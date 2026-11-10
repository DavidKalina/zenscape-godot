# Lane spec: wild-kit waterfall (lane `wk-falls`)

A lane of loop `wild-kit`. Branch `lane/wk-falls`, worktree
`/Users/davidkalina/Documents/Projects/zenscape-wk-falls`, branched from the
loop's finished step 0 (placed sites with their clear footprints). The
loop's spec, `spec-wild-kit.md`, is background: its **Settled** section holds
here. The master list is `wilderness-kit.md` (the Curtain row). Commits:
`ITER(wild-kit): lane falls: <task>`, each ending with **Notes for merge**
(every line it touched in a file it didn't create). Cap: the skill's
default.

Other lanes run at the same time (director, elk, uprights). Each adds one
line to `KINDS` in `scripts/endless/kinds/kinds.gd` and edits its own row in
`scripts/endless/world/wilderness/placed.gd`; touch only your line and your
row.

## Done looks like

The kind **curtain** (`scripts/endless/kinds/curtain.gd`: a sheet you punch
through with a space behind it, no skin of its own) with its wilderness skin,
**a waterfall**, at the placed site `wild/river_falls` (1940, -25, facing the
river; the west bank rises 60-75 m in 50 m there, the water 30-50 m from its
foot). Swap the site's `marker` for `curtain`, skin `waterfall`, keeping the
handle; size its `params.clear` (40 m now) to what the falls need.

- **From afar:** a landmark. White water falling over the cliff's lip into a
  plunge pool that joins the river, mist at its foot, readable from the
  valley on approach.
- **The punch:** the falling sheet has no collider; the plane flies through
  it. A spray burst, the screen goes wet (`scripts/endless/screen_wet.gd`),
  and the fall's roar drops to a hollow boom inside.
- **Behind it:** a cave in the cliff, wide and tall enough to fly, that runs
  through the rock and comes out a mouth lower down or round the side, back
  into the river valley. Its openings are sized with
  `WorldScale.opening(toy_width)`, the toy width a named constant in the
  file (AGENTS.md, Sizes). Its walls are solid, so the existing near misses
  count in it.
- **The look:** the land's rock look (the rock shader and its carved shape,
  `scripts/endless/rock_shape.gd`), not ruin stone; stylised water in the
  world's palette.

**Land shaping.** The bank may need a lip, a notch for the water to come
over, a plunge pool, and a stream feeding the top. Shape the land under the
site as a layer over the land field, the way the ponds and the slot halls do
(`scripts/endless/hall_sites.gd` is a layer over `land_field.gd`), keyed to
the placed site and deterministic. The cave is a mesh piece on the
heightfield (no voxels). The river keeps flowing, and the meadows-and-flats
rule holds.

Prior art for falling water: `scripts/flow_falls.gd`,
`scripts/cluster_falls_dress.gd`, `scripts/water_flow_reference.gd`,
`scripts/ruin_kit_aqueduct.gd` (its spill). Later skins of the curtain are
a sand fall, an ice curtain and hanging moss, so keep the sheet's shape, the
punch and the space behind it in the kind, and the water in the skin.

## Proof

The smoke check of `studies/endless_flight.tscn`. A throwaway driver through
the real play loop that flies the line in through the curtain, through the
cave and out the mouth without touching rock, logging the clearances. Rendered
stills, looked at: the falls from the valley on approach, just before the
curtain, inside the cave, the exit. Look at: those stills, and a launch line
that puts the plane near the falls if the game has a way to.

Suggested order: the land shaping and the falling water seen from the valley
(one checkpoint), then the cave and the fly-through (a second), then the
punch's spray, wet screen and sound, and the look (a third).

The handoff lists which `docs/art/model-budget.md` tricks apply to the cave
and the falls, with triangle and frame-time estimates (AGENTS.md, Models).
