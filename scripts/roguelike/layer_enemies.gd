extends Node
## The generated layer's enemies (docs/design/roguelike/layer-round8-
## enemies.md): the inhaler head (scripts/enemies/inhaler_head.gd, docs/
## design/roguelike/inhaler-head.md) laid by the generator on the isles of a
## sprawl or a ring, as data (`lay`, from LayerSprawl and LayerRing `core`
## once the hazards are laid, so it keeps off their perches), built into the
## stage's EnemyField (`dress`, a child of scripts/roguelike/layer_stage.gd,
## which steps the field round the motor).
##
## A head is set down over a clear spot (SPOT_ROOM round) of an isle and
## its round laid on the open ground round it: the ground it can heave
## itself over flood filled from the spot (`_open`, `_under`; round 2,
## inhaler-head-round2-scoot.md: it is ground bound, so turf under its
## middle and all round its jaw's foot, no stone under its body higher
## than its `climb` up to its crown, a rise or fall from cell to cell no
## more than its `climb` or its `slope` over a cell, never out over the
## void), then ROUND points picked far apart on it, each leg straight over
## open cells (`_round`). Its body over every leg clear of the edges' paths, the
## rides' tubes, the piers and the cannons (LayerHazards `_lumps_clear`)
## and ARROW_CLEAR of a gust arrow's perch and where it fires; the spot
## SPAWN_CLEAR from the spawn, GATE_CLEAR from the gate, RAM_CLEAR from the
## ram, PRIZE_CLEAR from the rune perch; heads APART and one an isle. The
## longest rounds first; the base (where he starts) last.
##
## Knob (LayerPlan KNOBS): `heads` (-1 rolled HEADS, 0 none, n as many as
## fit).
const LayerPlan = preload("res://scripts/roguelike/layer_plan.gd")
const LayerHazards = preload("res://scripts/roguelike/layer_hazards.gd")
const LayerPieces = preload("res://scripts/roguelike/layer_pieces.gd")
const KitMotif = preload("res://scripts/kit_isle/kit_motif.gd")
const PhysicsGround = preload("res://scripts/pilot_physics_ground.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const InhalerHead = preload("res://scripts/enemies/inhaler_head.gd")
const BodySpawner = preload("res://scripts/enemies/body_spawner.gd")
const LayerBodies = preload("res://scripts/roguelike/layer_bodies.gd")
const EnemyYard = preload("res://studies/enemy_yard.gd")
## The greybox motifs' own heads (scripts/roguelike/layer_greybox.gd).
const LayerGreybox = preload("res://scripts/roguelike/layer_greybox.gd")
## Olmec threat round 1 (docs/design/roguelike/olmec-threat-round1.md):
## the layer's roaming Olmec, and whether the places keep their own.
const LayerOlmec = preload("res://scripts/roguelike/layer_olmec.gd")
const OlmecPlaces = preload("res://scripts/enemies/olmec_places.gd")
## Underground, with the roaming Olmec (`olmecs` not "places"): one head
## a layer (its body comes for it up the cliffs, then hunts you), two from
## this danger on; `--knob=olmec_count=N` pins it.
const ROAM_TWO := 0.66
## A roaming head rated a point less each this far (m) from the spawn.
const ROAM_NEAR := 150.0

## How many heads a layer rolls.
const HEADS := Vector2i(1,2)
## Underground, the generator's own heads at the danger's top (the fourth
## region on); the places' Keepers come besides.
const DANGER_HEADS := 3
## The spots a head is set down over (m round clear), and its round: up to
## ROUND points (ROUND_LEAST at least), SPREAD of its `ring` (6 of the
## walker's heights) apart, on the open ground round the spot (flood
## filled in CELL m steps out to REACH of its `ring`, OPEN_LEAST cells at
## least), the loop LOOP_LEAST of its `ring` long at least; the best of
## ROUND_TRIES.
const SPOT_ROOM := 3.0
const ROUND := 5
const ROUND_LEAST := 3
const SPREAD := 0.8
const CELL := 1.5
const REACH := 2.4
const OPEN_LEAST := 40
const LOOP_LEAST := 3.5
const ROUND_TRIES := 4
## A round on the base (the aqueduct isle, where he starts) rates this
## less: the isles out on the way first.
const BASE_LESS := 0.6
## Over the void it goes no cells out past the turf (it is ground bound).
const VOID_CELLS := 0
## Its ground (`_under`): its body's half width more this (m); the turf it
## finds under it from FLOOR_UP over its last down to FLOOR_DOWN under (its
## `ground_at`'s); its jaw's foot, FOOT of that half width round, all on
## turf; stone up to CROWN_MARGIN over its crown is in its way.
const BODY_MORE := 0.3
const FLOOR_UP := 6.0
const FLOOR_DOWN := 12.0
const FOOT := 0.75
const CROWN_MARGIN := 0.5
## At most this share of a round's samples over the void.
const VOID_SHARE := 0.35
## Samples along each leg (m).
const SAMPLE := 1.5
## Keeps (m, flat): the spawn (past its sight), the gate, the ram, a gust
## arrow's perch and its stretch, another head.
const SPAWN_CLEAR := 30.0
const GATE_CLEAR := 16.0
const RAM_CLEAR := 22.0
const ARROW_CLEAR := 12.0
const PRIZE_CLEAR := 10.0
const APART := 60.0

# --- Planning -----------------------------------------------------------------------

static var _numbers := {}
static var _numbers_lock := Mutex.new()

## The pilot's numbers, as EnemyField `numbers()` gives them in play, and
## the head's knobs sized from them.
static func head_knobs() -> Dictionary:
	_numbers_lock.lock()
	if _numbers.is_empty():
		var n := numbers()
		var head: Node3D = InhalerHead.new()
		var k: Dictionary = head.default_knobs(n)
		head.free()
		k.unit = n.unit
		k.height = float(k.size)*n.unit
		k.half = k.height*1.04*0.5
		_numbers = k
	var out := _numbers
	_numbers_lock.unlock()
	return out

## The pilot's numbers, as EnemyField `numbers()` gives them in play.
static func numbers() -> Dictionary:
	var p: PilotMotor = KitMotif.pilot()
	return {"run":p.run,"walk":p.walk,"unit":maxf(PhysicsGround.HEAD*p.size,PhysicsGround.BODY_LOW+0.3),"gravity":p.gravity,
		"fall":p.fall,"jump":float(p.jumps[0]),"size":p.size,"step_up":PilotMotor.STEP_UP,
		"radius":PhysicsGround.RADIUS*p.size,"skid":PilotMotor.TUMBLE_SKID}

## The heads laid into `plan` (`plan.heads`: [{isle, at, face, route, void,
## on}]).
static func lay(plan: Dictionary, attempt: int) -> void:
	plan.heads = []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(plan.seed),attempt,"enemies"])
	var n := int((plan.knobs as Dictionary).get("heads",-1))
	if n < 0: n = rng.randi_range(HEADS.x,HEADS.y)
	# Underground the city's places bring their own Olmecs (each its
	# Keeper); the generator's wandering heads come by height (layer_
	# worlds.gd `danger`): none on the first region, up to DANGER_HEADS.
	if int((plan.knobs as Dictionary).get("heads",-1)) < 0 and LayerPlan.LayerWorlds.city(plan.knobs):
		n = roundi(float(DANGER_HEADS)*LayerPlan.LayerWorlds.danger(plan.knobs))
	# Olmec threat round 1: one roaming Olmec (two high up), the places'
	# Keepers and heads left out.
	var roam := roams(plan.knobs)
	if roam:
		n = int((plan.knobs as Dictionary).get("olmec_count",-1))
		if n < 0: n = 2 if LayerPlan.LayerWorlds.danger(plan.knobs) >= ROAM_TWO else 1
	if n == 0 and not roam:
		LayerGreybox.lay_heads(plan,numbers())
		return
	var cands := _candidates(plan,rng) if n > 0 else []
	# Roaming: his head on the way up, early (the climb to it seen, then
	# him whole and after you for the rest of the layer).
	if roam:
		var from: Vector3 = (plan.spawn as Dictionary).get("at",Vector3.ZERO)
		for c: Dictionary in cands:
			var isle: Dictionary = plan.isles[int(c.isle)]
			c.score = float(c.score)+(1.0 if str(isle.get("role","")) == "route" else 0.0)-0.2*float(c.isle)-_flat(c.at,from)/ROAM_NEAR
	# The longest rounds, out over the void a little first; one an isle.
	cands.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.score) > float(b.score))
	# With bodies (round 9, scripts/roguelike/layer_bodies.gd), a head
	# whose body has no cliff it can come up and get to it from waits
	# behind those with one; laid bodiless only if nothing else fits.
	var bodies := int((plan.knobs as Dictionary).get("bodies",1)) != 0
	var bodiless: Array = []
	for pass_ in range(2 if bodies else 1):
		var pool: Array = cands if pass_ == 0 else bodiless
		for c: Dictionary in pool:
			if (plan.heads as Array).size() >= n: break
			if not _fits(plan,c): continue
			c.cliffs = []
			if bodies and pass_ == 0:
				c.cliffs = LayerBodies.cliffs(plan,c,numbers())
				if (c.cliffs as Array).is_empty():
					bodiless.append(c)
					continue
			c.erase("score")
			plan.heads.append(c)
	if roam:
		# None of the generator's fit: a place's own head (with a cliff).
		if (plan.heads as Array).size() < n:
			var tmp := plan.duplicate()
			tmp.heads = []
			LayerGreybox.lay_heads(tmp,numbers())
			for h: Dictionary in tmp.heads:
				if (plan.heads as Array).size() < n and not (h.get("cliffs",[]) as Array).is_empty() and _fits(plan,h): plan.heads.append(h)
		return
	# A greybox isle's own heads, the generator's kept off it.
	LayerGreybox.lay_heads(plan,numbers())

## Whether the layer has the roaming Olmec (underground, `olmecs` not
## "places", `heads` not pinned).
static func roams(knobs: Dictionary) -> bool:
	return LayerPlan.LayerWorlds.city(knobs) and OlmecPlaces.mode(knobs) == "roam" and int(knobs.get("heads",-1)) < 0

## Whether head candidate `c` goes with those laid: one an isle, APART.
static func _fits(plan: Dictionary, c: Dictionary) -> bool:
	for h: Dictionary in plan.heads:
		if int(h.isle) == int(c.isle) or _flat(h.at,c.at) < APART: return false
	return true

## Every spot that takes a round, with its best round.
static func _candidates(plan: Dictionary, rng: RandomNumberGenerator) -> Array:
	var k := head_knobs()
	var out: Array = []
	var bare := plan.duplicate()
	bare.isles = []
	var spawn: Vector3 = (plan.spawn as Dictionary).get("at",Vector3.INF)
	var gate: Vector3 = (plan.exit as Dictionary).get("at",Vector3.INF)
	for i in range((plan.isles as Array).size()):
		var isle: Dictionary = plan.isles[i]
		var spots: Array = (isle.sockets as Array).filter(func(s: Dictionary) -> bool: return (s.kind == "arena" or s.kind == "perch") and float(s.room) >= SPOT_ROOM)
		if i == 0:
			# The city landing: no head where he arrives.
			if not LayerPlan.aqueduct_base(plan): continue
			spots = LayerPlan.base_spots(plan,"perch").filter(func(s: Dictionary) -> bool: return float(s.room) >= SPOT_ROOM)
		LayerPlan._shuffle(spots,rng)
		var taken: Array = []
		for s: Dictionary in spots:
			var at: Vector3 = s.at
			if spawn != Vector3.INF and _flat(at,spawn) < SPAWN_CLEAR: continue
			if gate != Vector3.INF and _flat(at,gate) < GATE_CLEAR: continue
			if not (plan.ram as Dictionary).is_empty() and _flat(at,plan.ram.at) < RAM_CLEAR: continue
			if not (plan.prize as Dictionary).is_empty() and _flat(at,plan.prize.at) < PRIZE_CLEAR: continue
			# A spot on open ground already flooded is the same ground.
			var inside := false
			for t: Array in taken:
				var c := Vector2i(roundi((at.x-(t[0] as Vector3).x)/CELL),roundi((at.z-(t[0] as Vector3).z)/CELL))
				if (t[1] as Dictionary).has(c) and str(t[1][c][0]) != "stone": inside = true
			if inside: continue
			var cells := _open(plan,at,k)
			if cells.is_empty(): continue
			taken.append([at,cells])
			var r := _round(plan,bare,at,cells,k,rng)
			if r.is_empty(): continue
			r.isle = i
			r.at = at
			r.on = "%s (%s)" % [isle.id,s.name]
			r.score = float(r.score)+rng.randf()*0.5-(BASE_LESS if i == 0 else 0.0)
			out.append(r)
	return out

## The open ground round `at` the head can ride (`_under`), flood filled in
## CELL m steps out to REACH of its `ring` (over the void at most VOID_CELLS
## out past the turf): {Vector2i: [kind, its turf's height]}.
static func _open(plan: Dictionary, at: Vector3, k: Dictionary) -> Dictionary:
	var half: float = float(k.half)+BODY_MORE
	var rise: float = k.climb
	var climb: float = maxf(float(k.climb),CELL*tan(float(k.slope)))
	var top: float = float(k.height)+CROWN_MARGIN
	var reach: float = float(k.ring)*REACH
	var cells := {Vector2i.ZERO:["turf",at.y,0]}
	var first := _under(plan,at,at.y,half,rise,top,climb)
	if str(first[0]) != "turf": return {}
	var front: Array = [Vector2i.ZERO]
	while not front.is_empty():
		var c: Vector2i = front.pop_front()
		var was: Array = cells[c]
		for d: Vector2i in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			var n := c+d
			if cells.has(n): continue
			var p := at+Vector3(n.x,0.0,n.y)*CELL
			if Vector2(n.x,n.y).length()*CELL > reach: continue
			var met := _under(plan,p,float(was[1]),half,rise,top,climb)
			var out := 0 if str(met[0]) == "turf" else int(was[2])+1
			if str(met[0]) == "stone" or out > VOID_CELLS:
				cells[n] = ["stone",0.0,0]
				continue
			cells[n] = [met[0],met[1],out]
			front.append(n)
	return cells

## A round on the open ground round `at`: ROUND points (ROUND_LEAST at
## least) far apart, each leg straight over open cells: {route, face, void
## (its share of the round over the void), score}, or {}.
static func _round(plan: Dictionary, bare: Dictionary, at: Vector3, cells: Dictionary, k: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var open: Array = []
	for c: Vector2i in cells:
		if str(cells[c][0]) != "stone" and c != Vector2i.ZERO: open.append(c)
	if open.size() < OPEN_LEAST: return {}
	var best := {}
	for t in range(ROUND_TRIES):
		# Greedy: each next point the furthest from those chosen, its leg from
		# the last open; the round closed back to the first.
		var picks: Array = [Vector2i.ZERO]
		var order := open.duplicate()
		LayerPlan._shuffle(order,rng)
		while picks.size() < ROUND+1:
			var far := -1.0
			var pick := Vector2i(999,999)
			for c: Vector2i in order:
				var d := INF
				for q: Vector2i in picks: d = minf(d,Vector2(c-q).length())
				if d*CELL < float(k.ring)*SPREAD: continue
				d += rng.randf()*2.0
				if d > far and _leg_open(cells,picks[picks.size()-1],c):
					far = d
					pick = c
			if far < 0.0: break
			picks.append(pick)
		picks.pop_front()
		while picks.size() >= ROUND_LEAST and not _leg_open(cells,picks[picks.size()-1],picks[0]): picks.pop_back()
		if picks.size() < ROUND_LEAST: continue
		var r := _rate(plan,bare,at,cells,picks,k)
		if not r.is_empty() and (best.is_empty() or float(r.score) > float(best.score)): best = r
	return best

## Whether the straight leg from cell `a` to `b` stays over open cells.
static func _leg_open(cells: Dictionary, a: Vector2i, b: Vector2i) -> bool:
	var n := maxi(int(ceil(Vector2(b-a).length()*2.0)),1)
	for j in range(n+1):
		var v := Vector2(a).lerp(Vector2(b),float(j)/n)
		var c := Vector2i(roundi(v.x),roundi(v.y))
		if not cells.has(c) or str(cells[c][0]) == "stone": return false
	return true

## The round through `picks` rated: its body over every leg clear of the
## layer's edges, tubes, piers and cannons and the gust arrows; the shares
## over turf and void; {} where it won't do.
static func _rate(plan: Dictionary, bare: Dictionary, at: Vector3, cells: Dictionary, picks: Array, k: Dictionary) -> Dictionary:
	var half: float = float(k.half)+BODY_MORE
	var tall: float = k.height
	var route: Array = []
	for c: Vector2i in picks: route.append(at+Vector3(c.x,0.0,c.y)*CELL)
	var lumps: Array = []
	var turf := 0
	var voids := 0
	var length := 0.0
	var stops: Array = [Vector2i.ZERO]+picks+[picks[0]]
	for j in range(stops.size()-1):
		var a: Vector2i = stops[j]
		var b: Vector2i = stops[j+1]
		length += Vector2(b-a).length()*CELL
		var n := maxi(int(ceil(Vector2(b-a).length()*CELL/SAMPLE)),1)
		for m in range(n):
			var v := Vector2(a).lerp(Vector2(b),float(m)/n)
			var cell: Array = cells[Vector2i(roundi(v.x),roundi(v.y))]
			if str(cell[0]) == "void": voids += 1
			else: turf += 1
			if m%2 == 0: lumps.append([at+Vector3(v.x*CELL,float(cell[1])-at.y+tall*0.5,v.y*CELL),half,tall*0.5,tall*0.5])
	var count := turf+voids
	if length < float(k.ring)*LOOP_LEAST: return {}
	if float(voids)/count > VOID_SHARE: return {}
	if not LayerHazards._lumps_clear(bare,lumps): return {}
	for l: Array in lumps:
		for a: Dictionary in plan.get("arrows",[]):
			if _flat(l[0],a.top) < ARROW_CLEAR or _flat(l[0],a.mid) < ARROW_CLEAR: return {}
	var first: Vector3 = route[0]
	return {"route":route,"face":Vector3(first.x-at.x,0.0,first.z-at.z).normalized(),"void":float(voids)/count,
		"length":length,"score":minf(length/(float(k.ring)*TAU),1.5)+(0.3 if voids > 0 else 0.0)}

## What the head meets at `p` heaving over from `ground` (the last turf's
## height), as its `ground_at` does (the first stone under its middle, from
## FLOOR_UP over that down to FLOOR_DOWN under): ["turf", the turf's height]
## no more than `climb` over or under the last, with nothing under its body
## (`half` round) standing more than `rise` over the turf and under its
## crown (`top` m up), and turf all round its foot (FOOT of `half`);
## ["void", ground] with nothing under its middle; ["stone", 0] where stone
## is in its way or its foot would hang over a rim.
static func _under(plan: Dictionary, p: Vector3, ground: float, half: float, rise: float, top: float, climb: float) -> Array:
	var floor_y := -INF
	var near: Array = []
	for isle: Dictionary in plan.isles:
		if not LayerPlan._rect(isle).grow(half+1.0).has_point(Vector2(p.x,p.z)): continue
		near.append(isle)
		var o := LayerPlan.occ_at(isle,p.x,p.z)
		if o.x == INF: continue
		# Stone over where its ray starts: an arch or a wall it would meet.
		if o.y > ground+FLOOR_UP and o.x < ground+top: return ["stone",0.0]
		if o.y < ground+FLOOR_UP and o.y > ground-FLOOR_DOWN: floor_y = maxf(floor_y,o.y)
	if floor_y == -INF: return ["void",ground]
	if absf(floor_y-ground) > climb: return ["stone",0.0]
	var foot := half*FOOT
	var x := -half
	while x <= half+0.01:
		var z := -half
		while z <= half+0.01:
			if x*x+z*z <= half*half+0.5:
				var under := false
				for isle: Dictionary in near:
					var o := LayerPlan.occ_at(isle,p.x+x,p.z+z)
					if o.x == INF: continue
					if o.y > floor_y+rise and o.x < floor_y+top: return ["stone",0.0]
					if o.y > floor_y-climb: under = true
				if not under and x*x+z*z <= foot*foot+0.1: return ["stone",0.0]
			z += half*0.5
		x += half*0.5
	return ["turf",floor_y]

static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x-b.x,a.z-b.z).length()

## A line for the card.
static func card(plan: Dictionary) -> String:
	var heads: Array = plan.get("heads",[])
	if heads.is_empty(): return ""
	var words := PackedStringArray()
	var bodies := int((plan.knobs as Dictionary).get("bodies",1)) != 0
	for h: Dictionary in heads:
		var cliffs: Array = h.get("cliffs",[])
		var body := ""
		if bodies: body = ", body up %d cliff%s" % [cliffs.size(),"" if cliffs.size() == 1 else "s"] if not cliffs.is_empty() else ", no body (no cliff reaches it)"
		words.append("%d %s%s%s" % [int(h.isle),str(h.on).replace("_"," "),", out over the void" if float(h.void) > 0.0 else "",body])
	return "Inhaler head%s: %s" % ["" if heads.size() == 1 else "s","; ".join(words)]

# --- On the stage -------------------------------------------------------------------

const VOICES := InhalerHead.VOICES

var study: Node3D
var field: Node
## The heads' bodies coming up their cliffs (scripts/enemies/
## body_spawner.gd), or null (`--knob=bodies=0`).
var spawner: Node = null
var _air_was: Callable
var _plane_was: Callable
var _voices := {}
## Olmec threat round 1: the roaming Olmec (`roams`), his director
## (scripts/roguelike/layer_olmec.gd) or null.
var roaming := false
var olmec: Node = null

## The plan's heads spawned into `stage`'s EnemyField, their air on the
## sail's wind and the plane's, their bodies' spawner; null where there are
## none.
static func dress(stage: Node3D, plan: Dictionary) -> Node:
	var heads: Array = plan.get("heads",[])
	if heads.is_empty() or stage.get("enemies") == null: return null
	var node := new()
	node.name = "LayerEnemies"
	stage.add_child(node)
	node.roaming = roams(plan.knobs)
	node.build(stage.study,stage.enemies,heads,int((plan.knobs as Dictionary).get("bodies",1)) != 0,float(plan.void_y),LayerBodies.spawn_rules(plan.knobs))
	# Olmec threat round 1: the roaming Olmec's director (his travel, his
	# weight on the isles, the masonry he breaks, the head-on beat).
	if node.roaming: node.olmec = LayerOlmec.dress(node,stage,plan)
	return node

func build(scene: Node3D, enemies: Node, heads: Array, bodies := true, void_y := -INF, spawn_rules := {}) -> void:
	study = scene
	field = enemies
	if not field.sound_hook.is_valid(): field.sound_hook = _voice
	for h: Dictionary in heads:
		var face: Vector3 = h.face
		var over := {"route":(h.route as Array).duplicate()}
		# A greybox motif's head keeps its study's knobs.
		over.merge(h.get("knobs",{}),false)
		field.spawn(InhalerHead,h.at,Vector2(face.x,face.z),over)
	if bodies:
		spawner = BodySpawner.new()
		add_child(spawner)
		spawner.setup(study,field,spawn_rules,LayerBodies.knobs(numbers(),roaming))
		# Under the void a body is gone (and its head's next comes up).
		spawner.lost_y = void_y
		for h: Dictionary in heads: spawner.add_head(h.at,h.get("cliffs",[]))
	var motor: Object = study.motor
	_air_was = motor.air
	var was := _air_was
	var me := self
	motor.air = func(p: Vector3) -> Dictionary:
		var here: Dictionary = was.call(p) if was.is_valid() else {}
		if not is_instance_valid(me): return here
		var wind := me._head_air(p,"sail_wind")
		if wind == Vector3.ZERO: return here
		var out := here.duplicate()
		out["wind"] = (here.get("wind",Vector3.ZERO) as Vector3)+wind
		return out
	if study.get("plane_air") is Callable:
		_plane_was = study.plane_air
		var plane_was := _plane_was
		study.plane_air = func(p: Vector3) -> Dictionary:
			var here: Dictionary = plane_was.call(p) if plane_was.is_valid() else {}
			if not is_instance_valid(me): return here
			var wind := me._head_air(p,"plane_wind")
			if wind == Vector3.ZERO: return here
			var out := here.duplicate()
			out["wind"] = (here.get("wind",Vector3.ZERO) as Vector3)+wind
			return out

func _exit_tree() -> void:
	if study == null: return
	if _air_was.is_valid(): study.motor.air = _air_was
	if _plane_was.is_valid(): study.plane_air = _plane_was

func _head_air(p: Vector3, how: String) -> Vector3:
	var sum := Vector3.ZERO
	if field == null: return sum
	for e in field.enemies:
		if is_instance_valid(e) and e.has_method(how): sum += e.call(how,p)
	return sum

## Ahead of the enemies' step: the bodies come up their cliffs.
func before(delta: float) -> void:
	# (The roaming Olmec first: a body falling away is his before the
	# spawner takes it under the void.)
	if olmec != null: olmec.before(delta)
	if spawner != null: spawner.step(delta)

## The camera placed: shaken by the bodies' landings.
func frame(camera: Camera3D, delta: float) -> void:
	if spawner != null: spawner.shake(camera)
	if olmec != null: olmec.frame(camera,delta)

## Whether a head holds him now (the stage hides the figure).
func holding() -> bool:
	if field == null: return false
	for e in field.enemies:
		if is_instance_valid(e) and e.get("swallowed"): return true
	return false

## Plays enemy sound `sound_name` at `at` (the study's placeholder synth).
func _voice(sound_name: StringName, at: Vector3) -> void:
	var key := String(sound_name)
	var spec: Variant = VOICES.get(key,BodySpawner.VOICES.get(key))
	if spec == null: return
	if not _voices.has(key): _voices[key] = EnemyYard._synth(spec)
	var player := AudioStreamPlayer3D.new()
	player.stream = _voices[key]
	player.position = at
	player.unit_size = float(BodySpawner.REACH.get(key,10.0))
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
