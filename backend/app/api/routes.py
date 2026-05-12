from __future__ import annotations

from pathlib import Path

from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates

from app.services.controller import SmartHomeController
from app.services.face_service import FaceService

router = APIRouter()
templates = Jinja2Templates(directory=str(Path(__file__).resolve().parents[1] / "templates"))


def _get_controller(request: Request) -> SmartHomeController:
    return request.app.state.controller


def _get_face_service(request: Request) -> FaceService:
    return request.app.state.face_service


@router.get("/", response_class=HTMLResponse)
def dashboard(request: Request) -> HTMLResponse:
    controller = _get_controller(request)
    events = request.app.state.event_store.list_events(limit=15)
    settings = request.app.state.settings
    return templates.TemplateResponse(
        request=request,
        name="index.html",
        context={
            "status": controller.state.snapshot(),
            "events": events,
            "camera_stream_url": f"{settings.esp32_cam_base_url.rstrip('/')}:81/stream",
        },
    )


@router.get("/partials/status", response_class=HTMLResponse)
def partial_status(request: Request) -> HTMLResponse:
    status = _get_controller(request).state.snapshot()
    return templates.TemplateResponse(
        request=request,
        name="partials_status.html",
        context={"status": status},
    )


@router.get("/partials/events", response_class=HTMLResponse)
def partial_events(request: Request) -> HTMLResponse:
    events = request.app.state.event_store.list_events(limit=15)
    return templates.TemplateResponse(
        request=request,
        name="partials_events.html",
        context={"events": events},
    )


@router.get("/api/v1/status")
def get_status(request: Request) -> dict:
    return _get_controller(request).state.snapshot()


@router.get("/api/v1/events")
def get_events(request: Request, limit: int = 50) -> dict:
    limit = max(1, min(200, limit))
    return {"events": request.app.state.event_store.list_events(limit=limit)}


@router.post("/api/v1/door/open")
def door_open(request: Request) -> dict:
    controller = _get_controller(request)
    controller.request_door("open", source="web_api")
    return {"ok": True, "door_state": "unlocked"}


@router.post("/api/v1/door/close")
def door_close(request: Request) -> dict:
    controller = _get_controller(request)
    controller.request_door("close", source="web_api")
    return {"ok": True, "door_state": "locked"}


@router.post("/api/v1/light/on")
def light_on(request: Request) -> dict:
    controller = _get_controller(request)
    controller.request_light("on", source="web_api")
    return {"ok": True, "light_state": "on"}


@router.post("/api/v1/light/off")
def light_off(request: Request) -> dict:
    controller = _get_controller(request)
    controller.request_light("off", source="web_api")
    return {"ok": True, "light_state": "off"}


@router.post("/api/v1/face/reload")
def reload_face_embeddings(request: Request) -> dict:
    face_service = _get_face_service(request)
    face_service.reload_owner_embeddings()
    return {"ok": True}


@router.post("/actions/door/{action}", response_class=HTMLResponse)
def action_door(request: Request, action: str) -> HTMLResponse:
    if action not in {"open", "close"}:
        raise HTTPException(status_code=400, detail="Invalid action")
    _get_controller(request).request_door(action, source="web_button")
    return partial_status(request)


@router.post("/actions/light/{action}", response_class=HTMLResponse)
def action_light(request: Request, action: str) -> HTMLResponse:
    if action not in {"on", "off"}:
        raise HTTPException(status_code=400, detail="Invalid action")
    _get_controller(request).request_light(action, source="web_button")
    return partial_status(request)
