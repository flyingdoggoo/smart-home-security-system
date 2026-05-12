# Architecture

## Tong quan

He thong duoc tach thanh 2 node phan cung + 1 backend:

1. `ESP32-CAM`:
   - Stream video (`/stream`)
   - Snap frame (`/capture`) cho backend vision
2. `ESP32 I/O`:
   - Dieu khien `servo SG90` khoa cua
   - Doc `MQ-2`
   - Dieu khien den + buzzer
   - Publish telemetry qua MQTT
3. `Python Backend`:
   - Face classification (`owner/stranger/no_face`)
   - Rule engine cho cua/gas/canh bao
   - API + web dashboard
   - Dong bo Blynk

## Data flow

1. Backend pull frame tu `ESP32-CAM /capture` theo `VISION_INTERVAL_SEC`.
2. Face service classify:
   - `no_face`: khong thay mat
   - `owner`: tat ca mat trong frame match chu nha
   - `stranger`: co it nhat 1 mat khong match
3. Rule engine:
   - `owner` -> mo cua + hen gio auto relock
   - `stranger` -> dong cua + canh bao
   - `gas_alert` -> mo cua thoat hiem + canh bao (uu tien cao nhat)
4. Command duoc publish sang MQTT topic cua `ESP32 I/O`.
5. ESP32 I/O publish telemetry ve backend de cap nhat trang thai.

## AI strategy (nhe)

- Khong train model moi.
- Dung embedding san co cua `face_recognition`:
  - Detect face (HOG/CNN)
  - Encode 128-D vector
  - So sanh Euclidean distance voi embedding chu nha
- Nhan `owner` neu distance <= `FACE_MATCH_THRESHOLD` (mac dinh 0.5).
- Co smoothing window de giam false alert.

