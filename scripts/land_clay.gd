extends Node
## Land as clay (docs/scenic/modeless.md, "Land as clay"). Under `--modeless`
## a left press on the land is the hand working clay, and the shape and timing
## of the press decide the verb. There are no springs here: the land follows
## the hand and stays where it is let go.
##
## This reads the gesture; the tool in hand (scripts/clay_tools/, chosen in the
## tool roll, docs/design/tools/PLAN.md "The seam") says what each gesture does:
##
## - **Tap** (let go within HOLD_SECONDS, moved under MOVE_PIXELS): the tool's
##   `tap`. The Modeller (the roll's first tool, id `hand`) pokes: a dimple
##   rings out and the land comes back.
##   (Props, trees and residents under the pointer never reach here:
##   hand_reach keeps their own grab.)
## - **Drag** (moved MOVE_PIXELS before HOLD_SECONDS): the tool's dabs, laid
##   DAB_SPACING apart along the pointer's path. The Modeller's thumb digs a
##   groove or rubs, by the pointer's speed; Shift, read when the drag is
##   decided, makes it the palm.
## - **Hold still** for HOLD_SECONDS, then drag: the tool's hold, following the
##   pointer's travel up or down the screen in metres standing at the spot.
##   The Modeller's is the pinch. A tool that `hold_tracks` is also given
##   the pointer's sideways travel as ground (`hold_point`): the Mountain
##   stretches its peak along it into a range.
## - **Paint:** a tool that paints (its `paints`, the Sculpt) skips all of
##   that: it works from the press to the release, at the pointer, held still
##   or dragged, each frame's dabs along the path sharing that frame's time
##   (`_paint_step`). A quick click is worked for TAP_WORK.
##
## A tool with modes (its `modes`, picked on the tool roll's fan) skips the
## reading too: its mode in hand says the gesture (`_kind`), so a press is
## that verb at once: a drag mode's stroke opens at the press, a hold mode's
## hold closes at the press (drag up or down straight away), and a tap mode's
## press is a tap however it moves or however long it is held.
##
## Everything the tools share is here: each drag or hold is one undo step
## (opened when the verb is decided, closed at release, or once a drag the
## tool runs on past release is done: the Wire's cut drawn through the clay); ground a stroke takes
## down shows bare earth through the grass (the tint layer) and stays; the
## land shows through the editor's light refresh, one at a time, as the
## brushes and the land spring do, and only the points near the hand are
## written; rock paint and trees sliding off at release (`paint_rock` on
## raised ground, `paint_faces` on cut faces, `shake_trees`, called by the
## tools); and the size pips' `size_scale`.
## Nothing weathers after: clay stays as it was left.
##
## Input: hand_reach's `land_pressed`, `land_dragged` and `land_released` call
## `press`, `pull` and `release` (connected in studies/fidelity.gd). The tool
## roll picks the tool (scripts/hand_materials.gd calls `set_tool`).

## Emitted when a press ends: `verb` is the tool's name for it (the Modeller's are
## "poke", "groove" (a thumb stroke, its rub share 0..1 in `last_rub`),
## "palm", "pinch" or "fine_pinch"); `kept` is whether the land changed and an
## undo step was added.
signal worked(verb: String, kept: bool)
## A moment the tools' sound answers (scripts/clay_sound.gd, docs/scenic/sound.md
## "Tool sound"): `cue` names it, `at` is the ground (plate space, as
## `ground_at`), `strength` 0..1 how big it was.
signal sounded(cue: StringName, at: Vector3, strength: float)

const ClayTool = preload("res://scripts/clay_tools/clay_tool.gd")
## The tools' scripts: scripts/clay_tools/<id>.gd for each tool roll id.
const TOOL_PATH := "res://scripts/clay_tools/%s.gd"
const HandTool = preload("res://scripts/clay_tools/hand.gd")
## The Modeller's groove, kept here for the probes that measure it.
const GROOVE_HALF_WIDTH := HandTool.GROOVE_HALF_WIDTH
const GROOVE_DEPTH := HandTool.GROOVE_DEPTH

## Seconds of holding still that close the hold, and the screen pixels of
## travel that make the press a drag instead. A release before either is a tap.
const HOLD_SECONDS := 0.2
const MOVE_PIXELS := 6.0
## A drag's speed, pointer pixels per second over the last SPEED_WINDOW
## seconds of travel (path length, so a rub's turns do not read as slow).
const SPEED_WINDOW := 0.25
## Dabs along the path, metres apart, and at most this many a frame.
const DAB_SPACING := 0.3
const MAX_DABS := 64
## A painting tool's quick press (let go within HOLD_SECONDS, moved under
## MOVE_PIXELS) is worked for at least TAP_WORK seconds at the spot, so a
## click leaves a mark.
const TAP_WORK := 0.35
## Dirt: where a stroke takes the ground down, the painted grass has caved in
## and what lies under it shows. The tint layer's weight rises from nothing at
## DIRT_FROM metres dug to full at DIRT_FULL, and its colour is the stratum
## the cut reached (scripts/strata.gd `color_at`, docs/scenic/strata.md): by
## the cell's new height under the ground it was cut from, so a shallow scrape
## is topsoil, the Modeller's groove bed the ochre clay, a deep pit sand,
## shale and bedrock, and a cut into a tall hill its granite core. The weight
## ramps over most of the bank, so the groove blends into the grass instead
## of standing as a hard-edged gash. The earth covers whatever
## was painted there before (the rock of a range's foot, a pinch's flank) by
## its own weight, not only by the weight it adds: dug ground is earth. The
## tool scales that weight by its `dirt_share` for the verb, so a broad, soft
## stroke (the Paddle's sweep) can leave its swale grassed. Where
## a tool that `turns_lip` raises ground LIP_TURNED metres or more the
## pushed-aside clay shows as a pale fringe, TURNED at up to TURNED_WEIGHT
## (full by TURNED_FULL, the Modeller's groove lip), so a groove is outlined on
## both banks. A cell a stroke leaves at least DIRT_BARE bare loses its grass
## and blades and is marked hand-made, so cover does not creep back and
## nothing takes root in it. Dirt only ever deepens.
const DIRT_FROM := 0.04
const DIRT_FULL := 0.45
const DIRT_BARE := 0.5
const Strata = preload("res://scripts/strata.gd")
const TURNED := Color("a39a78")
const TURNED_WEIGHT := 0.2
const TURNED_FULL := 0.12
const LIP_TURNED := 0.03
## Sinking never takes ground below FLOOR metres (the land brush's floor),
## a little over the land's own floor.
const FLOOR := NativeTerrainData.MIN_HEIGHT+0.3
## Cut faces (`paint_faces`): the strata, a shade darker than a flat, on tint
## cells the stroke moved at least FACE_MOVED metres, either way, weighted by
## the ground's slope alone, from nothing at FACE_SLOPE.x (rise over run) to
## FACE_WEIGHT at .y. The slope is read FACE_REACH metres either side of a
## cell's middle (the cells are 0.5 m), close enough that a flat a cell off
## the face stays ground. A face's column is topped by the highest ground
## FACE_TOP metres round it, so a tall mesa's or mountain's face is its
## granite core all the way down to the plain, and a low one's is earth.
## There is no summit share, unlike `paint_rock`'s, so a mesa's top stays
## grass and a shelf or a gorge's bed stays the stratum it was cut to.
const FACE_SLOPE := Vector2(0.6,1.2)
const FACE_WEIGHT := 0.8
const FACE_TOP := 1.0
const FACE_MOVED := 0.04
const FACE_REACH := 0.25
## Trees on ground a stroke moved, once let go, keep their footing only where
## a tree could take root (emergence's rule: no steeper than the rock slope
## the terrain paints rock above, and under the rock band below the
## snowline). Else they slide down the fall line in SLIDE_STEP metre steps
## until the ground is at most SLIDE_REST steep and under that band (or water,
## the plate's edge or SLIDE_MAX metres stop them), and stand there: shaken
## off the clay to its foot. Pinned trees hold.
const SLIDE_STEP := 0.25
const SLIDE_REST := 0.45
const SLIDE_MAX := 12.0
const ROCK_BAND := 1.8
## A metre standing at a hold is never taken as fewer than this share of a
## metre across the ground on screen, so a camera looking straight down still
## holds.
const MIN_UPRIGHT := 0.3
## A resident within NOTICE metres looks round at a tap (`stir`).
const NOTICE := 8.0
const Disturbance = preload("res://scripts/disturbance.gd")
## The plate's last metres, where shaping fades to nothing (as the land
## spring and the mountain forms), and its half-width to the rim.
const EDGE := Vector2(11.4,13.6)
const PLATE_HALF := 14.0
## Metres per bucket of the point lookup.
const CELL := 1.5
## A stroke's heading is taken over its last HEADING_RUN metres, so a slow
## stroke's pick jitter does not turn it.
const HEADING_RUN := 0.6
## The held prop turns toward the way the hand goes at PROP_TURN (1/s).
const PROP_TURN := 6.0
## The prop as its own cursor (`_place_prop`) moves as a material carried
## from the bar does (scripts/cursor_motion.gd): pinned by its working end,
## hovering, dropping onto the land on a press, leaning and idling.
const CursorMotion = preload("res://scripts/cursor_motion.gd")
const GodHand = preload("res://scripts/god_hand.gd")

## RUN: a drag let go whose tool still works it (its `drag_running`);
## its stroke stays open until the tool is done. PAINT: a tool that paints
## (its `paints`) working from the press to the release.
enum State { IDLE, PENDING, DRAG, HOLD, RUN, PAINT }

var scene: Node3D
var editor: NativeChunkEditor
var state := State.IDLE
## True from `open_stroke` to `close_stroke`: GenesisAudio leaves the clay's
## strokes to ClaySound (scripts/clay_sound.gd).
var stroking := false
## The tool's name for the decided verb ("thumb", "pinch", "sweep"...).
var verb := ""
## Seconds since the press, and the most pixels the pointer has been from it.
var held := 0.0
## True through the hold's last step at release: a tool that eases its hold
## (the Modeller's pinch) lands it where the pointer is.
var letting_go := false
var travel := 0.0
## A drag's speed, pixels per second over the window.
var speed := 0.0
## Counters for the probe: light refreshes, dabs, times a hold closed.
var refreshes := 0
var dabs := 0
var pinch_closes := 0
## Rim notches the Modeller's thumb has cut this session, and the last one:
## {"normal" (out of the plate), "at" (plate point on the rim), "bed" (m)},
## for probes.
var notches := 0
var last_notch := {}
## Trees the last stroke shook off: [{"id","from","to"}], for probes.
var shaken: Array = []
## The hand's size (the tool roll's pips, scripts/tool_roll.gd SIZES): every
## tool's reach scales by it.
var size_scale := 1.0

## The tool in hand, and every tool made so far by id.
var tool: ClayTool
var tool_id := "hand"
## True while the hand has put its tool down (Esc, or its pocket pressed
## again on the tool roll): the land is not worked, the prop is away, and a
## press on a tree is the hand's to bend. `tool` stays as it was, for the
## next `set_tool`.
var put_down := false
var _tools := {}
## The Modeller (id `hand`), always made: the probes read its state through
## the clay.
var hand: HandTool

## For the tools (the plan's "What the clay gives a tool"): the plate point
## the verb works at (a hold may move it), the heights when its stroke opened,
## a stroke's heading (unit, plate) and the last path point laid, and the
## points `gather` found and their distances.
var center := Vector2.ZERO
## For a hold whose tool `hold_tracks`: the ground under the pointer's
## sideways travel (plate), picked on the press's row of the screen, on the
## ground as it stood when the stroke opened (so the hold's own rise does not
## catch the ray, and its travel up the screen, the height, moves it not at
## all). Null until the pointer moves on the land.
var hold_point: Variant = null
var base := PackedFloat32Array()
var heading := Vector2.ZERO
var last_plate: Variant = null
var near := PackedInt32Array()
var near_d := PackedFloat32Array()
## The gesture the clay last gave the God Hand ("" when it let it go).
var hand_set := ""

## The Modeller's state, read by the probes through the clay.
var rub: float:
	get: return hand.rub
var last_rub: float:
	get: return hand.rub
var poking: bool:
	get: return tool.busy()
var lift: float:
	get: return tool.lift

var _press := Vector2.ZERO
var _pointer := Vector2.ZERO
var _first_id := 0
var _region := Rect2()
var _queued := PackedVector2Array()
var _moved := 0.0
var _window: Array[Vector2] = []
var _tint_base := PackedFloat32Array()
var _dirt_depth := {}
var _turned := {}
var _dirt_rect := Rect2()
var _metre_pixels := 1.0
var _heading_from := Vector2.ZERO
var _cells := {}
var _cells_for: NativeTerrainData
var _cells_points := -1
var _prop: Node3D
var _prop_way := Vector2.ZERO
var _prop_last: Variant = null
## The prop as a cursor: how it moves (its working end, lean, bob, growing).
var _prop_motion := CursorMotion.new()
var _prop_depth := 0.0
## Where the verb in hand works (plate), set with its gesture, or null.
var _work_at: Variant = null
## The gesture the tool's mode says this press is ("tap", "drag", "hold",
## "paint"), or "" for the press's shape and timing to say.
var _kind := ""

static func enabled() -> bool:
	return preload("res://scripts/modeless_input.gd").enabled()

func setup(owner_scene: Node3D) -> void:
	scene = owner_scene
	editor = owner_scene._chunk_editor
	editor.clay = self
	name = "LandClay"
	hand = _make("hand")
	tool = hand
	_take_prop()

# --- The tool in hand -------------------------------------------------------------

## Take the tool `id` (a tool roll id with a script in scripts/clay_tools/).
## Whatever is in hand finishes first. False when there is no such tool.
func set_tool(id: String) -> bool:
	if id == tool_id:
		put_down = false
		return true
	var next := _make(id)
	if next == null: return false
	finish_now()
	put_down = false
	tool = next
	tool_id = id
	_take_prop()
	return true

## Put the tool in hand down (`put_down`): whatever it was doing finishes.
func put_tool_down() -> void:
	finish_now()
	put_down = true

## The tool in hand's stand-in prop, in place of the last one's, hidden until
## `_place_prop` shows it. The Modeller, the tool the clay starts with, has
## one too, so it is built at setup as well as on a change of tool.
func _take_prop() -> void:
	if _prop != null: _prop.queue_free()
	_prop = tool.build_prop()
	_prop_last = null
	if _prop != null:
		_prop.name = "HeldTool"
		_prop.visible = false
		_prop_depth = _tip_depth(_prop)
		_prop_motion.reset()
		editor.terrain.add_child(_prop)

## The tool `id`, made if it has not been yet (it is not taken into the
## hand), or null when there is no such tool. For readers that size something
## by a tool not yet in hand: the ground marks' `mark_size`.
func tool_of(id: String) -> ClayTool:
	return _make(id)

## Whether a tool id has its script.
static func has_tool(id: String) -> bool:
	return ResourceLoader.exists(TOOL_PATH % id)

func _make(id: String) -> ClayTool:
	if _tools.has(id): return _tools[id]
	if not has_tool(id): return null
	var made: ClayTool = load(TOOL_PATH % id).new()
	made.clay = self
	if made.mode.is_empty() and not made.modes().is_empty(): made.mode = made.modes()[0].id
	_tools[id] = made
	return made

## The God Hand's gesture over the land while nothing is pressed.
func hover_gesture() -> String:
	return tool.hover_gesture()

# --- The seam the modeless input drives -------------------------------------------

## A press on the land at `screen_pos`. False when it is not on the land or
## the editor cannot take it.
func press(screen_pos: Vector2) -> bool:
	finish_now()
	if put_down or editor == null or editor.forming or not editor.active: return false
	var hit: Variant = editor.pick(screen_pos)
	if hit == null: return false
	_press = screen_pos
	_pointer = screen_pos
	center = Vector2(hit.x,hit.z)
	last_plate = center
	hold_point = null
	_queued = PackedVector2Array()
	_window.clear()
	_moved = 0.0
	held = 0.0
	travel = 0.0
	speed = 0.0
	verb = ""
	refreshes = 0
	dabs = 0
	tool.reset()
	_kind = tool.press_kind()
	if tool.paints():
		_begin_paint()
		return true
	state = State.PENDING
	match _kind:
		"drag": _begin_drag()
		"hold": _begin_hold()
	return true

## The pointer moved to `screen_pos`.
func pull(screen_pos: Vector2, _relative := Vector2.ZERO) -> void:
	if state == State.IDLE: return
	_moved += screen_pos.distance_to(_pointer)
	_pointer = screen_pos
	travel = maxf(travel,screen_pos.distance_to(_press))
	if state == State.PENDING and travel >= MOVE_PIXELS and _kind != "tap": _begin_drag()
	if state == State.DRAG or state == State.PAINT:
		var hit: Variant = _pick_base(screen_pos)
		if hit != null: _queued.append(Vector2(hit.x,hit.z))
		elif state == State.DRAG: tool.drag_off()
	elif state == State.HOLD and tool.hold_tracks():
		var hit: Variant = _pick_base(Vector2(screen_pos.x,_press.y))
		if hit != null: hold_point = Vector2(hit.x,hit.z)

## The button came up: a tap is the tool's, a drag or a hold is kept as it
## stands.
func release(screen_pos: Vector2 = Vector2.INF) -> void:
	if state == State.IDLE: return
	if screen_pos != Vector2.INF: pull(screen_pos)
	match state:
		State.PENDING:
			state = State.IDLE
			tool.tap(_fine())
		State.DRAG:
			_drag_step(0.0)
			if tool.drag_end(): _drag_step(0.0)
			if tool.drag_running(): state = State.RUN
			else: close_stroke()
		State.HOLD:
			letting_go = true
			_hold_step()
			letting_go = false
			tool.hold_end()
			close_stroke()
		State.PAINT:
			var tapped := held < HOLD_SECONDS and travel < MOVE_PIXELS
			_paint_step(0.0,maxf(TAP_WORK-held,0.0) if tapped else 0.0,true)
			tool.paint_end(tapped)
			close_stroke()

## End whatever is in hand at once (undo, a new press, a world change, a
## change of tool): a stroke or hold closes as it stands, anything the tool
## left running (a poke's dimple) is taken back, and a drag the tool runs on
## past release (the Wire's cut) lands whole and closes.
func finish_now() -> void:
	tool.finish()
	match state:
		State.PENDING: state = State.IDLE
		State.DRAG, State.RUN: close_stroke()
		State.HOLD:
			tool.hold_end()
			close_stroke()
		State.PAINT:
			_paint_step(0.0,0.0,true)
			tool.paint_end(false)
			close_stroke()

# --- Frame loop ------------------------------------------------------------------

func _process(delta: float) -> void:
	delta = minf(delta,0.05)
	tool.frame(delta)
	match state:
		State.PENDING:
			held += delta
			_track_speed(delta)
			if held >= HOLD_SECONDS and travel < MOVE_PIXELS and _kind != "tap": _begin_hold()
		State.DRAG: _drag_step(delta)
		State.HOLD: _hold_step()
		State.RUN: if not tool.drag_running(): close_stroke()
		State.PAINT:
			held += delta
			_track_speed(delta)
			_paint_step(delta,delta)
	_place_prop(delta)

## The drag's speed: path pixels over the last SPEED_WINDOW seconds.
func _track_speed(delta: float) -> void:
	_window.append(Vector2(delta,_moved))
	_moved = 0.0
	var seconds := 0.0
	var pixels := 0.0
	for k in range(_window.size()-1,-1,-1):
		if seconds >= SPEED_WINDOW:
			_window = _window.slice(k+1)
			break
		seconds += _window[k].x
		pixels += _window[k].y
	speed = pixels/maxf(seconds,1.0/120.0)

# --- Deciding the verb -------------------------------------------------------------

func _begin_drag() -> void:
	open_stroke()
	_heading_from = center
	heading = Vector2.ZERO
	verb = tool.drag_begin(_fine())
	state = State.DRAG
	hand_gesture(tool.gesture(verb),ground_at(center))

func _begin_hold() -> void:
	open_stroke()
	verb = tool.hold_begin(_fine())
	var at := ground_at(center)
	var camera: Camera3D = scene.camera
	var terrain: Node3D = editor.terrain
	var foot := camera.unproject_position(terrain.to_global(at))
	var up := camera.unproject_position(terrain.to_global(at+Vector3.UP)).distance_to(foot)
	var across := camera.unproject_position(terrain.to_global(at+Vector3.RIGHT)).distance_to(foot)
	_metre_pixels = maxf(maxf(up,across*MIN_UPRIGHT),1.0)
	state = State.HOLD
	pinch_closes += 1
	hand_gesture(tool.gesture(verb),at,true)

func _begin_paint() -> void:
	open_stroke()
	_heading_from = center
	heading = Vector2.ZERO
	verb = tool.paint_begin(_shift())
	state = State.PAINT
	_paint_step(0.0,0.0)

## Open the verb's one undo step on the ground as it now stands.
func open_stroke() -> void:
	var data := editor.data
	# Anything still landing lands first, as a brush press would.
	editor._land_mountain()
	data.begin_stroke()
	base = data.heights.duplicate()
	_first_id = data.next_id
	_region = Rect2(center,Vector2.ZERO).grow(1.0)
	_tint_base = data.tint.duplicate()
	_dirt_depth = {}
	_turned = {}
	stroking = true
	editor._emit_stroke(0,ground_at(center),tool.stroke_radius(),0.0)

## Close the verb's undo step and settle the land, as a brush's release does.
func close_stroke() -> void:
	var data := editor.data
	data.mark_objects_hand(_first_id)
	_bare()
	var kept := data.end_stroke()
	editor._stroke_rect = _region.grow(1.0)
	editor._settle_pending = true
	editor._settle_stroke()
	if kept: editor._stroke_ended("land")
	editor._stroke_rect = Rect2()
	editor._emit_stroke(2,ground_at(center),tool.stroke_radius(),0.0)
	stroking = false
	var done := tool.worked_as(verb)
	state = State.IDLE
	verb = ""
	hand_gesture("")
	worked.emit(done,kept)

## Dabs along the pointer's path since the last frame.
func _drag_step(delta: float) -> void:
	if delta > 0.0: _track_speed(delta)
	var go := tool.drag_frame(delta)
	if _queued.is_empty() or not go: return
	var data := editor.data
	var heights := data.heights
	_dirt_rect = Rect2()
	# A tool's dab may queue more path (the Modeller carrying a groove to the lip).
	var k := 0
	while k < _queued.size():
		var p := _queued[k]
		var from: Vector2 = last_plate if last_plate != null else p
		var count := clampi(ceili(from.distance_to(p)/DAB_SPACING),1,MAX_DABS)
		if _heading_from.distance_to(p) >= HEADING_RUN:
			heading = (p-_heading_from).normalized()
			_heading_from = p
		for j in range(1,count+1):
			var q := from.lerp(p,float(j)/count)
			var reach := tool.dab(heights,q)
			if reach > 0.0: dirty(q,reach)
			dabs += 1
		last_plate = p
		k += 1
	_queued = PackedVector2Array()
	data.heights = heights
	_dirt()
	show_land()
	var at := ground_at(last_plate)
	editor._emit_stroke(1,at,tool.stroke_radius(),delta)
	hand_gesture(tool.gesture(verb),at)
	var god: Node = scene.get("god_hand") as Node
	if god != null and not hand_set.is_empty(): god.reach_pace = tool.pace()

## A painting tool's frame: `work` seconds of it shared by dabs along the
## pointer's path since the last frame, or one at the pointer if it held
## still. `ending` at release: the tool finishes what is still growing.
func _paint_step(delta: float, work: float, ending := false) -> void:
	var data := editor.data
	var heights := data.heights
	_dirt_rect = Rect2()
	var wrote := tool.paint_frame(heights,delta,ending)
	var path := PackedVector2Array()
	for p in _queued:
		var from: Vector2 = last_plate if last_plate != null else p
		var count := clampi(ceili(from.distance_to(p)/DAB_SPACING),1,MAX_DABS)
		if _heading_from.distance_to(p) >= HEADING_RUN:
			heading = (p-_heading_from).normalized()
			_heading_from = p
		for j in range(1,count+1): path.append(from.lerp(p,float(j)/count))
		last_plate = p
	_queued = PackedVector2Array()
	if path.is_empty() and work > 0.0: path.append(last_plate)
	for q in path:
		var reach := tool.paint_dab(heights,q,work/path.size())
		if reach > 0.0: dirty(q,reach)
		dabs += 1
	if not wrote and path.is_empty(): return
	data.heights = heights
	_dirt()
	show_land()
	var at := ground_at(last_plate)
	editor._emit_stroke(1,at,tool.stroke_radius(),delta)
	hand_gesture(tool.gesture(verb),at)

## A hold follows the pointer: its travel up the screen in metres standing at
## the spot.
func _hold_step() -> void:
	var data := editor.data
	var heights := data.heights
	if not tool.hold_step(heights,(_press.y-_pointer.y)/_metre_pixels): return
	data.heights = heights
	_dirt()
	show_land()
	hand_gesture(tool.gesture(verb),ground_at(center))

# --- What the clay gives a tool ------------------------------------------------------

## Queue a plate point on the drag's path, laid after those queued before it.
func queue_point(p: Vector2) -> void:
	_queued.append(p)

## The drag's path points not yet laid, in order: all of it since the press
## for a tool whose `drag_frame` holds its dabs back (the Wire reads its
## drawn path here).
func queued() -> PackedVector2Array:
	return _queued

## The path's last point: the last queued, else the last laid.
func path_end() -> Vector2:
	return _queued[-1] if not _queued.is_empty() else last_plate

## The ground a dab at `q` may have dug, `reach` round it, for this frame's
## dirt (the clay lays it after the frame's dabs or hold step).
func dirty(q: Vector2, reach: float) -> void:
	var area := Rect2(q-Vector2.ONE*reach,Vector2.ONE*reach*2.0)
	_dirt_rect = _dirt_rect.merge(area) if _dirt_rect.has_area() else area

## Every point within `radius` of `at` into `near` (and distances `near_d`).
func gather(at: Vector2, radius: float) -> void:
	var data := editor.data
	if _cells_for != data or _cells_points != data.points.size():
		_cells.clear()
		_cells_for = data
		_cells_points = data.points.size()
		for i in range(data.points.size()):
			var key := Vector2i(floori(data.points[i].x/CELL),floori(data.points[i].y/CELL))
			if not _cells.has(key): _cells[key] = PackedInt32Array()
			_cells[key].append(i)
	near = PackedInt32Array()
	near_d = PackedFloat32Array()
	var low := Vector2i(floori((at.x-radius)/CELL),floori((at.y-radius)/CELL))
	var high := Vector2i(floori((at.x+radius)/CELL),floori((at.y+radius)/CELL))
	var points := data.points
	for x in range(low.x,high.x+1):
		for y in range(low.y,high.y+1):
			var cell: Variant = _cells.get(Vector2i(x,y))
			if cell == null: continue
			for i: int in cell:
				var d := points[i].distance_to(at)
				if d < radius:
					near.append(i)
					near_d.append(d)

## How much shaping reaches point `i`: 1 inside, easing to 0 over the
## plate's last metres (EDGE).
func fade(i: int) -> float:
	var p: Vector2 = editor.data.points[i]
	var edge := maxf(absf(p.x),absf(p.y))
	return clampf((EDGE.y-edge)/(EDGE.y-EDGE.x),0.0,1.0)

## The stroke touched the ground `reach` round `q` (the settle refresh covers it).
func touch(q: Vector2, reach: float) -> void:
	_region = _region.merge(Rect2(q-Vector2.ONE*reach,Vector2.ONE*reach*2.0))

## Ask the tools' sound for `cue` at `at` (plate), `strength` 0..1.
func sound(cue: StringName, at: Vector2, strength := 1.0) -> void:
	sounded.emit(cue,ground_at(at),clampf(strength,0.0,1.0))

func ground_at(p: Vector2) -> Vector3:
	var h: Variant = editor.data.ground_height(p)
	return Vector3(p.x,float(h) if h != null else 0.0,p.y)

## Send the land to the screen: one light refresh at a time, so a slow one is
## never stacked on; a full one if the light one cannot run.
func show_land() -> void:
	if editor.refresh_pending > 0: return
	refreshes += 1
	if editor._light_refresh_ready(true): editor._refresh_light()
	else: editor.refresh(get_tree())

## Settle the land after something outside a stroke moved it (a poke).
func settle() -> void:
	editor._settle_pending = true
	editor._settle_stroke()

## A tap on the land stirs the life round `at` (plate): a resident within
## NOTICE looks round, and frogs, fish, deer and the heron near it notice too
## (scripts/life_notice.gd answers a "poke").
func stir(at: Vector2, radius: float, strength: float) -> void:
	var point: Vector3 = editor.terrain.to_global(ground_at(at))
	var creature: Node3D = scene.get("creature") as Node3D
	if creature != null and creature.visible and creature.has_method("notice"):
		if creature.global_position.distance_to(point) < NOTICE: creature.notice(point)
	Disturbance.raise(point,radius,strength,"poke")

## The range's rock onto ground the stroke raised round `at`, `reach` out
## (mountain_forms `_rock_tint`, `form`'s rock job run at once), measured
## against `height` so a low swell stays green. The hand's bare earth keeps
## its colour. It goes into the stroke's undo step.
func paint_rock(at: Vector2, reach: float, height: float, form := "alpine") -> void:
	var data := editor.data
	var forms := preload("res://scripts/mountain_forms.gd")
	var ground: Variant = data.sample(at,base)
	var job := {"tint":data.tint.duplicate(),"rock":forms.ROCKS.granite,"height":height,"base":base,
		"region":Rect2(at-Vector2.ONE*reach,Vector2.ONE*reach*2.0),"lock":preload("res://scripts/edge_spring.gd")._bare_cells(data),
		"salt":hash([editor.land_seed,"pinch",at.snapped(Vector2.ONE*0.01)]),"form":form,"ground":float(ground) if ground != null else 0.0}
	data.tint = forms._rock_tint(data,job)
	sound(&"rock_settle",at,height/10.0)

## The strata on the faces a stroke cut (or built) inside `region` (plate):
## every tint cell the stroke moved at least FACE_MOVED metres from `base`,
## up or down, whose ground now stands steeper than FACE_SLOPE.x, weighted by
## that slope alone (see FACE_SLOPE). Each takes the stratum at its own
## height (scripts/strata.gd), a shade darker than a flat, so a wall cut
## through the bands shows them as stripes and a tall column's face its
## granite core. `paint_rock` is the one for raised ground's surface: it
## measures a share of `height` up from `base`, so ground a stroke lowered
## never takes it, and it adds a summit share that would paint a tall mesa's
## top.
##
## A cell's colour goes that share of the way to the stratum over whatever
## was laid there before, the stroke's own flat earth included (lay the dirt
## first, `lay_dirt`, so the face goes over it), and its weight never drops.
## Call it at release or inside a tap's stroke, so the undo step takes it
## back.
func paint_faces(region: Rect2) -> void:
	var data := editor.data
	var layers := strata()
	var side := NativeTerrainData.MEADOW_CELLS
	var step := NativeTerrainData.MEADOW_STEP
	var low := Vector2i(((region.position+Vector2.ONE*PLATE_HALF)/step).floor()).clamp(Vector2i.ZERO,Vector2i.ONE*(side-1))
	var high := Vector2i(((region.end+Vector2.ONE*PLATE_HALF)/step).floor()).clamp(Vector2i.ZERO,Vector2i.ONE*(side-1))
	var heights := data.heights
	var tint := data.tint
	var changed := false
	for z in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			var p := data.meadow_position(x,z)+Vector2.ONE*step*0.5
			var h: Variant = data.sample(p,heights)
			var b: Variant = data.sample(p,base)
			if h == null or b == null or absf(float(h)-float(b)) < FACE_MOVED: continue
			var share := smoothstep(FACE_SLOPE.x,FACE_SLOPE.y,_face_slope(data,heights,p))
			if share <= 0.01: continue
			var top := maxf(float(h),float(b))
			for around: Vector2 in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
				var t: Variant = data.sample(p+around*FACE_TOP,heights)
				if t != null: top = maxf(top,float(t))
			var color: Color = layers.color_at(p,float(h),top,true)
			var k := (z*side+x)*NativeTerrainTint.STRIDE
			var before: float = tint[k+3]
			var mix := 1.0 if before <= 0.0 else share
			tint[k] = lerpf(tint[k],color.r,mix)
			tint[k+1] = lerpf(tint[k+1],color.g,mix)
			tint[k+2] = lerpf(tint[k+2],color.b,mix)
			tint[k+3] = minf(maxf(before,share*FACE_WEIGHT),1.0)
			changed = true
	if changed: data.tint = tint

## The world's strata (scripts/strata.gd): what the ground is made of by
## height, for the colours here and for any tool that asks `material_at`.
func strata() -> Strata:
	return Strata.for_seed(editor.land_seed)

## Bare earth now, `reach` round `at`, on ground the stroke took down. The clay
## lays it by itself after a frame's dabs and each hold step; a tool whose
## change lands some other way (a cut written whole at release, a tap's own
## stroke) calls this, before `paint_faces` so the faces go over it.
func lay_dirt(at: Vector2, reach: float) -> void:
	dirty(at,reach)
	_dirt()

## Trees on ground the stroke moved, within `reach` of `at` (or inside `area`
## when it is given), that can no longer hold it slide down to where they can
## (see SLIDE_STEP). Their records move inside the stroke's undo step; they
## stay wild (not marked hand-made).
func shake_trees(at: Vector2, reach: float, area := Rect2()) -> void:
	shaken = []
	var data := editor.data
	var trees: Array = preload("res://scripts/diorama_world_play.gd").TREES
	var presets := preload("res://scripts/native_landscape_presets.gd")
	var snowline: float = preload("res://scripts/biome_blend.gd").snowline(data._recipe_settings,data._palette.snowline)
	var drawn: Dictionary = preload("res://scripts/native_formation_shape.gd").BIOMES.get(data._recipe_settings.get("biome",""),{})
	var rock_slope := float(drawn.get("rock_slope",data._palette.rock_slope))
	var band := snowline-ROCK_BAND
	var moved := false
	for index in range(data.objects.size()):
		var item: Dictionary = data.objects[index]
		if not str(item.asset) in trees or item.asset == "bigfoot_tree" or item.get("pinned",false): continue
		var from := Vector2(item.x,item.z)
		if area.has_area():
			if not area.has_point(from): continue
		elif from.distance_to(at) > reach: continue
		var was: Variant = data.sample(from,base)
		var now: Variant = data.ground_height(from)
		if was == null or now == null or absf(float(now)-float(was)) < 0.05: continue
		if presets._slope(data,from) <= rock_slope and float(now) <= band: continue
		var p := from
		var travelled := 0.0
		while travelled < SLIDE_MAX:
			var here: Variant = data.ground_height(p)
			if presets._slope(data,p) <= SLIDE_REST and here != null and float(here) <= band: break
			var fall := _fall(p)
			if fall == Vector2.ZERO: break
			var next := p+fall*SLIDE_STEP
			if maxf(absf(next.x),absf(next.y)) > EDGE.x or data.ground_height(next) == null or _in_pond(next): break
			p = next
			travelled += SLIDE_STEP
		if p == from: continue
		var moved_item := item.duplicate(true)
		moved_item.x = p.x
		moved_item.z = p.y
		data.objects[index] = moved_item
		moved = true
		shaken.append({"id":item.id,"from":from,"to":p})
	if moved:
		data.objects_revision += 1
		sound(&"trees",(shaken[0].to as Vector2),shaken.size()/4.0)

## The ground the stroke has touched so far (plate rect), for `shake_trees`.
func touched() -> Rect2:
	return _region

## Drive the God Hand. `again` plays the gesture's In afresh even if it is
## already showing (the hover's ready pinch closes into the real one).
func hand_gesture(gesture: String, point: Variant = null, again := false) -> void:
	hand_set = gesture
	_work_at = point if not gesture.is_empty() else null
	var god: Node = scene.get("god_hand") as Node
	if god == null: return
	god.reach_gesture = gesture
	god.reach_point = point if not gesture.is_empty() else null
	if gesture.is_empty(): god.reach_pace = 1.0
	if again and god.get("gesture") == gesture and god.player != null:
		var clip: String = god.GESTURES[gesture]+"In"
		if god.player.has_animation(clip): god.player.play(clip,god.BLEND)

# --- Dirt ------------------------------------------------------------------------------

## The strata into the tint cells under this frame's dabs: the stratum at
## each cell middle's new height, weighted by how far it now stands below the
## ground at the stroke's start. Written
## from the stroke's starting tint, so it lands the same whatever the pace.
func _dirt() -> void:
	if not _dirt_rect.has_area(): return
	var data := editor.data
	var side := NativeTerrainData.MEADOW_CELLS
	var step := NativeTerrainData.MEADOW_STEP
	var low := Vector2i(((_dirt_rect.position+Vector2(14,14))/step).floor()).clamp(Vector2i.ZERO,Vector2i.ONE*(side-1))
	var high := Vector2i(((_dirt_rect.end+Vector2(14,14))/step).floor()).clamp(Vector2i.ZERO,Vector2i.ONE*(side-1))
	var layers := strata()
	var turned := TURNED.srgb_to_linear()
	var turns := tool.turns_lip(verb)
	var shows := clampf(tool.dirt_share(verb),0.0,1.0)
	var heights := data.heights
	var tint := data.tint
	var changed := false
	for z in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			var p := data.meadow_position(x,z)+Vector2.ONE*step*0.5
			var was: Variant = data.sample(p,base)
			var now: Variant = data.sample(p,heights)
			if was == null or now == null: continue
			var cell := z*side+x
			var dug := float(was)-float(now)
			if dug < -LIP_TURNED and turns:
				# A lip: pushed-aside clay, a pale fringe.
				var weight := TURNED_WEIGHT*smoothstep(LIP_TURNED,TURNED_FULL,-dug)
				if weight <= float(_turned.get(cell,0.0)) or _dirt_depth.has(cell): continue
				_turned[cell] = weight
				_earth(tint,cell,turned,weight)
				changed = true
				continue
			if shows <= 0.0 or dug <= float(_dirt_depth.get(cell,DIRT_FROM)): continue
			_dirt_depth[cell] = dug
			var color := layers.color_at(p,float(now),float(was))
			_earth(tint,cell,color,smoothstep(DIRT_FROM,DIRT_FULL,dug)*shows)
			changed = true
	_dirt_rect = Rect2()
	if changed: data.tint = tint

## Earth `color` at `weight` into tint `cell`, over the stroke's starting
## tint: it covers what was painted there by its own weight (dug ground is
## earth, whatever colour its surface was), and the cell's weight never drops.
## Written from the starting tint, so coating again rewrites the cell.
func _earth(tint: PackedFloat32Array, cell: int, color: Color, weight: float) -> void:
	var k := cell*NativeTerrainTint.STRIDE
	var before := _tint_base[k+3]
	var share := 1.0 if before <= 0.0 else clampf(weight,0.0,1.0)
	tint[k] = lerpf(_tint_base[k],color.r,share)
	tint[k+1] = lerpf(_tint_base[k+1],color.g,share)
	tint[k+2] = lerpf(_tint_base[k+2],color.b,share)
	tint[k+3] = maxf(before,minf(weight,1.0))

## Where a stroke left the ground bare, the grass is gone for good: no cover,
## no blades, and hand-made, so emergence neither regrows nor plants it.
func _bare() -> void:
	var data := editor.data
	for cell: int in _dirt_depth:
		if NativeTerrainTint.weight_at(data.tint,cell) < DIRT_BARE: continue
		data.grass[cell] = 0.0
		data.blades[cell] = 0.0
		data.meadow[cell] = 0.0
		data.provenance[cell] = NativeTerrainData.SOURCE_HAND
	_dirt_depth = {}

# --- Helpers -----------------------------------------------------------------------

func _shift() -> bool:
	return Input.is_key_pressed(KEY_SHIFT)

## Shift, or a mode that presses as Shift does (the Modeller's palm).
func _fine() -> bool:
	return _shift() or bool(tool.mode_spec().get("fine",false))

## The pointer on the ground as it stood when the stroke began: picked on the
## live ground, a groove deepening ahead of the pointer would draw the line
## onto its far wall, away from the camera, and widen it on that side.
func _pick_base(screen_pos: Vector2) -> Variant:
	var data := editor.data
	var now := data.heights
	data.heights = base
	var hit: Variant = editor.pick(screen_pos)
	data.heights = now
	return hit

## Rise over run at plate point `p` on `heights`, read FACE_REACH either side
## (for `paint_faces`).
static func _face_slope(data: NativeTerrainData, heights: PackedFloat32Array, p: Vector2) -> float:
	var e: Variant = data.sample(p+Vector2(FACE_REACH,0),heights)
	var w: Variant = data.sample(p-Vector2(FACE_REACH,0),heights)
	var n: Variant = data.sample(p+Vector2(0,FACE_REACH),heights)
	var s: Variant = data.sample(p-Vector2(0,FACE_REACH),heights)
	if e == null or w == null or n == null or s == null: return 0.0
	return Vector2(float(e)-float(w),float(n)-float(s)).length()/(2.0*FACE_REACH)

## Whether `p` is under a pond (as native_landscape_presets `_wet` reads one).
func _in_pond(p: Vector2) -> bool:
	var data := editor.data
	var h: Variant = data.ground_height(p)
	for pool: Dictionary in data.ponds:
		if h != null and float(h) < float(pool.level)+0.15 and p.distance_to(Vector2(pool.x,pool.z)) < 7.0: return true
	return false

## The way down at `p`: against the ground's gradient, or zero on the level.
func _fall(p: Vector2) -> Vector2:
	var data := editor.data
	var e: Variant = data.ground_height(p+Vector2(0.25,0))
	var w: Variant = data.ground_height(p-Vector2(0.25,0))
	var n: Variant = data.ground_height(p+Vector2(0,0.25))
	var s: Variant = data.ground_height(p-Vector2(0,0.25))
	if e == null or w == null or n == null or s == null: return Vector2.ZERO
	var gradient := Vector2(float(e)-float(w),float(n)-float(s))
	return -gradient.normalized() if gradient.length() > 0.0001 else Vector2.ZERO

# --- The held prop -------------------------------------------------------------------

## The tool is its own cursor (docs/design/tools/PLAN.md "The hand at the
## rim"): no hand holds it. Its working end sits on the pointer's ground point,
## or on the point the verb works (`hand_gesture`), so the cursor stays exact;
## the life is in how it hangs from there (scripts/cursor_motion.gd, which a
## material carried from the bar shares). It hovers 0.3 m over the land,
## bobbing and swaying a little once still; it drops onto the land when a verb
## takes hold, bouncing as it lands, and springs back up when it lets go; it
## leans the tool's `prop_tilt` toward the way it goes (the last way it went
## when it stops), and its handle leads its working end by the pointer's
## speed, wobbling upright again on a stop. It grows out of the ground point as
## it comes and shrinks back into it as it goes: over the land while no
## material is held, and not while the camera moves. The Feather's wind in
## hand (hand_materials `feather_blowing`) is a press the clay never sees and
## makes the hand unavailable (hand_reach `available`), so it is let through
## on its own: the quill comes down and follows the pointer through the whole
## press, drag and release. `--hand-everywhere` puts it back in the God Hand
## (`_place_prop_in_hand`).
func _place_prop(delta: float) -> void:
	if _prop == null: return
	if GodHand.everywhere:
		_place_prop_in_hand(delta)
		return
	var reach: Node = scene.get("hand_reach")
	var materials: Node = reach.get("materials") if reach != null else null
	var carrying: bool = put_down or (materials != null and not str(materials.get("held")).is_empty())
	var wanderer: Node = scene.get("wanderer")
	var eye: bool = wanderer != null and wanderer.get("active") == true
	# A press comes down at once, before its verb is decided.
	var working := state != State.IDLE or not hand_set.is_empty()
	var blowing: bool = materials != null and materials.has_method("feather_blowing") and (materials.feather_blowing() or materials.can_pouring())
	var hit: Variant = editor.pointer_hit
	var want: bool = reach != null and (reach.available() or blowing) and not reach.camera_moving() and not carrying and not eye
	if want:
		var holding: String = reach.holding
		want = working or blowing or holding in ["land","feather","can"] or (holding.is_empty() and reach.hover_zone == "land")
		want = want and (hit != null or (working and _work_at != null) or (blowing and _prop.visible))
	var motion := _prop_motion
	_prop.visible = motion.show(want,delta)
	if not _prop.visible:
		_prop_last = null
		return
	var goal: Variant = _work_at if working and _work_at != null else hit
	if goal == null: goal = motion.tip
	var at_work := working and _work_at != null
	var ground := func(flat: Vector2) -> Variant: return editor.data.ground_height(flat)
	# The can pours from above the land, not pressed onto it.
	motion.advance(delta,goal,working or (blowing and tool.prop_lift() <= 0.0),ground,CursorMotion.across_view(editor.terrain,scene.camera),(goal as Vector3).y if at_work else -INF)
	var turn := motion.turn(-tool.prop_tilt())
	var size := _prop_size()*motion.size()
	# Pinned by its working end: the grip stands its depth above the tip.
	var grip := motion.tip+turn*Vector3(0.0,_prop_depth*size,0.0)+Vector3.UP*tool.prop_lift()*size
	_prop.transform = Transform3D(turn.scaled(Vector3.ONE*maxf(size,0.001)),grip)

## A point given in the held prop's own space, in plate coordinates (the
## can's rose, for its stream), or null while the prop is not shown.
func prop_point(local: Vector3) -> Variant:
	if _prop == null or not _prop.visible: return null
	return _prop.transform*local

## The prop's size: the God Hand's scale (1 at the hand's own size), which
## `--hand-cursor` keeps one size on screen.
func _prop_size() -> float:
	if not "--hand-cursor" in OS.get_cmdline_user_args(): return 1.0
	return float(scene.distance)/GodHand.CURSOR_DISTANCE

## How far the prop's working end hangs below its grip (m at size 1): the
## lowest point of its meshes.
static func _tip_depth(prop: Node3D) -> float:
	var low := 0.0
	for mesh: MeshInstance3D in prop.find_children("*","MeshInstance3D",true,false):
		var to_prop := mesh.transform
		var up := mesh.get_parent()
		while up != prop and up != null:
			to_prop = (up as Node3D).transform*to_prop
			up = up.get_parent()
		low = minf(low,(to_prop*mesh.get_aabb()).position.y)
	return -low

## `--hand-everywhere`: the prop rides in the God Hand, its grip between the
## index and thumb tips (god_hand `hold_at`), its working end down toward the
## land, leaning the tool's `prop_tilt` toward the way the hand is going.
## Shown while the hand shows and no material is held; sized with the hand.
func _place_prop_in_hand(delta: float) -> void:
	var god: Node3D = scene.get("god_hand") as Node3D
	var materials: Node = scene.hand_reach.get("materials") if scene.get("hand_reach") != null else null
	var carrying: bool = put_down or (materials != null and not str(materials.get("held")).is_empty())
	_prop.visible = god != null and god.visible and float(god.opacity) > 0.3 and not carrying
	if not _prop.visible:
		_prop_last = null
		return
	var grip: Vector3 = god.hold_at(true)
	var flat := Vector2(grip.x,grip.z)
	if _prop_last != null and flat.distance_to(_prop_last) > 0.01:
		_prop_way = _prop_way.lerp((flat-(_prop_last as Vector2)).normalized(),1.0-exp(-PROP_TURN*delta))
	_prop_last = flat
	if _prop_way.length() < 0.1:
		var right: Vector3 = editor.terrain.global_basis.inverse()*scene.camera.global_basis.x
		_prop_way = Vector2(-right.x,-right.z).normalized()
	var way := Vector3(_prop_way.x,0.0,_prop_way.y).normalized()
	var axis := way.cross(Vector3.UP)
	var lean := Basis.IDENTITY
	if axis.length_squared() > 0.0001: lean = Basis(axis.normalized(),deg_to_rad(-tool.prop_tilt()))
	var size: float = god.basis.get_scale().x/float(god.HAND_METRES)
	var facing := Basis(Vector3.UP,atan2(way.x,way.z))
	_prop.transform = Transform3D((lean*facing).scaled(Vector3.ONE*size),grip)
