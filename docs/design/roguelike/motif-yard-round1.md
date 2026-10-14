# Motif yard, round 1

> 2026-10-14. Harness round on `harness/motif-yard`: branched from
> `origin/proto/greybox-pool` (PR #25), with `origin/roguelike` merged in.
> The merge had no conflicts. The brief is
> [harness-motif-yard.md](harness-motif-yard.md). This is a prototyping
> round: no tests were added and the suite wasn't run.

## What was built

- **`studies/motif_yard.tscn`** (`studies/motif_yard.gd`,
  `studies/motif_yard_sky.gd`). It stands one motif with nothing else in
  the world.
  - It extends `studies/kit_isle.gd`, the same base `run_layer` stands on
    (under the aqueduct isle). So the pilot, motor, input, camera and tick
    are the same, and `tools/harness/drive.gd` drives it unchanged.
  - The motif is a placed isle (`MotifIsle` in a `MotifSky`, which the
    sky's `setup_layer` makes as run_layer's sky does), so it gets its turf,
    flora and life.
  - Its live parts go through `LayerStage.setup`, which calls
    `LayerGreybox.dress` and `LayerEnemies.dress`. The plan is a one-isle
    dict built by `yard_plan`. The isle comes from `LayerPlan._motif_isle`,
    the same call the generator makes, and the heads from
    `LayerGreybox.lay_heads`.
  - There's no run loop and no void card. A fall past the net (60 m under
    the motif's lowest solid) puts him back at the start, and R resets the
    stage.
  - When the window is rendered, the isle builds on its worker, as in a
    layer, and he is held at the start until it stands. The main thread
    can't wait on that worker, because the worker's server calls wait on
    the main thread.
- **The six motifs' grey flags** now read `LaunchArgs.user_args()` instead
  of the raw command line. That lets the yard's `--grey`, and a driver's
  `--scene-args`, reach them. It's a one-line change in each `gb_*.gd`.
- **`tools/harness/chain.gd`**, the chain-trial helper on drive.gd. It
  provides `open_motif` (yard, or `--in=layer`), `motif_index`,
  `motif_offset`, `motif_point`, `motif_isle`, `motif_host`, `motif_heads`,
  `cannons`, `hold_layer`, `reset_all`, `trials(n, fn, jitter, delay)`
  (a ROW per trial, and `RESULT {passed, trials, rate}`), `rest(region)`
  and `motif_box`. In the layer it adds `--knob=greybox=<slug>` and turns
  `--grey` into the motif's own flag.
- **Examples** in `tools/harness/examples/`:
  - `plumb_well_chain.gd`: the column, plus `--chain=cannon`.
  - `wardens_well_chain.gd`: the relay, plus `--chain=cannon`, the missed
    relay.

  The PR #25 drivers were gone, so both were rewritten from the motifs'
  code and cards.
- **Docs.** `tools/README.md` has the table rows and a "prove in the yard,
  confirm once in the layer" section. The `motif-greybox` and
  `motif-turf` skills and the header of `scripts/kit_isle/motif_greybox.gd`
  now point chain checks at the yard, with one full-layer run kept as the
  final confirmation.

## Launch

```
godot --path . res://studies/motif_yard.tscn -- --no-title --motif=plumb_well [--grey] [--bodies=0|1] [--rims] [--at=x,y,z] [--sky]
python tools/smoke.py studies/motif_yard.tscn -- --motif=lidstack --grey
python tools/drive.py tools/harness/examples/plumb_well_chain.gd -- --trials=10 --scene-args --motif=plumb_well --bodies=0 [--grey]
python tools/drive.py tools/harness/examples/wardens_well_chain.gd -- [--chain=cannon] --trials=10 --scene-args --motif=wardens_well --bodies=0 [--grey]
python tools/bg.py start pw_layer -- python tools/drive.py tools/harness/examples/plumb_well_chain.gd --timeout 2400 -- --in=layer --trials=10 --scene-args --seed=1 --shape=sprawl --knob=pool=classic --knob=bodies=0
python tools/shot.py studies/motif_yard.tscn --frame Motif_gb_noon_weir --view three -- --motif=noon_weir [--sky]
```

`--motif=` also takes a kit pool id such as `bell_spires`. A kit motif
stands (smoke PASS) but has no heads.

## Smoke: 12/12

The yard ran headless, 400 frames each, on the final code. In every run he
was grounded at the motif's start.

| Motif | Turf | Grey |
|---|---|---|
| sunken_giant | PASS, ready 4.2 s | PASS, 3.7 s |
| wardens_well | PASS, 3.3 s | PASS, 3.2 s |
| lidstack | PASS, 3.1 s | PASS, 3.1 s |
| plumb_well | PASS, 3.2 s | PASS, 3.1 s |
| vigil_bellows | PASS, 3.3 s | PASS, 3.2 s |
| noon_weir | PASS, 3.2 s | PASS, 3.1 s |

There were 0 errors in every run. Grey really is grey: the net moves
because the keels leave the occupancy, and no turf flora grows.

## Chains: yard against PR #25

All runs were headless and used the real input path: drive.gd's actions
read by the study's own tick, with no scripted pushes. Each was 10 trials,
with the start jittered ±0.5 m and a 0.8-1.2 s delay with the traps and
heads running first. All used `--bodies=0`.

| Chain | PR #25 (layer) | Yard turf | Yard grey | Layer turf (sprawl 1, this round) |
|---|---|---|---|---|
| Plumb Well: the column (leaf, seesaw, slabs, head gulp and blast, cannon, landing) | 10/10, 10/10 | **10/10** | **10/10** | **10/10** |
| Warden's Well: the head relay | 10/10, 10/10 | **10/10** | **10/10** | **10/10** |
| Warden's Well: missed relay to the cannon | 10/10, 10/10 | **10/10** | **10/10** | not run |

The rates match. Some notes on the runs:

- **Plumb Well column.** Every trial touched the leaf (26 m), the seesaw
  (17 m) and the slabs (8 m). The head gulped him 4.7-8.7 s in, and the
  cannon fired 7.6-11.6 s in. He came to rest on the landing at (26.99,
  -14.23 turf / -14.0 grey, -9.2), the landing's east edge, 1 m past the
  rim-out point.
  - Input: he runs off the cap (full stick), pulls back south in the air
    onto the leaf, then lets go. That follows the motif's brief.
  - A half-stick walk-off fails 0/3, grey and turf alike: he catches
    oculus 1's lip as a ledge and hangs.
  - At full stick with no pull-back he skips the leaf: the seesaw catches
    him from 18 m and the chain still completes, as the card predicted.
  - PR #25 doesn't say what input its driver used, so I chose this one
    from the brief rather than tuning it to match.
- **Relay.** Head 1 gulped him at 2.8-3.2 s, he was on cell 1 at 5.0-5.3 s
  and head 2 gulped him at 8.1-8.5 s. He came to rest at (-19.7, -11,
  -13.2 to -13.4), the study's own numbers. The layer's rest points match
  the yard's to within 1 cm.
- **Missed relay.** Head 2 is taken off the field, as its body would take
  it. He runs west off cell 1 from where head 1's skid ends. The cannon
  catches him and fires at 1.2-1.4 s, and he rests at (-24.5, -11, -14.9).
- **Bodies on** (`--bodies=1`, the default) gave the same 10/10 for the
  column and the relay. No body came up during a trial, as in PR #25.
  `reset_all` restarts each head's bodiless clock, and a trial is short.

## Timing (this Mac, quiet-ish)

The machine is an M5 Pro with 18 cores and 48 GB. The load average was
3-6 throughout. Another session's windowed `bench_loading` runs came and
went. I ran Godot one run at a time.

| One 10-trial chain, wall clock | Yard | run_layer (sprawl 1, `pool=classic`) |
|---|---|---|
| Plumb Well column | **10-11 s** (stood 1.6 s, trials 6.5-6.9 s) | **79 s** (stood 25 s, trials 52 s) |
| the same, whole layer stood up front (`--motifs-now`; stood whole in 43 s) | | **93 s** |
| Warden's Well relay | **8-9 s** | **69 s** |

The yard is well under the 4 min target, about 8x faster than the layer
here. The brief's ~15 min layer run was a 4-core cloud container shared by
five agents. This Mac runs the layer chain in about 1.5 min, so the saving
here is about 8x, not 80x. On a loaded machine the gap should widen:
headless the yard steps one motif, and a trial costs about 0.7 s of wall
time against about 3 s in the layer.

## Plan fields the yard sets, and why

`yard_plan` fills every field that `LayerStage`, `LayerGreybox`,
`LayerEnemies.dress`, `LayerBodies.cliffs` and the `LayerHazards` checks
they call read:

- `isles`: the one isle from `LayerPlan._motif_isle`, the generator's own
  call (occupancy, own sockets, motif). It also has `role` "route", `hood`
  0, `offset` (`--at=`, default the origin) and world `sockets`
  (`LayerPlan._world`).
- `edges`, `gulfs`, `tubes`, `arrows`: `[]`. Without them there are no
  stones, bridges, Voussoirs, rides or piers. They are also what
  `_lumps_clear` reads when a head's cliffs are found.
- `exit`, `prize`, `cannon`, `ram`: `{}`. That means no gate (`at_exit` is
  false), no runes, no generator cannon and no Plinth Ram. A motif's own
  cannons still come through its `live`.
- `heads`: from `LayerGreybox.lay_heads`, with the motif's knobs and
  routes. Each head's cliffs come from `LayerBodies.cliffs` over the motif
  alone.
- `knobs`: `LayerPlan.KNOBS` defaults, overridden by `--knob=` and by
  `--bodies=`. `heads`, `arrows` and `viaduct` are 0, so no generator
  heads or hazards are laid. Those belong to the layer, not the motif.
- `spawn`: the motif's `start()`, or its way-in rim for a kit motif,
  facing in off the way-in rim.
- `void_y`: 60 m under the lowest solid. It is the net, and also the body
  spawner's `lost_y` and the study's `lost`.
- `seed` is 1, `shape` is "yard" (so `LayerShapes.dress` would do
  nothing), and `hoods`, `route` and `problems` are filled for the card
  functions.

## Unverified

- **Hand play.** Nothing was played by hand or rendered beyond the stills.
  - All six stills were checked by eye
    (`captures/shots/yard_<slug>_three.png`, `yard_sheet.png`): each motif
    stands whole and in place.
  - The turf reads gold because the session opens in the real date's
    season, autumn.
  - With `--sky`, a drifting puff hid the low Vigil from the camera, so
    its still is without `--sky`.
- **`--rims`** stands its pads at a route stride, 1.7 m across the drop
  (a smoke run passed with it). I didn't drive a walk-on or a walk-off.
- **Bodies taking heads mid-chain** is still unproven: no body came up
  during a trial.
- **Other chains.** I re-ran only the two motifs the brief asked for. The
  Lidstack, Vigil, Noon Weir and Sunken Giant chains have not been run in
  the yard.
- **Kit motifs** (`bell_spires`) were smoke-tested only.

## Tests

None were added and the suite wasn't run. I don't know of any test this
round breaks: no test references the greybox grey flags. The PR #25 note
still stands: tests that assume the classic pool, such as
`test_run_layer` and `test_layer_sprawl`, change with the pool default.

## Harness gaps hit

- **The window lock is per worktree.** `tools/shot.py` locks
  `.godot/harness-window.lock`, so it can't see another worktree's windowed
  runs. I waited them out with a throwaway `scratch/wait_windows.sh`. A
  lock that lives with the user's machine, not the worktree, would do.
- **Two rendered stills hung** on `frame_post_draw` until the watchdog
  timed out at 180 s and 60 s. A retry passed both times, probably because
  macOS stopped drawing a hidden window.
- **The grey flags are listed twice**, in `motif_yard.gd` GREY_FLAGS and
  in `chain.gd`. A `grey_flag()` on `motif_greybox.gd` would make one
  source.
- **Out of scope**, and still wanted, in the brief's order: the motif
  probe, `--compat` stills, a bg.py lock for heavy runs, a placement
  finder (I found sprawl 1 for both motifs by hand with `layer_dump
  --isles`), the shared turf helper, and the stage posing traps.
- The merge left `tools/fixed_cache_check.gd.uid` untracked, an import
  artifact. It isn't committed.
