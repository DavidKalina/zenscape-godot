extends Node3D
## Clouds in the open air between the sky islands (scripts/sky_islands.gd),
## for the glide to fly past and through. Before these, the only clouds were
## the sky box's, which never come nearer.
##
## Each cloud is a heap of soft puffs, flat underneath and rounded on top
## (shaders/sky_cloud_puff.gdshader). They drift on the breeze and wrap
## round the field a whole cloud at a time. They keep clear of the islands,
## so they never hide a place, and are not set on a mountain range risen
## through the sea (scripts/sky_peaks.gd), whose cloud hugs its foot. `inside` says how deep a point is in a cloud,
## which the vapour reads (scripts/sky_flight.gd).
##
## The field follows the glide (`follow`): when the eye strays FOLLOW of
## the field's span from its middle, the field recentres on it, so islands
## that turn up far out (scripts/sky_cells.gd) have clouds round them too.
## Only clouds in the strip that re-wraps jump, at the far side of the
## field, most of a kilometre out in the haze.
##
## The node stays at the origin. The islands' swaps move the clouds through
## the shader's `shift`, so the wrap works in one frame.

const SkyPeaks = preload("res://scripts/sky_peaks.gd")
const SkyForestIsles = preload("res://scripts/sky_forest_isles.gd")
const COUNT := 70
## The field round the islands' slots, and the band of heights clouds sit
## in (metres).
const MARGIN := 400.0
const BAND := Vector2(-35.0,95.0)
## Clouds keep this far (plate plane) from every island's middle.
const CLEAR := 90.0
## A cloud's size (metres) and how many puffs it heaps up from.
const SIZE := Vector2(16.0,42.0)
const PUFFS := Vector2i(9,18)
const DRIFT := Vector2(0.6,0.3)
const FOLLOW := 0.15

## Each cloud: Vector4(x, y, z, size) at motion time 0, before `shift`.
var clouds := PackedVector4Array()
var field := Vector4.ZERO
var _home_field := Vector4.ZERO
var shift := Vector3.ZERO
var _puffs: MultiMeshInstance3D
var _material: ShaderMaterial

func build(slots: Array) -> void:
	name = "SkyClouds"
	var lo := Vector2(INF,INF)
	var hi := Vector2(-INF,-INF)
	for s: Vector3 in slots:
		lo = lo.min(Vector2(s.x,s.z))
		hi = hi.max(Vector2(s.x,s.z))
	lo -= Vector2.ONE*MARGIN
	hi += Vector2.ONE*MARGIN
	field = Vector4(lo.x,lo.y,hi.x-lo.x,hi.y-lo.y)
	_home_field = field
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	clouds = PackedVector4Array()
	var tries := 0
	while clouds.size() < COUNT and tries < COUNT*40:
		tries += 1
		var at := Vector3(rng.randf_range(lo.x,hi.x),rng.randf_range(BAND.x,BAND.y),rng.randf_range(lo.y,hi.y))
		var clear := true
		for s: Vector3 in slots:
			if Vector2(at.x,at.z).distance_to(Vector2(s.x,s.z)) < CLEAR: clear = false
		# Nor on a mountain risen through the sea (its cloud is at its foot),
		# nor in a forested isle's trees.
		if SkyPeaks.blocks(at): clear = false
		if SkyForestIsles.blocks(at,40.0): clear = false
		if clear: clouds.append(Vector4(at.x,at.y,at.z,rng.randf_range(SIZE.x,SIZE.y)))
	_build_puffs(rng)

func _build_puffs(rng: RandomNumberGenerator) -> void:
	var transforms := []
	var custom := []
	for cloud in clouds:
		var count := rng.randi_range(PUFFS.x,PUFFS.y)
		for i in range(count):
			# A flattened heap: wide, flat underneath, rounded on top.
			var a := rng.randf()*TAU
			var r := sqrt(rng.randf())
			var offset := Vector3(cos(a)*r*1.0,absf(rng.randfn(0.0,0.3))-0.08,sin(a)*r*0.7)
			var radius := cloud.w*rng.randf_range(0.32,0.6)*(1.0-0.35*r)
			var basis := Basis(Vector3.RIGHT*radius,Vector3.UP*cloud.w,Vector3.BACK)
			transforms.append(Transform3D(basis,Vector3(cloud.x,cloud.y,cloud.z)+offset*cloud.w))
			custom.append(Color(offset.x,offset.y,offset.z,rng.randf()))
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = quad
	multimesh.instance_count = transforms.size()
	for i in range(transforms.size()):
		multimesh.set_instance_transform(i,transforms[i])
		multimesh.set_instance_custom_data(i,custom[i])
	_material = ShaderMaterial.new()
	_material.shader = preload("res://shaders/sky_cloud_puff.gdshader")
	_material.set_shader_parameter("drift",DRIFT)
	_material.set_shader_parameter("field",field)
	_material.set_shader_parameter("shift",shift)
	if _puffs != null: _puffs.queue_free()
	_puffs = MultiMeshInstance3D.new()
	_puffs.name = "Puffs"
	_puffs.multimesh = multimesh
	_puffs.material_override = _material
	_puffs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Placed and wrapped in the shader; never cull them.
	_puffs.custom_aabb = AABB(Vector3.ONE*-1e5,Vector3.ONE*2e5)
	add_child(_puffs)

func puff_count() -> int:
	return _puffs.multimesh.instance_count if _puffs != null else 0

## Drifting clouds thin away over these places (Vector4(x, z, 0, radius),
## global): the sky peaks' and forested isles' (`keep_spots`), up to four.
func keep_off(spots: Array) -> void:
	if _material == null: return
	var list := PackedVector4Array()
	for i in range(4): list.append(spots[i] if i < spots.size() else Vector4.ZERO)
	_material.set_shader_parameter("keep_out",list)

## Moves every cloud by `by` (an island swap) or back home (`reset`).
func move(by: Vector3) -> void:
	shift += by
	_material.set_shader_parameter("shift",shift)

func reset() -> void:
	shift = Vector3.ZERO
	field = _home_field
	_material.set_shader_parameter("shift",shift)
	_material.set_shader_parameter("field",field)

## Recentres the field on a global point once it strays FOLLOW from the
## middle.
func follow(point: Vector3) -> void:
	var at := Vector2(point.x-shift.x,point.z-shift.z)
	var middle := Vector2(field.x+field.z*0.5,field.y+field.w*0.5)
	if absf(at.x-middle.x) < field.z*FOLLOW and absf(at.y-middle.y) < field.w*FOLLOW: return
	field.x = at.x-field.z*0.5
	field.y = at.y-field.w*0.5
	_material.set_shader_parameter("field",field)

## A cloud's middle now, at `time` (the scene's motion time), as the shader
## places it.
func centre(index: int, time: float) -> Vector3:
	var cloud := clouds[index]
	var moved := Vector2(cloud.x,cloud.z)+DRIFT*time
	var corner := Vector2(field.x,field.y)
	var span := Vector2(field.z,field.w)
	var wrapped := corner+Vector2(fposmod(moved.x-corner.x,span.x),fposmod(moved.y-corner.y,span.y))
	return Vector3(wrapped.x,cloud.y,wrapped.y)+shift

## How deep a global point is in a cloud: 0 outside, 1 at a heart.
func inside(point: Vector3, time: float) -> float:
	var deepest := 0.0
	for i in range(clouds.size()):
		var size := clouds[i].w
		var d := point-centre(i,time)
		# The heap is wide and flat: squash the height before measuring.
		d.y *= 2.2
		d.z *= 1.3
		deepest = maxf(deepest,1.0-smoothstep(size*0.3,size*0.85,d.length()))
	return deepest
