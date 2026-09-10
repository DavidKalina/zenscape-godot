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

`season` is a 0..1 knob reserved for a later calendar. **Season 0 reproduces the neutral table
exactly** — every factor below is 1.0 at season 0.

| target | factor |
| --- | --- |
| snow | `3.0 * clamp((season - 0.6) / 0.25, 0, 1)`, floored at ×1.5 while the current preset is `snow` |
| autumn | `2.0 * clamp((season - 0.55) / 0.25, 0, 1)` |
| overcast | `1.0 + 1.5 * clamp((season - 0.6) / 0.4, 0, 1)` |
| clear, fair | `1.0 - 0.5 * clamp((season - 0.3) / 0.7, 0, 1)` |

So season > 0.6 favours autumn/overcast/snow, and season < 0.3 leaves clear/fair at full strength
(they are only damped as the season climbs). Season is not captured from the clock yet; the
orchestrator can leave it at 0 until a calendar exists.

## Determinism and catch-up

- `advance(world_hour_abs)` is idempotent: called twice with the same hour, the second call returns
  `[]`. Hours that move backwards are ignored.
- A monotonic sequence of hours from a given restored state always yields the same transitions.
- A big jump (fast-forward, a long pause, a loaded save) catches up transition by transition, capped
  at `MAX_CATCH_UP = 24` per call. When the cap is hit, the schedule is re-anchored to
  `world_hour_abs + dwell(current)` so the scheduler cannot fall permanently behind.
- `history` keeps the last 32 entries, `{"hour": float, "from": String, "to": String}`; player
  overrides via `set_current()` are recorded too.

## Wiring (as shipped in `studies/fidelity.gd`)

The scene owns `weather_scheduler: WeatherScheduler` next to `world_clock`, seeded with
`randi()` at startup and **disabled by default**, so a garden's sky stays where the player put
it until they tick "Let the weather drift" in the scene-look editor (next to "Let the day
cycle").

Each frame, `_advance_weather_drift()` runs right after `world_clock.advance()`:

1. If the precipitation preset differs from `scheduler.current`, the player picked something
   (dropdown, mood, look editor, `--weather=` flag all end in `set_weather`), so the scheduler
   is re-anchored with `set_current`. No picker needs to know the scheduler exists.
2. If the scene is paused or drift is disabled, stop there.
3. Otherwise `advance(day * 24 + hour)` and apply each fired preset with `set_weather`
   (clearing the cloud/cold overrides so a mood's pinned sky doesn't fight the drift).

`NativeGardenStore` saves `capture()` under `"weather_scheduler"`, rejects a non-dictionary
entry, and restores it after the clock. Gardens saved before drift existed load unchanged.
`tests/test_weather_drift.gd` covers all of this against the real scene.

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
