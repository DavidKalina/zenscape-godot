# Islet unit: round 1 handoff

## What was built

One floating rock chunk, the smallest piece an isle is meant to be composed
of, built from a seed and seven knobs. All new, opt-in files; no existing isle,
motif or shared builder changed.

- `scripts/kit_isle/islet_unit.gd` (`class_name IsletUnit`): the builder.
  `IsletUnit.build(spec)` returns a Node3D with its origin at the middle of its
  turf top. It holds these children:
  - `Rock`: the body. It sits set back under the lip, then has beds stacked
    like plates. Each bed's top stands a little proud of the bed above, which
    gives an up-facing ledge, and its face cuts back under going down, which
    gives an undercut. Each bed is split round into blocks set in or out.
    Under the beds is a blunt cap with a cluster of hanging drips: one lead and
    several short ones, plus a few short ones off the bed feet. The drips are
    stepped, bent and off-centre. Knobs through the turf are drawn as a second
    surface with flat normals so they read as angular stone. Baked shade sits
    in the vertex colour's red (the band under the lip, the undercuts, the drip
    creases).
  - `Turf`: a hummocked polar grid. The lip rolls out over the rim and hangs as
    a thin ragged earth hem, and its under-face runs back into the rock as the
    dark shadow line.
  - `Drape`: thin grass strands hanging under the hem.
  - `Tufts`: a MultiMesh of dry grass clumps, in drifts, thickest along the rim
    so the skyline breaks.
  - `Growth`: one dead tree or a low shrub, depending on growth and seed.
  - `Roots`: HangingRoots strands (the kit's own mesh and shader) from under
    the hem, off the shelves and off the drips. They are retinted grey-brown
    and thinned through a copy of its shader; HangingRoots itself is unchanged.
  - `Body`: one concave collision shape on the solid and turf layers, so he
    can walk the top.
- `shaders/islet_rock.gdshader`: dusty, faded rock painted triplanar in the
  mesh's own space:
  - warped level beds, each with its own tone, plus thin laminae;
  - umber seams;
  - Voronoi block joints on the sides, with each block given its own normal
    tilt and tone;
  - spalls on what faces down;
  - a value gradient from bone at the top through ash to a cool dark underside;
  - pale lichen on up-facing ledges;
  - a derivative bump.

  Fine detail fades by pixel footprint. The scene's own ambient is off in the
  game's look rig, so the rock lights its shade with the rig's hemisphere
  globals and the look pass's cloud bounce, as the game's other shaders do.
- `shaders/islet_turf.gdshader`: dry straw and faded sage in drifts, with
  darker sage hollows, bleached patches and bare dirt. The lip's earth face is
  muted umber with pale root threads. The drape uses the same code with culling
  off.
- `shaders/islet_tuft.gdshader`: the tufts, which sway.
- `scripts/kit_isle/islet_unit_node.gd`: a unit as a node with the layout
  contract (`layout_pose`, `layout_tunes`, `layout_retune`). Every knob is a
  tune, and a retune rebuilds the unit under the same node.
- `studies/islet_yard.tscn` (`studies/islet_yard.gd`, `studies/islet_yard_sky.gd`):
  - It is built on the kit isle base: the game's look rig, its clouds and
    motes, and the pilot, who starts on the hero's turf.
  - It shows one hero unit and a ring of 8 siblings at varied distances and
    heights.
  - Each unit is placed through `scripts/layout_overrides.gd` as
    `islet_yard/hero` and `islet_yard/sib_1` .. `sib_8` (layout file
    `layouts/islet_yard.json`).
  - The yard leaves out the lodestone, the kit life, the KitFlora carpet and
    the parked plane.
- `run-islet-yard.command`: the launcher.

## Knobs

Each knob is a spec key. `IsletUnit.KNOBS` holds each one's default and range.

| knob | range | effect |
|---|---|---|
| seed | int | every draw |
| size | 1.5..18 m | top radius: hop boulder to landing slab |
| shape | 0..1 | wide shallow ledge .. narrow deep spire (depth, bed count, how fast the envelope narrows) |
| lean | 0..1 | body and drips lean off plumb |
| drip | 0..1 | many short drips .. one deep lead drip |
| lopsided | 0..1 | the cap and lead drip off the middle; the mass hangs further out on one side |
| growth | 0..1 | bare .. overgrown: tufts, lip reach and droop, drape, roots and their length, tree or shrub |
| weather | 0..1 | joints, block offsets, lichen, umber staining, bites out of the rim |

`IsletUnit.sibling(seed, base)` draws a sibling's knobs round a family's middle
(`base`). The size is drawn on a log scale; shape, drip and lopsided get wide
draws, the rest narrower ones.

## Running the yard

```
./run-islet-yard.command                          # hero + 8 siblings
./run-islet-yard.command --family=3 --ring=12     # another family
./run-islet-yard.command --hero=seed=12,shape=0.9,drip=1
./run-islet-yard.command --base=growth=1,weather=0.2
./run-islet-yard.command --solo --hide=Turf       # parts hidden to look at one
python3 tools/smoke.py studies/islet_yard.tscn
python3 tools/shot.py studies/islet_yard.tscn --at 14,29.6,4 --look 7,28.3,0 --settle 60 -- --no-title
```

Hero seed 29 has the dead tree. Seeds 5, 6, 8, 12, 15, 16, 19, 26 and 33
also grow one at the hero's knobs.

## Stills

These are in this worktree under `captures/shots/islet_unit/`, which git
ignores:

- `far.png`: the family
- `mid.png`: the hero
- `lip.png`: close on the lip, the rock face and the drip
- `rock.png`: the strata and undercuts from below the rim
- `under.png`: the underside against the sky
- `sheet.png`: a contact sheet of the five above plus `before_approach.png`
  (the current look), for comparison

## Smoke and tests

- `python3 tools/smoke.py studies/islet_yard.tscn` passes: 400 frames, no
  errors.
- The yard builds 9 units in about 50 ms.
- No committed tests: this is a prototyping round.
- No shared file changed, so no existing test should break.
  `test_world_scale_guard.gd` passes with the new files.

## Model budget (docs/art/model-budget.md)

The hero (size 9) has about 6.3k drawn triangles (rock, turf, drape and
tree). On top of those come about 390 tuft instances (51 triangles each,
about 20k instanced triangles) and about 19 root strands (120 triangles each).
The whole yard has 32k drawn triangles plus about 100k instanced in tufts.

- **Vertex-colour grime: applied.** Shade is baked per ring: under the lip,
  under each undercut, at drip creases. It costs nothing at runtime.
- **Silhouette geometry: applied.** The beds, ledges, undercuts, block offsets,
  drips and ragged lip hem are real geometry. Flat faces get their detail from
  the shader.
- **Import LODs and visibility ranges: apply next.**
  - The tufts already end at 220 m.
  - A second rock mesh at half the segments past about 150 m would save about
    50% of the rock's triangles on distant units (about 2.5k each at size 9).
  - A tuft range of about 120 m on small units would cut most of the instanced
    triangles in a composed isle.
  - Together these are estimated at well under 0.1 ms.
- **Sculpt high, bake low: not used.** The units are procedural, and the shader
  fakes the detail with a bump and per-block tilts. That detail is pixel cost
  rather than triangles: three Voronoi lookups and about six noise octaves on
  the rock. Rock filling a 1440x900 screen is estimated at 0.2-0.5 ms on the
  GPU. Baking a few hero drips and blocks to normal and AO maps would trade
  that for texture memory if the GPU cost shows up.
- **Parallax depth: not used.** The derivative bump carries the seams. Parallax
  would deepen the joints close up for about 0.1-0.2 ms more.
- **Rigid parts on bones: not applicable** (static).

## What's still weak

- From afar the siblings read as spinning tops: a flat disc, stacked rings and
  one spike. The drip cluster and lopsidedness are there but too subtle at
  100 m+. The many-short-drips setting doesn't read as a cluster from far off.
- Rock close-up is better than before but still a little soft, like leather:
  the bed faces are smooth bands, and only the shader breaks them up. The beds
  still band evenly round the whole unit.
- Lichen hardly shows: the up-facing ledges are thin, and most of the visible
  faces are vertical or face down.
- The tufts are pale spikes close up and fine from afar. The turf top is still
  fairly flat in silhouette apart from the tree and the rim tufts.
- The shrub is a few smooth balls.
- The lip's under-face shows as a black ring when seen from straight below.
- Bed tones and stains are painted in each unit's own space, so two touching
  units won't share strata.
- The rock colour leans a little warm and khaki under the game's warm sun;
  the palette uniforms can be tuned live.

## Round two suggestions

- **Compose units into an isle.**
  - Place 3-7 units of one family overlapping: a big landing slab plus smaller
    satellites tucked under and round its lip, their tops at stepped heights.
  - Let units fuse below the turf: a shared cap, or one unit's drips hanging
    off another's beds.
  - Paint strata in world space, or in the isle's frame, so beds run on across
    units.
  - Keep the landing turf rule: the slab unit is the runway.
  - Name each unit `<isle>/<unit>` so the world view can move and tune them.
- **Haze and depth layering.**
  - Fade units toward the sky's horizon colour with distance and height.
  - Make far siblings bluer and paler, with undersides lifting into the cloud
    light, so ranks of isles separate.
  - Add a soft cloud skirt or mist band under each isle's belly.
- **Silhouette.**
  - Add a second lead drip on some seeds.
  - Make the lopsided side's beds step lower than the other side's.
  - Let a few drips break off as small floating rocks under the unit.
- **Lichen and moss.** Widen some ledges (a weather-driven ledge width) so the
  up-facing lichen reads, and add moss on the shaded undercuts.
- **LOD** as in the model budget above, before isles get many units.

---

# Round 2: shape and grass

The rock shader, palette and lip shadow line are as round 1 left them. This
round changed the unit's shape, its grass and the yard's layout. Every
change is inside `IsletUnit`, its node and the yard. KitFlora, KitLook and
the aqueduct isle's flora are used as they are, with no edits.

## What changed

- **Grass.** The unit's own dry tufts (`islet_tuft`) are gone, and the
  shader file is deleted. The crown now grows the isles' own grass:
  - `KitFlora.Grow` runs with the aqueduct isle's carpet settings
    (`scripts/shared/aqueduct_isle_flora.gd` `carpeted`), so it has the carpet, the
    shag, the variety (tussocks, thatch, seed heads), the contact darkening,
    the rolling height and the tilt. Its flowers come too. `calm` runs after
    it, as on the aqueduct isle.
  - Its `probe` is the unit's own height function (`Unit.probe`), so it
    needs no physics. It returns NAN off the lip's roll and inside a rock
    knob's or the shard's foot. In from the rim it also returns NAN on
    slopes past the palette's rock slope.
  - The grass's outline is the lip's roll, so wild tall grass grows out over
    the crest onto the roll: the spill.
  - Growth scales the tufts a square metre (x0.3..1) and the shag's height
    (x0.8..1.9). Below growth 0.06 the crown is bare.
- **Turf ground.** The top and the lip's crest and roll are drawn as a
  `KitLook.GroundMesh` with `KitLook.turf` tones, in the isles' ground
  material, so the blades root into the same ground as on the aqueduct
  isle. The lip's earth face, hem and under-face stay in `islet_turf`, as
  the dark shadow line. The drape's strands are golden and olive
  (`DRAPE_*`), to match the carpet as it renders.
- **Bodies.** The shape knob now picks one of five bodies, each taking a
  fifth of its range. Within its fifth, the knob goes from shallow to deep
  (`IsletUnit.body_of`, `BODIES`, meta `body`):
  - **slab** (0..0.2): the outline is stretched and cut straight across
    once or twice, like a broken edge. The underside is a wedge, much deeper
    on one side. The whole unit is tilted 11-19 deg, with a few short drips
    along the deep edge.
  - **boulder** (0.2..0.4): the belly swells out past the lip (up to 1.18
    of the rim), then rounds under to a blunt foot. It has a domed top and
    0-2 stubs.
  - **cone** (0.4..0.6): round 1's stepped cone with a lead drip.
  - **cluster** (0.6..0.8): a shallow mass with a broad flat underside,
    from which hang 3-7 deep lobes of varied length. The lobes are spread on
    a golden-angle spiral, the lead lobe longest, with small drips between.
    This reads as separate teeth at 100 m+.
  - **spire** (0.8..1): a stretched, blade-like outline over a tall,
    narrowing, strongly leaning column, tilted 9-17 deg. A stepped stone
    shard stands 1.2-2x the radius out of its crown, along the same line.
- **Lip.** The reach is now `R*0.05` (0.25..0.9 m) and the droop `R*0.075`
  (0.35..1.3 m), both times growth. The face bulges out, sod tongues are
  more frequent and longer, and the rock under the lip is set further back
  (0.84).
- **Crown.**
  - A shoulder rises on one side, by 9-20% of the radius (half that on a
    slab).
  - There are 1-3 rises, of 4-10% of the radius.
  - A boulder's dome is higher.
  - There are more and bigger rock knobs (up to 3, 0.3-1.8 m), faceted.
  - A cone or boulder sometimes gets a low shard (a 25% chance).
- **The world view.** The shape tune is labelled with its bodies.
- **Yard.**
  - The siblings now stand in fixed layers (`SLOTS`): each has a bearing, a
    distance of 30-100 m, a height from -36 to +40 m off the hero's top, a
    body and a size factor. Seed jitter is added on top. Their names stay
    `islet_yard/sib_1..8`.
  - Five new far units, `islet_yard/far_1..5`, stand 250-450 m out at
    heights from -4 to +95 m. `--no-far` leaves them out.
  - The hero is now a cluster (shape 0.7).
  - He starts 2 m over the crown and drops onto it, since the crown is no
    longer flat.

## Knobs

These are the same keys and ranges as round 1. Only the meanings below
changed:

| knob | round 2 meaning |
|---|---|
| shape | the body: 0 slab, 0.2 boulder, 0.4 cone, 0.6 cluster, 0.8..1 spire; within its fifth, shallow to deep |
| lean | a spire leans 0.35..0.85 m a metre; the others 0..0.4 |
| drip | on a cluster: many lobes .. fewer, longer |
| growth | also the grass's thickness and its wild rim's height |
| weather | also how many rock knobs |

Constants: `GRASS_THICK`, `GRASS_SHAG`, `GRASS_FROM`, `DRAPE_*` in
`islet_unit.gd`, and `SLOTS` and `FAR` in `studies/islet_yard.gd`.

## Stills

These are in this worktree under `captures/shots/islet_unit_r2/`, which git
ignores. The camera spots are round 1's.

- `before_after.png`: round 1 on the left, round 2 on the right, for far,
  mid, lip and under.
- `far.png`, `mid.png`, `lip.png`, `under.png` and `top.png`: the hero's
  crown.
- `depth.png`: from behind and above the yard, looking back over it, which
  shows the layers best.
- `bodies.png`: the five bodies alone, all seed 29 and size 8, plus the
  depth view. The singles are `body_slab.png` .. `body_spire.png`.

```
python3 tools/shot.py studies/islet_yard.tscn --at 30,48,150 --look 0,20,0 --settle 60 -- --no-title           # far
python3 tools/shot.py studies/islet_yard.tscn --at -60,40,-120 --look 0,25,0 --settle 60 -- --no-title         # depth
python3 tools/shot.py studies/islet_yard.tscn --at 0,32,52 --look 0,18,0 -- --no-title --solo --hero=seed=29,size=8,shape=0.9   # one body
```

## Checks

- `python3 tools/smoke.py studies/islet_yard.tscn studies/aqueduct_isle.tscn`:
  both pass with 0 errors. The aqueduct isle is KitFlora's main caller, and
  KitFlora, KitLook and `aqueduct_isle_flora.gd` have no diff.
- A throwaway drive (`scratch/r2_walk.gd`) used real input: he lands on the
  hero's crown and walks to three points across it, staying grounded.
- The yard builds 14 units in about 650 ms, most of it the grass.
- No committed tests. No existing test is known to break: no shared file
  changed, and `islet_tuft` had no other users.

## Model budget (docs/art/model-budget.md)

- **Rock, ground, lip and drape.** These come to about 77k drawn triangles
  for the yard's 14 units. The hero has about 7.5k; round 1's hero had
  6.3k.
- **The grass.**
  - It uses the carpet's tuft at about 91 triangles an instance. The hero
    grows about 1.6k tufts plus tussocks, seed heads and flowers: about 145k
    instanced triangles. The yard comes to about 16k tufts and 1.4M
    instanced triangles.
  - Each tile only draws within the carpet's `grass_range` (220 m) and fades
    out over 15 m. The far units (250 m+) draw none, and from the hero
    about 0.6M are in range.
  - At the aqueduct isle's density, the estimate is 0.3-0.6 ms of GPU time
    for the grass in view. A tile crossing its fade range draws
    alpha-blended, which KitFlora notes as the real cost; `--flora-fade=pop`
    avoids it.
- **The geometry tricks.**
  - **Import LODs and visibility ranges: apply next.** A composed isle
    should draw its units' grass to a nearer range, such as 120 m for units
    under size 5. That would cut most of the instanced triangles at no
    visible loss, since the ground's tones carry the colour from afar. The
    round 1 note on a half-segment rock mesh past 150 m still stands.
  - **Vertex-colour grime and silhouette geometry:** applied, as in round 1.
  - **Sculpt-and-bake, parallax and rigid parts:** unchanged.

## What's still weak

- **Far depth.** The far shot shows different bodies at clearly different
  heights. Distance reads only through size and overlap, though: the game's
  screen-space haze barely fades rock at 300-450 m. A big far unit can
  read as a near small one. `depth.png` reads better than `far.png`.
- **The cone** is still round 1's spinning top. It is now one body of five
  rather than all of them.
- **The slab's wedge** is a smooth, dark plane on its deep side. It needs
  beds or blocks broken across it.
- **The crown's shoulder** reads in `top.png` and on the bigger units, but
  only gently on the hero from the mid shot.
- **The lip's earth face** reads at mid range but is a fairly even dark band
  close up.
- **The grass's ground** shows the carpet's orange earth where the carpet
  thins (drifts, the rolling height), as on the aqueduct isle. Under a
  small unit that reads as bare patches.
- **The grass is the carpet's tuft at its normal size.** On a 3.5 m unit it
  is fine; on a hop boulder (1.5 m) it will look coarse.

## Next: composing units into an isle

- **A composer.** Write `IsletUnit.isle(spec)` or a study that places 3-7
  units of one family, named `<isle>/<unit>`:
  - a big slab or cone as the landing turf, which keeps the landing-turf
    rule;
  - satellites tucked under its lip at stepped heights;
  - a spire or cluster as the landmark.
- **Fused undersides.** Let a satellite's top sit inside the main unit's
  bed band, so they read as one mass, and drop the hidden faces.
- **One grass run for the whole isle.** Grow one `KitFlora.Grow` over all
  the units' outlines, with a probe that asks each unit in turn. That gives
  one set of tiles rather than one a unit, and one `calm`.
- **A depth fade on the units' own shaders,** if far layering needs to read
  more strongly than the game's haze gives: `islet_rock` and the earth,
  toward the horizon colour. This is a look change, so ask the user first.

---

# Round 3: crag

Round 2's arrangement stays: the five bodies on the shape knob, the layered
yard, the far units. The unit is now built in a new style, the crag. Round 2's
unit is still there as `style` 0 (`--style=r2`) and builds as it did.

## What changed

- **Body** (`scripts/kit_isle/islet_crag.gd`, a subclass of `IsletUnit.Unit`):
  - **Outline.** From above, a ragged polygon: 8-17 corners, some notched
    in, some jutting, each edge broken at a point or two. Its vertices are
    the rock's columns, so the turf's rim lies on the rock's edge. A slab is
    still stretched and cut straight across; a spire is still a blade.
  - **Cliff.** Tiers down the face, 2-7 by depth. Columns are grouped into
    buttresses of 1-3, and each buttress has a fin that juts in or out. At
    each tier line a buttress either runs on straight (36%), steps in (32%:
    the tier above overhangs, in shade) or steps out (32%: an up-facing
    ledge). Each buttress's tier lines sit higher or lower than its
    neighbours', and each face leans in or out. A middle row bulges or dishes
    each face. Each block is smooth inside and has hard edges (SurfaceTool
    smooth groups); the lip, ledges, underside and fangs are flat-faced.
  - **Under.** The mass narrows in 3-4 ragged rings to a keel. Angular,
    stepped fangs hang from it, each with five or six sides of uneven width.
    By body: a cluster has 4-10, a cone a lead fang and 4-10 more, a boulder
    3-6, a slab 3-5 along its deep edge, a spire a tip and 1-3 more. A big
    fang often has a small one beside it, and short fangs hang off the
    overhangs.
  - **Lip.** The lip is rock: rim, a rock lip, then a notch of shadow under
    it. The notch is deep under some buttresses and barely there under
    others. There is no sod hem and no drape.
- **Shader** (`shaders/islet_crag.gdshader`): round 2's rock shader, plus:
  - strata by height in four stones (sand, clay, grey, shale) with thin beds.
    Each block's bands are offset by its own share (vertex colour b), so they
    break at the buttresses;
  - vertical streaks;
  - rounder joints, stretched up the face;
  - a dark topsoil skin under the rim where the turf runs to the edge
    (vertex colour a);
  - moss on what faces up, and green carried down from the rim in streaks
    (vertex colour g).

  The value gradient, cavity shade (vertex colour r), sky fill and bump are
  round 2's.
- **Grass:**
  - The crown grows the same KitFlora carpet as round 2, out to the rock's
    rim.
  - The rock's cap runs in under the turf from the rim. Along stretches of
    the edge (more with weather) it stands 0.2-0.75 m up through the turf
    and slopes back under it. The grass's probe stops wherever the cap is
    above the turf, so the grass ends raggedly at the rock.
  - Low tilted slabs and round 2's knobs break through inside.
  - A second, shorter KitFlora run grows on the ledges, probed on the
    ledges' own faces (`LedgeFlora`).
  - Roots hang only from the notch under the lip and from overhang feet.
- **Landmarks** (spec `landmark`: -1 drawn, 0 none, 1 tree, 2 ruin):
  - When drawn, units of 2.5 m and up get a lone tree (42%). Units of 4 m
    and up otherwise get a ruin (38%).
  - The trees are the game's hero oak and birch (motif_authored.gd
    `TREES`), scaled to the unit. They are drawn in a sky-filled material so
    their shade isn't black, and they stand plumb on tilted bodies.
  - Ruins are RuinKit pieces (arch, wall, pier, buttress, lancet wall,
    stone circle, aqueduct stump, rose gable, turret), weathered 0.55-0.95.
    They are seated on the turf with `motif_authored.gd` `seat`, and only
    pieces that fit the top are used. The grass keeps off a ruin's footprint
    and a tree's trunk.
  - The yard's hero has a tree (`HERO` `landmark` 1).
- **Debris** (`scripts/kit_isle/islet_debris.gd`):
  - Each unit's debris: 40-360 fragments, scaled by size and the spec's
    `debris` amount.
    - 60% hang under it, the biggest closest. They thin out and spread as
      they fall.
    - 28% form a loose ring beside the cliff.
    - 12% are pebbles high round the rim.
  - Sizes run from 4 cm to R x 0.17 m, drawn on a log scale.
  - The fragments come in three shapes (chunky, shard, flake), each a
    pushed-about icosahedron with its own squash.
  - 40% of them turn and bob on the GPU (`INSTANCE_CUSTOM`), using the crag
    shader with a turning vertex. Nothing collides.
- **Yard** (`studies/islet_yard.gd`), crag only:
  - **Loose chunks.** Each near unit gets 1-3 small crag units
    (`islet_yard/<unit>_chunk_<n>`, size 1.5-3.2), with grass, roots and a
    little debris. They sit 1.15-1.7 radii out and below, and bob and turn
    slowly (`set_drift` on the unit node; its layout pose stays put).
  - **Small islets.** There are 40 at 45-900 m (`islet_yard/speck_<n>`),
    from 170 m over the hero's top to 110 m under it. They get bigger
    farther out.
    - Only those within 200 m grow grass; the turf's tones carry the rest.
    - Those within 300 m may get a landmark, those within 400 m debris, and
      those within 250 m drift.
  - **Debris field.** 600 loose fragments fill the yard (`DebrisField`).
- **Unit node.** The world view shows `style`, `landmark` and `debris` as
  tunes.

## Flags and knobs

```
./run-islet-yard.command                       # crag (default)
./run-islet-yard.command --style=r2            # round 2's units, no extras
./run-islet-yard.command --no-debris           # crag without debris, chunks, specks, field
./run-islet-yard.command --specks=80           # more small islets
./run-islet-yard.command --solo --hero=seed=31,shape=0.3,landmark=2   # one unit with a ruin
```

Spec keys added to `IsletUnit.knobs_of`: `style` (0 r2, 1 crag, default
1), `landmark`, `grass` (0: no KitFlora, for far units) and `debris`
(0..2). The constants are `RUINS`, `TREES` and `CAP_U` in islet_crag.gd,
`TURNING`, `SPIN` and `BOB` in islet_debris.gd, and `SPECKS`, `SPECK_*`,
`GRASS_NEAR`, `LOOSE` and `FIELD_*` in the yard. The shader's palette and
`strata`, `band_m` and `greenery` are uniforms.

## Stills

These are in this worktree under `captures/shots/islet_unit_r3/`, which git
ignores:

- `sheet.png`: round 2 (mid) | round 3 (mid), the old chunk
  (`garden_chunk.png`) | round 3 close on a cliff, round 2 (depth) |
  round 3 (depth)
- `far.png`, `mid.png`, `depth.png`, `under.png` (from below, looking up),
  `cliff.png` (close on the hero's face and ledges), `top.png` (the crown,
  its tree and rock rim), `ruin.png` (a butte with a ruin)
- `bodies.png`: the five bodies, seed 29 size 8, plus depth; the singles are
  `body_slab.png` .. `body_spire.png`
- `r2_mid.png`, `r2_depth.png`: round 2 from the same spots

```
python3 tools/shot.py studies/islet_yard.tscn --at=0,38,46 --look=0,22,0 --settle 60 -- --no-title            # mid
python3 tools/shot.py studies/islet_yard.tscn --at=11,31,13 --look=0,23,0 --settle 60 -- --no-title --solo     # cliff
python3 tools/shot.py studies/islet_yard.tscn --at=14,-8,26 --look=0,14,0 --settle 60 -- --no-title            # under
```

Write negative coordinates as `--at=-60,...`. Written as `--at -60,...`,
argparse takes the value for a flag.

## Checks

- `python3 tools/smoke.py studies/islet_yard.tscn studies/aqueduct_isle.tscn`
  passes for both with 0 errors, and so does the yard with `--style=r2`.
- KitFlora, KitLook, RuinKit, HangingRoots and motif_authored.gd have no
  diff; they are only called. The motif editor and the isles don't change.
- The yard builds 69 units (14 placed, 15 chunks, 40 specks) in about
  1.8 s. Most of that is the grass.
- No committed tests, and no existing test is known to break: IsletUnit is
  used only by the yard.

## Model budget (docs/art/model-budget.md)

- **Rock.** The hero is about 5.8k triangles (the rock, slabs, fangs, ground
  and tree); round 2's hero was 7.5k. A unit carrying a ruin adds the piece's
  12-16k. The yard's 69 units come to about 248k drawn triangles. Of
  those, the 40 specks are about 158k (some of them carry a tree or a ruin)
  and the chunks about 26k.
- **Debris.**
  - The units carry about 4,700 fragments and the field 600, at 20
    triangles each, so about 106k instanced triangles.
  - Each unit's debris is three multimeshes, so the yard's debris is about
    210 draw calls. This is the main cost to watch.
  - Their visibility ranges end at 260 m to R x 45 m (the field's at
    440 m), and they fade out.
- **Grass.** About 1.2M instanced triangles across the yard (round 2's was
  1.4M), drawn within the carpet's 220 m. Far specks grow none. The ledge
  runs add a few hundred tufts in all.
- **Frame time: not measured.** Headless runs can't measure it, and the
  shots don't report it. Estimates:
  - debris: 0.1-0.2 ms GPU, plus the draw calls' CPU, about 0.2-0.4 ms;
  - rock pixel cost: as round 2's, 0.2-0.5 ms when the rock fills the
    screen;
  - grass: as round 2's.
- **The geometry tricks:**
  - **Silhouette geometry: applied.** It is the round: the broken outline,
    buttresses, steps, the keel and the fangs.
  - **Vertex-colour grime: applied, and widened.** r is the cavity shade, g
    the green, b the band offset, a the topsoil.
  - **Import LODs and visibility ranges: partly applied, apply next.**
    - Debris ranges are on.
    - Merging every unit's debris into one multimesh per shape per yard or
      isle would cut about 200 draw calls to 3, for perhaps 0.2-0.3 ms of
      CPU.
    - A far LOD for the specks (fewer columns, no fangs, no landmark past
      about 300 m) would cut most of their 158k triangles at no visible
      loss: an estimated 100k.
  - **Sculpt-and-bake, parallax and rigid parts:** not used.

## What's weak

- **Close up**, the faces still read a little like painted card:
  - the bands are flat paint over smooth blocks;
  - in places the thin beds alias into dotted lines;
  - the joints sometimes read as brickwork.

  From mid range and farther it reads well.
- **The strata's colour** leans warm tan and ochre. Next to the grass's gold
  the whole isle is warm; a cooler grey or bluish shale band would separate
  them.
- **The rock lip** on rock-out stretches is a flat mossy slab rim. From
  below the crown, the rim and lip together can still read as one stacked
  plate.
- **The ground** still shows the carpet's orange earth where the grass
  thins (as in round 2).
- **The ruins** are the kit's charcoal stone. On a small unit at mid range
  they read as dark silhouettes, and the smaller pieces are hard to see.
- **The oak** is the game's low-poly hero oak. Its faceted canopy is plainer
  than the rock round it.
- **The debris draws** are many small multimeshes (see the budget).
- **The specks** are full crag units. 40 is fine; several hundred would want
  a cheaper far model.

## Next

- **Merge the debris** into one multimesh per shape per scene. Give the
  specks a far LOD: rock with no grass, fewer columns, no fangs under a size.
- **A close-up pass on the shader:**
  - break the band edges with real relief, by moving the vertices along the
    bands on the middle row;
  - add a cool band to the palette;
  - antialias the thin beds.
- **Compose a crag isle** from a landing-slab unit and satellites, as in
  round 2's next step, with debris shared between them and the landing turf
  kept clear of slabs (rock-out off on the runway unit).
