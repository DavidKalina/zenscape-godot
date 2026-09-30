extends SceneTree
## Film predation (docs/scenic/life.md, "Predation") close up on a dug pond: the
## heron drawing in a fish and catching it, a miss, a carry-off, and the grass
## snake stalking, striking and swallowing a frog (or the frog escaping).
## Rendered, with a window:
##   Godot --windowed --resolution 1280x720 --fixed-fps 30 --path . \
##     --write-movie /tmp/zs-film/02-predation-a.avi \
##     -s res://tools/film_predation.gd -- --no-title --shot=catch
## Shots: catch, miss, carry, snake, escape. The world is staged fast before
## the shot, so trim the movie from the "FILM shot" time it prints. Headless it
## runs the same staging and prints the beats (a dry run).
## Staging only: the film forces the heron's lure and its outcome, and the
## snake's try for a frog; nothing in the feature code changes.
const FPS := 30.0
const DT := 1.0/FPS
## Life steps per frame while the world is staged off camera.
const FAST := 8
var scene: Node3D
var life: Node3D
var shot := "catch"
## --stop=S ends the run S s into the movie, for a smoke test.
var stop := -1.0
var frame := 0
var shot_frame := -1
## Camera, in life space: what it looks at, and from how far and how high.
var look := Vector3.ZERO
var side := 0.0
var distance := 3.2
var polar := 1.25

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="): shot = arg.trim_prefix("--shot=")
		if arg.begins_with("--stop="): stop = float(arg.trim_prefix("--stop="))
	create_timer(900.0).timeout.connect(func() -> void: print("FILM timed out"); quit(2))
	run.call_deferred()

func run() -> void:
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.places_path = "/private/tmp/zs-pred-film-%d/places.json" % Time.get_ticks_usec()
	scene.set_meta("movie_capture",true)
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	var editor: NativeChunkEditor = scene._chunk_editor
	var data := editor.data
	editor.set_process_input(false)
	scene.set_process_input(false)
	scene.set_process_unhandled_input(false)
	while scene._growth.terrain < 0.995: await process_frame
	scene._notice.visible = false
	if scene.places.get("cover") != null: scene.places.cover.visible = false
	if scene.creation_palette != null: scene.creation_palette.visible = false
	for layer: Node in scene.find_children("*","CanvasLayer",true,false): layer.visible = false
	scene.apply_scene_mood("Alpine daylight")
	scene._precipitation.set_weather(scene._precipitation.PRESET_NAMES.find("clear"),true)
	# Morning: the snake's hour, and good light for the heron.
	scene._celestial.set_phase(0.34)
	life = scene.land_life
	# A pond with shrubs on its west bank, as the snake probe digs it.
	var basin := Vector2(-3.0,2.0)
	data.begin_stroke()
	for _pass in range(6): data.brush(basin,4.2,0.3,"lower",0.0)
	var bottom: float = data.ground_height(basin)
	data.add_pond(basin,bottom+0.75)
	for i in range(7):
		var p := basin+Vector2.from_angle(2.2+float(i)*0.28)*(5.2+0.5*sin(float(i)*1.9))
		var id := data.place("fern" if i%2 else "shrub",p,float(i),1.0)
		if id >= 0: data.objects.back()["source"] = "emerged"
	data.end_stroke()
	await editor.refresh(self)
	look = Vector3(basin.x,bottom+0.75,basin.y)
	distance = 9.0
	life.pace = 8.0
	var waiting := 0
	while waiting < 30*90 and (life.survey == null or life.present("fish").size() < 4 or life.present("frog").size() < 2):
		waiting += 1
		await frame_step(0)
	print("FILM world fish=%d frogs=%d t=%.1f" % [life.present("fish").size(),life.present("frog").size(),frame/FPS])
	life.set_process(false)
	life.moments.clear()
	life.snakes.clear()
	# Nothing else comes on its own while we film.
	life.moments._heron_next = INF
	life.snakes._next = INF
	life.moments._deer_next = INF
	if shot in ["snake","escape"]: await film_snake()
	else: await film_heron()
	print("FILM end t=%.2f shot_from=%.2f" % [frame/FPS,shot_frame/FPS])
	scene.queue_free()
	await process_frame
	quit()

## One rendered frame, after `steps` life steps.
func frame_step(steps: int) -> void:
	for i in range(steps):
		life.clock += DT
		life._tick += DT
		if life._tick >= life.TICK:
			life._tick = 0.0
			life._arrive_due()
		life._animate(DT)
		life.moments.advance(DT,DT)
		life.snakes.advance(DT)
	# Clean frames: no hand, hints or labels.
	var hand: Node3D = scene.get("god_hand") as Node3D
	if hand != null:
		hand.process_mode = Node.PROCESS_MODE_DISABLED
		hand.visible = false
	if frame%10 == 0:
		for node: Node in scene.find_children("*","CanvasLayer",true,false): node.visible = false
		for node: Node in scene.find_children("*","Control",true,false):
			if not node.get_parent() is Control: node.visible = false
	var target: Vector3 = life.to_global(look)
	scene.target = target
	scene.distance = distance
	scene.polar = polar
	scene.yaw = side
	scene._update_camera()
	await process_frame
	frame += 1
	if stop > 0.0 and frame/FPS > stop: quit()

func mark(what: String) -> void:
	if shot_frame < 0: shot_frame = frame
	print("FILM shot %s t=%.2f" % [what,frame/FPS])

# --- Heron ----------------------------------------------------------------------

func film_heron() -> void:
	var moments: Node3D = life.moments
	if not moments.force("heron"):
		print("FILM no heron")
		return
	var s: Dictionary = moments._heron_state
	var spot: Vector3 = s.spot
	# From its side, a little ahead, close on where the bill goes in.
	side = float(s.yaw)+PI*0.5-0.35
	distance = 2.2
	polar = 1.32
	mark("heron lands")
	var done := false
	var after := -1.0
	var tries := 0
	while not moments._heron_state.is_empty() and frame < 30*400:
		s = moments._heron_state
		if s.phase == "stand":
			# Lure every strike until the one that is filmed.
			var strike := float(s.age)-float(s.strike)
			# A step ahead of LifeMoments, which would weigh it by its own odds.
			if not s.get("weighed",false) and strike+2.0*DT >= 0.25-moments.HERON_LURE_TIME and not done:
				s.weighed = true
				tries += 1
				lure(s,0.25-strike)
			if s.get("caught",false) and moments._heron_rig != null:
				s.carry_off = shot == "carry"
				moments._heron_rig._carry = shot == "carry"
			if s.get("rang",false) and not done:
				done = true
				after = frame/FPS
				print("FILM strike t=%.2f caught=%s" % [after,s.get("caught",false)])
		var beak: Vector3 = moments._beak() if s.has("spot") else spot
		var heron: Vector3 = moments._heron.position
		# Follow the heron's head in flight, the bill while it stands.
		var want := beak+Vector3(0,0.62,0) if s.phase == "stand" else heron+Vector3(0,0.6,0)
		look = look.lerp(want,1.0-exp(-DT*(3.0 if s.phase == "stand" else 1.6))) if frame > shot_frame+1 else want
		if s.phase == "out" and shot == "carry": distance = lerpf(distance,5.0,DT*0.8)
		await frame_step(1)
		# Hold on after the beat, then stop, unless it is flying off with it.
		if after >= 0.0 and frame/FPS > after+(9.0 if shot == "carry" else 6.0): break
	print("FILM heron catches=%d carried=%d tries=%d" % [moments.catches,moments.carried,tries])

## Draw in the nearest fish now, whatever the odds, with the shot's outcome.
func lure(s: Dictionary, lead: float) -> void:
	var moments: Node3D = life.moments
	var beak: Vector3 = moments._beak()
	var at := Vector2(beak.x,beak.z)
	var best := {}
	var nearest := 3.0
	for site: Dictionary in life.present("fish"):
		var p: Vector3 = site.get("shown_p",site.p)
		var d := Vector2(p.x,p.z).distance_to(at)
		if d < nearest and life.survey.wet_at(Vector2(p.x,p.z).lerp(at,0.5)):
			nearest = d
			best = site
	print("FILM lure lead=%.2f fish=%.2f m wet=%s" % [lead,nearest,life.survey.wet_at(at)])
	if best.is_empty(): return
	best.lure = {"to":beak,"from":life.clock,"at":life.clock+maxf(lead-moments.HERON_HOVER,0.5),"dart":-1.0}
	s.prey = best
	s.catch = shot != "miss"

# --- Snake ----------------------------------------------------------------------

func film_snake() -> void:
	var snakes: Node3D = life.snakes
	for visit in range(6):
		snakes.clear()
		if not snakes.force({"take":true,"bask":2.0,"hunts":6,"swim":false}):
			print("FILM no snake")
			return
		# Off camera, fast, until it sets off for a frog.
		var first: int = snakes.journal.size()
		var seen := false
		while snakes.showing() != "" and not seen:
			await frame_step(FAST)
			for entry: Array in snakes.journal.slice(first):
				if str(entry[1]) == "stalk": seen = true
		if seen: break
		print("FILM visit %d found no frog" % visit)
	if snakes.showing() == "":
		print("FILM the snake never tried for a frog")
		return
	var prey: Dictionary = snakes._state.get("prey",{})
	var frog: Vector3 = prey.get("home",snakes._head_pos)
	var head: Vector3 = snakes._head_pos
	var way := Vector2(frog.x-head.x,frog.z-head.z)
	# From the side of its way to the frog, both in frame.
	side = atan2(way.x,way.y)+PI*0.5
	# From outside NOTICE, or it stops to watch the camera: a long lens instead.
	distance = 7.5
	polar = 1.12
	scene.camera.fov = 22.0
	look = head
	mark("snake sets off for the frog")
	var struck := -1.0
	while snakes.showing() != "" and frame < 30*400:
		# The shot decides whether the frog gets away.
		for item: Dictionary in snakes._plan:
			if str(item.get("kind","")) == "strike": item.escape = shot == "escape"
		if struck < 0.0 and snakes._hold.get("struck",false):
			struck = frame/FPS
			print("FILM strike t=%.2f took=%d snout_to_frog=%.3f pose_w=%.2f lunge=%.2f frog_mode=%s" % [struck,snakes.takes,Vector2(snakes._snout.x,snakes._snout.z).distance_to(Vector2(frog.x,frog.z)),snakes._pose_w,snakes._lunge,prey.get("mode","")])
		# On its head, taking the frog in as it gets close.
		var want: Vector3 = snakes._head_pos
		var near := Vector2(want.x-frog.x,want.z-frog.z).length()
		if struck < 0.0 and near < 1.4: want = want.lerp(frog,0.4*(1.0-near/1.4))
		look = look.lerp(want,1.0-exp(-DT*1.5))
		await frame_step(1)
		# The swallow, then a little of the slow retreat.
		if struck >= 0.0 and frame/FPS > struck+(16.0 if snakes.takes > 0 else 5.0): break
	print("FILM snake takes=%d" % snakes.takes)
