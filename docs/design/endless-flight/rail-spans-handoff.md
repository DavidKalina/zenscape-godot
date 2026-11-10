# The railroad's spans: handoff (lane `rail-spans`, 2026-11-10)

On `lane/rail-spans`, off `iter/railroad` (with the steam train). One file
rebuilt, `scripts/endless/rail_span.gd`, and a timber shader.

## The kinds, by rule (per span, from the line and the land under it)

- **Stone arch bridge** (`ARCH`): half or more of the span is the line's
  "bridge" and its deck stands under `VIADUCT_FROM` (18 m) over the water.
  Round arches about 9 m clear on cutwater piers, sprung under the banks where
  the land is high; ring bands proud of the spandrels, string course, parapets.
  The 16 creek bridges.
- **Timber trestle** (`TRESTLE`): the rest under `TIMBER_MOST` (62 m). Bents of
  four posts (outer two battered 1:6) on stone pedestals, a stone cutwater
  pier under a bent standing in water; a cap, girts on both faces every tier
  (10 m), sway braces in the outer bays; stringers under a plank deck with a
  handrail. From `TOWER_FROM` (16 m) the bents pair into towers 7 m apart,
  braced along the line on every row, with an open bay between towers. The
  mine trestle, the shore, west, mine-town and bay trestles.
- **Stone viaduct** (`VIADUCT`): half or more over water and 18 m or more over
  it, or any span 62 m or more tall. Battered piers with cutwaters that rise to
  the parapet as pilasters; round arches; in each pier a gallery along the
  line under the springing, an arcade between piers under it whose top is the
  gallery's floor (only over a fair 8 m opening), then the next pair down while
  they fit. The bay bridge, approaches included.

## The openings (WorldScale.opening, so they scale with the plane)

| Where | Size |
|---|---|
| Trestle corridor along the line, between the inner posts | 8 m wide (`TOY_BAY` 4) x 9.55 m per tier |
| Trestle open bay across the line, between towers | about 17 m (`TOY_OPEN` 8.5) x 9.55 m per tier |
| Trestle top tier, under the deck | the same, cap to first girt |
| Low trestle bents across | about 9 m (`TOY_PLAIN` 4.5) |
| Viaduct gallery through each pier | 8 m x 12 m (`TOY_PASS` 6), round head |
| Viaduct arch over a gallery floor, across | about 26 m wide at the bay |
| Viaduct arcade, across under it | 8 m tall or more, or no arcade |
| Creek arch | about 9 m wide, as tall as the bank leaves (2 to 3 m) |

## Honest: one shape for the eye, the collider and the flight

Every member is a convex hull of two matching rings of corners. Its drawn
faces are its mesh and (per 64 m piece, within 120 m of the plane) its
concave collider on layer 1; its face planes answer `ground`, `inside` and
`land_y` through `_hull_y`, clamped to its box grown by the pad. Hulls are
found through a grid of 4 m cells in (s, d). The deck and abutments answer as
before; the parapet or handrail adds 1.1 m over each edge.

## See it

- Mine trestle: `python3 tools/play.py --no-pull -- --no-title --pilot-file=/tmp/rail.json --at=-4669,105 --alt=30`
- Bay viaduct: `--rail-start=bridge`, or `--at=-280,1000 --alt=-20` (the crest, galleries)
- A creek bridge: `--at=-2777,-3199 --alt=4`

## Numbers

- 24 spans: 16 arch, 7 trestle, 1 viaduct; 13,263 members; 231k triangles near,
  193k far. Built at load in about 0.9 to 1.7 s (was 0.12 s).
- Frame cost, headless, A/B with the old file on a quiet machine, 6 m over the
  deck and beside the bay: median +0.1 to +0.4 ms, p99 within noise (old 13.5 /
  16.1 / 13.0 ms, new 14.1 / 15.9 / 13.5). A flight answer costs 10 to 15 us.
  GPU unverified.

## Weak still

- Stone in full shade reads dark brown on the shaded side.
- The tall viaduct's stacked arcades read as a grid; the creek arches are low.
- Abutments are plain blocks; the far trestle drops only the handrail details.
- Load time up about a second.

## Not touched

No route, tunnel, car, station or test changes. Shared: a `ZS_TIMBER_GRAIN`
hook in `shaders/folk_surface.gdshaderinc` (off unless defined).
