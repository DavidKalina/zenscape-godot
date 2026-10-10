# Rune serpent (handoff)

Branch `look/rune-serpent`, from `main` 94a4d1c0. Not merged and not pushed.

This round adds a giant rune serpent to the sky round the aqueduct isle. It is
the grass snake (`scripts/life_snakes.gd`) grown to 90 m and carved from the
ruins' eroded basalt. It flies a long way through the sky isles: through the
gap between the isle and the grove to its east, round the isle, down into the
cloud sea and out again, and through the pierced isle's arch. It watches you,
paces your plane, then peels away. It is on by default.

## Where

- `scripts/rune_serpent.gd` holds all of it: one `RuneSerpent` node with a
  `setup(study)` call. It runs its own `_process` (its life, pose and lights)
  and `_physics_process` (its collision). It reads the study's `camera`,
  `flying`, `plane`, `figure` and `_celestial`. Self-contained, like
  `life_snakes.gd`.
- `shaders/rune_serpent.gdshader` draws the stone and its runes, eyes, mouth
  and tongue. `shaders/rune_serpent_glow.gdshader` draws the eyes' haze, and
  `shaders/rune_serpent_ribbon.gdshader` draws the whiskers and tail fin.
- `studies/aqueduct_isle_sky.gd` has one small block, "The rune serpent": the
  preload, the `serpent` var and `_build_serpent()`. There is also an entry in
  the header, `"serpent"` in `on`, and the `--no-serpent` parse. `flush()`
  needs nothing for it, because it stands at once.
- `studies/aqueduct_isle.gd` takes two capture flags, `--capture-wait` and
  `--capture-seq` (see below).
- `tests/test_rune_serpent.gd` is the headless feature test.

## What it looks like

- **Body.** About 90 m long and 4 m through at its widest, tapering to a fine
  tail. It is longer than any near isle is wide, against the 110 m isle.
  - It is the grass snake's form at that size: a faceted tube of octagonal
    rings with a narrow crest on the back and a broad flat belly. Each ring's
    corners are hewn a few percent out of true, so the facets read as cut stone.
  - It uses the ruin kit's eroded basalt (`5a5d63`/`52575f`) with a paler
    belly. Faces toward the sky are lighter and each segment is a shade apart.
  - It is lit as the ruin stone is, by the sky's hemisphere, with a plain
    Lambert terminator. Its fill and rim are the sky folk's (1.6 and 0.4), so
    its shaded side reads as slate, not black.
- **Runes.** These are warm gold, the stone plane's and lodestone's colour.
  - Where the grass snake has dark bars, there are bands of carved runes every
    third ring round its flanks. The glyphs are staves with branches, double
    staves and lozenges. A slow pulse runs down the bands from head to tail.
  - Behind the head is a glowing rune collar over a dark crescent.
  - A soft seam of light runs down the spine. A rune sits in about every other
    cell and runs back toward the tail as it flies (`RUNE_RUN`, as the stone
    plane's deck runes do).
  - A sigil sits on the brow.
- **Head.** The grass snake's head language, given more facets:
  - wide jowls, a flat top and brows;
  - a blunt faceted nose;
  - a hinged jaw that cracks open when it first notices you, showing a warm
    glow inside;
  - glowing amber eyes, each an almond with a slit pupil, with a soft haze;
  - a forked tongue of light that flicks every few seconds, and more often
    while it watches you.
- **Trailing light.** Two soft whiskers stream from the corners of its mouth,
  and a fin of light streams from its tail's tip. Each ribbon runs through
  where its root has been, so it draws the slither's line in the air. They
  flutter, and the whiskers sag.
- **At night** the runes, eyes, haze and ribbons carry it against the dark. The
  runes' emission is a little lower at night (`NIGHT_GLOW` against
  `DAY_GLOW`), because at full strength they blew out to white.

## How it moves

- **The way.** `ROUTE` is a closed cubic B-spline through 40 control points,
  2.78 km round, about four minutes a lap at cruise. A B-spline is smooth
  (C2), never overshoots its control points and stays inside their hull, which
  makes clearance easy to reason about. Nine control points in a line run it
  straight through the pierced isle's arch on the arch's own axis. Each
  control point carries:
  - a weave share (held in near rock and in the arch, widened in the sea);
  - a pace share (eased through the gaps);
  - a veer share (0 near rock, so pacing never pushes it toward an isle).
- **The slither.** The grass snake's principle. The head's path is the route
  plus a lateral weave of `WEAVE` 0.42 rad either side, one wave every `WAVE`
  46 m. That is about ±3.3 m, about two waves along the body: long and slow.
  - A slow heave is added: 0.1 rad every 84 m.
  - Both wavelengths are rounded so whole waves fit the lap, so the weave meets
    itself where the loop closes.
  - The path is laid as points 0.5 m apart. Every ring behind the neck reads
    its place from that path (a Catmull-Rom through the points), so the body
    never slides sideways.
  - The waves stand still in the sky and the body flows through them.
  - The rings roll into the route's turns (`BANK`).
- **The head glides.** The head keeps only `HEAD_KEEP` (30%) of the weave.
  The rest passes under it, taken up by the neck's S: a Hermite from the body's
  line, 17 m back, to the head, corrected to the neck's own length, as the
  grass snake's is.
- **Springs.** Every head and neck quantity is a goal on a critically damped
  spring: pace, weave share, veer, look turn and tilt, the head's lean and lift,
  jaw and roll. These are all slow, for its size. Breath, a slow drift of the
  head and tongue flicks never stop.
- **Pace.**
  - It cruises at 12 m/s, surging ±14% over 38 s, faster in dives and slower on
    climbs, always within 8.5 to 17 m/s.
  - The plane cruises at 14 m/s, so you can catch it and fly alongside.

## Life

- **Noticing.** Within `NOTICE` (120 m) of its head, the plane or the pilot on
  foot is noticed.
  - It turns its head to look, up to 1.25 rad of turn and 0.55 of tilt, and
    the neck's S takes the turn.
  - The head leans 2.6 m toward you and lifts 1.8 m.
  - Its jaw cracks open a moment and its tongue flicks.
  - If you go round behind it, past 2.4 rad, it looks ahead again instead of
    whipping its head from side to side.
  - It watches for up to 14 s, then not again for 16 s. It notices the pilot
    on the isle about twice a lap.
- **Pacing.** If the plane flies its way within 80 m, it paces you for 6 to
  9 s: it matches your speed and veers up to 9 m toward you where the route
  allows, keeping 22 m off. Then it peels away: 1.3× pace, veering off, for
  6 s. It is never hostile.
- **Solid.**
  - Capsules along its body (one over every four rings, plus the head) are on
    layer 1, moved each physics frame, like the airships' bodies.
  - The plane bumps off it, using the study's own bump.
  - The chase camera stays out of it, because the capsules answer point
    queries.

## Flags

It is on by default. The study's flags go after `--`:

- `--no-serpent` leaves it out.
- `--serpent-at=<mark or metres>` starts it there. The marks are `north`
  (default), `gap`, `curl`, `west`, `east`, `dive`, `sea`, `breach`, `arch` and
  `home`.
- `--serpent-cam[=mode]` puts a camera on it while you're on foot. It follows
  smoothly and overrides the walker's camera, but the pilot still takes input.
  The modes are:
  - `side` (the default) and `left`;
  - `pace`, where a plane pacing it would be;
  - `below`, against the sky;
  - `head`, ahead, looking back at its face;
  - `far`, a wide shot for the dive and breach;
  - `hill`, from over the stone circle on the isle's hill.
- `--meet-serpent` puts you in the plane beside its middle, on its way and at
  its pace, with its head ahead.
- `--serpent-speed=<x>` scales its pace, for judging the motion.
- `--capture-wait=<s>` makes a capture wait that long first (4 s by default;
  the life and sky go on meanwhile). `--capture-seq=<count>,<s>` saves that
  many shots that far apart (`out_0.png`…).

## Watching it

```
./run-aqueduct-isle.command --meet-serpent                 # fly alongside it
./run-aqueduct-isle.command --serpent-cam --serpent-at=gap # follow it from the side
./run-aqueduct-isle.command --serpent-cam=far --serpent-at=dive   # the dive and breach
./run-aqueduct-isle.command --serpent-cam=head --look=rosewater_dusk --serpent-at=home
./run-aqueduct-isle.command --serpent-cam=left --look=nordic_night --serpent-at=west
godot --headless --path . --script tests/test_rune_serpent.gd
```

On foot from the start, it comes through the east gap within about 20 s and
watches you as it passes.

## Tuning constants that matter most (`scripts/rune_serpent.gd`)

| Constant | Now | What it does |
|---|---|---|
| `LENGTH`, `RADIUS` | 90, 2 | Its size. The route's clearance is checked against the radius. |
| `WEAVE`, `WAVE` | 0.42 rad, 46 m | The slither: how wide and how long the waves are. |
| `HEAD_KEEP` | 0.3 | How steady the head is (the rest of the weave goes to the neck). |
| `CRUISE`, `SURGE`, `DIVE_GAIN`, `PACE_RANGE` | 12 m/s, ±14%, 0.35, 8.5–17 | Its pace. |
| `BANK`, `BANK_MAX` | 0.2, 0.5 rad | How far it rolls into turns. |
| `SPRING_HZ` | 0.07–0.6 Hz | How slow and majestic each quantity is. |
| `NOTICE`, `PACE_*`, `VEER`, `PEEL*` | 120 m … | How it watches and paces you. |
| `ROUTE` | 40 points | Its way. Each point also carries a weave, pace and veer share. |
| `DAY_GLOW`, `NIGHT_GLOW`, `EYE_*`, `HAZE_*` | 1.5, 1.25, … | Its light. |
| `BAND_EVERY`, `SPINE_CELL`, shader `spine_share` | 3, 1.5 m, 0.5 | How dense the runes are. |
| `RUNE_RUN` | 0.45 | The spine runes' run, in m per m flown. |
| `WHISKER`, `FIN`, `RIBBON_STRENGTH` | 15 m, 12 m, 0.85 | The trailing light. |
| `FILL`, `RIM` | 1.6, 0.4 | How light its shaded side reads. |

## Tests

`tests/test_rune_serpent.gd` runs headless in about 42 s. It checks that:

- the serpent stands by default, giant, with its body laid out behind its head;
- the route's tube is clear of every isle's ground and rock. The tube is its
  girth plus the most weave, veer and heave it can ever have, so it holds
  whatever the serpent does. The isles are checked through physics and the
  pierced isle's rock through its field, probed round the tube's rim. Least
  margin on the pierced rock: 3.0.
- its way stays clear of the three airships' loops. Least: 15.3 m past its
  reach, against a ship's 14.9.
- it flies its whole way round (56 of 56 stretches). Measured on that lap:
  - every ring behind the neck lies where the head was when it had come that
    far (0.002 m at most);
  - the body slides along its own line (at most 1.5% of a ring's speed across
    it);
  - nothing pops: the worst frame acceleration of any ring or the snout is
    22.4 m/s², against a limit of 40, where a 1 cm one-frame pop is 36;
  - the body never touches rock (checked every 12 frames);
- a ray finds its body on the bump's layer, and the plane put inside it is
  bumped out;
- a plane flying alongside is noticed, watched with the head turned toward it,
  paced at its own speed (13.0 against 13), then left. It never comes closer
  than 44 m.
- `--no-serpent` leaves it out (through `LaunchArgs.set_override`).

`tests/test_aqueduct_isle_sky.gd` still passes. Both report the one known
leaked shader RID at exit (see `aqueduct-isle-sky.md`).

## Perf

Measured rendered on this Mac (an M5 Pro), from one view held still, toggling
its visibility on the same frames:

- **GPU cost:** 4 draw calls and about 1.9 k primitives (338 against 334 draw
  calls, 254.1 k against 252.2 k primitives). That covers the body (stone and
  runes) and its shadow, the eyes' haze and the ribbons.
- **CPU cost:** its advance (path, springs, pose, ribbons) takes about 0.2 ms a
  frame (worst 0.33 ms rendered). Headless over a whole lap, the worst single
  frame was 0.26 to 0.99 ms, run to run (an occasional hitch). The physics
  frame's capsules (13) are negligible.
- **Frame time:** a captured frame is 16.67 ms with and without it. That is the
  display's 60 Hz cap (vsync stays on despite the capture's request), so it
  shows nothing either way.

## Skipped and why

- **Cloud tearing on the dive and breach.** The game's cloud wakes
  (`scripts/cloud_wakes.gd`) are owned by SkyIslands, which this study doesn't
  run. The dive reads well without them: it rises out of the cumulus sea with
  its tail still under the tops.
- **Sound.** The game's air sound (`scripts/glide_air.gd`) has the plane's
  wind and propeller. A second instance for a passing whoosh would add its
  streak meshes and a second wind under the plane's own. A stone hum wants its
  own sound.
- **Collision against the CPU planes and airships.** Kinematic bodies don't
  meet. The airships are kept off its way by the route (tested). The CPU
  planes climb over it when it is under them, because their ground ray finds
  its capsules, but they can fly into its side.

## Known issues

- **The plane can't follow the dive.** The study's cloud cushion lifts the
  plane from y ≈ −20, and the serpent's dive bottoms out at about −140, under
  the cumulus tops. You watch the dive and breach from above, which is the
  best view anyway.
- **One near pass with an airship.** Airship 0 comes within about 15 m of the
  serpent's farthest reach on the south-west curl. They never touch by the
  test's bound, but it is close if they meet there.
- **The tail's last rings drift a little off the path** (by design, a living
  tip). The on-path check stops at 85% of the length.
- **Merging `--capture-wait`.** At least two other branches on the aqueduct
  isle add a `--capture-wait` with the same name and the same 4 s default.
  `_take_capture` will conflict textually; keep one copy. `--capture-seq` is
  only here.
- **`--serpent-cam` and the pilot.** The camera follows the serpent, but the
  pilot still walks on input, unseen.
- **Its belly is near black from below.** Against the sky it reads as a black
  silhouette with its runes alight, which is striking, but its belly gets
  little of the ground hemisphere's fill. Raise `UNDER`, or give the belly
  faces more fill, if it should read as stone from there.
- **The headless load check** (`--quit-after 300`) reports a few leaked
  shader RIDs at exit. They're the same engine leak with `--no-serpent` (4
  with it, 7 without, varying run to run).

## Next ideas

- **Slipstream.** Fly tucked in behind its tail fin for a speed boost. Pacing
  it could brighten its runes, or open a token line along its way.
- **Cloud tearing.** If the study gets cloud wakes, it could tear the cloud
  tops on the dive and burst tufts on the breach.
- **More routes.** Add a second loop sharing a run of four control points
  with the first. On a B-spline the shared stretch is identical, so it can
  switch at the junction without a seam.
- **Light and sound.** Rune light cast onto the clouds at night (one
  OmniLight following its middle). A low stone hum as it passes.
