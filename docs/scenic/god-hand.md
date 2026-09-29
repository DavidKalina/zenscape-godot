# The God Hand

A hand of light that works the creation tools: a gentle Master Hand, "a lot less devious". It is built in Blender (`tools/blender_hand/`) and played in the game by `scripts/god_hand.gd`. It shows the work being done; the brushes, the water ball and the pollen land exactly where they would without it (`--no-hand`). The polish bar is Nintendo's (moving holds, anticipation, overlap, follow-through), and the handful rule still holds (`docs/scenic/handful.md`): the hand never changes where a handful lands.

## Build and review

- `blender -b --python tools/blender_hand/god_hand.py -- --no-render` builds the model and rig, bakes every clip and exports `assets/models/zenscape-god-hand.glb`. It takes a few seconds.
- `tools/blender_hand/god_hand_review.py`: `--check` (pops and hand-off gaps; every hand-off should be 0), `--clip=Name [--frames=..|--count=N] [--view=game|high|far|side|front]` (contact sheet), `--reel` and `--reel=idle` (mp4 in `/tmp/zs-hand-previews/review/`), `--heights=Clip,..` (each fingertip's lowest height).
- Headless probes: `tools/probe_god_hand.gd` (import facts), `tools/probe_god_hand_wiring.gd` (the game wiring against stand-ins), `tools/probe_pollen_hand.gd` (pollen in the palm) and `tools/probe_water_pop.gd` (the ball's toss and pop).

## Clips

Every clip is placed against the anchor, the ground point under the pointer. Each gesture is In, a looping Hold and Out, and all of them meet Idle's first pose, so the game chains them with no gap.

- **Idle** floats: a slow bob twice a round (6 s), the fingertips trailing it, and a lazy sway and bank. Its five variations start and end on Idle's first pose, and after a plain round one of them may follow (`VARIANT_CHANCE`), once the pointer has been near still for a second:
  - **IdleStretch**: the fingers curl in, then reach out long and fanned with the wrist bent back and the back of the hand turned to the camera, quiver, and shake out loose.
  - **IdlePeek**: it turns its palm up to the camera, tilts one way and the other, and wiggles its fingers.
  - **IdleRipple**: the fingers roll through a wave, little finger to thumb, twice.
  - **IdleGather**: the fingers close one by one into a soft fist, which trembles, then bloom open with the palm turned up like a flower.
  - **IdleDrift**: a lazy figure of eight, banking into each turn.
- **Pinch** (raise land, mountain forms). The hand rises, opens thumb and index wide and swoops down steeply to pinch the spot from above, the other three fingers tucked up clear of the ground. The hold pulls: two tugs a round, each squeezing, drawing the pinch up a touch and leaning the hand back round it with a quiver. On a mountain form the hand holds the summit (`NativeChunkEditor.hand_work_point`: the highest of the centre and a ring at 0.2 of the spread, so a volcano is held by its rim) and rides it up as it rises, however far the drag goes.
- **Press** (lower land). The hand rises, the fingers stretching long, and comes down palm first. It bears down with every finger extended and lifted a little off the ground, fanned, and the thumb out flat. The hold pushes twice a round, the heel rocking down and the fingers lifting further, while the palm works round a slow circle.
- **Cup** (the water ball). The hand turns over under the ball and works it: the palm circles under it, rolling it, the hand turns under it like a globe being turned, the fingers roll a wave round it and the thumb sweeps its side. On release the palm tosses the ball up, drops clear below it, comes round to its side thumb up, draws back and pokes it with the index finger: it pops. The hand recoils with its fingers flung open, shakes the wet off and floats home.
- **Sprinkle** (seed). Tossing a pinch of salt. The hand dips palm down and its fingertips take a pinch (thumb, index and middle gathered, ring and little finger tucked). Each toss draws back and up with the wrist cocked and the fingertips curled down, rolling the pinch once between thumb and fingers. It swings forward, the wrist flicks the fingertips up and out, and at the release the fingers spring apart and the pinch flies on. It follows through, then the fingertips gather a fresh pinch and it draws back again. There are two tosses a round (1.33 s each), one a little left and one a little right. Letting go tosses the last of it.
- **Turn** and **Catch** (turning the world, `docs/scenic/hand-turn.md`). The palm lies flat on the grabbed ground with the fingers spread wide, pads pressed and knuckles raised, and kneads its grip while the heel rocks. TurnIn lifts a touch with the fingers opening, then comes down palm first and the fingers flare on the touch; CatchIn is a quicker slap with the fingers bent back by the impact and the heel squashing in. Both Outs give a last shove, peel up heel first with the fingertips leaving last, flick the fingers open and sail up past the float. The game leans the gripping hand into the push about its palm (`TURN_LEAN`).

- **Void**, **Snap** (the sky, `docs/scenic/modeless.md` "Void slice"). Made, like Reach, for a camera level on the thumb side; the game turns them square to it. The anchor is the pointer's point on its ray, just under the fingers. VoidIn dips and swings up half upright, fingers up and leaning forward, the back of the hand turned a little to the camera so the thumb and middle finger show in profile. VoidHold (5 s) floats loosely curled with a slow bob, sway and drift, and twice a round the thumb drifts over and rubs the middle fingertip. VoidOut eases open and floats home. SnapIn (0.33 s, on the press) loads the snap: a small dip the other way, then the hand rises and cocks and the thumb pad finds the middle fingertip (solved against the rig) and squeezes past; SnapHold trembles with the pressure. SnapOut (1.1 s, on the release) gives one more squeeze with the wrist cocked, then in two frames the middle finger slams into the palm and the thumb flies on past the index as the wrist flicks forward and drops (`snap_hit_s`, frame 3); it holds the hit a beat, recoils up with the fingers flung loose (the finger springs, let go at the hit, give the overlap), shakes out and settles into VoidHold. All their hand-offs are exact (`--check`); review them with `--view=void`.

## Marks

Non-deforming bones carry what the game needs besides the hand. Their weights ride on the bones' scale.

- **Ball**, **BallTouch** (children of Root, not the hand): where the clip takes the water ball to be, and the point on it the hand touches. The game carries the hand so they sit on the real ball, pushed out along the touch by the difference in radius, so the palm stays under a ball of any size and the finger meets its skin. Ball's weight is how firmly the hand keeps to it: it ramps up as the palm forms and drops as the ball pops, and the hand then springs back to the pointer.
- **Handful** (child of Hand, at the gathered fingertips): the pinch of seed. While the hand is free, the handful gathers there (`SeedThrow.hand_at`). A drop of its weight in a Sprinkle clip throws it (`SeedThrow.toss`) at the throw's angle, aimed at the pointer, and from then on the physics decides where each seed lands (`docs/scenic/brushes.md` "Thrown seed"). While it sows, the hand stands `stand_off()` (2.2 m) back from the pointer along its reach, so it lobs onto the pointer. With `--pollen-veil` the motes instead fly on a spring to their places in the veil, and land where the veil would have put them.
- **Orb**, **Palm**, **Pinch** and **Pollen** mark the orb in the cupped palm, the pressing palm, where the tips meet and where a pinch of salt gathers.

## In the game

Over the clips the hand leans into the pointer's way and rocks back through upright when it stops, but only while it is free (idling or throwing). It tilts with the slope it works on, fully while it touches the land. No knuckle or palm goes into the land: the whole hand lifts clear, and only the pinching tips and a pressing palm may touch. Where it does meet the land it glows brighter and thins to nothing at the line where it goes in (`shaders/god_hand.gdshader`), so a touch reads as light on the ground rather than a hard cut. While it pinches or presses it rides the land's height exactly, rising with a pulled summit.

## 2026-09-28 refinement pass

After seeing the first version, the user asked for:

- "more idling animations ... bob and move": the float is bigger, the lean is new, and there are five idle variations.
- the water ball "manipulating the ball instead of just like an idle palm": the rolling, turning hold.
- on release, "instead of just going 180 degrees and flipping over and dropping the water ... pop the bubble in the air and then let it drop": the toss, poke and pop, with the ball popping on the same beat.
- pollen that feels "like it's throwing it, like sprinkling it ... ice melt ... tossing seeds. Instead of just ... dragging an open palm over the chunk": the underhand throws, with the pollen in the palm.
- the pinch clipping through the terrain, and "a pinching animation, like it is pulling the terrain": the steep pinch from above, the pulling hold, the summit hold, ground clearance and the soft contact.

Second round, the same day: the press fingers were "too relaxed", and the user wanted it "pressing palm first with all the fingers extended and kind of like pointing up a little bit". The pollen "looks like it's just opening and closing the hand over and over"; it should look like "it's holding something ... and then it's like tossing something". Both clips were redone as above.

Then asked for: seeds with "real physics and momentum", where "where they land is where they land". The user chose seeds landing as thrown (the veil went behind `--pollen-veil`), the hand throwing toward the pointer, and a soft preview of each throw. The throw clip now starts drawn back, so the first throw comes about a second after the press. The user then asked for the throw palm down, "like you got a pinch of salt and you're tossing it", in place of the palm-up handful.

The in-game look has not been checked on a GPU yet. The headless probes cover the wiring, the pollen and the pop.
