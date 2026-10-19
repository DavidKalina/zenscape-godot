extends Node3D
## Digging in the wreck cluster (docs/design/dig/spec-dig.md, loop `dig`).
## A child of the cluster (studies/wreck_cluster.gd), set up from its
## `_add_life`: the spade lying by the plane, taken by walking over it (or
## pressing Dig beside it), then carried on his back (a bone attachment on
## the figure's chest); `re_deal` lays it back by the plane (N).
##
## Dig is its own action, `walk_dig` (scripts/pad.gd: G, the pad's Y).
##
## The spade's lying spot is a named placement (scripts/layout_overrides.gd)
## `wreck_cluster/spade`, a token the world view (F4) moves.

const SpadeFigure = preload("res://scripts/dig/spade_figure.gd")
const LayoutOverrides = preload("res://scripts/layout_overrides.gd")
const Lines = preload("res://scripts/collectible_lines.gd")
const DigMotion = preload("res://scripts/dig/dig_motion.gd")
const DigFx = preload("res://scripts/dig/dig_fx.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const DigSpots = preload("res://scripts/dig/dig_spots.gd")

const ACTION := &"walk_dig"
const SPADE_NAME := "wreck_cluster/spade"
## Where the spade lies, from the cluster's start (beside the plane, in
## front of him as he starts, so the first look finds it).
const SPADE_FROM_START := Vector3(1.3,0.0,-2.4)
const SPADE_YAW := 0.6
## How far Dig reaches for the spade lying (m, times his size); walking
## over it takes it at the collectibles' reach.
const PRESS_REACH := 1.4
## The spade on his back, in the chest bone's frame (judged in stills).
## Slung across his back, blade down by one hip, the grip up past the other
## shoulder, clear of the hat's brim; the bone's +z is his back.
const BACK_TILT := Vector3(0.0,0.0,40.0)
const BACK_AT := Vector3(0.0,0.0,0.17)

var host: Node3D = null
## "lying" by the plane, or "carried" on his back.
var spade_state := "lying"
var spade_lying: Node3D = null
var spade_holder: Node3D = null
var spade_back: Node3D = null
var _back_mount: BoneAttachment3D = null
## The spade in his mitts while he digs (world).
var spade_hand: Node3D = null
var fx: Node3D = null
## The dig under way (scripts/dig/dig_motion.gd), or null; its time, and
## where it bites (the ground's point and normal).
var motion: RefCounted = null
var dig_t := 0.0
var dig_at := Vector3.ZERO
var dig_normal := Vector3.UP
var _scoop: Node3D = null
## The strange spots and their finds (scripts/dig/dig_spots.gd), and the
## one this dig is opening ({} for plain ground).
var spots: Node3D = null
var dig_spot := {}
## Digs made this deal, by kind ("soil", "stone"), for drivers.
var dug := {"soil":0,"stone":0}
## How far ahead of his feet the blade bites (m, times his size).
const BITE_AHEAD := 0.52

## `opts` (all optional, for a scene other than the cluster): "spade", the
## spade's placement name; "from_start", where it lies from the start;
## "spots", a node standing in for DigSpots (setup(host, fx, size),
## near(at), reveal(spot, at), cut_at(...), re_deal(seed), and optionally
## soil_at(at): ground it makes diggable). The host may also have
## `dig_blocked()`: true, the spade won't dig.
func setup(scene: Node3D, opts := {}) -> void:
	host = scene
	name = "Dig"
	var start: Vector3 = host.get("start")
	var spade_name := str(opts.get("spade",SPADE_NAME))
	var coded := Transform3D(Basis(Vector3.UP,SPADE_YAW),start+(opts.get("from_start",SPADE_FROM_START) as Vector3))
	spade_holder = Node3D.new()
	spade_holder.name = "SpadeSpot"
	add_child(spade_holder)
	spade_holder.global_transform = LayoutOverrides.xform(spade_name,coded)
	LayoutOverrides.track(spade_name,spade_holder,"token",coded)
	spade_lying = SpadeFigure.new()
	spade_holder.add_child(spade_lying)
	spade_hand = SpadeFigure.new()
	spade_hand.name = "SpadeInHand"
	spade_hand.top_level = true
	spade_hand.visible = false
	add_child(spade_hand)
	fx = DigFx.new()
	fx.size = _scale()
	add_child(fx)
	spots = opts.get("spots") if opts.get("spots") != null else DigSpots.new()
	add_child(spots)
	spots.setup(host,fx,_scale())
	lay_spade()

func _scale() -> float:
	var s: Variant = host.get("wanderer_scale")
	return float(s) if s != null else 1.0

## The spade back on its spot, stuck in the turf under it, and off his
## back.
func lay_spade() -> void:
	spade_state = "lying"
	if spade_back != null and is_instance_valid(spade_back): spade_back.visible = false
	spade_lying.visible = true
	var s := _scale()
	var at := spade_holder.global_position
	var ground := _ground_at(at)
	var y := ground.y if ground != Vector3.INF else at.y
	# Stuck upright in the turf by its blade, leaning a little, so it shows
	# over the grass.
	var lean := Basis(Vector3.FORWARD,deg_to_rad(12.0))*Basis(Vector3.UP,deg_to_rad(20.0))
	spade_lying.global_transform = Transform3D(spade_holder.global_basis.orthonormalized()*lean.scaled(Vector3.ONE*s),
		Vector3(at.x,y-SpadeFigure.BITE*s,at.z))

func _ground_at(p: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(p+Vector3.UP*3.0,p+Vector3.DOWN*6.0,1|(1 << 11))
	var hit := space.intersect_ray(ray)
	return Vector3.INF if hit.is_empty() else hit.position

## The spade's middle, lying (world).
func spade_point() -> Vector3:
	return spade_lying.global_transform*Vector3(0.0,SpadeFigure.LENGTH*0.4,0.0)

func has_spade() -> bool:
	return spade_state == "carried"

## The cluster's re-deal (N): the spade back by the plane.
func re_deal() -> void:
	end_dig()
	fx.clear_scoops()
	dug = {"soil":0,"stone":0}
	var seed_value: Variant = host.get("deal_seed")
	spots.re_deal(int(seed_value) if seed_value != null else 0)
	lay_spade()

func take_spade() -> void:
	if spade_state == "carried": return
	spade_state = "carried"
	spade_lying.visible = false
	_mount_back()
	var moments: Variant = host.get("_moments")
	if moments != null: moments.pop("The spade: G (Y) digs where the soil looks turned",3.0)
	var arc: Variant = host.get("plane_arc")
	if arc != null and arc.get("sounds") != null: arc.sounds.found(1)

## The spade on his back: a bone attachment on the figure's chest.
func _mount_back() -> void:
	if spade_back == null or not is_instance_valid(spade_back):
		var body: Node = host.get("body")
		var skeleton: Skeleton3D = body.get("_skeleton") if body != null else null
		if skeleton == null or skeleton.find_bone("chest") < 0: return
		_back_mount = BoneAttachment3D.new()
		_back_mount.name = "SpadeMount"
		_back_mount.bone_name = "chest"
		skeleton.add_child(_back_mount)
		spade_back = SpadeFigure.new()
		spade_back.transform = Transform3D(Basis.from_euler(BACK_TILT*PI/180.0),BACK_AT)*Transform3D(Basis.IDENTITY,Vector3(0.0,-SpadeFigure.LENGTH*0.5,0.0))
		_back_mount.add_child(spade_back)
	spade_back.visible = true

func _process(delta: float) -> void:
	if motion != null:
		_dig_step(delta)
		return
	if host == null or not bool(host.get("walk_ready")) or bool(host.get("flying")): return
	if spade_state == "lying":
		var motor: Variant = host.get("motor")
		var s := _scale()
		var mid: Vector3 = motor.feet+Vector3.UP*Lines.FOOT_Y*s
		if mid.distance_to(spade_point()) < Lines.WALKER_REACH*s+0.35*s: take_spade()

func _unhandled_input(event: InputEvent) -> void:
	if host == null or not event.is_action_pressed(ACTION) or event.is_echo(): return
	if bool(host.get("flying")) or not bool(host.get("walk_ready")): return
	if spade_state == "lying":
		var motor: Variant = host.get("motor")
		if (motor.feet as Vector3).distance_to(spade_point()) < PRESS_REACH*_scale():
			take_spade()
			get_viewport().set_input_as_handled()
	elif motion == null and can_dig():
		start_dig()
		get_viewport().set_input_as_handled()

# --- Digging ------------------------------------------------------------------------

## On his feet, still or walking, not climbing, hanging, swinging, sliding,
## wading or in the air, with the spade.
func can_dig() -> bool:
	if not has_spade() or host == null or bool(host.get("flying")) or not bool(host.get("walk_ready")): return false
	if host.has_method("dig_blocked") and bool(host.dig_blocked()): return false
	var motor: Variant = host.get("motor")
	if not motor.grounded or motor.hold != "" or motor.swimming or float(motor.wade) > 0.02: return false
	var carry: Variant = host.get("carry")
	if carry != null and not (carry.held as Dictionary).is_empty(): return false
	return motor.move == "" or motor.move == "crouch"

## What the blade meets ahead of him: {at, normal, kind} with kind "soil"
## (turf, worn earth), "stone" (ruin, rock, planks) or "" (nothing there:
## an edge).
func ground_ahead() -> Dictionary:
	var motor: Variant = host.get("motor")
	var s := _scale()
	var way: Vector2 = PilotMotor.forward(motor.facing)
	var feet: Vector3 = motor.feet
	var p := feet+Vector3(way.x,0.0,way.y)*BITE_AHEAD*s
	var space := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(p+Vector3.UP*0.6*s,p+Vector3.DOWN*0.8*s,1|(1 << 11))
	var hit := space.intersect_ray(ray)
	if hit.is_empty(): return {"kind":""}
	var at: Vector3 = hit.position
	var kind := "stone"
	var audio: Variant = host.get("audio")
	if audio != null and (audio as Object).has_method("_read_surface"):
		var surface: String = audio._read_surface(at)
		if surface == "grass" or surface == "earth": kind = "soil"
		elif surface == "water": kind = ""
		elif _turf_under_piece(hit,at): kind = "soil"
	elif hit.collider is CollisionObject3D and ((hit.collider as CollisionObject3D).collision_layer & (1 << 11)) != 0:
		kind = "soil"
	if kind != "" and spots != null and spots.has_method("soil_at") and bool(spots.soil_at(at)): kind = "soil"
	return {"at":at,"normal":hit.normal,"kind":kind}

## The turf itself where the isle's sound reads stone only because a piece
## stands over it (an arch's span): the hit is the land's turf collision,
## at the turf's height there, facing up.
func _turf_under_piece(hit: Dictionary, at: Vector3) -> bool:
	var body: Variant = hit.get("collider")
	if not (body is CollisionObject3D) or ((body as CollisionObject3D).collision_layer & (1 << 11)) == 0: return false
	if (hit.normal as Vector3).y < 0.75: return false
	var life: Variant = host.get("life")
	if life == null or not (life as Object).has_method("ground_at"): return false
	var turf: Variant = life.ground_at(Vector2(at.x,at.z))
	return turf != null and absf(float(turf)-at.y) < 0.3

func start_dig() -> void:
	var g := ground_ahead()
	if String(g.kind) == "": return
	var motor: Variant = host.get("motor")
	var s := _scale()
	var way: Vector2 = PilotMotor.forward(motor.facing)
	var fwd := Vector3(way.x,0.0,way.y).normalized()
	var right := fwd.cross(Vector3.UP).normalized()
	var feet: Vector3 = motor.feet
	motion = DigMotion.new(String(g.kind),Transform3D(Basis(right,Vector3.UP,-fwd),feet),s)
	dig_t = 0.0
	dig_at = g.at
	dig_normal = g.normal
	_scoop = null
	# A strange spot under the bite: the dig opens it, centred on it.
	dig_spot = spots.near(dig_at) if String(g.kind) == "soil" else {}
	if not dig_spot.is_empty():
		var p: Vector3 = (dig_spot.tell_node as Node3D).global_position
		dig_at = Vector3(p.x,p.y,p.z)
	# The isle's sound comes up after the cluster's life.
	if fx.audio == null: fx.hook_audio(host.get("audio"))
	motor.velocity = Vector3(0.0,motor.velocity.y,0.0)
	host.set("scripted",true)
	host.set("script_want",Vector2.ZERO)
	host.set("script_jump",false)
	host.set("script_crouch",false)
	host.set("script_twirl",false)

## One frame of the dig: his own tick (held still, no stick), then the
## dig's pose over the figure's, its moments, and the end.
func _dig_step(delta: float) -> void:
	if host == null or bool(host.get("flying")) or not bool(host.get("walk_ready")):
		end_dig()
		return
	if delta > 0.0: host.tick(delta)
	if motion == null: return
	var was := dig_t
	dig_t += delta
	var back := _back_xform()
	var p: Dictionary = motion.pose(dig_t,back)
	spade_hand.global_transform = p.spade
	spade_hand.visible = true
	if spade_back != null: spade_back.visible = false
	var body: Node3D = host.get("body")
	if body != null: DigMotion.apply(body,p,motion.frame.basis)
	for e: String in motion.crossed(was,dig_t): _moment(e)
	if dig_t >= motion.length: end_dig()

## The spade's xform on his back now (world), where it is drawn from and
## put back to.
func _back_xform() -> Transform3D:
	if spade_back == null: _mount_back()
	if spade_back == null: return spade_hand.global_transform
	return spade_back.global_transform

## How far the grass is cut round a dig (m at size 1): a strange spot's
## hole with its berm and spoil heap, a plain scoop.
const CUT_HOLE := 1.8
const CUT_SCOOP := 0.9
## ... and how near the dig's heart a blade may still reach (the hole's
## berm and heap, a scoop's rim).
const CLEAR_HOLE := 0.65
const CLEAR_SCOOP := 0.35

func _moment(e: String) -> void:
	var tip: Vector3 = spade_hand.global_transform*SpadeFigure.tip()
	var body: Node3D = host.get("body")
	var stretch: Variant = body.get("_stretch") if body != null else null
	match e:
		"bite":
			var bite_at := Vector3(tip.x,dig_at.y,tip.z)
			fx.bite(bite_at,-motion.frame.basis.z)
			if stretch != null: stretch.v -= 1.4
			if _scoop == null:
				# A strange spot opens a hole kept for the deal; plain soil a
				# scoop (none over a hole already dug: the hole takes it).
				# The grass round it cut too, or the carpet swallows it: a
				# hole and its heap to stubble-free earth, a scoop to stubble.
				var heap: Vector3 = motion.frame.basis.x*0.18*_scale()
				if not dig_spot.is_empty():
					_scoop = fx.hole(Vector3(dig_at.x,dig_at.y,dig_at.z),dig_normal,motion.frame.basis.x,0.4)
					spots.cut_at(dig_at+heap,CUT_HOLE*_scale(),0.0,CLEAR_HOLE*_scale())
				else:
					_scoop = fx.hole_near(dig_at,0.45)
					if _scoop == null:
						_scoop = fx.scoop(Vector3(dig_at.x,dig_at.y,dig_at.z),dig_normal,motion.frame.basis.x,0.4)
						spots.cut_at(dig_at+heap,CUT_SCOOP*_scale(),0.12,CLEAR_SCOOP*_scale())
				dug.soil += 1
			else:
				fx.deepen(_scoop,1.0)
				# The second bite opens a strange spot: its find comes up.
				if not dig_spot.is_empty():
					spots.reveal(dig_spot,dig_at)
					dig_spot = {}
		"throw":
			var blade: Vector3 = spade_hand.global_transform*Vector3(0.0,SpadeFigure.BLADE_H*0.5,0.0)
			var way: Vector3 = (motion.frame.basis.x*1.0-motion.frame.basis.z*0.35).normalized()
			fx.fling(blade,way,dig_at.y)
			if stretch != null: stretch.v += 0.8
		"clank":
			fx.clank(Vector3(tip.x,dig_at.y,tip.z))
			dug.stone += 1
			if stretch != null: stretch.v += 1.6
			var moments: Variant = host.get("_moments")
			if moments != null and dug.stone == 1: moments.pop("Stone: the spade only bites soil",2.0)
			if body != null and body.has_method("express"): body.express("surprise",0.6)

## The dig over (or cut short): the spade back on his back, the stick his.
func end_dig() -> void:
	if motion == null: return
	motion = null
	dig_spot = {}
	if host != null: host.set("scripted",false)
	if spade_hand != null: spade_hand.visible = false
	if spade_back != null and spade_state == "carried": spade_back.visible = true
