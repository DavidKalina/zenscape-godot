extends Node3D
## The showcase cluster (--showcase): one hand-laid group of islets near
## the plate's first home, made to read as a little place to fly past
## rather than scattered scenery. A prototype, to see how far the islets'
## own pipeline (scripts/sky_islet.gd `author`) goes toward a place:
##   lead: the farm islet, a cabin lit at night, stone lamps, a wheat field
##     fenced in split rails, and a pond whose stream leaves over the rim as
##     a fall;
##   forest: a small wood, higher, joined to the lead by a rope footbridge;
##   crag: the highest, rocky, spruces clinging on, a lamp at the lookout;
##   mill: a knoll beside the field with a turning windmill;
##   light: the outermost point, lower, a lighthouse whose beams sweep at
##     night;
##   dock: low, a plank dock jutting off its rim into the air, someone
##     fishing off its end, the line hanging down toward the clouds;
##   stones: stepping-stone islets from the lead down to the dock, each gap
##     a run-and-jump for the pilot on foot (GAP).
## All of them bob together (one phase), so the bridge holds. They stand in
## the islets' own `built` as `fixed` records (scripts/sky_islets.gd), so
## the glide reads them as solids and perches on them as on any islet; the
## seeded islets keep KEEP clear of them. Grouped (`group`), the pilot on
## foot runs and jumps from one onto the next (scripts/wanderer_eye.gd).
##
## Everything here is in the islets' home coordinates (the plate's first
## home at the origin): CENTRE is the lead's middle.

const SkyIslet = preload("res://scripts/sky_islet.gd")
const SkyIslets = preload("res://scripts/sky_islets.gd")
const Builds = preload("res://scripts/showcase_builds.gd")
const Footbridge = preload("res://scripts/footbridge.gd")
const Cabin = preload("res://scripts/cabin.gd")
const StoneLamp = preload("res://scripts/stone_lamp.gd")
const StoneLampLights = preload("res://scripts/stone_lamp_lights.gd")
const IslanderFigure = preload("res://scripts/islander_figure.gd")
const SkyFolk = preload("res://scripts/sky_folk.gd")
const MeadowTypes = preload("res://scripts/meadow_types.gd")

## The lead's middle (home coordinates), and how far round it no seeded
## islet stands.
const CENTRE := Vector3(150.0,-6.0,60.0)
const KEEP := 105.0
## The group the pilot runs between.
const GROUP := "showcase"
## Edge to edge between stepping stones (m): a running jump.
const GAP := 1.7
## The way from the lead down the stones to the dock (x, z).
const ROUTE := Vector2(-0.55,0.83)
## The cluster's bob: one phase and period for every member.
const PHASE := 0.7
const PERIOD := 9.0
## The sails' turn (rad/s), the beams' sweep (rad/s), the beam's reach (m).
const SAIL_SPIN := 0.55
const BEAM_SPIN := 0.45
const BEAM_REACH := 70.0
## Night lights: the cabin's pane, the lamps' warmth, the lighthouse lamp.
const WARM := Color("ffb466")
const LIGHT_COLOR := Color("ffb36b")

## The lead's stone lamps: by the cabin's door, mid-way to the pond, at
## the bridge's head.
const LAMPS := [Vector2(-0.6,8.2),Vector2(-1.0,-0.5),Vector2(-9.6,-7.4)]

## The members: name, seed, offset from CENTRE (stones and the dock are
## laid along ROUTE once their shapes are known, `_lay_route`), and the
## islet recipe (SkyIslet `recipe`).
static func members() -> Array:
	var field := Rect2(0.5,-13.5,8.5,8.0)
	var objects: Array = []
	objects.append({"asset":"cabin","x":1.5,"z":4.5,"angle":-0.585,"scale":1.0})
	for lamp: Vector2 in LAMPS:
		objects.append({"asset":"stone_lamp","x":lamp.x,"z":lamp.y,"angle":0.4,"scale":1.0})
	# The wheat in rows along x, a little wavering.
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	var row := 0.42
	var z := field.position.y+0.3
	while z < field.end.y-0.2:
		var x := field.position.x+0.3
		while x < field.end.x-0.2:
			objects.append({"asset":"wheat","x":x+rng.randf_range(-0.05,0.05),"z":z+rng.randf_range(-0.04,0.04),
				"angle":rng.randf()*TAU,"scale":rng.randf_range(0.82,0.95),"tint":MeadowTypes.tint("wheat",rng.randf())})
			x += 0.24
		z += row
	var list := [
		{"name":"lead","seed":91021,"offset":Vector3.ZERO,"spec":{"kind":"meadow","radius":19.0,"dome":0.35,
			"mounds":[Vector4(-12.0,-8.0,8.0,1.6),Vector4(12.0,10.0,7.0,1.1)],
			"pond":{"at":Vector2(-7.0,3.0),"radius":3.2,"toward":Vector2(-1.0,0.35)},
			"pads":[Vector4(1.5,4.5,2.8,0.0),Vector4(field.get_center().x,field.get_center().y,5.2,0.0)],
			"clear":LAMPS.map(func(l: Vector2) -> Vector3: return Vector3(l.x,l.y,0.8)),
			"trees":Vector2i(10,13),"tree_pool":{"broadleaf":1.0,"birch":0.8,"tree":0.5,"willow":0.3},"mixed":true,
			"tree_size":Vector2(0.9,1.3),"drifts":Vector2i(9,13),
			"objects":objects,"blocks":[Vector3(1.5,4.5,1.9)],"crowns":[Vector4(1.5,4.5,3.4,2.2)]},
			"field":field},
		{"name":"forest","seed":55117,"offset":Vector3(-35.0,7.0,-26.0),"spec":{"kind":"grove","radius":13.5,"dome":1.3,
			"trees":Vector2i(48,60),"tree_pool":{"tree":1.0,"redwood":0.4,"juniper":0.35,"broadleaf":0.6,"birch":0.4},
			"mixed":true,"tree_size":Vector2(0.75,1.7),"apart":0.7,"undergrowth":1.8}},
		{"name":"crag","seed":33829,"offset":Vector3(5.0,17.0,-37.0),"spec":{"kind":"crag","radius":9.0,
			"peaks":[Vector4(1.0,-1.0,7.5,6.5),Vector4(-4.0,3.0,4.5,3.0)],
			"pads":[Vector4(1.0,-1.0,1.3,0.0)],"trees":Vector2i(6,9),"tree_pool":{"tree":1.0,"juniper":0.8},
			"objects":[{"asset":"stone_lamp","x":1.6,"z":-0.4,"angle":0.2,"scale":1.0}]}},
		{"name":"mill","seed":71993,"offset":Vector3(31.0,2.0,-8.0),"spec":{"kind":"hills","radius":5.8,"dome":0.4,
			"mounds":[Vector4(0.0,0.0,4.6,1.0)],"pads":[Vector4(0.0,0.0,1.9,0.0)],"trees":Vector2i(0,1),
			"blocks":[Vector3(0.0,0.0,1.6)],"crowns":[Vector4(0.0,0.0,7.8,1.6)]}},
		{"name":"light","seed":18517,"offset":Vector3(36.0,-12.0,30.0),"spec":{"kind":"crag","radius":6.8,
			"peaks":[Vector4(0.0,0.0,5.5,1.4)],"pads":[Vector4(0.0,0.0,2.1,0.0)],"trees":Vector2i(1,2),
			"tree_pool":{"juniper":1.0},"blocks":[Vector3(0.0,0.0,2.0)],"crowns":[Vector4(0.0,0.0,10.7,2.0)]}},
	]
	var drops := [-0.6,-1.2,-1.8,-2.6]
	for k in range(3):
		list.append({"name":"stone%d" % k,"seed":40031+k*977,"offset":Vector3(0.0,drops[k],0.0),"route":true,"swing":[0.25,-0.3,0.2][k],
			"spec":{"kind":"hills","radius":[2.4,2.1,2.6][k],"dome":0.15,"mounds":[],"trees":Vector2i(0,0),"undergrowth":0.5}})
	list.append({"name":"dock","seed":62207,"offset":Vector3(0.0,drops[3],0.0),"route":true,
		"spec":{"kind":"shore","radius":5.2,"trees":Vector2i(1,2),"tree_pool":{"willow":1.0}}})
	return list

static func enabled() -> bool:
	return "--showcase" in OS.get_cmdline_user_args()

## The islets (SkyIslets) the members stand in, and the scene (for the
## daylight).
var islets: Node3D
var scene: Node
## Each member's built record by name, once stood.
var built := {}
## The night's glow, 0 by day to 1 at full night (StoneLampLights `night_for`).
var night := 0.0
## For probes: an override of the daylight, or -1.
var daylight_override := -1.0
var _task := -1
var _made: Array = []
var _sails: Node3D
var _beams: Node3D
var _warm: Array[GeometryInstance3D] = []
var _lights: Array = []
var _glow_material: StandardMaterial3D
var _beam_material: StandardMaterial3D
var _material: StandardMaterial3D
var _clock := 0.0

func _init() -> void:
	name = "SkyShowcase"
	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	_material.roughness = 0.9
	_glow_material = StandardMaterial3D.new()
	_glow_material.albedo_color = Color("4a4038")
	_glow_material.roughness = 0.6
	_glow_material.emission_enabled = true
	_glow_material.emission = WARM
	_beam_material = StandardMaterial3D.new()
	_beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_beam_material.vertex_color_use_as_albedo = true
	_beam_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beam_material.no_depth_test = false
	_beam_material.albedo_color = Color(1.0,1.0,1.0,0.0)

func _exit_tree() -> void:
	_wait()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE: _wait()

func _wait() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1

## Starts making the members on a worker (after the islets' `reset`); they
## stand up once made (`_process`, or `flush`).
func build() -> void:
	_wait()
	built.clear()
	_warm.clear()
	_lights.clear()
	_sails = null
	_beams = null
	islets.keep_clear.assign([Vector3(CENTRE.x,CENTRE.z,KEEP)])
	var palette: Dictionary = islets.prepare_authored()
	var list := members()
	_made = []
	for m: Dictionary in list: _made.append({"member":m,"out":{}})
	var made := _made
	_task = WorkerThreadPool.add_task(func() -> void:
		for entry: Dictionary in made:
			var m: Dictionary = entry.member
			entry.out = SkyIslets.make(int(m.seed),m.spec,palette,CENTRE.y+(m.offset as Vector3).y),false,"Showcase")

## Waits for the members and stands them up (tests, probes, captures).
func flush() -> void:
	if _task < 0: return
	_wait()
	_stand()

func _process(delta: float) -> void:
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		_wait()
		_stand()
	if built.is_empty(): return
	_clock += delta
	if _sails != null and is_instance_valid(_sails): _sails.rotate_object_local(Vector3.BACK,-SAIL_SPIN*delta)
	_light(delta)

# --- Standing them up -----------------------------------------------------------

func _stand() -> void:
	var homes := _lay_route()
	for entry: Dictionary in _made:
		var m: Dictionary = entry.member
		var b: Dictionary = islets.stand("Showcase_"+str(m.name),homes[m.name],entry.out)
		b.fixed = true
		b.group = GROUP
		b.phase = PHASE
		b.period = PERIOD
		b.age = 0.0
		b.member = m.name
		islets.built["show:"+str(m.name)] = b
		built[m.name] = b
	_furnish(homes)
	_made = []

## Every member's home: the fixed ones at CENTRE plus their offset; the
## stones and the dock laid one after another along ROUTE from the lead's
## rim, GAP apart rim to rim.
func _lay_route() -> Dictionary:
	var homes := {}
	var shapes := {}
	for entry: Dictionary in _made: shapes[entry.member.name] = entry.out.shape
	var prev_home := CENTRE
	var prev: RefCounted = shapes.lead
	var angle := ROUTE.angle()
	for entry: Dictionary in _made:
		var m: Dictionary = entry.member
		if not m.get("route",false):
			homes[m.name] = CENTRE+(m.offset as Vector3)
			continue
		var shape: RefCounted = shapes[m.name]
		# Each stone a little off the straight way, so the line wanders.
		angle = ROUTE.angle()+float(m.get("swing",0.0))
		var out: float = prev.rim_radius(angle)
		var back: float = shape.rim_radius(angle+PI)
		var way := Vector2.from_angle(angle)
		var flat := way*(out+GAP+back)
		homes[m.name] = Vector3(prev_home.x+flat.x,CENTRE.y+(m.offset as Vector3).y,prev_home.z+flat.y)
		prev_home = homes[m.name]
		prev = shape
	return homes

## What stands on the members: the bridge, the mill, the lighthouse, the
## dock, the fence, the cabin's light, the folk.
func _furnish(homes: Dictionary) -> void:
	var lead: Dictionary = built.lead
	var lead_shape: RefCounted = lead.shape
	# The footbridge from the lead to the forest, a deck of the lead's (so
	# the pilot walks it) and drawn as the plate's own bridges are.
	var forest_off: Vector3 = (homes.forest as Vector3)-(homes.lead as Vector3)
	var way := Vector2(forest_off.x,forest_off.z).normalized()
	var forest_shape: RefCounted = built.forest.shape
	var a2: Vector2 = way*(lead_shape.rim_radius(way.angle())-1.3)
	var b2: Vector2 = Vector2(forest_off.x,forest_off.z)-way*(forest_shape.rim_radius((-way).angle())-1.3)
	var a := Vector3(a2.x,lead_shape.ground_at(a2)+0.05,a2.y)
	var b := Vector3(b2.x,forest_shape.ground_at(b2-Vector2(forest_off.x,forest_off.z))+forest_off.y+0.05,b2.y)
	var span := Vector2(b.x-a.x,b.z-a.z).length()
	var bridge := MeshInstance3D.new()
	bridge.name = "Footbridge"
	bridge.mesh = Footbridge.build_mesh(a,b,7)
	bridge.material_override = _material
	(lead.node as Node3D).add_child(bridge)
	lead_shape.decks.append({"a":a,"b":b,"width":Footbridge.WIDTH,"bow":Footbridge.bow(span)})
	# A lantern post at each of its ends, beside the deck.
	var across := Vector3(way.x,0.0,way.y).cross(Vector3.UP).normalized()
	for end: Array in [[a,lead_shape,Vector3.ZERO,way],[b,forest_shape,forest_off,-way]]:
		var at: Vector3 = (end[0] as Vector3)+across*0.75-Vector3(end[3].x,0.0,end[3].y)*0.5
		var local: Vector3 = at-(end[2] as Vector3)
		at.y = float((end[1] as RefCounted).ground_at(Vector2(local.x,local.z)))+(end[2] as Vector3).y
		_lantern_post(lead.node,at,atan2(-across.x,-across.z)+PI)
	lead_shape.reach = maxf(lead_shape.reach,Vector2(b.x,b.z).length()+1.0)
	# The fence round the wheat, its gate toward the cabin.
	var field: Rect2 = _member("lead").field
	var corners := PackedVector2Array([field.position+Vector2(-0.3,-0.3),Vector2(field.end.x+0.3,field.position.y-0.3),field.end+Vector2(0.3,0.3),Vector2(field.position.x-0.3,field.end.y+0.3)])
	var fence := MeshInstance3D.new()
	fence.name = "Fence"
	fence.mesh = Builds.fence(corners,2,func(p: Vector2) -> float: return lead_shape.ground_at(p) if lead_shape.inland(p) > 0.2 else -INF,11)
	fence.material_override = _material
	(lead.node as Node3D).add_child(fence)
	# The cabin's window, warm at night, and its light.
	var cabin_item: Dictionary = {}
	for item: Dictionary in lead_shape.objects:
		if item.asset == "cabin": cabin_item = item
	if not cabin_item.is_empty():
		var pose := Transform3D(Basis(Vector3.UP,float(cabin_item.angle))*Basis.from_scale(Vector3.ONE*float(cabin_item.scale)),lead_shape.object_position(cabin_item))
		var pane: AABB = Cabin.info().pane
		var glow := MeshInstance3D.new()
		glow.name = "CabinWindow"
		var cube := BoxMesh.new()
		cube.size = Vector3.ONE
		glow.mesh = cube
		glow.material_override = _glow_material
		glow.transform = pose*Transform3D(Basis.from_scale(pane.size+Vector3(0.006,0.0,0.0)),pane.get_center()+Vector3(0.003,0.0,0.0))
		(lead.node as Node3D).add_child(glow)
		_light_at(lead.node,pose*(pane.get_center()+Vector3(0.45,0.0,0.0)),4.5,1.4)
		# A lantern by the door.
		var porch: Vector3 = pose*((Cabin.info().door as Vector3)+Vector3(0.8,0.0,0.15))
		_lantern_post(lead.node,porch,float(cabin_item.angle))
		# Someone out by the cabin with a lantern.
		var door: Vector3 = pose*((Cabin.info().door as Vector3)+Vector3(0.9,0.0,1.1))
		_person(lead,Vector2(door.x,door.z),float(cabin_item.angle)+0.4,"lantern")
	for item: Dictionary in lead_shape.objects:
		if item.asset == "stone_lamp": _lamp(lead,item)
	for item: Dictionary in built.crag.shape.objects:
		if item.asset == "stone_lamp": _lamp(built.crag,item)
	# The windmill, facing the way the cluster is flown up to (-x).
	var mill: Dictionary = built.mill
	var mill_node := _stand_on(mill,"Windmill",Builds.windmill(),Vector2.ZERO,-PI*0.5)
	var windows := MeshInstance3D.new()
	windows.name = "Windows"
	windows.mesh = Builds.windmill_windows()
	windows.material_override = _glow_material
	mill_node.add_child(windows)
	_light_at(mill_node,Vector3(0.0,3.6,-1.7),5.0,0.9)
	var hub := Node3D.new()
	hub.name = "Hub"
	hub.position = Builds.HUB
	mill_node.add_child(hub)
	var sails := MeshInstance3D.new()
	sails.name = "Sails"
	sails.mesh = Builds.sails()
	sails.material_override = _material
	hub.add_child(sails)
	_sails = hub
	# The lighthouse, its lamp room, its beams.
	var light: Dictionary = built.light
	var tower := _stand_on(light,"Lighthouse",Builds.lighthouse(),Vector2.ZERO,0.0)
	var room := MeshInstance3D.new()
	room.name = "LampRoom"
	room.mesh = Builds.lamp_room()
	room.material_override = _glow_material
	tower.add_child(room)
	_light_at(tower,Builds.LAMP_AT,14.0,3.0,true)
	_beams = Node3D.new()
	_beams.name = "Beams"
	_beams.position = Builds.LAMP_AT
	tower.add_child(_beams)
	for k in range(2):
		var beam := MeshInstance3D.new()
		beam.mesh = Builds.beam(BEAM_REACH,2.4)
		beam.material_override = _beam_material
		beam.rotation.y = PI*k
		beam.rotation.x = -0.06
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_beams.add_child(beam)
	# The dock off the dock islet's far rim, someone fishing off its end.
	var dock: Dictionary = built.dock
	var dock_shape: RefCounted = dock.shape
	var out_way := ROUTE.normalized()
	var start: Vector2 = out_way*(dock_shape.rim_radius(out_way.angle())-1.2)
	var end: Vector2 = start+out_way*7.0
	var deck_y: float = dock_shape.ground_at(start)+0.12
	var da := Vector3(start.x,deck_y,start.y)
	var db := Vector3(end.x,deck_y,end.y)
	var dock_mesh := MeshInstance3D.new()
	dock_mesh.name = "Dock"
	dock_mesh.mesh = Builds.dock(da,db,1.5,5)
	dock_mesh.material_override = _material
	(dock.node as Node3D).add_child(dock_mesh)
	dock_shape.decks.append({"a":da,"b":db,"width":1.5,"bow":0.0})
	dock_shape.reach = maxf(dock_shape.reach,end.length()+1.0)
	_hang_lantern(dock.node,Builds.dock_lantern(da,db,1.5))
	var fisher := _person(dock,end-out_way*0.45+Vector2(-out_way.y,out_way.x)*0.25,atan2(-out_way.x,-out_way.y),"rod")
	fisher.set_meta("deck_y",deck_y)

## Puts a built mesh on a member's ground at `at` (its frame), turned
## `angle`, as a child of its node.
func _stand_on(b: Dictionary, label: String, mesh: Mesh, at: Vector2, angle: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = _material
	node.position = Vector3(at.x,b.shape.ground_at(at)-0.05,at.y)
	node.rotation.y = angle
	(b.node as Node3D).add_child(node)
	return node

## A lantern post standing at `at` (a node's frame), its arm turned
## `angle`, the lantern hung and lit.
func _lantern_post(parent: Node3D, at: Vector3, angle: float) -> void:
	var post := MeshInstance3D.new()
	post.name = "LanternPost"
	post.mesh = Builds.post()
	post.material_override = _material
	post.position = at+Vector3.DOWN*0.05
	post.rotation.y = angle
	parent.add_child(post)
	_hang_lantern(post,Builds.post_lantern()+Vector3.UP*0.34)

## A stone lamp's glow (its fire box), lit at night.
func _lamp(b: Dictionary, item: Dictionary) -> void:
	var at: Vector3 = b.shape.object_position(item)+Vector3.UP*StoneLamp.GLOW_HEIGHT*float(item.scale)
	var core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = StoneLamp.GLOW_RADIUS*1.6
	sphere.height = StoneLamp.GLOW_RADIUS*3.2
	sphere.radial_segments = 6
	sphere.rings = 3
	core.mesh = sphere
	core.material_override = _glow_material
	core.position = at
	(b.node as Node3D).add_child(core)
	_light_at(b.node,at,3.5,0.8)

## A hanging lantern (dock post, a hand) and its light.
func _hang_lantern(parent: Node3D, at: Vector3, scale_by := 1.0) -> Node3D:
	var lantern := MeshInstance3D.new()
	lantern.name = "Lantern"
	lantern.mesh = Builds.lantern()
	lantern.material_override = _material
	lantern.position = at+Vector3.DOWN*0.34*scale_by
	lantern.scale = Vector3.ONE*scale_by
	parent.add_child(lantern)
	var core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.05
	sphere.height = 0.1
	sphere.radial_segments = 6
	sphere.rings = 3
	core.mesh = sphere
	core.material_override = _glow_material
	core.position = Vector3(0.0,0.12,0.0)
	lantern.add_child(core)
	_light_at(lantern,Vector3(0.0,0.12,0.0),4.0,0.9)
	return lantern

## A real light at `at` under `parent`, warm, lit by night (`_light`).
func _light_at(parent: Node3D, at: Vector3, reach: float, energy: float, shadow := false) -> void:
	var light := OmniLight3D.new()
	light.light_color = LIGHT_COLOR
	light.omni_range = reach
	light.light_energy = 0.0
	light.shadow_enabled = shadow
	light.position = at
	light.visible = false
	parent.add_child(light)
	_lights.append([light,energy])

## One of the sky folk (scripts/islander_figure.gd, at the folk's size) on
## a member at `at`, facing `angle`, with a lantern or a rod.
func _person(b: Dictionary, at: Vector2, angle: float, holding: String) -> Node3D:
	var figure := IslanderFigure.new(SkyFolk.SCARVES[2 if holding == "rod" else 1])
	figure.name = "Fisher" if holding == "rod" else "LanternBearer"
	figure.scale = Vector3.ONE*SkyFolk.SCALE
	figure.position = Vector3(at.x,b.shape.ground_at(at),at.y)
	figure.rotation.y = angle
	(b.node as Node3D).add_child(figure)
	figure.play("idle")
	# The hand's place on the figure (its own units), a little out front.
	var hand := Vector3(0.075,0.13,-0.05)
	if holding == "rod":
		var rod := MeshInstance3D.new()
		rod.name = "Rod"
		rod.mesh = Builds.rod(2.6)
		rod.material_override = _material
		rod.scale = Vector3.ONE/SkyFolk.SCALE
		rod.position = hand
		figure.add_child(rod)
		var tip: Vector3 = figure.transform*(hand+Builds.rod_tip(2.6)/SkyFolk.SCALE)
		var line := MeshInstance3D.new()
		line.name = "Line"
		line.mesh = Builds.line(5.5)
		line.material_override = _material
		line.position = tip
		(b.node as Node3D).add_child(line)
	else:
		_hang_lantern(figure,hand+Vector3(0.0,0.05,-0.02),1.0/SkyFolk.SCALE)
	return figure

# --- Night -----------------------------------------------------------------------

## The daylight the lights answer to, 0 (night) .. 1 (day), as the stone
## lamps read it.
func daylight() -> float:
	if daylight_override >= 0.0: return daylight_override
	var celestial: Variant = scene.get("_celestial") if scene != null else null
	if celestial != null and celestial.get("state") is Dictionary and celestial.state.has("zs_daylight"):
		return float(celestial.state.zs_daylight)
	return 1.0

func _light(delta: float) -> void:
	night = move_toward(night,StoneLampLights.night_for(daylight()),delta/2.0)
	_glow_material.emission_energy_multiplier = 2.6*night
	for entry: Array in _lights:
		var light: OmniLight3D = entry[0]
		if not is_instance_valid(light): continue
		light.visible = night > 0.01
		light.light_energy = float(entry[1])*night
	if _beams != null and is_instance_valid(_beams):
		_beams.visible = night > 0.05
		_beams.rotation.y = _clock*BEAM_SPIN
		_beam_material.albedo_color = Color(1.0,1.0,1.0,0.5*night)

func _member(member_name: String) -> Dictionary:
	for entry: Dictionary in _made:
		if entry.member.name == member_name: return entry.member
	return {}
