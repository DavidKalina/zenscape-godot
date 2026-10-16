extends "res://studies/character_study.gd"
## The Day-Count yard (the card is t1-day-count in round 4's lens4-traps.md):
## the calendar
## court (scripts/traps/trap_day_count.gd) on a basalt plaza in open sky,
## and the Olmec on call. The pilot is the character study's (this extends
## it, as the trap yard does): the same motor, figure, camera, F1, F2.
##
## Every footfall the drawn body makes (scripts/pilot_figure.gd `drive`'s
## "footfall", the one the step sound plays on) is handed to the court
## while he is on his feet on it (`_body_events`); the Olmec's every step
## (its "body_step" sound, scripts/enemies/headless_body.gd) is handed to
## it through the enemy field's `sound_hook`. A small local hook, not the
## noise bus: the court asks only "did a foot come down on me".
##
## Keys:
##   1   the plaza, facing the court      2   on the hub
##   3   up on the terrace (the way out)
##   O   the Olmec in (hunting you, from the plaza's far end) or gone
##   R   all back: you, the court, the Olmec
##   godot --path . res://studies/strange_day_count_yard.tscn -- --no-title
##     [--olmec] [--knob=<court knob>=<value>] [--body-knob=<k>=<v>]
## e.g. `--knob=per_click=1` clicks on every footfall (the card read
## literally), `--knob=snap=0.5` a slower ratchet.
const TrapField = preload("res://scripts/traps/trap_field.gd")
const DayCount = preload("res://scripts/traps/trap_day_count.gd")
const EnemyField = preload("res://scripts/enemies/enemy_field.gd")
const InhalerHead = preload("res://scripts/enemies/inhaler_head.gd")
const HeadlessBody = preload("res://scripts/enemies/headless_body.gd")
const BodySpawner = preload("res://scripts/enemies/body_spawner.gd")
const EnemyYard = preload("res://studies/enemy_yard.gd")
const CityStone = preload("res://scripts/city_kit_stone.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")

## The plaza south of the court (x, z), its slab's depth, its paving.
const PLAZA := Rect2(-16.0,-0.6,32.0,44.0)
const PLAZA_DEEP := 3.0
const PAVE := 4.0
## Where the Olmec comes in (the plaza's far end), facing the court.
const OLMEC_AT := Vector3(0.0,0.0,38.0)
const YARD_LOST := -30.0
## The court's sounds: [length, tone from, tone to, noise share, noise
## low-pass, attack, tremolo] (studies/enemy_yard.gd `_synth`).
const VOICES := {
	# The ratchet: a dry stone clack.
	"clack":[0.11,0.0,0.0,1.0,0.75,0.001,0.0],
	# A second ring ground round with it: a low burr.
	"burr":[0.42,62.0,48.0,0.55,0.18,0.01,24.0],
	# The next click lines the stair up: a deep thrum.
	"thrum":[1.1,38.0,34.0,0.25,0.05,0.08,3.0],
	# The stair stands: a settled knock and hum.
	"stair":[0.9,55.0,52.0,0.35,0.1,0.004,0.0],
	# The calendar round: a long hum, the cache's lid grinding aside.
	"round":[2.2,44.0,66.0,0.4,0.08,0.05,2.0],
}
const REACH := {"clack":26.0,"burr":30.0,"thrum":40.0,"stair":40.0,"round":60.0}

var traps: Node3D
var court: Node3D
var enemies: Node
var _slot: Node
var _knobs := {}
var _body_knobs := {}
var _olmec := false
var _voices := {}
var _count_label: Label
## Footfalls the drawn body made on the court, and off it (the check's).
var steps_on := 0
var steps_off := 0

## Steps the court and the enemies from the study's one slot (as the stun
## yard's Both does).
class Slot extends Node:
	var parts: Array = []
	func before(delta: float) -> void:
		for p: Node in parts: p.before(delta)
	func after(delta: float, events: Dictionary) -> void:
		for p: Node in parts: p.after(delta,events)
	func pose(figure: Node3D) -> void:
		for p: Node in parts: p.pose(figure)

func _ready() -> void:
	pack = "day_count_yard"
	for arg: String in LaunchArgs.user_args():
		if arg == "--olmec": _olmec = true
		for pair in [["--knob=",_knobs],["--body-knob=",_body_knobs]]:
			if not arg.begins_with(pair[0]): continue
			var kv: String = arg.trim_prefix(pair[0])
			var value := kv.get_slice("=",1)
			var parsed: Variant = value
			if value.is_valid_float(): parsed = value.to_float()
			elif value == "true" or value == "false": parsed = value == "true"
			pair[1][kv.get_slice("=",0)] = parsed
	super._ready()

func _load_pack() -> void:
	court = DayCount.new()
	court.configure(_knobs)
	var c: Vector3 = court.centre()
	var run_up: float = court.run_up()
	start = Vector3(0.0,0.0,run_up)
	start_face = Vector2(0.0,-1.0)
	lost = YARD_LOST
	_last_stood = start
	var hub_at := c+Vector3(0.0,0.0,float(court.knob("hub"))*0.5)
	# The court stands at the origin (its way in), not yet in the tree.
	var top: Vector3 = c+Vector3(0.0,court.terrace_top(),-court.terrace_face()-1.5)
	stations = [
		{"key":1,"name":"the plaza","spawn":start,"face":start_face,"parts":[]},
		{"key":2,"name":"the hub","spawn":hub_at,"face":Vector2(0.0,-1.0),"parts":[]},
		{"key":3,"name":"the terrace","spawn":top,"face":Vector2(0.0,1.0),"parts":[]},
	]

func _build_room() -> void:
	super._build_room()
	# No greybox signs: the place is its own stone.
	for l: Node in find_children("*","Label3D",false,false): l.queue_free()
	_build_plaza()
	traps = TrapField.new()
	add_child(traps)
	traps.attach(self)
	traps.add(court)
	court.sounded.connect(_court_sound)
	enemies = EnemyField.new()
	enemies.attach(self)
	enemies.sound_hook = _enemy_sound
	_slot = Slot.new()
	_slot.parts = [traps,enemies]
	add_child(_slot)
	foot_pieces = _slot
	motor.air = traps._air
	if _olmec: olmec_in()
	_build_count_label()

## The plaza: paving slabs of the city's basalt on a deep slab, collided as
## one box.
func _build_plaza() -> void:
	var m := CityStone.Mesher.new(CityStone.stone_colour())
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var nx := int(PLAZA.size.x/PAVE)
	var nz := int(PLAZA.size.y/PAVE)
	for i in nx:
		for j in nz:
			var c := Vector3(PLAZA.position.x+PAVE*(i+0.5),-0.5,PLAZA.position.y+PAVE*(j+0.5))
			var sink := rng.randf_range(0.0,0.03)
			m.solid(CityStone.box(Transform3D(Basis.IDENTITY,c+Vector3.DOWN*sink),Vector3(PAVE*0.5-0.04,0.5,PAVE*0.5-0.04),0.05),-1.0,rng.randf_range(0.85,1.08))
	var under := Vector3(PLAZA.get_center().x,-1.0-PLAZA_DEEP*0.5,PLAZA.get_center().y)
	m.solid(CityStone.box(Transform3D(Basis.IDENTITY,under),Vector3(PLAZA.size.x*0.5-0.4,PLAZA_DEEP*0.5,PLAZA.size.y*0.5-0.4),0.3),-1.0-PLAZA_DEEP,0.8)
	var mesh := MeshInstance3D.new()
	mesh.name = "Plaza"
	CityStone.warm()
	mesh.mesh = m.mesh(CityStone.wear("span"),CityStone._runes)
	add_child(mesh)
	var body := StaticBody3D.new()
	body.name = "PlazaSolid"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(PLAZA.size.x,1.0+PLAZA_DEEP,PLAZA.size.y)
	shape.shape = box
	shape.position = Vector3(PLAZA.get_center().x,-(1.0+PLAZA_DEEP)*0.5,PLAZA.get_center().y)
	body.add_child(shape)
	add_child(body)

# --- The hook: footfalls to the court ------------------------------------------------

## The drawn body's events: a footfall, on his feet on the court, is
## counted (jumps, hangs, climbs and wall runs make none).
func _body_events(out: Dictionary, delta: float) -> void:
	super._body_events(out,delta)
	if not out.has("footfall") or court == null: return
	if not motor.grounded or motor.on_ledge() or motor.swimming or motor.move == "wallrun": return
	if court.footfall(motor.feet,"wanderer"): steps_on += 1
	else: steps_off += 1

## The enemies' sounds: played, and the Olmec's steps handed to the court.
func _enemy_sound(sound_name: StringName, at: Vector3) -> void:
	if sound_name == &"body_step" and court != null: court.olmec_step(at)
	_play(String(sound_name),at)

func _court_sound(kind: StringName, at: Vector3) -> void:
	_play(String(kind),at)

func _play(key: String, at: Vector3) -> void:
	var spec: Variant = VOICES.get(key,InhalerHead.VOICES.get(key,BodySpawner.VOICES.get(key)))
	if spec == null: return
	if not _voices.has(key): _voices[key] = EnemyYard._synth(spec)
	var player := AudioStreamPlayer3D.new()
	player.stream = _voices[key]
	player.position = at
	player.unit_size = float(REACH.get(key,BodySpawner.REACH.get(key,30.0)))
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

# --- The Olmec ----------------------------------------------------------------------

## The whole Olmec, hunting, at the plaza's far end facing the court.
func olmec_in() -> void:
	if enemies == null or not enemies.specs.is_empty(): return
	var knobs := {"chase":1,"chase_routes":1,"periscope":1}
	knobs.merge(_body_knobs,true)
	enemies.spawn(HeadlessBody,OLMEC_AT,Vector2(0.0,-1.0),knobs)
	enemies.spawn(InhalerHead,OLMEC_AT,Vector2(0.0,-1.0),{})
	_wire()

func olmec_out() -> void:
	if enemies != null: enemies.clear()

func olmec() -> Node3D:
	if enemies == null: return null
	for e in enemies.enemies:
		if is_instance_valid(e) and e.has_method("make_whole"): return e
	return null

func _wire() -> void:
	var b := olmec()
	var h: Node3D = null
	for e in enemies.enemies:
		if is_instance_valid(e) and e.has_method("mouth"): h = e
	if b != null and h != null and not bool(b.get("whole")): b.make_whole(h)

# --- Play ---------------------------------------------------------------------------

## Set down anywhere: the court as built, the Olmec back where he came in.
func place(at: Vector3, face: Vector2) -> void:
	if traps != null: traps.reset()
	if enemies != null:
		enemies.reset()
		_wire()
	steps_on = 0
	steps_off = 0
	super.place(at,face)
	# Off whatever carried him (a ring set back would carry him with it).
	motor.platform = null
	motor.frame_v = Vector3.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_O and not _tuning():
		if olmec() == null:
			olmec_in()
			_say("The Olmec comes. Every step he takes turns the court.",3.0)
		else:
			olmec_out()
			_say("The Olmec is gone.",2.0)
		return
	super._unhandled_input(event)

func tick(delta: float) -> void:
	super.tick(delta)
	if _count_label != null: _count_label.text = count_line()

## The court's count in a line or two: what the glyphs say, in numbers.
func count_line() -> String:
	if court == null: return ""
	var lit := ""
	for k in DayCount.RINGS: lit += "●" if court.in_line(k) else "○"
	var to: int = court.clicks_to_window()
	var lines := PackedStringArray([
		"footfalls %d (a click every %d) · clicks %d" % [court.footfalls,int(court.knob("per_click")),court.clicks],
		"rings in line %s · %s" % [lit,"THE STAIR STANDS" if to == 0 else "stair in %d clicks" % to],
	])
	if court.round_aligned(): lines.append("THE CALENDAR ROUND: the cache is open")
	var o := olmec()
	if o != null: lines.append("Olmec steps on the court: %d" % (int(court.by.get("olmec",0))/maxi(int(court.knob("per_click")),1)))
	return "\n".join(lines)

func _build_count_label() -> void:
	_count_label = Label.new()
	_count_label.anchor_left = 1.0
	_count_label.anchor_right = 1.0
	_count_label.offset_left = -560.0
	_count_label.offset_right = -16.0
	_count_label.offset_top = 12.0
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count_label.add_theme_font_size_override("font_size",20)
	_count_label.add_theme_color_override("font_outline_color",Color.BLACK)
	_count_label.add_theme_constant_override("outline_size",6)
	var layer := CanvasLayer.new()
	layer.add_child(_count_label)
	add_child(layer)

func _hint_text() -> String:
	return "The Day-Count · every footfall on the court counts, every %d a click: the outer ring a notch, every 2nd the middle back, every 4th the inner · stand still and nothing turns; jumps and climbs don't count · all three rings lit is the stair to the terrace (north) · 1 plaza · 2 hub · 3 terrace · O the Olmec in/out · R start · F1 numbers · Esc mouse" % int(court.knob("per_click") if court != null else 4)
