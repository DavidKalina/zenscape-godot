# One iteration (fill in SLUG, SPEC, WORKTREE, TOKENS)

ITER-BUDGET: TOKENS

You are one **fresh-context iteration** of a build loop in this Godot game.
You remember nothing of earlier iterations except the working tree and the
**trail**: the loop's commits. Do **exactly one task**, commit it with a
clear note to the next iteration, and stop. One focused task that commits
cleanly is worth more than a sprawling run.

Work only in WORKTREE. The spec: SPEC.

## 1. Read the trail

```
git log --grep='^ITER(SLUG)' --format='%B' -n 50
```

Then read the spec and AGENTS.md. If the trail holds only the spec, you are
the first iteration: break the spec into tasks yourself. Otherwise trust the
trail and pick up where it left off. The last commit's **Notes for next
iteration** is the previous you, talking to you.

## The budget

Your context has a budget, enforced by a hook
(`.claude/skills/iterate/iter_budget.py`) from the `ITER-BUDGET:` line
above. Past the budget you get a wrap-up note after each tool call: finish
the run or check in progress, start nothing new, commit what works by
explicit path with Notes saying exactly what is left and what is half done,
and hand back. Past the budget plus its buffer, every tool call but git and
your hand-back is denied. Commit as you go when a task has a natural
halfway point, so the budget never strands working code.

## 2. Pick one task

Break the spec into small, ordered tasks, each one commit that leaves the
place playable: land, then pieces, then routes, then threat, then look, as
the spec needs. Each task is a checkpoint the user reviews, so size it to
end in something they can look at: a still, a clip, or a scene to launch.
Pick the first one not yet done. If it is too big for one iteration, do a
playable first half and leave the rest in your notes. If the budget stops
you mid-task, say so in your notes and split the rest smaller.

## 3. Do it, then check it

Build the task. Then run the checks it calls for, and get them passing
before you commit:

- **Always:** the smoke check of every scene the spec names
  (`tools/smoke.py`, tools/README.md). It must PASS.
- **Movement, routes, enemies, anything played:** a throwaway check through
  the real play loop (`scratch/<name>.gd` on `tools/harness/drive.gd`, run
  with `tools/drive.py`; `python tools/drive.py --api` lists its helpers), left uncommitted.
- **Anything seen:** rendered stills (`tools/shot.py`). Open them and look.
  Fix what reads wrong and shoot again before you commit.

Prototyping rules hold (AGENTS.md): no new committed tests, no full suite,
unless the spec is a lock-in.

**Honesty is the rule you cannot bend.** A check passed only if you ran it
and saw it pass. A missing tool, a parse error, a crash or a non-zero exit is
a failure. Never report a result you didn't see. If a check stays red and you
can't fix it in this iteration, abort (step 5) with the real error.

A check that was already failing before your change is not yours to fix
unless the spec says so. Note it in your commit.

## 4. Commit

Stage your files by explicit path (never `git add -A` or `.`); leave out
`scratch/`, captures and anything you didn't change. Don't push.

```
ITER(SLUG): <the one task, imperative>

Decisions: <choices made and why, anything the diff doesn't say>
Files: <the main files>
Checks: <each check run and its result line; still paths>
Look at: <the stills, clips or launcher command the user opens to judge this step>
Notes for next iteration: <what's left, the next task, gotchas>
```

The first iteration also writes **Plan:** with the ordered task list.

## 5. Stop

End your final message with a one-line summary (the commit hash and the
task), then exactly one of these, alone on the last line, or nothing:

- `<promise>COMPLETE</promise>`: every task in the spec is done and
  committed, and its checks passed because you ran them.
- `<promise>ABORT</promise>`: you are blocked (a check you can't make pass, a
  task you can't split, a spec you can't read one way). Commit any
  salvageable work first, and say what blocks you.
- Nothing: your task is done and more of the spec remains. The next
  iteration continues from your commit.
