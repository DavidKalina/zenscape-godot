extends "res://studies/aqueduct_isle.gd"
## The inhaler head's study (docs/design/roguelike/inhaler-head.md): the
## aqueduct isle (studies/aqueduct_isle.gd: its look, light, grass, sky and
## life; no lodestone, no hall chain, no dragon) with the inhaler head
## (scripts/enemies/inhaler_head.gd) drifting its round over the open turf
## east of the aqueduct and out past the east rim, and kit stone to hide
## behind: two clustered piers, a wall, a carved chest and a fallen pier.
## The wanderer starts on the turf's south side, out of its sight.
##   R   back to the start, the head back to its round too
##   F1  numbers (the head's state, its draw and its pull on him)
##   godot --path . res://studies/inhaler_isle.tscn -- --no-title
##     [--head-at=x,z] [--head-knob=<knob>=<value>] (repeatable, e.g.
##     --head-knob=pull=9 --head-knob=reach=16)
## Placeholder sounds: the enemy yard's synthesized ones (a grind, a long
## hiss, a gulp, a whoosh).
const EnemyField = preload("res://scripts/enemies/enemy_field.gd")
const InhalerHead = preload("res://scripts/enemies/inhaler_head.gd")
const EnemyYard = preload("res://studies/enemy_yard.gd")

## Where the head is set down (x, z) and its round (x, z): over the turf,
## out over the void past the east rim, back.
const HEAD_AT := Vector2(118.0,-6.0)
const ROUTE := [Vector2(118.0,-17.0),Vector2(125.0,-9.0),Vector2(133.0,-2.0),Vector2(124.0,8.0),Vector2(112.0,-5.0)]
## Where the wanderer starts (x, z), facing the head.
const START_AT := Vector2(110.0,11.0)
## The cover: [piece, seed, (x, z), yaw, weathered].
const COVER := [
	["pier",3,Vector2(113.0,-1.0),0.2,0.2],
	["pier",8,Vector2(121.5,4.5),-0.4,0.5],
	["wall",5,Vector2(115.0,-15.0),0.1,0.4],
	["tomb_chest",2,Vector2(124.0,-12.0),0.6,0.3],
	["fallen_pier",4,Vector2(108.5,3.5),1.1,0.5],
]
const VOICES := {
	"head_grind":[0.9,0.0,0.0,1.0,0.07,0.05,13.0],
	"head_inhale":[3.0,0.0,0.0,1.0,0.22,0.9,0.0],
	"head_yank":[0.35,0.0,0.0,1.0,0.4,0.01,0.0],
	"head_gulp":[0.45,70.0,40.0,0.4,0.15,0.005,0.0],
	"head_blast":[0.9,0.0,0.0,1.0,0.55,0.005,0.0],
}

var enemies: Node
var head: Node3D
var cover: Node3D
var _slot: Node
var _voices := {}
var _head_at := HEAD_AT
var _head_knobs := {}

## Steps what stood in the study's slot and the enemies, and hides the
## figure while the head holds him.
class Slot extends Node:
	var parts: Array = []
	var study: Node3D
	func before(delta: float) -> void:
		for p: Node in parts: p.before(delta)
	func after(delta: float, events: Dictionary) -> void:
		for p: Node in parts: p.after(delta,events)
	func pose(figure: Node3D) -> void:
		for p: Node in parts: p.pose(figure)
		var held := false
		for e in study.enemies.enemies:
			if is_instance_valid(e) and e.get("swallowed"): held = true
		figure.visible = not held
	func frame(camera: Camera3D, delta: float) -> void:
		for p: Node in parts:
			if p.has_method("frame"): p.frame(camera,delta)

func _ready() -> void:
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg.begins_with("--head-at="):
			var xz := arg.get_slice("=",1).split(",")
			if xz.size() == 2: _head_at = Vector2(float(xz[0]),float(xz[1]))
		elif arg.begins_with("--head-knob="):
			var pair := arg.trim_prefix("--head-knob=")
			_head_knobs[pair.get_slice("=",0)] = float(pair.get_slice("=",1))
	chain_on = false
	dragon_roost = false
	_no_lode = true
	isle_ready.connect(_stand_head,CONNECT_ONE_SHOT)
	super._ready()

func _load_pack() -> void:
	super._load_pack()
	start = Vector3(START_AT.x,Art.TOP,START_AT.y)
	start_face = (HEAD_AT-START_AT).normalized()
	_last_stood = start

## The plane parks where the aqueduct isle parks it, out of the head's
## ground.
func plane_home() -> Vector4:
	var was := start
	start = Art.START
	var home := super.plane_home()
	start = was
	return home

## The cover and the head, once the isle stands (on its turf).
func _stand_head() -> void:
	cover = Node3D.new()
	cover.name = "Cover"
	add_child(cover)
	for c: Array in COVER:
		var piece := RuinKit.piece(c[0],c[1],c[4])
		var at: Vector2 = c[2]
		piece.transform = Transform3D(Basis(Vector3.UP,float(c[3])),Vector3(at.x,_turf_y(at),at.y))
		cover.add_child(piece)
	start.y = _turf_y(START_AT)+0.05
	enemies = EnemyField.new()
	enemies.study = self
	enemies.motor = motor
	enemies.lost = float(lost)
	enemies.sound_hook = _voice
	add_child(enemies)
	var route: Array = []
	for p: Vector2 in ROUTE: route.append(Vector3(p.x,0.0,p.y))
	var knobs := {"route":route}
	knobs.merge(_head_knobs,true)
	var at := Vector3(_head_at.x,_turf_y(_head_at),_head_at.y)
	head = enemies.spawn(InhalerHead,at,(START_AT-_head_at).normalized(),knobs)
	_slot = Slot.new()
	_slot.study = self
	if foot_pieces != null: _slot.parts.append(foot_pieces)
	_slot.parts.append(enemies)
	add_child(_slot)
	foot_pieces = _slot
	# Its air in the pocket sail's wind and the plane's.
	var base_air: Callable = motor.air
	motor.air = func(p: Vector3) -> Dictionary:
		var here: Dictionary = base_air.call(p) if base_air.is_valid() else {}
		var wind := _head_air(p,"sail_wind")
		if wind == Vector3.ZERO: return here
		var out := here.duplicate()
		out["wind"] = (here.get("wind",Vector3.ZERO) as Vector3)+wind
		return out
	var base_plane: Callable = plane_air
	plane_air = func(p: Vector3) -> Dictionary:
		var here: Dictionary = base_plane.call(p) if base_plane.is_valid() else {}
		var wind := _head_air(p,"plane_wind")
		if wind == Vector3.ZERO: return here
		var out := here.duplicate()
		out["wind"] = (here.get("wind",Vector3.ZERO) as Vector3)+wind
		return out
	respawn()
	print("inhaler isle: the head at %s, %d cover pieces" % [str(at),COVER.size()])

func _head_air(p: Vector3, how: String) -> Vector3:
	if enemies == null: return Vector3.ZERO
	var sum := Vector3.ZERO
	for e in enemies.enemies:
		if is_instance_valid(e) and e.has_method(how): sum += e.call(how,p)
	return sum

## The turf's height at (x, z).
func _turf_y(at: Vector2) -> float:
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(at.x,Art.TOP+40.0,at.y),Vector3(at.x,Art.TOP-40.0,at.y),TURF_LAYER))
	return (hit.position as Vector3).y if not hit.is_empty() else Art.TOP

## Set down, the head back on its round.
func place(at: Vector3, face: Vector2) -> void:
	super.place(at,face)
	if enemies != null:
		enemies.reset()
		head = enemies.enemies[0] if not enemies.enemies.is_empty() else null
	if figure != null: figure.visible = true

func _show_hud() -> void:
	super._show_hud()
	if _hud == null or not _hud.visible or enemies == null: return
	var lines := PackedStringArray([_hud.text,""])
	for e in enemies.enemies:
		if not is_instance_valid(e): continue
		lines.append("head  %s %.1fs · draw %.2f · pull on him %.1f m/s · gulps %d" % [e.state,e.state_t,e.draw_share,e.pulling,e.gulps])
	_hud.text = "\n".join(lines)

## Plays enemy sound `sound_name` at `at` (a short synthesized placeholder).
func _voice(sound_name: StringName, at: Vector3) -> void:
	var key := String(sound_name)
	if not VOICES.has(key): return
	if not _voices.has(key): _voices[key] = EnemyYard._synth(VOICES[key])
	var player := AudioStreamPlayer3D.new()
	player.stream = _voices[key]
	player.position = at
	player.unit_size = 10.0
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
