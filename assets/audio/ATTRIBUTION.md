# Audio attribution

Wildlife recordings from Wikimedia Commons, processed (mono, trimmed,
loudness-normalized) for ZenScape. CC BY-SA clips require this credit to
ship with the game; the NPS public-domain clips are credited as a courtesy.

| file | license | author | source |
|---|---|---|---|
| chickadee.mp3 | CC BY-SA 4.0 | Matthias Sirch | https://commons.wikimedia.org/wiki/File%3APoecile_gambeli_-_Mountain_Chickadee_XC395088.mp3 |
| jay-1.mp3 | CC BY-SA 3.0 | Jonathon Jongsma | https://commons.wikimedia.org/wiki/File%3ACyanocitta_stelleri_-_Steller%27s_Jay_XC109654.mp3 |
| jay-2.mp3 | CC BY-SA 3.0 | Jonathon Jongsma | https://commons.wikimedia.org/wiki/File%3ACyanocitta_stelleri_-_Steller%27s_Jay_XC110259.mp3 |
| nutcracker.mp3 | Public domain | NPS / Shan Burson | https://commons.wikimedia.org/wiki/File%3AYellowstone_sound_library_-_Clark%E2%80%99s_Nutcracker_-_001.mp3 |
| hermit-thrush.mp3 | CC BY-SA 4.0 | Leonardo Guzman Hernandez | https://commons.wikimedia.org/wiki/File%3ACatharus_guttatus_-_Hermit_Thrush_XC389885.mp3 |
| kinglet.mp3 | CC BY-SA 4.0 | Jonathon Jongsma | https://commons.wikimedia.org/wiki/File%3ARegulus_calendula_-_Ruby-crowned_Kinglet_XC175095.mp3 |
| owl.mp3 | CC BY-SA 4.0 | Michael & Katie LaTour | https://commons.wikimedia.org/wiki/File%3ABubo_virginianus_-_Great_Horned_Owl_XC450919.mp3 |
| raven.mp3 | Public domain | NPS/David Restivo | https://commons.wikimedia.org/wiki/File%3AYellowstone_sound_library_-_Common_Raven_-_001.mp3 |
| bluebird.mp3 | Public domain | NPS & MSU Acoustic Atlas/Jennifer Jerrett | https://commons.wikimedia.org/wiki/File%3AYellowstone_sound_library_-_Mountain_Bluebird_-_001.mp3 |
| robin.mp3 | Public domain | NPS & MSU Acoustic Atlas/Jennifer Jerrett | https://commons.wikimedia.org/wiki/File%3AYellowstone_sound_library_-_American_Robin_-_001.mp3 |
| thunder-1.mp3 | Public domain | stephan | https://commons.wikimedia.org/wiki/File:Thunderstorm_after_hot_summer_day_17_minutes_02_of_04.ogg |
| thunder-2.mp3 | Public domain | stephan | https://commons.wikimedia.org/wiki/File:Thunderstorm_after_hot_summer_day_17_minutes_02_of_04.ogg |
| thunder-3.mp3 | Public domain | stephan | https://commons.wikimedia.org/wiki/File:Thunderstorm_after_hot_summer_day_17_minutes_02_of_04.ogg |

Wildlife and thunder edits copied unchanged from the Electron ZenScape project.
CC BY-SA license texts: https://creativecommons.org/licenses/by-sa/3.0/ and
https://creativecommons.org/licenses/by-sa/4.0/.

Procedural stream, shore, cricket, frog and footstep WAVs are baked native
adaptations of ZenScape audio.js. Regenerate with tools/generate_nature_audio.py.
Existing wind, rain and waterfall beds are procedural ZenScape audio.

Genesis sounds (genesis-rumble, genesis-thump, genesis-pour, genesis-fill,
genesis-meadow, genesis-path, leaf-rustle-bed, plain-air-bed, fish-plop-1/2,
frog-croak, heron-call, bow-swell) are synthesised from noise,
filters and sines by tools/generate_nature_audio.py --genesis. They use no
recordings and carry no licence beyond the project's own.

The finger snaps (finger-snap-1..3.wav) are synthesised for ZenScape by
tools/generate_nature_audio.py --snap; no recording is used.

## Tool and HUD foley (`foley/`)

Cut from CC0 recordings on Freesound and from Kenney's CC0 packs (Impact
Sounds, Interface Sounds, RPG Audio) by `tools/foley/make_foley.py`. CC0 asks
for no credit; every file's source, author and page is listed anyway in
`foley/SOURCES.tsv`.

The clay's land voice (`foley/land-bed-loop.wav`, `foley/land-grind-loop.wav`,
`foley/land-lurch-1..6.wav`, `foley/land-grind-1..6.wav`) is not cut from
recordings: it is synthesised from noise, filters and sines by
`tools/generate_nature_audio.py --land`, after the Electron ZenScape's
formation rumble (audio.js `rumble` and the strain bed). It carries no licence
beyond the project's own and is not listed in `foley/SOURCES.tsv`.

## Kit isle sound (`kit/`)

The kit isles' air, plane and body takes (`kit/*.wav`: air rush, whistle and
howl, engine and its start, wheel rumble, skid, flutter, wire sing, thin wind,
cloud hush, thumps, creaks, ticks, swishes, whooshes, sail pops and folds,
grabs) are synthesised from noise, filters and sines by
`tools/generate_kit_audio.py`. They use no recordings and carry no licence
beyond the project's own.
