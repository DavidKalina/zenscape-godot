# Isle hall chain: handoff

Branch `study/isle-hall-chain`, from main (94a4d1c0) with `study/hall-chain` (c06cc605) merged in (no conflicts). Not merged, not pushed. It follows on from docs/design/isle-lodestone.md (the lodestone, the nose arrow) and docs/design/hall-chain.md (the chain).

The ask: "Grab the sundered hall's orb, fly through the ring, and it starts."

## How to play

```
./run-aqueduct-isle.command                  # the whole loop, from on foot
./run-aqueduct-isle.command --near-ring      # quick test: in the plane, stone seated, 260 m before the ring
./run-aqueduct-isle.command --carry --fly    # in the plane, stone seated, by the isle
./run-aqueduct-isle.command --no-chain       # the shard only, with the old arrival chime
```

The scene picker's "Aqueduct isle" entry (Scenes, then Ruins) opens the whole loop.

1. Find the lodestone on floating stone `east_1` and pick it up (E or pad A). Keep it (E), then board (F or pad Y). This part is unchanged.
2. Fly where the nose arrow points. The shard is now 380 m north-north-east of the start, at (200, 42, -380).
3. Within 230 m of the ring, an arch on a keel of lode stone rises out of the cloud sea. It stands 90 m past the shard and 35 m to its left. Nothing announces it:
   - no beacon, glow or pulse;
   - no text;
   - the nose arrow goes on pointing at the shard.
4. Fly through its opening. Nothing happens for 1.5 s. Then the chime plays, a soft flash blooms round the plane and the nose arrow flares (on the stone plane, its own sync flash). The first Sundered hall starts rising out of the cloud dead ahead, on the heading you left the ring with.
5. From there it is the hall chain. Each hall you get 40% through sets the next one rising, and the oldest past 8 sinks. The flying hint adds one line: "The halls rise out of the cloud ahead: fly on through them".

Missing the ring does nothing. Crossing its plane beside it, or flying round it, starts nothing, and you can come round and go through. Being near the shard no longer triggers anything either: the old 30 m arrival is off with the chain. Its chime is folded into the ring's pulse, and the shard's own flash is dropped.

### Flags

| Flag | Default | Does |
|---|---|---|
| `--no-chain` | | no ring, sea or chain; the shard back at (250, 54, -230) with the old 30 m arrival |
| `--near-ring` | | starts in the plane, the stone seated, 260 m before the ring and 3 m over its middle, flying at it (implies `--carry`) |
| `--ring=x,y,z` | 90 m past the shard, 35 m left, y 25 | the opening's middle (where you thread it); it faces along the isle-to-shard line |
| `--ring-pause=<s>` | 1.5 | the held breath between threading and the pulse |
| `--chain-lead=<m>` | 180 | how far past the pass point the first hall's way in stands (the gate is 25 m more) |
| `--target=x,y,z` | (200, 42, -380) | the shard; the ring follows it |
| `--capture-wait=<s>` | 4 | how long a chase-camera capture waits (captures only) |
| the chain's and rise's | | `--chain-at=`, `--chain-gap=`, `--chain-keep=`, `--rise-speed=`, and so on, as in docs/design/hall-chain.md |

## The ring

- **What it is.** The gothic kit's pointed arch (`RuinKit.arch`, seed 52, weathered 0.25, so the crown stays whole) at 2.2×. That gives a clear span of 9.2 m and a crown 15 m over its feet. The wooden plane is 1.4 m across, so you have about 4 m either side.
- **What it stands on.** A small keel of the shard's lode stone (`Lodestone.keel_mesh`, 21 × 10 m, 9 m deep), with its veins dark (hum 0). It floats like the halls do.
- **Collision.** Both the arch and the keel collide (layer 1), but only once the ring stands.
- **Why a new arch, not the shard's.** The shard's own arch is the kit's 4.2 m one: too tight to thread comfortably, and it can't rise without poking out of the shard's tapering keel. With the chain on, the shard drops its small arch and keeps the pier, so there is one arch to read, not two to choose between. The ring stands apart and rises out of the same cloud the halls will rise from. It is a quieter echo of what is about to happen.
- **Why 35 m to the side.** On the straight line past the shard, the approach ran under the shard's keel (its bottom is at y 28, and the opening's middle is at 25). The first capture showed the keel filling the view and hiding the ring.
- **How it appears.** It rises 46 m from under the cloud top over 6 s, easing to a stop (1 − (1 − u)³), with a soft sea swell where it breaks through. There is no puff burst. It rises only with the stone seated.
- **What counts as threading.** Crossing the arch's plane (its local z through 0) with the crossing point inside the opening: within the span and under the pointed head, 0.6 m in from the stone. Any other crossing counts as a miss and does nothing.

## Placement

- **The cloud sea.** The isle has no real cloud surface. Its cumulus is the sky's, drawn at infinity, and nothing can rise through that. So the chain's greybox sea comes along (`shaders/isle_cloud_sea.gdshader`: the same heaps and swells), with its top at y 0.
  - It is a patch, not the whole world: opaque out to 420 m from its centre, breaking up into ragged clumps over 120 m more.
  - It has a hole round the isle's middle: none within 220 m, full by 320 m. That keeps it off the isle, its keels and the four near isles.
  - The patch starts centred on the ring and then follows the chain (over 4 s).
  - Over the patch, the plane's cloud cushion is the sea top. Elsewhere it is the isle's own (y −20).
- **The heights.** The first hall's lane stands 2 m under the pass height. That puts its lowest stone about 14 m over the cloud, as in the chain study, so the breakthrough is right ahead and a little below you. Later halls keep the chain's 8–24 m clearance.
- **The shard.** It moved from (250, 54, -230) to (200, 42, -380), so the ring (468 m from the isle's middle) and the halls stand well out over the sea patch, with the isle's near isles in the hole.
- **The direction.** The first hall is mirrored (it swings you left). Starting with the as-built hand would have run the chain's S east, toward the pierced isle and the reef cluster. Mirrored, the chain's mean heading is about 38° left of the ring's facing, north-north-west into open sky. On the way, the second or third hall passes the hamlet cluster about 300 m to the west, and the far isle `far_n` about 100–150 m off at about 1.2 km.
- **The first gate.** It is 205 m past the pass point (the way in at 180 m), within 0.01° of the heading you left the ring on. At cruise (14 m/s), after the 1.5 s pause and the rise's 12 s, the gate is easing in or settled as you reach it, as in the chain study's 170 m start.

## Files

- **New:**
  - `studies/aqueduct_isle_chain.gd`: the ring, the sea patch, the pause, starting and stepping the chain;
  - `shaders/isle_cloud_sea.gdshader`;
  - `tests/test_isle_hall_chain.gd`.
- **`studies/aqueduct_isle.gd`:**
  - the flags;
  - the new default target;
  - the chain built with the lodestone;
  - stepped in `fly_step` (in `_process` on foot);
  - the plane bumps off the halls (`RuinBump.LAYER` added to its bump and stone masks);
  - the cloud floor over the patch;
  - the pulse;
  - `fly_from`;
  - `--capture-wait`;
  - the hint line;
  - no proximity arrival with the chain.
- **`scripts/hall_chain.gd`:** `first_pose_at(way_in, heading, hand)` and `reset(seed, first)`. Additions only; the chain study is unchanged.
- **`scripts/nose_compass.gd`:** `pulse()`, a flare and a swell; where it points doesn't change.
- **`tests/test_isle_lodestone.gd`:** runs with `chain_on = false`, because it checks the shard-only arrival.
- **`scripts/scene_catalog.gd`:** the entry's detail.
- **`run-aqueduct-isle.command`:** the comments.

## Tests (headless)

`tests/test_isle_hall_chain.gd` takes about 32 s. It checks:
- the ring is hidden at the start and 400 m off;
- it rises within 230 m, starting under the cloud, then stands and collides;
- the nose arrow still points at the shard;
- a pass 18 m to the side counts a miss and starts nothing;
- threading counts;
- nothing happens for the pause (1.52 s measured, 1.50 asked): no hall, no flash;
- then the first hall rises, with a pulse in the plane, its gate 0.00° off the exit heading and 205 m ahead, all four chunks under the cloud;
- the chain's autopilot (`HallChain.steer`) flies from the ring through 2 halls (3 made, 43 s): never stuck (0 bumps), never inside stone, over the cloud;
- each gate (the first hall's included) is easing in or settled as the plane reaches it;
- `--no-chain`: no ring or chain, the shard where it was, the old arrival flash.

`test_isle_lodestone`, `test_aqueduct_isle`, `test_aqueduct_isle_plane`, `test_aqueduct_isle_look`, `test_aqueduct_isle_sky`, `test_aqueduct_isle_life`, `test_lodestone_study`, `test_hall_chain`, `test_hall_rise`, `test_scene_picker` and `test_scene_picker_title` pass under the runner, and the headless import is clean. In one parallel run, `test_aqueduct_isle_sky` failed on renderer RID errors in `sky_islets.gd` `stand`, with none of its checks failing. It passed when rerun alone. That code is untouched here. The full suite was not run (see What's weak for `test_scene_picker_entries`).

## Captures

These are in `captures/isle-hall-chain/`, local only (gitignored), taken from `--near-ring --capture-wait=<s>`.

## What's weak

- **The greybox sea is a stand-in.** Up close it reads as flat white fog against the sky's fluffy cumulus, and its ragged rim and the isle's hole are visible from the right angles. A real version wants the game's volumetric cumulus or `sky_sea` to be the thing the halls rise through.
- **Nothing tells you to thread the ring.** That is the design, but it means a player could circle the shard, see nothing happen, and leave. The arrow still points at the shard after you thread the ring, and all through the halls, behind you. Whether it should go quiet once the chain starts is an open question.
- **The chain's heading follows how you thread.** It is the plane's heading at the pass. A steep slanted pass (the opening allows about ±35°) swings the whole chain that way and could run it toward the hamlet or the pierced isle. Nothing checks halls against the sky's isles.
- **The patch follows the chain.** Its ragged rim slides slowly as the halls move on, and over a long run it can cover a far isle's keel or a cluster's underside.
- **Boost still outruns the first hall's rise,** as in the chain study (open question 2 there).
- **One shot.** The ring starts the chain once. Getting out, R, or flying back doesn't reset the ring or the chain; a scene restart does.
- **The pulse is small on the wooden plane.** A 7 m soft flash and the arrow's flare. It was checked headless (the flags are set) but not in motion.
- **The full scene picker entries test.** Both of my full runs of `test_scene_picker_entries.gd` crashed at exit (signal 11, `~ArrayMesh` with the RenderingServer already gone), after every entry's checks had passed, aqueduct_isle, hall_rise and hall_chain included. Runs of just those entries with `collectibles` exit cleanly. This is the engine-shutdown problem with static meshes that docs/design/scene-picker.md already records (there, one run in three). Here it happened in 2 of 2, so the chain may make it likelier. Not fixed.

## Open questions

1. Should the arrow go quiet (sink back into the cowl) once the ring has been threaded, so the halls are the only guide?
2. Should the ring stay standing as the chain's first gate, or sink back once the first hall is up?
3. Should the pause be shorter at speed? (1.5 s is about 21 m at cruise.)
4. Should the chain clamp its heading to the ring's facing, so a slanted pass can't swing it toward other islands?
5. Should there be a way back (sinking the chain, re-arming the ring) for a second go without a restart?
6. Greybox sea or the game's cumulus: is it worth making the real clouds something the halls can break through?
