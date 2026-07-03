---
description: Show the stored output of a background Gemini job (defaults to the most recent).
argument-hint: '[job-id]'
allowed-tools: Bash
---

Run:
```
bash "${CLAUDE_PLUGIN_ROOT}/scripts/gemini-jobs.sh" result "$ARGUMENTS"
```

Return the output verbatim, clearly labeled as Gemini's output (the command
already prints which job/model it came from). Don't summarize, edit, or
"improve" it.
