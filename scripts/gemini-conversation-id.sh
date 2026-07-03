#!/usr/bin/env bash
# ponytail: agy doesn't print the ID of the conversation it just created, but
# it does record "last conversation per directory" in its own cache file —
# the same file it consults for `agy -c`/`--continue` — so we just read that.
set -uo pipefail

cwd="${1:-$PWD}"
canonical="$(cd "$cwd" 2>/dev/null && pwd -P || printf '%s' "$cwd")"
cache_file="$HOME/.gemini/antigravity-cli/cache/last_conversations.json"

[ -f "$cache_file" ] || exit 1

python3 -c '
import json, sys
path, cache_file = sys.argv[1], sys.argv[2]
try:
    with open(cache_file) as f:
        data = json.load(f)
except (OSError, ValueError):
    sys.exit(1)
conv_id = data.get(path)
if not conv_id:
    sys.exit(1)
print(conv_id)
' "$canonical" "$cache_file"
