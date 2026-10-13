extends "res://studies/kit_isle.gd"
## The crossing yard (docs/design/roguelike/crossing-viaduct-round1.md):
## the roguelike's crossings, the set pieces between the spiral's isles,
## each workshopped on its own, in the game's look under the aqueduct
## isle's sky (its cloud sea and towers: studies/aqueduct_isle_sky.gd, as
## the dragon vision greybox has it). The pilot is the kit isle's (this
## extends it): the same motor, camera and moves; no plane, lodestone,
## grass or life.
##
## One crossing at a time, built from CROSSINGS (each a script extending
## studies/crossings/crossing.gd: its entry, its exit, its beats), set with
## its entry at the kit's datum. To add one: write its script, add a line.
##   R          back to the start rim
##   1..        each beat's start (practice)
##   N          the next crossing (built afresh)
## Crossed (stood on the far rim), the time from leaving the start rim
## shows. Fallen, he lands on the soft floor and walks (and climbs) back.
## `--crossing=<name>` starts on that crossing; `--beat=<n>` at that beat.
##   ./run-crossing-yard.command
##   godot --path . res://studies/crossing_yard.tscn -- --no-title
const Crossing = preload("res://studies/crossings/crossing.gd")

## The slots: name -> the crossing's script. One line per crossing.
const CROSSINGS := {
	"viaduct": preload("res://studies/crossings/crossing_viaduct.gd"),
}

var crossing: Crossing
var crossing_name := ""
var _beat := 0
## The run's clock: from leaving the start rim to the far rim.
var _run_t := -1.0
var _crossed := false

func _ready() -> void:
	crossing_name = CROSSINGS.keys()[0]
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg.begins_with("--crossing=") and CROSSINGS.has(arg.get_slice("=",1)): crossing_name = arg.get_slice("=",1)
		elif arg.begins_with("--beat="): _beat = int(arg.get_slice("=",1))
	super._ready()

func isle_name() -> String:
	return "crossing yard"

## The crossing laid out (its numbers worked out), its start and beats.
func _load_pack() -> void:
	crossing = (CROSSINGS[crossing_name] as GDScript).new()
	crossing.name = "Crossing"
	crossing.position = Vector3(0.0,TOP,0.0)
	crossing.lay_out()
	var e: Dictionary = crossing.entry()
	start = crossing.position+(e.at as Vector3)
	start_face = e.face
	lost = TOP+crossing.floor_y()-30.0
	stations = []
	var beats: Array = crossing.beats()
	for i in range(beats.size()):
		var b: Dictionary = beats[i]
		stations.append({"key":i+1,"name":b.name,"spawn":crossing.position+(b.at as Vector3),"face":b.face,"parts":[]})
	if _beat >= 1 and _beat <= stations.size():
		start = stations[_beat-1].spawn
		start_face = stations[_beat-1].face
	_last_stood = start
	print("crossing yard: %s %s" % [crossing.title(),crossing.get("numbers") if crossing.get("numbers") != null else ""])

func _build_art() -> void:
	super._build_art()
	art.add_child(crossing)
	crossing.build(_material)
	var floor_body := crossing.get_node_or_null("Floor") as StaticBody3D
	if floor_body != null: floor_body.collision_layer |= TURF_LAYER

## Only the cloud sea's own towers in the sky, no grass, no life, no plane.
func sky_script() -> Script:
	return CloudSky

class CloudSky extends "res://studies/aqueduct_isle_sky.gd":
	func setup(study: Node3D) -> void:
		scene = study
		for k in on: on[k] = false
		if not flags().has("--no-sky"):
			on.clouds = true
			_build_clouds()

func _grow() -> void:
	pass

func _add_life() -> void:
	pass

func park_home() -> void:
	pass

## No stranding: the soft floor is the net.
func _check_step_off() -> void:
	pass

func capture_look() -> Vector3:
	return crossing.position+crossing.call("slot_at") if crossing.has_method("slot_at") else crossing.position

func isle_summit() -> Vector3:
	return Vector3(0.0,TOP+20.0,-50.0)

func place(at: Vector3, face: Vector2) -> void:
	super.place(at,face)
	_run_t = -1.0
	_crossed = false

func tick(delta: float) -> void:
	super.tick(delta)
	if crossing == null or flying: return
	var local := motor.feet-crossing.position
	if _run_t < 0.0 and not _crossed and local.distance_to(crossing.entry().at) > 4.0: _run_t = 0.0
	elif _run_t >= 0.0: _run_t += delta
	if not _crossed and motor.grounded and crossing.exit_reached(local):
		_crossed = true
		if _run_t >= 0.0: _show_toast("Crossed: %s in %.1f s" % [crossing.title(),_run_t])
		_run_t = -1.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_N:
		next_crossing()
		return
	super._unhandled_input(event)

## The next crossing in CROSSINGS, built afresh, at its start.
func next_crossing() -> void:
	var keys := CROSSINGS.keys()
	crossing_name = keys[(keys.find(crossing_name)+1)%keys.size()]
	art.remove_child(crossing)
	crossing.queue_free()
	_beat = 0
	_load_pack()
	art.add_child(crossing)
	crossing.build(_material)
	await get_tree().physics_frame
	respawn()
	_show_toast(crossing.title())

func _foot_text() -> String:
	var names := []
	for s: Dictionary in stations: names.append("%d %s" % [s.key,s.name])
	return "%s  ·  R start rim  ·  %s  ·  N next crossing\nShift/C at a run: slide, + Space: long jump (again on each landing: chain)  ·  Space on landing: pump  ·  X twirl  ·  into a wall: slide, Space kick" % [crossing.title() if crossing != null else "",", ".join(names)]
