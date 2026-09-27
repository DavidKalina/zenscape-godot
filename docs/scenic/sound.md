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
| Bigfoot | the birds hush for 50 s (songs off, crickets down 70%), and 60% of the time two wood knocks, 0.8 s apart, 3–6 s after he shows, 8 m further into the wood, on the far bus | 0.22 | he is rare already |

Any two arrival sounds are at least `SHOT_GAP` (1.5 s) apart. For `SHOT_QUIET` (12 s) after a new world, load or undo there are none, because a settled world's life lands in a burst.

## Mix

- **Buses:** `Master` ← `Genesis` (the Sound volume, default 0.8, with a hard limiter at −1.5 dB) ← `GenesisFar`. `GenesisFar` has a low-pass at 1.6 kHz and a wide reverb (room 0.9, wet 0.45, dry 0.6, 60 ms predelay), and only the knock uses it. Nature and thunder stay on Master under their own toggles and sliders.
- **Levels** (before the Sound volume): the rumble is the loudest thing, at about −5 dB, and only during a fast rise. The other stroke voices sit at −10 to −16 dB, the beds at −16 to −20 dB, and the one-shots at −13 to −22 dB.
- **Settings:** World > Sound, or Settings in the main menu, holds Mute all sound, Master, and Sound (painting, creatures and the land's beds), next to the existing Nature sounds and Thunder. They are kept in `user://sound.cfg`.

## Sources

Every new sound is synthesised by `tools/generate_nature_audio.py` (`bake_genesis`) from noise, RBJ biquads, sines and Minnaert bubbles, so the project's own licence covers them. Deer steps reuse the baked footsteps and stream fronts reuse `stream-bed`; the Nature recordings are credited in `assets/audio/ATTRIBUTION.md`.

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
