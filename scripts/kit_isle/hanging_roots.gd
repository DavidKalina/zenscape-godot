extends RefCounted
## Hanging roots, a kit piece any motif can hang (first used by the
## Haul-Way's relay pier and its shores' lips, scripts/kit_isle/greybox/
## gb_haulway.gd): dry dark strands down from under turf lips, from a
## pier's courses and its capital, into the haze. One strand mesh (a metre
## long, faceted, tapering to a thread, with a fork off its middle) placed
## many times in one MultiMesh, so a motif only lists where they hang. The
## vertex shader gives each instance its own wander, kinks, fork (or none)
## and a slow sway, from the instance's custom data. Drawn only, never
## collided; no shadows; faded out past `FAR`.
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
## Share of strands that fork.
const FORKED := 0.45
## Faded out past this (m).
const FAR := 140.0
## The strand mesh: rings down and sides round.
const RINGS := 8
const SIDES := 5
## The fork: leaves the strand at this fraction of its length, in rings.
const FORK_AT := 0.35
const FORK_RINGS := 4
const FORK_SPAN := 0.4

const SHADER := """
shader_type spatial;
render_mode cull_back;
uniform float sway_speed = 0.8;
float tri(float x) { return abs(fract(x) * 2.0 - 1.0); }
void vertex() {
	float t = -VERTEX.y;
	float len = length(MODEL_MATRIX[1].xyz);
	vec4 c = INSTANCE_CUSTOM; // phase, thickness, shape, fork
	float ph = c.x * 6.2831;
	float amp = min(0.06 * len + 0.12, 2.2);
	vec2 wander = vec2(sin(t * 2.6 + ph), sin(t * 2.1 + ph * 1.7 + 1.3)) * 0.8;
	vec2 kink = vec2(tri(t * 2.3 + c.z) - 0.5, tri(t * 1.7 + c.z * 3.1 + 0.4) - 0.5) * 1.6;
	vec2 off = (wander + kink) * amp * t;
	vec2 sway = vec2(sin(TIME * sway_speed + ph + t * 2.0), cos(TIME * sway_speed * 0.8 + ph * 1.3 + t * 1.6));
	off += sway * min(0.025 * len, 0.5) * t * t;
	float ring_scale = c.y;
	if (UV.x > 0.5) {
		float a = c.z * 6.2831;
		off += vec2(cos(a), sin(a)) * (t - FORK_AT) * len * 0.3;
		if (c.w < 0.5) ring_scale = 0.0;
	}
	VERTEX.xz = VERTEX.xz * ring_scale + off;
}
void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.95;
}
"""

## A strand's triangles.
static func triangles() -> int:
	return (RINGS+FORK_RINGS)*SIDES*2

static var _mesh: ArrayMesh = null
static var _material: ShaderMaterial = null

## The mesh and material (on the main thread, before any batch).
static func warm() -> void:
	if _material == null:
		var sh := Shader.new()
		sh.code = SHADER.replace("FORK_AT",str(FORK_AT))
		_material = ShaderMaterial.new()
		_material.shader = sh
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
	mm.use_custom_data = true
	mm.mesh = _mesh
	mm.instance_count = roots.size()
	for i in roots.size():
		var r: Vector4 = roots[i]
		var thick := rng.randf_range(THICK.x,THICK.y)*clampf(r.w/8.0,0.45,1.3)
		mm.set_instance_color(i,Color.WHITE*rng.randf_range(0.7,1.1))
		# Phase, thickness (m), shape, forked.
		mm.set_instance_custom_data(i,Color(rng.randf(),thick,rng.randf(),1.0 if rng.randf() < FORKED else 0.0))
		mm.set_instance_transform(i,Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3(1.0,r.w,1.0)),Vector3(r.x,r.y,r.z)))
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

## The strand: one metre down from its top, straight (the shader bends it),
## tapering to a thread, with a fork off its middle (UV.x 1), faceted, darker
## at the top. Ring radii are unit; the shader scales them by the thickness.
static func _make() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = []
	for k in RINGS+1:
		var t := float(k)/RINGS
		rings.append([t,0.5*pow(1.0-t,0.9)+0.04,0.0])
	_tube(st,rings,0.0)
	var fork: Array = []
	for k in FORK_RINGS+1:
		var u := float(k)/FORK_RINGS
		fork.append([FORK_AT+FORK_SPAN*u,0.26*(1.0-u)+0.03,0.0])
	_tube(st,fork,1.0)
	st.generate_normals()
	var m := st.commit()
	# The shader wanders it out to a few metres.
	m.custom_aabb = AABB(Vector3(-6.0,-1.1,-6.0),Vector3(12.0,1.2,12.0))
	return m

## A tube through rings of [t down, radius, _]; `flag` goes in UV.x.
static func _tube(st: SurfaceTool, rings: Array, flag: float) -> void:
	var rows: Array = []
	for r: Array in rings:
		var ring: Array = []
		for s in SIDES: ring.append(Vector3(cos(TAU*s/SIDES)*r[1],-r[0],sin(TAU*s/SIDES)*r[1]))
		rows.append(ring)
	for k in rings.size()-1:
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
				st.set_uv(Vector2(flag,0.0))
				st.add_vertex(v)
