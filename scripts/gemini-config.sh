#!/usr/bin/env bash
# ponytail: one flag file, one flag. No general config system until there's
# a second setting that needs one.
set -uo pipefail

# State may land in a shared temp dir if CLAUDE_PLUGIN_DATA isn't set, so
# keep it from being world-readable regardless of the caller's umask.
umask 077

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
state_dir="$("$SCRIPT_DIR/resolve-state-dir.sh")"
mkdir -p "$state_dir"
config_file="$state_dir/config"

cmd="${1:-show}"
case "$cmd" in
  enable-review-gate)
    printf 'review_gate=1\n' > "$config_file"
    echo "Gemini review gate enabled. Every Claude Code Stop will now trigger a quick Gemini review of that turn's changes; a BLOCK verdict forces another pass before Claude can finish."
    ;;
  disable-review-gate)
    printf 'review_gate=0\n' > "$config_file"
    echo "Gemini review gate disabled."
    ;;
  show)
    if [ -f "$config_file" ] && grep -q '^review_gate=1' "$config_file"; then
      echo "review gate: enabled"
    else
      echo "review gate: disabled"
    fi
    ;;
  *)
    echo "usage: gemini-config.sh enable-review-gate|disable-review-gate|show" >&2
    exit 2
    ;;
esac
