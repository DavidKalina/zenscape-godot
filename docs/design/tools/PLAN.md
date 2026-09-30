# Shaping tools: paddle, chisel, wire and hammer

The tool roll (docs/design/materials-tray/HUD-4c.md) holds five shaping tools:
the Hand, and four that were undiscovered silhouettes until they had verbs.
This plan gives them verbs. The user approved the design on 2026-09-30.

## The design

Each tool keeps the Hand's gesture grammar: tap, drag, hold-then-drag, and
Shift for finer. The tool changes what the gestures do. The size pips scale
its reach as they scale the Hand's. Every tool is available once it is built:
it is taken off `UNBUILT`, with no discovery unlock.

| Tool | Tag | Drag | Hold, then drag | Tap | Shift |
|---|---|---|---|---|---|
| Hand | Mould | the thumb: a groove when slow, a rub when fast | the pinch: up raises, down sinks, a horn when tall | a poke that rings out | the palm; a smaller pinch |
| Paddle | Mass | a broad sweep pushing earth ahead and aside, leaving a long soft trough with a ridge on either bank | a wide round-shouldered swell (several times the pinch's radius), up or down | a broad pat that flattens | a narrower blade |
| Chisel | Cut | a flat shelf at the press's height with a steep face downhill (terraces) | a flat-topped mesa or a sunk pit with cliff walls; its height follows the pointer | a step or notch | shallower |
| Wire | Slice | a narrow deep gorge, near-vertical walls, rock painted on the walls | slices a hilltop off level at the pointer's height | (none yet) | shallower |
| Hammer | Break | (none yet) | (none yet) | cracks rock, lowers peaks, spills scree to the angle of repose, as height changes only (no loose props) | smaller |

The land's points are scattered 0.45 to 0.75 m apart, so a cliff is one facet
row at its sharpest. That is accepted.

Nothing draws a ground outline under the pointer from here. The faint ground
marks under the pointer are a separate piece of work (`scripts/ground_marks.gd`,
another branch).

## Order

1. The seam, and the Paddle. **Done** on `feature/hud-linen`.
2. The Chisel.
3. The Wire.
4. The Hammer.
5. A Blender pass for all four tools together: models for the props, and grip
   clips for the hand.

Steps 2 to 4 are independent. Each is one new script in `scripts/clay_tools/`
plus its entry off `UNBUILT`, so they can be built in parallel. `UNBUILT` is
one line in `scripts/tool_roll.gd`, so parallel branches conflict on it; the
merge keeps every built tool off it.

## Stand-in props

Until the Blender pass, the hand holds a stand-in: a few faceted primitives
built in code, as the materials' pebbles are (`scripts/hand_materials.gd`
`Clump`). Each tool builds its prop in one function, `build_prop()`, so a glb
replaces the body of that one function later.

- **Faceted.** `ClayTool.part(mesh, colour, at, size)` flat-shades a
  primitive: every face its own normal, like the land's facets and the HUD
  icons' facets. It adds a little emission so the prop reads at night.
- **Tint.** Each prop follows its icon's tint (`scripts/hud_icons.gd`): Hand
  `#e0a07a`, Paddle `#c49a5e`, Chisel `#6f8aa6`, Wire `#b8683f`, Hammer
  `#7a6a5a`. A darker and a lighter tone of it pick out the parts.
- **Tilt.** Each prop leans off upright toward the way the hand is going, as
  the cursor sketches lean: Hand -12°, Paddle -24°, Hammer -30°. The Chisel
  and the Wire are untilted. A negative tilt leans the working end forward
  into the drag, and the handle back. At rest the prop leans across the view.
- **Where it rides.** The clay places the prop each frame. Its grip (the
  prop's origin) sits between the hand's index and thumb tips (`god_hand`
  `hold_at(true)`). Its working end points down local -Y, and its broad face
  looks along local +Z, toward the drag. It is sized with the hand, and is
  shown while the hand shows and no material is held.
- **The grip pose.** The hand has no tool clips yet. The gesture `"grip"`
  (`scripts/god_hand.gd` `GESTURES`) borrows the rim grip's clips: curled
  fingers and a hooked thumb, lifted clear of the land. The Blender pass
  gives each tool its own grip.

## The seam

`scripts/land_clay.gd` (the clay) reads the gesture. The tool in hand
(`scripts/clay_tools/<id>.gd`) says what each verb does to the land.

### Registering a tool

A tool is a script at `scripts/clay_tools/<id>.gd`, where `<id>` is its tool
roll id (`chisel`, `wire`, `hammer`). It starts:

```gdscript
extends "res://scripts/clay_tools/clay_tool.gd"
```

It overrides the hooks it needs. Nothing else registers it: `LandClay.set_tool(id)`
loads the script by that path the first time the tool is taken. To make it
selectable, take its id off `UNBUILT` in `scripts/tool_roll.gd`. The roll,
Esc, and "one thing in hand" are already wired (`scripts/hand_materials.gd`
`select_tool`). A new tool should not need to touch `land_clay.gd`.

`scripts/clay_tools/paddle.gd` is the worked example.
`scripts/clay_tools/hand.gd` is the Hand, and the fullest one.

### The hooks

All are on `scripts/clay_tools/clay_tool.gd`, with defaults that do nothing.
`clay` is the LandClay node, and is set when the tool is made. `fine` is
Shift, read when the verb is decided.

| Hook | When | What it does |
|---|---|---|
| `id() -> String` | | the tool roll id |
| `hover_gesture() -> String` | hovering the land | the God Hand's gesture (default `"grip"`; the Hand's is `"pinch"`) |
| `gesture(verb) -> String` | while `verb` works | the God Hand's gesture (default `"grip"`) |
| `pace() -> float` | each drag frame | how fast the gesture's Hold plays (default 1) |
| `worked_as(verb) -> String` | the press ends | the name `worked` reports (default `verb`) |
| `stroke_radius() -> float` | stroke signals | the reach in metres the editor's stroke signals report |
| `turns_lip(verb) -> bool` | laying dirt | whether ground the verb raises shows the pale turned-clay fringe |
| `build_prop() -> Node3D` | the tool is taken | the stand-in prop, or null |
| `prop_tilt() -> float` | each frame | degrees of lean toward the drag |
| `reset()` | each press | forget the last verb's own state; reset `lift` |
| `drag_begin(fine) -> String` | the drag is decided | set up and return the verb's name. The undo step is already open |
| `drag_frame(delta) -> bool` | each drag frame, before its dabs | false holds this frame's dabs back |
| `dab(heights, q: Vector2) -> float` | every `DAB_SPACING` (0.3 m) along the path | write `heights`; return the reach round `q` that may have gone down (for the dirt), or 0 |
| `drag_off()` | the pointer runs off the land | |
| `drag_end() -> bool` | release, after the last dabs | true if it queued more path to lay (`clay.queue_point`) |
| `hold_begin(fine) -> String` | the hold is decided (still for `HOLD_SECONDS`, 0.3 s) | may move `clay.center`; set up, `clay.gather` the points it will move, return the verb's name. The undo step is already open |
| `hold_step(heights, rise: float) -> bool` | each frame held, and once at release | `rise` is the pointer's travel up the screen, in metres standing at `clay.center` (down is negative). Write `heights` from `clay.base`, set `lift`, and return false when nothing changed |
| `hold_end()` | release, or cut short | rock paint, trees sliding off |
| `tap(fine)` | a tap (let go before 0.3 s, moved under 6 px) | anything. To keep a change, call `clay.open_stroke()`, write `clay.editor.data.heights`, then `clay.close_stroke()` |
| `frame(delta)` / `finish()` / `busy() -> bool` | every frame / at once / probes | for anything that runs on after a press (the Hand's poke rings out; the paddle's pat holds the hand down) |

A drag's heights reach the land after each frame's dabs; a hold's after each
`hold_step`. Write only the working copy you are given.

### What the clay gives a tool

| Member | What |
|---|---|
| `center: Vector2` | the plate point pressed (a hold may move it) |
| `base: PackedFloat32Array` | the heights when the stroke opened. Shape against it, so a verb never compounds within a stroke |
| `verb: String` | the decided verb |
| `speed: float` | the drag's pointer speed, px/s over `SPEED_WINDOW` |
| `heading: Vector2` | the drag's direction over its last 0.6 m (zero until then) |
| `size_scale: float` | the pips: 0.6, 1 or 1.5 |
| `gather(at, radius)` | the points within `radius` into `near` (indices) and `near_d` (distances) |
| `fade(i) -> float` | 1 inside, easing to 0 over the plate's last metres (`EDGE`). Multiply every change by it |
| `touch(q, reach)` | marks ground for the settle refresh at release. Call it for everything you move |
| `dirty(q, reach)` | marks ground for bare earth (a drag's `dab` return value does this) |
| `ground_at(p) -> Vector3` | the live ground under a plate point |
| `show_land()` | one light refresh (the clay calls it after dabs and holds) |
| `paint_rock(at, reach, height, form)` | the range's granite on the steeps round `at` (mountain_forms `_rock_tint`), measured against `height` |
| `shake_trees(at, reach, area := Rect2())` | trees on moved ground that cannot hold it slide to its foot; `touched()` gives a drag's whole area |
| `stir(at, radius, strength)` | a tap disturbs the life round it |
| `open_stroke()` / `close_stroke()` | one undo step, for a tap that keeps its change |
| `queue_point(p)` / `path_end()` | add to the drag's path |
| `hand_gesture(gesture, point, again)` / `hand_set` | drive the God Hand directly |
| `FLOOR`, `EDGE`, `PLATE_HALF`, `CELL` | the sink floor (-1.2 m), the edge fade, the rim, the lookup cell |

The clay also owns the dirt tint (`DIRT` to `DIRT_DEEP`, laid by how far each
0.5 m tint cell went down), bare ground turning hand-made at release, and the
`worked(verb, kept)` signal.

### Rules a tool keeps

- Shape toward a target from `clay.base`, and never past it. Going over the
  same ground again within a stroke must not compound it; a new stroke may.
- Clamp heights to `NativeTerrainData.MIN_HEIGHT` and `MAX_HEIGHT`. Sinks stop
  at `clay.FLOOR`.
- Multiply every change by `clay.fade(i)`, so the plate's outline stays clean.
- `touch` everything you move. The settle refresh covers only the touched area.
- Paint rock only at release (`hold_end`, `drag_end`, or inside a tap's
  stroke), so the undo step takes it back.
- Check headless with a probe in the style of `tools/probe_tool_paddle.gd`:
  one undo step per verb, and one undo restoring the heights exactly.

## The Paddle

`scripts/clay_tools/paddle.gd`.

- **Sweep** (drag). It aims for a trough `SWEEP_DEPTH` (0.45 m) deep on the
  line and `SWEEP_HALF_WIDTH` (2.2 m) either side, on a raised cosine: no floor
  and no edge. A ridge up to `SWEEP_RIDGE` (0.38 m) stands from the trough's
  edge out to `RIDGE_OUT` (2.2) half-widths, on a sin² profile. The ridges hold
  about the earth the trough takes out. Both follow the ground across.
  - Each dab moves `SWEEP_STEP` (half) of the way to that shape, and never
    past it.
  - Ground the trough has taken is never raised again, so a curved sweep leaves
    its ridges outside the curve. The last dab's ridge ring stays in front, as
    earth pushed ahead.
  - The trough turns to bare earth where it goes 4 cm or more down, and the
    ridges get the pale turned-clay fringe. Trees on the swept area that cannot
    hold it slide off at release.
- **Swell** (hold, then drag). The rise is `1 - smoothstep(0, 1, t)` over
  `SWELL_RADIUS` (6.5 m, three times the pinch's opening radius): level on the
  crown, steepest halfway out, easing into the ground. Its crown follows the
  pointer, as the pinch's summit does, between -3 and +5 m. It never grows a
  horn or takes rock. Trees slide off at release.
- **Pat** (tap). Within `PAT_RADIUS` (3 m), each point moves `PAT_STEP` (0.7)
  of the way to the patch's weighted mean height, fully inside 40% of the
  radius and easing to the rim. It flattens bumps and keeps the patch's earth.
  It is one undo step. The hand shows the Press pose for 0.25 s, and the life
  round it is stirred.
- **Shift** halves every width (`NARROW`). The pips scale every width.
- **Verbs reported:** `sweep`, `swell`, `pat`, or `narrow_sweep`,
  `narrow_swell`, `narrow_pat` with Shift.
- **Prop:** a hexagonal handle (`#9c7444`) under the grip, with a pommel and
  a collar (`#d9b57e`). An octagonal blade in `#c49a5e` sits 0.62 m wide,
  0.72 m tall and 0.1 m thick, tapering a little to its foot. It tilts -24°.

### Checked headless

`tools/probe_tool_paddle.gd`:

```sh
godot --headless --fixed-fps 60 --path . -s res://tools/probe_tool_paddle.gd -- --modeless --no-title
```

It drives the product scene with synthesized input through `hand_reach`. It
checks the following:

- The pocket takes the paddle, the hand's gesture over the land is `grip`,
  and the prop is built in the icon's tint.
- The pat takes the roughness of the probe's roughened ground from 0.060 to
  0.024 and keeps the mean height to the millimetre.
- The sweep leaves a trough 0.36 to 0.39 m deep all along the path, with
  ridges 0.30 m or more on both banks.
- Shift lowers 69 points against 166, and the widest pip 260.
- A 60 px hold-and-drag raises a 4.2 m swell over 309 points, standing at
  0.79 of the crown 0.3 of the way out, the crown within 1.3 px of the
  pointer. Down sinks it, and Shift moves 77 points.
- Each verb is one undo step, and one undo restores the heights exactly.
- Esc gives back the Hand, whose drag digs a groove again.
- Taking a stone puts the paddle back.

### Unverified

Nothing has been seen on screen:

- how the sweep's trough, ridges and dirt read from the default camera
- whether the swell's crown and shoulders read as "mass" beside the pinch's
  horn
- whether a 0.45 m trough reads from 58 m out (the Hand's groove needed 1 m)
- the borrowed Rim grip over open land
- where the prop actually sits in the hand, its lean, and its size
- whether the flat-shaded parts read as the icon's facets

## The Chisel

`scripts/clay_tools/chisel.gd`. Built on `feature/tool-chisel`.

It is the only tool that makes crisp rock. Every verb leaves a dead-level
flat and a steep face. The faces take granite and the flats stay ground.

- **Crispness.** The chisel never eases a face. A point is either on the flat,
  at exactly its level, or off it. The face is whatever row of triangles spans
  the step, one facet row, as the plan accepts. Flats are written level
  outright, not moved a share per dab, so going over them again cannot
  roughen them.
- **Shelf** (drag). The shelf is level at the height of the press for
  `SHELF_HALF_WIDTH` (1.2 m) either side of the path, cut or filled to get
  there. On the downhill side only, a face drops `FACE_DROP` (1 m) to a bench
  `BENCH` (0.6 m) wide. A `RAMP` (1.2 m, smoothstep, soil) then climbs back to
  the ground, so the reach is 3 m either side. The bench and ramp only cut.
  The uphill side is never touched, so on a slope the cut into the hill
  stands behind the shelf as a riser.
  - The downhill side is the lower ground 2 m either side of the first
    stretch. On the flat (under 0.2 m of fall), it is the side toward the
    camera, so the face is seen.
  - Each dab writes the stretch from the last dab, squared off 0.1 m past
    either end. The dabs overlap and the stroke ends square.
  - If the ground on the line falls 1.2 m under the shelf, or climbs 2 m over
    it, the shelf steps by whole drops. A stroke down a hill leaves a flight
    of steps, not a causeway.
  - A stroke pressed on a bench cuts the next terrace down.
- **Mesa or pit** (hold, then drag). The outline is a straight-sided polygon
  of 6 to 8 corners, seeded by the spot, `MESA_RADIUS` (2.5 m) ±18%. Inside
  it the top is written flat at the spot's height plus the lift, which
  follows the pointer 1:1 between -3 and +6 m. Outside, the ground is
  untouched, so the wall is one facet row. Down makes a pit: its floor is
  flat at the lift and it only cuts, and the clay's `FLOOR` holds. Below
  0.3 m of lift the flattening eases in, so a hold let go without moving
  changes nothing.
- **Notch** (tap). A square `NOTCH_HALF` (0.8 m) half-side is knocked
  `NOTCH_DEPTH` (0.6 m) down to a flat floor. The square is set to the fall
  line, or to the view's right on the flat, as the ground mark's square is.
  It only cuts, so on a slope it is a step. It is one undo step. The hand
  shows the Press pose for 0.2 s, and the life round it is stirred.
- **Shift** is `SHALLOW` (half) of every depth and of the hold's travel. The
  extent stays the same.
- **The pips** scale every width, never a depth.
- **Verbs reported:** `shelf`, `mesa`, `notch`, or `shallow_shelf`,
  `shallow_mesa`, `shallow_notch` with Shift.
- **Rock.** At release, every tint cell the stroke moved (4 cm or more) takes
  mountain_forms' granite, weighted by its slope alone: from 0.6 rise/run to
  full at 1.2, read 0.25 m either side. Rock covers the cut's own bare earth,
  because a face is stone. There is no summit share, so mesa tops and
  shelves stay ground.
- **Prop:** a chisel hanging from the grip, made of an octagonal wood handle
  (`#9c7444`), steel ferrule and bolster, a square shank (`#4f6680`) and a
  wedge blade in `#6f8aa6` with its edge across local x. Beside it on +x
  stands a mallet, head up in `#6f8aa6`, with a wood handle, as the icon
  draws them. It is untilted.

### A seam gap

`LandClay.paint_rock` paints only ground a stroke raised (mountain_forms
`_rock_tint` skips cells under 4% of `height` up). Most of a chisel face is
lowered ground, so it would stay dirt. The chisel therefore lays the granite
itself (`chisel.gd` `_paint_faces`), inside the stroke, so the undo step takes
it back. `land_clay.gd` was not changed. If the Wire or the Hammer needs rock
on cut ground too, move `_paint_faces` to the clay as a `paint_faces(region)`
hook.

The notch also calls the clay's `dirty` and `_dirt()` itself, because a tap
lays no dirt by itself, so the notch floor turns to bare earth as a shelf does.

### The ground mark

The placeholder square (ground_marks `CHISEL_HALF`, 0.8 m) matches the
notch exactly. The shelf levels 1.2 m either side of the line and reaches
3 m on the downhill side. The mesa's outline is 2.5 m ±18%, up to 2.95 m.
All of these scale with the pips.

### Checked headless

`tools/probe_tool_chisel.gd`:

```sh
godot --headless --fixed-fps 60 --path . -s res://tools/probe_tool_chisel.gd -- --modeless --no-title
```

The world differs a little from run to run. The numbers below are from one
run.

- The pocket takes the chisel. The hand grips it, and the prop is built
  faceted in the steel tint, untilted.
- The shelf is level to 0 mm along its line, at the press's height. Its
  face drops 0.91 m. Its steepest facet across is 1.48 rise/run, against
  1.06 for the Hand's groove banks. 12 tint cells on the face are granite,
  and the line stays ground.
- Shift drops 0.44 m. The widest pip moves 232 points against 144, and
  drops 1.00 m.
- A second stroke pressed on the bench below cuts a level 0.81 m under the
  first, with its own 1 m face.
- A 60 px hold raises a 4.27 m mesa. Its top spread is 0 mm, it stays within
  2.4 px of the pointer, and its steepest wall facet is 8.35 rise/run. 58
  cells on the walls are rock, and none on top. Down sinks a 1.67 m pit with
  a flat floor, held by `FLOOR`. Shift gives 2.13 m. The smallest pip moves
  18 points against 52.
- The tap notches 0.60 m over 7 points and raises none. Shift notches
  0.30 m.
- Each verb is one undo step, and one undo restores the heights exactly.
- Esc gives back the Hand.

`tools/probe_tool_paddle.gd` and `tools/probe_hud_bars.gd` checked "chisel
is not built". They now check that every tool still on `UNBUILT` is
undiscovered.

### Unverified

Nothing has been seen on screen:

- whether a one-facet-row face reads as a cliff, or as a stretched smear,
  from the default camera
- whether a tall mesa's walls, 4 m in one facet row, shade acceptably
- how the rock on the faces and the bare earth on the shelves read together
- whether the camera-side face on flat ground is the right default
- the notch at 0.8 m, which may be too small to see from 58 m out
- where the chisel and mallet sit in the grip, their size, and whether the
  mallet beside the chisel reads
