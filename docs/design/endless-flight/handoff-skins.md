# Handoff: plane skins (loop `skins`)

Branch `iter/skins`, worktree `../zenscape-skins`. Spec:
`spec-skins.md` beside this file; its "The contract" section is the
reference for adding a skin. Trail: `git log --grep='^ITER(skins)'`.

## What is built

The shop's Paints list holds 30 skins: the 7 from before and 23 new ones.

- **The system (stage 1, seven iterations).** A paint row carries a
  `rarity` (shown as the colour of its name), an optional `finish` (sheen:
  satin, gloss, matte, metal; a pearl edge colour; a glow after dark), an
  optional `decal` and an optional `bake` (its own atlas maps). Only the
  worn or tried skin's textures load. The list scrolls. Prices sit in a
  band per rarity (`ShopStock.PRICE_BANDS`): common 60-150, uncommon
  120-350, rare 500-1000, legendary 1500-3000.
- **Tools** (`tools/README.md`): the decal painter
  (`art/blender/hero_plane/hero_plane_decal.py`), the bake maker
  (`hero_plane_bake.py`), the skin sheet (`tools/skin_sheet.py`).
- **The skins.** Each batch is `scripts/endless/skins/<batch>.gd` with its
  textures in `assets/models/hero_plane/skins/<batch>/` and its script in
  `art/blender/hero_plane/skins/<batch>.py`.

| Batch | Skins (rarity, price) |
|---|---|
| demo | Chequer (rare, 600), Moonstone (rare, 700), Silverwing (legendary, 2000) |
| heritage | Pennant (common, 110), Courier (uncommon, 200), Clubman (uncommon, 310), Barnstormer (rare, 720), Meridian (legendary, 2100) |
| wild | Kingfisher (common, 110), Shark (uncommon, 180), Bee (uncommon, 300), Moth (rare, 700), Koi (legendary, 2100) |
| metal | Gunmetal (common, 110), Rust (uncommon, 160), Copper (uncommon, 330), Brass (rare, 780), Gold (legendary, 2600) |
| glow | Filament (rare, 640), Cinder (rare, 880), Vesper (legendary, 1700), Borealis (legendary, 2300), Abyss (legendary, 2800) |

The skins' textures are 14 MB on disk.

## What the rounds learned

- The play camera sits behind and above: a skin's identity has to be on
  the top wing, the tailplane, the fin and the body's back. The wing cloth
  in the atlas is cream and the `wing` colour barely tints it, so a skin
  that wants coloured wings paints them in its decal.
- Gloss whitens dark paint edge-on and turns a dark plane silver at night.
  Gloss against satin barely differs at flying distance.
- Lettering on the body is cut by the struts and collides with the atlas's
  own "27"; the fin is the place for a word or number. Letters on a wing
  mirror on one half.
- A glow shows on dark paint and is lost on white. A decal's glow colour is
  also its day colour.
- Bare metal reads as metal only with the finish's `bare` mirror on and a
  bake that bares the whole airframe (`cloth="bare"`); both are off by
  default.
- After repainting a decal or remaking a bake, run
  `python3 tools/godot.py --import` before the sheet, or it shows the old
  texture.

## Checks

- `tools/smoke.py studies/endless_flight.tscn` PASS after each merge.
- A headless drive through the real shop (stage 1, task 5): try, buy,
  wear, take off, reload; 17 of 17.
- Every skin's sheet looked at; each lane had a second pass after the
  first sheets were judged from the chase view. The metal lane was rerun
  on Opus.

## Open

- Not played by hand.
- Meridian from behind is a dark plane: its gold lines are too fine at
  flying distance.
- Cinder by day reads brown, not charcoal with dark cracks.
- Rust reads as an all-brown plane from behind.
- Shark's mouth cannot be seen from behind.
- Pennant and Courier still show the atlas's "27" on the body.
- Mid-scroll, the shop list's bottom row is cut off at the list's edge.
- The out-of-band price warning exists but was not itself tested.
- Night sheets were not shot for the metal and heritage skins.
- Day and season presets for the shop are a later build.
