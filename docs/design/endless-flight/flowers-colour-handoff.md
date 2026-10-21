# Endless flight, look round 5: flowers and grass colour regions

The ask: "Can we add flowers here and there and different colored grass in some areas?"

## What changed

- **Flower drifts.** Wildflower drifts of one kind each are scattered over the meadows: buttercup, oxeye daisy, dandelion, poppy, lupine, and pink and magenta cosmos. Yellow is the most common. There are big drifts (46 m lattice, 13–23 m across, with edges warped and clumped) and small patches (15 m lattice). About 12% of a drift's flowers are the meadow's own kinds, mixed in as companions. Lone strays grow everywhere between drifts. A near cell now grows about 2500 flowers, against about 900 before.
- **Drifts read from far off.** Past the drawn flowers (from 22 to 55 m), the painted ground draws the drift's flower heads as coloured dots on two lattices. Where a pixel is wider than a head, the dots blend into a wash of that colour. Up to 35% of the far ring's tufts in a drift take the flower colour too. The dots fade in over the same distances the real flowers fade out over, so nothing pops. At cruise and high views the drifts read as speckled patches of colour.
- **Grass colour regions.** Seeded regions a few hundred metres across tint the meadow: lush deep green, fresh lime, sage blue-green, golden straw, and a heather tinge on higher ground (16–34 m over the sea and up). Their borders are soft, 50–80 m wide.
- **Everything reads the same field.** The tufts' tint (near and far ring), the tuft roots, the flowers grown on the workers and the painted ground all read one hash, so tufts and turf agree at every distance:
  - `scripts/endless/endless_patch.gd`: `region`, `bloom`, `KINDS`, `seed_offset`.
  - `shaders/endless_patch.gdshaderinc`: `ep_region`, `ep_bloom`, `ep_wash`.
  - Each land seed has its own offset.
- **Shared file, opt-in only.** `scripts/kit_isle/kit_flora.gd` gains two Site fields:
  - `flower_kind`: a callable that returns a kind and colour variant for a point.
  - `flower_tries`: flower candidates per m².

  Both default to off, so the aqueduct isle and the motif editor grow as before.
- **Unchanged:** land shape, collision and landable meadows. The drift wash shows on open turf only.

## Flags and knobs

All earlier flags and keys still work.

New flags:

- `--flower-drifts=X`: how many drifts (default 1). `0` or `--no-drifts` brings back round 4's drifts with no wash.
- `--grass-regions=X`: how strongly the colour regions show (default 1; 1.5 is still fine). `0` or `--no-regions` gives one palette.
- `--no-flowers` still removes all flowers, and the wash with them.

Constants:

- `endless_grass.gd`:
  - `BLOOM_PEAK` (16): how many times as many flowers grow at a drift's heart.
  - `BLOOM_TRIES` (3.4): flower candidates per m².
  - `BLOOM_COMPANION` (0.12), `BLOOM_KIND` (0.12): the companion share, and how far into a drift its own kind takes over.
  - `FAR_WASH` (0.35): the share of far-ring tufts in a drift that take the flower colour.
- `endless_patch.gd` and `endless_patch.gdshaderinc` (keep the two in step):
  - The region hues `LUSH`, `LIME`, `SAGE`, `STRAW`, `HEATHER`.
  - The noise scales, which are 380, 300 and 220 m.
  - The drift lattices and their chances.
  - `KIND_SLOTS` (which kinds appear and how often) and the washes.

Ground uniforms:

- `bloom_wash`: under the flowers 0.10, past them 0.9.
- `bloom_dots`: the head sizes, 0.38 and 0.62 m.
- `bloom_fade`: set from `FLOWER_FADE`.
- `region_amount`, `bloom_amount`, `region_offset`.

All can be tuned with `--ground-set=`.

## Perf

Measured on the M5 Pro, Forward+, 1440×900, uncapped, with clouds on, at the 1200,950 meadow (`scratch/endless-grass-tune/perf.sh`). Each figure is the mean of 300 frames. The new build and the old look (`--flower-drifts=0 --grass-regions=0`) were run alternately, two pairs each:

| view | old look (ms) | new (ms) | cost (ms) |
|---|---|---|---|
| low, 6 m | 12.4 | 13.2 | about +0.8 (the extra flowers) |
| cruise, 45 m | 10.2 | 10.1 | about 0 |
| high, 95 m | 9.1 | 9.5 | about +0.45 (the ground's drift lookup) |

Runs on this machine vary by about ±0.5 ms. The ground's drift lookup was cut by:
- reading only the four lattice cells that can hold a drift;
- skipping off-turf and far pixels;
- dropping a fine warp.

Cell grow on the workers: a near cell takes about 530 ms (was about 510). A far cell takes about 105 ms (was about 128), because no flowers are sown there now.

## Verified

- Headless import: 0 errors.
- Smoke PASS, 0 errors, for `endless_flight` in these runs:
  - default;
  - `--flower-drifts=0 --grass-regions=0`;
  - `--no-drifts --no-regions --no-flowers`;
  - `--no-grass --flower-drifts=2 --grass-regions=1.5`.
- Smoke PASS, 0 errors, for `aqueduct_isle`, and for the motif yard with `bell_spires` and with `editor_hill`.
- A rendered run of 900 frames quit with no leak or ObjectDB warning. Every still run had 0 errors.

## Stills (`scratch/endless-flowers/`)

- `fin_sheet.png` has all five final stills:
  - `fin_cruise` (45 m);
  - `fin_high` (95 m);
  - `fin_over` (230 m, no clouds; shows the regions);
  - `fin_drift` (a 10 m pass over a lupine drift at 1120,686);
  - `fin_golden` (golden meadow at 30 m).
- `fin_vs_off.png`: cruise and overview, the new look against `--flower-drifts=0 --grass-regions=0`.
- Scripts: `final.sh TAG [flags]` takes all five views, and `VIEWS=` picks some of them.
- `scratch/find_drift.gd` lists drift hearts near the start.

## Not verified

- **Motion.** The painted dots could shimmer at speed, and I haven't watched the 22–55 m hand-off from flowers to dots in flight.
- **Moods.** Only alpine morning and golden meadow were looked at.
- **CPU against GPU.** That the CPU and GPU hashes agree was judged by eye only, in a `--grass-regions=3` still (tufts and turf followed the same borders). No pixel test was run.
- **Stills.** One `final.sh` run saved its cruise still with the golden sky. Retaken alone, it was normal. I didn't find the cause.
- Windows and other GPUs.

## Existing tests

- No test covers the endless scripts or KitFlora.
- The KitFlora change is opt-in.
- The full suite was not run.
- `test_aqueduct_isle_look.gd` already failed before this round (see the grass-tune handoff).

## Next cues

- **Daisy drifts.** White daisy drifts seen from very high can read as pale dry patches. Their slots in `KIND_SLOTS` can be cut further.
- **Denser drifts up close.** Up close a drift is still a loose sowing, because the meadow's own presence noise thins it. Letting a drift override `presence` (another KitFlora opt-in) would make thick carpets.
- **Regions in the moods.** The regions could also follow the mood's palette. Sage leans cyan under golden light.
