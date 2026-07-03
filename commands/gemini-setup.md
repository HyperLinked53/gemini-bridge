---
description: Check whether Antigravity CLI (agy) is installed and logged in with a Google account (subscription auth, not an API key), and guide the user through setup if not. Also manages the optional stop-time review gate.
argument-hint: '[--enable-review-gate|--disable-review-gate]'
allowed-tools: Bash
---

Raw arguments: `$ARGUMENTS`

If `$ARGUMENTS` contains `--enable-review-gate` or `--disable-review-gate`,
handle only that and skip the health check below:

```
bash "${CLAUDE_PLUGIN_ROOT}/scripts/gemini-config.sh" enable-review-gate
```
or
```
bash "${CLAUDE_PLUGIN_ROOT}/scripts/gemini-config.sh" disable-review-gate
```

Relay the script's own output verbatim — it already explains what changed.
If enabling, also mention: this runs a real (billed) Gemini call on every
Claude Code `Stop`, which can slow down or loop the session, so it's meant
to be turned on only while actively watching this session, not left on
globally.

Otherwise, run the normal health check:

Run `${CLAUDE_PLUGIN_ROOT}/scripts/check-antigravity-cli.sh` (find it under
the plugin directory if that variable isn't set).

- If it prints `OK`, tell the user Antigravity CLI is ready, show them the
  list of models it printed (from `agy models`), and mention they can now
  say things like "ask gemini to review this" or "get a second opinion
  from gemini" to trigger the `gemini` subagent.
- If it prints `NOT_INSTALLED`, `API_KEY_MODE`, or `NOT_LOGGED_IN`, show
  the user the script's guidance verbatim. Do not run the install or login
  commands yourself — `agy` login opens an interactive Google Sign-In flow
  the user has to complete themselves.

Also run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/gemini-config.sh" show` and
report the current review-gate status, mentioning `--enable-review-gate`
as available if the user wants Gemini to gate `Stop` events.
