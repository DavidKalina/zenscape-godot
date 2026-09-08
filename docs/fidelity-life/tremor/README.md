# Bigfoot catches his balance

Press T or use the existing ground-tremor button in Fidelity Life. The shared
tremor event also reaches the editable Bigfoot playground scenes. A meaningful
shake interrupts the current activity, plays the existing crouch/landing clip
with additive torso wobble and balancing arms, then returns to Alert and normal
behavior. Strength controls the amount and duration of the stumble.

This is a planted balance reaction: the animation does not push the navigation
position off a bank. It does not add a ragdoll fall. Tiny events below 0.2 are
ignored; a carried, landing, wind-tossed or recovering actor is not overridden.
Pause queues the response until the actor clock resumes. Existing routine
cancellation handles dropped stones, fish release, tree restoration and sleep
marks. No Blender asset was changed.

`comparison.mp4`: new response on the left, same camera tremor without the actor
response on the right. Strong tremor at one second, smaller tremor at five.
`stumble.mp4` is the full-size effect reel. The camera/input and rendered-frame
clock are locked by `tools/film_bigfoot_tremor.gd` (Forward+, fixed 60 FPS,
Godot Movie Maker; `-- --control` disables only the actor response).

Checks passed:
- `test_creature_tremor.gd`: threshold, queued/paused reaction, fixed feet,
  recovery, strength scaling, carried actor, interrupted sleep and disabled input.
- `test_fidelity_tremor.gd` (Metal): actual held stone drops without duplication;
  T wakes sleeping Bigfoot after pause, clears Zs and restores upright footing.
- Existing creature actor, routine actor and growth regressions.

Effect/control frames were inspected for torso motion and balancing arms.
