# Dragon roost, round 3: make it ominous

Branch `look/dragon-roost-3`, made from `look/dragon-roost-2`. This is a look study. The sleep pose, the 1.5 size, the contact settle, `--dragon-roost`, and the clouds and airships keeping clear are all unchanged. `scripts/sky_dragon.gd` is untouched.

Run it with `./run-dragon-roost.command`. Add `--fly` to start in the plane, or `--hour=23` for night.

## What changed

### Rock (`scripts/kit_isle/motif_dragon_roost.gd` `_scorch`, `turf_tone`)

- **The pale sandstone band is gone.** Every crag face is now sooted part of the way toward near-black (`SOOTED`). Under the ledge it gets darker: an even darkening plus burn streaks running down from the rim and fading out 40 m down. The tower's flanks get their own streaks, and the lip just under the rim is blackened.
  - Part of the old beige came from the kit's rock bands near a land's top (topsoil, clay and sand by depth). The soot under the ledge is weighted to cover that.
- **Worn, polished stone** (light grey, not beige) is only where he lies: within 2.6 m of his hide (`POLISH`) and in a thin band along the ledge's rim. The nest floor is worn smooth pale stone with scuffs (`NEST_TONE`).
- **Claw gouges** (`RoostDress.gouges`):
  - Four sets raked down the ledge's outer faces under the rim, one on the crag toward the tower, one on the tower's flank, and two sets across the rim's top.
  - Each set is three or four grooves: dark in the middle, with pale fresh-stone edges.
  - They are laid on the drawn triangles by ray, so they sit on the faceted faces.
- **Crag fangs** (`FANGS`): five rock teeth stand out of the massif's flanks. They break the old mesa outline into points. All of them are clear of the ledge and the line.
- **Turf:**
  - The roost's grass is dead and drab (`DEAD_TONE`), with no flowers (`DEAD_WEAR`, through the flora wear).
  - Round the crags' foot it is scorched to char with ashen patches, in ragged tongues (`scorch`), and bare there.
  - The step tops on the massif are scorched too, so the orange layer-cake bands are gone.

### Summit tower (`RoostDress.tower`)

The rock above the shoulder is now a low broken crown (`CROWN`). On it stands an old octagonal tower in the ruin kit's own stone (`RuinKit.Build`):

- coursed blocks, its top sheared off in a long slant from a broken tooth on the far side, so its high side is away from the aqueduct isle
- lancet slits and two string courses
- stepped buttresses at three corners (the fourth fallen)
- fallen blocks round its foot
- upper courses sooted, with soot streaks

`PEAK_H` is now its top, at 118 layout m (the old rock peak was at 100). Its collision is the kit's own hulls.

### Remains

- **Bones below the ledge** (`_bones_below`): 22 bones are strewn on the crags' step tops and the turf under the ledge's front and outer side. A great beast's rib cage lies half sunk in the turf before the mountain.
- **Airship wreck** (`RoostDress.airship_wreck`, on the spur):
  - A 28 m sky-folk envelope frame caught on the spur's tip, its outer end drooping. Its rings are broken and its stringers snapped short, with a few charred, torn canvas gores and two fins askew.
  - Its gondola hangs off the low end on two lines. In practice the gondola is mostly lost in the rock below, so the frame is what reads.
  - It shows in the distance read, to the right of the head.
- **Crashed plane** (`scripts/roost_air.gd` `_build_wreck`): the plane figure at the game's plane scale, nose first in the scorched turf at the foot under the ledge's front.
  - It has `set_missing(["propeller","wheel","wingtip","windscreen"])` and `set_wear(1.0)`, with the pilot hidden.
  - It is built at runtime on the main thread, not in the motif's worker build.

### His weather, life and air (`scripts/roost_air.gd`, a node the aqueduct isle makes with the roost dragon and shows with it)

- **Wreath:** 44 soft puffs ride a ring 40 to 62 m round the summit's axis, one turn in 260 s.
  - The tilt is fixed in the world: the ring sits high on the side facing the aqueduct isle and dips behind the tower. From the isle it rings the tower above the dragon and doesn't veil his head.
  - The puffs are lit through from behind (wrap diffuse plus backlight). Without that they read as a dark smudge against the sky.
  - The sky's own clouds still keep off the roost, as before.
- **Haze:** 14 large, faint, cold-grey puffs hang round the flanks, with proximity fade.
- **Cold:** a negative omni light (warm colour, energy 0.22, range 190 m) takes a little warmth and light off the mountain. It is kept small: at 0.55 the close shots went near black.
- **Carrion birds:** nine dark birds, each about 2.6 m across.
  - They glide on two thermals, over the ledge and over the summit, wings raised and banked.
  - Every 6 to 14 s each one gives a few slow beats.
  - The roost has no life script, so there are no songbirds on it.
- **Sound** (`scripts/kit_isle/kit_audio_beasts.gd` `_roosting`, for the dragon in state "roosting"):
  - **Breath:** the slow draw in and long out-breath (the existing inhale and exhale clips, pitched down to about 0.65), at the snout. They are timed to `DragonRoost.breath()`, are full within 45 m and gone by 650 m. So they are heard from the roost's meadow but not from the aqueduct isle.
  - **Growl:** a low growl under each out-breath.
  - **Wind:** the air-howl loop at the summit crown (`DragonRoost.howl_at()`), rising and falling in slow gusts, reach 600 m.
  - **Loading:** every stream is `load()`ed in the beasts node, never a const preload.
  - **Visibility:** the beasts now also check `is_visible_in_tree()`, so the hidden roost dragon is silent until its mountain stands.
  - I haven't listened to it: it was only checked to run without errors.

### Plants

Thirteen dead trees (`RoostDress.dead_tree`) stand on the turf and lower slopes. They are bare, crooked and faceted, lean away from the summit, and are charred the nearer the scorch they stand.

## Contact

The settle is unchanged and the ground under the line is unchanged (the tower and fangs are clear of it):

| Measure | Value |
| --- | --- |
| Largest gap under the trunk, legs and tail | **0.85 m**, at line point 168 (near the tail's tip on the front rim) |
| Largest gap anywhere | 2.37 m, at line point 63 (the neck's arch off the ledge) |
| Deepest hide sink | 0.84 m |
| Deepest wing sink | 1.48 m |

## Captures

These are in `captures/dragon_roost_3/` (gitignored). `tools/capture_dragon_roost.gd` remakes them; its new shots are `wreck`, `crash` and `meadow`. The `base_*` files are round 2's look, captured at the start of this round for comparison.

| File | View |
| --- | --- |
| `round3_isle.png` | From the aqueduct isle, normal lens |
| `round3_isle_zoom.png` | The same line of sight narrowed to 14° |
| `round3_mountain.png` | The whole mountain |
| `round3_nest.png` | The nest close up: polished bed, gouges, bones |
| `round3_summit.png` | The neck, head and old tower |
| `round3_wreck.png` | The airship wreck on the spur |
| `round3_crash.png` | The crashed plane at the foot |
| `round3_meadow.png` | From the roost's own turf, looking up |
| `round3_low.png` | Ledge-height contact check |
| `round3_night_night.png`, `round3_night_isle_zoom.png`, `round3_night_nest.png` | At 23:00 |

## Checks

| Check | Result |
| --- | --- |
| Headless import | clean |
| `studies/zenscape.tscn --quit-after 300 -- --no-title` | exit 0. Prints the known "18 ObjectDB instances leaked / 1 resources still in use" (as noted in round 2 on plain runs) |
| The same with `--dragon-roost` | exit 0, clean |
| `test_export_entry.gd -- --native-kernels` | all PASS, including "PASS: packaged walk, plane and teardown" |
| `run_tests.py --tests test_world_scale_guard.gd --tests test_world_scale_fit.gd` | 2 passed |

Headless runs of 300 or 900 frames don't reach the roost isle's own build. The dress (tower, gouges, wreck, trees) has only run in the windowed captures, which logged no errors.

## What's weak

- **Night:** his hide reads pale blue-grey at 23:00, lighter than the rock round him, rather than as a silhouette.
  - It isn't the new cold light: a capture with it off looked the same. Nothing added this round touches his material.
  - It still needs tracing against round 2's night look, which round 2 described as a silhouette.
- **The tower close up:** the ragged slanted top leaves stair-stepped single blocks. Seen against the light from the summit view, it looks blocky and a little voxel-like. From afar it reads well as a broken tower.
- **The wreath is heavy:** it reads clearly from the aqueduct isle at the normal lens, like a halo crown. It may want thinning (alpha, puff count) or breaking into a less perfect ring.
- **Fangs:** clean, symmetric cones. They would read more as crags with a lean or a broken top, which a heightfield can't lean.
- **The crashed plane is tiny:** about 3 m, at the game's plane scale. It reads only up close at the foot; from the air it is a speck. The airship wreck is what carries the "pilots beware" read at distance.
- **The gondola** hangs into the spur's rock and is mostly hidden.
- **The rock under the ledge** is now dark, but still a warm brown-grey on its sunlit faces rather than black-scorched.
- **Distance read:** at the normal lens he is still a small dark horned shape. What reads now is the lair: the wreath, the tower, the fangs and the dark mass. No wing or tail breaks his outline: the pose was kept.
- **Sound:** not listened to; breath and wind gains are first guesses.
- **Carry-overs:** the wing folds and the in-flight check at 1.5 remain as round 2 left them.
