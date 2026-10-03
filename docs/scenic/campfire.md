# Campfire

Added 2026-10-03 on `feature/campfire`. The stone lamps gave the land its
first light at night. The campfire is the second: a little hearth you set on
the land, with a fire that dances in a ring of stones day and night.

## Placing it

The campfire has its own compartment in the field case, after the stone lamp
(`campfire` in scripts/materials_tray.gd `SPECIMENS`, with an icon in
scripts/hud_icons.gd and a row in the command palette's Elements). In hand it
is a small cursor clump: a ring of pebbles, three sticks and a warm bead.
It is set like the stone (scripts/hand_materials.gd `SCATTER["campfire"]`):

- **Tap** sets one campfire, a little bigger the longer you press.
- **Drag** sets nothing on the way (`tap_only`). It sets one campfire where
  you let go.

The land has to take it (scripts/campfire.gd `refusal`). If it doesn't,
nothing is set, the case's refusal sound plays, and the hint line says why:

| Refusal | When |
|---|---|
| `water` | the middle or any edge of the ring is in live water (`fence_dry`), a pond, lake or stream emergence knows, or off the plate |
| `steep` | the slope (rise over run, presets `_slope`) is over `STEEP` (0.45) |
| `near` | another campfire stands within `CLEAR` (3 m) |
| `tree` | a tree or snag's foot is within `TREE_CLEAR` (1.7 m) times its scale, and never closer than 1.1 m: no fire under a crown or in a trunk |

A campfire is an ordinary object record (asset `campfire` in
NativeTerrainData `ASSETS`). Each tap is one undo step, and campfires save
and load with the world. The trash can takes them away like any other
object, and the hand's pluck can pull one. It arrives with the drop
reactions' `settle`.

## The look

Following the style rule (docs/scenic/style.md), the solid parts are faceted
and the fire is soft.

- **The hearth** (scripts/campfire.gd) is about a metre across. Nine squat
  six-sided stones make the ring, each its own size and lean, in three greys.
  Inside is a low dark mound of ash, and five sticks lean together in a
  teepee, bark below and charred where they meet. A split log lies across
  the ash. It uses vertex colours on the stones' flat-faced material, and
  GardenView draws every campfire in one batch.
- **The flame** is five tongues per fire (scripts/campfire_fire.gd
  `FLAME_TONGUES`), one tall in the middle and four smaller round it. They
  use the wildfire's own add-blended flame shader
  (shaders/fire_flame.gdshader), so they boil, sway and lick on the GPU
  exactly like a burning cell. Each tongue has its own phase, so no two lick
  together. They lean with the wind where the fire stands. The lean is read
  from the same wind pollen rides (scripts/pollen_wind.gd), so the wind
  tool's gusts bend them too, and it eases in.
- **The glow** is a soft camera-facing halo round each fire, using the stone
  lamp's halo shader. It is strong at night and very faint by day.
- **Smoke** is thin pale puffs on the wildfire's smoke shader. They rise
  about half a metre a second, spread, lean downwind as they climb and are
  gone in about five seconds.
- **Sparks** are a few embers on the wildfire's ember shader. They fly up,
  cool from white-gold to red, drift with the wind and fall away.
- **The crackle** is one quiet voice at the nearest fire, playing the
  wildfire's own synthesized crackle (FireEffects `_build_audio`, no audio
  file) every 0.25 to 0.9 s at a varied pitch. It follows the Nature sounds
  toggle and volume.

## Light

There is no new pool of lights. The campfires join the stone lamps' pool
(scripts/stone_lamp_lights.gd) as **guests** (`set_guests`): the nearest
`MAX_LIGHTS` (8) of lamps and campfires together get a real OmniLight3D (no
shadows), picked again every 0.25 s and handed on with the lamps' 0.4 s
fade. A guest brings its own reach (5 m at scale 1), colour (`ff9a4a`) and
energy (`guest_energy`, the campfire's `energy`):

- **By night** the energy is 1.8. **By day** it is 0.35, a small warm touch
  on the stones. Day and night use the lamps' eased glow, so the fire
  brightens at dusk with them.
- **Flicker**: three slow sines, all under 1 Hz, with a phase per fire
  (`flicker`). The energy stays within 0.71 to 1.01 of its base and changes
  less than 1% a frame. It breathes rather than strobes.
- **Rain** (and snow) eases in over 3 s from the sky's precipitation. In
  full rain the light and glow lose 60% (`RAIN_LIGHT`), the flames lose 45%
  of their height (`RAIN_FLAME`) and fade a little, sparks thin to a fifth,
  and the smoke thickens.

## Contained, not wildfire

A campfire never touches the wildfire (scripts/fire_field.gd).
FireField `group_of("campfire")` is `"inert"`, so the field never ignites the
record. Nothing in scripts/campfire_fire.gd calls the field, and its flames,
smoke and sparks are visual only. A tree beside a campfire stays a tree.

## Cost

- The hearths are one GardenView batch. The flames (5 per fire), the glows,
  the smoke and the sparks are one MultiMesh each, with one shared material
  each, for any number of fires.
- The flames' instance data (place, height, lean) is written every 0.1 s.
  That is five instances per fire, and the dancing itself is all in the
  shader.
- Only the `ACTIVE_FIRES` (6) fires nearest the camera smoke, spark and
  crackle. The pools are capped at 72 puffs and 60 sparks, so a field of
  fifty campfires costs the same particles as six.
- Real lights stay capped at the lamps' 8, shared with them.
- The records are read again when the objects change, and every 0.5 s
  otherwise, so the fires stay on reshaped ground.

## Checks

`tools/probe_campfire.gd` runs headless (`-- --modeless --no-title`) and
covers:

- the tray slot;
- a tap: one campfire, one undo step, drawn, flames and glow laid, smoking
  and sparking;
- undo taking it away;
- the water refusal, on live water stood on dry land for the test, since the
  cozy world has none in view;
- the near-another and under-a-tree refusals;
- a real light at midnight from the shared pool, warm and shadowless;
- the flicker's range and its per-frame change;
- rain dimming the light and lowering the flames;
- a smaller light by day;
- 17 fires and lamps under the cap of 8 lights, with only 6 fires smoking;
- 25 s beside a tree with the wildfire field quiet and the trees unburnt;
- a save round trip through JSON;
- the trash taking it, lights too, with undo bringing it back.

Headless uses the dummy renderer, so none of the look is verified there:

- the hearth's shape and colours;
- the flame tongues' size, brightness and lean;
- the halo;
- the smoke and sparks;
- how the light falls on the ground and grass;
- whether the flicker reads as gentle on screen.

The crackle's level is not verified either. All of these need a rendered
look by day and at night.
