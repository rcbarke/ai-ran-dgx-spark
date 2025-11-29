#!/usr/bin/env bash
# configure_ngc_cli.sh — NGC setup with default org + API key prompt (robust)
set -euo pipefail

say() { printf '%s\n' "$*"; }

ORG_NAME="aerial-ov-digital-twin"
ORG_SLUG="esee5uzbruax"          # <-- use the slug, not the display name
TEAM_DEFAULT="${NGC_CLI_TEAM:-no-team}"
FMT_DEFAULT="${NGC_CLI_FORMAT_TYPE:-ascii}"

CONFIG_DIR="${HOME}/.ngc"
CONFIG_FILE="${CONFIG_DIR}/config"

if ! command -v ngc >/dev/null 2>&1; then
  say "[!] 'ngc' CLI not found. Install NGC CLI first, then re-run."
  exit 1
fi

say ""
say "==============================================================="
say " Obtain your NGC API key"
say "---------------------------------------------------------------"
say " 1) Visit: https://org.ngc.nvidia.com/setup/api-key"
say " 2) Generate or copy your Personal API key."
say " 3) We will accept the default prompts for format/org/team."
say "==============================================================="
say ""

# Prompt for the API key (masked); allow reusing exported key if present
if [[ -n "${NGC_CLI_API_KEY:-}" ]]; then
  say "[*] An NGC API key is already present in \$NGC_CLI_API_KEY."
  read -r -p "Press Enter to reuse it, or type a new key to replace: " -s _maybe_new || true
  if [[ -n "${_maybe_new:-}" ]]; then
    export NGC_CLI_API_KEY="${_maybe_new}"
  fi
  unset _maybe_new
else
  read -r -p "Enter your NGC API key: " -s NGC_CLI_API_KEY
  say ""
  if [[ -z "${NGC_CLI_API_KEY}" ]]; then
    say "[!] No API key provided. Aborting."
    exit 1
  fi
  export NGC_CLI_API_KEY
fi
say ""

# Ensure clean slate so the env var key is respected
mkdir -p "${CONFIG_DIR}"
say "[*] Resetting NGC config state to avoid stale/empty keys..."
ngc config clear || true
ngc config clear-cache || true
rm -f "${CONFIG_FILE}"

say "[*] NGC configuration will be saved here: ${CONFIG_FILE}"

# Non-interactive write of config using org slug (not name) and team
say "[*] Writing NGC configuration (org='${ORG_NAME}' -> slug='${ORG_SLUG}', team='${TEAM_DEFAULT}', format='${FMT_DEFAULT}')..."
ngc --org "${ORG_SLUG}" --team "${TEAM_DEFAULT}" \
  config set --auth-option api-key --format_type "${FMT_DEFAULT}"

# Verify account and show current config
say ""
say "[*] Verifying account…"
if ! ngc user who --format_type ascii >/dev/null 2>&1; then
  say "[!] Verification failed. Clearing cache so you can retry."
  ngc config clear-cache || true
  exit 1
fi

say ""
say "[*] Current config:"
ngc config current || true

say ""
say "[✓] NGC CLI configured."

# Docker instructions (from NVIDIA docs) — now performed automatically
say ""
say "==============================================================="
say " Docker login for NVIDIA NGC (nvcr.io)"
say "---------------------------------------------------------------"
say "Logging in to nvcr.io using your NGC API key…"
say "    (username: \$oauthtoken, password: <your API key>)"
say "==============================================================="

if echo "${NGC_CLI_API_KEY}" | docker login nvcr.io -u '$oauthtoken' --password-stdin; then
  say "[✓] Docker is authenticated for nvcr.io."
else
  say "[!] Docker login failed."
  say "    You can retry manually with:"
  say "        docker login nvcr.io"
  say "        Username: \$oauthtoken"
  say "        Password: <Your API key>"
  exit 1
fi

# Tip for per-command override (handy if you sometimes switch orgs/teams)
say ""
say "[i] Tip: You can override defaults per-command, e.g.:"
say "    ngc --org ${ORG_SLUG} --team ${TEAM_DEFAULT} catalog list"
