# Merchant round 1: the stall and the Collector

Feature `merchant` (items-contract.md). Code: `scripts/roguelike/merchant.gd`
(stall, wares, prompt), `merchant_collector.gd` (the hunter). Hooks marked
`# [merchant]` in `layer_stage.gd`, `run_state.gd` (`thief`), `run_loop.gd`
(cause word, `--runes=`).

## What it is
- On odd regions (layers 1, 3, ...; seed parity with no region) a still,
  masked trader under a worn cloth awning, wares on mats: up to 3 items drawn
  with `ItemCatalog.draw` (skips carried), plus a heart. Name and price float
  over each. Laid on a cover/perch spot of a route isle (not base or greed),
  else beside the spawn. Stood on the highest ground under it when he comes
  within 70 m.
- Stand at a ware: **E (pad B) buys** (purse `run.runes`, catalog `price`;
  heart is `HEART_PRICE` 6, refused at full hearts). **F (pad Y) takes it
  unpaid.**
- Taking sets `run.thief` for the rest of the run: the Collector (a floating
  stone mask hung with cloth, dim warm slits, a faint lamp) appears 6 s later
  at 48 m, drifts at him through anything at 0.5 x run speed rising to 0.88
  over 70 s, a touch costs a heart and it falls back 14 m, then returns. It
  re-comes 14 s into every later layer. Stalls on later layers are shut (a
  slab and a cloth, "shut"). Death card: "by the Collector".

## Play
```sh
/Users/davidkalina/Applications/Godot.app/Contents/MacOS/Godot --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=11 --merchant=start --runes=20
```
Knobs: `--merchant=start` (beside the spawn, 9 m), `--merchant=always`
(every layer, on an isle spot), `--no-merchant`, `--loot=off`,
`--runes=N` (purse starts with N extra), `--give=`.
Constants at the top of merchant.gd / merchant_collector.gd.

## Proof
`scratch/merchant_drive.gd` (not committed), real input actions: buy via
`cannon_leave`, refused when poor, steal via `cannon_climb`, thief flag,
Collector arrives, closes, hurts. 16/16. Rendered stills judged.

## Rough
- The catalog has one item today (Gecko Wraps), so stalls show 1 item + heart
  until other rounds add items. Ware shapes are by kind (bundle, brass disc,
  jar), no per-item art.
- The trader is a still figure (no animation, mask turns to a thief and the
  eyes brighten, nods on a sale). No audio.
- The Collector ignores terrain and gaps by design; no way to kill it, only
  to run and to leave the layer. Not yet scary in sound or tell.
- Stall footprint ~5 m wide; needs reasonably level ground (<=1.7 m steps),
  tries 8 spots round the chosen one, else the layer has none.
- E/F are the cannon's actions; stall prompt is plain text beside the chest's.
- Tests it may break: none known (not run; no full suite).
