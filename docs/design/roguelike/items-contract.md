# Items and the game-feel round: the shared contract (2026-10-15)

The user wants the run to feel like a game: loot you're scared to lose,
things that hunt you, a summit you can taste. Twelve agents build pieces
of it in parallel off this contract. Read it before touching items.

## Items

- **Catalog**: `scripts/roguelike/item_catalog.gd` `ITEMS`. Add your item's
  entry there first (`name`, `line`, `kind` verb/passive/cursed, `price` in
  runes, `rarity` 1..3, `once`). Ids stay stable.
- **Carrying**: `RunState.items` (`scripts/roguelike/run_state.gd`).
  `run.give_item(id)` takes one (emits `item_taken`; the run loop shows its
  caption and the strip), `run.drop_item(id)`, `run.carrying(id)`.
  Anywhere without a path to the run: `RunState.holds(id)` (static, reads
  `RunState.current`, the latest begun run). A new run starts with none;
  death loses them all (the card lists them: "lost with him: ...").
- **Effects read live**: whatever an item changes asks `holds(id)` where it
  acts, every tick or every use, so an item taken mid-layer works at once.
  Example: Gecko Wraps (`&"wallrun"`) — `run_loop.gd` `_item_moves` sets
  `motor.wallrun_on` from it each tick (`--wallrun` still gives it outright).
- **Drawing one**: `ItemCatalog.draw(rng, pool, run)` picks by rarity,
  skipping kept items already carried.
- **The strip**: `scripts/roguelike/item_strip.gd`, a stand-in row of names.

## Features: on by default

`scripts/roguelike/run_features.gd`: `RunFeatures.on(&"merchant")` where a
feature lays or starts itself. `--loot=off` turns every feature of this
round off, `--no-<name>` one. `RunFeatures.value("linger","serpent")` reads
a `--linger=` style knob. Feature names: `items_move`, `items_passive`,
`merchant`, `altars`, `weeper`, `beetle`, `flyer`, `inhabitant`,
`linger`, `summit`, `juice`.

Cut features (run-trim-round1.md) stay in the code, off unless asked:
`RunFeatures.opted(&"flyer")` is true only with `--flyer`, and the
Sun-Keepers come back with `--sun-keepers`.

## Shared files: touch lightly

`run_loop.gd`, `run_state.gd`, `run_overlay.gd`, `layer_stage.gd`,
`layer_enemies.gd`, `pilot_motor.gd` and `item_catalog.gd` are touched by
many agents at once. Put your work in your own new files; add only small,
marked hooks (`# [merchant]`) in the shared ones, so the merges are easy.

## Play it

```sh
/Users/davidkalina/Applications/Godot.app/Contents/MacOS/Godot --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=11
```
- `--give=wallrun,lantern`: the run begins carrying those (play and test knob).

- The linger serpent is cut from the run (2026-10-15): `--linger=serpent` brings it back; `--linger=colossus` lays the colossus. No linger threat by default.
