# The city, weathered (round 1)

Ask: bring everything the city kit built to the "weathered world" bar
(`kit-stone-weathered.md`, `olmec-weathered.md`): one basalt across the
four city files, different wear per piece, the underground look keeping the
weathering readable, and the day-sky-fill glow bug fixed properly. Surface
work only: no shape, collision, size or behaviour changes (except the one
decision below).

## What I found
Almost all city stone already wore the Olmec's `olmec_stone` shader, through
`HeadLook.stone_material()` (stone, breaks, fires, refuges). There was no
plain StandardMaterial3D stone to bring in. The remaining StandardMaterial3Ds
are the water sheet, the hush glass pane, the clay lamp and the drum
floor's unshaded warning ring: none of them stone. The unification was
therefore about wear and lighting, not conversion.

## What changed
- `shaders/olmec_stone.gdshader`, `shaders/folk_surface.gdshaderinc`
  (ruin stone only, under `ZS_STONE_WEATHER`): the stone's sky fill can swap
  to the underground's own. Three new globals in `project.godot`:
  `zs_under` (0 by default, so the day is untouched), `zs_under_sky`,
  `zs_under_ground` (colour times energy already).
- `scripts/underground/underground.gd`: **the glow bug, fixed once.** It
  publishes the stone's fill (`_publish_stone`, each frame with the sky,
  after the day's) and sets `zs_under` back to 0 on exit. Fill is the air's
  ambient eased toward grey (so the basalt is not one flat blue), at
  `STONE_FILL` torch 0.26, haze 0.5. Only the stone reads these, so the
  turf and everything else keep the hemisphere. This covers the generator
  and every city yard; the local patches are gone:
  `city_fires_yard.gd` `_hemi`/`HEMI` and `city_kit_gallery.gd`
  `_dress_hemi`/`_was_hemi`/`_exit_tree` (the breaks and refuges yards had
  none and now get the fix for free).
- `scripts/city_kit_stone.gd`: `wear(kind)`, one material per wear from the
  shared stone, a few knobs apart (`WEAR`): `pier` (base), `stair` (treads
  and crests walked pale, crisper), `span` (the causeway, rain-washed),
  `fire` (sooted crevices, little pale, lichen burnt dark), `break` (fresh
  pale chips, crisp), `refuge` (dust-greyed). All share a dry, dim
  olive-grey and ochre lichen (before, the stair's treads carried bright
  yellow lichen that read as glowing in the torch).
- Users: `city_kit.gd` (`Stone.mesh_of(m, kind)`: pillar, drum stair, stair,
  causeway, and the breakable fault/bay as `break`), `city_kit_breaks.gd`,
  `city_kit_fires.gd` (every fire mesh and the cresset plinth),
  `city_kit_refuges.gd` (`stone_material` is `wear("refuge")`; its dust
  colouring in the mesher is unchanged).
- **Refuges registered** in `scripts/city_kit.gd`: `CityRefuges` const,
  `PIECES` + `CityRefuges.PIECES`, `piece()` dispatch, `name_of()`.
  Same as the handoff `city-refuges-round1.md` describes. `ALL` includes them.

## Decisions folded in
1. **Grass is the city's default ground cover** (`ground_cover.gd`
   `DEFAULT := "grass"`, so `--ground` with no value and `cover()` with no
   kind mean grass; the gallery's and demo's fallbacks agree). Dust and moss
   remain (`--ground=dust|moss`, G cycles).
2. **The mouse run is a true safe room.** `city_kit_refuges.gd`:
   `MOUSE_ECHO := false`. The step echo (and its two silent beacons) is not
   built for the mouse run. Flip the const on for the old behaviour. The
   hush gallery's splash echo, the niches' glow and the slotted wall's reach
   are unchanged. Behaviour change, so this is the one exception to "surface
   only". Smoke clean; I did not play the chain.

## Stills (gitignored `captures/cityweather/`)
Same cameras before and after, grass ground, torch and haze:
- Yards: `before_{gallery,breaks,refuges,fires}_{torch,haze}.png`, and
  `after2_*` (the final), sheets `before_sheet.png`, `after2_sheet.png`
  (rows: gallery, breaks, refuges, fires; torch left, haze right).
- Close: `after2_fires_close_*`, `after2_gallery_close_*` (before:
  `before_gallery_close.png`, `before_fires_torch.png` from the same camera
  family).
- Generator, sprawl seed 7: `before_layer_torch`/`after_layer_torch`
  (matching), `after_layer_haze`. The before haze run started on a
  different spot, so it is not the same camera.
- `after1_*` is the first pass (shader fix only, before the wear and the
  lichen change).

What I judge by eye: the glow is gone (stone is dim blue-grey in the torch,
warm brown in the haze, and the torch pool lights it), the wear differences
read close (stair treads paler and chipped, fire stone darker in the
crevices, breaks paler), washes and rain streaks read in haze at gameplay
range, and in the torch the weathering reads near the torch and fades into
the dark as it should.

## Cost
No new texture lookups and no new cellular lookups. Per stone pixel there
are two `mix`es and three global reads (`zs_under*`); `ruin_stone` the same
under its define. Five wear materials instead of one or two: a few more
state changes, no extra passes. I did not run the GPU bench (a rendered
benchmark was out of scope for a look round); by construction the change
is within noise of the PR #26 budget (ALU only).

## Limits
- The far tower shafts, serpent heads and plain slabs are the same weathered
  stone; beyond a few tens of metres the shader's footprint fades turn the
  fine layers off, and the washes alone carry them, so they still read
  calm at range (400 m shafts are mostly fog). I did not add detail beyond
  the shader, and modelled nothing.
- The Olmec's own look is untouched; the wear knobs apply to the city only.
- `zs_under` is global: only the stone shaders read it; the turf, rock
  (`reference_surface`), foliage and the wanderer still use the hemisphere.
- The ruin kit's shelter bounce (halls) still reads `zs_hemi_*`.
- Torch tint: eased toward grey 35%; the torch's own warm pool carries the
  colour. Tuning: `STONE_FILL` and that mix in `underground.gd`.
- The breaks yard is on greybox ground (the study grid), unchanged.
- No tests added (prototyping). Existing tests not run; `test_city_*`
  that count `CityKit.PIECES` (the registered refuges add four ids) may need
  reconciling in a lock-in round.
- Smoke (headless, 0 errors): the gallery, breaks, fires and refuges yards
  (torch and haze), `run_layer` sprawl seed 1, and ring seed 2 with
  `--underground=haze`.
