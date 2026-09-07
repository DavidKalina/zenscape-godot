extends RefCounted
## Source tremor.js trauma curve and deterministic camera-local displacement.
var trauma := 0.0
var clock := 0.0
var enabled := true

func add(magnitude: float) -> void:
	if enabled:
		trauma = clampf(trauma + magnitude, 0.0, 1.0)

func advance(delta: float, paused: bool) -> void:
	if not paused:
		clock += delta
		trauma = maxf(0.0, trauma - delta * 0.7)

func _wob(frequency: float, phase: float) -> float:
	return sin(clock * frequency + phase) * 0.65 + sin(clock * frequency * 1.618 + phase * 2.3) * 0.35

func apply(base: Transform3D) -> Transform3D:
	if not enabled or trauma <= 0.0001:
		return base
	var strength := trauma * trauma
	var angles := Vector3(0.007 * strength * _wob(17.3, 1.7), 0.006 * strength * _wob(13.1, 4.2), 0.016 * strength * _wob(11.7, 0.3))
	var result := base
	result.basis = base.basis * Basis.from_euler(angles, EULER_ORDER_XYZ)
	result.origin += base.basis.x * 0.09 * strength * _wob(15.9, 2.9) + base.basis.y * 0.09 * strength * _wob(19.4, 5.5)
	return result
