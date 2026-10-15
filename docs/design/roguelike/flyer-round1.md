# The flyer, round 1: the guácharo (2026-10-15)

Feature `flyer` of the game-feel round (items-contract.md). On by default;
`--no-flyer` (or `--loot=off`) turns it off.

## What it is

A giant oilbird, the guácharo: the real cave bird of the Americas that
screams in the dark and finds its way by clicks. It is scaled up to three of
his heights across the wings (about 3.4 m). It has rufous-chestnut, worn,
white-spotted feathers with dusky tips and ragged split edges, a hooked horn
beak and big dark eyes. It has no glow and no spikes: the menace is its size,
its silhouette and its voice.

It makes exposed places frightening. It circles high over him, and while he
is exposed its hunger fills. He is exposed when he is in the air over the
void, hanging on a ledge, on a wall or a rope, or standing by a rim with
void round him, worse when he stands still. Under cover (stone over his
head), or knocked down, he is safe.

When it is hungry it marks him. It drops to a point in the camera's view,
off to one side of him, and hangs there clicking, the clicks quickening.
Then comes the tell: a scream, the beak wide and the wings thrown up, then
folded into a teardrop, and it stoops.

- **The dodge:** the aim locks with the scream on where he will be if he
  keeps on. Kept on, he is hit. Stopped, turned back or set off, he is
  missed (it barely corrects in the dive).
- **The hit:**
  - In the air, he is **buffeted**: a knock sideways, and the fall is the
    danger.
  - Standing or hanging, he is **snatched** (PilotMotor `seize`). It beats
    hard to lift him for 0.7 s, then carries him out over the nearest void
    and drops him. Mash jump or twirl (4 presses) during the lift and he
    drops back where he was. Free himself later and he falls anyway.
  - Either hit costs a heart through the motor's `harm` (cause "the
    guácharo").
- **Then:** it pulls out with heavy beats, sheds a few feathers where it
  hit, and waits a 7-12 s cool-down before it can mark him again.

Its shadow is a soft bird-shape thrown straight down (a Decal). It tightens
and darkens as it nears him.

The voice is placeholder synth: the sonar click, the scream, the rush of
the stoop and the hit.

## Where it is laid

`scripts/roguelike/layer_flyers.gd` `lay`: a layer with a gulf, or 5
crossings or more, gets one. A second comes from danger 0.6 (the higher
regions). Its home is 26 m over the widest gulf; a second's home is over a
crossing at least 60 m away.

It hunts once the layer's 12 s grace is out and he is within 140 m of a home
or 55 m of a crossing's lip. Only one bird dives at a time, and only one
carries him at a time.

## Play it

Meet it alone, in the flyer yard: the motif yard with one bird, the
Lamplighter's Stair, and rim pads out over the drop. It hunts after 3 s. Go
stand on the high pad.

```sh
/Users/davidkalina/Applications/Godot.app/Contents/MacOS/Godot --path . res://studies/flyer_yard.tscn -- --no-title
# underground look:  ... -- --no-title --underground=haze
# its beats logged:  ... -- --no-title --flyer-log
```

In the real run:

```sh
/Users/davidkalina/Applications/Godot.app/Contents/MacOS/Godot --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=11
# cross the stepping stones and stand still on one; or --flyers=2
```

The poses side by side (glide, beats, scream, fold, stoop, flare, carry):

```sh
python3 tools/shot.py studies/guacharo_poses.tscn [-- --close=glide [--near]]
```

## Knobs

- `--flyers=N`: the count on a layer (0 none).
- `--flyer-<knob>=<value>`: any of `Guacharo.KNOBS` (`scripts/enemies/guacharo.gd`).
  Sizes are in his heights, speeds in m/s, times in s. The ones to try first:
  - `fold` (0.6): the scream-to-dive tell.
  - `stalk_min` / `stalk_max` (1.6 / 5.5): how long it clicks before it
    commits.
  - `stalk_at` (0.9): how much exposure makes it mark him.
  - `lead` (0.9): how far ahead of him it aims.
  - `home_turn` (0.12 rad/s): how much it homes in the dive.
  - `hit` (0.8): its reach.
  - `buffet_out` / `buffet_up` (4.5 / 0.9): the knock.
  - `snatch` (1; 0 is buffet only).
  - `lift` / `carry` (0.7 / 1.5): the snatch's lift and its whole carry.
  - `struggle` (4): presses to get free.
  - `cool_min` / `cool_max` (7 / 12): the cool-down between dives.
  - `span` (3): the wingspan in his heights.
  - `stalk_side` / `stalk_out` / `stalk_up` (0.45 / 7.5 / 1.4): where it
    hangs before the dive.
- Layer constants in `layer_flyers.gd`: `GRACE`, `RANGE`, `NEAR_EDGE`,
  `HOME_UP`, `MANY_EDGES`, `DANGER_TWO`.

## Proven (throwaway drivers in scratch/, through the real motor and input)

Flyer yard, him on the high rim pad, 3 trials each:

| Case | What he does | Result |
|---|---|---|
| stand | stands still | snatched, carried, dropped into the void 3/3 (falls 18 m or more) |
| dodge | runs back toward the isle on the scream | missed 3/3 |
| leap | jumps as it arrives | buffeted 3/3 |
| struggle | mashes jump while held | freed during the lift and lands back on the pad 3/3 |

Run layer (sprawl, seed 11, one bird over the 169 m gulf), him on a stepping
stone of a stones crossing:

| Case | What he does | Result |
|---|---|---|
| stand | stands still | snatched and dropped, 15 m below the stone |
| hop | hops as it comes | buffeted off the stone, 15 m below it |

Smoke: `studies/run_layer.tscn` (sprawl seed 11; ring seed 2 underground),
`studies/flyer_yard.tscn` and `studies/guacharo_poses.tscn` run 900 frames
with no errors.

The rendered stills, from the play camera in the yard (scratch/fly_*.png),
show:
- the scream, wings thrown up against the clouds;
- the fold, a dark teardrop;
- the carry, him hanging under it over the pad, loose feathers falling and
  its shadow on the turf.

## Rough

- **The model is built in code, with procedural wing angles, not a Blender
  rig with authored clips.** The key poses read (see guacharo_poses), but the
  beats are a sine, not authored overlapping action. A Blender rig with
  clips is the next step, to the Animation bar.
- **The body is plain ellipsoids:** no neck ruff, no rictal bristles. It
  reads at play range, but is soft close up.
- **The shadow decal is faint in a sunlit sky world,** where the sun's own
  shadow does the work. It is meant for the underground murk. It is not yet
  judged there by eye: one underground capture showed it, but the bird
  wasn't in frame.
- **It flies through stone.** It climbs when stone is ahead, and the stalk
  point and the dive line are checked clear, but the circling never routes
  round tall spires.
- **It comes from its home over the widest gulf, so on a big layer it takes
  about 15 s to reach him.** That was 280 m on seed 11, flying twice its
  circling pace when far off.
- **The stalk point is tuned to the play camera's pitch:** low, about 1.5 m
  over him, 8 m out and 26° off the camera's forward. Where that point is
  over stone (along a crossing), it falls back to wider angles, then
  higher. The plane's wide
  camera isn't considered.
- **The danger isn't checked against the rest of the round.** The headless
  bodies, the heads and the bird can stack up on one crossing. One bird per
  layer below danger 0.6 is the guess.
- **When he struggles free, the knock still stuns him.** He lands stunned on
  the pad.
- **The voice is placeholder synth.**
- **Each sound has one player** (a scream doesn't overlap itself).

## Model budget (docs/art/model-budget.md)

The bird is about 2.3k triangles:
- 70 feathers a wing: arm 35, hand 18 on each side, plus tail 9, each
  8 triangles (about 920 in all);
- the ellipsoids, about 1.2k;
- eyes, beak and talons.

It is about 20 draw calls. The plumage is one shader.

| Trick | Applies? | Saving |
|---|---|---|
| Sculpt high, bake low | No | It is already low. Its detail is in the feather shader (vane, barbs, spots, wear, all faded by pixel footprint), not in geometry. |
| Import LODs / visibility ranges | Yes | At circling range (20-40 m), replace the body ellipsoids with one 300-triangle mesh and the feathers with one wing card a side. That drops about 1.5k triangles and about 12 draw calls a bird; it matters only with flocks. |
| Silhouette geometry | Applied | The ragged primaries and the split vanes cut by alpha scissor are the silhouette. |
| Rigid parts on bones | Applied | Wings, head, jaw and talons are rigid nodes, nothing skinned. A Blender rig should keep them rigid. |
| Parallax depth | No | Feathers are thin cards. |
| Vertex-colour grime | Partly | Per-feather tint (dark tip, spots, notch) is in vertex colour already. |

The cheapest win is merging the body's blobs, beak and eyes into one mesh:
about 10 fewer draw calls a bird, for well under 0.05 ms a frame.

## Files

New:
- `scripts/enemies/guacharo.gd`
- `scripts/enemies/guacharo_look.gd`
- `shaders/guacharo_feather.gdshader`
- `scripts/roguelike/layer_flyers.gd`
- `studies/flyer_yard.{gd,tscn}`
- `studies/guacharo_poses.{gd,tscn}`

Hooks: `scripts/roguelike/layer_stage.gd` (`# [flyer]`: preload, var,
dress, before, after, frame, reset).

## Tests it may break

None known; the full suite was not run. It changes no motor, piece or plan
data. A test that runs a sky layer with a gulf now has a bird that can
knock or carry the walker after 12 s, and that could upset a long scripted
layer test. Such a test can pass `--no-flyer`.
