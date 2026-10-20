# The stone guy's body: contract

The only thing the brood's mind (`scripts/brood/stone_guy.gd`, its hosts
`brood_host.gd` / `bag_brood.gd`, knobs `brood_knobs.gd`) and its body
(`scripts/brood/stone_guy_body.gd`, the model `art/blender/brood/`) share.
A name here is final once both sides build on it; changing one is a
`spec change` commit and a note to both.

The clip table below is also written by the build to
`assets/models/brood_clips.json`, which the body reads, so the glb, the
json and this page agree (rebuild after editing `brood_clips.py`).

## Shape

- **Height** `tall = BroodKnobs.tall()` (`TALL` x the wanderer's drawn
  height, `WorldScale.wanderer_tall`): knee-high to him. The model is
  authored at height 1 and scaled to `tall`; no metre figure lives in it.
- **Radius** `BroodKnobs.RADIUS` x `WorldScale.wanderer` (the mind's rays).
- **Origin** his middle; soles `tall*0.5` under it; front -Z, up +Y (the
  mind turns the node: upright on the ground, belly to the face on a
  face, belly to the wanderer clinging, belly to the bag riding).
- **Silhouette** (the greybox's): a squat block trunk about 0.72 tall wide,
  a head a little forward with a heavy brow, stub arms hanging outside the
  trunk ending in big fists, stub legs. Reach overhead: the fists at about
  0.6 tall over his middle (where the hauled treasure sits, `load`).

## Clips

Times in s. **Driven**: `seek` = the mind sets the clip to its own clock
each frame (so the mind's timings and the clip's beats agree exactly);
`stride` = moved on by the distance he travels, one loop per `stride` x
tall; `time` = the frame clock.

| clip | length | loop | driven | beats | the mind's state |
|---|---|---|---|---|---|
| idle | 1.6 | yes | time | - | walk, not moving 0.12 s |
| look | 1.4 | yes | time | left 0.1, right 0.7 | the burrow rise's hold |
| wake | 0.7 (WAKE_RISE) | no | seek | grip 0.315, peek 0.7 | wake over a lip, `_w_t` < WAKE_RISE |
| peek | 1.2 | yes | time | left 0.09, right 0.62 | wake over a lip, the hold after |
| rise | 0.7 (WAKE_RISE) | no | seek | peek 0.28, heave 0.385, stand 0.7 | wake out of a burrow |
| sink | 1.1 (SINK_TIME) | no | seek | look 0.38, crouch 0.5, hop 0.56, gone 1.1 | sink |
| walk | 0.44 | yes | stride 1.5 | plant 0.0, 0.22 | walk, moving |
| haul | 0.6 | yes | stride 0.9 | plant 0.0, 0.3 | haul, or walking `hauling` (the lead) |
| climb | 0.62 | yes | stride 0.55 (back down: backwards) | grab 0.0, 0.31 | climb |
| mantle | 0.5 (MANTLE_TIME) | no | seek | lip 0.275, over 0.5 | mantle |
| drop | 0.26 | no (held) | time | hang 0.26 | fall with a floor in sight (`_drop_to`) |
| land | 0.26 | no | time | contact 0.0, up 0.26 | fall -> walk |
| fall | 0.5 | yes | time | - | fall, no floor in sight |
| shake | 0.45 | no, then fall | time | flung 0.08 | fall after `shake()` (thrown off) |
| cling | 0.5 | yes | time | squeeze 0.0, 0.25 | cling |
| leap | 0.35 (LEAP_TIME) | no | seek | launch 0.07, catch 0.3 | leap |
| ride | 0.8 | yes | time | kick 0.0, 0.4 | ride |

"lost" and "home" are hidden: no clip. The seeked lengths are the knobs'
(`WAKE_RISE`, `SINK_TIME`, `MANTLE_TIME`, `LEAP_TIME`): change a knob and
the clip must be rebuilt to match (`brood_clips.py` names them).

What each shows (the tell a player reads): **wake** a dip, the fists
stretched up over the lip and hooked on at `grip`, a squash under the pull,
the heave that brings his eyes over at `peek`. **rise** the head up first
looking up, a quick look at `peek`, fists slapped down either side at
`heave`, a spring up and a landing squash at `stand`. **sink** two steps
onto the mouth, a look, a crouch, the hop, arms straight up stretched thin
as he goes down. **walk** a leaning scurry, a squash and dip at each
`plant`. **haul** arms straight up under the load, short heavy steps, head
down straining. **climb** hand over hand, each fist stretched up and slapped
on at `grab`, the opposite knee drawn up. **mantle** a squash under the
fists, the heave at `lip` (chest over, legs kicked back), a knee up, a
landing squash at `over`. **land** a deep squash at `contact`, held a
breath, up through a little stretch. **shake** splayed and whipped back
at `flung`, into the fall's windmill. **cling** arms round him squeezing,
legs kicking. **leap** a crouch, stretched long at `launch`, a tuck, a
squash as he grabs on at `catch`.

## Sockets

`socket(name) -> Node3D`, made on first ask (a BoneAttachment3D on the
bone): `hand_l`, `hand_r` (the fists' palms; cling, haul, climb grips),
`head` (its crown), `eyes` (between them, at the front), `load` (on the
trunk, over his head: where a hauled treasure sits).

## Effects

`set_effect(name, on)`: `daze` (his head lolls round over whatever clip
plays; the mind sets it while `daze` > 0 and he's not falling).

## The body's API

`scripts/brood/stone_guy_body.gd`, a Node3D under the mind's node:

- `setup(tall)`; `static available() -> bool` (the glb and table exist)
- `play(clip, blend := BLEND)`: from its start, cross-faded
- `seek(clip, t, dt)`: the clip at the mind's time `t`
- `advance(d, dt)`: on `d` s of clip time (negative for a loop backwards)
- signal `beat_reached(clip, beat)` (checked only while connected)
- `socket(name) -> Node3D`, `set_effect(name, on)`, `clip_info(clip)`
- `clip`: the clip playing

The greybox (`--brood-greybox`, or no glb) is the stand-in: the old block
body in `stone_guy.gd` (`_build`, `_swing`), driven by the same states.
