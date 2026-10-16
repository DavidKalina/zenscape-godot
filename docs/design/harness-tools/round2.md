# Harness tools, round 2: route walks and enemy watches

Two additive helpers in `tools/harness/drive.gd`, plus one in `chain.gd`. The
survey (`scratch/tool-survey.md`, ranks 1 and 2) found them rewritten most often.
They are opt-in. Existing drivers and the existing API behave as before: the
one change to old code is an empty per-frame hook list in `frames()`. No game
code changed. The README table now has their lines and round 1's two
collider-probe lines.

## API

### `route(points, opts) -> Dictionary` and `walk_leg(to, opts) -> Dictionary`

He is set down at the first point, facing the second. Each leg after that is
the stick and the jump button through the real input. A point is a Vector3
(arrive within `near` across and `up` in height), a Vector2 (x, z, any height)
or `{to, ...leg opts}`.

```gdscript
var r := await route([study.start, Vector2(76, 0), {"to": Vector2(60, -12), "jump": "long"}], {"name": "hill"})
check(r.ok, "up the hill", r.why)
```
```
[f412] LEG hill 1/2 ok 3.4 s to (76.0, 0.0) at (76.1, 34.5, 0.2) jumps 1 drops [1.2] stuns 0 knocks 0 set back 0 stuck 0
[f655] ROUTE hill FAIL 1/2 legs in 10.9 s at (60.3, 30.0, 4.1) drops [1.2] stuns 0 knocks 0 set back 0 (leg 2: stuck)
```

- Leg opts: `near` (0.7), `up` (2 pumps), `most` (1500 frames), `pace` (1 run, 0.5 walk), and `jump`:
  - `auto`: at a lip unless the point is below him, and at a wall he can catch;
  - `lip`: at every lip;
  - `long`: a crouch then a long jump at lips;
  - `drop`: walk off lips;
  - `none`.
- Route opts: `name`, `place` (true), `go_on` (false), `rows` (a ROW per leg for sweep.py).
- Grounded and stuck for 40 frames, he jumps (`stuck`). Hanging, he pushes in and jumps now and then.
- A leg returns `{ok, why ("", "set back", "stuck", "timeout", "halted"), s, frames, to, feet, left, jumps, drops, stuns, knocks, set_back, stuck}`.
  - `drops` are metres below the ground he left, each over a hop (`motor.jumps[0]`).
  - `set_back` counts frames where he moved further than he could travel: set back after a fall, gulped, or carried.
- Every size comes from the motor: `jumps`, `hang_drop`, `size`, `run`, `PilotMotor.STEP_UP` and `GRAB_LOW`. Wall reach is `jumps[1] + hang_drop + GRAB_LOW`, the same form as RuinKit's `CHAIN_TOP`.

`walk_leg` is named that, and not `leg`, because 4 old scratch drivers define
their own `leg()`. A same-named override with another signature does not parse.

### `walk_paths(owner, offset, opts) -> Dictionary` and chain.gd `walk_motif_paths(opts)`

```gdscript
var all := await walk_paths(load("res://studies/aqueduct_isle_art.gd"))   # a script or an object
var all := await walk_motif_paths()                                        # chain.gd: the motif, moved into the world
```

The contract is optional and minimal. `static func walks() -> Dictionary`
maps a name to an Array of points (as `route` takes them, in the owner's own
frame). Without `walks()`, it walks the owner's worn `paths()` (Arrays of
Vector2), which most motifs and the aqueduct isle already have. `paths()` was
already taken by the worn dirt polylines, which is why the named-route
contract is `walks()`. No motif defines `walks()` yet. `opts.only` picks one
name.

### `watch(enemy, opts) -> Dictionary`

```gdscript
var w := await watch(bird, {"pilot": "dodge", "dodge_on": ["stoop"], "frames": 240, "fields": ["dives"]})
```
```
[f372] bird state fold->stoop, dives 0->1 d 4.7 dy 4.7 at (45.3, 49.6, -113.6) | exposure 0.89 hunger 3.00 strikes 0 ... | him (42.6, 44.9, -109.7) still knocks 0
[f391] bird state stoop->carry, strikes 0->1, last_strike ""->snatch d 0.5 dy 1.1 ... | him (..) air tumble STUN knock knocks 1
[f576] WATCH bird 240 frames, 4 changes, closest 0.0 m, states { "fold": 35, "stoop": 19, "carry": 91, ... }, knocks 2 stuns 1 set back 0
```

- `enemy` is a Node, or a pattern for `first()`.
- Fields are looked up by duck typing. `WATCH_FIELDS` (state, act, stage, mode, awareness, aware, alert, hunting, seen, exposure, hunger, gap_to_him, strikes, hits, snaps, blows, misses, catches, spots, last_strike) is read wherever the enemy has the field or a no-arg method by that name.
  - `fields` adds more, as names or `{name: Callable(enemy)}`.
  - `only: true` drops the defaults.
  - Position is `at: Callable`, else `head()` if it returns a Vector3 (the Linger), else `global_position`.
- It prints a line every `every` frames (30; 0 means changes only), and a line at once whenever a String, bool or int field changes.
- `pilot` is one of:
  - `stand`;
  - `toward`;
  - `flee`: of 16 ways, the one with ground that ends furthest away, re-picked every 15 frames;
  - `dodge`: across its line, to the side with ground, on `dodge_on` states, or within `dodge_at` (half a second of his run);
  - an Array of route points;
  - a `Callable(enemy)` that steers him each frame.

  The default is `--pilot=`, else `stand`.
- Other opts:
  - `until: Callable` stops it;
  - `pilot_at` and `enemy_at` set start positions (defaults `--pilot-at=x,y,z` and `--enemy-at=x,y,z`), and the enemy's `home` moves with it;
  - `wake` is a method to call at the start;
  - `label` names the enemy in its lines.
- A study's `place()` can make its enemies again (enemy_yard, weeper_yard). Watch then finds the new one by script and says so. Its lambda keeps the node in a Dictionary, so a freed capture is never called.
- It returns `{frames, changes, closest, states {value: frames}, knocks, stuns, set_back, hearts_lost (-1 with no run), last, route}`.

## Proven (headless, through the real loop; drivers left in `scratch/`, uncommitted)

| Driver | Where | Result |
|---|---|---|
| `route_aqueduct.gd` | aqueduct isle, `way_up()` (37 legs, the ramp, ledge and stair) | 37/37 in 20.5 s |
| `route_aqueduct.gd --which=worn` | aqueduct isle, `walk_paths(Art)`, 3 worn paths | 3/3 |
| `route_walks.gd` + `walks_demo.gd` | aqueduct isle, the `walks()` contract, a Dictionary point with `pace` | 2/2 |
| `route_edge.gd` | aqueduct isle, walked off the edge | the leg fails with `set back` |
| `route_rootbound.gd` | motif yard, rootbound_cut (turf), the "top" route with 4 long jumps | 20/20 in 34.3 s (the original driver takes 33.5 s) |
| `route_motif_paths.gd` | motif yard, plumb_well, `walk_motif_paths()` | 3/3 |
| `watch_guacharo.gd --case=stand\|dodge\|leap` | flyer yard, guacharo | snatch / miss / buffet, as `flyer_yard_check.gd`'s cases |
| `watch_weeper.gd [--pilot=flee\|dodge] [--pilot-at= --enemy-at=]` | weeper yard, weeper | stand: a blow after 5 snaps; flee: never reached (closest 5.4 m); the flags move both |
| `watch_reset.gd` | weeper yard, the yard re-makes its enemies mid-watch | goes on with the new one |
| `watch_overseer.gd` | motif yard, rootbound_cut, headless body, pilot = the worn road | its suck and gulp knock him and set him back on leg 4 |

Smoke: a headless import, then `tools/smoke.py` on aqueduct_isle, motif_yard,
flyer_yard and weeper_yard: 4/4 PASS. `examples/plumb_well_chain.gd` gives 3/3
as before. Every main-checkout scratch driver that extends the harness parses,
except `crag_walk.gd` and `olmec_isle.gd`. Those two fail on functions that
are already missing from `colonnade_spine_isle_art.gd`, which this round did
not touch.

## Before and after

| Survey script | Lines | Re-made with the helpers | Lines |
|---|---|---|---|
| `rootbound_cut_routes.gd` (the walk machinery `ray_down` + `leg` + `run_route` alone: 114) | 174 | `route_rootbound.gd`, the top route | 13 |
| `flyer_yard_check.gd` | 85 | `watch_guacharo.gd`, all 3 cases | 23 |
| `weeper_run_check.gd` (run layer; its trace loop) | 124 | `watch_weeper.gd` (the weeper yard, stand/flee/dodge) | 15 |

## Tuning notes (from matching the rootbound original)

- The lip probe is 0.3 m x size. At 0.45 m he took off early, struck the far face under its lip and slid into the pit.
- The long-jump probe is 0.6 m. At 0.7 m the crouch at the rounded rim became a slide.
- The wall probe is 0.5 m. At 0.3 m it sat inside his own radius and never saw a wall.

## Not done / gaps

- No motif defines `walks()` yet. The worn `paths()` are walkable today, but they are dirt lines, not routes. The rootbound worn road runs through the overseer.
- `watch` has no ROW output. Add `row(w)` in a driver. A `sweep.py --arg mode=a,b` axis (survey rank 15) would let one driver sweep pilot modes.
- `hearts_lost` only reads a run (`run_loop.run.hearts_of`). The yards have no hearts, so `knocks` stands in.

## Tests

No existing test breaks: no test uses `tools/harness/`, and no game code
changed. The full suite was not run. No tests were added.
