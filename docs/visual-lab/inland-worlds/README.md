# Inland genome integration lab

Goal: combine the original Electron project's inland variation with Godot's rendering, customization, and the accepted mountain/valley/rock studies. Caves, islands, and oceans are excluded.

Run `./run-inland-worlds.command`. The left panel controls seed, composition, archetype, landform, habitat, relief and breadth. Auto samples from the seed. Explicit choices override that selection. The upper panel retains clean/layered/weathered rock; the lower panel retains all nine world moods and atmosphere controls. The status line shows the actual sampled choices. Landform profiles only affect their compatible composition: crests and volcanic forms belong to mountain/massif; canyon/glacial forms belong to valleys. Archetype controls the original mountain profile.

This is a **first integration milestone, not complete Electron genome parity**. It demonstrates how sampled inland structure can drive the existing Godot renderer. It does not replace the production generator or older accepted studies.

## Implemented separation

- Eleven compositions: mountain, massif, valley, basin, foothills, plateau, meadow, marsh, dunes, tablelands, buttes.
- Four original-inspired mountain archetypes: ridgeback, cone, range, horn.
- Original profiles plus twin summits, sawtooth ridge, buttressed canyon, glacial valley, rolling uplands, tall massif, and volcanic crown.
- Six existing habitats; habitat controls planting and terrain coloration independently from mood.
- Independent RNG streams for composition, mountain parameters, landforms, habitat, water, planting, and surface noise. Version 1 identifies this lab's sampling rules; it is not a claim of compatibility with Electron's generation 21.
- One analytic terrain sampler drives mesh vertices, gradients, placement, and native pond flooding. Rivers carve the same terrain they cross. Palette changes do not regenerate terrain.
- Dune crests remain sand rather than acquiring rock solely because of elevation. Reflected pond surfaces use the existing visual benchmark's water shading adapted to the live planar-water helper.

## Source and parity

Adapted from the sibling checkout's `genome.js` composition/archetype separation and `landforms.js` crest and valley-wall profiles. Desert families are informed by `desert.js`; their current shapes are simplified Godot studies rather than exact ports. Marsh placement currently uses three authored pool positions; the original's irregular seeded wetland layout remains to be carried over.

| Area | Status |
| --- | --- |
| Composition / archetype / landform separation | Integrated lab |
| Original + taller mountains and valley profiles | Representative profiles, not identical seed output |
| Habitat + nine Godot moods + rock treatments | Integrated |
| Inland water | Local pools and a through-valley river; original waterfall/tributary planning not yet ported |
| Regional fields, neighboring ridge/lake/river constraints | Not ported |
| Full original trait ranges, weighted probabilities, ecological interactions | Partial; lab uses smaller parameter set |
| Text/expression-driven generation | Not ported |
| Legacy generator version replay / archive migration | Not ported |
| Salt flats, desert monuments, detailed marsh morphology | Further inland parity work |
| Saving/reloading the new genome through production editor | Not enabled; runtime adapter is experimental |

The native record arrays remain the rendering output, but the temporary analytic recipe must not be serialized as an ordinary production recipe. Production integration needs an explicit validated genome document and save/reload path before exposing it in the editor. Rebuilds are synchronous in this disposable lab; production needs the existing frame-budgeted generation path.

## Verification

`tools/prototype_probe_inland_genome.gd`: 440 genomes across 40 seeds and all eleven compositions, repeatable settings, finite sampled heights, and identical terrain/water parameters under habitat changes. The headless data-only probe passed, with sandbox log/certificate warnings unrelated to the assertions.

Native Forward+ captures: every composition, recorded sampled genomes, and checks for nonempty generated pond surfaces. Inspect the [gallery](index.html). This is not a performance benchmark. Existing ObjectDB shutdown leaks remain outside this study.

Next parity pass: expand parameter distributions and water planning, improve habitat placement/ground cover, then validate a persisted genome format. Regional continuity follows when multi-chunk generation is addressed.
