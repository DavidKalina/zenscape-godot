extends Node
## The layer's Millstone Beetles (docs/design/roguelike/beetle-round1.md,
## scripts/enemies/millstone_beetle.gd): 0 to 2 a layer, each on a lane of
## an isle's flat (a terrace, a causeway, a landing) that runs to a lip.
## A child of scripts/roguelike/layer_stage.gd (`dress`), stepped by its
## `before`; the feature `beetle` (scripts/roguelike/run_features.gd,
## `--no-beetle` off).
##
## Laying: from the plan, the isles' open spots (arena, perch, cover) as
## candidates, shuffled by the layer's seed, kept SPAWN_CLEAR of the spawn,
## GATE_CLEAR of the gate, RAM_CLEAR of the ram, HEAD_CLEAR of the heads,
## PRIZE_CLEAR of the rune perch (and of a greybox isle's own heads, which
## are in the plan's heads); one an isle. Standing (lazily, as the collectibles do: the isles
## stand a slice a frame, nearest first): when he comes within NEAR of a
## candidate its ground is read with rays (`_lane`): DIRS lines through the
## spot, each walked both ways in STEP m steps while the ground stays flat
## (no step over FLAT, no rise over RISE from the spot), wide enough for
## the beetle (WIDE to either side), with no wall at its middle's height,
## and over the isle's own solid (the plan's occupancy: never out onto a
## bridge). A line ends at a "lip" (no ground, or a drop) or a "wall".
## The best line LANE_LEAST m long at least, with a lip at one end at least
## (the void is the threat), both lips best, clipped to LANE_MOST by its
## lip; its patrol ends inset from them. One candidate a frame.
##
## Knobs: `--beetles=N` (RunFeatures.value: how many at most; else rolled
## from COUNT), `--wheel=<share>` (the wheel's size).
const RunFeatures = preload("res://scripts/roguelike/run_features.gd")
const LayerPlan = preload("res://scripts/roguelike/layer_plan.gd")
const Beetle = preload("res://scripts/enemies/millstone_beetle.gd")
const Voice = preload("res://scripts/enemies/beetle_voice.gd")

## The roll of how many a layer (each entry as likely).
const COUNT := [0,1,1,1,2,2,2]
const NEAR := 70.0
const SPAWN_CLEAR := 22.0
const GATE_CLEAR := 12.0
const RAM_CLEAR := 16.0
const HEAD_CLEAR := 16.0
const PRIZE_CLEAR := 6.0
const APART := 20.0
const LANE_LEAST := 8.0
const LANE_MOST := 16.0
const LANE_REACH := 22.0
const STEP := 0.5
const DIRS := 12
const FLAT := 0.22
const RISE := 0.6
const WIDE := 0.55
## Its patrol's ends this far in from a lip, a wall (m, past its half length).
const INSET_LIP := 0.8
const INSET_WALL := 0.3
## A candidate whose ground hasn't stood yet is tried again this many times.
const WAITS := 600

var stage: Node3D
var field: Node
var plan: Dictionary
var want := 0
var pending: Array = []
var laid: Array = []
var wheel := 1.0
var _rng := RandomNumberGenerator.new()

## The layer's beetles hung on `stage` (its EnemyField), or null (off).
static func dress(stage_node: Node3D, layer: Dictionary) -> Node:
	if not RunFeatures.on(&"beetle") or stage_node.get("enemies") == null: return null
	var node := new()
	node.name = "LayerBeetles"
	stage_node.add_child(node)
	node.setup(stage_node,layer)
	return node

func setup(stage_node: Node3D, layer: Dictionary) -> void:
	stage = stage_node
	field = stage.enemies
	plan = layer
	_rng.seed = hash([int(plan.get("seed",0)),"beetle"])
	want = int(COUNT[_rng.randi_range(0,COUNT.size()-1)])
	var asked := RunFeatures.value("beetles","")
	if asked != "": want = int(asked)
	wheel = float(RunFeatures.value("wheel","1.0"))
	pending = _candidates()
	# Their sounds beside whatever plays the field's.
	var was: Callable = field.sound_hook
	var host := stage
	field.sound_hook = func(sound_name: StringName, at: Vector3) -> void:
		if Voice.has(String(sound_name)): Voice.play(host,String(sound_name),at)
		elif was.is_valid(): was.call(sound_name,at)

## The open spots it may stand on, shuffled.
func _candidates() -> Array:
	var out: Array = []
	var isles: Array = plan.get("isles",[])
	var spawn: Vector3 = (plan.get("spawn",{}) as Dictionary).get("at",Vector3.INF)
	var gate: Vector3 = (plan.get("exit",{}) as Dictionary).get("at",Vector3.INF)
	var ram: Vector3 = (plan.get("ram",{}) as Dictionary).get("at",Vector3.INF)
	var prize: Vector3 = (plan.get("prize",{}) as Dictionary).get("at",Vector3.INF)
	for i in range(isles.size()):
		var isle: Dictionary = isles[i]
		for s: Dictionary in isle.get("sockets",[]):
			if not str(s.get("kind","")) in ["arena","perch","cover"]: continue
			var at: Vector3 = s.at
			if _near(at,spawn,SPAWN_CLEAR) or _near(at,gate,GATE_CLEAR) or _near(at,ram,RAM_CLEAR) or _near(at,prize,PRIZE_CLEAR): continue
			var by_head := false
			for h: Dictionary in plan.get("heads",[]):
				if _near(at,h.at,HEAD_CLEAR): by_head = true
			if by_head: continue
			out.append({"isle":i,"at":at,"waits":0})
	# Shuffled by the seed (Fisher-Yates on our own rng).
	for k in range(out.size()-1,0,-1):
		var j := _rng.randi_range(0,k)
		var tmp: Variant = out[k]
		out[k] = out[j]
		out[j] = tmp
	return out

static func _near(a: Vector3, b: Vector3, most: float) -> bool:
	return b != Vector3.INF and Vector2(a.x-b.x,a.z-b.z).length() < most

## One candidate a frame: the first pending within NEAR of him read for a lane.
func before(_delta: float) -> void:
	if laid.size() >= want or pending.is_empty(): return
	var feet: Vector3 = stage.study.motor.feet
	for k in range(pending.size()):
		var c: Dictionary = pending[k]
		if not _near(c.at,feet,NEAR): continue
		var lane := _lane(c)
		if lane.get("wait",false):
			c.waits = int(c.waits)+1
			if int(c.waits) > WAITS: pending.remove_at(k)
			return
		pending.remove_at(k)
		if lane.is_empty(): return
		_stand(c,lane)
		return

func _stand(c: Dictionary, lane: Dictionary) -> void:
	var a: Vector3 = lane.a
	var b: Vector3 = lane.b
	# Starts somewhere along it, going toward the lip end.
	var at := a.lerp(b,_rng.randf_range(0.25,0.75))
	var to: Vector3 = b if bool(lane.lip_b) else a
	var face := Vector2(to.x-at.x,to.z-at.z).normalized()
	field.spawn(Beetle,at,face,{"lane_a":a,"lane_b":b,"wheel":wheel})
	laid.append({"isle":c.isle,"a":a,"b":b,"lips":int(lane.lips)})
	# Every other candidate on that isle or near it is let go.
	pending = pending.filter(func(p: Dictionary) -> bool: return int(p.isle) != int(c.isle) and not _near(p.at,at,APART))
	print("beetle: on isle %d, a lane %.1f m, %d lip%s" % [int(c.isle),a.distance_to(b),int(lane.lips),"" if int(lane.lips) == 1 else "s"])

## The best lane through candidate `c`'s spot, {} for none, {wait} if its
## ground hasn't stood yet.
func _lane(c: Dictionary) -> Dictionary:
	var spot: Vector3 = c.at
	var g0: float = field.floor_under(spot,3.0,4.0)
	if g0 == -INF: return {"wait":true}
	var base := Vector3(spot.x,g0,spot.z)
	var isle: Dictionary = plan.isles[int(c.isle)] if int(c.isle) < (plan.get("isles",[]) as Array).size() else {}
	var half := _half_length()
	var best := {}
	var best_score := -INF
	var turn := _rng.randf()*PI
	for k in range(DIRS):
		var q := turn+PI*float(k)/DIRS
		var dir := Vector2(cos(q),sin(q))
		var fwd := _run(base,dir,isle)
		var back := _run(base,-dir,isle)
		var total: float = float(fwd[0])+float(back[0])
		if total < LANE_LEAST: continue
		var lip_b: bool = fwd[1] == "lip"
		var lip_a: bool = back[1] == "lip"
		var lips := int(lip_a)+int(lip_b)
		if lips == 0: continue
		var score := minf(total,LANE_MOST)+5.0*lips+_rng.randf()
		if score <= best_score: continue
		var b_end := base+Vector3(dir.x,0.0,dir.y)*float(fwd[0])
		var a_end := base-Vector3(dir.x,0.0,dir.y)*float(back[0])
		# Clipped by its lip end (the lip kept).
		if total > LANE_MOST:
			if lip_b: a_end = b_end-Vector3(dir.x,0.0,dir.y)*LANE_MOST
			else: b_end = a_end+Vector3(dir.x,0.0,dir.y)*LANE_MOST
			if lip_b and lip_a: lip_a = false
		var ia := half+(INSET_LIP if lip_a else INSET_WALL)
		var ib := half+(INSET_LIP if lip_b else INSET_WALL)
		var a_in := a_end+Vector3(dir.x,0.0,dir.y)*ia
		var b_in := b_end-Vector3(dir.x,0.0,dir.y)*ib
		if a_in.distance_to(b_in) < LANE_LEAST*0.5: continue
		best_score = score
		best = {"a":a_in,"b":b_in,"lip_a":lip_a,"lip_b":lip_b,"lips":int(lip_a)+int(lip_b)}
	return best

## A beetle's half length with its wheel (its middle's way in from a lane's end).
func _half_length() -> float:
	var n: Dictionary = field.numbers()
	var d: float = float(n.jump)*wheel
	return (d+d*1.25-d*0.12)*0.5

## Walked from `base` along `dir` in STEP steps: [how far it stays a lane, "lip" | "wall"].
func _run(base: Vector3, dir: Vector2, isle: Dictionary) -> Array:
	var prev := base.y
	var s := STEP
	var side := Vector3(-dir.y,0.0,dir.x)
	while s <= LANE_REACH:
		var p := base+Vector3(dir.x,0.0,dir.y)*s
		p.y = prev
		# Off the isle's own solid (onto a bridge, a stone): its end.
		if not isle.is_empty() and LayerPlan.occ_at(isle,p.x,p.z).x == INF:
			return [s-STEP,"lip"]
		if field.blocked(p-Vector3(dir.x,0.0,dir.y)*STEP+Vector3.UP*0.55,Vector3(dir.x,0.0,dir.y)*STEP):
			return [s-STEP,"wall"]
		var g: float = field.floor_under(p,0.5,1.2)
		if g == -INF or g < prev-0.5: return [s-STEP,"lip"]
		if absf(g-prev) > FLAT or absf(g-base.y) > RISE: return [s-STEP,"wall"]
		for w: float in [-WIDE,WIDE]:
			var gs: float = field.floor_under(p+side*w+Vector3(0.0,g-p.y,0.0),0.4,0.6)
			if gs == -INF or absf(gs-g) > FLAT*1.5: return [s-STEP,"wall"]
		prev = g
		s += STEP
	return [s-STEP,"wall"]
