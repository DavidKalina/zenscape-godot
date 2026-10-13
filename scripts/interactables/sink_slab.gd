extends "res://scripts/interactables/foot_slab.gd"
## A sinking slab (docs/design/roguelike/crossing-viaduct-perches.md): one of
## the floating stones (scripts/interactables/foot_slab.gd, its look, its
## sag and tilt under his weight, a slam's shove), that gives way while he
## stands on it. After WAIT s stood on, it sinks RATE m/s, down to MOST m;
## let go of, it rises back RISE m/s to where it hung. Stand on it and it
## takes you down with it (scripts/interactables/foot_pieces.gd carries
## him): don't dawdle.

const WAIT := 0.25
const RATE := 0.7
const MOST := 6.0
const RISE := 1.2

## How far it has sunk (m) and how long he has stood on it (s).
var sunk := 0.0
var stood := 0.0

func _ready() -> void:
	super._ready()
	sink = 0.12
	tilt = 0.06
	give = 0.05
	hz = 1.6
	damp = 0.45

func advance(delta: float) -> void:
	if delta <= 0.0: return
	# `_load` is where he stood last frame (INF none); the base reads and
	# clears it.
	if _load != Vector3.INF:
		stood += delta
		if stood > WAIT: sunk = minf(sunk+RATE*delta,MOST)
	else:
		stood = 0.0
		sunk = maxf(sunk-RISE*delta,0.0)
	super.advance(delta)

## Its pose: where it hung, sunk.
func pose_at(_t: float) -> Transform3D:
	return Transform3D(rest.basis,rest.origin-Vector3.UP*sunk)
