# Project Summary - Smart Home Security + Environment Monitoring

Ngay cap nhat: 2026-05-16

## 1) Muc tieu du an

Xay dung he thong nha thong minh gom:
- Bao mat cua bang nhan dien khuon mat (owner/stranger/no_face).
- Canh bao ro ri khi gas vuot nguong.
- Dieu khien tu xa qua web/app: mo dong cua, bat tat den.
- Tu dong bat den khi troi toi.

## 2) Kien truc tong the

- `ESP32-CAM`:
  - Phat camera endpoint (`/capture`, co the co `/stream`).
  - Cung cap frame cho backend nhan dien.
- `Backend Python (FastAPI)`:
  - Lay frame tu ESP32-CAM.
  - Face detect + face match nhe (embedding threshold).
  - Rule engine:
    - stranger -> dong cua
    - owner -> mo cua
    - gas alert -> canh bao + uu tien an toan
  - Publish MQTT command va nhan telemetry.
- `ESP32-C3 (I/O node)`:
  - Doc MQ2 (A0 + D0).
  - Doc cam bien anh sang (A0 + D0).
  - Dieu khien servo, LED phong, buzzer.
  - Gui telemetry len MQTT.
- `Mosquitto MQTT`:
  - Kenh giao tiep backend <-> ESP32-C3.
- `Web dashboard`:
  - Hien thi trang thai.
  - Nut dieu khien den/cua.

## 3) Viec da lam

## 3.1 Planning + huong trien khai

- Da xac dinh huong AI nhe, khong train model nang:
  - Thu data owner.
  - Tao owner embeddings.
  - Predict real-time bang so khop threshold.
- Da chot phan tach 2 board:
  - ESP32-CAM chuyen ve vision.
  - ESP32-C3 chuyen ve I/O va actuator.

## 3.2 Data strategy va AI

- Da huong dan quy trinh:
  1. Thu anh owner tu `http://<cam-ip>/capture`.
  2. Loc anh co mat hop le.
  3. Tao file embedding owner (`.npz`).
  4. Chay predict real-time:
     - match -> owner
     - no match -> stranger
     - khong thay mat -> no_face
- Da giai thich:
  - Khong can gan bounding box thu cong cho cach lam hien tai.
  - Bounding box tu detector runtime.

## 3.3 Firmware ESP32-C3

Da nang cap file `firmware/esp32_io_node/esp32_io_node.ino`:
- Them MQ2 D0 va A0 song song.
- Them light sensor D0 va A0 song song.
- Them LED phong output.
- Them buzzer output khi gas alert.
- Them MQTT command parser cho:
  - `home/io/cmd/door` (`OPEN`/`CLOSE`)
  - `home/io/cmd/light` (`ON`/`OFF`/`AUTO`)
- Them telemetry JSON:
  - `gas_value`, `gas_alert`, `gas_d0`
  - `light_value`, `dark`, `light_d0_dark`
  - `door_state`, `light_state`, `source`
- Them debug serial dinh ky de calibrate threshold.
- Them hysteresis cho light de tranh nhap nhay.
- Fix logic dark:
  - Mac dinh lay tu analog A0.
  - Khong de D0 ep dark sai neu chua can.
- Them boot config print + `FW_VERSION` de xac nhan board dang chay dung firmware moi.

## 3.4 Backend MQTT stability

Da sua file `backend/app/services/mqtt_service.py`:
- Tao `client_id` MQTT unique (host/pid/random suffix).
- Muc tieu: tranh va cham session gay `MQTT_ERR_NO_CONN`/disconnect lien tuc.

## 3.5 Tai lieu van hanh

Da tao file huong dan run all:
- `docs/RUN_ALL.md`
- Noi dung gom:
  - Nguon cap
  - Wiring
  - Upload firmware
  - Thu data
  - Enroll embedding
  - Chay backend + docker
  - Checklist test + debug nhanh

## 4) Wiring da chot (ESP32-C3)

- Servo SIG -> `GPIO7`
- MQ2 A0 -> `GPIO0` (qua chia ap neu MQ2 cap 5V)
- MQ2 D0 -> `GPIO6` (qua chia ap neu MQ2 cap 5V)
- Light A0 -> `GPIO1`
- Light D0 -> `GPIO3`
- LED phong -> `GPIO4` (qua dien tro 220R)
- Buzzer -> `GPIO5`
- Tat ca GND noi chung.

## 5) Cac van de da debug

- ESP32-CAM bi treo/VSYNC overflow:
  - Da khoanh vung nguon, stream/capture dong thoi, ribbon camera.
- Loi `cv2`:
  - Da huong dan cai dependency dung moi truong Python.
- MQTT publish fail/disconnect:
  - Da fix client id va nhac chay 1 backend instance.
- LED web command khong sang:
  - Da bo sung log `[CMD]` va logic active level.
- Light detect sai:
  - Da bo sung dark by A0/D0 ro rang + hysteresis + config print.

## 6) Trang thai hien tai

- He thong da co day du cac thanh phan chinh.
- Firmware ESP32-C3 da co:
  - gas alert + buzzer
  - auto light + manual light command
  - door control theo command/rule
  - telemetry day du de web hien thi
- Can tiep tuc calibrate threshold theo du lieu thuc te (gas/light) tai nha ban.

## 7) File quan trong

- `firmware/code_camera_esp32/code_camera_esp32.ino`
- `firmware/esp32_io_node/esp32_io_node.ino`
- `backend/app/services/mqtt_service.py`
- `backend/scripts/capture_owner_dataset.py`
- `backend/scripts/enroll_owner.py`
- `docs/RUN_ALL.md`
- `docs/SUMMARY.md`
