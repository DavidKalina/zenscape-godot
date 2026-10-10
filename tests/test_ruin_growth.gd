extends SceneTree
## The ruins' growth (scripts/ruin_growth.gd, shaders/ruin_growth.gdshader,
## docs/scenic/ruin-overgrowth.md): every piece draws its stone and its
## growth as two surfaces, the growth in its own wind material with the
## shader's per-vertex data (reach from the anchor, strand length, flutter,
## the face it lies on); weathered pieces grow vine curtains hanging free
## (long strands, pinned at the root); moss never moves; set_detail thins
## the growth and 0 grows none, while the stone and the collision never
## change with it (growth is never collided); a merged run or hall keeps
## the growth as one second surface. Prints the triangle and draw-call cost
## of a 12-bay hall and an aqueduct span.
const RuinKit = preload("res://scripts/ruin_kit.gd")
const RuinGrowth = preload("res://scripts/ruin_growth.gd")
const Aqueduct = preload("res://scripts/ruin_kit_aqueduct.gd")
const Hall = preload("res://scripts/ruin_kit_hall.gd")
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		print("FAIL "+label)

func _run() -> void:
	for id: String in ["arch","lancet_wall","wall","aqueduct_span","hall_bay"]:
		_piece(id)
	_detail()
	_merged()
	_cost()
	print("test_ruin_growth: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL",failures])
	quit(1 if failures > 0 else 0)

func _mesh(node: Node) -> ArrayMesh:
	var m := node.get_node_or_null("Mesh") as MeshInstance3D
	return m.mesh as ArrayMesh if m != null else null

## {stone, growth} triangles of a built node's own mesh.
func _split(node: Node) -> Dictionary:
	var mesh := _mesh(node)
	var out := {"stone":0,"growth":0}
	for s in range(mesh.get_surface_count()):
		var key := "growth" if mesh.surface_get_material(s) == RuinGrowth.material() else "stone"
		out[key] += mesh.surface_get_array_len(s)/3
	return out

func _hulls(node: Node) -> Array:
	var out := []
	var body := node.get_node_or_null("Body")
	for child in body.get_children(): out.append(((child as CollisionShape3D).shape as ConvexPolygonShape3D).points)
	return out

func _piece(id: String) -> void:
	var node := RuinKit.piece(id,7,1.0)
	var mesh := _mesh(node)
	check(mesh.get_surface_count() == 2,id+": stone and growth, two surfaces")
	check(mesh.surface_get_material(0) == RuinKit.materials().stone,id+": the stone first, in the stone's material")
	check(mesh.surface_get_material(1) == RuinGrowth.material(),id+": the growth second, in the growth's wind material")
	var s := mesh.surface_get_arrays(1)
	var count: int = (s[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	check(count > 0 and (s[Mesh.ARRAY_TEX_UV] as PackedVector2Array).size() == count and (s[Mesh.ARRAY_TEX_UV2] as PackedVector2Array).size() == count and (s[Mesh.ARRAY_CUSTOM0] as PackedFloat32Array).size() == count*4 and (s[Mesh.ARRAY_COLOR] as PackedColorArray).size() == count,id+": the growth carries its wind data per vertex")
	var uv: PackedVector2Array = s[Mesh.ARRAY_TEX_UV]
	var uv2: PackedVector2Array = s[Mesh.ARRAY_TEX_UV2]
	var cu: PackedFloat32Array = s[Mesh.ARRAY_CUSTOM0]
	var free_long := 0
	var pinned := 0
	var still := 0
	var bad := 0
	for i in range(count):
		var reach := absf(uv[i].x)
		if uv[i].y > 0.0 and reach > uv[i].y*1.2+0.001: bad += 1
		if uv[i].y > 1.5 and cu[i*4+2] > 0.99 and reach > 1.0: free_long += 1
		if uv[i].y > 0.0 and reach < 0.05: pinned += 1
		if uv[i].y == 0.0 and uv2[i].y == 0.0: still += 1
	check(bad == 0,id+": no vertex reaches past its strand")
	check(pinned > 0,id+": strands are pinned at their roots")
	if id in ["arch","lancet_wall","aqueduct_span","hall_bay"]: check(free_long > 0,id+": vine curtains hang free, over a metre down")
	if id in ["wall","aqueduct_span"]: check(still > 0,id+": moss cushions, still")
	# Nothing of the growth is solid: every hull stands where stone does.
	node.free()

## The detail thins the growth (0: none); the vines never touch the stone
## or the collision (growth is never collided).
func _detail() -> void:
	for id: String in ["arch","aqueduct_span","hall_bay"]:
		var by := {}
		for d: float in [1.0,0.5,0.0]:
			RuinKit.set_detail(d)
			var node := RuinKit.piece(id,11,1.0)
			by[d] = _split(node)
			node.free()
		RuinKit.set_detail(1.0)
		check(by[1.0].growth > by[0.5].growth and by[0.5].growth > by[0.0].growth,id+": the detail thins the growth: %s" % str(by))
		check(by[0.0].growth == 0,id+": detail 0 grows nothing")
		RuinGrowth.vines = false
		var bare := RuinKit.piece(id,11,1.0)
		RuinGrowth.vines = true
		var grown := RuinKit.piece(id,11,1.0)
		check(_hulls(bare) == _hulls(grown),id+": the same collision with the vines or without")
		var old := _split(bare)
		var now := _split(grown)
		check(old.stone == now.stone,id+": the same stone with the vines or without")
		print("%s growth tris at detail 1 / 0.5 / 0: %d / %d / %d; without the vines %d; stone %d" % [id,by[1.0].growth,by[0.5].growth,by[0.0].growth,old.growth,now.stone])
		bare.free()
		grown.free()

func _merged() -> void:
	var run := Aqueduct.run(5,0.6,3)
	var mesh := _mesh(run)
	check(mesh != null and mesh.get_surface_count() == 2 and mesh.surface_get_material(1) == RuinGrowth.material(),"a merged aqueduct run keeps its growth as one second surface")
	run.free()

## The cost: a 12-bay hall at in-world detail and an aqueduct span.
func _cost() -> void:
	RuinKit.set_detail(Hall.IN_WORLD)
	for weathered: float in [0.0,0.6]:
		var hall := Hall.hall(12,weathered,12)
		var split := _split(hall)
		var total := RuinKit.triangles(hall)
		print("12-bay hall seed 12 weathered %.1f at detail %.2f: %d triangles (stone %d, growth %d), %d surfaces" % [weathered,Hall.IN_WORLD,total,split.stone,split.growth,_mesh(hall).get_surface_count()])
		check(total < Hall.BUDGET,"a 12-bay hall at weathered %.1f is under budget: %d < %d" % [weathered,total,Hall.BUDGET])
		hall.free()
	RuinKit.set_detail(1.0)
	for weathered: float in [0.55,1.0]:
		var span := RuinKit.piece("aqueduct_span",1,weathered)
		var split := _split(span)
		print("aqueduct span seed 1 weathered %.2f at detail 1: stone %d, growth %d triangles, %d surfaces" % [weathered,split.stone,split.growth,_mesh(span).get_surface_count()])
		span.free()
	var run := Aqueduct.run(1,0.55,4,2)
	var split := _split(run)
	print("aqueduct run (head + 4 spans, gallery's) at detail 1: stone %d, growth %d triangles" % [split.stone,split.growth])
	run.free()
