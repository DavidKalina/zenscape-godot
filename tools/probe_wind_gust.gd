extends SceneTree
## Headless probe of the wind tool's gust (scripts/wind_gust.gd,
## docs/scenic/wind-gust.md) on the Genesis plain, through the real input
## path: a mouse press with wind in hand, the editor's own _process following
## the pointer (pointer_override) while the hand drags, then a release.
##
## Gestures: "fast" (6 m in 0.15 s, against the breeze), "slow" (4 m in
## 1.2 s, across it), "burst" (a still press held 0.8 s), "nudge" (a fast
## swipe with `nudge` on, reporting the breeze before and after) and "volley" (five quick swipes 0.12 s apart, to reuse
## parcel slots). For each it prints what the promise showed at release and
## what was sent, then the shared air over time as the shaders will read it:
## the steered parcel (zs_puff_N and zs_puff_heading_N, as published by
## studies/wind_puffs.gd) and the steered local gust (LocalWindField), or the
## clap ring for a burst. "lane" checks: the parcel's centre in lane
## coordinates (along, across; it must stay inside the lane), its heading
## against the swipe's and against the global wind, and the local gust's
## direction. Cost: WindGust's own time per frame (`last_usec`) and on
## release (`send_usec`), and main-loop frame gaps (dummy renderer, CPU only).
## Foliage ("foliage burst", "foliage swipe", "foliage drag"): what the
## shaders' zs_blow_at gives plants at sample points over time, read through
## its CPU mirror (WindGust `blow_at`) from the published zs_blow_*: the lean
## along the way the air goes (out from a burst, along a lane), how far it
## swings back past rest (the overshoot), when it has settled, and the tip
## movement that makes for a broadleaf crown (bends from 0.4 m, 2.4 m tall),
## a 7 m hero conifer and a 0.35 m grass tuft. "old" is what the first wind
## tool gave the same plants, from the steered local gust alone (reference_
## surface's flexibility * 3 * speed / (speed + 10), conifer_wind's
## local / (10 + speed) * 0.32); the hand's air had none.
##   godot --headless --path . --script tools/probe_wind_gust.gd [-- --only=fast,burst]
var scene: Node3D
var editor: NativeChunkEditor
var gust: Node3D
var only := []
var costs := []
var frames := []

func _initialize() -> void: run.call_deferred()

func stats(values: Array) -> Dictionary:
	if values.is_empty(): return {}
	var sorted := values.duplicate()
	sorted.sort()
	return {"n":sorted.size(),"median":snappedf(sorted[sorted.size()/2],0.001),"p95":snappedf(sorted[mini(sorted.size()-1,int(sorted.size()*0.95))],0.001),"max":snappedf(sorted.back(),0.001)}

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

func frame() -> void:
	var before := Time.get_ticks_usec()
	await process_frame
	frames.append((Time.get_ticks_usec()-before)/1000.0)
	if not gust.gusts.is_empty() or gust.aiming(): costs.append(gust.last_usec/1000.0)

func to_plate(world: Vector2) -> Vector2:
	var local := editor.terrain.to_local(Vector3(world.x,0.0,world.y))
	return Vector2(local.x,local.z)

func plate_way(world: Vector2) -> Vector2:
	var local := editor.terrain.global_basis.inverse()*Vector3(world.x,0.0,world.y)
	return Vector2(local.x,local.z).normalized()

func degrees(a: Vector2, b: Vector2) -> float:
	return snappedf(rad_to_deg(absf(a.angle_to(b))),0.01)

## Press at `from`, drag to `to` over `seconds`, let go; or hold still for
## `seconds` when `to` is null. Returns the promise at release and the gust.
func blow(from: Vector2, to: Variant, seconds: float, watch := Callable()) -> Dictionary:
	var point := screen_of(from)
	editor.pointer_override = point
	mouse(point,true)
	var took: bool = editor.gust != null and editor.gust.aiming()
	gust = editor.gust
	var elapsed := 0.0
	var start := Time.get_ticks_usec()
	while elapsed < seconds:
		elapsed = (Time.get_ticks_usec()-start)/1000000.0
		if to != null:
			point = screen_of(from.lerp(to,clampf(elapsed/seconds,0.0,1.0)))
			editor.pointer_override = point
		await frame()
		if watch.is_valid(): watch.call(elapsed)
	var promised: Dictionary = gust.promise()
	var count: int = gust.gusts.size()
	mouse(point,false)
	editor.pointer_override = null
	var sent: Dictionary = gust.gusts.back() if gust.gusts.size() > count else {}
	return {"took":took,"promise":promised,"gust":sent,"send_ms":snappedf(gust.send_usec/1000.0,0.001),"send_parts_usec":sent.get("cost_usec",{})}

func round2(v: Vector2) -> Array:
	return [snappedf(v.x,0.01),snappedf(v.y,0.01)]

## Follow one gust until it has settled: its parcel and local gust, sampled
## every frame and reported every 0.1 s.
func follow(g: Dictionary, label: String) -> Dictionary:
	var air: Node = scene._atmosphere
	var field: LocalWindField = gust.field
	var wind := Vector2(cos(air._air_angle),sin(air._air_angle))
	var timeline := []
	var worst_across := 0.0
	var along_range := Vector2(INF,-INF)
	var heading_error := 0.0
	var local_error := 0.0
	var ring_max := 0.0
	var clap_max := 0.0
	var puff_max := 0.0
	var local_max := 0.0
	var slot: int = g.slot
	var next_line := 0.0
	var began := Time.get_ticks_usec()
	var tie := 0.0
	while gust.gusts.has(g):
		await frame()
		var t := (Time.get_ticks_usec()-began)/1000000.0
		var line := {"t":snappedf(t,0.01),"head":snappedf(float(g.head),0.01),"air":snappedf(float(g.air),0.01)}
		if g.kind == "lane" and slot >= 0 and not g.done:
			var parcel: Vector4 = air.puffs.parcels[slot]
			var heading: Vector2 = air.puffs.headings[slot]
			var age: float = air._gust_distance-parcel.z
			var center := Vector2(parcel.x,parcel.y)+heading*age
			var rel: Vector2 = to_plate(center)-Vector2(g.origin)
			var along: float = rel.dot(g.heading)
			var across: float = rel.dot(Vector2(-g.heading.y,g.heading.x))
			worst_across = maxf(worst_across,absf(across))
			if parcel.w > 0.0:
				along_range = Vector2(minf(along_range.x,along),maxf(along_range.y,along))
				heading_error = maxf(heading_error,degrees(plate_way(heading),g.heading))
			puff_max = maxf(puff_max,parcel.w)
			line["parcel"] = {"along":snappedf(along,0.01),"across":snappedf(across,0.001),"w":snappedf(parcel.w,0.001)}
			for local_gust: Dictionary in field._gusts:
				if not g.local.has(local_gust.id): continue
				local_error = maxf(local_error,degrees(plate_way(Vector2(local_gust.direction.x,local_gust.direction.z)),g.heading))
				local_max = maxf(local_max,float(local_gust.strength))
				line["local"] = snappedf(float(local_gust.strength),0.01)
			var head_point: Vector2 = Vector2(g.origin)+Vector2(g.heading)*float(g.head)
			tie = maxf(tie,gust.wind_at(head_point).dot(g.heading))
		if g.kind == "burst":
			var clap: Vector4 = scene._lightning.clap if scene.get("_lightning") != null else Vector4.ZERO
			ring_max = maxf(ring_max,clap.z)
			clap_max = maxf(clap_max,clap.w)
			line["clap"] = {"radius":snappedf(clap.z,0.01),"w":snappedf(clap.w,0.001)}
			for local_gust: Dictionary in field._gusts:
				if g.local.has(local_gust.id): local_max = maxf(local_max,float(local_gust.strength))
		if t >= next_line:
			timeline.append(line)
			next_line += 0.1
	var report := {"gesture":label,"kind":g.kind,"reach":snappedf(float(g.reach),0.01),"half":snappedf(float(g.half),0.01),"power":snappedf(float(g.power),0.01),
		"run_s":snappedf(float(g.run),0.01),"lived_s":snappedf((Time.get_ticks_usec()-began)/1000000.0,0.01)}
	if g.kind == "lane":
		report["lane"] = {"heading":round2(g.heading),"global_wind_plate":round2(plate_way(wind)),"heading_vs_global_deg":degrees(g.heading,plate_way(wind)),
			"parcel_heading_error_deg":heading_error,"local_heading_error_deg":local_error,"parcel_across_max_m":snappedf(worst_across,0.001),
			"parcel_along_m":[snappedf(along_range.x,0.01),snappedf(along_range.y,0.01)],
			"inside":worst_across <= float(g.half) and along_range.x >= -1.0 and along_range.y <= float(g.reach)+0.01,
			"puff_w_max":snappedf(puff_max,0.001),"local_ms_max":snappedf(local_max,0.01),"wind_at_head_max":snappedf(tie,0.01)}
	else:
		report["burst"] = {"ring_max_m":snappedf(ring_max,0.01),"clap_w_max":snappedf(clap_max,0.001),"inside":ring_max <= float(g.reach)+0.01,"local_ms_max":snappedf(local_max,0.01)}
	report["timeline"] = timeline
	return report

func gust_land() -> Array:
	var low := Vector2(INF,INF)
	var high := -low
	for point: Vector2 in editor.data.points:
		low = low.min(point)
		high = high.max(point)
	return [round2(low),round2(high)]

## Plants the foliage readout moves: bend from, height (m).
const PLANTS := {"canopy":[0.4,2.4],"conifer":[0.0,7.0],"grass":[0.0,0.35]}
const OLD_FLEX := {"canopy":0.07,"grass":0.05}

func world_of(p: Vector2) -> Vector3:
	var data := editor.data
	return editor.terrain.to_global(Vector3(p.x,float(data.sample(p,data.heights)),p.y))

## One reading of every point: [label, plate point, plate way (the way the
## air should push there; ZERO: out from `center`)].
func read_foliage(points: Array, t: float, rows: Dictionary, center := Vector2.ZERO) -> void:
	var clock_now := float(scene.get("_motion_time"))
	for spec: Array in points:
		var label: String = spec[0]
		var p: Vector2 = spec[1]
		var way: Vector2 = spec[2] if spec[2] != Vector2.ZERO else (p-center).normalized()
		var world := world_of(p)
		var world_way := editor.terrain.global_basis*Vector3(way.x,0,way.y)
		var ref := Vector2(world_way.x,world_way.z).normalized()
		var reading: Vector3 = gust.blow_at(Vector2(world.x,world.z),clock_now)
		var lean := Vector2(reading.x,reading.y)
		var along := lean.dot(ref)
		var local: Vector3 = gust.field.sample_local(world+Vector3.UP*1.5)
		var speed := local.length()
		var row: Dictionary = rows.get(label,{})
		if row.is_empty():
			row = {"peak":0.0,"t_peak":0.0,"back":0.0,"t_back":0.0,"shiver":0.0,"angle_at_peak":0.0,"last_moving":0.0,"series":[],"new_m":{},"old_m":{}}
			for plant: String in PLANTS:
				row.new_m[plant] = 0.0
				row.old_m[plant] = 0.0
			rows[label] = row
		if along > row.peak:
			row.peak = along
			row.t_peak = t
			row.angle_at_peak = rad_to_deg(absf(lean.angle_to(ref))) if lean.length() > 0.001 else 0.0
		if along < row.back and row.peak > 0.05:
			row.back = along
			row.t_back = t
		row.shiver = maxf(row.shiver,reading.z)
		if lean.length() > 0.03: row.last_moving = t
		for plant: String in PLANTS:
			var shape: Array = PLANTS[plant]
			row.new_m[plant] = maxf(row.new_m[plant],lean.length()*gust.give(shape[1])*(shape[1]-shape[0]))
			var old := 0.0
			if plant == "conifer": old = Vector2(local.x,local.z).length()/(10.0+speed)*0.32
			else: old = OLD_FLEX[plant]*3.0*speed/(speed+10.0)
			row.old_m[plant] = maxf(row.old_m[plant],old)
		var series: Array = row.series
		if series.is_empty() or t-float(series.back()[0]) >= 0.1-0.0001:
			series.append([snappedf(t,0.01),snappedf(along,0.01),snappedf(reading.z,0.01)])

func foliage_report(rows: Dictionary) -> Dictionary:
	var out := {}
	for label: String in rows:
		var row: Dictionary = rows[label]
		var new_m := {}
		var old_m := {}
		for plant: String in PLANTS:
			new_m[plant] = snappedf(row.new_m[plant],0.01)
			old_m[plant] = snappedf(row.old_m[plant],0.01)
		out[label] = {"lean_peak":snappedf(row.peak,0.01),"at_s":snappedf(row.t_peak,0.01),"angle_at_peak_deg":snappedf(row.angle_at_peak,0.1),
			"swings_back":snappedf(row.back,0.01),"back_at_s":snappedf(row.t_back,0.01),"overshoot":snappedf(-row.back/maxf(row.peak,0.001),0.01),
			"shiver_max":snappedf(row.shiver,0.01),"moving_until_s":snappedf(row.last_moving,0.01),"tip_m_new":new_m,"tip_m_old":old_m,
			"series":row.series.filter(func(entry: Array) -> bool: return int(round(entry[0]*10.0))%3 == 0)}
	return out

## Watch the points until every gust has settled.
func watch_foliage(points: Array, rows: Dictionary, began: int, center := Vector2.ZERO) -> void:
	while not gust.gusts.is_empty():
		await frame()
		read_foliage(points,(Time.get_ticks_usec()-began)/1000000.0,rows,center)

func foliage_gestures() -> void:
	# A burst: held still 1.5 s (the pressure builds), then let go.
	var center := Vector2(-2.0,1.0)
	var hold_points := [["held, 1.5 m out",center+Vector2(1.5,0.0),Vector2.ZERO],["held, 4 m out",center+Vector2(0.0,4.0),Vector2.ZERO],["held, 10 m out",center+Vector2(-10.0,0.0),Vector2.ZERO]]
	var hold_rows := {}
	var began := Time.get_ticks_usec()
	var blown := await blow(center,null,1.5,func(elapsed: float) -> void: read_foliage(hold_points,elapsed,hold_rows,center))
	var burst_points := [["3 m out",center+Vector2(3.0,0.0),Vector2.ZERO],["6 m out",center+Vector2(0.0,-6.0),Vector2.ZERO],["9 m out",center+Vector2(-6.4,6.4),Vector2.ZERO],["14 m out (past the ring)",center+Vector2(9.9,9.9),Vector2.ZERO]]
	var burst_rows := {}
	var released := Time.get_ticks_usec()
	await watch_foliage(burst_points,burst_rows,released,center)
	var hold_series := {}
	for label: String in hold_rows:
		hold_series[label] = hold_rows[label].series.filter(func(entry: Array) -> bool: return int(round(entry[0]*10.0))%5 == 0)
	print("FOLIAGE ",JSON.stringify({"gesture":"foliage burst","held_s":1.5,"reach":snappedf(float(blown.gust.reach),0.01),"power":snappedf(float(blown.gust.power),0.01),
		"while_held":foliage_report(hold_rows),"held_over_time":hold_series,"after_release":foliage_report(burst_rows)}))
	# A fast swipe: foliage along the lane and beside it.
	var from := Vector2(-8.0,-5.0)
	var to := Vector2(-2.0,-5.0)
	var heading := (to-from).normalized()
	var side := Vector2(-heading.y,heading.x)
	var swipe_points := [["4 m along",from+heading*4.0,heading],["10 m along",from+heading*10.0,heading],["16 m along",from+heading*16.0,heading],
		["10 m along, 2 m aside",from+heading*10.0+side*2.0,heading],["10 m along, 6 m aside (outside)",from+heading*10.0+side*6.0,heading]]
	var swipe_rows := {}
	began = Time.get_ticks_usec()
	blown = await blow(from,to,0.15,func(elapsed: float) -> void: read_foliage(swipe_points,elapsed,swipe_rows))
	await watch_foliage(swipe_points,swipe_rows,began)
	print("FOLIAGE ",JSON.stringify({"gesture":"foliage swipe","reach":snappedf(float(blown.gust.reach),0.01),"power":snappedf(float(blown.gust.power),0.01),"lanes":foliage_report(swipe_rows)}))
	# A slow drag: the forming lane parts under the hand before release.
	from = Vector2(4.0,-6.0)
	to = Vector2(4.0,2.0)
	heading = (to-from).normalized()
	side = Vector2(-heading.y,heading.x)
	var drag_points := [["2 m along, 1.2 m left",from+heading*2.0+side*1.2,side],["2 m along, 1.2 m right",from+heading*2.0-side*1.2,-side],["6 m along, centre",from+heading*6.0,heading]]
	var drag_rows := {}
	blown = await blow(from,to,1.6,func(elapsed: float) -> void: read_foliage(drag_points,elapsed,drag_rows))
	var dragging := foliage_report(drag_rows)
	var after_rows := {}
	await watch_foliage(drag_points,after_rows,Time.get_ticks_usec())
	print("FOLIAGE ",JSON.stringify({"gesture":"foliage drag","drag_s":1.6,"power":snappedf(float(blown.gust.power),0.01),"while_dragging":dragging,"after_release":foliage_report(after_rows)}))

func air_state() -> Dictionary:
	var air: Node = scene._atmosphere
	var held := 0
	var live := 0
	for i in range(6):
		if air.puffs.held[i] != 0: held += 1
		if air.puffs.parcels[i].w > 0.0: live += 1
	var steered := 0
	for local_gust: Dictionary in gust.field._gusts:
		if local_gust.get("steered",false): steered += 1
	var clap: Vector4 = scene._lightning.clap if scene.get("_lightning") != null else Vector4.ZERO
	return {"puff_slots_held":held,"puffs_live":live,"steered_local":steered,"clap_w":snappedf(clap.w,0.001),"gusts":gust.gusts.size(),"motes":gust._motes.size()}

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="): only = Array(arg.trim_prefix("--only=").split(","))
	create_timer(300).timeout.connect(func() -> void: push_error("Wind gust probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-wind-probe-%d/places.json" % Time.get_ticks_usec()
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
	editor.select_brush("wind")
	var key_brush := preload("res://scripts/genesis_canvas.gd").brush_for_key(KEY_6)
	print("wind brush ",editor.held_brush()," key6 ",key_brush," atmosphere ",scene.get("_atmosphere") != null," lightning ",scene.get("_lightning") != null,
		" resident field ",scene.get("_resident_wind") != null)
	await create_timer(0.5).timeout
	print("land ",editor.data.points.size()," points, lane bounds ",gust_land())
	# Foliage wiring: which emerged-plant materials bend under the wind tool.
	var wiring := {"conifer_sway":[],"sway_enabled":[],"trunk_follows_crown":[]}
	var materials: Dictionary = editor.content._materials
	for key: String in materials:
		var material := materials[key] as ShaderMaterial
		if material == null: continue
		if material.get_shader_parameter("conifer_sway") == true: wiring.conifer_sway.append(key)
		elif material.get_shader_parameter("sway_enabled") == true: wiring.sway_enabled.append(key)
		elif material.get_shader_parameter("blow_enabled") == true: wiring.trunk_follows_crown.append(key)
	print("WIRING ",JSON.stringify(wiring))
	# Fast: a quick 6 m flick, toward -x+z. Slow: 4 m over 1.2 s, toward +z.
	for spec: Array in [["fast",Vector2(4.0,-3.0),Vector2(-1.2,0.0),0.15],["slow",Vector2(-5.0,-4.0),Vector2(-5.0,0.0),1.2],["burst",Vector2(1.0,2.0),null,0.8]]:
		if not only.is_empty() and spec[0] not in only: continue
		costs.clear()
		frames.clear()
		var blown := await blow(spec[1],spec[2],spec[3])
		var g: Dictionary = blown.gust
		if g.is_empty():
			print("GUST ",JSON.stringify({"gesture":spec[0],"took":blown.took,"sent":false,"promise":str(blown.promise)}))
			continue
		var p: Dictionary = blown.promise
		var same: bool = p.kind == g.kind and Vector2(p.origin) == Vector2(g.origin) and Vector2(p.heading) == Vector2(g.heading) and is_equal_approx(float(p.reach),float(g.reach)) and is_equal_approx(float(p.power),float(g.power))
		var swipe: Vector2 = (Vector2(spec[2])-Vector2(spec[1])).normalized() if spec[2] != null else Vector2.ZERO
		var report := await follow(g,spec[0])
		report["took_press"] = blown.took
		report["sent_as_promised"] = same
		if swipe != Vector2.ZERO: report["heading_vs_swipe_deg"] = degrees(Vector2(g.heading),swipe)
		report["send_ms"] = blown.send_ms
		report["send_parts_usec"] = blown.send_parts_usec
		report["gust_ms_per_frame"] = stats(costs)
		report["frame_ms"] = stats(frames)
		report["after"] = air_state()
		print("GUST ",JSON.stringify(report))
	if only.is_empty() or "foliage" in only:
		await foliage_gestures()
	if only.is_empty() or "nudge" in only:
		# Lasting wind, the open option: a strong gust turns the breeze.
		var air: Node = scene._atmosphere
		var before := {"direction_angle":snappedf(air.direction_angle,0.01),"strength":snappedf(air.strength,0.001)}
		gust.nudge = 0.25
		var blown := await blow(Vector2(2.0,3.0),Vector2(2.0,-3.0),0.15)
		gust.nudge = 0.0
		var g: Dictionary = blown.gust
		var way := Vector2(g.heading)
		print("NUDGE ",JSON.stringify({"before":before,"after":{"direction_angle":snappedf(air.direction_angle,0.01),"strength":snappedf(air.strength,0.001)},
			"gust_heading_deg":snappedf(rad_to_deg(way.angle()),0.01),"power":snappedf(float(g.power),0.01)}))
		while not gust.gusts.is_empty(): await frame()
		air.direction_angle = before.direction_angle
		air.strength = before.strength
	if only.is_empty() or "volley" in only:
		# Five quick swipes 0.12 s apart, each a different way: each takes its
		# own parcel slot while it flies, a fifth hastens the oldest, and all
		# are given back. A second volley of three then takes the slots again.
		var ways := [Vector2(1,0),Vector2(0,1),Vector2(-1,0.3),Vector2(0.4,-1),Vector2(0.7,0.7)]
		for round_index in range(2):
			costs.clear()
			frames.clear()
			var slots := []
			var sends := []
			var peak := {}
			for i in range(ways.size() if round_index == 0 else 3):
				var from := Vector2(-2.0+i*1.1,-1.0+i*0.6)
				var blown := await blow(from,from+Vector2(ways[i]).normalized()*5.0,0.1)
				var g: Dictionary = blown.gust
				slots.append(g.get("slot",-2))
				sends.append(blown.send_ms)
				var state := air_state()
				if state.puff_slots_held > int(peak.get("puff_slots_held",0)): peak = state
				for f in range(7): await frame()
			var distinct := {}
			var shared := false
			for slot: int in slots:
				if slot >= 0 and distinct.has(slot): shared = true
				distinct[slot] = true
			var waited := 0.0
			var began := Time.get_ticks_usec()
			while not gust.gusts.is_empty() and waited < 12.0:
				await frame()
				waited = (Time.get_ticks_usec()-began)/1000000.0
			print("VOLLEY ",JSON.stringify({"round":round_index+1,"slots":slots,"two_gusts_one_slot":shared,"peak":peak,"send_ms":sends,"settled_s":snappedf(waited,0.01),
				"after":air_state(),"gust_ms_per_frame":stats(costs),"frame_ms":stats(frames),"worst_gust_ms":snappedf(gust.worst_usec/1000.0,0.001)}))
	scene.queue_free()
	for _frame in range(3): await process_frame
	quit()
