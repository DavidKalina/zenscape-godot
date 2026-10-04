extends RefCounted
## The fallen log (asset "log", part "logs"), redesigned in the family's style:
## a faceted solid with soft living things on it (docs/scenic/grass-look.md).
##
## One unit-long mesh along local X (the records scale it: x is the length, y
## and z the girth, as the source log was), about 0.32 across, so its footprint,
## placement and the walkway/collision logic are those of the source log.
##
## - Bark: nine irregular facets round a gently tapering, bending trunk, ridged
##   by a jitter of radius per vertex and a lightness per face, in the source
##   log's bark brown, darker underneath where it lies on the ground.
## - Two broken branch stubs stand off the upper side, each with a pale cut end.
## - One end is sawn: an inset pale end-grain disc in three bands (light
##   sapwood, a darker ring, a light heart) behind a thin cambium rim. The other
##   is broken: a ragged edge, a recessed splintered face and a few splinters.
## - Moss: a soft ragged strip along the top plus two small patches on the
##   shoulders, raised a little over the bark, with dome-soft normals and a
##   colour that runs from a dark edge, blended into the bark, to a lit crest.
##   Two tiny tufts of grass stand in it.
##
## The material is the source log's with `flat_faces` off: bark triangles carry
## their own face normals (so they read faceted), moss and grass carry soft ones
## (so they take the light as the grass tuft does). No shader change.
const BARK := Color(0.1569, 0.1176, 0.0784)
## The stump's pale wood (the source's cut face).
const WOOD := Color(0.549, 0.4157, 0.2353)
const WOOD_RING := Color(0.40, 0.29, 0.16)
const CAMBIUM := Color(0.34, 0.25, 0.14)
## The source log's moss green at the crest, darker toward the edge.
const MOSS_CREST := Color(0.15, 0.33, 0.10)
const MOSS_EDGE := Color(0.085, 0.19, 0.065)
const BLADE_ROOT := Color(0.08, 0.19, 0.06)
const BLADE_TIP := Color(0.22, 0.43, 0.12)
const SIDES := 9
const RINGS := 7
const HALF := 0.5

static var _mesh: ArrayMesh

class Cloth extends RefCounted:
	var surface := SurfaceTool.new()
	var count := 0
	func _init() -> void:
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	func vertex(p: Vector3, n: Vector3, c: Color) -> void:
		surface.set_color(c)
		surface.set_uv(Vector2(0.5, 0.5))
		surface.set_uv2(Vector2.ZERO)
		surface.set_normal(n)
		surface.add_vertex(p)
	## A faceted triangle: its own face normal, turned to face `outward`.
	func facet(a: Vector3, b: Vector3, c: Vector3, outward: Vector3, ca: Color, cb: Color, cc: Color) -> void:
		var n := (b - a).cross(c - a)
		if n.length_squared() < 1.0e-12: return
		n = n.normalized()
		if n.dot(outward) < 0.0: n = -n
		vertex(a, n, ca)
		vertex(b, n, cb)
		vertex(c, n, cc)
		count += 1
	## A soft triangle: the caller's vertex normals.
	func soft(a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, ca: Color, cb: Color, cc: Color) -> void:
		vertex(a, na, ca)
		vertex(b, nb, cb)
		vertex(c, nc, cc)
		count += 1

## The redesigned log, built once.
static func log_mesh() -> ArrayMesh:
	if _mesh == null: _mesh = _build()
	return _mesh

## The baked log (`logs`) swaps to the new one, keeping the source material.
static func swap(node_name: String, original: Mesh) -> Mesh:
	if node_name != "logs": return original
	var mesh := log_mesh().duplicate() as ArrayMesh
	mesh.surface_set_material(0, original.surface_get_material(0))
	return mesh

## The material the new log wants: soft normals for the moss, bark faceted by
## its own per-face normals instead of the derivative ones.
static func dress(material: Material) -> void:
	var shader_material := material as ShaderMaterial
	if shader_material != null: shader_material.set_shader_parameter("flat_faces", false)

static func triangle_count(mesh: Mesh) -> int:
	var arrays := mesh.surface_get_arrays(0)
	var indices = arrays[Mesh.ARRAY_INDEX]
	if indices != null and indices.size() > 0: return indices.size() / 3
	return (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3

## Triangles that are moss or grass (soft normals), for tests.
static func soft_vertex_count(mesh: Mesh) -> int:
	var arrays := mesh.surface_get_arrays(0)
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var count := 0
	for c in colors:
		if c.g > c.r * 1.2 and c.g > c.b * 1.3: count += 1
	return count

# --- shape --------------------------------------------------------------

## The trunk's centre line: a slight bend.
static func _centre(x: float) -> Vector2:
	return Vector2(0.016 * sin(x * 3.1 + 0.6) + 0.006 * x, 0.014 * sin(x * 2.3 + 2.0))

## Radius: a butt to a slimmer top, swollen a little near the sawn end, with a
## slow lumpiness round and along the trunk.
static func _radius(x: float, theta: float) -> float:
	var t := (x + HALF) / (2.0 * HALF)
	var r := lerpf(0.158, 0.128, t) * (1.0 + 0.05 * exp(-pow((t - 0.04) / 0.1, 2.0)))
	return r * (1.0 + 0.05 * sin(3.0 * theta + 0.8 + 3.0 * x) + 0.03 * sin(5.0 * theta + 2.1 - 4.0 * x))

## A point on the bark at (x, theta), lifted by `lift`; theta is measured so
## that PI/2 is straight up.
static func _surface(x: float, theta: float, lift: float) -> Vector3:
	var c := _centre(x)
	var dir := Vector3(0.0, sin(theta), cos(theta))
	return Vector3(x, c.x, c.y) + dir * (_radius(x, theta) + lift)

static func _out(theta: float) -> Vector3:
	return Vector3(0.0, sin(theta), cos(theta))

static func _build() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6203
	var cloth := Cloth.new()
	# Irregular facet angles and a radius jitter per vertex, fixed per ring.
	var thetas: Array[float] = []
	for i in range(SIDES):
		thetas.append(TAU * i / SIDES + rng.randf_range(-0.14, 0.14))
	var pts: Array = []
	var xs: Array[float] = []
	for k in range(RINGS):
		var x := lerpf(-HALF, HALF, float(k) / (RINGS - 1))
		if k > 0 and k < RINGS - 1: x += rng.randf_range(-0.03, 0.03)
		xs.append(x)
		var ring: Array[Vector3] = []
		for i in range(SIDES):
			ring.append(_surface(x, thetas[i], rng.randf_range(-0.006, 0.004)))
		pts.append(ring)
	# The broken end's ring is ragged: each point pulled back by its own amount.
	var ragged: Array[float] = []
	for i in range(SIDES):
		var pull := rng.randf_range(0.02, 0.07) if i % 2 == 0 else rng.randf_range(0.0, 0.025)
		ragged.append(pull)
		var p: Vector3 = pts[RINGS - 1][i]
		p.x -= pull
		pts[RINGS - 1][i] = p
	# Bark body.
	for k in range(RINGS - 1):
		for i in range(SIDES):
			var j := (i + 1) % SIDES
			var a: Vector3 = pts[k][i]
			var b: Vector3 = pts[k][j]
			var c: Vector3 = pts[k + 1][i]
			var d: Vector3 = pts[k + 1][j]
			var mid := (a + b + c + d) * 0.25
			var around := Vector3(0.0, mid.y - _centre(mid.x).x, mid.z - _centre(mid.x).y)
			var shade := rng.randf_range(-0.16, 0.16)
			var below := clampf(-around.normalized().y * 1.3, 0.0, 1.0)
			var face_a := _bark(shade, below, rng)
			var face_b := _bark(shade + rng.randf_range(-0.05, 0.05), below, rng)
			cloth.facet(a, b, c, around, face_a, face_a, face_a)
			cloth.facet(b, d, c, around, face_b, face_b, face_b)
	_sawn_end(cloth, rng, thetas, pts[0], xs[0])
	_broken_end(cloth, rng, thetas, pts[RINGS - 1], ragged)
	_stub(cloth, rng, -0.14, 1.0, 0.032, 0.11)
	_stub(cloth, rng, 0.2, 2.15, 0.026, 0.085)
	# Moss: a ragged strip along the top, two small patches on the shoulders.
	_moss(cloth, rng, 0.0, HALF * 0.78, PI * 0.5, 0.78, 10, 4, 0.028, true)
	_moss(cloth, rng, -0.3, 0.1, PI * 0.5 + 1.15, 0.3, 3, 2, 0.02, false)
	_moss(cloth, rng, 0.3, 0.1, PI * 0.5 - 1.1, 0.3, 3, 2, 0.02, false)
	_tuft(cloth, rng, -0.1, PI * 0.5 + 0.1)
	_tuft(cloth, rng, 0.24, PI * 0.5 - 0.15)
	var mesh := cloth.surface.commit()
	return mesh

static func _bark(shade: float, below: float, rng: RandomNumberGenerator) -> Color:
	var c := BARK.lightened(shade) if shade >= 0.0 else BARK.darkened(-shade)
	c = c.darkened(below * 0.3)
	# Faint warm and cool shifts break up the brown a little.
	return Color(c.r * rng.randf_range(0.96, 1.05), c.g * rng.randf_range(0.97, 1.04), c.b * rng.randf_range(0.95, 1.06))

## The sawn end at x = -0.5: a thin cambium rim, then three bands of end grain.
static func _sawn_end(cloth: Cloth, rng: RandomNumberGenerator, thetas: Array[float], ring: Array, x: float) -> void:
	var inset := 0.007
	var centre := Vector3(x + inset * 1.8, _centre(x).x, _centre(x).y)
	var outward := Vector3.LEFT
	var bands: Array = []
	for scale in [0.92, 0.62, 0.3]:
		var band: Array[Vector3] = []
		for i in range(SIDES):
			var p: Vector3 = ring[i]
			var c := Vector3(x, _centre(x).x, _centre(x).y)
			var q: Vector3 = c + (p - c) * scale * rng.randf_range(0.95, 1.05)
			q.x = x + inset * (1.0 + (1.0 - scale) * 0.8)
			band.append(q)
		bands.append(band)
	var tones: Array[Color] = [WOOD, WOOD_RING, WOOD.lightened(0.04)]
	for i in range(SIDES):
		var j := (i + 1) % SIDES
		# Rim.
		var o0: Vector3 = ring[i]
		var o1: Vector3 = ring[j]
		var a0: Vector3 = bands[0][i]
		var a1: Vector3 = bands[0][j]
		cloth.facet(o0, o1, a0, outward, CAMBIUM, CAMBIUM, CAMBIUM)
		cloth.facet(o1, a1, a0, outward, CAMBIUM, CAMBIUM, CAMBIUM)
		# Outer band (light), ring band (dark), heart fan (light).
		var colour := tones[0].lightened(rng.randf_range(-0.04, 0.05))
		cloth.facet(a0, a1, bands[1][i], outward, colour, colour, colour)
		cloth.facet(a1, bands[1][j], bands[1][i], outward, colour, colour, colour)
		var dark := tones[1].lightened(rng.randf_range(-0.04, 0.04))
		cloth.facet(bands[1][i], bands[1][j], bands[2][i], outward, dark, dark, dark)
		cloth.facet(bands[1][j], bands[2][j], bands[2][i], outward, dark, dark, dark)
		var heart := tones[2].lightened(rng.randf_range(-0.03, 0.04))
		cloth.facet(bands[2][i], bands[2][j], centre, outward, heart, heart, heart)

## The broken end at x = +0.5: a recessed ragged face and a few splinters.
static func _broken_end(cloth: Cloth, rng: RandomNumberGenerator, thetas: Array[float], ring: Array, ragged: Array[float]) -> void:
	var x: float = ring[0].x
	var c := Vector3(0.0, _centre(HALF).x, _centre(HALF).y)
	var centre := Vector3(HALF - 0.085, c.y, c.z)
	var outward := Vector3.RIGHT
	for i in range(SIDES):
		var j := (i + 1) % SIDES
		var tone := WOOD.darkened(rng.randf_range(0.05, 0.22))
		cloth.facet(ring[i], ring[j], centre, outward, tone, tone, tone)
	# Splinters reach past the ragged edge toward the old end plane.
	for i in range(SIDES):
		if ragged[i] < 0.045: continue
		var j := (i + 1) % SIDES
		var base_a: Vector3 = ring[i]
		var base_b: Vector3 = ring[j]
		var tip: Vector3 = (base_a + base_b) * 0.5
		tip.x = HALF + rng.randf_range(0.0, 0.012)
		tip.y += rng.randf_range(-0.012, 0.012)
		var tone := WOOD.lightened(rng.randf_range(0.0, 0.1))
		cloth.facet(base_a, base_b, tip, tip - Vector3(0.0, c.y, c.z), BARK, BARK, tone)

## A broken branch stub standing off the upper side at x0, round the trunk at
## `theta`, `length` long, with a pale cut end.
static func _stub(cloth: Cloth, rng: RandomNumberGenerator, x0: float, theta: float, radius: float, length: float) -> void:
	var base := _surface(x0, theta, -0.012)
	var dir := (_out(theta) + Vector3(rng.randf_range(-0.12, 0.12), 0.35, 0.0)).normalized()
	var side := dir.cross(Vector3.RIGHT).normalized()
	var along := side.cross(dir).normalized()
	var sides := 4
	var lower: Array[Vector3] = []
	var upper: Array[Vector3] = []
	for i in range(sides):
		var a := TAU * i / sides + rng.randf_range(-0.2, 0.2)
		var ring := side * cos(a) + along * sin(a)
		lower.append(base + ring * radius)
		upper.append(base + dir * length + ring * radius * rng.randf_range(0.6, 0.78) + side * rng.randf_range(-0.004, 0.004))
	var top := base + dir * (length * 1.0) + dir * 0.006
	for i in range(sides):
		var j := (i + 1) % sides
		var mid := (lower[i] + lower[j] + upper[i] + upper[j]) * 0.25 - base
		var tone := _bark(rng.randf_range(-0.1, 0.12), 0.0, rng)
		cloth.facet(lower[i], lower[j], upper[i], mid, tone, tone, tone)
		cloth.facet(lower[j], upper[j], upper[i], mid, tone, tone, tone)
		var wood := WOOD.darkened(rng.randf_range(0.0, 0.12))
		cloth.facet(upper[i], upper[j], top, dir, wood, wood, wood)

## A ragged cushion of moss over the bark: a grid of `cols` x `rows` quads
## round (x_mid, theta_mid). Edges sink to the bark and darken; the crest is
## lifted and lit. Normals are soft (outward blended with up).
static func _moss(cloth: Cloth, rng: RandomNumberGenerator, x_mid: float, half_len: float, theta_mid: float, half_width: float, cols: int, rows: int, height: float, wander: bool) -> void:
	var seed_a := rng.randf() * TAU
	var seed_b := rng.randf() * TAU
	var grid: Array = []
	for ci in range(cols + 1):
		var u := float(ci) / cols * 2.0 - 1.0
		var x := x_mid + u * half_len
		# Ragged width and wandering centre; the ends close up.
		var taper := pow(maxf(1.0 - u * u, 0.0), 0.35) if wander else sqrt(maxf(1.0 - u * u, 0.0))
		var width := half_width * taper * (0.62 + 0.38 * (0.5 + 0.5 * sin(seed_a + u * 5.3 + 1.7)))
		var shift := 0.0
		if wander: shift = 0.22 * sin(seed_b + u * 3.1) + 0.1 * sin(seed_a * 2.0 + u * 7.0)
		var column: Array = []
		for ri in range(rows + 1):
			var v := float(ri) / rows * 2.0 - 1.0
			var theta := theta_mid + shift + v * width
			var dome := (1.0 - v * v) * taper
			var lift := lerpf(0.008, height, dome) * rng.randf_range(0.85, 1.12)
			var normal := (_out(theta) * 0.55 + Vector3.UP * 0.45).normalized()
			var glow := clampf(dome * 1.15 + rng.randf_range(-0.12, 0.12), 0.0, 1.0)
			column.append([_surface(x, theta, lift), normal, MOSS_EDGE.lerp(MOSS_CREST, glow)])
		grid.append(column)
	for ci in range(cols):
		for ri in range(rows):
			var p00: Array = grid[ci][ri]
			var p01: Array = grid[ci][ri + 1]
			var p10: Array = grid[ci + 1][ri]
			var p11: Array = grid[ci + 1][ri + 1]
			cloth.soft(p00[0], p01[0], p10[0], p00[1], p01[1], p10[1], p00[2], p01[2], p10[2])
			cloth.soft(p01[0], p11[0], p10[0], p01[1], p11[1], p10[1], p01[2], p11[2], p10[2])

## A tiny tuft of five blades rising from the moss: three triangles each,
## dark at the root and lit at the tip, soft up-normals. The blade's width
## runs across the log (z), which the length scale does not stretch.
static func _tuft(cloth: Cloth, rng: RandomNumberGenerator, x: float, theta: float) -> void:
	var root := _surface(x, theta, 0.014)
	for b in range(5):
		var angle := TAU * b / 5.0 + rng.randf_range(-0.4, 0.4)
		var lean := Vector3(cos(angle) * 0.01, 0.0, sin(angle) * 0.03)
		var height := rng.randf_range(0.055, 0.095)
		var base := root + Vector3(rng.randf_range(-0.004, 0.004), 0.0, rng.randf_range(-0.012, 0.012))
		var half := Vector3(0.0, 0.0, 0.0045)
		var mid := base + Vector3.UP * height * 0.55 + lean * 0.4
		var tip := base + Vector3.UP * height + lean
		var tilt := (Vector3.UP + lean * 2.0).normalized()
		var mid_c := BLADE_ROOT.lerp(BLADE_TIP, 0.55)
		var tip_c := BLADE_TIP.lightened(rng.randf_range(-0.05, 0.08))
		cloth.soft(base - half, base + half, mid - half * 0.8, Vector3.UP, Vector3.UP, tilt, BLADE_ROOT, BLADE_ROOT, mid_c)
		cloth.soft(base + half, mid + half * 0.8, mid - half * 0.8, Vector3.UP, tilt, tilt, BLADE_ROOT, mid_c, mid_c)
		cloth.soft(mid - half * 0.8, mid + half * 0.8, tip, tilt, tilt, tilt, mid_c, mid_c, tip_c)
