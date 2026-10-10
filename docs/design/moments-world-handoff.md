# Moments set pieces in the sky world (handoff)

Branch: `sky/moments-world`, from `study/flight-moments` (327c93e7). Not
merged, not pushed. Greybox only, behind `--moments`: the default game is
unchanged.

The user flew the moments study and asked: "Can we litter these in the
world now?" This round puts the five moments stations
(docs/design/flight-study-moments.md) into the real sky world as set pieces
you come across while flying about: a dozen or so, laid by the world's own
layout pass, in the open sky between islands.

## Launch

    ./run-moments-world.command                       # the real game, --moments --no-title --skydive: in the plane over home
    ./run-moments-world.command --moments-at=3        # start on set piece 3's way in
    ./run-moments-world.command --challenge-time=12   # every challenge timed (12 s from the hoop)
    ./run-moments-world.command --challenge-mode=chain   # challenge collectibles one at a time
    godot --path . -- --moments --no-title --skydive  # the same, by hand (main scene)

No earlier launcher started in the sky with the plane. `--skydive` is the
game's own flag for that: it boots into the plane 110 m over home. The
launcher uses it.

Headless:

    godot --headless --path . -s tools/moments_world_list.gd [-- --sky-seed=N]   # where they stand for a seed
    python3 tools/run_tests.py --tests 'test_sky_moments.gd' --tests 'test_moments_world.gd'

Stills (opens a window, only when wanted):

    Godot --windowed --path . --resolution 1280x720 -s res://tools/capture_moments_world.gd -- --no-title --moments --out=captures/moments-world/try1 [--set-piece=N]

## Keys

All the plane's usual keys, plus:

| Key / arg | Does |
|---|---|
| N (in the plane) | Hop to the next set piece: the plane is put 200 m out on its way in, at its line's height, flying its line. The log lists every set piece with its distance, free collectibles taken and completions. A HUD pop names it: "Set piece 4/12 · sea cave · 1.9 km". |
| Shift+N | Hop to the one before. |
| `--moments-at=N` | Start on set piece N's way in. |
| `--challenge-time=<s>`, `--challenge-mode=chain` | The study's variants, for every set piece. |

The plane's hint gains "N for the next set piece" when `--moments` is on.
There is no minimap or compass in the game to hook a marker into, so none
was added. The beacons are the markers.

## Where the set pieces go, and why

They are laid in the world's layout pass (scripts/sky_world.gd `_moments`),
after the ranges, ridges, cumulus and the sea's summits, from the world
seed, and cached with the layout. So the same seed always lays the same set
pieces, and another seed lays others. The pass:

- **How many**: 12 to 14 (`MOMENTS`). Seeds 7, 1, 5, 8, 13, 99, 2024, 12345,
  31337 and 424242 lay 12, 13, 12, 14, 14, 13, 14, 12, 12 and 12.
- **Which**: each slot takes the layout stood fewest times so far, the
  widest first on a tie (it has the least room). So every one of the five
  stands two or three times.
- **Turned and mirrored**: one of 8 turns from a chance start, and mirrored
  across its line by chance. A test checks that the line's room to the
  stone is exactly the study's, turned and mirrored.
- **Spread**: each is laid at the candidate (a 100 m grid) farthest from
  those already laid, by a little chance, and at least 650 m apart
  (`MOMENT_APART`). The nearest is 600-700 m from home and the rest spread
  out to the edge of the bounds, so you meet one every kilometre or so in
  any direction.
- **Height**: the entry stands 8-30 m (home y). The stone's foot (the
  study's floor, 43 m under the entry, with its plinth) stays over the
  glide's floor (-55) and well over the cloud sea's top (-105). Its top
  stays under the ceiling (95).
- **Clear of everything** (`_moment_room`, read on a 25 m grid over the
  footprint rectangle, each point keeping its share and its cell's half
  diagonal):
  - every island that could stand, 100 m. Islands are read as every cell's
    `SkyCells.pick` blocked only past the bounds, a superset of the
    islands the game stands. The plan's own island count reads the band a
    little differently, and one island slipped through when I used that.
  - the ridges (RIDGE_GAP + 25 m)
  - the band's rock (BAND_CLEAR + 25 m) and 80 m inside its haze
  - the home range's keep
  - the passes, notches and kept gorge mouths, 250 m
  - the cumulus's keep + 25 m, the summits' crests (SUMMIT_KEEP + 25 m),
    the jet streams (80 m) and the plate (350 m)
- **Later kinds keep off them.** `SkyPeaks.blocks` reads the set pieces'
  footprints (`SkyWorld.moments_block`, 40 m past + the asker's margin), as
  it does the summits. So islets, clusters, pierced isles, clouds' spots,
  the airship and the token trails all stay off them. The islands are
  unchanged: the test checks they stand exactly where they do without
  `--moments`. The drifting clouds part round a standing set piece
  (`keep_spots`).

The footprint is the plate-plane rectangle round the stone, the natural
line, the collectibles, the hoop and the leads (scripts/sky_moments_plan.gd
`footprint`).

Seed 7 (the legacy seed, which a new world gets unless its save has
another) lays 12:

     0  bending nave     entry (  -950,   9,    239)  turn  15.4 deg              922 m from home
     1  pierced isle     entry (  -994,  16,  -1797)  turn 297.2 deg  mirrored   2059 m from home
     2  over the crest   entry (   222,  22,   1913)  turn  60.3 deg  mirrored   1910 m from home
     3  sea cave         entry (  1391,  20,  -1463)  turn 186.5 deg  mirrored   1980 m from home
     4  Sundered hall    entry ( -2276,  21,   -398)  turn 150.8 deg             2335 m from home
     5  bending nave     entry (   143,  21,   -946)  turn  70.0 deg  mirrored    906 m from home
     6  pierced isle     entry (  -197,  18,    806)  turn 260.4 deg  mirrored    825 m from home
     7  over the crest   entry ( -1125,  12,   1795)  turn 257.7 deg             2110 m from home
     8  sea cave         entry (  -514,  18,   -438)  turn 345.7 deg  mirrored    707 m from home
     9  Sundered hall    entry (  2124,  16,    397)  turn 161.8 deg             2138 m from home
    10  pierced isle     entry (  2004,  30,   -905)  turn 271.6 deg             2193 m from home
    11  over the crest   entry ( -1724,  19,  -1291)  turn 290.2 deg             2140 m from home

## What a set piece is

Each is the study's station unchanged (scripts/sky_moments_plan.gd): its
stone, its natural line (not drawn), its 3 free collectibles (gold balls)
and its 3 challenge collectibles (orange-red diamonds), each with the
study's reach (REACH × ease) and drawn at the study's size. Additions:

- **The hoop** (the starter) is moved from mid-line to the line's own way
  in: 35 m before the entry, 3 m in radius, facing along the line.
- **The beacon**: a tall magenta column (70 m) over the hoop, unshaded, so
  it reads from far off. In the stills it shows as a thin pink line at
  900 m.
- **The leads**: three small magenta diamonds out along the way in, at 65,
  100 and 135 m. From any side they show which way the line goes in.
- **The plinth**: under the two stations whose stone stood on the study's
  floor (bending nave and sea cave), a 3 m slab where that floor was. It
  closes them underneath as the study's floor did and makes them read as
  one floating thing. The hall, crest and pierced isle have no floor parts
  and float as they are.
- **The area**: the box round all of it, grown 30 m every way. It bounds the
  challenge.

The look is plain grid-grey, using the study's own shader and tints. There
is no kit and no art pass.

## Discovery and starting

- From afar you see a beacon. Nearer (within 1.4 km), the hoop and leads
  draw. Within 1.3 km the stone and collectibles stream in.
- **Starting.** Fly through the hoop toward the entry. It only works that
  way: going through it backwards does nothing. Whoever arrives from
  wherever has to come round onto the line to take it, and taking it puts
  them on the line at cruise, 2.5 s from the entry. This is the "flying in
  naturally lines you up" rule, as a hoop you can only take one way.
- **On.** The challenge collectibles come out (all at once, or one at a
  time with `chain`). The hoop goes down and the beacon dims. The HUD pops
  "Challenge · sea cave" and shows "challenge 0/3" under it (with the time
  left if timed), with the tokens' blip.
- **Ending.** None of these is ever a penalty. What's left goes away and
  nothing taken is lost.
  - All three taken: "Challenge complete · 3/3", with the tokens'
    sparkling run.
  - Leaving the area: "Challenge ended · left the area · 1/3".
  - The plane gone for over a second (landed, ejected): ended the same way.
  - With `--challenge-time`, the time running out: "time up".
- **Retry.** The hoop stands again once the plane is 20 m off it. Fly out,
  come round, take it again. It re-arms after a complete run too. Its core
  turns gold once the set piece has been completed, as a "done before"
  mark.
- **Free collectibles** are always there until taken. Each pops
  "sea cave · free 2/3" with the tokens' blip, climbing the steps.

## Save behaviour

`SkyIslands.save_state().moments` = `{seed, free: ["<set piece key>:<moment
index>", ...], record: {<key>: {tries, best, done}}}`. It is saved with the
world, as the tokens are, and the world is marked edited on a free pickup
or a completion.

- A key is the station id and its entry's spot (`moments_cave@-514,-438`),
  so it only changes if the layout moves it.
- A save for another seed is ignored.
- Without `--moments` the saved state is carried through untouched, so
  playing without the flag never drops it.

## Solids and the plane

Each set piece is one `StaticBody3D` on the ruins' layer
(`RuinBump.LAYER`, 1<<10) with one `BoxShape3D` or `CylinderShape3D` per
study solid, at the study's sizes, turned and mirrored as proper rotations.
The game's plane already runs `RuinBump.bump` against that layer every
step, so it bumps off the stone exactly as in the study, and nothing new
runs for it. A test puts the plane in the stone and sees it bumped out.

## Performance

Headless numbers (Apple Silicon, the dummy renderer). The `test_sky_moments`
log prints the full per-layout table.

| | |
|---|---|
| Layout pass (`_moments`, on the layout's worker, then cached on disk) | 90-160 ms per seed |
| Per set piece, made on a worker (mesh + body, off the tree) | 1.6 ms (pierced) to 5.8 ms (cave); 8 ms seen in the busy game |
| Stood on the main thread (one `add_child`, one SkyCommits commit) | 0.08-0.3 ms |
| Per frame, `SkyMoments.advance` + the plane's touch (12 set pieces) | mean ~0.01-0.015 ms, worst 0.09 ms (the stand frame) |
| Solids per set piece (shapes in one body) / verts drawn | hall 178 / 12.8k, bend 319 / 20.1k (with plinth), cave 213 / 20.8k (with plinth), pierced 60 / 6.5k, crest 241 / 16.0k |
| Drawn | one mesh a set piece (2-3 surfaces: boxes, cylinders, plinth), plus its 6 collectibles |
| Standing at once | one at a time made, all within 1.3 km kept (typically 1-3) |
| Far off | each set piece is just its beacon column: one draw. The hoop, core and leads draw within 1.4 km. |

The rendered capture held one view with the set pieces shown and then
hidden. Draw calls moved by about a dozen. The process times it printed
were dominated by the rest of the sky streaming and are too noisy to
quote. **GPU frame time is unverified.**

## Surprises

- **Low-priority worker tasks starved in the game.** Made as a
  low-priority task (as the pierced isles' are), a set piece's build
  never ran in the headless game. It stood queued for over 20 s behind the
  rest of the sky's work, while the same task finished in 18 ms on its own.
  It is now high priority (it is a few ms). The pierced isles and other
  low-priority sky work may wait the same way. I didn't look further.
- **No random pierced isles stand in the ring world.** `SkyPierced.spot_of`
  found none in the bounds for seeds 7, 99 or 12345 (the islands' 280 m
  keep leaves no room), so the "clear of pierced isles" check passes
  trivially. `--pierced` still stands its near one, and it keeps off the
  set pieces through `SkyPeaks.blocks`.
- **Set pieces are long.** With the hoop and leads, a footprint is 330-440
  m along its line. Between islands 450 m apart, the room went to the long
  axis. The first attempt (leads out to 170 m, 110 m island keep, 700 m
  apart) only fit 9 on seed 7. It is now 135 m, 100 m and 650 m apart, and
  the widest layout (bend) is laid first on ties.
- **The sea cave's inside is very dark** from the chase camera. Its walls
  shade the line, as in the study's stone.

## Glyph-token lines

Left alone. The token trails between islands keep off the set pieces
(their open-air check reads `SkyPeaks.blocks`). Islet and cluster token
lines go with their hosts, which also keep off. No clash showed in the
stills.

## Unverified

- **Nobody has flown it in the world.** Whether meeting them while
  wandering feels like Odyssey, and whether the one-way hoop and leads line
  people up naturally, are untested.
- **Readability.** In the stills from noon: the beacon reads at 900 m as a
  thin pink line, and the hoop reads at 320 m. The leads are too small to
  see at 320 m. Not checked at golden hour or night, or from the cumulus
  sea below.
- **GPU frame time** (see above).
- **Re-arm and the area by hand.** They were exercised only in tests and
  one scripted chase flight (straight in through the hoop: the challenge
  started and the HUD read "challenge 0/3").
- **Claims.** The set pieces ride with `cells.origin`, as the tokens do, so
  a claim's shift should carry them. Not tested.
- **Tests run** (headless, through `tools/run_tests.py`; not the full suite):
  - the import check: clean.
  - `test_flight_*.gd` (7): pass.
  - `test_sky_moments.gd` (new): pass.
  - `test_sky_world` (slow), `test_sky_summits`, `test_sky_cache`,
    `test_sky_layout`, `test_collectibles_world`, `test_sky_dive`: pass.
    `test_plane_flight` and `test_skydive` pass with the runner's known
    exit leaks.
  - `test_moments_world.gd` (new, slow): every check passes (0 failures),
    but the runner marks it failed for 4 engine errors at boot,
    `Condition "!std::isfinite(p_size.x) ..."` in `cozy_worlds.gd
    _layout_shell` (headless 64×64 viewport). `test_collectibles_pickup.gd`
    fails the same way, and it does so on the base commit 327c93e7 too. It
    was not caused here, and it was not added to known_failures.

## Suggested next round

1. **Fly it**: `./run-moments-world.command`, then wander. Do you come
   across them often enough? Too often? Does the beacon read? Does the
   one-way hoop line you up, or is it fiddly? Use N to hop between them
   for a quick tour.
2. **Discovery tuning** from that: column height and width, a soft glow or
   a sound near the hoop, lead spacing, and a "done" look for completed
   set pieces at distance (the core is gold, but it's only seen near).
3. **Fit to the world**: the nearest ones stand a little over 100 m off a
   ridge's box (the sea cave by home at seed 7 reads against the home
   range's wall in the stills). Decide whether they should prefer open sky,
   or be threaded with the world's own rock.
4. **Rewards**: the free collectibles and completions are saved but count
   for nothing yet. Tie them into the glyph tokens' tally or a sky journal.
5. **Then the art pass**: stone kits per layout (the Sundered hall kit
   already exists for the hall).

## Files

- New:
  - `scripts/sky_moments_plan.gd`: stations in their own metres, the hoop,
    leads, plinth, area, footprint, and the turn and mirror frame.
  - `scripts/sky_moments.gd`: the node. It streams the stone, stands the
    beacons, takes pickups, runs the challenge, saves, and provides the
    hops and list.
  - `scripts/moments_hud.gd`: the pop and the challenge line, with the
    tokens' sounds.
  - `run-moments-world.command`.
  - `tools/moments_world_list.gd`.
  - `tools/capture_moments_world.gd`.
  - `tests/test_sky_moments.gd`: layout, determinism, clearance, the study's
    geometry, body, pickups, save, challenge.
  - `tests/test_moments_world.gd` (slow): in the real scene, N hop, stream
    in, hoop, free pickup into the saved sky, stream out.
- `scripts/sky_world.gd`:
  - `moments` flag (`--moments`), part of the layout key only when on
  - `_moments` in `_compute`
  - `moment_spots`, `moments_block`
- `scripts/sky_peaks.gd`: `blocks` reads the set pieces.
- `scripts/sky_islands.gd`: wiring (setup, build, clear, advance, clouds,
  save/load, show_air).
- `scripts/wanderer_eye.gd`: the plane's touch, N/Shift+N, `--moments-at`,
  the hint.
