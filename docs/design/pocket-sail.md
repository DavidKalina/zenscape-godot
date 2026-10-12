# Pocket sail (rounds 1 and 2)

Branch `study/pocket-sail`, cut from main at 06ec4de5. Not merged, not
pushed.

The pocket sail is a small hand glider in the spirit of Wind Waker's Deku Leaf
and the paraglider in Breath of the Wild. Press Jump again in mid-air and it
pops out overhead. It gives a small kick up, then coasts you down slowly and
rides the wind. It is for saving yourself after something knocks you off an
island. Height is what it spends: thrown high and far enough, you coast back;
too low and you come down short and climb back. It replaces the skydive
canopy and the "A again in the air summons the plane" rule.

## Run it

    ./run-pocket-sail.command
    godot --path . res://studies/pocket_sail_study.tscn -- --no-title

It is also in the title's **Scenes** picker under On-foot greyboxes, as
"Pocket sail". The glider also works in:

- the character study (`./run-character-study.command`), in still air;
- the aqueduct isle and every kit isle (`./run-aqueduct-isle.command`), with
  that scene's breeze and gust fronts (B sends one);
- the old main scene (`studies/cozy_worlds.tscn`), on foot and out of the
  plane.

Rendered stills of the study: `Godot --windowed --path . --resolution
1280x720 -s res://tools/capture_pocket_sail.gd -- --no-title
--out=/private/tmp/zs-pocket-sail`.

## The study (studies/pocket_sail_study.gd)

It extends the character study, so it uses the same pilot, camera, F1
numbers and F2 feel panel. It is a tall greybox island in open sky, built from
the study's own station list (not an island pack file).

| Key | Station | What's there |
|---|---|---|
| 1 | Top · start | 36 m square slab 50 m up on a stem. Its edge can be hung from like any lip. |
| 2 | Launch pads | Four red pads on the east edge. Walking onto one throws you east: **nudge** 10 out / 8 up, **shove** 11 / 12, **blow** 12 / 16, **hurl** 14 / 21 (m/s). Landing on a pad doesn't throw you. |
| 3 | Shelf · 12 m down | A slab past a 4 m gap east of the cliff. A stair of 12 blocks (1 m each, a jump apiece) and a plank lead back up onto the top. |
| 4 | Islets · 26 m down | The main islet plus two more over stepping stones. Two switchback ramps (about 19°) climb to the shelf. |
| 5 | Floor · 50 m down | Under everything. Four more switchback flights and a bridge climb to the islets. |
| 6 | By the rising air | Look-out at the thermal column. |

- **K** (pad Y) is a sentinel's blow, a stand-in for the henge guardian. It
  throws you out from the island's middle at one of the pads' forces, picked
  at random, up to 0.5 rad to either side.
- **G** sends the next gust front now.
- **Gust fronts:** one every 10 s, alternating east (out from the island) and
  west (back towards it). Each band is 30 m deep, travels at 9 m/s and pushes
  8 m/s with 1 m/s of lift at its middle. They are drawn as bands of white
  streaks with a "gust →" sign.
- **Rising air (round 1; see Round 2 below for now):** a warm column at (30, -27), 6 m across, 75 m tall,
  strength 1.2 (the sail rises about 2.4 m/s in it before its caps).
- **Never death:** fall under -30 and you're set back at the nearest
  station.
- **F1:** the usual numbers, plus the sail (open or packed, speed across and
  down, lift, kick spent or ready, room to open), the last glide's ratio, the
  air at your feet, the next gust's direction and countdown, and the last
  throw (peak, and height now against where it threw you).
- **F2:** the motor's sliders, plus the sail's (`sail:pace`, `sail:sink` and
  the rest). Print copies them as `const` lines marked `# pocket_sail.gd`.

Try first: walk onto **hurl** (2, then right). At the top of the throw press
Space, steer back west, and press Space again over the top to fold and drop
onto it. Then try **nudge** and **shove** and see what height they leave you.

## Controls

| | Keys | Pad |
|---|---|---|
| Open the sail in the air (needs room under you) | Space | A |
| Fold it (drop), open again | Space | A |
| Steer (turns towards the stick, camera-relative, as on foot) | WASD / mouse | left stick |
| Float (slower across, slower down) | Shift or C (crouch) | LT |
| Study: thrown off / next gust / stations / start | K / G / 1-6 / R | Y / - / - / - |

Out of the plane, or off an edge in the old main scene, the dive keys hold:

| | Keys | Pad |
|---|---|---|
| Open / fold the sail | Space | A |
| Falling: turn, track forward | A D, W | left stick |
| Falling: spread and slow | Shift | LT |
| Falling: tuck and dive | none | RT (new `dive_tuck` action) |
| Under the sail: steer / dive faster / float | A D / W / S or Shift | left stick / LT |

## How it works

`scripts/pocket_sail.gd` holds the maths as plain state, so tests can step
it. The motor and the dive share it:

- **On foot:** `scripts/pilot_motor.gd` flies it as `move == "sail"`. It owns
  `sail` (a PocketSail) and an optional `air` callable (the feet's point in,
  `{wind, thermal}` out). Any scene that uses the motor gets the glider.
- **Drawing:** `scripts/pocket_sail_figure.gd` draws the wing as a child of
  the pilot's figure: six cells in an arc, cream with terracotta tips, lines
  to a bar. It pops out with a small swell, folds away, billows and leans
  into turns. `scripts/pilot_figure.gd` raises both arms over the idle to
  hold the bar (`_holding_sail`).
- **Wind in a scene with the game's atmosphere** (studies/atmosphere.gd):
  `PocketSail.atmosphere_air(atmosphere, point)` gives half the breeze plus
  the gust fronts' push and lift. `studies/kit_isle.gd` passes it to the
  motor, so the aqueduct isle has wind on the sail.
- **The dive:** `scripts/sky_dive.gd` now runs POP, FREEFALL, SAIL, DOWN.
  Walking off an edge calls `step_off`, which hands the walker's own sail
  over: still open if it was, its kick still spent. That fall is upright and
  uses the walker's gravity (39 m/s²) and top speed (18 m/s), not the
  belly-down skydive.

### Rules I picked

- **Opening needs room under you:** more than CLEAR (0.25 m) plus 0.25 s of
  the current fall speed. So it opens from any ordinary jump, over flat
  ground too: Space again near a plain jump's top glides a few metres and
  sets him down. A press within the motor's buffer (0.15 s) of the touch is
  still the buffered jump. Off an edge, or after being knocked away, it
  opens at once. (Until docs/design/serpent-teleports-sail/round1.md it was
  1.6 m plus 0.2 s: never from a jump over flat ground.)
  - I first allowed "always while rising". Two of the sky-village recordings
    mash Jump through every long jump, and that popped the sail at 0.7 m.
    That's why the rule is room only.
- **The kick:** once per airtime. Landing, catching a ledge, swimming or a
  knock gives it back. It never reduces your rise: speed up becomes
  `max(v, min(v + KICK, KICK))`.
- **Re-opening:** allowed REOPEN (0.25 s) after a fold, with no kick.
  Folding drops you at full gravity. Re-opening catches the fall at CATCH,
  and some of that fall goes into your pace (SWOOP).
- **Climbing:** wind can never lift you more than CEILING (1 m) above the
  highest your feet reached this airtime with the sail folded. Rising air
  slows the sink and can lift a little, but never climbs you back up.
- **Walls:** flying into one stops your speed across. There is no wall-slide
  or wall-run while the sail is open; ledges can still be caught.
- **Twirl:** X does nothing while the sail is open.

## Constants and how they feel

All are in `scripts/pocket_sail.gd`, and all except CLEAR are on F2.

| Constant | Value | Feel |
|---|---|---|
| PACE / SINK | 5.5 / 1.5 m/s | 3.67 m on per metre down in still air (measured 3.67) |
| PACE_SLOW / SINK_SLOW | 3.2 / 1.2 | crouch: floats, 2.7:1 |
| PACE_FAST / SINK_FAST | 7.5 / 2.4 | out of the plane only (W) |
| TOP / BLEED | 10 m/s / 1.5 m/s² | a 10 m/s long jump keeps 8.5 m/s a second into the glide |
| TURN | 2.4 rad/s | about 1.3 s to turn round |
| KICK / RISE_GRAVITY | 3.5 m/s / 20 m/s² | about 0.2–0.3 m extra from the top of a throw |
| CATCH / SETTLE | 12 / 3 m/s² | from 18 m/s it takes about 1.4 s and 13 m to settle |
| SWOOP | 0.3 | share of the fall over SINK turned into pace on opening |
| WIND / LIFT / THERMAL | 0.8 / 0.5 / 2.0 | a 4 m/s crosswind carries it 12.9 m in 3 s |
| RISE_MOST / CEILING | 0.8 m/s / 1 m | 20 s in a strong thermal: at most 0.99 m over the peak |
| REOPEN / CLEAR / CLEAR_AHEAD | 0.25 s / 0.25 m / 0.25 s | see the rules above |
| BREEZE / GUST_PUSH / GUST_LIFT | 0.5 / 5 / 9 | atmosphere scenes; the lift is capped by RISE_MOST |

Measured over a 40 m drop: opened at once, touchdown at 1.5 m/s; opened 6 m
over the ground, 8.9 m/s; never opened, 18 m/s.

## What changed from the canopy and the plane summon

- **Removed:** `scripts/canopy_figure.gd` and `shaders/canopy_cloth.gdshader`.
  The skydive no longer has OPENING/CANOPY phases, auto-open, the
  island-ward assist, the flare, or the swing on lines. `PilotFigure.dive()`
  dropped its flare argument; its `sail` argument is the hold pose.
  `dive_camera.gd` frames the sail where it framed the canopy.
- **Eject (X):** an unchanged pop and freefall. Space or A opens the sail and
  folds it again. X no longer opens anything. Tuck moved off Space/A (now
  the sail) to RT only; keyboard users track with W.
- **Off the edge with `--manual-landing`:** an upright drop. Nothing opens by
  itself; Space opens the sail. Stranding and the walk back to the plane are
  unchanged. The landing study (`studies/landing_study.gd`) works the same
  way: its mode "canopy" is now "drop".
- **The summon:** the motor never returns "fly". Pressing A again in the air
  opens the sail, everywhere. The hints in `scripts/wanderer_eye.gd`, keys
  and pad glyphs alike, now say "again in the air for the sail" and "Off the
  edge to fly". The kit isle's on-foot hint names the sail too.
- **Wind on foot in the old main scene:** `_walker_air` reads the glide's own
  air (sky currents, ridge lift, gust fronts), turned into the plate's or
  islet's frame.

## Tests

All headless. I ran the import check and the feature tests, not the full
suite.

- **New, passing:**
  - `tests/test_pocket_sail.gd`: sink ratio, kick once per airtime,
    fold/re-open, early vs late opening, carried pace and TOP, crouch float,
    steering, crosswind push, rising air and the ceiling, landing packs it,
    buffered jump not eaten, knock, the dive's sail matching.
  - `tests/test_pocket_sail_study.gd`: pads, the hurl coast back, the nudge
    to the shelf, the stair and both switchbacks climbable, gust push,
    thermal, K, the fall-back.
  - `tests/test_aqueduct_isle_sail.gd`: the sail on the aqueduct isle, its
    breeze, and a B gust pushing harder.
- **Updated, passing:**
  - test_pilot_motor, test_pilot_tricks, test_pilot_water (the "asks to fly"
    checks are now sail checks);
  - test_sky_dive (rewritten for the sail);
  - test_skydive (live, slow);
  - test_manual_landing;
  - test_manual_landing_game (live, slow);
  - test_gamepad: A in the air no longer flies; the flight leg starts as
    walking off the edge would.
- **Also passing:** every test_pilot_* and test_character_* except the one
  below; test_scene_picker and the picker entry run for pocket_sail; all the
  aqueduct isle tests, the three other kit isles, the island packs and
  test_kit_water.
- **Failing, and it already fails on main's motor:**
  `test_character_recordings.gd` "Tech. Fun, fluid, movement". It strays at
  28.82 s after a twirl, the same point with main's `pilot_motor.gd`. I did
  not add it to known_failures.
- **Not run:** the full suite, and the other live-game tests that walk off the
  plate's edge (test_plane_flight, test_walk_island, test_lower_world and
  others). They should be unaffected, because the default game's off-edge
  launch is unchanged.

## Open questions and weak spots

1. **The default game still flies off the edge.** Without
   `--manual-landing`, walking off the plate's edge still launches the plane;
   only A-in-the-air lost its summon. Making the drop the rule everywhere
   needs `--manual-landing`'s other rules too (a parked plane on entry,
   stranding). Since the aqueduct isle is becoming the main scene, the
   question may matter less there: its F key is how you fly.
2. **Room to open.** Lowered to 0.25 m (the user asked for it from any
   jump): Jump mashed through a long-jump chain now opens it mid-jump
   rather than only buffering the next.
3. **Not judged by hand.** Feel numbers (sink, turn, kick, catch) and gust
   strength need flying. The hurl coast-back works scripted, steered straight
   back. Whether a player can do it from the shove is untested.
4. **Camera.** The walker camera follows the sail at 7 m and does not pull
   back or widen. High throws may want more sky in view.
5. **Look.**
   - The arms-up hold is bone turns over the idle, and the legs hang from the
     idle too.
   - The wing is an ImmediateMesh rebuilt each frame (cheap, but greybox).
   - Rendered stills were checked (wing, arms holding the bar, gust streaks,
     thermal column). The open/fold animation and the gust band's motion
     were not watched live.
6. **Sound.** Opening and folding reuse a footstep and a flap; there is no
   cloth rustle.
7. **Knock.** `PilotMotor.knock()` is new and minimal (no tumble).
   `study/henge-guardian` has its own knock and tumble; merging will need one
   API.
8. **Dive tuck on keys.** Tuck is pad-only now (RT). Keyboard players track
   with W, and folding the sail is the new way to dive.
9. **The old skydive capture** (`tools/capture_skydive.gd`) was updated for
   the sail but not run.

## Round 2

The user flew round 1 and said: "I didn't notice the rising air lifting me up
at all." They also wanted the wing to look more like a handkerchief, like
fabric: narrower, with more of an arc.

### Why the rising air felt like nothing

Four things added up:

- **The cap.** A thermal could never take you more than CEILING (1 m) over
  the airtime's peak. From a throw you open near the peak, so it had about
  1 m to give.
- **The strength.** 1.2 units × THERMAL 2.0 = 2.4 m/s of lift, minus the
  1.5 m/s sink, left 0.9 m/s. RISE_MOST (0.8) capped that, and SETTLE
  (3 m/s²) took it up slowly. At best you flew level.
- **The size.** The column was 6 m across with a 3.6 m full-strength core.
  At 5.5 m/s you crossed it in about 2 s.
- **The place.** It stood at (30, -27). The pads throw along z = -7 to 14, so
  no throw went near it.

### What changed

- **Thermals climb you for real** (`scripts/pocket_sail.gd`). A thermal's
  lift now has no ceiling. In a column the sail climbs at up to
  THERMAL_MOST and takes up the climb at THERMAL_TAKE. While it climbs, the
  airtime's peak rises with it, so the height is yours to spend. Gust and
  wind lift keep RISE_MOST and CEILING, so a gust still pushes you sideways
  and never lifts you home. The ceiling can no longer force a sink faster
  than SINK. This was a latent case once a thermal had lifted you over it.
  `sail.riding` is true while a thermal climbs you. The figure, the camera
  and the numbers read it.
- **The study's column** (`studies/pocket_sail_study.gd`):
  - It is now at (46, -4), 20 m across, 85 m tall, with strength 3.0. That
    is 6 m/s of lift, or a 4.5 m/s climb after the sink.
  - It fades over its top 12 m, so you top out about 35 m over the top
    slab.
  - It draws you in towards its core at up to INFLOW (2 m/s), out to 1.8×
    its radius, which makes it easier to stay in.
  - The hurl's and the blow's lines out (z = -7 and 0) pass through it.
  - Station 6 starts at the east edge facing it.
- **Easy to see:** an outer tube plus a core tube with bands racing up, a
  warm ring on the floor at its foot, a "rising air" sign over the top's
  height, and "rising air: fly into it and circle" at shelf height.
- **Cues while riding:**
  - The column glows.
  - A banner says "riding the rising air: climbing".
  - The camera widens by RIDE_FOV, 9° (`studies/character_study.gd`, so
    every study with a sail gets it).
  - The sail puffs fuller and breathes faster.
  - A puff swirls up off the sail every 0.45 s.
  - F1's sail line says "riding the rising air".
  - No sound yet.
- **The handkerchief wing** (`scripts/pocket_sail_figure.gd`, rewritten):
  - The wing is now a 1.25 × 1.05 m square-ish cloth sheet held by its four
    corners on short lines to the bar. It replaces the 1.8 m wide six-cell
    wing.
  - The sheet arches deep across: its sides hang ARC (0.42 m) below its
    middle. It also domes along, with the front and back edges DOME
    (0.14 m) down.
  - It is a 16 × 16 grid with smooth normals: cream cloth with a thin
    terracotta hem.
  - The middle breathes, and the trailing edge ripples in waves running
    back, with the corners flapping most.
  - In a turn it rolls, the inside side pulls down (back corner most), and
    the ripple grows.
  - It pops out crumpled (deeper and rumpled), swells past full, and
    settles.
  - Rising air puffs it fuller.
  - `update()` takes a fourth argument, `lift` (0 to 1). The character study
    and the walker (`scripts/wanderer_eye.gd`) pass `sail.riding`. Other
    callers default to 0.
- **F2:** `sail:thermal_most` and `sail:thermal_take` added.
- **Capture:** `tools/capture_pocket_sail.gd` adds two close cloth shots and
  a riding-the-column shot.

### New constants

| Constant | Where | Value | Feel |
|---|---|---|---|
| THERMAL_MOST | pocket_sail.gd | 5 m/s | the fastest climb in a thermal |
| THERMAL_TAKE | pocket_sail.gd | 6 m/s² | from sinking to a full climb in under a second |
| RIDING | pocket_sail.gd | 0.3 m/s | climb over which it counts as ridden (cues) |
| THERMAL_AT / RADIUS / TOP / FADE / STRENGTH | study | (46, -4) / 10 m / 85 m / 12 m / 3.0 | see above |
| INFLOW / INFLOW_REACH | study | 2 m/s / 1.8 | the draw to the core |
| RIDE_FOV / RIDE_EASE | character_study.gd | 9° / 0.6 s | the camera's widening while riding |
| WIDTH / DEPTH / HIGH / ARC / DOME / GRID / HEM | figure | 1.25 / 1.05 / 2.0 / 0.42 / 0.14 m / 16 / 1 | the sheet |
| BILLOW / RIPPLE / PULL / PUFF | figure | 0.035 / 0.06 / 0.16 m / 0.9 | breathing, trailing ripple, turn pull, fullness in lift |

Measured headless:

- A 3.0 thermal, opened 0.3 s into a drop off a cliff: up 9.6 m in 4 s,
  7.6 m over the airtime's peak, climbing at 4.5 m/s. Out of it, 4 s later
  it was down 5.2 m, back at 1.5 m/s sink.
- A strong gust rise (6 m/s up) for 10 s: at most 0.85 m over the peak, so
  the ceiling still holds.
- In the study, opened in the column and circled: up 12.0 m in 4 s. The
  same opening outside the column: down 6.7 m in 4 s.

### Tests (round 2)

Headless only: the import check plus feature tests. Not the full suite.

- `test_pocket_sail.gd`: pass. The rising-air section is rewritten: the gust
  ceiling, the thermal climbing over 8 m in 4 s and over the peak, capped at
  THERMAL_MOST, and sinking at SINK once out of it.
- `test_pocket_sail_study.gd`: pass. New checks:
  - the column climbs the sail over 8 m in 4 s;
  - the banner and glow show while riding;
  - the hurl's and blow's lines pass through the column;
  - it stops at its top;
  - outside it, the sail sinks.
- Also passing:
  - every `test_pilot_*` (9);
  - test_aqueduct_isle_sail (pass, with the runner's known exit-leak
    diagnostic);
  - test_sky_dive;
  - test_skydive (live, slow; same known exit leak);
  - test_manual_landing*;
  - test_character_* except one.
- Still failing, unchanged from round 1 and from main's motor:
  `test_character_recordings.gd` "Tech. Fun, fluid, movement" (strays at
  28.82 s after a twirl).

### Looked at, rendered (`--no-title`)

The stills were `03-sail-out`, `06-cloth-close`, `07-cloth-side` and
`08-riding-the-rising-air`.

- The sheet reads as a domed cloth, not a board. It is narrower than round
  1's wing, with a deep arc and a thin hem.
- The first pass had a hem two squares wide, which read as a tray from the
  side. It is now one square of 16.
- From inside the column the warm haze washed the view out. I toned down
  the glow and the core tube afterwards, but did not re-capture that change.
- The ripple and billow are motion, and stills can't show them. They were
  not watched live.

### Open items

1. **Feel by hand.** Is 4.5 m/s of climb too strong, or just right? Are a
   20 m column and the inflow easy enough to stay in by circling with the
   stick? Turn radius at TURN 2.4 is about 2.3 m, so circling is easy. The
   question is whether players find out they should circle. Both
   THERMAL_MOST and THERMAL_TAKE are on F2. The study's strength and radius
   are constants.
2. **Haze inside the column.** It may still be too much when the camera is
   inside it. Lower `base` on the tubes, or fade them by camera distance.
3. **Sound.** There is no ride cue sound or cloth rustle yet.
4. **The game's own thermals** (`scripts/sky_currents.gd`, the old main
   scene) now climb the sail uncapped too, at their own strength (a 1-unit
   thermal gives 0.5 m/s net). This was not flown.
5. **The kit isles** have no thermals (`atmosphere_air` gives 0). If the
   aqueduct isle should have one, it must be placed.
6. **The cloth** is CPU-rebuilt each frame: 16 × 16 quads, about 1500
   vertices. That is fine for one pilot. Move it to a vertex shader if many
   sails ever fly.

## Merge with main

main (471e2249, "the aqueduct isle is the game") was merged into the branch.

- **Conflicts:**
  - `scripts/pilot_motor.gd`: `reset` keeps both `sail.rest()` and main's
    `carving = 0.0`; main's `carry()` and `_turned()` stay.
  - `scripts/scene_catalog.gd`: the pocket sail entry and main's two serpent
    entries.
  - `studies/character_study.gd`: both TUNABLE lists (carve and sail); the
    sail line went into main's `_hint_text()`.
  - `scripts/wanderer_eye.gd`: main's default-on hand landing
    (`--auto-landing` for the old one). Open question 1 above is settled by
    this: off the edge is now a drop in the default game too.
- **The kit isle's walk-off** (`studies/kit_isle.gd`). main had grown a
  walk-off that dropped into the skydive with the canopy opening by itself.
  It is now on foot all the way:
  - Walked, jumped or knocked off (falling STEP_OFF_DROP, 4 m, under where
    he last stood, with STEP_OFF_CLEAR, 12 m, of open air under him) sets
    `off_edge`. The motor keeps falling, and Space (pad A) opens the sail.
    Nothing opens by itself.
  - Stranding stays as main had it, as the never-death net. Once
    STRAND_BELOW (20 m) under the edge, or down in water, he is stranded for
    STRANDED_WAIT (3 s) and then back beside the parked plane. Down on
    ground or a ledge before that, he walks on. While off the edge the
    isle's `lost` height is set aside, so the strand rule decides and not a
    respawn at the start.
  - Removed: the SkyDive drop, the canopy figure, the dive camera, the
    dive's own input (X to open), DIVE_HINT, CANOPY_HINT and STEP_OFF_OPEN.
    The kit isle has no eject, so nothing else needed the skydive there.
  - Hints: FOOT_HINT names the sail; off the edge FALL_HINT ("Space (pad A)
    open the sail"); under it SAIL_HINT (steer, Shift or C / LT float,
    Space / pad A fold).
  - All of main's plane, hand landing, parking, boarding and stranding stay.
    The isle's wind still reaches the sail (`motor.air`,
    `PocketSail.atmosphere_air`).
- `tests/test_kit_isle_landing.gd`'s walk-off now checks the sail rules:
  off the edge on foot, nothing opens by itself, the hint offers the sail,
  stranded and back by the plane; then again with Jump opening the sail,
  sinking slower than the fall, and still stranding back to the plane.
- Comments in `scripts/kit_isle/pause_host.gd`, `pause_menu.gd` and
  `studies/zenscape.gd` no longer mention the canopy. Nothing references the
  deleted canopy files. Older docs (`docs/skydive.md`,
  `docs/design/manual-landing.md`, `docs/design/consolidation-audit.md`)
  still describe the canopy as history.
- **A replay bug in the merge:** the sail's F2 numbers (`sail:pace` and
  the rest) made `feel_names()` include `sail`, the PocketSail itself.
  `_feel_now()` stored that object in recordings, and `replay_verdict()`
  then crashed on `float(object)`. That broke test_slide_carve and the
  round trip in test_character_recordings. Now `_feel_now()` stores each
  `sail:NAME` as its own number, and the verdict reads those through
  `_feel()`. Restoring a recording still keeps the motor's own sail.

### Tests after the merge

All headless. The import check is clean. Not the full suite.

- **Passing:** test_pocket_sail, test_pocket_sail_study,
  test_aqueduct_isle_sail, every test_pilot_* (9), test_slide_carve,
  test_serpent_ride, test_rune_serpent, test_sky_dive, test_skydive,
  test_manual_landing, test_gamepad, test_scene_picker,
  test_kit_isle_landing (with its new sail checks), and every other test that
  touches the kit isles: test_aqueduct_isle (+ _life, _look, _plane, _sky),
  the cloister tarn, colonnade spine and sundered gorge isles, test_dev_keys,
  test_export_entry, test_front_door, test_game_pause, test_game_settings,
  test_isle_hall_chain, test_isle_lock, test_isle_lodestone,
  test_isle_teardown, test_kit_clouds and test_kit_water.
- **Still failing the same way as on main:** test_character_recordings
  "Tech. Fun, fluid, movement" (strays at 28.82 s after its twirl, 9.54 m
  off). Its round trip passes again.
- **Intermittent:** test_manual_landing_game. It failed 2 of 10 runs after
  the merge, and passed all 4 runs at the branch's head before it. Each run
  makes a fresh random world.
  - Failure one was "Down on the plane's own island, on foot (not
    stranded)" plus the boarding checks after it. That was in the parallel
    batch.
  - Failure two was "Space opens the sail", in a run alone.
  - Not diagnosed. Both are in the old main scene's walk-off
    (`wanderer_eye.gd`), which the merge did not change beyond making hand
    landing the default.
