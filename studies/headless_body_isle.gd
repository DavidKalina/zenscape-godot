extends "res://studies/character_study.gd"
## The headless body's study (docs/design/roguelike/headless-body-round1.md):
## greybox isles in open sky (the character study's grey structure, as the
## enemy yard is), the inhaler head (scripts/enemies/inhaler_head.gd) drifting
## its ring on the highest, and its lost body (scripts/enemies/headless_body.gd)
## set down on the lowest, to find it. Its way, if it hears right:
##   the low isle (A, top 0)  ->  climbs the mesa's south face (B, 16 m)
##   -> leaps the gap north, down onto the shelf (C, top 6)
##   -> climbs the crown's south face (D, top 18), where the head is.
## The walker starts on the low isle beside it. A ramp up the west side of
## the mesa and one up the crown's let him follow on foot (the pocket sail
## glides the rest).
##   R   back to the start, the body and the head back as they began
##   F1  numbers (the body's state, its finds, the head's state)
##   godot --path . res://studies/headless_body_isle.tscn -- --no-title
##     [--body-knob=<knob>=<value>] [--head-knob=<knob>=<value>] (repeatable)
## Placeholder sounds: synthesized thumps, a grind, a whoosh.
const EnemyField = preload("res://scripts/enemies/enemy_field.gd")
const InhalerHead = preload("res://scripts/enemies/inhaler_head.gd")
const HeadlessBody = preload("res://scripts/enemies/headless_body.gd")
const EnemyYard = preload("res://studies/enemy_yard.gd")

const ISLE_LOST := -40.0
const UNDER := -20.0
## The isles: [name, rect (x, z), top].
const ISLES := [
	["A  the low isle",Rect2(-20.0,-10.0,40.0,36.0),0.0],
	["B  the mesa",Rect2(-10.0,-24.0,20.0,18.0),16.0],
	["C  the shelf",Rect2(-24.0,-56.0,48.0,24.0),6.0],
	["D  the crown",Rect2(-10.0,-76.0,20.0,30.0),18.0],
]
## The walker's ramps (low middle edge, high middle edge, width).
const RAMPS := [
	[Vector3(-12.0,0.0,24.0),Vector3(-12.0,16.0,-14.0),4.0],
	[Vector3(-12.0,6.0,-33.0),Vector3(-12.0,18.0,-60.0),4.0],
]
const BODY_AT := Vector3(0.0,0.0,16.0)
const HEAD_AT := Vector3(0.0,18.0,-61.0)
const PILOT_AT := Vector3(9.0,0.0,21.0)
## [seconds, tone (Hz, 0 none), tone at the end, noise share, low-pass (0-1),
## attack (s), tremolo (Hz, 0 none)] (enemy_yard.gd `_synth`).
const VOICES := {
	"body_step":[0.3,45.0,30.0,0.5,0.12,0.004,0.0],
	"body_listen":[0.9,0.0,0.0,1.0,0.06,0.2,6.0],
	"body_found":[0.7,90.0,60.0,0.3,0.3,0.05,0.0],
	"body_grip":[0.25,0.0,0.0,1.0,0.35,0.005,18.0],
	"body_windup":[0.8,0.0,0.0,1.0,0.1,0.3,10.0],
	"body_leap":[0.5,0.0,0.0,1.0,0.5,0.02,0.0],
	"body_land":[0.9,40.0,25.0,0.6,0.15,0.003,0.0],
	"body_reach":[1.2,0.0,0.0,1.0,0.07,0.3,13.0],
	"body_whole":[1.0,70.0,110.0,0.3,0.25,0.01,0.0],
	"head_grind":[0.9,0.0,0.0,1.0,0.07,0.05,13.0],
	"head_inhale":[3.0,0.0,0.0,1.0,0.22,0.9,0.0],
	"head_yank":[0.35,0.0,0.0,1.0,0.4,0.01,0.0],
	"head_gulp":[0.45,70.0,40.0,0.4,0.15,0.005,0.0],
	"head_blast":[0.9,0.0,0.0,1.0,0.55,0.005,0.0],
}

var enemies: Node
var _voices := {}
var _body_knobs := {}
var _head_knobs := {}

## Hides the figure while the head holds him, and steps the enemies.
class Slot extends Node:
	var field: Node
	func before(delta: float) -> void: field.before(delta)
	func after(delta: float, events: Dictionary) -> void: field.after(delta,events)
	func pose(figure: Node3D) -> void:
		var held := false
		for e in field.enemies:
			if is_instance_valid(e) and e.get("swallowed"): held = true
		figure.visible = not held

func _ready() -> void:
	pack = "headless_body"
	for arg in preload("res://scripts/launch_args.gd").user_args():
		for pair in [["--body-knob=",_body_knobs],["--head-knob=",_head_knobs]]:
			if arg.begins_with(pair[0]):
				var kv: String = arg.trim_prefix(pair[0])
				pair[1][kv.get_slice("=",0)] = float(kv.get_slice("=",1))
	super._ready()

func _load_pack() -> void:
	start = PILOT_AT
	start_face = Vector2(BODY_AT.x-PILOT_AT.x,BODY_AT.z-PILOT_AT.z).normalized()
	lost = ISLE_LOST
	_last_stood = start
	var parts := []
	for i in ISLES.size():
		var isle: Array = ISLES[i]
		var r: Rect2 = isle[1]
		parts.append(["box",r,UNDER,isle[2],"floor" if i%2 == 0 else "wall"])
		parts.append(["label",Vector3(r.get_center().x,float(isle[2])+0.6,r.end.y-1.2),"%s · %d m" % [isle[0],int(isle[2])]])
	for ramp: Array in RAMPS: parts.append(["ramp",ramp[0],ramp[1],ramp[2],"grey"])
	stations = [{"key":1,"name":"Headless body","spawn":PILOT_AT,"face":start_face,"sign":Vector3(14.0,4.0,24.0),"parts":parts}]

func _build_room() -> void:
	super._build_room()
	enemies = EnemyField.new()
	enemies.study = self
	enemies.motor = motor
	enemies.lost = lost
	enemies.sound_hook = _voice
	add_child(enemies)
	var slot := Slot.new()
	slot.field = enemies
	add_child(slot)
	foot_pieces = slot
	# The body first, so the head reads its neck where it is this frame.
	enemies.spawn(HeadlessBody,BODY_AT,Vector2(0.0,-1.0),_body_knobs)
	var head_knobs := {"ring":ground.head_top*5.5}
	head_knobs.merge(_head_knobs,true)
	enemies.spawn(InhalerHead,HEAD_AT,Vector2(0.0,1.0),head_knobs)

func stone_body() -> Node3D:
	for e in enemies.enemies:
		if is_instance_valid(e) and e.get("whole") != null: return e
	return null

func stone_head() -> Node3D:
	for e in enemies.enemies:
		if is_instance_valid(e) and e.has_method("mouth"): return e
	return null

## Set down, the body and the head back as they began.
func place(at: Vector3, face: Vector2) -> void:
	super.place(at,face)
	if enemies != null: enemies.reset()
	if figure != null: figure.visible = true

## The camera shakes with its landings and its steps.
func tick(delta: float) -> void:
	super.tick(delta)
	var b := stone_body()
	if b == null or camera == null: return
	var near := clampf(1.0-camera.global_position.distance_to(b.global_position)/60.0,0.0,1.0)
	var q: float = b.quake*near
	if q > 0.001:
		var t := Time.get_ticks_msec()/1000.0
		camera.position += Vector3(sin(t*61.0),sin(t*53.0+1.0),sin(t*47.0+2.0))*q*0.5

func _hint_text() -> String:
	return "Headless body: its stone body hunts its head (on the crown, D) · it stops to listen, climbs what's in its way, leaps down gaps · walk into it moving and it shoves you · R start (both back) · F1 numbers · Esc mouse"

func _show_hud() -> void:
	super._show_hud()
	if not _hud.visible or enemies == null: return
	var lines := PackedStringArray([_hud.text,""])
	var b := stone_body()
	var h := stone_head()
	if b != null:
		var to := (h.global_position-b.global_position).length() if h != null else -1.0
		lines.append("body  %s %.1fs · %s · %.1f m/s · y %.1f · to head %.1f m · climbs %d · leaps %d · listens %d" % [b.state,b.state_t,"whole" if b.whole else ("has it" if b.homed else "searching"),Vector2(b.vel.x,b.vel.z).length(),b.position.y,to,b.climbs,b.leaps,b.listens])
	if h != null: lines.append("head  %s %.1fs · draw %.2f · pull on him %.1f m/s" % [h.state,h.state_t,h.draw_share,h.pulling])
	lines.append("fallen and gone: %d" % enemies.gone_count)
	_hud.text = "\n".join(lines)

func _voice(sound_name: StringName, at: Vector3) -> void:
	var key := String(sound_name)
	if not VOICES.has(key): return
	if not _voices.has(key): _voices[key] = EnemyYard._synth(VOICES[key])
	var player := AudioStreamPlayer3D.new()
	player.stream = _voices[key]
	player.position = at
	player.unit_size = 14.0
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
