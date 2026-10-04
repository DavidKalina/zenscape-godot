extends SceneTree
## Grass blades kicked up by sweeping breeze ribbons (scripts/wind_kicked_blades.gd):
## plucked from grass near the track, carried up in the lift, then they fall
## and fade; nothing over water or bare ground, never below the ground, bounded.
class StubRibbons extends Node:
	var list: Array[Dictionary] = []
	var updraft := 0.0
	func kicks() -> Array[Dictionary]: return list
	func air_at(p: Vector3) -> Vector3:
		if list.is_empty(): return Vector3.ZERO
		var near := 1.0-smoothstep(0.0,1.5,Vector2(p.x-list[0].at.x,p.z-list[0].at.z).length())
		return Vector3(list[0].vel.x,0,list[0].vel.z)*0.5*near+Vector3.UP*updraft*near
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
	print(("ok   " if ok else "FAIL ") + message)
func kick(at: Vector3, lift: float, strength := 1.0) -> Dictionary:
	return {"at":at,"vel":Vector3(6,0,0),"lift":lift,"strength":strength,"id":1}
func run() -> void:
	var Blades = load("res://scripts/wind_kicked_blades.gd")
	var rib := StubRibbons.new()
	var blades = Blades.new()
	root.add_child(rib)
	root.add_child(blades)
	var ground := func(p: Vector2) -> Variant: return 0.3*sin(p.x*0.4)+0.5
	var grass := func(_p: Vector2) -> float: return 1.0
	blades.setup(ground, grass)
	for i in range(60): blades.advance(1.0/60.0, false, rib)
	check(blades.blades.is_empty(), "No kicks, no blades")
	var at := Vector3(0,0.5,0)
	# Skimming: blades start near the track, low.
	rib.list = [kick(at,0.0)]
	for i in range(30):
		blades.advance(1.0/60.0, false, rib)
		rib.list[0].at.x += 0.1
	check(blades.blades.size() > 5, "A skimming kick plucks blades: %d" % blades.blades.size())
	var near: bool = blades.blades.all(func(b: Dictionary) -> bool: return Vector2(b.position.x-rib.list[0].at.x,b.position.z).length() < 4.0)
	check(near, "They stay near the track")
	var low: bool = blades.blades.all(func(b: Dictionary) -> bool: return b.position.y < 1.2+ground.call(Vector2(b.position.x,b.position.z)))
	check(low, "Skimming keeps them low")
	# Lift-off: they rise.
	rib.updraft = 3.5
	var peak := 0.0
	var below := false
	var most := 0
	for i in range(150):
		rib.list = [kick(at+Vector3(3.0,0,0),clampf(i/30.0,0.0,1.0))]
		blades.advance(1.0/60.0, false, rib)
		most = maxi(most, blades.blades.size())
		for b in blades.blades:
			peak = maxf(peak, b.position.y-float(ground.call(Vector2(b.position.x,b.position.z))))
			below = below or b.position.y < float(ground.call(Vector2(b.position.x,b.position.z)))
	check(peak > 0.8, "Lift-off carries blades up: %.2f m" % peak)
	check(most <= Blades.CAPACITY and blades.multimesh.visible_instance_count <= Blades.CAPACITY, "Capacity respected: %d" % most)
	# Ribbon gone: they come back down and fade away.
	rib.list = []
	rib.updraft = 0.0
	for i in range(60*6):
		blades.advance(1.0/60.0, false, rib)
		for b in blades.blades: below = below or b.position.y < float(ground.call(Vector2(b.position.x,b.position.z)))
	check(blades.blades.is_empty(), "All fade out and are gone: %d left" % blades.blades.size())
	check(not below, "No blade ever below the ground")
	# Bare ground and water spawn nothing.
	blades.setup(ground, func(_p: Vector2) -> float: return 0.0)
	rib.list = [kick(at,0.5)]
	for i in range(60): blades.advance(1.0/60.0, false, rib)
	check(blades.blades.is_empty(), "No grass, no blades")
	blades.setup(func(_p: Vector2) -> Variant: return null, grass)
	for i in range(60): blades.advance(1.0/60.0, false, rib)
	check(blades.blades.is_empty(), "Over water, nothing spawns")
	# Old ribbons without the methods: a no-op.
	var plain := Node.new()
	blades.setup(ground, grass)
	blades.advance(0.1, false, plain)
	check(blades.blades.is_empty(), "A ribbons node without kicks is a no-op")
	plain.free()
	blades.free()
	rib.free()
	print("WIND KICKED BLADES: ", failures, " failures")
	quit(1 if failures else 0)
