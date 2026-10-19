# Spec: storm-dragon

A build loop (skill `iterate`, slug `storm-dragon`) on the sky weather
study: `studies/sky_weather_field.tscn`, `./run-sky-weather.command`
(heavy on). It builds on what the study already has: the live sky's storm
(Shift+T), the storm front (T, `scripts/storm_front.gd`), gusts, jet
streams, rain flown through and lightning from the air
(`scripts/plane_lightning.gd`). Read `scripts/plane_weather.gd` first.

Prototype rules hold (AGENTS.md, Prototyping): smoke check plus throwaway
checks, no new committed tests, no full suite.

## What done looks like

Flying the study, the user sees and hears:

1. **Isles to fly over.** A handful of far isles (5 to 8) scattered round
   the plane field at a range of distances (a few hundred metres to a
   couple of km) and heights, so weather has something to pass over and
   the user has somewhere to fly to. Plain rolling kit land is enough
   (reuse the field's own land code or the kit isles'); no ruins needed.
   The field keeps its clear landing stretch, and each new isle big enough
   to land on keeps one too (AGENTS.md, Motifs).

2. **Weather that moves through the world.** The cloud drifts on the
   sky's wind, so towers and banks are seen to travel across the
   archipelago, their shadows and rain going with them. Storm cells,
   smaller and more often than the front, wander across the isles on the
   wind: a dark tower with a rain shaft hanging under it, its own
   lightning, its own rough air and rain when the plane is in or under it.
   One is seen coming from far off, passes over an isle (the isle darkens
   and is rained on) and goes on. They come on their own every few minutes
   upwind of the field; a key sends one now toward where the plane is. The
   front (T) and the sky storm (Shift+T) keep working.

3. **Whiteouts.** Inside a storm cell's thick core (and the front's), now
   and then a short stretch, roughly 4 to 15 s of flight, where the murk
   closes in until the user can see only tens of metres: the isles and the
   horizon gone, cloud racing past, rain thick, lightning lighting the murk
   from inside without showing where it came from. Then the plane bursts
   out into clearer storm air. Never long; they are moments. A key drops
   one on the plane's path now.

4. **The dragon in the lightning.** In a storm, the dragon is out there and
   is only seen in flashes:
   - It starts with a sound: a low far call or the thump of great wings
     under the rain and thunder, a second or few before anything is seen.
   - Then lightning, and in its light the dragon: **far** (a dark shape
     gliding between towers, hundreds of metres off, gone when the flash
     goes) or **close** (in a whiteout or a cell's core, a huge shape
     sliding past just off the wing or over the canopy, tens of metres
     away, a wing or the neck and head filling part of the view, then dark).
   - It is seen only while the flash lights it; between flashes it is not
     drawn, or is lost in the murk. A second flash a beat later may show it
     somewhere else, or gone.
   - Uses the existing dragon (the rim dragon model,
     `assets/models/rim_dragon_c.glb`, and the posing in
     `scripts/sky_dragon.gd`, reused or borrowed from) and the existing
     dragon sounds (`assets/audio/kit/dragon-*.wav`), muffled and spaced by
     distance.
   - No contact, no damage, no gameplay yet. But each sighting is one
     named event (a signal with the dragon's place, how near, and the time)
     that a later strike-and-react round can hang off.
   - It happens on its own in storms, more in whiteouts and cells' cores
     (rare enough to stay eerie: on the order of one sighting every minute
     or two in a full storm). Keys call a far sighting and a close one now.

5. **Tuned together.** One pass playing it all at once: how often cells,
   whiteouts and sightings come, so a few minutes' flight into weather
   gives a cell passing an isle, a whiteout and a sighting or two. The
   study's readout and header comment list every key.

## Order: the trunk and one lane

**Lane `dragon-sightings`** (part 4, the dragon in the lightning), on its
own branch `lane/dragon-sightings` in the worktree
`/Users/davidkalina/Documents/Projects/zenscape-dragon-lane`, run as its
own short loop (sound and the sighting signal, then the far flash, then
the close flash). Its commits are `ITER(storm-dragon): lane
dragon-sightings: <task>`. It keeps its code in its own new file(s)
(e.g. `scripts/dragon_sightings.gd`) and its edits to shared files
(`plane_weather.gd`, `plane_lightning.gd`, the study) small and additive,
and ends each commit with **Notes for merge**: the shared lines it
touched. It reads how stormy it is from what is already there (the
plane's storm, the cells' and front's `storm_at`) and gives the trunk one
small hook for whiteouts to raise the chance of a close sighting (e.g. a
`murk` value 0 to 1 the weather sets each frame); until whiteouts land, a
key or flag stands in. The trunk iterations do not build the dragon.

**The trunk** (this branch, `sky-game-loop-and-world`): isles, moving
cloud, cells (done), then whiteouts. Then the lane is merged (by the loop
runner, not an iteration) and whiteouts are wired to the lane's `murk`
hook. Then the tuning pass over everything. Each task ends in something
the user can launch or a still they can look at.

## Checks each iteration

- Smoke: `studies/sky_weather_field.tscn` (`tools/smoke.py`) must PASS.
- Rendered stills (`tools/shot.py`, `-- --no-title`) of what the task
  changed, looked at before committing. Stills of moments (a flash, a
  whiteout) need the task's debug key or a flag to stage them.
- Anything flown: a throwaway check through the real play loop
  (`tools/drive.py`), left in `scratch/`.

## Model and caps

Opus for every iteration. The skill's default cap and budget.
