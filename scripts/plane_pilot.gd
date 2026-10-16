extends Node3D
## The pilot in the plane's cockpit (scripts/plane_figure.gd), alive in the
## seat like a kart racer's driver, chest up out of the cockpit, both gloved
## hands on the stick. The wanderer (`wanderer`, the sheet's look,
## docs/design/plane-look/round1.md, docs/design/wanderer-look/round2.md) is
## the walker himself: his own head and hat lifted off his model (assets/
## models/pilot.glb, in his paint, scripts/pilot_paint.gd), the dark faceless
## head with the glowing eyes painted on it that blink now and then, the
## terracotta hat with its low crown, brown band and wide floppy brim; and
## its brim drawn in to suit the cockpit (`_trim_brim`); and soft and
## rounded in the plane's paint (scripts/soft_mesh.gd, shaders/
## plane_surface.gdshader) in his worn colours, a chunky navy scarf wound
## at the neck, the charcoal-brown jacket, brown mitts. The sky's other
## pilots (a livery's) keep the folk's faceted leather cap and brass
## goggles (scripts/person_kit.gd `chest`, `head`).
##
## Everything moves on springs, so it lags, overshoots a little and settles:
## the body leans into a turn and the head looks into it, levelling against
## the lean; a pull-up sinks them into the seat and a push lifts them; boost
## hunches them forward, the brake sits them back; the engine buzzes through
## them. The hands work the stick with the turn and climb. Left alone, every
## few seconds they do something: glance down at the land, look back over a
## shoulder, bob their head along, or wave back at whoever is following. In
## a barrel roll both arms go up.
##
## Built in the figure's frame: it sits at the seat, the nose along -Z.

const PersonKit = preload("res://scripts/person_kit.gd")
const FacetMesh = preload("res://scripts/facet_mesh.gd")
const SoftMesh = preload("res://scripts/soft_mesh.gd")
const PilotPaint = preload("res://scripts/pilot_paint.gd")
const PLANE_SURFACE := preload("res://shaders/plane_surface.gdshader")
const Spring = PersonKit.Spring

## The seat in the figure's frame.
const SEAT := Vector3(0.0,0.11,0.24)
## Arms: the upper arm's and forearm's length, and where the hands hold
## the stick.
const ARM := Vector2(0.07,0.07)
const STICK := Vector3(0.022,0.05,-0.09)
## The head's size against the body.
const HEAD_SCALE := 0.9
## Seconds between idle moves, least and most.
const IDLE_EVERY := Vector2(2.5,6.0)
## The walker's colours (scripts/pilot_paint.gd, the character sheet's):
## the scarf's navy, the jacket's charcoal brown, the mitts' brown.
## Aged as the plane's paint is, the walker's worn look's own colours
## (scripts/pilot_paint.gd LOOKS "worn").
const NAVY := Color("3b4a6b")
const JACKET := Color("534739")
const MITT := Color("6c4632")
## His paint's light and grime, as the plane's (scripts/plane_figure.gd
## PAINT_FILL, PAINT_RIM; shaders/craft_grime.gdshaderinc): the grime's
## cells a toy unit and how heavy it lies.
const PAINT_FILL := 1.3
const PAINT_RIM := 0.18
const PAINT_ROUGH := 0.88
const GRIT_SCALE := 9.0
const GRIT := 0.7
## The hat's brim in the cockpit (head frame, drawn to HEAD_RADIUS): what
## lies past CROWN from the head's axis is drawn in to BRIM_FIT of its
## reach, so the walker's wide brim suits the biplane's slim cockpit and
## clears its upper wing. The crown and band are left as they are.
const CROWN := 0.11
const BRIM_FIT := 0.5
## The hat's felt in the cockpit: the plane's oxide red, and less of the
## sky in its shade (scripts/pilot_paint.gd's paint `fill`, 3.2 on foot).
const HAT_FELT := Color("8c4a37")
const HAT_FILL := 2.2
## The walker's head and hat, lifted off his model: the head's middle there
## (m, rest; art/blender/pilot/pilot_build.py PILOT_HEAD, its radius), and
## the head's radius here and its middle over the neck (the pilot's units).
## The sheet's chibi, a big round head under a hat whose brim reaches past
## the shoulders; round two drew him a little smaller and lower in the seat
## (radius 0.116 to 0.1, the hat's top 0.06 lower), so the chase camera
## sees more of the plane past him. Round three's walker has a bigger head
## and a wider brim (2.2 times the head); drawn to the same head radius
## here, the brim reaches 0.22 (round two's 0.19) and the hat's top stands
## a little lower.
const WALKER_HEAD := Vector3(0.0,0.9551,0.0)
const WALKER_HEAD_RADIUS := 0.2259
const HEAD_RADIUS := 0.1
const HEAD_UP := 0.095
## The eyes' blink: seconds between, least and most, and seconds shut.
const BLINK_EVERY := Vector2(2.0,5.5)
const BLINK := 0.12

var _torso: Node3D
var _neck: Node3D
var _head: Node3D
## Per arm (left, right): the upper arm, the forearm and the hand.
var _arms := []
var _lean := Spring.new(2.2,0.35)
var _hunch := Spring.new(2.0,0.45)
var _twist := Spring.new(2.0,0.5)
var _bob := Spring.new(3.0,0.3)
var _yaw := Spring.new(2.6,0.45)
var _nod := Spring.new(3.0,0.4)
var _tilt := Spring.new(2.4,0.45)
## Each hand's offset from the stick, as springs (x, y, z per hand).
var _reach := []
var _rng := RandomNumberGenerator.new()
var _clock := 0.0
## The idle move now: its name, seconds left in it, its look (yaw, nod) and
## which side it favours; and the seconds till the next.
var _idle := ""
var _idle_left := 0.0
var _idle_look := Vector2.ZERO
var _idle_next := 2.0
## The wanderer's face paint (its eyes' `blink`), and the blink's clock:
## seconds to the next, and seconds left shut (below 0 open); a second
## blink may follow.
var _face: ShaderMaterial
var _blink_next := 3.0
var _blink_left := -1.0
var _blink_again := false

## `materials` is a PersonKit outfit; `wanderer` dresses him as the
## wanderer (the hat, the eyes, the navy scarf), else as the folk.
func _init(materials: Dictionary, wanderer := true) -> void:
	name = "Pilot"
	position = SEAT
	_rng.randomize()
	_idle_next = _rng.randf_range(IDLE_EVERY.x,IDLE_EVERY.y)
	_blink_next = _rng.randf_range(BLINK_EVERY.x,BLINK_EVERY.y)
	_torso = Node3D.new()
	add_child(_torso)
	if wanderer:
		materials = {"jacket":_painted(JACKET,0.4),"scarf":_painted(NAVY,0.7),"leather":_painted(MITT,0.55)}
		_wanderer_chest(materials)
	else:
		PersonKit.chest(_torso,materials)
	var pivots := _wanderer_head(materials) if wanderer else PersonKit.head(_torso,materials,HEAD_SCALE)
	_neck = pivots[0]
	_head = pivots[1]
	# The arms, posed each frame from shoulder to hand.
	for side in [-1.0,1.0]:
		if wanderer:
			var arm := []
			for mesh: Mesh in [SoftMesh.cylinder(0.021,0.018,1.0,12),SoftMesh.cylinder(0.018,0.016,1.0,12),SoftMesh.ball(0.023,12)]:
				arm.append(PersonKit.part(_torso,mesh,materials.leather if arm.size() == 2 else materials.jacket,Vector3.ZERO,Vector3.ZERO))
			_arms.append(arm)
		else:
			_arms.append(PersonKit.limb(_torso,Vector2(0.019,0.016),Vector2(0.016,0.014),materials.jacket,PersonKit.hand(),materials.leather))
		_reach.append([Spring.new(3.2,0.5),Spring.new(3.2,0.5),Spring.new(3.2,0.5)])
	animate(0.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0)

## The plane's paint (shaders/plane_surface.gdshader) in `color`, `own`
## its colour shift.
static func _painted(color: Color, own: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PLANE_SURFACE
	m.set_shader_parameter("albedo",color)
	m.set_shader_parameter("own",own)
	m.set_shader_parameter("fill",PAINT_FILL)
	m.set_shader_parameter("rim",PAINT_RIM)
	m.set_shader_parameter("roughness_value",PAINT_ROUGH)
	m.set_shader_parameter("grit_scale",GRIT_SCALE)
	m.set_shader_parameter("grit",GRIT)
	return m

## The wanderer's chest, as PersonKit `chest` but soft: the charcoal coat
## swelling to round shoulders, the navy scarf wound twice round the neck
## and its knot behind (PersonKit.KNOT, where the tails stream from).
func _wanderer_chest(m: Dictionary) -> void:
	var up := Vector3(-PI*0.5,0.0,0.0)
	PersonKit.part(_torso,SoftMesh.hull([Vector3(0.0,0.07,0.056),Vector3(0.06,0.084,0.062),Vector3(0.115,0.09,0.06),Vector3(0.15,0.05,0.042),Vector3(0.158,0.0,0.0)],12),m.jacket,Vector3.ZERO,up)
	for side in [-1.0,1.0]: PersonKit.part(_torso,SoftMesh.ball(0.03,12),m.jacket,Vector3(PersonKit.SHOULDER.x*side,PersonKit.SHOULDER.y,0.0),Vector3.ZERO)
	PersonKit.part(_torso,SoftMesh.torus(0.05,0.023,28,12),m.scarf,Vector3(0.0,PersonKit.NECK-0.01,0.002),Vector3.ZERO)
	PersonKit.part(_torso,SoftMesh.torus(0.046,0.021,28,12),m.scarf,Vector3(0.0,PersonKit.NECK+0.018,0.002),Vector3(0.12,0.0,0.0))
	PersonKit.part(_torso,SoftMesh.ball(0.022,12),m.scarf,PersonKit.KNOT,Vector3.ZERO)

## The wanderer's neck and head on the chest, returned [neck, head], each a
## pivot to turn, as PersonKit `head`: the walker's own head and hat
## (`head_mesh`), his face's paint its own here, to blink.
func _wanderer_head(m: Dictionary) -> Array:
	var neck := Node3D.new()
	neck.position = Vector3(0.0,PersonKit.NECK,0.0)
	_torso.add_child(neck)
	PersonKit.part(neck,SoftMesh.cylinder(0.03,0.026,0.05,12),m.jacket,Vector3(0.0,0.02,0.0),Vector3.ZERO)
	var pivot := Node3D.new()
	pivot.position = Vector3(0.0,0.035,0.0)
	neck.add_child(pivot)
	var head := MeshInstance3D.new()
	head.name = "Head"
	head.mesh = head_mesh()
	head.position = Vector3(0.0,HEAD_UP-pivot.position.y,0.0)
	pivot.add_child(head)
	for i in range(head.mesh.get_surface_count()):
		var paint := head.mesh.surface_get_material(i)
		if paint != null and paint.resource_name == "pilot_face":
			_face = paint.duplicate()
			head.set_surface_override_material(i,_face)
	return [neck,pivot]

static var _head_mesh: ArrayMesh

## The walker's head and hat (scripts/pilot_paint.gd `lift`), the head's
## middle at the origin, drawn to HEAD_RADIUS, the brim drawn in
## (`_trim_brim`); made once.
static func head_mesh() -> ArrayMesh:
	if _head_mesh == null:
		var at := Transform3D(Basis.from_scale(Vector3.ONE*HEAD_RADIUS/WALKER_HEAD_RADIUS),Vector3.ZERO)*Transform3D(Basis(),-WALKER_HEAD)
		_head_mesh = _trim_brim(PilotPaint.lift(["pilot_face"]+PilotPaint.HAT,at,PilotPaint.outfit()))
	return _head_mesh

## `mesh` with its hat's points past CROWN from the head's axis drawn in to
## BRIM_FIT of their reach past it (the brim narrower, the crown kept), and
## the felt in HAT_FELT.
static func _trim_brim(mesh: ArrayMesh) -> ArrayMesh:
	var out := ArrayMesh.new()
	for i in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(i)
		var material := mesh.surface_get_material(i)
		if material != null and material.resource_name == "pilot_hat":
			material = material.duplicate()
			material.set_shader_parameter("albedo",HAT_FELT)
			material.set_shader_parameter("fill",HAT_FILL)
		if material != null and material.resource_name in PilotPaint.HAT:
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for k in range(points.size()):
				var p := points[k]
				var reach := Vector2(p.x,p.z).length()
				if reach <= CROWN: continue
				var fit := (CROWN+(reach-CROWN)*BRIM_FIT)/reach
				points[k] = Vector3(p.x*fit,p.y,p.z*fit)
			arrays[Mesh.ARRAY_VERTEX] = points
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		out.surface_set_material(i,material)
	return out

## The scarf's knot in the figure's frame.
func knot() -> Vector3:
	return transform*(_torso.transform*PersonKit.KNOT)

## One frame: `bank` and `pitch` the flight's, `roll_rate` and `pitch_rate`
## how fast they change (rad/s), `throttle` -1 braking to 1 boosting,
## `spin` the barrel roll's angle, `engine` 0 to 1.
func animate(delta: float, bank: float, pitch: float, roll_rate: float, pitch_rate: float, throttle: float, spin: float, engine: float) -> void:
	_clock += delta
	_think(delta)
	_blink(delta)
	var trick := absf(spin) > 0.05
	var look := _idle_look
	if trick: look = Vector2(0.0,0.35)
	# The body: leaning into the turn, hunched or sat back, sunk or lifted.
	var lean := _lean.step(clampf(-bank*0.45-roll_rate*0.04,-0.5,0.5),delta)
	var hunch := _hunch.step(clampf(-0.22*maxf(throttle,0.0)+0.12*maxf(-throttle,0.0)+pitch_rate*0.06,-0.35,0.25),delta)
	var twist := _twist.step(look.x*0.25,delta)
	var bob := _bob.step(clampf(-pitch_rate*0.012,-0.02,0.02),delta)
	var buzz := sin(_clock*37.0)*0.0012*engine
	_torso.position = Vector3(0.0,bob+buzz,0.0)
	_torso.rotation = Vector3(hunch,twist,lean)
	# The head: looking into the turn and at whatever the idle picked,
	# levelling against the body's lean, half the turn in the neck.
	var yaw := _yaw.step(clampf(-bank*0.9,-0.9,0.9)+look.x-twist,delta)
	var groove := sin(_clock*TAU*2.1)*0.12 if _idle == "groove" else 0.0
	var nod := _nod.step(look.y-hunch*0.6+groove,delta)
	var tilt := _tilt.step(-lean*0.7+(sin(_clock*TAU*1.05)*0.1 if _idle == "groove" else 0.0),delta)
	_neck.rotation = Vector3(nod*0.4,yaw*0.4,tilt*0.4)
	_head.rotation = Vector3(nod*0.6,yaw*0.6,tilt*0.6)
	# The hands: on the stick, which moves with the turn and the climb;
	# up for a trick; the right one waving.
	for s in range(2):
		var side := -1.0 if s == 0 else 1.0
		var target := STICK*Vector3(side,1.0,1.0)+Vector3(clampf(roll_rate*0.012,-0.02,0.02),0.0,clampf(-pitch_rate*0.03,-0.02,0.02))
		if trick: target = Vector3(0.11*side,0.25,-0.02)
		elif _idle == "wave" and side > 0.0: target = Vector3(0.12+sin(_clock*12.0)*0.03,0.24,-0.03)
		var springs: Array = _reach[s]
		var hand := Vector3((springs[0] as Spring).step(target.x,delta),(springs[1] as Spring).step(target.y,delta),(springs[2] as Spring).step(target.z,delta))
		PersonKit.pose(_arms[s],PersonKit.SHOULDER*Vector3(side,1.0,1.0),hand,ARM,Vector3(side,-0.6,0.4))

## Now and then the wanderer's eyes shut for a moment, sometimes twice.
func _blink(delta: float) -> void:
	if _face == null: return
	if _blink_left >= 0.0:
		_blink_left -= delta
		if _blink_left < 0.0:
			_face.set_shader_parameter("blink",0.0)
			if _blink_again:
				_blink_again = false
				_blink_next = 0.12
			else:
				_blink_next = _rng.randf_range(BLINK_EVERY.x,BLINK_EVERY.y)
		return
	_blink_next -= delta
	if _blink_next > 0.0: return
	_blink_left = BLINK
	_blink_again = _blink_again or _rng.randf() < 0.25
	_face.set_shader_parameter("blink",1.0)

## Every few seconds an idle move: a glance down at the land, a look back
## over a shoulder, a head-bob, or a wave back at the follower.
func _think(delta: float) -> void:
	if _idle != "":
		_idle_left -= delta
		if _idle_left <= 0.0:
			_idle = ""
			_idle_look = Vector2.ZERO
			_idle_next = _rng.randf_range(IDLE_EVERY.x,IDLE_EVERY.y)
		return
	_idle_next -= delta
	if _idle_next > 0.0: return
	var side := -1.0 if _rng.randf() < 0.5 else 1.0
	var pick := _rng.randf()
	if pick < 0.45:
		_idle = "glance"
		_idle_left = _rng.randf_range(0.8,1.8)
		_idle_look = Vector2(_rng.randf_range(0.5,1.2)*side,-_rng.randf_range(0.15,0.5))
	elif pick < 0.65:
		_idle = "look_back"
		_idle_left = _rng.randf_range(1.0,1.6)
		_idle_look = Vector2(1.9*side,0.1)
	elif pick < 0.85:
		_idle = "groove"
		_idle_left = _rng.randf_range(2.0,3.5)
		_idle_look = Vector2.ZERO
	else:
		_idle = "wave"
		_idle_left = 1.8
		_idle_look = Vector2(-1.9,0.15)
