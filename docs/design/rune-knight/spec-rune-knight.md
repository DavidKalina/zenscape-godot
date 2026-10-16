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
3. **He grabs wind and throws it.** A tell you can read from a distance:
   he raises his arms, the air visibly streams into his hands (streaks
   drawn in from round him) and builds into a held ball or crescent of
   wind, about a second. Then he throws it: it flies on an arc (lobbed,
   not straight), slow enough to sidestep or jump. A hit knocks the
   wanderer with the shared gust knock (`scripts/traps/gust.gd`), so it
   can throw you off the aqueduct or across the meadow. Reuse the dragon's
   air-blast ball (`scripts/dragon_air_blast.gd`) or the wind horn's shot
   for its look and flight if they fit; don't copy them.
4. **Tennis.** The wanderer has a wind blast (see "The player's blast").
   A blast that comes at the knight from in front of him, within his
   reach, he intercepts: he catches it (the wind wraps round his hands, a
   short hold so you see it), then throws it back at you, faster than it
   came. You can blast the returned shot back at him. Each return in a
   rally is faster and gives him less time; past his limit he misses it,
   it hits him, and he staggers back heavily (a few steps, off balance; at
   the deck's edge, over it). A blast from behind or the side hits him
   without a catch. What a hit does to him beyond the stagger is the
   user's call later; no health or death yet.

Every shot, his and yours, is a visible thing in the air with a readable
silhouette, and every phase (patrol, notice, gather, throw, catch, return,
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
5. A feel pass on timings from the stills and checks, and a short rendered
   clip (a few frames strung) of one full rally.

## Checks

- Smoke: `studies/aqueduct_isle.tscn` with `-- --no-title --rune-knight`,
  and once without the flag (unchanged isle). Both PASS.
- Play-loop checks through `tools/drive.py` (scratch, uncommitted) for
  every played behaviour above.
- Stills with `tools/shot.py`, always `-- --no-title --rune-knight`.
- Prototype rules: no committed tests, no full suite. The handoff lists
  any existing test the change breaks.
