extends Node3D
## A fire, real rather than drawn (AGENTS.md, Art direction): torches,
## braziers, bonfires, candles; set one down and it burns. Its parts:
##
## - **Flames**: one or more volumes (shaders/flame_volume.gdshader), each a
##   box the ray is marched through, a teardrop of fire torn by rising noise,
##   coloured by heat. A bonfire is several, at their own heights and seeds,
##   so its licks never move as one.
## - **Sparks**: a few at a time, hot and tiny, whirled up on the heat and
##   going out as they cool (GPUParticles3D).
## - **Smoke**: a thin grey column off the bigger fires, drifting and
##   spreading as it rises, lit by the sky like anything else.
## - **Light**: one OmniLight3D, warm, its strength and place flickering
##   with the flames (two slow noises and a quick one), stronger at night.
##
## Kinds (KINDS): torch, brazier, bonfire, candle. `kind` before it enters
## the tree; `scale_by` grows it all; `wind` leans it; `night` (0..1) lets
## the light and glow come up after dark.

const FLAME_SHADER := preload("res://shaders/flame_volume.gdshader")

## Per kind: the flames ([x, z offset, width, height, seed] in m at scale 1),
## turbulence, the light's reach and strength by day and night, sparks a
## second, smoke a second (0 none), and whether its light casts shadows.
const KINDS := {
	"candle": {"flames": [[0.0,0.0,0.035,0.11,0.3]], "turb": 0.1, "rise": 1.0,
		"light": [2.5,0.25,0.9], "sparks": 0.0, "smoke": 0.0, "shadow": false},
	"torch": {"flames": [[0.0,0.0,0.24,0.62,1.7],[0.03,-0.02,0.16,0.45,4.1]], "turb": 0.55, "rise": 1.5,
		"light": [10.0,0.6,4.0], "sparks": 3.0, "smoke": 1.5, "shadow": false},
	"brazier": {"flames": [[0.0,0.0,0.62,1.05,2.2],[0.16,0.1,0.42,0.8,5.3],[-0.14,-0.08,0.44,0.72,8.9]], "turb": 0.7, "rise": 1.3,
		"light": [14.0,0.9,5.5], "sparks": 7.0, "smoke": 3.0, "shadow": true},
	"bonfire": {"flames": [[0.0,0.0,1.25,2.3,3.3],[0.42,0.2,0.85,1.6,6.1],[-0.38,0.28,0.9,1.75,9.7],[0.1,-0.42,0.85,1.45,12.2],[-0.2,-0.15,0.7,1.9,15.4]], "turb": 0.85, "rise": 1.1,
		"light": [22.0,1.4,9.0], "sparks": 18.0, "smoke": 5.0, "shadow": true},
}
const LIGHT_COLOUR := Color(1.0,0.62,0.32)

@export var kind := "torch"
@export var scale_by := 1.0
var wind := Vector2.ZERO
var night := 0.0:
	set(v):
		night = clampf(v,0.0,1.0)

var _spec: Dictionary
var _flames: Array[GeometryInstance3D] = []
var _light: OmniLight3D
var _sparks: GPUParticles3D
var _smoke: GPUParticles3D
var _time := 0.0
var _seed := 0.0

func _ready() -> void:
	_spec = KINDS.get(kind,KINDS.torch)
	_seed = fmod(absf(global_position.x*12.9898+global_position.z*78.233),97.0)
	# A unit box with its foot at 0 (the shader's box runs y 0..1).
	var box := BoxMesh.new()
	var arrays := box.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in verts.size(): verts[i].y += 0.5
	arrays[Mesh.ARRAY_VERTEX] = verts
	var unit := ArrayMesh.new()
	unit.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var mat := ShaderMaterial.new()
	mat.shader = FLAME_SHADER
	for f: Array in _spec.flames:
		var m := MeshInstance3D.new()
		m.mesh = unit
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var w := float(f[2])*scale_by
		var h := float(f[3])*scale_by
		m.scale = Vector3(w,h,w)
		m.position = Vector3(float(f[0])*scale_by,0.0,float(f[1])*scale_by)
		m.set_instance_shader_parameter("seed",float(f[4])+_seed)
		m.set_instance_shader_parameter("turbulence",float(_spec.turb))
		m.set_instance_shader_parameter("rise",float(_spec.rise))
		add_child(m)
		_flames.append(m)
	var tallest := 0.0
	for f: Array in _spec.flames: tallest = maxf(tallest,float(f[3])*scale_by)
	_light = OmniLight3D.new()
	_light.light_color = LIGHT_COLOUR
	_light.omni_range = float(_spec.light[0])*scale_by
	_light.omni_attenuation = 1.0
	_light.shadow_enabled = bool(_spec.shadow)
	_light.position = Vector3(0.0,tallest*0.62,0.0)
	add_child(_light)
	if float(_spec.sparks) > 0.0: _sparks = _make_sparks(tallest)
	if float(_spec.smoke) > 0.0: _smoke = _make_smoke(tallest)

func _process(delta: float) -> void:
	_time += delta
	var t := _time+_seed
	# Flicker: two slow swells and a quick shiver, never below 70%.
	var f := 0.82+0.1*sin(t*2.3)*sin(t*0.71+1.3)+0.08*sin(t*11.0+sin(t*3.7)*2.0)
	var base := lerpf(float(_spec.light[1]),float(_spec.light[2]),night)
	_light.light_energy = base*f
	_light.position.x = 0.04*scale_by*sin(t*5.3)
	_light.position.z = 0.04*scale_by*sin(t*4.1+0.7)
	var lean := wind*0.6
	for m in _flames:
		m.set_instance_shader_parameter("lean",lean)
		m.set_instance_shader_parameter("intensity",lerpf(1.0,1.25,night))

## Sparks: tiny hot points, rising and whirled, cooling as they go out.
func _make_sparks(tallest: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = maxi(4,int(float(_spec.sparks)*2.5))
	p.lifetime = 2.2
	p.randomness = 0.6
	p.local_coords = false
	p.position = Vector3(0.0,tallest*0.35,0.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.22*scale_by*sqrt(tallest)
	pm.direction = Vector3.UP
	pm.spread = 18.0
	pm.initial_velocity_min = 0.8*sqrt(scale_by)
	pm.initial_velocity_max = 2.6*sqrt(scale_by)
	pm.gravity = Vector3(0.0,0.9,0.0)
	pm.damping_min = 0.4
	pm.damping_max = 1.2
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.6
	pm.turbulence_noise_scale = 1.8
	pm.turbulence_influence_min = 0.05
	pm.turbulence_influence_max = 0.2
	pm.scale_min = 0.5
	pm.scale_max = 1.3
	var ramp := Gradient.new()
	ramp.set_color(0,Color(1.0,0.82,0.45,1.0))
	ramp.set_color(1,Color(0.6,0.08,0.01,0.0))
	ramp.add_point(0.35,Color(1.0,0.45,0.1,1.0))
	var rt := GradientTexture1D.new()
	rt.gradient = ramp
	pm.color_ramp = rt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.035,0.035)*sqrt(scale_by)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = _dot_texture()
	m.albedo_color = Color(2.2,1.5,1.0)
	m.disable_receive_shadows = true
	q.material = m
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p

## Smoke: soft grey puffs off the tip, growing, drifting, thinning out.
func _make_smoke(tallest: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = maxi(6,int(float(_spec.smoke)*5.0))
	p.lifetime = 5.0
	p.local_coords = false
	p.position = Vector3(0.0,tallest*0.85,0.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.1*tallest
	pm.direction = Vector3.UP
	pm.spread = 8.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 1.1
	pm.gravity = Vector3(0.0,0.15,0.0)
	pm.damping_min = 0.1
	pm.damping_max = 0.3
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_scale = 3.0
	pm.turbulence_influence_min = 0.02
	pm.turbulence_influence_max = 0.08
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.angular_velocity_min = -12.0
	pm.angular_velocity_max = 12.0
	var grow := Curve.new()
	grow.add_point(Vector2(0.0,0.3))
	grow.add_point(Vector2(1.0,1.0))
	var gt := CurveTexture.new()
	gt.curve = grow
	pm.scale_curve = gt
	var ramp := Gradient.new()
	ramp.set_color(0,Color(0.36,0.33,0.3,0.0))
	ramp.set_color(1,Color(0.62,0.6,0.58,0.0))
	ramp.add_point(0.12,Color(0.3,0.28,0.26,0.22))
	ramp.add_point(0.5,Color(0.48,0.46,0.44,0.12))
	var rt := GradientTexture1D.new()
	rt.gradient = ramp
	pm.color_ramp = rt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2.ONE*tallest*0.7
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.albedo_texture = _puff_texture()
	m.roughness = 1.0
	m.disable_receive_shadows = true
	m.proximity_fade_enabled = true
	m.proximity_fade_distance = 0.6
	q.material = m
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p

## A spark: a hot point with a soft edge.
static var _dot: Texture2D
static func _dot_texture() -> Texture2D:
	if _dot != null: return _dot
	var size := 16
	var img := Image.create(size,size,false,Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var d := Vector2(x-size*0.5+0.5,y-size*0.5+0.5).length()/(size*0.5)
			var a := clampf(1.0-d,0.0,1.0)
			img.set_pixel(x,y,Color(1,1,1,a*a))
	_dot = ImageTexture.create_from_image(img)
	return _dot

## A soft, uneven puff: a radial falloff broken by noise.
static var _puff: Texture2D
static func _puff_texture() -> Texture2D:
	if _puff != null: return _puff
	var n := FastNoiseLite.new()
	n.frequency = 0.06
	n.fractal_octaves = 4
	var size := 64
	var img := Image.create(size,size,false,Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var d := Vector2(x-size*0.5+0.5,y-size*0.5+0.5).length()/(size*0.5)
			var a := clampf(1.0-d,0.0,1.0)
			a = a*a*(0.55+0.9*(n.get_noise_2d(x,y)*0.5+0.5))
			img.set_pixel(x,y,Color(1,1,1,clampf(a,0.0,1.0)))
	_puff = ImageTexture.create_from_image(img)
	return _puff
