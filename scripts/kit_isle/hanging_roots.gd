extends RefCounted
## Hanging roots, a kit piece any motif can hang (first used by the
## Haul-Way's relay pier and its shores' lips, scripts/kit_isle/greybox/
## gb_haulway.gd): dry dark strands down from under turf lips, from a
## pier's courses and its capital, into the haze. One strand mesh (a metre
## long, faceted, tapering to a thread, wandering out and back as it
## hangs, the sky forest isles' `_make_root` in bark rather than the
## sky's palette) placed many times in one MultiMesh, so a motif only
## lists where they hang. Drawn only, never collided; no shadows; faded
## out past `FAR`.
##
##   HangingRoots.warm()                         main thread (a motif's warm)
##   HangingRoots.batch(roots, seed)             roots: Array of Vector4
##                                               (x, y top, z, length m)
##   HangingRoots.along(points, y_of, apart, long, out, seed)
##                                               roots every ~`apart` m
##                                               along a polyline

## Bark: dark, dry, a little warm (the Face's roots' tone).
const BARK := Color("44352a")
const BARK_TIP := Color("5b4a3a")
## A strand's thickness at its top (m), short to long.
const THICK := Vector2(0.1,0.3)
## Faded out past this (m).
const FAR := 140.0
## The strand mesh: rings down and sides round.
const RINGS := 5
const SIDES := 5

## A strand's triangles.
static func triangles() -> int:
	return RINGS*SIDES*2

static var _mesh: ArrayMesh = null
static var _material: StandardMaterial3D = null

## The mesh and material (on the main thread, before any batch).
static func warm() -> void:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.roughness = 0.95
		_material.albedo_color = Color.WHITE
	if _mesh == null: _mesh = _make()

## One MultiMeshInstance3D of every root in `roots` (Vector4: x, the y it
## hangs from, z, length), each turned and thickened by `seed`'s draw.
static func batch(roots: Array, seed_value: int) -> MultiMeshInstance3D:
	warm()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _mesh
	mm.instance_count = roots.size()
	for i in roots.size():
		var r: Vector4 = roots[i]
		var thick := rng.randf_range(THICK.x,THICK.y)*clampf(r.w/8.0,0.45,1.3)
		var b := Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3(thick,r.w,thick))
		mm.set_instance_transform(i,Transform3D(b,Vector3(r.x,r.y,r.z)))
		mm.set_instance_color(i,Color.WHITE*rng.randf_range(0.7,1.1))
	var out := MultiMeshInstance3D.new()
	out.name = "Roots"
	out.multimesh = mm
	out.material_override = _material
	out.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	out.visibility_range_end = FAR
	out.visibility_range_end_margin = 20.0
	return out

## Roots along a polyline (x, z points): about every `apart` m, `out` m
## outward of it (+ to its right as walked), hanging from `y_of(x, z)`
## less a little, `long` (min, max) m long.
static func along(points: Array, y_of: Callable, apart: float, long: Vector2, out: float, seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var roots: Array = []
	for k in points.size()-1:
		var a: Vector2 = points[k]
		var b: Vector2 = points[k+1]
		var d := a.distance_to(b)
		if d < 0.01: continue
		var way := (b-a)/d
		var right := Vector2(-way.y,way.x)
		var t := rng.randf_range(0.0,apart)
		while t < d:
			var p := a+way*t+right*out*rng.randf_range(0.6,1.2)
			var y := float(y_of.call(p.x,p.y))
			if is_finite(y):
				var l := rng.randf_range(long.x,long.y)*(1.0 if rng.randf() < 0.7 else 0.5)
				roots.append(Vector4(p.x,y-rng.randf_range(0.2,0.6),p.y,l))
				# Now and then a clump of two or three.
				if rng.randf() < 0.35:
					for c in rng.randi_range(1,2):
						var q := p+Vector2(rng.randf_range(-0.6,0.6),rng.randf_range(-0.6,0.6))
						roots.append(Vector4(q.x,y-rng.randf_range(0.2,0.8),q.y,l*rng.randf_range(0.4,0.9)))
			t += apart*rng.randf_range(0.5,1.5)
	return roots

## The strand: one metre down from its top, a unit thick there, tapering to
## a thread, wandering out (+z) and back, faceted, darker at the top.
static func _make() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows: Array = []
	for k in RINGS+1:
		var t := float(k)/RINGS
		var middle := Vector3(0.06*sin(t*5.0),-t,0.2*sin(t*PI*0.8)+0.05*sin(t*7.0))
		var r := 0.5*pow(1.0-t,1.3)+0.04
		var ring: Array = []
		for s in SIDES: ring.append(middle+Vector3(cos(TAU*s/SIDES)*r,0.0,sin(TAU*s/SIDES)*r))
		rows.append(ring)
	for k in RINGS:
		var tone := BARK.srgb_to_linear().lerp(BARK_TIP.srgb_to_linear(),float(k)/RINGS)
		for s in SIDES:
			var a: Vector3 = rows[k][s]
			var b: Vector3 = rows[k][(s+1)%SIDES]
			var c: Vector3 = rows[k+1][(s+1)%SIDES]
			var d: Vector3 = rows[k+1][s]
			var shade := tone*(0.85+0.15*float((k+s)%2))
			shade.a = 1.0
			for v: Vector3 in [a,c,b,a,d,c]:
				st.set_color(shade)
				st.add_vertex(v)
	st.generate_normals()
	return st.commit()
