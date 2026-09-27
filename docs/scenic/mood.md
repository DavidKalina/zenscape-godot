# Moods and customising the look

Branch `feature/mood-look`, 2026-09-27. The user asked for a quick way back to the authored atmosphere presets, plus season, rock, grass and other colours as opt-in controls that moods also drive.

## Using it

- **M** (or **Mood** on the creation palette, after Photo) opens a glass strip over the palette. **Esc** or **M** closes it.
  - It holds one chip per mood in `SceneLookPresets.PRESETS`. Each chip shows the mood's upper sky, horizon glow and grass as three bands, and hovering shows its title and description.
  - Once you have changed anything, a first chip, **This world**, goes back to the look the world was made with.
- Clicking a chip cross-fades the whole world over 1.2 s: sky, light, fog, haze, wind, clouds, rain or snow, the season (plants and ground), and every look colour.
- **Customise** opens a drawer:
  - **Season**: Spring, Summer, Autumn or Winter. This pins `world_clock.season_override` to living weather's mid-season values (`LivingWeather.SEASONS`), so plants blossom, turn or go bare through `zs_season`, and the ground takes the season's gold and cold. Choosing a season other than the mood's own drops the mood's gold, cold, snow and ice and lets the season supply them. Winter also lays a 0.45 frost (`WINTER_SNOW`).
  - **Time of day**: Dawn, Morning, Midday, Golden hour, Dusk or Night each hold that hour. **Turning day** lets the clock run instead. A pinned hour wins over the mood's (see "The hour" below).
  - **Weather**: any of the eight skies. The mood's own air (cloud, wind, mist, haze) is moved by the difference between the two skies, the same way living weather drifts. Pinning a weather holds the drift. Unpinning it lets the drift go again.
  - **Rock**: Granite, Slate, Sandstone or Basalt. Each sets the terrain shader's rock treatment and detail (`world_visuals.rock_style` / `rock_detail`) and a base rock colour. A pinned rock colour wins over the base. **All of this is live; nothing regenerates.** The desert strata (`world_visuals.geology`) are part of the world and do not change.
  - **Colours**: Grass, Leaves, Rock, Earth, Water, Sky (upper sky) and Mist (the mist tint). Each has six curated swatches and a free colour picker. Picker drags apply directly with no fade.
- **Pins.** A mood gives every control its starting value. Any control you set is pinned: it shows a dot and survives mood changes. For example, a purple rock set under Golden meadow stays purple under First snow. Clicking a dot lets that one control follow the mood again. **Back to mood** clears every pin.
- **The hour.** Each mood has an hour. On a world whose day turns (the creation plain, where the day runs at `PLAIN_DAY_LENGTH` so the deer find their dawn), picking a mood sets its hour as the time now and the day carries on turning from there. The moods defined by their hour hold it: **Nordic night**, **Rosewater dusk** and **Halloween hollow** (`MoodLook.HOUR_MOODS`), since a turning plain would otherwise pass their night or dusk within seconds. On a world whose day was held before any mood, every mood holds its hour, as before. A pinned **Time of day** always wins: an hour holds, **Turning day** turns. "Turns" is read from the world before its first mood (`origin.running`), so it survives moving between moods.
- **World → Colors & sky** is still the full editor. Its edits sit on top until the next mood change.

## How it works

`scripts/mood_look.gd` holds all the data and logic (a node on the scene, `scene.mood_look`). `scripts/mood_panel.gd` only draws it. The moods, controls, options and swatches are tables in `mood_look.gd` (`MOOD_SEASONS`, `CONTROLS`, `SEASONS`, `TIMES`, `WEATHERS`, `ROCK_TYPES`, `COLORS`), so a restyle can replace the panel without touching them.

**Rebuild.** Every change rebuilds the whole target in one frame, in this order:
1. The base: the mood, via `SceneLookPresets` data applied without its full scene step, or the world's origin snapshot for **This world**.
2. Weather.
3. Season.
4. Time.
5. Rock.
6. Colours.

Living weather's origin is re-established from the resulting sky, so later drift keeps the mood's air rather than the world's original air. A rebuild takes about 0.6 ms (headless).

**Cross-fade.** The rebuild snapshots the state before and after, puts the before state back, and blends between them with a smoothstep over `FADE_SECONDS` (1.2 s). The blend covers:
- the look's colours and settings;
- the hour and the season, each along the shorter way round;
- the atmosphere's fog, haze, wind and rays;
- precipitation state and targets, with cloud and cold overrides blended through their effective values;
- the surface's gold, cold, ice, snow and wetness;
- the world's fog bank, peaks and rock detail.

Discrete choices (the weather preset, rock treatment and whether the clock runs) switch at the start of the fade. A fade frame costs at most about 0.6 ms of GDScript (headless; `look.publish` and `update_rig` included). A new change during a fade starts from what is on screen. Saving lands a running fade first (`finish_fade`).

**New worlds.** Regenerate and New open plain reset moods: the new world opens on its own look with nothing pinned (`establish_world_weather` in `studies/cozy_worlds.gd`).

## Save format

`NativeGardenStore` saves an optional `mood` entry:

```
{"version":1, "mood":"first_snow" | "", "pins":{"rock":"8a5fb0","season":"winter",...},
 "origin":{look document, blended floats, phase, season, weather, rock_style, clock and drift origin} | {},
 "held_drift":false}
```

`origin` is the world before the first mood or pin, and is what **This world** returns to. The look, weather and clock themselves are saved as before, so loading restores the world exactly and only reinstates the mood and pins. Saves without `mood` load unchanged, on their own look with nothing pinned. Invalid pins, unknown moods or a malformed origin fail validation, like any other broken entry.

## Known gaps

- **E** (next season) and **W** (next weather) move the world without updating pins, so a pinned control can briefly disagree with the world until the next mood change reapplies it.
- Mood changes are not on the Cmd+Z stack.
- **Unverified on screen.** Only headless checks were run: parse checks and `tools/probe_mood_look.gd`, which applies every mood; pins rock, season, weather, rock type and time; switches mood; clears pins; round trips the save and a pre-mood save; resets on a new plain; and times the rebuild and fade frames. Nobody has yet seen how the fade looks, whether the chips read, whether the drawer layout fits at small window sizes, or whether the rock types and swatches look right.
