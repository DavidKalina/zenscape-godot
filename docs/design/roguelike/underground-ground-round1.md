# Underground ground, round 1

The user loves the shaded, wind-moved grass; the underground run's ground lost it (orange gold turf under the haze, bare stone on the city kit's walk tops). This round makes ground cover for the underground that keeps that living, shaded, wind-moved quality, and a layer the city kit can lay on stone.

Branch `look/underground-ground` (from `roguelike`). Code: `scripts/underground/ground_cover.gd`, `shaders/underground_dust.gdshaderinc`, `shaders/underground_cover.gdshader`; hooks in `scripts/underground/underground.gd` and `shaders/ground_look.gdshaderinc`.

## The options

`--ground=dust|grass|moss|off` (under `--underground`; default `dust`; `off` is the old orange). **G** flips live: day's own, grass, dust, moss. The look key L still flips haze and torch; the ground follows (warmer under the torch's cool moon, or sand reads as snow).

- **dust** (default): drifted dust, pale ash, fine sand. The terrain's grass ground turned sand (the grass ratio global, `zs_palette_grass`), with the meadow's own patches and drift hue kept. New in the ground shader (`ground_dust`): ripples lying across the wind that creep along it, a pale sheen lifted on the same gust crests that bow the grass, a broad dune light and dark, and fine grit close up. Sparse dry tufts (the game's own grass tuft, graded straw) and a few pale mushrooms poke through. Grit blows along the wind past the wanderer (GPU particles, 260).
- **grass**: the game's turf and tufts re-graded: dusty umber-sage, no seasonal gold. Same tufts, drifts, wave, sheen.
- **moss**: cool dark moss ground; on stone, patches that glow faintly and breathe, with cave mushrooms and spores rising. The glow scales with the preset (torch 1.0, haze 0.3; the haze washes it out).

All three also fix the orange: the season's gold (the real date is autumn) is switched off on the ground, grass tufts, ferns and shrubs only (their `leaf_season`). Ivy, vines, moss on ruins and the rest keep their look. The worn paths' earth was a vivid pink clay under the haze; the cover takes it to its own earth (`ground_path`).

## The API for the city kit

```gdscript
const GroundCover = preload("res://scripts/underground/ground_cover.gd")
# Lay the cover on a walk top. area: Rect2 in the parent's (x, z), or a PackedVector2Array polygon.
GroundCover.cover(piece, Rect2(-2, -6, 4, 12), "", top_y, seed)     # "" = the flags' kind
GroundCover.cover(crown, polygon, "dust", top_y, seed, {"tufts":0.5})
```

`cover(parent, area, kind := "", y := 0.0, seed_value := 1, opts := {}) -> Node3D`

- Returns a "GroundCover" node under `parent` (or `null` with no `--underground`, `--ground=off` or an unknown kind, so the kit can call it unconditionally; flag off changes nothing).
- Everything is in the parent's own frame, so a turned or tilted piece carries its cover. `y` is the top's height in that frame.
- Rect2 areas get soft ragged edges (`opts.fade`, default 0.4 m); polygons get a hard edge. The skin lies 1.2 cm over the stone and follows the stone by world x, z, so it runs on from the terrain's dust and from the piece beside it.
- `opts`: `tufts` (multiplier on tuft density, 0 none), `under` (shoots and mushrooms), `fade`, `amount` (skin opacity), `skin` (false: tufts only).
- Not on the stone's colour: the kit keeps its stone; this is a layer over it. Lay it on the flat tops only (landings, causeway decks, pillar crowns), not on risers or slopes (the skin is horizontal).
- Call it after the piece stands (it adds nodes only). `GroundCover.asked()` gives the kind the flags ask. The kit's own `KitFlora` is not touched.
- `--ground-demo` (with `--underground`) lays three test pieces by the start (a landing, a turned deck, an octagonal pillar crown, dark stone) so the cover can be judged on bare stone.

I did not edit any kit file.

## Play

    ./run-underground.command                                  # dust, torch
    ./run-underground.command --underground=haze --ground=grass
    ./run-underground.command --ground=moss --ground-demo      # G flips the cover, L the light
    <godot> --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=7 --underground=haze --ground=dust --ground-demo

## Stills (docs/design/roguelike/underground-ground-round1/)

Each sheet is dust, grass, moss (top left, top right, bottom left).

- `before_haze_orange.png`: the starting point.
- `haze_walker_dust_grass_moss.png`, `torch_walker_dust_grass_moss.png`: close, at the wanderer.
- `haze_wide_dust_grass_moss.png`, `torch_wide_dust_grass_moss.png`: wide, the start pad, the demo pieces and an aqueduct.
- `haze_landing_...`, `torch_landing_...`: the cover on a bare stone landing.
- `haze_dust_deck.png`, `haze_dust_crown.png`: a turned deck, a polygon crown.

## What I'd say about the look

- Dust reads as sand under the haze and pale ash under the torch, with ripples visible close up and the sheen on gusts. On stone landings it reads as drift lying on stone. The terrain's tufts are still the isles' dense grass, so on dust the ground is sand with a lot of dry grass; thinning the tufts for dust is a one-line knob but touches KitFlora (not done).
- Grass is the safest: it is the game's grass, just muted.
- Moss on the terrain is a teal-green ground only (no glow; the ground shader has no emission). Its glow, mushrooms and spores are on the cover and the air. Glow under the torch is strong (the patches are bright cyan); a notch down is a one-number change (`glow`).

## Cost

- Terrain: `ground_dust` adds ~6 noise taps and some ALU to the ground fragment, only while `ground_dust` > 0 (a uniform branch). `ground_path` is a branch too. Flag off: identical to before (smoke checked).
- A cover: one skin mesh (4 to 10 vertices, transparent, one draw) plus the existing KitFlora `Draw` multimesh tiles (24 m tiles, same fade/range as the isles' grass). Dust is sparse (0.55 tufts/m2 at drift peaks), grass 3.2/m2, moss 1.2/m2. A 7x5 m landing is a few dozen instances.
- Per frame: one global shader parameter set and a loop over the tuft materials every 20 frames. Motes: one GPUParticles3D, 260 quads, GPU only.
- No frame times measured (headless; rendered stills only).

## Checks

- Headless import, 0 errors.
- Smoke (`tools/smoke.py studies/run_layer.tscn`, seed 7, sprawl), 0 errors each: flag off; `--underground=haze` with `--ground=dust`, `grass`, `moss`, `off`; torch with `--ground=grass` and `dust --ground-demo`.
- Rendered stills as above (one window at a time).
- Rendered runs end with "1 shaders of type ParticlesShaderRD were never freed" at exit when the motes exist (dust, moss). It is exit noise from quitting with particles alive; headless and the grass cover don't show it.
- Not done: G in a real keypress run (the code path is `_unhandled_key_input`), ring shape, a cover on a tilted piece (a turned one is shown), wanderer walking on it (the cover is visual only; nothing about collision changes).

## Tests broken

None expected: flag off is unchanged. `tests/test_ground_look.gd` keeps the ground greens in step with the palette and was not run; the added `ground_look.gdshaderinc` lines are new uniforms and branches only. Full suite not run.

## Open questions

- Default cover: dust (my pick), or grass? (`DEFAULT` in ground_cover.gd.)
- Should the terrain's tufts thin under dust, so it reads as sand rather than sparse meadow?
- Moss glow strength, and whether moss on the terrain should glow too (would need an emission term in the ground shader).
- Does the city kit want the cover as a layer it lays on every walk top, or only on named pieces? `cover` is cheap enough for all of them at this size.
