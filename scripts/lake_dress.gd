extends RefCounted
## What floats on a cluster's lake (scripts/cluster_lake.gd's features on
## a member with an islet lake, scripts/islet_lake.gd), stood up as nodes
## by the cluster dresser (scripts/cluster_dresser.gd `furnish`, before it
## batches its halos): the rowing boat and its stern lantern, the lilies,
## the floating lanterns, and at night the warm lights' reflections on the
## water (shaders/lake_glint.gdshader): every window, lamp and lantern
## standing over the lake, the jetty's, the boat's and the floating ones,
## lies on the water as a soft streak broken by the ripples. The night's
## signature: a dark lake scattered with warm floating points, each
## doubled in the water.
##
## The boat rocks and the lanterns bob (`Life`, one a lake), and keep the
## paper's and the reflections' glow with the clusters' night (the
## dresser's halo material's `glow`).

## The dresser (scripts/cluster_dresser.gd), read when needed, not
## preloaded: it preloads this.
const DRESSER := "res://scripts/cluster_dresser.gd"
const LakeBuilds = preload("res://scripts/lake_builds.gd")
const IsletLake = preload("res://scripts/islet_lake.gd")

## Halos: the boat's lantern, a floating lantern (m across, strength).
const HALO_BOAT := Vector2(1.0,0.85)
const HALO_FLOAT := Vector2(0.75,0.75)
## Reflections: of lights at most this high over the water (m), their
## width a share of the halo's, their strength a share of its.
const GLINT_HIGH := 9.0
const GLINT_WIDTH := 0.32
const GLINT_STRENGTH := 0.7
## How far the open water round a reflection is read (m).
const GLINT_OPEN := 8.0
## The paper's glow at full night; the boat's rock (rad) and bob (m).
const PAPER_GLOW := 2.4
const ROCK := 0.035
const BOB := 0.018

static var _shared := {}

static func _dresser() -> Script:
	return load(DRESSER)

static func _mats() -> Dictionary:
	if not _shared.is_empty(): return _shared
	var Dresser := _dresser()
	var paper := StandardMaterial3D.new()
	paper.albedo_color = LakeBuilds.PAPER
	paper.roughness = 0.85
	paper.emission_enabled = true
	paper.emission = Dresser.WARM
	paper.emission_energy_multiplier = 0.0
	var glint := ShaderMaterial.new()
	glint.shader = preload("res://shaders/lake_glint.gdshader")
	glint.render_priority = 20
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var boats := []
	for k in range(LakeBuilds.BOAT_PAINTS.size()): boats.append(LakeBuilds.boat(k))
	_shared = {"paper":paper,"glint":glint,"quad":quad,"boats":boats,"pad":LakeBuilds.lily(false),
		"bloom":LakeBuilds.lily(true),"bloom_pink":LakeBuilds.lily(true,true),"float":LakeBuilds.float_lantern()}
	return _shared

## Lets the shared pieces go (with the sky).
static func release() -> void:
	_shared = {}

## Stands the lake's floating things on `member` under `node`, adds their
## halos to `halos` ([position, size], the dresser's), then a reflection
## for every halo over the water; the boat's light goes in `live`.
static func furnish(node: Node3D, member: Dictionary, halos: Array, live: Dictionary) -> void:
	var shape: RefCounted = member.shape
	if shape.lake.is_empty(): return
	var m := _mats()
	var Dresser := _dresser()
	var solid: Material = Dresser._mats().solid
	var level: float = shape.water_level
	var life := Life.new()
	life.name = "LakeLife"
	life.paper = m.paper
	life.glint = m.glint
	life.halo = Dresser._mats().halo
	node.add_child(life)
	for f: Dictionary in member.features:
		match str(f.type):
			"boat":
				var boat := MeshInstance3D.new()
				boat.name = "Boat"
				boat.mesh = (m.boats as Array)[int(f.get("paint",0)) % (m.boats as Array).size()]
				boat.material_override = solid
				boat.position = Vector3(f.at.x,level-LakeBuilds.DRAFT,f.at.y)
				boat.rotation.y = float(f.angle)
				node.add_child(boat)
				var lantern: MeshInstance3D = Dresser._lantern(boat,LakeBuilds.BOAT_LANTERN,1.0)
				halos.append([boat.transform*(LakeBuilds.BOAT_LANTERN+Vector3.UP*0.14),HALO_BOAT])
				Dresser._light(lantern,Vector3(0.0,0.12,0.0),4.5,0.9,Dresser.FADE_SMALL,live)
				life.add(boat,ROCK,BOB)
			"floats":
				_lilies(node,f.lilies,level)
				for p: Vector2 in f.lanterns:
					var lantern := MeshInstance3D.new()
					lantern.name = "FloatingLantern"
					lantern.mesh = m.float
					lantern.set_surface_override_material(0,solid)
					lantern.set_surface_override_material(1,m.paper)
					lantern.position = Vector3(p.x,level-0.02,p.y)
					lantern.rotation.y = fposmod(p.x*3.1+p.y*1.7,TAU)
					lantern.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					node.add_child(lantern)
					halos.append([lantern.position+LakeBuilds.float_glow()+Vector3.UP*0.04,HALO_FLOAT])
					life.add(lantern,ROCK*1.5,BOB*0.8)
	_glints(node,shape,halos)

## The lilies, one batch a kind of pad, lying on the water.
static func _lilies(node: Node3D, lilies: Array, level: float) -> void:
	var kinds := {"pad":[],"bloom":[],"bloom_pink":[]}
	for l: Array in lilies:
		var kind := "pad" if not l[4] else ("bloom_pink" if l[5] else "bloom")
		(kinds[kind] as Array).append(l)
	for kind: String in kinds:
		var list: Array = kinds[kind]
		if list.is_empty(): continue
		var batch := MultiMeshInstance3D.new()
		batch.name = "Lilies"
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = _mats()[kind]
		multi.instance_count = list.size()
		for k in range(list.size()):
			var l: Array = list[k]
			var size: float = l[3]
			multi.set_instance_transform(k,Transform3D(Basis(Vector3.UP,float(l[2])).scaled(Vector3.ONE*size),Vector3(l[0],level+0.008,l[1])))
			var tone := 0.88+0.24*fposmod(float(l[0])*7.13+float(l[1])*3.7,1.0)
			multi.set_instance_color(k,Color(tone,tone,tone))
		batch.multimesh = multi
		batch.material_override = _dresser()._mats().solid
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		batch.visibility_range_end = 220.0
		node.add_child(batch)

## A reflection on the water under every halo standing over the lake.
static func _glints(node: Node3D, shape: RefCounted, halos: Array) -> void:
	var level: float = shape.water_level
	var list: Array = []
	for h: Array in halos:
		var at: Vector3 = h[0]
		var flat := Vector2(at.x,at.z)
		var high := at.y-level
		if high <= 0.0 or high > GLINT_HIGH or not shape.wet(flat): continue
		list.append([flat,high,h[1],_open(shape,flat)])
	if list.is_empty(): return
	var batch := MultiMeshInstance3D.new()
	batch.name = "Glints"
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.use_custom_data = true
	multi.mesh = _mats().quad
	multi.instance_count = list.size()
	for k in range(list.size()):
		var g: Array = list[k]
		var size: Vector2 = g[2]
		var flat: Vector2 = g[0]
		multi.set_instance_transform(k,Transform3D(Basis.from_scale(Vector3.ONE*size.x*GLINT_WIDTH),Vector3(flat.x,level,flat.y)))
		multi.set_instance_color(k,Color(_dresser().WARM,size.y*GLINT_STRENGTH))
		multi.set_instance_custom_data(k,Color(float(g[1]),float(g[3]),0.0,0.0))
	batch.multimesh = multi
	batch.material_override = _mats().glint
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	batch.custom_aabb = AABB(Vector3(-60.0,-20.0,-60.0),Vector3(120.0,60.0,120.0))
	node.add_child(batch)

## How far open water reaches from `p` every way (m, the least).
static func _open(shape: RefCounted, p: Vector2) -> float:
	var least := GLINT_OPEN
	for k in range(8):
		var way := Vector2.from_angle(TAU*k/8.0)
		var run := 0.0
		while run < least and shape.wet(p+way*(run+0.5)): run += 0.5
		least = minf(least,run)
	return maxf(least,0.3)

## A lake's slow life: what floats rocks and bobs, each on its own beat,
## and the paper and the reflections glow with the night.
class Life extends Node3D:
	var things: Array = []
	var clock := 0.0
	var paper: StandardMaterial3D
	var glint: ShaderMaterial
	var halo: ShaderMaterial

	func add(thing: Node3D, rock: float, bob: float) -> void:
		things.append([thing,thing.position.y,thing.rotation.y,rock,bob,fposmod(thing.position.x*0.37+thing.position.z*0.61,TAU)])

	func _process(delta: float) -> void:
		clock += delta
		var night: Variant = halo.get_shader_parameter("glow")
		var glow := float(night) if night != null else 0.0
		paper.emission_energy_multiplier = PAPER_GLOW*glow
		glint.set_shader_parameter("glow",glow)
		if not is_visible_in_tree(): return
		for t: Array in things:
			var thing: Node3D = t[0]
			if not is_instance_valid(thing): continue
			var phase: float = t[5]
			thing.position.y = float(t[1])+sin(clock*1.1+phase)*float(t[4])
			thing.rotation = Vector3(sin(clock*0.7+phase*1.3)*float(t[3])*0.6,float(t[2]),sin(clock*0.83+phase)*float(t[3]))
