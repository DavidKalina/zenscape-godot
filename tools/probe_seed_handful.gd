extends SceneTree
## Headless probe of pollen (scripts/pollen_cloud.gd, docs/scenic/brushes.md
## "Pollen") on the Genesis plain, through the real input path: a mouse press
## with forest in hand, the pointer swept along a path (pointer_override) while
## the editor's own _process lays the veil, then a release. The wind is set on
## the scene's atmosphere.
##
## Each release reports the veil (knots, motes, length swept), the wind it went
## on, every landing against the footprint as it stood when the mote landed
## (all must be inside) and against the footprint shown at release, what grew
## compared with the swept path (trees near the path, shifted by the veil's
## drift, and how much of the path has a tree near it), why seeds took or not
## by habitat (Emergence `sown_outcomes`), frame gaps and the veil's own step
## while laid and falling, the undo steps added, and whether one undo restores
## the wish, the floor tint and the objects.
##
## The flicker check: every frame from the aim to the end of growth it counts
## the visible instances of every MultiMesh in the scene, and fails any node
## whose count jumps by FLICKER or more and drops back within a few frames (a
## frame drawing plants that are not there; the source chunk's forest showed
## for a frame when a veil settled, before the refresh fix).
##
## Releases: a click puff, a hold-still thicken, a straight sweep, a loop, a
## sweep in steady wind, a sweep with a gust mid-fall, a long zigzag (the mote
## cap), and full veils over mixed ground (a raised peak's top, and its flank
## down to a pond). Then an undo while a veil is in the air, a Shift press
## (clears by painting) and a press with pollen off (--paint-forest paints).
##   -- --grow=26 --only=straight  (releases whose label contains it, and no
##   mixed-ground or input checks)
## Frame gaps are CPU main-loop intervals under the dummy renderer, less the
## flicker count's own time.
const Wind = preload("res://scripts/pollen_wind.gd")
const Emergence = preload("res://scripts/emergence.gd")
const Pollen = preload("res://scripts/pollen_cloud.gd")
const FLICKER := 20
var scene: Node3D
var editor: NativeChunkEditor
var grow := 26.0
var only := ""
var failures := 0
var _settled := {}
## The flicker watch: per-frame counts by node, and the count's own time.
var _watching := false
var _counts: Array[Dictionary] = []
var _count_usec := 0

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

# --- The flicker watch ------------------------------------------------------------

func _count(node: Node, out: Dictionary) -> void:
	for child in node.get_children():
		if child is Node3D and not (child as Node3D).visible: continue
		if child is MultiMeshInstance3D and child.multimesh != null:
			var mm: MultiMesh = child.multimesh
			var key := String(scene.get_path_to(child))
			out[key] = int(out.get(key,0))+(mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count)
		_count(child,out)

## Counts what the last frame drew: at the start of the next frame, before
## any node or resumed coroutine has changed it. (The dummy renderer never
## emits frame_pre_draw.)
func _on_frame() -> void:
	if not _watching: return
	var began := Time.get_ticks_usec()
	var counts := {}
	_count(scene,counts)
	_counts.append(counts)
	_count_usec += Time.get_ticks_usec()-began

func watch() -> void:
	_counts.clear()
	_watching = true

## Nodes whose visible count jumped by FLICKER or more for a frame or three
## and dropped back: [{"node", "frame", "counts"}].
func flickers() -> Array:
	_watching = false
	var found := []
	var keys := {}
	for counts in _counts:
		for key in counts: keys[key] = true
	for key: String in keys:
		for i in range(1,_counts.size()-1):
			var was := int(_counts[i-1].get(key,0))
			var now := int(_counts[i].get(key,0))
			if now < was+FLICKER: continue
			for j in range(i+1,mini(i+4,_counts.size())):
				if int(_counts[j].get(key,0)) <= was+FLICKER/4:
					found.append({"node":key,"frame":i,"counts":[was,now,int(_counts[j].get(key,0))]})
					break
	return found

## The most instances visible in any frame, for the report.
func peak_instances() -> int:
	var best := 0
	for counts in _counts:
		var total := 0
		for key in counts: total += int(counts[key])
		best = maxi(best,total)
	return best

# ------------------------------------------------------------------------------

## Frames until no veil is out and the view has settled.
func wait_quiet(frames: Array, limit := 12.0) -> void:
	var previous := Time.get_ticks_usec()
	var began := previous
	var quiet := 0
	while quiet < 10 and (Time.get_ticks_usec()-began)/1000000.0 < limit:
		_count_usec = 0
		await process_frame
		var now := Time.get_ticks_usec()
		frames.append((now-previous-_count_usec)/1000.0)
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

static func to_path(p: Vector2, path: PackedVector2Array) -> float:
	if path.size() == 1: return p.distance_to(path[0])
	var best := INF
	for i in range(path.size()-1): best = minf(best,to_segment(p,path[i],path[i+1]))
	return best

## The point `share` of the way along polyline `path` (plate).
static func along(path: Array, share: float) -> Vector2:
	if path.size() == 1: return path[0]
	var total := 0.0
	for i in range(path.size()-1): total += Vector2(path[i]).distance_to(path[i+1])
	var want := clampf(share,0.0,1.0)*total
	for i in range(path.size()-1):
		var piece := Vector2(path[i]).distance_to(path[i+1])
		if want <= piece or i == path.size()-2: return Vector2(path[i]).lerp(path[i+1],clampf(want/maxf(piece,1e-6),0.0,1.0))
		want -= piece
	return path.back()

static func loop(centre: Vector2, radius: float, sides: int) -> Array:
	var out := []
	for i in range(sides+1): out.append(centre+Vector2.RIGHT.rotated(TAU*i/sides)*radius)
	return out

## One release: press at the path's start, sweep it over `seconds` (then hold
## `dwell` more), release; let it settle and grow. `swipe` sends a gust across
## the falling veil a second after release.
func release(label: String, path: Array, seconds: float, wind: Array, dwell := 0.0, swipe := false) -> Dictionary:
	set_wind(wind[0],wind[1])
	var data := editor.data
	# Growth still coming from earlier work would be counted as this veil's.
	var waited := Time.get_ticks_usec()
	while editor.emergence.busy() and (Time.get_ticks_usec()-waited)/1000000.0 < 40.0: await process_frame
	var wish: PackedFloat32Array = editor.emergence.intent.forest.duplicate()
	var tint := data.tint.duplicate()
	var known := ids()
	var objects := data.objects.size()
	var steps: int = data._undo.size()
	var outcomes_before: Dictionary = editor.emergence.sown_outcomes.duplicate(true)
	watch()
	var point := screen_of(path[0])
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
	var began := previous
	var landed_while_held := 0
	while true:
		var elapsed := (Time.get_ticks_usec()-began)/1000000.0
		if elapsed >= seconds+dwell: break
		point = screen_of(along(path,elapsed/maxf(seconds,0.001)))
		editor.pointer_override = point
		_count_usec = 0
		await process_frame
		var now := Time.get_ticks_usec()
		hold_frames.append((now-previous-_count_usec)/1000.0)
		hold_step.append(h.last_usec/1000.0)
		previous = now
		landed_while_held += h._glints.size()
	var held: Dictionary = h.held
	var motes: int = held.motes.size()
	var knots: int = held.knots.size()
	var cap: int = held.cap
	var thickest := 0.0
	for knot: Dictionary in held.knots: thickest = maxf(thickest,float(knot.thick))
	var flow: Vector2 = Wind.at(scene,editor.terrain,Vector2(held.head.x,held.head.z))
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
	began = previous
	var swiped := false
	var lift := 0.0
	var lift_frames := 0
	var middle_y0 := NAN
	while _settled.is_empty() and (Time.get_ticks_usec()-began)/1000000.0 < 12.0:
		_count_usec = 0
		await process_frame
		var elapsed := (Time.get_ticks_usec()-began)/1000000.0
		# The breath: how high the veil's middle rose before it sank.
		if not h.clouds.is_empty():
			var veil: Dictionary = h.clouds.back()
			var y := 0.0
			for mote: Dictionary in veil.motes: y += float(mote.p.y)
			y /= maxf(veil.motes.size(),1.0)
			if is_nan(middle_y0): middle_y0 = y
			if float(veil.t) < Pollen.LIFT+0.2:
				lift = maxf(lift,y-middle_y0)
				lift_frames += 1
		# A gust across the falling veil, a second after release.
		if swipe and not swiped and elapsed > 1.0:
			swiped = true
			await _swipe(path,flow)
		var now := Time.get_ticks_usec()
		fall_frames.append((now-previous-_count_usec)/1000.0)
		fall_step.append(h.last_usec/1000.0)
		previous = now
	h.settled.disconnect(catch)
	var settled := _settled
	var fell_s := (Time.get_ticks_usec()-began)/1000000.0
	var sown: float = Emergence.time
	await wait_quiet(fall_frames)
	var points: PackedVector2Array = settled.get("points",PackedVector2Array())
	var seeds: PackedVector2Array = settled.get("seeds",PackedVector2Array())
	var swept: PackedVector2Array = settled.get("path",PackedVector2Array())
	var promised: Array = settled.get("promised",[])
	var radius: float = settled.get("radius",1.0)
	var outside: int = settled.get("outside",0)
	var worst: float = settled.get("worst",0.0)
	var drift: Vector2 = settled.get("drift",Vector2.ZERO)
	var promised_worst := 0.0
	var middle := Vector2.ZERO
	for p in points:
		var share := INF
		for capsule: Array in promised: share = minf(share,to_segment(p,capsule[0],capsule[1])/float(capsule[2]))
		promised_worst = maxf(promised_worst,share)
		middle += p
	if not points.is_empty(): middle /= points.size()
	var path_middle := Vector2.ZERO
	for p in swept: path_middle += p
	if not swept.is_empty(): path_middle /= swept.size()
	var downwind := flow.normalized() if flow.length() > 0.001 else Vector2.ZERO
	# The land decides: what grew, where, and what became of the seeds.
	var grow_frames := []
	previous = Time.get_ticks_usec()
	began = previous
	while (Time.get_ticks_usec()-began)/1000000.0 < grow:
		_count_usec = 0
		await process_frame
		var now := Time.get_ticks_usec()
		grow_frames.append((now-previous-_count_usec)/1000.0)
		previous = now
		if not editor.emergence.busy() and (now-began)/1000000.0 > 3.0: break
	var flicker := flickers()
	var peak := peak_instances()
	var trees := 0
	var shrubs := 0
	var on_seed := 0
	var first_on_seed := INF
	var others := []
	var kinds := {}
	var habitats := {}
	var tree_points := PackedVector2Array()
	var blend: RefCounted = editor.emergence._blend
	for item: Dictionary in data.objects:
		if NativeTerrainData.object_source(item) != "emerged" or known.has(int(item.id)): continue
		if not item.asset in Emergence.TREES and not item.asset in ["snag","log","stump"]:
			shrubs += 1
			continue
		trees += 1
		kinds[item.asset] = kinds.get(item.asset,0)+1
		var p := Vector2(item.x,item.z)
		tree_points.append(p)
		if blend != null:
			var habitat: String = blend.pick(p)
			habitats[habitat] = habitats.get(habitat,0)+1
		var after := float(item.get("born",sown))-sown
		# A spruce may sit a few centimetres off its seed (Emergence `_dead_top`).
		if Emergence._nearest(seeds,p) < 0.05:
			on_seed += 1
			first_on_seed = minf(first_on_seed,after)
		else: others.append(after)
	# Trees against the swept path, shifted by the veil's drift: how many stand
	# within the footprint's reach of it, and how much of it has a tree near.
	var shifted := PackedVector2Array()
	for p in swept: shifted.append(p+drift)
	var reach := radius+1.6
	var near := 0
	var farthest := 0.0
	for p in tree_points:
		var d := to_path(p,shifted)
		farthest = maxf(farthest,d)
		if d <= reach: near += 1
	var samples := 0
	var covered := 0
	var length: float = settled.get("length",0.0)
	for i in range(maxi(1,ceili(length))+1):
		var q := along(Array(shifted),float(i)/maxf(ceilf(length),1.0))
		samples += 1
		for p in tree_points:
			if p.distance_to(q) <= 2.5:
				covered += 1
				break
	var outcomes := {}
	for habitat: String in editor.emergence.sown_outcomes:
		var now_by: Dictionary = editor.emergence.sown_outcomes[habitat]
		var was: Dictionary = outcomes_before.get(habitat,{})
		for outcome: String in now_by:
			var more := int(now_by[outcome])-int(was.get(outcome,0))
			if more > 0: outcomes.get_or_add(habitat,{})[outcome] = more
	var report := {"release":label,"held_s":snappedf(seconds+dwell,0.01),"wind_set":wind,"drift_m_s":[snappedf(flow.x,0.01),snappedf(flow.y,0.01)],"aim_footprint_shown":aiming,"gathering":gathering,
		"knots":knots,"swept_m":snappedf(length,0.01),"motes":motes,"cap":cap,"thickest":snappedf(thickest,0.01),"landed_while_held":landed_while_held,
		"lift_m":snappedf(lift,0.01),"landed":points.size(),"lost":settled.get("lost",0),"seeds":seeds.size(),"fell_s":snappedf(fell_s,0.01),
		"footprint":{"capsules":promised.size(),"radius":snappedf(radius,0.01)},
		"outside":outside,"worst_share":snappedf(worst,0.01),"outside_release_footprint":settled.get("outside_promised",0),"worst_share_release_footprint":snappedf(promised_worst,0.01),
		"drift_m":snappedf(drift.length(),0.01),"settled_centre_from_path_m":snappedf(middle.distance_to(path_middle),0.01),"settled_downwind_m":snappedf((middle-path_middle).dot(downwind),0.01),
		"undo_steps_added":data._undo.size()-steps,
		"grown":{"trees":trees,"shrubs":shrubs,"kinds":kinds,"tree_habitats":habitats,"on_seeds":on_seed,"first_on_seed_s":snappedf(first_on_seed,0.1) if first_on_seed < INF else null,"others_after_s":stats(others),"seed_outcomes":outcomes},
		"along_path":{"trees_within_reach":near,"reach_m":snappedf(reach,0.01),"farthest_m":snappedf(farthest,0.01),"path_covered":"%d of %d m" % [covered,samples]},
		"flicker":{"frames":_counts.size(),"spikes":flicker.slice(0,6),"peak_instances":peak},
		"release_ms":snappedf(release_ms,0.01),"hold_frames_ms":stats(hold_frames),"hold_step_ms":stats(hold_step),"fall_frames_ms":stats(fall_frames),"fall_step_ms":stats(fall_step),"grow_frames_ms":stats(grow_frames)}
	check(gathering,label+": press laid a veil")
	check(landed_while_held == 0,label+": nothing landed while held")
	check(motes <= cap,label+": motes within the cap")
	check(outside == 0,label+": every mote settled inside the footprint")
	check(points.size()+int(settled.get("lost",0)) == motes,label+": every mote came down")
	check(data._undo.size()-steps == 1,label+": one undo step")
	check(_counts.size() > 10,label+": the flicker watch saw the frames")
	check(flicker.is_empty(),label+": no frame drew instances that then vanished")
	check(lift > 0.05,label+": the veil took a breath before it sank")
	if trees > 0: check(near == trees,label+": every tree grew within reach of the swept path")
	editor.undo()
	await wait_quiet([])
	var restored := {"wish":editor.emergence.intent.forest == wish,"tint":data.tint == tint,"objects":data.objects.size() == objects,"sprouts_left":h._sprouts.size()}
	report["undo_restores"] = restored
	check(restored.wish and restored.tint and restored.objects,label+": undo restores")
	return report

## A gust swept across the falling veil: the wind tool's swipe when the editor
## has one, else a gust parcel from the atmosphere.
func _swipe(path: Array, _flow: Vector2) -> void:
	var at: Vector2 = along(path,0.5)
	scene._atmosphere.send_gust(editor.terrain.to_global(Vector3(at.x,0.0,at.y)),0.8)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--grow="): grow = float(arg.trim_prefix("--grow="))
		if arg.begins_with("--only="): only = arg.trim_prefix("--only=")
	create_timer(1500).timeout.connect(func() -> void: push_error("Pollen probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-pollen-probe-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	process_frame.connect(_on_frame)
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
	var zigzag := []
	for i in range(9): zigzag.append(Vector2(-9.0+i*2.2,-7.0 if i%2 == 0 else 7.0))
	var results := {}
	for spec: Array in [
			["click puff",[Vector2(-4.0,2.0)],0.03,[0.0,0.0]],
			["hold still",[Vector2(0.5,1.0)],0.0,[0.0,0.0],1.5],
			["straight sweep",[Vector2(-8.0,-6.0),Vector2(4.0,-6.0)],1.6,[0.0,0.0]],
			["loop",loop(Vector2(3.0,4.0),3.2,24),2.4,[0.0,0.0]],
			["sweep in wind",[Vector2(-9.0,-5.0),Vector2(-9.0,6.0)],1.4,[0.8,0.0]],
			["sweep, gust mid-fall",[Vector2(-8.0,-4.0),Vector2(-8.0,5.0)],1.2,[0.4,0.0],0.0,true],
			["long zigzag",zigzag,3.0,[0.0,0.0]]]:
		if not only.is_empty() and not only in spec[0]: continue
		var report := await release(spec[0],spec[1],spec[2],spec[3],spec[4] if spec.size() > 4 else 0.0,spec.size() > 5)
		results[spec[0]] = report
		print("RELEASE ",JSON.stringify(report))
	if not only.is_empty():
		print("failures=",failures)
		quit(1 if failures > 0 else 0)
		return
	# Shape: a sweep lays more than a click, a hold thickens, a long sweep
	# spreads its motes rather than growing past the cap.
	check(results["hold still"].motes > results["click puff"].motes and results["hold still"].thickest > 0.9,"holding still thickens")
	check(results["straight sweep"].swept_m > 9.0 and results["straight sweep"].knots > 15,"a sweep lays a veil along its way")
	check(results["long zigzag"].motes <= results["long zigzag"].cap,"a long sweep stays within its cap")
	check(results["sweep in wind"].settled_downwind_m > 1.0,"wind carries the veil downwind")
	# Mixed ground: a peak, then a pond dropped at its foot, then full veils
	# over the top and down the flank to the pond's edge.
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
	for spec: Array in [["peak top",[top],0.0,[0.0,0.0],1.5],["flank to pond",[top,top.lerp(pond_at,0.8)],1.4,[0.5,180.0]]]:
		var report := await release(spec[0],spec[1],spec[2],spec[3],spec[4] if spec.size() > 4 else 0.0)
		print("RELEASE ",JSON.stringify(report))
	set_wind(0.0,0.0)
	# An undo with a veil still in the air settles it and takes it back.
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
	# Shift still clears by painting: no veil.
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
	process_frame.disconnect(_on_frame)
	scene.queue_free()
	for _frame in range(3): await process_frame
	quit(1 if failures > 0 else 0)

func _shift(pressed: bool) -> InputEventKey:
	var key := InputEventKey.new()
	key.keycode = KEY_SHIFT
	key.physical_keycode = KEY_SHIFT
	key.pressed = pressed
	return key
