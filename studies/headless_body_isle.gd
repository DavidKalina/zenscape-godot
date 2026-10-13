extends "res://studies/character_study.gd"
## The headless body's study (docs/design/roguelike/headless-body-round1.md,
## round 2: headless-body-round2.md): greybox isles in open sky (the
## character study's grey structure, as the enemy yard is), the inhaler head
## (scripts/enemies/inhaler_head.gd) drifting its ring on the highest, and its
## lost body (scripts/enemies/headless_body.gd) to find it. The body comes up
## a cliff: it is spawned on a cliff face under a lip (`CLIFFS`), out of the
## walker's sight, and hauls itself over (the spawner, shared with the
## generator: scripts/enemies/body_spawner.gd). Its way, if it hears right:
##   the low isle (A, top 0)  ->  climbs the mesa's south face (B, 16 m)
##   -> jumps the 6 m gap ledge to ledge onto the step (E, 16 m)
##   -> the 12 m gap on to the far pillar (F, 16 m) is too wide: it drops
##      onto the shelf (C, top 6) instead
##   -> climbs F's south face, jumps the 4 m gap up onto the crown (D, 17 m),
##      where the head is.
## The walker starts on the low isle facing its south rim, where the body
## comes up. A ramp up the west side of the mesa and one up from the shelf
## to the crown let him follow on foot (the pocket sail glides the rest).
##   R   back to the start, the head back, the body gone (it comes up again)
##   G   a body up a cliff now (the head's one body: the old one goes)
##   F1  numbers (the body's state, its finds, the head's state, the spawns)
##   godot --path . res://studies/headless_body_isle.tscn -- --no-title
##     [--body-knob=<knob>=<value>] [--head-knob=<knob>=<value>]
##     [--spawn-knob=<knob>=<value>] (repeatable)
##     [--body-start=stand] (the body stood on A at the start, as round 1)
## Placeholder sounds: synthesized thumps, a grind, a whoosh.
const EnemyField = preload("res://scripts/enemies/enemy_field.gd")
const InhalerHead = preload("res://scripts/enemies/inhaler_head.gd")
const HeadlessBody = preload("res://scripts/enemies/headless_body.gd")
const BodySpawner = preload("res://scripts/enemies/body_spawner.gd")
const EnemyYard = preload("res://studies/enemy_yard.gd")

const ISLE_LOST := -40.0
const UNDER := -20.0
## The isles: [name, rect (x, z), top].
const ISLES := [
	["A  the low isle",Rect2(-20.0,-10.0,40.0,36.0),0.0],
	["B  the mesa",Rect2(-10.0,-24.0,20.0,18.0),16.0],
	["C  the shelf",Rect2(-24.0,-74.0,48.0,46.0),6.0],
	["E  the step",Rect2(-10.0,-40.0,20.0,10.0),16.0],
	["F  the far pillar",Rect2(-10.0,-64.0,20.0,12.0),16.0],
	["D  the crown",Rect2(-10.0,-98.0,20.0,30.0),17.0],
]
## The walker's ramps (low middle edge, high middle edge, width).
const RAMPS := [
	[Vector3(-12.0,0.0,24.0),Vector3(-12.0,16.0,-14.0),4.0],
	[Vector3(-12.0,6.0,-44.0),Vector3(-12.0,17.0,-80.0),4.0],
]
## Round 1's stood start (`--body-start=stand`).
const BODY_AT := Vector3(0.0,0.0,16.0)
const HEAD_AT := Vector3(0.0,17.0,-83.0)
const PILOT_AT := Vector3(9.0,0.0,21.0)
## Where a body comes up a cliff: [name, the lip over the face (x, top, z),
## the face's outward way (x, z)]. The first is by the walker's start.
const CLIFFS := [
	["A south",Vector3(-6.0,0.0,26.0),Vector2(0.0,1.0)],
	["A west",Vector3(-20.0,0.0,6.0),Vector2(-1.0,0.0)],
	["A east",Vector3(20.0,0.0,4.0),Vector2(1.0,0.0)],
	["B east",Vector3(10.0,16.0,-18.0),Vector2(1.0,0.0)],
	["C east",Vector3(24.0,6.0,-50.0),Vector2(1.0,0.0)],
	["C west",Vector3(-24.0,6.0,-60.0),Vector2(-1.0,0.0)],
	["D east",Vector3(10.0,17.0,-86.0),Vector2(1.0,0.0)],
]
## The head's voices: [seconds, tone (Hz, 0 none), tone at the end, noise
## share, low-pass (0-1), attack (s), tremolo (Hz, 0 none)] (enemy_yard.gd
## `_synth`). The body's are BodySpawner.VOICES.
const VOICES := {
	"head_grind":[0.9,0.0,0.0,1.0,0.07,0.05,13.0],
	"head_inhale":[3.0,0.0,0.0,1.0,0.22,0.9,0.0],
	"head_yank":[0.35,0.0,0.0,1.0,0.4,0.01,0.0],
	"head_gulp":[0.45,70.0,40.0,0.4,0.15,0.005,0.0],
	"head_blast":[0.9,0.0,0.0,1.0,0.55,0.005,0.0],
}

var enemies: Node
## The cliff spawns (scripts/enemies/body_spawner.gd, its RULES): a body
## comes up on its own once the head has had none for `wait` s (the start,
## after R, after one falls), at the nearest cliff that is `near` to `far`
## m from him (flat), its lip within `level` m of his feet's height (he is
## up on that isle), within `view` rad of where the camera looks (he will
## see it come over), and, with `hidden` 1, out of the camera's sight (the
## cliff hides it). `natural` 0: only G spawns. `--spawn-knob=` sets them.
var spawner: Node
var spawn_knobs := {}
var _stand := false
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
		if arg == "--body-start=stand": _stand = true
		for pair in [["--body-knob=",_body_knobs],["--head-knob=",_head_knobs],["--spawn-knob=",spawn_knobs]]:
			if arg.begins_with(pair[0]):
				var kv: String = arg.trim_prefix(pair[0])
				pair[1][kv.get_slice("=",0)] = float(kv.get_slice("=",1))
	super._ready()

func _load_pack() -> void:
	start = PILOT_AT
	var look_at: Vector3 = BODY_AT if _stand else CLIFFS[0][1]
	start_face = Vector2(look_at.x-PILOT_AT.x,look_at.z-PILOT_AT.z).normalized()
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
	if _stand: enemies.spawn(HeadlessBody,BODY_AT,Vector2(0.0,-1.0),_body_knobs)
	var head_knobs := {"ring":ground.head_top*5.5}
	head_knobs.merge(_head_knobs,true)
	enemies.spawn(InhalerHead,HEAD_AT,Vector2(0.0,1.0),head_knobs)
	spawner = BodySpawner.new()
	add_child(spawner)
	spawner.setup(self,enemies,spawn_knobs,_body_knobs)
	spawner.add_head(HEAD_AT,CLIFFS)

func stone_body() -> Node3D:
	return spawner.body_of(0) if spawner != null else null

func stone_head() -> Node3D:
	for e in enemies.enemies:
		if is_instance_valid(e) and e.has_method("mouth"): return e
	return null

## Set down, the head back as it began (and the body, if it stood at the
## start; else it comes up a cliff again).
func place(at: Vector3, face: Vector2) -> void:
	super.place(at,face)
	if enemies != null: enemies.reset()
	if figure != null: figure.visible = true
	if spawner != null:
		for h: Dictionary in spawner.heads: h.bodiless = 0.0

## The camera shakes with its landings and its steps; a body comes up a
## cliff when the rules say.
func tick(delta: float) -> void:
	super.tick(delta)
	if spawner == null: return
	spawner.step(delta)
	spawner.shake(camera)

## G: a body up the best cliff now.
func spawn_on_demand() -> Node3D:
	return spawner.spawn_on_demand(0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_G and not _name_panel.visible:
		spawn_on_demand()
		return
	super._unhandled_input(event)

# --- The HUD and the sounds ---------------------------------------------------------------

func _hint_text() -> String:
	return "Headless body: its stone body comes up a cliff and hunts its head (on the crown, D) · it listens, climbs what's in its way, jumps narrow gaps ledge to ledge, drops down wide ones · its landings send a shockwave (jump it) · G a body up a cliff now · R start · F1 numbers · Esc mouse"

func _show_hud() -> void:
	super._show_hud()
	if not _hud.visible or enemies == null: return
	var lines := PackedStringArray([_hud.text,""])
	var b := stone_body()
	var h := stone_head()
	if b != null:
		var to := (h.global_position-b.global_position).length() if h != null else -1.0
		lines.append("body  %s %.1fs · %s · %.1f m/s · y %.1f · to head %.1f m · climbs %d · leaps %d (jumps %d, last %s) · listens %d" % [b.state,b.state_t,"whole" if b.whole else ("has it" if b.homed else "searching"),Vector2(b.vel.x,b.vel.z).length(),b.position.y,to,b.climbs,b.leaps,b.jumps,b.leap_kind if b.leap_kind != "" else "-",b.listens])
		lines.append("shocks %d · threw you %d · jump gap %.1f m · clip %s" % [b.shocks,b.shock_hits,b.jump_gap(),b.look.clip_now()])
	else:
		var next: int = spawner.pick_cliff(0,true)
		lines.append("body  none yet (%.1f s) · next cliff %s" % [float(spawner.heads[0].bodiless),spawner.heads[0].cliffs[next][0] if next >= 0 else "none fits"])
	if h != null: lines.append("head  %s %.1fs · draw %.2f · pull on him %.1f m/s" % [h.state,h.state_t,h.draw_share,h.pulling])
	lines.append("cliff spawns %d (last %s) · fallen and gone: %d" % [spawner.spawns,spawner.last_cliff if spawner.last_cliff != "" else "-",enemies.gone_count])
	_hud.text = "\n".join(lines)

func _voice(sound_name: StringName, at: Vector3) -> void:
	var key := String(sound_name)
	var spec: Variant = VOICES.get(key,BodySpawner.VOICES.get(key))
	if spec == null: return
	if not _voices.has(key): _voices[key] = EnemyYard._synth(spec)
	var player := AudioStreamPlayer3D.new()
	player.stream = _voices[key]
	player.position = at
	player.unit_size = 14.0
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
