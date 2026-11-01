# The ice field: the Peak's glacier, populated

Loop slug `icefield`, trail prefix `ITER(icefield):`, branch
`claude/game-collectibles-brainstorm-357237` (main as of 2026-11-01, with
the crown, the carve lines, the climb fix and the spiral strike all in).
Cap and budget: the skill's defaults. Model: Opus for every lane and the
trunk. A prototype round (AGENTS.md, Prototyping): smoke checks and
throwaway drivers in `scratch/`, no committed tests, no full suite. Each
commit lists the existing tests its change breaks.

Seed 1 only. The Peak is a set piece; everything here is hand-sited in the
massif's frame (`PeakMassif.world(a, v)`: `a` along the axis from the
plateau out toward the start, `v` across it, heights over the sea).

## Why

The user, having played the crown: the glacier approach is "a massive ice
field that's pretty boring, it's just flat", "the routes up aren't that
cool", and "the top is dope". What they want: "populate it with more
landform, more stuff to fly around and through, for that sensation of
speed". Sense of speed comes from things passing close, so the glacier
needs the density of forms the coast's stacks and the forests have, in ice.
No hazards, no attacks, no wind: the mountain stays still air outside the
rock gorge's lift, and the spiral strike (`--peak-strike`) is not touched.

Baseline stills (git-ignored, `scratch/icefield/base_*.png`, from
`scratch/icefield/baseline.gd`): the glacier is a flat painted floor about
1 km long (a 3100 down to 2050, 100 to 300 m over the sea) and 500 m wide,
between two smooth moraine banks, with nothing standing on it until the
serac spill at the mouth (a 2050 to 2185). The shoot every lane and the
trunk repeat from the same five spots: toe (eye a 3050, 40 m up, looking at
a 2600), mid (a 2550 to 2100), mouth (a 2200 to 1800), high (a 3100 at
450 m up, looking down the glacier to a 2300) and side (a 2600, v 700,
250 m up, across to v 0).

## What done looks like

`.\run-endless-flight.cmd`, seed 1, take off and fly at the three spires:

1. **The glacier is a place to fly, not a floor.** From the toe to the
   mouth the ice is broken into things to thread at speed: crevasse slots
   you drop into and fly along, a medial moraine ridge to skim, serac ranks
   across the flow with lanes between them, ice fins along the flow, an ice
   arch or two to fly under, an icefall step where the surface drops in
   broken blocks. Low and flat out, something passes close every few
   seconds; the near-miss chain reads it (walls, threads, slaloms, skims).
2. **It reads as a glacier.** Blue in the slots and under the overhangs,
   white on top, dark moraine stripes, not "white crystals" and not a
   rectangle (the crown spec's taste on ice holds). Judged from the five
   baseline spots against the baseline stills.
3. **Three ways up that read differently from the glacier:**
   - **The slot**: the ice gorge (right of the prow), tight, the crevasse
     lines on the glacier leading into it, seracs dense in its bowls.
   - **The ramp**: the rock gorge (left, with the stair and the lift), the
     wide, fast way. Kept as it is.
   - **The tunnel**: new. A dark mouth in the glacier's flank near the
     prow, a flown tunnel climbing inside the mountain, out over the
     saddle. Hidden in plain sight: you see the mouth from the ice, you
     don't know where it goes.
   The carve lines (the Slot and the Bench, `peak_carve.gd`) stay as they
   are.
4. **The finds sit on the new forms.** The foothills rows in
   `scripts/endless/finds_table.gd` move onto them, by position only, ids
   kept: `ice-skim` low inside the long crevasse, `bend-ring` under the ice
   arch, `gorge-room` as it is, `gorge-run`'s gates re-sited so the line
   threads the new forms up the ice gorge. One new relic, `tunnel-deep`,
   deep in the tunnel (area `foothills`, kind `relic`, a `hall`-style row
   is not needed: a plain `at`). No new find kinds.
5. **Hand-flyable, medium weight, with and without Boost.** Every opening
   the spec adds is proved by a bot on the real stick with a wobble, not
   one exact line, and the least room past a wingtip is in the commit.
   The user flies medium only (light and heavy are not proved).
6. **Meadows and flats hold.** The glacier's first 250 m from the toe
   (a 3100 to 2850) stays flat enough to land on by hand, and the outer
   moraine banks keep their flats. Proved by a hand-style landing on the
   toe after everything is in.
7. **Cost.** Rendered frame time along the glacier line, before against
   after, on the Full preset, median and p95 in the handoff, and chunk
   build cost near the glacier (any new per-vertex pass runs in C++, with
   the GDScript mirror kept, as the Peak's does today).
8. Smoke passes on `studies/endless_flight.tscn` with everything on and
   with `--ice-carve=0 --ice-forms=0 --ice-tunnel=0`.

## What stands today (read before building)

- The massif: `scripts/endless/peak_massif.gd` (`world`, `gorge`,
  `STRETCHES`, the glacier's extents `ICEFALL`, `GLACIER`, `TOE`, the
  snow line), mirrored in C++ `native/terrain_kernels/peak_massif.h`
  (`zspeak::Massif`, class `ZenScapePeak`). **A change to the Peak's maths
  or constants is made on both sides and `NATIVE_VERSION` bumped**
  (`crown-native-handoff.md`); parity is proved bit for bit by a scratch
  driver that builds chunks with the twin on and off and compares every
  array. `--native-peak=0` runs the GDScript side.
- The split: `scripts/endless/peak_split.gd` (the prow, both gorges, the
  spill at the mouth `SPILL_*`, `NOSE_Y` 308, `SADDLE_Y` 840).
- The ice paint: `scripts/endless/peak_ice.gd` (a line of points from head
  to toe with half-width, cover, debris) and `shaders/peak_ice.gdshaderinc`
  (blue in cracks, sheen, flow stripes). The seracs: `scripts/endless/
  rocks/peak_serac.gd` (the mesher, ice material) placed by `rocks/
  peak_valley.gd` (a rock kind, `rocks/rock_plan.gd`, box in a, v; a lane
  kept open along the line; `--peak-ice=0`, `--valley=0`). Rock kinds
  place through `land_rocks.gd` `_build_cell`, get a ConcavePolygon
  collider and a flight solid (`LandRocks.stretches`), and the near-miss
  chain reads them.
- Arches: `scripts/endless/arch_plan.gd`, `arch_build.gd` (solid as
  columns; the carve round warns `BoxSolid.from_faces` can fill an opening
  with a phantom column). The carve's own rock: `rocks/peak_carve_rock.gd`
  (a distance field meshed on a worker, pieces as `LandArches` specs).
- Tunnels: `scripts/endless/land_tunnels.gd` (`_make`, bodies with
  backface collision; shaders `tunnel_stone`, `tunnel_basalt`, the vine and
  fern dressing). The overgrown tunnels are the mountain-tunnel machinery;
  `docs/design/endless-flight/overgrown-tunnels-handoff.md` and
  `spec-mountain-tunnels.md` say how a tunnel punches the field.
- Openings: toy widths through `WorldScale.opening(toy)` (AGENTS.md,
  Sizes). The plane's contact grades: `scripts/endless/flight_contact.gd`.
- Finds: `finds_table.gd` (the header has the anchor vocabulary),
  `place_lines.gd` (gates), `cracked_walls.gd` `SITES` (the rooms).
- The lift: `scripts/endless/air_lift.gd`, `peak_routes.gd` (the rock
  gorge's one-way tube). Don't add lift elsewhere unless the tunnel can't
  be climbed without it, and say so if it can.
- Drivers: `tools/harness/drive.gd` (`python tools/drive.py --api`); no
  wobble helper exists, a driver measures room itself with `pierce` and
  `ray`. The crown rounds' matrices were in git-ignored `scratch/` and are
  not in this worktree: write your own, small.
- Flags the Peak already has: `--peak=0 --towers=0 --spirals=0 --stair=0
  --lift=0 --peak-ice=0 --peak-snow=0 --peak-tarn=0 --peak-rock=0
  --peak-carve=0 --peak-strike=0`.

## Lanes (parallel, one Opus agent each, own worktree)

Each lane keeps its code in its own new files, keeps edits to shared files
small and additive, carries a flag to switch it off, proves itself with a
throwaway driver and stills from the baseline spots, and ends its commit
with **Notes for merge** (the shared lines it touched, its API for the
trunk). Lane commits: `ITER(icefield): lane <part>: <task>`. Lanes don't
wait on each other; the trunk merges them.

- **carve** (Opus). The glacier's floor in the height field, both sides
  (`peak_massif.gd` and `peak_massif.h`, version bumped, parity proved):
  - Crevasse slots: narrow (8 to 20 m across at the top, an opening at
    least `WorldScale.opening(3.5)` wide where the line goes), 15 to 40 m
    deep, walls steep with a rounded lip, in bands that curve across the
    flow where a real glacier bends (the glacier has `GL_BEND`, `GL_TURNS`),
    and **one long one** running along the flow for 300 m or more, wide
    enough to fly inside at medium with wobble, open at both ends.
  - A medial moraine ridge, 10 to 25 m high, down the middle, curving with
    the flow, broken, not a rail.
  - Meltwater channels: shallow grooves (2 to 5 m) wandering down the
    surface, for the paint and the skim.
  - An icefall step about mid-glacier: the surface drops 40 to 60 m over
    80 m in broken blocks (the forms lane stands seracs on it).
  - The first 250 m from the toe stay flat. The spill and the gorges are
    not touched.
  - The ice paint follows: the slots read blue inside (a depth or
    crevasse mask the shader can read; the ice shader already has a
    blue-in-cracks term), the ridge dark. Snow on top as today.
  - Flag `--ice-carve=0`. Proof: parity bit for bit; chunk mesh and
    collider agree with `height()` across the slots (rays); a driver on
    the stick flies the long crevasse end to end at medium, Boost on and
    off, with a wobble, room numbers; stills from the five spots; the toe
    landing. Chunk build time near the glacier against far from it.
- **forms** (Opus). Standing ice on the glacier as a rock kind in
  `scripts/endless/rocks/` (its own file; a `peak_valley.gd`-style kind
  with a box in a, v and a kept lane), reading the field's height at
  build so it stands on whatever the carve lane leaves:
  - Serac ranks across the flow at two or three places (the icefall step
    and the bends), lanes between the towers an opening wide, towers
    tilted and leaning on each other as `peak_serac.gd` does.
  - Ice fins: tall thin blades along the flow, in runs you weave.
  - One or two ice arches: a serac bridge over a slot or between two
    towers, flown under, with an opening at least `WorldScale.opening(4.0)`
    and a real solid (columns, not `from_faces`).
  - Tumbled blocks along the moraine's foot.
  - None in the first 250 m from the toe. A lane stays open along the
    glacier's line, widening in the bowls, as the valley kind does.
  - The serac read: where this lane's pieces use `peak_serac.gd`, make the
    ice read as ice and not white crystals (`crown-handoff.md`, Known weak:
    an unfinished patch existed and is gone with `scratch/`; do it fresh,
    small: tone, rim, blue in the undercut, less specular bloom).
  - Flag `--ice-forms=0`. Proof: a wobble driver threads each rank, each
    fin run and under each arch at medium, Boost on and off, room numbers,
    0 crashes; the near-miss chain scores a thread under an arch and a
    slalom through fins (print the moves); stills; triangle counts and the
    kind's cell build time; `docs/art/model-budget.md` assessed in the
    notes.
- **tunnel** (Opus). A flown tunnel through the massif's shoulder, its own
  file (`scripts/endless/peak_tunnel.gd` or beside `land_tunnels.gd`), on
  the tunnel machinery:
  - The mouth in the glacier's flank on the ice gorge's side, between
    a 2400 and a 2150, seen from the ice as a dark opening with a snowed
    lip; it must read from the toe at a 3050 (a still proves it).
  - Inside: climbs from about 300 m to the saddle (840 m) over 1.2 to
    1.8 km of tunnel, bends gentle enough for medium at Boost with wobble,
    a cross-section at least `WorldScale.opening(5.0)` and higher than
    wide, one or two windows to the sky or a chamber on the way, and an
    exit over the saddle so the plateau approach and landing work as they
    do (`crown-handoff.md`: Boost off at the saddle, Brake, flaps).
  - A cold dressing, not the overgrown one: bare rock and blue ice veins
    in the walls, ice on the floor, light from the windows and the ice
    (no vines, ferns or strands). New shader variants only if the stone
    and basalt ones can't be tinted.
  - No lift unless medium can't climb it without; if lift is needed, make
    it one way and telegraphed as the rock gorge's is, and say so.
  - Flag `--ice-tunnel=0`. Proof: a wobble driver flies it up and down at
    medium, Boost on and off, 0 crashes, least room; the field above the
    tunnel is solid (rays from above hit ground, not the tunnel's hollow);
    stills at both mouths and inside; the saddle landing still 2/2.

## Lanes landed (2026-11-01)

- **carve**: branch `worktree-agent-aa61725b479fe1f00` (eb220906 round 1,
  3bd15b0d and 891fcd23 round 2). Proved: parity bit for bit (native
  version 4), long crevasse 24/24 with wobble, toe landing 2/2, chunk cost
  unchanged. API `PeakMassif.carve_line(field.height)`. Open: the bands
  read as a dotted grid from the high spot, the step reads terraced from
  the toe. **The version-4 DLLs exist only in that worktree's
  `native/terrain_kernels/bin`** (main's are version 1): copy both DLLs
  and their `.sources` stamps from there, or rebuild, before any run.
- **forms**: branch `worktree-agent-a45b55d7ff87ac50e` (f2ed8cda). Rock
  kind `ice-forms` (`rocks/peak_ice_forms.gd`): ranks at a 2790, 2505,
  2240; fin runs a 2745-2595, 2455-2315; arches a 2560, 2290; blocks along
  the moraine. Proved on the uncarved floor only (two runs, 0 crashes,
  least room 2.33 m at fin run 1 with Boost). API
  `PeakIceForms.sites(field, peak)`. Open: rank side lanes unproved, the
  forms on the carved floor unproved, two cells build in 49-58 ms (over
  the bar), fins read as slabs, the bridge thin; it also widened
  `line_moves.gd` `_fin_at` to count any rock pillar for a slalom, and the
  line tune skips slaloms by default (a scoring call for the user, left).
- **tunnel**: branch `worktree-agent-ad8a8c7942b15ff59` (9efdef62,
  ac3e905e, c74bc65c). `peak_tunnel.gd` (the line) and
  `land_ice_tunnel.gd` (the tube, lights, collider, flight queries), hooks
  in `endless_flight.gd`, `land_field.gd`, `land_stream.gd`,
  `hall_doors.gd`. Mouth A at about (a 2185, v -290) in the bank (there is
  no flank wall there: the bank is 50-80 m), mouth B at s 1815 (a 600,
  v 180), 40 m under the saddle, the line then rounding to the saddle.
  Flown with Boost 6/6 both ways, least room 5.8 m; **without Boost 2 of 3
  runs down crash in the open gully stretch (s 1463-1548), where three
  Slot carve pieces (the blade at a 1030, the eye at a 960, the blade at
  a 890) stand across the bore.** Open: the solid-field rays, the saddle
  landing out of mouth B, the in-tunnel water check, stills after the
  relight (the inside was near black before it), a closer toe still.

**Decision (lead, 2026-11-01): the carve pieces stay.** The tunnel's
gully crossing is re-routed to cross the Slot line perpendicular at about
a 932, between the eye (a 948-972) and the blade at a 890 (to a 916); the
chamber's and window's s values move with it. Prove the crossing again
without Boost.

## Trunk (in order, Opus, one task an iteration)

1. **Merge.** Merge the three lanes' branches into the loop's branch,
   joining the shared lines from their Notes for merge; smoke with
   everything on and with every lane's flag off; parity still bit for bit;
   the forms stand on the carved field (re-read the heights, re-prove the
   room numbers that changed); the tunnel's gully crossing re-routed per
   the decision above and the no-Boost descent re-flown; the version-4
   DLLs in this worktree's bin; commit the merge under the prefix.
2. **The three ways.** The slot: the crevasse lines lead into the ice
   gorge and its bowls get denser seracs if its room allows; the tunnel's
   mouth reads from the glacier and its exit joins the saddle; the ramp
   untouched. A matrix: each way up at medium, Boost on and off, three
   wobble seeds, up and back down, 0 crashes, room numbers, and the plateau
   landing out of each.
3. **The finds.** Move the rows as the done list says, add `tunnel-deep`,
   re-site `gorge-run`'s gates; the ids and the layout handles
   (`finds/<id>`) keep. A driver takes each find and finishes the line.
4. **Look and cost.** Stills from the five baseline spots beside the
   baseline, A/B'd; fix what reads wrong (the user's taste: gritty, depth
   from detail that shrinks with distance, no fine grain on the rock
   shader). Rendered frame time along the glacier line, Full preset,
   before against after; chunk cost near the glacier; hitches named. Any
   pass over 2 ms a frame or 20 ms a chunk in GDScript goes to C++.
5. **Final.** Smoke both ways, the toe landing, the stills, then the
   handoff (`docs/design/endless-flight/icefield-handoff.md`): what's
   built, the flags, how to find each thing from the start, the numbers,
   what's unproved, which tests the change breaks.

## Proof, every iteration

- `python tools/smoke.py studies/endless_flight.tscn` passes, 0 errors.
- Throwaway drivers in `scratch/` (`python tools/drive.py --api`), left
  uncommitted; the commit quotes their numbers.
- Rendered stills from the baseline spots (`scratch/icefield/baseline.gd`
  is the pattern: the study's camera moved by hand with the land stepped
  round it), one window at a time, `-- --no-title`; looked at before the
  commit, listed under Look at.
- Headless-only limits reported as unverified, never retried with a
  renderer. The full suite is not run; tests touched by the change are,
  and breaks are listed.

## Not in this loop

Hazards, attacks, wind or thin air on the glacier. The spiral strike. The
crown, the towers, the lake, the strip, the carve lines, the rock gorge.
The foothills' other land. A map view. Light and heavy weights.
