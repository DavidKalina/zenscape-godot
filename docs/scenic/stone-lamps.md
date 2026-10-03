# Stone lamps

Added 2026-10-03 on `feature/stone-lamps`. The night sky got real stars, but
nothing on the land gave off light. Stone lamps are small lanterns you set on
the land that glow warm from dusk to dawn.

## Placing them

The lamp has its own compartment in the field case, after the river stone
(`lamp` in scripts/materials_tray.gd `SPECIMENS`, with an icon in
scripts/hud_icons.gd and a row in the command palette's Elements). It works
like the stone (scripts/hand_materials.gd `SCATTER["lamp"]`):

- **Tap** sets one lamp, a little bigger the longer you press.
- **Drag** lines a path: one lamp every `gap` (2 m at the middle pip, scaled
  by the pips), up to 12 in one drag, along the line the pointer takes.
- No lamp goes within `clear` (1.1 m) of another, so dragging back along a
  row does not stack them.
- The land decides as it does for stones: no lamp on water.

Each tap or drag is one undo step. A lamp is an ordinary object record
(asset `stone_lamp` in NativeTerrainData `ASSETS`), so it saves and loads
with the world. The trash can takes it away like any other object, and the
hand's pluck can pull it too. It arrives with the drop reactions' `settle`.

## The look

Following the style rule (docs/scenic/style.md), the solid parts are
faceted and the light is soft.

- **The lamp** (scripts/stone_lamp.gd) is about a metre tall: a hexagonal
  foot and post, a square shelf, four corner pillars round an open fire box,
  a low four-sided roof and a knob. It uses vertex colours on the stones'
  flat-faced material, and GardenView draws every lamp in one batch.
- **The core** is a small faceted bead in each fire box. By day it reads as
  a pale paper panel. At night it glows warm through emission.
- **The halo** is a soft camera-facing glow round each core
  (shaders/stone_lamp_halo.gdshader), added over whatever is behind it. It
  is off by day.
- **Real light** comes from an OmniLight3D without shadows, warm `ffb36b`,
  reaching about 3.4 m at lamp scale 1.

## Night

scripts/stone_lamp_lights.gd (`NativeChunkEditor.lamps`) reads the sky's
`zs_daylight` from studies/celestial.gd, or the world clock's `daylight` if
there is no sky. The lamps start to glow as daylight falls below 0.55
(before sunset) and are fully lit by 0.12. They go out the same way at dawn.
The glow eases over 2.5 s, so skipping time still fades them in and out.

## Cost

- Cores and halos are one MultiMesh each, with one shared material, for any
  number of lamps.
- At most **8** lamps get a real light: the 8 nearest the camera, picked
  again every 0.25 s. When a light moves to a different lamp, it fades out
  and back in over 0.4 s, so moving the camera along a row does not pop.
  Lamps beyond the nearest 8 still glow but light nothing around them.
- The pool is shared. Campfires (docs/scenic/campfire.md) and the cabins'
  windows (docs/scenic/cabin.md) join it as guests, each owner with its own
  list and energy (`set_guests(list, owner, energy)`): their own reach,
  colour and (flickering) energy. The nearest 8 of lamps, campfires and
  windows together get the lights, so the cap holds however many of each
  there are.
- The records are read again when the objects change, and every 0.5 s
  otherwise, so lamps stay on reshaped ground.

## Checks

`tools/probe_stone_lamps.gd` runs headless (`-- --modeless --no-title`) and
covers: the tray slot, tap (one lamp, one undo step, drawn, undo removes it),
drag (a spaced row along the drag, one undo step), noon dark / midnight lit /
dawn out / dusk up from the world clock, the 8-light cap with 19 lamps, a
save round trip through JSON, and the trash sweeping the row away (lights
too) with undo bringing it back.

Headless uses the dummy renderer, so none of the look is verified there: the
lamp's shape and colours, the core's emission, the halo shader, or how the
OmniLights fall on the ground and grass. These need a rendered look at night.
