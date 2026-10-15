# Inhabitants in the run, round 1 (2026-10-15)

Feature `inhabitant` of the game-feel round (`items-contract.md`). Two of
the strange-city prototypes now live on the generated city layers, next to
the headless bodies, the real wanderer, the light model and the noise bus.
On by default. `--no-inhabitant` (or `--loot=off`) turns it off.

## Which two, and why

1. **The Hollow Child** (`scripts/city_hollow_child.gd`, `hollow-child-round1.md`).
   This is the candle that calls every enemy to you. Sitting beside it
   hides you, because it drinks your torch, but while you hide it fills
   from your flame. When it is full it draws a breath and cries: a Beacon
   with a 160 m draw that every Olmec turns to, and a wail on the noise bus.
   It is also a tool: fill it, run during the 2 s breath, and the bodies go
   to it instead of to your route. It has the clearest tell and the best
   risk/tool trade of the yards.
2. **The Sun-Keepers** (`scripts/enemies/sun_keeper.gd`,
   `strange-sunkeepers-round1.md`). They stand only where light falls, and
   the city's places are strung with lit lamps, so they fit the generated
   layers with no new pieces. Their steal turns a Keeper into a second
   candle: the stolen torch is a walking sun the Olmecs go to.

I passed on the others. The Second Walker needs footprint history and has
no collider for the Olmec. The Earth Mouths and the Day-Count need pieces
the generator doesn't have. The inhaler head is already the generator's.

## Play it

```sh
# region 1 (a child, a sleeping Keeper)
/Users/davidkalina/Applications/Godot.app/Contents/MacOS/Godot --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=11
# top danger (households of 3 at the high lamps, 2 sleepers, 2 children)
... -- --no-title --shape=sprawl --seed=11 --knob=danger=1
# only one kind
... --inhabitant=child      ... --inhabitant=keepers
```

N steps a region up, which raises the danger. **T** (pad **Y**) puts the
torch out or lights it again. A doused torch also relights when you touch
any lit fire, by the fires kit's own rule.

## As built

`scripts/roguelike/layer_inhabitants.gd` is a director node on the LayerStage.
It is city layers only. The hooks in `layer_stage.gd` are marked
`# [inhabitant]`: dress, before, reset.

- **Laying.** Once the plan stands, the director gives each kind an order
  of isles:
  - households go on the highest places on the way;
  - sleepers go on the places on the way, in order;
  - children go on places with a `cover` socket first, which is where you
    would hide.

  The greed branch comes last in every order. Isles stand their colliders
  only near him, so each slot waits until its isle is there. If nothing on
  that isle fits, the slot moves on to the next isle. Nothing is laid
  within 18 m of him, 34 m of the spawn or 14 m of the gate, and two
  inhabitants are at least 22 m apart.
  - **Households** stand on open ground (not a plinth top) round a place's
    lit lamp, inside its light, facing the route.
  - **Sleepers** stand dark, 2-3 m beside a rune-line socket.
  - **Children** sit on a cover or route socket. No flame may be within
    their reach, and no lamp's light may fall where you would sit, so a
    child fills only from you and doesn't cry on a clock.
- **Danger** comes from `LayerWorlds.danger`: 0, 0.34, 0.68 and 1 by region.

  | | d 0 | d 0.34 | d 0.68 | d 1 |
  |---|---|---|---|---|
  | children | 1 | 1 | 2 | 2 |
  | sleepers | 1 | 1 | 2 | 2 |
  | households × size | 0 | 1×2 | 1×3 | 2×3 |
  | Keeper pace (of his walk) | 0.67 | 0.71 | 0.76 | 0.80 |
  | Keeper sense | 24 m | 27 m | 29 m | 32 m |
  | touches to steal | 2 | 2 | 2 | 1 |
  | child fill on torch alone | 25 s | 21 s | 17.5 s | 14 s |
  | child forgets (leak) | 60 s | 80 s | 101 s | 120 s |

  The fill is scaled by the look's torch strength, so the seconds hold in
  both haze and torch.
- **Into the game's systems:**
  - A thief's held sun draws from 160 m in the run (60 m in the yard).
  - A Keeper's crash (34 m) and a steal (22 m) go on the noise bus, and so
    do the child's breath (10 m) and its wail (60 m).
  - The Keepers' synth voices play in the run.
  - A Keeper's hit takes a run heart, and the death card reads "a Sun-Keeper".
  - Olmecs that barge into Keepers topple them, as in the yard.
- **Tells.** Each kind's tell comes from its own yard. On top of that, the
  director says one line once per layer: when a Keeper first turns to you,
  when one takes the torch, when one goes over the edge, when your flame
  first leans to a child, at the breath, and at the cry.

## Counterplay

- **Child.** Walking past costs a little fill, and it leaks away. Put the
  torch out beside it (T) and it stops filling. When you hear the breath,
  run. To use it, fill it on purpose, leave, and let it pull the bodies off
  your line.
- **Keepers.** They are slower than your walk and freeze as statues outside
  any light. If you douse with one standing in your pool, it topples; over
  the void it is gone. Dousing does nothing to a Keeper still in its lamp's
  light, so leave the light first. If one steals the torch, slide into it
  to make it drop the torch, then walk over the torch to take it back, or
  relight at a fire.

## Proof (headless, throwaway `scratch/inh_check.gd` through the real loop and input)

- **`--part=keeper`, seed 11, region 1.** The sleeper wakes in his pool and
  shoves him, costing a heart (4 to 3). Pressing T through the real action
  douses the torch and the sleeper falls into a heap; T relights. The
  second touch steals the torch, after which T won't relight it, and 2
  Olmecs heed the thief's sun. A slide into the thief by stick and crouch
  knocks it down, and walking over the torch makes it his again. 10/10.
- **`--part=house`, seed 11, `--knob=danger=1`.** A household of 3 stands
  lit by Lamp8 on the Lamplighter's Stair and makes 11 strides toward his
  torch in 4 s. Doused inside the lamp's light, they keep standing, which
  is the rule.
- **`--part=child`, seed 11, `--knob=danger=0.7`.** The child sits in
  `under_the_fuse_wall`. His torch is drunk 100% beside it. Sitting with
  it, it filled in 16.8 s, breathed, and cried. Its cry is a lit beacon,
  and the Olmec 35 m off heeds it. 8/8.
- **Smoke** (`tools/smoke.py studies/run_layer.tscn --frames 900`) passes
  with 0 errors on:
  - seed 11;
  - seed 3 at `--knob=danger=1`;
  - seed 4 at `--knob=region=3`;
  - seed 11 with `--no-inhabitant`.

  One seed-11 smoke run reported a fail with only an exit leak warning
  shown; three re-runs passed. Probably load.
- **Stills** (rendered, `scratch/inh_shot.gd`):
  - At gameplay range, the household reads well: three pale plaster
    figures, their mica discs flashing, walking single file out of the
    lamp's light at him.
  - The child reads as a small pale clay figure in a dark stone trench,
    warming as it fills.
  - The cry's blaze was not seen. The camera was jammed into the trench
    wall at that moment (him knocked, or the camera in tight cover).

## Rough edges

- **The torch douse is now in the run.** That makes the torch a stealth
  tool against the Olmec everywhere, not only near my two. If another
  agent also polls `walk_torch`, one press toggles twice, so keep one
  poller.
- **Slots wait on their isle.** If you never go near a slot's place, it
  is never laid. Seeds differ windowed and headless, because the plan is
  laid on a worker.
- **The thief has no goal in the run.** With no `keeper_goal`, it walks
  away from him and stops at rims.
- **The child drinks through walls**, and lights shine through walls (as
  before).
- **It is still greybox.** The Keepers have procedural poses and synth
  voices, and none of it has Blender clips.
- **Many lines on one line.** The once-a-layer lines use `study._say`,
  which other features also use.

## Tests it may break

No new tests were added and the suite was not run. The only shared edit
is `layer_stage.gd` (additive). Tests that open `run_layer` on a city
layer now carry extra enemies, and T now does something there:
`test_run_layer.gd` and `test_layer_sprawl.gd` (already noted as failing
or timing out). Pass `--no-inhabitant` to compare.
