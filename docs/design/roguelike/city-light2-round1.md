# City light 2, round 1: the sun-mirror and the relief face

Two pieces of the underground Olmec city kit, from the round 3 cards in
`brainstorm/round3-olmec-city/`:
- **The sun-mirror** (`maker_mirror`, kit-k6-light.md), with the light
  shaft that feeds it and a sun plaque its beam wakes.
- **The relief face** (`oc_relief`, kit-k3-climb-lanes.md): a cliff carved
  as one seated lord in profile. You jump-catch his carving. The Olmec
  climbs the stone.

Branch `kit/city-mirror-relief`, off `roguelike` 6f0129fc.

## Play it

    ./run-city-light2.command                        # torch look (the default)
    ./run-city-light2.command --underground=haze     # L flips torch / haze

This opens `studies/city_light2_yard.tscn`, a basalt plaza with a whole
Olmec posted below the relief, facing the plaza.

- **The sun-mirror** stands mid-plaza, under a light shaft falling from the
  dark.
  - Climb its pedestal (1.6 m, one jump).
  - Hop on a treadle: each landing turns it one 15° notch with a clack.
    The east slab turns its bearing up, the west slab down.
  - At start the beam points south, at you.
  - **6 hops east** aim it at the far cresset, which catches. Every Olmec
    in reach turns to it and walks over.
  - **12 hops back west** aim it at the sun plaque on the west block. The
    plaque wakes and six glyph steps grind out of the wall. That is the
    hidden route up the block, to an unlit cresset on its top.
- **The sweeping mirror** stands south-east, fed by a cresset that burns
  from the start. Its beam is pitched down and rakes the floor of your way
  north, back and forth every 7 s.
  - In the beam you are lit for his sight.
  - The drums cut the beam (the ray stops at them), so their lee is dark.
- **The relief face** is north: a 17.6 m cliff, 44 m wide, its 14 m panel
  carved as the seated lord.
  - Jump-catch his carving's bosses up the nose side, ten in all, to the
    top.
  - Light the cresset up there with your torch, put the torch out (T) and
    step back. The Olmec turns to the light, climbs the face behind the
    lord's shoulder, and his hands come over the helmet's crown.

Keys:
- T: torch out or lit again.
- K: the pieces as built (fires out, mirrors back, plaque asleep).
- R: all back. B: the Olmec back.
- J: his sight overlay. F1: numbers (the mirror's bearing, fed, turns,
  lightings; the light on you).
- 1-4: stations (start, the mirror, the relief's foot, the relief's top).

Flags:
- `--underground=haze|torch`, `--day`
- `--no-body`, `--body-at=x,z`, `--body-face=x,z`
- `--body-knob=k=v`, `--head-knob=k=v`, `--sight-overlay`

## The APIs

`scripts/city_kit_light2.gd`. Preload it; it has no `class_name`. It has
`PIECES` (id to a line) and `build(id, parent, xform, opts)`. Sizes go by
`WorldScale.wanderer`, through `RuinKit.SET_OFF`.

### `mirror(parent, xform, opts) -> SunMirror` (maker_mirror)

**Opts:**
- `mode`: `"turn"` (treadles), `"sweep"` or `"fixed"`.
- `bearing`: degrees; 0 throws along local +z.
- `step` (15), `pitch` (degrees; 0 is level).
- `reach` (64 m).
- `sweep`: `[from°, to°, period s, hold s]`.
- `source`: any node with `lit`. If unset, it uses any shaft over it or a
  lit fire within `FIRE_CATCH` 14 m.
- `seed`.

**The build:**
- A 12-sided basalt pedestal, 2.3 m in radius and SET_OFF tall, with a
  rune band.
- Two treadle slabs on the deck, with chevrons cut in them.
- The turning part:
  - a collar and two yoke arms;
  - a ring of 12 stone blocks with a heavier block (the brow) on top;
  - a 2.2 m concave obsidian disc (`shaders/city_mirror.gdshader`: a fake
    environment plus a Fresnel, no reflection pass). Fed, it glows as a
    white-hot coin.

**Fed, every frame:**
- One ray (mask 1, its own bodies excluded) from the disc along its
  bearing.
- The visual rod (`shaders/city_beam.gdshader`: an additive open cylinder
  with soft edges and drifting dust) is laid from the disc to the hit.
- At the hit: a glow quad and one unshadowed OmniLight.
- A `BeamLight` covers the segment.
- **Fires.** The first unlit Beacon within `CATCH` 1.6 m of the segment has
  its owning fire's `light()` called. That is any Cresset or crown.
  - The fire gets meta `mirror_lightings`.
  - The mirror emits `lit_target`.
- **Other targets.** Every node in group `beam_targets` gets
  `beam_touch(from, to, by)`. Mirrors and sun plaques answer it, so a beam
  on another disc feeds that mirror: relays work.

**Turning:**
- A **landing** of the wanderer's on a treadle (`motor.grounded` turning
  true there) calls `stamp(±1)`.
- The turn eases over 0.35 s with a small overshoot, then emits
  `turned(bearing)`.
- Walking or climbing onto a treadle does not turn it. A hop or a fall
  does.

**API:**
- `stamp(way)`, `reset()`, `disc_centre()`, `beam_dir()`, `beam_touch(...)`.
- State: `fed`, `bearing`, `turns`, `lightings`, `beam_from`, `beam_to`,
  `beam_hit`.
- Signals: `fed_changed`, `turned`, `lit_target`.
- Collision: the pedestal and the disc are solid (layer 1), so he walks
  round it. The disc turns with the yoke.

### `BeamLight` (a `SightLight` stripe)

`a`, `b` (world), `radius` and `strength`. `light_at(p)` falls off with
the distance to the segment, so standing in a beam lights you for the
Olmec's sight. `LightLevel` takes it like any SightLight, and no engine
file was changed. A mirror's stripe is 2 m in radius, at strength 1.

### `shaft(parent, xform, opts) -> LightShaft` (maker_shaft)

**Opts:** `height` (48), `radius` (1.5), `lit`, `strength`.

**The look:**
- A rod of pale light, faded in from the dark above.
- A pool on the floor.
- One unshadowed SpotLight.
- A `BeamLight` from the floor up 4 m (standing in it shows you).

**API:** group `light_shafts`; `covers(p)`, `light()`, `douse()`,
`lit_changed`.

### `plaque(parent, xform, opts) -> SunPlaque` (maker_sunplaque)

**Opts:**
- `steps`: `[[top middle (local), size]]`. These are its hidden glyph
  steps, recessed into the wall and switched off.
- `radius` (0.9), `seed`.

**Waking.** A beam ending within 1.5 radii of it wakes it:
- It glows, and a light comes on.
- The steps grind out one after another, with a shudder.
- Each step's walker-only collision comes on once it is out.

**API:** `wake()`, `reset()`, `awake`, signal `woke`.

### `relief(parent, xform, opts) -> Relief` (oc_relief)

**Opts:**
- `width` (40): the cliff.
- `deep` (24): its top's depth.
- `seed`, `cover` (true).

**Local frame:**
- y 0 is the foot. The top is `top` (17.6 m at size 1).
- z 0 is the wall plane the bodies collide with. The carving faces +z; its
  field lies 0.5 m behind that plane, inside it.

**The build:**
- The carving is the Blender model (below), dressed in the city stone: the
  `CityStone` material, each vertex shaded as the kit's, its baked
  occlusion, worn high points and polished hold lips, moss on tops, and
  its rest place for the grain. LODs are made again by `ImporterMesh`.
- One **Decal** projects the baked normal and cavity maps onto the
  carving. It projects onto visual layer 20 only, so not onto the
  wanderer or the Olmec, and fades past 70 m.
- The flank stone has course lines, and a capping course forms the
  helmet's crown.
- The ground cover goes on the top.

**Collision:**
- One plain box for the cliff, layer 1. That is the Olmec's lane: he
  climbs any of it.
- The **holds** are clean walker-only boxes, from the model's `Hold_NN`
  empties, each from the wall plane out to the boss's front. His rays
  never read them.

**API:** `holds` (`{name, box}`, foot first), `hold_tops()`, `lip()`,
`triangles`.

**The holds** (at size 1), one SET_OFF apart. Each is beside the last, so
one jump catches it. Two apart they stack with 1.9-2.2 m of room between.

| # | hold | x (m) | top (m) | out of the wall (m) |
|---|---|---|---|---|
| 0 | base band, full width | -7..7 | 1.6 | 0.9 |
| 1 | knee | 0.87..2.53 | 3.2 | 0.9 |
| 2 | bag (in his hand) | 2.81..4.29 | 4.8 | 0.92 |
| 3 | armlet | 0.90..2.40 | 6.4 | 0.86 |
| 4 | pectoral | 2.77..3.88 | 8.0 | 0.9 |
| 5 | collar knot | 0.91..2.29 | 9.6 | 0.86 |
| 6 | lip plug | 2.75..4.15 | 11.2 | 0.9 |
| 7 | ear spool | 0.65..2.45 | 12.8 | 0.92 |
| 8 | helmet's snout | 2.60..4.25 | 14.4 | 0.9 |
| 9 | helmet's knot | 0.75..2.40 | 16.0 | 0.88 |
| - | the lip (the helmet's crown) | | 17.6 | |

The rest of the carving stands at most 0.08 m proud of the wall plane, so
it never blocks his body.

## The registration snippet

```gdscript
const CityLight2 = preload("res://scripts/city_kit_light2.gd")
# in the family's PIECES:  ... + CityLight2.PIECES.keys()
# in stand(id, parent, xform, ...):
if CityLight2.PIECES.has(id): return CityLight2.build(id, parent, xform, opts)
```

**What a placement needs:**
- A mirror needs a source: a shaft over it, or a lit fire within 14 m.
  Give a sweeping mirror `pitch` -4 to -6 if its beam should rake a floor
  at his height.
- A relief needs room for him in front of the face and on its top: his
  8.8 m lanes. Its top is `deep` m back.
- A fire that burns from the start near a mirror should get
  `beacon.draw = 1`, or every Olmec walks off to it. The yard does this.

## The Blender script

`art/blender/city_relief/relief_build.py`, run with
`/opt/homebrew/bin/blender -b --python art/blender/city_relief/relief_build.py -- [--render=PNG] [--res=0.03] [--low=12000]`.
It takes about 40 s.

**The sculpt** is a height field (protrusion out of the wall) on a 3 cm
grid, 548k triangles. It is built from:
- soft-shouldered and domed masses (signed distances: ellipses, splines,
  strokes);
- the ten deep bosses, which are the holds;
- V-section incisions: the flame brow, the almond eye, the downturned
  mouth, the cleft feathers, the scutes and glyphs;
- an outline cut round the figure (champlevé);
- a two-octave chisel grain.

**The design** is after La Venta Monument 19 and the Chalcatzingo reliefs:
- The lord sits cross-legged and hunches forward, facing right. He wears a
  serpent-mask helmet, a jade collar and pectoral, an ear spool and a lip
  plug, and holds an incense bag in his forward hand.
- Behind him a feathered serpent rises from a rattle to a head over his
  shoulder.
- A glyph column runs in front of him: the crossed bands, the cleft, the U,
  the paw-wing.
- A base band of earth clefts runs under it all.
- The holds table (`HOLDS`) is the one source of truth. The script places
  each boss from it, cut in that boss's own language, and exports it as
  empties.

**The bake**, in numpy from the height field:
- **Vertex colours:** R is a 12-way horizon occlusion, G is convexity (worn
  high points), B is polish (the holds' lips).
- **Two 1024×1287 maps:** `assets/textures/city_relief_normal.png` (the
  high's normals) and `city_relief_cavity.png` (dark stone, its alpha the
  incisions and crevices).

**The low mesh:** a planar dissolve, then a collapse decimate, to 12,000
triangles.

**Out:** `assets/models/city_relief.glb`, with the objects `Relief`,
`Hold_00_base` … `Hold_09_helmet_knot` (location at the box middle, scale
its size) and `Wall` (its top middle on the collision plane). With
`--render`, a workbench still.

## Proof through the real play loop

The drivers are in `scratch/` and uncommitted. All pass headless with 0
errors, driven by the stick, the jump and the T key's handler.

**`l2_mirror.gd`** (torch out; Olmec posted at `--body-at=18,-30`, facing
away):
- The shaft feeds the mirror.
- He jump-climbs the pedestal and walks to the east treadle.
- **6 hops** take it to 90°, and the beam lights the far cresset 42 m off.
  `mirror_lightings` is 1, `torch_lightings` is 0.
- The Olmec turns to it at once (beacon turns 1, never hunting). He walks
  from 36.7 m to 6.5 m of it.
- Round the disc to the west treadle: **12 hops** take it to -90°, and the
  beam wakes the sun plaque.
- The light on him in the shaft: 1.0 (torch out, ambient 0.1).

**`l2_climb.gd`** (`--no-body`, torch and haze):
- From the relief's foot, as a player would: walk to the near end of each
  boss, turn, jump.
- Base, knee, bag, armlet, pectoral, collar, lip plug, ear spool, snout,
  knot, then the lip.
- **All ten holds and the top (17.6 m) are made**, with no retries needed.

**`l2_olmec.gd`** (the yard's defaults):
- From station 4 he climbs the top cresset's plinth, and the torch lights
  it.
- He walks back 10 m and presses T (torch out).
- The Olmec turns to the light and walks to the face, then:
  - `feel` at the foot;
  - **`climb`** at x -2.26 on the panel (behind the lord's shoulder) from
    15.5 s;
  - `mantle` over the crown at 23.5 s;
  - he stands on the top, 18.3 m (his origin).

**`l2_sweep.gd`** (torch out, `--no-body`), over 17 s:
- In the open lane he is lit to 1.0 for 1.5 s of every pass, and 0.1 the
  rest.
- In a drum's lee he is never past 0.39.

**Smoke** (`tools/smoke.py`, 400 frames), 0 errors each:
- `studies/city_light2_yard.tscn` with no flags (torch),
  `--underground=haze` and `--day`.
- `studies/run_layer.tscn --shape=sprawl --seed=1`.

The headless import is clean.

## Stills

Rendered with the study's own scene, a pinned camera (`scratch/l2_shots.gd
--rendered`, `--set=relief|mirror|sweep|climb|olmec`, `--tag`, scene args
for haze). I looked at all of them.

They are in `docs/design/roguelike/city-light2-round1/`. That folder is not
committed: `/docs/**/*.png` is gitignored. The full sets are in
`captures/city_light2/`.

| File | What it shows |
|---|---|
| `relief_far_torch.png` | the face from the plaza, 48 m: a carved panel in the cliff, the lord, the serpent and the glyph column read |
| `relief_wide_haze.png` | the same in the haze |
| `climb_side_torch.png` | him on the armlet, the torch warming the bag and pectoral bosses |
| `sheet_mix.png` | (1) relief in haze; (2) the mirror's beam to the lit far cresset, haze; (3, 4) the sweep, torch and haze, before the slope; (5, 6) climbing, torch and haze |
| `sheet_sweep_relief.png` | the pitched sweep raking the floor, the drums cutting it, the shaft falling on the mirror, torch and haze; the relief close and wide (rounded feathers) |
| `sheet_mirror_torch.png` | the beam from the side, from above, the game camera, the plaque awake with its steps out |
| `sheet_crown_torch.png`, `olmec_crown_3_torch.png` | from the relief's top: his hands, then his head and lit eyes coming over the crown; then his dust as he hauls up |

**What I tuned by eye:**
- **The figure.** The first pass read as a blob with boxes glued on. Now:
  - the head is bigger and leans forward, with the face in profile;
  - the holds are cut as the lord's own things (an oval knee, a tied bag,
    a banded armlet, a plaque, a disc spool, a fanged snout);
  - the outline cut is deeper.
- **No spikes.** The serpent's feathers read as spikes against the art
  direction. They are now rounded lobes, and the helmet's crest ends
  round.
- **The beam.** It was a solid white bar. Its strength is now 0.32 with a
  softer core and more dust.
- **The grass tufts** turned white behind the beam: they read the screen.
  The beam, shaft and glows now draw last (render priority 100).
- **The sweep's beam** ran at the disc's 3.35 m, over his head, so it lit
  no one. It is now pitched -5.5° so it rakes the floor.
- **The crown stills** are framed from the top, off to the side. His climb
  dust swamped the first framing.

## Model budget (docs/art/model-budget.md)

| piece | triangles |
|---|---|
| relief carving (low) | 12,000 (sculpt 548k) |
| relief cliff and capping | about 300, chamfered blocks |
| mirror (pedestal and treadles) | about 900 (estimate) |
| mirror's turning part (collar, yoke, ring, disc) | 1,536, of which the disc is 320 |
| sun plaque and six steps | 932 |
| beam and shaft rods | 28 each (open 14-sided cylinders) |

- **Sculpt high, bake low: applied.**
  - The relief went from 548k to 12k triangles, about 98% fewer.
  - The occlusion, convexity and polish are baked into vertex colours.
  - The normal and cavity maps carry the incisions and grain the low mesh
    can't, through one Decal. That is one clustered decal for the whole
    panel, with no extra pass.
  - Saving against drawing the sculpt: about 536k triangles, an estimated
    3-6 ms on a mid GPU.
  - Against a 50k mid mesh that would hold the grooves in geometry: 38k
    triangles, about 0.3-0.5 ms.
- **Import LODs and visibility ranges: applied in part.**
  - `ImporterMesh.generate_lods` makes the carving's LODs again (the
    head's round 10 lesson). The decal fades past 70-100 m.
  - Estimated: the 12k carving falls to about 2-3k past 60 m, saving
    about 9k triangles and 0.05-0.1 ms at the far views.
  - Not done: a visibility range on the beam's spot light past 80 m.
- **Silhouette geometry: applied.** The bosses, the helmet's snout, the
  serpent's head and lobes and the frame are real outline. Detail on flat
  faces comes from the maps and the stone shader. The mirror's ring is 12
  chamfered blocks (about 150 triangles), as the card asked.
- **Vertex-colour grime: applied.** The relief's baked R/G/B and the kit
  Mesher's foot occlusion cost nothing.
- **Parallax depth: not applied.**
  - The decal's normal map already carries the incisions. A height map
    would read deeper at grazing torchlight for about 0.1 ms.
  - `olmec_stone.gdshader` has no texture input, and the parallel round
    owns the city stone. That is why the maps go through a Decal instead.
- **Rigid parts on bones: doesn't apply.** Nothing is rigged. The yoke is
  one node turned by script.
- **The mirror: a fake reflection, not a pass.** The shader's environment
  and Fresnel stand in for a planar reflection. That saves an estimated
  1-2 ms (a second camera) for each mirror on screen.

**Lights:**
- A fed mirror has two unshadowed OmniLights (the beam's spot and the
  coin).
- A shaft has one unshadowed SpotLight.
- A woken plaque has one OmniLight.
- In all, the yard has 13 omni lights and 1 spot.

## Limits

- **The figure is a first sculpt by script.** It reads as an Olmec carving
  from range, in both looks. Close up it is still simple: the head is
  blocky and the hands schematic. A hand pass in Blender's sculpt mode on
  the same height field, keeping the bosses, would lift it.
- **Clipping.** The Olmec climbs the face's plain collision 1.46 m out (his
  standoff), and the carving's masses are inside that plane. In the yard
  he climbs behind the lord's shoulder (x -2.3), clear of the holds, which
  start at x 0.65.
  - Where he climbs is his planner's choice, his straight line to his
    goal.
  - Climbing through the nose side, his 4.4 m body would pass through the
    bosses, which stand 0.9 m proud.
  - There is no Olmec-only layer to give him the bosses as a wall.
- **The card's breakable lugs** (nose, lip plug, spool falling when he
  grabs them) are not built.
- **The mirror doesn't break**, and it is no carom face for a thrown body.
  - His bulk walks round the pedestal.
  - The card's shatter, shards and tossed-body reflection are not built.
  - The wind blaster doesn't turn it.
- **Beam occlusion is the ray's only.**
  - A beam stops at the first solid collider. Walker-only stone and bodies
    don't stop it, and the wanderer has no collider.
  - The `BeamLight` is lit along the whole segment. Its 2 m radius reaches
    a little round a drum's edge: 0.39 in the lee.
- **The treadle reads any landing on it.** A long fall onto it turns it
  too, which is intended. Two hops in quick succession both count.
- **The shaft** is a look and a source, with no ceiling gap. The
  underground has no ceiling to cut one in.
- **Not placed by the generator.** `scripts/city_kit.gd` (the parallel
  round's file) doesn't register these yet. The snippet is above.

## Tests broken

None expected. The round adds new files only:
- `scripts/city_kit_light2.gd`
- `shaders/city_beam.gdshader`, `city_glow.gdshader`, `city_mirror.gdshader`
- `art/blender/city_relief/relief_build.py`
- `assets/models/city_relief.glb`
- `assets/textures/city_relief_{normal,cavity}.png`
- `studies/city_light2_yard.*`
- `run-city-light2.command`

No shared script was edited. The full suite was not run (prototyping).

## Open questions

- **Treadles or something else?**
  - A hop is a notch, which is readable but slow: 12 hops for a half
    turn.
  - The options: bigger notches (30°), or a hold-to-turn (pushing a
    capstan bar).
- **The sweep's pitch.** A beam raking the floor makes a crossing. A level
  beam reads more like the card's "rod through dust" but lights no one.
  Keep both by placement?
- **Should the Olmec react to the beam itself**, beyond what it lights? For
  example, he could turn when it crosses him, or the lit spot could be a
  weak beacon.
- **The relief's figure:** keep the procedural sculpt as the base, or
  hand-sculpt it?
- **Clipping:** give the Olmec an Olmec-only "envelope" layer over the
  carving (an engine ask), or place reliefs so he always climbs the back
  half?
