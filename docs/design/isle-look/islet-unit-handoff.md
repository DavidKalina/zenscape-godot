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
