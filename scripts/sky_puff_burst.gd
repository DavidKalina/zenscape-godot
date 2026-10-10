extends MultiMeshInstance3D
## Short-lived puffs of the game's own cloud (shaders/sky_cloud_puff.gdshader,
## the glide's drifting clouds and the cloud round a sky peak's foot): soft,
## facing the eye, lit by the sky's cloud light, softened where they meet
## stone. For things breaking up out of the cloud sea (docs/design/
## isle-hall-chain.md): the hall rise's bursts, streams and caps (scripts/
## hall_rise.gd, given this as its `burst`) and the isle's ring. Each puff
## flies on its velocity (damped), swells by `grow` over its life and fades
## in and out (its instance colour's alpha). World coordinates; the node
## stands at the origin. At most COUNT at once.

const COUNT := 1200
## How fast a puff's velocity dies away (1/s), as the hall rise's.
const DAMP := 1.4
## Within this many metres of the stone behind, a puff thins away.
const SOFT_DEPTH := 6.0

## The cloud top the puffs are lit from (world y): puffs under it read as
## the sea's shaded side, over it as sunlit tops.
var base_y := 0.0
var _p := PackedVector3Array()
var _v := PackedVector3Array()
var _s := PackedFloat32Array()
var _g := PackedFloat32Array()
var _a := PackedFloat32Array()
var _l := PackedFloat32Array()
var _side := PackedVector3Array()
var _seed := PackedFloat32Array()
var _rng := RandomNumberGenerator.new()
var material := ShaderMaterial.new()

func _init() -> void:
	name = "SkyPuffBurst"
	_rng.seed = 41
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = COUNT
	mm.visible_instance_count = 0
	multimesh = mm
	material.shader = preload("res://shaders/sky_cloud_puff.gdshader")
	material.set_shader_parameter("drift",Vector2.ZERO)
	material.set_shader_parameter("field",Vector4(-1e6,-1e6,2e6,2e6))
	material.set_shader_parameter("soft_depth",SOFT_DEPTH)
	material.set_shader_parameter("instance_fade",true)
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	set_meta("skip_reflection",true)
	# Placed by hand wherever the bursts are; never culled by its own box.
	custom_aabb = AABB(Vector3.ONE*-1e5,Vector3.ONE*2e5)

## How many puffs are up now.
func count() -> int:
	return _p.size()

## A puff at `at` (world), flying `vel`, `size` m across to begin with,
## swelling by `grow` of that over `life` s.
func puff(at: Vector3, vel: Vector3, size: float, grow: float, life: float) -> void:
	if _p.size() >= COUNT: return
	_p.append(at); _v.append(vel); _s.append(size); _g.append(grow); _a.append(0.0); _l.append(maxf(life,0.05))
	var flat := Vector3(vel.x,0.0,vel.z)
	var side := flat.normalized()*0.4 if flat.length() > 0.01 else Vector3(_rng.randf_range(-0.3,0.3),0.0,_rng.randf_range(-0.3,0.3))
	_side.append(side)
	_seed.append(_rng.randf())

func clear() -> void:
	_p.clear(); _v.clear(); _s.clear(); _g.clear(); _a.clear(); _l.clear(); _side.clear(); _seed.clear()
	multimesh.visible_instance_count = 0

## One frame: every puff moved, aged, swollen and faded; the spent ones gone.
func step(delta: float) -> void:
	var k := 0
	var damp := exp(-DAMP*delta)
	while k < _p.size():
		_a[k] += delta
		if _a[k] >= _l[k]:
			var last := _p.size()-1
			_p[k] = _p[last]; _v[k] = _v[last]; _s[k] = _s[last]; _g[k] = _g[last]; _a[k] = _a[last]; _l[k] = _l[last]; _side[k] = _side[last]; _seed[k] = _seed[last]
			_p.resize(last); _v.resize(last); _s.resize(last); _g.resize(last); _a.resize(last); _l.resize(last); _side.resize(last); _seed.resize(last)
			continue
		_p[k] += _v[k]*delta
		_v[k] *= damp
		k += 1
	var mm := multimesh
	mm.visible_instance_count = _p.size()
	for i in range(_p.size()):
		var u := _a[i]/_l[i]
		# The shader's puff is a card twice its radius across: radius is half
		# the size asked.
		var radius := _s[i]*0.5*(1.0+_g[i]*sqrt(u))
		mm.set_instance_transform(i,Transform3D(Basis(Vector3.RIGHT*radius,Vector3.UP,Vector3.BACK),_p[i]))
		var high := clampf((_p[i].y-base_y)/18.0,-0.35,0.6)
		mm.set_instance_custom_data(i,Color(_side[i].x,high,_side[i].z,_seed[i]))
		mm.set_instance_color(i,Color(1,1,1,smoothstep(0.0,0.15,u)*(1.0-smoothstep(0.45,1.0,u))))
