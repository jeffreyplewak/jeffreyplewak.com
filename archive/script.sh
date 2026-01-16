#!/usr/bin/env bash
# scripts/move-consulting.sh
#
# Purpose (final, guardrailed):
#   Quarantine consulting/pricing/commerce pages into /consulting/ on a static Vercel site,
#   apply SEO guardrails (noindex), and (by default) REMOVE homepage links to those pages.
#
# Compatibility:
#   - macOS bash 3.2+ (MacBook Pro M4 Terminal)
#   - BSD sed/awk
#
# Usage:
#   bash scripts/move-consulting.sh --check
#   bash scripts/move-consulting.sh --apply
#   bash scripts/move-consulting.sh --apply --keep-homepage-links   # rewrite homepage links to /consulting + nofollow
#
# Modes:
#   Default behavior is "Mode B" (recommended):
#     - Move pages under /consulting/
#     - Add <meta name="robots" content="noindex,follow">
#     - Remove direct links from index.html to those pages (comment them out)
#
#   Optional "Mode A":
#     --keep-homepage-links
#     - Rewrite links in index.html to /consulting/<page> and add rel="nofollow"
#
# Safety:
#   - Creates timestamped backups in ./.backup-move-consulting/
#   - Does not require GNU tools
#   - Works even if files are missing (no failures on unmatched globs)

set -euo pipefail
IFS=$'\n\t'
shopt -s nullglob

MODE="check"
HOMEPAGE_MODE="strip"  # "strip" (default) or "keep"
ROOT_DIR="."
CONSULTING_DIR="${ROOT_DIR}/consulting"
BACKUP_DIR="${ROOT_DIR}/.backup-move-consulting"

# Candidate consulting pages. Adjust as needed.
CONSULTING_GLOBS=(
  "pay.html"
  "pricing.html"
  "prices.html"
  "services.html"
  "service.html"
  "store.html"
  "checkout.html"
  "stripe*.html"
  "offer*.html"
  "consulting.html"
)

# Also move any consulting-* prefixed pages
CONSULTING_PREFIX_GLOB="consulting-*.html"

usage() {
  cat <<EOF
Usage:
  bash scripts/move-consulting.sh --check
  bash scripts/move-consulting.sh --apply [--keep-homepage-links]

Options:
  --check                 Dry run (no changes)
  --apply                 Apply changes
  --keep-homepage-links   Keep homepage access by rewriting links to /consulting/<page> and adding rel="nofollow"
                          Default is to strip (comment out) homepage links to quarantined pages.
EOF
}

log() { printf "%s\n" "$*"; }

ensure_dir() {
  local d="$1"
  if [ "$MODE" = "apply" ]; then
    mkdir -p "$d"
  fi
}

file_exists() { [ -f "$1" ]; }

# Portable in-place sed for macOS + Linux
sedi() {
  local expr="$1"
  local file="$2"
  # GNU sed supports --version; BSD sed doesn't.
  if sed --version >/dev/null 2>&1; then
    sed -i "$expr" "$file"
  else
    sed -i '' "$expr" "$file"
  fi
}

backup_file() {
  local f="$1"
  ensure_dir "$BACKUP_DIR"
  local ts
  ts="$(date +"%Y%m%d-%H%M%S")"

  # Create a safe filename key that includes relative path (replace / with __)
  local rel="${f#${ROOT_DIR}/}"
  rel="${rel#/}"
  local key
  key="$(printf "%s" "$rel" | tr '/' '_' )"

  cp -p "$f" "${BACKUP_DIR}/${key}.${ts}.bak"
}

collect_targets() {
  local found=()

  # Exact glob matches
  local g f
  for g in "${CONSULTING_GLOBS[@]}"; do
    for f in "${ROOT_DIR}/${g}"; do
      [ -f "$f" ] && found+=("$f")
    done
  done

  # Prefix glob matches
  for f in "${ROOT_DIR}/${CONSULTING_PREFIX_GLOB}"; do
    [ -f "$f" ] && found+=("$f")
  done

  # De-dup (bash 3.2 safe)
  local uniq=()
  local seen="|"
  for f in "${found[@]}"; do
    case "$seen" in
      *"|$f|"*) ;;
      *) seen="${seen}${f}|"; uniq+=("$f") ;;
    esac
  done

  # Print newline-separated
  for f in "${uniq[@]}"; do
    printf "%s\n" "$f"
  done
}

add_noindex_meta_if_missing() {
  local html="$1"

  # If already has robots meta, do nothing.
  if grep -qi '<meta[^>]*name=["'"'"']robots["'"'"']' "$html"; then
    return 0
  fi

  if [ "$MODE" = "apply" ]; then
    backup_file "$html"

    if grep -qi '<head[^>]*>' "$html"; then
      # Insert immediately after first <head...>
      awk '
        BEGIN{inserted=0}
        {
          print $0
          if (!inserted && tolower($0) ~ /<head[^>]*>/) {
            print "  <meta name=\"robots\" content=\"noindex,follow\">"
            inserted=1
          }
        }
      ' "$html" > "${html}.tmp" && mv "${html}.tmp" "$html"
    else
      {
        echo "<head>"
        echo "  <meta name=\"robots\" content=\"noindex,follow\">"
        echo "</head>"
        cat "$html"
      } > "${html}.tmp" && mv "${html}.tmp" "$html"
    fi
  else
    log "  [check] would insert noindex robots meta into: $html"
  fi
}

rewrite_relative_asset_paths_for_subdir() {
  local html="$1"
  # Absolute /assets/... is fine anywhere.
  # But relative assets/... breaks when moving into /consulting.
  # Fix only relative 'assets/...'
  if grep -qE '(["'"'"'])assets/' "$html"; then
    if [ "$MODE" = "apply" ]; then
      backup_file "$html"
      sedi 's/\(href=["'"'"']\)assets\//\1..\/assets\//g' "$html"
      sedi 's/\(src=["'"'"']\)assets\//\1..\/assets\//g' "$html"
    else
      log "  [check] would rewrite relative asset paths in: $html"
    fi
  fi
}

record_moved_page() {
  local dst="$1"
  if [ "$MODE" = "apply" ]; then
    ensure_dir "$BACKUP_DIR"
    echo "$dst" >> "${BACKUP_DIR}/moved-pages.txt"
  fi
}

init_moved_pages_list() {
  if [ "$MODE" = "apply" ]; then
    ensure_dir "$BACKUP_DIR"
    : > "${BACKUP_DIR}/moved-pages.txt"
  fi
}

create_consulting_landing_if_missing() {
  local landing="${CONSULTING_DIR}/index.html"
  if file_exists "$landing"; then
    return 0
  fi

  if [ "$MODE" = "apply" ]; then
    cat > "$landing" <<'EOF'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <meta name="robots" content="noindex,follow" />
  <title>Consulting — Jeffrey Plewak</title>
</head>
<body>
  <main style="max-width: 760px; margin: 64px auto; padding: 0 20px; font-family: system-ui, -apple-system, Segoe UI, Roboto, Arial, sans-serif; line-height: 1.55;">
    <h1 style="margin: 0 0 10px 0;">Consulting</h1>
    <p style="margin: 0 0 14px 0;">
      This section contains consulting-related pages and materials. It is intentionally not indexed by search engines.
    </p>
    <p style="margin: 0;">
      <a href="/" style="text-decoration: none;">Return to homepage</a>
    </p>
  </main>
</body>
</html>
EOF
  else
    log "  [check] would create: ${landing}"
  fi
}

update_homepage_links() {
  local index="${ROOT_DIR}/index.html"
  if ! file_exists "$index"; then
    log "WARN: index.html not found at repo root; skipping homepage updates."
    return 0
  fi

  local moved_list="${BACKUP_DIR}/moved-pages.txt"
  if [ ! -f "$moved_list" ]; then
    log "WARN: moved-pages.txt not found (did you run --apply?). Skipping homepage updates."
    return 0
  fi

  if [ "$MODE" = "apply" ]; then
    backup_file "$index"
  fi

  local moved dst base

  while IFS= read -r dst; do
    [ -n "$dst" ] || continue
    base="$(basename "$dst")"

    if [ "$HOMEPAGE_MODE" = "keep" ]; then
      # Rewrite href="base" or href='base' to href="/consulting/base" and add rel="nofollow" if missing on same tag.
      if [ "$MODE" = "apply" ]; then
        # Rewrite href targets
        sedi "s/href=[\"']${base}[\"']/href=\"\\/consulting\\/${base}\"/g" "$index"
        # Add rel="nofollow" to anchors that point to /consulting/base and do not already have rel=
        # Conservative: only if the same line contains href="/consulting/base"
        awk -v base="$base" '
          {
            line=$0
            if (tolower(line) ~ /<a[[:space:]][^>]*href="\/consulting\// && line ~ ("/consulting/" base) ) {
              if (tolower(line) !~ /rel="/) {
                sub(/<a[[:space:]]/, "<a rel=\"nofollow\" ", line)
              }
            }
            print line
          }
        ' "$index" > "${index}.tmp" && mv "${index}.tmp" "$index"
      else
        log "  [check] would rewrite homepage href to /consulting/${base} and add rel=nofollow"
      fi
    else
      # Strip: comment out any line containing href="base" OR href="/consulting/base"
      if [ "$MODE" = "apply" ]; then
        awk -v base="$base" '
          {
            l=$0
            if (l ~ "href=\"" base "\"" || l ~ "href=\x27" base "\x27" || l ~ "href=\"/consulting/" base "\"") {
              print "<!-- quarantined consulting link: " l " -->"
            } else {
              print l
            }
          }
        ' "$index" > "${index}.tmp" && mv "${index}.tmp" "$index"
      else
        log "  [check] would comment out homepage lines containing links to: ${base}"
      fi
    fi

  done < "$moved_list"
}

main() {
  if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    usage
    exit 0
  fi

  if [ "${1:-}" = "--check" ]; then
    MODE="check"
  elif [ "${1:-}" = "--apply" ]; then
    MODE="apply"
  else
    usage
    exit 1
  fi

  if [ "${2:-}" = "--keep-homepage-links" ]; then
    HOMEPAGE_MODE="keep"
  fi

  log "Mode: $MODE"
  log "Homepage mode: $HOMEPAGE_MODE"
  log "Consulting dir: $CONSULTING_DIR"
  log "Backup dir: $BACKUP_DIR"
  log ""

  ensure_dir "$CONSULTING_DIR"
  init_moved_pages_list

  local targets
  targets="$(collect_targets || true)"

  if [ -z "$targets" ]; then
    log "No consulting-like pages found with current patterns."
    log "Edit CONSULTING_GLOBS in this script if your filenames differ."
    create_consulting_landing_if_missing
    exit 0
  fi

  log "Targets to move:"
  printf "%s\n" "$targets" | sed 's/^/  - /'
  log ""

  while IFS= read -r src; do
    [ -n "$src" ] || continue
    local base dst
    base="$(basename "$src")"
    dst="${CONSULTING_DIR}/${base}"

    if [ "$MODE" = "apply" ]; then
      log "Moving: $src -> $dst"
      mv "$src" "$dst"
      record_moved_page "$dst"
      add_noindex_meta_if_missing "$dst"
      rewrite_relative_asset_paths_for_subdir "$dst"
    else
      log "[check] would move: $src -> $dst"
      log "  [check] would add noindex + rewrite relative asset paths in: $dst"
    fi
  done <<< "$targets"

  create_consulting_landing_if_missing

  # Homepage update only meaningful after apply (needs moved-pages list),
  # but we'll still describe intended changes in check mode.
  log ""
  log "Homepage updates:"
  if [ "$MODE" = "apply" ]; then
    update_homepage_links
  else
    log "  [check] would update ./index.html according to homepage mode: $HOMEPAGE_MODE"
    log "  [check] (apply mode will either comment out consulting links, or rewrite to /consulting + rel=nofollow)"
  fi

  log ""
  log "Done."
  log "Summary:"
  log "  - Consulting pages moved to: /consulting/"
  log "  - Added robots noindex,follow to quarantined pages (if missing)"
  log "  - Homepage mode: $HOMEPAGE_MODE"
  log "Backups:"
  log "  - Modified originals backed up under: $BACKUP_DIR"
}

main "$@"
