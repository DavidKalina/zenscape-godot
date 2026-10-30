## The lift's tell (docs/design/endless-flight/spec-crown.md): pale streaks of
## blown snow going up the rock gorge inside the tube (PeakRoutes), so the rising
## air is seen from the gorge's mouth before it is felt, and which way it runs.
## One batched draw, moved in the shader, no colliders. It goes with the lift
## (`--lift=0`).
extends MultiMeshInstance3D

const PeakRoutes = preload("res://scripts/endless/peak_routes.gd")

## Streaks per m of the lift's path; none past MOST.
const PER_M := 0.32
const MOST := 900
## A streak's size (m): width, then its length's least and most.
const SIZE := Vector3(0.55,7.0,16.0)
## How far from the path's middle they keep, of the tube's radius.
const SPREAD := 0.72
## How far (m) a streak runs before it comes round, and the most it may be seen from.
const RUN := 60.0
const FAR := 1500.0

## `points`, `radius`: the lift's path and tube.
func setup(points: PackedVector3Array, radius: float, seed_value: int) -> void:
	var length := 0.0
	for i in points.size()-1: length += points[i].distance_to(points[i+1])
	var n := mini(int(length*PER_M),MOST)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.center_offset = Vector3(0.0,0.5,0.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = n
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value,"lift-wisps"])
	var box := AABB(points[0],Vector3.ZERO)
	for k in n:
		var s := rng.randf()*length
		var i := 0
		while i < points.size()-2 and s > points[i].distance_to(points[i+1]):
			s -= points[i].distance_to(points[i+1])
			i += 1
		var p0 := points[i]
		var p1 := points[i+1]
		var way := (p1-p0).normalized()
		var at := p0+way*s
		var off := Vector2.from_angle(rng.randf()*TAU)*sqrt(rng.randf())*radius*SPREAD
		at += Vector3(off.x,off.y*0.8,off.y*0.3)
		var long := rng.randf_range(SIZE.y,SIZE.z)
		var b := Basis(Vector3.RIGHT*SIZE.x,Vector3.UP*long,Vector3.BACK)
		mm.set_instance_transform(k,Transform3D(b,at))
		mm.set_instance_custom_data(k,Color(way.x,way.y,way.z,rng.randf()))
		box = box.expand(at)
	multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/peak_lift_wisps.gdshader")
	mat.set_shader_parameter("run",RUN)
	mat.set_shader_parameter("far",FAR)
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(box.position-Vector3.ONE*RUN,box.size+Vector3.ONE*RUN*2.0)
