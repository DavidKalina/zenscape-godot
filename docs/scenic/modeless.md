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
- a left land press emits `land_pressed`, `land_dragged`, `land_released`, does not turn, paints nothing (no undo step, no height change);
- a fast right drag tilts and looks round without changing time, the room or the spin.

`tools/probe_wall_grab.gd` (same flags) takes a low, close camera facing a wall and proves the wall's middle is rim, reaches the point under the pointer, shows the rim grip stood out from the wall, turns the world with the grabbed point within a few pixels of the pointer, and decides the flip from an upward drag.
