# The chunk manifest

Every ingredient the world offers Bigfoot: what it is, whether it renews, the
keys it puts in the decision context (`scripts/bigfoot_living_world.gd`
`_context()`, read by `scripts/bigfoot_life_mind.gd` `ranked()`), and which
actions those keys move.

Each slice of `PLAN.md` adds a row. A row with **Lifecycle: none** is a
one-way ingredient: once it is used up or filled up it never changes again,
which is exactly what the arc is meant to fix.

| Ingredient | Lifecycle | Context keys exposed | Actions that read them |
| --- | --- | --- | --- |
| Home (a dug tunnel) | None. Dug once, then permanent. | `home` | Gates `sleep`, `gather`, `eat`, `fish`, `check_home`, `play` |
| Food stash | Drains only. `fish` adds, `eat` removes; nothing restocks the pool. | `food_count`, `can_fish` | `eat` (needs food), `fish` (only below 3 fish) |
| Bed comfort | Fills to stage 3 and stops. Never degrades. | `material_needed`, `can_gather`, `comfort` | `gather` (a poorer bed scores higher), `sleep` (comfort speeds recovery) |
| Play stones | Three placements, then done. | `can_play` | `play` |
| Curiosity targets | Renew as the world changes, but familiarity only ever grows. | `curiosity_target`, `target_id` | `investigate` (familiar things score lower) |
| Favourite places | Grow from remembered experiences; capped at 8. | `ritual_target` | `ritual` |
| Home disturbance | Event-driven: an observed change near home, or the check timer. | `home_check_due`, `disturbance` | `check_home` |
| Hour and daylight | Cycles every world day (`scripts/world_clock.gd`). | `hour`, `daylight` | Every action: darkness tires and wearies, twilight lifts `fish`, dusk lifts `ritual`, night lifts `sleep` |
| **Season** (slice 0) | Cycles every 28 world days, four seven-day seasons; `season_override` pins it. | None yet — read directly off the clock as `world_clock.season`. | None yet. Today it feeds `WeatherScheduler.season` and the ground's `target_autumn` / `target_cold`; slices 1–5 give it scoring terms. |
