extends Node3D
## The rune knight's landing (docs/design/rune-knight/spec-rune-knight.md,
## "The leap"): a ring of dust and wind off the ground where he comes down.
## Set by the knight (scripts/enemies/rune_knight.gd `_launch`) at his
## landing as he leaves the ground, `eta` counted down by him; at `touch`
## (his touchdown) the wanderer within `reach` m (flat) and within his
## height of it is knocked out from its middle (the gust's knock,
## scripts/traps/gust.gd), and the ring of dust and wind runs out.
##
## A wind shot in every other way: in the "wind_shot" group with the parry's
## seam (`parry_eta`, `absorb`; scripts/wind_parry.gd), so a press timed to
## the touchdown parries it (its `shooter` told: he reels as he lands). Its
## `state` is "pending", never "flying", so nothing catches, strikes or
## meets it in the air.
const Gust = preload("res://scripts/traps/gust.gd")
const BodyDust = preload("res://scripts/enemies/body_dust.gd")

const GROUP := "wind_shot"
## The ring's run out (s) and its band's width (share of its radius).
const RUN := 0.4
const BAND := 0.18
const TINT := Color(0.84,0.94,1.0)

var shooter: Object = null
var target: Object = null
var strength := 0.8
var reach := 4.0
var tall := 3.0
## s till the touchdown (set by the knight each frame of the leap).
var eta := INF
## "pending" (he's in the air), "done" (touched or parried).
var state := "pending"
var form := "ring"
var velocity := Vector3.ZERO
var knocked := false
var _t := -1.0
var _ring: MeshInstance3D
var _mat: StandardMaterial3D

func _init() -> void:
	name = "LeapRing"
	add_to_group(GROUP)

## The parry seam: s till it reaches `motor` where he stands (the
## touchdown, if he is within reach), -1 if it won't or past `horizon`.
func parry_eta(motor: Object, horizon: float, slack := 0.0) -> float:
	if state != "pending" or motor == null or eta > horizon: return -1.0
	return eta if _within(motor,slack) else -1.0

func absorb() -> void:
	if state != "pending": return
	state = "done"
	print("leap ring: parried")
	queue_free()

func _within(motor: Object, slack := 0.0) -> bool:
	var feet: Vector3 = motor.feet
	var p := global_position
	return Vector2(feet.x-p.x,feet.z-p.z).length() <= reach+slack and absf(feet.y-p.y) < tall

## The touchdown: the dust and wind run out; the wanderer in reach knocked.
func touch() -> void:
	if state != "pending": return
	state = "done"
	var p := global_position
	BodyDust.plume(get_parent(),p,reach*0.7)
	_build()
	_t = 0.0
	var motor = target
	if motor != null and is_instance_valid(motor) and Gust.can_take(motor) and _within(motor):
		var feet: Vector3 = motor.feet
		var way := Vector3(feet.x-p.x,0.0,feet.z-p.z)
		if way.length() < 0.1: way = Vector3.FORWARD
		var k := Gust.wanderer_defaults()
		var mult := float(motor.get_meta("knock_mult",1.0))
		var v := Gust.knock(motor,way,float(k.blast_out)*strength*mult,float(k.blast_up)*strength*mult,shooter if shooter != null else self)
		knocked = true
		print("leap ring: knocks the wanderer at (%.1f, %.1f, %.1f), (%.1f, %.1f, %.1f) m/s" % [feet.x,feet.y,feet.z,v.x,v.y,v.z])

func _build() -> void:
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.0-BAND
	torus.outer_radius = 1.0
	torus.rings = 48
	torus.ring_segments = 6
	_ring.mesh = torus
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.albedo_color = TINT
	_ring.material_override = _mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	_ring.position = Vector3.UP*0.25

func _process(delta: float) -> void:
	if _t < 0.0: return
	_t += delta
	var u := clampf(_t/RUN,0.0,1.0)
	var r := lerpf(0.4,reach,1.0-pow(1.0-u,3.0))
	_ring.scale = Vector3(r,r*0.6,r)
	_mat.albedo_color.a = 0.75*(1.0-u)
	if u >= 1.0: queue_free()
