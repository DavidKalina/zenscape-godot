# Spec: wind across the wilderness (loop `wild-wind`)

The wilderness should feel alive with wind: some spots windy, some calm,
windier at some hours than others, and the grass and trees showing it.

## What's there today

- One wind for the whole view: `scripts/endless/endless_look.gd` `_publish`
  (around :677) wanders one heading, breathes one strength and runs the gust
  clock, then sets the `zs_wind_*` / `zs_gust_*` / `zs_motion_time` shader
  globals (`project.godot` `[shader_globals]`,
  `shaders/reference_globals.gdshaderinc`). Its strength comes from the
  blended mood (`blend_moods`), not from the spot, and not from the hour.
- The Amberlands' windy look is not stronger wind. It is the grass that
  "blows as one" (`scripts/endless/grass_sheen.gd` `swell()`/`pace()`, used
  in `scripts/endless/world/amberlands/look.gd` paint; shaders
  `grass_sheen.gdshaderinc`, `endless_tuft_far.gdshader`,
  `endless_ground.gdshader`, `reference_surface.gdshader`): slow long swells
  of light and dark, far tufts leaning on each crest, straw undersides
  showing. Commit 306dfacc. The wilderness doesn't use it.
- Near spruce sway (`endless_spruce_sprite.gdshader`, `tree_wind.gdshaderinc`,
  reading `zs_wind_*` and `zs_tree_gust`). The far spruce ring
  (`endless_spruce_ring.gdshader`) and far trees (`endless_tree_far.gdshader`)
  are still.
- The clock: `scripts/endless/day_cycle.gd` (`DayCycle`, 20 min a day, no
  real night: blue hour then dawn; `docs/design/endless-flight/day-cycle-handoff.md`).
- Wind sound: `scripts/endless/flight_sound.gd` breeze and thin-wind beds,
  driven by altitude only. Wind followers: `scripts/pollen_wind.gd`,
  `scripts/wind_leaf_litter.gd`, `scripts/shared/gust_fronts.gd`,
  `scripts/endless/endless_eddies.gd`. The grass already bends from the plane
  through a gust map (`scripts/endless/grass_react.gd`, `zs_gust_map` /
  `zs_gust_rect`): a pattern for handing a map around the eye to shaders.

## What done looks like (what the user plays and sees)

In the wilderness (seed 1, the main scene, `run-endless-flight.command`):

1. **Windy and calm spots.** From the air you can see the wind differ by
   place: on ridges, high open slopes, coasts and lake shores the grass rolls
   in Amberlands-style swells and the spruce toss; in valley floors and
   sheltered spots by forest the grass stands nearly still and the trees
   barely move. The windy spots come from the land's shape (a ridge that is
   windy stays windy) plus a few slow, broad windy patches drifting
   downwind across the land, so the same place changes over minutes.
   Changes are smooth in space and time: no seams, no pops.
2. **The hour.** Still at dawn, the wind building through late morning to
   an afternoon peak, easing through golden hour and dusk, near still in the
   blue hour. Each day rolls its own temper (calm, breezy or gusty) that
   scales the curve, so two days don't feel the same. Deterministic from
   the land seed and the clock (co-op someday: the same seed and time give
   the same wind on every machine).
3. **Grass follows the local wind.** Where it's windy the wilderness grass
   gets the Amberlands blow-as-one swell (near and far tufts lean, sheen
   rolls); where it's calm it eases toward still. Keep the wilderness's own
   grass colours; only the motion and sheen follow the wind.
4. **Trees follow it.** Near spruce sway harder in the wind, less in calm.
   The far spruce ring and far trees get a cheap sway so a windy hillside
   reads from altitude.
5. **The rest of the air follows it.** The breeze sound swells where and
   when it's windy (on top of today's altitude bed). Pollen/leaf litter
   blow with the local wind. Lakes and rivers get dark wind ripples (cat's
   paws) on windy stretches and lie glassy in calm.
6. **The eddies.** The visible wind ribbons (`scripts/endless/endless_eddies.gd`,
   `scripts/breeze_ribbons.gd`; `docs/design/endless-flight/endless-eddies-handoff.md`)
   stay; the user likes the flourish they add. Whether they still earn a
   place beside the new wind is an open question for the user, so don't
   remove them. Two changes:
   - **Their grass motion is wrong.** Today each ribbon head drops react
     stamps every 2 m into the grass's react map (`GrassReact.eddy`,
     `scripts/endless/grass_react.gd`, `zs_react_map`). The user sees the
     grass move at a low frame rate or in big chunks. It should be a smooth
     rolling gust of air through the grass instead. Find why it steps
     (the map's resolution, how often it updates, stamp spacing) and make it
     smooth; driving it off the new wind field (a moving gust cell
     the grass reads every frame) is one way.
   - **They follow the wind.** More of them where and when it's windy,
     few or none in calm spots and still hours, travelling with the local
     wind's heading.
7. **The plane is not affected** by the wind in this loop. It will be,
   later; don't build for that beyond keeping the field queryable from
   GDScript at a point (a `wind_at(x, z)`-style call) so it can be.
8. **Flags for A/B:** `--hour=` already exists. Add a way to force the wind:
   e.g. `--wind=calm|breezy|gusty` for the day's temper, `--wind=X` for a
   fixed strength everywhere, `--wind=off` for today's single wind (the old
   look), and a debug view of the field (overlay or map) for checking where
   the windy spots fall. Name them in the handoff.

## Must hold

- The Amberlands looks and plays as it does today (it keeps its held amber
  hour and its grass). Other worlds draw as before unless they opt in.
- Meadows and flats (AGENTS.md): wind is looks only; nothing about the land's
  shape, landing or flats changes.
- Cheap: measure the frame-time cost (flat out, low, near trees) and keep it
  small; say the number in the handoff.
- Stylised, not realistic; keep the look's calm read.
- Seed 1 only for judging (hand placement isn't built).

## The loop

- Trunk only, no lanes: every part reads the wind field, so it comes first.
- Suggested order (the first iteration writes the real Plan):
  1. The wind field: day curve, day temper, place exposure, drifting
     patches, `wind_at(x, z)` in GDScript, the flags, the debug view.
     Checkpoint: a still of the debug view over seed 1 showing ridges windy
     and valleys calm, and a printed strength over the day.
  2. Hand the field to the shaders (a small map around the eye, or computed
     in the shader if cheaper) and make the grass follow it with the
     blow-as-one swell in the wilderness. Checkpoint: stills/short clips of a
     windy ridge and a calm valley at the same hour.
  3. Trees: near spruce by the field, cheap sway for far spruce and far trees.
  4. The eddies: smooth rolling grass motion, and spawning by the local wind.
     Checkpoint: a short clip of an eddy rolling through grass.
  5. Sound, pollen/leaves, lake and river ripples.
  6. Tune by eye across the day, measure cost, final stills.
- Motion doesn't read in a single still: where motion is the point, shoot a
  short frame strip or clip (tools/shot.py, tools/README.md) and look at it.
- Cap: the skill's default. Budget per iteration: 250000 tokens.
- Prototype rules (AGENTS.md): smoke check of `studies/endless_flight.tscn`
  every iteration, rendered stills for anything seen, no new committed
  tests, no full suite. List any existing test a change breaks.
- Play commands handed to the user use `python3` and absolute `cd` paths,
  on a throwaway save (`--pilot-file=/tmp/wild_wind_pilot.json`). Never use
  git stash.
