# Underground look: the oculus (round 2)

A look round, not a lock-in. The user liked round 1's lighting (palette, warm key and jade fill) and disliked the textures ("muddy, low quality"). The finding: the muddiest thing was not the sky or roof but the **ground the wanderer stands on**.

    ./run-underground.command --underground=oculus
    ./run-underground.command --underground=oculus --region=2

The log prints `underground: oculus` (checked through the real launcher).

## What was muddy, and why

The start platform is the city landing's pillar top, wearing `shaders/olmec_stone.gdshader`, not the terrain ground. Same stone under torch and oculus: the oculus light only made it tan (warm key plus the start pool at 0.55 x 9). The stone itself was the problem: broad blurry washes (0.7 to 1.2 tone), blob-shaped pits and 0.5 m cracks with no structure, so it read as cracked mud. Stills: `r1_play.png` against `play.png` / `ground.png` / `torch_play.png` (torch is unchanged).

## What changed

- **Crisp stone** (gated by a new global `zs_under_crisp`, 1 only under the oculus preset, in `project.godot` shader globals; torch, haze, the editor and every other look read 0 and are unchanged). `shaders/olmec_stone.gdshader` and `shaders/kit_weather.gdshaderinc`: broad washes held down, dark pits halved, basalt cooled toward grey, and flat tops laid in **flagstones** about 2 m wide: a clean cut joint (about 2 px at any range, so it never shimmers), a lit chamfer beside it, each slab its own tone and tilt, the joint cut into the normal. The kit_weather half is wired the same way but I did not see it exercised in these stills (the start pillar is olmec_stone).
- **The opening** (`shaders/oculus_sky.gdshader`, rewritten): the roof is faceted rock: ribs running out from the opening (log-polar cells with wandering seams) with finer facets cut into each, broad slabs far out, posterised painted washes with clean edges, each facet with its own tone and tilt so the spill picks some and leaves others in true dark. A real **rock throat** (a lobed prism, `throat` m thick, traced analytically): fluted, bedded, catching the key on the side that faces it, with a warm lip and a dark cut where it meets the roof. Through it the **sky has parallax**: opal blue, a thin high veil, and a deck of heaped billows (the opal sea's smooth-max puffs, seen from beneath: bright thin edges, cool shaded hearts, lit rims, rifts onto the blue). Seams and rims are footprint-based and fade out with distance.
- **The mist sea**: the same heaped puffs seen from above, jade creases, pearl crowns, a pale edge toward the key, no gloss or reflection, a haze horizon, warmed under the shafts. Cell 170 m.
- **Shafts at the key's angle.** The opening now stands so the light rakes down the gate's shaft at 40 degrees (`RAKE`), all three shafts follow it.
- **The game's gate beam** (`layer_stage.gd`'s) is laid along the gate's shaft instead of straight up, and faded to alpha 0.12; restored when the preset is off.
- **Start pool**: 0.3 x energy (was 0.55) and a paler colour, so the platform keeps its stone.
- **Going up reads**: the climb is `1 - exp(-((region-1) + closeness) * 0.9)`, continuous within a region (the opening re-places in 20 steps as he nears the gate): it lowers to as little as 40% of its height and widens up to 1.9 x, the cloud deck and throat scale with it, brightness rises 1.5 x. In a plain region 1 walk from start to gate it goes about 0.0 to 0.55 of the way.
- **Far cities** (the user's new idea, `scripts/underground/far_cities.gd`, `shaders/oculus_far_city.gdshader`): 40 small hanging Olmec cities 1.5 to 3.7 km out and at varied heights above the mist: stepped towers on a jagged keel, about 170 triangles each, one MultiMesh and one draw call; they haze with distance and show windows as warm speckles laid after the haze (sub-pixel panes go to their average light so they never shimmer). About a quarter hang upside down or on their side. `--underground-cities=0` turns them off, `--underground-cities_glow=` dims them.

## What I tried and dropped

The real cloud volume (`cloud_volume_*`) was switched on in the abyss as a test: it drew, but its colour and rifts come from the sky world's celestial state (land and ocean seen through gaps, a misplaced tower), so it does not suit an abyss, and it costs a compute march. I used the opal cloud puffs' construction inside the sky shader instead (so: the fallback the brief allowed). The volume's own palette would need the celestial globals driven for the underground; not done.

## Frame cost

`tools/bench_run_layer.gd`, rendered, Apple M5 Pro, 1440x900, `--walk`, sprawl seed 1, 120 frames, wall median ms. Noisy; the torch run in the same session is the baseline.

| view | torch | oculus r1 | oculus r2 |
|---|---|---|---|
| spawn | 31.5 | 30.8 | 33.9 |
| mid | 23.7 | 20.4 | 20.8 |

About +2 to 3 ms over torch at the spawn; draw calls 1282 to 1416 (the same as round 1 plus the one cities call). The sky shader's voronoi taps and the throat solve are the extra.

## Stills

`docs/design/roguelike/underground-oculus-round2/` (committed with `-f`; the repo ignores doc images): `up.png` (from the start, with `r1_up.png`), `gate.png` (from beside the gate, the throat), `wide.png` (with `r1_wide.png`), `sea.png` (with `r1_sea.png`, the cities), `play.png` and `ground.png` (the platform, with `r1_play.png`; `torch_play.png` shows torch unchanged), `region2_up.png`.

## Checks

Headless import and `tools/smoke.py studies/run_layer.tscn -- --shape=sprawl --seed=7 --world=under --underground=oculus`: pass, 0 errors. The launcher printed `underground: oculus`. No tests written or run.

Existing tests I expect to break: none intended (the new global defaults to 0, so the stone shaders render as before); not run, so unverified. `tests` that count `project.godot` shader globals, if any, would notice `zs_under_crisp`.

## Not verified / open

- The roof still reads as a mosaic of facets next to the old mush: crisp but a little tiled; more variety (hanging masses with real depth) would need geometry.
- Joints on the platform show slight stair-stepping on one long diagonal at gameplay range (1 px edge aliasing).
- The start platform is still warm-grey under the warm key; cooler would need the key's saturation lowered (the user liked the lighting, so left).
- The mist sea from the high play camera reads as soft cloud banks; at grazing angles near the horizon it is still plain.
- The far cities are plain blocks, not Olmec-kit towers; they have no collision (they are far) and are not placed to avoid the opening's far side. Their light does not match the key's shadowing.
- Not looked at: the ring shape, a live run through the gate to region 2, the Olmec's light-sight (`scripts/enemies/light_level.gd`) under these lights, the kit_weather path for crisp stone, the editor's motif yard under the oculus.
- The ground cover (`--ground=`) grass and dust skins were not re-judged under the oculus.
