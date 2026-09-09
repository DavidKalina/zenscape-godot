# Desert terrain parity experiment

Question: can the original Electron desert's salt basin and sandstone identity carry into the Godot visual lab without losing its lighting and mood controls?

Run `./run-desert-worlds.command` to start on the salt basin. The composition menu also contains original desert (`desert`), dune sea, tablelands, broken buttes, monuments, and desert mountains. Seed, relief, breadth, rock treatments and all nine moods remain available.

## Adapted from the source

- `desert.js`: the original four profile parameter tables, mesa placement, ragged mesa outlines, anisotropic sand field, and asymmetric dune profile.
- `desert-monuments.js`: irregular sandstone towers, broad talus aprons, summit shelves, fluting, and the surviving narrow finger. The finger also gets an explicit mesh because it is narrower than the native terrain lattice.
- `desert-salt-basin.js`: the continuous irregular playa, low undulating salt floor, and shallow water datum. Native flooding finds the disconnected pools and draws each connected component once. Salt excludes planting.
- `desert-mountains.js`: eroded ridges framing a dry alluvial wash.
- `desert-rock-color.js`: warm sandstone bands at shared absolute heights and darker cap varnish. Sand and rock classification comes from the same terrain function, rather than an elevation threshold. Salt has a pale crust and subtle polygon cracks.
- Sparse saguaros with zero, one, or two arms, plus debris restricted to nearby cliff feet, adapt the source's visual vocabulary. These are disposable scene meshes, not new production editor assets.

The source's 84-unit regional studies are compressed horizontally by three into the existing 28-unit diorama. Their heights use a 0.65 multiplier and 0.8 base offset, preserving spectacle; relief and breadth remain independent. Original four desert profiles use their original 28-unit coordinates. The source's noise function is ported directly. Seed 7 preserves the original fixed profile lattice; other profile seeds are an explicit experimental extension.

## Verification

2,541 height/salt samples across seven profiles and three seeds were evaluated directly against the sibling source modules. Maximum height difference after scale conversion: 0.000002872 units. This verifies the analytic formulas, not pixel identity: the native terrain lattice, rendering, lighting, regional framing, and vegetation differ.

The expanded genome probe covers 600 deterministic samples across 15 compositions; habitat cannot change terrain or water. Versions 1 and 2 remain replayable. Version 3 records the new desert formulas and expanded composition distribution.

Native Godot Forward+ captures cover all seven desert profiles, plus daylight/dusk/snow salt-basin variants. The capture tool asserts nonempty salt pools and unchanged native records across all nine moods. No script or shader errors in the final native run. These checks do not constitute a production performance benchmark.

To reproduce source comparison (Node and Godot must be on PATH):

```sh
node tools/prototype_desert_source_fixtures.mjs /path/to/zenscape /tmp/zenscape-desert-source.json
godot --headless --path . --script tools/prototype_probe_desert_parity.gd -- /tmp/zenscape-desert-source.json
```

For native captures:

```sh
godot --path . --windowed --resolution 1600x1000 --rendering-method forward_plus --script tools/prototype_capture_deserts.gd
```

## Remaining source features

This brings the selected desert terrain formulas close to the source, not the entire Electron desert scene. The separate connected mesa-basin regional profile, mixed multi-chunk layout, regional seams, arches, ruins, colossal landmarks, scorpions/vultures, tumbleweed animation, blowing sand, dust devils and wind-driven dune drift remain outside this pass. Production persistence and frame-budgeted regeneration also remain outside the lab. The existing accepted mountain and valley experiments remain available.

Review the captures and montage for the aesthetic verdict; numeric parity does not decide whether the diorama proportions or sandstone contrast are the right final choices.
