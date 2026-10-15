# Beacons and light-aware sight, round 1

The engine asks from the underground Olmec city brainstorm
(`brainstorm/round3-olmec-city/README.md`, `kit-k6-light.md`): a lit thing
every Olmec turns to (the great cresset, a beacon tower, Mudge alight on his
spire), and an Olmec sight that knows the dark.

Branch `engine/beacons-light-sight`, off `roguelike` (rebased onto fd84889f, after the walker-only layer and
the underground look merged). It isn't merged
or pushed. Edits are kept to sight, hearing and attention. The route planner
(`body_routes.gd`), collision and layers are untouched.

## The APIs

**`SightLight`** (`scripts/enemies/sight_light.gd`, a `Node3D`) is a light the
Olmec's sight reckons with. It isn't a renderer light. Put one beside a
piece's OmniLight3D.
- `strength` (1.0, on the ambient's scale), `radius` (8 m), `lit` (true).
- `light()`, `douse()`, and the signal `lit_changed(on)`. `lightings` counts
  the times it was lit.
- `light_at(p)` gives `strength` within 0.4 of `radius`, falling straight to
  0 at `radius`.
- It joins the group `sight_lights` while it's in the tree.

**`Beacon`** (`scripts/enemies/beacon.gd`) extends SightLight, so a lit beacon
also lights the ground round it for the sight. It joins the group `beacons`.
- `pull` (1.0) weighs it against other beacons.
- `draw` is how far off it draws an Olmec, in flat metres. At 0 it is
  `radius` x 8.
- `stand` is where an Olmec comes to, in local space. INF means the floor
  under the flame.
- `gather` (3 m) is how near it comes, past its own half length. `dwell`
  (6 s) is how long it looks.
- `Beacon.all_lit(tree)`, `draw_range()`, `stand_at()`.

Any piece adds one where the flame is:

```gdscript
var b := Beacon.new()
b.position = Vector3(0, 4, 0)      # the bowl
b.stand = Vector3(0, -4, 3)        # optional: where he stands to look
bowl.add_child(b)
b.lit = false                      # later: b.light() / b.douse()
```

**`LightLevel`** (`scripts/enemies/light_level.gd`, static) says how lit the
wanderer stands. It sums three things: `ambient` (0 is black, 1 is daylight,
the default), his torch (`torch`, `torch_strength` 0.85), and every lit
SightLight that reaches him.
- `exposure(tree, p)` is 0..1. `glow(tree, p)` is the share from the lights
  alone. `daylight()` is true at ambient 1.
- `refresh(tree)` runs each frame before the sight looks. It takes the
  ambient and torch from, in order:
  1. The flags `--ambient=0.1` and `--torch=1`, if given (on any scene).
     `EnemyField._init` reads them, after putting LightLevel back to
     daylight.
  2. Else the underground look (`scripts/underground/underground.gd`, the
     study's `Underground` child, `--underground=torch|haze`), read
     directly:
     - Ambient comes from its preset: `LOOK_AMBIENT` gives torch 0.1, haze
       0.45.
     - His torch counts as lit while the look's `torch` node shows.
     - Its strength is 0.85 x the look's `torch` knob against the torch
       preset's. Haze's dim torch gives 0.34.
  3. Else daylight.
- To put the torch out (to hide), hide the look's `torch` node, and the
  sight reads him dark at once.

**Body knobs** (`headless_body.gd`):
- `sight_dark_range`, `sight_dark_seen`, `sight_glow` for the sight.
- `sight_walker_only`, default 0:
  - At 0 its sight looks through walker-only stone (`scripts/walker_only.gd`,
    layer 15), as the walker-only round left it.
  - At 1 that stone blocks its sight, so he can hide in a niche it can't
    reach.
  - It only ORs `WalkerOnly.LAYER` back into the sight's ray mask. Routes,
    walls and floors still strip it.
  - Kit pieces that are hiding places want it on. The user decides whether
    it should become the default.
- `beacons` (1 on, 0 off) and `beacon_rest` for beacons.
- `beacon` is the beacon it heeds. `beacon_turns` and `beacon_visits` are
  counters.

## The priorities

A beacon is heard through the head's call channel. It gives the bearing in
`_pick_way` (with a call's lower noise) and the goal in `_plan` (routes go
there as to a head). It also says "climb for it" in `_wants_up`.

Highest first:

- **Whole Olmec:**
  1. Him. That covers chasing and every attack, and also suspicious: alert,
     seek, the periscope.
  2. A lit beacon in its draw.
  3. Roaming, or walking back to its post (`return`).
  - It tests the beacon only while it is not hunting and its sight is
    `unaware`. It spots him at a beacon as it would anywhere, and the hunt
    wins at once.
- **Headless body:**
  1. Its head in sight (`home`, `reach`, `triumph`).
  2. Its head calling, within call hearing (`hear` x CALL_HEAR).
  3. A lit beacon.
  4. Its head heard but not calling.
  5. Wandering.
- With several beacons it takes the most `pull / (1 + d / draw)`. It keeps the
  one it heeds unless another draws 1.25 times harder.
- It turns at once (stops and listens) only from `listen`, `roam` or `return`.
  In a climb, a leap, a windup or the rest, it takes the beacon up at its next
  listen.
- When it gets there, it stands in `listen`, faces the flame and looks for
  `dwell` s. Then it tires of that beacon for `beacon_rest` s and hears afresh.
- Lighting it again makes it news again, because `lightings` changes. A beacon
  doused while it walks there turns it back to listening.
- It can't reach a beacon up a spire. It walks as near as its route gets and
  looks from there, with no bail.

## The numbers

| Knob / const | Value | What it does |
|---|---|---|
| `sight_dark_range` | 0.4 | in the black, its reach (and `near`) is 0.4 of `sight_range`, eased up to all as he is lit |
| `sight_dark_seen` | 0.3 | in the black, the visibility (so the awareness fill) is x0.3, eased up to x1 |
| `sight_glow` | 1.3 | a light's own glow on him (torch, lamp, beacon) makes him up to 1.3x plainer, in the dark only |
| `LightLevel.torch_strength` | 0.85 | his torch alone lifts ambient 0.1 to full |
| `SightLight` FULL / radius | 0.4 / 8 m | full strength out to 3.2 m, gone at 8 m |
| `Beacon.DRAW_K` | 8 | draw = 8 x radius (64 m at the default radius) |
| `gather`, `dwell` | 3 m, 6 s | |
| `beacon_rest` | 40 s | |
| BEACON_POLL, BEACON_KEEP | 0.25 s, 1.25 | |

By day (ambient 1) `exposure` is 1 and `glow` is 0, and the sight takes the
exact old path. The sky game and every study without the flags are
unchanged.

## How it was proved

All checks are throwaway drivers through the real play loop (`scratch/`,
uncommitted). The wanderer moves by the stick, and the bodies think in the
study's own frame.

**Beacon, headless body** (`scratch/beacon_turn.gd`; headless_body_isle with
`--body-start=stand --spawn-knob=natural=0`):
- The setup: a 1.2 m grey box labelled "STAND-IN beacon", 21 m east of the
  body. He walks to it by the stick, it lights (a torch touch stand-in), and
  he walks off.
- `lit_changed` fired once.
- The body turned to face it while he walked off, within 3.3 s of the
  lighting.
- It walked there, routed (from 21 m to 4.3 m), and stood looking 6 s (from
  15.5 s after the lighting).
- Then it tired of the beacon and wandered off.
- Control (`--control`, never lit): no turns, closest 10.4 m.

**Beacon, whole Olmec** (whole_body_chase, `--body-knob=chase=0`): from 33 m
it turned in 3 s and arrived at 20 s (closest 3.5 m), then looked, tired and
roamed.
- With chase on, he was in its sight at the box: it heeded the beacon for
  one poll, went suspicious, then spotted and chased him.
- So the player beat the beacon.

**Light-aware sight** (`scratch/light_sight.gd`):
- The setup: the whole Olmec held still with `walk=0 turn=0`. The wanderer
  walks straight in from 42 m at half stick.

| Light | Suspicious at | Spotted at | Spotted after |
|---|---|---|---|
| day (no flags) | 40.0 m | 37.5 m | 2.4 s |
| `--ambient=0.4` | 26.6 m | 22.6 m | 9.9 s |
| `--ambient=0.1` | 14.6 m | 9.8 m | 16.3 s |
| `--ambient=0.1 --torch=1` | 40.2 m | 37.8 m | 2.2 s |
| `--ambient=0.1`, STAND-IN lamp 22 m out (r 8) | 26.5 m | 24.9 m | 8.7 s |
| `--ambient=0.1`, full-stick run | 13.0 m | 4.3 m | 8.0 s |
| day, full-stick run | 37.8 m | 32.4 m | 2.1 s |

- In shadow it spots him much later than when a light is near.
- With the lamp, it spots him as he steps into its light.

**No change with nothing registered** (`scratch/trace.gd`): the body's state,
position, facing, sight state and awareness, every second for 40 s, hashed.
- Two traces: headless_body_isle, and whole_body_chase with him in view
  (it plants, sucks, chases, scopes).
- Both hashes matched exactly between `roguelike` and this branch.

**LightLevel reads the look** (`scratch/look_light.gd`, motif yard,
`--motif=plumb_well --bodies=0`). Exposure is measured at his chest:

| Look | Ambient | Torch | Torch strength | Exposure | Torch hidden: exposure |
|---|---|---|---|---|---|
| no flag | 1.0 (daylight) | off | – | 1.0 | – |
| `--underground` | 0.1 | lit | 0.85 | 0.95 | 0.1 |
| `--underground=haze` | 0.45 | lit | 0.34 | 0.79 | 0.45 |

**Walker-only sight option** (`light_sight.gd --wall`, by day): a 14 m tall
walker-only wall stands 20 m out on his way. At the default (0) it spotted
him at 37.5 m through the wall. With `--body-knob=sight_walker_only=1` it
never saw him.

**After the rebase** onto fd84889f, every check above was run again with the
same numbers, the no-change trace hashes still matched `roguelike`, and the
smokes passed.

**Smoke:** `tools/smoke.py` passed studies/run_layer.tscn sprawl seed 1 and
ring seed 2 (also with `--underground`), studies/headless_body_isle.tscn and studies/whole_body_chase.tscn,
all with 0 errors.

## The limits

- **No occlusion for lights.** A SightLight lights through walls. Shade
  volumes (kit-k6's `shade`, the hush gallery) aren't built. A shade could be
  a negative SightLight, or a ray per light within reach.
- **Beacons have no line of sight or hearing check.** It's a flat range: a
  lit beacon in its draw is heeded through a wall.
- **The dragon's sight and the inhaler head aren't light-aware.** The head
  doesn't turn to beacons (only the body and the whole Olmec do).
- **LightLevel is static.** The flags are read when each EnemyField is made.
  The look is read live each frame.
- **The look's numbers are a guess.** `LOOK_AMBIENT` (torch 0.1, haze 0.45)
  wasn't tuned by playing. The underground has no whole Olmec with the chase
  on to try it against: the generator's and the yard's bodies are headless.
  So the dark sight was proved by the flags in the chase arena, and the look
  reading separately (below).
- **Not proved in a generated layer.** No piece there makes a beacon yet. In
  the layer, only the no-change smoke was run.
- **Some of the proof isn't through the input path.** The beacon is lit by
  the driver when he reaches the box (no torch-touch mechanic exists). The
  sight check holds the Olmec still through knobs, and sets its facing once
  in the driver.
- **No rendered capture.** There is no new look to judge.

## Existing tests

None break. No test covers `headless_body.gd`, `body_sight.gd` or
`enemy_field.gd` directly. The layer tests (`test_run_layer.gd`,
`test_layer_sprawl.gd`) run the bodies by day with nothing registered, which
the trace shows is bit-identical.

Both layer tests already fail on `roguelike` (checked at e37139ec, before
the rebase), with the same
failures with and without this branch's files. They are walker crossings,
rims and a neighbourhood's rise, nothing about the bodies:
- `test_run_layer.gd`: 4 FAILs.
- `test_layer_sprawl.gd`: 8 FAILs. The one difference is the next layer's
  seed in "Into the void", which isn't fixed between runs.
