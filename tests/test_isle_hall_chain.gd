extends SceneTree
## suite: slow, serial
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
## its entry within a few degrees of the heading the plane left the ring on;
## then the Sundered line (docs/design/isle-hall-line.md): planned, its
## pieces whole, end to end and straight within runs, a flyable sidestep
## about every three; flown in real time (each piece the game's own
## Sundered hall, built on a worker: scripts/hall_line_build.gd), the
## autopilot goes on through seven pieces at cruise then boost, a sidestep
## among them, with no bump through the real collision, never inside
## stone, each piece whole and still as the plane gets to it and solid on
## the ruins' layer once still, its main-thread cost bounded, the oldest
## sinking past the cap; --chain-style=halls still gives the hall chain; and with the
## chain off (--no-chain) there is no ring and the old arrival flashes by
## the shard.
##   godot --headless --path . --script tests/test_isle_hall_chain.gd
const ChainPlan = preload("res://scripts/hall_chain_plan.gd")
const IsleChain = preload("res://studies/aqueduct_isle_chain.gd")
const LinePlan = preload("res://scripts/hall_line_plan.gd")
## Pieces the autopilot flies into at cruise, then holding boost.
const FLY_CRUISE := 4
const FLY_BOOST := 3
const SkyPlane = preload("res://scripts/sky_plane.gd")
const RuinBump = preload("res://scripts/ruin_bump.gd")
const LineBuild = preload("res://scripts/hall_line_build.gd")
## The most a real piece may cost the main thread in one frame (ms: its
## hand-over, its island stood, or one body of its collision).
const FRAME_BUDGET := 4.0
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
	_layout()
	study = await _open(true)
	_no_patch()
	_hidden()
	await _appears()
	_arrow()
	_beside()
	await _threads()
	_quiet()
	await _runs_on()
	_halls_style()
	_greybox_look()
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

## Nearer: it rises out of the cloud sea as the plane nears, seen rising,
## and stands a few seconds before the plane gets there at cruise or boost
## (not half a minute early: woken from the isle's edge it seemed always to
## be there), then stands, solid.
func _appears() -> void:
	var c: Node3D = study.isle_chain
	var still: float = c.ring_length()
	for v: float in [SkyPlane.CRUISE_SPEED,SkyPlane.BOOST_SPEED]:
		var d := _wake_distance(c,v)
		check(d/v-still > 2.0 and d/v-still < 8.0,"At %.0f m/s it wakes %.0f m out: still %.1f s after, the plane there %.1f s after" % [v,d,still,d/v])
	var from_isle: float = Vector2(c.ring_at.x-85.0,c.ring_at.z+20.0).length()
	check(_wake_distance(c,SkyPlane.CRUISE_SPEED) < from_isle-200.0,"At cruise it wakes well out from the isle (%.0f m from the ring, the isle %.0f m)" % [_wake_distance(c,SkyPlane.CRUISE_SPEED),from_isle])
	check(c.wakes(c.ring_at-_ahead(c.ring_heading)*300.0,SkyPlane.FAST) and not c.wakes(c.ring_at-_ahead(c.ring_heading)*300.0,SkyPlane.CRUISE_SPEED),"Diving fast it wakes sooner (from 300 m at %.0f m/s, not at cruise)" % SkyPlane.FAST)
	study.fly_from(c.ring_at-_ahead(c.ring_heading)*(c.ring_near-10.0),c.ring_heading)
	_fly(0.1)
	check(c.state == "rising" and c.ring.visible,"Within %.0f m it starts to rise" % c.ring_near)
	var lift: Node3D = c._lift
	var top: float = c.ring.global_position.y+lift.position.y+IsleChain.RING_CROWN
	check(top < IsleChain.SEA_TOP,"It starts under the cloud sea's top (its crown at %.1f m)" % top)
	var broke_at := -1.0
	var puffs := 0
	var t := 0.1
	# Braked: started inside ring_near (as no flown approach is), the game's
	# cruise (SkyPlane GAME_SPEED) would have it at the ring as it stands.
	while c.state == "rising" and t < still+1.0:
		study.fly_step(DT,{"brake":1.0})
		t += DT
		if broke_at < 0.0 and c.ring_broke:
			broke_at = t
			puffs = c.burst.count()
	check(broke_at > 0.0 and puffs > 0,"It bursts out of the cloud in puffs (%.1f s in, %d puffs)" % [broke_at,puffs])
	check(c.state == "standing" and lift.position.length() < 0.01 and absf(t-still) < 0.15,"Then it stands in place (%.1f s)" % t)
	var solid := 0
	for b: CollisionObject3D in c._bodies: if b.collision_layer != 0: solid += 1
	check(solid == c._bodies.size() and solid > 0,"And collides (%d bodies)" % solid)
	# In play the ring takes its 8.6 s to rise, in real time: the line's
	# first piece is built on a worker meanwhile (from when it woke), and
	# what its island first stands with made a frame at a time.
	var line: Node3D = c.chain
	# (Waited for well back: the ring now wakes only some 13 s out, so
	# flying on from here would thread it.)
	study.fly_from(c.ring_at-_ahead(c.ring_heading)*600.0,c.ring_heading)
	var waited := 0
	while line.look == "real" and (not line.built(0) or not line._warm.is_empty()) and waited < 600:
		study.fly_step(DT,{})
		waited += 1
		await physics_frame
	check(line.look != "real" or line.built(0),"The line's first piece is built while the ring rises (%.1f s more)" % (waited*DT))

## How far out the ring wakes for a plane at `speed` (m, to the metre).
func _wake_distance(c: Node3D, speed: float) -> float:
	var d := 1000.0
	while d > 0.0 and not c.wakes(c.ring_at-_ahead(c.ring_heading)*d,speed): d -= 1.0
	return d

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
	check(off < 3.0 and ahead >= c.lead+c.lead_in()-1.0,"The first gate is %.2f degrees off the heading the plane left the ring on (%.0f m ahead, way in %.0f m)" % [off,ahead,c.lead_used])
	var rise: Node3D = c.chain.halls[0].rise
	var arrive: float = ahead/maxf(c.pass_speed,SkyPlane.CRUISE_SPEED)
	check(float(rise.plan.length)+c.spare <= arrive+0.05,"At the plane's speed its gate is still %.1f s after threading, %.1f s before the plane gets there" % [float(rise.plan.length),arrive-float(rise.plan.length)])
	var need: float = SkyPlane.BOOST_SPEED*(float(c.chain.length_at(c.first_y()))+c.spare)-c.lead_in()
	check(need > c.lead_used+20.0,"Threaded at boost, its way in would stand %.0f m on (%.0f at cruise)" % [need,c.lead_used])
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

## The line runs on: the autopilot flies on from the ring through FLY_CRUISE
## pieces at cruise, then holding boost through FLY_BOOST more, a sidestep
## among them, in real time (a physics frame a step: the pieces are built
## on a worker as they would be in play): never stuck, never a bump, never
## inside stone; every piece the real build, whole (one chunk: the hall's
## near and far detail and its island) and still as the plane gets to its
## entry, at either speed, solid on the ruins' layer once still; no frame's
## hand-over over FRAME_BUDGET; the oldest sinking past the cap.
func _runs_on() -> void:
	var c: Node3D = study.isle_chain
	var line: Node3D = c.chain
	var at: int = line.route_base
	var arrived := {}
	var kinds := {}
	var shut := 0
	var bumps_from: int = study.bumps
	var steps := 0
	var whole := true
	var sank := false
	var most := 0
	var boost := 0.0
	var boosted_from := -1
	var solid := {}
	var real: bool = line.look == "real"
	while arrived.size() < FLY_CRUISE+FLY_BOOST and steps < int(150.0/DT):
		if arrived.size() >= FLY_CRUISE and boost == 0.0:
			boost = 1.0
			boosted_from = arrived.size()
		var got: Array = line.steer(study.plane,at)
		at = got[1]
		var input: Dictionary = got[0]
		input.boost = boost
		study.fly_step(DT,input)
		steps += 1
		await physics_frame
		if steps % 4 == 0 and study._inside_stone(study.plane.position): shut += 1
		most = maxi(most,line.standing_count())
		for h: Dictionary in line.halls:
			var rise: Node3D = h.rise
			if rise.sinking: sank = true
			if not _whole(rise,h): whole = false
			if rise.state[0] == "set" and not solid.has(int(h.index)):
				var bodies := 0
				var on := 0
				for b: StaticBody3D in rise._bodies_stood[0]:
					bodies += 1
					if b.collision_layer == RuinBump.LAYER: on += 1
				solid[int(h.index)] = [bodies,on,(rise.chunks[0].get("bodies",[]) as Array).size()]
			if bool(h.reached) and not arrived.has(int(h.index)):
				arrived[int(h.index)] = [rise.state[0] in ["pending","set"],boost > 0.0,snappedf(float(study.plane.speed),0.1)]
				kinds[str(h.pose.kind)] = int(kinds.get(str(h.pose.kind),0))+1
	var still := true
	var at_boost := 0
	for i: int in arrived:
		if not arrived[i][0]: still = false
		if arrived[i][1]: at_boost += 1
	check(arrived.size() >= FLY_CRUISE+FLY_BOOST,"The autopilot flies on from the ring into %d pieces (%d made, %.0f s)" % [arrived.size(),line.made,steps*DT])
	check(real and whole,"Every piece is the real Sundered build and rises whole: one chunk, its hall's near and far detail and its island in it")
	var solid_ok := solid.size() >= FLY_CRUISE+FLY_BOOST-1
	for i: int in solid:
		if solid[i][0] != solid[i][2] or solid[i][1] != solid[i][0] or solid[i][0] < 20: solid_ok = false
	check(solid_ok,"Once still, every body of each piece stands on the ruins' layer ([stood, on the layer, built]: %s)" % solid)
	check(still and at_boost >= FLY_BOOST-1,"Every piece is still as the plane reaches its entry, at cruise and at boost (%d at boost): %s" % [at_boost,arrived])
	check(kinds.has("jog"),"A sidestep is flown among them (%s)" % kinds)
	check(study.bumps-bumps_from == 0,"Never a bump (%d)" % (study.bumps-bumps_from))
	check(shut == 0,"Never inside stone")
	check(sank and most <= line.keep,"Past the cap the oldest sinks (at most %d standing)" % most)
	check(study.plane.position.y > IsleChain.SEA_TOP+60.0,"High over the cloud (y %.1f)" % study.plane.position.y)
	var worst := 0.0
	var take := 0.0
	var bodies := 0.0
	var build := 0.0
	for s: Dictionary in line.spawns:
		worst = maxf(worst,int(s.frame)/1000.0)
		take = maxf(take,(int(s.setup)+int(s.take))/1000.0)
		bodies = maxf(bodies,int(s.bodies)/1000.0)
		build = maxf(build,int(s.build)/1000.0)
	check(worst < FRAME_BUDGET,"No hitch: the heaviest frame's main-thread cost %.2f ms (a hand-over and its island %.2f, a body %.2f; the worker's build at most %.0f ms)" % [worst,take,bodies,build])

## Whether a piece's rise is the real build, whole: one chunk, made (its
## node, the hall's near and far detail and, once taken, its island).
func _whole(rise: Node3D, h: Dictionary) -> bool:
	if rise.chunks.size() != 1 or not (rise.chunks[0] as Dictionary).has("node") or (h.made as Dictionary).is_empty(): return false
	var node: Node3D = rise.nodes[0]
	if node == null: return true
	return node.get_node_or_null("Near") != null and node.get_node_or_null("Far") != null and node.get_node_or_null("Island") != null

## The layout, as planned (no scene): pieces end to end and straight
## within runs, Sundered gaps, a sidestep about every three (parallel, to
## the side, flyable at boost), the same for the same seed; and a bend line.
func _layout() -> void:
	var cfg := LinePlan.settings({})
	var pieces := _plan(cfg,40)
	var straight := true
	var gaps_ok := true
	var jogs := 0
	var jog_ok := true
	var runs := []
	var run := 1
	var worst_rate := 0.0
	var worst_off := 0.0
	var shortest := INF
	for i in range(1,pieces.size()):
		var a: Dictionary = pieces[i-1]
		var b: Dictionary = pieces[i]
		var d: Vector3 = b.entry-a.exit
		var flat := Vector3(d.x,0.0,d.z)
		var along := flat.dot(LinePlan.ahead(float(a.yaw)))
		var across := flat.dot(LinePlan.right(float(a.yaw)))
		if b.kind == "gap":
			run += 1
			if absf(across) > 0.01 or absf(float(b.yaw)-float(a.yaw)) > 1e-5: straight = false
			if along < 14.0-0.01 or along > 26.0+0.01 or absf(d.y) > 3.01 or absf(d.y) > along*LinePlan.GRADE+0.01: gaps_ok = false
		else:
			runs.append(run)
			run = 1
			jogs += 1
			if b.kind != "jog" or absf(float(b.yaw)-float(a.yaw)) > 1e-5 or absf(absf(across)-48.0) > 48.0*0.16 or along < 100.0: jog_ok = false
			shortest = minf(shortest,along)
			var m := _gap_motion(a,b)
			worst_rate = maxf(worst_rate,SkyPlane.BOOST_SPEED/m.x)
			worst_off = maxf(worst_off,m.y)
	check(straight,"Within a run the pieces stand end to end, dead straight on one heading")
	check(gaps_ok,"Their gaps are Sundered's: 14-26 m of sky, a step of at most 3 m")
	var mean := 0.0
	for r: int in runs: mean += r
	mean /= maxf(runs.size(),1)
	check(jogs >= 8 and runs.min() >= 2 and runs.max() <= 4 and mean > 2.4 and mean < 3.6,"A sidestep about every three pieces (%d in 40; runs %s, mean %.1f)" % [jogs,runs,mean])
	check(jog_ok,"Each sidestep sets the next run parallel, about 48 m to the side, over a gap of at least 100 m (shortest %.0f m)" % shortest)
	check(worst_rate < SkyPlane.TURN_RATE*0.6 and worst_off < 50.0,"Flyable at boost: at most %.2f rad/s of turn (the plane can %.1f), at most %.0f degrees off the run's heading" % [worst_rate,SkyPlane.TURN_RATE,worst_off])
	var overlap := 0
	for i in range(pieces.size()):
		for j in range(i+1,pieces.size()):
			if not Geometry2D.intersect_polygons(LinePlan.footprint(pieces[i]),LinePlan.footprint(pieces[j])).is_empty(): overlap += 1
	check(overlap == 0,"No two pieces' islands overlap")
	var drift := 0.0
	for p: Dictionary in pieces: drift = maxf(drift,absf(float(p.offset)))
	check(drift < 48.0*1.2+10.0,"The sidesteps lean back: never more than %.0f m off the first run's axis" % drift)
	var again := _plan(cfg,40)
	var same := true
	for i in range(pieces.size()):
		if (pieces[i].entry as Vector3).distance_to(again[i].entry) > 1e-4 or pieces[i].bays != again[i].bays: same = false
	check(same,"The same seed gives the same line")
	var t := LinePlan.template(pieces[1])
	check(t.chunks.size() == 1 and (t.chunks[0].solids as Array).size() == t.solids.size() and (t.chunks[0].extra as Array).size() == int(pieces[1].bays),"A piece is one chunk: all %d of its bays' solids and its island's %d hulls" % [t.solids.size(),int(pieces[1].bays)])
	var length := float(pieces[1].length)
	check(length >= 64.0 and float(t.chunks[0].hi.y)-float(t.chunks[0].lo.y) > 30.0,"A big piece: %.0f m of nave, %.0f m from keel to wall top" % [length,float(t.chunks[0].hi.y)-float(t.chunks[0].lo.y)])
	# The bend line.
	var bends := _plan(LinePlan.settings({"turn":"bend"}),40)
	var turned := 0
	var wander := 0.0
	var h0 := float(bends[0].yaw)
	for i in range(1,bends.size()):
		if bends[i].kind == "bend":
			turned += 1
			var m := _gap_motion(bends[i-1],bends[i])
			worst_rate = maxf(worst_rate,SkyPlane.BOOST_SPEED/m.x)
		wander = maxf(wander,absf(wrapf(float(bends[i].yaw)-h0,-PI,PI)))
	check(turned >= 8 and rad_to_deg(wander) < 40.0 and worst_rate < SkyPlane.TURN_RATE*0.6,"--line-turn=bend: %d bends, never more than %.0f degrees off the first heading, at most %.2f rad/s at boost" % [turned,rad_to_deg(wander),worst_rate])

func _plan(cfg: Dictionary, n: int) -> Array:
	var out := [LinePlan.first(int(cfg.seed),cfg,Vector3(0.0,25.0,0.0),0.4)]
	for i in range(n-1): out.append(LinePlan.next(out[-1],cfg))
	return out

## Over a gap's lane: its tightest turn's radius (m) and the most it swings
## off the first run's heading (degrees).
func _gap_motion(a: Dictionary, b: Dictionary) -> Vector2:
	var pts := [a.exit]
	for k in range(1,201): pts.append(LinePlan.gap_point(a,b,k/200.0))
	var tight := INF
	var off := 0.0
	for k in range(1,pts.size()-1):
		var p0: Vector3 = pts[k-1]
		var p1: Vector3 = pts[k]
		var p2: Vector3 = pts[k+1]
		var h1 := LinePlan.heading_of(p1-p0)
		var h2 := LinePlan.heading_of(p2-p1)
		var turn := absf(wrapf(h2-h1,-PI,PI))
		var step := Vector2(p2.x-p1.x,p2.z-p1.z).length()
		if turn > 1e-6: tight = minf(tight,step/turn)
		off = maxf(off,rad_to_deg(absf(wrapf(h1-float(a.yaw),-PI,PI))))
	return Vector2(tight,off)

## --chain-style=halls still gives the old hall chain, its first hall
## placed dead ahead of the threading.
func _halls_style() -> void:
	var c: Node3D = IsleChain.new()
	study.add_child(c)
	c.setup(study.lode_target,PackedStringArray(["--chain-style=halls"]))
	check(c.style == "halls" and c.chain.get("template_left") != null,"--chain-style=halls: the hall chain")
	c.pass_point = c.ring_at
	c.pass_heading = c.ring_heading
	c.pass_speed = SkyPlane.CRUISE_SPEED
	c._place_first()
	var gate: Vector3 = c.first_gate()
	var off := absf(rad_to_deg(wrapf(ChainPlan.heading_of(gate-c.pass_point)-c.pass_heading,-PI,PI)))
	check(c.chain.halls.size() == 1 and c.chain.halls[0].rise.chunks.size() == 4 and off < 3.0,"Its first hall rises in its four chunks, its gate %.2f degrees off the heading" % off)
	c.queue_free()

## --line-look=greybox: round 1's look, the greybox piece drawn on a
## worker as before (no real build).
func _greybox_look() -> void:
	var c: Node3D = IsleChain.new()
	study.add_child(c)
	c.setup(study.lode_target,PackedStringArray(["--line-look=greybox"]))
	var t: Dictionary = c.chain._first_template
	check(c.chain.look == "greybox" and not t.has("made") and (t.chunks[0].solids as Array).size() == t.solids.size() and t.solids.size() > 0 and c.chain.islets == null,"--line-look=greybox: the greybox piece (%d solids), no real build" % t.solids.size())
	c.queue_free()

## --no-chain: no ring, the shard where it was, the old arrival.
func _no_chain() -> void:
	check(study.isle_chain == null and study.get_node_or_null("IsleChain") == null,"--no-chain: no ring, no chain")
	check(study.lode_target.distance_to(study.SHARD_ONLY_TARGET) < 0.01,"The shard stands where it did")
	study.lode_target = study.plane.position+study.plane.forward()*12.0
	study.fly_step(DT,{})
	check(study.arrived and study._flash_left > 0.0,"Arriving by it flashes, as before")
