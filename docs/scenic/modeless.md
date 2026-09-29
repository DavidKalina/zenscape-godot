# Modeless controls

The control scheme agreed on 2026-09-28 (see "Verbs on the diorama" in `docs/scenic/hand-world.md`). Everything here is behind `--modeless`; without the flag the game behaves exactly as before. The idea is almost no UI and no tool modes. The hand is contextual and what it does depends on where you press. The only mode is the camera, on the right button.

| Press (left button) | Do | Result |
|---|---|---|
| Rim | push sideways | the world turns; a fast spin winds time |
| Rim | shake | snow-globe weather |
| Rim | drag up and over | flip (the flip slice) |
| Land | pull down or up, release | spring up mountains or sink a basin (the spring slice) |
| Right button anywhere | drag, scroll | camera: tilt, look round, zoom; never changes time |

Each slice adds its own section below. The shared flag and numbers are in `scripts/modeless_input.gd`.

## The agreed scheme (second pass, 2026-09-28)

This supersedes the table above, which is what the first slices built. Settled in a design session with the user; the build is in progress in the slices listed at the end.

**The rule.** The left button is the hand; the right button is the eye (camera: drag to tilt and look round, scroll or pinch to zoom). Where you press decides what the hand touches; the shape and timing of the drag decides the verb. There are no tool modes. Shift means "fine fingers" everywhere: the careful, smaller version of whatever you are doing. Everything should be found by playing, not taught: the hand's hover pose shows what a press will do, a hint line names it the first few times, and Cmd+Z is the safety net. Designed for a mouse; the user tests on a trackpad, so every verb must also work there.

**The edge (the lip and the block's walls, all the way down): whole-world verbs, big and dramatic.**

| Do | Result |
|---|---|
| Push sideways | the world turns; a fast spin winds time (days, then seasons) |
| Shift + push sideways | turns without winding time, however fast |
| Shake | the weather changes (snow globe) |
| Pull down, release | the whole block dips as a unit while you pull; on release a random range springs up. The pull sets height and jaggedness: a gentle pull gives rolling hills, a hard one tall jagged peaks. Placement, direction and peak count are random, leaning away from the rim and from what is already tall. Springs stack, up to a height ceiling that suits a 28 m plate. A quick starter to shape from, not a precise tool |
| Pull up, release slowly | the block lifts as a unit; on release a random basin sinks, sized by the pull (lakes and oceans later) |
| Pull up, release fast | a physics toss: the block tilts over its far edge by the flick's speed and either falls back and wobbles or goes over (the flip, a new world). Tilts add up while it is still up, so you can pump it over like a swing; one hard flick also does it |

Up is decided at release, not at the start: while you pull up the block's edge lifts and tilts after the hand, and the hand's upward speed when you let go makes it a toss or a basin.

**The land: local shaping, direct like clay (no springs).**

| Do | Result |
|---|---|
| Tap | poke: a creature or a tree reacts |
| Drag | the thumb: a slow, deliberate stroke digs a soft groove (future streams follow grooves), a fast back-and-forth rub smooths |
| Press, hold still a beat, then drag up or down | the hand visibly closes into a pinch; up raises, down sinks, following the hand directly, and it stays where you let go |
| Shift + drag | the palm: flattens and levels |
| Shift + pinch | a smaller, gentler raise or sink |

The charged land spring retires: springs belong to the edge. Props, trees and residents under a press keep their own grab.

**The void (sky, atmosphere, off the diorama).**

| Do | Result |
|---|---|
| Click | the hand snaps its fingers: instant day ↔ night (a cut, or a very fast blend; instant is preferred, it is the drama) |
| Shift + click | the snap steps dawn → noon → dusk → night |

**The hand is always there.** It is under the pointer wherever the pointer is, and its pose says what a press would do: over the land a ready pinch; on a wall its palm faces the wall; on the lip the rim grip; in the void it floats relaxed at a fixed depth along the pointer's ray, fingers loosely curled, ready to snap. It fades out while the right-button camera moves and comes back when it stops.

**Later.** Water: springs on high ground, streams in the thumb's grooves, ponds and lakes in basins, and its physics. The grooves and basins are shaped now so that water can follow them.

**Build slices.**
1. Edge rework (`feature/modeless-edge-spring`): the whole-block dip, the random multi-peak range, the basin, the physics toss with pumping, decided at release.
2. Land as clay (`feature/modeless-clay`): tap, thumb and pinch by timing, groove or smooth by speed, Shift palm, the land spring retired.
3. Void and the ever-present hand (`feature/modeless-void`): the snap, Shift-snap, the void pose, the fade under the camera, Shift-turn without time.
4. The wall palm (`feature/modeless-wall-hand`): a hand pose with the palm on the wall.

## Rim slice: the whole-world verbs, spin is time, right-drag is the camera

Branch `feature/modeless-rim`. Checked headless only (`tools/probe_modeless_rim.gd`); nothing has been seen or felt on screen.

### Try it

Run the product scene with `-- --modeless`.

- **Push the rim sideways.** The edge you hold follows the pointer and the world turns under the fixed room, as in `docs/scenic/hand-turn.md`. Let go with speed and it spins on, catches and bats exactly as before.
- **Flick it hard.** Past about 3 rad/s the light starts to shimmer, and past that time winds forward: the sun races, days flicker by, and with a very fast spin the seasons roll on and the weather changes. When the spin runs down, the world stays at the time it reached.
- **Shake the rim.** As before. When the shake is decided the turn lets go where it is and the snow globe has the rim.
- **Drag the rim up and over.** Emits the flip signals and does nothing else yet.
- **Left-press the land.** Nothing paints and nothing turns. The press is emitted for the spring slice.
- **Right-drag or scroll.** The camera. The drag tilts and looks round by pixels; it never winds time, and it does not turn the room (see below).
- **Hover.** Over the rim the hand takes the rim grip; over the land it readies a pinch.

The sun no longer grabs, the rim no longer turns the season, and the tool rail (the Lantern shell's brush bar) is hidden. Number keys and the Mood drawer are untouched.

### How it works

- **Zones and the press.** `scripts/hand_reach.gd` reads a left press in `_input`. A rim press is held by the hand; a land press (`_land(point)` hits terrain, no prop, tree or resident under the pointer) is taken and emitted; anything else falls through as before. `NativeChunkEditor.handle_input` ignores left presses under `--modeless`, and `studies/fidelity.gd` makes only the right button an orbit, so no brush and no scene orbit can start from a left press.
- **The rim's axis.** The first `AXIS_PIXELS` (12 px) of a rim drag decide it: if the vertical travel beats the sideways by `VERTICAL_BIAS` (1.2) it is the flip, otherwise the turn. The snow globe is fed every motion from the start, so a shake can be decided at any point and takes over from either. `hand_reach.rim_intent` is `""`, `"turn"`, `"flip"` or `"shake"`.
- **The turn.** `world_turn.gd` gets `hold_begin(press, rim_edge_global)`, `hold_move(pointer)` and `hold_end(flick)`. The rim's edge point is the grab point, so its existing bearing-hold, flick, bat and catch run unchanged (`on_land` is false, so its own "turn" hand stays away and the rim grip shows). A press on the rim or land during a spin catches it.
- **The room.** Under `--modeless` the room turns only by the turn's own yaw (a rim hold, a spin, a catch). A right drag looks round by pixels and leaves `room_yaw` alone. Reasoning: the user thinks of the camera as a separate mode, so looking round should be the camera moving round a world whose sun stays where it is, and turning the diorama should be the world moving in a fixed room. The two are different things to do and read differently.
- **Spin is time.** `scripts/spin_time.gd` reads `world_turn.own_rate`, the turn's own speed, signed and smoothed over 0.3 s (so a shake's back and forth cancels rather than winding the clock). Below `TIME_MIN` (3 rad/s) time is untouched. Above it the clock winds `6*excess^2` hours a second (excess is rad/s over the threshold): a hard flick winds about a day, the fastest spin about 19 days at a peak of 20 days a second. The clock's day and hour move, a held season (`season_override`) moves with the calendar and is shown at once, and living weather is handed the real time those hours would take (2 s per world hour, at most 40 s a frame) so the sky drifts because time passed, by its own dwell times. A pinned weather still holds it.
- **Pins.** A spin re-pins, it does not release. When the spin has run down, a held clock is pinned again at the new hour (`mood_look.pin_hour`, as letting go of the old sun drag did), and a pinned season is retargeted to the quarter the spin landed in (the pin only, the exact season value stays). A clock that was turning its own day keeps turning.
- **The cue.** `celestial.shimmer` (0..1) wobbles the key light's energy by up to 16 % at two incommensurate rates. It rises from `CUE_FROM` (1.8 rad/s) to `TIME_MIN` and eases to half once time is running. It costs one multiply.
- **Signals for the other slices**, all on `hand_reach`:
  - `flip_began(screen_pos)`, `flip_dragged(progress)` (0..1, up to `FLIP_REACH` = 0.45 screen heights of upward drag), `flip_released(progress)`. If a shake takes over a flip, the flip is ended with `flip_released(0.0)`.
  - `land_pressed(screen_pos)`, `land_dragged(screen_pos, relative)`, `land_released(screen_pos)`. `hand_reach.holding` is `"land"` between them. The hand is not driven while the land is held, so the spring slice can set `god_hand.reach_gesture`.
- **The walls are rim.** The block's earth sides are rim all the way down to the foot: a pointer on a wall reaches the point it is over (`_wall_hit`, outer faces only, unless a hill stands nearer along the ray), not the lip above it. That point is the turn's grab, so the wall stays under the pointer as the world turns; the hand shows there stood `WALL_OUT` (0.5 m) out from the wall, clear of the faceted sides, which bulge about 0.45 m past the plate. Before this, a wall press took the lip: the hand sat on it, hidden inside the bulge and often off screen in a low view, and the grab drifted about 150 px from the pointer (`tools/probe_wall_grab.gd`).
- **Hover.** `_drive_hand_modeless` sets `reach_gesture` to `"rim"` or `"pinch"` (with the point) only when the hand is free or already showing one of its own hover poses, and clears it after.

### Limits and open points

- **The water ball** is a brush, so it is not reachable under `--modeless`: left presses on land no longer reach the editor. It needs its own door (a zone or a gesture) when the spring slice defines the land's verbs.
- **A shake swings the world for its first strokes**: until the shake is decided (a stroke or two) the rim grab follows the pointer, so the world turns back and forth a little, and it stays wherever it was when the shake took over. It does not wind time.
- **Reach depends on where you grab.** The turn's speed is the pointer's speed over the grab's distance from the pivot, so the same flick winds more time near the pivot's side of the rim than far from it. `TIME_MIN` and `HOURS_GAIN` in `scripts/spin_time.gd` are the knobs, and the headless probe cannot say how they feel.
- Props, trees and residents under a left press keep their own grab (they are checked with `pick_object`, once per press).
- The hover key in `hand_reach` only changes with the pointer and camera, so while the world spins under a still pointer the hover pose can lag until the pointer moves.
- **Unverified on screen:** the shimmer, the hand's rim and pinch poses, how the sky, leaves and weather look while time races, whether 3 rad/s and the 12 px axis decision feel right, and the hidden tool rail's layout.

### Probe

`tools/probe_modeless_rim.gd` (run with `-- --modeless`, `--fixed-fps 60`). It proves, in the real product scene with synthesized input:

- the sun does not grab; over the rim the hand takes "rim", over the land "pinch", over nothing it lets go;
- a sideways rim push decides "turn", turns the world and the room, and shows the rim grip;
- a slow turn leaves the clock and the shimmer alone and does not spin on;
- two fast flicks wind the clock exactly as much as the spin's hours a second integrate to, the faster flick winds more, a held season rolls with the calendar, the shimmer rises, the world keeps its time at rest and the hour is pinned;
- forty extra days through the spin's path change the weather;
- a vertical drag decides "flip", emits the three flip signals and does not turn the world or touch time;
- a shake decided from a sideways or a vertical start becomes "shake", the turn lets go, the flip is ended with 0, the hand shakes, and time is not wound;
- a left land press emits `land_pressed`, `land_dragged`, `land_released`, does not turn and starts no brush stroke; with land as clay the drag is the thumb (one undo step, undone after), and the land spring stays idle;
- a fast right drag tilts and looks round without changing time, the room or the spin.

`tools/probe_wall_grab.gd` (same flags) takes a low, close camera facing a wall and proves the wall's middle is rim, reaches the point under the pointer, shows the rim grip stood out from the wall, turns the world with the grabbed point within a few pixels of the pointer, and decides the flip from an upward drag.

## Land as clay: tap, thumb, pinch and palm

Branch `feature/modeless-clay`. Checked headless only (`tools/probe_land_clay.gd`); nothing has been seen or felt on screen.

### Try it

Run the product scene with `-- --modeless` and left-press the land (not a prop, a tree or a resident: they keep their own grab).

- **Tap it.** A small dimple rings out at the spot and the land comes back exactly. A resident within 8 m looks round at it. No undo step.
- **Drag slowly.** The thumb digs a soft groove along the path: about 0.3 m deep and 2.4 m across, with a level, rounded floor and a faint lip either side. Going over the same line again digs deeper; lingering does not.
- **Rub fast, back and forth.** The land under the rub smooths out. Between slow and fast the stroke does some of each.
- **Hold still for a beat, then drag up or down.** The hand closes into a pinch. Up raises the spot and down sinks it; the summit keeps to the pointer, and the land stays where you let go. A hold let go without moving changes nothing.
- **Shift + drag.** The palm: levels the land toward the height under the press.
- **Shift + hold.** A smaller, gentler pinch.
- **Cmd+Z** takes back one stroke or one pinch at a time.

The charged land spring no longer answers the land (see `docs/scenic/modeless-spring.md`).

### How it works

- **Where.** `scripts/land_clay.gd`, created by `studies/fidelity.gd` under `--modeless` and connected to `hand_reach`'s `land_pressed`, `land_dragged` and `land_released` in place of the land spring. `NativeChunkEditor.clay` points at it, and an undo closes whatever it has in hand first (`finish_now`).
- **Deciding.** A press is undecided until the pointer has gone `MOVE_PIXELS` (6 px) from it, which makes it a drag, or it has been held `HOLD_SECONDS` (0.3 s, counted in frame time) without that, which makes it a pinch. A release before either is a tap. Shift is read when the verb is decided, so it can go down after the button.
- **The thumb's speed.** The pointer's path length in pixels over the last `SPEED_WINDOW` (0.25 s), so a rub's turns do not read as slow. The rub share is `smoothstep(GROOVE_SPEED, RUB_SPEED, speed)`: 500 px/s and under only digs, 1200 px/s and over only smooths, between it blends. Dabs are laid `DAB_SPACING` (0.3 m) apart along the path, at most 64 a frame.
- **The groove.** Each dab pulls the points within `GROOVE_HALF_WIDTH` (1.2 m) `GROOVE_STEP` (half) of the way toward a shape: a level bed `GROOVE_DEPTH` (0.3 m) under the ground on the stroke's line, full depth inside `GROOVE_FLOOR` (35 %) of the half-width and easing to the untouched ground on a smoothstep. It never digs below that shape, so the groove is even and unbroken whatever the pace. Its bed follows the ground along the line, so it runs downhill where the land does. Points just outside that the groove has not dug rise by up to `GROOVE_LIP` (5 cm) out to 1.6 half-widths. The land's points are about 0.6 m apart, which is why the groove is this wide: the nearest row always reaches the bed.
- **The rub.** Each dab moves the points within `RUB_RADIUS` (1.6 m) `RUB_STEP` (0.45) of the way to the mean of their neighbours, easing out over the outer half.
- **The palm.** Each dab moves the points within `PALM_RADIUS` (2 m) `PALM_STEP` (half) of the way to the height under the press, easing out over the outer 45 %.
- **The pinch.** The pointer's travel up the screen is turned into metres at the scale of a metre standing at the spot (never less than 0.3 of a metre across the ground, so a camera looking straight down still pinches), so the summit follows the pointer. The shape is `(1-t²)²` over a radius of 2.2 m plus 0.45 m per metre of lift, at most 5.6 m; the lift is between -4 and +8 m, and sinking never takes ground below -1.2 m. The Shift pinch takes 0.4 of the travel over 1.2 m plus 0.3 m per metre (at most 2.6 m), between -1 and +2 m. The shape is written from the heights at the hold, so it follows the hand both ways with no spring.
- **The poke.** A dimple 0.1 m deep over 1.2 m, `-depth·e^(-7t)·cos(26t)` over half a second, then the exact heights come back (only where nothing else moved them).
- **One undo step each.** `data.begin_stroke()` opens when the verb is decided and `end_stroke()` closes at release, so an unmoved pinch adds none. Release runs the editor's settle refresh and tells emergence about the stroke's ground as a land stroke would. Nothing weathers after: clay stays as it was left.
- **Frame cost.** Only the points near a dab are written (a bucket lookup, 1.5 m cells), and the land is shown through the editor's light refresh, one at a time, as the brushes and the land spring do.
- **The hand.** The hover's ready pinch stays while the press is undecided. The pinch plays its `PinchIn` again when it is decided, so the hand visibly closes. The thumb, the palm and the poke use `press` (the thumb's Hold plays faster as the stroke turns into a rub). On release the hand is let go and the hover takes it back.

### Limits and open points

- **No thumb or poke clips.** The thumb, the palm and the poke all show the Press pose. A thumb stroke and a fingertip poke want their own clips.
- **The pinch follows the hand very directly.** From the default view a metre is about 15 px, so 60 px of drag raises about 4 m. This is what "follows the hand" means, but it may feel too touchy from far out. `PINCH.scale` is the knob.
- **The groove bed follows the ground**, so across a hump it rises and falls with it. Water may want the bed kept falling along the stroke; that belongs to the water slice.
- **A drag off the land** skips the points off it and joins up again where the pointer comes back.
- **Creatures.** Only the resident notices a poke. Other life (birds, deer, frogs) does not react yet.
- **Unverified on screen:** how the groove, the rub, the palm and the pinch look and feel; whether 0.3 s and 6 px classify well on a trackpad; whether 500 and 1200 px/s split a stroke from a rub for a real hand; the Press pose standing in for the thumb.

### Probe

`tools/probe_land_clay.gd` (run with `-- --modeless`, `--fixed-fps 60`) drives the real product scene with synthesized mouse input through `hand_reach`, on a bare spot it finds. It proves: a quick release is a tap that dimples the spot, the hand pokes, the ground comes back bit-exact and no undo step is added; a 4 px nudge let go at 0.17 s is still a tap; a press is undecided before 0.3 s and a pinch after, with `PinchIn` playing, and a pinch let go unmoved keeps nothing; a 6 px move decides the thumb by the second frame; a 300 px/s drag is a groove (rub share 0) dug 0.27 to 0.31 m deep all along its path, with banks raised at most a few centimetres; an 1800 px/s back-and-forth is a rub (share 1) that takes the probe's roughened ground from about 0.09 to 0.0001 mean neighbour difference without digging; Shift-drag is the palm and levels the ground to the press's height; hold and drag up 60 px raises the spot about 4 m with the summit within a pixel of the pointer, and it stays after release; down sinks it; a Shift pinch raises about a third as much over a sixth of the points; each verb is one undo step and one undo restores the heights exactly; the land spring never starts or springs. CPU frame gaps (dummy renderer) while dragging: groove max 7 ms, rub under 6 ms, pinch under 5 ms.

`tools/probe_land_spring.gd` now drives the spring directly and checks the land signals leave it idle; `tools/probe_modeless_rim.gd` checks a land drag is the thumb and the spring stays idle.

