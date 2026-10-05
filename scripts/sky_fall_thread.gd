extends RefCounted
## A floating island's fall carried on down to the cloud sea: one soft thread
## from the lip all the way to the "ground", so a fall never seems to stop
## in mid-air (2026-10-05: "the waterfalls don't stretch all the way down
## ... we need some artistic direction to show that they do").
##
## It is not a kilometre of hard sheet. The near fall stays the waterfalls'
## glassy strand (shaders/flow_fall.gdshader, as scripts/sky_islets.gd
## `curtain` lays it); this thread fades in where that strand breaks up
## (`from`, metres under the lip) and carries on along the same arc:
## - first as running white strands, thin as the strand it takes over from;
## - fraying as it falls into a wider, softer veil of spray whose streaks
##   stretch longer and run slower the lower they are, never thinning out
##   to nothing on the way down;
## - leaning downwind and swaying on the breeze, more the lower it is
##   (zs_wind_direction, zs_breeze), so it reads as light spray;
## - melting into a soft, faintly glowing bloom of mist where it meets the
##   sea, a few puffs that billow up out of it, so from above you see where
##   it lands. The haze (shaders/glide_haze.gdshaderinc) takes it with the
##   distance and the thicker air low down, as it takes the islets.
##
## The whole of it is one mesh and one draw (shaders/sky_fall_thread.
## gdshader): the ribbon's rows, turned to the eye about the fall's line in
## the shader, and the bloom's puffs, billboards. `plan` is plain data (a
## worker may make it); `node_from` stands it up, `build` does both.
## A seed always makes the same thread.

## The cloud sea's top in the home frame (scripts/sky_flight.gd SEA_Y; not
## preloaded, since the haze it preloads preloads the islets that use this).
const SEA := -105.0
## The ribbon's rows, from where it takes over down to the sea, laid closer
## near the top (spacing ROW_POW) where the arc bends; the most metres
## between two rows is MAX_STEP (a test holds it to that).
const ROWS := 30
const ROW_POW := 1.35
const MAX_STEP := 9.0
## It runs this far into the sea's top (m), so it never ends above it.
const DIP := 6.0
## Fades in over FADE_IN m above `from`, and FADE_OVER m below it, the
## strand breaking up over the same stretch.
const FADE_IN := 6.0
const FADE_OVER := 5.0
## Its opacity: the strands at the top, the veil's floor all the way down,
## and the metres over the sea where it melts into the bloom.
const TOP_ALPHA := 0.92
const VEIL_ALPHA := 0.42
const MELT := 10.0
## Its half width, `d` m under the lip: `width` spread by SPREAD.x a metre,
## plus SPREAD.y m a metre (a 150 m fall ends a few metres wide).
const SPREAD := Vector2(0.01,0.022)
## How far down (share of what it falls past `from`) it has frayed from
## strands into the veil.
const FRAY := 0.45
## The bloom: PUFFS billowing puffs and one steady glow under them; their
## radius (m, before the fall's scale) and how far a puff drifts (m).
const PUFFS := 7
const PUFF_RADIUS := Vector2(4.0,9.0)
const PUFF_RISE := Vector2(5.0,16.0)
const PUFF_LIFE := Vector2(9.0,15.0)
const DRIFT_MAX := 24.0
const GLOW_RADIUS := 2.4
## How far it leans downwind at the sea, as a share of the drop, on a full
## breeze (the shader's `lean`).
const LEAN := 0.07
## Gravity (m/s²), for the arc off the lip (as SkyIslets `curtain`).
const G := 9.81

## The thread's plain data, in the frame `lip` is given in: off `lip`
## along `out` (flat, unit), `width` its half width at the lip (m), down to
## the sea at height `sea_y`; taking over `from` m under the lip; thrown
## `throw` m/s off the lip and kept `clear` m out from it at least.
## Returns {arrays (Mesh arrays), bounds (AABB), drop (m, lip to the bottom
## row), rows (the ribbon's row count), points, halves, alphas (per row),
## foot (Vector3), puffs (count, with the glow), seed}.
static func plan(lip: Vector3, out: Vector3, width: float, sea_y: float, seed_value: int, from := 0.0, throw := 1.4, clear := 0.0) -> Dictionary:
	out = Vector3(out.x,0.0,out.z).normalized()
	if out == Vector3.ZERO: out = Vector3.RIGHT
	var across := out.cross(Vector3.UP).normalized()
	var total := maxf(lip.y-(sea_y-DIP),from+1.0)
	from = clampf(from,0.0,total-1.0)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var indices := PackedInt32Array()
	var points := PackedVector3Array()
	var halves := PackedFloat32Array()
	var alphas := PackedFloat32Array()
	# The rows: from FADE_IN over `from` down to the bottom, closer at the
	# top; more rows if a long fall would leave too long a step.
	var start := maxf(from-FADE_IN,0.0)
	var rows := maxi(ROWS,ceili((total-start)*ROW_POW/MAX_STEP)+1)
	var travel := 0.0
	var last := point(lip,out,start,throw,clear)
	var low := Vector3(INF,INF,INF)
	var high := -low
	var widest := 0.0
	for r in range(rows+1):
		var d := lerpf(start,total,pow(float(r)/rows,ROW_POW))
		var at := point(lip,out,d,throw,clear)
		var tangent := (point(lip,out,d+0.5,throw,clear)-point(lip,out,maxf(d-0.5,0.0),throw,clear)).normalized()
		travel += at.distance_to(last)
		last = at
		var half := half_at(width,d)
		var alpha := alpha_at(d,from,lip.y,sea_y)
		var fray := smoothstep(from,from+FRAY*(total-from),d)
		var share := d/total
		points.append(at)
		halves.append(half)
		alphas.append(alpha)
		for side in [-1.0,1.0]:
			vertices.append(at)
			normals.append(tangent)
			colours.append(Color(fray,0.0,0.0,alpha))
			uv.append(Vector2(side,travel))
			uv2.append(Vector2(half,share))
		if r > 0:
			var k := r*2
			indices.append_array([k-2,k-1,k,k-1,k+1,k])
		low = low.min(at)
		high = high.max(at)
		widest = maxf(widest,half)
	# The bloom where it meets the sea: one steady glow, and puffs billowing
	# up and out of it on their own beats.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value*31+7
	var foot := point(lip,out,lip.y-sea_y,throw,clear)
	var foot_half := half_at(width,lip.y-sea_y)
	var scale := clampf(sqrt((lip.y-sea_y)/120.0),0.6,1.4)
	var glow_r := foot_half*GLOW_RADIUS+6.0*scale
	var reach := glow_r
	_puff(vertices,normals,colours,uv,uv2,indices,foot+Vector3.UP*1.5,Vector3.UP,glow_r,0.0,Color(0.0,rng.randf(),0.0,1.0))
	for k in range(PUFFS):
		var at := foot+across*rng.randf_range(-1.0,1.0)*foot_half*1.1+out*rng.randf_range(-0.6,0.9)*foot_half+Vector3.UP*rng.randf_range(-2.0,3.0)
		var drift := Vector3.UP*rng.randf_range(PUFF_RISE.x,PUFF_RISE.y)*scale+across*rng.randf_range(-4.0,4.0)*scale+out*rng.randf_range(0.0,4.0)*scale
		var radius := rng.randf_range(PUFF_RADIUS.x,PUFF_RADIUS.y)*scale
		var life := rng.randf_range(PUFF_LIFE.x,PUFF_LIFE.y)
		_puff(vertices,normals,colours,uv,uv2,indices,at,drift.normalized(),radius,life,Color(rng.randf(),rng.randf(),minf(drift.length()/DRIFT_MAX,1.0),rng.randf_range(0.75,1.0)))
		reach = maxf(reach,at.distance_to(foot)+drift.length()+radius*1.45)
	low = low.min(foot-Vector3.ONE*reach)
	high = high.max(foot+Vector3.ONE*reach)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_INDEX] = indices
	# Room for the lean and sway on the wind (the shader's), all round.
	var swing := LEAN*2.0*total+6.0
	return {"arrays":arrays,"bounds":AABB(low,high-low).grow(widest+swing),"drop":total,"rows":rows+1,
		"points":points,"halves":halves,"alphas":alphas,"foot":foot,"foot_travel":travel,"puffs":PUFFS+1,
		"across":across,"seed":seed_value,"from":from}

## The thread stood up as one MeshInstance3D (its shader's material set),
## in the frame `lip` is given in: add it under the island's node. The
## arguments are `plan`'s.
static func build(lip: Vector3, out: Vector3, width: float, sea_y: float, seed_value: int, from := 0.0, throw := 1.4, clear := 0.0) -> MeshInstance3D:
	return node_from(plan(lip,out,width,sea_y,seed_value,from,throw,clear))

## A planned thread (`plan`, perhaps made on a worker) as its node.
static func node_from(p: Dictionary) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,p.arrays)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/sky_fall_thread.gdshader")
	# Behind the strand where they overlap (FlowFalls CURTAIN_PRIORITY -1).
	material.render_priority = -2
	material.set_shader_parameter("seed",float(int(p.seed) % 997)*0.37+1.0)
	material.set_shader_parameter("drop",float(p.drop))
	material.set_shader_parameter("lean",LEAN)
	material.set_shader_parameter("across_axis",p.across)
	material.set_shader_parameter("foot_travel",float(p.foot_travel))
	material.set_shader_parameter("drift_max",DRIFT_MAX)
	var thread := MeshInstance3D.new()
	thread.name = "FallThread"
	thread.mesh = mesh
	thread.material_override = material
	thread.custom_aabb = p.bounds
	thread.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	thread.set_meta("skip_reflection",true)
	return thread

## The fall's line `d` m under `lip`: thrown `throw` m/s off it along
## `out`, never nearer than `clear` (as SkyIslets `curtain` lays its rings).
static func point(lip: Vector3, out: Vector3, d: float, throw: float, clear: float) -> Vector3:
	var away := maxf(throw*sqrt(2.0*maxf(d,0.0)/G),clear)
	return lip+out*away+Vector3.DOWN*d

## Its half width (m) `d` m under the lip.
static func half_at(width: float, d: float) -> float:
	return width*(1.0+d*SPREAD.x)+d*SPREAD.y

## Its opacity `d` m under a lip at height `lip_y`: in over the strand's
## break round `from`, the strands' TOP_ALPHA easing to the veil's floor
## (never lower on the way), melting into the bloom over the last MELT m
## above the sea and gone DIP m into it.
static func alpha_at(d: float, from: float, lip_y: float, sea_y: float) -> float:
	var total := lip_y-(sea_y-DIP)
	var fade_in := smoothstep(from-FADE_IN,from+FADE_OVER,d) if from > 0.0 else 1.0
	var veil := lerpf(TOP_ALPHA,VEIL_ALPHA,smoothstep(from,from+0.7*maxf(total-from,1.0),d))
	var y := lip_y-d
	var melt := smoothstep(sea_y-DIP,sea_y+MELT,y)
	return fade_in*veil*melt

static func _puff(vertices: PackedVector3Array, normals: PackedVector3Array, colours: PackedColorArray, uv: PackedVector2Array, uv2: PackedVector2Array, indices: PackedInt32Array, at: Vector3, way: Vector3, radius: float, life: float, data: Color) -> void:
	var k := vertices.size()
	for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
		vertices.append(at)
		normals.append(way)
		colours.append(data)
		uv.append(corner)
		uv2.append(Vector2(-radius,life))
	indices.append_array([k,k+1,k+2,k+1,k+3,k+2])
