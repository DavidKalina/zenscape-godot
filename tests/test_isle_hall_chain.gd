extends SceneTree
## The hall chain on the aqueduct isle (studies/aqueduct_isle.gd, studies/
## aqueduct_isle_chain.gd, docs/design/isle-hall-chain.md), headless: no
## greybox cloud of its own (the game's cloud sea, the game's puffs); with
## the lodestone seated, the ring past the shard is hidden until the plane
## comes near (early enough to be still well before it gets there, at
## cruise or boost), then rises out of the sea and stands; the nose arrow
## keeps pointing at the shard, never the ring; crossing beside the ring
## does nothing; threading it sets the first hall rising unseen under the
## cloud and nothing shows for the pause, then the pulse, the nose arrow
## folding quiet (no more tracking) and the first hall breaking out ahead,
## its gate within a few degrees of the heading the plane left the ring on;
## the chain then runs on, the autopilot flying through 2+ halls never
## stuck and never inside stone, each gate still as the plane gets to it;
## and with the chain off (--no-chain) there is no ring and the old arrival
## flashes by the shard.
##   godot --headless --path . --script tests/test_isle_hall_chain.gd
const ChainPlan = preload("res://scripts/hall_chain_plan.gd")
const IsleChain = preload("res://studies/aqueduct_isle_chain.gd")
const SkyPlane = preload("res://scripts/sky_plane.gd")
const NoseCompass = preload("res://scripts/nose_compass.gd")
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
	_no_patch()
	_hidden()
	_appears()
	_arrow()
	_beside()
	await _threads()
	_quiet()
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

## No cloud of its own: the greybox patch is gone, and what bursts from the
## sea is the game's own cloud puff.
func _no_patch() -> void:
	var c: Node3D = study.isle_chain
	var found := []
	_find_patch(study,found)
	check(found.is_empty() and c.get_node_or_null("CloudSea") == null and not ResourceLoader.exists("res://shaders/isle_cloud_sea.gdshader"),"No greybox cloud patch in the scene %s" % [found])
	var puff: ShaderMaterial = c.burst.material_override
	check(puff != null and puff.shader.resource_path == "res://shaders/sky_cloud_puff.gdshader" and c.chain.burst == c.burst,"The bursts are the game's own cloud puffs, shared with the chain")
	check(IsleChain.SEA_TOP < -100.0 and IsleChain.SEA_TOP > -110.0,"Things break out of the game's near cloud sea (its top %.0f m)" % IsleChain.SEA_TOP)

func _find_patch(node: Node, out: Array) -> void:
	if node is MeshInstance3D and not node.name.begins_with("SkySea"):
		var m := (node as MeshInstance3D).material_override as ShaderMaterial
		var mesh := (node as MeshInstance3D).mesh
		if m == null and mesh is PrimitiveMesh: m = (mesh as PrimitiveMesh).material as ShaderMaterial
		if m != null and m.shader != null and m.shader.resource_path.contains("cloud_sea"): out.append(node.name)
	for child in node.get_children(): _find_patch(child,out)

## Far off, nothing: the ring hidden and sunk.
func _hidden() -> void:
	var c: Node3D = study.isle_chain
	check(c != null and c.state == "hidden" and not c.ring.visible,"The ring is hidden at the start")
	check(c.ring_at.distance_to(study.lode_target) > 60.0 and Vector2(c.ring_at.x-85.0,c.ring_at.z+20.0).length() > 300.0,"It stands past the shard, clear of the isle (%.0f m from the isle's middle)" % Vector2(c.ring_at.x-85.0,c.ring_at.z+20.0).length())
	study.fly_from(c.ring_at-_ahead(c.ring_heading)*600.0,c.ring_heading)
	_fly(1.0)
	check(c.state == "hidden" and not c.ring.visible,"600 m off it is still hidden")

## Nearer: it rises out of the cloud sea, early enough to stand still well
## before the plane gets there even at boost, then stands, solid.
func _appears() -> void:
	var c: Node3D = study.isle_chain
	var still: float = c.ring_length()
	var boost_eta: float = c.ring_near/SkyPlane.BOOST_SPEED
	check(boost_eta-still > 5.0 and c.ring_near/SkyPlane.CRUISE_SPEED-still > 15.0,"It wakes %.0f m out: still %.1f s after, the plane there %.1f s after at cruise, %.1f s at boost" % [c.ring_near,still,c.ring_near/SkyPlane.CRUISE_SPEED,boost_eta])
	check(c.wakes(c.ring_at-_ahead(c.ring_heading)*470.0,SkyPlane.FAST) and not c.wakes(c.ring_at-_ahead(c.ring_heading)*470.0,SkyPlane.CRUISE_SPEED),"Diving fast it wakes sooner (from 470 m at %.0f m/s, not at cruise)" % SkyPlane.FAST)
	study.fly_from(c.ring_at-_ahead(c.ring_heading)*(c.ring_near-10.0),c.ring_heading)
	_fly(0.1)
	check(c.state == "rising" and c.ring.visible,"Within %.0f m it starts to rise" % c.ring_near)
	var lift: Node3D = c._lift
	var top: float = c.ring.global_position.y+lift.position.y+IsleChain.RING_CROWN
	check(top < IsleChain.SEA_TOP,"It starts under the cloud sea's top (its crown at %.1f m)" % top)
	var broke_at := -1.0
	var puffs := 0
	var t := 0.1
	while c.state == "rising" and t < still+1.0:
		study.fly_step(DT,{})
		t += DT
		if broke_at < 0.0 and c.ring_broke:
			broke_at = t
			puffs = c.burst.count()
	check(broke_at > 0.0 and puffs > 0,"It bursts out of the cloud in puffs (%.1f s in, %d puffs)" % [broke_at,puffs])
	check(c.state == "standing" and lift.position.length() < 0.01 and absf(t-still) < 0.15,"Then it stands in place (%.1f s)" % t)
	var solid := 0
	for b: CollisionObject3D in c._bodies: if b.collision_layer != 0: solid += 1
	check(solid == c._bodies.size() and solid > 0,"And collides (%d bodies)" % solid)

## The nose arrow still points at the shard.
func _arrow() -> void:
	var c: Node3D = study.isle_chain
	var nose: Node3D = study._nose
	check(nose != null and nose.target.distance_to(study.lode_target) < 0.01 and nose.target.distance_to(c.ring_at) > 50.0 and not nose.quieting,"The nose arrow points at the shard, not the ring")

## Crossing the ring's plane beside it: nothing.
func _beside() -> void:
	var c: Node3D = study.isle_chain
	var right := Vector3(cos(c.ring_heading),0.0,-sin(c.ring_heading))
	var from: Vector3 = c.ring_at-_ahead(c.ring_heading)*45.0+right*18.0
	study.fly_from(from,c.ring_heading)
	var line: Vector3 = from+_ahead(c.ring_heading)*200.0
	for i in range(int(6.0/DT)): study.fly_step(DT,_toward(line))
	check(c.misses >= 1 and c.state == "standing" and c.chain.halls.is_empty(),"Flying past beside it triggers nothing (%d misses, %s)" % [c.misses,c.state])

## Threaded: the first hall rising unseen, a held breath, then the pulse
## and the hall breaking out ahead.
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
	check(c.chain.halls.size() == 1 and c.chain.halls[0].rise.playing,"The first hall starts rising at once, unseen under the cloud")
	var waited := 0.0
	var quiet := true
	while c.state == "passed" and waited < 5.0:
		study.fly_step(DT,{})
		waited += DT
		if c.state == "passed":
			var shown := 0
			for b in c.chain.halls[0].rise.broke: shown += b
			if shown > 0 or study._plane_flash_left > 0.0 or study._nose.quieting: quiet = false
	check(quiet and absf(waited-c.pause) < 2.5*DT,"Then nothing shows for the pause: no chunk through the cloud, no flash (%.2f s, %.2f asked)" % [waited,c.pause])
	check(c.state == "started" and c.chain.halls.size() == 1,"Then the pulse")
	check(study._plane_flash_left > 0.0 and study._nose._pulse > 0.0,"A pulse runs through the plane")
	var gate: Vector3 = c.first_gate()
	var off := absf(rad_to_deg(wrapf(ChainPlan.heading_of(gate-c.pass_point)-c.pass_heading,-PI,PI)))
	var ahead := Vector2(gate.x-c.pass_point.x,gate.z-c.pass_point.z).length()
	check(off < 3.0 and ahead >= c.lead+ChainPlan.LEAD_IN-1.0,"The first gate is %.2f degrees off the heading the plane left the ring on (%.0f m ahead, way in %.0f m)" % [off,ahead,c.lead_used])
	var rise: Node3D = c.chain.halls[0].rise
	var arrive: float = ahead/maxf(c.pass_speed,SkyPlane.CRUISE_SPEED)
	check(float(rise.plan.length)+c.spare <= arrive+0.05,"At the plane's speed its gate is still %.1f s after threading, %.1f s before the plane gets there" % [float(rise.plan.length),arrive-float(rise.plan.length)])
	var need: float = SkyPlane.BOOST_SPEED*(float(c.chain.length_at(c.pass_point.y-2.0))+c.spare)-ChainPlan.LEAD_IN
	check(need > c.lead_used+50.0,"Threaded at boost, its way in would stand %.0f m on (%.0f at cruise)" % [need,c.lead_used])
	var through := 0
	for i in range(int(0.4/DT)):
		study.fly_step(DT,{})
		for b in rise.broke: through += b
		if through > 0: break
	check(through > 0,"Its first chunk breaks out of the cloud as the pulse runs")
	await physics_frame

## After the pulse the nose arrow folds down quiet: it stops tracking, lies
## along the nose and dims, gently (no pop).
func _quiet() -> void:
	var nose: Node3D = study._nose
	check(nose.quieting and nose.quieted < 0.3,"The arrow begins to fold quiet with the pulse (%.2f)" % nose.quieted)
	var pivot: Node3D = nose._pivot
	var last: Quaternion = pivot.basis.get_rotation_quaternion()
	var worst := 0.0
	for i in range(int((NoseCompass.QUIET_TIME+0.3)/DT)):
		study.fly_step(DT,{})
		var q: Quaternion = pivot.basis.get_rotation_quaternion()
		worst = maxf(worst,rad_to_deg(last.angle_to(q)))
		last = q
	check(worst < 3.0,"Gently: at most %.2f degrees a frame" % worst)
	var to_rest := rad_to_deg(pivot.basis.get_rotation_quaternion().angle_to(NoseCompass.rest().get_rotation_quaternion()))
	check(nose.quieted >= 1.0 and to_rest < 0.5,"Then it lies along the nose, tipped down (%.2f degrees off)" % to_rest)
	var glow: StandardMaterial3D = nose._glow
	check(glow.emission_energy_multiplier < 0.2,"And dims (glow %.2f, 0.8 or more while it tracked)" % glow.emission_energy_multiplier)
	var was: Quaternion = pivot.basis.get_rotation_quaternion()
	var keep: Vector3 = study.lode_target
	study.lode_target = study.plane.position+Vector3(300.0,80.0,0.0)
	_fly(0.5)
	check(rad_to_deg(was.angle_to(pivot.basis.get_rotation_quaternion())) < 0.01,"And no longer tracks")
	study.lode_target = keep

## The chain runs on: the autopilot flies through 2+ halls from the ring,
## never stuck and never inside stone, the next one rising each time, each
## gate still as the plane gets to it.
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
				# The gate (the last chunk up): still in its place by now.
				var g: int = rise.chunks.size()-1
				gates[int(h.index)] = rise.state[g] in ["pending","set"]
	check(through.has(0) and through.has(1),"The plane flies on through %d halls from the ring (%d made, %.0f s)" % [through.size(),chain.made,steps*DT])
	check(gates.get(0,false) and gates.get(1,false),"Each gate is still as the plane gets to it at cruise (%s)" % gates)
	check(chain.made >= 3,"Each one sets the next rising (%d made)" % chain.made)
	check(stuck == 0 and float(study.plane.speed) >= 6.9,"Never stuck (%d bumps)" % (study.bumps-bumps_from))
	check(shut == 0,"Never inside stone")
	check(study.plane.position.y > IsleChain.SEA_TOP+60.0,"High over the cloud (y %.1f)" % study.plane.position.y)

## --no-chain: no ring, the shard where it was, the old arrival.
func _no_chain() -> void:
	check(study.isle_chain == null and study.get_node_or_null("IsleChain") == null,"--no-chain: no ring, no chain")
	check(study.lode_target.distance_to(study.SHARD_ONLY_TARGET) < 0.01,"The shard stands where it did")
	study.lode_target = study.plane.position+study.plane.forward()*12.0
	study.fly_step(DT,{})
	check(study.arrived and study._flash_left > 0.0,"Arriving by it flashes, as before")
