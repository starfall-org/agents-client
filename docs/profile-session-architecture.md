# Agent profiles and native session control

## Profile model

Each profile stores a non-secret combination: profile ID/name, SSH host ID,
and the coding-agent kind (Claude Code, Codex or OpenCode). Multiple profiles
may share one host. The active profile ID is persisted in preferences. No keys,
passwords or model API tokens belong in a profile.

Sessions page starts with a **Profile** selector. Selecting a profile replaces
the visible session list, resets selected conversation state, and requests a
fresh provider catalog from that profile's SSH host. An offline SSH host shows a
real connection error rather than listing fabricated sessions.

## Provider-owned session catalog

The app's tmux registry is *not* the source of truth for the main list.

| Provider | Read-only list source | Resuming a selected conversation |
| --- | --- | --- |
| Claude Code | Existing JSONL transcripts under the provider's `~/.claude/projects` directory, excluding subagent IDs | `claude --resume <sessionId>` inside tmux |
| Codex | Existing rollout JSONL under `~/.codex/sessions`; parse provider session metadata | `codex resume <sessionId>` inside tmux |
| OpenCode | Official CLI `opencode session list --format json --max-count 40` | `opencode --session <sessionId>` inside tmux |

The initial catalog is intentionally capped at **40** records per provider.
Version changes may require updating JSONL parsing or CLI output handling.
Claude and Codex do not expose a stable cross-version CLI JSON session-list
command; read-only inspection of their native session store is a fallback,
**not a claim of an official public listing API**.

On selection, the app attempts to show a bounded recent extract of the actual
provider conversation. The UI never fabricates a chat reply for a remote
provider. Missing/unsupported history leaves the chat empty while Terminal
offers native resume.

## Applying the serverside-generative reference

Reference: https://github.com/starfall-org/serverside-generative
(doc: `docs/structured-agents.md`).

The project differentiates *structured native agent sessions* from PTY/terminal
sessions. Its `agent_open`, `agent_send`, `agent_events`,
`agent_respond`, `agent_interrupt`, `agent_list`, and `agent_close` API
operates over an authenticated, certificate-pinned TLS stream. Native backends:

- Claude Code: bidirectional stream JSON with control requests.
- Codex: app-server JSON-RPC with thread/turn notifications and approval IDs.
- OpenCode: private local HTTP + SSE with per-process credentials.

**Important:** The reference's `agent_list` lists sessions *owned by that
daemon in RAM*, not every saved provider session on disk. It is therefore not
substituted for the provider catalog.

Future optional structured transport should implement these semantics through
a separate adapter, with explicit handshake/pairing, certificate pinning,
reconnection event cursors, response ID matching and approval authorization.
The current native MVP continues to use SSH/tmux to resume provider-owned
sessions and retain their normal CLI permission prompts. It does not claim
structured agent approvals or live typed tool events.

## Platform constraints

Web does not have access to arbitrary TCP SSH sockets. An authenticated,
TLS-protected SSH or agent gateway is required; the running web page is a UI
preview. Do not add an unauthenticated raw SSH bridge.



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
