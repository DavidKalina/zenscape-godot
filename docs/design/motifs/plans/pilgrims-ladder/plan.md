# The Pilgrim's Ladder
Card: docs/design/motifs/brainstorm/round3-new-kit-isles/motif-m1-pilgrims-ladder.md
Pitch: Four sky isles stepped up and east like a pilgrimage, one new piece at each station. The torana's ropes lift you off the landing isle. The broken nimbus is the climb up to its horns. A pent hood on the Crown hides you from the guacharo. A slam on the hung stair's boss turns its flight into the way down to the Cellar, and from there two easy hops and a sail take you home to the plane. The plane lands on Threshold, threads the torana gate and flies out through the ring.
Fit: role hero/vertical. Footprint about 160 x 45 m (x -50..107, z -14..24). Height span 0 (Threshold) to 20 (Crown), the high horn at 24.1. It stands alone in the sky. Keep 20 m clear round it for the plane, and 12 m clear of anything north and south of the nimbus so the plane can line up on the ring.
Play: You land on the foot isle, walk to the jamb and ride the ropes up under the lintel onto its top, then drop onto the Halo. You climb the nimbus's ring by its stubs, spoke and brackets to the low horn, and a twirled leap takes you to the high horn. From there you sail across to the Crown, where the bird wakes. You creep under the hood to the reliquary, then jump off the south lip and slam the boss, drop into the shaft and run down the turned stair before its 12 s run out. From the Cellar you sail down to the Halo and sail on home.
Set pieces:
- relic_torana (the real piece), its jamb on Threshold's east lip at x 25: 4 SwingRopes, all 5.6 m, from iron arms on posts along the lintel's top front (+Z) edge, rings at x 28.2, 33.8, 39.4, 45.0 (heights 6.5, 8.1, 9.7, 11.3), z 1.58. Each knot is one SET_OFF higher than the last, and the 3rd rope is dry. The last rope's backswing release lands on the lintel's top (16 deg); the slow way is three offering steps up the jamb's head (6.4), a drop onto the lintel's root and a walk up its top to the snapped end (x 46.2, top 10.5), then a hop down onto the Halo (7).
- relic_nimbus, on the Halo at (62, 7, -3), 3 m north of its centre line so the torana's hop lands in front of the ring: the inner rays, the spoke, the outer rays, the low horn, then a twirled leap over the 3.9 m crown gap to the high horn. The plane threads the 11.4 m ring.
- pent_hood, along the Crown's north rim: 3 bays with the middle roof fallen. The gallery is cover from the bird's up-ray, the roof gap is an open dash, and the roof's 20 deg pitch is a surf down to the Crown's turf.
- keel_hung_stair, on a built plinth off the Crown's south lip. Hung, its soffit is a 50 deg slide off into the sky. Slammed from 4 m or more, it turns into a stair from the plinth's shaft down to the Cellar for 12 s, and it throws anyone still on it when it turns back.

## Numbers
| What | Value | Source | Card said |
|---|---|---|---|
| Plane scale / wanderer scale | 2.0 / 1.0 | scripts/world_scale.gd PLANE, WANDERER | - |
| Opening for a flown thread | 7.0 m | WorldScale.opening(RuinKit.TOY_THREAD 3.5) | 7.0 |
| Wanderer height (guacharo's unit) | 1.12 m | scripts/enemies/guacharo.gd `unit` | - |
| Ledge set-off (one step of climb) | 1.6 m | scripts/ruin_kit.gd SET_OFF | 1.6 |
| One-jump grab top / chain top | 1.875 / 2.575 m | RuinKit GRAB_TOP, CHAIN_TOP | - |
| Ledge stand depth / walk width | 0.58 / 1.16 m | RuinKit STAND, TOP_ROOM | - |
| Slide-auto slope | 44 deg | PilotMotor SLIDE_AUTO | 50 (hung soffit is SLIDE_AUTO+6 = 50, matches) |
| Fall stun / hurt / two hearts | 6 / 9 / 18 m | PilotMotor FALL_STUN_PUMPS 4, FALL_HURT_PUMPS 6, FALL_HARD_PUMPS 12 (x 1.5 m pump) | - |
| Sail pace / sink (glide 3.7:1) | 5.5 / 1.5 m/s | scripts/pocket_sail.gd PACE, SINK | horn to Crown "10 m" at 2.1 m drop: too far (7.7 m) |
| Slam: least drop that turns the stair | 4.0 m | scripts/slam.gd DECENT; keel_hung_stair.gd knob `slam` = Slam.decent() | 2.1 m (too little: corrected) |
| SwingRope length / knot / run-in | 5.6 / 0.9 / 3.0 m | scripts/interactables/swing_rope.gd LENGTH, KNOT, RUN_IN | - |
| Nimbus outer radius / band / depth | 9.0 / 1.6 / 1.6 m | scripts/ruin_kit_relic.gd NIMBUS_RADIUS, NIMBUS_BAND, NIMBUS_DEPTH | - |
| Nimbus ring centre over its foot | 8.2 m | Relic.nimbus_centre() | 8.2 |
| Nimbus clear opening | 11.43 m | relic_nimbus meta `opening` | 11.4 |
| Nimbus low / high horn perch | 15.51 / 17.11 m over foot | Relic.nimbus_lines() low_perch, high_perch | horn 24 (Halo 7 + 17.1 = 24.1) |
| Nimbus horns (piece frame) | low (-4.43, 15.51), high (0.8, 17.11) | meta `horns` | - |
| Nimbus crown gap | 3.9 m | NIMBUS_GAP | - |
| Pent hood bay / bays | 5.2 m / 2 (knob up to 3) | RuinKit WALL_LENGTH, Cloister HOOD_BAYS | 2 bays |
| Hood gallery width / parapet top / wall top | 1.16 / 1.59 / 4.93 m | Cloister HOOD_GALLERY, hood meta parapet_top, wall_top | - |
| Hood roof pitch / fallen gap | 20 deg / 1.6-2.4 m | HOOD_PITCH, HOOD_GAP | "one fallen bay" is a roof gap, not a whole bay |
| Hood back wall line | z -1.18 (piece frame) | hood_lines() wall_mid | - |
| Hung stair: hinge drop under boss | 3.2 m | scripts/ruin_kit_keel.gd KEEL_DROP | - |
| Hung stair: turned head / foot | head (1.84, -3.2, -1.42), foot (-2.0, -5.44, -1.42) | keel meta head, foot | stair down "9 m" to Cellar 13: code's flight drops 5.44 m |
| Hung stair: hold / tell / turn | 12 / 0.5 / 1.2 s | keel_hung_stair.gd knobs | 12 s |
| Hung stair: knock past | 70 deg of turn | knob knock_angle | - |
| Guacharo circle radius / height over him | 19.0 / 11.2 m | guacharo KNOBS circle_r 17, circle_up 10 (x unit 1.12) | "circles the Crown" |
| Guacharo hunt range from home | 22 m here (layer default 140) | scripts/roguelike/layer_flyers.gd RANGE, plan `flyers` [{home, grace, range}] | wakes on stepping onto the Crown |
| Hand landing: touch speed / braking | at most 10.5 m/s / 4.2 + 0.9 m/s2 | scripts/manual_landing.gd TOUCH_FAST, WHEEL_BRAKE, ROLL_DRAG | - |
| Strip ideal run | 18 m | scripts/plane_strip.gd IDEAL | - |

## Kit
| Piece | Exists / stand-in / build | Where it's used |
|---|---|---|
| relic_torana | real piece (merged) | Threshold east lip: jamb at (25, 0, 0), lintel to (46.2, 10.5, 0) |
| relic_nimbus | exists (scripts/ruin_kit_relic.gd) | Halo (62, 7, -3), rot 0 (ring in XY, plane flies along Z) |
| pent_hood | exists (scripts/ruin_kit_cloister.gd), bays 3, fallen 1 | Crown north rim, centre (92, 20, -10), rot 0 (back wall north, eaves south), seed 5342 (its fallen gap in the middle bay) |
| keel_hung_stair | exists (scripts/ruin_kit_keel.gd + scripts/keel_hung_stair.gd) | boss at (86, 15.5, 18) on the plinth, rot 0 (hung front +Z, south, over the void) |
| plinth (shaft) | built (gb_pilgrims_ladder.gd `plinth`, RuinKit.Build stone in courses) | deck x 83..90.4, z 13.4..19.3, top 15.5, hatch x 86.4..88.8, z 15.1..17.3; north wall on z 13.4..14.7 against the Crown's flank, east wall x 89.6..90.4, lintel over the west door, south side open under the deck (the hung flight swings out there); a shaft floor (top 12.3) east of the head, its lip on the stair's head cut |
| wall, floor, buttress, fallen_pier, arch, stairs | exist (RuinKit PIECES) | Crown dressing, the hood's kit wall line, the plinth's walls |
| guacharo | exists (scripts/enemies/guacharo.gd); no motif-yard host yet | LayerFlyers-style host stepping one bird round the motor |
| foot tokens / buried finds | exist (scripts/kit_isle/kit_tokens.gd, scripts/buried_find.gd) | the collectibles below |

## Corrections from the card (code over card)
- **Crown top 20, not 22.** The sail glides 3.7:1. A 2.1 m drop from the high horn (24.1) carries about 7.7 m. At 20 the 4.1 m drop carries about 15 m, so the 12 m sail from the horn to the Crown's west lip has room.
- **The slam needs a drop of 4.0 m or more** (Slam.DECENT), not 2.1. The boss sits on a built plinth 4.5 m under the Crown's south lip (top 15.5). You take it by jumping off the lip and slamming, or by sailing straight in off the high horn (an 8.6 m drop).
- **The turned flight drops 5.44 m, not 9.** Its head is 3.2 m under the boss (a drop into the shaft, under the 6 m stun) and its foot is 5.44 m under it, so the **Cellar's top is 10**, not 13.
- **KitLand has no hole cut,** so the shaft is a built plinth that stands on the Cellar's south rim off the Crown's south flank, with the turned flight inside its walls. The Cellar sits under the Crown's south half, its top 2 m under the Crown's keel (keel raised to 12). The hung soffit hangs south past the Cellar's rim (z 18) into the sky.
- **Horizontal spacing is tightened.** Halo x 62 (rx 12). Crown x 91 (rx 16), west lip 75. The high horn is at x 62.8, so the sail is 12 m.
- **The way home is Cellar -> Halo -> Threshold.** A sail from the Cellar (10) straight to Threshold covers 48 m, past the 37 m it can carry. The Cellar's west rim is about 5 m from the Halo's east rim and 3 m above it: a hop or a short sail down. From the Halo's west lip (50), a 7 m drop sails 26 m, against a 20 m gap to Threshold's east lip (30).
- **The real torana sets the numbers**: all ropes 5.6 m, rings rising 1.6 per 5.6 m along the lintel's top front edge (16 deg). The jamb moved from x 28 to 25 so rope 1 (3.2 m out from the jamb) hangs over turf (the lip is at about x 30). The snapped end (x 46.2, top 10.5) is about 4 m short of the Halo's lip, 3.5 m over it: a running hop carries it.
- **The nimbus stands 3 m north of the Halo's centre line** (62, 7, -3). At z 0 its ring's lower outer face (x 55.7 at head height) is where the torana's hop lands; set back, the hop lands in front (+Z) of the ring, two steps from its trough.
- **The hood stands at (92, 20, -10), not (94, 20, -11).** The Crown's north rim pulls in to z -12 at x 84 and 100 and to -10.5 at x 102, so the plan's 15.6 m hood hung its east end over the void. Seed 5342 puts its one fallen gap in the middle bay (x 91.6..93.7); the reliquary moves to the gallery's east end (99, 20.4, -10).

- **The Cellar's turf is cut back at x 83.85 south of z 14.** The stair's turn sweeps down to y 7.3 under the plinth (x 84..89.4, z 14.9..20.7, dumped headless), through a full Cellar's turf. The flight's foot (84, 10.06) steps west off the cut edge onto the turf.
- **The slam off the lip takes a jump.** Walking off the Crown's south lip and slamming at once gives a 3.4 m drop, under DECENT's 4.0; a jump off the lip and a slam at its top turns the stair (driven).
- **The hatch is x 86.4..88.8, z 15.1..17.3** (clear of the boss), and the shaft has a floor east of the head (top 12.3, lip on the stair's head cut), so a drop through the hatch lands on stone whether the stair is turned or hung.
- **The sail off the high horn takes a run-up.** A standing jump off the high perch peaks 0.8 m over it and comes down on the ring's outer top before the sail has room to open. Run east down the outer top 2-4.5 m (slope 13-30 deg), jump and open the sail at once (driven).
- **Cellar to Halo is a short sail, not a hop.** From the Cellar's west rim (77.2, 10, 9.4) a running jump falls about 5.7 m short into the sky; a jump and the sail at its top lands on the Halo at about (65.5, 7, 5.7) (driven). The Halo's west lip to Threshold is a sail along z 4.5, south of the lintel and its ropes; it lands at about x 19.

## Open questions
- Answered (drive check): the last rope's backswing release lands on the lintel's top, and a running hop off its end lands on the Halo.
- Answered (drive check): the sail from the high horn reaches the Crown with room. Run 2-4.5 m down the ring's east outer top, jump, open the sail: it lands 21-26 m on, at x 84-88 on the Crown's turf (the west lip is at 75).
- Can the hood's fallen gap (1.6-2.4 m) be crossed under the bird's stalk without a snatch? Is that the right amount of fear?
- Is 12 s (the hold) enough to drop into the shaft and walk the flight, or too generous? Knob `hold` 8-16.
- The Cellar can also be reached by sailing down off the Crown's south lip (10 m). Does that make the stair optional, and is that fine?
- Does the plinth read as built stone and not a box? (Stills: from the Crown's lip the deck, hatch and boss read; from the south and west the plinth sits in the Crown's shadow and reads near-black.) Does the hung soffit read as a slide from the Crown?
- Does the guacharo's 22 m range wake it as you land on the Crown and not on the high horn (28 m)?

Layout:
```json
{
  "isles": [
    {"id":"1","name":"Threshold","x":-10,"z":0,"rx":40,"rz":22,"top":0,"keel":-14,"set_piece":"relic_torana jamb + landing strip"},
    {"id":"2","name":"Halo","x":62,"z":0,"rx":12,"rz":12,"top":7,"keel":-5,"set_piece":"relic_nimbus"},
    {"id":"3","name":"Crown","x":91,"z":0,"rx":16,"rz":14,"top":20,"keel":12,"set_piece":"pent_hood + hung stair boss"},
    {"id":"4","name":"Cellar","x":84,"z":11,"rx":8,"rz":8,"top":10,"keel":3,"set_piece":"plinth shaft foot"}
  ],
  "links": [
    {"from":"1","to":"2","kind":"rope"},
    {"from":"2","to":"3","kind":"climb"},
    {"from":"3","to":"4","kind":"stair"},
    {"from":"4","to":"2","kind":"stones"},
    {"from":"2","to":"1","kind":"stones"}
  ],
  "pieces": [
    {"id":"relic_torana","at":[25,0,0],"rot":0,"note":"jamb on the lip; lintel east to (46.2, 10.5, 0); rings at x 28.2, 33.8, 39.4, 45.0, z 1.58, all 5.6 m, knots 0.9, 2.5, 4.1, 5.7 over turf 0; rope 3 dry"},
    {"id":"relic_nimbus","at":[62,7,-3],"rot":0,"note":"low horn perch (57.6, 22.5, -3), high horn perch (62.8, 24.1, -3)"},
    {"id":"pent_hood","at":[92,20,-10],"rot":0,"bays":3,"fallen":1,"seed":5342,"note":"x 84.2..99.8, back wall on z -11.2, gallery z -10.6..-9.4, eaves z -8.3, roof gap x 91.6..93.7"},
    {"id":"keel_hung_stair","at":[86,15.5,18],"rot":0,"note":"boss on plinth top 15.5; head 12.3, foot 10.06 on the Cellar"},
    {"id":"plinth","at":[86.7,11.9,16.35],"size":[7.4,7.2,5.9],"note":"built walls round the turned flight; hatch over the head end; door at the foot onto the Cellar"}
  ],
  "pilot": [[-30,0,0],[20,0,1.6],[28.2,0.9,1.6],[45,5.7,1.6],[44,10.2,0],[52,7,2],[62,7.8,1],[57.6,22.5,0],[62.8,24.1,0],[76,20,2],[88,20.2,-10.6],[101,20.2,-10.6],[86,20,13],[86,15.5,18],[87.8,12.3,16.6],[84,10,16.6],[80,10,12],[72,7,4],[50,7,0],[28,0,0],[-30,0,0]],
  "threat": [[91,31,-19],[110,31,0],[91,31,19],[72,31,0],[91,31,-19]],
  "tips": [[62.8,24.1,0],[86,15.5,18]],
  "landing": [-38,-5,-8,5],
  "end": [-30,0,0],
  "moments": [
    {"at":[36,3,0],"label":"The ropes","note":"You run in, swing, release rising and catch the next rope up under the lintel; the dry third rope snaps and you twirl on to the fourth."},
    {"at":[62,15.2,-3],"label":"The wheel","note":"You climb the broken ring by inner rays, the spoke and outer brackets to the low horn; the plane threads the same ring."},
    {"at":[60.2,23.5,0],"label":"The leap","note":"A twirled leap over the 3.9 m crown gap to the high horn, the whole stack in view."},
    {"at":[92,20.2,-10],"label":"Under the hood","note":"The bird wakes as you land; you creep the gallery under its circle, dash the fallen roof gap and take the reliquary."},
    {"at":[86,15.5,18],"label":"The slam","note":"Off the south lip (or in off the horn) you slam the boss; the stair grinds over and you have twelve seconds."},
    {"at":[84,10,16.6],"label":"The cellar","note":"Down the shaft and the flight before it turns back and throws the late; then hop to the Halo and sail home."}
  ],
  "notes": [
    {"at":[21,0,3],"text":"offering steps up the jamb's head: the slow way up"},
    {"at":[62,15.2,6],"text":"ring clear 11.4 m: plane fits (7.0 needed)"},
    {"at":[69,22,4],"text":"horn to Crown: sail 12 m, drop 4.1"},
    {"at":[86,13,23],"text":"hung soffit: 50 deg slide into the sky"},
    {"at":[92,20,-14],"text":"pent_hood gallery 3 bays, middle fallen"},
    {"at":[76,8.5,8],"text":"Cellar to Halo: a short sail, 3 m down"}
  ],
  "collectibles": [
    {"at":[24.3,6.4,0],"kind":"token","name":"threshold/niche_sill","how":"the slow way: climb the offering steps, one SET_OFF apart, to the head's top (6.4)"},
    {"at":[46,10.5,0],"kind":"token","name":"threshold/lintel_end","how":"a well-timed release off the fourth rope onto the lintel's outer end"},
    {"at":[29.6,1.9,0],"kind":"flown","name":"threshold/gate_thread","how":"fly the plane through the torana gate under the lintel (7.0 m opening)","plane":true},
    {"at":[62,15.2,-3],"kind":"flown","name":"halo/ring_thread","how":"fly the plane through the nimbus ring along Z","plane":true},
    {"at":[62.8,24.6,-3],"kind":"token","name":"halo/high_horn","how":"the twirled leap from the low horn to the high horn's perch"},
    {"at":[99,20.4,-10],"kind":"token","name":"crown/reliquary","how":"creep the hood's gallery to its east end, past the fallen gap, under the bird"},
    {"at":[85,10.5,16.6],"kind":"token","name":"cellar/stair_foot","how":"slam the boss, drop into the shaft and walk the turned flight down inside its 12 s"}
  ],
  "enemies": [
    {"id":"guacharo","kind":"giant oilbird (scripts/enemies/guacharo.gd)","sleep":[91,46,0],"wake":{"at":[91,20,0],"r":22,"by":"the pilot's feet within 22 m (flat) of the Crown's centre: landing on the Crown, the plinth or the Cellar; grace 0"},"route":[[91,31,-19],[110,31,0],[91,31,19],[72,31,0]],"note":"Home is high over the Crown. Woken, it circles 19 m out and 11.2 m over him and reads his exposure; under the hood's roof it reads 'cover' and its hunger falls. In the open (the fallen gap, the turf, the boss's plinth top, the turned flight) it stalks, folds and stoops. A hit on foot is a snatch out over the void."},
    {"id":"hung_stair","kind":"trap (scripts/keel_hung_stair.gd)","sleep":[86,15.5,18],"wake":{"at":[86,15.5,18],"r":2,"by":"a slam of 4.0 m or more whose ring reaches the boss"},"route":[[87.8,12.3,16.6],[84,10.06,16.6]],"note":"12 s turned, then a 0.5 s grinding tell and a 1.2 s turn back; anyone stood on it past 70 deg of turn is tossed or knocked."}
  ],
  "landing_note": "Strip on Threshold's west half, x -38..-8 at z -5..5, a 30 m run due east on flat turf at 0, the approach from the west over the lip at x -50. A hand landing touches at 10.5 m/s or less and brakes at 4.2 + 0.9 m/s2, so it stops in about 11 m. The strip ideal is 18 m (PlaneStrip IDEAL). 30 m leaves about 19 m for the float and touch. The band x -45..-3, z -8..8 stays clear of pieces, flora and rocks (the torana jamb is at x 25, 33 m past the strip's end)."
}
```
