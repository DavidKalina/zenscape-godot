---
name: enemy-build
description: Build a new character or enemy as two lanes, a mind (behaviour, proved by play) and a body (Blender model, rig, clips), joined by a contract. Use when the user asks to make, greybox or animate a new enemy or character.
---

# Enemy build

A character is two lanes that meet at a **contract**:

- **Mind**: states, senses, moves, attacks, the player's counter. Proved
  through the real play loop and input path.
- **Body**: the model, rig, clips and effects. Proved by eye in rendered
  stills.

The contract lets each lane build against the other before it exists:
the mind plays a stand-in body that honours it, and the body authors clips
to its beats. Both lanes go to **Opus** (AGENTS.md, Subagent models).

## 1. The card

Write the spec, `docs/design/<slug>/spec-<slug>.md`, from the user's
concept and answers: what done looks like, in what the user plays and
sees. It names:

- **Size**, from `scripts/world_scale.gd` (a multiple of the wanderer's
  height or the plane's span, never a copied metre figure).
- **Home**: the scene and spot he lives in, and the flag that places him
  (off by default, so nothing else changes).
- **Moves**: each one with its **tell** (what the player sees before it)
  and its **counter** (what the player does about it).
- **His end**: how he's worn down (read off his body, not a bar), each
  way he dies, and what he drops: a ledger objective
  (`docs/design/ledger/round1.md`) that keeps him dead once taken.
- **Code**: his script in `scripts/enemies/<slug>.gd`, his knobs in one
  dictionary at its top so the motif editor can adopt him later.
- **The contract** (below).

Commit it as the loop's spec (skill `iterate`, Set up).

## 2. The contract

A section of the spec. It is the only thing the two lanes share, so
every name in it is final once a lane has built on it; changing one is a
`spec change` commit and a note to both lanes.

- **Clips**: name, length, loop or not, and its **beats** (named times
  the mind waits on, e.g. `throw.release`, `catch.hold`, `walk.plant`),
  each move's tell and hold drawn from the animation bar in AGENTS.md.
- **Sockets**: named attach points (`hand_r`, `chest_rune`) where the
  mind hangs shots, effects and grabs.
- **Shape**: collision capsule, eye height, reach, stride.
- **Effects**: each switch the mind throws on the body (rune glow,
  gathered wind) and what it shows.
- **The body's API**: one small script the mind calls,
  e.g. `play(clip)`, `beat_reached(name)` signal, `socket(name) ->
  Node3D`, `set_effect(name, on)`. The stand-in and the real body both
  implement it.

## 3. Mind lane

A loop (skill `iterate`) on `iter/<slug>`. Its first task builds the
**stand-in body**: primitives in the right size and silhouette, the
sockets in place, `play(clip)` driving procedural key poses timed to the
contract's beats. Every later task plays through that API, so the real
body drops in without the mind changing. Each played move gets a
throwaway check through `tools/drive.py`, each look a still.

## 4. Body lane

Opens when the user has played the greybox and keeps him, unless the
user asks for both at once. A lane in its own worktree (`lane/<slug>-body`,
skill `iterate`, Split first), building only from the contract and the
stand-in's stills:

- Model and rig in Blender (`art/blender/`, `plane_build.py` is
  the pattern), clips authored to the contract's names and beats, beats as
  timeline markers, exported to glb.
- A body script implementing the contract's API on the glb.
- Rendered stills of every clip's key poses and a clip strip, judged
  against the animation bar.
- Its handoff lists which `docs/art/model-budget.md` tricks apply, with
  triangle and frame-time estimates (AGENTS.md, Models).

A clip that needs different beats to read well changes the contract by a
`spec change` commit; the trunk re-tunes the mind to it.

## 5. Trunk

After the body lane merges into `iter/<slug>` (skill `iterate`, Split
first, merge step), the loop goes on:

1. Swap the real body in for the stand-in behind the same API; the
   stand-in stays as a flag for debugging.
2. Procedural layers on top of the clips: feet planted on the real
   ground, hands met to the real target, look-at.
3. Re-tune the mind's timings to the real clips; re-run its play-loop
   checks.
4. A rendered clip of each move, start to finish.
