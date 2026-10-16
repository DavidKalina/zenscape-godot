#!/usr/bin/env python3
"""Hook: a context budget with a wrap-up buffer for iterate-skill agents.

An agent opts in by carrying `ITER-BUDGET: <tokens>` in its launch prompt
(the iterate skill puts it there), optionally `ITER-BUDGET: <tokens>
+<buffer>`; the buffer defaults to BUFFER_SHARE of the budget. On every tool
call the hook reads that agent's own transcript and takes the context size
of its latest model call (input + cache read + cache write tokens).

- Under the budget: nothing.
- Past the budget (soft): every call still runs, and after each one
  (PostToolUse) the agent is told to wrap up: finish the run or check in
  progress, start nothing new, commit and hand back.
- Past budget + buffer (hard): before each call (PreToolUse) everything
  but git and the report hand-back is denied.

Every other session and agent is let through untouched, and any error lets
the call through (the hook never blocks work by failing).

    python3 .claude/skills/iterate/iter_budget.py --check <agent transcript.jsonl>

prints the budget, the hard limit and the context size it reads.
"""
import json
import os
import re
import sys

MARKER = re.compile(r"ITER-BUDGET:\s*(\d+)(?:\s*\+\s*(\d+))?")
BUFFER_SHARE = 0.25  # the wrap-up buffer when the marker names none
TAIL = 512 * 1024  # bytes read from the transcript's end for the last usage
REPORT_TOOLS = ("SubagentHandback",)  # how an agent delivers its final report
GIT_ONLY = re.compile(r"^\s*(cd\s+\S+\s*&&\s*)*git\s")


def agent_transcript(hook):
    """The subagent's own transcript, beside the parent session's."""
    agent, session = hook.get("agent_id"), hook.get("session_id")
    parent = hook.get("transcript_path") or ""
    if not agent or not session or not parent:
        return None
    path = os.path.join(os.path.dirname(parent), session, "subagents",
                        "agent-%s.jsonl" % agent)
    return path if os.path.exists(path) else None


def limits_of(path):
    """(budget, hard limit) from the agent's first user message, or None."""
    with open(path, encoding="utf-8") as f:
        for line in f:
            try:
                d = json.loads(line)
            except ValueError:
                continue
            if d.get("type") != "user":
                continue
            content = d.get("message", {}).get("content")
            if isinstance(content, list):
                content = " ".join(c.get("text", "") for c in content
                                   if isinstance(c, dict))
            m = MARKER.search(content or "")
            if not m:
                return None
            budget = int(m.group(1))
            buffer = int(m.group(2)) if m.group(2) else int(budget * BUFFER_SHARE)
            return budget, budget + buffer
    return None


def context_of(path):
    """Context tokens of the agent's latest model call (0 if none yet)."""
    with open(path, "rb") as f:
        f.seek(0, os.SEEK_END)
        f.seek(max(0, f.tell() - TAIL))
        lines = f.read().decode("utf-8", "ignore").splitlines()
    for line in reversed(lines):
        try:
            d = json.loads(line)
        except ValueError:
            continue
        u = d.get("message", {}).get("usage") if d.get("type") == "assistant" else None
        if u:
            return (u.get("input_tokens", 0) + u.get("cache_read_input_tokens", 0)
                    + u.get("cache_creation_input_tokens", 0))
    return 0


def allowed_past_hard(hook):
    """Past the hard limit only git (after an optional cd) and the agent's
    hand-back of its report are let through."""
    if hook.get("tool_name") in REPORT_TOOLS:
        return True
    if hook.get("tool_name") != "Bash":
        return False
    cmd = (hook.get("tool_input") or {}).get("command", "")
    return bool(GIT_ONLY.match(cmd))


COMMIT = ("commit what works by explicit path with the loop's message "
          "(Decisions, Files, Checks you actually ran, and Notes for next "
          "iteration saying exactly what is left and what is half done; if "
          "nothing works yet, commit nothing and say so), then hand back "
          "your report with its one-line summary.")


def main():
    if len(sys.argv) == 3 and sys.argv[1] == "--check":
        path = sys.argv[2]
        print("limits", limits_of(path), "context", context_of(path))
        return
    hook = json.load(sys.stdin)
    path = agent_transcript(hook)
    if not path:
        return
    limits = limits_of(path)
    if not limits:
        return
    budget, hard = limits
    used = context_of(path)
    event = hook.get("hook_event_name")
    if event == "PostToolUse" and budget <= used < hard:
        note = ("ITER-BUDGET: your context is %d tokens, past the budget of %d. "
                "Wrap up now: finish the run or check already in progress if "
                "it is close, start no new work, then %s Past %d tokens only "
                "git and the hand-back will run." % (used, budget, COMMIT, hard))
        print(json.dumps({"hookSpecificOutput": {
            "hookEventName": "PostToolUse",
            "additionalContext": note}}))
    elif event == "PreToolUse" and used >= hard and not allowed_past_hard(hook):
        reason = ("ITER-BUDGET hard limit: your context is %d tokens, past %d. "
                  "No more work this iteration. Only git and the hand-back "
                  "run now: %s" % (used, hard, COMMIT))
        print(json.dumps({"hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason}}))


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass  # never block work by failing
