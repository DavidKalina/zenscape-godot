extends MeshInstance3D
## The stomper's shadow past the reach of the sun's own (EndlessLook SHADOW_REACH):
## without it a body 250 m tall floats over the land from the way out of the hall.
## One box down the sun from the body (shaders/stomper_shadow.gdshader), its shape
## read off the capsules the flight meets (stomper_solid.gd), so the limbs swing
## in it and it lies right on the ground. Near the eye the sun's own takes over.
## `--no-stomper-shadow` leaves it out.

const LaunchArgs = preload("res://scripts/launch_args.gd")
const SHADER = preload("res://shaders/stomper_shadow.gdshader")

## The most a capsule the shader reads (its arrays) and a shadow's length (m), the
## room round the body, and the box's height (m). Under SUN_LOW there is none.
const CAPSULES := 17
const LONGEST := 1800.0
const ROOM := 200.0
const UP := 900.0
const SUN_LOW := 0.08

var _body: Node3D
var _sun_of: RefCounted
var _mat: ShaderMaterial
## Another material that reads the same table (the dust, to darken in the shade).
var _also: ShaderMaterial
var _seg := PackedVector4Array()
var _cap := PackedVector2Array()

static func wanted() -> bool:
	return not "--no-stomper-shadow" in LaunchArgs.user_args()

func setup(study: Node, stomper: Node3D) -> void:
	name = "StomperShadow"
	top_level = true
	_body = stomper
	_sun_of = study.look.celestial
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	var fog: Environment = study.look.environment
	_mat.set_shader_parameter("haze",Vector3(fog.fog_depth_begin,fog.fog_depth_end,fog.fog_depth_curve))
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	box.material = _mat
	mesh = box
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_seg.resize(CAPSULES)
	_cap.resize(CAPSULES)
	step()

func also(material: ShaderMaterial) -> void:
	_also = material

func step() -> void:
	var sun: Vector3 = _sun_of.state.zs_sun_direction
	visible = sun.y > SUN_LOW
	if not visible: return
	var solid: RefCounted = _body.solid
	var at: Vector3 = _body.position
	var across := Vector3.UP.cross(sun).normalized()
	var over := sun.cross(across)
	for i in range(mini(solid.count,CAPSULES)):
		var a: Vector3 = solid.a[i]-at
		var b: Vector3 = solid.b[i]-at
		_seg[i] = Vector4(a.dot(across),a.dot(over),b.dot(across),b.dot(over))
		_cap[i] = Vector2(solid.radius[i],(a+b).dot(sun)*0.5+solid.radius[i])
	for m: ShaderMaterial in ([_mat] if _also == null else [_mat,_also]):
		m.set_shader_parameter("seg",_seg)
		m.set_shader_parameter("cap",_cap)
		m.set_shader_parameter("at",at)
		m.set_shader_parameter("sun",sun)
		m.set_shader_parameter("across",across)
		m.set_shader_parameter("over",over)
	# Down the sun off the body, as long as the top of it throws.
	var flat := Vector3(sun.x,0.0,sun.z)
	var away := -flat.normalized()
	var long := minf(_body.HEIGHT*flat.length()/sun.y,LONGEST)
	var b := Basis(Vector3.UP,atan2(-away.x,-away.z)).scaled_local(Vector3(ROOM*2.0+160.0,UP,long+ROOM*2.0))
	global_transform = Transform3D(b,at+away*long*0.5)
