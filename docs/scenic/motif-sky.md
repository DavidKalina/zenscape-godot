# Motif sky: the four ruin motifs in the aqueduct isle's sky (handoff)

Branch `consolidate/motif-sky`, from main 471e2249. Not merged, not pushed.
This is round 6 of docs/design/consolidation-audit.md ("split isle from study,
place the isles in one frame, build each on a worker within SkyCommits").

The user asked: "I want to remove anything that isn't one of the ruin motifs
... add all the other motifs to the aqueduct island scene."

## Try it

```sh
godot --path . res://studies/aqueduct_isle.tscn -- --no-title --fly
```

The motif isles stand round the aqueduct isle a few hundred metres out (see
the table below). Fly to one, R3 / Tab to circle it (its card shows), land on
its turf by hand, get out (F) and walk. `--no-far-isles` (or `--no-motifs`)
leaves them out. Headless, `--motifs-now` builds them at once (see "Headless").

## What was removed

From `studies/aqueduct_isle_sky.gd` (the scene, not behind a flag):

- the 17 `ISLES` far isles (`scripts/sky_islets.gd` islets) and their trees'
  far stand-ins;
- the 6 `CLUSTERS` (farmstead, falls, hamlet, reef, lake, forest: cabins,
  windmills, docks, the folk dresser);
- the `PIERCED` isle and its plane bump;
- their worker queue, `_solidify` trimeshes and the ambient life's tree
  reading (`SkyIslets.catalog`).

The shared scripts stay for the old builder game: `sky_islets.gd`,
`sky_islet.gd`, `sky_clusters.gd`, `cluster_dresser.gd`, `sky_pierced.gd`,
`pierced_*`, `cabin.gd`, `rock_looks.gd`.

Kept: the airships, the CPU traffic, the cumulus towers, drifting clouds and
tearing, the motes, the plane tokens, the serpent, the lodestone's shard and
ring, and the hall chain (the Sundered line).

## Where each motif sits

Each motif's own frame has its middle near the aqueduct isle's (x 75-86,
z -5 to -22) with its turf at 30 m. It is placed by an offset from that frame
(`scripts/kit_isle/motif_sky.gd` `PLACES`).

| Motif | Offset | Middle (world x, z) | Radius | Top (world y) | From the aqueduct isle |
|---|---|---|---|---|---|
| Bell spires | (338, 12, 82) | (420, 60) | 33 m | 42 m (spires to about 76) | 345 m east |
| Cloister tarn | (-14, 0, 365) | (60, 360) | 53 m | 30 m | 381 m south |
| Sundered gorge | (-386, 6, 102) | (-300, 80) | 56 m | 36 m | 398 m west |
| Colonnade spine | (-286, 18, -320) | (-200, -330) | 85 m | 48 m | 421 m north-west |

Between them there is 282 m (gorge to colonnade) to 632 m (bell to gorge) of
open sky.

They are placed clear of the following:

- **The aqueduct isle.** Each is outside its lock ring (194 m).
- **The lodestone's shard (200, 42, -380), its ring and the hall chain's line.**
  The line runs out north-north-east from the isle. The nearest motif, the
  bell spires, is 344 m off the line, the colonnade spine 361 m.
- **The four cumulus tower spots** (`scripts/kit_isle/kit_clouds.gd`
  `TOWERS`). Each tower keeps the old game's 340 m keep from every motif's edge:
  the tarn to (-100, 750) is 367 m, and all four towers still stand.

## How the extraction works

### Motif builders

Each one is a `RefCounted` in `scripts/kit_isle/`:

| File | What |
|---|---|
| `kit_motif.gd` | The interface: `id`, `isle_name`, `isle_card`, `top`, `summit`, `flora_site`, `flora_seed`, `life_script`, `pools`, `plane_tokens`, `token_source`, `warm`, `build(into)`, plus `frame`, `landed` and `plane_near` for live bits, and `rest_decks`. A `solid_box` helper. |
| `motif_bell_spires.gd` | The art, the four rope bridges (meta `rest_deck`), the bells' pendulum (swing, landing ring, plane ring), the plane tokens (`spire_tokens`) |
| `motif_cloister_tarn.gd` | The art, the bridges, the water with its skim surface (`WATER_LAYER`), the fall, the plane tokens (`tarn_tokens`) |
| `motif_sundered_gorge.gd` | The art, the rope bridge, the tower and chimney boxes (now under Art, not the scene root), `GORGE_TOKENS` |
| `motif_colonnade_spine.gd` | The art and bridges |

`build(into)` touches only the node it is given: no scene, no physics query,
no tree. It records its lands as `[land, outline, cliffs]` for whoever stands
it to register.

- **The standalone scenes** (`studies/<motif>_isle.gd`) build the motif at the
  origin into their own `Art`, register the lands with `add_turf`, and keep
  their own flora and life. Their fields (`belfry`, `bells`, `cloister`,
  `west_half`, `rope_deck`...) alias the builder's.
- **The layouts are unchanged.** `tools/kit_isle_fingerprints.sh` was run
  before and after. Every isle's shapes are the same and all 62k rays agree to
  0.0000 m. The one "different" shape hash is the parked plane's cylinder,
  whose object id is printed inside its data.

### Placed isle (`scripts/kit_isle/motif_isle.gd`)

A placed isle is a `Node3D` at the world's origin with its `Art` at the
offset. It stands in for the scene to the life: `isle_top`, `flora_site` (the
site moved by the offset), `_turf`, `_outlines` (world), `flora`, and the
study's `_atmosphere`, `_celestial`, `_precipitation`, `camera`, `motor`,
`flying` and `plane_figure` passed through.

It comes up in stages:

1. **`building`.** The art is built on a worker.
2. **`standing`.** One part a frame, moved from the off-tree staging node
   into the Art.
3. **`turf`.**
   - Its turf goes on `TURF_LAYER`, and its rids into the study's
     `_turf_rids`, so the wheels' stone query doesn't count it as stone.
   - Its pools are added to the pilot's ground, moved by the offset.
4. **`flora`.** `KitFlora.Grow` runs in slices.
5. **`life`.** `KitLife.begin` and `step` run in slices. The life's
   `offset` is set and `shares_wind` is on, so it rides the home isle's breeze
   ribbons. Its tokens' HUD is the sky's.
6. **`up`.**

Each frame (`advance`) it runs the bells and the pilot's landings, and the
plane's passes. Its life is advanced and its tokens touched only within
`LIFE_NEAR` (320 m) of its edge.

### Motif sky (`scripts/kit_isle/motif_sky.gd`)

The sky makes this only when its scene answers `wants_motifs()` true
(`studies/aqueduct_isle.gd`). A motif's own scene has none.

- **Building.** One worker at a time, nearest the eye first.
- **Main-thread work.** A slice a frame, nearest first, within `SkyCommits`
  (at least 1.5 ms once the frame's budget is open).
- **Plane tokens.** Each motif's plane tokens are added as a source on the
  sky's collectibles, moved by the offset.
- **`places()`** is static and answers `[id, middle, reach]` per motif. The
  clouds' layout, the traffic and the motes read it.
- **`flush()`** stands everything at once.

### Changes to shared code

| File | Change |
|---|---|
| `kit_flora.gd` | `grow`, `undergrowth` and `draw` are now resumable classes (`Grow`, `Undergrow`, `Draw`) run to the end. The records and their order are identical: the standalone flora counts match. |
| `kit_life.gd` | Setup is `begin` plus `step(usec)` (`setup` runs it to the end). Its hooks answer in the isle's own frame, and the base moves them by `offset`: `top`, `ground_span`, `ride_y`, `chaff_meadow` (`placed(rect)`), `leaf_spots`. It also has `shares_wind`. |
| `kit_birds.gd`, `kit_tokens.gd` | Their `offset` moves the isle's spots. |
| `deck_ground.gd` | A bridge with meta `rest_deck` sags as a resting walk-box deck whatever `rest_decks` says. `_sagged` compares in the bridge's frame. |
| `bell_spires_isle_birds.gd`, `_tokens.gd` | Use `bel.transform` and `child.transform` (the isle's frame), not global. |
| `colonnade_spine_isle_life.gd` | Its chaff meadows go through `placed(rect)`. |
| `bell_spires_isle_sky.gd`, `sundered_gorge_isle_sky.gd`, `cloister_tarn_isle_life.gd` | Their plane tokens now come from the builders (same data). |

## Re-routed

- **Airships** (`ROUTES`):
  - Route 0 still passes the isle close (the drone on its top) and runs out by
    the bell spires.
  - Route 1 now circles the colonnade spine.
  - Route 2 circles the cloister tarn.
  - All three keep off the serpent's way (the serpent test: 15.9 m past its
    reach, against a ship's 14.9).
- **CPU traffic.** The planes lap the four motif isles and buzz their tops,
  where they used to lap the clusters and the pierced isle and buzz the
  islets.
- **Motes.** Round the isle and the two motif isles nearest it (the bell spires
  and the cloister tarn).
- **Ambient life** (`SkyAmbientLife`). Gulls ride columns over each motif's
  middle and summit once it stands. The motifs have no trees, so there is no
  crown flock: each motif's own songbirds are its life's.
- **Clouds** (`kit_clouds.gd`).
  - The towers keep off the motif isles, through the sky's `places()`.
  - The puffs' field is the isle plus the motifs.
  - `CLUSTER_REACH` and `PIERCED_REACH` are gone.
- **The rune serpent** (`scripts/rune_serpent.gd` `ROUTE`, `MARKS`):
  - Its pierced-arch stretch is gone.
  - It now swings out west and slithers the length of the Sundered gorge,
    between the two halves' rims at about 50 m, over the lower crossing and
    the broken bridge. It can't go lower: the gorge's free space is only 1-6 m
    across there, against its 4-5 m reach.
  - From there it goes back round the isle's north, dives into the cloud sea
    under the bell spires as before, and breaches north, home past the shard.
  - The marks are now north, gap, curl, **gorge**, west, east, dive, sea,
    breach, home. "arch" is gone.
- **Plane tokens.** The aqueduct isle's five stay. Each motif's own line is
  added at its place (`bell_spires`, `cloister`, `sundered_gorge`,
  `colonnade` sources).
- **Isle lock** (R3 / Tab) works on each motif isle.
  - `kit_isle.gd` `lock_target(at)` is a new hook, and
    `studies/aqueduct_isle.gd` answers the nearest isle in reach (home or a
    standing motif) with its card.
  - The plane skims the tarn's water (the aqueduct's `plane_ground` adds the
    motif water layer).

## Headless: art built on the main thread

Built on a worker headless, the art raced the main thread's own mesh and
material creation in the dummy renderer (godot#124183, as the audit's round-2
notes describe). The result was "uninitialized RID" errors, a broken
`PlaneFigure`, thousands of leaks at exit and a hang. So, headless:

- **`threaded` is off.** A motif's art is built on the main thread, a whole
  isle in one frame (1.1-3.5 s).
- **It is only built once the eye is within `HEADLESS_NEAR` (200 m) of its
  edge.** `--motifs-now` or `flush()` builds it at once. Tests and the
  packaged check on the aqueduct isle are never stalled by isles they don't go
  near.

Rendered, every isle is built from the start on a worker. The Forward+ mesh,
material and shader RID owners are thread-safe. The old far isles, pierced
isle and towers were already built this way.

**Builder scripts are preloaded, not loaded at runtime.** Loading the bell
spires' and the cloister tarn's builders at runtime inside the aqueduct scene
leaked about 1,060 objects at exit (the whole script graph). Preloading them
fixed it, which is why `PLACES` holds the scripts.

## Numbers (headless, this Mac, alternating runs, 30 s of frames uncapped)

`tools/motif_sky_startup.gd` measures the time from load to walking
(`isle_up`), then every frame's wall time for 30 s. Before is main 471e2249
(exported to /tmp, the same tool).

| | Startup to walking | Frame mean | p95 | Worst | Frames > 50 ms |
|---|---|---|---|---|---|
| Before (far isles, clusters, pierced isle) | 5.8 / 6.1 / 6.5 s | 8.1-8.9 ms | 9.2-10.3 ms | 51-57 ms | 1-2 |
| After, the headless default (motifs not near) | 5.8 / 5.9 / 6.1 s | 6.9 ms | 7.6-7.9 ms | 22-24 ms | 0 |
| After, `--motifs-now` (all four built on the main thread) | 6.3 / 6.4 / 6.5 s | 9.8-10.4 ms | 7.6-7.9 ms | 2.9-3.3 s | 9 |

- **Startup.** The pilot walks as soon as before. The motifs' setup on the
  main thread is under 150 ms: making the four nodes and warming the builders'
  layout caches.
- **All four up.** Every motif isle stands, grown and alive, 12-14 s after
  walking (`--motifs-now`, headless).
- **The 9 slow frames with `--motifs-now`:**
  - 4 are the art builds on the main thread (1.2, 1.5, 2.7-3.3 s). Rendered,
    these run on a worker.
  - 5 are 63-76 ms: standing the largest single part. That is the tarn's
    mother isle, with 18.8k cliff prisms (69 ms), and the colonnade's ridge
    (38 ms).
  - Every other frame stays under the budget, so p95 is unchanged.

Per-motif main-thread cost (`MotifIsle.timings`, ms):

| Motif | Art build (worker rendered) | Stand (all parts) | Worst part | Flora | Life |
|---|---|---|---|---|---|
| Bell spires | 1,100-1,250 | 25-31 | 20 | 84-99 | 88-96 |
| Cloister tarn | 2,850-3,500 | 90-122 | 69 | 310-390 | 120-160 |
| Sundered gorge | 1,440-1,880 | 37-52 | 13 | 375-490 | 165-215 |
| Colonnade spine | 2,670-3,440 | 78-105 | 38 | 615-815 | 235-310 |

Flora and life run in slices of the frame budget.

**Not measured:** rendered frame times and draw calls with the four motifs in
view. The motifs add about 1.03M static triangles of art and about 1.7M
instanced grass triangles (each with its 95 m draw range). The draw calls
the far isles, clusters and pierced isle cost (about 660 surfaces) are gone.

## Tests (headless)

| Test | Result |
|---|---|
| Import (`--headless --editor --import`) | Clean |
| `test_aqueduct_isle.gd`, `_life`, `_look`, `_plane`, `_sky` | PASS |
| `test_bell_spires_isle`, `test_cloister_tarn_isle`, `test_sundered_gorge_isle`, `test_colonnade_spine_isle` | PASS |
| `test_motif_sky.gd` (new) | PASS |
| `test_isle_lock`, `test_isle_teardown`, `test_isle_lodestone`, `test_isle_hall_chain`, `test_kit_isle_landing`, `test_kit_clouds`, `test_kit_water`, `test_rune_serpent` | PASS |
| `test_front_door`, `test_game_pause`, `test_game_settings`, `test_dev_keys`, `test_export_entry` | PASS |
| `test_scene_picker`, `_title`, `_entries` | PASS (the entries test didn't crash at exit this run) |

26 of 26 passed in one batch. The full suite was not run, and
`tests/known_failures.txt` is untouched.

`test_motif_sky.gd` checks:

- headless, nothing is built while the eye is far;
- after `flush`, each motif's art stands at its offset, its grass grows on it
  and its foot tokens are on it;
- its songbirds have their perches;
- its turf is no stone to the wheels;
- the plane lands on it by hand (a touch, braked to a stop, out, parked), and
  the pilot walks on it;
- its rope bridges are live underfoot;
- the bell spires' bell swings as the plane passes;
- the tarn's water is skimmed.

Tests updated because they pinned the old layout:

| Test | Change |
|---|---|
| `test_aqueduct_isle_sky.gd` | Checks the four motif isles (placed, apart, grown, tokens, turf read by the plane and the traffic), their plane-token sources, and gulls over the bell spires. It used to check the far isles, clusters and pierced isle. |
| `test_kit_clouds.gd` | The towers keep off the motif isles (`sky.places()`) instead of `ISLES`, `CLUSTERS` and `PIERCED`. "A tower on a motif isle is left out" replaces the cluster check. It answers "lock ring" first, since every motif is within the lock ring's keep. |
| `test_isle_teardown.gd` | Now catches a motif isle with its art partly stood (its staging tree off the tree, 23 bodies) and checks it is freed with the scene. It used to catch the pierced isle's ruins. |
| `test_rune_serpent.gd` | The pierced rock's field probes are gone. A new check: its way runs down the Sundered gorge (64 m between the halves). |
| `test_isle_lock.gd` | New: Tab by the bell spires locks onto them, shows their card and circles them clear of stone. |

**Unverified headless:** everything visual (how the four isles read in the
sky and at what distance, the grass's draw range on approach, the serpent in
the gorge), the rendered worker build path, and rendered frame costs. Ask for
a rendered look.

## Files touched in `kit_isle.gd` and `aqueduct_isle_sky.gd` (for the time-weather merge)

**`studies/kit_isle.gd`** (one area, about 30 lines):

- `toggle_lock`: the target comes from the new `lock_target(at)` hook each
  time, not a one-off `isle_circle`; the card shown is the target's
  (`_lock_card`).
- New, right after `toggle_lock`: `var _lock_card`, `func lock_target`,
  `static func lock_reaches`.
- `_show_fly_hint`: the lock's two hint lines use `_lock_card` and
  `lock_target` (the `if aloft:` block near the `LOCK_HINT` / `LOCK_OFFER`
  lines).

**`studies/aqueduct_isle_sky.gd`** (the far-isle parts out, nothing else
restructured):

| Area | Change |
|---|---|
| Header doc and preloads | The isle, cluster, pierced and cabin preloads are out; `MotifSky` is in |
| Consts | `ISLES`, `TREE_DENSITY`, `FAR_TREES`, `CLUSTERS`, `PIERCED` out; `ROUTES` rewritten (the routes keep their shape) |
| Vars | `islets`, `clusters`, `pierced`, `_making`, `isles`, `_solid`, `_palette` out; `motifs` in |
| `setup` | `on.isles` makes the motifs (`_start_motifs`) if the scene `wants_motifs`; `--no-motifs` added; life needs `motifs` |
| Removed | `_exit_tree` and `_notification` (worker waits); `_start_isles`, `_recipe`, `_advance_isles`, `_stand_isle`, `_solidify` |
| New | `_start_motifs`, `places` |
| Rewritten | `flush`, `isles_ready`, `ground` |
| `_build_traffic` | Slots and buzz from `MotifSky.places()` |
| `IsleTraffic` | Doc line only |
| `_build_life`, `_advance_life` | Doc; `_advance_life` lays out the motif isles' gull columns |
| `_build_motes` | The two nearest motif places |
| `_build_tokens` | Adds the motifs' sources |
| `_process` | The `_advance_isles` call and the pierced bump are out; life only with motifs |

**Elsewhere, likely untouched by time-weather:** `studies/aqueduct_isle.gd`
(new block "The motif isles in its sky": `wants_motifs`, `motifs`,
`lock_target`, `plane_ground`), `scripts/kit_isle/kit_clouds.gd` (`places`,
`clear_of_play`, `slots`, `blocked`, `keeps`).

## Open issues

- **Rendered path unverified.**
  - The worker build itself.
  - Whether standing a part a frame reads well (an isle appears in about 10-25
    frames of parts).
  - The frame cost with four more kit isles in view. If heavy, the next steps
    are LOD or dropping far motif isles (the audit's "drop far ones"), and
    merging each isle's static kit pieces (`RuinKit.merge`).
- **A single 69 ms part.** The tarn's mother isle stands as one node, with
  18.8k prisms in its bodies. Splitting its bodies across frames would take
  that hitch away.
- **Headless builds stall the frame they happen in** (up to 3.5 s), but only
  near the isle or with `--motifs-now`.
- **The breeze ribbons ride the home isle's ground grid.** Over a motif they
  ride at the home isle's height (30 m), so near the colonnade (48 m) they may
  pass through its ridge. A ride function over all isles' grids would fix it.
- **Tarn set-down.** The tarn's own scene refuses to set the pilot down in the
  tarn (`_turf_top`); the aqueduct scene doesn't. Out of the plane in mid-air
  over the tarn, he might be set down on the tarn's bed.
- **Gulls but no crown flock** over the motifs (no trees).
- **The motif scenes' own skies are now emptier.** They lost the far isles,
  clusters and pierced isle with the shared sky, and don't place the other
  motifs (`wants_motifs` is the aqueduct isle's only). Their traffic laps the
  four motif places, which are empty in those scenes.
- **Foot tokens and lodestones aren't saved,** as before. The lodestone and the
  shard stay the aqueduct isle's: the placed motifs have no lodestone.
- `docs/scenic/aqueduct-isle-sky.md` and `docs/scenic/rune-serpent.md` got a
  pointer to this doc. Their bodies still describe the old far isles and the
  pierced arch.
