# Hall chain: handoff

Branch `study/hall-chain`, from `study/hall-rise` (2b0582ba). Not merged, not pushed. Greybox study only. The hall rise study works as it did before; its shared scripts only gained additions that are off by default (see Files).

The ask: "once the player reaches a certain percentage or spot in the sundered hall chunk, it spawns another one. So, almost like you're continuously flying and they keep spawning in."

## How to run it

```
./run-hall-chain.command                        # in the plane, 170 m out, the first hall rising
./run-hall-chain.command --autopilot            # sit back: it flies the route hall after hall
./run-hall-chain.command --chain-at=0.5 --chain-gap=50   # later, tighter
./run-hall-chain.command --chain-mirror=off --chain-at=0.6 --chain-gap=100 --chain-turn=20 --chain-climb=4   # the first round
./run-hall-chain.command --chain-keep=3         # the oldest sinks sooner, to watch it go
```

It is also in the scene picker: Scenes, then Ruins, then "Hall chain".

Keys:
- **R** starts the chain again from the first hall, with the plane back at the start. **Shift+R** does the same with a new seed.
- **N** sets the next hall rising now (debug).
- **P** turns the autopilot on or off. Any real stick, key or mouse input takes over from it.
- **Enter** puts every standing hall in place at once.
- **C** cycles the cameras: plane, orbit (round the newest hall), free.
- **F** gets into or out of the plane. Boarding puts you 60 m before the newest hall's way in.
- **[ ]** slower or quicker, **\\** back to 1x, **O** orbit turns or holds.
- **M** shows the route (white dots) and each hall's trigger spot (gold).
- **Esc** frees the mouse.

The HUD's first line shows the hall you're on, how many halls have been made, how many are standing and sinking, the trigger and how far along you are, and the last spawn's main-thread cost.

### Flags

| Flag | Default | Does |
|---|---|---|
| `--chain-at=<0-1>` | 0.4 | how far along the newest hall's line (by length) the plane must get to set the next one rising |
| `--chain-gap=<m>` | 70 | the straight-line distance from a hall's exit to the next one's way in (the chord of the arc between them) |
| `--chain-turn=<deg>` | 8 | the most the next way in swings off the heading you leave on |
| `--chain-climb=<m>` | 2 | the most one hall stands over or under the one before |
| `--chain-mirror=on\|off` | on | the halls alternate hands (every other one is the hall mirrored) |
| `--chain-keep=<n>` | 8 | how many halls stand at once before the oldest sinks (0: they never sink) |
| `--chain-seed=<n>` | 3 | the placement seed |
| `--autopilot` | off | start with the autopilot flying |
| `--watch=plane\|orbit\|free` | plane | the camera to start in |
| `--rise=<m>` | 14 | the first hall's lowest stone over the cloud top |
| the hall rise's flags | | `--rise-speed`, `--chunk-gap`, `--rise-from`, and so on, as in docs/design/hall-rise.md |

The first round's defaults, for comparison:

```
--chain-mirror=off --chain-at=0.6 --chain-gap=100 --chain-turn=20 --chain-climb=4
```

Headless numbers (placements, then the autopilot timed through n halls):

```
godot --headless --path . -s tools/hall_chain_list.gd -- --fly=4 [chain flags]
```

## The second round: the next hall in front as you exit

Your feedback on the first round: "Looks good, but the spawning needs to happen earlier, or needs to be more in front of where the user exits."

The cause was structural. The hall's line comes in at -17° and leaves past the apse at -85°, so every hall turns you 68° right. With every hall the same way round, the gap had to swing you about 70° back left, or the chain would curl into a circle every 5 halls. That put the next gate 35–40° off your nose as you came out, on an arc. Cutting the ±20° variety alone would not have fixed it.

The fix comes in three parts:

1. **The halls alternate hands** (`--chain-mirror`, on).
   - Every other hall is the hall mirrored across its length (`RisePlan.mirrored`), so it swings you left where the one before swung you right.
   - The next hall's way in can then stand straight on the heading you leave on, and the chain runs on as a long S.
   - The gate is now within 1–5° of your nose at the exit (tested: within 8°; worst 5.1° over 40 placements).
   - The gap is a near-straight run: the "arc" swings only the ±8° variety.
2. **It triggers earlier** (`--chain-at` from 0.6 to 0.4).
   - At 0.4 you are about two-thirds of the way through the roofed gate half.
   - The next hall starts rising about 7 s before you come out of the apse. By then all four chunks have broken through and the gate is just coming up through the cloud, right ahead.
3. **It is closer, with less wander.**
   - The gap drops from 100 m to 70 m, so it is near enough to read as "right in front".
   - The turn drops from ±20° to ±8° and the climb from ±4 m to ±2 m, so the next hall sits close to the line you're on.

The gap of 70 m (not 60) is what keeps you arriving just after the gate is still: at 60 m the autopilot reached the gate 0.3 s after it went still, at 70 m it is about 1 s after.

## Trigger

The trigger is a share of the way along the hall's natural line, by length. The plane only counts while it is within 30 m of the line, so flying round the outside doesn't trigger it. Only the newest hall can trigger, and only once. With **M** on, a gold ball marks the spot.

## Spacing and placement

- **Hands.** Hall 0 is as built (it swings right), hall 1 is mirrored (left), hall 2 is as built, and so on.
- **The next way in** stands on the exit's heading, plus a seeded swing of up to ±8°. Each draw is pulled back by half the swings drawn so far, so the chain wanders but never drifts round. Over 40 halls the swings add up to at most 12°.
- **Its height** steps a seeded ±2 m from the one before, kept between 8 and 24 m of clearance over the cloud top.
- **Its way in** is 25 m before the line's first point, on the in-heading, and stands 70 m from the exit. It sits along the heading halfway between the exit's heading and the way in's, so one circular arc is tangent at both ends.
- **Overlaps.** A hall that would come within 12 m of any standing hall is drawn again (up to 8 tries). Over 40 placements none overlapped.

**Chunk order:** apse first, gate last, the hall rise's default. Seen from the exit, the far end is up first and the gate comes up last, right in front of you, as you leave.

With `--chain-mirror=off` the old geometry comes back. The arc then swings you back the hall's 68°, plus the turn, and the next gate is well off to the side.

## Timing (defaults, headless, autopilot at about 14 m/s cruise)

| | s after the trigger |
|---|---|
| The apse breaks through the cloud | 1.8 |
| The gate breaks through (all four are up) | 6.3 |
| **The plane leaves the hall** (rendered run: about 7 s) | **about 7** |
| The gate stops (0.35 m over its place) | 10.9–11.1 |
| The gate is still | 12.2–12.4 |
| **The plane reaches the gate** (the line's first point) | **13.3** |

The trigger-to-gate distance is about 205 m: 103 m of line left, the 78 m run, and the 25 m way in. When you exit, the gate is breaking through about 70 m dead ahead with its cloud ring, then it eases up and settles as you close in. The test checks that when you leave each hall, all four of the next hall's chunks are through and its gate is within 15° of the nose.

The first hall rises as you fly in from 170 m out, and you reach its gate after 13.3 s. A full hall, from one trigger to the next, takes about 18.4 s and about 255 m.

**Boost still outruns it.** At 22 m/s you reach the gate about 9.5 s after the trigger, mid-rise. A rising chunk passes through the plane, as in the hall rise, so it's harmless but early (open question 2).

## Behind you: the cap

The default is to keep 8. Past 8 standing halls, the oldest sinks back into the cloud and is freed once under.

- **Why 8:** 8 halls is about 2 km of chain behind you, about 2.5 minutes of flying, so you never see a hall you just flew through go and fog has mostly taken it. The cost stays bounded: at most 8 × 4 chunk nodes, 8 × 178 collision shapes and 8 × 3 draw surfaces, plus the one sinking.
- `--chain-keep=0` keeps every hall forever. Cost then grows by one hall about every 18 s.
- **The sink is the rise reversed,** sample for sample (tested: 0.000 m off). The gate goes first and the apse last. Each chunk lifts the 0.35 m it settled, then speeds down through the cloud top. The cloud swells, streams off its sides and bursts as its top goes under.
- **Nothing sinking is ever solid.** Collision goes off the moment the sink starts.
- **The oldest waits to sink while the plane is within 20 m of it.**
- **The route** (the autopilot's points) is trimmed along with the halls.

## Build cost

- The hall's chunks are planned once (`RisePlan.make`), mirrored once (`RisePlan.mirrored`), and only timed again for each new hall (`RisePlan.remake`).
- They are made on the worker, as in the hall rise.
- They are handed over **one chunk a frame**.
- All the halls share one set of materials.

Main-thread cost per hall, from `tools/hall_chain_list.gd --fly=4`, headless:

| | per hall |
|---|---|
| spawn (setup: retime and start the worker) | 0.15–0.31 ms |
| the heaviest frame's hand-over (one chunk) | 0.12–0.21 ms |
| everything, added up | 0.6–0.9 ms |

In the rendered runs (local captures):
- The first hall cost about 3.5 ms in all, with a worst frame of 3.05 ms, probably the first mesh upload and shader warm-up.
- Later halls cost 1.2–1.7 ms in all, with a worst frame of 0.3–0.6 ms.

Headless uses the dummy renderer, so GPU upload isn't in the headless numbers. The rendered figures come from single runs, not a profile.

## Cloud sea

The sea is the hall rise's: 5 km across, re-centred under the camera every frame (snapped to 20 m, with the heaps in world metres so it doesn't swim). It covers the chain wherever it has got to.

The swells from every rising or sinking hall are gathered, and the 6 nearest the camera go to the shader.

## The autopilot and the cruise lane

The hall's natural line is the moments line. It weaves over and under the tie beams every bay, about 6 m up and down every 16 m. A pursuit bot can't hold that at cruise: an early version bumped 125 times in 4 halls and crawled at 7 m/s. A casual player can't hold it either.

So the chain computes a **cruise lane** once (about 10 ms at startup). It follows the line's ground track, at the smoothest height that keeps 1.3 m off all stone, under the gate half's roof and about level with the far half's wall tops. The search is a shortest path over heights, at most 1 m of climb per 3 m sample, and it pays for clearance under 2.2 m. It comes out nearly level: y = 0 through the gate half, rising to 1.5 m through the far half, between the beams. Its worst clearance is 1.6 m.

The autopilot is a simple pure-pursuit pilot on the route. The route is each hall's way in, its lane, then the arc to the next hall. With an 8 m look-ahead it flies 4 halls with 0 bumps and never drops under 13.4 m/s. The natural line is still the trigger's measure, and you can fly it yourself.

## Tests (headless)

`tests/test_hall_chain.gd` takes about 21 s, so it has no suite tag. It passes under the runner, as do `test_hall_rise` and `test_scene_picker`. The headless import is clean. The full suite was not run.

It checks:
- **The lane:** 1.6 m clear of stone, gentle slopes.
- **40 placements:**
  - the hands alternate;
  - each next way in swings ≤ 8° off the exit heading, and each next gate is within 8° of the nose at the exit (worst 5.1°);
  - the climb is ≤ 2 m, with heights in range;
  - each way in is exactly `gap` from the exit;
  - the arc is tangent at both ends (0.01° off);
  - no overlaps;
  - the swings never add up past 30° (12°);
  - the same seed gives the same placements.
- **The trigger:**
  - no next hall before 40%;
  - exactly one at 40%, and still one by the end of the line;
  - nothing from far off the line;
  - the new hall rises hidden and settles solid, placed within the limits;
  - the hand-over is under 4 ms.
- **The cap (keep 2):**
  - the third hall sinks the oldest, which is not solid while sinking;
  - the sink is the rise reversed, gate first;
  - the oldest is freed after 11.7 s;
  - five more halls leave 2 up and 2 nodes, with the route trimmed.
- **Flying:**
  - the autopilot flies 4 halls in a row from the start;
  - it is never stuck (0 bumps) and never inside stone;
  - leaving each hall, the next one has all four chunks up through the cloud, with its gate within 15° of the nose;
  - each gate is easing in or still when the plane gets there.

## What's weak

- **Boost outruns the rise** (see the timing table). The trigger is a fixed point on the line, not based on time to arrival.
- **The rhythm is regular:** right hall, short straight, left hall, short straight. Only the ±8° turn and ±2 m climb vary it, and those are small now on purpose. The same hall, mirrored or not, adds to the sameness, which is fine for greybox.
- **The mirrored hall is a mirror image.** Anything handed in the kit (a torn edge, the screens) reads the other way round. That doesn't matter for greybox; a dressed kit might care.
- **Float precision:** the chain travels about 255 m a hall from the origin with no rebasing. After an hour, about 195 halls, it is roughly 50 km out, where float32 is still about 4 mm. Fine for a study, but a real version wants origin shifting.
- **The cruise lane is the autopilot's line and the route marks' line, not the moments line.** The tokens and moments of the in-world hall aren't placed in the chain at all.
- **Puffs still read as balls** close up, and the sea is the greybox sea, as in the hall rise.
- **Not flown by hand with the new defaults.** In the rendered autopilot run the next gate was breaking through dead ahead at the exit, with its cloud ring, and up and settling by the time the plane closed in (captures/hall-chain, local only). How it feels with the mouse or a pad is unchecked.

## Open questions

1. **Cap:** keep 8 (default), or never sink (`--chain-keep=0`)? Or a small cap like 3, so you sometimes see one go down behind you?
2. **Boost:** make the trigger time-based (spawn when the gate is about 13 s away at your current speed), or let boost arrive early?
3. **Rhythm:** keep strict alternation, or now and then two halls of one hand with a real arc between (as the first round had), for variety?
4. **Trigger and gap:** 0.4 with 70 m has all four chunks up as you exit and the gate settling as you arrive. Earlier still (0.3) would have the gate fully up as you exit, but it is hidden behind the roofed half while it rises. Is 70 m close enough, or tighter (`--chain-gap=50` with `--chain-at=0.5`)?
5. Should the tokens and moments come with each chained hall?

## Files

- **New:**
  - `scripts/hall_chain_plan.gd`: placement, arcs, the trigger's progress, the cruise lane
  - `scripts/hall_chain.gd`: the halls, the trigger, the cap, the route, swells, the autopilot
  - `studies/hall_chain.gd`, `studies/hall_chain.tscn`, `run-hall-chain.command`
  - `tests/test_hall_chain.gd`, `tools/hall_chain_list.gd`
- **`scripts/hall_rise.gd`** (additions, off by default, so the hall rise study is unchanged):
  - `setup` takes an optional `template` and shared `materials`;
  - `take_per_frame`;
  - hand-over measures (`frame_take_usec`, `take_total_usec`, `setup_usec`);
  - `sink()` (the rise reversed) with `sunk` and `gone`;
  - swells while sinking;
  - chunks made but never taken are now freed with the node (a chain could drop a hall before its build came in; this was a leak).
- **`scripts/hall_rise_plan.gd`:** `remake` (time a made plan again) and `mirrored` (the plan mirrored across the hall's length).
- **`scripts/scene_catalog.gd`:** the Ruins entry "Hall chain".
