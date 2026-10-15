# Dragon downwash, round 1

An experiment on the `roguelike` branch. When the dragon flies, his wings
push air down under him and lift it over him. Coming at him from below gets
you punished; coming from above gets you a ride. He never notices you.

## What was built

- **One field** around his body: `scripts/dragon_downwash.gd` (RefCounted,
  pure maths plus one shader hookup). `SkyDragon` owns it (`downwash`) and
  updates it every frame from `advance`. It covers the flying sky dragon
  (`--dragon`) and the roost dragon on his wake circuit (`wake_fly`). It is
  off while he waits, rises out of the sea, grips, clings or leaves a rim,
  sleeps, takes off and lands.
- **Below him (downwash):** the air comes down. It pulses with his beat:
  `DOWN_PEAK` at the middle of the downstroke and `LULL` of that through
  the upstroke. The wash falls at `WASH_FALL`, so deeper down each beat
  arrives later. Gliding, it is a steady `GLIDE` share.
- **Above him (updraft):** a steady `UP` lift.
- **Shape:** an ellipse, `ACROSS` x `ALONG` of his span. It reaches `BELOW`
  down and `ABOVE` up, and passes through zero within `BODY` of his middle.
  His span is `MODEL_SPAN` (122 m, measured from rim_dragon_c.glb) times his
  `size`, so the field grows and shrinks with him. At SIZE 1.5 it is about
  77 m out to each side, 82 m deep and 55 m high. Plane and wanderer sizes
  are not used.
- **Plane:** the host (`studies/aqueduct_isle.gd` `_dragon_air` →
  `plane_air`) merges `downwash.plane_air` with the gale's `plane_gust`.
  SkyPlane `step` adds the result to its velocity. In the wash it also
  pushes the nose down (`PLANE_NOSE`) and buffets the plane
  (`PLANE_BUFFET`, `PLANE_ROLL`). Above him it gets `wind.y` up.
- **Pocket sail / glide / hover:** the host lays `downwash.pilot_air` over
  the isle's air on `motor.air` (`_wash_air`). Under him, `wind.y < 0`
  (`SAIL_PRESS` of the wash) cancels the sail's lift and presses it down by
  that much on top of its sink, including the crouch float. This is a new
  branch in `scripts/pocket_sail.gd` `step`. Above him it is a thermal, so
  the sail climbs and shows "riding".
- **Foliage/water:** each downstroke that reaches the ground fires a gust
  there. It uses the wind tool's own burst (`zs_burst_a/b`, read by
  `zs_blow_at` in the grass, canopy, conifer, leaves and water shaders). A
  front runs out from under him (`RING` of his span, over `RING_RUN` s), and
  everything reacts as it does to any other gust. Gliding, he fires a weaker
  one every `GLIDE_EVERY` s. He has to be within about `BELOW` of the ground
  (a ray every 0.2 s, `SkyDragon._downwash`). Nothing flattens anything.
- **Roost dragon:** the downwash is on during `wake_fly`. The "spectacle
  only" line in `scripts/dragon_wake.gd`'s header now says so. His pass over
  the aqueduct isle is 62 m up (HOME_OVER), so the wash only just reaches
  the turf there.
- **Test flag:** `--dragon-downwash-test` flies a cloverleaf over the home
  isle, 45 m over its top (`CIRCLE_UP`), out 150 m (`CIRCLE_R`), at most
  24 m/s (`CIRCLE_SPEED`), beating all the time. Attacks are off. Use
  `=glide` to get his own beats and glides instead. He crosses the isle
  about every 25 s. `--dragon-log` now prints the wash's reach on the ground
  and the last gust's lean.

All tuning constants are at the top of `scripts/dragon_downwash.gd`.
`CIRCLE_*` is in `scripts/sky_dragon.gd`.

## Run

```
~/Applications/Godot.app/Contents/MacOS/Godot --path . -- --no-title --dragon --dragon-downwash-test --plane-fixed
```

Add `--fly` to start in the plane. Walk out under him to feel the sail
pressed: jump, then press jump again for the sail. In the plane, climb over
him for the updraft and dive under him for the wash. V cycles the watch
camera.

## Tested vs judged by eye

- Tested headless (`tests/test_dragon_downwash.gd`): the field gives -9 m/s
  under him on the downstroke, -1.4 m/s in the lull, -3.6 m/s gliding,
  +4 m/s above him, zero out past a wingtip, far below, far above and far
  away, a smaller field for a smaller dragon, and nothing when he isn't
  flying.
- Headless game run (`--dragon --dragon-downwash-test --dragon-log`): he
  flies the cloverleaf over the isle and fires ground gusts as he crosses it.
  No script errors.
- **Not verified:** how any of it feels in play (the plane pressed down, the
  sail pressed, riding the updraft) and how the grass, trees and water look
  under the gust. A windowed capture didn't show him over the grass. Nobody
  has played it yet.

## Open questions / next steps

- Tuning by feel: is `DOWN_PEAK` 9 m/s too much for a 14 m/s plane? Is
  `SAIL_PRESS`, `UP` or the footprint too wide or too narrow?
- The updraft is steady. Should it also breathe with the beat?
- The wash ignores his bank and pitch (world-up only). Does it need to tilt
  with him in a hard turn?
- No wash outflow along the ground (the air spreading out sideways under
  him). The foliage gust shows it, but the plane and sail don't feel it.
- `zs_burst_*` is the wind tool's slot (scripts/wind_gust.gd). The aqueduct
  isle has no wind tool, but any scene with both would fight over it.
- Sound: there is no wash cue yet (whump on the downstroke under him).
- The roost dragon's circuit is high over the home isle. If he should be
  ridden there, the circuit needs a lower leg.
