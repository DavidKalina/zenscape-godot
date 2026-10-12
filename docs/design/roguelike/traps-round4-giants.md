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

A stone cube, 5.0 m a side (4.5 x his height), floating between the decks and
rolling about x (across the route) through its middle. The top moves back
toward the entry, so the face under him tips away from the exit: he is carried
round with it (`motor.carry` with the block's transform delta) and slid down
the tilt (`slip`); past the motor's own slide angle he cannot stand. Keep
walking uphill (-z); as a face goes steep, hop or jump onto the next one coming
up, or grab its lip and climb (the motor's ledge, wall slide and kick work on
it). Four faces, ruin features that rotate in: 0 a low wall, 1 a raised step
over half the face, 2 a trench across, 3 two low walls. Edges are bevelled so a
face-to-face step is a hop; `bevel` 0 is a true cube (knife-edge ridge, harder).
Tell: the face about to come up warms to orange; with a pause, the whole block
in its last `tell` s; `grind` sound as a quarter turn starts.

| knob | default | meaning |
|---|---|---|
| size | 5.04 m (HEAD x wanderer x 4.5) | cube side |
| plate | 0.6 m | face plate thickness (core inside) |
| bevel | 1.0 m (size x 0.2, max 2 x plate) | edge chamfer |
| spin | 0.286 rad/s (0.6 x walk / size) | roll rate; the worst keep-station walk is 0.6 x his walk |
| dir | +1 | +1 the top moves back toward the entry, -1 toward the exit |
| pause | 0 | 0 continuous; else 90 degree turns with this pause (s) between |
| yaw | 0 rad/s | later tier: a slow turn about the vertical too |
| gap | 1.43 m (0.6 x a running small hop's reach) | deck to cube, each side |
| top | 0 | flat top's height over the decks |
| slip | 2.16 m/s (walk x 0.9) | slid down the tilt at a sheer fall (x sin tilt) |
| wall_h / step_h / trench | 0.56 / 0.72 / 1.2 m | jump height x 0.7 / x 0.9 / run x 0.25 |
| tell | 0.8 s | pre-turn warm-up with a pause |

Route use: jump in from the entry deck onto the top, walk -z uphill, jump off
the top to the far deck (its top is at deck height every quarter turn).

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

Standing still on the cube's top he is slid and grabbed-off in about 3 s; a
scripted station-keeper (walks uphill, jumps what blocks him) stays the whole 40 s
over several face changes; carried, no teleport.

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

- Feel and pacing in a window (spin, slip, speed, bevel): no render here.
- Ledge-grab/climb and wall kicks off the cube's faces as it turns: the motor
  does them in the standing-still run (he catches the lip), but no scripted climb.
- The ray in a window: whether the slide, the throw and the float read and
  feel fair at 60 fps with a real stick and camera (the stick is camera-
  relative; on a turning ray "uphill" turns under it), whether the tells are
  readable soon enough, and the default knobs (grip, lean, ramp, shake).
- The figure while sliding: he slides standing (no slide pose), and the
  camera does not follow the ray's roll.
- The rim hang through a whole bank and a climb back up from it on a tilted
  back; letting go from it. Only the catch and the carried hang are tested.
- Coriolis is left out of the slide (the ray turns at 0.57 rad/s).
- The cube's `yaw` and pause mode.
- The cube's lower corners swing to about the yard floor (-6 m): cosmetic clip.
- Tells are colour and placeholder sounds only.
