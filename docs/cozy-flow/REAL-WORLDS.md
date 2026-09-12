# Growing a procedural cozy world

Run `run-cozy-flow.command` or F5. The latest window is **ZenScape · Gentle regrowth**.

Click **Regrow landscape**, or carry Bigfoot to a screen edge and hold for half a
second. The current place recedes with tremor over 3.4 seconds; rebuilding runs
across frames, then the new world grows over 5 seconds. Releasing early queues a safe landing. Keep holding
to choose where Bigfoot lands yourself. The transition adds no fog blanket;
each world's normal mist and weather remain intact.

## What changes

Regrowth now uses the native inland genome instead of cycling the eight curated
landscape presets. Its seed varies the composition, crest profile, peaks, valley
walls, shorelines, planting, relief and breadth. Woodland can also become redwood
forest. The current composition and terrain seed are excluded from the next draw.

A second part of the same seeded draw generates coordinated surface, sky and
lighting colors, hour, cloud cover, mist, haze, wind speed/direction, and season.
Weather includes clear, fair, overcast, mist, rain and snow. Dry regions keep dry
weather; snow supplies cold ground and partial ice; autumn shifts foliage toward
copper. These are bounded, correlated choices that preserve readable cozy worlds,
not arbitrary RGB noise. Colors and daylight blend during the reveal. Framing
adjusts to include the new terrain and tall trees. Weather animation keeps moving
while Bigfoot and the world clock are paused for formation.

Persistent moving fog banks and wisps are sampled with the climate and positioned
against the new relief. Fair and cloudy weather use coverage values that produce
visible puffs in the native cloud field. The sky march intersects both faces of
the cloud deck so it remains visible when the diorama camera is above it.

The generator is still built from a finite vocabulary of native landforms and
assets. It varies their continuous parameters and environmental combinations;
it does not create new meshes or landform algorithms with AI.

## Editing and saving

World → Landscapes remains available for deliberate choices. Build opens the
native sculpting/placement tools. Undo restores the complete previous world,
including its palette, atmosphere and finished growth; Redo restores the generated
world. Save and normal quit preserve the terrain recipe, colors and weather.
Earlier cozy saves remain readable; other saved places remain on disk while only
the active one is loaded, in `user://cozy-worlds/places.json`.

## Implementation

`scripts/cozy_world_generator.gd` samples the existing versioned inland genome
and generates a custom climate/color recipe. The existing look applicator resets
weather and season state, with every color and environmental setting supplied
by the draw. `scripts/cozy_regrowth.gd` wraps `form_inland()` in the reverse/forward
animation and replaces the editor's temporary bare-earth undo snapshot with the
complete pre-transition world.

Terrain movement in both directions uses `growth.gd` and `reference_tremor.gd`.
One full world is loaded. The native cooperative rebuild finishes before growth
resumes, so total transition time depends on the generated scene. Publication,
atmosphere setup, framing and navigation start on separate frames. Camera framing
uses the native 2 ms cooperative budget. Walkable-ground scanning uses two existing
worker-pool partitions, with budgeted main-thread validation before Bigfoot lands.
Palette/hour/framing blend on the forward pass; weather switches at bare earth.

The sky retains its moving cloud field and three-tap self-shadowing. It skips
detail work in provably empty parcels and uses 16 ray samples, with the original
26-sample ceiling available through the shader's `cloud_steps` parameter.

## Validation

`test_cozy_world_generator.gd` checks deterministic draws, valid saved recipes,
climate/palette diversity, and continuous relief across 100 seeds.
`test_cozy_worlds.gd` exercises actual carry input, queued landing, growth/tremor,
new colors and weather, complete Undo/Redo, and save/reopen.
`test_cozy_edge_input.gd` aliases that interaction check. Forward+ captures cover
meadow foothills, misty redwoods, a snowy woodland basin and desert monuments.
`test_cozy_atmosphere.gd` checks moving fog after regrowth and atmosphere restore.
`test_cloud_view_from_above.gd` requires a GPU window and compares rendered pixels
with and without clouds from above the deck.
It also compares the optimized cloud image with the 26-step reference.
`test_tree_degrowth.gd` renders all four tree types' trunks and crowns through
full, partial, zero and restored growth. Layered-tree materials opt into the
same foliage timeline as conifers, broadleaf trees and redwoods.

`tools/profile_cozy_regrowth.gd` records seeded forest/desert transition frames
and stage timings to `/private/tmp/cozy-<label>-<seed>.json`. Run with
`-- --label=capture --max-frame-ms=50` in headless mode for a main-thread stall
check; omit the limit in Forward+ to measure actual window frame intervals.

On the development M5 Pro, Forward+ at 3024×1898, the same two seeded transitions
reduced worst observed frame intervals from 87.9 to 45.6 ms (forest) and 72.2 to
46.8 ms (desert). These are short desktop captures, including GPU/display waiting,
not a 60 fps guarantee. The GPU timer returned zero/unavailable. See
`performance-regrowth.md` for the capture context and remaining costs.
