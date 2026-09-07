# ZenScape — Landscape Sandbox

A new Godot project exploring a cozy landscape sculpting toy. One continuous,
editable diorama: shape a place with a brush, then gradually bring it to life.

## ZenScape fidelity study

Double-click **`run-fidelity.command`** to explore a real ZenScape scene rendered
in Godot with Forward+. **Tab** compares it with the source screenshot; drag to
orbit, scroll to zoom, and **Esc** returns to sculpting. This study imports the
original terrain and 5,366 placed instances and adds native wind, bird, and water
motion. The imported scenery is not yet sculptable.

The motion pass preserves shallow-water depth, adds downstream stream highlights
and a deforming waterfall, and gives birds alternating flaps and glides. Use the
wind slider, **P** to pause motion, and middle-drag to pan. The quality selector
offers Beauty and Balanced post-processing. Frame-rate work is paused.

The environment controls now include wind direction and gusts (**G**), valley
fog, time of day and cycling (**N** advances the sun), aurora, rainbow, and
clear/rain/storm/snow transitions. Cloud cover and light-shaft controls now
share the source cloud field with terrain shadows and pooled fog. The **Cold**
slider freezes water over time; snow accumulates on exposed surfaces and warmth
thaws it. Rain wets ground and foliage, with rainbows emerging as clouds clear.
**Night fill** adjusts landscape readability after dark while preserving the
dark sky; set it to zero for deeper silhouettes.
**Summit mist** independently adjusts the mountain's cloud cap and downwind
spill; zero removes them while keeping valley fog.
**Hold rainbow** keeps one visible while sunlight permits it. See the
[winter comparison](docs/fidelity/winter-comparison.mp4) (winter left, warm right).
**Face rainbow** turns toward the arc and raises the view. Automatic rainbows
fade during snowfall and return in warm, humid clearing air.

Fireflies drift and blink above damp undergrowth on warm nights. Rain quiets
them and cold suppresses them. **Invite fireflies · even in daylight** brings
them out during daytime exploration; **P** freezes their motion and blinking.
Pond frogs breathe, hop into the water and paddle back to their banks, leaving
soft contact ripples. **F** startles them; cold, ice and an empty pond hide them.

Wind, rain and positional waterfall ambience follow weather, growth and freezing.
Their checkbox and volume slider are independent of thunder. **P** pauses all
audio along with scene motion.

**B** summons the original Bigfoot peek rig
in a terrain clearing; **T** triggers the original camera tremor. **P** freezes
these animations, including weather transitions and the encounter pose.

[Bigfoot motion check](docs/fidelity/bigfoot-motion.mp4): moving encounter on the
left, frozen control on the right. The imported rig is checked against 1,300
source joint transforms. See the [full parity checklist](docs/fidelity/PARITY.md)
for completed pieces and remaining systems.

[Six-second motion comparison](docs/fidelity/motion-comparison.mp4): updated Godot
on the left, previous Godot on the right. See [motion pass notes](docs/fidelity/MOTION.md)
for controls and the first motion pass; that video predates the environment work.

[Moving cloud comparison](docs/fidelity/cloud-comparison.mp4) · Godot left,
original Three.js right. The comparison still shows open lighting/fog differences.

[Comparison and remaining gaps](docs/fidelity/NOTES.md) ·
[Godot / Three.js video](docs/fidelity/comparison.mp4)

## Run

Open `project.godot` in **Godot 4.7.2** (standard edition; no .NET needed), then
press **F5** for the fidelity scene with Forward+ lighting and volumetric fog.
Open `scenes/sandbox.tscn` and press **F6** for the sculpting prototype, or use
**Esc** from the fidelity scene.

## First playable slice

- Raise, lower, smooth, and flatten a 24 × 24 unit patch of ground.
- Soft brush footprint, adjustable size and strength.
- Orbit, zoom, and pan around a faceted grassy diorama.
- Undo and redo complete brushstrokes (up to 50).
- Save to `user://landscape.json`; reload on launch. Changes also save when the
  window loses focus or closes normally. Force-quitting bypasses these saves.

| Control | Action |
| --- | --- |
| Left drag | Sculpt |
| 1 / 2 / 3 / 4 | Raise / lower / smooth / flatten |
| Right drag | Orbit |
| Middle drag | Pan |
| Scroll | Zoom |
| [ / ] | Brush size |
| ⌘Z / Ctrl+Z | Undo |
| ⌘⇧Z / Ctrl+Shift+Z | Redo |
| ⌘S / Ctrl+S | Save |

Flatten samples the height where a stroke begins. Terrain supports hills and
valleys; caves and overhangs are outside this heightfield model.

## Structure

- `scripts/landscape_data.gd`: editable heights, brush operations, history, and
  validated serialization. Independent of scene nodes and rendering.
- `scripts/terrain_view.gd`: terrain mesh, earth sides, brush preview, ray picking.
- `scripts/orbit_camera.gd`: camera navigation.
- `scripts/sandbox.gd`: input, brush interface, save lifecycle.
- `scenes/sandbox.tscn`: scene composition, lighting, backdrop, and camera.
- `shaders/ground.gdshader`: ground material and projected brush footprint.

There is one terrain mesh for now. Introduce internal tiles when measurements
justify local mesh rebuilds; tiles should remain invisible to the player.

## Checks

```sh
godot --headless --editor --path . --import
godot --headless --path . --script tests/test_landscape.gd
godot --headless --path . --script tests/test_scene.gd
```

## Direction

Future slices: vegetation painting; selectable rocks and trees that stay rooted
when terrain changes; assisted river drawing with connected water; wildlife
placement and gentle behavior. The first slice deliberately focuses on sculpting.

An entire mountain that can be picked up would need an editable feature layer
above the sampled heights. Establish that interaction before adding such a layer.

The original Three.js ZenScape project remains a separate reference for landscape
recipes, atmosphere, water, and wildlife. This project has no runtime dependency
on it, and does not include its journal or writing-driven world structure.

Press **Y** to replay landscape formation, or use the terrain and foliage sliders.
**P** freezes the replay along with the other motion. Terrain, plants and water use
source growth data. **Refill water** replays the falls, stream and lake alone;
the water slider scrubs their fill. Wildlife arrival remains pending.

[Wind response comparison](docs/fidelity/wind-response-comparison.mp4): new native
wind on the left, previous native wind on the right, at strength 2. Source lean,
flutter, shiver and bending now use the captured foliage tuning.

Press **L** or **Lightning** for a strike; Storm also schedules strikes. Bolts
light the clouds and ground, followed by a spreading gust. **P** freezes the
sequence, including delayed thunder audio. Toggle **Thunder sound** to mute it. [Lightning comparison](docs/fidelity/lightning-comparison.mp4)
shows a strike on the left and a control on the right.

Around sunrise and sunset, a climbing shadow leaves the mountain peaks in
gold and rose afterglow. [Sunset comparison](docs/fidelity/alpenglow-comparison.png)
shows native Godot on the left and the original on the right.

A calm, clear dawn now pools mist below the peaks, then breaks it into patches
as the sun rises. Strong wind and overcast suppress the inversion.
[Dawn comparison](docs/fidelity/inversion-comparison.png): Godot left, original right.

**G** now sends traveling gusts through the shared air field. Nearby presses
strengthen the latest gust; older gusts continue across the landscape.
[Left-bank gust comparison](docs/fidelity/gust-comparison.mp4): gust left, control right.

Weather presets now control wind, mist and haze together with precipitation.
Fair, Overcast and Mist are available alongside Clear, Rain, Storm and Snow.
Use **Haze** for atmospheric depth; the wind slider reaches full storm strength.

Autumn is available in the weather selector, with a separate Autumn slider.
The turn preserves warm/cool green differences and warms the lighting; Snow
retains turned foliage under its snowpack. Canopy-bound falling leaves now share the seasonal and wind state.

The fidelity scene now blends fog after tone mapping, matching the source
compositing order. Use `--native-fog` to compare the previous volume renderer.
See docs/fidelity/DISPLAY-FOG.md for validation and remaining gaps.
