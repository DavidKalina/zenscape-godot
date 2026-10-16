# The Runaway Wheel
Lenses: verb chase (a millstone beetle chases you down its lane, then you chase its loose wheel); scale human; mood playful; shape spread wide (three isles a long flight apart).

Pitch: A millstone beetle rolls its wheel up and down a straight lane, and you lead it to the lip so a timed jump sends the wheel off alone, then learn the game on a grand beetle below whose wheel you cannot jump. Lead the grand one down its lane and sidestep: its wheel tears loose at a cut too wide to jump, jams in it and becomes the only way across.

Place: Three isles strung wide across the gulf. The Mill Head (1) is a long flat plate of turf with a causeway of floor slabs down its middle and a stepped lip on the east end; below its lip to the east hangs the Tail Race (2), a lower isle with its own lane ending in a cut. Far east the Far Stone (3) is an outlier a plane flight off, with a second loaded beetle. On arrival you see the lane laid out like a bowling alley, and the beetle already grinding along it.

Top (ASCII, 1 char about 4 m; the plane's flight from 2 to 3 is the long gap, not to scale):
```
 x: 0        10        20        30        40
        ^^^^^^^^^^^^^^^^^^^
      1 1 1111111111111111111~~~ 2222222222222~~~~~~ 3333 3
      1 L==========B======>>>>~~~ 2 G=====>>X ~~~ @ P 3 B==
      1 1 1111111111111111111~~~ 2222222222222~~~~~~ 3333
      1 ====landing turf====
```
L = the lane's west end, B = a millstone beetle, G = the grand beetle (its wheel too big to jump), X = the cut (about 4.5 m, past an unchained long jump), @ = the prayer lintel (relic_torana) the plug leads to, P = perch. The lanes are floor slabs on turf; the landing strip is the turf south of the Mill Head's lane (the bottom row), clear of it.
Side (west to east, heights above the Mill Head turf):
```
 0  ===1=======B===>lip
                      \  glide down
                       \_____ 2 -14 ==G==X(gap)==@
                                                         ...plane flight... 3 +6 turf, B
```

Play: You walk onto the Mill Head lane, the beetle ticks, and you run before it so its straight charge ends at the east lip; a jump over its wheel lets the wheel tear free and go over. You glide down to the Tail Race, where the grand beetle's wheel is taller than any jump: you lead it down its lane and step aside on the click, and its wheel tears out at the cut and jams. The plug is the only way over (the cut is wider than a long jump with no run-up); too slow or too wide a sidestep and it goes into the void. A loud, cheerful bowling game you are always slightly late for.

Set pieces:
- The lane: floor slabs a few charges long and a run wide, stone strips each side; a charge goes down it dead straight, so a step aside is a dodge.
- The lip and its drop: stepped east end whose last step is the commit mark; the first wheel leaves it and goes over alone.
- The grand beetle: a `wheel` 6 millstone (diameter about 4.8 m, nothing to jump), led to the cut and sidestepped.
- The cut: a notch 4.5 m wide (0.95 of the grand wheel's diameter; plain long jump reaches about 4.2 m, LONG_SPEED*2*sqrt(2*LONG_HEIGHT/LONG_GRAVITY)), with only a 2.4 m approach slab behind it so no run-up chains a longer jump; the wheel jams flush and he walks over it.
- The Far Stone's second lane: the same game uphill, a lip over open void, so he may be chased or fly on.

Threat: two millstone beetles (scripts/enemies/millstone_beetle.gd; the grand one with `wheel` 6) tick, tell (clicks) then charge at 1.45 of run (about 7 m/s against his 4.8); a hit knocks him hard down its lane. The loose wheel (millstone_wheel.gd) crushes while faster than its harm speed. No new trap.

Ports: takes the plane's landing on the Mill Head and the Far Stone; throws the pilot down the lip by glide. The Tail Race has no landing of its own and is a hop, not a stay.

Kit used: floor (RuinKit "floor" slabs for the lanes), stairs (the lip's steps), aqueduct_end (the lane's blunt end), relic_torana (the lintel at the plug's end; ruin_kit_torana.gd, listed "Prayer lintel"), stone_circle (a ring round the Far Stone's turf strip, existing in gothic), the millstone beetle and its wheel. Rope bridges are not used.

Kit asks: a "cut" piece (a notch in a floor-slab lane, width and approach length as parameters, clean edges each side) so the jam gap is authored, 0.95 of the wheel and wider than the pilot's long jump reach, with an approach too short to chain.

Family knobs: lane length (3 to 5 charges), lip drop (10 to 16 m), the cut's width (0.9 to 0.95 of the grand wheel, always over the long jump's reach), the Far Stone's lip open or walled.

Sockets: rim the Mill Head's east lip (facing east); arena the lane (Mill Head, then Tail Race); cover none (it is a flat open); perch the Tail Race's far end and the Far Stone's turf strip.

Fit: role "peak" with a satellite; footprint about 60 m by 24 m (Mill Head) plus 40 m by 20 m (Tail Race) and a far outlier about 190 m east; height span about 20 m (the drop plus the Far Stone's rise).

Distinct from: noon_weir (gb_noon_weir.gd) is three stacked sluice channels on one clock with a plinth ram and a cannon out, climbed and timed; this is a flat bowling lane where a beetle's loose wheel becomes the bridge, and the Oilbird Stairs has a hunter you hide from, not a lead you turn on its own prop.

Layout:
```json
{
  "isles": [
    {"id": "1", "name": "Mill Head", "x": 0, "z": 0, "rx": 34, "rz": 12, "top": 0, "keel": -12, "set_piece": "lane"},
    {"id": "2", "name": "Tail Race", "x": 58, "z": 4, "rx": 22, "rz": 9, "top": -14, "keel": -24, "set_piece": "cut"},
    {"id": "3", "name": "Far Stone", "x": 170, "z": -6, "rx": 26, "rz": 11, "top": 6, "keel": -10, "set_piece": "second lane"}
  ],
  "links": [{"from": "1", "to": "2", "kind": "stones"}],
  "pilot": [[-26, 0.5, 0], [-8, 0.5, 0], [22, 0.5, 0], [34, -4, 2], [52, -13, 4], [74, -13, 4], [80, -12, 4]],
  "threat": [[-4, 0.5, 0], [30, 0.5, 0], [44, -4, 3], [56, -13, 4], [70, -13, 4]],
  "tips": [[22, 0.5, 0]],
  "landing": [-30, 5, -2, 10],
  "end": [80, -12, 4],
  "moments": [
    {"at": [-8, 0.5, 0], "label": "The tick", "note": "The beetle halts on its lane, head up, and ticks three times; you are in its line and it is a whole lane from the lip."},
    {"at": [22, 0.5, 0], "label": "The jump", "note": "Run it to the lip, jump the wheel on the commit; the beetle brakes blind and the wheel tears out of its grip."},
    {"at": [40, -4, 3], "label": "Down the lip", "note": "The first wheel goes over; you sail down after it to the Tail Race, where the grand beetle waits."},
    {"at": [66, -13, 4], "label": "The plug", "note": "The grand wheel tears out at the cut and jams flush; you cross it to the lintel. The cut is 4.5 m wide and cannot be jumped."},
    {"at": [170, 6, -6], "label": "The Far Stone", "note": "A plane flight east, the same lane turned uphill with a lip over open void; a second beetle, a second wheel."}
  ],
  "notes": [
    {"at": [-17, 0.5, 0], "text": "landing strip west, turf south of the lane"},
    {"at": [66, -13, 4], "text": "cut 4.5 m, over the long-jump reach (about 4.2 m), approach only 2.4 m"},
    {"at": [160, 6, -6], "text": "landing strip east"}
  ]
}
```
