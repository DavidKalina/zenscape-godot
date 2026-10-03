# Cabin

Added 2026-10-03 on `feature/cabin`. It is the fifth build piece, after the
stone lamp, the campfire, the fence and the footbridge: a small one-room log
cabin with a shake roof and a stacked-stone chimney. You set it on a flat,
dry patch of land, and from dusk its window glows warm.

## Where it came from: the evaluation

The sky-island branches (`sky/settler-cabin`, `sky/cabin-model`,
`sky/cabin-finish`, `sky/chimney-smoke`) built a settler's cabin as a scripted
Blender model (`art/blender/cabin_build.py`, then `cabin.blend` and
`assets/models/cabin.glb`), with a carried log, a stump and an axe, and a
chimney-smoke shader. `sky/camp-props` added a tent, campfire, lantern, log
seat, crate and barrel.

**Measured size.** These figures come from the GLB's accessor bounds and the
build script's report (`CABIN_REPORT`). At real size the walls are 2.6 × 3.2 m.
The roof covers 3.3 × 4.1 m. With the chimney the whole box is 3.82 × 3.65 ×
4.10 m (x, height, z). The eaves are at 2.22 m, the ridge at 3.35 m and the
chimney top at 3.65 m. The model is 2,872 triangles in 11 flat colours. The
sky branch drew it at **0.8**, the scale its chimney smoke was judged at. At
0.8 its footprint is **3.06 × 3.28 m**, plus 0.04 m to the door step. The
ridge is at **2.68 m** and the chimney top at **2.92 m**. The door is 1.4 m
clear.

**Against this game's scale.** That is under the brief's guide of about
3 × 4 m and a ridge under 3.5 m. Trees stand 3 to 5 m, so the roof sits below
the crowns, and a tree beside it still reads as the bigger thing. The stone
lamp (about 1 m) reaches the window sill. A fence post (0.62 m) is about a
third of the wall. The cabin covers about 1.5% of the 25.6 m plate, about as
much as a 6 m footbridge, so it is a cottage in a diorama and not a
landmark. The comparison render (below) shows it beside a 1 m post, a 0.62 m
post and a 4 m cone.

**Style.** Every part is faceted and flat-shaded in solid muted colours: seven-
sided peeled logs with notched, overhanging corners, split shakes, and laid
faceted stones. It matches the stone lamp, the campfire's stones, the split-
rail fence and the timber footbridge. The soft and glowing parts (the window
light and the smoke) are added in the game, as for the lamp and the fire.
Nothing in `cabin.glb` implies people. The axe, the carried log and the stump
were separate GLBs; they were left behind, as were the settler and the camp
props.

**Decision: (b), reuse it with changes.** It was the right size and style
already, so a rebuild in code (c) would have spent effort to get a worse
cabin. It was not reused unchanged (a) because:

- it is drawn at 0.8, baked into one vertex-coloured mesh (scripts/cabin.gd)
  on the stones' shared material. So it takes the scene palette, flat faces
  and the fire material like the lamp and the campfire, and every cabin is
  one GardenView batch instead of a 12-node scene with 11 materials;
- the window glass is dark by day, and a separate warm pane lies over it at
  night;
- a ring of faceted footing stones is added under the walls, so it can sit
  on gently sloping ground;
- `cabin_build.py` was cut to the cabin alone (no log or stump), and the
  regenerated `cabin.glb` is byte-identical to the sky branch's.
  `cabin_render.py` was rewritten to render the cabin at this game's scale
  without the settler.

The sky branch's own chimney smoke (opaque cream puffs, one node per cabin)
was not brought over. The campfire's thin smoke on the wildfire's smoke
shader is cheaper here (one capped pool) and matches the campfire's smoke on
the same plate.

## Placing it

The cabin has its own compartment in the field case, after the campfire
(`cabin` in scripts/materials_tray.gd `SPECIMENS`, with an icon in
scripts/hud_icons.gd and a row in the command palette's Elements). In hand it
is a small cursor clump: a log box, a door, a warm window, a pitched roof and
a chimney. A **tap** sets one cabin, and a drag sets one where it is let go
(`SCATTER["cabin"]`, `tap_only`). Every cabin is the same size (record scale
1).

It is an ordinary object record (asset `"cabin"`), so undo, saving and the
trash can all work with no special code. One tap is one undo step. The trash
reaches it anywhere over its footprint, not only at its middle (Trash
`reach_of`). It counts as big, so Shift with the trash spares it. The hand's
pluck is for plants and does not take it, as with the lamps. The wildfire
treats it as inert.

### Which way it faces

The door (+Z in the model) is turned at placement (Cabin `facing`) and saved
in the record's angle:

- **Down the slope** where the land falls more than 4% across the cabin
  (`FACE_SLOPE`, measured 1.5 m either side). A cabin on a hillside looks out
  over the fall, the way people build, and its uphill wall is the one
  partly sunk into the ground.
- **Toward the camera** on the flat, so you see the door you just set. The
  window is on the side wall, so a three-quarter view shows both.

It does not turn after it is set.

### The land decides

Cabin `refusal` samples the footprint and the 0.7 m apron before the door,
every 0.45 m. The cabin is refused, nothing is set, and the hint line says
why (`CABIN_REFUSALS` in scripts/hand_materials.gd):

| Reason | When |
|---|---|
| `edge` | any of it would hang off the plate |
| `water` | any sample is under live water, a pond, lake or stream |
| `steep` | the ground under it rises more than 0.45 m (`SPREAD`) from its lowest to its highest point (about a 1:10 slope) |
| `tree` | a tree's foot within 1.2 m × its scale (at least 0.8 m) of the footprint, so no roof is set into a crown or trunk |
| `near` | another cabin's footprint within 1.2 m |
| `room` | anything else standing there: a stone, boulder, lamp, campfire, log, shrub, sunflower, wheat, reeds, a fence post or a footbridge |

Low plants (flowers, grass tufts, ferns, mushrooms, a leaf bed) do not block
it; the floor covers them. The land is never levelled for a cabin. The
footing stones cover the gap that the allowed 0.45 m leaves: the cabin sits
at the ground height under its middle, the footing reaches 0.4 m below it,
and on the uphill side the bottom log sinks a little into the slope.

## Night

scripts/cabin_lights.gd (NativeChunkEditor `cabins`) follows the records:

- **Window.** A warm emissive pane over each cabin's glass, every cabin in
  one MultiMesh on one material. It follows the stone lamps' eased `glow`
  (the same sky), so it comes up from dusk with the lamps and goes out at
  dawn. By day it is hidden and the baked dark glass shows.
- **Light.** Each window joins the stone lamps' pool of real lights
  (scripts/stone_lamp_lights.gd) as a guest of owner `"cabin"`. It is a warm
  light 0.45 m outside the pane, reaching 3.6 m, and shines only while it is
  dark. The pool takes guests from more than one owner (`set_guests(list,
  owner, energy)`; the campfires are owner `"campfire"`). The nearest 8 of
  lamps, campfires and windows together get the lights, so no number of
  cabins adds a light.
- **Smoke.** A thin wisp from the chimneys of the 4 cabins nearest the
  camera, in one pool capped at 40 puffs, on the wildfire's smoke shader
  (as the campfire's smoke). It leans downwind with the breeze and the wind
  tool's gusts (PollenWind). It smokes day and night.

## Cost

Each cabin is about 3,500 triangles in the shared GardenView batch: the
model's 2,872 plus the footing. The window panes are one MultiMesh of boxes
and the smoke is at most 40 quads. Lights come from the existing pool of 8.
The mesh is built once from the GLB and shared.

## Files

- `scripts/cabin.gd`: the baked mesh, `info`, `footprint`, `facing`, `refusal`
- `scripts/cabin_lights.gd`: the window panes, the guest lights and the smoke
- `assets/models/cabin.glb` (+ `.import`), `art/blender/cabin_build.py`,
  `art/blender/cabin.blend`, `art/blender/cabin_render.py`
- `tools/probe_cabin_place.gd`

Regenerate and look:

```sh
/opt/homebrew/bin/blender -b --python art/blender/cabin_build.py    # cabin.blend + cabin.glb
/opt/homebrew/bin/blender -b --python art/blender/cabin_render.py   # docs/scenic/cabin-render.png (git-ignored)
```

## Checks

```sh
godot --headless --fixed-fps 60 --path . -s res://tools/probe_cabin_place.gd -- --modeless --no-title
```

The probe covers placement on a flat plain and the door's facing, one undo
step, and undo. It covers refusal on a slope (it tilts the plain under the
spot into a hillside when the world has none in view), in water (flooded
when none is in view), in a wood, and beside another cabin. It checks the
window dark by day and lit at midnight with a real light from the pool, the
cap of 8 lights with many cabins and lamps, the smoke's cap, the save round
trip, and the trash with its undo.

**Not verified headless:** how it looks in the game (the model on the land,
its palette under the scene's light, the footing on a slope), the window's
glow and the light it casts, and the smoke. These need a rendered run. The
Blender render is EEVEE, not the game's lighting.
