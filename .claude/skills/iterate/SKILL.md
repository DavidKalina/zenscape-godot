---
name: iterate
description: Run a build as a loop of fresh agents, one task each, remembered through a commit trail, until the spec is done. Use for builds that span several stages or would run long in one agent (a place study, a dressing pass, a big feature), or when the user asks to iterate, loop or run something in iterations.
---

# Iterate

A build loop: each **iteration** is a fresh agent that reads the spec and
the **trail** (the loop's commits), does exactly one task, commits it with
notes for the next, and stops. Every iteration starts near the top of its
context, and every step is one commit you can read, revert or resume from.

Single short jobs (cards, plans, a quick fix) stay one agent; they gain
nothing from a loop.

## Set up

1. **Name the loop** with a short slug, e.g. `olmec-ring`. Its trail prefix
   is `ITER(<slug>):`.
2. **The spec.** A plan, a card, or a brief you write, as a file in the repo
   (e.g. `docs/design/<topic>/spec-<slug>.md`). It says what done looks like,
   in what the user will play and see. Commit it as the loop's first commit:
   `ITER(<slug>): spec`.
3. **The branch.** A worktree on its own branch (AGENTS.md, Fresh
   worktrees), unless the user names one. Other sessions' work stays out.
4. **The model** per AGENTS.md, Subagent models: the same for every
   iteration of the loop.
5. **The cap.** 12 iterations unless the user says otherwise.

## Run

For each iteration, launch one **new** agent in the background (never resume
an earlier one: a fresh context is the point) with
[iteration.md](iteration.md), filling in SLUG, SPEC and WORKTREE. When it
comes back:

- Read its last line: `<promise>COMPLETE</promise>`, `<promise>ABORT</promise>`
  or none.
- Read its commit: `git log -1 --format=%B`. It must carry the
  `ITER(<slug>):` prefix and its Decisions, Checks and Notes. Look at any
  stills it lists.
- Tell the user in one or two lines: the task done, its checks, and what's
  next.

Then:

- **No token, a good commit:** launch the next iteration.
- **ABORT:** stop. Bring the blocker to the user.
- **No commit, or the same task twice without progress:** stop. Tell the
  user what it tried.
- **COMPLETE:** finish (below).
- **The cap is reached:** stop, and report what's left from the last Notes.

The user can redirect between iterations. Change the spec file and commit it
as `ITER(<slug>): spec change: <what>`; the next iteration reads it. If the
user asks to stop, let the running iteration finish its commit, then stop.

## Finish

1. Run the spec's smoke checks yourself and look at the final stills.
2. Write the handoff from the trail: `git log --grep='^ITER(<slug>)'
   --format='%B'` turned into a short doc beside the spec (what's built,
   where to play it, what's stood in, what's open). Commit it under the
   prefix.
3. Open the result for the user (its launcher), one window.
