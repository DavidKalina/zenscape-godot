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
