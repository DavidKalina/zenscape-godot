extends "res://studies/plane_field_isle.gd"
## The elements on the plane (a prototype): the plane field (studies/
## plane_field_isle.gd) with the air made weather (scripts/plane_weather.gd):
## a storm that rolls in off the live sky, gusts that throw the nose off,
## and jet streams to ride: a loop round the field and a high one across.
## Far isles round it (scripts/sky_isles.gd), 0.3 to 2 km off at their own
## heights, for the weather to pass over and to fly to; the big ones land.
## The sky's cloud, towers and puffs, drifts on its wind across them
## (scripts/sky_drift.gd), faster in a storm.
##   T            a storm front comes in on the wind (or is called off;
##                scripts/storm_front.gd)
##   C            a storm cell comes in on the wind toward the plane
##                (scripts/storm_cells.gd); they also come on their own
##                every few minutes, over the field or a far isle, with
##                their own lightning
##   Shift+T      the whole sky's storm rolls in, or clears
##   G            a gust now
##   F12          lightning now (scripts/plane_lightning.gd)
##   R            back to the start
##   ./run-sky-weather.command        (heavy on: --heavy)
##   ./run-sky-weather.command --storm=1   a full storm from the start
##   ./run-sky-weather.command --cell-at=-430,-240   a cell over the near isle
##   ./run-sky-weather.command --cell-every=60 --cell-first=5   cells often
##   ./run-sky-weather.command --cell-every=0   no cells on their own
##   ./run-sky-weather.command --cloud-drift=30   the cloud faster (m/s; 0 still)
## The plane field's flags hold here.
const PlaneWeather = preload("res://scripts/plane_weather.gd")
const SkyIsles = preload("res://scripts/sky_isles.gd")
const SkyDrift = preload("res://scripts/sky_drift.gd")

var elements: Node3D
var _storming := false
var _readout: Label
## The far isles (scripts/sky_isles.gd `build`'s entries).
var isles: Array = []
## The cloud carried on the wind.
var drift := SkyDrift.new()

func _build_art() -> void:
	super._build_art()
	isles = SkyIsles.build(art)
	# Their turf is the plane's to skim and land on, as the field's is; but
	# kept out of the field's own outlines (`add_turf`), which would grow the
	# game's grass over every isle and stretch the field's circle round them.
	for isle: Dictionary in isles:
		for turf: StaticBody3D in FieldLand.turf_bodies(isle.land):
			turf.collision_layer |= TURF_LAYER
			_turf_rids.append(turf.get_rid())

func sight_isles() -> Array:
	var out := super.sight_isles()
	for isle: Dictionary in isles:
		out.append({"middle":isle.middle,"radius":isle.radius,"top":isle.top,"isle":self})
	return out

func _process(delta: float) -> void:
	if elements == null and walk_ready and _precipitation != null: _add_elements()
	if elements != null and delta > 0.0:
		elements.step(delta)
		drift.step(delta,cloud_host(),camera.global_position,elements._air_angle(),elements.storm)
	super._process(delta)
	if elements != null:
		elements.grade()
		elements.rain(camera.global_position,plane.velocity if flying and plane != null else Vector3.ZERO)
	if _readout != null and elements != null: _readout.text = _read()

func _add_elements() -> void:
	elements = PlaneWeather.new()
	add_child(elements)
	elements.setup(self)
	plane_air = func(p: Vector3) -> Dictionary:
		return elements.air_at(p,plane.forward() if plane != null else Vector3.FORWARD)
	var layer := CanvasLayer.new()
	add_child(layer)
	_readout = Label.new()
	_readout.position = Vector2(24,24)
	_readout.add_theme_font_size_override("font_size",18)
	_readout.add_theme_color_override("font_outline_color",Color(0,0,0,0.7))
	_readout.add_theme_constant_override("outline_size",6)
	layer.add_child(_readout)

func _read() -> String:
	var line := "Storm %d%%   (T front, C cell, Shift+T sky storm, G gust, F12 lightning)" % roundi(elements.storm*100.0)
	line += "\n"+drift.describe(elements._air_angle(),elements.storm)
	if elements.front.active:
		var d: float = elements.front.ahead_of(elements.probe())
		line += "\nFront %s" % ("%.1f km off" % (d/1000.0) if d > 0.0 else "overhead")
	if elements.cells.active: line += "\n"+_cell_line()
	if flying and plane != null:
		var here: Dictionary = plane_air.call(plane.position)
		if float(here.gust) > 0.1: line += "\nGust!"
		if float(here.jet) > 0.2: line += "\nIn the jet  %d m/s" % roundi(plane.velocity.length())
	return line

func _cell_line() -> String:
	var cells: Node3D = elements.cells
	var d: float = cells.off(elements.probe())
	var line := "Storm cell %s" % ("%.1f km off" % (d/1000.0) if d > float(cells.SHAFT) else "overhead")
	for isle: Dictionary in isles:
		var gap := Vector2(cells.centre.x-isle.middle.x,cells.centre.z-isle.middle.z).length()
		if gap < float(isle.radius)+float(cells.SHAFT): line += ", over the %s isle" % isle.name
	return line

func _unhandled_input(event: InputEvent) -> void:
	if elements != null and event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_T when not (event as InputEventKey).shift_pressed:
				_show_toast("A storm front is coming" if elements.send_front() else "The front is gone")
				return
			KEY_T:
				_storming = not _storming
				if _storming: elements.roll_in()
				else: elements.clear()
				_show_toast("A storm rolls in" if _storming else "The storm clears")
				return
			KEY_C:
				_show_toast("A storm cell is coming" if elements.send_cell() else "Not while the front is out")
				return
			KEY_G:
				elements.gust()
				return
			KEY_F12:
				elements.lightning.strike()
				return
	super._unhandled_input(event)
