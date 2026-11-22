# ZWCAD

- **MCP server:** [CAD-MCP](https://github.com/daobataotie/CAD-MCP) (MIT), commit `daf7502`. Server điều khiển ZWCAD qua COM, có 35 tool: vẽ, sửa, layer, block, đọc đối tượng, chụp hình, chạy lệnh.
- **Tên server:** `zwcad`.
- **Cài vào:** `%LOCALAPPDATA%\SteveCADConnect\cadmcp\zwcad\src`. Python dùng chung tại `%LOCALAPPDATA%\SteveCADConnect\venv`.
- **ProgID:** công cụ tự chọn bản ZWCAD mới nhất có trên máy (ví dụ `ZWCAD.Application.2026`) và ghi vào `config.json`. Sửa `"progid"` trong file đó nếu muốn nối với bản khác.
- Server nối vào ZWCAD đang mở. Nếu ZWCAD chưa mở, server tự khởi động ZWCAD.
- **Đã thử:** ZWCAD 2026 Professional.

Lời dặn cho AI: [AGENTS.part.md](AGENTS.part.md).
