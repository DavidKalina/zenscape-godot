extends SceneTree
## Headless probe of pollen (scripts/pollen_cloud.gd, docs/scenic/brushes.md
## "Pollen") on the Genesis plain, through the real input path: a mouse press
## with forest in hand, the editor's own _process following the pointer
## (pointer_override) while the cloud gathers, then a release. The wind is set
## on the scene's atmosphere. Each release reports the wind it went on, the
## motes and seeds that settled and every landing against the footprint it
## was promised (all must be inside), how far the settled cloud sat from the
## pointer and along the wind, what grew and why by habitat (Emergence
## `sown_outcomes`, and the habitat under every new tree), main-loop frame
## gaps and the cloud's own step while it gathered, fell and grew, the undo
## steps added, and whether one undo restores the wish, the floor tint and
## the objects. Releases: puffs and full clouds in still air and in steady
## wind, and a full cloud over mixed ground (a raised peak's flank, rock and
## top, and the edge of a pond dropped there first). Then an undo while a
## cloud is still in the air, a Shift press (clears by painting) and a press
## with pollen off (--paint-forest paints).
##   -- --grow=26
## Frame gaps are CPU main-loop intervals under the dummy renderer.
const Wind = preload("res://scripts/pollen_wind.gd")
const Emergence = preload("res://scripts/emergence.gd")
var scene: Node3D
var editor: NativeChunkEditor
var grow := 26.0
var failures := 0
var _settled := {}

func _initialize() -> void: run.call_deferred()

func stats(values: Array) -> Dictionary:
	if values.is_empty(): return {}
	var sorted := values.duplicate()
	sorted.sort()
	return {"n":sorted.size(),"median":snappedf(sorted[sorted.size()/2],0.01),"p95":snappedf(sorted[mini(sorted.size()-1,int(sorted.size()*0.95))],0.01),"max":snappedf(sorted.back(),0.01),
		"over_16_7":sorted.filter(func(v: float) -> bool: return v > 16.667).size()}

func screen_of(point: Vector2) -> Vector2:
	var data := editor.data
	return scene.camera.unproject_position(editor.terrain.to_global(Vector3(point.x,float(data.sample(point,data.heights)),point.y)))

func mouse(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	editor.handle_input(event)

func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ",what)

func set_wind(strength: float, degrees: float) -> void:
	var air = scene._atmosphere
	air.strength = strength
	air._air_strength = strength
	air.swell = 0.0
	air.direction_angle = degrees
	air._air_angle = deg_to_rad(degrees)

## Frames until no cloud is out and the view has settled.
func wait_quiet(frames: Array, limit := 12.0) -> void:
	var previous := Time.get_ticks_usec()
	var began := previous
	var quiet := 0
	while quiet < 10 and (Time.get_ticks_usec()-began)/1000000.0 < limit:
		await process_frame
		var now := Time.get_ticks_usec()
		frames.append((now-previous)/1000.0)
		previous = now
		var busy: bool = (editor.handful != null and editor.handful.active()) or editor.refresh_pending > 0 or editor.water_settling or not editor._pour.is_empty() \
			or (editor.ball != null and editor.ball.state != "idle") or editor.land_settling or editor.mountain.active
		quiet = 0 if busy else quiet+1

func ids() -> Dictionary:
	var known := {}
	for item: Dictionary in editor.data.objects: known[int(item.id)] = true
	return known

static func to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b-a
	var t := clampf((p-a).dot(ab)/maxf(ab.length_squared(),1e-6),0.0,1.0)
	return p.distance_to(a+ab*t)

## One release: press at `at`, hold `seconds`, release; let it settle and grow.
func release(label: String, at: Vector2, seconds: float, wind: Array, gust := false) -> Dictionary:
	set_wind(wind[0],wind[1])
	var data := editor.data
	# Growth still coming from earlier work would be counted as this cloud's.
	var waited := Time.get_ticks_usec()
	while editor.emergence.busy() and (Time.get_ticks_usec()-waited)/1000000.0 < 40.0: await process_frame
	var wish: PackedFloat32Array = editor.emergence.intent.forest.duplicate()
	var tint := data.tint.duplicate()
	var known := ids()
	var objects := data.objects.size()
	var steps: int = data._undo.size()
	var outcomes_before: Dictionary = editor.emergence.sown_outcomes.duplicate(true)
	var point := screen_of(at)
	editor.pointer_override = point
	# Aiming first: the footprint shows before the press.
	for _frame in range(4): await process_frame
	var aiming: bool = editor.handful != null and editor.handful._prints[0].visible
	mouse(point,true)
	var h = editor.handful
	var gathering: bool = editor._handful_holding
	var hold_frames := []
	var hold_step := []
	var previous := Time.get_ticks_usec()
	var held := 0.0
	while held < seconds:
		await process_frame
		var now := Time.get_ticks_usec()
		hold_frames.append((now-previous)/1000.0)
		hold_step.append(h.last_usec/1000.0)
		held += (now-previous)/1000000.0
		previous = now
	var motes: int = h.held.motes.size()
	var flow: Vector2 = Wind.at(scene,editor.terrain,Vector2(h.held.centre.x,h.held.centre.z))
	var release_began := Time.get_ticks_usec()
	mouse(point,false)
	var release_ms := (Time.get_ticks_usec()-release_began)/1000.0
	editor.pointer_override = null
	_settled = {}
	var catch := func(cloud: Dictionary) -> void: _settled = cloud
	h.settled.connect(catch)
	var fall_frames := []
	var fall_step := []
	previous = Time.get_ticks_usec()
	var began := previous
	var gusted := false
	while _settled.is_empty() and (Time.get_ticks_usec()-began)/1000000.0 < 10.0:
		await process_frame
		# A gust through the falling cloud, a second after release.
		if gust and not gusted and (Time.get_ticks_usec()-began)/1000000.0 > 1.0:
			gusted = true
			scene._atmosphere.send_gust(editor.terrain.to_global(Vector3(at.x,0.0,at.y)),0.8)
		var now := Time.get_ticks_usec()
		fall_frames.append((now-previous)/1000.0)
		fall_step.append(h.last_usec/1000.0)
		previous = now
	h.settled.disconnect(catch)
	var settled := _settled
	var fell_s := (Time.get_ticks_usec()-began)/1000000.0
	var sown: float = Emergence.time
	await wait_quiet(fall_frames)
	var points: PackedVector2Array = settled.get("points",PackedVector2Array())
	var seeds: PackedVector2Array = settled.get("seeds",PackedVector2Array())
	var promised: Array = settled.get("promised",[at,at])
	var a: Vector2 = promised[0]
	var b: Vector2 = promised[1]
	var radius: float = settled.get("radius",1.0)
	var outside: int = settled.get("outside",0)
	var worst: float = settled.get("worst",0.0)
	var promised_worst := 0.0
	var middle := Vector2.ZERO
	for p in points:
		promised_worst = maxf(promised_worst,to_segment(p,a,b)/radius)
		middle += p
	if not points.is_empty(): middle /= points.size()
	var downwind := flow.normalized() if flow.length() > 0.001 else Vector2.ZERO
	# The land decides: what grew, where, and what became of the seeds.
	var grow_frames := []
	previous = Time.get_ticks_usec()
	began = previous
	while (Time.get_ticks_usec()-began)/1000000.0 < grow:
		await process_frame
		var now := Time.get_ticks_usec()
		grow_frames.append((now-previous)/1000.0)
		previous = now
		if not editor.emergence.busy() and (now-began)/1000000.0 > 3.0: break
	var trees := 0
	var shrubs := 0
	var on_seed := 0
	var first_on_seed := INF
	var others := []
	var kinds := {}
	var habitats := {}
	var blend: RefCounted = editor.emergence._blend
	for item: Dictionary in data.objects:
		if NativeTerrainData.object_source(item) != "emerged" or known.has(int(item.id)): continue
		if not item.asset in Emergence.TREES and not item.asset in ["snag","log","stump"]:
			shrubs += 1
			continue
		trees += 1
		kinds[item.asset] = kinds.get(item.asset,0)+1
		var p := Vector2(item.x,item.z)
		if blend != null:
			var habitat: String = blend.pick(p)
			habitats[habitat] = habitats.get(habitat,0)+1
		var after := float(item.get("born",sown))-sown
		# A spruce may sit a few centimetres off its seed (Emergence `_dead_top`).
		if Emergence._nearest(seeds,p) < 0.05:
			on_seed += 1
			first_on_seed = minf(first_on_seed,after)
		else: others.append(after)
	var outcomes := {}
	for habitat: String in editor.emergence.sown_outcomes:
		var now_by: Dictionary = editor.emergence.sown_outcomes[habitat]
		var was: Dictionary = outcomes_before.get(habitat,{})
		for outcome: String in now_by:
			var more := int(now_by[outcome])-int(was.get(outcome,0))
			if more > 0: outcomes.get_or_add(habitat,{})[outcome] = more
	var report := {"release":label,"at":[at.x,at.y],"held_s":snappedf(held,0.01),"wind_set":wind,"drift_m_s":[snappedf(flow.x,0.01),snappedf(flow.y,0.01)],"aim_footprint_shown":aiming,"gathering":gathering,
		"motes":motes,"landed":points.size(),"lost":settled.get("lost",0),"seeds":seeds.size(),"fell_s":snappedf(fell_s,0.01),
		"footprint":{"a":[snappedf(a.x,0.01),snappedf(a.y,0.01)],"b":[snappedf(b.x,0.01),snappedf(b.y,0.01)],"radius":snappedf(radius,0.01),"length":snappedf(a.distance_to(b),0.01)},
		"outside":outside,"worst_share":snappedf(worst,0.01),"outside_release_footprint":settled.get("outside_promised",0),"worst_share_release_footprint":snappedf(promised_worst,0.01),
		"drift_m":snappedf(Vector2(settled.get("drift",Vector2.ZERO)).length(),0.01),"settled_centre_from_pointer_m":snappedf(middle.distance_to(at),0.01),"settled_downwind_m":snappedf((middle-at).dot(downwind),0.01),
		"undo_steps_added":data._undo.size()-steps,
		"grown":{"trees":trees,"shrubs":shrubs,"kinds":kinds,"tree_habitats":habitats,"on_seeds":on_seed,"first_on_seed_s":snappedf(first_on_seed,0.1) if first_on_seed < INF else null,"others_after_s":stats(others),"seed_outcomes":outcomes},
		"release_ms":snappedf(release_ms,0.01),"hold_frames_ms":stats(hold_frames),"hold_step_ms":stats(hold_step),"fall_frames_ms":stats(fall_frames),"fall_step_ms":stats(fall_step),"grow_frames_ms":stats(grow_frames)}
	check(gathering,label+": press gathered a cloud")
	check(outside == 0,label+": every mote settled inside the footprint")
	check(points.size()+int(settled.get("lost",0)) == motes,label+": every mote came down")
	check(data._undo.size()-steps == 1,label+": one undo step")
	editor.undo()
	await wait_quiet([])
	var restored := {"wish":editor.emergence.intent.forest == wish,"tint":data.tint == tint,"objects":data.objects.size() == objects,"sprouts_left":h._sprouts.size()}
	report["undo_restores"] = restored
	check(restored.wish and restored.tint and restored.objects,label+": undo restores")
	return report

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--grow="): grow = float(arg.trim_prefix("--grow="))
	create_timer(900).timeout.connect(func() -> void: push_error("Pollen probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-pollen-probe-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready: await process_frame
	while true:
		while scene.places.busy or scene._chunk_editor.forming: await process_frame
		await create_timer(1.0).timeout
		if not scene.places.busy and not scene._chunk_editor.forming: break
	scene.set_building(true)
	editor = scene._chunk_editor
	scene.set_process_input(false)
	scene.set_process_unhandled_input(false)
	editor.select_tool("land")
	editor.select_brush("forest")
	print("pollen ",editor.seed_handful," brush ",editor.held_brush())
	await create_timer(1.0).timeout
	for spec: Array in [["still puff",Vector2(-4.0,2.0),0.05,[0.0,0.0]],["still full",Vector2(0.5,1.0),1.5,[0.0,0.0]],
			["wind puff",Vector2(-6.0,-4.0),0.05,[0.8,0.0]],["wind full",Vector2(-6.0,4.0),1.5,[0.8,0.0]],["gust mid-fall",Vector2(-7.0,0.0),0.05,[0.4,0.0],true]]:
		var report := await release(spec[0],spec[1],spec[2],spec[3],spec.size() > 4)
		print("RELEASE ",JSON.stringify(report))
	# Mixed ground: a peak, then a pond dropped at its foot, then a full cloud
	# over the flank, the foot and the pond's edge.
	var data := editor.data
	var peak_at := Vector2(2.0,-3.0)
	editor.select_brush("land")
	editor.select_land_form("alpine")
	editor._mountain_press(Vector3(peak_at.x,float(data.sample(peak_at,data.heights)),peak_at.y))
	editor.mountain.aim(data,peak_at+Vector2(1.0,0.4)*2.5)
	editor.finish_stroke()
	await wait_quiet([])
	var pond_at := Vector2(-5.0,-2.0)
	editor.select_brush("water")
	var point := screen_of(pond_at)
	editor.pointer_override = point
	mouse(point,true)
	for _frame in range(240): await process_frame
	mouse(point,false)
	editor.pointer_override = null
	await wait_quiet([],30.0)
	var top := peak_at
	var best := -INF
	for x in range(-12,13):
		for z in range(-12,13):
			var p := peak_at+Vector2(x,z)*0.25
			var height := float(data.sample(p,data.heights))
			if height > best:
				best = height
				top = p
	print("GROUND ",JSON.stringify({"peak":[snappedf(top.x,0.01),snappedf(top.y,0.01),snappedf(best,0.01)],"ponds":data.ponds.size()}))
	editor.select_brush("forest")
	for spec: Array in [["peak top",top,1.5,[0.0,0.0]],["flank to pond",top.lerp(pond_at,0.55),1.5,[0.5,180.0]]]:
		var report := await release(spec[0],spec[1],spec[2],spec[3])
		print("RELEASE ",JSON.stringify(report))
	set_wind(0.0,0.0)
	# An undo with a cloud still in the air settles it and takes it back.
	var wish: PackedFloat32Array = editor.emergence.intent.forest.duplicate()
	var tint := data.tint.duplicate()
	var steps: int = data._undo.size()
	point = screen_of(Vector2(-2.0,-6.0))
	editor.pointer_override = point
	mouse(point,true)
	for _frame in range(20): await process_frame
	mouse(point,false)
	editor.pointer_override = null
	for _frame in range(60): await process_frame
	var in_air: int = editor.handful.motes_in_air()
	editor.undo()
	await wait_quiet([])
	var midair := {"motes_in_air_at_undo":in_air,"active":editor.handful.active(),"wish":editor.emergence.intent.forest == wish,"tint":data.tint == tint,"undo_steps":data._undo.size()-steps}
	print("MIDAIR ",JSON.stringify(midair))
	check(in_air > 0 and midair.wish and midair.tint and midair.undo_steps == 0 and not midair.active,"undo in the air restores")
	# Shift still clears by painting: no cloud.
	Input.parse_input_event(_shift(true))
	point = screen_of(Vector2(0.0,0.0))
	editor.pointer_override = point
	mouse(point,true)
	var shift := {"cloud":editor._handful_holding,"painting":editor._painting}
	mouse(point,false)
	Input.parse_input_event(_shift(false))
	editor.pointer_override = null
	await wait_quiet([])
	print("SHIFT ",JSON.stringify(shift))
	check(not shift.cloud and shift.painting,"Shift paints a clearing")
	# With pollen off (--paint-forest) a press paints as before.
	editor.seed_handful = false
	point = screen_of(Vector2(-2.0,-1.0))
	editor.pointer_override = point
	mouse(point,true)
	var painted := {"cloud":editor._handful_holding,"painting":editor._painting}
	for _frame in range(10): await process_frame
	mouse(point,false)
	editor.pointer_override = null
	await wait_quiet([])
	editor.seed_handful = true
	print("PAINT ",JSON.stringify(painted))
	check(not painted.cloud and painted.painting,"--paint-forest paints")
	print("failures=",failures)
	scene.queue_free()
	for _frame in range(3): await process_frame
	quit(1 if failures > 0 else 0)

func _shift(pressed: bool) -> InputEventKey:
	var key := InputEventKey.new()
	key.keycode = KEY_SHIFT
	key.physical_keycode = KEY_SHIFT
	key.pressed = pressed
	return key
