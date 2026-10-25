class_name NativeGardenFalls
extends Node3D
## Authored falls use the same animated ring shader as the imported waterfall.
const RINGS := 32
const SECTIONS := 10
var _sprays: Array[CanvasLayer] = []
var _entries := {}
var reused_falls := 0
var rebuilt_falls := 0
var _mist_recipe: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/fall-mist.json"))

static func endpoints(data: NativeTerrainData, item: Dictionary) -> PackedVector3Array:
	var start := data.object_position(item)+Vector3.UP*0.12
	var end_point := Vector2(item.end_x,item.end_z)
	var finish := Vector3(end_point.x,data.ground_height(end_point)+0.06,end_point.y)
	for pond: Dictionary in data.ponds:
		if GardenWater.covers(data.pond_surface(pond),end_point):
			finish.y = maxf(finish.y,pond.level)
	return PackedVector3Array([start,finish])

static func build_course(data: NativeTerrainData, item: Dictionary) -> PackedVector3Array:
	var ends := endpoints(data,item)
	if ends[0].y <= ends[1].y+0.2:
		return PackedVector3Array()
	var water := PackedVector3Array()
	for pond: Dictionary in data.ponds:
		var surface := data.pond_surface(pond)
		if GardenWater.covers(surface,Vector2(item.end_x,item.end_z)):
			water = surface
			break
	var course := NativeWaterCourse.trace(data,ends[0],ends[1],RINGS,water)
	for i in range(course.size()):
		var tangent := course[mini(i+1,course.size()-1)]-course[maxi(0,i-1)]
		var across := Vector3(tangent.x,0,tangent.z).normalized().cross(Vector3.UP)
		if NativeWaterCourse.half_width(data,course[i],across,item.scale*(0.28+0.18*float(i)/(RINGS-1))) <= 0.0:
			return PackedVector3Array()
	return course

static func clear_path(data: NativeTerrainData, item: Dictionary) -> bool:
	return not build_course(data,item).is_empty()

## Keep live nodes until the next rebuild, but force that rebuild to reconstruct
## every result. The editor's reference refresh can bypass semantic reuse too.
func discard_cache() -> void:
	for id in _entries:
		_entries[id].signature = PackedByteArray()

func rebuild(data: NativeTerrainData) -> void:
	var current := {}
	_sprays.clear()
	for item: Dictionary in data.objects:
		if item.asset != "waterfall": continue
		var description := _describe(data,item)
		if description.is_empty(): continue
		# Compare the actual rendered inputs, not an approximate dirty rectangle.
		# Terrain can change anywhere without disturbing an identical fall/spray.
		var signature := var_to_bytes([description,_mist_recipe])
		var entry: Dictionary = _entries.get(item.id,{})
		if not entry.is_empty() and entry.signature == signature:
			reused_falls += 1
		else:
			if not entry.is_empty():
				entry.mesh.free()
				entry.spray.free()
			entry = _create(item,description)
			entry.signature = signature
			rebuilt_falls += 1
		current[item.id] = entry
		_sprays.append(entry.spray)
		move_child(entry.mesh,current.size()*2-2)
		move_child(entry.spray,current.size()*2-1)
	for id in _entries:
		if not current.has(id):
			_entries[id].mesh.free()
			_entries[id].spray.free()
	_entries = current

func _describe(data: NativeTerrainData,item: Dictionary) -> Dictionary:
	var ends := endpoints(data,item)
	var course := build_course(data,item)
	if ends[0].y <= ends[1].y+0.2 or course.is_empty():
		return {} # Keep the record so undoing an obstruction restores the fall.
	var centers := PackedVector4Array()
	var widths := PackedVector4Array()
	var thicknesses := PackedVector4Array()
	var aeration := PackedVector2Array()
	centers.resize(32)
	widths.resize(32)
	thicknesses.resize(32)
	aeration.resize(32)
	var direction := Vector3(ends[1].x-ends[0].x,0,ends[1].z-ends[0].z).normalized()
	var across := direction.cross(Vector3.UP).normalized()
	var length := 0.0
	var previous := ends[0]
	for i in range(RINGS):
		var t := float(i)/(RINGS-1)
		var point := course[i]
		var tangent := (course[mini(i+1,RINGS-1)]-course[maxi(0,i-1)]).normalized()
		direction = Vector3(tangent.x,0,tangent.z).normalized()
		across = direction.cross(Vector3.UP).normalized()
		var outward := across.cross(tangent).normalized()
		length += point.distance_to(previous)
		previous = point
		centers[i] = Vector4(point.x,point.y,point.z,length)
		widths[i] = Vector4(across.x,across.y,across.z,NativeWaterCourse.half_width(data,point,across,item.scale*(0.28+0.18*t)))
		thicknesses[i] = Vector4(outward.x,outward.y,outward.z,item.scale*0.07)
		aeration[i] = Vector2(clampf(-tangent.y,0.0,1.0)*0.75,clampf(-tangent.y,0.0,1.0))
	var in_pool := false
	for pond: Dictionary in data.ponds:
		if GardenWater.covers(data.pond_surface(pond),Vector2(item.end_x,item.end_z)): in_pool = true
	return {"ends":ends,"centers":centers,"widths":widths,"thicknesses":thicknesses,"aeration":aeration,"scale":item.scale,"in_pool":in_pool}

func _create(item: Dictionary,description: Dictionary) -> Dictionary:
	var ends: PackedVector3Array = description.ends
	var centers: PackedVector4Array = description.centers
	var widths: PackedVector4Array = description.widths
	var thicknesses: PackedVector4Array = description.thicknesses
	var aeration: PackedVector2Array = description.aeration
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in range(RINGS-1):
		for section in range(SECTIONS):
			for corner: Vector2i in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1)]:
				var r := ring+corner.x
				var angle := TAU*(section+corner.y)/SECTIONS
				surface.set_uv(Vector2(r,angle))
				surface.set_uv2(Vector2(ring,section))
				surface.set_color(Color.WHITE)
				surface.set_normal(Vector3.UP)
				var c := centers[r]
				var a := widths[r]
				var b := thicknesses[r]
				surface.add_vertex(Vector3(c.x,c.y,c.z)+Vector3(a.x,a.y,a.z)*cos(angle)*a.w+Vector3(b.x,b.y,b.z)*sin(angle)*b.w)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/reference_fall.gdshader")
	material.set_shader_parameter("ring_count",RINGS)
	material.set_shader_parameter("centers_tau",centers)
	material.set_shader_parameter("axis_a_width",widths)
	material.set_shader_parameter("axis_b_thick",thicknesses)
	material.set_shader_parameter("aer_steep",aeration)
	material.set_shader_parameter("section_white",PackedFloat32Array([0.1,0.3,0.2,0.5,0.2,0.4,0.1,0.3,0.2,0.4,0.2,0.1]))
	material.set_shader_parameter("body_white",0.12)
	material.set_shader_parameter("height_range",Vector2(ends[1].y,ends[0].y))
	var mesh := MeshInstance3D.new()
	mesh.name = "Waterfall_%d" % item.id
	mesh.mesh = surface.commit()
	mesh.material_override = material
	mesh.extra_cull_margin = 0.5
	add_child(mesh)
	# The plunge lives under the fall mesh so the falls node keeps one mesh and
	# one spray child per waterfall, and both are freed together.
	var plunge := preload("res://scripts/waterfall_plunge.gd").new()
	mesh.add_child(plunge)
	plunge.setup(ends[1],float(item.scale),bool(description.get("in_pool",false)))

	var spray := preload("res://scripts/shared/fall_mist.gd").new()
	var recipe := _mist_recipe.duplicate(true)
	var center := Vector3.ZERO
	for i in range(recipe.phase.size()):
		center += Vector3(recipe.positions[i*3],recipe.positions[i*3+1],recipe.positions[i*3+2])
	center /= recipe.phase.size()
	for i in range(recipe.phase.size()):
		var offset := Vector3(recipe.positions[i*3],recipe.positions[i*3+1],recipe.positions[i*3+2])-center
		var point: Vector3 = ends[1]+offset*float(item.scale)+Vector3.UP*0.1
		recipe.positions[i*3] = point.x
		recipe.positions[i*3+1] = point.y
		recipe.positions[i*3+2] = point.z
	add_child(spray)
	spray.setup(recipe)
	return {"mesh":mesh,"spray":spray,"plunge":plunge}

func _process(delta: float) -> void:
	var scene := get_parent()
	if _sprays.is_empty():
		return
	var paused: bool = scene.get("_paused") == true
	for entry in _entries.values():
		if not entry.has("plunge"): continue
		entry.plunge.visible = scene._growth.terrain >= 0.995 and scene._growth.water >= 0.5
		entry.plunge.set_paused(paused)
		if not paused: entry.plunge.advance(delta)
	var depth: CompositorEffect
	if scene._display_fog != null:
		depth = scene._display_fog.depth
	else:
		# Share the original mist's fallback capture; multiple sprays must not
		# replace one another's camera compositor.
		var original: CanvasLayer = scene.get_node("WaterfallSpray")
		original.update_view(scene.camera)
		depth = original.fallback_depth
	for spray in _sprays:
		spray.visible = scene._growth.terrain >= 0.995 and scene._growth.water >= 0.5
		spray.update_view(scene.camera,depth)
