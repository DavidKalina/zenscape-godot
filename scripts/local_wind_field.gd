class_name LocalWindField
extends Node
## Shared air velocity in metres/second. The owner advances this on its simulation
## clock, so pause and deterministic capture pause CPU and GPU gusts together.
## Eight slots keep shader work bounded; a ninth gust replaces the oldest.
## Calibrate mean physical ambient velocity from atmosphere strength * its gust_at
## envelope * 3 m/s, along its smoothed direction. Source noise/advection remains
## artistic foliage flutter; advection speed is not air force (zero dial = calm).
signal updated
const CAPACITY := 8
var ambient_velocity := Vector3.ZERO
var _gusts: Array[Dictionary] = []
var _next_id := 1
var _published := false

## A `quiet` gust moves what it reaches but draws no streaks
## (scripts/wind_gust_visuals.gd): a songbird shaking its tree's crown.
func emit_gust(origin: Vector3, direction: Vector3, strength: float, radius: float, duration: float, quiet := false) -> int:
	if not origin.is_finite() or not direction.is_finite() or direction.length_squared() < 0.000001:
		return -1
	if not is_finite(strength) or not is_finite(radius) or not is_finite(duration) or strength <= 0.0 or radius <= 0.0 or duration <= 0.0:
		return -1
	var id := _next_id
	_next_id += 1
	if _gusts.size() == CAPACITY:
		_gusts.pop_front()
	_gusts.append({"id": id, "origin": origin, "direction": direction.normalized(), "strength": strength, "radius": radius, "duration": duration, "age": 0.0, "quiet": quiet})
	publish()
	return id

## A steered gust (scripts/wind_gust.gd): its owner moves it and sets its
## strength each frame with `steer`, so it has no envelope of its own and
## never ages out; `let_go` ends it. Returns its id, or -1. Like any gust, a
## ninth replaces the oldest, so `steer` returns false once it is gone. It is
## never published to shaders: it is for what samples the field on the CPU
## (leaf litter, the resident's body). Shaders take the wind tool's own air.
func emit_steered(origin: Vector3, direction: Vector3, strength: float, radius: float) -> int:
	if not origin.is_finite() or not direction.is_finite() or direction.length_squared() < 0.000001 or not is_finite(radius) or radius <= 0.0:
		return -1
	var id := _next_id
	_next_id += 1
	if _gusts.size() == CAPACITY:
		_gusts.pop_front()
	_gusts.append({"id": id, "origin": origin, "direction": direction.normalized(), "strength": maxf(strength, 0.0), "radius": radius, "duration": 1.0e9, "age": 0.0, "steered": true})
	return id

func steer(id: int, origin: Vector3, direction: Vector3, strength: float, radius: float) -> bool:
	for gust: Dictionary in _gusts:
		if gust.id != id:
			continue
		if origin.is_finite(): gust.origin = origin
		if direction.length_squared() > 0.000001: gust.direction = direction.normalized()
		gust.strength = maxf(strength, 0.0) if is_finite(strength) else 0.0
		gust.radius = maxf(radius, 0.01)
		return true
	return false

func let_go(id: int) -> void:
	for i in range(_gusts.size()):
		if _gusts[i].id == id:
			_gusts.remove_at(i)
			publish()
			return

## A gust's share of its strength now: the envelope, or all of it steered.
static func weight_of(gust: Dictionary) -> float:
	return 1.0 if gust.get("steered", false) else envelope(gust.age, gust.duration)

static func envelope(age: float, duration: float) -> float:
	var phase := clampf(age / duration, 0.0, 1.0)
	return smoothstep(0.0, 0.15, phase) * (1.0 - smoothstep(0.35, 1.0, phase))

func sample_local(position: Vector3) -> Vector3:
	if not position.is_finite():
		return Vector3.ZERO
	var velocity := Vector3.ZERO
	for gust: Dictionary in _gusts:
		var distance: float = position.distance_to(gust.origin) / gust.radius
		var weight := 1.0 - smoothstep(0.0, 1.0, distance)
		velocity += gust.direction * gust.strength * weight_of(gust) * weight
	return velocity

func sample(position: Vector3) -> Vector3:
	return (ambient_velocity if ambient_velocity.is_finite() else Vector3.ZERO) + sample_local(position)

func advance(delta: float) -> void:
	if not is_finite(delta) or delta < 0.0:
		return
	for i in range(_gusts.size() - 1, -1, -1):
		_gusts[i].age += delta
		if _gusts[i].age >= _gusts[i].duration:
			_gusts.remove_at(i)
	publish()

func publish() -> void:
	_published = true
	RenderingServer.global_shader_parameter_set("zs_local_ambient_velocity", ambient_velocity if ambient_velocity.is_finite() else Vector3.ZERO)
	# Steered gusts stay on the CPU (leaf litter, the resident's body): the
	# wind tool gives shaders its own air (zs_blow_*, scripts/wind_gust.gd).
	var shown: Array[Dictionary] = []
	for gust: Dictionary in _gusts:
		if not gust.get("steered", false): shown.append(gust)
	for i in range(CAPACITY):
		var origin := Vector4.ZERO
		var vector := Vector4.ZERO
		if i < shown.size():
			var gust: Dictionary = shown[i]
			origin = Vector4(gust.origin.x, gust.origin.y, gust.origin.z, gust.radius)
			vector = Vector4(gust.direction.x, gust.direction.y, gust.direction.z, gust.strength * weight_of(gust))
		RenderingServer.global_shader_parameter_set("zs_local_gust_origin_%d" % i, origin)
		RenderingServer.global_shader_parameter_set("zs_local_gust_vector_%d" % i, vector)

	updated.emit()

func clear() -> void:
	_gusts.clear()
	publish()

func _exit_tree() -> void:
	if _published:
		ambient_velocity = Vector3.ZERO
		clear()
