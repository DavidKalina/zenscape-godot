# Visual effects in the playable editor

The project entry point, `studies/diorama.tscn`, now includes the effects previously restricted to the luminous woodland benchmark. Launch `run-diorama.command` and choose a landscape from the normal editor.

| Effect | Playable behavior |
| --- | --- |
| Planar pond reflections | Each distinct editable pond elevation receives a mirrored, clipped scene. Jade terraces shows three; other landscapes and manually added ponds use the same path. |
| Underwater caustics | Enabled on every reflected pond. Light patterns follow the submerged bed, fade in deep water, and diminish with ice, darkness and cloud cover. |
| Drifting ground mist and light shafts | Ordinary landscapes use the benchmark mist shader with live terrain/water maps and existing mist/ray controls. Redwood groves retain their tree-cover-driven forest mist. |
| Windblown leaves | Shared editor effect near broadleaf trees, shrubs and redwoods on suitable dry ground. Object edits refresh their anchors. |
| Redwood foliage and conifer wind | Shared editable asset meshes/materials, including foliage transmission and wind animation. |
| Waterfall drips | Shared editor effect attached to landscape falls, with existing growth, pause and ice gating. |

Reflections follow the current camera, light rig, mesh transforms, visibility, shared instance buffers and local material parameters. Terrain and object changes rebuild their scene bindings; changing worlds clears old reflection viewports. The water shader retains its rain rings, wind, algae, glints, palette and ice behavior. During terrain/water growth it uses the existing refill rendering, then activates reflections when filled. Streams retain their flowing-water shader.

Native mist and planar reflections use Forward+. Beauty renders reflection views at 512 pixels wide; Balanced uses 384. Both use 2× MSAA and omit duplicate shadow passes. Each pond elevation adds a scene render; this change does not establish a sustained frame-rate target.

The historical benchmark remains available as an isolated A/B composition. It explicitly disables the new automatic adapters so it can continue comparing its original treatment without double rendering.

## Verification

`tests/test_playable_visuals.gd` runs against the actual product scene. It checks three reflected terrace levels, caustics on every level, changing transforms/visibility/materials, object-only edits, save/load, landscape replacement, empty-world cleanup, water refill fallback and mist controls. Native Forward+ passed with zero failures; matched enabled/disabled water captures were inspected. Use `-- --capture` to save captures under `/private/tmp/zs-playable-*.png`.

`tests/test_redwood_grove.gd` (removed) checks editable grove objects, changing cover, save/load, mist controls and transition to ordinary landscape mist.
