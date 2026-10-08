extends SceneTree
## Every HUD glyph builds a solid token (scripts/glyph_token.gd): a closed
## silhouette with faces both sides and a rim, sized to its box.
const GlyphToken = preload("res://scripts/glyph_token.gd")
const HudIcons = preload("res://scripts/hud_icons.gd")
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	HudIcons.item("sun")
	var ids: Array = HudIcons._items.keys()
	for id: String in ids:
		var mesh := GlyphToken.mesh_for(id)
		check(mesh != null and mesh.get_surface_count() == 1, id+" builds a token")
		if mesh == null or mesh.get_surface_count() == 0: continue
		var normals: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
		var front := 0
		var back := 0
		var side := 0
		for n in normals:
			if n.z > 0.2: front += 1
			elif n.z < -0.2: back += 1
			else: side += 1
		check(front > 0 and front == back and side > 0, id+" has front, matching back and rim")
		var box := mesh.get_aabb()
		check(box.size.x > 3.0 and box.size.x <= 28.5 and box.size.y <= 28.5, id+" sits in its box: "+str(box))
		check(box.size.z > 2.0*GlyphToken.RIM and box.size.z <= 2.0*(GlyphToken.RIM+GlyphToken.SWELL)+0.01, id+" is a slab: "+str(box.size.z))
	var node := GlyphToken.token("sun",2.0)
	check(node != null and is_equal_approx(node.scale.x,2.0/24.0), "token scales to its size")
	if node: node.free()
	print("PASS: %d glyph tokens" % ids.size() if failures == 0 else "FAIL: glyph tokens")
	quit(1 if failures else 0)
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
