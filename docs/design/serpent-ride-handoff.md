# Serpent ride handoff

Branch `study/serpent-ride`, from `look/rune-serpent` (3a7c929d). Not merged
and not pushed.

The user played the rune serpent (`docs/scenic/rune-serpent.md`) and asked
for a greybox scene where the pilot runs about on top of it. This round
builds that scene: the real serpent, with its look, flies a loop of open
sky over greybox, and the game's own pilot (the character study's motor,
figure, camera and panels) rides on its back.

## Launch

    ./run-serpent-ride.command
    godot --path . res://studies/serpent_ride.tscn -- --no-title

It is also in the title's Scenes picker, under On-foot greyboxes, as
"Serpent ride".

You start on the start tower. The serpent comes from your right: its head
passes in about five seconds and its middle in about eight. Run at it and
jump onto its back as it goes by.

### Keys

- WASD/stick run, Space/A jump, Shift/C/LT crouch, X twirl, mouse/right
  stick look: all as in the character study.
- **1** puts you on its neck just behind the collar, **2** mid-back, **3** near
  the tail, and **4** on the start tower with it coming (time the jump).
- **R** is back to the start: the tower, with the serpent set to come by again.
- **F1** shows the numbers: what you're on (its back with your place on it,
  the air with how far you've dropped, or the tower), your speed over the
  ground, your speed on its back, its speed, state, the slope under you,
  the surf, falls, and the girth, roll share, bank and its mode.
- **F2** shows the feel sliders. They're the character study's, unchanged.
- F5 to F8 (recordings) are off here. A replay can't put the serpent back
  where it was.

### Flags (after `--`)

| Flag | Default | What it does |
|---|---|---|
| `--girth=<x>` | 1.5 | Its girth times x (head too). 0.5 to 3. |
| `--ride-roll=<x>` | 0.4 | The share of its roll into turns it keeps while ridden. 1 is all of it. |
| `--serpent-speed=<x>` | 1 | Its pace times x (the serpent's own flag). |
| `--weave=<x>` | 1 | Its slither times x (the route's weave shares). |
| `--no-glance` | off | It never glances back at you. |

## Where

- `studies/serpent_ride.gd` and `.tscn` hold the scene. It **extends**
  `studies/character_study.gd`, so the pilot setup is the study's own: the
  motor, figure, steps, puffs, physics bridge, walker camera, pad, F1 and F2
  panels, and R. It overrides `_build_light` (camera far), `_build_room`
  (the sky greybox and the serpent), `tick` (around the study's own),
  `respawn`, `go_to`, `_show_hud`, `_hint_text` and `_unhandled_input`.
- `studies/serpent_back.gd` turns the serpent's body into ground and holds
  its body frame. It's a helper for this scene.
- `tests/test_serpent_ride.gd` is the headless test.
- `tools/capture_serpent_ride.gd` takes rendered stills (it opens a window).

## How riding works

### Ground: its skin as convex hulls, rebuilt every frame

Every ring of the serpent is posed as a bone (`ring_frame`). Its skin
between two rings is the quads between their octagons (`ring_corners`).
`serpent_back.gd` makes one `ConvexPolygonShape3D` per pair of rings: 16
points, the two octagons as posed. The head's five sections are done the
same way, as rings on the head's frame, with the collar between the head's
back and the first ring. That gives 52 hulls on one `StaticBody3D` on layer
1, the bridge's layer. Their points are set again every frame after the
serpent moves.

- **Why hulls and not answering the ground from the rings by hand.** The
  physics bridge (`scripts/pilot_physics_ground.gd`) already answers the
  motor's ground, slide, walls, ledges and ceiling, and the camera's ball
  cast, against colliders. With hulls, all of that holds on the serpent
  unchanged:
  - its back (and head) is ground;
  - its vertical flanks are walls, to slide down and kick off;
  - its shoulders' outer edges are lips, to hang from;
  - the camera stays out of it;
  - the tower, pillars and arch are in the same space.
- **Jolt takes a hull's new points at once.** I checked this with a probe
  before building on it. New hull points, and a `CollisionShape3D`'s new
  transform, are seen by a ray in the same frame. A `StaticBody3D` moved by
  its node `position` isn't seen until the next frame. So the hulls are
  re-pointed, never moved.
- **The hulls are sharp (`margin` 0).** Jolt's default 4 cm convex radius
  would round every hull's end and dip the back 4 cm at each ring.
- **Cost.** About 0.6 ms a frame for the 52 hulls. A whole headless frame of
  the ride (serpent, hulls, carry, motor) is about 1 ms.

### Carry: a place on the body, carried exactly

The serpent's body never slides sideways: every ring keeps its arc behind
the snout and travels along the head's own trail. So a place on the body,
in the body's own terms, is the frame at that arc.

- **Where he is.** While he stands on it (or hangs from it), he is held as
  a place on the body (`SerpentBack.locate`): arc back from the snout, across
  and up. The across and up are in the frame blended between the two rings
  either side, exactly as the skin's corners are blended between them.
- **The carry each frame.** In `tick`:
  1. The serpent advances.
  2. The hulls are rebuilt.
  3. The body's move at his place since last frame (`moved`: frame now
     times frame then, inverted) is applied to everything the motor keeps.
     That is done by a new motor hook, `PilotMotor.carry(by, turn)`: his
     feet, a lip and his hang under it are moved; his facing, pace, a lip's
     and a wall's way off and the slope's fall are turned about up by the
     body's turn there.
  4. Then the study's own frame runs: the motor steps as ever on its back
     as it is now, then the figure, puffs, camera and HUD.
  5. After the step, his place on the body is read again from where the
     motor put him.
- **Why this and not moving colliders with a velocity the motor reads.**
  The motor has no notion of a platform's velocity. A velocity read from a
  collider would also only match the collider's real motion to first order,
  and on an S-curve that turns and banks the mismatch shows as drift and
  jitter. Carried as a place on the body, he goes exactly where that place
  went, by construction. The motor then steps on ground that is, for that
  step, standing still under him.
- **Measured.** Stood still mid-back for a whole lap (2441 m, 12193 frames),
  he drifts 1.4 mm along and 5.9 mm across. His place moves at most
  0.41 mm in a frame, and his feet are always on its skin (0.0000 m off).
- **The motor hook.** `PilotMotor.carry` is only called by this scene, so
  every other scene is unchanged. No feel numbers changed.

### Air: the frame he left in

On leaving its back (a jump, a slide jump, running or falling off the
edge), the frame he left in is his feet's carry velocity that frame:
`air_v`, the serpent's velocity at that place, vertical included. In the
air, each frame:

- he is moved by `air_v`. The flat part is slid round what stands in the
  way (the bridge's `slide`), so he can't fly through a pillar.
- the motor's own velocity stays relative to that frame, so air steering,
  the twirl, the long jump and the rest feel as ever.

So a jump straight up comes down about where it left from, while the body
turns or banks under him. That's the skill the user asked for. Measured at
eight places round the way, a straight-up jump lands at most 0.43 m off
across.

**Landing** on its back takes up its motion at once, with his own pace
relative to it kept, as a platformer's moving ground does. This includes
jumping on from the still tower. I chose this over a physical landing,
which would slam him down at 12 m/s relative. That would be one to try.

### Camera: carried, swaying, never inside it

It is the walker's camera from the study. Each frame, its follow point and
spring are carried with him (moved with his feet and turned about him by
the body's turn). The turn is then owed to its yaw and taken up over
`CAM_TURN` (0.6 s): a boat's sway, not a snap.

- The sky, floor, pillars, arch and the small grey markers hung along the
  way stream past at its speed, so the speed reads.
- It stays out of the body through the study's own ball cast, which now
  meets the hulls.
- Measured standing a lap: it turns at most 0.0068 rad in a frame, its
  place round him moves at most 0.037 m in a frame, and it is inside the
  body in 0 frames.

### Falling off

More than `LOST_DROP` (14 m) under the frame he left in, he is lost:

1. The view fades to the sky's horizon colour (0.35 s out, a 0.2 s beat,
   0.5 s in).
2. Mid-beat he is set back on its back, on its spine at the arc where he
   last stood (clamped between the neck and the tail keys). If he never got
   on, he goes back to the tower and the serpent comes by again.
3. F1 counts the falls.

Walking off its side to set back took 2.77 s in the test. It's never death.

### The serpent while ridden

- **Eased roll.** While he's on it (and for 3 s after he leaves),
  `bank_share` = `--ride-roll`.
- **Glances back.** `look_back` is on. About every 21 s it turns its head
  1.06 rad back over its shoulder (the side he's on), for up to 5 s. Its jaw
  cracks and its tongue flicks as it notices him. Measured from the neck,
  he stays on through it.

## Defaults chosen, and why

- **Girth 1.5×.** That makes it 6 m through, with a flat top 1.95 m across
  and 5.5 m between its shoulders' outer edges. The shoulders are 40°
  slopes he can stand and run along. At 1× those are 1.3 and 3.7 m; at 2×,
  2.6 and 7.3 m.
  - A scripted bot played on its back for 4 minutes per setting, steering
    with a 0.2 s delay and mixing runs, jumps, long jumps and twirls. It fell
    3.0 times a minute at 1×, 2.5 at 1.5× and 2.25 at 2×.
  - Wide shots: 1× reads as a slender snake, 2× as a road. 1.5× keeps it a
    snake with room to play.
  - If playing it says it's still too narrow, try `--girth=2` first.
- **Roll kept 0.4 while ridden.** Its back's flat top then tilts at most
  about 9° round the loop; with all of it, about 20°, which is near the
  motor's SLOPE_SLOW (22°), where running up it slows. The banks still show.
  The bot didn't tell them apart (2.5 against 2.25 falls a minute), so this
  is a judgement call for a runnable back. `--ride-roll=1` is the
  unchanged serpent.
- **Speed 1×** (cruise 12 m/s, about 14 in the dive and 10.6 on the climb),
  as the user knows it. `--serpent-speed=` changes it.
- **Weave 1×.** The slither is its character, so I kept it. It has a cost:
  - **The cost.** The waves stand still in the sky and the body slides
    through them. So in the air he flies straight along the tangent while
    the back he left curves away under him. At the weave's tightest
    (radius about 33 m), a long jump along the back (about 12 m of flight
    over the ground) comes down up to about 2 m off the spine. Running
    along it also needs steering through the bends, as on any curvy path.
    A bot holding "forward" on the camera ran 40 m on average before
    running off, much the same at every girth.
  - **The trade.** `--weave=0.6` cut the bot's falls from 2.5 to 2.0 a
    minute at 1.5×, and from 2.25 to 1.5 at 2×.

## The way (RIDE_ROUTE)

A closed cubic B-spline through 38 control points, 2441 m round, about
three and a half minutes a lap. The marks are the key places on it.

| Mark | m | What |
|---|---|---|
| `tower` | 104 | North up the east leg, level past the start tower (weave held in to 0.1). |
| `dive` | 253 | A 25° dive (five control points in a line: two straight stretches). The path pitches −30° to +27° with the heave. |
| `bottom` | 447 | Bottoms out about 50 m over the floor. |
| `climb` | 540 | A 22° climb back to 140 m. |
| `north` | 1001 | A long gentle curve west, about 150 m round, banking into it. |
| `pillars` | 1343 | South down the west leg: a slalom round five pillars, the path 12 to 18 m off each pillar's centre at the bends. |
| `arch` | 1873 | Straight through an arch whose lintel is 9 m over its back (so the camera passes under too). |
| `south` | 2219 | A long gentle curve east, and home past the tower. |

### Surroundings (all greybox)

- **Floor.** A grid at y 0, using the character study's shader with a new
  `cell` uniform: a line every 10 m, a stronger one every 50.
- **Pillars.** Five, 5 m wide and 215 m tall.
- **Arch.** Two posts and a lintel.
- **Tower.** An 8 m tower beside its way at the tower mark. Its top is a
  lip (orange) 1.2 m over its back's crest, 1.2 m off its flank plus the
  weave.
- **Markers.** About 100 small grey cubes hung 16 to 34 m off its way,
  either side in turn.

## Tests

`tests/test_serpent_ride.gd` runs headless in about 15 s, with scripted
input. Every check passes. It checks that:

- the real serpent flies the ride's way, and he starts on the tower;
- **stood still a lap,** mid-back: on it every frame, drifting 1.4 mm along
  and 5.9 mm across; at most 0.41 mm moved on it in a frame; feet on its
  skin. The camera turns at most 0.0068 rad and shifts at most 0.037 m a
  frame, and is never inside its body;
- **run neck to tail and back:** on it all 24.6 s, never more than 0.34 m
  off the spine;
- **straight-up jumps** at eight places (tower, dive, bottom, climb, the
  north curve, the pillars, the arch, the south curve): down on it every
  time, at most 0.43 m off;
- **walked off its side:** he falls, it fades, the fall is counted, and he
  is set back on its spine, 2.77 s from the step off;
- **surfing the dive:** crouched mid-back on the dive's straight (20° there
  that moment), his pace on its back goes 2.4, 4.5, 6.5, 8.6 m/s at 0.5 s
  steps, surfing every frame;
- **boarding from the tower:** a held running jump from the edge as its
  middle goes by lands him on it;
- F1 shows the ride's numbers.

As asked, I also ran:

- the import check;
- the load check (`--headless ... res://studies/serpent_ride.tscn
  --quit-after 300`), which is clean;
- `tests/test_rune_serpent.gd`, since I changed `rune_serpent.gd`. All 22
  checks pass.

I didn't run the full suite. That includes `test_scene_picker`, which
loads every catalogue entry, and the character study's tests, which share
the small `_hint_text` refactor. Nothing was added to known_failures.
At exit the ride test prints Godot's "5 ObjectDB instances were leaked"
warning (not a failure; I didn't chase it).

## What changed outside the scene

Every change below leaves its defaults as they were.

- **`scripts/rune_serpent.gd`.**
  - Settable before `setup`: `route`, `route_marks`, `start_mark`, `girth`
    (scales RADIUS through: rings, head, capsules, reach) and `solid`
    (capsules on or off).
  - Live while ridden: `bank_share` (times its bank goal) and `look_back`
    (a watcher behind it is glanced at over its shoulder for GLANCE 5 s,
    instead of looked away from).
  - New probes: `ring_frame(k)` and `ring_corners(k)`, `head_frame()` and
    `head_corners(i)`. The mesh build now uses `ring_corners` and
    `head_corners`, so the shapes live in one place.
- **`scripts/pilot_motor.gd`.** The `carry(by, turn)` hook. Nothing else
  calls it.
- **`studies/character_study.gd`.** The bottom help line is now
  `_hint_text()`, the same string.
- **`shaders/character_study_grid.gdshader`.** A `cell` uniform, default
  1 m.
- **`scripts/scene_catalog.gd`.** The new entry.
- **`run-serpent-ride.command`.** New, modeled on the character study's
  launcher.

## Try first

1. Launch it, jump onto its back from the tower as its middle goes by
   (hold Jump for a full jump), and stay on through the dive.
2. In the dive, crouch: surf down its back toward its head. On the climb,
   surf back toward its tail.
3. Press 2 in the slalom or on a curve and jump straight up: feel it turn
   under you. Then long-jump along its back and steer back onto it in the
   air.
4. Press 1 and wait on its neck for a glance back.
5. Compare `--girth=2`, `--weave=0.6` and `--ride-roll=1`.

## Unverified

- **Nothing was played by hand.** Real input, real feel and real
  frame-rate hitches are all unchecked. Scripted input and a few stills
  are all I could check:
  - whether the camera's 0.6 s take-up of its turn feels like a boat or a
    lag;
  - whether running along the S-curve is fun or fiddly;
  - whether the tower's timing is right;
  - whether the sticky landing feels right;
  - whether the 14 m fall before the fade is too long or too short.
- **The stills are few, from scripted runs.** They show the rider on its
  crest, the surf in the dive, the glance, the tower start and a wide shot.
  The look of the motion (the sway, the markers streaming past) is unseen.

## Known issues

- **Jumps along a bend can miss.** See "Weave 1×" above. It's the physics
  the user asked for, but long jumps and twirled jumps along the back are
  punishing where it bends most. Air steering can save about 1 m.
- **The low shoulder in a bank.** Above about 4° of roll, its low
  shoulder (40° unbanked) passes the motor's SLIDE_AUTO (44°), and he surfs
  off it if he stands there.
- **The tail narrows.** Its flat top is 1.2 m across at 70 m from the
  snout (key 3), 0.8 m at 76 m and 0.2 m at 85 m (worked out from its
  profile, not measured in play).
- **Standing on its head is wild.** It's ground, but it moves with every
  look and lean. The jaw isn't in its hull: the head's hull is all on the
  head's bone, so the jaw's brief 0.2 rad crack pokes out of it.
- **Running off the snout** drops him in front of it (and he is set back).
- **It reads paler than in the aqueduct isle.** It uses the same shader,
  but under the character study's bright sky and ambient light.
- **Recording and replay are off** (F5 to F8).
- **Its own capsules are left out here** (`solid = false`). The hulls stand
  in for them.
- **No sound beyond the pilot's own steps.** No art pass on the greybox.

## Next ideas

1. **Gravity toward its spine.** Run round its sides and underneath it. The
   carry already holds him as a place on the body (arc, across, up). A
   motor whose "up" is the body's local up at his place, with the ground
   answered along that up from the hulls, would let him circle it. This
   wants a motor that takes a gravity direction, which is a bigger change
   than this round's hook.
2. **Rune bands as real handholds.** Raise the bands a few centimetres so
   the bridge finds lips along its flanks, to climb its sides hand over
   hand as it flies.
3. **Landing physics as an option.** Land with the world velocity
   difference and skid it off with the motor's carry rules, so a jump on
   from the tower is a slam you ride out.
4. **Its speed in the camera.** Pull back or widen the FOV a little with
   the speed over the ground. Speed lines or wind ribbons past the rider.
5. **More to ride round.** Set pieces it threads with a rider on it: low
   arches you must duck (crouch) under, ring gates to jump through as it
   passes, a second serpent to leap across to, and a tail flick that
   launches you.
6. **The weave while ridden.** Like the roll, it could ease its weave a
   little while ridden (a `weave_share` goal).
