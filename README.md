# ADSCivil MCP: kết nối ADSCivil với ChatGPT (Codex), Gemini và Claude

Bộ script và cấu hình để các trợ lý AI điều khiển được **ADSCivil trên ZWCAD 2026** qua **MCP** (Model Context Protocol): đọc bản vẽ, layer, chạy lệnh, điều khiển hộp thoại, tra tiêu chuẩn TCVN...

ADSCivil NW 2027 đã có sẵn trợ lý AI (lệnh `ADSAI`, chạy Claude) và MCP server `AdsMcpServer.exe`. Repo này:

- dùng lại MCP server đó cho **ChatGPT (Codex)** và **Gemini CLI**;
- đưa trợ lý AI sang **ADSCivil NW 2026** và cho nó tự nạp mỗi lần khởi động.

> Repo **không chứa** file chạy hay dữ liệu của ADSCivil (`.zrx`, `.exe`, `standards.sqlite`). Các script chép chúng từ bản ADSCivil 2027 đã cài trên máy.

## Yêu cầu

- Windows, ZWCAD 2026, **ADSCivil NW 2027 For ZWCAD 2026** đã cài. Mặc định script dùng `C:\Program Files\BZS\ADSCivil NW 2027 For ZWCAD 2026`.
- ChatGPT: app **Codex** (Microsoft Store) hoặc Codex CLI, đăng nhập tài khoản ChatGPT.
- Gemini: Node.js 20 trở lên, Gemini CLI (`npm install -g @google/gemini-cli`) và một **Gemini API key**.

## Cài đặt nhanh

Mở PowerShell trong thư mục repo:

```powershell
# ChatGPT (Codex)
powershell -ExecutionPolicy Bypass -File scripts\setup-codex.ps1

# Gemini CLI
powershell -ExecutionPolicy Bypass -File scripts\setup-gemini.ps1

# ADSCivil 2026: chép module AI từ 2027 và tự nạp khi khởi động
# (đóng ADSCivil 2026 trước; cần PowerShell "Run as administrator" nếu Program Files không ghi được)
powershell -ExecutionPolicy Bypass -File scripts\install-2026-autoload.ps1

# Kiểm tra MCP server (ADSCivil phải đang mở)
powershell -ExecutionPolicy Bypass -File scripts\test-mcp.ps1
```

Các script đều sao lưu file cấu hình trước khi sửa (`*.bak-<thời gian>`). Chạy lại nhiều lần không sao.

## ChatGPT (Codex)

`scripts\setup-codex.ps1`:

1. tìm `codex.exe` (trong PATH hoặc bên trong app Codex của Microsoft Store);
2. chạy `codex mcp add adscivil -- <AdsMcpServer.exe>`;
3. thêm `cwd` và `startup_timeout_sec` vào `[mcp_servers.adscivil]` trong `%USERPROFILE%\.codex\config.toml`;
4. tạo thư mục làm việc `%USERPROFILE%\ADSCivil-Codex` có `AGENTS.md` (lời dặn hệ thống).

Cấu hình tương đương: [`codex/config.example.toml`](codex/config.example.toml).

Sau khi chạy: **thoát hẳn app Codex rồi mở lại**, mở thư mục `ADSCivil-Codex`, **tạo cuộc trò chuyện mới** và hỏi: *"Dùng tool adscivil liệt kê các layer của bản vẽ đang mở."*

> **Bắt buộc có `cwd`.** Thiếu dòng này, app Codex không khởi động được server (`MCP server startup failed ... The directory name is invalid. (os error 267)`). Khi đó ChatGPT chuyển sang chụp màn hình và trả lời "không xem được màn hình".

Không dùng được ChatGPT bản web: nó chỉ nhận MCP server từ xa qua HTTPS, không chạy server trên máy. Muốn dùng phải mở ZWCAD ra Internet, nên không khuyến nghị.

## Gemini CLI

`scripts\setup-gemini.ps1`:

1. thêm `adscivil` vào `mcpServers` trong `%USERPROFILE%\.gemini\settings.json` (giữ nguyên các cài đặt khác);
2. đặt kiểu đăng nhập `gemini-api-key`;
3. tạo thư mục `%USERPROFILE%\ADSCivil-Gemini` gồm `GEMINI.md` và `Mo Gemini ADSCivil.cmd`, rồi đánh dấu thư mục là tin cậy (`trustedFolders.json`).

Lấy key tại <https://aistudio.google.com/apikey> và tạo file `%USERPROFILE%\ADSCivil-Gemini\.env`:

```
GEMINI_API_KEY=key_cua_ban
```

Bấm đúp `Mo Gemini ADSCivil.cmd`, gõ `/mcp` để xem các tool.

> - **Không đăng nhập bằng tài khoản Google được nữa:** Gemini CLI báo `IneligibleTierError: This client is no longer supported for Gemini Code Assist for individuals`, nên phải dùng API key.
> - **Phải mở Gemini trong thư mục đã đánh dấu tin cậy.** Ở thư mục khác, Gemini tắt toàn bộ MCP server.

Cấu hình tương đương: [`gemini/settings.example.json`](gemini/settings.example.json).

## Claude

- **Trong ADSCivil 2027 (và 2026 sau khi cài tự nạp):** gõ lệnh `ADSAI`.
- **Claude Code:** `claude mcp add adscivil -- "C:\Program Files\BZS\ADSCivil NW 2027 For ZWCAD 2026\AdsMcpServer.exe"`
- **Claude Desktop:** xem [`claude/claude_desktop_config.example.json`](claude/claude_desktop_config.example.json).

## ADSCivil NW 2026

Module AI của bản 2027 chỉ phụ thuộc ZWCAD, nên chạy được trong ADSCivil 2026. `scripts\install-2026-autoload.ps1`:

1. chép `Ads.System.AI.Assistant.zrx`, `AdsMcpServer.exe` và thư mục `AdsAI\` từ thư mục 2027 sang thư mục 2026;
2. thêm [`zwcad/ads-ai-autoload.lsp`](zwcad/ads-ai-autoload.lsp) vào cuối `ZWCAD.lsp` của bản 2026. Đoạn này chỉ nạp khi tìm thấy file và chưa nạp; nếu lỗi thì in một dòng, không ảnh hưởng phần nạp menu.

Khởi động ADSCivil 2026: dòng lệnh hiện `ADSCivil AI: da nap. Go ADSAI de mo tro ly AI.`

Giới hạn:

- Bản 2026 dùng được **nhóm tool chung**: thông tin bản vẽ, layer, chạy lệnh, điều khiển hộp thoại, click hoặc chọn trong bản vẽ, tra tiêu chuẩn, ghi nhớ quy tắc. Khoảng 49 tool, so với khoảng 290 khi nối với bản 2027.
- **Tool nghiệp vụ** (kiểm tra tuyến, trắc dọc, siêu cao, mạng cống, san nền...) chỉ có trên bản 2027. Trên bản 2026, AI có thể gọi nhầm và nhận lỗi.
- **Cài lại ADSCivil 2026 sẽ ghi đè `ZWCAD.lsp`:** chạy lại script sau khi cài lại.

## Câu hỏi để thử

| Mục đích | Câu hỏi |
|---|---|
| Đọc bản vẽ | "Bản vẽ đang mở có bao nhiêu đối tượng, bao nhiêu layer, đơn vị gì?" |
| Trạng thái CAD | "ZWCAD đang làm gì, có hộp thoại nào đang mở không?" |
| Tiêu chuẩn | "Theo TCVN 4054:2005, bán kính đường cong nằm tối thiểu với tốc độ 60 km/h? Trích điều khoản." |
| Hướng dẫn | "Hướng dẫn từng bước thiết kế siêu cao trong ADSCivil." |
| Ghi (bản vẽ thử) | "Tạo layer AI-TEST màu đỏ." (gõ `UNDO` để hoàn tác) |
| Kiểm tra thiết kế | "Kiểm tra tuyến theo TCVN 4054, báo lý trình không đạt." (bản 2027, bản vẽ có tuyến) |

Khi AI thật sự gọi tool, sẽ thấy dòng `adscivil/<tên tool>`. Nếu không có dòng nào, tức là AI đang trả lời theo trí nhớ; nhắc nó *"dùng tool adscivil"*.

## Xử lý sự cố

| Hiện tượng | Cách xử lý |
|---|---|
| Codex: "không xem được màn hình", không có dòng `adscivil/...` | Kiểm tra `cwd` trong `config.toml`, thoát hẳn app rồi mở lại, mở cuộc trò chuyện mới. Log lỗi: `%USERPROFILE%\.codex\logs_2.sqlite` |
| Gemini: `IneligibleTierError` | Dùng API key (`.env`), không đăng nhập Google |
| Gemini: `adscivil ... Disabled` | Mở Gemini trong `ADSCivil-Gemini` (thư mục đã tin cậy) |
| Mở nhiều ZWCAD cùng lúc, AI đọc nhầm bản vẽ | Server tự chọn một phiên ZWCAD đang chạy. Chỉ mở một phiên, hoặc đặt biến môi trường `ADSCIVIL_MCP_PIPE=\\.\pipe\adscivil-mcp-<PID của ZWCAD>` cho server |
| Bản 2026 không hiện "ADSCivil AI: da nap" | Kiểm tra 3 file đã chép sang thư mục 2026 và cuối `ZWCAD.lsp` có `(ads-ai-autoload)` |

## Cấu trúc

```
scripts/   setup-codex.ps1, setup-gemini.ps1, install-2026-autoload.ps1, test-mcp.ps1
codex/     AGENTS.md, config.example.toml
gemini/    GEMINI.md, Mo Gemini ADSCivil.cmd, settings.example.json
claude/    claude_desktop_config.example.json
zwcad/     ads-ai-autoload.lsp
```
