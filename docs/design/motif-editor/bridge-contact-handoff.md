# Rope bridge contact: handoff

The ask: "The bridge tool is better, but still floats sometimes. Doesn't
insert good contact points."

## Causes

- **The end snapped to the wrong place.** `_run_point` snapped each click
  to `lip_near(highest)`, the highest point within 4 m that falls 1.2 m
  any way. That point did not have to face the other end. On a hillside or a
  stepped ravine wall it was a ledge partway down the wall or a point up the
  hill.
- **The seat search kept poor seats.** `bridge_seat` accepted a seat with no
  edge within 3 m before it tried a ridge seat, so an anchor could stand 6 m
  inland with the deck buried 1.6 m in the bank (gorge z -12). When it found
  nothing at all, it fell back to the ground height of one point, with no
  footing.
- **The anchor was only 0.21 m deep.** The sill was allowed 0.6 m of slope
  under it, and its top sat at the high side. That left up to about 0.35 m of
  air under the low side, and more under a corner over the edge. The land's
  mesh also cuts under the ground function at a lip, so the drawn turf could
  sit 0.3-0.4 m below a sill the ground function called seated.
- **Rubble floated.** `bridge_anchor` laid its rubble at y 0 with no ground,
  so stones that fell on the gap side hung in the air. These stones caused
  most of the large "before" gaps (1.4-4.8 m).
- **Edits under a bridge did not rebuild it.** `run_key` read the ground only
  2 m past each end. A bridge's anchors can stand 6 m or more inland, so
  editing the land there left the old bridge standing where it was.

## Fix

- `RuinKitFit.bridge_lip` / `bridge_ends` find each end's lip along the line
  between the two ends. A lip is where the ground falls steeply toward the
  other end, steeper by far than it climbs behind. Deeper falls, higher
  ground and points nearer the click score better, so it finds the top of a
  stepped wall and not a point up the hillside. The editor uses it on the
  second click and in the preview line. `bridge_run` runs it again on every
  build, so saved bridges and edited land are re-seated by the same logic.
  The recipe and its `from`/`to` keys are unchanged.
- Seat tiers, in order: meets the edge with a walkable bank behind; meets
  the edge; an edge further off. No more far seats with no edge ahead. The
  sill's top sits at the highest ground under it. Where the ground under it
  falls more than the sill is deep, a coursed plinth (the existing `plinth`
  spec) grows down to 0.3 m under the lowest ground. The lowest ground is
  read over a ring 0.8 m round the sill, to allow for the mesh, and at most
  1 m under the sill's own lowest point.
- `bridge_anchor`'s spec takes `terrain` (additive). Rubble lies on it and
  is left out over a drop, and faces under the turf are culled. `_rubble`
  has a `drop` parameter whose default leaves every other piece unchanged.
- `run_key` reads a bridge's ground 11 m past each end, at five offsets
  across the line.
- Files: `scripts/ruin_kit_fit.gd`, `scripts/ruin_kit.gd`,
  `studies/motif_editor.gd`, `studies/motif_editor_rebuild.gd`. Piece ids,
  connectors and the recipe are unchanged.

## Numbers (scratch/bridge_contact.gd, headless, real clicks, 16 cases)

The driver lays each bridge through mouse events with the run_bridge tool.
The cases are: the gorge's saved bridge; 4 new spans across the gorge;
clicks 2 m inland, 1.5 m down the wall and to the side; deep, shallow,
narrow and wide ravines cut across the terraced hill; uneven banks; a
slanted bank; the tarn peak; and land raised and lowered under a bridge
already laid. For each anchor it measures the stone's underside over a grid
of sample points against the turf collider and the ground function.

| | before | after |
|---|---|---|
| worst air under any anchor footprint sample | 4.76 m (1.4-1.6 m common) | -0.16 m (all buried) |
| anchors with any air under them | 20 of 34 | 0 of 34 |
| deck end buried in the bank (worst) | -1.59 m | -0.21 m (plank depth) |
| deck end to the real edge (worst, one end with a gap) | 7.35 m | 1.45 m |
| anchor height over its snapped lip (worst) | 11 m | 3.2 m (stepped hill; seat on the bank top) |
| land edited under a bridge | not rebuilt | rebuilt and re-seated |
| P, walk bank, on, across, off, and back | | 16/16 routes ok, no set-backs |

The bridge run now takes about 105 ms to build (lips 15 ms, two seat
searches about 60 ms, anchors 30 ms).

## Stills

Rendered stills are in the worktree at `scratch/shots/` (git-ignored).
`sheet_<case>.png` shows before and after side views of each end. The
cases with sheets are gorge_saved, gorge_z5, gorge_off_wall, hill_slant and
hill_edit_after.

## Notes

- Model budget: a plinth adds about 150-250 triangles to an anchor of
  about 630, and only where the ground falls away. Faces under the turf are
  culled. No other tricks apply.
- No existing test breaks. `test_ruin_kit.gd` and `test_rope_bridge.gd`
  pass. Smokes pass: motif_editor plain and with
  `--load=editor_aqueduct_gorge`, and motif_yard on editor_aqueduct_gorge,
  editor_hill and bell_spires.
- Not done: dragging an anchor by hand. On a deep stepped hill canyon, the
  seat can still stand on the bank top 3-4 m behind the lip the editor
  shows.
- A few walks hop once onto the anchor from a placed start. The same hop
  happens with the plinth turned off, so it is not this change.
