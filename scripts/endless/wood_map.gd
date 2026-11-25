extends RefCounted
## The woods' weight round the eye as a texture (global `zs_wood_map`, read
## by shaders/distance_read.gdshaderinc `zs_wood_at`), so the grass tufts
## darken where the forest floor's sheet does (scripts/endless/land_trees.gd,
## shaders/endless_forest_floor.gdshader) and the two agree.
##
## It holds no plan of its own: each near block's floor sheet (its vertices
## on the FLOOR_STEP lattice, their alpha the floor weight TreePlan
## `floor_weight` gave them) is stamped in as the block stands and cleared as
## it goes. A texel a lattice node (STEP m, texel centres on the nodes),
## SIZE texels a side, wrapped (repeat): blocks stand at most ~2.3 km off,
## so nothing within the tufts' reach aliases. The texture goes up at most
## once a frame, only after a change (64 KB).
const STEP := 16.0
const SIZE := 256

var image: Image
var texture: ImageTexture
var _dirty := false

func _init() -> void:
	image = Image.create(SIZE,SIZE,false,Image.FORMAT_R8)
	image.fill(Color(0,0,0))
	texture = ImageTexture.create_from_image(image)
	RenderingServer.global_shader_parameter_set(&"zs_wood_map",texture)

## The block's floor sheet (land_trees `_floor_arrays`' {"arrays"}) stamped in.
func stamp(ground: Dictionary) -> void:
	if ground.is_empty(): return
	var arrays: Array = ground.arrays
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	for k in verts.size():
		var w := colours[k].a
		image.set_pixel(posmod(floori(verts[k].x/STEP),SIZE),posmod(floori(verts[k].z/STEP),SIZE),Color(w,w,w))
	_dirty = true

## The square (x0, z0, size m) emptied.
func clear(x0: float, z0: float, size: float) -> void:
	var n := int(size/STEP)
	var i0 := floori(x0/STEP)
	var j0 := floori(z0/STEP)
	for j in n:
		for i in n:
			image.set_pixel(posmod(i0+i,SIZE),posmod(j0+j,SIZE),Color(0,0,0))
	_dirty = true

## Once a frame: the texture updated if anything changed.
func flush() -> void:
	if not _dirty: return
	_dirty = false
	texture.update(image)
