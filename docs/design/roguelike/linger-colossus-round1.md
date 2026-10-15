# Linger: the colossus, round 1 (2026-10-15)

The linger threat as a colossal Olmec. It's the comparison
to the rune serpent, which is the default linger. Branch
`worktree-agent-a2407892278f47228`, off `roguelike` at a3990ab6. It isn't
merged or pushed.

## What it is

A giant Olmec stands in the void off the layer's flank. He wears the Olmec
head's weathered basalt and the headless body under it, scaled up to a
170 m head. He rises through a cloud bank of his own. How much of him has
risen is the clock. There is no timer on the screen. The clock runs from
the layer's start (play), and he is laid again with each new layer, because
he is a child of the stage.

1. **He rises (60 s).** At 52 s the cloud bank stirs and a deep rumble
   starts: the land-bed loop and land-lurch takes, pitched down to half.
   At 60 s his crown breaks the cloud. He comes up in 6 heaves over 60 s.
   Each heave has a small sink, a heave up past its mark, a settle, a
   lurch, the bank pushed out round him and a tremble on the camera. A
   slow creep between heaves means he is never quite still. By 120 s his
   head and shoulders stand over the cloud. His eyes are dimly lit (warm,
   low energy), and his head turns slowly after the wanderer (at most
   0.7 rad off his facing).
2. **He inhales (first at 126 s, then every 22 s).**
   - **The tell, 3.6 s:** his chest draws up and back, his head tips back,
     his jaw starts to drop and his eyes warm. The bank streams in over
     his shoulders to his mouth. The world's own wind (`_atmosphere`: the
     grass, the trees, the wind trails and the wind's sound) swings round
     to blow toward him and freshens. Streaks run past the wanderer, and
     dust and leaves lift and go.
   - **The draw, 4.2 s, then 1.8 s letting go:** a stage-wide pull toward
     him, flat.
     - **On the turf:** he is slid toward the colossus at 0.95 x his run
       speed. Walking into it barely holds him. Crouched, the pull is
       x0.12. Unbraced for 1.0 s at more than 0.7 of the draw, he is torn
       off his feet and flung toward the colossus, which costs a heart
       (the motor's `harm("olmec")`, so the card says "by the Olmec").
     - **Hanging from a rim:** he holds. The motor's own rim catch often
       saves a wanderer slid to an edge.
     - **In the air:** he is drawn.
     - **Behind stone:** anything solid within 16 m flat toward the
       colossus, at chest height and 0.5 m above it, cuts the pull to
       x0.08.
   - He keeps rising through stage 2, to about chest-deep by 240 s, so the
     clock keeps reading.

## Play it

```sh
# Just before the first inhale
/Users/davidkalina/Applications/Godot.app/Contents/MacOS/Godot --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=11 --linger=colossus --linger-at=110
# Just before he rises
... --linger=colossus --linger-at=50
# The sky world, where he reads best (a sea of cloud)
... --shape=sprawl --seed=11 --region=3 --linger=colossus --linger-at=110
# Full timing
... --linger=colossus
```

## Knobs

- **Flags:**
  - `--linger-at=S`: the clock starts at S seconds.
  - `--linger-size=M`: his head's height in m (170).
  - `--linger-off=M`: how far past the isles' reach he stands (1.7 head
    heights).
  - `--linger-pull=X`: the pull, times his run speed (0.95).
  - `--no-linger` or `--loot=off`: turns the colossus off.
- **Constants** at the top of `scripts/roguelike/linger_colossus.gd`:
  - the stage times (`RISE_AT`, `RISEN_AT`, `INHALE_AT`, `EVERY`,
    `TOWER_AT`);
  - the rise (`SURGES`, `SURGE`, `RISEN_R`, `TOWER_R`);
  - the breath (`TELL`, `DRAW`, `RELEASE`);
  - the pull (`BRACE`, `SHELTERED`, `TRIP`, `FLING`, `SHELTER`);
  - the placement (`SIZE`, `OFF`, `ALONG`, `EYES_OVER`);
  - the eyes (`EYE_*`).

**Placement:** he stands broadside to the layer's way (start to gate),
abreast of its first third, on the side its isles reach least, facing the
way. Once risen, his eyes are 0.3 head heights under the start's height.
The play camera looks steeply down, so from the start he sits in the band
over the rim. As the way climbs he is below you and still in view.

## Files

- New:
  - `scripts/roguelike/linger_colossus.gd`: the clock, his placement,
    pose, pull, rumble and tremble.
  - `scripts/roguelike/linger_colossus_cloud.gd`: the cloud bank, a
    MultiMesh of 150 billboard puffs.
  - `scripts/roguelike/linger_colossus_air.gd`: the breath round the
    wanderer and the world's wind.
  - `shaders/linger_cloud.gdshader`: a painted puff with a soft depth fade.
- Hooks in `scripts/roguelike/run_loop.gd`, three lines marked
  `# [linger]`:
  - the preload and var;
  - `LingerColossus.lay(...)` in `layer_stood`;
  - `_linger.tick(delta)` in the "play" state.
- He reuses `inhaler_head_look.gd` (the head, jaw, eyes and mouth) and
  `headless_body_look.gd` (the body and its idle clip, the chest and spine
  pitched procedurally, the head on `seat()`). Neither file changed.

## Proved

- `python3 tools/smoke.py studies/run_layer.tscn --frames 900 -- --shape=sprawl --seed=11 --linger=colossus --linger-at=110`
  passed with 0 errors. The same layer without the flag also passed, and
  no colossus is laid there.
- A throwaway play-loop check (`scratch/linger_check.gd`, through the real
  input) went through three inhales on seed 11:

  | Stance | Moved | Result |
  |---|---|---|
  | Standing | 22.5 m | flung once, 1 heart lost |
  | Crouched (`walk_crouch` held) | 2.5 m | not flung |
  | Behind a 2.4 m wall | 0.6 m | sheltered every frame |

- Rendered stills (`scratch/linger_shots.gd`, `captures/linger/`) were
  taken from the play camera and from wider views, in the underground haze
  and in the sky world.

## What's rough

- **The play camera looks steeply down.** He is only fully in the default
  view from where the rim opens toward him. From an isle's middle you see
  his chin and shoulders over the rim, or only the cloud bank. Late in
  stage 2, as he climbs higher, his head leaves the top of the frame
  unless the player looks up. Isles can hide him too (in the region-3
  start, an isle stood in front of him). "Readable from any island" isn't
  fully met. A rule that keeps him in a clear line of sight from most
  isles, or a camera nudge toward him during the tell, is round 2's.
- **The underground haze washes him out at 600-900 m.** He reads as a dim
  shape with warm eyes, which may be right for the dark. In the sky over
  the sea of cloud he reads best.
- **The cloud drawn to his mouth** shrinks into pale blobs in front of his
  face, which looks a little CG. The streaks near the wanderer are still a
  bit crisp.
- **Sound:** the breath is a synthesized noise swell, and the rumble is the
  land foley pitched down. Both are stand-ins.
- **The pull is flat toward him** and ignores the plane and the pocket
  sail. Flying is exempt.
- **No hearts until the fling.** The fling toward the void is the real
  threat.

## Stage 3 hook (round 2)

`stage3(delta)` is called every tick and is empty now. `risen` reaches
`TOWER_R` by `TOWER_AT`.

- **The hand slams:** the body's arms are already under the cloud, rigged.
  Raise one with `BodyLook.reach(side, target, w)` (two-bone IK) onto a
  target isle's rim, then crack it. Use the stage's isles (`layer.isles`)
  and a falling-stone hazard, or the Loose Voussoirs' break, on the slammed
  isle, with a long tell: the hand rising out of the bank, its shadow, the
  rumble.
- **Small Olmecs answering his call:** play the head's "head_call" voice,
  scaled down, from his mouth. Then ask `LayerEnemies` / `BodySpawner` to
  bring a body up a far cliff (`spawn_far_share`) nearest the wanderer.
- Both need a timed beat like `breath_at`.

## Model budget

No new model. The head (inhaler_head.glb) and body (headless_body.glb) are
reused at about 50x scale, with their dressed meshes and generated LODs.
The cloud is 150 quads in one MultiMesh, about 300 triangles and one draw
call, with overdraw at the bank.

- **Import LODs:** these already apply, since `_dressed` generates them. At
  600-900 m the head covers a large share of the screen, so the LODs stay
  near full: about 0 saved. A visibility range isn't worth it for one
  copy.
- **Shadows:** casting is off on every part of him (a 500 m shadow caster
  would be the biggest cost). This saves one large shadow pass, estimated
  at 0.3-0.6 ms.
- **Overdraw:** the cloud puffs are the frame cost to watch. 150 large
  alpha quads near the horizon are estimated at 0.2-0.5 ms at 1440x900,
  not measured. Lowering `PUFFS` or the puff sizes is the knob.
- **Sculpt high, bake low; silhouette geometry; rigid parts on bones;
  parallax depth; vertex-colour grime:** none apply, since the models are
  unchanged. Vertex-colour grime is already baked.

## Existing tests it may break

None expected. It is off unless `--linger=colossus` is given, and the
run-loop hooks do nothing then. `tests/test_run_layer.gd` doesn't pass the
flag. The suite wasn't run (prototype round).
