extends Node3D
## Picking up and carrying treasures (docs/design/carry/spec-carry.md), on a
## kit isle's wanderer (studies/kit_isle.gd: its `motor`, `body`, `figure`).
## The host stands the treasures on their spots (each spot a node the world
## view moves, `<scene>/treasure_NN`, the treasure resting on it), and takes
## the `walk_carry` action (E, pad B; scripts/pad.gd) on foot:
##
## - by a treasure he lifts it: a heave as long as its weight's `lift`
##   (scripts/carry/carry_weights.gd), the treasure rising from the ground
##   into his hands, his paces held to a shuffle meanwhile;
## - carrying, he holds it before his chest in both hands (two-bone IK on
##   the figure's arms after its clips: procedural, stood in for authored
##   carry clips), his walk, run, jump and turn scaled by its weight;
## - pressed again, he sets it down on the ground before him (or at his
##   feet where there is no ground before him).
##
## `deal()` puts every treasure back on its spot (the scene's re-deal).
const Weights = preload("res://scripts/carry/carry_weights.gd")
const Models = preload("res://scripts/carry/treasure_models.gd")
const LayoutOverrides = preload("res://scripts/layout_overrides.gd")
const Pad = preload("res://scripts/pad.gd")

## What he stands on and sets things down on.
const SOLID_MASK := 1|(1 << 11)
## Reach (m across from his feet to the treasure's foot, times his size; and
## up or down from his feet).
const REACH := 1.1
const REACH_UP := 0.7
## Where its middle rides at the chest: out from the chest bone (m, times
## his size, past its own radius) and up from it (the chest bone's root is
## at his belly, about 0.48 m up on a 1 m wanderer).
const HOLD_OUT := 0.1
const HOLD_UP := 0.08
## Where it is set down: this far before his feet (times his size, past its
## radius); the ground looked for this far over and under.
const SET_OUT := 0.35
const SET_OVER := 1.2
const SET_UNDER := 2.5
## The elbows' pull: out to his sides, down and back (figure frame, +z back).
const ELBOW := Vector3(0.8,-0.6,0.35)
## His paces while he heaves or sets down, times the empty-handed ones.
const BUSY_PACE := 0.05

var study: Node3D = null
var scene_id := ""
## The treasures: [{id, kind, weight, spot (Node3D), node (Node3D), measures}].
var treasures: Array = []
## The one in his hands ({} none), and its phase: "lift", "carry", "set".
var held: Dictionary = {}
var phase := ""
var phase_t := 0.0
## Where the treasure was lifted from or is set down at (its foot, world).
var _ground_at := Transform3D.IDENTITY
## The motor's own feel, kept while he carries.
var _base := {}
var _prompt: Label3D = null

## Stands the treasures in `spec` ([id, kind, weight, foot (world), yaw deg])
## for the kit isle `host`, named `<id_scene>/<id>`.
func setup(host: Node3D, id_scene: String, spec: Array) -> void:
	study = host
	scene_id = id_scene
	name = "Treasures"
	process_priority = 100
	for row: Array in spec:
		var called := "%s/%s" % [scene_id,str(row[0])]
		if LayoutOverrides.deleted(called): continue
		var spot := Node3D.new()
		spot.name = "Spot_"+str(row[0])
		var coded := Transform3D(Basis(Vector3.UP,deg_to_rad(float(row[4]))),row[3])
		spot.transform = LayoutOverrides.xform(called,coded)
		add_child(spot)
		LayoutOverrides.track(called,spot,"token",coded)
		var made := Models.build(str(row[1]))
		var node := Node3D.new()
		node.name = "Treasure_"+str(row[0])
		node.add_child(made.node as Node3D)
		spot.add_child(node)
		treasures.append({"id":str(row[0]),"kind":str(row[1]),"weight":str(row[2]),"spot":spot,"node":node,"measures":made})
	_prompt = Label3D.new()
	_prompt.name = "Prompt"
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.no_depth_test = true
	_prompt.font_size = 36
	_prompt.pixel_size = 0.006
	_prompt.outline_size = 8
	_prompt.visible = false
	add_child(_prompt)

## Every treasure back on its spot, settled on what's under it; nothing
## carried.
func deal() -> void:
	if not held.is_empty(): _let_go()
	for t: Dictionary in treasures: _home(t)

func _home(t: Dictionary) -> void:
	var node: Node3D = t.node
	var spot: Node3D = t.spot
	if node.get_parent() != spot:
		node.get_parent().remove_child(node)
		spot.add_child(node)
	node.transform = Transform3D.IDENTITY
	var foot := _ground_under(spot.global_position,SET_OVER,SET_UNDER)
	if foot != Vector3.INF: node.global_position = foot

## Whether he carries anything (lifting and setting down count).
func carrying() -> bool:
	return not held.is_empty()

## The weight class of what he carries, or "".
func load_class() -> String:
	return "" if held.is_empty() else str(held.weight)

# --- Input ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"walk_carry",false,true) or event.is_echo(): return
	if not _on_foot(): return
	if held.is_empty():
		var t := in_reach()
		if t.is_empty(): return
		lift(t)
	elif phase == "carry": set_down()
	else: return
	get_viewport().set_input_as_handled()

## On foot, walking, the world view shut.
func _on_foot() -> bool:
	if study == null or not bool(study.get("walk_ready")) or bool(study.get("flying")): return false
	var editor := study.get_node_or_null("LayoutEdit")
	return editor == null or not bool(editor.get("editing"))

## The nearest resting treasure in reach of his feet, or {}.
func in_reach() -> Dictionary:
	var motor: Variant = study.get("motor")
	if not motor.grounded: return {}
	var feet: Vector3 = motor.feet
	var s: float = motor.size
	var best := {}
	var near := REACH*s
	for t: Dictionary in treasures:
		if t == held: continue
		var at: Vector3 = (t.node as Node3D).global_position
		var across := Vector2(at.x-feet.x,at.z-feet.z).length()-float(t.measures.radius)
		if across < near and absf(at.y-feet.y) < REACH_UP:
			near = across
			best = t
	return best

# --- Lifting and setting down ---------------------------------------------------------

## Starts the heave of `t`: off its spot, into his hands over its lift.
func lift(t: Dictionary) -> void:
	var node: Node3D = t.node
	_ground_at = node.global_transform
	node.get_parent().remove_child(node)
	add_child(node)
	node.global_transform = _ground_at
	held = t
	phase = "lift"
	phase_t = 0.0
	_keep_feel()
	_apply_feel(BUSY_PACE)

## Starts setting the carried one down before him.
func set_down() -> void:
	if held.is_empty(): return
	var motor: Variant = study.get("motor")
	var fwd := _forward()
	var s: float = motor.size
	var out := SET_OUT*s+float(held.measures.radius)
	var foot := _ground_under(motor.feet+fwd*out,SET_OVER,SET_UNDER)
	if foot == Vector3.INF or absf(foot.y-motor.feet.y) > SET_OVER: foot = motor.feet+fwd*(float(held.measures.radius)*0.5)
	_ground_at = Transform3D(Basis(Vector3.UP,atan2(-fwd.x,-fwd.z)),foot)
	phase = "set"
	phase_t = 0.0
	_apply_feel(BUSY_PACE)

## Let go where it is now: left resting on the ground at `_ground_at`.
func _let_go() -> void:
	var node: Node3D = held.node
	node.global_transform = _ground_at
	held = {}
	phase = ""
	_restore_feel()

func _process(delta: float) -> void:
	if study == null or not bool(study.get("walk_ready")): return
	if not held.is_empty():
		if bool(study.get("flying")):
			var t := held
			_let_go()
			_home(t)
		else: _carry_step(delta)
	_show_prompt()

## One frame of the heave, the carry or the setting down: the treasure moved
## between the ground and his hands, his arms reached to it.
func _carry_step(delta: float) -> void:
	var w := Weights.of(str(held.weight))
	var lift_time: float = w.lift
	var node: Node3D = held.node
	var hands := _hold_xform()
	var k := 1.0
	match phase:
		"lift":
			phase_t += delta
			k = clampf(phase_t/lift_time,0.0,1.0)
			if k >= 1.0:
				phase = "carry"
				_apply_feel(1.0)
		"set":
			phase_t += delta
			k = 1.0-clampf(phase_t/(lift_time*0.7),0.0,1.0)
			if k <= 0.0:
				_let_go()
				return
	var e := smoothstep(0.0,1.0,k)
	node.global_transform = _ground_at.interpolate_with(hands,e)
	_reach_arms(node.global_transform,minf(1.0,k*3.0+0.0001) if phase != "carry" else 1.0)

## Where its foot rides in his hands now (world).
func _hold_xform() -> Transform3D:
	var motor: Variant = study.get("motor")
	var s: float = motor.size
	var fwd := _forward()
	var chest := _bone_world("chest")
	if chest == Vector3.INF: chest = motor.feet+Vector3.UP*0.6*s
	var r: float = held.measures.radius
	var mid := chest+fwd*(HOLD_OUT*s+r)+Vector3.UP*HOLD_UP*s
	var foot := mid+Vector3.DOWN*float(held.measures.height)*0.5
	return Transform3D(Basis(Vector3.UP,atan2(-fwd.x,-fwd.z)),foot)

## His facing (world, flat).
func _forward() -> Vector3:
	var fig: Node3D = study.get("figure")
	var f := -fig.global_basis.z
	f.y = 0.0
	return f.normalized() if f.length() > 0.001 else Vector3.FORWARD

# --- The arms ------------------------------------------------------------------------

func _skeleton() -> Skeleton3D:
	var body: Node = study.get("body")
	return null if body == null else body.get("_skeleton") as Skeleton3D

func _bone_world(bone_name: String) -> Vector3:
	var sk := _skeleton()
	if sk == null: return Vector3.INF
	var b := sk.find_bone(bone_name)
	return Vector3.INF if b < 0 else sk.global_transform*sk.get_bone_global_pose(b).origin

## Both hands reached to the treasure's sides at `at` (its foot, world),
## `weight` of the way, by two-bone IK on each arm (the clips' pose under it).
func _reach_arms(at: Transform3D, weight: float) -> void:
	var sk := _skeleton()
	if sk == null: return
	var fwd := _forward()
	var right := fwd.cross(Vector3.UP).normalized()
	var mid := at.origin+Vector3.UP*float(held.measures.height)*0.5
	var grip: float = held.measures.grip
	var to_sk := sk.global_transform.affine_inverse()
	var sides := [["upper_arm.L","forearm.L","hand.L",-1.0],["upper_arm.R","forearm.R","hand.R",1.0]]
	for side: Array in sides:
		var upper := sk.find_bone(str(side[0]))
		var fore := sk.find_bone(str(side[1]))
		var hand := sk.find_bone(str(side[2]))
		if upper < 0 or fore < 0 or hand < 0: return
		var s: float = side[3]
		var goal := to_sk*(mid+right*s*grip)
		var pole_w := right*s*ELBOW.x+Vector3.UP*ELBOW.y-fwd*ELBOW.z
		var pole := (sk.global_basis.inverse()*pole_w).normalized()
		var shoulder := sk.get_bone_global_pose(upper).origin
		var elbow := sk.get_bone_global_pose(fore).origin
		var wrist := sk.get_bone_global_pose(hand).origin
		var a := shoulder.distance_to(elbow)
		var b := elbow.distance_to(wrist)
		var to := goal-shoulder
		var d := clampf(to.length(),0.01,(a+b)*0.999)
		var n := to.normalized()
		var along := (a*a-b*b+d*d)/(2.0*d)
		var out := sqrt(maxf(a*a-along*along,0.0))
		var bend := (pole-n*pole.dot(n)).normalized()
		_aim(sk,upper,elbow-shoulder,n*along+bend*out,weight)
		elbow = sk.get_bone_global_pose(fore).origin
		wrist = sk.get_bone_global_pose(hand).origin
		_aim(sk,fore,wrist-elbow,shoulder+n*d-elbow,weight)
		# The mitt turned in, palm to the treasure's side.
		wrist = sk.get_bone_global_pose(hand).origin
		var tip := sk.get_bone_global_pose(hand)*Vector3(0.0,0.03,0.0)
		_aim(sk,hand,tip-wrist,goal-wrist+(to_sk.basis*(-right*s))*0.02,weight)

## Turns `bone` so its `from` (skeleton space) points along `to`, `weight`
## of the way (scripts/pilot_figure.gd's `_aim_bone`).
static func _aim(sk: Skeleton3D, bone: int, from: Vector3, to: Vector3, weight: float) -> void:
	var axis := from.cross(to)
	if axis.length() < 1e-6: return
	var angle := from.angle_to(to)*weight
	var local := (sk.get_bone_global_pose(bone).basis.inverse()*axis).normalized()
	sk.set_bone_pose_rotation(bone,sk.get_bone_pose_rotation(bone)*Quaternion(local,angle))

# --- The motor's feel ----------------------------------------------------------------

func _keep_feel() -> void:
	var m: Variant = study.get("motor")
	_base = {"walk":m.walk,"run":m.run,"jumps":(m.jumps as Array).duplicate(),"turn":m.turn,"turn_run":m.turn_run}

## The carried weight's scales on the kept feel; `pace` times the paces
## more (BUSY_PACE while heaving).
func _apply_feel(pace: float) -> void:
	if _base.is_empty(): return
	var m: Variant = study.get("motor")
	var w := Weights.of(str(held.weight))
	m.walk = float(_base.walk)*float(w.walk)*pace
	m.run = float(_base.run)*float(w.run)*pace
	var j: Array = []
	for h: float in _base.jumps: j.append(h*float(w.jump)*(1.0 if pace >= 1.0 else 0.0))
	m.jumps = j
	m.turn = float(_base.turn)*float(w.turn)
	m.turn_run = float(_base.turn_run)*float(w.turn)

func _restore_feel() -> void:
	if _base.is_empty(): return
	var m: Variant = study.get("motor")
	m.walk = _base.walk
	m.run = _base.run
	m.jumps = (_base.jumps as Array).duplicate()
	m.turn = _base.turn
	m.turn_run = _base.turn_run
	_base = {}

# --- The prompt ----------------------------------------------------------------------

func _show_prompt() -> void:
	var t := {} if not _on_foot() or not held.is_empty() else in_reach()
	if t.is_empty():
		_prompt.visible = false
		return
	_prompt.text = Pad.pick("E  lift","B  lift")
	_prompt.global_position = (t.node as Node3D).global_position+Vector3.UP*(float(t.measures.height)+0.3)
	_prompt.visible = true

## The ground under `p` (a ray from `over` above to `under` below; flat
## enough to stand on), or INF.
func _ground_under(p: Vector3, over: float, under: float) -> Vector3:
	var space := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(p+Vector3.UP*over,p+Vector3.DOWN*under,SOLID_MASK)
	var hit := space.intersect_ray(ray)
	if hit.is_empty() or (hit.normal as Vector3).y < 0.6: return Vector3.INF
	return hit.position
