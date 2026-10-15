extends Node
## [inhabitant] The city's strange inhabitants in the generated run (docs/
## design/roguelike/inhabitant-round1.md): the two strongest of the strange-
## city yards promoted onto a city layer's places, round the headless bodies
## and the real wanderer.
##
##   The Hollow Child (scripts/city_hollow_child.gd): sits in a place's
##   cover (a shrine, a gallery, under a lintel: where you would hide), in
##   the dark. Beside it your torch is drunk: no Olmec sees you. But it
##   fills from your flame, and full it draws a breath and cries: a Beacon
##   every Olmec on the layer turns to, and a wail on the noise bus. The
##   candle that calls them all to you.
##   The Sun-Keepers (scripts/enemies/sun_keeper.gd): plaster figures that
##   stand only where light falls. Households wait in a lamp's light on the
##   way up; lone sleepers stand in the dark by the route, statues until your
##   torch pool reaches them. They follow your pool, shove (a heart), and
##   the second touch takes the torch: a walking beacon every Olmec goes to.
##   T (pad Y) puts the torch out: one stood in your pool topples (over the
##   void, gone), and you are blind and dark. Relight at any lit fire.
##
## Danger rises with the region (LayerWorlds.danger): region 1 lays one
## child and one sleeper; higher, households at the higher lamps, more
## Keepers, quicker, keener, and children that fill faster and forget slower.
##
## Laid from the plan's sockets and the places' lit lamps, a slot at a time
## as each place stands near him (its colliders), seeded by the layer's seed.
## Knob: `--inhabitant=child|keepers|both` (both by default).
const LayerPlan = preload("res://scripts/roguelike/layer_plan.gd")
const RunFeatures = preload("res://scripts/roguelike/run_features.gd")
const SunKeeper = preload("res://scripts/enemies/sun_keeper.gd")
const HollowChild = preload("res://scripts/city_hollow_child.gd")
const Fires = preload("res://scripts/city_kit_fires.gd")
const EnemyYard = preload("res://studies/enemy_yard.gd")

## Frames after the layer is built before laying (its colliders in the space).
const SETTLE := 20
## Keeps (m, flat): the spawn, the gate, one inhabitant from another.
const SPAWN_CLEAR := 34.0
const GATE_CLEAR := 14.0
const APART := 22.0
## Not laid in his face: a slot waits while its spot is this near him (m).
const POP := 18.0
## A slot is tried every POLL s.
const POLL := 0.25
## Head room (walker heights): a Keeper stands 1.5 of him, the child sits.
const KEEPER_TALL := 1.5
const CHILD_TALL := 0.7
## How far off (m, flat) a thief's held sun draws an Olmec (the yard's 60).
const THIEF_DRAW := 160.0
## Open ground: level floor this far round a Keeper's spot (m, at his size).
const OPEN := 2.0
## A household stands this far (m, flat) from its lamp's flame, in its light
## at least LIT; a floor this far under the flame at most.
const HOUSE_NEAR := Vector2(1.6,4.5)
const LIT := 0.45
const LAMP_DROP := 9.0
## A sleeper stands this far beside the route (m), in the dark.
const SLEEPER_ASIDE := Vector2(1.8,3.2)
## A child needs no flame within its reach and this more (m).
const CHILD_DARK := 1.5
## The noise bus (m of loudness): the child's breath and wail, a Keeper's
## crash (a plank of plaster on stone) and the steal.
const NOISE := {"breath":10.0,"cry":60.0,"keeper_crash":34.0,"keeper_steal":22.0}

var stage: Node3D
var study: Node3D
var field: Node
var plan: Dictionary
var danger := 0.0
var children: Array = []
var keepers := 0
## What was laid, for the card and the checks: [{kind, at, on}].
var laid: Array = []
var _frames := 0
var _done := false
var _said := {}
var _voices := {}
var _hook_was: Callable
var _slots: Array = []
var _order := {}
var _route: Array = []
var _taken: Array = []
var _poll := 0.0
var _rng := RandomNumberGenerator.new()

## The director for `stage` (a LayerStage), or null: city layers only, the
## feature on.
static func dress(on_stage: Node3D, layer: Dictionary) -> Node:
	if not RunFeatures.on(&"inhabitant"): return null
	if not LayerPlan.LayerWorlds.city(layer.knobs): return null
	if on_stage.get("enemies") == null: return null
	var node := new()
	node.name = "LayerInhabitants"
	node.stage = on_stage
	node.study = on_stage.study
	node.field = on_stage.enemies
	node.plan = layer
	node.danger = LayerPlan.LayerWorlds.danger(layer.knobs)
	on_stage.add_child(node)
	node._hook()
	return node

func _hook() -> void:
	_hook_was = field.sound_hook
	var was := _hook_was
	var me := self
	field.sound_hook = func(n: StringName, at: Vector3) -> void:
		if was.is_valid(): was.call(n,at)
		if is_instance_valid(me): me._sound(n,at)

func _exit_tree() -> void:
	if field != null and is_instance_valid(field) and _hook_was.is_valid(): field.sound_hook = _hook_was

# --- The frame ----------------------------------------------------------------------

## Ahead of the enemies' step: laid once the places stand; the torch key.
func before(_delta: float) -> void:
	_frames += 1
	if not _done and _frames >= SETTLE: _plan_slots()
	if _done: _step_slots(_delta)
	if Input.is_action_just_pressed(&"walk_torch"): toggle_torch()
	_tells()

## T (pad Y): the torch out, or lit again (not while a Keeper has it).
func toggle_torch() -> void:
	var tree := get_tree()
	if Fires.look(tree) == null: return
	if Fires.torch_lit(tree):
		Fires.set_torch(tree,false)
		_say("Torch out: dark to them, blind to the drop",2.0)
	elif SunKeeper.torch_taken(tree):
		_say("A Sun-Keeper has your torch: knock it down, or relight at a fire",3.0)
	else:
		Fires.set_torch(tree,true)
		_say("Torch lit",1.2)

func reset() -> void:
	for c in children:
		if is_instance_valid(c): c.reset()
	for t in get_tree().get_nodes_in_group(SunKeeper.DroppedTorch.GROUP): t.queue_free()
	Fires.set_torch(get_tree(),true)

## First-time lines, the tells said once a layer.
func _tells() -> void:
	if not _done: return
	var tree := get_tree()
	for k in tree.get_nodes_in_group(SunKeeper.GROUP):
		if not is_instance_valid(k): continue
		var s := str(k.get("state"))
		if s in ["walk","rim","reach"]: _once("keeper","Something in the light turns its face to your torch",3.0)
		if s == "thief": _once("thief","It has your torch! The Olmecs turn to its light",3.5)
		if s == "fall": _once("fell","Its light went out under it: over it goes",2.5)
	for c in children:
		if not is_instance_valid(c): continue
		if c.state == "drinking" and c.fill > 0.08: _once("drink","Your flame leans toward a small clay figure: it drinks the light",3.5)
		if c.state == "breath": _once("breath","It draws a breath…",2.0)

func _once(key: String, text: String, seconds: float) -> void:
	if _said.has(key): return
	_said[key] = true
	_say(text,seconds)

func _say(text: String, seconds: float) -> void:
	if study != null and study.has_method("_say"): study.call("_say",text,seconds)

func _child_said(s: String, c: Node3D) -> void:
	match s:
		"breath": NoiseBus.make(c,c.global_position,float(NOISE.breath),&"child_breath")
		"cry":
			NoiseBus.make(c,c.global_position,float(NOISE.cry),&"child_cry")
			_say("It cries! Everything in the dark turns to it",3.5)

func _sound(sound_name: StringName, at: Vector3) -> void:
	var key := String(sound_name)
	if NOISE.has(key) and is_inside_tree(): NoiseBus.make(self,at,float(NOISE[key]),sound_name)
	var spec: Variant = SunKeeper.VOICES.get(key)
	if spec == null: return
	if not _voices.has(key): _voices[key] = EnemyYard._synth(spec)
	var player := AudioStreamPlayer3D.new()
	player.stream = _voices[key]
	player.position = at
	player.unit_size = float(SunKeeper.REACH.get(key,20.0))
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

# --- Laying -------------------------------------------------------------------------

## How many of each, by the danger: [children, sleepers, households, its size].
func counts() -> Dictionary:
	var which := RunFeatures.value("inhabitant","both")
	var d := danger
	var out := {"children":1+roundi(d),"sleepers":1+(1 if d >= 0.6 else 0),"households":roundi(2.0*d),"house":2+roundi(d)}
	if which == "child":
		out.sleepers = 0
		out.households = 0
	elif which == "keepers": out.children = 0
	return out

func keeper_knobs() -> Dictionary:
	var d := danger
	# Its held sun (a stolen torch) draws on the layer's scale, as the
	# child's cry does: every Olmec near the way turns to the thief.
	return {"pace":0.67+0.13*d,"sense":(24.0+8.0*d)*Fires.size(),"steal_after":1 if d >= 0.99 else 2,
		"draw":THIEF_DRAW*Fires.size()}

func child_knobs() -> Dictionary:
	var d := danger
	# Its fill on the torch alone, in seconds whatever the look (the child
	# scales the torch's rate by its strength: the haze's torch is dimmer).
	var k := LightLevel.torch_strength/LightLevel.TORCH if LightLevel.torch_strength > 0.0 else 1.0
	return {"torch_fill":(25.0-11.0*d)*k,"leak":60.0+60.0*d}

## Which isles each kind goes on, in order of preference, and the slots to
## fill: households on the highest places, sleepers on the lower, children
## where there is cover. The isles stand their colliders a few at a time
## near him, so each slot is laid when its isle is there (`_step_slots`),
## and moves to the next isle of its order if nothing on its own fits.
func _plan_slots() -> void:
	_done = true
	_rng.seed = hash([int(plan.seed),"inhabitants"])
	_route = _sockets(["rune_line","rune_risk","rim"])
	# The places on the way up first (in the plan's order, the way he meets
	# them), the greed branch's after.
	var way: Array = []
	var greed: Array = []
	for i in (plan.isles as Array).size():
		var role := str(plan.isles[i].get("role",""))
		if role == "base": continue
		if role == "route": way.append(i)
		else: greed.append(i)
	var by_height := way.duplicate()
	by_height.sort_custom(func(a: int, b: int) -> bool: return float(plan.isles[a].offset.y) > float(plan.isles[b].offset.y))
	var cover: Array = []
	var bare: Array = []
	for i: int in way:
		if _sockets(["cover"],i).is_empty(): bare.append(i)
		else: cover.append(i)
	LayerPlan._shuffle(cover,_rng)
	_order = {"household":by_height+greed,"sleeper":way+greed,"child":cover+bare+greed}
	var want := counts()
	var names := {"household":"households","sleeper":"sleepers","child":"children"}
	for kind: String in ["household","sleeper","child"]:
		var n := int(want[names[kind]])
		for j in n:
			if j < (_order[kind] as Array).size(): _slots.append({"kind":kind,"isle":int(_order[kind][j]),"next":n})
	print("inhabitants: danger %.2f, slots %s" % [danger,str(_slots.map(func(x: Dictionary) -> String: return "%s@%d" % [x.kind,x.isle]))])

## One slot tried every POLL s: laid, waiting on its isle, or moved on.
func _step_slots(delta: float) -> void:
	_poll -= delta
	if _poll > 0.0 or _slots.is_empty(): return
	_poll = POLL
	for slot: Dictionary in _slots:
		var got := _try(slot)
		if got == "wait": continue
		if got == "fail":
			# The next isle of its kind's order not tried for it yet.
			var order: Array = _order[slot.kind]
			if int(slot.next) < order.size():
				slot.isle = int(order[slot.next])
				slot.next = int(slot.next)+1
				return
		_slots.erase(slot)
		if got == "ok": print("inhabitants: laid %s" % str(laid[laid.size()-1]))
		return

## A slot laid on its isle: "ok", "wait" (its isle isn't stood near him
## yet, or he is too near), "fail" (nothing on it fits).
func _try(slot: Dictionary) -> String:
	var isle := int(slot.isle)
	if not _isle_ready(isle): return "wait"
	var tree := get_tree()
	var feet: Vector3 = field.motor.feet
	match str(slot.kind):
		"household":
			var lamps := _lamps(tree,isle)
			lamps.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.global_position.y > b.global_position.y)
			for lamp: Node3D in lamps:
				var spots := _house_spots(tree,lamp,int(counts().house),_rng)
				if spots.size() < 2 or not _free(spots[0]): continue
				if _flat(spots[0],feet) < POP: return "wait"
				var face := _face_to_route(spots[0],_route)
				for s: Vector3 in spots:
					field.spawn(SunKeeper,s,face,keeper_knobs())
					keepers += 1
				_taken.append(spots[0])
				laid.append({"kind":"household","at":spots[0],"n":spots.size(),"isle":isle,"on":"%s %s" % [plan.isles[isle].id,lamp.get_parent().name]})
				return "ok"
		"sleeper":
			var route := _sockets(["rune_line","rune_risk"],isle)
			LayerPlan._shuffle(route,_rng)
			for s: Dictionary in route:
				var at := _sleeper_spot(tree,s.at,_rng)
				if at == Vector3.INF or not _free(at): continue
				if _flat(at,feet) < POP: return "wait"
				field.spawn(SunKeeper,at,_face_to(at,s.at),keeper_knobs())
				keepers += 1
				_taken.append(at)
				laid.append({"kind":"sleeper","at":at,"isle":isle,"on":"%s %s" % [plan.isles[isle].id,s.name]})
				return "ok"
		"child":
			var cover := _sockets(["cover"],isle)
			var route := _sockets(["rune_line","rune_risk"],isle)
			LayerPlan._shuffle(cover,_rng)
			LayerPlan._shuffle(route,_rng)
			for s: Dictionary in cover+route:
				var at := _child_spot(tree,s.at)
				if at == Vector3.INF or not _free(at): continue
				if _flat(at,feet) < POP: return "wait"
				var c: Node3D = HollowChild.new()
				c.name = "HollowChild%d" % children.size()
				c.position = at
				c.knobs.merge(child_knobs(),true)
				c.knobs.merge(HollowChild.knobs_from(OS.get_cmdline_user_args()),true)
				add_child(c)
				var f := _face_to_route(at,_route)
				c.rotation.y = atan2(f.x,f.y)
				c.state_changed.connect(_child_said.bind(c))
				children.append(c)
				_taken.append(at)
				laid.append({"kind":"child","at":at,"isle":isle,"on":"%s %s" % [plan.isles[isle].id,s.name]})
				return "ok"
	return "fail"

## Whether isle `i` stands near him: a floor under any of its sockets.
func _isle_ready(i: int) -> bool:
	for s: Dictionary in plan.isles[i].get("sockets",[]):
		var p: Vector3 = s.at
		if field.floor_under(p,2.0,3.0) != -INF: return true
	return false

func _free(p: Vector3) -> bool:
	var spawn: Vector3 = (plan.spawn as Dictionary).get("at",Vector3.INF)
	var gate: Vector3 = (plan.exit as Dictionary).get("at",Vector3.INF)
	if spawn != Vector3.INF and _flat(p,spawn) < SPAWN_CLEAR: return false
	if gate != Vector3.INF and _flat(p,gate) < GATE_CLEAR: return false
	for t: Vector3 in _taken:
		if _flat(p,t) < APART: return false
	return true

## The plan's sockets of `kinds` on the places (not the landing), or on
## isle `only`.
func _sockets(kinds: Array, only := -1) -> Array:
	var out: Array = []
	for i in (plan.isles as Array).size():
		var isle: Dictionary = plan.isles[i]
		if str(isle.get("role","")) == "base" or (only >= 0 and i != only): continue
		for s: Dictionary in isle.get("sockets",[]):
			if str(s.kind) in kinds: out.append(s)
	return out

## Isle `isle`'s lit lamps and cressets (Beacons of its fires, not its far
## towers), at least a stride's light.
func _lamps(tree: SceneTree, isle: int) -> Array:
	var out: Array = []
	var gate: Vector3 = (plan.exit as Dictionary).get("at",Vector3.INF)
	var tag := "Greybox_%s_%d/" % [str(plan.isles[isle].id).trim_prefix("gb_"),isle]
	for n in tree.get_nodes_in_group(Beacon.BEACONS):
		var b := n as Beacon
		if b == null or not b.lit or b.radius < 6.0 or not b.is_inside_tree(): continue
		var path := str(b.get_path())
		if not path.contains(tag) or path.contains("Tower") or path.contains("Far"): continue
		if gate != Vector3.INF and _flat(b.global_position,gate) < GATE_CLEAR: continue
		out.append(b)
	return out

## Up to `n` spots round `lamp` in its light, on its floor.
func _house_spots(tree: SceneTree, lamp: Node3D, n: int, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var f := lamp.global_position
	for t in 24:
		if out.size() >= n: break
		var a := rng.randf()*TAU
		var r := rng.randf_range(HOUSE_NEAR.x,HOUSE_NEAR.y)*Fires.size()
		var p := f+Vector3(cos(a)*r,0.0,sin(a)*r)
		var g := _stand(p,f.y+0.5,LAMP_DROP)
		if g == -INF: continue
		var at := Vector3(p.x,g,p.z)
		if (lamp as SightLight).light_at(at+Vector3.UP*0.3) < LIT: continue
		if not _open_ground(at): continue
		var near := false
		for o: Vector3 in out:
			if _flat(o,at) < 1.3*Fires.size(): near = true
		if near: continue
		out.append(at)
	return out

## A dark spot beside route point `p`, on its floor, or INF.
func _sleeper_spot(tree: SceneTree, p: Vector3, rng: RandomNumberGenerator) -> Vector3:
	for t in 10:
		var a := rng.randf()*TAU
		var r := rng.randf_range(SLEEPER_ASIDE.x,SLEEPER_ASIDE.y)*Fires.size()
		var q := p+Vector3(cos(a)*r,0.0,sin(a)*r)
		var g := _stand(q,p.y+1.0,2.0)
		if g == -INF or absf(g-p.y) > 0.8: continue
		var at := Vector3(q.x,g,q.z)
		if SunKeeper.light_on(tree,at) != null: continue
		if not _room(at): continue
		return at
	return Vector3.INF

## Socket `p` for a child: its floor, no flame within its reach.
func _child_spot(tree: SceneTree, p: Vector3) -> Vector3:
	var g := _stand(p,p.y+1.5,3.0,CHILD_TALL)
	if g == -INF: return Vector3.INF
	var at := Vector3(p.x,g,p.z)
	var reach := float(HollowChild.KNOBS.reach)*Fires.size()+CHILD_DARK
	for n in tree.get_nodes_in_group(SightLight.GROUP):
		var l := n as SightLight
		if l == null or not l.lit or l.strength <= 0.0: continue
		# Its flame not in its reach (it would drink it and cry like a clock),
		# and its light not on whoever sits with it (he would be seen anyway).
		if l.global_position.distance_to(at+Vector3.UP*0.5) < maxf(reach,l.radius+reach*0.5): return Vector3.INF
	return at

## The floor under `p` from `top` (world y) down `drop` m, with head room
## over it, or -INF.
func _stand(p: Vector3, top: float, drop: float, tall := KEEPER_TALL) -> float:
	var q := Vector3(p.x,top,p.z)
	var g: float = field.floor_under(q,0.0,drop)
	if g == -INF: return g
	return g if _room(Vector3(p.x,g,p.z),tall) else -INF

## Whether `at` is open ground: the floor round it (OPEN m off, each way)
## level with it, not a plinth's top or a column's head.
func _open_ground(at: Vector3) -> bool:
	var r := OPEN*Fires.size()
	for d: Vector3 in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
		var g: float = field.floor_under(at+d*r,1.0,1.0)
		if g == -INF or absf(g-at.y) > 0.4: return false
	return true

## Room for a figure `tall` walker heights tall at `at` (nothing over it).
func _room(at: Vector3, tall := KEEPER_TALL) -> bool:
	return not field.blocked(at+Vector3.UP*0.3,Vector3.UP*tall*float(field.numbers().unit))

func _face_to_route(at: Vector3, route: Array) -> Vector2:
	var best := INF
	var to := Vector3.INF
	for s: Dictionary in route:
		var d := _flat(at,s.at)
		if d > 1.0 and d < best:
			best = d
			to = s.at
	return _face_to(at,to) if to != Vector3.INF else Vector2(0.0,1.0)

func _face_to(at: Vector3, to: Vector3) -> Vector2:
	var v := Vector2(to.x-at.x,to.z-at.z)
	return v.normalized() if v.length() > 0.01 else Vector2(0.0,1.0)

static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x-b.x,a.z-b.z).length()

## A line for the card / log.
func card() -> String:
	var words := PackedStringArray()
	for l: Dictionary in laid:
		match str(l.kind):
			"household": words.append("Sun-Keepers x%d at a lamp (%s)" % [int(l.n),str(l.on)])
			"sleeper": words.append("a sleeping Sun-Keeper by %s" % str(l.on))
			"child": words.append("a Hollow Child in %s" % str(l.on))
	return "; ".join(words) if not words.is_empty() else "none fit"
