# Shipping NetAudit as a CLI *and* a GUI

Goal: a Homebrew user runs **one** install command and gets both

- `netaudit` on their `PATH` (runs the audit in the terminal — the natural thing
  for brew/CLI users), and
- the existing menu-bar + window **GUI** (`netaudit gui`, or `open -a NetAudit`,
  or double-click in Finder).

This is done with **one cask + a `binary` stanza** — no separate formula, no
second download. The pieces live in three repos:

| Repo | Change | Who |
|---|---|---|
| `sreebalakrishnan/netaudit` (source) | Make the app's entry point dispatch on `argv`: subcommand/flags → CLI, otherwise → GUI. Name the bundle executable so it can be symlinked as `netaudit`. | **you** |
| `sreebalakrishnan/homebrew-netaudit` (tap) | Add a `binary` stanza to the cask. | **you** |
| `netaudit.sreeb.dev` (this repo) | `install.sh` symlinks the CLI; landing page + `INSTALL.md` document it. | ✅ done |

The third column is already done in this repo. The first two are below.

---

## 1. Source repo — argument-dispatching entry point

The app is a py2app bundle (Python backend, `rumps` menu bar, `WKWebView`
window). Today the entry point launches the GUI unconditionally. Make it branch
on `sys.argv` instead:

```python
# netaudit/__main__.py  (or whatever py2app's "script" points at)
import sys

def main() -> int:
    # macOS LaunchServices may inject a "-psn_0_12345" process-serial arg when
    # the app is opened from Finder / `open`. Treat that as "no args" → GUI.
    args = [a for a in sys.argv[1:] if not a.startswith("-psn_")]

    # No args, or an explicit `gui` subcommand → launch the menu-bar app.
    if not args or args[0] == "gui":
        from netaudit.gui import run_gui   # rumps + WKWebView (current behavior)
        return run_gui()

    # Anything else → run in the terminal and exit.
    from netaudit.cli import run_cli       # argparse-based
    return run_cli(args)

if __name__ == "__main__":
    raise SystemExit(main())
```

A minimal `netaudit/cli.py`:

```python
import argparse, json
from netaudit.audit import run_audit   # the same checks the GUI calls

def run_cli(argv) -> int:
    p = argparse.ArgumentParser(prog="netaudit",
                                description="Should I join this Wi-Fi?")
    p.add_argument("command", nargs="?", default="check",
                   choices=["check", "gui"])
    p.add_argument("--json", action="store_true", help="machine-readable output")
    p.add_argument("--quiet", "-q", action="store_true", help="verdict only")
    args = p.parse_args(argv)

    result = run_audit()                 # returns the verdict + per-check details
    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print(format_verdict(result, quiet=args.quiet))   # 🟢/🟡/🔴 + lines
    # Exit code doubles as a script signal: 0 safe, 1 warn, 2 unsafe.
    return {"safe": 0, "warn": 1, "unsafe": 2}.get(result["verdict"], 0)
```

Key points:

- **GUI behavior is unchanged** — Finder/`open`/no-args all still open the window,
  so existing users notice nothing.
- The CLI calls the **same** `run_audit()` the GUI uses, so there's one source of
  truth for the checks.
- Use the **exit code** (`0/1/2`) so the command composes in scripts and CI.

### Naming the bundle executable `netaudit`

The cask `binary` stanza (below) can point at the executable under whatever name
py2app produces (default: `Contents/MacOS/NetAudit`) and re-target it as
`netaudit`, so renaming isn't strictly required. If you'd rather the in-bundle
name match, set it in `setup.py`:

```python
APP = ["netaudit/__main__.py"]
OPTIONS = {
    "argv_emulation": False,     # we parse sys.argv ourselves; keep this off
    "plist": {
        "CFBundleName": "NetAudit",
        "CFBundleExecutable": "netaudit",   # → Contents/MacOS/netaudit
        "LSUIElement": False,
    },
}
```

> Note: keep `argv_emulation` **off**. With it on, py2app swallows argv via the
> Apple-event mechanism and your CLI flags won't arrive.

---

## 2. Tap repo — add the `binary` stanza

In `homebrew-netaudit`, the cask becomes (illustrative):

```ruby
cask "netaudit" do
  version "0.8.0"
  sha256 "..."                       # shasum -a 256 NetAudit-0.8.0.dmg

  # DMGs are GitHub Release assets in the netaudit repo (not committed to the
  # site repo). Point at the versioned asset:
  url "https://github.com/sreebalakrishnan/netaudit/releases/download/v#{version}/NetAudit-#{version}.dmg"
  name "NetAudit"
  desc "Should I join this Wi-Fi? — network + Wi-Fi safety checker"
  homepage "https://netaudit.sreeb.dev"

  app "NetAudit.app"

  # This is the line that gives brew users the terminal command.
  # Point at the in-bundle executable; expose it on PATH as `netaudit`.
  binary "#{appdir}/NetAudit.app/Contents/MacOS/netaudit", target: "netaudit"
  # If you did NOT rename the executable in setup.py, use:
  #   binary "#{appdir}/NetAudit.app/Contents/MacOS/NetAudit", target: "netaudit"

  zap trash: [
    "~/.netaudit",
  ]
end
```

After this, `brew install --cask sreebalakrishnan/netaudit/netaudit` installs the
app to `/Applications` and symlinks `netaudit` into `$(brew --prefix)/bin` (on
PATH). `netaudit` runs the audit; `netaudit gui` opens the window.

> The landing page currently shows `brew install sreebalakrishnan/netaudit/netaudit`
> (no `--cask`). That works if the tap exposes it as a cask under that token;
> otherwise show `brew install --cask sreebalakrishnan/netaudit/netaudit`.

---

## 3. Sanity checklist after a release

```bash
brew install --cask sreebalakrishnan/netaudit/netaudit
which netaudit                 # → /opt/homebrew/bin/netaudit (or /usr/local/bin)
netaudit --json | head         # CLI path works, prints JSON
netaudit gui                   # GUI path works, window opens
open -a NetAudit               # Finder/LaunchServices path still opens GUI
brew uninstall --cask netaudit # removes app + the netaudit symlink
```

And for the non-Homebrew path:

```bash
curl -fsSL https://netaudit.sreeb.dev/install.sh | bash
netaudit --json                # installer symlinks the CLI too
```
