# Night light, round 2

Branch `look/night-light-2`, off `look/night-light` (round 1, `round1.md`). Not merged.
Aqueduct isle at night (clear, autumn, 23:00) unless said.

## Captures

All in `/private/tmp/zs-night2/`, 1440x900 windowed, taken with
`tools/capture_night_light.gd` (see round 1). The "before" is round 1's final look in
`/private/tmp/zs-night/`. Round 1's `rune` shot is now `ruins`: a low pass about 70 m
off the circle, stair and aqueduct.

| goal | before | after |
|---|---|---|
| 1. dragon at night | `zs-night/after_dragon.png` | `after_dragon.png` (top side), `k4_dragon.png` (underside), `opal_dragon.png` |
| 1. dragon by day | `zs-night/day_after_dragon.png` | `day_after_dragon.png` |
| 2. turf up close | `zs-night/after_circle.png`, `zs-night/after_aqueduct.png` | `after_circle.png`, `after_aqueduct.png` |
| 2. isle from afar | `zs-night/after_wide.png` | `after_wide.png` |
| 3. ruins' own light | `without_ruin_light_{wide,ruins,aqueduct}.png` (`--no-ruin-light`) | `after_{wide,ruins,aqueduct}.png` |
| 4. Opal night style | (not captured in round 1) | `opal_{wide,circle,ruins,dragon}.png` |
| by day, 13:00 | `zs-night/day_after_{wide,circle}.png` | `day_after_{wide,circle}.png` |

The day captures match round 1's to the third decimal in the measured turf boxes.
Other captures in the folder are tuning steps (`d*`, `k*`).

## What changed

1. **Dragon wings** (`scripts/sky_dragon.gd`):
   - **Why the old look failed.** The model's membrane is one grid panel per span
     (`art/blender/rim_dragon/dragon_body_build.py`, `panel`). On the finger panels,
     UV.y runs from one finger to the next, not toward the free edge. The old
     `UV.y` band therefore lit each finger panel from dark at one bone to full pink
     at the next. That made the flat pink panels with hard black bands.
   - **Tagging the panels.** `_tag_membrane` now finds each panel as a connected
     piece of the surface. The two pieces nearest the body are the arm panels. It
     writes a vertex colour to every vertex:
     - r: how near the free trailing edge (arm panel: v; finger panels: u)
     - g: how far from any bone, i.e. how thin the membrane is
     - b: the coordinate the veins cross
     The mesh is rebuilt once with that colour channel, at dress time.
   - **Night look.** The night shader mixes in a dark leathery hide (`night_hide`)
     and an ember rose (`night_ember`). The rose is strongest at the trailing edge
     (eased `pow(smoothstep)`), runs soft along the veins (Gaussian lines), and puts
     a faint warmth through the thin middle (`night_body`), so no panel goes flat
     black.
   - **By day** the shader computes exactly what it did before.
   - **Eyes.** The halo is bigger (`NIGHT_EYE_HALO` 4.2, strength 1.0). It is also
     drawn `NIGHT_EYE_HALO_LIFT` (0.35) of its size toward the eye, so the head no
     longer hides half of it. This is a new `toward_eye` uniform on
     `shaders/stone_lamp_halo.gdshader`; it defaults to 0, so the lamps are
     unchanged.
2. **Turf up close:**
   - **The near ground itself.** In `shaders/reference_surface.gdshader`, at night,
     the ground (`terrain_growth`), grass blades and flowers go darker
     (`NIGHT_NEAR_DIM` 0.5) and partly to a cool grey (`NIGHT_NEAR_COOL` 0.25,
     `NIGHT_NEAR_HUE`). This eases back to the full moonlit look between 12 and
     70 m (`NIGHT_NEAR`). Measured (sRGB luma), the near turf box went from 0.264
     to 0.186; before round 1 it was 0.149.
   - **Autumn's warm cast** (`studies/celestial.gd`) was left on the moon key, the
     fill and the haze at night. Now only `NIGHT_AUTUMN` (0.15) of it stays under
     the moon. This also takes the wide view's turf from 0.243 to 0.218, a little
     cooler.
   - **What didn't help.** `--moon-key=1.4 --night-fill=0.75` barely changed the
     near turf, so `MOON_KEY` and `NIGHT_FILL_ENERGY` stay at round 1's values.
   - **The night grade's colour keep** (`look_grade.gdshaderinc`, `keep` from 0.5)
     would also let bright turf keep its day colour. I tried raising it, but on
     Balanced the capture didn't change at all. I reverted it, so it is untested.
3. **Runes removed; the ruins' own light** (the user's change of direction):
   - **Removed:** the rune carvings, their code and `shaders/ruin_runes.gdshader`.
     `shaders/rune_glyphs.gdshaderinc` stays because the serpent still uses it.
   - **The stone holds the moon.** `shaders/ruin_stone.gdshader` defines
     `ZS_NIGHT_STONE`, and the block is in `shaders/folk_surface.gdshaderinc`. Faces
     turned to the moon get a cool lift, and tops get a little
     (`night_catch` × `zs_moon_light`).
   - **Lantern bounce.** The stone also takes a soft warm bounce from every lantern
     within 7 m (`night_lamps[16]`). This is done in the shader and casts no light.
   - **Washes.** Three broad, faint, cool OmniLights with no shadows sit over the
     stone circle, the aqueduct's arcade and the far gate (`WASHES`).
   - **Light count.** With the 4 lantern lights that makes 7 real lights at most.
   - The lanterns are unchanged.
   - `kit_night_lights.gd` sets the stone material's parameters every frame,
     faded by its night glow. The stone material is shared by every kit isle's
     ruins, so motif isles in view catch the moon too.
4. **Opal:** captured. Nothing round 1 or 2 changed looks wrong there. The ruins read,
   the turf is cool, and the dragon looks as it does under Storybook.

## Knobs

- `sky_dragon.gd`: `NIGHT_MEMBRANE` (day glow, night energy), `NIGHT_MEMBRANE_REACH`,
  `NIGHT_EYE_HALO`, `NIGHT_EYE_HALO_STRENGTH`, `NIGHT_EYE_HALO_LIFT`. In the membrane
  shader: `night_hide`, `night_ember`, `night_vein`, `night_body`, `vein_width`.
- `reference_surface.gdshader`: `NIGHT_NEAR`, `NIGHT_NEAR_DIM`, `NIGHT_NEAR_COOL`,
  `NIGHT_NEAR_HUE`.
- `celestial.gd`: `NIGHT_AUTUMN`. Round 1's `MOON_KEY` and `NIGHT_FILL_ENERGY` are
  unchanged.
- `kit_night_lights.gd`: `MOON_CATCH`, `BOUNCE`, `BOUNCE_REACH`, `BOUNCE_COLOUR`,
  `WASHES`, `WASH_COLOUR`. Flags: `--no-ruin-light` (catch, bounce and washes),
  `--no-lanterns`, `--no-night-lights`.

## Open

- **Washes.** From the air they are subtle to the point of hard to see. Most of the
  read comes from the stone catching the moon. Raise the energies in `WASHES` if you
  want pools.
- **Lantern bounce** shows only where a lantern stands near stone (the gate, the stair
  foot). Most lanterns stand on open turf.
- **Dragon:**
  - From above, the arm panel's rose covers a broad area. It is smooth and soft, but
    it is more glow than a thin edge.
  - From below, the hide side of a panel can still go very dark between the veins.
  - The far eye's lifted halo can peek over the head's outline.
- **Turf hue.** The near turf now reads cool grey with some of the grass's own colour.
  If it reads frosty, lower `NIGHT_NEAR_COOL`.
- **Night grade at Balanced.** On the Balanced tier, editing the night grade's colour
  keep did not change the capture at all. I didn't find out why.
- **Tests.** The only one run that renders the night is `test_night_styles`, and only
  headless. All the looks above were checked by eye in windowed captures.
