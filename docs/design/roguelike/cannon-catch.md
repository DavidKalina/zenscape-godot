# The catching cannon (prototype, 2026-10-13)

> Branch `proto/cannon-catch` (off `roguelike`), uncommitted. A set piece
> on the cannon (cannon-round1.md): **fall into a cannon and get fired
> out.** A body that arrives in the mouth is caught, held for a beat, wound up,
> then fired along the cannon's aim. It might fall in, be thrown in, tumble
> in stunned, or be blown in by another link. This is the link several greybox chains
> stood in for: Lidstack's catching cannon, Noon Weir's cannon chain, and the
> head that spits you into a cannon.

## What it catches and throws (motif-brief: everything chains)

- **Catches:** the pilot in the air arriving in the mouth, moving into
  the barrel (against its aim) within `catch_cone` of its axis. That covers a
  fall off a ledge, a jump, a sail into it, a knock (kicker, Ram, blaster), an
  inhaler head's blast, and a seesaw's throw. He must be in the air, with
  nothing held: not hanging, swimming or riding anything.
- **Throws:** him, along the aim at the power set (the same shot as climbing
  in), toward whatever the aim points at: an isle, another link, another
  cannon.

## How it reads

1. **Funnel.** Within `catch_pull` of the mouth and heading in, his
   velocity is turned toward the mouth and his speed is kept, so a near miss
   still goes in.
2. **Catch (the tell).** He vanishes into the barrel. The tube squashes fat
   and short, then wobbles out (the gulp), and the cannon makes a `gulp` sound.
   The chase camera swings round to look down the shot.
3. **Hold.** `catch_hold` s. Nothing cuts it short; no button acts.
4. **Anticipation.** For `catch_windup` s the tube draws back toward the
   breech, swells, shakes, and glows to the flash colour (`charge` sound).
5. **Shot.** Boom and flash. The tube kicks long and thin and snaps back.
   He leaves the mouth at the aim's velocity. After that the cannon won't catch
   again for `catch_cool` s.

The camera does not take over while he is caught, because in a chain the chase
camera keeps the place readable. Only operating and climbing in keep the
cannon's own view.

## Stuns (stun-round1.md)

- **Poised in, poised out.** He leaves by `PilotMotor.toss`, exactly as when
  he climbs in and fires: no tumble, the sail ready.
- **Stunned in, stunned out.** He leaves by `knock(v, cannon)`, and the
  cannon names itself as the source. If `stunnable(cannon)`, that's a fresh
  stun with a new poise for the shot's speed (about 1.2 s at the rest
  power). Otherwise the restun gap or the chain cap applies, and he is thrown
  on still stunned (`_throw_stunned`). So the stun lock rules hold: one
  cannon can't re-stun him within `restun_gap`, and after `stun_chain_cap`
  (3 s) any press breaks out.
- The time held counts toward the chain cap (the motor counts all time in
  the tumble). From the head, he is past the cap when fired (head hold 1.2
  s, flight, cannon hold 0.85 s). The cannon then only throws him. The head's
  hard hit keeps his poise off, so he lands downed unless he presses to
  break out. The poise timer itself is paused while he is held.
- Something else knocking him while he is inside (`rider` taken away) lets
  go: no shot.

## Enemies: not caught (decided)

Only the pilot is caught this round. Kegs and enemies fly past. Enemies have
no thrown-through-the-air state to hand over. The base enemy (`enemy.gd`)
walks, falls and gets stunned on the spot. The heads and bodies are
stones that tumble under their own step, and none of them has a velocity a
cannon could take and give back. Catching them needs an enemy-side
"thrown body" state (fly an arc, land, stun from the drop), which is the
"enemy and block stuns" item stun-round1 already lists. Once that exists,
the field's catch can take any body with `velocity` and a `thrown(v)`
hook. That's the next step if the user wants to fire enemies at enemies.

## See it

```sh
godot --path . res://studies/cannon_yard.tscn -- --no-title
```

The cannon yard has new stations, reached with the number keys:

- **2, the ledge.** You stand on a 9 m tower beside the catching cannon. Run
  off its edge toward the barrel: caught, fired onto the pad isle down the
  line.
- **3, the kicker.** Walk onto the plate (stand 0.5 s). It knocks you, stunned,
  on an arc that peaks 2.5 m over the mouth and comes down through it.
- **4, the head.** An inhaler head on its isle faces you. Let it draw you in
  and swallow you. It blasts you out over its rim, down into a cannon on the
  terrace 6 m below (the cannon's mouth sits where the blast comes down,
  measured), which fires you onto the terrace's pad isle.

Station 1 (ranging shots) is unchanged. The catch is on for every cannon, in
the yard and in runs (`catch` knob).

## Knobs (cannon.gd `defaults`, unit 1.2 m)

| knob | default | what |
|---|---|---|
| `catch` | true | catches at all |
| `catch_radius` | unit x 0.95 (1.14 m) | his middle within this of the mouth (swept per frame): caught |
| `catch_pull` | unit x 2.2 (2.64 m) | the funnel's reach around the mouth |
| `catch_pull_rate` | 12 /s | how fast the funnel turns his velocity toward the mouth |
| `catch_in` | 1 m/s | slowest he can be moving into the mouth |
| `catch_cone` | 72 deg | his way in at most this far off the barrel's axis |
| `catch_hold` | 0.45 s | the gulp, held |
| `catch_windup` | 0.4 s | the anticipation |
| `catch_cool` | 0.6 s | after a shot, no catch |

Yard: `TOWER_TOP` 9 m, `KICK_AT`, the kicker's `over` 2.5 m, `HEAD_TERRACE`
-6 m, `HEAD_CANNON` (placed from the measured blast path).

## Proven (headless, through the yard's real play loop)

`study.tick` was driven with the stick on the game's InputMap actions
(`Input.action_press`). There were 10 runs per station, each with the spawn
jittered by up to ±0.5 m in x and z and the start delayed 0.25 ± 0.2 s. A
throwaway script, not committed.

| station | caught | fired and landed on the pad isle | stun state right after the shot |
|---|---|---|---|
| ledge (run off the tower) | 10/10 | 10/10 | poised in, tossed out poised |
| kicker (knocked in stunned) | 10/10 | 10/10 | stunned in, still stunned out 10/10 |
| inhaler head (blast in) | 10/10 | 10/10 | stunned in, still stunned out 10/10 |

The head's jitter is mostly absorbed by its pull: it drags him to its mouth,
so its blast leaves from nearly the same spot every time (within 4 cm). The
catch there is proven for the head as it sits, not for a head that has
scooted elsewhere. A seesaw station wasn't built; the head was.

Smoke: `studies/cannon_yard.tscn` and `studies/run_layer.tscn` (sprawl seeds
1 and 2, ring seeds 3 and 4) were run headless past the walk start with no
SCRIPT ERROR.

## What it changes

- `scripts/cannon/cannon.gd`: the catch knobs; `swallow`, `set_charge`,
  `catching`, `step_catch`; the tube's squash and stretch (gulp, windup, kick)
  and the glow; `fire` starts the cooldown.
- `scripts/cannon/cannon_field.gd`: the funnel and the swept catch
  (`_funnel`, `_catch_in`, `catch_body`), the "caught" mode (held as the
  motor's rider, with no buttons), the beat (`_hold_caught`), the shot
  (`spit`), and letting go if he is knocked out (`_let_go`). It also keeps
  logs (`catches`, `spits`) for checks. The operating camera is now only for
  operating and inside.
- `studies/cannon_yard.gd`: stations 2 to 4. The yard also carries a
  TrapField (the kicker, an inner `CatchKicker` over `stun_kicker.gd`) and an
  EnemyField (the head), stepped with the cannons through an inner `Both`.

In runs, any generated cannon now catches a pilot who comes down into its
mouth along the barrel. Nothing in the generator was changed.

## Tests affected

Run: `test_cannon`, `test_stun_yard`, `test_pilot_stun`,
`test_dragon_grip_stun`, `test_run_layer` all pass.

- `test_cannon` failed with the first version: the launch from cannon A came
  down onto the near isle through cannon B's mouth, from behind, and B caught
  him. `catch_cone` (72 deg) fixed it: a body skimming past the mouth along
  the aim isn't swallowed. It passes now.
- `test_layer_sprawl` (slow) fails 6 checks. Five are in the plan
  (`_sprawl_plan`: silhouette build budgets, "the spawn faces it", "an exit
  chain of 6 crossings", and an out-of-bounds read at line 133 with no
  threshold slab). Those never load a cannon field, and the catch adds only
  knobs to what the planner reads. The sixth, "Into the void, the next layer
  (seed 4 -> 65624)", is a seed check after a void drop. Its own cannon check
  ("the chain's cannon lands him on its catch") passes. These look like
  existing failures, but they were **not run against a baseline**: setting the
  changes aside to rerun the test on bare `roguelike` was not done.

## Unverified (needs a windowed look)

- Whether the tell reads: the squash amounts, the wobble, the windup's
  shake and glow, the kick. The cannon's barrel only animates in `_process`,
  so the headless checks never drew it.
- Whether the swing of the chase camera down the shot during the hold is
  welcome or disorienting.
- Whether the funnel feels like a fair catch or like a magnet. It reaches 2.64 m
  and turns him fast.
- The sounds are placeholders (`gulp`, `charge`, `boom` in `heard`).
