# Water contact: the cushion, spray, the wake's marks, the wet screen

Prototype round. No committed tests.

## How to play it

```
.\run-endless-flight.cmd --water-near-start
```

The plane starts 3 m over the sea, 260 m out from the nearest river mouth (within 4 km of the start), heading for it. Hands-off, it eases down onto the water's cushion and holds there. Push the nose down a little to skim lower, push harder to touch, and bank hard while pushing to dip a wingtip. Follow the river up from its mouth to try a river. Ponds behave the same way. F1 shows a `water:` line with the clearance, closeness, spray, wingtips, lift, drag, shudder, marks and drops.

`--water-contact=0` turns the whole round off. The old CPU spray trail and the sea's buffer wake foam come back.

## What changed

- `scripts/endless/water_contact.gd` (new). Under 1 wingspan of belly clearance over water (sea, river or pond), fast:
  - **Cushion** (`feel`, before the plane steps). From the top of the reach down to the ride (0.32 spans), it takes away the low zone's settling for each preset (`settle`, `settle_pitch` and `low`). So hands-off the plane eases onto the same ride in light, medium and heavy. Under the ride it pushes back up, up to 5 m/s at the surface. It also soaks up half of any sink. The cushion drags 1.8 m/s² × closeness² and shudders: ±0.45 m/s of motion, plus the drawn plane's roll (0.035 rad) and pitch (0.015 rad), × closeness^1.5. It only acts at speed (from FlightWeight `LOW_SLOW` 16 m/s to 0.85 of cruise), so slow flight and the landing approach are untouched. Nothing changes over land.
  - **Spray.** GPU particles with their own process shader (`shaders/water_spray_process.gdshader`) and draw shader (`shaders/water_spray.gdshader`):
    - a narrow, tall rooster tail of fine streaked drops behind the tail (1800);
    - two fans of drops out from under the wings (1400);
    - a white spume of mist (700);
    - a jet from each wingtip under 1 m over the water (260 each);
    - three splash pairs (360 drops and 140 mist) for scrapes and crashes.
    
    The amount is `spray` = closeness^1.3 × the speed's share. Lower means a higher, denser and harder throw. Drops die under the water they came from, and all of it spawns on the real surface under the plane (the sea's CPU swell, or the river or pond level). The mist fades near the eye, so the chase camera isn't filled white.
  - **Marks** on the water (`shaders/water_mark.gdshader`), one MultiMesh of 160 slots:
    - foam patches every 2.4 m under the tail, plus two drifting arms when lower than 0.7 spans. They spread ×3.2 and thin into lace over 4 s.
    - ripple rings (1.7 s, up to 6 m across) off a wingtip under 1 m and the belly over 0.72 closeness, and three per splash.
  - **Touching the water is unchanged.** It's still FlightContact's call: over 16 m/s it scrapes and bounces off, steep and fast it crashes. It now throws a big splash with rings, douses the screen if the camera is within 14 m, plays a splash and sends a "splash" knock to the rumble. A wingtip in the water still never counts as a touch (NearMiss `touching` skips water), so a dipped wingtip only sprays.
  - **Screen.** The chase camera inside the plume gets wet (1.1 a second at full spray, by how deep in the plume it is). `douse(amount)` is the one call: the study's `wet(amount)` forwards to it. It lays drops and plays a toss above 0.2, and briefly muffles the air.
  - **Sound:**
    - a spray hiss made at start (1.5 s of bright noise with a crackle, looped), 0.32 at full spray;
    - a churn under it (foley `water-swirl-loop`, pitched up, from 0.35 spray);
    - `water-pop` when a wingtip first touches;
    - `water-toss` on a dousing;
    - `water-splash` on a splash.
  - `--water-near-start`: `near_start(field, from)` scans rings out from the start for river water within 5 m of sea level, then for open sea within 480 m of it.
- `scripts/endless/screen_wet.gd` (new), with `shaders/screen_drops.gdshader` and `shaders/screen_sheet.gdshader`. Drops on the lens, up to 220, each a little lens drawn from the screen: flipped, darker at the rim, with a highlight. Drops over 7 px run with the airflow, out from the point the plane heads toward and a little down, in stops and starts. Running drops leave beads. Drops dry at 0.8 px/s (faster at speed). A dousing over 0.25 also lays a sheet that bends and blurs the view and clears over 0.45 s. The layer is hidden while the screen is dry.
- `scripts/sky_plane.gd`: `cushion` (m/s up) and `cushion_drag` (m/s²), set from outside each frame and added to the vertical velocity and the speed. 0 by default, so a bare SkyPlane and the flight study don't change.
- `scripts/endless/flight_rumble.gd`: a `spray` hum (weak 0.34, strong 0.26 × spray², fluttering) and a `splash` knock.
- `scripts/endless/flight_sound.gd`: `muffle` (0 to 1) closes the air's low-pass down to 0.12 of itself.
- `scripts/endless/endless_sea.gd`: `wake_foam`, a multiplier on the wake foam laid into the foam buffer. Water contact sets it to 0, because its own marks replace that churn. The sea shader's V-shaped wake is untouched.
- `studies/endless_flight.gd`, small hooks: the flag and the menu skip, `water.feel` after `plane.water` is set, `water.step` after the near misses, the figure's shudder, the rumble's `spray`, water splashes in place of the debris puff on a water scrape or crash, the old `debris.spray` trail only with `--water-contact=0`, `wet(amount)`, and the F1 line.
- **Near miss:** skimming water already fed the chain exactly as land does (NearMiss `ground_clear` takes the water, and the skim trickle and pull-outs count `water`). Nothing was changed there.

## Numbers

Throwaway `scratch/water_skim.gd` through the real loop and stick, seed 1, `--water-near-start`, swept over `--weight=`:

| | light | medium | heavy | off |
|---|---|---|---|---|
| hands-off over the sea: belly clearance after 1 s (m) | 0.90–1.90, settles about 1.3 | 0.86–1.87, about 1.3 | 0.87–1.85, about 1.3 | 1.46–2.61 |
| scrapes hands-off | 0 | 0 | 0 | 0 |
| 20% nose-down for 2 s: least clearance (m) / scrapes | 0.14 / 0 | 0.20 / 0 | 0.32 / 0 | 0.05 / 0 |
| 60% nose-down for 2 s: scrapes | 2 | 2 | 2 | 0 (off never grades) |
| river, placed 0.4 / 1.2 / 2.4 m: least (m) | 0.53 / 1.26 / 2.15 | 0.57 / 1.29 / 2.03 | 0.57 / 1.30 / 1.98 | 0.48 / 1.22 / 2.42 |

Held at a clearance over the sea (medium; the other presets differ only in the lift, which cancels their own settle):

| belly clearance (m) | lift (m/s) | drag (m/s²) | shudder (0–1) | spray (0–1) |
|---|---|---|---|---|
| 0.42 | 5.9 | 1.39 | 0.82 | 0.81 |
| 0.93 | 4.0 | 0.84 | 0.56 | 0.59 |
| 1.47 | 3.0 | 0.42 | 0.34 | 0.38 |
| 2.06 | 1.1 | 0.13 | 0.14 | 0.18 |
| 2.8 | 0 | 0 | 0 | 0 |

- Out of the water at 40 m: no emitter runs, and lift and spray are 0. `wet(1)` lays 90 drops, and the screen is dry within 10 s.
- With the stick pushed into a full bank, the low wingtip reaches the water: tip spray at 1.0 (`bank_tip_most`). At the ride, a hands-off bank keeps both tips over 1 m.
- Cost (Windows, RTX 4070 SUPER, 2560×1440, `--uncapped`, median of 5 × 60 frames; throwaway `scratch/water_perf.gd`):
  - GPU low over the sea at spray about 0.3: 8.1 / 8.0 ms against 7.6 / 7.5 ms with `--water-contact=0`, so +0.5 ms.
  - At spray about 1.0, splashes and a wet screen included: 8.66 against 7.65 / 7.91, so +0.8 to 1.0 ms.
  - At 60 m: 9.28 against 9.30 ms, no cost. Just after a dousing, the drops' screen copy adds about 0.2 ms until they dry.
  - Script CPU (headless): 0.24 ms a frame low, 0.04 ms high. The marks went from 0.44 to 0.12 ms by moving from Dictionaries to packed slots and one buffer write.

## Proof

- Headless import. `tools/smoke.py studies/endless_flight.tscn` PASS, 0 errors, by default, with `--water-near-start`, with `--water-near-start --sound=on`, with `--water-contact=0`, and with `--weight=off`.
- Through the real loop: `scratch/water_skim.gd`, the table above. No crash, no stuck state; it is still flying after every pass.
- Rendered stills (git-ignored, `captures/water_contact/`):
  - chase views: `sea_ride`, `sea_low`, `sea_lowest`, `sea_bank`, `sea_skim`, `river_low`;
  - side and behind: `side_low`, `back_low`, `back_bank`;
  - the drops over time: `drops_0`, `drops_20`, `drops_80`, `drops_260`.
  
  The driver is `scratch/water_cap.gd` (`python tools/drive.py --rendered scratch/water_cap.gd -- --scene-args --water-near-start`). I iterated on the look five times. The spray first read as white sticks on a cream carpet. Now it is thin bright threads in a continuous white spume plume, from the side and behind, with lacy cool foam under it.
- Tests run on their own (not the suite): `test_world_scale_guard`, `test_knife_drift` and `test_sky_plane` pass.

## What to judge by hand

- **The cushion's feel.** Hands-off it bobs about ±0.5 m round 1.3 m before settling (the weighted path's lag against the cushion). This could feel floaty or alive. Knobs: `RIDE`, `HARD`, `DAMP` in water_contact.gd.
- **The water as a highway.** Over water, hands-off no longer sinks into a scrape the way it does over land. The risk is in going lower for more spray and points. Is that right?
- Drag (1.8 m/s² at the surface) and whether the shudder reads at all on screen. The camera shake stays off (the pace round's choice). The shudder is in the plane's motion, the drawn plane, the rumble and the hiss.
- **The look in motion.** Only stills were judged. Check the spray's colour in other moods (warm sun makes it cream), and how often the screen gets wet at the ride (about 10 drops) and very low (50+).
- Sound by ear. The hiss is generated noise, never listened to; the gains are first guesses. Also the muffle on a dousing.
- The rumble on a real pad: the spray hum and the splash knock.

## Not verified

- GPU-only parts in motion: particle flow, the marks' fade and the drops running. Stills only.
- Metal (the Mac): GPU particles with a custom process shader, and the screen texture in canvas shaders. Untried.
- Pond spray: it runs the same code (kind `pond`), but no capture was taken over a pond.
- The FFT sea's heave isn't on the CPU (up to about 0.5 m), so spray and marks sit on the Gerstner swell. The marks are lifted 0.15 m over the sea.

## Weak spots

- The tan blocky squares on the shallow sea are the sea's depth colour at its coarse depth-map texels, not the wake. They were there before.
- The mist can still show a puff or two at the tail end of a long trail.
- Water at a river mouth that sits under sea level reads as sea.

## Tests this breaks

None known. Nothing in the suite references the new files. SkyPlane's new fields default to 0, and FlightSound's `muffle` to 0. The full suite was not run.

## Models

No models made or changed, so the geometry tricks in `docs/art/model-budget.md` don't apply.

## For waterfalls later

Call `study.wet(amount)` (0 to 1) when the camera passes through falling water. `WaterContact.splash(at, k)` throws a splash anywhere on the water. The process shader takes any emitter frame (`ahead`, `right`, speeds, sizes), so a fall's curtain can reuse it.
