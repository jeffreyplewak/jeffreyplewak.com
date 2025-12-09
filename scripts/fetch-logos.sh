#!/usr/bin/env bash
#
# scripts/fetch-logos.sh
#
# Download portfolio logos into assets/logos/ using Wikimedia Commons
# Special:FilePath redirects (all SVG wordmarks).
#
# Logos:
#   - Lockheed Martin
#   - J.P. Morgan Chase
#   - Nintendo
#   - RTX (Raytheon)
#   - Fidelity Investments
#   - AWS (Amazon Web Services)
#   - Expedia
#   - IBM
#
# Usage:
#   ./scripts/fetch-logos.sh                 # normal run
#   ./scripts/fetch-logos.sh --dry-run       # show what it would do
#   ./scripts/fetch-logos.sh --force         # overwrite existing files
#   ./scripts/fetch-logos.sh --max-retries 5
#

set -Eeuo pipefail

# ---------------------------
# Paths
# ---------------------------
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOGO_DIR="$PROJECT_ROOT/assets/logos"

mkdir -p "$LOGO_DIR"

# ---------------------------
# Defaults / flags
# ---------------------------
DRY_RUN=0
FORCE=0
MAX_RETRIES=3

# ---------------------------
# CLI args (bash 3 compatible)
# ---------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --force)
      FORCE=1
      shift
      ;;
    --max-retries)
      if [[ $# -lt 2 ]]; then
        echo "ERROR: --max-retries requires a value" >&2
        exit 1
      fi
      MAX_RETRIES="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: $0 [--dry-run] [--force] [--max-retries N]" >&2
      exit 1
      ;;
  esac
done

# ---------------------------
# Helpers
# ---------------------------
have_cmd() { command -v "$1" >/dev/null 2>&1; }

log()   { printf '==> %s\n' "$*"; }
info()  { printf '  • %s\n' "$*"; }
warn()  { printf '  ! %s\n' "$*"; }
error() { printf 'ERROR: %s\n' "$*"; }

get_host() {
  # Extract host: https://commons.wikimedia.org/... -> commons.wikimedia.org
  printf '%s\n' "$1" | sed -E 's~^[a-zA-Z0-9+.-]+://([^/]+).*~\1~'
}

check_content_type() {
  local url="$1"
  if ! have_cmd curl; then
    return 0
  fi

  local ct
  ct="$(curl -fsSLI "$url" 2>/dev/null \
        | awk 'BEGIN{IGNORECASE=1} /^Content-Type:/ {print tolower($0)}' \
        | head -n1 || true)"

  if [[ -z "$ct" ]]; then
    warn "Could not determine Content-Type for $url (no header)."
    return 0
  fi

  if [[ "$ct" != *"image/"* ]]; then
    warn "Suspicious Content-Type for $url: $ct (expected image/*)."
  fi
}

download_with_retry() {
  local url="$1"
  local dest="$2"

  if (( DRY_RUN )); then
    info "[dry-run] would download:"
    info "         URL : $url"
    info "         Dest: $dest"
    return 0
  fi

  if ! have_cmd curl && ! have_cmd wget; then
    error "Neither curl nor wget is installed. Install one and rerun."
    return 1
  fi

  local attempt=1
  local delay=2

  while (( attempt <= MAX_RETRIES )); do
    info "Download attempt $attempt/$MAX_RETRIES"

    if have_cmd curl; then
      if curl -fL "$url" -o "$dest.tmp"; then
        mv "$dest.tmp" "$dest"
        return 0
      fi
    else
      if wget -O "$dest.tmp" "$url"; then
        mv "$dest.tmp" "$dest"
        return 0
      fi
    fi

    warn "Download failed for $url (attempt $attempt)."
    attempt=$((attempt + 1))
    if (( attempt <= MAX_RETRIES )); then
      warn "Retrying in ${delay}s..."
      sleep "$delay"
      delay=$((delay * 2))
    fi
  done

  error "Giving up on $url after $MAX_RETRIES attempts."
  return 1
}

# ---------------------------
# Logo definitions
# ---------------------------
# Format: "Label|local_filename.svg|Commons_File_Name.svg"
LOGOS=(
  "Lockheed Martin|lockheed-martin.svg|Lockheed_Martin_logo.svg"
  "J.P. Morgan Chase|jp-morgan-chase.svg|Logo_of_JPMorganChase_2024.svg"
  "Nintendo|nintendo.svg|Nintendo.svg"
  "RTX (Raytheon)|rtx-raytheon.svg|Raytheon_(RTX)_logo.svg"
  "Fidelity Investments|fidelity-investments.svg|Logo_Fidelity_2011-09-12.svg"
  "AWS|aws.svg|Amazon_Web_Services_2025.svg"
  "Expedia|expedia.svg|Expedia_Logo_2023.svg"
  "IBM|ibm.svg|IBM_logo.svg"
)

log "Logo directory : $LOGO_DIR"
log "Dry run        : $DRY_RUN"
log "Force overwrite: $FORCE"
log "Max retries    : $MAX_RETRIES"
echo

succeeded=0
failed=0

for entry in "${LOGOS[@]}"; do
  IFS='|' read -r label local_name commons_name <<<"$entry"

  dest="$LOGO_DIR/$local_name"
  url="https://commons.wikimedia.org/wiki/Special:FilePath/${commons_name}?download=1"

  log "$label"
  info "Commons file : $commons_name"
  info "URL          : $url"
  info "Destination  : $dest"

  host="$(get_host "$url")"
  if [[ "$host" != "commons.wikimedia.org" ]]; then
    error "Unexpected host '$host' for $label (expected commons.wikimedia.org). Skipping."
    failed=$((failed + 1))
    echo
    continue
  fi

  check_content_type "$url"

  if [[ -f "$dest" && $FORCE -eq 0 ]]; then
    info "File already exists at $dest (use --force to overwrite)."
    succeeded=$((succeeded + 1))
    echo
    continue
  fi

  if download_with_retry "$url" "$dest"; then
    info "Saved → $dest"
    succeeded=$((succeeded + 1))
  else
    failed=$((failed + 1))
  fi

  echo
done

log "Summary:"
info "  OK files      : $succeeded"
info "  Failed fetches: $failed"
echo

log "Done. Inspect assets/logos/ before committing."
echo "NOTE: These are trademarks; ensure your portfolio usage is legally compliant."