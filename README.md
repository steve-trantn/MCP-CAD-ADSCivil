# Steve CAD-AI Connect

**Kết nối ZWCAD · AutoCAD · ADSCivil với Claude · ChatGPT · Gemini bằng một cú bấm.**

Sau khi kết nối, bạn chỉ cần trò chuyện với trợ lý AI và nó sẽ **điều khiển trực tiếp phần mềm CAD đang mở**: đọc layer và đối tượng, vẽ, sửa, chèn block, chạy lệnh, tra tiêu chuẩn TCVN (với ADSCivil)... Việc kết nối dùng **MCP** (Model Context Protocol).

![Steve CAD-AI Connect](docs/screenshot.png)

> **Liên hệ hỗ trợ:** Steve Tran | 0987 779 228

## Dùng thế nào

1. **Tải về:** vào trang [**Releases**](https://github.com/steve-trantn/MCP-CAD-ADSCivil/releases/latest), tải file `Steve-CAD-AI-Connect-*.zip` rồi giải nén.
2. **Bấm đúp `Steve CAD-AI Connect.cmd`.**
3. **Tích chọn** phần mềm CAD và trợ lý AI muốn nối, rồi bấm **Connect**.
4. **Thoát hẳn trợ lý AI rồi mở lại** và bắt đầu ra lệnh, ví dụ: *"Bản vẽ đang mở có những layer nào?"*, *"Vẽ hình chữ nhật 1000×500 trên layer AI-TEST"*.

Kết nối xong có thể đóng công cụ, khởi động lại máy cũng không mất kết nối. Công cụ tạo shortcut **Steve CAD-AI Connect** trên Desktop và trong Start menu để mở lại khi cần.

| Muốn | Làm |
|---|---|
| Ngắt kết nối | Mở công cụ, tích chọn mục muốn ngắt, bấm **Disconnect** |
| Kiểm tra | Mở phần mềm CAD, bấm **Kiểm tra**: công cụ đọc thử danh sách layer của bản vẽ đang mở |
| Gỡ bỏ | Bấm **Uninstall**, hoặc chạy `Uninstall.cmd`, hoặc vào *Settings → Apps → Steve CAD-AI Connect → Uninstall* |

> Windows SmartScreen có thể cảnh báo khi chạy file tải từ Internet: bấm **More info → Run anyway**.

## Phần mềm CAD hỗ trợ

| CAD | MCP server | Yêu cầu | Chi tiết |
|---|---|---|---|
| **ZWCAD** | [CAD-MCP](https://github.com/daobataotie/CAD-MCP) (mã nguồn mở, MIT), 35 tool | ZWCAD 2020+; Python tự cài nếu thiếu | [CAD/ZWCAD](CAD/ZWCAD) |
| **AutoCAD** | [CAD-MCP](https://github.com/daobataotie/CAD-MCP), 35 tool | AutoCAD 2018+ (bản đầy đủ, không phải LT) | [CAD/AutoCAD](CAD/AutoCAD) |
| **ADSCivil** | `AdsMcpServer.exe` có sẵn trong ADSCivil 2027, khoảng 290 tool nghiệp vụ | ADSCivil NW 2027 For ZWCAD 2026 | [CAD/ADSCivil](CAD/ADSCivil) |

Máy có phần mềm nào thì ô đó mới bật. Nối nhiều CAD cùng lúc được: mỗi CAD là một server riêng (`zwcad`, `autocad`, `adscivil`).

## Trợ lý AI hỗ trợ

| Trợ lý | Cần gì | Ghi chú |
|---|---|---|
| **Claude Desktop** | [Claude Desktop](https://claude.ai/download), đăng nhập | Hỗ trợ cả bản Microsoft Store và bản cài thường |
| **Claude Code** | Claude Code | Nối ở phạm vi user, dùng được ở mọi thư mục |
| **ChatGPT (Codex)** | App **Codex** (Microsoft Store), đăng nhập ChatGPT | Mở thư mục làm việc `Steve-CAD-AI` trong Codex |
| **Gemini CLI** | **API key** miễn phí tại <https://aistudio.google.com/apikey> | Công cụ tự cài Node.js và Gemini CLI. Dán key vào ô *Gemini API key*. Mở bằng shortcut **Gemini CAD AI** |

ChatGPT bản web không dùng được vì chỉ nhận MCP server từ xa qua HTTPS.

## Công cụ làm gì trên máy

- **ZWCAD, AutoCAD:** tải CAD-MCP đúng bản đã rà soát (commit `daf7502`) vào `%LOCALAPPDATA%\SteveCADConnect` và tạo môi trường Python riêng. Server chỉ nói chuyện với CAD qua COM, không gửi dữ liệu ra ngoài.
- **Đăng ký server** vào cấu hình của từng trợ lý AI đã chọn. Mọi file cấu hình được sao lưu trước khi sửa (`*.bak-<thời gian>`).
- **Tạo thư mục làm việc** `%USERPROFILE%\Steve-CAD-AI` với lời dặn cho AI (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`): luôn đọc bản vẽ thật bằng tool, hỏi trước khi xóa, lưu hoặc đóng bản vẽ.
- **ADSCivil 2026** (tùy chọn): chép trợ lý AI của bản 2027 sang và cho nó tự nạp khi khởi động (lệnh `ADSAI`). Chỉ xin quyền admin khi cần.
- **Uninstall** gỡ sạch tất cả: ngắt kết nối, tắt tự nạp, xóa server, shortcut và mục trong Settings → Apps. Riêng thư mục làm việc (có API key) được giữ lại.

## Dòng lệnh (cho IT, cài hàng loạt)

```bat
powershell -ExecutionPolicy Bypass -File app\SteveCADConnect.ps1 -Connect                 :: moi CAD + moi tro ly co tren may
powershell -ExecutionPolicy Bypass -File app\SteveCADConnect.ps1 -Connect -Cad zwcad -Client codex,claude -Test
powershell -ExecutionPolicy Bypass -File app\SteveCADConnect.ps1 -Connect -Ads2026 -GeminiKey <key>
powershell -ExecutionPolicy Bypass -File app\SteveCADConnect.ps1 -Disconnect -Cad autocad
powershell -ExecutionPolicy Bypass -File app\SteveCADConnect.ps1 -Uninstall
```

## Xử lý sự cố

| Hiện tượng | Cách xử lý |
|---|---|
| AI trả lời "không xem được màn hình", không thấy dòng gọi tool (`zwcad/...`, `adscivil/...`) | Thoát hẳn trợ lý AI rồi mở lại, mở cuộc trò chuyện mới. Codex: mở thư mục `Steve-CAD-AI`. Log lỗi Codex nằm ở `%USERPROFILE%\.codex\logs_2.sqlite` |
| Gemini: `IneligibleTierError` | Dùng API key, không đăng nhập Google |
| Gemini: server bị `Disabled` | Mở Gemini bằng shortcut **Gemini CAD AI** (thư mục đã đánh dấu tin cậy) |
| Kiểm tra báo "chưa đọc được bản vẽ" | Mở CAD và một bản vẽ, bấm Esc để thoát lệnh hoặc hộp thoại đang mở, rồi thử lại |
| ADSCivil: "Cannot reach ADSCivil" | Mở ADSCivil (không phải ZWCAD thường) và một bản vẽ |
| Mở nhiều phiên CAD cùng lúc | Server nối vào phiên mà Windows đăng ký trước. Nên chỉ mở một phiên |
| Kết quả có chữ Trung Quốc | Đó là thông báo của CAD-MCP; AI sẽ dịch khi trả lời |
| Vẫn chưa được | Liên hệ **Steve Tran, 0987 779 228** |

## Cấu trúc

```
Steve CAD-AI Connect.cmd    bấm đúp để mở công cụ
Uninstall.cmd               gỡ toàn bộ
app/                        SteveCADConnect.ps1 (giao diện + dòng lệnh), core.ps1
CAD/ZWCAD/                  lời dặn AI cho ZWCAD
CAD/AutoCAD/                lời dặn AI cho AutoCAD
CAD/ADSCivil/               lời dặn AI, tự nạp ADSCivil 2026 (ads-ai-autoload.lsp, install-2026-autoload.ps1)
templates/                  lời dặn chung, launcher Gemini
```

## Liên hệ

**Steve Tran** · 0987 779 228 · [github.com/steve-trantn](https://github.com/steve-trantn)

Báo lỗi hoặc góp ý: gọi trực tiếp, hoặc mở [Issue](https://github.com/steve-trantn/MCP-CAD-ADSCivil/issues) trên GitHub.

## Bản quyền

- [CAD-MCP](https://github.com/daobataotie/CAD-MCP) © daobataotie, giấy phép MIT. Repo này không chứa mã của CAD-MCP; công cụ tải mã từ repo gốc khi cài.
- ADSCivil và `AdsMcpServer.exe` thuộc bản quyền của nhà phát triển ADSCivil. Repo không chứa file nào của ADSCivil; công cụ dùng bản đã cài trên máy.
