extends SceneTree
## Headless check of thrown seed (scripts/seed_throw.gd): throws aimed at the
## pointer land round it in still air, a throw on the move carries on the
## pointer's way, wind drags the seeds and more so the dust, every seed lands
## inside its throw's promise, and a sowing settles once, with its seeds.
##   Godot --headless --path . --script res://tools/probe_seed_throw.gd

const Throw := preload("res://scripts/seed_throw.gd")
const STEP := 1.0/60.0

const FakeAir := """
extends RefCounted
var _air_angle := 0.0
var _air_strength := 0.0
var swell := 0.0
var _wind_time := 0.0
var _gust_distance := 0.0
var puffs: Variant = null
func gust_at(_t: float) -> float: return 1.0
"""
const FakeScene := """
extends Node
var _atmosphere: Object
"""

var failures := 0
var settled: Array[Dictionary] = []

func _check(ok: bool, what: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+what)
	if not ok: failures += 1

func _script(source: String) -> GDScript:
	var script := GDScript.new()
	script.source_code = source
	script.reload()
	return script

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var plate := Node3D.new()
	root.add_child(plate)
	var scene: Node = _script(FakeScene).new()
	var air: Object = _script(FakeAir).new()
	scene._atmosphere = air
	root.add_child(scene)
	var throw: Node3D = Throw.new()
	throw.scene = scene
	plate.add_child(throw)
	throw.set_process(false)
	throw.settled.connect(func(c: Dictionary) -> void: settled.append(c))
	var target := Vector3(0.0,0.0,0.0)

	# Still air, no hand: held 3 s at one spot, then let go.
	var run := _sow(throw,target,Vector3.ZERO,3.0,null)
	_check(settled.size() == 1,"one sowing settles once")
	if settled.size() == 1:
		var sown: Dictionary = settled[0]
		print("  %d throws, %d motes, %d seeds, %d seeds outside a promise" % [sown.throws,sown.motes,sown.seeds.size(),sown.outside])
		_check(int(sown.throws) >= 3,"it throws while held and once more on release (%d)" % sown.throws)
		_check(sown.seeds.size() >= 3,"its seeds take their places (%d)" % sown.seeds.size())
		_check(int(sown.outside) == 0,"every seed lands inside its throw's promise")
	_check(run.seed_mean.distance_to(Vector2(target.x,target.z)) < 0.5,"seeds come down round the pointer (%.2f m off)" % run.seed_mean.distance_to(Vector2(target.x,target.z)))
	_check(run.skipped > 0,"fast seeds skip once (%d)" % run.skipped)
	print("  seed flight %.2f s, dust flight %.2f s" % [run.seed_time,run.dust_time])
	_check(run.dust_time > run.seed_time,"dust floats down slower than seed falls")

	# On the move: the pointer runs +x at 3 m/s; throws carry on its way.
	settled.clear()
	var moving := _sow(throw,target,Vector3(3.0,0.0,0.0),2.0,null)
	var ahead: float = moving.seed_offset.x
	print("  on the move, seeds land %.2f m ahead of the pointer at their throw" % ahead)
	_check(ahead > 0.5,"a throw on the move carries on the pointer's way")
	if settled.size() == 1: _check(int(settled[0].outside) == 0,"and still lands inside its promise")

	# A hand stands 2.2 m back and throws at its own angle and pace.
	settled.clear()
	var handed := _sow(throw,target,Vector3.ZERO,2.0,Vector3(2.2,1.45,0.0))
	_check(handed.seed_mean.distance_to(Vector2(target.x,target.z)) < 0.5,"the hand's throws land round the pointer (%.2f m off)" % handed.seed_mean.distance_to(Vector2(target.x,target.z)))
	_check(handed.throws >= 2,"at the hand's pace (%d throws)" % handed.throws)

	# Wind along +z at strength 1: the seeds shift a little, the dust a lot.
	settled.clear()
	air._air_angle = PI*0.5
	air._air_strength = 1.0
	var windy := _sow(throw,target,Vector3.ZERO,2.0,null)
	print("  in wind, seeds shift %.2f m, dust %.2f m downwind" % [windy.seed_mean.y-run.seed_mean.y,windy.dust_mean.y-run.dust_mean.y])
	_check(windy.seed_mean.y-run.seed_mean.y > 0.15,"wind drags the seeds downwind")
	_check(windy.dust_mean.y-run.dust_mean.y > windy.seed_mean.y-run.seed_mean.y,"and the dust further")
	if settled.size() == 1: _check(int(settled[0].outside) == 0,"inside the promise the wind showed")
	print("failures=%d" % failures)
	quit(1 if failures > 0 else 0)

## Hold for `seconds` with the pointer moving at `pointer_v` from `start`, a
## hand at `hand` (offset from the pointer) tossing every 1.33 s or none,
## then let go and fly everything down. Mean landings, flight times, skips.
func _sow(throw: Node3D, start: Vector3, pointer_v: Vector3, seconds: float, hand: Variant) -> Dictionary:
	throw.hand_at = null if hand == null else start+Vector3(hand)
	throw.gather(start,3.6,1.0,"broadleaf",99)
	var t := 0.0
	var toss := 0.0
	var at := start
	var sowing: Dictionary = throw.held
	while t < seconds:
		at = start+pointer_v*t
		throw.hold(at)
		if hand != null:
			throw.hand_at = at+Vector3(hand)
			toss += STEP
			if toss >= 1.0:
				toss = 0.0
				throw.toss(Vector3(-2.0,1.4,0.0))
		throw._process(STEP)
		t += STEP
	throw.release()
	if hand != null:
		throw._process(STEP)
		throw.toss(Vector3(-2.0,1.4,0.0))
	var guard := 0
	while throw.active() and guard < 1200:
		throw._process(STEP)
		guard += 1
	var throws: int = sowing.throws.size()
	var box := Rect2()
	var first := true
	for mote: Dictionary in sowing.motes:
		if not mote.seed or not mote.landed: continue
		var q := Vector2(mote.p.x,mote.p.z)
		box = Rect2(q,Vector2.ZERO) if first else box.expand(q)
		first = false
	print("  seeds landed over %.2f x %.2f m" % [box.size.x,box.size.y])
	var seed_sum := Vector2.ZERO
	var dust_sum := Vector2.ZERO
	var offset := Vector2.ZERO
	var seeds := 0
	var dust := 0
	var skipped := 0
	for mote: Dictionary in sowing.motes:
		if not mote.landed: continue
		var p := Vector2(mote.p.x,mote.p.z)
		if mote.seed:
			seed_sum += p
			seeds += 1
			if mote.skipped: skipped += 1
		else:
			dust_sum += p
			dust += 1
	return {"seed_mean":seed_sum/maxf(seeds,1),"dust_mean":dust_sum/maxf(dust,1),"skipped":skipped,"throws":throws,
		"seed_offset":_ahead(sowing),"seed_time":_flight(sowing,true),"dust_time":_flight(sowing,false)}

## Mean landing of the seeds against the pointer at their throw.
func _ahead(sowing: Dictionary) -> Vector2:
	var sum := Vector2.ZERO
	var n := 0
	for mote: Dictionary in sowing.motes:
		if not mote.seed or not mote.landed or not mote.has("aim"): continue
		sum += Vector2(mote.p.x,mote.p.z)-Vector2(mote.aim)
		n += 1
	return sum/maxf(n,1)

func _flight(sowing: Dictionary, seed: bool) -> float:
	var sum := 0.0
	var n := 0
	for mote: Dictionary in sowing.motes:
		if mote.seed != seed or not mote.has("flew"): continue
		sum += float(mote.flew)
		n += 1
	return sum/maxf(n,1)
