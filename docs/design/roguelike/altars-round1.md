# Altars round 1: where items are found (feature `altars`)

Code: `scripts/roguelike/item_pickup.gd` (reusable item-in-the-world),
`scripts/roguelike/altars.gd` (the layer's laying and the rules).

## What it is
- **Pedestals** (1-2 a layer): a weathered-basalt plinth (city kit stone) with
  the item floating over it, a dim warm lamp, a faint column of light, and its
  name and line when near. Laid on the collectibles' risky spots (rare,
  rune_risk, perch, cover, arena; never the start isle). Walk in to take:
  `run.give_item(ItemCatalog.draw(...))`, drawn at stand time.
- **Cursed altar** (from layer 2): offers a rarity 2+ (or cursed) item for one
  heart. Press Jump beside it. It goes through the run loop's harm path
  (cause "altar", flash, corner), so it counts as a hit. Decision: it
  **refuses your last heart** ("will not take your last"); `--altar-lethal=on`
  lets it kill.
- **Key and vault**: the Vault Key (catalog id `vault_key`, kind "key", never
  drawn) lies in a risky spot on layer 1 (until found, up to layer 3). Carried,
  a brass key bobs over his head. **A counted hit makes it fall** from his hand
  and tumble where he stood; take it up again after 1.2 s, but if it goes over
  an edge, or the layer's gate takes him with it lying, it is lost and a fresh
  one is laid on the next layer. The vault (from layer 2, till opened) is a
  locked stone reliquary: Jump beside it with the key, the door sinks, a
  rarity 2+ item is yours (key spent). Death loses the key like any item.

## Play
```sh
/Users/davidkalina/Applications/Godot.app/Contents/MacOS/Godot --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=11
```
`-- --altars=all` lays all four on layer 1 (to see them); `--no-altars` off;
`--altar-lethal=on`.

## Hooks in shared files (`# [altars]`)
`layer_stage.gd` (one dress line), `run_loop.gd` (altar harm always counts;
cause word), `item_catalog.gd` (`vault_key` entry; `draw` skips kind "key").

## Proof
Smoke clean (900 frames). Scratch driver through real input (walk, Jump,
`motor.harm`): pedestal walk-in, key take, hurt drops key, key retaken, vault
unlock, altar bargain all pass.

## Rough
- The catalog has one item (wallrun), and `draw` skips carried ones, so with
  today's catalog a second pedestal/altar finds nothing and is dropped; it
  fills out as items are added. The relic is a generic faceted stand-in.
- Spots need level ground 1.2 m round; some are dropped (backup spots are
  tried). Placement is by the collectibles' spots, so a pedestal can sit by a
  rare.
- Key/vault state is per run in a static (`Altars._s`); the vault is lit even
  with no key (prompt says the key lies on the way up).
- No sound yet. No dedicated drop-key warning beyond the caption.
- Tests it may break: none known (not run; full suite not run).
