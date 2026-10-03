# Scene colors and atmosphere

Open **Colors & sky** in the diorama toolbar, or search **Scene colors &
atmosphere** in the build palette. The existing Sky settings also link to it.

The editor starts on **Looks**, a gallery of nine curated presets with actual
rendered previews. Click a card to apply its colors, lighting, hour, weather and
season together. **Undo look** restores the entire previous state, including
snow/ice and wetness. Switching from winter to a warm look clears inherited
snow and ice immediately. Terrain, objects and camera framing are unchanged.

| Look | Character |
| --- | --- |
| Alpine morning | Blue air, green hills and sunlit stone |
| Golden meadow | Honey light and soft greens |
| Copper autumn | Warm leaves and gentle daylight |
| Rosewater dusk | Blush skies and lavender shadows |
| Enchanted forest | Emerald greens and drifting mist |
| Halloween hollow | Amber foliage, violet mist and a spooky moonlit sky |
| First snow | Pearl light, fresh snow and partly frozen water |
| Nordic night | Silver peaks and aurora |
| After the rain | Wet greens, clearing skies and a possible rainbow |

The previews use the reference landscape. Choose the look by its atmosphere;
your own terrain remains yours. The active card is highlighted. Manual edits
clear that exact match, and saved settings recover it when reopened.

![Curated looks gallery](presets/gallery.png)

A **Palette** changes base colors while keeping the current hour and weather.
**Whole mood** chooses a palette together with time, weather, mist, haze and wind.
Neither changes terrain shapes or objects.

Palettes: Mountain, Meadow, Summer, Desert, Heat, Autumn, Winter, Dusk, Moonlit,
Hollow, Storm, Dawn and Ocean. The families draw on the original Zenscape entry
palettes; these are native editable looks, not new biomes.

Moods: Alpine daylight, Meadow morning, Desert afternoon, Autumn evening,
Winter hush, Misty hollow, Ocean light, Rose dusk, Moonlit stillness and Storm
gathering. The build catalog also finds them by name.

- **Landscape:** grass, leaves/needles, rock/shore, earth/wood, water and palette strength.
- **Sky & light:** upper sky, horizon, glow, daytime sunlight, ambient sky, ground
  bounce, rim light, mist tint, sun/moon strength, ambient strength and exposure.
- **Atmosphere:** all eight weather presets, time and cycling, clouds, valley
  mist, haze, wind and direction, summit mist, cold, autumn, night fill, aurora
  and rainbow. Rainbow visibility still depends on the sun.

Color pickers preview immediately. One picker gesture or slider drag is one
**Undo look** step; choosing a mood can be undone as a whole. Cmd/Ctrl Z and
Cmd/Ctrl Shift Z use this history while the panel is open. Terrain editing keeps
its separate existing history. **Save** writes the current diorama. Look history
is cleared when opening or creating a world.

Colors are bases that lighting, weather and the hour continue to modify. They
are not promises of a matching flat screen color. **Palette strength** blends
colors back toward the original mountain appearance; **Reset colors** also
resets lighting strengths/exposure. Snow remains a coating over these colors.
Creatures and flower heads keep their authored material colors, while receiving
the scene's lighting. Facet variation and individual object tints are retained.
The captured terrain uses soft color masks to distinguish grass, mineral, soil
and snow; artist-painted terrain is also affected by the scene palette.

![Live palette editor](editor-landscape.png)

![Desert palette on the same terrain](desert.png)

## Verification

`tests/test_scene_look.gd` drives editor signals, palette and atmosphere undo,
paused edits, night sky edits, all preset records, real-file save/reopen, older
save migration, malformed palette rejection, material roles and small Retina
window layout. `tests/test_scene_look_render.gd` uses Forward+ framebuffers to
check each surface category, sky, ambient light and fog, plus bare soil in a new
world; resetting is compared with the original rendered frame.

The existing diorama lifecycle and paused lighting tests also pass. Actual
Forward+ captures from `tools/capture_scene_looks.gd` cover five palette families,
three additional moods and all editor tabs at normal/small window sizes.

Scene state stores a versioned `look` record containing finite, bounded RGB
triples and scalar settings. Missing records restore the original mountain
look. Validation precedes world mutation. Shader multipliers default to one,
so standalone studies retain the original appearance until a look is selected.

`tests/test_curated_looks.gd` (removed) verifies every preset over conflicting settings,
full undo/redo including surface weather, save-state roundtrips, selected-card
state, real preview textures, unchanged terrain/framing and small-window scrolling.
`tools/capture_curated_looks.gd` renders the actual nine previews. Run it normally,
import the generated textures, then run with `-- --ui-only` to capture the gallery.
