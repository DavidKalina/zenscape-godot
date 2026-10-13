# Dragon grip, round 2: the grip in the vision greybox, wired into the hit stun

Branch `feature/dragon-grip-greybox`, made from `roguelike`. The ask: "I want to wire up the ability where he basically grabs onto the island and pulls on it", and "wire that into the hit stun".

## What was built

- **The grip is one of his attacks in the vision greybox** (`studies/dragon_vision_study.gd`). It is `--attack=grip`, and K now cycles blast, grip, cyclone, none.
  - When he spots you on (or up to `OVER_ISLE` 60 m over) one of the three isles, he breaks off his loop and grips that isle.
  - The grip runs as on the motif isles: the slam onto the rim, the tip, the pant, the inhale (the tell), the gale blown across the isle, the last haul (`pull_down`, the tell), the let-go, and the snap.
  - He then rejoins his loop at the loop point nearest ahead of him, and leaves you alone for `GRIP_REST` (8 s).
  - Off the isles (on a walkway, or flying elsewhere) the grip falls back to the air blast.
  - While you're on an isle, or while a grip is under way, the blast is held.
  - His downwash and sight work as before while he flies. On the rim he is blind, so his awareness drains, as on the aqueduct isle.
- **Route chosen: grey isles that act like a large motif isle.** I adapted the flat grey boxes rather than placing a real motif isle.
  - Each isle is a `GreyIsle` node holding `_outlines`, `_turf` and `isle_top()`, which are what `scripts/dragon_isle_shape.gd` `build` reads off a motif isle. The real sampler builds each record (`_isle_record`, in the same form as the aqueduct's `_dragon_isle`), with no new shape code.
  - Each isle's body, turf and cover (wall, pillars, roof, posts, block, ledge) now sit under its own node, so the tip moves all of it, collision included.
  - This was less fragile than bringing in the motif-isle pipeline and kept the greybox plain.
- **The isles were enlarged to pass the room rule at 1.5** (`ROOM` 35 m from the middle to the rim). The rule itself is untouched.

  | isle | before | after | gripped at |
  |---|---|---|---|
  | home | 64 m square | 84 m square | rim 43 m out |
  | roof | 48 x 40 m | 80 x 40 m, moved to x 110 (posts and block kept 29 m and 49 m in from its west end) | rim 40 m out, 95% open |
  | flat | 50 x 36 m | 80 x 36 m | rim 40 m out |

  - The walkways and the loop's roof point follow the moved and enlarged isles. The cover keeps its sizes (WorldScale openings, RuinKit heights).
- **`spare_home`** (new var on `scripts/sky_dragon.gd`, default true): when false, his "never within 60 m of the host's middle" rule is off. The greybox sets it false because none of its isles is a starter isle. The aqueduct isle keeps the default.
- **New in `scripts/sky_dragon.gd`:**
  - `grip_isle(i, hold, near)`: off to grip target `i` now.
  - `grip_pick`: the host's callable for the pilot's isle index, or -1.
  - `grip_hold`.
  - `_grip_attack`.
  - `_rejoin_loop`.
  - `_on_the_way_in`: `--dragon-attack`'s start placement, moved into its own function.
  - The `grip_beat(what)` signal for a host's toasts.
- **Toasts:**
  - "He grabs the isle!"
  - "Staggered!"
  - "He draws breath: take cover!"
  - "Blown off your feet!"
  - "He hauls on the rim: hold on!"
  - "Thrown!"
- **Footer:** the K line now reads "K: his attack (blast, grip, cyclone, none)".

## The stun (the knobs, in `scripts/sky_dragon.gd` beside KNOCK_OUT)

Every grip hit calls `walker.knock(v, self, down)`. Because the dragon is the source, the grip shares one restun gap (`PilotMotor.restun_gap`, 1.2 s) with his air blast.

| knob | value | what |
|---|---|---|
| `BLOW_STUN_DOWN` | 0.8 s | The gale's knock (`_blow_on_pilot`) is a hard hit: no poise in the air, laid down 0.8 s once the skid stops. |
| `LAUNCH_STUN_DOWN` | 1.5 s | The snap's launch (`_ride_isle`) is a hard throw, laid down 1.5 s where he lands. |
| `SLAM_STAGGER_R` | 12 m at 0.85 (21 m at 1.5, scaled by `_k`) | The slam staggers a pilot standing on the isle this close to the gripped rim. |
| `SLAM_KNOCK_OUT`, `SLAM_KNOCK_UP` | 3, 0.5 walker heights | The stagger: a light knock in from the rim (away from the edge). |
| `SLAM_STUN_DOWN` | 0 | The stagger isn't a hard hit, so he only lies for the tumble's own `tumble_down`. |
| `GRIP_REST` | 8 s | After a grip, no new grip for this long. |
| `GRIP_HOLD` (greybox) | 12 s | How long he holds on: one blow, then the last haul. |

- **The restun gap holds** because the grip's hits are many seconds apart: the slam, then the first blow (settle 2.6 s, pant 4.5 to 7 s, inhale 2.1 s), then the throw (after at least one more pant and the 0.85 s pull). In the test run the stuns came 12.8 s and 8.6 s apart.
- **A blow only knocks once per blast** (`_knocked`), and the launch only fires on the snap.
- **The stun is shared, not greybox-only.** It is in `sky_dragon.gd`, so the aqueduct isle's grip (`--dragon-ride`, `--dragon --dragon-attack`) now stuns too. Checked headless on the aqueduct ride:
  - the slam staggered the pilot 15.7 m from hollow_keel's rim
  - the gust knock was a hard hit
  - the launch at 31 m/s was a hard throw
  - no errors

  One change there: `ride_spot` starts the pilot about 14 m in from the rim, so the ride's first slam now staggers him. If that's unwanted on the ride, lower `SLAM_STAGGER_R` or skip the stagger when `ride` is set.

## How to play it

```sh
godot --path . res://studies/dragon_vision_study.tscn -- --no-title --attack=grip
godot --path . res://studies/dragon_vision_study.tscn -- --no-title --attack=grip --grip-now
```

(`godot` is `/Users/davidkalina/Applications/Godot.app/Contents/MacOS/Godot`.)

- **`--grip-now`** sends him in to grip home about 0.6 s after the start, from the way-in point `--dragon-attack` uses. He doesn't need to see you first, and the slam comes about 8 s in.
- **Standing near the rim he grips** (within 21 m) gets you staggered by the slam.
- **Standing in the gale's path** gets you blown.
- **Standing on the gripped side when he lets go** gets you thrown. The launch is strongest near the rim; at the pivot or on the far side it is a small hop.
- **`--place=x,y,z`** puts you on an isle to start: flat `20,26.2,-100`, roof `135,34.2,0`.
- **Walk off onto a walkway** and he blasts instead.

## Verified headless

- **Import:** clean.
- **Load checks:**
  - `res://studies/dragon_vision_study.tscn --quit-after 2400 -- --no-title --attack=grip --grip-now` exits 0. It prints the slam on home's rim (43 m out, 100% open), the tip (8.7° held, 17.9° at the haul), the inhale, the pull, the let-go, and the launch with "a hard throw stun, down 1.5 s".
  - The default attack (`-- --no-title`) still blasts and knocks as before.
  - Exit leak warnings ("N ObjectDB instances leaked", "resources still in use") show on the base branch too.
- **Spotted path** (`--place` on each isle, `--attack=grip`):
  - flat and roof are each spotted, gripped, blown and thrown (roof launch 18 m/s).
  - On the roof walkway he fires the blast, which threw the pilot onto the roof, and then he gripped the roof.
- **`tests/test_dragon_grip_stun.gd`** (new) passes in 38 s. Run it with `python3 tools/run_tests.py --tests test_dragon_grip_stun.gd`. It goes through the real play loop: the study's `_process`, the motor on the isle's collision, `--attack=grip --grip-now`, with the pilot set down 10 m in from the planned rim. It checks:
  - the slam staggers him
  - the isle tips 23° at most
  - he never sinks into the tipped turf (-0.01 m at worst)
  - he rides it on every held frame (1167 of 1167)
  - the inhale, pull and let-go beats arrive
  - the blow knocks him (hard)
  - the snap throws him at 27.6 m/s
  - he is laid down and up again 3.5 s after the throw
  - no two of the dragon's stuns fall within the restun gap
  - the dragon rejoins his loop
- **The aqueduct `--dragon-ride` load check** is described in the stun section above.
- I didn't run the full suite or any other tests.

## Unverified until played

- **How it reads and feels in a window:** the claws on the grey rim, the head on the grey turf, the tip, the toasts' timing, the camera through the throw. I made no rendered runs or captures.
- **The walkways stay put while an isle tips**, so their ends step up or down at the isle's edge during a grip.
- **The stun values** (0.8 s, 1.5 s, the stagger's 3 walker heights) are first picks. Nobody has played them yet.
- **The spotted grip's approach** goes the long way round (`_attack_way`: 240 m out, 130 m aside), so from spotting to slam is about 10 to 15 s. If that's too slow, give the greybox a shorter way in.
- **The plane over an isle** counts as "over" it, so he grips the isle under a flying plane. The grip's gale reaches the plane as a gust (`plane_gust`, now merged into the greybox's `plane_air`, as on the aqueduct isle). A `--fly` load check with `--grip-now` exits clean, but nobody has flown through the gust.
- **Cover against the gale** (the wall on home, the block on the roof) goes through the gale's ribbons, as on the motif isles. Whether hiding behind them reliably spares you isn't tested.
