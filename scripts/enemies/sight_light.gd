class_name SightLight
extends Node3D
## A light the Olmec's sight reckons with (docs/design/roguelike/
## beacons-light-sight-round1.md): a fire, a lamp, a lit stripe. Not a
## renderer light: a point, a reach and a strength, read by
## scripts/enemies/light_level.gd to tell how lit the wanderer stands (no
## GPU readback). Add one beside the piece's OmniLight3D (or anywhere), set
## `lit`; it joins the group GROUP while in the tree.
##
## The light it casts at a point `d` m off: `strength` within `radius` x
## FULL, falling straight to 0 at `radius`. No occlusion: it lights through
## walls (a limit of round 1).

signal lit_changed(on: bool)

const GROUP := &"sight_lights"
## Full strength within this share of `radius`.
const FULL := 0.4

## How bright, on the ambient's scale (1 lights him as daylight would).
@export var strength := 1.0
## How far it lights (m).
@export var radius := 8.0
## Burning: lights, and (a Beacon) draws. Set it, or `light()` / `douse()`.
@export var lit := true:
	set(v):
		if v == lit: return
		lit = v
		if lit: lightings += 1
		lit_changed.emit(lit)

## Times it was lit (a relit beacon is news again to those that tired of it).
var lightings := 0

func _enter_tree() -> void:
	add_to_group(GROUP)

func light() -> void:
	lit = true

func douse() -> void:
	lit = false

## The light it casts at `p` (0 unlit or out of reach).
func light_at(p: Vector3) -> float:
	if not lit or radius <= 0.0: return 0.0
	var d := global_position.distance_to(p)
	if d >= radius: return 0.0
	return strength*clampf((radius-d)/(radius*(1.0-FULL)),0.0,1.0)
