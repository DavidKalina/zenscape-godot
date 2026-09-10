# The world clock

`scripts/world_clock.gd` (`class_name WorldClock extends RefCounted`) is the
world's single source of truth for time. It is pure data: no nodes, no RNG, no
wall-clock reads, no rendering. Give it the same captured state and the same
sequence of deltas and it lands on the same day, hour and phase every time.

There are no autoloads in this project. The scene owns the clock:

```gdscript
var world_clock: WorldClock   # studies/fidelity.gd
```

Reach it from anywhere with `scene.get("world_clock")` — the guard also keeps
scripts working in scenes that never build one.

## Contract

```gdscript
var day: int          # whole days elapsed, starts 0
var hour: float       # 0.0 ..< 24.0, fractional
var phase: float      # 0..1, the celestial rig's phase for this hour
var daylight: float   # 0..1, mirrors what celestial publishes as zs_daylight
var speed: float      # multiplier, 1.0 = default day length; 0 allowed
var running: bool     # false = time frozen (this is celestial's old `cycling`); true by default
var day_length: float # real seconds per world day at speed 1.0 (default 480.0)
var elapsed: float    # total world seconds, day * 86400 + hour * 3600
var season: float     # 0..1 position in the year, read-only (see below)
var season_override: float # >= 0 pins the season; -1.0 follows the calendar
var year_days: int    # world days in a year (default 28, clamped 1..100000)

func advance(delta: float, paused: bool) -> void
func set_time(day: int, hour: float) -> void
func skip_to(hour: float) -> void      # smooth-target, the old next_hour easing
func capture() -> Dictionary
func restore(value: Dictionary) -> void
```

Supporting helpers: `calendar_season()` (the season the day count alone says it
is, ignoring the override), `season_name()` and the static `name_for_season`
("spring"/"summer"/"autumn"/"winter"), the static `season_factor(season, shape)`
(the seasonal rate curve, below), `set_phase(phase)` (jump to the hour that renders as this
phase, keeping the day), `label()` ("Day 3 · 17:30"), `target_hour` (the pending
`skip_to` destination, `-1.0` when idle), the static `valid_state(value)` used by
the garden store, and the static mapping functions `phase_for_hour`,
`hour_for_phase`, `linger`, `elevation_for_phase`, `daylight_for_phase`.

Safety rules baked in: a delta that is negative, `NAN`/`INF` or larger than
`MAX_DELTA` (1 s) can never skip a day; `paused` freezes everything including a
pending skip; `day` is clamped to `MAX_DAY`; `restore` clamps every field and
falls back to defaults for a missing or broken document.

## Phase mapping and the sunrise linger

The old `celestial.advance` integrated `phase` directly and multiplied its rate
by a `linger` factor, so time itself slowed to half speed while the sun crossed
the horizon. A clock whose hands slow down is not a clock, so the linger moved
into the **hour → phase mapping** instead:

- `hour` always advances at a constant `24 / day_length * speed` hours per real
  second. A world day really is `day_length` real seconds long.
- `phase = phase_for_hour(hour)` warps that even time onto the celestial ring.
  The warp is the inverse of the cumulative integral of `1 / linger(phase)`,
  tabulated once per run (1024 samples, built from constants only, shared by
  every clock — still fully deterministic).

The result is identical on screen to the old behaviour: `dphase/dt` is still
proportional to `linger(phase)`, so sunrise and sunset still dwell. Two notes:

- Because the linger density is symmetric about phases 0.25 and 0.75, the
  quarter days are exact fixed points: hour 0/6/12/18 ↔ phase 0.0/0.25/0.5/0.75.
  Authored preset phases therefore still land on the hour they always did.
- The old code took `480 s / average(linger)` ≈ 516 s of real time per full
  turn. `day_length = 480.0` now means 480 s exactly, so a default day is about
  7% quicker than before with the same shape. Set `day_length = 516.0` for the
  old wall-clock pace.

## The year

`year_days` is how long a year lasts, in world days. It is a **knob**, not a
constant: `YEAR_DAYS = 28` is only its default (four seven-day seasons), it is
clamped to `MIN_YEAR_DAYS`..`MAX_YEAR_DAYS` (1..100000), it rides along in
`capture()`/`restore()`/`valid_state`, and a document written before the knob
existed simply has no key and keeps the 28-day year. Everything that draws a
year reads `clock.year_days` — the season scalar and the look editor's Day
scrubber, which spans `DAY_RANGE_YEARS = 2` of whatever year the clock keeps.

`season` is where the world stands in that year,
`fposmod(day + hour / 24, year_days) / year_days`, so day 0 opens at
0.0 and, with the default 28-day year, the quarters fall on days 0, 7, 14 and 21:

| season | 0.0 – 0.25 | 0.25 – 0.5 | 0.5 – 0.75 | 0.75 – 1.0 |
| --- | --- | --- | --- | --- |
| days | 0–6 | 7–13 | 14–20 | 21–27 |
| | spring | summer | autumn | winter |

`season` is read-only and derived, like `phase`: move `day` (`set_time`) or pin
it with `season_override`. Any override `>= 0` wins and is clamped into 0..1;
`-1.0` (the default) hands the year back to the calendar. The override is part
of `capture()`/`restore()`/`valid_state`, and a document written before the
calendar existed simply has no key and follows the days.

### What the season does today

Slices 0 and 4 of the world-progression plan wire five consumers:

- `WeatherScheduler.season` — the whole transition table leans on it, and each
  quarter of the year now has a recognisably different mix (see the
  weather-scheduler docs for the table and the measured hours).
- `surface_weather.target_autumn` and `target_cold` — the ground's gold and its
  cold.
- `scripts/fidelity_fish.gd` — the pond's restock rate, through
  `WorldClock.season_factor` and the pond's own `SEASON_RATE`.
- `scripts/bigfoot_living_world.gd` `_context()` — `season`, `season_name`,
  `cold` and `harvest` reach his decisions.
- `scripts/bigfoot_life_mind.gd` `ranked()` — the cold nudges `sleep`, the
  autumn gold nudges `gather`. Both are small; needs still win.
- `scripts/bigfoot_life_mind.gd` `drift()` (slice 5) — the cold is also the pull
  of the long winter drive, `torpor`, the one need kept on **world hours**
  instead of watched seconds: it chases `cold` with an 18-hour rise and a
  48-hour fall, so a garden that is fast-forwarded or reopened feels exactly as
  much winter as it lived through. It lifts a `hibernate` action and lowers his
  leisure; see docs/bigfoot-living-world/README.md.

The preset is the base and the season is a **lift added on top**, clamped to
0..1, so a snowy sky is still fully cold in midsummer and a clear day in late
autumn is still gold. Both lifts are smooth bumps on the year
(`WeatherScheduler.season_autumn` / `season_cold`, `[centre, half width,
strength]`):

| lift | centre | half width | strength | nonzero over |
| --- | --- | --- | --- | --- |
| autumn | 0.675 | 0.175 | 0.9 | 0.50 – 0.85 (the autumn quarter, spilling into early winter) |
| cold | 0.875 | 0.125 | 0.9 | 0.75 – 1.00 (the winter quarter exactly) |

Both fall to zero *before* the year wraps, so day 0 of a fresh garden is the
neutral scene it has always been and the new year arrives with no step. Spring
and summer add nothing at all.

`studies/fidelity.gd` `_apply_season()` recomputes both targets from the current
preset profile every frame, so nothing accumulates, and it never fights a
hand-set value: it only rewrites a target that is still the one it wrote last
frame, or the bare preset value a fresh `set_weather` just installed. A slider,
a look preset, a restored garden and the `--autumn=` / `--cold=` flags therefore
all keep their hold until the weather changes again.

The scene-look editor's Atmosphere tab carries the scrub tooling: a **Season**
slider (writes `season_override`), a **Follow the calendar** check (clears it), a
**Day** slider (`set_time(day, hour)`) and a **Force weather** picker. The clock
readout beside them names the quarter, and in a scene with a resident it shows
his winter drive while it is filling ("Day 3 · 09:12 · winter · torpor 0.62"),
which is how the Season slider is watched: pin it to 0.875 and he beds in within
a couple of world days.

### Seasonal rates: `season_factor`

Ecology that runs at a rate — the pond restocking, and dead wood after it —
reads the year through one pure static function:

```gdscript
static func WorldClock.season_factor(season: float, shape: Array) -> float
```

`shape` is four numbers, `[spring, summer, autumn, winter]`, each the multiplier
at the **opening** of its season. The value holds flat through the first half of
that season and then eases (smoothstep) into the next across the second half, so
the year is four plateaus joined by four shoulders. Two consequences are the
point of the arrangement:

- `season_factor(0.0, shape) == shape[0]` exactly, so a scene with no clock (it
  reads season 0) behaves precisely as it did before the calendar existed;
- winter has climbed all the way back to spring before the year wraps, so the
  new year arrives without a step — the same convention the gold and cold bumps
  follow.

A malformed shape (wrong size, a non-number) reads as `1.0`, the neutral rate.

The pond's shape is `fidelity_fish.gd SEASON_RATE = [1.0, 1.0, 0.6, 0.25]`:
spring and summer breed at the full two-world-day rate, autumn tapers, and a
winter pond takes about eight world days to refill — slow, but never zero, so
the food loop never fully closes.

## How the rest of the world integrates

**Celestial (`studies/celestial.gd`).** `attach_clock(clock)` hands time over and
seeds the clock with the phase the rig is already showing. After that:

- `phase` and `cycling` are **aliases** of `clock.phase` and `clock.running`
  (property getters/setters). Everything that already wrote those names — the
  "Let the day cycle" checkbox, the time-of-day slider, `set_phase` from moods
  and presets, the look editor's undo snapshots, the garden store — now reaches
  the clock without knowing it exists.
- `advance()` no longer integrates time when a clock is attached; it only
  refreshes the rig from `clock.phase`. The scene advances the clock first, so
  every system that asks the hour during a frame gets the same answer.
- `next_hour()` (KEY_N) routes to `clock.skip_to` on the next quarter day.
- With no clock attached the old self-integrating code still runs unchanged, so
  standalone studies keep working.

**Presets and moods.** `scene_look_presets.apply` and `fidelity.apply_scene_mood`
call `_celestial.set_phase(...)`, which now moves the clock's hour. Preset
documents still carry `phase`, not an hour.

**The scene (`studies/fidelity.gd`).** `_process` calls
`world_clock.advance(delta, _paused)` before anything else, and the time-of-day
label reads `world_clock.label()`.

**The look editor (`scripts/scene_look_editor.gd`).** The Atmosphere tab has a
"Day pace" selector (1x / 4x / 12x → `world_clock.speed`) under the cycle
checkbox, and a small "Day N · HH:MM" readout refreshed by `sync()`.

**The garden store (`scripts/native_garden_store.gd`).** `capture` adds a
`world_clock` key (only when the scene has a clock), `valid` checks it with
`WorldClock.valid_state`, and `restore` applies it. A save written before the
clock existed has no key: the restored `_celestial.phase` is converted back to an
hour on day 0, so legacy gardens open at the time of day they were saved at.

## Adding a consumer

```gdscript
var clock: WorldClock = scene.get("world_clock")
if clock == null: return          # a study without a clock; keep your old path
if clock.daylight < 0.15: ...     # night behaviour
if clock.day != _last_day: ...    # a new day started
```

Read the clock, never integrate your own copy of world time, and never write
`day`/`hour` from a consumer — use `set_time` / `skip_to` / `set_phase` if you
genuinely own a time change (a scripted sunrise, a preset). If your system needs
its own persisted timing, capture your own fields; the clock captures only the
world's time.

## Tests

- `tests/test_world_clock.gd` — pure: rollover, speed, pause, delta clamping,
  determinism, capture/restore (through JSON), `skip_to`, phase mapping, the
  year (quarters, wrap, the override winning and surviving a save, the
  `year_days` knob) and the `season_factor` curve.
- `tests/test_world_clock_scene.gd` — loads `studies/fidelity.tscn`, advances
  `_process` with fixed deltas and checks that the rig tracks the clock, that
  KEY_N's `next_hour` still snaps, that presets move the clock, and that the
  garden store round-trips it (including legacy saves).
- `tests/test_season_scene.gd` — loads the scene and checks the season reaches
  `weather_scheduler.season` and both surface targets, that a hand-set autumn
  is not fought, that the editor's Season/Day/Force-weather controls work, that
  the ground is right at all four quarters, and that each quarter's simulated
  weather mix looks like itself.
- `tests/test_fish_restock.gd` — the pond's rate at all four seasons.
- `tests/test_bigfoot_life_mind.gd` — the cold and gold scoring terms.
- `tests/test_bigfoot_living_world.gd` — the season keys in `_context()`.

Run one at a time, never headless:

```
"$HOME/Applications/Godot.app/Contents/MacOS/Godot" --path . --rendering-method forward_plus --script res://tests/test_world_clock.gd
```
