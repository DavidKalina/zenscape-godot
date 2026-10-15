extends MultiMeshInstance3D
## [linger] The colossus's cloud bank (scripts/roguelike/linger_colossus.gd):
## a broad bank of soft painted puffs (shaders/linger_cloud.gdshader) laid
## round where he stands in the void, at the deck he rises through. Before
## he comes it is only a far cloud bank; it heaves when he does (`heave`),
## and when he draws breath its puffs stream in over his shoulders to his
## mouth (`draw`), the tell read from any isle.
##   setup(middle, deck_y, size, tint_light, tint_shade, seed, front)
##   step(delta, mouth, share)   share 0 none .. 1 full draw

const SHADER := preload("res://shaders/linger_cloud.gdshader")
## Puffs in the bank, the inner share of them close round his body.
const PUFFS := 150
const INNER := 0.4
## The bank's reach and the puffs' sizes, in his head heights.
const REACH := 3.4
const NEAR := 0.75
const SIZE_MIN := 0.8
const SIZE_MAX := 1.8
## How fast a drawn puff goes to his mouth (shares of its way a second at
## a full draw), and how fast a left one drifts home.
const DRAWN := 0.22
const HOME := 0.03

var middle := Vector3.ZERO
var deck_y := 0.0
var size := 100.0
var _puffs: Array = []
var _rng := RandomNumberGenerator.new()
var _mat := ShaderMaterial.new()
var _clock := 0.0
var _heave := 0.0

func setup(at: Vector3, deck: float, head: float, light: Color, shade: Color, seed_value := 1, front := Vector3.FORWARD) -> void:
	middle = at
	deck_y = deck
	size = head
	_rng.seed = seed_value
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mat.shader = SHADER
	_mat.set_shader_parameter("light_col",light)
	_mat.set_shader_parameter("shade_col",shade)
	_mat.set_shader_parameter("soft_fade",head*0.07)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = _mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = PUFFS
	multimesh = mm
	custom_aabb = AABB(Vector3(-REACH*2.0,-2.0,-REACH*2.0)*head,Vector3(REACH*4.0,6.0,REACH*4.0)*head)
	for i in range(PUFFS):
		var inner := i < int(PUFFS*INNER)
		# The inner ones mostly in front of him (toward `front`), round his
		# shoulders, so he stands down in the bank from where he is seen.
		var a := _rng.randf()*TAU
		if inner: a = atan2(front.z,front.x)+_rng.randf_range(-1.0,1.0)*_rng.randf_range(0.4,PI)
		var r := (_rng.randf_range(0.45,1.5) if inner else lerpf(NEAR+0.4,REACH,sqrt(_rng.randf())))*head
		var home := Vector3(cos(a)*r,(_rng.randf_range(-0.2,0.3) if inner else _rng.randf_range(-0.35,0.1))*head,sin(a)*r)
		var s := _rng.randf_range(SIZE_MIN,SIZE_MAX)*head*(0.9 if inner else 1.0)
		_puffs.append({"home":home,"u":0.0,"s":s,"seed":_rng.randf(),"phase":_rng.randf()*10.0,
			"tone":_rng.randf(),"born":1.0,"flat":_rng.randf_range(0.45,0.7)})
	position = Vector3(middle.x,deck_y,middle.z)
	_write(Vector3.ZERO,0.0)

## The bank heaves as he surges up through it (0..1, eased away).
func heave(amount: float) -> void:
	_heave = maxf(_heave,amount)

func step(delta: float, mouth: Vector3, share: float) -> void:
	_clock += delta
	_heave = move_toward(_heave,0.0,delta*0.35)
	_mat.set_shader_parameter("clock",_clock)
	var local_mouth := mouth-position
	for p: Dictionary in _puffs:
		p.born = minf(float(p.born)+delta*0.4,1.0)
		if share > 0.02:
			# Nearer ones go first, and quicker.
			var home: Vector3 = p.home
			var near := clampf(1.0-Vector2(home.x,home.z).length()/(REACH*size),0.15,1.0)
			p.u = float(p.u)+delta*DRAWN*share*lerpf(0.5,1.5,near)
			if float(p.u) >= 1.0:
				p.u = 0.0
				p.born = 0.0
		else:
			p.u = maxf(float(p.u)-delta*HOME,0.0)
	_write(local_mouth,share)

func _write(local_mouth: Vector3, _share: float) -> void:
	var mm := multimesh
	for i in range(_puffs.size()):
		var p: Dictionary = _puffs[i]
		var home: Vector3 = p.home
		var u: float = p.u
		# Drawn in: up over the shoulders and in to the mouth, along a curve.
		var e := u*u*(3.0-2.0*u)
		var at := home.lerp(local_mouth,e)
		at.y += sin(e*PI)*size*0.35
		# The heave: the bank pushed out and up round him.
		var flat := Vector2(home.x,home.z)
		var out := flat.normalized()*_heave*size*0.25*clampf(1.0-flat.length()/(REACH*size),0.0,1.0) if flat.length() > 0.1 else Vector2.ZERO
		at += Vector3(out.x,_heave*size*0.12,out.y)
		at.y += sin(_clock*0.2+float(p.phase))*size*0.02
		var s: float = float(p.s)*lerpf(1.0,0.35,e)
		var xf := Transform3D(Basis.from_scale(Vector3(s,s*float(p.flat),1.0)),at)
		mm.set_instance_transform(i,xf)
		var alpha := smoothstep(0.0,1.0,float(p.born))*(1.0-smoothstep(0.75,1.0,u))
		mm.set_instance_custom_data(i,Color(float(p.seed),alpha,float(p.phase),float(p.tone)))
