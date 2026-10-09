extends Node3D
## Flight study: a greybox course for flying the game's plane
## (scripts/sky_plane.gd) through short hand-placed sections of tokens
## (scripts/flight_course.gd), to find out what kinds of flying set pieces
## are wanted before any are built. Each station is a few primitive solids
## and a token trail; every run, a person's or the CPU's, is recorded and
## measured (scripts/flight_run.gd, scripts/flight_metrics.gd) and saved as
## JSON under user://flight_runs (scripts/flight_log.gd). F1 shows the live
## numbers; at a station's end a report shows its time, its tokens, the bots'
## band for it (tools/flight_bench.gd) and the run's own demand, and asks for
## two 1-5 ratings, felt difficulty then fun, saved into the run's file.
##
## The plane is the game's own, flown by the same input dict the wanderer
## fills (scripts/wanderer_eye.gd `_plane_input`): WASD or the left stick
## turn and pitch (W noses down, as in the game), Space or RT boosts, Shift
## or LT brakes, Q and E or the shoulders held tip it on a knife edge and
## double-tapped barrel-roll it. It bumps off the solids as it does off the
## game's ruins (scripts/ruin_bump.gd). The camera is the game's chase
## (scripts/glide_camera.gd); the mouse or right stick looks round.
##
## Keys: 1-9, 0 and - the stations, R restart the station, N the next one, B cycles
## who flies (you, then the sloppy, decent, sharp and perfect bots), F1 the
## live numbers, Esc lets the mouse go. After a station: 1-5 rates felt
## difficulty, then 1-5 fun (Enter skips).
##   ./run-flight-study.command
##   godot --path . res://studies/flight_study.tscn -- --no-title [--station=slalom] [--bot=sharp]

const Course = preload("res://scripts/flight_course.gd")
const Run = preload("res://scripts/flight_run.gd")
const Bot = preload("res://scripts/flight_bot.gd")
const Metrics = preload("res://scripts/flight_metrics.gd")
const Log = preload("res://scripts/flight_log.gd")
const PlaneFigure = preload("res://scripts/plane_figure.gd")
const GlideCamera = preload("res://scripts/glide_camera.gd")
const Pad = preload("res://scripts/pad.gd")
const GRID := preload("res://shaders/character_study_grid.gdshader")

## The mouse's and right stick's look round the plane (as the wanderer's).
const LOOK := 0.0025
const STICK_LOOK := 2.4
## A second Q or E within this long asks for a barrel roll (as the game).
const DOUBLE_TAP := 0.3
const COLOURS := {"floor":Color(0.64,0.64,0.62),"box":Color(0.55,0.57,0.6),"cyl":Color(0.6,0.58,0.55)}
const TOKEN := Color(1.0,0.82,0.3)
const TAKEN := Color(0.4,0.9,0.5)
const MISSED := Color(0.85,0.3,0.25)
## Who flies, in B's order.
const PILOTS := ["human","sloppy","decent","sharp","perfect"]

signal ready_to_fly

var flight_ready := false
## Driven by a test: no input read, `tick` called by hand.
var scripted := false
## Where runs are saved.
var log_dir := Log.DIR
var station := {}
var run: Run
var bot: Bot
var pilot := "human"
var figure: Node3D
var chase := GlideCamera.new()
var camera: Camera3D
## The last run's data and file, and the rating being asked for: "",
## "difficulty", "fun".
var last_run := {}
var last_path := ""
var asking := ""
var _token_nodes: Array[MeshInstance3D] = []
var _token_materials := {}
var _materials := {}
var _hud: Control
var _hud_label: Label
var _report: PanelContainer
var _report_label: Label
var _hint: Label
var _bands := {}
var _roll_asked := 0.0
var _tap_dir := 0.0
var _tap_at := 0
var _space: PhysicsDirectSpaceState3D
var _solids := []

func _ready() -> void:
	Pad.ensure()
	_build_light()
	_build_course()
	_build_ui()
	figure = PlaneFigure.new()
	add_child(figure)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_space = get_world_3d().direct_space_state
	_bands = Log.bands(log_dir)
	var first := Course.STATIONS[0] as Dictionary
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--station="): first = Course.station(arg.substr(10)) if not Course.station(arg.substr(10)).is_empty() else first
		if arg.begins_with("--bot=") and arg.substr(6) in PILOTS: pilot = arg.substr(6)
	start(first)
	flight_ready = true
	ready_to_fly.emit()
	if not scripted and get_tree().current_scene == self: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	print("flight study: flying %.2f s from launch" % (Time.get_ticks_msec()/1000.0))

# --- The course ----------------------------------------------------------------------

func _build_light() -> void:
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = Color("6f9fcf")
	sky.sky_horizon_color = Color("dfe6e4")
	sky.ground_bottom_color = Color("9aa3a6")
	sky.ground_horizon_color = Color("dfe6e4")
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.sky.sky_material = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.9
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("dfe6e4")
	environment.fog_density = 0.002
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0,-35.0,0.0)
	sun.light_color = Color("fff1dc")
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 150.0
	add_child(sun)
	camera = Camera3D.new()
	camera.fov = GlideCamera.FOV
	camera.far = 1200.0
	add_child(camera)
	camera.current = true

func _material(kind: String) -> Material:
	if not _materials.has(kind):
		var m := ShaderMaterial.new()
		m.shader = GRID
		m.set_shader_parameter("tint",COLOURS.get(kind,COLOURS.box))
		_materials[kind] = m
	return _materials[kind]

## The floor, every station's solids, tokens and sign.
func _build_course() -> void:
	var count := Course.STATIONS.size()
	var floor_mesh := MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = Vector3(Course.SPACING*count+400.0,1.0,700.0)
	floor_mesh.mesh = slab
	floor_mesh.position = Vector3(Course.SPACING*(count-1)*0.5,Course.floor_y()-0.5,-150.0)
	floor_mesh.material_override = _material("floor")
	add_child(floor_mesh)
	for s: Dictionary in Course.STATIONS:
		Course.build(s,self,_material)
		var at := Course.origin(s)
		_label(at+Vector3(-8.0,7.0,-4.0),"%s  %s" % [Course.key_name(s),s.name],96)
		# A post under the entry, so its height reads against the floor.
		var post := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.3
		cyl.bottom_radius = 0.3
		cyl.height = at.y-2.0
		post.mesh = cyl
		post.position = Vector3(at.x,(at.y-2.0)*0.5,at.z+4.0)
		post.material_override = _material("cyl")
		add_child(post)

func _label(at: Vector3, text: String, size: int) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.outline_size = 16
	label.pixel_size = 0.02
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(0.12,0.12,0.14)
	label.outline_modulate = Color(1.0,1.0,1.0,0.85)
	label.position = at
	add_child(label)

func _token_material(colour: Color) -> StandardMaterial3D:
	if not _token_materials.has(colour):
		var m := StandardMaterial3D.new()
		m.albedo_color = colour
		m.emission_enabled = true
		m.emission = colour
		m.emission_energy_multiplier = 0.8
		_token_materials[colour] = m
	return _token_materials[colour]

## The station's tokens, drawn afresh.
func _show_tokens() -> void:
	for n in _token_nodes: n.queue_free()
	_token_nodes.clear()
	for p in Course.tokens(station):
		var node := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = Course.TOKEN_SIZE*0.5
		ball.height = Course.TOKEN_SIZE
		node.mesh = ball
		node.position = p
		node.material_override = _token_material(TOKEN)
		add_child(node)
		_token_nodes.append(node)

# --- Flying --------------------------------------------------------------------------

## Starts station `s` afresh, flown by `pilot`.
func start(s: Dictionary) -> void:
	if run != null and not run.done: run.abandon()
	station = s
	_solids = Course.solids(s)
	var params := {} if pilot == "human" else Bot.skill(pilot)
	run = Run.new(s,"human" if pilot == "human" else "bot:"+pilot,params,_space)
	bot = null if pilot == "human" else Bot.new(params,randi())
	asking = ""
	_report.visible = false
	_show_tokens()
	figure.reset(run.plane)
	chase.reset(run.plane,run.plane.position-run.plane.forward()*6.0+Vector3.UP*2.0,camera.fov)
	_frame(0.0)

func restart() -> void:
	start(station)

func next_station() -> void:
	var i := Course.STATIONS.find(station)
	start(Course.STATIONS[(i+1)%Course.STATIONS.size()])

func _physics_process(delta: float) -> void:
	if flight_ready and not scripted: tick(delta)

## One tick: the input (keys or bot), the run stepped (or, once it is over,
## the plane flown on unrecorded), the drawing and the numbers.
func tick(delta: float) -> void:
	var input := bot.input(run,delta) if bot != null else _input_dict()
	if not run.done:
		run.tick(delta,input)
		if run.done: _finished()
	else:
		var was := run.plane.position
		run.plane.step(delta,input,Callable(Course,"ground"))
		if _space != null: Run.RuinBump.bump(_space,run.plane,was)
	for i in range(_token_nodes.size()):
		var s := run.state[i]
		_token_nodes[i].visible = s != Run.TAKEN
		_token_nodes[i].material_override = _token_material(MISSED if s == Run.MISSED else TOKEN)
	figure.update(delta,run.plane,0.0,Callable(Course,"ground"),false)
	_frame(delta)
	_show_hud()

func _frame(delta: float) -> void:
	if not scripted:
		var right := Pad.stick(&"look_left",&"look_right",&"look_up",&"look_down")
		if right != Vector2.ZERO: chase.turn(Vector2(-right.x,-right.y)*STICK_LOOK*maxf(delta,0.0))
		chase.free_held = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or right != Vector2.ZERO
	chase.step(delta,run.plane,0.0,_solid)
	var way := chase.look-chase.eye
	if way.length() < 0.01: way = run.plane.forward()
	camera.global_transform = Transform3D(Basis.looking_at(way,Vector3.UP),chase.eye)
	if chase.roll != 0.0: camera.rotate_object_local(Vector3.BACK,chase.roll)
	camera.fov = chase.fov

## Inside a solid or under the floor, for the camera to keep out of.
func _solid(p: Vector3) -> bool:
	if p.y < Course.floor_y()+0.3: return true
	for s: Dictionary in _solids:
		if Course.distance(s,p) < 0.2: return true
	return false

## The plane's input from the keys and pad, as the wanderer's
## (scripts/wanderer_eye.gd `_fly_input` and `_plane_input`).
func _input_dict() -> Dictionary:
	var stick := Input.get_vector(&"move_left",&"move_right",&"move_forward",&"move_back")
	var keys := (1.0 if Input.is_key_pressed(KEY_E) else 0.0)-(1.0 if Input.is_key_pressed(KEY_Q) else 0.0)
	var input := {
		"turn":stick.x,"pitch":stick.y,"look":Vector2.ZERO,
		"boost":Input.get_action_strength(&"fly_boost"),"brake":Input.get_action_strength(&"fly_brake"),
		"lean":clampf(keys+Input.get_action_strength(&"fly_lean_right")-Input.get_action_strength(&"fly_lean_left"),-1.0,1.0),
		"roll":_roll_asked,
	}
	_roll_asked = 0.0
	return input

func _lean_tapped(dir: float) -> void:
	var now := Time.get_ticks_msec()
	if dir == _tap_dir and now-_tap_at <= int(DOUBLE_TAP*1000.0):
		_roll_asked = dir
		_tap_dir = 0.0
	else:
		_tap_dir = dir
		_tap_at = now

## The station is over: its data saved, the report shown, the ratings asked
## for (a person's runs only).
func _finished() -> void:
	last_run = run.finish()
	last_path = Log.save(last_run,log_dir)
	asking = "difficulty" if pilot == "human" else ""
	_report.visible = true
	_show_report()

func rate(value: int) -> void:
	if asking == "" or last_path == "": return
	var rating: Dictionary = last_run.get("rating",{})
	rating[asking] = clampi(value,1,5)
	last_run["rating"] = rating
	asking = "fun" if asking == "difficulty" else ""
	Log.write(last_path,last_run)
	_show_report()

# --- The numbers ---------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_hud = Control.new()
	_hud.position = Vector2(16.0,12.0)
	_hud.size = Vector2(430.0,355.0)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.draw.connect(_draw_bars)
	layer.add_child(_hud)
	_hud_label = Label.new()
	_style(_hud_label,15)
	_hud_label.position = Vector2(16.0,240.0)
	_hud.add_child(_hud_label)
	_hint = Label.new()
	_hint.text = "WASD/stick turn and pitch (W noses down) · Space/RT boost · Shift/LT brake · Q/E lean (knife edge), twice: roll · 0-9, - stations · R restart · N next · B who flies · F1 numbers · Esc mouse"
	_style(_hint,14)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_top = -36.0
	_hint.offset_left = -700.0
	_hint.offset_right = 700.0
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(_hint)
	_report = PanelContainer.new()
	_report.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_report.offset_left = -330.0
	_report.offset_right = 330.0
	_report.offset_top = -185.0
	_report.offset_bottom = 185.0
	_report.visible = false
	layer.add_child(_report)
	_report_label = Label.new()
	_style(_report_label,17)
	_report_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_report.add_child(_report_label)

func _style(label: Label, size: int) -> void:
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",Color("fbf6ea"))
	label.add_theme_color_override("font_shadow_color",Color(0,0,0,0.7))
	label.add_theme_constant_override("shadow_offset_y",1)

func _show_hud() -> void:
	_hud.queue_redraw()
	if not _hud.visible: return
	var live := run.live()
	var since := "-" if is_nan(float(live.since)) else "%.1f s ago" % float(live.since)
	_hud_label.text = "\n".join(PackedStringArray([
		"%s · %s · %s" % [station.name,run.pilot,"done" if run.done else "flying"],
		"time %.2f s · tokens %d/%d · bumps %d · speed %.1f m/s" % [float(live.t),int(live.collected),int(live.total),int(live.bumps),run.plane.speed],
		"next token seen %s" % since,
		"reversals %.2f /s · effort %.2f /s · full stick %d%%" % [float(live.reversals),float(live.effort),roundi(float(live.full)*100.0)],
		"threading %s · %d%% of the run · openings %d (%.2f /s)" % ["NOW" if live.threading_now else "open air",roundi(float(live.threading)*100.0),int(live.openings),float(live.openings_per_s)],
		"flow: still %d%% · longest %.1f s%s" % [roundi(float(live.still)*100.0),float(live.longest_straight)," · straight NOW" if live.straight_now else ""],
	]+_knife_hud(live)))

## The knife edge line, on a station with knife slits: slits threaded
## clean of all, time on edge, and the next slit's distance in seconds once
## seen.
func _knife_hud(live: Dictionary) -> Array:
	if int(live.knife_moments) == 0: return []
	var next := "" if is_nan(float(live.knife_next)) else " · next slit %.1f s" % float(live.knife_next)
	return ["knife: %d/%d slits clean · on edge %.1f s%s%s" % [int(live.knife_clean),int(live.knife_moments),float(live.on_edge_s)," · ON EDGE" if live.on_edge else "",next]]

## The live bars: flown turn and pitch against what the line needs here
## (the white tick), the gap's demand, and the slack to the next token.
func _draw_bars() -> void:
	if run == null: return
	var live := run.live()
	var font := ThemeDB.fallback_font
	var rows := [
		["turn",float(live.turn),float(live.need_turn),1.5,"%.2f of TURN_RATE" % float(live.turn)],
		["pitch",float(live.pitch),float(live.need_pitch),1.5,"%.2f of PITCH_SPEED" % float(live.pitch)],
		["demand",float(live.demand),-1.0,1.2,"%.2f %s" % [float(live.demand),Metrics.grade(float(live.demand))]],
		["slack",0.0 if is_nan(float(live.slack)) else float(live.slack),-1.0,3.0,"not seen" if is_nan(float(live.slack)) else "%.2f s" % float(live.slack)],
	]
	_hud.draw_rect(Rect2(-8.0,-6.0,440.0,355.0),Color(0.0,0.0,0.0,0.35))
	var y := 6.0
	for row: Array in rows:
		_hud.draw_string(font,Vector2(0.0,y+14.0),row[0],HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("fbf6ea"))
		var full := Rect2(70.0,y,220.0,16.0)
		_hud.draw_rect(full,Color(1.0,1.0,1.0,0.15))
		var share := clampf(float(row[1])/float(row[3]),0.0,1.0)
		var colour := Color(0.45,0.8,0.5).lerp(Color(0.9,0.35,0.25),share)
		if row[0] == "slack": colour = Color(0.9,0.35,0.25).lerp(Color(0.45,0.8,0.5),share)
		_hud.draw_rect(Rect2(full.position,Vector2(full.size.x*share,full.size.y)),colour)
		if float(row[2]) >= 0.0:
			var x := full.position.x+full.size.x*clampf(float(row[2])/float(row[3]),0.0,1.0)
			_hud.draw_line(Vector2(x,y-2.0),Vector2(x,y+18.0),Color.WHITE,2.0)
		_hud.draw_string(font,Vector2(300.0,y+14.0),row[4],HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("fbf6ea"))
		y += 26.0
	# The demand curve so far: this gap's demand along the run.
	var strip := Rect2(0.0,y+6.0,420.0,90.0)
	_hud.draw_rect(strip,Color(1.0,1.0,1.0,0.08))
	var t: Array = run.ticks.t
	if t.size() > 1:
		var span := maxf(float(t.back()),8.0)
		var line := PackedVector2Array()
		for i in range(0,t.size(),3):
			var next := _gap_at(float(t[i]))
			var d := 0.0
			if next >= 0:
				var gp: Dictionary = run.gaps[next]
				d = Metrics.gap_demand(gp.turn_peak,gp.pitch_peak,Metrics.WARN_EASY,float(run.rooms[next].room),Metrics.commit_time(gp))
			line.append(strip.position+Vector2(strip.size.x*float(t[i])/span,strip.size.y*(1.0-clampf(d/1.2,0.0,1.0))))
		if line.size() > 1: _hud.draw_polyline(line,Color(1.0,0.82,0.3),2.0)
	_hud.draw_string(font,strip.position+Vector2(4.0,14.0),"line demand",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(1.0,1.0,1.0,0.6))

## The token whose gap the plane was in at time `at` (s), or -1.
func _gap_at(at: float) -> int:
	for e: Dictionary in run.events:
		if (e.kind == "hit" or e.kind == "miss") and float(e.t) >= at: return int(e.token)
	return run.next_token()

func _show_report() -> void:
	var m: Dictionary = last_run.get("metrics",{})
	var lines := PackedStringArray()
	lines.append("%s · %s" % [station.name,last_run.get("pilot","")])
	lines.append("Time %.2f s · tokens %d/%d%s · bumps %d" % [float(m.duration),int(m.collected),int(m.total),"  CLEARED" if m.cleared else "",int(m.bumps)])
	var band: Dictionary = _bands.get(station.id,{})
	if band.is_empty() or str(band.get("hash","")) != Course.station_hash(station):
		lines.append("Bot band: not benched for this layout (tools/flight_bench.gd)")
	else:
		var c: Dictionary = band.clears
		lines.append("Bot band: %s  (clears: sloppy %.1f · decent %.1f · sharp %.1f · perfect %.1f)" % [str(band.band).to_upper(),float(c.get("sloppy",0)),float(c.get("decent",0)),float(c.get("sharp",0)),float(c.get("perfect",0))])
	lines.append("Your demand: peak %.2f (%s) · mean %.2f · spike %.2f" % [float(m.demand_peak),m.grade,float(m.demand_mean),float(m.demand_spike)])
	lines.append("Turn: line needs %.2f, you flew %.2f peak · pitch needs %.2f, flew %.2f" % [float(m.turn_need_peak),float(m.turn_flown_peak),float(m.pitch_need_peak),float(m.pitch_flown_peak)])
	lines.append("Warning least %s · room least %s" % ["-" if m.warning_min == null else "%.2f s" % float(m.warning_min),"-" if m.room_min == null else "%.2f m" % float(m.room_min)])
	lines.append("Reversals %.2f /s · effort %.2f /s · full stick %d%%" % [float(m.reversals_per_s),float(m.effort),roundi(float(m.full_share)*100.0)])
	lines.append("Threading %d%% of the run · openings %d (%.2f /s)" % [roundi(float(m.get("threading_share",0.0))*100.0),int(m.get("openings",0)),float(m.get("openings_per_s",0.0))])
	lines.append("Flow: still %d%% · straights %d · longest %.1f s · swing %.0f°/s, %d%% sideways" % [roundi(float(m.get("still_share",0.0))*100.0),int(m.get("straights",0)),float(m.get("longest_straight",0.0)),float(m.get("swing_mean",0.0)),roundi(float(m.get("yaw_share",0.0))*100.0)])
	if int(m.get("knife_moments",0)) > 0:
		lines.append("Knife edge: %d/%d slits clean · on edge %.1f s · warning least %s · on edge %s before a slit" % [int(m.knife_clean),int(m.knife_moments),float(m.on_edge_s),
			"-" if m.knife_warning_min == null else "%.1f s" % float(m.knife_warning_min),"-" if m.knife_lead == null else "%.2f s" % float(m.knife_lead)])
	var rating: Dictionary = last_run.get("rating",{})
	if asking == "difficulty": lines.append("\nHow hard did it feel? 1 (easy) - 5 (hard)   · Enter skips")
	elif asking == "fun": lines.append("\nDifficulty %d. How fun? 1 - 5   · Enter skips" % int(rating.difficulty))
	elif not rating.is_empty(): lines.append("\nRated: difficulty %s · fun %s" % [str(rating.get("difficulty","-")),str(rating.get("fun","-"))])
	lines.append("R again · N next · 0-9, - a station")
	_report_label.text = "\n".join(lines)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		chase.turn(Vector2(-event.relative.x,-event.relative.y)*LOOK)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventJoypadButton and event.pressed:
		if Pad.pressed(event,&"fly_lean_left"): _lean_tapped(-1.0)
		elif Pad.pressed(event,&"fly_lean_right"): _lean_tapped(1.0)
	elif event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).keycode
		if asking != "" and key >= KEY_1 and key <= KEY_5:
			rate(key-KEY_0)
			return
		match key:
			KEY_ESCAPE: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			KEY_ENTER,KEY_KP_ENTER:
				asking = ""
				if _report.visible: _show_report()
			KEY_R: restart()
			KEY_N: next_station()
			KEY_B:
				pilot = PILOTS[(PILOTS.find(pilot)+1)%PILOTS.size()]
				restart()
			KEY_F1: _hud.visible = not _hud.visible
			KEY_Q: _lean_tapped(-1.0)
			KEY_E: _lean_tapped(1.0)
			_:
				if key >= KEY_0 and key <= KEY_9 or key == KEY_MINUS:
					var s := Course.station_by_key(Course.MINUS_KEY if key == KEY_MINUS else key-KEY_0)
					if not s.is_empty(): start(s)
