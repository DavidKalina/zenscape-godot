extends SceneTree
## The knife-edge drift (scripts/sky_plane.gd, docs/design/knife-drift.md):
## a turn held on the knife edge comes round on a clearly tighter circle
## than the same turn banked, at a little speed; the nose leads its path;
## a straight knife edge still holds its heading; a small correction on
## the edge doesn't drift; letting go of a held drift gives a small boost;
## and drift strength 0 turns it off.
##   godot --headless --path . --script tests/test_knife_drift.gd
const SkyPlane = preload("res://scripts/sky_plane.gd")
const DT := 1.0/60.0
var failures := 0

func _initialize() -> void:
	var normal := _circle({"turn":1.0})
	var drifting := _circle({"turn":1.0,"lean":1.0})
	var counter := _circle({"turn":-1.0,"lean":1.0})
	print("Normal turn: radius %.2f m at %.1f m/s" % [normal.radius,normal.speed])
	print("Drift: radius %.2f m at %.1f m/s, slip %.1f deg" % [drifting.radius,drifting.speed,rad_to_deg(drifting.slip)])
	print("Counter drift: radius %.2f m at %.1f m/s" % [counter.radius,counter.speed])
	check(drifting.radius < normal.radius*0.75,"The drift turns clearly tighter (%.2f m against %.2f m)" % [drifting.radius,normal.radius])
	check(drifting.speed < normal.speed-1.0,"And bleeds speed for it (%.1f against %.1f m/s)" % [drifting.speed,normal.speed])
	check(drifting.speed > SkyPlane.SLOW+2.0,"But keeps flying well above SLOW (%.1f m/s)" % drifting.speed)
	check(absf(drifting.slip) > 0.15,"The nose leads its path (%.1f deg)" % rad_to_deg(drifting.slip))
	check(counter.radius < normal.radius and counter.radius > drifting.radius,"A turn against the lean drifts, less (%.2f m)" % counter.radius)
	_straight()
	_correction()
	_release()
	_off(normal.radius)
	print("PASS: knife drift" if failures == 0 else "FAIL: knife drift")
	quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func air(_p: Vector3) -> Variant:
	return null

func flying(strength := 1.0) -> SkyPlane:
	var plane := SkyPlane.new()
	plane.drift_strength = strength
	plane.launch(Vector3(0.0,40.0,0.0),0.0,14.0,false)
	for i in range(int(3.0/DT)): plane.step(DT,{},air)
	return plane

## Settles into the held turn, then measures the circle it flies: its path
## length over the heading it turns (the radius of a steady turn).
func _circle(input: Dictionary, strength := 1.0) -> Dictionary:
	var plane := flying(strength)
	for i in range(int(2.0/DT)): plane.step(DT,input,air)
	var path := 0.0
	var turned := 0.0
	var speed := 0.0
	var n := int(2.0/DT)
	for i in range(n):
		var was := plane.position
		var h := plane.heading
		plane.step(DT,input,air)
		var d := plane.position-was
		path += Vector2(d.x,d.z).length()
		turned += absf(angle_difference(h,plane.heading))
		speed += plane.speed/n
	return {"radius":path/maxf(turned,0.0001),"speed":speed,"slip":plane.slip}

## Held straight on the edge it flies on, as it always did.
func _straight() -> void:
	var plane := flying()
	var h := plane.heading
	var from := plane.position
	for i in range(int(3.0/DT)): plane.step(DT,{"lean":1.0},air)
	check(absf(angle_difference(h,plane.heading)) < 0.01,"A straight knife edge holds its heading (%.4f rad)" % angle_difference(h,plane.heading))
	check(plane.drift < 0.001 and absf(plane.slip) < 0.001,"And doesn't drift")
	var d := plane.position-from
	check(absf(d.x) < 0.1,"Nor slides sideways (%.3f m)" % d.x)
	check(absf(plane.speed-SkyPlane.CRUISE_SPEED) < 0.3,"Nor loses speed (%.2f m/s)" % plane.speed)

## A small stick on the edge (lining up a slit) is a plain correction.
func _correction() -> void:
	var plane := flying()
	for i in range(int(1.5/DT)): plane.step(DT,{"lean":1.0,"turn":0.2},air)
	check(plane.drift < 0.001,"A small correction on the edge doesn't drift (%.3f)" % plane.drift)

## Out of a held drift it gets a little speed back, then eases to cruise.
func _release() -> void:
	var plane := flying()
	for i in range(int(1.5/DT)): plane.step(DT,{"lean":1.0,"turn":1.0},air)
	var during := plane.speed
	plane.step(DT,{"lean":1.0},air)
	var after := plane.speed
	check(after > during+1.0 and after-during <= SkyPlane.DRIFT_BOOST+0.2,"Let go, a modest boost (%.1f to %.1f m/s)" % [during,after])
	for i in range(int(6.0/DT)): plane.step(DT,{},air)
	check(absf(plane.speed-SkyPlane.CRUISE_SPEED) < 0.5,"Then it eases back to cruise (%.1f m/s)" % plane.speed)
	check(absf(plane.slip) < 0.01,"Its nose back on its path")
	var quick := flying()
	for i in range(int(0.2/DT)): quick.step(DT,{"lean":1.0,"turn":1.0},air)
	var s := quick.speed
	quick.step(DT,{"lean":1.0},air)
	check(quick.speed <= s+0.05,"A flick too short to count gives no boost")

## Strength 0: the knife edge turns as a banked turn does.
func _off(normal: float) -> void:
	var off := _circle({"turn":1.0,"lean":1.0},0.0)
	check(absf(off.radius-normal) < 0.3,"--drift=0 turns it off (%.2f m against %.2f m)" % [off.radius,normal])
	check(SkyPlane.drift_flag(PackedStringArray(["--drift=1.5"])) == 1.5 and SkyPlane.drift_flag(PackedStringArray()) == 1.0,"The --drift flag reads")
