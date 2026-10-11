# Rim dragon (experiment)

A giant dragon rises out of the cloud sea, swoops over the aqueduct isle, then
grips the east rim and rears its head over the edge, the way the Ruined
Kingdom dragon does in Mario Odyssey. It blows gales across the isle and holds
a treasure in its mouth. There is no combat and no fire. The gusts knock you
about, and you only lose position and time.

Branch `study/rim-dragon`. This is a demo round. It has no tests, no bot
sweeps and no perf pass.

## Play

- `./run-rim-dragon.command`: the aqueduct isle with `--dragon`. The dragon
  rises after 5 s.
- `./run-rim-dragon.command --dragon-perched`: starts with it already on the rim.
- Title, then Scenes, then Ruins, then "Rim dragon".

Flags (scripts/rim_dragon.gd):

| Flag | What it does |
|------|--------------|
| `--dragon` | turns it on (studies/aqueduct_isle.gd) |
| `--dragon-perched` | skips the flight |
| `--dragon-delay=<s>` | seconds before it rises (5) |
| `--dragon-fly=<s>` | length of the flight (24) |
| `--dragon-calm` | gusts are look only and never knock |
| `--dragon-skip=<s>` | runs it on that far at the start (for captures: `--dragon-perched --dragon-skip=3.1` with `--capture` lands mid-gust) |

## What's built

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

## Captures (local, gitignored)

- `docs/design/rim-dragon/rim_wide.png`: on the rim, panting (taken before
  the materials were brightened).
- `docs/design/rim-dragon/mid_gust.png`: mid-gust, with streaks across the
  isle.
- `docs/design/rim-dragon/mouth_open.png`: mouth open, the gem on the tongue.

## Rough

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
