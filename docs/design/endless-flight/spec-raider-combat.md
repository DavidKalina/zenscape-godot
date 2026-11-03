# Spec: raider combat (loop `raider-combat`)

Builds on the raider greybox (`scripts/endless/raider.gd`,
`docs/design/endless-flight/raider-handoff.md`, branch `iter/raider`). It's
still an experiment: smallest playable builds, smoke checks and throwaway
drivers, with no committed tests. Everything stays behind `--raider`.
Use seed 1.

## Done looks like

The user takes off with `--raider` and gets a fight that mixes three things:

1. **Lock-on with depth of field.** Pressing the right stick in (R3), or a
   free key/mouse button for keyboard play, locks onto the raider when it's
   in view and in reach. While locked:
   - the camera keeps the raider in frame without losing the plane, easing
     between them rather than snapping;
   - depth of field focuses at the raider's distance, so the raider is sharp
     and the near and far land soften;
   - a lock reticle sits on the raider.
   Pressing again releases it. Losing the target (killed, far away, or out
   of sight for a moment) releases it too, easing back to the normal camera.
   Flying stays fully in the player's hands. Lock-on is generic: it targets
   nodes that ask for it (a group or a small registry), and the raider is
   the first.
2. **The chase.** The raider flees low and fast through trees and under
   arches (the land's forests and `LandArches` openings), and you trail it.
   Skimming (flying low, close to trees, terrain and stone, threading
   arches: the near-miss meter's own scoring) builds charge **and speed**,
   so a good line closes the gap and a lazy one loses it. With the meter
   full, a surge roll that reaches it knocks it out of the sky (the same
   kill as now). It flies by plane rules (turn rate, bank, ground
   clearance) and picks lines the player can follow; it never leads
   through a gap the player's plane can't fit (`WorldScale.opening`). If
   you lose it, it doesn't vanish: it comes back round.
3. **The dogfight** that exists now (stalk, tell, ram, dodge for meter,
   get knocked, surge-roll kill) stays, and the encounter moves between
   dogfight and chase. For example, after a few passes it breaks off and
   runs low, and if the chase is lost it turns and comes back at you. The
   iteration that builds the mix picks the rule and writes it in its
   Decisions.

Flags so each part can be played on its own:
`--raider-mode=dogfight|chase|mix` (default `mix` once the mix is built).
Lock-on is on whenever `--raider` is.

## Lanes and trunk

These lanes run in parallel, each in its own worktree branched from
`iter/raider`, then get merged into `iter/raider` by the loop's runner:

- `lane/raider-lockon`: lock-on (item 1). Its code goes in its own new
  file(s), e.g. `scripts/endless/lock_on.gd`, with small additive edits to
  the camera, the input map and `studies/endless_flight.gd`. The raider
  joins it with one line.
- `lane/raider-chase`: the chase (item 2), behind `--raider-mode=chase`.
  Keep the chase's steering in its own file where it can (e.g.
  `scripts/endless/raider_chase.gd`), with raider.gd edits small. Add the
  skim speed gain wherever the plane's speed lives (`flight_pace.gd` /
  `sky_plane.gd`), and only while a chase is on.

The trunk, in order, after both lanes are merged:

1. The mix (item 3): the encounter moves between dogfight and chase, with
   lock-on working across both. `--raider-mode=mix` becomes the default.
2. A tuning pass from driven runs and stills: chase distances, how much
   speed skimming gives, lock-on framing, how often it switches.
3. Stills of each part (locked dogfight, locked chase through trees or an
   arch, a kill) and the handoff.

## Checks

- Smoke: `python3 tools/smoke.py studies/endless_flight.tscn -- --raider`
  (and `--raider-mode=chase` / `dogfight` once they exist). Must PASS.
- A throwaway driver in `scratch/` through the real play loop and input
  path for every played change: press R3 through the input path, fly a
  chase, show the gap closing when skimming and opening when flying high,
  a surge-roll kill from the chase.
- Rendered stills (`tools/shot.py`, `-- --no-title`) for lock-on and DOF
  (headless can't show DOF; report it unverified if stills can't be made)
  and for the chase line. Look at them and iterate.

## Cap and budget

The skill's default cap and budget.
