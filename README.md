# ADSCivil MCP: kết nối ADSCivil với ChatGPT (Codex), Gemini và Claude

Bộ script và cấu hình để các trợ lý AI điều khiển được **ADSCivil trên ZWCAD 2026** qua **MCP** (Model Context Protocol): đọc bản vẽ, layer, chạy lệnh, điều khiển hộp thoại, tra tiêu chuẩn TCVN...

ADSCivil NW 2027 đã có sẵn trợ lý AI (lệnh `ADSAI`, chạy Claude) và MCP server `AdsMcpServer.exe`. Repo này:

- dùng lại MCP server đó cho **ChatGPT (Codex)** và **Gemini CLI**;
- đưa trợ lý AI sang **ADSCivil NW 2026** và cho nó tự nạp mỗi lần khởi động.

> Repo **không chứa** file chạy hay dữ liệu của ADSCivil (`.zrx`, `.exe`, `standards.sqlite`). Các script chép chúng từ bản ADSCivil 2027 đã cài trên máy.

> **Không có ADSCivil, chỉ có ZWCAD?** Dùng gói [**ZWCAD-MCP**](https://github.com/steve-trantn/ZWCAD-MCP): 35 tool vẽ, sửa, đọc bản vẽ, cài riêng. Hai gói chạy song song được.

## Tải về và cài đặt (3 bước)

1. **Tải về:** vào trang [**Releases**](https://github.com/steve-trantn/MCP-CAD-ADSCivil/releases/latest) và tải file `ADSCivil-MCP-*.zip` (hoặc dùng [Download ZIP](https://github.com/steve-trantn/MCP-CAD-ADSCivil/archive/refs/heads/main.zip)), rồi giải nén ra một thư mục bất kỳ (ví dụ Desktop).
2. **Bấm đúp `CaiDat.cmd`** trong thư mục vừa giải nén.
3. **Chọn trong menu:**

```
  1. Ket noi ChatGPT (app Codex)
  2. Ket noi Gemini CLI
  3. ADSCivil 2026: tu nap tro ly AI (lenh ADSAI)
  4. Cai tat ca (1 + 2 + 3)
  5. Kiem tra ket noi (mo ADSCivil truoc)
  6. Go bo tat ca
```

Trình cài tự làm các việc sau:

- tìm thư mục cài ADSCivil 2027 và 2026, không cần sửa đường dẫn;
- cài Gemini CLI (và Node.js nếu thiếu) khi được hỏi, nhận API key và tạo shortcut **Gemini ADSCivil** trên Desktop;
- xin quyền admin khi cần ghi vào `Program Files`;
- sao lưu mọi file cấu hình trước khi sửa (`*.bak-<thời gian>`).

Chạy lại nhiều lần không sao. Mục **6** gỡ sạch và trả `ZWCAD.lsp` về như cũ.

> Windows SmartScreen có thể cảnh báo khi chạy file tải từ Internet: bấm **More info → Run anyway**.

## Yêu cầu

- Windows 10/11, ZWCAD 2026, **ADSCivil NW 2027 For ZWCAD 2026** đã cài (bản có trợ lý AI và `AdsMcpServer.exe`).
- ChatGPT: app **Codex** của OpenAI (Microsoft Store), đăng nhập tài khoản ChatGPT.
- Gemini: một **Gemini API key** miễn phí tại <https://aistudio.google.com/apikey>. Node.js và Gemini CLI được trình cài tự cài.

## Chạy không cần menu (cho IT, cài hàng loạt)

```bat
CaiDat.cmd -All                 :: cai 1 + 2 + 3
CaiDat.cmd -Codex -Test         :: chi ChatGPT, roi kiem tra
CaiDat.cmd -Uninstall           :: go tat ca
CaiDat.cmd -All -Dir2027 "D:\ADSCivil 2027" -Dir2026 "D:\ADSCivil 2026"   :: thu muc cai khac mac dinh
```

Từng bước riêng nằm trong `scripts\` (`setup-codex.ps1`, `setup-gemini.ps1`, `install-2026-autoload.ps1`, `test-mcp.ps1`).

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
CaiDat.cmd     bấm đúp để cài (menu)
VERSION
scripts/   installer.ps1 (menu), setup-codex.ps1, setup-gemini.ps1, install-2026-autoload.ps1, test-mcp.ps1
codex/     AGENTS.md, config.example.toml
gemini/    GEMINI.md, Mo Gemini ADSCivil.cmd, settings.example.json
claude/    claude_desktop_config.example.json
zwcad/     ads-ai-autoload.lsp
```
