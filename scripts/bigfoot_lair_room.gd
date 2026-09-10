extends Node3D
## Full-footprint lower story: thick rock walls with permanent viewing openings.
## Seed changes dressing, never the dry bed or puddle footprint.
signal supplies_changed

const MAX_LIVING_STAGE := 3
const LAYER := 4
const HALF_WIDTH := 14.2
const CEILING := 8.3
const Genome = preload("res://scripts/cave_genome.gd")
var genome := preload("res://scripts/inland_genome.gd").cave(37)
var layout: Dictionary
var bed_point: Vector3
var pool_point: Vector3
var bed := Marker3D.new()
var drips := preload("res://scripts/waterfall_drips.gd").new()
var dressing := Node3D.new()
var palette := preload("res://scripts/native_terrain_palette.gd").new()
var seed_value := 37
var bed_stage := 0
var play_stage := 0
var bedding := Node3D.new()
var play_stones := Node3D.new()

func _ready() -> void:
	layout = Genome.sample(genome)
	bed_point = Vector3(layout.bed.x,0.15,layout.bed.y)
	pool_point = Vector3(layout.pool.x,-0.13,layout.pool.y)
	seed_value = genome.seed
	add_child(bed)
	bed.position = bed_point
	add_child(dressing)
	add_child(drips)
	_build_floor()
	_build_walls()
	_build_puddle()
	_build_bed()
	_draw_play_stones()
	_draw_stockpile()
	redress(seed_value)
	for spec in [[bed_point+Vector3.UP*4.5,Genome.PALETTES[genome.palette].light,2.6],[pool_point+Vector3.UP*4,Genome.PALETTES[genome.palette].light,0.8],[Vector3(0,5,-6),Genome.PALETTES[genome.palette].light,0.45]]:
		var light := OmniLight3D.new()
		light.position = spec[0]
		light.light_color = spec[1]
		light.light_energy = spec[2]
		light.omni_range = 14.0
		light.light_cull_mask = LAYER | 1
		light.shadow_enabled = true
		add_child(light)
	# Gentle exterior bounce keeps the rock reveals readable below the canopy.
	for point in [Vector3(0,4,23),Vector3(-23,4,0),Vector3(23,4,0),Vector3(0,4,-23)]:
		var fill := OmniLight3D.new()
		fill.position = point
		fill.omni_range = 35
		fill.light_energy = 2.4
		fill.light_color = Color("b9bdc7")
		fill.light_cull_mask = LAYER
		add_child(fill)
	# Window bounce reaches the seated face and hands, making small home
	# performances readable without brightening the entire underground story.
	var bed_fill := OmniLight3D.new()
	bed_fill.name = "BedWindowBounce"
	bed_fill.position = bed_point+Vector3(0,2.6,3.2)
	bed_fill.light_color = Genome.PALETTES[genome.palette].light
	bed_fill.light_energy = 1.8
	bed_fill.omni_range = 7.0
	bed_fill.light_cull_mask = LAYER | 1
	bed_fill.shadow_enabled = true
	add_child(bed_fill)
	_layers(self)

func _layers(root: Node) -> void:
	if root is GeometryInstance3D: root.layers = LAYER
	for child in root.get_children(): _layers(child)

func _mesh(surface: SurfaceTool, parent: Node = self) -> MeshInstance3D:
	surface.generate_normals()
	var node := MeshInstance3D.new()
	node.mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.95
	node.material_override = material
	parent.add_child(node)
	node.layers = LAYER
	return node

func _triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	st.set_color(color)
	st.set_smooth_group(-1)
	# Godot front faces use clockwise winding; keep each rock facet flat.
	for point in [a,c,b]: st.add_vertex(point)

func floor_height(x: float, z: float) -> float:
	var point := Vector2(x,z)
	var basin := point.distance_to(Vector2(pool_point.x,pool_point.z))
	var bed_distance := point.distance_to(Vector2(bed_point.x,bed_point.z))
	var relief := (palette.noise.fbm(x*0.3,z*0.3)-0.35)*1.1
	for i in range(2,layout.rooms.size()):
		var room: Dictionary = layout.rooms[i]
		var shoulder: Vector2 = room.center+Vector2(1.8,-1.3)
		relief += (float(room.height)-5.0)*0.65*exp(-point.distance_squared_to(shoulder)/(float(room.radius)*3.0))
	relief -= 0.25*exp(-pow(x-3.5,2)/3.0)*exp(-pow(z-3.0,2)/35.0)
	relief = lerpf(0.1,relief,smoothstep(0.65,1.8,Genome.passage_distance(layout,point)))
	relief = lerpf(0.1,relief,smoothstep(1.7,3.0,bed_distance))
	var pool_floor := -0.42*(1.0-smoothstep(0.8,1.8,basin))
	relief = lerpf(pool_floor,relief,smoothstep(1.8,2.9,basin))
	return relief*(1.0-smoothstep(12.0,14.0,maxf(absf(x),absf(z))))

func _damp_material(floor_surface := false) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/cave_rock.gdshader")
	material.set_shader_parameter("floor_surface",floor_surface)
	material.set_shader_parameter("bed_center",Vector2(bed_point.x,bed_point.z))
	material.set_shader_parameter("pool_center",Vector2(pool_point.x,pool_point.z))
	material.set_shader_parameter("moisture",float(genome.moisture))
	material.set_shader_parameter("rock_tint",Genome.PALETTES[genome.palette].rock)
	return material

func _build_floor() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(-14,14):
		for z in range(-14,14):
			var corners: Array[Vector3] = []
			for offset in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
				var point: Vector2 = Vector2(x,z)+offset
				if absf(point.x)<14 and absf(point.y)<14:
					var jitter := Vector2(palette.noise.hash_at(point.x,point.y),palette.noise.hash_at(point.y+43,point.x-17))-Vector2.ONE*0.5
					point += jitter*0.65
				corners.append(Vector3(point.x,floor_height(point.x,point.y),point.y))
			var color := palette.rock_at(Vector2(x,z))*Color(0.75,0.72,0.68)
			_triangle(st,corners[0],corners[2],corners[1],color)
			_triangle(st,corners[0],corners[3],corners[2],color.lightened(0.012))
	var floor_node := _mesh(st)
	floor_node.name = "LowerStoryFloor"
	floor_node.material_override = _damp_material(true)
	# Solid geological base, with a tapered bottom and faceted strata.
	var base := SurfaceTool.new()
	base.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in range(4):
		var turn := Basis(Vector3.UP,side*PI/2.0)
		for x in range(-14,14,2):
			var a := turn*Vector3(x,0,14)
			var b := turn*Vector3(x+2,0,14)
			var c := turn*Vector3(x*0.96,-1.6,13.44)
			var d := turn*Vector3((x+2)*0.96,-1.6,13.44)
			var color := palette.rock_at(Vector2(x,side))*Color(0.6,0.53,0.45)
			_triangle(base,a,c,b,color)
			_triangle(base,b,c,d,color.darkened(0.08))
	_triangle(base,Vector3(-13.44,-1.6,-13.44),Vector3(13.44,-1.6,13.44),Vector3(13.44,-1.6,-13.44),Color("292820"))
	_triangle(base,Vector3(-13.44,-1.6,-13.44),Vector3(-13.44,-1.6,13.44),Vector3(13.44,-1.6,13.44),Color("292820"))
	_mesh(base).name = "LowerStoryBase"

func _build_walls() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Two broad irregular windows per side. Their reveals are real rock depth,
	# so the openings remain legible while orbiting, without visibility tricks.
	for side in range(4):
		var turn := Basis(Vector3.UP,side*PI/2.0)
		for bay in range(2):
			var split := sin(side*1.9+0.4)*1.2
			var left := -HALF_WIDTH if bay==0 else split
			var right := split if bay==0 else HALF_WIDTH
			var middle := (left+right)*0.5
			var outer := [Vector2(left,0),Vector2(left,4),Vector2(left,CEILING+0.9),Vector2(middle,CEILING+0.9),Vector2(right,CEILING+0.9),Vector2(right,4),Vector2(right,0),Vector2(middle,0)]
			var inner := [Vector2(left+2.0,0.9),Vector2(left+1.35,3.8),Vector2(left+2.2,6.9),Vector2(middle,7.5),Vector2(right-2.0,6.7),Vector2(right-1.5,3.5),Vector2(right-2.3,0.85),Vector2(middle,0.65)]
			for i in range(8):
				inner[i] += Vector2(sin(i*2.7+side*3.1+bay)*0.3,cos(i*1.9+side+bay*2.3)*0.25)
			for i in range(8):
				var j := (i+1)%8
				var a: Vector3 = turn*Vector3(outer[i].x,outer[i].y,HALF_WIDTH)
				var b: Vector3 = turn*Vector3(outer[j].x,outer[j].y,HALF_WIDTH)
				var c: Vector3 = turn*Vector3(inner[i].x,inner[i].y,HALF_WIDTH)
				var d: Vector3 = turn*Vector3(inner[j].x,inner[j].y,HALF_WIDTH)
				var inward := turn*Vector3(0,0,-1.45)
				var color := palette.rock_at(Vector2(i+side*4,bay))*Color(0.82,0.75,0.65)
				_triangle(st,a,c,b,color)
				_triangle(st,b,c,d,color.lightened(0.016))
				_triangle(st,a+inward,b+inward,c+inward,color.darkened(0.12))
				_triangle(st,b+inward,d+inward,c+inward,color.darkened(0.08))
				_triangle(st,c,c+inward,d,color.darkened(0.18))
				_triangle(st,d,c+inward,d+inward,color.darkened(0.15))
	var walls := _mesh(st)
	walls.name = "WindowedRockWalls"
	walls.material_override = _damp_material()
	# The upstairs chunk is the ceiling; this underside overlaps its skirt.
	var roof := SurfaceTool.new()
	roof.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(-14,14,2):
		for z in range(-14,14,2):
			var a := Vector3(x,CEILING,z)
			var b := Vector3(x+2,CEILING,z)
			var c := Vector3(x,CEILING,z+2)
			var d := Vector3(x+2,CEILING,z+2)
			var color := palette.rock_at(Vector2(x,z))*Color(0.6,0.58,0.53)
			_triangle(roof,a,b,c,color)
			_triangle(roof,b,d,c,color)
	_mesh(roof).name = "UpperStoryUnderside"

func _build_puddle() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := pool_point
	for i in range(28):
		var a := TAU*i/28.0
		var b := TAU*(i+1)/28.0
		var radius_a := 1.25+0.08*sin(a*3.0)+0.04*cos(a*5.0)
		var radius_b := 1.25+0.08*sin(b*3.0)+0.04*cos(b*5.0)
		_triangle(st,center,center+Vector3(cos(b),0,sin(b))*radius_b,center+Vector3(cos(a),0,sin(a))*radius_a,Color.WHITE)
	var node := _mesh(st)
	node.name = "CavePuddle"
	var water := ShaderMaterial.new()
	water.shader = preload("res://shaders/cave_water.gdshader")
	water.set_shader_parameter("water_color",Genome.PALETTES[genome.palette].water)
	node.material_override = water
	drips.add_emitter(Vector3(center.x,ceiling_height(Vector2(center.x,center.z))-1.4,center.z),center+Vector3.UP*0.025)
	drips.add_emitter(Vector3(center.x+0.5,ceiling_height(Vector2(center.x+0.5,center.z-0.3))-1.1,center.z-0.3),center+Vector3(0.5,0.025,-0.3))

func _build_bed() -> void:
	if bedding.get_parent()==null:
		bedding.name = "Bedding"
		add_child(bedding)
	_clear_visuals(bedding)
	bedding.set_meta("stage",bed_stage)
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	# A sparse starting bed becomes visibly deeper and greener as he tends it.
	for i in range(12+bed_stage*16):
		var leaf := MeshInstance3D.new()
		leaf.name = "BedLeaf%d" % i
		var shape := SphereMesh.new()
		shape.radial_segments = 5
		shape.rings = 2
		shape.radius = 0.4
		shape.height = 0.8
		leaf.mesh = shape
		leaf.position = bed_point+Vector3(rng.randf_range(-1.2,1.2),0.025+float(i/16)*0.055,rng.randf_range(-0.75,0.75))
		leaf.scale = Vector3(1,0.12+bed_stage*0.035,0.5)
		leaf.rotation.y = rng.randf_range(0,TAU)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("776944").lerp(Color("7c854d"),bed_stage/3.0).lightened(rng.randf_range(-0.12,0.12))
		mat.roughness = 0.95
		leaf.material_override = mat
		leaf.layers = LAYER
		bedding.add_child(leaf)
	for i in range(bed_stage*3):
		var twig := MeshInstance3D.new()
		twig.name = "BedRim%d" % i
		var shape := CylinderMesh.new()
		shape.radial_segments = 5
		shape.top_radius = 0.045
		shape.bottom_radius = 0.065
		shape.height = 0.9
		twig.mesh = shape
		var angle := TAU*i/9.0
		twig.position = bed_point+Vector3(cos(angle)*1.35,0.07,sin(angle)*0.9)
		twig.rotation = Vector3(PI*0.5,-angle,0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("67513a")
		twig.material_override = mat
		twig.layers = LAYER
		bedding.add_child(twig)

func _clear_visuals(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func _draw_play_stones() -> void:
	if play_stones.get_parent()==null:
		play_stones.name = "PlayStones"
		add_child(play_stones)
	_clear_visuals(play_stones)
	play_stones.set_meta("stage",play_stage)
	# Selected pebbles from the cave floor form a small, carefully balanced cairn.
	var point := _play_origin()
	var height := point.y
	for i in range(MAX_LIVING_STAGE):
		var stone := MeshInstance3D.new()
		stone.name = ("BalancedStone%d" if i<play_stage else "LooseStone%d") % i
		var shape := SphereMesh.new()
		shape.radial_segments = 6
		shape.rings = 3
		shape.radius = 0.36-i*0.055
		shape.height = shape.radius*2.0
		stone.mesh = shape
		stone.scale = Vector3(1.15,0.5,0.85)
		if i<play_stage:
			stone.position = Vector3(point.x+sin(i*2.0)*0.045,height+shape.radius*0.5,point.z)
			height += shape.radius
		else:
			var loose := point+Vector3(-0.7+i*0.6,0,0.65+sin(i*1.8)*0.25)
			loose.y = (floor_height(loose.x,loose.z) if not layout.is_empty() else bed_point.y)+shape.radius*0.5
			stone.position = loose
		stone.rotation.y = i*1.7
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("7b8581").lightened(i*0.055)
		mat.roughness = 0.85
		stone.material_override = mat
		stone.layers = LAYER
		play_stones.add_child(stone)

func _spike(point: Vector3, length: float, radius: float, hanging: bool) -> void:
	var mesh := CylinderMesh.new()
	mesh.radial_segments = 5
	mesh.rings = 1
	mesh.top_radius = radius if hanging else 0.025
	mesh.bottom_radius = 0.025 if hanging else radius
	mesh.height = length
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = point+Vector3.UP*length*(-0.5 if hanging else 0.5)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("837b69")
	mat.roughness = 0.9
	node.material_override = mat
	dressing.add_child(node)
	node.layers = LAYER

func redress(value: int) -> void:
	seed_value = value
	for child in dressing.get_children():
		dressing.remove_child(child)
		child.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = value
	for i in range(42):
		var point := Vector3(rng.randf_range(-12.0,12.0),0,rng.randf_range(-12.0,12.0))
		if Genome.field(layout,Vector2(point.x,point.z))<0.7: continue
		point.y = ceiling_height(Vector2(point.x,point.z))
		_spike(point,rng.randf_range(0.45,1.8),rng.randf_range(0.16,0.45),true)
	for i in range(16):
		var point := Vector3(rng.randf_range(-11.5,11.5),0,rng.randf_range(-11.5,3.0))
		point.y = floor_height(point.x,point.z)
		if Genome.field(layout,Vector2(point.x,point.z))<0.7: continue
		if Vector2(point.x-bed_point.x,point.z-bed_point.z).length()<2: continue
		_spike(point,rng.randf_range(0.3,1.3),rng.randf_range(0.2,0.4),false)
	for i in range(26):
		var point := Vector3(rng.randf_range(-11.5,11.5),0,rng.randf_range(-11.5,11.5))
		if Genome.field(layout,Vector2(point.x,point.z))<0.7: continue
		if Vector2(point.x-bed_point.x,point.z-bed_point.z).length()<2.7: continue
		if Vector2(point.x-pool_point.x,point.z-pool_point.z).length()<2.4: continue
		var rock := MeshInstance3D.new()
		var shape := SphereMesh.new()
		shape.radial_segments = 5
		shape.rings = 2
		shape.radius = rng.randf_range(0.2,0.65)
		shape.height = shape.radius*1.7
		rock.mesh = shape
		point.y = floor_height(point.x,point.z)+shape.radius*0.15
		rock.position = point
		rock.scale = Vector3(1.3,0.7,0.8)
		rock.rotation.y = rng.randf_range(0,TAU)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("3d4745")
		material.roughness = 0.5
		rock.material_override = material
		dressing.add_child(rock)
		rock.layers = LAYER
	_spike(Vector3(pool_point.x,ceiling_height(Vector2(pool_point.x,pool_point.z)),pool_point.z),1.4,0.3,true)
	_spike(Vector3(pool_point.x+0.5,ceiling_height(Vector2(pool_point.x+0.5,pool_point.z-0.3)),pool_point.z-0.3),1.1,0.22,true)

var stash: Array = []
var stockpile := Node3D.new()

func can_receive_item(kind: String) -> bool:
	return kind in ["branch","leaves","fish","fruit"] and stash.size()<24

func receive_item_checked(kind: String, commit: Callable) -> bool:
	if not can_receive_item(kind) or not commit.is_valid(): return false
	if commit.call()!=true: return false
	return receive_item(kind)

func receive_item(kind: String) -> bool:
	if not can_receive_item(kind): return false
	stash.append(kind)
	_draw_stockpile()
	supplies_changed.emit()
	return true

func restore_stash(items: Array) -> void:
	stash = items.duplicate()
	_draw_stockpile()
	supplies_changed.emit()

func food_count() -> int:
	return stash.count("fruit")+stash.count("fish")

func material_count() -> int:
	return stash.count("leaves")+stash.count("branch")

func comfort() -> float:
	return float(bed_stage)/MAX_LIVING_STAGE

func tend_bed() -> bool:
	if bed_stage>=MAX_LIVING_STAGE or material_count()==0: return false
	stash.erase("leaves" if stash.has("leaves") else "branch")
	bed_stage += 1
	_build_bed()
	_draw_stockpile()
	supplies_changed.emit()
	return true

func eat_food() -> String:
	var kind := "fruit" if stash.has("fruit") else "fish" if stash.has("fish") else ""
	if kind.is_empty(): return ""
	stash.erase(kind)
	_draw_stockpile()
	supplies_changed.emit()
	return kind

func arrange_stone() -> bool:
	if play_stage>=MAX_LIVING_STAGE: return false
	play_stage += 1
	_draw_play_stones()
	return true

## Interaction locations are local to this room; callers use room.to_global().
func play_point() -> Vector3:
	return _play_origin()+Vector3.UP*0.2

func _play_origin() -> Vector3:
	# Keep the working collection within the seated resident's actual arm span.
	var point := bed_point+Vector3(-0.75,0,0.85)
	point.y = floor_height(point.x,point.z) if not layout.is_empty() else bed_point.y
	return point

func supply_point() -> Vector3:
	var point := bed_point+Vector3(2.35,0,-0.4)
	point.y = (floor_height(point.x,point.z) if not layout.is_empty() else bed_point.y)+0.2
	return point

func disturb_bed() -> bool:
	if bed_stage==0: return false
	bed_stage -= 1
	_build_bed()
	return true

func remove_one_supply() -> String:
	if stash.is_empty(): return ""
	var kind: String = stash.pop_back()
	_draw_stockpile()
	supplies_changed.emit()
	return kind

func capture_living() -> Dictionary:
	return {"bed_stage":bed_stage,"play_stage":play_stage}

func restore_living(state: Dictionary) -> void:
	if not valid_living(state): return
	bed_stage = int(state.bed_stage)
	play_stage = int(state.play_stage)
	_build_bed()
	_draw_play_stones()

static func valid_living(state: Variant) -> bool:
	if not state is Dictionary: return false
	for key in ["bed_stage","play_stage"]:
		var value: Variant = state.get(key)
		if not (value is int or value is float): return false
		if not is_finite(float(value)) or float(value)!=floorf(float(value)): return false
		if value<0 or value>MAX_LIVING_STAGE: return false
	return true

func document() -> Dictionary:
	return {"genome":genome.duplicate(true),"stash":stash.duplicate(),"living":capture_living()}

func _draw_stockpile() -> void:
	if stockpile.get_parent()==null:
		stockpile.name = "Stockpile"
		add_child(stockpile)
	_clear_visuals(stockpile)
	var center := Vector2(bed_point.x+1.9,bed_point.z-0.7)
	for i in range(stash.size()):
		var kind: String = stash[i]
		var node := MeshInstance3D.new()
		var mat := StandardMaterial3D.new()
		if kind=="branch":
			var branch := CylinderMesh.new()
			branch.top_radius = 0.05
			branch.bottom_radius = 0.07
			branch.height = 0.8
			branch.radial_segments = 5
			node.mesh = branch
			node.rotation.z = PI*0.5
			mat.albedo_color = Color("67513a")
		else:
			var shape := SphereMesh.new()
			shape.radius = 0.18
			shape.height = 0.36
			shape.radial_segments = 6
			shape.rings = 3
			node.mesh = shape
			node.scale = Vector3(1.8,0.5,0.7) if kind=="fish" else Vector3(1,0.2,1) if kind=="leaves" else Vector3.ONE
			mat.albedo_color = Color("7eabb2") if kind=="fish" else Color("827a45") if kind=="leaves" else Color("a36349")
		var point := center+Vector2((i%4)*0.35,(i/4%3)*0.3)
		var height := floor_height(point.x,point.y) if not layout.is_empty() else bed_point.y
		node.position = Vector3(point.x,height+0.13+float(i/12)*0.18,point.y)
		node.material_override = mat
		node.layers = LAYER
		stockpile.add_child(node)


func ceiling_height(_point: Vector2) -> float:
	return CEILING
