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

## The Hammer

`scripts/clay_tools/hammer.gd`. A rock hammer with one verb, the blow; the
gestures decide where the blows land.

- **What is rock.** A blow cracks where the land already knows rock at the
  spot, any of three ways: the tint layer carries a rock's paint (weight 0.4
  or more and not the clay's earth colours: a range's granite, a pinch's
  flank, earlier scree); the ground is at least 0.85 of the biome's
  `rock_slope`, the gradient the terrain paints rock above; or it stands in
  the rock band 1.8 m under the snowline.
- **Crack** (tap on rock). Within `CRACK_RADIUS` (1.8 m), rock more than
  `CRACK_DEPTH` (1.4 m) over the level is broken off: level is the highest
  point there, less the depth. The whole cut applies inside 35% of the
  radius and eases to the rim. Each point loses a seeded 0.72 to 1 share of
  it, so the scar is rough. A peak loses its top, and a cliff's lip is
  knocked off. The scar is painted a fresh pale grey (`#c4beb2`, up to 0.65).
  - **Scree.** Each broken piece walks out of the scar, to the lowest
    neighbour farther from the blow. Then it goes down the fall line while
    the drop is steeper than `REPOSE` (0.7, tan 35°), and lies there as loose
    rock. The loose rock then settles: wherever it stands more than 0.7 per
    metre over a neighbour, half the excess runs downhill. Bedrock never
    moves, so a cliff stays a cliff. The land's points are taken as equal
    areas, so the heights' sum is kept exactly.
  - Scree is painted in one of four pale broken-rock tones (`#bdb6a8`,
    `#aea799`, `#c9c2b3`, `#b3aa98`), up to 0.9. It covers what was under it
    by its thickness, fully from 0.15 m. A cell at least half scree loses
    its grass and is marked hand-made, as the clay's dug earth is.
  - Trees on moved ground that cannot hold it slide off (`shake_trees`
    within the crack radius plus 8 m).
- **Knock** (tap on anything else). A dent `KNOCK_DEPTH` (8 cm) deep over
  `KNOCK_RADIUS` (1 m), on a `(1-t²)²` profile. No scree and no paint.
- **The swing.** A tap winds the head back 38° over 0.09 s, then brings it
  down to -14° over 0.05 s. The blow lands then, 0.14 s after the release, or
  at once if anything ends it first (`finish`). The head recoils with one
  bounce over 0.24 s, and the hand shows the Press pose for 0.2 s. The
  swing turns a pivot inside the prop (`Swing`), so the clay's placement is
  untouched.
- **Drag.** The blow repeated every `STRIKE_GAP` (1.6 m, about a crack's
  radius) along the path. Each blow is a crack or a knock, by the ground it
  lands on, so a drag works a ridge line down. The whole drag is one undo
  step. Blows land on the live ground, not on `clay.base`, because scree
  from the last blow is part of what the next one strikes. Blows at that
  spacing barely overlap.
- **Hold.** A deliberate blow that lands at release, with nothing
  following the pointer while held; the head waits wound back. The design
  gave the hammer no drag and no hold. These are the blow again, not new
  verbs. A hammer has no pinch, and a slow press or a sweep should strike,
  not vanish into nothing.
- **Shift** halves the radius and the depth (`FINE`). The size pips scale
  both, so a bigger blow reaches further into the rock.
- **Verbs reported:** `crack`, `knock`, `strikes`, or `fine_crack`,
  `fine_knock`, `fine_strikes` with Shift.
- **Radii for the ground mark** (`ground_marks.gd` `HAMMER_RADIUS`, now a
  0.9 m placeholder): the crack reaches 1.8 m × the pips (0.9 m with Shift),
  and the knock 1.0 m. Scree runs on downhill as far as the ground stays
  steeper than repose; the probe's 8 m horn spilled it 4.9 to 5.9 m.
- **Prop:** a hexagonal wood handle (`#9a7550`) with a pommel. Across its
  foot is an octagonal head in `#7a6a5a`, with a flat face (`#9a8b7a`)
  toward the drag, a four-sided pick behind, and a dark collar (`#584b3f`).
  It tilts -30°.

### Checked headless

`tools/probe_tool_hammer.gd`:

```sh
godot --headless --fixed-fps 60 --path . -s res://tools/probe_tool_hammer.gd -- --modeless --no-title
```

- The pocket takes the hammer, the hand grips it, and the prop is built in
  the icon's tint.
- On grass a tap is a knock, 6 to 8 cm deep over 6 points, with nothing
  raised. The smallest pip moves 1 point.
- The Hand's pinch raises an 8.1 to 8.5 m horn with granite paint. A tap
  just under its tip is a crack:
  - The summit drops 1.0 to 1.3 m.
  - Scree covers 10 to 19 points, down to the horn's foot, 4.9 to 5.9 m
    out.
  - The heights' sum moves 0.0000, and the true volume (a 0.2 m grid)
    changes by at most 0.12 m³.
  - The steepest scree edge is 0.707, against a repose of 0.70.
  - 5/5 and 8/9 of the thick scree points are painted scree.
  - The blow lands after the wind-up, not on the release.
- Shift takes 0.51 to 0.64 m off the top against 1.02 to 1.08 m. The widest
  pip takes 1.53 to 1.83 m off and moves 33 to 58 points, against 16.
- A drag strikes along its path in one undo step. A hold changes nothing
  while held and cracks at release.
- Every blow is one undo step, and one undo restores the heights and the
  tint exactly.
- Esc gives back the Hand.

### Unverified

Nothing has been seen on screen:

- whether a 1 m crack off a horn and a few points of scree read from the
  default camera, and whether `CRACK_DEPTH` wants to be larger
- whether the scree tones read as rubble beside the granite, and whether the
  scar's fresh grey reads at all
- whether an 8 cm knock is visible
- the swing, the 0.14 s delay before a tap lands (anticipation or lag), and
  the Press pose on impact
- the prop's proportions, its lean and where it sits in the hand
