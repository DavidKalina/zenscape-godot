# Native wind, rain and waterfall ambience

Three quiet looping noise beds now accompany the scene. The original uses
filtered Web Audio noise; `tools/generate_ambience.py` follows that approach to
create deterministic native WAV loops. Wind and rain have decorrelated stereo
channels. Water is a positional mono source at the waterfall's plunge pool.

Wind loudness and pitch follow the shared gust strength. Rain follows the liquid
precipitation fraction and quiets as it turns to snow. Water fades with filling,
slows and fades with ice, and stops over unfinished terrain. Native distance
attenuation makes the waterfall quieter as the camera moves away. Mix envelopes
ease between conditions. Pause stops all three streams and their envelopes.

**Wind, rain and waterfall sound** toggles the beds; the slider beneath it sets
their volume. Thunder keeps its existing independent control. The beds are a
compact native soundscape adaptation; shoreline lapping, leaf rustle, crickets
and creature calls are not included in this pass.

`ambient-review.wav` was recorded from the actual Godot audio bus at 48 kHz:
calm at 0–4 seconds, building rain at 4–8, paused at 8–12, and frozen snowfall at
12–16. The review uses volume 0.8; the normal default is 0.55. Measured RMS in
settled portions was 0.00265 / 0.01507 / 0 / 0.00270 respectively. The paused
section is exactly silent and the recording contains no clipped samples.

`tests/test_ambient_audio.gd` checks weather/growth gates, valid looping streams,
pause and mute/resume. The integrated fidelity checks also pass with ambience
present. `tools/record_ambience.gd` reproduces the runtime recording.
