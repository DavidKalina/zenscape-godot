# Harness: the motif yard (and what the agents kept rebuilding)

> 2026-10-14. Findings from the greybox-pool round (PR #25: five greybox
> motifs converted, turfed and chain-proved by five parallel Opus agents),
> and a brief for the next harness round. Read `tools/README.md` first.

## The finding: 80% of an agent's round was waiting on Godot

Timed from the five agents' transcripts (every tool call, start to result),
about 12.5 agent-hours in all:

| Where the time went | Hours | Share |
|---|---|---|
| Waiting on background Godot runs (`tools/bg.py wait`) | ~8.4 | 67% |
| Godot runs in the foreground (`drive.py`, `sweep.py`, `shot.py`, `godot.py`) | ~2.2 | 17% |
| The model itself (reading output, writing code, thinking) | ~1.4 | 11% |
| Reading and searching files | ~0.4 | 3% |

The Godot runs, from the agents' `scratch/bg/*.json` records:

| Run | Count | Average | Total |
|---|---|---|---|
| Chain checks (`drive.py`) inside a full `studies/run_layer.tscn` | 59 | 8.7 min | 8.6 h |
| Plan sweeps (`sweep.py` + `tools/layer_dump.gd`) | 22 | 4-11 min | 2.4 h |
| Rendered stills through `run_layer` | 5 | 7.6 min | 0.6 h, mostly timed out |

A typical chain check: the Warden's Well relay, 10 trials of about 11 s of
game time each (under 2 min of play), took **18.6 min** on the clock. The
rest is two costs that have nothing to do with the motif under test:

1. **Standing the whole layer before the first trial.** Every isle, its
   flora and life, the crossings, the serpent or ferry, enemies and bodies:
   about 90 s on a quiet machine, several minutes with five agents on four
   cores.
2. **Stepping the whole layer every frame of every trial.** Physics,
   enemies, bodies and life on every isle run while the check only watches
   one motif.

The one agent that cut its driver down to standing only its own isle (the
Plumb Well, `isle.build_now()` on its isle alone, still inside run_layer)
got 10-trial runs of **about 4.6 min** against the others' 15-18 min.

Other costs worth knowing:

- **Out-of-memory kills.** About eight Godot processes at once on a 15 GB
  container killed runs with -9. Agents then serialised by hand.
- **The plan-fit loop.** To get its motif placed at all, every agent forced
  it with `--knob=pool=classic --knob=greybox=<slug>`, then searched seeds
  with `layer_dump` for one where the generator entered it at the right rim.
  Several chain runs were wasted on seeds where it came in backwards or was
  the greed branch.
- **Stills.** No GPU in the cloud container: `shot.py` on `run_layer` ran on
  software GL at about one frame every 20 s and timed out. Each agent wrote
  its own scratch scene that renders the motif alone under GL Compatibility
  and Xvfb.
- **No shared trial helper.** Each agent wrote a 150-240 line chain driver
  (`scratch/*_chain.gd`) that repeats the same plumbing: find its isle and
  offset in the plan, drop `study.run_loop` and push `layer.void_y` far
  down (or a fall lays a new layer), force-build its isle, find its live
  host and traps, reset heads and traps between trials, jitter the start,
  print `ROW` lines and a pass rate.

## The motif yard

**What it is:** one scene that stands **one motif** (any `scripts/kit_isle/
greybox/gb_<slug>.gd`, grey or turf, and ideally any kit motif in
`LayerPlan.POOL`) on the real stage, with nothing else in the world. It
uses the same code paths the generator does, so a chain proven in the yard
holds in a layer:

- the real pilot, motor, input and camera (the same study base `run_layer`
  uses), so `tools/harness/drive.gd` drives it unchanged;
- the motif built by its own `build` (turf) or the grey path (its `--<slug>-grey`
  flag), placed at the origin or a fixed offset;
- its live parts through the **real** `scripts/roguelike/layer_stage.gd` and
  `scripts/roguelike/layer_greybox.gd` (`dress`, the live host `g`, its
  traps, ropes, cannons in the stage's CannonField, enemies in the stage's
  EnemyField);
- its inhaler heads laid by `LayerGreybox.lay_heads` (so their knobs, routes
  and cliffs are the generator's), with `--bodies=0|1` to have the headless
  bodies on or off;
- no run loop, no void card that lays a new layer, a net far below;
- optional stand-in rims: a flat pad off the way-in and way-out rims at
  the generator's sizes, so the walk-on and walk-off can be checked without
  a generated crossing.

The simplest build is probably a one-isle plan dict (`isles` with just the
motif at offset 0, no edges, `heads` from `lay_heads`, `cannon` and `ram`
empty, `void_y` far down, a spawn at `motif.start()`), handed to the same
`LayerStage.setup` that run_layer uses. Check every field `LayerStage`,
`LayerGreybox` and `LayerEnemies.dress` read from the plan, and give each a
yard default; don't fork the stage.

Launch, for example:

```sh
python tools/drive.py scratch/x_chain.gd -- --trials=10 --scene-args --motif=plumb_well [--grey] [--bodies=0] [--rims]
python tools/smoke.py studies/motif_yard.tscn -- --motif=lidstack
python tools/shot.py studies/motif_yard.tscn -- --motif=vigil_bellows   # stills of the motif alone
```

### A chain-trial helper in drive.gd

The second half of the saving: move the plumbing every `*_chain.gd`
repeated into `tools/harness/drive.gd` (or a `tools/harness/chain.gd` on
it), working in the yard and in `run_layer` alike:

- `motif_offset(slug)`, `motif_host(slug)` (the live host, its `traps`,
  `pieces`), `motif_heads(slug)`;
- `hold_layer()`: drop the run loop and push the void far down (needed in
  run_layer only);
- `reset_all()`: stage, heads, traps, cannons and enemies back as built;
- `trials(n, fn, jitter := 0.5, delay := Vector2(0.8, 1.2))`: runs `fn` n
  times from a jittered start and delay, collects pass/fail and a `ROW` per
  trial, prints `RESULT {passed, trials}`;
- `--grey` passed through to the motif's grey flag, so the turf-vs-grey A/B
  is two runs of one command.

Port one existing chain driver onto the helper as its example (the Plumb
Well's `scratch/pw_chain.gd` is short and has two chains), and keep it in
`tools/harness/examples/` or the README.

### Acceptance

1. `studies/motif_yard.tscn` stands each of the six greybox motifs
   (`sunken_giant`, `wardens_well`, `lidstack`, `plumb_well`,
   `vigil_bellows`, `noon_weir`), grey and turf, and `tools/smoke.py` passes
   on all twelve with no script errors.
2. At least two motifs' chains re-proved in the yard through the real input
   path, 10 jittered trials each, with **the same pass rates** as their
   full-layer runs in PR #25. One should be the Plumb Well column (fall,
   leaf, seesaw, slabs, head blast, cannon, landing) and one should use
   heads (the Warden's Well relay), to show heads and cannons behave the
   same.
3. Timing: the wall time of a 10-trial chain in the yard against the same
   chain in `run_layer`, on this machine, quiet. Target: under 4 min
   against about 15.
4. `tools/README.md` gains the yard and the trial helper in its table, with
   the "prove in the yard, confirm once in the layer" workflow.
5. The motif skills (`.claude/skills/motif-greybox`, `motif-turf`) and the
   header of `scripts/kit_isle/motif_greybox.gd` point at the yard for
   chain checks, with one full-layer run kept as the final confirmation.

## Also found (smaller, separate rounds)

In order of payoff:

1. **A motif probe** (`tools/motif_probe.gd`, or a yard mode): build a motif
   alone and print its walked tiers, lip edges, rims and spots as a table,
   and the turf-minus-grey difference per point. Every turf agent wrote one
   (`scratch/*_probe.gd`). In the yard this is a few raycasts from above
   (rays that start inside a walk box pass through it under Jolt).
2. **Stills without a GPU.** A `--compat` option on `tools/shot.py` (and on
   `drive.py --rendered`): GL Compatibility under Xvfb. With the yard there
   is a small scene to point it at. On the Mac, `shot.py` already works.
3. **One heavy run at a time.** A lock or slot count in `tools/bg.py` for
   Godot runs that build a layer (or the yard), so parallel agents queue
   instead of being killed out of memory.
4. **A placement finder.** `tools/layer_dump.gd --find=<slug>` (or a sweep
   column): the seeds where the motif is placed on the route and entered at
   its way in, so a full-layer confirmation runs on a seed that exercises
   the chain.
5. **A shared turf helper.** All six greybox motifs copy the same helpers
   from the Sunken Giant: `_collide_sides` is line-for-line identical in all
   six, and `_rounded`, `_stone`, `_walk`, `_block` and `_walk_shape` are
   copies with small tweaks (about 100 lines per motif). Move them next to
   `scripts/kit_isle/greybox/giant_stone.gd` (or into `motif_greybox.gd` as
   turf utilities), have the six use it, and point the turf skill at it.
   This is about code duplication, not time.
6. **The stage never poses traps.** `scripts/traps/trap_field.gd` `pose` is
   empty, so a trap's posed look (the sluice's carried lean and rock) isn't
   drawn in a layer. Looks only.

## Where the evidence is

The agents' worktrees in this session (`.claude/worktrees/agent-*`) hold
their scratch drivers, probes and `scratch/bg/*.json` run records. They are
not committed and won't survive the session. The chain drivers' approach
is summarised above. PR #25's description has every chain's pass rates for
comparison.
