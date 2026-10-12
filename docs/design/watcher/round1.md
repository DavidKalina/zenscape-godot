# The watcher, round 1

A stranger stands on the aqueduct isle's south rim with his binoculars up,
slowly following something far off. Raise your own binoculars, follow his
line of sight, and you spot a glint on the rune serpent's back as it flies
its loop. Ride the serpent and touch the glint to take it. In the game the
glint will be a plane part (the tail fin caught in the serpent's ridges).
This round tests one thing: does following his gaze lead you to the find,
with no text pointing and no aim help?

Branch `study/watcher`, off `feature/binoculars`. It's a greybox study, not
merged.

## Running it

- `./run-watcher.command` is the game straight in (`--no-title --watcher`).
  Other flags pass through.
- `godot --path . -- --no-title --watcher` does the same. The aqueduct isle
  takes the flag too (`res://studies/aqueduct_isle.tscn -- --watcher`).
- Without `--watcher` nothing changes. The hook only makes him when the
  flag is set and the serpent is there (not with `--no-serpent`).
- The binoculars are the binoculars round's own: hold right mouse or pad LB
  on the ground, and use the wheel or triggers to zoom.

## Where he stands

- On the south rim's turf, about 13 m west of the parked plane, so he's
  the first thing you see turning from the plane. He stands at about
  (94, 30, 14.4).
- He is placed from the isle's ground and doesn't move it. A ray march
  starts at the named anchor `STAND_FROM` (94, 4) and walks south over the
  turf until the turf ends or jumps by more than 1 m. He stands
  `STAND_BACK` (1.6 m) back from that edge.
- From there the serpent's home pass runs about 15 to 20 m off along
  z 33. The dip, the cloister tarn and the drowned nave lie to the south and
  south-west, 150 to 500 m out.
- A column on the parked plane's layer (1 << 13, which only the walker sees)
  keeps you from walking through him.

## How the gaze works

Code: `scripts/kit_isle/watcher.gd`. The hook is a few lines in
`studies/aqueduct_isle.gd` `_add_life`. The test is `tests/test_watcher.gd`.

- **His body:**
  - `PilotFigure` (assets/models/pilot.glb) is repainted through its own
    `_paints` by surface name: a teal cap, an olive coat and hem, a mustard
    scarf, brown trousers and dark mitts. The fleece and skin stay the
    pilot's.
  - He's driven by `body._advance(delta)` alone, so he plays the idle with
    no motor.
- **His pose:**
  - Over the idle, the chest takes `CHEST_PITCH` of the gaze's pitch and
    the head takes the rest.
  - The arms lift by `Binoculars.ARMS` through the same `_turn_bone` calls
    the pilot's raise uses.
  - `Binoculars._make_pair()` sits between his mitts, tilted by the pitch.
- **Tracking:**
  - Each frame (process priority -50, after the serpent and its rider and
    before the scene) the find is placed on the serpent's back.
  - His facing and pitch ease toward the find with `TRACK_EASE` (0.6 s). The
    whole body turns, not just the head.
  - That lag is what makes him look like he's following something. As the
    serpent goes by at 32 m it keeps him within about 8° of it. Far off he's
    on it.
- **His states:**
  - `watch`: up and tracking, for 7 to 13 s.
  - `rest`: down for 2.4 s. If you're within 14 m, his head turns to you,
    up to 0.9 rad, and the body takes the rest of the turn. Then he goes
    back to `watch`.
  - `wait`: entered when he hasn't seen the find for 1.5 s (a ray from his
    eyes every 0.25 s, the serpent's own capsules left out). He lowers the
    binoculars and faces the find if it's within 300 m, else the serpent's
    way 220 m before its home pass, where it comes out from behind the hill.
    He raises them when it's back in sight.
  - `done`: the find is taken, the binoculars stay down, and he glances at
    you if you're near.
- **One lap** (a headless run, about 153 s): watch 93 s, rest 12 s, wait
  48 s.
  - He waits behind the tarn isle, past the nave and up the gorge, then
    looks again as it comes home along the rim.
  - At the start the serpent is at the dip, about 165 m south-east and
    below him, and he's already on it.
- **The find:**
  - A rune token (`RuneToken.diamond` and `ring`, 0.7 m, slowly spinning)
    rides 45 m back from the snout, 0.7 m over the crest of the nearest
    ring. That's in the stretch where riders stand (`RIDE_ARCS` 20 to 60).
  - `Binoculars.spottable(find)` with no objective, so it glints through the
    binoculars until it's taken.
  - On foot within 1.6 m of it, it's taken. It's freed, the moments HUD pops
    "A rune, caught in the old serpent's ridges" with a blip, and nothing
    goes in the ledger.
- **His line:**
  - Within 4 m, once every 45 s, and only while the find is still there:
    "Something's caught on the old snake's back."
  - It streams in at 32 characters a second at the screen's foot (CanvasLayer
    2) and holds 3 s. If you walk off past 8 m it fades.
  - Nothing pauses. While he speaks he's in `rest`, looking at you. Then he
    raises the binoculars and turns back to the serpent, and that turn is
    the cue to follow.

## Checks (headless)

- Import: clean.
- `zenscape.tscn --quit-after 300`:
  - With `-- --no-title`: 3 runs, clean.
  - With `-- --no-title --watcher`: 4 runs, no script errors. Two of them
    reported the known audio quit leak (15 to 17 AudioStream playbacks,
    kinglet.mp3 still in use, as kit_audio.gd documents and the binoculars
    round saw). None of the leaked objects are the watcher's.
- `tests/test_watcher.gd`: passes, about 9 s. It checks:
  - he stands near the start on the rim's turf
  - he sees the serpent coming home and his gaze stays within 10° of the
    find as it flies by
  - the find glints through the pilot's binoculars aimed his way, and not
    once they're down
  - near him his line streams in and he lowers his binoculars, nothing
    pauses, and the line fades when you walk off
  - on foot at the find it's taken, with the pop

## What's weak

- **Nothing visual is verified.** None of these have been seen:
  - his colours
  - the pose with the pair at his face
  - whether the body turn reads from 10 to 30 m behind him
  - whether the glint on the serpent stands out through the binoculars
  - the line's legibility
- **His raised arms are the pilot's angles,** reused blind. Combined with
  his chest pitch they may not meet his face when he looks well up or down.
- **The home ledge's steps hide the serpent briefly** as it comes home past
  them (his eyes are only 0.95 m up). He drops into `wait` for a moment,
  still facing it.
- **Standing right behind him hides the glint.** His column (1.6 m) is
  solid to the binoculars' glint ray, so a find straight past his head is
  hidden. Stand beside him.
- **The glance is head and body yaw only,** and he doesn't step. A glance
  at someone straight behind him swings his body round on the ease.
- **The find is a rune, not the fin.** `plane_parts.gd` isn't on this
  branch.
- **Taking it is a distance check, not a collider.** You have to be on its
  back near the 45 m mark. Riding there is the serpent ride's usual
  boarding from a ledge.
- **The line is plain screen-bottom text,** with no name or speaker mark,
  and it never repeats differently.

## Open questions

- Is the body turn enough of a pointer at 400 m, or does he need an arm
  gesture (pointing once, when he lowers the binoculars) for the far
  stretch?
- Should he stand higher, so the home ledge never hides the pass? The
  castellum's top or the stair's head, say.
- Should he react when you take it (a nod, a second line), and should he
  then point at the next thing?
- Should the glint be visible to the naked eye as a faint sparkle when the
  serpent passes close (20 m), or only ever through the binoculars?
- One line or none: does the line help, or does it give the find away
  before the gaze has a chance to?
