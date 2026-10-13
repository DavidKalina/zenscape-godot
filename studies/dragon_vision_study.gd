extends "res://studies/kit_isle.gd"
## The dragon's vision greybox (docs/design/dragon-vision/round1.md): three
## flat grey isles over the cloud sea, with cover to hide under or behind,
## and the sky dragon (scripts/sky_dragon.gd) flying a fixed loop over them
## at about his wake circuit's height (scripts/dragon_wake.gd HOME_OVER over
## the turf), looking for you (scripts/dragon_sight.gd). His downwash is on
## (the plane and the sail feel it, as on the aqueduct isle). Spotted, he
## cuts his roar short and answers with his air blast (scripts/
## dragon_air_blast.gd, docs/design/dragon-air-blast/round1.md): a snap
## wind-up, a swift ball of air fired where you will be, popped by stone
## cover, its burst throwing the pilot off the isle and the plane out of the
## sky. --attack=cyclone brings back his slower cyclone (scripts/
## dragon_cyclone.gd, docs/design/dragon-cyclone/round1.md) to compare; K
## swaps blast, cyclone and none live.
##
## The isles (TOP is the kit's datum, 30 m):
##   home  the start: a long wall (RuinKit WALL_HEIGHT: hide behind it, or
##         pump-jump onto it), two tall pillars, an open east half where the
##         plane stands parked.
##   roof  east, higher: a roof on posts (the plane flies under it), and a
##         block with a ledge jutting from it to stand under (its underside at
##         RuinKit GRAB_TOP, its top at CHAIN_TOP: the pump catches it).
##   flat  south, lower: open, nothing to hide behind.
## Walkways join home to each. Sizes come from scripts/world_scale.gd and
## the walker's (AGENTS.md "Sizes").
##
## The kit isle's moves and plane hold (studies/kit_isle.gd): Space by the
## parked plane boards it, F gets out stopped; off an edge Space opens the
## sail. J shows and hides the sight overlay (scripts/
## dragon_sight_overlay.gd: on by default here); V cycles the dragon camera.
## Flags: --vision-low flies his loop lower (LOW_OVER over the turf);
## --vision-log prints the sight once a second; --no-sight-overlay starts
## with the overlay hidden; --attack=blast|cyclone|none picks his attack
## (blast the default; --no-cyclone is --attack=none); --cyclone-fast and
## --blast-fast shorten each's cooldown between shots (FAST_COOLDOWN);
## --cyclone-shot=<x>,<z> and --blast-shot=<x>,<z> fire one at that spot at
## once (a look check); the dragon's own --dragon-* flags hold
## (--dragon-size=, --dragon-log, --dragon-watch=...).
##   ./run-dragon-vision.command [--attack=cyclone] [--vision-low] [--fly]
##   godot --path . res://studies/dragon_vision_study.tscn -- --no-title
const SkyDragon = preload("res://scripts/sky_dragon.gd")
const DragonWake = preload("res://scripts/dragon_wake.gd")
const DragonSight = preload("res://scripts/dragon_sight.gd")
const SightOverlay = preload("res://scripts/dragon_sight_overlay.gd")
const PhysicsGroundSize = preload("res://scripts/pilot_physics_ground.gd")

## His loop's height over the turf (m): his wake circuit's pass over the
## aqueduct isle, and --vision-low's.
const HIGH_OVER := DragonWake.HOME_OVER
const LOW_OVER := 28.0
## His loop (x, z; world), laid so each leg comes at an isle head on: in
## over home from the west, over the roof isle, out east, round south and
## back over the flat isle and home, out west.
const LOOP := [Vector2(-190.0,60.0),Vector2(-70.0,20.0),Vector2(95.0,-5.0),Vector2(220.0,-40.0),
	Vector2(200.0,-170.0),Vector2(60.0,-110.0),Vector2(-80.0,-60.0),Vector2(-230.0,-90.0)]
## The isles: name, middle (x, z), size (x, z), top over TOP, thickness.
const ISLES := [
	["home",Vector2(0.0,0.0),Vector2(64.0,64.0),0.0,10.0],
	["roof",Vector2(95.0,-5.0),Vector2(48.0,40.0),4.0,9.0],
	["flat",Vector2(20.0,-100.0),Vector2(50.0,36.0),-4.0,8.0],
]
## Toy-era widths of the flown openings (WorldScale.opening): the roof's span
## between its posts and its height clear over the floor.
const TOY_ROOF := 4.0
const TOY_ROOF_HIGH := 2.0
## The long wall's length in RuinKit wall lengths; the pillars' radius and
## height in the walker's heights; the ledge's jut and the block it juts from.
const WALL_RUNS := 5
const PILLAR_R := 0.75
const PILLAR_TALL := 7.0
const LEDGE_OUT := 4.0
const LEDGE_WIDE := 10.0
const BLOCK := Vector3(14.0,7.0,6.0)
## The walkways' width (m).
const WALK_WIDE := 4.0

var dragon: Node3D
var overlay: Node3D
var _low := false
var _log := false
var _log_t := 0.0
var _overlay_on := true
## His attack: "blast", "cyclone" or "none" (K cycles them).
const ATTACKS := ["blast","cyclone","none"]
var _attack := "blast"
var _cyclone_fast := false
var _blast_fast := false
## --blast-shot=<x>,<z>: as --cyclone-shot, a ball fired at that spot.
var _blast_shot := Vector2.INF
## --cyclone-shot=<x>,<z>: a look check: one cyclone fired at once at that
## spot on the turf from 60 m up to the west, sight or not (with --at, the
## capture's frames see it land and spin).
var _cyclone_shot := Vector2.INF

func _ready() -> void:
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg == "--vision-low": _low = true
		elif arg == "--vision-log": _log = true
		elif arg == "--no-sight-overlay": _overlay_on = false
		elif arg == "--no-cyclone": _attack = "none"
		elif arg.begins_with("--attack="):
			var kind := arg.get_slice("=",1)
			if kind in ATTACKS: _attack = kind
			else: push_warning("dragon vision greybox: --attack=%s unknown (blast, cyclone, none)" % kind)
		elif arg == "--cyclone-fast": _cyclone_fast = true
		elif arg == "--blast-fast": _blast_fast = true
		elif arg.begins_with("--cyclone-shot="):
			var xz := arg.get_slice("=",1).split(",")
			_cyclone_shot = Vector2(float(xz[0]),float(xz[1]))
		elif arg.begins_with("--blast-shot="):
			var xz := arg.get_slice("=",1).split(",")
			_blast_shot = Vector2(float(xz[0]),float(xz[1]))
	super._ready()

## No pack: one isle-group; the start on home, looking north-east to the
## wall and the roof isle.
func _load_pack() -> void:
	start = Vector3(6.0,TOP,22.0)
	start_face = Vector2(0.3,-1.0).normalized()
	lost = TOP-60.0
	_last_stood = start
	stations = []

func isle_name() -> String:
	return "dragon vision greybox"

func capture_look() -> Vector3:
	return Vector3(30.0,TOP+4.0,-20.0)

## Only the cloud sea's own towers in the sky (no airships, traffic,
## serpent or tokens), and no life or grass on the grey.
func sky_script() -> Script:
	return GreySky

class GreySky extends "res://studies/aqueduct_isle_sky.gd":
	func setup(study: Node3D) -> void:
		scene = study
		for k in on: on[k] = false
		if not flags().has("--no-sky"):
			on.clouds = true
			_build_clouds()

func _grow() -> void:
	pass

# --- The greybox -------------------------------------------------------------------

func _build_art() -> void:
	art = Node3D.new()
	art.name = "Art"
	add_child(art)
	var tall := PhysicsGroundSize.HEAD*WorldScale.wanderer
	for isle: Array in ISLES:
		var mid: Vector2 = isle[1]
		var size: Vector2 = isle[2]
		var top: float = TOP+float(isle[3])
		var land := Node3D.new()
		land.name = "Isle_%s" % isle[0]
		art.add_child(land)
		var body := _grey(Vector3(size.x,float(isle[4]),size.y),Vector3(mid.x,top-float(isle[4])*0.5,mid.y),0.0,"floor",land)
		body.name = "Body"
		var half := size*0.5
		add_turf(land,PackedVector2Array([mid-half,Vector2(mid.x+half.x,mid.y-half.y),mid+half,Vector2(mid.x-half.x,mid.y+half.y)]),false)
	# Home: the long wall across its west half, two pillars north-east.
	var wall_len := RuinKit.WALL_LENGTH*WALL_RUNS
	_grey(Vector3(wall_len,RuinKit.WALL_HEIGHT,RuinKit.WALL_THICK),Vector3(-8.0,TOP+RuinKit.WALL_HEIGHT*0.5,-6.0),0.0,"wall")
	for p: Vector2 in [Vector2(14.0,-16.0),Vector2(22.0,-4.0)]:
		_pillar(p,PILLAR_R*tall,TOP,TOP+PILLAR_TALL*tall)
	# Roof isle: a roof on four posts, its span and clearance flown openings.
	var roof_top: float = TOP+float(ISLES[1][3])
	var span := WorldScale.opening(TOY_ROOF)
	var clear := WorldScale.opening(TOY_ROOF_HIGH)
	var roof_mid := Vector2(84.0,-12.0)
	var roof_long := span*1.6
	var post := 0.35*tall
	for sx: float in [-1.0,1.0]:
		for sz: float in [-1.0,1.0]:
			_pillar(roof_mid+Vector2(sx*(span*0.5+post),sz*(roof_long*0.5-post)),post,roof_top,roof_top+clear)
	_grey(Vector3(span+4.0*post+1.0,0.8,roof_long+1.0),Vector3(roof_mid.x,roof_top+clear+0.4,roof_mid.y),0.0,"wall")
	# The block and its ledge, facing south (+z), its underside to stand
	# under, its top for the pump to catch.
	var block_mid := Vector2(104.0,-16.0)
	_grey(BLOCK,Vector3(block_mid.x,roof_top+BLOCK.y*0.5,block_mid.y),0.0,"dark")
	var under := RuinKit.GRAB_TOP
	var over := RuinKit.CHAIN_TOP
	_grey(Vector3(LEDGE_WIDE,over-under,LEDGE_OUT),Vector3(block_mid.x,roof_top+(under+over)*0.5,block_mid.y+BLOCK.z*0.5+LEDGE_OUT*0.5),0.0,"lip")
	# The walkways: home to the roof isle (a gentle rise), home to the flat.
	_walk(Vector3(32.0,TOP,-4.0),Vector3(71.0,roof_top,-4.0))
	_walk(Vector3(16.0,TOP,-32.0),Vector3(16.0,TOP+float(ISLES[2][3]),-82.0))
	print("dragon vision greybox: wall %.1f x %.1f m, roof %.1f m across, %.1f m clear, ledge underside %.2f m, top %.2f m" % [wall_len,RuinKit.WALL_HEIGHT,span,clear,under,over])

func _grey_material(colour: String) -> Material:
	return _material(colour)

## A grey box `size` round `middle` turned `yaw` (rad), solid (layer 1),
## under `parent` (the art without one).
func _grey(size: Vector3, middle: Vector3, yaw: float, colour: String, parent: Node3D = null) -> StaticBody3D:
	var solid := StaticBody3D.new()
	solid.transform = Transform3D(Basis(Vector3.UP,yaw),middle)
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	solid.add_child(collider)
	var mesh := BoxMesh.new()
	mesh.size = size
	var drawn := MeshInstance3D.new()
	drawn.mesh = mesh
	drawn.material_override = _grey_material(colour)
	solid.add_child(drawn)
	(parent if parent != null else art).add_child(solid)
	return solid

func _pillar(at: Vector2, radius: float, bottom: float, top: float) -> void:
	var solid := StaticBody3D.new()
	solid.position = Vector3(at.x,(bottom+top)*0.5,at.y)
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = top-bottom
	var collider := CollisionShape3D.new()
	collider.shape = shape
	solid.add_child(collider)
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = top-bottom
	var drawn := MeshInstance3D.new()
	drawn.mesh = mesh
	drawn.material_override = _grey_material("wall")
	solid.add_child(drawn)
	art.add_child(solid)

## A walkway WALK_WIDE across from `a` to `b` (their tops), 0.6 m thick.
func _walk(a: Vector3, b: Vector3) -> void:
	var run := b-a
	var flat := Vector2(run.x,run.z).length()
	var yaw := atan2(-run.x,-run.z)
	var pitch := atan2(run.y,flat)
	var basis := Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,pitch)
	var solid := _grey(Vector3(WALK_WIDE,0.6,run.length()+1.0),(a+b)*0.5-basis.y*0.3,0.0,"lane")
	solid.transform.basis = basis

# --- The dragon --------------------------------------------------------------------

func _add_life() -> void:
	dragon = SkyDragon.new()
	dragon.sky_scene = self
	dragon.idle_roars = false
	# Both built, so K can swap them; only `attack` fires.
	dragon.cyclone_on = true
	dragon.blast_on = true
	dragon.attack = _attack
	var over := LOW_OVER if _low else HIGH_OVER
	for p: Vector2 in LOOP: dragon.loop.append(Vector3(p.x,TOP+over,p.y))
	add_child(dragon)
	var middle := Vector3(40.0,TOP,-35.0)
	dragon.setup(camera,preload("res://scripts/launch_args.gd").user_args(),KitWeather.SEA_TOP,middle,TOP,[[middle,120.0]])
	dragon.sight_target = _sight_target
	dragon.sight.state_changed.connect(_sight_changed)
	if dragon.cyclone != null:
		if _cyclone_fast: dragon.cyclone.cooldown = dragon.cyclone.FAST_COOLDOWN
		dragon.cyclone.winding_up.connect(func() -> void: _show_toast("He draws breath: take cover!"))
		dragon.cyclone.broke.connect(func(_at: Vector3) -> void: _show_toast("The cyclone breaks on cover"))
	if dragon.air_blast != null:
		if _blast_fast: dragon.air_blast.cooldown = dragon.air_blast.FAST_COOLDOWN
		dragon.air_blast.broke.connect(func(_at: Vector3) -> void: _show_toast("The blast pops on cover"))
	overlay = SightOverlay.new()
	add_child(overlay)
	overlay.setup(dragon)
	overlay.visible = _overlay_on
	overlay._layer.visible = _overlay_on
	_wash_air()
	print("dragon vision greybox: his loop %.0f m over the turf (%s), attack %s" % [over,"low" if _low else "his circuit's height",_attack])

## The pilot for his sight: the plane's middle and wingtips flying, else
## the walker's feet, chest and head (airborne off the ground).
func _sight_target() -> Dictionary:
	if flying and plane != null:
		return {"points":DragonSight.pilot_points(Vector3.ZERO,true,plane.position,plane.forward()),"airborne":true}
	return {"points":DragonSight.pilot_points(motor.feet,false),"airborne":not motor.grounded}

func _sight_changed(now: String, _was: String) -> void:
	match now:
		"suspicious": _show_toast("The dragon is suspicious")
		"spotted": _show_toast("Spotted!")
		"unaware": _show_toast("He has lost you")

## His downwash on the plane and the sail (as studies/aqueduct_isle.gd),
## and his cyclone's and air blast's air on the plane.
func _wash_air() -> void:
	plane_air = func(p: Vector3) -> Dictionary:
		if plane == null or dragon == null: return {}
		var air: Dictionary = dragon.downwash.plane_air(p,plane.forward())
		if dragon.cyclone != null: air = dragon.downwash.merge(air,dragon.cyclone.plane_air(p,plane.forward()))
		if dragon.air_blast != null: air = dragon.downwash.merge(air,dragon.air_blast.plane_air(p,plane.forward()))
		return air
	var base: Callable = motor.air
	motor.air = func(p: Vector3) -> Dictionary:
		var here: Dictionary = base.call(p) if base.is_valid() else {}
		if dragon == null: return here
		return dragon.downwash.merge(here,dragon.downwash.pilot_air(p,PocketSail.THERMAL))

func _process(delta: float) -> void:
	super._process(delta)
	if dragon == null: return
	if _atmosphere != null:
		dragon.air = _atmosphere.breeze()
		dragon.air_angle = _atmosphere._air_angle
	dragon.on_foot = not flying
	_look_shot()
	dragon.advance(delta)
	# His cyclone and air blast on the walker (or sailing pilot): a knock,
	# as the gale's.
	if not flying:
		for hit_with: Node3D in [dragon.cyclone,dragon.air_blast]:
			if hit_with == null: continue
			var v: Vector3 = hit_with.pilot_knock(motor.feet,motor)
			if v != Vector3.ZERO:
				motor.knock(v)
				if hit_with == dragon.air_blast: _show_toast("Blasted!")
	if _log and delta > 0.0:
		_log_t += delta
		if _log_t >= 1.0:
			_log_t = 0.0
			var s: RefCounted = dragon.sight
			var who: Vector3 = plane.position if flying and plane != null else motor.feet
			print("vision: t %.0f dragon (%.0f, %.0f, %.0f) pilot (%.1f, %.1f, %.1f) %s, %s, awareness %.2f, visibility %.2f, %d/%d seen, in cone %s, %.0f m" % [Time.get_ticks_msec()/1000.0,dragon.pos.x,dragon.pos.y,dragon.pos.z,who.x,who.y,who.z,"flying" if flying else ("grounded" if motor.grounded else "in the air"),s.state,s.awareness,s.visibility,(s.seen as Array).count(true),(s.points as PackedVector3Array).size(),str(s.in_cone),s.distance])

## A fixed-eye capture (--at) still flies the dragon.
func _capture_tick(delta: float) -> void:
	if dragon == null: return
	_look_shot()
	dragon.advance(delta)

func _look_shot() -> void:
	if _blast_shot != Vector2.INF and dragon.air_blast != null:
		var at := Vector3(_blast_shot.x,TOP,_blast_shot.y)
		dragon.air_blast.fire(at+Vector3(-50.0,60.0,20.0),at)
		_blast_shot = Vector2.INF
	if _cyclone_shot == Vector2.INF or dragon.cyclone == null: return
	var aim := Vector3(_cyclone_shot.x,TOP,_cyclone_shot.y)
	dragon.cyclone.fire(aim+Vector3(-50.0,60.0,20.0),aim)
	_cyclone_shot = Vector2.INF

## K: his attack cycled blast, cyclone, none.
func _unhandled_input(event: InputEvent) -> void:
	if dragon != null and event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_K:
		swap_attack()
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)

func swap_attack() -> void:
	_attack = ATTACKS[(ATTACKS.find(_attack)+1)%ATTACKS.size()]
	dragon.set_attack(_attack)
	var said: String = {"blast":"His attack: the air blast","cyclone":"His attack: the cyclone","none":"His attack: none"}[_attack]
	_show_toast(said)
	print("dragon vision greybox: "+said)

func _foot_text() -> String:
	return super._foot_text()+"\nJ: the dragon's sight overlay  ·  K: his attack (blast, cyclone, none)  ·  V: watch the dragon  ·  knocked: X twirl, then Space sail"
