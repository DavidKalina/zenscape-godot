extends Node3D
## The watering can's stream (the tool roll's "can", scripts/clay_tools/can.gd;
## docs/scenic/water-flow.md "The watering can"). While its press is held the
## can tips forward and water falls from its rose to the land straight below
## and pours into the live water there (WaterFlow `taps`), RATE m³/s at the
## middle pip, following the pointer: drag it along a groove and the groove
## runs. With Shift down at the press it sprinkles: a wider, gentler shower
## through the rose. Held still on high or steep ground (where a dropped ball
## would make a spring) for SPRING_HOLD seconds, the pour takes: a spring
## rises there and keeps running after the can is lifted (WaterFlow
## `plant_spring`, one undo step with its bed).
##
## The water is drawn as the water ball's beads (shaders/water_bead.gdshader):
## drops leaving the rose along the spout, falling under GRAVITY and
## splashing up where they land. Lives under the terrain node, so its
## coordinates are the plate's.

const ClaySound = preload("res://scripts/clay_sound.gd")

## m³/s poured at the middle pip (the pips scale it 0.6 / 1 / 1.5), over a
## splash RADIUS m across; a sprinkle pours SPRINKLE_SHARE of that over
## SPRINKLE_SPREAD times the radius.
const RATE := 1.4
const RADIUS := 0.45
const SPRINKLE_SHARE := 0.4
const SPRINKLE_SPREAD := 3.0
## Seconds the pour takes to come on, as the can tips (and to stop).
const EASE_IN := 0.25
## A spring: the landing held within STILL m for SPRING_HOLD s on ground
## where a ball would make a spring.
const SPRING_HOLD := 1.6
const STILL := 0.35
## The drops: how many a second at a full pour (a sprinkle twice as many,
## smaller), how fast they leave the rose (m/s), the most drawn at once, and
## the splash beads thrown up per landing drop.
const DROPS_RATE := 70.0
const DROP_SPEED := 1.3
const GRAVITY := 9.8
const BEADS := 220
const SPLASH := 2
## The rose over the pointer's ground point when the prop is not shown (m).
const FALLBACK_HEIGHT := 1.0

signal spring_planted(point: Vector2)

## Set by the editor: the live water, the clay (for the prop and the tool),
## and the land's height at a plate x, z (a Vector2), or null off the land.
var flow: RefCounted
var clay: Node
var ground_at := Callable()
## The plate point under the pointer (a Vector3), or null; the editor sets it
## every frame.
var pointer: Variant = null

var pouring := false
var sprinkle := false
var size_scale := 1.0
## 0..1, easing toward 1 while pouring and to 0 after.
var flow_share := 0.0
## Where the stream meets the land (plate x, z), and m³ poured since the
## press.
var landing := Vector2.INF
var poured := 0.0
## Springs this can has planted, for probes.
var planted := 0
var _still_at := Vector2.INF
var _still := 0.0
var _planted_here := false
var _emit := 0.0
var _beads: Array[Dictionary] = []
var _bead_node: MultiMeshInstance3D

func _ready() -> void:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/water_bead.gdshader")
	material.render_priority = 2
	var bead := SphereMesh.new()
	bead.radius = 1.0
	bead.height = 2.0
	bead.radial_segments = 8
	bead.rings = 4
	var beads := MultiMesh.new()
	beads.transform_format = MultiMesh.TRANSFORM_3D
	beads.use_colors = true
	beads.instance_count = BEADS
	beads.visible_instance_count = 0
	beads.mesh = bead
	_bead_node = MultiMeshInstance3D.new()
	_bead_node.name = "Stream"
	_bead_node.multimesh = beads
	_bead_node.material_override = material
	_bead_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bead_node.top_level = true
	add_child(_bead_node)

## The press: pour from here until `release`.
func press(point: Vector3, scale: float, fine: bool) -> void:
	pouring = true
	sprinkle = fine
	size_scale = scale
	pointer = point
	poured = 0.0
	_still_at = Vector2.INF
	_still = 0.0
	_planted_here = false

func release() -> void:
	if not pouring: return
	pouring = false
	_still = 0.0

func _exit_tree() -> void:
	if flow != null: flow.taps.erase("can")

func _process(delta: float) -> void:
	delta = minf(delta,0.05)
	if pouring and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not DisplayServer.get_name() == "headless": release()
	flow_share = move_toward(flow_share,1.0 if pouring else 0.0,delta/EASE_IN)
	var tool: RefCounted = _tool()
	if tool != null: tool.pour = flow_share
	var rose: Variant = _rose(tool)
	if rose == null or flow_share <= 0.0:
		if flow != null: flow.taps.erase("can")
		landing = Vector2.INF
		_step_beads(delta,null,tool)
		return
	var at := Vector2((rose as Vector3).x,(rose as Vector3).z)
	var floor_y: Variant = ground_at.call(at) if ground_at.is_valid() else null
	if floor_y == null:
		if flow != null: flow.taps.erase("can")
		landing = Vector2.INF
		_step_beads(delta,rose,tool)
		return
	landing = at
	var rate := RATE*size_scale*flow_share*(SPRINKLE_SHARE if sprinkle else 1.0)
	var radius := RADIUS*size_scale*(SPRINKLE_SPREAD if sprinkle else 1.0)
	if flow != null:
		flow.taps["can"] = [at.x,at.y,radius,rate]
		poured += rate*delta
	ClaySound.voice(&"water_pour",flow_share*(0.6 if sprinkle else 1.0),(get_parent() as Node3D).to_global(rose))
	if pouring: _hold_still(at,delta)
	_step_beads(delta,rose,tool)

## Held still on spring ground long enough, the pour becomes a spring.
func _hold_still(at: Vector2, delta: float) -> void:
	if _still_at == Vector2.INF or at.distance_to(_still_at) > STILL:
		_still_at = at
		_still = 0.0
		_planted_here = false
		return
	_still += delta
	if _planted_here or _still < SPRING_HOLD or flow == null or sprinkle: return
	_planted_here = true
	if flow.source_kind(at) != "spring": return
	planted += 1
	spring_planted.emit(at)

func _tool() -> RefCounted:
	if clay == null or clay.get("tool_id") != "can": return null
	return clay.tool

## The rose in plate coordinates: on the shown prop, or over the pointer.
func _rose(tool: RefCounted) -> Variant:
	if tool != null:
		var on_prop: Variant = clay.prop_point(tool.rose())
		if on_prop != null: return on_prop
	if pointer == null: return null
	return (pointer as Vector3)+Vector3.UP*FALLBACK_HEIGHT

## Drops leave the rose along the spout and fall; where they land they splash
## up a little and are gone.
func _step_beads(delta: float, rose: Variant, tool: RefCounted) -> void:
	if rose != null and flow_share > 0.0:
		var way: Vector3 = tool.spout_way() if tool != null else Vector3.DOWN
		if tool != null: way = (clay.prop_point(way)-clay.prop_point(Vector3.ZERO)).normalized()
		_emit += DROPS_RATE*flow_share*(2.0 if sprinkle else 1.0)*delta
		while _emit >= 1.0:
			_emit -= 1.0
			var spread := 0.9 if sprinkle else 0.18
			var jitter := Vector3(randf_range(-1,1),randf_range(-1,1),randf_range(-1,1))*spread
			var size := randf_range(0.02,0.035) if sprinkle else randf_range(0.035,0.06)
			_beads.append({"p":(rose as Vector3)+jitter*0.05,"v":(way+jitter).normalized()*DROP_SPEED*randf_range(0.85,1.15),"size":size*sqrt(size_scale),"splash":false,"t":0.0})
	var kept: Array[Dictionary] = []
	# The water's depth, read once a frame: drops splash on its surface.
	var depths: PackedFloat32Array = PackedFloat32Array() if flow == null or _beads.is_empty() else flow.depths()
	for bead: Dictionary in _beads:
		bead.t = float(bead.t)+delta
		var v: Vector3 = bead.v
		v.y -= GRAVITY*delta
		bead.v = v
		var p: Vector3 = bead.p+v*delta
		bead.p = p
		var floor_y: Variant = ground_at.call(Vector2(p.x,p.z)) if ground_at.is_valid() else null
		var water := 0.0
		if not depths.is_empty() and floor_y != null:
			var cell: int = flow.cell_at(Vector2(p.x,p.z))
			if cell >= 0: water = depths[cell]
		if floor_y != null and p.y <= float(floor_y)+water:
			if not bead.splash:
				for i in range(SPLASH):
					var out := Vector2.from_angle(randf()*TAU)*randf_range(0.4,1.1)
					kept.append({"p":Vector3(p.x,float(floor_y)+water+0.02,p.z),"v":Vector3(out.x,randf_range(1.0,2.0),out.y),"size":float(bead.size)*0.55,"splash":true,"t":0.0})
			continue
		if float(bead.t) > 2.0: continue
		kept.append(bead)
	_beads = kept.slice(maxi(kept.size()-BEADS,0))
	var beads := _bead_node.multimesh
	beads.visible_instance_count = _beads.size()
	_bead_node.global_transform = (get_parent() as Node3D).global_transform
	for i in range(_beads.size()):
		var bead: Dictionary = _beads[i]
		var v: Vector3 = bead.v
		var speed := v.length()
		var basis := Basis.from_scale(Vector3.ONE*float(bead.size))
		# Stretched along the way it falls.
		if speed > 0.2:
			var along := v/speed
			var side := along.cross(Vector3.UP if absf(along.y) < 0.95 else Vector3.RIGHT).normalized()
			basis = Basis(side,along,side.cross(along))*Basis.from_scale(Vector3(1.0,1.0+clampf(speed*0.25,0.0,2.0),1.0))*basis
		beads.set_instance_transform(i,Transform3D(basis,bead.p))
		beads.set_instance_color(i,Color(1,1,1,1.0-smoothstep(0.15,0.35,float(bead.t)) if bead.splash else 1.0))
