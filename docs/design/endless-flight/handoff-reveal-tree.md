# Handoff: the golden tree (reveal finds, tree lane)

**What's built.** `scripts/endless/golden_trees.gd` adds three gold spruces to the wilderness. Each one replaces a real land tree, which is removed with `LandTrees.knock`, and stands on its own node. It uses the mature spruce mesh, made 1.2x taller and 1.2x wider, with a gilt material. Gold glints drift up from it, and its glow and a small lamp come up as daylight goes. Each tree is built when the eye comes within 1500 m and freed past 1800 m. The hit test runs only within 80 m of the plane.

- **Surge roll into it.** It falls: hit-stop, kick, snap, gold leaves, and a rod-on-its-foot fall that thuds and bounces twice. It then stays down. `book.open_up("golden/<id>")` saves the fall at once. At the thud the tree hands `finds.anchor("golden/<id>", foot)`, and a ring appears 9 m over the stump.
- **Plain hit.** The plane pays what any tree costs: TreeKnock's speed loss, shove, yaw and lost chain. The gold tree sways and stays up. I chose this over letting it fall like any tree because a plain fall would make the roll pointless or lose the find.
- **On load.** A tree marked down lies where it stood, but its fall direction is seeded, not the one it fell. Its anchor is handed at setup, so a ring not yet flown is still there.

**Where they stand** (world XZ, seed 1):
- `gold-spruce` (358.2, -310.3): a dense valley wood about 470 m NE of the start, area meadow.
- `gold-grove` (-1131.3, 2852.5): a grove in the south meadows by the gap, area south.
- `gold-shore` (2791.8, 932.2): the dense wood on the east hills past the arch run, area coast.

**See one fast.** `./run-endless-flight.command --heading=49 --full-meter` flies straight at `gold-spruce`. Press the surge (or the roll button on a full meter) about 70 m out.

**Open.**
- Nobody has played it by hand yet.
- The reload lies the tree in a seeded direction. The fall's real direction isn't kept, because the book's `opened` only holds a flight number.
- The ring at `up` 9 sits over the stump, and the lying trunk runs out under one side of it.
- The glint and leaf particles are plain unshaded quads.
- Off the chase camera (stills from the harness eye), near trees show bare dark trunks. Their crowns are probably tied to the game eye. This isn't from this change, and I didn't check it.
- With the unweighted preset (`--weight=off`) there is no surge roll, so the tree can't be felled. The gold tree has no flight solid either: the plane passes through it and pays only the plain hit's toll, where a green tree would be a solid. I didn't check this case.
