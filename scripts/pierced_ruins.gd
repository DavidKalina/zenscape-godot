extends RefCounted
## The pierced isle's ruins (scripts/pierced_isle.gd `ruins`, laid by the
## plan): built here from the ruin kit (scripts/ruin_kit.gd and its
## aqueduct and hall families) on a worker, off the tree, at the halls'
## in-world detail (Hall IN_WORLD), each in the lid's frame:
##   feed: an aqueduct run from its head (its abutment stepping down into
##     the top) to the skylight's lip, a spout carrying its channel out over
##     the hole's edge and its water spilling down the shaft as a long thin
##     fall (the islets' curtain, scripts/sky_islets.gd), into a pool where
##     it lands;
##   gate: the gothic pointed arch standing in the tight window, its feet
##     on the window's flat floor, its gable and buttresses buried in the
##     rock round the mouth;
##   hall: a short colossus hall on the top, on the lid's real ground (its
##     walls run down into it);
##   run: an aqueduct striding across the cavern's floor.
## Every ruin's stone is solid to the plane (its hulls on LAYER, which only
## the bump asks: scripts/sky_pierced.gd) and none glows. The ruins draw to
## RANGE m; past that the rock alone stands for the isle.

const RuinKit = preload("res://scripts/ruin_kit.gd")
const Aqueduct = preload("res://scripts/ruin_kit_aqueduct.gd")
const Hall = preload("res://scripts/ruin_kit_hall.gd")
const SkyIslet = preload("res://scripts/sky_islet.gd")
const SkyIslets = preload("res://scripts/sky_islets.gd")
const FlowFalls = preload("res://scripts/flow_falls.gd")

## The ruins' hulls' physics layer (the plane's bump asks only it).
const LAYER := 1 << 19
## The detail each is built at (RuinKit `set_detail`: the ivy, moss, tufts
## and rubble; the stone is the same): the hall and the gate at the halls'
## in-world detail, the feed a little leaner (an aqueduct span is some 9 to
## 16 thousand faces), the cavern's run bare (it stands in the dim). And
## how far they draw (m): past it the rock alone stands for the isle.
const DETAIL := {"hall":Hall.IN_WORLD,"gate":Hall.IN_WORLD,"feed":0.12,"run":0.0}
const RANGE := 480.0
## The spout: how far it carries the channel past the last pier's face (m).
const SPOUT := 1.8
## The spill: its half width (m), the strength of its white, its throw.
const SPILL := Vector3(0.5,0.45,0.9)

## The shared pieces the build needs, made on the main thread.
static func prepare() -> void:
	RuinKit.materials()

## The ruins of `plan` on its lid (`lid`, its SkyIslet shape, made), as
## one node in the lid's frame, or null if it has none. Settles the plan's
## ruins on the lid's real ground first (PiercedIsle `settle`).
static func build(plan: RefCounted, lid: RefCounted) -> Node3D:
	plan.settle(lid)
	if plan.ruins.is_empty(): return null
	var before: float = RuinKit.Build.detail
	var root := Node3D.new()
	root.name = "Ruins"
	for r: Dictionary in plan.ruins:
		var at: Transform3D = r.at
		RuinKit.set_detail(float(DETAIL.get(r.kind,Hall.IN_WORLD)))
		var node: Node3D = null
		match str(r.kind):
			"feed": node = _feed(plan,lid,r)
			"gate": node = RuinKit.arch(int(r.seed),float(r.weathered))
			"hall": node = Hall.hall(int(r.seed),float(r.weathered),int(r.bays),ground(lid,at,-2.0),true)
			"run": node = Aqueduct.run(int(r.seed),float(r.weathered),int(r.spans),-1,false,Callable(),true)
		if node == null: continue
		node.name = str(r.kind).capitalize()
		node.transform = at
		root.add_child(node)
	RuinKit.set_detail(before)
	_finish(root)
	return root

## The lid's ground under a piece standing at `at` (lid frame), in the
## piece's own frame; `off` (piece frame, m) off the lid's land.
static func ground(lid: RefCounted, at: Transform3D, off: float) -> Callable:
	return func(x: float, z: float) -> float:
		var p := at*Vector3(x,0.0,z)
		var flat := Vector2(p.x,p.z)
		if not lid.inside(flat): return off
		return float(lid.ground_at(flat))-at.origin.y

## The feed: the run with its head, a spout past the last pier, the spill
## down the shaft and its pool where it lands.
static func _feed(plan: RefCounted, lid: RefCounted, r: Dictionary) -> Node3D:
	var at: Transform3D = r.at
	var spans := int(r.spans)
	var rim := SkyIslet.RIM_HEIGHT-at.origin.y
	var root := Aqueduct.run(int(r.seed),float(r.weathered),spans,-1,true,ground(lid,at,rim),true)
	var end := Aqueduct.SPAN*spans
	var face := end+Aqueduct.PIER.x*0.5
	# The spout: the channel's floor and two low cheeks carried out over the
	# edge, the water running on along it.
	var b := RuinKit.Build.new(int(r.seed)+77,float(r.weathered)*0.5,"Spout")
	var length := face+SPOUT-end
	var slab := Vector3(length*0.5,Aqueduct.FLOOR*0.5,Aqueduct.DECK_WIDTH*0.5-0.1)
	b.solid(RuinKit._box(b,slab),Transform3D(Basis.IDENTITY,Vector3(end+length*0.5,Aqueduct.DECK-Aqueduct.FLOOR*0.5,0.0)),RuinKit._stone(b,0.98))
	for side: float in [-1.0,1.0]:
		var cheek := Vector3(length*0.5-0.05,Aqueduct.PARAPET.y*0.5,Aqueduct.PARAPET.x*0.5)
		b.solid(RuinKit._box(b,cheek),Transform3D(Basis.IDENTITY,Vector3(end+length*0.5,Aqueduct.DECK+cheek.y,side*(Aqueduct.CHANNEL*0.5+cheek.z))),RuinKit._stone(b,1.04))
	var spout := b.finish()
	root.add_child(spout)
	Aqueduct._water(root,end-0.1,face+SPOUT-0.08,Aqueduct.DECK+Aqueduct.WATER)
	# The spill: off the spout's end, down the shaft to where it lands.
	var lip := Vector3(face+SPOUT-0.05,Aqueduct.DECK+Aqueduct.WATER-0.02,0.0)
	var lip_lid := at*lip
	var landing: Vector3 = plan.fall_from(lip_lid)
	var drop := lip_lid.y-landing.y
	if drop > 2.0:
		var foot := _spill(root,lip,Vector3.RIGHT,int(r.seed),drop)
		# A pool where it lands, on the cavern's floor (or a ledge).
		var pool_lid := at*foot
		pool_lid.y = landing.y
		var pool := RuinKit.Build.new(int(r.seed)+91,float(r.weathered),"Pool")
		var floor_y := landing.y
		pool.terrain = func(_x: float, _z: float) -> float: return 0.0
		Aqueduct._pool(pool,Vector3.ZERO,1.6)
		var pool_node := pool.finish()
		pool_node.transform = Transform3D(Basis.IDENTITY,at.affine_inverse()*Vector3(pool_lid.x,floor_y+0.02,pool_lid.z))
		root.add_child(pool_node)
	return root

## A long thin spill off `lip` (the water's edge, the run's frame) along
## `out`, `drop` m down: the islets' curtain in the waterfalls' strand (as
## the aqueduct's own spill, scripts/ruin_kit_aqueduct.gd `_spill`). Gives
## where it lands (the run's frame, at the lip's height less the drop).
static func _spill(root: Node3D, lip: Vector3, out: Vector3, seed_value: int, drop: float) -> Vector3:
	var rings: Dictionary = SkyIslets.curtain(lip,out,drop-0.3,0.4,SPILL.x,0.3,SPILL.y,SPILL.z)
	if Aqueduct._fall_mesh == null: Aqueduct._fall_mesh = FlowFalls._build_ring_mesh(SkyIslets.FALL_RINGS)
	var fall := MeshInstance3D.new()
	fall.name = "Spill"
	fall.mesh = Aqueduct._fall_mesh
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/flow_fall.gdshader")
	material.render_priority = FlowFalls.CURTAIN_PRIORITY
	material.set_shader_parameter("fall_seed",float(seed_value%997)*0.37+3.0)
	var white := PackedFloat32Array()
	for s in range(12): white.append(fposmod(sin(float(s*23+seed_value%1000)*12.9898)*43758.5453,1.0))
	material.set_shader_parameter("section_white",white)
	material.set_shader_parameter("ring_count",SkyIslets.FALL_RINGS)
	material.set_shader_parameter("centers_tau",rings.centers)
	material.set_shader_parameter("axis_a_width",rings.across)
	material.set_shader_parameter("axis_b_thick",rings.outward)
	material.set_shader_parameter("aer_steep",rings.aer_steep)
	material.set_shader_parameter("ring_travel",rings.travel)
	material.set_shader_parameter("body_white",0.3)
	material.set_shader_parameter("veil",0.4)
	material.set_shader_parameter("streak_speed",clampf(0.6*sqrt(2.0*9.81*drop),2.5,9.0))
	fall.material_override = material
	fall.custom_aabb = rings.bounds
	fall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(fall)
	var points: PackedVector3Array = rings.points
	var foot := points[points.size()-1]
	return Vector3(foot.x,lip.y-drop,foot.z)

## Every body on LAYER (asked by the bump alone), every drawn part to RANGE.
static func _finish(root: Node) -> void:
	for node in root.get_children():
		if node is CollisionObject3D:
			(node as CollisionObject3D).collision_layer = LAYER
			(node as CollisionObject3D).collision_mask = 0
		elif node is GeometryInstance3D:
			var g := node as GeometryInstance3D
			g.visibility_range_end = RANGE
			g.visibility_range_end_margin = 40.0
			g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		_finish(node)

## The triangles the ruins draw (every mesh under `root` but the spill's
## ring mesh, drawn by its shader).
static func triangles(root: Node) -> int:
	if root == null: return 0
	var count := 0
	var mesh := root as MeshInstance3D
	if mesh != null and mesh.mesh != null and mesh.name != "Spill":
		for k in range(mesh.mesh.get_surface_count()): count += mesh.mesh.surface_get_array_len(k)/3
	for child in root.get_children(): count += triangles(child)
	return count
