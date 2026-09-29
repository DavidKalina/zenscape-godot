# Modeless controls

The control scheme agreed on 2026-09-28 (see "Verbs on the diorama" in `docs/scenic/hand-world.md`). Everything here is behind `--modeless`; without the flag the game behaves exactly as before. The idea is almost no UI and no tool modes. The hand is contextual and what it does depends on where you press. The only mode is the camera, on the right button.

| Press (left button) | Do | Result |
|---|---|---|
| Rim | push sideways | the world turns; a fast spin winds time |
| Rim | shake | snow-globe weather |
| Rim | drag up and over | flip (the flip slice) |
| Rim (lip or wall) | pull down, release | a range springs up inward of that edge (the edge spring) |
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
- **The rim's axis.** The first `AXIS_PIXELS` (12 px) of a rim drag decide it: if the vertical travel beats the sideways by `VERTICAL_BIAS` (1.2) it is the flip when it goes up and the edge spring when it goes down (see "Edge spring" below), otherwise the turn. The snow globe is fed every motion from the start, so a shake can be decided at any point and takes over from either. `hand_reach.rim_intent` is `""`, `"turn"`, `"flip"`, `"spring"` or `"shake"`.
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

## Edge spring: pull the rim down and let go

Branch `feature/modeless-edge-spring`. Checked headless only (`tools/probe_edge_spring.gd`); nothing has been seen or felt on screen.

The rim is a drawn bow. Grab the edge of the diorama, the lip or anywhere down the block's walls, pull it down and let go, and the energy springs up as a range in the land inward of that edge. How far you pull decides how long and how high.

### Try it

- **Press the rim and pull down.** The land sags in a trough a few metres in from the edge you hold, deeper and longer as you pull, trembling harder near the cap. The hand pinches at the edge and dips with the pull. The world does not turn and nothing flips.
- **Let go.** A ridge runs along that edge where the trough was, springs up through it, overshoots, rings down and settles, then weathers as any mountain does. One undo takes it all back.
- **Pull only a little and let go.** The sag relaxes with a small wobble and nothing is kept, no undo step.
- **Up is still the flip, sideways still the turn, a shake still the snow globe.** A shake that takes over a downward start lets the spring go with nothing kept.

### How it works

- **The decision** is the rim's axis (above): vertical and downward is `rim_intent == "spring"`. `hand_reach` then emits `edge_spring_began(press, edge, hand_point)` (the grabbed rim point `_press_edge`, plate coordinates, on the lip or on the wall, and where the hand shows it), `edge_spring_dragged(pointer)` on every move, and `edge_spring_released(pointer)` on let-go. A shake ends it with a release at the press, so the pull reads 0. `studies/fidelity.gd` connects them to `land_spring.edge_press`, `pull` and `release`.
- **The spring is the land spring's**, drawn from the side: same pull measure (the pointer's travel from the press over 0.32 screen heights, down only), same `DEAD` and `MIN_PULL`, same tension smoothing and tremble, same spring, same landing through the mountain machinery, same single undo step. What differs is the shape, below and in `docs/scenic/modeless-spring.md`.
- **The hand.** While the spring is drawn `_drive_hand_modeless` leaves the hand to the spring, which shows its pull pose ("pinch") at the grabbed edge, dipped up to 0.35 m with the pull. On let-go the spring clears only its own poses, so a shake's hand is not cut off.
- **Presses and the camera** behave as for the land spring: a new press on the land or the rim lands a springing range first; the camera is not blocked.

### Limits and open points

- **One form.** The range is the ridge form (one serrated crest along the edge). A true range of several peaks, or the biome's form, is open.
- **Where it rises** is fixed by the edge: the crest line is 5 to 6.5 m in from the grabbed edge, its middle at the grab (kept so its ends stay on the plate). Rising at the plate's middle, or where the pointer is when you let go, are alternatives to try on screen.
- **The edge itself does not move.** The sag is in the land, a few metres in; the lip and the walls stay put, because the plate's last metres are faded in every shape (the walls do not follow the ground). Tipping the whole block toward the grabbed edge would read more like a trampoline and is untried.
- **No pull up from the edge.** Up is the flip. A basin from the edge is not offered.
- The wall hand (palm to the wall, feature/modeless-wall-hand) could replace the pinch while pulling from a wall once merged.
- **Unverified on screen:** how the sag reads, whether a trough is the right tension, the hand's pose at the edge, the ridge's size, and how the whole thing feels.

### Probe

`tools/probe_edge_spring.gd` (run with `-- --modeless`, `--fixed-fps 60`) proves, in the real product scene with synthesized input, from the lip in the overview and from the +z wall in a low close view:

- a downward rim drag decides "spring", does not flip and does not turn the world;
- the land sags with the pull (0.17 m a third of the way, 0.40 m at 0.67 of the cap) and the sag is capped; the hand pinches;
- let go, it springs; the highest rise (6.4 to 6.6 m at 0.67 of the cap) is 6 m in from the grabbed edge and near the grab along it; the far side of the plate is untouched; `sprung("range", size)` is emitted;
- one undo step, and one undo restores the heights exactly;
- a tiny pull (14 px) decides "spring" but keeps nothing and adds no undo step;
- a sideways drag still turns and draws no spring; an upward drag still flips.

