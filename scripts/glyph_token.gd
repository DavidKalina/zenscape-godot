extends RefCounted
## Collectible tokens: a HUD glyph (scripts/hud_icons.gd) made solid. The
## glyph's silhouette is traced from its "locked" SVG, cut by the same kind
## of jittered triangle grid the icon is shaded with, and each facet raised
## into a faceted pillow (low at the rim, high inside) so it catches the
## sun like a cut stone. The front and back are shaded like the icon (its
## tint leaning light top-left, dark bottom-right); the glyph's lines are
## drawn over them from a rasterised lines-only SVG; the rim is the tint in
## shade. A soft glow wraps it (shaders/glyph_token.gdshader).
const HudIcons = preload("res://scripts/hud_icons.gd")
const TOKEN_SHADER = preload("res://shaders/glyph_token.gdshader")

## Raster scale for tracing the silhouette and drawing the lines (px a unit).
const TRACE := 10.0
## How far the traced outline may stray from the pixels (px).
const TRACE_EPSILON := 1.6
## Facet grid cells a side (the HUD uses 4; a solid wants a few more).
const GRID := 6
## Half the rim's thickness and how far the middle swells past it, and how
## far in (icon units) the swell takes to reach full height.
const RIM := 0.9
const SWELL := 1.3
const SWELL_REACH := 3.2
## The icon's lean to light and to shade, softened since the sun shades the
## facets too (light least, so the tint stays rich).
const LEAN := 0.55
const LEAN_LIGHT := 0.25

static var _meshes := {}

## The token for `id`, `size` m across its 24-unit box, glow included.
static func token(id: String, size := 1.0) -> MeshInstance3D:
	var mesh := mesh_for(id)
	if mesh == null: return null
	var node := MeshInstance3D.new()
	node.name = "Glyph_"+id
	node.mesh = mesh
	node.scale = Vector3.ONE*size/24.0
	var material := ShaderMaterial.new()
	material.shader = TOKEN_SHADER
	material.set_shader_parameter("lines",lines_texture(id))
	material.set_shader_parameter("glow_tint",Color(HudIcons.item(id).tint).lightened(0.15))
	node.material_override = material
	return node

## The token's mesh in icon units (24 across, centred, +Z to the front).
static func mesh_for(id: String) -> ArrayMesh:
	if _meshes.has(id): return _meshes[id]
	var it := HudIcons.item(id)
	if it.is_empty(): return null
	var outlines := _trace(id)
	if outlines.is_empty(): return null
	var outers: Array[PackedVector2Array] = []
	var holes: Array[PackedVector2Array] = []
	for p: PackedVector2Array in outlines:
		var inside := false
		for q: PackedVector2Array in outlines:
			if q != p and Geometry2D.is_point_in_polygon(p[0],q): inside = true
		if inside: holes.append(p)
		else: outers.append(p)
	var tint: Color = it.tint
	var side := tint.lerp(HudIcons.SHADE,0.35)
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()
	# Front and back: facet triangles clipped to the silhouette.
	for facet: Array in _facets(int(it.seed),tint):
		var pieces: Array = []
		for o in outers: pieces.append_array(Geometry2D.intersect_polygons(facet[0],o))
		for h in holes:
			var kept: Array = []
			for piece: PackedVector2Array in pieces: kept.append_array(Geometry2D.clip_polygons(piece,h))
			pieces = kept
		for piece: PackedVector2Array in pieces:
			if Geometry2D.is_polygon_clockwise(piece) != Geometry2D.is_polygon_clockwise(facet[0]): continue
			var tris := Geometry2D.triangulate_polygon(piece)
			for t in range(0,tris.size(),3):
				var flat := [piece[tris[t]],piece[tris[t+1]],piece[tris[t+2]]]
				for face: float in [1.0,-1.0]:
					var points: Array[Vector3] = []
					for p: Vector2 in flat: points.append(_at(p,face*(RIM+SWELL*_swell(p,outlines))))
					_tri(v,n,c,uv,points,Vector3(0.0,0.0,face),facet[1],flat)
	# The rim: each outline segment a wall from front to back.
	for p: PackedVector2Array in outlines:
		for i in range(p.size()):
			var a := p[i]
			var b := p[(i+1)%p.size()]
			var a0 := _at(a,RIM)
			var b0 := _at(b,RIM)
			var a1 := _at(a,-RIM)
			var b1 := _at(b,-RIM)
			var mid := (a+b)*0.5
			var out := Vector3(-(b-a).y,-(b-a).x,0.0).normalized()
			# Out is whichever side of the wall the silhouette isn't on.
			var probe := mid+Vector2(out.x,-out.y)*0.05
			if _inside(probe,outers,holes): out = -out
			_tri(v,n,c,uv,[a0,b0,b1],out,side,[])
			_tri(v,n,c,uv,[a0,b1,a1],out,side,[])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_COLOR] = c
	arrays[Mesh.ARRAY_TEX_UV] = uv
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	_meshes[id] = mesh
	return mesh

## The glyph's lines alone, drawn dark on clear over its box (UV 0-1 across
## the BOX units), or a clear pixel when it has none.
static func lines_texture(id: String) -> Texture2D:
	var it := HudIcons.item(id)
	var body := ""
	var dark: Color = Color(it.tint).lerp(HudIcons.SHADE,0.45)
	for d: String in it.lines:
		body += '<path d="%s" fill="none" stroke="#%s" stroke-width="%s" stroke-linecap="round" stroke-linejoin="round"/>' % [d,dark.to_html(false),String.num(float(it.lw),3)]
	var image := Image.new()
	if body.is_empty():
		image = Image.create(1,1,false,Image.FORMAT_RGBA8)
	else:
		var b := HudIcons.BOX
		var pad := HudIcons.PAD
		var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="%s %s %s %s">%s</svg>' % [int(b),int(b),-pad,-pad,b,b,body]
		image.load_svg_from_string(svg,TRACE*2.0)
		image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

## The silhouette's outlines in icon units, traced from the "locked" SVG.
static func _trace(id: String) -> Array[PackedVector2Array]:
	var image := Image.new()
	if image.load_svg_from_string(HudIcons.svg(id,"locked"),TRACE) != OK: return []
	var bits := BitMap.new()
	bits.create_from_image_alpha(image,0.5)
	var out: Array[PackedVector2Array] = []
	for p: PackedVector2Array in bits.opaque_to_polygons(Rect2i(Vector2i.ZERO,image.get_size()),TRACE_EPSILON):
		if p.size() < 3: continue
		var units := PackedVector2Array()
		for q in p: units.append(q/TRACE-Vector2.ONE*HudIcons.PAD)
		if absf(_area(units)) > 0.05: out.append(units)
	return out

## The jittered facet grid (HudIcons.facets, GRID a side): [triangle, colour].
static func _facets(seed: int, base: Color) -> Array:
	var s := seed*131+7
	var step := 26.0/GRID
	var grid: Array[Vector2] = []
	for y in range(GRID+1):
		for x in range(GRID+1):
			var jx := 0.0
			var jy := 0.0
			if not (x == 0 or y == 0 or x == GRID or y == GRID):
				s = (s*9301+49297)%233280
				jx = (s/233280.0-0.5)*step*0.75
				s = (s*9301+49297)%233280
				jy = (s/233280.0-0.5)*step*0.75
			grid.append(Vector2(-1.0+x*step+jx,-1.0+y*step+jy))
	var out := []
	for y in range(GRID):
		for x in range(GRID):
			var a := grid[y*(GRID+1)+x]
			var b := grid[y*(GRID+1)+x+1]
			var c := grid[(y+1)*(GRID+1)+x]
			var d := grid[(y+1)*(GRID+1)+x+1]
			for q: Array in ([[a,b,d],[a,d,c]] if (x+y)%2 == 1 else [[a,b,c],[b,d,c]]):
				var centre: Vector2 = (q[0]+q[1]+q[2])/3.0
				s = (s*9301+49297)%233280
				var t := (centre.x+centre.y)/48.0+(s/233280.0-0.5)*HudIcons.JITTER
				var fill := base.lerp(HudIcons.LIGHT,clampf((0.5-t)*HudIcons.LIFT*LEAN_LIGHT,0.0,1.0)) if t < 0.5 else base.lerp(HudIcons.SHADE,clampf((t-0.5)*HudIcons.DROP*LEAN,0.0,1.0))
				out.append([PackedVector2Array(q),fill])
	return out

## 0 on the outline rising to 1 SWELL_REACH units in.
static func _swell(p: Vector2, outlines: Array[PackedVector2Array]) -> float:
	var best := INF
	for o in outlines:
		for i in range(o.size()):
			var q := Geometry2D.get_closest_point_to_segment(p,o[i],o[(i+1)%o.size()])
			best = minf(best,p.distance_squared_to(q))
	return smoothstep(0.0,SWELL_REACH,sqrt(best))

static func _inside(p: Vector2, outers: Array[PackedVector2Array], holes: Array[PackedVector2Array]) -> bool:
	for h in holes:
		if Geometry2D.is_point_in_polygon(p,h): return false
	for o in outers:
		if Geometry2D.is_point_in_polygon(p,o): return true
	return false

## Icon units (y down) to the token's space (y up, centred).
static func _at(p: Vector2, z: float) -> Vector3:
	return Vector3(p.x-12.0,12.0-p.y,z)

## A flat-shaded triangle wound to face `toward`; `flat` gives its UVs.
static func _tri(v: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray, uv: PackedVector2Array, points: Array, toward: Vector3, colour: Color, flat: Array) -> void:
	var a: Vector3 = points[0]
	var b: Vector3 = points[1]
	var d: Vector3 = points[2]
	var normal := (d-a).cross(b-a).normalized()
	var order := [0,1,2]
	if normal.dot(toward) < 0.0:
		normal = -normal
		order = [0,2,1]
	if normal == Vector3.ZERO: return
	for k: int in order:
		v.append(points[k])
		n.append(normal)
		c.append(colour)
		var f: Vector2 = flat[k] if not flat.is_empty() else Vector2(-99.0,-99.0)
		uv.append((f+Vector2.ONE*HudIcons.PAD)/HudIcons.BOX)

static func _area(p: PackedVector2Array) -> float:
	var sum := 0.0
	for i in range(p.size()): sum += p[i].cross(p[(i+1)%p.size()])
	return sum*0.5
