# netaudit.sreeb.dev

The **website + installer** for [NetAudit](https://github.com/sreebalakrishnan/netaudit)
— a native macOS network audit + Wi-Fi safety checker. This repo is *only* the
public face: the landing page and the `curl | bash` installer. No app code lives
here. Deployed via Hostinger Git deploy at <https://netaudit.sreeb.dev>.

## How the three repos fit together

NetAudit is intentionally split across three repos, each with one job. Keeping
them separate is normal — the trick is knowing which one you touch for what.

| Repo | What it is | You touch it to… |
|---|---|---|
| [`netaudit`](https://github.com/sreebalakrishnan/netaudit) | **The app.** Python/rumps/WKWebView source, `build.sh`, issues, releases. The canonical project. | change the app, cut a release (DMG → GitHub Releases) |
| **`netaudit.sreeb.dev`** (this repo) | **The website + installer.** Landing page and `install.sh`. | edit the page or the curl installer |
| [`homebrew-netaudit`](https://github.com/sreebalakrishnan/homebrew-netaudit) | **The Homebrew tap.** One cask `.rb`. Must be named `homebrew-netaudit` so `brew install sreebalakrishnan/netaudit/netaudit` resolves. | bump version + sha on each release (ideally automated) |

```
                 build.sh
   netaudit  ─────────────▶  GitHub Release (NetAudit-X.Y.Z.dmg)
  (the app)                          │
                                     │ download URL
                 ┌───────────────────┼───────────────────┐
                 ▼                   ▼                    ▼
        netaudit.sreeb.dev     install.sh          homebrew-netaudit
        (download button)    (curl | bash)         (cask points at it)
```

The DMG is the single shared artifact. **It lives on GitHub Releases in the
`netaudit` repo** — everything else just links to it. Use the stable "latest"
URL so links never need editing:

```
https://github.com/sreebalakrishnan/netaudit/releases/latest/download/NetAudit.dmg
```

## What's in this repo

| File | Purpose |
|---|---|
| `index.html` + `style.css` | Landing page |
| `install.sh` | One-line installer (`curl … \| bash`). Downloads the DMG, copies the .app into `/Applications`, strips Gatekeeper quarantine, and symlinks the `netaudit` CLI onto `PATH`. |
| `INSTALL.md` | Manual install guide for people who'd rather double-click the DMG. Includes CLI-vs-GUI usage. |
| `docs/cli-and-gui.md` | Spec for shipping NetAudit as both a `netaudit` CLI and the GUI from one Homebrew cask (source-repo entry point + cask `binary` stanza). |
| `favicon.icns` | App icon (also usable as og:image). |

> **Note:** DMGs are no longer committed here — they're GitHub Release assets in
> the `netaudit` repo (see above). The legacy `NetAudit-0.8.0.dmg` in this repo
> can be removed once 0.8.0 is published as a release and the links below point
> at the Releases URL.

## CLI + GUI from one install

A Homebrew user runs one command and gets both a `netaudit` terminal command and
the menu-bar GUI. The mechanism is a single cask with a `binary` stanza (no
separate formula); the app's entry point dispatches on `argv` — a subcommand/flag
runs the audit in the terminal, no args (or `netaudit gui`) launch the GUI. The
distribution side (`install.sh`, landing page, `INSTALL.md`) lives here; the
entry-point and cask changes live in the `netaudit` and `homebrew-netaudit` repos
— see [`docs/cli-and-gui.md`](docs/cli-and-gui.md).

## Per-release flow

With DMGs on GitHub Releases, a release no longer copies files between repos:

```bash
# 1. In the netaudit (app) repo — build and publish the DMG as a release asset.
cd ~/Developer/netaudit
./build.sh                                   # produces NetAudit-X.Y.Z.dmg
gh release create vX.Y.Z NetAudit-X.Y.Z.dmg \
    --title "NetAudit X.Y.Z" --notes "…"
# (Also upload/symlink it as NetAudit.dmg so the /latest/download/ URL is stable.)

# 2. Bump the tap — version + sha256 in homebrew-netaudit/Casks/netaudit.rb.
#    Best automated from netaudit's release workflow; otherwise:
shasum -a 256 NetAudit-X.Y.Z.dmg            # paste into the cask

# 3. This repo only changes if the page copy or installer changed.
#    The version number on the landing page is the usual edit.
```

No DMG copy, no `install.sh`/`INSTALL.md` duplication across repos.

To make step 1+2 fully automatic (one `git tag` builds the DMG, publishes the
release, and opens the tap bump PR), see [`docs/release-automation.md`](docs/release-automation.md)
— a drop-in GitHub Actions workflow for the `netaudit` repo.
