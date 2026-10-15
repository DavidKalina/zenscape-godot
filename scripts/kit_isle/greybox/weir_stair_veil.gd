extends RefCounted
## The Weir Stair's spills (scripts/kit_isle/greybox/gb_weir_stair.gd): a
## sheet of water falling off a lip in its arc, painted white streaks
## running down it, and a mist where it lands. Drawn only (the surge's
## carry and fling are the sluice trap's). Motif-local; a stand-in for the
## card's `city_weir` spill face.
##
## `fall(parent, lip, out, wide, height, pace, seed)`: the sheet `wide` m
## across, leaving the lip's middle `lip` along `out` (level) at `pace` m/s,
## falling `height` m; a mist puffing where it lands. `warm` makes the
## materials (main thread).

const SHADER := """
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, specular_schlick_ggx;
uniform vec4 tint : source_color = vec4(0.82, 0.86, 0.86, 1.0);
uniform float speed = 3.2;
uniform float glow = 0.5;
uniform float body = 0.95;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
void fragment() {
	// UV.x across (0..1), UV.y metres fallen, UV2.x the share of the fall.
	float a = vnoise(vec2(UV.x * 18.0, UV.y * 0.7 - TIME * speed * 0.45));
	float b = vnoise(vec2(UV.x * 41.0 + 3.0, UV.y * 1.6 - TIME * speed));
	float streak = a * 0.6 + b * 0.4;
	float edge = smoothstep(0.0, 0.14, UV.x) * smoothstep(1.0, 0.86, UV.x);
	float ragged = smoothstep(0.25, 0.55, vnoise(vec2(UV.x * 9.0, UV.y * 0.4 - TIME * speed * 0.3)) + edge * 0.6);
	float foot = 1.0 - smoothstep(0.86, 1.0, UV2.x);
	float lip = 1.0 - smoothstep(0.0, 0.12, UV2.x);
	ALBEDO = tint.rgb * (0.9 + 0.25 * streak + 0.2 * lip);
	ALPHA = clamp(((body * 0.5 + streak * 0.8) * ragged + lip * 0.5 * edge) * foot, 0.0, 0.97);
	EMISSION = tint.rgb * glow * (0.6 + 0.6 * streak + lip);
	ROUGHNESS = 0.25;
}
"""

static var _sheet: ShaderMaterial = null
static var _mist: StandardMaterial3D = null
static var _spray: StandardMaterial3D = null
## Polish: how far (m) the mist and spray are drawn.
const MIST_RANGE := 150.0
## Set by the motif before it builds (false: the round-3 mist).
static var polish := true

static func warm() -> void:
	if _sheet == null:
		var s := Shader.new()
		s.code = SHADER
		_sheet = ShaderMaterial.new()
		_sheet.shader = s
	if _mist == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0,1.0])
		g.colors = PackedColorArray([Color(0.9,0.93,0.95,0.5 if polish else 0.3),Color(0.9,0.93,0.95,0.0)])
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5,0.5)
		tex.fill_to = Vector2(1.0,0.5)
		tex.width = 64
		tex.height = 64
		_mist = StandardMaterial3D.new()
		_mist.albedo_texture = tex
		_mist.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mist.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_mist.vertex_color_use_as_albedo = true
		_mist.emission_enabled = true
		_mist.emission = Color(0.5,0.52,0.54)
		_mist.emission_energy_multiplier = 0.25 if not polish else 0.6
		_mist.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	if _spray == null:
		var g2 := Gradient.new()
		g2.offsets = PackedFloat32Array([0.0,0.5,1.0])
		g2.colors = PackedColorArray([Color(1.0,1.0,1.0,0.95),Color(0.95,0.97,1.0,0.5),Color(0.9,0.94,1.0,0.0)])
		var t2 := GradientTexture2D.new()
		t2.gradient = g2
		t2.fill = GradientTexture2D.FILL_RADIAL
		t2.fill_from = Vector2(0.5,0.5)
		t2.fill_to = Vector2(1.0,0.5)
		t2.width = 32
		t2.height = 32
		_spray = StandardMaterial3D.new()
		_spray.albedo_texture = t2
		_spray.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_spray.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_spray.vertex_color_use_as_albedo = true
		_spray.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

## A cloud of mist at `at`: `scale` the share of the base puff.
static func _mist_at(parent: Node3D, at: Vector3, o: Vector3, wide: float, scale: float, node_name: String) -> void:
	var mist := CPUParticles3D.new()
	mist.name = node_name
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE*3.8
	quad.material = _mist
	mist.mesh = quad
	mist.amount = int(clampf(wide*2.2,30.0,90.0))
	mist.lifetime = 3.2
	mist.preprocess = 3.2
	mist.local_coords = false
	mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	mist.emission_box_extents = Vector3(wide*0.5,0.3,0.9)*scale
	mist.direction = Vector3(o.x,1.0,o.z)
	mist.spread = 50.0
	mist.initial_velocity_min = 0.5
	mist.initial_velocity_max = 1.8
	mist.gravity = Vector3(0.0,0.3,0.0)
	mist.scale_amount_min = 0.8*scale
	mist.scale_amount_max = 1.9*scale
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0,0.25,1.0])
	fade.colors = PackedColorArray([Color(1.0,1.0,1.0,0.0),Color(1.0,1.0,1.0,0.55),Color(1.0,1.0,1.0,0.0)])
	mist.color_ramp = fade
	mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mist.visibility_range_end = MIST_RANGE
	mist.position = at
	parent.add_child(mist)

## Fine spray thrown up and out where the water strikes (or breaks).
static func _spray_at(parent: Node3D, at: Vector3, o: Vector3, wide: float, scale: float) -> void:
	var sp := CPUParticles3D.new()
	sp.name = "Spray"
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE*0.42
	quad.material = _spray
	sp.mesh = quad
	sp.amount = 18
	sp.lifetime = 1.1
	sp.preprocess = 1.1
	sp.local_coords = false
	sp.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	sp.emission_box_extents = Vector3(wide*0.5,0.1,0.4)
	sp.direction = Vector3(o.x*0.5,1.0,o.z*0.5)
	sp.spread = 35.0
	sp.initial_velocity_min = 1.5*scale
	sp.initial_velocity_max = 4.0*scale
	sp.gravity = Vector3(0.0,-7.0,0.0)
	sp.scale_amount_min = 0.5
	sp.scale_amount_max = 1.3
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0,0.2,1.0])
	fade.colors = PackedColorArray([Color(1.0,1.0,1.0,0.0),Color(1.0,1.0,1.0,0.9),Color(1.0,1.0,1.0,0.0)])
	sp.color_ramp = fade
	sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sp.visibility_range_end = MIST_RANGE
	sp.position = at
	parent.add_child(sp)

## Rows down the sheet.
const ROWS := 14
## Gravity for the arc (m/s²).
const G := 9.8

static func fall(parent: Node3D, lip: Vector3, out: Vector3, wide: float, height: float, pace: float, seed_value: int) -> MeshInstance3D:
	warm()
	var o := Vector3(out.x,0.0,out.z).normalized()
	var across := Vector3.UP.cross(o).normalized()
	var t_end := sqrt(2.0*height/G)
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var cols := maxi(int(ceil(wide/1.0)),2)
	for r in range(ROWS+1):
		var s := float(r)/ROWS
		var t := t_end*s
		var drop := 0.5*G*t*t
		# The sheet narrows a little as it falls, and frays wider at its foot.
		var w := wide*(1.0-0.12*s+0.25*s*s*s)
		for c in range(cols+1):
			var u := float(c)/cols
			var wob := 0.12*sin(u*9.0+float(seed_value))*s
			var p := lip+o*(pace*t+wob)+across*(u-0.5)*w+Vector3.DOWN*drop
			v.append(p)
			var tangent := (o*pace+Vector3.DOWN*G*t).normalized()
			n.append(across.cross(tangent).normalized())
			uv.append(Vector2(u,drop))
			uv2.append(Vector2(s,0.0))
	for r in range(ROWS):
		for c in range(cols):
			var a := r*(cols+1)+c
			var b := a+1
			var d := a+cols+1
			var e := d+1
			idx.append_array([a,d,b,b,d,e])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var sheet := MeshInstance3D.new()
	sheet.name = "Veil"
	sheet.mesh = mesh
	sheet.material_override = _sheet
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sheet.set_meta("triangles",idx.size()/3)
	parent.add_child(sheet)
	var foot := lip+o*(pace*t_end)+Vector3.DOWN*height
	if not polish:
		# The round-3 mist: one puff where it lands.
		var mist := CPUParticles3D.new()
		mist.name = "Mist"
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE*2.8
		quad.material = _mist
		mist.mesh = quad
		mist.amount = 16
		mist.lifetime = 2.6
		mist.preprocess = 2.6
		mist.local_coords = false
		mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		mist.emission_box_extents = Vector3(wide*0.5,0.2,0.8)
		mist.direction = Vector3(o.x,1.0,o.z)
		mist.spread = 40.0
		mist.initial_velocity_min = 0.6
		mist.initial_velocity_max = 1.6
		mist.gravity = Vector3(0.0,0.25,0.0)
		mist.scale_amount_min = 0.7
		mist.scale_amount_max = 1.6
		var fade := Gradient.new()
		fade.offsets = PackedFloat32Array([0.0,0.25,1.0])
		fade.colors = PackedColorArray([Color(1.0,1.0,1.0,0.0),Color(1.0,1.0,1.0,0.7),Color(1.0,1.0,1.0,0.0)])
		mist.color_ramp = fade
		mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mist.position = foot
		parent.add_child(mist)
		return sheet
	# The mist where it lands, and the spray thrown off it.
	_mist_at(parent,foot,o,wide,1.0+clampf(height/14.0,0.0,1.5),"Mist")
	_spray_at(parent,foot+Vector3.UP*0.1,o,wide,1.0)
	# A long fall breaks up on the way: plumes of mist down it, wider as it goes.
	if height > 18.0:
		for frac: float in [0.35,0.65]:
			var tt := t_end*sqrt(frac)
			var at := lip+o*(pace*tt)+Vector3.DOWN*height*frac
			_mist_at(parent,at,o,wide*0.8,2.2,"Plume%d" % int(frac*100.0))
			_spray_at(parent,at,o,wide*0.6,1.6)
	return sheet

## Moss beards: ragged dark strands hanging off a wall's face, each
## [top (on the face), its way out of the face, length, width]; one mesh.
static var _moss: StandardMaterial3D = null

static func beards(parent: Node3D, strands: Array, seed_value: int) -> MeshInstance3D:
	if _moss == null:
		_moss = StandardMaterial3D.new()
		_moss.albedo_color = Color(0.17,0.2,0.11)
		_moss.roughness = 1.0
		_moss.cull_mode = BaseMaterial3D.CULL_DISABLED
		_moss.vertex_color_use_as_albedo = true
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var col := PackedColorArray()
	for s: Array in strands:
		var top: Vector3 = s[0]
		var out: Vector3 = (s[1] as Vector3).normalized()
		var length := float(s[2])
		var wide := float(s[3])
		var across := Vector3.UP.cross(out).normalized()
		# A strip of 4 rows narrowing to a ragged point, a hand off the face.
		var rows := 4
		var prev_l := top+out*0.04-across*wide*0.5
		var prev_r := top+out*0.04+across*wide*0.5
		for r in range(1,rows+1):
			var t := float(r)/rows
			var w := wide*(1.0-t)*(0.7+0.5*rng.randf())
			var c := top+out*(0.04+0.08*t)+Vector3.DOWN*length*t+across*rng.randf_range(-0.1,0.1)
			var l := c-across*w*0.5
			var rr := c+across*w*0.5
			var shade := Color(1.0,1.0,1.0).darkened(0.25*t+rng.randf()*0.15)
			for q: Vector3 in [prev_l,l,prev_r,prev_r,l,rr]:
				v.append(q)
				n.append(out)
				col.append(shade)
			prev_l = l
			prev_r = rr
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_COLOR] = col
	var mesh := ArrayMesh.new()
	if not v.is_empty(): mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var m := MeshInstance3D.new()
	m.name = "MossBeards"
	m.mesh = mesh
	m.material_override = _moss
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.set_meta("triangles",v.size()/3)
	parent.add_child(m)
	return m
