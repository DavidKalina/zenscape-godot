extends Node3D
## The pocket sail, drawn (scripts/pocket_sail.gd flies it): the wanderer's
## "float with cap". His hat lifts off his head and spins overhead like a
## rotor, soft cyan glow rings turning under its brim, and he hangs below
## it; folded, it drops back onto his head. Put on the pilot's figure (its
## origin at the feet, facing -Z), as his body is: `update` each frame
## lifts it over OPEN_TIME as it opens (spinning up, swelling past its
## height and settling), brings it down over FOLD_TIME, bobs it, leans it
## into a turn and spins it faster and glows it brighter in rising air
## (`lift`, 0 to 1: a thermal ridden). While it is out his figure hides the
## hat on his head (scripts/pilot_figure.gd), so there is only ever one.
##
## The hat is the model's own (assets/models/pilot.glb, its PilotPaint.HAT
## surfaces lifted off the skinned mesh once and kept), in its paint.

const PilotPaint = preload("res://scripts/pilot_paint.gd")
const MODEL := preload("res://assets/models/pilot.glb")
## Where the hat sits on his head (m, the model's frame, art/blender/pilot/
## pilot_build.py PILOT_HAT: its brim's root, standing) and its forward tip
## there (radians), and how high it flies over his feet.
const ON_HEAD := Vector3(0.0,0.95,0.0)
const REST_HIPS_DROP := 0.029
const TIP := -0.06
const HIGH := 1.6
## Seconds out and away; the swell past its height as it opens (m).
const OPEN_TIME := 0.22
const FOLD_TIME := 0.12
const SWELL := 0.08
## Its spin (turns a second, and more in rising air), its bob (m, Hz), its
## lean into a turn (radians) and the most it wobbles (radians).
const SPIN := 2.6
const SPIN_LIFT := 1.4
const BOB := 0.025
const BOB_HZ := 1.6
const LEAN := 0.35
const WOBBLE := 0.05
## The glow rings under the brim: their radii (m), heights under the brim's
## root, thickness, how bright, and how much brighter in rising air.
const RINGS := [[0.36,-0.05],[0.27,-0.1],[0.19,-0.15]]
const RING_THICK := 0.012
const RING_ALPHA := 0.55
const RING_LIFT := 0.6

## 0 packed to 1 out (with the swell over it as it opens).
var out := 0.0
var _swell := 0.0
var _time := 0.0
var _lean := 0.0
var _turn := 0.0
var _lift := 0.0
var _spin := 0.0
var _hat: MeshInstance3D
var _rings: Array[MeshInstance3D] = []
var _ring_paint: StandardMaterial3D
static var _hat_mesh: ArrayMesh

func _init() -> void:
	name = "PocketSail"
	_hat = MeshInstance3D.new()
	_hat.name = "Cap"
	_hat.mesh = hat_mesh()
	_hat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(_hat)
	_ring_paint = StandardMaterial3D.new()
	_ring_paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_paint.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_ring_paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ring_paint.albedo_color = Color(PilotPaint.GLOW,RING_ALPHA)
	for ring: Array in RINGS:
		var torus := TorusMesh.new()
		torus.inner_radius = ring[0]-RING_THICK
		torus.outer_radius = ring[0]+RING_THICK
		torus.rings = 64
		torus.ring_segments = 8
		var m := MeshInstance3D.new()
		m.mesh = torus
		m.material_override = _ring_paint
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_hat.add_child(m)
		_rings.append(m)
	visible = false

## The hat, lifted off the model (its PilotPaint.HAT surfaces, unskinned),
## its brim's root at the origin, level, in the pilot's paint.
static func hat_mesh() -> ArrayMesh:
	if _hat_mesh != null: return _hat_mesh
	_hat_mesh = ArrayMesh.new()
	var model := MODEL.instantiate()
	var paint := PilotPaint.outfit()
	var at := Transform3D(Basis(Vector3.RIGHT,-TIP),Vector3.ZERO)*Transform3D(Basis(),-(ON_HEAD+Vector3.UP*REST_HIPS_DROP))
	for node: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var placed := Transform3D.IDENTITY
		var up: Node = node
		while up != model:
			placed = (up as Node3D).transform*placed
			up = up.get_parent()
		for i in range(node.mesh.get_surface_count()):
			var material := node.mesh.surface_get_material(i)
			var key := material.resource_name if material != null else ""
			if not key in PilotPaint.HAT: continue
			var arrays := node.mesh.surface_get_arrays(i)
			arrays[Mesh.ARRAY_BONES] = null
			arrays[Mesh.ARRAY_WEIGHTS] = null
			var to := at*placed
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for k in range(points.size()):
				points[k] = to*points[k]
				normals[k] = (to.basis*normals[k]).normalized()
			arrays[Mesh.ARRAY_VERTEX] = points
			arrays[Mesh.ARRAY_NORMAL] = normals
			arrays[Mesh.ARRAY_TANGENT] = null
			_hat_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			_hat_mesh.surface_set_material(_hat_mesh.get_surface_count()-1,paint[key])
	model.free()
	return _hat_mesh

## Packed away at once.
func reset() -> void:
	out = 0.0
	_swell = 0.0
	_lean = 0.0
	_turn = 0.0
	_lift = 0.0
	visible = false

## One frame: `open` whether it is out, `turning` -1 right to 1 left,
## `lift` 0 to 1 how hard rising air holds it up.
func update(delta: float, open: bool, turning := 0.0, lift := 0.0) -> void:
	var was := out
	out = move_toward(out,1.0 if open else 0.0,delta/(OPEN_TIME if open else FOLD_TIME))
	if open and was < 1.0 and out >= 1.0: _swell = SWELL
	_swell = move_toward(_swell,0.0,delta*0.5)
	_time += delta
	_turn = lerpf(_turn,clampf(turning,-1.0,1.0),1.0-exp(-delta/0.25))
	_lean = _turn*LEAN
	_lift = lerpf(_lift,clampf(lift,0.0,1.0),1.0-exp(-delta/0.4))
	visible = out > 0.01
	if visible: _draw(delta)

func _draw(delta: float) -> void:
	var up := smoothstep(0.0,1.0,out)
	# Off the head and up: spinning up as it goes, swelling past its height
	# and settling; a bob and a wobble as it hovers.
	var t := _time*TAU
	var height := lerpf(ON_HEAD.y,HIGH,up)+_swell+BOB*up*sin(t*BOB_HZ)
	_spin = fmod(_spin+TAU*(SPIN+SPIN_LIFT*_lift)*up*delta,TAU)
	var wobble := Basis(Vector3.RIGHT,WOBBLE*up*sin(t*0.7))*Basis(Vector3.BACK,WOBBLE*up*cos(t*0.9))
	var tip := Basis(Vector3.RIGHT,TIP*(1.0-up))
	_hat.transform = Transform3D(Basis(Vector3.FORWARD,_lean)*wobble*tip*Basis(Vector3.UP,_spin),Vector3(0.0,height,0.0))
	# The rings turn the other way (in the hat's spinning frame, back past
	# still), each breathing out and in a beat after the last, brighter in
	# rising air; they come only once it is off his head.
	var shine := smoothstep(0.35,1.0,out)
	for i in range(_rings.size()):
		var ring: MeshInstance3D = _rings[i]
		var y: float = RINGS[i][1]
		var breathe := 1.0+0.06*sin(t*2.2-i*1.3)
		ring.transform = Transform3D(Basis(Vector3.UP,-_spin*(2.0+0.5*i)).scaled(Vector3(breathe,1.0,breathe)*maxf(shine,0.01)),Vector3(0.0,y,0.0))
		ring.visible = shine > 0.01
	_ring_paint.albedo_color = Color(PilotPaint.GLOW,RING_ALPHA*shine*(1.0+RING_LIFT*_lift)*(0.85+0.15*sin(t*3.0)))
