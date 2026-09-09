# Inland genome integration lab

Goal: combine the original Electron project's inland variation with Godot's rendering, customization, and the accepted mountain/valley/rock studies. Caves, islands, and oceans are excluded.

Run `./run-inland-worlds.command`. The left panel controls seed, composition, archetype, landform, habitat, relief and breadth. Auto samples from the seed. Explicit choices override that selection. The upper panel retains clean/layered/weathered rock; the lower panel retains all nine world moods and atmosphere controls. The status line shows the actual sampled choices. Landform profiles only affect their compatible composition: crests and volcanic forms belong to mountain/massif; canyon/glacial forms belong to valleys. Archetype controls the original mountain profile.

This is a **integrated visual experiment, not complete Electron genome parity**. It demonstrates how sampled inland structure can drive the existing Godot renderer. It does not replace the production generator or older accepted studies.

## Implemented separation

- Fifteen compositions: mountain, massif, valley, basin, foothills, plateau, meadow, marsh, dunes, tablelands, buttes, desert, monuments, salt-basin, desert-mountains.
- Four original-inspired mountain archetypes: ridgeback, cone, range, horn.
- Original profiles plus twin summits, sawtooth ridge, buttressed canyon, glacial valley, rolling uplands, tall massif, and volcanic crown.
- Six existing habitats; habitat controls planting and terrain coloration independently from mood.
- Independent RNG streams for composition, mountain parameters, landforms, habitat, water, planting, and surface noise. Version 3 adds source desert formulas, with the v1 and v2 samplers retained for replay. No version claims full identity with Electron generation 21.
- One analytic terrain sampler drives mesh vertices, gradients, placement, and native pond flooding. Rivers carve the same terrain they cross. Palette changes do not regenerate terrain.
- Dune crests remain sand rather than acquiring rock solely because of elevation. Reflected pond surfaces use the existing visual benchmark's water shading adapted to the live planar-water helper.

## Source and parity

Adapted from the sibling checkout's `genome.js` composition/archetype separation and `landforms.js` crest and valley-wall profiles. Desert families are informed by `desert.js`; their current shapes are simplified Godot studies rather than exact ports. Version 2 carries over the original wetland layout and shore profile: rotated, jittered ellipses with irregular margins and shallow shelves. Connected openings flood once, without duplicate coplanar surfaces. Dunes use the original long windward/short lee profile; meadow and upland knolls now vary by seed.

| Area | Status |
| --- | --- |
| Composition / archetype / landform separation | Integrated lab |
| Original + taller mountains and valley profiles | Representative profiles, not identical seed output |
| Habitat + nine Godot moods + rock treatments | Integrated |
| Inland water | Local pools, mountain headwaters/falls, valley river and tributary; full original regional hydrology is not ported |
| Regional fields, neighboring ridge/lake/river constraints | Not ported |
| Full original trait ranges, weighted probabilities, ecological interactions | Original archetype weights/ranges, treelines, and counts integrated; full ecology and original seed identity remain partial |
| Text/expression-driven generation | Not ported |
| Legacy generator version replay / archive migration | Not ported |
| Salt flats and desert monuments | Adapted source formulas, sandstone, salt crust, shallow pools; see [desert study](../desert-parity/README.md) |
| Saving/reloading the new genome through production editor | Not enabled; runtime adapter is experimental |

The native record arrays remain the rendering output, but the temporary analytic recipe must not be serialized as an ordinary production recipe. Production integration needs an explicit validated genome document and save/reload path before exposing it in the editor. Rebuilds are synchronous in this disposable lab; production needs the existing frame-budgeted generation path.

## Verification

`tools/prototype_probe_inland_genome.gd`: 440 genomes across 40 seeds and all eleven compositions, repeatable settings, finite sampled heights, and identical terrain/water parameters (including wetland genes) under habitat changes. Forty v1 records match the retained legacy sampler; all four archetypes are reachable across 200 seeds. The headless data-only probe passed, with sandbox log/certificate warnings unrelated to the assertions.

Native Forward+ captures: every composition, recorded sampled genomes, and checks for nonempty generated pond surfaces. Additional captures cover all four original mountain archetypes, the new crest/valley profiles, four habitats on identical terrain and water, and relief/breadth extremes. All nine mood changes are checked against byte-identical native record snapshots. Inspect the [gallery](index.html). This is not a performance benchmark. Existing ObjectDB shutdown leaks remain outside this study.

Further production work: validated genome persistence, frame-budgeted rebuilds, and the remaining source ecology/geology details. Regional continuity follows when multi-chunk generation is addressed. These remain documented boundaries of the integrated single-plot experiment.

## Requirement audit

- Runnable interactive experiment: `run-inland-worlds.command` launches the dedicated scene with seed and independent composition/archetype/landform/habitat controls, relief/breadth customization, nine moods, atmospheric controls, and three rock treatments.
- Inland source variety plus new forms: source-inspired archetypes, original/glacial/buttressed valley profiles, rolling uplands, basins, plateaus, marshes, and deserts coexist with twin/sawtooth/tall/volcanic crests. This covers representative inland families without claiming full source-engine parity.
- Accepted clean/original variants: Clean is the initial rock treatment; original archetype profiles remain selectable. All prior standalone experiments remain unchanged.
- Reproducibility: sampler version and seed are recorded with captures; independent streams and native record invariants are checked by the probe/capture tools.
- Visual verification: native overview captures plus explicit original-archetype, landform, habitat, and control-extreme comparisons are in the gallery.
- Exclusions and limitations: cave/island/ocean systems are absent; regional generation and production save integration are listed above as remaining work.

## Desert follow-up

The [desert parity experiment](../desert-parity/README.md) replaces the simplified desert shapes in sampler v3 with source formulas and explicit sand/rock/salt materials. The older captures on this page document v2; the desert study has the current renders. Use `run-desert-worlds.command` to start there.
