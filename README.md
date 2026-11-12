# Agents — Remote Coding Client

Ứng dụng Flutter điều khiển các phiên Claude Code, Codex và OpenCode trên máy từ xa. UI sử dụng shadcn_ui; màn hình chính là Chat, vuốt trái để xem Sessions, vuốt phải để quay lại.

## Web Preview trong ModelScope Studio

**Mở Web Preview mặc định, cổng 7860, đường dẫn /**. Nginx của workspace hiện proxy root đến server Flutter ở port 3000. Không cần mở /port/3000/ nữa.

Nếu workspace restart: từ ~/agents-client chạy rtk flutter build web --release --base-href /, sau đó chạy python3 -m http.server 3000 --bind 0.0.0.0 --directory build/web. Studio cần nginx route root / tới 127.0.0.1:3000 (đã thiết lập trong workspace hiện tại).

**Browser là UI preview**: trình duyệt không mở TCP SSH trực tiếp. Muốn điều khiển SSH trên web cần authenticated SSH/WebSocket gateway + TLS. Không nhập SSH secret vào web preview.

## Native SSH — Hướng dẫn

1. Settings → Connections → Add host; nhập hostname, username và port.
2. Nhấn Connect, nhập password hoặc private key PEM. Có thể chọn lưu credential trong OS secure storage (chỉ native).
3. Xác minh SHA256 SSH host key fingerprint, sau đó Trust. Fingerprint thay đổi luôn bị từ chối.
4. Sau khi kết nối, ứng dụng kiểm tra tmux và agent CLI có trong PATH.
5. Sessions → New → chọn agent, SSH host đã kết nối và working directory.
6. Phiên agent chạy bên trong tmux. Terminal có PTY tương tác (xterm), Esc/Tab/Ctrl+C và resize.
7. Chat gửi prompt một dòng vào tmux; xem phản hồi thật trong Terminal. Structured events chưa được hỗ trợ.
8. Refresh Sessions để phát hiện các phiên còn chạy. Đóng Terminal chỉ detach. Terminate có hộp xác nhận trước khi kill.
9. Changes hiển thị Git status chỉ đọc. Auto reconnect dùng credential được lưu chủ đích cùng fingerprint đã xác minh.

Remote host cần SSH daemon, tmux và ít nhất một CLI (claude, codex hoặc opencode) trong PATH. Ưu tiên VPN/Tailscale và bảo vệ SSH.

## Đã triển khai

Feature-first UI, shadcn_ui toàn app, Settings và host profiles lưu locally, secure credentials opt-in, host key pinning, SSH/tmux session runtime, xterm PTY, local session registry, reconnect, terminate và Git status. Network permissions được cấu hình cho Android/iOS/macOS.

## Giới hạn

- Structured native protocols của từng agent (history, tool events, approval API, resume, model selection) chưa triển khai. Terminal fallback vẫn giữ nguyên CLI permission prompts.
- Web SSH gateway và push notifications khi ứng dụng đóng chưa có; cần backend/relay.
- Chưa xác thực end-to-end trên SSH host thật của người dùng, chưa chạy trên thiết bị iOS/Android vật lý.
- Các phiên mẫu trong UI vẫn là demo; app không ngụy tạo output của phiên thật.

## Development

Từ ~/agents-client chạy: rtk flutter pub get, rtk flutter test, rtk flutter analyze và rtk flutter build web --release --base-href /.

Xem PLANS.md để biết phần đã làm và phần còn lại.



## Profile-first usage

1. Settings -> Connections: save an SSH host, and connect using the native application.
2. Swipe left on Chat to open Sessions. Tap the Profile selector at the top.
3. Create a profile by picking an SSH host and one coding agent: Claude Code, Codex, or OpenCode.
4. Selecting a profile fetches its provider-owned sessions from that SSH host (rather than showing only this application's tmux sessions).
5. Tap a listed session to read bounded saved chat history when available. Tap Terminal to resume the original session inside tmux; CLI permission prompts remain active.
6. In the profile picker, edit or remove a profile without changing provider data on the server.

Claude/Codex session discovery currently reads their native JSONL session storage in read-only mode; OpenCode uses its official JSON CLI session list command. This is the first compatible implementation rather than a claim that the two JSONL stores are official public listing APIs. First page is currently capped at 40 sessions.

Structured-agent reference: https://github.com/starfall-org/serverside-generative (see docs/structured-agents.md). That project's in-memory agent_list is not a list of all provider sessions on disk; full native structured control is not yet integrated here. See docs/profile-session-architecture.md.

Web Preview: open the ModelScope Studio preview on default port 7860 with path /. The workspace internally proxies it to port 3000. The root HTML and JavaScript both return HTTP 200 within the workspace; external browser access depends on ModelScope Studio routing. A browser cannot directly open raw SSH sockets.



## OpenCode HTTP profiles (2026-11-12)

Profiles are managed under **Settings → Profiles**. The selector at the top of **Sessions** only chooses an existing profile; it never edits or deletes configuration.

For Claude Code/Codex, the profile uses SSH. For OpenCode, the profile editor offers **SSH** and **HTTP API**:

- SSH: choose a saved SSH host (unchanged).
- HTTP API: **do not choose SSH host**. Enter the OpenCode server URL, username (default `opencode`) and optional Basic-auth password. The URL and username are non-secret profile metadata; the password is never in profile JSON or SharedPreferences.
- Password storage: native uses `flutter_secure_storage`/OS credential vault; browser keeps password in memory only until page reload. Changing the HTTP URL or username without supplying a new password clears the old secret to avoid sending it to another origin.
- Security: remote HTTP profiles require **HTTPS**; `http://localhost` and `http://127.0.0.1` are allowed for local testing. Redirects are rejected, and HTTP responses are limited to 1 MiB with timeouts.

For OpenCode HTTP the app uses the server's documented REST API (no SSH or tmux):

| Action | HTTP endpoint |
| --- | --- |
| List sessions | `GET /session` |
| Session messages | `GET /session/:id/message?limit=40` |
| New session | `POST /session` with a title |
| Send prompt | `POST /session/:id/prompt_async` with text parts |

API reference: https://opencode.ai/v1/docs/server/. OpenCode versions may change endpoint behavior; integration is implemented to the documented V1 REST API and needs real-server validation. The HTTP profile does not offer a raw SSH terminal, remote SFTP, or tmux management. For Flutter Web, the OpenCode server must explicitly permit the browser origin through CORS; mixed-content policy prevents an HTTPS web app from using plaintext remote HTTP.


## SSH via WebSocket proxy (2026-11-13)

In Settings > Connections > Add/Edit SSH host, select either Direct TCP or WebSocket proxy. A WebSocket SSH host retains the real SSH hostname, port and username for host-key verification, and adds a gateway URL such as wss://gateway.example.com/ssh. Remote gateways must use WSS; unencrypted WS is permitted only for loopback development.

WebSocket headers: tap Add header to enter any name/value pairs (up to 32), including Authorization, Origin, Cookie, Cloudflare-Access-Client-Id, Cloudflare-Access-Client-Secret, User-Agent and X-* fields. Remove header rows individually. Protocol-managed fields (Connection, Upgrade, Host, Sec-WebSocket-*, Content-Length, Transfer-Encoding), duplicate names and header injection are rejected.

The host metadata stores header names only; header values (which may contain bearer tokens) are saved in the native OS secure credential vault, not in SharedPreferences. Browser values are in memory only. Browser WebSocket APIs cannot send custom handshake headers, so use the native app for header-protected gateways, or a gateway-supported browser auth design. Browser WebSockets without custom headers are supported; direct browser TCP SSH is not.

The bridge must forward raw SSH byte streams in BINARY WebSocket frames, rather than messages, base64, JSON or a shell. SSH authentication and SSH host-key pinning are still performed by the client and are not replaced by proxy TLS authentication. Avoid exposing an unauthenticated arbitrary SSH TCP gateway.

Local automated tests cover binary byte roundtrips and custom Authorization headers. The feature is not yet tested with a real user-supplied SSH WebSocket gateway.
