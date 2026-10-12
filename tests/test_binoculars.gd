extends SceneTree
## The binoculars (scripts/binoculars.gd, docs/design/binoculars/round1.md),
## headless, on the aqueduct isle with its motif isles: held on the ground
## they come up over RAISE s into the view from his eyes (narrowed, his
## figure hidden), he only shuffles and doesn't jump, let go they come down
## and the chase camera's fov is back; they don't come up in the air or in
## the plane. Aimed at the bell spires from the isle, their card shows after
## the dwell and fades when the view leaves them; `pick` chooses by aim. A
## far find in plain sight glints only while they're up, never near, never
## once found; the isle's unfound tokens are listed to glint. The look is
## slowed by the zoom, the zoom kept in its range.
##   godot --headless --path . --script tests/test_binoculars.gd
const DT := 1.0/60.0
const Binoculars = preload("res://scripts/binoculars.gd")
const Ledger = preload("res://scripts/ledger/ledger.gd")
var failures := 0
var study: Node3D

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(150.0).timeout.connect(func() -> void: push_error("binoculars test timed out"); quit(2))
	study = load("res://studies/aqueduct_isle.tscn").instantiate()
	study.scripted = true
	study.chain_on = false
	root.add_child(study)
	current_scene = study
	while not study.flora_ready: await process_frame
	await physics_frame
	study.sky.flush()
	await physics_frame
	_pick()
	_raise_lower()
	_card()
	_glints()
	_look()
	_on_foot_only()
	print("PASS: binoculars" if failures == 0 else "FAIL: binoculars (%d)" % failures)
	quit(1 if failures > 0 else 0)

func _ticks(seconds: float) -> void:
	for i in range(int(round(seconds/DT))):
		study.tick(DT)
		var card: CanvasLayer = study.binoculars.splash
		if card.visible: card._process(DT)

## Points them from his eyes at `at`.
func _aim_at(at: Vector3) -> void:
	var b: Node = study.binoculars
	var to: Vector3 = at-b.eye()
	b.yaw = atan2(-to.x,-to.z)
	b.pitch = atan2(to.y,Vector2(to.x,to.z).length())

func _pick() -> void:
	var isles := [{"middle":Vector3(100.0,0.0,0.0),"radius":20.0,"top":10.0,"isle":null,"n":1},
		{"middle":Vector3(0.0,0.0,-100.0),"radius":20.0,"top":10.0,"isle":null,"n":2},
		{"middle":Vector3.ZERO,"radius":50.0,"top":5.0,"isle":null,"n":3}]
	var from := Vector3(0.0,5.0,0.0)
	check(int(Binoculars.pick(isles,from,Vector3(1.0,0.0,0.0)).get("n",0)) == 1,"pick: aimed east, the isle east (not the one stood on)")
	check(int(Binoculars.pick(isles,from,Vector3(0.05,0.02,-1.0).normalized()).get("n",0)) == 2,"pick: aimed north, near enough its middle, the isle north")
	check(Binoculars.pick(isles,from,Vector3(-1.0,0.0,0.0)).is_empty(),"pick: aimed at open sky, none")
	check(Binoculars.pick(isles,from,Vector3(1.0,0.0,1.0).normalized()).is_empty(),"pick: aimed between, none")

func _raise_lower() -> void:
	var b: Node = study.binoculars
	_ticks(1.0)
	check(b != null and study.binoculars_allowed(),"Stood on the ground, they may come up (move '%s')" % study.motor.move)
	var chase_fov: float = study.camera.fov
	study.script_binoculars = true
	_ticks(0.1)
	check(b.busy() and not b.raised(),"Coming up over %.2f s (%.2f up after 0.1 s)" % [Binoculars.RAISE,b.up])
	check(b.pair.visible and study.body.visible,"On the way up he holds the pair and is seen")
	_ticks(0.25)
	check(b.raised(),"Up after %.2f s" % Binoculars.RAISE)
	check(study.camera.global_position.distance_to(b.eye()) < 0.05,"The camera at his eyes (%.3f m off)" % study.camera.global_position.distance_to(b.eye()))
	check(absf(study.camera.fov-b.lens_fov()) < 0.01 and b.lens_fov() < chase_fov/2.0,"The view narrowed to %.1fx (fov %.1f, chase %.1f)" % [b.zoom,study.camera.fov,chase_fov])
	check(not study.body.visible and not b.pair.visible and b._overlay.visible,"Up, his figure is out of the lens and the circles close round it")
	check(str(study._switch_hint.text).contains("Binoculars"),"The hint says how to look and zoom")
	var start: Vector3 = study.motor.feet
	study.script_want = Vector2(0.0,1.0)
	study.script_jump = true
	_ticks(1.0)
	study.script_want = Vector2.ZERO
	study.script_jump = false
	var pace: float = study.motor.speed()
	check(study.motor.grounded and pace < 1.0 and b.raised(),"Up, he shuffles (%.2f m/s, %.2f m) and doesn't jump" % [pace,start.distance_to(study.motor.feet)])
	var yaw: float = b.yaw
	study.script_binoculars = false
	_ticks(0.4)
	check(not b.busy() and study.body.visible and not b._overlay.visible,"Let go, they come down and he is seen")
	check(absf(angle_difference(float(study._yaw),yaw)) < 0.01,"The chase camera looks where they looked")
	_ticks(2.0)
	check(absf(study.camera.fov-chase_fov) < 0.5,"The chase camera's fov is back (%.1f, was %.1f)" % [study.camera.fov,chase_fov])

func _card() -> void:
	var b: Node = study.binoculars
	var bell: Node3D = study.motifs.isles[0]
	var c: Vector3 = bell.circle()
	study.script_binoculars = true
	_ticks(0.3)
	_aim_at(Vector3(c.x,bell.isle_top()-c.z*0.25,c.y))
	_ticks(0.2)
	check(b.aimed.get("isle") == bell and b.carded == null,"Aimed at the bell spires, they're picked; no card before the dwell")
	_ticks(0.5)
	check(b.carded == bell and b.splash.visible and str(b.splash._name.text) == "SPIRES OF THE SILENT BELL","After %.1f s their card shows (%s)" % [Binoculars.DWELL,str(b.splash._name.text)])
	var finds: Array = b.splash.card.get("finds",[])
	var total := int(Ledger.shared().isle_progress("bell_spires").total)
	var rows := 0
	for row: Array in finds: rows += int(row[3])
	check(not finds.is_empty() and rows == total and total > 0,"The card counts the ledger's finds (%s, %d listed)" % [finds,total])
	_ticks(6.0)
	check(b.splash.visible,"It stays while they rest on the isle")
	b.pitch = 1.1
	_ticks(0.1)
	check(b.carded == null and b.aimed.is_empty(),"Looked away (up at the sky), it lets go")
	_ticks(2.0)
	check(not b.splash.visible,"And the card has faded")
	_aim_at(Vector3(c.x,bell.isle_top()-c.z*0.25,c.y))
	_ticks(0.8)
	check(b.splash.visible,"Back on the isle, the card again")
	study.script_binoculars = false
	_ticks(2.2)
	check(b.carded == null and not b.splash.visible,"Lowered, the card fades")

func _glints() -> void:
	var b: Node = study.binoculars
	var tokens := root.get_tree().get_nodes_in_group(Binoculars.GROUP).filter(func(n: Node) -> bool: return Binoculars.unfound(n))
	check(tokens.size() >= 7,"The isles' unfound tokens are listed to glint (%d)" % tokens.size())
	study.script_binoculars = true
	_ticks(0.3)
	b.yaw = float(study.motor.facing)
	b.pitch = 0.35
	var far := Node3D.new()
	far.name = "FarFind"
	study.add_child(far)
	far.global_position = b.eye()+b.look_way()*80.0
	# A real objective's id (a bell spires token's), so marking it is no stray.
	var id := str(tokens[0].get_meta(Binoculars.OBJECTIVE))
	Binoculars.spottable(far,id)
	var near := Node3D.new()
	near.name = "NearFind"
	study.add_child(near)
	near.global_position = b.eye()+b.look_way()*10.0+Vector3.UP*0.5
	Binoculars.spottable(near)
	_ticks(0.1)
	var shown: Array = b.glints.map(func(g: Dictionary) -> Node: return g.node)
	check(shown.has(far),"Up, a find 80 m off in plain sight glints (%d glints)" % shown.size())
	check(not shown.has(near),"A find 10 m off doesn't")
	var at: Vector2 = b.glints[shown.find(far)].at if shown.has(far) else Vector2.INF
	var size: Vector2 = study.camera.get_viewport().get_visible_rect().size
	check(at.distance_to(size*0.5) < size.y*0.05,"Its glint sits where it is, mid-view (%s of %s)" % [at,size])
	b.yaw += PI
	_ticks(0.1)
	check(not b.glints.map(func(g: Dictionary) -> Node: return g.node).has(far),"Turned away, it doesn't glint")
	b.yaw -= PI
	_ticks(0.1)
	Ledger.shared().mark_done(id)
	_ticks(0.1)
	check(not b.glints.map(func(g: Dictionary) -> Node: return g.node).has(far),"Found (its objective done), it glints no more")
	Ledger.shared().records.erase(id)
	_ticks(0.1)
	check(b.glints.map(func(g: Dictionary) -> Node: return g.node).has(far),"Unfound again, it glints")
	study.script_binoculars = false
	_ticks(0.1)
	check(b.glints.is_empty(),"Coming down, no glints")
	_ticks(0.3)
	check(b.glints.is_empty() and not b._overlay.visible,"Down, none and no overlay to draw them on")
	far.queue_free()
	near.queue_free()

func _look() -> void:
	var b: Node = study.binoculars
	b.zoom = 2.0
	b.yaw = 0.0
	b.turn(Vector2(0.1,0.0))
	var wide: float = b.yaw
	b.zoom = 8.0
	b.yaw = 0.0
	b.turn(Vector2(0.1,0.0))
	check(is_equal_approx(wide,4.0*float(b.yaw)),"Look is slowed by the zoom (2x %.4f, 8x %.4f rad)" % [wide,b.yaw])
	b.zoom_by(5)
	check(is_equal_approx(float(b.zoom),Binoculars.ZOOM.y),"Zoom stops at %.0fx" % Binoculars.ZOOM.y)
	b.zoom_by(-20)
	check(is_equal_approx(float(b.zoom),Binoculars.ZOOM.x),"And at %.0fx" % Binoculars.ZOOM.x)

func _on_foot_only() -> void:
	var b: Node = study.binoculars
	study.place(study.motor.feet+Vector3.UP*6.0,Vector2(0.0,-1.0))
	study.script_binoculars = true
	_ticks(0.2)
	check(not study.motor.grounded and not b.busy(),"In the air they don't come up")
	_ticks(2.0)
	check(study.motor.grounded and b.busy(),"Landed with the button held, they do (move '%s')" % study.motor.move)
	study.script_binoculars = false
	_ticks(0.4)
	study.board()
	check(study.flying and not study.binoculars_allowed(),"In the plane they can't come up")
