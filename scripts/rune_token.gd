extends RefCounted
## The rune token (glyph id "rune", scripts/glyph_pickup.gd): a red stone
## plummet hanging from nothing. A six-sided crystal, blunt shoulders round a
## small flat cap, tapering long below its girdle to a point, cut in flat
## facets that catch the sun, a carved rune on each long facet; over it a
## bead and a thread of light that fades out a little way up. Hung in a
## "Sway" pivot at the thread's top (`swing` sways it), so it reads as
## weighted, on a line nobody can see the end of. The stone glows
## (shaders/rune_token.gdshader) with an ember beating inside; the thread
## and bead are light only (shaders/rune_thread.gdshader). The uniforms are
## the glyph token's (`glow`, `inner`, `glow_tint`), so the pickup lights
## and spins it as it does the glyphs. The stone's shape goes to the shader
## too, so its runes sit on the facets.
const RUNE_SHADER = preload("res://shaders/rune_token.gdshader")
const THREAD_SHADER = preload("res://shaders/rune_thread.gdshader")

## The stone: its sides, its half-width at the girdle, its flat cap's
## half-width and height above the girdle, and its point below it, as
## shares of the token's size.
const SIDES := 6
const GIRDLE := 0.24
const CAP := 0.09
const TOP := 0.2
const BOTTOM := 0.62
## The bead on the cap and the thread over it: the bead's radius, the
## thread's length and radius (shares of the size).
const BEAD := 0.035
const THREAD := 1.1
const THREAD_WIDTH := 0.006
## The sway: how far it leans (rad) on its two axes and their paces (rad/s),
## out of step so the point traces a slow wandering loop.
const SWAY := Vector2(0.075,0.05)
const SWAY_PACE := Vector2(0.9,0.63)

## The whole plummet, `size` m across, its glow in `tint`: the stone
## centred on the node, bead and thread above, all in its "Sway" pivot.
static func plummet(size: float, tint: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Plummet"
	var pivot_y := (TOP+BEAD*2.0+THREAD)*size+_centre(size)
	var sway := Node3D.new()
	sway.name = "Sway"
	sway.position.y = pivot_y
	root.add_child(sway)
	var hang := Node3D.new()
	hang.name = "Hang"
	hang.position.y = -pivot_y
	sway.add_child(hang)
	var body := stone(size,tint)
	body.position.y = _centre(size)
	hang.add_child(body)
	var bead_node := bead(size,tint)
	bead_node.position.y = _centre(size)+(TOP+BEAD)*size
	hang.add_child(bead_node)
	var line := thread(size,tint)
	line.position.y = _centre(size)+(TOP+BEAD*2.0+THREAD*0.5)*size
	hang.add_child(line)
	return root

## How far the stone's girdle sits above the plummet's middle, so the stone
## (cap to point) is centred on it.
static func _centre(size: float) -> float:
	return (BOTTOM-TOP)*0.5*size

## The stone alone, `size` m across, its girdle at its origin.
static func stone(size: float, tint: Color) -> MeshInstance3D:
	var g := GIRDLE*size
	var c := CAP*size
	var girdle: Array[Vector3] = []
	var cap: Array[Vector3] = []
	for i in range(SIDES):
		var a := TAU*i/SIDES
		girdle.append(Vector3(cos(a)*g,0.0,sin(a)*g))
		cap.append(Vector3(cos(a)*c,TOP*size,sin(a)*c))
	var top := Vector3(0.0,TOP*size,0.0)
	var bottom := Vector3(0.0,-BOTTOM*size,0.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(SIDES):
		var j := (i+1)%SIDES
		_facet(st,top,cap[j],cap[i])
		_facet(st,cap[i],cap[j],girdle[j])
		_facet(st,cap[i],girdle[j],girdle[i])
		_facet(st,bottom,girdle[i],girdle[j])
	var node := MeshInstance3D.new()
	node.name = "Stone"
	node.mesh = st.commit()
	node.material_override = _material(tint,size)
	return node

## The bead on the cap, light only.
static func bead(size: float, tint: Color) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = BEAD*size
	sphere.height = BEAD*size*2.0
	sphere.radial_segments = 8
	sphere.rings = 4
	var node := MeshInstance3D.new()
	node.name = "Bead"
	node.mesh = sphere
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.material_override = _light(tint,size,1.0)
	return node

## The thread over the bead, light only, fading out as it rises.
static func thread(size: float, tint: Color) -> MeshInstance3D:
	var line := CylinderMesh.new()
	line.top_radius = THREAD_WIDTH*size
	line.bottom_radius = THREAD_WIDTH*size
	line.height = THREAD*size
	line.radial_segments = 4
	line.rings = 1
	line.cap_top = false
	line.cap_bottom = false
	var node := MeshInstance3D.new()
	node.name = "Thread"
	node.mesh = line
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.material_override = _light(tint,size,0.0)
	return node

## Sways plummet `node` for time `t` (s), out of step by `phase` (rad),
## `share` as far.
static func swing(node: Node3D, t: float, phase := 0.0, share := 1.0) -> void:
	var sway := node.get_node_or_null("Sway") as Node3D
	if sway == null: return
	sway.rotation.x = sin(t*SWAY_PACE.x+phase)*SWAY.x*share
	sway.rotation.z = sin(t*SWAY_PACE.y+phase*1.7+1.1)*SWAY.y*share

## Its materials: the stone's first, then the bead's and the thread's.
static func materials(node: Node3D) -> Array[ShaderMaterial]:
	var out: Array[ShaderMaterial] = []
	for path in ["Sway/Hang/Stone","Sway/Hang/Bead","Sway/Hang/Thread"]:
		var mesh := node.get_node_or_null(path) as MeshInstance3D
		if mesh != null: out.append(mesh.material_override as ShaderMaterial)
	return out

## A facet, flat: its own normal on all three corners.
static func _facet(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var n := (b-a).cross(c-a).normalized()
	for v: Vector3 in [a,b,c]:
		st.set_normal(n)
		st.add_vertex(v)

static func _material(tint: Color, size: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = RUNE_SHADER
	material.set_shader_parameter("tint",tint)
	material.set_shader_parameter("glow_tint",tint.lightened(0.35))
	material.set_shader_parameter("size",size)
	material.set_shader_parameter("sides",float(SIDES))
	material.set_shader_parameter("girdle",GIRDLE)
	material.set_shader_parameter("cap",CAP)
	material.set_shader_parameter("top",TOP)
	material.set_shader_parameter("bottom",BOTTOM)
	return material

static func _light(tint: Color, size: float, is_bead: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = THREAD_SHADER
	material.set_shader_parameter("tint",tint.lightened(0.25))
	material.set_shader_parameter("size",size)
	material.set_shader_parameter("thread_share",THREAD)
	material.set_shader_parameter("bead",is_bead)
	return material
