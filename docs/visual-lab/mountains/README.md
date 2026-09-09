# Mountain scale, first comparison

Three switchable variants on the existing alpine horn terrain. This is a question about relative proportions, not a new global unit system. The existing pond/canopy study remains separate and launchable.

| Variant | Terrain | Scenery and Bigfoot | Peak / Bigfoot visual height |
|---|---|---|---|
| 1 Compact | Existing horn | Existing sizes | about 4.2:1 |
| 2 Taller peaks | Double height above a 3-unit foothill threshold | Existing sizes | about 7.4:1 |
| 3 Smaller inhabitants | Existing horn | 55% scale; planted positions retained | about 7.6:1 |

The peak heights are about 13.6 / 24.1 / 13.6 engine units. Bigfoot's visual bounds are about 3.2 / 3.2 / 1.8 units. The ratio uses peak elevation above terrain datum, not summit relief above Bigfoot's feet. Bounds come from the current imported model in the frozen pose and are approximate visual measurements, not a gameplay collision height or real-world meters.

The same seed, plant locations, light, water level, and camera settings are used across variants. Smaller inhabitants also scales placed rocks and the generated grass meshes. Plant density is unchanged. The low ground stays fixed in the taller-peaks option, preserving the tarn. Terrain material slope and height responses can change when the peak stretches; this is a geometry experiment, not a pure silhouette-only edit.

Press 1/2/3 or the buttons to switch. C returns to the shared overview; F brings Bigfoot and a nearby conifer forward as scale references. Drag to orbit, scroll to zoom, Space to drift. Bigfoot is a frozen visual reference, with no autonomous navigation. No saved world is read or written; production movement, collision, reach and scales are unchanged.

## First reading

The taller option becomes a sharp spire. The smaller-inhabitants option suggests a larger landscape without changing its outline, but makes Bigfoot less readable from the overview. Both increase the numerical ratio almost equally; they do not deliver the same visual result. A broader mountain footprint and connected ridges are promising next questions. No preferred global scale has been selected.

Native 1600×1000 captures cover the common overview and common inhabitant view. `captures.json` retains the camera, model size, foot position, and peak measurements. The final run completed without script or shader errors; the existing six-instance ObjectDB shutdown warning remains. No performance claim is made.

## Run and capture

```sh
./run-mountain-scale.command
"$HOME/Applications/Godot.app/Contents/MacOS/Godot" --path . --windowed --resolution 1600x1000 --rendering-method forward_plus --script res://tools/prototype_capture_mountains.gd -- --clean --balanced
```

Open `index.html` to compare native stills. These are provisional proportions using an existing formation, not the completed mountain art treatment.
