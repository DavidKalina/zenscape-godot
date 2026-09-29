extends RefCounted
## The GDScript mirror of the native live water (native/terrain_kernels/
## water_flow.h, `ZenScapeWaterFlow`), for checkouts without the built
## library and for comparison (`--gdscript-kernels`). Same method names, same
## arithmetic, about fifty times slower, so scripts/water_flow.gd runs it on a
## coarser grid. Keep the two in step.
const OUTSIDE := 0
const WATER := 1
const EDGE := 2
var w := 0
var h := 0
var cell := 0.25
var ox := -14.0
var oz := -14.0
var face := PackedInt32Array()
var weight := PackedFloat32Array()
var kind := PackedByteArray()
var ground := PackedFloat32Array()
var depth := PackedFloat32Array()
var vx := PackedFloat32Array()
var vz := PackedFloat32Array()
var flux := PackedFloat32Array()
var flowing := PackedByteArray()
var gravity := 9.81
var friction := 0.6
var drag := 0.06
var evaporation := 0.00006
var soak := 0.0035
var soak_depth := 0.03
var max_speed := 4.0
var poured := 0.0
var drained := 0.0
var soaked := 0.0
var removed := 0.0
var last_usec := 0
var steps := 0

func configure(width: int, height: int, cell_size: float, origin: Vector2, faces: PackedInt32Array, weights: PackedFloat32Array) -> void:
	w = maxi(width,0)
	h = maxi(height,0)
	cell = cell_size
	ox = origin.x
	oz = origin.y
	var n := w*h
	ground = _zeros(n)
	depth = _zeros(n)
	vx = _zeros(n)
	vz = _zeros(n)
	flux.resize(n*4)
	flux.fill(0.0)
	kind.resize(n)
	kind.fill(OUTSIDE)
	flowing.resize(n)
	flowing.fill(0)
	poured = 0.0
	drained = 0.0
	soaked = 0.0
	removed = 0.0
	steps = 0
	if faces.size() != n*3 or weights.size() != n*2:
		w = 0
		h = 0
		return
	face = faces.duplicate()
	weight = weights.duplicate()
	for c in range(n):
		kind[c] = WATER if face[c*3] >= 0 else OUTSIDE
	for j in range(h):
		for i in range(w):
			var c := j*w+i
			if kind[c] != WATER: continue
			if i == 0 or j == 0 or i == w-1 or j == h-1 or kind[c-1] == OUTSIDE or kind[c+1] == OUTSIDE or kind[c-w] == OUTSIDE or kind[c+w] == OUTSIDE: kind[c] = EDGE

static func _zeros(n: int) -> PackedFloat32Array:
	var values := PackedFloat32Array()
	values.resize(n)
	values.fill(0.0)
	return values

func set_params(p: Dictionary) -> void:
	gravity = p.get("gravity",gravity)
	friction = p.get("friction",friction)
	drag = p.get("drag",drag)
	evaporation = p.get("evaporation",evaporation)
	soak = p.get("soak",soak)
	soak_depth = p.get("soak_depth",soak_depth)
	max_speed = p.get("max_speed",max_speed)

func _index(x: float, z: float) -> int:
	var i := floori((x-ox)/cell)
	var j := floori((z-oz)/cell)
	if i < 0 or j < 0 or i >= w or j >= h: return -1
	return j*w+i

func _resample(heights: PackedFloat32Array) -> void:
	var count := heights.size()
	for c in range(w*h):
		if kind[c] == OUTSIDE: continue
		var a := face[c*3]
		var b := face[c*3+1]
		var e := face[c*3+2]
		if a < 0 or a >= count or b >= count or e >= count: continue
		var u := weight[c*2]
		var v := weight[c*2+1]
		ground[c] = u*heights[a]+v*heights[b]+(1.0-u-v)*heights[e]

func _spread(x: float, z: float, radius: float, volume: float) -> float:
	if volume <= 0.0 or w == 0: return 0.0
	radius = maxf(radius,cell*0.75)
	var i0 := maxi(0,floori((x-radius-ox)/cell))
	var i1 := mini(w-1,floori((x+radius-ox)/cell))
	var j0 := maxi(0,floori((z-radius-oz)/cell))
	var j1 := mini(h-1,floori((z+radius-oz)/cell))
	var total := 0.0
	for pass_index in range(2):
		var scale := 0.0 if pass_index == 0 else volume/(total*cell*cell)
		for j in range(j0,j1+1):
			for i in range(i0,i1+1):
				var c := j*w+i
				if kind[c] != WATER: continue
				var dx := ox+(i+0.5)*cell-x
				var dz := oz+(j+0.5)*cell-z
				var t := (dx*dx+dz*dz)/(radius*radius)
				if t >= 1.0: continue
				var f := (1.0-t)*(1.0-t)
				if pass_index == 0: total += f
				else: depth[c] += f*scale
		if total <= 0.0:
			var c := _index(x,z)
			if c < 0 or kind[c] != WATER: return 0.0
			depth[c] += volume/(cell*cell)
			return volume
	return volume

func _tick(dt: float) -> void:
	var area := cell*cell
	for j in range(h):
		for i in range(w):
			var c := j*w+i
			var at := c*4
			if kind[c] != WATER or depth[c] <= 0.0:
				flux[at] = 0.0
				flux[at+1] = 0.0
				flux[at+2] = 0.0
				flux[at+3] = 0.0
				continue
			var d := depth[c]
			var surface := ground[c]+d
			var damp := 1.0/(1.0+dt*(friction+drag/maxf(d,0.004)))
			var total := 0.0
			for k in range(4):
				var m := -1
				match k:
					0: m = c-1 if i > 0 else -1
					1: m = c+1 if i < w-1 else -1
					2: m = c-w if j > 0 else -1
					3: m = c+w if j < h-1 else -1
				if m < 0 or kind[m] == OUTSIDE:
					flux[at+k] = 0.0
					continue
				var q := maxf(0.0,(flux[at+k]+dt*gravity*d*(surface-(ground[m]+depth[m])))*damp)
				flux[at+k] = q
				total += q
			var have := d*area
			if total*dt > have and total > 0.0:
				var scale := have/(total*dt)
				for k in range(4): flux[at+k] *= scale
	var next := PackedFloat32Array()
	next.resize(w*h)
	for j in range(h):
		for i in range(w):
			var c := j*w+i
			if kind[c] == OUTSIDE: continue
			var at := c*4
			var left := flux[(c-1)*4+1] if i > 0 else 0.0
			var right := flux[(c+1)*4] if i < w-1 else 0.0
			var up := flux[(c-w)*4+3] if j > 0 else 0.0
			var down := flux[(c+w)*4+2] if j < h-1 else 0.0
			var inflow := left+right+up+down
			var outflow := flux[at]+flux[at+1]+flux[at+2]+flux[at+3]
			var d := maxf(0.0,depth[c]+dt*(inflow-outflow)/area)
			var mean := 0.5*(depth[c]+d)
			if mean > 0.0005:
				var u := 0.5*(left-flux[at]+flux[at+1]-right)/(cell*mean)
				var v := 0.5*(up-flux[at+2]+flux[at+3]-down)/(cell*mean)
				var speed := sqrt(u*u+v*v)
				if speed > max_speed:
					u *= max_speed/speed
					v *= max_speed/speed
				vx[c] = u
				vz[c] = v
			else:
				vx[c] = 0.0
				vz[c] = 0.0
			if kind[c] == EDGE:
				drained += d*area
				d = 0.0
			elif d > 0.0:
				var lost := minf(d,dt*(evaporation+soak*maxf(0.0,1.0-d/soak_depth)))
				soaked += lost*area
				d -= lost
				if d < 0.000001:
					soaked += d*area
					d = 0.0
			next[c] = d
	depth = next

func step(heights: PackedFloat32Array, sources: PackedFloat32Array, ticks: int, dt: float) -> int:
	if w == 0: return 0
	var began := Time.get_ticks_usec()
	_resample(heights)
	var count := sources.size()/4
	for t in range(ticks):
		for s in range(count): poured += _spread(sources[s*4],sources[s*4+1],sources[s*4+2],sources[s*4+3]*dt)
		_tick(dt)
		steps += 1
	last_usec = Time.get_ticks_usec()-began
	return last_usec

func add_water(center: Vector2, radius: float, volume: float) -> float:
	var added := _spread(center.x,center.y,radius,volume)
	poured += added
	return added

func drain(center: Vector2, radius: float) -> float:
	var taken := 0.0
	for j in range(h):
		for i in range(w):
			var c := j*w+i
			var dx := ox+(i+0.5)*cell-center.x
			var dz := oz+(j+0.5)*cell-center.y
			if dx*dx+dz*dz >= radius*radius: continue
			taken += depth[c]*cell*cell
			depth[c] = 0.0
			for k in range(4): flux[c*4+k] = 0.0
	removed += taken
	return taken

func get_depth() -> PackedFloat32Array:
	return depth.duplicate()

func set_depth(values: PackedFloat32Array) -> void:
	if values.size() != depth.size(): return
	for c in range(depth.size()): depth[c] = maxf(values[c],0.0) if kind[c] == WATER else 0.0
	flux.fill(0.0)
	vx.fill(0.0)
	vz.fill(0.0)

func get_ground() -> PackedFloat32Array:
	return ground.duplicate()

func wet_cells(min_depth: float) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(depth.size())
	for c in range(depth.size()):
		if depth[c] >= min_depth: out[c] = 1
	return out

func get_velocity() -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(vx.size())
	for c in range(vx.size()): out[c] = Vector2(vx[c],vz[c])
	return out

func stats() -> Dictionary:
	var volume := 0.0
	var wet := 0
	for d in depth:
		volume += d
		if d > 0.01: wet += 1
	return {"volume":volume*cell*cell,"poured":poured,"drained":drained,"soaked":soaked,"removed":removed,"wet_cells":wet,"usec":last_usec,"steps":steps,"native":false}

## See ZenScapeWaterFlow::surface.
func surface(p: Dictionary) -> Dictionary:
	var wet: float = p.get("wet",0.012)
	var lift: float = p.get("lift",0.01)
	var flow_on: float = p.get("flow_on",0.22)
	var flow_off: float = p.get("flow_off",0.12)
	var foam_from: float = p.get("foam_from",0.8)
	var foam_to: float = p.get("foam_to",2.2)
	var depth_scale: float = p.get("depth_scale",0.45)
	var shallow: Color = p.get("shallow",Color(0.2,0.42,0.33))
	var deep: Color = p.get("deep",Color(0.02,0.1,0.11))
	var foam: Color = p.get("foam",Color(0.65,0.8,0.79))
	var n := w*h
	var top := PackedFloat32Array()
	top.resize(n)
	var state := PackedByteArray()
	state.resize(n)
	for c in range(n):
		if kind[c] != OUTSIDE and depth[c] > wet:
			state[c] = 1
			top[c] = ground[c]+depth[c]
	for j in range(h):
		for i in range(w):
			var c := j*w+i
			if state[c] != 0 or kind[c] == OUTSIDE: continue
			var sum := 0.0
			var found := 0
			for dj in range(-1,2):
				for di in range(-1,2):
					var a := i+di
					var b := j+dj
					if a < 0 or b < 0 or a >= w or b >= h: continue
					if state[b*w+a] == 1:
						sum += top[b*w+a]
						found += 1
			if found == 0: continue
			state[c] = 2
			top[c] = minf(sum/found,ground[c]-0.02)
	for c in range(n):
		if state[c] != 1:
			flowing[c] = 0
			continue
		var speed := sqrt(vx[c]*vx[c]+vz[c]*vz[c])
		if speed > flow_on: flowing[c] = 1
		elif speed < flow_off: flowing[c] = 0
	var out := {}
	const DI := [1,1,0,-1,-1,-1,0,1]
	const DJ := [0,1,1,1,0,-1,-1,-1]
	var stride := maxi(1,roundi(0.5/cell))
	for set_index in range(2):
		var slot := PackedInt32Array()
		slot.resize(n)
		slot.fill(-1)
		var vertices := PackedVector3Array()
		var colors := PackedColorArray()
		var uv := PackedVector2Array()
		var uv2 := PackedVector2Array()
		var custom0 := PackedFloat32Array()
		var custom1 := PackedFloat32Array()
		var indices := PackedInt32Array()
		var vertex := func(c: int) -> int:
			if slot[c] >= 0: return slot[c]
			var i := c%w
			var j := c/w
			var x := ox+(i+0.5)*cell
			var z := oz+(j+0.5)*cell
			var y := top[c]+lift
			var d := maxf(0.0,top[c]-ground[c])
			slot[c] = vertices.size()
			vertices.append(Vector3(x,y,z))
			var color := shallow.lerp(deep,1.0-exp(-d/depth_scale))
			uv2.append(Vector2(d,0.0))
			if set_index == 1:
				var u := vx[c]
				var v := vz[c]
				var speed := sqrt(u*u+v*v)
				if state[c] != 1 or speed < 0.0001:
					u = 0.0
					v = 0.0
					for dj in range(-1,2):
						for di in range(-1,2):
							var a := i+di
							var b := j+dj
							if a < 0 or b < 0 or a >= w or b >= h: continue
							if state[b*w+a] == 1:
								u += vx[b*w+a]
								v += vz[b*w+a]
					speed = sqrt(u*u+v*v)
				var ax := u/speed if speed > 0.0001 else 1.0
				var az := v/speed if speed > 0.0001 else 0.0
				uv.append(Vector2(x*ax+z*az,-x*az+z*ax))
				color = color.lerp(foam,smoothstep(foam_from,foam_to,speed)*0.55)
				custom0.append_array([x,y,z,-1.0])
				custom1.append_array([0.0,0.0,0.0,0.0])
			else:
				uv.append(Vector2.ZERO)
				var fetch := PackedFloat32Array()
				for k in range(8):
					var stepped := (1.41421356 if DI[k] != 0 and DJ[k] != 0 else 1.0)*stride*cell
					var run := 0.0
					for s in range(1,19):
						var a: int = i+DI[k]*stride*s
						var b: int = j+DJ[k]*stride*s
						if a < 0 or b < 0 or a >= w or b >= h: break
						if state[b*w+a] != 1: break
						run = s*stepped
						if run >= 9.0: break
					fetch.append(run)
				custom0.append_array(fetch.slice(0,4))
				custom1.append_array(fetch.slice(4,8))
			colors.append(color)
			return slot[c]
		for j in range(h-1):
			for i in range(w-1):
				var a := j*w+i
				var b := a+1
				var c := a+w
				var d := c+1
				if state[a] == 0 or state[b] == 0 or state[c] == 0 or state[d] == 0: continue
				if state[a] != 1 and state[b] != 1 and state[c] != 1 and state[d] != 1: continue
				var moving := flowing[a] != 0 or flowing[b] != 0 or flowing[c] != 0 or flowing[d] != 0
				if moving != (set_index == 1): continue
				var split := absf(top[a]-top[d]) <= absf(top[b]-top[c])
				var va: int = vertex.call(a)
				var vb: int = vertex.call(b)
				var vc: int = vertex.call(c)
				var vd: int = vertex.call(d)
				if split: indices.append_array([va,vb,vd,va,vd,vc])
				else: indices.append_array([va,vb,vc,vb,vd,vc])
		out["still" if set_index == 0 else "flow"] = {"vertices":vertices,"colors":colors,"uv":uv,"uv2":uv2,"custom0":custom0,"custom1":custom1,"indices":indices}
	return out

## See ZenScapeWaterFlow::pools.
func pools(min_depth: float, max_speed_still: float, min_cells: int) -> Array:
	var out := []
	var n := w*h
	var seen := PackedByteArray()
	seen.resize(n)
	var limit := max_speed_still*max_speed_still
	for s in range(n):
		if seen[s] != 0 or kind[s] == OUTSIDE or depth[s] <= min_depth: continue
		if vx[s]*vx[s]+vz[s]*vz[s] > limit: continue
		var todo: Array[int] = [s]
		seen[s] = 1
		var count := 0
		var deepest := s
		var i0 := w
		var j0 := h
		var i1 := -1
		var j1 := -1
		var level := 0.0
		while not todo.is_empty():
			var c: int = todo.pop_back()
			count += 1
			level += ground[c]+depth[c]
			if depth[c] > depth[deepest]: deepest = c
			var i := c%w
			var j := c/w
			i0 = mini(i0,i)
			i1 = maxi(i1,i)
			j0 = mini(j0,j)
			j1 = maxi(j1,j)
			for m in [c-1 if i > 0 else -1,c+1 if i < w-1 else -1,c-w if j > 0 else -1,c+w if j < h-1 else -1]:
				if m < 0 or seen[m] != 0 or kind[m] == OUTSIDE or depth[m] <= min_depth: continue
				if vx[m]*vx[m]+vz[m]*vz[m] > limit: continue
				seen[m] = 1
				todo.append(m)
		if count < min_cells: continue
		out.append({"x":ox+(deepest%w+0.5)*cell,"z":oz+(deepest/w+0.5)*cell,"cells":count,"area":count*cell*cell,"level":level/count,"depth":depth[deepest],
			"rect":Rect2(ox+i0*cell,oz+j0*cell,(i1-i0+1)*cell,(j1-j0+1)*cell)})
	return out

## See ZenScapeWaterFlow::falls.
func falls(min_flux: float, min_drop: float, min_slope: float, reach: float) -> PackedFloat32Array:
	var found := []
	for c in range(w*h):
		if kind[c] != WATER or depth[c] < 0.004: continue
		var q := flux[c*4]+flux[c*4+1]+flux[c*4+2]+flux[c*4+3]
		if q < min_flux: continue
		var speed := sqrt(vx[c]*vx[c]+vz[c]*vz[c])
		if speed < 0.05: continue
		var ax := vx[c]/speed
		var az := vz[c]/speed
		var x := ox+(c%w+0.5)*cell
		var z := oz+(c/w+0.5)*cell
		var y := ground[c]+depth[c]
		var best := 0.0
		var fall := []
		var run := cell
		while run <= reach+0.000001:
			var m := _index(x+ax*run,z+az*run)
			if m < 0 or kind[m] == OUTSIDE: break
			var drop := y-(ground[m]+depth[m])
			if drop >= min_drop and drop >= run*min_slope and drop > best:
				best = drop
				fall = [x,y,z,x+ax*run,ground[m]+depth[m],z+az*run,q]
			run += cell
		if best > 0.0: found.append(fall)
	found.sort_custom(func(a: Array, b: Array) -> bool: return a[6] > b[6])
	var kept := []
	for f: Array in found:
		var near := false
		for k: Array in kept:
			if Vector2(f[0]-k[0],f[2]-k[2]).length_squared() < reach*reach:
				near = true
				break
		if not near: kept.append(f)
		if kept.size() >= 8: break
	var out := PackedFloat32Array()
	for f: Array in kept: out.append_array(f)
	return out
