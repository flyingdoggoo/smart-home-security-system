# Wiring Guide (MVP)

## Topology

- Board 1: `ESP32-CAM AI Thinker` -> video stream only.
- Board 2: `ESP32 DevKit` -> servo SG90 + MQ-2 + den + buzzer.

## ESP32 I/O pin map

- `SERVO_PIN = GPIO14`
- `MQ2_PIN = GPIO34` (ADC1)
- `LIGHT_PIN = GPIO2`
- `BUZZER_PIN = GPIO15`

## Dau noi khuyen nghi

1. Servo SG90:
   - Signal -> GPIO14
   - VCC -> 5V external
   - GND -> GND external + noi chung GND voi ESP32
2. MQ-2 module:
   - AOUT -> GPIO34
   - VCC -> 5V
   - GND -> GND
3. Den:
   - GPIO2 -> module relay hoac LED test
4. Buzzer:
   - GPIO15 -> buzzer active (qua transistor neu tai lon)

## Luu y quan trong

- Khong cap servo tu nguon 3.3V cua ESP32.
- Neu dung relay cho khoa dien tu, can diode/chong nhieu theo module relay.
- MQ-2 can warm-up truoc khi do threshold (thuong 2-5 phut cho demo, lau hon cho on dinh).

