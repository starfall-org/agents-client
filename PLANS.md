# PLANS.md — Agents Remote Coding Client

Updated: 2026-11-12
Repository: ~/agents-client
Status: **Native SSH + tmux MVP implemented; Web UI preview accessible via Studio root.**
Stack: Flutter, shadcn_ui, dartssh2, xterm, flutter_secure_storage, shared_preferences.

## Product direction

- Chat is the primary screen. Swipe left → sessions list. Swipe right → current conversation.
- Agent-first UI, terminal fallback when a native structured agent protocol is unavailable.
- SSH-first remote control, persistent tmux sessions. No custom remote daemon required for native MVP.
- Claude Code, Codex, OpenCode supported as CLI launch targets. Do not claim native structured approval/history when terminal-only.

## Completed

### Preview / UI

- [x] Feature-first architecture (app, workspace, conversation, sessions, settings, terminal, core transport, agents).
- [x] shadcn_ui dark design system across app: buttons, cards, dialogs, sheets, inputs, selects, switches, badges and toasts.
- [x] Conversation-first home, left/right swipe sessions list, keyboard/mouse navigation alternatives.
- [x] Session selection, filters, create-session dialog, tool cards, mock chat for empty installations.
- [x] Settings: general, SSH hosts, default agent/path, notification preferences, about.
- [x] Settings and non-secret SSH host profiles persist via SharedPreferences.
- [x] Web release build at base href /.
- [x] **Fixed broken ModelScope Studio preview:** port 7860, root path / now proxies the Flutter server on port 3000, while keeping /ws, /action, /port/* routes. Local HTTP verification succeeds.
- [ ] Actual browser visual QA on physical phones and desktops (widget tests cover viewport sizes; browser rendering not manually inspected).

### Native SSH / security

- [x] Direct SSH on native using dartssh2. Password or PEM key authentication.
- [x] Explicit SHA256 SSH host key trust-on-first-use, pinned by hostname:port.
- [x] Changed fingerprint always fails closed; auto reconnect cannot silently trust a new key.
- [x] Optional native OS secure credential storage. SSH secrets never enter SharedPreferences.
- [x] Connected/offline host state, CLI and tmux detection.
- [x] Android INTERNET, iOS local network disclosure, macOS sandbox network.client permission.
- [x] Auto reconnect on startup and bounded retries after dropped connection, only with opted-in vault credentials.
- [ ] End-to-end authentication tested against a user-provided SSH host (none supplied yet).
- [ ] SSH agent forwarding / keyboard-interactive auth / password rotation UI.

### Session lifecycle / terminal

- [x] CLI launch in persistent tmux using safe POSIX shell argument quoting.
- [x] tmux list, attach, detach (close PTY), refresh, and discover managed sessions.
- [x] Save only remote session metadata locally, not raw conversation content.
- [x] Single-line literal prompt delivery to tmux. Never inject a shell command for the prompt.
- [x] Live PTY/xterm emulator, user keyboard input, resizing and Ctrl+C/Esc/Tab.
- [x] Git status (read only) for remote project.
- [x] Confirmed tmux termination, separate from detach.
- [x] Capability registry for terminal-only agent adapters.
- [ ] Rebuild conversation history from agent-native event streams (no fake replies shown for real sessions).
- [ ] Session-level interrupt UX, multiple attached terminal views and reconnection tests under network loss.
- [ ] Proper git diff viewer, SFTP file browser and project explorer.

### Quality

- [x] Flutter test suite (29+ widget/unit tests) covers swipe, settings navigation, preference persistence, host key trust, shell quoting and tmux commands.
- [x] flutter analyze: no error/warning (SDK may emit info-level Material deprecations).
- [x] Flutter Web release build succeeds and web assets respond HTTP 200 from Studio port 7860.
- [ ] Android/iOS/macOS device builds and physical-device QA.
- [ ] Automated remote-host integration tests using an isolated SSH/tmux fixture.
- [ ] Accessibility tests, keyboard accessibility, long sessions and slow network performance.

## Pending architecture: ordered by value

1. **Real-host integration testing**: provision isolated SSH test host with tmux and test each CLI, host key pinning, reconnect and termination. Use test credentials only, never commit secrets.
2. **Structured agent adapters**: integrate versioned Claude Code streaming/native API, Codex App Server and OpenCode server API when supported. Add unified AgentEvent, ToolCall and Approval models; only enable approval buttons when there is an authoritative structured action. Terminal fallback remains.
3. **Secure web SSH gateway**: browser cannot open raw SSH TCP. Create authenticated WSS gateway with TLS, per-user authorization, origin checks, session isolation, rate limits, audit logging without secrets and explicit host key verification. Never expose naked SSH or raw passwords in browser storage.
4. **Productivity**: file explorer via SFTP, git diff, saved prompts and search.
5. **Notifications**: remote push requires opted-in relay/worker; ensure approvals cannot be executed by spoofed or stale notifications.
6. **Testing / release**: Android/iOS/macOS/Windows/Linux packaging, E2E and CI.

## Current limitations (important)

- The Web Preview **does not control SSH**; it is fully interactive only for UI/demo. Native platforms use real SSH.
- Structured chat messages, tool events, native approval API, session resume history and per-agent model selection are not implemented.
- Notifications preference switches do not imply push delivery; a service is required.
- Demo session content is clearly sample content; remote session output is available through Terminal and is not fabricated.
- No remote user host/credentials were supplied, so remote commands have not been exercised against a production host.

## Next UI verification

Open **ModelScope Studio Web Preview at default port 7860, path /** (not /port/3000/).
Check Chat → swipe-left Sessions → Settings → Connections → New Session → Terminal demo.
Inspect on mobile 390×844 and desktop 1280×800.

## Safety rules

- Preserve CLI permission prompts; no --dangerously-skip-permissions or auto approval.
- Require user confirmation for new host key fingerprints and termination.
- Never auto-accept changed host keys, never store secrets in insecure/shared prefs.
- Keep terminate distinct from detach. Disconnection does not prove that the agent process died.
- A session running in tmux does not prove the agent is actively generating output; label only observed lifecycle state.



## Profile-first sessions — implemented 2026-11-12

- [x] Profile model persisted locally: name, SSH host ID and one of Claude Code, Codex, OpenCode.
- [x] Sessions header includes a Profile button that opens a shadcn_ui picker.
- [x] Create, select, edit, and delete profiles; deleting a profile does NOT delete native provider sessions.
- [x] Changing profiles clears the prior list and loads the selected provider session catalog from the selected host. SSH errors and unsupported browser SSH are explicit.
- [x] Provider-owned session list: Claude Code project JSONL, Codex rollout JSONL, OpenCode CLI session list JSON. This is separate from the application's tmux registry.
- [x] Best-effort read-only recent conversation text; no invented remote replies.
- [x] Native resume into tmux using the original provider ID (claude --resume, codex resume, opencode --session), without bypassing permissions.
- [x] New session dialog locks agent and host to active profile.
- [x] Referenced starfall-org/serverside-generative/docs/structured-agents.md; distinction documented in docs/profile-session-architecture.md.
- [x] 21 Flutter tests pass, including provider listing, profile form, persistence, native CLI resume, SSH safety and session swipe.
- [x] Web build served through ModelScope Studio preview port 7860, path /; HTTP 200 confirmed locally for root and main.dart.js.
- [ ] Codex official App Server thread/list API, provider pagination, structured event streaming and approvals.
- [ ] Native real-host integration tests for all three CLIs.
- [ ] Browser SSH requires a separately authenticated TLS gateway. Web preview is UI-only.

Source of truth caveat: the reference serverside-generative agent_list enumerates only daemon-created sessions currently held in RAM. It is not a list of every persisted Claude/Codex/OpenCode session, and therefore is not used to populate Profiles.



## Profiles management and OpenCode HTTP (2026-11-12)

- [x] Move all Profile creation/edit/delete into **Settings → Profiles**. Session's Profile dialog **only selects** existing profiles.
- [x] Profile transport: SSH for Claude/Codex; OpenCode supports SSH or HTTP API.
- [x] Conditional OpenCode form: HTTP hides SSH host and shows URL, username and password.
- [x] HTTPS enforced for remote HTTP; loopback HTTP allowed for development. Basic Auth secrets use native secure vault or browser memory only, never persisted with Profile JSON.
- [x] OpenCode HTTP REST: list sessions, read messages, create sessions and send async prompts without SSH/tmux.
- [x] HTTP redirects rejected; request timeouts and response bounds enforced; profile validation retains backward compatibility with older SSH profiles.
- [x] Unit/widget tests cover conditional HTTP fields, API endpoints and Basic Auth, error handling, legacy serialization and selection-only dialog.
- [ ] End-to-end test with an authenticated remote OpenCode instance and TLS/CORS configured.
- [ ] Real-time OpenCode HTTP SSE events, permission requests and interruption flows.


## SSH WebSocket proxy and custom headers (2026-11-13)

- [x] Direct TCP and WebSocket proxy SSH transport options in Settings > Connections.
- [x] WSS remote URL validation and local WS allowance; retain original SSH host-key verification.
- [x] Dynamic arbitrary HTTP upgrade header editor (up to 32, add/remove, show/hide values).
- [x] Persist only header names with host metadata; store values in OS vault on native or RAM on web.
- [x] Native WebSocket connector forwards Authorization/Origin/Cookie/X-* and other permitted headers.
- [x] Browser WebSockets are supported without custom headers; otherwise report platform limitation clearly.
- [x] Raw SSH bytes are sent/received via binary WebSocket frames.
- [x] Model tests, UI toggle test and binary WebSocket echo roundtrip test.
- [ ] Validate with a real authenticated WebSocket-to-SSH gateway and real SSH daemon.

## Android preview packaging (2026-11-13)

- [x] Build release-mode APKs split by armeabi-v7a, arm64-v8a and x86_64.
- [x] Verify app ID, ABI, version codes and APK Signature Scheme v2 signatures.
- [x] Confirm 35/35 Flutter tests pass before packaging.
- [x] Android build environment Gradle cache permissions repaired without modifying application Gradle configuration.
- [ ] Configure a dedicated production signing key before any production release; current APKs use Flutter template debug signing and must be labeled preview/prerelease.


## Safe-area, conversation density, and lifecycle hardening (2026-11-13)

- [x] SafeArea applied to Workspace and Settings content under system-bar panel backgrounds; shadcn_ui bottom sheets already provide their own insets.
- [x] Android edge-to-edge mode, light navigation/status bar icons and coherent dark system-bar backgrounds, with NavigationBar contrast suppression.
- [x] Compact conversation header + single-row composer, smaller readable bubbles, no repeated labels/avatars, collapsed activity and no placeholder attachment button; permission approvals remain visible.
- [x] Global privacy curtain on background/inactive, including Settings; Android FLAG_SECURE prevents recent-app snapshots and screenshots.
- [x] Android backup/device transfer of application data disabled to avoid exporting encrypted credentials.
- [x] Persist per-Profile last-selected session ID and selected demo session; no plaintext chat transcripts or drafts stored in preferences.
- [x] Serialized local settings writes, preserve on-screen transcript on temporary catalog refresh errors.
- [x] Resume only verified, remembered SSH credentials for the selected Profile; avoid all-host reconnect and no automatic dangerous actions.
- [x] Pending SSH handshakes are coalesced, canceled/invalidated on disconnect or dispose; sequential sends prevent accidental double-tap.
- [x] Widget tests for system insets, compact layout, session selection after cold start, background privacy and settings; runtime unit tests for pending SSH handshakes.
- [ ] Validate startup/reconnect, system bars, and privacy with physical Android devices, real SSH servers and a production WebSocket gateway.
- [ ] iOS-specific task switcher privacy and secure backup behavior.
- [ ] Structured native agent event streaming/approvals; avoid claiming tmux output is a structured chat API.
