class_name NoiseBus
extends Node
## The layer's noise (docs/design/roguelike/noise-stealth-round1.md): one
## bus every noise goes through and every ear reads, the way SightLight /
## LightLevel are the layer's light. A noise is a point, a loudness and who
## made it; loudness is in metres: how far off an ear of hearing 1 still
## hears it (at the very edge, faintly; full at the point).
##
## Making a noise (anything: the wanderer's feet, a body's landing, a break,
## an urn replaying what it heard):
##   NoiseBus.make(self, at, 14.0, &"step")          # from any node in the tree
##   NoiseBus.of(get_tree()).emit(at, 14.0, self, &"step")
## Hearing it:
##   NoiseBus.of(get_tree()).noise_made.connect(_on_noise)   # pushed, as made
##   for n: NoiseBus.Sound in bus.since(_last_id): ...        # pulled (a poll)
##   bus.recent(3.0, at)        # the last 3 s, loudest at `at` first
##   n.heard_at(p, hearing)     # 0 (out of hearing) .. 1 (at the point)
##
## The bus is a node under the current scene, named "NoiseBus", made the
## first time it is asked for (`of`), so it lives and dies with the layer;
## its clock is the scene's frames (s). Nothing here knows who listens or
## who the wanderer is: every wanderer (co-op later) makes its own noises,
## and an ear tells them apart by `source` and `kind`.
##
## Kinds the game makes (a listener may filter on them; new ones are free):
##   &"step" a footfall   &"land" a landing   &"slam" his slam
##   &"grab" a ledge grab, a climb over, a wall kick   &"slide" a slide's scrape
##   &"splash" water   &"rune" a rune taken   &"break" kit breaking
##   &"olmec_land" a body's landing (its shockwave)
## `relayed` noises (an echo, a twin jar) carry the noise they came from.
##
## `--noise-debug` (any scene): each noise drawn as its hearing ring, fading.

## A noise was made (`noise` a NoiseBus.Sound).
signal noise_made(noise: Sound)

const LaunchArgs = preload("res://scripts/launch_args.gd")
const NAME := &"NoiseBus"
## How long a noise is kept for `recent` / `since` (s).
const KEEP := 6.0

## One noise. Read-only once made.
class Sound extends RefCounted:
	## Its number on the bus (rising).
	var id := 0
	var position := Vector3.ZERO
	## How far it carries (m) to an ear of hearing 1.
	var loudness := 0.0
	## Who made it: a wanderer's figure, a body, a hub, an urn. May be freed
	## later: test with is_instance_valid.
	var source: Object = null
	var kind := &""
	## The bus clock when made (s).
	var time := 0.0
	## The noise this one repeats (an echo's), or null.
	var relayed: Sound = null

	## How well it is heard at `p` by an ear of `hearing` (its loudness
	## times this): 1 at the point, falling straight to 0 at the edge.
	func heard_at(p: Vector3, hearing := 1.0) -> float:
		var r := loudness*hearing
		if r <= 0.0: return 0.0
		return clampf(1.0-position.distance_to(p)/r,0.0,1.0)

	func age(bus_clock: float) -> float:
		return bus_clock-time

## The bus clock (s): the scene's frames since it was made.
var clock := 0.0
## Noises made, counted.
var made := 0
var _noises: Array[Sound] = []
var _next_id := 1
var _debug: Node3D = null

## The bus of `tree`'s current scene, made there if it has none (null with
## no scene).
static func of(tree: SceneTree) -> NoiseBus:
	if tree == null: return null
	var scene := tree.current_scene
	if scene == null: return null
	var bus := scene.get_node_or_null(NodePath(NAME)) as NoiseBus
	if bus != null: return bus
	bus = NoiseBus.new()
	bus.name = NAME
	scene.add_child(bus)
	return bus

## A noise made by `from` (any node in the tree; it is the source unless
## `source` is given) at `at`. Returns it, or null off the tree.
static func make(from: Node, at: Vector3, loudness: float, kind: StringName, source: Object = null) -> Sound:
	if from == null or not from.is_inside_tree(): return null
	var bus := of(from.get_tree())
	if bus == null: return null
	return bus.emit(at,loudness,from if source == null else source,kind)

func _ready() -> void:
	process_priority = -100
	for a: String in LaunchArgs.user_args():
		if a == "--noise-debug": debug(true)

func _process(delta: float) -> void:
	clock += delta
	while not _noises.is_empty() and clock-_noises[0].time > KEEP: _noises.pop_front()

## A noise at `position`, `loudness` m, made by `source`, of `kind`: kept,
## and `noise_made` told. `relayed`: the noise it repeats.
func emit(position: Vector3, loudness: float, source: Object, kind: StringName, relayed: Sound = null) -> Sound:
	var n := Sound.new()
	n.id = _next_id
	_next_id += 1
	n.position = position
	n.loudness = maxf(loudness,0.0)
	n.source = source
	n.kind = kind
	n.time = clock
	n.relayed = relayed
	_noises.append(n)
	made += 1
	noise_made.emit(n)
	return n

## The noises made after the one numbered `after_id` (0: all kept), oldest
## first: a poll's news.
func since(after_id: int) -> Array[Sound]:
	var out: Array[Sound] = []
	for n: Sound in _noises:
		if n.id > after_id: out.append(n)
	return out

## The noises of the last `within` s; given `at` (and an ear's `hearing`),
## only those heard there, loudest there first.
func recent(within := 2.0, at := Vector3.INF, hearing := 1.0) -> Array[Sound]:
	var out: Array[Sound] = []
	for n: Sound in _noises:
		if clock-n.time > within: continue
		if at != Vector3.INF and n.heard_at(at,hearing) <= 0.0: continue
		out.append(n)
	if at != Vector3.INF: out.sort_custom(func(a: Sound, b: Sound) -> bool: return a.heard_at(at,hearing) > b.heard_at(at,hearing))
	return out

## The number of the newest noise (0: none yet), for a poll's start.
func last_id() -> int:
	return _next_id-1

## Every kept noise dropped (a new layer).
func clear() -> void:
	_noises.clear()

## The hearing rings drawn (`--noise-debug`), or not.
func debug(on: bool) -> void:
	if on and _debug == null:
		_debug = preload("res://scripts/noise/noise_debug.gd").new()
		add_child(_debug)
	elif not on and _debug != null:
		_debug.queue_free()
		_debug = null
