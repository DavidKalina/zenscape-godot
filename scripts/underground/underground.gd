extends Node3D
## The underground look (docs/design/roguelike/underground-look-round1.md):
## `--underground[=torch|haze]`, a kit-isle study (studies/kit_isle.gd, so the motif yard
## and, later, run_layer) in an abyss instead of the sky. Everything is
## behind the flag; without it nothing here runs.
##
##   the abyss      a dark gradient sky with one faint far light straight up
##                  (the surface; shaders/abyss_sky.gdshader) and a huge
##                  (round 2: no far rock wall and no made-up far structures;
##                  the layer's own isles are the depth)
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
##   torch  the dark one: the wanderer's torch the
##          only warm light, the far light above, volumetric murk
##   haze   not cramped: a thick dim umber-grey haze lights everything, the
##          the layer's own far isles
##          fading in it as silhouettes; the torch only a glow; eyes still burn
##
## Knobs (KNOBS, the torch preset's; the haze preset's are in PRESETS; `--underground-<name>=<value>` overrides one):
##   fog          depth-fog density (per m)
##   volume       volumetric fog density (the torch's scatter), 0 off
##   ambient      the ambient light's energy
##   moon         the cool light from above, energy
##   exposure     tonemap exposure
##   torch        the torch light's energy
##   torch_range  its range (m)
const NEXT_SHADER = preload("res://shaders/underground_next.gdshader")
const SKY_SHADER = preload("res://shaders/abyss_sky.gdshader")
const FLAG := "--underground"
const DEFAULT_PRESET := "torch"

## Each preset's overrides of KNOBS and its colours.
const PRESETS := {
	"torch":{"title":"Underground: torch","fog_sky":0.0,"next_turf":Color(0.10,0.13,0.14),"next_stone":Color(0.13,0.15,0.2),"next_earth":Color(0.07,0.08,0.11),
		"murk":Color(0.11,0.15,0.22),"ambient":Color(0.2,0.27,0.4),"moon":Color(0.5,0.62,0.85),
		"vol_albedo":Color(0.45,0.55,0.72),"surface":0.55,
		"warm":Color(0.16,0.12,0.10),
		"sky_low":Color(0.02,0.03,0.05),"sky_horizon":Color(0.12,0.16,0.24),"sky_high":Color(0.035,0.055,0.1)},
	"haze":{"title":"Underground: haze","fog_sky":1.0,"next_turf":Color(0.22,0.17,0.11),"next_stone":Color(0.3,0.23,0.17),"next_earth":Color(0.15,0.115,0.085),
		"murk":Color(0.30,0.245,0.185),"ambient":Color(0.52,0.43,0.34),"moon":Color(0.95,0.78,0.55),
		"vol_albedo":Color(0.6,0.5,0.38),"surface":0.0,
		"warm":Color(0.3,0.2,0.12),
		"sky_low":Color(0.18,0.145,0.11),"sky_horizon":Color(0.30,0.245,0.185),"sky_high":Color(0.22,0.18,0.14),
		"knobs":{"fog":0.0016,"volume":0.0,"ambient":1.1,"moon":0.5,"exposure":1.05,"torch":2.2,"torch_range":16.0,"next_reach":520.0,"next_most":0.85}},
}
const KNOBS := {
	"fog":0.0016,"volume":0.008,"ambient":1.3,"moon":0.55,"exposure":1.3,
	"torch":5.5,"torch_range":24.0,"next_reach":420.0,"next_most":0.88,
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
var _asked := {}
var center := Vector3.ZERO
var moon: DirectionalLight3D
var torch: Node3D
var torch_light: OmniLight3D
var flame: MeshInstance3D
var _env: Environment
var _sky_material: ShaderMaterial
var _clock := 0.0
var _next_t := 0
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
	_build_moon()
	_build_torch()
	RenderingServer.frame_pre_draw.connect(_publish_sky)
	set_preset(preset)
	print("underground: %s, torch on the wanderer" % preset)

## The look `name` (a PRESETS key): its knobs (the flags' over them) and colours.
func set_preset(name: String) -> void:
	preset = name
	p = PRESETS[name]
	knobs = KNOBS.duplicate()
	knobs.merge(p.get("knobs",{}),true)
	knobs.merge(_asked,true)
	_sky_material.set_shader_parameter("low_color",p.sky_low)
	_sky_material.set_shader_parameter("horizon_color",p.sky_horizon)
	_sky_material.set_shader_parameter("high_color",p.sky_high)
	_sky_material.set_shader_parameter("surface_strength",float(p.surface))
	moon.light_color = p.moon
	moon.light_energy = float(knobs.moon)
	torch_light.omni_range = float(knobs.torch_range)
	_hold()

## The look key: the other preset, its title shown.
func cycle() -> void:
	var names: Array = PRESETS.keys()
	set_preset(names[(names.find(preset)+1) % names.size()])
	if study.has_method("_show_toast"): study.call("_show_toast",str(p.title))

## Where the place's middle is (kept for the generator).
func recenter(at: Vector3) -> void:
	center = Vector3(at.x,0.0,at.z)

# --- The pieces ------------------------------------------------------------------------

func _build_sky() -> void:
	_sky_material = ShaderMaterial.new()
	_sky_material.shader = SKY_SHADER
	var sky := Sky.new()
	sky.sky_material = _sky_material
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	_env.sky = sky

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

func _publish_sky() -> void:
	for pair: Array in [["zs_sky_down",p.sky_horizon],["zs_sky_up",p.sky_horizon],["zs_sky_glow",Color(0,0,0)]]:
		var c: Color = pair[1]
		RenderingServer.global_shader_parameter_set(pair[0],Vector3(c.r,c.g,c.b))

## The next region's far silhouettes (a real part of the layer, drawn by
## shaders/next_region_lod.gdshader) take the preset's own stone and haze, so
## they sit in the murk like the isles near them.
func _tint_next_region() -> void:
	for n: Node in study.find_children("NextRegion","MeshInstance3D",true,false):
		var mi := n as MeshInstance3D
		var m: ShaderMaterial = mi.material_override as ShaderMaterial
		if m == null: continue
		if m.shader != NEXT_SHADER:
			m = ShaderMaterial.new()
			m.shader = NEXT_SHADER
			mi.material_override = m
		m.set_shader_parameter("air_color",p.sky_horizon)
		m.set_shader_parameter("haze_reach",float(knobs.next_reach))
		m.set_shader_parameter("haze_most",float(knobs.next_most))
		m.set_shader_parameter("turf",p.next_turf)
		m.set_shader_parameter("stone",p.next_stone)
		m.set_shader_parameter("earth",p.next_earth)

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
	# The open sky's own life: clouds, gulls, motes, plane and ship traffic,
	# plane tokens. The layer's isles (sky.motifs) are the real depth and stay.
	var sky: Object = study.get("sky")
	if sky != null:
		for n: String in ["clouds","life","collectibles","traffic","ferry","drone","serpent","route","_hosts"]:
			var v: Variant = sky.get(n)
			if v is Node3D: (v as Node3D).visible = false
		for m: Node3D in sky.get("motes"): m.visible = false
		var ships: Array = sky.get("airships")
		for a: Dictionary in ships:
			for k: Variant in a.values():
				if k is Node3D: (k as Node3D).visible = false
	# The sky colours the far next-region silhouette (NextRegionLod) goes into:
	# the abyss's, not the day's.
	_publish_sky()
	_next_t -= 1
	if _next_t <= 0:
		_next_t = 20
		_tint_next_region()
	var air: Node = study.get("_atmosphere")
	if air != null:
		for c: Node in air.get_children():
			if c is Node3D: (c as Node3D).visible = false
