extends "res://studies/character_study.gd"
## GREYBOX, Opus pass: the Warden's Well. Grey structure in open sky, the REAL
## pilot, two
## REAL ground-bound inhaler heads (scripts/enemies/inhaler_head.gd, round 2;
## the second smaller by its `size` knob, every other knob default) and, on B,
## the REAL headless body. The point is being spat from one head into another.
##   godot --path . res://studies/greybox/wardens_well.tscn -- --no-title
##   1-7     stations (below) · R back to the start (the heads back, the body gone)
##   B       the headless body on the dais (B again: it goes) · F1 numbers
## North is -z. The well steps DOWN: the dais (0 m), cell 1 (-4 m), the exit rim
## (-11 m). A blast flies further onto a lower floor, which is what buys each
## void its width (a head's blast lands only ~10 m out on the level).
## The relay: head 1 fires you dead north from the lip; your skid on cell 1 ends
## 3 m in front of head 2's mouth, square on its face, so head 2 notices you
## lying there, winds up (its own 1.8 s tell) and fires you west.
## The whole layout is the LAYOUT table: one entry per mass (the hall is ONE mass
## with a dais tier), each piece/head/station with its place and facing, so a
## terrain pass can rebuild it from the table (KitLand.island(spec)).
const EnemyField = preload("res://scripts/enemies/enemy_field.gd")
const InhalerHead = preload("res://scripts/enemies/inhaler_head.gd")
const HeadlessBody = preload("res://scripts/enemies/headless_body.gd")
const EnemyYard = preload("res://studies/enemy_yard.gd")

const SLAB := 3.0
const LOST_Y := -24.0
## Tier heights (m): the dais, cell 1 (and cell 2), the exit rim.
const Y_DAIS := 0.0
const Y_CELL := -4.0
const Y_EXIT := -11.0
## Head 1 sits on the dais facing north; you stand LIP m in front of its middle.
## At 6 m half a metre either side of its axis is inside its no-turn band
## (0.6 x lock_angle, 0.096 rad), so it fires dead north. Lip post W hides the
## lip's west approach until you are about that close to the axis.
const H1 := Vector3(0.0, Y_DAIS, 8.0)
const LIP := 6.0
## Head 2 sits on cell 1 east of where head 1's skid ends (x 0, z -14.9: the
## blast's 13 m flight down to cell 1 plus its 7 m skid), facing west at it.
const H2 := Vector3(4.5, Y_CELL, -14.9)
const LAYOUT := {
	## Masses. rect = (x, z, w, d), top = the base height; tiers = [rect, top]
	## laid over the base (the climbable steps); water = [rect, depth] over a rect.
	"masses": [
		{"name": "hall", "rect": Rect2(-20.0, 1.2, 40.0, 28.8), "top": Y_DAIS-0.4,
		 "tiers": [[Rect2(-12.0, 1.2, 24.0, 12.8), Y_DAIS]],
		 "water": [[Rect2(-20.0, 14.0, 40.0, 16.0), 0.3]],
		 "label": [Vector3(-12.0, 0.6, 20.0), "FLOODED ENTRY (wading) - the hall's drowned floor"]},
		{"name": "cell 1", "rect": Rect2(-3.5, -18.0, 12.0, 11.7), "top": Y_CELL, "tiers": [],
		 "label": [Vector3(5.5, Y_CELL+1.6, -8.0), "CELL 1  (4 m down the well)"]},
		{"name": "plank", "rect": Rect2(8.5, -16.0, 2.5, 2.0), "top": Y_CELL, "tiers": []},
		{"name": "cell 2", "rect": Rect2(11.0, -21.0, 10.0, 10.0), "top": Y_CELL, "tiers": [],
		 "label": [Vector3(16.0, Y_CELL+1.6, -16.0), "CELL 2  (cache; by the plank)"]},
		{"name": "exit rim", "rect": Rect2(-34.0, -34.0, 23.0, 29.0), "top": Y_EXIT, "tiers": [],
		 "label": [Vector3(-20.0, Y_EXIT+1.6, -12.0), "EXIT RIM  (7 m under cell 1; STAND-IN: the onward exit throw is not built)"]},
	],
	## Cover, kerbs and caches: kind cyl (at, radius, bottom, top) / box (rect, bottom, top).
	"pieces": [
		{"kind": "cyl", "name": "column W", "at": Vector2(-3.0, 5.6), "r": 1.0, "bottom": Y_DAIS, "top": Y_DAIS+4.5},
		{"kind": "cyl", "name": "column E", "at": Vector2(3.0, 5.6), "r": 1.0, "bottom": Y_DAIS, "top": Y_DAIS+4.5},
		## Hides the lip's west side from head 1: step out of its lee and head 1
		## first sees you already on its axis, so it does not grind round to you.
		{"kind": "box", "name": "lip post W", "rect": Rect2(-1.65, 2.6, 0.9, 0.8), "bottom": Y_DAIS, "top": Y_DAIS+4.5},
		## The exit rim's south kerb: a blast that comes in south of west stops on it.
		{"kind": "box", "name": "exit kerb", "rect": Rect2(-34.0, -5.3, 23.0, 0.3), "bottom": Y_EXIT, "top": Y_EXIT+0.5},
		{"kind": "box", "name": "chest 1", "rect": Rect2(5.5, -8.5, 2.0, 1.2), "bottom": Y_CELL, "top": Y_CELL+1.0},
		{"kind": "box", "name": "chest 2", "rect": Rect2(17.0, -20.6, 2.0, 1.2), "bottom": Y_CELL, "top": Y_CELL+1.0},
	],
	## Enemies: place (x, y, z of the turf under), facing (x, z), knobs. Heads are
	## posted still by a one-point route (their own spot); otherwise default knobs.
	"heads": [
		{"name": "head 1", "at": H1, "face": Vector2(0.0, -1.0), "knobs": {"size": 3.0}},
		{"name": "head 2 (small)", "at": H2, "face": Vector2(-1.0, 0.0), "knobs": {"size": 2.0}},
	],
	## The body (B): where it is set down, and the head it is after (1 or 2).
	"body": {"at": Vector3(9.5, Y_DAIS, 2.4), "face": Vector2(-1.0, 0.0), "head": 1, "knobs": {}},
	## Stations: key, name, spawn, facing.
	"stations": [
		{"key": 1, "name": "Start (entry, wading)", "spawn": Vector3(-8.0, Y_DAIS-0.4, 24.0), "face": Vector2(1.0, -1.0)},
		{"key": 2, "name": "The lee of lip post W: head 1 cannot see you; step out east onto the lip", "spawn": Vector3(-2.0, Y_DAIS, 1.8), "face": Vector2(1.0, 0.0)},
		{"key": 3, "name": "Dais lip (CHAIN A: head 1 -> cell 1 -> head 2 -> exit rim)", "spawn": H1+Vector3(0.0, 0.0, -LIP), "face": Vector2(0.0, -1.0)},
		{"key": 4, "name": "Cell 1, in front of head 2 (CHAIN B: head 2 -> exit rim)", "spawn": Vector3(0.0, Y_CELL, H2.z), "face": Vector2(1.0, 0.0)},
		{"key": 5, "name": "Cell 2 (by the plank)", "spawn": Vector3(16.0, Y_CELL, -14.0), "face": Vector2(-1.0, 0.0)},
		{"key": 6, "name": "Exit rim", "spawn": Vector3(-20.0, Y_EXIT, -16.0), "face": Vector2(0.0, -1.0)},
		{"key": 7, "name": "The lee of column E (CHAIN C: press B and wait for the body)", "spawn": Vector3(5.5, Y_DAIS, 3.6), "face": Vector2(-1.0, 0.0)},
	],
	## Floating notes: (place, text).
	"notes": [
		[H1+Vector3(0.0, 5.0, 0.0), "HEAD 1 - stand on the lip and it blasts you north, down onto cell 1"],
		[H2+Vector3(0.0, 4.0, 0.0), "HEAD 2 (small, default knobs) - your skid ends on its face; it winds up and blasts you WEST"],
		[Vector3(0.0, 2.0, -2.5), "VOID 1: 7.5 m across, 4 m down to cell 1"],
		[Vector3(-7.0, Y_CELL+2.0, -14.0), "VOID 2: 7.5 m across, 7 m down to the exit rim"],
		[Vector3(-2.2, 3.2, 1.8), "LIP POST: head 1 cannot see you behind it; step out east onto the lip"],
		[H1+Vector3(0.0, 3.0, -LIP), "LIP: on head 1's axis it draws you in and fires you dead north"],
		[Vector3(5.5, 3.0, 3.6), "CHAIN C: hide here, press B: the body shoves you into head 1 (STAND-IN: head 1 hears its body)"],
	],
}

## [seconds, tone (Hz, 0 none), tone at the end, noise share, low-pass (0-1),
## attack (s), tremolo (Hz, 0 none)] (enemy_yard.gd `_synth`).
const VOICES := {
	"head_grind": [0.9, 0.0, 0.0, 1.0, 0.07, 0.05, 13.0],
	"head_inhale": [3.0, 0.0, 0.0, 1.0, 0.22, 0.9, 0.0],
	"head_yank": [0.35, 0.0, 0.0, 1.0, 0.4, 0.01, 0.0],
	"head_gulp": [0.45, 70.0, 40.0, 0.4, 0.15, 0.005, 0.0],
	"head_blast": [0.9, 0.0, 0.0, 1.0, 0.55, 0.005, 0.0],
}

## STAND-INs for chain C (the body shoves you into head 1). With the real head
## and body it fails every time: head 1 cannot draw at someone it has not seen
## and wound up on, and the body reaches its head and lifts it off before the
## gulp (or walks into the blast). So, only while the body is up:
## 1. Head 1 "hears its body": with the body walking within HEAR_BODY m, it goes
##    straight into its tell (no lock on you needed) and holds its bearing while
##    it draws (it does not grind round after you).
##    Engine change: InhalerHead hearing. A heavy step, a shove or a slam within
##    a `hear` knob starts the tell along its current facing, and in tell/inhale
##    `_track` turns it only toward a pilot it can see.
## 2. The body waits while its head eats: it stands still while head 1 holds
##    you and for 0.6 s after the blast.
##    Engine change: in HeadlessBody._walking, hold still while `head.swallowed`
##    or the head is in its first moments of "after".
const HEAR_BODY := 13.0
## The chain C stand-ins on (a throwaway check turns them off).
var stand_ins := true

var enemies: Node
var body_on := false
var _voices := {}
var _body_ref: Node3D = null
var _heard := false

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
	pack = "wardens_well"
	super._ready()

func _load_pack() -> void:
	var first: Dictionary = LAYOUT.stations[0]
	start = first.spawn
	start_face = first.face
	lost = LOST_Y
	_last_stood = start
	var parts := []
	for m: Dictionary in LAYOUT.masses:
		parts.append(["box", m.rect, m.top-SLAB, m.top, "floor"])
		for t: Array in m.tiers: parts.append(["box", t[0], m.top-SLAB, t[1], "grey"])
		for w: Array in m.get("water", []):
			var r: Rect2 = w[0]
			parts.append(["box", r, m.top-SLAB, m.top, "dark"])
			parts.append(["water", r, m.top, m.top+w[1]])
		if m.has("label"): parts.append(["label", m.label[0], m.label[1]])
	for p: Dictionary in LAYOUT.pieces:
		if p.kind == "cyl": parts.append(["cyl", p.at, p.r, p.bottom, p.top, "grey"])
		else: parts.append(["box", p.rect, p.bottom, p.top, "lip"])
	for n: Array in LAYOUT.notes: parts.append(["label", n[0], n[1]])
	stations = []
	for i in LAYOUT.stations.size():
		var s: Dictionary = LAYOUT.stations[i]
		stations.append({"key": s.key, "name": s.name, "spawn": s.spawn, "face": s.face,
			"sign": s.spawn+Vector3(0.0, 2.6, 0.0), "parts": parts if i == 0 else []})

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
	for h: Dictionary in LAYOUT.heads:
		var knobs: Dictionary = (h.knobs as Dictionary).duplicate()
		knobs["route"] = [h.at]
		enemies.spawn(InhalerHead, h.at, h.face, knobs)

func heads() -> Array:
	var out := []
	for e in enemies.enemies:
		if is_instance_valid(e) and e.has_method("mouth"): out.append(e)
	return out

func place(at: Vector3, face: Vector2) -> void:
	super.place(at, face)
	if enemies != null:
		_drop_body()
		enemies.reset()
	if figure != null: figure.visible = true

func _drop_body() -> void:
	body_on = false
	_heard = false
	if _body_ref != null and is_instance_valid(_body_ref):
		enemies.enemies.erase(_body_ref)
		if _body_ref.get_parent() == enemies: enemies.remove_child(_body_ref)
		_body_ref.queue_free()
	_body_ref = null

func toggle_body() -> void:
	if body_on:
		_drop_body()
		return
	var b: Dictionary = LAYOUT.body
	_body_ref = enemies.add(HeadlessBody, b.at, b.face, b.knobs)
	var own: Dictionary = LAYOUT.heads[int(b.head)-1]
	_body_ref.head_home = own.at
	enemies.enemies.erase(_body_ref)
	enemies.enemies.push_front(_body_ref)
	body_on = true

func tick(delta: float) -> void:
	_stand_ins()
	super.tick(delta)

## The chain C stand-ins (see HEAR_BODY), run before the frame's think.
func _stand_ins() -> void:
	if enemies == null or not stand_ins: return
	var all := heads()
	if all.is_empty(): return
	var h: Node3D = all[0]
	var body_up: bool = body_on and is_instance_valid(_body_ref) and not _body_ref.whole
	var to_body := Vector2(INF, INF)
	if body_up: to_body = Vector2(_body_ref.position.x-h.position.x, _body_ref.position.z-h.position.z)
	var near: bool = body_up and _body_ref.state in ["roam", "home", "reach"] and to_body.length() < HEAR_BODY
	if near and not _heard:
		_heard = true
		h.knobs["track_rest"] = 99.0
		h.knobs["lose"] = 99.0
	elif not near and _heard:
		_heard = false
		var d: Dictionary = h.default_knobs(enemies.numbers())
		h.knobs["track_rest"] = d.track_rest
		h.knobs["lose"] = d.lose
	if _heard and h.state in ["scoot", "notice"] and h.get("_act") == "":
		h._go("tell")
		h.tell()
		_voice(&"head_inhale", h.global_position)
	if _heard and h.state in ["tell", "inhale"]: h.set("_rest", 99.0)
	if body_up:
		var eating: bool = h.swallowed or (h.state == "after" and h.state_t < 0.6)
		var bd: Dictionary = _body_ref.default_knobs(enemies.numbers())
		_body_ref.knobs["walk"] = 0.0 if eating else bd.walk
		_body_ref.knobs["home"] = 0.0 if eating else bd.home

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and not _name_panel.visible:
		if (event as InputEventKey).keycode == KEY_B:
			toggle_body()
			return
	super._unhandled_input(event)

func _hint_text() -> String:
	return "Warden's Well greybox: 2/3 lip -> head 1 -> cell 1 -> head 2 -> exit · 4 head 2 alone · 7 then B: the body · R start · F1 numbers"

func _show_hud() -> void:
	super._show_hud()
	if not _hud.visible or enemies == null: return
	var lines := PackedStringArray([_hud.text, ""])
	var i := 1
	for h in heads():
		lines.append("head %d  %s %.1fs · draw %.2f · pull on him %.1f m/s · gulps %d blasts %d" % [i, h.state, h.state_t, h.draw_share, h.pulling, h.gulps, h.blasts])
		i += 1
	lines.append("stunned %s · body %s%s" % [motor.stunned if motor.stunned != "" else "-", (_body_ref.state if body_on and is_instance_valid(_body_ref) else "off (B)"), " · head 1 hears it (STAND-IN)" if _heard else ""])
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
