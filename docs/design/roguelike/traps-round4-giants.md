# Traps, round 4: the Tumbling Block and the Sky Ray (2026-10-12)

> Greybox only. Branch `feature/trap-giants` (off `roguelike`). Built to the
> contract in traps-round1.md; no contract change. The user on round 3 (small
> logs, small flip slabs): "I was thinking more like larger platforms that
> slowly rotate. Like a giant cube that you have to constantly stay on top of.
> Or something reminiscent of the sand bird in Mario Sunshine."

    godot --path . res://studies/trap_yard.tscn -- --no-title --trap=tumble
    godot --path . res://studies/trap_yard.tscn -- --no-title --trap=ray

Test: `godot --headless --path . --script tests/test_trap_giants.gd`.

Yard change (`studies/trap_yard.gd`): two TRAPS lines, and lanes are laid at an
accumulated x: a trap may define `lane_extra()` (m) to ask for room east of its
lane (the ray's loop). Others are unchanged (LANE apart).

## The Tumbling Block (`scripts/traps/trap_tumble.gd`), cost 4 (5 over the void)

### Round 4b: the roll gets teeth (branch `enhance/tumble`, 2026-10-12)

The user, after playing round 4: "The rotating platform thing had no danger to
it whatsoever." Played headless through the real play loop (the yard with
`--trap=tumble`, its own `_process` frames, input actions) before changing it:

- Standing still on the round-4 cube he was slid to the back edge in about 2 s,
  and the motor's careful step-off lowered him into a hang. The trap only
  carried him while his feet were near the block, so once the hang's feet
  left that band he stopped being carried and hung in mid-air for good. He
  never fell; nothing ever threw him.
- The slow continuous roll (0.29 rad/s) with a 1 m bevel on every edge let a
  station-keeper (walk uphill, hop what blocks him) ride 40 s over several
  face changes without one real jump. The face changes were just walked over.
- There was a floor a layer down under the lane, and the slip was a steady
  ~1 m/s that walking cancels out.

What changed:

- **Bigger, over real void.** 7.3 m a side (6.5 x his height). The yard lays
  no floor under its lane (`open_below()`, the `floor` knob; one opt-in line
  in `studies/trap_yard.gd`), so a fall goes to the yard's `lost` height and
  respawns him at the lane's start.
- **A rhythm with a lurch.** A face rests flat (`rest`), tips slowly to `tip`
  (33 degrees, halfway between the motor's SLOPE_SLOW and SLIDE_AUTO) over
  `tip_time`, then **lurches** the rest of the quarter turn in `lurch`
  (0.45 s, a small hop's airtime, ~2.2 rad/s) and stops dead. The tell, `tell`
  s before it: the block's look shudders (the colliders don't), dust pours
  off the top's edges, every face warms to orange, and it sounds `grind`.
  `lurch` sounds as it goes and `slam` as it stops. The pace ramps the longer
  he rides (`ramp`/s up to `ramp_top`: shorter rests, quicker tips).
- **The lurch throws.** Grounded on a face as it passes `throw_at` (the motor's
  44-degree slide angle) during the lurch: `motor.knock` at `throw` x the
  stone's own velocity under him (tumbling, no ledge catch). Hanging from a lip
  whose face passes it: shaken loose (`motor.toss`). Grounded on the block
  when it stops dead: jolted on at `jolt` x the stone's velocity (a knock over
  half a walk). So the skill is to be in the air through the lurch (jump at
  the end of the shudder; land after the stop to dodge the jolt) or in the
  pocket. The hang is now carried while its lip is on the block, so a hang
  is a real (short) refuge until the lurch.
- **Slick stone.** Past `slick` (13 degrees) the face slides him down its
  fall line, gaining `slip` x (sin tilt - sin slick) m/s², up to `slip_top`,
  unless he is moving uphill faster than `grip`. Walking up it, the slide
  bleeds away. Stood still, he goes over the leading edge during the tip.
- **No walk-over.** `bevel` defaults to 0 (knife edges). The 1 m chamfer is
  still a knob, and the face change is the lurch anyway.
- **Features that turn into him.** Face 0: a sweeper bar (`wall_h`) that runs
  along the face toward the leading edge at `sweep` while face 0 is up and
  shoves him before it unless he hops it. Face 3: the pocket, a rebate a
  plate deep and `pocket` wide at its trailing edge, open on top and behind.
  In it the slick and the lurch don't move him, but he is carried round, and
  after the lurch it is a step `pocket` under the new top's leading lip: hop
  up, or hang and climb. Face 2: the prize (a glowing rune marker, picked up
  by standing next to it while face 2 is up, two lurches in; `prize_taken`,
  sound `prize`) between two low walls. Face 1: a raised step over its
  trailing half; its lip is a handhold. The ends are plain walls (wall kick).
- `lurch` 0 gives back round 4's steady roll (`spin`, `pause`). `yaw` is as
  before.

| knob | default | meaning |
|---|---|---|
| size | 7.28 m (HEAD x wanderer x 6.5) | cube side |
| plate | 0.72 m (small jump x 0.9) | face plate thickness; the pocket's depth |
| bevel | 0 | edge chamfer (round 4 had 1 m: a walk-over) |
| rest | 2.28 s (0.75 x size / walk) | a face resting flat |
| tip / tip_time | 33 deg / 3.03 s (size / walk) | the slow tip before the lurch |
| lurch | 0.45 s (a small hop's airtime) | the fast rest of the quarter turn; 0 = round 4's steady roll |
| tell | 0.79 s (1.75 x the hop) | the shudder before the lurch |
| slick / slip / slip_top / grip | 13 deg / 15.6 m/s² / 4.8 m/s / 0.6 m/s | where stone gets slick; the slide's gain (gravity x 0.6), cap (his run), and the uphill pace that holds it off (walk x 0.25) |
| throw_at / throw / jolt | 44 deg / 0.8 / 0.35 | the tilt that throws in a lurch; shares of the stone's velocity given to a thrown / jolted rider |
| ramp / ramp_top | 0.015 /s / 1.8 | pace gain per second ridden, and its cap |
| sweep | 0.96 m/s (walk x 0.4) | the sweeper bar's pace along face 0 |
| wall_h / step_h / pocket | 0.56 / 0.72 / 0.8 m | jump height x 0.7 / x 0.9 / x 1 |
| prize | true | the rune marker on face 2 |
| floor | false | lay the yard's floor a layer down under it after all |
| shake | 0.045 m | the shudder's size (look only) |
| spin / pause | 0.198 rad/s / 0 | the steady roll (`lurch` 0 only) |
| dir | +1 | +1 the top moves back toward the entry (the pocket assumes it) |
| yaw | 0 rad/s | later tier: a slow turn about the vertical too |
| gap | 1.43 m (0.6 x a running small hop's reach) | deck to cube, each side |
| top | 0 | resting top's height over the decks |

Route use: jump in from the entry deck onto the resting top, ride it round
(uphill as it tips, airborne through each lurch) until face 2 comes up with the
prize, then jump off the resting top to the far deck.

Verified (headless, `tests/test_trap_giants.gd`, the tumble part through the
real play loop: the yard unscripted, its own frames at the project's 60 fps,
the stick and jump pressed as input actions, the camera held along the route):

- standing still he is in the void in 5.5 s (one rhythm is 5.8 s);
- placed a body and a half from the leading edge as the shudder starts,
  walking uphill, the lurch throws him into the void;
- a station-keeper who hops what blocks him but never jumps the lurch is thrown
  at the first face change;
- a scripted skilled rider (holds the uphill side as it tips, hops the bar and
  walls, jumps a moment before each lurch, climbs from a hang) rides 5 lurches
  in 26 s, takes the prize, the pace ramps to x1.32; he is still jolted on 3
  of the 5 stops (lands before the stop) and survives them;
- in the pocket he rides a lurch unthrown onto the step, then hops up onto the
  new top;
- carried, never teleported; grind, lurch and slam sounded;
- the yard loads headless (`--quit-after 300`).

Unverified (tumble):

- Feel in a window: whether the shudder, dust and warm-up read in time, the
  bar's pace, how hard the jolt and throw feel, how high the void feels. No
  rendered run was made.
- Getting on from the entry deck and off to the far deck by real jumps; the
  prize as a reason to ride (it is a marker only, nothing counts it yet).
- Face 1's step lip as a handhold in play; wall kicks off the ends; `yaw`;
  `dir` -1 (the pocket then sits at the leading edge); the `bevel` knob on the
  lurch rhythm; the steady mode (`lurch` 0) after the rewrite.
- The ramp past x1.3 (the test rides about 26 s).
- The thrown rider's tumble on the block (he can land on it tumbling and be
  carried until the stop jolts him off).

## The Sky Ray (`scripts/traps/trap_ray.gd`), cost 4 (5 over the void)

A broad slab (6.7 x 9.0 m) with two raised ridges, a head, a tail and two
wing edges (visual only), flying a closed stadium loop beside the decks: the
near straight runs level past both decks' east edges (board from the start
deck's edge, get off at the far deck's), then it turns east, climbs and dives
over a hump (`height`) on the far half and banks into both turns. The pilot is
carried with its full transform delta (bank and pitch swing him round) and slid
down the back's tilt toward the low edge. Tells, `tell` s ahead: the head dips
before a dive; the outer wing edge lifts and warms before a bank; `whoosh` as a
bank starts, `screech` as a dive does (placeholder sounds).

| knob | default | meaning |
|---|---|---|
| width / long / thick | 6.7 / 9.0 / 0.8 m | the back |
| speed | 4.8 m/s (his run) | pace along the loop |
| radius | 8.4 m | turn radius |
| height | 7.8 m | the hump over the far half |
| max_bank / max_pitch | 0.45 / 0.35 rad | bank in a turn / pitch cap |
| bank_lag | 0.5 s | settle time; also how early it banks before the turn |
| slip | 2.16 m/s | slid down the tilt (x sin tilt) |
| shake | 0 rad | wobble about its length that sheds a rider |
| tell | 1.0 s | how far ahead the head and wing cues show |
| ride | 22.4 m | route length (deck to deck) |
| edge_x / gap | 5.0 / 1.07 m | decks' east edge; jump gap to the ray's side (0.45 x reach) |
| lead_in / lead_out | 10 m | straight past the decks |

A lap is about 100 m / 4.8 m/s, roughly 25 s wait if he misses it.

## Verified (headless, tests/test_trap_giants.gd)

The cube (round 4b): see its section above. On the ray he is carried along
its path (14 m in 3 s with the ray) and in a hard bank slides to the low edge.
The test runs the ray first: the tumble part runs the yard unscripted, and every
trap is stepped by those frames.

## Unverified

- Feel and pacing in a window (speed): no render here. The cube's list is in
  its section.
- Boarding the ray by a real jump from the deck edge (moving platform timing),
  getting off at the far deck, `shake`, `yaw`, and the pause mode.
- Tells are colour and placeholder sounds only.
