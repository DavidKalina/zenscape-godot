extends Node3D
## The layer's collectibles (docs/design/roguelike/game-v1-brief.md rule 5,
## docs/design/roguelike/game-v1-collectibles.md): the runes (the coin) and
## the rare collectible (no name or look yet: GlyphPickup's "sun" glyph
## stands in), laid from the plan, plus a chest or two that pay runes.
##
## Laying (`lay`, static, data only, no physics, so a driver can count a
## layer over seeds without building it):
## - **Each isle's own spots**, read through its motif at the time
##   (`spots()`, and `collect_spots()` if it keeps them there), moved by the
##   isle's offset:
##   - `rune_line`: LINE runes on the route there (a line of them pointed
##     at the nearest other rune_line spot, the way the route runs, when
##     LINE > 1). The motifs space these along their ways already.
##   - `rune_risk`: a cluster: one on the spot, a ring round it, a stack
##     over it that takes a jump on the exposed spot, and on top a great
##     rune worth GREAT (rule 0: a detour pays many times a stretch of the
##     route).
##   - `rare`: a candidate for the rare (RARES a layer, one an isle first).
##   - A motif without rune spots gets a light scatter from its sockets
##     (arena, perch, cover: SCATTER).
## - **The crossings** between isles (the plan's edges): a rune every
##   SAFE_STEP m along a safe one (stones, bridge, climb), every RISK_STEP m
##   along a risky one (hard stones, the voussoirs, the greed branch), and a
##   few at the far lip of a gulf or a cannon's throw.
## - **Chests** (scripts/chest/chest_field.gd): CHESTS a layer, at cover and
##   perch spots off the start isle, paying CHEST_RUNES.
## Rule 0: the safe route is poor, the clever line rich (the counts are in
## the handoff doc).
##
## Standing (`dress`, a child of scripts/roguelike/layer_stage.gd, which
## steps it): each pickup is stood only when he comes within NEAR m, set on
## the ground found under its spot (a ray in his own ground's mask), RUNE_LIFT
## over it; a derived rune whose spot has no ground under it (off a lip) is
## dropped, a spot's own rune keeps its authored height. Taken by the
## walker's sweep (as LayerStage `touch`). A rune sounds the sky tokens'
## blip, climbing with a streak; a rare is a moment (`_rare_moment`): its
## spin and wisp, a warm light swelling round it, the sky tokens' flourish
## and a beat of slowed time, and the run loop's caption.
##
## Signals for the run loop: `rune_taken(src, worth)` (a rune and its worth, from where:
## "route", "risk", "crossing", "scatter", "chest", ...) and
## `rare_taken(got, of)`.
const GlyphPickup = preload("res://scripts/glyph_pickup.gd")
const ChestField = preload("res://scripts/chest/chest_field.gd")
const Lines = preload("res://scripts/collectible_lines.gd")
const CollectiblesHud = preload("res://scripts/collectibles_hud.gd")
const Audio = preload("res://scripts/genesis_audio.gd")

## The runes: their size (m), their middle over the ground (m), the line's
## count and step, the risk cluster's ring and stack.
const RUNE_SIZE := 0.55
const RUNE_LIFT := 0.7
const LINE := 1
const LINE_STEP := 1.4
## The nearest other rune_line spot a line points at, within this (m flat).
const LINE_LOOK := 40.0
const RISK_RING := 5
const RISK_STACK := 1
## The great rune on top of a risk stack: its worth (runes) and size (m).
const GREAT := 5
const GREAT_SIZE := 0.85
## The stack's steps over the spot's rune: shares of his small jump.
const STACK_STEP := 0.6
## The light scatter on a motif without rune spots: runes per socket kind.
const SCATTER := {"arena":3,"perch":2,"cover":1}
## Crossings: a rune every this far (m) along a safe edge, a risky one; at
## a gulf's or a cannon's far lip, this many.
const SAFE_STEP := 7.0
const RISK_STEP := 2.0
const LIP_RUNES := 3
## Two pickups closer than this (m) are one.
const APART := 0.9
## The rare: size (m), its middle over the ground (m), how many a layer.
const RARE_SIZE := 0.95
const RARE_LIFT := 0.85
const RARES := 3
## Chests a layer and the runes each pays.
const CHESTS := 2
const CHEST_RUNES := Vector2i(6,9)
## Stood within NEAR m (flat) of him; its motes on within MOTES m.
const NEAR := 70.0
const MOTES := 22.0
## Pending pickups stood per frame at most; one with no ground under it
## yet tried again after RETRY s.
const STAND_PER_FRAME := 24
const RETRY := 0.5
## The rune's look underground: tarnished gold, a dim warm glow (the sky's
## tokens are cyan; art direction: glows stay dim and warm).
const RUNE_TINT := Color("c79a52")
const RUNE_GLOW_TINT := Color("f0c98a")
const RUNE_HALO := Color("e8c48c")
const RUNE_GLOW := 0.32
const RUNE_HALO_STRENGTH := 0.16
## The rare's lantern: a small warm light under it (energy, range m).
const RARE_LIGHT := Color("ffcf8f")
const RARE_LIGHT_ENERGY := 0.45
const RARE_LIGHT_RANGE := 3.2
## The rare's moment: the light's swell (energy at its peak, range m, s),
## the slowed beat (time scale, real s held, real s easing back).
const MOMENT_ENERGY := 2.6
const MOMENT_RANGE := 7.0
const MOMENT_LIGHT := 1.4
const BEAT_SCALE := 0.25
const BEAT_HOLD := 0.22
const BEAT_EASE := 0.35
## A rune's blip climbs a step a pickup while they come within STREAK s.
const STREAK := 1.2
const BLIP_GAIN := 0.1
const FLOURISH_GAIN := 0.16

signal rune_taken(src: String, worth: int)
signal rare_taken(got: int, of: int)

var study: Node3D
var plan: Dictionary
## Every pickup laid: {what ("rune", "rare", "chest"), src, at, lift, keep
## (stand at the authored height if no ground), isle, name, node, state
## ("pending", "live", "taken", "dropped")}.
var items: Array = []
## Taken this layer, by src; rares taken and laid.
var taken := {}
var rares_got := 0
var rares_laid := 0
var chests: Node3D = null
var _live: Array = []
var _pending: Array = []
var _last := Vector3.INF
var _ray := PhysicsRayQueryParameters3D.new()
var _blip: AudioStreamPlayer
var _flourish: AudioStreamPlayer
var _streak := 0
var _since := INF
var _motes_t := 0.0
var _clock := 0.0

func _init() -> void:
	name = "Collectibles"

## The plan's collectibles stood on `stage` (scripts/roguelike/
## layer_stage.gd); null where the plan has no isles.
static func dress(stage: Node3D, layer: Dictionary) -> Node3D:
	if (layer.get("isles",[]) as Array).is_empty(): return null
	var node: Node3D = new()
	stage.add_child(node)
	node.setup(stage.study,layer)
	return node

func setup(scene: Node3D, layer: Dictionary) -> void:
	study = scene
	plan = layer
	items = lay(layer)
	for it: Dictionary in items:
		it.state = "pending"
		if it.what == "rare": rares_laid += 1
		_pending.append(it)
	chests = ChestField.new()
	chests.study = scene
	chests.motor = scene.motor
	add_child(chests)
	chests.rune_taken.connect(func(_left: int) -> void: _rune("chest",1))
	Audio.ensure_buses()
	_blip = _player(CollectiblesHud._blip(),BLIP_GAIN)
	_flourish = _player(CollectiblesHud._flourish(),FLOURISH_GAIN)

func _player(stream: AudioStreamWAV, gain: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = Audio.BUS
	p.stream = stream
	p.volume_db = linear_to_db(gain)
	p.max_polyphony = 4
	add_child(p)
	return p

# --- Laying (data only) ---------------------------------------------------------------

## Every pickup of `layer`, as data: [{what, src, at, lift, keep, isle, name}].
static func lay(layer: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(layer.get("seed",0)),"collectibles"])
	var out: Array = []
	var isles: Array = layer.get("isles",[])
	var rare_spots := {}
	var covers: Array = []
	var perches: Array = []
	var j := float(KitMotifPilot.jump())
	for i in range(isles.size()):
		var isle: Dictionary = isles[i]
		var spots := spots_of(isle)
		var has_runes := false
		for s: Dictionary in spots:
			if str(s.kind) in ["rune_line","rune_risk"]: has_runes = true
		var lines: Array = spots.filter(func(s: Dictionary) -> bool: return s.kind == "rune_line")
		for s: Dictionary in spots:
			var at: Vector3 = s.at
			match str(s.kind):
				"rune_line":
					var way := _line_way(s,lines,rng)
					for k in range(LINE):
						var off := (float(k)-float(LINE-1)*0.5)*LINE_STEP
						out.append(_item("rune","route",at+way*off,i,"%s_%d" % [s.name,k],k == (LINE-1)/2))
				"rune_risk":
					out.append(_item("rune","risk",at,i,str(s.name),true))
					var r := clampf(float(s.room)*0.9,APART+0.1,1.5)
					var turn := rng.randf()*TAU
					for k in range(RISK_RING):
						var a := turn+TAU*float(k)/RISK_RING
						out.append(_item("rune","risk",at+Vector3(cos(a),0.0,sin(a))*r,i,"%s_ring%d" % [s.name,k],false))
					for k in range(RISK_STACK+1):
						var st := _item("rune","risk",at,i,"%s_stack%d" % [s.name,k],true)
						st.lift = RUNE_LIFT+maxf(APART+0.05,j*STACK_STEP)*float(k+1)
						if k == RISK_STACK:
							st.worth = GREAT
							st.name = "%s_great" % s.name
						out.append(st)
				"rare":
					if str(isle.get("role","")) == "base": continue
					if not rare_spots.has(i): rare_spots[i] = []
					rare_spots[i].append(s)
				"cover":
					if float(s.room) >= 1.5 and str(isle.get("role","")) != "base": covers.append([i,s])
				"perch":
					if float(s.room) >= 2.0 and str(isle.get("role","")) != "base": perches.append([i,s])
		if not has_runes:
			# The light scatter: off the motif's sockets (world already).
			for s: Dictionary in isle.get("sockets",[]):
				var n := int(SCATTER.get(str(s.kind),0))
				if n <= 0: continue
				var turn := rng.randf()*TAU
				for k in range(n):
					var a := turn+TAU*float(k)/n
					var r := 0.0 if k == 0 else minf(float(s.get("room",1.0))*0.4,1.6)
					out.append(_item("rune","scatter",(s.at as Vector3)+Vector3(cos(a),0.0,sin(a))*r,i,"%s_%d" % [s.name,k],k == 0))
	_lay_crossings(layer,out)
	_lay_rares(layer,rare_spots,out,rng)
	_lay_chests(covers,perches,out,rng)
	return _apart(out)

## A rune_line's way: toward the nearest other line spot within LINE_LOOK
## (flat), else a turn from the seed.
static func _line_way(s: Dictionary, lines: Array, rng: RandomNumberGenerator) -> Vector3:
	var at: Vector3 = s.at
	var best := Vector3.ZERO
	var best_d := LINE_LOOK
	for o: Dictionary in lines:
		if o == s: continue
		var d := Vector2((o.at as Vector3).x-at.x,(o.at as Vector3).z-at.z)
		if d.length() > 0.5 and d.length() < best_d:
			best_d = d.length()
			best = Vector3(d.x,0.0,d.y).normalized()
	if best == Vector3.ZERO:
		var a := rng.randf()*TAU
		best = Vector3(cos(a),0.0,sin(a))
	return best

## The crossings: every SAFE_STEP / RISK_STEP m along the edge's walked line
## (each found on its footing when stood; one over a gap is dropped), a
## gulf's or a cannon's far lip LIP_RUNES.
static func _lay_crossings(layer: Dictionary, out: Array) -> void:
	var edges: Array = layer.get("edges",[])
	for ei in range(edges.size()):
		var e: Dictionary = edges[ei]
		var kind := str(e.get("kind",""))
		var risky := risky_edge(e)
		var src := "crossing_risk" if risky else "crossing_safe"
		if kind in ["gulf","cannon"]:
			var b: Vector3 = e.get("b",Vector3.ZERO)
			var dir: Vector3 = e.get("dir",Vector3.FORWARD)
			var flat := Vector3(dir.x,0.0,dir.z).normalized()
			for k in range(LIP_RUNES): out.append(_item("rune",src,b+flat*(1.2+1.3*k),-1,"edge%d_lip%d" % [ei,k],false))
			continue
		var path: Array = e.get("path",[])
		if path.is_empty(): continue
		var step := RISK_STEP if risky else SAFE_STEP
		var walked := 0.0
		var next := step*0.5
		var prev: Vector3 = path[0][0]
		for s: Array in path:
			var p: Vector3 = s[0]
			walked += p.distance_to(prev)
			prev = p
			if walked >= next:
				next += step
				var it := _item("rune",src,p,-1,"edge%d_%d" % [ei,roundi(walked)],false)
				it.probe = 1.4
				out.append(it)

## Whether an edge is the risky way: hard stones, the voussoirs, a gulf, a
## cannon, or the greed branch.
static func risky_edge(e: Dictionary) -> bool:
	return str(e.get("kind","")) in ["hard","trap","gulf","cannon"] or str(e.get("branch","")) == "greed"

## The rares: RARES of the isles' rare spots, one an isle first (the isles
## in a seeded order); with none, one on the greed isle's highest perch (or
## the last stone of a hard crossing).
static func _lay_rares(layer: Dictionary, spots: Dictionary, out: Array, rng: RandomNumberGenerator) -> void:
	var order: Array = spots.keys()
	order.sort()
	for k in range(order.size()-1,0,-1):
		var swap := rng.randi_range(0,k)
		var t: Variant = order[k]
		order[k] = order[swap]
		order[swap] = t
	var got := 0
	var round_i := 0
	while got < RARES and round_i < 4:
		for i: int in order:
			if got >= RARES: break
			var list: Array = spots[i]
			if list.is_empty(): continue
			var s: Dictionary = list.pop_at(rng.randi_range(0,list.size()-1))
			var it := _item("rare","rare",s.at,i,str(s.name),true)
			it.lift = RARE_LIFT
			out.append(it)
			got += 1
		round_i += 1
	if got > 0: return
	var isles: Array = layer.get("isles",[])
	for i in range(isles.size()):
		if str(isles[i].get("role","")) != "greed": continue
		var best: Dictionary = {}
		for s: Dictionary in isles[i].get("sockets",[]):
			if str(s.kind) in ["perch","arena"] and (best.is_empty() or (s.at as Vector3).y > (best.at as Vector3).y): best = s
		if not best.is_empty():
			var it := _item("rare","rare",best.at,i,"greed_%s" % best.name,true)
			it.lift = RARE_LIFT
			out.append(it)
			return
	for e: Dictionary in layer.get("edges",[]):
		if str(e.get("kind","")) == "hard" and not (e.stones as Array).is_empty():
			var last: Dictionary = e.stones[-1]
			var it := _item("rare","rare",last.at,-1,"hard_crossing",true)
			it.lift = RARE_LIFT
			out.append(it)
			return

## CHESTS chests: a cover spot's first (a seeded one), then a perch's.
static func _lay_chests(covers: Array, perches: Array, out: Array, rng: RandomNumberGenerator) -> void:
	var placed := 0
	for list: Array in [covers,perches,covers,perches]:
		if placed >= CHESTS or list.is_empty(): continue
		var pick: Array = list.pop_at(rng.randi_range(0,list.size()-1))
		var s: Dictionary = pick[1]
		var it := _item("chest","chest",s.at,int(pick[0]),str(s.name),false)
		it.runes = rng.randi_range(CHEST_RUNES.x,CHEST_RUNES.y)
		it.yaw = rng.randf()*TAU
		it.probe = 1.0
		out.append(it)
		placed += 1

static func _item(what: String, src: String, at: Vector3, isle: int, item_name: String, keep: bool) -> Dictionary:
	return {"what":what,"src":src,"at":at,"lift":RUNE_LIFT,"keep":keep,"isle":isle,"name":item_name,"probe":0.5,"worth":1}

## Rares and chests first, then runes no nearer than APART to one kept.
static func _apart(all: Array) -> Array:
	var out: Array = []
	for what: String in ["rare","chest","rune"]:
		for it: Dictionary in all:
			if it.what != what: continue
			var p: Vector3 = (it.at as Vector3)+Vector3.UP*float(it.lift)
			var clear := true
			for o: Dictionary in out:
				var room := APART if o.what == "rune" else 1.6
				if p.distance_to((o.at as Vector3)+Vector3.UP*float(o.lift)) < room:
					clear = false
					break
			if clear: out.append(it)
	return out

## An isle's spots in the world: its motif's `spots()` and `collect_spots()`
## (each once), moved by its offset; [] for a motif without them.
static func spots_of(isle: Dictionary) -> Array:
	var m: Variant = isle.get("motif")
	var out: Array = []
	if not (m is Object): return out
	var off: Vector3 = isle.get("offset",Vector3.ZERO)
	var seen := {}
	for getter: String in ["spots","collect_spots"]:
		if not _takes_none(m,getter): continue
		var got: Variant = (m as Object).call(getter)
		if not (got is Array): continue
		for s: Variant in got:
			if not (s is Dictionary) or not (s as Dictionary).has("kind") or not ((s as Dictionary).get("at") is Vector3): continue
			var d := (s as Dictionary).duplicate()
			var key := "%s|%s|%s" % [d.kind,str(d.get("name","")),str((d.at as Vector3).snapped(Vector3.ONE*0.1))]
			if seen.has(key): continue
			seen[key] = true
			d.at = (d.at as Vector3)+off
			if not d.has("room"): d.room = 1.0
			if not d.has("name"): d.name = str(d.kind)
			out.append(d)
	return out

## Whether `obj` has a method `method` that takes no arguments.
static func _takes_none(obj: Object, method: String) -> bool:
	if not obj.has_method(method): return false
	for m: Dictionary in obj.get_method_list():
		if str(m.name) == method: return (m.args as Array).size() == 0
	return false

## Counts of `items` by what and src: {runes, rares, chests, chest_runes,
## by_src {src: n}}.
static func tally(all: Array) -> Dictionary:
	var by := {}
	var n := {"runes":0,"rares":0,"chests":0,"chest_runes":0}
	for it: Dictionary in all:
		match str(it.what):
			"rune":
				n.runes += int(it.worth)
				by[it.src] = int(by.get(it.src,0))+int(it.worth)
			"rare": n.rares += 1
			"chest":
				n.chests += 1
				n.chest_runes += int(it.get("runes",0))
	n.by_src = by
	return n

# --- On the stage ---------------------------------------------------------------------

func before(delta: float) -> void:
	if chests != null: chests.before(delta)

func after(delta: float, events: Dictionary) -> void:
	if chests != null: chests.after(delta,events)
	_since += delta
	_clock += delta
	var figure: Variant = study.get("figure")
	if not (figure is Node3D): return
	var me: Vector3 = (figure as Node3D).global_position
	_stand_near(me)
	_touch(me+Vector3.UP*Lines.WALKER_MIDDLE)
	_motes_t -= delta
	if _motes_t <= 0.0:
		_motes_t = 0.25
		for it: Dictionary in _live:
			var node: Node3D = it.node
			if is_instance_valid(node) and not node.taking: node.motes_on(Vector2(node.global_position.x-me.x,node.global_position.z-me.z).length() < MOTES)

func pose(figure: Node3D) -> void:
	if chests != null: chests.pose(figure)

func frame(camera: Camera3D, delta: float) -> void:
	if chests != null: chests.frame(camera,delta)

func reset() -> void:
	if chests != null: chests.reset()
	_last = Vector3.INF

## Stands the pending pickups within NEAR of `me` (STAND_PER_FRAME a frame).
func _stand_near(me: Vector3) -> void:
	if _pending.is_empty() or not is_inside_tree(): return
	var stood := 0
	for idx in range(_pending.size()-1,-1,-1):
		if stood >= STAND_PER_FRAME: break
		var it: Dictionary = _pending[idx]
		var at: Vector3 = it.at
		if Vector2(at.x-me.x,at.z-me.z).length() > NEAR: continue
		if float(it.get("retry_at",0.0)) > _clock: continue
		stood += 1
		if _stand(it): _pending.remove_at(idx)
		else: it.retry_at = _clock+RETRY

## One pickup stood on the ground under its spot (or dropped); false to
## try again later (no ground found while the layer's isles still stand
## up, nearest the eye first: scripts/kit_isle/motif_sky.gd).
func _stand(it: Dictionary) -> bool:
	var at: Vector3 = it.at
	var ground := _ground_under(at,float(it.probe))
	if ground == INF:
		if not _isles_up(): return false
		if not bool(it.keep):
			it.state = "dropped"
			return true
		ground = at.y
	match str(it.what):
		"chest":
			var c: Node3D = chests.add_chest(Vector3(at.x,ground,at.z),float(it.yaw),{"runes":int(it.runes),"seed":hash(it.name) & 0xffff})
			it.node = c
			it.state = "live"
		"rare":
			var holder: Node3D = GlyphPickup.make("sun",RARE_SIZE,float(hash(it.name) % 100)*0.07,true)
			holder.name = "Rare_%s" % it.name
			add_child(holder)
			holder.global_position = Vector3(at.x,ground+float(it.lift),at.z)
			holder.glow_for(0.0)
			var lamp := OmniLight3D.new()
			lamp.name = "Lamp"
			lamp.light_color = RARE_LIGHT
			lamp.light_energy = RARE_LIGHT_ENERGY
			lamp.omni_range = RARE_LIGHT_RANGE
			lamp.shadow_enabled = false
			holder.add_child(lamp)
			it.node = holder
			it.state = "live"
			_live.append(it)
		_:
			var holder: Node3D = GlyphPickup.make("rune",GREAT_SIZE if int(it.worth) > 1 else RUNE_SIZE,float(hash(it.name) % 100)*0.13,true)
			holder.name = "Rune_%s" % it.name
			add_child(holder)
			holder.global_position = Vector3(at.x,ground+float(it.lift),at.z)
			_warm(holder)
			it.node = holder
			it.state = "live"
			_live.append(it)
	return true

## A rune holder in the underground's look: tarnished gold, dim and warm.
static func _warm(holder: Node3D) -> void:
	for path: String in ["Spin/Diamond","Spin/Orbit/Ring"]:
		var mesh := holder.get_node_or_null(path) as MeshInstance3D
		if mesh == null: continue
		var mat := mesh.material_override as ShaderMaterial
		if mat == null: continue
		mat.set_shader_parameter("tint",RUNE_TINT)
		mat.set_shader_parameter("glow_tint",RUNE_GLOW_TINT)
		mat.set_shader_parameter("glow",RUNE_GLOW)
	for child: Node in holder.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh is QuadMesh:
			var halo := (child as MeshInstance3D).material_override as ShaderMaterial
			if halo != null:
				halo.set_shader_parameter("tint",RUNE_HALO)
				halo.set_shader_parameter("strength",RUNE_HALO_STRENGTH)
	holder.set("_glow",RUNE_GLOW)
	holder.set("_halo_strength",RUNE_HALO_STRENGTH)
	var motes := holder.get("motes") as CPUParticles3D
	if motes != null and motes.mesh is PrimitiveMesh and (motes.mesh as PrimitiveMesh).material is StandardMaterial3D:
		var mm := ((motes.mesh as PrimitiveMesh).material as StandardMaterial3D).duplicate() as StandardMaterial3D
		mm.albedo_color = RUNE_GLOW_TINT
		mm.emission = RUNE_GLOW_TINT
		mm.emission_energy_multiplier = 1.0
		var mesh := motes.mesh.duplicate() as PrimitiveMesh
		mesh.material = mm
		motes.mesh = mesh

## Whether every isle of the layer stands (true where nothing says: the
## motif yard's one isle stands before the stage).
func _isles_up() -> bool:
	var sky: Variant = study.get("sky")
	if not (sky is Object): return true
	var motifs: Variant = (sky as Object).get("motifs")
	if not (motifs is Object) or not (motifs as Object).has_method("all_stood"): return true
	return bool((motifs as Object).call("all_stood"))

## The ground's top under `p` (from `probe` m over it, 2.5 m down) in his
## ground's mask, INF if none.
func _ground_under(p: Vector3, probe: float) -> float:
	var g: Variant = study.get("ground")
	var mask := 1
	if g != null and g.get("mask") != null: mask = int(g.mask)
	_ray.from = p+Vector3.UP*probe
	_ray.to = p-Vector3.UP*2.5
	_ray.collision_mask = mask
	_ray.hit_from_inside = false
	var hit := get_world_3d().direct_space_state.intersect_ray(_ray)
	return INF if hit.is_empty() else (hit.position as Vector3).y

## The pickups his middle swept past since the last frame.
func _touch(point: Vector3) -> void:
	var from := _last if _last != Vector3.INF and _last.distance_to(point) <= 6.0 else point
	_last = point
	for idx in range(_live.size()-1,-1,-1):
		var it: Dictionary = _live[idx]
		var node: Node3D = it.node
		if not is_instance_valid(node) or node.taking: continue
		var size := RARE_SIZE if it.what == "rare" else (GREAT_SIZE if int(it.worth) > 1 else RUNE_SIZE)
		var near := Geometry3D.get_closest_point_to_segment(node.global_position,from,point)
		# (Written so a NaN, a motor gone wild, takes nothing.)
		if not (near.distance_to(node.global_position) < Lines.WALKER_REACH+size*0.5): continue
		_live.remove_at(idx)
		it.state = "taken"
		if it.what == "rare":
			rares_got += 1
			_rare_moment(node)
			rare_taken.emit(rares_got,rares_laid)
		else:
			node.take(hash(node.name) & 0xffff)
			_rune(str(it.src),int(it.worth))

## One rune counted: its blip, climbing with a streak.
func _rune(src: String, worth: int) -> void:
	taken[src] = int(taken.get(src,0))+worth
	_streak = _streak+1 if _since < STREAK else 0
	_since = 0.0
	if _blip != null and _blip.is_inside_tree():
		_blip.pitch_scale = pow(2.0,float(CollectiblesHud.STEPS[mini(_streak,CollectiblesHud.STEPS.size()-1)])/12.0)
		_blip.play()
	rune_taken.emit(src,worth)

## The rare's moment: its spin and wisp, its lamp swelling warm and going
## out, the flourish, a beat of slowed time.
func _rare_moment(node: Node3D) -> void:
	var lamp := node.get_node_or_null("Lamp") as OmniLight3D
	var at := node.global_position
	var tween: Tween = node.take(hash(node.name) & 0xffff,self,false)
	# A light of its own that outlives the token.
	var glow := OmniLight3D.new()
	glow.name = "RareGlow"
	glow.light_color = RARE_LIGHT
	glow.omni_range = MOMENT_RANGE
	glow.light_energy = 0.0
	glow.shadow_enabled = false
	add_child(glow)
	glow.global_position = at+Vector3.UP*0.3
	if lamp != null: lamp.visible = false
	var t := create_tween()
	t.set_ignore_time_scale(true)
	t.tween_property(glow,"light_energy",MOMENT_ENERGY,0.12).set_ease(Tween.EASE_OUT)
	t.tween_property(glow,"light_energy",0.0,MOMENT_LIGHT).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	t.tween_callback(glow.queue_free)
	tween.tween_callback(node.queue_free)
	if _flourish != null and _flourish.is_inside_tree(): _flourish.play()
	_beat()

## A beat of slowed time (real seconds, whatever the scale).
func _beat() -> void:
	if not is_inside_tree(): return
	Engine.time_scale = BEAT_SCALE
	var t := create_tween()
	t.set_ignore_time_scale(true)
	t.tween_interval(BEAT_HOLD)
	t.tween_method(func(s: float) -> void: Engine.time_scale = s,BEAT_SCALE,1.0,BEAT_EASE)

func _exit_tree() -> void:
	Engine.time_scale = 1.0

# --- For checks ----------------------------------------------------------------------

## Counts of what stands, was taken and was dropped, by what.
func state_counts() -> Dictionary:
	var out := {}
	for it: Dictionary in items:
		var k := "%s_%s" % [it.what,it.state]
		out[k] = int(out.get(k,0))+1
	return out


## His small jump (m), the stack's step: the motor's at the wanderer's size.
class KitMotifPilot:
	static var _j := 0.0
	static func jump() -> float:
		if _j == 0.0:
			var p: Object = preload("res://scripts/kit_isle/kit_motif.gd").pilot()
			_j = float(p.jumps[0])
			if p is Node: (p as Node).free()
		return _j
