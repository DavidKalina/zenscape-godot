# The Broken Ring (motif isle handoff)

Branch `look/motif-broken-ring`, from main 3a0aef65. Not merged, not pushed.

"Size in number, not mass": a central isle (r 13.5) with a stone circle
(`RuinKit.stone_circle`, sarsens 5 and 6 missing) round a broken turret, and
round it a loose spiral of eight small isles (r 6-7.6), about 64 m across,
climbing 21 m (tops 30 to 51 m in its frame) with a 55 degree break in the ring.
Card: "The Broken Ring" / "A circle, taken apart a stone at a time".

## Run

```sh
./run-broken-ring.command            # standalone
godot --path . res://studies/aqueduct_isle.tscn -- --no-title --fly   # in the sky, far west
```

Also in the scene picker (Ruins, `broken_ring`).

## Layout

Each satellite carries one note: arch (lowest, a gateway on the way), pier
pair, fallen pier, lancet wall, tomb chest, buttress, wall, rose gable (highest).

The foot spiral, lowest to highest: rope bridge, 4 floating stones, rope bridge,
jump (about 2.4 m rim to rim), 4 floating stones, rope bridge, jump. The
central isle hangs off the fourth by a rope bridge. The plane's slalom: tokens
in the gaps, under three bridges, through the break, over the circle, under the
central keel. Six foot tokens (turret head, summit, bridge, stones, jump).

Files: `scripts/kit_isle/motif_broken_ring.gd`, `studies/broken_ring_isle{,_art,_life,_sky}.gd`
(+ .tscn), `run-broken-ring.command`, `tests/test_broken_ring_isle.gd`.

## Placement

`motif_sky.gd`: offset (-660, 6, -70), middle (-580, -80), reach 38. 322 m from
the Sundered gorge (centre to centre), 455 m from the colonnade, 668 m from the
aqueduct isle; far from the towers and the lodestone line. Its isles' tops stand
at 36-57 m in the sky.

## Tests (headless)

| Test | Result |
|---|---|
| import | clean |
| test_broken_ring_isle | PASS (191k tris; every hop driven; gaps measured) |
| test_motif_sky | PASS |
| test_aqueduct_isle_sky | PASS |
| test_kit_clouds | PASS |
| test_isle_lock | PASS |

Edits to shared tests (merge by hand with the other motif branches):
- `test_aqueduct_isle_sky.gd`: `broken_ring` appended to the source and id lists;
  the "a few hundred metres off" bound raised from 500 to 700 m.
- `test_kit_clouds.gd`: motif count `== 4` is now `>= 4`.
- `test_motif_sky.gd`: a motif answering `landing_run() == false` is not landed on
  by the plane; the pilot is set down on its highest isle instead. The broken
  ring answers false (its isles are too small for a 20 m run).

## Open issues / unverified

- One rendered capture only (standalone, wide view): it reads as intended. The
  look in the aqueduct sky, the worker build path and rendered frame cost are
  not verified. Build is about 1 s on the main thread headless.
- The turret token is not proven reachable by the tests (same turret as the bell
  spires' needle); 5 of 6 foot tokens are taken by the climb.
- The plane cannot land on any isle here (too small).
- Jump gaps depend on the outline's rim (0.92-1.05 r); the test measures them.
