# Handoff: the hangar (loop `hangar`, 2026-11-15)

Branch `claude/sharp-hopper-7ff7c7`, not pushed, not merged. Spec:
`spec-hangar.md`. Trail: `git log --grep='^ITER(hangar)'`.

## What's built

- **Hangar** row on the title and pause menus (`--hangar` opens straight
  in). Five parts: Preset, Paint, Pattern, Finish, Decal. The live plane
  updates at once; Q/E, the right stick or a drag turn the eye.
- **The look** (`scripts/endless/plane_look.gd`): one Dictionary in the
  pilot book (`look`): paint (four zone colours, free), pattern (id + two
  colours), finish (sheen, pearl, glow), wear (surface), decal. Applied
  only when it changes, through `ShopStock.dress`.
- **Patterns**: a tintable layer in `hero_surface.gdshader`; nine masks
  made by `art/blender/hero_plane/patterns.py`
  (`scripts/endless/plane_patterns.gd`).
- **Finish**: four sheens, pearl, night glow, nine surfaces
  (`plane_finishes.gd`); two new bakes under
  `assets/models/hero_plane/skins/surface/`.
- **Decals**: eleven emblems (`art/blender/hero_plane/skins/emblems.py`)
  and the 17 skin decals (`plane_decals.gd`).
- **Parts for sale**: 48 priced parts (`plane_parts.gd`), ids `kind:name`
  in the book's `owned`. Sold in the shop (tabs Patterns, Finishes,
  Decals) and bought in the hangar (Enter on a locked part, Enter again).
  A part that came with an owned skin is owned. `--hangar-all` owns all.
- **Presets**: every skin is a preset, loadable in the hangar and worn in
  the shop as a whole look; five custom slots (Save to); a replaced
  unsaved look is kept as "Previous look".
- `tools/skin_sheet.py` takes `pattern:`, `decal:` and `look:PATH` rows,
  an `under` view and `--size`.

## Try it (PowerShell, this worktree's root)

    .\run-endless-flight.cmd --fresh --hangar --hangar-all   # every part, a throwaway book
    .\run-endless-flight.cmd --fresh --hangar                # locked parts, no coins
    .\run-endless-flight.cmd --hangar                        # the real book

## Checks

`python tools/smoke.py studies/endless_flight.tscn`, and with
`-- --hangar --pilot=fresh` and `-- --hangar --hangar-all --pilot=fresh`:
PASS on the final commit. Each step's play-loop driver (real key, mouse
and wheel input, test books) is in its commit's Checks; the drivers are
uncommitted. No tests were run or added (prototype). A test expecting
`PilotBook.wear("paint")` to clear the look would now fail.

## Open, and what reads poorly

- The shop with parts was only seen with the plane in the air, not parked
  at a strip; `--shop-open` smoke never opens the panel at the default
  start.
- Shop: every decal row shares one thumbnail; glow previewed by day shows
  nothing; the WORN mark stays on the last skin loaded after the look
  changes.
- Hangar: leaving the decal list upward steps through to None and keeps it.
- Art: the star on the tail cone is a speck at chase distance; emblems
  over dark paint are nearly lost at night without glow on marks; on the
  bared-metal surfaces paint and patterns show only in flakes.
- On the title the parked plane's wheels stand in tall grass.
- Prices and the "Well kept" surface's name are first guesses.
- A rare `--hangar` smoke failure (~66 errors, once in 13 runs in round
  1) was never seen again or read.
- Blender on this PC writes bake JPEGs with an ICC profile Godot 4.7.2
  won't import; the two new albedos were stripped by hand. The fix
  belongs in `hero_plane_bake.py`'s `_jpeg`.
- Mac: not run there.
