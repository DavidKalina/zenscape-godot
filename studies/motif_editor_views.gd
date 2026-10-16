extends Node
## The motif editor's close views (loop editor-traps, spec item 10): two
## ways to judge a place up close without leaving the editor or playing.
##
## Frame (F): the camera swings in to the selected trap or piece (else the
## trap or piece under the cursor, else the ground there) and orbits it.
## Right-drag turns round it, the wheel moves in and out, W A S D Q E break
## back to free flight where the camera stands; F again glides back to where
## the camera was before.
##
## Eye view (V): the camera at the pilot's eye height (his real size,
## motor.size), a few steps behind the selected trap's way in looking along
## its route (entry()'s -z), else on the ground under the cursor looking the
## way the camera looked. W A S D walk it over the ground at his run pace
## (Shift faster), right-drag looks round; it follows what stands (the land,
## pieces' tops) and steps up anything a jump catches (RuinKit.GRAB_TOP),
## no collision: a wall taller than that is walked through, the void's edge
## stops it. V again glides back to where the camera was.
##
## Both glide (EASE s, smoothstep) and leave the trap ghost, the grid and
## selection alone. The views write the editor's own camera (_cam_pos,
## _cam_yaw, _cam_pitch, then _apply_cam), so picking, the shake and P
## carry on as in free flight; P, a load or a new motif drop the view.

const RuinKit = preload("res://scripts/ruin_kit.gd")
const MotifAuthored = preload("res://scripts/kit_isle/motif_authored.gd")

## The glide in or out (s).
const EASE := 0.4
## His eye over his feet at size 1 (m): the painted eyes' height in the
## figure's rest pose, `eye_at.z` in shaders/pilot_paint.gdshader (printed
## as PILOT_EYES by art/blender/pilot/pilot_build.py; the glb is drawn 1:1
## at size 1, head bone 0.81, hat bone 1.075). The shader's default can't be
## read back headless (dummy renderer), so the number is kept here.
const EYE := 0.9348
## The eye view starts this many of his heights behind a trap's way in.
const BACK := 2.2
## Orbit: the nearest and farthest (m), and its pitch limits (rad).
const NEAR := 1.5
const FAR := 120.0
const PITCH := Vector2(-1.45,0.6)
## Eye view: the vertical follow (1/s), the drop below the feet looked for.
const FOLLOW := 14.0
const DEEP := 80.0
const ZOOM := 1.15

var editor: Node
## "" free flight, "orbit", "eye".
var mode := ""
## Orbit: the point turned round and how far.
var target := Vector3.ZERO
var dist := 6.0
## Eye view: the feet.
var feet := Vector3.ZERO
## Where the camera was before the view (pos, yaw, pitch).
var _was := {}
## The glide: from this pose, t 0..1.
var _from := {}
var _t := 1.0
## What the view wants (pos, yaw, pitch), eased into.
var _yaw := 0.0
var _pitch := 0.0
var _eye_y := 0.0
## The cursor's last place on screen (the editor's mouse motion).
var pointer := Vector2.ZERO
## Counters for drivers.
var walked := 0.0
var stepped_up := 0

func setup(owner_editor: Node) -> void:
	editor = owner_editor
	name = "EditorViews"

func active() -> bool:
	return mode != ""

func gliding() -> bool:
	return _t < 1.0

func eye_height() -> float:
	return EYE*float(editor.motor.size)

# --- Frame (F) ------------------------------------------------------------------------------

## F at screen point `at`: frame what is selected or under it; F again
## while orbiting goes back.
func frame(at: Vector2) -> void:
	if mode == "orbit":
		back()
		return
	var aim := _aim(at)
	if aim.is_empty():
		editor.say("Frame: nothing under the cursor")
		return
	_keep_was()
	target = aim.centre
	dist = clampf(float(aim.reach)*2.4+2.5,NEAR*2.0,40.0)
	# Swing in along the way the camera looks at it, a little from above.
	var from: Vector3 = editor._cam_pos
	var to := target-from
	_yaw = atan2(-to.x,-to.z)
	_pitch = clampf(atan2(to.y,Vector2(to.x,to.z).length()),PITCH.x,-0.3)
	mode = "orbit"
	_start_glide()
	editor.say("Frame: %s · right-drag turns round it, wheel in and out, WASD flies on, F back" % str(aim.name))

## What F frames: {centre, reach, name} or {}.
func _aim(at: Vector2) -> Dictionary:
	var traps: Node = editor.traps
	var k: int = traps.selected if traps != null else -1
	var p: int = editor.selected
	if k < 0 and p < 0:
		# Nothing selected: the trap or the piece under the cursor, the
		# nearer along the ray when both are.
		if traps != null and not traps.holding(): k = traps.hit(at)
		p = editor.piece_hit(at)
		if k >= 0 and p >= 0 and traps.node_of(k) != null and editor.piece_node(p) != null:
			if _ray_box(editor.piece_node(p),at) < _ray_box(traps.node_of(k),at): k = -1
			else: p = -1
	if k >= 0 and traps.node_of(k) != null: return _box_aim(traps.node_of(k),"trap %s #%d" % [str(traps.entries()[k].id),k])
	if p >= 0 and editor.piece_node(p) != null: return _box_aim(editor.piece_node(p),"piece %s #%d" % [str(editor.data.pieces[p].id),p])
	var hit: Dictionary = editor.ground_hit(at)
	if hit.is_empty(): return {}
	return {"centre":hit.position+Vector3.UP*1.0,"reach":2.0,"name":"the ground"}

## How far along the ray through screen point `at` it meets `node`'s drawn
## box (INF: it misses).
func _ray_box(node: Node3D, at: Vector2) -> float:
	var cam: Camera3D = editor.camera
	var from := cam.project_ray_origin(at)
	var inv := node.global_transform.affine_inverse()
	var h: Variant = MotifAuthored.drawn_box(node).intersects_ray(inv*from,inv.basis*cam.project_ray_normal(at))
	return INF if h == null else from.distance_to(node.global_transform*(h as Vector3))

static func _box_aim(node: Node3D, what: String) -> Dictionary:
	var box := MotifAuthored.drawn_box(node)
	var c := node.global_transform*box.get_center()
	return {"centre":c,"reach":maxf(box.size.length()*0.5,1.0),"name":what}

func _orbit_pos() -> Vector3:
	var b := Basis(Vector3.UP,_yaw)*Basis(Vector3.RIGHT,_pitch)
	return target+b*Vector3(0.0,0.0,dist)

# --- Eye view (V) ---------------------------------------------------------------------------

## V at screen point `at`: stand at the selected trap's way in (or on the
## ground under the cursor) at his eye; V again goes back.
func eye(at: Vector2) -> void:
	if mode == "eye":
		back()
		return
	var traps: Node = editor.traps
	var k: int = traps.selected if traps != null else -1
	var stand := Vector3.INF
	var yaw: float = editor._cam_yaw
	var what := ""
	if k >= 0 and traps.node_of(k) != null:
		var into: Transform3D = traps.node_of(k).entry()
		var ahead := -into.basis.z
		ahead.y = 0.0
		ahead = ahead.normalized() if ahead.length() > 0.01 else Vector3.FORWARD
		yaw = atan2(-ahead.x,-ahead.z)
		stand = into.origin-ahead*BACK*eye_height()
		var g := ground_at(stand,into.origin.y)
		if g == INF:
			stand = into.origin
		else: stand.y = g
		what = "at %s #%d's way in" % [str(traps.entries()[k].id),k]
	else:
		var hit: Dictionary = editor.ground_hit(at)
		if hit.is_empty():
			editor.say("Eye view: no ground under the cursor")
			return
		stand = hit.position
		var g := ground_at(stand,stand.y)
		if g != INF: stand.y = g
		what = "on the ground"
	_keep_was()
	feet = stand
	_eye_y = feet.y+eye_height()
	_yaw = yaw
	_pitch = -0.06
	mode = "eye"
	walked = 0.0
	stepped_up = 0
	_start_glide()
	editor.say("Eye view %s, %.2f m up · WASD walk (Shift faster), right-drag look, V back" % [what,eye_height()])

## The top under `p` that a walker standing at height `from_y` reaches: a
## ray down from GRAB_TOP over his feet (what a jump catches), the void INF.
func ground_at(p: Vector3, from_y: float) -> float:
	var top := from_y+RuinKit.GRAB_TOP*float(editor.motor.size)+0.05
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x,top,p.z),Vector3(p.x,from_y-DEEP,p.z))
	var hit: Dictionary = editor.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty(): return INF
	return float(hit.position.y)

## W A S D in the eye view: walk at his run pace over what stands.
func walk(way: Vector2, fast: bool, delta: float) -> void:
	if way == Vector2.ZERO: return
	var pace: float = float(editor.motor.run)*(2.5 if fast else 1.0)
	var flat := Basis(Vector3.UP,_yaw)*Vector3(way.x,0.0,way.y)
	var next := feet+flat.normalized()*pace*delta
	var g := ground_at(next,feet.y)
	if g == INF: return
	if g > feet.y+0.3: stepped_up += 1
	walked += feet.distance_to(Vector3(next.x,feet.y,next.z))
	feet = Vector3(next.x,g,next.z)

# --- Both -----------------------------------------------------------------------------------

## Right-drag: turn round the target (orbit) or look round (eye).
func look(rel: Vector2) -> void:
	_yaw -= rel.x*float(editor.LOOK_RATE)
	_pitch = clampf(_pitch-rel.y*float(editor.LOOK_RATE),PITCH.x,PITCH.y if mode == "orbit" else 1.4)

## The wheel while orbiting: in (+1) or out (-1).
func zoom(dir: int) -> void:
	dist = clampf(dist/ZOOM if dir > 0 else dist*ZOOM,NEAR,FAR)

## Back to free flight where the camera stands now.
func release() -> void:
	mode = ""
	_t = 1.0
	_was = {}

## Glide back to where the camera was before the view.
func back() -> void:
	if _was.is_empty():
		release()
		return
	var was := _was
	_from = _pose()
	_t = 0.0
	mode = "back"
	target = was.pos
	_yaw = float(was.yaw)
	_pitch = float(was.pitch)
	_was = {}

## The camera moved by the view this frame. `way` holds W/S (y) A/D (x)
## and Q/E (z); while orbiting any of them breaks to free flight (false:
## the editor flies as usual).
func step(delta: float, way: Vector3, fast: bool) -> bool:
	if mode == "": return false
	if mode in ["orbit","back"] and way != Vector3.ZERO:
		_settle()
		release()
		editor.say("Free flight")
		return false
	if mode == "eye":
		walk(Vector2(way.x,way.y),fast,delta)
		_eye_y = lerpf(_eye_y,feet.y+eye_height(),1.0-exp(-FOLLOW*delta))
	var want := _want()
	if _t < 1.0:
		_t = minf(_t+delta/EASE,1.0)
		var s := smoothstep(0.0,1.0,_t)
		editor._cam_pos = (_from.pos as Vector3).lerp(want.pos,s)
		editor._cam_yaw = lerp_angle(float(_from.yaw),float(want.yaw),s)
		editor._cam_pitch = lerpf(float(_from.pitch),float(want.pitch),s)
	else:
		editor._cam_pos = want.pos
		editor._cam_yaw = want.yaw
		editor._cam_pitch = want.pitch
	editor._apply_cam()
	if mode == "back" and _t >= 1.0: release()
	return true

func _want() -> Dictionary:
	match mode:
		"orbit": return {"pos":_orbit_pos(),"yaw":_yaw,"pitch":_pitch}
		"eye": return {"pos":Vector3(feet.x,_eye_y,feet.z),"yaw":_yaw,"pitch":_pitch}
		_: return {"pos":target,"yaw":_yaw,"pitch":_pitch}

## The camera stays where the glide has it (WASD mid-glide).
func _settle() -> void:
	editor._cam_yaw = wrapf(float(editor._cam_yaw),-PI,PI)

func _pose() -> Dictionary:
	return {"pos":editor._cam_pos,"yaw":float(editor._cam_yaw),"pitch":float(editor._cam_pitch)}

func _keep_was() -> void:
	if _was.is_empty(): _was = _pose()

func _start_glide() -> void:
	_from = _pose()
	_t = 0.0
