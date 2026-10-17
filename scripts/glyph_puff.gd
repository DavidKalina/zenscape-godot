extends Node3D
## The puff a collected glyph token (scripts/glyph_token.gd) leaves: a faint
## flash and a small wisp of soft balls where the token was, gone in about
## half a second with a few sparks of the glyph's tint; light enough to
## pick up a line of them in a row. Add it where the token vanished; it frees itself when done.
##   var puff := GlyphPuff.new()
##   puff.size = 2.0
##   puff.tint = Color("e2b25e")
##   parent.add_child(puff)
##   puff.global_position = token.global_position

## The token's size (m across its box) and tint.
var size := 1.0
var tint := Color("fff1dc")
## Seeds the puffs' layout, so a given pickup always looks the same.
var seed := 0

## Puff balls and how big they grow (fractions of `size`).
const BALLS := 6
const BALL_MIN := 0.1
const BALL_MAX := 0.16
## How far out they pop (fractions of `size`), how fast, how far they then
## drift up (fractions of `size`) and how long they take to thin away (s).
const SPREAD := 0.16
const POP := 0.14
const RISE := 0.3
const FADE := 0.55
## The cloud's colour: cream, warmed a little by the tint.
const CREAM := Color("e9e3d9")
const WARM := 0.18

const HALO_SHADER = preload("res://shaders/glyph_halo.gdshader")

## The puffs' materials by colour, and their ball and spark meshes, made
## once and shared: each puff made seven materials of its own, ~22 ms of
## the frame it popped in (the hitch at every pickup). The balls thin away
## by their own `transparency`, not their material's alpha.
static var _balls := {}
static var _motes := {}
static var _sphere: SphereMesh
static var _fade: Curve

## A puff of `tint` popped now under `parent`, far out of sight, so its
## materials are made and first drawn while the isle loads (the isle's
## tokens call it as they stand): the first pickup doesn't pay either.
static func warm(tint: Color, parent: Node3D) -> void:
	if _balls.has(CREAM.lerp(tint,WARM)): return
	var puff: Node3D = load("res://scripts/glyph_puff.gd").new()
	puff.tint = tint
	parent.add_child(puff)
	puff.global_position = Vector3(0.0,-2000.0,0.0)

static func _ball_material(colour: Color) -> StandardMaterial3D:
	if _balls.has(colour): return _balls[colour]
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = colour
	material.roughness = 1.0
	material.rim_enabled = true
	material.rim = 0.35
	material.rim_tint = 0.2
	material.emission_enabled = true
	material.emission = colour
	material.emission_energy_multiplier = 0.05
	_balls[colour] = material
	return material

static func _spark_material(colour: Color) -> StandardMaterial3D:
	if _motes.has(colour): return _motes[colour]
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = colour
	_motes[colour] = material
	return material

func _ready() -> void:
	if _sphere == null:
		_sphere = SphereMesh.new()
		_sphere.radial_segments = 10
		_sphere.rings = 6
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var colour := CREAM.lerp(tint,WARM)
	var last := 0.0
	for i in range(BALLS):
		var ball := MeshInstance3D.new()
		ball.mesh = _sphere
		ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ball.material_override = _ball_material(colour)
		add_child(ball)
		# Out round a flattened ball, a touch more sideways than up and down.
		var way := Vector3(rng.randf_range(-1.0,1.0),rng.randf_range(-0.6,0.8),rng.randf_range(-0.5,0.5)).normalized()
		if i == 0: way = Vector3.ZERO
		var grown := size*rng.randf_range(BALL_MIN,BALL_MAX)*(1.4 if i == 0 else 1.0)
		var out := way*size*SPREAD*rng.randf_range(0.6,1.0)
		ball.scale = Vector3.ONE*0.01
		var delay := rng.randf_range(0.0,0.04)
		var fade := FADE*rng.randf_range(0.8,1.2)
		last = maxf(last,delay+POP+fade)
		var tween := create_tween()
		tween.tween_interval(delay)
		tween.tween_property(ball,"scale",Vector3.ONE*grown,POP).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(ball,"position",out,POP).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(ball,"position",out*1.15+Vector3.UP*size*RISE,fade).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(ball,"scale",Vector3.ONE*grown*0.35,fade).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(ball,"transparency",1.0,fade).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_flash()
	_sparks()
	get_tree().create_timer(last+0.1).timeout.connect(queue_free)

## A bright disc that blooms out and is gone in a blink.
func _flash() -> void:
	var flash := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE*size*0.9
	flash.mesh = quad
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = HALO_SHADER
	material.set_shader_parameter("tint",tint.lerp(Color.WHITE,0.6))
	material.set_shader_parameter("strength",0.4)
	flash.material_override = material
	add_child(flash)
	var tween := create_tween()
	tween.tween_property(flash,"scale",Vector3.ONE*1.4,0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_method(func(s: float) -> void: material.set_shader_parameter("strength",s),0.4,0.0,0.2)

## A few sparks of the tint thrown out and floating off.
func _sparks() -> void:
	var sparks := CPUParticles3D.new()
	sparks.one_shot = true
	sparks.explosiveness = 0.95
	sparks.amount = 7
	sparks.lifetime = 0.6
	sparks.spread = 180.0
	sparks.gravity = Vector3(0.0,0.5,0.0)
	sparks.initial_velocity_min = size*0.5
	sparks.initial_velocity_max = size*0.9
	sparks.damping_min = size*1.5
	sparks.damping_max = size*2.2
	var mote := SphereMesh.new()
	mote.radius = 0.03*size
	mote.height = 0.06*size
	mote.radial_segments = 4
	mote.rings = 2
	mote.material = _spark_material(tint.lightened(0.4))
	sparks.mesh = mote
	if _fade == null:
		_fade = Curve.new()
		_fade.add_point(Vector2(0.0,1.0))
		_fade.add_point(Vector2(1.0,0.0))
	sparks.scale_amount_curve = _fade
	add_child(sparks)
	sparks.emitting = true
