# Bore trees: handoff (2026-11-03)

The bug: the user sees a bright green/white distortion on the trees over a tunnel
during the burrower chase, on the Mac and the PC. Later they added that it only
happens on the tunnel.

Status: not reproduced in play, and nothing fixed. No code has changed.

## What was tried (seed 1, rendered, stills in `scratch/bore/`)

- **The shudder's gust** (`tree_shudder.gd` `gust_strip`, `zs_gust_map`). Driven
  by hand through a wood, and by the real creature (`burrower.wake`). At a run's
  strength the trees bow and the crowns pale a little, with no artifact
  (`d_sheet.png`). At a sighting's numbers (strength 1.6, gain 1.6) a crown is
  sheared about its own height sideways and smears pale (`e_1_f150.png`). That is
  a real overshoot, but it happens anywhere there are trees, not only over a
  tunnel, so it isn't the reported bug.
- **The tunnel's trees with no burrower** (`--no-burrower`). Tunnel
  `doors/tunnel/1_-1`, trees near (5220, -2034). Shot with the harness's own
  camera (`shot_at`) 90 m from the pinned plane, the near spruces drew mint-white
  under a dark top (`t1_1.png`, crop `t1_crop.png`). Toggles: hiding the tunnel's
  meshes, its portals and its `Stretches` changed nothing (`t2_sheet.png`,
  `t3_sheet.png`, `t4_sheet.png`). Hiding the trees' `Far_*` tiles removed the
  white, and hiding `Detail_*` didn't (`t56_sheet.png`). So the white was the
  far-crown stand-in drawn at 20-40 m. **This is a harness artifact**: the crown
  LOD bands are measured from `zs_camera_position`, the play camera's position
  (`endless_look.gd:705`, `reference_surface.gdshader:869-876`), not from the
  camera drawing the still. Play has one camera, so in play the two always match.
  Drivers that judge trees must shoot from the play camera (`shot()`), or stand
  `shot_at`'s eye at the play camera.
- **Through the play camera** (`bore_look.gd`, plane pinned): over the bore
  along its length and round the far sinkhole (`a1_sheet.png`), and inside the
  bore near both ends (`b1_sheet.png`, `m1_sheet.png`). No tree artifact in any
  of them. Mid-way the bore is about 70 m under the turf. The only pale green
  inside is the hanging growth, which is lit that way by design.

## Not yet checked

- The real chase from start to finish through the play camera, especially the
  run into the mouth, the exit out of the sinkhole with the plume, and the
  moments the camera crosses the rock at the mouths.
- Seed 1's other sunk tunnels (-2_1, -1_1, 1_1).
- The bore plume shader and the additive beam/card shaders (`land_tunnels.gd:2300,2436`)
  weren't toggled in a frame that showed the bug, because no frame showed it.

## Side findings

- Over mid-bore, a ray down from the sky hits the bore's body at about y -70,
  not the turf at about -3, so the turf over the bore there seems to have no
  collider.
- The sighting's gust shears tall crowns (`ZS_TREE_GUST` x `gust_gain` 1.6 x
  `over` 1.15, applied linearly up the whole height).

## Tools (scratch, git-ignored)

`scratch/bore/gust_repro.gd` (gust by hand or the real creature through a wood),
`wood_scan.gd` / `tunnel_scan.gd` (headless: dense tree cells, sunk tunnels and
the trees along them), `tunnel_look.gd` (stills of a spot, `--hide=`, node
listings), `bore_look.gd` (plane pinned in or over a bore, play-camera stills).
