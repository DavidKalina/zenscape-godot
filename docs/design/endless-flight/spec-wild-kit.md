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

## This loop's task: step 0, placed sites

Only this. Lanes 1-4 below run in their own worktrees after step 0 lands;
they are not this loop's tasks. Signal COMPLETE when step 0 is committed and
checked.

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

The lanes merge into this branch (the orchestrator does it, joining the
kind table's lines), the smoke check runs, and a driven flight past every
piece gives stills. Then the handoff beside this spec.
