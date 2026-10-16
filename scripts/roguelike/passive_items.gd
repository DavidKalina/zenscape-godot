extends Node
## [items_passive] The standing helps (docs/design/roguelike/items-passive-round1.md).
## One node on the study, reading `RunState.holds(id)` every frame so an item
## taken mid-layer works at once and one lost with the run is gone:
##   heart_vessel  (once) +1 max heart and two mended (RunState.add_vessel)
##   lantern       a warm light on him (a real OmniLight3D), so the
##                 underground reads lit for him
##   waystone      a small warm arrow over his shoulder, leaning at the gate
##   quiet_soles   less noise (scripts/roguelike/passive_noise.gd)
##   rune_magnet   runes within MAGNET m drift to him
##   tithe_bell    (cursed) runes count double (RunState.take_rune); steps x1.3
##                 and it rings (a noise) while he moves
## Knobs: `--lantern=` (1.0) light scale, `--magnet=` (5.0) m.

const NoiseBus = preload("res://scripts/noise/noise_bus.gd")
const RunFeatures = preload("res://scripts/roguelike/run_features.gd")
const RunState = preload("res://scripts/roguelike/run_state.gd")
const WorldScale = preload("res://scripts/world_scale.gd")

const MAGNET := 5.0
const BELL_EVERY := 1.1
const BELL_LOUD := 7.0
const ARROW_FADE := 10.0

var study: Node3D
var run: RefCounted
var _lamp: Node3D = null
var _omni: OmniLight3D
var _flame: MeshInstance3D
var _arrow: Node3D = null
var _arrow_mat: StandardMaterial3D
var _t := 0.0
var _bell := 0.0
var _last := Vector3.INF

func setup(scene: Node3D, state: RefCounted) -> void:
	name = "PassiveItems"
	study = scene
	run = state
	run.item_taken.connect(_taken)

func _taken(id: StringName) -> void:
	if id == &"heart_vessel": run.add_vessel()

func _process(delta: float) -> void:
	if run == null or study == null: return
	var figure: Variant = study.get("figure")
	if not (figure is Node3D) or not (figure as Node3D).is_inside_tree(): return
	_t += delta
	var me := figure as Node3D
	_lantern(me)
	_waystone(me,delta)
	_magnet(me,delta)
	_bell_ring(me,delta)

# --- Lantern ------------------------------------------------------------------------

func _lantern(me: Node3D) -> void:
	var on: bool = run.carrying(&"lantern")
	if on and _lamp == null:
		_make_lamp()
	if _lamp == null: return
	_lamp.visible = on
	if not on: return
	var s := WorldScale.wanderer
	var b := me.global_basis
	_lamp.global_position = me.global_position+Vector3.UP*0.75*s-b.x.normalized()*0.4*s
	var k := float(RunFeatures.value("lantern","1.0"))
	# A slow breath and a quick flicker, so it is a flame and not a bulb.
	var fl := 1.0+0.07*sin(_t*3.1)+0.05*sin(_t*11.7+1.3)+0.03*sin(_t*23.0)
	_omni.light_energy = 2.4*k*fl
	_omni.omni_range = 11.0*k*maxf(s,0.5)
	_flame.scale = Vector3.ONE*fl

func _make_lamp() -> void:
	_lamp = Node3D.new()
	_lamp.name = "HandLantern"
	_lamp.top_level = true
	add_child(_lamp)
	_omni = OmniLight3D.new()
	_omni.light_color = Color(1.0,0.74,0.42)
	_omni.shadow_enabled = false
	_omni.omni_attenuation = 1.3
	_lamp.add_child(_omni)
	_flame = MeshInstance3D.new()
	var ball := SphereMesh.new()
	var s := WorldScale.wanderer
	ball.radius = 0.11*s
	ball.height = 0.22*s
	_flame.mesh = ball
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0,0.82,0.5)
	m.emission_enabled = true
	m.emission = Color(1.0,0.7,0.35)
	m.emission_energy_multiplier = 2.0
	_flame.material_override = m
	_flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lamp.add_child(_flame)

# --- Way-stone ----------------------------------------------------------------------

func _gate_at() -> Variant:
	var stage: Variant = study.get("stage")
	if not (stage is Node) : return null
	var plan: Variant = (stage as Object).get("plan")
	if not (plan is Dictionary): return null
	var exit: Variant = (plan as Dictionary).get("exit",{})
	if not (exit is Dictionary) or (exit as Dictionary).is_empty(): return null
	return (exit as Dictionary).at

func _waystone(me: Node3D, _delta: float) -> void:
	var on: bool = run.carrying(&"waystone")
	var gate: Variant = _gate_at() if on else null
	if gate == null:
		if _arrow != null: _arrow.visible = false
		return
	if _arrow == null: _make_arrow()
	var s := WorldScale.wanderer
	var from := me.global_position+Vector3.UP*2.0*s
	var to: Vector3 = (gate as Vector3)+Vector3.UP*1.0
	var d := to-from
	var flat := Vector2(d.x,d.z).length()
	_arrow.visible = true
	var dir := d.normalized()
	_arrow.global_position = from+dir*0.8*s
	_arrow.look_at(_arrow.global_position+dir,Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT)
	# Subtle: a slow pulse; it gives way as the gate nears (you can see it then).
	var a := clampf((flat-4.0)/ARROW_FADE,0.0,1.0)*(0.55+0.2*sin(_t*2.2))
	_arrow_mat.albedo_color.a = a
	_arrow_mat.emission_energy_multiplier = 1.4*a
	_arrow.visible = a > 0.02

func _make_arrow() -> void:
	_arrow = Node3D.new()
	_arrow.name = "WayStoneArrow"
	_arrow.top_level = true
	add_child(_arrow)
	_arrow_mat = StandardMaterial3D.new()
	_arrow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_arrow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_arrow_mat.no_depth_test = true
	_arrow_mat.render_priority = 5
	_arrow_mat.albedo_color = Color(1.0,0.78,0.45,0.5)
	_arrow_mat.emission_enabled = true
	_arrow_mat.emission = Color(1.0,0.7,0.35)
	var s := WorldScale.wanderer
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.16*s
	cone.height = 0.5*s
	cone.radial_segments = 4
	cone.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = cone
	mi.material_override = _arrow_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The cone's tip is +Y; look_at aims -Z: lay it down so the tip leads.
	mi.rotation.x = -PI*0.5
	_arrow.add_child(mi)

# --- Lodestone ----------------------------------------------------------------------

## Runes (the collectibles' live ones and the greed ring) within reach drift
## to his middle, faster as they near; his own sweep then takes them.
func _magnet(me: Node3D, delta: float) -> void:
	if not run.carrying(&"rune_magnet"): return
	var stage: Variant = study.get("stage")
	if not (stage is Node): return
	var reach := float(RunFeatures.value("magnet",str(MAGNET)))*WorldScale.wanderer
	var mid := me.global_position+Vector3.UP*0.9*WorldScale.wanderer
	var nodes: Array = []
	var found: Variant = (stage as Object).get("collectibles")
	if found is Object:
		var live: Variant = (found as Object).get("_live")
		if live is Array:
			for it: Variant in live:
				if it is Dictionary and str((it as Dictionary).get("what","")) == "rune": nodes.append((it as Dictionary).get("node"))
	var ring: Variant = (stage as Object).get("runes")
	if ring is Array: nodes.append_array(ring)
	for n: Variant in nodes:
		if not is_instance_valid(n) or not (n is Node3D) or not (n as Node3D).is_inside_tree(): continue
		if bool((n as Object).get("taking")): continue
		var node := n as Node3D
		var d := mid-node.global_position
		var dist := d.length()
		if dist > reach or dist < 0.05: continue
		var speed := lerpf(2.5,9.0,1.0-dist/reach)
		node.global_position += d/dist*minf(speed*delta,dist)

# --- Tithe Bell ---------------------------------------------------------------------

## The bell rings while he moves: a noise the Olmec's ears can follow.
func _bell_ring(me: Node3D, delta: float) -> void:
	if not run.carrying(&"tithe_bell"):
		_last = Vector3.INF
		return
	var p := me.global_position
	var moved := _last != Vector3.INF and Vector2(p.x-_last.x,p.z-_last.z).length()/maxf(delta,0.001) > 1.0
	_last = p
	_bell -= delta
	if moved and _bell <= 0.0:
		_bell = BELL_EVERY
		NoiseBus.make(me,p+Vector3.UP,BELL_LOUD*WorldScale.wanderer,&"bell")
