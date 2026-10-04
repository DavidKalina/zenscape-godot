extends RefCounted
## Fallen leaves: real silhouettes (a pointed tip, a midrib fold so each half
## catches the light on its own facet), warm varied colour, and the shared
## drift scatter. Used by the loose wind litter (scripts/wind_leaf_litter.gd)
## and the placeable leaf bed (scripts/bigfoot_leaf_bed.gd).
##
## A leaf lies along z, tip at -z, about 1.2 long before scaling. Each shape is
## a list of stations (z, half width); an edge station is lifted by the fold,
## so a leaf is a shallow V along its midrib.
const SHAPES := {
	# Oval with a drawn-out point (birch, poplar).
	"oval":{"stations":[[0.60,0.0],[0.30,0.26],[-0.05,0.34],[-0.34,0.20],[-0.62,0.0]],"fold":0.22},
	# Lobed, maple-ish: three points a side with notches between.
	"lobed":{"stations":[[0.58,0.0],[0.34,0.14],[0.16,0.40],[-0.04,0.17],[-0.22,0.42],[-0.40,0.15],[-0.64,0.0]],"fold":0.16},
	# Slender willow blade.
	"willow":{"stations":[[0.66,0.0],[0.22,0.15],[-0.20,0.14],[-0.70,0.0]],"fold":0.3},
	# Broad, rounded aspen with a short tip.
	"broad":{"stations":[[0.52,0.0],[0.30,0.30],[-0.02,0.40],[-0.30,0.28],[-0.56,0.0]],"fold":0.12},
}
const ORDER := ["oval","lobed","willow","broad"]
## Autumn leaf colours (sRGB) and how common each is.
const PALETTE := [["c79a3f",3.0],["a9532c",3.0],["d2b050",2.5],["b9763a",2.5],["8c4a2a",1.5],["a9aa55",1.0]]

## How many triangles a shape has.
static func triangles(shape: String) -> int:
	var stations: Array = SHAPES[shape].stations
	var count := 0
	for k in range(stations.size()-1):
		count += 1 if (stations[k][1] == 0.0 or stations[k+1][1] == 0.0) else 2
	return count*2

## Adds one leaf (both halves) to `surface`, transformed by `at`. `variant`
## goes in UV.x so the instancing shader can pick one shape of a stacked set.
static func add_leaf(surface: SurfaceTool, shape: String, at: Transform3D, tint: Color, variant: float, lift := 1.0) -> void:
	var data: Dictionary = SHAPES[shape]
	var stations: Array = data.stations
	var fold: float = data.fold*lift
	for side in [-1.0,1.0]:
		# The two halves take the light differently, as folded faces do.
		var half := tint.darkened(0.13) if side < 0.0 else tint.lightened(0.05)
		for k in range(stations.size()-1):
			var a: Array = stations[k]
			var b: Array = stations[k+1]
			var a_mid := Vector3(0,0.0,a[0])
			var b_mid := Vector3(0,0.0,b[0])
			var a_edge := Vector3(side*a[1],a[1]*fold,a[0])
			var b_edge := Vector3(side*b[1],b[1]*fold,b[0])
			var triangle_list: Array = []
			if a[1] == 0.0: triangle_list = [[a_mid,b_edge,b_mid]]
			elif b[1] == 0.0: triangle_list = [[a_mid,a_edge,b_mid]]
			else: triangle_list = [[a_mid,a_edge,b_edge],[a_mid,b_edge,b_mid]]
			for tri: Array in triangle_list:
				var order: Array = tri if side > 0.0 else [tri[0],tri[2],tri[1]]
				for point: Vector3 in order:
					# Veins darker along the midrib, the tip a touch lighter.
					var shade := 0.9 if point.x == 0.0 else 1.0
					if point.z < -0.3: shade *= 1.06
					surface.set_color(Color(half.r*shade,half.g*shade,half.b*shade))
					surface.set_uv(Vector2(variant,0))
					surface.add_vertex(at*point)

## A warm colour, per-leaf jittered (sRGB in, linear out as the meshes use).
static func leaf_color(rng: RandomNumberGenerator) -> Color:
	var total := 0.0
	for entry in PALETTE: total += float(entry[1])
	var pick := rng.randf()*total
	var base := Color(PALETTE[0][0])
	for entry in PALETTE:
		pick -= float(entry[1])
		if pick <= 0.0:
			base = Color(entry[0])
			break
	var hue := fposmod(base.h+rng.randf_range(-0.025,0.025),1.0)
	var color := Color.from_hsv(hue,clampf(base.s*rng.randf_range(0.85,1.12),0.0,1.0),clampf(base.v*rng.randf_range(0.82,1.1),0.0,1.0))
	return color.srgb_to_linear()

## The four shapes stacked into one mesh for instancing: variant id in UV.x,
## and the shader collapses the shapes an instance did not pick.
static func instanced_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(ORDER.size()):
		add_leaf(surface,ORDER[i],Transform3D.IDENTITY,Color.WHITE,float(i))
	surface.generate_normals()
	return surface.commit()

static func material() -> ShaderMaterial:
	var made := ShaderMaterial.new()
	made.shader = load("res://shaders/leaf_litter.gdshader")
	return made

## Where a leaf of an anchor's drift rests: mostly in a lee heaped near the
## trunk, a few strays further out, thinning to nothing in open meadow.
## `heading` is the drift's own direction. `ground` (a Callable returning a
## height or null) pulls leaves toward hollows when it can.
static func drift_point(rng: RandomNumberGenerator, anchor: Vector2, heading: float, ground: Callable) -> Vector2:
	var best := anchor+Vector2.from_angle(heading)*0.5
	var best_score := -INF
	for attempt in range(3):
		var point: Vector2
		if rng.randf() < 0.15:
			point = anchor+Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(2.0,3.4)
		else:
			# Gathered about a spot a little way downwind of the trunk,
			# stretched along the drift.
			var centre := anchor+Vector2.from_angle(heading)*0.7
			var along := rng.randfn(0.0,0.75)
			var across := rng.randfn(0.0,0.4)
			point = centre+Vector2.from_angle(heading)*along+Vector2.from_angle(heading+PI*0.5)*across
			var out := point-anchor
			if out.length() < 0.3: point = anchor+(out.normalized() if out.length() > 0.001 else Vector2.RIGHT)*0.3
		var score := rng.randf()*0.25
		if ground.is_valid():
			var here: Variant = ground.call(point)
			if here == null: continue
			var around := 0.0
			var n := 0
			for d in [Vector2(0.6,0),Vector2(-0.6,0),Vector2(0,0.6),Vector2(0,-0.6)]:
				var h: Variant = ground.call(point+d)
				if h != null:
					around += float(h)
					n += 1
			# Hollows (lower than their surroundings) collect leaves.
			if n > 0: score += clampf((around/n-float(here))*2.0,-0.3,0.6)
		if score > best_score:
			best_score = score
			best = point
	return best
