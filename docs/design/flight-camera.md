# Flight camera (feature/flight-camera)

The chase camera at the 2x plane: the plane always in view, a little lead
into turns, and speed read against the plane's cruise. Branch
`feature/flight-camera`, from `feature/world-spacing` with
`test/plane-speed-camera` merged in.

Code: scripts/glide_camera.gd (`framed`), studies/kit_isle.gd
(`_new_chase`, `_size_chase`, `_sight`), scripts/sky_plane.gd
(`GAME_SPEED`, `turn_scale`). The instrument: tools/flight_frame.gd.

## What lost the plane

Measured with tools/flight_frame.gd. It flies hard manoeuvres (chained
full-stick turns, boosted turns, a dive and pull-up, mouse flicks, knife-edge
drifts, barrel rolls, a loop, braked turns) and pursuit routes close to the
aqueduct isle's stone. Every frame it puts the plane's middle, wingtips, nose
and tail through the camera's projection, and casts a ray from the eye to the
plane.

- **Open air never lost it.** With no stone, the framing is the same at
  plane 1 and plane 2 (the camera scales with the plane). The plane's edge
  never went past 0.55 of the half-screen, in any manoeuvre, at either size
  or speed. The turn tuck, the spring's lag and the >16 m/s pull-in did not
  push it out.
- **Stone did.** The old `_keep_clear` probed 12 points from the plane out
  to the eye. At the first hit it snapped the eye in, sometimes to 0 m, and
  wrote that into the spring's offset. The spring then had to swing back
  out from there, so the camera sat jammed in for about 10 to 20 frames
  after the stone had gone. The plane filled the screen or the eye sat
  inside it. A camera twice as far back crosses stone and turf more often.
  Turns made this worse because the camera swings wide, out over the ruins.
- **The probes missed thin stone.** Points 0.9 m apart skipped decks, piers
  and slabs between the eye and the plane, so stone hid the plane without
  any clamp: 17.9% of the frames threading the aqueduct's arches.

Before (old camera, `--plane-speed=1.15`, plane 2, isle run): plane edge
past the safe margin (0.8 of the half-screen) in 2.2% of frames, middle
hidden by stone 2.7%, worst 14.9 half-screens (wingtips far off screen),
closest 0.8 m. At plane 1: middle off screen in 1.7% of frames, margin
3.2%, closest 0.0 m.

## What changed

**Speed** (scripts/sky_plane.gd):
- `GAME_SPEED := 1.15` is the game's speed. kit_isle calls
  `use_game_speed()` on every plane it makes, so cruise is 16.1 m/s, boost
  25.3 and brake 9.2.
- `--plane-speed=<x>` still overrides it.
- A bare SkyPlane flies at 1 (the flight study and its benches stay pinned).
- `cruise()` gives the speed the engine holds.

**Turn rate:** `turn_scale` follows the speed by default, so at 1.15x the
turn rate is 1.84 rad/s and the turn radius stays the toy's 8.7 m. The isles'
lines and gaps were laid for that radius. With the old rate the radius would
grow 15% and carving a route over the isle would get wider. `--plane-turn=1`
keeps the old rate for an A/B.

**Framed camera** (scripts/glide_camera.gd, `framed`, set by kit_isle
only; the glide and the old game keep the old camera exactly):
- **Rock: go round before coming in.** When stone or turf blocks the line to
  the plane, the camera tries the DODGES in turn:
  - small and large swings round;
  - lifts over;
  - a drop to level behind, for under an arch or an island's edge;
  - wide swings.

  It takes the nearest one that sees the plane clear and eases there
  (EASE_DODGE 0.1 s), and back again over 0.6 s. It only draws in when no
  dodge is clear. Even then it comes no nearer than `near` = NEAR_SPANS
  (1.7) spans: 4.8 m at plane 2, 2.4 m at plane 1. It eases back out over
  0.35 s. The spring's own offset is never overwritten, so there's nothing
  to swing back out from.
- **Sight by ray:** kit_isle's `_sight` casts against stone, turf and the
  halls (`plane_mask`). Thin pieces no longer slip between probes.
- **Always in frame:** after the eye is placed, the view turns towards the
  plane if its edge (a ball of half a span) is past SAFE (0.62 of the
  half-screen). It eases in towards EDGE (0.84) and never passes it. The
  eye stays put; only the aim moves. `aspect` comes from the viewport.
- **Lead into turns:** the look-ahead swings into the turn by the eased
  heading rate times LEAD_TIME (0.3 s), at most LEAD_MAX (0.3 rad). It
  never steers anything. It is off while a sequence frames the camera
  (`cine`, the landing's).
- **Speed sense against the cruise:** the view widens (FOV_FAST, 10
  degrees) from FOV_SHARE 0.57x to 2.86x the cruise, the old 8 to 40 m/s
  around the toy's 14 m/s. At the default speed, cruise therefore looks as
  the old toy's did. The old tuck-in above 16 m/s is gone for the plane.
  Instead the eye eases back up to PULL_BACK (12%) more, from PULL_SHARE
  1.05x to 1.65x the cruise. Boost now pulls the camera back about 10% and
  widens the view by 3 degrees. Before, boost pulled it in 30%.
- **Sizes:** `near` and `extent` come from WorldScale TOY_SPAN times the
  plane's size now (`ground_scale.size()`). Distance, height and look-ahead
  already followed `size`.

**After** (same isle run, plane 2, speed 1.15): plane off screen 0.0%, past
the safe margin 0.0%, worst 0.80 half-screens, closest 4.4 m (the hard-touch
shake can take it a little under `near`). The middle is hidden 1.0% of the
time, briefly, while the camera swings round a pier or lintel. Threading
the aqueduct's arches it is hidden 3.5% of the time, down from 17.9%. At
plane 1: off 0.0%, margin 0.0%, hidden 0.5%.

**Old feel vs new** (open air, the instrument's `open`): at cruise the plane
spans 0.10 of the screen's width at both sizes, and the view's angles and
look-ahead match, because the camera scales with the plane. The `lead`
number (how far off-centre the plane ends up, 0.75 s later, in the view it
had then) fell from 0.40 to 0.29 at plane 2 and from 0.76 to 0.58 at plane 1.
The view now looks more where the plane goes. What doesn't match: ground
features near the plane pass a camera twice as far back at half the angular
speed. That is why 1.15x speed felt right.

## Flags and A/B

- The game: `godot --path . res://studies/zenscape.tscn -- --no-title`
- The old plane size: `-- --no-title --plane-scale=1`
- The old size, speed and turn together: add `--plane-speed=1`
- The old camera, with the same plane: `--cam-old`
- The old turn rate at the new speed: `--plane-turn=1`
- The trial knobs from test/plane-speed-camera still work:
  - `--cam-distance=<x>`
  - `--cam-fov=<deg>`
  - `--cam-speed-fov=<x>`
- Captures (dev builds), e.g. a 4 s hard left turn:
  `--fly --capture=out.png --capture-wait=4 --capture-stick=-1,0 --capture-seq=3,0.5`
  - `--capture-stick=<turn>,<pitch>` holds a stick while the capture flies.
  - `--fly-at=x,y,z,deg` starts flying there, the heading in degrees
    clockwise from -z. E.g. through the stone circle:
    `--fly-at=100,43.5,0,270`.
- The instrument:
  - `godot --headless --path . -s tools/flight_frame.gd -- open [unframed]`
    (the bare maths, both sizes);
  - `-- isle [--plane-scale=1] [--cam-old]` (the aqueduct isle). Isle runs
    vary a little run to run; compare whole runs.

## Tests

- test_glide_camera: new framed checks.
  - Through chained turns, boosted turns, flicks and a dive, the plane stays
    inside EDGE.
  - A slab where the eye trails: it goes round or over, never in.
  - Rock all round behind: never nearer than `near`, and the plane stays in
    view.
  - Clear again, it eases back out.
  - It leads into a turn.
  - At boost the view widens and the eye eases back.
  - The cruise view is the same at any `--plane-speed`.
- test_sky_plane: the game's cruise is GAME_SPEED times the toy's, and the
  turn radius stays the toy's.
- test_isle_hall_chain: its rise check starts the plane inside `ring_near`
  (no flown approach does that). It now holds the brake while the ring
  rises, since at 16.1 m/s the plane reached the ring as it stood. The
  ring's own wake distance is already speed-relative.

## Open

- **Not flown by a person yet.** Tune these by feel:
  - LEAD_TIME / LEAD_MAX;
  - SAFE / EDGE;
  - PULL_BACK;
  - the dodge set and its easing.
- The isle lock (`_frame_isle`, R3/Tab) moves the camera after the chase
  and isn't guarded. When circling an isle its aim is drawn halfway to the
  isle's middle.
- With the plane hard against stone or under an island's edge, the only
  clear view can be the steep lift (up to LIFT_MOST, 72 degrees), which
  looks down on the plane.
- In a long full-stick turn the camera still swings wide outside the turn
  (the spring and the way's lag, as before). The lead puts the plane right
  of centre (about 0.45 of the half-screen) in a hard left turn. If that
  reads as "in the way", ease EASE_WAY or SPRING next.
- test_plane_flight ("Clear of the ground") and test_manual_landing are
  flaky under parallel load. Both pass on their own. They fly the old game
  (cozy_worlds) and the landing study, which keep the old camera and speed.
