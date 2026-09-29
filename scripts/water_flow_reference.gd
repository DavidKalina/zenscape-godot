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
var steep := PackedByteArray()
## The edge ring's outflow (ZenScapeWaterFlow: edge_cells ... edge_brink).
var edge_cells := PackedInt32Array()
var edge_inner := PackedInt32Array()
var edge_side := PackedByteArray()
var side_of := PackedInt32Array()
var edge_acc := PackedFloat64Array()
var edge_rate := PackedFloat32Array()
var edge_brink := PackedFloat32Array()
var edge_smooth := 0.5
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
	steep.resize(n)
	steep.fill(0)
	edge_acc.resize(n)
	edge_acc.fill(0.0)
	edge_rate = _zeros(n)
	edge_brink = _zeros(n)
	edge_cells = PackedInt32Array()
	edge_inner = PackedInt32Array()
	edge_side = PackedByteArray()
	side_of.resize(n)
	side_of.fill(-1)
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
	for j in range(h):
		for i in range(w):
			var c := j*w+i
			if kind[c] != EDGE: continue
			var side := 3
			if i == 0: side = 0
			elif i == w-1: side = 1
			elif j == 0: side = 2
			elif j == h-1: side = 3
			elif kind[c-1] == OUTSIDE: side = 0
			elif kind[c+1] == OUTSIDE: side = 1
			elif kind[c-w] == OUTSIDE: side = 2
			var a := clampi(i+[1,-1,0,0][side],0,w-1)
			var b := clampi(j+[0,0,1,-1][side],0,h-1)
			edge_cells.append(c)
			edge_inner.append(b*w+a)
			edge_side.append(side)
			side_of[c] = side

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
	edge_smooth = maxf(0.01,p.get("edge_smooth",edge_smooth))

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
				edge_acc[c] += d*area
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
	_settle_edge(ticks*dt)
	last_usec = Time.get_ticks_usec()-began
	return last_usec

## See ZenScapeWaterFlow::settle_edge.
func _settle_edge(seconds: float) -> void:
	if seconds <= 0.0: return
	var k := 1.0-exp(-seconds/edge_smooth)
	for e in range(edge_cells.size()):
		var c := edge_cells[e]
		var m := edge_inner[e]
		var rate := edge_acc[c]/seconds
		edge_acc[c] = 0.0
		edge_rate[c] = edge_rate[c]+(rate-edge_rate[c])*k
		if edge_rate[c] < 1e-7: edge_rate[c] = 0.0
		var q := edge_rate[c]/cell
		edge_brink[c] = pow(q*q/gravity,1.0/3.0)
		vx[c] = vx[m]
		vz[c] = vz[m]

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
	edge_rate.fill(0.0)
	edge_brink.fill(0.0)

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
	var edge_flux := 0.0
	for c in edge_cells: edge_flux += edge_rate[c]
	return {"edge_flux":edge_flux,"volume":volume*cell*cell,"poured":poured,"drained":drained,"soaked":soaked,"removed":removed,"wet_cells":wet,"usec":last_usec,"steps":steps,"native":false}

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
	var under: bool = p.get("under",false)
	var edge_on: float = p.get("edge_on",0.0005)
	var n := w*h
	var top := PackedFloat32Array()
	top.resize(n)
	var state := PackedByteArray()
	state.resize(n)
	for c in range(n):
		if kind[c] != OUTSIDE and depth[c] > wet:
			state[c] = 1
			top[c] = ground[c]+depth[c]
	for c in edge_cells:
		if edge_rate[c] > edge_on:
			state[c] = 1
			top[c] = ground[c]+maxf(edge_brink[c],wet*1.5)
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
	var shore := _shore_distance(state)
	for c in range(n):
		if state[c] != 1:
			flowing[c] = 0
			continue
		var speed := sqrt(vx[c]*vx[c]+vz[c]*vz[c])
		if speed > flow_on: flowing[c] = 1
		elif speed < flow_off: flowing[c] = 0
	var fade := PackedFloat32Array()
	fade.resize(n)
	for c in range(n):
		if state[c] == 1: fade[c] = clampf((sqrt(vx[c]*vx[c]+vz[c]*vz[c])-flow_off)/maxf(flow_on-flow_off,0.000001),0.0,1.0)
	for j in range(h):
		for i in range(w):
			var c := j*w+i
			if state[c] != 2: continue
			var most := 0.0
			for dj in range(-1,2):
				for di in range(-1,2):
					var a := i+di
					var b := j+dj
					if a < 0 or b < 0 or a >= w or b >= h: continue
					if state[b*w+a] == 1: most = maxf(most,fade[b*w+a])
			fade[c] = most
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
			if state[c] == 1 and side_of[c] >= 0:
				x += [-0.5,0.5,0.0,0.0][side_of[c]]*cell
				z += [0.0,0.0,-0.5,0.5][side_of[c]]*cell
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
				custom1.append_array([fade[c],0.0,0.0,0.0])
			else:
				uv.append(Vector2(shore[c],0.0))
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
		var calm := 0
		# Still water with `under` takes the calm quads, then the moving ones.
		for pass_index in range(2 if set_index == 0 and under else 1):
			if pass_index == 1: calm = indices.size()
			for j in range(h-1):
				for i in range(w-1):
					var a := j*w+i
					var b := a+1
					var c := a+w
					var d := c+1
					if state[a] == 0 or state[b] == 0 or state[c] == 0 or state[d] == 0: continue
					if state[a] != 1 and state[b] != 1 and state[c] != 1 and state[d] != 1: continue
					var moving := flowing[a] != 0 or flowing[b] != 0 or flowing[c] != 0 or flowing[d] != 0
					if moving != (set_index == 1 or pass_index == 1): continue
					var split := absf(top[a]-top[d]) <= absf(top[b]-top[c])
					var va: int = vertex.call(a)
					var vb: int = vertex.call(b)
					var vc: int = vertex.call(c)
					var vd: int = vertex.call(d)
					if split: indices.append_array([va,vb,vd,va,vd,vc])
					else: indices.append_array([va,vb,vc,vb,vd,vc])
		if set_index == 0 and not under: calm = indices.size()
		out["still" if set_index == 0 else "flow"] = {"vertices":vertices,"colors":colors,"uv":uv,"uv2":uv2,"custom0":custom0,"custom1":custom1,"indices":indices,"calm":calm}
	return out

## How far each wet cell (state 1) lies from dry ground, m, by a chamfer
## distance (see ZenScapeWaterFlow::surface).
func _shore_distance(state: PackedByteArray) -> PackedFloat32Array:
	var n := w*h
	var shore := _zeros(n)
	var diagonal := cell*1.41421356
	for c in range(n):
		if state[c] == 1: shore[c] = 1000000.0
	for pass_index in range(2):
		var order := range(n) if pass_index == 0 else range(n-1,-1,-1)
		for c: int in order:
			if state[c] != 1: continue
			var i := c%w
			var j := c/w
			var best := shore[c]
			for dj in range(-1,2):
				for di in range(-1,2):
					if di == 0 and dj == 0: continue
					var a := i+di
					var b := j+dj
					var d := diagonal if di != 0 and dj != 0 else cell
					if a < 0 or b < 0 or a >= w or b >= h:
						best = minf(best,d)
						continue
					var m := b*w+a
					best = minf(best,(shore[m] if state[m] == 1 else 0.0)+d)
			shore[c] = best
	return shore

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

## See ZenScapeWaterFlow::cascades.
func cascades(p: Dictionary) -> Array:
	var wet: float = p.get("wet",0.01)
	var min_speed: float = p.get("min_speed",0.3)
	var slope_on: float = p.get("slope_on",1.0)
	var slope_off: float = p.get("slope_off",0.7)
	var run: float = p.get("run",0.5)
	var min_drop: float = p.get("min_drop",0.6)
	var min_flux: float = p.get("min_flux",0.004)
	var lip_band: float = p.get("lip_band",0.3)
	var band := maxf(0.05,float(p.get("band",0.3)))
	var min_cells: int = p.get("min_cells",3)
	var most: int = p.get("max",6)
	var n := w*h
	if n == 0: return []
	if steep.size() != n:
		steep.resize(n)
		steep.fill(0)
	var top := _zeros(n)
	for c in range(n): top[c] = ground[c]+depth[c]
	for c in range(n):
		var s := 0
		if kind[c] == WATER and depth[c] > wet:
			var speed := sqrt(vx[c]*vx[c]+vz[c]*vz[c])
			if speed > min_speed:
				var m := _index(ox+(c%w+0.5)*cell+vx[c]/speed*run,oz+(c/w+0.5)*cell+vz[c]/speed*run)
				if m >= 0 and m != c and kind[m] != OUTSIDE:
					var slope := (top[c]-top[m])/run
					s = 1 if slope >= (slope_off if steep[c] != 0 else slope_on) else 0
		steep[c] = s
	var found := []
	var group := PackedInt32Array()
	group.resize(n)
	group.fill(-1)
	var serial := 0
	var back := [1,0,3,2]
	for start in range(n):
		if steep[start] == 0 or group[start] >= 0: continue
		var cells: Array[int] = []
		var todo: Array[int] = [start]
		group[start] = serial
		while not todo.is_empty():
			var c: int = todo.pop_back()
			cells.append(c)
			var i := c%w
			var j := c/w
			for dj in range(-1,2):
				for di in range(-1,2):
					var a := i+di
					var b := j+dj
					if a < 0 or b < 0 or a >= w or b >= h: continue
					var m := b*w+a
					if steep[m] != 0 and group[m] < 0:
						group[m] = serial
						todo.append(m)
		var id := serial
		serial += 1
		if cells.size() < min_cells: continue
		var high := -1e9
		var low := 1e9
		for c in cells:
			high = maxf(high,top[c])
			low = minf(low,top[c])
		var inflow := 0.0
		var outflow := 0.0
		var landing := Vector3.ZERO
		var landing_depth := 0.0
		for c in cells:
			var i := c%w
			var j := c/w
			var nb := [c-1 if i > 0 else -1,c+1 if i < w-1 else -1,c-w if j > 0 else -1,c+w if j < h-1 else -1]
			for k in range(4):
				var m: int = nb[k]
				if m < 0 or group[m] == id or kind[m] == OUTSIDE: continue
				inflow += flux[m*4+back[k]]
				var q := flux[c*4+k]
				if q <= 0.0: continue
				outflow += q
				landing += q*Vector3(ox+(m%w+0.5)*cell,top[m],oz+(m/w+0.5)*cell)
				landing_depth += q*depth[m]
		var q := maxf(inflow,outflow)
		if q < min_flux: continue
		var lw := 0.0
		var lip := Vector3.ZERO
		var dir := Vector2.ZERO
		for c in cells:
			if top[c] < high-lip_band: continue
			var k := depth[c]+0.0001
			lw += k
			lip += k*Vector3(ox+(c%w+0.5)*cell,top[c],oz+(c/w+0.5)*cell)
			dir += k*Vector2(vx[c],vz[c])
		lip /= lw
		dir = dir.normalized() if dir.length() > 1e-9 else Vector2(1,0)
		var lo := 1e9
		var hi := -1e9
		for c in cells:
			if top[c] < high-lip_band: continue
			var t := (ox+(c%w+0.5)*cell-lip.x)*-dir.y+(oz+(c/w+0.5)*cell-lip.z)*dir.x
			lo = minf(lo,t)
			hi = maxf(hi,t)
		var reach := 0.0
		for side in [-1.0,1.0]:
			var walked := 0.0
			var d := 0.5*cell
			while d <= 3.0:
				var m := _index(lip.x-dir.y*side*d,lip.z+dir.x*side*d)
				if m < 0 or kind[m] == OUTSIDE or depth[m] <= wet: break
				walked = d
				d += 0.5*cell
			reach += walked
		var lip_half := maxf(0.5*(hi-lo),0.5*reach)+0.5*cell
		var bands := maxi(1,ceili((high-low)/band))
		var sums := PackedFloat64Array()
		sums.resize(bands*7)
		sums.fill(0.0)
		for c in cells:
			var b := mini(bands-1,int((high-top[c])/band))
			var x := ox+(c%w+0.5)*cell
			var z := oz+(c/w+0.5)*cell
			var e := b*7
			sums[e] += 1.0
			sums[e+1] += x
			sums[e+2] += z
			sums[e+3] += top[c]
			sums[e+4] += x*x
			sums[e+5] += z*z
			sums[e+6] += x*z
		var course := PackedVector4Array([Vector4(lip.x,lip.y,lip.z,lip_half)])
		var used: Array[int] = []
		for b in range(bands):
			var e := b*7
			if sums[e] < 1.0: continue
			var y := sums[e+3]/sums[e]
			if y >= lip.y-0.05: continue
			course.append(Vector4(sums[e+1]/sums[e],y,sums[e+2]/sums[e],0.0))
			used.append(b)
		var plunge: Vector3
		if outflow > 0.0: plunge = landing/outflow
		else: plunge = Vector3(course[-1].x,low,course[-1].z)
		course.append(Vector4(plunge.x,plunge.y,plunge.z,0.0))
		for k in range(1,course.size()-1):
			var e := used[k-1]*7
			var mx := sums[e+1]/sums[e]
			var mz := sums[e+2]/sums[e]
			var sxx := sums[e+4]/sums[e]-mx*mx
			var szz := sums[e+5]/sums[e]-mz*mz
			var sxz := sums[e+6]/sums[e]-mx*mz
			var tangent := Vector2(course[k+1].x-course[k-1].x,course[k+1].z-course[k-1].z)
			tangent = tangent.normalized() if tangent.length() > 1e-6 else dir
			var across := Vector2(-tangent.y,tangent.x)
			var spread := maxf(0.0,sxx*across.x*across.x+2.0*sxz*across.x*across.y+szz*across.y*across.y)
			var station := course[k]
			station.w = sqrt(3.0*spread)+0.5*cell
			course[k] = station
		var last := course[course.size()-1]
		last.w = course[course.size()-2].w if course.size() > 2 else lip_half
		course[course.size()-1] = last
		var drop := lip.y-plunge.y
		if drop < min_drop: continue
		found.append({"flux":q,"drop":drop,"cells":cells.size(),"lip":lip,"lip_dir":dir,"lip_half":lip_half,"plunge":plunge,
			"plunge_depth":landing_depth/outflow if outflow > 0.0 else 0.0,"course":course})
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.flux > b.flux)
	return found.slice(0,most)

## See ZenScapeWaterFlow::edge_outflow.
func edge_outflow() -> Dictionary:
	var along: Array[PackedFloat32Array] = [_zeros(h),_zeros(h),_zeros(w),_zeros(w)]
	var total := 0.0
	for e in range(edge_cells.size()):
		var c := edge_cells[e]
		var s := edge_side[e]
		var k := c/w if s < 2 else c%w
		along[s][k] += edge_rate[c]
		total += edge_rate[c]
	return {"sides":along,"total":total}

## See ZenScapeWaterFlow::spills.
func spills(p: Dictionary) -> Array:
	var cell_min: float = p.get("cell_min",0.0004)
	var min_flux: float = p.get("min_flux",0.003)
	var gap: int = p.get("gap",1)
	var most: int = p.get("max",8)
	var found := []
	var order: Array = [[],[],[],[]]
	var along_of := PackedInt32Array()
	along_of.resize(edge_cells.size())
	for e in range(edge_cells.size()):
		var c := edge_cells[e]
		along_of[e] = c/w if edge_side[e] < 2 else c%w
		order[edge_side[e]].append(e)
	for s in range(4):
		var list: Array = order[s]
		list.sort_custom(func(a: int, b: int) -> bool: return along_of[a] < along_of[b])
		var start := ox if s >= 2 else oz
		var k := 0
		while k < list.size():
			if edge_rate[edge_cells[list[k]]] <= cell_min:
				k += 1
				continue
			var end := k
			for m in range(k+1,list.size()):
				if along_of[list[m]]-along_of[list[end]] > gap+1: break
				if edge_rate[edge_cells[list[m]]] > cell_min: end = m
			var q := 0.0
			var t := 0.0
			var tt := 0.0
			var y := 0.0
			var fl := 0.0
			var dep := 0.0
			var sp := 0.0
			for m in range(k,end+1):
				var e: int = list[m]
				var c := edge_cells[e]
				var inner := edge_inner[e]
				var r := edge_rate[c]
				var a := start+(along_of[e]+0.5)*cell
				var out_speed: float = [-vx[inner],vx[inner],-vz[inner],vz[inner]][s]
				q += r
				t += r*a
				tt += r*a*a
				y += r*maxf(ground[inner]+depth[inner],ground[c]+edge_brink[c])
				fl += r*ground[c]
				dep += r*edge_brink[c]
				sp += r*maxf(0.0,out_speed)
			var from := start+along_of[list[k]]*cell
			var to := start+(along_of[list[end]]+1)*cell
			k = end+1
			if q < min_flux: continue
			var mid := t/q
			var half := minf(0.5*(to-from),sqrt(3.0*maxf(0.0,tt/q-mid*mid))+0.5*cell)
			var rim_x: float = [ox,ox+w*cell,0.0,0.0][s]
			var rim_z: float = [0.0,0.0,oz,oz+h*cell][s]
			var normal: Vector2 = [Vector2(-1,0),Vector2(1,0),Vector2(0,-1),Vector2(0,1)][s]
			var lip := Vector3(rim_x,y/q,mid) if s < 2 else Vector3(mid,y/q,rim_z)
			found.append({"side":s,"normal":normal,"flux":q,"lip":lip,"floor":fl/q,"half":half,"from":from,"to":to,"depth":dep/q,"speed":sp/q})
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.flux > b.flux)
	return found.slice(0,most)
