# Spec: the rune knight's body (lane `body` of loop `rune-knight`)

The body lane of skill `enemy-build`. The mind lane (`iter/rune-knight`,
`docs/design/rune-knight/spec-rune-knight.md`) plays him on a stand-in of
blocks (`scripts/enemies/rune_knight_body_standin.gd`). The user played it
and said he "looks a bit blocky, generic". This lane makes his real body:
a Blender model, rig and clips exported to glb, and a body script that
drops in behind the same API.

Branch `lane/rune-knight-body`, worktree
`.claude/worktrees/lane-rune-knight-body`, branched from `iter/rune-knight`
at ba8684a1. Commits: `ITER(rune-knight): lane body: <task>`. Cap and
budget: the skill's default.

The pattern to follow is the guacharo's body lane: `art/blender/guacharo/
guacharo_build.py` and `guacharo_clips.py` (scripts that build the model
and author the clips, run with Blender headless) and its trail
(`git log --grep='^ITER(guacharo-body)'`). AGENTS.md's Animation and
Models sections are the bar.

## The contract is the mind lane's

The body implements the API and the clips, beats, sockets, effects and
shape in the main spec's **The contract** section and every later spec
section that adds to it (runes and deaths, the brutal parry's `reel`, the
leap). The mind lane keeps changing that spec while this lane runs, so
read it from the mind's branch tip, not your own copy:

```
git show iter/rune-knight:docs/design/rune-knight/spec-rune-knight.md
```

Read the stand-in's code too: it is the working reference for every
clip's timing, beats and forms. Names are final; a clip that needs
different beats to read well is a note in your commit for the trunk, not
a rename.

## What he looks like

A knight carved out of stone, not stacked boxes. Design for:

- **A silhouette you know at a glance** from the game camera at 15 to 30 m
  against sky, turf and the aqueduct's grey stone: a distinct helm (crest,
  visor slit, the line of the eye), broad pauldrons, heavy forearms and
  gauntlets (the blade of wind forms along the right one and the catch
  reads in both), a tabard or plated skirt that gives his walk a swing,
  planted legs. Larger than the wanderer, about 1.6 of his height, far
  short of the Olmec head's bulk (sizes from `WorldScale`, as the mind's
  knobs give them).
- **Stone that matches the isle.** Weathered and chipped, the kit's stone
  look (`scripts/kit_isle/kit_look.gd`, `docs/art/olmec-weathered.md`), a
  little moss in the crevices. Not a new palette.
- **Runes carved into him:** chest, left gauntlet, right gauntlet, as
  grooves that glow from inside (the `rune_glow` effect) and can each
  crack and go dark on their own (`rune_crack` with form `chest`,
  `hand_l`, `hand_r`).
- **Made of pieces that come apart.** He crumbles into a heap and
  shatters off the edge, so the mesh is built from separate stone pieces
  (helm, plates, limb segments) that the body script can throw loose for
  `crumble` and `shatter`, not one welded skin.

## The pick and the look (spec change after the user saw task 1)

The user picked **A, "bastion"** (`art/blender/rune_knight/rune_knight_options.py`):
the fin-crest bucket helm with the T visor, boulder pauldrons, keeled
barrel chest, flared forearm guards and block gauntlets, the slab skirt
with its long tabard. Build that one.

The user, on the look: "He still doesn't match the look of the game
though. Lacks that slight grittiness." He should be of a piece with the
Olmec head and its headless body: the same family of carved stone.

- **Forms like the Olmec's:** chunky, rounded volumes with big soft
  bevels and swollen, simplified shapes, read at a glance; not crisp
  boxes. Exaggerate the proportions a little (the helm, the gauntlets,
  the pauldrons) the way the Olmec's features are. Look at
  `art/blender/face_colossus/colossus_build.py` and the head and body glbs
  (`assets/models/inhaler_head.glb`, `headless_body.glb`) before modelling.
- **The Olmec's stone, exactly:** `shaders/olmec_stone.gdshader`, as the
  rune serpent wears it (`scripts/rune_serpent.gd`, its `runes` knob):
  the gritty weathering (washes, rain streaks, flecks and pits, cracks,
  chipped pale high points, grime in crevices, a hint of lichen), and the
  runes cut in as lit grooves (`shaders/rune_serpent_runes.gdshaderinc`).
  The mesh carries what that shader reads: rest position in UV/UV2 (so
  the grain rides on the skinned body), baked occlusion in vertex alpha,
  rune data in CUSTOM0/CUSTOM1. Read `docs/art/olmec-weathered.md` in
  full. Add to the shader only behind a new knob that defaults off, so the
  Olmec, its body and the serpent are unchanged.
- **Real chips at the edges:** a few geometric chips and broken corners
  on his plates (the shader paints the rest); the user's eye goes to
  edges first.
- **Judge him beside the Olmec:** task 2's stills include him and the
  Olmec head (or its body) in the same light, at the same range.

## Model fixes before the rig (spec change after the user saw task 2)

The user approved the bastion in the Olmec's stone and asked for these
before the rig (task 2b):

- **The visor reads.** Cut the T slit deeper and give it a faint inner
  glow, like the Olmec's eyes: dim at rest, lit while he watches or
  tracks you (an `eye_glow` effect on the body; the trunk wires it to the
  mind's notice and tracking). The helm should have a face from the game
  camera.
- **The glyphs upright** on their tablets (they sit turned 90 degrees).
- **Not murky backlit.** Lift his stone tone so he reads as well as the
  Olmec head against a bright sky, by the material's knobs or his own
  tint, not by changing the shared shader's defaults.
- Triangle trim waits for task 6's budget pass.

Stills: the same views as task 2 (`game_sheet`, `game_close`), backlit
and sunlit, beside the Olmec, so the user can compare before and after.

## Tasks (the first iteration orders these; keep each one a checkpoint)

1. **Silhouette options.** Three distinct takes on him, blocked out in
   Blender at his real size, rendered from the game camera's distance and
   up close, beside the wanderer and the stand-in. The user picks one (or
   mixes) before any detail. Stop after this task for the pick.
2. **The model** of the picked take: pieces, carved runes, materials,
   rendered turntable and in the isle's light (a still in the game, on
   the deck).
3. **The rig and the first clips:** `idle`, `walk`, `turn`, `notice`,
   with planted feet and weight; stills of key poses and a clip strip.
4. **The fight clips:** `gather` (both forms), `slash` (`level`, `high`),
   `throw`, `catch`, `return`, `skid`, `teeter`, `reel`; anticipation,
   holds and follow-through, beats as timeline markers.
5. **The end and travel clips:** `kneel`, `fall`, `leap` (`down`, `up`),
   and the `crumble` and `shatter` break-up of his pieces.
6. **The body script** (`scripts/enemies/rune_knight_body.gd`) on the glb,
   implementing the API; the mind chooses it by default, the stand-in
   behind `--rune-body=standin`. Every mind-lane driver passes on the real
   body. The model-budget assessment (`docs/art/model-budget.md`) with
   triangle and frame-time estimates, and the lane's **Notes for merge**.

## Checks

- Blender scripts run headless and export cleanly; the glb imports with
  no errors (headless import).
- Stills (`tools/shot.py`, `-- --no-title --rune-knight`) of each task's
  work in the isle; open them and judge them against the animation bar.
- Smoke `studies/aqueduct_isle.tscn` with and without `--rune-knight`.
- From task 6, the mind lane's play-loop drivers on the real body (they are
  uncommitted: copy them from `../iter-rune-knight/scratch/rk_*.gd`).
- Prototype rules: no committed tests, no full suite.
