<task>
Run a stop-gate review of the previous Claude turn in this repository.
Only review work from the immediately previous Claude turn.
Only review it if Claude actually made code changes in that turn.
Pure status updates, setup/login checks, or reporting output do not count as
reviewable work.
If the previous turn did not make direct edits, return ALLOW immediately and
do no further work.
Otherwise, challenge whether that specific work and its design choices
should ship.

{{CLAUDE_RESPONSE_BLOCK}}
</task>

<output_contract>
Return a compact final answer.
Your first line must be exactly one of:
- ALLOW: <short reason>
- BLOCK: <short reason>
Do not put anything before that first line.
</output_contract>

<policy>
Use ALLOW if the previous turn did not make code changes, or if you find no
blocking issue.
Use BLOCK only if the previous turn made code changes and you found
something that still needs fixing before stopping.
Ground every blocking claim in the actual repository state you inspected —
do not block based on older edits from earlier turns.
</policy>
