# Olmec body, turn and clipping, round 1

The user: "His swivel animation where he turns his body is really bad. Just
needs to read better. Also, he still clips into stuff."

Branch `feature/olmec-turn-clip` (off `roguelike`), two commits:

- `ec0dced2`: the turn.
- `12462886`: the clipping.

It isn't merged or pushed.

## The turn

### What it was

Round 4's stepping turns (`scripts/enemies/headless_body_steps.gd`) worked
like this:

- The body's `facing` turned at its state's rate. In the chase that's
  `turn` × `chase_turn` = 1.62 rad/s.
- The figure stepped after it. Each step was sized from a smoothed turn rate
  that starts near 0, so the steps were small: about 0.45 rad (26°) each.
- In a 180° chase turn the figure fell 66° behind the facing.
- The chase strides off once the facing is within 0.8 rad of its goal. At
  that point the steps were cancelled and the figure swung the remaining
  110° or so at lerp 8/s while sliding forward. That was the "swivel".
- The `turn_*` clips were also small for a 10 m stone giant:
  - the foot lifted 0.42 m;
  - the weight shifted 0.28 m;
  - the arms were filtered out of the blend, so they hung still.

### What it is now

- **Planned whole.** A stood turn is planned toward where he is going (the
  route or chase heading, where he glimpsed you, the way he heard), not
  chased step by step behind a facing that runs ahead.
  - Under 20° (`SMALL` 0.35 rad) it's a correction: the hips ease round at
    0.5 rad/s on pivoting feet, with no step.
  - Over that, he takes as few equal steps as cover the turn, at most 66°
    each (`BIG`). 180° is three steps; 90° is two.
- **The beats:**
  - The first step has a 0.22 s lead-in (`ANTIC`). The weight goes over
    onto the standing leg and he sinks. The shoulders wind 0.16 rad against
    the turn, and the figure turns back 10% of the step.
  - The step itself: the foot comes up 0.8 m, knee forward, and the hips
    swing in.
  - The foot plants flat into a deep held squash (0.905). The shoulders,
    stump and arms swing on past.
  - The last step holds a 0.3 s settle. The steps in between chain with
    0.03 s between them.
- **Stood, his facing is his feet's.** His sight cone and walker box turn
  with his feet. The chase and route turns plant first (they no longer swing
  round at speed) and stride off only once the steps are done. Hunting, the
  steps run 1.3× faster.
- **Timing (hunting):**

  | Turn | Before | Now |
  |---|---|---|
  | 180° | moving at 1.5 s, still swivelling the rest | three steps, striding at 1.9 s |
  | 90° | | two steps, striding at 1.4 s |

  Calm (listen) turns go at pace 1.
- **The clips.** `turn_open_l/r` and `turn_close_l/r` were re-authored in
  `art/blender/headless_body/headless_body_build.py` (`_step_keys`) and
  baked into `assets/models/headless_body.glb` with `bake_clips.py`. Only
  those four clips changed; the mesh and the other clips are unchanged. The
  upper arms and forearms now blend in with the turn; the hands keep the
  clip under them.
- **The seek's look-about** no longer plays the walk clip on the spot. His
  feet step him round instead.

### Captures

They're in `docs/design/roguelike/olmec-turn-clip/` (the PNGs are
gitignored, as in earlier rounds).

Before (roguelike):
- `before_whole_chase180_three_sheet.png`
- `before_whole_chase180_side_sheet.png`
- `before_headless_listen180_side_sheet.png`
- `before_headless_listen180_three_sheet.png`

After:
- `final_whole_chase180_three_sheet.png`
- `final_whole_chase90_side_sheet.png`
- `final_headless_listen180_three_sheet.png`
- `final_headless_listen25_front_sheet.png` (a small turn: one step)
- `after_*_side_sheet.png`
- `a2_detail.png`: the key poses large (wind-up lean, knee up, squash
  plant, arms swinging)

The before strips show him standing almost still, then swinging round as he
walks off. The after strips read as lean, step, plant, step, settle, then
go.

## The clipping

### How it was measured

The throwaway drivers are in `scratch/` (uncommitted):

- `scratch/pen.gd` skins every 9th vertex (about 4,950) each sample.
- **Wall depth:** it casts a ray from the body's upright axis out to each
  vertex. A face met short of the vertex counts as penetration. A reverse
  ray drops vertices that are past a corner the ray cut, not inside it.
- **Floor depth:** for low vertices, a ray straight down.
- **Drivers**, all through the real loop at fixed 60 fps:
  - `chase_pen.gd`: the whole-body chase study, with you running a fixed
    path round the cover, ramps and ledges by real input.
  - `isle_route.gd`: the headless isle study's whole way to its head.
  - `layer_pen.gd`: the generator, with every isle stood. A body is stood by
    each head (the spawner's cliff fit failed on every cliff here; see
    below). They're left to their routes for 150 s, then one is made whole
    beside you and hunts for 45 s.

The figures are samples where the deepest vertex was past a face by more
than the threshold. Runs vary (the route search is wall-clock budgeted, and
the bodies' choices differ), so compare rates, not exact counts.

| Run | Samples | > 25 cm | > 1 m | Deepest | Feet in floor > 25 cm (deepest) | Bodies overlapping |
|---|---|---|---|---|---|---|
| Chase study, before | 4066 | 299 | 251 | 4.53 m | 447 (1.41 m) | n/a |
| Chase study, after | 4066 | 191 | 96 | 1.69 m | 151 (1.13 m) | n/a |
| Headless isle, before (whole at 110 s) | 1080 | 382 | 206 | 3.46 m | | |
| Headless isle, after (whole at 113.5 s) | 1114 | 115 | 3 | 2.26 m | | |
| Generator sprawl 2, before | 3500 | 185 | 68 | 6.09 m | 473 | not logged |
| Generator sprawl 2, after | 4620 | 26 | 10 | 2.00 m | 67 | 0 |
| Generator ring 1, before | 7665 | 1065 | 328 | 4.63 m | 1368 | 98 |
| Generator ring 1, after | 8135 | 923 | 131 | 2.52 m | 768 | 0 |

### Cases found, and what was done

**Fixed:**

1. **Walking beside a wall or pillar, half of him inside it.** The worst
   case before was 4 m in, at the chase study's pillar: his middle was
   0.3 m off the face. His only wall rays look straight ahead from his
   middle. Fix:
   - A box the size of his bulk (shoulders and hanging arms, ±3.36 m;
     ±1.68 m along; from over a stair's height to his stump, or head when
     whole) turns with him.
   - Each frame it is eased flat out of the world, at most 8 m/s, never off
     his floor. His planted feet go with it.
2. **Corners met slantwise and undersides.** These were a pillar corner at
   his shoulder, and the chase study's ramp he walked under (5.6 m in).
   - Off a route, rays from his shoulder lines and at his chest and head see
     them.
   - A down-facing underside is a wall he won't climb.
3. **Leaping into a wall.** He flew 5.6 m into the long wall. Only his feet
   were swept. Now jumps and pounces sweep his bulk; a wall met stops him
   and he drops.
4. **The pounce wind-up beside a pillar.** He crouched with his arms swept
   back 1.4 m into it. A pounce now needs room for the crouch.
5. **Landing in a shaft he doesn't fit.** On sprawl 2 he dropped into the
   Plumb Well's shaft with his arms 2.5 m in the walls. Now no leap lands
   where his bulk has no room. By a wall is fine; the push-out eases him
   off it.
6. **Hands and arms swinging into a wall beside him.** Each arm's elbow,
   forearm, wrist, fingertips and thumb are ray-checked. A hand past a face
   is drawn back in by IK, easing in fast (0.05 s) and out slowly
   (0.15 s).
7. **Toes in the floor.** In the walk clip they went up to 0.37 m in; the
   new turn's anticipation pitched them 0.24 m in.
   - The foot IK now lifts the ankle until the sole's lowest corner rests
     on the floor under it. It samples under the ankle and the four sole
     corners, so a foot also rests on a low step or a serpent pier beside
     him, up to 1.6 m up.
   - The anticipation's toe-down pitch was cut and the ankle raised with it.
   - On flat ground the worst is now 0.22 m.
8. **Legs through low blocks beside him.** These were the serpent ride's
   piers on sprawl 2 (2.6 m in). A low box (his feet's breadth, under the
   bulk box) eases him sideways off blocks taller than 0.9 m. It only pushes
   sideways, so a stair met head-on is still walked up.
9. **Bodies through each other.** Ring 1 had 98 overlapping samples. Now
   bodies keep apart (1.15 × their breadths, middle to middle).

**Route fixes the clearance needed** (the isle route broke on the way, and
these restored it to whole at 113.5 s, against 110 s before):

- **The planner's headroom** (`scripts/enemies/body_routes.gd`) is now his
  stump's top (`neck_h`), up from 0.92 of it. The old value put his
  shoulder slab into overhangs.
- **On a route the planner is trusted.** The shoulder rays and the upper
  rays are off; the bulk push-out still applies.
- **A walk leg that ends at the foot of the next leg's climb** is done when
  he meets that wall. His bulk, held off the face, may never stand within a
  cell of the leg's end; before, this only worked by marginal timing.
- **After two walk legs refused at a climbable wall he wants up,** he
  climbs it. Before, he only got there by luck through bail-outs.
- **Drops off a rim** don't sweep his bulk. The cliff he steps off is
  behind him. The landing room check still applies.

**Left (measured, not fixed):**

- **Narrow walkways the planner lets him into.** The Plumb Well's walk at
  (296, 110, -170) on sprawl 2 has walls about 3.6 m apart at shoulder
  height. His upper arms are 1.5 to 2 m into them while he stands and turns
  there.
  - The planner's "fits" checks 1.5 m round a place, but his shoulders and
    arms span 3.4 m each way.
  - Widening that test is a planner change (layer round 11's territory). I
    didn't make it.
- **The wall-feel and the climb.** The feel, climb, mantle and hang states
  are outside the push-out by design: their own code places him and his
  hands on the face.
  - Whole, his worn head leans into the long wall during the feel
    (`clip_after_sheet.png`, third still), with the hand 1.4 to 2.3 m in at
    the feel-to-climb hand-over.
  - The Sundered Gorge climbs on ring 1 show forearms 1.6 to 1.7 m in on a
    slanted face.
  - Round 4's notes on these stand.
- **Ring 1 still has 11% of samples over 25 cm.** Most are hanging hands
  and shins against low blocks beside him: serpent piers and the Sunken
  Giant's chest blocks. They're under the bulk box and outside the narrow
  leg box. Widening the leg box to his hands didn't help (it was within run
  noise, slightly worse), so I reverted it.
- **Fast swat arcs and thumbs at pillar corners:** 0.5 to 1 m for a few
  frames.
- **The wanderer inside his hanging hands.** The walker's box is his torso's
  breadth (4.4 m) but his hands hang 4 m out each side. The chase probe saw
  no walker overlap, but it's possible. That's a gameplay box choice, so I
  didn't change it.
- **The suck plant on the chase study's north rim** shows as about 90 deep
  samples. It's mostly a probe artifact: the axis ray starts below the
  floor when he stands on a rim's edge. The still looks fine.

Stills of the worst left cases from the rendered chase run are in
`docs/design/roguelike/olmec-turn-clip/clip_after_sheet.png`. The first
still is blocked by the wall, which is an artifact of the camera placement.

## How to see it

The whole body hunting you (turns, pillars, the ramp, the ledges):

    /Applications/Godot.app/Contents/MacOS/Godot --path . --rendering-method forward_plus --windowed --resolution 1440x900 res://studies/whole_body_chase.tscn -- --no-title

- Step out from behind the long wall so he sees you, then run behind him or
  round a pillar. He should plant, lean over his standing leg, step round in
  two or three heavy steps, settle, and only then come on. He shouldn't
  swing round as he starts walking.
- Run past the pillars and the long wall's ends. His arms should draw in,
  not sink into the stone.
- He no longer walks under the ramp.

The headless body: `run-headless-body.command`, or the same command with
`res://studies/headless_body_isle.tscn`. Watch his listen turns, and him
walking the shelf beside the cliffs.

The generator:

    /Applications/Godot.app/Contents/MacOS/Godot --path . --rendering-method forward_plus --windowed --resolution 1440x900 res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=2

## Checks

- **Import:** a headless import is clean.
- **Smoke:** these each passed 400 frames headless with 0 errors:
  - `whole_body_chase`
  - `headless_body_isle`
  - `whole_body_leap_grab`
  - `run_layer -- --shape=sprawl --seed=2`
- **Tests:** none reference the body. I ran `test_run_layer.gd` alone. It
  prints PASS, but fails on a deferred engine error,
  `GDScript::_cannons: Cannot convert argument 1 from Object to Object`.
  It fails the same way on unchanged `roguelike`, so it's pre-existing, not
  from this round. No full suite was run (prototyping).
- **Unverified:**
  - Interactive play.
  - Frame time. Each body now adds per frame:
    - a box query, plus a low one;
    - up to about 20 short arm rays and 10 foot rays;
    - the room checks only when deciding a leap.

    All of this sits inside the existing far-pose throttle for the arm and
    foot work, but the box queries run on every ground frame.

## Models (`docs/art/model-budget.md`)

No geometry changed: the same mesh, skin and bones. Only the four `turn_*`
clips were re-baked into the glb, so no geometry tricks apply this round and
there are no savings to estimate. Round 3's note stands: the mesh is about
89k triangles, so baking low and import LODs are the big wins if many bodies
are on screen.

## What the harness lacked

- **A mesh-against-world penetration probe** for skinned characters. I wrote
  one in `scratch/pen.gd` (skinned vertex sample, axis rays, a reverse-ray
  inside test, a floor test). It's worth promoting to
  `tools/harness/` if clipping comes up again.
- **Standing every generator isle** for a driver that isn't one motif's
  chain. I copied `chain.gd`'s `hold_layer` loop into `layer_pen.gd`.
- **The spawner's cliff fit in a driver.** In a driven run of sprawl 2,
  `body_spawner.gd`'s cliff fit failed on every cliff ("no face"), so no
  body could be spawned up a cliff. I stood them by their heads instead. I
  didn't look into whether this also happens in play.
