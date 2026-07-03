#!/usr/bin/env bash
# ponytail: shells out to the real check, no bespoke installer/updater logic here
set -uo pipefail

if ! command -v agy >/dev/null 2>&1; then
  cat <<'EOF'
NOT_INSTALLED
Antigravity CLI is not installed. Install it with:
  curl -fsSL https://antigravity.google/cli/install.sh | bash
Then run:
  agy
and sign in with Google Sign-In when prompted. That ties the CLI to your
Gemini subscription (Code Assist / AI Pro / AI Ultra) instead of an API key.
EOF
  exit 1
fi

if [ -n "${GEMINI_API_KEY:-}" ] || [ -n "${GOOGLE_API_KEY:-}" ]; then
  cat <<'EOF'
API_KEY_MODE
Antigravity CLI is installed, but GEMINI_API_KEY / GOOGLE_API_KEY is set in
this shell, which forces API-key billing instead of your Google-account
subscription. Unset it (unset GEMINI_API_KEY GOOGLE_API_KEY) if you want
usage to come out of your subscription instead of pay-per-token API billing.
EOF
  exit 1
fi

# `agy models` needs a live authenticated session to list what's available,
# so it doubles as an auth check. Bound it with perl's alarm() since macOS
# ships no `timeout`/`gtimeout` by default.
models_output="$(perl -e 'alarm 15; exec @ARGV' agy models 2>/dev/null)"
models_rc=$?

if [ "$models_rc" -ne 0 ] || [ -z "$models_output" ]; then
  cat <<EOF
NOT_LOGGED_IN
Antigravity CLI is installed but 'agy models' failed or timed out
(not signed in, or a sign-in prompt has nowhere to render here). Run:
  agy
and complete Google Sign-In to authenticate with your Gemini subscription.
EOF
  exit 1
fi

echo "OK"
echo "$models_output"
