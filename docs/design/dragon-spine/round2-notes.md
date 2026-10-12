# Dragon motion, round 2 (notes for a future round, 2026-10-12)

> Not started. What the user noticed after playing round 1
> (docs/design/dragon-spine/round1.md). Read that handoff first.

## 1. The wingbeat isn't continuous

The wing cycle visibly snaps when the wings reach the top of the
upstroke: the pose resets rather than flowing into the next downstroke.

Starting points, unchecked:
- `phase` wraps with `fposmod(phase+delta*hz,1.0)` in scripts/sky_dragon.gd
  (the flight step). The wrap is fine if every pose curve driven by `phase`
  is periodic. Look for curves whose value or slope at phase 1.0 doesn't
  match 0.0 (piecewise downstroke/upstroke shapes, eased segments, the wrist
  fold, the tip lag).
- Something keyed to the wrap: `_bout_left` counts on `phase < before`; the
  beat-driven springs in scripts/dragon_spine.gd may get a kick there.
- The beat rate `hz` changes with climb (BEAT to BEAT_CLIMB); a curve
  that uses time rather than phase would jump against it.
- The flap/glide blend (`flap_w`) and the "settle the wings at phase 0"
  rule while the flapping fades.

Done when a frame-by-frame capture across several beats, from the side and
from above, shows no step at the apex, and the wing tips trace a smooth
loop.

## 2. He clips into things

On the rim cling and when he flies low, his body, wings, tail or head pass
into turf, rock and ruins.

Starting points:
- The cling already lifts the head out of the turf and has a chin box
  (`_clear_turf`, `_place_chin`, the `sky dragon:` log's "head in the turf"
  numbers). Extend the clearance to the wings, the legs/claws and the tail
  rope, not only the head.
- The tail is a verlet rope: give its points a turf/ruin probe and push
  them out.
- Low flight (the vision greybox's `--vision-low`, low passes, the future
  low swoops over an isle): keep the wings and the body above the ground
  under him, either by holding his height over the turf or by folding and
  lifting the wings near the ground.
- Round 1's springs add motion (legs swing, the neck wave, the tail
  following the hips) that can carry bones further into geometry than
  before.

Done when captures of the cling (`/tmp/dragon_spine/cling/` was round 1's)
and of a low pass show nothing passing into turf or stone.

## Carried over from round 1's open points

- The bend in turns is modest; raise `TURN_*` in scripts/dragon_spine.gd.
- No roll twist along the spine: the bank still looks rigid.
- The climb hasn't been captured.
- The neck's beat wave may be too big up close.
- In a held dive the head still reads as pointing down.
