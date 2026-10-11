# Rim dragon (experiment)

A giant dragon from the cloud sea, after the Ruined Kingdom dragon in Mario
Odyssey. Round 1 gripped the isle's rim and blew gales; the user found it
"animatronic" (no body) and out of the game's style. Round 2 gave it a full
body and made it fly well. Round 3 rebuilds it as a wyvern after Smaug and
makes it ride the air. Round 4 brings the attack back on a far isle: it
clings to the rim and blows gales across it, seen from the aqueduct isle.

Branch `study/rim-dragon`. This is a demo round: no tests, no bot sweeps, no
perf pass.

## Round 4: the attack on a far isle

The user's note on round 3: "Much better. Now, can we work on the attack?
I'd like to see him cling on to one of the other islands in the distance."

### Play

- `./run-rim-dragon.command --dragon-attack`: the dragon starts far out on
  its way in to **hills_ne**, about 270 m east-north-east of the turf. It
  grabs about 6 s in and is on the rim by about 10 s. Stand on the turf's
  east side and look ENE.
- Without the flag it roams as in round 3 and makes its first attack about
  40 s after rising, then another every 60 to 85 s
  (`--dragon-attack-every=<s>`, 70). The targets rotate: hills_ne (270 m),
  meadow_south (190 m, south), grove_east (135 m, east; the most trees).
  `--dragon-target=<name>` picks the first one.
- V's cameras frame the rim while it clings: chase is a three-quarter view
  from outside and to the side, orbit circles the rim point
  (`--dragon-orbit=<deg>` is measured from the rim's outward way), and look
  aims at the rim from where you stood.

### What happens (scripts/sky_dragon.gd, scripts/dragon_gale.gd)

- **Target and side.** Targets are listed in `DRAGON_TARGETS`
  (studies/aqueduct_isle.gd). It grips the isle's flank as seen from the
  turf (`_clear_side`): of the two flanks, the one whose rim stands
  furthest, as seen, from any nearer isle. grove_east would otherwise hide
  it on hills_ne. So it shows in profile, and the blast crosses the view.
  The rim is found on the isle's real outline (SkyIslet `on_land` and
  `ground_at`, marched outward), as are the wrist and foot holds either
  side.
- **Approach and grab.** It goes in wide and banking round, then low
  outside the rim. The grab is a 3.4 s Hermite curve from its flight
  velocity onto the hold. It pitches up into a flare, with the wings swept
  forward and back-beating at 0.75 Hz and the legs swung forward. The
  swell and bumps fade out.
- **The slam.** The pose snaps over in 0.3 s. The isle node itself dips
  (an under-damped spring) and tilts toward the dragon, collision and all,
  and stays a little tilted while held. Dust puffs burst along the rim,
  about 30 stones break off and tumble into the clouds, and the isle's
  songbird flock (SkyAmbientLife) is flushed.
- **Clinging.** The body hangs nose up (1.12 rad), belly to the cliff. The
  wrists (thumb claws) and the hind feet are reached to the lip each frame
  by a small CCD IK (`_reach`), so they ride the isle's shudder. The
  membranes hang folded like a cape and open on the blast. The tail rope
  hangs and swings slowly under the keel. The neck rears over the turf.
- **Breath cycle.**
  - **Settle:** a gasp.
  - **Pant:** 4.5 to 7 s, jaw panting, glancing round on springs.
  - **Inhale:** 2.1 s, the tell. The head draws back and up, streaks flow
    into the mouth, and the isle's trees lean toward it.
  - **Blow:** 3.8 s. The head thrusts forward and sweeps ±0.42 rad across.
  - **Recover:** 1.3 s.

  Most of the blow reuses round 1's streaks, about 3x bigger (up to 34 m
  long), pouring across and on into the sky. The trees thrash because the
  wind tool's own foliage lanes (`zs_blow_*`, read by every plant's shader
  through `zs_blow_at`, conifers included) fire every 0.32 s along the
  blast. Nothing else publishes them on the aqueduct isle. Leaves are torn
  off the turf, stones shake loose, and big soft puffs churn up out of the
  cloud tops 70 to 420 m beyond in a widening wake.
- **The treasure.** A gem on its tongue, with a four-pointed glint that
  flares every few seconds and a small light.
- **Let go.** After 45 to 60 s, at the end of a pant, it pushes off. It
  drops back and turns out on one heavy beat (3.2 s, blended from the cling
  pose), the isle springs back, and it flies a circuit before roaming on.
- **The pilot.** If he is on foot on the attacked isle, the blow uses round
  1's rules: knocked into a tumble in the cone's core (±0.34 rad, 70 m) with
  a clear line, and pushed along in the band. Touching the gem (3.2 m)
  takes it: `yielded` pops the HUD, and it roars and lets go.

### Captures (local, gitignored, docs/design/rim-dragon/)

- `r4_from_turf_blast.png`: from the turf's east side, mid-blast on
  hills_ne. It shows the streaks across the isle, the leaves flung off and
  the tail hanging.
- `r4_close_blast.png`: close side view mid-blast. The neck is reared over
  the turf, the jaw open, a wrist hooked on the rim.
- `r4_slam_chase.png`: chase camera at the end of the grab.
- `r4_top_grip.png`: from above, the wrists on the rim either side.

Capture example: `--dragon --dragon-attack --dragon-skip=17 --at=122,40,6
--look=330,50,-120 --capture=x.png` (mid-blast from the turf).

### Rough

- From the turf, at 270 m, the dragon is small, about a tenth of the screen
  wide. The blast streaks and the leaf cloud read; the trees thrashing do
  not read at that range. Using `look` (V) narrows the FOV to 40.
  grove_east (135 m) shows it bigger.
- Not checked in play whether the pilot can land on and walk a lone isle.
  The knock and treasure code is wired but untested in play.
- The cloud-sea wake is plain soft billboards, not the volumetric clouds
  themselves (cloud_wakes.gd is tied to the puffs and towers). It sits at
  "about 80 m under the mouth", a guess at the cloud tops.
- The neck's sweep axis and sign are rough. The blast's way follows the
  dragon's facing plus the sweep rather than the head's true aim, so they
  can disagree by a little.
- The grab is a curve, not physics, and the slam has no camera shake or
  sound. The let-go turn is a simple yaw lerp.
- The membranes fold like a cape. The thumb claws are not posed separately.
- Leaves are flat quads. Debris is big on purpose (0.5 to 1.3 m).
- While it clings, nothing else reads the isle's tilt: the airships, the
  traffic and the islet life still use the home position.

## Round 3: a wyvern after Smaug

The user's notes on round 2 (look c, watched from the isle): still a bit
animatronic, the mouth most of all; reads well from the rear but not the side
or front; "lipstick" (the red mouth band); the tail too short; a lizard body;
the flight good but slow in a weird way, it should adjust to the wind and go
up and down a little; think Smaug; no shadow over the isle; wider wings.

### Play

- `./run-rim-dragon.command`: as round 2. Look **c** (stone body, soft
  glowing membranes) is now the default.
- `./run-rim-dragon.command --dragon-pass`: starts on the low pass's way in,
  so it comes over the isle and its shadow crosses the turf about 12 s in.
- V cycles the dragon camera, as before.

New flags (scripts/sky_dragon.gd): `--dragon-pass`, `--dragon-size=<x>`
(0.85, the model's scale), `--dragon-pose=roar` (with `--dragon-hold`: roars
on a loop), `--dragon-orbit-up=<m>` and `--dragon-orbit-far=<m>` (the orbit
camera's height and distance, for side and head-on captures).

### The model (art/blender/rim_dragon/dragon_body_build.py)

All three dresses still build from the one script (`--style=a|b|c`, c the
default); it was cheap to keep them.

- **A wyvern.** The wings are the forelimbs: there are no forelegs. Each
  wrist has a big hooked thumb claw, the one it would walk on. Two heavy
  hind legs, folded back under the tail's root in flight.
- **Neck.** Five neck bones (`neck.0` at the root to `neck.4`) along a long,
  thick neck that rises from the chest in a shallow S and carries the head
  out level.
- **Body.** A massive, deep chest (6 m half-width before scale), with a
  separate mass of wing muscle over each shoulder, then a lean waist into
  the hips.
- **Tail.** Eight bones, about 43 m from the hips to the tip before scale
  (head to hips is about 42 m). It is thick at the root and tapers to a whip
  with a spade blade.
- **Wings.** About 122 m span and 20 m chord at the arm before scale (round
  2: 84 m and 16 m). The membrane runs back to the hips.
- **Head.** A long wedge: broad at the cheeks, the brow peaked out over sunk
  amber slit eyes, the top falling straight to a narrow snout with nostril
  bosses. Horns swept back, cheek spikes, a row of blades over each brow.
- **Mouth.** The lips are the hide. The palate (`dragon_mouth`) and tongue
  (`dragon_tongue`) are a deep maroon going near black; the teeth ivory. A
  cheek-skin web joins the upper lip to the jaw at the back of the mouth,
  weighted from the head to the jaw, so it stretches open. The jaw's front
  half is its own bone (`jaw.tip`) for the lower lip's follow-through.
- **Size in game.** The game scales it by 0.85: about 74 m nose to tail and
  104 m span. Triangles: a 3.1k, b 5.1k, c 4.9k.
- **Sheet.** `dragon_body_sheet.py -- --styles=abc` renders side, head on,
  three-quarter, head close-up and top for each dress (c is the default
  style). `--jaw=-0.55` opens the mouth. `--tiles` keeps each view as its own
  png.

### The flight (scripts/sky_dragon.gd)

- **Faster.** It cruises at about 28 to 40 m/s (round 2: 19 to 26). Beats
  come at 0.3 Hz, and bouts start under 28 m/s. It glides until it is slow
  again, usually 8 to 12 s rather than 15 to 20. The turn rate is higher. The
  circuits are tighter and shorter (3 points, not 4) and the climbs a little
  lower, so there is less flying far off.
- **Riding the air.**
  - A slow swell lifts and sinks it a few metres, a bounded offset rather
    than a drift. Three sines, strongest when gliding and with the isle's
    breeze.
  - The air rolls and pitches the body a little. The nose rides the swell.
  - Every 3.5 to 8 s a bump hits: an under-damped roll and pitch spring
    that jolts, sways and settles. The wingtips flex with it.
  - Gliding, each wing trims against the air. The low wing lifts against the
    roll, and the hands twist with the swell. The wings take a gull's bend at
    the wrist, which also reads better head on.
  - A slow weave in the heading means no straight is ruled.
  - It drifts down the isle's wind. The host passes `air`
    (`Atmosphere.breeze()`) and `air_angle` each frame.
- **Mouth, all on springs.**
  - It breathes: a slight part of the jaw, and the chest swells (bone scale).
  - Every 2.5 to 6.5 s it chews, one or two soft small bites.
  - Every 12 to 22 s it roars. First it tightens, with a small dip. Then the
    jaw eases open (an under-damped spring, so it overshoots and settles)
    while the head lifts and the neck draws back. It holds with a tremble,
    then eases shut.
  - The lower lip lags the jaw's speed and springs back.
- **Neck.** Generic over the five bones. It holds the S, takes a share of
  the turn's lead, and a slow sway and slither pass up it.
- **Tail.** The rope now runs in world space through the skeleton's real
  transform (so it scales), over eight segments, with a slow whip wave down
  it.

### The shadow

Cast shadows were already on in round 2; they are now two-sided, so the
wings cast too. The isle's sun is an orthogonal map out to 140 m, which
reaches the turf under a pass 42 m up; the captures show the shadow
plainly. Round 2's trouble was aim. The low pass went over `IsleSky.MIDDLE`,
which sits on the near island's north edge. Under a sun about 38 degrees up,
the shadow fell 55 m away, mostly off the turf, and only for a moment. Now
the pass's middle point is set up-sun of the near island's turf (the middle
of `Art.NEAR`), by the shadow's offset (capped at 80 m). It is flown right
through: low passes arrive within 40 m, not round 2's 95 m skip. So the
shadow sweeps across the turf.

### Captures (local, gitignored, docs/design/rim-dragon/)

- `r3_side.png`: side, held glide.
- `r3_head_on.png`: head on, held glide.
- `r3_rear_three_quarter.png`: rear three-quarter in flight, banked.
- `r3_shadow_from_isle.png`: the shadow sweeping the turf with the dragon
  overhead, from the isle (`r3_shadow_after.png`: a second later, gone).
- `r3_shadow_overhead.png`: from above, the shadow over the hill.
- `r3_from_below.png`: from below on the low pass, against the sun.
- `r3_roar_open.png`, `r3_roar_closing.png`: a held roar.
- `r3_mouth_open_sheet.png`: the mouth open in Blender: dark inside, hide
  lips, cheek skin.
- `dragon_sheet.png`: the three dresses, five views each.

### Rough

- From the side, gliding, the wings are still edge-on and read as thin
  lines, though the neck, head and tail now carry the silhouette. Head on,
  the chest reads as a dark block and the head is foreshortened.
- The cheek web is subtle; the roar reads mostly through the head lift and
  the dark gape. No tongue motion.
- The membrane glow is toned down a little (0.42 from 0.7) but still lilac
  in bright daylight.
- It is big now (104 m span). Watch it against the isles and airships; there
  is still no collision. `--dragon-size` scales it.
- The swell, bumps and gain are tuned by eye, from captures only, not
  played. The wind tie is through the breeze strength and the drift; gust
  fronts are not sampled.
- The low pass picks a random approach heading, so on some passes the
  shadow crosses behind the ruins. The aim uses the first shadowed sun at
  the time the pass is planned. If the look preset's hour changes a lot,
  the aim goes stale.
- The capture rig: `studies/kit_isle.gd` gains a `_capture_tick` hook so a
  fixed-eye capture (`--at`) still flies the dragon.
- Still from round 2: no sound, the dragon camera doesn't stop pilot input,
  and the waypoints can make wide loops.

## Round 2: the sky dragon (superseded by round 3)

### Play

- `./run-rim-dragon.command`: the aqueduct isle with `--dragon`. The dragon
  rises out of the cloud sea after 3 s, makes a low pass over the isle, then
  roams.
- `./run-rim-dragon.command --dragon-look=a` (or `b`, `c`): the dress.
  `b` was the default (c is now).
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
