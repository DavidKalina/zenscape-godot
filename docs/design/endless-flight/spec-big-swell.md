# Spec: the big swell (ITER(big-swell))

The sea round the edge of the world gets big waves you fly among. A first
version is built (the commit after this spec): the surge, in
`shaders/endless_sea.gdshader` (`zs_surge`) and mirrored for the plane in
`scripts/endless/endless_sea.gd` (`surge_at`, `surge_room`, `set_edge`). This
loop polishes it until the waves look and fly nice. The user judges by
playing; a task isn't done because numbers came out right.

Worktree `../zenscape-big-swell`, branch `iter/big-swell`. Model: Opus. Cap and
budget: the skill's default. Nothing is merged to main in this loop.

## How to reach it

    python3 tools/play.py -- --no-title --pilot-file=/tmp/big-swell.json --at=8200,600 --heading=0 --alt=40

That is the east side, heading along the crests (`--heading` is clockwise from
-z). The edge line is at x = 7500 there. `--surge=0` takes the surge off;
`--sea-set=surge_size:1.4` sizes it.

The stills that showed it best, a low eye looking back at the land:

    python3 tools/shot.py studies/endless_flight.tscn --at 8700,-28,420 --look 8200,-34,560 --settle 240 --timeout 100 --out captures/shots/<name> -- --no-title --at=8300,420 --heading=90 --alt=30

`scratch/surge_check.gd` is a driver for heights, smoothness, cost and a
hands-off low flight:

    python3 tools/drive.py scratch/surge_check.gd --all --timeout 200 -- --scene-args --no-title --at=8000,600 --heading=90 --alt=9

## What's true now (2026-11-02)

- Three long waves (180, 130, 90 m), two with fronts along the edge line, so
  they roll toward the land on every side, and one crossing them.
- Full height 700 m past the edge line; the plane is turned home from 2000 m
  past it. Land stops short of the line (at most 20 m inside; median 950 m).
- Crests about 21 m at the very top of a set; 1 sample in 100 over 11 m.
- Hands off at about 9 m over the water, at cruise, the plane skipped up over
  a face and lost about 4 m/s without crashing.
- `height_at` costs about 15 microseconds in the belt.

## Done looks like

1. **The waves read as big and as water, from the cockpit's chase camera**, at
   the heights the user actually flies: low and fast, and from 100 to 200 m.
   Lit faces, dark troughs, a crest line that holds together as it moves.
2. **Foam reads as foam.** Today it is flat cream patches like cut paper up
   close. Crests should tear into white water, with lace and streaks down the
   back of a wave, and no hard-edged islands. Only the tall crests break.
   Up close the lace must read as soft foam: the first pass reads as cracked
   glass (`captures/swell/t2i_low_0.png`), wire-thin hard lines round cells a
   few metres wide. Judge it from a low chase camera on a wave's back, not only
   from the face.
3. **The crests throw spray.** Spindrift blowing off the tall crests, with the
   wind, the thing that says "big" at a distance. Cheap: it runs round the eye
   and only in the belt. No cost anywhere else in the world.
4. **They hold up in motion.** No popping as the sheet moves under the eye, no
   shimmer or swim on the far waves, and a calm join where the waves flatten
   with distance (the sheet's heave fades 2.2 to 3.2 km from the eye). The
   user has not seen this yet; check it with a run of stills or a short film,
   not one frame.
5. **The join to the calm sea is graceful.** From the shore and from the air
   the belt builds up over distance; no visible ring, no bands of repeated
   sets, no seam at the rounded corners. Check all four sides and a corner.
6. **They're fun to fly.** Skimming a face at speed and running along a crest
   feels good and pays in the near-miss and line scoring, which already read
   the water. Boost speed (about 57 m/s) is untested. A touch that feels unfair
   gets fixed: a low plane surprised by a rising wave should scrape and throw
   water, and a crash should still mean a real dive into it. Water landing in
   the belt should be hard, not impossible or a bug. Prove it through the real
   input path, not scripted ticks alone.
7. **It looks right across the day.** Dawn, midday, dusk and night, and under
   cloud: the green crest glow mustn't turn neon or black. Judge with stills.
8. **It costs little.** Compare frame times in the belt with `--surge=0`,
   rendered, repeated before believing it (AGENTS.md, Stutter and frame rate).
   Inland the sea should be no slower than before. If the plane's height read
   shows up in the frame, port `surge_at` to native
   (`native/terrain_kernels/flight_fx.h`, ZenScapeSwell); otherwise it stays in
   GDScript. A native change must keep the GDScript path working and say in its
   notes that the PC's kernels need a rebuild.

These are the targets, in the order a player meets them, not a fixed task list:
the first iteration writes the Plan, and each task should end in something the
user can look at.

## Out of scope

- The barrel: a curling wave you fly through is a later, separate build. Don't
  start it or lay groundwork for it.
- Changing the land, the coast recipe or the fence.
- Seeds other than 1.
- Other worlds: the surge runs only where the land has an edge line.

## Rules

- The swell keeps the waves deterministic from position and the sea's clock
  (co-op someday): no per-machine randomness in what the plane reads.
- The shader's surge and `surge_at` must always match. Change them together.
- Keep the look stylised; judge looks by eye in rendered stills. Rendered
  captures: one window, short, with `-- --no-title`.
- No `git stash` (the list is shared with the user's other work). Stage by
  explicit path.
- Prototyping rules (AGENTS.md): no new committed tests and no full suite.

## Smoke check

    python3 tools/smoke.py studies/endless_flight.tscn -- --no-title
