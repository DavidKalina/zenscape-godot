# Spec: hood-stair-relics (iterate loop)

Build four ruin-kit pieces the user picked from round 2, as real kit pieces
they can place in the motif editor and play. The cards are the design:

| Piece | Id, family | Card |
|---|---|---|
| Pent hood | `pent_hood`, cloister | kit-k5-hide-descend.md |
| Hung stair | `keel_hung_stair`, keel (new) | kit-k4-state-change.md |
| Broken nimbus | `relic_nimbus`, relic (new) | kit-k1-grab-climb.md |
| Prayer lintel | `relic_torana`, relic (new) | kit-k1-grab-climb.md |

Read the card for each piece before building it. Where a card and the code
disagree, the code's real numbers win (AGENTS.md, Sizes). Note the change in
the commit.

## Done looks like

1. **Each piece is in the kit by its stable id.** It builds through RuinKit
   in the ruin stone, with its foot on y 0, "Mesh" + "Body" like the
   others. Its connectors go in `scripts/ruin_kit_fit.gd`.
2. **Each piece shows in the motif editor's palette** with a thumbnail. It
   can be placed, turned and saved, and it rebuilds the same on reload.
   Editor and KitLand changes stay additive (AGENTS.md, The motif editor),
   so existing `motifs/authored/*.json` build as before.
3. **One playable place has all four on real terrain:** a greybox slug
   in the motif yard (`studies/motif_yard.tscn --motif=<slug>`), or an
   `editor_*` motif saved from the editor, whichever is less work. It needs
   a landing strip (AGENTS.md, Motifs). The routes are walked with the real
   pilot through the real play loop:
   - **pent_hood:** you walk the gallery under the roof, vault the parapet,
     and surf the roof off its eaves to a lower step.
   - **relic_nimbus:** you shimmy the rim, chain the ray ledges, surf the
     trough, and leap horn to horn with a twirl. The plane fits through
     the ring (`WorldScale.opening`).
   - **relic_torana:** live SwingRopes hang from the lintel's soffit, and
     you chain swing releases onto the lintel's top. The jamb's niches are
     the slow way up. The piece carries its ropes as meta, and the host
     spawns them, both in the place and in the editor.
   - **keel_hung_stair:** it hangs under an isle's keel. Its soffit
     surfs you down and off. A slam on the boss above turns it into a
     walkable stair, which it holds for a while and then turns back.
     Standing on it while it turns carries you, then throws you off past
     `knock_angle` (reuse trap_flip's logic).
4. **Stills** (`tools/shot.py`) of each piece and of the place, looked at
   and fixed until they read right.
5. **Smoke checks** pass: the place, the motif editor, plus one existing
   kit motif and one existing `editor_*` motif in the motif yard.

## Out of scope (note the gap, don't build it)

- The hung stair's updraft trigger. The updraft ring only reaches things
  level with the pilot. Slam is the trigger for now.
- Stealth fixes: crouch lowering the sight points, multi-ray cover, a soft
  landing muffling noise. The pent hood is built to the current one-ray
  cover rule.
- Saving a latched state across reloads.
- Per-piece editor settings beyond what is cheap. If the editor can't store
  a piece's settings yet, the pieces use their card defaults. Add per-piece
  settings only additively, and only if the hung stair needs them to work.

## Order (a suggestion; the first iteration writes the Plan)

pent_hood (static, cheapest), then relic_nimbus (static, arc tuning), then
relic_torana (static plus the rope host), then keel_hung_stair (moving: a
rotating body, the boss handle, editor support for a live piece), then the
place, the routes and the stills.

## Rules

Prototyping (AGENTS.md): smoke checks plus throwaway drive checks in
`scratch/`, no new committed tests, no full suite. The handoff lists any
existing test a change breaks. Models: assess `docs/art/model-budget.md`
for each piece and list the tricks applied.

## Lanes (spec change)

`relic_torana` and `keel_hung_stair` are being built at the same time in
their own worktrees (branches `lane/torana`, `lane/hung-stair`), each by one
agent. The orchestrator merges them into this branch. A loop iteration
does not build either piece: after `relic_nimbus`, stop with the note
"waiting on lanes". The place, routes and stills (Plan 5-6) start after
the merge.
