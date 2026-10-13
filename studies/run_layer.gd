extends "res://studies/aqueduct_isle.gd"
## One generated layer of the climb, played on foot (docs/design/roguelike/
## layer-round2.md, layer-round3.md): the aqueduct isle (studies/
## aqueduct_isle.gd: its look, light, weather, life and sky, unchanged) as
## the base, and round it a layer laid out from a seed (scripts/roguelike/
## layer_plan.gd): 2 or 3 neighbourhoods of ruin motif isles, each a few
## isles joined rim to rim by stones, rope bridges and the Loose Voussoirs,
## a gulf of open sky between two, crossed on a rune serpent's loop or the
## sky folk's ferry (and a cannon where it is narrow enough), along a route
## to the exit gate on the last neighbourhood's highest isle; a greed
## branch to a rune set (hard stones, and a cannon where a shot lands it),
## the Plinth Ram on an arena (scripts/roguelike/layer_stage.gd,
## layer_rides.gd). The isles are built on a worker and stood a slice a
## frame by the sky (studies/run_layer_sky.gd, scripts/kit_isle/
## motif_sky.gd), nearest first, so the pilot walks the base at once; a
## gulf's rides open once the isles at both its ends stand.
##
## Through the gate, or down into the void under every isle, a new layer
## comes up (the next seed); a fall onto a lower isle is just a fall.
## Under --shape=sprawl it is a run (scripts/roguelike/run_loop.gd, docs/
## design/roguelike/stakes-experiment.md): the gate a layer deeper, the
## runes carried; the void the run's end, its card, then a new climb from
## layer 1 (Space) or the same again (R); each layer begun at a start spot,
## the way on lit; I shows the long card.
##   N / Shift+N   the next / previous seed's layer
##   Backspace     this layer again
##   godot --path . res://studies/run_layer.tscn -- --no-title [--seed=<n>]
##     [--knob=gulf=<m>] [--knob=hoods=<2|3>] [--knob=ride=<serpent|ferry>]
##     [--shape=sprawl]  (scripts/roguelike/layer_sprawl.gd: an exit side, a
##     chain of crossings out to the gate, the next region seen far off)
##     [--knob=arrows=<n>] [--knob=viaduct=<0|1>]  (the sprawl's gust-arrow
##     perches, the ring's too, and the Broken Viaduct: scripts/roguelike/
##     layer_hazards.gd)
##     [--knob=heads=<n>]  (the inhaler heads, sprawl and ring: scripts/
##     roguelike/layer_enemies.gd; 0 none)
## Without --seed= a seed is drawn. The isle's own flags still work; the
## hall chain and the lodestone are left out, and the aqueduct isle's own
## dragon's roost. Under the sprawl a layer has its own roost
## (LayerSprawl `plan.roost`, docs/design/roguelike/layer-round5-roost.md):
## the roost motif stood apart and high, its dragon curled asleep on its
## ledge (`_stand_roost`; his wake's circuit is the aqueduct isle's sky's,
## so he never wakes here).
const LayerPlan = preload("res://scripts/roguelike/layer_plan.gd")
const LayerStage = preload("res://scripts/roguelike/layer_stage.gd")
const RunLayerSky = preload("res://studies/run_layer_sky.gd")
const LayerSprawl = preload("res://scripts/roguelike/layer_sprawl.gd")
const RoostMotif = preload("res://scripts/kit_isle/motif_dragon_roost.gd")
const RunLoop = preload("res://scripts/roguelike/run_loop.gd")
const LayerShapes = preload("res://scripts/roguelike/layer_shapes.gd")

## Seeds tried past a seed whose plan could not be laid.
const SKIP_MOST := 8
## The plan, its stage, and what stood in the slot before any layer.
static var layer_seed := -1
## The layer's knobs (`--knob=`, LayerPlan KNOBS), kept from layer to layer.
static var layer_knobs := {}
## The layer's shape (`--shape=`): "" round 3's, "sprawl" LayerSprawl's,
## "ring" LayerRing's; a run's first (scripts/roguelike/layer_shapes.gd: a
## run alternates sprawl and ring by depth).
static var layer_shape := ""
## The shape the layer asked for is laid in ("": `layer_shape`).
var shape_asked := ""
var layer: Dictionary = {}
var stage: Node3D = null
var _slot_was: Node = null
var _card: Label
## When the layer was asked for (ms) and how long its isles took to stand.
var _layer_asked := 0
var layer_up_ms := -1
var plan_ms := 0
## Layers played this run, and why the last one ended.
var layers := 0
var last_end := ""
## Windowed, a plan (1-8 s) is laid on a worker while the last layer stays
## (`request_layer`); headless or scripted, at once.
var _plan_task := -1
var _plan_out: Dictionary = {}
var _plan_why := ""
## Under --shape=sprawl, the run: a climb from layer 1, the void its end
## (scripts/roguelike/run_loop.gd); null in round 3's shape.
var run_loop: Node = null

func _ready() -> void:
	if layer_seed < 0:
		for arg in preload("res://scripts/launch_args.gd").user_args():
			if arg.begins_with("--seed="): layer_seed = int(arg.get_slice("=",1))
			if arg.begins_with("--shape="): layer_shape = arg.get_slice("=",1)
		layer_knobs = LayerPlan.knobs_from(preload("res://scripts/launch_args.gd").user_args())
		if layer_seed < 0:
			var rng := RandomNumberGenerator.new()
			rng.randomize()
			layer_seed = rng.randi_range(1,99999)
	chain_on = false
	dragon_roost = false
	_no_lode = true
	if _planning_away():
		# Laid while the aqueduct isle builds; its sky starts empty.
		LayerPlan.warm()
		_plan_task = WorkerThreadPool.add_task(_plan_job.bind(layer_seed,layer_knobs.duplicate()),true,"layer plan")
	else: _lay(layer_seed)
	isle_ready.connect(_first_layer,CONNECT_ONE_SHOT)
	super._ready()

func sky_script() -> Script:
	return RunLayerSky

## The layer's plan for `seed_value` (on past a seed that can't be laid).
func _lay(seed_value: int) -> void:
	_take(_plan_for(seed_value,layer_knobs,shape_asked))

## A plan for `seed_value` and on: {plan, ms}. Touches nothing of the
## scene's (a worker lays it, `_plan_job`).
static func _plan_for(seed_value: int, knobs: Dictionary, shape := "") -> Dictionary:
	var began := Time.get_ticks_msec()
	var plan := {}
	for k in range(SKIP_MOST):
		plan = LayerShapes.make(shape if shape != "" else layer_shape,seed_value+k,knobs)
		if (plan.problems as Array).is_empty(): break
		print("run layer: seed %d can't be laid (%s), on to the next" % [seed_value+k,str(plan.problems)])
	return {"plan":plan,"ms":Time.get_ticks_msec()-began}

func _plan_job(seed_value: int, knobs: Dictionary, shape := "") -> void:
	_plan_out = _plan_for(seed_value,knobs,shape)

func _take(laid: Dictionary) -> void:
	layer = laid.plan
	layer_seed = int(layer.seed)
	plan_ms = int(laid.ms)
	lost = float(layer.void_y)-200.0
	print("run layer: seed %d planned in %d ms\n%s" % [layer_seed,plan_ms,LayerPlan.describe(layer)])

## Whether plans are laid on a worker (windowed play; --plan-away asks for
## it headless too).
func _planning_away() -> bool:
	if scripted: return false
	return DisplayServer.get_name() != "headless" or preload("res://scripts/launch_args.gd").user_args().has("--plan-away")

## The layer for `seed_value` asked for: at once headless or scripted;
## windowed, laid on a worker and stood up when it's ready (one at a
## time: asked again meanwhile, the ask is dropped). In `shape` ("": the
## run's first, `layer_shape`).
func request_layer(seed_value: int, why := "", shape := "") -> void:
	if not _planning_away():
		shape_asked = shape
		start_layer(seed_value,why)
		return
	if _plan_task >= 0: return
	_plan_why = why
	_show_toast("%sLaying layer %d..." % [why+"  " if why != "" else "",seed_value])
	shape_asked = shape
	_plan_task = WorkerThreadPool.add_task(_plan_job.bind(seed_value,layer_knobs.duplicate(),shape),true,"layer plan")

## The layer's motif isles for the sky: [motif, offset, place].
func layer_entries() -> Array:
	var out: Array = []
	for isle: Dictionary in layer.get("isles",[]):
		if isle.role == "base": continue
		var r: Rect2 = LayerPlan._rect(isle)
		var c := r.get_center()
		out.append([isle.motif,isle.offset,[isle.id,Vector3(c.x,LayerPlan._span(isle).y,c.y),r.size.length()*0.5]])
	# The dragon's roost, apart (the sprawl's): the furthest from the eye, so
	# stood after the isles he walks.
	var roost: Dictionary = layer.get("roost",{})
	if not roost.is_empty():
		var at: Vector3 = roost.at
		out.append([RoostMotif.new(),roost.offset,[roost.id,Vector3(at.x,LayerPlan._span(roost).y,at.z),float(roost.reach)]])
	return out

func _first_layer() -> void:
	_slot_was = foot_pieces
	_build_card()
	if LayerShapes.RUN.has(layer_shape):
		run_loop = RunLoop.new()
		add_child(run_loop)
		run_loop.setup(self)
		_card.visible = false
	# Laid on a worker while the isle built: stood up once it's done
	# (`_process`; never waited for here: the worker's servers' calls wait
	# on this thread).
	if layer.is_empty(): return
	_stand_layer()

## The stage built and the pilot at the spawn.
func _stand_layer() -> void:
	_layer_asked = Time.get_ticks_msec()
	layer_up_ms = -1
	# The study's own net (back to the isle's station) only far under the
	# void, which ends the layer first.
	lost = float(layer.void_y)-200.0
	stage = LayerStage.new()
	add_child(stage)
	stage.setup(self,layer,_slot_was)
	LayerShapes.dress(stage,layer)
	_stand_roost()
	stage.rune_taken.connect(func(_left: int) -> void: _update_card())
	var spawn: Dictionary = layer.spawn
	var face: Vector3 = spawn.face
	start = spawn.at
	# Set down on the turf there (the run-up climbs a little behind its rim).
	var at: Vector3 = spawn.at
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*4.0,at+Vector3.DOWN*4.0,1|TURF_LAYER))
	if not hit.is_empty(): start = (hit.position as Vector3)+Vector3.UP*0.05
	start_face = Vector2(face.x,face.z).normalized()
	_end_fall()
	respawn()
	_last_stood = start
	layers += 1
	if run_loop != null: run_loop.layer_stood()
	_update_card()

## A new layer from `seed_value`: the old isles and stage freed, the new
## planned, the sky's isles made again, the pilot at its spawn.
func start_layer(seed_value: int, why := "", laid := {}) -> void:
	last_end = why
	var old: Array = sky.motifs.isles.duplicate() if sky != null and sky.motifs != null else []
	if stage != null:
		foot_pieces = _slot_was
		remove_child(stage)
		stage.free()
		stage = null
	if laid.is_empty(): _lay(seed_value)
	else: _take(laid)
	if sky != null:
		sky.restart(layer_entries())
		# The old isles' water no longer stands.
		var pools: Variant = ground.get("pools")
		if pools is Array:
			for i in range((pools as Array).size()-1,-1,-1):
				var p: Dictionary = pools[i]
				if p.has("node") and (not is_instance_valid(p.node) or old.has(p.node)): (pools as Array).remove_at(i)
	_stand_layer()
	if why != "" and run_loop == null: _show_toast(why)

# --- The dragon's roost (the sprawl's) ------------------------------------------

## The roost's dragon asleep on his ledge (scripts/dragon_roost.gd, its
## offset the layer's roost's) and the air round the mountain (scripts/
## roost_air.gd: its wreath, haze, cold, birds and the crashed plane), as
## the aqueduct isle's own (`_build_roost_dragon`) but without his wake: its
## circuit is laid over the aqueduct isle's sky's isles, not a layer's. The
## study's `_roost_frame` shows them once the mountain stands. The clouds
## thin away over it too (studies/run_layer_sky.gd `keep_roost`).
func _stand_roost() -> void:
	var roost: Dictionary = layer.get("roost",{})
	if sky != null and sky.has_method("keep_roost"): sky.keep_roost(roost)
	if roost.is_empty():
		_drop_roost()
		return
	var began := Time.get_ticks_msec()
	# Laid once; a new layer's roost moves him (and his air) there.
	if roost_dragon != null and is_instance_valid(roost_dragon):
		roost_dragon.roost.move_to(roost.offset)
		roost_air.move_to(roost.offset)
		roost_dragon.visible = false
		roost_air.visible = false
		roost_ms = Time.get_ticks_msec()-began
		return
	roost_dragon = SkyDragon.new()
	roost_dragon.name = "RoostDragon"
	roost_dragon.sky_scene = self
	add_child(roost_dragon)
	var pose: RefCounted = DragonRoost.new()
	pose.set("offset",roost.offset)
	roost_dragon.setup_roost(camera,pose)
	roost_air = RoostAir.new()
	roost_air.set("offset",roost.offset)
	add_child(roost_air)
	roost_air.setup()
	# Hidden till his mountain stands (`_roost_frame`).
	roost_dragon.visible = false
	roost_air.visible = false
	roost_ms = Time.get_ticks_msec()-began
	print("run layer: the roost's dragon laid in %d ms" % roost_ms)

## How long the roost's dragon and air took to lay or move (ms, main
## thread).
var roost_ms := 0

func _drop_roost() -> void:
	for node: Node in [roost_dragon,roost_air]:
		if node != null and is_instance_valid(node):
			remove_child(node)
			node.free()
	roost_dragon = null
	roost_air = null

# --- The loop -------------------------------------------------------------------

func tick(delta: float) -> void:
	if run_loop != null and not run_loop.before_tick(delta): return
	super.tick(delta)
	if stage == null or flying: return
	if run_loop != null:
		run_loop.after_tick(delta)
		return
	if stage.at_exit(motor.feet):
		request_layer(layer_seed+1,"Through the gate: layer %d" % (layer_seed+1))
	elif motor.feet.y < float(layer.void_y):
		request_layer(layer_seed+1,"Into the void: layer %d" % (layer_seed+1))
		# Laid on a worker: back at this one's spawn meanwhile.
		if _plan_task >= 0: respawn()

## Down off the edge he falls till he lands (a lower isle) or the void
## takes him; never stranded back to the plane.
func _strand() -> void:
	pass

var _card_due := 0.0

func _process(delta: float) -> void:
	super._process(delta)
	if _plan_task >= 0 and _card != null and WorkerThreadPool.is_task_completed(_plan_task):
		WorkerThreadPool.wait_for_task_completion(_plan_task)
		_plan_task = -1
		if stage != null: start_layer(int(_plan_out.plan.seed),_plan_why,_plan_out)
		else:
			# The first: its isles into the sky, then stood.
			_take(_plan_out)
			sky.restart(layer_entries())
			_stand_layer()
	_card_due -= delta
	if _card_due <= 0.0:
		_card_due = 0.5
		_update_card()
	if layer_up_ms < 0 and sky != null and sky.motifs != null and sky.motifs.all_stood():
		layer_up_ms = Time.get_ticks_msec()-_layer_asked
		print("run layer: seed %d stood whole in %d ms (planned in %d ms)" % [layer_seed,layer_up_ms,plan_ms])
		_update_card()

func _unhandled_input(event: InputEvent) -> void:
	if run_loop != null and run_loop.input(event): return
	if event is InputEventKey and event.pressed and not event.echo and walk_ready and stage != null:
		var key := event as InputEventKey
		match key.keycode:
			KEY_N:
				request_layer(maxi(layer_seed+(-1 if key.shift_pressed else 1),1),"",LayerShapes.after(layer))
				return
			KEY_BACKSPACE:
				request_layer(layer_seed,"",LayerShapes.shape_of(layer))
				return
	super._unhandled_input(event)

# --- The card -------------------------------------------------------------------

func _build_card() -> void:
	var holder := CanvasLayer.new()
	holder.name = "LayerCard"
	add_child(holder)
	_card = Label.new()
	_card.add_theme_font_size_override("font_size",18)
	_card.add_theme_color_override("font_color",Color("fbf6ea"))
	_card.add_theme_color_override("font_shadow_color",Color(0,0,0,0.75))
	_card.position = Vector2(16.0,12.0)
	holder.add_child(_card)

func _update_card() -> void:
	if _card == null or layer.is_empty(): return
	# Each neighbourhood's isles, the gulf (and its rides) after it.
	var parts := PackedStringArray()
	for h in range((layer.hoods as Array).size()):
		var names := PackedStringArray()
		for i: int in layer.hoods[h]:
			var isle: Dictionary = layer.isles[i]
			names.append(str(isle.id).replace("_"," ")+(" (greed)" if isle.role == "greed" else ""))
		parts.append(", ".join(names))
		if h < (layer.gulfs as Array).size():
			var e: Dictionary = layer.edges[layer.gulfs[h]]
			parts.append("~ %.0f m gulf: %s%s ~" % [float(e.width),str(e.ride),", cannon" if not (e.get("cannon",{}) as Dictionary).is_empty() else ""])
	var up := "standing up..." if layer_up_ms < 0 else "up in %.1f s" % (layer_up_ms/1000.0)
	var runes := "runes %d/%d" % [stage.taken,LayerPlan.RUNES] if stage != null else ""
	var ride := ""
	if stage != null and stage.rides != null and motor != null: ride = stage.rides.schedule(motor.feet)
	var shaped := LayerShapes.card(layer)
	if shaped != "": parts.append(shaped)
	_card.text = "Layer · seed %d  ·  %s  ·  %s\n%s\n%sN next seed · Shift+N previous · Backspace again" % [layer_seed,runes,up,"\n".join(parts),ride+"\n" if ride != "" else ""]
