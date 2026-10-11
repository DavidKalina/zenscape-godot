# Sound, round 2

Round 1 (docs/design/sound-round1.md) stays as it was. The user's note on it
was "Much better. Could use some extra bird noises and stuff." This round
makes the living world louder and richer and fills a few gaps. Branch
`feature/sound-round2`, built from `feature/sound-round1` with main merged in
for the swing ropes. Not merged to main.

The living layer is `scripts/kit_isle/kit_audio_life.gd`, a child of
`kit_audio.gd`. Its tuning constants are at the top of that file.

## Birds by the time of day

The celestial phase drives a `DAY` curve with two values: how busy the songs
are, and how loud the chorus bed is.

| Time | Songs | Chorus |
| --- | --- | --- |
| Dawn (phase about 0.3) | busiest | full |
| Morning | lively | about half |
| Midday | quieter | thin |
| Dusk (about 0.72) | a second chorus | about 0.75 |
| Night | none | none |

- **Chorus bed.** `bird-chorus-loop` is 30 s of synthesised distant singers
  on the Ambience Far bus. It seams cleanly because every phrase wraps
  around the loop's end.
- **Songs.** Excerpts of the old recordings, 3.5–9 s long, taken from a
  random point and faded out. Each has its own pitch (±7%) and gain, so
  repeats don't stand out. Up to 10 can overlap. The gap is 1.2–4 s when
  busy and 9–18 s when quiet. About a third get an answer from another spot
  16–35 m away.
- **Near birds.** Perched birds within 24 m chirp and twitter. These are
  synthesised: `chirp-1..8` and `twitter-1..6`, which include trills.
- **Wings.** A bird leaving a perch within 35 m gives a wing flurry
  (`wings-1..4`). A flock flushing together gives a bigger flurry and a few
  alarm chirps.
- **Raven.** `raven.mp3` calls every 35–80 s by day, 8–22 m up and 30–60 m
  off.
- **In the air.** Everything above scales with the square of the isle's
  nearness, so open sky stays airy.

## Other life

- **Bees.** `insect-hum-loop` plays at the nearest flower patch (kit_life's
  meadows) within 30 m, by day, and not in rain.
- **Crickets.** Ported from the Electron Zenscape (`zenscape/audio.js`
  `tickCrickets`). They replace `cricket-bed.wav`.
  - 8 positional voices sit on grass spots 5–22 m round the listener. A voice
    moves to a new spot once the listener has left it behind.
  - Each chirp is 3 or 4 sine pulses 0.055 s apart, pre-rendered as
    `cricket-<pulses>-<slow>`.
  - Each voice has its own pitch, 4.1–5 kHz.
  - Cold stretches both the pulses and the gaps by ×(1 + 1.6·cold).
  - Level: night is smoothstep(0.55, 0.18, daylight), and warm is
    1 − smoothstep(0.25, 0.6, cold).
  - Approach hush: within 4 m a cricket goes quiet with tau 0.15 s and comes
    back with tau 2.5 s.
- **Frogs.** Ported from audio.js `tickFrogs`.
  - The croak is a sawtooth through a resonant low-pass (480 Hz, Q 3), in a
    ratchet of 6–10 pulses with the pitch rising 1.3×. Six frogs are
    pre-rendered (`frog-1..6`).
  - 4 voices sit on the banks of the nearest wide pool.
  - They sing at dusk and at night, and in rain. Cold quiets them.
  - The old `frog-bed.wav` and `frog-croak.wav` are not used.

## Waterfalls

- Every mesh using `flow_fall.gdshader` (fall curtains) or
  `sky_fall_thread.gdshader` (threads to the cloud sea) is found as it
  enters the tree. That includes the motif isles built later.
- Each fall is a line down the middle of its `custom_aabb`. Its bed sits at
  the point on that line nearest the listener.
- The 3 nearest big falls get `fall-roar-loop`, heard out to 220 m. Threads
  are at half strength.
- The 2 nearest thin spills get `fall-spill-loop`, a patter and gurgle heard
  out to 70 m. This includes the aqueduct's "Spill".

## Swing ropes

These are main's `scripts/interactables/swing_rope.gd`, read through
`motor.rider`.

- **Catch:** a hand slap and a rope creak at the anchor.
- **While swinging:** rope creaks (`rope-creak-1..4`, fibrous and lower than
  wood). They come more often and louder as the swing grows.
- **Through the plumb:** a swish, plus a soft whoosh when the swing is fast.
- **Release:** a whip-crack with a low thrum (`rope-whip-1..3`), plus cloth.

## Quit leak

I couldn't reproduce it. These runs printed no "ObjectDB instances leaked":

- headless runs, on foot, flying and from the title, up to 2400 frames;
- the same runs with `--audio-driver CoreAudio`, so real playbacks were live;
- a probe of the steps' static take caches.

As a defensive fix, `KitAudio._exit_tree` now stops every player and lets go
of the clips and beds. `KitAudioLife._exit_tree` disconnects its
`node_added` hook. If the leak comes back, run with `--verbose` to get the
class names.

## Assets

`tools/generate_kit_audio.py` gained these takes:

- chirps, twitters, wings, bird-chorus;
- insect-hum, fall-roar, fall-spill;
- rope-creaks, rope-whips;
- crickets, frog-croaks.

Bake one group with, for example, `python3 tools/generate_kit_audio.py frog`.

## Checks

- `tests/test_kit_audio.gd` passes headless. It now also checks:
  - the bird-day curve;
  - songs and chorus at dawn;
  - crickets and no chorus at night;
  - the falls found, and the roar beside one;
  - the rope's whip.
- The headless load of studies/zenscape.tscn is clean on foot, with `--fly`,
  and with the title.
- Nothing has been heard yet. All levels are first guesses and need a
  listening pass.

## Open

- Set the mix by ear: chorus level, song density at dawn, cricket loudness,
  and the roar's reach.
- The aqueduct isle has one fall at load (its spill). The motif isles' falls
  are only picked up once those isles are built.
