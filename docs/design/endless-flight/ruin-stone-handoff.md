# Blender ruin stone: handoff

Recommendation 3 from the model audit (`docs/art/model-audit.md`): a cut-stone
material sculpted in Blender, laid on every RuinKit piece. It follows the
lighting round (`ruin-light-handoff.md`).

## What's built

- **The sculpt and bake** (`art/blender/ruin_stone/ruin_stone_build.py`;
  `python tools/blender.py run art/blender/ruin_stone/ruin_stone_build.py -- --preview=scratch/ruin_stone`,
  about 4 minutes):
  - A 2.4 m tile of coursed ashlar: four courses of blocks in a running
    bond. Each block is bevelled, chipped with lumpy boolean bites,
    sometimes spalled, remeshed at 11 mm and eroded with noise.
  - A mortar bed sits behind the blocks, and the tile is laid 3x3 so its
    edges tile without a seam.
  - Cycles bakes height, block tone and AO onto the centre tile (1024 px).
    The script works out the normal from the height (numpy).
  - Out: `assets/textures/ruin_stone_normal.png` and
    `ruin_stone_mask.png` (R AO, G height, B tone, 0 for mortar). Both are
    imported lossless with mipmaps (their `.import` files are set by hand).
- **The shader** (`shaders/stone_tile.gdshaderinc`, under `ZS_STONE_TILE` in
  `ruin_stone` and `gothic_stone`):
  - Sampled from three sides in the piece's own frame. The kit's stone
    stands still, and the colosseum's bays are MultiMesh instances, so
    each bay keeps its own frame.
  - The normal is laid onto the face's normal before the old weathering
    bumps it.
  - The AO and each stone's tone darken the colour, and through it the
    emission shade fill. The mortar is darker.
  - The weathering and the moss now classify by the face's own normal, so
    a chip's slope doesn't read as a worn top (that drew pale flecks along
    the joints).
- **The colosseum's moss on its tops only** (`land_arches.gd` `_tops_stone`:
  `moss_tongue` 2, `moss_low` 0). The moss tongues and bare patches were
  what made it read as camouflage. The gothic pieces keep their full moss.

Flags: `--ruin-stone=old` (no tile), `--colosseum-moss=full` (the colosseum
mossed as before), and `--no-stone-moss` (no moss on any set piece; the
stone alone).

## What it looks like

Stills are in `scratch/audit/cmp_st*` (driver `scratch/sets/sshots.gd`).

- **Close and mid range:** every kit face reads as built from coursed
  stones with joints, worn arrises and chips. The colosseum's ambulatory
  and vault soffits read as a stone passage instead of a dark slab and
  planks.
- **The colosseum from 120 m and further:** a coherent pale travertine
  ruin with moss along its ledges, where before it was a gold-olive camo
  of blotches.
- **The belfry and rose gate:** they still show the moss's bare patches.
  Their moss paint is unchanged and decides their look at range.

## Cost

GPU time at three views (this PC, 1440x900 at 0.75 3D scale) was 3.7 to
4.3 ms against 4.0 to 4.5 ms with `--ruin-stone=old`: within the noise.
The stone takes at most six texture taps per pixel. Texture memory is two
1024 maps with mipmaps, about 11 MB uncompressed.

## Model-budget tricks

| Trick | Status |
|---|---|
| Sculpt high, bake low | Used: about 177k-tri blocks baked to a tile, no new geometry in game |
| Parallax depth | Not used. The height is in the mask (G) for a later parallax or for moss in the joints |
| Vertex-colour grime | Unchanged (the lighting round's sky bake) |
| LODs | Not needed: the mipmaps fade the detail with distance |

## Checks

- Smoke PASS, 0 errors: default, `--world=amberlands`, `--world=regions`,
  and `--world=amberlands --ruin-stone=old --colosseum-moss=full`.
- Tests: not run this round. `test_ruin_kit.gd` already fails and times
  out (see `ruin-light-handoff.md`).

## Open

- The tile's courses don't follow the kit's own block seams, which still
  show as thin lines across the coursing.
- One tile everywhere. Its repeat is visible on long flat walls up
  close. A second bake (`--seed=`) blended per piece would hide it.
- The yellow triangle shards in the ambulatory are still there.
- Not seen in stills: the default world's halls and tunnels (tunnel
  stone doesn't take the tile).
- Next per the audit: Blender ivy cards (4). The gothic pieces' moss may
  want the same tops-first treatment if you like the colosseum's.
