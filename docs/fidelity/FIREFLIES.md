# Fireflies

The imported landscape now has 90 fireflies in its original damp-understory
habitat. Each uses its own wandering phase, amplitude and blink rhythm. The
native additive shader gives them a pale warm center and a soft green halo;
opaque terrain and foliage occlude them.

They emerge at dusk, reduce activity in rain, and disappear in cold weather.
The **Invite fireflies · even in daylight** checkbox bypasses daylight only.
Unfinished terrain or foliage hides them, including during paused growth
scrubbing. Both wandering and blinking use the scene's paused motion clock.

`tests/test_fireflies.gd` checks habitat population, daylight/invitation, rain,
cold, paused growth visibility and the shared animation clock with the native
graphics renderer. The whole-scene night capture and closer frames were
visually inspected for readable glow and landscape occlusion.

`fireflies-comparison.mp4` shows four seconds at 30 fps, fireflies on the left
and the same scene with their render layer disabled on the right. Capture:

```sh
Godot --path . --rendering-method forward_plus --resolution 1440x900 \
  --fixed-fps 30 --script tools/film_fireflies.gd -- \
  --clean --mood=2 --cam=15,1.0,1.9,6,2,5 \
  --film-frames=120 --film-dir=/private/tmp/fireflies-close-effect
```

Add `--control` and use a different film directory for the control reel.
This is a native visual adaptation, not a claim of pixel parity. Fireflies do
not cast dynamic lights onto nearby foliage or implement collision physics.
