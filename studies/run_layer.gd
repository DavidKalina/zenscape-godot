extends "res://studies/aqueduct_isle.gd"
## One generated layer of the climb, played on foot (docs/design/roguelike/
## layer-round2.md): the aqueduct isle (studies/aqueduct_isle.gd: its look,
## light, weather, life and sky, unchanged) as the base, and round it a
## layer laid out from a seed (scripts/roguelike/layer_plan.gd): 3 or 4
## ruin motif isles stepping up off it, joined rim to rim by stones, rope
## bridges and the Loose Voussoirs along a route to the exit gate on the
## highest, a greed branch to a rune set (hard stones, and a cannon where a
## shot lands it), the Plinth Ram on an arena (scripts/roguelike/
## layer_stage.gd). The isles are built on a worker and stood a slice a
## frame by the sky (studies/run_layer_sky.gd, scripts/kit_isle/
## motif_sky.gd), so the pilot walks the base at once.
##
## Through the gate, or down into the void under every isle, a new layer
## comes up (the next seed); a fall onto a lower isle is just a fall.
##   N / Shift+N   the next / previous seed's layer
##   Backspace     this layer again
##   godot --path . res://studies/run_layer.tscn -- --no-title [--seed=<n>]
## Without --seed= a seed is drawn. The isle's own flags still work; the
## hall chain, the lodestone and the dragon's roost are left out.
const LayerPlan = preload("res://scripts/roguelike/layer_plan.gd")
const LayerStage = preload("res://scripts/roguelike/layer_stage.gd")
const RunLayerSky = preload("res://studies/run_layer_sky.gd")

## Seeds tried past a seed whose plan could not be laid.
const SKIP_MOST := 8
## The plan, its stage, and what stood in the slot before any layer.
static var layer_seed := -1
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

func _ready() -> void:
	if layer_seed < 0:
		for arg in preload("res://scripts/launch_args.gd").user_args():
			if arg.begins_with("--seed="): layer_seed = int(arg.get_slice("=",1))
		if layer_seed < 0:
			var rng := RandomNumberGenerator.new()
			rng.randomize()
			layer_seed = rng.randi_range(1,99999)
	chain_on = false
	dragon_roost = false
	_no_lode = true
	_lay(layer_seed)
	isle_ready.connect(_first_layer,CONNECT_ONE_SHOT)
	super._ready()

func sky_script() -> Script:
	return RunLayerSky

## The layer's plan for `seed_value` (on past a seed that can't be laid).
func _lay(seed_value: int) -> void:
	var began := Time.get_ticks_msec()
	for k in range(SKIP_MOST):
		layer = LayerPlan.make(seed_value+k)
		if (layer.problems as Array).is_empty(): break
		print("run layer: seed %d can't be laid (%s), on to the next" % [seed_value+k,str(layer.problems)])
	layer_seed = int(layer.seed)
	plan_ms = Time.get_ticks_msec()-began
	lost = float(layer.void_y)-200.0
	print("run layer: seed %d planned in %d ms\n%s" % [layer_seed,plan_ms,LayerPlan.describe(layer)])

## The layer's motif isles for the sky: [motif, offset, place].
func layer_entries() -> Array:
	var out: Array = []
	for isle: Dictionary in layer.isles:
		if isle.role == "base": continue
		var r: Rect2 = LayerPlan._rect(isle)
		var c := r.get_center()
		out.append([isle.motif,isle.offset,[isle.id,Vector3(c.x,LayerPlan._span(isle).y,c.y),r.size.length()*0.5]])
	return out

func _first_layer() -> void:
	_slot_was = foot_pieces
	_build_card()
	_stand_layer()

## The stage built and the pilot at the spawn.
func _stand_layer() -> void:
	_layer_asked = Time.get_ticks_msec()
	layer_up_ms = -1
	stage = LayerStage.new()
	add_child(stage)
	stage.setup(self,layer,_slot_was)
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
	_update_card()

## A new layer from `seed_value`: the old isles and stage freed, the new
## planned, the sky's isles made again, the pilot at its spawn.
func start_layer(seed_value: int, why := "") -> void:
	last_end = why
	var old: Array = sky.motifs.isles.duplicate() if sky != null and sky.motifs != null else []
	if stage != null:
		foot_pieces = _slot_was
		remove_child(stage)
		stage.free()
		stage = null
	_lay(seed_value)
	if sky != null:
		sky.restart(layer_entries())
		# The old isles' water no longer stands.
		var pools: Variant = ground.get("pools")
		if pools is Array:
			for i in range((pools as Array).size()-1,-1,-1):
				var p: Dictionary = pools[i]
				if p.has("node") and (not is_instance_valid(p.node) or old.has(p.node)): (pools as Array).remove_at(i)
	_stand_layer()
	if why != "": _show_toast(why)

# --- The loop -------------------------------------------------------------------

func tick(delta: float) -> void:
	super.tick(delta)
	if stage == null or flying: return
	if stage.at_exit(motor.feet):
		start_layer(layer_seed+1,"Through the gate: layer %d" % (layer_seed+1))
	elif motor.feet.y < float(layer.void_y):
		start_layer(layer_seed+1,"Into the void: layer %d" % (layer_seed+1))

## Down off the edge he falls till he lands (a lower isle) or the void
## takes him; never stranded back to the plane.
func _strand() -> void:
	pass

func _process(delta: float) -> void:
	super._process(delta)
	if layer_up_ms < 0 and sky != null and sky.motifs != null and sky.motifs.all_stood():
		layer_up_ms = Time.get_ticks_msec()-_layer_asked
		print("run layer: seed %d stood whole in %d ms (planned in %d ms)" % [layer_seed,layer_up_ms,plan_ms])
		_update_card()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and walk_ready and stage != null:
		var key := event as InputEventKey
		match key.keycode:
			KEY_N:
				start_layer(maxi(layer_seed+(-1 if key.shift_pressed else 1),1))
				return
			KEY_BACKSPACE:
				start_layer(layer_seed)
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
	if _card == null: return
	var names := PackedStringArray()
	for isle: Dictionary in layer.isles:
		if isle.role != "base": names.append(str(isle.id).replace("_"," ")+(" (greed)" if isle.role == "greed" else ""))
	var up := "standing up..." if layer_up_ms < 0 else "up in %.1f s" % (layer_up_ms/1000.0)
	var runes := "runes %d/%d" % [stage.taken,LayerPlan.RUNES] if stage != null else ""
	_card.text = "Layer · seed %d  ·  %s  ·  %s\n%s\nN next seed · Shift+N previous · Backspace again" % [layer_seed,runes,up,", ".join(names)]
