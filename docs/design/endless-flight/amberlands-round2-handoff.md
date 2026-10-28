# Amberlands, round 2: handoff

Spec: `spec-amber-r2.md` (and its spec changes). Trail:
`git log --grep='^ITER(amber-r2)'`; every commit's Notes carry the detail.
Round 1: `amberlands-round1-handoff.md`.

## Play it

`.\run-endless-flight.cmd --world=amberlands` (also in `--world=regions`, in
the Overgrowth's place; the Overgrowth is `--world=overgrown`). On seed 1:

| What | Where |
|---|---|
| Colosseum | (476, -948), ~1 km south-east of the start |
| Ruined nave (forgiving knife slots on its west flank) | (-1840, 398) |
| Belfry tower (strict knife slits) | (701, 883) |
| Rose gate (forgiving slots) | (-885, 1912) |
| Aqueduct bridges | near (-477, -520), (1142, -965) |

Knife edge: hold Q/E. Flags to compare: `--no-sets`, `--sets=colosseum`
(a colosseum in every set cell that can take one), `--no-bridges`,
`--bridge-road=` (share of road bridges, default 0.5; 0 = all aqueducts),
`--aqueduct-fine` (the old heavy aqueduct), `--no-stone-moss`.

## What's built

- **Gothic set pieces** (`scripts/ruin_kit_gothic.gd`: `gothic_nave`,
  `belfry_tower`, `rose_gate`), placed by `scripts/endless/set_plan.gd`
  (1400 m cells, one piece at most, on shelves with a rising side), named
  `amberlands/<id>_<sx>_<sz>`. `openings()` / `plan()` give every opening
  without building; each knife slot says `forgive`.
- **Knife slots in two kinds** (`scripts/endless/knife_glance.gd`):
  forgiving (the nave's buttress slots, the rose gate's) fit the plane's
  true side shape and turn a jamb hit into a scrape that slides it to the
  middle; strict (belfry slits, the nave's east slits and wall lights) are
  plain contact, with sharper jambs and fewer strands.
- **An abandoned colosseum** (`scripts/ruin_kit_colosseum.gd`, id
  `colosseum`): 160 x 190 m, 50 m tall, 64 bays, one long side fallen in
  steps, the arena floor broken into a trench, gates on the long axis, a
  roofed ambulatory to fly round. Bays built once and repeated by
  MultiMesh; a coarse far shell past 600 m (crossfaded over 60 m). A rarer
  set piece kind on flat terraces with a landing strip beside it. The
  first-tier passages are walled up (too tight to thread).
- **Bridges in two forms** (`scripts/endless/bridge_plan.gd`,
  `bridge_build.gd`): aqueduct arcades (slimmed: 786k -> 255k tris and
  29.8 s -> 1.9 s on a 411 m two-tier, ivy grown back) and great road
  bridges (`scripts/ruin_kit_bridge.gd`: wide deck, parapets, few big
  arches, gates along the deck), some broken, some chained, rim to rim.
- **Overgrowth**: moss in the stone's shader (`shaders/stone_moss.gdshaderinc`,
  `scripts/gothic_growth.gd`) plus hanging growth, in muted gold-olive;
  the nave's shade lifted; the belfry raised to 106 m. The user kept this
  look ("keep it for now").
- **The rival's race** takes set piece, bridge and colosseum lines as gates
  (`scripts/endless/rival_pieces.gd`; never knife slots). Also fixed: the
  arch-candidate crash that sent every race near a land arch to air gates
  since 2026-10-26 (`_arch_opening`; on main too until this merges).
- **Big set pieces' colliders** go in over frames as server shapes
  (`arch_build.gd` Feed): the colosseum's add frame 52.6 -> 3.6 ms.

## Flown by hand

Through the real play loop (`scratch/sets/thread.gd`, a pilot 150 ms late
with wobble A), 10 trials. No crashes at A 0.2 on: the nave lengthwise,
lancets, flank corridors, belfry lights and tracery, rose window,
forgiving knife slots (steady hand), every bridge line (also at A 0.3),
and the colosseum's gates, ambulatory lap, outer arcade, drop over the
break and trench. Strict slits: a steady hand gets through 9/10 at A 0.1.

## Checks at the end

Smoke PASS, 0 errors: `--world=amberlands`, `--world=regions`, default,
`--world=amberlands --sets=colosseum`, `--world=overgrown`. Flats check
(`scratch/trunk5/flats.gd`, with the pieces' and bridges' footprints
masked): seeds 1, 3, 42 no worse than the bare land; seed 7 one more block
over 400 m, none over 600 m.

## Open

- The forgiving glance hasn't been watched in motion: it slides the plane
  up to ~1 m in a few frames, which may read as a pop.
- The colosseum's far switch (both levels see-through between ~540 and
  660 m) wants judging in play; past 2 km it draws a little more than
  before (16.4k vs 14.5k); its shadow could come from a lighter stand-in.
- The road bridge's growth is thin; the belfry is sited on low ground and
  sits low against the hills from a kilometre.
- Road bridges carry ~13x the collider boxes (watch for a hitch on a
  crowded route).
- Rare dummy-renderer RID errors in ~1 in 8–10 parallel headless runs
  (never in play); 4 Jolt "Hull building failed" on thin road-bridge
  splinters (kit yard only; the land swaps hulls for boxes).
- The chase camera sits inside buttress stone partway down the nave's
  flank slots.
- One seed-1 two-tier aqueduct (`bridge_-2_2_1_0`) sits in a hollow: flown
  one way the land rises right past the arch and the pass crashes.
- `tests/test_ruin_kit.gd`'s 30 m size cap fails on the new pieces
  (lock-in round).

## Harness gaps

- The flats check (`scratch/trunk5/flats.gd`) has been copied between
  worktrees for four rounds; it belongs in `tools/`.
- `thread.gd` (the hand-flight driver: gothic, bridges, colosseum,
  `--ordered` laps, steady hand) is uncommitted in `scratch/sets/`; it
  belongs in the harness too.
