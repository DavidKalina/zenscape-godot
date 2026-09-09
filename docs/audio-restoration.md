# Restored nature sounds

The Godot soundscape reuses all ten bird recordings from the Electron project's
`audio.js` / `public/audio`, with credits in `assets/audio/ATTRIBUTION.md`.
Songbirds play every 6–20 seconds in daylight, hermit thrushes take twilight,
and owls call every 30–90 seconds at night. Ravens and nutcrackers occasionally
call during the day. None requires a visible bird actor.

The original procedural stream burble, shore wash, cricket chirps and frog
chorus have baked native equivalents. `tools/generate_nature_audio.py` reproduces
these WAVs and four soft Bigfoot footstep variants, adapted from Electron's
`padStep` low thump and forest-litter scuff. These are synthesized sounds, not
additional field recordings.

Water emitters follow the nearest rendered waterfall, stream or pond surface,
including authored water. Editing water away removes its sound. Ice silences
streams and shores; cold quiets insects and frogs. The existing weather-driven
wind, rain, waterfall bed and thunder remain in place.

Bigfoot emits footsteps on the authored walk's alternating foot plants. Walking
speed changes the cadence; idle, carrying the character, and pause do not produce
steps. The Nature sounds toggle and volume control cover all restored audio.
Thunder retains its existing separate control.

Checks:

- `tests/test_nature_audio.gd`: recordings, hour selection, spatial playback,
  pause/mute, frozen water, alternating footsteps and speed changes.
- `tests/test_ambient_audio.gd`: weather beds, scene integration, positioned
  waterfall audio and removal of water emitters.

Listen in the diorama: enable Nature sounds in Settings, try daylight, twilight
and night, approach water, and watch Bigfoot walk. A final subjective mix pass
may still be useful; automated checks verify playback and controls, not taste.
