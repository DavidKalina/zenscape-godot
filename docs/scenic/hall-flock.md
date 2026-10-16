# Hall flock (round 1, prototype)

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
