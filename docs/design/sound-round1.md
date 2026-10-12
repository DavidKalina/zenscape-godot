# Sound, round 1

The core play had almost no sound. This round makes flying and moving on foot
sound alive on every kit isle, so the game (studies/zenscape.tscn) gets it too.
Branch `feature/sound-round1`, not merged.

Try it: `godot --path . -- --no-title` (on foot by the plane), or add `--fly`.

## What was there

- `scripts/glide_air.gd`: the plane's sound in the kit game. A GDScript noise
  generator (a hiss, a dive roar, a 52 Hz hum, a flap whoosh, a blip) on
  Master, with no bus. It's now muted on the kit isles (`voiced = false`),
  which keep its streaks and mist. Other scenes still have its sound.
- `scripts/wanderer_steps.gd`: the pilot's footsteps, on the Genesis bus. They
  already played on the kit isles, but always as "stone".
- `scripts/collectibles_hud.gd`: token blips. These play.
- `studies/thunder_audio.gd` through `kit_weather.gd`. Plays.
- `scripts/wind_gust.gd` and `scripts/genesis_audio.gd`: only in the old
  builder game. On the kit isles only the Genesis bus and settings are used.

## What's in

The new system is `scripts/kit_isle/kit_audio.gd`. It reads the isle every
frame and never steers it. The glue in `studies/kit_isle.gd` is:

- `audio = KitAudio.new()` in `_ready`;
- `audio.thump(k)` in `_thump`;
- `_surface()` and `_motor_events()` overrides that call `audio.surface` and
  `audio.body`;
- `air.voiced = false`.

**Air (the main voice)**
- The rush follows airspeed: the plane's, or the pilot's own fall. Its gain,
  pitch and the SFX Air bus low-pass all follow it.
- A whistle comes in when going fast, near rock, or on the knife edge.
- A hollow howl plays when stone closes in from several sides, such as when
  threading an arch or a gap. A ring of 8 rays checks this, 3 rays a frame,
  9 m reach, using `plane_mask()`.
- A whoosh plays as rock comes close, panned to that side.
- The sail flutters by its pace, and a long fall flaps.
- On foot, a wind bed follows the atmosphere's strength and gusts.

**Cloud sea**
- Under the isle's cloud floor (`isle_top - FLOOR_BELOW`), or inside a cloud's
  body, a low-pass on both SFX and Ambience closes to 1.3 kHz and a deep hush
  bed swells.

**Plane**
- The engine loop's pitch and gain follow throttle, speed and the engine's
  spin. It spins down on landing.
- Started on the turf, the engine coughs awake with `engine-start`.
- On the knife edge or in a drift, the wires sing and the frame creaks. A
  barrel roll starts with a creak and a swish. The flaps creak.
- On landing: touchdown thumps scaled by `k`, a wheel rumble that follows
  ground speed, and a skid hiss that follows `hand_landing.grit`.
- Boarding and getting out: cloth, a creak, then the seat's thump.
- Parked after a flight, the engine ticks for 50 s as it cools, sparser over
  time.

**Body**
- Footsteps now change by surface:
  - grass on open turf;
  - worn earth on paths;
  - stone on ruins and rock;
  - planks on rope-bridge decks;
  - water when wading.
- Foley on top of the steps:
  - jumps and wall kicks: cloth rustle;
  - wall kicks and twirls: swish;
  - ledge grabs and wall holds: a hand slapping stone;
  - the sail: a pop when it opens, a fold when it closes;
  - slides and carves: a scrape on stone, a swish on grass;
  - heavy landings: a thud;
  - bridge planks: creak underfoot, and on landing and jumping off;
  - water: splash and plop.

**Ambience**
- Leaves when the turf near the listener is green, rising with the wind.
- Birdsong by day from the isle's own songbirds (`life.birds.birds[].p`) when
  one is within 45 m, otherwise from the grass nearby. On the Ambience Far
  bus.
- Crickets and an occasional owl at night.
- A stream bed at the nearest narrow pool (the aqueduct channel) and a lapping
  bed at the nearest wide pool, both placed in 3D. Positions come from
  `ground.pools`.
- Rain.
- A thin, high wind away from the isle and high above it.

## Buses

```
Master ─┬─ SFX [LPF: cloud hush]          ← Effects volume (settings "sound")
        │    └─ SFX Air [LPF: speed]      ← rush, whistle, howl, whooshes
        ├─ Genesis (old: steps, tokens)   ← Effects volume too
        │    └─ GenesisFar
        ├─ Ambience [LPF: cloud hush]     ← Ambience volume (new setting)
        │    └─ Ambience Far [LPF 3.2k + reverb] ← birds, owl, crickets
        └─ Music (empty, for round 2)
```

`KitAudio.ensure_buses()` builds the buses at run time. There is no bus layout
file. The settings sheet now has these sound settings:

- Volume
- Effects (steps, air, plane)
- Ambience (wind, birds, water), new, stored under the `ambience` key in
  `user://sound.cfg`
- Mute

`game_settings.gd` calls `KitAudio.apply_settings` next to genesis_audio's.

## Assets

`tools/generate_kit_audio.py` (stdlib only, deterministic, about 2 s) bakes
these into `assets/audio/kit/`:

- loops: air-rush, air-whistle, air-howl, engine, wheel-rumble, skid, flutter,
  wire-sing, thin-wind, cloud-hush;
- one-shots: thump, creak, tick, swish, whoosh, sail-pop, sail-fold, grab,
  engine-start.

All are synthesized. The loops are seamless because each tail is cross-faded
into its head. Bake one take with `python3 tools/generate_kit_audio.py engine`.

It also reuses these existing files:

- wind-bed, leaf-rustle-bed, stream-bed, water-bed, cricket-bed, rain-bed,
  genesis-meadow;
- the birdsong mp3s and owl;
- foley: scrape-loop, ui-cloth, pat, water-splash, water-pop.

## Tuning knobs

The constants at the top of `kit_audio.gd`, all linear gains before the bus
volumes:

- `PLANE_AIR` and `BODY_AIR`: the speeds where the rush starts and where it's
  full.
- `RUSH`, `RUSH_NEAR`, `RUSH_CUT`, `WHISTLE`, `HOWL`: the air's level and
  brightness.
- `WHOOSH_AT`, `WHOOSH_GAIN`, `WHOOSH_GAP`: when a pass-by whoosh fires.
- `PROBE_REACH`, `PROBE_RAYS`: the threading probe.
- `ENGINE*`: the engine's level and pitch curve. Cruise is pitch 1.0 and full
  boost about 1.25.
- `WIRES`, `CREAK_GAP`: strain. `RUMBLE`, `SKID`: wheels. `COOL`, `TICK`:
  parked ticking.
- `BREEZE`, `THIN`, `HUSH`, `LEAVES`, `CRICKETS`, `RAIN`, `STREAM`, `POND`:
  the beds.
- `HUSH_OVER`, `MUFFLE_CUT`: the cloud sea's hush.
- `SONG_GAP`, `SONG_GAIN`, `SONG_REACH`, `OWL_GAP`: birds.

## Checks

- `tests/test_kit_audio.gd` runs headless and passes. It checks the mix's
  intent: the buses, silence on foot, the engine and rush rising with boost,
  the knife-edge wires, the cloud hush, the thump, the body's foley, the
  parked ticks, and the surfaces found.
- Headless has no audio device, so nothing here has been heard. The levels are
  first guesses. One rendered listening pass is needed to set the mix.
- The headless load of the game scene runs clean: on foot, with `--fly`, and
  with the title.

## What's next

- **A listening pass.** Set the overall balance between the rush and the
  engine, the loudness of birdsong, and how strong the cloud hush is.
- **Music.** The bus is ready. It needs a score that ducks under the rush in
  fast flight.
- **Creatures.** Songbirds flushing (wing flurry from `kit_birds` flush), the
  dragon (gale roar, wingbeats), the serpent (stone grind), butterflies. Skipped
  this round as asked.
- **Rope swings and ladders.** None exist yet, so there's nothing to creak.
  The bridges creak instead.
- **The waterfall** at the aqueduct's spill and at the island edges. It needs
  the fall's positions, which aren't in `ground.pools`.
- **Footstep variety.** Add sand and snow on isles that have them, and wet
  stone in rain.
- **Engine body.** A second layer that changes with the camera's angle to the
  plane, e.g. louder up front.
