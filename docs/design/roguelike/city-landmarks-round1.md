# City landmarks, round 1: the court, the pyramid, the sundered hall

These are the three set pieces of the underground Olmec city that the user
named: "epic staircases, the sundered hall, potentially coliseums". They come
from the cards `city_court`, `city_pyramid` and `city_hall` in
`brainstorm/round3-olmec-city/kit-k1-literal.md`. Each is a place two bodies
use differently:
- His lanes are his width (`CityKit.LANE`, 8.8 m).
- Her lines are cut at her own numbers (SET_OFF 1.6, STAND, GRAB_TOP).
- Each stands on its own battered foundation, so it reads in the haze as an
  isle with a landmark silhouette on it.

Branch `kit/city-landmarks`, off `roguelike` 6f0129fc. New files only:
`scripts/city_kit_landmarks.gd`, the yard and its launcher. Nothing in
`scripts/city_kit*.gd` was edited (`look/city-weathered` owns those this
round).

## Play it

    ./run-city-landmarks.command                       # torch look
    ./run-city-landmarks.command --underground=haze    # haze (L flips)
    ./run-city-landmarks.command --olmec=court         # he starts on the court's promenade

This opens `studies/city_landmarks_yard.tscn`: a basalt plaza over the abyss
with a landmark on three sides. A whole Olmec hunts there with sight, swat,
pounce, inhale, periscope and chase routes. His breaker is the breakables
hub, so the stair's fault landing and the cressets break under him.

| Where | Landmark |
|---|---|
| West | The ballcourt coliseum, its gate on the plaza |
| North | The temple pyramid, its epic stair's foot on the plaza |
| East | The sundered hall, its high end on the plaza |

**Stations:**

| Key | Station |
|---|---|
| 1 | Start |
| 2 | Court gate |
| 3 | Court ledge |
| 4 | Court promenade |
| 5 | Stair foot |
| 6 | Shrine door |
| 7 | West prism chain |
| 8 | East kick chimney |
| 9 | Hall high end |
| 0 | Hall aisle |
| - | Hall chimney |

**Keys:** R puts everything back, B puts him back, J shows his sight, L
flips torch and haze, T puts your torch out or lights it, F1 shows the
numbers (his state, which landmark he is on, your root).

**Flags:**
- `--olmec=plaza|court|stair|landing|pyramid|hall` sets where he starts.
- `--lit` starts the cressets burning.
- `--no-fault` keeps the stair's second landing whole.
- `--no-body`, `--sight-overlay`, `--body-knob=`, `--head-knob=`, `--day`.

## The API and the registration snippet

`scripts/city_kit_landmarks.gd` is a RefCounted with no class_name:
- `PIECES` and `NAMES`.
- `piece(id, seed, weathered, opts)` and `stand(id, parent, xform, ...)`.
- `walk_areas(piece, kinds)`, which is CityKit's.
- The builders `court`, `pyramid` and `hall`.

Each piece is built with `CityKit.Piece`: blocks in the Olmec's basalt
(`city_kit_stone.gd`) and a "Mesh" plus a "Body", front toward +Z. It
carries the family's meta (`ports`, `mounts.cresset`, `walk_areas`, `his`,
`breaks`, `triangles`) plus:
- `sizes`: every derived number.
- `ropes` (court only): `[{anchor, length}]` in piece space. The scene hangs
  them as SwingRopes and steps them, as the yard's `Slot` does. A piece
  can't step its own ropes; that needs the study's motor.

The y 0 of each piece:

| Piece | y 0 |
|---|---|
| Court | the alley floor, the ground it meets at its +Z gate |
| Pyramid | its foot, the ground at the stair's foot |
| Hall | the high half's floor, the ground at its +Z end |

Options every piece takes:
- `foundation`: depth, default 60 m.
- `fires`: default true, CityFires cressets on their mounts.
- `lit`, `cover`, `ground`.

The pyramid also takes `fault` (the stair landing that breaks, default 2,
0 for none).

Ground cover is `GroundCover.cover` on every walk top. The kind is grass
unless `--ground=` says otherwise. Nothing is laid without the underground
look.

**Registration**, in `scripts/city_kit.gd` (the family's file):

```gdscript
const CityLandmarks = preload("res://scripts/city_kit_landmarks.gd")
# PIECES:  ... + CityLandmarks.PIECES
# NAMES:   NAMES.merge(CityLandmarks.NAMES)   (or list the three)
# in piece(id, seed_value, weathered, opts):
if id in CityLandmarks.PIECES: return CityLandmarks.piece(id,seed_value,weathered,opts)
```

A scene that wants the court's roots to swing hangs `meta.ropes`, each a
SwingRope at `piece.transform * anchor`, and calls `advance` and
`try_catch` each frame. A scene that wants breaks needs the hub as each
body's `breaker` (see the yard's `Slot`).

## Sizes (from the kit's numbers)

### Court (`city_court`)

- **Alley:** 12.0 m between the taluds' feet (LANE + 2 SET_OFF) and 26.4 m
  long (6 CELL). The end zones are LANE deep and wider: out to the tablero
  line, 19.7 m, which is the I's crossbar.
- **Talud:** 3.2 m high (2 SET_OFF) at 55°, steeper than SLIDE_AUTO 44°.
  She surfs it and never stands on it.
- **Ledge:** a SET_OFF wide on the talud's top. His shelf rule keeps him
  off it.
- **Tablero:** a COURSE, 4.8 m, up to the rim at 8.0. The rim-to-ledge drop
  is under the 6 m fall stun.
- **Stands:** three rows a SET_OFF high and deep, up to his promenade at
  14.4 m, which is LANE wide. The back steps down in three courses with
  SET_OFF ledges.
- **Footprint:** 66.9 m wide, 48.4 m long.
- **Rings:** three on each wall at z −8.8, 0 and +8.8.
  - Each is 2.4 m across with a 1.2 m hole.
  - Each hangs at 6.2 m in the jaws of a serpent beam that runs out from
    the rim. The beam is 1.2 m wide and its top is a perch flush with the
    rim.
  - The ring's middle is 0.6 m in from the talud's foot, so its root swings
    clear of the talud.
- **Roots:** 4.7 m long, the knot at hand height over the alley
  (SwingRope.KNOT).
- **Shaft:** an octagon 4.0 m across in the alley's middle, open down to the
  abyss.
- **The −Z end** breaks off over the abyss in tipped slabs.
- **Her ways up** (walker-only prisms, 1.2 m, a SET_OFF apart):
  - two set-off blocks of slumped facing at each ledge's +Z end;
  - four prisms up each end zone's wall to the rim;
  - two prisms on each course of the stands' back.

### Pyramid (`city_pyramid`)

- **Tiers:** four, each a COURSE: a 1.6 m talud battered 0.8 m under a
  3.2 m tablero with a glyph band. Treads are LANE (8.0 m clear of the
  next talud).
- **Mass:** base 79.2 m; summit at 19.2 m, 26.4 m square.
- **Stair:** the epic stair, `CityKit.stair` with flights 4, flank 0, heads
  and fault 2.
  - It is 73.6 m long and 11.2 m wide.
  - It stands out 38.4 m in front of the base. Its pitch is fixed, so the
    tiers can't carry it.
  - Its summit landing is the summit court's front.
- **Platform** (its isle): 88 × 126.4 m.
- **Shrine:**
  - Inside, 8.8 m square and 9.6 m high (2 COURSE). Walls 1.2 m.
  - A roof comb 6.4 m high, pierced twice. The top is at 37.2 m.
  - **Door:** 1.6 × 2.6 m, under a pale lintel (the tell). He is 4.37 m
    wide.
  - **Screen:** a SET_OFF behind the door, so there's no line in.
  - The floor, screen and back bench are all walker-only.
  - His swat reach is 4.37 m. The sanctum is 7.6 m in from the door.
- **West face:** two walker-only prisms per tier, then the tier's lip.
- **East face:** two fins per tier, 0.9 m thick, out 2.4 m and 1.8 m apart.
  That's her kick chimney; he is four times too wide.
- **Summit:** a CityFires `cresset` on the summit court.

### Hall (`city_hall`)

- **Pillars:** 2.2 m square, BAY 6.6 m, three bays per half.
- **Nave:** LANE, 8.8 m clear, with 10.8 m under its roof, over his head
  worn whole. The card's 7.8 m would put his head through the roof.
- **Aisles:** 1.8 m wide, 4.4 m under their roof. That's under his neck
  (6.55 m), so he never fits.
- **Crack:** 3.2 m. The low half sits SET_OFF lower and drifts 1.1 m
  across.
- **Fallen slab:** 7.9 m wide, 8.0 m long, at 12.8°. Its ends are bedded
  in each floor with the top a step (0.12 m) over each.
- **Roofs:** aisle tops at 5.2 m, nave tops at 11.6 m.
  - One aisle slab has slid away (east, bay 1). It leaves a kick chimney
    between the inner and outer pillar and a shaft of light.
  - One nave slab is gone in the high half.
  - The low half's crack bay is roofless; its nave slab is the one that
    fell.
- **Glyph steps:** three walker-only stele columns on the east aisle roof,
  a SET_OFF apart, up to the nave roof's lip.
- **Aisle screens:** walker-only carved screens, 2.6 m high, between the
  outer pillars.
- **Footprint:** 25.6 × 51.6 m.

## Proof (through the real play loop)

The drivers are throwaway, in `scratch/` and not committed: `routes.gd`,
`olmec.gd`, `shots.gd`. Her runs use the stick and the buttons, through the
yard's own loop.

**Her routes:** every one passes in both the torch and haze looks, with 0
errors.

| Route | Result |
|---|---|
| `court_ropes` | Ran into the +Z west root at 4.8 m/s and swung along the wall. Let go well timed (0.76) into the next root, then the third. Let go at 12.4 m/s and landed in the −Z end zone. Three roots chained. Top speed 16 m/s. |
| `court_slide` | Stepped off the ledge onto the talud and surfed it (15 frames, 7.8 m/s) down into the alley. |
| `court_climb` | Slumped block (1.6) and ledge (3.2). The four end-zone prisms to the rim (8.0). Out along a serpent beam to its head over the alley. |
| `pyr_stair` | Foot to summit in 15.5 s. Through the door, round the screen, into the sanctum. |
| `pyr_chain` | Up the west face: prism, prism, lip, four times to 19.2 m. |
| `pyr_chimney` | Kicked up the east chimney (4 kicks, the first off a pump) onto a fin top at 4.75 m, the tread's height. |
| `hall_slab` | Crossed the fallen slab from the high half to the low. |
| `hall_jump` | Ran and jumped the crack beside the slab. |
| `hall_roof` | Kicked up the aisle chimney (6 kicks) onto the outer pillar's top. Onto the aisle roof (5.2), up the glyph steps (the pump skips one), onto the nave roof (11.6). |

**His lanes:** `scratch/olmec.gd` uses his own sight, think, planner and
motor.

| Lane | What he did |
|---|---|
| Court (`--olmec=court`) | On the promenade he spotted her in the alley. He planted and inhaled from 14.4 m up, then leapt down into the alley at 13 s. |
| Pyramid (`--olmec=stair --no-fault`, haze) | He spotted her on the first landing and chased her up the stair, flight by flight. She kept about 26 m ahead in his sight. He was on the top landing at 14.4 s. She went in; he came onto the summit court and stood 12 m from her at the door. He lifted his head to look (scope), searched, gave up and walked back down the stair. 60 s inside: 0 catches, she never moved, 0 frames of him in the shrine. **The shrine is a true safe room.** |
| Pyramid with the fault | Same start. The fault landing (2) dropped under him and he fell into its chamber at 4.8 m. |
| Hall (`--olmec=hall`) | From the high nave he spotted her on the low half and inhaled her across the crack. He gulped and spat her, then chased over the fallen slab onto the low half (y −1.6) at 12 s. |
| Aisle | She stood in the west aisle for 60 s, twice. He never reached her (0 catches, nearest 7.4 m). In one run he spotted her between the inner pillars and held at the nave edge. In the other he never saw her. |

**Smoke** (`tools/smoke.py`, 400 frames), 0 errors:
- `studies/city_landmarks_yard.tscn`, torch and `--underground=haze`.
- `studies/run_layer.tscn --shape=sprawl --seed=2 --underground=haze`.

The rendered drivers end with the usual `~ShaderRD` exit line, which is
exit noise.

## Stills

The stills are in `captures/landmarks/`, which is gitignored. I looked at
all of them. The contact sheet is `sheet_landmarks.png`.

| File | What it shows |
|---|---|
| `far_all_haze` | From 280 m south: the plaza, the pyramid with its stair up the middle, the court's stepped banks west, the hall east. |
| `far_court_haze` | The court as an isle: stepped banks over a hollow, the beams and rings, its foundation tapering into the haze. The pyramid stands behind it. |
| `far_north_haze` | From behind the pyramid, 330 m off: the stepped triangle and the pierced roof comb, which reads at range. |
| `far_pyramid_haze`, `far_pyramid_torch` | The stair face, and the hall's two halves split by the crack. In the torch look the lit summit cresset is the one warm dot on the pyramid. |
| `far_hall_haze` | |
| `near_court_haze`, `near_court_olmec_haze` | The alley from the gate: rings in their serpent jaws, roots, the shaft, the slump and the end-zone prisms. In the second, the Olmec is in the end zone. He stands as tall as the rim, which reads right. |
| `near_court_alley_haze` | |
| `near_pyramid_haze` | The stair's cheeks and serpent heads, the talud-tablero tiers with glyph bands, the shrine and comb. |
| `near_shrine_haze` | |
| `near_hall_haze` | |
| `near_hall_out_haze` | The pillars, roofs and screens; the open aisle bay; the drop and drift across the crack. |
| `*_torch` | All the views again in the torch look, with the cressets lit. |

**What I changed by eye:**
- **Foundations:** they first read as flat boxes, a tabletop. They're now
  60 m deep and taper in each course, so each landmark reads as an isle.
- **Shrine and comb:** the shrine was raised from 4.8 to 9.6 m and the comb
  from 4.8 to 6.4 m. The pyramid read squat against its long stair.

**The haze:** its depth fog is the look's own, 0.0016 per metre. At 300 m
that only dims things to about 60%. The silhouettes hold from all four far
views.

## Model budget (`docs/art/model-budget.md`)

All three are procedural chamfered basalt blocks in the Olmec stone shader.
No Blender model.

| Piece | Stone triangles | Collision shapes | Build time |
|---|---|---|---|
| Court | 8.7k | 153 | 73 ms |
| Pyramid (own) | 1.35k | 161 | 48 ms |
| Pyramid's epic stair | about 4.1k | | |
| Hall | 2.6k | 72 | 22 ms |

The court's six rings are smooth tori: 24 × 10 with per-vertex normals,
which is painterly, not faceted. That's about 480 triangles each, 2.9k for
the six. They were 32 × 12 (4.6k) before I cut them.

| Trick | Applies? | Estimate |
|---|---|---|
| Silhouette geometry | Used: chipped block corners, the tipped slabs at the broken end, the crack's lip, the snapped stumps, the pierced comb. Faces are the shader's. | Against modelled chips, about 5–10× fewer triangles. |
| Vertex-colour grime | Used: foot occlusion and tone in COLOR, as in the kit. Free. | No AO texture or pass. |
| Import LODs and visibility ranges | **Apply next, strongly.** These are landmarks seen from 150–300 m. A far proxy could be the foundation, the massing boxes and no rings, runes or prisms: the court about 1.5k triangles, the hall about 800. A visibility range on the runes surface past 80 m saves a draw each. | About 9k triangles and 3 draws in the yard's far views; 0.1–0.2 ms with several layers of landmarks. |
| Instancing / MultiMesh | The rings (six identical tori) and the prisms could be one MultiMesh each. | About 2.4k triangles of unique mesh and 5 draws saved. |
| Sculpt high, bake low | Would apply to the rings' serpent heads, now 4 blocks each, and the stair's serpent heads (city-kit round 1's open question). | A 2–3k baked head against blocks: costs triangles, buys looks. |
| Parallax depth | Optional for the talud's polished slabs and the glyph bands. | About 0.1 ms. |
| Rigid parts on bones | Doesn't apply. Nothing is rigged. | – |

**Lights:** four unshadowed cressets in the yard: two on the court, one on
the summit, one in the hall. They're out unless lit.

## Limits

- **The roots don't collide while ridden.** That's SwingRope's limit. Swung
  hard toward the wall, she can pass through the talud. The rings are sited
  so a swing along the wall is clear.
- **The stair stands out 38 m in front of the pyramid.** The epic stair's
  pitch (12-step flights plus 8.8 m landings) is fixed and shallower than
  the tiers. Side on, it reads as a processional ramp up to a steeper
  pyramid.
- **He gives up on a long stair.** Out of his sight he stops climbing and
  goes back. In the fault run, once she was out of sight he stayed in the
  chamber, seeking, for over 200 s. Last round he climbed out of it, so
  this may be his search state rather than the chamber. Not chased down.
- **A lit cresset didn't draw him from 57 m** in the beacon test
  (`--lit --olmec=landing`). He roamed off and never turned to it. I didn't
  find out why; it may be because the cresset is stood lit (`burn`) before
  the scene is in the tree. The fires round's own torch lighting worked.
- **The aisle isn't a sight refuge.** The screens hide her from outside.
  Between the inner pillars (4.4 m gaps) he can see her from the nave, but
  he can't reach or follow her.
- **He climbs onto the hall's aisle roofs** (4.4 m wide, 5.2 m up) while
  roaming. They are wide enough for him. The roof route is shared, not
  hers alone.
- **Not placed by the generator.** These are kit pieces with metadata.
  Registration in `city_kit.gd` is left to its owner (snippet above).
- **No ring break, no ball, no hall collapse.** The card's rolling ring,
  the court ball, the pillar breaks and the hall collapse aren't built. The
  only breaks are the stair's fault and the cressets.
- **Collision seams:** columns overlap by `CityKit.SEAM`. Before that,
  she fell through a seam where two boxes only touched.

## Tests

None were added (prototyping). No existing file was changed; the only
additions are the new files above. No committed test loads them. As far
as I know no test breaks. The full suite wasn't run.

## Open questions

- Should the stair keep standing out from the pyramid, or should the city
  have a steeper "temple stair" variant that sits in the face?
- Should the shrine be a safe room with no counterplay at all (as built)?
  Or should a lit cresset outside, or a shockwave on the roof, flush you
  out?
- Should the aisles hide you from his sight too (screens on the nave side,
  or narrower pillar gaps), or stay reach-only refuges?
- Should the hall's aisle roofs be his? They are now, by width.
- Rings: keep the swinging roots, or make the ring rims hang points with a
  motor change (the card's twirl through the hole)?
