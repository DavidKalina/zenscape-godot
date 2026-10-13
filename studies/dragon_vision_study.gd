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
## dragon_cyclone.gd, docs/design/dragon-cyclone/round1.md) to compare;
## --attack=grip (docs/design/dragon-grip/round2-greybox.md): spotted on or
## over an isle, he breaks off his loop, slams onto its rim (the slam
## staggers you near it), tips it, pants, draws breath (the tell) and blows
## his gale across it (a hard hit stun), hauls on the rim one last time (the
## tell) and lets go, and the isle snaps back and throws you (a hard throw
## stun); then he rejoins his loop. Off the isles, the grip falls back to the
## blast. K swaps blast, grip, cyclone and none live.
##
## The isles (TOP is the kit's datum, 30 m), each its own node (GreyIsle:
## its body, turf and cover under it, so a grip tips it all) with a record
## the dragon samples (`_isle_record`, scripts/dragon_isle_shape.gd). Each
## runs at least ROOM (35 m at 1.5) from its middle to a rim along one way
## at least, so all three pass his room rule (scripts/sky_dragon.gd
## `_has_room`):
##   home  the start, 84 m square: a long wall (RuinKit WALL_HEIGHT: hide
##         behind it, or pump-jump onto it), two tall pillars, an open east
##         half where the plane stands parked.
##   roof  east, higher, 80 m long: a roof on posts (the plane flies under
##         it), and a block with a ledge jutting from it to stand under (its
##         underside at RuinKit GRAB_TOP, its top at CHAIN_TOP: the pump
##         catches it).
##   flat  south, lower, 80 m long: open, nothing to hide behind.
## Walkways join home to each (they stay put while an isle tips). Sizes
## come from scripts/world_scale.gd and the walker's (AGENTS.md "Sizes").
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
## once (a look check); --grip-now starts him on his way in to grip home
## at once, seen or not; the dragon's own --dragon-* flags hold
## (--dragon-size=, --dragon-log, --dragon-watch=...).
##   ./run-dragon-vision.command [--attack=grip] [--grip-now] [--vision-low] [--fly]
##   godot --path . res://studies/dragon_vision_study.tscn -- --no-title
const SkyDragon = preload("res://scripts/sky_dragon.gd")
const DragonWake = preload("res://scripts/dragon_wake.gd")
const DragonSight = preload("res://scripts/dragon_sight.gd")
const DragonAirBlast = preload("res://scripts/dragon_air_blast.gd")
const SightOverlay = preload("res://scripts/dragon_sight_overlay.gd")
const DragonIsleShape = preload("res://scripts/dragon_isle_shape.gd")
const PhysicsGroundSize = preload("res://scripts/pilot_physics_ground.gd")

## His loop's height over the turf (m): his wake circuit's pass over the
## aqueduct isle, and --vision-low's.
const HIGH_OVER := DragonWake.HOME_OVER
const LOW_OVER := 28.0
## His loop (x, z; world), laid so each leg comes at an isle head on: in
## over home from the west, over the roof isle, out east, round south and
## back over the flat isle and home, out west.
const LOOP := [Vector2(-190.0,60.0),Vector2(-70.0,20.0),Vector2(110.0,-5.0),Vector2(220.0,-40.0),
	Vector2(200.0,-170.0),Vector2(60.0,-110.0),Vector2(-80.0,-60.0),Vector2(-230.0,-90.0)]
## The isles: name, middle (x, z), size (x, z), top over TOP, thickness.
## Round 2 of the grip: each runs at least the dragon's ROOM (35 m at 1.5)
## out from its middle along one way (home 42 m every way, roof and flat
## 40 m along their length), so he can grip it.
const ISLES := [
	["home",Vector2(0.0,0.0),Vector2(84.0,84.0),0.0,10.0],
	["roof",Vector2(110.0,-5.0),Vector2(80.0,40.0),4.0,9.0],
	["flat",Vector2(20.0,-100.0),Vector2(80.0,36.0),-4.0,8.0],
]
## The grip here: how long he holds on (s: one blow, then the last haul),
## and how far over an isle's top the pilot still counts as over it (m).
const GRIP_HOLD := 12.0
const OVER_ISLE := 60.0
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
## His attack: "blast", "grip", "cyclone" or "none" (K cycles them).
const ATTACKS := ["blast","grip","cyclone","none"]
var _attack := "blast"
## --grip-now: off to grip home GRIP_NOW_AFTER s in (the isles sampled).
const GRIP_NOW_AFTER := 0.6
var _grip_now := false
var _grip_now_t := 0.0
## The isles' nodes and the dragon's records of them, by name.
var _isle_nodes := {}
var _isle_records := {}
var _up_t := 0.0
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
			else: push_warning("dragon vision greybox: --attack=%s unknown (blast, grip, cyclone, none)" % kind)
		elif arg == "--grip-now": _grip_now = true
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
		var land := GreyIsle.new()
		land.name = "Isle_%s" % isle[0]
		land.top = top
		art.add_child(land)
		var body := _grey(Vector3(size.x,float(isle[4]),size.y),Vector3(mid.x,top-float(isle[4])*0.5,mid.y),0.0,"floor",land)
		body.name = "Body"
		var half := size*0.5
		var outline := PackedVector2Array([mid-half,Vector2(mid.x+half.x,mid.y-half.y),mid+half,Vector2(mid.x-half.x,mid.y+half.y)])
		add_turf(land,outline,false)
		land._outlines = [outline]
		land._turf = [body]
		_isle_nodes[str(isle[0])] = land
	var home: Node3D = _isle_nodes.home
	var roof: Node3D = _isle_nodes.roof
	# Home: the long wall across its west half, two pillars north-east.
	var wall_len := RuinKit.WALL_LENGTH*WALL_RUNS
	_grey(Vector3(wall_len,RuinKit.WALL_HEIGHT,RuinKit.WALL_THICK),Vector3(-8.0,TOP+RuinKit.WALL_HEIGHT*0.5,-6.0),0.0,"wall",home)
	for p: Vector2 in [Vector2(14.0,-16.0),Vector2(22.0,-4.0)]:
		_pillar(p,PILLAR_R*tall,TOP,TOP+PILLAR_TALL*tall,home)
	# Roof isle: a roof on four posts, its span and clearance flown openings.
	var roof_top: float = TOP+float(ISLES[1][3])
	var roof_west: float = (ISLES[1][1] as Vector2).x-(ISLES[1][2] as Vector2).x*0.5
	var span := WorldScale.opening(TOY_ROOF)
	var clear := WorldScale.opening(TOY_ROOF_HIGH)
	var roof_mid := Vector2(roof_west+29.0,-12.0)
	var roof_long := span*1.6
	var post := 0.35*tall
	for sx: float in [-1.0,1.0]:
		for sz: float in [-1.0,1.0]:
			_pillar(roof_mid+Vector2(sx*(span*0.5+post),sz*(roof_long*0.5-post)),post,roof_top,roof_top+clear,roof)
	_grey(Vector3(span+4.0*post+1.0,0.8,roof_long+1.0),Vector3(roof_mid.x,roof_top+clear+0.4,roof_mid.y),0.0,"wall",roof)
	# The block and its ledge, facing south (+z), its underside to stand
	# under, its top for the pump to catch.
	var block_mid := Vector2(roof_west+49.0,-16.0)
	_grey(BLOCK,Vector3(block_mid.x,roof_top+BLOCK.y*0.5,block_mid.y),0.0,"dark",roof)
	var under := RuinKit.GRAB_TOP
	var over := RuinKit.CHAIN_TOP
	_grey(Vector3(LEDGE_WIDE,over-under,LEDGE_OUT),Vector3(block_mid.x,roof_top+(under+over)*0.5,block_mid.y+BLOCK.z*0.5+LEDGE_OUT*0.5),0.0,"lip",roof)
	# The walkways: home to the roof isle (a gentle rise), home to the flat.
	var home_half: Vector2 = (ISLES[0][2] as Vector2)*0.5
	var flat_north: float = (ISLES[2][1] as Vector2).y+(ISLES[2][2] as Vector2).y*0.5
	_walk(Vector3(home_half.x,TOP,-4.0),Vector3(roof_west+1.0,roof_top,-4.0))
	_walk(Vector3(16.0,TOP,-home_half.y),Vector3(16.0,TOP+float(ISLES[2][3]),flat_north))
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

func _pillar(at: Vector2, radius: float, bottom: float, top: float, parent: Node3D = null) -> void:
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
	(parent if parent != null else art).add_child(solid)

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
	# The grip (round 2): every isle a target (none is a starter isle here),
	# its record sampled once it stands (`_isle_record`); the pilot it can
	# stagger, blow and throw; held GRIP_HOLD s.
	dragon.spare_home = false
	for isle: Array in ISLES:
		var size: Vector2 = isle[2]
		dragon.targets.append({"name":str(isle[0]),"home":Vector3((isle[1] as Vector2).x,TOP+float(isle[3]),(isle[1] as Vector2).y),"radius":size.length()*0.5})
	dragon.find_isle = _isle_record
	dragon.grip_pick = _pilot_isle
	dragon.grip_hold = GRIP_HOLD
	dragon.walker = motor
	dragon.slide = ground.slide_callable()
	add_child(dragon)
	var middle := Vector3(40.0,TOP,-35.0)
	dragon.setup(camera,preload("res://scripts/launch_args.gd").user_args(),KitWeather.SEA_TOP,middle,TOP,[[middle,120.0]])
	# No treasure on his tongue here.
	dragon.taken = true
	dragon.sight_target = _sight_target
	dragon.sight.state_changed.connect(_sight_changed)
	dragon.grip_beat.connect(_grip_beat)
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

## An isle as the dragon's grip reads it (scripts/dragon_isle_shape.gd
## `build`, made for a motif isle): its outline, its turf body and its top.
## Its node stands at the world's origin, its body and cover under it at
## their world places, so the gale (scripts/dragon_gale.gd) tips it all
## about its middle, collision and all.
class GreyIsle extends Node3D:
	var _outlines: Array = []
	var _turf: Array = []
	var top := 0.0
	func isle_top() -> float:
		return top

## The dragon's record of isle `id` ({node, shape, home, radius, exclude,
## frame, pivot}, as the aqueduct isle's `_dragon_isle`), sampled once at
## rest, a moment in (the physics space has its bodies); {} till then.
func _isle_record(id: String) -> Dictionary:
	if _isle_records.has(id): return _isle_records[id]
	var isle: Node3D = _isle_nodes.get(id)
	if isle == null or _up_t < 0.3 or not isle.is_inside_tree(): return {}
	var shape: RefCounted = DragonIsleShape.new()
	shape.build(isle,get_world_3d().direct_space_state)
	if not shape.ok: return {}
	var home: Vector3 = shape.home
	var rec := {"node":isle,"shape":shape,"home":home,"radius":float(shape.radius),"exclude":shape.exclude,
		"frame":isle.global_transform.affine_inverse()*Transform3D(Basis.IDENTITY,home),"pivot":home}
	_isle_records[id] = rec
	print("dragon vision greybox: the dragon knows %s: %.0f m to its corners about (%.0f, %.0f, %.0f)" % [id,float(shape.radius),home.x,home.y,home.z])
	return rec

## The isle the pilot is on or over (its index in ISLES, the dragon's
## `targets`), its outline at rest: the walker's feet, or the plane flying,
## from a little under its top to OVER_ISLE m over it; -1 for none.
func _pilot_isle() -> int:
	var at: Vector3 = plane.position if flying and plane != null else motor.feet
	for i in range(ISLES.size()):
		var mid: Vector2 = ISLES[i][1]
		var half: Vector2 = (ISLES[i][2] as Vector2)*0.5
		var top: float = TOP+float(ISLES[i][3])
		if absf(at.x-mid.x) <= half.x and absf(at.z-mid.y) <= half.y and at.y > top-3.0 and at.y < top+OVER_ISLE: return i
	return -1

## The grip's beats as toasts.
func _grip_beat(what: String) -> void:
	var said: String = {"grab":"He grabs the isle!","staggered":"Staggered!","inhale":"He draws breath: take cover!",
		"blown":"Blown off your feet!","pull":"He hauls on the rim: hold on!","thrown":"Thrown!"}.get(what,"")
	if said != "": _show_toast(said)
	print("dragon vision greybox: grip %s, %s tipped %.1f°, pilot %s at (%.1f, %.1f, %.1f) %s%s" % [what,
		str(dragon.grip.target.name) if not dragon.grip.is_empty() else "-",rad_to_deg(dragon.gale.tip()),motor.move if motor.move != "" else "standing",
		motor.feet.x,motor.feet.y,motor.feet.z,"stunned "+motor.stunned if motor.stunned != "" else "on his feet",", down" if motor.downed() else ""])

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
	_up_t += delta
	if _grip_now:
		# --grip-now: on his way in to grip home, once the isles are sampled.
		_grip_now_t += delta
		if _grip_now_t >= GRIP_NOW_AFTER and not _isle_record("home").is_empty():
			_grip_now = false
			dragon.grip_isle(0,GRIP_HOLD,true)
			print("dragon vision greybox: --grip-now: he comes in to grip home")
	if _atmosphere != null:
		dragon.air = _atmosphere.breeze()
		dragon.air_angle = _atmosphere._air_angle
	dragon.on_foot = not flying
	_look_shot()
	dragon.advance(delta)
	# His cyclone and air blast on the walker (or sailing pilot): a knock,
	# as the gale's, so a stun and the ragdoll (PilotMotor `knock`), the
	# dragon its source (his own restun gap).
	if not flying:
		for hit_with: Node3D in [dragon.cyclone,dragon.air_blast]:
			if hit_with == null: continue
			var v: Vector3 = hit_with.pilot_knock(motor.feet,motor)
			if v != Vector3.ZERO:
				motor.knock(v,dragon,DragonAirBlast.STUN_DOWN if hit_with == dragon.air_blast else 0.0)
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

## K: his attack cycled blast, grip, cyclone, none.
func _unhandled_input(event: InputEvent) -> void:
	if dragon != null and event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_K:
		swap_attack()
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)

func swap_attack() -> void:
	_attack = ATTACKS[(ATTACKS.find(_attack)+1)%ATTACKS.size()]
	dragon.set_attack(_attack)
	var said: String = {"blast":"His attack: the air blast","grip":"His attack: the grip (on an isle; the blast off them)","cyclone":"His attack: the cyclone","none":"His attack: none"}[_attack]
	_show_toast(said)
	print("dragon vision greybox: "+said)

func _foot_text() -> String:
	return super._foot_text()+"\nJ: the dragon's sight overlay  ·  K: his attack (blast, grip, cyclone, none)  ·  V: watch the dragon  ·  knocked: X twirl, then Space sail"
