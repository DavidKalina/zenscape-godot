# Ship guns: handoff

The pirate ships' fire, reworked (branch `iter/ship-guns`, off main a6b64912). Two
kinds of gun, a shot whose line hangs in the air, a bigger muzzle blast and a
splash. The ship's route, pose, solids and model are untouched; `iter/ship-rock`
and `iter/ship-look` own those.

## What changed

- **Hull guns: three a side**, fast and nearly straight as before (`BALL_SPEED`
  110, `BALL_DROP` 6, the same lead). Of today's glb's six a side, numbers 01, 03
  and 05 fire (z 40, 8, -24; `HULL_PICK`). The others are gone from the look:
  the glb's `Cannons` is one merged mesh, so each firing gun is cut out of it
  round its empty (`ShipGuns.cut`) into a piece of its own and `Cannons` is
  hidden. The quiet guns' ports stay open and empty. A glb with three empties a
  side fires all three with no change.
- **Deck guns: two a side**, on the top deck, that lob. Each swings (up to
  `DECK_SWING` off abeam) and lays its barrel onto the lob that would meet the
  plane now, while the plane is on its side within reach, then eases back to
  rest. It fires only once laid (`DECK_AIMED`). The lob has `LOB_DROP` 28 m/s² and
  a time aloft of 2.3 s at 110 m to 4.0 s at 560 m (`LOB_T`), thrown to come down
  where the plane will be if it holds its line. It climbs 15 to 50 m over the
  line to the plane. Its own cadence: one lob every `LOB_EVERY` 2.6 s per ship, a
  gun resting `LOB_REST` 5 s. Hull cadence went from 1.15 to `EVERY` 1.4 s.
- **Stand-ins** where the glb has no `DeckGun_*` empties (today's): at
  `DECK_GUNS` (x 7.6, z 19 and -11, mirrored), a drum and carriage in the
  ship's `wood.tres` and the hull gun's barrel cut from the glb, 1.45 times over
  (`DECK_SIZE`) in the outside `iron.tres`, so the barrels read over the rail.
  With `--ship-blocks` they are boxes.
- **The trail:** a ball lets go a smoke puff every 2.6 m (hull) or 2.2 m (lob).
  Each stays where it was let go, swells, lifts and drifts on the wind
  (`zs_wind_direction`), and thins out over 2.2 s (hull) or 4 s (lob), so the lob's
  arc hangs in the air (`gun_trail.gdshader`). The ball no longer carries a rigid
  streak; `ball_smoke.gdshader` is deleted.
- **Muzzle blast** (`ShipGuns._blast_mesh`): a flash and a tongue of fire, sparks,
  a ring of smoke thrown round the muzzle that stops a few metres off, and a cloud
  blown down the bore that slows, swells to 8 to 12 m and hangs about 7 s on the
  wind. The gun kicks back (`KICK` 1.4 m hull, 1.1 m deck) and runs out over 1.4 s.
  The boom is now heard far off (`BOOM_HEARD`; it was inaudible past 70 m).
- **Splash** (`ShipGuns._splash_mesh`), at the real water height
  (`game.water_at`, which is `sea_height`, or a river's level): a column of white
  water (streaks low, blobs high, drawn opaque with two tones, white in the sun
  and blue in shade), a boil of fat blobs at its foot, a crown, drops, then a
  skirt of spray, mist, two foam rings and a foam patch. A steep lob stands it
  26 m tall and straight; a skimming hull shot stands it about 9 m, slanted on
  along the ball's way (`SPLASH_TALL`, `SPLASH_LEAN`, `SPLASH_STEEP`). On land:
  brown clods and tan dust (`dirt`), no foam, plus `debris.burst("dust")`. A
  splash is heard within about 140 m (`SPLASH_HEARD`).
- **Whistle:** the lob coming down nearest the plane, inside 170 m, plays the
  air-whistle loop, pitched from high to low as it nears (`WHISTLE_*`).
- **Code:** `scripts/endless/ship_guns.gd` (new) holds the look: the pools, the
  meshes, the cuts. `pirate_ship.gd` keeps the firing: `_guns_step`, `_pick`,
  `_lay`, `_lob`, `_fire`, `_balls_step`, `_hull_guns`, `_deck_guns`. Shaders:
  `assets/models/pirate_ship/gun_fx.gdshaderinc`, `gun_burst_solid`,
  `gun_burst_soft`, `gun_trail`. Light comes from the clouds' palette
  (`cumulus_light`) as values, so smoke and spray go gray and white at every hour
  and don't take the gold.
- Guns fire from `transform*(local point)`, so they follow her rocking once
  `iter/ship-rock` lands. The deck guns' nodes sit under the model (or the ship
  with `--ship-blocks`).

## Knobs

`scripts/endless/pirate_ship.gd` top: `HULL_GUNS`, `HULL_PICK`, `EVERY`, `REST`,
`TELL`, `RANGE`, `ARC`, `BALL_*`; `DECK_GUNS`, `DECK_LIFT`, `DECK_MUZZLE`,
`DECK_SIZE`, `DECK_REST`, `DECK_SWING`, `DECK_RAISE`, `DECK_TURN`, `DECK_AIMED`;
`LOB_RANGE`, `LOB_EVERY`, `LOB_REST`, `LOB_DROP`, `LOB_T`; `KICK`, `KICK_S`;
`BOOM_HEARD`, `SPLASH_HEARD`, `WHISTLE_*`.
`scripts/endless/ship_guns.gd` top: `BLASTS`, `BLAST_LIFE`, `SPLASHES`,
`SPLASH_LIFE`, `SPLASH_HIGH`, `SPLASH_FALL`, `SPLASH_TALL`, `SPLASH_LEAN`,
`SPLASH_STEEP`, `DIRT_TALL`, `TRAIL`, `TRAIL_EVERY`, `TRAIL_R`. The shaders'
uniforms: `white`, `shade`, `band` (solid), `flash`, `white`, `dust`, `soft_reach`
(soft), `life`, `swell`, `rise`, `opacity` (trail). The throw of every bit is
baked in the two mesh builders.

## Contract for the model round

Her frame as in `pirate-ship-handoff.md` (metres, -z bow, +x starboard, origin at
the waterline amidships). Names are exact; `NN` counts from the stern.

**Hull guns:** empties `Gun_L_01..03`, `Gun_R_01..03` at the muzzle, -z out of the
bore. The code finds how many there are by looking for `Gun_L_04`. For the kick,
either give each gun its own mesh node `Cannon_L_01..03` / `Cannon_R_01..03`
(barrel and carriage; it slides back along its empty's +z, 1.4 m, so leave room
inboard), or keep a merged `Cannons`: then the code cuts each gun out of it,
taking the triangles within 7.5 m inboard of the empty, 1.5 m to either side,
2.5 m under and 1.4 m over it, and hides `Cannons`. Separate nodes are safer.

**Deck guns:** empties `DeckGun_L_01..02`, `DeckGun_R_01..02` at the mount's pivot
on the deck, -z outboard, y up. Under each, as direct children in this chain:

| Node | Origin | Moves |
|---|---|---|
| `DeckGun_X_NN_Mount` (mesh) | the pivot (its rest transform is kept) | turns about its own y: up to 1.05 rad either way |
| `DeckGun_X_NN_Barrel` (mesh, child of the mount) | the trunnions, bore along -z | lays about its own x: -0.05 to 0.95 rad up, 0.22 at rest; slides 1.1 m back along +z for the kick |
| `DeckGun_X_NN_Muzzle` (empty, child of the barrel) | the muzzle's mouth | the ball, tell and blast come from here |

A deck gun with an empty but no `_Muzzle` gets a stand-in at its empty; no empty,
a stand-in at `DECK_GUNS`. Sizes the stand-ins use, as a guide: trunnions 3.1 m
over the deck, muzzle 5.6 m on from them, barrel about 1.6 m across at the
breech, mount about 4 m across. The barrel needs to clear the rail at 0.22 rad and
swing clear of shrouds, masts and the boat over its 120 degrees; today's stand-ins
at z 19 and -11 clip a shroud near the mainmast at full swing (look only). They
read over the rail from off her beam only because they're big; smaller guns would
want a raised platform. Nothing here collides: keep them outside `solids()` or say
so.

## Proved

Headless, on real input through `tools/drive.py` (`scratch/guns/guns.gd`, not
committed). Six straight lines past the first ship, 250 to 420 m off her beam,
14 to 24 m up, both ways:

| Run | Hull shots | Hit (within 2.9 m) | Near (2.9 to 16.9 m) | Lobs | Hit | Near |
|---|---|---|---|---|---|---|
| Hold the line | 25 | 2 | 11 | 16 | 2 | 8 |
| Dodge (a hard turn for 1 s at each lob) | 32 | 0 | 5 | 18 | 0 | 0 (closest 28 m) |

Held, the lobs' closest passes were 1.0, 2.8, 3.3, 3.4, 4.2 and 4.3 m: they come
down on the plane or a few metres off it (the plane's speed wanders as it holds
height), then splash 20 to 40 m on along its line. The hull shots' were 2.1, 2.6,
2.9, 3.1, 3.7 m. The ship counted 7 hits over the held run. Turning on each lob
took every lob 28 m or more wide. Each run had one crash, both on the same driver
line launched beside an island (13 frames after the launch, onto land), not from a
ball.

- Both ships fire both kinds (`--part=second`: the second ship alone, 13 shots, 5 of them lobs, 2 hits in 15 s).
- `--ship-blocks`: the same guns and effects on the gray box, the second ship again 13 shots, 5 lobs, 2 hits; `smoke.py ... -- --ship-blocks` passes.
- Smoke: `python3 tools/smoke.py studies/endless_flight.tscn` passes, 0 errors.
  `--ship-start --full-meter` and `--ship-blocks --ship-start` time out in the
  smoke tool after 400 clean frames because the game hangs on quit with
  `--ship-start`. That hang is not this round's: it happens with `--no-ship` too
  (a worker thread waits at exit; the main thread waits on it). The same 400
  frames run with 0 errors in `scratch/guns/hang.gd` (8 shots, 3 lobs, splashes,
  355 puffs).
- Rendered, looked at and iterated (Mac, 1440x900, the full preset a harness run
  gets; `scratch/guns/views.gd` and `look.gd`, not committed), in
  `scratch/guns/shots/` (git-ignored): `sheet_lob_play.png` and `lob_play_16.png`
  (a lob's arc from the chase camera, with hull shots streaming past),
  `sheet_splash_{lob,skim}_{30,100,300}.png` (a plunge and a skim at four ages,
  from 30, 100 and 300 m), `blast_hull_sheet.png`, `blast_deck_sheet.png`,
  `sheet_deck.png` (a deck gun laying on and firing), `sheet_dirt.png` (a land
  hit); and in `scratch/guns/v/`: `gun_top.png`, `gun_out.png`, `gun_far.png`
  (the stand-ins; three hull guns a side).

## What a splash and the pools cost (from counts)

- A splash: 2 draw calls (solid, soft), 99 + 22 discs, 242 triangles.
- A blast: 1 draw call, 62 discs, 124 triangles.
- The trail: 1 draw call per ship, 1024 discs, 2048 triangles, drawn while any
  puff is alive; dead ones collapse in the vertex stage. Its buffer (64 KB) is
  written whole once in a frame a puff was let go.
- Full pools, one ship: 10 splashes, 8 blasts and the trail: 29 draw calls and
  about 5.5k triangles. No material or mesh is made per shot; the CPU sets one
  instance uniform (`age`) a frame per live splash or blast.
- Guns: the six cut hull guns are 3 surfaces each (18 draw calls inside 700 m,
  where `Cannons` was 3); the four deck stand-ins are 3 each (12, inside 910 m).
- No frame times: other agents share the GPU.

## Unproved

- Hand flying: dodging by hand, whether the lob's fall and the whistle read in time.
- The whistle and the new boom and splash levels are unheard (headless, no ears).
- The PC, other hours (night: smoke and spray take the cloud palette's values,
  never looked at), rain and fog.
- Splash on a river and the land burst were seen once each (land: one still).
- The deck gun's swing was seen in stills only, not in motion at speed.
- Interaction with `iter/ship-rock`: the deck guns sit under the model, which that
  branch may move differently from her transform.

## Tests

No committed test touches `pirate_ship.gd` or the new files. The only test that loads endless flight, `test_cloud_shade_steady.gd`, is `suite: gpu`, so it is skipped headless and wasn't run. No test is known to break.

## Launch

```
cd /Users/davidkalina/Documents/Projects/zenscape-ship-guns && python3 tools/play.py --no-pull -- --pilot-file=/tmp/ship-guns.json --ship-start --full-meter
```

The plane starts 240 m off the first ship's beam, 16 m up, flying her way, under
fire. Hold a line to be hit; turn when a lob goes up to watch it miss. On quitting,
a `--ship-start` run may hang (see above): close the window or Ctrl-C the terminal.
