extends Node3D
## The dressing on the world's greybox pieces (land_pieces.gd): each piece's
## `dressing()` list hung where the stamp put it on the map's ground. Only
## the waterfall so far: the wilderness's curtain skin (waterfall.gd `dress`)
## from the piece's lip into its pool, and the pool's water.

const Waterfall = preload("res://scripts/endless/world/wilderness/waterfall.gd")
const WATER := Color("3d6a7a")

func setup(game: Node) -> void:
	var field: RefCounted = game.field
	if not field.has_method("pieces"): return
	var ps: RefCounted = field.pieces()
	if ps == null: return
	for i: int in ps.count():
		var s: Script = ps.script_of(i)
		if not s.has_method("dressing"): continue
		for d: Dictionary in s.dressing():
			if String(d.get("kind","")) == "waterfall": _fall(field,ps,i,d)

func _fall(field: RefCounted, ps: RefCounted, i: int, d: Dictionary) -> void:
	var tall: float = ps.tall_of(i)
	var sc: float = ps.scale_of(i)
	var lip_l: Vector3 = d.lip
	var lip_w: Vector2 = ps.to_world(i,Vector2(lip_l.x,lip_l.z))
	var lip := Vector3(lip_w.x,float(field.height(lip_w.x,lip_w.y)),lip_w.y)
	var pool_w: Vector2 = ps.to_world(i,d.pool)
	# The pool's water over the map's own ground at its middle (the stamp's
	# rise taken off).
	var ground := float(field.height(pool_w.x,pool_w.y))-float(ps.rise(pool_w.x,pool_w.y))
	var pool := Vector3(pool_w.x,ground+float(d.pool_y)*tall,pool_w.y)
	var o: Vector3 = d.out
	var out2: Vector2 = ps.dir_to_world(i,Vector2(o.x,o.z))
	var root := Node3D.new()
	root.name = "Waterfall%d" % i
	add_child(root)
	Waterfall.dress(root,{"lip": lip, "out": Vector3(out2.x,0.0,out2.y), "pool": pool,
		"drop": lip.y-pool.y, "half": 6.0*sc},{})
	var water := MeshInstance3D.new()
	water.name = "PoolWater%d" % i
	var disc := CylinderMesh.new()
	disc.top_radius = float(d.pool_r)*1.05*sc
	disc.bottom_radius = disc.top_radius
	disc.height = 0.05
	disc.radial_segments = 32
	water.mesh = disc
	var wm := StandardMaterial3D.new()
	wm.albedo_color = WATER
	wm.roughness = 0.15
	wm.metallic = 0.2
	water.material_override = wm
	water.position = pool
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
