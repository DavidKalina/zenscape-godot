# Handoff: storm-dragon

The loop (spec: `spec-storm-dragon.md`; trail: `git log
--grep='^ITER(storm-dragon)'`) on `sky-game-loop-and-world`, with two
lanes merged in (`lane/dragon-sightings`, `lane/dragon-hide`).

## Where to play it

`./run-sky-weather.command` (the sky weather study, heavy on). Take off and
fly into the first storm cell (it comes 20 to 45 s in). `--storm=1` for a
full storm from the start (cells then only on C). The readout lists every
key; the study's header (`studies/sky_weather_field.gd`) every flag.

| Key | |
|---|---|
| C | a storm cell toward the plane |
| M | a whiteout now |
| K / Shift+K | the dragon far / close now |
| H | the dragon's old hide / the new one |
| T, Shift+T | the storm front; the sky's own storm |
| G, F12, R | a gust; lightning; back to the start |

Flags to stage things: `--sighting-stage=away|over|under|toward`,
`--strobe=on`, `--hide=old`, `--cell-first=`, `--cell-speed=`,
`--cloud-drift=`, `--whiteout-at=`, `--sighting-at=`.

## What's built

- **Isles:** seven far isles round the plane field, 0.5 to 2 km out; five
  landable (`scripts/sky_isles.gd`). Bare turf, no flora (load time).
- **Moving weather:** the sky's towers and puffs drift on its wind
  (`scripts/sky_drift.gd`); storm cells, a dark tower with a rain shaft and
  their own lightning, wander over the isles, darkening the land under
  them, every 1 to 2 minutes (`scripts/storm_cells.gd`).
- **Whiteouts:** 4 to 15 s of dark slate murk round the plane in a cell's
  or front's core, rain and spray driven at the camera
  (`scripts/storm_whiteout.gd`, `shaders/storm_whiteout.gdshader`,
  `shaders/plane_rain.gdshader`). Storms grade the whole frame darker.
- **The dragon in the lightning** (`scripts/dragon_sightings.gd`,
  `scripts/dragon_glimpse.gd`): heard first (muffled by distance), then
  seen only while a flash lights it, the flash behind it so it stands
  near-black against the bloom. Staged along the plane's line (away, over,
  under; far ones away or toward), never broadside. Close ones turn the
  head: away cocks it back over the shoulder, over looks down, jaw open,
  claws reaching. In the murk it looms as a soft dark shade
  (`shaders/dragon_loom.gdshader`). Each sighting emits `sighted` (place,
  nearness, stage, time) for a later strike round.
- **The hide:** scaled, mostly matte near-black purple with sparse wet
  glints, a veined maroon membrane (`shaders/dragon_hide.gdshader`,
  `shaders/dragon_membrane.gdshader`); the old one on H. The flying dragon
  in the aqueduct isle wears it with `--dragon-hide=new`
  (`./run-rim-dragon.command --dragon-hide=new --no-dragon-roost`); off by
  default there.

## Tried and set aside

- **The strobe** (`--strobe=on`): the light as 3 to 5 short pulses on the
  head turn's beats. The user found it read as the dragon glitching in and
  out. Their idea for another try: the dragon always faintly there in the
  murk, each pulse lighting it harder, never vanishing.

## Open

- The murk silhouette's edges are crisper than the mood board's.
- In clear storm air the wings read dark red, not black.
- The new hide is tuned for storm light; by day it reads near-black.
- Close scales a little honeycomb; they swim slightly with the pose.
- Far and "under" stills not shot with the latest look; thunder and growl
  timing checked in logs, not by ear.
- `scratch/strobe_check.gd`'s "nearer" test can fail from a ~63 m start.
- No committed tests (prototype); the suite was not run.
