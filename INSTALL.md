# Installing NetAudit

> NetAudit is distributed without an Apple-issued certificate (no $99 fee paid). The app is safe, but macOS will warn you on first launch — here's how to get past it.

## 1. Open the disk image

Double-click the downloaded `NetAudit.dmg`. A window opens showing the **NetAudit** app and a shortcut to your **Applications** folder.

## 2. Drag NetAudit into Applications

Drag the **NetAudit** icon onto the **Applications** shortcut in that same window. Wait a few seconds for the copy to finish.

## 3. First launch — getting past Gatekeeper

If you double-click NetAudit in Applications the *normal* way, macOS will say:

> *"NetAudit" cannot be opened because the developer cannot be verified. macOS cannot verify that this app is free from malware.*

This is macOS's default response to any app not signed with a paid Apple Developer certificate. It does **not** mean the app is malware — it means it's unsigned. Choose one of the following:

### Option A — Right-click to Open (easiest, one time only)

1. In **Applications**, **right-click** (or Control-click) the **NetAudit** icon
2. Choose **Open** from the menu
3. The warning will reappear — this time with an **Open** button
4. Click **Open**

That's it. macOS remembers your choice. Every subsequent launch is a normal double-click.

### Option B — System Settings (if Option A doesn't appear)

1. Double-click NetAudit normally and dismiss the warning
2. Open **System Settings** → **Privacy & Security**
3. Scroll down — you'll see "NetAudit was blocked from use"
4. Click **Open Anyway**
5. Confirm with Touch ID / password

### Option C — Terminal (one command, for the techy)

```bash
xattr -dr com.apple.quarantine /Applications/NetAudit.app
```

This strips the "downloaded from the internet" tag that triggers Gatekeeper. After this, NetAudit launches like any other app.

## 4. What you'll see when it works

- A **NetAudit** icon appears in your dock during launch
- A **window** opens showing the network audit UI (safety check + device list)
- A **status dot** (🟢 / 🟡 / 🔴) appears in your menu bar (top-right)
- Click the menu bar dot to see the verdict at a glance, save a report, or quit

## CLI vs GUI

NetAudit ships a single executable that works two ways:

```bash
netaudit              # run the audit in the terminal, print the verdict, exit
netaudit --json       # same, machine-readable (good for scripts / cron)
netaudit gui          # launch the menu-bar + window GUI (same as: open -a NetAudit)
```

With no arguments and no subcommand, NetAudit opens the GUI — so double-clicking
the app in Finder behaves exactly as before.

**Where does the `netaudit` command come from?**

- **Homebrew** (`brew install --cask netaudit`) and the **curl one-liner** both put
  a `netaudit` symlink on your `PATH` automatically (the cask uses a `binary`
  stanza; the installer symlinks into `/opt/homebrew/bin`, `/usr/local/bin`, or
  `~/.local/bin`).
- **Manual DMG install** (drag-to-Applications) only installs the GUI. To get the
  terminal command too, symlink it yourself:

  ```bash
  ln -sf "/Applications/NetAudit.app/Contents/MacOS/netaudit" /usr/local/bin/netaudit
  ```

## 5. Why does macOS warn?

Distributing an app without a Gatekeeper warning requires:

- Apple Developer Program membership ($99/year)
- A "Developer ID Application" certificate
- Submission to Apple's notarization service

NetAudit is a personal project shared informally — none of those are in place. The warning is normal for indie / hobbyist macOS apps. The same workaround applies to many tools you might already use (e.g. older versions of Audacity, IINA, ImageOptim before they were notarized).

## Uninstalling

```bash
# Delete the app
rm -rf /Applications/NetAudit.app

# Remove the CLI symlink (wherever it landed)
rm -f /opt/homebrew/bin/netaudit /usr/local/bin/netaudit ~/.local/bin/netaudit

# Optional: delete the database and reports
rm -rf ~/.netaudit
```
