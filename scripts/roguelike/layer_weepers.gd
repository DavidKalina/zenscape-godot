extends RefCounted
## The Weepers of a generated layer (scripts/enemies/weeper.gd, docs/design/
## roguelike/weeper-round1.md), the game-feel round's `weeper` feature
## (scripts/roguelike/run_features.gd; `--no-weeper` turns it off).
##
## Laid from a mid layer on (the run's REGION_FROM-th region on): COUNTS
## weighs how many (0 to 2) by the region. Each on an isle's open socket
## (arena, perch or cover, ROOM round at least), off the base, CLEAR of the
## spawn (out past his first look round), GATE_CLEAR of the gate, OTHERS_CLEAR
## of the ram and the heads; two never on one isle and APART at least.
## Facing the way he comes (the spawn). Data only (`lay`), then spawned into
## the stage's EnemyField (`dress`), which steps them and brings them back on
## a reset; each stands once the ground under it has (its isle stood).
##
## `--weepers=N` lays N on any region (play and test knob).
const LayerWorlds = preload("res://scripts/roguelike/layer_worlds.gd")
const RunFeatures = preload("res://scripts/roguelike/run_features.gd")
const Weeper = preload("res://scripts/enemies/weeper.gd")

const REGION_FROM := 2
## How many, by region: [chance of 0, of 1, of 2]; past the last, the last.
const COUNTS := [[0.3,0.5,0.2],[0.1,0.5,0.4]]
const ROOM := 1.5
const CLEAR := 26.0
const GATE_CLEAR := 12.0
const OTHERS_CLEAR := 12.0
const APART := 24.0
const KINDS := ["arena","perch","cover"]

## The Weepers for `plan`: [{at, face, isle, on}].
static func lay(plan: Dictionary) -> Array:
	if not RunFeatures.on(&"weeper"): return []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(plan.get("seed",0)),LayerWorlds.region_of(plan),"weepers"])
	var forced := RunFeatures.value("weepers","")
	var n := 0
	if forced != "": n = maxi(int(forced),0)
	else:
		var region := LayerWorlds.region_of(plan)
		if region < REGION_FROM: return []
		var w: Array = COUNTS[mini(region-REGION_FROM,COUNTS.size()-1)]
		var roll := rng.randf()
		n = 0 if roll < float(w[0]) else (1 if roll < float(w[0])+float(w[1]) else 2)
	if n == 0: return []
	var spawn: Vector3 = (plan.get("spawn",{}) as Dictionary).get("at",Vector3.INF)
	var gate: Vector3 = (plan.get("exit",{}) as Dictionary).get("at",Vector3.INF)
	var others: Array = []
	if not (plan.get("ram",{}) as Dictionary).is_empty(): others.append(plan.ram.at)
	for h: Dictionary in plan.get("heads",[]): others.append(h.at)
	var cands: Array = []
	var isles: Array = plan.get("isles",[])
	for i in range(isles.size()):
		var isle: Dictionary = isles[i]
		if str(isle.get("role","")) == "base" and forced == "": continue
		for s: Dictionary in isle.get("sockets",[]):
			if not KINDS.has(str(s.kind)) or float(s.get("room",0.0)) < ROOM: continue
			var at: Vector3 = s.at
			if spawn != Vector3.INF and _flat(at,spawn) < CLEAR: continue
			if gate != Vector3.INF and _flat(at,gate) < GATE_CLEAR: continue
			var near := false
			for o: Vector3 in others: near = near or _flat(at,o) < OTHERS_CLEAR
			if near: continue
			cands.append({"at":at,"isle":i,"on":"%s (%s)" % [isle.get("id",i),s.get("name","")]})
	# Shuffled by the layer's own roll.
	for k in range(cands.size()-1,0,-1):
		var j := rng.randi_range(0,k)
		var t: Variant = cands[k]
		cands[k] = cands[j]
		cands[j] = t
	var out: Array = []
	for c: Dictionary in cands:
		if out.size() >= n: break
		var ok := true
		for o: Dictionary in out: ok = ok and int(o.isle) != int(c.isle) and _flat(o.at,c.at) >= APART
		if not ok: continue
		var face := Vector3.FORWARD
		if spawn != Vector3.INF: face = Vector3(spawn.x-c.at.x,0.0,spawn.z-c.at.z).normalized()
		c.face = face
		out.append(c)
	return out

## The plan's Weepers spawned into `stage`'s EnemyField; how many.
static func dress(stage: Node3D, plan: Dictionary) -> int:
	var laid := lay(plan)
	plan["weepers"] = laid
	if laid.is_empty() or stage.get("enemies") == null: return 0
	var k := 0
	for w: Dictionary in laid:
		var face: Vector3 = w.face
		stage.enemies.spawn(Weeper,w.at,Vector2(face.x,face.z),{"seed":int(plan.get("seed",0))+k})
		k += 1
	return laid.size()

## A line for the card.
static func card(plan: Dictionary) -> String:
	var laid: Array = plan.get("weepers",[])
	if laid.is_empty(): return ""
	var words := PackedStringArray()
	for w: Dictionary in laid: words.append(str(w.on).replace("_"," "))
	return "Weeper%s: %s" % ["" if laid.size() == 1 else "s","; ".join(words)]

static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x-b.x,a.z-b.z).length()
