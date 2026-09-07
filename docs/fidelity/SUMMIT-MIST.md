# Summit mist control

The bright patch above the mountain in the snow review is the existing
orographic cap: a lens-shaped cloud in the wind over the summit. A capture with
local atmosphere disabled isolated it from the sky cloud deck and light shafts.

**Summit mist · cap and downwind spill** now controls this component separately
from valley fog and haze. Zero removes it, one keeps the existing strength, and
1.5 permits a denser cap. Wind, humidity, growth and fog-bank coverage continue
to govern where and when it forms. The control also publishes immediately while
paused. Weather presets preserve the chosen strength.

`summit-mist-comparison.mp4` compares strength 0.35 on the left with the default
1.0 on the right in the same snow scene, after 30 seconds of weather settling.
Both captures use the same camera and 90 frames at 30 fps. The footage was
inspected for the weaker cap and downwind spill while retaining snowfall and
the rest of the scene's atmosphere.

Capture with `tools/film_summit_mist.gd` and `--clean --weather=3 --preroll=30
--film-frames=90`, plus a unique `--film-dir`. Add `--control` for full strength.
