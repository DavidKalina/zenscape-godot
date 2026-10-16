# Airship ferry, round 2

The ask: take the rune serpent out of the main scene and have the ferry
shuttle round a few of the islands instead.

## What changed

- **No serpent in the game's sky.** `studies/aqueduct_isle_sky.gd` builds
  the serpent only where there are no motif isles (the other kit isle
  studies), or with `--serpent`. Its ledges and its route go with it.
  `rune_serpent.gd`, `serpent_route.gd` and `serpent_rider.gd` are
  untouched. `--serpent` brings back the route and ledges, and
  `--serpent --serpent-old-route` brings back the long way, with no ferry.
- **The ferry's loop** (`scripts/kit_isle/airship_ferry.gd` ROUTE) now has
  five stops. It is about 1960 m long and takes about 7.8 minutes a lap
  (467 s). CRUISE, EASE and HOLD are as in round 1, so the ride feels the
  same. Each leg takes 1 to 1.7 minutes.
- **The tail fin** lies on the ferry's foredeck. It sits by the cabin's
  front on the port side (PartSpots `FIN_DECK`, `on_ferry`) and is carried
  with the ship. A start aboard stands you about 1.5 m from it, so a step
  forward takes it. Without the ferry and with `--serpent`, it rides the
  serpent's back as before (`PlaneArc.kind`). `--part-at=fin` starts you
  aboard at home, beside the fin.
- **The watcher** (`--watcher`) watches the fin on the ferry. His sight ray
  skips the ferry's own body. When he loses it, he waits facing the
  ferry's way 220 m before home. His line is now "Something's glinting on
  the ferry's deck."
- **The tarn's airship** (`ROUTES[1]`) flies 22 to 26 m higher, at 84 to
  92 m, because the ferry now crosses its loop going in and out of the
  tarn. At the crossings the ferry's envelope top is about 25 m under the
  other ship's gondola. The colonnade airship and the salvager's loop are
  unchanged, and the nearest of them is 56 m off.

## The stops

Every stop was found with rays on the stood isles. The deck is level with
the turf, and the hull's side is 0.3 to 0.6 m off the edge by the
foredeck.

| stop | where | heading, isle side | deck |
|---|---|---|---|
| home | aqueduct isle, south edge by the start | west, starboard | 29.97 (turf 30.0) |
| gorge | Sundered gorge, east half's east edge | south, starboard | 37.30 (turf 37.6) |
| nave | drowned nave, west edge | south, port | 31.08 (turf 31.07) |
| tarn | cloister tarn, east edge just south of the falls | north, port | 31.28 (rim 31.1 to 31.4) |
| bell | bell spires, west lobe (round 1's stop) | south, port | 41.77 (turf 41.82) |

The gorge's deck is a step (0.3 m) under the turf on purpose. That rim is
bevelled, so with the deck level a walk aboard went down the bevel and
into the gap.

Leaving each new stop, the route veers out from the edge. Going straight
on, the hull met the rim's jags.

## How to start at each

```
--ferry-aboard               aboard at home, 4 s before it leaves
--ferry-aboard=<stop>        aboard, 25 s before it rests at <stop>
--ferry-at=<stop>            on foot by <stop>, the ferry 20 s off
--part-at=fin --plane-arc    aboard at home beside the fin (--plane-arc only for script runs)
```

`<stop>` is home, gorge, nave, tarn or bell. The motif ids work too:
sundered_gorge, drowned_nave, cloister_tarn and bell_spires. The stop's
isle is stood up at once. `ARRIVE_LEAD` replaces round 1's `BELL_LEAD`.

## Proof (headless, throwaway, in scratch/)

- Smoke: `studies/zenscape.tscn` passes 400 frames with 0 errors. It also
  passes with `--serpent`, `--watcher`, `--ferry-at=tarn`,
  `--ferry-aboard=drowned_nave`, `--part-at=fin` and a bogus stop, which
  only warns.
- Loop check: all five stops are level and a hand off the edge. Hull,
  cabin and envelope were tested against every isle every 0.5 s round the
  lap, with 0 touches. Both other ships were swept round their own loops
  with 0 touches.
- A full lap aboard through the real loop (`--ferry-aboard`): the ship
  rests at gorge, nave, tarn, bell and home in turn. He is on the deck at
  every stop and never off it riding, with at most 0.035 m of drift. At
  gorge, nave and tarn he walks off onto the turf with the stick and back
  aboard while it rests. The fin rides the whole lap and is taken with a
  walk forward at the end.
- `--ferry-aboard=<each stop>` puts him on the deck. `--ferry-at=<each
  stop>` puts him on the turf, the ferry comes in, and he walks aboard.
- The watcher tracks the fin within 0 to 2 degrees while watching. He
  loses it behind the hill on the way west and picks it up again at the
  gorge.
- Rendered stills of the ferry resting at the tarn, gorge and nave:
  `captures/shots/ferry_{tarn,gorge,nave}.png` (not committed). The deck
  reads level with the turf, beside the edge.

## Tests this breaks (not fixed; reconcile at lock-in)

- `test_airship_ferry.gd`: uses `BELL_LEAD`, expects only home and bell
  and a lap under 240 s, and steps `sky.serpent`.
- `test_plane_arc.gd`, `test_watcher.gd`: step `sky.serpent` (null now),
  and expect the fin on the serpent.
- `test_rune_serpent.gd`, `test_serpent_route.gd`, `test_serpent_hops.gd`,
  `test_kit_audio.gd`: expect the serpent in the aqueduct isle's sky by
  default. They need `--serpent`.

`test_collision_audit.gd` fails the same way before and after this
change, on the dragon roost's DragonTower. That failure is not from this
round.

## Unverified and rough

- The stills have white cloud shards close to the camera. That is the
  cloud tearing near the lens and is not from this round, but it hides
  part of the view.
- At home, the watcher stands a few metres from where the ferry docks, so
  the fin passes him close and his spyglass swings fast.
- A lap is about 7.8 minutes, so a missed ferry is a long wait. CRUISE
  or HOLD would shorten it.
- Hops on and off weren't driven, only walks.
- The model budget doesn't apply: no model changed.
