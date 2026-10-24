# Overgrown look (handoff)

**Where the isles' orange grass came from.** It is autumn, not a palette. The isle's KitWeather opens in the real date's season and publishes `zs_autumn` (1 in autumn) and `zs_season` (w = how far into autumn); the tuft shaders (`zs_autumn_paint`, reference_surface palette_role) gold the grass (commit 677ba968 notes it). Endless flight resets those globals on start (season-leak fix), so wilderness is green.

**What overgrown sets** (`scripts/endless/world/overgrown/look.gd`):
- `globals`: `zs_autumn` 1, `zs_season` (0,0,0,0.7). This turns the near tufts.
- Mood `desert_afternoon` at hour 14.8 (warm salmon sky, warm key light).
- `ground`: `carpet_tone_top/low` (the painted ground and watercolour washes seen from afar) and the new `carpet_under_tone` (the turf under tufts, so no green shows between them).
- `far` (new table): the far tuft ring's `root_colour`/`tip_colour`.
- Flora: `forest` 0.5, `forest_meadows` 0.5, `tree_weights` leaning windswept/sparse/dead-top, `grass_tall` 1.35.

**Engine additions, all opt-in (defaults are exact no-ops):** `WorldProfile.apply_far` + `paint.far` (endless_grass `_far`), flora key `grass_tall`, ground uniform `carpet_under_tone` (default 1). Wilderness stills (meadow_low, hills, cruise, high) match the pre-round ones to within 2/255.

**Knobs to tune:** the three tones above, `far` colours, `zs_season.w`, mood and hour, forest share. Not done: spruces are still blue-green (no autumn shader on them), sea tints left at defaults, grass colour regions still multiply as in wilderness (Patch regions are mirrored in GDScript and shader), flower colours unchanged.

**Captures** (git-ignored): `captures/overgrown-look/r2_wilderness|r2_overgrown/` (meadow_low, hills, cruise, high, onfoot), `r3_overgrown/` (final trees), `pair2_*.png` side by sides (wilderness left). Made with `tools/harness/look_views.gd -- --scene-args --no-title --world=<id>`.
