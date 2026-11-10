# The whale

A prototype round (2026-11-10), not locked in: no committed tests. One whale
in the open sea, staged ahead of a plane skimming deep water. Built as a mind
and a body joined by the contract below (skill `enemy-build`), both in one
round.

- Mind: `scripts/endless/whale.gd` (the spawner, the staging, the water, the
  near miss). The study holds it as `whale` and steps it once a frame.
- Body: `scripts/endless/whale_body.gd` on `assets/models/whale/whale.glb`,
  built by `art/blender/whale/whale_build.py` (skin: `whale_skin.png`,
  `shaders/whale_skin.gdshader`).

## Try it

    .\run-endless-flight.cmd --whale-now

Fly out over deep water, low (under 35 m) and at cruise or faster. Two
seconds later a blow goes up 360 to 760 m ahead. `--whale-now` repeats every
25 s of flight. Without the flag it is rare (below).

## What happens

Times are the clip's (s). The clip runs 0.6 to 1.7 times as fast until
`fluke.up`, so the flukes stand as the plane arrives.

| Beat | t | What shows |
|---|---|---|
| `blow` | 0.4 | A mist column about 25 m tall off the blowhole; the head awash. |
| | 0 to 3 | The sea's hump, slick and dark shade over the body (the lake fish's `swimmers` slot). |
| `back.show` | 3.0 | The back breaks the surface; a second, smaller blow at 3.4. |
| | 3 to 7.5 | The back rolls through, about 4.5 m proud, foam laid along it. |
| `fluke.up` | 7.5 | The tail stock arcs up, water sheeting off the flukes, spume at its foot. |
| `fluke.top` | 10.0 | The flukes stand: see Size. |
| `fluke.slide` | 12.0 | It slides under; rings run out from 13.5. |
| `gone` | 15.0 | Under. The clip ends at 16.0; foam and rings fade on their own. |

## Size

A giant: 56 m nose to tail stock, flukes 26 m tip to tip (9.3 wingspans).
At `fluke.top` (measured at 10.6 s) the flukes' root stands 9.4 m over the
water and the tips 19.4 m, 25 m apart; the tail stock is about 3.5 m thick
fore and aft and 2.5 m across where it leaves the water. Under each fluke,
between the tail stock and the tip, the gap is about 11 m wide and 8 m high at
the stock's side, rising to 18 m under the tip. From 8.5 s to about 13.5 s the
tail is over 8 m up: 5 s to pass it.

## Rarity and flags

Constants at the top of `whale.gd`; each has a flag for a run.

| Knob | Default | Flag |
|---|---|---|
| Flight time between whales | 600 s | `--whale-cooldown=S` |
| Flight time before the first | 150 s | `--whale-first=S` |
| The roll once the plane has been 8 s low over open sea | 0.35 | `--whale-chance=P` |
| Open-sea time after a lost roll | 45 s | `--whale-retry=S` |
| Off | | `--whale=0` |
| The first after 2 s of open sea, every 25 s | | `--whale-now` |

Open sea for the plane: flying, under 35 m over the sea, at 0.75 of cruise or
more, the bed 20 m or more down. The spot: where the plane will be in 11 s
(360 to 760 m), 12 to 26 m to one side, the whale heading within 0.3 rad of the
plane's way. `_site_refusal` turns a spot down for: water under 20 m deep
anywhere on rings out to 450 m, the edge's big swell able to rise over 6 m
there, stone in the whale's lane, a pirate ship within 600 m, land or stone
between the plane and the spot. `refused` holds the last reason.

On the default world about 70 cells of a 250 m grid are fit (4 km² of sea):
the outer sea is the edge's swell belt (up to 22 m), so the whale keeps to the
calm inner sea. `SURGE_MOST` and `RINGS` are the two knobs that widen it.

## The contract

- **Clip**: `dive`, 16.0 s, not looped, root motion in the clip. Its frame:
  the origin on the still water where the tail stock goes under, -Z the way
  it swims. Beats as in the table (`WhaleBody.BEATS`; markers in the .blend).
- **Sockets** (bones): `blowhole`, `root` (chest), `lumbar`, `tail1`, `tail2`,
  `tail3`, `fluke` (the flukes' root), `tip_l`, `tip_r`.
- **Shape**: `LONG` 56, `FLUKE_SPAN` 26, `STOCK_R` (2.4, 1.7, 1.1) at `tail2`,
  `tail3`, `fluke`, `LOBE_R` 1.4, `BACK` 5.
- **Effects**: `sheet` (0 to 1, water running off the skin), `surface_y`
  (the water's level; under it the skin dims).
- **API**: `play()`, `advance(seconds)`, `time()`, `done()`, `stop()`,
  `socket(name) -> Vector3`, `set_effect(name, value)`, `whole()`.

## Water

- The sea's own sheet draws the body under it and the white lip where it
  cuts the surface. Its `swimmers` slot (the lake fish's) gives the hump, the
  slick and the dark shade; `swim_body` 0 (new uniform, default 1) tells the
  shader the whale has a mesh of its own.
- Foam and rings are WaterContact marks through a new `mark(at, ring, k, from,
  to, life)`; the blow, the drops off the flukes and the spume are three
  emitters on the plane's spray shaders, capped at 160, 500 and 60 particles.
- Under a fluke that still sheds, the screen is doused once a pass
  (`WaterContact.douse`).

## Passing it

No collision: the plane flies through the tail. The tail is measured as four
capsules off the sockets, and a pass within 2.5 wingspans scores as a graze
through `NearMiss.shot_pass` (the cannon ball's path), once per pass.

## Cost

Measured on the Windows PC, the study's own tick, rendered, Full preset.
Waiting: a countdown a frame and one `field.height` every 0.5 s. Staging a
spot: 0.9 to 1.4 ms, once. Up: 0.08 to 0.10 ms a frame on average, 0.6 to
1.4 ms at worst, for 16 s. GPU cost (6.9k triangles skinned on 13 bones, at
most 720 particles) was not measured apart from the frame.

## Not done, not verified

- No sound (the blow, the tail's water).
- Not hand-flown: every run was driven. Not measured with `--frame-log` on a
  flown flight.
- The edge's swell rule only acts once the sea's shore map has loaded; the
  seed sweep ran headless, where the sweep waited for it.
- Doors, shops and finds in the water are not asked for by name; the depth and
  stone rules are what keep the whale off them.
- A lake fish staged while the whale is up shares the `swimmers` slot: one of
  them loses its hump and shade for that time.
- The near miss measures a fluke as a 1.4 m capsule down its middle, so a pass
  under the trailing edge reads up to about 2 m wider than it was.
- The flat foam and ring marks cut into tall swell, as the plane's own do.

## Also changed

- `scripts/endless/water_contact.gd`: the marks' culling box grown from 4 km
  to 16 km about the middle. The plane's own foam and rings were culled past
  4 km out (the world's edge is 9.5 km from its middle).

## Existing tests

None run (prototype round). None is known to break: the whale is off the
land, has no collider and stages only after 150 s of flight.

## Tools

`tools/shot.py --sheet-of` writes a relative `--out` against the repo root
whatever the working directory. The first `shot_at` of a run drew the body
under water as a flat pale shape; a throwaway first still cured it.
