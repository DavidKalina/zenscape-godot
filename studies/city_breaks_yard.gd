extends "res://studies/character_study.gd"
## The city breaks yard: the
## city kit's two pieces where the Olmec's power is the wanderer's tool
## (scripts/city_kit_breaks.gd), with a whole Olmec hunting him (the whole
## body's chase, its periscope, and this round's `chase_routes`: at an edge
## he can't leap he takes his planner's route to you).
##   the felled column  a drum column of the makers on its plinth by a gap
##                      too wide for either of you (and for his leap). Lure
##                      him into it from the west and it falls east across
##                      the gap: a bridge to the far isle, for you and then
##                      for him. From the east it falls west onto the yard,
##                      its top drums rolling (stay out of their way).
##   the drum court     loose slabs on drums, south-west. His landing on it
##                      (a pounce at you) staggers the slabs out from where
##                      he lands: a slab under you throws you; jump just as
##                      yours hops and it launches you, onto the gallery
##                      ledge along its north side (out of your jump's reach).
## Greybox ground (the character study's grid), the pieces in the Olmec's
## weathered basalt. `--underground=haze` (or torch) puts it in the abyss.
##   R   all back: you, him, the column standing, the court quiet
##   B   him back where he began, whole, unaware
##   F1  numbers
##   godot --path . res://studies/city_breaks_yard.tscn -- --no-title
##     [--underground=haze] [--body-knob=<knob>=<value>] [--head-knob=...]
##     [--body-at=x,z] [--body-face=x,z] [--no-body] [--no-sight-overlay]
const EnemyField = preload("res://scripts/enemies/enemy_field.gd")
const InhalerHead = preload("res://scripts/enemies/inhaler_head.gd")
const HeadlessBody = preload("res://scripts/enemies/headless_body.gd")
const BodySpawner = preload("res://scripts/enemies/body_spawner.gd")
const EnemyYard = preload("res://studies/enemy_yard.gd")
const SightOverlay = preload("res://scripts/enemies/body_sight_overlay.gd")
const Breaks = preload("res://scripts/kit_isle/colonnade_breaks.gd")
const Breakables = preload("res://scripts/breaks/breakables.gd")
const CityBreaks = preload("res://scripts/city_kit_breaks.gd")
const Underground = preload("res://scripts/underground/underground.gd")

const YARD_LOST := -40.0
const UNDER := -12.0
## The column's middle; it falls along +X (east) across the gap.
const COLUMN_AT := Vector3(0.0,0.0,0.0)
## The yard (west of the gap), the far isle (east of it).
const NEAR := Rect2(-60.0,-30.0,0.0,100.0)
const FAR_TO := 46.0
const FAR_Z := Vector2(-30.0,30.0)
## The drum court's middle (5 x 5 slabs) and the gallery ledge north of it.
const COURT_AT := Vector3(-26.0,0.0,40.0)
const GALLERY_TOP := 4.5
const GALLERY_DEEP := 5.0
## Where he stands and you start.
const BODY_AT := Vector3(-30.0,0.0,0.0)
const PILOT_AT := Vector3(-12.0,0.0,10.0)
## The Olmec's stride here (the colonnade's OLMEC_STEP: the plinth's steps
## and a felled drum's crown from the plinth are strides to him).
const OLMEC_STEP := CityBreaks.OLMEC_STEP
const VOICES := {
	"drum_ring":[1.4,96.0,92.0,0.12,0.35,0.002,3.0],
	"drum_thud":[0.4,70.0,50.0,0.5,0.15,0.002,0.0],
}

var enemies: Node
var hub: Node3D
var column: Node3D
var court: Node3D
var overlay: Node3D
var under: Node3D
var _environment: Environment
var _sun: DirectionalLight3D
var _voices := {}
var _body_knobs := {}
var _head_knobs := {}
var _body_at := BODY_AT
var _body_face := Vector2(1.0,0.0)
var _no_body := false
var _overlay_on := true

class Slot extends Node:
	var field: Node
	var hub: Node
	func before(delta: float) -> void:
		for e in field.enemies:
			if is_instance_valid(e) and e.has_method("world_changed") and e.breaker == null: e.breaker = hub
		field.before(delta)
	func after(delta: float, events: Dictionary) -> void: field.after(delta,events)
	func pose(figure: Node3D) -> void:
		var held := false
		for e in field.enemies:
			if is_instance_valid(e) and e.get("swallowed"): held = true
		figure.visible = not held

func _ready() -> void:
	pack = "city_breaks"
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg == "--no-body": _no_body = true
		elif arg == "--no-sight-overlay": _overlay_on = false
		elif arg.begins_with("--body-face="):
			var f := arg.get_slice("=",1).split(",")
			_body_face = Vector2(float(f[0]),float(f[1]) if f.size() > 1 else 0.0).normalized()
		elif arg.begins_with("--body-at="):
			var p := arg.get_slice("=",1).split(",")
			_body_at = Vector3(float(p[0]),0.0,float(p[1]) if p.size() > 1 else 0.0)
		for pair in [["--body-knob=",_body_knobs],["--head-knob=",_head_knobs]]:
			if arg.begins_with(pair[0]):
				var kv: String = arg.trim_prefix(pair[0])
				pair[1][kv.get_slice("=",0)] = float(kv.get_slice("=",1))
	super._ready()

## The felled line's bearing on the near rim (m): a stretch of its flank
## over ground, where the Olmec climbs onto it (his planner's climb leg
## needs ground at the wall's foot).
const NEAR_BEARING := 3.0

## The gap's west and east rims (x): the felled drums bear NEAR_BEARING m on
## the near one, BEARING on the far.
static func gap_x() -> Vector2:
	var from := COLUMN_AT.x+CityBreaks.felled_from()
	return Vector2(from+NEAR_BEARING,from+CityBreaks.felled_length()-CityBreaks.BEARING)

static func court_rect() -> Rect2:
	var w := 5*CityBreaks.SLAB
	return Rect2(COURT_AT.x-w*0.5,COURT_AT.z-w*0.5,w,w)

func _load_pack() -> void:
	start = PILOT_AT
	start_face = Vector2(1.0,-0.6).normalized()
	lost = YARD_LOST
	_last_stood = start
	var g := gap_x()
	var parts := []
	var near := Rect2(NEAR.position.x,NEAR.position.y,g.x-NEAR.position.x,NEAR.size.y)
	var holes: Array[Rect2] = [court_rect()]
	for r: Rect2 in _floor_rects(near,holes): parts.append(["box",r,UNDER,0.0,"floor"])
	parts.append(["box",Rect2(g.y,FAR_Z.x,FAR_TO-g.y,FAR_Z.y-FAR_Z.x),UNDER,0.0,"pad"])
	var c := court_rect()
	parts.append(["box",Rect2(c.position.x,c.position.y-GALLERY_DEEP,c.size.x,GALLERY_DEEP),0.0,GALLERY_TOP,"lip"])
	parts.append(["label",Vector3(c.get_center().x,GALLERY_TOP+0.8,c.position.y-GALLERY_DEEP*0.5),"gallery · %.1f m (the drum floor's launch)" % GALLERY_TOP])
	parts.append(["label",Vector3(c.get_center().x,0.8,c.end.y+1.5),"drum floor · his landing throws you, a timed jump launches you"])
	parts.append(["label",Vector3((g.x+g.y)*0.5,0.8,FAR_Z.x+3.0),"gap %.1f m · lure him into the column from the west" % (g.y-g.x)])
	parts.append(["label",Vector3(FAR_TO-8.0,0.8,0.0),"the far isle"])
	stations = [{"key":1,"name":"City breaks yard","spawn":PILOT_AT,"face":start_face,"sign":Vector3(-12.0,10.0,-12.0),"parts":parts}]

func _build_light() -> void:
	super._build_light()
	for n: Node in get_children():
		if n is WorldEnvironment: _environment = (n as WorldEnvironment).environment
		elif n is DirectionalLight3D: _sun = n

func _build_room() -> void:
	super._build_room()
	column = CityBreaks.piece("maker_felled",11)
	column.position = COLUMN_AT
	add_child(column)
	court = CityBreaks.piece("colossus_drum",12)
	court.position = COURT_AT
	add_child(court)
	enemies = EnemyField.new()
	enemies.study = self
	enemies.motor = motor
	enemies.lost = lost
	enemies.sound_hook = _voice
	add_child(enemies)
	hub = Breakables.new()
	hub.field = enemies
	hub.sound_hook = _voice
	add_child(hub)
	var slot := Slot.new()
	slot.field = enemies
	slot.hub = hub
	add_child(slot)
	foot_pieces = slot
	if not _no_body:
		var knobs := {"chase":1,"step":OLMEC_STEP,"chase_routes":1}
		knobs.merge(_body_knobs,true)
		enemies.spawn(HeadlessBody,_body_at,_body_face,knobs)
		enemies.spawn(InhalerHead,_body_at,_body_face,_head_knobs.duplicate())
		overlay = SightOverlay.new()
		add_child(overlay)
		_wire()
	under = Underground.attach(self)
	var b := stone_body()
	var fit := CityBreaks.fit(b.jump_gap() if b != null else 9.0,OLMEC_STEP)
	for f: Array in fit: print("city breaks fit: %s %.2f vs %.2f %s" % [f[0],float(f[1]),float(f[2]),"ok" if f[3] else "NO"])
	print("city breaks yard: column %.1f m tall, gap %.1f m, court %d slabs" % [CityBreaks.column_h(),gap_x().y-gap_x().x,court.slabs.size()])

func _wire() -> void:
	var b := stone_body()
	var h := stone_head()
	if b == null or h == null: return
	b.make_whole(h)
	b.breaker = hub
	if overlay != null:
		if overlay.body == null: overlay.setup_body(b)
		else: overlay.body = b
		overlay.visible = _overlay_on
		overlay._layer.visible = _overlay_on

func stone_body() -> Node3D:
	if enemies == null: return null
	for e in enemies.enemies:
		if is_instance_valid(e) and e.has_method("make_whole"): return e
	return null

func stone_head() -> Node3D:
	if enemies == null: return null
	for e in enemies.enemies:
		if is_instance_valid(e) and e.has_method("mouth"): return e
	return null

## R: you, him and the pieces as they began (a fall off the yard sets only
## you back).
func reset_all() -> void:
	if column != null: column.reset()
	if court != null: court.reset()
	reset_body()
	respawn()

func reset_body() -> void:
	if enemies == null or _no_body: return
	enemies.reset()
	if figure != null: figure.visible = true
	_wire()

func tick(delta: float) -> void:
	super.tick(delta)
	if under != null and _sun != null: _sun.visible = false
	if camera == null: return
	var q := float(hub.quake)*0.7 if hub != null else 0.0
	var b := stone_body()
	if b != null: q = maxf(q,float(b.quake)*clampf(1.0-camera.global_position.distance_to(b.global_position)/60.0,0.0,1.0))
	if q > 0.001:
		var t := Time.get_ticks_msec()/1000.0
		camera.position += Vector3(sin(t*61.0),sin(t*53.0+1.0),sin(t*47.0+2.0))*q*0.5

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and not _name_panel.visible:
		var key := (event as InputEventKey).keycode
		if key == KEY_R:
			reset_all()
			return
		if key == KEY_B:
			reset_body()
			_say("He is back where he began",2.0)
			return
		if key == KEY_L and under != null:
			under.cycle()
			return
	super._unhandled_input(event)

func _show_toast(text: String) -> void:
	_say(text,2.0)

# --- The HUD and the sounds -----------------------------------------------------------------

func _hint_text() -> String:
	return "City breaks: lure the Olmec into the column from the west and it falls across the gap as your bridge (and his) · on the drum court his landing throws you; jump as your slab hops to be launched onto the gallery · R all back · B him back · F1 numbers"

func _show_hud() -> void:
	super._show_hud()
	if not _hud.visible or hub == null: return
	var lines := PackedStringArray([_hud.text,""])
	var b := stone_body()
	if b != null:
		lines.append("olmec  %s %.1fs · y %.1f · chase routes %d (found %d) · %s" % [b.state,b.state_t,b.position.y,b.chase_plans,b.chase_found,b.route_stats()])
	lines.append("column  %s %s %s · fell in %.1f s · hits %s" % [column.state,column.how,column.cause,column.fall_s,str(column.dealt)])
	lines.append("court  hops %d · hits %s" % [court.hops,str(court.dealt)])
	_hud.text = "\n".join(lines)

func _voice(sound_name: StringName, at: Vector3) -> void:
	var key := String(sound_name)
	var spec: Variant = VOICES.get(key,InhalerHead.VOICES.get(key,BodySpawner.VOICES.get(key,Breaks.VOICES.get(key))))
	if spec == null: return
	if not _voices.has(key): _voices[key] = EnemyYard._synth(spec)
	var player := AudioStreamPlayer3D.new()
	player.stream = _voices[key]
	player.position = at
	player.unit_size = float(BodySpawner.REACH.get(key,Breaks.REACH.get(key,30.0)))
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
