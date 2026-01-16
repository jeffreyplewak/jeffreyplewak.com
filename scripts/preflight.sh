#!/usr/bin/env bash
# preflight.sh — reusable static site preflight for audit + local server + smoke tests
# Designed for Vercel static hosting + performance/SEO/A11y/structural checks.
# Run:
#   bash preflight.sh        # audit only
#   bash preflight.sh --dev   # audit + start server + smoke test
#   bash preflight.sh --help

set -euo pipefail

# -----------------------------
# Defaults
# -----------------------------
MODE="audit"
PORT="3000"
SHOW_LOGS=0
TIMEOUT=12

# colors
RED=$(printf "\033[31m")
GRN=$(printf "\033[32m")
YLW=$(printf "\033[33m")
BLU=$(printf "\033[34m")
RST=$(printf "\033[0m")

banner(){ printf "\n%s%s%s\n" "$BLU" "$*" "$RST"; }

usage(){
  cat <<EOF
Static Site Preflight (2026-ready)

Usage:
  bash preflight.sh [options]

Options:
  --audit           Run only audits (default)
  --dev             After audit start local server & smoke tests
  --port <n>        Local server port (default 3000)
  --logs            Print server logs even on successful smoke tests
  --timeout <secs>  Local server readiness timeout (default 12s)
  --help            Show this help
EOF
}

# -----------------------------
# Parse args
# -----------------------------
while [ $# -gt 0 ]; do
  case "$1" in
    --audit) MODE="audit" ;;
    --dev) MODE="dev" ;;
    --port) PORT="$2"; shift ;;
    --logs) SHOW_LOGS=1 ;;
    --timeout) TIMEOUT="$2"; shift ;;
    --help) usage; exit 0 ;;
    *) echo "Unknown arg: $1"; usage; exit 1 ;;
  esac
  shift
done

ROOT="$(pwd)"
INDEX="$ROOT/index.html"

# -----------------------------
# Helpers
# -----------------------------
log_ok(){ printf "%s[OK]%s %s\n" "$GRN" "$RST" "$*"; }
log_warn(){ printf "%s[WARN]%s %s\n" "$YLW" "$RST" "$*"; }
log_fail(){ printf "%s[FAIL]%s %s\n" "$RED" "$RST" "$*"; exit 1; }
log_info(){ printf "%s[INFO]%s %s\n" "$BLU" "$RST" "$*"; }

need_cmd(){ command -v "$1" >/dev/null 2>&1 || log_fail "Required command missing: $1"; }
have_cmd(){ command -v "$1" >/dev/null 2>&1; }

start_server(){
  log_info "Starting dev server on port $PORT"
  if have_cmd vercel; then
    log_info "Using Vercel CLI"
    (vercel dev --listen "$PORT" >"/tmp/vercel.log" 2>&1 &) || true
    DEV_PID=$!
  elif have_cmd python3; then
    log_info "Falling back to python3 http.server"
    (python3 -m http.server "$PORT" >"/tmp/py.log" 2>&1 &) || true
    DEV_PID=$!
  else
    log_fail "No server tool (vercel or python3) found"
  fi

  # wait for readiness
  local t=0
  while ! curl -s "http://localhost:$PORT" >/dev/null 2>&1; do
    sleep 0.5
    t=$((t+1))
    [ $t -lt $TIMEOUT ] || log_fail "Server not ready after $TIMEOUT sec"
  done
  log_ok "Server responsive at http://localhost:$PORT"
}

smoke_tests(){
  banner "SMOKE TESTS"
  for p in "/" "/css/base.css" "/js/main.js" "/assets/favicon.png"; do
    code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$PORT$p" || true)
    printf "%s %s\n" "$code" "$p"
    [ "$code" = "200" ] || log_fail "Smoke failed: $p -> $code"
  done
  log_ok "Smoke tests passed"
  [ $SHOW_LOGS -eq 1 ] && (echo "--- server log ---"; tail -n 50 /tmp/vercel.log /tmp/py.log || true)
}

# -----------------------------
# Checks (audits)
# -----------------------------
banner "BEGIN AUDIT"

# structural
log_info "Checking index.html structural integrity"
doc_count=$(grep -ci '<!doctype html' "$INDEX" || true)
end_count=$(grep -ci '</html>' "$INDEX" || true)
[ "$doc_count" = "1" ] || log_fail "Expected single doctype, got $doc_count"
[ "$end_count" = "1" ] || log_fail "Expected one '</html>', got $end_count"
log_ok "HTML structure valid"

# required assets
log_info "Checking required files"
REQUIRED="robots.txt sitemap.xml css/base.css js/main.js assets/favicon.png"
for f in $REQUIRED; do
  [ -f "$ROOT/$f" ] || log_fail "Missing required: $f"
done
log_ok "Required files present"

# internal refs
log_info "Checking internal href/src refs"
refs=$(grep -oE '(href|src)=\"/[^\"]+\"' "$INDEX" | sed -E 's/^(href|src)=\"(\/[^\"]+)\"$/\2/' | sort -u)
for r in $refs; do
  [ -f ".$r" ] || log_fail "Broken ref: $r"
done
log_ok "Internal refs resolve"

# SEO basics
log_info "Checking SEO meta"
grep -qi '<title>' "$INDEX" || log_fail "Missing <title>"
grep -qi 'meta name="description"' "$INDEX" || log_fail "Missing meta description"
log_ok "Title + description present"

# accessibility baseline
log_info "Checking a11y basics"
grep -qi '<html[^>]*lang=' "$INDEX" || log_warn "Missing lang attribute"
h1count=$(grep -io '<h1' "$INDEX" | wc -l | tr -d ' ')
[ "$h1count" = "1" ] || log_warn "Expected 1 H1, found $h1count"
grep -q 'alt=' "$INDEX" || log_warn "Missing alt on images"
log_ok "A11y basics checked"

# Calendly placeholder
grep -q 'calendly.com/YOUR_HANDLE' "$INDEX" && log_warn "Replace Calendly placeholder" || log_ok "Calendly link non-placeholder"

banner "AUDIT COMPLETE"

# -----------------------------
# Dev mode
# -----------------------------
if [ "$MODE" = "dev" ]; then
  start_server
  smoke_tests
  log_info "Dev mode complete (pid=$DEV_PID). Ctrl+C to stop."
  while true; do sleep 1; done
fi