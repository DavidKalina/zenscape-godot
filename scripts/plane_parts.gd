extends Node3D
## The plane's lost parts, as the pilot finds them on foot: six of the
## biplane's own pieces (scripts/plane_figure.gd `piece`), each a different
## shape, so each find reads as the part it is and not as one generic
## "plane part". A look study (studies/plane_parts_gallery.gd), in two
## treatments to compare:
##   "coin"   the piece drawn flat onto a thick faceted coin: a sky-blue
##            face in a brass bevelled rim, the piece raised on both sides
##            as a faceted pillow in its own paint, seen from the side that
##            says most about it (the propeller from the front, the
##            wingtip from above). The silhouette is traced from the
##            piece's own triangles drawn flat, as the glyph tokens trace
##            their icons (scripts/glyph_token.gd), and lit by the same
##            shader (shaders/glyph_token.gdshader).
##   "piece"  the piece itself, built from the very meshes and paint the
##            plane is, hovering and turning slowly under a warm rim glow
##            (shaders/plane_part_glow.gdshader).
## Both stand in the same holder: a slow turn and bob, a warm halo behind
## (shaders/glyph_halo.gdshader), a few motes, and a soft brass ring of
## light under it, the plane's own landing mark (scripts/facet_mesh.gd
## `soft_ring`), which the rune tokens' cool tilted ring is not.
##   var holder := PlaneParts.part("propeller",0.9,"piece")
##   parent.add_child(holder)
##   holder.glow_for(night)
const PlaneFigure = preload("res://scripts/plane_figure.gd")
const FacetMesh = preload("res://scripts/facet_mesh.gd")
const TOKEN_SHADER = preload("res://shaders/glyph_token.gdshader")
const HALO_SHADER = preload("res://shaders/glyph_halo.gdshader")
const GLOW_SHADER = preload("res://shaders/plane_part_glow.gdshader")

## The parts, in the gallery's order.
const IDS := ["propeller","wheel","cowl","fin","wingtip","windscreen"]
## Each part: its name; the plane's pieces it is made of, each moved by an
## offset (the propeller's own frame sits at the nose); the coin's view of
## it (looking back along `view`, `up` up, turned `roll` on the face); and
## the hovering piece's pose (Euler angles), so it shows its shape as it
## turns.
const PARTS := {
	"propeller":{"name":"Propeller","pieces":[["propeller",Vector3(0.0,0.0,-0.68)],["spinner",Vector3.ZERO]],"view":Vector3(0.0,0.0,-1.0),"up":Vector3.UP,"roll":0.75,"pose":Vector3(0.0,0.0,0.75)},
	"wheel":{"name":"Wheel","pieces":[["wheel",Vector3.ZERO]],"view":Vector3(1.0,0.0,0.0),"up":Vector3.UP,"roll":0.0,"pose":Vector3(0.0,1.2,0.45)},
	"cowl":{"name":"Cowl","pieces":[["cowl",Vector3.ZERO]],"view":Vector3(1.0,0.35,-0.9),"up":Vector3.UP,"roll":0.0,"pose":Vector3(0.0,0.7,0.0)},
	"fin":{"name":"Tail fin","pieces":[["fin",Vector3.ZERO]],"view":Vector3(1.0,0.0,0.0),"up":Vector3.UP,"roll":0.0,"pose":Vector3(0.0,1.25,0.0)},
	"wingtip":{"name":"Wingtip","pieces":[["wingtip",Vector3.ZERO]],"view":Vector3(0.0,1.0,0.0),"up":Vector3(0.0,0.0,-1.0),"roll":0.6,"pose":Vector3(1.05,0.0,0.45)},
	"windscreen":{"name":"Windscreen","pieces":[["windscreen",Vector3.ZERO]],"view":Vector3(0.75,0.35,-1.0),"up":Vector3.UP,"roll":0.0,"pose":Vector3(0.0,-0.5,0.0)},
}

## The coin, in token units (24 across, as the glyph tokens, so the
## shader's shine crosses it the same): its radius, the face's radius
## inside the bevel, half its thickness at the rim's edge and at the face's
## edge, the face's dome, the relief's height at its edge and how far it
## swells inside (reaching full height SWELL_REACH in), and how far the
## relief reaches out over the face.
const R := 12.0
const FACE_R := 10.6
const RIM_T := 1.3
const FACE_T := 1.75
const DOME := 0.35
const RELIEF := 0.55
const SWELL := 0.9
const SWELL_REACH := 1.6
const REACH := 8.6
## Sides round the rim, the face's facet grid (cells a side), and the flat
## drawing's size (px).
const SIDES := 20
const GRID := 10
const RES := 192
## The coin's face and its brass rim.
const FACE := Color("2f5a78")
const RIM_BRASS := Color("b8843c")
## The light the flat drawing is shaded by (towards it, in the view).
const FLAT_LIGHT := Vector3(-0.45,0.6,0.66)

## The turn (rad/s) and the bob (shares of the size, and its pace).
const TURN := 0.55
## Where the turn starts (rad), a little off square, so the first look is
## three quarters on.
const START := -0.4
const BOB := 0.1
const BOB_PACE := 1.1
## The glow by day and at full night: the coin's rim glow, the piece's rim
## glow, the halo, the ring under it; and the faint inner light at night.
const COIN_GLOW := Vector2(0.4,0.6)
const PIECE_GLOW := Vector2(0.55,0.6)
const HALO := Vector2(0.24,0.4)
const RING_GLOW := Vector2(0.32,0.7)
const INNER_NIGHT := 0.04
const WARM := Color("ffd59a")

var id := "propeller"
var style := "coin"
var size := 1.0
## The bob's phase (rad), so a row of them doesn't bob in step.
var phase := 0.0
## False holds the turn still.
var turning := true
var _spin: Node3D
var _halo: MeshInstance3D
var _ring: MeshInstance3D
var _glow_materials: Array[ShaderMaterial] = []
var _night := 0.0

static var _paints := {}
static var _coins := {}

## A holder for part `part_id`, `part_size` m across, as a "coin" or a
## "piece".
static func part(part_id: String, part_size := 1.0, part_style := "coin", bob_phase := 0.0) -> Node3D:
	var holder: Node3D = new()
	holder._build(part_id,part_size,part_style,bob_phase)
	return holder

func _build(part_id: String, part_size: float, part_style: String, bob_phase: float) -> void:
	id = part_id
	size = part_size
	style = part_style
	phase = bob_phase
	name = "Part_%s_%s" % [id,style]
	_spin = Node3D.new()
	_spin.name = "Spin"
	_spin.rotation.y = START
	add_child(_spin)
	if style == "piece": _spin.add_child(_piece())
	else: _spin.add_child(_coin())
	_halo = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE*size*2.0
	_halo.mesh = quad
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var halo_material := ShaderMaterial.new()
	halo_material.shader = HALO_SHADER
	halo_material.set_shader_parameter("tint",WARM)
	_halo.material_override = halo_material
	add_child(_halo)
	_ring = MeshInstance3D.new()
	var mark := QuadMesh.new()
	mark.size = Vector2.ONE*size*1.5
	mark.orientation = PlaneMesh.FACE_Y
	_ring.mesh = mark
	_ring.position = Vector3(0.0,-size*0.72,0.0)
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring_material := StandardMaterial3D.new()
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.albedo_texture = FacetMesh.soft_ring()
	ring_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring_material.no_depth_test = false
	_ring.material_override = ring_material
	add_child(_ring)
	add_child(_motes())
	glow_for(0.0)

## The turning part.
func spin() -> Node3D:
	return _spin

## Lit for the world's `night` (0 by day, 1 at full night): a soft
## lantern after dark.
func glow_for(night: float) -> void:
	_night = night
	var glow := lerpf(COIN_GLOW.x,COIN_GLOW.y,night) if style == "coin" else lerpf(PIECE_GLOW.x,PIECE_GLOW.y,night)
	for m in _glow_materials:
		m.set_shader_parameter("glow",glow)
		m.set_shader_parameter("inner",INNER_NIGHT*night)
	(_halo.material_override as ShaderMaterial).set_shader_parameter("strength",lerpf(HALO.x,HALO.y,night))

func _process(delta: float) -> void:
	var t := Time.get_ticks_msec()/1000.0
	if turning: _spin.rotation.y += TURN*delta
	_spin.position.y = sin(t*BOB_PACE+phase)*BOB*size
	var ring := lerpf(RING_GLOW.x,RING_GLOW.y,_night)*(0.8+0.2*sin(t*1.7+phase))
	(_ring.material_override as StandardMaterial3D).albedo_color = Color(WARM.r,WARM.g,WARM.b,ring)

# --- The piece -----------------------------------------------------------------------

## The plane's paints, made once for every part.
static func _paint(paint: String) -> Material:
	if _paints.is_empty(): _paints = PlaneFigure.paints()
	return _paints[paint]

## The part's pieces as [mesh, paint, transform], moved by their offsets.
static func _parts_of(part_id: String) -> Array:
	var out := []
	for p: Array in PARTS[part_id].pieces:
		for q: Array in PlaneFigure.piece(p[0]):
			out.append([q[0],q[1],Transform3D(Basis.IDENTITY,p[1])*(q[2] as Transform3D)])
	return out

## The hovering piece: the plane's own meshes in its own paint, posed,
## centred and scaled so its longest side is `size`, the warm glow over
## every part.
func _piece() -> Node3D:
	var parts := _parts_of(id)
	var bounds := AABB()
	for i in range(parts.size()):
		var box: AABB = (parts[i][2] as Transform3D)*(parts[i][0] as Mesh).get_aabb()
		bounds = box if i == 0 else bounds.merge(box)
	var model := Node3D.new()
	model.name = "Piece"
	model.basis = Basis.from_euler(PARTS[id].pose)*Basis.from_scale(Vector3.ONE*size/maxf(bounds.size[bounds.get_longest_axis_index()],0.001))
	var glow := ShaderMaterial.new()
	glow.shader = GLOW_SHADER
	glow.set_shader_parameter("tint",WARM)
	glow.set_shader_parameter("reach",size)
	_glow_materials.append(glow)
	for p: Array in parts:
		var mesh := MeshInstance3D.new()
		mesh.mesh = p[0]
		mesh.material_override = _paint(p[1])
		mesh.material_overlay = glow
		mesh.transform = Transform3D(Basis.IDENTITY,-bounds.get_center())*(p[2] as Transform3D)
		if p[1] == "glass": mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		model.add_child(mesh)
	return model

# --- The coin ------------------------------------------------------------------------

## The coin, `size` m across, lit as the glyph tokens are, the piece's flat
## drawing laid over its relief.
func _coin() -> MeshInstance3D:
	var made: Array = _coin_for(id)
	var node := MeshInstance3D.new()
	node.name = "Coin"
	node.mesh = made[0]
	node.scale = Vector3.ONE*size/(2.0*R)
	var material := ShaderMaterial.new()
	material.shader = TOKEN_SHADER
	material.set_shader_parameter("lines",made[1])
	material.set_shader_parameter("glow_tint",WARM)
	node.material_override = material
	_glow_materials.append(material)
	return node

## [mesh, drawing] for a part's coin, made once.
static func _coin_for(part_id: String) -> Array:
	if _coins.has(part_id): return _coins[part_id]
	var flat := _draw_flat(part_id)
	var colours: Image = flat[0]
	var outlines := _trace(flat[1])
	var outers: Array[PackedVector2Array] = []
	var holes: Array[PackedVector2Array] = []
	for p in outlines:
		var inside := false
		for q in outlines:
			if q != p and Geometry2D.is_point_in_polygon(p[0],q): inside = true
		if inside: holes.append(p)
		else: outers.append(p)
	var st := {"v":PackedVector3Array(),"n":PackedVector3Array(),"c":PackedColorArray(),"uv":PackedVector2Array()}
	var face := PackedVector2Array()
	for i in range(SIDES):
		var a := TAU*(i+0.5)/SIDES
		face.append(Vector2(cos(a),sin(a))*FACE_R)
	var facets := _facets(hash(part_id))
	for side: float in [1.0,-1.0]:
		# The face: the facet grid clipped to it, domed a little, each
		# facet a shade off the next.
		for facet: Array in facets:
			for piece: PackedVector2Array in Geometry2D.intersect_polygons(facet[0],face):
				_fill(st,piece,side,func(p: Vector2) -> float: return _face_z(p),FACE.lerp(Color.WHITE if facet[1] > 0.0 else Color("1d3346"),absf(facet[1])),false)
		# The relief: the same grid clipped to the piece's silhouette,
		# swelling inward from its outline, its paint drawn over it.
		for facet: Array in facets:
			var pieces: Array = []
			for o in outers: pieces.append_array(Geometry2D.intersect_polygons(facet[0],o))
			for h in holes:
				var kept: Array = []
				for piece: PackedVector2Array in pieces: kept.append_array(Geometry2D.clip_polygons(piece,h))
				pieces = kept
			for piece: PackedVector2Array in pieces:
				if Geometry2D.is_polygon_clockwise(piece) != Geometry2D.is_polygon_clockwise(facet[0]): continue
				_fill(st,piece,side,func(p: Vector2) -> float: return _face_z(p)+RELIEF+SWELL*_swell(p,outlines),Color.WHITE,true)
		# The relief's walls, in its paint in shade.
		for p in outlines:
			for i in range(p.size()):
				var a := p[i]
				var b := p[(i+1)%p.size()]
				var mid := (a+b)*0.5
				var out := Vector2(b.y-a.y,a.x-b.x).normalized()
				if _inside(mid+out*0.05,outers,holes): out = -out
				var colour := _sample(colours,mid-out*0.15).darkened(0.3)
				var a0 := Vector3(a.x,a.y,side*(_face_z(a)-0.05))
				var b0 := Vector3(b.x,b.y,side*(_face_z(b)-0.05))
				var a1 := Vector3(a.x,a.y,side*(_face_z(a)+RELIEF))
				var b1 := Vector3(b.x,b.y,side*(_face_z(b)+RELIEF))
				var toward := Vector3(out.x,out.y,0.0)
				_tri(st,[a0,b0,b1],toward,colour,[])
				_tri(st,[a0,b1,a1],toward,colour,[])
		# The bevel from the face's edge out to the rim.
		for i in range(SIDES):
			var p0 := face[i]
			var p1 := face[(i+1)%SIDES]
			var q0 := p0/FACE_R*R
			var q1 := p1/FACE_R*R
			var f0 := Vector3(p0.x,p0.y,side*FACE_T)
			var f1 := Vector3(p1.x,p1.y,side*FACE_T)
			var r0 := Vector3(q0.x,q0.y,side*RIM_T)
			var r1 := Vector3(q1.x,q1.y,side*RIM_T)
			var mid := (p0+p1).normalized()
			var toward := Vector3(mid.x,mid.y,side*1.2)
			_tri(st,[f0,r0,r1],toward,RIM_BRASS.lightened(0.08),[])
			_tri(st,[f0,r1,f1],toward,RIM_BRASS.lightened(0.08),[])
	# The rim's edge, round between the two bevels.
	for i in range(SIDES):
		var a := TAU*(i+0.5)/SIDES
		var b := TAU*(i+1.5)/SIDES
		var q0 := Vector2(cos(a),sin(a))*R
		var q1 := Vector2(cos(b),sin(b))*R
		var mid := (q0+q1).normalized()
		var toward := Vector3(mid.x,mid.y,0.0)
		var colour := RIM_BRASS.darkened(0.12)
		_tri(st,[Vector3(q0.x,q0.y,RIM_T),Vector3(q1.x,q1.y,RIM_T),Vector3(q1.x,q1.y,-RIM_T)],toward,colour,[])
		_tri(st,[Vector3(q0.x,q0.y,RIM_T),Vector3(q1.x,q1.y,-RIM_T),Vector3(q0.x,q0.y,-RIM_T)],toward,colour,[])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = st.v
	arrays[Mesh.ARRAY_NORMAL] = st.n
	arrays[Mesh.ARRAY_COLOR] = st.c
	arrays[Mesh.ARRAY_TEX_UV] = st.uv
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	colours.generate_mipmaps()
	_coins[part_id] = [mesh,ImageTexture.create_from_image(colours)]
	return _coins[part_id]

## The face's height `p` from the middle (token units), domed.
static func _face_z(p: Vector2) -> float:
	return FACE_T+DOME*(1.0-minf(p.length_squared()/(FACE_R*FACE_R),1.0))

## A flat polygon triangulated onto the coin's `side`, its heights from
## `height`, in `colour`; `drawn` lays the piece's drawing over it.
static func _fill(st: Dictionary, piece: PackedVector2Array, side: float, height: Callable, colour: Color, drawn: bool) -> void:
	var tris := Geometry2D.triangulate_polygon(piece)
	for t in range(0,tris.size(),3):
		var flat := [piece[tris[t]],piece[tris[t+1]],piece[tris[t+2]]]
		var points := []
		for p: Vector2 in flat: points.append(Vector3(p.x,p.y,side*float(height.call(p))))
		_tri(st,points,Vector3(0.0,0.0,side),colour,flat if drawn else [])

## The jittered facet grid over the coin: [triangle, lean] with the lean
## -1..1 to shade it lighter or darker a touch.
static func _facets(seed_value: int) -> Array:
	var s := absi(seed_value)%233280
	var step := 2.0*R/GRID
	var grid: Array[Vector2] = []
	for y in range(GRID+1):
		for x in range(GRID+1):
			var j := Vector2.ZERO
			if not (x == 0 or y == 0 or x == GRID or y == GRID):
				s = (s*9301+49297)%233280
				j.x = (s/233280.0-0.5)*step*0.7
				s = (s*9301+49297)%233280
				j.y = (s/233280.0-0.5)*step*0.7
			grid.append(Vector2(-R+x*step,-R+y*step)+j)
	var out := []
	for y in range(GRID):
		for x in range(GRID):
			var a := grid[y*(GRID+1)+x]
			var b := grid[y*(GRID+1)+x+1]
			var c := grid[(y+1)*(GRID+1)+x]
			var d := grid[(y+1)*(GRID+1)+x+1]
			for q: Array in ([[a,b,d],[a,d,c]] if (x+y)%2 == 1 else [[a,b,c],[b,d,c]]):
				s = (s*9301+49297)%233280
				var centre: Vector2 = (q[0]+q[1]+q[2])/3.0
				var lean := clampf((centre.y-centre.x)/(R*6.0)+(s/233280.0-0.5)*0.12,-0.2,0.2)
				out.append([PackedVector2Array(q),lean])
	return out

## The part drawn flat from its coin view, fitted inside REACH: [the
## colours (RES square, each pixel the nearest face's paint shaded by
## FLAT_LIGHT, spread a few pixels past the edge), the coverage mask].
## Pixel (0, 0) is the coin's top left, (RES, RES) its bottom right.
static func _draw_flat(part_id: String) -> Array:
	var spec: Dictionary = PARTS[part_id]
	var w: Vector3 = (spec.view as Vector3).normalized()
	var u: Vector3 = (spec.up as Vector3).cross(w).normalized()
	var v := w.cross(u)
	var roll := float(spec.roll)
	var light := FLAT_LIGHT.normalized()
	var tris := []
	var low := Vector2(INF,INF)
	var high := -low
	for p: Array in _parts_of(part_id):
		var mesh: Mesh = p[0]
		var placed: Transform3D = p[2]
		var turn := placed.basis.inverse().transposed()
		var arrays := mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: Variant = arrays[Mesh.ARRAY_INDEX]
		var order: Array = Array(indices) if indices is PackedInt32Array and (indices as PackedInt32Array).size() > 0 else range(vertices.size())
		var base: Color = PlaneFigure.PAINT_COLOURS[p[1]]
		for t in range(0,order.size(),3):
			var corners := []
			var normal := Vector3.ZERO
			for k in range(3):
				var at := placed*vertices[order[t+k]]
				var flat := Vector2(at.dot(u),at.dot(v)).rotated(roll)
				corners.append(Vector3(flat.x,flat.y,at.dot(w)))
				low = low.min(flat)
				high = high.max(flat)
				normal += (turn*normals[order[t+k]]).normalized()
			var n2 := Vector2(normal.dot(u),normal.dot(v)).rotated(roll)
			var seen := Vector3(n2.x,n2.y,normal.dot(w)).normalized()
			var shade := 0.68+0.42*maxf(seen.dot(light),0.0)
			tris.append([corners,Color(base.r*shade,base.g*shade,base.b*shade)])
	var centre := (low+high)*0.5
	var radius := 0.0
	for t: Array in tris:
		for c: Vector3 in t[0]: radius = maxf(radius,Vector2(c.x,c.y).distance_to(centre))
	var fit := REACH/maxf(radius,1e-6)
	var image := Image.create(RES,RES,false,Image.FORMAT_RGBA8)
	var mask := Image.create(RES,RES,false,Image.FORMAT_LA8)
	var depth := PackedFloat32Array()
	depth.resize(RES*RES)
	depth.fill(-INF)
	for t: Array in tris:
		var pts: Array[Vector3] = []
		for c: Vector3 in t[0]: pts.append(Vector3(_px((c.x-centre.x)*fit),_px(-(c.y-centre.y)*fit),c.z))
		var area := (pts[1].x-pts[0].x)*(pts[2].y-pts[0].y)-(pts[2].x-pts[0].x)*(pts[1].y-pts[0].y)
		if absf(area) < 1e-9: continue
		var x0 := maxi(int(floor(minf(pts[0].x,minf(pts[1].x,pts[2].x)))),0)
		var x1 := mini(int(ceil(maxf(pts[0].x,maxf(pts[1].x,pts[2].x)))),RES-1)
		var y0 := maxi(int(floor(minf(pts[0].y,minf(pts[1].y,pts[2].y)))),0)
		var y1 := mini(int(ceil(maxf(pts[0].y,maxf(pts[1].y,pts[2].y)))),RES-1)
		for y in range(y0,y1+1):
			for x in range(x0,x1+1):
				var px := x+0.5
				var py := y+0.5
				var b0 := ((pts[1].x-px)*(pts[2].y-py)-(pts[2].x-px)*(pts[1].y-py))/area
				var b1 := ((pts[2].x-px)*(pts[0].y-py)-(pts[0].x-px)*(pts[2].y-py))/area
				var b2 := 1.0-b0-b1
				if b0 < -0.02 or b1 < -0.02 or b2 < -0.02: continue
				var z := b0*pts[0].z+b1*pts[1].z+b2*pts[2].z
				if z <= depth[y*RES+x]: continue
				depth[y*RES+x] = z
				image.set_pixel(x,y,t[1])
				mask.set_pixel(x,y,Color(1.0,1.0,1.0,1.0))
	# Spread the colours a few pixels past the edge, so the relief's rim
	# never samples the clear outside.
	for _pass in range(3):
		var grown := image.duplicate() as Image
		for y in range(RES):
			for x in range(RES):
				if image.get_pixel(x,y).a > 0.0: continue
				for o: Vector2i in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
					var q := Vector2i(x,y)+o
					if q.x < 0 or q.y < 0 or q.x >= RES or q.y >= RES: continue
					var c := image.get_pixelv(q)
					if c.a > 0.0:
						grown.set_pixel(x,y,c)
						break
		image = grown
	return [image,mask]

## Token units across the coin (-R..R) to the drawing's pixels.
static func _px(t: float) -> float:
	return (t/R*0.5+0.5)*RES

## The drawing's colour at `p` (token units, y up).
static func _sample(image: Image, p: Vector2) -> Color:
	var x := clampi(int(_px(p.x)),0,RES-1)
	var y := clampi(int(_px(-p.y)),0,RES-1)
	var c := image.get_pixel(x,y)
	return c if c.a > 0.0 else FACE

## The silhouette's outlines in token units (y up), traced from the mask.
static func _trace(mask: Image) -> Array[PackedVector2Array]:
	var bits := BitMap.new()
	bits.create_from_image_alpha(mask,0.5)
	bits.grow_mask(1,Rect2i(Vector2i.ZERO,mask.get_size()))
	var out: Array[PackedVector2Array] = []
	for p: PackedVector2Array in bits.opaque_to_polygons(Rect2i(Vector2i.ZERO,mask.get_size()),1.2):
		if p.size() < 3: continue
		var units := PackedVector2Array()
		for q in p: units.append(Vector2((q.x/RES-0.5)*2.0*R,-(q.y/RES-0.5)*2.0*R))
		var area := 0.0
		for i in range(units.size()): area += units[i].cross(units[(i+1)%units.size()])
		if absf(area) > 0.1: out.append(units)
	return out

## 0 on the outline rising to 1 SWELL_REACH in.
static func _swell(p: Vector2, outlines: Array[PackedVector2Array]) -> float:
	var best := INF
	for o in outlines:
		for i in range(o.size()):
			best = minf(best,p.distance_squared_to(Geometry2D.get_closest_point_to_segment(p,o[i],o[(i+1)%o.size()])))
	return smoothstep(0.0,SWELL_REACH,sqrt(best))

static func _inside(p: Vector2, outers: Array[PackedVector2Array], holes: Array[PackedVector2Array]) -> bool:
	for h in holes:
		if Geometry2D.is_point_in_polygon(p,h): return false
	for o in outers:
		if Geometry2D.is_point_in_polygon(p,o): return true
	return false

## A flat-shaded triangle wound to face `toward`; `flat` (token units)
## gives its drawing's UVs, or none (the shader keeps the vertex colour).
static func _tri(st: Dictionary, points: Array, toward: Vector3, colour: Color, flat: Array) -> void:
	var a: Vector3 = points[0]
	var b: Vector3 = points[1]
	var d: Vector3 = points[2]
	var normal := (d-a).cross(b-a).normalized()
	if normal == Vector3.ZERO: return
	var order := [0,1,2]
	if normal.dot(toward) < 0.0:
		normal = -normal
		order = [0,2,1]
	for k: int in order:
		st.v.append(points[k])
		st.n.append(normal)
		st.c.append(colour)
		if flat.is_empty(): st.uv.append(Vector2(-99.0,-99.0))
		else: st.uv.append(Vector2(_px(flat[k].x),_px(-flat[k].y))/RES)

# --- The motes -----------------------------------------------------------------------

## A few warm motes drifting up round it.
func _motes() -> CPUParticles3D:
	var motes := CPUParticles3D.new()
	motes.amount = 10
	motes.lifetime = 2.6
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	motes.emission_sphere_radius = size*0.55
	motes.direction = Vector3.UP
	motes.spread = 30.0
	motes.gravity = Vector3(0.0,0.06,0.0)
	motes.initial_velocity_min = 0.05
	motes.initial_velocity_max = 0.15
	var mote := SphereMesh.new()
	mote.radius = 0.018*size
	mote.height = 0.036*size
	mote.radial_segments = 4
	mote.rings = 2
	var mote_material := StandardMaterial3D.new()
	mote_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mote_material.albedo_color = WARM.lightened(0.3)
	mote_material.emission_enabled = true
	mote_material.emission = mote_material.albedo_color
	mote_material.emission_energy_multiplier = 2.0
	mote.material = mote_material
	motes.mesh = mote
	var fade := Curve.new()
	fade.add_point(Vector2(0.0,0.0))
	fade.add_point(Vector2(0.2,1.0))
	fade.add_point(Vector2(1.0,0.0))
	motes.scale_amount_curve = fade
	return motes
