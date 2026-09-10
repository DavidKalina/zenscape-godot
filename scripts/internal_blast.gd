extends RefCounted
## A confined charge fractures a cap around its origin, then ejects the actual
## removed terrain in all directions. Surface charges keep the crater/slide path.
const Collapse = preload("res://scripts/mountain_collapse.gd")

static func confined(data: NativeTerrainData, origin: Vector3, radius: float) -> bool:
	var roof: Variant = data.ground_height(Vector2(origin.x,origin.z))
	return roof != null and roof-origin.y >= maxf(1.0,radius*0.35)

static func rupture(data: NativeTerrainData, origin: Vector3, radius: float, colors: PackedColorArray, arrays_only := false) -> Dictionary:
	if not confined(data,origin,radius): return {}
	var before := data.heights.duplicate()
	var after := before.duplicate()
	var reach := radius*lerpf(1.6,1.8,smoothstep(2.0,6.0,radius))
	var region := Rect2()
	var changed := false
	for i in range(data.points.size()):
		var offset := data.points[i]-Vector2(origin.x,origin.z)
		# Confinement directs pressure through the surrounding rock and upward.
		# Thick overburden attenuates it; a tiny charge cannot remove any mountain.
		var cover := maxf(0,before[i]-origin.y)
		var distance := sqrt(offset.length_squared()+pow(cover*0.55,2))
		var q := distance/reach
		if q>=1.0: continue
		var strength := 1.0-smoothstep(0.5,1.0,q)
		var floor_height := maxf(data.MIN_HEIGHT,origin.y-radius*0.4)
		after[i] = before[i]-minf(maxf(0,before[i]-floor_height),radius*0.55)*strength
		if before[i]-after[i]<0.08: continue
		region = region.expand(data.points[i]) if changed else Rect2(data.points[i],Vector2.ZERO)
		changed = true
	if not changed: return {}
	# A finite rock budget prevents one small charge from excavating every
	# tall column in reach. Larger charges earn a cubic increase in capacity.
	var areas := Collapse.control_areas(data)
	var volume := 0.0
	for i in range(before.size()): volume += (before[i]-after[i])*areas[i]
	var capacity := pow(radius,3)*1.5
	if volume>capacity:
		for i in range(before.size()): after[i] = lerpf(before[i],after[i],capacity/volume)
	var chunks := Collapse._chunks(data,before,after,origin,radius,colors,true,arrays_only)
	if chunks.is_empty(): return {}
	for chunk: Dictionary in chunks:
		var offset: Vector3 = chunk.center-origin
		var direction := (offset.normalized()+Vector3.UP*0.25).normalized()
		var speed := radius*3.0*lerpf(0.55,1.0,1.0-clampf(offset.length()/(reach*1.8),0,1))
		chunk.velocity = direction*speed
		chunk.delay = 0.0
	data.heights = after
	Collapse._strip_cover(data,before,after,region)
	data.erase_tint(Vector2(origin.x,origin.z),reach,1.0)
	return {"before":before,"after":after,"region":region,"chunks":chunks,"internal":true,"origin":origin,"radius":radius}
