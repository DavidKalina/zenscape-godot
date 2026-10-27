# Storm front (handoff)

A storm front sweeps across the endless land, as spectacle only. The plane flies bit for bit the same with it on or off. It is off by default. This is a prototype: smoke checks, throwaway drivers and stills, no committed tests. Spec: `spec-storm-front.md`; trail: `git log --grep='^ITER(storm-front)'`.

## Play it

```
.\run-endless-flight.cmd --storm-start                 # Windows
./run-endless-flight.command --storm-start             # Mac
.\run-endless-flight.cmd --storm-start --night=1       # at full night
.\run-endless-flight.cmd --storm-start=-1500           # start under the core
```

`--storm-start` puts the front's leading edge 3.5 km ahead of the start, its middle on your line, coming toward you at 15 m/s with the wind. Flying at it, you're under it in about a minute. `--storm-start=M` puts the edge M metres ahead (negative: already passed over you). `--storm` turns it on without placing it; `--storm=0` is the same as no flag.

## What you see

- **From far (5 to 10 km):** the field's own cumulus in and ahead of the front swells, merges, sinks its bases and darkens, keeping the field's texture. Three baked cumulonimbus towers rise in 12 stages along the core, far above the flight ceiling, visible from 10 km. Rain curtains hang under the base; lightning flickers inside.
- **Growing:** the storm builds over `GROW` = 60 s from 10% (`--storm-grow=S`, `--storm-grow-from=F`); storm cells boil faster than fair-weather ones (`--storm-churn=X`).
- **The gust front:** a band 800 m ahead of the edge flattens grass in waves, bends trees, roughens the sea and lakes with whitecaps and spray, scatters flocks, and brings a roar.
- **Enveloped under the core:** a heaped, side-lit deck drops toward the plane, dark scud whips past at plane height, rain murk closes the distance. The light greys, rain streaks past and beads on the lens, rain pocks the water, the sound muffles under a rain bed, the meadow hushes.
- **Lightning:** bolts strike near the plane, preferring a ruin piece (it breaks through the existing breaks; the struck arch's flight solid is rebuilt from what stands and its rubble freed), then a tree (knocked), then a hilltop. The flash lights the land and the cloud base; thunder arrives late by distance (343 m/s). Strikes never hit the plane.
- **Behind:** the back tears into tongues with blue gaps; the land it rained on stays dark, a little glossy and puddled on flat meadows, drying back over about 4.5 km (about 5 minutes). Ground and landing are untouched.
- **Night:** flashes light the land for an instant and drop it back to a dark but flyable murk; no stars through the storm.

Meadows under the core are landable by day and night (checked through the play loop).

## Flags

- Place and pace: `--storm-start[=m]`, `--storm-speed=X`, `--storm-length=X` (10 km), `--storm-debug` (d, amount, rain, gust at the plane in the HUD notes).
- Look knobs: `--storm-grow=S`, `--storm-grow-from=F`, `--storm-strength=F` (hold the growth at F), `--storm-churn=X`, `--storm-sun=X`, `--storm-gloom=X`, `--storm-envelope=0` (no deck, scud or murk), `--storm-murk=X`, `--storm-scud=X`, `--storm-deck=X`, `--storm-towers=0..3`, `--storm-tower-scale=X`, `--storm-tower-widen=X`.
- Strikes, for stills and checks: `--strike-at=F` (one forced strike F frames in; the automatic ones stop unless `--strike-auto`), `--strike-kind=ground|far|inside`, `--strike-range=m`, `--strike-bearing=deg`, `--strike-ruin` (the forced one takes the nearest ruin), `--strike-hold=s` (frozen into its flash), `--strike-log`.
- Cost: `--cloud-cost-view=M.G` compiles a separate march version with counters (mode, gain).

## Where it lives

- `scripts/endless/storm_front.gd` (`StormFront`): the line, its bands (gust, shelf, core, clearing, tapered ends), the pure queries (`amount_at`, `rain_at`, `gust_at`, `edge_distance`, `envelope_at`, ...), the flags, and the shader globals (`zs_storm_line`, `zs_storm_shape`, `zs_storm_here`, `zs_lightning`, `zs_storm_wet`, `zs_storm_cloud_weight`, `zs_storm_ground`, `zs_storm_cloud_flash`). GPU mirror: `shaders/storm_front.gdshaderinc`.
- Clouds: `shaders/storm_cloud.glslinc` (the push on the field's cells, the deck, scud, murk, the torn back) in `shaders/endless_cloud_march.glsl`; `shaders/storm_cloud_light.gdshaderinc`; `scripts/endless/storm_towers.gd` on `scripts/sky_tower.gd` (baked 3D distance textures).
- Rain: `scripts/endless/storm_rain.gd`, `shaders/storm_rain*.gdshader`, `storm_curtain.gdshader`, `storm_rain_water.gdshaderinc`, the soak and puddles in `shaders/endless_ground.gdshader`.
- Lightning: `scripts/endless/storm_lightning.gd`, `shaders/storm_bolt.gdshader`.
- Gust: `scripts/endless/storm_gust_sound.gd`, `shaders/storm_gust.gdshaderinc`, `shaders/storm_sea.gdshaderinc`.
- Sound in `flight_sound.gd` (rain bed, thunder, gust roar, `cloud_muffle`); the light grade through `celestial.storm` (`scripts/celestial.gd`, `STORM_NIGHT_FILL`).

## Cost (this PC, GPU ms, d631ca0f)

| View | ms | Storm adds |
|---|---|---|
| Storm off | 7.33 | |
| Ahead | 10.92 | +3.6 (towers +2.0) |
| Ahead, `--storm-towers=0` | 8.87 | +1.5 |
| Ahead, `--storm-towers=1` | 9.38 | +2.05 |
| Under the core | 9.62 | +2.3 (towers +0.8) |
| Under, `--storm-towers=0` | 8.80 | +1.5 |
| Behind | 8.65 | +1.3 |

The aim was the storm under +2 ms and the towers under 1 ms. Under the core the towers are; ahead they are not. Low-end knobs: `--storm-towers=0/1`, `--cloud-half-res`, `--cloud-steps=N`. The march looks register-bound: cuts that remove code win, cuts that add branches lose. Untried, all removing code: one shared tower path for the cheap taps, 2 towers by default, fewer carve octaves far off, a coarse max-distance mip of the bakes for a footprint test.

**Measuring trap:** `tools/godot.py` does not reimport a changed `.glsl`, and Godot never tracks `.glslinc` includes. Run `python tools/godot.py --import` after every shader edit before a rendered run. A shader rebuild alone moves timings ±0.15 to 0.25 ms, so compare against a rebuild of HEAD in the same session.

## Stood in or left rough

- The day in-cloud flash is a flat grey lift capped at 0.06, with no form in the cloud. At night the deck lights a fairly even grey under a flash.
- Trees under a near flash read pale (lit through the rain's grey air).
- The wet turf's darkening is mild once tonemapped; the drawn grass blades near the plane aren't wetted. Puddles are noise blobs mirroring the clear sky gradient, not the clouds.
- No light shafts through the gaps behind the storm.
- The struck arch's rubble on the ground is no flight solid (low, small). Reshaping costs 1.9 ms once per struck ruin, on the main thread.
- A small dark flat blob at cloud height behind the storm (chase -3500, top left, `--storm-start=-3000 --storm-grow=0`).
- The rain curtains against the reworked deck's base were not re-shot.
- Sound balance (rain bed, thunder, roar) is set by numbers, not judged by ear.
- Pre-existing, not the storm: at full night with no storm, stars draw over the far land below the horizon and over fair-weather clouds.
- No existing test was run; prototype rules (no suite). The cost view's march split (`#[versions]`) touches `scripts/cloud_volume_effect.gd`, which other cloud tests load.

## For the user to judge in play

- From 5 km the towers are sunlit tan-white with dark heaps at the foot: menacing enough, or a darker underside or an anvil?
- A far bolt from 5 km lifts the near land at night by about 40%: right for distant lightning?
- 4 km behind, the sky overhead is heavy dark cloud with blue holes: does that read as breaking up?
- Does the storm pay for itself at +3.6 ms ahead, or should towers default to 1 or 2?

## Out of this slice

Forces on the plane, gusts that push, storms in normal play (when and how often they come), wind features feeding the near-miss chain, a jet stream, rainbows, waterspouts, breaking out above the cloud.
