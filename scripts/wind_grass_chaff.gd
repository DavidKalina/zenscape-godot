extends "res://scripts/wind_leaf_litter.gd"
## A few loose grass blades and bits of chaff on the open meadow, cosmetic
## only (no saves or gameplay state), after the leaf litter they extend.
## They are lighter than leaves, so the same air moves them sooner: an
## ordinary breeze only rocks them, a swell of the breeze or a puff drags
## them, and a gust from the wind tool lifts and tumbles them downwind.
## Sparse on purpose (CHAFF at most, one per anchor), small (10-16 cm), and
## a soft straw-green so they read as grass, not litter.
const CHAFF := 36
## Weight per blade, against the leaves' 0.8-1.4: a blade slides in air of
## about 0.55 × weight and hops over 1.3 × weight (WindLeafLitter).
const WEIGHT := Vector2(0.5,0.75)
const SIZE := Vector2(0.10,0.16)
const COLORS := ["b9c47e","cfc98f","a7b86f"]

func _init() -> void:
	super()
	# Lighter than a leaf, so a sweep's updraft carries it a little higher.
	rise_cap = 3.0
	name = "WindGrassChaff"
	multimesh.mesh = _chaff_mesh()

## A thin, slightly bent blade lying along z, about 0.07 wide and 1 long
## before scaling, light at the tip.
static func _chaff_mesh() -> Mesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var spine := [Vector3(0,0.02,-0.5),Vector3(0.03,0.05,0.0),Vector3(0,0.03,0.5)]
	var half := [0.035,0.03,0.0]
	for k in range(2):
		var a: Vector3 = spine[k]
		var b: Vector3 = spine[k+1]
		var a_side := Vector3(half[k],0,0)
		var b_side := Vector3(half[k+1],0,0)
		var a_color := Color.WHITE.darkened(0.12) if k == 0 else Color.WHITE
		for corner in [[a-a_side,a_color],[a+a_side,a_color],[b+b_side,Color.WHITE],[a-a_side,a_color],[b+b_side,Color.WHITE],[b-b_side,Color.WHITE]]:
			surface.set_color(corner[1])
			surface.add_vertex(corner[0])
	surface.generate_normals()
	return surface.commit()

## A lost blade grows back close to its anchor, not in a tree's drift.
func _regrow_point(anchor: Vector2, _leaf: Dictionary) -> Vector2:
	return anchor+Vector2.from_angle(_rng.randf()*TAU)*_rng.randf_range(0.35,1.7)

## Blades rest one per anchor, anywhere within reach of it, and a lost one
## grows back near its anchor (WindLeafLitter._regrow).
func seed_from(anchors: Array, probe: Callable) -> void:
	ground_height = probe
	leaves.clear()
	_clock = 0.0
	_accumulator = 0.0
	_rng.seed = 5113
	for anchor: Vector2 in anchors:
		if leaves.size() >= CHAFF: break
		var angle := _rng.randf()*TAU
		var point := anchor + Vector2(cos(angle),sin(angle))*_rng.randf_range(0.0,0.6)
		var height: Variant = ground_height.call(point)
		if height == null or not is_finite(float(height)): continue
		var normal := _ground_normal(point,float(height))
		if normal.y < 0.75: continue
		var position := Vector3(point.x,float(height)+0.035,point.y)
		leaves.append({"position":position,"home":position,"anchor":anchor,"velocity":Vector3.ZERO,"yaw":angle,"spin":0.0,
			"phase":_rng.randf()*TAU,"size":_rng.randf_range(SIZE.x,SIZE.y),"weight":_rng.randf_range(WEIGHT.x,WEIGHT.y),
			"exposure":_rng.randf_range(0.7,1.3),"cooldown":_rng.randf_range(0.0,0.8),"airborne":false,"normal":normal,
			"stir":0.0,"turn":-1.0 if _rng.randf() < 0.5 else 1.0,"shown":1.0,"lost":false,"wait":0.0})
		var color := Color(COLORS[_rng.randi_range(0,COLORS.size()-1)])
		multimesh.set_instance_color(leaves.size()-1,color.srgb_to_linear())
	multimesh.visible_instance_count = leaves.size()
	_draw()

## Up to `count` resting places on open grass: an even spread over the
## plate (the R2 low-discrepancy sequence, the same for the same ground)
## kept where `cover` (0..1 at a point) says grass grows.
static func anchors_on(cover: Callable, count := CHAFF) -> Array:
	var anchors: Array = []
	for i in range(count*4):
		if anchors.size() >= count: break
		var point := Vector2(fposmod(0.5+i*0.7548777,1.0),fposmod(0.5+i*0.5698403,1.0))*(Plate.SIZE-2.0)-Vector2.ONE*(Plate.HALF-1.0)
		if float(cover.call(point)) > 0.4: anchors.append(point)
	return anchors
