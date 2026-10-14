extends Node3D
## The underground look (docs/design/roguelike/underground-look-round1.md):
## `--underground[=torch|haze]`, a kit-isle study (studies/kit_isle.gd, so the motif yard
## and, later, run_layer) in an abyss instead of the sky. Everything is
## behind the flag; without it nothing here runs.
##
##   the abyss      a dark gradient sky with one faint far light straight up
##                  (the surface; shaders/abyss_sky.gdshader) and a huge
##                  enclosing shaft of rock round the place, backdrop only,
##                  no collision (shaders/abyss_rock.gdshader)
##   the murk       low cool ambient, a dim cool "moon" from above for the
##                  ruins' silhouettes, depth fog and a thin volumetric fog
##                  that the torch scatters in
##   the torch      a warm flickering light riding the wanderer (and a small
##                  flame prop), the only warm thing in the dark
##   the eyes       the Olmec's eyes glow (scripts/enemies/inhaler_head_look.gd
##                  `glow`, `Underground.on()`), so he is seen before his body
## The study's day, sun, stars, planet, clouds and air are held off here,
## every frame after theirs (process priority), so the weather and the hour
## can still run underneath without showing.
##
## Two presets (PRESETS), L (the look key) flips them live:
##   torch  the dark one: a cool shaft of rock, the wanderer's torch the
##          only warm light, the far light above, volumetric murk
##   haze   not cramped: a thick dim umber-grey haze lights everything, the
##          wall dissolved in it, stepped-pyramid isles on rock pillars
##          fading in it at many distances (cheap backdrop silhouettes, no
##          collision, not a kit); the torch only a glow; eyes still burn
##
## Knobs (KNOBS, the torch preset's; the haze preset's are in PRESETS; `--underground-<name>=<value>` overrides one):
##   fog          depth-fog density (per m)
##   volume       volumetric fog density (the torch's scatter), 0 off
##   ambient      the ambient light's energy
##   moon         the cool light from above, energy
##   exposure     tonemap exposure
##   torch        the torch light's energy
##   torch_range  its range (m)
##   wall         the rock shaft's radius (m)
const ROCK_SHADER = preload("res://shaders/abyss_rock.gdshader")
const SKY_SHADER = preload("res://shaders/abyss_sky.gdshader")
const FLAG := "--underground"
const DEFAULT_PRESET := "torch"

## Each preset's overrides of KNOBS and its colours.
const PRESETS := {
	"torch":{"title":"Underground: torch","far":true,"fog_sky":0.0,"wall_scale":5.5,
		"murk":Color(0.085,0.115,0.17),"ambient":Color(0.16,0.22,0.34),"moon":Color(0.5,0.62,0.85),
		"vol_albedo":Color(0.45,0.55,0.72),"wall_density":0.0026,"surface":0.55,
		"rock_dark":Color(0.05,0.065,0.09),"rock_light":Color(0.26,0.30,0.37),"warm":Color(0.16,0.12,0.10),
		"sky_low":Color(0.02,0.03,0.05),"sky_horizon":Color(0.09,0.12,0.18),"sky_high":Color(0.035,0.055,0.1)},
	"haze":{"title":"Underground: haze","far":true,"fog_sky":1.0,"wall_scale":6.0,
		"murk":Color(0.30,0.245,0.185),"ambient":Color(0.52,0.43,0.34),"moon":Color(0.95,0.78,0.55),
		"vol_albedo":Color(0.6,0.5,0.38),"wall_density":0.010,"surface":0.0,
		"rock_dark":Color(0.14,0.11,0.09),"rock_light":Color(0.32,0.26,0.2),"warm":Color(0.3,0.2,0.12),
		"sky_low":Color(0.18,0.145,0.11),"sky_horizon":Color(0.30,0.245,0.185),"sky_high":Color(0.22,0.18,0.14),
		"knobs":{"fog":0.0016,"volume":0.0,"ambient":1.1,"moon":0.5,"exposure":1.05,"torch":2.2,"torch_range":16.0}},
}
const KNOBS := {
	"fog":0.0032,"volume":0.012,"ambient":1.3,"moon":0.55,"exposure":1.3,
	"torch":5.5,"torch_range":24.0,"wall":300.0,
}
## The fog and the ambient's colours: cool, a little lighter than the rock.
const MURK := Color(0.085,0.115,0.17)
const AMBIENT := Color(0.16,0.22,0.34)
const MOON := Color(0.5,0.62,0.85)
const FLAME := Color(1.0,0.58,0.22)

var study: Node3D
var knobs: Dictionary = KNOBS.duplicate()
var preset := DEFAULT_PRESET
var p: Dictionary = {}
var far: Node3D
var _asked := {}
var _wall_mat: ShaderMaterial
var center := Vector3.ZERO
var wall: MeshInstance3D
var moon: DirectionalLight3D
var torch: Node3D
var torch_light: OmniLight3D
var flame: MeshInstance3D
var _env: Environment
var _sky_material: ShaderMaterial
var _clock := 0.0
var _noise := FastNoiseLite.new()

## True when the launch flags ask for the underground look.
static func on() -> bool:
	for a: String in preload("res://scripts/launch_args.gd").user_args():
		if a == FLAG or a.begins_with(FLAG+"="): return true
	return false

## The preset the flags ask: --underground=haze, else the torch's.
static func asked() -> String:
	for a: String in preload("res://scripts/launch_args.gd").user_args():
		if a.begins_with(FLAG+"="):
			var k := a.get_slice("=",1)
			if PRESETS.has(k): return k
	return DEFAULT_PRESET

## The look stood on `study_node` (a kit isle) if the flags ask; null otherwise.
static func attach(study_node: Node3D) -> Node3D:
	if not on(): return null
	var u: Node3D = (preload("res://scripts/underground/underground.gd") as GDScript).new()
	u.name = "Underground"
	study_node.add_child(u)
	u.setup(study_node)
	return u

func setup(study_node: Node3D) -> void:
	study = study_node
	process_priority = 1000
	process_mode = Node.PROCESS_MODE_ALWAYS
	preset = asked()
	for a: String in preload("res://scripts/launch_args.gd").user_args():
		if not a.begins_with(FLAG+"-") or not "=" in a: continue
		var k := a.get_slice("=",0).trim_prefix(FLAG+"-")
		if knobs.has(k): _asked[k] = float(a.get_slice("=",1))
	_noise.seed = 4
	_noise.frequency = 0.7
	_env = study.get("_environment")
	var at: Vector3 = study.isle_summit() if study.has_method("isle_summit") else Vector3.ZERO
	center = Vector3(at.x,0.0,at.z)
	_build_sky()
	_build_wall()
	_build_moon()
	_build_torch()
	_build_far()
	set_preset(preset)
	print("underground: %s, wall r=%.0f m at %s, torch on the wanderer" % [preset,float(knobs.wall),str(center)])

## The look `name` (a PRESETS key): its knobs (the flags' over them) and colours.
func set_preset(name: String) -> void:
	preset = name
	p = PRESETS[name]
	var wall_r := float(knobs.wall)
	knobs = KNOBS.duplicate()
	knobs.merge(p.get("knobs",{}),true)
	knobs.merge(_asked,true)
	knobs["wall"] = wall_r
	_wall_mat.set_shader_parameter("murk_color",p.murk)
	_wall_mat.set_shader_parameter("murk_density",float(p.wall_density))
	_wall_mat.set_shader_parameter("rock_dark",p.rock_dark)
	_wall_mat.set_shader_parameter("rock_light",p.rock_light)
	_wall_mat.set_shader_parameter("warm_tint",p.warm)
	_sky_material.set_shader_parameter("low_color",p.sky_low)
	_sky_material.set_shader_parameter("horizon_color",p.sky_horizon)
	_sky_material.set_shader_parameter("high_color",p.sky_high)
	_sky_material.set_shader_parameter("surface_strength",float(p.surface))
	moon.light_color = p.moon
	moon.light_energy = float(knobs.moon)
	torch_light.omni_range = float(knobs.torch_range)
	far.visible = bool(p.far)
	wall.scale = Vector3.ONE*float(p.get("wall_scale",1.0))
	_hold()

## The look key: the other preset, its title shown.
func cycle() -> void:
	var names: Array = PRESETS.keys()
	set_preset(names[(names.find(preset)+1) % names.size()])
	if study.has_method("_show_toast"): study.call("_show_toast",str(p.title))

## Where the wall's axis stands (the place's middle), for the generator.
func recenter(at: Vector3) -> void:
	center = Vector3(at.x,0.0,at.z)
	if wall != null: wall.position = center

# --- The pieces ------------------------------------------------------------------------

func _build_sky() -> void:
	_sky_material = ShaderMaterial.new()
	_sky_material.shader = SKY_SHADER
	var sky := Sky.new()
	sky.sky_material = _sky_material
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	_env.sky = sky

## The shaft: an open ring of rock round `center`, its radius wandering with
## noise and stepping in ledges, its inside the drawn side. Far backdrop: no
## collision, no shadows.
func _build_wall() -> void:
	var seg := 160
	var rows := 56
	var y0 := -500.0
	var y1 := 520.0
	var r0 := float(knobs.wall)
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for j in range(rows+1):
		var t := float(j)/rows
		var y := lerpf(y0,y1,t)
		for i in range(seg+1):
			var a := TAU*float(i)/seg
			var dir := Vector3(cos(a),0.0,sin(a))
			# Wandering radius, ledged (the profile steps in, then sheers),
			# and narrowing a little toward the surface.
			var n := _noise.get_noise_3d(dir.x*1.6,y*0.0055,dir.z*1.6)
			var n2 := _noise.get_noise_3d(dir.x*5.0+9.0,y*0.02,dir.z*5.0)
			var ledge := absf(fmod(y,90.0)-45.0)/45.0
			var r := r0*(1.0+n*0.28)+n2*18.0+ledge*10.0*(0.5+n)
			r *= lerpf(1.0,0.78,smoothstep(0.55,1.0,t))
			verts.append(Vector3(dir.x*r,y,dir.z*r))
			uvs.append(Vector2(float(i)/seg,t))
	for j in range(rows):
		for i in range(seg):
			var a0 := j*(seg+1)+i
			var b := a0+seg+1
			idx.append_array([a0,a0+1,b,a0+1,b+1,b])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh.custom_aabb = AABB(Vector3(-r0*2.0,y0,-r0*2.0),Vector3(r0*4.0,y1-y0,r0*4.0))
	var mat := ShaderMaterial.new()
	mat.shader = ROCK_SHADER
	mat.set_shader_parameter("top_y",y1)
	mat.set_shader_parameter("bottom_y",y0)
	_wall_mat = mat
	wall = MeshInstance3D.new()
	wall.name = "AbyssWall"
	wall.mesh = mesh
	wall.material_override = mat
	wall.position = center
	wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wall)

## A dim cool light from far above, so the ruins' forms read in the dark.
func _build_moon() -> void:
	moon = DirectionalLight3D.new()
	moon.name = "SurfaceLight"
	moon.light_energy = float(knobs.moon)
	moon.rotation_degrees = Vector3(-72.0,25.0,0.0)
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 140.0
	moon.light_specular = 0.2
	add_child(moon)

## The torch rides the wanderer: a flickering warm light and a small flame
## on a short stick at his side. The figure's animation is not touched.
func _build_torch() -> void:
	torch = Node3D.new()
	torch.name = "Torch"
	var fig: Node3D = study.get("figure")
	(fig if fig != null else study).add_child(torch)
	torch.position = Vector3(0.42,1.0,-0.32)
	var stick := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.035
	cyl.bottom_radius = 0.045
	cyl.height = 0.5
	stick.mesh = cyl
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.2,0.12,0.07)
	wood.roughness = 0.9
	stick.material_override = wood
	stick.position = Vector3(0.0,0.2,0.0)
	torch.add_child(stick)
	flame = MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.1
	sph.height = 0.34
	flame.mesh = sph
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(1.0,0.78,0.4)
	fm.emission_enabled = true
	fm.emission = FLAME
	fm.emission_energy_multiplier = 4.0
	flame.material_override = fm
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame.position = Vector3(0.0,0.5,0.0)
	torch.add_child(flame)
	torch_light = OmniLight3D.new()
	torch_light.light_color = FLAME
	torch_light.light_energy = float(knobs.torch)
	torch_light.omni_range = float(knobs.torch_range)
	torch_light.omni_attenuation = 1.4
	torch_light.shadow_enabled = true
	torch_light.shadow_bias = 0.05
	torch_light.light_specular = 0.5
	torch_light.position = Vector3(0.0,0.62,0.0)
	torch.add_child(torch_light)

# --- Held every frame ------------------------------------------------------------------

func _process(delta: float) -> void:
	_clock += delta
	_hold()
	var f := _noise.get_noise_1d(_clock*9.0)*0.5+_noise.get_noise_1d(_clock*23.0+40.0)*0.25
	torch_light.light_energy = float(knobs.torch)*(1.0+f*0.32)
	torch_light.position = Vector3(f*0.03,0.62+f*0.04,0.0)
	flame.scale = Vector3(1.0+f*0.15,1.0+f*0.35,1.0+f*0.15)

## The look's values on the study's environment, lights and air, after the
## day's, the weather's and the air's (processed before this node).
func _hold() -> void:
	if _env == null: return
	_env.background_mode = Environment.BG_SKY
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = p.ambient
	_env.ambient_light_energy = float(knobs.ambient)
	_env.ambient_light_sky_contribution = 0.0
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	_env.tonemap_exposure = float(knobs.exposure)
	_env.fog_enabled = true
	_env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	_env.fog_light_color = p.murk
	_env.fog_light_energy = 1.0
	_env.fog_density = float(knobs.fog)
	_env.fog_sky_affect = float(p.fog_sky)
	_env.fog_aerial_perspective = 0.0
	var vol := float(knobs.volume)
	_env.volumetric_fog_enabled = vol > 0.0
	_env.volumetric_fog_density = vol
	_env.volumetric_fog_albedo = p.vol_albedo
	_env.volumetric_fog_emission = Color(0.0,0.0,0.0)
	_env.volumetric_fog_length = 90.0
	_env.volumetric_fog_anisotropy = 0.55
	_env.volumetric_fog_ambient_inject = 0.0
	_env.volumetric_fog_sky_affect = 0.0
	_env.glow_enabled = true
	_env.glow_hdr_threshold = 0.9
	_env.glow_intensity = 0.55
	_env.ssao_light_affect = 0.0
	# The day away: sun and moon of the clock, stars and planet, the air.
	var lighting: Node = study.get("_lighting")
	if lighting != null:
		for l: DirectionalLight3D in lighting.lights: l.visible = false
		var objects: Node3D = lighting.get("sky_objects")
		if objects != null: objects.visible = false
	var fog_layer: Node = study.get("_display_fog")
	if fog_layer != null and fog_layer is CanvasLayer: (fog_layer as CanvasLayer).visible = false
	var look: Object = study.get("_look")
	if look != null:
		look.set("cloud_sea",0.0)
		for n: String in ["sea","cloud_volume","_motes"]:
			var v: Variant = look.get(n)
			if v is Node3D: (v as Node3D).visible = false
	var air: Node = study.get("_atmosphere")
	if air != null:
		for c: Node in air.get_children():
			if c is Node3D: (c as Node3D).visible = false

# --- The far isles (haze) --------------------------------------------------------------

## Stepped-pyramid and platform silhouettes on rock pillars out of the abyss,
## at many distances and heights, no collision: the haze's fog (the study's
## environment) is their distance. Cheap stand-ins, not the Olmec-city kit.
func _build_far() -> void:
	far = Node3D.new()
	far.name = "FarIsles"
	far.position = center
	add_child(far)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.12,0.095,0.075)
	stone.roughness = 1.0
	var rock := StandardMaterial3D.new()
	rock.albedo_color = Color(0.09,0.07,0.057)
	rock.roughness = 1.0
	var eye := StandardMaterial3D.new()
	eye.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eye.albedo_color = Color(1.0,0.66,0.28)
	eye.disable_fog = true
	# Layers: pillars at six heights, well below the start to far above it,
	# nearer ones lower, ring after ring out into the haze.
	var n := 30
	for i in range(n):
		var a := TAU*(float(i)+rng.randf_range(-0.35,0.35))/n
		var layer := rng.randi_range(0,5)
		var r := rng.randf_range(480.0,1250.0)
		var y := -280.0+layer*120.0+rng.randf_range(-35.0,35.0)
		# Keep the bridge's quarter (north, -z) for the span.
		if sin(a) < -0.55 and absf(cos(a)) < 0.7 and r > 500.0: continue
		var node := Node3D.new()
		node.position = Vector3(cos(a)*r,y,sin(a)*r)
		node.rotation.y = rng.randf()*TAU
		far.add_child(node)
		var size := rng.randf_range(0.8,1.4)*clampf(r/300.0,0.9,3.2)
		_far_isle(node,rng,size,stone,rock)
		# Something awake on it: a pair of burning eyes on the platform.
		if rng.randf() < 0.4:
			for sx in [-1.0,1.0]:
				var e := MeshInstance3D.new()
				var sp := SphereMesh.new()
				sp.radius = 1.1*size
				sp.height = 2.2*size
				e.mesh = sp
				e.material_override = eye
				e.position = Vector3(sx*2.6*size,34.0*size*0.12+3.0*size,34.0*size*0.7)
				e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				node.add_child(e)
	_far_bridge(Vector3(0.0,230.0,-900.0),stone,rock)

## The hero silhouette: a huge aqueduct-bridge of two tiers of arches
## between two pyramid-topped pillars, far to the north, no collision.
func _far_bridge(at: Vector3,stone: Material,rock: Material) -> void:
	var holder := Node3D.new()
	holder.name = "FarBridge"
	holder.position = at
	far.add_child(holder)
	var half := 300.0
	for sx in [-1.0,1.0]:
		var node := Node3D.new()
		node.position = Vector3(sx*half,0.0,0.0)
		holder.add_child(node)
		_far_isle(node,null,2.6,stone,rock,true)
	var deck_y := 20.0
	var tier := [[deck_y,70.0,22,36.0],[deck_y+70.0+12.0,46.0,14,26.0]]
	var span := half*2.0-80.0
	for t: Array in tier:
		var y0: float = t[0]
		var h: float = t[1]
		var count: int = t[2]
		var width: float = t[3]
		var deck := _box(Vector3(span,20.0,width*1.3),stone)
		deck.position.y = y0+h+6.0
		holder.add_child(deck)
		var pitch := span/count
		for k in range(count):
			var pier := _box(Vector3(pitch*0.38,h,width),stone)
			pier.position = Vector3(-span*0.5+pitch*(k+0.5),y0+h*0.5,0.0)
			holder.add_child(pier)
	# Pillars under the deck's middle, down into the dark.
	for k in range(-1,2):
		var col := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 34.0
		cone.bottom_radius = 12.0
		cone.height = 900.0
		cone.radial_segments = 8
		cone.rings = 1
		col.mesh = cone
		col.material_override = rock
		col.position = Vector3(k*span*0.3,-430.0,0.0)
		holder.add_child(col)

## One: a tapering pillar down into the dark, a platform, a pyramid of 3-6
## steps (or a long hall), and a small temple on top.
func _far_isle(node: Node3D,rng: RandomNumberGenerator,size: float,stone: Material,rock: Material,tall := false) -> void:
	var w := 34.0*size
	var pillar := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = w*0.5
	cone.bottom_radius = w*0.18
	cone.height = 1500.0
	cone.radial_segments = 9
	cone.rings = 1
	pillar.mesh = cone
	pillar.material_override = rock
	pillar.position.y = -750.0
	node.add_child(pillar)
	var plat := _box(Vector3(w*1.5,w*0.12,w*1.5),stone)
	plat.position.y = w*0.06
	node.add_child(plat)
	var top := w*0.12
	if tall or rng.randf() < 0.75:
		var steps := 6 if tall else rng.randi_range(3,6)
		var side := w*1.1
		var h := w*0.16
		for k in range(steps):
			var b := _box(Vector3(side,h,side),stone)
			b.position.y = top+h*0.5
			node.add_child(b)
			top += h
			side *= 0.78
		var temple := _box(Vector3(side*1.1,h*1.5,side*0.9),stone)
		temple.position.y = top+h*0.75
		node.add_child(temple)
		var comb := _box(Vector3(side*0.9,h*1.2,side*0.18),stone)
		comb.position.y = top+h*1.5+h*0.5
		node.add_child(comb)
	else:
		# A long hall and a tall stair-tower beside it.
		var hall := _box(Vector3(w*1.3,w*0.28,w*0.5),stone)
		hall.position = Vector3(0.0,top+w*0.14,-w*0.3)
		node.add_child(hall)
		var tower := _box(Vector3(w*0.4,w*0.8,w*0.4),stone)
		tower.position = Vector3(w*0.45,top+w*0.4,w*0.4)
		node.add_child(tower)

func _box(size: Vector3,mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m
