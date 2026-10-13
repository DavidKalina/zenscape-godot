# Stun, round 1

The user, 2026-10-12: "There SHOULD be fall damage. And mid air rag dolling...
Not fall damage but fall stun." Stun locks and chains are wanted ("knocked onto
a manta ray and being forced to hang on. Then gliding off and maybe landing on
a see saw"). Then, mid-round: "the stun should work in the air... you have X
time before you regain poise and can pull out the cloth", and "maybe both could
work" for the timed press. This round builds the stun as a system on the motor
(scripts/pilot_motor.gd), draws it (scripts/pilot_figure.gd), and lays a yard
to play it.

Built on the `roguelike` branch (feature/stun, merged b8390926) and ported to
`main` on `port/dragon-stun` (docs/design/port-dragon-stun.md) without the
roguelike's traps and enemies. This copy is trimmed to what main has: the
traps' and the Ram's parts of the round stayed on `roguelike`, and the yard
here is reduced to the drop ladder and a blast post.

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
- **9, the blast post.** A deck with the dragon's air blast
  (scripts/dragon_air_blast.gd) fired from a post off its side while you
  stand on it. It is a hard hit (`knock`'s `down`, `STUN_DOWN` 1.2 s): no
  poise the whole throw, then laid down dizzy on the floor one stun's fall
  (6 m) below. The post names its blast as the source.

(On `roguelike` the yard also had the Plinth Ram, the wind blaster lane and a
chain of a kicker, the Sky Ray and a seesaw dropper. Those need the traps and
enemies, which aren't on main.)

Controls are the character study's (WASD or stick, Space jump and sail, Shift
or C crouch, X or the pad's twirl button). **T** turns the tech on and off
live. The top-right line always shows it, along with the stun's state: DOWN
with its seconds, STUNNED with the seconds until poise returns, "tech armed",
and the fall so far against the stun's height. R goes back to the start. F1
shows the numbers.

## The rules as built

### Fall stun

- **The threshold:** `fall_stun_pumps` (4) times his pump, `jumps[1]`. At
  the wanderer's 1.0 that is 6 m, so a long drop now costs a stun. The drop is measured from the top
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
  no catching. An 8 m/s blow gives about 0.8 s.
- When the timer runs out in mid-air, his poise returns ("poised"). The
  sail, the twirl (given back), the stick and ledges all work again. A long
  fall gives him time to recover. A short knock over the void may not.
- If he lands still stunned, he is laid down for `tumble_down` (0.5 s), or
  for the fall stun's time if the tumble fell that far.

### The tech (the skill layer, `tech`, off by default)

Smash-style. While stunned, the twirl button arms a press for `tech_window`
(0.2 s). If he meets a surface inside that window, he recovers at once
("teched"):

- the **floor**: he lands in the roll, with no time down;
- a **wall**: he kicks off it (the wall jump), under his own control again;
- a **lip** in reach: he catches it, whichever way he faces or flies.

(On `roguelike` a floor tech on the Sky Ray's back also latches him onto a
rail; that is the ray's code and stayed there.)

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
  `toss`. Every knock without a source shares one key. The dragon's air blast and
  cyclone name the dragon (in the vision greybox); the yard's blast post
  names its blast.
- **Chain cap:** after `stun_chain_cap` (3 s) stunned in a row, any press
  breaks out: in the air into the twirl, on the ground straight up. New
  blows only throw him (no new stun) until he has been in control for
  `STUN_CALM` (1 s).
- **Why this can't freeze him in one spot:** each stun from one source is
  at least 1.2 s apart, and every blow moves him. After 3 s the player can
  always leave. Different sources can chain freely. That is the Spelunky
  chain the user asked for: the world decides where he goes, the cost is
  position, and the cap guarantees a way out.

### The world acts on a stunned body

- **`toss` (motor):** a stunned body that is tossed is thrown still
  stunned. Before, `toss` silently ended the tumble. Anything on main that
  tosses him (updrafts, the slam's ring, moving pieces) now throws a
  stunned body on, still stunned.
- (On `roguelike` this round also went through each trap's `before` and
  `after` and fixed the Sky Ray carrying a downed body; not on main.)

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
  with a stretch. (On `roguelike` the wanderer's face also squints; main's
  figure predates the wanderer look and has no face. The dizzy dots use the
  sheet's cyan as a local `DIZZY_GLOW`.)
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

- `tests/test_pilot_stun.gd` (the motor with the figure): the threshold, the
  timing curve and its cap, the sail, water and slam exemptions, the roll and
  its pace, the lockout, poise (no steering, no sail, then the sail), landing
  stunned, the body drawn lying and dizzy, the toss staying stunned, the
  source gap, the chain-cap breakout, the tech on the floor, on a wall and
  when mashed, and the dragon's hard hit.
- `tests/test_stun_yard.gd`: run through the **real play loop**, with input
  actions and the study's own frames: the ladder at 0.75x (a landing) and
  1.25x (down, then up), the roll at 1.6x, the blast post (knocked off, no
  sail through a hard hit, laid down on the floor below), T on and off.
- Results on `port/dragon-stun`: docs/design/port-dragon-stun.md.

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
- No sounds were added for the stun.

## For the next round

- **Items.** Spring boots can cancel the fall stun (set `fall_stun = false`,
  or raise `fall_stun_pumps` while they are worn). A "sure grip" item could
  turn `tech` on.
- **Dragon hits.** The sky dragon's gale and land knocks and the air blast
  now name the dragon (roguelike d659907b). `recovering()`'s hold-off ends
  the moment he is up (`tumble_immune` is 0): check a gust doesn't re-knock
  him on the frame he stands.
- `knock()` and `toss()` are where any new hit lands. Use `stunnable(source)`
  to ask whether a hit would stun or only shove.
