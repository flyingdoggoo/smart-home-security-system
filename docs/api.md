# API & Topics

## REST API

- `GET /api/v1/status`
  - Trang thai tong hop: door/light/gas/face
- `GET /api/v1/events?limit=50`
  - Nhat ky su kien
- `POST /api/v1/door/open`
- `POST /api/v1/door/close`
- `POST /api/v1/light/on`
- `POST /api/v1/light/off`
- `POST /api/v1/face/reload`
  - Reload embeddings sau khi enroll

## MQTT Topics

- Command:
  - `home/io/cmd/door` payload: `OPEN` | `CLOSE`
  - `home/io/cmd/light` payload: `ON` | `OFF`
- Telemetry:
  - `home/io/telemetry` payload JSON:
    ```json
    {
      "gas_value": 1780,
      "gas_alert": false,
      "door_state": "locked",
      "light_state": "off",
      "source": "esp32_io"
    }
    ```
- Vision state publish:
  - `home/vision/state` payload JSON:
    ```json
    {
      "label": "owner",
      "confidence": 0.82,
      "distance": 0.42,
      "face_count": 1,
      "timestamp": "2026-05-12T15:00:00Z"
    }
    ```

## Blynk mapping

- `V0`: door status/command
- `V1`: light status/command
- `V2`: gas alert
- `V3`: face label

Event codes:

- `intruder_alert`
- `gas_alert`

