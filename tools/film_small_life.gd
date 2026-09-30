extends SceneTree
## Film the small ambient life (scripts/life_small.gd): dragonflies over a
## pond, butterflies on flowering shrubs, a woodpecker drumming on a snag, and
## geese in a V, each close, plus the same scene at the normal overview.
##   Godot --windowed --resolution 1280x720 --fixed-fps 30 --path . \
##     --write-movie /tmp/zs-film/06-small-life-<shot>.avi -s res://tools/film_small_life.gd \
##     -- --no-title --shot=dragonflies|butterflies|woodpecker|geese|wide
## Forced: summer daylight (spring for geese), no rain, the creatures' arrival
## waits cleared, and the woodpecker and geese started on cue. `--dry` runs
## headless-style and prints numbers only. Prints "FILM begin t=" (seconds of
## movie to trim from the front, spent loading).
const FPS := 30.0
var scene: Node3D
var life: Node3D
var editor: NativeChunkEditor
var shot := "dragonflies"
var dry := false
var frame := 0
## Every frame since the script began, for trimming the loading off the movie.
var total := 0
## The camera's how-to hint, kept off the frame.
var hints: Array[Node] = []
const POND := Vector2(-3.0, 2.0)
const FLOWERS := Vector2(6.0, -5.0)
const SNAG := Vector2(5.0, 7.0)

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="): shot = arg.trim_prefix("--shot=")
		if arg == "--dry": dry = true
	run.call_deferred()

func ground(p: Vector2) -> Vector3:
	return editor.terrain.to_global(Vector3(p.x,float(editor.data.ground_height(p)),p.y))

func look(at: Vector3, distance: float, yaw: float, polar: float) -> void:
	scene.target = at
	scene.distance = distance
	scene.yaw = deg_to_rad(yaw)
	scene.polar = deg_to_rad(polar)
	scene._update_camera()

func tick() -> void:
	# Arrivals wait tens of seconds; on cue, they do not.
	for fly: Dictionary in life.small.dragonflies.flies: fly.wait = 0.0
	for fly: Dictionary in life.small.butterflies.flies: fly.wait = 0.0
	life.small.butterflies._since = 100.0
	for node: Node in hints:
		node.visible = false
		if node is CanvasItem: node.modulate.a = 0.0
	await process_frame
	frame += 1

func hold(seconds: float) -> void:
	for i in range(int(seconds*FPS)): await tick()

func run() -> void:
	process_frame.connect(func() -> void: total += 1)
	root.size = Vector2i(1280,720)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.places_path = "/private/tmp/zs-small-film-%d/places.json" % Time.get_ticks_usec()
	scene.set_meta("movie_capture",true)
	root.add_child(scene)
	current_scene = scene
	create_timer(500).timeout.connect(func() -> void: push_error("film timed out"); quit(2))
	while not scene.places_ready or not scene.shell_ready: await process_frame
	editor = scene._chunk_editor
	life = scene.land_life
	while scene._growth.terrain < 0.995: await process_frame
	scene._notice.visible = false
	if scene.places.get("cover") != null: scene.places.cover.visible = false
	if scene.creation_palette != null: scene.creation_palette.visible = false
	for layer: Node in scene.find_children("*","CanvasLayer",true,false): layer.visible = false
	for node: Node in scene.find_children("*","Control",true,false):
		if (node is Label and node.text.begins_with("Double-click")) or (node is Button and node.text == "×"): hints.append(node)
	if scene.get("god_hand") is Node: hints.append(scene.get("god_hand"))
	scene.apply_scene_mood("Alpine daylight")
	scene._celestial.set_phase(0.4)
	scene._precipitation.set_weather(scene._precipitation.PRESET_NAMES.find("clear"),true)
	scene.world_clock.season_override = 0.05 if shot == "geese" else 0.3
	var overview := [scene.target,scene.distance,rad_to_deg(scene.yaw),rad_to_deg(scene.polar)]
	# The world: a pond in a basin with a wood on its bank, a flowering meadow
	# patch, and a lone snag standing clear.
	var data := editor.data
	data.begin_stroke()
	for _pass in range(6): data.brush(POND,4.2,0.3,"lower",0.0)
	var bottom: float = data.ground_height(POND)
	data.add_pond(POND,bottom+0.75)
	for i in range(14):
		var p := POND+Vector2.from_angle(-1.2+float(i)*0.19)*(6.0+0.8*sin(float(i)*2.3))
		var id := data.place("broadleaf" if i%3 else "tree",p,float(i),0.9)
		if id >= 0: data.objects.back()["source"] = "emerged"
	for i in range(18):
		data.place(["daisy_flower","button_flower","spike_flower","umbel_flower"][i%4],FLOWERS+Vector2.from_angle(float(i)*1.3)*(0.6+float(i%6)*0.45),0.0,1.0)
	for i in range(6): data.place("reeds",POND+Vector2.from_angle(2.6+float(i)*0.25)*(3.9+0.2*float(i%2)),0.0,1.0)
	data.place("snag",SNAG,0.4,1.0)
	data.end_stroke()
	await editor.refresh(self)
	while life.survey == null or life.survey.flower_spots.size() < 4: await process_frame
	for i in range(int(2.0*FPS)): await tick()
	print("FILM staged flowers=%d snags=%d ponds=%d dragon=%d butter=%d" % [life.survey.flower_spots.size(),life.survey.snag_spots.size(),life.survey.bodies.size(),life.small.dragonflies.flies.size(),life.small.butterflies.flies.size()])
	var begin := frame
	var seconds := 24.0
	match shot:
		"dragonflies":
			look(ground(POND)+Vector3(0,0.3,0),4.6,25.0,72.0)
			print("FILM begin t=%.2f" % (total/FPS))
			await hold(seconds)
		"butterflies":
			look(ground(FLOWERS)+Vector3(0,0.5,0),4.2,-30.0,68.0)
			print("FILM begin t=%.2f" % (total/FPS))
			await hold(seconds)
		"woodpecker":
			look(ground(SNAG)+Vector3(0,1.5,0),3.6,20.0,84.0)
			print("FILM begin t=%.2f" % (total/FPS))
			await hold(2.0)
			print("FILM woodpecker start=",life.small.woodpecker.start())
			await hold(22.0)
		"geese":
			var peak := 0.0
			for h in life.survey.height: if not is_nan(h): peak = maxf(peak,h)
			look(Vector3(0,peak+9.0,0),26.0,0.0,78.0)
			print("FILM begin t=%.2f" % (total/FPS))
			await hold(2.0)
			var geese = life.small.geese
			print("FILM geese start=",geese.start())
			# The same flock, sent across the view rather than along it.
			var f: Dictionary = geese._flock
			var way := deg_to_rad(90.0)
			f.way = way
			f.heading = Vector3(sin(way),0,cos(way))
			f.start = -f.heading*geese.RUN*0.5
			await hold(23.0)
		"wide":
			look(overview[0],overview[1],overview[2],overview[3])
			print("FILM begin t=%.2f" % (total/FPS))
			await hold(4.0)
			print("FILM woodpecker start=",life.small.woodpecker.start()," geese start=",life.small.geese.start())
			await hold(26.0)
	print("FILM end frames=%d dragon=%d butter=%d wp_rolls=%d honks=%d" % [frame-begin,life.small.dragonflies.showing(),life.small.butterflies.showing(),life.small.woodpecker.rolls_played,life.small.geese.honks_played])
	quit()
