# Run All In One (ESP32-CAM + ESP32-C3 + Web)

Tai lieu nay la checklist 1 file de ban chay full he thong tu dau den cuoi.

## 1) Kien truc tong quan

- `ESP32-CAM`: stream/capture khuon mat
- `ESP32-C3`: doc MQ2 + cam bien anh sang + dieu khien servo/led/buzzer
- `Backend Python`: face recognition + rule engine + web dashboard
- `Mosquitto MQTT`: giao tiep backend <-> ESP32-C3

## 2) Nguon va wiring (quan trong)

### 2.1 Nguon

- 1 buck 5V (khuyen nghi >= 3A), chia nhanh song song:
  - 5V -> ESP32-CAM
  - 5V -> ESP32-C3 (chan 5V)
  - 5V -> Servo
  - 5V -> MQ2
- Tat ca GND noi chung.

### 2.2 Wiring ESP32-C3 (firmware hien tai)

Theo file: `firmware/esp32_io_node/esp32_io_node.ino`

- Servo SG90:
  - SIG -> `GPIO7`
  - VCC -> 5V
  - GND -> GND
- MQ2:
  - A0 -> `GPIO0` (qua chia ap neu module cap 5V)
  - D0 -> `GPIO6` (qua chia ap neu module cap 5V)
  - VCC -> 5V
  - GND -> GND
- Cam bien anh sang:
  - A0 -> `GPIO1`
  - D0 -> `GPIO3`
  - VCC -> 3.3V
  - GND -> GND
- LED phong:
  - `GPIO4` -> dien tro 220R -> anode LED
  - cathode -> GND
- Buzzer:
  - `GPIO5` -> +
  - GND -> -

### 2.3 Chia ap cho MQ2 khi cap 5V

Khuyen nghi chia ap cho ca `A0` va `D0` vao ESP32-C3:

- SensorOut -- `R1=10k` --+-- ESP32 GPIO
-                         |
-                       `R2=20k`
-                         |
-                        GND

## 3) Cau hinh va nap firmware

## 3.1 ESP32-CAM

File: `firmware/code_camera_esp32/code_camera_esp32.ino`

- Sua `ssid`, `password`
- Upload
- Mo Serial Monitor 115200
- Xac nhan log:
  - `Camera Ready! Use 'http://<ip>' to connect`

Kiem tra:
- `http://<ip-cam>/capture`

## 3.2 ESP32-C3 (main controller)

File: `firmware/esp32_io_node/esp32_io_node.ino`

- Sua:
  - `WIFI_SSID`
  - `WIFI_PASSWORD`
  - `MQTT_HOST` = IP may chay backend/mosquitto (vd `172.20.10.3`)
- Upload
- Mo Serial 115200, theo doi log:
  - sensor values
  - `[CMD] light ON/OFF` khi bam web

## 4) Thu data owner va tao embedding

### 4.1 Tao moi truong Python 3.10 (Windows)

```powershell
py -3.10 -m venv backend\.venv310
backend\.venv310\Scripts\python.exe -m pip install --upgrade pip
backend\.venv310\Scripts\python.exe -m pip install dlib-bin face-recognition-models face-recognition --no-deps
backend\.venv310\Scripts\python.exe -m pip install fastapi==0.115.0 uvicorn[standard]==0.30.6 jinja2==3.1.4 pydantic-settings==2.4.0 paho-mqtt==2.1.0 requests==2.32.3 numpy==2.1.1 opencv-python-headless==4.10.0.84
```

### 4.2 Thu anh owner

```powershell
backend\.venv310\Scripts\python.exe backend\scripts\capture_owner_dataset.py --capture-url http://<ip-cam>/capture --target-count 60 --interval 2.0
```

Anh luu tai:
- `backend/data/faces/owner_raw`

### 4.3 Tao embeddings

```powershell
backend\.venv310\Scripts\python.exe backend\scripts\enroll_owner.py --source-dir backend\data\faces\owner_raw --output backend\data\faces\owner_embeddings\owner_embeddings.npz --min-count 20
```

## 5) Chay backend + web + MQTT

## Lua chon khuyen nghi: Docker (gian don)

1. Tao/sua `backend/.env`:

```env
ESP32_CAM_BASE_URL=http://<ip-cam>
CAMERA_CAPTURE_PATH=/capture
VISION_INTERVAL_SEC=1.0
FACE_DETECTOR_MODEL=hog
FACE_MATCH_THRESHOLD=0.5
FACE_SMOOTHING_WINDOW=5
OWNER_EMBEDDINGS_FILE=data/faces/owner_embeddings/owner_embeddings.npz
```

2. Start stack:

```powershell
cd infra
docker compose down
docker compose up -d --build
```

3. Mo web:
- `http://localhost:8000`

Luu y: chi chay 1 backend de tranh MQTT session collision.

## 6) Test chuc nang

1. Web button:
- `Mo cua` / `Dong cua`
- `Bat den` / `Tat den`

2. Auto theo sensor:
- Che cam bien anh sang -> LED phong bat
- Mo sang -> LED phong tat

3. Gas:
- MQ2 trigger -> `gas_alert=true` tren web + buzzer keu + cua mo

4. Face:
- Owner -> cua mo
- Stranger -> cua dong

## 7) Debug nhanh

### 7.1 MQTT connect/disconnect lien tuc

- Trieu chung: `session taken over`, `MQTT_ERR_NO_CONN`
- Cach xu ly:
  - Dung backend duplicate (chi de 1 instance)
  - Kiem tra mosquitto dang chay (`docker ps`)

### 7.2 Bam den tren web ma LED khong sang

1. Xem Serial ESP32-C3 co log `[CMD] light ON` khong
2. Neu co log ma LED van khong sang:
  - Kiem tra wiring LED + dien tro
  - Dao cuc LED
  - Doi `LIGHT_LED_ACTIVE_HIGH` trong firmware (`true/false`)
3. Neu khong co log:
  - Kiem tra `MQTT_HOST` dung IP may backend
  - ESP32-C3 va backend cung mang WiFi

### 7.3 Gas khong bao tren web

1. Kiem tra MQ2 D0 co doi trang thai khi gas khong
2. Chinh:
  - `MQ2_D0_ACTIVE_LOW` (`true/false`)
  - `GAS_THRESHOLD`
3. Dam bao A0/D0 khong qua 3.3V vao ESP32-C3 (neu module cap 5V -> phai chia ap)

### 7.4 ESP32-CAM dung/treo

- Khong mo `/stream` cung luc voi script `/capture`
- Dung nguon 5V on dinh (1A-2A cho cam)
- Kiem tra ribbon camera

## 8) Files quan trong

- Camera firmware: `firmware/code_camera_esp32/code_camera_esp32.ino`
- Main controller firmware: `firmware/esp32_io_node/esp32_io_node.ino`
- Backend app: `backend/app/main.py`
- MQTT service: `backend/app/services/mqtt_service.py`
- Data scripts:
  - `backend/scripts/capture_owner_dataset.py`
  - `backend/scripts/enroll_owner.py`
  - `backend/scripts/predict_once.py`

