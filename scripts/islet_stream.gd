extends RefCounted
## A stream on an islet (scripts/sky_islet.gd, a recipe's `stream`): a
## brook rising in a hollow inland and running down a valley it has cut to
## the shore, where it leaves through a notch in the rim. The forest
## landform's (scripts/landform_forest.gd), from the air a darker fold
## through the canopy with a thread of water at its floor. The islet keeps
## it in `stream`; its own `wet`, `water`, `water_arrays` and its top's
## colours ask here when it has one.
##
## In order (`cut`, after the erosion):
##   the course: from the spring (`from`) a way out to the shore heading
##     `toward`, meandering about that heading (MEANDER) and leaning down
##     the ground, a point every STRIDE m until it leaves the land; the
##     shore point nearest where it leaves is its mouth, the lip;
##   the water: its level along the course, from under the spring's ground
##     (SPRING) down to just under the rim at the mouth (MOUTH), never
##     rising, cut up to `incise` under the ground along its middle reach;
##     its half width widening from the spring's to the mouth's (`half`);
##   the valley: the ground cut down to the water's bank over `valley` m
##     each side (a smooth V that rounds into the land round it), the bed
##     BED under the water across the water's width (and a grid point past
##     it, so the coarse faces dip under), and a low bank kept over the
##     water a grid step past that so it never spills.
## Water is read from the course itself (`wet`: within the water's half
## width of it), through a coarse bucket of its segments (BUCKET m).
##
## The recipe's stream: {from: Vector2 (the spring, m in the islet's
## frame), toward: Vector2 (the way out), half: Vector2 (the water's half
## width at the spring and at the mouth, m), valley: the valley's half
## width (m), incise: how far under the ground the water runs at most (m),
## meander: how far the course swings off its heading (radians)}; each but
## `from` and `toward` optional.

const Genesis = preload("res://scripts/genesis_canvas.gd")
const IslandShore = preload("res://scripts/island_shore.gd")

## The course: a point every STRIDE m, swinging off its heading by up to
## MEANDER radians over MEANDER_WAVE (1/m), leaning down the ground by
## DOWNHILL (share of a turn toward the steepest way down), and at most
## LONGEST times the islet's radius long.
const STRIDE := 1.0
const MEANDER := 0.55
const MEANDER_WAVE := 0.045
const DOWNHILL := 0.35
const LONGEST := 3.0
## The water: under the spring's ground (m), under the rim at the mouth
## (m), how far under the ground it cuts along its middle reach (m), and
## the least fall a stride (m).
const SPRING := 0.35
const MOUTH := 0.18
const INCISE := 1.6
const FALL := 0.004
## The water's half width at the spring and the mouth (m), the valley's
## half width (m), the bed's depth under the water (m), and the bank kept
## over the water (m); the bed reaches BED_REACH of a grid step past the
## water's edge, the bank a step past that.
const HALF := Vector2(0.6,1.4)
const VALLEY := 6.0
const BED := 0.22
const BANK := 0.06
const BED_REACH := 0.6
## Segments bucketed this coarse (m) for `wet`.
const BUCKET := 4.0
## The water sheet's rows across, and the fetch along the stream (m).
const ACROSS := 4
const RUN := 6.0

## Cuts the stream `islet.recipe.stream` asks for into its ground and
## keeps it on the islet (`islet.stream`): {course, level, half, lip, out,
## buckets}. Nothing when the spring is off the land.
static func cut(islet: RefCounted, rng: RandomNumberGenerator) -> void:
	var spec: Dictionary = islet.recipe.get("stream",{})
	var from: Vector2 = spec.get("from",Vector2.ZERO)
	if not islet.on_land(from): return
	var heading: Vector2 = (spec.get("toward",Vector2.RIGHT) as Vector2).normalized()
	var meander := float(spec.get("meander",MEANDER))
	var halves: Vector2 = spec.get("half",HALF)
	var valley := float(spec.get("valley",VALLEY))
	var incise := float(spec.get("incise",INCISE))
	var wave := FastNoiseLite.new()
	wave.seed = int(islet.seed)+83
	wave.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	wave.frequency = MEANDER_WAVE
	# The course, out to where it leaves the land.
	var course := PackedVector2Array([from])
	var at := from
	var way := heading
	var most := int(float(islet.radius)*LONGEST/STRIDE)
	var phase := rng.randf()*100.0
	for k in range(most):
		var swing := wave.get_noise_1d(phase+k*STRIDE)*meander*2.0
		var want := heading.rotated(swing)
		# Lean down the ground, never back up the way it came.
		var down := _downhill(islet,at)
		if down != Vector2.ZERO and down.dot(heading) > -0.2: want = (want+down*DOWNHILL).normalized()
		way = way.slerp(want,0.5).normalized()
		at += way*STRIDE
		course.append(at)
		if not islet.on_land(at): break
	if course.size() < 4 or islet.on_land(course[course.size()-1]): return
	# The mouth: the shore point nearest where the course leaves.
	var leaving := course[course.size()-1]
	var points: PackedVector2Array = islet.points
	var edges: PackedInt32Array = islet.shore_edges
	var best := -1
	for k in range(0,edges.size(),3):
		var i := edges[k]
		if best < 0 or points[i].distance_to(leaving) < points[best].distance_to(leaving): best = i
	var lip: Vector2 = points[best]
	var outward: Dictionary = IslandShore._outward(points,edges)
	var out: Vector2 = outward.get(best,way)
	course[course.size()-1] = lip+out*0.3
	# The water's level along the course: falling all the way, under the
	# ground by SPRING at the spring and never more than `incise` under it,
	# down to the mouth's.
	var mouth: float = Genesis.RIM_HEIGHT-MOUTH
	var count := course.size()
	var level := PackedFloat32Array()
	level.resize(count)
	var ground := PackedFloat32Array()
	ground.resize(count)
	for k in range(count): ground[k] = islet.ground_at(course[k]) if islet.on_land(course[k]) else Genesis.RIM_HEIGHT
	var top := ground[0]-SPRING
	for k in range(count):
		var t := float(k)/float(count-1)
		# Cut deepest along the middle reach, easing out at the spring and
		# to the mouth, and by how high the ground stands over the mouth
		# (half of it at most, so the water keeps falling all the way).
		var deep := smoothstep(0.0,0.3,t)*(1.0-smoothstep(0.75,1.0,t))*clampf((ground[k]-mouth)*0.5,0.0,incise)
		var y := maxf(minf(lerpf(top,mouth,t),ground[k]-SPRING*0.5-deep),mouth)
		if k > 0: y = minf(y,level[k-1]-FALL)
		level[k] = y
	level[count-1] = minf(mouth,level[count-2]-FALL)
	var half := PackedFloat32Array()
	half.resize(count)
	for k in range(count): half[k] = lerpf(halves.x,halves.y,smoothstep(0.0,1.0,float(k)/float(count-1)))
	var stream := {"course":course,"level":level,"half":half,"lip":lip,"out":out,"valley":valley}
	stream.buckets = _buckets(course,valley+1.0)
	islet.stream = stream
	# The valley, cut into the ground.
	var heights: PackedFloat32Array = islet.heights
	var step: float = islet.step
	for i in range(points.size()):
		if islet.shore_distance[i] < 0.0: continue
		var p := points[i]
		var near := _nearest(stream,p)
		if near.is_empty(): continue
		var d: float = near.distance
		if d > valley: continue
		var w: float = near.level
		var hw: float = near.half
		var h := heights[i]
		# The bed reaches a grid point past the water's edge, so the faces
		# there dip under the water whatever the grid's step.
		var bed := hw+step*BED_REACH
		var floor_y := w+BANK
		if d < bed: floor_y = w-BED*lerpf(1.0,0.35,smoothstep(hw*0.5,bed,d))
		# A smooth V, rounding into the land at the valley's edge.
		var side := smoothstep(bed,valley,d)
		var cut_y := lerpf(floor_y,h,side*side*(3.0-2.0*side))
		var y := minf(h,cut_y)
		# The bank stands over the water for a grid step past the bed.
		if d >= bed and d < bed+step: y = maxf(y,w+BANK)
		heights[i] = y
	# (A packed array is the islet's own only once set back.)
	islet.heights = heights

## The way down the ground at `p` (unit), or zero on the flat.
static func _downhill(islet: RefCounted, p: Vector2) -> Vector2:
	var e := 1.5
	var gx: float = islet.ground_at(p+Vector2(e,0.0))-islet.ground_at(p-Vector2(e,0.0))
	var gz: float = islet.ground_at(p+Vector2(0.0,e))-islet.ground_at(p-Vector2(0.0,e))
	var g := Vector2(gx,gz)
	if g.length() < 0.02: return Vector2.ZERO
	return -g.normalized()

## Each BUCKET cell's segments (indices of their first point), every
## segment in each cell within `room` of it.
static func _buckets(course: PackedVector2Array, room: float) -> Dictionary:
	var buckets := {}
	for k in range(course.size()-1):
		var a := course[k]
		var b := course[k+1]
		var lo := Vector2i(((a.min(b)-Vector2.ONE*room)/BUCKET).floor())
		var hi := Vector2i(((a.max(b)+Vector2.ONE*room)/BUCKET).floor())
		for x in range(lo.x,hi.x+1):
			for z in range(lo.y,hi.y+1):
				var key := Vector2i(x,z)
				if not buckets.has(key): buckets[key] = []
				(buckets[key] as Array).append(k)
	return buckets

## The course nearest `p` within the valley: {distance, level, half, along
## (the course's index, fractional)}; empty when none is near.
static func _nearest(stream: Dictionary, p: Vector2) -> Dictionary:
	var list: Variant = (stream.buckets as Dictionary).get(Vector2i((p/BUCKET).floor()))
	if list == null: return {}
	var course: PackedVector2Array = stream.course
	var best := INF
	var best_k := -1
	var best_t := 0.0
	for k: int in list:
		var a := course[k]
		var ab := course[k+1]-a
		var t := clampf((p-a).dot(ab)/maxf(ab.length_squared(),0.0001),0.0,1.0)
		var d := p.distance_to(a+ab*t)
		if d < best:
			best = d
			best_k = k
			best_t = t
	if best_k < 0: return {}
	var level: PackedFloat32Array = stream.level
	var half: PackedFloat32Array = stream.half
	return {"distance":best,"along":best_k+best_t,"level":lerpf(level[best_k],level[best_k+1],best_t),"half":lerpf(half[best_k],half[best_k+1],best_t)}

## True over the stream's water.
static func wet(islet: RefCounted, p: Vector2) -> bool:
	var near := _nearest(islet.stream,p)
	return not near.is_empty() and float(near.distance) < float(near.half)

## True within `room` m of the stream's water.
static func near(islet: RefCounted, p: Vector2, room: float) -> bool:
	var near_at := _nearest(islet.stream,p)
	return not near_at.is_empty() and float(near_at.distance) < float(near_at.half)+room

## True where a face at `at`, its lowest corner `y`, lies in the stream's
## bed (under the water, or its bank's waterline): drawn in its gravel.
static func bed(islet: RefCounted, at: Vector2, y: float) -> bool:
	var near_at := _nearest(islet.stream,at)
	return not near_at.is_empty() and float(near_at.distance) < float(near_at.half)+float(islet.step) and y < float(near_at.level)+BANK*0.5

## The stream's water for the islet's `water` (the fall off its mouth, as a
## pond's off its lip): level at the mouth, the spring as its middle.
static func water(islet: RefCounted) -> Dictionary:
	var s: Dictionary = islet.stream
	var level: PackedFloat32Array = s.level
	var half: PackedFloat32Array = s.half
	return {"level":level[level.size()-1],"middle":(s.course as PackedVector2Array)[0],"radius":0.0,"lip":s.lip,"out":s.out,"half":half[half.size()-1]*0.8}

## The water's surface for the plate's still-water material, as a pond's
## (SkyIslet `water_arrays`): a ribbon down the course, ACROSS rows wide,
## its level falling with the stream's. Each vertex carries its depth over
## the bed (UV2.x), a run to the bank for the foam (UV.x), and the fetch:
## RUN up and down the stream, to the bank across it.
static func water_arrays(islet: RefCounted, color: Color, shift: Vector3) -> Array:
	var s: Dictionary = islet.stream
	var course: PackedVector2Array = s.course
	var level: PackedFloat32Array = s.level
	var half: PackedFloat32Array = s.half
	var count := course.size()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var fetch_a := PackedFloat32Array()
	var fetch_b := PackedFloat32Array()
	var dirs := []
	for i in range(8): dirs.append(Vector2.from_angle(TAU*i/8.0))
	var rows := []
	for k in range(count):
		var way := (course[mini(k+1,count-1)]-course[maxi(k-1,0)]).normalized()
		var side := Vector2(-way.y,way.x)
		var row := []
		for r in range(ACROSS+1):
			var u := float(r)/ACROSS*2.0-1.0
			# The sheet reaches under the banks, as far as the bed dips.
			var p := course[k]+side*u*(half[k]+float(islet.step)*BED_REACH)*1.05
			var bank_run := half[k]*(1.0-absf(u))
			var deep := maxf(level[k]-float(islet.ground_at(p)),0.0) if islet.on_land(p) else BED
			var runs := []
			for d: Vector2 in [dirs[0],dirs[1],dirs[2],dirs[3],-dirs[0],-dirs[1],-dirs[2],-dirs[3]]:
				var along := absf(d.dot(way))
				var across := d.dot(side)
				var to_bank := (half[k]*(1.0-u*signf(across)))/maxf(absf(across),0.05)
				runs.append(clampf(lerpf(to_bank,RUN,along*along),0.0,RUN))
			row.append([Vector3(p.x,level[k],p.y),Vector2(bank_run*2.5,0.0),Vector2(deep,0.0),runs])
		rows.append(row)
	var add := func(v: Array) -> void:
		vertices.append((v[0] as Vector3)+shift)
		normals.append(Vector3.UP)
		colors.append(color)
		uv.append(v[1])
		uv2.append(v[2])
		var runs: Array = v[3]
		fetch_a.append_array([runs[0],runs[1],runs[2],runs[3]])
		fetch_b.append_array([runs[4],runs[5],runs[6],runs[7]])
	for k in range(count-1):
		for r in range(ACROSS):
			var a: Array = rows[k][r]
			var b: Array = rows[k][r+1]
			var c: Array = rows[k+1][r+1]
			var d: Array = rows[k+1][r]
			for tri: Array in [[a,b,c],[a,c,d]]:
				var p0: Vector3 = tri[0][0]
				var p1: Vector3 = tri[1][0]
				var p2: Vector3 = tri[2][0]
				# Up-facing in Godot's winding (as SkyIslet `_tri`).
				if (p2-p0).cross(p1-p0).y < 0.0: tri = [tri[0],tri[2],tri[1]]
				for v: Array in tri: add.call(v)
	if vertices.is_empty(): return []
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_CUSTOM0] = fetch_a
	arrays[Mesh.ARRAY_CUSTOM1] = fetch_b
	return arrays
