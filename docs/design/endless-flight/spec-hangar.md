# Spec: the hangar (loop `hangar`)

A plane editor in `studies/endless_flight.tscn`. The player sets the plane's
look from parts; the shop sells parts; a skin is a preset (a saved set of
parts). Decided with the user 2026-11-15.

## What exists (read before building)

- A skin is a row in `ShopStock` (`scripts/endless/shop_stock.gd`, batches in
  `scripts/endless/skins/`): `livery` (body, dark, trim, wing), `finish`
  (sheen, bare, metal, pearl, glow, glow_on), `decal` (one premultiplied RGBA
  PNG in atlas UV, colours fixed in the image), `bake` (own albedo/mask/orm).
- `ShopStock.dress` -> `_paint` -> `PlaneFigure.repaint(livery)` and
  `refinish(finish_values(row))` (`scripts/plane_figure.gd`), which set
  uniforms on `assets/models/hero_plane/hero_surface.gdshader`. The mask
  texture's RGBA are the four zone weights.
- `shop_sites.gd` `step()` dresses the plane each frame as the book says
  (early out when unchanged); `shop_view.gd` previews on the live plane.
- Money, owned and worn live in `PilotBook` (`scripts/endless/pilot_book.gd`,
  `user://pilot.json`).
- Menus: `scripts/endless/ui/menu_base.gd` (rows, pages via `open_page`),
  `title_menu.gd`, `pause_menu.gd`, the kit `ui_kit.gd`. The title shows the
  parked plane through `scripts/endless/menu_stage.gd` (camera orbit).
- Makers: `art/blender/hero_plane/hero_plane_decal.py` (`Decal`),
  `hero_plane_bake.py`; `python tools/skin_sheet.py <id>` renders a look.

## The look, as data

One Dictionary, the **look**, saved in the pilot book and applied by one
function (in a new file, e.g. `scripts/endless/plane_look.gd`):

- `paint`: four colours, body / trim / wing / dark. Any colour, free.
- `pattern`: a pattern id plus its one or two colours. Tintable: the shape
  is bought, the colours are the player's. A new layer in the shader: a
  pattern mask texture in atlas UV (channels = colour slots), tinted by
  uniforms, laid over the paint and under the decal.
- `finish`: sheen (satin, gloss, matte, metal), pearl, glow. Special ones
  are bought.
- `decal`: an emblem, number or roundel on top; bought. The existing
  full-plane decal pictures stay usable here as they are.
- `wear`: clean to weathered, from the baked atlases.

A **preset** is a named look. Every existing skin row is a preset: loading
one the player owns fills the editor, and they change it from there. The
book's `worn.paint` id keeps working until the presets task replaces it; a
custom look, when set, wins over the worn skin.

## The screen

A "Hangar" row on the title menu and the pause menu, in the cream-slip
style (`ui_kit.gd`), keyboard, mouse and pad. The plane is the live plane
(parked on the title; held in the air under pause), with the camera
orbiting it so the whole plane can be seen. Changes show at once. Leaving
keeps the look; it is saved in the book and survives a restart. `--ui=old`
need not have the hangar.

## Frame rate

Applying a look sets uniforms and swaps textures only when the look
changes, never per frame. No new per-frame work in flight. The pattern
layer is one more texture sample behind a uniform switch.

## Tasks

Trunk 1 (one iteration, first):
1. **Hangar with paint.** The look data and its apply/save path; the
   Hangar row on both menus; the screen with the four zone colours (a
   picker per zone: hue, saturation, value, plus a row of swatches) updating
   the plane live; orbit camera; saved and restored; existing skins and the
   shop unchanged. A launch flag opens straight into it for checks
   (`--hangar`).

Lanes (parallel, after trunk 1; each in its own worktree branched from the
loop's branch, own new files, small additive edits to shared ones):
- **pattern**: the tintable pattern layer in the shader and `PlaneFigure`,
  a maker on `hero_plane_decal.py` that writes pattern masks, a first set of
  about eight patterns, and the hangar's pattern section.
- **finish**: the hangar's finish and wear sections over what the shader and
  the existing bakes already do.
- **emblem**: a set of small emblem decals (roundels, numbers, pennants,
  nose art shapes) made with `Decal`, and the hangar's decal section,
  listing these and the existing full-plane decals.

Trunk 2 (in order, after the lanes merge):
2. **Shop sells parts.** Patterns, special finishes and decals as shop rows
   with prices in the economy's bands; the hangar shows unowned parts
   locked with their price; owning is saved in the book.
3. **Skins as presets.** Each existing skin row expressed as a look; the
   hangar's preset section loads an owned one; the shop's skin rows sell
   the preset (its parts come with it).
4. **Handoff.**

## Done

From `studies/endless_flight.tscn` the player opens the hangar, composes a
look from paint, pattern, finish, decal and wear, flies with it, and finds
it again after a restart; parts are bought in the shop; old skins load as
presets. `python tools/smoke.py studies/endless_flight.tscn` passes after
every task. Each task's commit names a command the user runs to try it and
stills of the plane in the hangar (`captures/`, uncommitted).

## Out of scope

Other plane models. Committed tests (a lock-in round the user asks for).
The files `scripts/endless/*_site.gd`, `scripts/temple_kit.gd` and
`scripts/endless/way_towers.gd` belong to another session: don't edit them.
The cap and budget are the skill's defaults.
