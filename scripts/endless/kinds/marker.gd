extends RefCounted
## Kind `marker`: a stand-in at a placed site's spot (scripts/endless/
## placed_sites.gd): a tall post in one plain colour, a pointer along the
## site's heading at its foot, the handle written over its top and, when the
## site asks for a clear footprint (params.clear, m), a ring on the ground at
## that radius. Unlit, no collider: the plane flies through it. The lanes
## swap a marker for their kind.
##
## Params: colour (Color, else one from the handle), tall (m, 40), clear.

const TALL := 40.0
const WIDE := 2.5
const COLOURS := [Color(1.0,0.25,0.6),Color(1.0,0.6,0.1),Color(0.2,0.8,1.0),Color(0.55,1.0,0.2),Color(0.75,0.4,1.0)]

static func build(site: Dictionary) -> Node3D:
	var params: Dictionary = site.get("params",{})
	var handle := str(site.get("handle",""))
	var col: Color = params.get("colour",COLOURS[absi(hash(handle))%COLOURS.size()])
	var tall := float(params.get("tall",TALL))
	var root := Node3D.new()
	var mat := _mat(col)
	var post := _box(Vector3(WIDE,tall,WIDE),mat)
	post.position.y = tall*0.5-2.0
	root.add_child(post)
	# A cap a shade darker, so the top reads against sky.
	var cap := _box(Vector3(WIDE*2.2,WIDE*1.6,WIDE*2.2),_mat(col.darkened(0.45)))
	cap.position.y = tall-2.0
	root.add_child(cap)
	# The heading: a bar out along -Z at the foot.
	var arrow := _box(Vector3(WIDE*0.8,1.0,14.0),mat)
	arrow.position = Vector3(0.0,0.5,-7.0)
	root.add_child(arrow)
	var clear := float(params.get("clear",0.0))
	if clear > 0.0:
		var ring := MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = clear-1.0
		t.outer_radius = clear+1.0
		t.rings = 48
		ring.mesh = t
		ring.material_override = mat
		ring.scale = Vector3(1.0,0.4,1.0)
		ring.position.y = 0.8
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(ring)
	var label := Label3D.new()
	label.text = handle
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.12
	label.font_size = 64
	label.outline_size = 14
	label.modulate = Color.WHITE
	label.outline_modulate = col.darkened(0.6)
	label.position.y = tall+8.0
	root.add_child(label)
	return root

static func _mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.disable_fog = true
	return m

static func _box(size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
