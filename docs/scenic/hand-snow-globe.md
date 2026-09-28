# Shake it like a snow globe

Branch `feature/hand-world-shake`, 2026-09-28. One slice of the "hand is the interface" direction (`docs/scenic/hand-world.md`, "Shake it like a snow globe"). Grab the diorama's rim and shake it. The diorama jiggles in the hand, and it snows in winter and rains otherwise, as much as the shake was hard and long. Let go and the world settles on its own: the jiggle rings down and the fall thins away. Nothing is switched on or off.

`scripts/snow_globe.gd` does the work. Its API does not depend on how the rim is grabbed: `grab(screen_pos)`, `feed(screen_delta, delta) -> bool` (true once the grab has been judged a shake) and `release()`, plus the `shake_started` signal.

## Try it

Run the main scene. Press on the rim (the earth block's wall, or the plate's top within `RIM_BAND` 1.5 m of its edge) and shake the mouse back and forth. Pressing on the land or the sky still moves the camera. A slow drag along the rim does nothing but lean the diorama a touch. For snow, turn the season to winter first (E steps the season).

## The rules it keeps

- **The mouse drives and the hand interprets.** A shake is not a shape to draw. It is an ordinary drag that keeps turning back on itself quickly. The drag is projected on its own main axis (a running second moment over `AXIS_TIME` 0.25 s, so any direction works). A stroke ends when the drag comes back `TURN_SLOP` (0.005 screen heights) from its furthest point. The turn counts if the stroke travelled at least `MIN_STROKE` (0.012 screen heights) within `MAX_STROKE` (0.45 s), at `MIN_SPEED` (0.12 screen heights a second) or more. `STROKES` (2) counted turns within `WINDOW` (1.1 s) make a shake. A stroke that runs past `MAX_STROKE`, or a slow one, clears the count. So a slow steady drag never turns, and slowly working the rim back and forth (as the season dial will be) turns too slowly to count. A firm shake is judged a shake after about 0.2 s, and a gentle one after about 0.35 s.
- **You release, and the world decides.** The shake stirs the fall up and the air settles it out; see "The fall".
- **Feel first.** The diorama answers the drag from the first frame, before any shake has been decided, and the hand's shake speeds up with the drag.

## The fall

- **Stirring.** `vigour` is the drag's speed, smoothed over `VIGOUR_TIME` (0.12 s), in screen heights a second. Strength runs from 0 at `GENTLE` (0.08) to 1 at `FIRM` (1.8). It counts only while a decided shake is still turning (within `LIVELY`, 0.5 s, of its last counted turn). Strength raised to `STIR_CURVE` (1.5) lifts `STIR` (0.8) of the loose fall a second into `airborne`. So a gentle shake lifts a few flakes and a firm one a flurry. A long firm shake approaches a full storm.
- **Settling.** The airborne fall settles out with a time constant of `SNOW_SETTLE` (9 s) for snow and `RAIN_SETTLE` (4 s) for rain, mixed by the world's cold. Snow drifts down for half a minute; rain is gone sooner. The fall shown builds toward what is airborne at `GATHER` (4/s), so it comes in over a moment rather than popping. A fully stirred globe is `FLURRY` (0.85) of the heaviest precipitation. The fall ends at `DONE`.
- **The weather it uses.** Nothing new is drawn. The fall is the precipitation's second channel, `studies/precipitation.gd` `state.y`, which the particles add to the sky's own rain (`state.x`). No preset sets it, and it drains toward zero by itself. So the world's cold decides whether it falls as snow or rain (`surface_weather.snow_phase`: winter's cold is snow, the rest of the year rain). The ground whitens or wets under it as it would under any sky, and the air reads it as rain. Bigfoot already reads `state.y` as snow: a firm, long flurry may send him out to catch it, or to shelter.

## The jiggle

The camera moves, not the diorama. `scripts/reference_tremor.gd` has a new `jiggle` (metres along the camera's right and up, and a roll about the view). The tremor moves the view the other way, so the whole world moves together on screen, with the hand on its rim. The terrain, water, creatures, physics and the precipitation's height map never move. Moving the real diorama would have meant moving the plate's node under everything that lives in plate or world space (fog, water, the precipitation's clip map, creature navigation). The camera gives the same picture and touches none of that. The tremor is applied before the display fog reads the camera, so the fog stays aligned; the snow globe runs at `process_priority` -10 for that, as `scripts/world_rumble.gd` does.

- **The pull.** The drag is high-passed over `PULL_TIME` (0.12 s), so a steady drag leaves only its speed times that. The diorama follows `PULL_GAIN` of it: 0.15 while simply held, rising with the square root of the shake's strength to 0.45 at full strength. So a gentle shake stirs it a little and a slow drag barely leans it. The offset is capped at `MAX_JIGGLE` (0.06 screen heights), and it rolls `ROCK` (0.35 rad per screen height) as it swings sideways.
- **The weight.** The diorama rides the pull on a spring at `JIGGLE_HZ` (3.5 Hz) with damping ratio `JIGGLE_DAMPING` (0.25). It lags a touch and overshoots like something heavy, and after release it rings through rest a few times and is still within a second or two. I first tried 2.4 Hz, but that sat on a gentle shake's own rhythm, and a gentle shake then jiggled as much as a firm one.

## The hand

The hand (`scripts/god_hand.gd`) gets a new gesture key, `"shake"`, for the clip family `Shake`. While the rim is held, the snow globe sets `reach_gesture` to it and `reach_point` to the lip, on the side of the plate nearest the press and at least `CORNER` (1.2 m) from a corner. It also sets two small new hooks in god_hand.gd:

- `reach_facing` turns the hand so its reach leads in across the lip, instead of keeping its profile to the camera.
- `reach_pace` is how fast the Hold plays: `PACE` 0.35 while simply held, up to 1.6 at a firm shake.

On release it clears all four. The hand's knuckles are not lifted clear of the land while it grips (`UNLIFTED`), because its fingers are meant to touch the rim.

The clips (`tools/blender_hand/god_hand_clips.py`, section "shake: the snow globe"). The anchor is the lip. The plate's top is the anchor's -Y side, and the earth block's wall runs down its +Y side. The grip is a ledge grip: the hand hangs on the outside of the wall with its palm to it, the four fingers hooked over the lip onto the top and the thumb braced on the wall. It is solved against the rig (`prepare_shake`) and seen from the back.

- **ShakeIn** (22 frames, contact at 12). Anticipation: it rises and opens wide as it draws back. It swings out over the lip with the palm to the wall and the fingers long and up, drops, hooks them over, squeezes past the grip (`GRIP_HARD`) and eases back.
- **ShakeHold** (24-frame loop, two shakes). The heel swings along the lip and back about the hooked fingertips, and the wrist rolls into each stroke a beat behind. The palm pumps against the wall at the turns and the grip squeezes. The fingertips hold, so their springs are pinned, and the overlap is drawn in by hand: the thumb flaps behind the stroke, and the little finger lifts off at the far end and hooks back.
- **ShakeOut** (42 frames). One last squeeze with the heel dipping. Then the fingers unhook and fling open as the hand springs up and back off the rim, shakes itself out loose from the wrist, and floats home to Idle.

`god_hand_review.py` has a rim stand-in for the Shake clips and a `--view=rim` (from outside the rim, as the game sees it). `--check` gives 0 for every Shake hand-off.

## Checks

- `tools/probe_snow_globe.gd` (headless, stand-ins, fixed 60 Hz steps) proves:
  - Which presses hold the rim (the land, well inside the edge and the sky do not).
  - A slow drag along the rim, and slow back-and-forth working, are not a shake.
  - Gentle and firm shakes are, and a firm one brings more than four times the gentle one's fall, and a longer one more still.
  - Snow in the cold and rain otherwise.
  - The fall thins after release and is over by itself, rain sooner than snow.
  - The jiggle is bigger for a firm shake than a gentle one or a slow drag, rings through rest and comes to rest within 3 s.
  - The hand plays ShakeIn into ShakeHold, reaches in across the lip, holds it with its fingers over the top, shakes faster with a harder shake, and plays ShakeOut into Idle when it lets go.
  - With `claim_grip` off, the hand waits for a decided shake.
- `tools/probe_snow_globe_scene.gd` (headless, the real `studies/cozy_worlds.tscn`) proves:
  - The real earth block and plate are found.
  - A firm shake reaches the real precipitation as falling snow instances in the cold.
  - The tremor jiggles the camera and rings down.
  - The real hand grips and lets go.
- **Unverified.** How the flakes, the rain and the jiggle look on screen needs a GPU and has not been seen. Nor has the hand's grip on the real rim in game: the grip was checked only in Blender contact sheets against the stand-in block.

## At merge

- `scripts/hand_reach.gd` (the sun slice) owns the rim grab. The end of `snow_globe.gd`, "Temporary rim grab", is the seam: `_is_rim` and the input hookup. Delete it and connect `rim_grabbed` to `grab`, `rim_dragged` to `feed` and `rim_released` to `release`. When `feed` returns true (or on `shake_started`), put the season dial back to its grab-time value.
- If the rim grab shows its own grip or dial gesture, set `claim_grip = false`. The snow globe then sets `"shake"` only once a shake is decided, and hands the hand back to whoever set it on release (it clears the reach only if it is still `"shake"`).
- `rim_at(screen_pos)` (lip point and way in) may be useful to hand_reach for its rim zone.

## Open

- Whether a firm shake should also gather cloud. It does not now, so a flurry can fall from a clear sky, as it does in a globe.
- Whether creatures should notice the shake itself (a stumble like the tremor's) and not only the fall.
