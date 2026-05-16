# Report Flow Code Bundle

Thư mục này chứa các đoạn mã liên quan đến flow để chèn vào báo cáo (`BaoCao_30plus.md`).

## Mapping với placeholder trong báo cáo

- `Hình 1.1` -> `01_system_block.mmd`
- `Hình 2.4` -> `03_end_to_end_sequence.mmd`
- `Hình 2.6` -> `04_face_decision_flow.mmd`
- `Hình 2.7` -> `05_light_auto_manual_flow.mmd`
- `Hình 2.8` -> `06_mobile_architecture_flow.mmd`
- `Hình 3.9` -> `07_mobile_control_sequence.mmd`
- `AI chi tiet` -> `08_ai_pipeline_math_flow.mmd`

## Hình ảnh đã có sẵn

- Thư mục ảnh báo cáo: `report-images`
- Ảnh hiện có: `report-images/circuit_image.png` (có thể dùng cho Hình 2.1 hoặc 2.2)

## Snippet code để đưa vào phần "Mã 2.x"

- `snippet_controller_rule.py`
- `snippet_telemetry_publish.cpp`
- `snippet_mobile_polling.dart`
- `snippet_ai_formula.md`

## Gợi ý xuất ảnh từ Mermaid

Bạn có thể dùng Mermaid Live Editor:
1. Mở file `.mmd` và copy nội dung.
2. Dán vào https://mermaid.live
3. Export PNG/SVG và đặt vào `report-images`.
