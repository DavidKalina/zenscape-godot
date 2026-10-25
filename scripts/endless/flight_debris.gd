extends Node3D
## What flies off when the plane meets the land or nearly does (scripts/
## endless/near_miss.gd, flight_contact.gd): small one-shot bursts of
## particles, each kind a pair of CPU emitters taken in turn.
## - dust: earth kicked up by a scrape on the land or a crash.
## - sparks: off stone (an arch, a hall, a bore's rock).
## - leaves: off a tree grazed or scraped.
## - spray: off the water, as a burst on a scrape, and a running trail
##   (`spray`) while it skims the water low and fast.

const KINDS := {
	"dust":{"color":Color(0.55,0.47,0.36),"amount":28,"size":0.55,"speed":Vector2(3.0,8.0),"gravity":-6.0,"life":1.1,"spread":55.0,"damp":2.0},
	"sparks":{"color":Color(1.0,0.78,0.42),"amount":24,"size":0.12,"speed":Vector2(8.0,16.0),"gravity":-9.8,"life":0.45,"spread":70.0,"damp":0.5},
	"leaves":{"color":Color(0.33,0.5,0.24),"amount":22,"size":0.3,"speed":Vector2(2.0,6.0),"gravity":-2.0,"life":1.6,"spread":80.0,"damp":2.5},
	"spray":{"color":Color(0.88,0.94,0.97),"amount":30,"size":0.45,"speed":Vector2(3.0,9.0),"gravity":-9.0,"life":0.9,"spread":40.0,"damp":1.0},
}
## A crash's burst is this many times a scrape's in size and speed.
const CRASH := 2.2

var _pools := {}
var _turn := {}
var _trail: CPUParticles3D

func _ready() -> void:
	for kind: String in KINDS:
		_pools[kind] = [_emitter(KINDS[kind],true),_emitter(KINDS[kind],true)]
		_turn[kind] = 0
	_trail = _emitter(KINDS.spray,false)
	_trail.amount = 40
	_trail.lifetime = 0.7
	_trail.explosiveness = 0.0

func _emitter(k: Dictionary, one_shot: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = one_shot
	p.emitting = false
	p.amount = int(k.amount)
	p.lifetime = float(k.life)
	p.explosiveness = 0.92
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = float(k.spread)
	p.initial_velocity_min = (k.speed as Vector2).x
	p.initial_velocity_max = (k.speed as Vector2).y
	p.gravity = Vector3(0.0,float(k.gravity),0.0)
	p.damping_min = float(k.damp)
	p.damping_max = float(k.damp)*1.5
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	p.angle_min = 0.0
	p.angle_max = 360.0
	var fade := Gradient.new()
	fade.set_color(0,Color(1,1,1,1))
	fade.set_color(1,Color(1,1,1,0))
	p.color_ramp = fade
	p.color = k.color
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE*float(k.size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = m
	p.mesh = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p

## A burst of `kind` at `at` thrown out along `normal`; `crash` a big one.
func burst(kind: String, at: Vector3, normal: Vector3, crash := false) -> void:
	if not _pools.has(kind): return
	var pool: Array = _pools[kind]
	var i: int = _turn[kind]
	_turn[kind] = (i+1)%pool.size()
	var p: CPUParticles3D = pool[i]
	var k: Dictionary = KINDS[kind]
	var big := CRASH if crash else 1.0
	p.initial_velocity_min = (k.speed as Vector2).x*big
	p.initial_velocity_max = (k.speed as Vector2).y*big
	p.scale_amount_max = 1.3*big
	p.global_position = at
	p.direction = normal if normal.length() > 0.1 else Vector3.UP
	p.restart()
	p.emitting = true

## The burst for a surface (land, water, tree, stone): dust, spray, leaves
## (and dust), sparks (and dust).
func hit(what: String, at: Vector3, normal: Vector3, crash := false) -> void:
	match what:
		"water": burst("spray",at,normal,crash)
		"tree":
			burst("leaves",at,normal,crash)
			if crash: burst("dust",at,normal,true)
		"stone":
			burst("sparks",at,normal,crash)
			burst("dust",at,normal,crash)
		_: burst("dust",at,normal,crash)

## The running spray at `at` (on the water under the plane), `on` or off.
func spray(on: bool, at: Vector3, way: Vector3) -> void:
	_trail.emitting = on
	if not on: return
	_trail.global_position = at
	_trail.direction = (Vector3.UP*1.5-way.normalized()).normalized()
