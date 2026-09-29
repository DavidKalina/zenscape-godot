# Modeless controls

The control scheme agreed on 2026-09-28 (see "Verbs on the diorama" in `docs/scenic/hand-world.md`). Everything here is behind `--modeless`; without the flag the game behaves exactly as before. The idea is almost no UI and no tool modes. The hand is contextual and what it does depends on where you press. The only mode is the camera, on the right button.

| Press (left button) | Do | Result |
|---|---|---|
| Rim | push sideways | the world turns; a fast spin winds time |
| Rim | shake | snow-globe weather |
| Rim | drag up and over | flip (the flip slice) |
| Rim (lip or wall) | pull down or up, release | a random range, a basin, a toss or the flip ("Edge rework" below) |
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
- **The rim's axis.** The first `AXIS_PIXELS` (12 px) of a rim drag decide it: if the vertical travel beats the sideways by `VERTICAL_BIAS` (1.2) it is the lift (`"flip"`) when it goes up and the edge spring when it goes down (see "Edge rework" below), otherwise the turn. The snow globe is fed every motion from the start, so a shake can be decided at any point and takes over from either. `hand_reach.rim_intent` is `""`, `"turn"`, `"flip"`, `"spring"` or `"shake"`.
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
- a shake decided from a sideways or a vertical start becomes "shake", the turn lets go, no flip is left running (a downward start is now the edge spring, which the shake lets go of with nothing kept), the hand shakes, and time is not wound;
- a left land press emits `land_pressed`, `land_dragged`, `land_released`, does not turn, paints nothing (no undo step, no height change);
- a fast right drag tilts and looks round without changing time, the room or the spin.

`tools/probe_wall_grab.gd` (same flags) takes a low, close camera facing a wall and proves the wall's middle is rim, reaches the point under the pointer, shows the rim grip stood out from the wall, turns the world with the grabbed point within a few pixels of the pointer, and decides the flip from an upward drag.

## Edge rework: the dip, the random range, the basin and the toss

Branch `feature/modeless-edge-spring`, the first build slice of the agreed scheme above (the edge's rows). Checked headless only (`tools/probe_edge_spring.gd`); nothing has been seen or felt on screen.

### Try it

- **Pull the rim down** (the lip, or anywhere down a wall). The whole block dips as a unit and tips a little toward your hand, deeper as you pull, trembling near the cap. Nothing on the land moves yet.
- **Let go.** The block snaps back up and a random range springs out of the land, overshoots, rings down, settles and weathers. A gentle pull gives low rolling hills, a hard one tall jagged peaks. Where it rises, which way it runs and how many peaks it has are random, leaning away from the rim and from ground that is already tall. Pull again and another stacks on, under a ceiling. One undo takes each back.
- **A tiny pull** keeps nothing and adds no undo step.
- **Lift the rim up.** The block's near edge lifts and tilts after your hand, hinged on the far edge, as the flip always did. What happens is decided when you let go:
  - **let go slowly** (or hold still first): the block settles back with a small bounce and a random basin sinks, sized by how far you lifted, away from the rim;
  - **flick it**: the block is tossed. It turns about its far edge at the flick's speed under gravity; too little and it falls back and wobbles, enough and it passes upright and goes over (the flip: a new world);
  - **catch it in the air** (press anywhere while it is up) and flick again: the tilts add up, so you can pump it over like a swing. One hard flick also takes it over.
- **Shift and push sideways.** The world turns, however fast, and time does not wind (no shimmer either).

### How it works

- **The dip** is the flip's snapshot (`scripts/diorama_flip.gd` `dip_begin`, `dip_to`, `dip_release`): the diorama's meshes are copied onto one pivot and the real ones hidden, as for the flip, and the pivot is posed with `pose(-DIP_TILT*d, -DIP_DROP*d)`: at a full pull the block drops `DIP_DROP` (0.9 m) and tips `DIP_TILT` (0.06 rad) about its far edge, so the grabbed edge goes down about 2.3 m. It follows the pull on the hold spring (13/s, 0.85). Let go, it snaps up on a stiffer spring (26/s, 0.5) and is handed back the moment it reaches rest (5 frames in the probe); `dipped(amount)` then starts the range's spring. No terrain is touched while it is held, so the snapshot never shows stale land.
- **The pull** is the land spring's measure: travel down from the press over 0.32 of the viewport's height is the cap; under 0.03 nothing shows; let go under 0.12 and nothing is kept.
- **The range** (`scripts/edge_spring.gd`, which extends `scripts/land_spring.gd` for its spring, landing and basin):
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

- **Several forms.** The horns are alpine only; ridge, mesa or the biome's form could join. Hills weather with the alpine settings.
- **The dip snaps up and hands over.** The block's own overshoot upward is not shown (the snapshot is released at rest); the range's overshoot carries the energy. A small upward tremor at the hand-over is untried.
- **Catch reach.** Any left press catches a tossed plate, wherever it is, not only one on its rim.
- **The land spring stays** for the land press until the clay slice retires it; `edge_spring.gd` extends it, so retiring it means keeping the file or moving the shared parts.
- **The hand** grips the rim with the flip's grip during the dip; the wall palm could replace it on walls.
- **Unverified on screen:** how the dip, the snap and the springing range read, whether the toss's gravity and gain feel right on a mouse and on a trackpad (600 px/s may be too easy or too hard to hit on purpose), the catch, the rolling-to-jagged blend, and whether the ceiling suits the look.

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
