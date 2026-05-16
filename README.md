# Smart Home Guardian (ESP32-CAM + Python + Blynk)

MVP he thong giam sat an ninh + moi truong thong minh cho nha o:

- Face label: `owner`, `stranger`, `no_face`
- Gas alert (MQ-2): mo cua thoat hiem + canh bao
- Dieu khien tu xa: cua + den qua web API/dashboard va Blynk

## 1) Cau truc nhanh

- `firmware/code_camera_esp32`: ESP32-CAM stream (co san)
- `firmware/esp32_io_node`: ESP32 I/O node (servo SG90 + MQ-2 + light + MQTT)
- `backend`: FastAPI backend + face recognition + rule engine + scripts
- `infra/docker-compose.yml`: Mosquitto + backend
- `docs`: architecture, wiring, API
  - them `docs/data_collection.md` cho quy trinh thu thap du lieu khuon mat

## 2) Chay nhanh backend (local)

```powershell
cd backend
python -m venv .venv
.\\.venv\\Scripts\\activate
pip install -r requirements.txt
copy .env.example .env
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Web dashboard: `http://localhost:8000`

### Windows note (neu dang dung Python 3.12)

`face_recognition` co the loi build `dlib`. Cach on dinh:

```powershell
py -3.10 -m venv backend\.venv310
backend\.venv310\Scripts\python.exe -m pip install --upgrade pip
backend\.venv310\Scripts\python.exe -m pip install dlib-bin face-recognition-models face-recognition --no-deps
backend\.venv310\Scripts\python.exe -m pip install fastapi==0.115.0 uvicorn[standard]==0.30.6 jinja2==3.1.4 pydantic-settings==2.4.0 paho-mqtt==2.1.0 requests==2.32.3 numpy==2.1.1 opencv-python-headless==4.10.0.84
```

## 3) Chay bang Docker Compose

```powershell
cd infra
copy ..\\backend\\.env.example ..\\backend\\.env
docker compose up -d --build
```

## 4) Quy trinh enroll khuon mat chu nha

1. Thu thap anh tu ESP32-CAM:

```powershell
python backend/scripts/capture_owner_dataset.py --capture-url http://172.20.10.2/capture --target-count 60 --interval 1.2
```

2. Tao embeddings:

```powershell
python backend/scripts/enroll_owner.py --source-dir backend/data/faces/owner_raw --output backend/data/faces/owner_embeddings/owner_embeddings.npz
```

3. Reload embeddings:

```powershell
curl -X POST http://localhost:8000/api/v1/face/reload
```

## 5) Luu y an toan

- Khong cap nguon servo SG90 truc tiep tu chan 3.3V ESP32.
- Dung nguon 5V rieng cho servo, noi chung GND voi ESP32.
- Mac dinh MQTT dang `allow_anonymous true` chi dung cho LAN demo.
