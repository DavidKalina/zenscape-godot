# Sundered hall: handoff

Branch `feature/sundered-hall`, from `feature/ruins` (a39b3c7d). Not merged to main, not pushed.

The brief: one long gothic hall of the old sky-builders, torn apart when the land broke. Its pieces float on a chain of islands at different heights, and the plane flies the whole nave, gaps and all, for a minute or more. Exits through the roof or the sides all the way along.

## What was built

- **Planner** (`scripts/sundered_hall.gd`): plain data, safe on a worker, the same hall for the same seed. It lays the hall as acts, not as one bay repeated.
  - **gate**: a gabled west mouth out of open sky, then roofed bays and the first light.
  - **nave** (2 pieces): the dark whole roof, in runs of 2–3 bays, each run broken by a wide arch out of the side.
  - **shafts** (1–2 pieces): a broken roof with light coming down in shafts.
  - **drop gap**: a 34–40 m gap that steps down 8–11 m (a dive).
  - **cloister** (2 pieces): open sky over the columns, walls torn low or collapsed.
  - **aqueduct gap**: 40–44 m. A small island stands in the gap and an aqueduct crosses the line square. The line threads the middle arch, and the channel spills off its snapped end down to the cloud sea.
  - **slit**: screens with knife-edge slits every other bay, inner columns paired.
  - **shafts** again.
  - **apse**: the roof opening up, a ring of snapped columns past the end, a snapped tower beside it, and the line climbing out to open sky (the release).
- **Gaps and curves.**
  - Other gaps are 12–30 m with a 4–5 m step up or down. No step is steeper than 0.3 (about 17°).
  - Each gap kinks the line by up to 0.14 rad.
  - Pieces curve with the kit's curved stretches (radius ≥ 70 m), alternating sides so the hall snakes. The heading never wanders more than 0.9 rad off the first.
  - Every torn end has snapped columns, no beam or gable over it, and walls torn down to 2.6–5.5 m.
- **Exits.** No more than 2 bays in a row lack a way out (an open or broken roof, a flyable breach, a torn end or a gap).
  - Across 60 seeds the longest stretch with no exit is 26 m (1.9 s at cruise).
  - Breaches and open roofs also let you in midway.
- **Islands** (`scripts/sundered_build.gd` `solve`):
  - Each piece stands on its own real sky island, built by the cluster pipeline: rock palettes, keel, erosion, trees.
  - The islands are authored as rounded oblongs along the piece's chord. `IslandOutline.mask` takes a new optional `form` (`aspect`, `heading`, `drift`, `bays`, `lobes`, `square`), passed as the islet recipe's `outline`.
  - The torn ends overhang the island tips by 1–4.5 m. The land runs on 8 m past the gate and 16 m past the apse.
  - The hall's footprint is levelled into a bed at the floor, with higher ground eased down round it. Plants are cleared off the bed.
  - Walker blocks along the columns and walls are left open at breaches and doors.
  - The hall stands on a coursed podium. At torn ends the podium hangs in ragged stacks, with paving slabs tipping off the edge.
- **Bobbing.** All members share one bob phase and period (the cluster's), so the pieces stay aligned at the gaps. The hall nodes are children of their island nodes.
- **Detail and streaming:**
  - **Far:** one cheap mesh per piece from the plan: 8-sided plain columns, block walls with breach gaps, roof strips as whole slabs, beams, gables, podium, apse ring and tower. No carving, growth or collision. It stands with the island and is always there.
  - **Near:** the ruin kit's bays at `Hall.IN_WORLD`, plus the podium, torn ends and apse.
    - Built on a worker for the nearest piece within 340 m, one piece at a time.
    - Shown within 240 m (the far is hidden then) and let go past 480 m.
    - The mesh stands in one commit. The body stands in chunks of 120 hulls, one per frame, inside the sky's frame budget (`SkyCommits`).
  - `RuinKit.merge` now reads arrays kept on the built mesh (meta `arrays`) rather than reading them back from the renderer, so it is safe on a worker. Reading back on a worker deadlocked against a main thread that was waiting. `RuinKit.forget_arrays` frees the kept arrays once merged.
- **Collisions in the game** (`scripts/ruin_bump.gd`, called from `wanderer_eye.gd` `_advance_flight`):
  - The plane bumps and recovers off the ruins' stone, the same way as the gallery's fly mode. Its body is a wing-wide slab turned with bank and roll, so knife edge works through the slits.
  - The query only reads the ruin layer (`RUIN_LAYER`, bit 11).
- **Placement** (`scripts/sky_clusters.gd`):
  - The hall is too long for a 850 m cluster cell, so it gets its own placement: `SPECIAL` motifs, `hall_spot`, `near_hall_spot`.
  - It stands in at most one world in `HALL_ODDS` (0.55). It is tried at 48 places 900–3400 m out, at 12 headings each.
  - The whole footprint (each island's capsule) must keep clear of:
    - the islands' spots by `HALL_ISLAND` (75 m) past the capsule;
    - the ranges, walls and band (`WALL_CLEAR`), the cumulus (`HALL_TOWER`, 60 m), the forested isles, the haze, and the home.
  - These clearances are tighter than a cluster middle's 240 m. The islands stand in a 450 m grid, and a kilometre of hall can only thread between them.
  - Random clusters and seeded islets keep `HALL_KEEP` (140 m) off the footprint.
- **The query** (in `sundered_hall.gd`, cluster frame):
  - `line`: the flown centreline (the lane's middle, 2.3 m over the floor);
  - `sections`, `exits`, `corridor` (per bay) and `anchors` (the torn ends' lips).
  - This is groundwork only. Nothing uses it yet.

## How to fly it

```
godot --path . -- --no-title --motif=sundered
```

- The hall stands 240–900 m from the home, heading away from it. The console prints where: "Sundered hall: its gate … m from the home toward …".
- Take off and fly to it. The near detail streams in as you come within about 340 m.
- `--motifs-near-home` includes it. `--motif-seed=N` picks a different hall. `--no-clusters` leaves the random clusters out.
- Without `--motif` it turns up on its own only in some worlds, far out.

Rendered stills from its real positions (opens a window; always pass `--no-title`):

```
Godot --windowed --path . --resolution 1280x720 -s res://tools/capture_sundered.gd -- --no-title --motif=sundered --no-clusters --out=captures/sundered/try1 [--hours=noon,golden] [--only=inside,gap]
```

Stills from this round are in `captures/sundered/try1` (noon, every shot) and `try2` (golden hour, after the islands became oblongs). The `captures/` folder is gitignored. Worth a look:
- `overview`, `gate`, `inside-1-nave-3` and `inside-4-cloister-3`;
- `gap-0-gap`, `gap-5-aqueduct` (the arch on the line, the spill), `torn-0` and `roof-1`.

## Measured

All measurements are headless, seed 7 (the `--motif=sundered` default), unless noted.

| What | Value |
|---|---|
| Hall, gate to apse (60 seeds) | 815–1011 m, 58–72 s at cruise (14 m/s) |
| Whole line (lead-in and release included) | 945–1135 m |
| Pieces, bays | 9–10 pieces, 78–98 bays |
| Autopilot traversal, gate to apse at cruise | **61.4 s** (863 m), 0 bumps, never more than 2.2 m off the line |
| Far detail, whole hall | ~15.4k triangles (budget 30k) |
| Near detail per piece | 44–71k triangles (≤ 7.9k per bay; budget 85k / 8k), 1.2–2.2k hulls |
| Aqueduct near | ~69k triangles, ~760 hulls |
| Near build per piece (worker) | 0.3–0.6 s |
| Planning the whole cluster (worker: islands, beds, far detail, dressing) | ~3.5 s solve, ~7 s with dressing |
| Standing a piece (main thread) | mesh < 1 ms (headless); body chunks ~1–1.6 ms each, but the first chunk of a piece ~5 ms |

## Checks

- `tests/test_sundered_hall.gd` (suite: slow) passes headless. It checks:
  - 60 layouts well formed, with length, gaps, grade, exits and acts in order;
  - placement clear of the islands and the other clusters;
  - the islands turned and clear of one another, and the floor on its bedded island;
  - the aqueduct's arch on the line;
  - the far and near budgets, and standing without a hitch;
  - the autopilot run (bump count and time);
  - streaming out and back in.
- The related tests run alongside: `test_sky_clusters`, `test_ruin_kit`, `test_sky_plane`, `test_cluster_motifs`, `test_sky_islet*`.

## Known issues

- **The first body chunk of each piece costs ~5 ms** on the main thread; the later ones cost ~1.3 ms. This looks like a per-body or per-parent cost in Jolt, not a per-hull one. It is over the 4 ms sky budget once per piece, so it is a small hitch every ~100 m. Next lever: fewer, simpler hulls per bay, or warm a body under the piece earlier.
- **Rendered render cost is not measured.** The near mesh upload on a GPU was not timed (the headless renderer is a dummy). Neither was the frame time with 2–3 near pieces in view (~150–200k triangles).
- **The roof from above is still a patchwork**, as the ruin kit's handoff says: flat slab tops in mixed grey, brown and moss.
- **Dark faces:** shaded long walls and the islands' shaded rock read near black from outside.
- **The pilot is not blocked by walls on foot.** The walker's blocks stop them at columns and walls, but you can't stand on the roof, wall tops or beams: the islets' walker only knows ground. Landing the plane inside the nave works (it is the island's ground).
- **The camera** (chase cam) can pass into walls. Only the plane bumps.
- **Island corners.** Lobes or warp still bite the odd corner, so a wall end can overhang air near a torn end. The podium shows there.
- **Far/near pop:** the far detail's broken roofs drop strips at random, not the near build's own gaps, so a broken bay's roof changes at the 240 m swap.
- **The apse tower** is plain coursed walls with a ragged head: no buttresses, no spire stub.
- **Not tested by hand:** bump feel, the knife slits in play, the light in the dark nave at speed, the dive across the drop gap, and how the streaming feels at boost speed (22 m/s gives ~6 s from build start to the 240 m swap; a build takes ≤ 0.6 s).

## Next steps

1. Fly it by hand. Check the gap lengths and steps at boost, the bump feel, and whether the nave stretches are too dark.
2. Collision cost: simpler hulls for the hall's bodies (merged course blocks per wall run, one hull per column), which would remove the 5 ms first chunk.
3. Far/near match: draw the far roof from the same gaps the near bay drew (expose the bay's chosen strips in its plan).
4. The roof from above, and shading the outside walls (the kit's open items).
5. On foot: walkable tops (roof, parapets, beams) as islet decks or a physics walker, if the hall becomes a place to land in.
6. More variety: a second aqueduct act, a crossing with transepts, a gate act with flanking towers.
