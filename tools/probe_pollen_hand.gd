extends SceneTree
## Headless check of pollen in the God Hand's palm (scripts/pollen_cloud.gd
## `hand_at`, `toss`): two veils laid alike, one with a hand and one without.
## With the hand, new motes wait in the palm and fly out when it throws; the
## veil it makes and every landing must be the same as without it.
##   Godot --headless --path . --script res://tools/probe_pollen_hand.gd

const Cloud := preload("res://scripts/pollen_cloud.gd")
const STEP := 1.0/60.0

var failures := 0
var settled := {}

func _check(ok: bool, what: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+what)
	if not ok: failures += 1

func _init() -> void:
	_run.call_deferred()

func _make(plate: Node3D, tag: String) -> Node3D:
	var cloud: Node3D = Cloud.new()
	cloud.scene = Node.new()
	plate.add_child(cloud)
	cloud.set_process(false)
	cloud.settled.connect(func(c: Dictionary) -> void: settled[tag] = c)
	return cloud

func _run() -> void:
	var plate := Node3D.new()
	root.add_child(plate)
	var bare := _make(plate,"bare")
	var held := _make(plate,"hand")
	var start := Vector3(-3.0,0.0,0.0)
	for cloud in [bare,held]: cloud.gather(start,3.6,1.0,"broadleaf",1234)
	# A sweep 6 m along x, a throw every half second; the palm rides 1.2 m
	# under the veil's head, as the hand's does.
	var in_palm := 0
	var palm_off := 0.0
	for frame in range(180):
		var point := start+Vector3(6.0*frame/179.0,0.0,0.0)
		held.hand_at = point+Vector3.UP*1.0
		for cloud in [bare,held]:
			cloud.hold(point)
			cloud._process(STEP)
		if frame == 20:
			for mote: Dictionary in held.held.motes:
				if mote.has("hand"):
					in_palm += 1
					palm_off = maxf(palm_off,Vector3(mote.p).distance_to(held.hand_at))
		if frame%30 == 29: held.toss(Vector3(1.5,3.0,0.0))
	_check(in_palm > 0,"new motes wait in the palm (%d at 1/3 s)" % in_palm)
	_check(palm_off < 0.3,"gathered in a handful (%.2f m across at most)" % palm_off)
	var waiting := 0
	for mote: Dictionary in held.held.motes:
		if mote.has("hand"): waiting += 1
	# Hold still (which thickens the veil) throwing as the hand does, then
	# with the hand gone a moment: every thrown mote reaches its place.
	for frame in range(150):
		held.hand_at = start+Vector3(6.0,1.0,0.0) if frame < 60 else null
		for cloud in [bare,held]:
			cloud.hold(start+Vector3(6.0,0.0,0.0))
			cloud._process(STEP)
		if frame%30 == 5 and frame < 60: held.toss(Vector3(1.5,3.0,0.0))
	var worst := 0.0
	var flying := 0
	for i in range(held.held.motes.size()):
		var a: Dictionary = bare.held.motes[i]
		var b: Dictionary = held.held.motes[i]
		worst = maxf(worst,Vector3(a.p).distance_to(Vector3(b.p)))
		if b.has("v") or b.has("hand"): flying += 1
	_check(flying == 0,"every thrown mote has come to rest in the veil (%d still flying)" % flying)
	_check(worst < 0.25,"the veil is the one laid without a hand (%.3f m apart at most)" % worst)
	# The release throw: whatever is in the palm when the button comes up is
	# thrown after, and still lands where it would have.
	for i in range(20):
		held.hand_at = start+Vector3(6.0,1.0,0.0)
		for cloud in [bare,held]:
			cloud.hold(start+Vector3(6.3+0.1*i,0.0,0.0))
			cloud._process(STEP)
	var in_hand_at_release := 0
	for mote: Dictionary in held.held.motes:
		if mote.has("hand"): in_hand_at_release += 1
	for cloud in [bare,held]: cloud.release()
	for frame in range(900):
		if frame == 12: held.toss(Vector3(0.5,2.5,0.0))
		for cloud in [bare,held]:
			if cloud.active(): cloud._process(STEP)
		if settled.size() == 2: break
	print("  motes waiting in the palm at release: %d" % in_hand_at_release)
	_check(settled.size() == 2,"both veils settle")
	if settled.size() == 2:
		var a: PackedVector2Array = settled.bare.points
		var b: PackedVector2Array = settled.hand.points
		var same := a.size() == b.size()
		var apart := 0.0
		if same:
			for i in range(a.size()): apart = maxf(apart,a[i].distance_to(b[i]))
		_check(same and apart < 0.0001,"every mote lands where it would without the hand (%d landings, %.6f m apart at most)" % [a.size(),apart])
		_check(settled.bare.seeds == settled.hand.seeds,"and the same seeds take")
	print("failures=%d" % failures)
	quit(1 if failures > 0 else 0)
