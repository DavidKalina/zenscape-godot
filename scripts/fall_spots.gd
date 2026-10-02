extends Node
## Where poured water would fall (docs/scenic/water-flow.md "Fall spots"): with
## water in hand, a few faint cream rings on the land mark the spots just
## above a lip, where a pour runs over a drop big enough for the live water to
## stand a waterfall (scripts/flow_falls.gd), or into a notch cut through the
## rim, where it pours off the plate (scripts/edge_falls.gd).
##
## **Water in hand** is the watering can in the roll, the case's water in the
## hand (hand_materials `held` "water"), a water ball carried (NativeChunkEditor
## `_ball_holding`, the ball still "holding") or the sky's cloud pinched
## (hand_reach `holding` "cloud"). The can and the case's water show the rings
## only while the hand hovers the land with nothing pressed; a press is the
## pour (or the scoop), and the rings go. A ball or a cloud is carried in a
## press already, and its pour is the letting go, so its rings stay while it
## is carried.
##
## **Quiet, by the user's rule** for ground previews (ground_marks.gd's
## header): the same cream, fainter than the cursor's mark (LINE_ALPHA,
## FILL_ALPHA), at most MAX_SPOTS of the best spots and never a field of
## them, coming in only after DELAY s of water in hand and fading in over
## FADE_IN, gone at once (FADE_OUT) on a press, the camera moving or the
## water leaving the hand. No bob, pulse or loop.
##
## **The scan** (`Scan`) reads the ground on a STEP grid and walks the
## steepest way down from a source every SOURCE_EVERY cells, as a spring's
## course does (WaterFlow `descent`, on the grid so it costs no triangle
## walks). A walk that, within APPROACH m of its source, comes to a step
## falling LIP_SLOPE or more per metre, and then falls MIN_DROP m or more
## within FACE_RUN m, is a lip: its spot is the source, and it scores the drop
## (less APPROACH_COST a metre of approach, so the source nearest the brink
## wins). A walk that leaves the plate within EDGE_APPROACH m through a notch
## (the rim there NOTCH m under the rim either side) is an edge spot, scoring
## EDGE_SCORE: under any lip, so a mountain's falls come first. The best are
## kept SPACING m apart. A scan runs once per shape of the land (it keeps the
## heights it read and starts again when they change), in slices of
## SCAN_BUDGET_USEC a frame, which DELAY hides.

const GroundMarks = preload("res://scripts/ground_marks.gd")

## The ground grid (m) and the plate's half extent; a source every
## SOURCE_EVERY cells (1 m).
const STEP := 0.5
const HALF := 14.0
const SOURCE_EVERY := 2
## Water reaching this close to the rim leaves the plate (the sim's drain ring
## is its outermost 0.25 m cells; a cell further in is a safe read).
const RIM_BAND := 0.5
## A walk's most steps.
const WALK_STEPS := 14
## A lip: a step falling LIP_SLOPE per metre or more within APPROACH m of the
## source, then MIN_DROP m down the face (steps falling FACE_SLOPE or more)
## within FACE_RUN m. The flow's own fall wants its water's surface to fall
## 0.8 per metre over 3 cells and a 0.7 m drop (flow_falls.gd DETECT), so
## these stand a little over it.
const LIP_SLOPE := 0.9
const APPROACH := 1.5
const FACE_SLOPE := 0.5
const MIN_DROP := 1.0
const FACE_RUN := 3.0
const APPROACH_COST := 0.25
## An edge spot: the walk leaves the plate within EDGE_APPROACH m, where the
## rim stands NOTCH m or more under the rim NOTCH_REACH m along it either side.
const EDGE_APPROACH := 2.5
const NOTCH := 0.15
const NOTCH_REACH := 1.5
const EDGE_SCORE := 0.5
## How many spots at most, and how far apart (m).
const MAX_SPOTS := 5
const SPACING := 3.0
## Microseconds of scan a frame.
const SCAN_BUDGET_USEC := 2000
## Seconds of water in hand before the rings come, to fade in, and to go.
const DELAY := 0.6
const FADE_IN := 0.8
const FADE_OUT := 0.12
## The ring: its radius (m), the thread's and the fill's alpha at full show
## (under the cursor mark's 0.3 and 0.05, so the hand's own mark reads first).
const RADIUS := 0.5
const LINE_ALPHA := 0.2
const FILL_ALPHA := 0.035

## The ground on the grid, then the walks from the sources, in slices: the
## heights it read, and when done, `found`.
class Scan extends RefCounted:
	var data: NativeTerrainData
	var heights := PackedFloat32Array()
	var size := 0
	var ground := PackedFloat32Array()
	var row := 0
	var source := 0
	var candidates: Array[Dictionary] = []
	var found: Array[Dictionary] = []
	var done := false
	var usec := 0

	func _init(terrain: NativeTerrainData) -> void:
		data = terrain
		heights = terrain.heights.duplicate()
		size = roundi(HALF*2.0/STEP)+1
		ground.resize(size*size)

	## Runs until `budget` µs have gone (or to the end with budget < 0).
	## True once done.
	func advance(budget: int) -> bool:
		var start := Time.get_ticks_usec()
		var over := func() -> bool: return budget >= 0 and Time.get_ticks_usec()-start >= budget
		while row < size and not done:
			for i in range(size):
				var h: Variant = data.ground_height(point(i,row))
				ground[row*size+i] = float(h) if h != null else NAN
			row += 1
			if over.call():
				usec += Time.get_ticks_usec()-start
				return false
		var sources := ceili(float(size)/SOURCE_EVERY)
		while source < sources*sources and not done:
			var i := (source%sources)*SOURCE_EVERY
			var j := (source/sources)*SOURCE_EVERY
			source += 1
			var spot := _walk(i,j)
			if not spot.is_empty(): candidates.append(spot)
			if over.call():
				usec += Time.get_ticks_usec()-start
				return false
		if not done:
			found = pick(candidates)
			done = true
		usec += Time.get_ticks_usec()-start
		return true

	## The plate point of grid node i, j.
	func point(i: int, j: int) -> Vector2:
		return Vector2(-HALF+i*STEP,-HALF+j*STEP)

	func _on_plate(i: int, j: int) -> bool:
		var p := point(i,j)
		return HALF-maxf(absf(p.x),absf(p.y)) >= RIM_BAND

	func _height(i: int, j: int) -> float:
		if i < 0 or j < 0 or i >= size or j >= size: return NAN
		return ground[j*size+i]

	## The steepest way down from source i, j, read for a lip or a notch:
	## {"at" (x, ground, z), "kind" ("lip" or "edge"), "drop", "score"}, or
	## {} for neither.
	func _walk(i: int, j: int) -> Dictionary:
		var h := _height(i,j)
		if is_nan(h) or not _on_plate(i,j): return {}
		var run := 0.0
		var lip := -1.0
		var lip_h := 0.0
		var face_end := 0.0
		var drop := 0.0
		var at := Vector2i(i,j)
		for step in range(WALK_STEPS):
			var best := Vector2i(-1,-1)
			var best_slope := 0.0
			var best_run := 0.0
			var leaves := false
			for dj in range(-1,2):
				for di in range(-1,2):
					if di == 0 and dj == 0: continue
					var n := at+Vector2i(di,dj)
					var below := _height(n.x,n.y)
					if is_nan(below): continue
					var length := STEP*(1.4142136 if di != 0 and dj != 0 else 1.0)
					var slope := (h-below)/length
					if slope > best_slope:
						best_slope = slope
						best = n
						best_run = length
						leaves = not _on_plate(n.x,n.y)
			if best.x < 0: break
			if lip < 0.0 and best_slope >= LIP_SLOPE:
				if run > APPROACH: break
				lip = run
				lip_h = h
			if lip >= 0.0:
				if best_slope < FACE_SLOPE: break
				drop = lip_h-_height(best.x,best.y)
				face_end = run+best_run
				if face_end-lip > FACE_RUN: break
			if leaves:
				# Off the plate: through a notch it is an edge spot (a lip
				# already found keeps what it fell before the rim).
				if lip < 0.0 and run+best_run <= EDGE_APPROACH:
					var notch := _notch(best)
					if notch >= NOTCH: return {"at":Vector3(point(i,j).x,_height(i,j),point(i,j).y),"kind":"edge","drop":notch,"score":EDGE_SCORE+notch}
				break
			run += best_run
			h = _height(best.x,best.y)
			at = best
			# Too far from its source for a lip or the rim: the pour would run
			# a long way first, so this is not its spot.
			if lip < 0.0 and run > maxf(APPROACH,EDGE_APPROACH): break
		if lip < 0.0 or drop < MIN_DROP: return {}
		var p := point(i,j)
		return {"at":Vector3(p.x,_height(i,j),p.y),"kind":"lip","drop":drop,"score":drop-APPROACH_COST*lip}

	## How far the rim at grid node `at` stands under the rim NOTCH_REACH m
	## along it either side (the lower side), or 0 at a corner.
	func _notch(at: Vector2i) -> float:
		var p := point(at.x,at.y)
		var along := Vector2i(0,1) if absf(p.x) > absf(p.y) else Vector2i(1,0)
		var reach := roundi(NOTCH_REACH/STEP)
		var here := _height(at.x,at.y)
		var one := _height(at.x+along.x*reach,at.y+along.y*reach)
		var two := _height(at.x-along.x*reach,at.y-along.y*reach)
		if is_nan(one) or is_nan(two): return 0.0
		return minf(one,two)-here

	## The best candidates, SPACING m apart, at most MAX_SPOTS.
	static func pick(from: Array[Dictionary]) -> Array[Dictionary]:
		var sorted := from.duplicate()
		sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.score > b.score)
		var kept: Array[Dictionary] = []
		for spot: Dictionary in sorted:
			var near := false
			for other: Dictionary in kept:
				if Vector2(spot.at.x,spot.at.z).distance_to(Vector2(other.at.x,other.at.z)) < SPACING:
					near = true
					break
			if near: continue
			kept.append(spot)
			if kept.size() >= MAX_SPOTS: break
		return kept

## The spots on `terrain` now, in one go (for probes): see `Scan`.
static func scan(terrain: NativeTerrainData) -> Array[Dictionary]:
	var job := Scan.new(terrain)
	job.advance(-1)
	return job.found

var scene: Node3D
var reach: Node
## The rings, one box decal each (shaders/ground_mark.gdshader, the
## cursor mark's loop).
var rings: Array[MeshInstance3D] = []
## The spots of the land as last read, the scan under way (or null), and the
## scan they came from (for probes: its cost in `usec`).
var spots: Array[Dictionary] = []
var scanning: Scan
var last_scan: Scan
## Seconds water has been in hand, and the fade (0..1).
var held_seconds := 0.0
var shown := 0.0
## Why the rings are hidden this frame, for probes ("" while wanted).
var reason := ""

static func enabled() -> bool:
	return not "--no-fall-spots" in OS.get_cmdline_user_args()

func setup(owner_scene: Node3D, hand_reach: Node) -> void:
	scene = owner_scene
	reach = hand_reach
	name = "FallSpots"
	for k in range(MAX_SPOTS):
		var material := ShaderMaterial.new()
		material.shader = preload("res://shaders/ground_mark.gdshader")
		material.render_priority = -1
		var ring := MeshInstance3D.new()
		ring.name = "FallSpot%d" % k
		ring.mesh = BoxMesh.new()
		ring.material_override = material
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.top_level = true
		ring.visible = false
		add_child(ring)
		rings.append(ring)

## Reads the hand each frame (called by scripts/hand_reach.gd after the
## marks): shows the rings while water is in hand, scanning the land first
## if it has changed shape.
func step(delta: float) -> void:
	delta = minf(delta,0.1)
	reason = _water_in_hand()
	if not reason.is_empty():
		held_seconds = 0.0
		shown = move_toward(shown,0.0,delta/FADE_OUT)
		_draw()
		return
	held_seconds += delta
	var editor := _editor()
	if scanning == null and (last_scan == null or last_scan.data != editor.data or last_scan.heights != editor.data.heights):
		scanning = Scan.new(editor.data)
	if scanning != null:
		if scanning.data != editor.data or scanning.heights != editor.data.heights: scanning = Scan.new(editor.data)
		if scanning.advance(SCAN_BUDGET_USEC):
			last_scan = scanning
			spots = scanning.found
			scanning = null
	if scanning == null and held_seconds >= DELAY: shown = move_toward(shown,1.0,delta/FADE_IN)
	_draw()

## "" while water is in hand and the rings may show, otherwise why not.
func _water_in_hand() -> String:
	var editor := _editor()
	if editor == null or editor.forming: return "no land"
	var flow: RefCounted = editor.get("flow")
	if flow == null or not flow.ready: return "no live water"
	var wanderer: Node = scene.get("wanderer")
	if wanderer != null and wanderer.get("active") == true: return "eye"
	if reach.camera_moving(): return "camera"
	# Carried in a press: its pour is the letting go.
	var ball: Node = editor.get("ball")
	if editor.get("_ball_holding") == true and ball != null and str(ball.state) == "holding": return ""
	if reach.holding == "cloud": return ""
	var materials: Node = reach.get("materials")
	if materials == null or materials.roll == null: return "no tray"
	var water: bool = materials.held == "water" or (materials.held.is_empty() and materials.roll.tool == "can")
	if not water: return "no water"
	if not str(reach.holding).is_empty(): return "pouring" if reach.holding == "can" else "held"
	var can: Node = editor.get("can")
	if can != null and can.get("pouring") == true: return "pouring"
	if not reach.available(): return "unavailable"
	if reach.hover_zone != "land" or reach._hover_point == null: return "not land"
	var pointer: Vector2 = scene.get_viewport().get_mouse_position() if reach.pointer_override == null else reach.pointer_override
	if materials.tray_under(pointer): return "tray"
	return ""

## The rings showing now (for probes).
func visible_count() -> int:
	var count := 0
	for ring: MeshInstance3D in rings:
		if ring.visible: count += 1
	return count

func _editor() -> Node:
	return scene.get("_chunk_editor")

## Each spot's box round its ring, and the shader its loop.
func _draw() -> void:
	var editor := _editor()
	for k in range(rings.size()):
		var ring := rings[k]
		ring.visible = shown > 0.0 and k < spots.size() and editor != null
		if not ring.visible: continue
		var terrain: Node3D = editor.terrain
		var scale := terrain.global_basis.get_scale().x
		var at: Vector3 = spots[k].at
		var c := Vector2(at.x,at.z)
		var low := at.y
		var high := at.y
		for n in range(GroundMarks.OUTLINE_SAMPLES):
			var h: Variant = editor.data.ground_height(c+Vector2.from_angle(TAU*n/GroundMarks.OUTLINE_SAMPLES)*RADIUS)
			if h == null: continue
			low = minf(low,float(h))
			high = maxf(high,float(h))
		var e := GroundMarks.NORMAL_REACH
		var dx := _height(c+Vector2(e,0.0),at.y)-_height(c-Vector2(e,0.0),at.y)
		var dz := _height(c+Vector2(0.0,e),at.y)-_height(c-Vector2(0.0,e),at.y)
		var normal := Vector3(-dx,2.0*e,-dz).normalized()
		var axis := (Vector3.RIGHT-normal*normal.x).normalized()
		var side := (RADIUS+GroundMarks.BOX_MARGIN)*2.0
		var local := Transform3D(Basis.from_scale(Vector3(side,high-low+GroundMarks.BOX_BELOW+GroundMarks.BOX_ABOVE,side)),Vector3(c.x,(low-GroundMarks.BOX_BELOW+high+GroundMarks.BOX_ABOVE)*0.5,c.y))
		ring.global_transform = terrain.global_transform*local
		var basis := terrain.global_basis
		var material := ring.material_override as ShaderMaterial
		material.set_shader_parameter("mark_kind",0)
		material.set_shader_parameter("mark_centre",terrain.to_global(at))
		material.set_shader_parameter("mark_axis",(basis*axis).normalized())
		material.set_shader_parameter("mark_normal",(basis*normal).normalized())
		material.set_shader_parameter("mark_half",Vector2.ONE*RADIUS*scale)
		material.set_shader_parameter("shown",shown)
		material.set_shader_parameter("line_alpha",LINE_ALPHA)
		material.set_shader_parameter("fill_alpha",FILL_ALPHA)
		material.set_shader_parameter("line_px",GroundMarks.LINE_PX)
		material.set_shader_parameter("stitches",maxf(8.0,roundf(TAU*RADIUS/GroundMarks.STITCH_METRES)))
		material.set_shader_parameter("stitch_duty",GroundMarks.STITCH_DUTY)
		material.set_shader_parameter("ceiling",terrain.to_global(Vector3(c.x,high+GroundMarks.CEILING_LIFT,c.y)).y)
		material.set_shader_parameter("mark_tone",Vector3(GroundMarks.TONE.r,GroundMarks.TONE.g,GroundMarks.TONE.b))
		material.set_shader_parameter("night_dim",GroundMarks.NIGHT_DIM)

func _height(p: Vector2, fallback: float) -> float:
	var h: Variant = _editor().data.ground_height(p)
	return float(h) if h != null else fallback
