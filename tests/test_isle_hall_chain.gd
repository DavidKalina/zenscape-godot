extends SceneTree
## The hall chain on the aqueduct isle (studies/aqueduct_isle.gd, studies/
## aqueduct_isle_chain.gd, docs/design/isle-hall-chain.md), headless: with
## the lodestone seated, the ring past the shard is hidden until the plane
## comes near, then rises and stands; the nose arrow keeps pointing at the
## shard, never the ring; crossing beside the ring does nothing; threading
## it starts nothing for the pause, then the pulse and the first hall
## rising ahead, its gate within a few degrees of the heading the plane left
## the ring on; the chain then runs on, the autopilot flying through 2+
## halls never stuck and never inside stone; and with the chain off
## (--no-chain) there is no ring and the old arrival flashes by the shard.
##   godot --headless --path . --script tests/test_isle_hall_chain.gd
const ChainPlan = preload("res://scripts/hall_chain_plan.gd")
const IsleChain = preload("res://studies/aqueduct_isle_chain.gd")
const DT := 1.0/60.0
var failures := 0
var study: Node3D

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(300.0).timeout.connect(func() -> void: push_error("isle hall chain test timed out"); quit(2))
	study = await _open(true)
	_hidden()
	_appears()
	_arrow()
	_beside()
	await _threads()
	await _runs_on()
	study.queue_free()
	await process_frame
	study = await _open(false)
	_no_chain()
	study.queue_free()
	await process_frame
	print("PASS: isle hall chain" if failures == 0 else "FAIL: isle hall chain (%d)" % failures)
	quit(1 if failures > 0 else 0)

## The isle with the stone carried, in the plane (the stone seated).
func _open(chain: bool) -> Node3D:
	var s: Node3D = load("res://studies/aqueduct_isle.tscn").instantiate()
	s.scripted = true
	s.chain_on = chain
	s._carry = true
	root.add_child(s)
	current_scene = s
	while not s.flora_ready: await process_frame
	await physics_frame
	s.board()
	return s

func _fly(seconds: float, input := {}) -> void:
	for i in range(int(seconds/DT)): study.fly_step(DT,input)

func _ahead(h: float) -> Vector3:
	return Vector3(-sin(h),0.0,-cos(h))

## A pursuit pilot at `aim` (as scripts/hall_chain.gd `steer`).
func _toward(aim: Vector3) -> Dictionary:
	var plane: RefCounted = study.plane
	var to: Vector3 = aim-plane.position
	var err := wrapf(ChainPlan.heading_of(to)-float(plane.heading),-PI,PI)
	var want_pitch := atan2(to.y,maxf(Vector2(to.x,to.z).length(),1.0))
	return {"turn":clampf(-err*3.0,-1.0,1.0),"pitch":clampf((want_pitch-float(plane.pitch))*2.5,-1.0,1.0)}

## Far off, nothing: the ring hidden and sunk.
func _hidden() -> void:
	var c: Node3D = study.isle_chain
	check(c != null and c.state == "hidden" and not c.ring.visible,"The ring is hidden at the start")
	check(c.ring_at.distance_to(study.lode_target) > 60.0 and Vector2(c.ring_at.x-85.0,c.ring_at.z+20.0).length() > IsleChain.HOLE.x+IsleChain.HOLE.y,"It stands past the shard, out over the cloud sea, clear of the isle (%.0f m from the isle's middle)" % Vector2(c.ring_at.x-85.0,c.ring_at.z+20.0).length())
	study.fly_from(c.ring_at-_ahead(c.ring_heading)*400.0,c.ring_heading)
	_fly(1.0)
	check(c.state == "hidden" and not c.ring.visible,"400 m off it is still hidden")

## Nearer: it rises out of the cloud, then stands, solid.
func _appears() -> void:
	var c: Node3D = study.isle_chain
	study.fly_from(c.ring_at-_ahead(c.ring_heading)*210.0,c.ring_heading)
	_fly(0.1)
	check(c.state == "rising" and c.ring.visible,"Within %.0f m it starts to rise" % IsleChain.RING_NEAR)
	var lift: Node3D = c._lift
	var top: float = c.ring.global_position.y+lift.position.y+_crown()
	check(top < IsleChain.SEA_TOP,"It starts under the cloud (its top %.1f m)" % top)
	_fly(IsleChain.RING_RISE+0.2)
	check(c.state == "standing" and lift.position.length() < 0.01,"Then it stands in place")
	var solid := 0
	for b: CollisionObject3D in c._bodies: if b.collision_layer != 0: solid += 1
	check(solid == c._bodies.size() and solid > 0,"And collides (%d bodies)" % solid)

## The arch's crown over its feet at the ring's scale (about).
func _crown() -> float:
	return 7.0*IsleChain.RING_SCALE

## The nose arrow still points at the shard.
func _arrow() -> void:
	var c: Node3D = study.isle_chain
	var nose: Node3D = study._nose
	check(nose != null and nose.target.distance_to(study.lode_target) < 0.01 and nose.target.distance_to(c.ring_at) > 50.0,"The nose arrow points at the shard, not the ring")

## Crossing the ring's plane beside it: nothing.
func _beside() -> void:
	var c: Node3D = study.isle_chain
	var right := Vector3(cos(c.ring_heading),0.0,-sin(c.ring_heading))
	var from: Vector3 = c.ring_at-_ahead(c.ring_heading)*45.0+right*18.0
	study.fly_from(from,c.ring_heading)
	var line: Vector3 = from+_ahead(c.ring_heading)*200.0
	for i in range(int(6.0/DT)): study.fly_step(DT,_toward(line))
	check(c.misses >= 1 and c.state == "standing" and c.chain.halls.is_empty(),"Flying past beside it triggers nothing (%d misses, %s)" % [c.misses,c.state])

## Threaded: a held breath, then the pulse and the first hall rising ahead.
func _threads() -> void:
	var c: Node3D = study.isle_chain
	var head: float = c.ring_heading+deg_to_rad(6.0)
	study.fly_from(c.ring_at-_ahead(head)*70.0,head)
	var steps := 0
	while c.state == "standing" and steps < int(10.0/DT):
		var p: Vector3 = study.plane.position
		var along: float = (p-c.ring_at).dot(_ahead(head))
		study.fly_step(DT,_toward(c.ring_at+_ahead(head)*(along+20.0)))
		steps += 1
	check(c.state == "passed","Threading the ring counts (%s)" % c.state)
	var waited := 0.0
	var quiet := true
	while c.state == "passed" and waited < 5.0:
		study.fly_step(DT,{})
		waited += DT
		if c.state == "passed" and (not c.chain.halls.is_empty() or study._plane_flash_left > 0.0): quiet = false
	check(quiet and absf(waited-c.pause) < 2.5*DT,"Then nothing for the pause (%.2f s, %.2f asked)" % [waited,c.pause])
	check(c.state == "started" and c.chain.halls.size() == 1,"Then the first hall rises")
	check(study._plane_flash_left > 0.0 and study._nose._pulse > 0.0,"And a pulse runs through the plane")
	var gate: Vector3 = c.first_gate()
	var off := absf(rad_to_deg(wrapf(ChainPlan.heading_of(gate-c.pass_point)-c.pass_heading,-PI,PI)))
	check(off < 3.0,"Its gate is %.2f degrees off the heading the plane left the ring on (%.0f m ahead)" % [off,Vector2(gate.x-c.pass_point.x,gate.z-c.pass_point.z).length()])
	var rise: Node3D = c.chain.halls[0].rise
	var broke := 0
	for b in rise.broke: broke += b
	check(broke == 0,"It starts under the cloud")
	await physics_frame

## The chain runs on: the autopilot flies through 2+ halls from the ring,
## never stuck and never inside stone, the next one rising each time.
func _runs_on() -> void:
	var c: Node3D = study.isle_chain
	var chain: Node3D = c.chain
	var at: int = chain.route_base
	var through := {}
	var gates := {}
	var stuck := 0
	var shut := 0
	var last: Vector3 = study.plane.position
	var bumps_from: int = study.bumps
	var steps := 0
	while through.size() < 2 and steps < int(90.0/DT):
		var got: Array = chain.steer(study.plane,at)
		at = got[1]
		study.fly_step(DT,got[0])
		steps += 1
		if steps % 4 == 0:
			await physics_frame
			if study._inside_stone(study.plane.position): shut += 1
		if steps % 60 == 59:
			if study.plane.position.distance_to(last) < 6.0: stuck += 1
			last = study.plane.position
		for h: Dictionary in chain.halls:
			if float(h.progress) >= 0.97: through[int(h.index)] = true
			var rise: Node3D = h.rise
			var local: Vector3 = ChainPlan.local(rise.to_local(study.plane.position),ChainPlan.hand_of(h.pose))
			if not gates.has(int(h.index)) and local.distance_to(ChainPlan.line()[0]) < 8.0:
				# The gate (the last chunk up): easing in or still by now.
				var g: int = rise.chunks.size()-1
				var cg: Dictionary = rise.chunks[g]
				var t := float(rise.clock)-float(rise.began_at[g])
				gates[int(h.index)] = rise.state[g] != "waiting" and (rise.state[g] != "moving" or t >= float(cg.t_in)+float(cg.t_run))
	check(through.has(0) and through.has(1),"The plane flies on through %d halls from the ring (%d made, %.0f s)" % [through.size(),chain.made,steps*DT])
	check(gates.get(0,false) and gates.get(1,false),"Each gate is easing in or settled as the plane gets to it (%s)" % gates)
	check(chain.made >= 3,"Each one sets the next rising (%d made)" % chain.made)
	check(stuck == 0 and float(study.plane.speed) >= 6.9,"Never stuck (%d bumps)" % (study.bumps-bumps_from))
	check(shut == 0,"Never inside stone")
	check(study.plane.position.y > IsleChain.SEA_TOP,"Over the cloud (y %.1f)" % study.plane.position.y)

## --no-chain: no ring, the shard where it was, the old arrival.
func _no_chain() -> void:
	check(study.isle_chain == null and study.get_node_or_null("IsleChain") == null,"--no-chain: no ring, no chain")
	check(study.lode_target.distance_to(study.SHARD_ONLY_TARGET) < 0.01,"The shard stands where it did")
	study.lode_target = study.plane.position+study.plane.forward()*12.0
	study.fly_step(DT,{})
	check(study.arrived and study._flash_left > 0.0,"Arriving by it flashes, as before")
