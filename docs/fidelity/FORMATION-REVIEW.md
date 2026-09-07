# Formation integration review

The full sixteen-second replay was reviewed with the current terrain, water,
fog, vegetation and wildlife systems. It exposed two abrupt arrivals: the four
boulders appeared together at terrain completion, and Bigfoot's shelter tree
appeared at full size midway through foliage growth.

Boulders now rise and scale in on staggered terrain-growth intervals. Their
finished transforms are preserved exactly. The shelter tree grows from its
existing local anchor through foliage growth, restoring its original asset
transform at full growth. Bigfoot's rig and encounter admission still require
completed growth; the tree reveal does not move the encounter frame or IK
anchors. Manual scrubbing uses the same growth functions.

`tests/test_growth.gd` checks staged boulder visibility/scaling, exact transform
restoration, shelter-tree scaling/terrain gating, and the complete terrain →
water → foliage replay. `tests/test_bigfoot_lifecycle.gd` verifies encounter
concealment, admission, reservation, pause, growth and manual preview.

`formation-comparison.mp4` shows the updated replay on the left and the previous
replay on the right at the normal camera, sixteen seconds at 30 fps. Capture
with `./run-fidelity.command --fixed-fps 30 -- --clean --reveal
--film-frames=480 --film-dir=<unique directory>`.
