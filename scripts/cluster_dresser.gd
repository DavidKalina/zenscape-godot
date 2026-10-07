extends RefCounted
## What stands on a sky cluster's member, stood up as nodes (scripts/
## sky_clusters.gd): from its plan's features (scripts/cluster_solver.gd)
## the windmill and its sails, the lighthouse, its lamp and beams, the dock,
## the fence round the field, the footbridges, the lantern posts, the folk
## (scripts/islander_figure.gd) fishing and carrying lanterns, and the
## night's lights. The cabin, the stone lamps and the wheat are the islet's
## own records, drawn with the plate's catalog; their glow is here.
##
## Night lights read from far: every window, lamp and lantern has a soft
## halo (shaders/cluster_halo.gdshader) in one batch per member, never
## smaller than a few pixels however far, so a cluster passed a hundred
## metres off at night shows as a scatter of warm points; real lights only
## near (distance-faded), the lighthouse's lamp farther.
##
## The materials are shared by every cluster (`set_night` lights them all
## at once); the meshes that are the same everywhere are made once.

const Builds = preload("res://scripts/showcase_builds.gd")
const Footbridge = preload("res://scripts/footbridge.gd")
const Cabin = preload("res://scripts/cabin.gd")
const StoneLamp = preload("res://scripts/stone_lamp.gd")
const IslanderFigure = preload("res://scripts/islander_figure.gd")
const SkyFolk = preload("res://scripts/sky_folk.gd")
const LakeDress = preload("res://scripts/lake_dress.gd")

const WARM := Color("ffb466")
const LIGHT_COLOR := Color("ffb36b")
const BEAM_REACH := 70.0
## Halos (m across near, strength): a window, a lamp, a lantern, the
## lighthouse's lamp.
const HALO_WINDOW := Vector2(2.2,0.9)
const HALO_LAMP := Vector2(1.1,0.8)
const HALO_LANTERN := Vector2(1.0,0.8)
const HALO_BEACON := Vector2(5.0,1.0)
## Real lights fade out past these (m): small ones, windows, the beacon.
const FADE_SMALL := 45.0
const FADE_WINDOW := 80.0
const FADE_BEACON := 320.0

static var _shared := {}

static func _mats() -> Dictionary:
	if not _shared.is_empty(): return _shared
	var solid := StandardMaterial3D.new()
	solid.vertex_color_use_as_albedo = true
	solid.roughness = 0.9
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("4a4038")
	glow.roughness = 0.6
	glow.emission_enabled = true
	glow.emission = WARM
	var beam := StandardMaterial3D.new()
	beam.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beam.vertex_color_use_as_albedo = true
	beam.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam.albedo_color = Color(1.0,1.0,1.0,0.0)
	var halo := ShaderMaterial.new()
	halo.shader = preload("res://shaders/cluster_halo.gdshader")
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_shared = {"solid":solid,"glow":glow,"beam":beam,"halo":halo,"quad":quad,
		"windmill":Builds.windmill(),"sails":Builds.sails(),"mill_windows":Builds.windmill_windows(),
		"lighthouse":Builds.lighthouse(),"lamp_room":Builds.lamp_room(),"beam_mesh":Builds.beam(BEAM_REACH,2.4),
		"lantern":Builds.lantern(),"post":Builds.post(),"rod":Builds.rod(2.6),"line":Builds.line(5.5)}
	return _shared

## Lets the shared pieces go (with the sky).
static func release() -> void:
	_shared = {}
	LakeDress.release()

## The night's glow on every cluster: 0 by day, 1 at full night.
static func set_night(night: float) -> void:
	var m := _mats()
	(m.glow as StandardMaterial3D).emission_energy_multiplier = 2.6*night
	(m.halo as ShaderMaterial).set_shader_parameter("glow",night)
	(m.beam as StandardMaterial3D).albedo_color = Color(1.0,1.0,1.0,0.5*night)

## The meshes made for one member's features that are its own (a dock's,
## a field's fence, its bridges'), safe on a worker: by feature index and
## by bridge.
static func prepare(member: Dictionary, plan: Dictionary) -> Dictionary:
	var shape: RefCounted = member.shape
	var out := {"features":{},"bridges":[]}
	var cabin := {}
	for f: Dictionary in member.features:
		if f.type == "cabin": cabin = f
	for i in range(member.features.size()):
		var f: Dictionary = member.features[i]
		match str(f.type):
			"dock":
				out.features[i] = Builds.dock(f.a,f.b,1.5,int(member.seed) % 997)
			"field":
				var rect: Rect2 = f.rect
				var corners := PackedVector2Array([rect.position+Vector2(-0.3,-0.3),Vector2(rect.end.x+0.3,rect.position.y-0.3),rect.end+Vector2(0.3,0.3),Vector2(rect.position.x-0.3,rect.end.y+0.3)])
				# The gate on the side nearest the cabin.
				var gate := 0
				if not cabin.is_empty():
					var best := INF
					for k in range(4):
						var mid := (corners[k]+corners[(k+1)%4])*0.5
						if mid.distance_to(cabin.at) < best:
							best = mid.distance_to(cabin.at)
							gate = k
				out.features[i] = Builds.fence(corners,gate,func(p: Vector2) -> float: return shape.ground_at(p) if shape.inland(p) > 0.2 else -INF,int(member.seed) % 991)
	for br: Dictionary in plan.bridges:
		if br.from == member.name: out.bridges.append(Footbridge.build_mesh(br.a,br.b,hash(br.to) % 997))
	return out

## Stands what stands on `member` under its islet's `node`; what moves or
## lights is returned: {"sails": [Node3D], "beams": [Node3D], "lights":
## [[OmniLight3D, energy]]}.
static func furnish(node: Node3D, member: Dictionary, plan: Dictionary, made: Dictionary) -> Dictionary:
	var m := _mats()
	var shape: RefCounted = member.shape
	var live := {"sails":[],"beams":[],"lights":[]}
	var halos: Array = []
	var beam_on: bool = (plan.get("night",{}) as Dictionary).get("beam",false)
	for i in range(member.features.size()):
		var f: Dictionary = member.features[i]
		match str(f.type):
			"cabin":
				var pose := Transform3D(Basis(Vector3.UP,float(f.angle)),Vector3(f.at.x,shape.ground_at(f.at),f.at.y))
				var pane: AABB = Cabin.info().pane
				var glow := MeshInstance3D.new()
				glow.name = "CabinWindow"
				var cube := BoxMesh.new()
				cube.size = Vector3.ONE
				glow.mesh = cube
				glow.material_override = m.glow
				glow.transform = pose*Transform3D(Basis.from_scale(pane.size+Vector3(0.006,0.0,0.0)),pane.get_center()+Vector3(0.003,0.0,0.0))
				glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				node.add_child(glow)
				var outside: Vector3 = pose*(pane.get_center()+Vector3(0.45,0.0,0.0))
				halos.append([pose*(pane.get_center()+Vector3(0.12,0.0,0.0)),HALO_WINDOW])
				_light(node,outside,4.5,1.4,FADE_WINDOW,live)
				var porch: Vector3 = pose*((Cabin.info().door as Vector3)+Vector3(0.8,0.0,0.15))
				var p2 := Vector2(porch.x,porch.z)
				if shape.on_land(p2) and not shape.wet(p2):
					porch.y = shape.ground_at(p2)
					_post(node,porch,float(f.angle),halos,live)
			"lamp":
				var at := Vector3(f.at.x,shape.ground_at(f.at)+StoneLamp.GLOW_HEIGHT,f.at.y)
				var core := MeshInstance3D.new()
				var sphere := SphereMesh.new()
				sphere.radius = StoneLamp.GLOW_RADIUS*1.6
				sphere.height = StoneLamp.GLOW_RADIUS*3.2
				sphere.radial_segments = 6
				sphere.rings = 3
				core.mesh = sphere
				core.material_override = m.glow
				core.position = at
				node.add_child(core)
				halos.append([at,HALO_LAMP])
				_light(node,at,3.5,0.8,FADE_SMALL,live)
			"post":
				var at := Vector3(f.at.x,shape.ground_at(f.at),f.at.y)
				_post(node,at,float(f.angle),halos,live)
			"bearer":
				var figure := _person(node,shape,f.at,float(f.angle),1,member.seed)
				var lantern := _lantern(figure,Vector3(0.075,0.18,-0.07),1.0/SkyFolk.SCALE)
				halos.append([figure.transform*(Vector3(0.075,0.14,-0.07)),HALO_LANTERN])
				_light(lantern,Vector3(0.0,0.12,0.0),4.0,0.9,FADE_SMALL,live)
			"windmill":
				var mill := _stand(node,shape,"Windmill",m.windmill,f.at,float(f.angle))
				var windows := MeshInstance3D.new()
				windows.name = "Windows"
				windows.mesh = m.mill_windows
				windows.material_override = m.glow
				mill.add_child(windows)
				for y: float in [3.1,4.7]: halos.append([mill.transform*Vector3(0.0,y,-1.3),HALO_LAMP])
				var hub := Node3D.new()
				hub.name = "Hub"
				hub.position = Builds.HUB
				hub.rotation.z = float(member.seed % 360)*0.0174
				mill.add_child(hub)
				var sails := MeshInstance3D.new()
				sails.mesh = m.sails
				sails.material_override = m.solid
				hub.add_child(sails)
				live.sails.append(hub)
			"lighthouse":
				var tower := _stand(node,shape,"Lighthouse",m.lighthouse,f.at,float(f.angle))
				var room := MeshInstance3D.new()
				room.mesh = m.lamp_room
				room.material_override = m.glow
				tower.add_child(room)
				halos.append([tower.transform*Builds.LAMP_AT,HALO_BEACON])
				_light(tower,Builds.LAMP_AT,14.0,3.0,FADE_BEACON,live)
				if beam_on:
					var beams := Node3D.new()
					beams.name = "Beams"
					beams.position = Builds.LAMP_AT
					beams.rotation.y = float(member.seed % 628)*0.01
					tower.add_child(beams)
					for k in range(2):
						var beam := MeshInstance3D.new()
						beam.mesh = m.beam_mesh
						beam.material_override = m.beam
						beam.rotation.y = PI*k
						beam.rotation.x = -0.06
						beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
						beams.add_child(beam)
					live.beams.append(beams)
			"dock":
				var dock := MeshInstance3D.new()
				dock.name = "Dock"
				dock.mesh = made.features.get(i)
				dock.material_override = m.solid
				node.add_child(dock)
				var hang := Builds.dock_lantern(f.a,f.b,1.5)
				var lantern := _lantern(node,hang+Vector3.DOWN*0.34,1.0)
				halos.append([hang+Vector3.DOWN*0.2,HALO_LANTERN])
				_light(lantern,Vector3(0.0,0.12,0.0),4.0,0.9,FADE_SMALL,live)
			"fisher":
				var figure := _person(node,shape,f.at,float(f.angle),2,member.seed,float(f.deck_y))
				var hand := Vector3(0.075,0.13,-0.05)
				var rod := MeshInstance3D.new()
				rod.mesh = m.rod
				rod.material_override = m.solid
				rod.scale = Vector3.ONE/SkyFolk.SCALE
				rod.position = hand
				figure.add_child(rod)
				var line := MeshInstance3D.new()
				line.mesh = m.line
				line.material_override = m.solid
				line.position = figure.transform*(hand+Builds.rod_tip(2.6)/SkyFolk.SCALE)
				node.add_child(line)
			"field":
				var fence := MeshInstance3D.new()
				fence.name = "Fence"
				fence.mesh = made.features.get(i)
				fence.material_override = m.solid
				node.add_child(fence)
	for mesh: Mesh in made.get("bridges",[]):
		var bridge := MeshInstance3D.new()
		bridge.name = "Footbridge"
		bridge.mesh = mesh
		bridge.material_override = m.solid
		node.add_child(bridge)
	LakeDress.furnish(node,member,halos,live)
	if not halos.is_empty():
		var batch := MultiMeshInstance3D.new()
		batch.name = "Halos"
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = m.quad
		multi.instance_count = halos.size()
		for k in range(halos.size()):
			var size: Vector2 = halos[k][1]
			multi.set_instance_transform(k,Transform3D(Basis.from_scale(Vector3.ONE*size.x),halos[k][0]))
			multi.set_instance_color(k,Color(WARM,size.y))
		batch.multimesh = multi
		batch.material_override = m.halo
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		batch.custom_aabb = AABB(Vector3(-60.0,-20.0,-60.0),Vector3(120.0,60.0,120.0))
		node.add_child(batch)
	return live

static func _stand(node: Node3D, shape: RefCounted, label: String, mesh: Mesh, at: Vector2, angle: float) -> MeshInstance3D:
	var built := MeshInstance3D.new()
	built.name = label
	built.mesh = mesh
	built.material_override = _mats().solid
	built.position = Vector3(at.x,shape.ground_at(at)-0.05,at.y)
	built.rotation.y = angle
	node.add_child(built)
	return built

static func _post(node: Node3D, at: Vector3, angle: float, halos: Array, live: Dictionary) -> void:
	var post := MeshInstance3D.new()
	post.name = "LanternPost"
	post.mesh = _mats().post
	post.material_override = _mats().solid
	post.position = at+Vector3.DOWN*0.05
	post.rotation.y = angle
	node.add_child(post)
	var lantern := _lantern(post,Builds.post_lantern(),1.0)
	halos.append([post.transform*(Builds.post_lantern()+Vector3.UP*0.12),HALO_LANTERN])
	_light(lantern,Vector3(0.0,0.12,0.0),4.0,0.9,FADE_SMALL,live)

static func _lantern(parent: Node3D, at: Vector3, scale_by: float) -> MeshInstance3D:
	var lantern := MeshInstance3D.new()
	lantern.name = "Lantern"
	lantern.mesh = _mats().lantern
	lantern.material_override = _mats().solid
	lantern.position = at
	lantern.scale = Vector3.ONE*scale_by
	parent.add_child(lantern)
	var core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.05
	sphere.height = 0.1
	sphere.radial_segments = 6
	sphere.rings = 3
	core.mesh = sphere
	core.material_override = _mats().glow
	core.position = Vector3(0.0,0.12,0.0)
	lantern.add_child(core)
	return lantern

static func _light(parent: Node3D, at: Vector3, reach: float, energy: float, fade: float, live: Dictionary) -> void:
	var light := OmniLight3D.new()
	light.light_color = LIGHT_COLOR
	light.omni_range = reach
	light.light_energy = 0.0
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = fade
	light.distance_fade_length = fade*0.25
	light.position = at
	light.visible = false
	parent.add_child(light)
	live.lights.append([light,energy])

static func _person(node: Node3D, shape: RefCounted, at: Vector2, angle: float, scarf: int, seed_value: int, y := INF) -> Node3D:
	var figure := IslanderFigure.new(SkyFolk.SCARVES[(scarf+seed_value) % SkyFolk.SCARVES.size()])
	figure.scale = Vector3.ONE*SkyFolk.SCALE
	figure.position = Vector3(at.x,shape.ground_at(at) if y == INF else y,at.y)
	figure.rotation.y = angle
	node.add_child(figure)
	figure.play("idle")
	return figure
