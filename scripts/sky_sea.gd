extends MeshInstance3D
## The near cloud sea (shaders/sky_sea.gdshader): a floor of cumulus heaps,
## the towering cumulus' own cloud (scripts/sky_towers.gd) only low and
## wide, at their own height in the world, about SEA metres down, out to
## `reach`, where the dome's painted sea (shaders/sky_cloud_sea.gdshaderinc)
## takes over to the horizon. So the near sea slides by under a glide and
## swings under a turn, the islands' shadows lie on it and they ride on a
## swell of it, and a mountain's foot stands softly in it.
##
## A box round the eye (`follow`), its inside faces only starting the rays,
## so nothing about it needs sorting against what stands in it. The look
## pass (scripts/look_pass.gd) owns it: it follows the camera each frame and
## takes the sea's strength and style from the sky (`set_sea`), so F6,
## --no-cloud-sea and Settings > Clouds turn it with the dome's. The
## islands under the glide (scripts/sky_islands.gd) are handed it
## (`island_spots`), the plate's own first, and the ranges standing near
## (`set_ranges`), round whose feet the heaps close their gaps. The
## cauliflower on the heaps is the towers' noise volume (scripts/
## cumulus_noise.gd), made on a worker and handed over once it is ready
## (`_take_noise`); till then the heaps are their smooth envelope.
##
## That envelope (the heap-field and the domes of `sea_rise`) is the
## costliest part of the march, some forty hashes a step; it only drifts, so
## it is baked into a texture over a square of the drifting field round the
## eye (`_bake`, shaders/sky_sea_envelope.gdshader) and read from there,
## baked again only once the eye has gone BAKE_MOVE from the square's middle.
## The swells under the islands and round the ranges' feet sit still in the
## world, so they are baked likewise in a square of the world (`_bake_swells`,
## shaders/sky_sea_swells.gdshader), again when the eye has gone as far or the
## islands or ranges it is told of change.

const SkyIslands = preload("res://scripts/sky_islands.gd")
const NativeTerrainData = preload("res://scripts/native_terrain_data.gd")
const IslandShore = preload("res://scripts/island_shore.gd")
const CumulusNoise = preload("res://scripts/cumulus_noise.gd")
## The heaps' feet and their tallest (m); the swell over them under an
## island (shaders/sky_sea.gdshader SWELL), for the box.
const FLOOR := -150.0
const TALL := 45.0
const SWELL := 22.0
const HEADROOM := 1.3
## How far out it reaches (m), never past this share of the camera's far
## plane (the box's far corners must stand inside it).
const REACH := 2400.0
const FAR_SHARE := 0.6
## Islands and ranges it is told of, nearest first (shaders/sky_sea.gdshader
## `islands`, `ranges`).
const ISLANDS := 8
const RANGES := 4
## Drawn before the glide's towers (scripts/sky_towers.gd RENDER_PRIORITY),
## which rise out of it.
const RENDER_PRIORITY := -2
## The envelope's bake: texels a side, how far past `reach` it covers (m;
## past the march's furthest taps), how far the eye goes from its middle
## before it is baked again, and the heaps' cell and drift (m, m/s; as
## shaders/sky_sea.gdshader CELL and DRIFT).
const BAKE_TEXELS := 2048
const BAKE_PAST := 600.0
const BAKE_MOVE := 400.0
const CELL := 72.0
const DRIFT := Vector2(0.6,0.35)*1.2
## How far round an island its swell starts and ends, in its reaches (as
## shaders/sky_sea.gdshader SWELL_REACH).
const SWELL_REACH := Vector2(0.6,1.5)

var material := ShaderMaterial.new()
var reach := REACH
var _box := BoxMesh.new()
var _has_noise := false
var _bake_view := SubViewport.new()
var _bake_material := ShaderMaterial.new()
var _baked_middle := Vector2.INF
var _baked_side := 0.0
var _swell_view := SubViewport.new()
var _swell_material := ShaderMaterial.new()
var _swells_middle := Vector2.INF
var _swells_side := 0.0
var _swells_key := PackedVector3Array()
var _eye_xz := Vector2.INF
var _islands := PackedVector4Array()
var _ranges := PackedVector4Array()

func _init() -> void:
	name = "SkySea"
	visible = false
	material.shader = preload("res://shaders/sky_sea.gdshader")
	material.render_priority = RENDER_PRIORITY
	material.set_shader_parameter("floor_y",FLOOR)
	material.set_shader_parameter("tall",TALL)
	material_override = material
	mesh = _box
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ignore_occlusion_culling = true
	set_islands([])
	set_ranges([])
	_size(REACH)
	_bake_material.shader = preload("res://shaders/sky_sea_envelope.gdshader")
	_bake_material.set_shader_parameter("cell",CELL)
	_sheet(_bake_view,"EnvelopeBake",_bake_material)
	material.set_shader_parameter("envelope",_bake_view.get_texture())
	_swell_material.shader = preload("res://shaders/sky_sea_swells.gdshader")
	_swell_material.set_shader_parameter("swell_reach",SWELL_REACH)
	_sheet(_swell_view,"SwellBake",_swell_material)
	material.set_shader_parameter("swells",_swell_view.get_texture())

## The sea's strength (0 paints none) and style (scripts/look_pass.gd
## CLOUD_STYLES), as the sky has them.
func set_sea(strength: float, style: int) -> void:
	visible = strength > 0.0
	material.set_shader_parameter("cloud_sea",strength)
	material.set_shader_parameter("cloud_sea_style",style)

## Stands round `camera`, out as far as its far plane allows, the
## envelope baked round it at `motion_time` (the shaders' zs_motion_time).
func follow(camera: Camera3D, motion_time := 0.0) -> void:
	if camera == null: return
	var want := minf(REACH,camera.far*FAR_SHARE)
	if not is_equal_approx(want,reach): _size(want)
	_take_noise()
	var eye := camera.global_position
	_eye_xz = Vector2(eye.x,eye.z)
	_bake(_eye_xz+DRIFT*motion_time)
	_bake_swells()
	global_position = Vector3(eye.x,FLOOR+(TALL+SWELL)*HEADROOM*0.5,eye.z)
	material.set_shader_parameter("eye_xz",Vector2(eye.x,eye.z))

## The islands over the sea: Vector4(x, z, reach, underside's height), at
## most ISLANDS, nearest first.
func set_islands(spots: Array) -> void:
	var list := PackedVector4Array()
	for i in range(ISLANDS):
		list.append(spots[i] if i < spots.size() else Vector4.ZERO)
	material.set_shader_parameter("islands",list)
	_islands = list
	_bake_swells()

## The ranges standing near: Vector4(x, z, how far round, 0), at most
## RANGES, nearest first (scripts/sky_peaks.gd `keep_spots`, whose w is the
## reach).
func set_ranges(spots: Array) -> void:
	var list := PackedVector4Array()
	for i in range(RANGES):
		var spot: Vector4 = spots[i] if i < spots.size() else Vector4.ZERO
		list.append(Vector4(spot.x,spot.y,spot.w,0.0))
	material.set_shader_parameter("ranges",list)
	_ranges = list
	_bake_swells()

## The plate and the islands of `islands` (scripts/sky_islands.gd) nearest
## `eye`, as `set_islands` takes them; the plate alone when there are none.
static func island_spots(islands: Node, plate: Node3D, eye: Vector3) -> Array:
	var out := []
	var reach := SkyIslands.HALF*1.25
	# The middle of the underside: below the slab, part way down the keel.
	var under := NativeTerrainData.SLAB_BASE-IslandShore.DEEPEST*0.5
	var home := plate.global_position if plate != null else Vector3.ZERO
	out.append(Vector4(home.x,home.z,reach,home.y+under))
	if islands != null and islands.get("offsets") != null:
		var offsets: Array = islands.offsets
		for i in range(offsets.size()):
			var sunk: float = islands.sunk(i) if islands.has_method("sunk") else 0.0
			var at: Vector3 = home+offsets[i]+Vector3.DOWN*sunk
			out.append(Vector4(at.x,at.z,reach,at.y+under))
	var first: Vector4 = out[0]
	var rest := out.slice(1)
	rest.sort_custom(func(a: Vector4, b: Vector4) -> bool: return Vector2(a.x-eye.x,a.y-eye.z).length_squared() < Vector2(b.x-eye.x,b.y-eye.z).length_squared())
	return ([first]+rest).slice(0,ISLANDS)

func _exit_tree() -> void:
	CumulusNoise.settle()

## The cumulus' noise volume, once it is made (on a worker, never here).
func _take_noise() -> void:
	if _has_noise: return
	var noise := CumulusNoise.request()
	if noise == null: return
	_has_noise = true
	material.set_shader_parameter("cauliflower",noise)
	material.set_shader_parameter("has_noise",1.0)

## Bakes the envelope round `middle` (in the drifting field) when the eye
## has gone BAKE_MOVE from the last bake's middle or the reach has grown.
## The bake is drawn before the frame's 3D (a viewport inside it), so the
## sea reads the new square from the frame it is set.
func _bake(middle: Vector2) -> void:
	var side := (reach+BAKE_PAST)*2.0
	if middle.distance_to(_baked_middle) < BAKE_MOVE and side <= _baked_side: return
	_baked_middle = middle
	_baked_side = side
	var corner := middle-Vector2.ONE*side*0.5
	_bake_material.set_shader_parameter("origin",corner)
	_bake_material.set_shader_parameter("side",side)
	_bake_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	material.set_shader_parameter("envelope_at",Vector4(corner.x,corner.y,side,1.0))

## Bakes the swells round the eye when it has gone BAKE_MOVE from the last
## bake's middle, the reach has grown, or the islands or ranges (where they
## stand and how far round) have changed. Drawn before the frame's 3D, as
## `_bake`.
func _bake_swells() -> void:
	if _eye_xz == Vector2.INF: return
	var key := PackedVector3Array()
	for spot: Vector4 in _islands: key.append(Vector3(spot.x,spot.y,spot.z))
	for spot: Vector4 in _ranges: key.append(Vector3(spot.x,spot.y,spot.z))
	var side := (reach+BAKE_PAST)*2.0
	if _eye_xz.distance_to(_swells_middle) < BAKE_MOVE and side <= _swells_side and key == _swells_key: return
	_swells_middle = _eye_xz
	_swells_side = side
	_swells_key = key
	var corner := _eye_xz-Vector2.ONE*side*0.5
	_swell_material.set_shader_parameter("origin",corner)
	_swell_material.set_shader_parameter("side",side)
	_swell_material.set_shader_parameter("islands",_islands)
	_swell_material.set_shader_parameter("ranges",_ranges)
	_swell_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	material.set_shader_parameter("swells_at",Vector4(corner.x,corner.y,side,1.0))

## A bake: `view` drawing one sheet of `sheet_material` over all its texels,
## in float, only when asked (UPDATE_ONCE).
func _sheet(view: SubViewport, view_name: String, sheet_material: ShaderMaterial) -> void:
	view.name = view_name
	view.size = Vector2i(BAKE_TEXELS,BAKE_TEXELS)
	view.disable_3d = true
	view.use_hdr_2d = true
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var sheet := ColorRect.new()
	sheet.size = Vector2(BAKE_TEXELS,BAKE_TEXELS)
	sheet.material = sheet_material
	view.add_child(sheet)
	add_child(view)

func _size(value: float) -> void:
	reach = value
	material.set_shader_parameter("reach",reach)
	_box.size = Vector3(reach*2.0,(TALL+SWELL)*HEADROOM+2.0,reach*2.0)
	# The shader draws it wherever the box is on screen; never cull it.
	custom_aabb = AABB(-_box.size*0.5,_box.size)
