extends "res://studies/whole_body_chase.gd"
## The city refuges yard (docs/design/roguelike/city-refuges-round1.md): the
## city kit's four places the Olmec can't follow (scripts/city_kit_refuges.gd)
## on one paved basalt court, a whole Olmec hunting you among them (the
## whole body chase's: sight, swat, pounce, inhale, periscope).
##   north   the hush gallery: a servants' slit into a tier, his forecourt
##           before it (he stands at his post there, facing it); the trough
##           inside snuffs your torch, the lamp by the east exit relights it
##   west    the mouse run through a wall he can't climb: walk round it, he must
##   east    the slotted wall: the door at its foot, the chimney inside, his
##           arm slot at his shoulder; out of the window at the top, west side
##   south-east  the votive niches up a pier he can't climb, to a dark alcove
## You start south, behind him.
##   godot --path . res://studies/city_refuges_yard.tscn -- --no-title
##     [--underground[=torch|haze]] [--body-knob=k=v] [--head-knob=k=v]
##     [--body-at=x,z] [--body-face=x,z] [--no-body] [--no-sight-overlay]
##   R you back at the start (him too) · B him back · J his sight · L the look
const Refuges = preload("res://scripts/city_kit_refuges.gd")
const GiantStone = preload("res://scripts/kit_isle/greybox/giant_stone.gd")
const Underground = preload("res://scripts/underground/underground.gd")

const COURT := Rect2(-62.0,-62.0,124.0,124.0)
const YARD_LOST := -30.0
## Where each piece stands and the way its front (local +z) faces (yaw, deg).
const PIECES := [
	["city_hush",Vector3(0.0,0.0,-34.0),0.0],
	["city_mouserun",Vector3(-34.0,0.0,0.0),90.0],
	["city_slotwall",Vector3(34.0,0.0,0.0),-90.0],
	["city_niches",Vector3(26.0,0.0,34.0),180.0],
]
## His post: in the gallery's forecourt, facing its slit; your start.
const POST := Vector3(0.0,0.0,-18.0)
const POST_FACE := Vector2(0.0,-1.0)
const START_AT := Vector3(0.0,0.0,30.0)

var under: Node3D
var refuges := {}
var _environment: Environment
var _sun: DirectionalLight3D
var _no_body := false

func _ready() -> void:
	body_at = POST
	body_face = POST_FACE
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg == "--no-body": _no_body = true
		elif arg.begins_with("--body-face="):
			var f := arg.get_slice("=",1).split(",")
			body_face = Vector2(float(f[0]),float(f[1]) if f.size() > 1 else 0.0).normalized()
		elif arg.begins_with("--body-at="):
			var p := arg.get_slice("=",1).split(",")
			body_at = Vector3(float(p[0]),0.0,float(p[1]) if p.size() > 1 else 0.0)
	super._ready()

func _load_pack() -> void:
	start = START_AT
	start_face = Vector2(0.0,-1.0)
	lost = YARD_LOST
	_last_stood = start
	stations = [{"key":1,"name":"City refuges yard","spawn":START_AT,"face":start_face,"parts":[]}]

func _build_light() -> void:
	super._build_light()
	for n: Node in get_children():
		if n is WorldEnvironment: _environment = (n as WorldEnvironment).environment
		elif n is DirectionalLight3D: _sun = n

func _build_room() -> void:
	_build_court()
	for p: Array in PIECES:
		var r: Node3D = Refuges.piece(p[0],7)
		r.position = p[1]
		r.rotation.y = deg_to_rad(float(p[2]))
		add_child(r)
		refuges[p[0]] = r
	if _no_body:
		_build_room_no_body()
	else:
		super._build_room()
	under = Underground.attach(self)
	var o := Refuges.olmec()
	print("city refuges yard: olmec width %.2f depth %.2f neck %.2f reach %.2f climb_max %.1f · walker %s" % [o.width,o.length,o.neck,o.reach,o.climb_max,str(Refuges.walker())])
	for k: String in refuges: print("city refuges yard: %s %s tris %d" % [k,str(refuges[k].get_meta("sizes")),int(refuges[k].get_meta("tris"))])

## The stations' (empty) parts and the start label only, no enemies.
func _build_room_no_body() -> void:
	enemies = EnemyField.new()
	enemies.study = self
	enemies.motor = motor
	enemies.lost = lost
	add_child(enemies)
	overlay = SightOverlay.new()
	add_child(overlay)

## The paved court: one collider, big basalt flags (the Olmec's stone).
func _build_court() -> void:
	var b := StaticBody3D.new()
	b.name = "Court"
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = Vector3(COURT.size.x,4.0,COURT.size.y)
	c.shape = s
	c.position = Vector3(COURT.get_center().x,-2.0,COURT.get_center().y)
	b.add_child(c)
	add_child(b)
	var m := Refuges.CityMesher.new(GiantStone.stone_colour())
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var flag := 6.2
	var nx := int(COURT.size.x/flag)
	var nz := int(COURT.size.y/flag)
	for i in nx:
		for j in nz:
			var x := COURT.position.x+(float(i)+0.5)*COURT.size.x/nx
			var z := COURT.position.y+(float(j)+0.5)*COURT.size.y/nz
			var sink := rng.randf_range(-0.04,0.0)
			m.box(Transform3D(Basis.IDENTITY,Vector3(x,-0.3+sink,z)),Vector3(COURT.size.x/nx-0.06,0.6,COURT.size.y/nz-0.06),0.08,-0.6,rng.randf_range(0.82,1.02))
	# The underground's ground cover over the paving (nothing with the look off).
	preload("res://scripts/underground/ground_cover.gd").cover(self,COURT.grow(-0.5),"",0.0,41,{"tufts":0.5,"fade":1.0})
	var mi := MeshInstance3D.new()
	mi.name = "Paving"
	mi.mesh = m.mesh(Refuges.stone_material(),null)
	add_child(mi)

## The body's knobs here: the chase's periscope, and walker-only stone hides
## you (the round's decision; `--body-knob=sight_walker_only=0` to compare).
func _study_body_knobs() -> Dictionary:
	return {"periscope":1,"sight_walker_only":1}

func tick(delta: float) -> void:
	super.tick(delta)
	if under != null and _sun != null: _sun.visible = false

func _hint_text() -> String:
	return "City refuges · gallery N (trough snuffs, east lamp relights) · mouse run W · slotted wall E · niches SE · J his sight · B him back · R start · L look · F1 numbers"
