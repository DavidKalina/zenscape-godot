# Isle hall chain: handoff

Branch `study/isle-hall-chain-2`, from `study/isle-hall-chain` (dfa139d2). Not merged, not pushed. It follows on from docs/design/isle-lodestone.md (the lodestone, the nose arrow) and docs/design/hall-chain.md (the chain).

The first round's ask: "Grab the sundered hall's orb, fly through the ring, and it starts." You flew it: "Not bad. Few issues." This round fixes three of them:

1. **"Spawns too late."** Now the ring and every hall are up and still before you reach them, at cruise and at boost.
2. **"I don't like the cloud layer."** The flat greybox patch is gone. The ring and the halls now erupt out of the game's own cumulus sea, far below, and climb up to where you fly.
3. **"Arrow keeps pointing while I start the challenge."** At the pulse the nose arrow now folds down along the nose, dims, and stops tracking.

## How to play

```
./run-aqueduct-isle.command                  # the whole loop, from on foot
./run-aqueduct-isle.command --near-ring      # quick test: in the plane, stone seated, 260 m before the ring
./run-aqueduct-isle.command --carry --fly    # in the plane, stone seated, by the isle
./run-aqueduct-isle.command --no-chain       # the shard only, with the old arrival chime
```

The scene picker's "Aqueduct isle" entry (Scenes, then Ruins) opens the whole loop.

1. Find the lodestone on floating stone `east_1` and pick it up (E or pad A). Keep it (E), then board (F or pad Y).
2. Fly where the nose arrow points. The shard is at (200, 42, -380).
3. As you near the ring (about 13 s out at your speed: 176 m at cruise, 277 m at boost), an arch on a keel of lode stone erupts out of the cloud sea far below and climbs about 160 m to stand past the shard. It takes 8.6 s. Nothing announces it, and the nose arrow goes on pointing at the shard.
4. Fly through its opening. The first hall starts rising at once, out of sight, deep in the cloud. For 1.5 s nothing shows. Then:
   - the chime plays;
   - a soft flash blooms round the plane;
   - the nose arrow flares, then folds quiet over 2.4 s;
   - the first chunk of the first hall bursts out of the cloud dead ahead, a tenth of a second after the pulse.
5. From there it is the hall chain. Each hall erupts out of the sea ahead and climbs to your height, triggered early enough for its gate to be still before you get there.

### Flags

| Flag | Default | Does |
|---|---|---|
| `--ring-near=<m>` | 150 | the nearest the ring wakes. At speed it wakes sooner: once the plane would arrive within its rise plus 4 s (was 420 m and 8 s; see the fix below) |
| `--ring-pause=<s>` | 1.5 | the held breath between threading and the pulse |
| `--first-at=thread\|pulse` | thread | when the first hall starts rising: at the threading (unseen through the pause) or, as before, after the pause |
| `--chain-lead=<m>` | 180 | the least distance past the pass point for the first hall's way in (the gate is 25 m more). At speed it stands further on |
| `--arrive-spare=<s>` | 2 | how long before the plane gets to a gate it should be still. This sets the first hall's lead and the chain's triggers |
| `--catch-up=<x>` | 1.6 | how much quicker a hall rises when the plane would still beat it (1: never) |
| `--no-chain`, `--near-ring`, `--ring=x,y,z`, `--target=x,y,z`, `--capture-wait=<s>` | | as before. `--capture-wait` now counts seconds flown when the capture is from the plane, so a capture shows the same moment on every run |
| the chain's and rise's | | `--chain-at=`, `--chain-gap=`, `--chain-keep=`, `--rise-speed=`, `--chunk-gap=`, `--rise-ease=`, and so on, as in docs/design/hall-chain.md. They override the isle's rise defaults below |

To time it headless:

```
godot --headless --path . -s tools/isle_chain_timings.gd [-- <flags>]
```

## 1. Timing

### Before and after

These come from `tools/isle_chain_timings.gd`, headless. The plane flies straight at the ring from 600 m out, threads it, and the chain's autopilot flies three halls, at cruise (14 m/s) and holding boost (about 22 m/s). The before numbers are the same tool run on dfa139d2.

Each row shows seconds from the trigger to the gate standing still / seconds from the trigger to the plane reaching it / the margin (positive: still before you arrive).

| | Before, cruise | Before, boost | After, cruise | After, boost |
|---|---|---|---|---|
| **Ring** (trigger: it wakes) | 6.0 / 16.4 / **+10.4** (woke 230 m out) | 6.0 / 10.4 / **+4.4** | 8.6 / 30.0 / **+21.4** (woke 420 m out) | 8.6 / 19.1 / **+10.5** |
| **First hall** (trigger: threading) | 13.7 / 14.2 / **+0.4** | 13.7 / 9.0 / **−4.7** | 12.1 / 14.2 / **+2.1** | 12.1 / 13.8 / **+1.7** |
| **Hall 1** (trigger: its spawn) | 12.2 / 13.3 / **+1.1** | 12.2 / 8.5 / **−3.6** | 11.4 / 13.3 / **+1.8** | 10.2 / 12.8 / **+2.6** |
| **Hall 2** | 12.1 / 13.3 / **+1.2** | 12.1 / 8.5 / **−3.6** | 11.5 / 13.3 / **+1.8** | 10.4 / 12.9 / **+2.4** |

Before, at boost, you met every hall's gate 3.6 to 4.7 s before it was still. Now every gate is still about 2 s before you get there, at either speed.

### What changed

- **The ring wakes at 420 m, not 230 m, and earlier still at speed.** It also wakes once the plane would arrive within its rise plus 8 s. Only a 30 m/s dive changes anything: from 470 m it wakes at 30 m/s but not at cruise. Its rise is longer (8.6 s, from deep in the sea), but it now stands still 10 to 21 s before you reach it. You see it rise from about 400 m out.
- **The first hall starts rising at the threading, not after the pause.** Through the 1.5 s pause it is climbing deep under the cloud, so the held breath is unchanged. The rise's lead is tuned (0.4 s) so the first chunk breaks the cloud top just after the pulse, which ties the two together. This alone gains 1.5 s.
- **The first hall's way in is speed-aware.** It stands at least `--chain-lead` (180 m) past the pass point. If you thread at speed, it moves further on, enough for the gate to be still `--arrive-spare` (2 s) before you get there at that speed. At cruise that is still 180 m; threaded at full boost it would be 287 m.
- **The chain's triggers are speed-aware** (`HallChain.settle_by`). The next hall starts rising as soon as, at the plane's speed, its gate is no more than its rise plus 2 s away. The old trigger, 40% of the way along the hall, still fires if that comes first. At cruise the two land at about the same spot. At boost the next hall starts as you enter the current one.
- **Catch-up** (`HallChain.catch_up`). If you speed up after a hall was set rising, so that you would still beat it, its rise plays up to 1.6× faster. It only applies until you reach that hall. It is what keeps hall 1 and hall 2 still at boost (10.2 s instead of 11.4 s).

The chain study (`./run-hall-chain.command`) is unchanged: `settle_by` and `catch_up` are off there by default.

## 2. The cloud: erupting out of the game's own sea

### What's in the scene

The aqueduct isle runs the game's look pass (scripts/look_pass.gd), so it already has the game's cumulus. In the first round's capture you can see it past the greybox patch's rim. It consists of:

- **The near cloud sea** (scripts/sky_sea.gd), a field of cumulus heaps round the eye, out to 2.4 km. Their feet are at y −150 and their tops reach about −105. It is drawn by the unified cloud volume (scripts/cloud_volume.gd), raymarched after the opaque pass, so solid things inside it are hidden by real cloud.
- **The dome's painted sea** past that, to the horizon.

These aren't in the isle:

- **The towering cumulus** (scripts/sky_towers.gd, the "cumulus life": towers rise from the sea, stand, wane and regrow). They are cell-placed by the sky world and need its islands. They are hundreds of metres tall and take tens of seconds to grow.
- **The glide's drifting clouds** (scripts/sky_clouds.gd).
- **Cloud tearing** (scripts/cloud_wakes.gd). It only acts on those puffs and the volume.

The first round's note that "the isle's own clouds are drawn at infinity" was wrong: the near sea is real geometry in the world, about 130 m under the plane.

### Chosen: rise out of the real sea, all the way up

- **The halls stay where you fly.** Their lane is about the ring's height, about 23 m, with later halls within ±8 m of the first (`HallChain.clear_range`).
- **Each one rises out of the near sea.** It starts 25 m under the heaps' tops (`SEA_TOP`, −108) and climbs about 160 m:
  - it bursts through the heaps at full speed (30 m/s);
  - it eases over its last 30 m;
  - it sinks its 0.35 m into place.
  - These are the isle's rise defaults (`RISE_OPTS`), and the rise flags override them. With chunks 1.2 s apart (was 1.5), a hall still takes about 12 s from start to still gate. That is about the same as the old 9 m/s rise over 40 m.
- **The ring rises the same way.** It climbs about 160 m on a chunk's motion (`RisePlan.height_at`), at 26 m/s, easing over 26 m.
- **The breakthrough is the game's own cloud.** The hall rise's bursts, streams and caps now go to `scripts/sky_puff_burst.gd` (`HallRise.burst`, shared by the chain and the ring). It draws them with `shaders/sky_cloud_puff.gdshader`, the shader of the glide's clouds and the cloud wrapped round a sky peak's foot. That means the sky's own cloud light: sunlit tops, cool shaded bases, ragged soft rims, and a soft fade where a puff meets stone.
  - The puffs are 2.2× the greybox size.
  - None is carried up faster than 8 m/s, so a fast chunk leaves a billow behind it, not a jet trail.
  - The shader gains one switch, `instance_fade` (off by default), so each puff can fade in and out by its instance colour. Its other users are unchanged.
- **No cloud of its own.** No patch, no hole round the isle, no rim, no follow. `shaders/isle_cloud_sea.gdshader` is deleted. The plane's cloud floor is the isle's own again (y −20) everywhere.

Why this one: the sea is the cloud you liked, and it is already there. Rising out of it reads at once as "erupting from the clouds we have". From the plane you watch each chunk punch up through the heaps and climb to meet you, so the motion is easy to catch even though the breakthrough is about 130 m below.

Captures (local only, gitignored) are in `captures/isle-hall-chain-2/`:
- `before_t4.png`: the first round, with the flat white patch in front of the real sea;
- `after_s01.png`: the ring bursting out of the sea in a billow of puffs;
- `after_s05.png`: the ring standing, the sea under it;
- `after_s21.png`, `after_s23.png`: the first hall's chunks climbing out of the sea ahead, the gate last;
- `after_t30.png`: arriving at the first gate.

The earlier `after_t*` frames used the old real-time capture wait, so their moments drift from run to run.

### Alternatives considered

- **A local billow at the halls' height**, in the same puff shader. This would be a cumulus heap that swells round each chunk at y 0 and bursts as it comes through. Rejected for now:
  - with no sea under it, the heap floats alone in open sky;
  - to hide a chunk before it breaks through, the heap would need to be about 30 m deep under the whole footprint (a hall is about 230 m long), at roughly 200 puffs a hall;
  - from a shallow angle you could still see under it.
  - It is the fallback if the long climb reads wrong in motion.
- **Swelling the real sea under each hall.** The near sea already heaves up to 22 m under islands (`SkySea.set_islands`), and it could heave under each rising hall too. But the look pass rewrites the island list every frame, and a swell change re-bakes a 2048² texture. It is a good next layer, not done here.
- **A towering cumulus under each hall**, the hall coming out of its crown. Rejected: the towers are hundreds of metres across and take tens of seconds to grow. They also cost a body bake each, and the cloud volume marches four at most.
- **Lowering the whole chain to just over the sea.** Rejected: it would mean a 130 m dive from the ring and a run skimming the heaps, and it changes the flight you liked.

## 3. The nose arrow goes quiet

At the pulse, `NoseCompass.quiet()`:

- the arrow stops tracking the shard;
- over 2.4 s, smoothstepped from where it pointed, it swings round to lie along the nose, tipped 22° down toward the cowl (`NoseCompass.rest`);
- its glow fades from its tracking energy (0.8 or more) to 0.06, and its gold dims to 55%;
- it shrinks to 85%.

The pulse's flare still plays on top during the first 1.2 s, so it reads as a flare, then a fold. It moves at most 1.75° a frame, so there is no pop. If you get out and board again after the chain has started, it comes up already folded (`quiet(true)`). Before the pulse everything is as it was: it wakes with the stone, tracks the shard, and brightens on course.

## Files

- **New:**
  - `scripts/sky_puff_burst.gd`: short-lived game-cloud puffs;
  - `tools/isle_chain_timings.gd`: the timing table.
- **Deleted:** `shaders/isle_cloud_sea.gdshader` (and its `.uid`).
- **`studies/aqueduct_isle_chain.gd`** (rewritten in part):
  - no sea patch;
  - `SEA_TOP` at the near sea;
  - the isle's rise defaults;
  - the ring's long rise, its burst and stream, and its speed-aware wake;
  - the first hall placed at the threading, with a speed-aware lead;
  - the arrival settings handed to the chain;
  - the new flags.
- **`scripts/hall_chain.gd`** (additions; the study's defaults are unchanged):
  - `clear_range`;
  - `burst` and `puff_scale`;
  - `settle_by`, `plane_speed` and `catch_up` (each hall's `pace`, `near`);
  - `length_at`;
  - `gate_of`.
- **`scripts/hall_rise.gd`:** `burst`, `puff_scale` and `BURST_UP`. With a burst set, its puffs go there in the world. It is unchanged without one.
- **`shaders/sky_cloud_puff.gdshader`:** `instance_fade` (off by default).
- **`scripts/nose_compass.gd`:** `quiet()`, `rest()` and the quiet constants.
- **`studies/aqueduct_isle.gd`:**
  - the arrow quieted at the pulse (and on boarding again);
  - no patch floor;
  - `flown`, so plane captures wait on seconds flown;
  - the comments.
- **`tests/test_isle_hall_chain.gd`:** rewritten for the above.
- **`run-aqueduct-isle.command`:** the new flags in its comments.

## Tests (headless)

`tests/test_isle_hall_chain.gd` takes about 34 s. It checks:

- **No patch:**
  - no greybox cloud patch anywhere in the scene, and its shader is gone;
  - the bursts are the sky puff shader, shared with the chain;
  - things break out of the near sea's top.
- **The ring:**
  - hidden at the start and at 600 m;
  - it wakes 420 m out: still 8.6 s later, with you there at 30 s at cruise and 19.1 s at boost;
  - a 30 m/s dive wakes it from 470 m, cruise doesn't;
  - it starts under the sea's top, bursts out in puffs (40 at once), stands on time, and collides;
  - the nose arrow points at the shard, not the ring;
  - crossing beside it triggers nothing.
- **Threading:**
  - threading counts, and the first hall starts rising at once;
  - for the 1.5 s pause, no chunk is through the cloud and there is no flash, and the arrow isn't quieting;
  - then the pulse;
  - the gate is 0.00° off the exit heading and 205 m ahead;
  - it is still 2.5 s before you get there at the threading speed;
  - threaded at boost, the way in would stand 287 m on;
  - the first chunk breaks out as the pulse runs.
- **The arrow:**
  - it starts folding with the pulse, at most 1.75° a frame;
  - it ends at rest (0.00° off) with its glow at 0.06;
  - it no longer tracks when the target moves.
- **The chain:**
  - the autopilot flies 2 halls (3 made, 40 s) with 0 bumps, never inside stone, high over the cloud;
  - each gate is fully still (pending or set) when the plane reaches it at cruise. This is stricter than round 1's "easing in or settled".
- **`--no-chain`:** as before.

Run under the runner and passing: `test_isle_hall_chain` (with the runner's known exit leak), `test_isle_lodestone`, `test_aqueduct_isle`, `test_aqueduct_isle_plane`, `test_aqueduct_isle_look`, `test_aqueduct_isle_sky` (known exit leak), `test_lodestone_study`, `test_hall_chain`, `test_hall_rise` and `test_scene_picker`. The headless import is clean.

`test_aqueduct_isle_life` failed once in the parallel run on one wind leaf ("1 off" the turf). It passes run alone, on this branch and on dfa139d2, and this round doesn't touch the wind life. The full suite was not run.

**Not verified headless.** Everything about the look (the cloud volume hiding a chunk under the heaps, the puffs' light, the billows) needs the GPU. Headless uses the dummy renderer, and the cloud volume needs a RenderingDevice. Those points were judged by eye from the rendered captures above only.

## What's weak

- **Gaps in the sea.** Between heaps the sea is open down to its floor (−150). A chunk starts 25 m under the heaps' tops (−133 for its top). If it rises in a gap, its top can show for a moment before its burst. In the captures the breakthroughs read as coming out of cloud, but nothing checks where the heaps are. The sea's swell under each hall (see Alternatives) would fix this.
- **The puffs are a touch brighter than the volume's heaps** right at the breakthrough (after_s01). Close, but the two shaders light differently. `PuffBurst` could take the sea's style colours.
- **The long climb takes most of each hall's rise.** You watch the chunks come up a long way. It reads as an eruption in stills, but how it feels in motion at 30 m/s is unchecked: grand, or too quick?
- **The halls are still greybox and still backlit black at this hour** (after_t30), as in round 1.
- **Catch-up changes the rise's speed** (up to 1.6×). It is only noticeable if you boost late, but it is a visible speed-up.
- **A rising chunk still passes through the plane** if you fly into it as it climbs, as before.
- **Carried over from round 1, still open:**
  - one shot only;
  - nothing tells you to thread the ring;
  - the chain's heading follows how you thread;
  - the `test_scene_picker_entries` exit crash, not rerun here.

## Open questions

1. Is the long climb out of the sea right, or would you rather the halls broke out of a local billow at your height (the fallback above)?
2. Should the sea heave up under each rising hall (the islands' swell), so the eruption has a mound of cloud under it?
3. Ring at 420 m: is seeing it rise from that far good, or does it give the surprise away?
4. The quiet arrow: folded flat along the nose and dim, or sunk back into the cowl entirely?
5. Catch-up: keep it (hidden help at boost), or let a boost meet a gate still coming up?
6. Should the halls' 30 m/s break-through stay, or would a slower, heavier climb (`--rise-speed=20`) with a longer lead suit the game better?

## Fix (2026-10-11, fix/hall-line-trigger): the ring wakes as you near

Played from the front door, "the arch is always there". The ring woke 420 m out, and the ring stands 469 m from the isle's middle, so it woke as the plane rolled off the isle's north edge and stood still half a minute before the plane got there. The loop tests never saw this: they open the isle with the stone carried and jump the plane 600 m and then 410 m out on the ring's line.

- The ring now wakes once the plane would be there within its rise plus 4 s at its speed (cruise at the least), and within 150 m at the least: 176 m out at cruise, 277 m at boost. It stands about 4 s before you get there, so you see it come up out of the cloud.
- A plane that speeds up after it wakes can reach it while it still climbs. Flying through its opening, where it is at that moment, threads it all the same, and it climbs on to stand through the pause. It collides only once it stands, as before.
- The line's pieces start building as soon as the stone rides in the plane, no longer only when the ring wakes, so the first real piece is ready by the thread.
- Without the stone nothing changes: the ring never wakes and the shard has no arch of its own.
- `tests/test_isle_loop_played.gd` plays it the player's way. It opens studies/zenscape.tscn with no study flags, flies out without the stone (no ring, no halls), then walks to the stone, keeps it, boards the parked plane, rolls it off the edge, flies at the ring, threads it and flies into the first Sundered piece.

The second report, "when I go through it, no Sundered hall", did not reproduce on main b6fc79b4. Threading worked through the real path, headless and rendered, with fixed steps and with live input through the game's own `_process`, from straight on, ±40°, the reverse side, 3 m off centre, at boost, after three minutes of circling and after leaving and re-boarding. Every time the first piece rose and stood ahead.
