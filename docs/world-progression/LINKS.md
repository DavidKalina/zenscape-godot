# World links: making the ingredients multiply

Started 2026-09-10 off `main` at the merge of `feature/world-progression-2`
(PR #14), with fire already on `main` since PR #5.

The first arc (`PLAN.md`) gave the world a calendar and a set of renewable
ingredients: fish, weather, dead wood, seasons, winter and the long sleep,
beside the fire, the cave, the mountains and the trees that were already here.
Almost all of them run in parallel. The manifest (`MANIFEST.md`) has thirteen
rows and only a handful of cross-links: season feeds the fish and the branches,
weather wears the bed, and fire reads wetness and snow. Everything else keeps
to itself.

This arc adds no new ingredient. Its goal is depth by multiplication: every
slice makes two things that already exist read each other, so the number of
situations the scorer can produce grows without anyone authoring a situation.
Fire is the biggest ingredient not yet in the ecology and gets the first slices.

The rules from the first arc still hold (ship the world change with its
scoring terms; every slice updates the manifest), with one more:

- **A link is a context key or a lifecycle edge, or it is not a link.** "Fire
  and dead wood" means branches change a fuel number and a burning cell removes
  a branch. Prose in a README is not a link.

## What we have

| Ingredient | Where | Reads | Writes |
| --- | --- | --- | --- |
| Clock, day/night | `scripts/world_clock.gd` | nothing | hour, daylight, season |
| Weather | `scripts/weather_scheduler.gd`, `studies/precipitation.gd`, `studies/surface_weather.gd` | season | preset, rain, wind, lightning, ground wet, snow cover, ice, cold, autumn gold |
| Fish | `scripts/fidelity_fish.gd` | clock, wet, season | `fish_available` |
| Dead wood | `scripts/dead_wood.gd` | clock, weather, wind, season | `branches_nearby` |
| Bed, stash, home | `scripts/bigfoot_lair_room.gd`, `bigfoot_living_world.gd` | storms (bed wear) | `comfort`, `food_count`, `material_needed` |
| Winter drive | `scripts/bigfoot_life_mind.gd` | cold, stash, bed | `torpor`, `winter_ready` |
| Fire | `scripts/fire_field.gd`, `fire_look.gd`, `fire_effects.gd`, `bigfoot_fire.gd` | wind, ground wet, snow, rain, standing water, lightning, explosives | burning cells, ash, snags, regrowth, `zs_fire`; Bigfoot flee, watch, warm hands |
| Curiosity, favourite places | `bigfoot_life_mind.gd` | world changes | `curiosity_target`, `ritual_target`, familiarity |
| Play stones | `bigfoot_lair_room.gd` | nothing | `can_play` |
| Trees | habitat interests | wind (shake), fire (snag) | drop sites for dead wood |
| Pond, waterfall | surface map, `surface_weather.ice` | cold | standing water (stops fire), fishing spots |

## The links, ranked by what they multiply

Each row is one edge. The multiplier column says which existing situations the
edge combines.

| # | Edge | Multiplies | Cost |
| --- | --- | --- | --- |
| 1 | Ice closes the pond: `fish_available` is 0 while `surface_weather.ice` is high | winter × fish × stash × torpor: the autumn stockpile becomes a real deadline | small |
| 2 | Branches are fuel: a branch raises its cell's fuel, a burning cell consumes it; snags shed a burst of branches when they fall | fire × dead wood × wind × gather: a burnt stand is a windfall, then a bare one | small |
| 3 | Dryness: fire spread reads a `dryness` scalar from days-since-rain and season (autumn burns hotter, DESIGN.md's deferred one-liner) | fire × weather × season | small |
| 4 | Fire reaches the mind: `fire_nearby`, `ash_nearby`, `home_burnt` context keys; watch, warm-hands and investigate-the-ash become scorer terms, flee alone stays a reflex | fire × curiosity × ritual × home: the priority ladder in `bigfoot_fire.gd` becomes inputs, as the identity notes ask | medium |
| 5 | Storm shelter tuned against `tests/test_storm_week.gd` (red today: inside for 46% of storm hours on seed 2) | weather × sleep × bed, and the criterion slice 2 promised | small |
| 6 | A burnt favourite place: familiarity of a ritual spot drops when its cells burn; the ritual reason says so; regrowth restores it | fire × memory × ritual: the first thing he can visibly lose | small |
| 7 | Lightning fells: a strike on a snag drops it and its branches; a strike near home is a `disturbance` | storm × fire aftermath × dead wood × home check | small |
| 8 | A branch is also a toy: with the bed full, a branch can be carried to the cairn as a play placement, so `can_play` reopens on windy days | dead wood × play × enrichment: a second meaning for the same object | small |
| 9 | Night fire: `zs_fire` lifts local light and `daylight` for the mind while a fire burns near him at night, so fear and curiosity at night differ from day | fire × night × mind | small |
| 10 | The legends log: every completed action's reason, every weather change, first snow, first frost, a fire's start and end, bedding in and waking, written with day and season, surfaced in the thoughts panel and saved | everything × time: this is the scoring system the identity notes describe | medium |

## Slices

### Slice A: winter bites and fire eats (edges 1, 2, 3)

Ice closes the pond, branches burn and snags shed, and dryness makes autumn
the fire season. All three are number changes inside lifecycles that already
exist. Watch: a dry autumn storm's lightning starts a fire that runs through
the leaf-fall branches; a week later the pond is iced and he eats from the
stash he built in autumn.

Success: in a simulated year the fish action fires zero times while the pond is
iced and the stash carries him through; a fire started over branches burns
hotter (more cells per second) than the same fire over bare ground; the same
strike in spring after rain fizzles.

### Slice B: shelter and the log's first pages (edges 5, 10 foundation)

Tune the shelter term until the storm-week criterion holds for every sampled
seed, and add the event log with the events that already exist as reason
strings. No UI yet beyond the thoughts panel and the save document. Watch: the
panel reads "Day 12, autumn: took shelter from the storm; Day 13: fixed the bed".

Success: `test_storm_week.gd` passes on all seeds; a simulated year produces a
log whose entries are in day order and survive a save.

### Slice C: fire reaches the mind (edges 4, 6, 9)

Fire's context keys, the burnt favourite place, and night fire. Flee stays a
reflex because a reflex is what it is; everything after the flee goes through
`ranked()`. Watch: he flees, watches from upwind, and the next day walks to
the ash of his quiet spot and stands there, reason "The quiet spot is gone".

Success: with fire keys present the mind chooses watch and warm-hands without
`bigfoot_fire.gd` forcing them; a burnt ritual spot ranks lower than an unburnt
one until regrowth; a scene without a fire field ranks exactly as before.

### Slice D: second meanings (edges 7, 8)

Lightning fells snags and disturbs the home; branches double as play pieces.
Watch: the morning after a storm he clears a fallen snag's branches, one to the
bed, one to the cairn.

Success: a snag struck by lightning leaves branches at its site; with a full
bed and a branch in reach `play` becomes available and completes.

### Slice E: the legends log, surfaced

The log from slice B gets its reading surface: a scrollable page per world
day, the notable entries marked (first snow, a fire, bedding in, waking), and
a filter by ingredient. This is where "scoring" lives in a terrarium: the
world's story, not a grade.

Success: a year's log renders, scrolls to any day, and every entry links to
the context key that produced it.

## Cadence

A and B run in parallel off `main` (A touches fish, dead wood and fire; B
touches the mind's shelter term and adds the log). C starts after A lands
because both touch fire and the mind. D after C. E after B and C, since it
reads the log and fire's events.

The second inhabitant stays where `PLAN.md` left it: after this arc, when the
world has enough edges that a rival for the larder means something.
