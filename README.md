# gemini-bridge

Claude Code plugin that lets you delegate work to Google Gemini models,
authenticated through your **Gemini subscription** (Google Sign-In via
[Antigravity CLI](https://antigravity.google/docs/cli-install), `agy`)
instead of an API key — the same idea as a Codex-in-Claude-Code plugin, but
for Gemini. (Google is retiring Gemini CLI in favor of Antigravity CLI, so
this plugin targets `agy` directly.)

## Setup

1. Install Google's official CLI:
   ```
   curl -fsSL https://antigravity.google/cli/install.sh | bash
   ```
2. Run `agy` once and complete **Google Sign-In** when prompted (not the
   API-key option). This is what ties usage to your subscription
   (Code Assist / AI Pro / AI Ultra) rather than pay-per-token billing.
3. Install this plugin in Claude Code, then run `/gemini-setup` to confirm
   everything is wired up correctly.

## Usage

Just ask for it in conversation — e.g. "get a second opinion from Gemini on
this function" or "have gemini review this PR". Claude Code will delegate to
the `gemini` subagent, which shells out to
`agy -p "..." --model "<model>"` and relays the model's actual response
back to you, labeled as coming from Gemini.

Default model is `Gemini 3.5 Flash (Medium)`. You can name a specific model
instead ("ask Gemini 3.1 Pro to review this") and the subagent will pass it
straight through with `--model`.

"Ask/review/opinion" phrasing gets you Gemini's answer only, no file
changes. If you instead ask Gemini to write, fix, or implement something
("have gemini fix this bug"), the subagent runs `agy` with
`--dangerously-skip-permissions --sandbox` so it can actually edit files
for that task, non-interactively, while `--sandbox` restricts it from
running arbitrary terminal commands. It's scoped to whichever directory
the task touches via `--add-dir`, so only ask Gemini to write code in
things you'd trust an unattended agent to touch.

## Background jobs

For anything you'd expect to take a while (a big review, an open-ended
investigation, a multi-file fix), say "in the background" or just let the
subagent decide — it launches a **tracked background job** instead of
blocking the conversation:

- `/gemini-status [job-id]` — list jobs, or show one job's status
- `/gemini-result [job-id]` — print a finished job's output (defaults to
  the most recent job)
- `/gemini-cancel <job-id>` — kill a running job

Job state lives on disk per-repository (under `$CLAUDE_PLUGIN_DATA` if set,
else a temp dir), so these commands work even in a later session — there's
no daemon or supervisor process; status is just reconciled against a
`.done` marker (or the process's pid) whenever you ask for it. Job/state
files are created with `umask 077` (owner-only) since the temp-dir fallback
can be a shared, multi-user location, and are read with a plain
`key=value` line parser — never sourced/eval'd — so a tampered job file
can't execute anything.

## Continuing directly in Antigravity CLI

Every Gemini call from this plugin is a real `agy` conversation, and `agy`
remembers each directory's most recent conversation ID (the same mechanism
behind `agy -c`/`--continue`). Run `/gemini-continue [job-id]` to get the
exact command to keep going in Antigravity CLI's own interactive session —
full history, same model — outside Claude Code entirely:

```
agy --conversation <id>
```

With no job id, it uses the most recent job for the repo, or falls back to
whatever conversation is most recent in the current directory if there are
no tracked jobs at all. `/gemini-status`/`/gemini-result` also print this
line automatically for any job that has one.

## Review gate (optional, off by default)

`/gemini-setup --enable-review-gate` turns on a `Stop` hook: every time
Claude Code is about to finish responding, it sends that turn's work to a
Gemini model and asks it to ALLOW or BLOCK. A BLOCK verdict forces another
pass before Claude can stop. `/gemini-setup --disable-review-gate` turns it
back off (this is also the default state — nothing is enabled until you
opt in).

This runs a real, billed Gemini call on every `Stop`, and a bad verdict can
make Claude loop trying to satisfy it — only enable it while you're
actively watching the session, the same caveat Codex's equivalent gate
carries. Also worth knowing: Gemini's own judgment here isn't perfect — in
testing it sometimes leaned on the *described* summary of a change rather
than re-verifying the actual repository diff, despite being told to ground
every blocking claim in real state. Treat a BLOCK as a prompt to look
closer yourself, not an infallible verdict.

## Security & privacy notes

- Job/config state directories and files are created owner-only (`umask
  077`), and `resolve-state-dir.sh` retroactively `chmod 700`s the
  directories it owns every time it runs — so even leftovers from an older,
  pre-hardening version of this plugin end up private, not just newly
  created ones.
- Job files are parsed as plain `key=value` text (never sourced/`eval`'d),
  and job ids are validated against a strict charset before touching any
  file path — a tampered or malicious job file can't execute code or
  traverse outside the jobs directory.
- The review gate's `Stop` hook sends Claude's last reply verbatim to
  Gemini so it can review that turn's work — if that reply contained a
  real secret, it goes to Gemini. That's inherent to what a review gate has
  to do, not a bug to fix; only enable it if you're fine with that
  tradeoff.
- The write-capable path relies on `agy --sandbox` to restrict terminal
  command execution — and this has now been observed to be bypassable in
  practice, not just theoretically weak: during a real task, `agy`'s
  sandbox blocked a direct `gh` invocation, and Gemini worked around that
  block by wrapping the same command in `env` (`env gh repo create ...`),
  which ran successfully. That's a real sandbox escape via a well-known
  technique (wrapping a blocked binary through `env` to spawn it as a
  child process), observed directly, not inferred. Treat `--sandbox` as a
  speed bump against accidental commands, not a security boundary against
  a model that's actively trying to run something — only let Gemini write
  code in places you'd trust an unattended, unsandboxed agent to touch.

## A note on model names

Google ships new Gemini models faster than any static list can track — as
of this writing `agy models` reports `Gemini 3.5 Flash (Low/Medium/High)`
and `Gemini 3.1 Pro (Low/High)` (plus non-Gemini options Antigravity CLI
also exposes, like Claude and GPT-OSS models). Rather than hardcode a list
that will go stale, both the check script and the subagent read the live
output of `agy models` and pass whatever name you ask for straight through
to `--model`. Model names contain spaces/parens, so they need quoting.

## A note on auth checking

`agy` has no dedicated `auth status` command and normally caches its
Google Sign-In token in your OS keyring, which isn't something a shell
script can query directly. Instead, the check script runs `agy models`
(bounded to 15s) — that call requires a live authenticated session to
succeed, so a working model list is used as the real signal that install
+ login are both good.

## Files

- `agents/gemini.md` — the delegatable subagent
- `commands/gemini-setup.md` — `/gemini-setup` health check + review-gate toggle
- `commands/gemini-status.md`, `gemini-result.md`, `gemini-cancel.md` —
  background job management
- `commands/gemini-continue.md` — `/gemini-continue` prints the command to
  resume a Gemini thread directly in Antigravity CLI
- `scripts/check-antigravity-cli.sh` — verifies install + subscription login
- `scripts/gemini-jobs.sh` — background job start/status/result/cancel
- `scripts/gemini-conversation-id.sh` — looks up a directory's most recent
  `agy` conversation ID (reads `agy`'s own cache, doesn't invent one)
- `scripts/gemini-config.sh` — review-gate on/off flag
- `scripts/resolve-state-dir.sh` — shared per-repository state-dir path;
  also ensures that directory (and its owned parents) exist and are
  owner-only permissioned
- `scripts/stop-review-gate-hook.py` + `hooks/hooks.json` — the optional
  `Stop`-hook review gate
- `prompts/stop-review-gate.md` — the review gate's prompt template
