extends Node3D
## Songbirds on a kit isle's ruins (docs/scenic/kit-isle-shared.md; the
## aqueduct isle's, docs/scenic/aqueduct-isle-life.md): the game's songbirds
## (scripts/songbirds.gd, its carved bodies scripts/songbird_body.gd and its
## numbers) with their perches moved from the oaks' limbs to the stone.
## An isle names its perch groups' candidate points (`spots`: name -> (x, z)
## points over its parapets, lintels, stumps, floating stones) and its
## flocks (`flock_specs`); each perch is found in the physics space
## (`perches_from`): a ray down onto something standing over the turf, flat
## on top, with room over it.
##
## Small flocks of one species keep a home: one perch group. Most sit in
## plain sight, look about in quick snaps and flick their tails, hop along
## a parapet to the next free stone, flit to another perch of the group in
## the bounding flap-and-glide of small birds, or drop to the turf beside
## the ruin to forage in short hops and pecks. The pilot coming close
## (FIGURE_NEAR, more at a run), the plane passing (PLANE_NEAR) or a strong
## gust reaching them (a front sent with B) flushes the flock: out all at
## once, wheeling over the stones, then off to another group away from him.
## Some while after (HOME_AFTER) with him away from home, they come back.
## A flock also moves on now and then by itself (ROAM). At dusk they fly
## off; at dawn they come in again.
##
## Everything is in world space; nothing is saved.
const Body = preload("res://scripts/songbird_body.gd")
## A flock of species "crow" gets crows (their own body and moves) instead.
const Crow = preload("res://scripts/crow_body.gd")
const Songbirds = preload("res://scripts/songbirds.gd")
const Disturbance = preload("res://scripts/disturbance.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")

## Flight, from the game's songbirds.
const SPEED := Songbirds.SPEED
const STEER := Songbirds.STEER
const APPROACH := Songbirds.APPROACH
const BOUND := Songbirds.BOUND
const BEAT := Songbirds.BEAT
const SIT := Vector2(9.0,22.0)
const WHEEL := Vector2(3.6,4.2)
const WHEEL_TIME := Songbirds.WHEEL_TIME
const CALM := Songbirds.CALM
const DUSK := Songbirds.DUSK
## What a perched bird does when its sit is up: hop along to a free perch
## within HOP_REACH m, drop to the turf to forage, or flit within the group.
const HOP_SHARE := 0.45
const FORAGE_SHARE := 0.3
const HOP_REACH := 1.7
## Foraging: seconds on the turf, a hop's length (m) and time (s), and the
## pause between hops (pecking).
const FORAGE := Vector2(5.0,12.0)
const GROUND_HOP := Vector2(0.12,0.3)
const GROUND_HOP_TIME := 0.16
const PECK := Vector2(0.4,1.4)
## Flush reach (m): the pilot's feet, more at a run (RUN_NEAR over RUN_PACE
## m/s), the plane; a gust front's notice strength that flushes.
const FIGURE_NEAR := 3.6
const RUN_NEAR := 5.5
const RUN_PACE := 4.0
const PLANE_NEAR := 14.0
const GUST_FLUSH := 0.24
## A flushed flock settles at least AWAY m from the pilot; back home after
## HOME_AFTER s once he is HOME_CLEAR m from home. Moves on by itself every
## ROAM s.
const AWAY := 12.0
const HOME_AFTER := Vector2(18.0,35.0)
const HOME_CLEAR := 14.0
const ROAM := Vector2(80.0,180.0)
## A perch: room over it (m), and how far over the turf a top must stand.
const ROOM := 0.18
const OVER_TURF := 0.7
## A flock keeps within FOCUS_REACH m of a perch of its group picked as it
## comes (`_focus`), so it reads as one flock.
const FOCUS_REACH := 5.0
## Seconds between a flier's look ahead for stone in its way.
const LOOK_AHEAD := 0.2

var scene: Node3D
var ground: Callable
## Perch groups by name: {name, middle, perches: [{at, face}], forage: [Vector3]}.
var groups := {}
var flocks: Array[Dictionary] = []
var birds: Array[Dictionary] = []
## What happened, for probes: take-offs, landings, hops, forages, flushes.
var counts := {}
var _held := {}
var _clock := 0.0
var _pending: Array = []
var _rng := RandomNumberGenerator.new()
## A placed isle's (scripts/kit_isle/motif_isle.gd): where it stands from
## its own frame, which `spots` answers in.
var offset := Vector3.ZERO

func setup(owner_scene: Node3D, ground_at: Callable) -> void:
	scene = owner_scene
	ground = ground_at
	name = "Songbirds"
	top_level = true
	_rng.seed = 4021
	var space := scene.get_world_3d().direct_space_state
	var found := spots(space)
	if offset != Vector3.ZERO:
		var by := Vector2(offset.x,offset.z)
		for group: String in found: found[group] = (found[group] as Array).map(func(p: Vector2) -> Vector2: return p+by)
	groups = perches_from(space,found,ground_at,float(scene.isle_top()))
	for spec: Array in flock_specs():
		if not groups.has(spec[2]) or (groups[spec[2]].perches as Array).size() < 2: continue
		var flock := {"index":flocks.size(),"species":spec[0],"home":spec[2],"group":spec[2],"state":"settled",
			"calm_until":0.0,"roam_at":_rng.randf_range(ROAM.x,ROAM.y),"home_at":INF,"wheel":{}}
		flocks.append(flock)
		for i in range(int(spec[1])):
			var bird := _new_bird(flock)
			var spot := _spot(flock,bird,false)
			if spot.is_empty(): continue
			bird.target = spot
			bird.p = spot.at
			bird.heading = spot.face
			bird.state = "perched"
			bird.timer = _rng.randf_range(0.5,SIT.y)
	Disturbance.hub().raised.connect(_raised)

## What stands over `outline` (x, z; an island's, scripts/world_islands.gd
## `grab`) carried with it: a Callable(step: Transform3D, a world move
## since the last call; IDENTITY once more after the links refit) that
## keeps each perch on the stone it was found on, when that stone is the
## island's or a link's it holds (so a perch on a beam over no island
## stays, and one on the aqueduct follows its refit), moves the turf to forage over it and the middle of
## a group wholly over it, and the birds: one bound for a moved perch goes
## as its perch does, one over the island (flying, foraging) with it.
func carrier(outline: PackedVector2Array) -> Callable:
	var over := func(p: Vector3) -> bool: return Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),outline)
	const WorldIslands = preload("res://scripts/world_islands.gd")
	var mine := WorldIslands.island_of_outline(outline)
	var held := {}
	var whole := {}
	for name: String in groups:
		var perches: Array = groups[name].perches
		var n := 0
		for k in range(perches.size()):
			var at: Vector3 = perches[k].at
			# The stone it sits on (found when the perch was), its island's or a link's.
			var body := perches[k].get("on") as Node3D
			if body == null or not is_instance_valid(body): continue
			var link := str(body.get_meta("world_link","")) if body.has_meta("world_link") else ""
			if WorldIslands.island_of(body) != mine and (link == "" or not mine in (WorldIslands.links[link].islands as Array)): continue
			held["%s:%d" % [name,k]] = [perches[k],body,body.global_transform.affine_inverse()*at,body.global_transform.basis.inverse()*(perches[k].face as Vector3)]
			n += 1
		if n > 0 and n == perches.size(): whole[name] = true
	var forage: Array = []
	for name: String in groups:
		var f: Array = groups[name].forage
		for k in range(f.size()):
			if over.call(f[k]): forage.append([f,k])
	# The island's whole move so far (the outline is where it stood when taken).
	var total := [Transform3D.IDENTITY]
	return func(step: Transform3D) -> void:
		total[0] = step*(total[0] as Transform3D)
		var before := ((total[0] as Transform3D).affine_inverse()*step)
		var moved := {}
		for key: String in held:
			var h: Array = held[key]
			var q: Dictionary = h[0]
			var body: Node3D = h[1]
			if not is_instance_valid(body): continue
			var was: Vector3 = q.at
			q.at = body.global_transform*(h[2] as Vector3)
			q.face = (body.global_transform.basis*(h[3] as Vector3)).normalized()
			moved[key] = (q.at as Vector3)-was
		for fk: Array in forage: fk[0][fk[1]] = step*(fk[0][fk[1]] as Vector3)
		for name: String in whole: groups[name].middle = step*(groups[name].middle as Vector3)
		for flock: Dictionary in flocks:
			if whole.has(flock.group) and flock.has("focus"): flock.focus = step*(flock.focus as Vector3)
		for bird: Dictionary in birds:
			var target: Dictionary = bird.target
			var key := str(target.get("key",""))
			var by := Transform3D.IDENTITY
			if moved.has(key):
				by = Transform3D(Basis.IDENTITY,moved[key])
				target.at = (held[key][0] as Dictionary).at
				target.face = (held[key][0] as Dictionary).face
			elif over.call(before*(bird.p as Vector3)):
				by = step
				if target.has("at") and not target.has("key"): target.at = step*(target.at as Vector3)
			else: continue
			if by == Transform3D.IDENTITY: continue
			bird.p = by*(bird.p as Vector3)
			bird.heading = (by.basis*(bird.heading as Vector3)).normalized()
			var hop: Dictionary = bird.hop
			if hop.has("from"): hop.from = by*(hop.from as Vector3)
			var body: Node3D = bird.body
			if is_instance_valid(body): body.global_transform = by*body.global_transform

func _exit_tree() -> void:
	if Disturbance.hub().raised.is_connected(_raised): Disturbance.hub().raised.disconnect(_raised)

# --- Perches ------------------------------------------------------------------------

## The flocks: [species, birds, home group].
func flock_specs() -> Array:
	return []

## The perch groups' candidate points: group name -> (x, z) points a ray
## comes down on.
func spots(_space: PhysicsDirectSpaceState3D) -> Dictionary:
	return {}

## The perch groups from `candidates` (name -> (x, z) points):
## a perch is a flat top OVER_TURF over the turf (or over the sky) with
## ROOM over it, found by a ray down from `top`+40 to `top`-20 m. Each group
## also gets turf to forage on round its middle.
static func perches_from(space: PhysicsDirectSpaceState3D, candidates: Dictionary, ground_at: Callable, top: float) -> Dictionary:
	var out := {}
	var ray := PhysicsRayQueryParameters3D.new()
	var ball := SphereShape3D.new()
	ball.radius = ROOM
	var room := PhysicsShapeQueryParameters3D.new()
	room.shape = ball
	for name: String in candidates:
		var perches: Array = []
		var middle := Vector3.ZERO
		for p: Vector2 in candidates[name]:
			ray.from = Vector3(p.x,top+40.0,p.y)
			ray.to = Vector3(p.x,top-20.0,p.y)
			var hit := space.intersect_ray(ray)
			if hit.is_empty() or (hit.normal as Vector3).y < 0.75: continue
			var at: Vector3 = hit.position
			var turf: Variant = ground_at.call(p)
			if turf != null and at.y < float(turf)+OVER_TURF: continue
			room.transform = Transform3D(Basis.IDENTITY,at+Vector3.UP*(ROOM+0.05))
			if not space.intersect_shape(room,1).is_empty(): continue
			var taken := false
			for q: Dictionary in perches:
				if (q.at as Vector3).distance_to(at) < 0.35: taken = true
			if taken: continue
			perches.append({"at":at,"on":hit.collider})
			middle += at
		if perches.is_empty(): continue
		middle /= perches.size()
		for q: Dictionary in perches:
			var away := Vector3((q.at as Vector3).x-middle.x,0.0,(q.at as Vector3).z-middle.z)
			if away.length() < 0.2: away = Vector3(1.0,0.0,0.3)
			q.face = away.normalized()
		# Turf to forage on round its perches (every few), off what stands.
		var forage: Array = []
		for n in range(0,perches.size(),maxi(1,perches.size()/6)):
			var base: Vector3 = perches[n].at
			for k in range(6):
				var a := TAU*k/6.0+0.4*n
				var p := Vector2(base.x+cos(a)*(2.0+float(k%3)),base.z+sin(a)*(2.0+float(k%3)))
				var turf: Variant = ground_at.call(p)
				if turf == null: continue
				room.transform = Transform3D(Basis.IDENTITY,Vector3(p.x,float(turf)+0.45,p.y))
				if not space.intersect_shape(room,1).is_empty(): continue
				forage.append(Vector3(p.x,float(turf),p.y))
		out[name] = {"name":name,"middle":middle,"perches":perches,"forage":forage}
	return out

# --- Birds --------------------------------------------------------------------------

func _new_bird(flock: Dictionary) -> Dictionary:
	var body: Node3D = Crow.new() if Crow.SPECIES.has(flock.species) else Body.new()
	body.build(flock.species)
	add_child(body)
	var bird := {"flock":flock.index,"state":"gone","p":Vector3.ZERO,"v":Vector3.ZERO,"heading":Vector3.FORWARD,"body":body,
		"target":{},"timer":0.0,"delay":0.0,"bound":_rng.randf()*0.5,"beat":_rng.randf()*TAU,"look":0.0,"look_goal":0.0,"look_at":0.0,
		"hop":{},"slot":0,"ahead":0.0,"over":0.0,"peck":0.0}
	birds.append(bird)
	return bird

## A spot in the flock's group for `bird`: a free perch near the flock's
## focus, or (`ground_ok`) turf near it to forage on.
func _spot(flock: Dictionary, bird: Dictionary, ground_ok := false) -> Dictionary:
	var group: Dictionary = groups.get(flock.group,{})
	if group.is_empty(): return {}
	_release(bird)
	var focus := _focus(flock)
	var forage: Array = group.forage
	if ground_ok and not forage.is_empty():
		var near := forage.filter(func(f: Vector3) -> bool: return Vector2(f.x-focus.x,f.z-focus.z).length() < FOCUS_REACH+4.0)
		if near.is_empty(): near = forage
		var at: Vector3 = near[_rng.randi_range(0,near.size()-1)]
		at += Vector3(_rng.randf_range(-0.6,0.6),0.0,_rng.randf_range(-0.6,0.6))
		var h: Variant = ground.call(Vector2(at.x,at.z))
		if h != null:
			at.y = float(h)
			var face := Vector3(_rng.randf_range(-1,1),0.0,_rng.randf_range(-1,1)).normalized()
			return {"kind":"ground","group":flock.group,"at":at,"face":face}
	var perches: Array = group.perches
	var start := _rng.randi_range(0,perches.size()-1)
	var far := -1
	for k in range(perches.size()):
		var i := (start+k)%perches.size()
		var key := "%s:%d" % [flock.group,i]
		if _held.has(key): continue
		if (perches[i].at as Vector3).distance_to(focus) > FOCUS_REACH:
			if far < 0: far = i
			continue
		return _hold(flock,bird,i)
	return _hold(flock,bird,far) if far >= 0 else {}

func _hold(flock: Dictionary, bird: Dictionary, i: int) -> Dictionary:
	var perch: Dictionary = groups[flock.group].perches[i]
	var key := "%s:%d" % [flock.group,i]
	_held[key] = bird
	return {"kind":"perch","group":flock.group,"key":key,"index":i,"at":perch.at,"face":perch.face}

## Where in its group a flock keeps together: a perch picked when it comes.
func _focus(flock: Dictionary) -> Vector3:
	if flock.get("focus_of","") != flock.group:
		var perches: Array = groups[flock.group].perches
		flock.focus = (perches[_rng.randi_range(0,perches.size()-1)].at as Vector3)
		flock.focus_of = flock.group
	return flock.focus

func _release(bird: Dictionary) -> void:
	var spot: Dictionary = bird.target
	if spot.get("kind","") == "perch" and _held.get(spot.key) == bird: _held.erase(spot.key)

func advance(delta: float) -> void:
	if delta <= 0.0: return
	_clock += delta
	for i in range(_pending.size()-1,-1,-1):
		if _clock >= float(_pending[i][0]):
			var call: Callable = _pending[i][1]
			_pending.remove_at(i)
			call.call()
	var day := _daylight()
	for flock in flocks: _advance_flock(flock,day)
	_check_pilot()
	for bird in birds: _advance_bird(bird,delta,day)
	_pose_all(delta)

func _members(flock: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for bird in birds:
		if int(bird.flock) == int(flock.index): out.append(bird)
	return out

func _daylight() -> float:
	var celestial: Variant = scene.get("_celestial")
	if celestial == null: return 1.0
	return float(celestial.state.get("zs_daylight",1.0))

## A flock's day: wheeling until its time is up, then off to its group;
## at dusk away, at dawn back; settled, now and then on to another group,
## and home again once the pilot has left it be.
func _advance_flock(flock: Dictionary, day: float) -> void:
	var members := _members(flock)
	if day < DUSK:
		for bird in members:
			if not bird.state in ["gone","leaving"]: _leave(bird)
		flock.state = "away"
		return
	if flock.state == "away":
		flock.state = "settled"
		flock.calm_until = _clock+CALM
		var from: Vector3 = (groups[flock.group].middle as Vector3)+Vector3(_rng.randf_range(-1,1),0.4,_rng.randf_range(-1,1)).normalized()*30.0
		for i in range(members.size()):
			var bird := members[i]
			bird.p = from+Vector3(_rng.randf_range(-1.5,1.5),_rng.randf_range(-0.6,0.6),_rng.randf_range(-1.5,1.5))
			bird.v = ((groups[flock.group].middle as Vector3)-from).normalized()*SPEED
			bird.delay = float(i)*0.3+_rng.randf()*0.4
			_fly_to(bird,_spot(flock,bird,false))
		return
	if flock.state == "wheeling" and _clock >= float(flock.wheel.until):
		flock.state = "settled"
		flock.calm_until = _clock+CALM
		for bird in members:
			bird.delay = _rng.randf()*0.6
			_fly_to(bird,_spot(flock,bird,false))
		_count("settle")
		return
	if flock.state != "settled" or _clock < float(flock.calm_until): return
	if flock.group != flock.home and _clock >= float(flock.home_at):
		var pilot := _pilot()
		if pilot == Vector3.INF or pilot.distance_to(groups[flock.home].middle) > HOME_CLEAR:
			_move(flock,flock.home,false)
			_count("home")
			return
		flock.home_at = _clock+_rng.randf_range(4.0,8.0)
	if _clock >= float(flock.roam_at):
		flock.roam_at = _clock+_rng.randf_range(ROAM.x,ROAM.y)
		var to := _choose_group(flock,_pilot())
		if to != "":
			_move(flock,to,false)
			_count("roam")

## A group for a flock to go to: not its own, the pilot at least AWAY m from
## it, nearer ones more often, one no other flock lives in if it can.
func _choose_group(flock: Dictionary, pilot: Vector3) -> String:
	var best := ""
	var best_score := -INF
	for name: String in groups:
		if name == flock.group: continue
		var middle: Vector3 = groups[name].middle
		if pilot != Vector3.INF and middle.distance_to(pilot) < AWAY: continue
		var score := -middle.distance_to(groups[flock.group].middle)*0.02+_rng.randf()
		for other in flocks:
			if other != flock and other.group == name: score -= 0.8
		if name == flock.home: score += 0.6
		if score > best_score:
			best_score = score
			best = name
	return best

## The flock off to group `to`: quietly (a roam, home) one by one, or
## (startled) all at once after wheeling over where they were.
func _move(flock: Dictionary, to: String, startled: bool) -> void:
	var members := _members(flock)
	flock.group = to
	flock.home_at = INF if to == flock.home else _clock+_rng.randf_range(HOME_AFTER.x,HOME_AFTER.y)
	if startled: return
	flock.calm_until = _clock+CALM
	for bird in members:
		if bird.state in ["gone","leaving"]: continue
		bird.delay = _rng.randf()*2.5
		if bird.state in ["perched","hopping","ground"]: _take_off(bird)
		_fly_to(bird,_spot(flock,bird,false))

## The whole flock out at once, wheeling over where it was, then off to
## another group away from the pilot.
func flush(flock: Dictionary) -> void:
	if flock.state != "settled": return
	var members := _members(flock)
	var centre := Vector3.ZERO
	var n := 0
	for i in range(members.size()):
		var bird := members[i]
		if bird.state in ["gone","leaving"]: continue
		bird.delay = _rng.randf()*0.3
		if bird.state in ["perched","hopping","ground"]: _take_off(bird)
		_release(bird)
		bird.state = "wheeling"
		bird.slot = i
		centre += bird.p
		n += 1
	if n == 0: return
	centre /= n
	flock.wheel = {"centre":centre+Vector3.UP*WHEEL.y,"radius":WHEEL.x,"since":_clock,"until":_clock+_rng.randf_range(WHEEL_TIME.x,WHEEL_TIME.y),
		"spin":(1.0 if _rng.randf() < 0.5 else -1.0)*1.3,"angle0":_rng.randf()*TAU,"count":members.size()}
	flock.state = "wheeling"
	var to := _choose_group(flock,_pilot())
	_move(flock,to if to != "" else flock.group,true)
	_count("flush")

## The pilot's feet, or INF while flying.
func _pilot() -> Vector3:
	if bool(scene.get("flying")):
		var figure: Variant = scene.get("plane_figure")
		return (figure as Node3D).global_position if figure is Node3D else Vector3.INF
	var motor: Variant = scene.get("motor")
	return motor.feet if motor != null else Vector3.INF

## The pilot near a settled flock's bird (nearer at a walk than at a run),
## or the plane passing, flushes it.
func _check_pilot() -> void:
	var at := _pilot()
	if at == Vector3.INF: return
	var flying: bool = bool(scene.get("flying"))
	var reach := PLANE_NEAR if flying else FIGURE_NEAR
	if not flying:
		var motor: Variant = scene.get("motor")
		if motor != null and motor.speed() > RUN_PACE: reach = RUN_NEAR
	for flock in flocks:
		if flock.state != "settled" or _clock < float(flock.calm_until): continue
		for bird in _members(flock):
			if bird.state in ["gone","leaving"]: continue
			var p: Vector3 = bird.p
			if (p-at).length() < reach:
				flush(flock)
				break

## A gust front sent (B) flushes the flocks its head reaches, as it reaches
## them; the breeze's ordinary fronts only ruffle.
func _raised(point: Vector3, _radius: float, strength: float, kind: String, detail: Dictionary) -> void:
	if kind != "gust" or strength < GUST_FLUSH: return
	var way: Vector3 = detail.get("way",Vector3.ZERO)
	if way.length_squared() < 0.01: return
	var speed := float(detail.get("span",1.0))/maxf(float(detail.get("run",1.0)),0.01)
	for flock in flocks:
		var middle: Vector3 = groups[flock.group].middle
		var off := Vector2(middle.x-point.x,middle.z-point.z)
		var along := off.dot(Vector2(way.x,way.z))
		var across := absf(off.dot(Vector2(-way.z,way.x)))
		if along < 0.0 or along > float(detail.get("span",0.0)) or across > float(detail.get("across",0.0)): continue
		var startled := flock
		_pending.append([_clock+along/maxf(speed,0.1)+_rng.randf_range(0.0,0.3),func() -> void: flush(startled)])

func _advance_bird(bird: Dictionary, step: float, day: float) -> void:
	if float(bird.delay) > 0.0:
		bird.delay = float(bird.delay)-step
		return
	match str(bird.state):
		"perched": _sit(bird,step,day)
		"hopping": _hop(bird,step)
		"ground": _forage(bird,step)
		"flying","landing","wheeling","leaving": _fly(bird,step)

## On the stone: look about in quick snaps, flick the tail; after a while
## hop to a free perch along, drop to the turf, or flit within the group.
func _sit(bird: Dictionary, step: float, day: float) -> void:
	bird.timer = float(bird.timer)-step
	var spot: Dictionary = bird.target
	bird.p = spot.at
	bird.heading = _turn(bird.heading,spot.face,minf(step*5.0,1.0))
	_glance(bird,step)
	if _rng.randf() < step*0.3: (bird.body as Node3D).set("tail_flick",1.0)
	if float(bird.timer) > 0.0 or day < DUSK: return
	var flock: Dictionary = flocks[int(bird.flock)]
	if flock.state != "settled": return
	var roll := _rng.randf()
	if roll < HOP_SHARE:
		var group: Dictionary = groups[spot.group]
		var perches: Array = group.perches
		var order := range(perches.size())
		order.shuffle()
		for i: int in order:
			var key := "%s:%d" % [spot.group,i]
			if key == spot.key or _held.has(key): continue
			if (perches[i].at as Vector3).distance_to(spot.at) > HOP_REACH: continue
			_release(bird)
			_held[key] = bird
			bird.hop = {"from":bird.p,"t":0.0}
			bird.target = {"kind":"perch","group":spot.group,"key":key,"index":i,"at":perches[i].at,"face":perches[i].face}
			bird.state = "hopping"
			return
	_take_off(bird)
	_fly_to(bird,_spot(flock,bird,roll >= HOP_SHARE and roll < HOP_SHARE+FORAGE_SHARE))

## The head snaps between glances.
func _glance(bird: Dictionary, step: float) -> void:
	bird.look_at = float(bird.look_at)-step
	if float(bird.look_at) <= 0.0:
		bird.look_goal = _rng.randf_range(-0.9,0.9) if _rng.randf() < 0.8 else 0.0
		bird.look_at = _rng.randf_range(0.4,1.6)

func _hop(bird: Dictionary, step: float) -> void:
	var hop: Dictionary = bird.hop
	hop.t = float(hop.t)+step/0.35
	var to: Vector3 = bird.target.at
	var t := minf(float(hop.t),1.0)
	var from: Vector3 = hop.from
	var flat := Vector3(to.x-from.x,0.0,to.z-from.z)
	if flat.length_squared() > 0.0001: bird.heading = flat.normalized()
	bird.p = from.lerp(to,t)+Vector3.UP*sin(t*PI)*0.12
	if t >= 1.0:
		bird.state = "perched"
		bird.timer = _rng.randf_range(SIT.x,SIT.y)
		_count("hop")

## On the turf: short hops this way and that, a peck between; then up to
## a perch.
func _forage(bird: Dictionary, step: float) -> void:
	bird.timer = float(bird.timer)-step
	var hop: Dictionary = bird.hop
	if not hop.is_empty():
		hop.t = float(hop.t)+step/GROUND_HOP_TIME
		var t := minf(float(hop.t),1.0)
		var to: Vector3 = hop.to
		bird.p = (hop.from as Vector3).lerp(to,t)+Vector3.UP*sin(t*PI)*0.07
		if t >= 1.0:
			bird.hop = {}
			bird.peck = _rng.randf_range(PECK.x,PECK.y)
		return
	bird.peck = float(bird.peck)-step
	# Pecking: the head dips now and then (`_pose_all`), glances between.
	_glance(bird,step)
	if float(bird.peck) > 0.0: return
	if float(bird.timer) <= 0.0 and flocks[int(bird.flock)].state == "settled":
		_take_off(bird)
		_fly_to(bird,_spot(flocks[int(bird.flock)],bird,false))
		return
	var way := (bird.heading as Vector3).rotated(Vector3.UP,_rng.randf_range(-1.4,1.4))
	var to: Vector3 = (bird.p as Vector3)+way*_rng.randf_range(GROUND_HOP.x,GROUND_HOP.y)
	var h: Variant = ground.call(Vector2(to.x,to.z))
	if h == null or absf(float(h)-(bird.p as Vector3).y) > 0.3 or Vector2(to.x-(bird.target.at as Vector3).x,to.z-(bird.target.at as Vector3).z).length() > 1.6:
		bird.heading = -(bird.heading as Vector3)
		bird.peck = 0.2
		return
	to.y = float(h)
	bird.heading = way
	bird.hop = {"from":bird.p,"to":to,"t":0.0}

## Steering to its spot (the last stretch to a perch slow, in from its open
## side), wheeling, or leaving at dusk; bounding flight while cruising. A
## look ahead now and then lifts it over stone in its way.
func _fly(bird: Dictionary, step: float) -> void:
	var goal: Vector3
	var speed := SPEED
	var arrive := 0.15
	var flock: Dictionary = flocks[int(bird.flock)]
	if bird.state == "wheeling":
		var wheel: Dictionary = flock.wheel
		var angle := float(wheel.angle0)+float(bird.slot)*TAU/maxf(float(wheel.count),1.0)+(_clock-float(wheel.since))*float(wheel.spin)
		goal = (wheel.centre as Vector3)+Vector3(cos(angle),sin(angle*1.7+float(bird.slot))*0.3,sin(angle))*float(wheel.radius)*(0.8+0.25*sin(float(bird.slot)*2.1))
		speed = SPEED*1.15
		arrive = -1.0
	elif bird.state == "leaving":
		goal = bird.target.at
		speed = SPEED*1.2
		if (bird.p as Vector3).distance_to(goal) < 1.0:
			bird.state = "gone"
			return
		arrive = -1.0
	else:
		var spot: Dictionary = bird.target
		if spot.is_empty():
			_fly_to(bird,_spot(flock,bird,false))
			if (bird.target as Dictionary).is_empty(): return
			spot = bird.target
		goal = spot.at
		var front: Vector3 = goal+(spot.face as Vector3)*0.9+Vector3.UP*0.35
		if bird.state == "flying" and (bird.p as Vector3).distance_to(front) < 0.35: bird.state = "landing"
		if bird.state == "flying": goal = front
		else:
			speed = APPROACH
			arrive = 0.03
	var p: Vector3 = bird.p
	# Stone in the way: over it.
	bird.ahead = float(bird.ahead)-step
	if float(bird.ahead) <= 0.0 and bird.state != "landing":
		bird.ahead = LOOK_AHEAD
		var space := get_world_3d().direct_space_state
		var to_goal := goal-p
		var reach := minf(to_goal.length(),3.0)
		bird.over = 0.0
		if reach > 0.3:
			var ray := PhysicsRayQueryParameters3D.create(p,p+to_goal.normalized()*reach,1)
			if not space.intersect_ray(ray).is_empty(): bird.over = 2.5
	var to := goal-p+Vector3.UP*float(bird.over)
	var reach := (goal-p).length()
	if arrive > 0.0 and reach <= arrive:
		_land(bird)
		return
	var want := to.normalized()*speed*clampf(reach/1.6,0.3 if bird.state != "landing" else 0.6,1.0)
	var h: Variant = ground.call(Vector2(p.x,p.z))
	if h != null and p.y < float(h)+1.0 and reach > 2.0: want.y += (float(h)+1.0-p.y)*3.0
	for other in birds:
		if other == bird or int(other.flock) != int(bird.flock) or not other.state in ["flying","wheeling"]: continue
		var gap := p-(other.p as Vector3)
		var d := gap.length()
		if d < 0.45 and d > 0.001: want += gap/d*(0.45-d)*6.0
	bird.v = (bird.v as Vector3).move_toward(want,STEER*step)
	p += (bird.v as Vector3)*step
	if h != null: p.y = maxf(p.y,float(h)+(0.0 if bird.state == "landing" else 0.12))
	bird.p = p
	var v: Vector3 = bird.v
	var flat := Vector3(v.x,0.0,v.z)
	if flat.length_squared() > 0.01: bird.heading = _turn(bird.heading,flat.normalized(),minf(step*8.0,1.0))
	bird.bound = fmod(float(bird.bound)+step,BOUND.x+BOUND.y)
	bird.beat = float(bird.beat)+step*BEAT

## Level heading `a` turned `t` of the way to `b`.
static func _turn(a: Vector3, b: Vector3, t: float) -> Vector3:
	var turned := a.lerp(b,t)
	turned.y = 0.0
	return turned.normalized() if turned.length_squared() > 0.0001 else b

func _land(bird: Dictionary) -> void:
	var spot: Dictionary = bird.target
	bird.v = Vector3.ZERO
	bird.p = spot.at
	if spot.kind == "perch":
		bird.state = "perched"
		bird.timer = _rng.randf_range(SIT.x,SIT.y)
		_count("land_perch")
	else:
		bird.state = "ground"
		bird.timer = _rng.randf_range(FORAGE.x,FORAGE.y)
		bird.hop = {}
		bird.peck = _rng.randf_range(PECK.x,PECK.y)
		_count("land_ground")

func _take_off(bird: Dictionary) -> void:
	var face: Vector3 = bird.heading
	bird.v = face*1.6+Vector3.UP*1.9
	bird.hop = {}
	bird.state = "flying"
	_count("take_off")

func _fly_to(bird: Dictionary, spot: Dictionary) -> void:
	if spot.is_empty():
		bird.target = {}
		bird.state = "wheeling" if flocks[int(bird.flock)].state == "wheeling" else "flying"
		return
	bird.target = spot
	bird.state = "flying"

## Off over the rim at dusk.
func _leave(bird: Dictionary) -> void:
	_release(bird)
	if bird.state in ["perched","hopping","ground"]: _take_off(bird)
	if bird.state == "gone": return
	var p: Vector3 = bird.p
	var out := Vector3(_rng.randf_range(-1,1),0.0,_rng.randf_range(-1,1)).normalized()
	bird.target = {"kind":"away","at":p+out*30.0+Vector3.UP*12.0}
	bird.state = "leaving"
	bird.delay = _rng.randf()*3.0

# --- Posing (as the game's songbirds) -------------------------------------------------

func _pose_all(delta: float) -> void:
	for bird in birds:
		var body: Node3D = bird.body
		var shown: bool = bird.state != "gone"
		body.visible = shown
		if not shown: continue
		body.global_position = bird.p
		var heading: Vector3 = bird.heading
		var yaw := atan2(-heading.x,-heading.z)
		if body is Crow:
			# A crow poses itself from the bird's state (scripts/crow_body.gd).
			body.animate(bird,delta,yaw)
			continue
		var pitch := 0.0
		var airborne: bool = bird.state in ["flying","landing","wheeling","leaving"]
		if airborne:
			var v: Vector3 = bird.v
			pitch = clampf(atan2(v.y,maxf(Vector2(v.x,v.z).length(),0.3))*0.6,-0.6,0.6)
		else:
			pitch -= 0.18*float(body.tail_flick)
			# Foraging: a peck dips the body forward between hops.
			if bird.state == "ground" and (bird.hop as Dictionary).is_empty():
				pitch -= 0.45*maxf(0.0,sin(float(bird.peck)*9.0))
		body.global_basis = Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,pitch)*Basis.from_scale(Vector3.ONE*Body.SIZE)
		_pose_wings(bird,airborne)
		bird.look = lerpf(float(bird.look),float(bird.look_goal) if not airborne else 0.0,1.0-exp(-delta*14.0))
		body.head.rotation = Vector3(-0.12 if airborne else 0.0,float(bird.look),0.0)
		body.tail_flick = maxf(float(body.tail_flick)-delta*5.0,0.0)

func _pose_wings(bird: Dictionary, airborne: bool) -> void:
	var body: Node3D = bird.body
	if not airborne:
		body.spread_wings(false)
		for wing in body.wings: wing.rotation.z = 0.0
		return
	var landing: bool = bird.state == "landing"
	var beating: bool = landing or float(bird.bound) < BOUND.x or float((bird.v as Vector3).y) > 1.2 or bird.state == "wheeling" and float(bird.bound) < BOUND.x*1.4
	body.spread_wings(beating)
	for i in range(2):
		var side := -1.0 if i == 0 else 1.0
		var lift := sin(float(bird.beat))*(0.55 if landing else 0.95)+(0.5 if landing else 0.15)
		body.wings[i].rotation.z = side*lift if beating else 0.0

## Birds in sight: [{node, p, state}].
func visible_birds() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for bird in birds:
		if (bird.body as Node3D).visible: out.append({"node":bird.body,"p":bird.p,"state":bird.state})
	return out

func _count(kind: String) -> void:
	counts[kind] = int(counts.get(kind,0))+1
