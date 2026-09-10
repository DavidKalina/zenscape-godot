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

Shipped, Bigfoot only: the mind gains `torpor`, the first need kept on world
hours rather than watched seconds. `mind.drift(cold, world_hours)` chases the
season's cold with an 18-hour rise and a 48-hour fall, so over a 28-day year it
crosses the `TORPOR_THRESHOLD = 0.50` two days into winter, peaks at ~0.82 just
after deep winter, and is gone by the end of spring. It lifts a new `hibernate`
action (the cave's existing long visit, which already had a name and a rest pose)
and lowers `investigate`, `play`, `ritual` and `gather` by degrees first, so the
watcher sees him grow slow — including a surface walking pace that falls from
0.65 to 0.45 — before he beds in. The stockpile is `winter_ready`: four stashed
meals weighted 0.6 against a finished bed weighted 0.4, whose shortfall
(`larder`) adds up to +0.45 to `fish` and +0.30 to `gather` from the first gold
leaf of autumn. Because the same shortfall subtracts up to 1.00 from `hibernate`,
an empty stash in deep winter sends him out to fish instead of under: nothing
starves here. The completion cooldown on `hibernate` *is* the waking outing, 28
seconds thawing down to 10 in the deep cold, so the stage is never empty for
long. A second inhabitant was not added; see below.

## Second inhabitant

Deliberately not built in slice 5 — this note is what it would take, for the
user to decide on.

`bigfoot_life_mind.gd` is already the right shape to be shared: it is a pure
`RefCounted` with no node references, and every world fact reaches it through
one `Dictionary` in `ranked()`. What is Bigfoot-specific about it is not the
class, it is three things: the constant `ACTIONS` list, the fixed coefficients
inside `ranked()`, and the fixed need-fill rates in `advance()`. A camper or a
bear reusing it would need those three lifted into a **drive profile**: a small
data object (weights per action term, need-fill rates, thresholds, and which
actions the creature may consider at all) that `_init` takes and `ranked()`
multiplies through. Bigfoot's profile would be exactly today's numbers, so his
behaviour is bit-for-bit unchanged and every existing test still holds — that is
the migration's success criterion.

The living world needs more than the mind does. `bigfoot_living_world.gd`
currently owns one creature, one lair, one cave and one routine by direct
reference (`scene.creature`, `scene.lair`, `routine.cave`), and the save document
is a single `bigfoot_living` blob. A second inhabitant means: an instance per
resident with its own remembered home, its own `_failed_until` and its own saved
state under a key; the shared ingredients (the pond, the dead wood, the branches)
becoming reservations rather than first-come grabs, since two residents walking
to the same fish is the first bug this arc would produce; and a rule for what
happens when they meet, which is a new action on both minds (avoid, watch,
follow) and the first thing in this world that is neither weather nor supply.

The cheapest honest first step, if the user wants one, is a bear that only
appears in autumn and only takes fish: it shares the mind class with a profile
that has three actions, needs no lair, no bed and no memory of home, and it gives
Bigfoot's `larder` term a rival — which is the point of a second inhabitant in a
terrarium, and the only reason to pay for one.

## Cadence

Slices 0, 1 and 2 run in parallel off `main` on their own branches. Slice 3
starts after 2 lands because both touch gather. Then 4, then 5.
