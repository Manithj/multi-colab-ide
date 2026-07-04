# multi-colab-ide

Use **multiple Google accounts** with **Google Colab CLI** inside your IDE — without credential conflicts.

Each account gets an isolated `CLOUDSDK_CONFIG` profile. Launch your IDE through `multi-colab-ide`, and every integrated terminal, extension, and MCP server in that window uses the correct Google identity.

Works on **Linux**, **macOS**, and **WSL**. Supports **bash** and **zsh**.

---

## Why this exists

Google Colab CLI authenticates via Application Default Credentials (ADC). By default, all tools share one gcloud config — so switching accounts breaks sessions, agents, and terminal commands.

This toolkit gives each Google account its own credential directory and makes it easy to:

- Launch your IDE bound to a specific account
- Run `colab --auth=adc` without prefixing environment variables
- Switch accounts per terminal session
- Keep Colab session state separate per account

---

## Requirements

| Tool | Purpose |
|------|---------|
| [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) (`gcloud`) | Authentication |
| [Colab CLI](https://github.com/googlecolab/colab-cli) (`pip install colab-cli`) | Colab sessions |
| bash or zsh | Shell |
| Your IDE CLI in PATH | e.g. `code`, `codium`, `windsurf` (see Cursor note below) |

---

## Quick start

```bash
git clone https://github.com/YOUR_USER/multi-colab-ide.git
cd multi-colab-ide
chmod +x install.sh
./install.sh
```

### First-time auth (once per account)

```bash
mci-setup 1
mci-setup 2
mci-setup 3
```

### Daily use

```bash
multi-colab-ide        # pick account from menu → IDE opens
multi-colab-ide 2      # launch IDE with account 2
mci-verify             # check active account
```

---

## Configure your IDE

Edit `~/.config/multi-colab-ide/ide.conf`:

```bash
IDE_COMMAND="code"      # VS Code
IDE_ARGS=""             # optional, e.g. "--new-window"
```

**Cursor preset** — Cursor has no built-in CLI (unlike `code`). Create a launcher script first:

```bash
cp config/cursor-launcher.example.sh ~/.local/bin/cursor
chmod +x ~/.local/bin/cursor
# Edit ~/.local/bin/cursor — set your AppImage or binary path
cp config/ide.conf.cursor.example ~/.config/multi-colab-ide/ide.conf
```

Examples:

| IDE | `IDE_COMMAND` | Notes |
|-----|----------------|-------|
| VS Code | `code` | Built-in CLI |
| Cursor | `$HOME/.local/bin/cursor` | **Custom launcher required** — use `cursor-launcher.example.sh` |
| VSCodium | `codium` | Built-in CLI |
| Windsurf | `windsurf` | Built-in CLI |
| IntelliJ | `idea` | Built-in CLI |

---

## Commands

| Command | Description |
|---------|-------------|
| `multi-colab-ide [id] [args]` | Launch IDE with selected Google profile |
| `mci-setup <id>` | Authenticate one account |
| `mci-switch <id>` | Switch account in current shell (`source` it) |
| `mci-verify` | Show active credentials and profiles |
| `./uninstall.sh` | Remove symlinks and shell hooks |

---

## Shell support (bash & zsh)

`install.sh` adds a hook to both `~/.bashrc` and `~/.zshrc` (if they exist).

New terminals auto-load the last selected profile from:

```
~/.config/multi-colab-ide/active
```

Switch manually in any session:

```bash
source mci-switch 2
```

Or:

```bash
eval "$(mci-switch 2)"
```

---

## WSL

WSL is detected automatically. If the browser does not open during setup:

```bash
mci-setup 1 --no-launch-browser
```

Copy the printed URL into your **Windows** browser, complete sign-in, and paste the authorization code back into the WSL terminal.

Tips for WSL:

- Install `gcloud` inside WSL (not only on Windows)
- Use `mci-verify` to confirm the active account
- Launch the IDE from WSL so integrated terminals inherit the profile:

  ```bash
  multi-colab-ide 2 /path/to/project
  ```

---

## Account layout

Edit `accounts.conf` (created from `accounts.conf.example` on install):

```
1|work@gmail.com|~/.config/gcloud-account1
2|personal@gmail.com|~/.config/gcloud-account2
3|lab@company.io|~/.config/gcloud-account3
```

| Path | Purpose |
|------|---------|
| `accounts.conf` | Account menu labels and config paths |
| `~/.config/gcloud-accountN/` | Isolated gcloud + ADC per account |
| `~/.config/gcloud-accountN/colab-cli/` | Colab session state per account |
| `~/.config/multi-colab-ide/active` | Last selected profile |
| `~/.config/multi-colab-ide/ide.conf` | IDE launcher settings |

---

## Colab CLI notes

- Prefer **`--auth=adc`** (Application Default Credentials).
- OAuth2 tokens live at `~/.config/colab-cli/token.json` (shared). ADC keeps accounts isolated.
- The `colab` wrapper installed by this toolkit auto-loads your active profile.

```bash
colab --auth=adc whoami
colab --auth=adc sessions
```

---

## ADC scopes

`mci-setup` runs:

```bash
gcloud auth application-default login \
  --scopes=openid,https://www.googleapis.com/auth/cloud-platform,https://www.googleapis.com/auth/userinfo.email,https://www.googleapis.com/auth/colaboratory
```

---

## Troubleshooting

### `colab --auth=adc whoami` fails

```bash
mci-verify
mci-setup <id>
source mci-switch <id>
```

### Wrong account in IDE terminals

Restart the IDE via `multi-colab-ide <id>` so child processes inherit `CLOUDSDK_CONFIG`.

### Migrate existing gcloud config to account 1

```bash
cp -a ~/.config/gcloud ~/.config/gcloud-account1
mci-setup 2
mci-setup 3
```

### Uninstall

```bash
./uninstall.sh
```

---

## Project structure

```
multi-colab-ide/
├── install.sh
├── uninstall.sh
├── multi-colab-ide      # IDE launcher with account menu
├── mci-setup            # Authenticate one profile
├── mci-switch           # Switch shell profile
├── mci-verify           # Verify credentials
├── colab-wrap           # colab CLI wrapper
├── env.sh               # Shell auto-load hook
├── lib/
│   ├── common.sh
│   ├── load-profile.sh
│   └── platform.sh      # WSL / platform helpers
├── config/
│   ├── ide.conf.example
│   ├── ide.conf.cursor.example
│   └── cursor-launcher.example.sh
├── accounts.conf.example
└── README.md
```

---

## License

MIT — see [LICENSE](LICENSE).

---

## Tests

Run the full test suite (isolated temp HOME — does not modify your config):

```bash
./tests/run-tests.sh
```
