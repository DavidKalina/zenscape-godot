extends RefCounted
## The rune token (glyph id "rune", scripts/glyph_pickup.gd): a glowing
## diamond, a four-sided bipyramid taller above its girdle than below, cut
## in flat facets that catch the sun, and a thin ring round it on a tilt that
## the holder turns, so it orbits the diamond diagonally. Both glow
## (shaders/rune_token.gdshader), the ring the brighter; the uniforms are
## the glyph token's (`glow`, `inner`, `glow_tint`), so the pickup lights
## and spins it as it does the glyphs. The diamond's shape goes to the
## shader too, so its runes sit on the facets.
const RUNE_SHADER = preload("res://shaders/rune_token.gdshader")

## The diamond: its half-width at the girdle, its tip above and below it,
## as shares of the token's size.
const GIRDLE := 0.3
const TOP := 0.62
const BOTTOM := 0.42
## The ring: its radius and its band's half-thickness (shares of the size),
## and how far it tilts off level (rad).
const RING := 0.58
const RING_BAND := 0.022
const TILT := 0.5

## The diamond, `size` m across, its glow in `tint`.
static func diamond(size: float, tint: Color) -> MeshInstance3D:
	var g := GIRDLE*size
	var girdle: Array[Vector3] = [Vector3(g,0.0,0.0),Vector3(0.0,0.0,g),Vector3(-g,0.0,0.0),Vector3(0.0,0.0,-g)]
	var top := Vector3(0.0,TOP*size,0.0)
	var bottom := Vector3(0.0,-BOTTOM*size,0.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(4):
		var a := girdle[i]
		var b := girdle[(i+1)%4]
		_facet(st,top,b,a)
		_facet(st,bottom,a,b)
	var node := MeshInstance3D.new()
	node.name = "Diamond"
	node.mesh = st.commit()
	node.material_override = _material(tint,0.0,size)
	return node

## The ring round a diamond `size` m across, tilted, in `tint`.
static func ring(size: float, tint: Color) -> MeshInstance3D:
	var torus := TorusMesh.new()
	torus.inner_radius = (RING-RING_BAND)*size
	torus.outer_radius = (RING+RING_BAND)*size
	torus.rings = 48
	torus.ring_segments = 6
	var node := MeshInstance3D.new()
	node.name = "Ring"
	node.mesh = torus
	node.rotation.x = TILT
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.material_override = _material(tint,1.0,size)
	return node

## A facet, flat: its own normal on all three corners.
static func _facet(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var n := (b-a).cross(c-a).normalized()
	for v: Vector3 in [a,b,c]:
		st.set_normal(n)
		st.add_vertex(v)

static func _material(tint: Color, band: float, size: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = RUNE_SHADER
	material.set_shader_parameter("tint",tint)
	material.set_shader_parameter("glow_tint",tint.lightened(0.35))
	material.set_shader_parameter("band",band)
	material.set_shader_parameter("size",size)
	material.set_shader_parameter("girdle",GIRDLE)
	material.set_shader_parameter("top",TOP)
	material.set_shader_parameter("bottom",BOTTOM)
	return material
