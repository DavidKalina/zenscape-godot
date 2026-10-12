# Dragon roost, round 1: the sleeping dragon on its mountain

Branch `look/dragon-roost`, built on `merge/scale-into-main` (current sizes and spacing). This is a look study. There is no waking, chasing, stealing or ledger work.

Run it with `./run-dragon-roost.command`, which starts the game with `--no-title --dragon-roost`. Add `--fly` to start in the plane, or `--hour=23` for night. Without the flag the game is unchanged. With `--dragon` as well, the roost wins and the dragon only sleeps.

## The isle

`scripts/kit_isle/motif_dragon_roost.gd` is a motif (`kit_motif.gd`), built and stood like the others by `motif_isle.gd`. `motif_sky.gd` adds it to its list only with `--dragon-roost`.

- **Where it stands:** `AT = (600, 55, 550)` from the motif frame. Its middle is at world (680, 540), about 820 m south-east of the aqueduct isle's middle. That is farther out than any motif isle (the broken ring is about 665 m), clear of the hall chain's NNE line and the cloud towers. Its meadow is at y 85, 55 m above the aqueduct isle's turf. The shelf is at about 157 and the needle tip at about 191, so it is the tallest silhouette in the sky. It is not in `MotifSky.places()`, so the clouds' keep and the flying dragon's targets don't know about it. That doesn't matter at this distance, but see the open questions.
- **Shape:** one height function, `ground(x, z)`, built through `KitLand.island` in the kit look (plate turf, islet rock, keel 64 m).
  - A meadow ring round the foot. It is broad on the aqueduct isle's side, and the plane can set down on it.
  - A massif of stepped crags with buttresses.
  - A steep upper cone (`CONE`: 0.32 m out per m down, for 48 m).
  - A narrow shelf at the top (radius 10.5).
  - A fluted needle rising 34 m out of the shelf.
- **The groove:** the rock is cut to fit the dragon. `_groove` carves a trough under the whole coil line, like a thread wound down the cone, worn in by its sleeping. Its walls rise steeper than the cone, so a lower turn never undercuts the turn above it.
- **Ruins:** a `tomb_chest` (its hoard, for later) sits on the shelf just past the snout, and a `fallen_pier` lies round the needle. Both are placed relative to the coil's head tip. I dropped the broken arch: the shelf is only a few metres wide.
- **Noise:** the crag noise is pure arithmetic hashed value noise (`crag`, `grain`), not a static `FastNoiseLite`. A static noise resource left "resources still in use" at exit.

## The coil and the sleep

`scripts/dragon_roost.gd` poses the dragon. `sky_dragon.gd` gets small hooks:

- `setup_roost` builds the model only: no route, gale or treasure.
- `advance` hands each frame to the pose, then runs its own `_night_glow`.
- V and G input are ignored while it roosts.

`studies/aqueduct_isle.gd` builds it as `roost_dragon` (`_build_roost_dragon`). It is shown only once the roost isle stands.

- **Line:** `Roost.coil()` lays the spine's rest length, from head tip (rest z -35.5) to tail tip (52.5), every 0.5 m. It winds about 1.1 turns down the upper cone.
  - The head rests on the shelf by the needle. The chest sits at `CHEST_AT` 215°, facing the aqueduct isle. The tail is lowest.
  - The belly falls 0.36 m per metre of body. Each point sits out from the axis where the cone is at its belly height, plus 0.75 of its girth, so the body bulges out of the flank.
  - `GIRTH` is the hide's reach round each bone, measured from the mesh (about the 90th percentile per bone).
- **On the rock:** each point is also checked against the actual ground. Its height is the highest the rock reaches under a disc of its girth, plus 0.2 m. The line is then eased to a slope of at most 0.75. The load prints the least clearance, which is 0.20 m (the gap). It never goes negative, so the body doesn't clip the rock.
- **Bones:** the dragon's frame is set at the chest joint. Two chains then run along the line: chest → spine.2 → neck.0-3 → head, and hips → tail.0-7. Each bone is turned so its child's joint lands on the line one bone length on, rolled so the belly faces the cone (up leaned out from the axis, `UP_OUT`). Its flight code is untouched. The coil works with its real spine; nothing is faked except the wings.
- **Wings:** they fold against the flanks. The arm points back, the forearm forward, and the hand and fingers back along the side, with membrane faces turned out. **The fingers are shortened to 0.42 of their length** with a bone scale. They are single rigid bones of about 30 m and can't follow the coil's curve; full length, they stuck out of the coil or into the needle.
- **Legs and head:** the hind legs fold flat at the hips' sides. The jaw is shut.
- **Eyes closed:** the eye surface is worn as hide, so it reads as lids. There is no eye glow and the night eye halos are cleared.
- **Breathing:** a 6.5 s breath. The chest swells sideways (4.5%), the neck lifts slightly, and on each out-breath a faint warm haze (CPU particles) puffs from the nostrils. The tail tip twitches on a spring every 6 to 14 s.
- **Night:** the dragon's own night glow still runs. The membranes glow rose at their folded trailing edges, the closed mouth shows an ember slit, and the eyes stay dark.
- **Size:** the roost dragon is **1.3**, and its rock is cut for that size (`DRAGON_SIZE`). At the flying dragon's 0.85 it looked like a lizard on a hill. At 1.3 it is about 114 m long and 11 m thick, so it reads as the mountain's owner.

## Captures

These are in `captures/dragon_roost/` (gitignored). `tools/capture_dragon_roost.gd` remakes them; it takes `--out=`, `--shots=` and any game flags.

| File | View |
| --- | --- |
| `round1_isle.png` | From the pilot's start on the aqueduct isle, the landmark read |
| `round1_mountain.png` | Mid view of the whole mountain |
| `round1_close.png` | Head resting on the shelf, the coil going down behind |
| `round1_side.png` | The trunk and folded wings round the cone |
| `round1_snout.png` | Out-breath haze, with the hoard chest by the nose |
| `round1_top.png` | Straight down: the full coil |
| `round1_night.png` | At 23:00 |

## What's weak

- **From the aqueduct isle (820 m)** the mountain reads as a landmark: the tallest, sharpest thing in the sky, with a dark shape and a glint of pink membrane on its top. But the coil isn't legible as a coil at that distance. The hide is dark against dark rock. From 250 m it is clearly coiled, and from overhead it is a full ring.
- **Folded wings** are the weakest part close up. The membranes bunch into crumpled panels and a fingertip panel hangs below the body. The finger shortening is a cheat. A proper folded-wing pose, or blend shape, in the Blender rig would fix it.
- **The tail** past mid-length is thin and sits deep in its groove, so on the far side it nearly disappears.
- **The needle and cone** facets are coarse (1.2 m grid). The groove is cut into a heightfield, so its inner wall is a steep smear rather than an overhang.
- **The haze** is a simple billboard puff and looks a bit solid up close.
- **The mountain is barely walkable:** only the meadow and some crag treads. The cone and shelf are rock you can't really reach on foot.

## Open questions

- **Size:** should the flying dragon grow to 1.3, or should the roost shrink? The same dragon at two sizes won't survive waking.
- **Waking:** the coil is a line of points. To wake, ease each bone from `_lay_chain`'s pose toward the flight `_pose`, head first. The neck lifts off the shelf, the trunk uncurls along the groove, and the tail slides out last, so the coil "unwinds" along the thread. The groove stays behind as its empty bed.
- **Visibility:** should the roost go into `places()` so clouds and airships keep clear, and so the flying dragon knows its home?
- **Readability from afar:** a lighter or warmer hide, a rim light, or a faint glow along the spine at dusk might help the coil read at 800 m. That needs a look call.
