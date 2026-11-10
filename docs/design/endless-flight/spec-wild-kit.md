# Spec: wild-kit (the wilderness kit's first build)

Loop `wild-kit`, trail prefix `ITER(wild-kit):`. Branch
`claude/game-world-expansion-2d681e` (draft PR #45), worktree
`/Users/davidkalina/Documents/Projects/zenscape-wilderness-kit`. The master
list is `wilderness-kit.md` beside this file: read its "How a region is
made", its "Settled" section and its "Now" section first. Cap: the skill's
default.

## Settled, for every task

- People's things may be built (kept up, not abandoned); no human figures, ever.
- The ruin look is the aqueduct isle's look (`iter/wilderness-secrets`, not
  on this branch). Nothing in this build uses ruin stone.
- New kinds live in `scripts/endless/kinds/<kind>.gd`; their wilderness skin
  sits beside them or in `scripts/endless/world/wilderness/`.
- Wind is a look only; nothing here pushes the plane.
- Seed 1 only. The meadows-and-flats rule holds (AGENTS.md): nothing here
  may take away a landable flat near the plane.
- Flown openings are sized with `WorldScale.opening(toy_width)` (AGENTS.md,
  Sizes).
- Prototyping (AGENTS.md): a smoke check of `studies/endless_flight.tscn`
  plus a throwaway check through the real play loop (`scratch/`, left
  uncommitted); no committed tests, no full suite.
- Windowed runs and launch commands use a throwaway save:
  `-- --no-title --pilot-file=/tmp/wild-kit-pilot.json`. Never write the
  user's `user://` saves or `layouts/` files except the ones this spec names.
- No `git stash` (the stash list is shared with the user's checkouts).

## Step 0, placed sites (done)

Built and checked (4397081a, 9d7c0ee5). The lanes below built on it and are
merged; the loop's tasks now are the trunk's, at the end of this spec.

Done looks like:

1. **The list.** `scripts/endless/world/wilderness/placed.gd`: the
   wilderness's hand list of sites, each `[handle, kind, skin, x, z,
   heading, params]`. Handles follow AGENTS.md, Handles (`<route>/<piece>`,
   e.g. `wild/meadow_ring`) and stay stable once written.
2. **The reader.** An engine script that builds each listed site's piece
   when the plane comes near and frees it when it streams out, the way the
   land's generated sites are built. Height from the land under (x, z)
   unless `params` says otherwise. It reads the list of the region the site
   is in (the regions world: `WorldProfile.at(x, z)`), so a region with no
   list places nothing.
3. **Kinds by name.** One small table maps a kind's name to its script in
   `scripts/endless/kinds/`, with one build entry every kind implements
   (the site in, a Node3D out). Lanes add their kind with one line each:
   say in the commit exactly where that line goes.
4. **Moves win.** Each site's transform goes through
   `scripts/layout_overrides.gd` (`xform(handle, coded)`, `deleted`) with
   `res://layouts/endless_flight.json`: a hand-written move in that file
   moves the piece, and a deleted handle drops it. No file means the coded
   spots.
5. **A clear footprint.** A site's `params` can ask for a clear radius:
   trees, rocks and generated sites (arches, splits, stacks, tunnels, halls)
   keep out of it. Shaping the land under a site (a cliff, a cut) is not
   step 0; lane 3 owns that.
6. **Stand-in markers at the lanes' spots.** A `marker` kind (a tall,
   plainly coloured post, cheap) at the spots the lanes will use, from the
   master list's recorded flight. Check each spot is what the list says it
   is, and nudge it if not:
   - `wild/meadow_ring`, the fast meadow, ~(770, 70): open, flat, long
   - `wild/meadow_herd`, the same meadow, near a treeline the herd can bolt from
   - `wild/inlet_wreck`, the inlet shore west of the start, ~(0, 40)
   - `wild/river_falls`, the river stretch ~(1750-2250, 110 to -60), where
     a cliff or steep bank meets the river
   Coordinates are world x, z in metres on seed 1. The lanes swap the
   markers for their pieces.

Proof: the smoke check; a throwaway driver through the play loop that flies
near each marker and confirms it builds and frees; a hand-written move in a
`/tmp` layout file (`--layout=<path>`) that moves one marker; a rendered
still of each spot with its marker in view (`tools/shot.py`). Look at: those
four stills, labelled with their handles. They are the user's checkpoint on
the spots.

## Lanes (after step 0; not this loop's tasks)

Each lane branches from this branch after step 0 as `lane/<part>` in its own
worktree, keeps its code in new files, keeps edits to shared files small and
additive, and ends each commit with **Notes for merge**.

1. **director** (engine): a happenings director (rare moments keyed to
   place, hour and weather, one at a time, a cooldown per area; a launch
   flag to force a moment) and life reacts (flush, bolt, look up, follow).
   Moments: the cloud punch (climb out of a cloud into sun: a rainbow from
   `celestial.gd`, frost on the canopy that melts off) and waterfowl running
   off the water at takeoff from the inlet or a lake.
2. **elk** (kind: ground escort): a herd on the fast meadow that runs beside
   the plane when it skims low and bolts from a treeline. Built with the
   `enemy-build` skill (a mind lane and a body lane); a short loop of its own.
3. **waterfall** (kind: curtain, wilderness skin): a waterfall on the river
   cliff at `wild/river_falls` to fly through, a cave behind it and out a
   mouth lower down; the land shaping it needs.
4. **uprights** (kind: upright row / ring, two skins): standing stones from
   the rock shape kit in a ring at `wild/meadow_ring`; shipwreck ribs in a
   row at `wild/inlet_wreck`. Gaps to thread, sized by WorldScale.

## Trunk after the lanes

All five lanes are merged into this branch: director, uprights, falls,
elk-body and elk-mind (each lane's handoff or last commit says what it built
and left open). The trunk is this loop's tasks now, one per iteration, in
order. Signal COMPLETE when the last is committed and checked.

1. **The real elk.** Point `BODIES["elk"]` in
   `scripts/endless/kinds/ground_escort.gd` at
   `scripts/endless/world/wilderness/elk_body.gd`; keep the stand-in behind a
   flag (`--elk-body=standin`). Then the procedural layers on the real clips
   (skill `enemy-build`, Trunk): feet planted on the real ground (the clips
   plant on a flat plane, the meadow is not flat), the head's look-at on the
   real neck, and the mind's timings re-tuned to the real clips. Re-run the
   elk drivers (`scratch/elk/`, each with the run line in its header, one at a
   time) with the real body, and rendered stills of each pass.
2. **The herd keeps out of placed pieces.** The stone ring
   (`wild/meadow_ring`, 770, 70) stands about 110 m from the herd's spot. The
   herd checks trees, water and steep ground, not placed pieces' solids. No
   elk may run, leap, halt or drift home through a stone: make the herd's
   land check read the placed pieces (`placed.inside`, or the sites' clear
   circles), and prove it with a run beside aimed past the ring.
3. **Headings agree.** A placed site's heading turns the opposite way from
   the `--heading` launch flag (the ring's 90 faces west; `--heading=90` flies
   east). Make them one convention, the launch flag's (the plane's own), and
   flip the rows in `scripts/endless/world/wilderness/placed.gd` so every
   piece stands exactly where it stands now: stills of each piece before and
   after match.
4. **A flight past every piece.** One driven route from the start: the
   wreck's channel, the stone ring (under a lintel), the herd (a run beside),
   the falls (in through the curtain, out through the cave), a still at each,
   and the director's moments forced along it (`--happen=`). A launch line
   per piece. The smoke check, and each lane's main driver once more on this
   branch.
   Done (the driver is `scratch/tour/tour.gd`, uncommitted). The launch
   lines, each after `python3 tools/play.py --no-pull -- --no-title
   --pilot-file=/tmp/wild-kit-pilot.json`:
   - the wreck's channel, stern to bow (hold Boost, keep low):
     `--at=103,211 --heading=-47 --alt=4`
   - the ring, in under gap 0's lintel: `--at=579,69 --heading=90 --alt=12`
   - the herd, a run beside at cruise (it is 600 m ahead, keep it on your
     right): `--at=60,145 --heading=90 --alt=40`
   - the falls, in through the sheet: `--at=2350,30 --heading=-82 --alt=40`
   - the waterfowl: drop `--no-title`, add `--happen=waterfowl`, press Start
   - the cloud punch: `--happen=cloud_punch --hour=16.5`, climb out of a
     tall cloud's top with the sun behind
5. **The handoff**, `wild-kit-handoff.md` beside this spec, from the trail
   and the lanes' handoffs: what's built, where to play each piece (launch
   lines), what's stood in, what's open (each lane's open list, plus the
   frost's streaks and the wreck's thin side-on look, both judged good
   enough for now by the user), and which existing tests the build breaks:
   find the tests under `tests/` that read the files this branch changed
   (`git diff --name-only main...`) and run only those, headless.
