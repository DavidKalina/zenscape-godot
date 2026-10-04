# Look pass: open improvements

The October 2026 look pass merged a cloud sea under the plate in three styles
(Opal, Storybook, Mystic; Settings → Clouds, Opal by default), a longer golden
hour, dusk light on the land, and ground colour that follows the land. This is
what it left open, in rough order of how much it shows.

Guiding notes from the review: subtle beats stylized ("the more 'out there' the
worse"), the plate stays the focal point, and autumn must stay vibrant.

## Dusk (18:00–19:30)

- **Mist over hollows.** In close views at dusk, grey ground-mist patches still sit
  over craters and lakes. They are thinner than before but are still the first thing
  you notice. The cause is the ground-mist air pass, which is lit by the sky colour
  rather than dimmed like the land. See `studies/atmosphere.gd` (`EVENING_MIST_SUN`)
  and `tools/probe_dusk_light.gd`.
- **Lamps read weaker.** The dusk fill (`DUSK_FILL` in `studies/celestial.gd`) lifts
  the ground, so stone lamps and the campfire stand out less against it than they
  did. Raise their glow at dusk, or dip the fill near lights.
- **Dusk tint.** The lavender afterglow on the land is subtle. The tint weight
  (0.5) in celestial's `surface_sky` line makes it rosier.

## Day length

Golden hour now lasts about 62 s and the afterglow about 33 s (before: 30 s and 16 s)
of the 480 s day, so full daylight fell from 169 s to 100 s and night from 185 s to
133 s. The other route is a longer day (about 9.5 min) that keeps night's length.
Undecided. The pacing lives in `scripts/world_clock.gd` (`LINGER_E`,
`LINGER_DEPTH_UP` / `_DOWN`, `NOON_HASTE`), and `tests/test_world_clock.gd`
prints the seconds for each phase.

## Cloud sea

- **Opal**
  - The rifts that show land below are fairly round "windows". Make them fewer,
    raggeder and hazier (`SEA_RIFTS`).
  - From some angles the puffs look slightly quilted.
  - At 17:40 it is a touch coral rather than peach (golden-hour `SEA_SUN_TINT`
    0.5 → ~0.42).
- **All styles:** the desert look shows green fields through the gaps, but the land
  below should follow the scene look. In Storybook, rivers can repeat as pale loops
  in big gaps.
- **Mystic:** the light shafts can read as "holy light" in wide views at low sun.
- **Overcast** still shows the plain grey deck.
- **Cost:** none of the three has been profiled on a GPU. Opal and Mystic draw at
  full resolution.

## Ground

- The hue drift (`ground_hue` 1.15) is just perceptible from the overview, and
  `ground_hue` and `ground_shade` are the dials for more. A separate damp band at
  shores was not added.
- The GPU cost (20 extra texture reads per ground vertex) is estimated, not
  profiled.

## Elsewhere, from the scripted play session

- **Crater walls** look like sinkholes: steep, brown, faceted pit walls. Lakes made
  with the crater sit low in rock-walled pits.
- **Wheat** isn't clustered enough. It might be a bigger change.
- **Sunflowers** stand as tall as the trees.
- **The HUD is heavy:** five panels, plus a hint ("Hold in the sky to call a cloud")
  that stays mid-screen.
- **The Settings dialog** uses Godot's default dark theme, not the stitched-fabric
  HUD style.
- **Water from the materials case** does nothing when pressed on dry land; it only
  scoops existing water. A first-timer will likely expect it to make water.
- **The footbridge** is fussy to lay (it refuses with "flooded", "too long" and "dry").
- **Camera moves** with the pointer over land at low angles log non-finite transform
  errors from `cursor_motion.gd` via `land_clay._place_prop`.
- **`tools/capture_title.gd`** loads the old diorama scene, so it can't capture the
  real title menu.

## Tests

- `tests/test_hand_trees.gd` "One pass paints a stand" is flaky headless: one pass
  painted 3–7 trees across runs, and 3 fails the check. It passed 2 of 3 runs after
  the merge and 2 of 2 on main just before it.

## Tools for revisiting

- `tools/capture_backdrop.gd` (`--seed 184 --looks --only=`, `--cloud-style=`):
  backdrop and clouds by hour.
- `tools/capture_golden_hour.gd` (`--suns=`, `--close`, `--resume --places=`):
  evening light at fixed sun heights.
- `tools/capture_ground.gd` (`--classic-form` for before/after, `--diorama`).
- All are rendered runs: pass `--windowed` and `-- --no-title`.
