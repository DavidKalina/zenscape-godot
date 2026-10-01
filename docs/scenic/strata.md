# Strata

Digging shows geology. The plate is made of flat rock layers by height, so a
cut tells you how deep it went and what it hit: banded canyon walls, a pit
stepping down through the layers, a cut at the rim matching the slab's side.

One definition, `scripts/strata.gd`, feeds both places that show it:

- **Cut ground:** the clay's tint layer (`scripts/land_clay.gd` `_dirt` for
  flats, `paint_faces` for steep faces), through `color_at`.
- **The slab's earth sides:** `shaders/reference_surface.gdshader`
  `zs_strata`, fed by `apply` (called from `NativeChunkEditor._rebuild_skirt`).

The grass surface does not change. Strata show only where ground was cut or
exposed, and on the sides.

## The bands

By absolute plate height. The plain sits near 0.

| Band | From | To | Colour (sRGB) |
|---|---|---|---|
| topsoil | above the plain | -0.4 m | `7a624b` dark loam |
| clay | -0.4 | -1.8 | `a8784c` warm ochre |
| sand | -1.8 | -3.2 | `cfbd96` pale sand and gravel |
| shale | -3.2 | -4.4 | `6f6863` / `58524e`, 0.3 m beds |
| bedrock | below -4.4 | | `7f7e7a` grey |
| rock_core | see below | | the range's granite, 0.6 m beds |

- **Warp.** Each boundary rises or falls up to 0.25 m across the plate: two
  long sine waves (19 m and 12 m), their direction and phase seeded by the
  world (`land_seed`). The layers undulate a little but stay flat and readable.
- **Rock core.** A column whose surface stands 2.5 m or more is granite from
  the plain (0 m) up, so tall hills and mountains are rock inside. Lower
  raised ground is earth (topsoil). The core ignores the warp.
- **Faces.** A cut face is 0.86 of a flat's colour, so facets read. A face
  takes the highest ground within 1 m as its column's top, so a tall mesa's
  face is granite to its foot.
- **Side skin.** The top 0.22 m under the rim is the grass's root mat (the
  topsoil at 0.55).

All of these are constants at the top of `strata.gd`. The shader takes every
value from `apply`; its own uniform defaults only stand in until then.

## Palette

Colours are authored against the default (Mountain) palette. The world's
palette reaches them the way it reaches every ground colour,
`scene_palette_ground` in `shaders/scene_palette.gdshaderinc`: earthy colours
(topsoil, clay, sand) take the palette's earth, grey ones (shale, bedrock,
core) its rock. The sides now use the same function (they used the earth
ratio for everything), so cut ground and sides shift together.

## Desert worlds

Desert ground keeps its own geology. With `desert_enabled` the terrain shader
repaints the whole surface from the desert map (sand, banded stone by height,
varnish, salt) and ignores the tint, so cuts in a desert show the desert's
own bands, not these. The desert's slab sides use these strata, warmed by the
desert palette. Joining the two (the desert's band colours as this stack's) is
open.

## Query: `material_at`

```gdscript
var layers = Strata.for_seed(editor.land_seed)  # or land_clay.strata()
layers.material_at(point: Vector2, height: float, surface := -INF) -> String
```

It returns `"topsoil"`, `"clay"`, `"sand"`, `"shale"`, `"bedrock"` or
`"rock_core"`. `surface` is the top of the column there (for example the
ground before a cut). Left out, the point is taken as the surface, so ground
standing 2.5 m or more reads as `rock_core`.

Nothing uses it for behaviour yet. Candidates: sand that drains, the Hammer
cracking shale and core but knocking soil. The Hammer's rock-paint test does
read the soft bands' colours (`Strata.earthy`), so a face cut in topsoil, clay
or sand counts as earth, as the old dirt did.

## Limits

- Cut ground is coloured per 0.5 m tint cell, and a Chisel face is about one
  facet row, so a steep wall shows one or two bands per facet. The sides band
  per pixel. A per-pixel band on cut faces would need the terrain shader to
  know which cells were cut.
- Today you can only dig to -1.5 m (topsoil and clay). The deep slab
  (`feature/deep-slab`) opens sand, shale and bedrock.
- A sunlit cut wall and a slab side in shade can differ a lot in brightness.
  The colours match; the light does not.
