extends Node3D
## The rune knight's core rune (docs/design/rune-knight/spec-rune-knight.md,
## "The drop"): where he died (his heap on the deck, or where he shattered),
## after RISE_DELAY s it rises out of the stones over RISE s to hang HANG m
## up, turning and glowing (the glyph pickup's look, scripts/glyph_pickup.gd,
## glyph "crystal"), with a light under it. Risen, the wanderer on foot
## walking into it takes it: the pickup's twist, the ledger's objective
## (`objective`, scripts/ledger/ledger.gd `mark_done`) and the isle's
## `knight_rune_taken` (the pop on screen), then it frees itself.
const GlyphPickup = preload("res://scripts/glyph_pickup.gd")
const Lines = preload("res://scripts/collectible_lines.gd")
const Ledger = preload("res://scripts/ledger/ledger.gd")
const Telescope = preload("res://scripts/telescope.gd")
const WindShot = preload("res://scripts/enemies/wind_shot.gd")

const GLYPH := "crystal"
## Across (m), bigger than an isle's tokens (0.7).
const SIZE := 1.3
## The wait before it rises (s, his crumble or shatter first), the rise
## (s), and how high it hangs over where he died (m).
const RISE_DELAY := 1.2
const RISE := 1.8
const HANG := 1.5
const LIGHT := Color(0.62, 0.86, 1.0)

## The ledger's objective it marks.
var objective := ""
## Whether it has risen (only then can it be taken), and taken.
var risen := false
var taken := false
var isle: Node3D = null
var holder: Node3D = null
var light: OmniLight3D = null
## A faint column of light from where he died up through it (reads from
## afar by day), and its material.
var beam: MeshInstance3D = null
var _beam_mat: StandardMaterial3D = null
var _t := 0.0
var _base := Vector3.ZERO

## Laid at `at` (where he died) on `owner_isle`, marking `objective_id`.
func setup(owner_isle: Node3D, at: Vector3, objective_id: String) -> void:
	name = "CoreRune"
	isle = owner_isle
	objective = objective_id
	_base = at
	position = at
	holder = GlyphPickup.make(GLYPH,SIZE,0.0,true)
	holder.name = "Rune"
	holder.scale = Vector3.ONE*0.05
	holder.visible = false
	add_child(holder)
	light = OmniLight3D.new()
	light.light_color = LIGHT
	light.light_energy = 0.0
	light.omni_range = 5.0
	light.shadow_enabled = false
	add_child(light)
	_beam_mat = StandardMaterial3D.new()
	_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beam_mat.albedo_color = Color(LIGHT, 0.0)
	var tube := CylinderMesh.new()
	tube.top_radius = 0.05
	tube.bottom_radius = 0.22
	tube.height = HANG+3.0
	tube.cap_top = false
	tube.cap_bottom = false
	beam = MeshInstance3D.new()
	beam.name = "Beam"
	beam.mesh = tube
	beam.material_override = _beam_mat
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.position = Vector3.UP*(tube.height*0.5)
	add_child(beam)

func _physics_process(delta: float) -> void:
	if taken: return
	_t += delta
	if not risen:
		var u := clampf((_t-RISE_DELAY)/RISE,0.0,1.0)
		if u > 0.0 and not holder.visible:
			holder.visible = true
			holder.motes_on(true)
			print("rune knight: his core rune rises at (%.1f, %.1f, %.1f)" % [_base.x,_base.y,_base.z])
		var e := 1.0-pow(1.0-u,3.0)
		holder.position = Vector3.UP*(0.3+(HANG-0.3)*e)
		holder.scale = Vector3.ONE*lerpf(0.05,1.0,minf(u*1.6,1.0))
		light.position = holder.position
		light.light_energy = 1.6*e
		_beam_mat.albedo_color.a = 0.35*e
		if u >= 1.0:
			risen = true
			Telescope.spottable(holder,objective)
		return
	light.light_energy = 1.4+0.3*sin(_t*2.2)
	_beam_mat.albedo_color.a = 0.3+0.06*sin(_t*2.2)
	var motor = isle.get("motor") if isle != null else null
	if motor == null or motor.get("rider") != null: return
	var chest: Vector3 = (motor.feet as Vector3)+Vector3.UP*0.5*WindShot.walker_tall()
	if chest.distance_to(holder.global_position) < Lines.WALKER_REACH+SIZE*0.5: take()

## Walked into: the twist, the objective marked, the isle's pop.
func take() -> void:
	if taken or not risen: return
	taken = true
	if objective != "": Ledger.shared().mark_done(objective)
	print("rune knight: his core rune is taken (%s)" % objective)
	holder.take(hash(objective) & 0xffff)
	var tween := create_tween()
	tween.tween_property(light,"light_energy",0.0,0.5)
	tween.parallel().tween_property(_beam_mat,"albedo_color:a",0.0,0.5)
	tween.tween_callback(queue_free)
	if isle != null and isle.has_method("knight_rune_taken"): isle.call("knight_rune_taken")
