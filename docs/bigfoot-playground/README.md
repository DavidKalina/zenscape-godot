# Bigfoot interaction playground

Launch `run-bigfoot-playground.command`. This opens a separate little woodland clearing with the Blender classic Bigfoot. It does not load, overwrite or add creatures to a saved garden, and it does not replace the original rare encounter.

Drag Bigfoot to pick him up by the head. His scalp stays at the carrying pivot while his arms flail at different rhythms and his feet kick unevenly. Pointer movement adds a small head-pivoted sway. Click him, or press **Call him**, to get his attention. **Pick up** carries him from the controls; the next world click sets him down. Right drag orbits and the wheel zooms. **Esc** returns a carried creature to the last safe spot. **Reset** or **R** returns him to the clearing.

A green ground marker indicates a clear landing; red means an obstacle or steep patch. Releasing outside the chunk or over the controls returns him to his last safe spot. Landing plays once when he reaches the ground, then returns to idle. He occasionally glances toward a tree or the camera. Walking to trees, gripping trees, autonomous roaming, garden persistence and multiple creatures are not part of this first playground.

## Asset and behavior boundary

- Blender source: `art/blender/bigfoot/zenscape-bigfoot-interactions.blend`.
- Deliberate export: `assets/models/zenscape-bigfoot-interactions.glb`.
- Authoring script: `tools/animate_bigfoot_interactions.py`; preserves the original classic source and refuses to overwrite subsequent authored work without its explicit generated-output option.
- Clips: Idle (4s), Held (3s), Land (0.7s), Alert (1.2s), existing Walk (3.6s). Idle/Held loop. Held keeps the head and torso fixed while limbs flail. The original Walk's 93 animation channels are preserved exactly.
- `CreatureActor` handles safe carry/drop state, clip playback, head-pivoted sway and additive gaze. The playground handles pointer projection, terrain and obstacle checks, camera and controls. Another creature can supply its own clips and grip height; it does not need to reuse Bigfoot's mesh.

## Validation

`animation-validation.json` records export bone count, bounds, loop seams and preservation of Walk. `test_creature_actor.gd` checks transition timing, invalid drops, pickup during landing, finite bone poses, scalp anchoring, asymmetric limb motion, head stability and seam continuity. `test_bigfoot_playground.gd` checks picking, terrain boundaries and resetting while held. The existing walk test is also run against the new export.

Final GPU regression: **83/83 tests passed**, without retries or timeouts; see `test-results.json`. Existing six-instance ObjectDB shutdown warnings remain in scene tests/capture. `head-grab.mp4` is a five-second in-game reel through idle, head-held flailing and landing; `head-grab.png` shows one held pose. The live user review prompted the change from overhead-hand suspension to a fixed scalp grip.
