extends SceneTree
## Headless probe: a flip (scripts/diorama_flip.gd) gives a blank slate, and
## growth follows only the player's water (docs/scenic/emergence.md "Whose
## water"). Opens the product scene with `--modeless` (live water), then:
## - before a flip: the V figure stands (scripts/wanderer_eye.gd), branches lie
##   (scripts/dead_wood.gd), falls stand in both falls lists (injected, with
##   their nodes, since the dummy renderer makes real ones slowly), the
##   editor's pond record is full, and a water ball is let go as it is thrown;
## - after it: no figure, no branches nor sites to drop more on, no falls, an
##   empty pond record (read as the world is replaced, and once landed), the
##   ball gone without landing and the new plain dry;
## - on the new plain: water the player did not pour (the weather's rain and
##   a tap standing in for runoff or an old spring) fills a hollow, and the
##   pond change is reported to life but queues no growth; a water ball the
##   player drops in another hollow does queue growth, as "water".
## Nothing is rendered: how any of it looks is not checked here.
##   godot --headless --fixed-fps 60 --path . -s res://tools/probe_flip_blank_slate.gd -- --modeless --no-title
var scene: Node3D
var editor: NativeChunkEditor
var flip: Node
var failures := []
## Emergence's queue as seen each frame: sources of every entry queued.
var queued_sources: Array = []
var _seen_queue := {}
var settled_rects: Array[Rect2] = []

func _initialize() -> void: run.call_deferred()

func check(label: String, ok: bool, detail: Variant = "") -> void:
	if not ok: failures.append(label)
	print(("OK   " if ok else "FAIL ")+label+("" if str(detail).is_empty() else "  "+str(detail)))

## One frame, noting what reached emergence's queue meanwhile.
func tick() -> void:
	await process_frame
	for entry: Dictionary in editor.emergence._queued:
		var key := str(entry.rect)+str(entry.born)
		if _seen_queue.has(key): continue
		_seen_queue[key] = true
		queued_sources.append(entry.source)

func frames(count: int) -> void:
	for i in range(count): await tick()

func settle(limit := 1500) -> void:
	var n := 0
	while (flip.phase != flip.Phase.IDLE or scene.places.busy or editor.forming) and n < limit:
		await tick()
		n += 1
	await frames(6)

func baked(seed: int) -> bool:
	for i in range(600):
		if flip._under_seed == seed and flip._under_mesh != null: return true
		await tick()
	return false

func ground(p: Vector2) -> float:
	return float(editor.data.ground_height(p))

## A hollow in the data only, not a stroke: the land as it stands, not the
## player's work this minute.
func hollow(at: Vector2) -> void:
	var data := editor.data
	data.begin_stroke()
	for _pass in range(10): data.brush(at,2.6,0.6,"lower",0.0)
	data.end_stroke()

func water(center: Vector2, radius: float) -> float:
	var flow: RefCounted = editor.flow
	var depths: PackedFloat32Array = flow.depths()
	var total := 0.0
	for j in range(flow.height):
		for i in range(flow.width):
			if (flow.origin+Vector2(i+0.5,j+0.5)*flow.cell).distance_to(center) < radius: total += depths[j*flow.width+i]
	return total*flow.cell*flow.cell

func fake_fall(falls: Node3D, id: int) -> void:
	falls._falls.append({"id":id,"found":0.0,"lost":0.0,"shown":true,"presence":1.0,"target":{"side":0,"along":0.0},"now":{},"nodes":falls._create(id)})

func run() -> void:
	create_timer(280).timeout.connect(func() -> void: push_error("blank slate probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-blank-slate-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	editor = scene._chunk_editor
	flip = scene.flip
	for i in range(240):
		if editor.flow != null and editor.flow.ready: break
		await process_frame
	check("the flip and live water are built with --modeless",flip != null and editor.flow != null and editor.flow.ready)
	if flip == null or editor.flow == null or not editor.flow.ready:
		finish()
		return
	await settle()
	scene._precipitation.set_weather(0,true)
	if scene.get("living_weather") != null: scene.living_weather.drift = false
	editor.water_settled.connect(func(rect: Rect2) -> void: settled_rects.append(rect))

	# --- The old world's leftovers --------------------------------------------
	var wanderer: Node = scene.wanderer
	wanderer.place(Vector3(2.0,0.0,2.0))
	var wood: Node = scene.dead_wood
	wood._add_branch(Vector3(1.0,ground(Vector2(1,1))+0.06,1.0),0.0)
	wood._add_branch(Vector3(-3.0,ground(Vector2(-3,-3))+0.06,-3.0),0.5)
	if wood.sites.is_empty(): wood.sites.append(Vector3(4.0,ground(Vector2(4,4)),4.0))
	var view: Node = editor.flow_view
	var falls: Array[Node3D] = []
	for node: Variant in [view.falls,view.edge_falls]:
		if node == null: continue
		node.set_process(false)
		fake_fall(node,900)
		fake_fall(node,901)
		falls.append(node)
	var fall_nodes: Array = []
	for node in falls:
		for fall: Dictionary in node._falls:
			for part: Variant in fall.nodes.values():
				if part is Node: fall_nodes.append(part)
	editor._flow_pools = [{"x":3.0,"z":3.0,"area":12.0,"cells":[],"rect":Rect2(1,1,4,4)}]
	editor._flow_changed = Rect2(1,1,4,4)
	editor._flow_fish.append({"point":Vector2(3,3),"fish":[{"kind":"trout"}],"until":editor._flow_clock+90.0})
	editor._tend(Vector2(3,3),5.0)
	check("before: the figure stands",wanderer.has_figure())
	check("before: branches lie",wood.branches.size() == 2,wood.branches.size())
	check("before: falls stand in both lists",falls.size() == 2 and falls.all(func(n: Node3D) -> bool: return n._falls.size() == 2),falls.map(func(n: Node3D) -> int: return n._falls.size()))
	# A water ball let go as the flip is thrown, so it is in the air as the
	# plain forms (a held one is let go by the flip's `suspend_creation`).
	var drop_at := Vector2(-2.0,4.0)
	var toss := func(p: int) -> void:
		if p != flip.Phase.THROW or editor.ball != null and editor.ball.state != "idle": return
		editor._ball_press(Vector3(drop_at.x,ground(drop_at),drop_at.y))
		editor.ball_volume = 3.0
		editor.ball.hold(Vector3(drop_at.x,ground(drop_at),drop_at.y),3.0)
		editor._ball_release()
	flip.phase_changed.connect(toss)
	# Made once before, so its landing can be watched.
	editor._ball_press(Vector3(drop_at.x,ground(drop_at),drop_at.y))
	editor.ball.vanish()
	editor._ball_holding = false

	# --- The flip -----------------------------------------------------------------
	var at_restore := {}
	editor.data.state_restored.connect(func(state: Dictionary) -> void:
		if not state.is_empty() or not at_restore.is_empty(): return
		at_restore.merge({"pools":editor._flow_pools.size(),"changed":editor._flow_changed.has_area(),"fish":editor._flow_fish.size(),"tended":editor._flow_tended.size(),
			"figure":wanderer.has_figure(),"branches":wood.branches.size(),"sites":wood.sites.size(),"falls":falls.map(func(n: Node3D) -> int: return n._falls.size()),"ball":editor.ball.state}))
	var landed := [false]
	editor.ball.landed.connect(func(_p: Vector2, _v: float, _f: Array) -> void: landed[0] = true)
	var ball_states := []
	flip.phase_changed.connect(func(_p: int) -> void: ball_states.append(editor.ball.state))
	editor.formation_started.connect(func() -> void: ball_states.append("forming:"+editor.ball.state))
	flip.next_seed = 424242
	check("a plain is baked for the underside",await baked(424242),flip._under_seed)
	check("the flip is thrown",flip.debug_flip(1.0,1.6))
	await settle()
	flip.phase_changed.disconnect(toss)
	for node in falls: node.set_process(true)
	await frames(30)
	print("AT RESTORE ",JSON.stringify(at_restore))
	check("the flip landed on the new plain",editor.land_seed == 424242 and not editor.forming and flip.phase == flip.Phase.IDLE,editor.land_seed)
	check("as the world is replaced the pond record is empty (pools, changes, fish, tended)",at_restore.get("pools",-1) == 0 and not at_restore.get("changed",true) and at_restore.get("fish",-1) == 0 and at_restore.get("tended",-1) == 0,at_restore)
	check("no wanderer figure remains",not wanderer.has_figure() and wanderer.figure == null)
	check("no figure node is left on the terrain",editor.terrain.find_children("Wanderer","",false,false).is_empty())
	check("no branches remain, nor sites under the old trees",wood.branches.is_empty() and wood.sites.is_empty(),{"branches":wood.branches.size(),"sites":wood.sites.size()})
	check("no FallenBranch nodes are left",wood.get_children().filter(func(n: Node) -> bool: return str(n.name).begins_with("FallenBranch")).is_empty())
	wood.drop = 0.999
	check("and none drops until the habitat is rebuilt",not wood._drop_one() and wood.branches.is_empty())
	check("no falls entries remain in either list",falls.all(func(n: Node3D) -> bool: return n._falls.is_empty()),falls.map(func(n: Node3D) -> int: return n._falls.size()))
	check("and their nodes are freed",fall_nodes.all(func(n: Variant) -> bool: return not is_instance_valid(n)))
	print("BALL ",ball_states)
	check("the ball was let go into the air as the plain formed",ball_states.has("forming:tossed"),ball_states)
	check("and went without landing",editor.ball.state == "idle" and not landed[0] and not editor._ball_holding,{"state":editor.ball.state,"landed":landed[0]})
	check("the new plain is dry",editor.flow.volume() < 0.01,editor.flow.volume())
	check("once landed the pond record holds no stale ponds or changes",editor._flow_pools.is_empty() and not editor._flow_changed.has_area() and editor._flow_fish.is_empty(),{"pools":editor._flow_pools.size(),"changed":editor._flow_changed})
	check("nothing was queued for growth by the flip",queued_sources.is_empty(),queued_sources)
	var emerged_before := emerged()

	# --- Rain grows nothing ---------------------------------------------------------
	var rain_at := Vector2(-6.0,-6.0)
	var drop2_at := Vector2(6.5,6.5)
	hollow(rain_at)
	hollow(drop2_at)
	await editor.refresh(self)
	await frames(10)
	queued_sources.clear()
	settled_rects.clear()
	var storm: int = WeatherScheduler.PRESET_NAMES.find("storm")
	scene._precipitation.set_weather(storm,true)
	editor.flow.taps["sky"] = [rain_at.x,rain_at.y,0.6,1.2]
	var rained := 0.0
	var rain_fall := 0.0
	for i in range(60*10):
		await tick()
		rain_fall = maxf(rain_fall,editor.flow.runoff.rain)
	editor.flow.taps.erase("sky")
	scene._precipitation.set_weather(0,true)
	for i in range(60*8): await tick()
	rained = water(rain_at,3.0)
	var rain_reports := settled_rects.filter(func(r: Rect2) -> bool: return r.grow(1.0).has_point(rain_at))
	print("RAIN ",JSON.stringify({"water_m3":snappedf(rained,0.01),"reports":settled_rects.size(),"over_hollow":rain_reports.size(),"queued":queued_sources,"rain":snappedf(rain_fall,0.01)}))
	check("rain and runoff filled the hollow",rained > 0.5 and rain_fall > 0.0,{"water":rained,"rain":rain_fall})
	check("the pond change was reported to life (water_settled)",not rain_reports.is_empty(),settled_rects)
	check("but queued no growth",queued_sources.is_empty() and not editor.emergence.busy(),queued_sources)
	check("and nothing emerged",emerged() == emerged_before,emerged())

	# --- The player's water grows ------------------------------------------------------
	queued_sources.clear()
	settled_rects.clear()
	var lands := [false]
	editor.ball.landed.connect(func(_p: Vector2, _v: float, _f: Array) -> void: lands[0] = true)
	editor._ball_press(Vector3(drop2_at.x,ground(drop2_at),drop2_at.y))
	editor.ball_volume = 6.0
	editor.ball.hold(Vector3(drop2_at.x,ground(drop2_at),drop2_at.y),6.0)
	await frames(2)
	editor._ball_release()
	for i in range(60*15):
		await tick()
		if lands[0] and queued_sources.has("water"): break
	print("DROP ",JSON.stringify({"landed":lands[0],"water_m3":snappedf(water(drop2_at,3.5),0.01),"reports":settled_rects.size(),"queued":queued_sources}))
	check("the player's ball landed",lands[0])
	check("and its pond queued growth, as water",queued_sources.has("water"),queued_sources)
	finish()

## Objects emergence grew.
func emerged() -> int:
	var count := 0
	for item: Dictionary in editor.data.objects:
		if editor.data.object_source(item) == "emerged": count += 1
	return count

func finish() -> void:
	if flip != null:
		await flip.wait_idle()
	print("RESULT ","PASS" if failures.is_empty() else "FAIL "+str(failures))
	quit(0 if failures.is_empty() else 1)
