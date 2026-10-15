# City refuges, round 1: places he can't follow

Four pieces of the new `city` kit (the underground Olmec city) where the
wanderer goes and the whole Olmec can't. They come from the round 3
brainstorm's most-shared idea, "the refuge he can't enter"
(`brainstorm/round3-olmec-city/README.md`):

- `city_mouserun`: k2 `colossus_mouserun`
- `city_niches`: k2 `colossus_niche`
- `city_hush`: k6 `maker_hush`
- `city_slotwall`: k3 `oc_slot`

They're built on the walker-only layer and on the beacons and light-aware
sight.

Branch `kit/city-refuges`, on `roguelike` 2b0e2e0e (after city-breaks and
the underground ground cover).

## Play it

    ./run-city-refuges.command                       # torch look
    ./run-city-refuges.command --underground=haze    # or press L in play

This opens `studies/city_refuges_yard.tscn`: a paved basalt court with a
whole Olmec, which is the whole body chase's Olmec (sight, swat, pounce,
inhale and periscope). Without `--underground` it's daylight, and the day
sight sees through the dark.

- **The Olmec.** He starts at his post in the gallery's forecourt, facing
  its slit. You start south, behind him.
- **North: the hush gallery.**
  - A servants' slit leads into a tier, with a long dark hall behind it.
  - A trough of black water runs across the hall. Wade it and your torch
    hisses out. Jump it and you keep the flame.
  - Past the trough is a carved stele, with a side bay on each side.
  - A passage leaves east, past a lamp that relights the torch.
- **West: the mouse run.** A 1.4 m door at the foot of a 24.8 m wall
  leads into a passage with a jog. He can't climb the wall, so he has to
  walk round it.
- **East: the slotted wall.**
  - A door at the foot leads into a chimney. Climb it ledge to ledge,
    leaf to leaf.
  - His arm slot is level with the second ledge, on his side.
  - At the top, a window in the far face opens onto a balcony.
- **South-east: the votive niches.** Seven lamp-lit shelves zigzag up a
  pier too tall for him to climb, to a dark alcove.

Keys and flags:
- **Keys:** R puts you back at the start (and him too), B puts only him
  back, J shows his sight, L flips the look, F1 shows the numbers.
- **Flags:** `--body-knob=k=v`, `--head-knob=k=v`, `--body-at=x,z`,
  `--body-face=x,z`, `--no-body`, `--no-sight-overlay`.

## The API, and how to register the pieces

`scripts/city_kit_refuges.gd` is a RefCounted with no class_name. It has
`PIECES`, `NAMES` and `piece(id, seed, weathered) -> Node3D`. Each piece
is built in its own frame:
- Its front, his side, is +z.
- y 0 is the ground it stands on.
- Add the piece under the study and move or turn it there.

In `scripts/city_kit.gd`, which is the other agent's file and untouched
here:

```gdscript
const CityRefuges = preload("res://scripts/city_kit_refuges.gd")
# in the family's PIECES:  ... + CityRefuges.PIECES
# in piece(id, seed, weathered):
if id in CityRefuges.PIECES: return CityRefuges.piece(id,seed_value,weathered)
```

Nothing else is needed: no hub and no stepping. Each piece runs itself
(`Refuge._process`) and finds the study's `motor` through the current
scene.

**The piece's metadata, in its own frame:**
- `kind`
- `bounds` (AABB)
- `mouths`: [{at, out}]
- `his_ground`: an AABB of floor he needs in front, to stand and look or
  reach
- `sizes`: every derived number
- `tris`
- `slot` on the slotted wall, and `stele` on the gallery

**At play** (the inner class `Refuge`):
- `inside` is true while he's in it, and `snuffs`, `relit` and
  `echo_count` count those events.
- `RefugeCue` is the hiding cue, one per scene.
- `Shade` is the hall's darkness, a SightLight.
- `CityMesher` is GiantStone's mesher with dust in place of moss, plus
  `dark` boxes: lampblack stone inside a refuge. The Olmec shader's
  hemisphere fill isn't occluded, so a hall reads as dark only by its
  tone.

**What else it calls:**
- `GroundCover.cover` lays the underground's ground cover on every flat
  walk top. Inside the runs and halls that's a thin dust skin with no
  tufts.
- Colliders: what he fits is solid (layer 1). What only the wanderer
  stands on inside is `WalkerOnly.mark`ed. That's the run's floor, the
  shelves, the hall's floor, piers and stele, the chimney's floor and
  ledges, the window sill and the balcony.

## The sizes

The Olmec's numbers come from its own knobs (`headless_body.gd`
`build_of` over `default_knobs`, at the wanderer's scale). The walker's
come from `WorldScale.wanderer`, `PhysicsGround`, `RuinKit.GRAB_TOP` /
`SET_OFF` / `STAND` and `PilotMotor.STEP_UP`. Here is what the yard
prints:

| | |
|---|---|
| Olmec | width 4.37, depth 2.42, neck 6.55, swat reach 4.37 (`catch_reach` 1.3 Hh), climb_max 22.4, eye about 8.07 (measured; `olmec().eye` = neck x 1.23) |
| Walker | tall 1.12, radius 0.28, grab 1.875, rise 1.6, stand 0.58, step 0.45 |

**Mouse run:**
- **The passage:** 1.4 wide (5 radii), 1.79 clear (1.6 tall), and walled
  in solid stone. He's 4.37 wide.
- **The wall:** 24.8 tall (climb_max + 0.7 Hh), 9.0 thick (from his reach
  and depth, so he can't swat to the jog from either face), and 30.6 long
  (7 of his widths).
- **The way in and the jog:**
  - The way in is a 0.36 cill, a step up.
  - The jog is 2.24 sideways, which hides each mouth from the other.
- **The tell:** a small pale lintel stone over each mouth, and an ember in
  the jog.

**Votive niches:**
- **The pier:** 7.0 square (1.6 of his widths), 25.8 tall (over his
  climb).
- **The shelves:** 7 shelves, each 1.4 wide and 1.02 deep (1.75 x
  STAND), a SET_OFF (1.6) apart up the face, zigzagging 0.5 apart either
  side of the middle.
- **The lamps:** one clay lamp per shelf. Every second lamp has a real
  OmniLight3D (range 3.4, no shadow, fading out at 45 to 60 m). Each lamp
  has a SightLight (strength 0.5, radius 2.6), so a lit shelf shows you.
- **The alcove:** at 12.8, 2.24 wide, 2.24 tall and 2.46 deep. It's cut
  into the pier, is dark, and is grabbed from the last shelf by its floor's
  front lip.

**Hush gallery:**
- **The tier:** 26.9 x 14.8 x 9.1 (8 Hh wide). He climbs it.
- **The slit:** 1.4 wide and 4.2 tall (1.25 Hh). From his forecourt, at
  about 15 to 20 m, his eye looks down the hall's aisle. The heavy brow
  over it, 1 Hh forward, cuts that line from closer in.
- **The hall:** 6.72 wide, 4.2 tall and 10.1 deep.
  - The aisle is 2.38 wide, with one row of squat piers forming the side
    bays.
  - The trough is 1.0 wide and 0.36 deep (under STEP_UP, so you can walk
    out of it). It runs across the hall at 1.2 Hh in.
  - The stele is 0.7 x 1.74 x 0.44, in the aisle, off its middle.
- **The exit:** a 1.4 x 1.8 passage east to the tier's side, with the
  relighting lamp in its wall 1.6 from the mouth.

**Slotted wall:**
- **The chimney:** 2.41 across (2.15 x tall).
  - His leaf is 0.45 thick. The card calls it "a thin wall".
  - The far leaf is 1.0 thick. The wall is 13.3 tall (under his climb)
    and 12.1 long.
  - The ledges are 0.9 deep (1.55 x STAND), 0.6 apart edge to edge,
    alternating leaves a SET_OFF up. There are six, to the window at 9.96.
- **His arm slot:**
  - It's 1.2 x 2.24 and cut as an embrasure that splays down inward in 4
    steps.
  - The steps follow his eye's line from where he stops at a wall (about
    2.6 m off; measured 2.2 to 3.2) to a wanderer on his side's first
    ledge (3.56 up).
  - That ledge is the only place his swat reaches you. 3.56 is under his
    swat height, `neck x 0.6` = 3.93. His flat reach is 4.37.

## Hiding reads

- **The cue.** `RefugeCue` closes a dark blue-black vignette in from the
  screen's edges and shows "hidden" low in the middle. It shows while
  you're inside a refuge's hide boxes and no Olmec's sight has you.
- **When he sees you.** If his sight does have you, the vignette turns a
  warm, pulsing red and the label reads "he sees you".
  - The cue reads the truth, `sight.seeing()` on the scene's `enemies`, so
    it never says "hidden" while he sees you.
  - A scene without an `enemies` field gets only "hidden".
- **The torch.** In the trough the torch goes out with a puff of steam and
  the toast "Hsss: your torch is out. In the dark he can't make you out".
  Relit at the lamp, the toast is "Your torch takes the lamp's flame: lit
  again".
- **Still:** `captures/shots/refuges_cue_hidden.png`.

## The sight decision: `sight_walker_only` = 1, and make it the default

What I proved: the gallery's stele is walker-only stone in his line down
the aisle. He stood still at his post and you stood behind the stele with
the torch lit (torch look).

| `sight_walker_only` | Seen | Spotted after |
|---|---|---|
| 1 | visibility 0, never | – |
| 0 | visibility 0.69 | 1.2 s |

At 0 he sees through a stone the player sees, stands behind and is
lit right beside. That reads as a bug, and the player can't tell
walker-only stone from solid. At 1, what you see is what hides you.

Walker-only pieces are meant to be inside places he can't fit or high on
walls (the layer's own rule). So the sight-blocking ghost case, a
free-standing walker-only block in the open, shouldn't be built anyway.

Recommendation: **flip the knob's default to 1.**
- The yard sets it, in `_study_body_knobs`. I didn't change the default
  in `headless_body.gd`; it's the user's call.
- Nothing in the generator uses walker-only stone yet, so the flip
  changes nothing there today.

## The counterplay: no refuge is safe forever

All proved through the real loop, below.

- **Mouse run.**
  - **Waiting.** He seeks where he lost you, lifts his head (the
    periscope), gives up and roams.
  - **Going round** (new, the echo). Move about in the run and your steps
    carry out of the nearer mouth. A silent `Beacon` there is lit while
    you move and for 6 s after.
    - A calm Olmec (not hunting, sight unaware) turns to it, walks round
      to that mouth and stands looking for 8 s.
    - Standing still is silent.
- **Hush gallery.**
  - **Light.** Your torch lit inside the dark hall glows at the slit. The
    `TorchGlow` beacon draws a calm Olmec to the forecourt on the slit's
    line, 5 Hh out, to look down the hall for 10 s.
    - If you're lit on the aisle he spots you, then plants and **sucks
      you out through the slit** (twice, in the proof). That inhale wasn't
      scripted.
    - Snuffed, there's no glow, he never comes and his sight can't reach
      you.
    - A side bay is out of the slit's line, lit or not.
  - **The splash.** Wading the trough carries out of the front mouth for
    3 s.
  - **The relight costs.** The lamp by the exit lights you (a SightLight)
    as it relights the torch.
- **Slotted wall.**
  - **Reach.** He swats you through the arm slot when you're on his
    side's first ledge, knocking you onto the far ledge below.
  - **Timing.** Climb past that ledge quickly and his swat misses.
  - **Over the top.** He can still climb the wall's outside and stand on
    top (13.3 m, under his climb). That wasn't driven.
  - **The inhale through the slot** from 15 to 23 m isn't driven either.
- **Votive niches.**
  - **The lamps light you on the ladder.** In his sight he spotted you,
    sucked you off the shelves and pounced, three catches in the proof.
  - **The alcove is dark and cut in.** He roamed 90 s and never saw you
    there.
  - **No counterplay at the alcove itself.** It's the one refuge without
    one. He can't climb the pier and his inhale needs a clear line. A
    next round could add lamp-dousing by his wall hits (the card's) or
    a glow beacon like the gallery's.

## How it was proved

Every proof is a throwaway driver in `scratch/` (uncommitted), with real
stick and jump input, in the yard. `scratch/proofs.sh` runs them all in
both looks, and `scratch/proofs.log` holds the last run.

**He loses you in the mouse run** (`refuge_run.gd`):
- **The run:** he spots you in the open, then you run in and stand in the
  jog.
- **His beats:** spotted, pounce, scope, scope none, lost, gave up (at
  18.9 s), then roam.
- **His frames inside the wall:** 0.
- **The echo** (`--dawdle`): you pace in the run, he turns to the echo
  5 times, and he stands at the mouth you were near after 15.3 s (15.1 s
  in haze).

**He loses you in the gallery** (`refuge_gallery_chase.gd`):
- **The run:** he spots you in the forecourt and you run in by the slit.
- **His beats:** scope, scope none, lost, gave up (19.3 s).
- **His frames in the tier:** 0. That held in a bay and on the aisle,
  torch and haze.

**Snuffing the torch hides you where carrying it lit doesn't:**

Test 1 (`refuge_gallery.gd`): he stands still at his post, facing the
slit. You walk in by the east exit, wading the trough or not, and stand
on the aisle 24 m from his eye.

| Look | Torch | Exposure | Visibility | Spotted after |
|---|---|---|---|---|
| torch | lit | 0.95 | 0.68 | 1.05 s |
| torch | snuffed | 0.10 | 0 | never |
| haze | lit | 0.44 | 0.23 | 3.8 s |
| haze | snuffed | 0.10 | 0 | never |

Without the hall's `Shade`, the haze's 0.45 ambient would reach 26.8 m,
and a snuffed wanderer at 24 m would have been seen.

Test 2 (`refuge_gallery_chase.gd`): he's free to roam. He hunts you into
the gallery and you hide on the aisle for 60 s.

| Torch | What he did |
|---|---|
| Lit (trough jumped) | Drawn by the glow, spotted you at 31.9 s, sucked and gulped you twice |
| Snuffed (trough waded) | Never came back (torch and haze) |

**The slots let him reach but not follow** (`refuge_slot.gd`; he's set
8 m out from his face):

| You | What he did |
|---|---|
| On his ledge | Swat, then "caught swat": knocked off after 1.1 s, 1 catch |
| On the far leaf's lane, on the floor | 0 catches, then lost and gave up |
| Climbing straight through | Swatted at his ledge and missed. Up all six ledges and out of the window |

His frames inside the wall: 0 in every case (torch and haze).

**Climbability, with no body:**
- **Chimney:** six ledges and out of the window. You run at each ledge
  edge and jump, held. The ledges were first 0.59 deep, which gave no
  run-up for the 1.5 m jump, so they're 0.9 now.
- **Niches:** all seven shelves and into the alcove. Each hop is at half
  stick, catching the next shelf's end, and the stick held climbs it.
  - At a full run (4 m/s or more) the jump along the face becomes the
    motor's wallrun up the pier. That carries you up and past the next
    shelf, a move of its own.

**Smoke:** `tools/smoke.py` passed, all with 0 errors:
- `studies/city_refuges_yard.tscn`: plain, torch and haze.
- `studies/run_layer.tscn`: sprawl seed 1, and ring seed 2 with
  `--underground=haze`.
- `whole_body_chase`, `headless_body_isle` and `city_breaks_yard`.

**A body fix this round needed** (`headless_body.gd` `_beacon_gaze`, 4
lines):
- **The bug.** At a beacon whose `stand` is off the flame, the gaze
  turned `facing` to the flame. But stood in `listen`, the step
  controller's turn goal is `_heading`, which was the bearing to the stand
  point. That's behind him if he overshot it. So `look.steps.yaw` swung
  him back every frame, and he "looked" the wrong way for the whole dwell.
- **The fix.** The gaze now sets `_heading` too.
- **Where it shows.** Only at beacons. The round 1 beacon proofs stood
  under the flame (`stand` INF), where it didn't show.

## The stills

These are in `captures/shots/` (gitignored). I looked at each.

- `refuges_sheet2.png`:
  - **The mouse run, torch.** A tiny lit doorway at the foot of the
    colossal wall, its pale lintel the tell.
  - **The gallery, torch.** The slit behind him at his post.
  - **The hall inside, torch.** The trough, a pier and the stele; you
    with your torch in.
  - **The niches, torch.** A ladder of warm points up the dark pier.
  - **The yard wide, haze.**
  - **The slotted wall, haze.** The door and the stepped arm slot.
- `refuges_day_sheet.png`: the four pieces by day, close.
- `refuges_cue_hidden.png`: the "hidden" cue in a side bay of the hall
  (his camera, HUD on).
- `refuges_torch_sheet.png`: an earlier pass, kept for comparison. In it
  the hall reads lit and the steam reads as white balls; both are fixed in
  the newer stills.

**What I'd say about the look:**
- The stone is weathered basalt, and dust lies on the tops.
- The colossal coursing reads, though still a little regular (big
  staggered blocks, Hh courses).
- The mouse run and the lamp ladder are the strongest reads.
- The hall reads dark with the lampblack tone, but your own torch lights
  it close up.

## The model budget

The geometry is procedural, chamfered blocks in the Olmec's stone with
painted weathering in the shader. Each piece is one mesh and one draw.
Triangles: gallery 1.9k, mouse run 3.7k, slotted wall 2.9k, niches 2.0k,
plus 8 lamps of about 60 triangles. The yard's paving is about 17k.

| Trick | Applies? | Estimated saving |
|---|---|---|
| Vertex-colour grime | **Yes, used.** The foot occlusion, the lampblack interiors and dust on the tops are all in the vertex colour, at no texture cost. | Against a baked AO texture per piece: no extra texture fetch and about 1 MB of texture memory per piece. |
| Silhouette geometry | **Yes, used.** Chamfered blocks give real joints on the outline, while the faces' pits, cracks and streaks are the shader's. | Against modelled joints and chips: about 5 to 10x fewer triangles (an estimated 15 to 30k each down to 2 to 4k). |
| Import LODs, visibility ranges | **Should apply next.** A piece's interior (the run's legs, the hall, the chimney ledges) could be its own mesh with a visibility range of about 60 m. The lamps' lights already fade out at 45 to 60 m. | About 30 to 40% of a piece's triangles beyond 60 m (0.6 to 1.4k each). Frame time is negligible at this count; it matters with dozens of pieces in a layer. |
| Instancing (the cards' note) | **Should apply next.** The lamps are shared meshes and materials but separate nodes. A MultiMesh for all lamp bowls and flames would merge them. | Draws: 2 per lamp down to 2 per scene (8 lamps: 16 draws down to 2). |
| Sculpt high, bake low | Not yet. No sculpted model this round. The obvious candidate is a carved stele face or lintel glyphs, baked onto the box. | – |
| Parallax depth | Not worth it. The shader's pits and cracks already read at play distance. | – |
| Rigid parts on bones | Doesn't apply. Nothing is skinned. | – |

No frame times were measured (headless). One OmniLight3D sits on every
second lamp, with no shadows, which is the real cost the cards named.

## The limits

- **Free-roaming proofs are single seeds.** The Olmec's roaming is
  random. The gallery glow visit came at 31.9 s in one run.
- **The torch.** Only the gallery's trough snuffs it, and only its lamp
  relights it. There's no general "dip the torch", and wind and falls
  don't put it out.
  - Snuffing and relighting are the underground look's `torch` node
    hidden or shown.
  - In daylight (no look) the trough does nothing.
- **The echo and glow are beacons.** They draw only a calm Olmec, and as
  a flat range through walls (the beacons round's limit). While he hunts,
  he hunts by sight.
- **The shade is a box.** `Shade` subtracts the look's ambient down to
  the torch preset's, inside the hall's boxes. It isn't occlusion, and
  lamps still light through walls.
- **The slotted wall's reach is narrow.** It's only his side's first
  ledge. He stops 2.2 to 3.2 m off a wall, and from there his eye at 8.1 m
  looks steeply down, so the slot is an embrasure aimed at that ledge.
- **Not driven:** his climb over the slotted wall's top, and the inhale
  through its slot.
- **The camera.** In the 4.2 m hall and the chimney, the play camera
  crowds the wanderer (see the cue still).
- **No breaks.** That's city-breaks' machinery. The cards' breaks aren't
  built: the awning, the slot panel, lamps knocked out and the plug.
- **Not placed by the generator.** These are kit pieces with metadata
  only; no motif or generator placement yet.
- **`city_kit.gd` registration** is left to its owner (above).
- **Bays.** The gallery has one row of bay piers at this depth (`bays`
  1).

## Tests

No new tests; this is a prototyping round. The only change outside the
new files is `headless_body.gd` `_beacon_gaze` (4 lines, beacons only).
- **What touches it:** no test covers `headless_body.gd` beacons, and
  the `beacon` hits in `tests/` are the sky moments' hoops.
- **What I ran:** the smokes above. I didn't run the full suite.
- **What breaks:** as far as I know, no test.

## Open questions

- Make `sight_walker_only` = 1 the default? I recommend it.
- Is an echo that draws him round, when you move in the mouse run, the
  right pressure? Or should the run be a true safe room while you're
  inside?
- The torch glow drew him to suck you out of the gallery. Is that too
  punishing, or the right cost of keeping the flame?
- Should the alcove get a counterplay? Options: lamps doused by his wall
  hits, or a glow beacon like the gallery's.
- Is the slotted wall's one swattable ledge enough reach? Or do we want a
  second slot, which needs him to stop closer to walls?
