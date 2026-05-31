# Release automation — `netaudit` repo

> This spec lives in the **site** repo for reference, but the files below belong
> in the **`sreebalakrishnan/netaudit` (app)** repo. Copy them there. Nothing in
> this doc runs from `netaudit.sreeb.dev`.

Goal: one `git tag` cuts a release. The workflow builds the DMG, publishes it as
a GitHub Release asset (versioned **and** as a stable `NetAudit.dmg`), then opens
a PR against the tap bumping `version` + `sha256`. After that, `install.sh`, the
cask, and the landing button all resolve to the new build with **zero** manual
file copying.

```
git tag v0.9.0 && git push --tags
        │
        ▼
 .github/workflows/release.yml  (in netaudit repo, runs on macOS)
        │  build.sh → NetAudit-0.9.0.dmg
        ├──▶ GitHub Release v0.9.0
        │      • NetAudit-0.9.0.dmg   (versioned, immutable)
        │      • NetAudit.dmg         (same bytes — stable "latest" URL)
        └──▶ PR to homebrew-netaudit: bump version + sha256
```

The two stable URLs everything points at:

```
https://github.com/sreebalakrishnan/netaudit/releases/latest/download/NetAudit.dmg      # install.sh, landing button
https://github.com/sreebalakrishnan/netaudit/releases/download/v0.9.0/NetAudit-0.9.0.dmg # cask (pinned per version)
```

---

## 1. `.github/workflows/release.yml`

```yaml
name: Release

on:
  push:
    tags:
      - "v*.*.*"

permissions:
  contents: write          # create the release + upload assets

jobs:
  build:
    runs-on: macos-14      # Apple Silicon runner
    steps:
      - uses: actions/checkout@v4

      - name: Derive version from tag
        id: ver
        run: echo "version=${GITHUB_REF_NAME#v}" >> "$GITHUB_OUTPUT"

      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"

      - name: Build the DMG
        run: ./build.sh          # must emit NetAudit-${version}.dmg in repo root

      - name: Stage release assets
        id: assets
        run: |
          set -euo pipefail
          V="${{ steps.ver.outputs.version }}"
          SRC="NetAudit-${V}.dmg"
          test -f "$SRC" || { echo "::error::build.sh did not produce $SRC"; exit 1; }
          # Stable "latest" copy so /releases/latest/download/NetAudit.dmg works.
          cp "$SRC" "NetAudit.dmg"
          SHA=$(shasum -a 256 "$SRC" | awk '{print $1}')
          echo "sha256=$SHA"   >> "$GITHUB_OUTPUT"
          echo "dmg=$SRC"      >> "$GITHUB_OUTPUT"

      - name: Publish GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          files: |
            NetAudit-${{ steps.ver.outputs.version }}.dmg
            NetAudit.dmg
          generate_release_notes: true

      - name: Bump the Homebrew tap
        env:
          # Fine-grained PAT with contents:write on homebrew-netaudit.
          # Store it as a repo secret named TAP_TOKEN.
          GH_TOKEN: ${{ secrets.TAP_TOKEN }}
        run: |
          set -euo pipefail
          V="${{ steps.ver.outputs.version }}"
          SHA="${{ steps.assets.outputs.sha256 }}"
          git clone "https://x-access-token:${GH_TOKEN}@github.com/sreebalakrishnan/homebrew-netaudit.git" tap
          cd tap
          CASK="Casks/netaudit.rb"
          # Replace the version "..." and sha256 "..." lines.
          /usr/bin/sed -i '' -E "s/version \"[^\"]*\"/version \"${V}\"/" "$CASK"
          /usr/bin/sed -i '' -E "s/sha256 \"[^\"]*\"/sha256 \"${SHA}\"/" "$CASK"
          git config user.name  "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          BRANCH="bump-${V}"
          git checkout -b "$BRANCH"
          git commit -am "netaudit ${V}"
          git push -u origin "$BRANCH"
          gh pr create --repo sreebalakrishnan/homebrew-netaudit \
            --title "netaudit ${V}" \
            --body "Automated bump to ${V}. sha256 \`${SHA}\`." \
            --head "$BRANCH" --base main
```

> **Why a PR, not a direct push to the tap?** It gives you a one-click review and
> keeps `brew audit`/CI (if any) in the loop. If you'd rather it be fully hands-off,
> swap the last step for a direct `git commit -am … && git push origin main`.

### Secrets you need

- **`TAP_TOKEN`** — a fine-grained PAT scoped to `homebrew-netaudit` with
  *Contents: read/write* and *Pull requests: read/write*. Add it under
  `netaudit` → Settings → Secrets → Actions. (The default `GITHUB_TOKEN` can't
  reach a *second* repo, hence a PAT.)

### `build.sh` contract

The workflow assumes `./build.sh` emits `NetAudit-${version}.dmg` in the repo
root. If it currently writes elsewhere or derives the version differently, either
adjust `build.sh` or tweak the `SRC=` path above. Keep the version in one place —
ideally `build.sh` reads it from the tag (`$GITHUB_REF_NAME`) or a `VERSION` file
so the tag, DMG name, and Info.plist never drift.

---

## 2. Tap cask shape it expects

`homebrew-netaudit/Casks/netaudit.rb` should have `version`/`sha256` on their own
lines (so the `sed` bumps are clean) and a versioned URL:

```ruby
cask "netaudit" do
  version "0.9.0"
  sha256 "abc123…"   # bumped by the workflow

  url "https://github.com/sreebalakrishnan/netaudit/releases/download/v#{version}/NetAudit-#{version}.dmg"
  name "NetAudit"
  desc "Should I join this Wi-Fi? — network + Wi-Fi safety checker"
  homepage "https://netaudit.sreeb.dev"

  app "NetAudit.app"
  binary "#{appdir}/NetAudit.app/Contents/MacOS/netaudit", target: "netaudit"

  zap trash: ["~/.netaudit"]
end
```

(The `binary` stanza is what gives brew users the `netaudit` CLI — see
`cli-and-gui.md`.)

---

## 3. One-time migration (flip site + curl to Releases)

Do this once, *after* the first release is live and the
`/releases/latest/download/NetAudit.dmg` URL returns the DMG:

1. **`install.sh`** (this repo) — change the `DMG_URL` default from the
   `netaudit.sreeb.dev/NetAudit-0.8.0.dmg` fallback to
   `https://github.com/sreebalakrishnan/netaudit/releases/latest/download/NetAudit.dmg`.
2. **`index.html`** (this repo) — point the "Manual DMG" download link at the
   same Releases URL (or the versioned one), and drop the committed
   `NetAudit-0.8.0.dmg`.
3. Confirm `brew install --cask sreebalakrishnan/netaudit/netaudit`, the curl
   one-liner, and the download button all pull the release build.

Until then, everything keeps working off the DMG currently in this repo.

---

## 4. Release checklist (steady state)

```bash
# In the netaudit (app) repo:
#   bump VERSION / Info.plist if build.sh doesn't read it from the tag
git tag v0.9.0
git push origin v0.9.0
#   → workflow builds, publishes the release, opens the tap bump PR
#   → review/merge the tap PR (or auto if you chose direct-push)
brew update && brew upgrade --cask netaudit   # verify
```
