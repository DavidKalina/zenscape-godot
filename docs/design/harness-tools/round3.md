# Harness tools, round 3: discovery

The survey (`scratch/tool-survey.md`, "Discovery gaps") found agents
rewriting helpers the harness already had: they read `drive.gd`'s source
rather than `tools/README.md`. This round puts the helper list where agents
look and adds a cue at the moment they start a driver. No game code changed.

## What changed where

| File | Change |
|---|---|
| `tools/drive.py` | `--api [WORD] [--update]`. It prints every public helper of `tools/harness/drive.gd`, `chain.gd` and `stations.gd` with its signature and the first sentence of its `##` doc, grouped by the `# --- X ---` sections. It reads the scripts and never launches Godot. `--api WORD` keeps the helpers and sections whose name contains WORD, and adds their whole docs and the section's `#` notes (route opts, watch opts, what each returns). It exits 1 when a header index is stale. |
| `tools/harness/drive.gd` | The header has a generated index, one line per public helper, grouped by section. It sits between `## Index (...)` and `## (end of index)`. `--api --update` rewrites it, and `--api` fails while it differs from the code. New `# --- Shots ---` section for `shot()`. One-line `##` docs added to the helpers that had none (`arg_int`, `flag`, `hold`, `let_go`, `first`, `check`, `result`, `finish` and others). `motor` has its own doc. `watch()` has a new opt `row`: `true` (default `--watch-row`) prints a closing `ROW {watch, pilot, frames, changes, closest, knocks, stuns, set_back, hearts_lost, state, last_state}`, and a Dictionary adds its own columns. |
| `tools/harness/chain.gd` | Docs for `motif_index`, `motif_offset`, `motif_isle`, `motif_host` and the fields. Its hand-written header now names `motif_start`, `motif_floor` and `motif_box`. `--api` checks that this header names every public function. |
| `tools/sweep.py` | `--arg name=a,b` (repeatable) is an axis that goes to the driver as `--name=a`, before `--scene-args`. The other axes and flags are unchanged. |
| `tools/README.md` | New rows: `drive.py --api`, `sweep.py --arg`, the watch `row`, `layer_dump.gd` ("What a run layer lays"), and the parse check (`godot.py --check-only -s`). A "The full list" bullet under drive.gd. `--arg` in the sweep section. |
| `AGENTS.md` | One cue line (below). |
| Skill briefs | One line each (below). |

### Why the index is generated, not hand-kept

The index and `--api` come from one parse (`api_items` in drive.py). A
hand-kept index would drift. With the generated one, a changed helper means
running `--api --update`, and plain `--api` exits 1 with
`== stale header: drive.gd: its index differs from the code` until then.
chain.gd keeps its hand-written annotated header, because the annotations
are worth more than a generated list. It gets a coverage check instead,
which names any public function the header misses.

## Lines added

AGENTS.md, "The harness":

> Throwaway drivers go in `scratch/` (git-ignored); before
> writing one, run `python tools/drive.py --api` for the helpers it can call.

`.claude/skills/motif-greybox/agent-brief.md`, Prove it, step 3:

> Helpers: `route()` / chain.gd
> `walk_motif_paths()`, `watch()`, `ray()` / `what_is_at()`; `python tools/drive.py --api WORD`.

`.claude/skills/motif-turf/SKILL.md`, step 6:

> (helpers:
> `route()` / `walk_motif_paths()`, `watch()`, `ray()` / `what_is_at()`; `python tools/drive.py --api WORD`)

`.claude/skills/iterate/iteration.md`, "Movement, routes, enemies" check (a
minimal addition, inside the existing parenthesis):

> ; `python tools/drive.py --api` lists its helpers

Not changed: `motif-plan`. Its brief says "no code edits, no Godot runs",
so it has no proof step for a driver. The greybox `SKILL.md` was not changed
either: the orchestrator only smokes and shoots there, and its agents get
the brief line.

## The sweep example

```
python tools/sweep.py scratch/watch_weeper.gd --arg pilot=stand,flee,dodge -j 3 -- --watch-row --frames=600
```
```
pilot  changes  closest  frames  hearts_lost  knocks  last_state  set_back  state  stuns  watch   ok   s
stand  7        1        600     -1           1       blow        0         blow   1      weeper  yes  2.7
flee   43       5.49     600     -1           0       snap        0         snap   0      weeper  yes  2.7
dodge  7        1        600     -1           1       blow        0         blow   1      weeper  yes  2.7
```

`python tools/sweep.py scratch/watch_guacharo.gd --arg case=stand,dodge,leap -j 3 -- --trials=1`
gives one row per case from the driver's own `row()`: stand dropped (knocks
2), dodge miss, leap buffet.

The weeper's `dodge` matches `stand`. Without `--on-blow`, the dodge only
fires within `dodge_at` (half a second of his run), and the blow lands
first. That is the weeper and the driver, not the sweep.

## Proven (headless)

- `python tools/drive.py --api` lists all round 1 helpers (`ray`, `pierce`,
  `what_is_at`, `what_is_in`, `colliders`, `collision_box`, `hit_text`,
  `space`) and all round 2 helpers (`walk_leg`, `route`, `walk_paths`,
  `watch`, chain.gd `walk_motif_paths`). Exit 0. A copy with a renamed
  function is reported stale.
- The two sweeps above: 3/3 each. The old axes still work:
  `sweep.py tools/layer_dump.gd --seed 1..2 --shape ring --knob gulf=40,60`
  gives 4/4.
- Headless import: 0 errors. Smoke: aqueduct_isle, motif_yard
  (`--motif=plumb_well`) and weeper_yard, 3/3 PASS.
- `tools/harness/examples/plumb_well_chain.gd --trials=3 --motif=plumb_well --bodies=0`: 3/3.
- `godot.py --check-only -s` catches the untyped `:=` parse error in a
  SceneTree script and in a Node script (exit 1), and passes clean ones.

## Not done / gaps

- From the survey, not done: `godot.py --check FILE...` for many files at
  once (`--check-only` takes one script), `layer_dump.gd --contents` and
  `--problems`, `sweep.py --logs DIR`, and `tree()` for node finding.
- `tools/index.py` is still rarely used. The README row and AGENTS.md line
  point at it as before.

## Tests

No existing test breaks: no test uses `tools/harness/`, `drive.py` or
`sweep.py`. The full suite was not run, and no tests were added.
