# Flight sound: engine, air, whoosh, wheels, ambience

What changed
- `scripts/endless/flight_sound.gd` (new, a Node) ports the plane and open-air part of the kit isle's soundscape (`git show archive/before-the-cut:scripts/kit_isle/kit_audio.gd`). Left out: the walker, rope, beasts, boarding, flaps and roll creaks, the cloud sea's hush, leaves, rain, owls and the living layer (birds, frogs).
- The sounds, all from `assets/audio/kit/` and `assets/audio/`:
  - Engine: `engine-loop` by throttle and speed (Boost lifts gain and pitch); `engine-start` when the engine comes on while on the wheels. The game starts in the air and never switches the engine off, so the start is dormant until something does.
  - Air: `air-rush-loop`, `air-whistle-loop`, `air-howl-loop` on the "SFX Air" bus, whose low-pass opens with speed. Speed is read as a share of the plane's cruise (`AIR_SPEED` 0.3 to 1.85 cruises: cruise is 0.45, Boost 0.75). A dive, a hard pull (the flight path's turn rate, the vapour's own 0.7 to 1.5 rad/s) and Boost add to the rush and whistle. `wire-sing-loop` rises with the knife edge, a drift and a pull.
  - Whoosh: `whoosh-1..4`, panned to the nearer side. A ring of 8 ray probes (3 a frame) on physics layer 1 (the land, arches, halls, trees, tunnels). Reach is the larger of 3.2 wingspans and 0.45 s of flight (13 m at cruise, 21 m at Boost). `near` rising through 0.4 fires one, 0.7 s apart, over 9 m/s. Stone on several sides raises `enclosed` (the howl); the ray straight down counts 0.7 (skimming the land is gentler than a cliff).
  - Wheels, from the landing's events dict (the one `flight_rumble.gd` reads): `thump-1..3` on `settled` by its `k` (gain 0.22 to 0.6, lower pitch when harder), a quieter high tap on `greaser`, a louder one on `bounce` by its sink, the hardest on `hit`; `creak` under a hard one and on `slide`. `wheel-rumble-loop` by ground speed (full at 12 m/s), `skid-loop` by the landing's `grit` (floor 0.4 while `sliding`).
  - Ambience: `wind-bed` breeze grows with height over the ground (2 to 120 m), `thin-wind-loop` with height over the sea (50 m to the ceiling), `shore-bed` near the sea (15 land samples in rings of 0, 50 and 130 m every 0.4 s; water on some sides is a coast, all round an open sea 0.45 of that; fades out by 130 m up).
- Buses (`FlightSound.ensure_buses`): Master > SFX > SFX Air, Master > Ambience, a hard limiter on Master, the Genesis bus from `genesis_audio.gd`. Volumes are `user://sound.cfg`'s `sound` (SFX) and `ambience` (default 0.8), master and mute `genesis_audio.gd`'s (`FlightSound.load_settings`, `apply_settings`).
- Windowed only. Headless there are no buses, no players, and the window-close hook is off, but every layer's goal, gain and pitch still run (`layers()`). `--sound=0` is silent, `--sound=on` plays headless too (a proof's). A window close stops every player and quits three frames later, as the kit's audio did (the exit leak).

Hook in `studies/endless_flight.gd` (4 lines)
```
const FlightSound = preload("res://scripts/endless/flight_sound.gd")      # next to FlightRumble
var sound := FlightSound.new()                                            # next to rumble
	add_child(sound)                                                      # in _ready, after Pad.note
	sound.step(delta,self,events,float(input.get("boost",0.0)))           # in tick, after _rumble(...)
```
It reads `plane`, `hand_landing`, `ground_scale` and `field` off the study and its physics world; nothing is changed.

Knobs (consts at the top of `flight_sound.gd`)
- Speed and air: `AIR_SPEED`, `RUSH`, `RUSH_NEAR/DIVE/PULL/BOOST`, `RUSH_CUT*`, `WHISTLE*`, `HOWL`, `PULL_TURN`, `DIVE_SINK`.
- Whoosh: `WHOOSH_AT/GAIN/GAP/SPEED`, `PROBE_SPANS/LEAD/RAYS/DOWN/MASK`.
- Engine: `ENGINE*`, `WIRES`. Wheels: `RUMBLE`, `SKID`, `RUMBLE_FULL`, `THUMP`, `THUMP_PITCH`, `TAP`, `HOP`, `HIT`.
- Ambience: `BREEZE`, `BREEZE_HEIGHT`, `THIN`, `THIN_HEIGHT`, `SHORE`, `SURF`, `SHORE_HEIGHT`, `PLACE_RINGS`.

Gain table (linear, on SFX / Ambience; the buses' volumes then apply)

| layer | bus | full | cruise | Boost | dive (0.65) | hard turn | stopped | rolling 11 m/s |
|---|---|---|---|---|---|---|---|---|
| engine | SFX | 0.165 | 0.099 | 0.156 | 0.097 | 0.098 | 0.062 | 0.136 |
| rush | Air | 0.3 + near 0.16 + dive 0.12 + pull 0.05 + boost 0.04 | 0.102 | 0.226 | 0.176 | 0.26 | 0 | 0.03 |
| whistle | Air | 0.07 + near 0.06 + pull 0.05 + dive 0.05 | 0.001 | 0.042 | 0.028 | 0.036 | 0 | 0 |
| howl | Air | 0.17 enclosed + 0.04 near | 0 | 0 | 0 | 0.17 (in the hills) | 0 | 0 |
| wires | SFX | 0.07 | 0 | 0 | 0.031 | 0.03 | 0 | 0 |
| rumble | SFX | 0.2 | 0 | 0 | 0 | 0 | 0.007 | 0.196 |
| skid | SFX | 0.16 | 0 | 0 | 0 | 0 | 0.005 | 0 (0.019 on touch) |
| breeze | Ambience | 0.03 ground, 0.08 up | 0.04 | 0.04 | 0.05 | 0.04 | 0.03 | 0.03 |
| thin | Ambience | 0.07 | 0 to 0.03 by height | | | | 0 | 0 |
| shore | Ambience | 0.14 | 0.13 over a coast at 30 m up | | | | 0.003 | 0.016 |
| whoosh shot | Air | 0.22 x (0.6 to 1) | 0.17 | | | | | |
| thump shot | SFX | 0.22 to 0.6; tap 0.12; hop 0.3 to 0.7; hit 0.5 | | | | | | |

The "full" column is the sum of the terms; the others are the eased gains read in the drive below.

Proof
- Smoke: `endless_flight` PASS, also with `--sound=on` (players, buses and the close hook run on the dummy audio driver).
- Throwaway drives (`scratch/drive_sound.gd`, `drive_pass.gd`, `drive_shore.gd`, uncommitted) through the real loop and the real input actions, printing every layer's gain and pitch:
  - Stopped: engine idles at 0.062, pitch 0.63; rumble and skid fall to nothing.
  - Rolling: touchdown (a greaser) fires the tap (gain 0.12, pitch 1.2); rumble 0.11 at 7 m/s, 0.196 at 11; engine 0.136 with Boost.
  - Cruise 29.4 m/s: rush 0.10 at pitch 0.99, engine 0.099 at pitch 1.04. Boost 42.8 m/s: rush 0.23, whistle 0.04, engine 0.156 at pitch 1.31.
  - A dive (sink 0.65): rush 0.176 against 0.102. A hard turn: pull 0.7, rush 0.26, wires 0.03.
  - A pass by an arch at cruise: the whoosh fired with the nearest stone at 8.9 m (gain 0.17); passes along the hills fired at 3 to 9 m. `near` reached 0.8 to 1.0 and `enclosed` 1.0 in a gap, so the howl came up to 0.2.
  - Over a coast at 30 m: water share 0.53 to 0.2, shore goal 0.14 to 0.09.
- Note for drivers: `hold(&"fly_boost")` and `hold(&"fly_lean_right")` are not released by `let_go()`; release them with `hold(action, false)`.

Not verified
- The mix by ear: nobody could listen. Levels are the old kit's gains (the plane ran at 16 m/s then and cruises at 29 here, so speed-driven layers were remapped to a share of cruise, not retuned). Check the engine against the rush at Boost, the howl in gaps, and whether the whoosh over the hills comes too often.
- The sound in a real windowed audio device: buses and players ran on the dummy driver only.
- The thump on a hop and `hit` by ear (the driven hops are a dive into the land).
- Only the greaser's tap and a hop's thump were driven; a hard `settled` thump and `slide` use the same call.
- `engine-start` (dormant, above) and the shore over open sea at height.

Tests this breaks
- None known; the suite was not run. No test was added (prototype round).
