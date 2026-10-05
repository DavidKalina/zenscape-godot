extends RefCounted
## Scores a candidate world as it will look from the default overview camera.
## Pure CPU work on the inland sampler, so the generator can run it on a worker.
## Each term lies in 0..1; `total` is their weighted sum.
const Desert = preload("res://scripts/desert_landscape.gd")
const Plate = preload("res://scripts/plate.gd")
## Samples the land a metre inside the plate's rim.
const HALF := Plate.HALF-1.0
const STEP := 1.0
const COLUMNS := 32
# The overview framing in studies/diorama.gd `_frame_diorama`, at a typical fitted distance.
const TARGET := Vector3(0,-1.0,0)
const YAW := 0.35
const POLAR := 0.82
const DISTANCE := 46.0
const WEIGHTS := {"drama":0.30,"focal":0.20,"water":0.15,"composition":0.20,"relief":0.15}

static func score(field: RefCounted) -> Dictionary:
	var genome: Dictionary = field.genome
	var eye := TARGET+Vector3(sin(POLAR)*sin(YAW),cos(POLAR),sin(POLAR)*cos(YAW))*DISTANCE
	var view := Basis.looking_at(TARGET-eye,Vector3.UP)
	var heights := PackedFloat32Array()
	var screen := PackedVector2Array()
	var depths := PackedFloat32Array()
	var wet := 0
	var land := 0
	var steps := int(HALF*2.0/STEP)+1
	for zi in range(steps):
		for xi in range(steps):
			var p := Vector2(-HALF+xi*STEP,-HALF+zi*STEP)
			if not field.has_ground(p): continue
			var h: float = field.height(p.x,p.y)
			land += 1
			if field.wet(p): wet += 1
			heights.append(h)
			var point := Vector3(p.x,h,p.y)
			screen.append(_project(eye,view,point))
			depths.append(-(point-eye).dot(view.z))
	if land<steps*steps/4: return {"total":0.0,"drama":0.0,"focal":0.0,"water":0.0,"composition":0.0,"relief":0.0}
	var sorted := heights.duplicate()
	sorted.sort()
	var low: float = sorted[int(sorted.size()*0.05)]
	var median: float = sorted[sorted.size()/2]
	var high: float = sorted[int(sorted.size()*0.95)]
	var top: float = sorted[-1]
	# The same plate with no relief: its far edge is the skyline to beat.
	var flat := PackedVector2Array()
	for p in [Vector2(-Plate.HALF,-Plate.HALF),Vector2(Plate.HALF,-Plate.HALF),Vector2(Plate.HALF,Plate.HALF),Vector2(-Plate.HALF,Plate.HALF)]:
		flat.append(_project(eye,view,Vector3(p.x,median,p.y)))
	var left := INF
	var right := -INF
	for s in flat:
		left = minf(left,s.x)
		right = maxf(right,s.x)
	var width := right-left
	var skyline := PackedFloat32Array()
	var baseline := PackedFloat32Array()
	skyline.resize(COLUMNS)
	skyline.fill(-INF)
	baseline.resize(COLUMNS)
	for c in range(COLUMNS): baseline[c] = _edge_top(flat,left+width*(c+0.5)/COLUMNS)
	var peak := Vector2(0,-INF)
	var mass := 0.0
	var mass_x := 0.0
	var columns: Array = []
	for c in range(COLUMNS): columns.append([])
	for i in range(screen.size()):
		var s: Vector2 = screen[i]
		var c := clampi(int((s.x-left)/width*COLUMNS),0,COLUMNS-1)
		skyline[c] = maxf(skyline[c],s.y)
		columns[c].append(i)
		if s.y>peak.y: peak = s
		var lift := maxf(heights[i]-median,0.0)
		mass += lift
		mass_x += lift*(s.x-left)/width
	# Skyline drama: how far the land rises above the flat plate's far edge,
	# and how much that silhouette moves from column to column.
	var rise := 0.0
	var wiggle := 0.0
	var peaks := 0
	for c in range(COLUMNS):
		if skyline[c]==-INF: skyline[c] = baseline[c]
		rise += maxf(skyline[c]-baseline[c],0.0)/width
	for c in range(1,COLUMNS-1):
		wiggle += absf(skyline[c+1]-2.0*skyline[c]+skyline[c-1])/width
		if skyline[c]>skyline[c-1] and skyline[c]>=skyline[c+1] and skyline[c]-baseline[c]>width*0.03: peaks += 1
	rise /= COLUMNS
	# Layering: from the high overview few summits break the back edge, so
	# inner silhouettes carry the depth. Count land hidden behind nearer ridges.
	var hidden := 0
	for column: Array in columns:
		column.sort_custom(func(a: int,b: int) -> bool: return depths[a]<depths[b])
		var crest := -INF
		for i: int in column:
			if screen[i].y<crest-width*0.004: hidden += 1
			crest = maxf(crest,screen[i].y)
	var layering := float(hidden)/land
	var drama := 0.30*smoothstep(0.0,0.14,rise)+0.35*smoothstep(0.0,0.18,layering)+0.15*smoothstep(0.0,0.6,wiggle)+0.20*clampf(peaks/3.0,0.0,1.0)
	var relief := smoothstep(0.5,7.0,high-low)
	# A focal point is one summit that stands clear of the rest, or a body of water.
	var prominence := (top-high)/maxf(high-low,0.4)
	var along := (peak.x-left)/width
	var wet_share := float(wet)/land
	var focal := maxf(smoothstep(0.02,0.35,prominence)*smoothstep(0.5,3.0,top-median),smoothstep(0.0,0.05,wet_share)*0.8)
	# Water helps up to a lake's worth, then starts drowning the land.
	var water := 0.6
	if genome.composition not in Desert.KINDS or genome.composition=="salt-basin":
		water = 0.35+0.65*smoothstep(0.0,0.05,wet_share)-0.7*smoothstep(0.22,0.45,wet_share)
	# Composition: the summit sits off-centre near a third rather than dead
	# centre or at an edge, visual weight is not piled on one side, and
	# nearer walls do not hide most of the land.
	var thirds := 1.0-smoothstep(0.06,0.20,minf(absf(along-1.0/3.0),absf(along-2.0/3.0)))
	var balance := 0.5 if mass<=0.001 else mass_x/mass
	var composition := 0.40*thirds+0.35*(1.0-smoothstep(0.08,0.25,absf(balance-0.5)))+0.25*(1.0-smoothstep(0.25,0.45,layering))
	var result := {"drama":drama,"focal":focal,"water":water,"composition":composition,"relief":relief}
	var total := 0.0
	for key in WEIGHTS: total += float(WEIGHTS[key])*float(result[key])
	result.total = total
	return result

## Colour harmony for a generated palette. `night` skips the day-sky rules.
static func palette(colors: Dictionary,night: bool) -> float:
	var sky: Color = colors.horizon
	var grass: Color = colors.grass
	var foliage: Color = colors.foliage
	var water: Color = colors.water
	var rock: Color = colors.rock
	var earth: Color = colors.earth
	var terms := []
	# The land reads against the sky.
	if not night: terms.append(smoothstep(0.06,0.22,sky.get_luminance()-foliage.get_luminance()))
	# Water reads against the bank.
	terms.append(smoothstep(0.03,0.12,absf(water.h-grass.h))*0.5+smoothstep(0.02,0.10,absf(water.get_luminance()-grass.get_luminance()))*0.5)
	# Ground colours share a saturation family instead of one shouting.
	var sats := [grass.s,foliage.s,rock.s,earth.s]
	terms.append(1.0-smoothstep(0.18,0.34,sats.max()-sats.min()))
	# Grass stays clear of mud: enough chroma at a readable value.
	terms.append(smoothstep(0.08,0.20,grass.s*grass.v))
	# Rock separates from the grass it sits in.
	terms.append(smoothstep(0.04,0.14,absf(rock.get_luminance()-grass.get_luminance())))
	var sum := 0.0
	for term in terms: sum += term
	return sum/terms.size()

static func _project(eye: Vector3,view: Basis,point: Vector3) -> Vector2:
	var v := point-eye
	var depth := -v.dot(view.z)
	return Vector2(v.dot(view.x),v.dot(view.y))/maxf(depth,0.01)

## Highest screen y of the flat plate outline at screen x.
static func _edge_top(outline: PackedVector2Array,x: float) -> float:
	var best := -INF
	for i in range(outline.size()):
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i+1)%outline.size()]
		if (x<a.x)==(x<b.x) and x!=a.x: continue
		var t := 0.0 if is_equal_approx(a.x,b.x) else (x-a.x)/(b.x-a.x)
		best = maxf(best,lerpf(a.y,b.y,clampf(t,0.0,1.0)))
	return best
