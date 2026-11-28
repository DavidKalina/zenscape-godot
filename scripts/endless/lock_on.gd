extends Node
## Lock-on (spec docs/design/endless-flight/spec-raider-combat.md, item 1):
## `fly_lock` (the pad's R3, the middle mouse button, Y) locks onto the
## target nearest the middle of the view that is in reach (REACH m) and in
## sight (on screen, not behind the land). While locked:
## - the view turns toward the target (BIAS of its angle off the view's axis,
##   eased over AIM_EASE s), never so far the plane leaves the frame
##   (PLANE_KEEP of the half view), and widens WIDE degrees;
## - depth of field focuses at the target's distance: the land nearer and
##   farther softens (DOF_*), eased on and off with the lock;
## - a reticle sits on the target.
## Pressing again releases it, and so does losing the target: gone (hidden or
## freed), past LET_GO m, or out of sight for LOST_S s. The view eases back.
## The flying is the player's throughout: only the view turns.
##
## Targets: any Node3D in the group GROUP, aimed at at its `lock_point()` if it
## has one, else its global position, and lockable while visible in the tree
## (and its `lockable()`, if it has one, is true). The raider's figure joins in
## raider.gd's setup.
##
## The study builds it with `--raider` and calls `frame(delta, game)` at the
## end of its `_frame`, after the chase camera has placed the eye.

const GROUP := &"lock_on"
const ACTION := &"fly_lock"
## Reach to lock (m); held out to LET_GO (m); out of sight this long lets go (s).
const REACH := 700.0
const LET_GO := 950.0
const LOST_S := 1.5
## Locking: within this share of the half view from the middle (each axis).
const IN_VIEW := 0.92
## The view: share of the target's angle it turns toward, the ease (s), the
## most of the half view the plane may sit off the middle, the widening (deg).
const BIAS := 0.6
const AIM_EASE := 0.45
const PLANE_KEEP := 0.72
const WIDE := 4.0
## The lock's ease on and off (s); the focus distance's ease (s).
const LOCK_EASE := 0.35
const FOCUS_EASE := 0.2
## Depth of field: sharp from FOCUS*(1-DOF_NEAR) to FOCUS*(1+DOF_FAR)+DOF_PAD m,
## softening over DOF_RAMP of the focus (+ DOF_RAMP_PAD m); the blur's amount.
## The near blur never reaches the player's plane: it starts at most
## PLANE_SHARP of the plane's distance from the eye, so only what is between
## the eye and the plane softens (a depth blur can't soften the land ahead of
## the plane and keep the plane sharp).
const DOF_NEAR := 0.45
const PLANE_SHARP := 0.7
const DOF_FAR := 0.35
const DOF_PAD := 40.0
const DOF_RAMP := 0.5
const DOF_RAMP_PAD := 30.0
const DOF_AMOUNT := 0.1
## The line of sight: samples against the land, m it may dip under it.
## The reticle: a target's half size (m) unless it says (`lock_radius()`),
## how far past it the brackets sit (x its half size on screen), the most (px).
const RETICLE_R := 3.5
const RETICLE_OPEN := 2.4
const RETICLE_MOST := 220.0
const SIGHT_SAMPLES := 8
const SIGHT_DIP := 2.0

## The locked target, or null.
var target: Node3D = null
## 0 to 1: how far the lock has eased in (the view, DOF, reticle follow it).
var weight := 0.0
## The view's turn toward the target (rad: yaw right, pitch up), as applied.
var offset := Vector2.ZERO
## m from the eye to what is in focus.
var focus := 100.0
## Counted, for the drivers: locks, releases by kind.
var stats := {"locks":0,"pressed":0,"released":0,"killed":0,"far":0,"lost":0,"misses":0}
## Why the last lock ended (pressed, killed, far, lost), "" while locked.
var why := ""

var game: Node3D
var _unseen := 0.0
var _dof: CameraAttributesPractical = null
var _dof_before: CameraAttributes = null
var _dof_on := false
var _layer: CanvasLayer
var _reticle: Reticle
var _clock := 0.0

static func wanted() -> bool:
	return "--raider" in preload("res://scripts/launch_args.gd").user_args()

func _init() -> void:
	name = "LockOn"

func setup(g: Node3D) -> void:
	game = g
	_layer = CanvasLayer.new()
	_layer.layer = 6
	add_child(_layer)
	_reticle = Reticle.new()
	_layer.add_child(_reticle)

## One frame, after the chase camera has placed the eye: the button, the
## target kept or let go, the view turned, the focus and the reticle.
func frame(delta: float, g: Node3D) -> void:
	game = g
	var cam: Camera3D = game.camera
	if cam == null: return
	_clock += delta
	# The main menu's stage holds the camera and its lens.
	var menu: bool = game.get("stage") != null
	if not menu and game.get("overlay") == null and Input.is_action_just_pressed(ACTION):
		if target != null: release("pressed")
		else: _acquire(cam)
	if target != null and not lockable(target): release("killed")
	if menu and target != null: release("pressed")
	var want := 1.0 if target != null else 0.0
	weight = want if delta <= 0.0 else lerpf(weight,want,1.0-exp(-delta/LOCK_EASE))
	if absf(weight-want) < 0.002: weight = want
	if not menu: _aim(delta,cam)
	# Kept or lost as seen through the turned view.
	if target != null: _keep(delta,cam)
	_lens(delta,cam,menu)
	_draw_reticle(cam)

## Let go of the target (`kind`: pressed, killed, far, lost).
func release(kind: String) -> void:
	if target == null: return
	target = null
	why = kind
	stats.released = int(stats.released)+1
	stats[kind] = int(stats.get(kind,0))+1

static func point_of(n: Node3D) -> Vector3:
	if n.has_method("lock_point"): return n.call("lock_point")
	return n.global_position

static func lockable(n: Node) -> bool:
	if not is_instance_valid(n) or not n.is_inside_tree(): return false
	if not (n is Node3D) or not (n as Node3D).is_visible_in_tree(): return false
	if n.has_method("lockable") and not bool(n.call("lockable")): return false
	return true

# --- The target -----------------------------------------------------------------

func _acquire(cam: Camera3D) -> void:
	var best: Node3D = null
	var best_k := INF
	var eye := cam.global_position
	for n: Node in get_tree().get_nodes_in_group(GROUP):
		if not lockable(n): continue
		var p := point_of(n as Node3D)
		var d := eye.distance_to(p)
		if d > REACH: continue
		var off := _off_middle(cam,p)
		if off.x > IN_VIEW or off.y > IN_VIEW: continue
		if not _in_sight(eye,p): continue
		var k := maxf(off.x,off.y)+d/REACH*0.25
		if k < best_k:
			best_k = k
			best = n as Node3D
	if best == null:
		stats.misses = int(stats.misses)+1
		_reticle.miss = 0.4
		return
	target = best
	why = ""
	_unseen = 0.0
	focus = eye.distance_to(point_of(best))
	stats.locks = int(stats.locks)+1
	_reticle.born = _clock

func _keep(delta: float, cam: Camera3D) -> void:
	var p := point_of(target)
	var eye := cam.global_position
	if eye.distance_to(p) > LET_GO:
		release("far")
		return
	var off := _off_middle(cam,p)
	var seen := off.x <= 1.0 and off.y <= 1.0 and _in_sight(eye,p)
	_unseen = 0.0 if seen else _unseen+delta
	if _unseen >= LOST_S: release("lost")

## How far off the view's middle `p` is, as a share of the half view on each
## axis (> 1 off screen; INF behind).
func _off_middle(cam: Camera3D, p: Vector3) -> Vector2:
	var local := cam.global_transform.affine_inverse()*p
	if local.z >= -0.01: return Vector2(INF,INF)
	var half := _half_view(cam)
	return Vector2(absf(atan2(local.x,-local.z))/half.x,absf(atan2(local.y,-local.z))/half.y)

## The half view (rad), across and up.
func _half_view(cam: Camera3D) -> Vector2:
	var size := cam.get_viewport().get_visible_rect().size
	var aspect := size.x/size.y if size.y > 0.0 else 16.0/9.0
	var v := deg_to_rad(cam.fov)*0.5
	return Vector2(atan(tan(v)*aspect),v)

## Not behind the land: the line from the eye sampled against its height.
func _in_sight(eye: Vector3, p: Vector3) -> bool:
	var field = game.get("field")
	if field == null: return true
	for i: int in range(1,SIGHT_SAMPLES):
		var q := eye.lerp(p,float(i)/float(SIGHT_SAMPLES))
		if q.y < float(field.height(q.x,q.z))-SIGHT_DIP: return false
	return true

# --- The view -------------------------------------------------------------------

## The view turned toward the target, eased, the plane kept in frame.
func _aim(delta: float, cam: Camera3D) -> void:
	var want := Vector2.ZERO
	cam.fov += WIDE*weight
	if target != null:
		var basis := cam.global_basis
		var eye := cam.global_position
		var t := basis.inverse()*(point_of(target)-eye)
		var tang := Vector2(atan2(t.x,-t.z),atan2(t.y,Vector2(t.x,t.z).length()))
		want = tang*BIAS
		# The plane stays in frame: the turn held within PLANE_KEEP of the
		# half view of where the plane sits.
		var plane_at: Vector3 = game.plane.position
		var pl := basis.inverse()*(plane_at-eye)
		if pl.z < -0.5:
			var pang := Vector2(atan2(pl.x,-pl.z),atan2(pl.y,Vector2(pl.x,pl.z).length()))
			var keep := _half_view(cam)*PLANE_KEEP
			want.x = clampf(want.x,pang.x-keep.x,pang.x+keep.x)
			want.y = clampf(want.y,pang.y-keep.y,pang.y+keep.y)
		else:
			want = Vector2.ZERO
	offset = want if delta <= 0.0 else offset.lerp(want,1.0-exp(-delta/AIM_EASE))
	if offset.length() < 0.0005 and target == null:
		offset = Vector2.ZERO
		return
	cam.rotate_object_local(Vector3.UP,-offset.x)
	cam.rotate_object_local(Vector3.RIGHT,offset.y)

# --- The lens -------------------------------------------------------------------

func _lens(delta: float, cam: Camera3D, menu: bool) -> void:
	if target != null:
		var d := cam.global_position.distance_to(point_of(target))
		focus = d if delta <= 0.0 else lerpf(focus,d,1.0-exp(-delta/FOCUS_EASE))
	if weight <= 0.0 or menu:
		if _dof_on:
			if cam.attributes == _dof: cam.attributes = _dof_before
			_dof_on = false
			_dof_before = null
		return
	if not _dof_on:
		_dof_before = cam.attributes
		_dof = CameraAttributesPractical.new()
		if _dof_before is CameraAttributesPractical: _dof = _dof_before.duplicate() as CameraAttributesPractical
		cam.attributes = _dof
		_dof_on = true
	elif cam.attributes != _dof: return
	var ramp := focus*DOF_RAMP+DOF_RAMP_PAD
	_dof.dof_blur_near_enabled = true
	var plane_at: Vector3 = game.plane.position
	var plane_d := cam.global_position.distance_to(plane_at)
	_dof.dof_blur_near_distance = maxf(minf(focus*(1.0-DOF_NEAR),plane_d*PLANE_SHARP),0.5)
	_dof.dof_blur_near_transition = _dof.dof_blur_near_distance*0.6
	_dof.dof_blur_far_enabled = true
	_dof.dof_blur_far_distance = focus*(1.0+DOF_FAR)+DOF_PAD
	_dof.dof_blur_far_transition = ramp
	_dof.dof_blur_amount = DOF_AMOUNT*smoothstep(0.0,1.0,weight)

# --- The reticle ----------------------------------------------------------------

func _draw_reticle(cam: Camera3D) -> void:
	var r := _reticle
	r.miss = maxf(r.miss-get_process_delta_time(),0.0)
	r.on = false
	if target != null or weight > 0.01:
		if target != null and lockable(target):
			r.last = point_of(target)
		var p: Vector3 = r.last
		if not cam.is_position_behind(p):
			r.at = cam.unproject_position(p)
			r.on = cam.get_viewport().get_visible_rect().has_point(r.at)
			# The target's half size on screen (px), so close in the brackets
			# open round it rather than sit on it.
			var rad := float(target.call("lock_radius")) if target != null and target.has_method("lock_radius") else RETICLE_R
			var dist := maxf(cam.global_position.distance_to(p),0.1)
			var tall := cam.get_viewport().get_visible_rect().size.y
			r.body = rad/(dist*tan(deg_to_rad(cam.fov)*0.5))*tall*0.5
	r.weight = weight
	r.locked = target != null
	r.spin = _clock-r.born
	r.queue_redraw()

class Reticle extends Control:
	var on := false
	var locked := false
	var at := Vector2.ZERO
	var last := Vector3.ZERO
	var weight := 0.0
	var spin := 0.0
	var born := 0.0
	var miss := 0.0
	var body := 0.0

	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var mid := get_viewport_rect().size*0.5
		if miss > 0.0:
			# A press with nothing to lock: a brief empty ring in the middle.
			draw_arc(mid,26.0,0.0,TAU,32,Color(1.0,1.0,1.0,0.5*miss/0.4),2.0)
		if not on or weight <= 0.01: return
		# Four corners closing in and turning a quarter as it locks.
		var k := smoothstep(0.0,1.0,weight)
		var s := lerpf(64.0,30.0,k)
		# Close in, it opens to clear the target (RETICLE_OPEN x its half size,
		# up to RETICLE_MOST px), its corners short and thin, the dot gone.
		var wide := clampf(body*RETICLE_OPEN,s,RETICLE_MOST)
		var open := clampf((wide-s)/s,0.0,1.0)
		s = wide
		var turn := (1.0-minf(spin/0.35,1.0))*PI*0.5 if locked else 0.0
		var col := Color(1.0,0.82,0.3,0.95*k) if locked else Color(1.0,1.0,1.0,0.6*k)
		var dark := Color(0.05,0.03,0.02,0.7*k)
		for i: int in 4:
			var a := turn+PI*0.25+PI*0.5*i
			var c := at+Vector2(cos(a),sin(a))*s
			var u := (at-c).normalized()
			var n := Vector2(-u.y,u.x)
			var arm := minf(s*0.45,lerpf(s*0.45,16.0,open))
			var pts := PackedVector2Array([c+(u+n).normalized()*arm,c,c+(u-n).normalized()*arm])
			draw_polyline(pts,dark,lerpf(5.0,3.5,open))
			draw_polyline(pts,col,lerpf(2.5,1.6,open))
		if open < 0.99: draw_circle(at,2.5,Color(col,col.a*(1.0-open)))
		if locked:
			var font := ThemeDB.fallback_font
			var p := at+Vector2(-60.0,s+22.0)
			draw_string_outline(font,p,"LOCKED",HORIZONTAL_ALIGNMENT_CENTER,120.0,16,4,dark)
			draw_string(font,p,"LOCKED",HORIZONTAL_ALIGNMENT_CENTER,120.0,16,col)
