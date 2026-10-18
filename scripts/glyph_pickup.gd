extends Node3D
## A collectible glyph token as it stands in the world (scripts/
## glyph_token.gd): the token turning slowly and bobbing in a holder, a soft
## halo behind it (shaders/glyph_halo.gdshader) and a few motes drifting up
## round it; and its pickup (`take`): a short twist that winds faster as the
## token lifts a touch and brightens, then, still spinning, it shrinks away
## into a small wisp (scripts/glyph_puff.gd). Light enough to pick up a line
## of them in a row. The collectible gallery (studies/collectible_gallery.gd)
## and the sky's tokens (scripts/sky_collectibles.gd) both stand these.
##   var holder := GlyphPickup.make("sun",1.1)
##   parent.add_child(holder)
##   ...
##   holder.take(seed)   # frees itself when done
## Glyph "rune" stands the rune token instead (scripts/rune_token.gd): a
## red stone plummet on a fading thread, swaying as it bobs.
const GlyphToken = preload("res://scripts/glyph_token.gd")
const RuneToken = preload("res://scripts/rune_token.gd")
const GlyphPuff = preload("res://scripts/glyph_puff.gd")
const HudIcons = preload("res://scripts/hud_icons.gd")
const HALO_SHADER = preload("res://shaders/glyph_halo.gdshader")

## The rune's bob (m, and its pace): deeper and slower than a glyph's, and
## not gentled when calm, so it floats like a weight on a line.
const RUNE_BOB := 0.2
const RUNE_BOB_PACE := 0.95

## The turn (rad/s) and the bob (m, and its pace).
const TURN := 0.7
const BOB := 0.12
const BOB_PACE := 1.3
## A calm token (`calm`: one only the pilot on foot takes) turns and bobs
## this share as much, at this share of the pace, in a halo this much
## wider, warmed this far toward WARM: at rest, so it reads as one to land
## for.
const CALM := 0.45
const CALM_PACE := 0.6
const CALM_HALO := 1.25
const CALM_WARM := 0.35
const WARM := Color("ffd9a0")
## The glow in the world (`glow_for`): the rim's glow and the halo's
## strength by day and at full night, and the token's own faint inner
## light at night, so it reads as a small lantern after dark.
const GLOW := Vector2(0.5,0.95)
const HALO := Vector2(0.28,0.55)
const INNER_NIGHT := 0.16
## The pickup's spin: how long it winds up (s), how many turns it makes
## (each faster than the last) and how high it lifts (fraction of its size).
const SPIN_TIME := 0.32
const SPIN_TURNS := 1.5
const SPIN_LIFT := 0.08
## How long it keeps spinning as it shrinks away into the wisp (s).
const SHRINK_TIME := 0.18

## The glyph (HudIcons id) and the token's size (m across its box).
var id := "sun"
var size := 1.0
## Its bob's phase (rad), so a line of them doesn't bob in step.
var phase := 0.0
## False holds the turn still (the gallery's freeze).
var turning := true
## True from the pickup on.
var taking := false
## True for a token only the pilot on foot takes: it turns and bobs
## gentler, in a warmer, wider halo.
var calm := false
var _glow := 0.35
var _halo_strength := 0.22
## The motes, so far ones can stop drifting (`motes_on`).
var motes: CPUParticles3D
var _spin: Node3D
var _token: MeshInstance3D
var _halo: MeshInstance3D
## The rune's plummet (null for a glyph) and its bead's and thread's
## materials, lit with the stone.
var _plummet: Node3D
var _lights: Array[ShaderMaterial] = []

## A holder for glyph `id`, `size` m across, its token turning in "Spin";
## `calm` for one only the pilot on foot takes.
static func make(glyph: String, token_size: float, bob_phase := 0.0, is_calm := false) -> Node3D:
	var holder: Node3D = new()
	holder.calm = is_calm
	holder._build(glyph,token_size,bob_phase)
	return holder

func _build(glyph: String, token_size: float, bob_phase: float) -> void:
	id = glyph
	size = token_size
	phase = bob_phase
	name = "Token_"+id
	set_meta("phase",phase)
	_spin = Node3D.new()
	_spin.name = "Spin"
	add_child(_spin)
	if id == "rune":
		var tint := Color(HudIcons.item(id).tint)
		_plummet = RuneToken.plummet(size,tint)
		_spin.add_child(_plummet)
		_token = _plummet.get_node("Sway/Hang/Stone")
		_lights = RuneToken.materials(_plummet).slice(1)
	else:
		_token = GlyphToken.token(id,size)
		_spin.add_child(_token)
	_halo = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE*size*1.9*(CALM_HALO if calm else 1.0)
	_halo.mesh = quad
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var halo_material := ShaderMaterial.new()
	halo_material.shader = HALO_SHADER
	var halo_tint := Color(HudIcons.item(id).tint).lightened(0.5)
	if calm: halo_tint = halo_tint.lerp(WARM,CALM_WARM)
	halo_material.set_shader_parameter("tint",halo_tint)
	_halo.material_override = halo_material
	add_child(_halo)
	motes = CPUParticles3D.new()
	motes.amount = 10
	motes.lifetime = 2.6
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	motes.emission_sphere_radius = size*0.55
	motes.direction = Vector3.UP
	motes.spread = 30.0
	motes.gravity = Vector3(0.0,0.06,0.0)
	motes.initial_velocity_min = 0.05
	motes.initial_velocity_max = 0.15
	var mote := SphereMesh.new()
	mote.radius = 0.018*size
	mote.height = 0.036*size
	mote.radial_segments = 4
	mote.rings = 2
	var mote_material := StandardMaterial3D.new()
	mote_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mote_material.albedo_color = Color(HudIcons.item(id).tint).lightened(0.6)
	mote_material.emission_enabled = true
	mote_material.emission = mote_material.albedo_color
	mote_material.emission_energy_multiplier = 2.0
	mote.material = mote_material
	motes.mesh = mote
	var fade := Curve.new()
	fade.add_point(Vector2(0.0,0.0))
	fade.add_point(Vector2(0.2,1.0))
	fade.add_point(Vector2(1.0,0.0))
	motes.scale_amount_curve = fade
	add_child(motes)

## The turning part (the token in it).
func spin() -> Node3D:
	return _spin

## Lets the motes drift or stills them (far off, where nobody sees them).
func motes_on(on: bool) -> void:
	if motes != null and motes.emitting != on: motes.emitting = on

## Lit for the world's `night` (0 by day, 1 at full night): a little
## brighter than the gallery's by day, a soft lantern after dark.
func glow_for(night: float) -> void:
	if taking: return
	_glow = lerpf(GLOW.x,GLOW.y,night)
	_halo_strength = lerpf(HALO.x,HALO.y,night)
	var token_material := _token.material_override as ShaderMaterial
	token_material.set_shader_parameter("glow",_glow)
	token_material.set_shader_parameter("inner",INNER_NIGHT*night)
	for light in _lights:
		light.set_shader_parameter("glow",_glow)
		light.set_shader_parameter("inner",INNER_NIGHT*night)
	(_halo.material_override as ShaderMaterial).set_shader_parameter("strength",_halo_strength)

func _process(delta: float) -> void:
	if taking: return
	var share := CALM if calm else 1.0
	if turning: _spin.rotation.y += TURN*share*delta
	var t := Time.get_ticks_msec()/1000.0
	if _plummet != null:
		_spin.position.y = sin(t*RUNE_BOB_PACE+phase)*RUNE_BOB
		if turning: RuneToken.swing(_plummet,t,phase)
		return
	_spin.position.y = sin(t*BOB_PACE*(CALM_PACE if calm else 1.0)+phase)*BOB*share

## The pickup: a short twist that winds faster as the token lifts a touch
## and brightens, then, still spinning, it shrinks away into a wisp left in
## `puff_parent` (this holder's parent if null). Returns the tween, so the
## caller can chain what follows; with `free_after` the holder frees itself
## once the wisp is out.
func take(seed_value: int, puff_parent: Node = null, free_after := true) -> Tween:
	taking = true
	set_meta("taking",true)
	var token_material := _token.material_override as ShaderMaterial
	var halo_material := _halo.material_override as ShaderMaterial
	var from_yaw := _spin.rotation.y
	var from_y := _spin.position.y
	# One clock through the twist and the shrink, so the spin never stops:
	# u runs 0 to 1 over the twist and on past 1 while the token shrinks
	# into its wisp, still turning faster and faster.
	var end := 1.0+SHRINK_TIME/SPIN_TIME
	var tween := create_tween()
	tween.tween_method(func(u: float) -> void:
		var k := minf(u,1.0)
		var gone := clampf((u-1.0)/(end-1.0),0.0,1.0)
		_spin.rotation.y = from_yaw+TAU*SPIN_TURNS*u*u
		_spin.position.y = from_y+SPIN_LIFT*size*u
		_spin.scale = Vector3.ONE*maxf(0.01,(1.0+0.08*k)*(1.0-gone*gone))
		_halo.scale = Vector3.ONE*maxf(0.01,1.0-gone)
		token_material.set_shader_parameter("glow",lerpf(_glow,1.6,k*k))
		for light in _lights: light.set_shader_parameter("glow",lerpf(_glow,1.6,k*k))
		halo_material.set_shader_parameter("strength",lerpf(_halo_strength,maxf(0.5,_halo_strength),k*k)),0.0,end,SPIN_TIME+SHRINK_TIME)
	var parent := puff_parent if puff_parent != null else get_parent()
	tween.parallel().tween_callback(func() -> void:
		if parent == null or not is_instance_valid(parent): return
		var puff := GlyphPuff.new()
		puff.size = size
		puff.tint = Color(HudIcons.item(id).tint)
		puff.seed = seed_value
		parent.add_child(puff)
		puff.global_position = _spin.global_position).set_delay(SPIN_TIME)
	if free_after:
		if motes != null: motes.emitting = false
		tween.tween_callback(queue_free)
	return tween
