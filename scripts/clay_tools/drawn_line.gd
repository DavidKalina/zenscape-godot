extends RefCounted
## A line drawn on the land in a shaping tool's Draw mode (the Mountain's
## range, the Crater's lake): the pointer's ground points read from the
## clay's queue while the drag lasts, kept PATH_SPACING apart and smoothed as
## the Ravine's are (scripts/clay_tools/wire.gd `drawn`), so the hand's jitter
## goes and its bends stay. The tool returns false from `drag_frame`, so the
## queue is never laid as dabs and holds the whole stroke.

const Wire = preload("res://scripts/clay_tools/wire.gd")

## The kept points, how many of the clay's queued points have been read, and
## the pointer's last ground point.
var _kept := PackedVector2Array()
var _taken := 0
var _end := Vector2.ZERO

## A stroke begins at plate point `at`.
func begin(at: Vector2) -> void:
	_kept = PackedVector2Array([at])
	_taken = 0
	_end = at

## Forget the stroke.
func clear() -> void:
	_kept = PackedVector2Array()
	_taken = 0

## True while a stroke is being drawn.
func drawing() -> bool:
	return not _kept.is_empty()

## The pointer's last ground point.
func end() -> Vector2:
	return _end

## The pointer's new ground points from `clay`'s queue into the stroke.
func take(clay: Node) -> void:
	if _kept.is_empty(): return
	var queued: PackedVector2Array = clay.queued()
	for k in range(_taken,queued.size()):
		_end = queued[k]
		if _end.distance_to(_kept[-1]) >= Wire.PATH_SPACING: _kept.append(_end)
	_taken = queued.size()

## The stroke so far (plate points, press first, the pointer last), smoothed.
## Empty when none is being drawn.
func path(clay: Node) -> PackedVector2Array:
	if _kept.is_empty(): return PackedVector2Array()
	take(clay)
	var out := _kept.duplicate()
	# The pointer's point ends it: it stands in for a kept point too near it.
	if out.size() > 1 and _end.distance_to(out[-1]) < Wire.PATH_SPACING*0.5: out[-1] = _end
	elif _end.distance_to(out[-1]) > 0.01: out.append(_end)
	for n in Wire.SMOOTH_PASSES:
		var was := out.duplicate()
		for k in range(1,out.size()-1): out[k] = was[k]*0.5+(was[k-1]+was[k+1])*0.25
	return out
