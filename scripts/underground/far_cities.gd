extends Node3D
## Far cities in the abyss (docs/design/roguelike/underground-oculus-round2.md):
## other Olmec cities hanging in the void round the layer, far off and far
## down, small lit clusters of stepped towers that go to haze with distance
## and show their windows as warm speckles. Some hang the right way up, some
## upside down from nothing, some on their side (Escher's stair, Piranesi's
## vaults): the abyss is not the layer's own gravity.
##
## One MultiMesh of one low-poly mesh (about 170 triangles), one draw call;
## the shader (shaders/oculus_far_city.gdshader) hazes them itself and lays
## the window lights after the haze.
const SHADER = preload("res://shaders/oculus_far_city.gdshader")
const COUNT := 40
## Distance from the layer's middle (m).
const NEAR := 1500.0
const FAR := 3700.0

var _mm: MultiMeshInstance3D
var _material: ShaderMaterial

static func make_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := 1.0
	# The keel: an inverted, jagged cone of rock under a flat deck (unit radius).
	var n := 9
	var apex := Vector3(0.1,-1.5,0.05)
	var top: Array[Vector3] = []
	var mid: Array[Vector3] = []
	for i in n:
		var a := float(i)/n*TAU
		var j := 0.7+0.55*fposmod(sin(float(i)*12.9898)*43758.5453,1.0)
		top.append(Vector3(cos(a)*r*j,0.0,sin(a)*r*j))
		mid.append(Vector3(cos(a+0.2)*r*0.55*j,-0.6-0.25*fposmod(sin(float(i)*78.233)*43758.5453,1.0),sin(a+0.2)*r*0.55*j))
	for i in n:
		var k := (i+1)%n
		_tri(st,top[i],mid[i],top[k],Color(0.55,0.55,0.6,0.0))
		_tri(st,top[k],mid[i],mid[k],Color(0.5,0.5,0.56,0.0))
		_tri(st,mid[i],apex,mid[k],Color(0.42,0.42,0.5,0.0))
		_tri(st,Vector3(0,0,0),top[k],top[i],Color(0.7,0.7,0.7,0.0))
	# The city: stepped tiers and towers on the deck, windows flagged by alpha.
	var tiers := [
		[Vector3(0,0,0),Vector3(0.62,0.22,0.58)],
		[Vector3(0.05,0.22,0.0),Vector3(0.42,0.22,0.4)],
		[Vector3(0.0,0.44,0.03),Vector3(0.26,0.2,0.24)],
		[Vector3(-0.55,0.0,0.15),Vector3(0.16,0.34,0.16)],
		[Vector3(0.58,0.0,-0.2),Vector3(0.14,0.28,0.14)],
		[Vector3(0.1,0.0,0.6),Vector3(0.12,0.4,0.12)],
		[Vector3(-0.2,0.0,-0.62),Vector3(0.18,0.26,0.16)],
		[Vector3(0.02,0.64,0.0),Vector3(0.09,0.5,0.09)],
	]
	for t: Array in tiers:
		_box(st,t[0],t[1])
	st.generate_normals()
	return st.commit()

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	for v: Vector3 in [a,b,c]:
		st.set_color(col)
		st.add_vertex(v)

static func _box(st: SurfaceTool, base: Vector3, half: Vector3) -> void:
	# A box standing on `base` (its floor's middle), `half` its half extents in x and z, its height y.
	var lo := base+Vector3(-half.x,0.0,-half.z)
	var hi := base+Vector3(half.x,half.y*2.0,half.z)
	var p := [Vector3(lo.x,lo.y,lo.z),Vector3(hi.x,lo.y,lo.z),Vector3(hi.x,lo.y,hi.z),Vector3(lo.x,lo.y,hi.z),
		Vector3(lo.x,hi.y,lo.z),Vector3(hi.x,hi.y,lo.z),Vector3(hi.x,hi.y,hi.z),Vector3(lo.x,hi.y,hi.z)]
	var sides := [[0,1,5,4],[1,2,6,5],[2,3,7,6],[3,0,4,7]]
	var wall := Color(0.62,0.62,0.66,1.0)
	for s: Array in sides:
		_tri(st,p[s[0]],p[s[2]],p[s[1]],wall)
		_tri(st,p[s[0]],p[s[3]],p[s[2]],wall)
	var roof := Color(0.8,0.8,0.8,0.0)
	_tri(st,p[4],p[5],p[6],roof)
	_tri(st,p[4],p[6],p[7],roof)

## Lays the cities round `middle`, the sea's surface `sea_y` and the layer's
## top `ceiling_y` bounding their heights, by `seed_value`.
func build(middle: Vector3, sea_y: float, floor_y: float, seed_value: int) -> void:
	clear()
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = make_mesh()
	mm.instance_count = COUNT
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value*977+13
	for i in COUNT:
		var a := (float(i)+rng.randf_range(0.0,0.8))/COUNT*TAU
		var dist := lerpf(NEAR,FAR,pow(rng.randf(),0.8))
		var y := rng.randf_range(sea_y+60.0,floor_y+200.0)
		var size := rng.randf_range(40.0,115.0)*lerpf(0.9,1.5,dist/FAR)
		var roll := rng.randf()
		var b := Basis(Vector3.UP,rng.randf()*TAU)
		if roll > 0.88: b = Basis(Vector3.RIGHT,PI)*b                     # hanging from nothing
		elif roll > 0.76: b = Basis(Vector3(cos(a),0.0,sin(a)),PI*0.5)*b   # on its side
		b = b.scaled(Vector3.ONE*size)
		mm.set_instance_transform(i,Transform3D(b,middle+Vector3(cos(a)*dist,y-middle.y,sin(a)*dist)))
		mm.set_instance_custom_data(i,Color(rng.randf(),rng.randf_range(0.25,0.75),0.0,0.0))
	_mm = MultiMeshInstance3D.new()
	_mm.name = "FarCities"
	_mm.multimesh = mm
	_mm.material_override = _material
	_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mm.extra_cull_margin = 5000.0
	add_child(_mm)

func set_light(key: Vector3) -> void:
	if _material != null: _material.set_shader_parameter("light_dir",key)

func clear() -> void:
	if is_instance_valid(_mm):
		_mm.queue_free()
	_mm = null

## The haze the cities go into, and how bright their windows burn.
func set_look(haze: Color, glow: float, reach: float) -> void:
	if _material == null: return
	_material.set_shader_parameter("haze",haze)
	_material.set_shader_parameter("glow",glow)
	_material.set_shader_parameter("reach",reach)
