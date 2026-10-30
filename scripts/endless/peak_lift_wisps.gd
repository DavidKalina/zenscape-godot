## The lift's tell (docs/design/endless-flight/spec-crown.md): soft pale wisps of
## blown snow going up the rock gorge inside the tube (PeakRoutes), so the rising
## air is seen just before it is felt, and which way it runs. They keep below the
## gorge's rim (RIM_UNDER) and show only near the eye (FAR), so nothing is drawn
## against the open sky. One batched draw, moved in the shader, no colliders. It
## goes with the lift (`--lift=0`).
extends MultiMeshInstance3D

const PeakRoutes = preload("res://scripts/endless/peak_routes.gd")

## Streaks per m of the lift's path; none past MOST.
const PER_M := 0.32
const MOST := 900
## A streak's size (m): width, then its length's least and most.
const SIZE := Vector3(0.7,6.0,12.0)
## How far from the path's middle they keep, of the tube's radius, across and up.
const SPREAD := Vector2(0.72,0.45)
## How far (m) a streak runs before it comes round, and the most it may be seen from.
const RUN := 40.0
const FAR := 200.0
## The top of a streak's whole run stays this far under the lower of the path's two
## rims; a streak the rim leaves no room for, past the top of the walls, is dropped.
const RIM_UNDER := 25.0
const TOP_OVER := 24.0
## How far out each side (m) the rim is looked for, and in how many steps.
const RIM_REACH := 240.0
const RIM_STEPS := 8
## Floor to path, the least over the floor a streak may stand, and how far under
## the path they keep (m): at the plane's height, against the walls, not the sky.
const PATH_OVER := 40.0
const LEAST_OVER := 10.0
const UNDER_PATH := 12.0

## The lower of the two rims beside each point of the path (world y): the highest
## ground out to RIM_REACH on each side.
static func rims(points: PackedVector3Array, height: Callable) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(points.size())
	for i in points.size():
		var o := points[mini(i+1,points.size()-1)]-points[maxi(i-1,0)]
		var n := Vector2(-o.z,o.x).normalized()
		var low := INF
		for sg: float in [-1.0,1.0]:
			var top := -INF
			for k in range(1,RIM_STEPS+1):
				var w := Vector2(points[i].x,points[i].z)+n*sg*RIM_REACH*k/RIM_STEPS
				top = maxf(top,float(height.call(w.x,w.y)))
			low = minf(low,top)
		out[i] = low
	return out

## `points`, `radius`: the lift's path and tube. `height`: world y at (x, z).
func setup(points: PackedVector3Array, radius: float, seed_value: int, height: Callable) -> void:
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
	var rim := rims(points,height)
	var used := 0
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
		var off := Vector2.from_angle(rng.randf()*TAU)*sqrt(rng.randf())*radius
		at += Vector3(off.x*SPREAD.x,off.y*SPREAD.y-UNDER_PATH,off.y*SPREAD.y*0.5)
		var long := rng.randf_range(SIZE.y,SIZE.z)
		var phase := rng.randf()
		var path_y := lerpf(points[i].y,points[i+1].y,s/maxf(points[i].distance_to(points[i+1]),0.01))
		at.y = minf(at.y,lerpf(rim[i],rim[i+1],s/maxf(points[i].distance_to(points[i+1]),0.01))-RIM_UNDER-TOP_OVER)
		if at.y < path_y-PATH_OVER+LEAST_OVER: continue
		var b := Basis(Vector3.RIGHT*SIZE.x,Vector3.UP*long,Vector3.BACK)
		mm.set_instance_transform(used,Transform3D(b,at))
		mm.set_instance_custom_data(used,Color(way.x,way.y,way.z,phase))
		used += 1
		box = box.expand(at)
	mm.visible_instance_count = used
	multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/peak_lift_wisps.gdshader")
	mat.set_shader_parameter("run",RUN)
	mat.set_shader_parameter("far",FAR)
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(box.position-Vector3.ONE*RUN,box.size+Vector3.ONE*RUN*2.0)
