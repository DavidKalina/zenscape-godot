# The Weeper, round 1 (2026-10-15)

A stone mourner that only moves while the camera isn't looking at it. Seen,
it is frozen stone. Unseen, it closes on you one snap at a time. Each snap
sets it down nearer in a new pose: mourning with its face in its hands,
hands lowering, head turned to you, arms reaching. You never see it move.
You hear it. A grind of stone comes from where it went, a little grit falls
off its shoulders and a puff rises at its hem. When it gets within reach it
gives a deeper grind, and if you still don't look, it comes at your back and
shoves you on: one heart, and the shove bends toward the nearest rim. This
is feature `weeper` of the game-feel round (items-contract.md). It is on by
default; `--no-weeper` or `--loot=off` turns it off.

## Play it

```sh
# alone, in its yard (the enemy yard's isle over the drop, plus four columns)
godot --path . res://studies/weeper_yard.tscn -- --no-title [--weepers=2]
# in a run, mid layer (seed 12 region 2 lays two; see the sweep below)
godot --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=12 --region=2
# force N on any layer
godot --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=11 --region=2 --weepers=2
```

In the yard: turn the camera away (hold right mouse or use the right stick)
and walk off south. Listen. Look back to freeze it. Stand on the spit with
your back to it and it will throw you off the side. R puts everything back.
F1 shows each Weeper's state (seen or not, distance, snaps, blows, pose).

## How it works

- `scripts/enemies/weeper.gd` extends the enemy base (enemy.gd) and lives in
  the stage's EnemyField, so it is stepped, reset and pushed out like the
  others. Its blow goes through `PilotMotor.knock` plus `harm("a Weeper")`,
  which the run loop turns into hearts.
- **Seen** means any of five marks (hem, chest, crown, both sides) lands on
  the real camera's screen (`get_viewport().get_camera_3d()`), grown by
  SEEN_MARGIN (8%). That margin lets a camera that is swinging round meet it
  already frozen. Past CLEAR_NEAR (16 m), a mark hidden behind stone doesn't
  count as seen. Inside 16 m, anything on screen counts as seen even behind
  a pillar, so it gets no cheap shots out of what the camera's own walls
  hide.
- **Snap**: once it has been unseen for GAP (0.75 s, give or take 0.2), it
  moves up to STEP (2.6 m) toward him, about 3.2 m/s on average. He runs at
  4.8 m/s, so running gets you away but climbing doesn't. The ground has to
  be there the whole way (sampled every 0.45 m), each step can climb at most
  RISE (1.2 m) or drop at most DROP (2.6 m), there can be no wall in the way,
  and the new spot must also be unseen. If straight ahead fails it tries
  turning ±0.45 and ±0.9 rad, and a shorter step. If nothing works, it
  waits. It never comes closer than the lunge's edge (LUNGE*HOLD_OFF).
- **Lunge**: it strikes only when he is within LUNGE (4.6 m flat, 1.4 m up
  or down), it has been unseen for LUNGE_BEAT (0.9 s) since its last snap,
  it is out of the camera's frame altogether (being behind a wall isn't
  enough), and nothing stands between them. It lands BEHIND (0.9 m) at his
  back in the seize pose, knocks him OUT 4.2 m and takes a heart. The knock
  is bent up to EDGE_BEND (0.9 rad) toward the nearest rim within 7 m. Then
  it rests for REST (3.5 s). While resting it isn't solid, because it has
  just been set down between him and the camera and would otherwise drag
  the camera in against its back.
- It wakes when he is within WAKE (32 m flat, 8 m up or down). While he is
  down or thrown, it waits.
- Why the high camera matters: the camera sits about 5.7 m behind him and
  4 m up, looking down, so a ring of ground round him is always on screen.
  Once it reaches the bottom edge of the frame it freezes there and becomes
  a statue you keep glimpsing. That's why it gets a 4.6 m lunge from just
  off the frame, with the heavy grind as its warning. It is most dangerous
  while you climb, look ahead to line up a jump, or stand in tight
  underground spots where the camera gets drawn in.
- **Laying** (`scripts/roguelike/layer_weepers.gd`, at dress time from the
  plan): none before region 2. In region 2 it lays 0/1/2 Weepers with
  weights 0.3/0.5/0.2, and from region 3 on 0.1/0.5/0.4. They go on arena,
  perch or cover sockets (room 1.5 m or more), off the base, at least 26 m
  from the spawn, 12 m from the gate, ram and heads, one per isle, at least
  24 m apart, facing the spawn. A Weeper appears when its isle's ground
  appears. Sweep (sprawl, seeds 9-14): region 1 lays none; region 2 lays
  1,0,0,2,1,1; region 3 lays 2,1,0,2,1,1.
- **Hooks** in shared files: one in `layer_stage.gd`, marked `# [weeper]`
  (a preload and `LayerWeepers.dress(self,layer)`). Nothing else shared was
  touched.

## The look

`scripts/enemies/weeper_look.gd` carves it in code, with no Blender clip,
because it is never seen moving and only snaps between key poses (POSES).
The robe, mantle, hood and sleeves are turned profiles with drapery folds
cut round them, and the fold valleys are baked darker as crevices. The face
is a worn oval in a hollowed hood. The forearms are capsules and the hands
are long and flat. It wears the Olmec's weathered basalt
(`HeadLook.stone_material()`, shaders/olmec_stone.gdshader) with the rest
position in UV/UV2, coloured as one block with no masonry cells. It stands
1.3 times the wanderer's height (EnemyField `numbers().unit`). There is no
glow, nothing spiky; the menace is in the stillness and the reaching.
Every snap varies each joint by up to 0.1 rad and sometimes mirrors the
pose, so no two poses are the same.

Model budget (docs/art/model-budget.md): about 1.6k triangles across 9
mesh parts. Robe 22×10 segments, hood 16×6, mantle 22×5, sleeves 12×4.
- **Vertex-colour grime**: applied. The fold valleys, hem, sleeve mouths
  and face hollow are baked into COLOR and its alpha, which the shader
  reads as crevices. It costs nothing at run time.
- **Rigid parts on pivots**: applied. The parts are rigid meshes on Node3D
  pivots, with no skinning cost.
- **Import LODs**: not applied. These are ArrayMeshes made in code with no
  LODs. At 1.6k triangles and 0 to 2 per layer, LODs would save under 3k
  triangles on screen, which is negligible. If it ever goes to Blender,
  bake it through ImporterMesh `generate_lods` the way HeadLook `_dressed`
  does.
- **Sculpt high, bake low / parallax**: not applied. The weathering comes
  from the shader's solid noise. A baked normal map would sharpen the folds
  up close for about 0 ms. Worth doing if the look is promoted to a
  Blender model.
- **Silhouette geometry**: partly applied. The folds break the outline, but
  there are no chips on the hood or hands yet.

## Proven

- Smoke (headless, no errors): `studies/weeper_yard.tscn`,
  `studies/enemy_yard.tscn`, and `studies/run_layer.tscn --frames 900`
  with `--shape=sprawl --seed=11` (region 1, no Weepers),
  `--seed=11 --region=2 --weepers=2` and `--seed=12 --region=2`.
- `scratch/weeper_yard_check.gd` uses the real loop, the camera (turned with
  the `look_left`/`look_right` actions) and stick input:
  - It stays frozen for 180 frames while faced.
  - It snaps after you turn away and run off.
  - With your back to it on the spit it closed 27 m in 10 snaps, struck and
    threw him off the spit's side (the rim bend).
  - Looking back froze it for 180 frames.
  - A per-frame watcher checked every snap against the drawn camera with no
    margin: 14 snaps, none seen moving.
- `scratch/weeper_run_check.gd` (run_layer, seed 11, region 2,
  `--weepers=2`, its isle stood on demand): it snapped 3 times from 9 m and
  struck. Hearts went from 4 to 3 through the run loop and he was knocked
  down a 5 m ledge. No snap was seen moving.
- Rendered stills (`scratch/weeper_run_shot.gd --rendered`) at gameplay
  range in the shrine doorway, and the blow from the play camera.

## Rough

- Two problems from the run-layer driver:
  - The look-back step (hold `look_left` until it's seen) never found the
    Weeper. He had been knocked 5 m down, below it, and the check "seen it
    held still" passed without testing anything. The freeze is proven in
    the yard only.
  - "Never seen moving" was checked over only 4 snaps there.
- The layer check stands the Weeper's isle on demand rather than walking
  there, because isles stand only as he comes near. The yard covers the
  rest.
- With the high camera it rarely gets within reach on open ground while you
  watch the way ahead. It wins on climbs, on narrow spits and in tight
  corners. Whether LUNGE (4.6 m) is too long or too short needs play.
- The sounds are synth placeholders (`EnemyYard._synth`): a grind, a near
  grind and the blow.
- The robe's lathe shape is chunky up close, and the forearms and hands are
  plain capsules. Under the underground's warm light the stone reads
  sandy, the same as the kit. It is fine at gameplay range; a sculpted
  Blender version would sell it.
- You can't push it or topple it yet. The brainstorm's "toppled Weeper
  becomes a lintel" is not done.
- It has no line on the layer card (`LayerWeepers.card` exists but isn't
  wired into the sprawl or ring cards).
- The plane's wide camera: while he flies it keeps hunting his last feet.
  This hasn't been tested.

## Existing tests it may break

None known. The Weepers are added to the stage's EnemyField only on region
2 and later (or with `--weepers=`). Region 1 layers, the enemy yard and
tests/test_enemy_ram.gd are untouched. A test that counts a mid layer's
`EnemyField.enemies` would now see the Weepers too. The full suite was not
run.
