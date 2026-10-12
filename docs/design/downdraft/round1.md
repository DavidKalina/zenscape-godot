# The downdraft, round 1

Superseded by round 2, the slam (docs/design/slam/round2.md): the move
now takes its power from height and spends no charge. This page is the
round-1 record.

The updraft's opposite, in the pilot's own wind. In the air, with crouch
held, spending the flow charge drives a burst of wind straight down
beneath him. He's slammed down, lands heavily and slides out of it. A ring
of wind runs out from where he lands, pushing whatever is round him, and it
blows buried finds out of the turf.

Branch `feature/downdraft` (from `main`). The direction is
docs/game-direction.md ("The downdraft", "The plane's parts", "Ways to
discover things").

## Controls

| | Keys | Pad |
|---|---|---|
| Downdraft | Shift or C held, then Q, in the air | LT held, then RB, in the air |
| Updraft (unchanged) | Q, crouch not held (or on the ground) | RB |

- It shares the updraft's charge and rules. It spends all of the charge,
  with at least `MIN_RELEASE` (0.15) needed. Charging is then locked as it
  is after a forward burst (`SPENT_*`): until he's back to his old pace and
  out of any slide, or 5 s at most. You get one or the other, never a chain.
- Crouch + Q in the air with too little charge does nothing. It never falls
  back to the updraft.
- On the ground, crouch + Q is still the updraft.
- With crouch still held at the touch, he slides at his pace, or surfs on a
  slope.
- Jump pressed just before the touch is buffered and jumps out of it.
  Crouched at a run, that is the long jump.
- A twirl during the slam ends it, with no ring.
- These controls are documented in docs/gamepad.md (Walking) and in the
  foot hint (`studies/kit_isle.gd` `FOOT_HINT`, and the character study's
  key line).

## Feel numbers

Everything is at the top of `scripts/downdraft.gd`. Lengths scale with the
motor's `size`, and paces with `size^PACE_POWER`, so a smaller wanderer
gets a smaller ring.

| What | Value |
|---|---|
| Gather (the hang) | `GATHER` 0.11 s. The fall stops and his flat pace is held at `GATHER_FLAT` 0.45. The view narrows 3° (`FOV_GATHER`). Five strokes spiral in and down onto him |
| Slam pace | `SLAM_PACE` 16 to 30 m/s down, from least charge to full. The fall's top speed is 18 |
| Slam kick | `SLAM_KICK` 0.7 of that pace at once. The motor's `SLAM_PULL` (2x his falling gravity) takes him the rest of the way |
| Flat pace kept | `SLAM_KEEP` 0.94. He isn't steered in the slam |
| View on the way down | Widens 3.5° to 7° (`FOV_SLAM`) |
| Ring radius | `RADIUS` 3.2 to 7.5 m |
| Strength | `STRENGTH` 0.4 to 1.0 |
| Falloff | `FALLOFF` 0.6 of the push is lost at the rim. The ring reaches `REACH_UP` 0.6 of its radius up or down |
| Camera kick | `KICK` 0.34 m drop over `KICK_TIME` 0.42 s (down in the first sixth, then easing back). `SHAKE` 0.07 m dies over 0.45 s |
| Pad | `PULSE` 0.35 weak, 0.75 strong, 0.16 s |
| Sound | Gather: a quiet whoosh at pitch 1.4. Slam: a swish at pitch 0.72. Touch: the kit's thump at pitch about 0.45 (`DOWNDRAFT_WHUMP` 0.75) under a `wind-slam` take (`DOWNDRAFT_WIND` 0.3), all in `scripts/kit_isle/kit_audio.gd` |
| Dust | 7 puff bursts thrown outward by the strength (`character_study.gd` `DOWNDRAFT_DUST`), plus a swirl at the gather |

Measured headless (`tests/test_downdraft.gd`):
- During the hang he falls at no more than 0.65 m/s.
- At full charge the slam reaches 30 m/s.
- From 6 m up at 5 m/s flat, he lands still at 4.7 m/s and goes into a
  crouch slide.
- From 6 m up, the press to the touch should take about 0.35 s. That is
  worked out from the numbers, not measured.

## The push hook

The group is `Downdraft.GROUP` (`&"downdraft"`). At the touch, every node in
the group that has `downdraft(at: Vector3, radius: float, strength: float)`
gets one call. That's `Downdraft.blast(tree, at, radius, strength)`, which
anything may call, for example an enemy's own slam.

Each receiver decides for itself, using these helpers:
- `Downdraft.share(at, radius, point)`: 1 at his feet, 0.4 at the rim, 0
  out of reach.
- `Downdraft.way(at, point)`: out from his feet and down.
- `Downdraft.knock_way(at, radius, strength, point)`: an outward,
  slightly upward velocity for an enemy's `knock`, following the motor's
  `knock(v)` pattern. Its scales are `KNOCK_OUT` 7 m/s and `KNOCK_UP` 3 m/s.

What answers it today:
- **Floating slabs** (`scripts/interactables/foot_slab.gd`, both bobbing and
  drifting): they're kicked down (`WIND_SINK` 2.6 m/s), tipped at the near
  edge (`WIND_TIP`) and shoved aside (`WIND_SHOVE` 1.6 m/s) on a new
  horizontal spring (`shove`), and they come back the way a landing does.
  Counted in `winded`.
- **Swing ropes** (`swing_rope.gd`): `wind_push` along `way`, as the
  updraft's ring pushes them.
- **Bells** (`scripts/kit_isle/motif_bell_spires.gd`): a `BellWind` node in
  the belfry's art hands the blast to the motif's `downdraft`. Every bell
  within the radius plus `BELL_REACH` (2.5 m) of its pivot is swung away
  from the touch, by up to `BELL_DOWNDRAFT` 0.62 (about 36°, against 0.18
  for a landing). This works in the aqueduct isle's sky and in the bell
  spires study.
- **Loose leaves and chaff** (`scripts/wind_leaf_litter.gd`): thrown up and
  out (`DOWNDRAFT_THROW` 5 m/s, `DOWNDRAFT_LIFT` 2.6 m/s per unit of
  weight).
- **The grass and flowers** (`scripts/pilot_wake.gd`): a ring is laid flat
  where he touched. It grows to the radius over 0.3 s, is held 0.45 s,
  then springs back with the wake's own spring. This goes through the
  shaders' existing tread globals. While the ring is down it takes the
  slots, so his own wake isn't drawn for that second or so.
- **Buried finds** and **the jammed cowl** (below).

## Buried finds

The code is `scripts/buried_find.gd` (`BuriedFind`). It is generic: any
node that hovers to be taken can be buried.

```gdscript
var dig := BuriedFind.new()
dig.setup(find, ground_point, objective_id, hover_height)  # ground_point in find's parent's frame
parent.add_child(dig)                                       # as the find's sibling
...
if dig.takeable(): ...                                      # gate the owner's take
dig.revealed.connect(...)                                    # optional
dig.reveal()                                                 # from code, if ever needed
```

- **Buried:**
  - The find waits hidden 0.6 m (`DEPTH`) under the turf.
  - Above it is a low turf hump (`MOUND`) with a faint gold radial shimmer
    that breathes between alpha 0.06 and 0.2 every 3.2 s.
  - The shimmer, not the find, is `Telescope.spottable` with the
    objective's id, so it glints from 25 m and further.
- **Blown open:**
  - It takes a downdraft whose touch is within `REACH` 2.4 m flat (at the
    walker's size, or the ring's radius if that is smaller) and within
    `LEVEL` 1.6 m up or down.
  - The hump and the shimmer go. Twelve clods are thrown out and up and
    fade over 1.1 s.
  - The find comes up out of the ground over `RISE` 0.75 s, overshooting a
    little.
  - Once up it is takeable and glints in its own right.
- **Rune tokens:** `scripts/kit_isle/kit_tokens.gd` takes a spot with
  `"buried": true` and `"ground"` (the turf point). Its `touch` skips the
  token until it is up. A plane part could use the same code in
  `plane_arc.gd` `_lay`, but none does yet.

## The buried rune

| | |
|---|---|
| Objective | `aqueduct_isle/buried`, type `token`, `needs_plane` false |
| Name (placeholder) | "What the Turf Keeps" |
| Where | Off the aqueduct isle's north-edge worn path to the stumps (`Art.PATHS[1]`). It sits 0.6 of the way along that path's middle leg, 3.6 m inland (`aqueduct_isle_tokens.gd` `buried_ground()`, about (85.6, 30, -20.9)). This is flat open turf in the grass, not on the path, and about 9 m in from the edge |
| How | Spot the shimmer while walking the path, or through the telescope. Jump, then crouch + Q over it |

The region's counts move from 63 to 64 objectives (58 tokens), and the
aqueduct isle's Runes row from 7 to 8. `test_ledger.gd` and
`test_plane_arc.gd` are updated for the new data, as round 1 did for the
parts. `test_aqueduct_isle_life.gd` takes the buried token with a real
downdraft (crouch + Q) and checks that it is buried rather than out of a
jump's reach.

## The cowl

Done, kept simple, in `scripts/plane_arc/plane_arc.gd`.

- **Jammed.** The cowl is laid where round 1 put it, 0.3 m under the
  bell's mouth, as `cowl == "jammed"`. `touch` skips it, so reaching it
  takes nothing. `take("cowl")` from code still works, which the
  all-six test uses.
- **Knocked loose.**
  - The arc joins the downdraft group.
  - A blast within the bell's reach of the cowl (`bell_reach(radius)`),
    with at least `COWL_NEED` 0.3 strength, sets it falling. In practice
    that means landing on the belfry floor, or on the belfry's head over
    it.
  - Then, in order:
    - it shakes in the bell's mouth for `COWL_DELAY` 0.28 s, as the bell
      swings into it;
    - it tumbles down onto the belfry floor over `COWL_FALL` 0.55 s, with
      a small hop at the end;
    - it hovers at `PartSpots.cowl_floor()`, which is (-0.45, 0.35) in
      the belfry's frame at the floor plus `HOVER`;
    - a pop says "The bell swings: the cowl drops to the belfry floor";
    - it is taken as ever and stamped in the ledger.
- **Getting there.** The belfry still needs the plane (`--plane-fixed`,
  and `--part-at=cowl` starts on its floor) until the airship ferries
  exist.
- **Not saved.** A cowl that was knocked down but not taken is jammed again
  after a restart.

## Hosting

`studies/character_study.gd` makes the downdraft beside the updraft
(`--no-downdraft` leaves it out, and `--no-updraft` leaves both out). It
hands it to the updraft as `updraft.downdraft`. Each frame:
- `downdraft.update` runs after `updraft.update` and before the motor.
- `events.merge(downdraft.after(events, motor))` runs right after the
  motor's step. It adds `downdraft_gather`, `downdraft_slam` and
  `downdraft` (`{at, radius, strength, p, hit}`), which the dust,
  `kit_audio.body` and anything else can read.
- `downdraft.apply_feel(camera)` runs after the updraft's.

Scripted runs press the key with `script_wind`.

Motor hooks (`scripts/pilot_motor.gd`):
- `slam(pace, kick)` and the move "slam". The air steer, the wall slide,
  the wall run, the ledge grab, the wall kick and opening the sail all
  skip it.
- "slammed" is added to the step's landing.
- One fix in `_arc`: the "held to the fall's top speed" check now allows a
  hair (1e-4) of float error. The velocity is 32-bit, so a slam pace that
  isn't a round number (20.1 m/s, say) read back a hair past the limit,
  and the fall stopped dead in mid-air. The fall's 18 m/s was exact, so
  nothing before this ever hit it.

`scripts/updraft.gd` gains:
- `downdraft`;
- `spend_down(m)`, which spends the charge, lets the wake go drifting down
  and locks charging;
- `downdrafts`, a counter;
- a shared static `draw_strokes(mesh, strokes, min_run)`, the old `_draw`
  loop. Both winds draw with it.

## Checks

- Headless import: exit 0, no errors.
- Load checks, `res://studies/zenscape.tscn --quit-after 300`, all exit 0
  with no script errors:
  - `-- --no-title`: no warnings.
  - `-- --no-title --plane-fixed`: no warnings.
  - `-- --no-title --plane-fixed --part-at=cowl`: printed the known quit
    leak ("5 ObjectDB instances leaked").
- `python3 tools/run_tests.py --tests ...`:
  - These pass: `test_downdraft.gd` (new, about 35 s), `test_plane_arc.gd`,
    `test_ledger.gd`, `test_telescope.gd`, `test_aqueduct_isle_life.gd`,
    `test_pilot_motor.gd`, `test_pilot_wake.gd`,
    `test_foot_interactables.gd` and `test_world_scale_guard.gd`.
  - `test_bell_spires_isle.gd` passes with the known quit-leak engine
    error.
- **There is no updraft test** in `--list`. `tools/probe_updraft.gd` was
  run instead, and its numbers match docs/design/updraft.md: burst
  21.2/19.1/15.8, updraft out of a slide 9.4 m.
- `test_character_recordings.gd` fails on one recording ("Tech. Fun, fluid,
  movement", which strays at its twirl at 28.82 s). It fails the same way
  on `main`, so it isn't this branch's doing.
- The first run of `test_aqueduct_isle_life.gd` had one stray leaf ("1
  off"), checked before any downdraft runs. It passed on the reruns.
- The full suite was not run.

`tests/test_downdraft.gd` covers:
- In the air, Q alone is the updraft. Crouch + Q is the downdraft: all the
  charge is spent and charging locked. On the ground, crouch + Q is the
  updraft.
- The hang, the slam past the fall's top speed, the flat pace kept, the
  ring's radius at full, and the slide out of it.
- The lock: fast airtime builds no charge, and neither wind fires.
- A landing on a bobbing slab sags and shoves it.
- On the belfry floor: the bell is swung hard and wide, the jammed cowl
  can't be taken, and it is knocked onto the floor, taken and stamped.
- The buried rune:
  - it lies on the turf, hidden;
  - its shimmer is spottable, and the token isn't;
  - walking over it and a downdraft 5.4 m off both leave it buried;
  - a downdraft over it blows it open; it rises, hovers, glints, and is
    taken and stamped.

## What's weak

- **Nothing was seen or heard rendered.** These are all unverified: the
  gather spirals, the slam streaks, the ring's strokes, the grass ring
  through the shaders, the dust, the clods, the shimmer's faintness, the
  camera kick and shake, the FOV moves, the whump's mix and the pad pulse.
  The feel numbers are first guesses tuned by reasoning and headless
  measurement, not by hand. They are the first things to play.
- **No pose for the slam.** The figure falls in its usual air pose. A tuck
  with the arms pressing down would sell it.
- **The bells have no voice.** No bell sound exists in the kit, so "ring"
  means a hard swing. The breeze and the plane only swing them too.
- **The grass ring hides his wake** for about 1.5 s, because it uses the
  wake's shader slots rather than a slot of its own.
- **The cowl's fall is timed, not physical.** It falls after a fixed beat
  rather than when the bell's swing reaches it. It isn't saved as knocked
  down.
- **The ring pushes everything at the touch, at once.** Unlike the updraft's
  ring, it doesn't hit things as its rim passes, and it ignores walls: a
  slab behind a pier is pushed too.
- **Taking the buried rune off the path is easy.** Once the shimmer is
  spotted, a hop and crouch + Q opens it, with no platforming asked. It is
  the showcase, not a hard find.
- **The test drives the move by setting the charge.** Building it from
  flow and then spending it in one run isn't exercised.

## Next

- A slam pose, and a bell toll sound.
- Enemies answering `downdraft` with `knock_way`.
- Cracked slabs, crates and sagging lintels that the downdraft shakes
  loose (from the direction).
- A buried plane part, or a buried set of tesserae.
- Saving the cowl as knocked down.
