# Shaping tools: paddle, chisel, wire and hammer

The tool roll (docs/design/materials-tray/HUD-4c.md) holds five shaping tools:
the Modeller (once the Hand, see "The Modeller"), and four that were
undiscovered silhouettes until they had verbs.
This plan gives them verbs. The user approved the design on 2026-09-30.

## The roll, revised (2026-10-02)

The user played the branch and found it solid but not as fun as it could
be: too many tools making the same shapes (a basin from four tools, hills
from three, a range from two), and the Wire named for how it works where the
Mountain and the Hills are named for what they make. The decision:

- **One landform, one gesture, and the gesture fits the shape.** Mountains
  are pulled up, ravines are drawn, hills are scrubbed in. Drawing a line
  and watching the land form along it was the most fun on the branch, but
  drawing a mountain range was not as good as pulling one up, so the line
  stays with the shapes that are lines.
- **Fewer tools, none overlapping.**

| Tool (id) | Tag | Gesture | Makes |
|---|---|---|---|
| Modeller (`hand`) | Mould | as before, all small | the fine tool for the water's work: stream beds, notches, spillways, a pond's lip. Its pinch rises at most 1.5 m over 2.4 m and never horns (it was 8 m over 5.6 m, a mountain); the groove is 0.6 m deep and 1 m half-width (was 0.75 and 1.35); the palm 1.5 m (was 2) |
| Hills (`hills`) | Roll | scrub | rolling hills, unchanged |
| Mountain (`mountain`) | Peak | pull up; up and sideways | a peak; a range, unchanged. It only builds up: a pull down does nothing |
| Crater (`crater`, new) | Hollow | pull down | a crater: a level floor following the pointer and a thrown-out rim (`scripts/clay_tools/crater.gd`, the Mountain's pull turned over) |
| Ravine (`wire`) | Carve | draw a line; draw a loop | a gorge along the line; a lake basin inside the loop. No fan: a press is a drag from the start |
| Chisel (`chisel`) | Cut | as before | mesa, shelf, notch, and the **Slice**, moved from the Wire |
| Paddle (`paddle`) | Smooth | drag; tap | Plane and Pat only: the tidy-up tool |

Cut: the **Bowl** (off the roll; Ravine's loop and the Mountain's crater make
its basins; `scripts/clay_tools/bowl.gd` stays for the classic shell), the
Wire's **Range**, **Hill**, **Trees** and **Flowers** (the Mountain, the
Hills and the seed painting cover them), the Paddle's **Swell** and
**Sweep** (the Hills and the Ravine). The Wire keeps its id `wire`, its
script and its prop, so probes, sounds and the ground marks read as before;
only its label ("Ravine · Carve") and icon changed.

The roll's order is now Modeller, Hills, Mountain, Crater, Ravine, Chisel,
Paddle: makers first, then cutters, then tidying.

After playing it (the same day): the Hammer is unnecessary, and a crater
wants its own tool. The crater first went on the Mountain's pull down; it
moved to the Crater, which took the Hammer's place, and the Mountain went
up-only. The Hammer is off the roll (`scripts/clay_tools/hammer.gd` stays,
unreached, as the Bowl's does; its probe is gone, and the mesa badlands
landscape breaks its mesas with the Chisel instead).

Water level (the user's next question: a waterfall filling a ravine, a notch
at the rim letting it out, an equilibrium) is left for later. The live water
already holds a basin to its rim's lowest point and drains over the plate's
edge (docs/scenic/water-flow.md).

## The Island (2026-10-03)

With lakes in (the Crater's Draw and the can), the user wanted little islands
with trees on them. Pulling one up with the Modeller meant guessing how far
the water's surface stood over the press, and there was no easy way to grow
one. The **Island** (`island`, tag Isle, after the Crater) builds to the
water, not to the press, and has a fan of two modes:

- **Draw:** draw the shore and let go: the land inside rises to a beach at
  the drawn line and a low crown, the bed shelving down outside it.
- **Spread:** scrub to push land out from an isle or a shore, to a flat top
  just over the water; it cannot overshoot.

Neither lowers ground, so drawing or spreading over an isle extends it. The
lake keeps its level: the water the new land displaces is taken away
(`_keep_level`), rather than lifted with the bed and spilled over the rim.
Probe: `tools/probe_island.gd`.

The sections below are the design as first built; where they describe the
cut verbs they are history.

## The design

Each tool keeps the Hand's gesture grammar: tap, drag, hold-then-drag, and
Shift for finer. The tool changes what the gestures do. The size pips scale
its reach as they scale the Hand's. Every tool is available once it is built:
it is taken off `UNBUILT`, with no discovery unlock.

| Tool | Tag | Drag | Hold, then drag | Tap | Shift |
|---|---|---|---|---|---|
| Modeller (id `hand`; was the Hand) | Mould | the thumb: a groove when slow, a rub when fast | the pinch: up raises, down sinks, a horn when tall | a poke that rings out | the palm; a smaller pinch |
| Paddle | Mass | a broad sweep pushing earth ahead and aside, leaving a long soft trough with a ridge on either bank | a wide round-shouldered swell (several times the pinch's radius), up or down | a broad pat that flattens | a narrower blade |
| Paddle's Plane (a fan mode) | Mass | levels the ground to the press's height and lays it afresh as grass, earth, rock or sand (the swatch in hand) | (drag only) | (drag only) | a narrower blade |
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
- **Tint.** Each prop follows its icon's tint (`scripts/hud_icons.gd`): Modeller
  `#e0a07a`, Paddle `#c49a5e`, Chisel `#6f8aa6`, Wire `#b8683f`, Hammer
  `#7a6a5a`. A darker and a lighter tone of it pick out the parts.
- **Tilt.** Each prop leans off upright toward the way the hand is going, as
  the cursor sketches lean: Modeller -20° (the Hand's was -12°), Paddle -24°,
  Hammer -30°. The Chisel
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
| `mark_size() -> Vector2` | hovering the land | the ground mark's half extents in metres at the middle pip (x along the mark's axis, y across): what the hover stands for, usually the tap's reach. Zero (the default) keeps `ground_marks.gd`'s placeholder |
| `turns_lip(verb) -> bool` | laying dirt | whether ground the verb raises shows the pale turned-clay fringe |
| `dirt_share(verb) -> float` | laying dirt | how much of the clay's bare earth ground the verb takes down shows, 0..1 (default 1, the full dirt). Below the clay's `DIRT_BARE` (0.5) the grass stays alive. The Paddle's sweep gives 0.2, so it stays a grassed valley beside the Modeller's bare-earth groove |
| `build_prop() -> Node3D` | the tool is taken | the stand-in prop, or null |
| `prop_tilt() -> float` | each frame | degrees of lean toward the drag |
| `reset()` | each press | forget the last verb's own state; reset `lift` |
| `drag_begin(fine) -> String` | the drag is decided | set up and return the verb's name. The undo step is already open |
| `drag_frame(delta) -> bool` | each drag frame, before its dabs | false holds this frame's dabs back |
| `dab(heights, q: Vector2) -> float` | every `DAB_SPACING` (0.3 m) along the path | write `heights`; return the reach round `q` that may have gone down (for the dirt), or 0 |
| `drag_off()` | the pointer runs off the land | |
| `drag_end() -> bool` | release, after the last dabs | true if it queued more path to lay (`clay.queue_point`) |
| `drag_running() -> bool` | after `drag_end`, each frame | true while the drag still works the land after release (the Wire's cut drawing through). The clay keeps the undo step open, calls `frame`, and closes it once this is false; `finish()` must land the rest at once (default false) |
| `hold_begin(fine) -> String` | the hold is decided (still for `HOLD_SECONDS`, 0.3 s) | may move `clay.center`; set up, `clay.gather` the points it will move, return the verb's name. The undo step is already open |
| `hold_step(heights, rise: float) -> bool` | each frame held, and once at release | `rise` is the pointer's travel up the screen, in metres standing at `clay.center` (down is negative). Write `heights` from `clay.base`, set `lift`, and return false when nothing changed |
| `hold_end()` | release, or cut short | rock paint, trees sliding off |
| `hold_tracks() -> bool` | the pointer moves while held | true and the clay picks the ground under the pointer's sideways travel into `clay.hold_point` (default false: nothing is picked). The Mountain's range runs to it |
| `tap(fine)` | a tap (let go before 0.3 s, moved under 6 px) | anything. To keep a change, call `clay.open_stroke()`, write `clay.editor.data.heights`, then `clay.close_stroke()` |
| `frame(delta)` / `finish()` / `busy() -> bool` | every frame / at once / probes | for anything that runs on after a press (the Hand's poke rings out; the paddle's pat holds the hand down; the Wire's cut draws through). `finish()` runs on an undo, a new press or a change of tool, and leaves what running out would have |

A drag's heights reach the land after each frame's dabs; a hold's after each
`hold_step`. Write only the working copy you are given.

### What the clay gives a tool

| Member | What |
|---|---|
| `center: Vector2` | the plate point pressed (a hold may move it) |
| `hold_point: Variant` | for a tool that `hold_tracks`: the ground under the pointer's sideways travel (plate), picked on the press's row of the screen on the ground as it stood at `base`, so the travel up the screen (the height) does not move it; null until the pointer moves on the land |
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
| `paint_rock(at, reach, height, form)` | the range's granite on the steeps round `at` (mountain_forms `_rock_tint`), measured against `height`. Raised ground only: a cell must stand at least 4% of `height` over `base`, and tall ground takes a summit share |
| `paint_faces(region: Rect2)` | the strata (scripts/strata.gd) on the faces a stroke cut or built inside `region`, a shade darker than flats (`FACE_SHADE`): every tint cell moved at least `FACE_MOVED` (4 cm) either way, weighted by its slope alone, from `FACE_SLOPE` 0.6 to `FACE_WEIGHT` at 1.2 rise/run, read `FACE_REACH` (0.25 m) either side. Each cell takes the stratum at its own height, under the highest ground `FACE_TOP` (1 m) round it, so a wall through the bands is striped and a tall column's face is its granite core. No summit share, so flats stay ground. It covers the stroke's flat earth, so lay the dirt first. The Chisel and the Wire use it |
| `lay_dirt(at, reach)` | the strata now on ground the stroke took down, `reach` round `at`. The clay lays it by itself after a frame's dabs and each hold step; call it when the change landed some other way (a cut written whole at release, a tap's own stroke), before `paint_faces` |
| `shake_trees(at, reach, area := Rect2())` | trees on moved ground that cannot hold it slide to its foot; `touched()` gives a drag's whole area |
| `stir(at, radius, strength)` | a tap disturbs the life round it |
| `open_stroke()` / `close_stroke()` | one undo step, for a tap that keeps its change |
| `queue_point(p)` / `path_end()` / `queued()` | add to the drag's path; its last point; the points not yet laid (all of the path, for a tool whose `drag_frame` holds its dabs back) |
| `hand_gesture(gesture, point, again)` / `hand_set` | drive the God Hand directly |
| `FLOOR`, `EDGE`, `PLATE_HALF`, `CELL` | the sink floor (-1.2 m), the edge fade, the rim, the lookup cell |
| `FACE_SLOPE`, `FACE_REACH`, `FACE_MOVED`, `FACE_WEIGHT`, `FACE_TOP` | `paint_faces`'s slope ramp (rise/run), read distance, least move, full weight and how far it looks for the column's top |
| `strata()` | the world's strata (scripts/strata.gd): `material_at(point, height, surface)` names what the ground is made of there ("topsoil", "clay", "sand", "shale", "bedrock", "rock_core"); `color_at` gives its colour. See docs/scenic/strata.md |

The clay also owns the cut-ground tint, bare ground turning hand-made at
release, and the `worked(verb, kept)` signal. Cut ground shows the stratum it
reached (docs/scenic/strata.md): each 0.5 m tint cell a stroke took down takes
the strata colour at its new height, under the ground it was cut from, at a
weight rising from `DIRT_FROM` (4 cm dug) to full at `DIRT_FULL` (0.45 m),
scaled by the tool's `dirt_share`. So a scrape is topsoil, a groove's bed the
ochre clay, a deep pit sand, shale and bedrock, and a cut into ground standing
2.5 m or more (a tall hill, a mountain) its granite core. The slab's earth
sides paint from the same definition, so a cut at the rim matches the side
beside it.

### Rules a tool keeps

- Shape toward a target from `clay.base`, and never past it. Going over the
  same ground again within a stroke must not compound it; a new stroke may.
- Clamp heights to `NativeTerrainData.MIN_HEIGHT` and `MAX_HEIGHT`. Sinks stop
  at `clay.FLOOR`.
- Multiply every change by `clay.fade(i)`, so the plate's outline stays clean.
- `touch` everything you move. The settle refresh covers only the touched area.
- Paint rock only at release (`hold_end`, `drag_end`, while a drag runs on,
  or inside a tap's stroke), so the undo step takes it back. `paint_rock` is
  for raised ground and `paint_faces` for cut faces.
- Call only the clay's public members (the tables above). A tool that needs
  something the clay keeps private wants a new hook here.
- Check headless with a probe in the style of `tools/probe_tool_paddle.gd`:
  one undo step per verb, and one undo restoring the heights exactly.

## The Paddle

`scripts/clay_tools/paddle.gd`.

- **Sweep** (drag). The landscape-scale cut: a broad, soft, grassy valley,
  where the Modeller's groove is the detail tool's crisp bare-earth line. It
  aims for a trough `SWEEP_DEPTH` (0.6 m) deep on the line and
  `SWEEP_HALF_WIDTH` (2.8 m) either side, on a raised cosine: no floor and no
  edge. A ridge up to `SWEEP_RIDGE` (0.43 m) stands from the trough's edge out
  to `RIDGE_OUT` (2.4) half-widths, on a sin² profile. The ridges hold about
  the earth the trough takes out (0.6 × 2.8 against 2 × 0.5 × 0.43 × 3.92 m²).
  Nowhere steeper than about 0.34 rise/run, so it reads as a swale between
  shoulders, not a trench. Both follow the ground across. (Until 2026-09-30 it
  was 0.45 m deep, 2.2 m half-width, 0.38 m ridges out to 2.2, with full dirt
  and a turned fringe: on screen it read as the groove at another width.)
  - Each dab moves `SWEEP_STEP` (half) of the way to that shape, and never
    past it.
  - Ground the trough has taken is never raised again, so a curved sweep leaves
    its ridges outside the curve. The last dab's ridge ring stays in front, as
    earth pushed ahead.
  - The trough shows only `SWEEP_DIRT` (0.2) of the clay's bare earth
    (`dirt_share`), a faint scuff that keeps its grass, and the ridges get no
    turned-clay fringe. Trees on the swept area that cannot hold it slide off
    at release.
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
- **Plane** (drag; the fan's fourth mode, added 2026-10-01 for "if I have
  rock, I'm stuck with rock"). Flattens ground fast and changes what it is.
  - Each dab moves the ground `PLANE_STEP` (half) of the way to the height
    under the press. This is full inside `PLANE_CORE` (half) of
    `PLANE_RADIUS` (2.5 m) and eases to nothing at the rim. Dabs fall 0.3 m
    apart, so the swath ends level within millimetres, with a smooth
    shoulder.
  - The same falloff relays the surface. A cell's share is the most any dab
    gave it, written over the stroke's starting cover, so a second pass never
    lays it twice. A full share replaces the cell outright (Brush `coat` at
    1): the surface at full weight, over any stored paint (the Brush's rock,
    a range's `paint_rock`, dirt).
  - The surface is one of `SURFACES`, picked on the swatch strip under the
    fan: grass (the default), earth, rock or sand. The strip has no picker
    cell (clay_tool `picks` false). The colours come from Brush
    `surface_colour`: the palette's patched grass or rock, the strata's
    topsoil, or the palette's shore `sand`.
  - Grass brings the cover up to full and leaves the meadow and blades as
    they stood. Earth, rock and sand take cover, meadow and blades away.
    Every cell laid is hand-made.
  - The clay's dirt stays out (`dirt_share` 0), so a cut through a peak
    shows the planed surface, not its strata. Slope rock, which is derived
    from slope when the mesh is built, goes with the slope. Snow still
    settles over paint above the snowline. Trees slide off at release, as
    after a sweep.
- **Shift** halves every width (`NARROW`). The pips scale every width.
- **Verbs reported:** `sweep`, `swell`, `pat`, `plane`, or `narrow_sweep`,
  `narrow_swell`, `narrow_pat`, `narrow_plane` with Shift.
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
  ridges 0.30 m or more on both banks. (Measured on the old 0.45 m profile; not rerun
  since the 2026-09-30 valley change.)
- Shift lowers 69 points against 166, and the widest pip 260.
- A 60 px hold-and-drag raises a 4.2 m swell over 309 points, standing at
  0.79 of the crown 0.3 of the way out, the crown within 1.3 px of the
  pointer. Down sinks it, and Shift moves 77 points.
- Each verb is one undo step, and one undo restores the heights exactly.
- Esc gives back the Hand, whose drag digs a groove again.
- Taking a stone puts the paddle back.

That probe predates the mode fan and now fails its pat, sweep and groove
checks (a press takes the fan's mode, not the gesture's shape). The fan is
checked by `tools/probe_drag_tools.gd`. The Plane is checked by
`tools/probe_paddle_plane.gd`:

```sh
godot --headless --fixed-fps 60 --path . -s res://tools/probe_paddle_plane.gd -- --modeless --no-title
```

- A Mountain peak (about 8 m) is painted rock by the Brush across its
  summit. The Plane then fans out fourth, with four swatches and no picker,
  and grass in hand.
- Drawn flank to flank across the peak, the ground along the laid path ends
  within 5 mm of the press's height. Before the stroke it was up to 7 m off.
- A point 0.75 of the radius off the path is eased 0.5 to 0.8 of the way.
  Ground past the rim is unmoved.
- The summit's rock is replaced by the palette's grass at full weight. Its
  cover is 1, and the cells are hand-made.
- It is one undo step, and one undo restores the heights, tint, grass,
  meadow, blades and provenance exactly.
- With the sand swatch, the palette's sand is laid at full weight, and
  cover, meadow and blades go to 0.

### Unverified

Seen on screen (2026-09-30, tools/landscapes/sweep_vs_groove.gd, an untracked
harness build): beside a Modeller groove, on the flat and down a swell's
flank, the sweep reads as a grassed swale and the groove as a bare-earth
trench, at dawn and noon. From the overview at noon the swale is faint: like
any gentle relief, its facets barely mark it. Not yet seen:

- whether the swell's crown and shoulders read as "mass" beside the pinch's
  horn
- whether water holds to the 0.6 m swale where the 0.45 m trough lost it
- the borrowed Rim grip over open land
- where the prop actually sits in the hand, its lean, and its size
- whether the flat-shaded parts read as the icon's facets

## The Wire

`scripts/clay_tools/wire.gd`. It only cuts; it never raises.

- **Gorge** (drag). The gorge follows the path the pointer drew, bends and
  all. While the wire is drawn nothing is laid (`drag_frame` returns false,
  and the hand follows the pointer). The ground marks' faint line follows the
  drawn path from the press point to the pointer, and it is the whole
  preview. Let go, the wire is drawn through the clay along the path (see
  "Drawn through" below).
  - The path: the pointer's ground points (the clay's `queued`, picked on the
    ground as it stood at the press) are kept once `PATH_SPACING` (0.5 m)
    from the last kept point. The kept points and the pointer's own are
    smoothed `SMOOTH_PASSES` (2) times, each interior point halfway to its
    neighbours' middle, with the ends held. That takes out the hand's jitter
    and keeps a deliberate bend: a right angle is rounded by about 0.4 m
    (`wire.drawn`, the same path the preview line draws).
  - Across: a flat bed `BED_HALF` (1.1 m) either side of the path, then a
    wall to the untouched ground over `WALL_RUN` (0.35 m), under the point
    spacing, so each wall is one facet row. Across is distance to the path,
    so the ends are round and a bend is a round-cornered channel.
  - Along, in arc length along the path: `GORGE_DEPTH` (2.6 m) under the
    ground, and the bed never climbs. From its higher end it falls at least
    `BED_FALL` (2 cm per metre), cutting deeper where the ground rises under
    the path, so water runs its length. Across a dip, the far side is cut to
    the dip's level. Where the path crosses itself, or a point is near two
    stretches of it at a bend, the deeper cut wins. `MIN_HEIGHT` (-1.5 m)
    stops it, so on low meadow (0.1 to 0.3 m) the gorge is 1.6 to 1.9 m
    deep. A drag is a stroke, like the thumb, so the sink `FLOOR` does not
    apply.
  - Drawn through: at release the whole cut is planned once (`_plan`: for
    each point it takes down, the arc length where the wire passes it and
    the height it goes to, sorted by arc length). A head then runs along the
    path at `CUT_SPEED` (8 m/s), the whole taking `CUT_SECONDS` (0.5 to
    2.5 s; a 20 m drag hits the 2.5 s cap). Its pace is half even and half
    smoothstep (`CUT_EASE` 0.5), so it starts with a pull and eases into the
    end. Each frame lays only the cuts the head has passed: those points are
    written, touched and dirtied, and the land is shown through the clay's
    usual light refresh (`show_land`). The prop rides the head (the clay's
    `hand_gesture` point), down in the cut, and goes back to the pointer when
    the stroke closes.
  - As the head passes, the dug ground turns to bare earth (`clay.lay_dirt`).
    Once it reaches the end, the walls take granite on their steeps
    (`clay.paint_faces`) and trees that cannot hold the cut ground slide off.
    The rock waits for the end because it reads the slope round each cell,
    and the head's own round end would read as a wall. A tree sliding mid-cut
    would bump the objects' revision and stop the light refresh. The bed stays
    earth.
  - It is one undo step. The clay keeps the stroke open while the cut runs
    (its `RUN` state, the tool's `drag_running`) and closes it once the cut
    lands. An undo, a new press, a change of tool or Esc mid-cut calls
    `finish`, which lays the rest at once, with the dirt, rock and trees, and
    the stroke closes. The land is the same as an uninterrupted cut's (an
    undo then takes it all back). `wire.cut_gorge(heights, path)` writes the
    same cut at once, and `animate = false` cuts at release with no drawing
    through, for probes.
- **Slice** (hold, then drag). Every point within `SLICE_RADIUS` (7 m) that
  stands above a level plane is cut down to it. The plane starts at the ground
  under the press and follows the pointer's height, as the pinch's summit
  does: dragging down takes more of the hill. It is hard-edged, since a wire
  does not feather. A hill wider than the radius keeps a step at the rim,
  which takes rock on its steeps (`clay.paint_faces`). The sliced top is bare
  earth.
- **Tap:** nothing yet, and no undo step.
- **Shift:** a gorge `SHALLOW` (0.4) as deep, and a slice whose plane follows
  the pointer at 0.4 of the pace, so it takes a thinner cut for the same pull.
  The pips scale the bed's width and the slice's radius. Depth and the wall's
  run hold.
- **Verbs reported:** `gorge`, `slice`, or `shallow_gorge` and `shallow_slice`
  with Shift.
- **Prop:** two hexagonal toggles in `#b8683f`, tapered, with darker end caps
  (`#8a4a2c`). One lies across the grip, and a thin wire (`#e6c3a4`, 12 mm)
  hangs 1.05 m to the other. It is untilted.

### Checked headless

`tools/probe_tool_wire.gd`:

```sh
godot --headless --fixed-fps 60 --path . -s res://tools/probe_tool_wire.gd -- --modeless --no-title
```

- The pocket takes the wire. The hand grips it, and the prop is built in the
  icon's tint, untilted. A tap keeps nothing.
- A 300 px drag bowed 70 px leaves the land untouched until release, and the
  path it drew is the one the cut runs. The figures below are from four runs
  on 2026-09-30, after the path and drawing-through change. The world
  differs from run to run.
  - Its gorge follows the bow: a 19.4 to 19.8 m path of 30 or 31 points, cut
    to the full depth the ground allows all along it (1.94 to 2.23 m at
    most). The straight line's middle, 4.9 to 5.3 m off the path, is not
    dug. The bed climbs 0.000 m, the ground 0.6 m past the rim is unmoved,
    and none is raised. The walls stand at 1.92 to 3.19 (90% to 10% depth).
    0.96 to 0.99 of the wall cells are rock, and 0.96 to 1.00 of the bed
    cells are earth.
  - It is drawn through in 145 to 148 frames at 60 fps, each within 3
    frames of its path's length at 8 m/s (2.4 to 2.5 s). At 0.35 of the
    way, the ground 10% along is 1.52 to 1.96 m down and the ground 90%
    along is untouched. The stroke is still open (no undo step yet), and the
    prop's point is on the head (0.00 m off). The slowest frame while
    drawing is 8.3 to 9.7 ms headless.
  - The land it leaves equals `cut_gorge` along the same path, exactly.
- Cut short at 0.35 of the way:
  - An undo takes it all back, heights and tint.
  - A new press or Esc lands the rest at once. Both leave the same heights
    and the same tint as the full drawing of the same drag, in one undo step.
- An L drag (170 px along the screen, then 140 px down) cuts both legs 1.6 to
  1.9 m deep at their middles, at full depth all along. Its bed never climbs
  round the bend. The corner itself (picked before the cut) is 0.38 m inside
  the smoothed path and 1.89 m deep. 2.25 m out from the corner (2.6 m off
  the path) nothing is dug, and nothing is dug on the straight line across
  the bend, 4.8 to 4.9 m off the path. It equals `cut_gorge` too.
- Shift: the check that it cuts under 0.6 of the full gorge's deepest failed
  in all four runs (1.47 against 2.23, 1.64 against 2.00, 1.44 against
  2.06, 1.27 against 1.94). The straight-line version passed that day, at
  1.12 against 1.94. The check is world-flaky, and it was flaky before this change. The
  bowed path crosses more ground than the old straight line did. Where the
  ground rises along the path, the never-climbing bed deepens the shallow
  gorge, while the full gorge is held by `MIN_HEIGHT`. The widest pip
  lowers 225 to 229 points against 155 to 160, and the smallest 101 to 104.
- A 40 px hold-and-drag on a 3.17 m hill slices it to 0.5 m. All 218 points
  over the plane stand on it, with nothing under it moved. The plane is within
  1.7 px of the pointer. Shift takes 1.07 m off against 2.67.
- Each verb is one undo step, and one undo restores the heights exactly.
- Esc gives back the Hand, which hovers ready to pinch.

### Unverified

Nothing has been seen on screen:

- whether a 1.6 to 1.9 m gorge reads from the default camera, and whether
  its one-facet walls read as a gorge or as a trench
- the granite walls beside the earth bed, and the sliced top's bare earth
- whether water from the shallow-water sim actually runs the bed
- how the drawing-through looks and feels: the head's pace and ease, the
  land's light refresh keeping up with it (headless draws nothing), the prop
  riding down in the cut, and the rock arriving all at once at the end
- the preview line along the drawn path (headless compiles the shader but
  never runs it)
- the prop in the hand: where the grip sits, and whether the 12 mm wire shows
  at all

### Drawing modes (2026-10-02, removed the same day)

Removed by "The roll, revised": the Wire is the Ravine, and only the gorge
and the loop's basin stay. The Slice went to the Chisel.

The user: "I feel like the wire tool is super useful, and almost under
utilized? Would be cool to trace what you want. Same tool. Draw a ravine,
draw a mountain range, draw a hill, hell, maybe draw a line of flowers,
trees, etc." So the drawn path, kept and smoothed as the gorge's is, now
makes what the fan's mode says: **Gorge**, **Range**, **Hill**, **Trees**,
**Flowers**, then the **Slice**. Every drawing mode is built behind the same
running head as the gorge's cut (heights raised with `max` where the gorge
cuts with `min`; plants placed as the head passes them and shown through the
view's paint preview), one undo step each.

- **Range** (`_plan_range`): summits every `RANGE_SPACING` (4 m) along the
  path, each `RANGE_TALL` of `RANGE_HEIGHT` (8.5 m), the crest between them
  at `RANGE_SADDLE` and serrated by noise, a knife-edged profile
  `RANGE_HALF` (3.4 m) either side; an open range tapers at its ends. Let go,
  it takes the mountains' rock (`paint_rock`) and its cliffs the strata.
- **Hill** (`_plan_hill`): a cosine ridge `HILL_HEIGHT` (2.4 m) over the
  ground and `HILL_HALF` (4 m) either side, its crest rolling by `HILL_ROLL`.
- **Trees** (`_plan_plants`): one every `TREE_STEP` (3 m; Shift's hedge
  `HEDGE_STEP` 2 m), up to `TREE_WANDER` off the line, each the kind
  emergence would grow there (`_tree_kind`), through `scripts/tree_paint.gd`'s
  ground rules and room.
- **Flowers**: the flower brush (`scripts/flower_paint.gd`) at `FLOWER_SIZE`
  of its own, drawn along the path in `FLOWER_STEP` steps, each lingering
  `FLOWER_LINGER` s, the wildflower mix (or the world's meadow type).
- **A closed loop** (ends within `LOOP_GAP` 2 m, at least `LOOP_MIN` 8 m
  round) is an outline. The Gorge sinks a level basin inside it, a lake's
  bed `BASIN_DEPTH` (2.4 m) under the outline's lowest ground, its banks
  rising to the outline over `BASIN_BANK` (`_plan_basin`); the Hill raises
  one hill filling it, `MOUND_SLOPE` m tall for each metre its middle lies
  in (`_plan_mound`); the Range stands a ring of peaks. The outline is built
  first, then the inside settles from its edge in (`FILL_PACE`).
- Shift: a shallower gorge or basin, a lower range or hill (`LOW`), a hedge,
  a thinner border. Only the gorge runs on out through the rim.

Checked headless (`tools/probe_wire_draw.gd`, all 47 pass): the fan holds the
six modes, each with an icon; an open gorge cuts as before; a 5 m loop with
the Gorge sinks a basin 2.65 m deep with a level floor and the ground outside
untouched, and the watering can's gush fills it to its brim in 11 s; a Range
along an L raises both legs 5.7-5.9 m, its highest summit 6.6 m,
with nothing off the path moved; a Hill rises 2.2 m; a Hill loop stands 2.4 m
in its middle and 0.9 m 3 m out; a 12 m Trees line plants 4 oaks within
0.2 m of it; a Flowers line 90 flowers within 0.6 m; each one undo step that
one undo takes back exactly. `tools/probe_tool_wire.gd` was already stale
before these (30 of its checks fail on the untouched Wire, mostly from the
fan modes); its results are unchanged, bar its "narrow" check, which fails
about one run in three on the old Wire too.

Unverified: everything on screen (the range's look against the Mountain's,
the hill's softness, the rows' spacing and the drawing's pace), and Shift
for the new modes (the probe draws without it).

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
- **The ground mark** (`mark_size`) is the crack's ring, 1.8 m × the pips.
  The mark does not read Shift, which halves it to 0.9 m, and the knock
  reaches 1.0 m. Scree runs on downhill as far as the ground stays steeper
  than repose; the probe's 8 m horn spilled it 4.9 to 5.9 m, well past the
  mark's scree specks (1.25 to 2.85 m, ground_marks `SCREE`).
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
  - The downhill side is the side the ground falls 0.2 m or more to across
    the first stretch, read 0.9 m out either side, else 2 m out. On the flat,
    it is the side toward the camera, so the face is seen. The near reading
    keeps a stroke pressed on a bench from cutting its face back into the
    terrace above: past the ramp the ground can stand as high again, and the
    far reading alone would call it flat.
  - Each dab writes the stretch from the last dab, squared off 0.1 m past
    either end, and the shelf round the joint with the last one, so a
    zigzag path (a drag along the foot of a face picks now the bench, now
    the face) leaves no unlevelled wedge outside its turns. The stroke ends
    square.
  - If the ground on the line falls 1.2 m under the shelf, or climbs 2 m over
    it, the shelf steps by whole drops. A stroke down a hill leaves a flight
    of steps, not a causeway.
  - A stroke pressed on a bench cuts the next terrace down. A press that
    lands on a face (steeper than 1.2 rise/run, as a pointer aimed at a
    0.6 m bench often does) takes the lowest ground within `FOOT_REACH`
    (0.6 m): the bench at its foot. A shelf is never set above the ground
    pressed.
  - **At the floor.** The level never steps under `MIN_HEIGHT` (-1.5 m), and
    the face drops only as far as it: less than 1 m of room gives a shorter
    face. A shelf within `FLOOR_ROOM` (5 cm) of the floor takes no face and
    cuts nothing beside it, so a stroke pressed on a bench at the floor
    leaves the bench level.
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
- **Rock.** At release, `clay.paint_faces`: every tint cell the stroke moved
  (4 cm or more) takes mountain_forms' granite, weighted by its slope alone:
  from 0.6 rise/run to full at 1.2, read 0.25 m either side. Rock covers the
  cut's own bare earth, because a face is stone. There is no summit share,
  so mesa tops and shelves stay ground. The notch lays its floor's bare
  earth first (`clay.lay_dirt`), because a tap lays no dirt by itself.
- **Prop:** a chisel hanging from the grip, made of an octagonal wood handle
  (`#9c7444`), steel ferrule and bolster, a square shank (`#4f6680`) and a
  wedge blade in `#6f8aa6` with its edge across local x. Beside it on +x
  stands a mallet, head up in `#6f8aa6`, with a wood handle, as the icon
  draws them. It is untilted.

### The ground mark

The square is the notch (`mark_size`, `NOTCH_HALF` 0.8 m), the tap's reach.
The shelf levels 1.2 m either side of the line and reaches 3 m on the
downhill side. The mesa's outline is 2.5 m ±18%, up to 2.95 m. All of these
scale with the pips.

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
- A second stroke pressed on the bench below cuts a level at the bench,
  0.58 to 0.99 m under the first over ten runs, level to 0 mm. Its face drops a whole
  metre where the floor leaves room, and stops at `MIN_HEIGHT` where it
  does not (0.48 m with 0.59 m of room). The first shelf still stands at its
  level uphill. The probe presses the bench point itself, and turns the
  camera half round first when the bench is hidden behind the shelf's lip.
  On the floor itself the probe asserts no face instead.
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

## The Feather

Design "ZenScape HUD 5 Air", section C (`docs/design/hud-5/README.md`,
`lowpoly.js` `SHAPING_TOOLS[5]`, `TOOL_DIVIDER_BEFORE`, `GUST`). The Feather,
"Gust", is wind held in hand. It sits last in the tool roll, below the Hammer,
after a stitched divider (`tool_roll.gd` `DIVIDER_BEFORE`). The prevailing
wind stays in the almanac and is not the Feather's.

### Routing: a hold of the hand, with the clay's prop

The Feather shapes no land, so its gestures do not go through the clay. Its
press is held by the materials hand (`scripts/hand_materials.gd`, "The
Feather") the way a scatter is, and handed to the wind tool
(`scripts/wind_gust.gd`, `NativeChunkEditor.gust_in_hand`). There is still a
`scripts/clay_tools/feather.gd`, but it has no verbs. It is there so that
`LandClay.set_tool("feather")` does what it does for every tool:

- it builds and places the prop (`build_prop`, `prop_tilt`);
- the hand grips over the land (`hover_gesture`);
- one thing is in hand, so Esc, the Hand's pocket or taking a material give
  back the Hand with no new code.

Going through the clay's verbs was rejected for three reasons:

- the clay opens an undo step when it decides a drag or a hold;
- it decides a hold at 0.3 s, where the Feather's burst waits 0.4 s;
- the wind tool reads the pointer itself every frame, and needs to own the
  release to tell a burst from nothing.

Holding the press in `hand_materials` keeps the wind in one place. Nothing
about the gust is written twice.

- **Drag on the land:** a live wake (below). The wind goes with the feather
  while it moves, along the path it takes, as strong as it moves, and dies
  away when let go. Nothing is aimed and nothing is fired.
- **Hold still `FEATHER_BURST_SECONDS` (0.4 s):** a burst, rung out round the
  press on release, gathered as the wind tool gathers it (4 to 12 m over
  1.2 s). A still press let go sooner sends nothing, so a stray click blows
  nothing.
- **Width.** The wake is `FEATHER_HALF` (3 m, the Wind brush's radius) either
  side at the middle pip. The pips scale it by 0.6 / 1 / 1.5, as they scale
  every tool: 1.8 / 3 / 4.5 m, standing in for the design's 20 / 34 / 52 px.
- **From the sky.** Wind dragged from the sky onto the land
  (`hand_reach._void_drag`, `SkyWind.to_land`) now also puts the Feather in
  hand (`take_feather`), pressed in the roll, with the Feather's wake width.
  The drag on from there is the Feather's wake, starting out with the
  flick's power and heading. A sky swipe with the Feather in hand is still
  the sky's passing gust (`gust_from_sky`).
- **No land changes.** No undo step, and the heights are left alone.
- **Prop:** a stand-in quill, until Blender. A pale hexagonal shaft
  (`#ece2c8`) runs through the grip, with a horn quill end (`#a8936a`) over
  it. Two flattened seven-sided ellipsoids in `#cbb994` hang below the grip
  as the vane: a narrow leading half and a broad trailing one. It leans
  -18° (`GUST.cursorTilt`). It is its own cursor (below, "The hand at the
  rim"), and follows the pointer through the whole press, drag and release.
  The Feather's press is held by the materials hand, not the clay, and makes
  the hand unavailable (`hand_reach.available` is false while the wind is
  in hand), so `LandClay._place_prop` lets the quill through on its own
  (`materials.feather_blowing()`). Before that it shrank away for the whole
  drag.

Hook lines in shared files:

- `hand_reach.gd`: `"feather"` joins the holds whose release goes to
  `materials.let_go`. `_void_drag` passes `materials.feather_half()` to
  `to_land` and calls `materials.take_feather()` after.
- `sky_wind.gd` `to_land(point, half := -1.0)` and
  `native_chunk_editor.gd` `gust_in_hand(..., half := -1.0)` take the lane
  width. Below 0, the Wind brush's radius is used, as before.
- `ground_marks.gd`: three new kinds, `feather`, `feather_lane` and
  `feather_burst`. There is one branch in `step` (`_step_feather`) and the
  lane's box, fill and stitches in `_draw` and `_stitches`. The size lookup
  (`size_of`) is untouched: the Feather's sizes come from the wind.
- `shaders/ground_mark.gdshader`: kind 7, the lane.

### Live wake

Decided 2026-09-30 after a playtest: "The feather should drag along the path
you draw... I'll drag, and it will randomly like change directions so I
can't finish the path." The old drag guessed a heading from the last 0.12 s
of pointer samples, which flipped with small wobbles, and fired a straight
lane on release. Now the wind happens while you drag (`scripts/wind_gust.gd`,
"The wake"):

- **The path, not a heading.** Once the press moves past `STILL_DRAG`
  (0.6 m), the pointer's ground path is recorded. The shaders get the last
  12 points (`zs_wake_0..11`, the last one the feather). A point is fixed
  every 0.5 m, or every 0.18 s of travel at speed so the points cover the
  whole sway, or sooner where the path turns 20°. Each foliage root finds
  the nearest stretch and leans along it by when the feather passed there
  (`zs_wake_at`, mirrored by `blow_at`). It stirs 0.12 s before the feather
  arrives, holds 0.3 s while its air streams past, then swings back as a
  lane's head does. It parts out from the path a little.
- **Speed is strength.** The pointer's ground speed, smoothed, sets the lean
  from 0.3 (2 m/s) to 1.0 (20 m/s). Under 2 m/s the air eases off, so a
  drag that stops blows nothing.
- **Along the path.** Leaves and motes are picked up every 0.7 to 1.4 m
  where the feather passes, and carried along the path on the gust's
  spring. Ribbons are laid along the real curve, with UV.x as metres along
  it, so `wind_gust_trail.gdshader` is unchanged. They are baked 4 m at a
  time as the feather leaves them behind, and only the tail to the feather
  is rebuilt each frame. A parcel and a steered local gust ride at the
  feather, and creatures are told of each stretch as it is completed.
- **Let go, it dies away.** The air fades over 0.6 s while its head coasts
  up to 3 m on. Nothing is fired, and the wake is gone after 2.5 s.
- **Unchanged.** A still hold is the burst. The Genesis wind brush's press
  (`NativeChunkEditor.handle_input`) and the sky's swipe (`gust_from_sky`)
  still send aimed lanes.

### The ground mark

These marks are faint, at the same `LINE_ALPHA` (0.3) and `FILL_ALPHA`
(0.05) as the other tools, not the design's 0.85:

- **At rest:** a small stitched hotspot ellipse, `FEATHER_HOTSPOT` (0.24 by
  0.12 m, the design's 7 by 3.5 px at the hand sketch's scale).
- **During a drag:** the hotspot rides under the feather. The wind itself
  shows where it goes. (The lane's stitched edges, `feather_lane`, are
  drawn only for an aimed lane, which the Feather no longer makes.)
- **Held still:** the hotspot until 0.4 s. Then the burst's ring appears at
  the lane's half-width and grows to 1.5 times it (1.5 times the lane's
  width across) over the wind tool's gather.

Unlike the tools' marks, these stay while the press is held.

### Checked headless

`tools/probe_tool_feather.gd`:

```sh
godot --headless --fixed-fps 60 --path . -s res://tools/probe_tool_feather.gd -- --modeless --no-title
```

- The roll holds the Feather after the Hammer. The divider opens a 21 px gap
  between them, against 4. Its pocket takes it.
- The quill is built faceted in `#cbb994`. The hand grips it, and it rides
  in the shown hand leaning 18.0°.
- A 240 px swipe is one live wake, 0.3° off the swipe at the end, power
  0.94, and sends no lane gust. It is 1.8 / 3 / 4.5 m either side at the
  three pips. Mid-swipe the hotspot sits under the feather (0.00 m off).
- A curved drag (a 7 m radius arc, 72 frames, about 10.5 m/s): the quill
  shows on all 72 frames, its tip at most 0.47 m from the pointer's ground
  point, and it stays after release. With the old `_place_prop` it showed on
  7 of 72 frames and its tip was left 10.4 m behind.
- Through `WindGust.blow_at` mid-drag: foliage leans 0.68 / 0.63 / 0.56 at
  0.5 / 1.5 / 3 m behind the feather, 0.6° / 10.9° / 1.5° off the arc's
  tangent. It leans 0.00 at 2 m ahead and at 6 and 7 m off the path. A
  point the feather passed peaks at 0.70 and swings back to -0.17. 21
  leaves ride within 2.06 m of the path, and the ribbons lie within 2.46 m
  of it (strands sit up to 0.7 half-widths aside), their UV running to the
  feather's 7.87 m. The feather's heading is 5.8° off the tangent. One
  steered local gust and a parcel ride at the feather.
- Let go, the lean is 0.04 after 1 s and 0.00 after 3 s, and the wake is
  gone. A slow 2 m/s drag leans 0.33 against 0.68 for the fast one. The
  wind tool's own cost peaked at 0.59 and 0.94 ms a frame in two runs.
- A still press let go at 0.2 s sends nothing. Held, the hotspot stays until
  0.4 s. The ring then shows at 3.06 m, grows to 4.5 m, and bursts on
  release.
- No undo step, and the heights are unchanged.
- Taking a stone gives back the Hand. A drag from the sky onto the land puts
  the Feather in hand, at its width. The drag on is one wake, which dies
  away on release with nothing sent. Esc gives back the Hand.
- `tools/probe_sky_wind.gd`: the carried drag is a wake, 13° off the drag as
  the camera sees it, at the flick's power (0.98). Creatures are told as
  it goes. Held still it still bursts.
- Every mark's line alpha is 0.30, under `FAINT_CAP` (0.4).

### Unverified

Nothing has been seen on screen:

- the quill's size, lean and place in the grip. The hand blows open while
  the wind is in hand (`NativeChunkEditor.hand_gesture` "void"), so the quill
  may float in an open hand mid-gesture.
- whether a 0.24 m hotspot reads at all from 58 m out
- the burst ring on slopes and at night
- the wake itself: how the bend, the hold and the swing-back read in the
  grass and trees, whether 0.3 to 1.0 of lean is right for a slow and a fast
  drag, the ribbons along a curve, and the leaves' pick-up. The shader
  (`zs_wake_at`) is parse-checked only. It adds a 12-point loop to
  `zs_blow_at`, which every foliage vertex and the water's fragments run;
  it returns early outside the wake's box and with no wake. Its cost and
  GPU limits are unmeasured.
- the roll's new divider and the feather icon at 1.2 line width

## The hand at the rim

Decided 2026-09-30, once the linen HUD carried the verbs. The God Hand is for the
whole world only. It shows for the rim's reaches (the rim and wall hover, spin,
shake, flip, and the grip that turns the world) and fades out anywhere else
(scripts/god_hand.gd `WORLD`). The shaping tools and the Feather are their own
cursors, with no hand holding them, and so is material carried from the bar
(below). Only the sky's cloud is still pulled by the hand (`SKY`: "cloud" and
"summon", and a grown tree's crown, which borrows the cloud's pinch); the ball
a torn tuft becomes over the land goes without it. Day and night are the
almanac's Time pocket (click, Shift-click for the golden hours); the void's
click snaps nothing, and the snap is behind `--void-snap`. `--hand-everywhere`
brings back the old hand for the tools, the water ball ("cup") and the sown
seed ("sprinkle"); material from the bar stays a cursor even then.

The prop as a cursor (scripts/land_clay.gd `_place_prop`; the motion is
scripts/cursor_motion.gd, shared with the materials):

- **The tip is pinned.** Its working end sits on the pointer's ground point, or
  on the point the verb works (`hand_gesture`), on a stiff spring (about 0.1 s).
  The cursor stays exact, and the life comes from how the prop hangs off the tip.
- **It hovers and lands.** It hovers `HOVER` (0.3 m) over the land. A press
  brings it down at once, before the verb is decided, `PRESS_IN` into the
  land, on a soft spring so it bounces as it lands and as it lifts.
- **It leans.** It leans the tool's `prop_tilt` toward the way it goes. The
  handle leads by the pointer's speed and wobbles upright on a stop.
- **It idles.** Still for a moment, it bobs and sways a little.
- **It grows and shrinks at the tip.** It grows in out of the tip and shrinks
  back into it: over the land, with no material held, and not while the camera
  moves.

The material as a cursor (scripts/hand_materials.gd `Clump`, decided
2026-09-30: "a pinch of seeds or a bead of water follows the pointer, and a
flick sows"). A small faceted stand-in of what is in hand, built in code as the
props are, is the cursor, pinned by its underside and moving as the props do:

- **Seeds** are a pinch tinted by kind: three capped acorns, a fan of winged
  pine or birch seed, willow down or a dandelion's puff, flower seed with a
  petal or two, slim reed seed. Sowing, the veil's motes gather in the pinch
  (the handful's `hand_at`) and it flicks them out every 0.45 s and once more
  on release (`toss`, carrying the pointer's speed): a quick snap forward and
  a swell. Where they land is the veil's, as before.
- **Water** is a bead coming to a point. A press swells it into the water
  ball, which pops on its own beat (scripts/water_ball.gd `POP_SECONDS`,
  about 0.9 s from release to landing), no hand needed; the bead comes back
  once the ball is down.
- **Stones** are a few heaped pebbles, and flowers and reeds their seed. A
  press sets them onto the land, a still press swells them, and a drop sheds
  a little.

## The Modeller

Decided 2026-09-30, with the hand at the rim. The roll's first pocket held the
bare Hand, whose `build_prop()` was null, so with the God Hand gone the default
tool showed no cursor. It is now the Modeller, "Mould": a sculptor's boxwood
modelling tool with the Hand's verbs unchanged (tap a poke, drag the thumb's
groove or rub, Shift-drag the palm, hold-then-drag the pinch).

- **Kept.** The internal id stays `hand` (`scripts/clay_tools/hand.gd`,
  `LandClay.hand`, the roll's `TOOLS`, the ground marks' kind), and the verbs
  keep their names, so saves, probes and signals do not churn. Only the label
  (`scripts/hud_icons.gd` "hand": "Modeller · Mould"), the icon and the prop
  are new.
- **The prop.** A pale boxwood octagonal shaft through the grip with a darker
  band at the grip, a short tapered point over it, and below a neck flaring
  into a flattened seven-sided spatula in the tint, thin across the way it
  pushes. Tilt -20°, held as a pencil is. The clay builds it at setup, since
  the tool in hand from the start is never taken through `set_tool`.
- **The icon.** The same tool laid on the diagonal, spatula down to the left,
  point up to the right, with a band line at the grip and a line down the
  spatula for its thumb-worn hollow; the finer 1.2 line, full opacity (the
  Hand's was 0.82).
- **Unverified.** Nothing of it has been seen rendered: the prop's size and
  lean against the land, and the icon at the roll's size.

## The Mountain's range

Asked 2026-10-01: "The ability to pull a mountain to create a range. Right
now I have to do multiple points and pull up to stitch the mountain range.
I'd like a horizontal pull." Decided: one gesture on the Mountain
(`scripts/clay_tools/mountain.gd`), no new tool or mode.

- **The gesture.** Press and pull up for height, as before. Moving the
  pointer sideways as well stretches the peak into a range running from the
  press to the ground under the pointer's sideways travel. The clay picks
  that ground for a tool that `hold_tracks` (`clay.hold_point`): on the
  press's row of the screen, on the ground as it stood when the stroke
  opened, so pulling up never lengthens the range and the rising range never
  catches the ray. A range runs across the view; the up-down axis of the
  screen is the height.
- **A pull straight up is the old peak, exactly.** Under `RANGE_DEAD`
  (1.5 m) of sideways ground the Modeller's pinch step runs untouched. Past
  it the peak eases into the range over `RANGE_EASE` (2.5 m), so nothing
  jumps; coming back inside it eases back to the peak. The range is at most
  the spec's `range` long: 20 m for the Mountain (the 28 m plate's edge fade
  starts 11.4 m out), 10 m with Shift.
- **The shape.** Summits every `spacing` (4 m, 2.2 m with Shift, times the
  hand's size) from the press, each slipped along by up to 25 % of the
  spacing and off the line by up to 0.4 m, and 72 to 100 % of the range's
  height, seeded by the spot. Each is the pinch's horn (`_horn_from`, its own
  three to five arêtes, the forms' crag and lump noise), at `RANGE_NARROW`
  (0.45) of a lone peak's radius, which still grows with its own height, so
  the range is a line of teeth and not a long dome. Between them the crest is
  mountain_forms' ridge (its knife edge, one flank 0.72 as wide, serrated by
  the crag noise) at `SADDLE` (0.55) of the summits; the higher of the two
  wins, so neighbours join in notched cols. An envelope lowers the ends'
  summits by `RANGE_TAPER` (40 %), and the tallest summit stands at the
  pulled height. A summit further along rises out of the end as the line
  reaches it. Low pulls stay rounded swells and turn into the range as the
  peak turns into a horn (`HORN`); a pull down sinks a rounded trench.
- **Points.** The range gathers the points within the widest horn's reach of
  its line again whenever its end moves `REGATHER` (0.25 m), and keeps
  writing every point it has reached this pull (from `base`), so a range
  pulled back shorter lets its ground back down.
- **Let go.** The range's rock along its whole length (`paint_rock` over a
  square round its middle), trees on its flanks slide off, and the pull is
  one undo step.

### Checked headless

`tools/probe_mountain_range.gd` (real cozy worlds scene, synthesized input):

- a 150 px pull straight up gives the same heights as before the change on
  the same world (`--seed 7`, `--peak-ref`): largest difference 9e-5 m,
  which is the camera settling by a fraction of a pixel between runs; round
  (12.6 by 12.9 m raised over 10 % of its 13.9 m top);
- the same pull wobbling ±10 px sideways (under the dead zone) leaves that
  peak and never turns into a range;
- 150 px up and 16 m of ground sideways (rightward on most worlds, leftward
  on seed 12): a range along the drag (its axis within 2.5° of it), 19.2 to
  20.7 m long and 5.3 to 6.2 m wide at 10 % of its top (3.2 to 3.7 times),
  5 or 6 summits standing 0.4 m or more over the cols between them, its top
  11.6 to 12.9 m against the peak's 13.5 to 14 m, its crest down to 3 m or
  less at both ends, and rock along all three thirds of its crest; on seeds
  3, 7 and 12 and four runs of the default (random) world;
- each pull is one undo step and one undo restores the heights and tint
  exactly;
- headless frame time while pulling is the peak's: p50 10.7 against 10.9 ms
  in one run, 5.4 against 4.8 ms in another.

`tools/probe_drag_tools.gd` passes as before.

### Unverified

Nothing of it has been seen rendered: how the range's teeth, cols and
arêtes read against the edge spring's ranges, its rock, and how the
sideways pull feels with a real pointer and camera angles other than the
default view.
