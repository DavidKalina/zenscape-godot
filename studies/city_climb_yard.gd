extends "res://studies/whole_body_chase.gd"
## The city climb yard: the city
## kit's climb pieces (scripts/city_kit_climb.gd), lanes for two bodies, on a
## basalt plaza over the abyss, with a whole Olmec hunting (the chase, its
## periscope, chase routes, his breaks).
##   south-west  the giant's riser: treads a riser too tall for you; your
##               chimney is in its left cheek (the arch at its foot, west)
##   east        the hauling lip: a face up to a cornice he hauls himself over;
##               your shelves up its south end, the undercut under the
##               cornice your hide; its north corner is cracked
##   south       the leaper's pit, out to the far isle: the jump is his, the
##               cornice along the fins is yours (the east one cracks under
##               his landing)
##   north-east  the wrapped pillar over the void, its start on the plaza's
##               corner: his ramp round, your recess up the south face (a
##               cell halfway up the first stretch)
##   north       the hanging terrace off the plaza's edge: his stair, your
##               shelves up through the hatch; the undercroft is your hide
##   north-west  the wedged chunk: its top his ramp, the chimney beside it
##               yours, the hollow under its high end your hide
## You start south of the middle; he stands in the middle.
##   godot --path . res://studies/city_climb_yard.tscn -- --no-title
##     [--underground[=torch|haze]] [--ground=grass|dust|moss|off]
##     [--olmec=hunt|none|riser|lip|pit|wrap|terrace|wedge]  (a piece: his
##       headless body at its foot homing to his head on its top, his planner's lane)
##     [--body-knob=k=v] [--head-knob=k=v] [--body-at=x,z] [--body-face=x,z]
##     [--no-brazier]  (the lip's brazier unlit: it draws the calm Olmec up
##       the face and over the cornice to look)
##   1-7 the stations · R all back (the pieces rebuilt) · B him back · L the look
##   J his sight · F1 numbers
const Climb = preload("res://scripts/city_kit_climb.gd")
const CityKit = preload("res://scripts/city_kit.gd")
const Stone = preload("res://scripts/city_kit_stone.gd")
const Underground = preload("res://scripts/underground/underground.gd")
const GroundCover = preload("res://scripts/underground/ground_cover.gd")
const Breakables = preload("res://scripts/kit_isle/breakables.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")

const YARD_LOST := -40.0
## The plaza (x, z), its top 0, and the far isle past the pit.
const PLAZA := Rect2(-64.0,-64.0,128.0,128.0)
const PLAZA_DEEP := 6.0
const PAVE := 6.4
## Where each piece stands (its origin) and its yaw (deg): see `_spot`.
const RISER_AT := Vector3(-36.0,0.0,50.0)
const WEDGE_AT := Vector3(-36.0,0.0,-40.0)
## The pillar over the void off the plaza's north-east corner: its start
## corner's south edge on the plaza's edge (its lane 8.8 and bench: 12.36).
const WRAP_AT := Vector3(70.6,0.0,-82.96)
const OPTS := {"city_wrap":{"deep":30.0}}
## The lip's face on a planner column's edge (x a multiple of 1.5: his
## columns' middles 0.75 off it, clear of the cornice's overhang).
const LIP_FACE_X := 51.0
const LIP_Z := 24.0
const PIT_X := 10.0
const TERRACE_X := -8.0
const YARD_BODY_AT := Vector3(0.0,0.0,-4.0)
const YARD_PILOT_AT := Vector3(10.0,0.0,40.0)
## The walked tops the ground cover lies on.
const COVER_ON := ["tread","summit","cheek","top","plinth","landing","crown","deck","wall"]

var pieces := {}
var hub: Node3D
var under: Node3D
var olmec := "hunt"
var far_isle := Rect2()
var _environment: Environment
var _sun: DirectionalLight3D
var _cover_kind := ""
var _built_body := false
var _no_brazier := false

## Steps the field and hands every body the hub (spawned again on B).
class ClimbSlot extends Node:
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
	body_at = YARD_BODY_AT
	body_face = Vector2(0.0,1.0)
	for arg in LaunchArgs.user_args():
		if arg.begins_with("--olmec="): olmec = arg.get_slice("=",1)
		elif arg == "--no-body": olmec = "none"
		elif arg.begins_with("--body-face="):
			var f := arg.get_slice("=",1).split(",")
			body_face = Vector2(float(f[0]),float(f[1]) if f.size() > 1 else 0.0).normalized()
		elif arg.begins_with("--body-at="):
			var p := arg.get_slice("=",1).split(",")
			body_at = Vector3(float(p[0]),0.0,float(p[1]) if p.size() > 1 else 0.0)
		elif arg.begins_with("--ground="): _cover_kind = arg.get_slice("=",1)
		elif arg == "--no-brazier": _no_brazier = true
	super._ready()

## A piece's place: [origin, yaw deg].
static func _spot(id: String) -> Array:
	var s := Climb.sizes()
	match id:
		"city_riser": return [RISER_AT,0.0]
		"city_wedge": return [WEDGE_AT,0.0]
		"city_wrap": return [WRAP_AT,0.0]
		"city_lip":
			# Its foot on the plaza, its face west at LIP_FACE_X.
			var h := float(s.cornice)+float(s.undercut)+6.0*float(s.set_off)
			return [Vector3(LIP_FACE_X,h,LIP_Z),-90.0]
		"city_pit":
			# Its north plinth off the plaza's south edge.
			return [Vector3(PIT_X,0.0,PLAZA.end.y+float(s.landing)+float(s.pit_gap)*0.5),0.0]
		"city_terrace":
			# Its lower deck's front on the plaza's north edge.
			return [Vector3(TERRACE_X,0.0,PLAZA.position.y-3.5*float(s.cell)),0.0]
	return [Vector3.ZERO,0.0]

## A piece's named point (its meta ports; `i` into a list) in the world.
func port(id: String, name: String, i := -1) -> Vector3:
	var p: Node3D = pieces[id]
	var ports: Dictionary = p.get_meta("ports")
	var v: Variant = ports[name]
	var local: Vector3 = (v as Array)[i] if i >= 0 else v
	return p.global_transform*local

## Which piece's "hers" box (her lane, local AABBs) `at` is in ("" none).
func in_hers(at: Vector3, grow := 0.0) -> String:
	for id: String in pieces:
		var p: Node3D = pieces[id]
		var local := p.global_transform.affine_inverse()*at
		for box: AABB in p.get_meta("hers",[]):
			if box.grow(grow).has_point(local): return id
	return ""

func in_box(id: String, meta: String, at: Vector3, grow := 0.0) -> bool:
	var p: Node3D = pieces[id]
	var local := p.global_transform.affine_inverse()*at
	for box: AABB in p.get_meta(meta,[]):
		if box.grow(grow).has_point(local): return true
	return false

func _load_pack() -> void:
	start = YARD_PILOT_AT
	start_face = Vector2(0.0,-1.0)
	lost = YARD_LOST
	_last_stood = start
	var s := Climb.sizes()
	var riser := RISER_AT+Vector3(0.0,0.0,4.0)
	var lip_foot := Vector3(LIP_FACE_X-5.0,0.0,LIP_Z)
	var pit_n := Vector3(PIT_X,0.0,PLAZA.end.y-3.0)
	var wrap := WRAP_AT+Vector3(-float(s.core)*0.5-float(s.lane)*0.5,0.0,float(s.core)*0.5+float(s.lane)+3.0)
	var terrace := Vector3(TERRACE_X+12.0,0.0,PLAZA.position.y+6.0)
	var wedge := WEDGE_AT+Vector3(0.0,0.0,float(s.wedge_run)+4.0)
	stations = [
		{"key":1,"name":"City climb yard","spawn":YARD_PILOT_AT,"face":start_face,"parts":[]},
		{"key":2,"name":"Giant's riser","spawn":riser,"face":Vector2(0.0,-1.0),"parts":[]},
		{"key":3,"name":"Hauling lip","spawn":lip_foot,"face":Vector2(1.0,0.0),"parts":[]},
		{"key":4,"name":"Leaper's pit","spawn":pit_n,"face":Vector2(0.0,1.0),"parts":[]},
		{"key":5,"name":"Wrapped pillar","spawn":wrap,"face":Vector2(0.0,-1.0),"parts":[]},
		{"key":6,"name":"Hanging terrace","spawn":terrace,"face":Vector2(0.0,-1.0),"parts":[]},
		{"key":7,"name":"Wedged chunk","spawn":wedge,"face":Vector2(0.0,-1.0),"parts":[]},
	]

func _build_light() -> void:
	super._build_light()
	for n: Node in get_children():
		if n is WorldEnvironment: _environment = (n as WorldEnvironment).environment
		elif n is DirectionalLight3D: _sun = n

func _build_room() -> void:
	_build_plaza()
	_build_pieces()
	hub = Breakables.new()
	add_child(hub)
	if olmec == "hunt":
		super._build_room()
		hub.field = enemies
		hub.sound_hook = _voice
		var slot := ClimbSlot.new()
		slot.field = enemies
		slot.hub = hub
		add_child(slot)
		foot_pieces = slot
		var b := stone_body()
		if b != null: b.breaker = hub
	else:
		_build_field()
		if olmec != "none": _build_homing()
	under = Underground.attach(self)
	_cover()
	var n := Climb.numbers()
	print("city climb yard: wanderer tall %.2f grab %.3f chain %.3f rise %.2f · olmec hh %.2f width %.2f depth %.2f neck %.2f reach %.2f climb %.1f step %.2f stair %.2f jump gap %.2f press %.2f bulk %.2f" % [
		n.tall,n.grab,n.chain,n.rise,n.hh,n.width,n.length,n.neck,n.reach,n.climb_max,n.step,n.stair,n.jump_gap,n.press,n.bulk])
	for f: Array in Climb.fit(): print("city climb fit: %s %.2f vs %.2f %s" % [f[0],float(f[1]),float(f[2]),"ok" if f[3] else "NO"])
	for id: String in pieces: print("city climb yard: %s tris %d %s" % [id,int(pieces[id].get_meta("triangles")),str(pieces[id].get_meta("sizes"))])

## The field with no whole Olmec (homing, or none).
func _build_field() -> void:
	enemies = EnemyField.new()
	enemies.study = self
	enemies.motor = motor
	enemies.lost = lost
	enemies.sound_hook = _voice
	add_child(enemies)
	hub.field = enemies
	hub.sound_hook = _voice
	var slot := ClimbSlot.new()
	slot.field = enemies
	slot.hub = hub
	add_child(slot)
	foot_pieces = slot
	overlay = SightOverlay.new()
	add_child(overlay)

## `--olmec=<piece>`: his headless body at the piece's foot, his head on its
## top: he walks his planner's lane to it (the city kit gallery's proof).
func _build_homing() -> void:
	var id := "city_"+olmec
	if not pieces.has(id):
		push_error("city climb yard: no piece %s" % id)
		return
	var from: Vector3
	var to: Vector3
	match id:
		"city_riser":
			from = port(id,"foot")+Vector3(0.0,0.0,4.0)
			to = port(id,"summit")
		"city_lip":
			from = port(id,"foot")+Vector3(-6.0,0.0,0.0)
			to = port(id,"top")
		"city_pit":
			from = port(id,"north")+Vector3(0.0,0.0,-8.0)
			to = Vector3(far_isle.get_center().x,0.0,far_isle.get_center().y)
		"city_wrap":
			from = port(id,"foot")
			to = port(id,"crown")
		"city_terrace":
			from = port(id,"lower")
			to = port(id,"upper")
		"city_wedge":
			from = port(id,"foot")
			to = port(id,"crown")
	if body_at != YARD_BODY_AT: from = body_at
	var face := Vector2(to.x-from.x,to.z-from.z).normalized()
	var knobs := {"hear":400.0,"listen":1.2,"listen_every":12.0}
	knobs.merge(_body_knobs,true)
	enemies.spawn(HeadlessBody,from,face,knobs)
	var head_knobs := {"ring":2.0}
	head_knobs.merge(_head_knobs,true)
	enemies.spawn(InhalerHead,to,-face,head_knobs)
	_built_body = true

func _wire() -> void:
	if olmec != "hunt": return
	super._wire()
	var b := stone_body()
	if b != null and hub != null: b.breaker = hub

## The body's knobs here: the chase's periscope, its routes at an edge.
func _study_body_knobs() -> Dictionary:
	return {"periscope":1,"chase_routes":1}

func reset_body() -> void:
	if olmec == "hunt":
		super.reset_body()
		return
	if enemies == null or olmec == "none": return
	enemies.reset()
	if figure != null: figure.visible = true

## The plaza: one collider, big basalt flags; the far isle past the pit.
func _build_plaza() -> void:
	var s := Climb.sizes()
	var pit_spot: Array = _spot("city_pit")
	var pit_far := (pit_spot[0] as Vector3).z+float(s.pit_gap)*0.5+float(s.landing)
	far_isle = Rect2(PIT_X-22.0,pit_far,44.0,34.0)
	for r: Rect2 in [PLAZA,far_isle]:
		var b := StaticBody3D.new()
		b.name = "Plaza" if r == PLAZA else "FarIsle"
		var c := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(r.size.x,PLAZA_DEEP,r.size.y)
		c.shape = box
		c.position = Vector3(r.get_center().x,-PLAZA_DEEP*0.5,r.get_center().y)
		b.add_child(c)
		add_child(b)
		var m := Stone.Mesher.new(Stone.stone_colour(),0.15)
		var rng := RandomNumberGenerator.new()
		rng.seed = 41 if r == PLAZA else 43
		var nx := int(r.size.x/PAVE)
		var nz := int(r.size.y/PAVE)
		for i in nx:
			for j in nz:
				var x := r.position.x+(float(i)+0.5)*r.size.x/nx
				var z := r.position.y+(float(j)+0.5)*r.size.y/nz
				var sink := rng.randf_range(-0.04,0.0)
				m.solid(Stone.box(Transform3D(Basis.IDENTITY,Vector3(x,-0.3+sink,z)),Vector3(r.size.x/nx*0.5-0.04,0.3,r.size.y/nz*0.5-0.04),0.06),NAN,rng.randf_range(0.82,1.02))
		# The plaza's rim: the stone goes down into the haze.
		m.solid(Stone.box(Transform3D(Basis.IDENTITY,Vector3(r.get_center().x,-PLAZA_DEEP*0.5-0.6,r.get_center().y)),Vector3(r.size.x*0.5-0.1,PLAZA_DEEP*0.5,r.size.y*0.5-0.1),0.2),NAN,0.8)
		var mi := MeshInstance3D.new()
		mi.name = "Paving"
		mi.mesh = Stone.mesh_of(m)
		add_child(mi)

func _build_pieces() -> void:
	for id: String in Climb.PIECES:
		var spot: Array = _spot(id)
		var o: Dictionary = OPTS.get(id,{}).duplicate()
		# The brazier lit only for the whole Olmec (a homing body would
		# turn to it and leave his piece).
		if id == "city_lip": o["brazier"] = olmec == "hunt" and not _no_brazier
		var p: Node3D = Climb.piece(id,7,0.4,o)
		p.position = spot[0]
		p.rotation.y = deg_to_rad(float(spot[1]))
		add_child(p)
		pieces[id] = p

## R: the pieces stood again (their breaks whole), every body's routes told.
func rebuild_pieces() -> void:
	for id: String in pieces:
		var p: Node3D = pieces[id]
		remove_child(p)
		p.queue_free()
	pieces = {}
	_build_pieces()
	_cover()
	if hub != null: hub.changed(AABB(Vector3(-120.0,-40.0,-120.0),Vector3(240.0,120.0,260.0)))

## The underground's ground cover (grass, unless `--ground=` asks another)
## on the plaza and the pieces' flat tops.
func _cover() -> void:
	var kind := _cover_kind if _cover_kind != "" else "grass"
	if kind == "off": return
	if under != null and kind != under.ground:
		under.ground = kind
		under._set_motes()
	GroundCover.cover(self,PLAZA.grow(-0.5),kind,0.0,41,{"tufts":0.5,"fade":1.0})
	GroundCover.cover(self,far_isle.grow(-0.5),kind,0.0,43,{"tufts":0.5,"fade":1.0})
	var k := 0
	for id: String in pieces:
		var p: Node3D = pieces[id]
		for a: Dictionary in p.get_meta("walk_areas",[]):
			if not String(a.kind) in COVER_ON: continue
			GroundCover.cover(p,a.poly,kind,float(a.y),51+k,{"tufts":0.6})
			k += 1

func tick(delta: float) -> void:
	super.tick(delta)
	if under != null and _sun != null: _sun.visible = false
	if camera != null and hub != null:
		var q := float(hub.quake)*0.7
		if q > 0.001:
			var t := Time.get_ticks_msec()/1000.0
			camera.position += Vector3(sin(t*61.0),sin(t*53.0+1.0),sin(t*47.0+2.0))*q*0.5

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and not _name_panel.visible:
		var key := (event as InputEventKey).keycode
		if key == KEY_R:
			rebuild_pieces()
			reset_body()
			respawn()
			_say("All back: the pieces whole, him where he began",2.0)
			return
		if key == KEY_L and under != null:
			under.cycle()
			return
	super._unhandled_input(event)

func _hint_text() -> String:
	return "City climb: his lanes are wide, yours are cut into the stone · riser SW (your chimney: the arch in its west cheek) · lip E (shelves at its south end, hide in the undercut) · pit S (his jump, your cornice) · pillar NE (your recess, the cell) · terrace N (the hatch; hide in the undercroft) · chunk NW (the chimney, the hollow) · 1-7 stations · R all back · B him · L look · J sight · F1"

func _show_hud() -> void:
	super._show_hud()
	if not _hud.visible: return
	var lines := PackedStringArray([_hud.text])
	var b := stone_body() if olmec == "hunt" else _homing_body()
	if b != null:
		lines.append("olmec  %s · y %.1f · in her lane: %s · %s" % [b.state,b.position.y,in_hers(b.position) if in_hers(b.position) != "" else "no",b.route_stats()])
	var you := in_hers(motor.feet)
	lines.append("you  %s" % ("in your lane on "+you if you != "" else "in the open"))
	_hud.text = "\n".join(lines)

func _homing_body() -> Node3D:
	if enemies == null: return null
	for e in enemies.enemies:
		if is_instance_valid(e) and e.has_method("make_whole"): return e
	return null
