extends "res://studies/character_study.gd"
## The city landmarks yard:
## the city kit's three set pieces (scripts/city_kit_landmarks.gd) round a
## basalt plaza over the abyss, each on its own foundation, in the
## underground look (torch by default; `--underground=haze`), a whole Olmec
## hunting among them (sight, swat, pounce, inhale, periscope, chase routes)
## and breaking what breaks (the breakables hub: the pyramid stair's fault
## landing, the cressets).
##   west    the ballcourt coliseum, its gate on the plaza: the alley, the
##           rings' roots to swing (run into one), the taluds to slide, the
##           stands he hunts from, the shaft and the broken end over the abyss
##   north   the temple pyramid, its epic stair's foot on the plaza: the west
##           face's prism chain, the east face's kick chimneys, the summit
##           shrine (its door is yours alone: a safe room), the cresset
##   east    the sundered hall, its high end on the plaza: the nave, the
##           aisles behind their screens, the fallen slab across the crack,
##           the kick chimney and glyph steps up to the roofs
## Stations (keys): 1 start · 2 court gate · 3 court ledge · 4 court
## promenade · 5 stair foot · 6 summit door · 7 west chain · 8 east chimney
## · 9 hall high end · 0 hall aisle · - hall chimney
## Keys: R all back · B him back · J his sight · L torch/haze
##   godot --path . res://studies/city_landmarks_yard.tscn -- --no-title
##     [--underground=haze|torch] [--day] [--olmec=plaza|court|stair|landing|pyramid|hall]
##     [--body-knob=<k>=<v>] [--head-knob=...] [--no-body] [--sight-overlay]
##     [--lit] (the cressets burning) [--no-fault] (the
##     stair's second landing whole)
const EnemyField = preload("res://scripts/enemies/enemy_field.gd")
const InhalerHead = preload("res://scripts/enemies/inhaler_head.gd")
const HeadlessBody = preload("res://scripts/enemies/headless_body.gd")
const BodySpawner = preload("res://scripts/enemies/body_spawner.gd")
const EnemyYard = preload("res://studies/enemy_yard.gd")
const SightOverlay = preload("res://scripts/enemies/body_sight_overlay.gd")
const Breakables = preload("res://scripts/kit_isle/breakables.gd")
const Underground = preload("res://scripts/underground/underground.gd")
const Fires = preload("res://scripts/city_kit_fires.gd")
const GiantStone = preload("res://scripts/kit_isle/greybox/giant_stone.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const Landmarks = preload("res://scripts/city_kit_landmarks.gd")
const SwingRope = preload("res://scripts/interactables/swing_rope.gd")

const YARD_LOST := -40.0
## The stone's hemisphere fill under each look (the fires yard's).
const HEMI := {"torch":0.12,"haze":0.55}
## The plaza (x, z), its top 0, its slab's depth; its paving's slab.
const PLAZA := Rect2(-60.0,-40.0,120.0,100.0)
const PLAZA_DEEP := 24.0
const PAVE := 8.0
## Where each landmark stands: [id, the edge of the plaza it meets (its
## open end's port set on it), yaw (deg: its +Z turned to face the plaza)].
const PILOT_AT := Vector3(0.0,0.0,48.0)
const OLMEC_AT := {"plaza":Vector3(0.0,0.0,-8.0)}

var enemies: Node
var hub: Node3D
var overlay: Node3D
var under: Node3D
var court: Node3D
var pyramid: Node3D
var hall: Node3D
var ropes: Array = []
var _environment: Environment
var _sun: DirectionalLight3D
var _voices := {}
var _body_knobs := {}
var _head_knobs := {}
var _olmec := "plaza"
var _no_body := false
var _overlay_on := false
var _lit := false
var _fault := 2

## Steps the enemies (each body handed the breakables hub) and the court's
## roots (as scripts/interactables/foot_pieces.gd steps its ropes: each
## advanced, caught in the air or run into); hides the figure while the
## head holds him, hangs it along the root it rides.
class Slot extends Node:
	var field: Node
	var hub: Node
	var motor: PilotMotor
	var ropes: Array = []
	var catches := 0
	func before(delta: float) -> void:
		for e in field.enemies:
			if is_instance_valid(e) and e.has_method("world_changed") and e.breaker == null: e.breaker = hub
		field.before(delta)
		for r: Node3D in ropes: r.advance(delta)
	func after(delta: float, events: Dictionary) -> void:
		if motor.rider == null and not motor.swimming:
			for r: Node3D in ropes:
				if r.anchor.distance_to(motor.feet) < 12.0 and r.try_catch(motor,delta):
					events["swing"] = true
					catches += 1
					break
		field.after(delta,events)
	func pose(figure: Node3D) -> void:
		for r: Node3D in ropes:
			if r.held(): figure.basis = r.tilt
		var held := false
		for e in field.enemies:
			if is_instance_valid(e) and e.get("swallowed"): held = true
		figure.visible = not held

func _ready() -> void:
	pack = "city_landmarks"
	var args := LaunchArgs.user_args()
	var asked := false
	for a: String in args:
		if a == "--underground" or a.begins_with("--underground="): asked = true
	if not asked and not args.has("--day"):
		var with := PackedStringArray(args)
		with.append("--underground=torch")
		LaunchArgs.set_override(with)
	for arg: String in LaunchArgs.user_args():
		if arg == "--no-body": _no_body = true
		elif arg == "--sight-overlay": _overlay_on = true
		elif arg == "--lit": _lit = true
		elif arg == "--no-fault": _fault = 0
		elif arg.begins_with("--olmec="): _olmec = arg.get_slice("=",1)
		for pair in [["--body-knob=",_body_knobs],["--head-knob=",_head_knobs]]:
			if arg.begins_with(pair[0]):
				var kv: String = arg.trim_prefix(pair[0])
				pair[1][kv.get_slice("=",0)] = float(kv.get_slice("=",1))
	super._ready()

## The landmarks stood (their ports are the stations).
func _load_pack() -> void:
	start = PILOT_AT
	start_face = Vector2(0.0,-1.0)
	lost = YARD_LOST
	_last_stood = start
	var opts := {"lit":_lit,"fault":_fault}
	# West: the court, its gate's apron on the plaza's west edge.
	court = Landmarks.piece("city_court",7,0.45,opts)
	var gate: Vector3 = court.get_meta("ports").gate
	add_child(court)
	court.transform = Transform3D(Basis(Vector3.UP,PI*0.5),Vector3(PLAZA.position.x-gate.z,0.0,10.0))
	# North: the pyramid, its platform's front edge on the plaza's north edge.
	pyramid = Landmarks.piece("city_pyramid",11,0.45,opts)
	var plat: Array = pyramid.get_meta("sizes").platform
	var front := float(plat[1])-float(plat[0])*0.5
	add_child(pyramid)
	pyramid.transform = Transform3D(Basis.IDENTITY,Vector3(0.0,0.0,PLAZA.position.y-front))
	# East: the hall, its high end on the plaza's east edge.
	hall = Landmarks.piece("city_hall",5,0.5,opts)
	var high: Vector3 = hall.get_meta("ports").high_end
	add_child(hall)
	hall.transform = Transform3D(Basis(Vector3.UP,-PI*0.5),Vector3(PLAZA.end.x+high.z,0.0,10.0))
	var cp: Dictionary = court.get_meta("ports")
	var pp: Dictionary = pyramid.get_meta("ports")
	var hp: Dictionary = hall.get_meta("ports")
	var c := court.transform
	var p := pyramid.transform
	var h := hall.transform
	stations = [
		{"key":1,"name":"City landmarks yard","spawn":PILOT_AT,"face":Vector2(0.0,-1.0),"parts":[]},
		{"key":2,"name":"Court gate","spawn":c*(cp.gate as Vector3),"face":_face(c,Vector3.FORWARD),"parts":[]},
		{"key":3,"name":"Court ledge","spawn":c*(cp.ledge_l as Vector3),"face":_face(c,Vector3.FORWARD),"parts":[]},
		{"key":4,"name":"Court promenade","spawn":c*(cp.promenade_l as Vector3),"face":_face(c,Vector3.RIGHT),"parts":[]},
		{"key":5,"name":"Stair foot","spawn":p*(pp.stair_foot as Vector3),"face":Vector2(0.0,-1.0),"parts":[]},
		{"key":6,"name":"Shrine door","spawn":p*(pp.door as Vector3)+Vector3(0.0,0.0,2.0),"face":Vector2(0.0,-1.0),"parts":[]},
		{"key":7,"name":"West chain","spawn":p*(pp.chain_foot as Vector3),"face":Vector2(1.0,0.0),"parts":[]},
		{"key":8,"name":"East chimney","spawn":p*(pp.chimney_foot as Vector3),"face":Vector2(-1.0,0.0),"parts":[]},
		{"key":9,"name":"Hall high end","spawn":h*((hp.high_end as Vector3)+Vector3(0.0,0.0,-2.0)),"face":_face(h,Vector3.FORWARD),"parts":[]},
		{"key":10,"name":"Hall aisle","spawn":h*(hp.aisle as Vector3),"face":_face(h,Vector3.FORWARD),"parts":[]},
		{"key":11,"name":"Hall chimney","spawn":h*(hp.chimney as Vector3),"face":_face(h,Vector3.FORWARD),"parts":[]},
	]

## The way `local` (a piece's frame) faces in the world, as (x, z).
static func _face(xf: Transform3D, local: Vector3) -> Vector2:
	var w := xf.basis*local
	return Vector2(w.x,w.z).normalized()

func _build_light() -> void:
	super._build_light()
	for n: Node in get_children():
		if n is WorldEnvironment: _environment = (n as WorldEnvironment).environment
		elif n is DirectionalLight3D: _sun = n
	camera.far = 1500.0

func _build_room() -> void:
	super._build_room()
	for l: Node in find_children("*","Label3D",false,false): l.queue_free()
	_build_ground()
	# The court's roots, hung from its rings.
	for r: Dictionary in court.get_meta("ropes",[]):
		var rope: Node3D = SwingRope.new()
		rope.setup(court.transform*(r.anchor as Vector3),float(r.length))
		add_child(rope)
		ropes.append(rope)
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
	slot.motor = motor
	slot.ropes = ropes
	add_child(slot)
	foot_pieces = slot
	if not _no_body:
		var knobs := {"chase":1,"chase_routes":1,"periscope":1}
		knobs.merge(_body_knobs,true)
		var at := olmec_at(_olmec)
		var face := Vector2(0.0,-1.0) if _olmec in ["stair","landing"] else Vector2(0.0,1.0)
		if _olmec == "hall": face = _face(hall.transform,Vector3.FORWARD)
		enemies.spawn(HeadlessBody,at,face,knobs)
		enemies.spawn(InhalerHead,at,face,_head_knobs.duplicate())
	overlay = SightOverlay.new()
	add_child(overlay)
	_wire()
	under = Underground.attach(self)
	for n: Node3D in [court,pyramid,hall]:
		print("city landmarks yard: %s tris %d sizes %s" % [n.name,int(n.get_meta("triangles")),str(n.get_meta("sizes"))])

## Where the Olmec starts: the plaza, the court's promenade, the stair's
## foot, the pyramid's summit court, the hall's high nave.
func olmec_at(where: String) -> Vector3:
	match where:
		"court": return court.transform*((court.get_meta("ports").promenade_r as Vector3))
		"pyramid": return pyramid.transform*((pyramid.get_meta("ports").summit as Vector3))
		"landing":
			var st: Node3D = pyramid.get_node("Stair")
			return pyramid.transform*st.transform*((st.get_meta("ports").landings as Array)[0] as Vector3)
		"stair": return pyramid.transform*((pyramid.get_meta("ports").stair_foot as Vector3)+Vector3(0.0,0.0,4.0))
		"hall": return hall.transform*Vector3(0.0,0.0,12.0)
	return OLMEC_AT.plaza

## The plaza's paving over its slab dropping into the abyss.
func _build_ground() -> void:
	var m := GiantStone.mesher()
	var shapes: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var nx := int(PLAZA.size.x/PAVE)
	var nz := int(PLAZA.size.y/PAVE)
	for i in nx:
		for j in nz:
			var c := Vector3(PLAZA.position.x+PLAZA.size.x/nx*(i+0.5),0.0,PLAZA.position.y+PLAZA.size.y/nz*(j+0.5))
			var sink := rng.randf_range(0.0,0.04)
			m.box(Transform3D(Basis.IDENTITY,c+Vector3(0.0,-1.0-sink,0.0)),Vector3(PLAZA.size.x/nx-0.08,2.0,PLAZA.size.y/nz-0.08),0.06,-2.0,rng.randf_range(0.82,1.08))
	var under_c := Vector3(PLAZA.get_center().x,-2.0-PLAZA_DEEP*0.5,PLAZA.get_center().y)
	m.box(Transform3D(Basis.IDENTITY,under_c),Vector3(PLAZA.size.x-1.0,PLAZA_DEEP,PLAZA.size.y-1.0),0.5,-2.0-PLAZA_DEEP,0.8)
	shapes.append(Fires.box_shape(Vector3(PLAZA.size.x,2.0+PLAZA_DEEP,PLAZA.size.y),Vector3(PLAZA.get_center().x,-(2.0+PLAZA_DEEP)*0.5,PLAZA.get_center().y)))
	Fires.mesh_node(self,m,"Plaza")
	Fires.solid(self,shapes,false,"PlazaSolid")
	var kind := Landmarks.cover_kind()
	if kind != "": preload("res://scripts/underground/ground_cover.gd").cover(self,PLAZA.grow(-0.5),kind,0.0,41,{"tufts":0.6,"fade":1.0})

func _wire() -> void:
	var b := stone_body()
	var h := stone_head()
	if b == null or h == null: return
	b.make_whole(h)
	b.breaker = hub
	if not b.chase_beat.is_connected(_beat): b.chase_beat.connect(_beat)
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

func reset_body() -> void:
	if enemies == null: return
	enemies.reset()
	if figure != null: figure.visible = true
	_wire()

func _beat(what: String) -> void:
	var said: String = {"spotted":"He sees you!","lost":"He lost you: he looks where he last saw you","gave up":"He gives up, and goes back",
		"pounce":"He crouches to pounce!","suck":"He plants and opens his jaw!","gulped":"Swallowed!","swat":"He raises his fists!",
		"caught swat":"Caught: swatted down","scope":"He lifts his head up to look…","scope none":"Nothing: he puts his head back",
		"caught pounce":"Caught: pounced on","missed":"He missed"}.get(what,what)
	_say(said,2.5)

## His feet on which landmark (for the HUD and the drivers).
func where_is(p: Vector3) -> String:
	for n: Node3D in [court,pyramid,hall]:
		var l := n.transform.affine_inverse()*p
		var s: Dictionary = n.get_meta("sizes")
		match n.name:
			"CityCourt":
				if absf(l.x) < float(s.width)*0.5 and absf(l.z) < float(s.long)*0.5: return "court"
			"CityPyramid":
				var pl: Array = s.platform
				if absf(l.x) < float(pl[0])*0.5 and l.z > -float(pl[0])*0.5 and l.z < float(pl[1])-float(pl[0])*0.5: return "pyramid"
			"CityHall":
				if absf(l.x) < float(s.width)*0.5 and absf(l.z) < float(s.long)*0.5: return "hall"
	return "plaza" if PLAZA.has_point(Vector2(p.x,p.z)) else "air"

func tick(delta: float) -> void:
	super.tick(delta)
	if under != null:
		if _sun != null: _sun.visible = false
		_hemi()
	var b := stone_body()
	if b == null and enemies != null and not _no_body:
		reset_body()
	if camera == null: return
	var q := float(hub.quake)*0.7 if hub != null else 0.0
	if b != null: q = maxf(q,float(b.quake)*clampf(1.0-camera.global_position.distance_to(b.global_position)/60.0,0.0,1.0))
	if q > 0.001:
		var t := Time.get_ticks_msec()/1000.0
		camera.position += Vector3(sin(t*61.0),sin(t*53.0+1.0),sin(t*47.0+2.0))*q*0.5

func _hemi() -> void:
	var p: Dictionary = under.get("p")
	var amb: Color = p.get("ambient",Color(0.2,0.27,0.4))
	var e := float(HEMI.get(str(under.get("preset")),0.2))
	RenderingServer.global_shader_parameter_set("zs_hemi_sky",Vector3(amb.r,amb.g,amb.b))
	RenderingServer.global_shader_parameter_set("zs_hemi_ground",Vector3(amb.r,amb.g,amb.b)*0.25)
	RenderingServer.global_shader_parameter_set("zs_hemi_energy",e)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and not _name_panel.visible:
		match (event as InputEventKey).keycode:
			KEY_R:
				reset_body()
				respawn()
				return
			KEY_B:
				reset_body()
				_say("He is back where he began",2.0)
				return
			KEY_J:
				_overlay_on = not _overlay_on
				_wire()
				return
			KEY_L:
				if under != null:
					under.cycle()
					return
	super._unhandled_input(event)

func _hint_text() -> String:
	return "City landmarks · W court (run into a ring's root, swing, chain) · N pyramid (stair, west prism chain, east kick chimneys, the shrine's door is yours) · E sundered hall (aisles, the fallen slab) · 1-9 0 - stations · R all back · B him back · J his sight · L torch/haze · F1 numbers"

func _show_hud() -> void:
	super._show_hud()
	if not _hud.visible: return
	var lines := PackedStringArray([_hud.text,""])
	var b := stone_body()
	if b != null:
		var s: RefCounted = b.sight
		lines.append("olmec  %s %.1fs · %s · on the %s · y %.1f · sight %s %.2f · catches %d · climbs %d · leaps %d" % [b.state,b.state_t,"hunting" if b.hunting else "calm",
			where_is(b.global_position),b.global_position.y,str(s.state) if s != null else "-",float(s.awareness) if s != null else 0.0,b.catches,b.climbs,b.leaps])
	lines.append("you on the %s · rope %s" % [where_is(motor.feet),"held" if motor.rider != null else "-"])
	_hud.text = "\n".join(lines)

func _voice(sound_name: StringName, at: Vector3) -> void:
	var key := String(sound_name)
	var spec: Variant = InhalerHead.VOICES.get(key,BodySpawner.VOICES.get(key))
	if spec == null: return
	if not _voices.has(key): _voices[key] = EnemyYard._synth(spec)
	var player := AudioStreamPlayer3D.new()
	player.stream = _voices[key]
	player.position = at
	player.unit_size = float(BodySpawner.REACH.get(key,30.0))
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
