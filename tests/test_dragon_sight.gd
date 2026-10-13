extends SceneTree
## The dragon's sight (scripts/dragon_sight.gd, docs/design/dragon-vision/
## round1.md), headless: seen in the open in his cone; not seen out of the
## cone or past its range; a wall between hides him, a low one half; the
## air makes him plainer; awareness fills, holds through the grace, drains,
## and the states change with their hysteresis, signalled each time.
##   godot --headless --path . --script tests/test_dragon_sight.gd
const DragonSight = preload("res://scripts/dragon_sight.gd")

var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var space := root.get_world_3d().direct_space_state
	var s := DragonSight.new()
	var eye := Vector3(0.0,10.0,0.0)
	var look := Vector3.FORWARD
	var feet := Vector3(0.0,9.0,-40.0)
	var open := s.look_at_pilot(space,eye,look,DragonSight.pilot_points(feet,false),false)
	check(open > 0.4 and s.in_cone and s.seen_share == 1.0,"in the open in his cone he is seen (%.2f)" % open)
	var aloft := s.look_at_pilot(space,eye,look,DragonSight.pilot_points(feet,false),true)
	check(aloft > open,"in the air he is plainer (%.2f against %.2f on the ground)" % [aloft,open])
	var far := s.look_at_pilot(space,eye,look,DragonSight.pilot_points(Vector3(0.0,9.0,-250.0),false),false)
	check(far > 0.0 and far < open,"farther off, less seen (%.2f)" % far)
	var aside := s.look_at_pilot(space,eye,look,DragonSight.pilot_points(Vector3(40.0,9.0,5.0),false),false)
	check(aside == 0.0 and not s.in_cone,"out of the cone, not seen")
	var past := s.look_at_pilot(space,eye,look,DragonSight.pilot_points(Vector3(0.0,9.0,-DragonSight.RANGE-20.0),false),false)
	check(past == 0.0 and not s.in_cone,"past his range, not seen")
	# A wall between them, then a low one just before him (his feet and
	# chest behind it, his head over it).
	var wall := _box(Vector3(10.0,10.0,1.0),Vector3(0.0,9.0,-20.0))
	await physics_frame
	await physics_frame
	var hid := s.look_at_pilot(space,eye,look,DragonSight.pilot_points(feet,false),false)
	check(hid == 0.0 and s.in_cone and s.seen_share == 0.0,"a wall between hides him (in the cone, no ray through)")
	wall.queue_free()
	_box(Vector3(10.0,0.7*2.0,0.5),Vector3(0.0,9.0,-38.0))
	await physics_frame
	await physics_frame
	var half := s.look_at_pilot(space,eye,look,DragonSight.pilot_points(feet,false),false)
	check(is_equal_approx(s.seen_share,1.0/3.0) and half > 0.0 and half < open*0.5,"behind a low wall only his head shows: a third seen (%.2f)" % half)
	# Awareness: seen in the open it fills to suspicious, then spotted.
	var a := DragonSight.new()
	var changes: Array = []
	a.state_changed.connect(func(now: String, was: String) -> void: changes.append(was+">"+now))
	var t := 0.0
	var suspect_at := -1.0
	while a.state != "spotted" and t < 30.0:
		a.step(0.1,open)
		t += 0.1
		if suspect_at < 0.0 and a.state == "suspicious": suspect_at = t
	check(suspect_at > 0.0 and a.state == "spotted" and t > suspect_at,"seen, he turns suspicious (%.1f s) then spots him (%.1f s)" % [suspect_at,t])
	# Out of sight: held through the grace, then drained back down.
	var full := a.awareness
	for i in range(int(DragonSight.GRACE*10.0)-2): a.step(0.1,0.0)
	check(is_equal_approx(a.awareness,full),"just out of sight, the grace holds his awareness (%.2f)" % a.awareness)
	t = 0.0
	while a.state == "spotted" and t < 60.0:
		a.step(0.1,0.0)
		t += 0.1
	check(a.state == "suspicious" and a.awareness < DragonSight.SPOT_DOWN,"unseen, it drains back to suspicious (%.1f s)" % t)
	while a.state != "unaware" and t < 60.0:
		a.step(0.1,0.0)
		t += 0.1
	check(a.state == "unaware","and on to unaware (%.1f s)" % t)
	check(changes == ["unaware>suspicious","suspicious>spotted","spotted>suspicious","suspicious>unaware"],"each change signalled (%s)" % str(changes))
	# Hysteresis: the same awareness reads by the way it came.
	var mid := (DragonSight.SPOT_DOWN+DragonSight.SPOT_UP)*0.5
	check(DragonSight.next_state("spotted",mid) == "spotted" and DragonSight.next_state("unaware",mid) == "suspicious","between the thresholds the state holds (spotted stays, unaware rises only to suspicious)")
	print("PASS: dragon sight" if failures == 0 else "FAIL: dragon sight (%d)" % failures)
	quit(1 if failures else 0)

func _box(size: Vector3, at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = at
	root.add_child(body)
	return body

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)
