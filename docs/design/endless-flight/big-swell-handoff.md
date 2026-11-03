# Big swell: handoff (ITER(big-swell), 2026-11-02)

Big waves round the edge of the world, on branch `iter/big-swell`
(worktree `../zenscape-big-swell`). Not merged to main. Spec:
`spec-big-swell.md`; cost: `big-swell-cost.md`; the trail:
`git log --grep='^ITER(big-swell)'`.

## Play it

    python3 tools/play.py -- --no-title --pilot-file=/tmp/big-swell.json --at=8800,420 --heading=0 --alt=8

Low on the east side, along the crests. Other starts: `--at=8300,420
--heading=90 --alt=26` (out at the faces), `--at=7200,2600 --heading=0
--alt=280` (the join from the air), `--day-at=dawn`. `--surge=0` takes the
swell off, `--spray=0` the spray, `--sea-set=surge_size:1.4` sizes it.

## What's built

- **The swell** (`shaders/endless_surge.gdshaderinc`, `shaders/endless_sea.gdshader`;
  the plane's copy `scripts/endless/endless_sea.gd` `surge_at`). Three long
  waves (180, 130, 90 m) whose fronts follow the edge line, so they roll in on
  every side. They lean landward (a steep face, a long back) and come in sets,
  with peaks along a crest. Crests reach about 20 m at the very top; most are
  far smaller. The belt starts at the edge line, pushed out by up to 700 m in
  places, and is whole 700 to 1400 m past it. The land stops short of the line.
- **The light:** faces lit by the long waves' own slope, dark troughs that
  mirror the wave beside them, crest glow scaled to a wave's size. Past about
  1 km the big waves drop out of the sky's mirror except in patches, which is
  what removed the ruled lines from the air (`surge_mirror`).
- **Foam:** only tall crests break, in sections that hold and die. A torn cap,
  fingers down the face, soft lace and streaks on the back.
- **Spray** (`shaders/surge_spray.gdshader`, `scripts/endless/surge_spray.gd`):
  5,600 GPU cards in three rings round the eye out to 2.3 km. They are held on
  the breaking lip each frame and torn back off it. Hidden more than 2.3 km
  from the belt.
- **Flying** (`scripts/endless/flight_contact.gd`, `scripts/endless/line_moves.gd`,
  `studies/endless_flight.gd`): a wave rising into a level or climbing plane
  scrapes and throws water, but keeps the line. A dive still crashes. A new
  held move, the crest run, pays for running fast and low along a big crest. A
  crash puts the plane back at least 31 m up, over the tallest crests.
- **All seas:** the sky's mirror is capped by its brightest channel, so a low
  sun's sheen stays amber (it read lime at dawn, swell or no swell).

## Proof

- Smoke check passes inland and in the belt on the final code.
- Driven flights through the real input path at cruise and Boost (56 to 61 m/s):
  skims and hands-off flight never crashed, and dives crashed 3 of 3.
- Stills and frame-by-frame films (low, at 140 to 150 m, out to 2.5 km): no
  pops, no shimmer, no ring where the heave fades. Rendered at dawn, noon,
  dusk and night. All in `captures/swell/`, which isn't committed.
- Cost, from driven flights on this Mac: about 1.8 ms a frame low in the belt,
  1.1 ms of it spray. Inland and at the coast the cost is within noise.
  `surge_at` stays in GDScript; its reads hide under the GPU wait.

## Open, for the user to judge in play

- From 200 to 300 m the far belt may read too calm now that the ruled lines
  are gone (`zs_surge_mirror`'s patch thresholds).
- Whether keeping the line through a rising-wave scrape is too kind. A very low
  Boost skim banked 4,330 points in 25 s, against 901 before.
- The crest run's thresholds. Nobody has seen it trigger by hand.
- The dusk face toward the sun is a strong teal.
- Crests barely darken under a cloud's shadow. Fixing that changes the whole sea.
- The far corner reads as faint arcs from 900 m. The north and west sides
  weren't shot well. The join isn't filmed from the shore.
- No water landing exists anywhere in the game: braking rides the swell at
  12 m/s.
- Frame cost on the PC: if the PC waits on the CPU, the 0.47 ms of height reads
  would show there.

## Seen, outside the swell, not chased

- Thin white needles in many sea stills, also with foam off. The burrower's
  wake is a suspect, unproved.
- Dark specks and a dark band under the shore at noon, from the sea's
  screen-space reflection. They show with `--surge=0` too.
- Real low clouds sit 22 to 115 m over the sea, and one cloud's colour popped
  between stills at 150 m.
- `drive.gd`'s `film()` draws in a SubViewport where the cloud sheet renders
  wrong. The loop's films used the main camera instead.

## Not done

The barrel, a curl you fly through, was out of scope. No committed tests (a
prototype); no test touches the changed files.
