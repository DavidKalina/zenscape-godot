# Rim dragon (experiment)

A giant dragon from the cloud sea, after the Ruined Kingdom dragon in Mario
Odyssey. Round 1 gripped the isle's rim and blew gales; the user found it
"animatronic" (no body) and out of the game's style. Round 2 gives it a full
body and makes it fly well. The rim grip and gusts are parked.

Branch `study/rim-dragon`. This is a demo round: no tests, no bot sweeps, no
perf pass.

## Round 2: the sky dragon

### Play

- `./run-rim-dragon.command`: the aqueduct isle with `--dragon`. The dragon
  rises out of the cloud sea after 3 s, makes a low pass over the isle, then
  roams.
- `./run-rim-dragon.command --dragon-look=a` (or `b`, `c`): the dress.
  `b` is the default.
- Press **V** in game to cycle the dragon camera: chase, orbit, look (from
  where the camera was), then off. `--dragon-watch[=chase|orbit|look]`
  starts on it.
- Title, then Scenes, then Ruins, then "Sky dragon". "Rim dragon (round 1)"
  is round 1.

Flags (scripts/sky_dragon.gd):

| Flag | What it does |
|------|--------------|
| `--dragon` | turns it on (studies/aqueduct_isle.gd) |
| `--dragon-look=a\|b\|c` | the dress: a angular, b carved (default), c stone and glow |
| `--dragon-watch[=mode]` | starts with the dragon camera on (chase, orbit, look) |
| `--dragon-delay=<s>` | seconds before it rises (3) |
| `--dragon-skip=<s>` | runs it on that far at the start (captures) |
| `--dragon-seed=<n>` | the route's dice |
| `--dragon-log` | prints where it is and what it is doing every 2 s |
| `--dragon-hold` | pose check: holds it in place 120 m up east of the isle |
| `--dragon-phase=<0..1>` / `--dragon-pose=glide\|dive` | with hold: freezes a beat phase or a pose |
| `--dragon-orbit=<deg>` | fixes the orbit camera's angle from its nose (90 = right side) |
| `--dragon-rim` | round 1's rim grip instead (scripts/rim_dragon.gd) |

Capture example: `--dragon --dragon-delay=0 --dragon-skip=26
--dragon-watch=chase --capture=/tmp/x.png --capture-wait=4`.

### The model

`art/blender/rim_dragon/dragon_body_build.py --style=a|b|c` builds one body
and one rig in three dresses in headless Blender, and writes
`assets/models/rim_dragon_<style>.glb` (`--blend` also saves a .blend).

- **Body.** One loft runs from the back of the head down a thick neck,
  through a deep, broad chest and the back, and out along a long tapering
  tail. It ends in a flat diamond blade. The head is 1.22x scale, with a
  heavy brow peaked over sunk amber eyes. The horns sweep back flat. The
  snout is short and square, the lower jaw big, and the teeth are ivory (no
  longer gold). It has four thick legs with claws. The wings span about
  84 m, with deep membranes (about 16 m chord at the body) on a real arm,
  wrist and four fingers. The body is about 56 m nose to tail. Everything
  is flat shaded: a 2.8k triangles, b 5k, c 4.6k (round 1 was 86k).
- **Rig.** `root`, `chest`, `spine.2`, `neck.0-2`, `head`, `jaw`, `hips`,
  `tail.0-5`. Each wing has `wing_arm`, `wing_fore`, `wing_hand`,
  `wing_f1`/`wing_f1b`, `wing_f2-4`. The legs are `fore_upper/lower/foot`
  and `hind_upper/lower/foot`. Rest is the glide pose. The body loft is
  weighted by its ring centres along the spine chain, so a deep chest ring
  moves as one. The membranes blend between the finger bones and the body,
  so they fold with the wrist.
- **Dresses.**
  - **a, angular:** 8-sided rings 2.3 m apart, few spikes, the biggest
    planes.
  - **b, carved:** 12-sided rings 1.45 m apart. The bands alternate, which
    gives scutes on the belly and plates on the neck. It adds a double row
    of back plates, brow plates, cheek spikes, jaw spikes, ringed horns, a
    nose horn and a lesser horn pair.
  - **c, stone and glow:** a's solids with a matte, stone-like hide. The
    membranes are smooth and soft, going from deep violet to a rose glow at
    the trailing edge (a ShaderMaterial in the game). The back fins and the
    tail blade glow amber. This follows the style rule.

  The game repaints by material name (`_material` in sky_dragon.gd) with a
  dark basalt-violet hide.
- **Sheet.** `art/blender/rim_dragon/dragon_body_sheet.py` writes
  `docs/design/rim-dragon/dragon_sheet.png`. It has a row per dress (a, b,
  c from the top) and columns for side, three-quarter, head close-up and
  top (Workbench, rest pose).

### The flight (scripts/sky_dragon.gd)

All of it is procedural on the rig, every frame.

- **Flight model.** It keeps a heading, a path angle, a speed and a turn
  rate, and steers at a waypoint with an eased turn rate (at most
  0.3 rad/s). The bank follows the turn: atan(v * rate / g). Speed comes
  from thrust (on the downstroke only), drag and gravity along the path.
- **Rhythm.** This follows the user's mid-round note: "less flaps, big flaps
  that let it coast". Cruising, it beats in bouts of 1 to 2 big, slow beats
  (0.27 Hz, raise +1.1 to -0.78 rad) when it drops under 21 m/s. Then it
  glides on spread wings until it is slow again, usually 15 to 20 s.
  Continuous, quicker beats (0.36 Hz) only come on climbs steeper than
  about 12 degrees and in the rise.
- **A beat.**
  - The downstroke is the power stroke, quick through its middle.
  - On the upstroke the wing folds: the forearm swings in, the hand and
    fingers fold back, and the outer membrane collapses.
  - The tips lag the raise's speed.
  - The body heaves 2 m against each beat, and the chest, hips and neck
    nod with it.
- **Gliding.** Small separate trims on each wing. The inside wing dips a
  touch in turns.
- **Dives.** The wings half tuck: raised, folded and swept back.
- **Neck, head and tail.**
  - The neck leads into turns through a spring (with a little overshoot).
  - The head holds level against pitch and bank.
  - The head turns to look at the camera when it passes within about
    200 m.
  - Every 10 to 20 s the jaw drops in a silent roar.
  - The tail is a verlet rope dragged from the hips, pulled softly toward
    its rest line. It trails the curve through turns and swings late out
    of them, and the bones are turned to lie along it.
  - The legs are tucked: forelegs folded up, hind legs trailing.
- **Route.** It runs in legs.
  - The start: a spiralling rise out of the cloud sea east-south-east of
    the isle, then a low pass over the isle about 44 m above its top.
  - After that it picks big circuits (r 300 to 460 m, 115 to 160 m up),
    threads between two neighbouring isles a little above the lower rim,
    or makes a climb to about 220 m followed by a long dive.
  - After about 3 legs there is usually another low pass.
  - The isles come from `aqueduct_isle_sky.gd`: ISLES and CLUSTERS within
    700 m.
- **Dragon camera.** It overrides the host's camera after the host has
  placed it each frame, so walking or flying carries on underneath. The
  FOV is restored when you turn it off.

### Captures (local, gitignored, docs/design/rim-dragon/)

- `dragon_sheet.png`: the three dresses compared.
- `flight_a_chase.png`: a, banked glide from the chase camera.
- `flight_b_upstroke.png`: b, the wings folding up on the upstroke, the
  tail trailing.
- `flight_b_glide.png`: b, gliding past the aqueduct isle (orbit).
- `flight_c_chase.png`: c, from behind, the glowing membranes spread.
- `flight_c_from_isle.png`: c, overhead in the low pass, seen from the isle.
- `flight_a_glide_hold.png`: a, held glide pose (pose check).

### Rough

- The head reads big and squat (on purpose). Head-on, the red mouth roof
  shows between the teeth as a flat band. Close up, the face is still a
  plain box next to Odyssey's.
- Seen from the side the wings go edge-on and thin. They read best from
  above and behind. The sheet's three-quarter view is framed loosely.
- The dragon camera does not stop pilot input, so walking keys still move
  him underneath.
- There is no collision with isles or airships. The waypoint heights keep
  it clear, but a thread leg can pass close to hanging rock, and it flies
  through the airship route near the isle.
- No sound: no wingbeat whump or roar.
- The waypoint steering can make a wide loop when a point lands inside its
  turn radius. It skips points behind it within 200 m.
- The C membrane glow is fairly saturated in bright daylight.
- Pose-check flags (`--dragon-hold` and the rest) are debug aids.
- No LODs. They are not needed at about 5k triangles.

## Round 1 (parked behind `--dragon-rim`)

### Play

- `./run-rim-dragon.command --dragon-rim`: the dragon rises after 5 s.
- `./run-rim-dragon.command --dragon-rim --dragon-perched`: starts with it already on the rim.
- Title, then Scenes, then Ruins, then "Rim dragon (round 1)".

Flags (scripts/rim_dragon.gd):

| Flag | What it does |
|------|--------------|
| `--dragon-rim` | turns it on (studies/aqueduct_isle.gd) |
| `--dragon-perched` | skips the flight |
| `--dragon-delay=<s>` | seconds before it rises (5) |
| `--dragon-fly=<s>` | length of the flight (24) |
| `--dragon-calm` | gusts are look only and never knock |
| `--dragon-skip=<s>` | runs it on that far at the start (for captures: `--dragon-perched --dragon-skip=3.1` with `--capture` lands mid-gust) |

### What's built

- **Model**: `art/blender/rim_dragon/rim_dragon_build.py` generates it in
  headless Blender and writes `assets/models/rim_dragon.glb` (about 86k
  triangles). `rim_dragon_preview.py` renders Workbench stills. The head,
  jaw, neck, arms and hands are metaball unions. Each one is turned into a
  mesh, then gets two displaces (lumps, then Voronoi scale plates). After
  that it is decimated into irregular flat-shaded facets. Horns, teeth,
  claws and neck spines are ringed swept tubes. The wings are lofted
  scalloped membranes. Rig: `neck.0-2`, `head`, `jaw`,
  `upper_arm/forearm/hand.L/R`, `wing/wing_tip.L/R`. It has no clips, because
  the game poses the bones. Its origin is the rim's lip and the island lies
  ahead. The head is about 9 m tall without the horns.
- **Behaviour**: `scripts/rim_dragon.gd`, one self-contained node:
  - It waits, then flies a Catmull-Rom path in the perch's frame. The path
    climbs out of the cloud sea (`IsleChain.SEA_TOP`), passes high over the
    isle, banks round, drops under the rim and lands.
  - Once perched it loops through four states:
    - **pant** (4.6 s): chin on the turf, jaw open, the gem glinting on its
      tongue.
    - **inhale** (1.5 s): the tell. The head rears up and back and streaks
      flow into the mouth.
    - **blow** (2.4 s): the head thrusts forward and sweeps its yaw ±0.42 rad,
      throwing streaks out of the mouth. At the same moment the isle sends a
      strong gust front along that way, so the grass and air ribbons lie over.
    - **recover**.
  - In the cone's core (±0.34 rad, 55 m) with a clear ray from the throat,
    the pilot gets `motor.knock` into a tumble. In the wider band (±0.6 rad)
    he's only pushed along the ground. Stone between him and the throat
    shelters him.
  - Touch the gem (2.8 m from the pilot's middle) and it's taken. The dragon
    roars, lifts its hands, falls back off the rim and sinks into the clouds,
    and a crystal pops on the HUD.
  - While perched, invisible collision rides the skull, the snout, the lower
    jaw (you can stand on it) and the hands.
- **Pilot knock and tumble**: `scripts/pilot_motor.gd` and
  `scripts/pilot_figure.gd` carry over the henge guardian's changes from
  `park/henge-guardian` unchanged: `knock`, `knock_velocity`, `recovering`,
  the tumble step, twirl-out recovery and the somersault and sit-down pose.
- **Isle hook**: `studies/aqueduct_isle.gd` builds it at `DRAGON_RIM`
  (126.6, -9, east rim, facing west), advances it every frame and runs it
  during `--capture`. It also wires the gust front and the "treasure taken"
  pop, and adds a foot-hint line.

### Captures (local, gitignored)

- `docs/design/rim-dragon/rim_wide.png`: on the rim, panting (taken before
  the materials were brightened).
- `docs/design/rim-dragon/mid_gust.png`: mid-gust, with streaks across the
  isle.
- `docs/design/rim-dragon/mouth_open.png`: mouth open, the gem on the tongue.

### Rough

- The head is good at a distance. Close up it still reads more "Western
  dragon on a pug's snout" than Odyssey's massive brow. The brow and
  cheekbones want more mass and the snout wants to be shorter and squarer.
- The hide is a dark violet-black. It's lit glossy, but the sheen is a
  StandardMaterial clearcoat, not a wet shader. The teeth pick up warm light
  and read gold-ish.
- The pant pose leaves the jaw tilted: the chin is on the turf and the back
  of the jaw sits about 0.8 m up. The neck is never shown properly, and seen
  from the side the chest blob hangs below the rim.
- The flight is only seen in passing. The flying pose and banking are rough,
  and there is no body or tail, so close up mid-swoop it looks odd. The
  landing interpolates its transform rather than really climbing.
- No sound: no roar, inhale or wind.
- The pilot isn't carried by the moving jaw. If the head moves while he
  stands on the jaw or skull, he can clip in. A gust usually throws him out
  first.
- It runs one cycle: once the treasure is taken it doesn't come back.
- Stretch goal not done: seeing it clinging to another isle from afar.
- The model is 12 MB because flat shading splits every vertex. It could be
  decimated harder or use LODs.
