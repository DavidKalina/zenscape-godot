# Weather scheduler

`scripts/weather_scheduler.gd` (`class_name WeatherScheduler extends RefCounted`) decides how the
sky's weather drifts over world time. It is pure data: no nodes, no globals, no engine time. Feed it
an **absolute world hour** (`clock.day * 24 + clock.hour`) and it returns the preset names that
became current, which the scene applies with `precipitation.set_weather(WeatherScheduler.preset_index(name))`.

Everything is driven by one seeded `RandomNumberGenerator`, whose `state` is part of `capture()`, so
a save resumes the exact same future.

- Module: `scripts/weather_scheduler.gd`
- Tests: `tests/test_weather_scheduler.gd` (pure, headless)
  `Godot --path . --headless --script res://tests/test_weather_scheduler.gd`
- Eyeball tool: `tools/simulate_weather.gd`
  `Godot --path . --headless --script res://tools/simulate_weather.gd -- <seed> <season> <days>`

## Presets

The preset list is a mirror of `studies/precipitation.gd`'s `PRESET_NAMES`; a test asserts the two
stay identical by loading that script and comparing the constants.

| index | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| name | clear | rain | storm | snow | fair | overcast | mist | autumn |

## Transition table (season 0)

Weights for the next preset given the current one. A preset never transitions to itself. Weights are
relative within a row: they are multiplied by the season and hour factors below, then normalised.

| from \ to | clear | fair | overcast | rain | storm | mist | snow† | autumn† |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| clear    | –    | 0.55 | 0.30 | –    | –    | 0.15 | –    | –    |
| fair     | 0.40 | –    | 0.40 | 0.20 | –    | –    | –    | 0.30 |
| overcast | 0.15 | 0.30 | –    | 0.40 | –    | 0.15 | 0.35 | 0.35 |
| rain     | –    | 0.20 | 0.45 | –    | 0.25 | 0.10 | 0.20 | –    |
| storm    | –    | 0.10 | 0.40 | 0.50 | –    | –    | –    | –    |
| mist     | 0.40 | 0.30 | 0.30 | –    | –    | –    | 0.15 | –    |
| snow     | 0.20 | 0.15 | 0.50 | –    | –    | 0.15 | –    | –    |
| autumn   | 0.10 | 0.25 | 0.40 | 0.25 | –    | –    | –    | –    |

† `snow` and `autumn` are gated by season (see below) and are **zero at season 0**, so a neutral
season never rolls them. The shape of the rest is the intended arc:
`clear ⇄ fair ⇄ overcast → rain → storm → overcast`, with `mist` as a short interlude.

## Dwell times (world hours)

Rolled uniformly in `[min, max]` from the seeded RNG when a preset becomes current.

| preset | min | max |
| --- | --- | --- |
| clear | 5 | 12 |
| fair | 6 | 18 |
| overcast | 4 | 10 |
| rain | 2 | 6 |
| storm | 1 | 3 |
| mist | 1 | 3 |
| snow | 3 | 8 |
| autumn | 6 | 14 |

## Time-of-day effects

Multipliers applied to the candidate's weight, using the hour of day at the moment the transition is
due (`fposmod(next_change_hour, 24)`):

| target | condition | factor |
| --- | --- | --- |
| storm | 13:00–19:00 (afternoon) | ×2.5 |
| storm | 22:00–06:00 (night) | ×0.4 |
| mist | 04:00–08:00 (dawn) coming from `rain` or `storm` | ×5.0 |
| mist | 04:00–08:00 (dawn) otherwise | ×1.5 |
| mist | 10:00–16:00 (midday) | ×0.2 |
| clear | 17:00–22:00 (evening clearing) | ×1.8 |

Everything else is ×1.0.

## Season hooks

`season` is a 0..1 walk through the year the world clock keeps (four quarters:
spring, summer, autumn, winter — see docs/world-clock/README.md). **Season 0
reproduces the neutral table exactly** — every factor below is 1.0 at season 0,
and the four quarter bumps (`QUARTER_SPRING`/`SUMMER`/`AUTUMN`/`WINTER`,
`[centre, half width, strength]`, centred on 0.125/0.375/0.625/0.875 with a half
width of 0.125) are zero at every season boundary, so the year also wraps
without a step.

| target | factor |
| --- | --- |
| snow | `3.0 * clamp((season - 0.7) / 0.15, 0, 1)`, floored at ×1.5 when the current preset was reached straight from `snow` (snow never follows itself, so this is what "still wintry" means; a manual snow pick at season 0 can therefore flurry back once) |
| autumn | `2.2 * clamp((season - 0.45) / 0.15, 0, 1) * (1 - 0.75 * clamp((season - 0.8) / 0.15, 0, 1))` — arrives with autumn, thins once deep winter is in |
| overcast | `1.0 + 1.5 * clamp((season - 0.6) / 0.4, 0, 1)` |
| clear, fair | `1.0 + 0.55 * summer - 0.45 * clamp((season - 0.5) / 0.25, 0, 1)` |
| rain | `1.0 + 0.8 * spring + 0.2 * summer + 0.9 * autumn - 0.5 * winter` |
| storm | `1.0 + 3.0 * summer - 0.7 * winter` (storms only follow rain, and summer is dry, so its thunder has to be worth a lot when the rain does come) |
| mist | `1.0 + 0.9 * spring + 0.4 * autumn` |

### The mix, quarter by quarter

Share of world hours spent in each preset, measured over 4 seeds × 60 days with
the season pinned at the middle of each quarter (`tests/test_season_scene.gd`
prints these numbers and asserts the shape of them):

| quarter | the sky |
| --- | --- |
| **spring** (0.00–0.25) | fair 35%, overcast 28%, clear 17%, **rain 15%**, mist 3%, storm 2% — the showery, misty quarter |
| **summer** (0.25–0.50) | **fair 45%, clear 24%** (the brightest quarter), overcast 19%, rain 8%, storm 2% — dry, but the rain it gets thunders twice as readily |
| **autumn** (0.50–0.75) | fair 27%, overcast 26%, **autumn 20%**, rain 12%, clear 11%, storm 2%, mist 2% — gold and grey, and wet |
| **winter** (0.75–1.00) | **overcast 40%, snow 19%**, autumn 14%, fair 14%, clear 8%, rain 3%, storm ~0% — grey and cold, and it snows rather than rains |

`studies/fidelity.gd` feeds `season` from `world_clock.season` every frame, so a
garden left running walks that whole table on its own. Season is not captured:
it is pushed in from the clock, whose own `season_override` and `year_days` are
the things a save carries.

The scheduler also owns the two curves that say how much gold and how much cold
the **ground** wears for a given season, `season_autumn(season)` and
`season_cold(season)`. They are smooth bumps on the year (autumn centred on
0.675, cold on 0.875) that fall to zero before it wraps, and the scene adds them
on top of the current preset's own values. The transition table above decides
which sky is rolled; these two decide how the ground underneath it looks. The
*rate* curve ecology reads — the pond, and dead wood after it — is a third
thing, and lives on the clock: `WorldClock.season_factor`.

## Determinism and catch-up

- `advance(world_hour_abs)` is idempotent: called twice with the same hour, the second call returns
  `[]`. Hours that move backwards are ignored.
- A monotonic sequence of hours from a given restored state always yields the same transitions.
- A big jump (fast-forward, a long pause, a loaded save) catches up transition by transition, capped
  at `MAX_CATCH_UP = 24` per call. When the cap is hit, the schedule is re-anchored to
  `world_hour_abs + dwell(current)` so the scheduler cannot fall permanently behind.
- While `enabled` is false, `advance()` fires nothing but keeps `next_change_hour` ahead of the
  clock (re-rolling a dwell whenever it falls behind), so enabling drift after days off starts a
  fresh drift from now instead of bursting through every change it missed.
- `history` keeps the last 32 entries, `{"hour": float, "from": String, "to": String}`; player
  overrides via `set_current()` are recorded too.

## Wiring (as shipped in `studies/fidelity.gd`)

The scene owns `weather_scheduler: WeatherScheduler` next to `world_clock`, seeded with
`randi()` at startup. `enabled` is **false by default** in the scheduler itself, so a garden's
sky stays where the player put it until they tick "Let the weather drift" in the scene-look
editor (next to "Let the day cycle"). Anything that wants drift — the scene once the box is
ticked, `tools/simulate_weather.gd`, a test — asks for it.

Each frame, `_advance_weather_drift()` runs right after `world_clock.advance()`:

1. If the precipitation preset differs from `scheduler.current`, the player picked something
   (dropdown, mood, look editor, `--weather=` flag all end in `set_weather`), so the scheduler
   is re-anchored with `set_current`. No picker needs to know the scheduler exists.
2. `advance(day * 24 + hour)` unconditionally (a paused clock does not move, and a disabled
   scheduler only slides its schedule forward) and apply each fired preset with `set_weather`
   (clearing the cloud/cold overrides so a mood's pinned sky doesn't fight the drift).

`NativeGardenStore` saves `capture()` under `"weather_scheduler"`, rejects a non-dictionary
entry, and restores it after the clock. Gardens saved before drift existed load unchanged.
`tests/test_weather_drift.gd` covers all of this against the real scene.

## Climate mode (the product diorama)

The product scene does not use the table above. `scripts/living_weather.gd` calls
`set_climate(shares, dwell)` with the generator's `WET_WEATHER` or `DRY_WEATHER` odds and its own
dwell times, and `_pick` then draws any preset but the current one by a solved weight. The chain is
reversible and visits preset *i* in proportion to *w_i (1 − w_i)*, so the time share is
*w_i (1 − w_i) · mean dwell_i*. `climate_weights` solves for the weights once, by bisection, so
that the share matches the odds. Season and hour factors are not applied in climate mode.

Living weather feeds the scheduler its own hours (`now_hour()` plus real seconds / 20) instead of
the world clock, because generated worlds hold their hour of day. `force_next` draws the next sky
immediately (the W key). `capture()` is version 2: it adds `origin` and `origin_mood`, the weather
and air the world was generated with, and `restore()` only reads `enabled` from version 2 saves,
since older saves stored the default rather than a choice.

`season_plants(season)` is the plants' side of the year, published as the `zs_season` shader
global: spring bloom, deciduous leaf fall and winter dormancy, plateaus shaped like the gold and
cold curves and zero at season 0. See docs/scenic/PLAN.md, Phase 2 item 6.

`tools/probe_living_weather.gd` prints shares, dwell times and a timeline for climate mode.

## Sample timeline

`tools/simulate_weather.gd -- 4242 0.0 7`:

```
day 1  06:04  mist       day 3  10:06  overcast   day 6  03:14  rain
day 1  07:41  clear      day 3  14:43  fair       day 6  07:18  storm
day 1  13:32  fair       day 3  22:53  overcast   day 6  10:12  overcast
day 2  02:39  overcast   day 4  08:47  rain       day 6  19:53  rain
day 2  09:35  clear      day 4  12:26  fair       day 6  22:07  fair
day 2  16:07  fair       day 5  02:56  clear      day 7  15:23  clear
day 3  00:04  overcast   day 5  13:08  fair       day 7  21:33  fair
day 3  05:18  rain
```

Hours per preset over that week: fair 77.6, overcast 36.4, clear 34.8, rain 12.7, mist 3.6, storm 2.9.
