# Hall flock (round 2: tune, prototype)

The user flew round 1 and found it had too many birds, looked a bit
skittery, and always left by the same exit. This round fixes those three.

## What changed in round 2

- **Fewer birds:** `COUNT` 480 -> 180 per piece. `BODY` (the flock's
  extents) is smaller to match.
- **Smoother motion** (`scripts/hall_flock.gd`):
  - Ways: the weave is broad and low (`WEAVE_STEP` 6 -> 14 m, `WEAVE`
    0.5-1.6 m). Each way is then relaxed: three running-mean passes at
    1 m, 4 points either side (`_relax`, a Gaussian of σ ~3.5 m). A point
    that would come near the stone or into the lane moves only part way.
    The ledge and the climb-out are held. Wiggles shorter than ~15 m go;
    loops and broad curves stay.
  - Heading and bank come from the bird's closed-form way at t ± 0.1 s,
    no longer from frame-to-frame differences. Uneven frames or late
    worker poses can't shake them. The shown heading is eased (16/s) and
    the bank eased (5/s).
  - The joins into and out of the flock are Hermite curves from the way's
    end velocity to the flock's velocity. Round 1 overshot straight up
    and hooked back.
  - The flock's middle runs on a little, then wheels round one broad
    circle (`WHEEL_R` 20-28 m at `WHEEL_V` 13-16 m/s, left or right per
    piece), kept over the piece. Round 1's course slowed to a near hover,
    so the birds' own ripples spun their headings. The ripples in the body
    are slower and smaller.
  - The clamp over the roof (`_clear`) is eased, so a bird rounds up over
    the roof instead of snapping onto it.
  - Wingbeat: the shader's `beat_rate` is 7.5 -> 4.2 Hz and `sweep`
    0.85 -> 0.75. Each bird flaps in bursts and glides with its wings held
    out, on its own cycle (`FLAP_CYCLE` 1.6-2.8 s, `FLAP_SHARE` 35-55%
    flapping), eased in and out. Takeoff, steep climbs, hard turns and
    landing force full beats.
  - The pose group task runs at high priority. `status()` reports
    `late_frames` (frames whose poses came late) next to `up_frames`.
- **Varied exits:**
  - `_openings` finds each piece's openings: where an open cell under the
    roof and inside the walls meets open air (roof breaks, side arches,
    open bays). They are clustered and named `kind@m`
    (`left@41`, `right@66` ...), and those at the nave's ends are left out.
    A piece has 7-21 of them.
  - Per piece (seeded), up to `NEAR_EXITS` (4) openings get a near-way
    field, and up to `STREAM_EXITS` (2) in the far half get a stream field
    that stays low in the lane until `RISE` (10 m) short of the opening.
    The far end's open roof stays one of the stream's ends.
  - Birds roosting within `GROUP` (9 m) of each other on one side go
    together: the stream (`FAR_SHARE` 0.6 of the groups) or an opening
    near them, never one back toward the plane. `SPLIT` (20%) pick their
    own.
  - `LOOP_SHARE` (35%) of the stream groups loop once in the nave (a level
    circle, `LOOP_R` 4.5-7 m, slower at `LOOP_SPEED`) where the grid has
    room, then leave.
- **Safety:** any way that crosses the lane's column, up to `LANE_OVER`
  (6 m) over the lane, is timed like the stream. It goes only while a
  plane at `PLANE_PACE` would stay `GAP` behind it, and with no stagger.
  Without this, a near bird crossing the nave to an opening on the far
  side passed 3.5 m over the plane.
- `--hall-flock=0`, `--hall-flock=<n>` and `--hall-flock-size=` are
  unchanged.

## Round 2 proof (headless, `--near-ring --autopilot`, real loop)

Exits: birds that went, by the opening they left by. `open-roost` birds
roost outside the roof and walls already (wall heads, roof edges by
breaks) and simply rise where they sit.

| Piece | Went | By opening |
|---|---|---|
| 0 | 79 | left@85 30, left@41 3, open-roost 42, none 4 |
| 2 | 180 | left@87 16, left@63 16, right@45 15, left@76 13, left@29 10, left@54 8, right@71 6, left@14 6, right@92 5, left@41 4, left@68 3, right@29 3, right@48 2, right@98 2, right@25 1, open-roost 67, none 3 |
| 3 | 172 | left@37 29, left@75 22, right@59 15, left@64 5, right@29 4, right@49 1, open-roost 95, none 1 |
| 4 | 71 | left@72 9, left@99 7, far-end 1, open-roost 38, none 16 |
| 5 | 120 | left@66 21, far-end 19, left@76 9, right@49 3, left@43 3, right@57 3, open-roost 62 |

Pieces stood late in headless runs keep their birds (by design), so not
every piece flies in every run.

- 0 birds inside the hull boxes and 0 inside the collision, over 6000
  frames.
- Closest bird to the plane's box: 6.6 m and 9.2 m in two runs. Round 1's
  run was 9.4 m. The 6.6 m bird was off the lane, 8.6 m to its side.
- Smoke passed with 0 errors.
- `test_isle_hall_chain.gd` was run once and passed.

Smoothness: every flying bird, every frame, from the poses as shown.
Both versions were driven the same way over 4200 frames.

| | Round 1 (480) | Round 2 (180) |
|---|---|---|
| Turn rate, on its way, p95 / max | 17.2 / 128 rad/s | 4.6 / 18.6 rad/s |
| Turn rate, joining, p95 / max | 4.0 / 79 rad/s | 2.9 / 4.3 rad/s |
| Turn rate, in the flock, p95 / max | 2.5 / 180 rad/s | 0.87 / 2.8 rad/s |
| Frame-to-frame heading flips | 119 | 0 |
| Wiggles (yaw-rate reversals over 2 rad/s within 0.5 s) | 4334 in 4554 bird-s | 0 in 1658 bird-s |
| Frame steps over 11° | 14672 (5.4%) | 55 (0.06%) |
| Flapping / gliding share | 82% / 7% | 60% / 23% |
| Late pose frames | not counted | 0 of 1615 |

The remaining highs on the ways are takeoffs and pitch-ups out of roof
breaks.

## Round 2 cost (headless)

| Item | Measured |
|---|---|
| Worker poses, summed over the flocks in flight | ~0.6-1.7 ms/frame, worst 2.6-4.7 ms. Fewer birds, but 3 closed-form samples each |
| Main thread | ~40 µs/frame, worst 0.33-0.54 ms |
| Plan per piece, once, on a worker | 0.8-1.7 s (round 1: 0.8-1.2 s); the extra opening fields |
| Triangles | ~8k per flying piece (round 1: ~21k) |

## Drivers (round 2, `scratch/`, git-ignored)

- `flock_tune.gd`: the exit table, stone checks and closest bird. With
  `--smooth`, it gives the turn, wiggle and wingbeat numbers instead.
- `flock_follow.gd` (`--rendered`): a fixed camera that follows the
  flock's centroid.
- `geo_probe.gd`: ASCII slices of a piece's plan grid.

## Round 2 unfinished

- Birds leaving one opening rise in a narrow column, which reads as a
  string of beads for a second before they join the body. Spreading the
  climb-out (fanning the tail) would help.
- About a third to a half of each piece's birds roost in the open and
  rise where they sit.
- The wheel can carry the flock up to ~2 radii off to one side of the
  piece. That is checked clear of this piece's stone, but a line that
  curves could put a neighbour there (0 hits in these runs).
- I didn't get a good chase-camera still of the stream. At sheet scale
  the birds are too small, so judge it by flying it.

---

# Round 1

A flock of swifts roosts in every real piece of the Sundered line and
bursts ahead of the plane as it flies the nave.

## What changed

- `scripts/hall_flock.gd` (new). It holds the plan, the motion, the
  MultiMesh and the sound. Each piece gets one flock, planned on a worker
  once the piece stands still with its island and bodies stood.
  - **Plan.** The piece's hull boxes (`made.boxes`) go into a 1 m grid
    grown by `PAD` (0.5 m), and breadth-first fields find the ways out.
    The near way leaves by a roof break, an open bay or a side arch, and
    the plane's lane is shut for it. The stream way runs down the nave
    under `CEILING` (5.5 m), within the lane's width, and up out of the
    far end's open roof. Roosts are box tops 4.5 m and up with room above
    (ties, beams, wall heads, the roof's edges near breaks).
  - **Shaping a way.** Each bird's way is its cell walk, pulled straight,
    woven side to side, smoothed, then checked again against the real
    boxes. It then climbs to over the piece's top. Free flight (the body
    and the joins) is clamped over the piece's top while it is over the
    piece's footprint.
  - **Motion.** Each bird's position is a closed form of the piece's
    clock: roost, then its way (it accelerates off the ledge), then an
    eased join into a slot in one body. The body sweeps ahead, loops and
    drifts left, and turns as a whole, so the birds bank together. They
    come home the same way back. Heading and bank come from each bird's
    motion between frames. Poses are computed on worker threads (one
    group task per frame, one flock per item) and handed to the
    MultiMesh the next frame. If a frame's poses aren't ready, the birds
    keep the last frame's poses and the main thread never waits.
  - **Keeping clear of the plane.**
    - Near-way birds startle once the plane is 30-55 m short of them,
      with up to 0.5 s of stagger, so the burst ripples forward.
    - Stream birds fly the lane itself at 22-27 m/s, faster than the
      plane at boost. Each one goes only once a plane at 18 m/s would
      stay 8 m behind it wherever its way is in the lane. A faster plane
      sets them off sooner.
    - A bird the plane is already within 18 m of stays on its ledge.
      This happens when a piece stood late.
  - **Model.** The swift is about 44 triangles: a slim body, a forked
    tail and scythe wings. It is 3x a real swift's 0.42 m span so it
    reads at speed.
  - **Shader.** `shaders/hall_flock_bird.gdshader` (new) does the wing
    beat, fold and glide dihedral from INSTANCE_CUSTOM. The birds are
    dark, with a faint rim.
  - **Sound.** All of it uses existing kit clips.
    - The rush is `flutter-loop.wav` at pitch 1.35, placed at the
      flock's centroid. It gets louder the more birds are up.
    - The burst plays `wings-4` and `wings-3`.
    - The screams are `chirp-*` and `twitter-*` at pitch 1.5-1.95, from
      birds in flight, on a pool of 6 players.
- `scripts/hall_line.gd` has three small hooks: a preload, a `flock`
  var, creation in `configure` (real look only), and
  `flock.advance(delta, plane_at)` at the end of `advance`.

## Knobs

- `--hall-flock=0` turns it off. `--hall-flock=<n>` sets the birds per
  piece (default 480). `--hall-flock-size=<x>` scales the bird size.
- The constants are at the top of `scripts/hall_flock.gd`:
  - `COUNT`, `SIZE`
  - `LEAD`, `STAGGER`, `MIN_AHEAD`
  - `SPEED`, `STREAM_SPEED`, `PLANE_PACE`, `GAP`
  - `FAR_SHARE` (0.9 of eligible roosts stream), `CEILING`
  - `WEAVE`, `WEAVE_STEP`
  - `BODY`, `LOOP_R`, `LOOP_W`, `SWEEP`, `SIDE`, `OVER`
  - `HOME_PAST`, `HOME_SPREAD`
  - `FAR` (draw range, 240 m)

## How to see it

```
& $env:GODOT --path . studies/aqueduct_isle.tscn --rendering-method forward_plus --windowed --resolution 1440x900 -- --no-title --near-ring --autopilot
```

The burst comes as the plane enters each piece. Through the roof breaks
you see birds pouring up. In the nave you see a dark stream racing ahead
down the lane against the far end's light, and above the hall the body
forming. Drivers in `scratch/` (git-ignored):

- `flock_shots.gd` (`--rendered`): a chase-cam sequence.
- `flock_side.gd`: a fixed-camera sequence.
- `flock_check.gd` (headless): closest bird to the plane, birds in hull
  boxes, birds in the collision.
- `flock_perf.gd`: frame times.

## Proof (headless, through the real autopilot loop)

`flock_check.gd`, 3600 frames over pieces 0-2:

- 0 birds inside any piece's hull boxes.
- 0 birds inside the collision (point queries on layer 1).
- The closest flying bird came 9.4 m from the plane's box.
- Smoke (`tools/smoke.py studies/aqueduct_isle.tscn -- --near-ring
  --autopilot`) passed with 0 errors.
- In headless runs the line's pieces often stand late, under the plane.
  The birds of a piece the plane is already on stay put by design, so
  later pieces show few bursts headless.

## Cost

| Item | Measured |
|---|---|
| Main thread, mean while birds fly | ~35-45 µs/frame |
| Main thread, worst frame | 0.5-0.7 ms (the frame a planned flock's MultiMesh is stood) |
| Worker poses, mean summed over flocks in flight | ~1.2-1.9 ms/frame |
| Worker poses, worst | ~3 ms/frame |
| Plan per piece, once, on a worker | ~0.8-1.2 s (fields 0.25 s, roosts 0.15 s, ways 0.45 s) |
| Triangles (2 pieces of birds in view) | +~42k |
| Rendered frame/GPU time, vsync off, first runs | no measurable difference: 6.0-6.2 ms on vs 6.4 ms off, GPU 3.86 ms both |

Back-to-back perf runs were noisy: the second run was always slower,
whichever came second.

## Existing tests

- `tests/test_isle_hall_chain.gd`, "No hitch" (main-thread budget 4.0 ms):
  - With the first version (plan started at the piece's spawn, 1.7 s of
    GDScript on a worker beside the hand-over) it failed twice. The
    heaviest frame was 4.39 ms and 4.35 ms (island hand-over 4.39 / 4.35,
    body 3.49 / 3.41, worker build 5.4 s / 5.0 s).
  - With the flock off it passed at 3.28 ms (island 3.04, body 3.28,
    build 3.8 s).
  - After the plan was made cheaper (~0.8 s) and deferred until the
    piece is still, it passed with the flock on at 3.53 ms (island 3.07,
    body 3.53, build 5.0 s).
  - The margin is thin. CPU contention from the flock's workers can push
    it, so treat it as at risk.
- `tests/test_isle_loop_played.gd` fails "And the next piece rises behind
  it (1 pieces)" with the flock on and off alike. It was already failing
  and isn't from this change.
- The full suite was not run.

## Model budget (`docs/art/model-budget.md`)

The swift is a new procedural model of about 44 triangles.

- **Sculpt/bake:** doesn't apply; the mesh is already far below 5k.
- **Import LODs:** don't apply at 44 triangles. A visibility range is
  used (`FAR` 240 m), which leaves out a roosting flock two or more
  pieces away. Estimated saving: ~21k triangles per culled piece,
  negligible frame time.
- **Silhouette geometry:** this is what the model is, a scythe-wing
  outline in geometry.
- **Rigid parts on bones, parallax, vertex-colour grime:** don't apply.
  The wings bend in the vertex shader and there is no texture.

## Unfinished / next

- The stream is easiest to read in motion. In stills from the chase
  camera the birds are small (about 20-30 px at 15-25 m) and dark against
  dim stone. The ties at 6-7 m hide anything flying higher than the
  camera, which is why the stream flies low in the lane.
- The body above the hall is seen mainly on approach and through roof
  breaks. It isn't brought into view at the far end yet; the next piece
  could be in the way.
- Slits aren't used as exits. At 1.9 m they are too narrow for the 1 m
  grid with 0.5 m padding.
- Trees on the islands have no collision, so a side-exit climb could pass
  through foliage (not stone).
- Birds roost on box tops of the collision hulls, so a perched bird can
  float a few cm off the visual stone.
