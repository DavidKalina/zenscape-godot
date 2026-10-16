extends "res://studies/kit_isle.gd"
## The motif editor, round 1 (its
## handoff level-editor-round1.md): one authored motif built by hand in the
## game's real look, on the motif yard's base (studies/kit_isle.gd, the
## yard's sky studies/motif_yard_sky.gd, the motif stood as a placed isle
## by scripts/kit_isle/motif_sky.gd as the yard and the generator stand
## theirs), saved as a recipe the generator places
## (scripts/kit_isle/motif_authored.gd).
##
##   godot --path . res://studies/motif_editor.tscn -- --no-title [--load=<slug>]
##
## Editing (the pilot put away):
##   hold right mouse + move      look round      W A S D / Q E  fly / down, up
##   Shift                        fly fast        wheel          fly speed
##   left click a piece / marker  select it; drag to move it along the ground
##   palette item, then left click on the ground  place it (Shift: keep placing)
##   Z / X                        turn the selected piece 15 deg (Shift: 5)
##   Delete / Backspace           delete the selected piece
##   G                            dress again (turf, flora, life)
##   Ctrl+S                       save          P / Shift+P   play from the spawn / under the camera
##   1-8                          tools: select raise lower smooth flatten ravine water outline
##   brush: LMB drag (hold still to pile up), wheel or [ ] radius, panel strength
##   water: click a hollow (Shift: take it away); outline: drag handles,
##   Shift+click add, Alt+click or Delete remove; Ctrl+Z / Ctrl+Shift+Z undo, redo
##   (round 2)
## Round 3: the early game's
## UI on it. The tool roll (scripts/tool_roll.gd) down the left edge holds
## the land tools and stamps; Cmd/Ctrl K or / opens the palette
## (studies/motif_editor_palette.gd over scripts/command_palette.gd) with the
## kit's pieces and trees as thumbnails to drag into the world; the
## landform's sliders sit top left on the same linen
## (studies/motif_editor_panel.gd); the old tools' sound and tremor run
## under it (studies/motif_editor_feel.gd).
##   stamps (Mountain, Hills, Crater, Mesa, Island): click, drag out to size
##   Ravine: draw a line (a ravine) or a loop (a lake, dug and filled)
##   New land: draw a loop out past the edge; Trash: click a thing away
## Playing: the real pilot, motor and input; P back to editing, as it was.
const MotifAuthored = preload("res://scripts/kit_isle/motif_authored.gd")
const MotifSky = preload("res://scripts/kit_isle/motif_sky.gd")
const YardSky = preload("res://studies/motif_yard_sky.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const LandformPanel = preload("res://studies/motif_editor_panel.gd")
const EditorPalette = preload("res://studies/motif_editor_palette.gd")
const Feel = preload("res://studies/motif_editor_feel.gd")
const ToolRoll = preload("res://scripts/tool_roll.gd")
const ClaySound = preload("res://scripts/clay_sound.gd")
const RuinKitFit = preload("res://scripts/ruin_kit_fit.gd")

## The net under the motif's keel (m), the yard's.
const NET := 60.0
const LOOK_RATE := 0.004
const MARKERS := {"spawn":["SPAWN",Color(0.98,0.85,0.25)],"rim_in":["RIM IN",Color(0.35,0.8,1.0)],"rim_out":["RIM OUT",Color(1.0,0.45,0.3)]}
const PICK_PX := 26.0

## The motif's data (the file's), and the motif made from it.
var data: Dictionary = {}
var motif: RefCounted = null
## The dressed stand (a MotifSky holding the one isle), or the bare land
## while a slider drags.
var motifs: Node3D = null
var bare: Node3D = null
var editing := true
var net_y := -INF
## Timings (ms): the last bare rebuild, the last dress (art stood).
var bare_ms := 0
var dress_ms := 0
var rebuilds := 0

var _rid_base := 0
var _args := PackedStringArray()
var _cam_pos := Vector3(60.0,30.0,60.0)
var _cam_yaw := 0.8
var _cam_pitch := -0.45
var _cam_speed := 14.0
var _edit_cam := Transform3D.IDENTITY
var _looking := false
var _look_from := Vector2.ZERO
## The selection: a piece's index (-1 none) or a marker's key ("" none).
var selected := -1
var sel_marker := ""
var _dragging := false
var armed := ""
var _weather_new := 0.3
var _marker_nodes := {}
var _arrows := {}

## The land tools (round 2): [id, label, key].
const TOOLS := [["select","Select","1"],["raise","Raise","2"],["lower","Lower","3"],["smooth","Smooth","4"],
	["flatten","Flatten","5"],["ravine","Ravine","6"],["water","Water","7"],["outline","Outline","8"]]
const BRUSHES := ["raise","lower","smooth","flatten"]
## Round 3: the stamps (click, drag out to size) and their landform; the
## tools that draw a path (applied on release); the stamps' height as a
## share of their radius at strength 0.5, and their sound and tremor tool.
const STAMPS := {"stamp_mountain":"mountain","stamp_hills":"hills","stamp_crater":"crater","stamp_mesa":"mesa","stamp_island":"island"}
const STAMP_TALL := {"mountain":0.7,"hills":0.26,"crater":0.38,"mesa":0.42,"island":0.25}
const STAMP_FEEL := {"mountain":"mountain","hills":"mountain","crater":"crater","mesa":"chisel","island":"island"}
const PATHS := ["ravine","new_land"]
## Each tool's pocket on the tool roll and its mode there ("" none).
const POCKET := {"select":["",""],"raise":["hand","pinch"],"lower":["hand","groove"],"smooth":["paddle","plane"],
	"flatten":["paddle","pat"],"ravine":["wire",""],"water":["can",""],"outline":["",""],"stamp_mountain":["mountain",""],
	"stamp_hills":["hills",""],"stamp_crater":["crater",""],"stamp_mesa":["chisel",""],"stamp_island":["island","spread"],
	"new_land":["island","draw"],"trash":["trash",""],"run_aqueduct":["",""],"run_wall":["",""],"run_bridge":["",""]}
## A pocket's modes, and the tool a pocket (or a pocket's mode) gives.
const POCKET_MODES := {"hand":["pinch","groove"],"paddle":["plane","pat"],"island":["spread","draw"]}
const POCKET_TOOL := {"hand":"raise","hills":"stamp_hills","mountain":"stamp_mountain","crater":"stamp_crater","island":"stamp_island",
	"wire":"ravine","chisel":"stamp_mesa","paddle":"smooth","can":"water","trash":"trash"}
const MODE_TOOL := {"hand:pinch":"raise","hand:groove":"lower","paddle:plane":"smooth","paddle:pat":"flatten","island:spread":"stamp_island","island:draw":"new_land"}
## The roll's three size pips: the brush radius each gives.
const PIP_RADIUS := [3.0,5.0,8.5]
const HINTS := {
	"select":"Select: click a piece or marker, drag it along the ground · Z X turn · B breakable · Del delete · Cmd/Ctrl K the palette",
	"raise":"Raise: drag over the land, hold still to pile it up · wheel or [ ] radius",
	"lower":"Lower: drag over the land · wheel or [ ] radius",
	"smooth":"Smooth: drag over the land · wheel or [ ] radius",
	"flatten":"Flatten: drag; levels to where the stroke began",
	"ravine":"Ravine: draw a line for a ravine, a loop for a lake · strength is depth",
	"water":"Water: click a hollow to pour a pond · Shift+click takes one away",
	"outline":"Outline: drag the edge points · Shift+click adds · Alt+click or Del removes",
	"stamp_mountain":"Mountain: click inside the ring to stamp, drag up to pull it taller · pips or wheel size the ring",
	"stamp_hills":"Hills: click to stamp in the ring, drag up for taller",
	"stamp_crater":"Crater: click to stamp in the ring, drag down to dig deeper · pour water in it",
	"stamp_mesa":"Mesa: click to stamp in the ring, drag up for taller",
	"stamp_island":"Island: click near or past the edge; the isle grows round the ring",
	"new_land":"New land: draw a loop out past the edge; the isle grows to it",
	"trash":"Trash: click a piece, a run, a stamp, a lake or a pond to take it away",
	"run_aqueduct":"Aqueduct run: click the start, then the end (or drag) · spans fill between, piers to the ground, heads at both ends",
	"run_wall":"Wall run: click the start, then the end (or drag) · walls step with the ground; ends snap to cliff lips",
	"run_bridge":"Rope bridge: click one lip, then the other · ends snap to the nearest cliff lip",
}
## Round 4: the run tools (scripts/ruin_kit_fit.gd), and how near (px) the
## cursor must come to a free connector for a carried piece to snap on.
const RUNS := {"run_aqueduct":"aqueduct","run_wall":"wall","run_bridge":"bridge"}
const SNAP_PX := 60.0
## A piece carried near a cliff lip (m) seats along it (a wall).
const LIP_SNAP := 2.5
var _run: Dictionary = {}
var _snap_mark: MeshInstance3D = null
var _snap_tint: StandardMaterial3D = null
var snaps_made := 0
## A live stroke's land: KitLand's grid this coarse (m), no crisp cliffs.
const LIVE_CELL := 1.5
## A held brush stamps again this often (ms) where it stands (a dwell
## raises a mountain).
const DWELL_MS := 110
const UNDO_MOST := 120
var tool := "select"
var brush_r := 5.0
var brush_s := 0.6
## The stroke being drawn (its dict is in data.strokes), {} none.
var _stroke: Dictionary = {}
var _stroke_at := 0
var _want_live := false
## Timings (ms): the last live (coarse) rebuild, the last full bare one.
var live_ms := 0
var full_ms := 0
var live_count := 0
var _undo: Array = []
var _redo: Array = []
var _slider_undo_at := 0
## The outline handle being dragged or picked (-1 none) and its plane's y.
var handle := -1
var _handle_y := 0.0
var _handles: Node3D = null
var _cursor: MeshInstance3D = null
var panel: LandformPanel = null
var roll: ToolRoll = null
var palette: EditorPalette = null
var feel: Feel = null
## A stamp being sized ({} none): its stroke, its middle, the outline
## before it (an island grows the outline from that), its press.
var _stamp: Dictionary = {}
var _stamp_mid := Vector3.ZERO
var _stamp_outline: Array = []
var _stamp_press := Vector2.ZERO
var _stamp_base := 0.0
## Pixels of pull up the screen that double a stamp's height.
const STAMP_PULL_PX := 160.0
## A path being drawn ({} none): its tool and points (x, z), its line.
var _path: Dictionary = {}
var _path_line: MeshInstance3D = null
## The ravine's cut running after the release ({} none).
var _cut: Dictionary = {}
## A piece's ghost carried in from the palette ({} none).
var _held_piece: Dictionary = {}
var _cam_base := Transform3D.IDENTITY
var _thumbs_left: Array = []
var stamps_made := 0
var lakes_made := 0

var _ui: CanvasLayer
var _slider_drag := false
var _want_bare := false
var _want_dress := false
var _changed_at := 0
var _bare_done_at := 0

## Live editing (round 3's "an edit must look like an edit"): the dressed
## isle stays as it is while a stroke, a stamp or a cut runs; the edit
## shows as a ghost of its own ground (`update_ghost`); on release the isle
## is dressed again out of sight, and the old one shows until the new one
## stands whole with its plants (`_swap_step`).
## The stand still showing while the new one comes up (null none), and its motif.
var _shown: Node3D = null
var _shown_motif: RefCounted = null
var _swap_began := 0
## Ms from a release's dress to the swap (the new stand whole, plants and all).
var swap_ms := 0
var swaps := 0
## The ghost: its mesh, the ground it is drawn over (the motif shown) and
## that ground's heights on the ghost's lattice (cached for the edit).
const GHOST_CELL := 0.5
var _edit_ghost: MeshInstance3D = null
var _ghost_base: RefCounted = null
var _ghost_old := {}
var ghost_ms := 0.0
var ghost_count := 0
## The look the editor holds while editing (the sky and light never turn
## under an edit); playing gives the live sky back.
var edit_look := START_LOOK

func _ready() -> void:
	_args = LaunchArgs.user_args()
	var slug := ""
	for a: String in _args:
		if a.begins_with("--load="): slug = a.get_slice("=",1)
		elif a.begins_with("--look=") and SceneLookPresets.PRESETS.has(a.get_slice("=",1)): edit_look = a.get_slice("=",1)
	if slug != "" and FileAccess.file_exists(MotifAuthored.path_of(slug)): data = MotifAuthored.read(MotifAuthored.path_of(slug))
	if data.is_empty():
		if slug != "": push_warning("motif editor: no %s; a fresh hill" % MotifAuthored.path_of(slug))
		data = MotifAuthored.blank(slug if slug != "" else "untitled")
	motif = MotifAuthored.from_data(data)
	_no_lode = true
	start = motif.start()
	start_face = Vector2(-1.0,0.0)
	_set_net()
	isle_ready.connect(_first_stand,CONNECT_ONE_SHOT)
	super._ready()

func _set_net() -> void:
	net_y = float(motif.keel_top())-float(motif.depth())*MotifAuthored.KEEL_REACH-NET
	lost = net_y

func sky_script() -> Script:
	return YardSky

func isle_name() -> String:
	return "motif editor"

func isle_top() -> float:
	return float(motif.crest_top()) if motif != null else TOP

func isle_summit() -> Vector3:
	return motif.summit() if motif != null else super.isle_summit()

func capture_look() -> Vector3:
	return isle_summit()

func park_home() -> void:
	pass

func _grow() -> void:
	if not _turf.is_empty(): super._grow()

func _add_life() -> void:
	pass

func _strand() -> void:
	pass

# --- Standing it -------------------------------------------------------------------------

func _first_stand() -> void:
	_rid_base = _turf_rids.size()
	_build_editor_ui()
	set_tool("select")
	_build_markers()
	dress()
	frame_hill()
	enter_edit()
	# The study captures the mouse once he can walk (character_study.gd
	# `_ready`, right after `ready_to_walk`, which is when this runs: the
	# isle's `_ready` resumes inside that emit). In the editor the mouse
	# stays free: `_hold_mouse` frees it every frame while editing.
	_free_mouse_if_editing.call_deferred()
	print("motif editor: %s stood, dressed in %d ms" % [str(data.slug),dress_ms])

func _free_mouse_if_editing() -> void:
	if editing and not _looking: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

## While editing the cursor is free (captured only while the right button
## looks round); anything that captured it (the study's walk-ready, a
## click handled by the base) is undone the next frame.
func _hold_mouse() -> void:
	var want := Input.MOUSE_MODE_CAPTURED if _looking else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != want and get_tree().current_scene == self: Input.mouse_mode = want

## Everything stood freed: the dressed isle, the bare land, their turf.
func _clear_stand() -> void:
	# The pools the stand gave the pilot to wade go with it.
	var g: Variant = get("ground")
	if motifs != null and g != null and g.get("pools") is Array:
		var keep: Array = []
		for pool: Dictionary in g.pools:
			if not (pool.get("node") is Node and motifs.is_ancestor_of(pool.node)): keep.append(pool)
		g.pools.clear()
		g.pools.append_array(keep)
	if motifs != null:
		remove_child(motifs)
		motifs.free()
		motifs = null
	if bare != null:
		remove_child(bare)
		bare.free()
		bare = null
	if _shown != null:
		remove_child(_shown)
		_shown.free()
		_shown = null
		_shown_motif = null
	_drop_edit_ghost()
	_turf_rids.resize(_rid_base)

## The pools stood by `stand` taken from the pilot's ground.
func _drop_pools(stand: Node3D) -> void:
	var g: Variant = get("ground")
	if stand == null or g == null or not (g.get("pools") is Array): return
	var keep: Array = []
	for pool: Dictionary in g.pools:
		if not (pool.get("node") is Node and stand.is_ancestor_of(pool.node)): keep.append(pool)
	g.pools.clear()
	g.pools.append_array(keep)

## The dressed stand kept showing while the next comes up: out of the
## physics (rays, the pilot, the new plants' rays find only the new land),
## its pools and life stopped.
func _retire(stand: Node3D) -> void:
	_drop_pools(stand)
	for co: Node in stand.find_children("*","CollisionObject3D",true,false):
		(co as CollisionObject3D).collision_layer = 0
		(co as CollisionObject3D).collision_mask = 0
	stand.process_mode = Node.PROCESS_MODE_DISABLED

## The new stand stands whole (its plants grown): it shows, the old goes.
func _swap_step() -> void:
	if _shown == null: return
	var ready: bool = motifs == null or motifs.isles.is_empty() or str(motifs.isles[0].stage) in ["life","up"]
	if not ready and Time.get_ticks_msec()-_swap_began < 5000: return
	remove_child(_shown)
	_shown.free()
	_shown = null
	_shown_motif = null
	if motifs != null: motifs.visible = true
	swap_ms = Time.get_ticks_msec()-_swap_began
	swaps += 1
	if _stamp.is_empty() and _stroke.is_empty() and _cut.is_empty() and not _want_live: _drop_edit_ghost()
	else: _ghost_old.clear()

## The motif dressed as the generator stands it: its art built now (land
## and pieces), its turf, plants and life coming over the next frames in
## the sky's budget (scripts/kit_isle/motif_isle.gd).
func dress() -> void:
	var began := Time.get_ticks_msec()
	var keep := bare == null and motifs != null and get_tree().current_scene == self
	if not keep: _clear_stand()
	else:
		if _shown == null:
			# What shows now keeps showing (its motif the ghost's ground).
			_shown = motifs
			_shown_motif = motifs.isles[0].motif if not motifs.isles.is_empty() else motif
			_retire(_shown)
		else:
			# A stand still coming up, dropped: the shown one is kept.
			_drop_pools(motifs)
			remove_child(motifs)
			motifs.free()
		motifs = null
		_turf_rids.resize(_rid_base)
		_swap_began = began
	motif = MotifAuthored.from_data(data)
	motif.warm()
	motifs = MotifSky.new()
	# Built here and now, rendered too: one small isle is quicker than a
	# worker's round trip, and a worker's build must never be waited on
	# from this thread (its renderer calls wait on this thread's flush).
	motifs.threaded = false
	if _shown != null: motifs.visible = false
	add_child(motifs)
	var c: Vector2 = KitLand.centre_of(motif.outline())
	var reach := float(motif.sliders().length)*0.6
	motifs.setup_layer(self,null,_args,[[motif,Vector3.ZERO,[motif.id(),Vector3(c.x,float(motif.crest_top()),c.y),reach]]])
	for isle: Node3D in motifs.isles:
		isle.build_now()
		while str(isle.stage) in ["built","standing"]: isle.work(1 << 30)
	# Its ground on the turf layer now (the isle registers it again a
	# frame or two on): the editor's rays find it at once.
	for land: Array in motif.lands:
		for body: StaticBody3D in KitLand.turf_bodies(land[0]): body.collision_layer |= TURF_LAYER
	dress_ms = Time.get_ticks_msec()-began
	_after_land()

## The bare land and pieces only (a slider dragging): no plants, no life.
func rebuild_bare(live := false) -> void:
	var began := Time.get_ticks_msec()
	_clear_stand()
	motif = MotifAuthored.from_data(data)
	bare = Node3D.new()
	bare.name = "Bare"
	add_child(bare)
	# A live stroke or outline drag: coarse. Else the full land if the last
	# full one took under a quarter second, else coarse.
	var coarse := live or full_ms > 250
	if live: motif.fast_cell = LIVE_CELL
	var land: Node3D = motif.build_land(coarse)
	bare.add_child(land)
	for body: StaticBody3D in KitLand.turf_bodies(land): body.collision_layer |= TURF_LAYER
	var holder := Node3D.new()
	holder.name = "Pieces"
	bare.add_child(holder)
	motif.build_pieces(holder)
	bare_ms = Time.get_ticks_msec()-began
	if live:
		live_ms = bare_ms
		live_count += 1
	elif not coarse: full_ms = bare_ms
	rebuilds += 1
	_bare_done_at = Time.get_ticks_msec()
	_after_land()

func _after_land() -> void:
	_set_net()
	start = motif.start()
	# A marker the land shrank away from comes back onto it: along the way
	# to the middle until it is 1.5 m inside the outline.
	var poly := PackedVector2Array(motif.outline())
	var mid := KitLand.centre_of(motif.outline())
	for k: String in MARKERS:
		var a: Array = data.markers[k]
		var p := Vector2(float(a[0]),float(a[2]))
		var tries := 0
		while tries < 40 and (not Geometry2D.is_point_in_polygon(p,poly) or KitLand.edge_distance(p,poly) < 1.5):
			p = p.lerp(mid,0.06)
			tries += 1
		a[0] = snappedf(p.x,0.001)
		a[2] = snappedf(p.y,0.001)
	for k: String in MARKERS:
		var a: Array = data.markers[k]
		a[1] = snappedf(float(motif.ground(float(a[0]),float(a[2]))),0.001)
	_place_markers()
	_show_handles()
	_show_status()

## The Pieces holder of what stands now.
func pieces_holder() -> Node3D:
	var under: Node = bare if bare != null else (motifs.isles[0].art if motifs != null and not motifs.isles.is_empty() else null)
	return under.find_child("Pieces",true,false) as Node3D if under != null else null

func piece_node(k: int) -> Node3D:
	var holder := pieces_holder()
	return holder.get_node_or_null("P%d" % k) as Node3D if holder != null else null

## The pieces built again into what stands (after an add or a delete).
func refresh_pieces() -> void:
	var holder := pieces_holder()
	if holder == null: return
	for c: Node in holder.get_children():
		holder.remove_child(c)
		c.free()
	motif.build_pieces(holder)

# --- Edit and play --------------------------------------------------------------------------

func frame_hill() -> void:
	var s: Dictionary = motif.sliders()
	var top := float(motif.crest_top())
	var far := maxf(float(s.length),float(s.width))
	_cam_pos = Vector3(far*0.55,top+far*0.45,far*0.75)
	var to := Vector3(0.0,top*0.5,0.0)-_cam_pos
	_cam_yaw = atan2(-to.x,-to.z)
	_cam_pitch = atan2(to.y,Vector2(to.x,to.z).length())
	_apply_cam()

func _apply_cam() -> void:
	var b := Basis(Vector3.UP,_cam_yaw)*Basis(Vector3.RIGHT,_cam_pitch)
	_cam_base = Transform3D(b,_cam_pos)
	camera.global_transform = _cam_base

func _hints(on: bool) -> void:
	for l: Label in [_foot_hint,_switch_hint]:
		if l != null: l.visible = on

func enter_edit() -> void:
	editing = true
	# The sky held while editing: one pleasant daylight, never turning.
	if look_id != edit_look or weather.live: apply_look(edit_look,false)
	_hints(false)
	figure.visible = false
	if _ui != null: _ui.visible = true
	_set_markers_visible(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_apply_cam()

## The pilot dropped at the spawn (or under the camera's middle), live.
func play(under_camera := false) -> void:
	_edit_cam = camera.global_transform
	editing = false
	_end_drag()
	_set_markers_visible(false)
	if _ui != null: _ui.visible = false
	var at: Vector3 = motif.start()
	var face := Vector2(-1.0,0.0)
	if under_camera:
		var hit := ground_hit(get_viewport().get_visible_rect().size*0.5)
		if not hit.is_empty(): at = hit.position
	var rims: Array = motif.rims()
	if not rims.is_empty():
		var f: Vector3 = rims[0].face
		face = Vector2(-f.x,-f.z)
	start = at
	start_face = face
	# Playing, the sky turns again (from the held hour).
	apply_look(KitWeather.LIVE,false)
	figure.visible = true
	_hints(true)
	_end_fall()
	place(at+Vector3.UP*0.1,face)
	if get_tree().current_scene == self: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func back_to_edit() -> void:
	_cam_pos = _edit_cam.origin
	enter_edit()
	camera.global_transform = _edit_cam

func toggle_play(under_camera := false) -> void:
	if editing: play(under_camera)
	else: back_to_edit()

func _process(delta: float) -> void:
	_swap_step()
	if not editing or motif == null or _ui == null:
		super._process(delta)
		return
	_hold_mouse()
	_edit_step(delta)
	_advance_look(delta)
	_feel_step(delta)

func tick(delta: float) -> void:
	super.tick(delta)
	if not flying and motor.feet.y < net_y:
		_end_fall()
		respawn()

func _edit_step(delta: float) -> void:
	var typing := get_viewport().gui_get_focus_owner() is LineEdit
	if not typing and not Input.is_key_pressed(KEY_CTRL) and not Input.is_key_pressed(KEY_META):
		var way := Vector3.ZERO
		if Input.is_key_pressed(KEY_W): way.z -= 1.0
		if Input.is_key_pressed(KEY_S): way.z += 1.0
		if Input.is_key_pressed(KEY_A): way.x -= 1.0
		if Input.is_key_pressed(KEY_D): way.x += 1.0
		if Input.is_key_pressed(KEY_E): way.y += 1.0
		if Input.is_key_pressed(KEY_Q): way.y -= 1.0
		if way != Vector3.ZERO:
			var b := camera.global_basis
			var move := b*Vector3(way.x,0.0,way.z)+Vector3.UP*way.y
			_cam_pos += move.normalized()*_cam_speed*(3.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0)*delta
			_apply_cam()
	var now := Time.get_ticks_msec()
	# A held brush stamps again where it stands.
	if not _stroke.is_empty() and str(_stroke.tool) in ["raise","lower","smooth"] and now-_stroke_at > DWELL_MS:
		var pts: Array = _stroke.pts
		pts.append((pts[pts.size()-1] as Array).duplicate())
		_stroke_at = now
		_want_live = true
	# A stroke's or a handle's live land: coarse, as often as it keeps up.
	if _want_live and now-_bare_done_at > maxi(int(live_ms*1.5),30):
		_want_live = false
		if handle_drag(): _show_handles()
		else: update_ghost()
	# A slider's live rebuild: coalesced, and spaced while it drags.
	if _want_bare and (now-_changed_at > 60 or now-_bare_done_at > maxi(bare_ms*2,120)):
		_want_bare = false
		rebuild_bare()
	_cut_step()
	if _want_dress and not _want_bare and not _want_live and not _slider_drag and _stroke.is_empty() and _stamp.is_empty() and _path.is_empty() and _cut.is_empty() and handle_drag() == false and now-_changed_at > 250:
		_want_dress = false
		dress()

# --- Input ---------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_P and walk_ready and _ui != null:
		toggle_play((event as InputEventKey).shift_pressed)
		get_viewport().set_input_as_handled()
		return
	if not editing or _ui == null:
		super._unhandled_input(event)
		return
	_edit_input(event)

func _edit_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_RIGHT:
				# Looking captures the cursor; let go, it comes back where it was.
				if mb.pressed and not _looking: _look_from = mb.position
				_looking = mb.pressed
				_hold_mouse()
				if not mb.pressed and get_tree().current_scene == self: get_viewport().warp_mouse(_look_from)
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed and _sized() and not mb.shift_pressed: set_radius(brush_r*1.12)
				elif mb.pressed: _cam_speed = minf(_cam_speed*1.2,120.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed and _sized() and not mb.shift_pressed: set_radius(brush_r/1.12)
				elif mb.pressed: _cam_speed = maxf(_cam_speed/1.2,2.0)
			MOUSE_BUTTON_LEFT:
				if mb.pressed:
					if roll_click(mb.position): return
					if panel != null and panel.contains_pointer(mb.position) and _held_piece.is_empty(): return
					click(mb.position,mb.shift_pressed,mb.alt_pressed)
				else: release(mb.position)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _looking:
			_cam_yaw -= mm.relative.x*LOOK_RATE
			_cam_pitch = clampf(_cam_pitch-mm.relative.y*LOOK_RATE,-1.5,1.5)
			_apply_cam()
		elif not _held_piece.is_empty(): ghost_to(mm.position)
		elif not _stamp.is_empty(): size_stamp(mm.position)
		elif not _path.is_empty(): path_to(mm.position)
		elif not _run.is_empty(): run_to(mm.position)
		elif not _stroke.is_empty(): stroke_to(mm.position)
		elif handle >= 0 and _dragging: handle_to(mm.position)
		elif _dragging: drag_to(mm.position)
		_show_cursor(mm.position)
	elif event is InputEventKey and event.pressed:
		var k := event as InputEventKey
		if k.keycode == KEY_S and (k.ctrl_pressed or k.meta_pressed):
			save()
			return
		if k.keycode == KEY_Z and (k.ctrl_pressed or k.meta_pressed):
			if k.shift_pressed: redo()
			else: undo()
			return
		if k.keycode == KEY_Y and (k.ctrl_pressed or k.meta_pressed):
			redo()
			return
		if get_viewport().gui_get_focus_owner() is LineEdit: return
		if k.keycode >= KEY_1 and k.keycode <= KEY_8 and not k.echo:
			set_tool(str(TOOLS[k.keycode-KEY_1][0]))
			return
		if k.keycode == KEY_BRACKETLEFT:
			set_radius(brush_r/1.12)
			return
		if k.keycode == KEY_BRACKETRIGHT:
			set_radius(brush_r*1.12)
			return
		if k.echo and not k.keycode in [KEY_Z,KEY_X]: return
		match k.keycode:
			KEY_Z: turn_selected(-(5.0 if k.shift_pressed else 15.0))
			KEY_X: turn_selected(5.0 if k.shift_pressed else 15.0)
			KEY_DELETE, KEY_BACKSPACE:
				if tool == "outline" and handle >= 0: remove_handle(handle)
				else: delete_selected()
			KEY_G: dress()
			KEY_B: toggle_breakable()
			KEY_ESCAPE:
				if not _held_piece.is_empty(): _drop_ghost()
				if not _stroke.is_empty() or not _stamp.is_empty() or not _path.is_empty(): release(Vector2.ZERO)
				armed = ""
				if tool != "select": set_tool("select")
				select(-1)
			KEY_L: step_look(-1 if k.shift_pressed else 1)

## The turf under screen point `at` ({position, normal} or {}).
func ground_hit(at: Vector2) -> Dictionary:
	var from := camera.project_ray_origin(at)
	var to := from+camera.project_ray_normal(at)*2000.0
	var q := PhysicsRayQueryParameters3D.create(from,to,TURF_LAYER)
	return get_world_3d().direct_space_state.intersect_ray(q)

## The piece under screen point `at` (its index, -1 none).
func piece_hit(at: Vector2) -> int:
	var from := camera.project_ray_origin(at)
	var to := from+camera.project_ray_normal(at)*2000.0
	var q := PhysicsRayQueryParameters3D.create(from,to)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var n: Node = hit.collider if not hit.is_empty() else null
	while n != null and n.get_parent() != null:
		if n.get_parent().name == "Pieces" and str(n.name).begins_with("P") and str(n.name).substr(1).is_valid_int(): return int(str(n.name).substr(1))
		n = n.get_parent()
	# Missed its colliders (a piece sunk low, a tree's crown): the piece
	# whose drawn middle is nearest the click on screen.
	var best := -1
	var near := PICK_PX*1.5
	var holder := pieces_holder()
	if holder == null: return -1
	for c: Node in holder.get_children():
		var piece := c as Node3D
		if not str(piece.name).substr(1).is_valid_int(): continue
		var mid := piece.global_transform*MotifAuthored.drawn_box(piece).get_center()
		if camera.is_position_behind(mid): continue
		var d := camera.unproject_position(mid).distance_to(at)
		if d < near:
			near = d
			best = int(str(piece.name).substr(1))
	return best

## The marker whose pole is under screen point `at` ("" none).
func marker_hit(at: Vector2) -> String:
	var best := ""
	var near := PICK_PX
	for k: String in _marker_nodes:
		var n: Node3D = _marker_nodes[k]
		for up: float in [0.0,1.5,3.0]:
			var p := n.global_position+Vector3.UP*up
			if camera.is_position_behind(p): continue
			var d := camera.unproject_position(p).distance_to(at)
			if d < near:
				near = d
				best = k
	return best

## A left click at screen point `at`: a marker, a piece, else the ground
## (a placement when the palette is armed).
func click(at: Vector2, keep := false, alt := false) -> void:
	if not _held_piece.is_empty():
		place_ghost(at)
		return
	if armed == "" and tool in BRUSHES:
		begin_stroke(at)
		return
	if armed == "" and STAMPS.has(tool):
		begin_stamp(at)
		return
	if armed == "" and tool in PATHS:
		begin_path(at)
		return
	if armed == "" and tool == "trash":
		trash_at(at)
		return
	if armed == "" and RUNS.has(tool):
		run_click(at)
		return
	if armed == "" and tool == "water":
		pour_at(at,keep)
		return
	if armed == "" and tool == "outline":
		outline_click(at,keep,alt)
		return
	var m := marker_hit(at)
	if m != "" and armed == "":
		snapshot()
		select(-1)
		sel_marker = m
		_dragging = true
		_show_status()
		return
	if armed != "":
		var hit := ground_hit(at)
		if not hit.is_empty():
			snapshot()
			var k := place_piece(armed,hit.position)
			_pop(k)
			if not keep: armed = ""
		return
	var k := piece_hit(at)
	if k >= 0: snapshot()
	select(k)
	_dragging = k >= 0

func drag_to(at: Vector2) -> void:
	var hit := ground_hit(at)
	if hit.is_empty(): return
	var p: Vector3 = hit.position
	if sel_marker != "":
		data.markers[sel_marker] = [snappedf(p.x,0.001),snappedf(float(motif.ground(p.x,p.z)),0.001),snappedf(p.z,0.001)]
		_place_markers()
	elif selected >= 0: move_piece(selected,p)

func _end_drag() -> void:
	_dragging = false
	_show_status()

## A new piece `id_name` at `at` (world, on the ground), seated; selected.
## `snap` (from `find_snap`): set onto another piece, it follows that piece.
func place_piece(id_name: String, at: Vector3, seed_value := -1, turn := 0.0, snap := {}) -> int:
	var pieces: Array = data.pieces
	var entry := {"id":id_name,"seed":seed_value if seed_value > 0 else randi()%9000+1,"weathered":snappedf(_weather_new,0.01),"at":[snappedf(at.x,0.001),snappedf(at.y,0.001),snappedf(at.z,0.001)],"turn":snappedf(fposmod(turn,360.0),0.001),"sink":MotifAuthored.SINK}
	if id_name in RuinKit.AQUEDUCT_PIECES: entry.fit = true
	if not snap.is_empty() and int(snap.get("to",-1)) >= 0:
		var under: Dictionary = pieces[int(snap.to)]
		var frame := Transform3D(Basis(Vector3.UP,deg_to_rad(float(under.get("turn",0.0)))),Vector3(float(under.at[0]),float(under.at[1]),float(under.at[2])))
		var local := frame.affine_inverse()*at
		entry.on = {"to":int(snap.to),"c":str(snap.get("c","")),"mine":str(snap.get("mine","")),"at":[snappedf(local.x,0.001),snappedf(local.y,0.001),snappedf(local.z,0.001)],
			"turn":snappedf(fposmod(turn-float(under.get("turn",0.0)),360.0),0.001)}
		if bool(snap.get("stand",false)): entry.on.stand = true
		snaps_made += 1
	pieces.append(entry)
	var k := pieces.size()-1
	var node: Node3D = motif.make_piece(k)
	if node != null: pieces_holder().add_child(node)
	_after_pieces()
	select(k)
	return k

func move_piece(k: int, at: Vector3) -> void:
	var p: Dictionary = data.pieces[k]
	# Dragged off what it was set onto: it stands on its own again.
	if p.has("on"):
		p.erase("on")
		refresh_pieces()
	var a: Array = p.at
	a[0] = snappedf(at.x,0.001)
	a[2] = snappedf(at.z,0.001)
	_reseat(k)
	_show_selection()

func turn_selected(deg: float) -> void:
	if selected < 0: return
	snapshot()
	var p: Dictionary = data.pieces[selected]
	p.turn = fposmod(float(p.get("turn",0.0))+deg,360.0)
	if p.has("on"):
		p.on.turn = fposmod(float(p.on.get("turn",0.0))+deg,360.0)
		refresh_pieces()
		_show_status()
		return
	_reseat(selected)
	_show_status()

## The selected piece breakable or not (its "breakable"; absent is
## breakable, so a saved motif reads as before). The build only tags it
## (scripts/kit_isle/motif_authored.gd `make_piece`): nothing else changes.
func toggle_breakable() -> void:
	if selected < 0 or selected >= (data.pieces as Array).size(): return
	snapshot()
	var p: Dictionary = data.pieces[selected]
	if bool(p.get("breakable",true)): p.breakable = false
	else: p.erase("breakable")
	var node := piece_node(selected)
	if node != null:
		if p.has("breakable"): node.set_meta("breakable",false)
		else: node.remove_meta("breakable")
	_status_line = "%s #%d %s" % [str(p.id),selected,"breakable" if not p.has("breakable") else "unbreakable"]
	_show_status()

## The whole motif breakable or not (its "breakable"; absent is breakable).
func toggle_motif_breakable() -> void:
	snapshot()
	if bool(data.get("breakable",true)): data.breakable = false
	else: data.erase("breakable")
	_status_line = "Motif %s" % ("breakable" if not data.has("breakable") else "unbreakable: no piece of it breaks")
	_show_status()

func _reseat(k: int) -> void:
	var node := piece_node(k)
	if node == null: return
	var p: Dictionary = data.pieces[k]
	var a: Array = p.at
	var turn := float(p.get("turn",0.0))
	a[1] = snappedf(MotifAuthored.seat(motif.ground_fn(),node,float(a[0]),float(a[2]),turn,float(p.get("sink",MotifAuthored.SINK))),0.001)
	node.transform = Transform3D(Basis(Vector3.UP,deg_to_rad(turn)),Vector3(float(a[0]),float(a[1]),float(a[2])))

func delete_selected() -> void:
	if selected < 0: return
	snapshot()
	forget_piece(selected)
	select(-1)
	refresh_pieces()
	_after_pieces()

func _after_pieces() -> void:
	_show_status()

var _sel_ring: MeshInstance3D = null

func select(k: int) -> void:
	selected = k
	sel_marker = ""
	_show_status()

## A ring round the selected piece's footprint, drawn over everything.
func _show_selection() -> void:
	if _sel_ring == null:
		_sel_ring = MeshInstance3D.new()
		_sel_ring.name = "Selection"
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0,0.9,0.3)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.no_depth_test = true
		_sel_ring.material_override = mat
		add_child(_sel_ring)
	var node := piece_node(selected) if selected >= 0 and editing else null
	_sel_ring.visible = node != null
	if node == null: return
	var box := MotifAuthored.drawn_box(node)
	var r := maxf(Vector2(box.size.x,box.size.z).length()*0.5,0.8)
	var torus := TorusMesh.new()
	torus.inner_radius = r
	torus.outer_radius = r+0.15
	_sel_ring.mesh = torus
	var c := node.global_transform*box.get_center()
	_sel_ring.global_position = Vector3(c.x,node.global_position.y+0.3,c.z)

# --- The land tools (round 2) -------------------------------------------------------------

func set_tool(id_name: String) -> void:
	if not _stroke.is_empty(): release(Vector2.ZERO)
	_drop_run()
	tool = id_name
	if tool != "select":
		armed = ""
		select(-1)
	handle = -1
	_sync_roll()
	_show_handles()
	if _cursor != null: _cursor.visible = false
	_show_status()

func set_radius(r: float) -> void:
	brush_r = clampf(r,0.8,40.0)
	_label_brush()
	_show_cursor(get_viewport().get_mouse_position())

func set_strength(v: float) -> void:
	brush_s = clampf(v,0.05,1.0)
	if panel != null: panel.strength.set_value_no_signal(brush_s)
	_label_brush()

func _label_brush() -> void:
	if roll != null:
		var best := 0
		for i in range(PIP_RADIUS.size()):
			if absf(PIP_RADIUS[i]-brush_r) < absf(PIP_RADIUS[best]-brush_r): best = i
		roll.size_level = best
	_show_status()

## A tool whose reach the wheel and the pips set.
func _sized() -> bool:
	return tool in BRUSHES or tool == "ravine" or STAMPS.has(tool)

## A brush stroke begun at screen point `at`: stored in the file as it is
## drawn (its points on the ground), the land rebuilt live.
func begin_stroke(at: Vector2) -> void:
	var hit := ground_hit(at)
	if hit.is_empty(): return
	snapshot()
	var p: Vector3 = hit.position
	_stroke = {"tool":tool,"r":snappedf(brush_r,0.01),"s":snappedf(brush_s,0.01),"pts":[[snappedf(p.x,0.001),snappedf(p.z,0.001)]]}
	(data.strokes as Array).append(_stroke)
	_stroke_at = Time.get_ticks_msec()
	_want_live = true

## The stroke drawn on to screen point `at`: a point each quarter radius
## (a ravine's each third, at least a metre).
func stroke_to(at: Vector2) -> void:
	var hit := ground_hit(at)
	if hit.is_empty(): return
	var p: Vector3 = hit.position
	var pts: Array = _stroke.pts
	var last: Array = pts[pts.size()-1]
	var gap := maxf(brush_r*(0.33 if str(_stroke.tool) == "ravine" else 0.25),0.5 if str(_stroke.tool) != "ravine" else 1.0)
	if Vector2(p.x,p.z).distance_to(Vector2(float(last[0]),float(last[1]))) < gap: return
	pts.append([snappedf(p.x,0.001),snappedf(p.z,0.001)])
	_stroke_at = Time.get_ticks_msec()
	_want_live = true

## The left button let go: a stroke or a handle drag ends (the full land
## and its dressing follow), else a piece's or marker's drag.
func release(at: Vector2) -> void:
	if not _held_piece.is_empty():
		place_ghost(at)
		return
	if not _stamp.is_empty():
		end_stamp()
		return
	if not _path.is_empty():
		end_path()
		return
	if not _run.is_empty() and bool(_run.get("pressed",false)):
		run_release(at)
		return
	if not _stroke.is_empty():
		_stroke = {}
		_want_live = false
		_changed_at = Time.get_ticks_msec()
		_want_dress = true
		_show_status()
		return
	if handle >= 0 and _dragging:
		_dragging = false
		_want_live = false
		_changed_at = Time.get_ticks_msec()
		_want_dress = true
		_show_status()
		return
	_end_drag()

func handle_drag() -> bool:
	return handle >= 0 and _dragging

## Water poured at screen point `at` (Shift: the pond there taken away).
## Strength is how full (a skim to just under its spill).
func pour_at(at: Vector2, take := false) -> void:
	var hit := ground_hit(at)
	if hit.is_empty(): return
	var p: Vector3 = hit.position
	var waters: Array = data.waters
	if take:
		var ponds: Array = motif.ponds()
		for i in range(ponds.size()):
			if (ponds[i].rect as Rect2).has_point(Vector2(p.x,p.z)) and i < waters.size():
				snapshot()
				waters.remove_at(i)
				_status_line = "Pond taken away"
				dress()
				return
		return
	var found: Dictionary = motif.pour(p.x,p.z,brush_s)
	if found.is_empty():
		_status_line = "No hollow there: the water runs off (raise a rim, lower a bowl)"
		_show_status()
		return
	snapshot()
	waters.append({"at":[snappedf(p.x,0.001),snappedf(p.z,0.001)],"fill":snappedf(brush_s,0.01)})
	_status_line = "Poured: level %.2f m (spills at %.2f)" % [float(found.level),float(found.spill)]
	dress()

## The outline's points (x, z) as stood.
func outline_points() -> Array:
	return motif.outline()

## The outline made the file's own (the preset's baked in) before a handle
## edit.
func _own_outline() -> void:
	if (data.outline as Array).size() >= 3: return
	var own: Array = []
	for q: Vector2 in motif.outline(): own.append([snappedf(q.x,0.001),snappedf(q.y,0.001)])
	data.outline = own

## The handle under screen point `at` (-1 none).
func handle_hit(at: Vector2) -> int:
	var best := -1
	var near := PICK_PX
	var ring := outline_points()
	for i in range(ring.size()):
		var q: Vector2 = ring[i]
		var w := Vector3(q.x,motif.ground(q.x,q.y)+0.3,q.y)
		if camera.is_position_behind(w): continue
		var d := camera.unproject_position(w).distance_to(at)
		if d < near:
			near = d
			best = i
	return best

## Outline tool: a handle picked and dragged; Shift+click the ground adds
## a point on the nearest edge; Alt+click a handle (or Delete) takes it
## away.
func outline_click(at: Vector2, add := false, take := false) -> void:
	var k := handle_hit(at)
	if k >= 0 and take:
		remove_handle(k)
		return
	if k >= 0:
		snapshot()
		_own_outline()
		handle = k
		var q: Vector2 = outline_points()[k]
		_handle_y = motif.ground(q.x,q.y)
		_dragging = true
		_show_handles()
		return
	if add:
		var hit := ground_hit(at)
		if hit.is_empty(): return
		snapshot()
		_own_outline()
		var p := Vector2(hit.position.x,hit.position.z)
		var ring: Array = data.outline
		var best := 0
		var near := INF
		for i in range(ring.size()):
			var a := Vector2(float(ring[i][0]),float(ring[i][1]))
			var b := Vector2(float(ring[(i+1)%ring.size()][0]),float(ring[(i+1)%ring.size()][1]))
			var d := p.distance_to(Geometry2D.get_closest_point_to_segment(p,a,b))
			if d < near:
				near = d
				best = i
		ring.insert(best+1,[snappedf(p.x,0.001),snappedf(p.y,0.001)])
		handle = best+1
		dress()
		return
	handle = -1
	_show_handles()

func remove_handle(k: int) -> void:
	_own_outline()
	var ring: Array = data.outline
	if ring.size() <= 5:
		_status_line = "An outline keeps 5 points at least"
		_show_status()
		return
	snapshot()
	ring.remove_at(k)
	handle = -1
	dress()

## The dragged handle to under screen point `at` (on the level plane it
## was picked at, so it moves where the mouse points even off the land).
func handle_to(at: Vector2) -> void:
	var from := camera.project_ray_origin(at)
	var way := camera.project_ray_normal(at)
	if absf(way.y) < 0.01: return
	var t := (_handle_y-from.y)/way.y
	if t <= 0.0: return
	var p := from+way*t
	var ring: Array = data.outline
	ring[handle] = [snappedf(p.x,0.001),snappedf(p.z,0.001)]
	_want_live = true

func reset_outline() -> void:
	if (data.outline as Array).is_empty(): return
	snapshot()
	data.outline = []
	handle = -1
	dress()

## The outline's handles (the outline tool's), the picked one yellow.
func _show_handles() -> void:
	if _handles == null:
		_handles = Node3D.new()
		_handles.name = "OutlineHandles"
		add_child(_handles)
	for c: Node in _handles.get_children(): c.free()
	if tool != "outline" or not editing or motif == null: return
	var ring := outline_points()
	var line := PackedVector3Array()
	for i in range(ring.size()):
		var q: Vector2 = ring[i]
		var w := Vector3(q.x,motif.ground(q.x,q.y)+0.3,q.y)
		line.append(w)
		var ball := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.45 if i == handle else 0.32
		mesh.height = mesh.radius*2.0
		ball.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.no_depth_test = true
		mat.albedo_color = Color(1.0,0.9,0.3) if i == handle else Color(0.4,0.9,1.0)
		ball.material_override = mat
		ball.position = w
		_handles.add_child(ball)
	# The outline drawn as a line through them.
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for w: Vector3 in line: im.surface_add_vertex(w)
	if not line.is_empty(): im.surface_add_vertex(line[0])
	im.surface_end()
	var drawn := MeshInstance3D.new()
	drawn.mesh = im
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.no_depth_test = true
	lm.albedo_color = Color(0.4,0.9,1.0,0.8)
	drawn.material_override = lm
	_handles.add_child(drawn)

## The brush's ring on the ground under screen point `at`.
func _show_cursor(at: Vector2) -> void:
	if not _stamp.is_empty(): return
	if _cursor == null:
		_cursor = MeshInstance3D.new()
		_cursor.name = "BrushCursor"
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.no_depth_test = true
		mat.albedo_color = Color(1.0,1.0,1.0,0.85)
		_cursor.material_override = mat
		add_child(_cursor)
	var on := editing and (tool in BRUSHES or tool in ["water","ravine"] or STAMPS.has(tool)) and _held_piece.is_empty()
	var hit := ground_hit(at) if on else {}
	_cursor.visible = on and not hit.is_empty()
	if not _cursor.visible: return
	var r := brush_r*(RAVINE_HALF_SHOWN if tool == "ravine" else 1.0) if tool != "water" else 0.6
	if STAMPS.has(tool): r = brush_r*2.0
	var torus := TorusMesh.new()
	torus.inner_radius = r
	torus.outer_radius = r+maxf(0.08,r*0.03)
	_cursor.mesh = torus
	_cursor.global_position = hit.position+Vector3.UP*0.15
	(_cursor.material_override as StandardMaterial3D).albedo_color = {"raise":Color(1.0,0.85,0.4),"lower":Color(0.5,0.75,1.0),"smooth":Color(0.8,1.0,0.8),"flatten":Color(1.0,1.0,1.0),"ravine":Color(1.0,0.5,0.35),"water":Color(0.3,0.7,1.0)}.get(tool,Color(0.95,0.85,0.65))
const RAVINE_HALF_SHOWN := MotifAuthored.RAVINE_HALF

# --- Undo ------------------------------------------------------------------------------------

## The data as it stands, kept for undo (before each edit); redo cleared.
func snapshot() -> void:
	_undo.append(data.duplicate(true))
	if _undo.size() > UNDO_MOST: _undo.pop_front()
	_redo.clear()

func undo() -> void:
	_finish_cut()
	if not _stamp.is_empty() or not _path.is_empty(): release(Vector2.ZERO)
	if _undo.is_empty(): return
	if not _stroke.is_empty(): release(Vector2.ZERO)
	ClaySound.cue(&"ui_undo")
	_redo.append(data.duplicate(true))
	_apply_data(_undo.pop_back())
	_status_line = "Undo (%d more)" % _undo.size()
	_show_status()

func redo() -> void:
	_finish_cut()
	if _redo.is_empty(): return
	ClaySound.cue(&"ui_undo")
	_undo.append(data.duplicate(true))
	_apply_data(_redo.pop_back())
	_status_line = "Redo (%d more)" % _redo.size()
	_show_status()

## `d` made the motif's: the panel set to it, the land stood again.
func _apply_data(d: Dictionary) -> void:
	var preset_was := str(data.get("preset",""))
	data = d
	_dragging = false
	handle = -1
	select(-1)
	if panel != null:
		if str(data.preset) != preset_was: panel.fill()
		else: panel.sync()
	dress()

## The landform preset changed: its sliders at their defaults (the size
## kept), the strokes and waters kept, the outline the preset's.
func set_preset(name_: String) -> void:
	if name_ == str(data.preset) or not MotifAuthored.PRESETS.has(name_): return
	snapshot()
	data.preset = name_
	data.sliders = {}
	for spec: Array in MotifAuthored.PRESETS[name_]: data.sliders[spec[0]] = float(spec[5])
	data.outline = []
	if panel != null: panel.fill()
	dress()
	frame_hill()

# --- The markers ---------------------------------------------------------------------------

func _build_markers() -> void:
	for k: String in MARKERS:
		var spec: Array = MARKERS[k]
		var n := Node3D.new()
		n.name = "Marker_"+k
		var mat := StandardMaterial3D.new()
		mat.albedo_color = spec[1]
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var pole := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.08
		cyl.bottom_radius = 0.08
		cyl.height = 3.0
		pole.mesh = cyl
		pole.position.y = 1.5
		pole.material_override = mat
		n.add_child(pole)
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.55
		torus.outer_radius = 0.75
		ring.mesh = torus
		ring.position.y = 0.1
		ring.material_override = mat
		n.add_child(ring)
		var label := Label3D.new()
		label.text = str(spec[0])
		label.font_size = 48
		label.outline_size = 12
		label.pixel_size = 0.01
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.modulate = spec[1]
		label.position.y = 3.6
		n.add_child(label)
		if k != "spawn":
			var arrow := MeshInstance3D.new()
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.35
			cone.height = 1.0
			arrow.mesh = cone
			arrow.material_override = mat
			n.add_child(arrow)
			_arrows[k] = arrow
		add_child(n)
		_marker_nodes[k] = n

func _place_markers() -> void:
	if _marker_nodes.is_empty(): return
	for k: String in MARKERS:
		var a: Array = data.markers[k]
		(_marker_nodes[k] as Node3D).position = Vector3(float(a[0]),float(a[1]),float(a[2]))
	for r: Dictionary in motif.rims():
		var arrow: MeshInstance3D = _arrows.get("rim_"+str(r.name))
		if arrow == null: continue
		var f: Vector3 = r.face
		# Lying along the way out, a metre up.
		arrow.transform = Transform3D(Basis(Vector3.UP.cross(f).normalized(),-PI*0.5),f*1.2+Vector3.UP*1.0)

func _set_markers_visible(on: bool) -> void:
	for k: String in _marker_nodes: (_marker_nodes[k] as Node3D).visible = on

# --- Save and load --------------------------------------------------------------------------

func save() -> String:
	var slug := panel.slug_edit.text.strip_edges().to_lower().replace(" ","_") if panel != null else str(data.slug)
	if slug == "": slug = "untitled"
	if panel != null: panel.slug_edit.text = slug
	data.slug = slug
	if str(data.get("name","")) == "" or str(data.name) == "Untitled": data.name = slug.capitalize()
	var path := MotifAuthored.path_of(slug)
	var err := MotifAuthored.write(path,data)
	if err == OK: ClaySound.cue(&"ui_page")
	_status_line = ("Saved %s" % path) if err == OK else ("Save failed (%s)" % error_string(err))
	_show_status()
	print("motif editor: %s" % _status_line)
	return path

func load_motif(slug: String) -> bool:
	var path := MotifAuthored.path_of(slug)
	if not FileAccess.file_exists(path): return false
	var d := MotifAuthored.read(path)
	if d.is_empty(): return false
	snapshot()
	data = d
	if panel != null:
		panel.slug_edit.text = str(data.slug)
		panel.fill()
	select(-1)
	dress()
	frame_hill()
	_status_line = "Loaded %s" % path
	_show_status()
	return true

func reroll() -> void:
	snapshot()
	data.seed = randi()%99999+1
	dress()
	if panel != null: panel.sync()

# --- The UI (round 3: the early game's) ----------------------------------------------------

var _status_line := ""

func _build_editor_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.name = "EditorUI"
	_ui.layer = 8
	add_child(_ui)
	feel = Feel.new()
	add_child(feel)
	feel.setup(self)
	panel = LandformPanel.new()
	_ui.add_child(panel)
	panel.setup(self)
	roll = ToolRoll.new()
	_ui.add_child(roll)
	roll.set_anchors_preset(Control.PRESET_TOP_LEFT)
	roll.want(true)
	palette = EditorPalette.new()
	_ui.add_child(palette)
	palette.setup_editor(self)
	_label_brush()
	# The thumbnails, a few a frame once the palette is first opened (none
	# headless: nothing renders there).
	if DisplayServer.get_name() != "headless":
		for entry: Array in MotifAuthored.palette(): _thumbs_left.append(str(entry[0]))

## The roll stood under the panel (its own height centred in its rect, so
## the rect is sized to put it there), and the shake.
func _feel_step(delta: float) -> void:
	if roll != null:
		var screen := get_viewport().get_visible_rect().size
		var extent: float = roll._height()*roll.ui_scale
		var top := panel.bottom()+18.0*roll.ui_scale if panel != null else (screen.y-extent)*0.5
		top = minf(top,screen.y-extent-10.0*roll.ui_scale)
		roll.position = Vector2.ZERO
		roll.size = Vector2(screen.x,top*2.0+extent)
		roll.quiet = not _stamp.is_empty() or not _path.is_empty() or not _stroke.is_empty() or not _held_piece.is_empty()
	if feel != null and not _looking:
		camera.global_transform = feel.shake(_cam_base,delta)
	var made := 0
	while not _thumbs_left.is_empty() and made < 3 and palette != null and palette.shown > 0.0:
		var id := str(_thumbs_left.pop_front())
		var model := MotifAuthored.make(id,7,0.3)
		if model == null: continue
		palette.set_thumb(id,feel.render(model))
		made += 1

## A click on the roll: a pocket (its tool; the held one again puts it
## down), a mode on the fan, a size pip. True if the roll took it.
func roll_click(at: Vector2) -> bool:
	if roll == null or not roll.contains_pointer(at): return false
	var mode: String = roll.mode_at(at)
	if mode != "":
		var t := str(MODE_TOOL.get(str(roll.tool)+":"+mode,""))
		if t != "":
			set_tool(t)
			ClaySound.cue(&"ui_pick")
		return true
	var pip: int = roll.pip_at(at)
	if pip >= 0:
		set_radius(PIP_RADIUS[pip])
		ClaySound.cue(&"ui_size")
		return true
	var pocket: String = roll.tool_at(at)
	if pocket != "":
		if not POCKET_TOOL.has(pocket):
			roll.not_yet(pocket)
			say("Not in the editor yet: %s" % str(preload("res://scripts/hud_icons.gd").item(pocket).get("label",pocket)))
		elif str(POCKET[tool][0]) == pocket: set_tool("select")
		else: set_tool(str(POCKET_TOOL[pocket]))
		ClaySound.cue(&"ui_pick")
	return true

## The roll shows the tool in hand: its pocket pressed, its modes fanned.
func _sync_roll() -> void:
	if roll == null: return
	var pm: Array = POCKET.get(tool,["",""])
	roll.tool = str(pm[0])
	roll.set_modes(POCKET_MODES.get(str(pm[0]),[]),str(pm[1]))
	roll.held_tint = {"hand":Color("e0a07a"),"paddle":Color("c8a070"),"wire":Color("b08060"),"can":Color("7fb0d0")}.get(str(pm[0]),Color("d8c4a0"))

## The palette's verbs.
func pick_tool(id_name: String) -> void:
	set_tool(id_name)

func arm(id_name: String) -> void:
	set_tool("select")
	armed = id_name
	_show_status()

func palette_opened() -> void:
	if _cursor != null: _cursor.visible = false

func world_verb(id_name: String) -> String:
	match id_name:
		"undo": undo()
		"redo": redo()
		"save": save()
		"play": toggle_play()
		"dress": dress()
		"reroll": reroll()
		"frame": frame_hill()
		_: return "Not a verb here"
	return ""

func say(line: String) -> void:
	_status_line = line
	_show_status()

## The landform panel's sliders.
func slider_began() -> void:
	snapshot()
	_slider_undo_at = Time.get_ticks_msec()
	_slider_drag = true

func slider_moved(key: String, value: float) -> void:
	# A click or a nudge (not a drag) is its own undo step, closely spaced
	# ones one step.
	if not _slider_drag and Time.get_ticks_msec()-_slider_undo_at > 500: snapshot()
	_slider_undo_at = Time.get_ticks_msec()
	data.sliders[key] = value
	if panel != null: panel.sync()
	_changed_at = Time.get_ticks_msec()
	_want_bare = true
	if not _slider_drag: _want_dress = true

func slider_ended() -> void:
	_slider_drag = false
	_want_dress = true

func _show_status() -> void:
	_show_selection()
	if panel == null: return
	var hint := str(HINTS.get(tool,""))
	if armed != "": hint = "Placing %s: click the ground (Shift keeps placing) · Esc stops" % armed
	elif not _held_piece.is_empty(): hint = "Carrying %s: let go over the ground to set it down · Esc drops it" % str(_held_piece.id)
	var sel := ""
	if sel_marker != "": sel = " · marker %s" % sel_marker
	elif selected >= 0 and selected < (data.pieces as Array).size():
		var p: Dictionary = data.pieces[selected]
		sel = " · %s #%d turned %d deg%s" % [str(p.id),selected,int(p.get("turn",0.0))," · unbreakable" if not bool(p.get("breakable",true)) else ""]
	var line := "%d strokes · %d ponds · %d pieces · radius %.1f m · live %d ms, dressed %d ms%s" % [(data.strokes as Array).size(),(data.waters as Array).size(),(data.pieces as Array).size(),brush_r,live_ms,dress_ms,sel]
	if _status_line != "": line = _status_line+"   ·   "+line
	panel.say(hint,line,tool in BRUSHES or tool in ["ravine","water"] or STAMPS.has(tool))
	panel.sync()

# --- Stamps (round 3: the old Mountain, Hills, Crater, Chisel mesa, Island) ---------------

## A stamp set down at screen point `at` at the default size (twice the
## brush radius); dragging out sizes it (`size_stamp`), live.
func begin_stamp(at: Vector2) -> void:
	var form := str(STAMPS[tool])
	var hit := ground_hit(at)
	if hit.is_empty() and form == "island":
		# Off the edge: the level of the land's edge nearest.
		_stamp_outline = motif.outline().duplicate()
		var guess := _plane_hit(at,float(motif.crest_top())*0.5)
		if guess != Vector3.INF: hit = {"position":_plane_hit(at,_edge_ground(Vector2(guess.x,guess.z)))}
		if not hit.is_empty() and hit.position == Vector3.INF: hit = {}
	if hit.is_empty(): return
	snapshot()
	var p: Vector3 = hit.position
	_stamp_mid = p
	_stamp_outline = motif.outline().duplicate()
	_stamp = {"tool":"stamp","form":form,"at":[snappedf(p.x,0.001),snappedf(p.z,0.001)],"r":0.0,"h":0.0,"seed":randi()%9000+1}
	# The level a mesa or an island builds to, read once off the land
	# before the stamp (read live it would stand on itself and climb).
	_stamp_outline = motif.outline().duplicate()
	_stamp_base = float(motif.ground(p.x,p.z)) if form == "mesa" else _edge_ground(Vector2(p.x,p.z))
	(data.strokes as Array).append(_stamp)
	_stamp_press = at
	_size_to(brush_r*2.0,1.0)
	stamps_made += 1
	feel.cue(&"poke",p,0.6)

## Screen point `at` on the level plane at height `y` (INF: none).
func _plane_hit(at: Vector2, y: float) -> Vector3:
	var from := camera.project_ray_origin(at)
	var way := camera.project_ray_normal(at)
	if absf(way.y) < 0.01: return Vector3.INF
	var t := (y-from.y)/way.y
	return from+way*t if t > 0.0 else Vector3.INF

## The footprint is the ring shown before the click (twice the brush
## radius: the pips, the wheel, [ ]); dragging up pulls it taller (a
## crater: dragging down digs it deeper), as the old Mountain's pull did.
## The footprint never follows the pointer (it once did: a pull up the
## screen ran far over the ground and one stamp covered the whole isle).
func size_stamp(at: Vector2) -> void:
	var dy := _stamp_press.y-at.y
	if str(_stamp.form) == "crater": dy = -dy
	_size_to(float(_stamp.r),clampf(1.0+dy/STAMP_PULL_PX,0.25,3.0))

## The stamp at radius `r`, its height `pull` x the strength's, the land live.
func _size_to(r: float, pull: float) -> void:
	var form := str(_stamp.form)
	r = clampf(r,2.0,40.0)
	var h := r*float(STAMP_TALL[form])*(0.5+brush_s)*pull
	if form == "hills": h = minf(h,6.0)
	_stamp.r = snappedf(r,0.01)
	_stamp.h = snappedf(h,0.01)
	if form in ["mesa","island"]:
		# A level top: the ground under the middle (an island: under the
		# old edge nearest it, so it grows out at the land's height).
		_stamp.y = snappedf(_stamp_base+h*(1.0 if form == "mesa" else 0.35),0.001)
	if form == "island": _grow_outline(_circle(Vector2(_stamp_mid.x,_stamp_mid.z),r*0.92))
	_want_live = true
	_ring_at(_stamp_mid,r)
	feel.hold(str(STAMP_FEEL[form]),-h if form == "crater" else h,_stamp_mid)

## The brush ring held round a stamp's footprint while it is sized.
func _ring_at(p: Vector3, r: float) -> void:
	if _cursor == null: return
	var torus := TorusMesh.new()
	torus.inner_radius = r
	torus.outer_radius = r+maxf(0.08,r*0.03)
	_cursor.mesh = torus
	_cursor.global_position = p+Vector3.UP*0.15
	_cursor.visible = true

func end_stamp() -> void:
	var form := str(_stamp.form)
	feel.rest()
	feel.cue(&"lurch" if form in ["mountain","mesa","crater"] else &"rock_settle",_stamp_mid,clampf(float(_stamp.h)/8.0,0.3,1.0))
	feel.kick(0.25 if form == "mountain" else 0.15)
	_status_line = "%s stamped: %.0f m across, %.1f m %s" % [form.capitalize(),float(_stamp.r)*2.0,float(_stamp.h),"deep" if form == "crater" else "tall"]
	_stamp = {}
	_want_live = false
	_changed_at = Time.get_ticks_msec()
	_want_dress = true
	_show_status()

## The ground at the point of the outline (before this edit) nearest `q`.
func _edge_ground(q: Vector2) -> float:
	var ring := PackedVector2Array(_stamp_outline if not _stamp_outline.is_empty() else motif.outline())
	if Geometry2D.is_point_in_polygon(q,ring): return float(motif.ground(q.x,q.y))
	var best := ring[0]
	var near := INF
	for i in range(ring.size()):
		var c := Geometry2D.get_closest_point_to_segment(q,ring[i],ring[(i+1)%ring.size()])
		if c.distance_to(q) < near:
			near = c.distance_to(q)
			best = c
	# A step inside, so the ground read is the land's, not its fall-off.
	var inward := (KitLand.centre_of(Array(ring))-best).normalized()
	var p := best+inward*1.5
	return float(motif.ground(p.x,p.y))

static func _circle(c: Vector2, r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := clampi(int(TAU*r/2.5),10,40)
	for k in range(n): out.append(c+Vector2.from_angle(TAU*k/n)*r)
	return out

## The outline before this edit grown round `loop` (their union, its
## largest outer ring, points at least 1.8 m apart); unchanged when the
## loop is all inside.
func _grow_outline(loop: PackedVector2Array) -> bool:
	var old := PackedVector2Array(_stamp_outline)
	var merged := Geometry2D.merge_polygons(old,loop)
	var best := PackedVector2Array()
	var area := 0.0
	for poly: PackedVector2Array in merged:
		if Geometry2D.is_polygon_clockwise(poly) != Geometry2D.is_polygon_clockwise(old): continue
		var a := absf(_area(poly))
		if a > area:
			area = a
			best = poly
	if best.size() < 3 or area <= absf(_area(old))+1.0: return false
	var ring: Array = []
	for q: Vector2 in best:
		if not ring.is_empty() and q.distance_to(Vector2(float(ring[-1][0]),float(ring[-1][1]))) < 1.8: continue
		ring.append([snappedf(q.x,0.001),snappedf(q.y,0.001)])
	if ring.size() >= 3: data.outline = ring
	return true

static func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in range(poly.size()):
		var p := poly[i]
		var q := poly[(i+1)%poly.size()]
		a += p.x*q.y-q.x*p.y
	return a*0.5

# --- Drawn paths (round 3: the old Ravine "wire" and the Island's draw) --------------------

## The longest gap (m) between a path's ends that still closes it as a
## loop, and the shortest loop.
const LOOP_GAP := 5.0
const LOOP_MIN := 14.0
## The cut runs this fast (m/s) after the release, at least / at most
## this long (s).
const CUT_SPEED := 22.0
const CUT_TIME := Vector2(0.45,1.6)

func begin_path(at: Vector2) -> void:
	var hit := ground_hit(at)
	if hit.is_empty(): return
	_finish_cut()
	var p: Vector3 = hit.position
	_path = {"tool":tool,"pts":[Vector2(p.x,p.z)],"ys":[p.y]}
	_draw_path()
	if tool == "ravine": feel.cue(&"wire_start",p,0.7)

func path_to(at: Vector2) -> void:
	var hit := ground_hit(at)
	if hit.is_empty(): return
	var p: Vector3 = hit.position
	var pts: Array = _path.pts
	if Vector2(p.x,p.z).distance_to(pts[-1]) < 1.0: return
	pts.append(Vector2(p.x,p.z))
	(_path.ys as Array).append(p.y)
	_draw_path()

## The path's line on the ground while it is drawn.
func _draw_path() -> void:
	if _path_line == null:
		_path_line = MeshInstance3D.new()
		_path_line.name = "PathLine"
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.no_depth_test = true
		mat.albedo_color = Color(1.0,0.86,0.6,0.9)
		_path_line.material_override = mat
		add_child(_path_line)
	var im := ImmediateMesh.new()
	var pts: Array = _path.get("pts",[])
	_path_line.visible = pts.size() >= 2
	if pts.size() >= 2:
		im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for i in range(pts.size()): im.surface_add_vertex(Vector3(pts[i].x,float(_path.ys[i])+0.25,pts[i].y))
		im.surface_end()
	_path_line.mesh = im

func _path_length(pts: Array) -> float:
	var n := 0.0
	for i in range(1,pts.size()): n += (pts[i] as Vector2).distance_to(pts[i-1])
	return n

func end_path() -> void:
	var pts: Array = _path.pts
	var kind := str(_path.tool)
	_path = {}
	_draw_path()
	var length := _path_length(pts)
	var loop := pts.size() >= 6 and length >= LOOP_MIN and (pts[0] as Vector2).distance_to(pts[-1]) <= maxf(LOOP_GAP,brush_r)
	if kind == "new_land":
		if length < 8.0:
			say("Draw a loop out past the edge for new land")
			return
		grow_land(pts)
	elif loop: make_lake(pts)
	elif length >= 3.0: cut_ravine(pts)
	_show_status()

## A ravine along the drawn line, carved behind a running head (the old
## Ravine's cut drawn through the clay); one undo step.
func cut_ravine(pts: Array) -> void:
	snapshot()
	var all: Array = []
	var gap := maxf(brush_r*0.33,1.0)
	for q: Vector2 in pts:
		if all.is_empty() or q.distance_to(Vector2(float(all[-1][0]),float(all[-1][1]))) >= gap: all.append([snappedf(q.x,0.001),snappedf(q.y,0.001)])
	var last: Vector2 = pts[-1]
	if Vector2(float(all[-1][0]),float(all[-1][1])).distance_to(last) > 0.3: all.append([snappedf(last.x,0.001),snappedf(last.y,0.001)])
	var stroke := {"tool":"ravine","r":snappedf(brush_r,0.01),"s":snappedf(brush_s,0.01),"pts":all.slice(0,2)}
	(data.strokes as Array).append(stroke)
	var length := _path_length(pts)
	_cut = {"stroke":stroke,"all":all,"began":Time.get_ticks_msec(),"time":clampf(length/CUT_SPEED,CUT_TIME.x,CUT_TIME.y),"length":length,
		"box":MotifAuthored.Ravine.new({"tool":"ravine","r":stroke.r,"s":stroke.s,"pts":all},motif.ground_fn()).box}
	_want_live = true

func _cut_step() -> void:
	if _cut.is_empty(): return
	var share := clampf(float(Time.get_ticks_msec()-int(_cut.began))/1000.0/float(_cut.time),0.0,1.0)
	share = 1.0-pow(1.0-share,1.6)
	var all: Array = _cut.all
	var n := clampi(int(ceil(share*all.size())),2,all.size())
	var stroke: Dictionary = _cut.stroke
	if n != (stroke.pts as Array).size():
		stroke.pts = all.slice(0,n)
		_want_live = true
	var head: Array = all[n-1]
	feel.cutting(share,float(_cut.length),Vector3(float(head[0]),motif.ground(float(head[0]),float(head[1])),float(head[1])))
	if share >= 1.0: _finish_cut()

func _finish_cut() -> void:
	if _cut.is_empty(): return
	(_cut.stroke as Dictionary).pts = _cut.all
	_status_line = "Ravine cut: %.0f m" % float(_cut.length)
	_cut = {}
	feel.rest()
	_want_live = false
	_changed_at = Time.get_ticks_msec()
	_want_dress = true
	_show_status()

## A lake in a drawn loop: a basin dug inside it (strength: deeper) and
## water poured into it, in one step.
func make_lake(pts: Array) -> void:
	snapshot()
	var loop: Array = []
	for q: Vector2 in pts:
		if loop.is_empty() or q.distance_to(Vector2(float(loop[-1][0]),float(loop[-1][1]))) >= 1.5: loop.append([snappedf(q.x,0.001),snappedf(q.y,0.001)])
	var poly := PackedVector2Array(pts)
	var box := Rect2(poly[0],Vector2.ZERO)
	for q: Vector2 in poly: box = box.expand(q)
	var depth := snappedf(1.2+brush_s*4.0,0.01)
	(data.strokes as Array).append({"tool":"basin","pts":loop,"depth":depth,"bank":snappedf(clampf(minf(box.size.x,box.size.y)*0.3,1.5,6.0),0.01)})
	motif = MotifAuthored.from_data(data)
	var inside := _inside_point(poly,box)
	var found: Dictionary = motif.pour(inside.x,inside.y,0.85)
	if found.is_empty():
		_status_line = "Basin dug, but it holds no water (the loop runs off the land?)"
	else:
		(data.waters as Array).append({"at":[snappedf(inside.x,0.001),snappedf(inside.y,0.001)],"fill":0.85})
		_status_line = "Lake: %.1f m deep, level %.2f m" % [depth,float(found.level)]
		lakes_made += 1
	var mid := Vector3(inside.x,float(motif.ground(inside.x,inside.y)),inside.y)
	feel.cue(&"water_splash",mid,0.9)
	feel.cue(&"lurch",mid,0.6)
	feel.kick(0.18)
	dress()

## A point well inside `poly`: its middle if inside, else the inside cell
## furthest from the edge.
func _inside_point(poly: PackedVector2Array, box: Rect2) -> Vector2:
	var c := box.get_center()
	if Geometry2D.is_point_in_polygon(c,poly) and KitLand.edge_distance(c,poly) > 2.0: return c
	var best := c
	var far := -1.0
	var x := box.position.x
	while x < box.end.x:
		var z := box.position.y
		while z < box.end.y:
			var q := Vector2(x,z)
			if Geometry2D.is_point_in_polygon(q,poly):
				var e := KitLand.edge_distance(q,poly)
				if e > far:
					far = e
					best = q
			z += 1.0
		x += 1.0
	return best

## New land in a drawn loop: the outline grown round it and the ground
## built up to the old land's height where the loop leaves it.
func grow_land(pts: Array) -> void:
	snapshot()
	_stamp_outline = motif.outline().duplicate()
	var old := PackedVector2Array(_stamp_outline)
	var loop := PackedVector2Array()
	for q: Vector2 in pts:
		if loop.is_empty() or q.distance_to(loop[-1]) >= 1.5: loop.append(q)
	var level := INF
	for q: Vector2 in loop:
		if Geometry2D.is_point_in_polygon(q,old) and KitLand.edge_distance(q,old) > 1.0: level = minf(level,float(motif.ground(q.x,q.y)))
	if level == INF: level = _edge_ground(KitLand.centre_of(Array(loop)))
	if not _grow_outline(loop):
		_undo.pop_back()
		say("That loop is inside the land: draw it out past the edge")
		return
	var ring: Array = []
	for q: Vector2 in loop: ring.append([snappedf(q.x,0.001),snappedf(q.y,0.001)])
	(data.strokes as Array).append({"tool":"fill","pts":ring,"y":snappedf(level,0.001),"bank":2.0})
	_status_line = "New land: the isle grown to the loop, at %.1f m" % level
	feel.cue(&"lurch",Vector3(loop[0].x,level,loop[0].y),0.7)
	feel.kick(0.2)
	dress()

# --- Trash (round 3: the old trash can) -----------------------------------------------------

## Takes away what is under screen point `at`: a piece, else a stamp whose
## middle is near, else a pond, else a lake's or new land's loop.
func trash_at(at: Vector2) -> void:
	var run := run_hit(at)
	if run >= 0:
		snapshot()
		var kind := str(data.runs[run].run)
		(data.runs as Array).remove_at(run)
		if (data.runs as Array).is_empty(): data.erase("runs")
		refresh_pieces()
		say("%s run taken away" % kind.capitalize())
		feel.cue(&"crumble",camera.global_position,0.6)
		return
	var k := piece_hit(at)
	if k >= 0:
		snapshot()
		forget_piece(k)
		select(-1)
		refresh_pieces()
		say("Piece taken away")
		feel.cue(&"crumble",camera.global_position,0.6)
		return
	var hit := ground_hit(at)
	if hit.is_empty(): return
	var q := Vector2(hit.position.x,hit.position.z)
	var strokes: Array = data.strokes
	var best := -1
	var near := INF
	for i in range(strokes.size()):
		var s: Dictionary = strokes[i]
		if str(s.get("tool","")) != "stamp": continue
		var a: Array = s.at
		var d := q.distance_to(Vector2(float(a[0]),float(a[1])))
		if d < maxf(float(s.r)*0.6,2.5) and d < near:
			near = d
			best = i
	if best >= 0:
		snapshot()
		var form := str(strokes[best].form)
		strokes.remove_at(best)
		say("%s stamp taken away" % form.capitalize())
		feel.cue(&"crumble",hit.position,0.8)
		dress()
		return
	var ponds: Array = motif.ponds()
	var waters: Array = data.waters
	for i in range(ponds.size()):
		if (ponds[i].rect as Rect2).has_point(q) and i < waters.size():
			snapshot()
			waters.remove_at(i)
			# Its basin goes with it.
			for j in range(strokes.size()-1,-1,-1):
				var s: Dictionary = strokes[j]
				if str(s.get("tool","")) == "basin" and Geometry2D.is_point_in_polygon(q,_loop_of(s)):
					strokes.remove_at(j)
					break
			say("Pond taken away")
			feel.cue(&"water_pop",hit.position,0.8)
			dress()
			return
	for j in range(strokes.size()-1,-1,-1):
		var s: Dictionary = strokes[j]
		if str(s.get("tool","")) in ["basin","fill"] and Geometry2D.is_point_in_polygon(q,_loop_of(s)):
			snapshot()
			strokes.remove_at(j)
			say("%s taken away (the outline stays: Outline tool to pull it back)" % ("Lake bed" if str(s.tool) == "basin" else "New land"))
			dress()
			return
	say("Nothing there to take away")

static func _loop_of(s: Dictionary) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Array in s.get("pts",[]): out.append(Vector2(float(p[0]),float(p[1])))
	return out

# --- A piece carried in from the palette (its ghost) ----------------------------------------

func begin_ghost(id_name: String, at: Vector2) -> void:
	set_tool("select")
	armed = ""
	var seed_value := randi()%9000+1
	var node := MotifAuthored.make(id_name,seed_value,_weather_new)
	if node == null: return
	node.name = "Ghost"
	for g: GeometryInstance3D in node.find_children("*","GeometryInstance3D",true,false):
		g.transparency = 0.45
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for b: CollisionObject3D in node.find_children("*","CollisionObject3D",true,false):
		b.collision_layer = 0
		b.collision_mask = 0
	add_child(node)
	_held_piece = {"id":id_name,"seed":seed_value,"node":node}
	ghost_to(at)
	ClaySound.cue(&"ui_take")
	_show_status()

func ghost_to(at: Vector2) -> void:
	var node: Node3D = _held_piece.node
	var hit := ground_hit(at)
	var snap := find_snap(at,hit)
	_held_piece.snap = snap
	if not snap.is_empty():
		node.visible = true
		node.transform = Transform3D(Basis(Vector3.UP,deg_to_rad(float(snap.turn))),snap.at)
		_show_snap(snap)
		return
	_show_snap({})
	node.visible = not hit.is_empty()
	if hit.is_empty(): return
	var p: Vector3 = hit.position
	var turn := float(_held_piece.get("turn",0.0))
	var y := MotifAuthored.seat(motif.ground_fn(),node,p.x,p.z,turn)
	node.transform = Transform3D(Basis(Vector3.UP,deg_to_rad(turn)),Vector3(p.x,y,p.z))

## The ghost set down where it hangs (or dropped, off the land).
func place_ghost(at: Vector2) -> void:
	ghost_to(at)
	var node: Node3D = _held_piece.node
	var id_name := str(_held_piece.id)
	var seed_value := int(_held_piece.seed)
	var on := node.visible
	var p := node.position
	var turn := rad_to_deg(node.basis.get_euler().y)
	var snap: Dictionary = _held_piece.get("snap",{})
	_drop_ghost()
	if not on:
		say("Dropped off the land: nothing placed")
		return
	snapshot()
	var k := place_piece(id_name,p,seed_value,turn,snap)
	_pop(k)
	if snap.is_empty(): say("Placed %s" % id_name)
	else: say("Placed %s onto %s" % [id_name,str(snap.label)])

func _drop_ghost() -> void:
	_show_snap({})
	if _held_piece.is_empty(): return
	var node: Node3D = _held_piece.node
	remove_child(node)
	node.queue_free()
	_held_piece = {}
	_show_status()

## A placed piece pops in (the old grow-in): from small, overshooting, and
## a knock or a rustle.
func _pop(k: int) -> void:
	var node := piece_node(k)
	if node == null: return
	var full := node.scale
	node.scale = full*0.55
	var tw := create_tween()
	tw.tween_property(node,"scale",full,0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var id_name := str((data.pieces[k] as Dictionary).id)
	feel.cue(&"plant" if id_name.begins_with("tree_") else &"stone_drop",node.global_position,0.8)
	if not id_name.begins_with("tree_"): feel.kick(0.08)

# --- The ghost (live editing) ------------------------------------------------------------

## The motif whose land shows now (the ghost's "before").
func _base_motif() -> RefCounted:
	if _shown != null and _shown_motif != null: return _shown_motif
	if motifs != null and not motifs.isles.is_empty(): return motifs.isles[0].motif
	return motif

## Where the edit in hand can change the ground (none: an empty rect).
func _edit_box() -> Rect2:
	if not _stamp.is_empty():
		var c := Vector2(_stamp_mid.x,_stamp_mid.z)
		var e := float(_stamp.r)*1.3+1.0
		return Rect2(c-Vector2.ONE*e,Vector2.ONE*e*2.0)
	if not _cut.is_empty(): return _cut.box
	if _stroke.is_empty(): return Rect2()
	var pts: Array = _stroke.pts
	var box := Rect2(Vector2(float(pts[0][0]),float(pts[0][1])),Vector2.ZERO)
	for p: Array in pts: box = box.expand(Vector2(float(p[0]),float(p[1])))
	return box.grow(float(_stroke.r)*1.8+1.0)

## The edit drawn as a ghost over the land as it shows: the new ground on a
## GHOST_CELL lattice over the edit's box, where it differs from the shown
## ground (fading in with the change), smooth-shaded with a contour each
## metre; what rises is drawn on the land, what sinks seen through it.
func update_ghost() -> void:
	var began := Time.get_ticks_usec()
	var box := _edit_box()
	if box.size == Vector2.ZERO: return
	var base := _base_motif()
	if base != _ghost_base:
		_ghost_old.clear()
		_ghost_base = base
	var preview: RefCounted = MotifAuthored.from_data(data)
	var g: Callable = preview.ground_fn()
	var old_g: Callable = base.ground_fn()
	var new_poly := PackedVector2Array(preview.outline())
	var old_poly := PackedVector2Array(base.outline())
	var c0 := floori(box.position.x/GHOST_CELL)
	var r0 := floori(box.position.y/GHOST_CELL)
	var w := ceili(box.end.x/GHOST_CELL)-c0+1
	var h := ceili(box.end.y/GHOST_CELL)-r0+1
	var ys := PackedFloat32Array()
	var ds := PackedFloat32Array()
	ys.resize(w*h)
	ds.resize(w*h)
	for r in range(h):
		for c in range(w):
			var k := r*w+c
			var p := Vector2((c0+c)*GHOST_CELL,(r0+r)*GHOST_CELL)
			if not Geometry2D.is_point_in_polygon(p,new_poly):
				ys[k] = NAN
				continue
			var key := Vector2i(c0+c,r0+r)
			var o: float = NAN
			if _ghost_old.has(key): o = _ghost_old[key]
			else:
				if Geometry2D.is_point_in_polygon(p,old_poly): o = float(old_g.call(p.x,p.y))
				_ghost_old[key] = o
			var y := float(g.call(p.x,p.y))
			ys[k] = y
			ds[k] = 9.0 if is_nan(o) else y-o
	var up := _GhostSurface.new()
	var down := _GhostSurface.new()
	for r in range(h-1):
		for c in range(w-1):
			var ks := [r*w+c,r*w+c+1,(r+1)*w+c+1,(r+1)*w+c]
			var most := 0.0
			var sum := 0.0
			var whole := true
			for k: int in ks:
				if is_nan(ys[k]):
					whole = false
					break
				most = maxf(most,absf(ds[k]))
				sum += ds[k]
			if not whole or most < 0.06: continue
			var into := up if sum > 0.0 else down
			var vs: Array = []
			for k: int in ks:
				var cc := k%w
				var rr := k/w
				var n := Vector3(_gy(ys,w,h,cc-1,rr)-_gy(ys,w,h,cc+1,rr),2.0*GHOST_CELL,_gy(ys,w,h,cc,rr-1)-_gy(ys,w,h,cc,rr+1)).normalized()
				vs.append([Vector3((c0+cc)*GHOST_CELL,ys[k]+(0.05 if into == up else 0.0),(r0+rr)*GHOST_CELL),n,clampf(absf(ds[k])/0.6,0.0,1.0)])
			for i: int in [0,1,2,0,2,3]: into.add(vs[i])
	var mesh := ArrayMesh.new()
	for pair: Array in [[up,false],[down,true]]:
		var sf: _GhostSurface = pair[0]
		if sf.verts.is_empty(): continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = sf.verts
		arrays[Mesh.ARRAY_NORMAL] = sf.normals
		arrays[Mesh.ARRAY_COLOR] = sf.colours
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		mesh.surface_set_material(mesh.get_surface_count()-1,_ghost_material(bool(pair[1])))
	if _edit_ghost == null:
		_edit_ghost = MeshInstance3D.new()
		_edit_ghost.name = "EditGhost"
		_edit_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_edit_ghost)
	_edit_ghost.mesh = mesh
	_edit_ghost.visible = true
	var spent := float(Time.get_ticks_usec()-began)/1000.0
	ghost_ms = spent
	ghost_count += 1
	live_ms = int(ceil(spent))
	live_count += 1
	_bare_done_at = Time.get_ticks_msec()

## A ghost lattice height (clamped to the lattice; a hole reads its neighbour's 0 slope).
static func _gy(ys: PackedFloat32Array, w: int, h: int, c: int, r: int) -> float:
	var y := ys[clampi(r,0,h-1)*w+clampi(c,0,w-1)]
	return 0.0 if is_nan(y) else y

class _GhostSurface extends RefCounted:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	func add(v: Array) -> void:
		verts.append(v[0])
		normals.append(v[1])
		colours.append(Color(1.0,1.0,1.0,float(v[2])))

const GHOST_SHADER := """
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, specular_disabled%s;
uniform vec4 tint : source_color;
varying vec3 world;
void vertex() { world = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
	float f = fract(world.y);
	float line = 1.0-clamp(min(f,1.0-f)/max(fwidth(world.y),1e-4)-0.5,0.0,1.0);
	ALBEDO = mix(tint.rgb,vec3(1.0),line*0.7);
	ALPHA = COLOR.a*(tint.a+line*0.3);
}
"""
var _ghost_mats := {}
func _ghost_material(sunk: bool) -> ShaderMaterial:
	if not _ghost_mats.has(sunk):
		var sh := Shader.new()
		sh.code = GHOST_SHADER % (", depth_test_disabled" if sunk else "")
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("tint",Color(0.55,0.75,1.0,0.35) if sunk else Color(0.98,0.88,0.62,0.55))
		_ghost_mats[sunk] = m
	return _ghost_mats[sunk]

func _drop_edit_ghost() -> void:
	if _edit_ghost != null:
		remove_child(_edit_ghost)
		_edit_ghost.free()
		_edit_ghost = null
	_ghost_old.clear()
	_ghost_base = null

# --- Pieces that know how to fit (round 4) ------------------------------------------------

## Where the carried piece snaps with the cursor at `at` (`hit` the ground
## under it): onto a placed piece's free connector that mates one of its
## own (scripts/ruin_kit_fit.gd), the nearest on screen within SNAP_PX; else
## stood on a piece's top the ray meets first; else along a cliff lip (a
## wall). {at, turn, to (piece, -1 none), c, stand, label, mark: Vector3} or {}.
func find_snap(at: Vector2, hit: Dictionary) -> Dictionary:
	if _held_piece.is_empty(): return {}
	var node: Node3D = _held_piece.node
	var id_name := str(_held_piece.id)
	var mine: Array = RuinKitFit.connectors(id_name,node)
	var holder := pieces_holder()
	var best := {}
	var near := SNAP_PX
	var cursor_ground := Vector2(hit.position.x,hit.position.z) if not hit.is_empty() else Vector2.INF
	if holder != null:
		var used := _used_connectors()
		for c: Node in holder.get_children():
			var piece := c as Node3D
			var name_ := str(piece.name)
			if not name_.begins_with("P") or not name_.substr(1).is_valid_int(): continue
			var k := int(name_.substr(1))
			if k >= (data.pieces as Array).size(): continue
			var pid := str(data.pieces[k].id)
			# Its pose, not its look (a piece just set down still pops in, scaled).
			var pose_k: Transform3D = piece.global_transform.orthonormalized()
			for theirs: Dictionary in RuinKitFit.connectors(pid,piece):
				if used.has("%d/%s" % [k,theirs.name]): continue
				var world_at: Vector3 = pose_k*(theirs.at as Vector3)
				if camera.is_position_behind(world_at): continue
				var d := camera.unproject_position(world_at).distance_to(at)
				if str(theirs.mode) != "top":
					# A connector at a piece's foot reads as its upright: the
					# nearest point of a 2.5 m post over it (a terrace may hide its foot).
					var up_at := world_at+Vector3.UP*2.5
					if not camera.is_position_behind(up_at):
						var q := Geometry2D.get_closest_point_to_segment(at,camera.unproject_position(world_at),camera.unproject_position(up_at))
						d = minf(d,q.distance_to(at))
				if d >= near: continue
				var target := {"at":world_at,"facing":pose_k.basis*(theirs.facing as Vector3)}
				var pose := {}
				var stand := false
				if str(theirs.mode) == "top":
					pose = {"at":world_at,"turn":fposmod(rad_to_deg(pose_k.basis.get_euler().y)+float(_held_piece.get("turn",0.0)),360.0)}
				else:
					for m: Dictionary in mine:
						if not RuinKitFit.mates(str(m.kind),str(theirs.kind)): continue
						var free_turn := float(_held_piece.get("turn",0.0))
						if str(m.mode) == "post":
							# The turn free: the piece reaches toward the cursor.
							var reach := MotifAuthored.drawn_box(node).get_center()-(m.at as Vector3)
							var want := cursor_ground-Vector2(world_at.x,world_at.z) if cursor_ground != Vector2.INF else Vector2.ZERO
							if want.length() > 0.8 and Vector2(reach.x,reach.z).length() > 0.3:
								free_turn = rad_to_deg(atan2(want.x,want.y)-atan2(reach.x,reach.z))
						pose = RuinKitFit.pose_onto(m,target,free_turn)
						pose.mine = str(m.name)
						stand = str(m.mode) == "post"
						if stand:
							var p: Vector3 = pose.at
							p.y = MotifAuthored.seat(motif.ground_fn(),node,p.x,p.z,float(pose.turn))
							pose.at = p
						break
				if pose.is_empty(): continue
				near = d
				best = {"at":pose.at,"turn":pose.turn,"to":k,"c":str(theirs.name),"mine":str(pose.get("mine","")),"stand":stand,"label":"%s's %s" % [pid,theirs.name],"mark":world_at}
	if not best.is_empty(): return best
	# A piece's top under the cursor (the ray meets it before the land).
	var stack := _top_hit(at)
	if not stack.is_empty():
		var turn := float(_held_piece.get("turn",0.0))
		return {"at":stack.position,"turn":turn,"to":int(stack.k),"c":"","stand":false,"label":"%s's top" % str(data.pieces[int(stack.k)].id),"mark":stack.position}
	# A wall carried to a cliff lip seats along it, just inland.
	if id_name in ["wall","lancet_wall"] and not hit.is_empty():
		var lip := RuinKitFit.lip_near(motif.ground_fn(),cursor_ground,LIP_SNAP,motif.outline())
		if not lip.is_empty():
			var out: Vector2 = lip.out
			var mid: Vector2 = (lip.at as Vector2)-out*(RuinKit.WALL_THICK*0.5+0.15)
			var along := Vector2(-out.y,out.x)
			var turn := rad_to_deg(atan2(-along.y,along.x))
			var y := MotifAuthored.seat(motif.ground_fn(),node,mid.x,mid.y,turn)
			var lip_at: Vector2 = lip.at
			return {"at":Vector3(mid.x,y,mid.y),"turn":turn,"to":-1,"c":"lip","stand":false,"label":"the cliff lip","mark":Vector3(lip_at.x,float(motif.ground(lip_at.x,lip_at.y)),lip_at.y)}
	return {}

## Each connector in use ("<k>/<name>"): the one a piece is set onto, and
## the piece's own that meets it.
func _used_connectors() -> Dictionary:
	var out := {}
	var pieces: Array = data.pieces
	for k in range(pieces.size()):
		var on: Variant = pieces[k].get("on")
		if not on is Dictionary: continue
		if str(on.get("c","")) != "": out["%d/%s" % [int(on.to),str(on.c)]] = true
		if str(on.get("mine","")) != "": out["%d/%s" % [k,str(on.mine)]] = true
	return out

## The top of a placed piece under screen point `at` that faces up and
## stands nearer than the land: {position, k} or {}.
func _top_hit(at: Vector2) -> Dictionary:
	var from := camera.project_ray_origin(at)
	var q := PhysicsRayQueryParameters3D.create(from,from+camera.project_ray_normal(at)*2000.0)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or (hit.normal as Vector3).y < 0.75: return {}
	var n: Node = hit.collider
	while n != null and n.get_parent() != null:
		if n.get_parent().name == "Pieces":
			var name_ := str(n.name)
			if name_.begins_with("P") and name_.substr(1).is_valid_int(): return {"position":hit.position,"k":int(name_.substr(1))}
			return {}
		n = n.get_parent()
	return {}

## The snap shown: a bright ring where the piece goes on (drawn through
## everything) and the carried ghost tinted gold; {} hides it.
func _show_snap(snap: Dictionary) -> void:
	if _snap_mark == null:
		_snap_mark = MeshInstance3D.new()
		_snap_mark.name = "SnapMark"
		var torus := TorusMesh.new()
		torus.inner_radius = 0.75
		torus.outer_radius = 1.0
		_snap_mark.mesh = torus
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.no_depth_test = true
		mat.albedo_color = Color(0.45,1.0,0.75)
		_snap_mark.material_override = mat
		add_child(_snap_mark)
		_snap_tint = StandardMaterial3D.new()
		_snap_tint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_snap_tint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_snap_tint.albedo_color = Color(0.5,1.0,0.7,0.28)
		_snap_tint.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_snap_mark.visible = not snap.is_empty()
	if not snap.is_empty(): _snap_mark.global_position = snap.mark
	if not _held_piece.is_empty():
		for g: GeometryInstance3D in (_held_piece.node as Node3D).find_children("*","GeometryInstance3D",true,false):
			g.material_overlay = _snap_tint if not snap.is_empty() else null

## Piece `k` taken out of the data: those set onto it stand on their own
## where they are; the later pieces' "on" shift down one.
func forget_piece(k: int) -> void:
	var pieces: Array = data.pieces
	for p: Dictionary in pieces:
		var on: Variant = p.get("on")
		if not on is Dictionary: continue
		if int(on.to) == k: p.erase("on")
		elif int(on.to) > k: on.to = int(on.to)-1
	pieces.remove_at(k)

## The run under screen point `at` (its index, -1 none).
func run_hit(at: Vector2) -> int:
	var from := camera.project_ray_origin(at)
	var q := PhysicsRayQueryParameters3D.create(from,from+camera.project_ray_normal(at)*2000.0)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var n: Node = hit.collider if not hit.is_empty() else null
	while n != null and n.get_parent() != null:
		if n.get_parent().name == "Pieces" and str(n.name).begins_with("Run"): return int(str(n.name).substr(3))
		n = n.get_parent()
	# A rope bridge has no collider: near its line on screen.
	var ground := ground_hit(at)
	if ground.is_empty(): return -1
	var g := Vector2(ground.position.x,ground.position.z)
	var runs: Array = data.get("runs",[])
	for i in range(runs.size()):
		var a := Vector2(float(runs[i].from[0]),float(runs[i].from[1]))
		var b := Vector2(float(runs[i].to[0]),float(runs[i].to[1]))
		if Geometry2D.get_closest_point_to_segment(g,a,b).distance_to(g) < 1.5: return i
	return -1

## A run tool's click: the first sets the start, the second (or the
## release after a drag) the end.
func run_click(at: Vector2) -> void:
	var p := _run_point(at)
	if p == Vector2.INF: return
	if _run.is_empty():
		_run = {"kind":str(RUNS[tool]),"from":p,"to":p,"pressed":true,"press":at}
		say("%s from here: click where it ends" % str(_run.kind).capitalize())
	else:
		_run.to = p
		end_run()
		return
	_draw_run()

func run_to(at: Vector2) -> void:
	var p := _run_point(at)
	if p == Vector2.INF: return
	_run.to = p
	_draw_run()

func run_release(at: Vector2) -> void:
	_run.pressed = false
	# A drag laid it out; a click waits for the second click.
	if at.distance_to(_run.press) > 12.0 and (_run.from as Vector2).distance_to(_run.to) > 3.0: end_run()

## The ground point under `at` for a run's end (a bridge's or a wall's
## snapped to the nearest cliff lip within 4 m), or INF.
func _run_point(at: Vector2) -> Vector2:
	var hit := ground_hit(at)
	if hit.is_empty(): return Vector2.INF
	var p := Vector2(hit.position.x,hit.position.z)
	var kind := str(RUNS.get(tool,""))
	if kind in ["bridge","wall"]:
		# A bridge's end: the bank's top (the highest lip near), not a step down the wall.
		var lip := RuinKitFit.lip_near(motif.ground_fn(),p,4.0 if kind == "bridge" else LIP_SNAP,motif.outline(),kind == "bridge")
		if not lip.is_empty(): return snapped_v(lip.at)
	return snapped_v(p)

static func snapped_v(p: Vector2) -> Vector2:
	return Vector2(snappedf(p.x,0.001),snappedf(p.y,0.001))

## The run laid down: one recipe entry, built on the land as it is.
func end_run() -> void:
	var r := _run
	_drop_run()
	var from: Vector2 = r.from
	var to: Vector2 = r.to
	if from.distance_to(to) < 3.0:
		say("Too short for a run")
		return
	snapshot()
	if not data.has("runs"): data.runs = []
	var entry := {"run":str(r.kind),"from":[from.x,from.y],"to":[to.x,to.y],"seed":randi()%9000+1}
	if str(r.kind) != "bridge": entry.weathered = snappedf(_weather_new,0.01)
	(data.runs as Array).append(entry)
	var k := (data.runs as Array).size()-1
	var began := Time.get_ticks_msec()
	var node: Node3D = motif.make_run(k)
	run_ms = Time.get_ticks_msec()-began
	if node != null:
		pieces_holder().add_child(node)
		feel.cue(&"stone_drop",node.global_position,0.9)
		feel.kick(0.12)
	say("%s run laid (%.0f m, %d ms)" % [str(r.kind).capitalize(),from.distance_to(to),run_ms])

var run_ms := 0

func _drop_run() -> void:
	_run = {}
	_draw_run()

## The run's line while it is laid out: its ends marked, an aqueduct's
## spans ticked where they will stand.
func _draw_run() -> void:
	if _path_line == null:
		_path = {}
		_draw_path()
	var im := ImmediateMesh.new()
	_path_line.visible = not _run.is_empty()
	if not _run.is_empty():
		var g: Callable = motif.ground_fn()
		var a: Vector2 = _run.from
		var b: Vector2 = _run.to
		if str(_run.kind) == "aqueduct" and a.distance_to(b) > 0.5:
			var plan := RuinKitFit.aqueduct_plan(a,b,g)
			b = a+(plan.dir as Vector2)*float(plan.length)
		im.surface_begin(Mesh.PRIMITIVE_LINES)
		var n := maxi(2,int(a.distance_to(b)/1.0))
		for i in range(n):
			for t: float in [float(i)/n,float(i+1)/n]:
				var q := a.lerp(b,t)
				im.surface_add_vertex(Vector3(q.x,float(g.call(q.x,q.y))+0.3,q.y))
		for e: Vector2 in [a,b]:
			var y := float(g.call(e.x,e.y))
			im.surface_add_vertex(Vector3(e.x,y,e.y))
			im.surface_add_vertex(Vector3(e.x,y+4.0,e.y))
		if str(_run.kind) == "aqueduct" and a.distance_to(b) > 0.5:
			var dir := (b-a).normalized()
			var span := a.distance_to(b)/maxf(1.0,roundf(a.distance_to(b)/RuinKitFit.Aqueduct.SPAN))
			var t := span
			while t < a.distance_to(b)-0.5:
				var q := a+dir*t
				var y := float(g.call(q.x,q.y))
				im.surface_add_vertex(Vector3(q.x,y,q.y))
				im.surface_add_vertex(Vector3(q.x,y+2.0,q.y))
				t += span
		im.surface_end()
	_path_line.mesh = im
