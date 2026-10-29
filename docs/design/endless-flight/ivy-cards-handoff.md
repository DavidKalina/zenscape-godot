# Ivy cards: handoff

Recommendation 4 from the model audit (`docs/art/model-audit.md`): the ruins'
ivy leaves drawn as cut-out cards of Blender-made leaf clusters, in place of
two-triangle leaves (on the gothic pieces those were about 0.75 m dark
chevrons).

## What's built

- **The atlas** (`art/blender/ivy_cards/ivy_cards_build.py`;
  `python tools/blender.py run art/blender/ivy_cards/ivy_cards_build.py`,
  about 35 s):
  - Four hanging clusters in a 2x2 atlas. Each is a curling stem with
    8 to 11 leaves on short stalks. The leaves are palmate, with pointed
    lobes and a notch at the stalk, cupped and folded, and each is turned
    its own way.
  - Lit from above and in front in Cycles, on a clear film.
  - `assets/textures/ivy_cards.png`: R the light (0.5 is the mean), B 1 on
    a leaf and 0 on a stem, A coverage. The light under the clear parts is
    spread out so the mips don't fringe. Imported lossless with mipmaps.
  - The strand's own colour tints the cards, so the Amberlands' muted
    gold-olive stays.
- **The cards** (`scripts/ruin_growth.gd` `_leaf_card`):
  - A card hangs from a stem's node, 2.1 times the leaf's size, at 42% of
    the nodes. It's folded down its middle and leans out from the stone.
  - Each card is a random cluster, mirrored half the time.
  - Its place on the card rides in a new vertex channel, CUSTOM1. That
    channel is carried through `RuinGrowth.Faces`, `append` (merges),
    `RuinLod` (levels and shadow chunks) and the bridge's tinted Build.
- **Which builds draw cards:** builds that draw their growth in GDScript
  (`Build.card_face` → `_draw_cards`, after the kernel or `_draw`). That
  covers the gothic pieces' dressing, the halls' (SunderedGrowth probe)
  and the bridges.
- **Which builds don't:** the kit's own small ivy drawn by the native
  kernel keeps its old leaves. The kernel doesn't know cards.
- **Shadow chunks:** with cards present, these are split in GDScript,
  because the kernel's split drops CUSTOM1 and the cards would cast
  squares.
- **The shader** (`shaders/ruin_growth.gdshader`):
  - Card fragments sample the atlas and cut out with alpha scissor at
    0.45, with coverage held up through the mips.
  - The baked light's spread is narrowed (`card_floor` 0.4).
  - Cards take 1.9x the sky fill (`card_fill`), so a clump in shade shows
    its leaves instead of a black lump.
  - Everything else in the growth draws as before.

Flag: `--ivy-cards=0` gives the old leaves.

## What it looks like

Stills are in `scratch/audit/cmp_ivy*`.

- The ivy reads as clumps of lobed leaves, cascading down the belfry,
  hanging off the nave's tops against the sky and down the rose gate.
- There's more ivy on screen than before: each card is a whole clump.
- The tendril hooks (thin dark V shapes) are still the old stems.

## Cost

GPU time at three views was 3.3 to 4.0 ms with cards, against 3.3 to
4.1 ms with `--ivy-cards=0`: no measurable cost. Cards come out to fewer
triangles than the leaves did: 4 triangles at 42% of nodes, against 2 to
4 at every node. The atlas is 1024², about 5.6 MB with mipmaps.

## Checks

- Smoke PASS, 0 errors: default, `--world=amberlands`, `--world=regions`,
  and `--world=amberlands --ivy-cards=0`.
- `tests/test_ruin_growth.gd` passes.

## Open

- The native kernel's ivy (the kit's own, small) has no cards. It would
  need the kernel to emit CUSTOM1 too (`isle_kernels.h` `ruin_finish`,
  `growth_chunks`).
- Cards lit edge-on can show as a thin line. A crossed second card per
  clump would fix that, at a little more cost.
- The belfry's moss blotches are unchanged (stone moss, not the ivy).
