# Head lift handoff (prototype)

Branch `iter/head-lift`, off `iter/giant-city`. Not merged.

## Play it

```
cd /Users/davidkalina/Documents/Projects/zenscape-head-lift
python3 tools/play.py --no-pull -- --no-title --head-lift-start --no-clouds --pilot-file=/tmp/head_lift_pilot.json
```

The plane starts on the far side, 1750 m out on the bore's line, level at the
bore's height, meter full. He's at the site. Hold Boost, fly straight, press Z
(the roll) about a second out from the glowing plate, and steer a touch up at the
end. Drop `--no-clouds` to see it with the sky as it is: clouds sat on him at this
height in the captures, and the plate was hard to see through them.

## What was built

- `scripts/endless/head_lift.gd`: the head, the state machine, the solid, the
  plate, `--head-lift-start`.
- `scripts/endless/stomper_lift_pose.gd`: procedural pose (SkeletonModifier3D after
  the legs): back bent and turned, two-bone IK on the arms. No clip was authored.
- `art/blender/giant_ruins/lift_head.py`: mourner_55 with a capped neck and a straight
  14 m bore (`TOY_WAY` 7) from stump to socket. Writes `lift_head.glb` and
  `lift_head.json` (the boxes the flight meets, read from the same field).
- `stomper.gd`: stops for the lift, `crouch`, `stands_for_lift`. `flight_contact.gd`:
  a touch in the open bore glances. `finds_table.gd`: find `lift-head` (a relic).
  `finds.gd`: `unfind`. `endless_flight.gd`: key U, the debug start.

Beat: the plane within 1500 m of the head starts it. Stoop 5 s, grasp 1.5 s, raise
and turn 7 s, hold, lower 6 s, let go 1.5 s, stand 4 s. The hold lasts 40 s at most,
or ends 4 s after the plane is through (8 s at least). If the plane is still within
1100 m he lifts again; past that he walks on. Each lift restores the plate and the
find (and the meter on `--head-lift-start`). The find is therefore not a one-time
find yet.

He's put at the site when the plane comes near (`_arrive`): unseen inside 2300 m if
it can be done, seen or not inside 1500 m. There's no walking there. He then stands
at a fixed cycle point (both feet down), so the head is always in reach.

## Site

2320 m along the loop (world about 47894, 1518), the straight on the west end of the
plain, heading east. The ground within 1.2 km either side rises about 10 m, the
flattest clear stretch on the loop. `LINE` is unchanged. The run-in comes from the
north across his front, left to right, so the way out is open ground and both his
arms stay behind the head. An earlier hold, off to his left with the line angled
toward him, put the exit into his right forearm 75 m past the socket.
Map: `scratch/head_lift_route_map.png` (red loop, cyan dot his stance, magenta the
held head, cyan line the run-in and exit).

## Numbers

- Head middle 140 m over his ground, 115 m ahead of his feet. The plate's bore mouth
  is about 118 m up (world y 93), about his hip to chest in this stooped stance.
- Bore climbs 5 degrees. Driven line: level on Boost at 57 m/s, nose up a little
  over the last 120 m, Z at 50 m from the plate's front (surge 74 m/s). The bore
  takes the plane under 1 s. A surge lasts 2.5 s, so early Z has room.
- Without Boost the plane cruises at 37 m/s and arrives about 40 s after the
  trigger, near the end of the hold.

## Debug

- `--head-lift-start`: above. It sets the meter full at the start and on each lift.
- `--full-meter`: the meter full at the start only, for arriving the normal way.
- U: he's put at the site and lifts now.
- `--head-lift=0`: no lift. It only exists on the doors world, not `--world=amberlands`.

## Proof

Throwaway drivers, real stick and the Z key, headless, 0 script errors:
`scratch/lift2.gd --mode=through|shut|shell|again`, `scratch/lift3.gd`.

- Through: plate broke with the head moving at 1.35 m/s, no crash, find taken, flew
  on 320 m past the socket.
- Shut plate without the surge: crash. Surge into the skull beside the plate: crash,
  plate whole.
- Again: he lifts on his own, plate and find back, U works, walks on once left.
- The game's way in (`--city-start`, plane carried near): he's put at the site once,
  lifts, walks on.

Smoke passed with and without `--head-lift-start`. Captures in `scratch/shots/`:
`fly_sheet.png`, `lift_sheet.png`, `runin.png`.

## Rough

- The pose is greybox. It doesn't meet the animation bar: the mesh folds at the
  waist, the hands don't close, the stance is the walk's long stride, nothing
  anticipates or settles. A bent stone body will want an authored clip.
- Him popping to the site in view when the plane comes in where it can see him.
- The head's stone is a flat material, with no maps. The break uses the surge's own
  dust and chips; the plate just vanishes.
- Solid: the hold's boxes are 3 m steps, and only hold the hold's pose. Off the hold
  the head is a round lump. So the plate can only be broken in the hold.
- Wing rays on the moving head use the same boxes.

## Unverified

- A person flying it; every pass was on the driver's steering. How hard the line is
  by hand, and whether the hold is long enough, are the open questions.
- Sound of the break, and frame cost of the 310-box solid (no perf pass).
- Arriving by hand through the hall.

## Model budget (lift_head.glb, 23k triangles)

- Sculpt high, bake low: applies. Baking to 10k would save about 13k triangles, under
  0.1 ms; not done for a prototype.
- Import LODs: applies, not done. Saves most of the 23k at range; the head is one
  mesh, so under 0.1 ms.
- Silhouette, rigid parts, parallax, vertex grime: don't apply yet (no look pass).

## Tests and tools

Grepping `tests/` for the stomper, finds table and FlightContact found nothing the
change would break. The full suite wasn't run. The harness has no plot tool for a
top-down map without Pillow on this Mac, so the map came from a throwaway
plain-Python PNG writer. `site_map.py` wasn't tried on this land.
