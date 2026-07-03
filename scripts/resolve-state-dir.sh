#!/usr/bin/env bash
# ponytail: one shared place to compute the per-workspace state dir, used by
# gemini-jobs.sh, gemini-config.sh, and the Stop hook, so they always agree.
set -uo pipefail

cwd="${1:-$PWD}"
root="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$cwd")"
canonical="$(cd "$root" 2>/dev/null && pwd -P || printf '%s' "$root")"

if command -v shasum >/dev/null 2>&1; then
  hash="$(printf '%s' "$canonical" | shasum -a 256 | cut -c1-16)"
elif command -v sha256sum >/dev/null 2>&1; then
  hash="$(printf '%s' "$canonical" | sha256sum | cut -c1-16)"
else
  hash="$(printf '%s' "$canonical" | cksum | tr -d ' \t' | cut -c1-16)"
fi

slug="$(basename "$canonical" | tr -c 'A-Za-z0-9._-' '-')"
[ -n "$slug" ] || slug="workspace"

# Ensure the directories we own are private even if an earlier version of
# this plugin (or anything else) created them with looser permissions
# before umask-hardening was added — a fresh `mkdir -p` under a strict
# umask only protects newly created directories, not ones left over from
# before that fix. Only chmod what we actually own: never the caller's
# $CLAUDE_PLUGIN_DATA root itself, which the host application manages.
if [ -n "${CLAUDE_PLUGIN_DATA:-}" ]; then
  base="$CLAUDE_PLUGIN_DATA/state"
  mkdir -p "$base" 2>/dev/null
  chmod 700 "$base" 2>/dev/null
else
  owned_root="${TMPDIR:-/tmp}/gemini-bridge"
  base="$owned_root/state"
  mkdir -p "$base" 2>/dev/null
  chmod 700 "$owned_root" "$base" 2>/dev/null
fi

printf '%s/%s-%s\n' "$base" "$slug" "$hash"
