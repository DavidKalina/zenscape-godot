extends Node3D
## A kit isle's on-foot tokens (docs/scenic/kit-isle-shared.md; the
## aqueduct isle's, docs/scenic/aqueduct-isle-life.md): an isle's own answer
## `spots_for` with where each stands and the move it asks for. They are
## a few of the sky's foot tokens (scripts/glyph_pickup.gd, calm: slower
## turn, gentler bob, a warmer, wider halo) set where each asks for a move,
## not laid in a trail. The readout and its climbing blip are the sky's
## (scripts/collectibles_hud.gd): the isle's tokens are one line, so each
## pickup climbs a step and the last one runs the flourish.
##
## Only the pilot on foot takes them (the plane passes through): his middle
## (CollectibleLines FOOT_Y over his feet) within WALKER_REACH plus half a
## token, read along the way he moved since the last frame, as the sky's
## do. Nothing is saved; a new run lays them again.
const GlyphPickup = preload("res://scripts/glyph_pickup.gd")
const Hud = preload("res://scripts/collectibles_hud.gd")
const Lines = preload("res://scripts/collectible_lines.gd")

const GLYPH := "wildflower"
const SIZE := 0.7
## A mover jumping further than this in a frame (a respawn, a placing)
## starts its sweep afresh.
const JUMP := 6.0

## The tokens: {name, at, move}. Filled by `spots_for`.
var tokens: Array[Dictionary] = []
## Taken token names, in order.
var taken: Array[String] = []
var hud: CanvasLayer
var _holders := {}
var _last := Vector3.INF

## Where each token stands and the move it asks for ({name, at, move}),
## worked out from the isle's own geometry (`isle` the study).
func spots_for(_isle: Node3D) -> Array[Dictionary]:
	return []

## A point under the lip of floating stone `p` on its north (-z) face,
## `along` m off its middle along the lip, where his middle is when he hangs
## from it (pilot_motor HANG_DROP under the lip, HANG_OUT off the face).
static func under_lip(p: Dictionary, along: float) -> Vector3:
	var size: Vector3 = p.size
	var basis := Basis(Vector3.UP,float(p.yaw))
	var at: Vector3 = p.at
	# Of the two faces across its width, the one facing north.
	var normal := basis.z if basis.z.z < 0.0 else -basis.z
	var side := basis.x
	return at+normal*(size.z*0.5+0.45)+side*along+Vector3.DOWN*0.4

func setup(isle: Node3D) -> void:
	name = "Tokens"
	tokens = spots_for(isle)
	for i in range(tokens.size()):
		var t: Dictionary = tokens[i]
		var holder := GlyphPickup.make(GLYPH,SIZE,float(i)*1.3,true)
		holder.name = "Token_%s" % t.name
		holder.position = t.at
		add_child(holder)
		holder.motes_on(true)
		_holders[t.name] = holder
	hud = Hud.new()
	add_child(hud)

## How many are left.
func left() -> int:
	return tokens.size()-taken.size()

## The night's glow (0 by day, 1 at full night).
func glow_for(night: float) -> void:
	for holder: Node3D in _holders.values():
		if is_instance_valid(holder) and not holder.taking: holder.glow_for(night)

## The pilot's middle this frame (on foot): every token within his reach of
## the way he moved since the last is taken. `point` INF (flying) forgets
## the last.
func touch(point: Vector3) -> void:
	if point == Vector3.INF:
		_last = Vector3.INF
		return
	var from := _last if _last != Vector3.INF and _last.distance_to(point) <= JUMP else point
	_last = point
	for t: Dictionary in tokens:
		if taken.has(t.name): continue
		var at: Vector3 = t.at
		var near := Geometry3D.get_closest_point_to_segment(at,from,point)
		if near.distance_to(at) < Lines.WALKER_REACH+SIZE*0.5: take(t.name)

## Token `name` taken: it twists away, the readout climbs a step.
func take(name: String) -> void:
	if taken.has(name) or not _holders.has(name): return
	taken.append(name)
	var holder: Node3D = _holders[name]
	if is_instance_valid(holder): holder.take(hash(name) & 0xffff)
	_holders.erase(name)
	if hud != null: hud.show_pickup(GLYPH,taken.size(),taken.size(),tokens.size())
