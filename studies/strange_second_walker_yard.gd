extends "res://studies/whole_body_chase.gd"
## The Second Walker's yard (round 4 strange city, card h2: docs/design/
## roguelike/brainstorm/round4-strange-city/lens1-hunters.md; built in
## scripts/enemies/second_walker.gd on the footprint trail, scripts/enemies/
## foot_trail.gd): a clay figure your size walks your exact footprints 8 s
## behind you. Stand still 8 s and it catches you (a knock and a heart).
## Where a floor you crossed has broken since, it walks onto nothing.
## One paved court, a whole Olmec hunting you round it (the whole body
## chase's), and:
##   south       you start; the walker sits in its niche by the way north
##               (it wakes as you pass, and follows you from then on)
##   west        the loose voussoirs: a slab bridge over a 6 m pit, each
##               slab dropping just after you touch it (run it). It walks
##               your run 8 s later and steps onto nothing. A ramp climbs
##               out of the pit's west end.
##   east        a jump course: two blocks a running jump apart, a ledge to
##               hang from and climb: watch it do your jumps and your hang
##   north-east  the votive niches (scripts/city_kit_refuges.gd): shelves up
##               a pier the Olmec can't climb, a dark alcove at the top. A
##               refuge from him; not from it.
## Hearts as the run's (scripts/roguelike/run_state.gd, 4, safe 1.6 s after
## a hit), shown in the HUD; out of them, R starts again.
##   R  all back: you, the Olmec, the walker asleep, the bridge, hearts
##   B  the Olmec back · J his sight · L the look · F1 numbers
##   godot --path . res://studies/strange_second_walker_yard.tscn -- --no-title
##     [--underground[=torch|haze]] [--no-body] [--no-walker]
##     [--body-knob=k=v] [--head-knob=k=v] [--no-sight-overlay]
const SecondWalker = preload("res://scripts/enemies/second_walker.gd")
const TrapField = preload("res://scripts/traps/trap_field.gd")
const Voussoirs = preload("res://scripts/traps/trap_voussoirs.gd")
const Refuges = preload("res://scripts/city_kit_refuges.gd")
const RunState = preload("res://scripts/roguelike/run_state.gd")
const Underground = preload("res://scripts/underground/underground.gd")
const PilotMotorS = preload("res://scripts/pilot_motor.gd")

const COURT := Rect2(-44.0,-56.0,88.0,96.0)
const YARD_LOST := -40.0
## The pit under the bridge (x, z), its floor's top, and the bridge's way
## in (its slabs run along -z from there, over the pit's length).
const PIT := Rect2(-38.0,-10.6,22.0,9.6)
const PIT_FLOOR := -6.0
const BRIDGE_IN := Vector3(-20.0,0.0,-1.0)
## The walker's seat (in its niche, facing south: the way you came in).
const SEAT := Vector3(-3.2,0.0,17.0)
const SEAT_FACE := Vector2(0.0,1.0)
## The jump course: two blocks BLOCK_TOP high, WALKER_GAP walker heights
## apart, then a ledge a grab over the second.
const BLOCK_TOP := 1.0
const COURSE_X := 16.0
## The votive niches (their front, +z, to the court).
const NICHES_AT := Vector3(10.0,0.0,-42.0)
const START_AT := Vector3(0.0,0.0,30.0)
const BODY_POST := Vector3(-26.0,0.0,-36.0)
## Seconds after the bridge's last slab fell that it is laid again (once
## nobody is on it, and the walker is not walking toward it).
const ROW_BACK := 24.0

var walker: Node3D
var traps: Node3D
var row: Node3D
var niches: Node3D
var run := RunState.new()
var under: Node3D
var _environment: Environment
var _sun: DirectionalLight3D
var _no_body := false
var _no_walker := false
var _row_t := 0.0
var _out_said := false
var _clock_s := 0.0

## The Olmec's and the traps' slots round the motor's step.
class BothSlot extends Node:
	var first: Node
	var second: Node
	func before(delta: float) -> void:
		first.before(delta)
		second.before(delta)
	func after(delta: float, events: Dictionary) -> void:
		first.after(delta,events)
		second.after(delta,events)
	func pose(figure: Node3D) -> void:
		first.pose(figure)

func _ready() -> void:
	body_at = BODY_POST
	body_face = Vector2(0.0,1.0)
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg == "--no-body": _no_body = true
		elif arg == "--no-walker": _no_walker = true
	super._ready()

func _load_pack() -> void:
	start = START_AT
	start_face = Vector2(0.0,-1.0)
	lost = YARD_LOST
	_last_stood = start
	var parts := []
	var holes: Array[Rect2] = [PIT]
	for r: Rect2 in _floor_rects(COURT,holes): parts.append(["box",r,-4.0,0.0,"floor"])
	# The pit: its floor, its walls down to it, a ramp out at its west end.
	parts.append(["box",PIT,PIT_FLOOR-4.0,PIT_FLOOR,"pad"])
	parts.append(["ramp",Vector3(-23.0,PIT_FLOOR,-5.8),Vector3(PIT.position.x+0.05,0.0,-5.8),3.0,"lane"])
	parts.append(["label",Vector3(BRIDGE_IN.x,1.2,BRIDGE_IN.z+1.5),"the loose voussoirs · run it"])
	parts.append(["label",Vector3(-30.0,PIT_FLOOR+0.8,-8.5),"the pit · %d m · ramp out west" % int(-PIT_FLOOR)])
	# The walker's niche: a back wall and two cheeks round its seat.
	var n := SEAT
	parts.append(["box",Rect2(n.x-1.3,n.z-1.1,2.6,0.5),0.0,2.4,"wall"])
	parts.append(["box",Rect2(n.x-1.3,n.z-0.6,0.4,1.2),0.0,2.4,"wall"])
	parts.append(["box",Rect2(n.x+0.9,n.z-0.6,0.4,1.2),0.0,2.4,"wall"])
	parts.append(["label",Vector3(n.x,2.9,n.z),"a clay figure, seated"])
	# The jump course.
	var gap := WALKER_GAP*walker_tall()
	var a := Rect2(COURSE_X,-4.0,6.0,8.0)
	var b := Rect2(a.end.x+gap,-4.0,6.0,8.0)
	var ledge := Rect2(b.end.x,-4.0,4.0,8.0)
	parts.append(["box",a,0.0,BLOCK_TOP,"grey"])
	parts.append(["box",b,0.0,BLOCK_TOP,"grey"])
	parts.append(["box",ledge,0.0,BLOCK_TOP+RuinKit.GRAB_TOP,"lip"])
	parts.append(["ramp",Vector3(a.get_center().x,0.0,a.end.y+3.0),Vector3(a.get_center().x,BLOCK_TOP,a.end.y),2.4,"lane"])
	parts.append(["label",Vector3(a.end.x+gap*0.5,BLOCK_TOP+1.0,a.get_center().y),"jump · %.1f m" % gap])
	parts.append(["label",Vector3(ledge.get_center().x,BLOCK_TOP+RuinKit.GRAB_TOP+0.8,ledge.get_center().y),"hang · climb"])
	stations = [{"key":1,"name":"Second Walker yard","spawn":START_AT,"face":start_face,"parts":parts},
		{"key":2,"name":"bridge","spawn":BRIDGE_IN+Vector3(0.0,0.0,6.0),"face":Vector2(0.0,-1.0),"parts":[]},
		{"key":3,"name":"jump course","spawn":Vector3(a.get_center().x,0.0,a.end.y+6.0),"face":Vector2(0.0,-1.0),"parts":[]},
		{"key":4,"name":"niches","spawn":NICHES_AT+Vector3(0.0,0.0,10.0),"face":Vector2(0.0,-1.0),"parts":[]}]

func _build_light() -> void:
	super._build_light()
	for node: Node in get_children():
		if node is WorldEnvironment: _environment = (node as WorldEnvironment).environment
		elif node is DirectionalLight3D: _sun = node

func _build_room() -> void:
	niches = Refuges.piece("city_niches",7)
	niches.position = NICHES_AT
	add_child(niches)
	if _no_body: _build_room_no_body()
	else: super._build_room()
	# The bridge, stepped round the motor beside the Olmec.
	traps = TrapField.new()
	traps.study = self
	traps.motor = motor
	add_child(traps)
	row = Voussoirs.new()
	row.position = BRIDGE_IN
	traps.add(row)
	var both := BothSlot.new()
	both.first = foot_pieces
	both.second = traps
	add_child(both)
	foot_pieces = both
	# The walker, following whichever wanderer passes it (one here).
	if not _no_walker:
		walker = SecondWalker.new()
		walker.lost = lost
		walker.sound_hook = _voice
		add_child(walker)
		walker.setup(SEAT,PilotMotorS.facing_of(SEAT_FACE),[motor])
		walker.caught.connect(func(_w: Object) -> void: _say("Caught: it stepped into your place",2.5))
		walker.fell.connect(func(_at: Vector3) -> void: _say("It stepped onto nothing",2.5))
		walker.woke.connect(func(_w: Object) -> void: _say("Something got up behind you",2.5))
	run.begin(1)
	motor.harmed.connect(_harmed)
	under = Underground.attach(self)

## Without the Olmec: the field the HUD and the slot expect, empty.
func _build_room_no_body() -> void:
	super._build_room()
	enemies.clear()

func _study_body_knobs() -> Dictionary:
	return {"periscope":1,"sight_walker_only":1}

## Set down: everything back (the walker asleep, the bridge laid, hearts).
func place(at: Vector3, face: Vector2) -> void:
	super.place(at,face)
	if walker != null: walker.reset()
	if traps != null: traps.reset()
	_row_t = 0.0
	run.begin(1)
	_out_said = false
	if body != null: body.visible = true

func _harmed(amount: int, cause: String, _source: Object) -> void:
	var took := run.hurt(motor,amount,cause,cause == "fall")
	if took <= 0: return
	if run.hearts_of(motor) <= 0 and not _out_said:
		_out_said = true
		_say("Out of hearts (%s). R to start again" % ("the Second Walker" if cause == "walker" else cause),6.0)

func tick(delta: float) -> void:
	super.tick(delta)
	_clock_s += delta
	run.tick(delta)
	if walker != null: walker.step(delta)
	_relay_row(delta)
	# Safe after a hit: the figure blinks (the run loop's 12 Hz, 60% shown).
	if body != null:
		body.visible = run.safe_for(motor) <= 0.0 or fmod(_clock_s*12.0,1.0) < 0.6
	if under != null and _sun != null: _sun.visible = false

## The bridge laid again a while after it fell, once nobody is on it.
func _relay_row(delta: float) -> void:
	if row == null or row.fallen_count == 0:
		_row_t = 0.0
		return
	_row_t += delta
	if _row_t < ROW_BACK: return
	var on_it := func(p: Vector3) -> bool:
		return absf(p.x-BRIDGE_IN.x) < 3.0 and p.z < BRIDGE_IN.z+2.0 and p.z > PIT.position.y-2.0
	if on_it.call(motor.feet): return
	if walker != null and (walker.state == "walking" or walker.state == "falling") and on_it.call(walker.pos): return
	traps.reset()
	_row_t = 0.0

func _voice(sound_name: StringName, at: Vector3) -> void:
	var key := String(sound_name)
	if not SecondWalker.VOICES.has(key):
		super._voice(sound_name,at)
		return
	if not _voices.has(key): _voices[key] = EnemyYard._synth(SecondWalker.VOICES[key])
	var player := AudioStreamPlayer3D.new()
	player.stream = _voices[key]
	player.position = at
	player.unit_size = float(SecondWalker.REACH.get(key,14.0))
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func _hint_text() -> String:
	return "Second Walker · it walks your footprints 8 s behind: keep moving · run the voussoirs W and it steps onto nothing · jumps E · niches NE · R start · B Olmec back · 1-4 stations · F1 numbers"

func _show_hud() -> void:
	super._show_hud()
	if not _hud.visible: return
	var lines := PackedStringArray([_hud.text])
	lines.append("hearts %d/%d%s" % [run.hearts_of(motor),RunState.HEARTS," (safe)" if run.safe_for(motor) > 0.0 else ""])
	if walker != null: lines.append(walker.line())
	if row != null: lines.append("bridge  fallen %d · touched %d" % [row.fallen_count,row.landed_count])
	_hud.text = "\n".join(lines)
