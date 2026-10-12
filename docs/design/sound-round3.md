# Sound, round 3: the beasts

Rounds 1 and 2 (sound-round1.md, sound-round2.md) stay as they were. This
round gives the sky dragon and the rune serpent their sound; both were
silent. Branch `feature/sound-round3`, not merged.

The new code is `scripts/kit_isle/kit_audio_beasts.gd`, a child of
`kit_audio.gd` (`audio.beasts`). Its tuning constants are at the top. It
reads the beasts and never steers them. Dragons, serpents and serpent riders
are found by their scripts as they enter the tree, so every scene that has
them gets their sound.

Try it:

- `godot --path . -- --no-title --dragon --dragon-ride`: you stand on the
  isle the dragon grips. You hear the slam, the growl, the grinding stone,
  the breath and the gale on you, then the launch.
- `godot --path . -- --no-title --dragon --dragon-attack`: you watch it
  fly in from the aqueduct isle and grip a far isle about 8 s later.
- `godot --path . -- --no-title --serpent-board=home`: you stand on the home
  ledge with the serpent coming. Jump on to hear the ride.

## The dragon

- **Wingbeats.** Each one is timed to the dragon's own beat (`phase`,
  `flap_w`).
  - The downstroke is a deep whump: a 34–44 Hz sub drop, a low push of
    air, and the membrane's soft boom.
  - The sample peaks 0.35 s in. It's fired that far ahead of the stroke's
    middle (phase 0.25), using the beat rate measured each frame. So the
    peak lands on the stroke at a cruise, in a climb and in the flare.
  - The upstroke (phase 0.6) is a lighter rustle with the membrane
    fluttering.
  - The gain follows `flap_w`, so glides are silent. Climbs and the grab's
    flare are heavier.
  - Beats are heard at full within 60 m and fade out by 1.6 km. They play
    on the new **SFX Far** bus: under SFX, with a long open reverb and the
    top eased off.
- **Passing air.** A rush loop, pitched down, follows the dragon and its
  speed. Heard within 500 m, it makes a close pass roar by.
- **Call.** A long, low, horn-like voice over a rough throat. It's meant
  to sound old and awe-inspiring, not like a snarl. It plays:
  - when the dragon rises out of the cloud sea;
  - when it comes within 420 m of you;
  - when its jaw opens on one of its roars (`roar_time()` crossing 0.45 s);
  - at most once every 16–24 s. Heard to 2.6 km.
- **On a rim.**
  - The grip: a deep slam through the rock, and rubble coming away.
  - A chest growl at the mouth, following its breath: strong as it
    settles and on the last pull, steady while panting, low through the
    draw-in and the blow.
  - Grinding stone at the gripped rim, placed where the tipped isle has it
    now. It's there while the isle is held and rises with the sag's speed
    (`gale.sag_v`), so the tip, each deepening and the snap back all grind.
  - **Breath** (dragon_breath.gd's blow): a 2.1 s draw-in (the tell),
    rising, then a 3.8 s blow, a vast rush and hiss of air with a low
    throat under it. No fire.
- **Gales.**
  - A howl along the blast's line, placed at the point nearest you and
    scaled by `gust_env`. Heard to 900 m.
  - A second howl round you, scaled by the breath ribbons' own air where
    you are (`breath.air_near`). These ribbons are what push and knock the
    pilot.
- **The plane in a gust.** The beasts script reads `plane_gust` the way
  the plane does.
  - When the gust strikes (strength 0.25 or more): a wind slam and a
    buffet hit.
  - While the gust holds: buffets at 0.18–0.5 s gaps, closer as it
    strengthens, and the howl round you.
- **Letting go.** A huge beat pitched low, a wind slam and two falls of
  rubble.
- **The pilot flung off** the springing isle: a wind slam and a whoosh.

## The serpent

- **Scales.** Stone plates grinding in a slow rolling rhythm, the odd knock
  of one on the next, and a rumble of weight.
  - The sound sits at whichever of its 48 rings is nearest you, so it's
    the body beside you you hear, not the head.
  - The gain and pitch follow its pace (`speed()`, up to 17 m/s).
  - Reach is 260 m. Further off it's silent.
- **Rune hum.** A deep 55 Hz hum with partials that beat slowly, and a
  faint glassy shimmer over it. It sits two rings toward the head from the
  scales.
- **Breath.** A slow, hollow breath at the head on its own 5.2 s cycle
  (`breath_phase()`): in for 2 s, out for 2.5 s.
- **Riding it** (`serpent_rider.gd`'s `riding_on == "serpent"`, or the
  greybox's own):
  - A stone rumble under the feet, scaled by its pace.
  - A swish as a carve starts and each time it changes side, plus a soft
    whoosh when fast.
  - A scrape while carving or sliding.

## Where it plays

- In the game (`studies/zenscape.tscn`) and on every kit isle:
  - The serpent is on its route by default.
  - The dragon is there with `--dragon`, `--dragon-ride`, `--dragon-attack`,
    or the Sky dragon entry in the scene picker.
- In the serpent ride greybox (`studies/serpent_ride.tscn`, the scene
  picker's Serpent ride and Serpent convoy): one line in `_build_room` calls
  `KitAudioBeasts.attach(self)`. That makes the buses and the kept
  settings, and a beasts node of its own. Each serpent in the convoy gets
  its own scales and hum while within reach.

## Hooks

Hooks are read-only and kept minimal:

- `sky_dragon.gd`: `roar_time()` returns `_roar_t`.
- `rune_serpent.gd`: `breath_phase()` is the breath cycle `_pose` uses.
- Everything else is state that was already public: the dragon's `state`,
  `phase`, `flap_w`, `mode`, `speed`, `breath`, `grip`, `launched`,
  `mouth_at()`, `blast_way()`, and the gale's `phase`, `sag_v`, `gust_env`,
  `isle`, `isle_rest`, `breath`, `plane_gust()`. On the serpent: `rings()`,
  `speed()`.

## Assets

`tools/generate_kit_audio.py` gained these takes, all synthesised:

- dragon-beat-1..4
- dragon-up-1..3
- dragon-call-1..3
- dragon-growl-loop
- stone-grind-loop
- rock-debris-1..3
- dragon-slam-1..2
- gale-howl-loop
- buffet-1..3
- wind-slam-1..2
- dragon-inhale
- dragon-exhale-1..2
- serpent-scales-loop
- serpent-hum-loop
- serpent-breath-1..2

To bake one group: `python3 tools/generate_kit_audio.py dragon` or
`serpent`. It also reuses round 1's air-rush, swish, whoosh and thump, and
the old foley scrape loop.

## Checks

- `tests/test_kit_audio.gd` passes headless. It now also checks:
  - the serpent is found;
  - its scales and hum play beside its body, at that ring, and go silent
    far off;
  - the dragon is found, with one whump a beat and its upstroke's rustle;
  - a call plays as its jaw opens.
- The headless load of `studies/zenscape.tscn --quit-after 300 -- --no-title`
  is clean. So is the load with `--dragon --dragon-attack` (900 frames,
  through the grip), and so are the serpent ride greybox and its convoy.
- In one of six `--dragon` loads, "1 resources still in use at exit" was
  printed. It's the `--quit-after` teardown race from round 2, which
  bypasses `KitAudio.quit`. It didn't happen again under `--verbose`.
- Headless has no audio device, so none of this has been heard. The levels
  are first guesses and need a listening pass.

## Open

- Set the mix by ear:
  - the wingbeat's weight against the plane's engine at a close pass;
  - the reach of the call;
  - the growl and the grind against the gale;
  - the serpent's hum level.
- The roars while it roams come every 12–22 s. `CALL_GAP` holds the call
  back, so not every visible roar is voiced. If the silent ones read
  wrong, lower the gap or add a quieter grumble for them.
- No sound yet for the serpent noticing you (its jaw parting, `JAW_TIME`).
