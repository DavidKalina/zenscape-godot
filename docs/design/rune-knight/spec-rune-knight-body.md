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
   body. The drivers (list and commands in the mind's commit bd228a3a)
   read a few stand-in internals: `body.clip`, `body._sent`,
   `body._flying`, `blocks_at_rest()`. Give the real body the same, or
   edit the drivers minimally; say which in the commit. The model-budget assessment (`docs/art/model-budget.md`) with
   triangle and frame-time estimates, and the lane's **Notes for merge**.

## Model budget (task 6c)

Counted headless from `assets/models/rune_knight.glb` and the dressed look
(`scratch/rk_tris.gd`, uncommitted): **28,776 triangles in 43 pieces, 48
surfaces** (helm 3: stone, slit, eye; each rune tablet 2: stone, rune; the
rest 1). Every piece is a skinned mesh weighted wholly to one bone. The
heaviest pieces are the tabard slabs (1,020 each), belly and belt (~960),
helm and chest (~900); the lightest the thumbs and gauntlet tablets (340).
The look's `generate_lods` gives a chain summed over the pieces of 14.4k,
7.2k, 3.5k, 1.7k, 0.84k, 0.37k triangles.

Frame-time figures below are estimates from those counts, not measured on
a GPU (headless can't): he is one figure on the isle, so his cost is mostly
draw calls and skinning, not triangles.

| Trick | Applies? | Estimate |
|---|---|---|
| Import LODs | **Yes, done.** The look generates LODs per piece. From the game camera at 15-30 m he is ~60-120 px tall, which picks roughly the 3.5k-7k level instead of 28.8k. | ~22-25k tris saved at play range (and in the shadow pass); under 0.05 ms GPU. A visibility range doesn't apply: there is one knight. |
| Silhouette geometry | **Yes, done.** Chipped corners (`chunks`) and broken edges on the plates; the shader paints the faces. | Already in the count: chips are a few dozen tris per piece. |
| Rigid parts on bones | **Applies, not done.** Each piece already moves rigidly with one bone, but through 43 skinned meshes. As meshes on `BoneAttachment3D`s they would skip 43 skinning passes a frame, and the break-up would no longer need to drop the skin and rebuild the pose (`rune_knight_breakup.gd` `_posed`). | 0 tris; ~0.1-0.2 ms CPU+GPU a frame for skin updates. Cost: re-export with pieces parented to bones, and the look's rest-position UVs taken in bone space plus the bone's rest. Worth doing if the knight shows in a profile; not before. |
| Triangle trim | **Applies, cheap.** Flat faces carry a 0.1 m grid (`SPACING`) with 3 round steps per arris, for the `shape` swelling and the wear noise. 0.14 m spacing on the flat faces keeps the bevels. | ~30-40% off the base mesh (~9-11k tris); negligible frame time at play range, since the LODs already cut him there. Matters only close up. |
| Sculpt high, bake low | **No.** His grain, grime and runes are procedural on the rest position (`olmec_stone.gdshader`), with no texture UVs to bake into; he is already in the 5-15k band at LOD1. | Would save ~14k tris close up (<0.02 ms) for an unwrap and texture set that fights the shared shader. |
| Parallax depth | **No.** The shader's pits and cracks already read on a 1.9 m figure; parallax costs per-pixel loop work on every stone pixel. | Would add cost (~0.05-0.1 ms full screen close up), not save it. |
| Vertex-colour grime | **Yes, done.** Occlusion baked in Blender into COLOR_0, kept in vertex alpha for the shader's grime and crevice moss. | Free; no AO texture or extra pass. |

The biggest cost is **draw calls**: 48 surfaces, drawn in the depth
prepass, the colour pass and each shadow cascade he is in, so ~150-250
draws, roughly 0.2-0.4 ms CPU. Merging pieces would cut that but breaks
the crumble and shatter (each piece must move on its own). One cheap win if
needed: `cast_shadow` off on the thumbs, tablets, lames and cuffs (12
pieces, ~16 surfaces) saves their shadow draws with no visible change at
play range.

## Notes for merge (body lane into iter/rune-knight)

- **The real body is the default.** `rune_knight.gd` builds
  `rune_knight_body.gd`; `--rune-body=standin` brings back the blocks. The
  real body shares the stand-in's CLIPS, LEAP, SOCKETS and numbers (consts
  read off `rune_knight_body_standin.gd`), so a timing change made in the
  stand-in reaches both. Keep the stand-in file.
- **Driver internals.** The real body names what the drivers read:
  `clip`, `clip_form`, `clip_time`, `_sent`, `_flying`,
  `blocks_at_rest()`, `feet`, `effects`, `crack_t`, `spills`, `broken`,
  `_root_v`. One driver changed: `rk_parry.gd`'s `stand_ahead` (and
  `rk_brutal`, which extends it) stands the wanderer 0.22 m to his right
  on the real body, because the real slash leaves the blade 0.22 m further
  right (x 0.80 vs 0.58 at release) and the knock ran him off the deck's
  side. The mind's copy in `../iter-rune-knight/scratch` doesn't have it.
- **Spills from wide hands.** The real `reel` throws the gauntlets 1.19 m
  out (the deck is 1.25 half wide), so a rune further out than
  `SPILL_WIDE` (0.25 of his height) sprays back in toward him from a
  point pulled half way in; the stand-in sprays from the hand.
- **Streaks.** The real body has its own gather and blade numbers
  (`GATHER_REACH` 0.8, `GATHER_WIDTH` 0.055, `GATHER_ON_BLADE` 0.45,
  `BLADE_WIDTH` 0.1); the stand-in keeps 1.15 / 0.085 / 0.085. Tune the real
  body's in `rune_knight_body.gd`.
- **The shared shader.** `olmec_stone.gdshader` gained `split` (0..1,
  default 0): a seam across a rune tablet's face for `rune_crack`. At 0 the
  Olmec head, its body and the rune serpent are unchanged. His stone lift
  (fill, rim, grime) is on his own material only.
- **`eye_glow`.** The body lights the visor's eye itself at `notice`, eases
  it back to rest on `walk` and puts it out once he kneels. The mind never
  calls `set_effect("eye_glow", ...)`; the trunk wires it to tracking (on
  while he tracks or winds up at you, off when he loses you) if notice and
  walk aren't enough.
- **Break-up.** A crumbling piece stops drifting over a drop deeper than
  0.4 m below his base (`rune_knight_breakup.gd` LEDGE), so pieces don't
  roll off the deck's side when he kneels near the edge.
- **Untracked `.uid` files.** Godot writes `.uid` files for the loop's new
  scripts (the mind's and the body's, e.g. `rune_knight_body.gd`,
  `rune_knight_breakup.gd`, `rune_knight_look.gd`); neither lane committed
  them. The trunk commits them once, after the merge's import.

## Checks

- Blender scripts run headless and export cleanly; the glb imports with
  no errors (headless import).
- Stills (`tools/shot.py`, `-- --no-title --rune-knight`) of each task's
  work in the isle; open them and judge them against the animation bar.
- Smoke `studies/aqueduct_isle.tscn` with and without `--rune-knight`.
- From task 6, the mind lane's play-loop drivers on the real body (they are
  uncommitted: copy them from `../iter-rune-knight/scratch/rk_*.gd`).
- Prototype rules: no committed tests, no full suite.
