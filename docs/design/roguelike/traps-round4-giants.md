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

Standing still on the cube's top he is slid and grabbed-off in about 3 s; a
scripted station-keeper (walks uphill, jumps what blocks him) stays the whole 40 s
over several face changes; carried, no teleport. On the ray he is carried along
its path (14 m in 3 s with the ray) and in a hard bank slides to the low edge.

## Unverified

- Feel and pacing in a window (spin, slip, speed, bevel): no render here.
- Ledge-grab/climb and wall kicks off the cube's faces as it turns: the motor
  does them in the standing-still run (he catches the lip), but no scripted climb.
- Boarding the ray by a real jump from the deck edge (moving platform timing),
  getting off at the far deck, `shake`, `yaw`, and the pause mode.
- The cube's lower corners swing to about the yard floor (-6 m): cosmetic clip.
- Tells are colour and placeholder sounds only.
