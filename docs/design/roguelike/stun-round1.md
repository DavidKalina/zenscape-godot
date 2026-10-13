# Stun, round 1

The user, 2026-10-12: "There SHOULD be fall damage. And mid air rag dolling...
Not fall damage but fall stun." Stun locks and chains are wanted ("knocked onto
a manta ray and being forced to hang on. Then gliding off and maybe landing on
a see saw"). Then, mid-round: "the stun should work in the air... you have X
time before you regain poise and can pull out the cloth", and "maybe both could
work" for the timed press. This round builds the stun as a system on the motor
(scripts/pilot_motor.gd), draws it (scripts/pilot_figure.gd), makes the traps
and the Ram act on a stunned body, and lays a yard to play it.

With no health, a stun costs position and time. A stunned body is an object:
the world decides where it goes. The skill is getting out of it.

## Play it

```sh
godot --path . res://studies/stun_yard.tscn -- --no-title
godot --path . res://studies/stun_yard.tscn -- --no-title --knob=tech=true
godot --path . res://studies/stun_yard.tscn -- --no-title --knob=poise=0.8 --knob=poise_most=1.5
```

(`godot` is `/Users/davidkalina/Applications/Godot.app/Contents/MacOS/Godot`.)
`--knob=<motor var>=<value>` sets any of the motor's stun knobs below.

Stations (number keys):

- **1 to 8, the drop ladder.** Columns of 0.5, 0.75, 0.95, 1, 1.25, 1.6, 2
  and 3 times the stun's fall, each marked with its height and share. You
  start on top of each, facing the deck. Step off it.
- **9, the Ram.** The Plinth Ram on an open isle. Let it hit you.
- **0, the blaster.** The wind blaster lane. Stop on its plate and you get
  blown off, onto a floor one stun's fall (6 m) below.
- **-, the chain.** Stand on the orange plate (the kicker) for half a second
  and it knocks you onto the Sky Ray waiting beside the deck. Its dwell is
  8 s here so you have time. The seesaw dropper is 1.5 stun falls (9 m) under
  the ray's stop. Its block falls on the near end every 4 s and throws
  whatever lies on the far half.

Controls are the character study's (WASD or stick, Space jump and sail, Shift
or C crouch, X or the pad's twirl button). **T** turns the tech on and off
live. The top-right line always shows it, along with the stun's state: DOWN
with its seconds, STUNNED with the seconds until poise returns, "tech armed",
and the fall so far against the stun's height. R goes back to the start. F1
shows the numbers.

## The rules as built

### Fall stun

- **The threshold:** `fall_stun_pumps` (4) times his pump, `jumps[1]`. At
  the wanderer's 1.0 that is 6 m, the same as the trap yard's drop to its
  floor, so the soft fail now costs a stun. The drop is measured from the top
  of the airtime. The sail, a wall slide, a wall run and a twirl each restart
  it. Moving frames (`carry`) carry it along.
- **Time down:** `stun_down.x` (0.7 s) at the threshold, rising to
  `stun_down.y` (1.6 s) at `FALL_STUN_FULL` (2) times it. That is the cap.
  He skids to a stop as he would after a knock.
- **What avoids it:** landing under the sail, a ledge catch (no landing),
  deep water (a swim), and **the roll**. The roll is the twirl button pressed
  when the touch is less than `tech_window` (0.2 s) away, during a fall big
  enough to stun. That press is the roll, not the twirl. He lands rolling
  (move "roll", `roll_time` 0.35 s) and keeps his pace. A press earlier than
  that, with the twirl already spent, locks the button out for
  `tech_lockout` (0.4 s), so mashing doesn't roll. An earlier press with the
  twirl unspent is simply the twirl. That restarts the fall's measure, so a
  low twirl also saves him. This is a skilled save too.
- **The slam does not stun** (`slam_stuns` false). It is his own move: he
  chose to land hard, and its impact goes out into the world as the ring.
  It commits him straight down where he is, with no steering, so it isn't a
  free save over the void. Still, crouch pressed 1.8 m or more up turns any
  survivable fall into a stun-free one. If that reads as an exploit, set
  `--knob=slam_stuns=true`.

### Stunned in the air: poise (the baseline)

- When knocked (`knock`, or `toss` while stunned), he has no control for
  `poise_for(v)` = `poise` (0.5 s) + `poise_hit` (0.04 s per m/s of the blow),
  capped at `poise_most` (1.2 s). That is no sail, no twirl, no steering and
  no catching. An 8 m/s blow gives about 0.8 s, and the blaster's about 0.9 s.
- When the timer runs out in mid-air, his poise returns ("poised"). The
  sail, the twirl (given back), the stick and ledges all work again. A long
  fall gives him time to recover. A short knock over the void may not: in
  the yard, the blaster's knock lands him on the 6 m floor before his poise
  returns.
- If he lands still stunned, he is laid down for `tumble_down` (0.5 s), or
  for the fall stun's time if the tumble fell that far.

### The tech (the skill layer, `tech`, off by default)

Smash-style. While stunned, the twirl button arms a press for `tech_window`
(0.2 s). If he meets a surface inside that window, he recovers at once
("teched"):

- the **floor**: he lands in the roll, with no time down;
- a **wall**: he kicks off it (the wall jump), under his own control again;
- a **lip** in reach: he catches it, whichever way he faces or flies;
- the **Sky Ray's back**: a floor tech there latches him onto the nearest
  rail (`trap_ray.gd _latch`), held as the ray's own grab holds him.

Every press locks the button out for `tech_lockout` (0.4 s) past the window
it armed. A mistimed press, or mashing, can't tech. The tech is off by
default so the plain poise timer can be judged first. Turn it on with T, or
with `--knob=tech=true`. The default was chosen headless, not by feel. See
below.

### Stun locks

- `tumble_immune` (the protection after getting up) is now **0** (it was
  0.8 s). The world can chain its hits.
- **Per-source gap:** `knock(v, source)`. A source that stunned him can't
  stun him again for `restun_gap` (1.2 s). Its blow still throws him: if
  he is stunned, his poise starts over; if he is on his feet, it is a plain
  `toss`. Every knock without a source shares one key, so the dragon and the
  cyclone count as one source. The Ram, the enemy base (`shove_pilot`,
  `buck`), the wind blaster and the tumbling block all name themselves.
- **Chain cap:** after `stun_chain_cap` (3 s) stunned in a row, any press
  breaks out: in the air into the twirl, on the ground straight up. New
  blows only throw him (no new stun) until he has been in control for
  `STUN_CALM` (1 s).
- **Why this can't freeze him in one spot:** each stun from one source is
  at least 1.2 s apart, and every blow moves him. After 3 s the player can
  always leave. Different sources can chain freely. That is the Spelunky
  chain the user asked for: the world decides where he goes, the cost is
  position, and the cap guarantees a way out.
- A charging Ram now hits a stunned body once its own gap is past. Before,
  `recovering()` let a tumbling pilot through.

### The world acts on a stunned body

Each trap's `before` and `after` was checked:

- **Logs:** carry anything grounded, so a downed body rolls with them.
  Unchanged.
- **Sluice (flush):** washes him while grounded, pushes him in the air, and
  its spill is a `toss`. A stunned body stays stunned. Unchanged.
- **Wind:** the vents push him as a shove (not under the sail). A tumbling
  body is pushed. A downed body on the plate trips the blaster. Unchanged.
  The blaster names itself as the source.
- **Seesaw** (all kinds): carries anything grounded, its weight tips the
  slab, its landing counts as a landing, and the launch is a `toss`. A
  stunned body is launched still stunned, with a fresh poise. Unchanged.
- **Flip, voussoirs, tumbling block:** grounded checks and `toss`, so they
  carry or shed a downed body. The tumble trap's knock names itself.
- **Sky Ray: fixed.** It ignored anyone `recovering()`, so a downed body on
  its back was left in the air as it flew. Now a downed body rides it as a
  body (carried, slid, shed, thrown off) but never grabs a rail itself. A
  floor tech on its back latches him on.
- **`toss` (motor):** a stunned body that is tossed is thrown still
  stunned. Before, `toss` silently ended the tumble.

### The figure: a procedural ragdoll

A real physics ragdoll (PhysicalBone3D) would fight the AnimationTree and the
springs, and would need tuning per pose. It also can't be tested headless in
any useful way. Instead the figure does a procedural ragdoll on the same
painterly mesh, with no new art, so it stays smooth:

- **The spin.** The throw spins the body about the axis it was hit over:
  head back along the throw, at `RAG_SPIN` times the blow's pace (5 to 14
  rad/s), plus a random twist and roll. The spin carries through the air,
  slowed only a little by drag.
- **The limbs.** They go limp, each on a soft spring (2.2 Hz, damping
  0.28). Each one chases the direction the air and gravity pull it in the
  body's own frame, and the spin flings it outward. So the limbs trail, flop
  and overshoot instead of holding a pose.
- **Down.** On the ground he eases over to lying flat, on whichever side he
  came down on, sprawled. Three small glowing dots (the dizzy) circle over
  his head.
- **Getting up.** The body springs upright.
- **Poise back.** In the air, he gathers himself: the ragdoll unwinds fast,
  with a stretch and a squint.
- **The roll** is a forward roll over 0.35 s.
- **Grabbed.** When held by a grab, he is tipped as before.

The old fixed somersault and the sit-down are gone.

## Knobs and defaults (PilotMotor vars, from its constants)

| knob | default | what |
|---|---|---|
| `fall_stun` | true | the fall stun at all |
| `fall_stun_pumps` | 4.0 | the stunning fall, in pumps (6 m at size 1) |
| `stun_down` | (0.7, 1.6) | seconds down at the threshold and at 2x (cap) |
| `poise` | 0.5 | seconds without poise after any knock |
| `poise_hit` | 0.04 | more per m/s of the blow |
| `poise_most` | 1.2 | the most |
| `tech` | false | the tech (T in the yard) |
| `tech_window` | 0.2 | a press is armed this long; also the roll's window |
| `tech_lockout` | 0.4 | lockout past the armed window |
| `roll_time` | 0.35 | the roll on the ground |
| `restun_gap` | 1.2 | one source's stun-again gap |
| `stun_chain_cap` | 3.0 | seconds stunned in a row before any press breaks out |
| `tumble_immune` | 0.0 | protection after getting up (was 0.8) |
| `tumble_down` | 0.5 | down after a knock's landing |
| `slam_stuns` | false | whether the slam's landing can fall-stun |

The motor's events: "stunned" ("fall"), "downed" (seconds), "poised",
"rolled" (the drop), "roll_ready", "teched" ("land", "wall", "ledge"),
"recovered" (the cap breakout in the air), "got_up". Queries:
`downed()`, `poise_left()`, `tech_armed()`, `stunnable(source)`,
`fall_stun_height()`, `fall_stun_time(drop)`, `poise_for(v)`, and `stunned`
("", "knock", "fall").

## Checks

- `tests/test_pilot_stun.gd` (new, the motor with the figure): the
  threshold, the timing curve and its cap, the sail, water and slam
  exemptions, the roll and its pace, the lockout, poise (no steering, no
  sail, then the sail), landing stunned, the body drawn lying and dizzy,
  the toss staying stunned, the source gap, the chain-cap breakout, and the
  tech on the floor, on a wall and when mashed. Passes.
- `tests/test_stun_yard.gd` (new): run through the **real play loop**, with
  input actions and the study's own frames. It covers the ladder at 0.75x
  (a landing) and 1.25x (down, then up), the roll at 1.6x, the blaster
  (no sail before poise, ends down on the floor), the Ram hitting, the
  kicker onto the ray (carried while down), T and a tech latching onto a
  rail, and a stunned body thrown by the seesaw's block. Passes.
- Run as well: test_pilot_figure, test_pilot_motor, test_pilot_moves,
  test_pilot_ledge, test_pilot_momentum, test_pilot_water, test_pilot_wake,
  test_pilot_footfalls, test_pocket_sail, test_slam, test_cannon,
  test_enemy_ram, all of `test_trap_*`, `test_character_*`,
  test_dragon_cyclone, and test_world_scale_guard/fit. All pass except:
  - test_pilot_tricks ("Twirling low, Jump pressed again neither opens the
    sail nor flies"). This already fails on `roguelike` before this round.
  - test_character_recordings. Three runs already fail on `roguelike`. One
    more, "Fluid Gameplay 2", now strays at 30.2 s, after a landing. That
    is the fall stun: with `fall_stun` off it goes back to the three. The
    recording was made before stuns existed. It was neither re-recorded nor
    listed as known: the user should decide.

## Unverified (needs a windowed look)

- Whether the ragdoll reads well: the spin rate, how floppy the limbs are,
  the lying pose. Some of those bone turns are on top of the idle clip and
  may twist strangely in places, such as an arm through the body when he
  lies on his front. Its joint limits are rough guesses.
- The dizzy dots' size and height, and the gather cue (it may be too
  subtle).
- The roll's look. It pivots about the hips, so the head may dip into the
  ground.
- Whether 0.2 s is a fair window, and whether poise at 0.5 s + 0.04 s per
  m/s feels right. Neither the tech default (off) nor the window has been
  judged by playing.
- Camera behaviour while ragdolling: the chase camera follows the feet.
- The chain station's timing (the kicker against the ray's 8 s dwell) and
  whether the 9 m seesaw drop is too far.
- No sounds were added. The kicker records a `kick` tell_sound only.

## For the next round

- **Enemy and block stuns.** The same state carries over: an enemy already
  has `stun(seconds)`. Give it a poise (no thinking until it is up) and a
  fall stun from its own drop, using the motor's `fall_stun_time`. Thrown
  blocks and stunned enemies become the "objects the world moves" for the
  pilot. Pass the enemy as `source` when it hits him, as the Ram does now.
- **Items.** Spring boots can now cancel the fall stun (set
  `fall_stun = false`, or raise `fall_stun_pumps` while they are worn). A
  "sure grip" item could turn `tech` on.
- **Dragon hits.** `sky_dragon.gd` and `dragon_cyclone.gd` still call
  `knock(v)` with no source. Pass `self` so the dragon gets its own gap. Its
  `recovering()` hold-off now ends the moment he is up (`tumble_immune` is
  0). That is intended for chaining, but check that the gust doesn't re-knock
  him on the frame he stands.
- `knock()` and `toss()` are where any new hit lands. Use `stunnable(source)`
  to ask whether a hit would stun or only shove.
