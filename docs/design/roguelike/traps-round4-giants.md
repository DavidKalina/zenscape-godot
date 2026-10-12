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

Enhanced on `enhance/sky-ray` (2026-10-12) after the user played it: "The
Manta was cool, but it never made me slide off. I never felt like I was gonna
fall off."

### Why it didn't slide

Reproduced through the real play loop (the yard with `--trap=ray`, real
`_process` frames, the pilot standing still, then holding a direction):

- The "slip" was a constant-speed drift (`slip` x the back's tilt, at most
  0.94 m/s at its 26 degree cap, eased in over the 0.5 s bank lag) pushed
  through `motor.carry`. No momentum, no friction, no swing: 40% of his walk,
  so any stick input outran it, and only one bank in each 5.5 s turn.
- Reaching the rim that slowly, the motor's careful step-off catch always took
  the lip: he never fell. The hang was then not carried (the riding test
  wanted his feet on the back), so he hung in mid-air while the ray flew on.
- The ray flew the near straight away from the start deck: a rider who boarded
  there was 22 m (4.7 s of level straight) from the far deck and never met the
  banks or the hump at all.
- His own braking was not eating it (carry moves the feet, not his run), but a
  plain drift is all it ever was. The old test pinned the bank by hand (and
  the wrong way round), so it passed on a slide play never produced.
- Found on the way: the ray's new pose reached the physics server only when
  the tree flushed transform notifications, after the frame's motor step, so
  his ground rays read the back where it was a frame before (about 0.3 m off
  in a dive). `_pose` now pushes the transform to the server itself.

### What it does now

The loop runs the other way: past the far deck, then the start deck, so a
rider who boards at the start deck rides the whole loop (about 23 s) before
the far deck comes by. The back is a thin hide out to the rim over a thick
body inset from it, with four ridges: one along each rim (left forward, right
aft, open back between) and two across.

- **The slide is physics.** The trap keeps his slide across the back (`slip`,
  m/s) and moves him by it through `carry`. It is pushed by gravity along the
  tilted back and by the swing of the flight (the acceleration of the back's
  point under his feet, from its pose a frame either side: a turn throws him
  outward, a climb presses him down) and held by friction: `grip` (0.3, a
  smooth hide) times how hard he is pressed on. Standing still in the hardest
  bank he is off the rim under a second into the roll.
- **Leaning holds.** His own run uphill grips harder: `lean` 0.8 more at
  `lean_pace` (his walk x 0.5) up the slope, so leaning in holds even the
  hardest bank (1.1 against its 0.9). Crouching is not the grip: on any slope
  over the motor's SLIDE_FROM a crouch is its boot-surf (the trap leaves that
  slide to the motor), straight down the back and off.
- **The rim.** Slid past the rim faster than the motor's CATCH_PACE and not
  leaning in, he is thrown off with the speed he had (`motor.toss`). Slower,
  or leaning back in, the motor's own step-off catch takes the lip and he
  hangs from it (the thin hide leaves nothing under his feet past the rim),
  carried with the ray, to climb back up or let go.
- **Ridges** stop a slide into them (his body's radius kept out): get behind
  the low side's ridge before the bank and it is cover. They are a jump high.
- **Dives go light.** A dive climbs `height`, then plunges at his fall's
  acceleration x `dive` (1.4) for `plunge` s and pulls out level. Where its
  back drops away faster than he would fall he lifts off (`toss` with its
  velocity) and floats till it pulls up under him: about 1 m clear for 0.6 s.
  Sliding as it goes, he drifts on in the air. The climb before it presses
  him down (more grip).
- **Momentum both ways.** Leaving its back (a jump, a step off, letting go of
  the rim) he keeps its velocity; landing on it, his run is taken relative to
  it. So jumping off at the far deck carries him along the deck a little.
- **The rhythm.** `pattern` "RDLDR" over the far part of the loop, from just
  into the first turn to the end of the last: bank (right wing low), dive,
  bank left, dive, bank right. Banks grow from (1 - `ramp`) x `max_bank` to
  `max_bank`: 0.22, 0.47, 0.72 rad. The two right banks fall in the turns,
  where the swing throws him the same way. The near straight past both decks
  is calm. A gentle wobble (`shake` 0.04 rad) runs all the time.
- **Tells**, `tell` s ahead: the wing that will rise lifts and warms to orange
  before a bank, with a `whoosh`; the head dips before a dive's plunge, with a
  `screech` (the climb shows too). Placeholder sounds.
- **Tilt cap.** Bank and pitch together stay 2 degrees under the motor's own
  slide angle (SLIDE_AUTO 44), past which the motor would surf him itself.

| knob | default | meaning |
|---|---|---|
| width / long / thick | 6.7 / 9.0 / 0.8 m | the back (6 and 8 of his heights) |
| hide / inset | 0.2 / 0.78 m | the rim's thin hide; the thick body starts his hang plus his body's width in |
| speed | 4.8 m/s (his run) | pace along the loop |
| radius | 8.4 m | turn radius |
| pattern | "RDLDR" | the beats: L/R a bank dropping that wing, D a dive |
| max_bank / ramp | 0.72 rad / 0.7 | the last bank; the first is (1 - ramp) of it |
| turn_bank | 0 rad | banked into the turns as well (0: the beats only) |
| roll / hold | 0.5 / 1.0 s | a bank's roll in and out, and its hold |
| height / climb | 7.8 m / 2.0 s | a dive's climb |
| dive / plunge | 1.4 / 0.35 s | the plunge: his fall's acceleration x dive, for plunge s |
| max_pitch | 0.25 rad | the back's pitch in a dive's climb and plunge |
| shake / shake_rate | 0.04 rad / 4 rad/s | the rider-shedding wobble (0 off) |
| tell | 1.0 s | how far ahead the wing and head cues show |
| grip / lean / lean_pace | 0.3 / 0.8 / 1.2 m/s | friction standing; more leaning in, full at lean_pace uphill |
| pull / swing | 1 / 1 | shares of gravity and of the flight's swing in the slide |
| catch_pace | 2.6 m/s (the motor's CATCH_PACE) | over the rim faster than this, not leaning, he is thrown |
| ride | 22.4 m | route length (deck to deck) |
| edge_x / gap | 5.0 / 1.07 m | decks' east edge; jump gap to the ray's side (0.45 x reach) |
| lead_in / lead_out | 10 m | straight past the decks |
| arrive | 3.0 s | after a reset, how long till it passes the start deck |

A lap is about 138 m / 4.8 m/s, roughly 29 s wait if he misses it.

## Verified (headless, tests/test_trap_giants.gd)

The cube (round 4b): see its section above.

The ray, on its real schedule through the yard's frame (`study.tick`, the
motor, the trap field; nothing pinned by hand): carried 14 m in 3 s with it;
standing still through the hardest bank he is slid off and falls, 0.97 s into
the roll; a rider holding the middle and leaning uphill stays on the whole
28.7 s loop (two floats); in a plunge he is 1.05 m clear of the back for
0.6 s and lands on it again; slid off the rim leaning in he catches it and
hangs, carried (the lip fixed on the rim); a scripted rider jumps on from the
start deck's edge, rides the loop and jumps off onto the far deck. Also run
by hand in the real `_process` loop: standing still in the middle he rides out
the gentle first bank (slid 1.3 m) and is thrown off in the second.

## Unverified

- Feel and pacing in a window: no render here. The cube's list is in its
  section.
- The ray in a window: whether the slide, the throw and the float read and
  feel fair at 60 fps with a real stick and camera (the stick is camera-
  relative; on a turning ray "uphill" turns under it), whether the tells are
  readable soon enough, and the default knobs (grip, lean, ramp, shake).
- The figure while sliding: he slides standing (no slide pose), and the
  camera does not follow the ray's roll.
- The rim hang through a whole bank and a climb back up from it on a tilted
  back; letting go from it. Only the catch and the carried hang are tested.
- Coriolis is left out of the slide (the ray turns at 0.57 rad/s).
- Tells are colour and placeholder sounds only.
