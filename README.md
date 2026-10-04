# ZenScape

A cozy landscape toy in Godot. You shape a small square plate of land with
your hand, and life arrives on what you make in its own time: grass, flowers,
trees, fish, frogs, birds and deer.

## Play

Double-click **`run-cozy-flow.command`**, or open `project.godot` in
**Godot 4.7.2** (standard edition; no .NET needed) and press **F5**. Both open
`studies/cozy_worlds.tscn`.

The title is a generated world the camera orbits behind a fan of cards
([title cards](docs/design/title-cards/README.md)): **Continue**, **Your
worlds** (every kept world as its card, the world behind turning to the one
you point at), **A new world**, **Almanac** (settings) and **Rest** (quit).
`--classic-title` brings back the old card, with **Build this world** and
**Begin on a quiet plain**, and the library strip with rename, duplicate
and delete. In a world, **Esc**
opens the pause panel: Resume, Save a copy, Field notes, Settings and
Return to title. Worlds keep themselves a few seconds after each change.

**[How to play](docs/HOW-TO-PLAY.md)** lists every control. In short:

- **The hand.** There are no tool modes. The **left button is the hand**, and
  what a press does depends on where you press: the land, the plate's rim and
  walls, or the sky. The **right button is the eye**: drag to look round,
  scroll or pinch to zoom.
- **The tool roll** on the left edge holds the shaping tools, one per
  landform gesture: the **Modeller** (fine work: thumb a stream bed, pinch a
  knoll, palm a pan), **Hills** (scrub), **Mountain** (pull up a peak, or
  sideways for a range), **Crater** (pull down),
  **Island** (draw an isle in a lake, or spread land out to the water), **Ravine** (draw a line; a
  loop sinks a basin), **Chisel** (mesa, shelf, notch, slice) and **Paddle**
  (plane and pat). The strip along the top holds the tools that tend: the
  **Feather** (wind), the **Watering can** and the **Brush** (colour).
- **The materials case** along the bottom holds tree seeds, flowers, reeds,
  water and a river stone. Take one and press or paint the land.
- **The edge and the sky.** Push the rim to turn the world and wind time on;
  pull it down and let go to spring the land up; flick it to flip to a new
  world. Hold still in the sky to call the cloud; swipe the sky for a gust.
- **First steps.** A new player gets a small card that walks through six
  things in turn; **Field notes** on the pause panel lists everything the hand
  can do ([first steps](docs/scenic/first-steps.md)).
- **Keys.** **M** moods, **P** photo mode, **O** watch mode
  ([watch](docs/scenic/watch.md)), **Esc** put down / pause, **R**
  overview, **F** glide to what's under the pointer, arrows to pan,
  **Cmd+Z** / **Shift+Cmd+Z** undo and redo, **Cmd+S** save now.

Launch flags go after the launcher, for example
`./run-cozy-flow.command --resume`: `--no-title` opens a new plain,
`--watch` opens it in watch mode,
`--resume` the last saved place, `--generated` or `--seed N` a generated
world. HOW-TO-PLAY lists the rest.

For a standalone Windows or Mac app, see
[desktop builds](docs/desktop-builds.md).

## Design notes

- [The creation plan](docs/scenic/PLAN.md) and the hand scheme,
  [modeless](docs/scenic/modeless.md); the other notes in `docs/scenic/`
  cover water, life, sound, wind, the cloud and the look.
- [The shaping tools](docs/design/tools/PLAN.md), the
  [worlds and library](docs/design/worlds/README.md), the
  [tool roll and materials case](docs/design/materials-tray/HUD-4c.md) and
  the [almanac and HUD](docs/design/hud-5/README.md).
- [Deprecated and retired](docs/DEPRECATED.md): what the game no longer
  needs, and what has been removed.

## Older study scenes

The game's scene inherits a chain of older scripts:
`cozy_worlds.gd` → `diorama.gd` → `bigfoot_lair.gd` → `bigfoot_cave.gd` →
`fidelity_life.gd` → `fidelity.gd`. Their scenes (`studies/diorama.tscn`,
`fidelity.tscn`, `fidelity_life.tscn`, `bigfoot_lair.tscn` and
`bigfoot_cave.tscn`) are not part of the game, but many tests and tools load
them, and `run-diorama.command`, `run-fidelity.command`,
`run-fidelity-life.command`, `run-bigfoot-lair.command`,
`run-bigfoot-cave.command` and `run-godot-comparison.command` still open
them. The fidelity study, a port of the original Three.js scene, is the look
reference: see [comparison and remaining gaps](docs/fidelity/NOTES.md) and
the [parity checklist](docs/fidelity/PARITY.md).

## Structure

- `studies/cozy_worlds.gd`: the game's scene: title, worlds, the hand scheme.
- `scripts/title_cards.gd`, `scripts/menu_card.gd`, `scripts/world_card.gd`:
  the title as cards, one card, and what a world's card shows.
- `scripts/world_session.gd`, `scripts/world_library.gd`,
  `scripts/world_lands.gd`: which world is open, the saved worlds, and the
  lands a new world starts from.
- `scripts/land_clay.gd` with `scripts/clay_tools/`: the land as clay; one
  script per tool on the roll.
- `scripts/tool_roll.gd`, `scripts/materials_tray.gd`,
  `scripts/hand_materials.gd`: the tool roll, the materials case and the hand
  that takes from them.
- `scripts/native_chunk_editor.gd`: the editable chunk: terrain, water,
  objects, undo and saves.
- `scripts/land_life.gd`: life answering the land.
- `scripts/first_steps.gd`, `scripts/first_steps_card.gd`,
  `scripts/field_notes.gd`, `scripts/pause_panel.gd`: first steps, the field
  notes and the pause panel.
- `native/terrain_kernels/`: the optional native terrain kernels
  (`tools/build_native_kernels.py`); without a built kernel the GDScript
  versions run.

## Checks

```sh
godot --headless --editor --path . --import
godot --headless --path . --script tests/test_landscape.gd
godot --headless --path . --script tests/test_garden.gd
godot --headless --path . --script tests/test_world_clock.gd
```

The Python runners also default to headless, so automated checks do not open
windows or take focus. To run selected tests with retained logs and a JSON report:

```sh
python3 tools/check_bigfoot_living_regressions.py --tests test_world_clock.gd
```

Use `--godot /path/to/Godot` to override the executable. Repeat `--tests` to select
multiple scripts, or omit it to attempt all tests headless.

Headless uses Godot's dummy renderer. Some integration tests require GPU pixel
readback or MultiMesh transform storage and can fail or time out in this mode;
a headless run does not replace those visual checks. Both Python runners accept
`--rendered` for an explicitly requested Forward+ run, which opens windows and
may take focus. They never automatically fall back to graphical execution.

The original Three.js ZenScape project remains a separate reference for
landscape recipes, atmosphere, water and wildlife. This project has no runtime
dependency on it.
