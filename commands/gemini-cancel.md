---
description: Cancel a running background Gemini job.
argument-hint: '<job-id>'
allowed-tools: Bash
---

Run:
```
bash "${CLAUDE_PLUGIN_ROOT}/scripts/gemini-jobs.sh" cancel "$ARGUMENTS"
```

Return the output verbatim. A job id is required — if the user didn't give
one, run `/gemini-status` first to find it.
