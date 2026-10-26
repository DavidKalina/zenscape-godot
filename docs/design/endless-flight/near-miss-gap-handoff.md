# Near misses: the gap readout and the edge

Builds on `near-miss-handoff.md`. The default HUD (`scripts/endless/near_miss_hud_handoff.gd`, tag and top) shows how close the plane came, and the score climbs steeply over the last metre.

What changed
- **The edge** (`scripts/endless/near_miss.gd` `edge`, EDGE, EDGE_SOFT). Every moment's points are also × (EDGE + EDGE_SOFT) / (least + EDGE_SOFT) under EDGE spans, × 1 past it. At plane 2 (span 2.8 m) that is × 1 at 1.0 m, × 2 at 0.4 m, × 3 at 0.2 m, × 4 at 0.1 m and × 6 touching.

| least | before | now |
|---|---|---|
| 2.0 m | × 2.24 | × 2.24 |
| 1.0 m | × 3.02 | × 3.04 |
| 0.4 m | × 3.59 | × 7.21 |
| 0.12 m | × 3.87 | × 14.6 |
| 0 m | × 4.00 | × 24.0 |

- **The live gap** (`NearMiss.gap`): the nearest thing in reach (the ground under REACH spans, a wing or the roof under STONE_REACH), only while flying fast enough to score. F1's near line shows it.
- **The readout**, at the tag's foot, nearest the plane: a down chevron and the closest so far this pass in metres (two places under 1 m). It counts down as the plane closes and holds the least once it starts to rise. Its colour is mist out at the reach and cream at the close band (1.4 m), then gold, orange and burning toward touching. It grows from GAP_PX.x to .y, and throbs under the razor band. A scored pass locks it on the moment's least: one white frame, a pop, held GAP_HOLD (1 s). A pass that scored nothing (too slow to be a pull-out, a skim's dip) or a scrape fades it (GAP_FADE). It comes back once the plane closes again at GAP_CLOSING (0.6 m/s). The cluster's foot moved down (CLUSTER_FOOT 392 to 560 D) to make room, so the tag sits a little higher off the plane.
- **Feed lines** carry the least between the kind and the points ("PULL-OUT 0.16 m +3,201"), coloured as the readout. After play, the user found them too small: ROWS' badge, kind and points sizes went up about 1.35x, the rows spread to match (newest at 380 D), the gap moved to GAP_Y 502 and CLUSTER_FOOT to 590.
- The glyph and classic HUDs (`--near-hud=glyph|classic`) are unchanged.

Measured (throwaway `scratch/gap.gd`, uncommitted; `python tools/drive.py scratch/gap.gd -- --h=3.5,3.2,3 --push=0.25 --alt=8 --back=40`, medium, seed 1, a glide into the meadow MenuSpot finds first, full back at h)
- The same dive, pulled later: 0.85 m least 903 points, 0.49 m 1,555 (unfarmed), 0.12 m 3,769 (unfarmed). Before, 0.12 m would have been about 1,000.
- The readout over a pull: 3.32, 2.50, 1.75, 1.16, 0.87, 0.85, then locked 0.85 for 1 s, then fading.
- Gentle glides sinking under PULL_MIN (3.75 m/s at brisk) came to 0.37 m and scored nothing (the existing rule: only skimming). The readout showed the 0.37 m and faded without the lock.
- Rendered stills (`--rendered ... --shot --at=0.3`, `scratch/gap_cap/`): live "0.46 m" in orange beside the plane; locked "0.16 m" under "PULL-OUT 0.16 m +3,201". The readout was enlarged once after the first look.

Proof: smoke PASS for endless_flight and flight_study. No test reads near_miss.gd or the HUD.

Not verified
- The feel in play: whether the live number is readable at speed or distracts, and whether the edge makes razor passes worth too much against the chain and the meter (METER_FULL 4000; one 0.1 m pull-out now nearly fills it).
- Long canopy or canyon skims, where the readout stays up the whole time.
