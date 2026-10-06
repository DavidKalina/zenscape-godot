extends SceneTree
## The main thread's cost of a claim (scripts/sky_islands.gd `claim`), frame
## by frame: flown at the glide's pace from open sky into a fresh chunk (the
## plate becomes its plain), back into the island first left (a built
## island: the land its document gives) and into the fresh one again (left
## as the plain it was claimed as, so a chunk again). Each frame from just
## before the claim to well after the landing that did any of the claim's
## work, or ran slow, is listed with its wall time (uncapped: its work), the
## claim's own work in it (`claim_ms`), every step timed in it (SkyCommits
## `spend` and `note`: the claim's steps, the plate drawn again, the
## habitat, the sky's commits, the islands' life) and where its time went
## (a spy before each of the scene's parts marks where its process starts:
## the coroutines resumed before any, each part, the rest).
##   Godot --headless --path . -s res://tools/profile_claim.gd -- \
##     [--speed=22] [--out=/private/tmp/zs-claim.txt] [--all]
## --all lists every frame of each leg.
## Headless measures the scripts only, never the GPU's uploads. Without the
## native kernels (native/terrain_kernels/bin, built, as the main checkout
## has them) the water's surface is rebuilt in GDScript, 7 to 12 ms every
## few frames: the editor's part in the listing.
const SkyCommits = preload("res://scripts/sky_commits.gd")

var speed := 22.0
var out := ""
var all := false

## Times the frame: where it starts (the tree's process_frame, before any
## node's process) and each spy's turn; a frame ends where the next starts.
## Kept per process frame: {start, spies: [[label, usec]]}.
class Clock extends RefCounted:
	var frames := {}
	func begin() -> void:
		var f := Engine.get_process_frames()
		frames[f] = {"start":Time.get_ticks_usec(),"spies":[]}
	func spy(label: String) -> void:
		var f: Dictionary = frames.get(Engine.get_process_frames(),{})
		if not f.is_empty(): (f.spies as Array).append([label,Time.get_ticks_usec()])

## A node standing just before another among its siblings: its process
## marks where that one's subtree starts processing.
class Spy extends Node:
	var label := ""
	var clock: Clock
	func _process(_delta: float) -> void: clock.spy(label)

func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--speed="): speed = float(a.trim_prefix("--speed="))
		elif a.begins_with("--out="): out = a.trim_prefix("--out=")
		elif a == "--all": all = true
	run.call_deferred()

func run() -> void:
	create_timer(900).timeout.connect(func() -> void: push_error("claim profile timed out"); quit(2))
	var result: Dictionary = await fly(root,self,speed,all)
	print(result.report)
	if out != "":
		var f := FileAccess.open(out,FileAccess.WRITE)
		f.store_string(result.report+"\n")
	quit(0)

## Opens the cozy world under `root` and flies the three legs (or only
## the first `legs`). Returns {legs: [{name, frames, claim: [first, last]
## frame ids, path}], quiet: open-sky frames' wall ms, report, scene}. Each
## frame: {id, wall, claiming, steps: [[what, ms]], parts: [[what, ms]]}:
## its wall time from the end of the frame before to its own end, the steps
## timed in it (SkyCommits), and where its time went (`parts`: the frame's
## start, its coroutines and signals before any process, each of the
## scene's subtrees' process, and the rest to its end).
## `watch`, if given, is called every frame of every leg after the flight's
## own step: watch(scene, frame id, claiming, leg index).
static func fly(root: Window, tree: SceneTree, pace: float, every := false, before := Callable(), leg_count := 3, watch := Callable()) -> Dictionary:
	root.unfocusable = true
	var scene: Node3D = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.set_meta("no_title",true)
	scene.places_path = "/private/tmp/zs-claim-%d/places.json" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(scene.places_path.get_base_dir())
	root.add_child(scene)
	tree.current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await tree.process_frame
	while scene.places.busy or scene._chunk_editor.forming: await tree.process_frame
	var eye: Node = scene.wanderer
	var islands: Node3D = eye.islands
	var waited := 0
	while not islands.sky_ready() and waited < 6000:
		islands.make_ahead(1.0/60.0)
		waited += 1
		await tree.process_frame
	for i in range(30): await tree.process_frame
	scene.world_clock.running = false
	eye.place(Vector3(eye.PLATE_REACH-0.6,0.0,0.0))
	eye.enter()
	for i in range(5): await tree.process_frame
	eye._launch(6.0,false)
	eye.set_process(false)
	eye._layer.visible = false
	for i in range(10): await tree.process_frame
	if before.is_valid(): await before.call(scene)
	var clock := Clock.new()
	tree.process_frame.connect(clock.begin)
	var spies := _spy(root,scene,clock)
	var fps_was := Engine.max_fps
	Engine.max_fps = 0
	var first_home: Vector3 = -islands.origin
	var index := 0
	while islands.lands[index] == null: await tree.process_frame
	var fresh_home: Vector3 = islands.homes[index]
	var legs: Array = []
	var quiet: Array[float] = []
	legs.append(await _leg(scene,tree,"into a fresh chunk",fresh_home,pace,quiet,clock,watch.bind(0) if watch.is_valid() else watch))
	if leg_count > 1: legs.append(await _leg(scene,tree,"back into the built island first left",first_home,pace,quiet,clock,watch.bind(1) if watch.is_valid() else watch))
	if leg_count > 2: legs.append(await _leg(scene,tree,"into the fresh chunk again",fresh_home,pace,quiet,clock,watch.bind(2) if watch.is_valid() else watch))
	Engine.max_fps = fps_was
	tree.process_frame.disconnect(clock.begin)
	for spy: Node in spies: if is_instance_valid(spy): spy.queue_free()
	var report := _report(legs,quiet,every)
	return {"legs":legs,"quiet":quiet,"report":report,"scene":scene}

## A spy before each of the root's children and each of the scene's.
static func _spy(root: Window, scene: Node, clock: Clock) -> Array[Node]:
	var made: Array[Node] = []
	var parents: Array[Node] = [root,scene]
	# One level further under the plate's editor, which carries the most.
	var editor: Node = scene.get("_chunk_editor")
	if editor != null: parents.append(editor)
	for parent: Node in parents:
		var children := parent.get_children()
		# The parent's own process, then its children's.
		if parent != root and not children.is_empty():
			var own := Spy.new()
			own.label = "%s's children" % parent.name
			own.clock = clock
			parent.add_child(own)
			parent.move_child(own,0)
		for child: Node in children:
			if child is Spy: continue
			var spy := Spy.new()
			var script: Script = child.get_script()
			spy.label = String(child.name)+("<%s>" % script.resource_path.get_file() if script != null else "")
			spy.clock = clock
			parent.add_child(spy)
			parent.move_child(spy,child.get_index())
			made.append(spy)
	var last := Spy.new()
	last.label = "(after)"
	last.clock = clock
	root.add_child(last)
	made.append(last)
	return made

## One leg: from 260 m off `home` (30 m over it), flown straight in over its
## middle at `pace`, claimed as the flight's own frame claims (WandererEye
## `_advance_flight`), and on 120 m past it. Open-sky frames before the
## chunk is near go to `quiet`.
static func _leg(scene: Node3D, tree: SceneTree, name: String, home: Vector3, pace: float, quiet: Array[float], clock: Clock, watch := Callable()) -> Dictionary:
	var eye: Node = scene.wanderer
	var islands: Node3D = eye.islands
	var glide: RefCounted = eye.glide
	# Whatever settled from the last leg settles first.
	for i in range(60): await tree.process_frame
	var from := home
	var at0: Vector3 = glide.position-islands.origin
	var way := Vector3(from.x-at0.x,0.0,from.z-at0.z).normalized()
	if way == Vector3.ZERO: way = Vector3.FORWARD
	var start := Vector3(from.x,from.y+30.0,from.z)-way*260.0
	var finish := Vector3(from.x,from.y+30.0,from.z)+way*120.0
	SkyCommits.log.clear()
	SkyCommits.trace.clear()
	SkyCommits.recording = true
	clock.frames.clear()
	var frames: Array = []
	var travelled := 0.0
	var length := start.distance_to(finish)
	var claim := [-1,-1]
	var claimed := false
	var after := 0
	var count := 0
	while (travelled < length or islands.claiming or after < 120) and count < 4000:
		count += 1
		var delta := 1.0/60.0
		travelled += pace*delta
		if travelled >= length: after += 1
		var home_at := start.lerp(finish,minf(travelled/length,1.0))
		var p: Vector3 = home_at+islands.origin
		glide.position = p
		glide.heading = atan2(-way.x,-way.z)
		glide.pitch = 0.0
		glide.speed = pace
		glide.velocity = way*pace
		var id := Engine.get_process_frames()
		var began := Time.get_ticks_usec()
		if not islands.claiming and not claimed:
			var under: int = islands.copy_under(p)
			if under >= 0 and islands.homes[under] == home:
				claimed = true
				claim[0] = id
				eye._claim(under)
		elif claimed and claim[1] < 0 and not islands.claiming:
			claim[1] = id-1
		SkyCommits.note("flight:claim_call",Time.get_ticks_usec()-began)
		began = Time.get_ticks_usec()
		eye.sky.advance(delta,p,0.0)
		SkyCommits.note("flight:sky",Time.get_ticks_usec()-began)
		began = Time.get_ticks_usec()
		islands.advance(delta,p,glide.heading,0.0)
		SkyCommits.note("flight:islands",Time.get_ticks_usec()-began)
		began = Time.get_ticks_usec()
		var o := p-way*30.0+Vector3.UP*6.0
		scene.target = p
		scene.distance = o.distance_to(p)
		var dir := (o-p).normalized()
		scene.yaw = atan2(dir.x,dir.z)
		scene.polar = acos(clampf(dir.y,-1.0,1.0))
		scene.camera_roll = 0.0
		scene._auto_orbit = false
		scene._update_camera()
		SkyCommits.note("flight:camera",Time.get_ticks_usec()-began)
		frames.append({"id":id,"wall":0.0,"claiming":islands.claiming,"steps":[],"parts":[]})
		if watch.is_valid(): watch.call(scene,id,islands.claiming)
		await tree.process_frame
	frames.pop_back()
	SkyCommits.recording = false
	var by_frame := {}
	for c: Array in SkyCommits.log+SkyCommits.trace:
		if not by_frame.has(c[0]): by_frame[c[0]] = []
		by_frame[c[0]].append([c[1],c[2]/1000.0])
	for f: Dictionary in frames:
		f.steps = by_frame.get(f.id,[])
		var mine: Dictionary = clock.frames.get(f.id,{})
		var next: Dictionary = clock.frames.get(f.id+1,{})
		if mine.is_empty() or next.is_empty(): continue
		# Headless draws no frame to mark its end: a frame runs from its
		# start to the next one's (its physics, deferred calls and drawing
		# in the rest).
		f.wall = (next.start-mine.start)/1000.0
		var parts: Array = []
		var at: int = mine.start
		var label := "(resumed coroutines)"
		for s: Array in mine.spies:
			parts.append([label,(s[1]-at)/1000.0])
			label = s[0]
			at = s[1]
		parts.append(["(rest of the frame)",(next.start-at)/1000.0])
		f.parts = parts
	# Open sky: the first 120 frames, while the chunk is still well off.
	for k in range(mini(120,frames.size())):
		if frames[k].wall > 0.0: quiet.append(frames[k].wall)
	var path := "fresh" if islands.plate_seed >= 0 else "built"
	return {"name":name,"frames":frames,"claim":claim,"path":path}

## A frame's own claim work (ms): every step timed in it but the flight's
## own (the profile's stand-in for the glide's frame) and the streaming
## commits, which keep to their own share.
static func claim_ms(f: Dictionary) -> float:
	var total := 0.0
	var settled := false
	for s: Array in f.steps: settled = settled or s[0] == "claim:settle"
	for s: Array in f.steps:
		var what: String = s[0]
		if what.begins_with("claim:") or what.begins_with("form:") or what.begins_with("refresh:") or (what == "habitat" and not settled) or what.begins_with("life:"):
			total += s[1]
	return total

static func _report(legs: Array, quiet: Array[float], every: bool) -> String:
	var lines: Array[String] = []
	var q := quiet.duplicate()
	q.sort()
	var pick := func(a: Array, f: float) -> float: return a[clampi(int(f*(a.size()-1)),0,a.size()-1)] if not a.is_empty() else 0.0
	lines.append("CLAIM PROFILE; open-sky frames' wall time: p50 %.2f, p95 %.2f, max %.2f ms (n %d)" % [pick.call(q,0.5),pick.call(q,0.95),pick.call(q,1.0),q.size()])
	for leg: Dictionary in legs:
		var claim: Array = leg.claim
		lines.append("")
		lines.append("LEG %s (plate now %s): claim frames %d..%d (%d)" % [leg.name,leg.path,claim[0],claim[1],claim[1]-claim[0]+1])
		var worst_wall := 0.0
		var worst_claim := 0.0
		var near_worst := 0.0
		for f: Dictionary in leg.frames:
			worst_wall = maxf(worst_wall,f.wall)
			var mine := claim_ms(f)
			worst_claim = maxf(worst_claim,mine)
			var near: bool = claim[0] >= 0 and f.id >= claim[0]-3 and f.id <= (claim[1] if claim[1] >= 0 else claim[0])+100
			if near: near_worst = maxf(near_worst,f.wall)
			var claimed := false
			for step: Array in f.steps: claimed = claimed or (step[0] as String).begins_with("claim:")
			if not (every or (near and (f.wall > 9.0 or mine > 0.5 or claimed)) or f.wall > 14.0): continue
			var parts: Array[String] = []
			for s: Array in f.steps:
				if s[1] >= (0.5 if (s[0] as String).begins_with("p:") else 0.05): parts.append("%s %.2f" % [s[0],s[1]])
			var where: Array[String] = []
			for s: Array in f.parts:
				if s[1] >= 0.4: where.append("%s %.1f" % [s[0],s[1]])
			lines.append("  @%d %s wall %5.1f claim %5.1f | %s | %s" % [f.id,"C" if f.claiming else " ",f.wall,mine,", ".join(parts),", ".join(where)])
		lines.append("  worst: wall %.1f (around the claim %.1f), claim work in a frame %.1f ms" % [worst_wall,near_worst,worst_claim])
	return "\n".join(lines)
