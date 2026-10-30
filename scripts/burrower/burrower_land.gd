extends Node3D
## The burrower study's slice of land (docs/design/endless-flight/spec-burrower.md):
## a meadow some 360 m across in a bowl of low hills, the game's carpet
## grass on it (KitFlora's tufts as the endless land grows them), a pond,
## a steep knoll, scattered boulders, a ruin stub and a few trees. Greybox
## where the game's pieces don't lift out cheaply.
##
## Everything the trail will steer round is listed: `rocks` and `ruins`
## (xz centre, reach), `trees` (their nodes, to shudder), `knoll`, `pond`.
## The stone and the trunks are static bodies on RuinBump.LAYER, so the
## plane glances off them as off the game's ruins.

const RuinBump = preload("res://scripts/ruin_bump.gd")
const Carpet = preload("res://scripts/shared/aqueduct_isle_flora.gd")
const EndlessGrass = preload("res://scripts/endless/endless_grass.gd")
const SkyIslets = preload("res://scripts/sky_islets.gd")

## The land's square (m a side, centred on the origin) and its grid step.
const SIZE := 840.0
const STEP := 2.0
## The meadow's flat middle (m from the centre) and where the hills begin
## to rise round it to HILLS m.
const MEADOW_R := 255.0
const HILLS_R := 380.0
const HILLS := 34.0
## The pond: its middle, its radius at the water's edge, its depth.
const POND := Vector2(85.0,-55.0)
const POND_R := 34.0
const POND_DEEP := 3.8
const WATER_Y := -0.45
const POND_SHADER = preload("res://shaders/burrower_pond.gdshader")
## The pond's water (shaders/burrower_pond.gdshader): the burrower sets its wake.
var pond_material: ShaderMaterial
## The steep knoll: its middle, its foot's radius, its height.
const KNOLL := Vector2(-95.0,-85.0)
const KNOLL_R := 30.0
const KNOLL_UP := 9.0

const GROUND_LOW := Color("466b30")
const GROUND_HIGH := Color("6b7a45")
const ROCK := Color("8a8478")
const MUD := Color("5a4a36")
const BARK := Color("4a3a2a")
const LEAF := Color("3f6b2c")
const STONE := Color("a39a88")
## The grass grows in squares this big, at once on the workers.
const GRASS_CELL := 48.0
## Bumped when the land or the grow changes, so the kept grass is grown again.
const GRASS_VERSION := 5
## The grass thins out over the meadow's last this many m.
const RIM_SOFT := 35.0

var rocks: Array = []
var ruins: Array = []
var trees: Array = []
var _roll := FastNoiseLite.new()
var _hill := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()
var grass_tufts := 0

func _init() -> void:
	name = "Land"
	_roll.seed = 7
	_roll.frequency = 1.0/70.0
	_roll.fractal_octaves = 3
	_hill.seed = 11
	_hill.frequency = 1.0/140.0
	_rng.seed = 23

## The land's height at (x, z), the pond's bed included (not its water).
func height(x: float, z: float) -> float:
	var p := Vector2(x,z)
	var r := p.length()
	var h := 1.2+_roll.get_noise_2d(x,z)*0.9
	h += smoothstep(MEADOW_R,HILLS_R,r)*HILLS*(0.75+0.5*_hill.get_noise_2d(x,z))
	var k := p.distance_to(KNOLL)
	h += KNOLL_UP*smoothstep(KNOLL_R,KNOLL_R*0.35,k)
	var d := p.distance_to(POND)
	h -= POND_DEEP*smoothstep(POND_R*1.25,POND_R*0.55,d)
	return h

## Whether (x, z) is under the pond's water.
func wet(x: float, z: float) -> bool:
	return height(x,z) < WATER_Y

## The ground's normal at (x, z).
func normal(x: float, z: float) -> Vector3:
	var e := 0.75
	return Vector3(height(x-e,z)-height(x+e,z),2.0*e,height(x,z-e)-height(x,z+e)).normalized()

## The ground's colour (sRGB, as its vertices have it) at (x, z), of height
## `y` and normal `nm` there.
func colour(x: float, z: float, y: float, nm: Vector3) -> Color:
	var c := GROUND_LOW.lerp(GROUND_HIGH,clampf(y/HILLS,0.0,1.0))
	c = c.lerp(ROCK,smoothstep(0.82,0.68,nm.y))
	c = c.lerp(MUD,smoothstep(WATER_Y+0.4,WATER_Y-0.2,y))
	return c.lerp(c*0.85,0.5+0.5*_roll.get_noise_2d(x*3.0,z*3.0))

## The ground mesh's own height at (x, z): its STEP grid's triangles, as
## drawn (not the noise between them), for things laid on it.
func mesh_height(x: float, z: float) -> float:
	var half := SIZE*0.5
	var u := clampf((x+half)/STEP,0.0,SIZE/STEP-0.001)
	var v := clampf((z+half)/STEP,0.0,SIZE/STEP-0.001)
	var i := floorf(u)
	var j := floorf(v)
	var fu := u-i
	var fv := v-j
	var x0 := -half+i*STEP
	var z0 := -half+j*STEP
	var h10 := height(x0+STEP,z0)
	var h01 := height(x0,z0+STEP)
	if fu+fv <= 1.0:
		var h00 := height(x0,z0)
		return h00+fu*(h10-h00)+fv*(h01-h00)
	var h11 := height(x0+STEP,z0+STEP)
	return h11+(1.0-fu)*(h01-h11)+(1.0-fv)*(h10-h11)

## The plane's ground (SkyGlide `step`): the land's height under it.
func ground(p: Vector3) -> Variant:
	return height(p.x,p.z)

func build(grass_share := 1.0) -> void:
	var t := Time.get_ticks_msec()
	_build_ground()
	var t_ground := Time.get_ticks_msec()-t
	_build_water()
	_build_rocks()
	_build_ruin()
	_build_trees()
	t = Time.get_ticks_msec()
	if grass_share > 0.0: _build_grass(grass_share)
	print("burrower land: ground %d ms, grass %d ms" % [t_ground,Time.get_ticks_msec()-t])

func _build_ground() -> void:
	var n := int(SIZE/STEP)+1
	var half := SIZE*0.5
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	verts.resize(n*n)
	normals.resize(n*n)
	colours.resize(n*n)
	for j in n:
		for i in n:
			var x := -half+i*STEP
			var z := -half+j*STEP
			var y := height(x,z)
			var nm := normal(x,z)
			var k := j*n+i
			verts[k] = Vector3(x,y,z)
			normals[k] = nm
			colours[k] = colour(x,z,y,nm)
	var index := PackedInt32Array()
	index.resize((n-1)*(n-1)*6)
	var o := 0
	for j in n-1:
		for i in n-1:
			var a := j*n+i
			index[o] = a; index[o+1] = a+1; index[o+2] = a+n
			index[o+3] = a+1; index[o+4] = a+n+1; index[o+5] = a+n
			o += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_INDEX] = index
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.95
	var node := MeshInstance3D.new()
	node.name = "Ground"
	node.mesh = mesh
	node.material_override = m
	add_child(node)

func _build_water() -> void:
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE*POND_R*3.0
	# Fine enough for the wake's bulge and rings to lift it (0.7 m cells).
	quad.subdivide_width = 145
	quad.subdivide_depth = 145
	pond_material = ShaderMaterial.new()
	pond_material.shader = POND_SHADER
	var node := MeshInstance3D.new()
	node.name = "Pond"
	node.mesh = quad
	node.material_override = pond_material
	# The wake lifts it: room for it.
	node.custom_aabb = AABB(Vector3(-POND_R*1.5,-1.0,-POND_R*1.5),Vector3(POND_R*3.0,2.5,POND_R*3.0))
	node.position = Vector3(POND.x,WATER_Y,POND.y)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)

func _stone_material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m

## A static body on RuinBump.LAYER holding `shape` at `xf`.
func _solid(holder: Node3D, shape: Shape3D, xf: Transform3D) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = RuinBump.LAYER
	body.collision_mask = 0
	var s := CollisionShape3D.new()
	s.shape = shape
	s.transform = xf
	body.add_child(s)
	holder.add_child(body)

## Boulders: a lumpy sphere each, half sunk, steered round by the trail.
func _build_rocks() -> void:
	var spots := [Vector2(-30.0,-20.0),Vector2(40.0,30.0),Vector2(-60.0,-140.0),Vector2(10.0,-110.0),
		Vector2(130.0,40.0),Vector2(-130.0,20.0),Vector2(60.0,-130.0)]
	var m := _stone_material(ROCK)
	for i in spots.size():
		var p: Vector2 = spots[i]
		var r := _rng.randf_range(2.2,4.2)
		var holder := Node3D.new()
		holder.name = "Rock_%d" % i
		holder.position = Vector3(p.x,height(p.x,p.y)-r*0.2,p.y)
		holder.rotation.y = _rng.randf()*TAU
		add_child(holder)
		var rock := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = r
		s.height = r*2.0
		s.radial_segments = 10
		s.rings = 6
		rock.mesh = s
		rock.material_override = m
		var sc := Vector3(_rng.randf_range(1.0,1.5),_rng.randf_range(0.6,0.9),_rng.randf_range(0.9,1.3))
		rock.scale = sc
		holder.add_child(rock)
		# The body unscaled (Jolt takes no squashed sphere): a box round it.
		var shape := BoxShape3D.new()
		shape.size = sc*r*1.7
		_solid(holder,shape,Transform3D.IDENTITY)
		rocks.append({"at":p,"reach":r*1.5})

## The ruin stub: a broken wall and two pillars, one fallen block.
func _build_ruin() -> void:
	var c := Vector2(-55.0,45.0)
	var holder := Node3D.new()
	holder.name = "Ruin"
	holder.position = Vector3(c.x,height(c.x,c.y),c.y)
	holder.rotation.y = 0.5
	add_child(holder)
	var m := _stone_material(STONE)
	var blocks := [
		[Vector3(0.0,1.6,0.0),Vector3(11.0,3.2,1.6)],
		[Vector3(-3.0,4.0,0.0),Vector3(4.5,1.6,1.6)],
		[Vector3(-7.5,3.5,0.0),Vector3(1.8,7.0,1.8)],
		[Vector3(7.0,2.8,0.0),Vector3(1.8,5.6,1.8)],
		[Vector3(3.5,0.6,3.5),Vector3(2.4,1.2,1.6)],
	]
	for b: Array in blocks:
		var node := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = b[1]
		node.mesh = box
		node.material_override = m
		node.position = b[0]
		holder.add_child(node)
		var shape := BoxShape3D.new()
		shape.size = b[1]
		_solid(node,shape,Transform3D.IDENTITY)
	ruins.append({"at":c,"reach":11.0})

## The trees: a trunk and a few crown lumps, each a node of its own (the
## trail shudders them).
func _build_trees() -> void:
	var placed := 0
	var tries := 0
	while placed < 16 and tries < 400:
		tries += 1
		var p := Vector2(_rng.randf_range(-170.0,170.0),_rng.randf_range(-170.0,170.0))
		if p.length() > MEADOW_R-10.0: continue
		if p.distance_to(POND) < POND_R+8.0 or p.distance_to(KNOLL) < KNOLL_R: continue
		if p.length() < 25.0: continue
		var clear := true
		for r: Dictionary in rocks + ruins:
			if p.distance_to(r.at) < float(r.reach)+8.0: clear = false
		for t: Node3D in trees:
			if p.distance_to(Vector2(t.position.x,t.position.z)) < 14.0: clear = false
		if not clear: continue
		trees.append(_tree(p,placed))
		placed += 1

func _tree(p: Vector2, i: int) -> Node3D:
	var tall := _rng.randf_range(8.0,13.0)
	var tree := Node3D.new()
	tree.name = "Tree_%d" % i
	tree.position = Vector3(p.x,height(p.x,p.y)-0.2,p.y)
	tree.rotation.y = _rng.randf()*TAU
	add_child(tree)
	var trunk := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.25
	cyl.bottom_radius = 0.45
	cyl.height = tall*0.7
	trunk.mesh = cyl
	trunk.material_override = _stone_material(BARK)
	trunk.position.y = tall*0.35
	tree.add_child(trunk)
	# The crown on its own node, so a shudder can sway it more than the trunk.
	var crown := Node3D.new()
	crown.name = "Crown"
	crown.position.y = tall*0.55
	tree.add_child(crown)
	var leaf := _stone_material(LEAF.lerp(Color("587a32"),_rng.randf()))
	for k in 3:
		var lump := MeshInstance3D.new()
		var s := SphereMesh.new()
		var r := tall*_rng.randf_range(0.2,0.28)
		s.radius = r
		s.height = r*1.8
		s.radial_segments = 12
		s.rings = 6
		lump.mesh = s
		lump.material_override = leaf
		lump.position = Vector3(_rng.randf_range(-1.2,1.2),tall*0.2+k*tall*0.12,_rng.randf_range(-1.2,1.2))
		crown.add_child(lump)
	var shape := CylinderShape3D.new()
	shape.radius = 0.5
	shape.height = tall*0.7
	_solid(tree,shape,Transform3D(Basis.IDENTITY,Vector3.UP*tall*0.35))
	var bush := SphereShape3D.new()
	bush.radius = tall*0.24
	_solid(tree,bush,Transform3D(Basis.IDENTITY,Vector3.UP*tall*0.8))
	tree.set_meta("tall",tall)
	return tree

## The carpet grass, as the endless land's near ring grows it (KitFlora
## Grow with Carpet's settings and the ringed tufts), over the meadow and
## the hills' feet; none in the water, on the knoll's steep sides or under
## the stone.
func _build_grass(share: float) -> void:
	var site := KitFlora.Site.new()
	Carpet.carpeted(site)
	site.tufts *= share
	site.rim = 0.0
	site.lod = EndlessGrass.LOD
	site.lod_share = 0.35
	site.lod_grow = EndlessGrass.FAR_GROW
	site.lod_soft = EndlessGrass.SOFT
	site.grass_range = EndlessGrass.LOD.w
	var reach := MEADOW_R
	# The heights on a 1 m grid over the grass's square, read bilinearly by
	# the probe (the noise at every candidate cost the most of the grow).
	var g0 := -reach-20.0
	var gn := int((reach+20.0)*2.0)+1
	var hs := PackedFloat32Array()
	hs.resize(gn*gn)
	for j in gn:
		for i in gn: hs[j*gn+i] = height(g0+i,g0+j)
	var at := func(x: float, z: float) -> float:
		var u := clampf(x-g0,0.0,gn-1.001)
		var v := clampf(z-g0,0.0,gn-1.001)
		var i := int(u)
		var j := int(v)
		var fu := u-i
		var fv := v-j
		var k := j*gn+i
		return lerpf(lerpf(hs[k],hs[k+1],fu),lerpf(hs[k+gn],hs[k+gn+1],fu),fv)
	var stones: Array = rocks.duplicate()
	site.probe = func(p: Vector2, _r: float) -> float:
		var r := p.length()
		if r > reach: return NAN
		# Thinning out over the meadow's last RIM_SOFT m, ragged.
		if r > reach-RIM_SOFT:
			var keep := (reach-r)/RIM_SOFT*(0.7+0.6*_hill.get_noise_2d(p.x*4.0,p.y*4.0))
			if float(hash(Vector2i(roundi(p.x*7.0),roundi(p.y*7.0)))%10007)/10007.0 > keep: return NAN
		var h: float = at.call(p.x,p.y)
		if h < WATER_Y+0.25: return NAN
		var up := 2.0/Vector3(float(at.call(p.x-1.0,p.y))-float(at.call(p.x+1.0,p.y)),2.0,float(at.call(p.x,p.y-1.0))-float(at.call(p.x,p.y+1.0))).length()
		if up < 0.8: return NAN
		for s: Dictionary in stones:
			if p.distance_to(s.at) < float(s.reach)*0.6: return NAN
		return h-EndlessGrass.SINK
	site.plain = true
	var g := reach+16.0
	var outline := PackedVector2Array([Vector2(-g,-g),Vector2(g,-g),Vector2(g,g),Vector2(-g,g)])
	# Grown in GRASS_CELL m squares at once on the workers (plain parts, as
	# the endless grass grows its cells), stood as batches here.
	var cells: Array[Rect2] = []
	var x := -reach
	while x < reach:
		var z := -reach
		while z < reach:
			var box := Rect2(x,z,GRASS_CELL,GRASS_CELL)
			# Only squares that reach into the grass's disc.
			var near := Vector2(clampf(0.0,box.position.x,box.end.x),clampf(0.0,box.position.y,box.end.y))
			if near.length() < reach: cells.append(box)
			z += GRASS_CELL
		x += GRASS_CELL
	var grown: Array = []
	grown.resize(cells.size())
	# The catalog and the tufts' meshes made here first (the workers only read them).
	for key: String in (SkyIslets.catalog().meshes as Dictionary).keys():
		if key.begins_with("grass") or key.contains("meadow-flower"):
			SkyIslets._plant_material(key)
		if key.begins_with("grass") and KitFlora.ringed(key): KitFlora.lite_tuft(key)
	var grow_one := func(i: int) -> void:
		var s: KitFlora.Site = Carpet.carpeted(KitFlora.Site.new())
		for k: String in ["tufts","rim","lod","lod_share","lod_grow","lod_soft","grass_range","probe","plain"]: s.set(k,site.get(k))
		s.box = cells[i]
		var job := KitFlora.Grow.new(hash([1234,i]) & 0xffffff,null,[],[outline],s)
		while not job.step(-1): pass
		if job.node != null: job.node.free()
		grown[i] = job.parts
	# Kept on disk once grown (the land is fixed): a grow takes 10-20 s.
	var cache := "user://burrower_grass_%d.bin" % (hash([GRASS_VERSION,share,reach,GRASS_CELL,site.tufts,rocks.size()]) & 0x7fffffff)
	var kept: Variant = null
	if FileAccess.file_exists(cache):
		var f := FileAccess.open(cache,FileAccess.READ)
		if f != null: kept = f.get_var()
	if kept is Array and (kept as Array).size() == cells.size():
		grown = kept
	else:
		var task := WorkerThreadPool.add_group_task(grow_one,cells.size(),-1,true,"burrower grass")
		WorkerThreadPool.wait_for_group_task_completion(task)
		var f := FileAccess.open(cache,FileAccess.WRITE)
		if f != null: f.store_var(grown)
	var holder := Node3D.new()
	holder.name = "Grass"
	add_child(holder)
	for parts: Array in grown:
		for part: Dictionary in parts:
			var batch := KitFlora.batch_node(str(part.key),part.tile,int(part.count),part.buffer,site.grass_range,part.get("ring",{}))
			holder.add_child(batch)
			grass_tufts += int(part.count)
