extends "res://studies/character_study.gd"
## The stun yard: greybox stations in
## open sky for playing the stun (scripts/pilot_motor.gd's header). The
## pilot is the character study's (this extends it): the same motor,
## figure, camera, F1 numbers, F2 feel.
##   1-8  the drop ladder: columns of 0.5 to 3 times the stun's fall (its
##        height and share marked on each), stood on top facing the deck;
##        step off: under 1x a landing, from 1x laid down, longer the
##        higher (capped at 2x). Twirl (X) with the touch close: the roll.
##   0    the wind blaster lane (trap_wind_blaster.gd): stop on its plate
##        and be blown off, down onto the floor a stun's fall below.
##   -    the chain: stand on the orange plate (the kicker) and you are
##        knocked onto the Sky Ray waiting beside the deck; ride (or hang)
##        it, or fall/glide off onto the seesaw dropper below, whose block
##        throws whatever lies on its far half.
## T turns the tech on and off live (shown top right with the stun's state).
## `--knob=<motor var>=<value>` (repeatable) sets the motor's stun knobs,
## e.g. `--knob=tech=true --knob=poise=0.7 --knob=tumble_immune=0.3`.
##   godot --path . res://studies/stun_yard.tscn -- --no-title
const Trap = preload("res://scripts/traps/trap.gd")
const TrapField = preload("res://scripts/traps/trap_field.gd")
const Ray = preload("res://scripts/traps/trap_ray.gd")
const Dropper = preload("res://scripts/traps/trap_seesaw_dropper.gd")
const Blaster = preload("res://scripts/traps/trap_wind_blaster.gd")
const Kicker = preload("res://studies/stun_kicker.gd")

## The ladder's columns, in shares of the stun's fall.
const RUNGS := [0.5,0.75,0.95,1.0,1.25,1.6,2.0,3.0]
const DECK_WIDE := 10.0
const END_DECK := 8.0
## Where each station's ground is (x).
const LADDER_X := 0.0
const BLAST_X := 80.0
const CHAIN_X := 130.0
## The chain's seesaw is this many stun falls under the ray's stop.
const SEESAW_UNDER := 1.5

var traps: Node3D
var ray: Node3D
var seesaw: Node3D
var blaster: Node3D
var kicker: Node3D
var _both: Node
var _stun_label: Label
var _knobs := {}

## Steps the traps from the study's one slot.
class Both extends Node:
	var parts: Array = []
	func before(delta: float) -> void:
		for p: Node in parts: p.before(delta)
	func after(delta: float, events: Dictionary) -> void:
		for p: Node in parts: p.after(delta,events)
	func pose(figure: Node3D) -> void:
		for p: Node in parts: p.pose(figure)

func _ready() -> void:
	pack = "stun_yard"
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if not arg.begins_with("--knob="): continue
		var pair := arg.trim_prefix("--knob=")
		var value := pair.get_slice("=",1)
		var parsed: Variant = value
		if value.is_valid_float(): parsed = value.to_float()
		elif value == "true" or value == "false": parsed = value == "true"
		_knobs[pair.get_slice("=",0)] = parsed
	for key: String in _knobs:
		if key in motor: motor.set(key,_knobs[key])
		else: push_warning("stun yard: the motor has no knob %s" % key)
	super._ready()

## The stun's fall at the wanderer's size.
static func stun_fall() -> float:
	return Trap.pilot().fall_stun_height()

func _load_pack() -> void:
	stations = []
	var h := stun_fall()
	lost = -h*SEESAW_UNDER-15.0
	# The ladder: a deck, its columns along its north side.
	var parts: Array = [["box",Rect2(LADDER_X-9.0,-8.0,18.0,18.0),-1.0,0.0,"pad"],
		["label",Vector3(LADDER_X,0.6,8.5),"the drop ladder · stun from %.1f m" % h]]
	for i in range(RUNGS.size()):
		var x: float = LADDER_X-7.0+2.0*i
		var top: float = h*float(RUNGS[i])
		parts.append(["box",Rect2(x-0.8,-7.6,1.6,1.6),-1.0,top,"grey"])
		parts.append(["label",Vector3(x,top+1.2,-6.8),"%.1f m\n%.2fx" % [top,RUNGS[i]]])
		stations.append({"key":i+1,"name":"%.2fx" % RUNGS[i],"spawn":Vector3(x,top,-6.6),"face":Vector2(0.0,1.0),"parts":[]})
	stations[0].parts = parts
	stations[0]["sign"] = Vector3(LADDER_X,h*3.0+2.0,-7.0)
	# The blaster's lane, as the trap yard lays it: a floor a stun's fall down.
	blaster = Blaster.new()
	var b_long: float = blaster.length()
	var b_run: float = blaster.run_up()
	var drop: float = h
	stations.append({"key":10,"name":"the blaster","spawn":Vector3(BLAST_X,0.0,b_run),"face":Vector2(0.0,-1.0),"sign":Vector3(BLAST_X,3.0,b_run+2.0),
		"parts":[["box",Rect2(BLAST_X-DECK_WIDE*0.5,0.0,DECK_WIDE,b_run+4.0),-1.0,0.0,"pad"],
			["box",Rect2(BLAST_X-DECK_WIDE*0.5,-b_long-END_DECK,DECK_WIDE,END_DECK),-1.0,0.0,"pad"],
			["box",Rect2(BLAST_X-DECK_WIDE*2.0,-b_long-2.0,DECK_WIDE*4.0,b_long+4.0),-drop-1.0,-drop,"floor"],
			["label",Vector3(BLAST_X+DECK_WIDE,-drop+0.6,-b_long*0.5),"floor: %.1f m down" % drop]]})
	# The chain: the ray's lane, the kicker on its start deck, the seesaw
	# dropper under the ray's stop, a ledge each end of it.
	ray = Ray.new()
	ray.configure({"dwell":8.0})
	var r_long: float = ray.length()
	var r_run: float = ray.run_up()
	seesaw = Dropper.new()
	var stop := Vector3(CHAIN_X+ray.line_x(),0.0,float(ray.knob("board_z")))
	var s_long: float = seesaw.length()
	var s_at := Vector3(stop.x,-h*SEESAW_UNDER,stop.z+s_long*0.5)
	seesaw.position = s_at
	stations.append({"key":11,"name":"the chain: kicker, Sky Ray, seesaw","spawn":Vector3(CHAIN_X-2.5,0.0,r_run),"face":Vector2(1.0,0.0),
		"sign":Vector3(CHAIN_X,3.0,r_run+3.0),
		"parts":[["box",Rect2(CHAIN_X-DECK_WIDE*0.5,0.0,DECK_WIDE,r_run+4.0),-1.0,0.0,"pad"],
			["box",Rect2(CHAIN_X-DECK_WIDE*0.5,-r_long-END_DECK,DECK_WIDE,END_DECK),-1.0,0.0,"pad"],
			["box",Rect2(s_at.x-2.5,s_at.z,5.0,3.0),s_at.y-1.0,s_at.y,"pad"],
			["box",Rect2(s_at.x-2.5,s_at.z-s_long-3.0,5.0,3.0),s_at.y-1.0,s_at.y,"pad"],
			["label",Vector3(s_at.x+3.5,s_at.y+1.0,s_at.z-s_long*0.5),"seesaw: %.1f m under the ray" % (h*SEESAW_UNDER)]]})
	kicker = Kicker.new()
	kicker.position = Vector3(CHAIN_X+1.5,0.0,r_run)
	ray.position = Vector3(CHAIN_X,0.0,0.0)
	blaster.position = Vector3(BLAST_X,0.0,0.0)
	start = stations[3].spawn
	start_face = stations[3].face
	_last_stood = start

func _build_room() -> void:
	super._build_room()
	traps = TrapField.new()
	add_child(traps)
	traps.attach(self)
	for trap: Node3D in [blaster,ray,seesaw,kicker]: traps.add(trap)
	kicker.aim = ray.body
	_both = Both.new()
	_both.parts = [traps]
	add_child(_both)
	foot_pieces = _both
	motor.air = traps._air
	_stun_label = Label.new()
	_stun_label.anchor_left = 1.0
	_stun_label.anchor_right = 1.0
	_stun_label.offset_left = -520.0
	_stun_label.offset_right = -16.0
	_stun_label.offset_top = 12.0
	_stun_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stun_label.add_theme_font_size_override("font_size",20)
	_stun_label.add_theme_color_override("font_outline_color",Color.BLACK)
	_stun_label.add_theme_constant_override("outline_size",6)
	var layer := CanvasLayer.new()
	layer.add_child(_stun_label)
	add_child(layer)

## Set down anywhere: the traps as built.
func place(at: Vector3, face: Vector2) -> void:
	if traps != null: traps.reset()
	super.place(at,face)

## The tech on or off (T), said on screen.
func toggle_tech() -> void:
	motor.tech = not motor.tech
	_say("tech: %s (T)" % ("ON: a press just before a surface recovers" if motor.tech else "off: poise only"))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_T and not _tuning():
		toggle_tech()
		return
	super._unhandled_input(event)

func tick(delta: float) -> void:
	super.tick(delta)
	if _stun_label != null: _stun_label.text = stun_line()

## The stun's state in a line or two: the tech, the state, the clocks.
func stun_line() -> String:
	var lines := PackedStringArray(["tech %s (T)" % ("ON" if motor.tech else "off")])
	if motor.move == "tumble":
		if motor.grounded: lines.append("DOWN (%s) %.1f s" % [motor.stunned,maxf(motor._down,0.0)])
		else: lines.append("STUNNED · poise in %.2f s%s" % [motor.poise_left()," · tech armed" if motor.tech_armed() else ""])
	elif motor.move == "roll": lines.append("roll")
	var fell := motor._fall_top-motor.feet.y
	if not motor.grounded and fell > 0.5: lines.append("falling %.1f m (stun from %.1f)" % [fell,motor.fall_stun_height()])
	return "\n".join(lines)

func _hint_text() -> String:
	return "Stun yard · 1-8 the drop ladder (step off) · 0 the blaster · - the chain (stand on the orange plate) · X twirl: just before a hard landing, the roll · knocked: no control till your poise is back, then sail/twirl · T tech on/off · R start · F1 numbers · Esc mouse"
