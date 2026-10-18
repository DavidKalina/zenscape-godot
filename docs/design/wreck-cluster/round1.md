# Wreck cluster, round 1

The run's start as its own study: the plane parked broken on a cluster of four land masses, its six parts dealt to random spots, and a re-deal key. It doesn't touch the aqueduct isle.

**Launch** `./run-wreck-cluster.command [--seed=N]`, or `godot --path . res://studies/wreck_cluster.tscn -- --no-title [--seed=N]`. You start beside the plane.

**Keys.** **N** re-deals: the plane goes back on its spot, broken, every part comes off it, and the parts are dealt to fresh spots from a new seed (the seed is printed and shown). It works on foot and in the plane, and the pause menu (Esc) has *New deal* under *Back to the plane*. The hint line shows the key. R puts you back at the start. Z is the stand-in wind blast at the knight (dev key), and Q (RB) parries. F4 opens the world view (dev key).

**Masses** (`studies/wreck_cluster_art.gd`, turf at y 30):
- **main**: the plane at the west end facing east, with a clear strip of about 75 m to the east rim (`longest_run` 90). Behind it are a broken wall, a pier and a fallen pier. On the north side, tier A is 1.6 up (a plain jump-catch) and tier B 2.2 up on it (a chained catch). A flat air ring over tier A throws you up to a floating perch. There is also a broken wall at mid-isle.
- **spire** (NE): a jump-catch onto its landing (1.95 m gap, 1.2 up), then a 1.6 crag up to the plateau. A 9 m tower shell stands there: go in at the door and kick up the shaft to the coping. Its keel is 60 m deep.
- **rope islet** (W): 4.85 m of sky off the main, with a swing-rope frame on each side for there and back.
- **knight islet** (SE): a 2 m hop onto a 2.8 m wide causeway, which is the rune knight's deck, then the islet with a carved chest.

**Spot pool**: 17 spots, `wreck_cluster/part_spot_01`..`17`, in the order of `Art.spots()`. Main has 01-07: by the plane, tier A, tier B, wall top, perch, east rim, south rim. Spire has 08-11: landing, before the door, behind the tower, coping. The rope islet has 12-14: middle, wall top, far lip. The knight islet has 15-17: causeway, behind him, chest top. A deal puts at most 2 parts on one mass. A re-deal avoids the last deal's spots. Each spot is settled at deal time: a ray down onto stone or turf, with the part 0.85 m above it and raised clear of stone. A spot that doesn't settle is skipped. In F4 the spots show as orange discs with their names. Move one, save, then press N to deal onto the new spots.

**Flags**: `--seed=N`, `--no-rune-knight`, `--plane-fixed`, `--parts-carried`, `--part-at=<id>`, and the kit isle's flags (`--no-flora`, `--no-life`, `--no-sky`, `--fly`, ...). The layout file is `layouts/wreck_cluster.json`, written only by the world view's save.

**Saves**: the ledger is memory-only while the scene runs, unless you pass `--ledger=`, and it's restored on exit. The parts never write to it (`scripts/plane_arc/wreck_arc.gd`, `keep` false).

**Code**: `studies/wreck_cluster.gd` (kit isle subclass: the deal, re-deal, knight, pause row, world view), `studies/wreck_cluster_art.gd` (numbers, outlines, pieces, spots), `studies/wreck_cluster_sky.gd` (the aqueduct sky without isles, airships, biplanes, serpent or plane tokens), `scripts/plane_arc/wreck_arc.gd` (plane_arc with parts laid at given points).

**Proved** (throwaway drivers in scratch/, real input): seeds 11 and 12 deal different spots, all on ground, and seed 11 repeats. Walked to a part, took it, Space at the plane fitted it. N breaks the plane again, parks it, moves every part and reforms the knight. Routes up the tiers, onto the spire and in at the door, and over the causeway all walked. The air ring reaches the perch. The rope carries you both ways on a run-in swing (releases at 40-58 frames out, 34-58 back). The knight teeters at the causeway's lip and goes over on a second hit. With all six fitted, it rolls off the east rim flying. The smoke check passes.

**Rough**: the turf reads orange in the morning look. The spire reads small from far off, since the tower is 9 m against a 98 m main. Spot heights for wall tops depend on how worn the wall is. Island moves from F4 don't move the plane's coded home (`plane_home` is fixed). The knight is the aqueduct's mind, tuned for a 1.25 m deck. The wall-kick in the tower wasn't driven here (the tower shell study covers it). The parts' pop and hint texts are the plane arc's.

**Harness**: nothing missing. A swing-rope helper for drivers (catch, pump, release at a timing) would have saved the hand-rolled loop.
