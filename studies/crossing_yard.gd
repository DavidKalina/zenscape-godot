extends "res://studies/kit_isle.gd"
## The crossing yard:
## the crossings, the set pieces between isles,
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
##   K          its hazards on or off (the viaduct's gust arrows);
##              `--arrows=0` starts with them off (default on)
## Crossed (stood on the far rim), the time from leaving the start rim
## shows. The crossing hangs over the void (its `floor_y` under its walk):
## fallen past the
## void's floor he is lost, a short fade and back at the start rim, the
## falls counted on the foot card. Knocked into the air, Jump after
## KNOCK_SAIL s opens the pocket sail out of the tumble (PilotMotor
## `knock_sail`), and the crossing's updrafts (`updrafts`, thermals as the
## sky's: scripts/sky_currents.gd) climb the sail back up.
## `--crossing=<name>` starts on that crossing; `--beat=<n>` at that beat.
##   ./run-crossing-yard.command
##   godot --path . res://studies/crossing_yard.tscn -- --no-title
const Crossing = preload("res://studies/crossings/crossing.gd")
const SkyCurrents = preload("res://scripts/sky_currents.gd")
const GustArrows = preload("res://studies/crossings/gust_arrows.gd")
const FootPieces = preload("res://scripts/interactables/foot_pieces.gd")

## Seconds after a knock into the air before Jump opens the sail out of
## the tumble (PilotMotor `knock_sail`): the blow's first jolt is his to
## take, then the sail is his.
const KNOCK_SAIL := 0.35
## The updrafts' look, bolder than the sky's thermals (SkyCurrents' ribbon
## shader): how many times each column's ribbons are drawn (a second,
## look-only SkyCurrents: the air reads the one), and the ribbons'
## opacity, width and glow, so a falling player can see one to steer for.
const UPDRAFT_DRAWS := 4
const UPDRAFT_OPACITY := 0.75
const UPDRAFT_WIDTH := 2.2
const UPDRAFT_GLOW := 2.4
## The fade back from a fall to his death (s).
const FALL_FADE := 0.8

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
## The crossing's hazards on (K, --arrows=0/1), and the sound's state for
## each of their voices.
var hazards_on := true
var _voice_beds: Array = []
## The crossing's updrafts (thermals the sail climbs, drawn as the sky's).
var currents: SkyCurrents
var _updraft_look: SkyCurrents
## The crossing's floating stones (foot pieces), or null.
var stones: Node3D
## Fallen past the void's floor (world y): lost. Falls so far.
var kill_y := -INF
var falls := 0
var _fade: ColorRect
var _fade_left := 0.0

func _ready() -> void:
	crossing_name = CROSSINGS.keys()[0]
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg.begins_with("--crossing=") and CROSSINGS.has(arg.get_slice("=",1)): crossing_name = arg.get_slice("=",1)
		elif arg.begins_with("--beat="): _beat = int(arg.get_slice("=",1))
		elif arg.begins_with("--arrows="): hazards_on = arg.get_slice("=",1) != "0"
	super._ready()
	motor.knock_sail = KNOCK_SAIL
	# The sail reads the game's air and the crossing's updrafts together.
	var game_air: Callable = motor.air
	motor.air = func(p: Vector3) -> Dictionary: return _air_at(game_air,p)
	var layer := CanvasLayer.new()
	layer.name = "FallFade"
	layer.layer = 7
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.02,0.03,0.05)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	layer.add_child(_fade)

## The air at `p`: the game's (`game_air`: its breeze and gusts) with the
## crossing's updrafts' rise and thermal on it.
func _air_at(game_air: Callable, p: Vector3) -> Dictionary:
	var here: Dictionary = game_air.call(p) if game_air.is_valid() else {}
	if currents == null: return here
	var lift: Dictionary = currents.air_at(p)
	var wind: Vector3 = here.get("wind",Vector3.ZERO)
	return {"wind":wind+(lift.wind as Vector3),"thermal":maxf(float(here.get("thermal",0.0)),float(lift.thermal))}

func isle_name() -> String:
	return "crossing yard"

## The crossing laid out (its numbers worked out), its start and beats.
func _load_pack() -> void:
	crossing = (CROSSINGS[crossing_name] as GDScript).new()
	crossing.name = "Crossing"
	crossing.lay_out()
	# Its void's floor at the isle's datum, the walk high over it.
	crossing.position = Vector3(0.0,TOP-crossing.floor_y(),0.0)
	var e: Dictionary = crossing.entry()
	start = crossing.position+(e.at as Vector3)
	start_face = e.face
	kill_y = crossing.position.y+crossing.floor_y()
	lost = -INF
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
	crossing.set_hazards(hazards_on)
	var floor_body := crossing.get_node_or_null("Floor") as StaticBody3D
	if floor_body != null: floor_body.collision_layer |= TURF_LAYER
	_build_updrafts()
	_build_stones()

## The crossing's floating stones (its `foot_stones`, if it has them: the
## viaduct's routes out to its perches) as foot pieces (scripts/
## interactables/foot_pieces.gd: bobbing, sinking, carrying him).
func _build_stones() -> void:
	if stones != null:
		if foot_pieces == stones: foot_pieces = null
		stones.queue_free()
		stones = null
	if not crossing.has_method("foot_stones"): return
	stones = FootPieces.new()
	stones.name = "CrossingStones"
	add_child(stones)
	stones.attach(self)
	var k := 0
	for st: Dictionary in crossing.foot_stones():
		var p: Vector3 = crossing.position+(st.at as Vector3)
		if st.kind == "sink": stones.sink_slab(p,st.size,float(st.yaw),900+k)
		else: stones.bob_slab(p,st.size,float(st.yaw),900+k)
		k += 1
	if crossing.has_method("stones_made"):
		var rids: Array[RID] = []
		for slab: Node3D in stones.slabs: rids.append(slab.rid())
		crossing.stones_made(rids)

## The crossing's updrafts as the sky's thermals (SkyCurrents `add_thermal`,
## its ribbons spiralling up each column), in the world's frame.
func _build_updrafts() -> void:
	for old: SkyCurrents in [currents,_updraft_look]:
		if old != null: old.queue_free()
	currents = null
	_updraft_look = null
	var drafts: Array = crossing.updrafts()
	if drafts.is_empty(): return
	currents = SkyCurrents.new()
	currents.name = "Updrafts"
	add_child(currents)
	_updraft_look = SkyCurrents.new()
	_updraft_look.name = "UpdraftLook"
	add_child(_updraft_look)
	for d: Dictionary in drafts:
		var base: Vector3 = crossing.position+(d.base as Vector3)
		var top: float = crossing.position.y+float(d.top)
		currents.add_thermal(base,"crossing",top,float(d.radius))
		for k in range(UPDRAFT_DRAWS-1): _updraft_look.add_thermal(base,"crossing",top,float(d.radius))
	for drawn: SkyCurrents in [currents,_updraft_look]:
		var look := drawn.wisp_material()
		look.set_shader_parameter("opacity",UPDRAFT_OPACITY)
		look.set_shader_parameter("width_scale",UPDRAFT_WIDTH)
		look.set_shader_parameter("glow",UPDRAFT_GLOW)

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

## The grass and flowers on the crossing's sky isles (its `flora_turf`, if
## it has them: scripts/kit_isle/kit_flora.gd, as the kit isles grow theirs).
func _grow() -> void:
	if crossing == null or not crossing.has_method("flora_turf"): return
	var turf: Array = crossing.flora_turf()
	if turf.is_empty(): return
	var by := Vector2(crossing.position.x,crossing.position.z)
	var outlines: Array = []
	var high := -INF
	var low := INF
	for body: StaticBody3D in turf:
		high = maxf(high,body.global_position.y)
		low = minf(low,body.global_position.y)
	for o: PackedVector2Array in crossing.flora_outlines():
		var moved := PackedVector2Array()
		for p in o: moved.append(p+by)
		outlines.append(moved)
	var wear: Callable = crossing.flora_wear()
	var site := KitFlora.Site.new(high,func(p: Vector2) -> float: return float(wear.call(p-by)))
	site.ray = Vector2(high+40.0,low-8.0)
	var began := Time.get_ticks_msec()
	flora = KitFlora.grow(flora_seed(),get_world_3d().direct_space_state,turf,outlines,site)
	art.add_child(flora)
	flora_ready = true
	print("%s: flora %s grown in %d ms" % [isle_name(),flora.get_meta("counts"),Time.get_ticks_msec()-began])

func _add_life() -> void:
	pass

func park_home() -> void:
	pass

## No stranding: the void's floor is the net (`tick`).
func _check_step_off() -> void:
	pass

func capture_look() -> Vector3:
	return crossing.position+crossing.call("slot_at") if crossing.has_method("slot_at") else crossing.position

func isle_summit() -> Vector3:
	return Vector3(0.0,(crossing.position.y if crossing != null else TOP)+20.0,-50.0)

func place(at: Vector3, face: Vector2) -> void:
	super.place(at,face)
	_run_t = -1.0
	_crossed = false

func tick(delta: float) -> void:
	super.tick(delta)
	if _fade != null and _fade_left > 0.0:
		_fade_left = maxf(_fade_left-delta,0.0)
		_fade.modulate.a = clampf(_fade_left/FALL_FADE,0.0,1.0)
	if crossing == null or flying: return
	if motor.feet.y < kill_y:
		fall_to_death()
		return
	var local := motor.feet-crossing.position
	if _run_t < 0.0 and not _crossed and local.distance_to(crossing.entry().at) > 4.0: _run_t = 0.0
	elif _run_t >= 0.0: _run_t += delta
	_hazards(delta)
	if not _crossed and motor.grounded and crossing.exit_reached(local):
		_crossed = true
		if _run_t >= 0.0: _show_toast("Crossed: %s in %.1f s" % [crossing.title(),_run_t])
		_run_t = -1.0

## The crossing's hazards after the pilot's step, and their sound.
func _hazards(delta: float) -> void:
	if not crossing.has_hazards(): return
	var word := crossing.step_hazards(delta,motor,get_world_3d().direct_space_state)
	if word == "silenced": _show_toast("Slammed the horn: silenced for %.0f s" % GustArrows.DISABLE_TIME)
	if audio == null or audio.beasts == null: return
	var voices: Array = crossing.hazard_voices()
	while _voice_beds.size() < voices.size(): _voice_beds.append({})
	for i in range(voices.size()): audio.beasts._air_blast(voices[i],_voice_beds[i])

## Fallen past the void's floor: counted, a short fade, back at the start
## rim (the crossing's entry, whatever beat he practised from).
func fall_to_death() -> void:
	falls += 1
	var e: Dictionary = crossing.entry()
	place(crossing.position+(e.at as Vector3),e.face)
	_last_stood = motor.feet
	_fade_left = FALL_FADE
	if _fade != null: _fade.modulate.a = 1.0
	_show_toast("Fallen into the void: back to the start rim  ·  falls %d" % falls)

func set_hazards(on: bool) -> void:
	hazards_on = on
	crossing.set_hazards(on)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_N:
		next_crossing()
		return
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_K and crossing.has_hazards():
		set_hazards(not hazards_on)
		_show_toast("Gust arrows on" if hazards_on else "Gust arrows off")
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
	crossing.set_hazards(hazards_on)
	_build_updrafts()
	_build_stones()
	_voice_beds = []
	await get_tree().physics_frame
	respawn()
	_show_toast(crossing.title())

func _foot_text() -> String:
	var names := []
	for s: Dictionary in stations: names.append("%d %s" % [s.key,s.name])
	var hazard := ("  ·  K arrows: %s" % ("on" if hazards_on else "off")) if crossing != null and crossing.has_hazards() else ""
	if crossing != null and crossing.has_method("foot_stones"): hazard += "  ·  stones out to a horn: Space, Space again for the sail; off the last stone Shift/C slams its top (silenced)"
	hazard += "  ·  falls %d" % falls
	if motor != null and motor.move == "tumble" and not motor.grounded: hazard += "\nKnocked: Space (pad A) opens the sail  ·  ride an updraft's swirl back up"
	elif motor != null and motor.move == "sail": hazard += "\nUnder the sail: WASD steer into an updraft's swirl to climb  ·  Shift/C float  ·  Space fold"
	return "%s  ·  R start rim  ·  %s  ·  N next crossing%s\nShift/C at a run: slide, + Space: long jump (again on each landing: chain)  ·  Space on landing: pump  ·  X twirl  ·  into a wall: slide, Space kick" % [crossing.title() if crossing != null else "",", ".join(names),hazard]
