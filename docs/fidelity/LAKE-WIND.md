# Shoreline-dependent lake wind

The imported lake now retains the original eight-direction fetch at every
vertex, exported from the live seed-7 source only after all 996 positions match
the saved geometry. The native import reverses source winding while carrying
both four-float fetch channels into CUSTOM0/CUSTOM1. test_lake_fetch verifies
all 7,968 values and every saved instance transform in the scene.

The generated water.js wind recipe uses that fetch, the shared world gust field,
the source lake's swell multiplier (.7637764759), and effects (1,1). It supplies
the directional short-wave trains, warped longer waves, fine normal ripples,
and localized crest foam. Foam follows the same wave phase as displacement;
ice, wind strength and fetch gate it. Rain-ring normals remain an independent
source contribution. --no-lake-wind disables the chop/fine-ripple/foam group while
retaining the source base swell and rain response.

Native GPU test_lake_chop verifies zero-fetch/calm/frozen suppression, open-water
chop, localized foam, and time propagation. The integrated fidelity suite passes
after rebuilding geometry. The import tool now rejects the dummy/headless
renderer before saving: it cannot preserve MultiMesh instance buffers. Rebuild
with Godot's native renderer; do not use --headless for tools/import_reference.gd.

lake-wind-comparison.mp4 uses Storm, fog disabled, camera
8,.55,1.9,6.2,.38,-3.4, matching three-second clocks. Wind response left, disabled
right. Foliage and rain remain active on both sides. An initial headless-import
capture was discarded because its foliage was absent; only the verified native
rebuild is represented in the published comparison.

Remaining water gaps include wildlife contact rings, transparent water's own
atmosphere depth, reflection/absorption, submerged detail, lake-specific rays,
algae and cut/base shading. This is source wind-response integration, not full
water fidelity or a performance claim.
