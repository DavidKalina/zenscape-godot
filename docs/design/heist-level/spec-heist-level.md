# Spec: the heist level, a standalone greybox (loop `heist-level`)

A new standalone level, pure greybox, built to see how the pieces fit
together in one authored place: the plane, the climbing rope, the loot bag
(worn, thrown, slid), the stone brood and the Olmec. The plane sits at the
edge. You make your way in to the main treasure. Taking it wakes the
Olmec and the brood, and you narrowly get out.

The user is open to what comes of it. Part of the point is finding where
the kit, KitLand or generation would need extending to support a level like
this. Note those gaps as you hit them; don't build big new systems to
close them.

Branch `iter/heist-level`, cut from `iter/greed-run` (unmerged), which
already joins the bag, rope, brood, Olmec, banking, escape, death and the
end screen on the crag reach. Read first:
`docs/design/greed-run/handoff.md` and its spec, then the handoffs they
name (`docs/design/bag/`, `bag-brood/`, `bag-hitch/`, `rope/`,
`rope-swing/`, `bridge-snap/`, `crag-reach/olmec-*-handoff.md`).

## Lanes and trunk

No lanes. It's all trunk, in order.

## Where it plays

- A new scene, `studies/heist_level.tscn` (+ `.gd`), launched by
  `run-heist.command` on a throwaway ledger in /tmp, like
  `run-greed-run.command`. On foot beside the parked plane at start, with
  `--no-title` honoured.
- Reuse the greed run's glue (greed meter, rope/bag switch, brood wake,
  Olmec entrance, banking, end screen). Where it lives inside
  `studies/crag_reach.gd`, lift what the heist level needs into shared
  scripts (e.g. under `scripts/greed/`) with the crag reach calling the same
  code, so `--greed-run` on the crag reach plays as before. Keep those edits
  small.
- The season is never winter here (snow showed in the greed-run builds and
  the user flagged it). Find what turns it on and keep it off.

## The level, as the user plays it

About 300–400 m end to end, greybox: KitLand turf and rock, plain boxes and
existing RuinKit pieces, no flora or dressing. Readable at a glance from
the plane: the vault visible as the goal.

1. **The landing.** The plane is parked on landing turf at the outer edge,
   with its bare rope hook (bag hitch). The turf is long enough to land
   and take off by hand (AGENTS.md, Landing turf).
2. **The way in.** A route that needs the rope: a drop to rappel, a wall
   or face to hook and climb, a beam to swing a gap. Calm, no threat. A
   little light loot on the way.
3. **The vault.** A sunken court or chamber with the main treasure and
   loot around it. The bag gets heavy here. The way out of the vault is
   built for the bag: ledges you throw it up before climbing after it, a
   chute or slope you slide it down, a gap you throw it across.
4. **The wake.** Bagging the main treasure (or crossing the greed
   threshold, whichever plays clearer) wakes the brood out of burrows in
   and around the vault and brings the Olmec up a cliff, close.
5. **The way out.** Not the way in. A different route back to the plane,
   again using the rope and the bag (throw it up, slide it down), with a
   rope bridge that snaps (bridge-snap) behind you or under the brood.
6. **The narrow escape.** It should feel like you only just got out. Build
   it from tuning plus a few staged moments, not a perfect chase AI:
   - the Olmec lands where you just were (his `down_show`-style staged
     drop, in camera view);
   - the bridge goes down just behind you;
   - he reaches the landing turf as you take off, or leaps at the plane.
   Tune his pace so a player who keeps moving stays just ahead, and a
   player who stalls gets caught.
7. **The end.** Hitch the bag at the plane and take off. Clearing the isle
   ends the run as banked (the greed run's end screen). Caught: lost, with a
   restart, as in the greed run.

## Handles

Every piece, islet, platform section, loot piece, anchor post, burrow and
staged spot is named `heist/<piece>` through `scripts/layout_overrides.gd`,
so the user can move them in F4. Keep the names stable.

## Rules

- Greybox only. Use existing pieces and systems. If something needs a new
  piece or a kit/generation change, keep it minimal and note it.
- Sizes from `scripts/world_scale.gd` (openings with
  `WorldScale.opening`, walker reach from the wanderer size). Rope pieces
  stay within the rope's length (the greed run found loot deeper than the
  14 m rope).
- Prototyping rules (AGENTS.md): smoke checks plus throwaway play-loop
  checks in `scratch/`, no new committed tests, no full suite.
- Small checkpoints: each task ends in something the user can launch or
  look at.

## Done looks like

- `./run-heist.command` plays the whole thing start to finish: land
  stretch, rope in, vault, wake, escape over a different route, staged
  near misses, take off, end screen.
- A throwaway drive through the real input path reaches the vault and gets
  back to the plane, and a stalled run gets caught.
- Rendered stills: the level from the plane at start, the way in, the
  vault, the wake, each staged near miss, the takeoff.
- `crag_reach --greed-run` still smokes clean.
- The handoff lists where the kit, KitLand or generation fell short for a
  level like this.

## Smoke checks

- `studies/heist_level.tscn -- --no-title`
- `studies/crag_reach.tscn -- --no-title --greed-run`

## Cap

The skill's default.

## Spec change: swing points out of the rock (from the user, after task 3)

The user wants the rope's swing worked into the land itself: structures
growing out of the rock that let you swing around. Do this as the **next
task** (before the vault), so the way out is built round it.

- **Swing points** that carry the rope swing's existing hook line
  (`docs/design/rope-swing/handoff.md`, `climb_rope.gd` `_beam_target`):
  stone arms jutting off cliff faces, dead trees or roots with a branch out
  over a drop, natural rock arches between two masses, a broken ruin lintel
  sticking out. Greybox shapes, each named `heist/swing_NN` through
  `layout_overrides.gd`; a moved or turned one takes its hook line along.
  Keep the shapes in their own new file so they can become kit pieces
  later; note in the handoff what a real kit piece would need.
- **Where:** the way in's gantry beam (`beam_01`) becomes one of them. The
  way out gets the most: swinging round a cliff corner, a chain of two or
  three swings across a big gap, and a swing out from under the Olmec as
  one of the narrow escapes (build these when their steps come; place the
  points now where the way out will run).
- **Check:** swinging with the bag worn (rope in hand). If a heavy bag
  should change the swing, or the switch gets in the way, note it.

## Spec change: the Olmec from main (after task 7's first half)

The user merged new Olmec work to main, now merged into this branch:
`docs/design/crag-reach/olmec-reach-handoff.md` (steps 9-15: walks the
fallen pillar, never stuck, suck_in, `down_show`: a staged drop that lands
where your camera sees him) and `docs/design/crag-reach/olmec-run-handoff.md`
(`run_up`: he sets off at a walk and builds into a run, 5.52 m/s top vs
your 4.8; turns cost him the build). The heist's Olmec inherits both via
OLMEC_KNOBS. Use them for the narrow escape: pace through `run_up` /
`run_top` / `run_turn_cost` (keep moving and turning = just ahead, stall =
caught), and `down_show`'s `_lands_seen` to put the staged drop in camera
view. Re-check task 7's first half (the pillar-foot drop) on the merged
Olmec before building on it. The greed run's under-stuck timer in
crag_reach.gd was renamed `_below_t`/`_below_best` to clear main's
`_stuck_t`.
