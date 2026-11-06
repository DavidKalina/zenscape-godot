# Lane spec: wild-kit uprights (lane `wk-uprights`)

A lane of loop `wild-kit`. Branch `lane/wk-uprights`, worktree
`/Users/davidkalina/Documents/Projects/zenscape-wk-uprights`, branched from
the loop's finished step 0 (placed sites with their clear footprints). The
loop's spec, `spec-wild-kit.md`, is background: its **Settled** section holds
here. The master list is `wilderness-kit.md` (the Upright row / ring row).
Commits: `ITER(wild-kit): lane uprights: <task>`, each ending with **Notes for
merge** (every line it touched in a file it didn't create). Cap: the skill's
default.

Other lanes run at the same time (director, elk, waterfall). Each adds one
line to `KINDS` in `scripts/endless/kinds/kinds.gd` and edits its own row in
`scripts/endless/world/wilderness/placed.gd`; touch only your line and your
two rows.

## Done looks like

The kind **uprights** (`scripts/endless/kinds/uprights.gd`: a set of upright
pieces stood in a ring or a row, with gaps to thread; no skin of its own)
and two wilderness skins, which prove a kind takes more than one:

1. **Standing stones**, a ring at `wild/meadow_ring` (770, 70; open, flat,
   about 400 x 250 m; an 80 m clear). Tall stones with gaps to thread, a
   few lintels across pairs to fly under, one or two leaning or fallen.
   Built from the land's rock: the rock shader and its carved shape
   (`scripts/endless/rock_shape.gd`, `scripts/endless/rocks/rock_build.gd`),
   not the ruin stone.
2. **Shipwreck ribs**, a row at `wild/inlet_wreck` (25, 100; a flat beach
   2-3 m over the sea, lying along the shore; a 60 m clear). A keel half sunk
   in the sand with curved wooden ribs standing up from it, open at the top,
   some broken short, a stern or bow post: a channel to fly along between
   the two sides and gaps to thread through them.

Swap each site's `marker` for `uprights` with its skin (`stones`, `ribs`),
keeping the handles; size their `params.clear` to the pieces.

- Every gap meant to be flown is sized with `WorldScale.opening(toy_width)`,
  the toy width a named constant in the file (AGENTS.md, Sizes).
- The pieces are solid, so the existing near misses count when you thread
  them.
- The kind takes its layout from the site's `params` (count, radius or
  length, height, gap, lean), so a later skin (bone ribs, crystal spires,
  broken columns) only brings its pieces.
- The meadows-and-flats rule holds: the ring leaves the meadow landable,
  and you can still land on the beach past the wreck.
- The look is stylised and in the world's palette (no photo textures).

## Proof

The smoke check of `studies/endless_flight.tscn`. A throwaway driver through
the real play loop that threads a gap in the ring, flies under a lintel and
flies the wreck's channel, logging the clearances, with no crash. Rendered
stills, looked at: each from the approach and from inside a gap. Look at:
those stills, and a launch line that puts the plane near them if the game has
a way to (the wreck is 100 m south of the start).

Suggested order: the kind and the stone ring (one checkpoint), then the
wreck ribs (a second), then tuning the gaps from the driven runs.

The handoff lists which `docs/art/model-budget.md` tricks apply to the
stones and the ribs, with triangle and frame-time estimates (AGENTS.md,
Models).
