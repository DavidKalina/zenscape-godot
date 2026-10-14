extends Node3D
## A ruin motif isle placed in another isle's sky (docs/scenic/motif-sky.md):
## one motif (scripts/kit_isle/kit_motif.gd: the bell spires, the cloister
## tarn, the Sundered gorge, the colonnade spine) stood `offset` from its own
## frame, with everything its own scene gives it: its art and ruins, its
## turf (the plane skims, bumps and sets down on it, the pilot walks it),
## its water to wade, its rope bridges underfoot, its grass and flowers
## (scripts/kit_isle/kit_flora.gd), its life (its undergrowth, butterflies,
## fireflies, songbirds, loose leaves and chaff, on-foot tokens) and its live
## bits (the bells). The scene round it (`study`, studies/kit_isle.gd) keeps
## the pilot, the plane, the camera and the look; this node stands in for it
## to the life (`isle_top`, `flora_site`, `_turf`, `_outlines`, `flora`, and
## the study's air, light, weather, pilot and plane passed through).
##
## It comes up in stages (scripts/kit_isle/motif_sky.gd runs them): the art
## built whole on a worker (`start_build`, nothing but nodes off the tree;
## headless, on the main thread in one go, `threaded` off: the dummy
## renderer's mesh and material RIDs are not safe to make on a worker while
## the main thread makes its own, godot#124183), then on the main thread a
## slice a frame within the sky's budget (`work`):
## its parts stood one at a time, its turf registered, its plants grown, its
## life set up. Until the life is up it is drawn and solid but bare.
## The node stands at the world's origin; its art at `offset`; its plants and
## life in the world's frame.
const TURF_LAYER := 1 << 11
## Its ruins' levels of detail, added on its worker once built.
const RuinLod = preload("res://scripts/ruin_lod.gd")
const LateShapes = preload("res://scripts/late_shapes.gd")
const IsleStore = preload("res://scripts/roguelike/isle_store.gd")

## The scene, the motif, where it stands from its own frame.
var study: Node3D
var motif: RefCounted
var offset := Vector3.ZERO
var art: Node3D
## The turf bodies and their outlines (world x, z), as kit_isle keeps its own.
var _turf: Array = []
var _outlines: Array = []
var flora: Node3D
var life: Node3D
## Where it is: "waiting" for its worker, "building" on it, "standing" its
## parts, "turf", "flora", "life", "up".
var stage := "waiting"
var _task := -1
var _staging: Node3D
var _grow: KitFlora.Grow
var _args := PackedStringArray()
## Its art built on a worker (else on the main thread, one frame).
var threaded := true
## Bodies in the tree with shapes still held back (LateShapes).
var _held: Array = []
var _grounded := true
## What each stage cost (ms on the main thread; the art's on its worker).
var timings := {}
## Where its art came from: "built" (here, on a worker or the main thread)
## or "store" (scripts/roguelike/isle_store.gd, loaded on a worker).
var source := ""
## A load's result while its worker runs ({root, ms}).
var _loaded := {}
## Its circle before its turf is registered (x, z its middle, z its reach;
## scripts/kit_isle/motif_sky.gd `places`), INF for none.
var guess := Vector3.INF

# --- What the life and the motif read of their scene, passed through ----------

var _atmosphere: Node:
	get: return study.get("_atmosphere") if study != null else null
var _celestial: RefCounted:
	get: return study.get("_celestial") if study != null else null
var _precipitation: Node3D:
	get: return study.get("_precipitation") if study != null else null
var _motion_time: float:
	get: return float(study.get("_motion_time")) if study != null else 0.0
var camera: Camera3D:
	get: return study.get("camera") if study != null else null
var motor:
	get: return study.get("motor") if study != null else null
var flying: bool:
	get: return bool(study.get("flying")) if study != null else false
var plane_figure: Node3D:
	get: return study.get("plane_figure") if study != null else null
var belfry: Node3D:
	get: return motif.get("belfry") if motif != null else null
var colonnade: Node3D:
	get: return motif.get("colonnade") if motif != null else null

func setup(owner_study: Node3D, owner_motif: RefCounted, at: Vector3, args: PackedStringArray) -> void:
	study = owner_study
	motif = owner_motif
	offset = at
	_args = args
	name = "Motif_"+str(motif.id())
	art = Node3D.new()
	art.name = "Art"
	art.position = offset
	add_child(art)

func _exit_tree() -> void:
	_forget()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE: _forget()

## Its worker waited out, and the art it built freed if it never stood.
func _forget() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	var root: Variant = _loaded.get("root")
	if root is Node and is_instance_valid(root) and (root as Node).get_parent() == null and root != _staging: (root as Node).free()
	_loaded = {}
	if _staging != null and is_instance_valid(_staging) and _staging.get_parent() == null:
		_staging.free()
	_staging = null

# --- Its frame ------------------------------------------------------------------------

func isle_name() -> String:
	return motif.isle_name()

func isle_card() -> Dictionary:
	return motif.isle_card()

## Its datum (world y).
func isle_top() -> float:
	return float(motif.top())+offset.y

func isle_summit() -> Vector3:
	return (motif.summit() as Vector3)+offset

## Its ground as the plants read it, in the world's frame.
func flora_site() -> KitFlora.Site:
	var site := placed_site(motif.flora_site(),offset)
	if looks_past_neighbours: site.looks_past = _neighbour
	return site

## Physics steps it waits once stood before its turf and plants, and when
## it stood.
const SETTLE_STEPS := 2
var _stood_at := -1000

## Whether its plants' rays look past the other motif isles, the Broken
## Viaduct and anything that moves (when those stand or where they are
## depends on how fast the layer loads; the plants should not), reading its
## own ground and stone (whole: SETTLE_STEPS), the base and the stage.
var looks_past_neighbours := false

func _neighbour(collider: Object) -> bool:
	var node := collider as Node
	# Anything that moves (a ferry, a ride, a beast): where it is when the
	# plants grow is a matter of time.
	if node != null and node.get_class() != "StaticBody3D": return true
	while node != null:
		if node == self: return false
		if node.get_script() == get_script(): return true
		# The Broken Viaduct and what stands with it when it is done
		# (scripts/roguelike/layer_hazards.gd `_finish_viaduct`).
		if node.name in [&"BrokenViaduct",&"ViaductStones",&"ViaductUpdrafts"]: return true
		node = node.get_parent()
	return false

## A site in an isle's own frame as it reads standing `by` from it.
static func placed_site(site: KitFlora.Site, by: Vector3) -> KitFlora.Site:
	var out := KitFlora.Site.new()
	out.ray = site.ray+Vector2.ONE*by.y
	out.tufts = site.tufts
	var flat := Vector2(by.x,by.z)
	if site.wear.is_valid(): out.wear = func(p: Vector2) -> float: return float(site.wear.call(p-flat))
	else: out.wear = Callable()
	if site.wet.is_valid(): out.wet = func(p: Vector2) -> bool: return bool(site.wet.call(p-flat))
	else: out.wet = Callable()
	return out

## Its circle (x, z its middle, z its radius; kit_isle `isle_circle`), from
## its turf's outlines once registered, else the motif's own frame's.
func circle() -> Vector3:
	var lo := Vector2(INF,INF)
	var hi := -lo
	for outline: PackedVector2Array in _outlines:
		for p in outline:
			lo = lo.min(p)
			hi = hi.max(p)
	if lo.x == INF: return guess if guess != Vector3.INF else Vector3(isle_summit().x,isle_summit().z,40.0)
	var mid := (lo+hi)*0.5
	var reach := 0.0
	for outline: PackedVector2Array in _outlines:
		for p in outline: reach = maxf(reach,p.distance_to(mid))
	return Vector3(mid.x,mid.y,reach)

## True once it stands whole, its life up.
func is_up() -> bool:
	return stage == "up"

## True once its art stands (solid, drawn).
func stands() -> bool:
	return stage in ["flora","life","up"]

# --- Coming up --------------------------------------------------------------------------

## Its art built on a worker: nodes only, off the tree.
func start_build() -> void:
	if stage != "waiting": return
	stage = "building"
	source = "built"
	_staging = Node3D.new()
	_staging.name = "Staging"
	var built: RefCounted = motif
	var into := _staging
	_task = WorkerThreadPool.add_task(func() -> void:
		built.build(into)
		RuinLod.add(into)
		LateShapes.defer(into),false,"Motif isle "+str(motif.id()))

## Its art loaded from the isle store on a worker (scripts/roguelike/
## isle_store.gd: as its build would leave it, levels and held shapes too);
## if the file can't be read it goes back to "waiting", to be built.
func start_load() -> void:
	if stage != "waiting": return
	stage = "building"
	source = "store"
	var built: RefCounted = motif
	var path := IsleStore.path_of(motif)
	var out := {}
	_loaded = out
	_task = WorkerThreadPool.add_task(func() -> void:
		var began := Time.get_ticks_msec()
		var root := IsleStore.load_art(built,path,out)
		if root != null:
			root.name = "Staging"
			var t := Time.get_ticks_usec()
			LateShapes.defer(root)
			out.defer_us = Time.get_ticks_usec()-t
		out.root = root
		out.ms = Time.get_ticks_msec()-began,true,"Motif isle load "+str(motif.id()))

## Its art built here and now (no worker: tests, captures).
func build_now() -> void:
	if stage == "waiting":
		_staging = Node3D.new()
		var began := Time.get_ticks_msec()
		motif.build(_staging)
		RuinLod.add(_staging)
		LateShapes.defer(_staging)
		timings.build = Time.get_ticks_msec()-began
		stage = "built"
	elif stage == "building":
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_took()
		if stage == "waiting": build_now()

## Whether its worker is busy.
func building() -> bool:
	if stage != "building": return false
	if not WorkerThreadPool.is_task_completed(_task): return true
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	_took()
	return false

## Its worker's art taken: "built", or back to "waiting" if a load failed.
func _took() -> void:
	preload("res://scripts/roguelike/layer_loading.gd").mark("isle art in (%s): %s" % [source,str(motif.id())])
	if source == "store":
		var root: Variant = _loaded.get("root")
		timings.load = int(_loaded.get("ms",0))
		for k: String in _loaded:
			if k.ends_with("_us"): us("load_"+k.trim_suffix("_us"),int(_loaded[k]))
		_loaded = {}
		if root == null:
			push_warning("%s: its kept isle couldn't be read; built instead" % isle_name())
			IsleStore.failed(motif)
			source = "built"
			stage = "waiting"
			return
		_staging = root
		timings.build = 0
		timings.forged = int(motif.built_ms)
	else: timings.build = int(motif.built_ms)
	stage = "built"

## Whether it has main-thread work left (its worker done; or, not
## `threaded`, its art to build).
func wants_work() -> bool:
	return stage in ["built","standing","turf","flora","life"] or (stage == "waiting" and not threaded)

## Works on for about `usec` (-1: to the end): one part stood, its turf, a
## slice of its plants or its life. Answers the stage it reached.
func work(usec: int) -> String:
	var end := Time.get_ticks_usec()+usec
	while true:
		match stage:
			"waiting":
				# Not threaded: the art built here, all of it this frame.
				build_now()
				return stage
			"built":
				motif.set("art",art)
				stage = "standing"
				_work_began = Time.get_ticks_usec()
			"standing":
				var began := Time.get_ticks_usec()
				# A part at a time: what the worker built, into the art at
				# its place; then the big bodies' held shapes, a slice a
				# frame (scripts/late_shapes.gd).
				if _staging != null and _staging.get_child_count() > 0:
					var part := _staging.get_child(0)
					_staging.remove_child(part)
					var t0 := Time.get_ticks_usec()
					art.add_child(part)
					us("stand_add",Time.get_ticks_usec()-t0)
					t0 = Time.get_ticks_usec()
					_held.append_array(LateShapes.held_bodies(part))
					us("stand_held",Time.get_ticks_usec()-t0)
				elif not _held.is_empty():
					var t0 := Time.get_ticks_usec()
					LateShapes.drain(_held,maxi(end-Time.get_ticks_usec(),0) if usec >= 0 else -1)
					us("stand_drain",Time.get_ticks_usec()-t0)
				if _staging != null and _staging.get_child_count() == 0 and _held.is_empty():
					_staging.free()
					_staging = null
					stage = "turf"
					_stood_at = Engine.get_physics_frames()
				var spent := (Time.get_ticks_usec()-began)/1000
				timings.stand = int(timings.get("stand",0))+spent
				timings.stand_worst = maxi(int(timings.get("stand_worst",0)),spent)
				if usec >= 0: return stage
			"turf" when usec >= 0 and looks_past_neighbours and Engine.get_physics_frames() < _stood_at+SETTLE_STEPS:
				# Its last shapes are in the physics space only after a step:
				# its plants' rays wait for all of them.
				return stage
			"turf":
				var t0 := Time.get_ticks_usec()
				_register()
				us("turf",Time.get_ticks_usec()-t0)
				stage = "flora"
			"flora" when _args.has("--no-flora"):
				stage = "life"
			"flora":
				var began := Time.get_ticks_msec()
				if _grow == null:
					var tg := Time.get_ticks_usec()
					_grow = KitFlora.Grow.new(int(motif.flora_seed()),get_world_3d().direct_space_state,_turf,_outlines,flora_site())
					us("flora_new",Time.get_ticks_usec()-tg)
				var t0 := Time.get_ticks_usec()
				var done := _grow.step(maxi(end-Time.get_ticks_usec(),0) if usec >= 0 else -1)
				us("flora_%d" % mini(_grow._phase,2),Time.get_ticks_usec()-t0)
				timings.flora = int(timings.get("flora",0))+Time.get_ticks_msec()-began
				if not done: return stage
				flora = _grow.node
				_grow = null
				var ta := Time.get_ticks_usec()
				add_child(flora)
				us("flora_add",Time.get_ticks_usec()-ta)
				stage = "life"
				print("%s (placed): flora %s grown in %d ms" % [isle_name(),flora.get_meta("counts"),int(timings.flora)])
				preload("res://scripts/roguelike/layer_loading.gd").mark("isle plants grown: "+str(motif.id()))
				if usec >= 0 and Time.get_ticks_usec() > end: return stage
			"life" when life == null and (_args.has("--no-life") or motif.life_script() == null):
				stage = "up"
				preload("res://scripts/roguelike/layer_loading.gd").mark("isle up: "+str(motif.id()))
			"life":
				var began := Time.get_ticks_msec()
				if life == null:
					life = motif.life_script().new()
					life.offset = offset
					life.shares_wind = true
					var tb := Time.get_ticks_usec()
					add_child(life)
					life.begin(self,_args)
					us("life_begin",Time.get_ticks_usec()-tb)
				var t0 := Time.get_ticks_usec()
				var done: bool = life.step(maxi(end-Time.get_ticks_usec(),0) if usec >= 0 else -1)
				us("life",Time.get_ticks_usec()-t0)
				timings.life = int(timings.get("life",0))+Time.get_ticks_msec()-began
				if not done: return stage
				_share_hud()
				stage = "up"
				us("wall_built_to_up",Time.get_ticks_usec()-_work_began)
				preload("res://scripts/roguelike/layer_loading.gd").mark("isle up: "+str(motif.id()))
				print("%s (placed): life in %d ms %s" % [isle_name(),int(timings.life),life.timings])
			_:
				return stage
		if usec >= 0 and Time.get_ticks_usec() > end: return stage
	return stage

## Microseconds by step, for the trace.
var usecs := {}
var _work_began := 0

func us(what: String, n: int) -> void:
	usecs[what] = int(usecs.get(what,0))+n

## Its turf on the turf layer (skimmed, set down on, walked) and kept off
## the plane's stone query (the study's `_turf_rids`); its water for the
## pilot to wade; its rope bridges' resting decks.
func _register() -> void:
	var flat := Vector2(offset.x,offset.z)
	for land: Array in motif.lands:
		var node: Node3D = land[0]
		for turf: StaticBody3D in (KitLand.turf_bodies(node) if bool(land[2]) else [node.get_node("Body")]):
			turf.collision_layer |= TURF_LAYER
			_turf.append(turf)
			var rids: Variant = study.get("_turf_rids") if study != null else null
			if rids is Array: (rids as Array).append(turf.get_rid())
		var outline: PackedVector2Array = land[1] if land[1] != null else node.get_meta("outline")
		var moved := PackedVector2Array()
		for p in outline: moved.append(p+flat)
		_outlines.append(moved)
	var ground: Variant = study.get("ground") if study != null else null
	if ground != null and ground.get("pools") is Array:
		for pool: Dictionary in motif.pools():
			var r: Rect2 = pool.rect
			# Round 9 (docs/design/rim-dragon.md): the pool rides this node, so
			# it tips with the isle when the dragon holds it.
			(ground.pools as Array).append({"rect":Rect2(r.position+flat,r.size),"top":float(pool.top)+offset.y,"node":self,"rest":transform})

## The sky's tokens' readout, which its tokens share (scripts/kit_isle/
## kit_tokens.gd `setup`); null for none.
func token_hud() -> Node:
	var sky: Variant = study.get("sky") if study != null else null
	var sky_tokens: Variant = sky.get("collectibles") if sky != null else null
	return sky_tokens.get("hud") if sky_tokens != null else null

## One readout for its tokens and the sky's (as kit_isle `_add_life`).
func _share_hud() -> void:
	var shared := token_hud()
	if life.tokens != null and shared != null and life.tokens.hud != shared:
		life.tokens.hud.queue_free()
		life.tokens.hud = shared

# --- Each frame -------------------------------------------------------------------------

## Its bells (the motif's live bits), its life within LIFE_NEAR m of the eye
## (beyond, the life holds still), the pilot's landings and the plane's
## passes.
const LIFE_NEAR := 320.0

func advance(delta: float, eye: Vector3) -> void:
	if not stands() or study == null: return
	motif.frame(delta,self)
	var m: Variant = motor
	if not flying and m != null:
		var grounded: bool = m.grounded
		if grounded and not _grounded: motif.landed(m.feet)
		_grounded = grounded
	elif flying and study.get("plane") != null:
		motif.plane_near(study.plane.position)
	if life != null and is_up():
		var c := circle()
		var gap := Vector2(eye.x-c.x,eye.z-c.y).length()-c.z
		if gap < LIFE_NEAR:
			life.advance(delta,maxf(gap,0.0))
			life.step_pilot()
