# Spec: pilgrims-ladder (iterate loop)

Build card m1, **The Pilgrim's Ladder**
(`docs/design/motifs/brainstorm/round3-new-kit-isles/motif-m1-pilgrims-ladder.md`),
as a playable place in the motif yard. The user wants to play it. The card is
the design; where it and the code disagree, the code's real numbers win.
Note the change in the commit.

## Done looks like

1. **A plan** of the card, following `.claude/skills/motif-plan/SKILL.md`,
   in `docs/design/motifs/plans/pilgrims-ladder/`. It has real sizes from
   the code, the landing strip, collectibles, the guacharo's spawns and
   wake, and its map page.
2. **The place,** following `.claude/skills/motif-greybox/SKILL.md`: a
   greybox slug `pilgrims_ladder`, played with
   `studies/motif_yard.tscn --motif=pilgrims_ladder`, on the real terrain
   from the start (KitLand isles, RuinKit pieces, sky, light, flora). The
   layout lives in one data table. It has four stepped isles with a clear
   strip on the first, long enough to land the plane by hand (AGENTS.md,
   Motifs).
3. **The four new pieces,** each at its station as the plan places it:
   - `relic_torana`'s ropes lift you off the strip's isle.
   - `relic_nimbus` carries you to its horns.
   - `pent_hood` hides you from the guacharo on the crown.
   - `keel_hung_stair`, slammed from a perch, is the way down.

   The turned stair lies under the turf, so give it a shaft, a built
   plinth or a cliff-step edge (KitLand has no hole cut).
4. **The routes walked** with the real pilot through the real play loop and
   input (throwaway drive checks in `scratch/`, uncommitted): strip to
   crown, and the way down. Then the guacharo threat working against the
   hood's cover.
5. **Stills** (`tools/shot.py`, `-- --no-title`) of each station and of the
   whole place, looked at and fixed until they read right.
6. **Smoke checks pass:** the place in the motif yard, plus one existing kit
   motif and one `editor_*` motif.

## Lanes

- `relic_torana` is merged (commit 5575f797): use the real piece, no
  stand-in. Its code changed the card: ropes hang from iron arms on posts
  along the lintel's top front edge (not the soffit), the lintel slopes
  16 deg, the last rope's backswing release lands on the top, and the slow
  way is three offering steps up the jamb's head. Read
  `git log -1 --format=%B ec376068` before placing it; the plan may need
  its torana numbers updated.

## Spec change after the user played it (strip and populate)

The user played the place at 9ef1e363 and likes it. The ring reads very
well. Now it should lose two things and gain some life:

7. **Strip the merchant and the beetle from this place.** Today the
   merchant's stall spawns on the Halo's perch, and a beetle walks a lane
   on Threshold. Turn both off for `pilgrims_ladder` only: a per-motif
   opt-out, so other places keep them. Don't delete them from the game.
8. **Populate it: it reads sparse and barren.** Do a dressing pass that
   follows `.claude/skills/motif-turf/SKILL.md`. Use existing kit and
   flora only, and keep it additive:
   - ruin and pilgrimage dressing round each station (fallen piers, tomb
     chests, floor slabs, walls and stairs from the kit);
   - growth (vines on the stone, trees and shrubs where they won't block
     a route or the landing strip);
   - life (birds, the wind's movement).

   It must not cover the landing strip, block a route or the plane's
   lines through the ring and the gate, or remove the guacharo's cover
   rule. Re-run the route drives after it, and take before and after
   stills of each station and the whole place. Look at them.

## Rules

Prototyping (AGENTS.md): smoke checks plus throwaway drive checks, no new
committed tests, no full suite. The handoff lists any existing test a change
breaks. Each iteration does one task and commits it. The budget hook may
stop an iteration midway; the next one carries on from its Notes.
