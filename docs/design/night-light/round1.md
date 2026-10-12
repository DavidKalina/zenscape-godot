# Night light, round 1

Branch `look/night-light` (not merged). The aqueduct isle at night (clear sky, autumn,
23:00): moonlight on the land, less blobby glows, runes and lanterns on the ruins,
the dragon and the serpent glowing, clouds kept moonlit.

## Captures

All in `/private/tmp/zs-night/`, 1440x900 windowed on the Mac. The tool is
`tools/capture_night_light.gd`:

    Godot --windowed --path . --resolution 1440x900 -s res://tools/capture_night_light.gd \
      -- --out=/private/tmp/zs-night/after --hour=23 --weather=clear --season=autumn [--shots=wide,rune]

It passes `--no-title --day-length=0 --still-weather --dragon --dragon-skip=40`. Note
that `--still-sky` would hold the start look and ignore `--hour`. Shots: wide, circle,
rune, aqueduct, arch, plane, airship (plus airship_bare and airship_near), dragon and
serpent. The game hangs on quit after a capture (`capture_front_door` hangs too), so
the tool kills its own process at the end.

| view | before | after |
|---|---|---|
| title (the user's command) | `title_h23.png`, `before_title.png` | `after_title.png` |
| isle wide | `before_wide.png` | `after_wide.png` |
| stone circle on foot | `before_circle.png` | `after_circle.png`, `after_rune.png` (close-up of a rune) |
| aqueduct / arch / plane | `before_aqueduct.png`, `before_arch.png`, `before_plane.png` | `after_*` |
| far airship (521 m) | `before_airship.png` | `after_airship.png`; `crops/t2_a0.png` (blob) vs `crops/t3_a0.png` (fixed) |
| dragon | `before_dragon.png` | `after_dragon.png` |
| serpent | `before_serpent.png` | `after_serpent.png` |
| clouds | `before_wide.png`, `crops/cloud_before.png` | `c3_wide.png`, `after_wide.png` |
| by day, 13:00 | `day_before_{wide,circle,plane,serpent,dragon}.png` | `day_after_*` |
| other night styles | | `style_nocturne_wide.png`, `style_mystic_wide.png` |

By day the after captures match the before ones. The only new thing in the day view
is the stone lanterns standing as props.

## What changed

1. **Moonlight on the land** (`studies/celestial.gd`, shared with the old game):
   - The moon key is `MOON_KEY` (2.0) times what it was.
   - The night fill energy is `NIGHT_FILL_ENERGY` (1.1, was 0.4 per unit of fill).
   - The rim's night floor is `NIGHT_RIM` (0.16 to 0.42, was 0.12 to 0.3).
   - The grade's rod-lit shift and the sky are unchanged.
   - The title's scrim (`shaders/title_scrim.gdshader`, `strength`) eases to
     `NIGHT_SCRIM` 0.5 at night (`scripts/kit_isle/front_door.gd`). By day it is as
     before. At night it pressed the isle into a black cutout.
2. **Light sources on the isle** (`scripts/kit_isle/kit_night_lights.gd`, hooked in
   `studies/aqueduct_isle.gd` `_add_life`, with the spots in `NIGHT_LAMPS`):
   - **Runes:** 17 carvings on the stone circle, grand stair, arch and heel stone.
     They are placed by ray-casting onto the kit blocks' own hulls. They use the
     serpent's glyphs (`shaders/rune_glyphs.gdshaderinc`, which is now shared with
     `rune_serpent.gdshader`) and are drawn by `shaders/ruin_runes.gdshader` as one
     MultiMesh that casts no light. They glow pale cool blue and breathe slowly.
   - **Lanterns:** 10 lanterns (2 behind the parked plane, the grand stair's foot and
     head, the path, the circle, the aqueduct head, the heel stone and both sides of
     the gate). They use the stone lamp mesh in the ruins' stone, with a warm core and
     halo. Only the 4 nearest the eye cast light (OmniLights, no shadows). Their posts
     collide only on the walker's layer (the parked plane's `PARKED_LAYER`).
   - Both fade with `StoneLampLights.night_for`.
3. **Blobby glows:**
   - `shaders/cluster_halo.gdshader` has a new `far_pixels` floor. Far off, a halo is
     the smaller of `far_size` × distance and N pixels.
   - The airship sets `FAR_PIXELS` 4. A 521 m airship now shows as a ship with a few
     warm points; before, it was a disc about 15 m across.
   - `scripts/look_pass.gd`: at night the bloom's wide levels drop (`NIGHT_GLOW`:
     level 3 to 0.6, level 4 to 0.25). The bloom only runs on the Beauty and Ultra
     tiers. Balanced, the default, has none.
4. **Dragon** (`scripts/sky_dragon.gd`, `NIGHT_*`):
   - At night the eyes go from 2.2 to 7.5 and get a warm halo each, placed from the
     eye mesh on the head bone.
   - The spines and tail blade go from 1.6 to 3.6.
   - The membrane's rose edge goes from 0.42 to 1.1, reaches 0.3 further in, and its
     veins show lit through.
   - An ember glows in the throat and mouth, stronger with the jaw open or breathing in.
   - The hide gets a faint cool sheen.
   - It all eases in over 2.5 s. The host sets `dragon.sky_scene`.
5. **Serpent** (`scripts/rune_serpent.gd`, `shaders/rune_serpent.gdshader`):
   - At night the runes go up to `NIGHT_GLOW` 2.1 (was 1.25).
   - They shift to a deeper amber (`NIGHT_RUNE_COLOUR`), which keeps them from
     blowing out to white.
   - The halo in the stone around each stroke grows (`NIGHT_HALO`: share 0.62,
     spread 24; by day 0.32 and 10).
6. **Clouds at night** (follow-up). My key and fill changes did not lift the clouds.
   In gameplay they were already this white before (`crops/cloud_before.png`). The
   blue-grey in `title_h23.png` came from the title scrim, and halving the scrim showed
   them white. Fixes:
   - The moon's light on the clouds is now `NIGHT_CLOUD_LIGHT` (0.1 to 0.42, was 0.12
     to 0.85; `--night-cloud=` scales it).
   - The cloud volume's painted moonlit sea leads at night (`NIGHT_TINT` 0.72, was 0.4).
   - The drifting puffs (`sky_cloud_puff.gdshader`) are lit from the moon's side at
     night, with less sky light and less light wrapped onto the far side.
   - The teal glow across the sea under the isle was there before (`before_wide.png`).
     It is the lower world showing through the cloud sea, and this round did not
     touch it.

## Knobs

- `celestial.gd`: `MOON_KEY`, `NIGHT_FILL_ENERGY`, `NIGHT_RIM`, `NIGHT_CLOUD_LIGHT`.
  Flags: `--moon-key=`, `--night-fill=`, `--night-cloud=`.
- `kit_night_lights.gd`:
  - runes: `RUNE_COLOUR`, `RUNE_ENERGY`, `RUNE_SHARE`, `LANDMARK_SHARE`, `UNCARVED`,
    `MAX_RUNES`, `RUNE_APART`
  - lanterns: `MAX_LIGHTS`, `LIGHT_RANGE`, `LIGHT_ENERGY`, `HALO_*`
  - flags: `--no-night-lights`, `--no-runes`, `--no-lanterns`
- `ruin_runes.gdshader`: `width`, `halo`, `halo_spread`, `breath_*`, `reach`.
- `sky_airship.gd` `FAR_PIXELS`; `look_pass.gd` `NIGHT_GLOW`; `front_door.gd`
  `NIGHT_SCRIM`.
- `sky_dragon.gd` `NIGHT_*`; `rune_serpent.gd` `NIGHT_GLOW`, `NIGHT_RUNE_COLOUR`,
  `NIGHT_HALO`.
- `cloud_volume_composite.gdshader` `NIGHT_TINT`; `sky_cloud_puff.gdshader`
  `NIGHT_SKY`, `NIGHT_WRAP`.

## Open

- **Rune colour.** The brief asked for cool runes "in the colour family of the serpent
  and lodestones", but both of those are warm gold. I went cool (pale blue) for the
  contrast with the lanterns. Warm gold is a one-line change (`RUNE_COLOUR`).
- **Runes in the wide view.** From the wide view (about 150 m) and the title the runes
  can't be seen. They read on foot. If they should read from the air, raise
  `RUNE_ENERGY` or the glyph size.
- **Rune coverage.** The aqueduct and castellum get no runes, because their collision
  is invisible boxes, not the stone. Floating stones, crag walls and islands are left
  out on purpose.
- **Dragon.** The membranes still read as large flat pink panels at night. The eye
  halo is small.
- **Ground brightness.** The moonlit turf can read a little pale and sandy up close
  (`after_circle.png`). If it feels too day-like, `--moon-key=1.6` is a gentler try.
- **Other halos.** The sky clusters' halos (`cluster_dresser.gd`) still use only
  `far_size`. They could take `far_pixels` too.
- **Night styles.** Only checked by eye in wide shots (Storybook, Nocturne, Mystic).
  Opal wasn't captured.
- **Lantern spots** are hand-placed for the aqueduct isle. The motif isles have none.
