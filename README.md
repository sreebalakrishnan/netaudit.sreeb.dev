# netaudit.sreeb.dev

Landing page + download host for [NetAudit](https://github.com/sreebalakrishnan/netaudit) — a native macOS **desktop (GUI) app** for network auditing + Wi-Fi safety checking.

> **NetAudit is a GUI application, not a command-line tool.** You install it into `/Applications` and launch it like any other Mac app (double-click, or open from Launchpad/Spotlight). The `install.sh` one-liner and Homebrew cask below are just convenience ways to *download and install* the app — they don't run it from the terminal. NetAudit itself is built in Ruby.

Deployed via Hostinger Git deploy.

## What's here

| File | Purpose |
|---|---|
| `index.html` + `style.css` | Landing page (placeholder — to be designed) |
| `NetAudit-0.8.0.dmg` | Current release. Linked from the page; pulled by `install.sh`; pulled by the Homebrew cask. |
| `install.sh` | One-line installer (`curl … \| bash`). Downloads the DMG, copies the .app into /Applications, strips Gatekeeper quarantine. |
| `INSTALL.md` | Manual install guide for people who'd rather double-click the DMG. |
| `favicon.icns` | App icon (also usable as og:image). |

## Per-release update flow

When NetAudit ships a new version:

```bash
# In the netaudit repo:
cd ~/Developer/netaudit
./build.sh                                # produces NetAudit-X.Y.Z.dmg

# Copy the artifacts into this repo:
cd ~/Developer/netaudit.sreeb.dev
cp ~/Developer/netaudit/NetAudit-*.dmg .
cp ~/Developer/netaudit/install.sh .       # if it changed
cp ~/Developer/netaudit/INSTALL.md .       # if it changed
# Update version reference in index.html if needed.

git add . && git commit -m "Release NetAudit X.Y.Z"
git push                                   # Hostinger picks it up
```

## Why the DMG lives in the repo

So Hostinger's Git deploy serves it at `https://netaudit.sreeb.dev/NetAudit-<version>.dmg` — that exact URL is what:

- The Homebrew cask formula points at (`homebrew/Casks/netaudit.rb` in the source repo)
- `install.sh` defaults to
- The landing page's download button will link to

The DMG is ~35 MB; per-version commits are fine. If the repo gets bloated over many releases, we can shift older DMGs to GitHub Releases and keep only the current version in the repo.
