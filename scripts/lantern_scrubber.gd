extends Control
## The bottom scrubber, like Mario Maker's course-scroll strip: one slim track
## with two handles. The glowing orb on the line is the season (the four season
## glyphs sit at its detents); the small sun riding above the line is the time
## of day, placed by the sun's phase, with Turning day at the right end.
## Dragging pins the season or hour through scripts/mood_look.gd as the mood
## drawer would, a detent at a time, so the change fades in live and is kept
## like any pin. Right-click a handle to let it follow the mood again.
const Style = preload("res://scripts/lantern_style.gd")
const Mood = preload("res://scripts/mood_look.gd")
const WIDTH := 360.0
const HEIGHT := 44.0
const INSET := 16.0
## Track fraction the hours span; Turning day sits past it, at the end.
const HOURS_SPAN := 0.9
const LINE_Y := 27.0
const SUN_RISE := 12.0

var scene: Node3D
var _drag := ""
var _hover := ""
var _drag_f := 0.0
var _label_alpha := 0.0

func setup(owner_scene: Node3D) -> void:
	scene = owner_scene
	name = "SeasonScrubber"
	custom_minimum_size = Vector2(WIDTH,HEIGHT)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "Drag the orb for the season, the sun for the time of day  ·  right-click one to follow the mood"
	mouse_exited.connect(func() -> void: _hover = "")

func _mood() -> Node:
	return scene.get("mood_look")

func _x(f: float) -> float:
	return INSET+clampf(f,0.0,1.0)*(size.x-INSET*2.0)

func _f(x: float) -> float:
	return clampf((x-INSET)/(size.x-INSET*2.0),0.0,1.0)

func season_f() -> float:
	return float(scene.world_clock.season)

func time_f() -> float:
	var mood := _mood()
	if mood != null and mood.pinned("time") and mood.value("time") == "turning" and not scene.world_clock.running: return 1.0
	return float(scene._celestial.phase)*HOURS_SPAN

static func season_at(f: float) -> String:
	return str(Mood.SEASONS[clampi(int(f*4.0),0,3)].id)

## The hour option nearest a track fraction, or "turning" past the hours.
static func time_at(f: float) -> String:
	if f > (HOURS_SPAN+1.0)*0.5: return "turning"
	var phase := f/HOURS_SPAN
	var best := ""
	var gap := INF
	for entry: Dictionary in Mood.TIMES:
		if float(entry.phase) < 0.0: continue
		var d := absf(angle_difference(float(entry.phase)*TAU,phase*TAU))
		if d < gap:
			gap = d
			best = entry.id
	return best

func _handle(which: String) -> Vector2:
	var f := _drag_f if _drag == which else (season_f() if which == "season" else time_f())
	return Vector2(_x(f),LINE_Y-(SUN_RISE if which == "time" else 0.0))

func _pick(point: Vector2) -> String:
	var season := point.distance_to(_handle("season"))
	var time := point.distance_to(_handle("time"))
	if minf(season,time) < 14.0: return "season" if season <= time else "time"
	return "time" if point.y < LINE_Y-6.0 else "season"

func _gui_input(event: InputEvent) -> void:
	var mood := _mood()
	if mood == null: return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_RIGHT and button.pressed:
			mood.unpin(_pick(button.position))
			accept_event()
		elif button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				_drag = _pick(button.position)
				_scrub(button.position.x)
			else:
				_drag = ""
			accept_event()
	elif event is InputEventMouseMotion:
		if _drag.is_empty(): _hover = _pick(event.position)
		else:
			_scrub(event.position.x)
			accept_event()

func _scrub(x: float) -> void:
	_drag_f = _f(x)
	var mood := _mood()
	var id := season_at(_drag_f) if _drag == "season" else time_at(_drag_f)
	if mood.value(_drag) != id or not mood.pinned(_drag): mood.pin(_drag,id)

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	_label_alpha = move_toward(_label_alpha,1.0 if not (_drag+_hover).is_empty() else 0.0,delta*5.0)
	queue_redraw()

func _draw() -> void:
	var mood := _mood()
	if mood == null: return
	var light := Style.LIGHT
	var x0 := _x(0.0)
	var x1 := _x(1.0)
	# The line, with a dark underlay so it holds on snow.
	draw_line(Vector2(x0,LINE_Y),Vector2(x1,LINE_Y),Color(Style.SHADE,0.55),3.0,true)
	draw_line(Vector2(x0,LINE_Y),Vector2(x1,LINE_Y),Color(light,0.55),1.0,true)
	for i in range(25):
		var x := lerpf(x0,x1,i/24.0)
		draw_line(Vector2(x,LINE_Y-2.0),Vector2(x,LINE_Y+2.0),Color(light,0.35),1.0)
	# Hour detents above the line; Turning day as a small loop at the end.
	for entry: Dictionary in Mood.TIMES:
		if float(entry.phase) < 0.0: continue
		var x := _x(float(entry.phase)*HOURS_SPAN)
		draw_circle(Vector2(x,LINE_Y-SUN_RISE),1.3,Color(light,0.45))
	var loop := Vector2(x1-2.0,LINE_Y-SUN_RISE)
	var turning: bool = scene.world_clock.running
	draw_arc(loop,4.0,0.4,TAU-0.4,16,Color(light,0.85 if turning else 0.4),1.1,true)
	# Season glyphs at their detents, on dark discs so the line breaks round them.
	for index in range(4):
		var at := Vector2(_x((index+0.5)/4.0),LINE_Y)
		draw_circle(at,8.5,Color(Style.SHADE,0.7))
		var id := str(Mood.SEASONS[index].id)
		var current := season_at(season_f()) == id
		draw_texture_rect(Style.glyph(id),Rect2(at-Vector2(7,7),Vector2(14,14)),false,Color(light,0.95 if current else 0.55))
	# The time of day: a small sun by day, a ring moon by night.
	var sun := _handle("time")
	var phase := float(scene._celestial.phase)
	var day := phase > 0.24 and phase < 0.76
	var warm := Color("f6d49a")
	draw_line(Vector2(sun.x,sun.y+5.0),Vector2(sun.x,LINE_Y-1.5),Color(warm,0.4),1.0)
	draw_circle(sun,9.0,Color(Style.SHADE,0.5))
	draw_circle(sun,7.0,Color(warm,0.22))
	if day:
		draw_circle(sun,3.6,warm)
		for i in range(8):
			var dir := Vector2.from_angle(i*TAU/8.0)
			draw_line(sun+dir*5.2,sun+dir*7.0,Color(warm,0.85),1.0,true)
	else:
		draw_arc(sun,4.0,0,TAU,20,warm,1.2,true)
		draw_circle(sun+Vector2(1.6,-1.2),3.2,Color(Style.SHADE,0.9))
	if mood.pinned("time"): draw_circle(sun+Vector2(0,-10.5),1.4,warm)
	# The season: the glowing orb on the line.
	var orb := _handle("season")
	for ring in range(5): draw_circle(orb,14.0-ring*2.2,Color(light,0.05+ring*0.02))
	draw_circle(orb,7.5,Color(Style.SHADE,0.55))
	draw_circle(orb,6.0,light)
	if mood.pinned("season"): draw_circle(orb+Vector2(0,10.5),1.4,light)
	# The name of the handle in hand, above it.
	if _label_alpha > 0.01:
		var which := _drag if not _drag.is_empty() else _hover
		var text := ""
		if which == "season": text = str(Mood.option("season",season_at(_drag_f if _drag == "season" else season_f())).get("title",""))
		elif which == "time":
			var id: String = time_at(_drag_f) if _drag == "time" else str(mood.value("time"))
			text = str(Mood.option("time",id).get("title","Time of day"))
		if not text.is_empty():
			var font := Style.font()
			var caps := Style.caps(text)
			var width := font.get_string_size(caps,HORIZONTAL_ALIGNMENT_LEFT,-1,11).x
			var at := Vector2(clampf(_handle(which).x-width*0.5,0.0,size.x-width),LINE_Y-SUN_RISE-11.0)
			draw_string_outline(font,at,caps,HORIZONTAL_ALIGNMENT_LEFT,-1,11,4,Color(Style.SHADE,0.85*_label_alpha))
			draw_string(font,at,caps,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color(light,_label_alpha))
