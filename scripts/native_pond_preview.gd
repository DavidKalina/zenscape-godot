extends MeshInstance3D
## A read-only view of the same connected flood used when placing a pond.
var _pending: Variant = null
var _level := INF
var _age := 0.0
var _checked := false

func _init() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var look := StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.albedo_color = Color(0.18,0.75,0.95,0.55)
	look.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = look
	position.y = 0.035
	hide()

func clear() -> void:
	hide()
	_pending = null
	_checked = false
	_age = 0.0

static func evaluate(data: NativeTerrainData, point: Vector2, level: float) -> Dictionary:
	var height: Variant = data.ground_height(point)
	if height == null:
		return {"vertices":PackedVector3Array(),"message":"Point inside the diorama to fill a pond."}
	if not is_finite(level) or level <= height or level > NativeTerrainData.MAX_HEIGHT:
		return {"vertices":PackedVector3Array(),"message":"Water is below this ground. Dig a hollow, or raise the water level in Settings."}
	var vertices := data.pond_surface({"x":point.x,"z":point.y,"level":level})
	if vertices.is_empty():
		return {"vertices":vertices,"message":"Water would spill out. Lower the water level or build up the banks."}
	return {"vertices":vertices,"message":"Blue shows the pond shoreline. Click to fill; adjust Water level in Settings."}

func hover(data: NativeTerrainData, hit: Variant, level: float, delta: float) -> String:
	if hit == null:
		clear()
		return ""
	var point := Vector2(hit.x,hit.z)
	if _pending == null or point.distance_to(_pending)>0.08 or not is_equal_approx(level,_level):
		_pending = point
		_level = level
		_age = 0.0
		_checked = false
		hide()
	_age += delta
	# Flood once after the pointer settles, not once per animation frame.
	if _checked or _age<0.12: return ""
	_checked = true
	var result := evaluate(data,point,level)
	var vertices: PackedVector3Array = result.vertices
	if vertices.is_empty():
		mesh = null
	else:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		var surface := ArrayMesh.new()
		surface.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		mesh = surface
		show()
	return result.message
