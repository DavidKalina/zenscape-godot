# Motif families (2026-10-12)

> The nine motif isles as templates a layer generator can place and
> connect: one motif, many isles. The contract is on
> `scripts/kit_isle/kit_motif.gd` ("The family"); the idiom is the traps'
> (`scripts/traps/trap.gd`) and the cluster solver's (seeded, deterministic,
> checked).

## What the nine share

Read across `scripts/kit_isle/motif_*.gd` and their `studies/*_isle_art.gd`:

- **One fixed seed**, sub-seeds by offset (`SPINE_SEED+20`, `RING_SEED+4`...).
- **A static layout**: tables of constants (the ring's `SATS` and `HOPS`,
  the colonnade's `LINES`, `STUBS`, `FALLEN`, `FRAGMENTS`) read by static
  functions, and read again by the isle's life, sky tokens, study and tests.
- **The same frame**: the turf datum `TOP` = 30, everything in the aqueduct
  isle's sky coordinates (not centred on the origin: the ring sits round
  (80, -10), the colonnade runs x 14..165). A generator places an isle by
  its `footprint`, not by its origin.
- **The same hop grammar** between the parts: a rope bridge
  (`Footbridge.live` on `RuinKit.bridge_anchor`s), floating stones
  (`Art.floating_stones` from platform dictionaries), a jump. Seven of nine
  hang satellites or fragments off a main isle this way.
- **Ruin notes** from `RuinKit.piece(id, seed, weathered)`; lands from
  `KitLand.island`; turf registered through `turf()`.
- Plane token lines, a life script, sometimes water (`pools`).

So the cheap knobs are what the ruin *has lost* (pieces snapped, fallen,
missing), how many satellites or fragments, how the hops are made, and
water. The expensive one is the main land's shape (a ridge, a crater, a
mesa), which every other function reads; round 1 leaves it fixed.

## The contract (kit_motif.gd)

A motif that answers `family()` true:

| Answer | What |
|---|---|
| `configure(seed, over)` | before `build`: the seed rolls the knobs (`roll`), `over` pins any (clamped to `knob_choices`). Same seed and knobs, the same isle. |
| `default_seed()` | at its own `roll`, the authored isle, exactly (tested by hash). |
| `knob_choices()` | each knob's values in order, for the generator and the gallery. |
| `knobs`, `current_seed()` | what is in force. |
| `sockets()` | `socket(kind, name, at, face, room, run_up)` dictionaries in its own frame, on its walked ground, read off the plan before any build. |
| `role()` | `hero` (a landmark a layer is built round), `filler` (route between), `arena`. |
| `footprint()` | its x z rect; everything it builds stands over it. |
| `height_span()` | its lowest keel to its highest walked top (y). |
| `build_cost()` | ms headless, measured, so a generator can spread slow builds. |

Socket kinds:

- **rim**: where an edge to another isle attaches. `at` a step in from the
  lip, `face` out over the drop (4 m out the ground is gone or 1.5 m+
  under), `run_up` the clear walked ground behind it along -face. A
  generator wants `run_up >= run_up_wanted()` (the pilot's run for 0.75 s,
  as the traps' `run_up`); rims under it are still reported, honestly.
- **arena**: a level spot clear of stone, `room` its radius: an on-isle
  trap or enemy.
- **cover**: out of the sky dragon's sight from above: stone over and round
  it (the test asks 65%+ of the sky above 30 degrees hidden) and a way in
  along `face`.
- **perch**: a trader's or a ledger activity's spot, `room` its clear radius.

Sizes come from the pilot (`pilot()`, `hop_reach()`, `run_up_wanted()`)
and the kit's pieces measure their own footprints (`piece_block` builds a
piece once on the main thread and keeps its colliders' rect); helpers
`clear_run`, `room_at`, `reach_out` do the 2D clearance.

## The two families

**The broken ring** (`motif_broken_ring.gd`, filler). Knobs: `isles` 5-8,
`jumps` 0-2 (how many hops are jumps, never the first), `climb` 0.7/0.85/1
(the hops' rises as a share of the authored), `missing` 0-3 (one run of
the circle's stones gone). `Ring.rolled` picks each hop's kind, rise and
sky from the seed in the pilot's reach (a jump 1.0-1.1 of his running hop,
a stones hop five strides of 0.72-0.84 hop each rising 1.05-1.35 of his
small jump, a bridge 1.95-2.7 hops), then solves each isle's angle round
the ring against the isles' real outlines, pushing the ring out (to 30 m)
and drawing the skies in until the break stays three hops wide. Sockets:
rims `entry` (lowest isle) and `exit` (summit), each turned up to 90
degrees to clear its note with a run-up; the arena at the clearest spot of
the middle isles; cover just inside the circle's turret door (about 90%
hidden); a perch at the summit's clearest spot.

**The colonnade spine** (`motif_colonnade_spine.gd`, hero). Knobs:
`collapse` 0-1 (round(6 x collapse) piers snapped to stubs, as many lintels
fallen, each portal crown losing up to that many voussoirs, at most 4;
the authored is 0.5), `tail` 1-5 fragments left, `bridges` intact / one /
both snapped (the anchors stand over the gap). Portal and cross-lintel
piers never snap (their arch and lintel would float); no lintel falls
where a way up stands. The ridge, terraces, stairs and temple are the one
ridge's. Sockets: rims `head` (the prow, west), `plaza_south` and
`terrace_south` (the clearest run-up across L3 and L2), `tail` (the last
fragment left); the arena at the clearest terrace spot between the rows;
cover on the south stair turret's doorstep (about 73%: the north turret's
door opens into the gate's flank, and nothing on the crest is roofed);
the perch at the podium's clearest spot.

Both keep every layout function's old signature: the plan is an optional
last argument, the authored tables when none is given, so the studies,
lives, skies and their tests read the authored isles as before.

## Round 1 handoff

**Built**
- The contract on `scripts/kit_isle/kit_motif.gd` (the seven other motifs
  answer `family()` false and are untouched).
- The broken ring and the colonnade spine as families (above); the art
  builders take a plan (`studies/broken_ring_isle_art.gd` `authored` /
  `rolled`, `studies/colonnade_spine_isle_art.gd` the same).
- `tests/test_motif_families.gd` (`## suite: slow`, about 50 s headless)
  with `tests/motif_fingerprint.gd`: the default seeds hash to today's
  isles (hashes taken before the change), a config built twice hashes the
  same, every knob value builds, every socket stands in its footprint and
  height span on solid ground and passes its kind's checks, the rolled
  ring's jumps measure 1-3.2 m, its other hops and its break over 4 and 6.
- The gallery, `studies/motif_family_gallery.tscn`.

**The gallery** (windowed):

```sh
/Users/davidkalina/Applications/Godot.app/Contents/MacOS/Godot --path . res://studies/motif_family_gallery.tscn -- --no-title --family=broken_ring --seed=81
```

`--family=colonnade_spine` or `broken_ring`; `--seed=` (the authored seed
if none: 61 and 81); `--knob=key=value` pins a knob. N / Shift+N next /
previous seed, M / Shift+M next / previous family, R the start (the arena,
looking at the first rim). Orange rims (an arrow out, a line back along
the run-up), red arena rings, blue cover, green perches, each labelled.
No sky and no life; the grass grows, the plane is parked near the start.

**Unverified (headless can't see it)**
- How the rolled isles look: a five-isle ring, a ring pushed out to 30 m
  (longer centre bridge), `collapse` 1.0, a snapped bridge (anchors with
  nothing between), a one-fragment tail. Geometry is tested; the look isn't.
- The markers' look and legibility, the card, the grass on rolled isles.
- The gallery windowed: the reload on N/M ran headless only.
- The rolled ring's hops driven on foot: gaps and rises are measured and
  sized from the pilot, but no test jumps them (test_broken_ring_isle.gd
  drives only the authored ring).

**Weak spots, honestly**
- Cover on the colonnade is the best walked spot there is, about 73% of
  the sky; the ridge has nothing roofed. A real roofed nook would be new
  art (a lean-to of the kit's pieces), out of scope here.
- The ring's arena is small (3-3.8 m of room in the tested seeds): its
  isles are 6-7.6 m in radius and each carries a note. Its rims' run-ups
  are 3.6-7 m, at or just over the wanted 3.6. The colonnade's tail rim has under the
  wanted run-up on small fragments (2-7 m); the plaza rim drops to about
  6 m when a lintel lies across it. A generator should filter rims by
  `run_up`.
- Rolled isles have no life (`life_script` is null off the authored seed):
  the lives read the authored tables. The aqueduct isle's sky still places
  only the authored isles.

**For round 2 (retrofit the rest, the layer graph)**
- Retrofitting: thread an optional plan through the art's static layout
  functions (authored tables when none), keep sub-seeds as offsets of the
  isle's seed (0 shift at the authored), hash the authored isle first
  (`tests/motif_fingerprint.gd`) and add the family to the test's
  `FAMILIES` and `TODAY`. Watch the static caches (move them into the plan
  dictionary) and the kit's own limits (the stone circle has no lintel
  left to drop if three of its stones go: `GONE_RUNS`).
- Natural knobs for the rest: the bell spires (which bells fallen, which
  of the four bridges snapped, crowns), the cloister tarn and the drowned
  nave (water full or drained; the cloister's arcades fallen), the
  sundered gorge (how far the halves have drifted, the rope bridge or
  not), the stair to the clouds (flights fallen, the pinnacle's bridge),
  the hollow keel (stairs down the shaft). The dragon's roost is a
  set-piece, likely not a family.
- The layer graph: rims are edges' ends (`at`, `face`, `run_up`);
  `footprint` and `height_span` pack isles; `role` picks one hero a layer;
  `build_cost` (3.4 s the colonnade, 1.4 s the ring) says what to build on
  a worker over frames. Sockets are pure plan reads (no physics), so a
  generator can lay a whole layer before building any of it, except
  `piece_block`, which builds a piece once on the main thread.
