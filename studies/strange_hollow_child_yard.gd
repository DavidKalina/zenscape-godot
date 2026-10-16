extends "res://studies/whole_body_chase.gd"
## The Hollow Child's yard (card x5-hollow, round 4 "strange city"): one paved
## basalt court in the
## underground dark (torch by default; `--underground=haze`), a whole Olmec
## at his post hunting (sight, swat, pounce, inhale, periscope), a lit route
## past his front, and the Hollow Child (scripts/city_hollow_child.gd) sitting
## on that route in his sight.
##   you start   south-west; the route runs north up the west side, then east
##               across his front (cressets lit along it), then north up the
##               east side to the far gate behind him
##   the Olmec   at his post north of the route, facing it (south)
##   the child   on the route, in front of him: sit with it and you are dark
##               to him with your torch lit, until it fills and cries; then
##               it is a beacon he comes to, and you are standing in it
##   a cresset   unlit, beside the child, in its reach: light it and it fills
##               the child fast (a lure you set and run from); its flame is
##               drunk while the child drinks, so it draws no one
##   the gate    north-east, behind him: reach it
##   godot --path . res://studies/strange_hollow_child_yard.tscn -- --no-title
##     [--underground[=torch|haze]] [--hollow-knob=k=v] [--body-knob=k=v]
##     [--head-knob=k=v] [--body-at=x,z] [--body-face=x,z] [--no-body]
##     [--sight-overlay]
##   T your torch out / lit (relight it at any lit cresset) · H the child
##   empty again · K the side cresset out · R you back at the start (him and
##   the child too) · B him back · J his sight · L the look · F1 numbers
const Fires = preload("res://scripts/city_kit_fires.gd")
const HollowChild = preload("res://scripts/city_hollow_child.gd")
const Refuges = preload("res://scripts/city_kit_refuges.gd")
const GiantStone = preload("res://scripts/kit_isle/greybox/giant_stone.gd")
const Underground = preload("res://scripts/underground/underground.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")

const COURT := Rect2(-44.0,-52.0,88.0,96.0)
const YARD_LOST := -30.0
## His post and the way he faces; your start.
const POST := Vector3(0.0,0.0,-22.0)
const POST_FACE := Vector2(0.0,1.0)
const START_AT := Vector3(-32.0,0.0,34.0)
## The child: where it sits and the way it faces (yaw, deg; 180 faces north,
## toward him).
const CHILD_AT := Vector3(2.0,0.0,2.0)
const CHILD_YAW := 180.0
## The route's lit cressets, and the one beside the child (unlit).
const ROUTE_CRESSETS := [Vector3(-37.0,0.0,16.0),Vector3(-22.0,0.0,-7.0),Vector3(20.0,0.0,-7.0),Vector3(37.0,0.0,-26.0)]
const SIDE_CRESSET := Vector3(5.4,0.0,3.6)
## Broken drums for cover: [x, z, radius, top].
const DRUMS := [[-14.0,12.0,1.6,6.0],[16.0,14.0,1.8,8.0],[-30.0,-30.0,2.0,9.0]]
## The far gate (its middle) and how near counts as through.
const GATE := Vector3(33.0,0.0,-46.0)
const GATE_NEAR := 3.5

var under: Node3D
var child: Node3D
var side: Node3D
var route: Array = []
var _environment: Environment
var _sun: DirectionalLight3D
var _no_body := false
var _child_knobs := {}
var _gate_said := false
## Times he spotted you since you set out (for the gate's verdict).
var _spots_from := 0

func _ready() -> void:
	pack = "strange_hollow_child"
	body_at = POST
	body_face = POST_FACE
	_overlay_on = false
	var args := LaunchArgs.user_args()
	# The underground look by default (torch); --day leaves it off.
	var asked := false
	for a: String in args:
		if a == "--underground" or a.begins_with("--underground="): asked = true
	if not asked and not args.has("--day"):
		var with := PackedStringArray(args)
		with.append("--underground=torch")
		LaunchArgs.set_override(with)
	for arg in LaunchArgs.user_args():
		if arg == "--no-body": _no_body = true
		elif arg == "--sight-overlay": _overlay_on = true
		elif arg.begins_with("--body-face="):
			var f := arg.get_slice("=",1).split(",")
			body_face = Vector2(float(f[0]),float(f[1]) if f.size() > 1 else 0.0).normalized()
		elif arg.begins_with("--body-at="):
			var p := arg.get_slice("=",1).split(",")
			body_at = Vector3(float(p[0]),0.0,float(p[1]) if p.size() > 1 else 0.0)
	_child_knobs = HollowChild.knobs_from(LaunchArgs.user_args())
	super._ready()
	# whole_body_chase reads --no-sight-overlay only: here it is off unless asked.
	if overlay != null and not _overlay_on:
		overlay.visible = false
		overlay._layer.visible = false

func _load_pack() -> void:
	start = START_AT
	start_face = Vector2(0.0,-1.0)
	lost = YARD_LOST
	_last_stood = start
	stations = [{"key":1,"name":"Hollow Child yard","spawn":START_AT,"face":start_face,"parts":[]}]

func _build_light() -> void:
	super._build_light()
	for n: Node in get_children():
		if n is WorldEnvironment: _environment = (n as WorldEnvironment).environment
		elif n is DirectionalLight3D: _sun = n
	camera.far = 900.0

func _build_room() -> void:
	_build_court()
	var fires := Node3D.new()
	fires.name = "Fires"
	add_child(fires)
	for i in ROUTE_CRESSETS.size():
		var c: Node3D = Fires.cresset(fires,Transform3D(Basis.IDENTITY,ROUTE_CRESSETS[i]),{"size":"cresset","seed":11+i,"lit":true,"barge":false,"name":"RouteCresset%d" % i})
		# The route's lamps: they light you, but long burning, they are no
		# news to him (no draw), so the child's cry and the side cresset are
		# the only lures here.
		c.beacon.draw = 1.0
		route.append(c)
	side = Fires.cresset(fires,Transform3D(Basis.IDENTITY,SIDE_CRESSET),{"size":"cresset","seed":31,"barge":false,"name":"SideCresset"})
	side.lit_changed.connect(func(on: bool) -> void:
		if on: _say("The cresset catches, and its flame bends to the child's mouth",3.0))
	child = HollowChild.new()
	child.name = "HollowChild"
	child.knobs.merge(_child_knobs,true)
	child.position = CHILD_AT
	child.rotation.y = deg_to_rad(CHILD_YAW)
	add_child(child)
	child.state_changed.connect(_child_said)
	if _no_body:
		enemies = EnemyField.new()
		enemies.study = self
		enemies.motor = motor
		enemies.lost = lost
		add_child(enemies)
		overlay = SightOverlay.new()
		add_child(overlay)
	else:
		super._build_room()
	under = Underground.attach(self)
	print("hollow child yard: child at %s (reach %.1f m), post %s %.1f m off, side cresset %.1f m from its heart" % [str(CHILD_AT),child.drinker.radius,str(body_at),Vector2(CHILD_AT.x-body_at.x,CHILD_AT.z-body_at.z).length(),child.drinker.global_position.distance_to(side.beacon.global_position)])

## The paved court, its drums and the far gate: the Olmec's basalt.
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
	rng.seed = 47
	var flag := 6.0
	var nx := int(COURT.size.x/flag)
	var nz := int(COURT.size.y/flag)
	for i in nx:
		for j in nz:
			var x := COURT.position.x+(float(i)+0.5)*COURT.size.x/nx
			var z := COURT.position.y+(float(j)+0.5)*COURT.size.y/nz
			var sink := rng.randf_range(-0.04,0.0)
			m.box(Transform3D(Basis.IDENTITY,Vector3(x,-0.3+sink,z)),Vector3(COURT.size.x/nx-0.06,0.6,COURT.size.y/nz-0.06),0.08,-0.6,rng.randf_range(0.82,1.02))
	var shapes: Array = []
	for d: Array in DRUMS:
		var at := Vector3(float(d[0]),float(d[3])*0.5,float(d[1]))
		m.cylinder(Transform3D(Basis.IDENTITY,at),float(d[2]),float(d[3]),14,0.18,0.0)
		shapes.append(Fires.cyl_shape(float(d[2]),float(d[3]),at))
	# The gate: two piers and a lintel, wide enough to walk through.
	for sx: float in [-3.2,3.2]:
		var at := GATE+Vector3(sx,4.0,0.0)
		m.box(Transform3D(Basis.IDENTITY,at),Vector3(1.6,8.0,1.6),0.12,0.0)
		shapes.append(Fires.box_shape(Vector3(1.6,8.0,1.6),at))
	var lintel := GATE+Vector3(0.0,8.7,0.0)
	m.box(Transform3D(Basis.IDENTITY,lintel),Vector3(8.4,1.4,1.9),0.14,8.0)
	shapes.append(Fires.box_shape(Vector3(8.4,1.4,1.9),lintel))
	Fires.solid(self,shapes,false,"CourtSolid")
	preload("res://scripts/underground/ground_cover.gd").cover(self,COURT.grow(-0.5),"",0.0,47,{"tufts":0.5,"fade":1.0})
	var mi := MeshInstance3D.new()
	mi.name = "Paving"
	mi.mesh = m.mesh(Refuges.stone_material(),null)
	add_child(mi)

func _study_body_knobs() -> Dictionary:
	return {"periscope":1}

## Set down (R): him, and the child empty again.
func place(at: Vector3, face: Vector2) -> void:
	super.place(at,face)
	if child != null: child.reset()
	Fires.set_torch(get_tree(),true)
	_gate_said = false
	var b := stone_body()
	_spots_from = int(b.spots) if b != null else 0

func _child_said(s: String) -> void:
	match s:
		"drinking": _say("Your flame leans to the child's mouth: it drinks. He can't see your torch here",3.0)
		"breath": _say("It draws a breath…",2.0)
		"cry": _say("It cries! All the light pours out: every Olmec turns to it",3.5)
		"spent": _say("It goes cold and quiet",2.5)

func tick(delta: float) -> void:
	super.tick(delta)
	if under != null and _sun != null: _sun.visible = false
	if not _gate_said and motor != null and Vector2(motor.feet.x-GATE.x,motor.feet.z-GATE.z).length() < GATE_NEAR:
		_gate_said = true
		var b := stone_body()
		var seen := (int(b.spots) if b != null else 0)-_spots_from
		_say("Through the gate%s" % (" unseen!" if seen == 0 else ", seen %d time%s" % [seen,"" if seen == 1 else "s"]),4.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and not _name_panel.visible:
		match (event as InputEventKey).keycode:
			KEY_T:
				var on := not Fires.torch_lit(get_tree())
				Fires.set_torch(get_tree(),on)
				_say("Torch lit" if on else "Torch out (relight it at a lit cresset)",2.0)
				return
			KEY_H:
				child.reset()
				_say("The child is empty again",2.0)
				return
			KEY_K:
				side.douse()
				_say("The side cresset is out",2.0)
				return
			KEY_L:
				if under != null:
					under.cycle()
					return
	super._unhandled_input(event)

func _hint_text() -> String:
	return "Hollow Child · sit by it torch lit: he can't see you, but it fills · full, it cries and he comes · light the cresset beside it to fill it fast · reach the gate NE · T torch · H child empty · K side cresset out · J his sight · B him back · R start · L look · F1 numbers"

func _show_hud() -> void:
	super._show_hud()
	if not _hud.visible: return
	var lines := PackedStringArray([_hud.text])
	if child != null: lines.append(child.describe())
	var me: Vector3 = motor.feet+Vector3.UP
	lines.append("light on you %.2f (glow %.2f, drunk %.0f%%) · torch %s" % [LightLevel.exposure(get_tree(),me),LightLevel.glow(get_tree(),me),LightDrinker.drunk(get_tree(),me)*100.0,"lit" if Fires.torch_lit(get_tree()) else "out"])
	var b := stone_body()
	if b != null: lines.append("olmec beacon %s (turns %d, visits %d)" % [str(b.beacon.get_parent().name) if b.beacon != null else "-",b.beacon_turns,b.beacon_visits])
	_hud.text = "\n".join(lines)
