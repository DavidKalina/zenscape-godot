# Bigfoot lives with the landscape

Bigfoot now mixes quiet environmental activities into his existing wandering,
resting and physical play in the main diorama and Fidelity Life.

- Approaches suitable exposed trunks, wraps both arms around them, or rests one
  arm around the tree. Contact height follows the trunk; unusually thick or
  low trunks are skipped rather than stretching his arms.
- Walks to safe overlooks inside the chunk edge, shades his eyes and slowly
  surveys the horizon.
- Notices visible rainbows and follows the growing ring. At clear night he can
  catch a shooting star already in front of him and track its moving head.
- Tests rain or snow with an open palm, shields his head in rain, and shakes
  himself dry after the rain clears. Existing wind reactions remain in place.
- Flinches at nearby lightning. A direct ground strike within 1.8 meters gives
  him a brief, nonfatal electrical tremble with blue arcs, then he recovers.

These are occasional activities, with cooldowns and time left for his existing
routines. Resting and physical interactions take precedence over quiet scenery
watching. Navigation checks every approach; edits and carrying release contact.
Pausing freezes the behavior clock and defers queued lightning.

## Implementation

`bigfoot_environment.gd` owns approaches and short performances; CreatureActor
layers torso, hand and gaze motion onto the breathing idle. Habitat interests
carry trunk bounds for imported and authored trees. Lightning emits its actual
ground contact. Celestial motion publishes one meteor trajectory to both the
sky shader and Bigfoot, so his target cannot diverge from the visible streak.

Tree contact currently covers stable upright trunks whose bounds fit his reach.
He does not climb trees. Overlooks are selected from safe navigation nodes
10–12.5 meters from the chunk center along either horizontal axis.

## Verification

Run with Godot from the project root:

```
Godot --headless --path . --script tests/test_bigfoot_environment.gd
Godot --path . --script tests/test_diorama_environment.gd
Godot --path . --script tools/film_bigfoot_environment.gd
```

The first test checks real actor palm contact, safe approaches, weather events,
tracking, cooldown ownership, pause and interruption. The rendered diorama test
checks native tree bounds, deletion, physical-play ownership, actual lightning
signals, overlooks and pause. The last command writes `poses.png` beside this
file for visual inspection.

Existing actor, hand reach, routine actor, tremor, motion controls, navigation,
main-world physical play, lightning and rainbow regressions also pass (11 targeted
test scripts total). A six-second motion preview is saved locally as
`preview.mp4`; captures follow the repository’s existing Git ignore policy.
Use `-- --film` with the capture script to write 30 fps PNGs under
`/private/tmp/bigfoot-environment-frames` for encoding.
