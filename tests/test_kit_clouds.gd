extends SceneTree
## The aqueduct isle's clouds (scripts/kit_isle/kit_clouds.gd, through the
## cloud host, scripts/cloud_host.gd), headless: the sky has a cloud host,
## the look pass finds it (and still finds the old game's islands), and the
## cloud volume reads its towers and wakes; the towers stand where nothing
## else does (clear of the lock ring, every motif isle and the chain's
## line), with no peak ring laid; they rise, stand,
## wane and rise again, and never drift; the puffs drift, clear of the isle,
## the isles and the towers; the CPU planes are flown through the puffs and
## tear them; the player's plane tears a puff and a tower, and the volume
## gets the tunnel; and the scene freed while a tower bakes leaves nothing.
## Headless: no drawing, only the clouds' lives, places and data. The cost
## of a frame of the clouds is printed (µs on the main thread).
##   godot --headless --path . --script tests/test_kit_clouds.gd
const KitClouds = preload("res://scripts/kit_isle/kit_clouds.gd")
const CloudHost = preload("res://scripts/cloud_host.gd")
const SkyTowers = preload("res://scripts/sky_towers.gd")
const SkyTower = preload("res://scripts/sky_tower.gd")
const SkyClouds = preload("res://scripts/sky_clouds.gd")
const CloudWakes = preload("res://scripts/cloud_wakes.gd")
const CloudVolume = preload("res://scripts/cloud_volume.gd")
const LookPass = preload("res://scripts/look_pass.gd")
const SkyWorld = preload("res://scripts/sky_world.gd")
const SkyCommits = preload("res://scripts/sky_commits.gd")
const DT := 1.0/30.0
var failures := 0
var study: Node3D
var host: Node3D

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(240.0).timeout.connect(func() -> void: push_error("kit clouds test timed out"); quit(2))
	study = load("res://studies/aqueduct_isle.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.isle_up: await process_frame
	host = study.cloud_host()
	check(host != null and host == study.sky.clouds and host is KitClouds,"The sky has a cloud host, and the scene answers with it")
	check(host.towers is SkyTowers and host.clouds is SkyClouds and host.wakes is CloudWakes,"It holds the towers, the drifting clouds and the wakes")
	_seam()
	_places()
	await _towers_live()
	_puffs()
	_traffic()
	await _plane_tears()
	await _teardown()
	print("PASS: kit clouds" if failures == 0 else "FAIL: kit clouds (%d)" % failures)
	quit(1 if failures > 0 else 0)

## The look pass's seam: the kit's host, and the old game's islands through
## its wanderer; the cloud volume reads the host's towers and wakes.
func _seam() -> void:
	check(LookPass.host_of(study) == host,"The look pass finds the kit's host through the scene")
	var old := OldScene.new()
	old.wanderer = Wanderer.new()
	old.wanderer.islands = Node3D.new()
	check(LookPass.host_of(old) == old.wanderer.islands,"and the old game's islands through its wanderer")
	var bare := Node3D.new()
	check(LookPass.host_of(bare) == null,"and none where there is neither")
	bare.free()
	old.wanderer.islands.free()
	old.wanderer.free()
	old.free()
	var volume: Node3D = CloudVolume.new()
	volume.update(study.camera,null,host,null,0.0)
	check(volume.towers == host.towers and volume.wakes == host.wakes,"The cloud volume reads the host's towers and wakes")
	volume.free()

class OldScene extends Node3D:
	var wanderer: Node
class Wanderer extends Node:
	var islands: Node3D

## Every tower clear of what the sky lays, the lock ring and the chain's
## line; spots in the way left out; no peak ring laid for them.
func _places() -> void:
	var spots: Array = host.spots()
	check(spots.size() == KitClouds.TOWERS.size() and host.towers.fixed == spots,"Every tower of the aqueduct's stands (%d)" % spots.size())
	var c: Vector3 = study.isle_circle()
	var ring: float = host.lock_reach()
	var line: Array = host.chain_line()
	check(line.size() == 2 and study.isle_chain != null,"The chain's line runs out past the ring")
	var worst := INF
	for at: Vector3 in spots:
		var flat := Vector2(at.x,at.z)
		var gaps := [flat.distance_to(Vector2(c.x,c.y))-ring,KitClouds._to_segment(flat,line[0],line[1])]
		for place: Array in study.sky.places(): gaps.append(flat.distance_to(Vector2(place[1].x,place[1].z))-float(place[2]))
		worst = minf(worst,gaps.min())
	check(study.sky.places().size() >= 4,"The motif isles are among what they keep off (%d)" % study.sky.places().size())
	check(worst >= SkyTowers.KEEP,"Each keeps the old game's keep (%.0f m) from the lock ring, the motif isles and the chain's line (closest %.0f m)" % [SkyTowers.KEEP,worst])
	var home: Vector3 = spots[0]
	var off := Vector2(home.x-c.x,home.z-c.y).length()
	check(off < 1000.0,"The first stands in sight of the isle (%.0f m off)" % off)
	check(host.clear_of_play(Vector3(c.x,0.0,c.y)) == "lock ring","A tower on the isle is left out (the lock ring)")
	var on_line: Vector2 = (line[0] as Vector2).lerp(line[1],0.8)
	check(host.clear_of_play(Vector3(on_line.x,0.0,on_line.y)) == "chain","A tower on the chain's line is left out")
	var isle0: Vector3 = study.sky.places()[3][1]
	check(host.clear_of_play(isle0) != "","A tower on a motif isle is left out (%s)" % host.clear_of_play(isle0))
	check(SkyWorld._layout.is_empty(),"No peak ring was laid for the clouds (SkyWorld layout untouched)")

## The towers built on workers round the eye, the home one about to rise;
## each life rises, stands, wanes and rises again; none drifts.
func _towers_live() -> void:
	var towers: Node3D = host.towers
	var frames := 0
	SkyCommits.recording = true
	while towers.built.size() < KitClouds.TOWERS.size() and frames < 1200:
		await process_frame
		frames += 1
	check(towers.built.size() == KitClouds.TOWERS.size(),"Every tower is made on a worker and stood (%d in %d frames)" % [towers.built.size(),frames])
	var b: Dictionary = towers.built.get("0,0",{})
	check(not b.is_empty() and (b.node as Node3D).global_position.is_equal_approx(KitClouds.TOWERS[0]),"The home tower stands at its spot")
	var age: float = towers.age_of(Vector2i.ZERO)
	check(age < SkyTowers.REST and SkyTowers.REST-age <= SkyTowers.RISE_SOON+0.1,"The home tower is about to rise (%.1f s to go)" % (SkyTowers.REST-age))
	var fixed_at := (b.node as Node3D).global_position
	var began := Time.get_ticks_usec()
	SkyTower.make(SkyTowers.seed_of(Vector2i.ZERO)).bake(1.0)
	var bake := Time.get_ticks_usec()-began
	# Through its life by the clock, as it runs.
	var rising := await _at(b,SkyTowers.REST+SkyTowers.GROW*0.5)
	check(absf(rising.x-0.5) < 0.05 and rising.y == 0.0,"Rising, it shows the stage its life has come to (%.2f grown)" % rising.x)
	var standing := await _at(b,SkyTowers.MATURE)
	check(is_equal_approx(standing.x,1.0) and standing.y == 0.0 and towers.fade(_heart(towers,b)) > 0.9,"Standing, it is whole and solid cloud at its heart")
	var waning := await _at(b,SkyTowers.REST+SkyTowers.GROW+SkyTowers.HOLD+SkyTowers.WANE*0.5)
	var wane_now: float = SkyTowers.wane_of(towers.age_of(b.cell))
	check(waning.y > 0.3 and waning.y < 0.8 and absf(waning.y-wane_now) < 0.02,"Waning, it goes from the foot up (%.2f waned, its life %.2f)" % [waning.y,wane_now])
	var again := await _at(b,SkyTowers.LIFE+SkyTowers.REST+SkyTowers.GROW*0.25)
	check(absf(again.x-0.25) < 0.05 and again.y == 0.0,"And it rises again in a new life (%.2f grown)" % again.x)
	check((b.node as Node3D).global_position == fixed_at,"It never drifts")
	var ages := {}
	for key in towers.built: ages[snappedf(towers.age_of(towers.built[key].cell),1.0)] = true
	check(ages.size() == towers.built.size(),"Their lives are out of step")
	SkyCommits.recording = false
	var most := 0
	var total := 0
	var count := 0
	var frames_of := {}
	for entry: Array in SkyCommits.log:
		var per: Array = frames_of.get_or_add(entry[0],[])
		per.append(entry)
		if entry[1] != "cumulus": continue
		if count == 0: print("kit clouds: the first tower stood in %d µs (the shared noise made with it)" % int(entry[2]))
		most = maxi(most,int(entry[2]))
		total += int(entry[2])
		count += 1
	# The sky's budget's rule: a part stands only while the frame has spent
	# under BUDGET_USEC, so a frame may run over only on its last commit.
	var piled := 0
	for f in frames_of:
		var spent := 0
		var per: Array = frames_of[f]
		for i in range(per.size()):
			if i > 0 and spent >= SkyCommits.BUDGET_USEC and per[i][1] == "cumulus": piled += 1
			spent += int(per[i][2])
	check(count >= towers.built.size() and piled == 0,"The towers stand up within the sky's frame budget, one past it never piled onto another (%d stand-ups)" % count)
	print("kit clouds: tower stage bake %.1f ms on a worker; %d stand-ups on the main thread, mean %.0f µs, most %d µs" % [bake/1000.0,count,float(total)/maxi(count,1),most])
	SkyCommits.log.clear()

## Sets the clock so `b` is `age` into its life and lets it run till it
## shows it: (grown, wane).
func _at(b: Dictionary, age: float) -> Vector2:
	var towers: Node3D = host.towers
	towers.clock = age-towers.phase(b.cell)
	for i in range(600):
		await process_frame
		if b.pair == SkyTowers._stage(SkyTowers.grown_of(towers.age_of(b.cell))): break
	await process_frame
	return Vector2(float(b.grown),float(b.wane))

## A point in the heart of a built tower (global), a third of the way up.
func _heart(towers: Node3D, b: Dictionary) -> Vector3:
	var shape: RefCounted = b.shape
	var y: float = SkyTower.SEA+shape.tall*0.35
	var axis: Vector2 = shape._axis(y)
	return towers.global_of(b,Vector3(axis.x,y,axis.y))

## The puffs: laid, drifting, clear of the isle, the isles and the towers.
func _puffs() -> void:
	var clouds: Node3D = host.clouds
	check(clouds.clouds.size() >= SkyClouds.COUNT*0.6 and clouds.puff_count() > clouds.clouds.size()*8,"The drifting clouds are laid (%d clouds, %d puffs)" % [clouds.clouds.size(),clouds.puff_count()])
	var c: Vector3 = study.isle_circle()
	var near := INF
	var in_tower := 0
	for cloud: Vector4 in clouds.clouds:
		var at := Vector3(cloud.x,cloud.y,cloud.z)
		near = minf(near,Vector2(at.x,at.z).distance_to(Vector2(c.x,c.y))-c.z)
		if host.towers.keeps(at): in_tower += 1
	check(near >= KitClouds.ISLE_CLEAR and in_tower == 0,"None is laid on the isle (closest %.0f m off its edge) or in a tower" % near)
	check(clouds.centre(0,0.0).distance_to(clouds.centre(0,60.0)) > 20.0,"They drift on the breeze")
	check((clouds._material.get_shader_parameter("keep_out") as PackedVector4Array).size() == CloudHost.KEEPS,"They thin away over the places nearest the eye")

## The CPU planes flown five minutes through the host's clouds: they choose
## passes through the drifting clouds, fly into them and tear them.
func _traffic() -> void:
	var traffic: Node = study.sky.traffic
	check(traffic.cloud_near.is_valid() and traffic.cloud_depth.is_valid(),"The CPU planes are given the host's clouds")
	var through := 0
	var deepest := 0.0
	var tore := false
	var time: float = study._motion_time
	var last := {}
	var spent := 0
	var steps := 0
	var eye: Vector3 = study.camera.global_position
	for i in range(int(300.0/DT)):
		time += DT
		for plane: Dictionary in traffic.planes:
			traffic._clock += DT
			traffic._fly(plane,DT)
			var kind: String = plane.goal.kind
			if kind == "cloud" and last.get(plane.figure,"") != "cloud": through += 1
			last[plane.figure] = kind
			deepest = maxf(deepest,host.cloud_body(plane.flight.position))
		host.step(DT,eye,time,host.fliers())
		spent += host.spent
		steps += 1
		for id in host.wakes._fliers:
			if id is int and host.wakes.open_count(time) > 0: tore = true
	check(through >= 3,"They choose passes through the drifting clouds (%d in 5 minutes, 4 planes)" % through)
	check(deepest > CloudWakes.IN,"and fly into them (deepest %.2f)" % deepest)
	check(tore,"and tear tunnels in them")
	print("kit clouds: a frame of the clouds with the traffic: %.0f µs on the main thread (mean of %d)" % [float(spent)/steps,steps])

## The player's plane through a drifting cloud, then through a standing
## tower: a tunnel in each, the puffs and the tower's shader given it, and
## the cloud volume marching it.
func _plane_tears() -> void:
	var clouds: Node3D = host.clouds
	host.towers.pinned = SkyTowers.MATURE
	host.flush()
	study.board()
	check(study.flying,"In the plane")
	var time: float = host.time+1.0
	var eye: Vector3 = study.camera.global_position
	# The cloud nearest the isle, flown through its heart.
	var c: Vector3 = clouds.centre(0,time)
	var heading := 0.4
	var way := Vector3(-sin(heading),0.0,-cos(heading))
	study.fly_from(c-way*40.0,heading)
	host.wakes.clear()
	var deepest := 0.0
	for i in range(int(6.0/DT)):
		time += DT
		study.plane.position += study.plane.velocity*DT
		deepest = maxf(deepest,host.cloud_body(study.plane.position))
		host.step(DT,eye,time,host.fliers())
	check(deepest > 0.5,"The plane flies through a drifting cloud's heart (%.2f)" % deepest)
	var near: Array = host.wakes.near_box(c,Vector3.ONE*60.0,time,CloudWakes.COUNT)
	check(host.wakes._fliers.has("eye") and int(near[2]) > 0,"and tears a tunnel through it (%d points)" % int(near[2]))
	var torn: PackedVector4Array = clouds._material.get_shader_parameter("wake_at")
	check(torn == host.wakes.at,"The puffs are given the tunnel")
	check(host.wakes.tufts.size() > 0,"and tufts of it are dragged out after the plane (%d)" % host.wakes.tufts.size())
	# Through the home tower, a third of the way up.
	var b: Dictionary = host.towers.built["0,0"]
	var heart := _heart(host.towers,b)
	host.wakes.clear()
	study.fly_from(heart-way*60.0,heading)
	for i in range(int(8.0/DT)):
		time += DT
		study.plane.position += study.plane.velocity*DT
		host.step(DT,heart,time,host.fliers())
	var material: ShaderMaterial = b.material
	check(int(material.get_shader_parameter("wake_count")) > 0,"The plane tears a tunnel through a tower (%d points on its shader)" % int(material.get_shader_parameter("wake_count")))
	var volume: Node3D = CloudVolume.new()
	study.add_child(volume)
	study.camera.global_position = heart
	volume.update(study.camera,null,host,null,time)
	volume._fill()
	check(volume.tower_count == mini(CloudVolume.TOWERS,host.towers.built.size()) and volume.wake_count > 0,"The cloud volume marches the host's towers (%d) and the tunnel (%d points)" % [volume.tower_count,volume.wake_count])
	volume.queue_free()
	await process_frame

## The scene freed while a tower bakes its next stages on a worker leaves
## nothing behind (the runner's exit check sees any leak).
func _teardown() -> void:
	var towers: Node3D = host.towers
	towers.pinned = -1.0
	var b: Dictionary = towers.built["0,0"]
	towers.clock = SkyTowers.REST+SkyTowers.GROW*0.7-towers.phase(b.cell)
	var baking := false
	for i in range(30):
		await process_frame
		if not (b.job as Dictionary).is_empty():
			baking = true
			break
	check(baking,"Caught a tower baking its stages on a worker")
	var id := towers.get_instance_id()
	var node_id := (b.node as Node3D).get_instance_id()
	study.free()
	await process_frame
	await process_frame
	check(not is_instance_id_valid(id) and not is_instance_id_valid(node_id),"Freed with the scene, the bake waited for")
