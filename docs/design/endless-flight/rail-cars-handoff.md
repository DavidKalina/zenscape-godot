# Train cars: handoff (lane `rail-cars`, 2026-11-10)

On `lane/rail-cars` (off `iter/railroad` / the steam train). Prototype round:
no committed tests; drivers in `scratch/` (uncommitted).

## Openings and how they are flown

Each hole in `RailTrain._parts` has a `way`, sized at cruise (36.75) against
the 32 m/s train:

| car | opening | way |
|---|---|---|
| doors, stock, gate | doorway 10 x 6 | slide (angled from alongside at the train's pace) |
| gate (new) | the same doorway; doors slide shut 1.2 s, shut 1 s, open 1.2 s, open 3.2 s (`gate_open`, the train clock); each leaf a moving solid | slide, while open |
| logs (22 m now) | gap 12.2 m (7 m toy opening + 5.2 m drift over the car's width), open above | square across |
| truss | middle panel 10 x 6 | slide |
| crane + idler | under the boom, 18 m long, 6 m high | square |
| coach + coach | the gap, 10 x 6 | slide |
| the run (new): thru, culvert, thru | one corridor 5.2 x 7 m, 70 m long | along, from behind (cruise: 13 s inside; Boost: 3 s) |
| smash | the same corridor, plates | along on a surge |

Corridors (`CORRIDOR`: thru, culvert, smash) glance instead of crashing
(`way_off`) and draw the camera tight.

Consist: engine, tender, box, logs, gate, stock, open, flat, thru, culvert,
thru, flat, truss, crane, flat, doors, logs, flat, flat, smash, flat, coach,
coach, van (548.8 m, same as before).

## Colliders and models in step

`rail_train.gd _parts` is the source. `art/blender/train/train_parts.gd`
writes `train_parts.json` from it; `train_build.py` runs that first, takes
the doorway, log gap, corridor and culvert sizes from it, and its `prove()`
checks every hole clear and every model vertex within 0.15 m of the solid.
The engine's boxes (`ENGINE`) are still hand-kept to its model; the proof
covers them.

## See it

- Yard: `python3 tools/play.py --no-pull studies/train_yard.tscn -- --no-title --line=24`
- Train: `python3 tools/play.py --no-pull -- --no-title --pilot-file=/tmp/rail.json --rail-start=beside`
- Rebuild: `python3 tools/blender.py run art/blender/train/train_build.py`, then `python3 tools/godot.py --import`

## Open

- The engine's drivers are still red (the user's call).
- The culvert car and the run read as boxes from outside; the inside is the point.
- The gate's far look (past 150 m) shows its doors open always.
- `ride_land.gd` stop check fails only because a 75 s ride meets no stop.
