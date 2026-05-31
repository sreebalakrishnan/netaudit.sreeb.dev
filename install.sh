#!/usr/bin/env bash
# One-line installer for NetAudit.
#
# Usage:
#   curl -fsSL https://netaudit.sreeb.dev/install.sh | bash
#
# What it does:
#   1. Downloads the latest NetAudit DMG to a temp file
#   2. Mounts it
#   3. Copies NetAudit.app into /Applications (overwriting any existing copy)
#   4. Strips the macOS quarantine attribute so Gatekeeper doesn't block launch
#   5. Symlinks the `netaudit` CLI onto your PATH (runs the audit in the terminal;
#      `netaudit gui` or no args launches the GUI)
#   6. Unmounts and cleans up
#
# No sudo required. The script will ask before overwriting if an existing
# NetAudit.app is in /Applications.
set -euo pipefail

# Where the DMG lives. Override with NETAUDIT_DMG_URL=... if you mirror it.
DMG_URL="${NETAUDIT_DMG_URL:-https://netaudit.sreeb.dev/NetAudit.dmg}"

APP_NAME="NetAudit.app"
DEST="/Applications/$APP_NAME"

bold() { printf "\033[1m%s\033[0m\n" "$1"; }
ok()   { printf "\033[32m✓\033[0m %s\n" "$1"; }
warn() { printf "\033[33m!\033[0m %s\n" "$1"; }
die()  { printf "\033[31m✗\033[0m %s\n" "$1" >&2; exit 1; }

bold "Installing NetAudit…"

# --- 0. Sanity checks ---
[[ "$(uname)" == "Darwin" ]] || die "NetAudit is a macOS app; this script only runs on macOS."

# --- 1. Confirm overwrite if app already exists ---
if [[ -d "$DEST" ]]; then
    INSTALLED_VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$DEST/Contents/Info.plist" 2>/dev/null || echo "?")
    warn "$DEST already exists (version $INSTALLED_VERSION)."
    if [[ -t 0 ]]; then
        read -r -p "Replace it? [y/N] " ans
        [[ "$ans" =~ ^[Yy]$ ]] || die "Aborted by user."
    else
        warn "(running non-interactively — will replace)"
    fi
fi

# --- 2. Download DMG to a temp file ---
TMP=$(mktemp -d -t netaudit-install)
trap 'rm -rf "$TMP"; [[ -n "${MOUNT:-}" && -d "$MOUNT" ]] && hdiutil detach -quiet "$MOUNT" 2>/dev/null || true' EXIT
DMG="$TMP/NetAudit.dmg"

ok "Downloading $DMG_URL …"
curl -fsSL --progress-bar "$DMG_URL" -o "$DMG" || die "Download failed."

SIZE=$(du -h "$DMG" | cut -f1)
ok "Got $SIZE."

# --- 3. Mount ---
ok "Mounting disk image…"
MOUNT=$(hdiutil attach -nobrowse -readonly "$DMG" | tail -1 | awk '{print $NF}')
[[ -d "$MOUNT/$APP_NAME" ]] || die "Mounted image doesn't contain $APP_NAME."

# --- 4. Copy ---
ok "Copying $APP_NAME → /Applications…"
[[ -d "$DEST" ]] && rm -rf "$DEST"
cp -R "$MOUNT/$APP_NAME" "/Applications/"

# --- 5. Strip quarantine so first launch doesn't trigger Gatekeeper ---
ok "Removing quarantine attribute…"
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

# --- 5.5 Symlink the CLI so `netaudit` works from the terminal ---
# The same executable inside the bundle runs the audit in the terminal when
# given a subcommand/flags (e.g. `netaudit check`, `netaudit --json`) and
# launches the GUI when run with no arguments (or `netaudit gui`). This mirrors
# what the Homebrew cask's `binary` stanza does, so curl- and brew-installed
# users get the same `netaudit` command.
CLI_LINKED=""
# Find the CLI entry point inside the bundle (py2app names it after the script).
for NAME in netaudit NetAudit; do
    if [[ -x "$DEST/Contents/MacOS/$NAME" ]]; then
        BIN_SRC="$DEST/Contents/MacOS/$NAME"
        break
    fi
done
if [[ -n "${BIN_SRC:-}" ]]; then
    # Pick the first PATH dir we can write to without sudo.
    for BIN_DIR in /opt/homebrew/bin /usr/local/bin "$HOME/.local/bin"; do
        if [[ -d "$BIN_DIR" && -w "$BIN_DIR" ]]; then
            ln -sf "$BIN_SRC" "$BIN_DIR/netaudit"
            CLI_LINKED="$BIN_DIR/netaudit"
            break
        fi
    done
    if [[ -z "$CLI_LINKED" ]]; then
        # Fall back to ~/.local/bin, creating it if needed.
        mkdir -p "$HOME/.local/bin"
        ln -sf "$BIN_SRC" "$HOME/.local/bin/netaudit"
        CLI_LINKED="$HOME/.local/bin/netaudit"
    fi
    ok "Linked CLI → $CLI_LINKED"
fi

# --- 6. Done ---
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$DEST/Contents/Info.plist" 2>/dev/null || echo "?")
ok "NetAudit $VERSION installed at $DEST"
echo
if [[ -n "$CLI_LINKED" ]]; then
    bold "Run the audit from the terminal:"
    echo "  netaudit            # quick verdict"
    echo "  netaudit --json     # machine-readable"
    case ":$PATH:" in
        *":$(dirname "$CLI_LINKED"):"*) ;;
        *) warn "$(dirname "$CLI_LINKED") isn't on your PATH — add it to use 'netaudit' directly." ;;
    esac
    echo
    bold "Or open the app (menu-bar GUI):"
    echo "  netaudit gui        # or: open -a NetAudit"
else
    bold "Launch it with:"
    echo "  open -a NetAudit"
    echo
    bold "Or just hit ⌘Space and type 'NetAudit'."
fi
