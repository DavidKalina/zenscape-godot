extends "res://studies/character_study.gd"
## The headless body's study (docs/design/roguelike/headless-body-round1.md,
## round 2: headless-body-round2.md): greybox isles in open sky (the
## character study's grey structure, as the enemy yard is), the inhaler head
## (scripts/enemies/inhaler_head.gd) drifting its ring on the highest, and its
## lost body (scripts/enemies/headless_body.gd) to find it. The body comes up
## a cliff: it is spawned on a cliff face under a lip (`CLIFFS`), out of the
## walker's sight, and hauls itself over. Its way, if it hears right:
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
	"body_shock":[1.6,30.0,20.0,0.75,0.09,0.002,0.0],
	"body_reach":[1.2,0.0,0.0,1.0,0.07,0.3,13.0],
	"body_whole":[1.0,70.0,110.0,0.3,0.25,0.01,0.0],
	"head_grind":[0.9,0.0,0.0,1.0,0.07,0.05,13.0],
	"head_inhale":[3.0,0.0,0.0,1.0,0.22,0.9,0.0],
	"head_yank":[0.35,0.0,0.0,1.0,0.4,0.01,0.0],
	"head_gulp":[0.45,70.0,40.0,0.4,0.15,0.005,0.0],
	"head_blast":[0.9,0.0,0.0,1.0,0.55,0.005,0.0],
}

var enemies: Node
## The cliff spawns' rules (`--spawn-knob=`). A body comes up on its own
## once the head has had none for `wait` s (the start, after R, after one
## falls), at the nearest cliff that is: `near` to `far` m from him (flat),
## its lip within `level` m of his feet's height (he is up on that isle),
## within `view` rad of where the camera looks (he will see it come over),
## and, with `hidden` 1, out of the camera's sight (the cliff hides it).
## `natural` 0: only G spawns.
var spawn_knobs := {"wait":2.0,"near":8.0,"far":40.0,"level":3.5,"view":1.0,"hidden":1.0,"natural":1.0}
## Spawns made, the last cliff's name.
var spawns := 0
var last_cliff := ""
var _bodiless := 0.0
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

func stone_body() -> Node3D:
	for e in enemies.enemies:
		if is_instance_valid(e) and not e.gone and e.get("whole") != null: return e
	return null

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
	_bodiless = 0.0

## The camera shakes with its landings and its steps; a body comes up a
## cliff when the rules say.
func tick(delta: float) -> void:
	super.tick(delta)
	_spawner(delta)
	var b := stone_body()
	if b == null or camera == null: return
	var near := clampf(1.0-camera.global_position.distance_to(b.global_position)/60.0,0.0,1.0)
	var q: float = b.quake*near
	if q > 0.001:
		var t := Time.get_ticks_msec()/1000.0
		camera.position += Vector3(sin(t*61.0),sin(t*53.0+1.0),sin(t*47.0+2.0))*q*0.5

# --- Cliff spawns -----------------------------------------------------------------------

func _spawner(delta: float) -> void:
	if enemies == null or stone_body() != null:
		_bodiless = 0.0
		return
	_bodiless += delta
	if float(spawn_knobs.natural) < 0.5 or _bodiless < float(spawn_knobs.wait): return
	var i := pick_cliff(true)
	if i >= 0: spawn_climber(i)

## The cliff a body should come up now: the nearest one meeting every rule
## (`strict`), or, not strict (G), the nearest meeting the most (out of
## sight, then `near` to `far` m, then any); -1 none.
func pick_cliff(strict: bool) -> int:
	var best := -1
	var best_score := INF
	for i in CLIFFS.size():
		var lip: Vector3 = CLIFFS[i][1]
		var d := Vector2(lip.x-motor.feet.x,lip.z-motor.feet.z).length()
		var ranged := d >= float(spawn_knobs.near) and d <= float(spawn_knobs.far)
		var level := absf(motor.feet.y-lip.y) <= float(spawn_knobs.level)
		var hid := _cliff_hidden(i)
		var seen := _cliff_in_view(lip)
		var score := d
		if strict:
			if not (ranged and level and hid and seen): continue
		else:
			score += (0.0 if ranged else 1000.0)+(0.0 if hid else 500.0)+(0.0 if level else 200.0)+(0.0 if seen else 100.0)
		if score < best_score:
			best_score = score
			best = i
	return best

## Whether the camera's line to a body hanging on cliff `i` is blocked.
func _cliff_hidden(i: int) -> bool:
	if float(spawn_knobs.hidden) < 0.5 or camera == null: return true
	var lip: Vector3 = CLIFFS[i][1]
	var out: Vector2 = CLIFFS[i][2]
	var hands := lip+Vector3(out.x,0.0,out.y)*2.0-Vector3.UP*1.5
	var q := PhysicsRayQueryParameters3D.create(camera.global_position,hands,ground.mask)
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()

## Whether `lip` is within `view` rad of the camera's look (flat).
func _cliff_in_view(lip: Vector3) -> bool:
	if camera == null: return true
	var look := -camera.global_basis.z
	var to := lip-camera.global_position
	var a := Vector2(look.x,look.z)
	var b := Vector2(to.x,to.z)
	if a.length() < 0.01 or b.length() < 0.01: return true
	return absf(a.angle_to(b)) <= float(spawn_knobs.view)

## A body up cliff `i` now, the head's one body: the old one goes (and if
## it had its head, the head goes back to its ring).
func spawn_climber(i: int) -> Node3D:
	var h := stone_head()
	if h != null and h.perch != null:
		enemies.reset()
	for e in enemies.enemies.duplicate():
		if is_instance_valid(e) and e.get("whole") != null:
			enemies.enemies.erase(e)
			if e.get_parent() == enemies: enemies.remove_child(e)
			e.queue_free()
	var c: Array = CLIFFS[i]
	var b: Node3D = enemies.add(HeadlessBody,c[1],-(c[2] as Vector2),_body_knobs)
	# First in the field, so the head reads its neck where it is this frame.
	enemies.enemies.erase(b)
	enemies.enemies.push_front(b)
	b.cling(c[1],c[2])
	b.body.force_update_transform()
	spawns += 1
	last_cliff = c[0]
	_bodiless = 0.0
	return b

## G: a body up the best cliff now.
func spawn_on_demand() -> Node3D:
	var i := pick_cliff(true)
	if i < 0: i = pick_cliff(false)
	return spawn_climber(i) if i >= 0 else null

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
		lines.append("shocks %d · threw you %d · jump gap %.1f m" % [b.shocks,b.shock_hits,b.jump_gap()])
	else: lines.append("body  none yet (%.1f s) · next cliff %s" % [_bodiless,CLIFFS[pick_cliff(true)][0] if pick_cliff(true) >= 0 else "none fits"])
	if h != null: lines.append("head  %s %.1fs · draw %.2f · pull on him %.1f m/s" % [h.state,h.state_t,h.draw_share,h.pulling])
	lines.append("cliff spawns %d (last %s) · fallen and gone: %d" % [spawns,last_cliff if last_cliff != "" else "-",enemies.gone_count])
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
