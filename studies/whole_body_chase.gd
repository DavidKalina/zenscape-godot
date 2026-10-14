extends "res://studies/character_study.gd"
## The whole body's chase greybox (docs/design/roguelike/whole-body-chase-round1.md):
## the headless body (scripts/enemies/headless_body.gd) set down whole, its
## inhaler head (scripts/enemies/inhaler_head.gd) on its neck, with its
## chase on: it sees you (scripts/enemies/body_sight.gd, the dragon's sight
## at its scale; drawn by scripts/enemies/body_sight_overlay.gd), and comes
## for you, swatting you near, pouncing a little way off, planting and
## sucking you in with its head's breath further off; lost, it looks where it
## last saw you, then walks back and roams.
## One grey arena in open sky (the character study's structure, as the
## headless body isle's):
##   the floor     100 m square, flat, for chases (outrun it on the flat);
##   cover         a long wall in front of your start, three pillars: taller
##                 than its eyes, to break its sight;
##   east ledges   a low one at the walker's pump catch (RuinKit.CHAIN_TOP:
##                 it pounces up onto that), a mid one (6 m) and a tower
##                 (12 m) it climbs after you; ramps up for you;
##   west isle     across a gap you jump (WALKER_GAP walker heights), level:
##                 it leaps after you;
##   north shelf   across the same gap, NORTH_DROP m lower: it leaps down
##                 after you; a ramp back up its east end.
##   cover yard   south of your start (Olmec periscope round 1,
##                docs/design/roguelike/olmec-periscope-round1.md): what
##                hides you once it lifts its head overhead to look: a low
##                wall (under its eyes: hides you from its eyes on its neck,
##                not from its head held up), a tall wall, a ledge over it
##                (a ramp up its west side) and an arch whose lintel hangs
##                over you.
## You start behind the long wall, out of its sight; it stands north of it.
## Its periscope is on here (`--body-knob=periscope=0` turns it off).
##   B   the body back where it started, whole, unaware of you
##   , . the head smaller, bigger (its `size`, 0.1 a press; the body back
##       where it started)
##   R   you back at the start, the body too
##   J   its sight overlay (on: the cone on the ground, its rays to you, the
##       awareness meter, what it is doing and its ranges)
##   F1  numbers
##   godot --path . res://studies/whole_body_chase.tscn -- --no-title
##     [--body-knob=<knob>=<value>] [--head-knob=<knob>=<value>] (repeatable)
##     [--no-sight-overlay]
## Placeholder sounds: the head's and the body's synthesized voices.
const EnemyField = preload("res://scripts/enemies/enemy_field.gd")
const InhalerHead = preload("res://scripts/enemies/inhaler_head.gd")
const HeadlessBody = preload("res://scripts/enemies/headless_body.gd")
const BodySpawner = preload("res://scripts/enemies/body_spawner.gd")
const EnemyYard = preload("res://studies/enemy_yard.gd")
const SightOverlay = preload("res://scripts/enemies/body_sight_overlay.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")
const WorldScale = preload("res://scripts/world_scale.gd")

const ARENA_LOST := -40.0
const UNDER := -12.0
## The floor (x, z), its top 0.
const FLOOR := Rect2(-50.0,-50.0,100.0,100.0)
## Cover: [name, rect (x, z), top]. Taller than its eyes (about 9.6 m).
const COVER := [
	["the long wall",Rect2(-16.0,6.0,32.0,3.0),12.0],
	["pillar",Rect2(-31.0,-17.0,7.0,7.0),14.0],
	["pillar",Rect2(-34.0,22.0,7.0,7.0),14.0],
	["pillar",Rect2(8.0,-34.0,7.0,7.0),14.0],
]
## The east ledges: [name, rect, top]; the low one's top is the walker's
## pump catch (RuinKit.CHAIN_TOP), set in `_load_pack`.
const LEDGES := [
	["low ledge",Rect2(26.0,4.0,14.0,14.0),-1.0],
	["mid ledge",Rect2(26.0,-22.0,14.0,22.0),6.0],
	["tower",Rect2(28.0,-46.0,10.0,12.0),12.0],
]
## The walker's ramps (low middle edge, high middle edge, width).
const RAMPS := [
	[Vector3(24.5,0.0,10.0),Vector3(24.5,6.0,-12.0),3.0],
	[Vector3(33.0,6.0,-21.5),Vector3(33.0,12.0,-34.0),3.0],
]
## The gaps west and north, in walker heights (he jumps them running), and
## the north shelf's drop (m).
const WALKER_GAP := 2.5
const NORTH_DROP := 2.5
## The cover yard (Olmec periscope round 1): [name, rect, bottom, top]. The
## low wall is under its eyes on its neck (about 9.6 m), the tall wall over
## its head held up (about 12-13 m); the ledge's top is over its eyes on its
## neck, under them held up; the arch's lintel hangs over the walker (its
## underside YARD_ARCH_UNDER m) between two side walls.
const YARD_ARCH_UNDER := 2.6
const YARD := [
	["low wall",Rect2(-10.0,32.0,14.0,1.2),0.0,5.5,"lip"],
	["tall wall",Rect2(8.0,32.0,12.0,1.2),0.0,14.0,"wall"],
	["ledge over it",Rect2(-49.0,32.0,17.0,14.0),0.0,9.0,"grey"],
	["arch",Rect2(-26.0,36.0,2.0,8.0),0.0,4.0,"wall"],
	["",Rect2(-16.0,36.0,2.0,8.0),0.0,4.0,"wall"],
	["",Rect2(-26.0,36.0,12.0,8.0),YARD_ARCH_UNDER,4.0,"wall"],
]
## The walker's ramp up the ledge (along its west side, from the north).
const YARD_RAMP := [Vector3(-47.5,0.0,8.0),Vector3(-47.5,9.0,32.0),3.0]
## Where the body stands, where you start.
const BODY_AT := Vector3(-8.0,0.0,-22.0)
const PILOT_AT := Vector3(0.0,0.0,22.0)

var enemies: Node
var overlay: Node3D
var _voices := {}
var _body_knobs := {}
var _head_knobs := {}
## The head's knobs as spawned (the field's spec holds this one: , . size it).
var _head_spawned := {}
var _overlay_on := true
## Where the body stands and faces (a study built on this one sets its own).
var body_at := BODY_AT
var body_face := Vector2(0.0,1.0)
var _gone_t := 0.0

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
	pack = "whole_body_chase"
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg == "--no-sight-overlay": _overlay_on = false
		for pair in [["--body-knob=",_body_knobs],["--head-knob=",_head_knobs]]:
			if arg.begins_with(pair[0]):
				var kv: String = arg.trim_prefix(pair[0])
				pair[1][kv.get_slice("=",0)] = float(kv.get_slice("=",1))
	super._ready()

## The walker's height (m): his gaps are in it.
static func walker_tall() -> float:
	return PhysicsGround.HEAD*WorldScale.wanderer

func _load_pack() -> void:
	start = PILOT_AT
	start_face = Vector2(0.0,-1.0)
	lost = ARENA_LOST
	_last_stood = start
	var gap := WALKER_GAP*walker_tall()
	var parts := []
	parts.append(["box",FLOOR,UNDER,0.0,"floor"])
	parts.append(["label",Vector3(0.0,0.6,FLOOR.end.y-2.0),"the floor · outrun it here"])
	for c: Array in COVER:
		var r: Rect2 = c[1]
		parts.append(["box",r,0.0,float(c[2]),"wall"])
		parts.append(["label",Vector3(r.get_center().x,float(c[2])+0.8,r.get_center().y),"%s · %d m" % [c[0],int(c[2])]])
	for i in LEDGES.size():
		var l: Array = LEDGES[i]
		var r: Rect2 = l[1]
		var top: float = RuinKit.CHAIN_TOP if i == 0 else float(l[2])
		parts.append(["box",r,0.0,top,"lip" if i == 0 else "grey"])
		parts.append(["label",Vector3(r.get_center().x,top+0.8,r.get_center().y),"%s · %.1f m" % [l[0],top]])
	for ramp: Array in RAMPS: parts.append(["ramp",ramp[0],ramp[1],ramp[2],"lane"])
	for y: Array in YARD:
		var r: Rect2 = y[1]
		parts.append(["box",r,float(y[2]),float(y[3]),y[4]])
		if y[0] != "": parts.append(["label",Vector3(r.get_center().x,float(y[3])+0.8,r.get_center().y),"%s · %.1f m" % [y[0],float(y[3])]])
	parts.append(["label",Vector3(-20.0,0.8,40.0),"under the arch · %.1f m" % YARD_ARCH_UNDER])
	parts.append(["ramp",YARD_RAMP[0],YARD_RAMP[1],YARD_RAMP[2],"lane"])
	# West, level across the gap; north, lower across it, a ramp back up.
	var west := Rect2(FLOOR.position.x-gap-24.0,-18.0,24.0,36.0)
	parts.append(["box",west,UNDER,0.0,"pad"])
	parts.append(["label",Vector3(west.get_center().x,0.8,west.get_center().y),"west isle · %.1f m gap, level" % gap])
	var north := Rect2(-24.0,FLOOR.position.y-gap-22.0,48.0,22.0)
	parts.append(["box",north,UNDER,-NORTH_DROP,"pad"])
	parts.append(["label",Vector3(north.get_center().x,-NORTH_DROP+0.8,north.get_center().y),"north shelf · %.1f m gap, %.1f m down" % [gap,NORTH_DROP]])
	parts.append(["ramp",Vector3(20.0,-NORTH_DROP,north.end.y-7.0),Vector3(20.0,0.0,FLOOR.position.y+3.0),2.5,"lane"])
	stations = [{"key":1,"name":"Whole body chase","spawn":PILOT_AT,"face":start_face,"sign":Vector3(0.0,14.0,12.0),"parts":parts}]

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
	var body_knobs := {"chase":1}
	body_knobs.merge(_study_body_knobs(),true)
	body_knobs.merge(_body_knobs,true)
	enemies.spawn(HeadlessBody,body_at,body_face,body_knobs)
	# Worn, its draw reaches out over its suck range: its own worn_* knobs.
	_head_spawned = _head_knobs.duplicate()
	enemies.spawn(InhalerHead,body_at,body_face,_head_spawned)
	overlay = SightOverlay.new()
	add_child(overlay)
	_wire()

## The body's knobs this study sets (over the chase's own; the flags over these).
func _study_body_knobs() -> Dictionary:
	return {"periscope":1}

## The head on the body's neck, the overlay on the body, its beats heard.
func _wire() -> void:
	var b := stone_body()
	var h := stone_head()
	if b == null or h == null: return
	b.make_whole(h)
	b.chase_beat.connect(_beat)
	if overlay.body == null: overlay.setup_body(b)
	else: overlay.body = b
	overlay.visible = _overlay_on
	overlay._layer.visible = _overlay_on
	_gone_t = 0.0

func stone_body() -> Node3D:
	for e in enemies.enemies:
		if is_instance_valid(e) and e.has_method("make_whole"): return e
	return null

func stone_head() -> Node3D:
	for e in enemies.enemies:
		if is_instance_valid(e) and e.has_method("mouth"): return e
	return null

## Set down, the body and its head back as they began.
func place(at: Vector3, face: Vector2) -> void:
	super.place(at,face)
	reset_body()

## B: the body back where it began, whole, unaware.
func reset_body() -> void:
	if enemies == null: return
	enemies.reset()
	if figure != null: figure.visible = true
	_wire()

func _beat(what: String) -> void:
	var said: String = {"spotted":"It sees you!","lost":"It lost you: it looks where it last saw you","gave up":"It gives up, and goes back",
		"pounce":"It crouches to pounce!","suck":"It plants and opens its jaw: it will suck you in!","gulped":"Swallowed!","blown out":"Blown out!",
		"swat":"It raises its fists!","caught swat":"Caught: swatted down","scope":"It lifts its own head up overhead to look…",
		"scope saw":"Its raised head sees you!","scope none":"Nothing: it puts its head back","caught pounce":"Caught: pounced on","missed":"It missed"}.get(what,what)
	_say(said,2.5)

## The camera shakes with its landings and its steps; a body gone off the
## world comes back.
func tick(delta: float) -> void:
	super.tick(delta)
	var b := stone_body()
	if b == null:
		_gone_t += delta
		if _gone_t > 3.0: reset_body()
		return
	if camera != null:
		var q := float(b.quake)*clampf(1.0-camera.global_position.distance_to(b.global_position)/60.0,0.0,1.0)
		if q > 0.001:
			var t := Time.get_ticks_msec()/1000.0
			camera.position += Vector3(sin(t*61.0),sin(t*53.0+1.0),sin(t*47.0+2.0))*q*0.5

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_B and not _name_panel.visible:
		reset_body()
		_say("The body is back where it began",2.0)
		return
	if event is InputEventKey and event.pressed and (event as InputEventKey).keycode in [KEY_COMMA,KEY_PERIOD] and not _name_panel.visible:
		var h := stone_head()
		var size := float(h.knobs.size) if h != null else float(_head_spawned.get("size",2.6))
		size = clampf(snappedf(size+(0.1 if (event as InputEventKey).keycode == KEY_PERIOD else -0.1),0.1),1.0,5.0)
		_head_spawned["size"] = size
		reset_body()
		_say("Head size %.1f (--head-knob=size=%.1f)" % [size,size],3.0)
		return
	super._unhandled_input(event)

# --- The HUD and the sounds ---------------------------------------------------------------

func _hint_text() -> String:
	return "Whole body chase · J its sight · near it swats, mid it pounces, further it sucks · lose it and it lifts its head to look (cover yard south) · B body back · , . head size · R start · F1 numbers · Esc mouse"

func _show_hud() -> void:
	super._show_hud()
	if not _hud.visible or enemies == null: return
	var lines := PackedStringArray([_hud.text,""])
	var b := stone_body()
	var h := stone_head()
	if b != null:
		var s: RefCounted = b.sight
		lines.append("body  %s %.1fs · %s · y %.1f · sight %s %.2f" % [b.state,b.state_t,"hunting" if b.hunting else "calm",b.position.y,str(s.state) if s != null else "-",float(s.awareness) if s != null else 0.0])
		lines.append("spotted %d · pounces %d · sucks %d (gulps %d) · swats %d (missed %d) · caught you %d (last %s) · climbs %d · leaps %d · gave up %d" % [b.spots,b.pounces,b.sucks,b.gulps,b.swats,b.misses,b.catches,b.last_catch if b.last_catch != "" else "-",b.climbs,b.leaps,b.gave_up])
	else: lines.append("body  gone (back in a moment)")
	if h != null: lines.append("head  %s %.1fs · draw %.2f · pull on you %.1f m/s · swallowed %s" % [h.state,h.state_t,h.draw_share,h.pulling,str(h.swallowed)])
	_hud.text = "\n".join(lines)

func _voice(sound_name: StringName, at: Vector3) -> void:
	var key := String(sound_name)
	var spec: Variant = InhalerHead.VOICES.get(key,BodySpawner.VOICES.get(key))
	if spec == null: return
	if not _voices.has(key): _voices[key] = EnemyYard._synth(spec)
	var player := AudioStreamPlayer3D.new()
	player.stream = _voices[key]
	player.position = at
	player.unit_size = float(BodySpawner.REACH.get(key,14.0))
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
