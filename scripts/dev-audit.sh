#!/usr/bin/env bash
# scripts/dev-audit.sh
# Comprehensive audit + local dev runner for a Vercel static site (2026 best practices)
# - macOS Bash 3 compatible
# - fails fast, prints clear diagnostics
# - no external dependencies beyond: bash, grep, sed, awk, find, curl, node(optional), vercel(optional)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# ---------- helpers ----------
RED="$(printf '\033[31m')"; GRN="$(printf '\033[32m')"; YLW="$(printf '\033[33m')"; BLU="$(printf '\033[34m')"; RST="$(printf '\033[0m')"
ok(){ printf "%sOK%s  %s\n" "$GRN" "$RST" "$*"; }
warn(){ printf "%sWARN%s %s\n" "$YLW" "$RST" "$*"; }
fail(){ printf "%sFAIL%s %s\n" "$RED" "$RST" "$*"; exit 1; }
info(){ printf "%sINFO%s %s\n" "$BLU" "$RST" "$*"; }

need_cmd(){
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

have_cmd(){
  command -v "$1" >/dev/null 2>&1
}

# Safe kill (macOS compatible)
kill_pid(){
  local pid="$1"
  if [ -n "${pid:-}" ] && kill -0 "$pid" >/dev/null 2>&1; then
    kill "$pid" >/dev/null 2>&1 || true
    # give it a moment
    sleep 0.3
    kill -9 "$pid" >/dev/null 2>&1 || true
  fi
}

cleanup(){
  if [ -n "${DEV_PID:-}" ]; then
    info "Stopping local dev server (pid=$DEV_PID)"
    kill_pid "$DEV_PID"
  fi
}
trap cleanup EXIT INT TERM

# ---------- args ----------
MODE="audit"
PORT="3000"
YES="0"
NO_DEV="0"

while [ $# -gt 0 ]; do
  case "$1" in
    --audit) MODE="audit" ;;
    --dev) MODE="dev" ;;
    --port) PORT="${2:-}"; shift ;;
    --yes) YES="1" ;;
    --no-dev) NO_DEV="1" ;;
    -h|--help)
      cat <<EOF
Usage: bash scripts/dev-audit.sh [--audit|--dev] [--port 3000] [--yes] [--no-dev]

--audit   Run all checks (default)
--dev     Run checks, then start local dev server and smoke-test endpoints
--port    Port for local server (default 3000)
--yes     Non-interactive where possible
--no-dev  Skip starting dev server (useful if you run it elsewhere)

EOF
      exit 0
      ;;
    *) fail "Unknown arg: $1" ;;
  esac
  shift
done

# ---------- baseline tools ----------
need_cmd bash
need_cmd grep
need_cmd sed
need_cmd awk
need_cmd find
need_cmd curl
need_cmd wc

# ---------- repo shape / files ----------
INDEX="index.html"
[ -f "$INDEX" ] || fail "index.html not found at repo root: $ROOT"

# Required assets for THIS project (adjust if you rename files)
REQ_FILES=(
  "index.html"
  "robots.txt"
  "sitemap.xml"
  "site.webmanifest"
  "css/reset.css"
  "css/tokens.css"
  "css/base.css"
  "css/layout.css"
  "css/components.css"
  "css/effects.css"
  "js/main.js"
  "js/a11y.js"
  "js/parallax.js"
  "downloads/jeffrey-plewak-resume.pdf"
  "downloads/jeffrey-plewak.vcf"
  "assets/favicon.png"
  "assets/icon-192.png"
  "assets/icon-512.png"
  "assets/images/og-image.png"
  "assets/images/jeffrey-plewak-portrait.jpg"
  "assets/images/jeffrey-plewak-portrait.webp"
  "assets/images/jeffrey-plewak-portrait.avif"
)

# ---------- checks ----------
check_single_document(){
  info "HTML structural checks (single document, no junk artifacts)"
  local doctype htmlend
  doctype="$(grep -ci '<!doctype html' "$INDEX" || true)"
  htmlend="$(grep -ci '</html>' "$INDEX" || true)"
  [ "$doctype" = "1" ] || fail "Expected exactly 1 <!doctype html>, found $doctype"
  [ "$htmlend" = "1" ] || fail "Expected exactly 1 </html>, found $htmlend"

  if grep -nE 'oai_citation:|sediment://|file_0000' "$INDEX" >/dev/null 2>&1; then
    fail "Found citation artifacts (oai_citation/sediment/file_0000). Remove them from index.html."
  fi

  # Ensure END guardrail exists (optional but recommended)
  if ! grep -n 'END OF DOCUMENT' "$INDEX" >/dev/null 2>&1; then
    warn "Missing END-OF-DOCUMENT guard comment. Add: <!-- END OF DOCUMENT: do not paste below this line -->"
  fi

  ok "HTML structure clean"
}

check_required_files(){
  info "Required file presence checks"
  local missing=0
  for f in "${REQ_FILES[@]}"; do
    if [ ! -f "$f" ]; then
      printf "%s\n" "MISSING: $f"
      missing=1
    fi
  done
  [ "$missing" = "0" ] || fail "Missing required files (see list above)"
  ok "All required files present"
}

check_internal_refs(){
  info "Internal href/src references resolve to real files"
  # extract absolute refs like href="/css/base.css" or src="/js/main.js"
  local refs bad
  refs="$(
    grep -oE '(href|src)=\"/[^\"]+\"' "$INDEX" \
      | sed -E 's/^(href|src)=\"(\/[^\"]+)\"$/\2/' \
      | sort -u
  )"
  bad=0
  # shellcheck disable=SC2086
  for r in $refs; do
    if [ ! -f ".${r}" ]; then
      printf "%s\n" "BROKEN: $r (missing .${r})"
      bad=1
    fi
  done
  [ "$bad" = "0" ] || fail "Broken internal asset references (see above)"
  ok "All internal href/src references resolve"
}

check_seo_basics(){
  info "SEO checks (static, high-signal)"
  # title
  grep -qi '<title>.*</title>' "$INDEX" || fail "Missing <title>"
  # description
  grep -qi 'meta name="description"' "$INDEX" || fail "Missing meta description"
  # canonical
  grep -qi 'rel="canonical"' "$INDEX" || warn "Missing canonical link"
  # robots
  grep -qi 'meta name="robots"' "$INDEX" || warn "Missing robots meta"
  # OG
  grep -qi 'property="og:title"' "$INDEX" || warn "Missing og:title"
  grep -qi 'property="og:description"' "$INDEX" || warn "Missing og:description"
  grep -qi 'property="og:image"' "$INDEX" || warn "Missing og:image"
  # Twitter card
  grep -qi 'name="twitter:card"' "$INDEX" || warn "Missing twitter:card"
  # Schema JSON-LD
  grep -qi 'application/ld\+json' "$INDEX" || warn "Missing JSON-LD schema script"
  ok "SEO baseline present"
}

check_accessibility_basics(){
  info "A11y checks (static)"
  # language
  grep -qi '<html[^>]*lang="en"' "$INDEX" || warn "Missing lang=\"en\" on <html>"
  # single H1
  local h1count
  h1count="$(grep -io '<h1' "$INDEX" | wc -l | tr -d ' ')"
  [ "$h1count" = "1" ] || warn "Expected 1 <h1>, found $h1count"
  # image alt
  if grep -n '<img' "$INDEX" | grep -v 'alt=' >/dev/null 2>&1; then
    warn "Found <img> without alt attribute"
  fi
  ok "A11y baseline ok"
}

check_perf_risks(){
  info "Performance risk checks (file sizes, LCP candidates)"
  # show large assets > 300KB
  local large
  large="$(find assets downloads -type f -maxdepth 5 -size +300k 2>/dev/null | wc -l | tr -d ' ')"
  if [ "$large" != "0" ]; then
    warn "Found $large asset(s) >300KB. Consider compressing to reduce LCP."
    find assets downloads -type f -maxdepth 5 -size +300k -print0 2>/dev/null | xargs -0 ls -lh | awk '{print $5, $9}' || true
  else
    ok "No assets over 300KB (good for LCP)"
  fi

  # Ensure hero image includes width/height to avoid CLS
  if ! grep -n 'class="hero-avatar"' "$INDEX" | grep -q 'width='; then
    warn "Hero avatar missing explicit width/height (CLS risk)."
  else
    ok "Hero avatar has explicit dimensions"
  fi
}

check_calendly_placeholder(){
  info "Calendly placeholder check"
  if grep -n 'calendly.com/YOUR_HANDLE' "$INDEX" >/dev/null 2>&1; then
    warn "Calendly URL is still placeholder. Replace with your real link."
  else
    ok "Calendly URL looks non-placeholder"
  fi
}

check_vercel_config(){
  info "Vercel config checks"
  if [ -f "vercel.json" ]; then
    ok "vercel.json present"
  else
    warn "vercel.json missing (optional for pure static; recommended if you need headers/redirects)."
  fi

  if [ -f "build.sh" ]; then
    ok "build.sh present"
  else
    warn "build.sh missing. If Vercel tries to run @vercel/static-build:build.sh, it may fail."
  fi

  # If package.json exists in root, verify it doesn't accidentally override build
  if [ -f "package.json" ]; then
    warn "package.json present. Ensure it doesn't set a build command that conflicts with static hosting."
  fi
}

# ---------- dev server + smoke tests ----------
start_dev_server(){
  if [ "$NO_DEV" = "1" ]; then
    warn "--no-dev set; skipping server start"
    return 0
  fi

  if have_cmd vercel; then
    info "Starting Vercel dev on port $PORT"
    # Vercel CLI flags change over time; keep conservative:
    # --listen is stable, --yes reduces prompts (if supported)
    if [ "$YES" = "1" ]; then
      (vercel dev --yes --listen "$PORT" >"/tmp/jp-vercel-dev.log" 2>&1 &) || true
    else
      (vercel dev --listen "$PORT" >"/tmp/jp-vercel-dev.log" 2>&1 &) || true
    fi
    DEV_PID=$!
  else
    warn "Vercel CLI not found. Fallback to python http.server on port $PORT"
    if have_cmd python3; then
      (python3 -m http.server "$PORT" >"/tmp/jp-httpserver.log" 2>&1 &) || true
      DEV_PID=$!
    else
      fail "Neither vercel nor python3 available to run a local server."
    fi
  fi

  # Wait for server to accept connections
  info "Waiting for http://localhost:$PORT to respond"
  local i
  for i in $(seq 1 30); do
    if curl -s -o /dev/null "http://localhost:$PORT/" >/dev/null 2>&1; then
      ok "Server responsive"
      return 0
    fi
    sleep 0.2
  done

  echo "---- server log ----"
  if [ -f /tmp/jp-vercel-dev.log ]; then tail -n 40 /tmp/jp-vercel-dev.log || true; fi
  if [ -f /tmp/jp-httpserver.log ]; then tail -n 40 /tmp/jp-httpserver.log || true; fi
  fail "Server did not become ready on port $PORT"
}

smoke_test_endpoints(){
  [ "$NO_DEV" = "1" ] && return 0

  info "Smoke testing key endpoints (HTTP 200 expected)"
  local paths=(
    "/"
    "/css/base.css"
    "/css/layout.css"
    "/css/components.css"
    "/css/effects.css"
    "/js/main.js"
    "/js/a11y.js"
    "/js/parallax.js"
    "/downloads/jeffrey-plewak-resume.pdf"
    "/downloads/jeffrey-plewak.vcf"
    "/assets/favicon.png"
    "/assets/images/og-image.png"
  )

  local p code
  for p in "${paths[@]}"; do
    code="$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$PORT$p" || true)"
    printf "%s %s\n" "$code" "$p"
    [ "$code" = "200" ] || fail "Smoke test failed for $p (HTTP $code)"
  done

  ok "All smoke tests passed"
}

# ---------- run ----------
info "Repo: $ROOT"
info "Mode: $MODE"

check_single_document
check_required_files
check_internal_refs
check_seo_basics
check_accessibility_basics
check_perf_risks
check_calendly_placeholder
check_vercel_config

if [ "$MODE" = "dev" ]; then
  start_dev_server
  smoke_test_endpoints
  ok "Dev mode complete. Server is still running (pid=$DEV_PID). Ctrl+C to stop."
  # Keep running until user stops
  while true; do sleep 1; done
fi

ok "Audit complete"