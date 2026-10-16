# Rope bridge grit

Branch `look/rope-bridge-grit`. Surface only: the bridge's shape, sag and sway sim, collision and sizes are unchanged.

## What changed
- `shaders/rope_bridge.gdshader`: the fragment now draws the surface per pixel, with no textures.
  - Planks: grey and split, dark wet grain, nail heads, dirt packed in the joins, paler where feet fall, moss and lichen.
  - Hand and foot ropes: bleached hemp with dark twisted strands, frayed fibres, grime stains, an occasional binding, a little moss. Cords are the same, darker.
  - Posts and sills: dark split timber, lichen, moss.
  - Lit as the ruins' stone is: the sky hemisphere as emission, a faint rim, the look pass's cloud bounce and sky fill (`look_fill.gdshaderinc`). The bridge is no longer black in shade.
- `scripts/footbridge.gd` (`_box`, `_rope_bridge`, `build_mesh`): rope-bridge meshes now carry per-vertex tags. UV is the face's metres along its long and short side, offset per box. CUSTOM0 is (part kind, per-box random, short half-size, long half-size). Vertex positions, normals and colours are untouched. The tags are written only for roped bridges, so the plain footbridge mesh is unchanged.
- Every rope bridge is built through `Footbridge.live` -> `RopeBridge.make`, so all get it: the aqueduct isle's sky motifs (bell spires, broken ring, colonnade spine, hollow keel, stair clouds, sundered gorge), the plate's footbridges and the sky clusters.

## Knobs
Shader uniforms on the bridge's material: `grit` (0 bare vertex colours .. 2, default 1), `moss` (default 0.8), `fill` (shade fill, default 1.25). Colour constants are at the top of each part's branch in the fragment.

## See it
```
python tools/drive.py scratch/rbshot.gd --rendered --timeout 500 -- --settle=1500 --pick=5 --out=captures/shots/rope-after --scene-args --no-title --motifs-now
```
`scratch/rbshot.gd` is git-ignored (a throwaway camera driver: it pins a camera by a live bridge and saves wide/mid/close/deck stills). To see one without it, play the aqueduct isle and fly to the bell spires isle (east, about 420, 60) or the broken ring. `studies/motif_yard.tscn -- --motif=...` did not draw the land or bridge in rendered runs here (before or after this change), so it isn't useful for stills.

## Cost
No new draw calls: still one MeshInstance3D and one ShaderMaterial per bridge. No textures. The mesh gains a UV and a 4-float CUSTOM0 per vertex (16 bytes extra, 24 vertices a box). Fragment cost is a few dozen noise taps, only on the bridge's pixels; fine detail fades with the pixel footprint (`seen`).

## Tests
`tests/test_rope_bridge.gd` passes. No test reads the mesh's vertex format. Smoke: headless import and `studies/aqueduct_isle.tscn -- --motifs-now` 400 frames, 0 errors. The full suite was not run.

## Captures
`captures/shots/rope-before-{wide,mid,close,deck}.png` and `rope-after-*.png` (bell spires, Bridge_gable, camera pinned beside it). Git-ignored; they stay in this worktree (`.claude/worktrees/agent-ad168dfcee0cb56f1/captures/shots/`).
