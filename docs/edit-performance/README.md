# Editing stalls: Redwood Grove and Bigfoot

Reported on Windows with an RTX 4070 Super: rendering is smooth, but inviting
Bigfoot and subsequent placements stutter. Reproduced related edit stalls on
Apple M5 Pro, Godot 4.7.2, native Forward+/Metal. Windows remains unverified.

## Findings and changes

- Redwood mist regenerated a 64×64 cover texture by testing every redwood
  against every pixel whenever **any** object revision changed. The parent
  scene spent about 30 ms here on each rock drag update; an isolated cover
  call took 34.6 ms in a headless CPU probe. Cover now depends only on redwood
  x/z/scale footprints. Unrelated edits reuse the texture; changed trees are
  rasterized only within their radius. The final native unchanged-cover call
  took 0.1 ms.
- Committing a prop also regenerated unchanged water and repainted surface
  maps. GardenView now preserves water resources and their revision when only
  props changed. On the populated fixture, surface-map work fell from 10.5 ms
  to 0.007 ms, and placement commits from 53–54 ms to 29–32 ms.
- A selection outline fetched every object's render transform. It now filters
  to the selected ID before fetching transforms. Geometry notifications copy
  only records whose tint must be omitted, preserving authored data. Populated
  drag updates fell from 12–14 ms to 7–8 ms.

The Redwood/Bigfoot native sequence's largest recorded frame interval fell
from 52.9 ms to 31.2 ms. This is a short, instrumented local sample, not a Windows
GPU result or a guarantee of hitch-free editing. Initial Bigfoot invitation
still performs a synchronous navigation scan. Subsequent live navigation scans
already use approximately 2 ms slices; instrumented habitat work was about
2.4–2.7 ms per frame, versus roughly 30 ms for the unnecessary mist update.

## Reproduce

Run from a source checkout with Godot 4.7.2 and imported assets:

```sh
godot --path . --script tools/profile_object_edits.gd -- --redwood-bigfoot --out=redwood-edits.json
godot --path . --script tools/profile_object_edits.gd -- --file=res://docs/garden/fall-world-proof.json --out=populated-edits.json
```

The harness uses the diorama scene, editor record commit/refresh and selection
preview paths. It does not save user worlds. The Redwood option enables the
resident through `invite_bigfoot`. Timings cover synchronous script operations
and process-frame intervals, not GPU timestamps or display/input latency.
Pointer picking and placement reaction effects are not included. Diagnostic
stage probes run after the interaction sample. Other workspace work was active;
the before/after files are evidence of this local investigation, not an isolated
hardware benchmark. Exported release packages exclude these source tools.

## Validation

- `test_redwood_cover_cache.gd`: originally failed on unrelated prop edits;
  now passes. Rasterized output matches the full-grid reference byte for byte,
  including overlap, edge clipping, tree movement/scale, deletion and biome change.
- `test_native_refresh_incremental.gd`: originally failed both water-resource
  preservation checks; now passes, including full-rebuild equivalence, undo,
  terrain sculpting and changed/removed water.
- `test_native_selection.gd`: passes headless and native GPU checks for picking,
  drag, tint, authored-data preservation and undo.
- `test_redwood_grove.gd` and `test_fidelity_life.gd`: pass.
- Temporary per-frame diagnosis logs were removed; `git diff --check` passes.

Some headless runs emitted the system-certificate warning and exit-time ObjectDB
leak warnings also seen before these changes; no assertion failures remained.
