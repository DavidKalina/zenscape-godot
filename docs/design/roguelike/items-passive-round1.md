# Passive items, round 1 (feature `items_passive`)

Six catalog entries (`scripts/roguelike/item_catalog.gd`), effects read live by
`RunState.holds(id)` / `run.carrying(id)`. Code: `scripts/roguelike/passive_items.gd`
(a node on the study, added by run_loop), `passive_noise.gd` (noise multiplier).
Hooks marked `# [items_passive]` in run_state, run_loop, wanderer_noise, item_catalog.

| id | name | kind | effect |
|---|---|---|---|
| `heart_vessel` | Heart Vessel | once | +1 max heart, 2 mended (`RunState.add_vessel`, `max_hearts()`; the overlay row follows) |
| `lantern` | Hand Lantern | passive | warm OmniLight3D at his side, flickering, plus a SightLight (r 9, 0.5) |
| `waystone` | Way-stone | passive | faint warm arrow over his head leaning at the gate (3D, so it also says "up"); fades out within ~14 m of the gate |
| `quiet_soles` | Quiet Soles | passive | his noises x0.45 (a slam x0.75) |
| `rune_magnet` | Lodestone | passive | runes (live pickups and the greed ring) within 5 m drift to him, faster when near |
| `tithe_bell` | Tithe Bell | cursed | every rune counts double (purse and haul); all noise x1.3 and a 7 m bell noise every 1.1 s while he moves |

Light interaction: the lantern is a SightLight, so `LightLevel.exposure` reads him
brighter (the Olmec sees him at range, a LightDrinker drinks it like a torch). It
helps you see and costs you stealth. Not an `exposure`-blind item.

## Play
```sh
/Users/davidkalina/Applications/Godot.app/Contents/MacOS/Godot --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=11 --give=heart_vessel,lantern,waystone,quiet_soles,rune_magnet,tithe_bell
```
Knobs: `--quiet=0.45`, `--lantern=1.0` (light scale), `--magnet=5.0` (m), `--no-items_passive`.
Items also come through altars/merchants via `ItemCatalog.draw`.

## Proven
Smoke clean (900 frames, all six given). Drive check through the run loop: max hearts 5, noise mul
0.45 / 1.3, magnet took a rune from 3.5 m away (none without), bell doubled it. Rendered still:
5 hearts, strip names, lantern ball and arrow visible.

## Rough
- Lantern sits beside the existing hand torch; looks are stand-in (sphere, no cage). Its extra light on
  the underground is modest while the torch look is on.
- Arrow is a plain cone; no icons. Bell has no sound. Vessel does not persist (items are lost with the run).
- Max hearts is 4 + vessels; other agents reading `RunState.HEARTS` as max should use `max_hearts()`.
- Tests that may break: none found; any test asserting the hearts row max uses `RunState.HEARTS` (unchanged constant).
