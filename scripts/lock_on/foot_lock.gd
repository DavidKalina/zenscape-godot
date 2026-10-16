extends Node3D
## Lock-on on foot (docs/design/lock-on/spec-lock-on.md): R3 (Tab, the
## middle mouse) locks onto the nearest "lock_targets" member in range and
## roughly in view; again lets go, as does the target staying out of range
## or out of sight a while. `weight` eases 0 -> 1 on lock and back on
## release, so the camera (studies/kit_isle.gd `_frame`) and later the depth
## of field blend in and out, never snapping. A small marker hangs over the
## locked target: a down-pointing wedge that pops in, bobs and turns.
## While the weight is up the camera gets its own CameraAttributesPractical
## with depth of field: him and the target sharp, what lies past them (and
## the very near foreground) softly blurred; it hands back whatever the
## camera had once the weight is back to 0.

const TargetStone = preload("res://scripts/lock_on/target_stone.gd")

## Reach (m from his feet): locks within ACQUIRE, lets go past RELEASE.
## A target with `lock_reach()` (Vector2: acquire, release) sets its own.
const ACQUIRE := 22.0
const RELEASE := 28.0
## Roughly in view: within this of the camera's flat heading (rad).
const VIEW := deg_to_rad(65.0)
## Out of range or out of sight this long (s) and the lock lets go.
const LOSE_AFTER := 1.5
## The blend in and out (s, the ease's time constant).
const BLEND := 0.22
## The marker: its height over the target's top (m), size (m), bob (m, Hz),
## turn (rad/s) and colour (a worn bone white).
const MARK_OVER := 0.38
const MARK_SIZE := Vector3(0.3,0.34,0.08)
## It grows with the camera's distance past MARK_NEAR (m), so it reads
## at range, up to MARK_MOST times.
const MARK_NEAR := 6.0
const MARK_MOST := 3.0
const MARK_BOB := Vector2(0.05,0.9)
const MARK_TURN := 1.4
const MARK_COLOUR := Color(0.93,0.87,0.72)
## Depth of field: the blur at full weight (Godot's dof_blur_amount; photo
## mode's lens uses 0.09), where the far blur starts past the farther of
## him and the target (m, plus a share of that distance), and how long it
## takes to come in fully (m, plus a share). The near blur ends at
## DOF_NEAR of the nearer one's distance.
const DOF_AMOUNT := 0.075
const DOF_FAR_PAST := Vector2(1.5,0.15)
const DOF_FAR_RAMP := Vector2(5.0,1.0)
const DOF_NEAR := 0.45
## His chest over his feet (m): where the camera focuses on him.
const DOF_CHEST := 0.9

## The target locked onto (null when free).
var target: Node3D = null
## What the sight line tests (the isle leaves out its unseen keep-out
## volumes, the parked plane's room).
var sight_mask := 0xFFFFFFFF
## Why the last lock let go ("pressed", "range", "sight", "not allowed"), for checks.
var let_go_why := ""
## 0 free .. 1 fully locked: eased.
var weight := 0.0
## Where the marker last stood over (kept while it fades out).
var _last: Node3D = null
var _lost := 0.0
var _clock := 0.0
var _pop := 0.0
var _mark: MeshInstance3D
var _mat: StandardMaterial3D
## The lens while locked, and what the camera had before (handed back).
var dof: CameraAttributesPractical = null
var _dof_before: CameraAttributes = null
var _dof_on := false

func _ready() -> void:
	top_level = true
	_mark = MeshInstance3D.new()
	_mark.name = "LockMark"
	var wedge := PrismMesh.new()
	wedge.size = MARK_SIZE
	_mark.mesh = wedge
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.no_depth_test = true
	_mat.albedo_color = MARK_COLOUR
	_mat.render_priority = 2
	_mark.material_override = _mat
	_mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mark.visible = false
	add_child(_mark)

func locked() -> bool:
	return target != null and is_instance_valid(target)

## Locks onto the best target from `feet` seen by `camera`; false if none.
func acquire(feet: Vector3, camera: Camera3D) -> bool:
	var best: Node3D = null
	var best_score := INF
	var ahead := -camera.global_basis.z
	var flat_ahead := Vector2(ahead.x,ahead.z).normalized()
	for node: Node in get_tree().get_nodes_in_group(TargetStone.GROUP):
		var t := node as Node3D
		if t == null or not t.is_visible_in_tree(): continue
		var aim: Vector3 = t.call("aim_point")
		var d := aim-feet
		var across := Vector2(d.x,d.z).length()
		var reach := _reach(t)
		if across > reach.x: continue
		var from_cam := aim-camera.global_position
		var off := absf(flat_ahead.angle_to(Vector2(from_cam.x,from_cam.z).normalized()))
		if off > VIEW: continue
		if not _seen(t,camera): continue
		var score := across/reach.x+off/VIEW
		if score < best_score:
			best_score = score
			best = t
	if best == null: return false
	target = best
	_last = best
	_lost = 0.0
	_pop = 0.0
	return true

## `t`'s reach (acquire, release, m): its own, else ACQUIRE and RELEASE.
static func _reach(t: Node3D) -> Vector2:
	return t.call("lock_reach") if t.has_method("lock_reach") else Vector2(ACQUIRE,RELEASE)

func release(why := "pressed") -> void:
	if target != null: let_go_why = why
	target = null
	_lost = 0.0

## One frame: lets go when out of range or sight too long (or `allowed`
## false: flying, off the edge), eases the weight, draws the marker.
func step(delta: float, feet: Vector3, camera: Camera3D, allowed: bool) -> void:
	_clock += delta
	if target != null and not is_instance_valid(target): target = null
	if locked():
		if not allowed: release("not allowed")
		else:
			var aim: Vector3 = target.call("aim_point")
			var far := Vector2(aim.x-feet.x,aim.z-feet.z).length() > _reach(target).y
			if far or not _seen(target,camera): _lost += delta
			else: _lost = 0.0
			if _lost > LOSE_AFTER: release("range" if far else "sight")
	var goal := 1.0 if locked() else 0.0
	if delta > 0.0: weight = lerpf(weight,goal,1.0-exp(-delta/BLEND))
	if absf(weight-goal) < 0.002: weight = goal
	_draw_mark(delta,camera)
	_focus(camera,feet)

## The depth of field: on with the weight, focused across him and the
## target, eased by the weight; off and handed back at weight 0.
func _focus(camera: Camera3D, feet: Vector3) -> void:
	if weight <= 0.0 or _last == null or not is_instance_valid(_last):
		if _dof_on:
			if camera.attributes == dof: camera.attributes = _dof_before
			_dof_on = false
			_dof_before = null
		return
	if not _dof_on:
		_dof_before = camera.attributes
		dof = CameraAttributesPractical.new() if _dof_before == null else _dof_before.duplicate() as CameraAttributesPractical
		if dof == null: dof = CameraAttributesPractical.new()
		camera.attributes = dof
		_dof_on = true
	elif camera.attributes != dof: return # something else took the lens: leave it be
	var eye := camera.global_position
	var him := eye.distance_to(feet+Vector3.UP*DOF_CHEST)
	var aim: Vector3 = _last.call("aim_point")
	var it := eye.distance_to(aim)
	var near := minf(him,it)
	var far := maxf(him,it)
	dof.dof_blur_far_enabled = true
	dof.dof_blur_near_enabled = true
	dof.dof_blur_far_distance = far+DOF_FAR_PAST.x+far*DOF_FAR_PAST.y
	dof.dof_blur_far_transition = DOF_FAR_RAMP.x+far*DOF_FAR_RAMP.y
	dof.dof_blur_near_distance = maxf(near*DOF_NEAR,0.1)
	dof.dof_blur_near_transition = maxf(near*DOF_NEAR*0.8,0.05)
	dof.dof_blur_amount = DOF_AMOUNT*smoothstep(0.0,1.0,weight)

## Whether `camera` sees `t`'s aim point: nothing in between but the target.
func _seen(t: Node3D, camera: Camera3D) -> bool:
	var aim: Vector3 = t.call("aim_point")
	var query := PhysicsRayQueryParameters3D.create(camera.global_position,aim,sight_mask)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty(): return true
	var collider: Node = hit.collider as Node
	if collider != null and (collider == t or t.is_ancestor_of(collider)): return true
	return (hit.position as Vector3).distance_to(aim) < 0.6

func _draw_mark(delta: float, camera: Camera3D) -> void:
	if locked(): _last = target
	if _last == null or not is_instance_valid(_last) or weight <= 0.0:
		_mark.visible = false
		return
	_mark.visible = true
	_pop = minf(_pop+delta*4.0,1.0) if locked() else _pop
	# The pop in: a little overshoot; going out it simply shrinks with the weight.
	var grow := _back_out(_pop) if locked() else weight
	var top: float = _last.call("tall") if _last.has_method("tall") else 1.5
	var over := Vector3.UP*(top+MARK_OVER+sin(_clock*TAU*MARK_BOB.y)*MARK_BOB.x)
	var turn := Basis(Vector3.UP,_clock*MARK_TURN)*Basis(Vector3.FORWARD,PI)
	grow *= clampf(camera.global_position.distance_to(_last.global_position+over)/MARK_NEAR,1.0,MARK_MOST)
	_mark.global_transform = Transform3D(turn.scaled(Vector3.ONE*maxf(grow,0.01)),_last.global_position+over)
	_mat.albedo_color.a = clampf(weight*1.2,0.0,0.92)

static func _back_out(u: float) -> float:
	var s := 1.9
	var v := u-1.0
	return 1.0+v*v*((s+1.0)*v+s)
