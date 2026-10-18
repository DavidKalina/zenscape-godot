extends Node3D
## The Olmec's rune (docs/design/olmec-boss/spec-olmec-knockoff.md, "the
## third knock-off ends him"): the kit caches' break-to-find
## (scripts/kit_isle/kit_caches.gd), bigger. He crumbles at the top of the
## rim; out of the break in his heap:
##
## - **The seam.** SEAM_AT s after he falls apart, light grows in the heap's
##   middle (flickering, a column of it up out of the stones) and chips
##   spurt out of it, faster and faster, for SEAM s.
## - **The burst.** A flash, a spray of chips and dust, and the rune comes
##   up out of the seam (SIZE across, twice a cache's find): RISE s up to
##   TOP m over the seam, overshooting a little.
## - **The settle.** Then it drifts DRIFT s in from the rim (STEP_IN m
##   toward the field's middle, out of the rubble) and down to hover HOVER
##   m over the turf, turning, its light breathing.
## - **Taken.** The wanderer's middle within reach (the caches' reach) takes
##   it: the pickup's twist, the light out, `taken` emitted.
##
## Use: `setup(at, inward, motor, sounds)` with `at` his feet (world),
## `inward` flat toward the field's middle, `sounds` a node with
## `sound(name, at)` (his `field`) or null; add it to the field.
const GlyphPickup = preload("res://scripts/glyph_pickup.gd")
const Lines = preload("res://scripts/collectible_lines.gd")
const Dust = preload("res://scripts/enemies/body_dust.gd")
const KitCaches = preload("res://scripts/kit_isle/kit_caches.gd")

signal taken

const GLYPH := "rune"
## Across (m): twice a cache's find (kit_caches SIZE 0.7).
const SIZE := KitCaches.SIZE*2.0
## The seam: s after the crumble it starts, s it glows and spurts before
## the burst, its height over his feet (m), and s between spurts (first,
## last).
const SEAM_AT := 0.6
const SEAM := 1.4
const SEAM_UP := 1.1
const SPURT := Vector2(0.28,0.07)
## The rise: s, m over the seam, overshoot (share of the rise).
const RISE := 1.3
const TOP := 3.2
const OVERSHOOT := 0.1
## The settle: s, m in from his heap, m over the turf.
const DRIFT := 1.8
const STEP_IN := 4.5
const HOVER := 1.25
## Room (m) kept clear of rubble round where it settles.
const CLEAR := 1.6
## The light: colour (the rune's pale cyan), its most in the seam, the
## flash, and its breath once settled; reach (m).
const LIGHT := KitCaches.TINT
const SEAM_LIGHT := 3.0
const FLASH := 9.0
const REST_LIGHT := Vector2(1.3,1.8)
const REACH := 9.0
## The column out of the seam: m tall, radius at its foot.
const BEAM := 7.0
const BEAM_FOOT := 0.55

## "wait", "seam", "rise", "drift", "up", "taken".
var state := "wait"
var holder: Node3D = null
var light: OmniLight3D = null
var beam: MeshInstance3D = null
var motor: Object = null
var sounds: Node = null
var seam := Vector3.ZERO
var rest := Vector3.ZERO
var _t := 0.0
var _spurt_t := 0.0
var _flash := 0.0
var _beam_mat: StandardMaterial3D = null
var _top := Vector3.ZERO
var _inward := Vector3.FORWARD

func setup(at: Vector3, inward: Vector3, walker: Object, sound_node: Node = null) -> void:
	name = "OlmecRune"
	motor = walker
	sounds = sound_node
	seam = at+Vector3.UP*SEAM_UP
	var flat := Vector3(inward.x,0.0,inward.z)
	if flat.length() < 0.01: flat = Vector3.FORWARD
	rest = at+flat.normalized()*STEP_IN
	_top = seam+Vector3.UP*TOP

func _ready() -> void:
	holder = GlyphPickup.make(GLYPH,SIZE,randf()*TAU,true)
	holder.name = "Rune"
	holder.visible = false
	add_child(holder)
	holder.global_position = seam
	holder.scale = Vector3.ONE*0.05
	light = OmniLight3D.new()
	light.light_color = LIGHT
	light.light_energy = 0.0
	light.omni_range = REACH
	light.shadow_enabled = false
	add_child(light)
	light.global_position = seam
	_beam_mat = StandardMaterial3D.new()
	_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beam_mat.albedo_color = Color(LIGHT,0.0)
	var tube := CylinderMesh.new()
	tube.top_radius = 0.08
	tube.bottom_radius = BEAM_FOOT
	tube.height = BEAM
	tube.cap_top = false
	tube.cap_bottom = false
	beam = MeshInstance3D.new()
	beam.name = "Beam"
	beam.mesh = tube
	beam.material_override = _beam_mat
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)
	beam.global_position = seam+Vector3.UP*(BEAM*0.5-0.3)
	_inward = (rest-seam)*Vector3(1.0,0.0,1.0)
	_inward = _inward.normalized()
	rest = _settle_spot()

## Where it settles: STEP_IN m in from the heap, or farther in or a little
## aside, the first spot with no rubble within CLEAR m (his blocks, the
## arm's), HOVER over the turf there.
func _settle_spot() -> Vector3:
	var foot := seam-Vector3.UP*SEAM_UP
	var best := foot+_inward*STEP_IN
	for step: float in [STEP_IN,STEP_IN+1.5,STEP_IN+3.0,STEP_IN+4.5]:
		for turn: float in [0.0,0.45,-0.45,0.9,-0.9]:
			var p := foot+_inward.rotated(Vector3.UP,turn)*step
			p.y = _ground(p)
			if _clear(p):
				return p+Vector3.UP*HOVER
	best.y = _ground(best)+HOVER
	return best

func _ground(p: Vector3) -> float:
	if not is_inside_tree(): return p.y
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x,seam.y+6.0,p.z),Vector3(p.x,seam.y-12.0,p.z))
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return (hit.position as Vector3).y if not hit.is_empty() else p.y

## No rubble (a RigidBody3D) within CLEAR m of `p` (its turf point).
func _clear(p: Vector3) -> bool:
	if not is_inside_tree(): return true
	var ball := SphereShape3D.new()
	ball.radius = CLEAR
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = ball
	q.transform = Transform3D(Basis.IDENTITY,p+Vector3.UP*(CLEAR*0.6))
	for hit: Dictionary in get_world_3d().direct_space_state.intersect_shape(q,16):
		if hit.collider is RigidBody3D: return false
	return true

func takeable() -> bool:
	return state == "up"

func _process(delta: float) -> void:
	if state == "taken": return
	_t += delta
	_flash = maxf(_flash-delta*FLASH*1.4,0.0)
	match state:
		"wait":
			if _t >= SEAM_AT: _go("seam")
		"seam": _seam(delta)
		"rise": _rise()
		"drift": _drift()
		"up": _up()

func _go(to: String) -> void:
	state = to
	_t = 0.0
	print("olmec rune: %s" % to)

## Light grows in the break, chips spurt out of it, faster and faster.
func _seam(delta: float) -> void:
	var u := clampf(_t/SEAM,0.0,1.0)
	var flicker := 0.75+0.25*sin(_t*37.0)*sin(_t*23.0+1.0)
	light.light_energy = SEAM_LIGHT*u*u*flicker
	_beam_mat.albedo_color.a = 0.32*u*flicker
	beam.scale = Vector3(0.4+0.6*u,1.0,0.4+0.6*u)
	_spurt_t -= delta
	if _spurt_t <= 0.0:
		_spurt_t = lerpf(SPURT.x,SPURT.y,u)
		var a := randf()*TAU
		Dust.rocks(get_parent(),seam,Vector3(cos(a),1.2,sin(a)),3+int(u*4.0),0.1)
		if randf() < 0.4: Dust.puff(get_parent(),seam,0.5+u)
		if sounds != null and randf() < 0.35: sounds.sound(&"ruin_crack",seam)
	if u >= 1.0: _burst()

## The flash and the spray, and the rune comes up.
func _burst() -> void:
	_flash = FLASH
	Dust.rocks(get_parent(),seam,Vector3.UP,24,0.16)
	Dust.plume(get_parent(),seam-Vector3.UP*SEAM_UP,2.2)
	if sounds != null:
		sounds.sound(&"ruin_crack",seam)
		sounds.sound(&"body_rumble",seam)
	holder.visible = true
	holder.motes_on(true)
	print("olmec rune: bursts out of his heap at (%.1f, %.1f, %.1f)" % [seam.x,seam.y,seam.z])
	_go("rise")

func _rise() -> void:
	var u := clampf(_t/RISE,0.0,1.0)
	# Out fast, past the top a touch, back to it.
	var e := 1.0-pow(1.0-u,3.0)
	var over := sin(u*PI)*OVERSHOOT*u
	holder.global_position = seam.lerp(_top,e+over)
	holder.scale = Vector3.ONE*lerpf(0.05,1.0,minf(u*2.2,1.0))
	light.global_position = holder.global_position
	light.light_energy = REST_LIGHT.y+_flash
	_beam_mat.albedo_color.a = 0.32*(1.0-u*0.4)
	if u >= 1.0:
		rest = _settle_spot()
		_go("drift")

func _drift() -> void:
	var u := clampf(_t/DRIFT,0.0,1.0)
	var e := u*u*(3.0-2.0*u)
	var p := _top.lerp(rest,e)
	# A soft arc: up a little as it goes, then down onto its hover.
	p.y += sin(u*PI)*0.6
	holder.global_position = p
	light.global_position = p
	light.light_energy = REST_LIGHT.y+_flash
	_beam_mat.albedo_color.a = 0.19*(1.0-e)
	if u >= 1.0:
		beam.visible = false
		_go("up")

func _up() -> void:
	light.light_energy = lerpf(REST_LIGHT.x,REST_LIGHT.y,0.5+0.5*sin(_t*2.2))
	if motor == null or not is_instance_valid(motor): return
	if motor.get("rider") != null: return
	var feet: Vector3 = motor.get("feet")
	if (feet+Vector3.UP*Lines.FOOT_Y).distance_to(holder.global_position) < Lines.WALKER_REACH+SIZE*0.5: take()

## Walked into: the twist, the light out.
func take() -> void:
	if state != "up": return
	state = "taken"
	print("olmec rune: taken")
	holder.take(hash("olmec_rune") & 0xffff,get_parent())
	var tween := create_tween()
	tween.tween_property(light,"light_energy",0.0,0.6)
	tween.tween_callback(queue_free)
	taken.emit()
