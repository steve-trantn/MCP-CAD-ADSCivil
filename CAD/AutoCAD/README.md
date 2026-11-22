# AutoCAD

- **MCP server:** [CAD-MCP](https://github.com/daobataotie/CAD-MCP) (MIT), commit `daf7502`. Đây cũng là server dùng cho ZWCAD, cùng 35 tool, điều khiển AutoCAD qua COM.
- **Tên server:** `autocad`.
- **Cài vào:** `%LOCALAPPDATA%\SteveCADConnect\cadmcp\autocad\src`.
- **ProgID:** để trống, server tự thử mọi bản AutoCAD đã cài (`AutoCAD.Application.25.1`, `24.3`...), bản mới nhất trước. Ghi `"progid"` trong `config.json` nếu muốn cố định một bản.
- **Cần bản AutoCAD đầy đủ.** AutoCAD LT không có COM nên không dùng được.
- Nếu AutoCAD chưa mở, server tự khởi động AutoCAD (mất khoảng 20 giây).

### Về "Autodesk AutoCAD MCP Server"

Autodesk có cài kèm một MCP server chính hãng (`AutoCAD-MCP-Server-2027.bundle`), nhưng nó chỉ chạy với **AutoCAD 2027** (R26) và chưa có tài liệu công khai. Khi Autodesk công bố cách dùng, công cụ sẽ bổ sung lựa chọn này.

Lời dặn cho AI: [AGENTS.part.md](AGENTS.part.md).
