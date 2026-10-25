# Near misses: the low zone, scrapes and crashes, scoring, the chain and the surge

Builds on `flight-weight-handoff.md` and `flight-sound-handoff.md`. Everything here runs in the weighted presets (light, medium, heavy) only. `off` is the flight as it was: the same path digest and the same weight numbers as before the change.

What changed
- **Low zone** (`scripts/sky_plane.gd` `_low_zone`, knobs in `scripts/flight_weight.gd`).
  - Under `low_spans` wingspans of belly clearance over what is under it (the land, a tree's crown, a ruin's top, the water), the nose stops easing level. Hands off, it eases to `settle_pitch` instead, and the plane sinks `settle` m/s, both scaled by `low`.
  - `low` runs 0 at the zone's top to 1 at LOW_FULL (0.25 spans). It is the square root of the share of the way down, so it bites from the top of the zone.
  - A buffet of `buffet` m/s (two sines) moves it up and down there, scaled by `low` and by speed over cruise.
  - It acts only when fast: from LOW_SLOW (16 m/s), full by LOW_FAST (0.85 of cruise). A hand landing's approach (5.5 to 12 m/s) and Brake's 13.2 m/s never feel it.
  - It is off under a span and in a tunnel's bore. The study sets `plane.roofed` from `tunnels.tube`.
  - Read-outs: `plane.low` and `plane.low_clear`.
- **The land is real** (`scripts/endless/flight_contact.gd`, new).
  - The plane's move still runs SkyGlide `_skim` (ride, brush, under) and `_water`. In a weighted preset SkyPlane records what it ran into as `contact` (kind, velocity, normal).
  - FlightContact grades each contact against the surface normal. The normal is the ground's slope from `plane_ground` either side for a ride, a brushed face's way out (or the land's slope where it is a cliff), down under an underside, and up on the water.
  - It also grades a wingtip or other body point in the land, a tree crown or a wall while the middle is clear (NearMiss `touching`).
  - **Crash**: into the surface faster than CRASH_INTO (7 m/s) at more than CRASH_ANGLE (0.42 rad, 24°). The study's `crash()` relaunches the plane 45 m back along its way, 14 m over the highest thing from there to 140 m on, at cruise and on the same heading. The screen dips dark and lifts over 0.7 s.
  - **Scrape**: anything shallower. It keeps 0.88 of its speed, less 0.012 per m/s it went in (never under 0.6). SkyPlane `scrape` turns the path off the surface and sets a `bump` out of it of 2.2 m/s plus 0.35 per m/s in, dying over 0.3 s. For 0.45 s after a scrape, another touch can only crash.
  - The unbanked chain is lost on either.
  - Landings: `scripts/manual_landing.gd` gets `land_most`, which the study sets to 16 m/s in the weighted presets and INF in off. A touch of the land no faster than that is graded by the landing as ever. Faster, the landing leaves it to FlightContact. The water ridden slower than 16 m/s is ridden as before.
- **Near-miss detection and scoring** (`scripts/endless/near_miss.gd`, new; its header has the full rules).
  - `measure` uses five body points (nose, tail, belly at SKIM, both lower wingtips) against `plane_ground` and `water_at`. It also casts rays on layer 1: two along each wing, fore and aft, and one up through the roof (reaching 10 spans). Land hit along a wing counts only while the wing points sideways.
  - Channels:
    - ground: the least clearance, scored as a **pull-out** over land or water if it was closing at 3 m/s or more, or as a **graze** over a tree or ruin top under 0.5 spans.
    - stone: the wings and the roof within 1.2 spans, scored as a **graze**, or as a **thread** when both wings are near something (a gap).
    - passage: under something (an arch span, a hall roof, a bore), scored as a **thread** when it comes out.
  - A moment is scored at its turning point: the clearance back up HYST (0.12 spans) or half the least past the least, or out of reach.
  - Score = BASE (pull-out 100, graze 200, thread 300) × (1 + 3k²) × speed/cruise × farm cut. k is 1 minus the least over the reach. Pull-outs also get × (1 + (closing/5)^1.5), at most 6.
  - Bands: razor under 0.15 spans (0.42 m), close under 0.5 spans (1.4 m), else near.
  - **Skim**: under 1 span over land or water, fast, it trickles 8 points/s by closeness. It holds the bank timer but adds no multiplier step.
  - Nothing scores under 0.8 of cruise.
  - Farming: each moment in the last 25 s within 60 m cuts a new one by 1/(1 + 0.6n). The same surface again cuts it × 0.35 (a collider shape, or a 30 m patch of land).
  - After a scrape a channel re-arms only once its clearance is back out of reach, so the moment that scraped never scores.
- **Chain, meter, surge** (near_miss.gd).
  - Each moment adds its points and a multiplier step of 0.5 (at most ×5), and kicks the speed 0.6 to 1.6 m/s by closeness.
  - 3 s with no new moment banks points × multiplier into the meter (4000 points fill it).
  - Holding **surge** spends the meter over 2.5 s (from full). SkyPlane `surge` drives the speed to 1.3 × Boost's (about 60 m/s at endless speed), pulling 2.5 × harder than the throttle. It lifts the speed cap, which falls back at 6 m/s² after.
  - Boost is unchanged.
- **Juice**
  - `scripts/endless/flight_rumble.gd`: a "near" pulse by k, a "scrape" knock by how hard it went in, a "crash" knock, and a "low" buffet hum.
  - `scripts/endless/flight_sound.gd`, new clips, all existing samples:
    - a near miss plays a swish (kit `swish-*`) and a whoosh, louder and higher by k, plus leaves if a tree;
    - a scrape plays a grind (foley `land-grind-*`), plus leaves, a splash or debris by surface;
    - a crash plays a break (foley `mesa-break-*`) and debris (kit `rock-debris-*`).
  - Camera (`studies/endless_flight.gd`): a FOV punch of 6° × k dying over 0.28 s, a shake of 0.006 rad × k (0.012 on a scrape) dying over 0.3 s, and a buffet shake low and fast of 0.0022 rad × low × speed.
  - `scripts/endless/flight_debris.gd` (new, CPU particles): dust, sparks off stone, leaves off a tree, spray off water on a scrape or crash, and a running spray trail under 0.8 spans over water.
  - `scripts/endless/near_miss_hud.gd` (new):
    - the pop: the kind and band in gold, white or mist by band, over "+points", at 20% height, swelling in and rising away over 1.3 s;
    - the chain, low centre, as points ×multiplier over a bar running down to the bank;
    - a note: "banked +N", "SCRAPE · chain lost -N" or "CRASHED";
    - the surge meter under it, labelled with its key.
  - F1's numbers get a near line: clearances, low, chain, meter, total, scrapes, crashes.
- Hook in `studies/endless_flight.gd`: `_near_misses(delta, events)` runs after `hand_landing.step`. It calls measure, then FlightContact `step`, then score, and merges into the frame's `events` before the rumble, sound and HUD read them.

Keys and buttons
- Surge: **B**, or pad **X** (new action `fly_surge` in `scripts/pad.gd`). X was only bound to the cut walker's twirl and eject.
- Everything else is as before. The hint line reads "B surge".

Knobs and where they live
- `scripts/flight_weight.gd` PRESETS:

| knob | off | light | medium | heavy |
|---|---|---|---|---|
| low_spans (zone top, spans) | – | 1.6 | 1.8 | 2.0 |
| settle (m/s at full low) | – | 1.0 | 1.4 | 1.8 |
| settle_pitch (rad hands-off at full low) | – | -0.06 | -0.09 | -0.11 |
| buffet (m/s) | – | 0.35 | 0.5 | 0.65 |

- Also in flight_weight.gd: LOW_FULL, LOW_SLOW, LOW_FAST.
- `flight_contact.gd`: LAND_MOST, CRASH_ANGLE, CRASH_INTO, SCRAPE_KEEP/COST/LEAST, KICK, GRACE.
- `near_miss.gd`: BODY, REACH, STONE_REACH, OVER_SPANS, RAZOR, CLOSE, HYST, BASE, CLOSE_GAIN, PULL_MIN, CLOSING_REF/TOP, SKIM_BAND/RATE, FAST_FROM, FARM_*, CHAIN_STEP/TOP, BANK_AFTER, METER_FULL, SURGE_TIME, KICK.
- `sky_plane.gd`: SURGE_OVER, SURGE_PULL, CAP_FALL, BUMP_FADE, SCRAPE_OUT.
- `endless_flight.gd`: PUNCH*, *_SHAKE, SPRAY_*, CRASH_BACK/UP/LOOK, FADE_TIME.

Measured (throwaway `scratch/nm.gd` through the real loop and the stick, uncommitted; `python tools/drive.py scratch/nm.gd -- --part=<pull|handsoff|skim|chain|graze|crash|land|farm|thread> --scene-args --weight=X`, seed 1, on a flat meadow run found near the spawn)

Pull-outs from a steady 30° dive at cruise (32 m/s, sinking 15 m/s), full back when the body's least clearance reaches h:

| h (m) | light | medium | heavy |
|---|---|---|---|
| 12 | none (7.0 m least) | 157 near (5.6 m) | 584 near (3.6 m) |
| 9 | 677 near (3.8 m) | 1217 near (2.2 m) | scrape |
| 8 | 1035 near (2.8 m) | 1861 close (1.0 m) | scrape |
| 7 | 1618 near (1.6 m) | scrape (6°) | scrape (22°) |
| 6 | 2260 close (0.5 m) | scrape (18°) | crash |
| 5.5 | scrape (4°) | scrape (20°) | crash |
| 4.5 | scrape (18°) | crash | crash |
| 3.5 | scrape (23°) | crash | crash |

- The latest pull that comes clean: light 6 m, medium 8 m, heavy 12 m. The latest that only scrapes: light under 3.5 m, medium 5.5 m, heavy 7 m.
- A gentle 8° glide (sinking 4 to 5 m/s), medium: pulled at 3 m it scores 387 (2.0 m least), at 2 m 607 (0.8 m), at 1.5 m 762 razor (0.13 m). The 30° dive saved at 1.0 m scores 1861.

| | light | medium | heavy |
|---|---|---|---|
| hands-off, level at cruise, belly 2 m up: s to a scrape | 1.45 | 1.15 | 1.0 |
| the same from 4 m | 3.9 | 2.6 | 2.05 |
| the same from 5 m | 12.6 | 4.4 | 3.0 |
| from 8 m (over the zone) | never (settles 1.1 m, holds) | never | never |
| hands-off at 60 m, height change over 3 s | 0.0 m | 0.0 m | 0.0 m |

Medium, the rest:
- Steady meadow skim, the belly held about 0.8 m up for 8 s by small stick corrections: 5.6 points/s, 0 moments, 0 scrapes.
- Graze along a tree's crown, level at cruise. At 2.6 m it scored 228 near, at 1.12 m 465 close. The next trees in its row scored 131 and 34 after the farm cut. Aimed 0.6 m off, the wingtip went into the crown: a scrape.
- Thread, `--world=overgrown --tunnel-test`, flown out of the bore hands-off from 120 m inside mouth B: thread 300 (the bore is roomy, k 0). Under a 40 m rock arch the drive's straight line ran into the rock and scraped, and no tighter arch was found near seed 1, so an arch thread was not driven.
- Chain:
  - one pull-out (1863 points) banked after 3.15 s clean, filling the meter to 0.466;
  - the same then nosed into the land lost its 1866 unbanked points;
  - the surge from a 0.5 meter, already at Boost's 45.5 m/s, reached 59.6 m/s and spent the meter in 1.25 s, then eased back to 30.1 m/s at cruise 4 s after.
- Farming, the same pull-out at the same spot three times: 1861, 407, 296.
- Crash, a 45° dive into the flat: crash at 42° and 22 m/s in. It respawned 44.6 m back, 14.2 m over the ground, at 29.4 m/s.
- Hand landing on the flat (flaps, braked, 14 m up and 120 m out, tracking a sink): greaser at 5.78 m/s and 0.67 m/s sink, 0 scrapes. The weight round's landing drive gives greasers in every preset (light 5.76 / 0.67, medium 6.26 / 0.93 when run after its other parts, 5.77 / 0.67 alone, heavy 5.78 / 0.67).
- Off (`scratch/nm_offdigest.gd`, a fixed stick script hashing the path, and the weight round's `scratch/weight.gd`) gives the same hash and the same numbers before and after the change.

Proof
- Smoke: endless_flight PASS by default (medium), with `--weight=off`, and with `--weight=heavy --sound=on`. flight_study PASS.
- Rendered (`scratch/nm_cap.gd --rendered`, stills in `scratch/nm_cap/`): the medium pull-out from 8 m. The pop reads "PULL-OUT · close +1,861" in clear sky over the horizon, the chain "1,863 ×1.0" sits low under the plane with its bar, and the gold meter shows after the bank. The FOV went 77.1 to 81.7 at the moment. The HUD's fonts were enlarged once after the first look (46 / 32 / 30 px).

Not verified
- The feel in the hand: the zone's depth and settle, whether holding a low line by hand is fun or fiddly, the buffet, and whether a 24° crash angle is fair. The user judges by playing.
- The rumble felt on a real pad, and the new sounds by ear. Gains are first guesses on the bus levels the sound round set.
- Particles look: only CPU emitters ran headless. They were not seen in the rendered stills (none fired in that pass).
- An arch thread, a gap thread between two trunks, and a thread under a hall roof were not driven. The tunnel exit was.
- Hands-off in a long bend of a tunnel the plane drifts and its wingtip scrapes the wall (the guide steers the heading, not the bank). Off and before, the wall only brushed it.
- Flying low over forest: the crown "ground" makes grazes under 0.5 spans frequent if the user skims a canopy. The farm cut damps it, but this was not tuned.
- The mouse pitches directly, so a mouse flyer holds a low line more easily than the stick.

Tests this breaks
- None found. A targeted headless run: `test_knife_drift`, `test_flight_study`, `test_flight_metrics` and `test_world_scale_guard` pass.
- `test_sky_plane` and `test_glide_camera` still stop at the removed scarf (`_scarf_points`), as before this round. A bare SkyPlane is `off`, so its low zone, contact and surge never run there.
