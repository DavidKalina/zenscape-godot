# Genesis sound

Phase 3, slice 6 (`feature/genesis-sound`). The world answers the hand in sound: each stroke has its own voice, the land's beds follow what exists, and arrivals and moments get a few quiet one-shots.

- `scripts/genesis_audio.gd` (`GenesisAudio`, built by `studies/fidelity_life.gd` after LandLife): the stroke voices, creation beds, one-shots, buses and saved settings.
- `scripts/sound_settings.gd`: the Sound controls in the Settings dialog.
- `studies/nature_audio.gd`: the existing Nature voices, now gated by presence on blank worlds.
- `tools/generate_nature_audio.py --genesis`: bakes every new sound.
- `tools/probe_genesis_audio.gd`: the headless wiring probe.

## What plays when

### Stroke voices

Each voice is one looping player that is always loaded. Its gain eases toward a target: in at `ATTACK` (7/s, about 140 ms) and out at `RELEASE` (2.5/s, about 400 ms). Fast dabs only move the target, so they never stack or click. A silent voice is paused.

| Brush | Voice | Follows | Peak gain |
|---|---|---|---|
| Land (and craft raise, lower, flatten, smooth) | `genesis-rumble`: body under 160 Hz, 31/43/57 Hz subs, soil grit | rise rate, as the tremor reads it (`StrokeFeedback.RUMBLE_FULL_RATE`), times the brush's rumble (`BRUSH_FEEL`, `RUMBLE_MODE`); pitch 0.85–1.1 with the rate | 0.55 |
| Mountain click | `genesis-thump`: falling boom, dull hit, rumbling tail | one per click, at most every 0.3 s | 0.5 |
| Water, brush down | `genesis-pour`: bright rush and a froth of small bubbles | brush speed (floor 0.3 when held still) | 0.3 |
| Water, settling on the worker | the pour at 35% | `editor.water_settling` | 0.1 |
| Water, ponds rising | `genesis-fill`: deep glugs over a low slosh | the pour's pond births (`GardenView.water_births`, `WaterBrush.FILL_SECONDS`) on the emergence clock; pitch 0.9 → 1.12 as the water rises | 0.26 |
| Water, streams running | `stream-bed` (existing) | the pour's stream-front windows | 0.18 |
| Forest | `leaf-rustle-bed`: airy band, leaf flutter, slow rush | `atmosphere.swell` / the forest swell, so it rises and settles with the trees | 0.3 |
| Meadow (and craft growth tools) | `genesis-meadow`: soft swish, odd stem tick | brush speed | 0.16 |
| Path | `genesis-path`: gravel crunch over a dry scuff | brush speed | 0.2 |

The held world rumble (`scripts/world_rumble.gd`, regeneration and long world changes) also plays `genesis-rumble`: up to 85% of its peak, deeper (pitch 0.78–0.95), swelling with the camera rumble, and through a paused world clock. See `stroke-feel.md`, Rumble and pour.

Voices sit at the brush (the pour's glugs at the pour's middle). Attenuation is off and panning is gentle (`panning_strength` 0.6), so they are heard at the level set here wherever the camera is.

### Creation beds

These run on blank worlds only, the Genesis plain and generated worlds, while LandLife is active. Every `BED_TICK` (0.5 s) they read LandLife's last survey: tree and shrub counts, damp cells, water area and the tree grid. Nothing scans the world for sound. Gains ease at `BED_RESPONSE` (0.6/s).

- **Leaves rustle** (`leaf-rustle-bed`, peak 0.15): from the nearest wooded metre (the survey's 1 m tree grid, thinned to 160 points). The gain is woods (trees / 12) × wind (air plus swell) × camera proximity × (1 − 0.4 rain). Proximity is 1 within 30 m and falls to 0.2 at 90 m; the creation camera usually sits about 50 m from the woods.
- **Open-ground wind** (`plain-air-bed`, peak 0.1): a low, slow wind with a faint drifting whistle. It is loudest on a bare plain and falls to 20% as life comes (trees / 10 + shrubs / 30 + water m² / 10). It swells with the wind and halves in rain.
- **Nature's voices, gated** (`nature_audio.gd`; the Fidelity world is untouched):
  - Birdsong, owl and raven chances fire only with probability `song_presence` = trees / 8 + shrubs / 40 + arrived birds / 4, × (1 − 0.85 rain). Songs come from the woods, not from around the listener. A bare plain has no birdsong.
  - Crickets at night: × `cricket_presence` = 0.15 + shrubs / 25 + trees / 15 + damp cells / 80.
  - Frogs at the shore at night or in rain: × `frog_presence`, which is 1 once frogs have arrived, 0.35 with frogspawn only, and 0 otherwise.
  - Water lapping (shore bed), stream beds, rain and the ambient wind are Nature's and ambient audio's own beds. They already follow the drawn ponds, streams and weather.

### Arrivals and moments

One-shots come from a pool of four 3D players that fall off with distance (`unit_size` 10). When every player is busy, a sound is dropped.

| Event | Sound | Gain | Limits |
|---|---|---|---|
| Fish arrives | `fish-plop-1/2`: one bubble, a little splash, a droplet | 0.16 | 6 s per kind |
| Frog arrives | `frog-croak`: two short buzzy pulses | 0.12 | 8 s per kind |
| Frogspawn, birds, fireflies | nothing (the beds carry them) | | |
| Heron moment | `heron-call`: a rough, falling "fraank", 1.5 s after it sets off | 0.2 | |
| Deer moment | four soft `footstep-*` steps at pitch 1.2–1.35 | 0.1 | |
| Rainbow | `bow-swell`: an open G–D chord breathing in over 2.5 s and away over 4.5 s | 0.08 | |
| Bigfoot's howl (his trail, `docs/scenic/life.md`) | `far-howl`: a long low "whooo" rising and falling over 4 s, 16 m beyond the elder stand, on the far bus; the wood hushes 20 s | 0.3 | 420 s |
| Bigfoot's knocks (his trail) | two or three `wood-knock`s, 0.7-1.2 s apart, 4 m into the elder stand, on the far bus; the wood hushes 20 s | 0.22 | 300 s |
| Bigfoot | the birds hush for 50 s (songs off, crickets down 70%), and 60% of the time two wood knocks, 0.8 s apart, 3–6 s after he shows, 8 m further into the wood, on the far bus | 0.22 | he is rare already |

Any two arrival sounds are at least `SHOT_GAP` (1.5 s) apart. For `SHOT_QUIET` (12 s) after a new world, load or undo there are none, because a settled world's life lands in a burst.

## Tool sound

The shaping tools (Modeller, Paddle, Chisel, Hammer, Wire) and the linen HUD have their own sound. It lives in `scripts/clay_sound.gd` (`ClaySound`), which `studies/fidelity_life.gd` builds next to GenesisAudio when the clay is on (`--modeless`). These sounds are recorded foley, not synthesised: CC0 recordings from Freesound and Kenney, cut by `tools/foley/make_foley.py` into `assets/audio/foley/`. Each file is credited in `assets/audio/foley/SOURCES.tsv`. The one exception is the land voice (below), which is synthesised.

**Cues** are one-shots, asked for by name:
- The tools call `LandClay.sound(cue, at, strength)`, which emits `sounded`.
- The HUD calls the static `ClaySound.cue(name)`.

Each cue has up to eight takes (`<clip>-<n>.wav`). The same take never plays twice running. Each play is nudged by ±5% in pitch and ±1.5 dB in level, and a stronger moment plays louder and slightly lower. A cue with no takes on disk is silent.

| Moment | Cue | Clip |
|---|---|---|
| Modeller poke (tap) | `poke` | `poke` |
| Groove breaks through the rim | `notch` | `crumble` |
| Paddle pat (tap) | `pat` | `pat` |
| Chisel shelf steps down a level | `chisel_step` | `chisel-tick` |
| Chisel notch (tap) | `chisel_knock` | `chisel-knock` |
| Chisel mesa breaks free (the lift passes `FLAT_FROM`) | `mesa_break` | `mesa-break` |
| Chisel shelf let go, and the Wire's cut landing | `crumble` | `crumble` |
| Hammer blow on rock / elsewhere | `crack` / `knock` | `hammer-rock` / `hammer-soil` |
| Scree from a crack | `scree` | `scree` |
| Rock painted on a raised peak | `rock_settle` | `pebbles` |
| Trees slide off (`shake_trees` moved any) | `trees` | `trees` |
| Wire's cut sets off | `wire_start` | `wire-start` |
| Land lurches as a hold lifts it (see Land voice) | `lurch` | `land-lurch` |
| The Wire's cut and slice grind (see Land voice) | `grind` | `land-grind` |
| Roll or tray reached for; slot hovered | `ui_reach`; `ui_hover` | `ui-cloth`; `ui-tick` |
| Tool picked; size pip changed | `ui_pick`; `ui_size` | `ui-pick`; `ui-tick` |
| Material taken; put back | `ui_take`; `ui_put` | `ui-take`; `ui-put` |
| A slot not found yet | `ui_refuse` | `ui-refuse` |
| Foot: undo; photo | `ui_undo`; `ui_shutter` | `ui-undo`; `ui-shutter` |
| Almanac page opened | `ui_page` | `ui-page` |

**Voices** are loops whose gain eases toward a target (in at `ATTACK` 9/s, out at `RELEASE` 3.5/s):
- **Drags:** the Modeller's groove and rub crossfade by `LandClay.rub`. The palm and the Paddle use the sweep, and the Chisel uses the scrape. All of these follow the pointer's speed (`SPEED`, 40–900 px/s).
- **Holds:** the pinch, swell and slice stretch. The Chisel's mesa scrapes. These follow how fast the lift moves (`LIFT_RATE`). A raise also brings in the land bed, deeper when it is slow.
- **Wire:** the cut loop and the grind bed follow how fast its head runs. The Wire never brings in the deep land bed.

**Land voice.** Building mountains and ravines answers with a rumble in lurches, after the Electron ZenScape's formation rumble (`audio.js` `rumble`). It plays in step with the camera's shudder (`scripts/clay_tremor.gd`), but each is driven from the clay on its own; neither calls the other.
- **Bed:** `land-bed-loop` is the RUMBLE voice (peak 0.38). It has a body under 180 Hz, a 430 Hz grind band, a faint drifting 41 Hz sub and soil grains, so it carries on laptop speakers. The old `genesis-rumble` put about 95% of its energy under 150 Hz and was nearly silent there; GenesisAudio and the world rumble still use it.
- **Lurches:** while a hold's lift is above zero and rising (any tool but the Hammer and the Wire), `_tremble` fires `lurch` one-shots. They start at 0.4 m/s of rise and are at their most at 6 m/s (`LURCH_RISE`), at 1.4 to 4.5 a second (`LURCH_PACE`), each interval randomised. A faster, taller pull lurches louder and a little lower. At most four sound at once (`LURCH_STACK`). A still hold, a creep or a sink never lurches. When idle, the beat waits just short of firing (`FIRST_LURCH`), so land that starts moving gives almost at once.
- **Ravine:** the Wire's running cut and its slice drive the GRIND voice (`land-grind-loop`, peak 0.24) and `grind` one-shots at 2 to 6 a second (`GRIND_PACE`), at most three at once (`GRIND_STACK`). There is no sub: it is grit dragged through clay, mostly 400 Hz to 3 kHz.
- **Cues:** `lurch` and `grind` use the takes machinery above, with a wider pitch spread (±10% and ±8%, the cue's `jitter` key). The land player pool is eight (`LAND_POOL`).
- **Takes:** six of each. The lurches (1.3 to 2.4 s) are a sub falling from 58–72 Hz to 31 Hz, noise through a lowpass falling from 460–640 Hz to 70 Hz, crackle early and a thinning trickle of stones. Takes 4 and 6 stack a second, smaller lurch. The grinds (0.45 to 0.8 s) are a lowpass falling from 1100 to 260 Hz over a 540–880 Hz band with dense high grit.
- **Not yet tuned by ear:** the lurch level against the bed, and whether 4.5 a second at full speed is too busy.

The Feather has no cue of its own, because the wind tool's own wind bed (`scripts/wind_gust.gd`) already answers it.

GenesisAudio leaves the clay's strokes alone (`LandClay.stroking`). Before this change, the editor's last brush voice, usually the rumble, played during clay drags at a level unrelated to the tool.

**Re-cutting the foley.**
1. Fetch sources with `tools/foley/fs_search.py "<query>" --into /tmp/zs-foley/fs/<dir>`. It takes only CC0 results.
2. Cut them with `tools/foley/make_foley.py candidates`.
3. Audition the takes on `/tmp/zs-foley/cand/index.html`.
4. List the chosen take numbers per clip in `tools/foley/picks.json`.
5. Run `tools/foley/make_foley.py build`.

## Mix

- **Buses:** `Master` ← `Genesis` (the Sound volume, default 0.8, with a hard limiter at −1.5 dB) ← `GenesisFar`. `GenesisFar` has a low-pass at 1.6 kHz and a wide reverb (room 0.9, wet 0.45, dry 0.6, 60 ms predelay), and only the knock uses it. Nature and thunder stay on Master under their own toggles and sliders.
- **Levels** (before the Sound volume): the rumble is the loudest thing, at about −5 dB, and only during a fast rise. The other stroke voices sit at −10 to −16 dB, the beds at −16 to −20 dB, and the one-shots at −13 to −22 dB.
- **Settings:** World > Sound, or Settings in the main menu, holds Mute all sound, Master, and Sound (painting, creatures and the land's beds), next to the existing Nature sounds and Thunder. They are kept in `user://sound.cfg`.

## Sources

The god hand's finger snap (`finger-snap-1..3`, `scripts/snap_sound.gd`, played on the Genesis bus when a click in the sky snaps day and night) is synthesised by `tools/generate_nature_audio.py --snap`; `docs/scenic/modeless.md` "Void slice" describes it.

Every new sound is synthesised by `tools/generate_nature_audio.py` (`bake_genesis`) from noise, RBJ biquads, sines and Minnaert bubbles, so the project's own licence covers them. The clay's land voice (`land-bed-loop`, `land-grind-loop`, `land-lurch-1..6`, `land-grind-1..6` in `assets/audio/foley/`) is synthesised by `tools/generate_nature_audio.py --land`, with the standard library only, and comes out the same on every run. Deer steps reuse the baked footsteps and stream fronts reuse `stream-bed`; the Nature recordings are credited in `assets/audio/ATTRIBUTION.md`.

The files are mono 16-bit WAV at 12–24 kHz: 12 kHz for the rumble and thump, 16 kHz for the fill and the plain air. Loops are baked 0.6 s long and crossfaded into their heads, so they loop without a seam. Godot imports them compressed as QOA (`compress/mode=2`), like the existing beds. They are not Ogg because there is no Vorbis encoder here: ffmpeg's built-in one is experimental and stereo-only. The new files total about 1.9 MB on disk.

## Cost

- **Loading:** every stream is loaded once in `setup`. The loops are duplicated and set looping there, and players are created there. Nothing loads or allocates when a sound plays. The only exceptions are the pending list for a moment's delayed sounds and a once-a-survey rebuild of the wood points.
- **Per frame:** seven voice gains, two bed gains and at most a few pending one-shots.
- **Every 0.5 s:** the nearest of at most 160 wood points and a count of arrived birds, frogs and spawn.
- **Measured headless** (`tools/probe_genesis_audio.gd`, all five brushes, a pour, 30 s of growth and every moment): GenesisAudio's own time per frame had median 0.014-0.015 ms, p95 0.033-0.035 ms and max 0.27-0.35 ms over two runs.
- **`tools/profile_stroke.gd --mode=land --watch=20`**, before → after: stroke frames p95 9.73 → 9.88 ms (max 10.3 → 10.7), settle p95 9.06 → 9.00 ms (max 18.2 → 15.0).
- **`--mode=water`:** stroke p95 9.28 → 8.80 ms, settle p95 9.03 → 8.86 ms (max 16.3 → 16.9).
- These differences are within run-to-run noise. The profile does not emit the stroke signals, so its strokes do not start voices; the probe covers them.

## Checking it

Headless Godot uses a dummy audio driver, so nothing here has been heard. The probe checks the wiring: which voice rises for which brush, how it falls after release, the pour's fill and trickle windows, bed presence before and after growth, the one-shot limits and Bigfoot's hush.

```
godot --headless --path . -s res://tools/probe_genesis_audio.gd -- --native-kernels
```

To listen, launch `./run-cozy-flow.command` and try each of these:

- **Land:** a slow drag gives a low, soft rumble; a fast drag gives a louder and slightly higher one. It should fade out in under half a second after release, with no click at the start or end. On laptop speakers you mostly hear the 80–160 Hz body and the grit.
- **Mountain click:** one deep thump.
- **Water:** pouring while the brush is down, then a quieter tail while it settles. Then glugs that rise in pitch as the pond fills, and a trickle while a stream front runs. It should all stop when the water stops moving.
- **Forest:** a leafy wind that swells as the trees heave and settles with them over a few seconds.
- **Meadow and path:** a soft swish and a gravel scuff, only while the brush moves. They should be quiet.
- **Fast dabbing:** no machine-gun effect and no build-up.
- **A bare plain:** only a quiet, low wind with a faint whistle, and no birds.
- **After a wood grows:** birdsong from the wood's side, leaves rustling louder as you zoom toward it, and the plain wind receding.
- **At night:** crickets in cover, and frogs only once frogs have come.
- **Arrivals:** an occasional small plop when fish arrive, and a single croak for a frog. Never a burst on load.
- **A heron:** one harsh call as it comes in. **Deer:** a few soft steps.
- **A rainbow:** a barely-there open chord.
- **Bigfoot:** the birds go quiet. Sometimes there are two distant, reverberant knocks from deeper in the wood.
- **World > Sound:** Mute all, and the Master and Sound sliders act at once and are remembered after a relaunch.

Tunables that are likely to need an ear: the peak gains, `ATTACK` and `RELEASE`, `SPEED_FULL`, `NEAR` and `FAR`, `PLAIN_FLOOR`, the `ARRIVALS` gaps, `KNOCK_CHANCE` and the GenesisFar reverb. All are constants at the top of `scripts/genesis_audio.gd`.

## Open

- Nothing has been heard yet. The synthesised heron call and frog croak are the most likely to need another pass, or a licensed recording in their place.
- Voices are not ducked under Nature's beds, and Nature's beds are not ducked during a stroke. If a stroke over a busy pond feels muddy, a small sidechain-style duck on the ambient beds while a voice is up would be the next step.
- The Fidelity reference world keeps its old ungated Nature voices, and its strokes get the stroke voices.
