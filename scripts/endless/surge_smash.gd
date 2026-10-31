extends Node3D
## The surge roll (docs/design/endless-flight/spec-wilderness-demo.md, lane
## `roll`). On a full near-miss meter the roll button (Z, pad A, left click), or
## the surge button pressed (`fly_surge`), is the surge roll: the meter's whole
## surge at once (NearMiss `score`, SkyPlane `surge`), a fast double spin and a
## lunge. While it's `hot`:
##
## - breakable stone ahead breaks and the plane flies on through: a LandArches
##   record's kit pieces (arches, ruins, set pieces under SmashBreaks.MOST_LONG)
##   and the cracked walls (scripts/endless/cracked_walls.gd). The hub
##   (scripts/breaks/breakables.gd) lives here, breaker `plane` on; `--breakers=`
##   still rules it. Outside it stone is stone as ever, and so is what can't
##   break (rock, halls and bores, slabs, a colosseum).
## - a burrower on a run can't keep ahead, and flown into he's caught
##   (scripts/endless/burrower_flight.gd `try_catch`, signal `caught`).
##
## Below a full meter the roll button is the clean roll and `fly_surge` the plain
## surge, as before.

const Hub = preload("res://scripts/breaks/breakables.gd")
const Breaks = preload("res://scripts/breaks/smash_breaks.gd")
const Walls = preload("res://scripts/endless/cracked_walls.gd")
const WorldScale = preload("res://scripts/world_scale.gd")

## A hit on stone (`smashed`): where (world). Any break, wall or ruin.
signal smashed(at: Vector3)

const FULL := 0.999
## The spin: turns, seconds. A hit caught outside it spins again (HIT_TURNS).
const TURNS := 2.0
const SPIN_S := 0.62
const HIT_TURNS := 1.0
const HIT_SPIN_S := 0.4
## The lunge (m/s on the speed at once), the view's kick on it (rad, degrees).
const LUNGE := 18.0
const KICK := Vector2(0.014,7.0)
## A hit: the view's kick, the hit-stop (frames, time scale), the breaker's
## strength and reach (m), how far it looks ahead (s of flight, least m).
const HIT_KICK := Vector2(0.03,11.0)
const HIT_STOP := Vector2(5.0,0.12)
const STRENGTH := 1.0
const HIT_R := 3.5
const LOOK_S := 0.1
const LOOK_LEAST := 6.0
## How long the wingtip vapour stays hard on (s).
const VAPOUR_S := 0.7
## While full or hot, every SCAN_S s, ruins within SCAN_M m ahead get their
## cuts made on a worker, so a hit finds them made.
const SCAN_S := 0.3
const SCAN_M := 240.0

var game: Node3D
var hub: Node
var breaks: Node3D
var walls: Node3D
## The surge roll is on: the surge held, stone breaking.
var hot := false
## 0 to 1: the wingtips' vapour held on through the spin (the study's `_pull`).
var vapour := 0.0
## Counted, for the drivers.
var rolls := 0
var hits := 0
var catches := 0
var _held_was := false
var _hold := 0.0
var _scan := 0.0
var _crashes := 0

func _init() -> void:
	name = "SurgeSmash"

func setup(g: Node3D) -> void:
	game = g
	hub = Hub.new()
	add_child(hub)
	hub.set_breaker(&"plane",true,STRENGTH)
	hub.sound_hook = Callable(self,"_stone_sound")
	breaks = Breaks.new()
	breaks.hub = hub
	breaks.dress = func(node: Node3D, at: Vector3) -> void: game.arches._sunlit(node,false,false,at)
	add_child(breaks)
	hub.others.append(breaks)
	walls = Walls.new()
	add_child(walls)
	walls.setup(g,self)

## True when the next press is the surge roll.
func armed() -> bool:
	return game.plane.weighted and bool(game.hand_landing.flying()) and float(game.near.meter) >= FULL

## Hot on past the meter's end for `seconds`: a flown chamber's way out.
func keep_hot(seconds: float) -> void:
	_hold = maxf(_hold,seconds)

## One frame, before the plane's: `input`'s roll taken for the surge roll on a
## full meter, stone ahead struck, the burrower caught.
func before(delta: float, input: Dictionary) -> void:
	walls.step(game.camera.global_position)
	vapour = move_toward(vapour,0.0,delta/VAPOUR_S)
	var held := Input.is_action_pressed(&"fly_surge")
	var pressed := held and not _held_was
	_held_was = held
	var asked := float(input.get("roll",0.0))
	if not hot and armed() and (asked != 0.0 or pressed):
		input["roll"] = 0.0
		_start(asked if asked != 0.0 else float(game.roll_side()))
	if armed() or hot: _scan_ahead(delta)
	if not hot: return
	if not bool(game.hand_landing.flying()) or int(game.contact.crashes) != _crashes:
		_end()
		return
	_hold = maxf(_hold-delta,0.0)
	if float(game.near.meter) <= 0.0 and _hold <= 0.0:
		_end()
		return
	_strike()
	if game.burrower != null and game.burrower.try_catch(game): _caught()

## While hot a wingtip's touch of stone is nothing: the stone's going (NearMiss
## `touching`, read by FlightContact).
func touch(near: RefCounted) -> void:
	if hot and str(near.touching.get("what","")) == "stone": near.touching = {}

func _start(dir: float) -> void:
	hot = true
	rolls += 1
	_crashes = int(game.contact.crashes)
	vapour = 1.0
	game.plane.surge_roll(dir,TURNS,SPIN_S)
	game.plane.lunge(LUNGE)
	game.feel_hit(KICK.x,KICK.y)
	game.sound.shot("whoosh",1.0,0.75)
	game.sound.shot("swish",0.8,0.8)
	if game.burrower != null: game.burrower.chased(true)

func _end() -> void:
	hot = false
	_hold = 0.0
	if game.burrower != null: game.burrower.chased(false)

## What the plane's about to meet this frame, struck.
func _strike() -> void:
	var p: Vector3 = game.plane.position
	var v: Vector3 = game.plane.velocity
	if v.length() < 1.0: return
	var way := v.normalized()
	var pad := WorldScale.span*0.5+0.3
	var look := maxf(v.length()*LOOK_S,LOOK_LEAST)
	var s := 0.0
	while s <= look:
		var q := p+way*s
		var r: Dictionary = game.arches.record_at(q,pad)
		if not r.is_empty() and _hit(r,q,way,v): return
		s += 1.5

## Record `r` struck at `q`: true if it broke.
func _hit(r: Dictionary, q: Vector3, way: Vector3, v: Vector3) -> bool:
	breaks.blast_dir = way
	breaks.blast_v = v
	if r.has("wall"):
		walls.strike(r,q)
	else:
		if not _adopt(r): return false
		if not breaks.in_reach(q,HIT_R,STRENGTH): return false
		_hole(r,q)
	hub.hit(q,HIT_R,-1.0,&"plane")
	_felt(q,way)
	return true

## The hit in the eye and the ear.
func _felt(q: Vector3, way: Vector3) -> void:
	hits += 1
	hub.pause(int(HIT_STOP.x),HIT_STOP.y)
	game.feel_hit(HIT_KICK.x,HIT_KICK.y)
	game.sound.shot("crash",1.2,1.0)
	game.sound.shot("debris",1.0,0.9)
	game.debris.burst("dust",q,-way,true)
	game.debris.hit("stone",q,-way,true)
	vapour = 1.0
	if not game.plane.rolling: game.plane.surge_roll(float(game.plane.roll_dir) if game.plane.roll_dir != 0.0 else 1.0,HIT_TURNS,HIT_SPIN_S)
	smashed.emit(q)

func _caught() -> void:
	catches += 1
	hub.pause(int(HIT_STOP.x)+2,HIT_STOP.y)
	game.feel_hit(HIT_KICK.x,HIT_KICK.y)
	game.sound.shot("crash",1.2,0.6)
	game.sound.shot("thump",1.2,0.7)
	vapour = 1.0

## The hub's stone sounds, as the flight's.
func _stone_sound(what: StringName, at: Vector3) -> void:
	match what:
		&"ruin_crack": game.sound.shot("debris",0.7,1.0,at)
		&"ruin_fall", &"ruin_boom": game.sound.shot("thump",0.9,0.6,at)
		&"ruin_thud": game.sound.shot("thump",0.5,0.9,at)

# --- Ruins in the land -------------------------------------------------------

## Record `r`'s kit pieces targets of the breaks (once). False if it has none.
func _adopt(r: Dictionary) -> bool:
	if not r.has("adopted"): r["adopted"] = int(breaks.adopt(r.node))
	return int(r.adopted) > 0

## The way through record `r` at `q`: its flight solid and its colliders gone
## over the stump's line within the break's reach. Back when its cell is
## streamed again.
func _hole(r: Dictionary, q: Vector3) -> void:
	var o: Vector3 = r.pos
	var grow := float((r.spec as Dictionary).get("grow",1.0))
	var reach := 3.5*grow+WorldScale.span
	var stump := (q.y-o.y)*0.4
	var ox := q.x-o.x
	var oz := q.z-o.z
	var lx := ox*float(r.cos)-oz*float(r.sin)
	var lz := ox*float(r.sin)+oz*float(r.cos)
	var solid: Dictionary = r.solid
	var b: PackedFloat32Array = solid.b
	for k in range(0,b.size(),6):
		if b[k+4] < stump: continue
		var dx := maxf(0.0,maxf(b[k]-lx,lx-b[k+3]))
		var dz := maxf(0.0,maxf(b[k+2]-lz,lz-b[k+5]))
		if dx*dx+dz*dz > reach*reach: continue
		b[k+1] = -1e6
		b[k+4] = -1e6
	solid.b = b
	var body := (r.node as Node).get_node_or_null("Body") as StaticBody3D
	if body == null or not body.has_meta("shapes_on"): return
	var inv: Transform3D = body.global_transform.affine_inverse()
	var at := inv*q
	var pairs: Array = body.get_meta("shapes")
	for i in range(pairs.size()):
		var c: Vector3 = pairs[i][1]
		if c.y > stump and Vector2(c.x-at.x,c.z-at.z).length() < reach:
			PhysicsServer3D.body_set_shape_disabled(body.get_rid(),i,true)

## Kit ruins ahead get their cuts made ahead of the hit.
func _scan_ahead(delta: float) -> void:
	_scan -= delta
	if _scan > 0.0: return
	_scan = SCAN_S
	var p: Vector3 = game.plane.position
	var way: Vector3 = game.plane.forward()
	for r: Dictionary in game.arches.standing():
		var to: Vector3 = (r.pos as Vector3)-p
		if to.length() > SCAN_M or to.dot(way) < 0.0: continue
		if r.has("adopted"): continue
		_adopt(r)
		for i in range(breaks.targets.size()):
			if (breaks.targets[i].pre as Dictionary).is_empty(): breaks._ready_job(i,Vector3.INF)
