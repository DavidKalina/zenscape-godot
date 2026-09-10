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
var running: bool     # false = time frozen (this is celestial's old `cycling`)
var day_length: float # real seconds per world day at speed 1.0 (default 480.0)
var elapsed: float    # total world seconds, day * 86400 + hour * 3600
var season: float     # 0..1 position in the year, read-only (see below)
var season_override: float # >= 0 pins the season; -1.0 follows the calendar

func advance(delta: float, paused: bool) -> void
func set_time(day: int, hour: float) -> void
func skip_to(hour: float) -> void      # smooth-target, the old next_hour easing
func capture() -> Dictionary
func restore(value: Dictionary) -> void
```

Supporting helpers: `calendar_season()` (the season the day count alone says it
is, ignoring the override), `set_phase(phase)` (jump to the hour that renders as this
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

`YEAR_DAYS = 28`: four seven-day seasons. `season` is where the world stands in
that year, `fposmod(day + hour / 24, YEAR_DAYS) / YEAR_DAYS`, so day 0 opens at
0.0 and the quarters fall on days 0, 7, 14 and 21:

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

Slice 0 of the world-progression plan wires three consumers, no new ecology:

- `WeatherScheduler.season` — the transition table already leans on it (autumn,
  snow and overcast get likelier as it climbs; see the weather-scheduler docs).
- `surface_weather.target_autumn` and `target_cold` — the ground's gold and its
  cold.

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
**Day** slider (`set_time(day, hour)`) and a **Force weather** picker.

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
  determinism, capture/restore (through JSON), `skip_to`, phase mapping, and
  the year: quarters, wrap, the override winning and surviving a save.
- `tests/test_world_clock_scene.gd` — loads `studies/fidelity.tscn`, advances
  `_process` with fixed deltas and checks that the rig tracks the clock, that
  KEY_N's `next_hour` still snaps, that presets move the clock, and that the
  garden store round-trips it (including legacy saves).
- `tests/test_season_scene.gd` — loads the scene and checks the season reaches
  `weather_scheduler.season` and both surface targets, that a hand-set autumn
  is not fought, and that the editor's Season/Day/Force-weather controls work.

Run one at a time, never headless:

```
"$HOME/Applications/Godot.app/Contents/MacOS/Godot" --path . --rendering-method forward_plus --script res://tests/test_world_clock.gd
```
