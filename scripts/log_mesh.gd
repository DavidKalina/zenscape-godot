extends RefCounted
## The fallen log (asset "log"), redesigned in the family's style: a faceted
## solid with soft living things on it (docs/scenic/grass-look.md). Two parts
## share the records' transforms, as a tree's trunk and crown do.
##
## "logs" (the bark, replacing the source mesh): a unit-long solid along local
## X (the records scale it: x is the length, y and z the girth, as the source
## log's), about 0.3 across, so footprint and placement are the source log's.
## - Twelve facets round a trunk that tapers and bends noticeably; the outline
##   is round (small radius jitter) and the facets show in the light through
##   per-face normals and lightness, in the source bark brown, darker below.
## - Two broken branch stubs: tapered cones, angled, with an oblique pale break.
## - One end sawn: a thin cambium rim and alternating light and dark end-grain
##   rings round a pale heart. The other broken: a ragged edge, a recessed
##   splintered face and splinters.
##
## "log-moss" (a new part): many small clumps along the top and shoulders, each
## a few leaf blades and low faceted cushions, built for the `grass_blades`
## mode of reference_surface.gdshader as undergrowth_mesh.gd's fern and shrub
## are: UV.y is the along fraction, vertex colours a root-to-tip gradient, and
## the shader gives them the meadow's living green, dome-soft light and sheen.
const BARK := Color(0.1569, 0.1176, 0.0784)
const WOOD := Color(0.62, 0.47, 0.27)
const WOOD_RING := Color(0.31, 0.21, 0.10)
const CAMBIUM := Color(0.30, 0.22, 0.12)
## The moss gradient, like the grass tuft's (sRGB, converted on build).
const MOSS_ROOT := Color("36623a")
const MOSS_TIP := Color("86b455")
const SIDES := 12
const RINGS := 7
const HALF := 0.5
const NODE_MOSS := "log-moss"

static var _mesh: ArrayMesh
static var _moss: ArrayMesh

class Cloth extends RefCounted:
	var surface := SurfaceTool.new()
	var count := 0
	func _init() -> void:
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	func vertex(p: Vector3, n: Vector3, c: Color, along: float) -> void:
		surface.set_color(c)
		surface.set_uv(Vector2(0.5, along))
		surface.set_uv2(Vector2.ZERO)
		surface.set_normal(n)
		surface.add_vertex(p)
	## A faceted triangle: its own face normal, turned to face `outward`.
	func facet(a: Vector3, b: Vector3, c: Vector3, outward: Vector3, ca: Color, cb: Color, cc: Color) -> void:
		var n := (b - a).cross(c - a)
		if n.length_squared() < 1.0e-12: return
		n = n.normalized()
		if n.dot(outward) < 0.0: n = -n
		vertex(a, n, ca, 0.0)
		vertex(b, n, cb, 0.0)
		vertex(c, n, cc, 0.0)
		count += 1
	## A moss triangle: vertex colours and "along" fractions as the grass reads them.
	func blade(a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color, la: float, lb: float, lc: float) -> void:
		vertex(a, Vector3.UP, ca, la)
		vertex(b, Vector3.UP, cb, lb)
		vertex(c, Vector3.UP, cc, lc)
		count += 1

## The redesigned bark, built once.
static func log_mesh() -> ArrayMesh:
	if _mesh == null: _mesh = _build_bark()
	return _mesh

## The moss part, built once, with its own grass-look material.
static func moss_mesh() -> ArrayMesh:
	if _moss == null:
		_moss = _build_moss()
		_moss.set_meta("grass_root", MOSS_ROOT.srgb_to_linear())
		_moss.set_meta("grass_tip", MOSS_TIP.srgb_to_linear())
		_moss.surface_set_material(0, moss_material(_moss))
	return _moss

## The baked log (`logs`) swaps to the new bark, keeping the source material.
static func swap(node_name: String, original: Mesh) -> Mesh:
	if node_name != "logs": return original
	var mesh := log_mesh().duplicate() as ArrayMesh
	mesh.surface_set_material(0, original.surface_get_material(0))
	return mesh

## The moss on a reference_surface material: the grass look, root and tip
## colours for the shader to divide out, only the very root taking the bark's
## neighbourhood (the ground's) colour.
static func moss_material(mesh: Mesh) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/reference_surface.gdshader")
	material.set_shader_parameter("plant_growth", true)
	material.set_shader_parameter("flat_faces", false)
	material.set_shader_parameter("grass_blades", true)
	material.set_shader_parameter("grass_root_blend", Vector2(0.55, 0.2))
	var root: Color = mesh.get_meta("grass_root")
	var tip: Color = mesh.get_meta("grass_tip")
	material.set_shader_parameter("grass_source_root", Vector3(root.r, root.g, root.b))
	material.set_shader_parameter("grass_source_tip", Vector3(tip.r, tip.g, tip.b))
	return material

static func triangle_count(mesh: Mesh) -> int:
	var arrays := mesh.surface_get_arrays(0)
	var indices = arrays[Mesh.ARRAY_INDEX]
	if indices != null and indices.size() > 0: return indices.size() / 3
	return (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3

# --- shape --------------------------------------------------------------

## The trunk's centre line (y, z): a visible bend.
static func _centre(x: float) -> Vector2:
	return Vector2(0.013 * sin(x * 3.4 + 0.6) + 0.01 * x, 0.03 * sin(x * 2.5 + 2.0))

## Radius: a butt tapering well toward the top, swollen a little at the butt,
## with a slow, small lumpiness (the outline stays round).
static func _radius(x: float, theta: float) -> float:
	var t := (x + HALF) / (2.0 * HALF)
	var r := lerpf(0.160, 0.114, t) * (1.0 + 0.05 * exp(-pow((t - 0.03) / 0.09, 2.0)))
	return r * (1.0 + 0.02 * sin(3.0 * theta + 0.8 + 3.0 * x) + 0.012 * sin(5.0 * theta + 2.1 - 4.0 * x))

## A point on the bark at (x, theta), lifted by `lift`; PI/2 is straight up.
static func _surface(x: float, theta: float, lift: float) -> Vector3:
	var c := _centre(x)
	return Vector3(x, c.x, c.y) + _out(theta) * (_radius(x, theta) + lift)

static func _out(theta: float) -> Vector3:
	return Vector3(0.0, sin(theta), cos(theta))

static func _axis(x: float) -> Vector3:
	var c := _centre(x)
	return Vector3(x, c.x, c.y)

static func _build_bark() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6203
	var cloth := Cloth.new()
	var thetas: Array[float] = []
	for i in range(SIDES):
		thetas.append(TAU * i / SIDES + rng.randf_range(-0.05, 0.05))
	var pts: Array = []
	var xs: Array[float] = []
	for k in range(RINGS):
		var x := lerpf(-HALF, HALF, float(k) / (RINGS - 1))
		if k > 0 and k < RINGS - 1: x += rng.randf_range(-0.025, 0.025)
		xs.append(x)
		var ring: Array[Vector3] = []
		for i in range(SIDES):
			ring.append(_surface(x, thetas[i], rng.randf_range(-0.004, 0.003)))
		pts.append(ring)
	# The broken end's ring is ragged: each point pulled back by its own amount.
	var ragged: Array[float] = []
	for i in range(SIDES):
		var pull := rng.randf_range(0.025, 0.07) if i % 3 != 1 else rng.randf_range(0.0, 0.02)
		ragged.append(pull)
		var p: Vector3 = pts[RINGS - 1][i]
		p.x -= pull
		pts[RINGS - 1][i] = p
	for k in range(RINGS - 1):
		for i in range(SIDES):
			var j := (i + 1) % SIDES
			var a: Vector3 = pts[k][i]
			var b: Vector3 = pts[k][j]
			var c: Vector3 = pts[k + 1][i]
			var d: Vector3 = pts[k + 1][j]
			var mid := (a + b + c + d) * 0.25
			var around := mid - _axis(mid.x)
			around.x = 0.0
			var shade := rng.randf_range(-0.14, 0.14)
			var below := clampf(-around.normalized().y * 1.3, 0.0, 1.0)
			var face_a := _bark(shade, below, rng)
			var face_b := _bark(shade + rng.randf_range(-0.05, 0.05), below, rng)
			cloth.facet(a, b, c, around, face_a, face_a, face_a)
			cloth.facet(b, d, c, around, face_b, face_b, face_b)
	_sawn_end(cloth, rng, pts[0], xs[0])
	_broken_end(cloth, rng, pts[RINGS - 1], ragged)
	_stub(cloth, rng, -0.16, 1.05, 0.034, 0.11, 0.3)
	_stub(cloth, rng, 0.22, 2.0, 0.028, 0.09, -0.35)
	return cloth.surface.commit()

static func _bark(shade: float, below: float, rng: RandomNumberGenerator) -> Color:
	var c := BARK.lightened(shade) if shade >= 0.0 else BARK.darkened(-shade)
	c = c.darkened(below * 0.3)
	return Color(c.r * rng.randf_range(0.96, 1.05), c.g * rng.randf_range(0.97, 1.04), c.b * rng.randf_range(0.95, 1.06))

## The sawn end at x = -0.5: a thin cambium rim, then alternating light and dark
## rings of end grain round a pale heart.
static func _sawn_end(cloth: Cloth, rng: RandomNumberGenerator, ring: Array, x: float) -> void:
	var inset := 0.006
	var c := _axis(x)
	var centre := Vector3(x + inset * 2.4, c.y, c.z)
	var outward := Vector3.LEFT
	var radii := [0.93, 0.76, 0.56, 0.36]
	var bands: Array = []
	for scale in radii:
		var band: Array[Vector3] = []
		for i in range(SIDES):
			var q: Vector3 = c + ((ring[i] as Vector3) - c) * scale * rng.randf_range(0.97, 1.03)
			q.x = x + inset * (1.0 + (1.0 - scale) * 1.4)
			band.append(q)
		bands.append(band)
	# Light, dark, light between rings; the last ring and the heart are dark and light.
	var tones: Array[Color] = [WOOD, WOOD_RING, WOOD.lightened(0.05)]
	for i in range(SIDES):
		var j := (i + 1) % SIDES
		cloth.facet(ring[i], ring[j], bands[0][i], outward, CAMBIUM, CAMBIUM, CAMBIUM)
		cloth.facet(ring[j], bands[0][j], bands[0][i], outward, CAMBIUM, CAMBIUM, CAMBIUM)
		for b in range(3):
			var colour: Color = tones[b].lightened(rng.randf_range(-0.03, 0.04))
			cloth.facet(bands[b][i], bands[b][j], bands[b + 1][i], outward, colour, colour, colour)
			cloth.facet(bands[b][j], bands[b + 1][j], bands[b + 1][i], outward, colour, colour, colour)
		var heart := WOOD_RING.lightened(rng.randf_range(0.0, 0.05))
		cloth.facet(bands[3][i], bands[3][j], centre, outward, heart, heart, heart)

## The broken end at x = +0.5: a recessed ragged face and a few splinters.
static func _broken_end(cloth: Cloth, rng: RandomNumberGenerator, ring: Array, ragged: Array[float]) -> void:
	var c := _axis(HALF)
	var centre := Vector3(HALF - 0.085, c.y, c.z)
	for i in range(SIDES):
		var j := (i + 1) % SIDES
		var tone := WOOD.darkened(rng.randf_range(0.1, 0.35))
		cloth.facet(ring[i], ring[j], centre, Vector3.RIGHT, tone, tone, tone)
	for i in range(SIDES):
		if ragged[i] < 0.05: continue
		var j := (i + 1) % SIDES
		var a: Vector3 = ring[i]
		var b: Vector3 = ring[j]
		var tip := (a + b) * 0.5
		tip.x = HALF + rng.randf_range(0.0, 0.012)
		tip.y += rng.randf_range(-0.012, 0.012)
		var tone := WOOD.lightened(rng.randf_range(-0.05, 0.08))
		cloth.facet(a, b, tip, tip - Vector3(0.0, c.y, c.z), BARK, BARK, tone)

## A broken branch stub off the upper side at x0, round the trunk at `theta`:
## a tapered five-sided cone leaning along the log by `lean`, snapped off
## obliquely with a pale break.
static func _stub(cloth: Cloth, rng: RandomNumberGenerator, x0: float, theta: float, radius: float, length: float, lean: float) -> void:
	var base := _surface(x0, theta, -0.014)
	var dir := (_out(theta) + Vector3(lean, 0.25, 0.0)).normalized()
	var side := dir.cross(Vector3.RIGHT).normalized()
	var along := side.cross(dir).normalized()
	var sides := 5
	var lower: Array[Vector3] = []
	var upper: Array[Vector3] = []
	var phase := rng.randf() * TAU
	for i in range(sides):
		var a := phase + TAU * i / sides + rng.randf_range(-0.15, 0.15)
		# Half as wide along the log, which the length scale stretches.
		var ring := side * cos(a) + along * sin(a)
		ring.x *= 0.55
		lower.append(base + ring * radius)
		# The break is oblique: one side stands taller than the other.
		var cut := length * (0.82 + 0.3 * (0.5 + 0.5 * cos(a - 0.7)))
		upper.append(base + dir * cut + ring * radius * rng.randf_range(0.3, 0.42))
	var top := base + dir * length * 0.98
	var wood := WOOD.darkened(rng.randf_range(0.0, 0.1))
	for i in range(sides):
		var j := (i + 1) % sides
		var mid := (lower[i] + lower[j] + upper[i] + upper[j]) * 0.25 - base
		var tone := _bark(rng.randf_range(-0.1, 0.1), 0.0, rng)
		cloth.facet(lower[i], lower[j], upper[i], mid, tone, tone, tone)
		cloth.facet(lower[j], upper[j], upper[i], mid, tone, tone, tone)
		cloth.facet(upper[i], upper[j], top, dir, wood, wood, wood)

# --- moss ---------------------------------------------------------------

static func _build_moss() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8821
	var cloth := Cloth.new()
	# A broken run of clumps along the top (wandering a little), a few lower
	# on the shoulders, thicker toward the sawn end's side.
	var x := -0.4
	var index := 0
	while x < 0.4:
		var theta := PI * 0.5 + 0.35 * sin(x * 7.0 + 1.1) + rng.randf_range(-0.28, 0.28)
		_clump(cloth, rng, x, theta, 5 if index % 3 != 2 else 4, 0.8 + rng.randf() * 0.5)
		if index % 2 == 0: _cushion(cloth, rng, x + rng.randf_range(0.0, 0.06), theta + rng.randf_range(-0.4, 0.4))
		x += rng.randf_range(0.075, 0.115)
		index += 1
	for side in [[-0.28, PI * 0.5 + 1.05], [0.12, PI * 0.5 - 1.1], [0.33, PI * 0.5 + 0.9]]:
		_clump(cloth, rng, side[0], side[1], 3, 0.7)
		_cushion(cloth, rng, side[0] + 0.05, side[1] + 0.1)
	return cloth.surface.commit()

## A little clump of leaf blades rising from the bark at (x, theta): each a
## kite of two triangles (base, widest point, tip), dark at the root and lit at
## the tip, standing mostly upward, leaning away from the clump's middle.
static func _clump(cloth: Cloth, rng: RandomNumberGenerator, x: float, theta: float, blades: int, size: float) -> void:
	for b in range(blades):
		var angle := TAU * b / blades + rng.randf_range(-0.5, 0.5)
		var spot := _surface(x + cos(angle) * 0.008, theta + sin(angle) * 0.07 * size, 0.0)
		var up := (_out(theta) * 0.35 + Vector3.UP * 0.65).normalized()
		var height := rng.randf_range(0.045, 0.085) * size
		var lean := Vector3(cos(angle) * 0.012, 0.0, 0.0) + _out(theta + sin(angle) * 0.5) * 0.02 * size
		var half := Vector3(0.0, 0.0, 0.0085 * size)
		var widest := spot + up * height * 0.38 + lean * 0.3
		var tip := spot + up * height + lean
		var tilt := rng.randf_range(-0.05, 0.08)
		var root := _tone(0.0, 0.0)
		var wide := _tone(0.4, tilt)
		var end := _tone(1.0, tilt + 0.05)
		cloth.blade(spot - half * 0.35, spot + half * 0.35, widest - half, root, root, wide, 0.04, 0.04, 0.4)
		cloth.blade(spot + half * 0.35, widest + half, widest - half, root, wide, wide, 0.04, 0.4, 0.4)
		cloth.blade(widest - half, widest + half, tip, wide, wide, end, 0.4, 0.4, 1.0)

## A low faceted cushion: a six-sided dome set into the bark, soft-lit by the
## grass shading, with the rim dark and the crown lit.
static func _cushion(cloth: Cloth, rng: RandomNumberGenerator, x: float, theta: float) -> void:
	var peak_lift := rng.randf_range(0.022, 0.034)
	var radius := rng.randf_range(0.03, 0.05)
	var peak := _surface(x, theta, peak_lift)
	var rim: Array[Vector3] = []
	var turn := rng.randf() * TAU
	for i in range(6):
		var a := turn + TAU * i / 6.0 + rng.randf_range(-0.2, 0.2)
		rim.append(_surface(x + cos(a) * radius * 0.5, theta + sin(a) * radius / maxf(_radius(x, theta), 0.05), -0.004 + rng.randf_range(0.0, 0.004)))
	var rim_c := _tone(0.12, 0.0)
	for i in range(6):
		var crown := _tone(0.62, rng.randf_range(-0.05, 0.1))
		cloth.blade(rim[i], rim[(i + 1) % 6], peak, rim_c, rim_c, crown, 0.12, 0.12, 0.62)

static func _tone(along: float, jitter: float) -> Color:
	var colour := MOSS_ROOT.lerp(MOSS_TIP, clampf(along, 0.0, 1.0))
	colour = colour.lightened(jitter) if jitter >= 0.0 else colour.darkened(-jitter)
	return colour.srgb_to_linear()
