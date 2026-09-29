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
- a left land press emits `land_pressed`, `land_dragged`, `land_released`, does not turn, paints nothing (no undo step, no height change);
- a fast right drag tilts and looks round without changing time, the room or the spin.

`tools/probe_wall_grab.gd` (same flags) takes a low, close camera facing a wall and proves the wall's middle is rim, reaches the point under the pointer, shows the rim grip stood out from the wall, turns the world with the grabbed point within a few pixels of the pointer, and decides the flip from an upward drag.

## Void slice: the ever-present hand and the snap

Branch `feature/modeless-void`. Checked headless only (`tools/probe_void_snap.gd`); nothing has been seen, heard or felt on screen.

### Try it

Run the product scene with `-- --modeless`.

- **Point at the sky**, or anywhere off the diorama. The hand floats there, half upright with its fingers loosely curled, and now and then its thumb rubs its middle fingertip. Over the land it readies a pinch and on the lip it takes the rim grip, as before. Over a panel it goes.
- **Click the sky.** The hand snaps its fingers and it is night; click again and it is day. The cut is instant.
- **Shift-click the sky.** The snap steps the golden hours: dawn, noon, dusk, night, dawn.
- **Press the sky and drag.** Nothing happens: the loaded hand relaxes and no snap fires.
- **Right-drag, scroll or pinch.** The hand fades while the camera moves and comes back when it stops.

### How it works

- **The void.** A pointer that is in the world (`pointer_in_world`) but reaches no rim or wall, has no land under it and no prop, tree or resident is in the void (`hand_reach.void_at`, hover zone `"void"`). The hand stands on the pointer's ray `VOID_DEPTH` (0.8) of the camera's distance to its pivot out, and never nearer than `VOID_NEAR` (5 m). That is about the size the hand has over the middle of the land, a touch bigger, so it does not jump in size as the pointer leaves the land; at the overview (59 m) it is 47 m out. The sun grab's fixed 12 m made the 2.5 m hand fill a fifth of the screen.
- **The poses.** The god hand gestures `"void"` (VoidIn, VoidHold, VoidOut) and `"snap"` (SnapIn, SnapHold) turn the hand square to the camera, as the sun's Reach does, and float free (they lean into the pointer's way; no tilt, no lift). `docs/scenic/god-hand.md` has the clips.
- **The click.** A left press in the void is held by the hand (`holding == "void"`) and loads the snap: the hand plays SnapIn and holds it. If the pointer wanders more than `CLICK_PIXELS` (6 px) the press is a drag: the hand relaxes back into VoidHold and the release does nothing. A release inside that is a click: `fire_snap(shift)` changes the hour and the hand plays SnapOut, the slam and its follow-through, back into VoidHold. The cut and the slam start on the same frame. There is no time limit: holding the loaded snap and letting go is still a snap.
- **The hours.** `scripts/void_snap.gd`. Day is the sun above the horizon. From day a snap lands on mood_look's Night (phase 0.035, just after midnight, the moon high); from night on its Morning (0.345). Shift steps to the nearest of Dawn 0.275, Midday 0.47, Dusk 0.705 and Night 0.035 ahead of the hour now. The clock is wound forward to it, as a spin winds it (the day moves on; nothing runs backwards). The weather is not advanced.
- **Instant.** The blend is 0 s. Everything that smooths the hour between the clock and the screen is bypassed for a snap: a mood cross-fade in flight is landed first (`finish_fade`, else it drags the old hour back over 1.2 s); the N key's easing (`skip_to`) is dropped by setting the time outright; the celestial rig is rebuilt at once (`update_rig`), so the lights and every sky, fog and night global are the new hour's that frame; and the sky's radiance map, which refreshes over several frames (`PROCESS_MODE_INCREMENTAL`), runs in real time for 0.3 s so the wet-sheen reflections follow. Everything else that reads the hour (fireflies, the display fog colours, the look pass, the cricket and frog beds) already follows it every frame.
- **Audio.** The cricket and frog beds follow daylight every frame, so they switch at once. A bird call from the wrong half of the day (a song after a night snap, an owl after a day snap) fades out over half a second (`nature_audio.snap_to`), and the new half's first call comes within a few seconds (an owl in 1.5 to 4 s, a song in 0.5 to 2 s). There is no snap sound yet.
- **Pins.** As for a spin: a clock that was running keeps running from the new hour; a held clock is pinned again at it (`mood_look.pin_hour`, a held hour).
- **The camera fades the hand.** `hand_reach.camera_moving()` is true during a right drag and while the camera's view still turns or zooms faster than 0.05 rad/s (or log-distance/s) or its pivot slides faster than 0.15 m/s (a fling, a zoom, a double-click's glide). A turn or spin of the world is not the camera moving, nor is a followed creature carrying the pivot. While it is true the hover sets `god_hand.held_off` and the hand fades out as it stands (keeping its pose) and back in when the camera stops, at the hand's usual fade (0.25 s). A hold (rim, land, flip, void) keeps the hand.
- **Hint.** Over the void the hint line reads "Click the sky to snap day and night · Shift-click steps dawn, noon, dusk, night" until two snaps have been made.
- **Signals.** `hand_reach.snapped(phase, step)` after each snap; `hand_reach.snaps` counts them.

### Limits and open points

- Nothing has been checked on a GPU: the hand's size and pose in the sky, the snap's read, the cut, and the reflections catching up are all unseen. Headless has no renderer, so the radiance switch is only checked as a setting.
- The snap itself has no sound; the nature beds and calls are the only audio that changes, and they are unheard.
- Shift + sideways rim push (turn without time) is the edge slice's.
- Headless has no pointer, so probes set `hand_reach.pointer_override` for the hover.
- Clicking the sky no longer lets go of a hover as the rim slice's probe expected: over the sky the hand stays. `tools/probe_modeless_rim.gd` and `tools/probe_diorama_flip.gd` now expect the void pose where the pointer is in the sky.

### Probe

`tools/probe_void_snap.gd` (`--headless --fixed-fps 60 ... -- --modeless`) on the product scene: the glb has the six clips; the sky is void and the land's middle is not; hover there takes the void pose and plays the void clips, the hand shows at the void depth with its point under the pointer; over a panel the hand lets go and hides; a press loads the snap, and the release cuts to night the same frame (phase, `zs_night`, key light energy and `zs_sky_up` all change), the day moves on, radiance runs in real time and goes back, the hand plays SnapOut and returns to VoidHold; a running clock keeps running unpinned; a second click is day; a held clock is pinned at the new hour; a mood fade in flight is landed; Shift-clicks step 0.275, 0.47, 0.705, 0.035, 0.275; a drag relaxes the hand and does not snap; a right drag fades the hand, which comes back once the camera stops; land and rim presses are as before and do not snap.
