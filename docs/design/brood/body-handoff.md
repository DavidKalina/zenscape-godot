# Handoff: the stone guy's body (lane `brood-body`)

Branch `lane/brood-body` (from main). The skill's body lane plus the
trunk's first step: the model is in, the greybox behind a flag.

## What was built

- **Contract**: `body-contract.md` (clips, lengths, loops, beats, how each
  is driven, sockets, shape, effects, the API).
- **Model + bake**: `art/blender/brood/brood_build.py`. Ten rounded-box
  pieces (trunk, head with brow, eye pits and mouth crack, upper arms,
  fists with knuckles, legs, feet). The low mesh is 1,764 tris and keeps
  the big lumps and chips on its outline. The high mesh is 201k tris with
  cracks, nicks, pits and grain, painted with stone, grime, moss in the
  upward crevices and worn edges. Cycles bakes colour, a tangent normal
  map and AO (pieces apart, so the AO holds in any pose), 512 px. AO is
  multiplied into the colour. Out: `assets/models/brood_stone_guy.glb`
  (textures embedded; Godot extracts them next to it) and
  `brood_clips.json`. The maps as files go to `art/blender/brood/bake/`.
  Rebuild: `python3 tools/blender.py run art/blender/brood/brood_build.py [-- --render=scratch/r]`
  (about 20 s; `--render` adds Workbench sheets of each clip).
- **Clips**: `art/blender/brood/brood_clips.py`, 17 clips as key poses with
  holds, Hermite eased. Squash and stretch are bone scales (the body about
  his feet, arms along their length). Follow-through is computed: the head
  lags the lean and bob, the fists trail the swing. Beats are pose markers
  in the .blend and go into the json.
- **Body**: `scripts/brood/stone_guy_body.gd` implements the API. It uses
  one shared material and an AnimationPlayer stepped by hand. Guys past
  22 m step every 3rd frame. Beats are checked only while something
  listens. There is a `daze` head-loll layer, and sockets are made on
  first ask.
- **Swap**: `stone_guy.gd` uses the body by default. `_animate` maps each
  state to its clip: the mind's own clock for wake/rise/sink/mantle/leap,
  distance moved for walk/haul/climb (climb runs backwards going down),
  and a landing squash on fall -> walk. The mind's movement, rays and
  timings are untouched.
- **Poses study**: `studies/brood_poses.tscn` (`--clips=a,b --n=6
  --view=three|side|front|back --live --close`).

## See it

- `./run-heist.command`, bag the egg: the brood come out of the court's burrows.
- `python3 tools/shot.py studies/brood_poses.tscn -- --clips=walk,climb --no-title`
- **Flag**: `--brood-greybox` brings back the old block body (it also
  comes back if the glb is missing).

## Proof

- Headless import, 0 errors. Smoke 4/4 with 0 errors: `heist_level`,
  `aqueduct_isle`, `bag_study`, `brood_poses`, all `--no-title`.
- Real loop (`scratch/brood_heist.gd`, uncommitted): the heist's brood
  woken, two pieces bagged, jumps. Clips seen: rise, look, walk, idle,
  climb, mantle, drop, land, cling, sink. The same run with
  `--brood-greybox` is clean. leap/ride (the plane's bag in flight),
  haul and shake were not caught in a sampled tick; they are proved in
  stills only.
- Stills (`docs/design/brood/stills/`, in this worktree only: the repo
  git-ignores images under docs/ and art/): `close.jpg`,
  `clips_wake_haul_climb_cling.jpg`, `clips_mantle_land_shake_leap.jpg`,
  `strip_side_walk_to_land.jpg`, `heist_walk.jpg`. Full sets are in
  `captures/brood/` (`strip_a/b/c.png`, `key_a/b.png`) and the heist
  films in `captures/drive/brood_heist_01_*_sheet.png` (git-ignored).

## Cost, and how many on screen

60 guys in the heist court, headless: the brood step is 1.16 ms with the
body vs 1.0 ms with the greybox, and wall time per frame is about +0.3 ms.
On the GPU: 60 x 1.8k = 106k tris in one draw call per guy. The greybox
was about 12 box meshes a guy (720 draw calls for 60), so the body is
lighter on draw calls. 60 on screen is comfortable; 100+ should be fine
(not measured rendered).

## model-budget.md tricks

- **Sculpt high, bake low**: applied. 201k -> 1.8k tris a guy (about
  12M tris saved at 60 guys). Two shared 512 px textures.
- **Import LODs**: applied (Godot's `generate_lods`, on by default for
  skinned meshes). Guys far off likely draw around 400-800 tris. No
  visibility ranges yet: these small guys could fade past ~60 m for
  another ~0.05-0.1 ms GPU in big crowds.
- **Silhouette geometry**: applied. The lumps, big chips, brow and eye
  pits are on the low mesh; cracks and pits come from the maps.
- **Rigid parts on bones**: applied in spirit. Every piece is rigid (one
  bone, weight 1), but all ten are one skinned mesh. Ten meshes on
  BoneAttachment3Ds would be 10x the draw calls (600 for 60) and 10
  attachment updates a guy per frame.
- **Parallax depth**: not applied. He is under a metre on screen, so it
  would add per-pixel cost for no visible gain.
- **Vertex-colour grime**: not needed. Grime, moss and AO are in the
  baked colour.

## Broken tests

None found. No test references the brood. `test_world_scale_guard.gd`
passes. The full suite was not run.

## Open questions

- He goes quite dark in deep shade (the heist's court at the wake).
  `GLOW_MORE` (2.2 x the greybox's GLOW) in `stone_guy_body.gd` is the knob.
- Feet are not planted procedurally on slopes, and hands are not pinned
  to the real face: the clips are authored to a flat face at his radius.
  Feet-on-ground IK and hands-on-face are the trunk's next step.
- The mind doesn't listen to beats yet. Re-tuning the mind to them is the
  skill's trunk step 3.
- No dedicated daze clip: a dazed guy walks with his head lolling.
- In `haul`, the far arm hides behind the head in a three-quarter view.
- Harness: the first `tools/shot.py` window after a heavy step sometimes
  sat 150 s and exited 2 with nothing saved. A retry worked each time.
