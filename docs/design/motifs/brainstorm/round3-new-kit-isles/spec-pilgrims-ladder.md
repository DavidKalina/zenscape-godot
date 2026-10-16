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

9. **The Cellar is safe.** Reaching it down the stair is the escape, so
   the guacharo must not reach a pilot standing on the Cellar. Pull its
   home or range in, or stop it following below the Crown. Then the stair
   drive's "still safe on the Cellar" check must pass. The plinth's
   near-black shadow side is lighting, not stone, so the dressing pass
   (item 8) should break it up with growth and wear. The two plane tokens
   stay unplaced: there's no token the plane can take.

10. **Orchestrator's look at part 1** (`captures/shots/pl/dress/a3_Threshold_three.png`):
    it still reads barren. The ruins are small dark dots scattered over a
    big flat orange plate, all about the same 2.5 m height. Part 2 should
    add height and mass:
    - trees and shrubs in clumps;
    - one taller ruin landmark per isle (an arch, a pier left standing, a
      wall end with a lancet), within the route and strip rules;
    - growth climbing the stone.

    Find out why the turf reads saturated orange (the yard's palette, the
    season or the flora tier) and whether the place can ask for greener
    turf. Fix it here if it's a per-place setting; report it if it's
    global.

11. **The plane in the scene (the user, after playing the dressed place).**
    The user wants to play the same scene with the plane. The motif yard
    parks no plane today (`studies/motif_yard.gd` `park_home()` is a no-op:
    "it would stand on the motif"). Add an opt-in yard flag, e.g.
    `--plane`, that parks the plane on the motif's landing strip (this place
    reports a landing run on Threshold, x -45..-3), the way the game parks it
    beside the pilot. He can board it, take off, fly the gate and the ring,
    and land back on the strip. With the flag off, the yard behaves as
    before. Prove it through the real play loop and input: board, take off,
    fly a lap, land on the strip by hand. Also check, by flying it, the open
    question from the handoff: the strip's clearance from the trees. Take
    stills of the plane parked on the strip and in the air over the place.

## Rules

Prototyping (AGENTS.md): smoke checks plus throwaway drive checks, no new
committed tests, no full suite. The handoff lists any existing test a change
breaks. Each iteration does one task and commits it. The budget hook may
stop an iteration midway; the next one carries on from its Notes.
