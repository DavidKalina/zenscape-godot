extends "res://studies/character_study.gd"
## The stun yard (docs/design/stun/round1.md): greybox stations in open sky
## for playing the stun (scripts/pilot_motor.gd's header). The pilot is the
## character study's (this extends it): the same motor, figure, camera, F1
## numbers, F2 feel.
##   1-8  the drop ladder: columns of 0.5 to 3 times the stun's fall (its
##        height and share marked on each), stood on top facing the deck;
##        step off: under 1x a landing, from 1x laid down, longer the
##        higher (capped at 2x). Twirl (X) with the touch close: the roll.
##   9    the blast post: a deck with the dragon's air blast (scripts/
##        dragon_air_blast.gd) fired from a post off its side while you
##        stand on it; a hard hit (stunned the whole throw, then laid down
##        dizzy) onto the floor a stun's fall below.
## T turns the tech on and off live (shown top right with the stun's state).
## `--knob=<motor var>=<value>` (repeatable) sets the motor's stun knobs,
## e.g. `--knob=tech=true --knob=poise=0.7 --knob=tumble_immune=0.3`.
##   godot --path . res://studies/stun_yard.tscn -- --no-title
const DragonAirBlast = preload("res://scripts/dragon_air_blast.gd")
const WorldScale = preload("res://scripts/world_scale.gd")

## The ladder's columns, in shares of the stun's fall.
const RUNGS := [0.5,0.75,0.95,1.0,1.25,1.6,2.0,3.0]
const DECK_WIDE := 10.0
## Where each station's ground is (x).
const LADDER_X := 0.0
const BLAST_X := 100.0
## The blast post: its mouth off the deck's side (m out along x, up), and
## the floor under the deck, in stun falls.
const POST_OUT := 36.0
const POST_UP := 14.0
const FLOOR_UNDER := 1.0

var post: BlastPost
var _stun_label: Label
var _knobs := {}

## The blast post: the air blast fired at the pilot while he stands on its
## deck (the post its source), stepped from the study's one slot.
class BlastPost extends Node:
	var yard: Node3D
	var blast: Node3D
	var mouth := Vector3.ZERO
	## The deck (x, z) he is shot at on.
	var deck := Rect2()
	var knocks := 0
	func before(_delta: float) -> void:
		pass
	func after(delta: float, _events: Dictionary) -> void:
		var m: RefCounted = yard.motor
		var feet: Vector3 = m.feet
		var on_deck: bool = deck.has_point(Vector2(feet.x,feet.z)) and feet.y > -0.5 and m.move != "tumble"
		var aim: Vector3 = feet+Vector3.UP*0.55*DragonAirBlast.walker_tall()
		var space: PhysicsDirectSpaceState3D = yard.get_world_3d().direct_space_state if yard.is_inside_tree() else null
		blast.advance(delta,space,on_deck,mouth,aim)
		var v: Vector3 = blast.pilot_knock(feet,m)
		if v != Vector3.ZERO:
			m.knock(v,blast,DragonAirBlast.STUN_DOWN)
			knocks += 1
	func pose(_figure: Node3D) -> void:
		pass
	func reset() -> void:
		blast.phase = "idle"
		blast.cooldown_left = 0.0
		blast.balls.clear()
		blast.shocks.clear()

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

## The stun's fall at the wanderer's size (the room is laid before the
## study sizes its motor).
static func stun_fall() -> float:
	var p := PilotMotor.new()
	p.set_size(WorldScale.wanderer)
	return p.fall_stun_height()

func _load_pack() -> void:
	stations = []
	var h := stun_fall()
	lost = -h*FLOOR_UNDER-15.0
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
	# The blast post: a deck, the post off its +x side, a floor below.
	var drop: float = h*FLOOR_UNDER
	var deck := Rect2(BLAST_X-DECK_WIDE*0.5,-DECK_WIDE*0.5,DECK_WIDE,DECK_WIDE)
	stations.append({"key":9,"name":"the blast post","spawn":Vector3(BLAST_X-2.0,0.0,0.0),"face":Vector2(1.0,0.0),"sign":Vector3(BLAST_X,3.0,DECK_WIDE*0.5+1.0),
		"parts":[["box",deck,-1.0,0.0,"pad"],
			["box",Rect2(BLAST_X-DECK_WIDE*7.0,-DECK_WIDE*3.0,DECK_WIDE*7.0,DECK_WIDE*6.0),-drop-1.0,-drop,"floor"],
			["box",Rect2(BLAST_X+POST_OUT-0.6,-0.6,1.2,1.2),-drop-1.0,POST_UP-1.0,"grey"],
			["label",Vector3(BLAST_X-DECK_WIDE,-drop+0.6,0.0),"floor: %.1f m down" % drop]]})
	post = BlastPost.new()
	post.name = "BlastPost"
	post.deck = Rect2(deck.position.x,deck.position.y,deck.size.x,deck.size.y)
	post.mouth = Vector3(BLAST_X+POST_OUT,POST_UP,0.0)
	start = stations[3].spawn
	start_face = stations[3].face
	_last_stood = start

func _build_room() -> void:
	super._build_room()
	post.yard = self
	var blast := DragonAirBlast.new()
	blast.publish = false
	post.blast = blast
	add_child(blast)
	add_child(post)
	foot_pieces = post
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

## Set down anywhere: the post's shots cleared.
func place(at: Vector3, face: Vector2) -> void:
	if post != null and post.blast != null: post.reset()
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
	return "Stun yard · 1-8 the drop ladder (step off) · 9 the blast post (stand on the deck) · X twirl: just before a hard landing, the roll · knocked: no control till your poise is back, then sail/twirl · T tech on/off · R start · F1 numbers · Esc mouse"
