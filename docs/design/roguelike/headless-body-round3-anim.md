# Headless body, round 3: the model and its clips

Rounds 1 and 2 (`headless-body-round1.md`, `headless-body-round2.md`) built
the behaviour on a greybox of boxes on pivots. This round replaces the
greybox with a Blender model and authored clips. The aim is the
Nintendo-like bar in AGENTS.md "Animation". Behaviour, physics and timings
are unchanged, apart from the one new beat listed under the knobs.

## What's in

- **The model** (`art/blender/headless_body/headless_body_build.py` builds
  `headless_body.blend` and `assets/models/headless_body.glb`).
  - A hulking Olmec figure made of rounded masonry courses: a pectoral
    plaque, a belt and loincloth, boss knees, slab feet, big hands with
    fingers and thumbs, and a raw-cut neck stump.
  - It is built with the head's rounded-box method (`inhaler_head_build.py`)
    and is smooth, not faceted.
  - It keeps round 2's size and proportions in head heights (`HH` = 3.36,
    scaled to the head's `size`).
- **Its look in game** (`scripts/enemies/headless_body_look.gd`).
  - The stone is dressed the way the head's is: the kit's stone material,
    per-vertex kit colour, baked crevice occlusion, and moss on the faces
    that point up.
  - The stump's cut is a warmer fresh stone that glows when he tells.
  - The clips run through an AnimationTree that the body drives by hand.
    Each clip is seeked by his own clocks (the walk and climb phases, or
    the state's time over that state's knob), so the clips follow his
    timings instead of setting them. Each state cross-fades in over its
    own fade.
  - Procedural corrections are layered on top with two-bone IK:
    - Climbing, each hand is moved in or out onto the real wall face.
    - Hauling, both hands slap up over the lip and come down on it, with
      a grip sound, a small quake and two dust puffs.
    - Early in the mantle, both hands press on the real lip.
- **The head rides the real stump.** `head_seat()` and `head_tilt()` come
  from the neck bone, so the head bobs and tilts with every clip.
- **A triumph beat.** Once whole, he throws his arms up, holds, then
  thuds both fists down (a quake and a step sound), then goes on. Before
  this round he went straight to listening.
- **The study's HUD** shows the clip now playing.

## How to run it

`run-headless-body.command`, as before. G spawns a body up a cliff, R
resets, and F1 toggles the HUD.

To rebuild the model and clips after editing the build script:

    /opt/homebrew/bin/blender -b --python art/blender/headless_body/headless_body_build.py -- --blend

Then run a headless import. Pass `--out=/tmp/x --no-bake --render=/tmp/x/r
--clips=stride,walk` to render workbench stills of some clips instead.

## The clips

| Clip | State | What it does |
|---|---|---|
| `idle` | listening while whole; roam at a standstill | Two slow breaths and a sigh, a weight shift, the fingers flexing |
| `listen` | listen (headless) | Holds a breath, cups a hand by the stump on one side, then the other, leaning into it. Then "heard": the hand drops, the stump snaps round, the fists close |
| `walk` | roam | A heavy two-step cycle: contact, a held drop with squash, passing, up. Arms swing opposite the legs, the forearms trail, the hips sway and twist |
| `stride` | home (has the head's scent) | Longer steps and a deeper lean, both arms reaching forward toward the head |
| `climb` | climb | Hand over hand: each hand plants at the top of its reach and holds as the body rises past it, then slaps up again. The feet push in counter-step, and the body sways and heaves after each grab |
| `haul` / `spawn_haul` | climb with hands on the lip (`spawn_haul` for a cliff spawn) | Two heaves per loop, held at the top, with the legs scrabbling. The spawn version is wilder |
| `mantle` | mantle | Presses on the lip, gets the right foot up, swings over, raises the foot and stomps (squash 0.86) |
| `windup` | windup | Anticipation, then a deep crouch with the arms swept back, a shiver while coiled, and the release |
| `jump_air` | leap (jump) | Arms thrown up, legs tucked at the peak, arms flung wide, then reaching down for the landing |
| `drop_air` | leap (drop), fall | Arms straight up, fists clenched, legs dangling, a little wobble |
| `land` | land after a jump | A hard squash (0.76), held, a rebound, a settle, then up |
| `drop_land` | land after a drop | A superhero landing: the right fist into the ground, the left knee down, the left arm flung back |
| `reach` | reach (the head coming down) | Arms up to receive the head, trembling as it nears, then guiding it onto the neck |
| `triumph` | triumph (new) | Arms up, a hold, then both fists down with a thud |

This round narrowed the stride's arms. The hands used to splay about 0.9 m
out past the shoulders. Now they reach forward and slightly inward.

## Knobs

These are new in `default_knobs`:

- `stride` (`Look.WALK_STEP` = 0.5 Hh) is a walking step's length.
- `stride_home` (`Look.STRIDE_STEP` = 0.68 Hh) is a step's length while
  striding home.
  - Both step lengths only set the walk phase (the clip and the step
    sound). Movement speed is still `walk` and `home`.
  - The clips are made for these values. Other values make the feet
    slide.
- `triumph` (1.8 s) is the new triumph beat once whole. The thud lands at
  1.34/1.8 of it.

Fades are constants in `headless_body.gd`: `FADE` = 0.22 s by default, and
`FADES` per state (land 0.05, leap 0.08, fall 0.15, mantle 0.12, windup
0.1, triumph 0.08, reach 0.3). `GRAB` = 0.32 s is the slap onto the lip.

In the build script, the clips' timings match the game's knob defaults
(`LISTEN`, `WINDUP`, `LAND`, `MANTLE`, `SETTLE`, `TRIUMPH`). Any knob can
change, though, because the game seeks each clip by its share of the
state's time.

## Captures

The rendered captures are in `docs/design/roguelike/headless-body-anim/`,
which is gitignored (PNGs and imports; each folder's `log.txt` is left
uncommitted too). Each sheet is 8 frames, and each folder holds every 2nd
frame at 60 fps:

- `spawn`: the cliff-spawn haul and mantle
- `climb`: a far view of the climb on B
- `climb_close`: a closer view of the climb on B, from behind and off the wall
- `walk`
- `home`: the stride, after the arm fix
- `jump`: windup, air and land
- `drop`: the drop and the drop landing
- `reachs` (folder `reach`): the reunion and triumph
- `crown`: the whole end, from stride to triumph

The workbench stills of every clip are rebuilt into `/tmp/hb/r` by
`--render`.

## What was verified

- **Smoke check: passes.** A headless import, then the study loaded for
  400 frames headless, with no script errors.
- **Route check: passes.** This was a throwaway headless run through the
  study's own loop at a fixed 60 fps (uncommitted). It went:
  1. The cliff spawn (`spawn_haul`), the mantle and its stomp.
  2. A climb up B (`climb`, then `haul`, then `mantle`).
  3. A ledge jump (`windup`, `jump_air`, `land`).
  4. A drop (`drop_air`, `drop_land`).
  5. Another climb and jump, then the stride home.
  6. The reunion (`reach`) at 114 s, then `triumph`, then whole and
     roaming again.

  The run had no errors, and the round 2 route works as before.
- **Rendered captures** of every clip, in game and as Blender stills. I
  judged them by eye.

## What wasn't verified

- I didn't play the build interactively. I only watched captures.
- I didn't watch the shockwave's throw on the wanderer, and I didn't watch
  riding his shoulders with the new model. The motor code is unchanged.
- The close climb capture is from behind and off the wall, so the hands on
  the wall are partly hidden by his own back. A front-on climb view would
  need a camera inside the cliff.
- I didn't look at frame times. The mesh is about 89k triangles, which is
  heavy if many bodies are on screen at once.

## Open questions for the user

- **Does the walk read heavy enough?** It is deliberately slow and
  weighty, with a held squash on each step. Should it stomp harder, or
  shake the camera more on each step?
- **Is the arms-forward stride the read you want for "he has the scent"?**
  The other option is a hunched, head-down charge.
- **Is the 1.8 s triumph beat worth the pause before he moves on?** It is
  the `triumph` knob, and 0 skips it.
- **Riding his back while he's headless.** Chunky grabbable ledges between
  his shoulder blades would be easy to add to this model.
  - The back is already built from rbox masonry courses on the `chest`
    bone. One or two proud blocks across the upper back are a few lines in
    the build script, and they would bend with his chest.
  - The game side is a little more work. It needs a grab collider (or a
    `RuinKit` ledge) on a `BoneAttachment3D` that follows the `chest` bone,
    and the wanderer's grab code has to accept a moving ledge. Riding the
    shoulders already works with moving bodies, so the parenting pattern
    exists.

## Tests this breaks

No existing test references the headless body (I grepped `tests/` for
`headless_body` and `stone_body`). As far as I know, none break. I didn't
run the full suite, as prototyping rules say.
