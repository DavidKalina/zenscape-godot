extends SceneTree
## Headless probe of the edge (docs/scenic/modeless.md, "The agreed scheme",
## scripts/edge_spring.gd and the toss in scripts/diorama_flip.gd): the real
## product scene, `--modeless`, synthesized mouse input at a fixed 60 Hz.
## - pull the rim down (lip, and a wall from a low camera): the whole block
##   dips as a unit (the flip's snapshot), no terrain is touched while held,
##   nothing turns or flips; let go and a random range springs up, one undo
##   step, restored exactly by one undo, also when undone mid-spring;
## - a gentle pull gives lower, smoother hills than a hard one (same seed);
## - springs stack under the ceiling, and a second range with the same seed
##   moves away from the first's tall ground;
## - a tiny pull keeps nothing;
## - pull up and let go slowly: the block settles and a basin sinks;
## - a small flick tosses the block, which falls back and wobbles, and makes
##   no basin and no new world;
## - catching it in the air and flicking again pumps it over (a new world);
## - one hard flick goes over;
## - Shift and a fast sideways push turns without winding time.
## Nothing is rendered: how any of it looks or feels is not checked.
##   perl -e 'alarm 400; exec @ARGV' Godot --headless --fixed-fps 60 --path . \
##     -s res://tools/probe_edge_spring.gd -- --modeless
var scene: Node3D
var editor: NativeChunkEditor
var reach: Node
var spring: Node
var flip: Node
var rig: Node
var failures := []
var sprung := []
var flips := 0
var set_downs := []

func _initialize() -> void: run.call_deferred()

func check(label: String, ok: bool, detail: Variant = "") -> void:
	if not ok: failures.append(label)
	print(("OK   " if ok else "FAIL ")+label+("" if str(detail).is_empty() else "  "+str(detail)))

func button(at: Vector2, pressed: bool, shift := false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.global_position = at
	event.pressed = pressed
	event.shift_pressed = shift
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	root.push_input(event)

func motion(at: Vector2, relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(event)

func frames(count: int) -> void:
	for i in range(count): await process_frame

## Move by `step` a frame, `count` frames, from `from`; returns where it ended.
func move(from: Vector2, step: Vector2, count: int) -> Vector2:
	var at := from
	for i in range(count):
		at += step
		motion(at,step)
		await frames(1)
	return at

func settled() -> void:
	var quiet := 0
	var n := 0
	while quiet < 20 and n < 3000:
		await process_frame
		n += 1
		var busy: bool = editor.mountain.active or editor.land_settling or editor.refresh_pending > 0 or spring.state != 0 or spring.waiting or flip.active() or scene.places.busy
		quiet = 0 if busy else quiet+1

## The highest rise over `base` and where.
func rise(base: PackedFloat32Array) -> Array:
	var heights := editor.data.heights
	var best := 0.0
	var at := Vector2.ZERO
	for i in range(heights.size()):
		var up := heights[i]-base[i]
		if up > best:
			best = up
			at = editor.data.points[i]
	return [best,at]

## The deepest sink under `base`.
func sink(base: PackedFloat32Array) -> float:
	var heights := editor.data.heights
	var deepest := 0.0
	for i in range(heights.size()): deepest = maxf(deepest,base[i]-heights[i])
	return deepest

## The range's lift as built (before it springs): its highest, and its
## roughness, the mean absolute second difference on a 0.3 m grid over its
## bounds, per metre of its highest.
func lift_shape() -> Array:
	var mountain: RefCounted = editor.mountain
	var lift: PackedFloat32Array = mountain._lift
	var data := editor.data
	var top := 0.0
	for v in lift: top = maxf(top,v)
	var box: Rect2 = mountain.bounds
	var total := 0.0
	var count := 0
	var step := 0.3
	var x := box.position.x+step
	while x < box.end.x-step:
		var z := box.position.y+step
		while z < box.end.y-step:
			var c: Variant = data.sample(Vector2(x,z),lift)
			var e: Variant = data.sample(Vector2(x+step,z),lift)
			var w: Variant = data.sample(Vector2(x-step,z),lift)
			var n: Variant = data.sample(Vector2(x,z+step),lift)
			var s: Variant = data.sample(Vector2(x,z-step),lift)
			if c != null and e != null and w != null and n != null and s != null and float(c) > 0.2:
				total += absf(float(e)+float(w)+float(n)+float(s)-4.0*float(c))
				count += 1
			z += step
		x += step
	return [top,(total/maxf(count,1))/maxf(top,0.01)]

## A lip point on screen: the land just inside the rim on the nearest side,
## with room below it for a pull and above it for a lift.
func lip_point() -> Vector2:
	var terrain: Node3D = editor.terrain
	var best := Vector2.ZERO
	for side in range(4):
		for i in range(7):
			var f := -6.0+12.0*i/6.0
			var edge: Vector2 = [Vector2(f,-13.7),Vector2(13.7,f),Vector2(f,13.7),Vector2(-13.7,f)][side]
			var top := float(editor.data.ground_height(edge))
			var world := terrain.to_global(Vector3(edge.x,top,edge.y))
			if scene.camera.is_position_behind(world): continue
			var at: Vector2 = scene.camera.unproject_position(world)
			if reach.reach_at(at) != "rim": continue
			if at.y > best.y and at.y < root.size.y-300 and at.y > 330: best = at
	return best

## Press the rim at `from`, pull down `pixels` over `count` frames, hold 10
## frames. Returns what the pull showed.
func pull_down(from: Vector2, pixels: float, count: int) -> Dictionary:
	var base := editor.data.heights.duplicate()
	var terrain_before: Transform3D = editor.terrain.global_transform
	button(from,true)
	await frames(1)
	var at := await move(from,Vector2(0.0,pixels/count),count)
	await frames(10)
	var hand: Node = scene.get("god_hand")
	var edge_drop := 0.0
	if flip.pivot != null:
		var grabbed: Vector3 = flip._centre+flip._grab_dir*flip._half
		edge_drop = grabbed.y-(flip.pivot.transform*grabbed).y
	return {"end":at,"intent":reach.rim_intent,"phase":flip.phase,"dip":flip.dip,"snapshot":flip.pivot != null,
		"drop":terrain_before.origin.y-editor.terrain.global_transform.origin.y,"edge_drop":edge_drop,
		"touched":editor.data.heights != base,"pulled":spring.pulled,"gesture":hand.reach_gesture if hand != null else "-"}

## One full edge spring from `from` with `pixels` of pull; checks under
## `label`. Returns [rise, roughness, lift top] and leaves the range undone
## unless `keep`.
func edge_spring(label: String, from: Vector2, pixels: float, keep := false, seed := -1) -> Array:
	var data := editor.data
	var before := data.heights.duplicate()
	var undo0: int = data._undo.size()
	var yaw0: float = scene.yaw
	flips = 0
	sprung.clear()
	var what: String = reach.reach_at(from)
	check("%s: the press is on the rim" % label,what == "rim",what)
	spring.next_seed = seed
	var held := await pull_down(from,pixels,24)
	print("%s: pull %.2f, dip %.2f, block down %.2f m, grabbed edge down %.2f m" % [label,held.pulled,held.dip,held.drop,held.edge_drop])
	check("%s: a downward rim drag decides the spring" % label,held.intent == "spring" and spring.state == 1,[held.intent,spring.state])
	check("%s: the whole block dips as a unit (snapshot, terrain moved down, grabbed edge lower)" % label,held.snapshot and held.phase == flip.Phase.DIP and held.drop > 0.2 and held.edge_drop > held.drop,held)
	check("%s: no terrain is touched while held" % label,not held.touched)
	check("%s: it does not flip or turn" % label,flips == 0 and absf(angle_difference(yaw0,scene.yaw)) < 0.001,[flips,scene.yaw-yaw0])
	check("%s: the hand grips the rim" % label,held.gesture == "flip" or scene.get("god_hand") == null,held.gesture)
	button(held.end,false)
	await frames(1)
	var shape := lift_shape()
	var n := 0
	while flip.active() and n < 60:
		await frames(1)
		n += 1
	check("%s: let go, the block is back up within a few frames and the range springs" % label,not flip.active() and n < 15 and spring.state == 2 and flip.pivot == null,[n,spring.state])
	await settled()
	var up: Array = rise(before)
	var range: Dictionary = spring.last_range
	print("%s: highest rise %.2f m at %s; range %s peaks, length %.1f m, direction %s, middle %s, jag %.2f, built top %.2f m, roughness %.3f, built in %.1f ms" % [label,up[0],up[1],range.peaks.size(),range.length,range.direction,range.centre,range.jag,shape[0],shape[1],range.build_ms])
	check("%s: land rises" % label,float(up[0]) > 0.8,up[0])
	check("%s: several peaks" % label,range.peaks.size() >= 2,range.peaks.size())
	var mid: Vector2 = range.centre
	check("%s: the range stands off the rim" % label,maxf(absf(mid.x),absf(mid.y)) <= spring.RANGE_ROOM+0.01,mid)
	check("%s: sprung, one undo step" % label,sprung.size() == 1 and sprung[0][0] == "mountain" and data._undo.size() == undo0+1,[sprung,data._undo.size()-undo0])
	if not keep:
		editor.undo()
		await settled()
		check("%s: one undo restores the heights exactly" % label,data.heights == before)
	return [up[0],shape[1],shape[0]]

func run() -> void:
	create_timer(380).timeout.connect(func() -> void: push_error("Edge probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-edge-spring-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	editor = scene._chunk_editor
	reach = scene.hand_reach
	spring = scene.get("edge_spring")
	flip = scene.get("flip")
	rig = scene.camera_rig
	check("run with --modeless: the edge spring and the flip are built",reach.modeless and spring != null and flip != null)
	if spring == null or flip == null:
		quit(1)
		return
	scene.world_clock.running = false
	reach.flip_began.connect(func(_p: Vector2) -> void: flips += 1)
	spring.sprung.connect(func(kind: String, size: float) -> void: sprung.append([kind,size]))
	flip.set_down.connect(func(p: float) -> void: set_downs.append(p))
	scene._overview()
	await frames(60)
	await settled()
	var data := editor.data

	# --- Pull down from the lip -------------------------------------------------------
	var lip := lip_point()
	check("a lip point is found on screen",lip != Vector2.ZERO,lip)
	await edge_spring("lip",lip,192.0,false,11)

	# --- Gentle and hard, same seed ---------------------------------------------------
	var gentle := await edge_spring("gentle",lip_point(),70.0,false,5)
	var hard := await edge_spring("hard",lip_point(),288.0,false,5)
	check("a hard pull raises higher than a gentle one",hard[0] > gentle[0]+2.0,[gentle[0],hard[0]])
	check("and more jagged (roughness per metre of height)",hard[1] > gentle[1]*1.3,[gentle[1],hard[1]])

	# --- Stacking under the ceiling ----------------------------------------------------
	var before_stack := data.heights.duplicate()
	var undo0: int = data._undo.size()
	var centres := []
	for k in range(3):
		await edge_spring("stack %d" % k,lip_point(),288.0,true,77)
		centres.append(spring.last_range.centre)
	var tallest := -INF
	for h in data.heights: tallest = maxf(tallest,h)
	print("stack: middles %s, tallest ground %.2f m (ceiling %.1f)" % [centres,tallest,spring.CEILING])
	check("the same seed on tall ground places the next range elsewhere",centres[1].distance_to(centres[0]) > 2.0 and centres[2].distance_to(centres[0]) > 2.0,centres)
	check("springs stack under the ceiling",tallest <= spring.CEILING+0.05,tallest)
	for k in range(3): editor.undo()
	await settled()
	check("three undos take the three ranges back exactly",data.heights == before_stack and data._undo.size() == undo0)

	# --- Undo mid-spring ---------------------------------------------------------------
	var before := data.heights.duplicate()
	var held := await pull_down(lip_point(),200.0,20)
	button(held.end,false)
	for i in range(30):
		await frames(1)
		if spring.state == 2 and spring.spring_x > 0.3: break
	check("mid-spring (x %.2f)" % spring.spring_x,spring.state == 2)
	editor.undo()
	await settled()
	check("an undo mid-spring lands it and takes it back exactly",data.heights == before)

	# --- A tiny pull keeps nothing ------------------------------------------------------
	before = data.heights.duplicate()
	undo0 = data._undo.size()
	sprung.clear()
	var tiny := await pull_down(lip_point(),16.0,2)
	check("a tiny pull still decides the spring",tiny.intent == "spring",tiny.intent)
	button(tiny.end,false)
	await settled()
	check("a tiny pull raises nothing and adds no undo step",data.heights == before and sprung.is_empty() and data._undo.size() == undo0,sprung)

	# --- From the wall, low and close ----------------------------------------------------
	rig.glide_to(Vector3(0,-1.0,8.0),0.0,1.42,16.0)
	await frames(150)
	var wall: Vector2 = scene.camera.unproject_position(editor.terrain.to_global(Vector3(2.0,-1.6,14.0)))
	print("wall point on screen ",wall)
	await edge_spring("wall",wall,192.0,false,31)
	scene._overview()
	await frames(120)
	await settled()

	# --- Pull up and set down slowly: a basin ------------------------------------------
	before = data.heights.duplicate()
	undo0 = data._undo.size()
	var seed0: int = editor.land_seed
	set_downs.clear()
	var lip2 := lip_point()
	spring.next_seed = 21
	button(lip2,true)
	await frames(1)
	var p := await move(lip2,Vector2(0.0,-4.0),40)
	check("an upward rim drag lifts the block (the flip holds it)",reach.rim_intent == "flip" and flip.phase == flip.Phase.HELD and flip.angle > 0.2,[reach.rim_intent,flip.phase,flip.angle])
	await frames(12)
	button(p,false)
	await settled()
	var deep := sink(before)
	print("basin: set down from %s, %s, sank %.2f m" % [set_downs,spring.last_basin,deep])
	check("a slow let-go settles the block and a basin sinks",set_downs.size() == 1 and deep > 0.25 and editor.land_seed == seed0,[set_downs,deep])
	var bc: Vector2 = spring.last_basin.get("centre",Vector2.ZERO)
	check("the basin stands off the rim",maxf(absf(bc.x),absf(bc.y))+float(spring.last_basin.get("radius",0.0)) <= spring.ROOM+0.01,spring.last_basin)
	check("one undo step for the basin",data._undo.size() == undo0+1)
	editor.undo()
	await settled()
	check("one undo restores it exactly",data.heights == before)

	# --- A small flick: tossed, falls back, wobbles -------------------------------------
	before = data.heights.duplicate()
	set_downs.clear()
	seed0 = editor.land_seed
	lip2 = lip_point()
	var fell := [0]
	flip.fell_back.connect(func() -> void: fell[0] += 1)
	button(lip2,true)
	await frames(1)
	p = await move(lip2,Vector2(0.0,-16.0),8)
	var at_release: float = flip.angle
	button(p,false)
	await frames(1)
	var tossed: bool = flip.phase == flip.Phase.TOSS
	var bounces := 0
	var was: float = flip.angle
	var n := 0
	while flip.active() and n < 600:
		await frames(1)
		if flip.angle <= 0.0 and was > 0.0: bounces += 1
		was = flip.angle
		n += 1
	print("small toss: released at %.2f rad, peak %.2f rad, %d frames, %d landings" % [at_release,flip.toss_peak,n,bounces])
	check("a small flick tosses the block",tossed and flip.tosses == 1)
	check("it rises under the upright and falls back",flip.toss_peak > at_release and flip.toss_peak < flip.TIP_ANGLE and fell[0] == 1,flip.toss_peak)
	check("and wobbles (lands more than once)",bounces >= 2,bounces)
	check("no basin, no new world",set_downs.is_empty() and data.heights == before and editor.land_seed == seed0)
	var single_peak: float = flip.toss_peak
	await settled()

	# --- Pump: catch it on the way down and flick again ---------------------------------
	var landed := [-1]
	flip.landed.connect(func(s: int) -> void: landed[0] = s)
	lip2 = lip_point()
	button(lip2,true)
	await frames(1)
	p = await move(lip2,Vector2(0.0,-16.0),8)
	button(p,false)
	# Wait for the top, then for it to come down a little.
	n = 0
	while n < 200 and not (flip.phase == flip.Phase.TOSS and flip.omega < -0.5):
		await frames(1)
		n += 1
	var caught_at: float = flip.angle
	var catch_screen: Vector2 = scene.camera.unproject_position(editor.terrain.to_global(Vector3(flip._grab_dir.x,0.0,flip._grab_dir.z)*(flip._half-1.0)))
	button(catch_screen,true)
	await frames(1)
	check("a press catches the block in the air",flip.phase == flip.Phase.HELD and reach.holding == "rim" and reach.rim_intent == "flip",[flip.phase,reach.holding,reach.rim_intent])
	p = await move(catch_screen,Vector2(0.0,-16.0),6)
	button(p,false)
	n = 0
	var peak := 0.0
	while (flip.active() or scene.places.busy) and n < 2400:
		await frames(1)
		peak = maxf(peak,flip.angle)
		n += 1
	print("pump: caught at %.2f rad, tosses %d, went to %.2f rad, landed %d" % [caught_at,flip.tosses,peak,landed[0]])
	check("the same flick again from the air adds up and goes over",flip.tosses == 2 and peak >= PI-0.01 and landed[0] >= 0,[flip.tosses,peak,landed[0]])
	check("where the first alone fell back",single_peak < flip.TIP_ANGLE)
	await settled()

	# --- One hard flick goes over ---------------------------------------------------------
	scene._overview()
	await frames(90)
	await settled()
	landed[0] = -1
	lip2 = lip_point()
	button(lip2,true)
	await frames(1)
	p = await move(lip2,Vector2(0.0,-40.0),5)
	button(p,false)
	await frames(1)
	var hard_tossed: bool = flip.phase == flip.Phase.TOSS or flip.going_over()
	n = 0
	while (flip.active() or scene.places.busy) and n < 2400:
		await frames(1)
		n += 1
	check("one hard flick tosses it over",hard_tossed and flip.tosses == 1 and landed[0] >= 0 and editor.land_seed == landed[0],[flip.tosses,landed[0]])
	await settled()

	# --- Shift and a fast push: no time ---------------------------------------------------
	scene._overview()
	await frames(90)
	var clock: WorldClock = scene.world_clock
	var hours0 := float(clock.day)*24.0+clock.hour
	lip2 = lip_point()
	button(lip2,true,true)
	await frames(1)
	var fastest := 0.0
	p = lip2
	for i in range(10):
		p += Vector2(36.0,0.0)
		motion(p,Vector2(36.0,0.0))
		await frames(1)
		fastest = maxf(fastest,absf(rig.turn.own_rate))
	button(p,false)
	for i in range(90):
		await frames(1)
		fastest = maxf(fastest,absf(rig.turn.own_rate))
	var hours1 := float(clock.day)*24.0+clock.hour
	var time_min: float = preload("res://scripts/spin_time.gd").TIME_MIN
	print("shift turn: fastest %.2f rad/s (time winds from %.1f), hours %.3f" % [fastest,time_min,hours1-hours0])
	check("Shift and a fast push turns fast",rig.turn.timeless and fastest > time_min,fastest)
	check("and winds no time",absf(hours1-hours0) < 0.0001,hours1-hours0)
	rig.turn.stop()

	await flip.wait_idle()
	await settled()
	print("FAILURES: ",failures)
	quit(1 if not failures.is_empty() else 0)
