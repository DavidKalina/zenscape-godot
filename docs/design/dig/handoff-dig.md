# Handoff: digging with a spade (loop `dig`)

Spec: `spec-dig.md`. Trail: `git log --grep='^ITER(dig)'` on branch
`iter/dig` (worktree `/Users/davidkalina/Documents/Projects/zenscape-dig`),
six tasks, not merged.

## Play it

`./run-wreck-cluster.command` from the worktree. The spade stands in the turf
just ahead and right of the start, by the plane. G (pad Y) digs. The console's
"wreck cluster: deal" line names the part buried this deal ("(buried)" and its
part spot). N re-deals.

## What's built

- **Spade:** stuck upright by the plane (`wreck_cluster/spade`). Walk into it
  or press G beside it, and it rides across his back. N puts it back.
- **Dig:** about 1.8 s: draw, raise and hold, strike, lever, fling to his
  right, twice, then stow. Clods, soft dust, soil sounds and a scoop in a
  stubble clearing. On stone: clank, spark, chips, recoil, no hole. Nothing
  in the air, hanging, swinging, sliding or in water.
- **Strange spots:** 12 (`wreck_cluster/dig_spot_NN`) in nooks: under the
  arches, the tower's foot, rock tips and rims, the bench's east end. Tells:
  mound, ring of stones, line of stones on edge, leaning marker, dry patch,
  strap, box corner. Plants round each are cut back so the tell reads.
- **Finds:** a token (rune, crystal, moon, feather) rises out of the hole with
  dust and a chime, then he takes it. Each deal also buries one plane part at
  one of four spots (strip lobe, coast arch, rope arch, tilt rock chest), via
  the new `buried` holder; it rises and lies glinting to be taken.
- **Holes:** a dug spot leaves a pit with a rim and spoil heap, cleared to
  bare earth about 1.8 m out, for the whole deal. Plain scoops cap at 16. N
  fills everything.

## Stood in

- The dig motion is procedural on the existing rig; Blender clips come with
  lock-in.
- Holes are meshes laid on the turf. Real terrain dents would mean rebuilding
  a land's mesh, collision and grass per dig (each land is one mesh on a 2 m
  grid with one collision shape; the cluster builds in about 1.6 s).
- Cutting plants reads the grass buffers back from the GPU (once per dig,
  and once a second for the first 12 s at load). Untimed; may hitch.

## Open

- The game camera dropped into the grass mid-dig under the rope arch; likely
  the camera pulling in for the arch overhead. Not checked in play.
- Finds aren't saved to the ledger.
- Part names are now shuffled before the deal, so old `--seed=N` deals differ.
- Harness: shot cameras draw the cloud sea as haze at this isle's height, so
  some reveal films can't be judged.
- Merging with `iter/carry`: both add an action to `scripts/pad.gd` (dig G /
  pad Y, carry E / pad B) and small hooks in `studies/wreck_cluster.gd`.
