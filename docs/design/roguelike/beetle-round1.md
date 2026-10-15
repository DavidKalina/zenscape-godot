# The Millstone Beetle, round 1 (feature `beetle`)

Part of the "make it feel like a game" round (items-contract.md). This round
adds the deck's patroller from ideas-enemies.md (2) and the shortlist. It is
a heavy scarab that rolls a millstone up and down a lane of an isle's flat.
It sees only down its lane, ahead of its wheel. When it sees him it plants,
racks the wheel back in its grip (click, click, CLACK) and charges dead
straight. A hit knocks him hard down the lane, and the lanes run to the void.
Dodge it late near a lip and the wheel tears out of its grip and goes over.
The wheel falls, lands on whatever is below, or jams in a gap narrower than
itself and becomes a plug he can walk over.

The feature is on by default. `--no-beetle` (or `--loot=off`) turns it off.

## Play it

```sh
# Meet it alone: three lanes (causeway, slot, terrace), a beetle on each.
/Users/davidkalina/Applications/Godot.app/Contents/MacOS/Godot --path . res://studies/beetle_yard.tscn -- --no-title
#   --lane=causeway|slot|terrace   one beetle only
#   --wheel=1.6                    a bigger wheel (a real jam bridge, no jumping it)

# In the run. Seeds 2 and 4 (sprawl and ring) lay two beetles, seed 11 lays two.
/Users/davidkalina/Applications/Godot.app/Contents/MacOS/Godot --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=2
#   --beetles=2      always lay up to 2 (else rolled 0-2 a layer)
#   --no-beetle      none
```

The log prints `beetle: on isle N, a lane L m, K lip(s)` when one stands.
That happens lazily, when he comes within 70 m of its spot.

In the yard, go up the causeway. The beetle comes at you down it. Jump the
wheel as it arrives, and you land on its shell and are bucked off behind
it. Then wait by the far lip. When it charges, jump at the last moment: the
wheel goes over the lip onto the ledge 3 m below and falls flat there as a
new stone. At full pace the beetle goes over after its wheel. Do the same
on the slot lane and the wheel jams in the slot. On the terrace there is
room to step out of its line instead.

## What it is

- `scripts/enemies/millstone_beetle.gd`: the beetle, on the enemy base
  (`enemy.gd`), stepped by the stage's EnemyField. It has these states:
  - **patrol**: rolls toward its lane's end at walk x 0.75.
  - **turn**: rests at the end, then hauls the wheel round in 1.15 s. It
    never turns early.
  - **notice**: stops dead, raises its head and feelers, and hisses.
  - **tell**: sinks and splays its legs, and the wheel racks back a notch
    per click. Three clicks over 0.85 s, then a 0.2 s hold.
  - **charge**: a 0.5 s wind-up to run x 1.45 (about 7 m/s), dead straight.
    It cannot steer.
  - **commit**: until 0.55 s before contact it still looks. If he steps out
    of its line, if a lip is inside its stopping distance, or if he is out
    of range, it stops safely. After that point it charges blind.
  - **brake**: legs dug in, sitting back, dust, grinding. From full pace it
    needs `kill_band` (2.7 m) to stop.
  - **dig**, then **teeter**, **plunge** or **bereft**. Without its wheel
    it is harmless and wanders its lane. Pushed off a lip, it falls.

  The hit uses the existing harm path: `PilotMotor.knock` (12.5 m down the
  lane, a hard hit that lays him down 0.7 s) plus `harm("beetle",1)`, which
  costs a heart. The death card says "by the millstone beetle". Only the
  wheel's face hurts, and only while his feet are under 0.4 of its height.
  A pilot hanging from a rim is never touched. Its body is two solid
  boxes, the wheel and the shell. He can stand on the shell. When it is
  charging, braking or teetering it bucks him off behind it.
- `scripts/enemies/millstone_wheel.gd`: the wheel once it is let go. It is
  scripted rather than a rigid body, so it plays the same every time:
  - It rolls with drag and speeds up down slopes.
  - It crushes him above 2.2 m/s.
  - It bounces off walls.
  - It wobbles and falls flat when slow, becoming a round step.
  - At a lip it looks across. If there is ground again within 0.95 of its
    diameter, it **jams**: it drops into the gap with its top `flush`
    (0.38 m) over the lip, as a plug to walk over. Otherwise it falls,
    lands with a thud and a bounce, and rolls on. Out of sight it lands
    with a far crash.
- `scripts/enemies/millstone_look.gd`: the model, built in code.
  - The wheel is a lathed millstone (chamfered rim, worn dents, a chip,
    the eye) dressed in the Olmec's weathered basalt
    (`inhaler_head_look.gd` `_dressed` and `stone_material`, so the grain
    turns with it), on a squared timber axle.
  - The beetle is a low domed scarab. It has six legs on hip pivots (the
    front pair grip the axle, the rest walk a tripod gait), a small head
    with a shovel lip, bead eyes and clubbed feelers.
  - The shell uses `shaders/beetle_chitin.gdshader`: dark umber and bronze
    chitin, worn paler on its high points, faint scratches and pits, and
    ochre dust caked from the feet. It is all in solid noise over each
    part's rest pose, with fine layers faded by pixel footprint.
  - There are no horns, spikes or glows. The tell is pose, wheel and sound,
    never colour.
- `scripts/enemies/beetle_voice.gd`: placeholder synthesized sounds. They
  are the clicks, the clack, the hiss, the scrabble, the grind, thuds, the
  wheel's jam and far crash, and a looped rolling rumble whose volume and
  pitch follow its pace.
- `scripts/roguelike/layer_beetles.gd`: laying in the run.
  - **Candidates.** The plan's arena, perch and cover sockets are shuffled
    by seed. They are kept away from the spawn (22 m), the gate (12 m), the
    ram (16 m), heads (16 m) and the rune perch (6 m), with one beetle per
    isle.
  - **Lanes.** When he comes within 70 m of a candidate, its ground is read
    with rays, one candidate a frame. Twelve lines through the spot are
    walked both ways in 0.5 m steps. A line keeps going while the ground
    stays flat (no step over 0.22 m, no rise over 0.6 m), it is wide
    enough, no wall blocks it, and it stays over the isle's own solid (so
    it never goes onto a bridge).
  - **The pick.** The best line is at least 8 m long, has at least one lip
    end (the void is the threat), and is clipped to 16 m by its lip. Its
    patrol ends are inset from the lip.
  - **How many.** The count is rolled from `COUNT` (0-2: 0 one time in 7);
    `--beetles=N` sets it.
  - It wraps the field's `sound_hook` so the beetle's sounds play beside
    the heads'.
- `studies/beetle_yard.tscn`: the yard.

### Hooks in shared files (marked `# [beetle]`)

- `scripts/roguelike/layer_stage.gd`: the preload, `var beetles`, the
  `LayerBeetles.dress(self,layer)` call after the collectibles, and
  `beetles.before(delta)`.
- `scripts/roguelike/run_loop.gd`: `"beetle":"the millstone beetle"` in
  `WORDS.causes`.

## Knobs (n = pilot numbers; `default_knobs` in millstone_beetle.gd)

| knob | default | what |
|---|---|---|
| wheel | 1.0 | wheel diameter = his plain jump (0.8 m) x this; the shell scales with it. `--wheel=` in yard and run |
| patrol_speed / turn_time / end_rest | walk x 0.75 / 1.15 s / 0.6 s | the patrol |
| notice / notice_side | run x 2.1 (10 m) / unit x 1.2 | sees him this far ahead of its wheel, this far to its side |
| tell / retell / clicks / hold | 1.05 / 0.6 s / 3 / 0.2 s | the rack |
| charge_speed / wind_up / charge_dist | run x 1.45 / 0.5 s / run x 3.4 | the charge |
| commit / line_out | 0.55 s / unit x 0.3 | stops looking this long before contact; out of line this far past its wheel's danger = a safe stop |
| kill_band / lip_brake | unit x 2.4 / run x 4 | stopping distance from full pace; a safe stop's hard brake at a lip |
| over_share / teeter | 0.72 / 0.8 s | at the lip faster than this share of its top, it goes over after its wheel |
| hop | 0.4 | his feet over this share of the wheel's height clear it |
| shove_out / shove_up / down | run x 2.6 / unit x 0.55 / 0.7 s | the hit |
| stun_wall / stun_hit / stun_miss | 2.2 / 0.9 / 1.4 s | |
| push_carry | 0.3 (0.85 bereft) | how far his slide throws it |

Wheel (millstone_wheel.gd): `roll_drag` 0.9, `harm_speed` 2.2, `topple_speed`
0.55, `jam` 0.95 (of its diameter), `flush` step_up x 0.85.

## Measured (headless, through the real input path; scratch drivers, not committed)

- **Standing on its lane.** Noticed at once, a 1.05 s tell, then about
  1 s of charge to reach him 6 m off. He is hit and knocked 12.4 m down
  the lane.
- **Jump (A) on the causeway.** It clears the wheel when started 0.74 to
  2.7 m before the wheel's face at 7 m/s, which is about 0.1 to 0.39 s. A
  jump at 0.4 m is too late. He lands on the shell and is bucked off
  behind it.
- **Step aside on the terrace.** A step started 2.4 to 5 m out (0.35 to
  0.7 s) is a miss. At 1.8 m or less he is hit. Past the commit it is a
  late dodge: it brakes blind. Before the commit it sees him go and stops
  safely.
- **At the causeway's far lip.** A late jump sends the wheel over. It lands
  on the ledge 3 m down, rolls and falls flat. The beetle plunges after it
  and is stunned on the ledge, then wanders bereft.
- **At the slot.** The wheel jams in the 0.6 m slot. The beetle stops at
  the lip, teeters and goes bereft. He walks over the plug.
- **In the run.** Over sprawl and ring seeds 1-5, every layer that rolled
  beetles stood them all: 6 of 10 layers rolled 1 or 2, 4 rolled 0. On
  sprawl seed 11 (`--beetles=2 --knob=heads=0 --knob=bodies=0`) it noticed,
  told, charged and hit him, knocking him 17 m off its terrace to the one
  below.
- **Smoke.** `run_layer --shape=sprawl --seed=11` (900 frames), the yard
  (900 frames) and motif_yard (`bell_spires`, `lidstack`) all pass with 0
  errors. One earlier run_layer smoke failed on an exit-time
  `PagedAllocator ... GeometryInstanceDummy` leak. The next three runs were
  clean, so it looks flaky. If it comes back, suspect the beetle's nodes at
  exit.

## Rough

- **The bridge is small.** At default size the wheel is 0.8 m across, so
  it only jams in gaps under 0.76 m, which he can step across anyway. The
  jam reads as spectacle, not a tool. A real "bridge" needs
  `--wheel=1.6` or more (jams up to 1.5 m), but then the wheel is too tall
  to jump. The size fights the jump counterplay. The user should pick:
  - a jumpable wheel that rarely bridges, or
  - a giant wheel you must dodge or bait, which bridges real gaps.
- **Jumping looks off.** The wheel equals his plain jump peak, so a
  cleared jump still passes his feet close over its top. In a rendered
  capture he lands on the shell and tumbles off behind it. That reads as a
  scramble, not a clean vault.
- **Animation is procedural, not authored.** Gait, sink and splay, the
  wheel's rack, the lean and the teeter scrabble are all in code. Blender
  clips per AGENTS.md (anticipation and hold keys, a real launch pose)
  would raise it to the bar. It was judged only in stills, not motion.
- **Lanes are found only on what has stood near him.** A lane that
  crosses another isle's crossing rim can patrol right at an arriving
  walker. That is intended menace, but unchecked for fairness, and there
  is no clearance from crossings' landing pads yet.
- **Sounds are placeholder synths, never heard.**
- **No camera shake or hit-stop on the hit or the wheel's crash.** The
  `juice` agent may own that.
- **Wheels on stairs.** A loose wheel on a long down-slope speeds up
  (2/3 g sin). It is untested on the generated layers' stairs.

## Existing tests it may break (not run; no full suite this round)

- `tests/test_run_layer.gd`, `tests/test_layer_sprawl.gd` and
  `tests/test_creature_navigation.gd` load run_layer. A beetle that stands
  near the walker may shove or knock him. `--no-beetle` restores the old
  behaviour.
- `tests/test_enemy_ram.gd` is unaffected: enemy_yard is not touched.

## Model budget (docs/art/model-budget.md)

About 3.5k triangles and about 30 draw calls per beetle. The wheel is a
512-triangle lathe with generated LODs from `_dressed`. The shell, legs and
head are about 25 primitive MeshInstances, roughly 3k triangles. All parts
stop drawing past 140 m (the wheel past 210 m).

| trick | applies? | estimate |
|---|---|---|
| Import LODs + visibility ranges | Yes. The wheel has generated LODs; the beetle's primitives have none. Merging the shell, head and legs into one mesh per pivot, with LODs, is the win. | About 25 to 8 draw calls per beetle. At 2 a layer, about 0.05-0.1 ms CPU. Triangles about 3k to 1k past 40 m. |
| Rigid parts on bones | Yes, when it is authored in Blender. Legs and shell plates as rigid meshes on bones rather than skinned. | Keeps the draw count of the merged version, with no skinning cost. |
| Vertex-colour grime | Yes, on the wheel. Bake crevice darkness at the eye and the chamfers into the vertex AO that `_dressed` already reads (it is 1 now). | 0 triangles, 0 ms; looks only. |
| Silhouette geometry | Partly done: the rim's dents and chip are real geometry. Dressing furrows on the faces would be texture. | Already in. |
| Sculpt high, bake low | Later. A sculpted scarab baked to a 3-5k mesh would replace the primitives at about the same triangles. | About the same triangles, many fewer draws. |
| Parallax depth | No. The pits are shader-only at this size. | |
