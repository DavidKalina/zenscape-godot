extends Node3D
## Ruin kit gallery: the ruin kit's three families on one floating plate,
## each piece intact and weathered side by side. In the middle the gothic
## abbey's fourteen pieces (scripts/ruin_kit.gd), laid close in four rows
## (the tall gable, arch and window at the back, the turret, vault,
## buttress and pier in the middle, the low pieces before them, the grand
## stair and the stone circle in front) so the whole view is ruins, not
## lawn; to its right the aqueduct (scripts/
## ruin_kit_aqueduct.gd), its pieces in two rows before an assembled run
## striding over a strip of water (the head, four spans, one broken and
## spilling, stumps beyond); to its left the colossus hall (scripts/
## ruin_kit_hall.gd), its pieces before two hall bays put together round
## the medallion with the fallen mask beside them, dim under the roof, the
## sun coming down through its gaps in shafts (volumetric fog in a box
## round the hall, as the redwood mist does its rays). Lit as the game is: its sky,
## sun and grade (scripts/landscape_lighting.gd, studies/celestial.gd) and
## its look pass (scripts/look_pass.gd: the cloud sea and cloud volume under
## the plate, the hour's grade, the night style the player chose), at the
## game's own noon and midnight (the look tour's hours, tools/
## capture_look_tour.gd). The pilot on foot (scripts/pilot_figure.gd)
## stands about for scale and the plane (scripts/plane_figure.gd) hangs in
## the pointed arch, under an aqueduct arch and inside the hall.
##   Drag            orbit          Wheel     zoom
##   F1 F2 F3        frame the gothic, aqueduct or hall family
##   1-9 0 - = \     frame a piece of the family  Left/Right the next piece
##   C               the family's centrepiece (the run, the hall)
##   Space or Tab    the whole layout     L  light shafts in the hall
##   W               pairs, intact only, weathered only
##   R               reseed the weathering     N  day or night
##   V               the growth in the wind or held still (compare)
##   B               send a strong gust front across the view now
##   T               the next stone look: classic, big ashlar, carved mass,
##                   islet basalt, eroded basalt light / medium / heavy
##                   (scripts/ruin_stone_style.gd, docs/scenic/ruin-stone.md);
##                   --stone=classic|ashlar|mass|basalt|eroded_light|eroded|eroded_heavy
##                   starts in one
## The growth (scripts/ruin_growth.gd, docs/scenic/ruin-overgrowth.md) sways
## in the game's breeze, run here as the atmosphere runs it: the air's
## travel, its gust fronts (studies/gust_fronts.gd) and the breeze.
##   --still        start with the growth held still     --no-vines  no vine curtains
##   --gust=<s>     send a strong gust front that many seconds in
##   --breeze=<x>   the breeze (zs_breeze; the game's default air is 0.53)
##   --frames=<n>   with --capture: n frames, --frame-step=<s> apart (0.1),
##                  saved as <capture>_000.png and on, for a sway sequence
##   ./run-ruin-kit.command [--family=hall] [--piece=2] [--centre] [--night] [--show=intact|weathered] [--seed=3] [--no-shafts]
##   godot --path . res://studies/ruin_kit_gallery.tscn -- --no-title --capture=out.png
## --capture=<png> waits for the sky to settle, saves the view and quits;
## --yaw=, --pitch= and --distance= set the view for it; --at=x,y,z puts
## the eye there looking at --look=x,y,z (in the layout's frame, or with --centre in the centrepiece's).
const RuinKit = preload("res://scripts/ruin_kit.gd")
const Aqueduct = preload("res://scripts/ruin_kit_aqueduct.gd")
const Hall = preload("res://scripts/ruin_kit_hall.gd")
const PilotFigure = preload("res://scripts/pilot_figure.gd")
const PlaneFigure = preload("res://scripts/plane_figure.gd")
const WandererEye = preload("res://scripts/wanderer_eye.gd")
const LandscapeLighting = preload("res://scripts/landscape_lighting.gd")
const Celestial = preload("res://studies/celestial.gd")
const LookPass = preload("res://scripts/look_pass.gd")
const SkyPlane = preload("res://scripts/sky_plane.gd")
const GlideCamera = preload("res://scripts/glide_camera.gd")
const Pad = preload("res://scripts/pad.gd")
const RuinGrowth = preload("res://scripts/ruin_growth.gd")
const RuinGrowthPush = preload("res://scripts/ruin_growth_push.gd")
const GustFronts = preload("res://studies/gust_fronts.gd")
const StoneStyle = preload("res://scripts/ruin_stone_style.gd")

## The families left to right on the plate, their names, and each one's
## rows, back to front, and where each row stands (z, m).
const ORDER := ["hall","gothic","aqueduct"]
const FAMILY_NAMES := {"gothic":"Gothic abbey","aqueduct":"Aqueduct","hall":"Colossus hall"}
const ROWS := {"gothic":[["rose_gable","arch","lancet_wall"],["turret","vault","buttress","pier"],["wall","stairs","fallen_pier","tomb_chest","floor"],["grand_stair","stone_circle"]],
	"aqueduct":[["aqueduct_end","aqueduct_two_tier","aqueduct_span","aqueduct_broken","aqueduct_stump"]],
	"hall":[["hall_bay"],["hall_column","hall_beam","hall_slab"]]}
const ROW_Z := {"gothic":[-13.0,-1.5,9.0,33.0],"aqueduct":[0.0],"hall":[0.0,27.0]}
## The room between families on the plate (m), and how far behind its rows
## a family's centrepiece stands (to its middle).
const FAMILY_GAP := 10.0
const CENTRE_BACK := {"gothic":22.0,"aqueduct":22.0,"hall":44.0}
## The aqueduct run: spans, which one is broken, its weathering; the strip
## of water under it (its half width, m) and the stumps standing in it past
## its end.
const RUN_SPANS := 4
const RUN_BREAK := 2
const RUN_WEATHERED := 0.55
const SEA_HALF := 7.0
## The hall's centrepiece weathering, and its light shafts: the fog's
## density in the box round it and the sun's share in it.
const HALL_WEATHERED := 0.6
## The long hall's plan: straight, a long curve to the left, straight on
## (scripts/ruin_kit_hall.gd `hall` layout), its bays in all.
const HALL_LAYOUT := [{"bays":4,"turn":0.0},{"bays":6,"turn":0.85},{"bays":6,"turn":0.0}]
const HALL_BAYS := 16
## The aqueduct that feeds the hall: its spans, chained to the hall's first
## mouth (its channel's far end a little short of it, on the hall's axis).
const FEED_SPANS := 4
const SHAFT_FOG := 0.02
const SHAFT_LIGHT := 4.0
## Fly mode: the plane's body for the bump (m: its wings' span across, a
## thin slab, its length; turned with its bank, so on a knife edge it slips
## through a gap its level wings would not), the share of its speed a
## bump keeps, the mouse's turn (radians a pixel, the game's LOOK).
const BUMP_BODY := Vector3(PlaneFigure.SPAN,0.3,1.2)
const BUMP_KEEP := 0.55
const FLY_LOOK := 0.0025
## The aqueduct across a valley (uneven ground): its spans.
const VALLEY_SPANS := 6
## The terrain demos' slopes down to the plate round their rims (m).
const TERRAIN_FADE := 14.0
## The room between a pair's two (m) and between pairs.
const PAIR_GAP := 0.8
const SLOT_GAP := 2.6
## The hours (studies/celestial.gd phase): a late morning, the sun high
## enough to be the game's day and low enough to model the faces; midnight.
const DAY := 0.45
const NIGHT := 0.0
## The game's own look at its noon, as the look tour logged it (tools/
## capture_look_tour.gd, the opening world, 2026-10-08): the scene look
## (scripts/scene_look.gd) a world is made with, its sky, ambient and
## exposure. Without it the celestial rig runs on the bare defaults, whose
## sky is a quarter as bright and reads as a dusky purple at noon (the
## ancient gallery's), which misjudges every colour under it. The sky's
## cloud deck as the game has it then: cover CLOUD, foot and depth DECK (m).
const GAME_LOOK := {"version":1,"palette":"Custom","colors":{"grass":[0.3647,0.6196,0.3255],"foliage":[0.2784,0.4627,0.2902],
	"rock":[0.5529,0.5216,0.4667],"earth":[0.4157,0.3137,0.2431],"water":[0.2235,0.4902,0.4745],"sun":[0.9804,0.8392,0.6863],
	"ambient":[0.5608,0.7020,0.8510],"bounce":[0.2902,0.3216,0.2510],"rim":[0.4980,0.6588,0.7882],"fog":[0.8627,0.8863,0.8745],
	"sky":[0.4784,0.6,0.8],"horizon":[0.7529,0.7922,0.7961],"glow":[0.9529,0.7843,0.6667]},
	"settings":{"strength":0.7416,"sun_energy":1.041,"ambient_energy":1.3539,"exposure":1.0896}}
const CLOUD := 0.14
const DECK := Vector2(20.0,12.0)
## The plate: faceted grass, CELL m triangles, MARGIN round the pieces, its
## rock sides DEPTH deep.
const GRASS := [Color("54683f"),Color("52663c"),Color("566b41"),Color("50643b")]
const ROCK := Color("4d4640")
const CELL := 2.2
const MARGIN := 3.5
const DEPTH := 4.0
## How far round from the light the layout is turned (radians): the sun over
## the viewer's left shoulder, the fronts lit at a slant so their sides read.
const SIDE := 0.55
const SHOWS := ["pairs","intact","weathered"]
const KEYS := [KEY_1,KEY_2,KEY_3,KEY_4,KEY_5,KEY_6,KEY_7,KEY_8,KEY_9,KEY_0,KEY_MINUS,KEY_EQUAL,KEY_BACKSLASH]
const FAMILY_KEYS := [KEY_F1,KEY_F2,KEY_F3]

## What the look pass reads off the scene it dresses (scripts/look_pass.gd).
var _environment: Environment
var _lighting: LandscapeLighting
var _display_fog: CanvasLayer = null
var _precipitation := {"ground_texture":null}
var _motion_time := 0.0

var _seed := 1
var _show := 0
var _night := false
var _frame := -1
var _slots: Array[Dictionary] = []
var _layout: Node3D
var _camera: Camera3D
var _celestial: RefCounted
var _look: Node
var _focus := Vector3.ZERO
var _focus_goal := Vector3.ZERO
var _yaw := 0.0
var _pitch := 0.42
var _distance := 60.0
var _distance_goal := 60.0
var _label: Label
var _capture := ""
var _pilots: Array[Node3D] = []
var _sun: DirectionalLight3D
var _layout_yaw := 0.0
var _bounds := Rect2()
## The family framed (its pieces numbered from 1) and each family's area:
## {origin (its node's place), bounds (in the layout's frame), centre (the
## centrepiece's frame: focus, distance, yaw, pitch)}.
var _family := "gothic"
var _areas := {}
var _centred := false
var _shafts := true
var _fog: FogVolume
## Fly mode: on, the plane's flight (a SkyPlane), its figure, the chase
## camera, the mouse's look and the barrel roll asked since the last step,
## the bumps so far.
var _flying := false
var _plane_flight
var _fly_figure
var _chase
var _fly_look := Vector2.ZERO
var _roll_asked := 0.0
## The last lean pressed and when (ms): pressed twice within the game's
## DOUBLE_TAP, a barrel roll (scripts/wanderer_eye.gd `_lean_tapped`).
var _tap_dir := 0.0
var _tap_at := -100000
var _bumps := 0
## The planes standing for scale in the long hall (hidden while flying it).
var _hall_planes: Array = []
## --fly[=seconds]: start flying (for a capture: on autopilot down the lane
## that many seconds, weaving a little).
var _fly_at := -1.0
var _autopilot := 0.0
## A lean the autopilot holds (for captures: --lean=-1..1).
var _autopilot_lean := 0.0
## The height it holds over the floor (--height=, m).
var _autopilot_height := 2.8
## The air the growth sways in: on (V), the gust fronts, the air's travel
## (m), the breeze, a strong front asked for at --gust seconds, and the
## sway sequence's frames (--frames, --frame-step).
var _wind := true
var _fronts: GustFronts
var _gust_distance := 0.0
var _breeze := 0.53
var _gust_at := -1.0
var _frames := 0
var _frame_step := 0.1
var _forced_delta := 0.0

func _ready() -> void:
	var start_piece := -1
	var start_centre := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--piece="): start_piece = int(arg.get_slice("=",1))-1
		elif arg.begins_with("--family="): _family = arg.get_slice("=",1)
		elif arg == "--centre": start_centre = true
		elif arg == "--no-shafts": _shafts = false
		elif arg.begins_with("--fly"): _fly_at = float(arg.get_slice("=",1)) if "=" in arg else 0.0
		elif arg.begins_with("--lean="): _autopilot_lean = float(arg.get_slice("=",1))
		elif arg.begins_with("--height="): _autopilot_height = float(arg.get_slice("=",1))
		elif arg == "--night": _night = true
		elif arg.begins_with("--show="): _show = maxi(0,SHOWS.find(arg.get_slice("=",1)))
		elif arg.begins_with("--seed="): _seed = int(arg.get_slice("=",1))
		elif arg.begins_with("--capture="): _capture = arg.get_slice("=",1)
		elif arg == "--still": _wind = false
		elif arg == "--no-vines": RuinGrowth.vines = false
		elif arg.begins_with("--gust="): _gust_at = float(arg.get_slice("=",1))
		elif arg.begins_with("--breeze="): _breeze = float(arg.get_slice("=",1))
		elif arg.begins_with("--frames="): _frames = int(arg.get_slice("=",1))
		elif arg.begins_with("--frame-step="): _frame_step = float(arg.get_slice("=",1))
		elif arg.begins_with("--stone="): _set_stone(arg.get_slice("=",1))
	_fronts = GustFronts.new()
	_set_wind(_wind)
	_build_world()
	_set_night(_night)
	_build_layout()
	if start_centre: _frame_centre()
	elif start_piece >= 0: _frame_piece(_family_slot(start_piece))
	elif Array(OS.get_cmdline_user_args()).any(func(a: String) -> bool: return a.begins_with("--family=")): _frame_family(_family)
	else: _frame_piece(-1)
	var eye := Vector3.INF
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--yaw="): _yaw = float(arg.get_slice("=",1))
		elif arg.begins_with("--pitch="): _pitch = float(arg.get_slice("=",1))
		elif arg.begins_with("--distance="): _distance_goal = float(arg.get_slice("=",1))
		elif arg.begins_with("--at="): eye = _vec(arg.get_slice("=",1))+_centre_origin(start_centre)
		elif arg.begins_with("--look="): _focus_goal = _vec(arg.get_slice("=",1))+_centre_origin(start_centre)
		# In the long hall's path space (x along its nave, z across).
		elif arg.begins_with("--hall-at="): eye = _hall_point(_vec(arg.get_slice("=",1)))
		elif arg.begins_with("--hall-look="): _focus_goal = _hall_point(_vec(arg.get_slice("=",1)))
	if eye != Vector3.INF:
		# The eye at `eye` looking at the focus: the orbit that puts it there.
		var off := eye-_focus_goal
		_distance_goal = off.length()
		_pitch = asin(clampf(off.y/maxf(_distance_goal,0.01),-1.0,1.0))
		_yaw = atan2(off.x,off.z)
	_distance = _distance_goal
	_focus = _focus_goal
	if _fly_at >= 0.0:
		_fly(true)
		# On autopilot past the capture, so the frame is taken mid-flight.
		_autopilot = _fly_at+2.0
	if not _capture.is_empty():
		await get_tree().create_timer(_fly_at if _fly_at > 0.0 else 4.0).timeout
		await RenderingServer.frame_post_draw
		if _frames <= 0:
			get_viewport().get_texture().get_image().save_png(_capture)
		else:
			# Each drawn frame steps the scene exactly --frame-step s, however
			# long the save takes; saved at half size.
			var stem := _capture.get_basename()
			_forced_delta = _frame_step
			for i in range(_frames):
				var image := get_viewport().get_texture().get_image()
				image.resize(image.get_width()/2,image.get_height()/2,Image.INTERPOLATE_BILINEAR)
				image.save_png("%s_%03d.png" % [stem,i])
				await RenderingServer.frame_post_draw
		get_tree().quit()

## Where the family's centrepiece stands (its middle on the ground), in
## the layout's frame; the origin unless `on`.
func _centre_origin(on: bool) -> Vector3:
	if not on or not _areas.has(_family): return Vector3.ZERO
	var rows: Array = ROW_Z[_family]
	return (_areas[_family].origin as Vector3)+Vector3(0.0,0.0,float(rows[0])-float(CENTRE_BACK[_family]))

## A point of the long hall's path space in the layout's frame.
func _hall_point(p: Vector3) -> Vector3:
	var scene: Node3D = _areas.hall.scene
	return (scene.get_parent() as Node3D).transform*(scene.transform*(scene.get_meta("path").point(p) as Vector3))

func _vec(text: String) -> Vector3:
	var p := text.split(",")
	return Vector3(float(p[0]),float(p[1]),float(p[2]))

func _build_world() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/scene.json"))
	_lighting = LandscapeLighting.new()
	add_child(_lighting)
	_lighting.setup(source)
	_environment = _lighting.environment
	for light in _lighting.lights: light.directional_shadow_max_distance = 120.0
	_sun = _lighting.lights[0]
	_celestial = Celestial.new()
	_celestial.setup(_lighting.lights)
	_celestial.cycling = false
	_celestial.cloud = CLOUD
	_celestial.look.restore(GAME_LOOK)
	# As the game does when its look changes (studies/fidelity.gd
	# `_update_scene_look`): the exposure follows the look's.
	var exposure: float = float(source.exposure)/1.08*float(_celestial.look.settings.exposure)
	_environment.tonemap_exposure = exposure
	RenderingServer.global_shader_parameter_set("zs_exposure",exposure)
	_look = LookPass.new()
	_look.setup(self)
	_look.apply_tier(_look.tier)
	preload("res://scripts/render_resolution.gd").attach(get_viewport())
	_camera = Camera3D.new()
	_camera.fov = 40.0
	_camera.near = 0.1
	_camera.far = 4000.0
	add_child(_camera)
	_camera.make_current()
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(24.0,18.0)
	_label.add_theme_font_size_override("font_size",20)
	_label.add_theme_color_override("font_color",Color(1.0,0.98,0.92,0.85))
	_label.add_theme_color_override("font_shadow_color",Color(0.0,0.0,0.0,0.4))
	layer.add_child(_label)
	var help := Label.new()
	help.text = "F1 Gothic · F2 Aqueduct · F3 Hall · 1-9 0 - = \\ frame a piece · C centrepiece · G fly the long hall · ←/→ next · Space/Tab whole layout · W intact/weathered · T stone look · R reseed · N night · L shafts · V wind on/off · B gust · Drag orbit · Wheel zoom"
	help.add_theme_font_size_override("font_size",15)
	help.add_theme_color_override("font_color",Color(1.0,0.98,0.92,0.5))
	help.add_theme_color_override("font_shadow_color",Color(0.0,0.0,0.0,0.3))
	help.anchor_top = 1.0
	help.anchor_bottom = 1.0
	help.position = Vector2(24.0,-34.0)
	layer.add_child(help)

## The layout: each family's pairs in their rows and its centrepiece behind
## them, side by side on the plate; the labels, the plate under them all,
## the scale figures.
func _build_layout() -> void:
	if _layout != null: _layout.free()
	_layout = Node3D.new()
	_layout.name = "Layout"
	_layout.rotation.y = _layout_yaw
	add_child(_layout)
	_slots.clear()
	_pilots.clear()
	_areas.clear()
	var cursor := 0.0
	for f in range(ORDER.size()):
		var family: String = ORDER[f]
		var area := Node3D.new()
		area.name = family.capitalize()
		_layout.add_child(area)
		var local := _build_family(area,family)
		area.position.x = cursor-local.position.x
		cursor += local.size.x+FAMILY_GAP
		_areas[family].local = local
	# The gothic family stays round the layout's middle, as it was.
	var gothic: Rect2 = _areas.gothic.local
	var shift: float = -(float(_layout.get_node("Gothic").position.x)+gothic.get_center().x)
	var bounds := Rect2()
	for f in range(ORDER.size()):
		var family: String = ORDER[f]
		var area: Node3D = _layout.get_node(family.capitalize())
		area.position.x += shift
		var local: Rect2 = _areas[family].local
		var placed := Rect2(local.position+Vector2(area.position.x,0.0),local.size)
		_areas[family].origin = area.position
		_areas[family].bounds = placed
		bounds = placed if f == 0 else bounds.merge(placed)
	_slots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.index < b.index)
	_bounds = bounds.grow(MARGIN)
	_plate(_bounds)
	_figures()
	_shaft_fog()
	_apply_show()

## One family's pairs in their rows round its own origin, its centrepiece
## behind; gives back its extent (x, z).
func _build_family(area: Node3D, family: String) -> Rect2:
	var index := {}
	for i in range(RuinKit.ALL_PIECES.size()): index[RuinKit.ALL_PIECES[i]] = i
	var bounds := Rect2()
	var first := true
	var rows: Array = ROWS[family]
	var row_z: Array = ROW_Z[family]
	for r in range(rows.size()):
		var row: Array = rows[r]
		var built: Array = []
		var width := 0.0
		for id: String in row:
			var pair: Array = []
			var spans: Array = []
			for k in range(2):
				var node := _piece(id,int(index[id]),float(k))
				var box := _extent(node)
				pair.append(node)
				spans.append(box)
			var slot_w: float = spans[0].size.x+spans[1].size.x+PAIR_GAP
			built.append([id,pair,spans,slot_w])
			width += slot_w
		width += SLOT_GAP*(row.size()-1)
		var x := -width*0.5
		for entry: Array in built:
			var id: String = entry[0]
			var pair: Array = entry[1]
			var spans: Array = entry[2]
			var slot := {"id":id,"index":int(index[id]),"family":family,"area":area,"pieces":pair,"x":x+float(entry[3])*0.5,"z":float(row_z[r]),"width":float(entry[3]),"spans":spans,"homes":[]}
			var at := x
			for k in range(2):
				var node: Node3D = pair[k]
				var box: AABB = spans[k]
				var home := Vector3(at-box.position.x,0.0,float(row_z[r]))
				node.position = home
				slot.homes.append(home)
				area.add_child(node)
				var foot := Rect2(Vector2(home.x+box.position.x,home.z+box.position.z),Vector2(box.size.x,box.size.z))
				bounds = foot if first else bounds.merge(foot)
				first = false
				_tag(area,"intact" if k == 0 else "weathered",Vector3(home.x,0.02,home.z+box.end.z+0.5),0.5)
				at += box.size.x+PAIR_GAP
			var front := maxf((spans[0] as AABB).end.z,(spans[1] as AABB).end.z)
			_tag(area,"%d  %s" % [(RuinKit.FAMILIES[family] as Array).find(id)+1,RuinKit.NAMES[id]],Vector3(slot.x,0.02,float(row_z[r])+front+1.2),1.0)
			_slots.append(slot)
			x += float(entry[3])+SLOT_GAP
	_areas[family] = {"origin":Vector3.ZERO,"bounds":Rect2(),"local":Rect2(),"centre":{}}
	var back: float = float(row_z[0])-float(CENTRE_BACK[family])
	var extra := Rect2()
	match family:
		"aqueduct":
			extra = _aqueduct_run(area,back)
			extra = extra.merge(_valley(area,back-36.0))
		"hall": extra = _hall_scene(area,back)
	if extra.has_area(): bounds = bounds.merge(extra)
	return bounds

## The aqueduct's centrepiece: a run over a strip of water standing for the
## sea between two islands, its head on the left, the third span broken and
## spilling, the last dry, two stumps going on as stepping stones; at `z`.
func _aqueduct_run(area: Node3D, z: float) -> Rect2:
	var run := Aqueduct.run(_seed*31+5,RUN_WEATHERED,RUN_SPANS,RUN_BREAK)
	var length := Aqueduct.SPAN*RUN_SPANS
	var x0 := -length*0.5
	run.position = Vector3(x0,0.0,z)
	area.add_child(run)
	_areas.aqueduct.run = run
	var stumps: Array[Vector3] = [Vector3(length+3.6,0.0,0.6),Vector3(length+7.4,0.0,-0.9)]
	for k in range(stumps.size()):
		var stump := Aqueduct.stump(_seed*31+40+k,0.4+0.3*k)
		stump.position = run.position+stumps[k]
		stump.rotation.y = 0.3*(k*2-1)
		area.add_child(stump)
	var sea := Rect2(x0-2.0,z-SEA_HALF,length+13.0,SEA_HALF*2.0)
	_sea(area,sea)
	_tag(area,"The aqueduct run: its head, four spans, one broken",Vector3(0.0,0.02,z+SEA_HALF+1.0),1.0)
	_areas.aqueduct.centre = {"focus":Vector3(x0+length*0.4,5.0,z),"distance":40.0,"yaw":0.55,"pitch":0.12}
	return Rect2(x0-10.5,z-SEA_HALF,length+24.0,SEA_HALF*2.0+2.0)

## A strip of still water on the plate (the sea between islands, here):
## the aqueduct's pond water.
func _sea(area: Node3D, rect: Rect2) -> void:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := [Vector3(rect.position.x,0.05,rect.position.y),Vector3(rect.end.x,0.05,rect.position.y),Vector3(rect.end.x,0.05,rect.end.y),Vector3(rect.position.x,0.05,rect.end.y)]
	for t: Array in [[c[0],c[1],c[2]],[c[0],c[2],c[3]]]:
		for p: Vector3 in t:
			v.append(p)
			n.append(Vector3.UP)
	var holder := Node3D.new()
	holder.name = "Sea"
	area.add_child(holder)
	Aqueduct._sheet(holder,v,n,"Water")

## The hall's centrepiece: a long hall of HALL_BAYS bays along X, centred,
## at `z`; behind it, a shorter hall run into a hillside.
func _hall_scene(area: Node3D, z: float) -> Rect2:
	var scene := Hall.hall(_seed*17+3,HALL_WEATHERED,HALL_BAYS,Callable(),true,HALL_LAYOUT)
	var box: AABB = scene.get_meta("bounds")
	# The aqueduct that feeds it, chained on at its first mouth: the run's
	# channel end (its "ends"[1]) set just short of the hall's ("ends"[0]).
	var feed := Aqueduct.run(_seed*31+9,0.5,FEED_SPANS,-1)
	var mouth: Vector3 = (scene.get_meta("ends") as Array)[0].at
	var channel: Vector3 = (feed.get_meta("ends") as Array)[1].at
	var feed_at := Vector3(mouth.x-1.2-channel.x,0.0,mouth.z)
	var reach := -feed_at.x+Aqueduct.SPAN
	# The whole, centred on the plate: the feed's head on the left.
	var x0 := -(box.position.x-reach+box.end.x)*0.5
	# Its front where a straight hall's stood (the pieces' rows before it).
	var z0 := z+Hall.WALL_Z+1.0-box.end.z
	scene.position = Vector3(x0,0.0,z0)
	area.add_child(scene)
	feed.position = scene.position+feed_at
	area.add_child(feed)
	_areas.hall.scene = scene
	_areas.hall.feed = feed
	_tag(area,"The long hall: %d bays, curving, its roof whole, broken and open, fed by an aqueduct (G flies it)" % HALL_BAYS,Vector3(0.0,0.02,z0+box.end.z+14.0),1.4)
	_areas.hall.centre = {"focus":Vector3(0.0,4.0,z),"distance":150.0,"yaw":0.35,"pitch":0.55}
	var rect := Rect2(x0+box.position.x-reach-6.0,z0+box.position.z-6.0,box.size.x+reach+12.0,box.size.z+12.0)
	# The hall in the hillside, its far end buried in the slope.
	var hz := rect.position.y-Hall.WALL_Z-26.0
	var bays := 5
	var hill_length := Hall.BAY*bays
	var hill := func(x: float, zz: float) -> float: return clampf((x-hill_length*0.5)*0.55+0.02*absf(zz)*maxf(0.0,x-hill_length*0.5),0.0,Hall.ROOF_TOP+1.5)
	var buried := Hall.hall(_seed*17+11,0.6,bays,hill)
	buried.position = Vector3(-hill_length*0.5,0.0,hz)
	area.add_child(buried)
	_areas.hall.hill = buried
	var ground_rect := Rect2(-8.0,-Hall.WALL_Z-24.0,hill_length+40.0,Hall.WALL_Z*2.0+48.0)
	_terrain(buried,ground_rect,hill,TERRAIN_FADE)
	_tag(area,"A hall run into a hillside",Vector3(0.0,0.02,hz+Hall.WALL_Z+9.0),1.0)
	return rect.merge(Rect2(ground_rect.position+Vector2(-hill_length*0.5,hz),ground_rect.size))

## The aqueduct over a valley: a run of VALLEY_SPANS spans from its head,
## butted into the hill at the left, across to the hill at the right, its
## piers tall in the valley's middle and short up its sides; at `z`.
func _valley(area: Node3D, z: float) -> Rect2:
	var length := Aqueduct.SPAN*VALLEY_SPANS
	var deck := Aqueduct.DECK-Aqueduct.FLOOR
	var valley := func(x: float, zz: float) -> float:
		var t := x/length
		var sides := deck*0.92*(1.0-smoothstep(0.0,0.36,t))+deck*0.9*smoothstep(0.66,1.0,t)
		if x < 0.0: sides = deck+0.4+minf(-x*0.05,1.0)
		return maxf(0.0,sides+0.06*zz*(1.0 if t < 0.5 else -1.0))
	var run := Aqueduct.run(_seed*31+77,0.45,VALLEY_SPANS,-1,true,valley)
	run.position = Vector3(-length*0.5,0.0,z)
	area.add_child(run)
	_areas.aqueduct.valley = run
	var ground_rect := Rect2(-22.0,-24.0,length+38.0,48.0)
	_terrain(run,ground_rect,valley,TERRAIN_FADE)
	_tag(area,"Across a valley: tall piers in its middle, its head in the hill",Vector3(0.0,0.02,z+13.5),1.0)
	return Rect2(ground_rect.position+Vector2(-length*0.5,z),ground_rect.size)

## A simple faceted ground under `parent` (in its frame) over `rect` (x, z)
## from `ground`: grass on the gentle facets, rock on the steep; within
## `fade` of the rim it slopes down to the plate in rough facets (a hill,
## not a block).
func _terrain(parent: Node3D, rect: Rect2, ground: Callable, fade := 0.0) -> void:
	var step := 2.0
	var nx := int(ceil(rect.size.x/step))
	var nz := int(ceil(rect.size.y/step))
	var rng := RandomNumberGenerator.new()
	rng.seed = 911
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var at := func(i: int, j: int) -> Vector3:
		var x := rect.position.x+i*rect.size.x/nx
		var zz := rect.position.y+j*rect.size.y/nz
		var edge := i == 0 or j == 0 or i == nx or j == nz
		var y := float(ground.call(x,zz))
		if fade > 0.0:
			var rim := minf(minf(x-rect.position.x,rect.end.x-x),minf(zz-rect.position.y,rect.end.y-zz))
			var t := clampf(rim/fade,0.0,1.0)
			# Rough facets on the slope: each vertex a little off it.
			var rough := sin(float(i)*12.9898+float(j)*78.233)*43758.5453
			y = y*t*t*(3.0-2.0*t)+(rough-floorf(rough)-0.5)*0.9*t*(1.0-t)*minf(y,6.0)
		return Vector3(x,y-(0.15 if edge else 0.0)+0.02,zz)
	for i in range(nx):
		for j in range(nz):
			var a: Vector3 = at.call(i,j)
			var b: Vector3 = at.call(i+1,j)
			var d: Vector3 = at.call(i,j+1)
			var e: Vector3 = at.call(i+1,j+1)
			for t: Array in [[a,d,b],[b,d,e]]:
				var p0: Vector3 = t[0]
				var p1: Vector3 = t[1]
				var p2: Vector3 = t[2]
				var normal := (p1-p0).cross(p2-p0).normalized()
				if normal.y < 0.0:
					normal = -normal
					var swap := p1
					p1 = p2
					p2 = swap
				var tone: Color = GRASS[rng.randi()%GRASS.size()]*rng.randf_range(0.92,1.06)
				if normal.y < 0.8: tone = tone.lerp(ROCK,smoothstep(0.8,0.55,normal.y))
				for p: Vector3 in [p0,p2,p1]:
					v.append(p)
					n.append(normal)
					c.append(tone.srgb_to_linear())
	# Its sides: rock faces down to the plate round the rim.
	var rim: Array[Vector3] = []
	for i in range(nx): rim.append(at.call(i,0))
	for j in range(nz): rim.append(at.call(nx,j))
	for i in range(nx,0,-1): rim.append(at.call(i,nz))
	for j in range(nz,0,-1): rim.append(at.call(0,j))
	var middle := Vector3(rect.get_center().x,0.0,rect.get_center().y)
	for k in range(rim.size()):
		var p0: Vector3 = rim[k]
		var p1: Vector3 = rim[(k+1)%rim.size()]
		if p0.y < 0.05 and p1.y < 0.05: continue
		var q0 := Vector3(p0.x,-0.1,p0.z)
		var q1 := Vector3(p1.x,-0.1,p1.z)
		var out := ((p0+p1)*0.5-middle)*Vector3(1.0,0.0,1.0)
		for t: Array in [[p0,q0,p1],[p1,q0,q1]]:
			var a0: Vector3 = t[0]
			var a1: Vector3 = t[1]
			var a2: Vector3 = t[2]
			var normal := (a1-a0).cross(a2-a0).normalized()
			if normal.dot(out) < 0.0:
				normal = -normal
				var swap := a1
				a1 = a2
				a2 = swap
			for p: Vector3 in [a0,a2,a1]:
				v.append(p)
				n.append(normal)
				c.append((ROCK*rng.randf_range(0.85,1.1)).srgb_to_linear())
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_COLOR] = c
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var ground_node := MeshInstance3D.new()
	ground_node.name = "Ground"
	ground_node.mesh = mesh
	ground_node.material_override = RuinKit.materials().stone
	parent.add_child(ground_node)

## The shafts: Godot's volumetric fog, thin and tight, filling only the
## long hall's inside (so the air round it stays clear and the inside
## stays dark where the sun does not reach), and the sun lighting it, so
## its beams come down crisp through the roof's gaps and the lancets (as
## scripts/redwood_biome_mist.gd's rays in the woods). No ambient light in
## the fog: unlit air is dark.
func _shaft_fog() -> void:
	_fog = FogVolume.new()
	_fog.name = "HallFog"
	var material := FogMaterial.new()
	material.density = SHAFT_FOG
	material.albedo = Color(0.95,0.92,0.86)
	material.edge_fade = 0.05
	var scene: Node3D = _areas.hall.scene
	var path = scene.get_meta("path")
	var plans: Array = scene.get_meta("plans")
	scene.add_child(_fog)
	# A box a bay under each roof (none under the open sky: no haze there),
	# turned along the hall's path.
	for i in range(plans.size()):
		if plans[i].roof == "open": continue
		var box := FogVolume.new()
		box.material = material
		box.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
		box.size = Vector3(Hall.BAY+0.05,Hall.COLUMN_H+0.9,(Hall.WALL_Z-Hall.WALL_THICK*0.5)*2.0-0.4)
		var frame: Transform3D = path.xform(Hall.BAY*(i+0.5))
		box.transform = Transform3D(frame.basis,frame.origin+Vector3.UP*box.size.y*0.5)
		_fog.add_child(box)
	_set_shafts(_shafts)

func _set_shafts(on: bool) -> void:
	_shafts = on
	_environment.volumetric_fog_enabled = on
	_environment.volumetric_fog_density = 0.0
	_environment.volumetric_fog_length = 120.0
	_environment.volumetric_fog_detail_spread = 1.5
	_environment.volumetric_fog_anisotropy = 0.72
	_environment.volumetric_fog_ambient_inject = 0.0
	_sun.light_volumetric_fog_energy = SHAFT_LIGHT if on else 0.0
	if _fog != null: _fog.visible = on
	_say()

## A piece as the gallery shows it.
func _piece(id: String, index: int, weathered: float) -> Node3D:
	var seed_value := _seed*101+index
	return RuinKit.piece(id,seed_value,weathered)

## A piece's extent, its rubble's far strays left out (the stone near its
## middle).
func _extent(node: Node3D) -> AABB:
	var mesh := (node.get_node("Mesh") as MeshInstance3D).mesh
	var box := mesh.get_aabb()
	var shape_box := AABB()
	var first := true
	for holder in node.get_node("Body").get_children():
		var shape := (holder as CollisionShape3D).shape as ConvexPolygonShape3D
		for p in shape.points:
			if first:
				shape_box = AABB(p,Vector3.ZERO)
				first = false
			else: shape_box = shape_box.expand(p)
	if first: return box
	# The body without far rubble: the hulls' box, which the scatter (not
	# solid) never widens.
	return shape_box.grow(0.3)

func _tag(parent: Node3D, text: String, at: Vector3, size: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 64
	label.pixel_size = 0.007*size
	label.position = at+Vector3(0.0,0.3*size,0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	label.modulate = Color(1.0,0.97,0.88,0.85 if size >= 1.0 else 0.6)
	label.outline_size = 12
	label.outline_modulate = Color(0.08,0.1,0.06,0.45)
	parent.add_child(label)

## The plate: faceted grass a touch uneven, triangle by triangle, under the
## pieces; dark rock sides hanging under it, so it floats as an islet does.
func _plate(rect: Rect2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	var nx := int(ceil(rect.size.x/CELL))
	var nz := int(ceil(rect.size.y/CELL))
	var heights := {}
	for i in range(nx+1):
		for j in range(nz+1):
			var edge := i == 0 or j == 0 or i == nx or j == nz
			heights[Vector2i(i,j)] = -0.12 if edge else rng.randf_range(-0.07,-0.015)
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var at := func(i: int, j: int) -> Vector3:
		return Vector3(rect.position.x+i*rect.size.x/nx,heights[Vector2i(i,j)],rect.position.y+j*rect.size.y/nz)
	# Each triangle wound to face `toward` (front faces are clockwise).
	var add := func(t: Array, colour: Color, toward: Vector3) -> void:
		var p0: Vector3 = t[0]
		var p1: Vector3 = t[1]
		var p2: Vector3 = t[2]
		if (p1-p0).cross(p2-p0).dot(toward) > 0.0:
			var swap := p1
			p1 = p2
			p2 = swap
		var normal := (p2-p0).cross(p1-p0).normalized()
		for p: Vector3 in [p0,p1,p2]:
			v.append(p)
			n.append(normal)
			c.append(colour.srgb_to_linear())
	for i in range(nx):
		for j in range(nz):
			var a: Vector3 = at.call(i,j)
			var b: Vector3 = at.call(i+1,j)
			var d: Vector3 = at.call(i,j+1)
			var e: Vector3 = at.call(i+1,j+1)
			for t: Array in [[a,b,d],[b,e,d]]:
				var tone: Color = GRASS[rng.randi()%GRASS.size()]*rng.randf_range(0.92,1.06)
				add.call(t,tone,Vector3.UP)
	# The sides: the rim's points dropped, jagged, toward a keel.
	var rim: Array[Vector3] = []
	for i in range(nx): rim.append(at.call(i,0))
	for j in range(nz): rim.append(at.call(nx,j))
	for i in range(nx,0,-1): rim.append(at.call(i,nz))
	for j in range(nz,0,-1): rim.append(at.call(0,j))
	var centre := Vector3(rect.get_center().x,0.0,rect.get_center().y)
	var keel := Vector3(centre.x,-DEPTH*3.0,centre.z)
	var drops: Array[Vector3] = []
	for p: Vector3 in rim: drops.append(p.lerp(Vector3(centre.x,0.0,centre.z),rng.randf_range(0.06,0.16))+Vector3(0.0,-DEPTH*rng.randf_range(0.7,1.3),0.0))
	for k in range(rim.size()):
		var k1 := (k+1)%rim.size()
		var p0: Vector3 = rim[k]
		var p1: Vector3 = rim[k1]
		var q0: Vector3 = drops[k]
		var q1: Vector3 = drops[k1]
		var tone := ROCK*rng.randf_range(0.85,1.12)
		var out := ((p0+p1)*0.5-centre)*Vector3(1.0,0.0,1.0)
		add.call([p0,q0,p1],tone,out)
		add.call([p1,q0,q1],tone*0.95,out)
		add.call([q0,keel,q1],tone*0.8,out+Vector3.DOWN*out.length())
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_COLOR] = c
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var plate := MeshInstance3D.new()
	plate.name = "Plate"
	plate.mesh = mesh
	plate.material_override = RuinKit.materials().stone
	_layout.add_child(plate)


## The pilot by the pier, on the wall's head, at the stair's foot, on the
## buttress's first set-off and in the weathered window's sill; the plane
## in the pointed arch. On the aqueduct: the pilot walking the channel and
## on a stump, the plane threading an arch of the run. In the hall: the
## pilot by a column's foot and on the medallion, the plane flying through
## under the roof and a second one knife-edged in the back wall's slit.
func _figures() -> void:
	var slot := func(id: String) -> Dictionary:
		for s in _slots:
			if s.id == id: return s
		return {}
	var pier: Dictionary = slot.call("pier")
	_pilot(pier,0,Vector3(0.95,RuinKit.SUB_BASE.x,0.45),0.4)
	var wall: Dictionary = slot.call("wall")
	_pilot(wall,0,Vector3(0.9,RuinKit.WALL_HEIGHT,0.0),-0.3)
	var stairs: Dictionary = slot.call("stairs")
	_pilot(stairs,0,Vector3(0.3,0.0,3.2),0.2)
	var buttress: Dictionary = slot.call("buttress")
	_pilot(buttress,0,Vector3(1.9,RuinKit.SET_OFF,0.0),0.0)
	var window: Dictionary = slot.call("lancet_wall")
	_pilot(window,1,Vector3(-0.6,RuinKit.WINDOW.y,0.15),0.5)
	var arch: Dictionary = slot.call("arch")
	_plane(arch.pieces[0],Vector3(0.0,2.6,0.6),Vector3(0.0,0.35,-0.1))
	# The aqueduct: on the span's channel, by the stump's foot, on its top;
	# the plane through the run's first arch.
	var span: Dictionary = slot.call("aqueduct_span")
	_pilot(span,0,Vector3(-1.2,Aqueduct.DECK,0.0),-1.2)
	var stump: Dictionary = slot.call("aqueduct_stump")
	_pilot(stump,0,Vector3(0.2,float((stump.pieces[0] as Node3D).get_meta("height")),0.1),0.3)
	_pilot(stump,1,Vector3(1.4,0.0,1.6),-0.4)
	var run: Node3D = _areas.aqueduct.run
	_plane(run,Vector3(Aqueduct.SPAN*1.5,3.4,0.8),Vector3(0.0,0.35,0.12))
	var walker := PilotFigure.new()
	run.add_child(walker)
	walker.position = Vector3(Aqueduct.SPAN*0.7,Aqueduct.DECK,0.0)
	walker.rotation.y = PI*0.5
	walker.settle()
	_pilots.append(walker)
	# The hall: the pilot at a column's foot, and in the long hall on the
	# nave's floor and up on a low tie; the plane cruising down the lane, a
	# second on a knife edge in a screen's slit.
	var column: Dictionary = slot.call("hall_column")
	_pilot(column,0,Vector3(2.0,0.0,1.4),0.5)
	var scene: Node3D = _areas.hall.scene
	var weave: Dictionary = scene.get_meta("weave")
	var floor_pilot := PilotFigure.new()
	scene.add_child(floor_pilot)
	floor_pilot.position = Vector3(Hall.BAY*1.5,0.0,2.0)
	floor_pilot.rotation.y = 0.6
	floor_pilot.settle()
	_pilots.append(floor_pilot)
	if not (weave.low_ties as Array).is_empty():
		var tie: Vector3 = weave.low_ties[0]
		var up := PilotFigure.new()
		scene.add_child(up)
		var path = scene.get_meta("path")
		up.position = path.point(Vector3(tie.x,Hall.TIE_LOW+Hall.TIE_DEPTH,-5.0))
		up.rotation.y = 1.2+atan2(-(path.tangent(tie.x) as Vector3).z,(path.tangent(tie.x) as Vector3).x)
		up.settle()
		_pilots.append(up)
	# Heading +X: SkyGlide's forward is (-sin h, 0, -cos h), so h -PI/2.
	_hall_planes = [_plane(scene,Vector3(Hall.BAY*2.4,2.6,6.0),Vector3(0.0,-PI*0.5+0.12,0.3))]
	# (The slit's plane only on the first straight stretch: path space is the
	# hall's frame there.)
	if scene.has_meta("slit") and (scene.get_meta("slit") as Vector3).x < Hall.BAY*float(HALL_LAYOUT[0].bays):
		var slit: Vector3 = scene.get_meta("slit")
		_hall_planes.append(_plane(scene,slit+Vector3(0.6,0.0,0.0),Vector3(0.0,-PI*0.5,PI*0.5)))

func _plane(parent: Node3D, at: Vector3, turn: Vector3) -> Node3D:
	var plane := PlaneFigure.new()
	plane.name = "Plane"
	parent.add_child(plane)
	plane.position = at
	plane.rotation = turn
	plane.show_pilot(true)
	plane._mark.visible = false
	plane._vapour.visible = false
	return plane

func _pilot(slot: Dictionary, k: int, at: Vector3, turn: float) -> void:
	var pilot := PilotFigure.new()
	(slot.pieces[k] as Node3D).add_child(pilot)
	pilot.position = at
	pilot.rotation.y = turn
	pilot.settle()
	_pilots.append(pilot)

## Which of each pair shows (W): both, or one alone standing in its pair's
## middle.
func _apply_show() -> void:
	for slot in _slots:
		for k in range(2):
			var node: Node3D = slot.pieces[k]
			var shown: bool = _show == 0 or _show-1 == k
			# Framing one piece, the rows in front of it in its family stand
			# aside.
			if _frame >= 0 and slot.family == _slots[_frame].family and float(slot.z) > float(_slots[_frame].z)+0.5: shown = false
			# Framing a centrepiece, its family's pairs (in front of it) too.
			if _centred and slot.family == _family: shown = false
			node.visible = shown
			node.process_mode = Node.PROCESS_MODE_INHERIT if shown else Node.PROCESS_MODE_DISABLED
			var home: Vector3 = slot.homes[k]
			if _show != 0:
				var box: AABB = slot.spans[k]
				home.x = float(slot.x)-box.position.x-box.size.x*0.5
			node.position = home
	_say()

## The slot of the `n`th piece (from 0) of the family framed.
func _family_slot(n: int) -> int:
	var ids: Array = RuinKit.FAMILIES[_family]
	if n < 0 or n >= ids.size(): return -1
	for i in range(_slots.size()):
		if _slots[i].id == ids[n]: return i
	return -1

func _frame_piece(index: int) -> void:
	_frame = index
	_centred = false
	if index < 0 or index >= _slots.size():
		_frame = -1
		_focus_goal = Vector3(_bounds.get_center().x,2.2,_bounds.get_center().y+1.5)
		_distance_goal = maxf(_bounds.size.x*0.92,_bounds.size.y*1.6)
		_pitch = 0.75
		_yaw = 0.0
	else:
		var slot := _slots[index]
		_family = slot.family
		var spans: Array = slot.spans
		var tall := maxf((spans[0] as AABB).size.y,(spans[1] as AABB).size.y)
		var across: float = slot.width if _show == 0 else (spans[_show-1] as AABB).size.x
		var origin: Vector3 = _areas[slot.family].origin
		_focus_goal = origin+Vector3(slot.x,minf(tall*0.42,4.5),slot.z)
		_distance_goal = maxf(across*1.25,tall*1.9)+3.0
		_pitch = 0.3
		_yaw = 0.0
	if not _slots.is_empty(): _apply_show()

## Frames a whole family: its rows and its centrepiece behind.
func _frame_family(family: String) -> void:
	_family = family
	_frame = -1
	_centred = false
	var r: Rect2 = _areas[family].bounds
	_focus_goal = Vector3(r.get_center().x,3.0,r.get_center().y+2.0)
	_distance_goal = maxf(r.size.x*0.95,r.size.y*1.3)
	_pitch = 0.42
	_yaw = 0.0
	_apply_show()

## Frames the family's centrepiece: the aqueduct's run, the hall (the
## gothic family has none: its whole layout).
func _frame_centre() -> void:
	var centre: Dictionary = _areas.get(_family,{}).get("centre",{})
	if centre.is_empty():
		_frame_family(_family)
		return
	_frame = -1
	_centred = true
	_focus_goal = (_areas[_family].origin as Vector3)+(centre.focus as Vector3)
	_distance_goal = float(centre.distance)
	_yaw = float(centre.yaw)
	_pitch = float(centre.pitch)
	_apply_show()

func _say() -> void:
	if _label == null: return
	var what := "The ruin kit" if _frame < 0 else "%s %d · %s" % [FAMILY_NAMES[_slots[_frame].family],(RuinKit.FAMILIES[_slots[_frame].family] as Array).find(_slots[_frame].id)+1,RuinKit.NAMES[_slots[_frame].id]]
	if _frame < 0 and _focus_goal != Vector3.ZERO and _areas.has(_family) and (_centred or _distance_goal < _bounds.size.x*0.5):
		what = FAMILY_NAMES[_family]+(" · centrepiece" if _centred else "")
	var keys := "F1 Gothic · F2 Aqueduct · F3 Hall · G fly the long hall"
	if _flying:
		_label.text = "Flying the long hall   ·   %.0f m/s   ·   bumps %d   ·   shafts %s\nA D bank and turn · W S pitch (W nose down) · mouse steers · Space boost · Shift brake · hold Q E or LB RB knife-edge, twice quick or click barrel roll · hold right mouse to look round · R or pad Back restart at the entrance · L shafts · N night · V wind · B gust · G or Esc to stop flying" % [float(_plane_flight.speed),_bumps,"on" if _shafts else "off"]
		return
	_label.text = "%s   ·   %s   ·   %s   ·   %s (T)   ·   shafts %s   ·   growth %s   ·   seed %d\n%s" % [what,SHOWS[_show],"night" if _night else "day",StoneStyle.NAMES[StoneStyle.current],"on" if _shafts else "off","in the wind" if _wind else "still",_seed,keys]

## Builds in stone look `id` from now on (scripts/ruin_stone_style.gd).
func _set_stone(id: String) -> void:
	StoneStyle.use(id)
	StoneStyle.dress(RuinKit.materials().stone)

func _set_night(on: bool) -> void:
	_night = on
	_celestial.set_phase(NIGHT if on else DAY)
	_face_sun()
	_say()

## Turns the layout so the sun (by night the moon) comes from over the
## viewer's left shoulder onto the pieces' fronts (+Z); the camera orbits in
## the layout's frame.
func _face_sun() -> void:
	var toward: Vector3 = _sun.global_basis.z
	var flat := Vector2(toward.x,toward.z)
	if flat.length() < 0.01: return
	_layout_yaw = atan2(flat.x,flat.y)-SIDE
	if _layout != null: _layout.rotation.y = _layout_yaw

func _process(delta: float) -> void:
	if _forced_delta > 0.0: delta = _forced_delta
	_motion_time += delta
	_celestial.advance(delta,true)
	for pilot in _pilots:
		if pilot.is_visible_in_tree(): pilot._advance(delta)
	if _flying:
		_fly_step(minf(delta,0.05))
		if Engine.get_process_frames()%15 == 0: _say()
	else:
		var ease := minf(1.0,delta*4.0)
		_focus = _focus.lerp(_focus_goal,ease)
		_distance = lerpf(_distance,_distance_goal,ease)
		var frame := Transform3D(Basis(Vector3.UP,_layout_yaw),Vector3.ZERO)
		_camera.position = frame*(_focus+Vector3(sin(_yaw)*cos(_pitch),sin(_pitch),cos(_yaw)*cos(_pitch))*_distance)
		_camera.look_at(frame*_focus)
	RenderingServer.global_shader_parameter_set("zs_camera_position",_camera.global_position)
	RenderingServer.global_shader_parameter_set("zs_motion_time",_motion_time)
	# The channel's water ripples and the spill runs on the scene's clock.
	RenderingServer.global_shader_parameter_set("zs_flow_time",_motion_time)
	_look.update(_camera,_celestial)
	RenderingServer.global_shader_parameter_set("zs_cloud",Vector4(_celestial.cloud,0.0,DECK.x,DECK.y))
	_advance_air(delta)

## The game's air for the growth (as studies/atmosphere.gd runs it): the
## air's travel, the gust fronts rolling across the view, the breeze going
## quiet before a front; the plane brushing the curtains it passes.
func _advance_air(delta: float) -> void:
	var way := _wind_way()
	var speed := 1.6+1.9*0.4
	_gust_distance += speed*delta
	var focus := _camera.global_position
	_fronts.set_bounds(Vector2(focus.x,focus.z),36.0)
	_fronts.advance(delta,way,0.4,_breeze)
	if _gust_at >= 0.0 and _motion_time >= _gust_at:
		_gust_at = -1.0
		_send_gust()
	_fronts.publish()
	RenderingServer.global_shader_parameter_set("zs_gust_distance",_gust_distance)
	RenderingServer.global_shader_parameter_set("zs_gust_speed",speed)
	RenderingServer.global_shader_parameter_set("zs_breeze",_breeze*_fronts.lull())
	if _flying and _fly_figure != null: RuinGrowthPush.stir(&"plane",(_fly_figure as Node3D).global_position,delta)
	else: RuinGrowthPush.settle(delta)

## A strong gust front now, across what the camera looks at (B).
func _send_gust() -> void:
	var way := _wind_way()
	var focus := _camera.global_position+(-_camera.global_basis.z)*20.0
	_fronts.set_bounds(Vector2(focus.x,focus.z),24.0)
	for i in range(_fronts.fronts.size()): _fronts.fronts[i] = {}
	_fronts.send(way,0.9,_breeze,1.0)

## The world's wind direction (the project's shader global).
func _wind_way() -> Vector2:
	var setting: Variant = ProjectSettings.get_setting("shader_globals/zs_wind_direction")
	if setting is Dictionary and (setting as Dictionary).get("value") is Vector2: return ((setting as Dictionary).value as Vector2).normalized()
	return Vector2(0.943858,0.33035)

## The growth in the wind or held still (V).
func _set_wind(on: bool) -> void:
	_wind = on
	RuinGrowth.material().set_shader_parameter("motion",1.0 if on else 0.0)
	if _label != null: _say()

func _unhandled_input(event: InputEvent) -> void:
	if _flying:
		if event is InputEventMouseMotion:
			_fly_look += Vector2(event.relative.x,-event.relative.y)*FLY_LOOK
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
			_chase.free_held = event.pressed
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# A click rolls the way it is turning, or right flying straight.
			_roll_asked = -1.0 if float(_plane_flight.bank) < -0.05 else 1.0
		elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_BACK:
			_fly_launch()
		elif Pad.pressed(event,&"fly_lean_left"): _lean_tapped(-1.0)
		elif Pad.pressed(event,&"fly_lean_right"): _lean_tapped(1.0)
		elif event is InputEventKey and event.pressed and not event.echo:
			match event.keycode:
				KEY_G, KEY_ESCAPE: _fly(false)
				KEY_R: _fly_launch()
				KEY_Q: _lean_tapped(-1.0)
				KEY_E: _lean_tapped(1.0)
				KEY_N: _set_night(not _night)
				KEY_L: _set_shafts(not _shafts)
				KEY_V: _set_wind(not _wind)
				KEY_B: _send_gust()
		return
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_yaw -= event.relative.x*0.006
		_pitch = clampf(_pitch+event.relative.y*0.005,-0.1,1.4)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: _distance_goal = maxf(3.0,_distance_goal*0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: _distance_goal = minf(400.0,_distance_goal*1.1)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in KEYS:
			var at := _family_slot(KEYS.find(event.keycode))
			if at >= 0: _frame_piece(at)
			return
		if event.keycode in FAMILY_KEYS:
			_frame_family(ORDER[[1,2,0][FAMILY_KEYS.find(event.keycode)]])
			return
		match event.keycode:
			KEY_RIGHT: _frame_piece((_frame+1)%_slots.size())
			KEY_LEFT: _frame_piece((_frame+_slots.size()-1)%_slots.size() if _frame >= 0 else _slots.size()-1)
			KEY_SPACE, KEY_TAB: _frame_piece(-1)
			KEY_C: _frame_centre()
			KEY_G: _fly(true)
			KEY_L: _set_shafts(not _shafts)
			KEY_R:
				var framed := _frame
				var centred := _centred
				_seed += 1
				_build_layout()
				if centred: _frame_centre()
				else: _frame_piece(framed)
			KEY_T:
				# The next stone look, the same pieces rebuilt in it.
				var framed := _frame
				var centred := _centred
				var focus := _focus_goal
				var distance := _distance_goal
				_set_stone(StoneStyle.next(StoneStyle.current))
				_build_layout()
				if centred: _frame_centre()
				elif framed >= 0: _frame_piece(framed)
				_focus_goal = focus
				_distance_goal = distance
				_say()
			KEY_W:
				_show = (_show+1)%SHOWS.size()
				_apply_show()
				if _frame >= 0: _frame_piece(_frame)
			KEY_N: _set_night(not _night)
			KEY_V: _set_wind(not _wind)
			KEY_B: _send_gust()

# --- Fly mode (G) ---------------------------------------------------------------

## Fly mode: the game's own plane (scripts/sky_plane.gd) flown with the
## game's controls, under its chase camera (scripts/glide_camera.gd), into
## the long hall's mouth. The ruins' bodies are solid: touching stone
## bumps the plane back out along the face, turned along it and slowed,
## and it flies on (bump and recover, never a crash).
func _fly(on: bool) -> void:
	if on == _flying: return
	_flying = on
	for plane: Node3D in _hall_planes:
		if is_instance_valid(plane): plane.visible = not on
	if not on:
		if _fly_figure != null: _fly_figure.queue_free()
		_fly_figure = null
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_camera.fov = 40.0
		_say()
		return
	Pad.ensure()
	if _night: _set_night(false)
	_fly_figure = PlaneFigure.new()
	_fly_figure.name = "Flying"
	add_child(_fly_figure)
	_fly_figure.show_pilot(true)
	_chase = GlideCamera.new()
	_fly_launch()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_say()

## (Re)starts the run: the plane short of the long hall's first mouth,
## flying in down the lane, the chase camera behind it (R or the pad's
## Back/View restarts it at once).
func _fly_launch() -> void:
	var scene: Node3D = _areas.hall.scene
	var mouth: Dictionary = (scene.get_meta("ends") as Array)[0]
	var at := scene.global_transform*((mouth.at as Vector3)+Vector3(-18.0,3.2,(Hall.LANE.x+Hall.LANE.y)*0.5))
	var way := (scene.global_transform.basis*Vector3.RIGHT).normalized()
	_plane_flight = SkyPlane.new()
	_plane_flight.floor_y = -100.0
	_plane_flight.launch(at,atan2(-way.x,-way.z),SkyPlane.CRUISE_SPEED,false)
	_chase.reset(_plane_flight,at-way*6.0+Vector3.UP*1.6)
	_fly_look = Vector2.ZERO
	_roll_asked = 0.0
	_bumps = 0

## The plate's top under a point, or open air off it.
func _fly_ground(p: Vector3) -> Variant:
	var local := _layout.global_transform.affine_inverse()*p
	if _bounds.has_point(Vector2(local.x,local.z)): return 0.0
	return null

func _fly_step(delta: float) -> void:
	var stick := Input.get_vector(&"move_left",&"move_right",&"move_forward",&"move_back")
	if _autopilot > 0.0:
		# Down the lane, weaving a little either side of its middle, at
		# the height of a low run (in the hall's frame: +X down the nave).
		_autopilot -= delta
		# In the hall's path space, so it follows the curve.
		var scene: Node3D = _areas.hall.scene
		var path = scene.get_meta("path")
		var inv: Transform3D = scene.global_transform.affine_inverse()
		var local: Vector3 = path.locate(inv*(_plane_flight.position as Vector3))
		var frame: Transform3D = path.xform(local.x)
		var moving: Vector3 = frame.basis.inverse()*(inv.basis*(_plane_flight.velocity as Vector3))
		var want := (Hall.LANE.x+Hall.LANE.y)*0.5+1.1*sin(_motion_time*0.9)
		var height := _autopilot_height
		stick = Vector2(clampf(-(local.z-want)*0.35-moving.z*0.3,-0.7,0.7),clampf((height-local.y)*0.4-moving.y*0.25,-0.6,0.6))
	# Q E or the shoulders held: the knife edge (as the game's plane).
	var keys := (1.0 if Input.is_key_pressed(KEY_E) else 0.0)-(1.0 if Input.is_key_pressed(KEY_Q) else 0.0)
	var lean := clampf(keys+Input.get_action_strength(&"fly_lean_right")-Input.get_action_strength(&"fly_lean_left"),-1.0,1.0)
	if _autopilot_lean != 0.0: lean = _autopilot_lean
	var input := {"turn":stick.x,"pitch":stick.y,"look":_fly_look,"lean":lean,
		"boost":Input.get_action_strength(&"fly_boost"),"brake":Input.get_action_strength(&"fly_brake"),"roll":_roll_asked}
	_fly_look = Vector2.ZERO
	_roll_asked = 0.0
	var was: Vector3 = _plane_flight.position
	_plane_flight.step(delta,input,_fly_ground)
	_bump(was)
	_fly_figure.update(delta,_plane_flight,0.0,_fly_ground,false)
	_fly_figure._mark.visible = false
	_chase.step(delta,_plane_flight,0.0,_inside_stone)
	_camera.global_position = _chase.eye
	_camera.look_at(_chase.look,Vector3.UP)
	_camera.rotate_object_local(Vector3.FORWARD,_chase.roll)
	_camera.fov = _chase.fov

## A lean pressed: the second press the same way within the game's
## DOUBLE_TAP asks for a barrel roll that way.
func _lean_tapped(dir: float) -> void:
	var now := Time.get_ticks_msec()
	if dir == _tap_dir and now-_tap_at <= int(WandererEye.DOUBLE_TAP*1000.0):
		_roll_asked = dir
		_tap_dir = 0.0
	else:
		_tap_dir = dir
		_tap_at = now

## Bump and recover: if the plane's body (BUMP_BODY, turned with its
## heading, pitch, bank and roll) sits in stone, it is put back out along the face it hit (the way it
## came, failing that), its heading turned along the face and its pitch
## eased level, a share of its speed lost; the camera shakes a little.
func _bump(was: Vector3) -> void:
	var space := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var body := BoxShape3D.new()
	body.size = BUMP_BODY
	query.shape = body
	var turn := PlaneFigure.pose(Vector3.ZERO,float(_plane_flight.heading),float(_plane_flight.pitch),float(_plane_flight.bank)+float(_plane_flight.spin)).basis
	query.transform = Transform3D(turn,_plane_flight.position)
	var rest := space.get_rest_info(query)
	if rest.is_empty(): return
	_bumps += 1
	var normal: Vector3 = rest.get("normal",Vector3.ZERO)
	if normal.length() < 0.5: normal = (was-_plane_flight.position).normalized()
	# Back out: to where it was, then a little off the face.
	_plane_flight.position = was+normal*0.15
	query.transform = Transform3D(turn,_plane_flight.position)
	if not space.get_rest_info(query).is_empty(): _plane_flight.position = was+normal*0.6
	# Turned along the face, eased level against a floor or ceiling.
	var way: Vector3 = _plane_flight.forward()
	var along := way-normal*way.dot(normal)
	if along.length() > 0.05:
		along = along.normalized()
		var flat := Vector2(along.x,along.z)
		if flat.length() > 0.05: _plane_flight.heading = atan2(-flat.x,-flat.y)
		_plane_flight.pitch = clampf(asin(clampf(along.y,-1.0,1.0)),-0.6,0.6)
	_plane_flight.speed = maxf(SkyPlane.SLOW,float(_plane_flight.speed)*BUMP_KEEP)
	_plane_flight.velocity = _plane_flight.forward()*float(_plane_flight.speed)

## Whether a point is inside stone (the camera stays out of it).
func _inside_stone(p: Vector3) -> bool:
	var query := PhysicsPointQueryParameters3D.new()
	query.position = p
	return not get_world_3d().direct_space_state.intersect_point(query,1).is_empty()
