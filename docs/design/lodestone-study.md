# Lodestone look study: handoff

Branch `look/lodestone`. This is a standalone study scene. Nothing is wired into the game.

The lodestone is the key item for the new loop. The player finds it somewhere hard to reach. It points the plane toward a hidden sky set piece, which rises from the clouds when the player arrives. This study answers one question: what does the stone look like, and does the place it holds read at hand size?

## What's built

**The stone** (`scripts/lodestone.gd`) is a faceted chip of sky island. It has a moss top, an earth band at the rim, and a keel of dark warm stone that hangs to a point, like the sky islands' keels. Two bands of pale facets wind round the keel. They are the "lode", and they glow a soft warm gold that breathes facet by facet. The stone's top is the miniature's ground, so the place stands on the stone itself rather than floating over it as a projection. This keeps it away from the hologram read.

**The miniatures** (`scripts/lodestone_miniatures.gd`) are built from the real set-piece code:
- **Sundered hall.** The plan is `SunderedHall.layout(1)`. The gate piece's first 6 bays are built with the hall's own far detail (`SunderedBuild.far`), torn at the sixth bay. Across a gap of open sky, a step up, 4 bays of the next piece stand on their own shard, torn at both ends. The torn hall across islands is the signature. The step up is exaggerated (+6 m) over the plan's for drama.
- **Broken aqueduct.** This is `RuinKitAqueduct.run(3, 0.35, spans 3, break at 2)` at the least growth (`RuinKit.set_detail(0)`): three spans with pointed arches, the last one snapped. A thread of water (`shaders/lodestone_thread.gdshader`) spills from the snapped channel's lip, which is found from the broken span's `walk` metadata. A kit `stump` stands on a floating shard past the break. The kit's own spill and pool are removed because they are drawn for world scale.
- Both are dressed in `shaders/lodestone_mini.gdshader`. It uses the set piece's own vertex colours, lit the way the ruins are (the sky's hemisphere as emission). The stone pales into a warm mist low down and toward its fringe, and its shade fills with "air", so it reads as a far place rather than a model.

**The swirl** reuses two existing pieces of work:
- The **vortex motion** comes from the water ball (`scripts/water_ball.gd` `_swim`, `shaders/water_ball.gdshader`). Each mote has its own orbit and pace, the inner ones quicker, weaving and breathing. The swirl angle is integrated by the script, as the ball's `swirl` is. The motion lives in `shaders/lodestone_vortex.gdshaderinc` as a function of time, so a stroke's tail is simply where its mote was. That idea comes from the jet ribbons (`shaders/sky_jet_ribbon.gdshader`).
- The **ribbon look** is the breeze ribbons' brush (`shaders/breeze_ribbon_paint.gdshaderinc`), used directly by `shaders/lodestone_ribbon.gdshader`: needle head, full body, dry bristled tail, sky-lit, plus a breath of the stone's own warm light.

Riding the swirl:
- 14 painted strokes.
- 65 riders in one MultiMesh (`shaders/lodestone_motes.gdshader`): 36 motes, 9 tumbling petals, 8 twinkling glints and 12 cloud wisps low round the miniature's foot.
- A wispy warm-white glow quad behind the stone (`shaders/lodestone_glow.gdshader`).
- A small warm OmniLight that lights what the stone rests on. Its cull mask leaves out the stone's own layer (`OWN_LAYER`), because at a few centimetres it burned the stone white.

**Hum** (`hum_goal` 0..1): the glow, the lode and the light brighten, the swirl quickens and draws in, and the whole thing breathes.

**Pointing** (`stream_goal` toward `stream_dir`): the swirl lets go of the stone. Each mote is born at the stone and spirals 2.5 turns round the stream's axis as it rides out along it, its orbit narrowing, then it is born again. The strokes deepen to amber so they read against cloud. A `stream_drift` sweeps the stream back with the air past the plane, so a stream pointing down or ahead still bends out behind the tail, where the chase camera sees it.

**The study** (`studies/lodestone_study.gd`/`.tscn`) uses the game's sky, sun, grade and look pass, the same way the ruin kit gallery sets them up. It has three views:
1. **world.** A small sky island made from the same keel mesh at island scale, with a weathered lancet window wall, a pier and floor slabs from the gothic kit. The stone hovers over the window's sill, beside the broken mullion, bobbing. The real pilot (`scripts/pilot_figure.gd`, driven through a stand-in motor) walks up to the stone and away. The stone hums from 5.5 m and fully at 1.6 m.
2. **inspect.** The pilot turns out along the wall and raises his mitts overhead (bone turns over the idle clip, in the item-get pose). The stone floats off the sill on an arc into the air above his mitts, and the camera pushes in from a medium shot over 1.8 s. The player turns the stone with a mouse drag or the right stick. It starts three-quarters on and tipped toward the eye.
3. **cradle.** The real plane (`scripts/plane_figure.gd`; its look is untouched, the cradle is added as children) cruises in place at the chase camera's cruise framing: 5.4 m back, pitch 0.27, FOV 70. The placeholder gimbal is a brass post, an outer ring that turns to the target's heading and an inner ring that leans the stone toward it, with the stone seated at 0.42 scale. The swirl streams toward one of six ways (ahead, left, right, up, down, behind) or sweeps round. The real cradle is being designed on `look/plane-ruin`. This one is a placeholder.

## How to run

```
./run-lodestone-study.command                      # windowed, --no-title is passed
./run-lodestone-study.command --view=inspect --mini=aqueduct
./run-lodestone-study.command --view=cradle --sweep
godot --path . res://studies/lodestone_study.tscn -- --no-title --view=cradle --target=up --capture=out.png
```

Flags:
- `--view=world|inspect|cradle`
- `--mini=sundered|aqueduct`
- `--target=ahead|left|right|up|down|behind`
- `--sweep`
- `--night`
- `--near=<m>`: holds the pilot that far from the stone (world view).
- `--turn=yaw,pitch`: turns the stone.
- `--yaw= --pitch= --distance=`: set the camera.
- `--arms=raise,forward,forearms`: tries other arm poses.
- `--capture=<png> [--wait=s]`: saves the frame, prints the cost and quits.

Headless test: `python3 tools/run_tests.py --tests 'test_lodestone_study.gd'` (passes).

## Controls

| Key / pad | Does |
|---|---|
| V or Tab, pad Back | next view |
| M, pad Y | next miniature |
| Drag, right stick | turn the stone (inspect) / orbit (world, cradle) |
| Wheel | zoom |
| E, pad A | pick it up (world) |
| W / S, A | walk the pilot up / back, toggle auto walk (world) |
| R | replay the pickup (inspect) |
| T, pad X; P | next way to point; sweep round (cradle) |
| N | day / night |
| I | measure and show the cost |

## Captures

The captures are in `docs/design/lodestone/` as 1440-wide JPEGs. The repo ignores `docs/**/*.jpg`, so they are local and not committed:
- `world_found.jpg`, `world_quiet.jpg`: the pilot 2 m off (humming), and 7.5 m off (still).
- `inspect_sundered.jpg`, `inspect_aqueduct.jpg`, `inspect_sundered_night.jpg`, `inspect_aqueduct_night.jpg`
- `cradle_ahead.jpg`, `cradle_left.jpg`, `cradle_up.jpg`, `cradle_down.jpg`: at the chase framing.
- `cradle_close.jpg`: the aqueduct streaming right, from 2.2 m.

## Cost

These are measured in-frame by hiding the stone. Shadow passes are included. Forward+, 1440x900, M-series Mac.

| | draws | triangles on screen | miniature tris | stone + shards tris |
|---|---|---|---|---|
| Sundered hall | 9 | 4,688 | 2,236 | 768 |
| Broken aqueduct | 13 | 31,476 | 29,000 | 768 |

The swirl is 2 draws: the strokes (14 x 56 tris) and the riders (65 quads). The glow is 1 draw. The aqueduct's extra draws are its channel water sheets and the thread. Materials are per stone; shader uniforms are set every frame.

## Weaknesses (honest)

- **The aqueduct is heavy.** 29k triangles for a hand-held item. The kit has no lean or LOD path for it from the outside (`Build.lean` is per build, so the static piece functions can't take it). Options:
  - Add a lean flag to the aqueduct pieces.
  - Run the merged mesh through `ImporterMesh.generate_lods`. Facet-split vertices may not simplify well.
  - Bake a simplified arcade.
- **The Sundered hall miniature reads as "a little gabled temple on an island"** more than as the Sundered hall. From above you get the gable, the colonnade and the torn piece across the gap, which is good. At a glance it is a generic classical hall. The real hall's identity is its length, its torn sequence and its dark nave. Two pieces is too few to say "a long hall torn across many islands". Showing 3 or 4 shorter shards in a stepped chain would probably read better.
- **The pickup pose is serviceable, not good.**
  - The pilot's arms are short. The overhead raise puts the mitts beside the head, not under the stone, so the stone floats a hand above them.
  - The close camera ends over the cap, so his face doesn't show.
  - A proper item-get clip from Blender, plus a camera that keeps the face, is the fix.
- **Cradle readability.**
  - Left, right and up read clearly at the chase framing: an amber helix.
  - Ahead and down are weak. Ahead is foreshortened and runs away from the camera. Down is hidden by the plane and only shows as a faint strand swept back past the tail.
  - Pale strokes over the bright cloud sea are low contrast even in amber.
  - The stone itself is too small to see at chase distance (0.42 scale on a 1.4 m plane). Only the gimbal ring and the stream read.
- **The island top in the world view looks washed pale mint** at grazing angles. That is the study's backdrop, not the stone, and it was left alone.
- **The world view stone is small** next to a 7.8 m window wall. At 0.3 m across it needs the glow or the camera to find it. A finding moment probably wants a stronger beacon: a thin column of motes, or a hum audible before it is seen. There is no audio yet.
- **The keel's vein facets catch the sun** and can flash pale and gem-like in daylight. That reads toward a crystal rather than a stone. They're toned down but still worth watching.
- **The night glow reads cool white** under the night grade, not pale gold.
- **The lodestone builds its keel per miniature** (its top outline follows the place), so the stone's silhouette changes with the place. That is fine for a study. The game may want one recognisable stone shape.
- **Snow globe / hologram check.** It doesn't read as a snow globe, because nothing encloses it. It doesn't read as a hologram, because the place is solid stone on solid stone, lit by the sun. The wisps and the haze make it feel like a far place. The weakest part is the glow quad, which can look like a flat smudge behind the stone against a dark wall.

## Next steps

1. Give the aqueduct a lean or LOD path, or bake it, to get under ~8k triangles.
2. Try the Sundered miniature as a stepped chain of 3 or 4 short torn stretches on shards. Compare it against the real hall flown at `--motif=sundered`.
3. Make an item-get clip for the pilot, and an inspect camera that keeps his face under the stone.
4. Cradle: a bolder stream head (a bright mote leading each stroke), longer strokes when the target is ahead or down, and maybe a short pulse that shoots along the stream every few seconds. Hand the stream parameters to the `look/plane-ruin` cradle.
5. Sound: a soft chord hum that swells with `hum`, and a whoosh when it starts pointing.
6. More miniatures (the pierced isle is the obvious third), and a rise moment where the real place surfaces and matches the miniature.

## Files

- `scripts/lodestone.gd`: the item (stone, miniature, swirl, hum, stream, keel mesh)
- `scripts/lodestone_miniatures.gd`: the miniatures from the set-piece code
- `shaders/lodestone_vortex.gdshaderinc`: the swirl's paths (rest and streaming)
- `shaders/lodestone_ribbon.gdshader`, `shaders/lodestone_motes.gdshader`, `shaders/lodestone_glow.gdshader`, `shaders/lodestone_stone.gdshader`, `shaders/lodestone_mini.gdshader`, `shaders/lodestone_thread.gdshader`
- `studies/lodestone_study.gd`, `studies/lodestone_study.tscn`, `run-lodestone-study.command`
- `tests/test_lodestone_study.gd`
