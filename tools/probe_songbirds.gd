extends SceneTree
## Headless probe of the songbirds (scripts/songbirds.gd, docs/scenic/songbirds.md).
## Opens the product scene on the Genesis plain and plants two groves of oaks
## (the second with two spruces) about 12 m apart, then at a fixed 60 Hz:
## - the oak's bark carries its perch limbs, and the oak has three perches;
## - flocks arrive and settle: some birds hide in crowns, some sit on perches,
##   each perched bird's feet within 1 cm of its perch;
## - landings and leavings rustle crowns and shed leaves;
## - a poke flushes the flock near it: all its birds up within a second, a
##   big rustle and burst, wheeling, then settled again in the other grove;
## - a gust sent across a grove flushes its flock when the front arrives;
## - moving a tree under a perched bird sends it off, never carrying it;
## - no bird is ever under the ground, faster than 8 m/s, or not finite.
## Nothing is rendered: the bird shader, the look and the motion are unverified.
##   godot --headless --fixed-fps 60 --path . -s res://tools/probe_songbirds.gd
const Disturbance = preload("res://scripts/disturbance.gd")
const Limbs = preload("res://scripts/perch_limbs.gd")
var scene: Node3D
var editor: NativeChunkEditor
var songbirds: Node3D
var failures := []
var worst := {"under":INF,"speed":0.0,"finite":true}

func _initialize() -> void: run.call_deferred()

func check(label: String, ok: bool, detail: Variant = "") -> void:
	if not ok: failures.append(label)
	print(("OK   " if ok else "FAIL ")+label+("" if str(detail).is_empty() else "  "+str(detail)))

## Step `seconds` of frames, watching every bird.
func run_for(seconds: float) -> void:
	for i in range(int(seconds*60.0)):
		await process_frame
		for bird: Dictionary in songbirds.birds:
			var p: Vector3 = bird.p
			if not p.is_finite():
				worst.finite = false
				continue
			if bird.state in ["hidden","gone"] or float(bird.delay) > 0.0: continue
			var ground: Variant = songbirds.inspector.ground_y(p)
			if ground != null: worst.under = minf(worst.under,p.y-float(ground))
			worst.speed = maxf(worst.speed,(bird.v as Vector3).length())

func states() -> Dictionary:
	var out := {}
	for bird: Dictionary in songbirds.birds: out[bird.state] = int(out.get(bird.state,0))+1
	return out

func run() -> void:
	create_timer(900).timeout.connect(func() -> void: push_error("Songbird probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.set_meta("no_title",true)
	scene.places_path = "/private/tmp/zs-songbird-probe-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	editor = scene._chunk_editor
	songbirds = scene.land_life.songbirds
	var data := editor.data

	# The oak's bark has its limbs.
	var bark: Mesh = editor.content._meshes.get("broadleaf:mesh-11")
	var ends := 0
	if bark != null:
		for v: Vector3 in bark.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			if Vector2(v.x-Limbs.AXIS.x,v.z-Limbs.AXIS.y).length() > 0.62 and v.y > 0.65 and v.y < 0.9: ends += 1
	check("the oak bark carries its perch limbs",ends > 0,{"limb_tip_vertices":ends})
	check("three perches",Limbs.perches().size() == 3)

	# Two groves of oaks, about 12 m apart; the second has two spruces.
	var groves := [Vector2(-5.0,-2.0),Vector2(6.0,3.0)]
	data.begin_stroke()
	for g in range(2):
		for i in range(6 if g == 0 else 4):
			var at: Vector2 = groves[g]+Vector2.from_angle(float(i)*1.9+float(g))*(1.2+0.5*float(i))
			data.place("broadleaf",at,float(i)*0.7,1.4)
		if g == 1:
			data.place("tree",groves[g]+Vector2(2.2,0.4),0.0,1.0)
			data.place("tree",groves[g]+Vector2(-0.6,2.4),0.0,1.0)
	data.end_stroke()
	await editor.refresh(self)
	scene._overview()
	await run_for(1.0)
	check("life is running",scene.land_life.active)
	songbirds.scan_trees()
	check("two groves",songbirds.groves.size() == 2,songbirds.groves.size())
	var oaks_with_perches := 0
	for id: int in songbirds.trees:
		if not (songbirds.trees[id].perches as Array).is_empty(): oaks_with_perches += 1
	check("every oak has perches",oaks_with_perches == 10,oaks_with_perches)

	# Arrival and settling.
	await run_for(40.0)
	print("FLOCKS ",JSON.stringify(songbirds.flocks.map(func(f: Dictionary) -> Dictionary: return {"species":f.species,"grove":f.grove,"state":f.state})))
	print("STATES ",states()," COUNTS ",songbirds.counts)
	check("flocks arrived",songbirds.flocks.size() >= 1 and songbirds.birds.size() >= 3,{"flocks":songbirds.flocks.size(),"birds":songbirds.birds.size()})
	var s := states()
	check("settled: some hidden, some perched",int(s.get("hidden",0)) > 0 and int(s.get("perched",0)) > 0,s)
	var off := 0.0
	for bird: Dictionary in songbirds.birds:
		if bird.state != "perched": continue
		var placed: Array = songbirds._perch_world(int(bird.target.tree),bird.target.perch)
		off = maxf(off,(placed[0] as Vector3).distance_to(bird.p))
	check("perched birds stand on their perch",off < 0.01,snappedf(off,0.0001))
	check("landings rustle crowns and shed leaves",int(songbirds.counts.get("rustle",0)) > 0 and int(songbirds.counts.get("leaves",0)) > 0,songbirds.counts)

	# A poke near the first flock's grove flushes it.
	var flock: Dictionary = songbirds.flocks[0]
	var home := int(flock.grove)
	var centre: Vector3 = songbirds._world()*(songbirds.groves[home].centre as Vector3)
	await run_for(13.0) # past the settling calm
	var flushes := int(songbirds.counts.get("flush",0))
	Disturbance.raise(centre,1.0,1.0,"poke")
	await run_for(1.0)
	var up := 0
	var members: Array = songbirds._members(flock)
	for bird: Dictionary in members:
		if bird.state == "wheeling": up += 1
	check("a poke flushes the flock",int(songbirds.counts.get("flush",0)) == flushes+1 and up == members.size(),{"wheeling":up,"of":members.size()})
	check("a flush bursts leaves",int(songbirds.counts.get("leaves_big",0)) > 0,songbirds.counts.get("leaves_big",0))
	await run_for(25.0)
	check("the flock settles in the other grove",flock.state == "settled" and int(flock.grove) != home,{"state":flock.state,"grove":flock.grove,"was":home,"states":states()})

	# A gust lane sent across the flock's new grove flushes it when the front arrives.
	await run_for(13.0)
	var now_home: Vector3 = songbirds._world()*(songbirds.groves[int(flock.grove)].centre as Vector3)
	var from := now_home+Vector3(-8.0,0.0,0.0)
	flushes = int(songbirds.counts.get("flush",0))
	Disturbance.raise(from,8.0,1.0,"gust",{"shape":"lane","way":Vector3.RIGHT,"from":0.0,"span":14.0,"run":1.6,"wind_up":0.2,"across":3.0})
	await run_for(0.3)
	var early := int(songbirds.counts.get("flush",0))
	await run_for(2.0)
	# Both flocks may share the grove by now, so one or two flushes.
	check("a gust flushes the flock as its front arrives",early == flushes and int(songbirds.counts.get("flush",0)) > flushes,{"before_front":early-flushes,"after":int(songbirds.counts.get("flush",0))-flushes})
	await run_for(30.0)

	# Move a tree from under a perched bird: it leaves rather than riding along.
	var sitter: Dictionary = {}
	for i in range(40):
		for bird: Dictionary in songbirds.birds:
			if bird.state == "perched": sitter = bird
		if not sitter.is_empty(): break
		await run_for(1.0)
	if sitter.is_empty():
		print("SKIP move a tree under a perched bird: none perched")
	else:
		var before: Vector3 = sitter.p
		for item: Dictionary in data.objects:
			if int(item.id) == int(sitter.target.tree): item.x = float(item.x)+1.5
		songbirds._scan = 0.0
		await run_for(0.1)
		check("a moved tree sends its bird off",sitter.state == "flying",{"state":sitter.state,"moved_m":snappedf((sitter.p as Vector3).distance_to(before),0.01)})

	await run_for(5.0)
	print("WORST ",JSON.stringify({"under_ground_min":snappedf(worst.under,0.01),"speed_max":snappedf(worst.speed,0.01),"finite":worst.finite,"life_worst_ms":snappedf(scene.land_life.worst_usec/1000.0,0.01)}))
	print("COUNTS ",songbirds.counts)
	check("never under the ground",worst.under > -0.01,snappedf(worst.under,0.01))
	check("never faster than 8 m/s",worst.speed < 8.0,snappedf(worst.speed,0.01))
	check("always finite",worst.finite)
	print("FAILURES ",failures.size()," ",failures)
	quit(1 if not failures.is_empty() else 0)
