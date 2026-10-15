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
const OCULUS_SKY = preload("res://shaders/oculus_sky.gdshader")
const OCULUS_SHAFT = preload("res://shaders/oculus_shaft.gdshader")
const OCULUS_DUST = preload("res://shaders/oculus_dust.gdshader")
const FarCities = preload("res://scripts/underground/far_cities.gd")
const GroundCover = preload("res://scripts/underground/ground_cover.gd")
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
		"knobs":{"fog":0.0016,"volume":0.0,"ambient":1.1,"moon":0.5,"exposure":1.05,"torch":2.2,"torch_range":16.0,"next_reach":800.0,"next_most":0.72}},
	# The oculus (docs/design/roguelike/underground-oculus-round1.md): a vast opening high in
	# the roof with the real sky in it, a warm raking key light and a jade fill, the abyss a
	# mist sea. `oculus:true` turns on _oculus_* below.
	"oculus":{"title":"Underground: oculus","oculus":true,"fog_sky":0.0,"next_turf":Color(0.10,0.14,0.14),"next_stone":Color(0.14,0.17,0.2),"next_earth":Color(0.07,0.09,0.11),
		"murk":Color(0.10,0.17,0.19),"ambient":Color(0.20,0.34,0.38),"moon":Color(1.0,0.77,0.52),
		"vol_albedo":Color(0.55,0.66,0.66),"surface":0.0,
		"warm":Color(0.17,0.13,0.10),
		"sky_low":Color(0.05,0.09,0.10),"sky_horizon":Color(0.13,0.21,0.23),"sky_high":Color(0.03,0.05,0.07),
		"knobs":{"fog":0.0011,"volume":0.007,"ambient":1.0,"moon":0.7,"exposure":1.15,"torch":4.0,"torch_range":20.0,"next_reach":1100.0,"next_most":0.6,
			"fill":0.45,"shaft":0.12,"glory":0.6,"sea":0.55,"oculus_h":380.0,"oculus_r":190.0,"height_fog":0.012,"pool":9.0,"cities":1,"cities_glow":0.85}},
}
## How much of the ambient colour the stone is filled with (the torch lights
## the rest): dim in the dark, the haze's lit air a good deal more.
const STONE_FILL := {"torch":0.26,"haze":0.5,"oculus":0.55}
const KNOBS := {
	"fog":0.0016,"volume":0.008,"ambient":1.3,"moon":0.55,"exposure":1.3,
	"torch":5.5,"torch_range":24.0,"next_reach":900.0,"next_most":0.62,
	# The oculus preset's: the jade fill's energy, the shafts' strength, the
	# opening's brightness, the mist sea's light, the opening's height over
	# the gate (m, region 1) and radius (m), the height fog's density.
	"fill":0.45,"shaft":0.12,"glory":0.6,"sea":0.55,"oculus_h":380.0,"oculus_r":190.0,"height_fog":0.012,"pool":9.0,"cities":0,"cities_glow":1.0,
}
## The fog and the ambient's colours: cool, a little lighter than the rock.
const MURK := Color(0.085,0.115,0.17)
const AMBIENT := Color(0.16,0.22,0.34)
const MOON := Color(0.5,0.62,0.85)
const FLAME := Color(1.0,0.58,0.22)
const Flame = preload("res://scripts/flame.gd")
## The torch flame's size against the torch kind (0.62 m tall at 1).
const TORCH_FLAME := 0.72

var study: Node3D
var knobs: Dictionary = KNOBS.duplicate()
var preset := DEFAULT_PRESET
var p: Dictionary = {}
var _asked := {}
var center := Vector3.ZERO
var moon: DirectionalLight3D
var torch: Node3D
var torch_light: OmniLight3D
var flame: Node3D
var _env: Environment
var _sky_material: ShaderMaterial
var _clock := 0.0
var _next_t := 0
var _noise := FastNoiseLite.new()
## The ground cover worn (scripts/underground/ground_cover.gd: grass, dust,
## moss, "" the day's own), --ground= and G; the air's motes for it.
var ground := ""
var _motes: GPUParticles3D

## The run's world sets the look (scripts/roguelike/layer_worlds.gd,
## studies/run_layer.gd `_apply_world`): 1 on, 0 off, -1 the flags decide;
## and its preset ("" the flags'). The flag `--underground` still wins: on
## every layer.
static var world_on := -1
static var world_preset := ""

## True when the look is asked: the launch flags, else the run's world.
static func on() -> bool:
	if flagged(): return true
	return world_on == 1

## True when the launch flags ask for the underground look.
static func flagged() -> bool:
	for a: String in preload("res://scripts/launch_args.gd").user_args():
		if a == FLAG or a.begins_with(FLAG+"="): return true
	return false

## The preset the flags ask: --underground=haze, else the torch's (the
## run's world's when the flags don't ask the look). The last flag wins, so
## a launcher's extra flags override its own.
static func asked() -> String:
	if not flagged() and world_preset != "" and PRESETS.has(world_preset): return world_preset
	var args: Array = preload("res://scripts/launch_args.gd").user_args()
	for i in range(args.size()-1,-1,-1):
		var a: String = args[i]
		if a.begins_with(FLAG+"="):
			var k := a.get_slice("=",1)
			if PRESETS.has(k): return k
	return DEFAULT_PRESET

## The look stood on `study_node` (a kit isle) if the flags ask; null otherwise.
static func attach(study_node: Node3D) -> Node3D:
	if not on(): return null
	var had := study_node.get_node_or_null("Underground")
	if had != null: return had as Node3D
	var u: Node3D = (preload("res://scripts/underground/underground.gd") as GDScript).new()
	u.name = "Underground"
	study_node.add_child(u)
	u.setup(study_node)
	return u

## The look taken off `study_node` live (the run's climb out of the dark):
## the day's environment, sky, lights and air given back as they were, the
## torch put out, the ground cover handed back to the day. Nothing if the
## look isn't on.
static func detach(study_node: Node3D) -> void:
	var u := study_node.get_node_or_null("Underground")
	if u == null or not u.has_method("restore"): return
	u.restore()
	# Renamed first, so a look stood again at once can take the name.
	u.name = "UndergroundGone"
	study_node.remove_child(u)
	u.queue_free()

## The environment's values the look holds, kept to give back (`restore`).
const HELD := ["background_mode","ambient_light_source","ambient_light_color","ambient_light_energy","ambient_light_sky_contribution",
	"reflected_light_source","tonemap_exposure","fog_enabled","fog_mode","fog_light_color","fog_light_energy","fog_density",
	"fog_sky_affect","fog_aerial_perspective","volumetric_fog_enabled","volumetric_fog_density","volumetric_fog_albedo",
	"volumetric_fog_emission","volumetric_fog_length","volumetric_fog_anisotropy","volumetric_fog_ambient_inject",
	"volumetric_fog_sky_affect","glow_enabled","glow_hdr_threshold","glow_intensity","ssao_light_affect","sky"]
var _env_was := {}
## Each node the look hid and whether it was shown before; the look's cloud
## sea before.
var _hidden := {}
var _cloud_sea_was: Variant = null

func setup(study_node: Node3D) -> void:
	study = study_node
	process_priority = 1000
	process_mode = Node.PROCESS_MODE_ALWAYS
	preset = asked()
	var env: Environment = study.get("_environment")
	if env != null:
		for k: String in HELD: _env_was[k] = env.get(k)
	var look_was: Object = study.get("_look")
	if look_was != null: _cloud_sea_was = look_was.get("cloud_sea")
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
	ground = GroundCover.asked()
	_set_motes()
	if "--ground-demo" in preload("res://scripts/launch_args.gd").user_args(): get_tree().create_timer(3.0).timeout.connect(_demo)
	RenderingServer.frame_pre_draw.connect(_publish_sky)
	set_preset(preset)
	print("underground: %s, torch on the wanderer" % preset)

## The look `name` (a PRESETS key): its knobs (the flags' over them) and colours.
func set_preset(name: String) -> void:
	preset = name
	p = PRESETS[name]
	knobs = KNOBS.duplicate()
	knobs.merge(p.get("knobs",{}),true)
	_lift_preset()
	knobs.merge(_asked,true)
	_sky_material.set_shader_parameter("low_color",p.sky_low)
	_sky_material.set_shader_parameter("horizon_color",p.sky_horizon)
	_sky_material.set_shader_parameter("high_color",p.sky_high)
	_sky_material.set_shader_parameter("surface_strength",float(p.surface))
	moon.light_color = p.moon
	moon.light_energy = float(knobs.moon)
	torch_light.omni_range = float(knobs.torch_range)
	_hold()
	_oculus_apply()

## The run's climb out of the dark (scripts/roguelike/run_loop.gd
## CLIMB_LIGHTEN): 0 the torch preset as authored, toward 1 its colours and
## knobs eased toward the haze's. Static, so a look stood again keeps it.
## Only light, air and the far silhouettes' tint: no growth is touched.
static var climb_lift := 0.0

func set_climb_lift(lift: float) -> void:
	if is_equal_approx(lift,climb_lift): return
	climb_lift = clampf(lift,0.0,1.0)
	set_preset(preset)

## The torch preset eased `climb_lift` toward the haze's (`set_preset`).
func _lift_preset() -> void:
	if preset != "torch" or climb_lift <= 0.0: return
	var to: Dictionary = PRESETS.haze
	var mixed := p.duplicate()
	for k: String in p:
		if p[k] is Color and to.get(k) is Color: mixed[k] = (p[k] as Color).lerp(to[k],climb_lift)
		elif p[k] is float and to.get(k) is float: mixed[k] = lerpf(p[k],to[k],climb_lift)
	p = mixed
	var haze := KNOBS.duplicate()
	haze.merge(to.get("knobs",{}),true)
	# The torch kept as it is: the Olmec's sight reads it (scripts/enemies/
	# light_level.gd), so the climb's air never changes who sees whom.
	for k: String in knobs:
		if k in ["torch","torch_range"]: continue
		knobs[k] = lerpf(float(knobs[k]),float(haze[k]),climb_lift)

## The look key: the other preset, its title shown.
func cycle() -> void:
	var names: Array = PRESETS.keys()
	set_preset(names[(names.find(preset)+1) % names.size()])
	if study.has_method("_show_toast"): study.call("_show_toast",str(p.title))

## The next ground cover (G): the day's own, then grass, dust, moss.
func cycle_ground() -> void:
	ground = GroundCover.next(ground)
	_set_motes()
	if is_instance_valid(_demo_root): _demo()
	if study.has_method("_show_toast"): study.call("_show_toast",str(GroundCover.KINDS[ground].title) if ground != "" else "Ground: as the day paints it")

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_G and not key.ctrl_pressed and not key.meta_pressed:
		cycle_ground()

## `--ground-demo`: stone pieces by the start with the cover on their tops.
var _demo_root: Node3D
func _demo() -> void:
	if is_instance_valid(_demo_root): _demo_root.queue_free()
	var fig: Node3D = study.get("figure")
	var at: Vector3 = fig.global_position if fig != null else Vector3.ZERO
	_demo_root = GroundCover.demo(study,at,ground if ground != "" else "grass")
	print("ground demo at ",at)

func _exit_tree() -> void:
	RenderingServer.global_shader_parameter_set("zs_under",0.0)
	RenderingServer.global_shader_parameter_set("zs_under_crisp",0.0)
	_free_motes()
	_oculus_free()

## The motes' resources are let go with them, or the renderer reports the
## particle shader as leaked at exit.
func _free_motes() -> void:
	if not is_instance_valid(_motes): return
	_motes.emitting = false
	_motes.process_material = null
	_motes.draw_pass_1 = null
	_motes.free()
	_motes = null

## The air's motes for the ground (grit, spores), following the wanderer.
func _set_motes() -> void:
	_free_motes()
	_motes = GroundCover.motes(ground)
	if _motes != null: add_child(_motes)

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
	# The flame is the game's real fire (scripts/flame.gd), no light of its
	# own: the torch's light below is the one that lights the stone.
	var real: Node3D = Flame.new()
	real.set("kind","torch")
	real.set("scale_by",TORCH_FLAME)
	real.set("with_light",false)
	real.set("with_smoke",false)
	flame = real
	flame.name = "Flame"
	flame.position = Vector3(0.0,0.44,0.0)
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
	_publish_stone()

## The weathered stone's fill (shaders/olmec_stone.gdshader, ruin_stone) in
## the look's own air, not the day sky's hemisphere (which made the basalt
## glow blue-white in the dark). Only the stone reads these globals, so the
## turf and the rest keep the day's hemisphere. Held every frame, like the sky.
func _publish_stone() -> void:
	# The air's colour, eased toward grey so the basalt isn't one flat blue.
	var amb: Color = (p.ambient as Color).lerp(Color(0.34,0.34,0.34),0.35)
	var low: Color = p.warm
	var e := float(STONE_FILL.get(preset,0.2))
	if preset == "torch": e = lerpf(e,float(STONE_FILL.haze),climb_lift)
	RenderingServer.global_shader_parameter_set("zs_under",1.0)
	RenderingServer.global_shader_parameter_set("zs_under_crisp",1.0 if bool(p.get("oculus",false)) else 0.0)
	RenderingServer.global_shader_parameter_set("zs_under_sky",Vector3(amb.r,amb.g,amb.b)*e)
	RenderingServer.global_shader_parameter_set("zs_under_ground",Vector3(low.r,low.g,low.b)*e)

## The next region's far silhouettes (a real part of the layer, drawn by
## shaders/next_region_lod.gdshader) take the preset's own stone and haze, so
## they sit in the murk like the isles near them.
func _tint_next_region() -> void:
	# By its group (scripts/roguelike/next_region_lod.gd): a find_children
	# down the whole layer here was an 11-12 ms hitch every 20th frame
	# (docs/design/roguelike/perf-city-run-round1.md).
	for n: Node in get_tree().get_nodes_in_group(&"next_region"):
		if not n is MeshInstance3D or not study.is_ancestor_of(n): continue
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
		_far_fire(mi)

## The next region's beacon (the climb up, docs/design/roguelike/
## game-v1-climb-up.md): a far fire on its landmark's top, a soft warm glow
## that reads up there in the dark where the silhouette alone would sink
## into the murk. One billboard, no light, no shadow. FAR_FIRE 0 drops it.
const FAR_FIRE := 14.0
const FAR_FIRE_COLOUR := Color(1.0,0.62,0.3)
const FAR_FIRE_STRENGTH := 1.5
func _far_fire(mi: MeshInstance3D) -> void:
	if FAR_FIRE <= 0.0 or mi.has_node("FarFire"): return
	var layer: Variant = study.get("layer")
	if not (layer is Dictionary) or not (layer as Dictionary).has("next"): return
	var nxt: Dictionary = (layer as Dictionary).next
	if not nxt.has("landmark"): return
	var glow := MeshInstance3D.new()
	glow.name = "FarFire"
	var quad := QuadMesh.new()
	quad.size = Vector2(FAR_FIRE,FAR_FIRE)
	glow.mesh = quad
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5,0.5)
	tex.fill_to = Vector2(0.5,0.0)
	var g := Gradient.new()
	g.set_color(0,Color(1,1,1,1))
	g.set_color(1,Color(1,1,1,0))
	g.add_point(0.07,Color(1,1,1,0.6))
	g.add_point(0.3,Color(1,1,1,0.12))
	tex.gradient = g
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_texture = tex
	mat.albedo_color = FAR_FIRE_COLOUR*FAR_FIRE_STRENGTH
	mat.disable_fog = true
	mat.no_depth_test = false
	glow.material_override = mat
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_child(glow)
	# (The landmark mark sits MARK_UNDER, 3 m, under its highest cell.)
	glow.global_position = (nxt.landmark as Vector3)+Vector3.UP*(3.0+FAR_FIRE*0.25)

# --- The oculus preset ----------------------------------------------------------------------
# A vast opening high in the cavern roof above the way up (the layer's exit gate),
# shown by shaders/oculus_sky.gdshader with the real sky in it; a warm key
# light and shafts from it, a cool jade fill, a mist sea in the abyss. The
# opening is a real place (a world position and radius), so it grows as the
# wanderer climbs toward it and, region by region, sits nearer and larger.

## Where the opening lies over the exit, toward the start (share of the
## way), so the light rakes in at about 40 degrees rather than straight down.
const OCULUS_PULL := 0.3
## The light's rake from the vertical down the gate's shaft (degrees), and how
## fast the climb saturates (per region): the opening comes lower and wider as
## the run climbs, region by region and step by step within each.
const RAKE := 40.0
const CLIMB_RATE := 0.9
## Region by region the opening comes lower and larger, to these shares.
const OCULUS_LOWER := 0.6
const OCULUS_WIDER := 0.9
## How far under the lowest isle the mist sea lies (m past the layer's void).
const SEA_BELOW := 40.0
## The shafts (start, middle, gate): the radius where each lands (m), the
## top as a share of the opening's radius, and each one's strength.
const SHAFT_LAND := [34.0,26.0,44.0]
const SHAFT_TOP := 0.32
const SHAFT_LEVEL := [0.8,0.45,1.0]
## How far up the shaft a pool's light stands (m).
const POOL_BACK := 110.0

var _oculus_live := false
var _oculus_material: ShaderMaterial
var _abyss_sky: Sky
var _oculus_sky: Sky
var _shafts: Array[MeshInstance3D] = []
var _fill: DirectionalLight3D
## The pools of light (spot lights at the start's and the gate's shafts).
var _pools: Array[SpotLight3D] = []
var _dust: GPUParticles3D
var _dust_material: ShaderMaterial
var _cities: Node3D
var _cities_seed := -1
var _anchor_tag := -999999
var _anchors := {}

func _oculus_apply() -> void:
	var want: bool = bool(p.get("oculus",false))
	if want == _oculus_live: return
	_oculus_live = want
	if want:
		_oculus_build()
		_env.sky = _oculus_sky
	else:
		if _abyss_sky != null: _env.sky = _abyss_sky
		_oculus_free()
		moon.rotation_degrees = Vector3(-72.0,25.0,0.0)
		moon.directional_shadow_max_distance = 140.0
		moon.light_specular = 0.2
		moon.light_volumetric_fog_energy = 1.0

func _oculus_build() -> void:
	_abyss_sky = _env.sky
	_oculus_material = ShaderMaterial.new()
	_oculus_material.shader = OCULUS_SKY
	_oculus_sky = Sky.new()
	_oculus_sky.sky_material = _oculus_material
	# The sky is traced from the camera each frame; its radiance isn't read.
	_oculus_sky.process_mode = Sky.PROCESS_MODE_QUALITY
	_oculus_sky.radiance_size = Sky.RADIANCE_SIZE_32
	_fill = DirectionalLight3D.new()
	_fill.name = "JadeFill"
	_fill.shadow_enabled = false
	_fill.light_specular = 0.0
	_fill.light_color = Color(0.45,0.78,0.82)
	_fill.light_volumetric_fog_energy = 0.0
	add_child(_fill)
	for i in 3:
		var shaft := MeshInstance3D.new()
		shaft.name = "Shaft%d" % i
		var cone := CylinderMesh.new()
		cone.radial_segments = 28
		cone.rings = 1
		cone.cap_top = false
		cone.cap_bottom = false
		shaft.mesh = cone
		var m := ShaderMaterial.new()
		m.shader = OCULUS_SHAFT
		shaft.material_override = m
		shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shaft.extra_cull_margin = 4000.0
		add_child(shaft)
		_shafts.append(shaft)
	_dust = GPUParticles3D.new()
	_dust.name = "ShaftDust"
	_dust.amount = 220
	_dust.lifetime = 14.0
	_dust.preprocess = 14.0
	_dust.local_coords = false
	_dust.visibility_aabb = AABB(Vector3(-60,-30,-60),Vector3(120,60,120))
	_dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(38,14,38)
	pm.direction = Vector3(0,1,0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.1
	pm.initial_velocity_max = 0.5
	pm.gravity = Vector3.ZERO
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.5
	pm.turbulence_noise_scale = 6.0
	_dust.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(1,1)
	_dust_material = ShaderMaterial.new()
	_dust_material.shader = OCULUS_DUST
	quad.material = _dust_material
	_dust.draw_pass_1 = quad
	add_child(_dust)
	for i in 2:
		var pool := SpotLight3D.new()
		pool.name = "Pool%d" % i
		pool.light_color = Color(1.0,0.84,0.64) if i == 0 else Color(1.0,0.78,0.52)
		pool.shadow_enabled = true
		pool.shadow_bias = 0.08
		pool.spot_angle_attenuation = 0.6
		pool.spot_attenuation = 0.5
		pool.light_specular = 0.6
		add_child(pool)
		_pools.append(pool)
	_cities = FarCities.new()
	_cities.name = "FarCities"
	add_child(_cities)
	_anchor_tag = -999999

func _oculus_free() -> void:
	_oculus_restore_gate_beam()
	if is_instance_valid(_cities): _cities.queue_free()
	_cities = null
	for n: Node in _shafts:
		if is_instance_valid(n): n.queue_free()
	_shafts.clear()
	if is_instance_valid(_fill): _fill.queue_free()
	_fill = null
	for n: Node in _pools:
		if is_instance_valid(n): n.queue_free()
	_pools.clear()
	if is_instance_valid(_dust):
		_dust.emitting = false
		_dust.process_material = null
		_dust.draw_pass_1 = null
		_dust.free()
	_dust = null
	_oculus_live = false

## Where things stand for the layer on the study: the exit, the start, the
## abyss's depth; the opening over the way up and its light.
func _oculus_anchors(near := 0.0) -> Dictionary:
	var ascent := 0.0
	var l: Variant = study.get("layer")
	var start: Vector3 = study.get("start") if study.get("start") is Vector3 else center
	var exit: Vector3
	var void_y := start.y-120.0
	# How far up the run has climbed: region by region and, within one, step by
	# step as he nears the gate (`near`, 0 at the start to 1 at the gate).
	if study.has_method("region"): ascent = 1.0-exp(-((float(study.call("region"))-1.0)+near)*CLIMB_RATE)
	if l is Dictionary and (l as Dictionary).has("exit") and not ((l as Dictionary).exit as Dictionary).is_empty():
		exit = ((l as Dictionary).exit as Dictionary).at
		void_y = float((l as Dictionary).get("void_y",void_y))
	else:
		exit = start+Vector3(140.0,60.0,-260.0)
	var flat := Vector3(start.x-exit.x,0.0,start.z-exit.z)
	var reach := maxf(flat.length(),1.0)
	var h := float(knobs.oculus_h)*(1.0-OCULUS_LOWER*ascent)
	var radius := float(knobs.oculus_r)*(1.0+OCULUS_WIDER*ascent)
	# The opening stands so the light rakes down the gate's shaft at RAKE degrees.
	var pull := clampf(h*tan(deg_to_rad(RAKE))/reach,0.2,0.75)
	var at := exit+flat/reach*reach*pull+Vector3.UP*h
	var mid := (start+exit)*0.5
	return {"ascent":ascent,"start":start,"exit":exit,"at":at,"radius":radius,"key":(at-mid).normalized(),"sea":void_y-SEA_BELOW,"reach":reach,"mid":mid}

func _oculus_tick() -> void:
	var seed_now := int(study.get("layer_seed")) if study.get("layer_seed") != null else 0
	var start_now: Vector3 = study.get("start") if study.get("start") is Vector3 else Vector3.ZERO
	var region := int(study.call("region")) if study.has_method("region") else 1
	var fig: Node3D = study.get("figure")
	var closeness := 0.0
	if not _anchors.is_empty():
		var here0: Vector3 = fig.global_position if fig != null else _anchors.start
		var ex0: Vector3 = _anchors.exit
		closeness = 1.0-clampf(Vector2(here0.x-ex0.x,here0.z-ex0.z).length()/float(_anchors.reach),0.0,1.0)
	var tag := seed_now*7919+int(start_now.x*3.0+start_now.z)+region*104729+int(closeness*20.0)*31
	if tag != _anchor_tag:
		_anchor_tag = tag
		_anchors = _oculus_anchors(closeness)
		_oculus_place()
	if _anchors.is_empty(): return
	# The gate may be built after the opening is placed: aim its beam when it stands.
	if not _beam_aimed and Engine.get_process_frames()%30 == 0: _oculus_aim_gate_beam()
	var here: Vector3 = fig.global_position if fig != null else _anchors.start
	var ascent := float(_anchors.ascent)
	# Brighter region by region, and as he nears the way up.
	_oculus_material.set_shader_parameter("glory",float(knobs.glory)*lerpf(1.0,1.5,ascent)*(0.8+0.5*closeness))
	_oculus_material.set_shader_parameter("sea_glow",float(knobs.sea))
	var level := float(knobs.shaft)*lerpf(1.0,1.4,ascent)*(0.8+0.5*closeness)
	for i in _shafts.size():
		(_shafts[i].material_override as ShaderMaterial).set_shader_parameter("strength",level*float(SHAFT_LEVEL[i]))
	if is_instance_valid(_dust): _dust.global_position = here+Vector3(0.0,4.0,0.0)
	for i in _pools.size():
		_pools[i].light_energy = float(knobs.pool)*lerpf(1.0,1.3,ascent)*(0.3 if i == 0 else 1.25)
	_env.fog_height = float(_anchors.sea)+120.0
	_env.fog_height_density = float(knobs.height_fog)

## The game's own gate beam (scripts/roguelike/layer_stage.gd), laid along the
## gate's shaft instead of straight up, fainter, so the two read as one light.
var _beam_was := {}
var _beam_aimed := false
func _oculus_aim_gate_beam() -> void:
	var gate := study.find_child("ExitGate",true,false) as Node3D
	if gate == null or gate.get_child_count() == 0:
		_beam_aimed = false
		return
	_beam_aimed = true
	var beam: MeshInstance3D = null
	for c: Node in gate.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is CylinderMesh and ((c as MeshInstance3D).mesh as CylinderMesh).height > 40.0: beam = c as MeshInstance3D
	if beam == null: return
	var col := beam.mesh as CylinderMesh
	var mat := beam.material_override as StandardMaterial3D
	if not _beam_was.has(beam):
		_beam_was[beam] = {"xf":beam.transform,"alpha":mat.albedo_color.a if mat != null else 0.0}
	var was: Dictionary = _beam_was[beam]
	var up: Vector3 = ((_anchors.at as Vector3)-gate.global_position).normalized()
	beam.global_transform = Transform3D(Basis(Quaternion(Vector3.UP,up)),gate.global_position+up*col.height*0.5)
	if mat != null:
		var c := mat.albedo_color
		c.a = minf(float(was.alpha),0.12)
		mat.albedo_color = c

func _oculus_restore_gate_beam() -> void:
	for b: Variant in _beam_was:
		if not is_instance_valid(b): continue
		var beam := b as MeshInstance3D
		beam.transform = (_beam_was[b] as Dictionary).xf
		var mat := beam.material_override as StandardMaterial3D
		if mat != null:
			var c := mat.albedo_color
			c.a = float((_beam_was[b] as Dictionary).alpha)
			mat.albedo_color = c
	_beam_was.clear()

## The opening, key light, fill and shafts set for the layer.
func _oculus_place() -> void:
	var a := _anchors
	var key: Vector3 = a.key
	_oculus_material.set_shader_parameter("oculus",a.at)
	_oculus_material.set_shader_parameter("radius",float(a.radius))
	_oculus_material.set_shader_parameter("throat",float(a.radius)*0.8)
	_oculus_material.set_shader_parameter("cloud_height",float(a.at.y-a.exit.y)*2.4)
	_oculus_aim_gate_beam()
	if _cities != null and int(knobs.cities) > 0:
		if _cities_seed != int(study.get("layer_seed")) or not _cities.has_node("FarCities"):
			_cities_seed = int(study.get("layer_seed")) if study.get("layer_seed") != null else 0
			(_cities as Object).call("build",a.mid,float(a.sea),float((a.start as Vector3).y),_cities_seed)
		(_cities as Object).call("set_look",(p.sky_horizon as Color).lerp(Color(0.2,0.3,0.32),0.5),float(knobs.cities_glow),float(knobs.next_reach))
		(_cities as Object).call("set_light",a.key)
	_oculus_material.set_shader_parameter("sea_y",float(a.sea))
	_oculus_material.set_shader_parameter("sun_dir",key)
	_oculus_material.set_shader_parameter("pool_at",a.exit)
	# The key light rakes along the shaft; the fill comes the other way, low.
	moon.basis = Basis.looking_at(-key,Vector3.UP)
	moon.directional_shadow_max_distance = 220.0
	moon.light_specular = 0.6
	moon.light_volumetric_fog_energy = 1.0
	_fill.basis = Basis.looking_at(Vector3(key.x,-0.25,key.z).normalized(),Vector3.UP)
	_fill.light_energy = float(knobs.fill)
	var land: Array[Vector3] = [a.start,a.mid,a.exit]
	_dust_material.set_shader_parameter("top",a.at)
	_dust_material.set_shader_parameter("foot_a",a.start)
	_dust_material.set_shader_parameter("foot_b",a.mid)
	_dust_material.set_shader_parameter("foot_c",a.exit)
	_dust_material.set_shader_parameter("land",Vector3(SHAFT_LAND[0],SHAFT_LAND[1],SHAFT_LAND[2]))
	_dust_material.set_shader_parameter("top_r",float(a.radius)*SHAFT_TOP)
	# The pools: a spot light on the start and on the gate, down the shaft.
	for i in _pools.size():
		var foot: Vector3 = land[i*2]
		var back: Vector3 = ((a.at as Vector3)-foot).normalized()
		var r := float(SHAFT_LAND[i*2])
		var pool := _pools[i]
		pool.position = foot+back*POOL_BACK
		pool.basis = Basis.looking_at(-back,Vector3.UP)
		pool.spot_range = POOL_BACK*1.7
		pool.spot_angle = rad_to_deg(atan(r*1.25/POOL_BACK))
	for i in _shafts.size():
		var top: Vector3 = a.at
		var foot: Vector3 = land[i]
		var toward := (top-foot).normalized()
		var low := foot-toward*((foot.y-float(a.sea)+10.0)/maxf(toward.y,0.2))
		var cone := _shafts[i].mesh as CylinderMesh
		cone.height = top.distance_to(low)
		cone.top_radius = float(a.radius)*SHAFT_TOP
		cone.bottom_radius = float(SHAFT_LAND[i])
		var sm := _shafts[i].material_override as ShaderMaterial
		sm.set_shader_parameter("r_low",float(SHAFT_LAND[i]))
		sm.set_shader_parameter("r_top",float(a.radius)*SHAFT_TOP)
		sm.set_shader_parameter("length_m",cone.height)
		var y := (top-low).normalized()
		var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
		_shafts[i].transform = Transform3D(Basis(x,y,x.cross(y)),(top+low)*0.5)

# --- Held every frame ------------------------------------------------------------------

func _process(delta: float) -> void:
	_clock += delta
	_hold()
	if is_instance_valid(_motes):
		var fig: Node3D = study.get("figure")
		if fig != null: _motes.global_position = fig.global_position+Vector3(0.0,1.5,0.0)
	if _oculus_live: _oculus_tick()
	var f := _noise.get_noise_1d(_clock*9.0)*0.5+_noise.get_noise_1d(_clock*23.0+40.0)*0.25
	torch_light.light_energy = float(knobs.torch)*(1.0+f*0.32)
	torch_light.position = Vector3(f*0.03,0.62+f*0.04,0.0)

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
	if not _oculus_live: _env.fog_height_density = 0.0
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
		for l: DirectionalLight3D in lighting.lights: _hide(l)
		var objects: Node3D = lighting.get("sky_objects")
		if objects != null: _hide(objects)
	var fog_layer: Node = study.get("_display_fog")
	if fog_layer != null and fog_layer is CanvasLayer: _hide(fog_layer)
	var look: Object = study.get("_look")
	if look != null:
		look.set("cloud_sea",0.0)
		for n: String in ["sea","cloud_volume","_motes"]:
			var v: Variant = look.get(n)
			if v is Node3D: _hide(v)
	# The open sky's own life: clouds, gulls, motes, plane and ship traffic,
	# plane tokens. The layer's isles (sky.motifs) are the real depth and stay.
	var sky: Object = study.get("sky")
	if sky != null:
		for n: String in ["clouds","life","collectibles","traffic","ferry","drone","serpent","route","_hosts"]:
			var v: Variant = sky.get(n)
			if v is Node3D: _hide(v)
		for m: Node3D in sky.get("motes"): _hide(m)
		var ships: Array = sky.get("airships")
		for a: Dictionary in ships:
			for k: Variant in a.values():
				if k is Node3D: _hide(k)
	# The sky colours the far next-region silhouette (NextRegionLod) goes into:
	# the abyss's, not the day's.
	_publish_sky()
	if GroundCover.grade(ground,preset):
		var celestial: Object = study.get("_celestial")
		if celestial != null and celestial.get("look") != null: (celestial.get("look") as Object).call("publish")
	_next_t -= 1
	if _next_t <= 0:
		_next_t = 20
		_tint_next_region()
	var air: Node = study.get("_atmosphere")
	if air != null:
		for c: Node in air.get_children():
			if c is Node3D: _hide(c)

## A node of the day's hidden, its own visibility kept (the first time) to
## give back.
func _hide(n: Node) -> void:
	if not _hidden.has(n): _hidden[n] = bool(n.get("visible"))
	n.set("visible",false)

## The day given back (`detach`): the environment as it was, every node the
## look hid shown again as it was, the torch out, the cover the day's.
func restore() -> void:
	set_process(false)
	if RenderingServer.frame_pre_draw.is_connected(_publish_sky): RenderingServer.frame_pre_draw.disconnect(_publish_sky)
	if _env != null:
		for k: String in _env_was: _env.set(k,_env_was[k])
	for n: Variant in _hidden:
		if is_instance_valid(n): (n as Node).set("visible",bool(_hidden[n]))
	_hidden.clear()
	var look: Object = study.get("_look")
	if look != null and _cloud_sea_was != null: look.set("cloud_sea",_cloud_sea_was)
	if is_instance_valid(torch):
		torch.get_parent().remove_child(torch)
		torch.queue_free()
	_free_motes()
	_oculus_free()
	RenderingServer.global_shader_parameter_set("zs_under",0.0)
	RenderingServer.global_shader_parameter_set("zs_under_crisp",0.0)
	if GroundCover.grade("",preset):
		var celestial: Object = study.get("_celestial")
		if celestial != null and celestial.get("look") != null: (celestial.get("look") as Object).call("publish")
