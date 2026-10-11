# Plane ground scale (demo)

On its wheels the plane is drawn bigger, so the pilot in the cockpit is the
wanderer's size. In flight it is exactly the old toy size. Code:
scripts/plane_ground_scale.gd, wired in studies/kit_isle.gd (the aqueduct isle
game), with `size`/`lift` on scripts/glide_camera.gd (1 and zero in flight).

- Factor 2.4 by default. Measured: the wanderer is 0.44 m from shoulders to cap
  top and the cockpit pilot is 0.185 m (2.38). Shoulder width gives 2.2.
- `--plane-ground-scale=<x>` sets it. `=1` turns it off: every change falls
  back to the old numbers.
- Driven by ground speed: full size at or under 3 m/s, flight size from 10 m/s
  (ROLL_TOP is 11). Eased over 0.22 s and capped at 1.4x the full change a
  second. Off an edge and dipping it shrinks fast (0.12 s). Flying, it is 1.0.
- Scaled about the wheel contact (PlaneStrip WHEEL_DROP/WHEEL).
- Follows the scale: chase distance, height and look point; the hop-in start
  and the hop arc; the hop-out spot (left, between the lower wing and the
  tailplane); the board reach and the walker's keep-off column; the parked
  footprint check when picking the plane's home.

Open issues:
- On the ground the wings clip trees and walls, and the roll's blocked/bump
  checks still use the flight-size plane.
- The landing mark is hidden on the kit isle, so it wasn't touched. The scarf
  doesn't scale (its width/length).
- The stone plane (`--stone-plane`) is scaled about the wooden plane's wheel
  point. Not checked.
- Rolling off an edge slowly can show a short (~0.3 s) shrink during the dip.
- Not tuned. Only the parked view was captured; the mid-roll blend hasn't
  been seen yet.

Where the cheat can show (keep these in mind for later features):
- Planes seen from on foot in the air: CPU traffic flying low past the
  wanderer, or a landing watched from the ground, reads as a model plane.
  Traffic seen from on foot may need the same cheat.
- Mid-air hand-offs: ejecting into the pocket sail or being knocked off by the
  dragon swaps the ~0.5 m cockpit pilot for the 1.19 m walker in the air.
  Each one needs something to hide the change (a puff, a tumble).
- Built spaces: anything the plane parks in (hangar, strip, dock) is sized for
  the ground scale; anything flown through is sized for flight (SPAN 1.4).
- Ask scripts/plane_ground_scale.gd how big the plane is right now; don't
  hard-code either size in new code.

Meeting in the middle (demo, branch test/plane-wanderer-scale):
- `--plane-scale=<x>` (default 1) draws the plane x times bigger everywhere,
  in flight too, scaled about its wheels so landing and skimming are
  unchanged. Its bump bodies (flight hull, roll checks, fuselage box) grow and
  shift with it; the chase camera's distance, height and look point follow
  (`size()` = plane_scale * ground k). Flight physics and speeds untouched.
- `--wanderer-scale=<x>` (default 1) scales the walker's figure, his body
  collider (radius and head; step-up kept) and the on-foot camera's distance
  and height (studies/character_study.gd, scripts/pilot_physics_ground.gd).
- The ground factor now derives as 2.4 * wanderer / plane, never under 1;
  `--plane-ground-scale=` still overrides it. E.g. 2.0/0.8 gives ~1 (cheat off).
- Not done: the moveset (jump height, speeds, ledge reach) isn't re-tuned for
  a smaller walker; set-piece gaps aren't re-spaced (pierced isle's
  ROUTE_CLEAR still reads the toy SPAN); the pocket sail and the cockpit
  pilot aren't scaled; other scenes' planes (ruin gallery, sky_pierced,
  traffic) are unchanged.
