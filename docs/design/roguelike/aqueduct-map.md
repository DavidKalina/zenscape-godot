# Aqueduct isle map (2D, for placing roguelike content)

Read docs/design/roguelike/concept.md for why. This is a reference map of the
authored aqueduct isle ("The Aqueduct of Veyl") at the **default sizes**
(plane 2.0, walker 1.0, opening ratio 1.0; scripts/world_scale.gd). Every
number below was worked out from the source at those defaults; "~" marks an
approximation. Nothing here was measured by running Godot.

Frame: **x east (+), z south (+), north is -z, y up.** The island tops are
**y 30**; "h" below means metres above y 30 unless a world y is given. The
aqueduct runs along **x = 100**, its head (south end) near z -2 and its far
end near z -72, so the run goes **north (-z)**. In the art file's aqueduct
frame, "aqueduct x" = -z (world z = -aqueduct x).

Doc/code drift to know about: several comments in studies/aqueduct_isle_art.gd
still quote the old ratio 0.9 numbers (clear 7.2, deck 9.2, 6.0 m sarsens).
At the defaults the code gives clear 8.0, crown 8.0, deck 10.0, pier module
10.0, sarsen 6.8 (studies/aqueduct_isle_art.gd:50-64, scripts/ruin_kit.gd:213-214).

## 1. Plan view

### 1a. Whole isle, 1 cell = 2 m (x) by 4 m (z)

Row label = z of the row's top edge (the row covers z to z+4). Column ticks
are x in metres, labelled every 20 m. Tokens and the pad of the parked plane
are not drawn (token positions are in the table, the plane's home is decided
at runtime). The ferry `F` is drawn only where it is over open sky; on land it
is hidden under the turf (it runs x 110, z -36.3 to -67.9).

```
            40        60        80        100       120
            |         |         |         |         |         
 -104                                    ::                   
 -100                                 :..AA..::               
  -96                               ::.........::             
  -92                              :.....dd......             
  -88                              ......dd......:            
  -84                             :......dd......:            
  -80                              ......dd......:            
  -76                              :.....dd.....:             
  -72                               ::...==...::              
  -68                                uu::==::R F              
  -64                                uu  ==    F              
  -60                                uu  XX    F              
  -56                                uu  XX    F              
  -52                                uu  ==    F              
  -48                                uu  ==  R F              
  -44                                uu  ==    F              
  -40                                uu :==::  F              
  -36                                uu..==...::              
  -32                              :.....==..R..::            
  -28              ::::::::::    ::......==.......::          
  -24           ::.......................==.........::        
  -20         :....r111..................WW...........:       
  -16       :..rrrr221111111.............WW............       
  -12      :.rrr222^oo^oo^11DDDD.........WWBB..........:  III 
   -8      .2222^oo^^^^^^^ooDDDDDDDDD....WWBB.........eEL III 
   -4 IIIIwww222^oo^^^^^^^oo^1GGGGGDDDDC+WW.......HH...:  bbb 
    0 IIIIwww222^oo^^^^^^^oo^1GGGGGGG.CCCss.......HH...:bbb   
    4      :22222oo^^^^^^^ooff1..........ss...........: bb    
    8      :..21222^oo^fllff111..........ss.........::        
   12        :..111kkk2ffff111...........SS......:::          
   16         ::...kkk...11.....:::::   :SS                   
   20            ::........:::                                
   24                                                         ```

Legend, grid 1a and 1b:

| Char | Meaning |
|---|---|
| ` ` (space) | open sky (nothing there; falling) |
| `.` | meadow turf at island top, h 0 (to ~2.9) |
| `:` | island rim cell (edge of the turf; a drop to the sky) |
| `1` | hill lower tier T1, h 4.48 (grand stair head, round E, S, N of the hill) |
| `r` | the hill's ramp, h 4.5 to 8.7, climbing from polar 100 deg to 160 deg |
| `2` | hill upper tier T2 (west shelf and south ledge), h 8.68 |
| `^` | summit crag, h ~10.7 (summit plane, tilted 3 deg down to the east) |
| `o` | stone circle (henge) sarsen, 7 standing; `m` the 8th, gone, now a floating stone |
| `l` | the bite's fallen lintel (floating, over the notch cut in the crag) |
| `s` | rubble slope, 30 deg, up onto the aqueduct head (z +15.3 to -2) |
| `W` | blind wall: deck on top (z -2 to -22), two walled-up arches below |
| `=` | aqueduct deck over open arches (channel floor, h 10.0) |
| `X` | the fallen span gap (3 m, z -54.5 to -57.5), open sky |
| `d` | far-end drops: eight 1.2 m steps down to the far island, z -72 to -91.2 |
| `B` | buttress east of the blind wall (x 103.8-104.8, z -12 to -6, top h 9.2) |
| `C` | castellum (water tower + its broken steps, x 93-97) |
| `+` | the kick block in the wall-kick slot between castellum and blind wall |
| `G` | grand stair (balustrades on both cheeks), x 77.5-89.7, climbs west |
| `k` | kit stair up the crag (south-south-west side of the hill) |
| `f` | "south" floating-stone chain (4 stones, lower tier up round the crag) |
| `D` | "drift" floating stones (6, summit north-east edge to castellum crown) |
| `w` | west_1 floating stone (west shelf to the west islet) |
| `I` | an islet: west islet (centre 32, -0.5) and east islet (135, -8) |
| `e` `E` `L` | east_0, east_1 floating stones; `L` the lodestone's stone spot |
| `b` | the three bobbing slabs (rim to east islet) |
| `u` | the five stepping stumps (x 92, run from near tip to far island) |
| `R` | the three swing-rope anchors at x 106.3 (beams reach in from the aqueduct) |
| `F` | the drift slab's (ferry) path over sky, x 110 |
| `H` | heel stone (118, 0) |
| `S` | spawn (100, 15.9) |
| `A` | gate arch on the far island |

Edges: a change between the digits/`.`/`^` characters on the hill is a cliff
(or the grand stair / ramp); exact heights in grid 1b. Hill ring radii in
section 6.

Notes on where it is lossy: at 2 m x 4 m the 2.4 m wide aqueduct is drawn 2
cells wide; the `I` islet cells over-draw by about half a cell; the whole
hill is drawn from its centre sampling so tiers wobble by up to a cell. Use
grid 2 (1 m x 2 m) for the aqueduct head, castellum and spawn area.

### 1b. Height bands, same grid

Each cell: whole metres above y 30 of the ground or the top of the feature in
that cell (0 to 9), then `A`=10, `B`=11, `C`=12 ... `I`=18. Features show their top
(deck `A` = 10, castellum `B`, circle sarsens and lintels `I` = 18 above y 30 = world ~48,
south-chain stones 6, drift stones `B`). Slope `s` cells show the slope's
height at that row. Islets show their top (west 8.9, east 1.9).
Overlapping cells show the max/last feature.

```
            40        60        80        100       120
            |         |         |         |         |         
 -104                                    00                   
 -100                                 000550000               
  -96                               0000000000000             
  -92                              000000AA000000             
  -88                              000000AA0000000            
  -84                             0000000AA0000000            
  -80                              000000AA0000000            
  -76                              000000AA000000             
  -72                               00000AA00000              
  -68                                0000AA00A                
  -64                                00  AA                   
  -60                                00  00                   
  -56                                00  00                   
  -52                                00  AA                   
  -48                                00  AA  A                
  -44                                00  AA                   
  -40                                00 0AA00                 
  -36                                0000AA00000              
  -32                              000000AA00A0000            
  -28              0000000000    00000000AA000000000          
  -24           0000000000000000000000000AA00000000000        
  -20         000013322100000000000000000AA000000111000       
  -16       00345667754443221100000000000AA000000000000    1  
  -12      005777899II9II875BBBB000000000AA9900000000000 11111
   -8  88  048889IIBBBBBBBIIBBBBBBBBB0000AA9900000000001211111
   -4 8888888888AIIBBBBBBBIIB544444BBBBB6AA0000000220000  111 
    0 8888888888AIIBBBBBBBIIA544444440BBB770000000220000000   
    4      048889IIBBBBB9BII662000000000055000000000000 00    
    8      00366689AIIB6II6644200000000003300000000000        
   12        001245BBB766664430000000000000000000000          
   16         00000BBB111221000000000   000                   
   20            0000000000000                                
   24                                                         
```

### 2. Zoom: aqueduct head, spawn and castellum, 1 cell = 1 m (x) by 2 m (z)

Same legend. The aqueduct reads 4 cells wide here because its 2.4 m channel
plus cell overlap rounds up; true width is x 98.8-101.2.

```
            90        100       110       120
            |         |         |         |   
  -32     :.........====...........:          
  -30   :...........====....R........:        
  -28  :............====...............:      
  -26 :.............====.................:    
  -24 ..............====...................:  
  -22 ..............WWWW....................::
  -20 ..............WWWW......................
  -18 ..............WWWW......................
  -16 ..............WWWW......................
  -14 ..............WWWW......................
  -12 ..............WWWW.BB...................
  -10 ..............WWWW.BB...................
   -8 DD............WWWW.BB...................
   -6 DD.DD.........WWWW......................
   -4 GGGDDGDDDCCC++WWWW......................
   -2 GGGGGG...CCCC.ssss...............HH.....
    0 GGGGGG...CCCC.ssss...............HH.....
    2 GGGGGG........ssss......................
    4 ..............ssss......................
    6 ..............ssss......................
    8 ..............ssss.....................:
   10 ..............ssss...................:  
   12 ..............ssss.................:    
   14 ..............sSSs...:::.....::::       
   16 ...:::::   ::::SS::                     
   18                                         ```

Height bands for the zoom (same rules as 1b):

```
            90        100       110       120
            |         |         |         |   
  -32     0000000000AAAA000000000000          
  -30   000000000000AAAA0000A000000000        
  -28  0000000000000AAAA0000000000000000      
  -26 00000000000000AAAA000000000000000000    
  -24 00000000000000AAAA00000000000000000000  
  -22 00000000000000AAAA0000000000000000000000
  -20 00000000000000AAAA0000000000000011000000
  -18 00000000000000AAAA0000000000000111100000
  -16 00000000000000AAAA0000000000000011000000
  -14 00000000000000AAAA0000000000000000000000
  -12 00000000000000AAAA0990000000000000000000
  -10 00000000000000AAAA0990000000000000000000
   -8 BB000000000000AAAA0990000000000000000000
   -6 BB0BB000000000AAAA0000000000000000000000
   -4 444BB4BBBBBB66AAAA0000000000000000000000
   -2 444444000BBBB099990000000000000002200000
    0 444444000BBBB088880000000000000002200000
    2 4444440000000077770000000000000000000000
    4 0000000000000055550000000000000000000000
    6 0000000000000044440000000000000000000000
    8 0000000000000033330000000000000000000000
   10 00000000000000222200000000000000000000  
   12 000000000000001111000000000000000000    
   14 000000000000000000000000000000000       
   16 00000000   00000000                     
   18                                         
```

Heights for the zoom (second panel above): the castellum crown `B` is 11.8; its
steps east of it fall 10.2 (`B`/`A`), 8.7 ... 1.4 as they run south (z -3 to
10.6); the kick block `+` is 1.4; spawn is 0.

## 3. Elevation profiles

### 3a. Along the aqueduct (x = 100), south (left) to north (right), 1 char = 2 m in z

Rows are y; each row covers y to y+2 (row `28` = y 28 to 30 = just under the
island top). Cells: `~` island body (the keel hangs about 30 m under the near
island and 20 m under the far one, tapering; the profile is approximate),
`/` rubble slope, `W` blind wall, `=` deck slab (top y 40), `#` pier or spandrel
stone, `d` the far-end drops. Piers hang in the sky with broken feet.

```
 50                                                               
 48                                                               
 46                                                               
 44                                                               
 42                                                               
 40                                                               
 38         //===================================dd               
 36        ///WWWWWWWWWW#########################dddd             
 34      /////WWWWWWWWWW    #    #    #    #    #ddddd            
 32    ///////WWWWWWWWWW    #    #    #    #    #dddddddd         
 30  /////////WWWWWWWWWW    #    #    #    #    #dddddddddd       
 28 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#    #    #  ~~~~~~~~~~~~~~~~~~  
 26  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~#    #    #   ~~~~~~~~~~~~~~~~   
 24  ~~~~~~~~~~~~~~~~~~~~~~~~~~~ #    #    #   ~~~~~~~~~~~~~~~~   
 22   ~~~~~~~~~~~~~~~~~~~~~~~~~  #    #    #    ~~~~~~~~~~~~~~    
 20    ~~~~~~~~~~~~~~~~~~~~~~~   #    #    #     ~~~~~~~~~~~~     
 18     ~~~~~~~~~~~~~~~~~~~~~~   #    #    #      ~~~~~~~~~~      
 16      ~~~~~~~~~~~~~~~~~~~~    #    #    #       ~~~~~~~~       
 14       ~~~~~~~~~~~~~~~~~~     #    #    #        ~~~~~~        
 12        ~~~~~~~~~~~~~~~~           #    #         ~~~~         
 10         ~~~~~~~~~~~~~~            #               ~~          
  8          ~~~~~~~~~~~                                          
             |         |         |         |         |         |  
             0         -20       -40       -60       -80       -100       
```

Read it with these numbers (aqueduct x = -z; all at the defaults):

| Thing | z (world) | y |
|---|---|---|
| Rubble slope foot / top | +15.3 / -2.0 | 30 / 40 (30 deg) |
| Blind wall (2 walled arches, piers at z -11, -21) | -2 to -22 | deck 40 |
| Open arch 2 (over near island) | -22 to -30 | crown 38, springing ~32.3 |
| Pier 31 (stands on the near island) | -30 to -32 | foot 30 |
| Open arch 3 (over the island's north tip) | -32 to -40 | crown 38 |
| Pier 41 (hangs; foot y 15) | -40 to -42 | 15 to 40 |
| Open arch 4 (over sky) | -42 to -50 | crown 38 |
| Pier 51 (hangs; foot y ~11.7) | -50 to -52 | 11.7 to 40 |
| Fallen arch 5: springers stand on piers 51 and 61, the arch is open at the top | -52 to -60 | stubs: south deck stub top 40 ends z -54.5, north stub starts z -57.5 |
| **The gap** (snapped channel) | **-54.5 to -57.5** | deck missing, 3.0 m |
| Pier 61 (hangs; foot y ~13.3) | -60 to -62 | 13.3 to 40 |
| Open arch 6 (over far island's near edge; island starts z -66) | -62 to -70 | crown 38 |
| Pier 71 (on the far island) and deck end | -70 to -72 | foot 30, END z -72 |
| Drops (8 steps, 2.4 m long, 1.2 m each) | -72 to -91.2 | 38.8 down to 30.4 |
| Gate arch on far island | (100, -96.9) | on turf |

Walker-scale facts for the profile: channel clear width is x 99.25-100.75
(parapets 0.42 m high at +-0.95); the walker walks the channel, and under the
open arches over turf (arches 2 and 3; clear 8 m wide, crown 8 m high).

### 3b. East-west cut at z = 0, x 28 to 140, 1 char = 2 m in x

`I` west islet (top 38.9), `w` west_1, `2` west shelf, `^` summit (~40.7),
`-` stone-circle lintel row (world y ~47-48.4), `1` lower tier,
`G` grand stair (h 0 to 4.48, climbs west), `C`/`c` castellum (crown 11.8 at
x 93-95; its steps from 10.2 down to 8.7 at z 0), `s` rubble slope at z 0
(h ~8.9), `H` heel stone (top 2.3). Row label is y. The cut is at z 0 so
the circle's sarsens (which stand at z +-3.7 and +-8.8) are not on it; the
lintel row is over the ring's centre line for scale only.

```
 50                                                          
 48             ---------                                    
 46             ---------                                    
 44                                                          
 42                                                          
 40           ^^^^^^^^^^^^^         CC                       
 38 IIIIwww222^^^^^^^^^^^^^         Cccss                    
 36 IIII  2222^^^^^^^^^^^^^         Cccss                    
 34 IIII  2222^^^^^^^^^^^^^1G       Cccss                    
 32 IIII  2222^^^^^^^^^^^^^1GGGG    Cccss       HH           
 30 IIII  2222^^^^^^^^^^^^^1GGGGGGG Cccss       HH           
 28      ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~       
          |         |         |         |         |         |   
          40        60        80        100       120       140           
```

## 4. Feature table

Source keys: ART = studies/aqueduct_isle_art.gd, ISLE = studies/aqueduct_isle.gd,
FOOT = scripts/interactables/aqueduct_foot_route.gd, KIT = scripts/ruin_kit.gd,
TOK = studies/aqueduct_isle_tokens.gd, AQ = scripts/ruin_kit_aqueduct.gd.
"h" = height of the walkable top above y 30 (world y = 30 + h). Verbs: walk,
jump, grab (ledge), kick (wall-kick), wallrun, slide (rail/slope), swing
(rope), ride (moving slab), twirl (twirled jump).

### Landmasses

| Name | Position (x, y, z) | Size | h | Walker can | Source |
|---|---|---|---|---|---|
| Near island | x 37-128, z -40.4 (tip at x 100; -35 to -38 elsewhere) to +24.6; top y 30 | ~90 x 65 m, keel ~30 m | 0 (hill to ~11) | walk; rim is a drop | ART:803-821 (NEAR), :38 |
| Far island | x 85-116, z -66 to -101.6; top y 30 | ~31 x 36 m, keel ~20 m | 0 (rise 1.6 at 108,-90.8) | walk | ART:810-812, :802 |
| Sky gap between them | x 100: z -40.4 to -66.0 (25.6 m); at the rope line x 106.3: rim -37.1 to -67.3 (30.2 m) | | | cross by rope, ferry, stumps, aqueduct deck, glide | FOOT:5-9,:47 |
| West islet | centre (32, 38.9, -0.5), r 3.6 | disc, keel 7 m | 8.9 | walk | ART:1056,:1058 |
| East islet | centre (135, 31.9, -8), r 4.0 | disc, keel 7 m | 1.9 | walk | ART:1057,:1059 |
| Grassy rises | (117,-17) r6; (108,11) r4; (108,-90.8) r5 | smooth bumps | +1.6 each | walk | ART:873 |

### The hill (west lobe), centre HILL = (61, 0)

| Name | Position | Size | h | Walker can | Source |
|---|---|---|---|---|---|
| Lower tier T1 | ring r ~12 to 16-21 round the east, south, north of the hill; east face wall at x 77.55 | band 4.3 +- 2.3 m wide, limited to r 21 | 4.48 | walk; cliff down to meadow, grab not needed on stair | ART:569-582, :646 |
| Grand stair | middle (83.62, 30, 0), climbs west to x 77.5; width 4.4 (z +-2.2), run 12.24 | 2 flights of 12 steps (0.28 x 0.5), landing 2.0 | 0 to 4.48 | walk; **balustrade slide down each cheek** | ART:601; KIT:182-190 |
| Balustrades (2) | on the stair's cheeks, z +-2.2+, head (77.5, 34.5, +-2.6) to foot (~89.7, ~31, +-2.6) | rail ~21 deg, 0.67-1.24 m over the steps | rail top ~35 -> 31 | slide, flung off the foot east across the meadow | FOOT:110 |
| Ramp (T1 to T2) | polar 100 deg to 160 deg (north round to west-north-west), r ~15-20 | 60 deg arc, rises 4.2 | 4.48 -> 8.68 | walk; retaining wall on its inner side, kerb 0.2-0.36 on the outer | ART:571,:581-582 |
| West shelf | polar 160-215 deg, r to ~21 (west edge x ~40) | | 8.68 | walk; west_1 stone beyond | ART:582 |
| South ledge (T2 band) | polar 215-280 deg, r to ~16; widens to +2.6 m at the kit stair | band 3.3 +- 0.6 | 8.68 | walk | ART:573,:583,:593 |
| Kit stair | foot (~57.9, 38.7, ~14.4), head into the crag at polar 257 deg | 8 steps of 0.28 x 0.5, 2.0 wide, landing 1.0, run 4.5 | 8.68 -> 10.9 | walk up through the ring's gap | ART:589-590; KIT:87-91 |
| Summit crag | disc r ~11-14 around (61,0); plane y ~40.7 at the centre, falling 5.2 cm per m to the east | ~25 m across | ~10.7 | walk | ART:579,:660-675 |
| The bite | notch in the SE-S edge, centre polar 296 deg (point ~(65.6, 9.3)), reaches in to r 7.8 | width +-16 deg | summit edge cut | fall in (to T1); cross by the bite lintel | ART:586 |
| Stone circle (henge) | centre (61, ~40.7, 0), radius 9.55, 8 sarsens at polar 22.5+45k deg | sarsen 1.62 x 6.8 x 1.29, lintels 1.3 x 0.6 on top (top at ~+7.4), gap between sarsens 5.2 | sarsens 6.8; lintels ~7.4 above the summit (~world 48.1) | climb by the leaning stone / the fallen trilithon, run round on the lintels, twirl over the break (3 m) | KIT:210-258; ART:677-678 |
| Great trilithon | at the ring's back (west) edge, top ~world 49.6 | upright 1.8 x 8.9 x 1.2, knife slot 1.9 between the pair | | climb the lintels then jump up (pumped catch) | KIT:236-240 |
| Ring sarsen (floating) | (64.65, ~48.4, 8.8), polar 292.5 deg | 1.1 thick, lies along the ring, ~5.4 long | summit +7.4 | twirl from the lintels onto it and off | ART:1090-1102 |
| Bite lintel | across the bite's mouth at r 10.4, centre ~(65.6, ~41, 9.3) | ~3.5 long x 0.6 x 1.3 | ~11 | walk across the bite | ART:1103-1114 |
| Bite floor lintel | (65.8, 34.9, 9.8) | 2.8 x 0.6 x 1.3, grounded on T1 | 4.9 | step onto | ART:1116-1118 |

### Floating stones (platforms; each a clean box with a clod hung beneath)

| Name | Top middle (x, y, z) | Size (along, thick, across) | Gap to the previous | Source |
|---|---|---|---|---|
| south_1 (grounded, sunk on T1) | (73.1, 35.8, 7.0) | 2.0 x 1.6 x 1.8 | from T1 | ART:1066-1076 |
| south_2 | (70.9, 37.2, 9.9) | 1.9 x 0.7 x 1.7 | +1.35 up over ~1.8 m of air (a jump caught) | ART:1066 |
| south_3 | (68.0, 38.5, 12.1) | same | +1.35 | |
| south_4 | (64.4, 39.9, 12.8) | same | +1.35; then the bite / summit edge | |
| drift_1..6 | (73.6,-8.0) (77.2,-7.2) (80.8,-6.3) (84.4,-5.4) (88.0,-4.4) (91.3,-3.0) at y ~40.4, 40.7, 40.9, 41.1, 41.4, 41.6 | 2.0 x 0.65-0.9 x 1.8; drift_3 is a lintel | ~1.6 m of air each; last one ~0.7 m short of the castellum crown (x 93) | ART:1055,:1077-1086 |
| west_1 | (39.0, 39.2, 0.5) | 2.2 x 0.8 x 2.2 | 0.5 above the west shelf; 2.3 m of air to the west islet | ART:1087 |
| east_0 (grounded) | (125.4, 30.55, -6.3) | 1.6 x 0.85 x 1.3 | | ART:1089 |
| east_1 (**lodestone rests here**, +0.85 above top) | (128.8, 31.3, -6.5); lodestone at y ~32.15 | 2.0 x 0.8 x 2.0 | 1.2 m from the east islet's rim | ART:1088; ISLE:166,:395-400 |
| ring_sarsen / bite_lintel / bite_floor | see hill table | | | |

### The aqueduct and what stands by it

| Name | Position (x, y, z) | Size | h | Walker can | Source |
|---|---|---|---|---|---|
| Spawn (START) | (100, 30, 15.9) | | 0 | | ART:101 (-SLOPE_LOW+0.6) |
| Rubble slope | x 98.8-101.2, z +15.3 to -2, 30 deg | 2.4 wide, 20 m long | 0 -> 10 | walk up (under the walker's 44 deg limit); a scramble heap on its west side | ART:93,:338-366,:435 |
| Blind wall | x 98.8-101.2, z -2 to -22 | 20 m, deck on top; arches walled up; west face x 98.8, east face x 101.2 | 10 | walk on the deck; **wallrun the east face** (token "wallrun") | ART:69-83,:269-298 |
| Deck / channel | x 98.8-101.2, z -2 to -54.5, then -57.5 to -72 | channel clear 1.5 (parapets 0.42 high at x +-0.95, gone in runs; east side clear z +1 to -16) | 10 | walk, wade in 6 cm of water (z -2.6 to -54.4); slow | ART:108-117,:135-136 |
| Open arches (3, 4 over land/sky) | at z -26, -36, -46, -66 | clear 8.0 wide, crown 8.0 high | | walk beneath the first two (arches 2, 3); fly the plane through all (clear 8.0 vs span 2.8) | ART:49-60,:123-128 |
| Piers | z -31 (on island), -41, -51, -61 (hanging), -71 (on far island) | 2.0 x 2.4 | to 10 | pier heads of hanging piers are under the deck (not reachable); broken feet y 15, 11.7, 13.3 | ART:80-83,:300-311 |
| **Fallen span (the gap)** | z -54.5 to -57.5 at x 100 | **3.0 m**, deck stubs 1.4 and 1.2 below the deck near the snap (ragged, caught on voussoirs) | deck 10 | **twirled jump**; or drop in and twirl up (token "span"); water spills over the south end | ART:84-91,:239-267,:450-451 |
| Far-end drops | x 98.8-101.2, z -72 to -91.2 | 8 steps, 2.4 long, 1.2 down each | 8.8 -> 0.4 | walk/hop down | ART:94-98,:392-401 |
| Buttress | x 103.8-104.8, z -12 to -6 | 1.0 x 6.0, 2.6 m off the blind wall's east face | top 9.2 (0.8 under the deck) | kick up from the wall's east face to the buttress and on to the deck lip | ART:116-120,:403-417 |
| Castellum (water tower) | crown block x 93-95, z -3 to +1 | 2 x 4 plan, crown **11.8** (+ parapet 0.3 on W and N) | 11.8 | climb the steps from the south; jump from the channel (1.8 m gap across to the high step at 10.2) | ART:468-538 |
| Castellum steps | x 95-97, six blocks at z -3..9 (2 m each): h 10.2, 8.7, 7.3, 5.8, 4.3, 2.9; foot block (95.3, 9) 1.7 x 1.6 at 1.4 | steps of 1.47 (<= SET_OFF 1.6) | 10.2 -> 1.4 | walk/jump up (each step is a caught jump) | ART:471-484 |
| Kick block / slot | block x 97.05-98.75, z -3.4 to -1.8, h 1.4; the slot between the castellum steps (x 97) and the blind wall west face (x 98.8) is 1.8 m wide | | | **wall-kick up the slot** to the channel lip (token "slot") | ART:485-501 |
| Rope beams (3) | centre x 103.55, y 40.67, z -29.4, -47.0, -64.5; reach x 100.35-106.75 | 6.4 x 0.5 x 0.6 each | top ~40.9 (0.9 over the deck) | step/jump on from the deck; they lie over the east parapet | FOOT:51-52,:115 |
| Swing ropes (3) | anchor x 106.3, y 40.17; hang to a knot at y 30.9 (hands height); z -29.4 (over the meadow, 7.7 m in from the rim -37.1), -47.0, -64.5 (2.8 m short of the far rim -67.3) | rope length 9.27 (~9.3), 17.6 m apart | | run/jump onto rope 1, then **swing + release** to rope 2, 3, then land on the far island (a 9.3 m rope's well-timed release reaches 26.5 m, so each 17.6 m hop is well inside it) | FOOT:34-49,:94-97 |
| Ferry (drift slab) | x 110, y 30.3, z -36.25 to -67.9 | 2.4 x 0.6 x 2.4; 31.7 m each way at 2.51 m/s, period ~25 s; out and back | 0.3 | ride across the gap | FOOT:56-64,:122 |
| Bobbing slabs (3) | (129.6, 30.3, 3.4), (132.6, 30.8, 2.0), (135.0, 31.4, -1.4) (centres as given in the source: y may be top or centre) | 2.3 x 0.7 x 2.2 each; sink 0.24 and tilt when stood on | 0.3 -> 1.4 | hop slab to slab, out to the east islet | FOOT:65-66,:124 |
| Stepping stumps (5) | x 92 (2.4 wide): z -35.65 to -39.75 (top 30.6); -41.35 to -44.95 (30.4); [knife slot 2.11 m] -47.06 to -50.21 (29.8); -53.6 to -57.5 (30.2); -60.5 to -65.2 (30.0) | 3.0-4.1 long | tops +0.6 to -0.2 | gaps: 1.6 (run jump), 2.11 (slot), 3.4, 3.0, then 2.9 to the far island: twirled jumps. The plane slips the slot on a wingtip (knife edge) | ART:840-866 |
| Heel stone | (118, 30, 0) | 1.7 x 2.3 x 1.1, leaning away from the henge | 2.3 | grab/pump-catch the top | ART:604-605,:539-550 |
| Gate arch + paving (far island) | gate (100, 30, -96.9), paving (94.5, 30, -91.4) yaw 15 | the kit arch where the aqueduct came down | | walk through | ART:869-870; ISLE:142-147 |
| Parked plane | not fixed: found at runtime, an open level patch with a take-off run 8-40 m from the start (100, 30, 15.9) | span 2.8 m | | board it; walker keeps 0.75 m off | studies/kit_isle.gd:246-247,:1127-1146 |
| Paths worn in the turf | (90.8,0) -> (91.6,6) -> (94.5,10.6) -> (100,15.4) -> (106,10) -> (112,3) -> (117,0.4); and (72,-22) -> (80,-21.5) -> (86,-25.5) -> (92,-33.6) to the stumps | | | where flora is thin | ART:750-753 |

### Tokens (the isle's 8 on-foot tokens; the moves they ask for)

| # | Name | Position (x, y, z) | Move |
|---|---|---|---|
| 1 | slot | (97.9, 36.5, -2.6) | wall-kick up the castellum / blind wall slot |
| 2 | wallrun | (101.66, 33.45, -4.9) | wallrun along the blind wall's east face |
| 3 | span | (100, 39.65, -56.2) | drop into the fallen gap, twirl up to the far lip |
| 4 | sarsen | (64.65, ~49.3, 8.8) | twirl from the lintels onto the floating sarsen |
| 5 | trilithon | ~(52, ~50.5, 0), ring's west back | climb the lintels, jump onto the great trilithon (position approximate) |
| 6 | drift | under drift_3's north lip (~(80.8, ~40, -7.2)) | hang off the lintel and shimmy |
| 7 | stumps | (92, 31.25, -66.65) | jump the stumps back from the far island |
| 8 | buried | ground (85.6, 30, -20.9), shimmer ~0.85 above | slam down onto it from a height |

Source: TOK:11-75. Items 5 and 6 positions are derived and approximate.

## 5. Movement numbers

From scripts/pilot_motor.gd (line refs) and scripts/ruin_kit.gd. Walker size 1.0
(drawn at 1.0 x his clips' 1.19 m); plane 2.0 (span 2.8 m, 0.74 x 2 = 1.48 m
tall).

| Move | Number | Source |
|---|---|---|
| Walk / run | 2.4 / 4.8 m/s | pilot_motor.gd:201-202 |
| Gravity up / fall | 26 m/s^2, falling x1.5 (39); cut jump x2.8; terminal 18 m/s | :218-221 |
| Plain jump | 0.8 m high (about 2.1-2.2 m long off a run, ~) | :223 |
| Pump (jump again within 0.3 s of landing) | 1.5 m high (about 3 m long, ~) | :223,:226 |
| Step up (walk) | 0.45 m; 44 deg slopes walked | :233 |
| Ledge grab: highest lip a plain jump catches | **GRAB_TOP 1.875 m** | ruin_kit.gd:79 (0.8 + HANG_DROP 0.825 + GRAB_LOW 0.25) |
| Ledge grab: a pumped jump | **CHAIN_TOP 2.575 m** | ruin_kit.gd:80 (1.5 + 0.825 + 0.25) |
| Climb-route rise between holds | SET_OFF 1.6 m | ruin_kit.gd:83 |
| Long jump (crouch, jump at pace >= 3) | 0.7 m high, 4.2 m level from a run; chained: +1.4 m/s per jump up to 12 m/s, 4.2 -> 6.7 m a jump | :251-259 |
| Twirl (jump apex, press again) | rises 2.8 m/s for 0.45 s at half gravity, ~0.4 s more air, pushes 2 m/s along the stick | :289-295 |
| Twirled jump | what the isle designs the 3 m fallen span and the stump gaps (2.9, 3.0, 3.4) round; the ring's lintel break is also 3.0 m (3 x wanderer) | ART:84-88,:848; KIT:225-228 |
| Wall slide / kick | fall caught to 0.5, slide max 1.8 m/s; kick 1.4 m high, 5.2 m/s out; ~1 m gained per kick between walls 2.8 m apart | :268-283 |
| Wall run | needs pace 4.0, rises ~2 m (the "wallrun" token is 3 m up the blind wall's face) | :311-319 |
| Slide (rail, slope) | slides on slopes steeper than ~22 deg; balustrade ~21 deg; slide top speed 20 m/s | :330-343 |
| Hang drop / shimmy | hands 0.825 over the feet; shimmy 0.7 m/s | :375-379 |
| Swing rope | knot at the walker's hands (0.9 m over the ground at rest); 9.3 m rope: plain release reaches **26.5 m** (5.6 m rope: 19.0 m) | FOOT:40-46; swing_rope.gd:42-43 |
| Pocket sail (glide) | opens mid-air with jump: a 3.5 kick up (once per airtime), then PACE 5.5 m/s, SINK 1.5 m/s (about 3.7 m across per metre down); brake 3.2/1.2 (2.7:1), dive 7.5/2.4 (3.1:1); turn 2.4 rad/s; carries run/long-jump pace; thermals lift | pocket_sail.gd:46-91 |
| Swim / wade | wades slower in the channel (0.67 of speed) | :420-432 |

Gaps currently in the isle (all at the defaults):

| Gap | Size |
|---|---|
| Fallen span | 3.0 m, deck 10 m up (fall = death into the sky) |
| Ropes over the sky | rim to rim 30.2 m at x 106.3; rope hops 17.6 m |
| Stepping stumps | 1.6, 2.11, 3.4, 3.0, 2.9 m |
| Near tip to far island at x 100 | 25.6 m of sky; the deck crosses it |
| Floating drift stones | ~1.6 m of air each; castellum crown ~0.7 m |
| South chain | +1.35 m up over ~1.8 m of air each |
| Castellum steps | 1.47 m each; channel to castellum high step 1.8 m across |
| West_1 to west islet | 2.3 m; east_1 to east islet 1.2 m |
| Ring lintel break | 3.0 m |

The plane's sizes and openings (scripts/world_scale.gd, defaults):

| Thing | Value |
|---|---|
| Plane span / height | 2.8 m / 1.48 m (TOY_SPAN 1.4, TOY_TALL 0.74, times 2) |
| `opening(toy_width)` | toy_width x 2 x 1.0, floored at 5.2 (never acts at ratio 1) |
| Aqueduct arch clear | opening(4.0) = **8.0 m**, 2.6 m past each wingtip |
| Henge sarsen gap | max(gap(SNUG) 5.2, opening(2.1) 4.2) = 5.2 m, 1.2 m past each tip |
| `gap(room)` | span + 1.4 x room; default room 2.0 gives 5.6; SNUG gives 5.2 |
| Knife-edge slots | `knife()` 1.9 m (trilithon slot); stump slot 2.11 m (0.32 m clear each side on a wingtip) |
| Walker (WANDERER) | 1.0; cockpit pilot drawn 1.2x; parked plane drawn at no extra ground cheat |

## 6. Hill ring radii (m from HILL, to place things by polar angle)

Polar angle in degrees runs from east (+x) toward north (-z): 0 east, 90 north,
180 west, 270 south. Position of (angle t, radius r) = (61 + r cos t, -r sin t).
Radii (formulas ART:617-650; computed): summit edge / upper tier outer edge /
lower tier outer edge.

| t | Summit edge | T2 outer | T1 outer |
|---|---|---|---|
| 0 (east) | 13.9 | 17.4 | 16.5 (stops at the east face x 77.55) |
| 45 | 13.1 | 16.2 | 19.1 |
| 90 (north) | 11.2 | 14.7 | 18.4 |
| 135 | 12.6 | 15.7 | 20.4 |
| 180 (west) | 12.6 | 16.1 | 21.0 |
| 225 | 12.2 | 15.3 | 19.2 |
| 270 (south) | 11.8 | 15.3 | 17.6 |
| 296 (the bite) | ~7.8 | | |
| 315 | 11.7 | 14.9 | 20.6 |

T2 exists only 100-280 deg; T1 elsewhere is the ring between T2/summit and r1.
The cliffs between tiers are 4.2 m (T1 to T2), 4.5 m (meadow to T1), 2.2 m
(T2 to summit by the kit stair; elsewhere up to 2.2 m of crag).

## 7. Named zones

Use these names when placing content.

- **Near meadow**: the flat turf round the aqueduct's line and the spawn (x 70-125, z -26 to +24), `.` on the map. Spawn (100, 15.9), slope foot, paths, plane home.
- **Spawn and slope foot**: x 95-105, z 8-18; the rubble slope runs north from here to the head.
- **The head / blind wall**: the aqueduct's south end, z -2 to -22, deck 10 m up, walled arches, east-face wall-run, buttress.
- **Kick slot**: the 1.8 m gap between the castellum's steps and the blind wall (x 97-98.8, z -3 to -1), a wall-kick climb to the channel.
- **Castellum**: the water tower (x 93-97, z -3 to +10), crown at 11.8, a broken staircase of steps running south.
- **The channel**: the deck walkway, z -2 to -54.5, parapets and water, 10 m above the turf.
- **Arcade (under the arches)**: z -22 to -40 beneath arches 2 and 3, where you can walk beneath the deck (8 m clear, 8 m high).
- **The gap**: the fallen span, z -54.5 to -57.5, 3 m, deck 10 m up, open sky below.
- **North deck / far run**: the channel past the gap, z -57.5 to -72, then the drops to the far island.
- **The drops**: eight 1.2 m steps down, z -72 to -91.2.
- **Far island**: x 85-116, z -66 to -101.6; gate arch at the north, the raised bump at (108, -90.8).
- **The sky gap**: 25.6 to 30.2 m of open air between the near island's north tip and the far island; ropes, ferry, stumps, aqueduct cross it.
- **Rope line**: x 106.3, three rope anchors at z -29.4, -47, -64.5.
- **Ferry lane**: x 110, z -36 to -68.
- **Stump line**: x 92, z -35.7 to -65.2, five broken piers back from the far island.
- **North path / north edge**: the worn path (72,-22) to (92,-33.6) along the near island's north rim.
- **Henge terrace / the summit**: the crag at (61, 0), y ~41; stone circle radius 9.55, great trilithon at its west, the bite at its south-east.
- **The grand stair and the forecourt**: stair x 77.5-89.7; the meadow east of it (x 90-98, z -8 to +8) is the forecourt, drift stones run overhead.
- **Lower terrace (T1)**: the 4.5 m shelf round the hill's east, north and south.
- **The winding way**: stair, T1 north, ramp (100-160 deg), west shelf, south ledge, kit stair, ring gap.
- **West shelf and west islet**: x ~40-45, y 38.7; west_1 and the islet beyond (32, -0.5), a view out over open sky.
- **South chain**: four floating stones (64-73, 7-13) climbing from T1 round the crag to the bite.
- **Drift**: six stones from the summit's north-east edge to the castellum crown, (73.6,-8) to (91.3,-3).
- **East meadow and heel stone**: x 105-128, z -25 to +14; heel stone (118, 0), rise (117, -17).
- **East rim, bobs and east islets**: the rim at x ~126-128; east_0, east_1 (lodestone) at (125-129, -6.5), bobs (129-135, 3.4 to -1.4), the east islet (135, -8).
- **Open sky / the neighbours**: the isle stands alone in this scene except the motif isles listed in section 8.

## 8. Other isles near the aqueduct isle in the full world

studies/island_packs/ruins_archipelago.gd lays seven stations 100 m apart in x
(station k around x 100(k-1)), but the aqueduct isle's scene keeps only
station 2 (studies/aqueduct_isle.gd:246-255). The sky adds motif isles at
fixed offsets (scripts/kit_isle/motif_sky.gd:39-53); their world middle and
turf height: bell spires (420, y 42, 60), cloister tarn (60, 30, 360),
sundered gorge (-300, 36, 80), colonnade spine (-200, 48, -330), broken ring
(-580, 36, -80), drowned nave (-230, 30, 350), stair to the clouds (520, 44,
-260; reach 33), hollow keel (365, 46, 355). Nearest are 300+ m away; nothing
is within walking or glide range. The lodestone's chain target is
(200, 42, -380), 380 m north-north-east.

## 9. Uncertainties

- The plane's parking spot is chosen at runtime (open level turf with a take-off run, 8 to 40 m from the start); I did not run it, so it is left off the map.
- Floating-stone and token heights are derived from formulas; the summit plane (~40.7) is computed by hand, not read off the engine (+-0.3).
- Hill tier outlines are a coarse rasterisation of the radius formulas; for exact edges call `Art.ground(x, z)`.
- The bob slabs' source "y" (TOP+0.3 ...) may be their top or centre.
- The castellum step positions are exact from the formula; the drawn stone around them is a bit larger.
- Island keel depths are the build parameter; the actual hanging rock tapers.
- Slope speeds and jump distances marked "~" come from the motor's constants by hand, not a measurement.
