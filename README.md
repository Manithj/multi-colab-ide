# multi-colab-cli

Launch **IDE** with an isolated Google Cloud credential profile so Colab CLI, `gcloud`, and Colab MCP all use the correct Google account.

## Why this works

Each profile gets its own `CLOUDSDK_CONFIG` directory. That isolates:

- `gcloud auth login` accounts
- `gcloud auth application-default login` (ADC) — what **colab CLI** uses by default (`--auth=adc`)
- Colab session metadata (`<config>/colab-cli/sessions.json`)

When you launch the IDE through `multi-colab`, every terminal and MCP server inside that window inherits the same environment.

## Install

```bash
cd ~/multi-colab
chmod +x install.sh
./install.sh
```

## First-time auth (once per account)

```bash
setup-account 1
setup-account 2
setup-account 3
```

Each command opens a browser login and stores credentials in a separate config directory.

Edit `accounts.conf` to set friendly labels (emails are updated automatically when possible).

## Daily use

### Launch the IDE with a menu

```bash
multi-colab
```

### Launch a specific account directly

```bash
multi-colab 2
```

### Switch account in an already-open terminal

```bash
source account-switch 2
```

### Check which account is active

```bash
verify
```

## Account layout

| File / dir | Purpose |
|------------|---------|
| `accounts.conf` | Menu labels and config paths |
| `~/.config/gcloud-accountN/` | Isolated gcloud + ADC for account N |
| `~/.config/gcloud-accountN/colab-cli/` | Colab session state for account N |
| `~/.config/multi-colab/active` | Last selected profile (for `verify`) |

## Colab CLI notes

- Default auth is **ADC**, not OAuth2. Keep using ADC for agents and MCP.
- If you use `--auth=oauth2`, the OAuth token is still stored at `~/.config/colab-cli/token.json` (shared). Prefer ADC with this toolkit.
- Colab commands automatically use per-account session files when `COLAB_CLI_CONFIG` is set (done by `multi-colab` and `account-switch`).

## ADC scopes required for Colab

`setup-account` runs:

```bash
gcloud auth application-default login \
  --scopes=openid,https://www.googleapis.com/auth/cloud-platform,https://www.googleapis.com/auth/userinfo.email,https://www.googleapis.com/auth/colaboratory
```

## Troubleshooting

**`colab whoami` fails after switching**

Run `setup-account <id>` for that profile.

**Wrong account in MCP**

Restart the IDE via `multi-colab <id>` so MCP servers inherit the new `CLOUDSDK_CONFIG`.

**Migrate existing default gcloud config**

Your current `~/.config/gcloud` can become account 1:

```bash
cp -a ~/.config/gcloud ~/.config/gcloud-account1
```

Then run `setup-account` for accounts 2 and 3.
