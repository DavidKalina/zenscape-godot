# Dragon roost, round 2: asleep on a ledge

Branch `look/dragon-roost-2`, made from `look/dragon-roost` with main merged in (one conflict in `studies/aqueduct_isle.gd` `_add_life`: the roost/sky-dragon choice is kept first, then main's watcher block). This is a look study. There is no waking, chasing, stealing or ledger work.

Run it with `./run-dragon-roost.command`, which passes `--no-title --dragon-roost`. Add `--fly` to start in the plane, or `--hour=23` for night. Without the flag the game is unchanged, apart from the flying dragon's new size (see Size).

## Size

- **The dragon is 1.5**, asleep and flying alike. `scripts/sky_dragon.gd` now has `const SIZE := 1.5` (it was `var size := 0.85`). `--dragon-size=` still overrides it. At 1.5 it is about 132 m from snout to tail tip.
- The grip reach and the treasure scale from `TUNED_SIZE := 0.85`, the size they were tuned at, as before.
- The roost takes its size from `SkyDragon.SIZE`, so the same dragon can wake and fly.
- 1.5 is a starting point and may go to 1.7. The mountain is laid out in "layout metres" at 1.5. `SPAN = SIZE/1.5` scales the whole mountain with the dragon, so a bigger dragon gets a bigger ledge and tower without retuning.
- `--dragon` loads headless at 1.5. Its routes, threads and attack clearances were tuned at 0.85 and haven't been checked at 1.5 in flight.

## The mountain

`scripts/kit_isle/motif_dragon_roost.gd`. It is still one height function, `ground(x, z)`, built through `KitLand.island`. The whole layout is in a frame turned to the aqueduct isle: `v` points toward it, and `u` runs across, toward the viewer's left.

- **Where it stands:** `AT` is now `(520, 55, 475)`. Its middle is about world (610, 455), 710 m from the aqueduct isle, down from 820 m, so the dragon reads larger.
  - It is 120 m clear of the hollow keel's reach and 250 m or more off every airship loop.
  - Its turf is 55 m over the aqueduct isle's.
- **Massif:** stepped crags with creased buttress faces. The creases are folded sines, so the faces break into planes. They fall from the ledge's height to a strip of turf, steepest under the ledge's outer edge and broadest toward the aqueduct isle. There is no cone and no hex plate: the outline is a wandering blob (R 80).
- **The ledge** (`LEDGE_C`, r 22, 50 m over the turf) stands out on the aqueduct isle's left side. Its floor is dished 1.8 m with a 1.1 m lip.
  - The floor is worn bare (turf `wear`), so it reads as earth rather than grass, and no plants grow on it.
  - It is scattered with pale bones (six long bones and two broken rib cages, built in `bones()`), floor slabs, a fallen pier and the tomb chest (the hoard) in the middle of the curl.
- **The summit tower** (`TOWER_C`) rises behind the ledge: steep flanks to a shoulder at 82 m, then a broken peak at 100 m, with a lower spur (64 m) beside it for a lopsided outline.
- **The neck's shelf:** `_groove` cuts a shelf into the tower under the neck's line. It now also carries rock under the line where the tower falls short, at 2.2 m down per metre past half the girth. The neck lies on rock all the way, rather than over air.
- **Pale rock:** `_pale` warms and pales the crag faces round where the dragon lies (within 7 m of the line) and the ledge's rim and the crag under it. Main's rock look is basalt, so the dark hide reads against a sandstone-coloured ledge and shelf. The dragon's own dress is unchanged.
- **Ruins below the ledge:** two broken stair flights on the front crags and a pointed-arch shrine and pier stump on the turf.
- **Clouds and airships:**
  - `MotifSky.stood_places()` now includes the roost when it stands, and the aqueduct sky's `places()` returns it. So the cloud towers and puffs keep off it.
  - The airship loops are fixed waypoints, and the nearest passes 250 m outside its reach.
  - The CPU biplanes' buzz list still uses the static `places()`, so they don't visit it.

## The pose

`scripts/dragon_roost.gd`, laid on the mountain's line (`Roost.coil()`). The neck goes round the front of the tower, the side the aqueduct isle sees: round the back, it would hide the coil.

- **Chest:** on the ledge's inner side, by the tower's foot.
- **Trunk and folded hind legs:** along the ledge's back.
- **Tail:** round the outer rim and back along the front rim, curled round the hoard like a cat's. The tail doesn't drape over the edge any more: a tail hanging down a sheer heightfield face never touches anything under it, so it would always hover.
- **Neck:** rises from the chest round the front of the tower on its shelf, about 190° of turn.
- **Head:** rests on the shelf on the tower's far flank, chin down, horns against the sky, with the peak above it.

### Settling (the hard requirement)

The old fixed 0.2 m gap over girth-sized discs is gone. `_settle()` skins the hide on the CPU from the mesh's bones and weights, all 5537 vertices. It then runs 14 passes. In each pass:

1. Every hide point is given to the nearest point of the line.
2. Each line point goes to the height where its hide just touches the ground. That is the highest of `ground under the point - its drop under the spine`, taken over its points and its neighbours' (±2).
   - On the nest's worn floor it sinks `SINK_NEST` (0.15 m); on rock it sits at `SINK_ROCK` (0.03 m).
   - The first passes ease toward that height; the last five only raise, so nothing is left in the ground.
3. Head and neck points with nothing within 4 m under them may hang (the snout off its shelf). The trunk and tail always come down onto what is under them.

The load prints what is left. Current numbers:

| Measure | Value |
| --- | --- |
| Largest gap under the trunk, legs and tail | **0.85 m**, at line point 168, near the tail's tip on the front rim |
| Largest gap anywhere | 2.37 m, at line point 63: the base of the neck where it lifts off the ledge toward the tower. This one is an arch, not a hover. |
| Deepest any hide point sinks into the ground | 0.84 m |
| Deepest any folded-wing point sinks into the ground | 1.48 m (wings don't bear weight in the settle; see the wing section) |

"Gap" here is the lowest hide point's clearance over the ground under it, per stretch of about a bone's length.

The low captures (`round2_low.png`, `round2_low_back.png`) are taken at ledge height, where a gap would show. The trunk and tail lie on the floor and rim.

### Kept from round 1

The 6.5 s breath (chest swell and a slight neck lift), the nostril haze on each out-breath, the tail-tip twitch, closed eyes, the night glow (rose membrane edges and the ember mouth slit), the jaw shut, the `--dragon-roost` flag, and `--dragon` losing to the roost when both are passed.

## Wings

They now fold close along the flanks: arm back, forearm forward, hand and fingers back, all level or a little up, with the membrane faces turned out. The fingers are shortened to `FOLD` = 0.36 of their length with a bone scale. Nothing hangs under the body any more.

Close up, though, the membranes still bunch into crumpled, faceted panels at the shoulder and hip. One forms a small arch over the flank (see `round2_low.png`).

What the rig would need for a proper fold:

- **Fingers that bend:** each wing finger needs two or three segments (a knuckle mid-finger), not one 30 m bone. Then the folded fingers can follow the trunk's curve instead of being shortened.
- **A folded-wing shape key** (or an authored rest-fold action) in `rim_dragon_c.blend`, so the membrane between arm, forearm and fingers collapses into tidy pleats rather than whatever the stretch-skinned panels do when the bones close.
- **Membrane weights** that let the trailing edge tuck under the forearm: a few vertex rows weighted to the forearm and hand rather than only to the fingers.

## Captures

These are in `captures/dragon_roost_2/` (gitignored). `tools/capture_dragon_roost.gd` remakes them. Its new shots are `isle_zoom`, `nest`, `summit`, `low`, `low_back` and `back`.

| File | View |
| --- | --- |
| `round2_isle.png` | From the pilot's start on the aqueduct isle, normal lens |
| `round2_isle_zoom.png` | The same line of sight narrowed to 14° (what the eye picks out) |
| `round2_mountain.png` | The whole mountain from the aqueduct side |
| `round2_nest.png` | Over the ledge nest: the curl round the hoard, the neck rising round the tower, the head on its shelf |
| `round2_summit.png` | The neck and head round the summit, from the front |
| `round2_low.png`, `round2_low_back.png` | At ledge height, to check contact |
| `round2_back.png` | From behind the tower |
| `round2_night_night.png`, `round2_night_isle_zoom.png`, `round2_night_nest.png` | At 23:00 |

## What's weak

- **From the aqueduct isle at a normal lens,** the mountain is still small (about 710 m off). The dragon reads as a dark, horned shape lying along the ledge and up the tower, with a purple glint, on a pale band.
  - With the narrowed view (`isle_zoom`), it is plainly "a dragon asleep on a mountain": horns against the sky, spines along the back, the trunk on the ledge.
  - At the normal lens, a stranger might need a second look. Moving it closer or growing it to 1.7 would help.
- **Wings,** as above: the biggest close-up weakness, and the rig's to fix.
- **The tower** is a big plain faceted cone above the shoulder. Up close it lacks the ruin dressing the lower crags have.
- **Night:** the dragon reads only as a silhouette with a faint rose wing. The ember slit and membrane edges are small at this distance.
- **Sinks:** about 0.84 m at worst for the hide (a claw or chin into the nest floor), and the wing panels up to 1.5 m into the floor or shelf in places.
- **Headless runs** sometimes report "1 resources still in use / ObjectDB instances leaked" at exit. It also appears on plain runs without `--dragon-roost`, so it isn't the roost's, but it isn't traced.
- **The flying dragon at 1.5** isn't checked in flight: its thread gaps and isle clearances were tuned at 0.85.
