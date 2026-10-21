extends Node3D
## Clouds in the open air between the sky islands (scripts/sky_islands.gd),
## for the glide to fly past and through. Before these, the only clouds were
## the sky box's, which never come nearer.
##
## Each cloud is a heap of soft puffs, flat underneath and rounded on top
## (shaders/sky_cloud_puff.gdshader). They drift on the breeze and wrap
## round the field a whole cloud at a time. They keep clear of the islands,
## so they never hide a place, and are not set on a mountain range risen
## through the sea (scripts/sky_peaks.gd), whose cloud hugs its foot, nor
## in a towering cumulus (scripts/sky_towers.gd), and never show through
## one (`screen`): it draws first, so the puffs fade where it stands
## between them and the eye. `inside` says how deep a point is in a cloud,
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
const SkyTowers = preload("res://scripts/sky_towers.gd")
const SkyForestIsles = preload("res://scripts/sky_forest_isles.gd")
const SkyWorld = preload("res://scripts/sky_world.gd")
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
## The breeze they ride (m/s, x then z; DRIFT unless a sky blows them,
## `blow`) and how far that has put them off DRIFT's track (m), so a
## change of breeze carries them on from where they stand.
var drift := DRIFT
var lead := Vector2.ZERO
var _puffs: MultiMeshInstance3D
var _material: ShaderMaterial

## Lays COUNT clouds over the field round `slots` (+MARGIN), CLEAR of each
## slot. `blocked` (a home point to true), given, says where else none may
## stand, in place of the open sky's peaks, towers and forested isles: a
## sky laid by hand (scripts/kit_isle/kit_clouds.gd) reads no layout.
func build(slots: Array, blocked := Callable()) -> void:
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
	rng.seed = SkyWorld.salted(23)
	clouds = PackedVector4Array()
	var tries := 0
	while clouds.size() < COUNT and tries < COUNT*40:
		tries += 1
		var at := Vector3(rng.randf_range(lo.x,hi.x),rng.randf_range(BAND.x,BAND.y),rng.randf_range(lo.y,hi.y))
		var clear := true
		for s: Vector3 in slots:
			if Vector2(at.x,at.z).distance_to(Vector2(s.x,s.z)) < CLEAR: clear = false
		# Nor on a mountain risen through the sea (its cloud is at its foot),
		# in a tower, nor in a forested isle's trees.
		if blocked.is_valid():
			if clear and blocked.call(at): clear = false
		else:
			if SkyPeaks.blocks(at) or SkyTowers.blocks(at,SIZE.y): clear = false
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

## The puffs ride `breeze` (m/s, x then z) from now (`time`, the scene's
## motion time) on, carried on from where they stand.
func blow(breeze: Vector2, time: float) -> void:
	if _material == null: return
	lead += (drift-breeze)*time
	drift = breeze
	_material.set_shader_parameter("drift",drift)
	_material.set_shader_parameter("lead",lead)

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

## The towers the puffs must not show through (SkyTowers `screens`), and
## how deep in one's fog the eye is (0 to 1): the puffs past it dim by that.
func screen(spots: Array, veiled := 0.0) -> void:
	var columns := PackedVector4Array()
	var spans := PackedVector2Array()
	for i in range(4):
		columns.append(spots[i][0] if i < spots.size() else Vector4.ZERO)
		spans.append(spots[i][1] if i < spots.size() else Vector2.ZERO)
	_material.set_shader_parameter("towers",columns)
	_material.set_shader_parameter("tower_spans",spans)
	_material.set_shader_parameter("veiled",veiled)

## The planes' tunnels (CloudWakes `at`, `way`), for the puffs to part
## along.
func wakes(at: PackedVector4Array, way: PackedVector4Array) -> void:
	if _material == null: return
	_material.set_shader_parameter("wake_at",at)
	_material.set_shader_parameter("wake_way",way)

## A cloud's middle now, at `time` (the scene's motion time), as the shader
## places it.
func centre(index: int, time: float) -> Vector3:
	var cloud := clouds[index]
	var moved := Vector2(cloud.x,cloud.z)+drift*time+lead
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
