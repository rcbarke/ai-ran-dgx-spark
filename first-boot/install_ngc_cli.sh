#!/usr/bin/env bash
# install_ngc_cli.sh — ARM64 Ubuntu 18.04+ one-shot installer for NVIDIA NGC CLI
# Source reference: https://org.ngc.nvidia.com/setup/installers/cli
# Intentionally omits `ngc config` (run separately).

set -euo pipefail

NGC_VERSION="4.8.2"
NGC_ZIP="ngccli_arm64.zip"
NGC_URL="https://api.ngc.nvidia.com/v2/resources/nvidia/ngc-apps/ngc_cli/versions/${NGC_VERSION}/files/${NGC_ZIP}"
NGC_SHA256_EXPECTED="0243568105b0472dc2dd96fb985c59eb5f0a49913025988b7c4eec68a5c0b5dc"

INSTALL_ROOT="$HOME/.local/ngc-cli"         # staging area for ZIP
EXTRACT_DIR="${INSTALL_ROOT}/ngc-cli"       # unzip target (contains 'ngc')
TARGET_BIN="${EXTRACT_DIR}/ngc"             # actual CLI binary
USER_BIN="$HOME/.local/bin"                 # per-user bin
SYSTEM_BIN="/usr/local/bin"                 # system-wide bin (usually on PATH)
LINK_USER="${USER_BIN}/ngc"
LINK_SYSTEM="${SYSTEM_BIN}/ngc"

say() { printf "%s\n" "$*"; }
need() { command -v "$1" >/dev/null 2>&1 || { say "Missing dependency: $1"; exit 1; }; }

# 0) Idempotent precheck: if ngc works now, exit
if command -v ngc >/dev/null 2>&1 && ngc --version >/dev/null 2>&1; then
  say "[✓] NGC already installed: $(ngc --version)"
  exit 0
fi

# 1) Arch + prerequisites
if [[ "$(uname -m)" != "aarch64" ]]; then
  say "[!] Warning: expected ARM64 (aarch64), got $(uname -m). Continuing…"
fi
need wget; need unzip; need sha256sum; need md5sum

# 2) Download ZIP
mkdir -p "$INSTALL_ROOT"
cd "$INSTALL_ROOT"
say "[*] Downloading NGC CLI ${NGC_VERSION} (ARM64)…"
wget --content-disposition "$NGC_URL" -O "$NGC_ZIP"

# 3) Verify SHA256 of the ZIP
say "[*] Verifying SHA256 checksum…"
sha256_actual="$(sha256sum "$NGC_ZIP" | awk '{print $1}')"
if [[ "$sha256_actual" != "$NGC_SHA256_EXPECTED" ]]; then
  say "ERROR: SHA256 mismatch!"
  say "  Expected: $NGC_SHA256_EXPECTED"
  say "  Actual:   $sha256_actual"
  exit 1
fi
say "[✓] SHA256 OK"

# 4) Unzip
say "[*] Unzipping…"
unzip -o "$NGC_ZIP"

# 5) Verify MD5 manifest if present (NVIDIA doc step)
if [[ -f "${INSTALL_ROOT}/ngc-cli.md5" ]]; then
  say "[*] Verifying MD5 manifest…"
  find ngc-cli/ -type f -exec md5sum {} + | LC_ALL=C sort | md5sum -c ngc-cli.md5
  say "[✓] MD5 manifest OK"
else
  say "[i] MD5 manifest not found; skipping MD5 validation."
fi

# 6) Ensure binary exists & is executable
if [[ ! -f "$TARGET_BIN" ]]; then
  say "ERROR: expected binary not found at $TARGET_BIN"
  exit 1
fi
chmod u+x "$TARGET_BIN"
say "[*] Binary: $TARGET_BIN"

# 7) Create user-level symlink
mkdir -p "$USER_BIN"
ln -sf "$TARGET_BIN" "$LINK_USER"
say "[*] User symlink: $LINK_USER -> $TARGET_BIN"

# 8) Make sure ngc is immediately invocable as 'ngc' in THIS shell
# If ~/.local/bin is already in PATH, we’re done; otherwise, install a system symlink via sudo.
if echo ":$PATH:" | grep -q ":$HOME/.local/bin:" ; then
  # ~/.local/bin already on PATH, should work immediately
  :
else
  say "[i] ~/.local/bin is not in your current PATH."
  if echo ":$PATH:" | grep -q ":$SYSTEM_BIN:" ; then
    # Use system-wide bin (on PATH) so 'ngc' works immediately
    if [[ -w "$SYSTEM_BIN" ]]; then
      ln -sf "$TARGET_BIN" "$LINK_SYSTEM"
      say "[*] System symlink: $LINK_SYSTEM -> $TARGET_BIN"
    else
      say "[*] Creating system symlink with sudo at $LINK_SYSTEM …"
      sudo ln -sf "$TARGET_BIN" "$LINK_SYSTEM"
      say "[*] System symlink created."
    fi
  else
    # As a last resort (very rare), prepend ~/.local/bin for the current process and print guidance
    export PATH="$HOME/.local/bin:$PATH"
    say "[i] Temporarily prepended ~/.local/bin to PATH for this shell."
  fi
fi

# Persist user PATH for future shells (doesn't affect current parent shell, but good hygiene)
persist_line='export PATH="$HOME/.local/bin:$PATH"'
for file in "$HOME/.bashrc" "$HOME/.profile"; do
  touch "$file"
  grep -Fqx "$persist_line" "$file" || echo "$persist_line" >> "$file"
done

# 9) Final smoke test: MUST succeed with plain 'ngc'
if ! command -v ngc >/dev/null 2>&1; then
  say "ERROR: 'ngc' is still not on PATH. Current PATH is:"
  echo "$PATH"
  say "Tried user symlink ($LINK_USER) and system symlink ($LINK_SYSTEM)."
  exit 1
fi

say "[✓] ngc is on PATH: $(command -v ngc)"
ngc --version
say "[✓] Install complete (configuration intentionally omitted)."

