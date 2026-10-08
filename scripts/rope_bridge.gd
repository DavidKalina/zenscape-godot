extends MeshInstance3D
## A rope bridge that lives (docs/scenic/bridges.md): the footbridge's own
## static faceted mesh (scripts/footbridge.gd `build_mesh`), drawn through
## shaders/rope_bridge.gdshader, which moves its vertices by how far the
## ropes stand off their sag pose, as stepped by scripts/rope_bridge_sim.gd.
## The plate's footbridges (scripts/footbridge.gd) and the sky clusters'
## (scripts/cluster_dresser.gd) both hang theirs on one of these.
##
## Near the eye (within WAKE m) it lives: the pilot's weight sags it where he
## stands, his footfalls and landings bounce it, the wind sways it, a plane
## passing close makes it shudder. Farther, its swing is damped away over
## FADE m, so it eases back into the static pose and sleeps; a sleeping one
## costs a distance check a frame.
##
## The walker (scripts/wanderer_eye.gd) tells it where the pilot is each
## frame (`tread`) and is carried with its sway; the deck's height under him
## comes from the deck record's "sim" (read by Footbridge `deck_at` and
## SkyIslet `deck_y`), so feet and planks move as one. `hold`
## keeps him between the hand ropes. The plane tells it where it is
## (`flown_by`).

const Sim = preload("res://scripts/rope_bridge_sim.gd")
const SHADER = preload("res://shaders/rope_bridge.gdshader")

## Within WAKE m of the eye a bridge lives; over the next FADE m its swing
## dies away; past WAKE+FADE, once still, it sleeps.
const WAKE := 70.0
const FADE := 25.0
## The pilot counts as on the deck within its width (plus STAND_SLACK m to a
## side) and STAND_OVER m over its planks (feet down on them, or just off
## them in a hop).
const STAND_SLACK := 0.1
const STAND_OVER := 0.25
## The hand ropes' height over the deck (m) (Footbridge HAND_ROPE), and the
## walker's room inside them (m from the deck's edge). Jumped this far over
## the hand ropes, he is let over them.
const HAND_ROPE := 0.8
const ROPE_ROOM := 0.14
const OVER_ROPE := 0.15
## The wind: m/s at a strength of 1 (PollenWind DRIFT), m/s per unit of a
## gust front's lean.
const WIND_SPEED := 2.4
const FRONT_WIND := 3.0
## A plane within PLANE_REACH m of the deck shudders it, the more the closer
## and the faster (full at PLANE_FAST m/s).
const PLANE_REACH := 28.0
const PLANE_FAST := 22.0

## Every bridge in the tree, for the walker and the plane.
static var _live: Array = []

var sim: RefCounted
## The ends (the mesh's frame, on the ground), the sag at the middle (m,
## negative), the span (m, flat), the way across (+side), the deck record
## the walker reads.
var a := Vector3.ZERO
var b := Vector3.ZERO
var bow := 0.0
var span := 1.0
var across := Vector3.RIGHT
var deck: Dictionary = {}
var _shader: ShaderMaterial
var _deck_pack := PackedVector4Array()
var _hand_pack := PackedVector4Array()
var _drawn_awake := false
var _stood := Vector3.INF
var _carry_t := -1.0
var _carry_was := 0.0

## A live rope bridge for `mesh` (Footbridge `build_mesh(end_a, end_b,
## seed_value)`), its deck `width` m, `planks` across it; `record` the deck
## record the walker reads (its "sim" is set here), or {}.
static func make(mesh: Mesh, end_a: Vector3, end_b: Vector3, seed_value: int, sag: float, width: float, planks: int, record := {}) -> MeshInstance3D:
	var bridge: MeshInstance3D = new()
	bridge._setup(mesh,end_a,end_b,seed_value,sag,width,planks,record)
	return bridge

func _setup(mesh_in: Mesh, end_a: Vector3, end_b: Vector3, seed_value: int, sag: float, width: float, planks: int, record: Dictionary) -> void:
	mesh = mesh_in
	a = end_a
	b = end_b
	bow = sag
	var flat := Vector3(b.x-a.x,0.0,b.z-a.z)
	span = maxf(flat.length(),0.01)
	across = (flat/span).cross(Vector3.UP).normalized()
	sim = Sim.new(span,width,seed_value)
	deck = record
	deck["sim"] = sim
	_shader = ShaderMaterial.new()
	_shader.shader = SHADER
	_shader.set_shader_parameter("end_a",a)
	_shader.set_shader_parameter("end_b",b)
	_shader.set_shader_parameter("bow",bow)
	_shader.set_shader_parameter("width",width)
	_shader.set_shader_parameter("nodes",sim.nodes)
	_shader.set_shader_parameter("planks",float(planks))
	material_override = _shader
	# Room for the swing outside the static mesh's box.
	extra_cull_margin = 1.0
	process_priority = -10
	_write()

## In the tree its deck lives; out of it the deck is the static one again.
func _enter_tree() -> void:
	if not _live.has(self): _live.append(self)
	deck["sim"] = sim

func _exit_tree() -> void:
	_live.erase(self)
	if deck.get("sim") == sim: deck.erase("sim")

func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	var far := 0.0
	var middle := global_transform*(a.lerp(b,0.5))
	if camera != null:
		var d := camera.global_position.distance_to(middle)
		if d > WAKE+FADE and not sim.awake and _stood == Vector3.INF:
			if _drawn_awake: _write()
			return
		far = clampf((d-WAKE)/FADE,0.0,1.0)
	if far < 1.0: _blow(middle)
	else: sim.wind(0.0)
	if _stood != Vector3.INF: sim.load(_stood.x,_stood.y,_stood.z)
	_stood = Vector3.INF
	sim.step(delta,far)
	_write()

## The shader's samples from the sim (all zero asleep).
func _write() -> void:
	sim.pack(_deck_pack,_hand_pack)
	_shader.set_shader_parameter("deck",_deck_pack)
	_shader.set_shader_parameter("hand",_hand_pack)
	_shader.set_shader_parameter("rattle",sim.rattle)
	_drawn_awake = sim.awake

## The air across the bridge now, from the atmosphere the scenery's wind
## reads (as scripts/pollen_wind.gd does): its strength and breath, the
## gust parcels it has sent, the gust fronts rolling by.
func _blow(middle: Vector3) -> void:
	var scene := get_tree().current_scene if is_inside_tree() else null
	var air: Variant = scene.get("_atmosphere") if scene != null else null
	if not (air is Object) or air.get("_air_angle") == null:
		sim.wind(0.0)
		return
	var strength := maxf(float(air._air_strength)+float(air.swell),0.0)*float(air.gust_at(float(air._wind_time)))
	var way := Vector2(cos(float(air._air_angle)),sin(float(air._air_angle)))
	var pulse := 0.0
	if air.get("puffs") != null: pulse = float(air.puffs.sample_at(Vector2(middle.x,middle.z),way,float(air._gust_distance)))
	var speed := WIND_SPEED*strength*(0.45+1.1*minf(1.0,0.5+pulse))
	if air.get("fronts") != null: speed += FRONT_WIND*maxf(float(air.fronts.lean_at(Vector2(middle.x,middle.z),way)),0.0)
	var flow := global_basis.inverse()*Vector3(way.x,0.0,way.y)*speed
	var along := (b-a)
	along.y = 0.0
	sim.wind(flow.dot(across),flow.dot(along.normalized()))

## Where a point of this bridge's frame stands on the deck: Vector3(t, side
## (m off its middle line, toward +across), height over the planks' top),
## t outside 0 to 1 off its ends.
func _on_deck(local: Vector3) -> Vector3:
	var rel := Vector2(local.x-a.x,local.z-a.z)
	var way := Vector2(b.x-a.x,b.z-a.z)/span
	var t := rel.dot(way)/span
	var side := rel.dot(Vector2(across.x,across.z))
	var tc := clampf(t,0.0,1.0)
	var top := lerpf(a.y,b.y,tc)+bow*pow(sin(PI*tc),2.0)+float(sim.drop(tc,side-sim.sway(tc)))
	return Vector3(t,side,local.y-top)

# --- The walker and the plane -------------------------------------------------------

## The pilot this frame: `frame` the node whose frame `feet` are in (the
## plate's terrain, or the islet stood on), `grounded`, the motor's events
## (`landed`) and the body's (`footfall`), `effort` 0 at a walk to 1 at a
## run. The deck under him takes his weight (from the next step), a
## footfall or a landing its push. Returns how far (the frame's metres) the
## deck's sway carried his feet since the last frame.
static func tread(frame: Node3D, feet: Vector3, grounded: bool, events: Dictionary, drawn: Dictionary, effort: float) -> Vector3:
	if frame == null or not frame.is_inside_tree(): return Vector3.ZERO
	var world := frame.global_transform*feet
	for bridge: MeshInstance3D in _live:
		var on: Vector3 = bridge._on_deck(bridge.global_transform.affine_inverse()*world)
		var width := float(bridge.sim.width)
		if on.x <= 0.0 or on.x >= 1.0 or absf(on.y-bridge.sim.sway(on.x)) > width*0.5+STAND_SLACK or on.z > STAND_OVER or on.z < -0.3:
			if bridge._carry_t >= 0.0: bridge._carry_t = -1.0
			continue
		if grounded: bridge._stood = Vector3(on.x,on.y,1.0)
		if events.has("landed"): bridge.sim.land(on.x,on.y,float(events.landed))
		if drawn.has("footfall") and grounded: bridge.sim.step_on(on.x,on.y,effort,int(drawn.footfall))
		# Carried with the sway.
		var now: float = bridge.sim.sway(on.x)
		var carry := 0.0
		if bridge._carry_t >= 0.0 and grounded: carry = now-bridge._carry_was
		bridge._carry_t = on.x
		bridge._carry_was = now
		if carry == 0.0: return Vector3.ZERO
		var shift: Vector3 = bridge.global_basis*(bridge.across*carry)
		return frame.global_basis.inverse()*shift
	return Vector3.ZERO

## `to` (the frame's x, z) for feet at `feet` in `frame`, kept between a
## live bridge's hand ropes when the feet are on its deck: pulled back in
## across it, as far as ROPE_ROOM inside its edge, anywhere but past its
## ends. Jumped clear over the ropes, let through.
static func hold(frame: Node3D, feet: Vector3, to: Vector2) -> Vector2:
	if frame == null or not frame.is_inside_tree(): return to
	for bridge: MeshInstance3D in _live:
		var into: Transform3D = bridge.global_transform.affine_inverse()*frame.global_transform
		var on: Vector3 = bridge._on_deck(into*feet)
		var width := float(bridge.sim.width)
		if on.x <= 0.0 or on.x >= 1.0 or absf(on.y-bridge.sim.sway(on.x)) > width*0.5+STAND_SLACK: continue
		if on.z > HAND_ROPE+OVER_ROPE or on.z < -0.5: continue
		var next: Vector3 = into*Vector3(to.x,feet.y,to.y)
		var rel := Vector2(next.x-bridge.a.x,next.z-bridge.a.z)
		var way: Vector2 = Vector2(bridge.b.x-bridge.a.x,bridge.b.z-bridge.a.z)/bridge.span
		var t: float = rel.dot(way)/bridge.span
		if t <= 0.0 or t >= 1.0: return to
		var centre: float = bridge.sim.sway(t)
		var room := maxf(width*0.5-ROPE_ROOM,0.0)
		var side := rel.dot(Vector2(bridge.across.x,bridge.across.z))
		if absf(side-centre) <= room: return to
		var held: Vector2 = Vector2(bridge.a.x,bridge.a.z)+way*t*bridge.span+Vector2(bridge.across.x,bridge.across.z)*(centre+clampf(side-centre,-room,room))
		var back: Vector3 = into.affine_inverse()*Vector3(held.x,next.y,held.y)
		return Vector2(back.x,back.z)
	return to

## The plane at `world` going `velocity` (m/s): every live bridge within
## PLANE_REACH of it shudders.
static func flown_by(world: Vector3, velocity: Vector3) -> void:
	var fast := clampf(velocity.length()/PLANE_FAST,0.0,1.5)
	if fast < 0.1: return
	for bridge: MeshInstance3D in _live:
		var local: Vector3 = bridge.global_transform.affine_inverse()*world
		var near := Geometry3D.get_closest_point_to_segment(local,bridge.a,bridge.b)
		var d := near.distance_to(local)
		if d < PLANE_REACH: bridge.sim.shudder(pow(1.0-d/PLANE_REACH,1.5)*fast)
