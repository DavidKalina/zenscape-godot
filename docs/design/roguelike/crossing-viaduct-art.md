# Broken Viaduct: art pass (sky isles, kit stone over the greybox)

Branch `feature/viaduct-art`, cut from `feature/viaduct-polish` (0ffc13f4). Not merged.
This round changes the look only. Every walk top keeps its exact clean collision: the
same heights, edges, gaps and lips.

## Run it

    ./run-crossing-yard.command                 # windowed (live weather: autumn turf in October)
    ./run-crossing-yard.command --look=alpine_morning   # a summer look, green turf

## What each greybox piece became

The crossing's greybox helpers (`box`, `column`, `slab`) now draw nothing (colour `""`).
Each walk keeps its box, and kit stone or a sky isle is drawn over it. The kit pieces are
built with `piece(..., false)`, which drops their hulls, so only the clean box collides.

| Was | Now (collision unchanged) |
|---|---|
| Start rim pad (12×12 column to -26) | **StartIsle**: a sky isle with turf, flora and a keel 15 m deep. The kit `floor_slabs` are laid as an apron where the deck begins. Its walk is a 2.2 m box (`TOP_SOLID`) under the same top. |
| Run-up deck, far deck | Already real aqueduct spans. Each of their 6 pier feet (at -26) now stands on a **clod**: a little isle of turf and rock. |
| Turn platform (grey column) | **TurnIsle**: turf, with two kit floors where the route crosses, and a 10 m keel. |
| 10 piers (orange lip-capped columns) | `RuinKitAqueduct.pillar` coursed piers, drawn only, over the exact columns. Each is sized so its impost's top and edge are the column's top and edge. Their feet stand on 4 clods, in runs of 3/3/2/2. The orange lip caps are gone: the impost reads as the ledge. |
| Safe stair supports ("wall"/"grey" columns to -26) | Kit pillars under each flight and rest. They are now 7-9.5 m (flights) and 4.2 m (rests) deep, broken off over the sky with ivy, so the crumbling stair hangs. The flights are the same kit `stairs`. |
| Chimney plinth (grey 9.2 m column) | **PlinthIsle**: turf, four kit floors under the tower, and a 12 m keel. |
| Launch slab ("lane") | A fallen run of deck masonry (`ViaductArt.slab_stone`): worn blocks two across and about 1.15 m long, with staggered joints, settled 1.5-5 cm under the true walk, ivy under it. |
| Slab's flat lip | The same masonry on a broken kit pillar. That pillar now reaches 13 m under the lip, not to -26, broken off. |
| Far rim (orange lip-capped column) | **FarIsle**: turf, flora and a 15 m keel. Two broken gothic piers (`RuinKit.pier`, weathered 0.55, colliding as built) stand at its back corners as a gate's remains. |

The chimney (the real `RuinKitTower`), the horns and the perch pillars are unchanged.

## The isles and what they reuse

- **New file: `studies/crossings/viaduct_art.gd`.**
  - `isle(ring, top, depth, ...)` is the kit isles' own land builder, `KitLand`:
    - `Gather` + `grid` + `surface`: the plate's turf (`KitLook.turf`, worn bare under the floors);
    - `ring_sides`: the islets' hanging rock and keel, as the aqueduct isle's islands have.
  - Its outlines come from `rect_ring`: the walk box with the corners cut 0.9 m and a slow
    noise wander of up to 0.32 m. The wander only ever goes inward, so the drawn turf never
    overhangs the collision.
  - The keel collides as one convex hull, starting 2.2 m under the top, inside the drawn
    rock, so a glide under an isle meets rock.
  - Clods are the same builder on `blob_ring` outlines. They collide whole, top included.
    They sit 26 m under the start rim.
- **Flora:** `crossing_yard.gd _grow` now grows `KitFlora` grass and flowers on the
  crossing's isles. It uses the crossing's `flora_turf` / `flora_outlines` / `flora_wear`:
  718 tufts and a few flowers, grown in about 0.2 s.
- **The turf is orange-gold in the default run.** That is the live weather's autumn, the
  same as every kit isle in October. `--look=alpine_morning` shows it green.
- **Updrafts:** none moved. The isles stay clear of their columns: the start isle's edge is
  the start updraft's edge, as the pad's was. The clods hang 26 m under the walks, well off
  the updraft columns.
- **Cost:**
  - The piers' and stair's kit stone is built with its ivy and moss thinned
    (`COLUMN_DETAIL` 0.45 through `RuinKit.set_detail`, restored after; the stone is the
    same).
  - Drawn triangles: 351k before, 545k now. Bodies: 251 before, 273 now. Shapes: 2900
    before, 3005 now.
  - Time to walk-ready (headless): about 4.9 s before, 6.3 s now.

## Verified

- Import is clean. The yard loads for 300 frames headless with no script errors.
- `tests/test_crossing_viaduct.gd`: 0 failures in its own output. The runner flags only the
  existing exit leak.
- The same runs of the sibling tests match the polish round:
  - arrows: 0 failures;
  - perches: 0 failures;
  - heights: the same 3 known failures listed in crossing-viaduct-polish.md.
- **Throwaway walk-top check** (`captures/viaduct_art/rays.gd`, uncommitted): straight-down
  rays on a 0.25 m grid over the whole crossing (170,841 columns), old build against new,
  with the first hit on the crossing's own bodies. Every walk top matches within 2 cm: rims,
  deck, piers, stair, plinth, slab, lip and far rim. The only differences:
  - 175 columns lying exactly on the start rim box's edge lines (x ±6, z 0, z 12), a ray
    grazing the edge;
  - the two gate piers and their rubble at the far rim's back corners (new, colliding);
  - the clods 26 m down.
- Not checked: feel at human timing, and whether the dropped orange lip caps make the
  piers harder to read in play.

## Captures

Windowed (forward_plus, `-- --no-title`), driven by the throwaway
`captures/viaduct_art/shots.gd` with the study's own camera (the kit isle's `--at` way). They
are in `captures/viaduct_art/` in the worktree (gitignored):

- `final_0_play_start.png`: the play camera on the start isle;
- `final_1_start_up_climb.png`: from behind the start rim, up the climb;
- `final_2_piers.png`: off pier 1 toward the stair and tower;
- `final_3_below_glide.png`, `final_3b_below_start.png`: from below, the clods and keels;
- `final_4_chimney_launch.png`: the tower, the fallen slab and its lip;
- `final_5_far_rim.png`: the far isle and its gate stumps;
- `final_6_wide.png`, `final_7_wide_right.png`: the whole crossing over the cloud sea.

`base_*` are the greybox before this round.

## Open

- The islets' rock is the kit isles' faceted basalt. Shaded, it reads very dark (navy).
  That is the shared `KitLook` rock, not changed here.
- The perches' pillars still end in their own broken feet (no clods).
- The safe stair's broken supports leave the flights hanging over 20 m of open air under
  them. That reads as a ruin, but it is a change from the old full-height columns.
