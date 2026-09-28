extends RefCounted
## Source tremor.js trauma curve and deterministic camera-local displacement.
signal shaken(strength: float)
var trauma := 0.0
var clock := 0.0
var enabled := true
## A held rolling rumble (scripts/world_rumble.gd owns it): a displacement
## strength 0..1 on its own clock, slower and rounder than trauma's shake. It
## never decays here and never emits `shaken`, so creatures do not stumble.
var rumble := 0.0
var rumble_clock := 0.0
## The diorama jiggling in the hand (scripts/snow_globe.gd owns it): how far
## the world is moved on screen, metres along the camera's right and up (x, y),
## and how far it is rolled about the view, radians (z). The camera moves the
## other way, so the whole world moves together and nothing in it is touched.
## Held as given: it never decays here and never emits `shaken`.
var jiggle := Vector3.ZERO

func add(magnitude: float) -> void:
	if enabled and is_finite(magnitude) and magnitude>0.0:
		trauma = clampf(trauma + magnitude, 0.0, 1.0)
		shaken.emit(clampf(magnitude,0.0,1.0))

func advance(delta: float, paused: bool) -> void:
	if not paused:
		clock += delta
		trauma = maxf(0.0, trauma - delta * 0.7)

func _wob(frequency: float, phase: float) -> float:
	return sin(clock * frequency + phase) * 0.65 + sin(clock * frequency * 1.618 + phase * 2.3) * 0.35

## Rolling heave with a little grit on top.
func _roll(frequency: float, phase: float) -> float:
	var t := rumble_clock
	return sin(t * frequency + phase) * 0.55 + sin(t * frequency * 1.73 + phase * 1.9) * 0.3 + sin(t * frequency * 4.1 + phase * 3.1) * 0.15

func apply(base: Transform3D) -> Transform3D:
	if jiggle != Vector3.ZERO:
		base.origin -= base.basis.x*jiggle.x+base.basis.y*jiggle.y
		base.basis = base.basis*Basis(Vector3.BACK,-jiggle.z)
	if not enabled or (trauma <= 0.0001 and rumble <= 0.0001):
		return base
	var strength := trauma * trauma
	var angles := Vector3(0.007 * strength * _wob(17.3, 1.7), 0.006 * strength * _wob(13.1, 4.2), 0.016 * strength * _wob(11.7, 0.3))
	var shift := base.basis.x * 0.09 * strength * _wob(15.9, 2.9) + base.basis.y * 0.09 * strength * _wob(19.4, 5.5)
	if rumble > 0.0001:
		angles += Vector3(0.006 * rumble * _roll(7.3, 0.9), 0.004 * rumble * _roll(5.9, 2.6), 0.011 * rumble * _roll(4.7, 4.4))
		shift += base.basis.y * 0.07 * rumble * _roll(8.8, 1.3)
	var result := base
	result.basis = base.basis * Basis.from_euler(angles, EULER_ORDER_XYZ)
	result.origin += shift
	return result
