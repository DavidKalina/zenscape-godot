# Pollen and slow creep for the other flowers

Branch `beautification`, 2026-10-02. The second pass after the dandelion's round (docs/scenic/dandelions.md). Painting stays the tool; spreading is what living plants do.

Settled with the user:

- **Glints and creep only.** Oxeye daisy, buttercup, poppy, cosmos, lupine and sunflower get faint pollen and a slow creep. No wilt or regrow, and no change to the flower mesh or material.
- **Much slower than dandelions.** About a quarter of the dandelion's creep.
- **Butterflies do not carry pollen yet.** Later.

## The seam

`scripts/dandelion_seeds.gd` is now the per-kind spreading module (the name is kept so the dandelion's code and tests are unchanged). One table, `BLOOMS`, is the spec of a kind:

- `slot`: the `FlowerSowing` slot whose ground rules and sizes a new plant of the kind uses (wildflower for daisy, buttercup and lupine; poppy, cosmos, sunflower their own);
- `pollen`: the glint's colour (sRGB, pale and warm).

The dandelion kinds are not in it: they keep their seeds, round and `CLOCK_SHARE`. A kind added to `BLOOMS` gets glints and creep with no other change.

Shared, not copied: the index (`reindex`, `_flower_cells`, `_room_cells`), the air (`air_at`, `lean_at`), the particle arrays and flight (a `_kind` per particle: "" a seed, else the parent's kind), `take()` and every taking rule. `take(p, parent)` grows a plant of `parent`'s kind (`""` is the dandelion's mix). Sowings are cached per slot.

## What happens

- **The breeze lifts.** The whole land lets a grain go at `PUFF` (1/25 s) per bloom at 1 m/s of air, as the square of the air, at most `POLLEN_RATE` (24/s). Each pick is a random bloom, accepted by its local air, as the clock's peel is. Still air lets none go.
- **A gust shakes more.** Every `GUST_TICK` (0.25 s) while the wind tool blows, the 2 m cells of blooms the lean touches (`STRIP_LEAN`) let `GUST_PUFF` (0.6/s) a bloom go at full lean.
- **The grains** ride the same air as the seeds, sink at `POLLEN_SINK` (0.22 m/s), keep under `POLLEN_CEILING` (3 m), and fade where they land or after `POLLEN_LONGEST` (14 s). At most `POLLEN_MAX` (220) fly at once, apart from the seeds' own `SEEDS_MAX`.
- **The look.** A second MultiMesh with `shaders/pollen_speck.gdshader` (the wind tool's glints: soft, warm, lit by the scene, wisped along the way they move). Radius 0.05 to 0.085 m, opacity 0.85 with a slow twinkle: faint from the diorama distance, drawn larger than life as the heads are.
- **Some take.** A landed grain takes with chance `POLLEN_TAKE` (0.008, against the seed's 0.12) under exactly the dandelion's rules: ground the brush could paint, `ROOM`, a flower within `CREEP`, under `CROWD`, not on ground the hand thinned in the last `CLEAR_HOLD`, under `MOST_FLOWERS`, at most one take every `SPREAD_GAP`, never into an open stroke. The new plant copies its parent's kind, is an `emerged` record with a `born` stamp, is drawn at once and is itself a bloom in turn.

Measured headless (`tests/test_flower_spread.gd`, a 3 m drift in a steady 1 m/s breeze, 30 minutes): dandelions grew 28 plants, poppies 10 and daisies 3 (mean 6.5, about a quarter), the furthest 5 to 7 m from the middle. The chance was tuned to that ratio; creep feeds itself a little, as new plants shed in turn.

## Cost

- Main thread, 4,356 flowers (`tools/probe_flower_spread.gd`, headless): reindex 4.9 ms (4.4 ms before, now also indexing the blooms); a breeze step 0.05 ms mean, 0.10 worst; a gust step 0.26 ms mean, 1.2 ms worst (the 4 Hz cell scan, about 190 grains in the air).
- GPU (`tools/film_breeze.gd --land=wildflowers --seconds=0 --probe`, 1280x720): median 23.0 to 24.7 ms with the change against 23.1 to 24.5 ms at HEAD over repeated runs, within the run-to-run noise. One more draw call (the pollen node).

## Checks

- `tests/test_flower_spread.gd` (headless): the spec; still air lets none go, a breeze lifts, a stronger air more, a gust far more; grains ride downwind and stay under `POLLEN_MAX`; dandelions let none go; every taking rule; a new plant copies its parent's kind for every kind in `BLOOMS`; 30 minutes of creep stays near the drift and is at most half the dandelion's.
- `tools/still_pollen.gd` (rendered, `--no-title`): a wildflowers meadow in a breeze, and just after a sky gust. Frames go to `captures/pollen/`.

## Not verified

- Motion over time: stills only. The twinkle and drift have not been watched.
- Dusk and night look of the glints; glints close up.
- Pollen under the real hand wind tool's wake and bursts (the headless test uses a stand-in lane).
- Undo after spreading takes back plants that came up since, as with emergence.

## Open

- Butterflies and bees carrying pollen between drifts.
- The wilt and regrow cycle for the other kinds, if wanted.
