extends RefCounted
## Worn paths drawn per pixel (shaders/path_dirt.gdshaderinc): a kit isle's
## paths (world polylines of (x, z)) handed to the ground material as
## segments, with the dirt the turf's baked-in wear used to blend to
## (KitLook.ground_tone's). The isle then bakes no wear into its turf's
## colours (`baked`), so the edge is drawn by the pixel, not the mesh's
## facets. --vertex-paths keeps the old baked wear and draws no paths.

## The most segments the shader reads (path_segs).
const MOST := 48
## The dirt lifted (times) and greyed toward dust (share).
const LIFT := 1.35
const DUST := 0.3

## Whether the turf bakes its wear into its colours (the old paths).
static func baked() -> bool:
	return "--vertex-paths" in preload("res://scripts/launch_args.gd").user_args()

## Hands `paths` to `material` (none with `baked`); the segments drawn.
static func paint(material: ShaderMaterial, paths: Array) -> int:
	var segs: Array[Vector4] = []
	if not baked():
		for path: Array in paths:
			for i in range(path.size()-1):
				if segs.size() >= MOST: break
				var a: Vector2 = path[i]
				var b: Vector2 = path[i+1]
				segs.append(Vector4(a.x,a.y,b.x,b.y))
	while segs.size() < MOST: segs.append(Vector4.ZERO)
	var count := 0 if baked() else mini(MOST,_count(paths))
	material.set_shader_parameter("path_segs",segs)
	material.set_shader_parameter("path_count",count)
	var pal := KitLook.palette()
	# The baked wear's dirt, lifted and greyed toward dust: drawn at full
	# strength per pixel it read as dark mud.
	var dirt: Color = (pal.gravel as Color).lerp(KitLook.EARTH.srgb_to_linear(),0.45)
	var grey := dirt.get_luminance()
	material.set_shader_parameter("path_dirt",Color(dirt.r,dirt.g,dirt.b).lerp(Color(grey,grey,grey),DUST)*LIFT)
	return count

static func _count(paths: Array) -> int:
	var n := 0
	for path: Array in paths: n += maxi(0,path.size()-1)
	return n
