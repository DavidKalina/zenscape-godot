# Spec: the rune knight, a greybox enemy (loop `rune-knight`)

A new enemy, greyboxed so the user can play it and judge whether it fits.
The rune knight is a stone knight, taller and broader than the wanderer
but nowhere near the Olmec head's bulk (about 1.6x the wanderer's height,
from `WorldScale`, not a copied number). He patrols the aqueduct on the
aqueduct isle. He grabs wind out of the air and throws it at you as an
arc. When you shoot a wind blast at him, he catches it and blasts it back:
tennis.

Branch `iter/rune-knight`, worktree `.claude/worktrees/iter-rune-knight`.
Cap and budget: the skill's default.

## Done looks like

`./run-aqueduct-isle.command --rune-knight` (or `godot --path .
res://studies/aqueduct_isle.tscn -- --no-title --rune-knight`) puts you on
foot on the isle, and:

1. **He patrols the aqueduct.** He stands on the aqueduct's deck (its
   walkable top, the one the foot route's rope beams hang from;
   `studies/aqueduct_isle_art.gd` `TOP` and the deck's ends) and walks it
   end to end, turning in planted steps at each end. He collides with the
   wanderer: you can't walk through him. Heavy, deliberate walk.
2. **He sees you.** In range and in sight (from the deck or the meadow
   below), he stops, turns to face you and tracks you. Out of sight long
   enough, he goes back to patrolling.
3. **He grabs wind and slashes it at you.** His main attack is an arc of
   air, like a sword beam: a crescent blade of wind cut off his arm, not a
   ball tossed on an arc. The tell, readable from a distance: the air
   visibly streams into his right gauntlet and builds along his forearm
   into a blade of wind (about a second, runes lit). Then a big sweeping
   slash, wound up and followed through, and the crescent leaves along the
   slash's line: wide, thin, flying flat and fast-ish in a straight line,
   its curve the slash's curve. Horizontal slashes you jump over; diagonal
   or vertical ones you sidestep; he picks between them, and the pose
   tells you which before it leaves. A hit knocks the wanderer with the
   shared gust knock (`scripts/traps/gust.gd`), so it can throw you off
   the aqueduct or across the meadow. The lobbed ball built in task 2
   stays as a knob (`attack`: `slash` the default, `lob`), not his main
   move.
4. **Tennis.** The wanderer has a wind blast (see "The player's blast").
   A blast that comes at the knight from in front of him, within his
   reach, he intercepts: he catches it (the wind wraps round his hands, a
   short hold so you see it), then wraps it onto his blade and slashes
   it back at you as a crescent, faster than it came. You can blast the returned shot back at him. Each return in a
   rally is faster and gives him less time; past his limit he misses it,
   it hits him, and he staggers back heavily (a few steps, off balance; at
   the deck's edge, over it). A blast from behind or the side hits him
   without a catch. What a hit does to him beyond the stagger is the
   user's call later; no health or death yet.

Every shot, his and yours, is a visible thing in the air with a readable
silhouette, and every phase (patrol, notice, gather, slash, catch, return,
stagger) reads at a glance in a still.

## The player's blast

The real one is on main now (merged at b6602a4f): **lock-on**
(`scripts/lock_on/foot_lock.gd`: R3 / Tab / middle mouse locks the nearest
`lock_targets` member that answers `aim_point()` and `tall()`) and the
**gust shot** (`scripts/lock_on/gust_shot.gd`: X with updraft charge; a
locked shot homes and calls `hit(at, way, strength)` on its target, its
strength from the charge spent). Read `docs/design/lock-on/handoff-lock-on.md`.
These are the player's side of the knight; extend them additively and
keep the target stone working as before.

- **He is a lock target.** In `lock_targets`, `aim_point()` his chest,
  `tall()` so the marker hangs over his helm, while he stands; off the
  list while he's down off the deck only if that reads better in play.
- **The gust shot knocks him back.** `hit()` shoves him along the shot's
  flat way, farther with more strength, into a heavy stagger (the
  `stagger` clip, planted steps, real weight); at the deck's edge, over
  it, as task 4 built for a miss.
- **Tennis on the real shot.** A gust shot that reaches him from in front
  while he is under his rally limit he catches instead (the task-4 catch,
  then `_send_return`). From the side or behind, or past his limit, it
  knocks him back. Fired while his return is coming at you, your gust
  ball meets it in the air and sends it back at him, the way the stand-in
  does. The gust shot's balls have to be readable by the knight for that;
  the smallest additive seam in `gust_shot.gd` (e.g. its live balls in
  the `wind_shot` group, or a query) is fine.
- **From the meadow:** the deck's buttresses pop a shot aimed from below
  (found in task 4). A locked homing shot should be able to reach him
  from the meadow; fix the line, not the stone.
- **The Z stand-in stays** as a dev key that needs no charge, for checks
  and quick play; X is the game's blast.

## The parry (spec change after the user played the slash)

The wanderer's answer to wind thrown at him. **RB (Q on keyboard), the
updraft button, pressed at the right moment parries a shot and he absorbs
its wind** into his wind gauge (`scripts/updraft.gd`, `scripts/wind_gauge.gd`;
read `docs/design/wind-gauge/handoff-wind-gauge.md`).

- **What can be parried:** any `wind_shot` thrown at him that isn't his:
  the knight's crescents (level and high), his rally returns, the lob.
- **The window:** the press counts as a parry when the shot will reach
  him within a short window (time to contact, a knob; start near 0.2 s,
  and tune by play). A press outside the window is the plain updraft, as
  today (spends a segment, lifts him), so a mistimed parry still has its
  own use against a level slash. A parry press needs no charge.
- **Absorb:** the shot is gone, its wind visibly spirals into him (the
  crescent unwinds into streaks drawn to his chest), a short hit-stop and
  a flash sell the timing, and the gauge gains a full segment (capped at
  full), pulsing as a filled segment does. A late press is a hit as now.
- **The loop it closes:** the segment he absorbs pays for the X focus
  blast back at the knight, so parry then blast is the rally from the
  wanderer's side. Blasting a crescent back mid-air (Z, or X when the
  ball meets it) stays as built.
- **A pose:** a quick guard-and-draw-in on the wanderer while he absorbs
  (procedural is fine for this round; the wanderer's clips are authored,
  so keep it a light layer over them).
- **Code:** its own file (e.g. `scripts/wind_parry.gd`), hooked into the
  updraft press additively: the updraft asks the parry first, then does
  what it does today. Off the isle and without `--rune-knight` nothing
  changes, except that a parry seam other wind can join later.

## Where code goes

- `scripts/enemies/rune_knight.gd`: the knight (body, patrol, sense,
  gather, throw, catch, return, stagger).
- `scripts/enemies/wind_shot.gd`: the shot both sides throw (flight on an
  arc or straight, look, hit, catch, reflect).
- The stand-in blast in its own file.
- `studies/aqueduct_isle.gd`: the `--rune-knight` flag and a small,
  additive hook that places him (the way `--watcher` is placed). Off by
  default; nothing else on the isle changes.

He is not an `enemy.gd` field enemy and not in the motif editor in this
loop (the `editor-enemies` loop is queued separately); keep his knobs in
one dictionary at the top of his script so either can adopt him later.

## Look and animation (greybox)

Greybox: his body from primitives (a blocky helm, a broad chest, pauldrons,
gauntlets big enough to read the catch, legs), stone material from the
kit's look, a few rune lines on chest and gauntlets that glow when he holds
wind. Animate by procedural key poses on those parts (anticipation before
the throw, a hold on the catch, follow-through after the throw, a heavy
settle on each step), not authored Blender clips: those come if the user
keeps him. Note in the handoff which `docs/art/model-budget.md` tricks
would apply to a real model.

## The contract (skill `enemy-build`)

This loop is the mind lane. A Blender body lane opens after the user has
played the greybox and keeps him, so the greybox body is a **stand-in**
behind the API below, and the real body drops in without the mind
changing. Names here are final once built on; change one only by a
`spec change` commit.

- **Body API** (`scripts/enemies/rune_knight_body_standin.gd`):
  `play(clip, form := "")`, signal `beat_reached(clip, beat)`,
  `socket(name) -> Node3D`, `set_effect(name, on)`. The mind drives the
  body only through these. A clip's `form` picks its variant: `gather`
  "blade" (the wind drawn into the right gauntlet; "" the two-handed ball
  of the lob), `slash` "level" or "high".
- **Clips and beats** (lengths are the stand-in's starting values; the
  mind waits on beats, never on its own timers for body motion):
  `idle` (loop), `walk` (loop; beat `plant` per footfall), `turn`
  (`plant`), `notice`, `gather` (`grab`, `full`), `slash` (`release`; the
  windup tells horizontal or diagonal), `throw` (`release`; the lob knob),
  `catch` (`contact`, `hold`), `return` (`release`), `stagger`
  (`plant`, `recover`). Every one-shot clip (all but `idle` and `walk`;
  `turn` loops too) also sends `end` at its length, so the mind can wait
  on a clip with no beat of its own (`notice`) or on its follow-through.
- **Sockets**: `hand_r`, `hand_l`, `hands_mid` (where a held shot sits),
  `blade` (along the right forearm, where the wind blade forms),
  `chest_rune`, `eye`.
- **Shape**: capsule radius and height, eye height, reach (the catch
  range) and stride, all from `WorldScale` and his knobs.
- **Effects**: `rune_glow` (lines lit while he holds wind),
  `wind_gather` (streaks drawn into `hands_mid`, or into `blade` before
  a slash), `wind_blade` (the blade of air along his forearm).

## Tasks (the first iteration orders these; keep each one a checkpoint)

1. His body on the deck and his patrol, with the flag. Still of him on the
   aqueduct.
2. Sense, the wind gather tell and the arcing shot that knocks you.
   Stills of the gather and the shot in the air; a play-loop check that a
   hit knocks the wanderer.
3. The stand-in player blast and the shot group seam. Still of your shot.
4. Catch and return, the rally speeding up, the miss and his stagger.
   A play-loop check of a rally (blast, catch, return, blast back) and of
   a miss; stills of the catch and the stagger.
5. Lock-on and the gust shot on him (spec change after the user pushed
   lock-on and the gust shot to main): lock target, knockback from
   `hit()`, catch and rally on the real shot, the meadow line. Play-loop
   checks through the real inputs (lock key, X with charge set): lock
   him, a hit from the side knocks him back, a hit from in front is
   caught and returned, X blasts the return back, a hit at the edge puts
   him over. Stills of the lock marker on him and the knockback.
6. The slash (spec change after the user played task 2): the blade
   tell, the `slash` clip (horizontal and diagonal), the crescent shot
   (a shape of `wind_shot.gd`, same group and seam), the `attack` knob,
   and his return in a rally becomes a slash. Stills of the blade tell,
   both slashes and the crescent in flight; play-loop checks that a
   jump clears a horizontal crescent, a sidestep a diagonal one, and a
   hit knocks.
7. The parry (above): the window, the absorb into a gauge segment, the
   look and hit-stop, the pose. Play-loop checks through the real RB / Q
   press: a timed press on a level and a high crescent absorbs it and
   fills a segment; an early press is the plain updraft; a late press is
   a hit; parry then X lands a blast on him. Stills of the absorb.
8. A feel pass on timings from the stills and checks, and a short rendered
   clip (a few frames strung) of one full rally.

## Checks

- Smoke: `studies/aqueduct_isle.tscn` with `-- --no-title --rune-knight`,
  and once without the flag (unchanged isle). Both PASS.
- Play-loop checks through `tools/drive.py` (scratch, uncommitted) for
  every played behaviour above.
- Stills with `tools/shot.py`, always `-- --no-title --rune-knight`.
- Prototype rules: no committed tests, no full suite. The handoff lists
  any existing test the change breaks.
