class_name NativeWaterCourse
extends RefCounted
## Adapt waterfall.js traceCourse: downhill gradient, momentum and pool pull.
## Every accepted station samples the editable terrain; there is no airborne arc.
static func trace(data: NativeTerrainData, start: Vector3, finish: Vector3, rings: int, water := PackedVector3Array()) -> PackedVector3Array:
	var path := PackedVector3Array([start])
	var position := Vector2(start.x,start.z)
	var target := Vector2(finish.x,finish.z)
	var momentum := Vector2.ZERO
	for step in range(240):
		var height: float = data.ground_height(position)
		var gap := position.distance_to(target)
		if gap <= 0.28:
			path.append(finish)
			return _resample(data,path,rings,finish.y,water)
		var gradient := Vector2.ZERO
		for axis in [Vector2.RIGHT,Vector2.DOWN]:
			var a: Variant = data.ground_height(position+axis*0.15)
			var b: Variant = data.ground_height(position-axis*0.15)
			if a == null or b == null:
				return PackedVector3Array()
			gradient += axis*(float(a)-float(b))/0.3
		var toward := (target-position).normalized()
		var downhill := -gradient.normalized() if gradient.length() > 0.001 else toward
		var flat := 1.0-smoothstep(0.12,0.5,gradient.length())
		var pull := maxf(0.26+0.62*(1.0-smoothstep(0.7,3.2,gap)),0.9*flat)
		momentum = momentum*0.55+downhill.lerp(toward,pull)*0.45
		var next := position+momentum.normalized()*minf(0.25,gap)
		var next_height: Variant = data.ground_height(next)
		if next_height == null or _surface(float(next_height),next,water,finish.y) > _surface(height,position,water,finish.y)+0.0001:
			# The pool's pull cannot make water climb over a ridge.
			next = position+downhill*minf(0.25,gap)
			next_height = data.ground_height(next)
			if next_height == null or _surface(float(next_height),next,water,finish.y) > _surface(height,position,water,finish.y)+0.0001:
				return PackedVector3Array()
		if path.size() > 12 and next.distance_to(Vector2(path[-10].x,path[-10].z)) < 0.2:
			return PackedVector3Array() # Trapped in a hollow, not connected water.
		position = next
		path.append(Vector3(position.x,_surface(float(next_height),position,water,finish.y),position.y))
	return PackedVector3Array()

static func _resample(data: NativeTerrainData, path: PackedVector3Array, count: int, level: float, water: PackedVector3Array) -> PackedVector3Array:
	var cumulative := PackedFloat32Array([0.0])
	for i in range(1,path.size()):
		var drop := maxf(0.0,path[i-1].y-path[i].y)
		cumulative.append(cumulative[-1]+0.4*path[i].distance_to(path[i-1])+0.6*drop)
	var result := PackedVector3Array()
	var segment := 0
	for i in range(count):
		var distance := cumulative[-1]*float(i)/(count-1)
		while segment < path.size()-2 and cumulative[segment+1] < distance:
			segment += 1
		var t := (distance-cumulative[segment])/maxf(0.00001,cumulative[segment+1]-cumulative[segment])
		var point := path[segment].lerp(path[segment+1],t)
		var ground: Variant = data.ground_height(Vector2(point.x,point.z))
		if ground == null:
			return PackedVector3Array()
		point.y = _surface(float(ground),Vector2(point.x,point.z),water,level)
		if not result.is_empty() and point.y > result[-1].y+0.002:
			return PackedVector3Array()
		result.append(point)
	result[0] = path[0]
	result[-1] = path[-1]
	for i in range(1,result.size()):
		var samples := maxi(2,ceili(result[i].distance_to(result[i-1])/0.1))
		for sample in range(1,samples):
			var point := result[i-1].lerp(result[i],float(sample)/samples)
			var ground: Variant = data.ground_height(Vector2(point.x,point.z))
			if ground == null:
				return PackedVector3Array()
			var bed := _surface(float(ground),Vector2(point.x,point.z),water,level)
			if point.y < bed-0.06 or point.y > bed+0.25:
				return PackedVector3Array()
	return result

static func _surface(ground: float, point: Vector2, water: PackedVector3Array, level: float) -> float:
	return level if not water.is_empty() and GardenWater.covers(water,point) else ground+0.08

static func half_width(data: NativeTerrainData, point: Vector3, across: Vector3, requested: float) -> float:
	for pond: Dictionary in data.ponds:
		if GardenWater.covers(data.pond_surface(pond),Vector2(point.x,point.z)):
			return requested
	var width := 0.0
	for i in range(1,21):
		var distance := requested*float(i)/20.0
		for side in [-1.0,1.0]:
			var sample: Vector3 = point+across*distance*side
			var ground: Variant = data.ground_height(Vector2(sample.x,sample.z))
			if ground == null or ground > point.y+0.15 or ground < point.y-0.45:
				return minf(width,requested)
		width = distance
	return requested
