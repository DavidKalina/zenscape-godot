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

The user is building the wanderer's own wind blast elsewhere; it is not
on main. This loop adds a **stand-in**: a key (pick one free in
`scripts/kit_isle/dev_keys.gd` and the motor's input; say which in the
commit) that fires a straight wind shot from the wanderer the way he
faces, only with `--rune-knight`. Keep it in its own file, small, and
behind one seam: a shot is a node in a group (e.g. `wind_shot`) with its
position, velocity, owner and strength, which the knight reads and
reflects. The real blast should only have to join that group to play
tennis. Both his shot and yours use the same shot script.

The deflected shot's knock on a body is the gust knock; on the wanderer
that's `Gust.knock`.

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
  `play(clip)`, signal `beat_reached(clip, beat)`, `socket(name) ->
  Node3D`, `set_effect(name, on)`. The mind drives the body only
  through these.
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
5. The slash (spec change after the user played task 2): the blade
   tell, the `slash` clip (horizontal and diagonal), the crescent shot
   (a shape of `wind_shot.gd`, same group and seam), the `attack` knob,
   and his return in a rally becomes a slash. Stills of the blade tell,
   both slashes and the crescent in flight; play-loop checks that a
   jump clears a horizontal crescent, a sidestep a diagonal one, and a
   hit knocks.
6. A feel pass on timings from the stills and checks, and a short rendered
   clip (a few frames strung) of one full rally.

## Checks

- Smoke: `studies/aqueduct_isle.tscn` with `-- --no-title --rune-knight`,
  and once without the flag (unchanged isle). Both PASS.
- Play-loop checks through `tools/drive.py` (scratch, uncommitted) for
  every played behaviour above.
- Stills with `tools/shot.py`, always `-- --no-title --rune-knight`.
- Prototype rules: no committed tests, no full suite. The handoff lists
  any existing test the change breaks.
