extends Node3D
## One fire of the city kit's fire pieces (scripts/city_kit_fires.gd): what
## burns in a cresset's bowl or on a beacon tower's crown. A look only. Its
## flame is the game's real fire (scripts/flame.gd, a raymarched volume), so
## the city's fires and the lamps are one fire:
##
##   flame    a Flame node of `kind` (brazier for a bowl) sized to `flame`
##            m tall: volumes,
##            sparks and smoke, with no light of its own
##   coals    a faint glowing bed (shaders/campfire_coals.gdshader)
##   halo     a soft camera-facing glow (shaders/stone_lamp_halo.gdshader):
##            the orange dot that reads through the haze from far off, where
##            the volume has given way
##   light    one OmniLight3D, a warm flicker (two noises: a slow breath and
##            a quick lick), shadowed only if `shadows`, faded with distance
##
## `lit` eases the fire in and out: lighting it flares (the flame overshooting
## its height) then settles.
## Sizes are the flame's height (m) and the bed's width (m).

const Flame = preload("res://scripts/flame.gd")
const COALS_SHADER := preload("res://shaders/campfire_coals.gdshader")
const HALO_SHADER := preload("res://shaders/stone_lamp_halo.gdshader")

const COLOR := Color(1.0,0.6,0.28)
## How long (s) lighting takes to flare and settle, and dousing to die.
const IGNITE := 0.9
const DIE := 0.6
## The flare's overshoot on the flame's height.
const FLARE := 0.45
## The Flame kind's own height (m) at scale 1, so `flame` sizes it.
const KIND_TALL := {"torch":0.62,"brazier":1.05,"bonfire":2.3}
## The light's fade with the camera: begins at this many ranges, over one.
## The volume stands this much taller than `flame`: a teardrop's thin tip
## reads shorter than the card did, and a bowl wants a body of fire.
const FLAME_FIT := 1.4
## The coals bed's strength: a faint warm bed under the flame, not a disc.
const COALS := 0.7
const LIGHT_FADE_AT := 2.4

## The flame's height (m), the bed's width (m).
@export var flame := 1.2
@export var bed := 1.6
## The light: its reach (m), energy at full, and whether it casts shadows.
@export var light_range := 14.0
@export var light_energy := 3.0
@export var shadows := false
## The halo's width (m) and strength.
@export var halo := 5.0
@export var halo_glow := 0.55
## How lively the light's flicker is (0 steady).
@export var flicker := 1.0
## The Flame's kind (flame.gd KINDS): brazier in a bowl. Before it enters
## the tree.
@export var kind := "brazier"
## Smoke off the flame.
@export var smoke := true

## Burning (eased in `_process`). `light()` / `douse()`.
var lit := false
## 0 out .. 1 burning; over 1 while it flares.
var heat := 0.0
## How many times it was lit (for checks).
var lightings := 0

var real: Flame
var coals: MultiMeshInstance3D
var glow: MeshInstance3D
var omni: OmniLight3D
var _coal_mat := ShaderMaterial.new()
var _halo_mat := ShaderMaterial.new()
var _since := 99.0
var _clock := 0.0
var _noise := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()
var _built := false

func _ready() -> void:
	_build()

func _build() -> void:
	if _built: return
	_built = true
	_rng.seed = hash(get_instance_id())
	_noise.seed = _rng.randi()
	_noise.frequency = 0.9
	_clock = _rng.randf()*50.0
	_coal_mat.shader = COALS_SHADER
	_coal_mat.set_shader_parameter("strength",COALS)
	_halo_mat.shader = HALO_SHADER
	_halo_mat.set_shader_parameter("tint",COLOR)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	real = Flame.new()
	real.name = "Flame"
	real.kind = kind
	real.scale_by = flame*FLAME_FIT/float(KIND_TALL.get(kind,1.05))
	real.with_light = false
	real.with_smoke = smoke
	real.burn = 0.0
	add_child(real)
	var disc := PlaneMesh.new()
	disc.size = Vector2.ONE
	coals = _batch("Coals",disc,_coal_mat,true)
	coals.multimesh.instance_count = 1
	coals.multimesh.set_instance_transform(0,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*bed),Vector3(0.0,0.01,0.0)))
	coals.multimesh.set_instance_custom_data(0,Color(_rng.randf(),0.0,0.0,0.0))
	coals.multimesh.set_instance_color(0,Color(1,1,1,1))
	glow = MeshInstance3D.new()
	glow.name = "Halo"
	glow.mesh = quad
	glow.material_override = _halo_mat
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.scale = Vector3.ONE*halo
	glow.position = Vector3(0.0,flame*0.45,0.0)
	add_child(glow)
	omni = OmniLight3D.new()
	omni.name = "Light"
	omni.light_color = COLOR
	omni.omni_range = light_range
	omni.omni_attenuation = 1.2
	omni.shadow_enabled = shadows
	omni.shadow_bias = 0.06
	omni.light_specular = 0.35
	omni.distance_fade_enabled = true
	omni.distance_fade_begin = light_range*LIGHT_FADE_AT
	omni.distance_fade_length = light_range
	omni.position = Vector3(0.0,flame*0.85,0.0)
	add_child(omni)
	_show(0.0)

func _batch(label: String, mesh: Mesh, material: Material, colours: bool) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = MultiMesh.new()
	node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	node.multimesh.use_custom_data = true
	node.multimesh.use_colors = colours
	node.multimesh.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The shaders draw the cards off their points: room round them.
	node.custom_aabb = AABB(Vector3(-bed-flame,-0.5,-bed-flame),Vector3(bed+flame,flame*2.5+1.0,bed+flame)*2.0)
	add_child(node)
	return node

## Lit now: it flares, sparks burst, then it settles.
func light() -> void:
	_build()
	if lit: return
	lit = true
	lightings += 1
	_since = 0.0

## Out now (eased).
func douse() -> void:
	if not lit: return
	lit = false
	_since = 0.0

## Lit at once, no flare (a fire burning when the place stands).
func burn() -> void:
	_build()
	lit = true
	lightings += 1
	_since = 99.0
	heat = 1.0
	_show(1.0)

func _process(delta: float) -> void:
	if not _built: return
	var dt := clampf(delta,0.0,0.1)
	_since += dt
	_clock += dt
	if lit:
		# Flares past full, then settles (an ease-out with one overshoot).
		var u := clampf(_since/IGNITE,0.0,1.0)
		heat = 1.0+FLARE*sin(u*PI)*(1.0-u*0.4) if u < 1.0 else 1.0
		heat *= smoothstep(0.0,0.18,_since)
	else:
		heat = move_toward(heat,0.0,dt/DIE)
	_show(heat)
	if heat <= 0.001: return
	_coal_mat.set_shader_parameter("time",_clock)
	# The light: a slow breath and a quick lick, both brief, never a strobe.
	var n := _noise.get_noise_1d(_clock*2.2)*0.6+_noise.get_noise_1d(_clock*7.5+31.0)*0.4
	omni.light_energy = light_energy*heat*(1.0+n*0.28*flicker)
	omni.position = Vector3(n*0.05*flame,flame*(0.85+n*0.04),0.0)

## The fire drawn at `h` (0 out .. 1 burning, over 1 flaring).
func _show(h: float) -> void:
	var on := h > 0.001
	real.burn = h
	glow.visible = on
	omni.visible = on
	_coal_mat.set_shader_parameter("strength",COALS*clampf(h,0.0,1.2) if on else 0.0)
	coals.visible = on
	_halo_mat.set_shader_parameter("glow",halo_glow*clampf(h,0.0,1.3))
