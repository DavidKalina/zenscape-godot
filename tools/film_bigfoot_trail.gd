extends SceneTree
## Bigfoot's trail on film (scripts/life_trail.gd, docs/scenic/life.md
## "Bigfoot's trail"). Stages a wood with dead wood on the plain's west half
## and a pond to its east, holds the gate open, then forces each sign:
##   tracks  snow tracks out of the wood; then mud tracks from the wood to the
##           shore on wet ground, and rain washing them out (a time lapse).
##   cairn   the stacked stones at the elder stand's edge, close.
##   branch  the snapped or arched sapling, close.
##   night   a still, clear night over the wood: the far howl, then knocks.
## Rendered (needs a window), one shot per run:
##   Godot --windowed --resolution 1280x720 --path . --write-movie /tmp/zs-film/08-bigfoot-trail-tracks.avi \
##     -s res://tools/film_bigfoot_trail.gd -- --no-title --shot=tracks
## Headless, `--odds` rolls the natural chances (no forcing) over simulated
## plain days and prints how often each sign comes.

var scene: Node3D
var editor: NativeChunkEditor
var life: Node3D
var moments: Node3D
var trail: Node3D
## Held each frame: {"snow", "wet", "rain"}; empty leaves the weather alone.
var weather := {}
## Extra trail seconds a frame while rain washes the tracks (time lapse).
var lapse := 0.0

func _initialize() -> void: run.call_deferred()

func frames(count: int) -> void:
	for i in range(count):
		await process_frame
		_hold_weather()
		var hand: Node3D = scene.get("god_hand") as Node3D
		if hand != null: hand.visible = false
		if lapse > 0.0: trail.advance(lapse)

func seconds(value: float) -> void:
	await frames(int(value*60.0))

func _hold_weather() -> void:
	if weather.is_empty(): return
	var sky: Node = scene._precipitation
	var surface: RefCounted = sky.surface_weather
	surface.snow_cover = float(weather.snow)
	surface.ground_wet = float(weather.wet)
	var rain: float = weather.rain
	sky.target = Vector4(rain,0.0,0.85 if rain > 0.0 else 0.1,0.0)
	sky.state = sky.target
	surface.publish()

func camera_to(target: Vector3, distance: float, yaw: float, polar: float, secs: float) -> void:
	var from := [scene.target,scene.distance,scene.yaw,scene.polar]
	var count := maxi(1,int(secs*60.0))
	for i in range(count):
		var t := smoothstep(0.0,1.0,float(i+1)/count)
		scene.target = from[0].lerp(target,t)
		scene.distance = lerpf(from[1],distance,t)
		scene.yaw = lerp_angle(from[2],yaw,t)
		scene.polar = lerpf(from[3],polar,t)
		scene._update_camera()
		await frames(1)

func orbit(turn: float, secs: float) -> void:
	var from: float = scene.yaw
	var count := int(secs*60.0)
	for i in range(count):
		scene.yaw = from+turn*float(i+1)/count
		scene._update_camera()
		await frames(1)

func at(p: Vector2, lift := 0.3) -> Vector3:
	var h: Variant = editor.data.ground_height(p)
	return editor.terrain.to_global(Vector3(p.x,(float(h) if h != null else 0.0)+lift,p.y))

func run() -> void:
	create_timer(400).timeout.connect(func() -> void: push_error("bigfoot trail film timed out"); quit(2))
	var shot := "tracks"
	var odds := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="): shot = arg.trim_prefix("--shot=")
		if arg == "--odds": odds = true
	root.size = Vector2i(1280,720)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.places_path = "/private/tmp/zs-film-trail-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready: await process_frame
	editor = scene._chunk_editor
	life = scene.land_life
	moments = life.moments
	trail = moments.trail
	editor.set_process_input(false)
	# Clean frames: no hand, no hover ring or label under the idle pointer.
	var reach: Node = scene.get("hand_reach")
	if reach != null: reach.pointer_override = Vector2(-10000.0,-10000.0)
	for name in ["god_hand"]:
		var node: Node = scene.get(name)
		if node == null: continue
		node.set_process(false)
		node.set_physics_process(false)
		node.set_process_input(false)
		node.set_process_unhandled_input(false)
		if node is Node3D: node.visible = false
	scene.set_process_input(false)
	scene.set_process_unhandled_input(false)
	Input.warp_mouse(Vector2(1,1))
	editor.pointer_override = Vector2(-10000.0,-10000.0)
	for overlay: Node in scene.find_children("*","CanvasLayer",true,false): overlay.visible = false
	scene.world_clock.running = false
	scene._celestial.cycling = false
	scene._celestial.set_phase(0.3)
	await frames(30)
	await stage()
	print("TRAIL FILM survey trees=%d edges=%d shore=%d bodies=%d elder=%s" % [life.survey.tree_count,life.survey.forest_edges.size(),life.survey.shore.size(),life.survey.bodies.size(),trail._elder(life.survey)])
	if odds:
		roll_odds()
		quit()
		return
	scene._overview()
	scene._update_camera()
	match shot:
		"tracks": await film_tracks()
		"cairn": await film_mark("cairn")
		"branch": await film_mark("branch")
		"night": await film_night()
	print("TRAIL FILM history ",JSON.stringify(moments.history.map(func(m: Dictionary) -> Array: return [m.kind,snappedf(m.at,0.1)])))
	quit()

## A wood of 40 trees with three snags on the west half, undergrowth, and a
## pond dug to its east; waits for a survey that has seen the water.
func stage() -> void:
	var data := editor.data
	var basin := Vector2(3.0,1.0)
	data.begin_stroke()
	for _pass in range(4): data.brush(basin,3.5,0.25,"lower",0.0)
	var bottom: float = data.ground_height(basin)
	data.add_pond(basin,bottom+0.6)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for gx in range(5):
		for gz in range(8):
			var p := Vector2(-10.5+gx*1.9+rng.randf_range(-0.5,0.5),-7.5+gz*2.0+rng.randf_range(-0.5,0.5))
			if data.place(["tree","broadleaf","broadleaf"][(gx+gz)%3],p,rng.randf()*TAU,1.0) >= 0: data.objects.back()["source"] = "emerged"
	for p in [Vector2(-9.0,-2.0),Vector2(-8.5,-1.2),Vector2(-9.3,0.4)]:
		if data.place("snag",p,0.3,1.0) >= 0: data.objects.back()["source"] = "emerged"
	for i in range(24):
		var p := Vector2(rng.randf_range(-11.0,-3.5),rng.randf_range(-8.0,8.0))
		if data.place(["shrub","fern"][i%2],p,rng.randf()*TAU,1.0) >= 0: data.objects.back()["source"] = "emerged"
	data.end_stroke()
	await editor.refresh(self)
	for attempt in range(4):
		var surveys: int = life.surveys
		life._changed(true)
		while life.surveys == surveys: await process_frame
		await frames(10)
		if life.survey.shore.size() > 0: break
	# The gate held long enough for full kinship.
	trail._since = life.clock-2000.0
	moments._stroke_at = -INF
	moments._consider()

func film_tracks() -> void:
	# Snow: tracks out of the wood and back in.
	weather = {"snow":0.7,"wet":0.0,"rain":0.0}
	await seconds(1.0)
	var ok: bool = trail._lay_tracks(life.survey,false)
	var line: Dictionary = trail.tracks.back() if ok else {}
	print("TRAIL FILM snow tracks ",ok," ",line.get("kind","")," prints=",(line.get("prints",[]) as Array).size())
	if ok: await look_along(line,0.0)
	await seconds(5.0)
	await orbit(0.5,4.0)
	# Wet ground: new tracks from the wood down to the shore and back.
	trail.tracks.clear()
	weather = {"snow":0.0,"wet":0.7,"rain":0.0}
	await seconds(0.5)
	ok = false
	for attempt in range(12):
		if trail._lay_tracks(life.survey,false) and trail.tracks.back().kind == "mud":
			ok = true
			break
	line = trail.tracks.back() if ok else {}
	print("TRAIL FILM mud tracks ",ok," prints=",(line.get("prints",[]) as Array).size())
	if ok: await look_along(line,1.5)
	await seconds(5.0)
	# Rain washes them out: a time lapse, the trail's clock 6x.
	weather = {"snow":0.0,"wet":0.9,"rain":0.85}
	lapse = 5.0/60.0
	for i in range(8):
		await seconds(1.0)
		print("TRAIL FILM rain fade ",snappedf(float(line.get("fade",0.0)),0.01)," sets=",trail.tracks.size())
	lapse = 0.0
	await seconds(2.0)

## Frame a set of prints from its open side.
func look_along(line: Dictionary, secs: float) -> void:
	var prints: Array = line.prints
	var centre := Vector2.ZERO
	for row: Array in prints: centre += Vector2(row[0],row[1])
	centre /= prints.size()
	var reach := 0.0
	for row: Array in prints: reach = maxf(reach,centre.distance_to(Vector2(row[0],row[1])))
	await camera_to(at(centre,0.0),clampf(reach*1.3+2.0,5.0,9.0),PI*0.5+0.5,0.9,maxf(secs,0.05))

func film_mark(kind: String) -> void:
	await seconds(1.0)
	var ok: bool = trail.force(kind)
	print("TRAIL FILM ",kind," placed ",ok)
	if not ok:
		await seconds(2.0)
		return
	var mark: Dictionary = trail.marks.back()
	var p := Vector2(mark.x,mark.z)
	var close := 2.6 if kind == "cairn" else 3.2
	var best := clear_yaw(p,close*sin(1.2),Vector2(sin(float(mark.yaw)),cos(float(mark.yaw))))
	scene.target = at(p,0.3 if kind == "cairn" else 0.8)
	scene.distance = close*1.8
	scene.yaw = best-0.2
	scene.polar = 1.0
	scene._update_camera()
	await seconds(2.0)
	await camera_to(at(p,0.3 if kind == "cairn" else 0.8),close,best-0.15,1.2,4.0)
	await seconds(2.0)
	await orbit(0.15,8.0)
	await seconds(2.0)

## The yaw whose camera, `reach` metres out on the level, sees `p` past the
## most trunk room: every tree's distance from the sight line, the nearest wins.
func clear_yaw(p: Vector2, reach: float, out: Vector2) -> float:
	# Crowns hang low at plate scale: keep the sight line clear of them.
	var trunks: Array[Vector3] = []
	for item: Dictionary in editor.data.objects:
		var asset := str(item.get("asset",""))
		if asset in life.Survey.TREES or asset == "snag":
			var q := Vector2(float(item.x),float(item.z))
			var skirt := 0.25 if asset == "snag" else 0.9
			if q.distance_to(p) < reach+2.0: trunks.append(Vector3(q.x,q.y,skirt))
	var best := 0.0
	var room := -INF
	for k in range(48):
		var yaw := TAU*k/48.0
		var eye := p+Vector2(sin(yaw),cos(yaw))*reach
		var nearest := INF
		for t in trunks:
			var q := Vector2(t.x,t.y)
			nearest = minf(nearest,Geometry2D.get_closest_point_to_segment(q,p,eye).distance_to(q)-t.z)
		# Rather from the open side of the edge.
		nearest = minf(nearest,1.5)+0.4*Vector2(sin(yaw),cos(yaw)).dot(out)
		if nearest > room:
			room = nearest
			best = yaw
	print("TRAIL FILM clear yaw %.2f room %.2f" % [best,room])
	return best

func film_night() -> void:
	scene._celestial.set_phase(0.92)
	var atmosphere: Node = scene._atmosphere
	weather = {"snow":0.0,"wet":0.0,"rain":0.0}
	var elder: Vector2 = trail._elder(life.survey)
	await camera_to(at(elder+Vector2(4.0,0.0),1.0),16.0,PI*0.5+0.3,1.1,0.05)
	for i in range(60):
		atmosphere._air_strength = 0.15
		await frames(1)
	print("TRAIL FILM still_clear ",trail._still_clear()," light ",moments.light_now())
	await seconds(3.0)
	print("TRAIL FILM howl ",trail.force("howl"))
	await orbit(0.15,8.0)
	print("TRAIL FILM knocks ",trail.force("knocks"))
	await orbit(0.12,6.0)
	await seconds(2.0)

## The natural dice: plain days of 1200 s, the night eased through in a jump
## from phase 0.8 to 0.2 as cozy_regrowth.gd does, a check every 2 s.
func roll_odds() -> void:
	var days := 6
	var seen := {}
	var start: int = moments.history.size()
	var clock: float = life.clock
	for weathers in [["dry",0.0,0.0],["snow",0.7,0.0]]:
		var surface: RefCounted = scene._precipitation.surface_weather
		surface.snow_cover = weathers[1]
		surface.ground_wet = weathers[2]
		scene._atmosphere._air_strength = 0.2
		for step in range(int(days*1200/2)):
			var phase := 0.2+fposmod(step*2.0/1200.0,0.6)
			scene._celestial.set_phase(phase)
			life.clock = clock
			trail.consider(life.survey,clock)
			clock += 2.0
		for m: Dictionary in moments.history.slice(start):
			var key: String = weathers[0]+":"+str(m.kind)
			seen[key] = int(seen.get(key,0))+1
		start = moments.history.size()
	print("TRAIL ODDS kinship=%.2f days=%d per weather: %s marks=%d tracks=%d" % [trail.kinship,days,JSON.stringify(seen),trail.marks.size(),trail.tracks.size()])
