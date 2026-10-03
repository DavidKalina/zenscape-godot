extends SceneTree
## First steps: the state machine, its saving, and the verbs noticed from stand-in
## pieces that send the signals and keep the counters the world's own do.
const FirstSteps = preload("res://scripts/first_steps.gd")
var failures := 0
var found: Array[String] = []
var steps: Array[String] = []
var finishes := 0

func _initialize() -> void:
	_machine()
	_saving()
	_missing_pieces()
	_detection()
	_again()
	if failures == 0: print("PASS: first steps")
	else: print("FAILED: first steps, %d failures"%failures)
	quit(1 if failures > 0 else 0)

func _machine() -> void:
	var fs := _fresh()
	check(FirstSteps.VERBS.size() == 25,"There are 25 verbs")
	check(FirstSteps.STEPS.all(func(id: String) -> bool: return FirstSteps.VERBS.has(id)),"Every step is a verb")
	check(FirstSteps.VERBS.keys().all(func(id: String) -> bool: return FirstSteps.GROUPS.any(func(g: Array) -> bool: return g[0] == FirstSteps.VERBS[id].group)),"Every verb is in a group")
	check(fs.current() == "look" and fs.steps_found() == 0,"It starts at the first step")
	fs.mark("glide")
	check(fs.current() == "look" and fs.found.has("glide") and steps.is_empty(),"A verb outside the steps is found and moves nothing")
	fs.mark("raise")
	check(fs.current() == "look" and fs.steps_found() == 1,"A later step done early waits its turn")
	fs.mark("look")
	check(fs.current() == "groove" and steps == ["groove"],"The card moves past every step already found")
	check(found == ["glide","raise","look"],"verb_found is sent once each, in order: %s"%str(found))
	fs.mark("look")
	fs.mark("not-a-verb")
	check(found.size() == 3 and not fs.found.has("not-a-verb"),"A verb found twice, or an unknown one, is nothing")
	for id: String in ["groove","water","tree"]: fs.mark(id)
	check(fs.current() == "turn" and finishes == 0,"One step left, not finished")
	fs.mark("turn")
	check(fs.current().is_empty() and finishes == 1 and steps.back() == "","The last step finishes the card")
	check(fs.steps_found() == FirstSteps.STEPS.size(),"All steps found")
	fs.restart()
	check(fs.current() == "look" and fs.found.has("glide") and not fs.found.has("look"),"Restart asks the steps again and keeps the other verbs")
	check(steps.back() == "look","Restart sends the first step")
	fs.skip()
	check(fs.skipped and fs.current().is_empty() and steps.back() == "" and finishes == 1,"Skip puts it away without finishing")
	fs.skip()
	fs.mark("look")
	check(fs.current().is_empty() and fs.found.has("look"),"A skipped card stays away, verbs still found")
	fs.restart()
	check(not fs.skipped and fs.current() == "look","Restart brings a skipped card back")
	fs.free()

func _saving() -> void:
	var path := OS.get_temp_dir().path_join("first-steps-test-%d.cfg"%Time.get_ticks_usec())
	var one := _fresh(path)
	one.mark("look")
	one.mark("glide")
	var two := _fresh(path)
	two.setup(null,null)
	check(two.found.has("look") and two.found.has("glide") and two.current() == "raise","Found verbs come back from the file")
	two.skip()
	var three := _fresh(path)
	three.setup(null,null)
	check(three.skipped and three.current().is_empty(),"The skip comes back from the file")
	three.restart()
	var four := _fresh(path)
	four.setup(null,null)
	check(not four.skipped and not four.found.has("look") and four.found.has("glide"),"Restart is kept: steps asked again, other verbs kept")
	var quiet := _fresh("")
	quiet.mark("look")
	check(not FileAccess.file_exists(""),"No path, no file")
	for fs: Node in [one,two,three,four,quiet]: fs.free()
	DirAccess.remove_absolute(path)

func _missing_pieces() -> void:
	var fs := _fresh()
	fs.setup(null,null)
	var bare := Node.new()
	var hand := Node.new()
	fs.setup(bare,null)
	fs._process(0.1)
	fs.setup(bare,hand)
	fs._poll(0.1)
	fs._poll(0.1)
	check(fs.found.is_empty(),"Nothing to listen to marks nothing")
	fs.free()
	bare.free()
	hand.free()

func _detection() -> void:
	var world := _world()
	var fs := _fresh()
	fs.setup(world.scene,world.reach)
	fs._poll(0.1)
	check(fs.found.is_empty(),"What is counted before the listening is not news")
	# The land.
	world.clay.lift = 0.2
	world.clay.worked.emit("pinch",true)
	check(not fs.found.has("raise"),"A pinch that lifted next to nothing is not a raise")
	world.clay.lift = 2.5
	world.clay.worked.emit("pinch",false)
	check(not fs.found.has("raise"),"A pinch that kept nothing is not a raise")
	world.clay.worked.emit("pinch",true)
	check(fs.found.has("raise") and not fs.found.has("hollow"),"A kept pinch that lifted is a raise")
	world.clay.lift = -1.5
	world.clay.worked.emit("fine_pinch",true)
	check(fs.found.has("hollow"),"A kept pinch that sank is a hollow")
	world.clay.verb = "thumb"
	world.clay.last_rub = 0.0
	fs._poll(0.5)
	world.clay.verb = ""
	world.clay.worked.emit("groove",true)
	check(fs.found.has("groove") and not fs.found.has("smooth"),"A thumb that dug is a groove")
	world.clay.verb = "thumb"
	world.clay.last_rub = 1.0
	fs._poll(0.5)
	world.clay.verb = ""
	world.clay.worked.emit("groove",true)
	check(fs.found.has("smooth"),"A thumb that rubbed is a smoothing")
	world.clay.worked.emit("palm",false)
	check(not fs.found.has("level"),"A palm that changed nothing is not a level")
	world.clay.worked.emit("palm",true)
	check(fs.found.has("level"),"A palm that changed the land is a level")
	world.clay.notches += 1
	fs._poll(0.1)
	check(fs.found.has("spillway"),"A notch in the rim is a spillway")
	world.materials.roll.tool = "hand"
	fs._poll(0.1)
	check(not fs.found.has("tool"),"The Modeller is not a tool taken up")
	world.materials.roll.tool = "mountain"
	fs._poll(0.1)
	check(fs.found.has("tool"),"Another tool on the roll is a tool taken up")
	world.editor.undos += 1
	fs._poll(0.1)
	check(fs.found.has("undo"),"A step taken back is an undo")
	# The eye.
	world.rig._used = {"orbit":true}
	fs._poll(0.1)
	check(not fs.found.has("look"),"Orbiting alone is not looking round")
	world.rig._used = {"orbit":true,"zoom":true,"focus":true}
	fs._poll(0.1)
	check(fs.found.has("look") and fs.found.has("glide"),"Orbit and zoom are looking round; a focus is a glide")
	world.photo.saved.emit("")
	check(not fs.found.has("photo"),"A photo that failed is not a photo")
	world.photo.saved.emit("/tmp/x.png")
	check(fs.found.has("photo"),"A photo kept is a photo")
	# Trees.
	world.reach.tree_spores += 1
	world.reach.plucked += 1
	fs._poll(0.1)
	check(fs.found.has("tree") and fs.found.has("pluck"),"Spores thrown, a plant plucked")
	# The edge.
	world.reach.rim_intent = "turn"
	world.scene.yaw = 0.1
	fs._poll(0.1)
	check(not fs.found.has("turn"),"A nudge on the rim is not a turn")
	world.scene.yaw = 0.8
	fs._poll(0.1)
	check(fs.found.has("turn"),"The rim carried the world round")
	world.reach.rim_intent = ""
	world.globe.shake_started.emit()
	check(fs.found.has("shake"),"The shake")
	world.flip.dipped.emit(0.0)
	check(not fs.found.has("spring"),"A dip with no pull springs nothing")
	world.flip.dipped.emit(0.6)
	check(fs.found.has("spring"),"A pull let go springs the land")
	world.flip.set_down.emit(0.02)
	check(not fs.found.has("basin"),"A hardly lifted rim sinks no basin")
	world.flip.set_down.emit(0.3)
	check(fs.found.has("basin"),"A lifted rim set down slowly sinks a basin")
	world.flip.landed.emit(7)
	check(fs.found.has("flip"),"A new world landed")
	# The sky.
	world.wind.gusts += 1
	fs._poll(0.1)
	check(fs.found.has("gust"),"A gust sent")
	# The case.
	world.editor.ball_settled.emit({"kind":"pond"})
	check(not fs.found.has("scoop"),"A ball with no water from the case is not Carry water")
	world.reach.uses["water"] = 1
	fs._poll(0.1)
	check(not fs.found.has("scoop"),"Water taken is not water carried")
	world.editor.ball_settled.emit({"kind":"pond"})
	check(fs.found.has("scoop"),"Water from the case settled")
	check(not fs.found.has("water"),"The can has not poured yet")
	world.can.poured = 0.2
	fs._poll(0.1)
	check(not fs.found.has("water"),"A can that is not pouring has not poured")
	world.can.pouring = true
	fs._poll(0.1)
	check(fs.found.has("water"),"The can poured")
	world.materials.flicks += 1
	world.reach.uses["stone"] = 1
	fs._poll(0.1)
	check(fs.found.has("sow") and fs.found.has("stone"),"Seeds flicked, a stone set")
	# The air.
	world.look.mood = "dusk"
	fs._poll(0.1)
	check(fs.found.has("mood") and not fs.found.has("night"),"A new mood")
	world.look.pins = {"time":"night"}
	fs._poll(0.1)
	check(fs.found.has("night"),"Time pinned is the night")
	check(FirstSteps.VERBS.keys().all(func(id: String) -> bool: return fs.found.has(id)),"All 25 verbs were noticed: missing %s"%str(FirstSteps.VERBS.keys().filter(func(id: String) -> bool: return not fs.found.has(id))))
	# A world opening restores its own air without the hand.
	var again := _fresh()
	again.setup(world.scene,world.reach)
	again._poll(0.1)
	world.session.current_id = "other"
	world.look.mood = "snow"
	world.look.pins = {"time":"morning"}
	again._poll(0.1)
	check(not again.found.has("mood") and not again.found.has("night"),"A world opening is not the hand's doing")
	world.look.mood = "dusk"
	again._poll(0.1)
	check(again.found.has("mood"),"A mood changed after it opened is")
	again.free()
	fs.free()
	_free_world(world)

## Setting up again (another world, or the scene again) connects nothing twice.
func _again() -> void:
	var world := _world()
	var fs := _fresh()
	fs.setup(world.scene,world.reach)
	fs.setup(world.scene,world.reach)
	check(world.globe.shake_started.get_connections().size() == 1 and world.clay.worked.get_connections().size() == 1,"A second setup connects nothing twice")
	world.reach.tree_spores += 1
	fs.setup(world.scene,world.reach)
	fs._poll(0.1)
	check(not fs.found.has("tree"),"A second setup takes the counters afresh")
	fs.free()
	_free_world(world)

func _fresh(path := "") -> Node:
	found.clear()
	steps.clear()
	finishes = 0
	var fs: Node = FirstSteps.new()
	fs.settings_path = path
	fs.verb_found.connect(func(id: String) -> void: found.append(id))
	fs.step_changed.connect(func(id: String) -> void: steps.append(id))
	fs.finished.connect(func() -> void: finishes += 1)
	return fs

## Stand-ins with the signals and counters the pieces really have.
func _world() -> Dictionary:
	var world := {}
	world.clay = _stub("signal worked(verb: String, kept: bool)\nvar verb := \"\"\nvar last_rub := 0.0\nvar lift := 0.0\nvar notches := 0")
	world.globe = _stub("signal shake_started")
	world.flip = _stub("signal dipped(amount: float)\nsignal set_down(progress: float)\nsignal landed(world_seed: int)")
	world.photo = _stub("signal saved(path: String)")
	world.editor = _stub("signal ball_settled(outcome: Dictionary)\nvar undos := 0\nvar can")
	world.can = _stub("var pouring := false\nvar poured := 0.0")
	world.editor.can = world.can
	world.rig = _stub("var _used := {}")
	world.look = _stub("var mood := \"\"\nvar pins := {}")
	world.places = _stub("var busy := false")
	world.session = _stub("var current_id := \"a\"\nvar previewing := false")
	world.roll = _stub("var tool := \"hand\"")
	world.materials = _stub("var flicks := 0\nvar roll")
	world.materials.roll = world.roll
	world.wind = _stub("var gusts := 0")
	world.cloud = _stub("var summons := 0\nvar given := 0.0")
	world.reach = _stub("var tree_spores := 0\nvar plucked := 0\nvar snaps := 0\nvar rim_intent := \"\"\nvar uses := {}\nvar wind\nvar cloud\nvar materials")
	world.reach.wind = world.wind
	world.reach.cloud = world.cloud
	world.reach.materials = world.materials
	world.scene = _stub("var land_clay\nvar snow_globe\nvar flip\nvar photo\nvar _chunk_editor\nvar camera_rig\nvar mood_look\nvar places\nvar world_session\nvar titled := false\nvar yaw := 0.0")
	world.scene.land_clay = world.clay
	world.scene.snow_globe = world.globe
	world.scene.flip = world.flip
	world.scene.photo = world.photo
	world.scene._chunk_editor = world.editor
	world.scene.camera_rig = world.rig
	world.scene.mood_look = world.look
	world.scene.places = world.places
	world.scene.world_session = world.session
	return world

func _free_world(world: Dictionary) -> void:
	for piece: Node in world.values(): piece.free()

func _stub(source: String) -> Node:
	var script := GDScript.new()
	script.source_code = "extends Node\n"+source+"\n"
	script.reload()
	var node := Node.new()
	node.set_script(script)
	return node

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		print("FAIL: "+message)
