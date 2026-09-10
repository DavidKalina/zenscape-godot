# World progression: the plan

Started 2026-09-10 off `main` at the merge of `feature/world-progression`.

ZenScape is a terrarium, not a survival game. The goal of this arc is that the
world pushes back on Bigfoot and renews itself, so his utility scorer
(`scripts/bigfoot_life_mind.gd`, `ranked()`) always has something to choose
between. Today most actions close on themselves: the bed fills to stage three
and never degrades, the cairn has three placements, the fish run out and
nothing replaces them, and the weather changes nothing about his day.

Two rules across every slice:

- **Ship the world change and the scoring terms together.** A system may lead
  its consumer by one slice (the weather scheduler did), never two.
- **Every slice adds a row to the chunk manifest** (`MANIFEST.md`, created by
  slice 0): the ingredient, its lifecycle, the context keys it exposes to the
  mind, and the actions that read them.

Each slice lists a watchable scene, the visible change it leaves, the scoring
effect, and a success criterion a test can assert.

## Slice 0: scrub tooling and the season scalar

Add to the scene-look editor (`scripts/scene_look_editor.gd`, the Air section):
a Season slider, a day setter, and a force-weather picker. `WorldClock` gains a
`season` value (0..1) derived from `day` with a `YEAR_DAYS` constant, and an
optional override the slider sets. `WeatherScheduler.season` and the surface
cold/autumn targets (`studies/surface_weather.gd` via `studies/precipitation.gd`)
follow it. No new ecology, only knobs, but every later slice reads season from
day one.

Success: a pure test shows season cycling with the day count and the override
winning; a scene test shows the scheduler and surface targets follow the slider.

## Slice 1: the fish come back

`scripts/fidelity_fish.gd` restocks the pool toward a cap over world time,
faster overnight and after rain. Fish already carries the twilight bonus in
`ranked()`, so the scoring change is small. Watch: he fishes at dawn, comes back
a few days later and fishes again.

Success: over a simulated week the fish action keeps firing and the stash never
sits empty for more than one world day.

## Slice 2: the weather reaches him

Rain and storms count as a disturbance to the bed while he is out, and a storm
gives him a reason to head home: a shelter term on sleep or a small new action.
The decision context gains a weather name and a wetness value. Watch: the sky
darkens, he turns for the cave, and the next morning he fixes the bed.

Success: gather fires again after every storm in a simulated week, and he is
inside for most storm hours.

## Slice 3: dead wood

Wind and storms drop branches under trees. They lie there as visible traces,
rot after some days, and become the gather source in place of the current
fallen-material shortcut in `_material_targets()`. The context gains a
nearby-branch count. Watch: a windy night, branches on the ground in the
morning, he clears them one at a time.

Success: the branch count rises and falls over a week instead of sitting at zero.

## Slice 4: seasons proper

Year length and the weather table follow season, autumn and cold visuals track
it, and fish and branch rates take a seasonal factor. Seasons earn their
visuals here because three consumers exist.

Shipped: `year_days` is a saved knob on the clock; the transition table gives
each quarter its own mix (spring showers and mist, a bright thundery summer, a
gold and wet autumn, a grey snowy winter); `WorldClock.season_factor(season,
shape)` is the one seasonal rate curve, used by the pond
(`SEASON_RATE = [1.0, 1.0, 0.6, 0.25]`) and waiting for dead wood; and the
context carries `season`, `season_name`, `cold` and `harvest`, with the cold
nudging `sleep` and the gold nudging `gather`.

Success: the four quarters produce measurably different weather and ground, the
pond keeps restocking in winter at a quarter of the summer rate, and a scene
with no clock ranks exactly as it did before the calendar existed.

## Slice 5: winter and a long-horizon drive

A hibernation need that fills over the cold season, a stockpile that matters
before it, and a torpor with occasional outings so the stage is not empty.
This is where a second inhabitant is decided, not before.

## Cadence

Slices 0, 1 and 2 run in parallel off `main` on their own branches. Slice 3
starts after 2 lands because both touch gather. Then 4, then 5.
