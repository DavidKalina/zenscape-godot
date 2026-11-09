# Audio attribution

Wildlife recordings from Wikimedia Commons and Freesound, processed (mono,
trimmed, loudness-normalized) for ZenScape. Every recording here is public
domain or CC0; none requires credit, and each is credited as a courtesy. The
in-game credits (`scripts/endless/shell/credits_page.gd` `SOUNDS`) carry the
same list, since an exported game ships without this file.

| file | license | author | source |
|---|---|---|---|
| chickadee.mp3 | CC0 1.0 | *ngoomie (Black-capped Chickadee) | https://commons.wikimedia.org/wiki/File:Black-capped_Chickadee_201947598.wav |
| jay-1.mp3 | Public domain | National Park Service (Steller's Jay) | https://commons.wikimedia.org/wiki/File:Steller%27s_Jay_-_National_Park_Service.ogg |
| jay-2.mp3 | CC0 1.0 | nfrae (Steller's Jay) | https://freesound.org/people/nfrae/sounds/703255/ |
| nutcracker.mp3 | Public domain | NPS / Shan Burson | https://commons.wikimedia.org/wiki/File%3AYellowstone_sound_library_-_Clark%E2%80%99s_Nutcracker_-_001.mp3 |
| hermit-thrush.mp3 | Public domain | National Park Service, Yosemite (Hermit Thrush) | https://commons.wikimedia.org/wiki/File:Hermit_Thrush_Yosemite_National_Park.ogg |
| kinglet.mp3 | Public domain | G. McGrane (Ruby-crowned Kinglet) | https://commons.wikimedia.org/wiki/File:Ruby-crowned_Kinglet.ogg |
| owl.mp3 | CC0 1.0 | Felix Blume (Great Horned Owl) | https://freesound.org/people/felix.blume/sounds/612651/ |
| raven.mp3 | Public domain | NPS/David Restivo | https://commons.wikimedia.org/wiki/File%3AYellowstone_sound_library_-_Common_Raven_-_001.mp3 |
| bluebird.mp3 | Public domain | NPS & MSU Acoustic Atlas/Jennifer Jerrett | https://commons.wikimedia.org/wiki/File%3AYellowstone_sound_library_-_Mountain_Bluebird_-_001.mp3 |
| robin.mp3 | Public domain | NPS & MSU Acoustic Atlas/Jennifer Jerrett | https://commons.wikimedia.org/wiki/File%3AYellowstone_sound_library_-_American_Robin_-_001.mp3 |
| thunder-1.mp3 | Public domain | stephan | https://commons.wikimedia.org/wiki/File:Thunderstorm_after_hot_summer_day_17_minutes_02_of_04.ogg |
| thunder-2.mp3 | Public domain | stephan | https://commons.wikimedia.org/wiki/File:Thunderstorm_after_hot_summer_day_17_minutes_02_of_04.ogg |
| thunder-3.mp3 | Public domain | stephan | https://commons.wikimedia.org/wiki/File:Thunderstorm_after_hot_summer_day_17_minutes_02_of_04.ogg |

The nutcracker, raven, bluebird, robin and thunder edits are copied unchanged
from the Electron ZenScape project. The chickadee, jays, hermit thrush,
kinglet and owl replaced CC BY-SA recordings in 2026-11; the Freesound ones
are the site's HQ previews. CC0: https://creativecommons.org/publicdomain/zero/1.0/.

Procedural stream, shore, cricket, frog and footstep WAVs are baked native
adaptations of ZenScape audio.js. Regenerate with tools/generate_nature_audio.py.
Existing wind, rain and waterfall beds are procedural ZenScape audio, as is
`edge-strain.wav` (tools/generate_nature_audio.py). The bore sounds (`bore/`,
tools/generate_bore_audio.py) and the parry's ring, boom and clunk (`parry/`,
baked from scripts/endless/parry.gd's old in-code makers) are synthesised too.

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

## Burrower study (`burrower/`)

The bell and gong are CC0 recordings from Freesound, previews used as
downloaded (`bell-417300.mp3` puppyhead "BELL.WAV", `bell-531031.mp3`
creeeeak "bell8.wav", `gong-369428.mp3` cabled_mess "Small Gong_Soft Hit_RAW",
`gong-711881.mp3` robin.kaf "Street Sign Gong - 03"); pages at
https://freesound.org/people/<author>/sounds/<id>/. CC0 asks for no credit.
The orb's blip is synthesised in `scripts/burrower/push_ups.gd`.
