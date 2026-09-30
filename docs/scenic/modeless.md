# Modeless controls

The control scheme agreed on 2026-09-28 (see "Verbs on the diorama" in `docs/scenic/hand-world.md`). Since 2026-09-29 this is the default; `--classic-controls` brings back the tool modes. (Before that it was behind `--modeless`, which the slices' "Try it" notes and the probes still pass; the flag is now harmless.) The idea is almost no UI and no tool modes. The hand is contextual and what it does depends on where you press. The only mode is the camera, on the right button.

| Press (left button) | Do | Result |
|---|---|---|
| Rim | push sideways | the world turns; a fast spin winds time |
| Rim | shake | snow-globe weather |
| Rim | drag up and over | flip (the flip slice) |
| Rim (lip or wall) | pull down or up, release | your shapes amplified (a random range on a blank plate), a basin, a toss or the flip ("Edge rework" below) |
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
| Pull down, release | the whole block dips as a unit while you pull; on release your own sculpt springs up bigger: the peaks you pinched grow taller and more jagged, grooves and basins get deeper. The pull sets how much. It adds energy to what you made; it adds no new mountains. On a blank or nearly flat plate a random range springs up instead, as a starter: its placement, direction and peak count are random, leaning away from the rim and from what is already tall, and the pull sets its height and jaggedness. Either way springs stack, under a height ceiling that suits a 28 m plate. While you pull, the pointer is held (the hand on the rim stands in for it) and the travel is counted, so a rim near the bottom of the screen still has the whole pull, and the camera leans down and in with the block. **Pull on past the cap** (the deep pull, up to another 0.9 screen heights) and the block and the camera keep sinking; on release the whole plate also fills with height, a plateau up to 5.5 m, green on top with rocky sides falling to the rim, for the thumb to carve valleys and ravines into |
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
| Swipe (let go within 0.3 s) | a passing gust across the land along the swipe; the weather is left alone ("Wind" below) |
| Drag onto the land | the wind tool in hand where the drag meets the ground: its lane is promised, swipe on and let go to send it, hold still to burst ("Wind" below) |
| Press, drag and hold | the prevailing wind turns the way you pull from the press, harder the further you pull; it stays when you let go ("Wind" below) |

**The hand is always there.** It is under the pointer wherever the pointer is, and its pose says what a press would do: over the land a ready pinch; on a wall its palm faces the wall; on the lip the rim grip; in the void it floats relaxed at a fixed depth along the pointer's ray, fingers loosely curled, ready to snap. It fades out while the right-button camera moves and comes back when it stops.

**Water** (`feature/water-flow`, `docs/scenic/water-flow.md`). A tuft pulled off the sky's cloud and carried over the land becomes a water ball (`docs/scenic/sky-cloud.md`), and letting go drops it. On high or steep ground it becomes a spring. Its water runs in a live simulation: streams in the thumb's grooves, ponds in the palm's basins, spilling over rims, and following every change to the land. `--planned-water` keeps the one-shot plan.

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
- **Flick it hard.** Past about 2.2 rad/s (a brisk flick) the light starts to shimmer, and past that time winds forward: the sun races, days flicker by, and with a very fast spin the seasons roll on and the weather changes. When the spin runs down, the world stays at the time it reached.
- **Shake the rim.** As before. When the shake is decided the turn lets go where it is and the snow globe has the rim.
- **Drag the rim up and over.** Emits the flip signals and does nothing else yet.
- **Left-press the land.** Nothing paints and nothing turns. The press is emitted for the spring slice.
- **Right-drag or scroll.** The camera. The drag tilts and looks round by pixels; it never winds time, and it does not turn the room (see below).
- **Hover.** Over the rim the hand takes the rim grip; over the land it readies a pinch.

The sun no longer grabs, the rim no longer turns the season, and the tool rail (the Lantern shell's brush bar) is hidden. Number keys and the Mood drawer are untouched.

### How it works

- **Zones and the press.** `scripts/hand_reach.gd` reads a left press in `_input`. A rim press is held by the hand; a land press (`_land(point)` hits terrain, no prop, tree or resident under the pointer) is taken and emitted; anything else falls through as before. `NativeChunkEditor.handle_input` ignores left presses under `--modeless`, and `studies/fidelity.gd` makes only the right button an orbit, so no brush and no scene orbit can start from a left press.
- **The rim's axis.** The first `AXIS_PIXELS` (12 px) of a rim drag decide it: if the vertical travel beats the sideways by `VERTICAL_BIAS` (1.2) it is the lift (`"flip"`) when it goes up and the edge spring when it goes down (see "Edge rework" below), otherwise the turn. The snow globe is fed every motion from the start, so a shake can be decided at any point and takes over from either. `hand_reach.rim_intent` is `""`, `"turn"`, `"flip"`, `"spring"` or `"shake"`.
- **The turn.** `world_turn.gd` gets `hold_begin(press, rim_edge_global)`, `hold_move(pointer)` and `hold_end(flick)`. The rim's edge point is the grab point, so its existing bearing-hold, flick, bat and catch run unchanged (`on_land` is false, so its own "turn" hand stays away and the rim grip shows). A press on the rim or land during a spin catches it.
- **The room.** Under `--modeless` the room turns only by the turn's own yaw (a rim hold, a spin, a catch). A right drag looks round by pixels and leaves `room_yaw` alone. Reasoning: the user thinks of the camera as a separate mode, so looking round should be the camera moving round a world whose sun stays where it is, and turning the diorama should be the world moving in a fixed room. The two are different things to do and read differently.
- **Spin is time.** `scripts/spin_time.gd` reads `world_turn.own_rate`, the turn's own speed, signed and smoothed over 0.3 s (so a shake's back and forth cancels rather than winding the clock), or once let go the spin itself (`world_turn.spin`) when that is faster, since the smoothing trails a flick's spin and ate its peak. Below `TIME_MIN` (2.2 rad/s, 3 until 2026-09-29) time is untouched. Above it the spin winds `5*excess^2` hours a second (excess is rad/s over the threshold): a brisk trackpad flick on the near rim (150 to 300 px in 0.15 to 0.2 s, let go at 3.8 to 4.7 rad/s) winds 6 to 22 hours, a hard one about two days, the fastest spin about 16 to 19 days at a peak of 20 days a second. That is what is wound, not how fast it is shown.
- **The world glides to the wound time.** The spin winds a target; what the world has not shown yet is `ahead`, and the world travels to it over seconds, carrying on after the spin stops winding, so nothing strobes:
  - The sun travels the hours at up to `SKY_HOURS_MAX` (6 world hours a real second, a whole day and night in four seconds). It gathers speed at `SKY_ACCEL` (8 h/s², full speed in about 0.75 s) and settles at `SKY_RESPONSE` (1.5: its speed is at most 1.5 times the hours left, per second), landing when under `ARRIVE` (0.02 h) is left. A flick sweeps the sun across the sky and eases it to rest.
  - Whole days are rolled through, not shown as days and nights. While more than `SKIP_ABOVE` (30) hours are ahead, a day is taken off: the calendar day moves and the season rolls through it at `DAY_RESPONSE` (0.6) times the days ahead, held between `SKIP_MIN_DAYS` (1.5) and `SKIP_MAX_DAYS` (4) days a second, with the sun where it is. A three-week spin passes through a day or two of sky and rolls the year over about five seconds (a season, a quarter of the 28-day year, in about two). Headless, the fastest spin's 16 days arrive about 8.5 s after it stops winding; a one-day flick about 4 s; a 1.3 h nudge about 2 s.
  - The season on screen moves continuously. A held season (`season_override`) moves with the travelled hours and rolled days; with the calendar's own season `_season_shown` trails the calendar through the day being rolled, so the plants' `zs_season` never steps a day at a time.
  - Weather crossfades. Living weather is handed the real time the travelled hours would take (`WEATHER_SECONDS_PER_HOUR` 2 s per world hour, at most `WEATHER_MAX` 40 s a frame), so the sky changes because time passed, by its own dwell times. Each change eases in over real seconds as always (living weather's `RESPONSE` 0.08, about 37 s to 95 %): the extra weather time is passed with `blend_seconds` 0 (`living_weather.advance`), so it moves the schedule but does not hurry the fog and cloud-peak ease. Before this the handed-over seconds pushed the fog bank most of the way to each new sky in one frame. A pinned weather still holds it.
  - Anything else that moves the clock during a glide wins: the void's snap (`scripts/void_snap.gd`, still an instant cut), a mood fade or N's skip. Spin time notices the clock moved by more than its own running (`OUTSIDE` 0.01 h) and drops the rest of the glide (`drop_glide`), so the snap's hour stays.
- **Pins.** A spin re-pins, it does not release. When the spin has run down and the world has arrived at the wound time, a held clock is pinned again at the new hour (`mood_look.pin_hour`, as letting go of the old sun drag did), and a pinned season is retargeted to the quarter the spin landed in (the pin only, the exact season value stays). A clock that was turning its own day keeps turning.
- **The cue.** `celestial.shimmer` (0..1) wobbles the key light's energy by up to 16 % at two incommensurate rates. It rises from `CUE_FROM` (1.3 rad/s) to `TIME_MIN` and eases to half once time is running. It costs one multiply.
- **Signals for the other slices**, all on `hand_reach`:
  - `flip_began(screen_pos)`, `flip_dragged(progress)` (0..1, up to `FLIP_REACH` = 0.45 screen heights of upward drag), `flip_released(progress)`. If a shake takes over a flip, the flip is ended with `flip_released(0.0)`.
  - `land_pressed(screen_pos)`, `land_dragged(screen_pos, relative)`, `land_released(screen_pos)`. `hand_reach.holding` is `"land"` between them. The hand is not driven while the land is held, so the spring slice can set `god_hand.reach_gesture`.
- **The walls are rim.** The block's earth sides are rim all the way down to the foot: a pointer on a wall reaches the point it is over (`_wall_hit`, outer faces only, unless a hill stands nearer along the ray), not the lip above it. That point is the turn's grab, so the wall stays under the pointer as the world turns. Before this, a wall press took the lip: the hand sat on it, hidden inside the bulge and often off screen in a low view, and the grab drifted about 150 px from the pointer (`tools/probe_wall_grab.gd`).
- **The palm on the wall.** On a wall the hand lays its palm flat against it (`"wall"`, the Wall clips in `docs/scenic/god-hand.md`), fingers spread up the wall, ready to push it sideways, pull it down or lift it. The lip keeps the Rim grip. `reach_facing` is the wall's inward normal, so the palm faces into the wall whichever side the camera is on. The faceted earth sides bulge 0 to 0.45 m past the plate (about 0.2 m typically), so the hand does not stand a fixed distance out: `_wall_face` reads the facets round the palm (rays into them over the palm and fingers, `WALL_SPAN` either side, `WALL_BELOW` under to `WALL_ABOVE` over the point, and their corners there) and the hand point stands `WALL_GAP` (4 cm) past the outermost of them. The palm then lies on the earth, not in it or floating off it; `WALL_OUT` (0.5 m) is only the fallback where the sides cannot be read. It costs about 0.15 ms a call, once per hover change or drag motion. `_hand_at` gives the hand point, and `_wall_facing` tells a wall point (outside the plate) from the lip.
- **Hover.** `_drive_hand_modeless` sets `reach_gesture` to `"rim"`, `"wall"` or `"pinch"` (with the point, and for the wall its facing) only when the hand is free or already showing one of its own hover poses, and clears all three after. A rim hold keeps the same pose (wall or lip) while it is undecided or turning; the flip and a decided shake take the hand over as before. The hover is read before the hand is driven each frame, so the pose never trails the pointer by a frame.

### Limits and open points

- **The water ball** is a brush, so left presses on land do not reach it under `--modeless`. Its door is the sky: a void press dragged onto the land (`docs/scenic/water-flow.md`).
- **A shake swings the world for its first strokes**: until the shake is decided (a stroke or two) the rim grab follows the pointer, so the world turns back and forth a little, and it stays wherever it was when the shake took over. It does not wind time.
- **Reach depends on where you grab.** The turn's speed is the pointer's speed over the grab's distance from the pivot, so the same flick winds more time near the pivot's side of the rim than far from it. `TIME_MIN` and `HOURS_GAIN` in `scripts/spin_time.gd` are the knobs, and the headless probe cannot say how they feel.
- Props, trees and residents under a left press keep their own grab (they are checked with `pick_object`, once per press).
- The hover key in `hand_reach` only changes with the pointer and camera, so while the world spins under a still pointer the hover pose can lag until the pointer moves.
- **Unverified on screen:** the shimmer, the hand's rim, wall and pinch poses (the Wall clips have been looked at only in Blender review renders), how the sky, leaves and weather look while time races (whether the glide rates read as a smooth sweep or feel sluggish), whether 2.2 rad/s and the 12 px axis decision feel right, and the hidden tool rail's layout.

### Probe

`tools/probe_modeless_rim.gd` (run with `-- --modeless`, `--fixed-fps 60`). It proves, in the real product scene with synthesized input:

- the sun does not grab; over the rim's wall (half a metre under the lip) the hand takes "wall", over the land "pinch", over nothing it lets go;
- a sideways rim push decides "turn", turns the world and the room, and keeps the palm on the wall;
- a slow turn leaves the clock and the shimmer alone and does not spin on;
- two fast flicks wind the clock exactly as much as the spin's hours a second integrate to, shown over time (the world glides on after the spin stops winding), the faster flick winds more, a held season rolls with the calendar, the shimmer rises, the world keeps its time at rest and the hour is pinned;
- sixteen days wound through the spin's path take seconds to show and change the weather;
- a snap during a glide drops the glide and the world stays at the snap's hour;
- a vertical drag decides "flip", emits the three flip signals and does not turn the world or touch time;
- a shake decided from a sideways or a vertical start becomes "shake", the turn lets go, no flip is left running (a downward start is now the edge spring, which the shake lets go of with nothing kept), the hand shakes, and time is not wound;
- a left land press emits `land_pressed`, `land_dragged`, `land_released`, does not turn and starts no brush stroke; with land as clay the drag is the thumb (one undo step, undone after), and the land spring stays idle;
- a fast right drag tilts and looks round without changing time, the room or the spin.

`tools/probe_wall_grab.gd` (same flags) takes a low, close camera facing a wall and proves the wall's middle is rim, reaches the point under the pointer, lays the palm on the wall on hover (`"wall"`, facing into it, the hand point on the earth side's face), keeps the rim grip on the lip, has the Wall clips in the model and plays WallIn into WallHold while held, keeps the palm on the earth rather than in it, clears the facing on letting go, keeps the palm on the wall while it turns, turns the world with the grabbed point within a few pixels of the pointer, and decides the flip from an upward drag.

## Land as clay: tap, thumb, pinch and palm

Branch `feature/modeless-clay`. Checked headless only (`tools/probe_land_clay.gd`); nothing has been seen or felt on screen.

### Try it

Run the product scene with `-- --modeless` and left-press the land (not a prop, a tree or a resident: they keep their own grab).

- **Tap it.** A small dimple rings out at the spot and the land comes back exactly. A resident within 8 m looks round at it. No undo step.
- **Drag slowly.** The thumb digs a channel along the path: about 1 m deep and 2.5 m across, with a level, rounded floor and a soft lip either side. Drawn downhill, its floor keeps falling across the ground's bumps, so water can run along it. The dug faces turn to bare earth, as if the grass had caved in, and stay that way. Going over the same line again digs deeper; lingering does not.
- **Rub fast, back and forth.** The land under the rub smooths out. Between slow and fast the stroke does some of each.
- **Hold still for a beat, then drag up or down.** The hand closes into a pinch. Up raises the spot and down sinks it; the summit keeps to the pointer, and the land stays where you let go. A hold let go without moving changes nothing.
- **Shift + drag.** The palm: levels the land toward a little under the height under the press, a level-floored pan a pond can fill. Pressing again deepens it. Pressed-down ground turns to bare earth too.
- **Shift + hold.** A smaller, gentler pinch.
- **Cmd+Z** takes back one stroke or one pinch at a time.

The charged land spring no longer answers the land (see `docs/scenic/modeless-spring.md`).

### How it works

- **Where.** `scripts/land_clay.gd`, created by `studies/fidelity.gd` under `--modeless` and connected to `hand_reach`'s `land_pressed`, `land_dragged` and `land_released` in place of the land spring. `NativeChunkEditor.clay` points at it, and an undo closes whatever it has in hand first (`finish_now`).
- **Deciding.** A press is undecided until the pointer has gone `MOVE_PIXELS` (6 px) from it, which makes it a drag, or it has been held `HOLD_SECONDS` (0.3 s, counted in frame time) without that, which makes it a pinch. A release before either is a tap. Shift is read when the verb is decided, so it can go down after the button.
- **The thumb's speed.** The pointer's path length in pixels over the last `SPEED_WINDOW` (0.25 s), so a rub's turns do not read as slow. The rub share is `smoothstep(GROOVE_SPEED, RUB_SPEED, speed)`: 500 px/s and under only digs, 1200 px/s and over only smooths, between it blends. Dabs are laid `DAB_SPACING` (0.3 m) apart along the path, at most 64 a frame. A thumb's first `SPEED_WINDOW` of path is held and laid down together once its speed is read: with a 1 m groove, a rub's first frame (read at about 900 px/s, the still press frame still in the window) otherwise dug a trench 9 cm deep on average under it.
- **Where the stroke runs.** The pointer is picked on the ground as it stood when the stroke began (`_pick_base`). Picked on the live ground, a groove deepening ahead of the pointer drew the line onto its far wall under an oblique camera, and a straight stroke came out about 4 m wide on the side away from the camera.
- **The groove.** Each dab pulls the points within `GROOVE_HALF_WIDTH` (1.35 m) `GROOVE_STEP` (half) of the way toward a shape: each point sinks by the line's depth (`GROOVE_DEPTH`, 0.75 m, from 1 m) from where it stood, so across a slope the cut follows the ground (a level bed across cut 1.5–2.5 m into a flank's uphill bank and read as a trench), full depth inside `GROOVE_FLOOR` (35 %, about 0.47 m either side) of the half-width and easing to the untouched ground on a smoothstep, so the floor and the walls are rounded. It never digs below that shape, so the groove is even and unbroken whatever the pace. Points just outside that the groove has not dug rise by up to `GROOVE_LIP` (12 cm; 22 cm read as a rampart) out to `LIP_OUT` (1.6) half-widths. The land's points are 0.45 to 0.75 m apart (2,025 points, mean edge 0.75 m, mean nearest neighbour 0.47 m), so about 3.7 points a metre stand on the full-depth floor. A second pass digs another metre, down to the land's floor of -1.5 m.
- **Why 1 m.** The first groove was 0.3 m deep and 2.4 m across. Measured headless (a throwaway probe driving a 300 px/s stroke), it was dug and kept: 0.24 to 0.29 m mid-drag, 0.26 to 0.29 m at release, the same after the settle refresh and 3 s later, the shown mesh matching the data, and a second pass going on to 0.53 m. Nothing smoothed or undid it and the light refresh showed it. It did not read because from the default camera, 58 m out, its floor sat 3.8 px under the old ground, the same green on both sides. At 1 m the floor sits 13 to 18 px down, and the earth colour marks it.
- **Why it still did not read (2026-09-29 playtest).** A slow stroke across the plain after an edge-pull range and a pinch left no mark from the overview. Measured headless on the same session (tools-style probe driving real input): the groove was dug everywhere it ran, 1.0 to 1.1 m deep and 2.5 to 3 m across on the flat, 1.3 to 2.5 m on slopes (the bed never climbs). But where it crossed ground the range had painted granite (weight 0.8), `coat` only mixed in the weight it added (0.2), so the bed came out #afa79c and #90887f, the grey of the rock round it. And with the pinch raised beside the plain's tree, the tree stood near the summit where the stroke was pressed, and in the reproduction no groove was dug at all (0 dabs; most likely the press went to the tree, whose grab comes first). Now the earth covers what was painted by its own weight (`_earth`), the bed darkens to #5f412e, the lip is outlined, and the tree is shaken off the peak.
- **The bed never climbs.** The bed is the ground on the line less the depth, but never higher than the bed of the dab before it, cutting at most `GROOVE_CUT` (0.2 m) deeper than the depth to hold it. A downhill stroke is then a channel that keeps falling across the ground's bumps: across a 10 cm hump the probe's floor held level and fell on, its worst climb along the fall 1.2 cm (the rounding between floor points). An uphill stroke comes out level, then rising once the ground has climbed past the cut, so it drains back to its start. Water (a later slice) runs down these.
- **The rub.** Each dab moves the points within `RUB_RADIUS` (1.6 m) `RUB_STEP` (0.45) of the way to the mean of their neighbours, easing out over the outer half.
- **The palm.** Each dab moves the points within `PALM_RADIUS` (2 m) `PALM_STEP` (half) of the way to the height under the press less `PALM_SINK` (0.4 m), both easing out over the outer 45 %. Levelling alone only makes a pan where the ground round it is higher; pressing a little under the press height makes a basin a pond can form in anywhere. Each stroke presses from the ground as it now stands, so pressing again deepens it. In the probe a short press (24 frames) left a pan 0.24 to 0.3 m deep and about 4.5 m across.
- **Dirt.** Where the thumb (its groove share) or the palm takes the ground down, bare earth shows. After each frame's dabs, every tint cell (0.5 m) under them is measured at its middle: the depth it now stands under the ground at the stroke's start. The tint layer's weight rises from nothing at `DIRT_FROM` (4 cm dug) to full at `DIRT_FULL` (0.45 m), and its colour runs from `DIRT` (#8f7c62, a muted earth) toward `DIRT_DEEP` (#6e5b47, damp earth) by `GROOVE_DEPTH`, so the floor reads as a line without a saturated brown gash (#946c47 to #5f412e did). So the floor and walls are full earth and the upper walls fade. Where a groove's lip has risen `LIP_TURNED` (3 cm) or more, the pushed-aside clay shows as a pale fringe (`TURNED`, #a39a78, at up to `TURNED_WEIGHT`, 0.2) that keeps its grass, so both banks are outlined. It is written from the stroke's starting tint (`_earth`): the earth covers whatever was painted there by its own weight, not only by the weight it adds as `NativeTerrainTint.coat` does, because dug ground is earth whatever colour its surface was (a range's granite foot, a pinch's flank); the cell's weight never drops. So it lands the same whatever the pace and only ever deepens. At release, a cell left at least `DIRT_BARE` (0.5) earth loses its grass, blades and meadow and is marked hand-made (`SOURCE_HAND`), so emergence neither regrows cover over it nor plants in it. The tint and the cover are part of the history snapshot and the saved document, so the dirt goes into the stroke's undo step and survives save and load. The rub paints none; the pinch paints rock (below).
- **The pinch.** The pointer's travel up the screen is turned into metres at the scale of a metre standing at the spot (never less than 0.3 of a metre across the ground, so a camera looking straight down still pinches), so the summit follows the pointer. The shape is `(1-t²)²` over a radius of 2.2 m plus 0.45 m per metre of lift, at most 5.6 m; the lift is between -4 and +8 m, and sinking never takes ground below -1.2 m. The Shift pinch takes 0.4 of the travel over 1.2 m plus 0.3 m per metre (at most 2.6 m), between -1 and +2 m. The shape is written from the heights at the hold, so it follows the hand both ways with no spring. The pinch takes the land's nearest point to the press, so its tip stands on a point and the summit reaches the pointer exactly.
- **The pinch's horn.** The rounded `(1-t²)²` swell was the wrong family beside the edge spring's faceted jagged range. A raise now blends from it into the range's horn as it grows (`HORN`, smoothstep over 1 to 4 m of lift): the alpine form of `mountain_forms` `_stamp`, scaled so its summit is 1, concave faces up to a sharp tip, three to five arêtes seeded by the spot (so they hold still while the hand moves), and the forms' crag and lump noise (their per-world noise, `prepare`), so the outline wanders; the points are gathered `HORN_REACH` (1.25) of the widest radius out for it. Sinks and the Shift pinch (at most 2 m, so at most 16 % horn) stay rounded. Measured headless at an 8 m pull: the ring round the summit varies by an angular s.d. of 0.13 to 0.51 m (0.02 to 0.04 before), slopes p50 1.31, p90 2.15, max 3.6 (the range's tallest peak: 1.18, 2.01, 3.2; the old dome 1.84, 2.47, 4.0), roughness (mean departure from the four neighbours 0.5 m out) 0.110 (range 0.100, dome 0.079). A 1.4 m pinch is still a soft swell (s.d. 0.02).
- **The pinch's rock.** Let go, a raise of at least `ROCK_FROM` (2.5 m) takes the range's granite on its steeps and upper share (`mountain_forms._rock_tint`, the range's rock job run at once over the pinch), measured against a height that keeps a low swell green (`lerp(10, lift, horn)`, at least 2, as the range's gentle pulls do); the hand's bare earth keeps its colour. It goes into the pinch's undo step. The ground is not weathered: clay stays as it was left.
- **Trees shaken off.** While held, a tree on the pinched ground rides it up (its record stands on the ground). Let go, a tree on ground the pinch moved keeps its footing only where a tree could take root, by emergence's rule: no steeper than the rock slope the terrain paints rock above, and under the rock band 1.8 m below the snowline. Else it slides down the fall line in `SLIDE_STEP` (0.25 m) steps until the ground is at most `SLIDE_REST` (0.45) steep and under that band, or a pond, the edge fade or `SLIDE_MAX` (12 m) stops it, and stands there. Pinned trees and the Bigfoot tree hold; moved trees stay wild (not marked hand-made), and the move is part of the pinch's undo step. This is the "you release, the world decides" choice: the hand is not stopped from lifting a tree, nor does the pinch push trees aside while it is held (the land still follows the hand exactly); the world settles what the hand made at release, as the edge spring's range lands. Headless: a tree beside an 8 m pinch, at 8.04 m on a 1.19 slope before, slid 4.1 m to the foot (ground 0.43 m, slope 0.37).
- **The poke.** A dimple 0.1 m deep over 1.2 m, `-depth·e^(-7t)·cos(26t)` over half a second, then the exact heights come back (only where nothing else moved them).
- **One undo step each.** `data.begin_stroke()` opens when the verb is decided and `end_stroke()` closes at release, so an unmoved pinch adds none. Release runs the editor's settle refresh and tells emergence about the stroke's ground as a land stroke would. Nothing weathers after: clay stays as it was left.
- **Frame cost.** Only the points near a dab are written (a bucket lookup, 1.5 m cells), and the land is shown through the editor's light refresh, one at a time, as the brushes and the land spring do. The dirt samples the ground at each tint cell under the frame's dabs; a 1 m groove stroke measured a 7.1 ms CPU max, 5.2 ms mean (dummy renderer), about what the 0.3 m groove cost.
- **The hand.** The hover's ready pinch stays while the press is undecided. The pinch plays its `PinchIn` again when it is decided, so the hand visibly closes. The thumb, the palm and the poke use `press` (the thumb's Hold plays faster as the stroke turns into a rub). On release the hand is let go and the hover takes it back.

### The thumb at the rim

Branch `feature/edge-falls` (2026-09-29). The user wanted to "thumb your way to the edge so the water could actually flow and actually spill over the edge of the chunk like a waterfall … into the void".

- **The fade stays for everything else.** Shaping fades to nothing over the plate's last metres (`EDGE`, 11.4 to 13.6 m from the middle, `_fade`), so a groove could not reach the rim. It still does for the pinch, the palm, the rub, the groove's raised banks, and a thumb running along the edge. The plate's outline stays clean.
- **Heading out breaches.** A groove dab in that fade zone whose stroke is heading out across the nearest side, within `BREACH_ANGLE` (50°) of straight out, **breaches** (`_breaching`). It digs its bed at full depth without the fade, rim points included.
- **The heading.** It is taken over the stroke's last `HEADING_RUN` (0.6 m), so a slow stroke's pick jitter cannot turn it.
- **Carried to the lip.** A breaching stroke let go short of the rim, or run off the plate into the void (where the pick finds nothing), is carried on along its heading to `BREACH_PAST` (0.4 m) beyond the rim (`_carry_to_lip`). The groove therefore always reaches the lip.
- **The spillway.** The bed keeps falling (it never climbs), so the rim is notched to the groove's level-floored, round-banked section, about 1 m deep and 2.5 m across. It is tinted with the groove's dirt.
- **The earth sides follow.** They are refitted to the notch without a gap (`skirt_mesh_for` slices their big facets at the rim's points where it bends; `docs/scenic/water-flow.md`, "Edge falls"). The notch runs a shallow chute down the face, fading toward the block's base.
- **Counters.** `notches` and `last_notch` (side normal, rim point, bed) are for probes.
- **Checked.** `tools/probe_edge_fall.gd`: a stroke let go at 13 m notches the rim 0.8–1.0 m deep over four rim points. The rim beside the notch, and beside a thumb run along the edge, is unchanged. The earth sides meet the notch within 1 mm. Filmed in `tools/film_edge_fall.gd`.

### Limits and open points

- **No thumb or poke clips.** The thumb, the palm and the poke all show the Press pose. A thumb stroke and a fingertip poke want their own clips.
- **The pinch follows the hand very directly.** From the default view a metre is about 15 px, so 60 px of drag raises about 4 m. This is what "follows the hand" means, but it may feel too touchy from far out. `PINCH.scale` is the knob.
- **The groove cuts at most `GROOVE_CUT` (0.2 m) extra** to keep its bed falling; over a bigger hump it rises with the ground, and water will pool behind it.
- **Dirt is per 0.5 m tint cell and per face.** A face takes the colour of the cell under its middle, so the earth's edge along the lip is stepped at the facet scale, not a soft line.
- **The tree's slide is a jump.** The record moves at release and the settle refresh shows it at the foot; there is no sliding or toppling animation yet. The edge spring's range still leaves trees standing on its flanks.
- **Dirt only deepens.** A later palm or pinch that fills a groove back in leaves the earth showing; only undo takes it back. Emerged plants already standing in a groove when it is dug stay.
- **The poke is still 0.1 m.** Beside a 1 m groove it is small (about a pixel from the default view, 58 m out); `POKE_DEPTH` is the knob.
- **A drag off the land** skips the points off it and joins up again where the pointer comes back.
- **Creatures.** The resident looks round at a poke, and the Genesis life notices it too: frogs near it plop in, fish scatter and come back to nose at the rings, deer look up or walk off, a heron leaves (`docs/scenic/life.md`, "Noticing"). The snap wakes the fireflies in a wave at night and brings a dawn chorus at day.
- **Unverified on screen:** how the groove, the rub, the palm and the pinch look and feel (the 2026-09-29 legibility pass, the horn, its rock and the pale lip are measured headless only); whether the dirt colours (#946c47, #73513a) sit well in the painted, faceted look beside the grass and the Fidelity reference; whether 0.3 s and 6 px classify well on a trackpad; whether 500 and 1200 px/s split a stroke from a rub for a real hand; the Press pose standing in for the thumb.

### Probe

`tools/probe_land_clay.gd` (run with `-- --modeless`, `--fixed-fps 60`) drives the real product scene with synthesized mouse input through `hand_reach`, on a bare spot it finds. It proves: a quick release is a tap that dimples the spot, the hand pokes, the ground comes back bit-exact and no undo step is added; a 4 px nudge let go at 0.17 s is still a tap; a press is undecided before 0.3 s and a pinch after, with `PinchIn` playing, and a pinch let go unmoved keeps nothing; a 6 px move decides the thumb by the second frame; a 300 px/s drag is a groove (rub share 0) dug all along its path (it reads 0.65 to 1.0 m, because it samples the path picked on the live ground, part way up the wall), with banks raised at most a few centimetres; an 1800 px/s back-and-forth is a rub (share 1) that takes the probe's roughened ground from about 0.09 to 0.0001 mean neighbour difference without digging; Shift-drag is the palm (its check that the ground ends near the press's height now fails by design: the palm presses 0.24 m under it in that run; the check wants updating when the tests are); hold and drag up 60 px raises the spot about 4 m with the summit within a pixel of the pointer, and it stays after release; down sinks it; a Shift pinch raises about a third as much over a sixth of the points; each verb is one undo step and one undo restores the heights exactly; the land spring never starts or springs. CPU frame gaps (dummy renderer) while dragging: groove max 7 ms, rub under 6 ms, pinch under 5 ms.

`tools/probe_land_spring.gd` now drives the spring directly and checks the land signals leave it idle; `tools/probe_modeless_rim.gd` checks a land drag is the thumb and the spring stays idle.

## Edge rework: the dip, the amplify, the random range, the basin and the toss

Branch `feature/modeless-edge-spring`, the first build slice of the agreed scheme above (the edge's rows). Checked headless only (`tools/probe_edge_spring.gd`); nothing has been seen or felt on screen.

### Try it

- **Pull the rim down** (the lip, or anywhere down a wall). The whole block dips as a unit and tips a little toward your hand, deeper as you pull, trembling near the cap. Nothing on the land moves yet.
- **Let go on land you have shaped.** The block snaps back up and your own shapes spring up bigger: they overshoot, ring down, settle and weather. Peaks you pinched grow taller, sharper and craggier; thumb grooves and palm basins get deeper, and water standing in them reflows. A gentle pull adds a little, a hard one a lot. Nothing new is placed. Rock repaints the taller slopes, and the thumb's bare earth stays as it was. Pull again to amplify again, under a ceiling. One undo takes each back.
- **Let go on a blank plate.** Nothing to amplify, so a random range springs out of the land instead, as a starter. A gentle pull gives low rolling hills, a hard one tall jagged peaks. Where it rises, which way it runs and how many peaks it has are random, leaning away from the rim and from ground that is already tall.
- **A tiny pull** keeps nothing and adds no undo step.
- **Lift the rim up.** The block's near edge lifts and tilts after your hand, hinged on the far edge, as the flip always did. What happens is decided when you let go:
  - **let go slowly** (or hold still first): the block settles back with a small bounce and a random basin sinks, sized by how far you lifted, away from the rim;
  - **flick it**: the block is tossed. It turns about its far edge at the flick's speed under gravity; too little and it falls back and wobbles, enough and it passes upright and goes over (the flip: a new world);
  - **catch it in the air** (press anywhere while it is up) and flick again: the tilts add up, so you can pump it over like a swing. One hard flick also takes it over.
- **Shift and push sideways.** The world turns, however fast, and time does not wind (no shimmer either).

### How it works

- **The dip** is the flip's snapshot (`scripts/diorama_flip.gd` `dip_begin`, `dip_to`, `dip_release`): the diorama's meshes are copied onto one pivot and the real ones hidden, as for the flip, and the pivot is posed with `pose(-DIP_TILT*d, -DIP_DROP*d)`: at a full pull the block drops `DIP_DROP` (0.9 m) and tips `DIP_TILT` (0.06 rad) about its far edge, so the grabbed edge goes down about 2.3 m. It follows the pull on the hold spring (13/s, 0.85). Let go, it snaps up on a stiffer spring (26/s, 0.5) and is handed back the moment it reaches rest (5 frames in the probe); `dipped(amount)` then starts the range's spring. No terrain is touched while it is held, so the snapshot never shows stale land.
- **The pull** is the land spring's measure: travel down from the press over 0.32 of the viewport's height is the cap; under 0.03 nothing shows; let go under 0.12 and nothing is kept.
- **Shaped or blank** (`scripts/edge_spring.gd` `_build_shape`). At release the plate's relief is measured: the largest departure of any point from the smooth base (below), faded at the rim. At `RELIEF_MIN` (0.5 m) or more the plate has been shaped and is amplified; under it a range springs. The cozy worlds' starting plate measures 0.22 to 0.27 m; one clay pinch, groove or two palm presses take it over.
- **The amplify** (`_build_amplify`, branch `feature/edge-spring-amplify`):
  - **the base** is a robust heavy blur of the land: point heights averaged onto a 1 m grid, blurred with three box passes 4 cells either side (about a 4 m gaussian), then refined four times, each time blurring the heights clamped to within 1, 0.5, 0.25 and 0.25 m of the last base (`BASE_CLAMPS`). A clamped peak or basin barely pulls the base toward itself, so what you shaped stands out from the base and the ground round it does not. The plate's plain level (a flat base) was rejected: it scales every height, so a palm basin pressed into raised ground (still above the plain) would rise instead of deepening, and a broad raised shoulder would lift as a block. A plain blur was also rejected: a peak pulls it up round itself, so its foot sinks into a moat (0.32 m round a 3.3 m peak at a hard pull in the probe, against 0.19 m with the clamps, most of which is the plate's own ripple amplified);
  - **the factor**: each departure is scaled by `lerp(1.1, 1.6, pull)` (`AMPLIFY`), so the smallest kept pull (0.12) is about ×1.16 and the cap ×1.6. Peaks rise, grooves and basins deepen;
  - **jaggedness** follows the range's blend (`JAGGED`, 0.15 to 0.85 of the pull). On upper slopes (a smoothstep over 0.6 to 3.5 m above the base, `UPPER`) the gain grows by up to 40 % of itself (`SHARPEN`), so summits sharpen, and the mountain forms' ridged and fine crag noise moves the ground by up to 20 % of its departure either way (`CRAG`). A rise is never negative;
  - **limits**: rises are eased under the range's ceiling (`KNEE` 7 m toward `CEILING` 11 m), faded off water by the mountain keep-out and capped at `MAX_HEIGHT`; sinks are eased below `SINK_KNEE` (-0.8 m) toward `MIN_HEIGHT` (-1.5 m), never reaching it. Both fade to nothing over the plate's last metres (`EDGE`, 11.4 to 13.6 m), as the range does;
  - it is built into the editor's mountain as the range is (lift, touched points, bounds, a middle weighted by the rise), so it springs through `_apply`, lands through `_land_mountain` (weathering on the risen cells only, rock by share of `max(2, top, lerp(10, top, jag))` m) and is one undo step, which restores the heights and tint exactly; an undo mid-spring lands it first;
  - **bare earth stays**: `tint_lock` on the mountain (`scripts/mountain_forms.gd`) names the tint cells the rock must leave alone, set to the cells the hand has bared (hand provenance, no grass: the clay's dirt and paths);
  - built in about 4 ms at release (3 ms of it the base) on the 2025-point plate in the probe.
- **The range** (blank plates; `scripts/edge_spring.gd`, which extends `scripts/land_spring.gd` for its spring, landing and basin):
  - random, from a seeded generator: 2 to 5 peaks (`RANGE_PEAKS`), a crest line 6 to 15 m long (`RANGE_LENGTH`) at a random bearing;
  - placement: the best of 24 random middles (`CANDIDATES`), its ends kept within 9 m of the middle lines (`RANGE_ROOM`), scored `-3·(distance out / 11 m)² - 0.6·(mean ground along the line, m) + 1.5·random`. The grabbed edge plays no part;
  - peaks slip along the line by up to 35 % of their spacing and stand off it by up to 1.2 m; each is 65 to 100 % of the range's height, lower toward the ends;
  - the pull sets height and jaggedness together. The range's height is 1.2 m at no pull to 9.5 m at the cap (`RANGE_HEIGHT`). Each peak is a blend of a rolling dome (radius 3.2 to 4.8 m, `(1-r²)²` with the forms' lumpy noise) and the alpine horn of `scripts/mountain_forms.gd` (its own arêtes, crags and faces). The blend runs from all dome below a pull of 0.15 to all horn above 0.85 (`JAGGED`). In the probe, with the same seed, a 0.24 pull rose 3.2 m with a roughness of 0.014 per metre and a full pull 7.8 m at 0.024;
  - the peaks are combined as the root of the sum of their squares, so neighbours join in saddles;
  - **the ceiling**: ground is left as is up to `KNEE` (7 m) and eased toward `CEILING` (11 m) above it (`7 + 4·(1 - e^(-(h-7)/4))`), so it never reaches 11 m and a range on tall ground adds little. 11 m suits the 28 m plate: under half its width, above the snow line (about 6.5 m). Three full pulls in the probe reached 9.4 m;
  - it is built into the editor's mountain (`editor.mountain`: the alpine form's `begin` for the base, the keep-out from water and the rim, and the salt; each peak's `_reshape`; the combined lift written back), so it springs through the land spring's `_apply`, lands through `_land_mountain` (weathering and rock on a worker) and is one undo step. Built in 1.4 to 2.4 ms at release in the probe. Gentle ranges keep their green: the rock paints by share of `max(top, lerp(10, top, jag))` m.
- **The toss** (`diorama_flip.gd`). A release reads the drag's rate (progress per second, smoothed over 0.06 s; progress is upward drag over 0.45 screen heights):
  - upright or past it (`TIP_ANGLE`, pi/2): it goes over, as before;
  - rate at least `TOSS_RATE` (1.5 a second, about 600 px/s on a 900 px window): tossed, at `max(the plate's own rate, rate·pi·TOSS_GAIN)` rad/s with `TOSS_GAIN` 0.5. In the air it is a hinged slab: `angle'' = -TOSS_GRAVITY·cos(angle) - TOSS_DRAG·angle'` with `TOSS_GRAVITY` 16 rad/s² and `TOSS_DRAG` 0.3/s, stepped at 240 Hz. From flat that needs about 5.7 rad/s (`sqrt(2·16)`) to reach upright; passing upright hands it to the flip's throw (no pull back), which makes and lands the new world as before. Landing keeps 28 % of its speed per bounce, as the fall back does;
  - slower: it falls back as before, and when it rests `set_down(progress)` sinks a basin. A toss that falls back sinks nothing.
- **Catching.** While a tossed plate is in the air (`can_catch`: tossing or falling back), any left press is `catch`: the hand holds the rim again (`hand_reach._catch_toss`, `rim_intent` "flip") and the plate is held where it is, its speed kept; the next drag adds to its angle (`base + pi·progress`), and the next release is read as above. `tosses` counts flicks since it left the ground.
- **The basin.** `edge_spring.basin(progress)`: nothing under a lift of 0.08; the land spring's bowl at `min(progress/0.45, 1)` of its size (radius 2.2 to 5 m, 0.4 to 1.1 m deep), at a spot chosen as the range's is, its rim within 11 m of the middle lines. One undo step.
- **Shift.** `hand_reach` records Shift at the rim's press (or held when the turn is decided) and sets `world_turn.timeless`; `spin_time.gd` reads a timeless turn as speed 0.
- **Undo.** `edge_spring` chains its `land_now` onto the editor's spring hook, so an undo mid-dip or mid-spring lands it first (the probe undoes one mid-spring and gets the heights back exactly).

### Limits and open points

- **Amplify weathers with the alpine settings**, and a gentle pull's rock height of about 10 m also raises the weathering's detail, as the range's rolling hills do. The crags add little fine roughness the probe can measure (roughness per metre of prominence 0.053 before, 0.053 after a hard pull); the sharpening shows more (prominence ×1.86 at a ×1.6 factor). How craggy it reads needs eyes.
- **The relief threshold** is a single number over the whole plate. A world generated with more ripple than 0.5 m would amplify on its first pull.
- **Several forms.** The horns are alpine only; ridge, mesa or the biome's form could join. Hills weather with the alpine settings.
- **The dip snaps up and hands over.** The block's own overshoot upward is not shown (the snapshot is released at rest); the range's overshoot carries the energy. A small upward tremor at the hand-over is untried.
- **Catch reach.** Any left press catches a tossed plate, wherever it is, not only one on its rim.
- **The land spring stays** for the land press until the clay slice retires it; `edge_spring.gd` extends it, so retiring it means keeping the file or moving the shared parts.
- **The hand** grips the rim with the flip's grip during the dip; the wall palm could replace it on walls.
- **Unverified on screen:** how the amplify reads (whether the sharpening and crags look like more energy or like noise, the rock on the risen slopes, the dirt left in grooves), how the dip, the snap and the springing range read, whether the toss's gravity and gain feel right on a mouse and on a trackpad (600 px/s may be too easy or too hard to hit on purpose), the catch, the rolling-to-jagged blend, and whether the ceiling suits the look.

### Probe

`tools/probe_edge_spring.gd` (run with `-- --modeless`, `--fixed-fps 60`) proves, in the real product scene with synthesized input:

- a downward rim drag, from the lip in the overview and from a wall in a low view, decides "spring", does not flip or turn, dips the block as a unit (1.05 m at a 0.67 pull, the grabbed edge 1.56 m) on the snapshot, touches no terrain while held and shows the rim grip;
- let go, the block is back up in 5 frames and the range springs: several peaks, off the rim, one undo step, restored exactly by one undo;
- the same seed pulled gently and hard: 3.2 m and roughness 0.014 against 7.8 m and 0.024;
- three full pulls with one seed land in three places (the tall ground moves the next away) and stay under the ceiling (9.4 m); three undos restore them;
- an undo mid-spring takes it back exactly; a tiny pull keeps nothing;
- a slow lift let go settles the block and sinks a basin (1.07 m deep), off the rim, one undo step, restored by one undo;
- a small flick (960 px/s) tosses the block from 0.26 rad to 0.75 rad; it falls back, lands three times, sinks no basin and makes no new world;
- caught in the air and flicked the same way again, it goes over and a new world lands; one hard flick (2400 px/s) also goes over;
- Shift and a fast push turns at 8.9 rad/s and winds no time.

Its stacking check (three full pulls with one seed) predates the amplify: after the first range the plate is shaped, so the second and third pulls now amplify it, and that section needs rewriting.

`tools/probe_edge_amplify.gd` (same flags) proves the amplify:

- the blank plate measures 0.22 to 0.27 m of relief and a hard pull still springs a random range (3 peaks, 9.5 m), taken back exactly by one undo;
- the clay sculpts a peak (a pinch, about 3.3 m), a groove (a slow thumb, about 1.1 m) and a basin (two palm presses, about 0.5 m). In one run, before, gentle (0.24 pull, ×1.22) and hard (full pull, ×1.6):

  | | sculpted | gentle | hard | hard twice |
  |---|---|---|---|---|
  | peak height (m) | 3.45 | 4.27 | 6.24 | 9.81 |
  | peak prominence (m) | 3.33 | 4.18 | 6.20 | 9.85 |
  | groove depth (m) | 1.14 | 1.37 | 1.63 | 1.89 |
  | basin depth (m) | 0.50 | 0.60 | 0.77 | 1.21 |

- it springs: the shape's scale overshoots to 1.26 (the peak reached 6.9 m before settling at 6.2 m);
- nothing moves beyond 13.6 m out; the fade band moves at most 0.19 m at a hard pull (the plate's own ripple amplified);
- none of the 195 bare-earth tint cells changes;
- each is one undo step, which restores heights and tint exactly; an undo mid-spring does too;
- the build takes about 4.1 ms at release (3.1 ms for the base) and the release frame about 7.4 ms, against 2.5 ms and 12.6 ms for the blank plate's range.

## Void slice: the ever-present hand and the snap

Branch `feature/modeless-void`. Checked headless only (`tools/probe_void_snap.gd`); nothing has been seen, heard or felt on screen.

### Try it

Run the product scene with `-- --modeless`.

- **Point at the sky**, or anywhere off the diorama. The hand floats there, half upright with its fingers loosely curled, and now and then its thumb rubs its middle fingertip. Over the land it readies a pinch and on the lip it takes the rim grip, as before. Over a panel it goes.
- **Click the sky.** The hand snaps its fingers, with a crisp snap you hear, and it is night; click again and it is day. The cut is instant.
- **Shift-click the sky.** The snap steps the golden hours: dawn, noon, dusk, night, dawn. It is a lighter snap, quieter and a touch higher.
- **Press the sky and drag.** No snap fires, and the loaded hand relaxes. The drag is the wind's ("Wind" below). Water comes from the sky's cloud now, not from empty sky (`docs/scenic/sky-cloud.md`).
- **Right-drag, scroll or pinch.** The hand fades while the camera moves and comes back when it stops.

### How it works

- **The void.** A pointer that is in the world (`pointer_in_world`) but reaches no rim or wall, has no land under it and no prop, tree or resident is in the void (`hand_reach.void_at`, hover zone `"void"`). The hand stands on the pointer's ray `VOID_DEPTH` (0.8) of the camera's distance to its pivot out, and never nearer than `VOID_NEAR` (5 m). That is about the size the hand has over the middle of the land, a touch bigger, so it does not jump in size as the pointer leaves the land; at the overview (59 m) it is 47 m out. The sun grab's fixed 12 m made the 2.5 m hand fill a fifth of the screen.
- **The poses.** The god hand gestures `"void"` (VoidIn, VoidHold, VoidOut) and `"snap"` (SnapIn, SnapHold) turn the hand square to the camera, as the sun's Reach does, and float free (they lean into the pointer's way; no tilt, no lift). `docs/scenic/god-hand.md` has the clips.
- **The click.** A left press in the void is held by the hand (`holding == "void"`) and loads the snap: the hand plays SnapIn and holds it. If the pointer wanders more than `CLICK_PIXELS` (6 px) the press is a drag: the hand relaxes back into VoidHold and the release does nothing. A release inside that is a click: `fire_snap(shift)` changes the hour, plays the snap's sound and the hand plays SnapOut, the slam and its follow-through, back into VoidHold. The slam is SnapOut's first frame after the loaded pose (`snap_hit_s`, 1/30 s), so the cut, the sound and the slam land together. There is no time limit: holding the loaded snap and letting go is still a snap. A click quicker than SnapIn's load (its tips meet at 0.1 s, `snap_loaded_s`, `god_hand.SNAP_LOADED`) first moves SnapIn on to the loaded frame, so even the quickest click shows the thumb and middle pressed together before the slam.
- **The hours.** `scripts/void_snap.gd`. Day is the sun above the horizon. From day a snap lands on mood_look's Night (phase 0.035, just after midnight, the moon high); from night on its Morning (0.345). Shift steps to the nearest of Dawn 0.275, Midday 0.47, Dusk 0.705 and Night 0.035 ahead of the hour now. The clock is wound forward to it, as a spin winds it (the day moves on; nothing runs backwards). The weather is not advanced.
- **Instant.** The blend is 0 s. Everything that smooths the hour between the clock and the screen is bypassed for a snap: a mood cross-fade in flight is landed first (`finish_fade`, else it drags the old hour back over 1.2 s); the N key's easing (`skip_to`) is dropped by setting the time outright; the celestial rig is rebuilt at once (`update_rig`), so the lights and every sky, fog and night global are the new hour's that frame; and the sky's radiance map, which refreshes over several frames (`PROCESS_MODE_INCREMENTAL`), runs in real time for 0.3 s so the wet-sheen reflections follow. Everything else that reads the hour (fireflies, the display fog colours, the look pass, the cricket and frog beds) already follows it every frame.
- **Audio.** The cricket and frog beds follow daylight every frame, so they switch at once. A bird call from the wrong half of the day (a song after a night snap, an owl after a day snap) fades out over half a second (`nature_audio.snap_to`), and the new half's first call comes within a few seconds (an owl in 1.5 to 4 s, a song in 0.5 to 2 s).
- **The snap's sound.** `scripts/snap_sound.gd`, an `AudioStreamPlayer` the hand reach makes in its setup under `--modeless` and plays in `fire_snap`. It is not positional: the snap is the player's own hand. Three takes (`assets/audio/finger-snap-1..3.wav`) are synthesised by `tools/generate_nature_audio.py --snap` (`finger_snap`, `bake_snap`): a dry skin tick (0.7 ms), a bright crack of noise band-passed round 2.4 to 3.1 kHz over a 900 Hz high-pass, about 1 ms up and decaying over 16 ms and 45 ms, a faint 6.2 kHz sizzle, a short low slap of flesh (a 175 to 210 Hz sine falling in pitch, 18 ms), three early reflections (7, 13 and 19 ms) and a quiet 75 ms room tail. Mono, 44.1 kHz, 0.32 s, imported as QOA like the other one-shots. Each snap picks a take other than the last, a pitch of 0.93 to 1.07 and a level within 1.5 dB of `GAIN` (0.4, about −8 dB, on the `Genesis` bus, so the Sound volume and Mute apply). A Shift-snap is lighter: `LIGHT` (0.55) of the gain and a pitch of 1.08 to 1.18.
- **Pins.** As for a spin: a clock that was running keeps running from the new hour; a held clock is pinned again at it (`mood_look.pin_hour`, a held hour).
- **The camera fades the hand.** `hand_reach.camera_moving()` is true during a right drag and while the camera's view still turns or zooms faster than 0.05 rad/s (or log-distance/s) or its pivot slides faster than 0.15 m/s (a fling, a zoom, a double-click's glide). A turn or spin of the world is not the camera moving, nor is a followed creature carrying the pivot. While it is true the hover sets `god_hand.held_off` and the hand fades out as it stands (keeping its pose) and back in when the camera stops, at the hand's usual fade (0.25 s). A hold (rim, land, flip, void) keeps the hand.
- **Hint.** Over the void the hint line reads "Click the sky to snap day and night · Shift-click steps dawn, noon, dusk, night" until two snaps have been made.
- **Signals.** `hand_reach.snapped(phase, step)` after each snap; `hand_reach.snaps` counts them.

### Limits and open points

- Nothing has been checked on a GPU: the hand's size and pose in the sky, the snap's read, the cut, and the reflections catching up are all unseen. Headless has no renderer, so the radiance switch is only checked as a setting.
- Nothing has been heard: headless Godot has a dummy audio driver. The snap's sound (its brightness, level and how it sits with the slam) and the nature beds and calls are unheard. `GAIN`, the pitch ranges and the synthesis in `finger_snap` are the knobs.
- Shift + sideways rim push (turn without time) is the edge slice's.
- Headless has no pointer, so probes set `hand_reach.pointer_override` for the hover.
- Clicking the sky no longer lets go of a hover as the rim slice's probe expected: over the sky the hand stays. `tools/probe_modeless_rim.gd` and `tools/probe_diorama_flip.gd` now expect the void pose where the pointer is in the sky.

### Probe

`tools/probe_void_snap.gd` (`--headless --fixed-fps 60 ... -- --modeless`) on the product scene: the glb has the six clips; the sky is void and the land's middle is not; hover there takes the void pose and plays the void clips, the hand shows at the void depth with its point under the pointer; over a panel the hand lets go and hides; a press loads the snap, and the release cuts to night the same frame (phase, `zs_night`, key light energy and `zs_sky_up` all change), the day moves on, radiance runs in real time and goes back, the hand plays SnapOut and returns to VoidHold; a running clock keeps running unpinned; a second click is day; a held clock is pinned at the new hour; a mood fade in flight is landed; Shift-clicks step 0.275, 0.47, 0.705, 0.035, 0.275; a drag relaxes the hand and does not snap; a right drag fades the hand, which comes back once the camera stops; land and rim presses are as before and do not snap.

## Wind: swipe the sky for a gust, hold and pull to turn the wind

Branch `feature/sky-cloud`. Checked headless only (`tools/probe_sky_wind.gd`); nothing has been seen or felt on screen.

### Try it

- **Swipe the sky** (press in empty sky, flick across, let go within `SWIPE_SECONDS`, 0.3 s). A gust blows across the land along the swipe, as the camera sees it: flicking right blows to the screen's right, flicking up blows away from you. The faster the flick, the stronger the gust. It is the wind tool's lane gust (`scripts/wind_gust.gd`, `docs/scenic/wind-gust.md`), so the fog parts, trees, grass and water bend as it passes, leaves blow and pollen in the air rides it. It starts just inside the land's upwind edge and runs across it, 5 m either side of its line. The prevailing wind does not change.
- **Press the sky, drag and hold.** After 0.3 s the prevailing wind is in hand. It blows the way the pointer lies from the press, laid onto the ground as the camera sees it, and harder the further you pull: from a breeze (0.15) at 4 % of the view's height to a strong wind (1.3) at 40 %. The world's air swings round to it while you hold, faster than the weather would turn it. Let go and it stays. Pollen falling after that drifts on it.
- **Drag from the sky onto the land.** The wind tool (`docs/scenic/wind-gust.md`) is taken in hand where the drag meets the ground, as if the Wind brush had pressed there, and the gesture is the tool's from then on: the lane's promise shows on the ground, the hand's air leans the foliage, swiping on and letting go sends the lane along the swipe, and holding still gathers a burst. The flick's heading and power come with it (`WindGust.carry`), so a fast drag in from the sky blows hard at once and then follows the swipe on the land. The lane is the Wind brush's size (3 m half width) and strength. A held wind turned on the way in (the drag took longer than 0.3 s to reach the land) is put back as it was. The god hand opens to blow while the tool is held.
- **Click** is still the snap: a press that moves under 6 px is never the wind's.

### How it works

- `scripts/sky_wind.gd` (made by `hand_reach` under `--modeless`) is fed the void's press, drag and release, and is stepped each frame while a void press has moved past `CLICK_PIXELS`. It stays a swipe until `SWIPE_SECONDS`, then becomes the held wind.
- **The swipe.** Its speed is read over the last `SWIPE_WINDOW` (0.12 s), in view heights a second: 0.4 or slower is the weakest gust (power 0.25), 3 or faster a full one. `NativeChunkEditor.gust_from_sky` finds the start, backing up from the land's middle against the heading to `SKY_GUST_INSET` (2 m) inside the land's rectangle, then walking in until there is ground. It sends the gust with `WindGust.send_lane`, which is the tool's press and release in one step.
- **To the land.** `hand_reach._void_drag` calls `SkyWind.to_land` once the drag has moved past `CLICK_PIXELS` and the pointer is over the land. That calls `NativeChunkEditor.gust_in_hand`, which presses the tool at the ground point and carries the flick. The hand's reach then lets go of the void, and the editor's `_gust_process` aims the tool and sends it when the button comes up, as it does for the Wind brush.
- **The held wind.** It sets the atmosphere's `direction_angle` and `strength`, the targets its air eases toward at the weather's pace (`weather_response`, 0.55/s). While held it also swings `_air_angle` and `_air_strength` there at `STEER` (4/s), so you see the world answer. The weather's drift moves strength relative to where it stands, so a set wind survives it. A mood preset or a mood's restore sets the wind again. The atmosphere's fields are saved with the garden.

### Limits and open points

- Nothing shows the wind's heading while you hold except the world bending (trees, grass, fog, the wind trails). A vane or streaks under the hand may be wanted.
- The hand has no blowing pose; it relaxes as for any void drag.
