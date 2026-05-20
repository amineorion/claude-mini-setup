# claude-mini-setup

Run **Claude Code on a spare Mac**, always on, and reach it from your laptop and
phone over a private [Tailscale](https://tailscale.com) network — with push
notifications when Claude needs you.

Each project gets its own Claude session that never stops. Close the laptop,
lose WiFi, walk away — then pick up on your phone, same live session.

```
        ┌──────────────┐              ┌──────────────┐
        │  Personal PC │              │     Phone     │
        │   (laptop)   │              │ Termius/Blink │
        │    cmini     │              │   ssh + ct    │
        └──────┬───────┘              └──────┬────────┘
               │      Tailscale (private,    │
               │      encrypted, SSH)        │
               └──────────────┬──────────────┘
                              │
                    ┌─────────▼──────────┐
                    │   SERVER (a Mac)   │
                    │  tmux sessions:    │
                    │  project-a  …      │  one Claude per project,
                    │  (always running) │  always running
                    └─────────┬──────────┘
                              │  ntfy push
                              ▼
                    🔔  "project-a needs input"
```

## How it works

The sessions live on the **server**. Your laptop and phone are just windows in.

- `tmux` keeps each Claude process alive on the server between connections.
- **Tailscale SSH** is how a device attaches — no passwords, no keys, no ports
  exposed to the public internet.
- `ct` (on the server) attaches to or creates a session.
- `cmini` (on the laptop) is a picker that SSHes in and runs `ct`.
- [ntfy](https://ntfy.sh) delivers the push notifications.

## What you need

- A **server**: any Mac that can stay powered on (a Mac mini is ideal), with
  [Homebrew](https://brew.sh) and Claude Code installed and signed in.
- A free **Tailscale** account, with every device signed into it.
- An SSH app on your phone (Termius or Blink) and the ntfy app.

## Repo layout

```
config.sh            all settings in one place — EDIT THIS FIRST
server/install.sh    sets up the server (Tailscale, tmux, ct, hooks, no-sleep)
server/sessions.sh   start / list / restart / stop the project sessions
server/ct            session helper, installed to ~/.local/bin/ct
client/install.sh    sets up a laptop (SSH config, cmini launcher)
client/cmini         session picker, installed to /usr/local/bin/cmini
```

---

## Step 0 · Configure (do this once)

Clone the repo and edit `config.sh` — every script reads it:

```bash
git clone https://github.com/amineorion/claude-mini-setup.git
cd claude-mini-setup
```

Open `config.sh` and set:

| Setting       | Set it to                                              |
|---------------|--------------------------------------------------------|
| `SERVER_HOST` | your server's Tailscale machine name                   |
| `SERVER_USER` | your macOS username on the server                      |
| `NTFY_TOPIC`  | a long random topic — generate it on the server with `echo "claude-$(openssl rand -hex 12)"` |
| `PROJECTS`    | your project folder names (live under `~/workspaces`)  |

The `NTFY_TOPIC` is a **shared secret** — anyone who knows it can read and post
your notifications. Keep it private; don't commit a real one to a public repo.

---

# Part 1 · The server (always-on Mac)

Do this **on the server**, with the repo cloned and `config.sh` filled in.

```bash
cd claude-mini-setup/server
./install.sh
```

`install.sh` installs Tailscale + tmux, enables Tailscale SSH, installs the `ct`
helper, adds the notification hooks, and stops the Mac from sleeping. If
Tailscale prints a `https://login.tailscale.com/...` URL, open it and approve
the machine — everything else is automatic.

Then start the always-on sessions:

```bash
./sessions.sh start     # one detached Claude per project in config.sh
./sessions.sh list      # confirm they're running
```

`sessions.sh restart` recreates them all; `sessions.sh stop` kills them.

> ⚠️ The sessions run Claude with `--dangerously-skip-permissions` — it runs
> commands without asking each time. Convenient on a personal server you trust,
> but it means Claude can change or delete files unprompted. Edit `server/ct`
> and `server/sessions.sh` to drop the flag if you'd rather keep prompts.

The server can now run headless forever.

---

# Part 2 · Your personal PC (laptop)

Do this **on the laptop**.

1. Install Tailscale and sign in with the **same account** as the server:

   ```bash
   brew install --cask tailscale
   ```

   Open the app, sign in, confirm it shows **Connected**.

2. Clone the repo, fill in the same `config.sh`, and run:

   ```bash
   cd claude-mini-setup/client
   ./install.sh
   ```

   This adds an SSH config entry, installs `cmini`, sets `CLAUDE_MINI_HOST` in
   your `~/.zshrc`, and tests the connection.

### Daily use

```bash
cmini                 # picker — lists sessions, pick a number
cmini project-a       # jump straight into a session
cmini -l              # list running sessions
cmini -k project-a    # kill a session
```

Inside a session, **Ctrl-B** then **D** detaches — the session keeps running.

### Auto-open on login (optional)

To drop straight into the picker every time you open a terminal:

1. **Terminal.app → Settings → Profiles** → new profile → **Shell** tab →
   "Run command": `cmini`
2. Click **Default**.
3. **System Settings → General → Login Items** → add Terminal.

---

# Part 3 · Your phone

The phone can't be scripted — three apps, a few taps.

1. **Tailscale** app — install, sign in with the same account, confirm
   **Connected**.

2. **SSH client** — install **Termius** (free) or **Blink Shell** (paid, best
   keyboard). Add a host:

   | Field         | Value                                      |
   |---------------|--------------------------------------------|
   | Hostname      | your server's Tailscale name (or `100.x` IP)|
   | Username      | your macOS username on the server          |
   | Port          | `22`                                       |
   | Password/key  | *leave blank*                              |

   No password — Tailscale SSH authenticates by device identity. Accept the
   host-key prompt on first connect.

3. **ntfy** app — install, tap **+** → Subscribe to topic:
   - Topic: your `NTFY_TOPIC`
   - Server: default (`ntfy.sh`)

   Allow notifications when iOS/Android asks.

### Daily use

When a push says **"project-a needs input"**, open the SSH client and:

```bash
ct -l            # list sessions
ct project-a     # attach
```

---

## tmux cheat sheet

Everything starts with the **prefix**: `Ctrl-B`, release, then the key.

| Keys             | Action                          |
|------------------|---------------------------------|
| `Ctrl-B` `D`     | Detach (session keeps running)  |
| `Ctrl-B` `S`     | Visual session switcher         |
| `Ctrl-B` `(` `)` | Previous / next session         |
| `Ctrl-B` `[`     | Scroll mode (`q` to exit)       |

## Notifications — how they work

`server/install.sh` adds two Claude Code hooks to `~/.claude/settings.json`:

- **Notification** → push when Claude is waiting for input (high priority, 🔔).
- **Stop** → push when Claude finishes a response (✅).

Both are guarded so they fire **only** for sessions running under
`~/workspaces` — other Claude runs on the server stay silent. Test it from the
server:

```bash
curl -d "test" https://ntfy.sh/YOUR_TOPIC
```

Too many pings? Remove the `Stop` block from `~/.claude/settings.json` to keep
only the "needs input" alerts.

## Troubleshooting

**`command not found: ct` over SSH** — non-interactive SSH has no `PATH`.
`cmini` already calls `ct` by absolute path; do the same in your own scripts.

**`bad interpreter: /bin/bash^M`** — a file was downloaded through a terminal
that added CRLF line endings. Re-fetch with `ssh -T` piped through `tr -d '\r'`,
and make sure `~/.ssh/config` has no `RequestTTY yes`.

**`sudo tailscale ...` says the daemon isn't running** — the menu-bar app runs
a per-user daemon. Use the `brew install tailscale` path (a system daemon), as
`server/install.sh` does.

**Can't SSH in** — on the server: `tailscale status` (online?) and
`tailscale debug prefs | grep RunSSH` (should be `true`). On the client:
Tailscale Connected, server visible in `tailscale status`.

**"Last login" banner on connect** — `touch ~/.hushlogin` on the server
(install.sh already does this).

## Security notes

- Nothing is exposed to the public internet — all traffic rides your private
  Tailscale network.
- The **ntfy topic is a shared secret**. Anyone who learns it can read your
  notifications and send fake ones. Keep it out of git and screenshots.
- `--dangerously-skip-permissions` removes Claude's per-action approval
  prompts. Understand the trade-off (see the warning in Part 1).

## Changing things

Everything lives in [`config.sh`](config.sh). Change a value, then re-run the
relevant `install.sh`.

## License

MIT — see [LICENSE](LICENSE).
