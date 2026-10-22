# Random wakes on the sea: handoff

## Cause
The sea's wake (`EndlessSea._wake`, `zs_wake` in `shaders/endless_sea.gdshader`)
was laid whenever the plane was within 7 m of the water, at any speed. With a
plane not travelling (parked or landed near sea level, slow, hanging) the
trail holds one old point at the plane's spot; the V's arm is drawn at
`0.6 + age * spread` from the nearest point of the track, so it becomes a
ring that widens and fades over ~4.6 s. When that point expires (4.8 s) a
new one is laid and the ring starts again: circular wakes appearing from
nothing. The same nearest-point rule also closed the arms into a ring cap
round the oldest end of a moving trail.

## Fix
- `_wake` scales the wake's strength by travel speed (`WAKE_SPEED` 3..9 m/s),
  for the trail and for the foam laid in the buffer.
- `zs_wake` skips points past the trail's oldest end (`wake_tail` uniform).
- `--wake=old` brings back both (wake at any speed, ring cap).

## Proof
Headless throwaway (`scratch/wake_sim.gd`, calls the real `_wake`): a
stationary plane 3 m up kept 2 trail points and re-laid a fresh one every
~4.8 s (ring restarts); now count stays 0. At 16 m/s the trail still fills
(36-40 points). I could not catch the rings in a rendered still (the capture
camera did not frame the wake), so the visual before/after is by reasoning
plus the trail numbers. Smoke check of `studies/endless_flight.tscn` passes;
a rendered run compiles the shader.

Look: `./run-endless-flight.command --at=-707,707 --alt=3`, land or stall
near the water; add `--wake=old` to compare.

Breaks no existing test known (suite not run).
