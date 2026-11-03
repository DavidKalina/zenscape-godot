# Wake fish: handoff

Prototype round, for the user to play. Skim water low and fast and fish burst
out to either side of the line. `--wake-fish=0` turns all of it off.

## Fly it

`.\run-endless-flight.cmd --at=87,250 --heading=180 --alt=3` starts on the
south shore of the lake nearest the start, 1.1 km across, about 40 m of water
to the ground. Hold Boost and let the plane settle onto the water. Other lakes
on seed 1: (2334,-2014) 2.8 km, (1344,-4857) 1.7 km, (-6841,3527) 1.7 km,
(4796,-3688) 1.5 km. A pond: (2609,1048). The tarn: (-3533,-623), level 821 m.

## What it is

- `scripts/endless/wake_fish.gd`, a child of EndlessFish. Shaders
  `shaders/wake_fish.gdshader` and `shaders/wake_splash.gdshader`.
- What seed 1 calls lakes are the sea's level standing inside the land:
  `WaterContact.kind` says SEA, and they have no record like a pond's. A spot
  counts as a lake when it is under the sea's level and at least `LAKE_IN`
  (300 m) inside the world's edge line, so a bay counts too and the ring of open
  sea doesn't. Ponds, the tarn and rivers come through `river_y` for free.
- `WaterContact.stir()` is the trigger: closeness over the 2 spans `clear` is
  read for (5.6 m), by the same speed share as the spray. `REACH` alone is 2.8 m,
  too low to ask of a hand-flown line.
- A leap is written once and runs on the GPU from its start time: arc, body along
  it, arch, tail beat, roll, the rings, drops and puffs. Two rings of MultiMesh
  slots (34 fish a kind, 200 splashes), the buffer set only on a frame that lays
  one. CPU each frame: the trigger and the plop queue.
- Most fish (`AHEAD_SHARE`, 70%) break AHEAD of the plane, not behind it as first
  asked. The camera is about 10 m behind the plane, so a fish behind it goes
  unseen. The other 30% are the trail behind, for a turn back over the water.
- Lakes get an idle leap too, ahead of a plane under 90 m over one. Pond idle
  leaps are untouched.

## Knobs (top of wake_fish.gd)

`SPACING` how many, `STIR_POW` how much lower pays, `LONG`, `PEAK`, `RUN` size of
leap, `AHEAD_SHARE`, `LEAD`, `SCATTER` where. In the shader, `sheen`, `glint`,
`rim` the flash.

## Open

- Fish are 0.85 to 1.35 m long, about half the plane's span, to read at speed.
- Ponds give only a handful: one pass is under a second. The lakes are the trail.
- No sound was heard: the plops ran headless. Levels are a guess, for the ear.
