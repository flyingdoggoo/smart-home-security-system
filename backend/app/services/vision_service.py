from __future__ import annotations

import ipaddress
import logging
import socket
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from urllib.parse import urlparse

import cv2
import numpy as np
import requests

from app.core.config import Settings
from app.services.controller import SmartHomeController
from app.services.face_service import FaceService

logger = logging.getLogger(__name__)


class VisionService:
    def __init__(
        self,
        settings: Settings,
        face_service: FaceService,
        controller: SmartHomeController,
    ) -> None:
        self.settings = settings
        self.face_service = face_service
        self.controller = controller
        self._thread: threading.Thread | None = None
        self._stop_event = threading.Event()
        self._capture_url = self.settings.camera_capture_url
        self._last_discovery_at = 0.0
        self._discovery_lock = threading.Lock()
        self._state_file = self._build_state_file()
        self._load_saved_capture_url()
        self._normalize_capture_url_in_memory()

    def start(self) -> None:
        if self._thread and self._thread.is_alive():
            return
        self._stop_event.clear()
        self._thread = threading.Thread(target=self._run_loop, name="vision-service", daemon=True)
        self._thread.start()

    def stop(self) -> None:
        self._stop_event.set()
        if self._thread and self._thread.is_alive():
            self._thread.join(timeout=2)

    def _run_loop(self) -> None:
        logger.info("Vision worker started: %s", self._capture_url)
        interval = max(0.2, self.settings.vision_interval_sec)

        while not self._stop_event.is_set():
            started = time.time()
            try:
                frame = self._fetch_frame()
                if frame is not None:
                    result = self.face_service.classify(frame)
                    self.controller.handle_vision_result(result)
            except Exception as exc:
                logger.warning("Vision cycle failed: %s", exc)

            try:
                self.controller.tick()
            except Exception as exc:
                logger.warning("Tick failed: %s", exc)

            elapsed = time.time() - started
            sleep_time = max(0.01, interval - elapsed)
            self._stop_event.wait(sleep_time)

        logger.info("Vision worker stopped")

    def _fetch_frame(self) -> np.ndarray | None:
        if not self._ensure_safe_capture_url():
            return None
        try:
            timeout = (
                max(0.2, self.settings.camera_discovery_connect_timeout_sec),
                max(0.3, self.settings.camera_discovery_read_timeout_sec),
            )
            response = requests.get(self._capture_url, timeout=timeout)
            response.raise_for_status()
        except requests.RequestException as exc:
            logger.warning("Camera capture request failed (%s): %s", self._capture_url, exc)
            self._maybe_rediscover_camera()
            return None

        peer_ip = self._extract_response_peer_ip(response)
        if peer_ip and self._is_private_ipv4(peer_ip):
            self._pin_capture_url_to_ip(peer_ip)
        else:
            # Khong dung du lieu tra ve tu host public/khong xac dinh.
            # Tranh truong hop .local resolve sai ra internet.
            parsed = urlparse(self._capture_url)
            host = parsed.hostname or ""
            if host and not self._is_private_ipv4(host) and not self._is_ipv4_literal(host):
                logger.warning("Camera hostname resolved to non-private peer (%s), rediscovering...", peer_ip)
                self._maybe_rediscover_camera()
                return None

        image_array = np.frombuffer(response.content, dtype=np.uint8)
        frame = cv2.imdecode(image_array, cv2.IMREAD_COLOR)
        if frame is None:
            logger.warning("Failed decoding camera JPEG frame")
            return None
        return frame

    def _build_state_file(self) -> Path:
        sqlite_path = Path(self.settings.sqlite_path)
        runtime_dir = sqlite_path.parent / "runtime"
        runtime_dir.mkdir(parents=True, exist_ok=True)
        return runtime_dir / "camera_capture_url.txt"

    def _normalize_capture_url(self, raw: str) -> str:
        value = (raw or "").strip()
        if not value:
            return ""
        if "://" not in value:
            value = f"http://{value}"

        parsed = urlparse(value)
        if not parsed.scheme or not parsed.netloc:
            return ""

        path = parsed.path or "/"
        if path == "/":
            path = self.settings.camera_capture_path
        if not path.startswith("/"):
            path = f"/{path}"
        return f"{parsed.scheme}://{parsed.netloc}{path}"

    def _load_saved_capture_url(self) -> None:
        try:
            if not self._state_file.exists():
                return
            saved = self._state_file.read_text(encoding="utf-8").strip()
            candidate = self._normalize_capture_url(saved)
            if candidate:
                self._capture_url = candidate
                logger.info("Vision loaded saved camera URL: %s", self._capture_url)
        except Exception as exc:
            logger.warning("Unable to load saved camera URL: %s", exc)

    def _normalize_capture_url_in_memory(self) -> None:
        normalized = self._normalize_capture_url(self._capture_url)
        if normalized:
            self._capture_url = normalized

    def _save_capture_url(self, capture_url: str) -> None:
        try:
            self._state_file.write_text(capture_url, encoding="utf-8")
        except Exception as exc:
            logger.warning("Unable to save camera URL: %s", exc)

    def _is_ipv4_literal(self, host: str) -> bool:
        try:
            ipaddress.IPv4Address(host)
            return True
        except Exception:
            return False

    def _is_private_ipv4(self, value: str) -> bool:
        try:
            ip = ipaddress.ip_address(value)
            return isinstance(ip, ipaddress.IPv4Address) and ip.is_private
        except Exception:
            return False

    def _resolve_hostname_to_private_ip(self, host: str) -> str | None:
        try:
            resolved = socket.gethostbyname(host)
        except Exception:
            return None
        if self._is_private_ipv4(resolved):
            return resolved
        return None

    def _capture_url_from_ip(self, ip: str) -> str:
        return f"http://{ip}{self.settings.camera_capture_path}"

    def _extract_response_peer_ip(self, response: requests.Response) -> str | None:
        try:
            # urllib3 raw socket peer
            return response.raw._connection.sock.getpeername()[0]
        except Exception:
            return None

    def _pin_capture_url_to_ip(self, ip: str) -> None:
        target = self._capture_url_from_ip(ip)
        if target != self._capture_url:
            logger.info("Pin camera URL to resolved private IP: %s -> %s", self._capture_url, target)
            self._capture_url = target
            self._save_capture_url(target)

    def _ensure_safe_capture_url(self) -> bool:
        parsed = urlparse(self._capture_url)
        host = parsed.hostname or ""
        if not host:
            return False

        if self._is_ipv4_literal(host):
            return True

        private_ip = self._resolve_hostname_to_private_ip(host)
        if private_ip:
            self._pin_capture_url_to_ip(private_ip)
            return True

        # Hostname khong resolve ve private IP: tranh goi nham ra internet.
        logger.warning("Camera host '%s' does not resolve to private IP, skipping direct fetch and rediscovering.", host)
        self._maybe_rediscover_camera()
        return False

    def _maybe_rediscover_camera(self) -> None:
        if not self.settings.camera_discovery_enabled:
            return

        cooldown = max(3.0, self.settings.camera_discovery_cooldown_sec)
        now = time.time()
        if now - self._last_discovery_at < cooldown:
            return

        if not self._discovery_lock.acquire(blocking=False):
            return
        try:
            self._last_discovery_at = now
            discovered = self._discover_camera_url()
            if discovered and discovered != self._capture_url:
                logger.info("Camera URL updated: %s -> %s", self._capture_url, discovered)
                self._capture_url = discovered
                self._save_capture_url(discovered)
        finally:
            self._discovery_lock.release()

    def _discover_camera_url(self) -> str | None:
        for url in self._candidate_capture_urls():
            if self._probe_capture_url(url):
                return url
        return None

    def _candidate_capture_urls(self) -> list[str]:
        seen: set[str] = set()
        ordered: list[str] = []

        def add(url: str) -> None:
            normalized = self._normalize_capture_url(url)
            if not normalized:
                return
            if normalized in seen:
                return
            seen.add(normalized)
            ordered.append(normalized)

        self._add_ip_or_private_hostname_candidate(add, self._capture_url)
        self._add_ip_or_private_hostname_candidate(add, self.settings.camera_capture_url)

        for hint in (self.settings.camera_host_hints or "").split(","):
            self._add_ip_or_private_hostname_candidate(add, hint)

        subnet_urls = self._scan_subnet_candidates()
        for url in subnet_urls:
            add(url)

        return ordered

    def _add_ip_or_private_hostname_candidate(self, add_fn, raw: str) -> None:
        normalized = self._normalize_capture_url(raw)
        if not normalized:
            return
        parsed = urlparse(normalized)
        host = parsed.hostname or ""
        if not host:
            return

        if self._is_ipv4_literal(host):
            add_fn(normalized)
            return

        private_ip = self._resolve_hostname_to_private_ip(host)
        if private_ip:
            add_fn(self._capture_url_from_ip(private_ip))

    def _iter_hint_subnets(self) -> list[ipaddress.IPv4Network]:
        subnets: list[ipaddress.IPv4Network] = []
        raw = (self.settings.camera_subnet_hints or "").strip()
        if not raw:
            return subnets

        for token in raw.split(","):
            item = token.strip()
            if not item:
                continue
            try:
                net = ipaddress.ip_network(item, strict=False)
            except ValueError:
                logger.warning("Invalid CAMERA_SUBNET_HINTS item ignored: %s", item)
                continue
            if isinstance(net, ipaddress.IPv4Network):
                subnets.append(net)
        return subnets

    def _iter_discovery_subnets(self) -> list[ipaddress.IPv4Network]:
        networks: list[ipaddress.IPv4Network] = []
        added: set[str] = set()

        def append(net: ipaddress.IPv4Network) -> None:
            key = str(net)
            if key in added:
                return
            added.add(key)
            networks.append(net)

        for net in self._iter_hint_subnets():
            append(net)

        local_ip = self._get_local_ipv4()
        if local_ip:
            try:
                append(ipaddress.ip_network(f"{local_ip}/24", strict=False))
            except ValueError:
                pass

        for raw in [self._capture_url, self.settings.camera_capture_url]:
            parsed = urlparse(self._normalize_capture_url(raw))
            host = parsed.hostname or ""
            if self._is_ipv4_literal(host):
                try:
                    append(ipaddress.ip_network(f"{host}/24", strict=False))
                except ValueError:
                    pass

        return networks

    def _scan_subnet_candidates(self) -> list[str]:
        subnets = self._iter_discovery_subnets()
        if not subnets:
            return []

        priority_hosts = [2, 3, 4, 5, 6, 10, 20, 30, 40, 50, 80, 100, 120, 150, 173, 200]
        candidate_urls: list[str] = []

        for subnet in subnets:
            own_host = None
            for raw in [self._capture_url, self.settings.camera_capture_url]:
                parsed = urlparse(self._normalize_capture_url(raw))
                host = parsed.hostname or ""
                if self._is_ipv4_literal(host):
                    try:
                        host_ip = ipaddress.ip_address(host)
                        if host_ip in subnet:
                            own_host = int(host.split(".")[-1])
                    except ValueError:
                        pass

            hosts: list[int] = []
            for host in priority_hosts:
                if 1 <= host <= 254 and host != own_host and host not in hosts:
                    hosts.append(host)
            for host in range(1, 255):
                if host == own_host or host in hosts:
                    continue
                hosts.append(host)

            prefix = ".".join(str(subnet.network_address).split(".")[:3])
            for host in hosts:
                candidate_urls.append(f"http://{prefix}.{host}{self.settings.camera_capture_path}")

        max_workers = max(8, min(128, self.settings.camera_discovery_max_workers))

        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            futures = {executor.submit(self._probe_capture_url, url): url for url in candidate_urls}
            for future in as_completed(futures):
                try:
                    ok = future.result()
                except Exception:
                    ok = False
                if ok:
                    found_url = futures[future]
                    executor.shutdown(wait=False, cancel_futures=True)
                    logger.info("Camera discovered in subnet: %s", found_url)
                    return [found_url]

        return []

    def _get_local_ipv4(self) -> str:
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
                sock.connect(("8.8.8.8", 80))
                ip = sock.getsockname()[0]
                ipaddress.ip_address(ip)
                return ip
        except Exception:
            pass

        parsed = urlparse(self.settings.camera_capture_url)
        host = parsed.hostname or ""
        try:
            ipaddress.ip_address(host)
            return host
        except ValueError:
            return ""

    def _probe_capture_url(self, capture_url: str) -> bool:
        try:
            response = requests.get(
                capture_url,
                timeout=(
                    max(0.2, self.settings.camera_discovery_connect_timeout_sec),
                    max(0.3, self.settings.camera_discovery_read_timeout_sec),
                ),
            )
            if response.status_code != 200:
                return False

            content_type = (response.headers.get("Content-Type") or "").lower()
            if "image/jpeg" in content_type:
                return True

            data = response.content
            return len(data) >= 4 and data[0] == 0xFF and data[1] == 0xD8
        except requests.RequestException:
            return False
