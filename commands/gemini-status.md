---
description: Show background Gemini job status for this repository.
argument-hint: '[job-id]'
allowed-tools: Bash
---

Run:
```
bash "${CLAUDE_PLUGIN_ROOT}/scripts/gemini-jobs.sh" status "$ARGUMENTS"
```

Return the output verbatim. If no job id is given, this lists every known
job (newest first): id, status, mode, created_at, summary.
