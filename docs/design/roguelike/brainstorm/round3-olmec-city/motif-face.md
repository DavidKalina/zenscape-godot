# The Face — "He sat down to watch the dark. The dark came up to his knees and stayed."
Lenses: climb · colossal · a fragment of something bigger · sacred · an Olmec piece as terrain, not enemy
Slug: `face` (from the k3 hunch, kit-k3-climb-lanes.md / round 3: "The Face")

Pitch: You come in on a ledge of grass at the feet of a seated lord the
size of a hill, cut out of the cliff that once stood here, and his face,
high over you in the haze, is lit from below by the fires burning on his
knees. Behind your shoulder the rest of the old cliff slumps away in grassy
terraces into the dark; ahead of you, between his knees, something of his
own size is waiting in his lap.

Place: A lone colossus over the abyss: a seated Olmec lord, cross-legged,
hands on his knees, carved out of a basalt cliff of which only a ruined
ridge remains (the quarry ridge, west and behind him). He is one figure
from every side: knees, arms and shoulders round, the head huge and set a
little forward, the headdress a flat crown. The arrival is a turf ledge at
his feet, offset west so you see him three-quarter, his right side lit by
the knee fires, his left half in shadow. The eye goes: the lit knees → the
face over them → the flat crown against the void → the ridge's terraces
climbing on the left. The lap is a garden between his knees; his chest is
the relief panel (a lord carved on the lord: the kit's `city_relief`); his
shins are a facing-sheet wall, sheets of bossed stone on an earth core. The
stone is the Olmec's weathered basalt, moss on every up-face; turf on the
ledge, the lap, the left shoulder and the crown; the ridge is all land.
Broken: the ridge has fallen away from his left arm (a gulf the width of a
hop at the top), his shins' sheets are cracked, an old fire channel runs up
his right shin to a cold bowl in his lap.

Top (1 char ≈ 4 m; north up, arrival at the bottom):
```
            """"""""""""                    ~ void all round
         """"" ridge top ^""####### crown (46.4) ^ rim out (north)
        """ "  terraces  "" ##  HEAD ##
       """"  climbing    "" ##########
      """"   north-east  "####  relief ####   shoulders (27.2)
       """"""           "##  ( lap )  ##
        """"           o@##[skin wall]##@   @ the knee fires (lit)
          """"""""""""""""""""""""""""o     o the Olmec's post (east)
            """"^ rim in """""""""""""
```
Side (from the east):
```
            ____  crown 46.4 (the high terrace, rim out)
           |face|
           |    |__  collar shelf 27.2
           |relief| \__ knee fire 12.8
           |      |lap 9.6
  ridge    |skin  |
  ________ |______|____  the ledge, 0
 ~~~~~~~~~~~~~~~~~~~~~~~~  the shafts fade into the haze
```

Play:
- **The face** (clever, exposed, rich, about 90 s). Light the feed port of
  the fire channel at his shin. The flame runs up to the great bowl in his
  lap; the Olmec on the ledge's east end turns to it and climbs his shins to
  get there; the sheets peel under him and the earth slumps into a ramp. Run
  up it past him while he looks at the fire. From the lap, the relief's ten
  carved bosses up his chest to the collar shelf (in his sight once he turns
  round, 17.6 m over the lap), west onto the grassed left shoulder, then the
  hauling lip's shelves up the headdress's ear flap to the crown. Runes on
  every boss; the rare ones at the end of hard detours.
- **The ridge** (safe, slow, poor, about 150 s). West off the ledge, up the
  quarry ridge's grassy terraces (set-off steps, grabbable lips) climbing
  north and east behind him, out of the fires' light and his sight, to the
  ridge top level with his crown; one hop across the gulf to the crown's
  back. A branch at the ridge's lower terraces drops onto his left knee and
  into the lap: the bare way onto the face line without the lure.
You choose between luring him into his own lord's lap (fast, past him) and
the long dark ridge.

Threat: **the whole Olmec** (headless body wearing his head), posted at the
ledge's east end facing the void. He hunts by light and sound; the knee
fires light his face and the arrival. When he loses you above him he
climbs after you in his own lanes (the face, the skin, the shoulders) and
comes over the headdress's brim (climb_after). **The breaks**: the skin
wall (his climb peels it), the lip's cracked corner, the lap's cresset he
barges. **The void**: every edge but the ridge's back drops into it, and
his swat throws 4.5 m. As a tool: the fire channel lights the lap's bowl,
his climb to it peels the shins into the ramp.

Could combo: his landing off a peeled column throws a walker on the lap's
edge off it (9.6: a heart) or into the slope; a barged lit bowl spills on
the lap while you cross it; his inhale from the collar shelf pulls a walker
off the relief's bosses onto the lap. Ports: catches a body thrown in onto
the wide ledge; throws out off the crown's back and the knees.

Mystery: He was carved sitting, facing the dark, as if waiting for
something to come up out of it. The fires on his knees still burn; the
bowl in his lap went cold. The Olmec who walks the ledge keeps away from
him, until the bowl is lit.

Kit used: `city_relief` (the chest), `maker_skin` (the shins), `city_lip`
(the ear flap), CityFires `cresset` (great: the knees lit, the lap unlit),
`runnel` (the fire channel), the breakables hub, the headless body and
inhaler head made whole, KitLand turf islands (ledge, lap, shoulder, crown,
ridge), GroundCover grass.

Kit asks:
- The colossus himself: a seated-lord colossus piece (a sculpted mass with
  his lanes and her holds). Built here as a motif-local Blender model,
  STAND-IN for a kit piece.

Family knobs: `lure` (the channel on or off), `ridge` (how high the ridge
climbs: to the crown, or to the shoulder only), `keeper` (whole Olmec on
the ledge, or none).

Sockets: rims: in on the ledge's south edge (facing south), out on the
crown's north edge (facing north). Arenas: the ledge (14 m), the lap
(6 m). Cover: the lip's undercut. Perches: the knee daises, the ridge top.

Generator fit: role hero; footprint about 130 x 110 m; height span -70 to
50 m. Suits a tall layer: the climb is 46 m.

Distinct from: the Sunken Giant (a lying body, climbed along; here a seated
one, climbed up the front, his head the summit), the Stacked Court (a city
of pillars; here one figure and a ridge of land).

## Place (round 1)

Built as a place from the city kit and KitLand, on the underground look:
`scripts/kit_isle/greybox/gb_face.gd` (one LAYOUT table near the top) and
`scripts/kit_isle/greybox/face_colossus.gd` (the lord), registered in
`scripts/kit_isle/greybox/registry.gd` (`## world: under`). The lord's model
is `art/blender/face_colossus/colossus_build.py` →
`assets/models/face_colossus.glb`.

**Yard command.**

    godot --path . res://studies/motif_yard.tscn -- --no-title --motif=face --underground=haze
    godot --path . res://studies/motif_yard.tscn -- --no-title --motif=face --underground=torch
    python3 tools/smoke.py studies/motif_yard.tscn -- --motif=face --underground=haze
    python3 tools/drive.py scratch/face_routes.gd -- --route=ridge|face|up [--film --tag=haze] --scene-args --motif=face --underground=haze

In a layer: `studies/run_layer.tscn -- --shape=sprawl --seed=2 --knob=pool=classic --knob=greybox=face`.

**The lord.** He is made the way the Olmec is made: stacked pillow blocks of
basalt (three torso courses, a belt, shoulder blocks, arms of two blocks
hanging then laid along the thighs, block fists on the knees, crossed legs,
the shins crossed in front) on a ragged root of raw rock that drops into
the haze. His head is the inhaler head's own carving scaled ×5.8 (19.4 m
wide, 19.2 tall): the brow band and its glyph, the slot eyes, the wedge
nose, the thick lips. He leans to his right (that shoulder higher, round);
his left shoulder is cut flat and grassed. The kit's real pieces stand in
notches cut in him: the facing sheet wall between his feet, the lap's turf,
the relief as his chest (a lord carved on the lord), the hauling lip as the
back of his head, the knee daises, the crown. Changed from the card: the
first blob-sculpted lord read as a rock heap with a mushy face; the block
lord in the Olmec's own idiom reads as one figure, and it makes the Olmec
his kin.

**The land.** The ledge at his feet (KitLand, a set-off rise at its west
end), turf caps on the lap (9.6), the left shoulder and the throne's back
(27.2) and the crown (46.4), the ridge (the old cliff, slumped into four
blocks with 0.7 m cracks, lawns rising 1 m along each terrace to a 1.6 m
cliff: 10 terraces to 27.2, west and round behind him), and a lone stone in
the gulf. One island per ridge block: KitLand hangs a side toward its
island's middle, and a crescent's middle is in the gulf (it hung a rock arch
across the view).

**Routes** (both walked rim in to rim out through the real input, stick and
jump, `scratch/face_routes.gd`, haze and torch, the Olmec live):
1. **The ridge** (safe, slow, poor; 51 s for the driver): west across the
   ledge, up the ridge's ten terraces (a jump-catch each), round behind him
   onto the throne's back (27.2), the hauling lip's eleven shelves up the
   back of his head, over its cornice onto the crown, the rim. He never saw
   the walker.
2. **The face** (clever, exposed; 89 s with the lure's wait): walk up to
   the channel's feed port at the jamb post west of the skin wall (the torch
   lights it); the flame runs up the post and across the lap to the great
   bowl; go west out of his sight (the ridge's first block). The Olmec turns
   to the light, walks to his shins, lays a hand on the skin wall and climbs:
   the column peels at 35 s, he falls with it and his landing peels two
   more (3 down). Run up the slumped earth into the lap past him, up the
   relief's ten bosses (in his sight: he hunts and follows to the lap's
   edge), west across the collar onto the shoulder, up eleven bosses on the
   head's west flank (carved blocks, walker-only), onto the crown, the rim.
   Without the lure the lap has no way up for the bare moveset: the face
   line needs the Olmec.

Linger by the lit port and he spots you (driver with a 3 s delay: he
hunted, sucked, gulped and blew the walker off the ledge twice in an
earlier run; the other run he chased him to the ridge). Readable and fair:
you light it under his gaze.

**Threat.** The whole Olmec (headless body made whole with an inhaler head,
chase and chase routes on) on the ledge's south lip facing the void, his
STAND-IN beat (`Keeper_STANDIN`, gb_stacked_court's) along the ledge. The
breakables hub is his breaker: the skin wall (his climb, his landings, a
slam on the cracked column), the lip's cracked corner, the bowls (he barges
them; a lit one spills). The void all round; the skin wall's 9.6 m drop
costs a heart; the relief's top over the lap is 17.6 m.

**Real vs stand-in.**
- Real, unedited: CityBreaks2 `maker_skin`, CityLight2 `relief`, CityClimb
  `lip`, CityFires `cresset` (great: knees lit, lap cold; crown lamps on the
  collar) and `runnel`, the breakables hub, the headless body and inhaler
  head, KitLand islands and turf, GroundCover grass (also on the skin's earth
  tops, parented to each column's core so it goes when it peels).
- STAND-IN: the colossus itself (a kit piece the city lacks: a motif-local
  Blender model; it doesn't follow `--wanderer-scale`, the pieces in it do);
  the flank's bosses (walker-only boxes drawn as carved blocks, from the
  model's Hold_NN empties); the Keeper's beat.
- Not used: the hanging terrace (the seed's suggestion): the lip on the back
  of the head and the flank's bosses did the head's two ways.

**Distances changed from the card.** Knee daises 11.2 (not 12.8); the
ridge tops at the collar's 27.2 behind him (the card had it reaching the
crown), and the lip is the back of his head (the card had it as the west
ear flap: a 13–22 m coursed block on his silhouette read as a building on
his head). Lip width 15.4 (the default 22 stuck out of his head both sides).

**Rare spots** (`spots()`, kind `rare`): the lip's undercut (hidden, a true
safe room); the stone in the gulf (a 3.3–3.7 m long jump up 1.7 from the
ridge's third terrace, over the void, and back); behind the skin (in the
peeled columns' slumped earth, only once he has broken it). `rune_line`
along the ramp, the lap, every other relief boss, the collar, every third
flank boss, the crown and four ridge terraces (the poor way: few);
`rune_risk` on the east knee's dais (by a lit fire, over the void), the
collar's east end (in his reach from the lap), the ledge's east point.

**Stills** (rendered, `captures/face/`, gitignored): `arrival_haze.png`,
`arrival_torch.png`, `wide_haze.png`, `wide_torch.png`, `face_up_haze.png`,
`final_sheet.png`; the tool moment `film/{lit,climb,peel0-5,ramp}_{haze,torch}.png`,
`film/sheet_haze.png`, `film/sheet_torch.png`; the bar: `cmp_sheet.png`
(face, stacked_court and sundered_gorge from the yard's three view, haze).

**My read against the bar.** From the arrival he reads as one seated figure:
the face under the flat crown is the strongest shape, the knee fires and
collar lamps light his front, the block fists and knees give him a body, and
the void is open to his right and over him. The Olmec standing on the ledge
is plainly his kin. Against the Sundered Gorge it is still more stone than
land and statuary rather than ruin: the ridge's blocks and the ledge are the
land; he is unbroken, and the blocks are clean. In haze the figure goes to a
dark mass with the face lit; in torch the blue night flattens him more. A
dressing pass should break him (a lost fist, a cracked course, rubble on the
ledge), hang growth down his blocks, and make the ridge less regular.

**Size.** About 95 × 110 m (x -63 to 34, z -63 to 36), height -76 to 46.4;
the climb is 46.4 m. Driver crossings are 51 s and 89 s; a player will take
longer, but it is under the brief's 2–4 minutes for a strong player.

**Model budget** (docs/art/model-budget.md). The lord is 23.2k triangles
drawn (blocks ~9k, the head 14k), one draw, plus the bosses (~1k); his
collision is an 8k-triangle trimesh hull.
- Import LODs: applied (`_dressed_relief`'s `generate_lods`): past ~60 m
  he should fall to ~5k, about 18k triangles and 0.05–0.1 ms saved.
- Vertex-colour grime: applied (BVH-baked occlusion and convexity in R, G).
- Silhouette geometry: the blocks and the head's carving are the outline;
  the weathering is the stone shader's.
- Merging: the whole lord is one mesh (one draw).
- Sculpt high, bake low: the head reuses the inhaler head's sculpt,
  decimated 2:1; no normal bake (a decal like the relief's would add the
  head's fine grooves back, ~0.1 ms).
- Parallax, rigid parts: don't apply.
- Collision: a hull of boxes per block instead of the 8k trimesh would be
  cheaper for the bodies' rays; not done.

**Unverified.**
- The gulf stone's jump (geometry only; not driven), the lip's undercut and
  the behind-the-skin spot by play.
- The lure when he is already hunting (the bowl doesn't pull a hunting
  Olmec); his own climb up the flank or the lip and over the crown (the
  routes saw him follow to the lap's edge only).
- Haze vs torch headless are the same run (the sight doesn't read the
  render); both only differ in the stills.
- A layer: the face is placed and smoke-clean with `--knob=pool=classic
  --knob=greybox=face` (seed 2); `--knob=greybox=face` alone (and with
  stacked_court) fails on this base before any isle stands (run_layer.gd:238,
  `spawn.face` on an empty plan): not this motif's.
- Tests: none run or added (prototyping). New files and one registry line;
  no existing test is known to break.

## Polish (round 1)

Branch `polish/city-face`. The lord was a stepped stack of clean blocks; now he
is one seated figure who has sat in the dark for centuries.

**What changed.**
- **The lord** (`art/blender/face_colossus/colossus_build.py`, rebuilt glb):
  carved as rounded Olmec pillows (superellipsoids, a little lumpy) instead of
  coursed blocks. One trunk broadening to the shoulders. The upper arms hang
  clear of his flanks, so there is air between arm and body, with the elbows
  out. The forearms lie along his outer thighs to the hands, palms down on the
  knees' fronts with broad fingers over them. The knees are domes cut flat for
  the fire daises, and the shins cross in front. His right shoulder rides high
  and round; the left is cut flat and grassed. The head (the inhaler head's
  carving) is a little taller and bowed 5°, so he looks down at the ledge.
- **The relief** (`LAYOUT.relief.width` 24 → 15): only its carved panel is
  left, and his chest wraps it. The relief's box flanks read as a temple. The
  collar's turf now runs from the relief's top west onto the shoulder, with a
  cap east of it (`collar_e`). `collar_east` (rune_risk) moved onto that cap.
- **Broken and weathered:**
  - about 45 chips and 9 cracks on the carved masses;
  - the top of his right shoulder is sheared off and lies on the ledge by his
    right knee in its rubble;
  - a fallen knuckle by his left shin;
  - the head's east flank is pressed in (it is open shells, so no booleans
    there);
  - broken faces are paler and have no moss (B channel).
- **Growth:**
  - a moss shell on every up-face (`Moss`, `shaders/face_moss.gdshader`:
    ragged, alpha-scissored patches);
  - grass tufts in the hollows of his tops (`Tuft_NN`, laid by the Dresser
    with the ground cover);
  - 58 roots that crawl down the head's east flank, the shoulders, the arms,
    the knees and the throne's back, and hang from his rock into the abyss
    (`Roots`, a triplanar bark grain).
- **The seat's foot:** a filler under the seat and thighs, so a knocked walker
  can't end up in a crawl space under him. A filmed run ended there before.
- **The gulf stone** moved 0.7 m nearer the ridge and dropped from 6.4 to
  4.16. At 6.4 the jump was never makeable (0 of 8 tries: he hit its side).
- **`flora_site`** casts its rays down to the ledge (`LOWEST_TURF` 0), with 2.8
  tufts per m². This is the Felled Colonnade's fix: the default reach stops 8 m
  under the top.

**Stills** (`captures/face/`):
- before: `before_arrival_haze.png`, `before_arrival_torch.png`,
  `before_wide_haze.png`;
- after: `after_arrival_{haze,torch}.png`, `after_wide_{haze,torch}.png`,
  `after_face_haze.png`, `after_west_haze.png`;
- `before_after_sheet.png` (the wide camera moved nearer for "after");
- the tool moment: `film/{lit,climb,peel0-5,ramp,on_ramp}_haze.png` and
  `film/sheet_haze.png`.

**Routes, re-walked through the input** (`scratch/face_routes.gd`, haze and
torch, the Olmec live):
- **The ridge:** 51 s, 2/2.
- **The face:** about 110 s, 4/4.
  - Light the port, then wait in the knuckle's lee. He has climbed the skin
    and peeled 3–4 columns by about 40 s.
  - Wait until he's off the slumped earth, then go up a column's earth. Not
    every column's slump is a ramp; the driver tries each one.
  - Then the lap, the relief, the collar turf, the flank and the crown.
  - Waiting out in the open by the shin, he saw and sucked the walker in 4 of
    6 earlier runs. The lee is the knuckle now.
- **The gulf stone** (`scratch/face_gulf.gd`): 12/12 out from a running start
  off the ridge's terrace. Only 5/12 make it back: the return has a 2.6 m
  run-up and the same gap. Hard, but you can see both ways.
- **The Olmec over the crown** (`scratch/face_crown.gd`):
  - He is set on the throne's back, and the walker climbs the flank in his
    sight and walks out over the crown.
  - He plans after the walker, climbs his zone of the hauling lip, mantles
    over the crown's back edge at 35–37 s and leaps at the walker. Haze and
    torch, 3/3.
  - From the ledge he never followed beyond the lap's edge. From the shoulder
    he knocks the walker off the flank before it gets anywhere.

**Smoke:** yard haze and torch, stacked_court, `run_layer` sprawl/under seed 1
and ring/under seed 2: all pass, 0 errors.

**Generator:** the under plan (sprawl seed 1) keeps its isles and edges. Only
the face isles' own occupancy (the gulf stone's box) and their spots differ.
Default (sky) plans don't place the face.

**Budget** (docs/art/model-budget.md):

| Part | Triangles |
|---|---|
| Stone (one draw, LODs from `_dressed_relief`) | 26.7k |
| Moss | 5.1k |
| Roots | 8.9k |
| Her bosses | 0.7k |
| **Lord, drawn** | **41.4k** |
| Hull (trimesh, as 4 pieces) | 9.0k |

The lord was about 24k before. The motif builds in 440–810 ms (the
colossus's warm takes 36–98 ms).

- **Applied:**
  - silhouette geometry: the chips, the shear and the fallen pieces are real
    geometry on his outline;
  - vertex-colour grime: occlusion, convexity and breaks are baked;
  - import LODs on the stone;
  - decimation of the smooth masses: 0.42 collapse, about −17k triangles and
    roughly 0.05 ms.
- **Would help:**
  - a visibility range or LOD tuning on Moss and Roots: past about 80 m,
    roughly −10k triangles;
  - a hull of convex pieces instead of the trimesh, for the bodies' rays.
- **Don't apply:** sculpt high/bake low, parallax and rigid parts.

**Still rough.**
- From the arrival, the skin wall's courses and the relief's flat-topped
  collar still read a little architectural in the middle. They are kit pieces
  and unchanged.
- The ridge's first block hangs a faceted rock arch across the left of the
  arrival view. That is KitLand's hang, and the ridge is in `parts()`, so it
  wasn't touched.
- The roots are smooth tubes; up close they read a bit like cables.
- The moss is dense on the knees and forearms and thin on the shins.
- The lip's undercut and behind-the-skin rare spots haven't been driven.
