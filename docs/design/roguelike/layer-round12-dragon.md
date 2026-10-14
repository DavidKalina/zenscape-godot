# The generated layer, round 12: the dragon live over a layer (2026-10-14)

> Branch `feature/dragon-in-layer`, cut from `roguelike` at c46295af. A demo
> round: the smallest playable build so you can watch the dragon live in a
> generated layer. No new tests.

The ask: "For the dragon, can we work on seeing how he would play in the
generator? Like maybe we can have him swoop, or monitor the level from a
distance. Maybe we can do the cling attack every now and then? Just need to
see how that would look."

## Run it

```sh
./run-dragon-layer.command                          # sprawl seed 11
./run-dragon-layer.command --shape=ring --seed=2    # the ring
```

Or directly:

```sh
~/Applications/Godot.app/Contents/MacOS/Godot --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=11 --dragon-live
```

Without `--dragon-live`, run_layer is unchanged and the dragon stays asleep.

About 3 s after the loading screen lifts, he wakes on his roost. This is the
existing wake: his eyes open, his head lifts and he roars (9 s), then he
takes off on heavy beats with dust and birds (8 s). After that he runs his
loop over the layer. The first swoop comes about 35-40 s in, depending on
how far off the roost stands.

Good seeds:

| Seed | What you see |
|---|---|
| sprawl 11 | The first swoop goes over the aqueduct isle you start on, right overhead. He grips the Vigil of the Bellows (sprawl's only roomy isle on this seed) across the gulf, in view from the start. |
| ring 2 | He swoops over the isle nearest you in view: the start isle in a headless run, the Plumb Well in the rendered run, where the camera faced another way. He grips the Sundered Gorge. |
| sprawl 4, ring 3 | Smoke-checked only (no captures). |

### Keys (on foot, once the layer stands)

| Key | Does |
|---|---|
| U | Wakes him now |
| J | Swoops next (at once if he's flying; after the grip if he's on a rim) |
| K | Grips next (the roomy isle nearest you in view, not the one you're on) |
| H | Back to his high circuit. On a rim, he lets go first. |
| V | His camera: chase, orbit, look from here, off (existing) |
| G | He lets go of the rim (existing) |

The layer card (top left) has a "Dragon: ..." line with what he is doing
now and the keys. Each change of behaviour also shows a toast and logs a
`layer dragon:` line.

### Flags

| Flag | Default | Does |
|---|---|---|
| `--dragon-live` | off | Turns all of this on |
| `--dragon-wake-at=<s>` | 3 | Seconds after play begins before he wakes. Also turns on live mode. |
| `--dragon-first=swoop\|grip\|monitor` | swoop | His first behaviour once he's up |
| `--dragon-monitor=<s>` | 25 | How long each high circuit lasts |
| `--dragon-grip-hold=<s>` | 22 | How long he holds the rim. His own default is 45-60 s. |
| `--dragon-swoop-over=<m>` | 30 | The swoop's height over the highest solid under his line |
| `--dragon-circuit=layer` | near | Rings the whole layer instead of the isles near you |
| `--dragon-no-blast` | blast on | No air blast when he spots you. Used for the captures. |
| `--dragon-watch[=chase\|orbit\|look]` | off | Starts on his camera once he flies |
| `--dragon-log` | off | Prints where he is, his height and his sight every 2 s |

## What each behaviour does

He runs **swoop, monitor, grip, monitor** round and round
(`scripts/roguelike/layer_dragon.gd` `ORDER`). A key you press jumps the
loop to that behaviour, and the loop carries on from there.

- **Monitor.** A slow, high ring round the isles within 260 m of you (180-340 m
  across, `NEAR_R`). It sits 70 m over the highest solid under it and inside
  it, with a 10 m rise and fall, and is bent clear of his roost
  (`ROOST_CLEAR`, 110 m past its reach). The ring is laid again from where
  you are each time he goes back to it. His head turns in and down to the
  ring's middle (new `SkyDragon.gaze`). If his sight is tracking you, that
  wins. On seeds 11 and 2 the ring was 265-281 m round and 131-166 m up.
- **Swoop.** He picks the isle nearest you, preferring one in your view and
  never the same isle twice in a row. That includes the base you start on.
  He comes in from 300 m out, 40 m over the pass height, and goes down to
  `--dragon-swoop-over` (30 m) over the highest solid along a 60 m band
  under his line (the plan's occupancy). He crosses the isle's middle and
  climbs out 60 m higher. His head looks down at the isle on the way in.
  Over the aqueduct isle that put him about 48 m over the turf. The existing
  downwash fires its ground gusts on each downstroke (`reach_ground` up to
  0.96 in the logs), which bends the grass, trees and water through their
  wind shaders. That reaction is the existing system, unchanged.
- **Grip.** He picks the isle nearest you in view that passes his own room
  rule (`SkyDragon._has_room` on the built isle's shape). It is never the
  base and never the isle you stand on. Then he calls the existing
  `grip_isle` and runs all the existing beats: the wide approach, flare,
  slam (staggers you if you're near the rim), pant, inhale ("take cover"),
  gale across the isle, last haul, let go, and the snap that throws a pilot
  standing on it. The isle tips (9 degrees held on the Vigil). The way in is
  lifted 25 m over anything under its line. After he lets go, he goes back
  to the circuit.
- **Sight and air blast.** These are on whenever he flies (`blast_on`), as
  in the vision greybox. If he spots you he roars, winds up and fires; the
  shockwave knocks and stuns you through `PilotMotor.knock`, with no damage
  numbers. Cover pops the blast ("The blast pops on cover"). On seed 11 he
  spotted and blasted the pilot during the first swoop over the start isle.
  In one capture run the blast knocked the idle pilot off the isle into the
  void, which ended the run (the card). That is the real knock-off rule.
  Use `--dragon-no-blast` if you only want to watch.

## What was built

- **`scripts/roguelike/layer_dragon.gd` (new): the controller.** It wakes
  him, hands him from the wake to full flight, lays the circuit and swoops
  from the plan, picks grip targets, and applies the blast to the pilot. It
  also gives his grip each isle's record (`DragonIsleShape`, as the aqueduct
  isle's `_dragon_isle`, but keyed by the plan's isle id), and handles the
  keys, the card line and the toasts.
- **`scripts/sky_dragon.gd`:**
  - `go_live(...)`: off the wake's takeoff and into the whole flight. It
    drops the roost, builds the gale and air blast, and skips the treasure.
  - `gaze`: a point his head turns to when nothing else holds it.
- **`scripts/dragon_wake.gd`:**
  - The ledge reads the roost pose's `offset`. Before, it always read
    `Roost.AT`, so a moved roost took off from the wrong place. For the
    aqueduct scene the offset is still `Roost.AT`.
  - New `wake_now()`.
- **`studies/run_layer.gd`:**
  - `--dragon-live` makes the controller per layer (`_live_dragon`).
  - A dragon woken on the last layer is laid again asleep on the next one.
  - The keys U, J, K, H and the card line.
- **`run-dragon-layer.command`** (new).

## Captures (rendered, judged by eye)

The captures are in `captures/dragon-in-layer/sprawl11/` and `ring2/`, both
git-ignored. Each folder has `sheet_a.png` (rise, swoop, monitor) and
`sheet_b.png` (circuit from above, grab, pant, blow, from you, leaving).

What reads well:

- **Takeoff.** He rises off the roost against the sky (sprawl `01_rise`).
- **Swoop.** Seen from the start isle, he is huge and right overhead, mouth
  open, wings up. From above (ring `03`-`05`) he dwarfs the isle he crosses
  and reads clearly as low over it.
- **Grip.**
  - The flare onto the rim, wings spread (sprawl `08_grab`).
  - The neck reared over the turf while he hangs off the flank (ring
    `09`, `10`).
  - The blow streaks across the isle.
  - The isle visibly tipped.

What is weak:

- **The monitor reads as a pale ghost.** At 250-350 m the scene's haze
  washes him to a light grey silhouette (sprawl and ring
  `06_monitor_from_you`). It looks eerie and atmospheric rather than menacing.
  A closer or lower ring, or a haze exception for him, would make him darker.
- **His camera clips through the isle while he leaves a rim** (sprawl
  `12_leave` is inside the rock). This is the old chase framing, not this
  round's work.
- **The grass reaction can't be judged from stills.** The logs show the
  ground gusts firing under the swoop. Whether the sweep reads in motion
  still needs a look in play.
- **The circuit seen from above, banked hard** (`07_monitor_orbit`), looks
  like a near-vertical dive. That is just the orbit camera's angle on a
  51-degree bank in a 265 m ring.

## Checks (headless)

- **Import:** clean.
- **Smoke** (`tools/smoke.py`, run_layer):
  - `--dragon-live`, 1800 frames each: sprawl 4 and ring 3 pass with 0
    errors.
  - Without the flag: sprawl 6 passes.
  - `aqueduct_isle --dragon-wake` passes.
- **`tests/test_dragon_wake.gd`** passes. No other tests were run.
- **Throwaway drive** (`scratch/dragon_live.gd`, real play loop; it asks for
  the grip after the first swoop, then another swoop):

  | Seed | Wakes | Flying | First swoop | Grip | Lowest over any solid while flying free | Inside an isle's occupancy |
  |---|---|---|---|---|---|---|
  | sprawl 11 | 3 s | 20 s | aqueduct isle | Vigil of the Bellows, slam at 64 s, let go at 87 s | 39 m | 0 frames |
  | ring 2 | 3 s | 20 s | aqueduct isle | Sundered Gorge, slam at 65 s, let go at 90 s | 32 m | 0 frames |

## Breaks

No existing test is known to break.

- Without `--dragon-live`, nothing in run_layer changes.
- The wake's ledge change keeps `Roost.AT` for the aqueduct scene.
- `gaze` defaults to off.

## Open questions for you

1. **Few isles have room for his grip.** Of the greybox motifs, only the big
   ones pass his room rule at size 1.5: the Sundered Gorge and the Vigil of
   the Bellows. The Plumb Well, Warden's Well, Sunken Giant and Noon Weir
   rims sit 17-31 m out, under the 35 m needed. On a seed with neither, K
   falls back to a swoop. Options:
   - grow those motifs;
   - let him grip at a smaller size;
   - relax the rule for the layer.
2. **Should the monitor ring be closer and darker?** Today it is 70 m over
   the local top and 180-340 m round the isles near you. A lower or tighter
   ring would read as watching rather than a faint shape in the haze.
3. **Should he ever swoop the isle you stand on?** Right now he does, and on
   the start isle it is the most felt moment. The catch is that he spots you
   from there and blasts.
4. **Does he go home?** He never returns to the roost in this demo. The wake
   still has its landing if he should settle after a while.
5. **The blast on an idle player knocked them into the void and ended the
   run.** Is that the intended stakes for layer 1?
