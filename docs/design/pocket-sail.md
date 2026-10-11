# Pocket sail (round 1)

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
- **Rising air:** a warm column at (30, -27), 6 m across, 75 m tall,
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

- **Opening needs room under you:** more than CLEAR (1.6 m) plus 0.2 s of the
  current fall speed. So it never opens from a jump over flat ground (the
  pump tops out at 1.5 m). Mashing Jump through a long-jump chain to catch
  the landing buffer still just buffers. A press that close to the ground is
  the buffered jump, as before. Off an edge, or after being knocked away, it
  opens at once.
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
| REOPEN / CLEAR / CLEAR_AHEAD | 0.25 s / 1.6 m / 0.2 s | see the rules above |
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
2. **Room to open.** 1.6 m makes it a drop-and-knock tool, not a jump
   extender. If the user wants to pop it at a jump's top over flat ground
   (as in BotW), lower CLEAR on F2 and watch long-jump chains with Jump
   mashed.
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
