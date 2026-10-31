# The climb at the Peak: handoff

Round of 2026-10-31 on `claude/mountain-peak-visual-polish-d83e07`, not pushed. The user, after
playing: slowing to a crawl going up, and not reaching the spire clouds, is a design flaw; undo it.
Now every weight climbs the whole mountain at the speed it climbs off the sea, and flies over all
three tips and through the spirals.

## The cause

The thin-air band started at 215 m over the sea, under the whole mountain, so all of the Peak was
in it. By 600 m the nose was limited to about half its pitch and speed sat at 28 m/s (18 without
Boost), and the band's top stopped Medium near 1175 and Heavy near 1100 m, under every tip (1335 to
1480). I found no other cap: none over terrain, none in the camera, none in the logbook (`highest`
is unclamped).

## What changed

- `land_field.gd`: `THIN_OVER` 215 to **1700**, `CEILING_OVER` 1520 to **2100**. The band starts
  220 m over the tallest tip. Below 1700 the plane flies by the low-level rules, nothing else.
- `flight_weight.gd`: the `ceiling` and `reach` shares are unchanged; they now give flown tops of
  2100, about 1995 and about 1970 (light, medium, heavy). Only the doc changed.
- `sky_plane.gd`: `use_thin(from, top, eased)`, `thin_ease`, `_thin_swing()`. In the new band the
  cost comes in by `thin`, not its square root. With the square root the plane hit a wall at 1700:
  51 to 27 m/s inside 4 s.
- `endless_flight.gd`: `--climb=old`, and the launch picks the band. `--ceiling=m` under 1700
  still thins from 215 as before; `--old-land` is unchanged.

Other land and the amberlands use the same numbers, so between 215 and 1700 they lose thin air too.
Nothing reads `plane.thin` outside `sky_plane.gd`. The thin air's job was a soft top, so the plane
doesn't run on upward; it still does that, higher. The gorge's lift is untouched.

## A/B

`.\run-endless-flight.cmd --climb=old` is the old climb. A 100 s medium run matched the before
table exactly at 500, 900 and 1100 m.

## Numbers, seed 1, by stick with a wobble (`scratch/climb_table.gd`)

Full back from 250 m over the sea, away from the Peak. Speed / rise, m/s. "-" is never reached in
130 s.

| Boost | 400 m | 800 m | 1200 m | 1500 m | 1700 m | 1800 m | 1900 m | 1500 m at |
|---|---|---|---|---|---|---|---|---|
| light, before | 28/23 | 28/10 | 28/6 | - | - | - | - | - |
| light, after | 50/46 | 51/47 | 51/47 | 51/47 | 51/47 | 37/42 | 27/17 | 27 s |
| medium, before | 27/21 | 28/8 | - | - | - | - | - | - |
| medium, after | 50/46 | 50/47 | 50/47 | 50/47 | 51/47 | 34/41 | 26/13 | 27 s |
| heavy, before | 26/20 | 28/8 | - | - | - | - | - | - |
| heavy, after | 50/45 | 50/47 | 50/47 | 50/47 | 50/47 | 32/40 | 26/11 | 28 s |

| No Boost | 400 m | 800 m | 1200 m | 1500 m | 1700 m | 1800 m | 1900 m | 1500 m at |
|---|---|---|---|---|---|---|---|---|
| light, before | 18/9 | 18/4 | - | - | - | - | - | - |
| light, after | 30/28 | 30/28 | 30/28 | 30/28 | 30/28 | 17/18 | 18/6 | 46 s |
| medium, before | 18/8 | 18/3 | - | - | - | - | - | - |
| medium, after | 30/28 | 30/28 | 30/28 | 30/28 | 30/28 | 16/16 | 18/5 | 46 s |
| heavy, before | 18/8 | 18/3 | - | - | - | - | - | - |
| heavy, after | 30/28 | 30/28 | 30/28 | 30/28 | 30/28 | 15/14 | 17/4 | 46 s |

On a 0.5 rad line (a pilot's climb, not full back) at 1500 m: 54 m/s with Boost, 33 without, on
every weight; before, 28 and 18 by 800 m. Under 1700 weight changes the climb by a m/s or so. It
still shows in the top and in how late the path follows the nose.

## Proofs

| Check | Result |
|---|---|
| Tour (`scratch/spire_fly.gd`): from 50 m over the front, a climbing lap through each spiral, then over each tip | Light and medium, Boost and none, 8/8; heavy with Boost 2/2. 0 scrapes, 0 crashes. Slowest 37 m/s with Boost and 29 without, mean 54 and 34 |
| The same, heavy, no Boost | First pass 2/5 (2 crashes, 1 timed out): all reached tips 0 and 1, then the bot's line from tip 1 to spiral 2 clipped a tower. With a guard added to the bot, 5/5, slowest 28 m/s, least room 16 m. A driving flaw, but a hand may find that line tight on heavy |
| Over the tips | Every tour passed each tip 28 m or more over it (1508, 1423, 1363 m) |
| `crown_matrix --seeds 1,2` wobble | 24/24, 0 crashes, 0 scrapes; wall 22.6 m, floor 11.6 m, seracs 11.5 m (was 20.6, 13.1, 9.4). Mean speed 36 to 57 m/s |
| Gaps between spires, 1040 m | 8/8, least room 56 m and 120 m, the same as before |
| Landings out of the gorges | Rock 6/6 greasers. Ice as the bot flew it, see below: light and medium pass, heavy lands on the plateau past the bot's limit. With a steeper final nose, ice 6/6 greasers |
| Strip landing, by hand's line | 2/2 |
| Low flight (`scratch/low_flight.gd`, each weight) | Cruise, turns, pull, push, Boost, Brake, stall floor and the start of the skim: identical to 3 decimals, before against after, over the first 20 of 24 rows. Light is identical to the end. The last rows of medium and heavy differ a little, and so do two runs of the same build (the height noise the silhouette round found) |
| Smoke | `endless_flight`, `--world=regions`, `--climb=old`, `flight_study`: pass, 0 errors |
| Rendered, 1650 to 2080 m | Stills only, see below |

## Landing on the plateau changed

This is the one real change a hand will feel besides the climb. The old thin air sank a slow plane up
to 3 m/s more on the plateau. Now it lands as it does anywhere else, so a flat flapped approach
floats. Holding the old shallow nose (0.1 rad), heavy took about 50 s to come down and landed far
along, at the bot's aim near the lake; one ice medium run didn't get down in time. Nose down a touch
more (0.22) and ice is 6/6. Also, Boost at the saddle now means 56 m/s, not 28, so Brake earlier
than the crown handoff's recipe.

## Tests

No test under `tests/` names a ceiling, thin air or `use_thin`. Passing headless: test_sky_plane,
test_knife_drift, test_glide_camera, test_flight_metrics, test_flight_study, test_world_scale_guard.
`test_cloud_shade_steady` is a GPU test, so it's unverified. Nothing I know of breaks. The full suite
was not run.

## Looks, from stills at 1650, 1950 and 2080 m

Sky, haze, horizon, far land and spirals all hold, and the crown from above is a strong view. No
break in the cloud or the land showed. Weak: the cumulus reads as soft tan blobs from over the slab
(its top is 1250 m), and in the 1950 m shot over the land a thin straight pale line runs under one
cloud, not traced. These heights were mostly out of reach before (medium's old top was 1329).

## Still weak

- **The soft top.** Full back gets pulled down from about 1800 m, 51 to 27 m/s by 1900. It sits
  320 m over the tip. A plane climbing right up to look down will feel it.
- **The climb is very strong.** 47 m/s up at 69 degrees on every weight: 1500 m in 27 s from 250 m.
  The gorges are now a choice, not the way up. That's what was asked; the user may want a little
  cost back.
- **Weight barely shows in a climb.** If that's missed, a small per-weight cost is the place.

## Not verified

- Nobody has flown it by hand. All flight proofs are a bot on the real stick.
- Motion: the land's LOD rings coarsen together on a climb, now several times faster. Pop-in and
  frame time on a fast climb were not measured.
- Dusk and night at height. The second world only by smoke.
- Riding the gorge lift by hand at the new speeds; the bot's wobble runs pass.
