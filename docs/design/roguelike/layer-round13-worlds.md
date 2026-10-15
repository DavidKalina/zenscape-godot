# The generated layer, round 13: worlds, under then sky (2026-10-14)

> Branch `layer/under-sky-pools`, cut from `roguelike` at eeb8e2c0 and
> merged with `roguelike` at 2e2d8198 (hearts, the title, the climb-up).
> A prototype round: smoke checks and throwaway drives, no new tests.

The ask: a run starts deep underground in the abandoned Olmec city and
climbs to the sky. Underground: the dark look, the city kit, the Olmecs, the
rune serpent, no plane. The sky is the old world: the gothic ruin kit, the
dragon, the clouds, the plane.

## Play

```sh
./run-run.command                                   # a run: 2 regions underground (haze), then the sky
./run-run.command --seed=7 --shape=ring --under-look=torch
./run-game.command                                  # the title, then the same run (torch underground)
```

Or directly:

```sh
<godot> --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl [--seed=2]
```

N (Shift+N) steps a region on (back), so the second N from the start reaches
the sky. The long card (I) has a "Region 2 · underground (the Olmec city) ·
no plane" line.

## The world model and knobs

`scripts/roguelike/layer_worlds.gd` (new) holds the whole model. Each
region's plan carries its world in its knobs, so the plan, the next-region
silhouette and the study all read one source:

| Knob / flag | Default | Does |
|---|---|---|
| `region` (knob) | set by the study | Which region of the run this is: 1 is the first. 0 means outside a run's count and reads as sky, as before. |
| `--under-regions=N` / `--knob=under_regions=N` | 2 | How many regions from the first are underground |
| `--world=under\|sky` / `--knob=world=` | "" | Forces every region into one world |
| `--region=N` | 1 | The region a launch (and every new climb) starts at. `--region=3` starts in the sky. |
| `--under-look=torch` | haze | The underground regions' look. `--underground=haze\|torch` still forces the look on every layer, the sky's too, as before. |

- Sprawl and ring keep alternating by depth inside each world
  (`LayerShapes.after`, unchanged).
- The study (`studies/run_layer.gd`) asks every plan for a region:
  - the gate (run_loop) asks the region one on;
  - N and Shift+N ask one on and one back;
  - Backspace keeps the region;
  - a new climb starts at `--region` (1).
- `LayerSprawl.next_plan` lays the next region with the region one on, so
  past the last underground gate the silhouette far off is the sky's. That
  is also the plan the gate takes from the cache.
- **The readout.** The coordinator's merge note wins: the brief says the
  player reads the height climbed from the run's start, and it always goes
  up. So underground there is no offset and no negative altitude. The
  climb-up round's true heights carry straight through. The world shows only
  in the arrival caption: "OPEN SKY" (run_loop WORDS `arrive_sky`) through
  the last underground gate, "HIGHER STILL" elsewhere. My first cut read
  depth below the surface (-500 m, rising); it was dropped in the merge.

## The pool tags

- `scripts/kit_isle/greybox/registry.gd` has a new `WORLD` table: slug ->
  "under" or "sky", with `world_of(id)`. Untagged is sky, so every old motif
  and every kit motif in LayerPlan POOL stays where it was.
- `stacked_court` is "under". It is the only underground motif.
- `LayerPlan.draw_pool`:
  - **Sky region:** the named pools ("motifs", "classic", "all") are the
    same pools as before, minus the under-tagged motifs.
  - **Underground region:** every under-tagged motif, whichever named pool
    is set.
  - **An explicit list** (`--knob=pool=a+b`) is taken as asked, in either
    world.
- Underground, a motif may come any number of times a layer
  (`LayerWorlds.UNDER_REPEATS`).
- Underground, the gulfs are the rune serpent's: the `ride` knob defaults to
  serpent. The ring tries the serpent first and keeps the ferry only as a
  fallback.
- Underground, the sprawl has no extra isle per neighbourhood (`hood_more`
  0): three courts won't fit in one neighbourhood.

### How thin the underground pool is

**One motif.** Every underground layer is 4-7 Stacked Courts and the
aqueduct base. To make that work at all, the court changed:

- **More ways in and out**
  (`scripts/kit_isle/greybox/gb_stacked_court.gd` `rims`). The generator
  never turns an isle, and the court had one way in (south) and one way out
  (north-east), so no court could join another (`no way onto
  gb_stacked_court` on every seed). It now has:
  - ways in on F's south, south-east and south-west faces;
  - ways out on T's north face and the summit (north-east).
  - The pairs that join court to court are north to south and north-east to
    south-west.
  - F's turf is tucked inside the stone on its three south faces (it hung
    4 m past the stone, so the rims had ground past their lip). Each rim
    stands 2.6 m in from the stone's edge.
  - A way out on U's north-west face was tried and dropped: its collars stand
    under the lip.
- **The turf caps' overhang is in the occupancy** (`parts`). The crossings'
  corridors ran through the caps' hanging earth (the layer test caught
  `Turf_forecourt/Body` in a corridor).
- **`vary(seed)`.** `LayerPlan._motif_isle` calls it with the isle's own
  seed on any non-family motif that has it. It changes only what doesn't
  touch the shape:
  - the pillars' stone seeds and weathering (±0.15-0.2);
  - the turf caps' ragged edges;
  - the fallen drums' lie;
  - the Keeper's seed;
  - which of the five cressets are already lit (30% each; a lit one draws no
    Olmec).
  
  **The shape is identical every time, and every court faces the same way.**
  The generator places isles by moving them only, and a greybox motif's
  occupancy is cached per slug. From above a layer reads as one court
  copy-pasted, staggered in height and spacing. Real variety needs more
  underground motifs, or courts that can turn.
- Plans lay well: sprawl 12/12 and ring 12/12 on seeds 1-6 (an earlier cut
  failed sprawl 6, which run_layer skips past to the next seed).

Plan dump, `python3 tools/sweep.py tools/layer_dump.gd --seed 1..4 --shape
sprawl,ring --knob region=1,3` (before the last rim change; the
`layer_dump` RESULT now has `world`, `region`, `motifs`):

| shape | seed | region | world | isles | motifs |
|---|---|---|---|---|---|
| sprawl | 1 | 1 | under | 5 | gb_stacked_court x4 |
| sprawl | 1 | 3 | sky | 11 | gb_rootbound_cut x2, gb_vigil_bellows, ... |
| sprawl | 2 | 1 | under | 5 | gb_stacked_court x4 |
| sprawl | 3 | 1 | under | 7 | gb_stacked_court x6 |
| sprawl | 4 | 3 | sky | 8 | gb_editor_hill, gb_plumb_well, gb_rootbound_cut, ... |
| ring | 1 | 1 | under | 7 | gb_stacked_court x6 |
| ring | 2 | 3 | sky | 8 | gb_sunken_giant, gb_vigil_bellows x2, ... |
| ring | 3 | 1 | under | 8 | gb_stacked_court x7 |
| ring | 4 | 3 | sky | 6 | gb_vigil_bellows x2, gb_sunken_giant x2, ... |

All 16 laid with no problems. No sky plan holds a stacked court; no
underground plan holds anything else.

## The world sets the look and the rules

- **The look.** The study's `_world_look` runs when a plan is taken, before
  its isles are made, so the ground cover and the motifs' `Underground.on()`
  checks see the right world. It sets two statics on
  `scripts/underground/underground.gd`: `world_on` and `world_preset`.
  - `Underground.on()` is now the flag, or the run's world.
  - `GroundCover.asked()` asks `Underground.on()`.
  - Under: the look is stood (`attach`, now idempotent).
  - Sky: it comes off live with the new `Underground.detach` / `restore`.
    That gives back:
    - the environment values it held (snapshotted at setup, the sky
      included);
    - every node it hid, at its own earlier visibility;
    - the cloud sea;
    - the torch (freed), the motes, `zs_under`;
    - the ground grade (the palette republished).
  - The climb-up round's `climb_lift` still eases the torch preset toward the
    haze by depth. It is static, so a look stood again keeps it.
  - The statics are reset when run_layer exits.
- **The plane.**
  - **Underground:** none. It isn't parked (`_unpark`) and its figure is
    hidden. `park_home`, `board` and `board_parked` do nothing, so `--fly`
    does nothing too. F on foot is swallowed.
  - **In the sky:** it is parked again by the new start (`_world_plane`
    after the start spot). A sky-to-sky gate leaves it where it is, as
    before.
  - The plane tokens are hidden by the look already.
- **The dragon.** Sky only. The sprawl and ring lay no roost underground,
  so the study drops the roost dragon. The sky regions get the roost as
  before (`--dragon-live` still opt-in).
- **Olmecs.**
  - Each court brings its Keeper (a whole Olmec on the well's ring), the
    summit head and its body.
  - The generator's own heads on perches stay in both worlds.
  - The drive counted 4-7 headless bodies and 9-14 head nodes in an
    underground layer.
- **The transition.** The gate already raises the warm veil, and windowed it
  brings up the loading screen while the next plan lays. The look switches
  in `_take`, behind both, so the sky is simply there when the screen lifts,
  with the "OPEN SKY" caption. No new fade.

## Proof

- **Plan dump:** the table above.
- **Through the real play loop** (`scratch/worlds.gd`, uncommitted): it
  opens run_layer, checks region 1, walks onto the gate (the run loop's own
  `after_tick` asks the next region) twice, and checks region 3. 16/16
  checks on sprawl 2 and ring 3, 0 errors.
  - **Region 1** is under, with only stacked courts. The look is on (haze,
    fog 0.0016). There is no plane parked, `board`, `board_parked` and the
    fly key don't fly, and there is no dragon.
  - **Region 3** is sky, with sky motifs only. The look is off and the day's
    sky is back (fog disabled as the day has it). The plane is parked and
    drawn, and the roost and its dragon are laid.
  - **Height:** 0 m, then 162 m, then 275 m (sprawl 2); 0, 113, 295 (ring 3).
  - Not tried: real key presses for boarding. `press(&"fly_land")` and the
    direct calls were used.
- **Rendered stills** (`scratch/worlds_shots.gd`, a rendered drive through
  both gates; downscaled copies in `docs/design/roguelike/layer-round13-worlds/`):
  - `under_arrival.png`, region 1:
    - the haze;
    - the torch on the wanderer;
    - the courts' basalt pillar-isles and crowns stacked round in the
      murk;
    - "THE CLIMB", 0 m, the hearts;
    - no plane.
  - `under_region2.png`, region 2: the same air, the next court's pillars
    standing off in the haze.
  - `sky_arrival.png`, region 3:
    - the full day back: gold turf, sun shadows, the cloud sea;
    - the plane parked by the start;
    - "OPEN SKY", 275 m.
  - The flip reads as a real change of world, not a glitch.
  - Weak:
    - the underground base is still the aqueduct isle, so the arrival is
      meadow under haze, not the city;
    - the HUD's foot hint still says "Walk to your plane" underground.
- **Smoke checks** (`tools/smoke.py`, 400 frames, all 0 errors):
  - run_layer:
    - sprawl 2 (default: under);
    - ring 3;
    - `--world=under` sprawl 4 and ring 2;
    - `--world=sky` sprawl 6 and ring 4;
    - round 3's shape (seed 5);
  - `studies/game_title.tscn` with run-game's flags;
  - the motif yard: `stacked_court` (haze) and `plumb_well`.
  - Rerun after the merge with `roguelike`.

## Launchers

- `run-run.command` (new): a normal run.
- `run-game.command`: `--underground=torch` became `--under-look=torch`. The
  old flag forced the dark on the sky regions too.
- `run-underground.command`: adds `--world=under` (every region
  underground, as it was meant).
- `run-dragon-layer.command`: adds `--world=sky`, so seed 11 is the sky
  layer the round-12 doc describes.

## Tests (prototype round: none changed)

`tests/test_run_layer.gd` and `tests/test_layer_sprawl.gd` open run_layer
without `--world`, so **they now play underground layers**.

|  | roguelike 2e2d8198 | this branch |
|---|---|---|
| test_run_layer | FAIL (2): rim `out` ground past its lip, seeds 1 and 2 | FAIL (3): greed hard not crossed on foot, seeds 15 and 1; a serpent jump off its back short of the far pier, seed 15 |
| test_layer_sprawl | FAIL (5) | FAIL (13) |

test_layer_sprawl's failures on this branch:

- **Expected, because the world changed:**
  - "the roost stands", "its N motif isles stand (the roost too)" and "a
    dragon's roost of its own": underground has no roost;
  - "neighbourhood 2 stands 7 m over the last": one court a neighbourhood.
- **Open:** the scripted crossings onto and off courts fail on a few seeds
  (route climb and route trap on seeds 3 and 6). The baseline fails similar
  crossings on sky motifs: route climb seed 6, the viaduct, the serpent's
  far pier, "Into the void".
- **On both:** the test's own `Out of bounds get index '0'` error.

A lock-in round should run these with `--world=sky` (their old meaning) and
add an underground pass.

## Limits and open questions

1. **The pool is one motif.** Every underground layer is copies of the
   Stacked Court, the same shape facing the same way. More city motifs are
   the real fix, or a court that can be turned or mirrored.
2. **The base is the aqueduct isle** in both worlds: a gothic ruin meadow,
   lit by the haze, is where every underground region starts. An
   underground base (a plaza of the city kit) would sell the city.
3. **Sky things still underground:**
   - the gust-arrow perches;
   - the Broken Viaduct, the Loose Voussoirs and the rope bridges (gothic
     kit);
   - the ferry, where no serpent loop fits.
4. **The dragon in the sky is asleep unless `--dragon-live`.** Should the
   run turn him on in sky regions?
5. **The crossings onto the courts' new rims** pass the plan's checks and
   the rim probe, but a few scripted crossings in the layer tests fail.
   Worth a walk in play.
