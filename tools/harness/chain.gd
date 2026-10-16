extends "res://tools/harness/drive.gd"
## Chain trials on a motif, in the motif yard (studies/motif_yard.tscn,
## the fast place to prove a chain) or in a full layer (studies/run_layer.tscn,
## the one confirmation): the plumbing every motif's chain driver repeated.
## Extend it, write `drive()` and a trial function:
##
##   extends "res://tools/harness/chain.gd"
##   func drive() -> void:
##   	await open_motif("plumb_well")              # the yard, or --in=layer
##   	await trials(arg_int("trials",10),column)   # ROW per trial, RESULT {passed, trials}
##   func column(t: Dictionary) -> Dictionary:
##   	await place(motif_point(Vector3(0,35,5.5))+t.jitter,Vector2(0,1))
##   	...drive him through the real input (stick, jump, walk_to)...
##   	return {"ok":landed,"why":"..."}
##
##   python tools/drive.py scratch/x_chain.gd -- --trials=10 --scene-args --motif=plumb_well [--grey] [--bodies=0] [--rims]
##   python tools/drive.py scratch/x_chain.gd --timeout 1200 -- --in=layer --trials=10 --scene-args --seed=4 --shape=sprawl --knob=pool=classic [--grey] [--knob=bodies=0]
##
## Driver args: `--in=yard|layer` (yard), `--trials=N`, `--trial-seed=N` (the
## jitter's dice, 1). Scene args go to the scene; in the layer the helper
## adds `--knob=greybox=<slug>` if no greybox knob is given and turns
## `--grey` into the motif's own grey flag (the yard does that itself), so
## the turf-vs-grey A/B is the same command with and without --grey.
##
##   motif_index(slug)    its isle in the plan (study.layer.isles), -1 none
##   motif_offset(slug)   its offset (world = its own frame + this)
##   motif_point(p, slug) a point of its own frame in the world
##   motif_start(slug)    its start (the motif's `start()`), in the world
##   motif_isle(slug)     its placed isle (scripts/kit_isle/motif_isle.gd)
##   motif_host(slug)     its live host (scripts/roguelike/layer_greybox.gd
##                        Isle: .traps (a TrapField, .traps), .pieces (ropes))
##   motif_heads(slug)    its inhaler heads now (in its `heads()` order; a
##                        reset makes them again, so ask after one)
##   motif_floor(slug)    its lowest solid (world y)
##   motif_box(rect, bottom, top, slug)
##                        a rect of its frame (x, z) as a world AABB
##   hold_layer()         run_layer only: no run loop, the void far down,
##                        the motif's isle stood now (the yard needs none)
##   reset_all()          the stage as built (traps, heads and their
##                        bodies, cannons, the greybox's bits), him at the
##                        motif's start
##   trials(n, fn, jitter, delay)
##                        n times: reset_all, `delay` s (a range) of the
##                        real loop with him parked at the start (the
##                        traps and heads run), then `fn.call(t)` with
##                        t = {i, jitter (a Vector3, +-jitter m in x and z),
##                        delay}; fn returns {ok, ...} (or a bool). A ROW a
##                        trial; RESULT gets passed, trials, rate.
##   walk_motif_paths(opts)  drive.gd walk_paths on the motif, in the world
##   rest(region, frames, most)
##                        waits till he comes to rest (grounded, still, not
##                        in a cannon) for `frames`, at most `most` frames:
##                        where he rested, or Vector3.INF; `region` an AABB
##                        (world) he must rest in, or AABB() for anywhere.
const Registry = preload("res://scripts/kit_isle/greybox/registry.gd")
const YARD := "studies/motif_yard.tscn"
const LAYER := "studies/run_layer.tscn"
## Each greybox motif's own grey flag (studies/motif_yard.gd GREY_FLAGS).
const GREY_FLAGS := {
	"sunken_giant":"--giant-grey","wardens_well":"--wardens-well-grey","lidstack":"--lidstack-grey",
	"plumb_well":"--well-grey","vigil_bellows":"--vigil-grey","noon_weir":"--weir-grey",
}
## How far under the motif's lowest solid a trial's fall counts as lost.
const LOST_UNDER := 30.0

## The motif the trials are on.
var slug := ""
## Where: "yard" or "layer".
var where := "yard"
## True if the scene args asked for the motif's grey look.
var grey := false
## When the scene was asked for (ms since start).
var opened_ms := 0
## When it stood (ms since start).
var stood_ms := 0
var _rng := RandomNumberGenerator.new()

## Opens the yard (or, with --in=layer, run_layer) on motif `motif_slug`
## (default the scene args' --motif=), stands it and holds the layer.
## Returns false (and a FAIL line) if the motif isn't there.
func open_motif(motif_slug := "") -> bool:
	where = str(arg("in","yard"))
	slug = motif_slug if motif_slug != "" else str(arg("motif","")).trim_prefix("gb_")
	var given := PackedStringArray(scene_args())
	grey = given.has("--grey") or (GREY_FLAGS.has(slug) and given.has(GREY_FLAGS[slug]))
	var scene := YARD
	if where == "layer":
		scene = LAYER
		var out := PackedStringArray()
		var knobbed := false
		for a: String in given:
			if a == "--grey": continue
			if a.begins_with("--motif="): continue
			if a.begins_with("--knob=greybox="): knobbed = true
			out.append(a)
		if not knobbed: out.append("--knob=greybox="+slug)
		if grey and GREY_FLAGS.has(slug) and not out.has(GREY_FLAGS[slug]): out.append(GREY_FLAGS[slug])
		given = out
	elif not given.has("--motif="+slug):
		given.append("--motif="+slug)
	var began := Time.get_ticks_msec()
	opened_ms = began-_began
	var ready := await open(scene,given)
	if ready < 0: return false
	if motif_index() < 0:
		check(false,"%s in the %s" % [slug,where],"no isle gb_%s in the plan (in the layer: try another seed or --knob=pool=classic)" % slug)
		return false
	hold_layer()
	stood_ms = Time.get_ticks_msec()-_began
	result("motif",slug)
	result("in",where)
	result("grey",grey)
	result("stood_s",snappedf((Time.get_ticks_msec()-began)/1000.0,0.1))
	say("%s (%s) stood in the %s at %s in %.1f s" % [slug,"grey" if grey else "turf",where,str(motif_offset()),(Time.get_ticks_msec()-began)/1000.0])
	return true

# --- Finding the motif ------------------------------------------------------------------

func _plan() -> Dictionary:
	var p: Variant = study.get("layer") if study != null else null
	return p if p is Dictionary else {}

## Its isle's index in the plan (study.layer.isles), -1 if none.
func motif_index(s := "") -> int:
	var id := "gb_"+(s if s != "" else slug)
	var isles: Array = _plan().get("isles",[])
	for i in range(isles.size()):
		if str(isles[i].id) == id: return i
	return -1

## Its offset: world = its own frame + this.
func motif_offset(s := "") -> Vector3:
	var i := motif_index(s)
	return (_plan().isles[i].offset as Vector3) if i >= 0 else Vector3.ZERO

## Point `p` of the motif's own frame (its table's numbers), in the world.
func motif_point(p: Vector3, s := "") -> Vector3:
	return p+motif_offset(s)

## The motif (its script's instance in the plan), or null.
func motif(s := "") -> RefCounted:
	var i := motif_index(s)
	return _plan().isles[i].motif if i >= 0 else null

## Its start (the motif's `start()`), in the world.
func motif_start(s := "") -> Vector3:
	var m := motif(s)
	return motif_point(m.start(),s) if m != null and m.has_method("start") else motor.feet

## Its placed isle (scripts/kit_isle/motif_isle.gd), or null.
func motif_isle(s := "") -> Node3D:
	var m := motif(s)
	var sky: Variant = study.get("sky")
	var holder: Variant = study.get("motifs")
	if holder == null and sky != null: holder = sky.get("motifs")
	if holder == null or m == null: return null
	for isle: Node3D in holder.isles:
		if isle.motif == m: return isle
	return null

## Its live greybox host (.traps, .pieces), or null.
func motif_host(s := "") -> Node3D:
	var stage: Variant = study.get("stage")
	if stage == null or stage.greybox == null: return null
	var i := motif_index(s)
	for h: Node3D in stage.greybox.hosts:
		if int(h.index) == i: return h
	return null

## Its inhaler heads in the field now, in the motif's `heads()` order (null
## where one is gone).
func motif_heads(s := "") -> Array:
	var out: Array = []
	var stage: Variant = study.get("stage")
	if stage == null: return out
	var i := motif_index(s)
	for h: Dictionary in _plan().get("heads",[]):
		if int(h.isle) != i: continue
		var found: Node3D = null
		for e in stage.enemies.enemies:
			if is_instance_valid(e) and e.has_method("home") and (e.home() as Vector3).distance_to(h.at) < 0.5 and not e.gone: found = e
		out.append(found)
	return out

## The stage's cannon field (scripts/cannon/cannon_field.gd).
func cannons() -> Node3D:
	var stage: Variant = study.get("stage")
	return stage.cannons if stage != null else null

## The motif's lowest solid (world y).
func motif_floor(s := "") -> float:
	var i := motif_index(s)
	if i < 0: return -INF
	var lo := INF
	for v: float in _plan().isles[i].occ.lo: if v < INF: lo = minf(lo,v)
	return lo+(_plan().isles[i].offset as Vector3).y

# --- Holding the layer, resetting it ------------------------------------------------------

## In run_layer: the run loop dropped (its void card would lay a new layer
## on a fall), the void far down (so a fall is only a fall), and the
## motif's isle stood now (its neighbours come up as he nears them, as in
## play). In the yard there is nothing to hold.
func hold_layer() -> void:
	if where != "layer": return
	var loop: Variant = study.get("run_loop")
	if loop != null:
		(loop as Node).get_parent().remove_child(loop)
		(loop as Node).free()
		study.set("run_loop",null)
	var plan := _plan()
	plan.void_y = -100000.0
	study.set("lost",-100000.0)
	var isle := motif_isle()
	if isle != null and not isle.stands():
		isle.build_now()
		while str(isle.stage) in ["built","standing"]: isle.work(1 << 30)

## Everything as built, him parked at the motif's start, nothing held.
func reset_all() -> void:
	let_go()
	var stage: Variant = study.get("stage")
	if stage != null:
		stage.reset()
		var heads: Variant = stage.get("heads")
		var spawner: Variant = heads.get("spawner") if heads != null else null
		if spawner != null:
			for h: Dictionary in spawner.heads:
				h.body = null
				h.bodiless = 0.0
				h.mode = ""
	if study.has_method("_end_fall"): study._end_fall()
	await place(motif_start(),_start_face())
	# A frame for the heads and traps made again.
	await frames(1)

## Facing in off the motif's way-in rim.
func _start_face() -> Vector2:
	var i := motif_index()
	for s: Dictionary in _plan().isles[i].sockets:
		if s.kind == "rim":
			var f: Vector3 = s.face
			return -Vector2(f.x,f.z).normalized()
	return Vector2(0.0,-1.0)

# --- Trials ---------------------------------------------------------------------------------

## `n` trials of `fn` (see the header). Returns how many passed.
func trials(n: int, fn: Callable, jitter := 0.5, delay := Vector2(0.8,1.2)) -> int:
	_rng.seed = arg_int("trial-seed",1)
	var passed := 0
	var began := Time.get_ticks_msec()
	for i in range(n):
		await reset_all()
		var d := _rng.randf_range(delay.x,delay.y)
		await frames(int(round(d*60.0)))
		var j := Vector3(_rng.randf_range(-jitter,jitter),0.0,_rng.randf_range(-jitter,jitter))
		var f0 := frame
		var w0 := Time.get_ticks_msec()
		var out: Variant = await fn.call({"i":i,"jitter":j,"delay":d})
		let_go()
		var r: Dictionary = out if out is Dictionary else {"ok":bool(out)}
		var ok := bool(r.get("ok",false))
		if ok: passed += 1
		var line := {"trial":i,"ok":ok,"motif":slug,"in":where,"grey":grey,"delay":snappedf(d,0.01),"jitter":j,
			"game_s":snappedf((frame-f0)/60.0,0.1),"wall_s":snappedf((Time.get_ticks_msec()-w0)/1000.0,0.1)}
		line.merge(r,false)
		row(line)
	result("passed",passed)
	result("trials",n)
	result("rate","%d/%d" % [passed,n])
	result("trials_s",snappedf((Time.get_ticks_msec()-began)/1000.0,0.1))
	note("%s (%s, %s): %d/%d in %.0f s of trials, %.0f s in all" % [slug,"grey" if grey else "turf",where,passed,n,(Time.get_ticks_msec()-began)/1000.0,(Time.get_ticks_msec()-_began)/1000.0])
	return passed

## Waits till he rests (grounded, still on the flat, in no cannon) for
## `still` frames running, at most `most` frames, or falls LOST_UNDER under
## the motif: where he rested (and if `region` is given, only in it), or
## Vector3.INF.
func rest(region := AABB(), still := 20, most := 1800) -> Vector3:
	var run := 0
	var floor_y := motif_floor()-LOST_UNDER
	for k in range(most):
		var v: Vector3 = motor.velocity
		var calm: bool = motor.grounded and Vector2(v.x,v.z).length() < 0.3 and motor.rider == null
		if calm and region.size != Vector3.ZERO and not region.grow(0.01).has_point(motor.feet): calm = false
		run = run+1 if calm else 0
		if run >= still: return motor.feet
		if motor.feet.y < floor_y: return Vector3.INF
		await frames(1)
	return Vector3.INF

## Walks the motif's paths (drive.gd `walk_paths`: its `walks()`, else its
## worn `paths()`), moved into the world: {name: route summary}.
func walk_motif_paths(opts := {}, s := "") -> Dictionary:
	return await walk_paths(motif(s),motif_offset(s),opts)

## A rect of the motif's frame (x, z), from `bottom` to `top` (its y), as a
## world AABB.
func motif_box(rect: Rect2, bottom: float, top: float, s := "") -> AABB:
	var o := motif_offset(s)
	return AABB(Vector3(rect.position.x+o.x,bottom+o.y,rect.position.y+o.z),Vector3(rect.size.x,top-bottom,rect.size.y))
