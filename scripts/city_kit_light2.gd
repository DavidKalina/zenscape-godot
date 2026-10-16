extends RefCounted
## The Olmec city kit's relief face (oc_relief), from the light pieces'
## round 2 (its sun-mirror, light shaft and sun plaque are gone): a cliff
## carved as one seated lord that the two bodies climb their own ways. In
## the city's stone (scripts/city_kit_stone.gd).
##
##   oc_relief       `relief`: a cliff `width` m wide, TOP m tall, `deep` m
##                   back, its face carved as one seated lord in profile
##                   (the Blender model art/blender/city_relief/
##                   relief_build.py, assets/models/city_relief.glb, its
##                   baked maps projected by one Decal). The wanderer jump-
##                   catches the carving's deep bosses, a SET_OFF apart, up
##                   the nose side (clean walker-only boxes); the Olmec climbs
##                   the cliff's plain collision, and at the top his hands
##                   come over the helmet's crown, the cliff's lip.
##
## Register in a kit registry with `PIECES` (id -> what it is) and `build`.
const CityStone = preload("res://scripts/city_kit_stone.gd")
const Fires = preload("res://scripts/city_kit_fires.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const Style = preload("res://scripts/ruin_stone_style.gd")
const GroundCover = preload("res://scripts/underground/ground_cover.gd")
const RELIEF_MODEL := "res://assets/models/city_relief.glb"
const RELIEF_NORMAL := "res://assets/textures/city_relief_normal.png"
const RELIEF_CAVITY := "res://assets/textures/city_relief_cavity.png"

const PIECES := {
	"oc_relief":"Relief face: a cliff carved as a seated lord; you jump-catch his carving's bosses, the Olmec climbs the stone",
}

## The visual layer only the relief's mesh is on, which its Decal projects onto.
const RELIEF_LAYER := 1 << 19

static func size() -> float:
	return WorldScale.wanderer

static func set_off() -> float:
	return RuinKit.SET_OFF*size()

## Piece `id` (PIECES) stood in `parent` at `xform`, `opts` its own.
static func build(id: String, parent: Node3D, xform: Transform3D, opts := {}) -> Node3D:
	match id:
		"oc_relief": return relief(parent,xform,opts)
	push_error("city light2: no piece '%s'" % id)
	return null

# --- Helpers --------------------------------------------------------------------------------

static func _mesh_node(parent: Node3D, m: CityStone.Mesher, node_name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = CityStone.mesh_of(m)
	parent.add_child(mi)
	return mi

static func _stone() -> CityStone.Mesher:
	return CityStone.Mesher.new(CityStone.stone_colour(),0.25)

static func _box(m: CityStone.Mesher, at: Vector3, sz: Vector3, bevel := 0.06, turn := 0.0, tone := 1.0) -> void:
	m.solid(CityStone.box(Transform3D(Basis(Vector3.UP,turn),at),sz*0.5,bevel),NAN,tone)

static func _body(parent: Node3D, shapes: Array, node_name: String, walker := false) -> StaticBody3D:
	return Fires.solid(parent,shapes,walker,node_name)

# --- The relief face ------------------------------------------------------------------------

## A relief cliff in `parent` at `xform` (its foot's middle, on the wall
## plane the bodies collide with; the carving faces local +z). opts:
## "width" (m, 40: the cliff; the carving is 14), "deep" (m, 24: the top's
## depth back from the face), "seed", "cover" (true: the ground cover on
## its top).
static func relief(parent: Node3D, xform: Transform3D, opts := {}) -> Relief:
	var r := Relief.new()
	r.name = str(opts.get("name","Relief"))
	r.transform = xform
	r.width = float(opts.get("width",40.0))
	r.deep = float(opts.get("deep",24.0))
	r.seed_value = int(opts.get("seed",hash(xform.origin)))
	r.cover = bool(opts.get("cover",true))
	parent.add_child(r)
	r.stand_up()
	return r

class Relief extends Node3D:
	const Kit = preload("res://scripts/city_kit_light2.gd")
	var width := 40.0
	var deep := 24.0
	var seed_value := 0
	var cover := true
	## As authored (m at his size 1): the cliff's top, the carving's width,
	## where the wall the bodies collide with stands out of the carved field.
	var top := 17.6
	var panel := 14.0
	var collide_z := 0.5
	## The holds: [{"name", "box": AABB (in this node's space, scaled)}], foot first.
	var holds: Array = []
	var carving: MeshInstance3D
	var decal: Decal
	var triangles := 0

	## The local frame: the carving's own, scaled by his size; the wall
	## plane the bodies collide with is z = 0 here (the carved field is
	## behind it).
	func stand_up() -> void:
		var k := Kit.size()
		var model: Node3D = (load(RELIEF_MODEL) as PackedScene).instantiate()
		var wall := model.get_node_or_null("Wall") as Node3D
		if wall != null:
			top = wall.position.y
			collide_z = wall.position.z
			panel = wall.scale.x
		var src := model.get_node("Relief") as MeshInstance3D
		var art := Node3D.new()
		art.name = "Carving"
		art.scale = Vector3.ONE*k
		art.position = Vector3(0.0,0.0,-collide_z*k)
		add_child(art)
		carving = MeshInstance3D.new()
		carving.name = "Relief"
		carving.mesh = Kit._dressed_relief(src.mesh,CityStone.stone_colour())
		if CityStone._stone == null: CityStone.warm()
		carving.material_override = CityStone._stone
		carving.layers = 1 | RELIEF_LAYER
		art.add_child(carving)
		triangles = 0
		for s in carving.mesh.get_surface_count():
			triangles += (carving.mesh as ArrayMesh).surface_get_array_index_len(s)/3 if (carving.mesh as ArrayMesh).surface_get_array_index_len(s) > 0 else (carving.mesh as ArrayMesh).surface_get_array_len(s)/3
		# The baked maps, projected straight into the wall by one Decal (the
		# carving's layer only: not the wanderer, not the Olmec).
		decal = Decal.new()
		decal.name = "Bake"
		decal.texture_albedo = load(RELIEF_CAVITY)
		decal.texture_normal = load(RELIEF_NORMAL)
		decal.cull_mask = RELIEF_LAYER
		decal.size = Vector3(panel,3.0,top)
		decal.albedo_mix = 1.0
		decal.normal_fade = 0.35
		decal.distance_fade_enabled = true
		decal.distance_fade_begin = 70.0
		decal.distance_fade_length = 30.0
		# Its -y (the way it projects) into the wall; its +z (the map's
		# down) down the wall.
		decal.transform = Transform3D(Basis(Vector3.RIGHT,PI*0.5),Vector3(0.0,top*0.5,0.0))
		art.add_child(decal)
		# The holds: clean walker-only boxes (he never reads them).
		holds.clear()
		var shapes: Array = []
		for n: Node in model.get_children():
			if not n.name.begins_with("Hold_"): continue
			var e := n as Node3D
			var sz := e.scale*k
			var at := (e.position-Vector3(0.0,0.0,collide_z))*k
			holds.append({"name":str(n.name).substr(8),"box":AABB(at-sz*0.5,sz)})
			shapes.append(Fires.box_shape(sz,at))
		holds.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a.box as AABB).end.y < (b.box as AABB).end.y)
		Kit._body(self,shapes,"Holds",true)
		model.free()
		# The cliff: its stone either side of the carving and behind it, a
		# capping course over the carving's top (the helmet's crown, the lip
		# his hands come over); collided as one block, its face z = 0.
		var h := top*k
		var w := width*k
		var d := deep*k
		var pw := panel*k
		var m := Kit._stone()
		var side := (w-pw)*0.5
		for s: float in [-1.0,1.0]:
			Kit._box(m,Vector3(s*(pw*0.5+side*0.5),h*0.5,-d*0.5),Vector3(side,h,d),0.25*k)
		Kit._box(m,Vector3(0.0,h*0.5,-d*0.5-collide_z*k*0.5-0.05),Vector3(pw+0.2,h,d-collide_z*k-0.1),0.0,0.0,0.85)
		Kit._box(m,Vector3(0.0,h-0.2*k,-0.05*k),Vector3(pw+0.4*k,0.4*k,0.5*k),0.1*k,0.0,1.05)
		# Courses on the flanks: a band every few set-offs, so the cliff reads
		# as cut stone and the carving as its panel.
		var course := Kit.set_off()*3.0
		var y := course
		while y < h-0.5:
			for s: float in [-1.0,1.0]:
				Kit._box(m,Vector3(s*(pw*0.5+side*0.5),y,0.02*k),Vector3(side-0.6*k,0.18*k,0.12*k),0.03*k,0.0,0.8)
			y += course
		Kit._mesh_node(self,m,"Cliff")
		Kit._body(self,[Fires.box_shape(Vector3(w,h,d),Vector3(0.0,h*0.5,-d*0.5))],"CliffBody")
		if cover:
			GroundCover.cover(self,Rect2(-w*0.5+0.4,-d+0.4,w-0.8,d-0.6),"",h+0.002,seed_value,{"tufts":0.6,"fade":0.6})

	## The holds' tops (world), foot first: where he stands on each.
	func hold_tops() -> Array:
		var out: Array = []
		for hd: Dictionary in holds:
			var b: AABB = hd.box
			out.append(to_global(Vector3(b.get_center().x,b.end.y,b.get_center().z)))
		return out

	## The lip (world, its middle).
	func lip() -> Vector3:
		return to_global(Vector3(0.0,top*Kit.size(),0.0))

## The relief's low mesh dressed as the kit's stone: each vertex shaded as
## the kit shades a face (Style.shade), darkened by the occlusion baked in
## its colour's R, its worn high points (G) and the holds' polished lips (B)
## a little paler, moss on what faces up; rest place in UV/UV2 for the
## weathering grain. LODs made again (an ImporterMesh).
static func _dressed_relief(mesh: Mesh, stone: Color) -> ArrayMesh:
	var out := ImporterMesh.new()
	var noise := FastNoiseLite.new()
	noise.seed = 31
	noise.frequency = 0.5
	var moss := CityStone.MOSS.srgb_to_linear()
	var moss_light := CityStone.MOSS_LIGHT.srgb_to_linear()
	for s in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var baked: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		var colours := PackedColorArray()
		colours.resize(verts.size())
		var ra := PackedVector2Array()
		var rb := PackedVector2Array()
		ra.resize(verts.size())
		rb.resize(verts.size())
		for i in verts.size():
			var p := verts[i]
			var n := normals[i]
			var c := Style.shade(stone,Vector3(0.0,9.0,-2.0),p,n,1.0)
			var ao := 1.0
			var convex := 0.5
			var polish := 0.0
			if baked.size() == verts.size():
				ao = baked[i].r
				convex = baked[i].g
				polish = baked[i].b
			var occ := pow(clampf(ao,0.0,1.0),0.85)
			c = c*lerpf(0.88,1.14,convex)
			c = c.lerp(c*1.35,polish*0.55)
			var up := smoothstep(0.62,0.95,n.y)
			if up > 0.0:
				var patch := clampf(noise.get_noise_3dv(p)*1.1+0.35,0.0,1.0)
				var tone := moss.lerp(moss_light,clampf(noise.get_noise_3dv(p*3.0)+0.5,0.0,1.0))
				c = c.lerp(tone,up*patch*0.55*occ*(1.0-polish))
			c = c*lerpf(CityStone.AO_FLOOR,1.0,occ)
			c.a = occ
			colours[i] = c
			var rest := p*CityStone.GRAIN
			ra[i] = Vector2(rest.x,rest.y)
			rb[i] = Vector2(rest.z,0.0)
		arrays[Mesh.ARRAY_COLOR] = colours
		arrays[Mesh.ARRAY_TEX_UV] = ra
		arrays[Mesh.ARRAY_TEX_UV2] = rb
		out.add_surface(Mesh.PRIMITIVE_TRIANGLES,arrays)
	out.generate_lods(60.0,25.0,[])
	return out.get_mesh()
