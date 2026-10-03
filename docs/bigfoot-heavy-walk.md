# Heavy walk with loose arms

The selected Bigfoot walk replaces only the personality profile's Walk clip.
His existing model, coat, face, idle, and other action performances remain in use.

Editable source: `art/blender/bigfoot/zenscape-bigfoot-heavy-walk.blend`.
Runtime animation source: `assets/models/zenscape-bigfoot-heavy-walk.glb`,
action `HeavyWalk`. The exported model supplies animation tracks only; its
geometry is not installed on the gameplay character.

The source opens with frames 1–180 at 60 fps, a three-second, four-step loop.
It is an in-place performance calibrated to 0.85 m/s. In Blender, translation
along world -Y at that speed keeps stance feet planted. The accepted pose has
deeper weight absorption, longer strides, and hanging arms with roughly
3–10 degrees of elbow bend. No appearance experiment is included.

`bigfoot_personality.gd` remaps the animation onto the resident's existing rig
and supplies its ground-speed and contact-count metadata. `CreatureActor`
uses those values to match cadence to actual requested travel, emit all four
contacts, and retain foot phase/travel speed when switching personality profiles.
Legacy Walk and LogCarry retain their existing calibration and two contacts.
Turning retains its prior step frequency. This change does not redesign turning,
acceleration, or stopping.

## Validation

Headless Godot checks passed:

- `tests/test_bigfoot_heavy_walk.gd`: 1x authored-speed playback; all contacts
  across wraps for both profiles and carrying; 1.33 mm planted-foot drift
  through the actual movement controller.
- `tests/test_bigfoot_personality.gd`: retargeting, preserved idle, original
  profile switching, and held interruption.
- `tests/test_creature_walk.gd`: movement, navigation waypoints, terrain projection,
  safe positions, pickup, and wind interruption.
- `tests/test_rage_walk.gd` (removed): rage doubles travel and cadence, cooling restores both.
- `tests/test_bigfoot_motion_controls.gd` (removed): idle/stroll controls and live profile switching.

Headless runs emitted the environment's macOS certificate warning; scene-based
tests also emitted shutdown resource-leak warnings after reporting zero failures.
