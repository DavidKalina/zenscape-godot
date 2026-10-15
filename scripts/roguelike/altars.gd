extends Node3D
## Where items are found (docs/design/roguelike/altars-round1.md): feature
## `altars` (RunFeatures). A child of the layer stage, laid on the plan once
## the run knows its depth, stood near him like the collectibles.
##
## - **Pedestals** (1-2 a layer): a carved plinth holding an item drawn at
##   random from the catalog, in a risky spot (the collectibles' rare and
##   risk spots, perches, covers). Walk into one to take it.
## - **The cursed altar** (one a layer, from the second): offers a better
##   item for a HEART. Press Jump beside it. A last heart is refused (the
##   altar will not take your life) unless `--altar-lethal=on`.
## - **The key** (layer 1 until found, then again only if it is lost): lies in
##   a risky spot. Carry it (a brass key bobs over his head): HURT and it
##   falls from his hand to where he stood and tumbles down; take it up again
##   (walk into it, after a breath) before it goes over an edge, or leave it
##   behind when the gate takes you and it is lost for good: a fresh one is
##   laid on the next layer.
## - **The vault** (from layer 2, until opened): a locked stone reliquary.
##   Press Jump beside it with the key: the door sinks and a rare item (rarity
##   2-3) is yours.
##
## `--altars=all` lays all four on the first layer (play and test knob);
## `--altar-lethal=on` lets the altar take a last heart.
const RunFeatures = preload("res://scripts/roguelike/run_features.gd")
const RunState = preload("res://scripts/roguelike/run_state.gd")
const ItemCatalog = preload("res://scripts/roguelike/item_catalog.gd")
const ItemPickup = preload("res://scripts/roguelike/item_pickup.gd")
const Collectibles = preload("res://scripts/roguelike/collectibles.gd")
const Stone = preload("res://scripts/city_kit_stone.gd")
const PadPrompt = preload("res://scripts/pad_prompt.gd")

const KEY := &"vault_key"
## Stood within NEAR m (flat); a spot with no ground is tried again after RETRY s.
const NEAR := 70.0
const RETRY := 0.5
## How near (m, flat) to press at an altar or a vault.
const PRESS := 1.9
## The key lies this long (s) after a drop before he may take it up again.
const DROP_WAIT := 1.2
const GRAVITY := 16.0
## Spot kinds, by how risky they are (a spot's draw weight).
const RISK := {"rare":5.0,"rune_risk":4.0,"perch":3.0,"cover":2.0,"arena":1.5}

## What the run has done, across layers (reset for each new run).
static var _s := {"id":"","key_found":false,"key_lost":false,"vault_open":false}

var study: Node3D
var plan: Dictionary
## Everything laid: {kind (pedestal|altar|key|vault), at, isle, name, state
## (pending|live|taken|dropped), node, ...}.
var ents: Array = []
var laid := false
var _clock := 0.0
var _held := {}
var _prompt: Label
var _key_node: Node3D = null
var _drops: Array = []
var _ray := PhysicsRayQueryParameters3D.new()
var _wired := false
var _near_before: Dictionary = {}

static func dress(stage: Node3D, layer: Dictionary) -> Node3D:
	if not RunFeatures.on(&"altars"): return null
	var node: Node3D = (load("res://scripts/roguelike/altars.gd") as GDScript).new()
	stage.add_child(node)
	node.study = stage.study
	node.plan = layer
	return node

func _init() -> void:
	name = "Altars"

# --- Laying (data) ------------------------------------------------------------------

## What to lay on a layer at run depth `depth`: [{kind, at, isle, name}].
## `all`: everything (a test). Candidate spots weighted by risk, a different
## isle for each where there are enough.
static func lay(layer: Dictionary, depth: int, rng: RandomNumberGenerator, all := false, s := _s) -> Array:
	var want: Array = []
	if all:
		want = ["pedestal","key","altar","vault"]
	else:
		want.append("pedestal")
		if rng.randf() < 0.5: want.append("pedestal")
		if (not bool(s.key_found) and not bool(s.vault_open) and depth <= 3) or bool(s.key_lost): want.append("key")
		if depth >= 2 and not bool(s.vault_open): want.append("vault")
		if depth >= 2: want.append("altar")
	var cands := _candidates(layer)
	var out: Array = []
	var used_isles := {}
	# The riskiest spots to the key and the first pedestal, the rest after.
	want.sort_custom(func(a: String, b: String) -> bool: return _order(a) < _order(b))
	for k in want:
		var pick := _pick(cands,used_isles,rng,k == "vault")
		if pick.is_empty(): continue
		cands.erase(pick)
		used_isles[pick.isle] = true
		# Backups, tried in turn if the spot has no room to stand it.
		var alts: Array = []
		var pool := cands.duplicate()
		for _b in range(3):
			var alt := _pick(pool,{},rng,k == "vault")
			if alt.is_empty(): break
			pool.erase(alt)
			alts.append(alt)
		out.append({"kind":k,"at":pick.at,"isle":pick.isle,"name":"%s_%d" % [k,out.size()],"src":pick.kind,"alts":alts})
	return out

static func _order(k: String) -> int:
	return {"key":0,"pedestal":1,"altar":2,"vault":3}.get(k,4)

## Every spot an item could stand at: off the start isle, with a risk weight.
static func _candidates(layer: Dictionary) -> Array:
	var out: Array = []
	var isles: Array = layer.get("isles",[])
	for i in range(isles.size()):
		var isle: Dictionary = isles[i]
		if str(isle.get("role","")) == "base": continue
		var seen := {}
		for s: Dictionary in Collectibles.spots_of(isle):
			var kind := str(s.kind)
			if not RISK.has(kind): continue
			if kind in ["perch","cover"] and float(s.get("room",1.0)) < 1.6: continue
			seen[(s.at as Vector3).snapped(Vector3.ONE*0.5)] = true
			out.append({"at":s.at,"isle":i,"kind":kind,"weight":RISK[kind]})
		for s: Dictionary in isle.get("sockets",[]):
			var kind := str(s.get("kind",""))
			if not RISK.has(kind) or float(s.get("room",1.0)) < 1.8: continue
			if seen.has((s.at as Vector3).snapped(Vector3.ONE*0.5)): continue
			out.append({"at":s.at,"isle":i,"kind":kind,"weight":RISK[kind]*0.8})
	return out

static func _pick(cands: Array, used: Dictionary, rng: RandomNumberGenerator, gentle: bool) -> Dictionary:
	if cands.is_empty(): return {}
	var total := 0.0
	var ws: Array = []
	for c: Dictionary in cands:
		var w := float(c.weight)
		if gentle: w = 1.0/w
		if used.has(c.isle): w *= 0.15
		ws.append(w)
		total += w
	var roll := rng.randf()*total
	for k in range(cands.size()):
		roll -= float(ws[k])
		if roll <= 0.0: return cands[k]
	return cands[-1]

static func tally(laid_list: Array) -> Dictionary:
	var out := {}
	for e: Dictionary in laid_list: out[e.kind] = int(out.get(e.kind,0))+1
	return out

# --- The run's memory -----------------------------------------------------------------

static func _sync(run: Object) -> void:
	var id := "%s|%s" % [run.get("runs"),run.get("run_seed")]
	if _s.id != id:
		_s = {"id":id,"key_found":false,"key_lost":false,"vault_open":false}

# --- On the stage -----------------------------------------------------------------------

func _ready() -> void:
	_ray.hit_from_inside = false

func _loop() -> Node:
	return study.get("run_loop") if study != null else null

func _run() -> Object:
	return RunState.current

func _process(delta: float) -> void:
	if study == null or study.get("motor") == null: return
	var loop := _loop()
	var run := _run()
	if run == null or loop == null: return
	_clock += delta
	if not laid:
		if study.get("stage") != get_parent() or String(loop.get("pending")) != "": return
		if not (String(loop.get("state")) in ["play","arrive"]) or int(run.get("depth")) < 1: return
		_lay_now(run)
	if String(loop.get("state")) not in ["play","arrive"]: return
	var motor: Variant = study.motor
	var feet: Vector3 = motor.feet
	_wire(motor)
	_stand_near(feet)
	_keyhold(run)
	_drops_step(delta,run)
	var press := _edge(&"walk_jump")
	var text := ["",""]
	var near_now: Dictionary = {}
	for e: Dictionary in ents:
		if e.state != "live": continue
		var node: Node3D = e.node
		if not is_instance_valid(node): continue
		match e.kind:
			"pedestal":
				if (node as ItemPickup).within(feet): _take(e,run)
			"altar":
				if _near(node,feet,motor):
					text = _altar_prompt(e,run,motor)
					near_now = e
			"vault":
				if _near(node,feet,motor):
					text = _vault_prompt(run)
					near_now = e
			"key":
				if (e.get("pick") as ItemPickup).within(feet): _take_key(e,run)
	# The press acts on what he stood beside the frame before (the jump that
	# the press is has already lifted him when this runs).
	if press and not _near_before.is_empty() and _near_before.state == "live":
		if _near_before.kind == "altar": _bargain(_near_before,run,motor)
		elif _near_before.kind == "vault": _unlock(_near_before,run)
	_near_before = near_now
	_show_prompt(text)

func _lay_now(run: Object) -> void:
	laid = true
	_sync(run)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(plan.get("seed",0)),"altars"])
	var all := RunFeatures.value("altars") == "all"
	for d: Dictionary in lay(plan,int(run.get("depth")),rng,all):
		d.state = "pending"
		d.retry_at = 0.0
		ents.append(d)

func _wire(motor: Object) -> void:
	if _wired: return
	_wired = true
	motor.connect(&"harmed",_on_harmed.bind(motor))

func _edge(action: StringName) -> bool:
	var down := Input.is_action_pressed(action)
	var was: bool = _held.get(action,false)
	_held[action] = down
	return down and not was

func _near(node: Node3D, feet: Vector3, motor: Variant) -> bool:
	var d := Vector2(node.global_position.x-feet.x,node.global_position.z-feet.z).length()
	return d < PRESS and bool(motor.grounded) and absf(feet.y-node.global_position.y) < 1.4

# --- Standing ---------------------------------------------------------------------------

func _stand_near(me: Vector3) -> void:
	for e: Dictionary in ents:
		if e.state != "pending" or float(e.retry_at) > _clock: continue
		var at: Vector3 = e.at
		if Vector2(at.x-me.x,at.z-me.z).length() > NEAR: continue
		var ground := _find_ground(e)
		if ground.is_empty():
			if not _isles_up(): e.retry_at = _clock+RETRY
			elif not (e.alts as Array).is_empty():
				# No room there: the next spot.
				var next: Dictionary = (e.alts as Array).pop_front()
				e.at = next.at
				e.isle = next.isle
				e.src = next.kind
			else: e.state = "dropped"
			continue
		_stand(e,ground.at)

## The ground near the spot: tried at the spot's side first (so a rare on the
## spot itself is not stood on), then the spot.
func _find_ground(e: Dictionary) -> Dictionary:
	var at: Vector3 = e.at
	var side := 1.9 if e.kind != "key" else 1.3
	for off: Vector3 in [Vector3(side,0,0),Vector3(-side,0,0),Vector3(0,0,side),Vector3(0,0,-side),Vector3.ZERO]:
		var p := at+off
		var y := _ground_under(p)
		if y != INF and absf(y-at.y) < 1.5:
			# Room to stand and walk up to it: level ground all round.
			var ok := true
			var ring := 0.6 if e.kind == "key" else 1.2
			for k in range(8):
				var q := Vector3(cos(TAU*k/8.0),0,sin(TAU*k/8.0))*ring
				var yy := _ground_under(p+q)
				if yy == INF or absf(yy-y) > 0.4: ok = false
			if ok: return {"at":Vector3(p.x,y,p.z)}
	return {}

func _ground_under(p: Vector3) -> float:
	var g: Variant = study.get("ground")
	var mask := 1
	if g != null and g.get("mask") != null: mask = int(g.mask)
	_ray.from = p+Vector3.UP*1.0
	_ray.to = p-Vector3.UP*2.5
	_ray.collision_mask = mask
	var hit := get_world_3d().direct_space_state.intersect_ray(_ray)
	return INF if hit.is_empty() else (hit.position as Vector3).y

func _isles_up() -> bool:
	var sky: Variant = study.get("sky")
	if not (sky is Object): return true
	var motifs: Variant = (sky as Object).get("motifs")
	if not (motifs is Object) or not (motifs as Object).has_method("all_stood"): return true
	return bool((motifs as Object).call("all_stood"))

func _stand(e: Dictionary, at: Vector3) -> void:
	var run := _run()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(plan.get("seed",0)),e.name])
	var yaw := rng.randf()*TAU
	e.state = "live"
	match str(e.kind):
		"pedestal":
			var id := _draw(rng,run,false,e)
			if id == &"":
				e.state = "dropped"
				return
			e.item = id
			var p: Node3D = ItemPickup.make(id,true,hash(e.name))
			add_child(p)
			p.global_position = at
			p.rotation.y = yaw
			e.node = p
		"key":
			var p: Node3D = ItemPickup.make(KEY,false,hash(e.name))
			add_child(p)
			p.global_position = at
			e.node = p
			e.pick = p
		"altar":
			var id := _draw(rng,run,true,e)
			if id == &"":
				e.state = "dropped"
				return
			e.item = id
			var a := Node3D.new()
			a.name = "Altar"
			add_child(a)
			a.global_position = at
			a.rotation.y = yaw
			_altar_body(a,hash(e.name))
			var p: Node3D = ItemPickup.make(id,false,hash(e.name),1.0)
			p.ready_in = 1.0e9
			a.add_child(p)
			e.node = a
			e.pick = p
		"vault":
			var v := Node3D.new()
			v.name = "Vault"
			add_child(v)
			v.global_position = at
			v.rotation.y = yaw
			_vault_body(v,e,hash(e.name))
			e.node = v

## An item for a pedestal / the altar / the vault: drawn now from the
## catalog (it grows with the round), none of those already laid here.
func _draw(rng: RandomNumberGenerator, run: Object, better: bool, e: Dictionary) -> StringName:
	var pool: Array[StringName] = []
	for id in ItemCatalog.ids():
		if String(ItemCatalog.info(id).get("kind","")) == "key": continue
		if better and int(ItemCatalog.info(id).get("rarity",1)) < 2 and String(ItemCatalog.info(id).get("kind","")) != "cursed": continue
		pool.append(id)
	for o: Dictionary in ents:
		if o != e and o.has("item") and o.item in pool and pool.size() > 1: pool.erase(o.item)
	var id := ItemCatalog.draw(rng,pool,run)
	if id == &"" and better: id = ItemCatalog.draw(rng,[] as Array[StringName],run)
	return id

# --- Bodies ---------------------------------------------------------------------------------

func _altar_body(host: Node3D, seed_value: int) -> void:
	var m := Stone.Mesher.new(Stone.stone_colour(),0.25)
	m.solid(Stone.box(Transform3D(Basis(),Vector3(0,0.2,0)),Vector3(0.8,0.2,0.5),0.05))
	m.solid(Stone.box(Transform3D(Basis(),Vector3(0,0.5,0)),Vector3(0.62,0.1,0.38),0.04))
	# A bowl's rim on top, where the heart is laid.
	m.solid(Stone.drum(Transform3D(Basis(),Vector3(0,0.6,0)),8,0.26,0.22,0.1,0.02))
	m.runes(Vector3(-0.5,0.08,0.505),Vector3(0.5,0.08,0.505),Vector3.UP,Vector3(0,0,1),float(seed_value),0.2)
	var mi := MeshInstance3D.new()
	mi.mesh = Stone.mesh_of(m,"fire")
	host.add_child(mi)
	# A dull, dim glow in the bowl: not an ember, a cold gleam.
	var lamp := OmniLight3D.new()
	lamp.light_color = Color("a99cb8")
	lamp.light_energy = 0.4
	lamp.omni_range = 3.0
	lamp.position = Vector3(0,0.9,0)
	lamp.shadow_enabled = false
	host.add_child(lamp)

func _vault_body(host: Node3D, e: Dictionary, seed_value: int) -> void:
	var m := Stone.Mesher.new(Stone.stone_colour(),0.3)
	m.solid(Stone.box(Transform3D(Basis(),Vector3(0,0.1,0)),Vector3(0.78,0.1,0.62),0.04))
	m.solid(Stone.box(Transform3D(Basis(),Vector3(0,0.85,0)),Vector3(0.6,0.75,0.5),0.06))
	m.solid(Stone.box(Transform3D(Basis(),Vector3(0,1.66,0)),Vector3(0.7,0.08,0.58),0.04))
	m.runes(Vector3(-0.5,1.45,0.505),Vector3(0.5,1.45,0.505),Vector3.UP,Vector3(0,0,1),float(seed_value),0.16)
	var mi := MeshInstance3D.new()
	mi.mesh = Stone.mesh_of(m,"refuge")
	host.add_child(mi)
	# The door: a brass-banded slab over the front, a keyhole's gleam.
	var door := MeshInstance3D.new()
	door.name = "Door"
	var bx := BoxMesh.new()
	bx.size = Vector3(0.8,1.1,0.08)
	door.mesh = bx
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color("5a4a2c")
	dm.metallic = 0.75
	dm.roughness = 0.5
	dm.emission_enabled = true
	dm.emission = Color("c9a24a")
	dm.emission_energy_multiplier = 0.18
	door.material_override = dm
	door.position = Vector3(0,0.78,0.54)
	host.add_child(door)
	var lock := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.07
	sp.height = 0.14
	lock.mesh = sp
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color("e0b45e")
	lm.emission_enabled = true
	lm.emission = Color("e0b45e")
	lm.emission_energy_multiplier = 1.4
	lock.material_override = lm
	lock.position = Vector3(0,0.85,0.6)
	host.add_child(lock)
	var lamp := OmniLight3D.new()
	lamp.name = "Lamp"
	lamp.light_color = Color("e0b45e")
	lamp.light_energy = 0.5
	lamp.omni_range = 3.5
	lamp.position = Vector3(0,1.0,1.0)
	lamp.shadow_enabled = false
	host.add_child(lamp)
	e.door = door

# --- Taking ---------------------------------------------------------------------------------

func _say(title: String, line: String) -> void:
	var loop := _loop()
	if loop != null and loop.get("overlay") != null: loop.overlay.show_caption(title,line)

func _take(e: Dictionary, run: Object) -> void:
	e.state = "taken"
	(e.node as ItemPickup).take(run)

func _take_key(e: Dictionary, run: Object) -> void:
	e.state = "taken"
	_s.key_found = true
	_s.key_lost = false
	(e.node as ItemPickup).take(run)

func _altar_prompt(e: Dictionary, run: Object, motor: Object) -> Array:
	var name := ItemCatalog.title(e.item)
	var hearts := int(run.hearts_of(motor))
	if hearts <= 1 and RunFeatures.value("altar-lethal") != "on":
		return ["The altar will not take your last heart","The altar will not take your last heart"]
	return ["Space  give a heart for %s" % name,"{walk_jump}  give a heart for %s" % name]

func _bargain(e: Dictionary, run: Object, motor: Object) -> void:
	var hearts := int(run.hearts_of(motor))
	if hearts <= 1 and RunFeatures.value("altar-lethal") != "on":
		_say("It will not take your last","Come back with a heart to spare")
		return
	e.state = "taken"
	# The heart goes the way every harm does (the run loop hears it: the
	# flash, the corner, and at none the end of the run).
	var loop := _loop()
	loop._harmed(1,"altar",null,motor)
	(e.pick as ItemPickup).take(run)
	var lamp := (e.node as Node3D).get_node_or_null("OmniLight3D") as OmniLight3D
	if lamp != null: lamp.light_energy = 0.05

func _vault_prompt(run: Object) -> Array:
	if run.carrying(KEY): return ["Space  unlock the vault","{walk_jump}  unlock the vault"]
	return ["A locked vault. Its key lies on the way up","A locked vault. Its key lies on the way up"]

func _unlock(e: Dictionary, run: Object) -> void:
	if not run.carrying(KEY):
		_say("Locked","The key is somewhere on the way up")
		return
	e.state = "taken"
	run.drop_item(KEY)
	_s.vault_open = true
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(plan.get("seed",0)),"vault"])
	var pool: Array[StringName] = []
	for id in ItemCatalog.ids():
		if String(ItemCatalog.info(id).get("kind","")) == "key": continue
		if int(ItemCatalog.info(id).get("rarity",1)) >= 2: pool.append(id)
	var id := ItemCatalog.draw(rng,pool,run)
	if id == &"": id = ItemCatalog.draw(rng,[] as Array[StringName],run)
	var host: Node3D = e.node
	var door: MeshInstance3D = e.door
	var t := create_tween()
	t.tween_property(door,"position:y",-0.7,0.7).set_ease(Tween.EASE_IN)
	var lamp := host.get_node("Lamp") as OmniLight3D
	t.parallel().tween_property(lamp,"light_energy",2.2,0.7)
	if id == &"":
		_say("The vault is empty","dust, and a hollow")
		return
	var p: Node3D = ItemPickup.make(id,false,hash("v"+str(id)),1.3)
	p.ready_in = 1.0e9
	host.add_child(p)
	p.position = Vector3(0,1.0,0.0)
	t.tween_interval(0.25)
	t.tween_callback(func() -> void:
		if is_instance_valid(p): p.take(run))

# --- The key in hand ----------------------------------------------------------------------

## A brass key bobs over his head while he carries it.
func _keyhold(run: Object) -> void:
	var fig: Variant = study.get("figure")
	if not (fig is Node3D): return
	var has: bool = run.carrying(KEY)
	if has and (_key_node == null or not is_instance_valid(_key_node)):
		_key_node = ItemPickup.make(KEY,false,3)
		(_key_node as ItemPickup).bare()
		(fig as Node3D).add_child(_key_node)
		_key_node.position = Vector3(0.0,1.35,0.0)
	elif not has and _key_node != null:
		if is_instance_valid(_key_node): _key_node.queue_free()
		_key_node = null

func _on_harmed(amount: int, cause: String, _src: Object, motor: Object) -> void:
	var run := _run()
	if run == null or amount <= 0 or cause == "altar" or not run.carrying(KEY): return
	# Only a hit that counted (the run loop heard it first).
	if run.safe_for(motor) < 1.0: return
	run.drop_item(KEY)
	var feet: Vector3 = motor.feet
	var p: Node3D = ItemPickup.make(KEY,false,7)
	add_child(p)
	p.global_position = feet+Vector3.UP*0.9
	p.ready_in = DROP_WAIT
	var heading := Vector3(randf_range(-1.0,1.0),0.0,randf_range(-1.0,1.0)).normalized()*2.2
	var d := {"node":p,"vel":Vector3(heading.x,4.5,heading.z),"landed":false}
	_drops.append(d)
	_say("The key slips from your hand","take it up before it goes over")

func _drops_step(delta: float, run: Object) -> void:
	var feet: Vector3 = study.motor.feet
	var void_y := float(plan.get("void_y",-1000.0))
	for k in range(_drops.size()-1,-1,-1):
		var d: Dictionary = _drops[k]
		var p: ItemPickup = d.node
		if not is_instance_valid(p):
			_drops.remove_at(k)
			continue
		if not d.landed:
			var v: Vector3 = d.vel
			v.y -= GRAVITY*delta
			var from := p.global_position
			var to := from+v*delta
			_ray.from = from+Vector3.UP*0.2
			_ray.to = to-Vector3.UP*0.25
			var g: Variant = study.get("ground")
			_ray.collision_mask = int(g.mask) if g != null and g.get("mask") != null else 1
			var hit := get_world_3d().direct_space_state.intersect_ray(_ray)
			if not hit.is_empty() and v.y < 0.0:
				p.global_position = hit.position
				d.landed = true
			else:
				p.global_position = to
			d.vel = v
			if p.global_position.y < void_y+30.0 and not d.landed and to.y < feet.y-40.0:
				# Gone over the edge.
				_s.key_lost = true
				_say("The key is gone","a fresh one lies somewhere above")
				p.queue_free()
				_drops.remove_at(k)
				continue
		elif p.within(feet):
			p.take(run)
			_s.key_found = true
			_s.key_lost = false
			_drops.remove_at(k)

func _exit_tree() -> void:
	# A key left lying when the layer goes is lost for good.
	for d: Dictionary in _drops:
		if is_instance_valid(d.node): _s.key_lost = true

# --- The prompt ---------------------------------------------------------------------------

func _show_prompt(lines: Array) -> void:
	if _prompt == null:
		var layer := CanvasLayer.new()
		layer.layer = 6
		add_child(layer)
		_prompt = PadPrompt.new()
		_prompt.add_theme_font_size_override("font_size",16)
		_prompt.add_theme_color_override("font_color",Color("fbf6ea"))
		_prompt.add_theme_color_override("font_shadow_color",Color(0,0,0,0.55))
		_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		_prompt.offset_top = -140.0
		_prompt.offset_bottom = -110.0
		_prompt.offset_left = -480.0
		_prompt.offset_right = 480.0
		layer.add_child(_prompt)
	_prompt.alternates = {lines[0]:lines[1]}
	_prompt.text = lines[0]
	_prompt.visible = lines[0] != ""

func shown_prompt() -> String:
	return _prompt.shown_text() if _prompt != null and _prompt.visible else ""

## For checks: counts of what stands, by kind and state.
func state_counts() -> Dictionary:
	var out := {}
	for e: Dictionary in ents:
		var k := "%s_%s" % [e.kind,e.state]
		out[k] = int(out.get(k,0))+1
	return out
