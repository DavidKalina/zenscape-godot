extends Node3D
## Rings on the water round the pilot (scripts/wanderer_eye.gd): thin pale
## rings laid on the surface that spread out and thin away, never fading
## (nothing see-through), as a storybook draws a ripple. One rings each leg
## as a wading boot comes down (`ring`), a few more round the legs as he
## wades on (`trail`, every TRAIL m), a wide one with a splash going in or
## coming down in it; swimming, one is let go at his chest every WAKE m,
## and as each spreads slower (SPREAD) than he swims the string of them
## opens behind him into a V, the wake a duck leaves.
##
## One MultiMesh of POOL rings in the world's frame (top level; the oldest
## is reused when all are out), each ring's reach and width carried in its
## instance data and laid out by shaders/pilot_ripple.gdshader.

const SHADER := preload("res://shaders/pilot_ripple.gdshader")
const POOL := 64
## Segments round a ring (faceted, as everything solid is).
const SIDES := 28
## Seconds a ring spreads, about; metres a second it spreads (slower than a
## swim, so a wake opens into a V); its first width (m), thinning to none.
const LIFE := 1.5
const SPREAD := 0.45
const WIDTH := 0.05
## Metres between the rings a wade trails and a swim's wake lets go.
const TRAIL := 0.45
const WAKE := 0.28
## Over the water's top, against its chop.
const LIFT := 0.02

var _mesh: MultiMeshInstance3D
var _at := PackedVector3Array()
var _age := PackedFloat32Array()
var _life := PackedFloat32Array()
var _from := PackedFloat32Array()
var _spread := PackedFloat32Array()
var _width := PackedFloat32Array()
var _next := 0
## Metres since the last trail or wake ring, and where he was.
var _gone := 0.0
var _was := Vector3.INF
var _rng := RandomNumberGenerator.new()
## Rings out, for probes and tests.
var alive := 0

func _init() -> void:
	name = "Ripples"
	top_level = true
	_rng.randomize()
	var material := ShaderMaterial.new()
	material.shader = SHADER
	var ring := _ring()
	ring.surface_set_material(0,material)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = ring
	multimesh.instance_count = POOL
	_mesh = MultiMeshInstance3D.new()
	_mesh.multimesh = multimesh
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The rings are laid out in the shader: never culled by the unit ring's box.
	_mesh.custom_aabb = AABB(Vector3(-4.0,-1.0,-4.0),Vector3(8.0,2.0,8.0))
	add_child(_mesh)
	_at.resize(POOL)
	_age.resize(POOL)
	_life.resize(POOL)
	_from.resize(POOL)
	_spread.resize(POOL)
	_width.resize(POOL)
	for i in range(POOL):
		multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3.ZERO))
		multimesh.set_instance_custom_data(i,Color(0.0,0.0,0.0,0.0))
	set_process(false)

## A ring at `at` (on the water's top), from `from` m across its middle,
## `strength` 0 (a stir) to 1 (a splash) widening how far and long it goes.
func ring(at: Vector3, from := 0.12, strength := 0.3) -> void:
	var i := _next
	_next = (_next+1)%POOL
	_at[i] = at+Vector3.UP*LIFT
	_age[i] = 0.0
	_life[i] = LIFE*lerpf(0.7,1.3,strength)*_rng.randf_range(0.85,1.15)
	_from[i] = from
	_spread[i] = SPREAD*lerpf(0.8,1.6,strength)
	_width[i] = WIDTH*lerpf(0.8,1.8,strength)
	set_process(true)

## A splash going in or coming down: two rings, one inside the other.
func splash(at: Vector3, strength: float) -> void:
	ring(at,0.25,clampf(strength,0.3,1.0))
	ring(at,0.1,clampf(strength*0.6,0.1,0.7))

## Moving through the water at `at` (its top under him): a ring each
## TRAIL m wading (round the legs, `across` m), each WAKE m swimming (at
## the chest, ahead of the feet). Out of the water, call `dry`.
func trail(at: Vector3, swimming: bool, across := 0.2) -> void:
	if _was.is_finite(): _gone += Vector2(at.x-_was.x,at.z-_was.z).length()
	_was = at
	var every := WAKE if swimming else TRAIL
	if _gone < every: return
	_gone = fmod(_gone,every)
	ring(at,across,0.45 if swimming else 0.3)

## Out of the water: the next trail starts afresh.
func dry() -> void:
	_was = Vector3.INF
	_gone = 0.0

func _process(delta: float) -> void:
	var multimesh := _mesh.multimesh
	alive = 0
	for i in range(POOL):
		if _life[i] <= 0.0: continue
		_age[i] += delta
		var u := _age[i]/_life[i]
		if u >= 1.0:
			_life[i] = 0.0
			multimesh.set_instance_custom_data(i,Color(0.0,0.0,0.0,0.0))
			continue
		alive += 1
		# Spreading, slowing as it goes, and thinning away to nothing.
		var reach := _from[i]+_spread[i]*_life[i]*(1.0-pow(1.0-u,1.6))/1.6
		var width := _width[i]*pow(1.0-u,1.3)
		multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,_at[i]))
		multimesh.set_instance_custom_data(i,Color(reach,width,u,1.0))
	if alive == 0: set_process(false)

## A ring of SIDES faceted segments: each vertex on the unit circle (x, z),
## UV.x 0 on the inner edge, 1 on the outer; the shader sets its reach and
## width.
static func _ring() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for k in range(SIDES):
		var a := Vector3(cos(TAU*k/SIDES),0.0,sin(TAU*k/SIDES))
		var b := Vector3(cos(TAU*(k+1)/SIDES),0.0,sin(TAU*(k+1)/SIDES))
		for corner: Array in [[a,0.0],[b,1.0],[a,1.0],[a,0.0],[b,0.0],[b,1.0]]:
			st.set_uv(Vector2(corner[1],0.0))
			st.add_vertex(corner[0])
	return st.commit()
