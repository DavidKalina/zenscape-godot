# Birds round: handoff

## Songbirds round (latest)

The user found the endless birds (one MultiMesh of a dove-like body with a
vertex-shader flap) far too jittery and asked for the isles' songbirds.
`scripts/endless/endless_birds.gd` is rewritten around them; the hook in
`studies/endless_flight.gd` is unchanged (`setup`, `step`, `note`).

### The jitter's cause

The flight paths were already smooth: a headless/rendered metric
(`scratch/birds_jitter.gd`: change of yaw rate, roll step and the second
difference of each bird's screen position per frame) showed sub-pixel
path noise. The buzz came from the pose and the update rate:

- **The wingbeat.** 12 beats a second cruising and 19 on the burst, with a
  warped fast downstroke and the body bobbing on every stroke: 3 to 5
  rendered frames a beat at 60 fps, so the wings aliased into a flicker
  (worse at uneven frame times). The songbirds beat 2.4 a second
  (`BEAT` 15 rad/s; 3.8 on the burst) in bounds with the wings tucked.
- **Far flocks stepped every other frame** with twice the delta: they
  moved at 30 Hz against a 60 Hz camera (judder).
- **Bank read off the clamped steering acceleration** (bang-bang: the
  acceleration cap was saturated against a stiff spring and separation),
  so the roll swung with it; perched birds also snapped their facing.

Now every bird steps every frame. A flying bird follows its place in the
flock on a critically damped spring (velocity eased toward the place's
velocity plus a quarter-response pull on the gap; no clamp), places sit on
a sunflower disc so no separation steering is needed, facing follows the
smoothed velocity, bank comes from the smoothed turn rate, and the flock's
frame turns smoothly (no snap to FORWARD at low speed).

### What it does now

- **Bodies.** The songbird's own meshes (`SongbirdBody.meshes_for`, its
  `HEAD_AT`, `SHOULDER`), drawn as six MultiMeshes per species: sitting
  (body and folded wings) plus the head apart (so it can look about),
  flying with wings tucked (the bounds), flying without wings, and each
  spread wing hinged at its shoulder. 3 species (sparrow, robin,
  goldfinch; one per flock) = 18 draw calls at any count, no LOD and no
  pop: every bird is the full songbird at every distance (~430 triangles).
  `shaders/endless_birds.gdshader` is now the songbird look (vertex colour,
  rough) with a wrapped light, backlight and a small fill, since with the
  plain songbird shader their shaded sides went near black against the
  land. They cast shadows. Span 0.85 m (0.3 of the plane's span; 2.2 times
  the isles' bird), `--bird-size=` scales it.
- **Flight (the isles').** Bounding flap-and-glide: beating 0.34 s
  (0.48 s while with the plane, wheeling or peeling), tucked 0.22 s, always
  beating when climbing or landing; lift `sin(beat)*0.95+0.15`, the
  isles' formula. Pitch from the climb, bank into turns, head held a
  little down in flight.
- **Startle.** A ripple through the crown (nearest first), a 0.12 s
  crouch (squat, lean forward, wings folded), then out and up with the
  wings flung up for the first stroke and a stretch that eases off.
- **Perched life** (flocks within 110 m of the eye): look-about snaps (head
  eased at 14/s to a new glance every 0.4 to 1.6 s), tail flicks, hops
  round and up or down the crown (0.35 s arcs) every 4 to 14 s; birds on
  the ground hop and peck (the isles' forage).
- **Perches** use the trees' real crown (`cell_trees` crown bottom and
  radius) rather than a guessed cone.
- **In the plane:** as before. Perched flocks ahead along the plane's way,
  flushed by the plane, ride alongside, peel, dropped out of sight; far
  wheeling flocks.
- **On foot:** up to 2 flocks kept in trees 22 to 85 m from him (the ones
  in view preferred), 30% of each foraging round the foot of the tree.
  Him within `FIGURE_NEAR` (3.6 m, 5.5 at a run over 4 m/s; times 1.33 for
  the birds' scale) of a bird across (and under 14 m below it), or under
  the crown, flushes it: out all at once, wheeling over the tree for 2.5 to
  4.5 s, then off to another tree 45 to 95 m from him, each bird coming in
  to its own perch (front point, then the slow approach), then the perched
  life again (calm 6 s). With no tree it flies off and is dropped. Dropped
  past 240 m from him.

Flags as before: `--birds=0` / `--no-birds`, `--birds=X`, `--bird-range=X`,
`--bird-size=X`, `--bird-ride=S`, `--ambient-birds=X`.

### Cost

RTX 4070 Super, 2560x1440 window, uncapped, the low pass over forest of
`scratch/birds_cost.gd` (20 s averages):

| | birds on | `--birds=0` |
|---|---|---|
| birds alive | ~62 | 0 |
| birds step (GDScript) | 0.48 ms | 0 |
| GPU | 13.2 ms | 13.3 ms (noise) |
| frame | 14.2 ms | 14.3 ms |
| draw calls | 982 | 964 (+18: the parts' MultiMeshes and shadows) |

Headless with 60 to 80 birds the step is 0.4 to 0.9 ms, of which drawing
(composing up to three transforms a bird into the buffers) is 0.3 to 0.45.
F1 shows flying/perched, flushes and the step's and the draw's ms.

### Proof (scratch drivers, uncommitted)

- `scratch/birds_pass.gd`: a flock flushes, rides, peels, is dropped;
  closest bird 3.4 m from the plane, no errors.
- `scratch/birds_foot.gd -- --scene-args --on-foot`: a flock in a tree
  74 m off, all 10 look about, ~30 hops while he walks up through the
  real input, flushed 10.5 m from the trunk (by a forager), wheel, flit,
  settled in another tree, no errors.
- `scratch/birds_film.gd` (`--side` a camera beside the flock): crops.
- Sheets: `captures/shots/birds_side_sheet.png` (burst and ride from the
  side, every 2nd frame), `birds_chase_sheet.png` and `birds_chase_16.png`
  (the ride at the chase camera), `birds_chase_full.png` (a far flock
  over the ridge), `birds_foot_perched.png`, `birds_foot_close_sheet.png`,
  `birds_foot_flush_sheet.png`.
- Smoke passes: default, `--on-foot`, `--birds=0`, `--birds=3
  --bird-size=2 --ambient-birds=2`. Shared songbird code untouched, so
  the isles are unchanged.

### Weak spots

- Stills, not a film: the smoothness is shown by the metric and frame
  strips; judge it by playing.
- At the chase camera the flushed flock starts ~40 m off the plane and
  out to the side, outside the frame for the first 1 to 2 s; it is in view
  once the slot closes (the ride geometry is unchanged from before).
- They still fly through neighbouring crowns (no tree avoidance), and
  sit on the crown's surface, not on boughs; no branch sway (the isles'
  `ride` uniform is per material, not per instance).
- On foot a forager can flush the flock while he is still ~10 m from the
  trunk.
- No sound, no gust flush, no dusk leaving.

---

## First round (kept for reference)

`scripts/endless/endless_birds.gd`, hooked into `studies/endless_flight.gd`
(built after the trees, stepped after them each frame, a line on F1's
numbers). Perched flocks are put 140 to 280 m ahead along the plane's way
and 5 to 38 m off its line, every 0.5 s when fewer than 2 wait and the
plane is under 80 m over the ground. The plane within `FLUSH_SPANS` (16) of
its span flushes one: they burst, form up, ride a slot 6 to 9 m out and 0
to 2.5 m over the plane for 6 s (`--bird-ride=`) sliding from 16 m ahead to
beside it, top out at 1.08 times cruise, then peel 1 rad away over 3 s at
0.78 times cruise and are dropped past 200 m, behind the camera past 50 m,
or after 20 s. Up to 2 far flocks of 16 to 26 birds at twice the size wheel
130 to 300 m ahead over the higher of two sampled spots and are dropped
past 650 m. The first body was an 80-triangle dove in one MultiMesh,
flapped in its vertex shader; it is replaced.
