#!/usr/bin/env python3
"""Stop hook: optional Gemini review gate for the previous Claude turn.

Reads Claude Code's Stop-hook JSON payload from stdin. If the review gate
is disabled (default), does nothing. If enabled, sends the previous
assistant turn to a Gemini model via `agy` and, on a BLOCK verdict, emits
{"decision": "block", "reason": "..."} so Claude Code re-prompts instead of
stopping.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

PLUGIN_ROOT = Path(__file__).resolve().parent.parent
REVIEW_TIMEOUT_SECS = 570  # stay under the hook's own 600s timeout


def resolve_state_dir(cwd: str) -> Path:
    out = subprocess.run(
        [str(PLUGIN_ROOT / "scripts" / "resolve-state-dir.sh"), cwd],
        capture_output=True, text=True, check=True,
    )
    return Path(out.stdout.strip())


def read_config(state_dir: Path) -> dict:
    config_file = state_dir / "config"
    enabled = False
    if config_file.exists():
        for line in config_file.read_text().splitlines():
            if line.strip() == "review_gate=1":
                enabled = True
    return {"review_gate": enabled}


def build_prompt(last_message: str) -> str:
    template = (PLUGIN_ROOT / "prompts" / "stop-review-gate.md").read_text()
    block = f"Previous Claude response:\n{last_message}" if last_message.strip() else ""
    return template.replace("{{CLAUDE_RESPONSE_BLOCK}}", block)


def pick_model(cwd: str) -> str:
    try:
        result = subprocess.run(
            ["agy", "models"], cwd=cwd, capture_output=True, text=True, timeout=15,
        )
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return "Gemini 3.5 Flash (Medium)"
    for line in result.stdout.splitlines():
        line = line.strip()
        if line.lower().startswith("gemini") and "flash" in line.lower():
            return line
    return "Gemini 3.5 Flash (Medium)"


def run_review(cwd: str, prompt: str) -> tuple[bool, str | None]:
    model = pick_model(cwd)
    try:
        result = subprocess.run(
            ["agy", "-p", "--model", model],
            input=prompt, cwd=cwd, capture_output=True, text=True,
            timeout=REVIEW_TIMEOUT_SECS,
        )
    except subprocess.TimeoutExpired:
        return True, "Gemini review gate timed out; allowing stop. Run /gemini-status if a job is stuck."
    except FileNotFoundError:
        return True, "agy not found; allowing stop. Run /gemini-setup."

    text = (result.stdout or "").strip()
    if not text:
        return True, "Gemini review gate got no output; allowing stop."

    # `agy` sometimes interleaves its own tool-progress narration ("I will
    # wait for the find command...") before the model's actual final
    # answer, so the ALLOW:/BLOCK: line isn't reliably the first line —
    # scan for the last line that matches the contract instead.
    verdict_line = None
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.upper().startswith(("ALLOW", "BLOCK")):
            verdict_line = stripped

    if verdict_line is None:
        return True, "Gemini review gate returned an unexpected answer; allowing stop."

    upper = verdict_line.upper()
    if upper.startswith("ALLOW"):
        return True, None
    reason = verdict_line.split(":", 1)[1].strip() if ":" in verdict_line else verdict_line
    return False, f"Gemini found issues that should be addressed before stopping: {reason}"


def main() -> None:
    raw = sys.stdin.read()
    payload = json.loads(raw) if raw.strip() else {}
    cwd = payload.get("cwd") or os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()

    config = read_config(resolve_state_dir(cwd))
    if not config["review_gate"]:
        return

    if os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY"):
        sys.stderr.write(
            "Gemini review gate: GEMINI_API_KEY/GOOGLE_API_KEY is set, so this "
            "review is billing against that key instead of your subscription.\n"
        )

    prompt = build_prompt(payload.get("last_assistant_message", "") or "")
    allow, note = run_review(cwd, prompt)
    if not allow:
        print(json.dumps({"decision": "block", "reason": note}))
    elif note:
        sys.stderr.write(note + "\n")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:  # defensive: never let the hook itself crash the Stop event
        sys.stderr.write(f"gemini review gate error: {exc}\n")
