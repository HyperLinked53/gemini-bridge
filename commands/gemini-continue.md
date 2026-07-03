---
description: Print the command to continue a Gemini thread directly in Antigravity CLI, outside Claude Code.
argument-hint: '[job-id]'
allowed-tools: Bash
---

Raw arguments: `$ARGUMENTS`

If a job id was given, run:
```
bash "${CLAUDE_PLUGIN_ROOT}/scripts/gemini-jobs.sh" status "$ARGUMENTS"
```
and read the `continue in Antigravity CLI: agy --conversation <id>` line from
its output.

If no job id was given, first try the most recent job for this repository:
```
bash "${CLAUDE_PLUGIN_ROOT}/scripts/gemini-jobs.sh" result
```
and read the same line from its output. If there are no jobs at all (it
says "no gemini jobs yet"), fall back to whatever Gemini conversation is
most recent in the current directory:
```
bash "${CLAUDE_PLUGIN_ROOT}/scripts/gemini-conversation-id.sh" "$PWD"
```
That prints a bare conversation ID (or nothing/exit 1 if there isn't one
yet — tell the user there's no Gemini conversation to continue in that
case, and that a plain `agy` in this directory starts a fresh one).

Once you have an id, tell the user the exact command to run themselves in
a terminal — don't try to run it interactively yourself, Antigravity CLI's
normal (non `-p`) mode needs a real TTY that this tool call doesn't have:

```
agy --conversation <id>
```

This drops them into Antigravity CLI's normal interactive session,
continuing that exact thread — full history, same model, same
project/sandbox settings — so they can keep going directly in Gemini's own
CLI instead of through Claude Code.
