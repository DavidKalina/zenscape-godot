extends RefCounted
## The Olmec's ears for the layer's noise: a headless body or a whole Olmec
## (scripts/enemies/headless_body.gd) hears what is made on the NoiseBus
## (scripts/noise/noise_bus.gd) and goes to look, as at a weaker, fading
## beacon. It is one: a `Lure`, a Beacon only its own body heeds (in no
## group, lighting nothing), set where the noise was. The body's beacon
## machinery does the rest: it stops and listens (the tell), turns to it,
## routes there, stands looking `noise_dwell` s, then tires of it.
##
## Its place among the body's wants: below a lit beacon (and so below its
## head in sight or calling, and below him seen, whole), above roaming and
## its head heard but not calling (`_beacons` in the body).
##
## Heard: a noise of loudness L reaches it within L x `hear_noise` m of its
## middle, x `noise_wall` with stone between; how well, 1 at the point
## falling to 0 at the edge. A louder (better heard) noise takes over from
## the one it is going to, which fades over `noise_memory` s; forgotten
## then, it goes back to what it was doing. A noise more than NEWS m from
## the one it heeds (or after it tired of looking) is news: it stops and
## listens again. Nearer, the place it goes moves quietly.
##
## Never heard: its own noises, another body's (a body's landing shakes the
## ground for everyone, but no Olmec goes to another's: an urn that relays
## it makes it its own), and its breaker's crashes near it (what it broke).
##
## Knobs (the body's, `--body-knob=`): `hearing` 1 on / 0 deaf;
## `hear_noise` (1.0) its ears' reach, x every loudness; `noise_memory`
## (15 s); `noise_dwell` (4 s, looking there); `noise_wall` (0.6).

const Dust = preload("res://scripts/enemies/body_dust.gd")

## A noise's place, as a beacon only its body heeds.
class Lure extends Beacon:
	const LURES := &"noise_lures"
	## Heeded now (a heard noise not yet looked at or forgotten).
	var active := false
	func _enter_tree() -> void:
		# Not a SightLight (lights nothing) nor a Beacon (draws no one else).
		add_to_group(LURES)

## A noise this far (m) from the one heeded is news (it listens again).
const NEWS := 6.0
## A noise older than this (s) when it first polls is not news (made
## before it was there to hear it).
const STALE := 1.0
## How much a noise is mis-placed (m) at the edge of hearing (none at 1).
const BLUR := 5.0

var lure: Lure = null
## Noises heard, and those that turned it (news).
var heard := 0
var turns := 0
## The noise it heeds (a NoiseBus.Sound), or null.
var noise: Object = null
var _s := 0.0
var _at := 0.0
var _last_id := 0
var _news := false
var _ray := PhysicsRayQueryParameters3D.new()
var _rng := RandomNumberGenerator.new()

## Every poll (the body's BEACON_POLL): the noises made since, heard or
## not; returns its lure while it heeds one (nothing higher decides that:
## the body's `_beacons` does), else null.
func pick(body: Node3D) -> Beacon:
	var knobs: Dictionary = body.knobs
	if float(knobs.get("hearing",1)) < 0.5 or not body.is_inside_tree(): return null
	var bus := NoiseBus.of(body.get_tree())
	if bus == null: return null
	if lure == null or not is_instance_valid(lure):
		lure = Lure.new()
		lure.name = "HeardNoise"
		lure.top_level = true
		lure.strength = 0.0
		lure.radius = 0.0
		lure.draw = 1.0
		_rng.seed = hash(body.get_instance_id())
		body.add_child(lure)
	lure.dwell = float(knobs.get("noise_dwell",4.0))
	lure.gather = 2.0
	var memory := float(knobs.get("noise_memory",15.0))
	var ear: Vector3 = body.position+Vector3.UP*float(body.neck_h)*0.5
	var k := float(knobs.get("hear_noise",1.0))
	for n: NoiseBus.Sound in bus.since(_last_id):
		_last_id = n.id
		if bus.clock-n.time > STALE or _deaf_to(body,n): continue
		var s := n.heard_at(ear,k)
		if s <= 0.0: continue
		if _walled(body,n.position,ear):
			s = n.heard_at(ear,k*float(knobs.get("noise_wall",0.6)))
			if s <= 0.0: continue
		heard += 1
		if lure.active and s <= _strength(bus.clock,memory): continue
		_take(body,n,s,bus.clock)
	if lure.active and (bus.clock-_at > memory or body._tired_of(lure)):
		lure.active = false
		noise = null
	return lure if lure.active else null

## Whether `b` (its beacon) is its lure, freshly news: once, then false.
func news(b: Beacon) -> bool:
	if b != lure or not _news: return false
	_news = false
	return true

func is_lure(b: Object) -> bool:
	return b != null and b == lure

## The tell, as it turns to a noise: a sift of dust off its shoulders and
## its listening voice (it stops, then turns its stump to it: `listen`).
func tell(body: Node3D) -> void:
	turns += 1
	var field: Node = body.field
	if field == null: return
	field.sound(&"body_heard",body.position)
	var hh: float = body.hh
	var right := Vector3(cos(body.facing),0.0,-sin(body.facing))
	for side: float in [-1.0,1.0]:
		Dust.puff(field,body.position+Vector3.UP*float(body.neck_h)*0.92+right*side*float(body.width)*0.4,hh*0.35,right*side)

## Where it heard the noise it heeds (INF: none).
func heard_at() -> Vector3:
	return lure.global_position if lure != null and lure.active else Vector3.INF

func _strength(clock: float, memory: float) -> float:
	return _s*clampf(1.0-(clock-_at)/maxf(memory,0.01),0.0,1.0)

func _take(body: Node3D, n: NoiseBus.Sound, s: float, clock: float) -> void:
	var blur := BLUR*(1.0-s)
	var a := _rng.randf()*TAU
	var at := n.position+Vector3(sin(a),0.0,cos(a))*blur*_rng.randf()
	var tired: bool = body._tired_of(lure)
	if not lure.active or tired or Vector2(at.x-lure.global_position.x,at.z-lure.global_position.z).length() > NEWS:
		_news = true
		lure.lit = false
		lure.lit = true
	lure.global_position = at
	lure.active = true
	noise = n
	_s = s
	_at = clock

func _deaf_to(body: Node3D, n: NoiseBus.Sound) -> bool:
	var src: Object = n.source
	if src == null or not is_instance_valid(src): return false
	if src == body or src == body.get("head"): return true
	if src is Node and (src as Node).get_script() == body.get_script(): return true
	var breaker: Object = body.get("breaker")
	if breaker != null and src == breaker and n.position.distance_to(body.position) < float(body.length)*3.0: return true
	return false

## Stone between the noise and its ear.
func _walled(body: Node3D, from: Vector3, ear: Vector3) -> bool:
	var field: Node = body.field
	if field == null or field.study == null: return false
	_ray.from = from+Vector3.UP*0.5
	_ray.to = ear
	_ray.collision_mask = WalkerOnly.strip(field.study.ground.mask)
	_ray.exclude = body._skip()
	return not body.get_world_3d().direct_space_state.intersect_ray(_ray).is_empty()
