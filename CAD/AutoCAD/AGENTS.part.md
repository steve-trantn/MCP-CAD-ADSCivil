
## AutoCAD: server `autocad`

Điều khiển AutoCAD đang mở qua COM (35 tool, cùng bộ tool với ZWCAD).

- **Đọc:** `list_layers`, `list_entities`, `get_entity_properties`, `list_blocks`, `screenshot`
- **Vẽ:** `draw_line`, `draw_circle`, `draw_arc`, `draw_ellipse`, `draw_polyline`, `draw_rectangle`, `draw_text`, `draw_hatch`, `add_dimension`
- **Sửa:** `move_entity`, `copy_entity`, `rotate_entity`, `scale_entity`, `mirror_entity`, `offset_entity`, `array_linear_entity`, `array_polar_entity`, `erase_entity`, `undo`, `redo`
- **Layer, block, file:** `create_layer`, `set_current_layer`, `create_block`, `insert_block`, `new_drawing`, `open_drawing`, `save_drawing`, `close_drawing`
- Lệnh không có tool riêng: `send_command` (ví dụ `"_ZOOM _E "`). Tránh lệnh mở hộp thoại.
- Nếu AutoCAD chưa mở, server sẽ tự khởi động AutoCAD (mất khoảng 20 giây).
- Kết quả có thể chứa chữ Trung Quốc (thông báo của server gốc); dịch sang tiếng Việt khi trả lời.
