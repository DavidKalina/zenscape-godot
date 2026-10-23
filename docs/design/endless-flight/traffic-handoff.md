# Other planes in the endless sky: handoff

## What it does

`scripts/endless/endless_traffic.gd` (`EndlessTraffic`, a subclass of
`scripts/sky_traffic.gd`; the isles' traffic is unchanged) flies 3 AI
biplanes round the player over the endless land. They use the isles'
liveries, steering, banking, wander and tricks (rolls, loops, swoops).

- **Plans** (`_spawn`): each plane comes in from the haze 1–1.3 km out.
  - A **cross** (50%) comes in from 550–700 m to the side and is aimed to
    cross the player's line 110–260 m ahead of where he'll be. While it is
    over 380 m away it re-aims, so the cross still happens if he turns.
  - A **pass** (20%) comes head-on from far ahead and goes by 95–170 m to one side.
  - A **cruise** (30%) flies across the land somewhere off to the side.
  - After its plan, each plane cruises from valley to valley: it picks the
    lowest of 5 points 500–900 m ahead.
- **Recycling**: a plane is put away when it is over 1.7 km away, or when it
  is behind the view and going away (over 650 m, or for 25 s). It comes
  back on a new plan after 3–14 s.
- **Ground**: it reads `LandField.height` (not physics) up to 450 m ahead
  and climbs early. It is asked to keep 30 m over the ground, minus 0.2 m
  for each metre further out. A hard floor keeps it 7 m over the ground
  right under it. This is the base's `_fly` with that one line changed: the
  base floor used the ramp, which made planes pop upward.
- **Player**: when its line would pass within 110 m of him in the next
  12 s, it steers up or down and aside. It is never nearer than 55 m (a
  hard push). Visual only, no collision.
- **On foot** (`_foot_tick`): the planes keep flying. The eye stands in for
  the player and the view for his heading, so crosses still pass over and
  in front of him, about 30 m up.
- **Trail** (`Trail`): one camera-facing `ImmediateMesh` ribbon per plane,
  rebuilt each frame from samples laid off the tail every 0.2 s.
  - It lives 10 s, widens from 1 m to 9 m (at plane scale 2) and fades.
    Far off it is never thinner than about 1.5 px.
  - One shared unshaded material, fogged. Its tint is the mood's sun and
    ambient light, pulled toward white.
  - Hard banks pull the figure's own wingtip vapour.
- **Cost cuts**:
  - Beyond 260 m from the eye a plane is only posed (`FarPose`): no pilot,
    scarf, vapour, prop or control surfaces.
  - Beyond 140 m it casts no shadow.
  - The ground is read every 0.15 s.

## Flags

`--traffic=0` off, `--traffic=N` planes (default 3, at most 8),
`--trails=0` no trails. F1 (`--numbers`) adds a `traffic:` line: planes
up, CPU ms, spawned, recycled.

## Cost

Measured on this Windows PC, rendered at 1440p, `--uncapped`, seed 1.

| Case | Draw calls | CPU per frame | Frame time |
|---|---|---|---|
| `--traffic=0` | 824 | – | 11.9 ms |
| Normal flight (2 planes in view at about 400 m) | 852 (+28) | 0.27 ms | no change |
| All 3 planes within 250 m | 903 (+80) | 0.49 ms | no change |

Before the far pose and the shadow cut, 3 near planes cost 0.75 ms and
+370 draws. A full-detail figure update is about 150 µs per plane, and the
ground read was about 36 µs per plane before it was cached.

## Proof (throwaway, scratch/)

- `traffic_fly.gd` flies 4 minutes headless with 4 planes and real stick
  turns:
  - 12 spawned, 9 recycled, 10 came into view ahead (within 30° and 700 m).
  - Closest to the ground: 9.8 m. Closest to the player: 55.5 m (one
    cruise drifting alongside after its cross).
  - No script errors.
- `traffic_film.gd` / `traffic_foot_film.gd` take rendered stills of a
  forced cross (`EndlessTraffic.force(n, plan)`).
- Stills in `captures/shots/`:
  - `traffic_cross_crops.png`: chase view, a plane crossing ahead with its
    trail, another trail on the left.
  - `traffic_chase_sheet.png`: the full chase frames.
  - `traffic_ground_sheet.png`: from the meadow on foot, a plane crossing
    over with its trail.
- Smoke passes flying, `--on-foot`, `--traffic=0` and `--traffic=6 --trails=0`.

## Weak spots

- The planes are the game's true size, so past about 200 m a plane is a
  speck and the trail does the reading.
- A cross takes 30–40 s from spawn to the crossing.
- The base's heading wander (±0.4 rad) makes crosses curve.
- The trail is a flat ribbon. Seen end-on it thins to a line. Clouds do not
  hide it the way they hide solid things.
- Very steep faces can still bring a plane down to about 10 m over the
  ground before the climb catches up.
- A cruise can drift alongside the player at 60–80 m.
- On foot, the walker camera looks down, so planes cross high in the frame
  or above it.
- No cloud pass-through (`cloud_near`) for the endless clouds yet.
  `cloud_wakes.gd` is not hooked up.
- Planes recycle by distance only, so a plane can pop in or out at about
  1–1.3 km in thin haze.

## Next

- Fade a plane in and out with distance instead of popping it.
- Fly through the endless clouds and tear wakes in them.
- Add a formation plan (2–3 planes together).
- Let the player join up with a plane or chase it as a flying challenge.
