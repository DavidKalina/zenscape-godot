# Underground look, round 1

A first-look experiment, not a lock-in: the run starts deep underground
and climbs toward the sky. `--underground[=torch|haze]` swaps the sky isle
look for an abyss, behind the flag; the default look is unchanged.

## Built, and where

- `scripts/underground/underground.gd`: one node, stood on a kit-isle
  study by `Underground.attach(self)` in `studies/kit_isle.gd`
  (after `_add_sky`). So the motif yard has it now, and run_layer
  (also a kit isle) takes the same flag later, no wiring needed beyond
  `recenter(at)` to put the shaft on a layer's middle. It holds its values
  on the study's environment every frame (process priority 1000), so the
  day, weather, air, cloud sea and stars still run but never show.
- `shaders/abyss_sky.gdshader`: dark gradient sky, with a faint far cool
  light straight up (torch preset only: the surface).
- `shaders/abyss_rock.gdshader`: the enclosing rock shaft (strata and
  ledge shading, lit "from above", murk by distance). Backdrop geometry,
  no collision, no shadow. Pushed very far out (about 1 km in torch, 1.8 km
  in haze), so it is only a hint of an enclosure; the floor never shows.
- Far silhouettes (both presets): about 30 pillars on six height layers
  (-280 to +380 m about the start), 480 to 1250 m out, topped with stepped
  pyramids, temples or halls; plus one hero aqueduct-bridge (two tiers of
  arches between two pyramid pillars, far north, -z). Boxes and cones in
  the study's own fog: no collision, no kit. Some carry a pair of
  amber "eyes" (fog-proof) as stand-ins for far Olmecs.
- Torch (both presets, strong in `torch`, a glow in `haze`): a flickering
  warm OmniLight with shadows and a small flame on a stick, parented to
  the wanderer's `figure`; animation and movement untouched.
- Olmec eyes: `scripts/enemies/inhaler_head_look.gd` `glow()` keeps the
  eyes burning at rest under `--underground` (`UNDER_REST`, `UNDER_ENERGY`).
  Shape, motion, collision untouched.
- L (the look key) flips torch/haze live (`kit_isle.gd` `step_look`
  hands it to `Underground.cycle()`). Not exercised rendered with a real
  key press (headless cannot, and I only used flags); it is one call.

## Motif

The sunken giant, in the yard: the roomiest place with heads and
climbable flanks, so the headless bodies actually have somewhere to go.
The sundered gorge is a kit motif (no heads, no bodies); the drowned nave
is its own isle study, not in the yard.

## Play

`./run-underground.command` (torch), or any of:

    <godot> --path . res://studies/motif_yard.tscn -- --no-title --motif=sunken_giant --underground=haze
    ./run-underground.command --underground=haze     (later flags win)

Press L to flip presets. Knobs: `--underground-fog=`, `-volume=`,
`-ambient=`, `-moon=`, `-exposure=`, `-torch=`, `-torch_range=`.

## Stills (docs/design/roguelike/underground-round1/)

- `compare_torch_haze.png`: same camera, torch left, haze right.
- `wide_torch_haze.png`, `wide_torch.png`, `wide_haze.png`: the
  establishing view from the start spot looking north at the bridge.
- `torch_near_ledge.png`: the torch lighting the lip of the isle.
- `eyes_at_lip_torch.png`, `eyes_at_lip_haze.png`: the head's glowing
  eyes at a lip.

## What worked

- The torch on the orange turf is a strong read: a pool of warm light and
  a hard cut to dark at the ledge.
- Haze: far pyramids and the bridge fade through layers; reads vast.
- Eyes burn visibly in both presets; the amber pair against the dark is
  the best frame.

## What did not, or is thin

- Not played: no body was seen climbing a flank in a still; only the
  heads were framed. The headless body itself has no eyes (the head does),
  so "eyes over the lip" is the head, or a reunited whole one.
- The far Olmec bodies (existing model, existing clip) were skipped: not
  cheap. Far "eyes" pairs stand in.
- The wall's noise reads as rough cloud, not rock; the far silhouettes are
  blocky and flat-coloured. The turf and the isle's cliffs stay saturated
  orange / blue-grey, since the ruins' materials are untouched.
- Intermittent 150 s stalls on a first rendered launch (shot.py timeout)
  on this Mac, unrelated to the look; a retry passed.

## Knobs to tune next

Haze fog density (`fog`, 0.0016) and exposure; far isle contrast (stone
albedo in `_build_far`); wall scale per preset (`wall_scale`); torch
energy/range per preset; eye energy (`UNDER_ENERGY`); the turf saturation
under the dim light (grade the isle's orange down); the far light's
strength; far-isle count and layer heights; give the bridge a real arch
profile.

## Existing tests this breaks

None expected. `inhaler_head_look.gd` and `kit_isle.gd` have no-op
changes without the flag. The full suite was not run.
