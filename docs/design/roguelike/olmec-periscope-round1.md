# Olmec periscope, round 1

The user: "you break his line of sight, he can lift his own head to gain more
line of sight."

Branch `feature/olmec-periscope` (off `roguelike`). It isn't merged or pushed.

## What he does

When the whole Olmec loses you while hunting, he plants, takes his own head
off his shoulders and holds it up overhead in both hands, like a lantern.
Then he turns it slowly, looking around, and holds. Then he lowers it and
puts it back on.

- **When:** he tries it once each time he loses you, at most every
  `scope_rest` s. It happens at the first of these:
  - he walks into cover on his way to where he lost you (a wall in his
    path);
  - he gets to where he last saw you;
  - he has lost you for `scope_wait` s within `scope_near` Hh of that spot.
- **Squaring up:** if low cover is a few metres ahead, he first steps up to
  it and squares up to its face, so the head goes up over it. Low cover is
  any wall he could see over with the head held up. Then he plants. He
  doesn't walk or step-turn while the head is up. That's your window to slip
  away.
- **His sight from up there:** while the head is up, his sight is cast from
  the head where it is held, along its turn, with a cone 1.5 times as wide.
  His eyes go from about 7.2 m to about 11 m over his feet, and he leans
  out over low cover by up to `scope_lean` rad. If the held head would go
  into a wall or a ledge's face, he leans less.
  - A low wall no longer hides you, even pressed against its back.
  - A tall wall still hides you.
  - So does an overhang over you (the arch's lintel).
- **If the raised head spots you:** you have to be seen for `scope_spot` s.
  Then he calls, and if his head's draw reaches you with nothing between,
  he inhales from up there through his existing worn suck. That uses the
  same `suck_tell`, `suck_for` and `suck_lose` knobs, and it turns his trunk
  and head after you. The pull yanks you up over a low wall, or off a ledge
  above him. Swallowed, held, blown out, he lowers the head and chases.
- **If not:** "Nothing", and he lowers the head. Then he searches on: the
  look-about if he was at the last-seen spot, otherwise the chase toward it.
  After that he climbs, skirts or gives up as before.

## The animation

Three new clips are authored on his rig in
`art/blender/headless_body/headless_body_build.py` (section "the
periscope") and baked into `assets/models/headless_body.glb` with
`bake_clips.py --clips=scope_lift,scope_look,scope_lower`. No other clip
changed. The procedural layer is in `headless_body.gd` (`_scope_pose`,
`_scope_hands`).

- **`scope_lift`** (1.7 s):
  - His hands come up to the sides of his head, and the palms grip it.
  - A pry: a tremble as it cracks off the stump.
  - A deep dip with the head, the anticipation.
  - The heave up overhead: stretched tall, overshot.
  - The head's weight sinks him into the key pose.
- **The key pose:** the head held up in both hands, the arms nearly
  straight, the elbows out, a clear gap over the empty stump, its cut
  glowing warm.
- **`scope_look`** (3 s loop): held up there, a breath, a weight shift, the
  arms straining a little.
- **`scope_lower`** (1.6 s):
  - A small lift first (the anticipation).
  - Down slowly and carefully.
  - The seat: a clunk and a held squash.
  - He lets go, and his hands drop.
- **On top (procedural):**
  - **The turn:** his trunk twists (hips, spine, chest) toward where he's
    looking, slowly, and the head turns a little further in his hands. The
    turn holds, sweeps `scope_sweep` rad one way, holds, sweeps the other,
    holds, and comes back.
  - **The lean:** spine and chest pitch out over low cover, and back when
    he's looking up at a ledge.
  - **The head:** it rides between his wrists from the grip until it's
    seated. It stays upright, its face tipped down as he leans out.
  - **The hands:** IK keeps them on the real head's sides, so they follow
    head-size changes (the `,` and `.` keys).

The captures were judged by eye: a three-quarter view behind the low wall
(the wanderer pressed to its back), a view from behind at the tall wall, and
a side view at the ledge. The key pose reads at a glance: a stone giant with
his own head held up over a wall, the empty stump glowing under it. Fixes
made from the captures and the driver:

- **Head off his hands:** a turn step's blend dragged his arms down while
  the head came off, so for most of the lift the head hung at his waist.
  Now he finishes squaring up, turn steps and all, before the lift, and he
  never step-turns with the head up.
- **Seat nod:** the seat's forward nod was too deep, so it was cut.
- **Fists:** the grip was curled into fists, so it was opened to palms.

The PNGs are in `scratch/shots/`, which is gitignored and not committed.

## How to launch it

`run-whole-body-chase.command` (new), or:

    /Applications/Godot.app/Contents/MacOS/Godot --path . --rendering-method forward_plus --windowed --resolution 1440x900 res://studies/whole_body_chase.tscn -- --no-title

On Windows, use the same arguments after `& $env:GODOT`.

1. Get spotted.
2. Run south past your start to the new cover yard and break his sight.
   The yard has:
   - **A low wall** (5.5 m, orange top), from x -10 to 4. Its east end
     faces a gap. Hide pressed to its back: he can't see you from his
     shoulders, but he can with the head up.
   - **A tall wall** (14 m), east of the gap. Hides you either way.
   - **An arch** (south-west): a lintel 2.6 m over you between two side
     walls. Hides you under it either way.
   - **A ledge over him** (9 m, the grey block in the south-west corner),
     with your ramp up its west side from the north. Step back from its
     lip: he can't see you from his shoulders, but the raised head can,
     and it pulls you off.

J shows his sight overlay; it now draws his cone from the raised head. F1's
overlay line says "periscope" with the beat it's on and its count.

## Knobs

Set these with `--body-knob=`. `periscope` is on only in this study. The
study sets it through `_study_body_knobs`, so the leap-grab study, the
headless body isle and the generator play as before.

| Knob | Default | What it sets |
|---|---|---|
| `periscope` | 0 (1 in the chase study) | On or off (whole, with `chase` on) |
| `scope_lift` / `scope_look` / `scope_lower` | 1.7 / 5.0 / 1.6 s | The lift, the look (one sweep), the lower |
| `scope_sweep` | 1.0 rad | How far he turns it either way |
| `scope_wide` | 1.5 | His sight cone held up, times `sight_half` |
| `scope_spot` | 0.35 s | Seen this long from up there: found |
| `scope_lean` | 0.38 rad | How far he leans out over low cover |
| `scope_rest` | 8 s | Before he tries it again |
| `scope_near` / `scope_wait` | 1.6 Hh / 1.0 s | Lost this long this near the last-seen spot: he plants at once |

## Checks

- **Import:** a headless import is clean.
- **Smoke:** these each ran 400 frames headless with 0 script errors:
  - `whole_body_chase`;
  - `headless_body_isle`;
  - `whole_body_leap_grab`;
  - `run_layer -- --shape=sprawl --seed=2`.
- **Real-play-loop driver** (`scratch/periscope.gd`, uncommitted), headless
  at a fixed 60 fps.
  - **Setup:** each bout sets the body down by teleport, and its pounce and
    plant-suck are rested so they don't interfere. The wanderer is spotted,
    then walks behind the cover by real input (stick actions).
  - **Results:** all 16 checks pass.

  | Bout | He | Eyes | Found | Then |
  |---|---|---|---|---|
  | Low wall, pressed to its back | stepped up to it, lifted | 7.2 m to 11.3 m | yes | inhaled from up there (pull 6.2 m/s), you yanked over the wall, swallowed, blown out, then the head lowered |
  | Tall wall, round its end | lifted | to 11.3 m | no | lowered, searched on |
  | Under the arch | lifted | to 11.3 m | no | lowered, searched on |
  | Ledge over him, 8 m back from its lip | stepped up, lifted (the head bumped the face and he leaned off it) | to 10.8 m | yes | inhaled, pulled you off the ledge, swallowed, blown out |

  - **Control:** with `--body-knob=periscope=0`, the low-wall bout never
    finds the wanderer pressed to the wall. The body gives up and walks
    back.

## What's rough

- **Squaring up:** he squares up to the nearest low cover's face and sweeps
  about that. If you're far round to one side, the 1.5x cone and the ±1.0 rad
  sweep with the trunk's ±0.9 rad twist may still miss you. He never steps
  round with the head up. That's deliberate: a turn step's arm swing pulls
  the arms off the head.
- **The look is long:** 1.7 + 5 + 1.6 s, about 8 s planted. That's the
  player's window, but it may be too long. `scope_look` sets it.
- **The pull from up there:** it lifts you over the low wall in a big arc,
  because the mouth is high. A gulp counts anywhere in front of him up to the
  head's height. Judge whether that reads as fair.
- **Low cover hides you only at range:** the low wall hides you from his
  shoulders only while you're close behind it. He usually loses you there
  and walks up to it before he lifts.
- **Clipping:** with the head held up, nothing keeps his arms or hands out
  of a wall. The arms stay over a 5.5 m wall in the captures. The held head
  is kept out of walls by the lean cap only.
- **The hands:** they're flat palms on the head's sides, and the thumbs
  aren't placed.
- **The generator:** untried there. It's off there, and it would need
  `periscope` in `LayerBodies.knobs`.
- **Not played:** GPU-only behaviour and the feel in interactive play are
  unverified.

## Tests

No test references the headless body (`grep tests/` for `headless_body`,
`whole_body_chase` and `stone_body`). As far as I know, none break. The full
suite wasn't run (prototyping).

## Models (`docs/art/model-budget.md`)

No geometry changed: the mesh, skin and bones are the same. Only three clips
were added to the glb (about 190 baked frames). So none of the geometry
tricks apply to this round, and there are no triangle or frame-time savings
to estimate.

- **What the round adds per frame:** one box query for the held head, made
  only while the head is up. Everything else rides the existing posing and
  IK.
- **Round 3's note stands:** the mesh is about 89k triangles. If several
  bodies are on screen, the big wins are sculpt high, bake low (to 5-15k
  triangles, most of the triangle cost) and import LODs with visibility
  ranges.
- **The other tricks:**
  - **Rigid parts on bones:** the masonry is already weight-1 per bone.
    Splitting it into rigid meshes would trade skinning cost for draw calls.
  - **Vertex-colour grime:** already used (baked crevice occlusion).

## What the harness lacked

- **A free camera for driver stills.** `shot()` uses the study's camera, so
  `scratch/periscope_shots.gd` adds its own Camera3D. A
  `shot_from(at, look_at)` helper in drive.gd would save that.
- **Setting a body down mid-study.** The chase study's `reset_body` respawns
  at the field's original spec, not at `body_at`. The driver moves the body
  by hand and replaces its `Steps`.
