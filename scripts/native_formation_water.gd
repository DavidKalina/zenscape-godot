extends RefCounted
## A shared plan for stream levels, their carved beds, and bounded source pools.
## Rendered courses and terrain consume the same stations: no floating ribbons.
var routes: Array[Dictionary] = []
var pools: Array = []
var _segments := {}
const CELL := 2.0

func setup(shape: RefCounted) -> void:
	pools = shape.pool_specs.duplicate(true)
	var family: String = shape.family
	if family == "terraced_pools":
		for i in range(pools.size()-1):
			var a: Dictionary = pools[i]
			var b: Dictionary = pools[i+1]
			_add([[a.x,a.z+a.rz*0.45,a.level],[a.x,a.z+a.rz*1.05,a.level],[b.x,b.z-b.rz*0.55,b.level]],1.1,false,false)
	elif family in ["valley","canyon"]:
		var pool := {"x":shape.channel_x(7.8),"z":7.8,"rx":2.5,"rz":2.0,"level":0.92}
		pools.append(pool)
		var anchors: Array = []
		for i in range(12):
			var z := -10.0+i*1.6
			var stage := 1.05+(7.8-z)*0.04
			if family == "canyon": stage += 1.6*(1.0-smoothstep(-3.5,-1.5,z))
			anchors.append([shape.channel_x(z),z,stage])
		anchors.append([pool.x,pool.z,pool.level])
		_add(anchors,1.55,true,false)
		# A side spring joins the main channel at exactly its receiving level.
		var z := -6.8
		var stage := 1.05+(7.8-z)*0.04+(1.6 if family == "canyon" else 0.0)
		_add([[-5.0,z-1.5,stage+1.8],[-3.2,z-0.7,stage+0.7],[shape.channel_x(z),z,stage]],0.75,true,false)
	elif family in ["cone","horn","ridgeback"]:
		var pool: Dictionary = pools[0]
		var start := Vector2(0.4,-1.2) if family != "ridgeback" else Vector2(-3.0,-2.0)
		var end := Vector2(pool.x,pool.z)
		var anchors: Array = []
		var level: float = shape.raw_height(start.x,start.y)+0.1
		for i in range(13):
			var t := float(i)/12.0
			var p := start.lerp(end,t)+Vector2(sin(t*PI)*0.7,0)
			level = maxf(pool.level,minf(level,shape.raw_height(p.x,p.y)+0.08))
			anchors.append([p.x,p.y,level])
		anchors[-1][2] = pool.level
		_add(anchors,0.95,true,false)
	elif family == "plateau":
		var pool: Dictionary = pools[0]
		var lower := {"x":2.4,"z":7.0,"rx":2.7,"rz":1.8,"level":1.35}
		pools.append(lower)
		_add([[pool.x,pool.z+0.7,pool.level],[pool.x,pool.z+2.2,pool.level],[0.2,3.5,5.9],[lower.x,5.8,lower.level],[lower.x,lower.z,lower.level]],1.1,false,false)
	for pool: Dictionary in pools:
		# A spill has its own downstream course, rather than flooding lower
		# shelves at the upstream lake's elevation.
		pool.basin = [float(pool.rx)*1.05,float(pool.rz)*1.05]

func _add(anchors: Array,width: float,head: bool,tail: bool) -> void:
	var points: Array = []
	var depth := 0.48
	var surface := 0.28
	for i in range(anchors.size()-1):
		var a: Array = anchors[i]
		var b: Array = anchors[i+1]
		var steps := maxi(1,ceili(Vector2(b[0]-a[0],b[1]-a[1]).length()/0.3))
		for j in range(steps):
			var t := float(j)/steps
			var level := lerpf(a[2],b[2],smoothstep(0.0,1.0,t))
			points.append({"x":lerpf(a[0],b[0],t),"z":lerpf(a[1],b[1],t),"h":level+depth-0.065*surface})
	var last: Array = anchors[-1]
	points.append({"x":float(last[0]),"z":float(last[1]),"h":float(last[2])+depth-0.065*surface})
	var route := {"pts":points,"width":width,"depth":depth,"surface":surface,"capHead":head,"capTail":tail}
	routes.append(route)
	for i in range(points.size()-1):
		var a := Vector2(points[i].x,points[i].z)
		var b := Vector2(points[i+1].x,points[i+1].z)
		var reach := width*0.6+1.3
		var low := a.min(b)-Vector2.ONE*reach
		var high := a.max(b)+Vector2.ONE*reach
		var segment := {"a":a,"delta":b-a,"length":a.distance_squared_to(b),"bed":points[i].h-depth,"drop":points[i+1].h-points[i].h,"width":width}
		for z in range(floori(low.y/CELL),floori(high.y/CELL)+1):
			for x in range(floori(low.x/CELL),floori(high.x/CELL)+1):
				var key := Vector2i(x,z)
				if not _segments.has(key): _segments[key] = []
				_segments[key].append(segment)

func carve(x: float,z: float,height: float) -> float:
	var p := Vector2(x,z)
	var closest := INF
	var result := height
	for s: Dictionary in _segments.get(Vector2i(floori(x/CELL),floori(z/CELL)),[]):
		var t := clampf((p-s.a).dot(s.delta)/s.length,0,1)
		var distance: float = p.distance_to(s.a+s.delta*t)
		if distance >= closest: continue
		closest = distance
		var half: float = s.width*0.6
		var weight := 1.0-smoothstep(half,half+1.3,distance)
		# Stream geometry dips its centre below the edge. Put the entire bed
		# below that centre, with room for its small animated ripples.
		result = lerpf(height,s.bed+s.drop*t-0.35,weight)
	return result

func disable_flow() -> void:
	routes.clear()
	_segments.clear()
