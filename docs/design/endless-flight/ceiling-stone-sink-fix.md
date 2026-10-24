# Fix: the plane sank into land standing over the ceiling

The bug: land standing over the plane's ceiling fade (175 to 200 m world by
default; the test massif's top is about 275 to 284 m) let the plane sink into
the rock and fly on inside it.

## What happened

Reproduced at seed 1 with `--world=overgrown --tunnel-test`, flying at the
massif's middle at boost, stick held up. The plane rides up to the crest flat
and the skim counts as a touch, so it lands hot and rolls. When it lifts off,
the unstick (`scripts/manual_landing.gd` `_heavy`) sets its height from
`speed * sin(pitch)`. Over the ceiling the nose is pinned at `CEILING_NOSE`
(-0.05), so that height ran down about 2.2 m/s straight into the land. Back in
the air, the stone rule in `scripts/sky_glide.gd` `_skim` measured the rise
from `was.y`, which was now under the skim band, so the rule failed.
`_brush`'s fallback, `was`, wasn't "out" either, so nothing ever lifted it.
The plane went 14.7 m into the land, and was still sinking when the run
ended.

## The fix

- `sky_glide.gd`: a new `_lifted(ground, was)` gives where it was, raised to
  SKIM over the land there (not if it was under that solid's underside). The
  stone rule measures the rise from that height, and `_brush`'s last fallback
  is that point. A step that starts too low (held low from outside, or
  anything else) can never sink on through. A cliff still turns it aside:
  the fallback is the ground at `was`, never the face's top.
- `manual_landing.gd` `_heavy`: the unstick never holds the plane under the
  land (`floor_at` plus `PlaneStrip.contact`). Over the ceiling it runs on
  along the land.

Steps that start at or above the skim band behave exactly as before.

## Checks (headless, uncommitted throwaways in scratch/tunnel/)

- `flank.gd` (stick held up and steered at a point). Before the fix, the
  crest flat at boost: 2484 frames inside, deepest 14.7 m. After the fix,
  0 frames inside for all of these: the crest flat at cruise and boost; the
  massif's top (275 m) at boost from 3 sides and at cruise; boost with the
  stick held straight; another stretch of the massif; and a wilderness peak
  over the ceiling (default world, 188 to 200 m) at cruise and boost.
- `over.gd` (the original path autopilot) at cruise and boost: clear
  0.9 m at the least, never inside. It stays turned along the face as the
  driver steers it back in, which is fine.
- `bore.gd --boost`: through in 36.7 s, 0 brush, 0 rock frames (unchanged).
- Smoke: `--world=overgrown --tunnel-test`, `--world=overgrown`, and the
  default world all PASS, 0 errors.
- Tests: these pass: test_sky_plane, test_glide_camera,
  test_manual_landing, test_kit_isle_landing, test_isle_lodestone,
  test_sky_sea_peaks, test_sky_dive, test_sky_islets and
  test_aqueduct_isle_sail. test_aqueduct_isle_plane fails "R3 puts the
  camera back behind the pilot at the default pitch" the same way without
  this change (it was already failing).

## Left open

A plane landed on a flat over the ceiling can't climb away: the nose stays
pinned to -0.05, so it runs along the flat and off its edge. A ceiling
measured from the land under the plane would let it climb away. That is a
design call for the user.
