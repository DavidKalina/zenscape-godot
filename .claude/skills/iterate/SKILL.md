---
name: iterate
description: Run a build as parallel lanes (independent parts, one agent each) and a loop of fresh agents for the steps that must come in order, one task each, remembered through a commit trail, until the spec is done. Use for builds that span several stages or would run long in one agent (a place study, a dressing pass, a big feature), or when the user asks to iterate, loop or run something in iterations.
---

# Iterate

A build loop: each **iteration** is a fresh agent that reads the spec and
the **trail** (the loop's commits), does exactly one task, commits it with
notes for the next, and stops. Every iteration starts near the top of its
context, and every step is one commit you can read, revert or resume from.

Single short jobs (cards, plans, a quick fix) stay one agent; they gain
nothing from a loop.

## Split first

A loop runs one agent at a time, so only use it for work that has to come
in order. Before setting up, split the spec:

- **Lanes:** parts that don't need each other (one kit piece, one enemy,
  one isle) and fit in one agent each. Run every lane at once, one agent
  per lane, each in its own worktree branched from the loop's branch
  (`lane/<part>`). A lane too big for one agent runs as its own short loop.
- **The trunk:** the steps that need the lanes merged (a place built from
  the pieces, its routes, its stills), in order. This is the loop.

Brief each lane to keep its code in its own new file and its edits to
shared files (family lists, connector tables, editor build paths) small and
additive, and to end its commit with **Notes for merge**: the shared lines
it touched. Lane commits carry the loop's prefix, `ITER(<slug>): lane
<part>: <task>`. When the lanes land, merge them into the loop's branch
yourself, joining the shared lines, run the smoke checks, and commit the
merge under the prefix. Then run the trunk. Write the lanes and the trunk
into the spec so every iteration knows which pieces are built elsewhere.

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
5. **The cap.** 20 iterations, for every loop. Specs say "the skill's default" rather than a number, so changing it here changes it everywhere; a spec names its own number only when the user asks for one.
6. **The budget.** Each agent's context: a budget, 150000 tokens unless
   the user says otherwise (an agent starts near 20000), and a wrap-up
   buffer past it, a quarter of the budget unless set
   (`ITER-BUDGET: 200000 +40000`). The `ITER-BUDGET:` line in its launch
   prompt opts it into the hook in `.claude/settings.json`
   (`.claude/skills/iterate/iter_budget.py`). Past the budget every call
   still runs, and after each one the agent is told to wrap up: finish the
   run in progress, start nothing new, commit and hand back. Past budget +
   buffer every call but git and the hand-back is denied. That is what
   keeps any one task inside the budget: an agent that runs out commits what
   works and the next fresh agent carries on from its Notes. Lanes carry
   the line too.

## Run

For each iteration, launch one **new** agent in the background (never resume
an earlier one: a fresh context is the point) with
[iteration.md](iteration.md) filled in (SLUG, SPEC, WORKTREE, TOKENS: the budget) as its
prompt: the text itself, not a pointer to a file, since the hook reads the
`ITER-BUDGET` line from the launch prompt. When it
comes back:

- Read its last line: `<promise>COMPLETE</promise>`, `<promise>ABORT</promise>`
  or none.
- Read its commit: `git log -1 --format=%B`. It must carry the
  `ITER(<slug>):` prefix and its Decisions, Checks and Notes. Look at any
  stills it lists.
- Tell the user in one or two lines: the task done, its checks, and what's
  next.

Then:

- **No token, a good commit** (a budget stop included): launch the next
  iteration.
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
