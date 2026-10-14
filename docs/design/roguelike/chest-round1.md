# Treasure chest, round 1

A chest the pilot opens: the kit's carved chest with a lid that lifts, spills
runes as the existing rune pickups, pays them into the run, makes a noise,
and stays open. A prototype round: judged by playing, proved headless with a
throwaway probe (not committed), no tests added.

Branch `roguelike-chest` (cut from `roguelike`, b2ec3c19), worktree
`.claude/worktrees/agent-ad3f708db7ac414a6`.

Play it: `studies/chest_study.tscn -- --no-title` (Windows:
`& $env:GODOT --path . studies/chest_study.tscn -- --no-title`). The first
chest opens to Space / A beside it; the second is locked and wants a slam on
its lid (jump onto it from height, crouch in the air).

## What exists, and what was reused

| Need | Reused |
|---|---|
| Look | `RuinKit.tomb_chest` (the base) and a lid built from the same recipe |
| Rune pickups | `GlyphPickup.make("rune", 0.7, phase, calm=true)`, taken with its own `take()` twist-and-wisp, by the same walker reach sweep as `LayerStage.touch` and `KitTokens.touch` (`Lines.WALKER_REACH`) |
| Run count | `RunState.take_rune()`, wired the way `run_loop.gd` wires `stage.rune_taken` |
| Slam | the `Slam.GROUP` / `slam(at, radius, strength)` call and `Slam.decent()` (the buried find's rule) |
| Foot-piece slot | `before / after / pose / frame / reset`, as `CannonField` is stepped |
| Input | the game's `walk_jump` action, read as an edge, as the cannon's "operate" |
| Noise | `EnemyField.sound(name, at)` (logs in `sounds`, calls `sound_hook`); the `sounded` signal pattern of `CannonField` and `Trap` |
| Glow | `BuriedFind._glow_material()` |

Not found in the game: an interact action (the cannon borrows Jump, so the
chest does too), and the dragon's attention. `ideas-dragon.md` has a table
(opening a chest = "big spike") but no code reads it. The only noise path is
`EnemyField.sound` plus the signals, and nothing consumes them yet. The
chest sends the noise down that path and stops.

## Files

New:
- `scripts/chest/treasure_chest.gd`: one chest (model, lid animation, rune
  toss, rune pickup sweep, the noise clip).
- `scripts/chest/chest_field.gd`: the set of chests in a scene: the press,
  the slam, the foot-piece slot, the prompt, the noise out.
- `studies/chest_study.gd` / `.tscn`: the study.
- this doc.

Edited, one shared script: `scripts/ruin_kit.gd` `tomb_chest(seed, weathered,
with_lid := true)`. With `with_lid` false it adds the rubble and returns
before the lid. The default path draws the same numbers as before.

## Behaviour

**Knobs** (`field.add_chest(at, yaw, knobs)`):
`runes` (5), `locked` (false), `loud` (1.0: scales the sound's reach and is
carried in the noise), `seed`, `weathered` (0.25). Constants at the top of
`treasure_chest.gd`: `MODEL_SCALE` 0.65 (0.65 of the tomb chest, about 1.5 x
0.7 x 0.6 m), `WINDUP` 0.26 s, `SWING` 0.22 s, `SETTLE` 0.55 s, rune flight
0.5 to 0.7 s, `SPILL_GAP` 0.07 s.

**Opening.** `yaw` 0 opens the mouth toward +z, hinge on the back (-z) edge.

1. Wind-up (0.26 s): the lid trembles and cocks a crack open, the body
   squashes 3.5 percent.
2. Swing (0.22 s): the lid flings back to -122 deg, the body stretches 3
   percent, the glow comes in.
3. Settle (0.55 s): damped bounce to -108 deg and rest; the glow breathes.
4. The noise goes out at the swing's start. The runes are tossed from the
   mouth 0.1 s later, 0.07 s apart, on arcs 1.5 m high to a fan in front of
   the chest (1.0 to 1.9 m out, +-110 deg), on the ground found by a ray
   under each spot (falls back nearer, then to the chest's own height if
   there is no ground, so none is thrown off a rim).
5. The lid's collision is dropped as it goes up. The base stays solid.

**Open stays open.** `state` "open" is final. `reset()` (a respawn) does not
shut it, and the runes already spilled stay where they lie. Only
`close_all()` (the study's restart) shuts them.

**Triggers.**
- Press: a fresh `walk_jump` within 0.9 m (times the walker's size) of the
  footprint's edge, on the ground, within 1.2 m of its height. The press is
  also a jump; as with the cannon, nothing swallows it. A dedicated action
  would be cleaner if the generator puts many chests near ledges.
- Slam: a slam at or above `Slam.decent()` (a 4 m drop) landing on the lid
  (within 0.4 m of the footprint, within 1 m of the lid's top) opens it.
- `locked`: a press rattles the lid (0.3 s, signal `rattled`) and nothing
  more; a decent slam opens it all the same. (There is no key item in the
  game; the slam is the "lockpick", the same trade as digging up a find.)

**Pay-out.** Each rune is the sky's rune pickup. When the walker's middle
sweeps it, it twists into a wisp as ever, the chest emits `rune_taken(left)`
(left = runes still lying or yet to be thrown), the field re-emits it, and
the owner calls `run.take_rune()`. A chest of N pays N, one by one, only to
a pilot who walks through them: runes left lying are the greed that the
dragon can punish. Nothing is paid at the press.

**Noise.** On the swing's start the chest emits `opened(at, loud, how)`; the
field logs `[&"chest_open", at, loud]` in `heard`, emits
`sounded(&"chest_open", at, loud)` and, if `field.enemies` is set, calls
`enemies.sound(&"chest_open", at)`. It also plays its own clip (a creak, a
lid clack, a spill of five pings, synthesised in `TreasureChest.clip()`) on
an `AudioStreamPlayer3D` with `unit_size` 14 x `loud`, so it carries.
When the dragon's attention exists, it should subscribe to
`ChestField.sounded` (or `EnemyField.sound_hook`) and treat `loud` 1 as the
table's "big spike". Not done: any hearing.

## How the generator would place it

Not wired (another agent is on the generator). The shape of the wiring, from
how the layer places pickups:

- `LayerPlan` puts the rune set in `plan.prize = {isle, at, room, runes: [Vector3]}`
  (`layer_plan.gd` ~line 480, on the greed isle's roomiest `perch` socket,
  a ring of `RUNES` = 5 at `ring` radius). `LayerStage._runes()` builds those
  as `GlyphPickup` holders, `touch()` sweeps them, `rune_taken` counts, and
  `run_loop.gd` connects `stage.rune_taken` to `run.take_rune()`.
- A chest would be one more plan entry from the same pass, placed on a
  `perch` socket (the sockets carry `at`, `room`, and a kind): add
  `plan.chests = [{at, yaw, runes, locked}]`, `at` the socket's ground point,
  `yaw` facing the way in (the branch's `to_rim.face` reversed, so the mouth
  opens toward the pilot arriving), `runes` from the tier
  (`ideas-runes-ledger.md`: a normal isle pays 4-8, a risky one 10-16, so a
  chest of 4-6 on a normal isle, 8-12 on a greed branch), `locked` true on a
  risky one. Either replace the greed ring with a chest, or add the chest to
  a second perch.
- `LayerStage.setup` would then, next to `cannons`:
  ```
  chests = ChestField.new()
  add_child(chests)
  chests.study = scene; chests.motor = scene.motor
  chests.enemies = enemies            # the noise goes to the EnemyField
  chests.rune_taken.connect(rune_taken.emit)   # run_loop already counts it
  for c: Dictionary in layer.get("chests", []): chests.add_chest(c.at, c.yaw, c)
  ```
  and `before / after / pose / frame / reset` delegate to it like `cannons`
  (`inner` stays null: the stage already is the slot). Because the field adds
  itself to the slam group and takes `Jump` itself, nothing else is needed.
  `stage.taken` counts the ring only; the HUD's "runes %d/%d" would want the
  chests' count added or kept separate.
- A chest that is a motif piece (a `piece_block("tomb_chest", ...)` of a kit
  isle) could be swapped in the same way: the motif's `place.call("tomb_chest",
  ...)` becomes `add_chest` at the same frame.

## Proof (headless)

A throwaway driver (kept out of the repo) loads `studies/chest_study.tscn`
scripted, then through `Input.action_press` only: walks up with
`move_forward`, presses `walk_jump`, waits, walks through the runes with
`move_forward`, then presses again, resets, rattles the locked chest, drops
the pilot from 9 m and presses `walk_crouch` for the slam, and walks through
the second chest's runes. It checks: the press opens it; one noise logged
(`chest_open`); 5 runes thrown and landed; none paid before they are taken;
the run's count rises by exactly 5; a second press does nothing; a reset
leaves it open; the locked chest rattles and stays shut; a slam on the lid
opens it (`how` = "slam"), one more noise; its 3 runes pay (5 to 8). Run
six times: 6 of 6 clean, no errors in any log.

Smoke: `chest_study.tscn` 500 frames; `run_layer.tscn` sprawl seeds 1-3 and
ring seeds 1-2, 400 frames each: no SCRIPT ERROR.

Geometry check (printed from the meshes): the lid closed spans y 0.74 to
0.96 over the base's top at 0.75; open at -108 deg it stands behind the
hinge, y 0.69 to 1.88, z -1.16 to -0.59, clear of the mouth.

## Not verified / known gaps

- Looks and the animation's feel are unseen (headless only). The wind-up,
  the swing's overshoot, the glow and the rune arcs are numbers, to be judged
  by eye in a play session. Per AGENTS.md animation is meant to be judged in
  rendered captures; none taken.
- The noise has no listener, so "greed is loud" is audible to the player
  only. The `sounded` signal and `enemies.sound` are the hook.
- The press is Jump; near a chest a jump is also an open.
- Model (docs/art/model-budget.md): no new art asset; the base is the
  existing piece (1571 triangles at weathered 0.25, rubble and moss
  included) and the lid is a 60-triangle slab from the same Build recipe.
  Which tricks apply: *import LODs / visibility ranges* would help a layer
  with many chests (a chest is far smaller than its 1.6k triangles needs at
  distance; estimate a distant copy at ~300 triangles, a saving of ~1.2k each
  beyond the visibility range); *rigid parts on bones* is what the lid
  already is (a separate rigid mesh on a pivot, not skinned, no cost beyond
  one transform); *vertex-colour grime* is already how the kit's stone is
  toned. Sculpt-bake, silhouette geometry and parallax are not applicable to a
  prop at this size. Frame cost: one transform and one material alpha per
  opening chest, nothing for a shut one.
- Tests (run headless, 8 token, rune, ledger, ruin, slam, scale and layer
  tests): none broken by this round. test_ruin_kit, test_slam and
  test_rune_serpent hit the default 180 s timeout on this slow machine and
  pass at --timeout 500 (193, 141, 194 s). test_collectibles_pickup fails on
  engine errors from studies/cozy_worlds.gd `_layout_shell` (Control set_size
  with a non-finite size at the headless 64x64 viewport), nothing the chest
  touches; not checked against a clean roguelike. test_run_layer, test_ledger,
  test_glyph_token, test_flight_tokens, test_ruin_floating, test_ruin_growth,
  test_telescope, test_world_scale_fit/guard and the ruins archipelago pack
  pass.
