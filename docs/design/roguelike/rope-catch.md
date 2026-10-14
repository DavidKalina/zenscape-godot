# Rope catch: ropes and roots snag a tumbling body

The Root Curtain card (brainstorm round 1, `kit-k1-grab.md`) wants "live
roots snag a ragdolled pilot out of the air and hand him back control; dry
roots snap and redirect him, still stunned". Before this round a swing rope
turned a tumbling body away (`swing_rope.gd` `try_catch` returned on
`move == "tumble"`), and `seize()` only ever ended in a `knock`. So a knocked
pilot thrown past a rope just fell. Now any swing rope is a catcher in the
chain: knocked through its reach, he is snagged, swung round and handed his
poise back on it.

## Play it

The yard's ropes (station 3) snag. Nothing in the yard knocks you yet, so to
feel it, stand on the start deck in front of the first rope and get thrown
through it. The headless check below throws by hand (`motor.knock`). The
stun yard's blaster and seesaw throw into open floor, not at ropes.

```sh
godot --path . res://studies/interactables_yard.tscn -- --no-title --at=rope
```

## What happens

1. **The snag.** A tumbling body in the air (move "tumble", not seized, not
   on the ground or swimming) whose chest passes within `SNAG_REACH` (0.55 m)
   of the rope's lower part is caught. The rope checks the chest's path over
   the frame, not only where it ends, so a fast throw can't skip through.
   0.55 m is the chest plus a flung arm. An ordinary grab's reach is
   `CATCH_BODY` 0.32, but a ragdoll's limbs are out. His hands go to the
   rope `HANG_DROP - CHEST` (0.225 m) above where his chest met it, so the
   body doesn't jump.
2. **The swing round.** Only the part of his speed across the rope becomes
   its swing. The part along the rope is lost: the rope takes the blow. (An
   ordinary grab turns all of his pace into swing.) The swing is capped at
   TOP 24 m/s. A knock of 8.5 up and 9 across swings him to about 53 degrees
   off the plumb (MOST is 77).
3. **The whip.** For `WHIP_TIME` (0.45 s) the rope's tail below his hands
   is drawn flung back up to `WHIP` (1.1 rad) against the swing, easing
   out. The figure takes the hang with the jolt it already gives a grab from
   the air (GRAB_KICK, GRAB_SWING).
4. **Limp.** He hangs still stunned (move "tumble", `hold` "swing") as the
   rope's bob. The stick does nothing (no pump, no steer), and neither do
   Jump and crouch: mashing them doesn't let go. The swing runs on gravity
   alone.
5. **Poise back on the rope.** After the limp beat, `regain()` gives him his
   control: stunned "", the twirl given back, the motor's event "poised". He
   is now an ordinary rider, exactly as if he had jumped in: pump, steer, a
   timed release with BOOST and POP, crouch to drop.

Events: foot_pieces adds "snag" (and "swing") on the catch, and counts it
(`counts.snag`). The rope's ride returns "poised" when his poise is back,
"teched" "rope" on a tech, and "snapped" when a dry rope breaks.

## The stun decision: poise on the rope, cut short; the tech takes hold at once

The question was whether he comes out of the stun on the rope, after a
beat, or by a tech press. The answer is all three, layered the way
stun-round1.md layers the air:

- **Baseline: a beat, then poise on the rope.** The limp beat is what his
  poise had left (`poise_left()`), held between `SNAG_LEAST` 0.25 s and
  `SNAG` 0.5 s. In the air, the poise rule says no control for
  `poise_for(v)` (0.5 s plus 0.04 per m/s, at most 1.2 s). The rope is a
  catch, so it cuts that short to at most 0.5 s: the rope took the blow.
  It never holds him less than 0.25 s, so the catch always reads (whip,
  limp swing) before the player has him back. A hard hit (`knock` with
  `down`, poise INF in the air) gets the full 0.5 s and comes back too. The
  rope is the save from a hit that would otherwise have no recovery in the
  air.
- **Skill: the tech.** With `tech` on, a twirl press armed (`tech_window`
  0.2 s) when he meets the rope, or pressed during the limp beat, takes hold
  at once ("teched" "rope"). This is the stun round's "a lip in reach:
  caught", extended to ropes. Its lockout is unchanged, so mashing can't
  tech.
- **The chain cap.** After `stun_chain_cap` (3 s) stunned in a row, any
  twirl press takes hold at once, as it breaks out in the air.
- **Not a stun.** The snag shares no restun key. A pilot snagged, let go
  and knocked again by the next piece is stunned afresh. One source still
  can't juggle him (`restun_gap`). While he hangs limp, a knock from any
  source throws him off the rope (`knock` clears the rider).

Why not keep him stunned until a press? A rope that holds a limp body
forever stalls the chain. It is a net, not a trap, and the card says "hands
him back control". Why not give control back at once? Then the snag is just
a grab and the catch doesn't read. The 0.25 to 0.5 s beat is the read.

## Dry ropes (the dry root): snap and redirect, still stunned

`rope.set_dry(true)` makes a rope pale (`DRY_TONE`) and brittle.

- It snags a tumbling body too, but holds it only `DRY_SNAG` 0.3 s. Then it
  snaps and throws him on along its swing's velocity at his hands, by
  `toss`. A tossed stunned body stays stunned with a fresh poise
  (stun-round1). It's a redirect, not a rescue. A tech press during that
  0.3 s takes hold before the snap, and then he rides a dry rope (below).
- Held as an ordinary rider, it snaps after `DRY_HOLD` 2.5 s. He keeps its
  arc (a plain `toss`: not stunned, the sail fresh).
- Snapped, it leaves a stub `DRY_STUB` (0.3) of its length, too high to
  reach. It never catches again (`snapped`).
- Not built: the creak and bark tell before the snap, the falling piece,
  and "past the plumb the second time".

## Knobs

| knob | default | what |
|---|---|---|
| `snag` (per rope) | true | snags a tumbling body at all (the Holder's ring wants it off) |
| `SNAG_REACH` / `t_snag_reach` | 0.55 m | chest-to-rope reach of the snag, swept |
| `SNAG` / `t_snag` | 0.5 s | the longest limp beat |
| `SNAG_LEAST` | 0.25 s | the shortest limp beat |
| `WHIP`, `WHIP_TIME` | 1.1 rad, 0.45 s | the tail's flick |
| `dry` (per rope, `set_dry`) | false | snaps, see above |
| `DRY_SNAG`, `DRY_HOLD`, `DRY_STUB` | 0.3 s, 2.5 s, 0.3 | dry rope's holds and the stub left |

## Code touched

- `scripts/interactables/swing_rope.gd`. `try_catch(walker, delta := 0.0)`:
  a snapped rope refuses, and a tumbling body goes to the new `_try_snag`.
  The ordinary path is unchanged. `_take(walker, at, along := true)`: the
  snag passes false, so only the across part becomes swing. `ride`: the
  limp beat, then the regain, the tech, and the dry snaps. Also new:
  `_snap`, `set_dry`, the whip in `_draw`, and `_rope_mesh(tone_of)`, whose
  default keeps `snag_plane.gd`'s call as it was.
- `scripts/pilot_motor.gd`. `step`: while a rider holds a tumbling body,
  the twirl press runs `_tech_press` (a chain-cap "up" arms it too). New:
  `regain()`. Header note.
- `scripts/interactables/foot_pieces.gd`. `after` passes the frame's delta
  to `try_catch`, adds the "snag" event and `counts.snag`.

## Checks (headless, uncommitted throwaway)

A throwaway SceneTree script ran the interactables yard through its own
`_process` loop (`scripted` false, `--fixed-fps 60`), with real Input
actions (`walk_jump`, `walk_twirl`, `walk_crouch`, `move_forward`) and the
knock by hand (`motor.knock(Vector3(0, 8.5, -9), study)`) from the start
deck at (6 ± 0.5, 0, 3.6 ± 0.5) toward the first rope:

- **Live snag: 10/10** (20/20 over 20 trials). Jitter: ±0.5 m in x and z,
  and ±0.2 s on when the knock lands. The rope sways 0.5 m and crosses the
  plumb at the nominal arrival. Every catch: snagged about 0.45 s after the
  knock, still stunned on it, poise back 0.5 s later, still holding 1 s on
  with no input, swung to 51-55 degrees. With a lopsided swing instead (the
  rope given 1.6 m/s sideways, so it is about 0.5 m off centre when he
  arrives), 8/10 (12/20). Every miss was jittered toward the side the rope
  had swung away from, so those are honest misses.
- **Mashing**: Jump and crouch mashed through the 31-frame limp beat did
  nothing, and he was still holding once poised. A jump press then let go
  (a plain toss, not stunned).
- **Tech** (tech on, twirl pressed 1.4 m before the rope): held and poised
  1 frame after the snag.
- **Dry**: 10/10 snagged, snapped after 0.3 s, and thrown on still stunned.
- **Ordinary grab unchanged**: a run and jump into the first rope, pumped,
  released by a jump press. Before and after the change: caught on frame
  97, released on frame 230 at (0, 3.239, 6.160), landed at (5.997, 0,
  2.350), timing 0.098, and the weighted sum of every frame's feet
  identical to 7 digits.
- **Smoke**, 400 frames headless, no SCRIPT ERROR: interactables_yard (and
  `--at=rope`), character_study, run_layer sprawl seed 1, ring seed 2,
  sprawl seed 3.

## Tests

Run: test_pilot_* (figure, footfalls, ledge, momentum, motor, moves, stun,
tricks, wake, water), test_foot_interactables, test_stun_yard,
test_character_recordings, test_dragon_grip_stun, test_rope_bridge,
test_aqueduct_under, test_aqueduct_isle, test_trap_*, test_snag. Nothing
breaks. These failures are the same before and after the change:

- test_pilot_tricks: "Twirling low, Jump pressed again neither opens the
  sail nor flies". It already fails on `roguelike`.
- test_character_recordings: the same 4 strays as on `roguelike` (Tech Fun,
  Fluid Gameplay 2, village 1, village 5).
- test_trap_giants fails on `roguelike` too, with details that vary from
  run to run.

One trap: test_trap_seesaw's real-loop part ("he comes down on the high
ledge") depends on frame time. It failed after any script edit, even a
comment, until the worktree was imported again. After a fresh headless
import it passes with the change.

## Unverified (needs a windowed look)

- Whether the catch reads: the whip's size, and the hang pose during the
  limp beat. The figure draws the rope's hang with the grab jolt. It
  doesn't draw the ragdoll's limp limbs or the dizzy dots while snagged,
  which might read better as "caught limp".
- Camera behaviour on the snag.
- No sound was added. `rope-whip-*.wav` exists in `assets/audio/kit/` for
  the "snag" event.
- Whether 0.55 m reach is generous or stingy by feel.

## Next

- Give a station in the yard a thrower aimed at a rope: a blaster, or a
  seesaw's far end under a rope.
- Root Curtain: a root mesh on this rider, and `set_dry` for the pale
  ones. Add the creak tell and the falling piece to the dry snap.
- The Holder's ring: `snag = false` by default, as the card asks.
