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
| Food stash | `fish` adds, `eat` removes. | `food_count` | `eat` (needs food), `fish` (only below 3 fish) |
| **Fish** (slice 1) | Renewable: seeded slots refill toward capacity over ~2 world days, ×2 at night, ×2 for half a day after rain, and ×`SEASON_RATE` for the time of year (slice 4: spring/summer 1.0, autumn 0.6, winter 0.25 — eight world days, never zero); frozen while world time is. | `can_fish`, `fish_available` | `fish` (a full pond adds a little), `eat` downstream |
| Bed comfort | Fills to stage 3; storm hours erode it while he is out (slice 2). He only learns on his next visit home. | `material_needed`, `can_gather`, `comfort` | `gather` (a poorer bed scores higher), `sleep` (comfort speeds recovery) |
| Play stones | Three placements, then done. | `can_play` | `play` |
| Curiosity targets | Renew as the world changes, but familiarity only ever grows. | `curiosity_target`, `target_id` | `investigate` (familiar things score lower) |
| Favourite places | Grow from remembered experiences; capped at 8. | `ritual_target` | `ritual` |
| Home disturbance | Event-driven: an observed change near home, or the check timer. | `home_check_due`, `disturbance` | `check_home` |
| Hour and daylight | Cycles every world day (`scripts/world_clock.gd`). | `hour`, `daylight` | Every action: darkness tires and wearies, twilight lifts `fish`, dusk lifts `ritual`, night lifts `sleep` |
| **Weather** (slice 2) | Scheduler drift or a player pick; storm hours erode `bed_stage` while he is out, restored only by tending. | `weather`, `wet`, `sheltered` | `sleep` (+shelter, lower threshold), `gather` / `fish` / `play` / `investigate` / `ritual` (penalties), `gather` again via `material_needed` |
| **Dead wood** (slice 3) | Renewable: wind and falling water drop branches under the trees (storm 6, rain 2, calm 0.35 per world day, all scaled by the sky's wind), they lie there as visible traces, and they rot away after 4 world days. Frozen while world time is; at most 12 on the ground at once. | `branches_nearby` | `gather` (fallen wood adds up to 0.08 and renames the reason), and `can_gather` / `_material_targets()` now point at the branches instead of the trees |
| **Season** (slices 0, 4) | Cycles every `world_clock.year_days` days (28 by default), four quarters — spring, summer, autumn, winter; `season_override` pins it. | `season` (0..1), `season_name`, `cold` (the winter chill, 0 outside winter), `harvest` (the autumn gold, 0 outside autumn) | `sleep` (cold adds +0.12 and lowers the tiredness threshold by 0.05), `gather` (harvest adds +0.10). It also sets the whole weather mix (`WeatherScheduler.season`), the ground's `target_autumn` / `target_cold`, and the pond's restock rate (`WorldClock.season_factor` with `fidelity_fish.SEASON_RATE = [1.0, 1.0, 0.6, 0.25]`). |
