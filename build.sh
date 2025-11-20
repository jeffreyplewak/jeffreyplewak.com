#!/usr/bin/env bash
#
# build.sh – token replacement for jeffreyplewak.com
# Replaces %%VAR%% placeholders in static HTML with environment values.
# Run via: npm run build

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

HTML_FILES=(
  "index.html"
  "pay.html"
  "premium.html"
  "book.html"
  "contact.html"
)

echo "build.sh: Using values (from environment)"
echo "  SITE_NAME=${SITE_NAME:-Jeffrey Plewak}"
echo "  SITE_URL=${SITE_URL:-https://jeffreyplewak.com}"
echo "  CONTACT_EMAIL=${CONTACT_EMAIL:-${CONTACT_FORM_EMAIL:-plewak.jeff@gmail.com}}"
echo "  CONTACT_ENDPOINT=${CONTACT_ENDPOINT:-https://jeffreyplewak.com/api/contact}"
echo "  CALENDLY_URL=${CALENDLY_URL:-https://calendly.com/plewak-jeff/intro}"
echo

# Python reads env directly; shell does not touch placeholders.
python3 - "${HTML_FILES[@]}" << 'PY'
import os
import sys
from pathlib import Path

html_files = [Path(p) for p in sys.argv[1:]]

site_name = os.getenv("SITE_NAME", "Jeffrey Plewak")
site_url = os.getenv("SITE_URL", "https://jeffreyplewak.com")

tokens = {
    "SITE_NAME": site_name,
    "SITE_URL": site_url,
    "OG_IMAGE_URL": os.getenv("OG_IMAGE_URL", f"{site_url}/og-image.png"),
    "FAVICON_URL": os.getenv("FAVICON_URL", "/favicon.svg"),
    "CONTACT_EMAIL": os.getenv("CONTACT_EMAIL") or os.getenv("CONTACT_FORM_EMAIL", "plewak.jeff@gmail.com"),
    "CONTACT_ENDPOINT": os.getenv("CONTACT_ENDPOINT", "https://jeffreyplewak.com/api/contact"),
    "CALENDLY_URL": os.getenv("CALENDLY_URL", "https://calendly.com/plewak-jeff/intro"),
    # Stripe placeholders kept for compatibility; they can be empty.
    "STRIPE_PUBLISHABLE_KEY": os.getenv("STRIPE_PUBLISHABLE_KEY", ""),
    "STRIPE_STARTER_BUTTON_ID": os.getenv("STRIPE_STARTER_BUTTON_ID", ""),
    "STRIPE_BUILDER_BUTTON_ID": os.getenv("STRIPE_BUILDER_BUTTON_ID", ""),
}

def apply_tokens(path: Path) -> None:
    if not path.exists():
        print(f"[build.sh] WARNING: {path} not found, skipping", file=sys.stderr)
        return
    text = path.read_text(encoding="utf-8")
    original = text
    for key, value in tokens.items():
        placeholder = f"%%{key}%%"
        if placeholder in text:
            text = text.replace(placeholder, value or "")
    if text != original:
        path.write_text(text, encoding="utf-8")
        print(f"[build.sh] Updated {path}")
    else:
        print(f"[build.sh] No tokens found in {path}, unchanged")

for p in html_files:
    apply_tokens(p)
PY

echo
echo "build.sh: Token replacement complete."