# The crown's silhouette: handoff

Round of 2026-10-30/31 on `claude/mountain-peak-visual-polish-d83e07`, not pushed. After
playing the crown the user said the spires sit on a cake, it looks boxy and castle-like from
some angles, the colour mismatch is weird, and the dark rock is the better one. Trail:
`git log --grep='silhouette:'`. Stills are in the git-ignored `scratch/sil/`.

## What was wrong, from rendered shots

- **The cake:** each plinth was a convex dome topping out near 950 m, and a near-vertical post
  began at its crown, so slope jumped from about 45 to about 85 degrees and colour flipped on
  the same line.
- **The box:** posts of almost constant width, standing upright (the lean came late), with
  setback storeys and blunt tops, round a level crest. Keeps on a curtain wall.
- **The colour:** the towers were already the ground's shader with `rock_tint` 0.2,
  `peak_granite` 0.012 and a deeper height-haze cut. The split was only in those numbers.

## What changed

- **Roots** (`peak_massif.gd`, `ROOTS`, `_roots`): each tower has a long even fall that steepens
  toward its axis, so the mountain's profile only gets steeper going up. Ridges run down each
  root. A root's top leans with its spire, or a second tip stands beside it.
- **Shoulders** (`SHOULDERS`): two ridges down the outer flanks from towers 0 and 2, so the
  outline climbs diagonally into the spires and the block between the gorges doesn't read
  square.
- **The lane** (`LANE`): a col at 872 m through tower 2's root, keeping the strip's +v approach
  open. The shoulder had closed it.
- **The spire** (`peak_tower_shape.gd`, `SPIRE`, `SPIRE_STRAIGHT`): one long narrowing curve,
  1.5 to 0.26 of the girth, and 70% of the lean running straight up it.
- **Lean:** 1.7 times the table (`ROOT_LEAN`). Tips stand 187/153/119 m off their bases, 14 to
  18 degrees. The spirals follow the tips, so their axes tilt more. Their code is untouched.
- **Bases held** (`ROOT_BASES`): the old massif's numbers, so tower height and the spirals' reach
  don't follow the rock that now buries the feet.
- **Colour** (`endless_ground.gdshader`, `peak_basalt`): the massif takes the towers' tint,
  granite and haze cut with height, ragged, from 60 m to whole by 680 m. The tint fades
  geometrically. The haze cut climbs from 120 to 760 m on purpose: over the land's own 300 m
  span it stood as a band round the mountain, whichever way the tint was moved.
- **Far:** the far body's melt widened to 90-640 m. Far towers and body keep `FAR_ROCK`, which now
  matches the near rock, since the near rock moved to it.

The plateau stays flat inside. The strip, apron, stair, lift and spiral code are not touched.

## A/B

`--spire-form=0` the old shape, `--spire-rock=0` the old colour, each alone or both:
`.\run-endless-flight.cmd --spire-form=0 --spire-rock=0`. Both off was shot against the before
frames and matches, apart from the spirals' phase.

## Proofs, final shape, seed 1

| Check | Result |
|---|---|
| Smoke, `endless_flight` and `--world=regions` | pass, 0 errors |
| Rendered, all views | shaders compile, 0 errors |
| `crown_matrix --seeds 1,2` (the wobble) | 24/24 through, 0 crashes, 0 scrapes; wall 20.6 m, floor 13.1 m, seracs 9.4 m, the same as before this round |
| Landings out of the gorges, 3 weights | 6/6 |
| Hand landings along the strip, each way, `peak_land2` | 2/2 |
| Over the rim and down, each way, 2 weights, 4 lines | 15/16 stopped on the plateau, see below |
| Out of the lake between spires at 1040 m, wobble (new, `crown_gap`) | gap 0-1 4/4, least room 56 m; gap 1-2 4/4, 120 m |
| Climb to 880 m | 43/48/52 s, unchanged |
| Heights over the zone | 117,691 sampled, 0 non-finite |
| Strip, 236 x 44 m | 880.000 to 880.000 |
| Gorge floors, half-width + 30 m | 6 of 2,567 points moved, at most 0.52 m |
| Lake, inside r 110 m | 2 points moved, at most 0.79 m |
| Land outside the crown | no height change past 1,272 m from the plateau, flag on against off, apart from the noise below |
| New rock's collider against the field | 355 rays, median 0.13 m, p95 0.74 m, worst 6.6 m (old 5.5 m) |
| Tower solid against collider | 220 rays, mean 1.0 m, worst 13 m (old 38 m), one ray with no solid near |

The land outside the crown is proved by height and by reading the shader (the new term is gated
on the Peak's zone), not by a pixel match against the previous commit.

## Cost

| | Old | New |
|---|---|---|
| All chunks in a load, build time | 30.6 s | 30.8 s, +0.7% |
| `_h_rock` per chunk's vertices, on the crown's rock | 81-88 ms | 96-107 ms, about +18% |
| Tower build, slowest, on a worker | 330 ms | 319 ms |
| Far mesh | 2,856 tris | 3,560 tris |

The +18% is the worst case and only on chunks standing on the roots, so those go from the
handoff's 133-160 ms to roughly 150-175 ms. A bound skips the angle on far vertices but doesn't
help there, since those vertices really are on a root. It's a few lines for the C++ port.
Frame time wasn't re-measured.

## Tests

No test under `tests/` names the massif or the towers, so a grep finds none this breaks. The
suite was not run, as agreed. `test_sky_peak_look.gd` and `test_sky_sea_peaks.gd` are about the
sky's own peaks (`shaders/sky_peak_look.gdshaderinc`), which this round didn't touch.

## Still weak

- **The spiral hides the join.** The biggest coil sits on it from several sides, which flatters
  the shape. With `--spirals=0` the join still reads well (`scratch/sil/join.png`).
- **Over the rim, heavy:** one low line (a 120, 26 m over the strip, Brake held from the start)
  cleared the ridge and sank into the 820 m hollow behind it. The old shape didn't. At 40 m over
  it lands on both weights. No crash; the plane stops on rock short of the plateau. The driver
  flies this line badly, so a hand should test it.
- **From the front** (`front.png`), the block between the gorges is much better but still the
  biggest shape, with a short level top between towers 0 and 2 over the strip. Going further
  means changing the gorge ridges or closing the lane, and both are to stay.
- **Near, in full sun,** the root's brown is warmer than the spire's near-black. The join is
  fine, but the two surfaces still differ: root rock is jagged and spire faces are smoother.
- **Sawtooth rock relief** on the roots reads a bit spiky up close. It is the existing relief on
  more steep ground; not touched.
- **Tower 2 from inside the crown** still rises off the flat floor on that side. That's the
  plateau, kept flat as asked.
- **A tower's foot fins** stand past the root on tower 0: 50 of 405 ground rays hit them. They are
  drawn and solid, so it's a shape note, not a bug.

## Not verified

- Motion: nobody has watched this moving, nor flown it by hand. The flight proofs are the bot.
- Dusk, night and other hours: stills are at the default hour only.
- The spirals against the leaning spires over time; stills only.
- Frame time and hitches, near the crown or anywhere.
- Flags at the summit and lake, and spindrift off the moved tips: they read the towers' own
  numbers and smoke passes, but none was looked at closely.

## Found, not caused

`field.height` differs between two runs of the same build and flags at a handful of points far
outside the crown: 10 of 117,691, at most 2.7 m, near a 5040. It moves between runs. Worth a look
because the land is meant to be one fixed seed.

## `docs/art/model-budget.md`

The towers changed shape; triangle counts did not (129k at full detail, levels 43,200 / 10,848 /
2,736 / 696 / 180 a tower).

| Trick | Applies | Estimated saving |
|---|---|---|
| Trim what the roots bury | New, the real one: about 40% of each tower's rows now lie under the root | About 50k of 129k tris at full detail, about 400 at the far level; under 0.1 ms a frame by estimate, since LODs already cut most of it. Worth doing once the shape is final. Keep a margin, since a layout move can shift a tower |
| Import LODs | Already in, 5 authored levels | None further |
| Silhouette geometry | Already the method: arêtes and breaks are real | None further |
| Vertex-colour grime | Already in: beds and shade in vertex data | None further |
| Sculpt high, bake low | Possible on spire faces, which read smoother than the root; a normal bake would help the look more than the count | 20-30k tris if level 1 became level 0; about 0.1 ms; an art round, not now |
| Parallax depth | No: faces are seen from hundreds of metres | None |
| Rigid parts on bones | No: nothing is skinned | None |

## Next

Per the crown handoff: the chunk pass in C++ or baked, now the shape is final if the user agrees,
then the rest of step 7. The far views at 6-16 km from every side were looked at here and hold
up. `crown_views.gd`, `crown_far.gd` and `crown_gap.gd` in `scratch/` are worth carrying forward.
