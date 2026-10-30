extends RefCounted
## One hero tower of the Peak's crown, built on a worker: plain data, no
## nodes (scripts/endless/rocks/peak_towers.gd stands it).
##
## Not a lathe and not rock_build's noisy loft. The section is a star polygon
## of straight edges: four main corners of an irregular quad and MIDS corners
## on each side between them. Every corner has its own width with height:
##   setbacks    each side steps in at its own heights (a sloped ledge across
##               that side), now and then out (a roof), so the outline changes
##               up the tower and the four walls don't match.
##   buttresses  a corner stands far out at the foot and dies up the wall,
##               its shoulder sloping, a fin of two big planes.
##   gullies     a corner pulled in over a span of height: a V cut.
## On those planes: the beds (`strata`, one geology for the whole crown, tilted,
## the same bed at the same height on each tower). They are uneven on purpose:
## massive cliffs, sets of thin ribbons, long dull stretches where they barely
## show. Each bed pinches out along the wall, each of the 12 panels stands a few
## metres off its neighbour (a fault at each corner) and joints cut up through
## them, so no line runs round a tower. A setback's ledge breaks the same way:
## along the wall it wanders and goes from a shelf to a steep ramp (`_ledge`).
## The arêtes chip, bed by bed. The top is a cap of rings closing on a broken
## surface (`_top`: snapped at a tilt, stepped, a cleft through it), never flat.
##
## What it gives the paint, past the shape: the land's paint lays snow by the
## vertex normal's height (endless_ground, `snowy`), so `_hold_snow` writes it:
## where the snow won't hold, a shelf's normal lies down to a wall's, and in the
## gullies' streaks a wall's stands up to a shelf's. The geometry stays true;
## only the paint reads these. CUSTOM3's g and b take the beds (`_paint_beds`).
##
## Levels: the skin is rows x columns, rows and columns multiples of EDGE with
## every corner on a multiple of EDGE columns, so strides 1, 2, 4, 8 and 16
## share the same vertices and all keep the arêtes.

const Field = preload("res://scripts/endless/land_field.gd")
const Build = preload("res://scripts/endless/rocks/rock_build.gd")
const RockShape = preload("res://scripts/endless/rock_shape.gd")

const SIDES := 4
## Corners a side between the main ones.
const MIDS := 2
## Points an edge (a power of two: see Levels above).
const EDGE := 16
## Metres a row, near.
const ROW := 6.0
## Rows of the cap (a multiple of EDGE).
const CAP_ROWS := 16
const LEVELS := 5
## Each coarser level's error (m): where Godot swaps it in (about 1 km per m).
const LOD_ERROR := [1.0,3.5,12.0,40.0]
## The level the collider takes, and the far mesh.
const COLLIDER_LEVEL := 1
const FAR_LEVEL := 3
## Below its base a tower goes on this share of its height, flaring by
## FLARE, so it stands buried in any slope.
const SINK := 0.16
const SINK_LEAST := 60.0
const FLARE := 0.5
## The apron: the foot's flare over the first APRON.y of the height.
const APRON := Vector2(0.24,0.14)
## Width left at the top before the setbacks.
const TOP_WIDTH := 0.74
## The setbacks a side, the drop of each (share of the width) and the
## height of a ledge (share of the height).
const STEPS := Vector2i(3,5)
const DROP := Vector2(0.09,0.2)
const LEDGE := Vector2(0.008,0.03)
## The chance a setback high up is a roof instead: the block above stands out.
const ROOF := 0.2
const ROOF_OUT := Vector2(0.05,0.1)
## Corners of each kind on a tower.
const BUTTRESS := Vector2i(3,5)
const BUTTRESS_OUT := Vector2(0.25,0.7)
const BUTTRESS_END := Vector2(0.28,0.72)
const GULLY := Vector2i(2,4)
const GULLY_IN := Vector2(0.14,0.3)
## The detail, m at a girth of 100 m.
const BED_AMP := 6.0
const BLOCK_AMP := 2.6
const CHIP_AMP := 6.0
const JOINT_AMP := 1.2
const WARP_AMP := 2.4
## A bed's pinch along the wall: the span of its noise (m), least and most.
const PINCH_SPAN := Vector2(70.0,190.0)
## The beds' fold across the crown (m, span m) and each panel's fault (m).
const FOLD := Vector2(16.0,420.0)
const FAULT := 22.0
## The joints: the columns over JOINT_ODDS (a hash, -1..1), this deep (m at a
## girth of 100 m) over spans of this height (m).
const JOINT_CUT := 4.0
const JOINT_ODDS := 0.72
const JOINT_SPAN := 120.0
## A ledge's break: how far a block stands off it (share of the height), the
## blocks' length along the wall (m, about), the hash a block goes steep over
## and the steep ramp's height (share of the height).
const LEDGE_WANDER := 0.014
const LEDGE_SPAN := 52.0
const LEDGE_ODDS := -0.25
const LEDGE_RAMP := 0.13
## The snow's hold: the normals' height a shelf lies down to where it won't
## hold, and a gully's streak stands up to.
const SNOW_OFF := 0.3
const SNOW_ON := 0.66
## How far the beds push the paint's shape, g and b (of 255).
const BAND_G := 36.0
const BAND_B := 80.0
## The top: its share of the height, the least of it (share of the girth, so a
## shorter tower's top still reads broken) and how far down the walls it reaches.
const CAP := Vector2(0.07,0.11)
const CAP_GIRTH := Vector2(0.8,1.2)
const CAP_REACH := 1.6
## The flight's solid: slices this far apart, directions a slice, read
## off every SOLID_STRIDE-th column.
const SOLID_DY := 10.0
const SOLID_WAYS := 72
const SOLID_STRIDE := 4
## The top's height field: its cell (m) and an empty cell's value.
const TOP_CELL := 6.0
const NO_TOP := -1e9
## The strata's height range (m over the sea).
const STRATA_LOW := -100.0
const STRATA_SPAN := 2400

## The crown's one geology: {hard (per m, -1 soft .. 1 hard), bed (per m,
## its bed's number), power (per bed, 0 nearly gone .. 1 strong), dip (Vector2,
## the beds' fall per m of world XZ)}. Uneven by packets: a massive cliff with a
## soft slot under it, a set of thin ribbons, a long dull stretch.
static func strata(land_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = land_seed*7919+13
	var raw := PackedFloat32Array()
	raw.resize(STRATA_SPAN)
	var bed := PackedInt32Array()
	bed.resize(STRATA_SPAN)
	var power := PackedFloat32Array()
	var y := [0]
	var lay := func(th: int, h: float, strong: float) -> void:
		for k in range(y[0],mini(y[0]+th,STRATA_SPAN)):
			raw[k] = h
			bed[k] = power.size()
		power.append(strong)
		y[0] += th
	while y[0] < STRATA_SPAN:
		var roll := rng.randf()
		if roll < 0.32:
			lay.call(rng.randi_range(10,20),-1.0,rng.randf_range(0.5,1.0))
			lay.call(rng.randi_range(55,150),rng.randf_range(0.6,1.0),rng.randf_range(0.55,1.0))
		elif roll < 0.58:
			for m in rng.randi_range(3,6):
				lay.call(rng.randi_range(9,20),1.0 if m%2 == 0 else -0.9,rng.randf_range(0.35,1.0))
		else:
			lay.call(rng.randi_range(30,110),rng.randf_range(-0.5,0.4),rng.randf_range(0.0,0.22))
	# Eased over a few metres, so a ledge has a face.
	var hard := PackedFloat32Array()
	hard.resize(STRATA_SPAN)
	for k in STRATA_SPAN:
		var s := 0.0
		for o in range(-3,4): s += raw[clampi(k+o,0,STRATA_SPAN-1)]
		hard[k] = s/7.0
	return {"hard":hard,"bed":bed,"power":power,"dip":Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(0.08,0.16)}

## The tower's plan from its entry: pure in its seed.
static func _plan(t: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var k_all := SIDES*(MIDS+1)
	var yaw := rng.randf()*TAU
	var aspect := sqrt(rng.randf_range(1.0,1.5))
	var main: Array[Vector2] = []
	for m in SIDES:
		var a := TAU*(m+0.5)/SIDES+rng.randf_range(-0.2,0.2)
		var r := rng.randf_range(1.22,1.52)
		main.append(Vector2(cos(a)*r*aspect,sin(a)*r/aspect).rotated(yaw))
	var corners := PackedVector2Array()
	corners.resize(k_all)
	var kind := PackedInt32Array()   # 0 a main corner, else on a side
	kind.resize(k_all)
	for m in SIDES:
		var a: Vector2 = main[m]
		var b: Vector2 = main[(m+1)%SIDES]
		corners[m*(MIDS+1)] = a
		var out := (b-a).normalized()
		out = Vector2(out.y,-out.x)
		for q in range(1,MIDS+1):
			var along := float(q)/(MIDS+1)+rng.randf_range(-0.09,0.09)
			corners[m*(MIDS+1)+q] = a.lerp(b,along)+out*rng.randf_range(-0.05,0.09)
			kind[m*(MIDS+1)+q] = 1
	var steps: Array = []
	for s in SIDES:
		var list: Array = []
		var count := rng.randi_range(STEPS.x,STEPS.y)
		for n in count:
			var u := (n+rng.randf_range(0.2,0.9))/count*0.86+0.07
			var drop := rng.randf_range(DROP.x,DROP.y)
			if u > 0.45 and rng.randf() < ROOF: drop = -rng.randf_range(ROOF_OUT.x,ROOF_OUT.y)
			list.append([u,drop,rng.randf_range(-0.05,0.05),rng.randf_range(LEDGE.x,LEDGE.y),rng.randi_range(1,4000)])
		steps.append(list)
	# Corners for the buttresses first, gullies from the mids left.
	var order: Array = []
	for k in k_all: order.append(k)
	for k in range(k_all-1,0,-1):
		var o := rng.randi_range(0,k)
		var swap: Variant = order[k]
		order[k] = order[o]
		order[o] = swap
	var outs := {}
	var cuts := {}
	var left := rng.randi_range(BUTTRESS.x,BUTTRESS.y)
	for k: int in order:
		if left <= 0: break
		outs[k] = [rng.randf_range(BUTTRESS_OUT.x,BUTTRESS_OUT.y),rng.randf_range(BUTTRESS_END.x,BUTTRESS_END.y)]
		left -= 1
	left = rng.randi_range(GULLY.x,GULLY.y)
	for k: int in order:
		if left <= 0: break
		if outs.has(k) or kind[k] == 0: continue
		var u0 := rng.randf_range(0.04,0.5)
		cuts[k] = [rng.randf_range(GULLY_IN.x,GULLY_IN.y),u0,u0+rng.randf_range(0.2,0.45)]
		left -= 1
	var faults := PackedFloat32Array()
	for k in k_all: faults.append(rng.randf_range(-FAULT,FAULT))
	var lean: Vector2 = t.lean
	var bow_way := Vector2(-lean.y,lean.x).normalized() if lean.length() > 0.01 else Vector2.from_angle(rng.randf()*TAU)
	return {"corners":corners,"kind":kind,"steps":steps,"outs":outs,"cuts":cuts,"lean":lean,"faults":faults,
		"bow":bow_way*rng.randf_range(-0.09,0.09)*(float(t.tip)-float(t.base)),"knee":rng.randf_range(0.45,0.8)}

## A side's share of the width at `u`, `at` of the way along it.
static func _side(steps: Array, u: float, at: float) -> float:
	var w := 1.0
	for s: Array in steps:
		var from := float(s[0])+float(s[2])*(at-0.5)
		var d := clampf((u-from)/float(s[3]),0.0,1.0)
		w *= 1.0-float(s[1])*d*d*(3.0-2.0*d)
	return w

## Where this column's ledges stand off the side's straight ones (share of the
## width, plus is out). Each ledge is broken into blocks along the wall: a
## block's shelf stands a little higher or lower, and some go to a steep ramp
## that holds no snow. `along` is the column's way round, m.
static func _ledge(steps: Array, u: float, at: float, along: float) -> float:
	var out := 0.0
	for s: Array in steps:
		var from := float(s[0])+float(s[2])*(at-0.5)
		var rise := float(s[3])
		if u < from-LEDGE_WANDER or u > from+LEDGE_RAMP+LEDGE_WANDER: continue
		var id := int(s[4])
		var cell := int(floor((along+float(id))/(LEDGE_SPAN*(0.7+fposmod(float(id)*0.37,0.8)))))
		var ramp := _hash(cell,id+7)
		var from2 := from+_hash(cell,id)*LEDGE_WANDER
		var rise2 := rise if ramp < LEDGE_ODDS else lerpf(LEDGE_RAMP*0.4,LEDGE_RAMP,(ramp-LEDGE_ODDS)/(1.0-LEDGE_ODDS))
		var a := clampf((u-from)/rise,0.0,1.0)
		var b := clampf((u-from2)/rise2,0.0,1.0)
		out += float(s[1])*(a*a*(3.0-2.0*a)-b*b*(3.0-2.0*b))
	return out

## The width of everything at `u`.
static func _width(u: float, sink_u: float) -> float:
	if u <= 0.0: return (1.0+APRON.x)*(1.0+FLARE*clampf(-u/sink_u,0.0,1.0))
	var w := lerpf(1.0,TOP_WIDTH,pow(u,0.9))
	return w*(1.0+APRON.x*(1.0-smoothstep(0.0,APRON.y,u)))

## The corners' offsets (m, off the axis) at `u`.
static func _section(pl: Dictionary, u: float, g: float, sink_u: float) -> PackedVector2Array:
	var corners: PackedVector2Array = pl.corners
	var steps: Array = pl.steps
	var n := corners.size()
	var out := PackedVector2Array()
	out.resize(n)
	var w := _width(u,sink_u)
	for k in n:
		var side := k/(MIDS+1)
		var at := float(k%(MIDS+1))/(MIDS+1)
		var share: float = _side(steps[side],u,at)
		if k%(MIDS+1) == 0: share = minf(share,_side(steps[(side+SIDES-1)%SIDES],u,1.0))
		var f := w*share
		var o: Variant = pl.outs.get(k)
		if o != null:
			f += float(o[0])*(1.0-smoothstep(float(o[1])*0.55,float(o[1]),u))
		var c: Variant = pl.cuts.get(k)
		if c != null:
			f -= float(c[0])*smoothstep(float(c[1]),float(c[1])+0.05,u)*(1.0-smoothstep(float(c[2])-0.04,float(c[2]),u))
		out[k] = corners[k]*f*g
	return out

## The axis's offset (m) off the base at `u`: the lean, mostly late, a
## knee in it, and a bow across it.
static func _axis(pl: Dictionary, u: float) -> Vector2:
	if u <= 0.0: return Vector2.ZERO
	var knee := float(pl.knee)
	var eased := u*u*(1.0+knee)-u*u*u*knee
	return (pl.lean as Vector2)*eased+(pl.bow as Vector2)*sin(PI*minf(u,1.0))

## The broken top's height (share of the cap's) at `p` (-1..1 across the
## rim): a snapped surface tilted toward `way`, stepped across `cross`, a
## cleft through it.
static func _top(p: Vector2, way: Vector2, cross: Vector2, cleft: Vector2, gap: float) -> float:
	var tilt := clampf(0.5+0.5*p.dot(way),0.0,1.0)
	var x := (p.dot(cross)+1.0)*1.6
	var lvl := floorf(x)
	var stair := lerpf(fposmod(lvl*0.37,1.0),fposmod((lvl+1.0)*0.37,1.0),smoothstep(0.72,1.0,x-lvl))
	var f := tilt*0.72+stair*0.28
	var c := absf(p.dot(cleft)-gap)
	return f*(0.55+0.45*smoothstep(0.03,0.2,c))

## A hash in -1..1 of two ints.
static func _hash(a: int, b: int) -> float:
	var h := (a*73856093)^(b*19349663)
	h = (h^(h>>13))*1274126177
	return float((h^(h>>16))&0xffff)/32767.5-1.0

## Built: {arrays, lods, faces (the collider's triangles), solid, tris
## ([per level]), far ({v, c, i}: the far level's own arrays), height,
## foot}. Everything local to the tower's base point; `solid` too.
static func build(t: Dictionary, beds: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(t.seed)
	var pl := _plan(t,rng)
	var over := float(t.base)
	var tall := float(t.tip)-over
	var g := float(t.girth)
	var gs := g/100.0
	var sink := maxf(tall*SINK,SINK_LEAST)
	var sink_u := sink/tall
	var cap := minf(maxf(tall*rng.randf_range(CAP.x,CAP.y),g*rng.randf_range(CAP_GIRTH.x,CAP_GIRTH.y)),tall*0.3)
	var rim_y := tall-cap
	var body_rows := maxi(EDGE,int(ceil((rim_y+sink)/ROW/EDGE))*EDGE)
	var dy := (rim_y+sink)/body_rows
	var k_all: int = (pl.corners as PackedVector2Array).size()
	var cols := k_all*EDGE
	var rows := body_rows+CAP_ROWS
	# The top's surface, normalised so its highest is the tip.
	var way := Vector2.from_angle(rng.randf()*TAU)
	var cross := way.rotated(rng.randf_range(1.1,2.0))
	var cleft := way.rotated(rng.randf_range(0.5,1.2))
	var gap := rng.randf_range(-0.3,0.3)
	var top_most := 0.0
	for a in range(-20,21):
		for b in range(-20,21):
			top_most = maxf(top_most,_top(Vector2(a,b)/20.0,way,cross,cleft,gap))
	var rim_at: PackedVector2Array = _section(pl,rim_y/tall,g,sink_u)
	var rim_r := 1.0
	for o in rim_at: rim_r = maxf(rim_r,o.length())
	var noise := FastNoiseLite.new()
	noise.seed = int(t.seed)
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 1.0
	noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	# Each column's way round, m at the base's size: blocks hold up the wall.
	var unit: PackedVector2Array = pl.corners
	var round_at := PackedFloat32Array()
	round_at.resize(cols+1)
	for j in cols:
		var k := j/EDGE
		var e := unit[(k+1)%k_all]-unit[k]
		round_at[j+1] = round_at[j]+e.length()*g/EDGE
	var hard: PackedFloat32Array = beds.hard
	var bed: PackedInt32Array = beds.bed
	var power: PackedFloat32Array = beds.power
	var dip: Vector2 = beds.dip
	var faults: PackedFloat32Array = pl.faults
	var steps: Array = pl.steps
	var base_w := Vector3((t.at as Vector2).x,over+Field.SEA_Y,(t.at as Vector2).y)
	var rock := Field.ROCK
	var v := PackedVector3Array()
	var c := PackedColorArray()
	v.resize((rows+1)*cols+1)
	c.resize((rows+1)*cols+1)
	var rim := PackedVector2Array()
	rim.resize(cols)
	var rim_o := PackedVector2Array()
	rim_o.resize(cols)
	# Each vertex's snow (0 it won't hold, 1 it holds), its gully streak (1 the
	# snow runs down a wall) and band (-1 sunk .. 1 proud: the paint's beds).
	var hold := PackedFloat32Array()
	hold.resize((rows+1)*cols+1)
	var streaks := PackedFloat32Array()
	streaks.resize((rows+1)*cols+1)
	var band := PackedFloat32Array()
	band.resize((rows+1)*cols+1)
	var rim_axis := Vector2.ZERO
	var at := 0
	var warp_from := rim_y-cap*CAP_REACH
	for i in range(body_rows+1):
		var y := -sink+i*dy
		var u := y/tall
		var section := _section(pl,u,g,sink_u)
		var axis := _axis(pl,u)
		var warp := smoothstep(warp_from,rim_y,y)
		if i == body_rows: rim_axis = axis
		for j in cols:
			var k := j/EDGE
			var tt := float(j%EDGE)/EDGE
			var a := section[k]
			var b := section[(k+1)%k_all]
			var e := b-a
			var nrm := Vector2(e.y,-e.x).normalized()
			if j%EDGE == 0:
				var e0 := a-section[(k+k_all-1)%k_all]
				nrm = (nrm+Vector2(e0.y,-e0.x).normalized()).normalized()
			var o := a.lerp(b,tt)
			# The bed here: tilted across the crown, folded, faulted at the corners.
			var wx := base_w.x+axis.x+o.x
			var wz := base_w.z+axis.y+o.y
			var wy := base_w.y+y
			var fold := noise.get_noise_2d(wx/FOLD.y,wz/FOLD.y)*FOLD.x
			var sy := int(wy-Field.SEA_Y+dip.x*wx+dip.y*wz-STRATA_LOW+fold+faults[k])
			sy = clampi(sy,0,STRATA_SPAN-1)
			var bn := bed[sy]
			# It pinches out along the wall, each bed at its own span.
			var span := lerpf(PINCH_SPAN.x,PINCH_SPAN.y,fposmod(float(bn)*0.618,1.0))
			var pinch := smoothstep(-0.3,0.2,noise.get_noise_2d(round_at[j]/span,float(bn)*9.7))
			var strong := power[bn]*pinch
			var d := hard[sy]*strong*BED_AMP
			var sa: float = round_at[j]+float(bn)*37.0
			var bw := 24.0+fposmod(float(bn)*31.0,56.0)
			d += _hash(bn,int(floor(sa/bw)))*BLOCK_AMP*(0.3+0.7*strong)
			var near_corner := 1.0-minf(tt,1.0-tt)*2.0
			d -= maxf(0.0,_hash(bn+91,k))*CHIP_AMP*near_corner*near_corner*(0.35+0.65*strong)
			d += noise.get_noise_3d(round_at[j]/26.0+57.0,wy/140.0,float(k))*JOINT_AMP
			d += noise.get_noise_3d(wx/70.0,wy/70.0,wz/70.0)*WARP_AMP
			# A joint: a crack up the wall, here and there along its height.
			var jh := _hash(j,int(t.seed))
			if jh > JOINT_ODDS: d -= (jh-JOINT_ODDS)/(1.0-JOINT_ODDS)*JOINT_CUT*smoothstep(-0.1,0.25,noise.get_noise_2d(float(j)*3.1,wy/JOINT_SPAN))
			d *= gs
			var side := k/(MIDS+1)
			var side_at := (float(k%(MIDS+1))+tt)/(MIDS+1)
			d += _ledge(steps[side],u,side_at,round_at[j])*o.length()
			band[at] = hard[sy]*strong
			# The snow: dashes along the beds, broken down the fall line, thicker
			# on the hard beds' tops; streaks of it down a gully.
			var dash := noise.get_noise_2d(round_at[j]/85.0,float(sy)/15.0)+noise.get_noise_2d(round_at[j]/27.0+31.0,float(sy)/7.0)*0.5
			var fall := noise.get_noise_2d(round_at[j]/15.0,wy/60.0)
			hold[at] = smoothstep(0.12,0.46,dash+fall*0.35+maxf(band[at],0.0)*0.12)
			var cut: Variant = pl.cuts.get(k)
			if cut == null: cut = pl.cuts.get((k+1)%k_all)
			if cut != null and near_corner > 0.7 and u > float(cut[1]) and u < float(cut[2]) and fall > 0.18: streaks[at] = 1.0
			var q := o+nrm*d
			var lift := 0.0
			if warp > 0.0:
				lift = _top(o/rim_r,way,cross,cleft,gap)/top_most*cap*warp
			v[at] = Vector3(axis.x+q.x,y+lift,axis.y+q.y)
			var shade := 0.82+d*0.01
			c[at] = Color(rock.r*shade,rock.g*shade,rock.b*shade*0.97,0.0)
			at += 1
			if i == body_rows:
				rim[j] = q
				rim_o[j] = o
	for r in range(1,CAP_ROWS+1):
		var keep := 1.0-float(r)/CAP_ROWS*0.97
		for j in cols:
			var q := rim[j]*keep
			var lift := _top(rim_o[j]*keep/rim_r,way,cross,cleft,gap)/top_most*cap
			v[at] = Vector3(rim_axis.x+q.x,rim_y+lift,rim_axis.y+q.y)
			hold[at] = smoothstep(-0.1,0.15,noise.get_noise_3d(q.x/30.0+base_w.x,lift/16.0,q.y/30.0+base_w.z))
			c[at] = Color(rock.r*0.8,rock.g*0.8,rock.b*0.8,0.0)
			at += 1
	var last := _top(Vector2.ZERO,way,cross,cleft,gap)/top_most*cap
	v[at] = Vector3(rim_axis.x,rim_y+last,rim_axis.y)
	c[at] = Color(rock.r*0.8,rock.g*0.8,rock.b*0.8,0.0)
	var cap_vertex := at
	var levels: Array = []
	for l in range(LEVELS):
		var idx := PackedInt32Array()
		var s := 1 << l
		idx.resize((rows/s)*(cols/s)*6+(cols/s)*3)
		var w := 0
		for i in range(0,rows,s):
			for j in range(0,cols,s):
				var a0 := i*cols+j
				var a1 := i*cols+(j+s)%cols
				var b0 := a0+s*cols
				var b1 := a1+s*cols
				idx[w] = a0
				idx[w+1] = b1
				idx[w+2] = b0
				idx[w+3] = a0
				idx[w+4] = a1
				idx[w+5] = b1
				w += 6
		for j in range(0,cols,s):
			idx[w] = cap_vertex
			idx[w+1] = rows*cols+j
			idx[w+2] = rows*cols+(j+s)%cols
			w += 3
		levels.append(idx)
	var n := Build._normals(v,levels[0])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_COLOR] = c
	arrays[Mesh.ARRAY_INDEX] = levels[0]
	RockShape.bake(arrays)
	_paint_beds(arrays,band)
	arrays[Mesh.ARRAY_NORMAL] = _hold_snow(n,_blur(hold,rows,cols),_blur(streaks,rows,cols))
	var lods := {}
	var tris: Array = [(levels[0] as PackedInt32Array).size()/3]
	for l in range(1,LEVELS):
		lods[float(LOD_ERROR[l-1])] = levels[l]
		tris.append((levels[l] as PackedInt32Array).size()/3)
	var coarse: PackedInt32Array = levels[COLLIDER_LEVEL]
	var faces := PackedVector3Array()
	faces.resize(coarse.size())
	for i in range(coarse.size()): faces[i] = v[coarse[i]]
	return {"arrays":arrays,"lods":lods,"faces":faces,"tris":tris,"height":tall,"foot":-sink,
		"solid":_solid(v,rows,body_rows,cols,pl,tall),"far":_far(v,levels[FAR_LEVEL],band)}

## Lays the beds into the baked shape, as the paint reads it: a soft bed's
## groove dark and its recess in shade, a hard one's edge worn pale.
static func _paint_beds(arrays: Array, band: PackedFloat32Array) -> void:
	var shape: Variant = arrays[Mesh.ARRAY_CUSTOM3]
	if shape == null: return
	var bytes: PackedByteArray = shape
	for i in band.size():
		var b := band[i]
		bytes[i*4+1] = clampi(bytes[i*4+1]+int(b*BAND_G),0,255)
		bytes[i*4+2] = clampi(bytes[i*4+2]+int(b*BAND_B),0,255)
	arrays[Mesh.ARRAY_CUSTOM3] = bytes

## A skin's per-vertex value, eased twice over its neighbours, so what the paint
## cuts at it crosses several vertices and its ragged edge has room to work.
static func _blur(a: PackedFloat32Array, rows: int, cols: int) -> PackedFloat32Array:
	var src := a
	for pass_n in 2:
		var out := src.duplicate()
		for i in range(rows+1):
			var up := maxi(i-1,0)*cols
			var dn := mini(i+1,rows)*cols
			var row := i*cols
			for j in cols:
				var l := row+(j+cols-1)%cols
				var r := row+(j+1)%cols
				out[row+j] = (src[row+j]*2.0+src[l]+src[r]+src[up+j]+src[dn+j])/6.0
		src = out
	return src

## The normals the paint lays snow by: where `hold` is 0 a shelf lies down to a
## wall's height, at 1 it stays; `streaks` stand a wall up to a shelf's.
static func _hold_snow(n: PackedVector3Array, hold: PackedFloat32Array, streaks: PackedFloat32Array) -> PackedVector3Array:
	var out := n.duplicate()
	for i in n.size():
		var m := n[i]
		var ny := m.y
		if ny > SNOW_OFF: ny = lerpf(SNOW_OFF,ny,hold[i])
		ny = lerpf(ny,maxf(ny,SNOW_ON),streaks[i])
		if ny == m.y: continue
		var flat := Vector2(m.x,m.z)
		if flat.length() < 0.001: flat = Vector2.RIGHT
		flat = flat.normalized()*sqrt(1.0-ny*ny)
		out[i] = Vector3(flat.x,ny,flat.y)
	return out

## The far level as arrays of its own: {v, n, b (its band), i}, its vertices only.
static func _far(v: PackedVector3Array, idx: PackedInt32Array, band: PackedFloat32Array) -> Dictionary:
	var map := {}
	var fv := PackedVector3Array()
	var fb := PackedFloat32Array()
	var fi := PackedInt32Array()
	fi.resize(idx.size())
	for i in range(idx.size()):
		var o: int = idx[i]
		var got: Variant = map.get(o)
		if got == null:
			got = fv.size()
			map[o] = got
			fv.append(v[o])
			fb.append(band[o])
		fi[i] = int(got)
	return {"v":fv,"n":Build._normals(fv,fi),"b":fb,"i":fi}

## The flight's solid, read off the skin itself: {c (slice centres, off the
## base), r (slices x SOLID_WAYS radii), y0, dy, slices, then from rim_y up the
## top's height field `field`; top, mid, reach}.
static func _solid(v: PackedVector3Array, rows: int, body_rows: int, cols: int, pl: Dictionary, tall: float) -> Dictionary:
	var y0 := v[0].y
	for j in cols: y0 = minf(y0,v[j].y)
	var top := y0
	for p in v: top = maxf(top,p.y)
	var slices := int(ceil((top-y0)/SOLID_DY))+1
	var r := PackedFloat32Array()
	r.resize(slices*SOLID_WAYS)
	var c := PackedVector2Array()
	c.resize(slices)
	var count := cols/SOLID_STRIDE
	var hints := PackedInt32Array()
	hints.resize(count)
	var pts := PackedVector2Array()
	pts.resize(count)
	var rim_low := INF
	for j in cols: rim_low = minf(rim_low,v[body_rows*cols+j].y)
	for s in slices:
		var y := y0+s*SOLID_DY
		var round_at := Vector2.ZERO
		var hits := 0
		for e in count:
			var j := e*SOLID_STRIDE
			var i := hints[e]
			var hit := false
			var q := Vector2.ZERO
			while i < body_rows:
				var a := v[i*cols+j]
				var b := v[(i+1)*cols+j]
				if y < b.y:
					if y >= a.y:
						var f := (a+(b-a)*(y-a.y)/maxf(b.y-a.y,0.001))
						q = Vector2(f.x,f.z)
						hit = true
					break
				i += 1
			hints[e] = i
			if not hit:
				for m in range(body_rows,rows):
					var a := v[m*cols+j]
					var b := v[(m+1)*cols+j]
					if (a.y-y)*(b.y-y) <= 0.0:
						var f := (a+(b-a)*((y-a.y)/(b.y-a.y) if absf(b.y-a.y) > 0.001 else 0.0))
						q = Vector2(f.x,f.z)
						hit = true
						break
			pts[e] = q if hit else Vector2.ZERO
			if hit:
				round_at += q
				hits += 1
		# (Round its own outline, not the axis: the rock can stand off the axis. Past
		# the top's lowest edge the outline opens, and the top field takes over.)
		if hits < count and y >= rim_low:
			slices = s
			break
		var axis := round_at/hits if hits > 0 else _axis(pl,y/tall)
		c[s] = axis
		for e in count:
			if pts[e] != Vector2.ZERO: pts[e] -= axis
		_ways(pts,r,s*SOLID_WAYS)
	r.resize(slices*SOLID_WAYS)
	c.resize(slices)
	var mid := Vector2.ZERO
	for s in slices: mid += c[s]
	mid /= slices
	var reach := 0.0
	for s in slices:
		for k in SOLID_WAYS: reach = maxf(reach,r[s*SOLID_WAYS+k]+c[s].distance_to(mid))
	var rim_y := y0+(slices-1)*SOLID_DY
	var field := _top_field(v,rim_y)
	var fat := field.at as Vector2
	var fsize := Vector2(int(field.w),int(field.d))*TOP_CELL
	for corner: Vector2 in [fat,fat+fsize,fat+Vector2(fsize.x,0.0),fat+Vector2(0.0,fsize.y)]:
		reach = maxf(reach,corner.distance_to(mid))
	return {"c":c,"r":r,"y0":y0,"dy":SOLID_DY,"slices":slices,"rim_y":rim_y,"field":field,"top":top,"mid":mid,"reach":reach}

## The top as a height field, from `rim_y` up: {h (highest rock in each cell, or
## NO_TOP), at (the grid's corner), w, d}. Over the rim the skin is one surface
## over the ground plan, clefts and all, which no outline round a middle can
## hold. Read by `PeakTowers._top_at`.
static func _top_field(v: PackedVector3Array, rim_y: float) -> Dictionary:
	var lo := Vector2(INF,INF)
	var hi := Vector2(-INF,-INF)
	for p in v:
		if p.y < rim_y: continue
		lo = lo.min(Vector2(p.x,p.z))
		hi = hi.max(Vector2(p.x,p.z))
	var w := int((hi.x-lo.x)/TOP_CELL)+2
	var d := int((hi.y-lo.y)/TOP_CELL)+2
	var h := PackedFloat32Array()
	h.resize(w*d)
	h.fill(NO_TOP)
	for p in v:
		if p.y < rim_y: continue
		var at := int((p.x-lo.x)/TOP_CELL)+int((p.z-lo.y)/TOP_CELL)*w
		h[at] = maxf(h[at],p.y)
	# A cell the skin's vertices stepped over, inside the top, takes its neighbours'.
	var filled := h.duplicate()
	for z in range(1,d-1):
		for x in range(1,w-1):
			if h[x+z*w] != NO_TOP: continue
			var sum := 0.0
			var n := 0
			for o: int in [-1,1,-w,w]:
				if h[x+z*w+o] != NO_TOP:
					sum += h[x+z*w+o]
					n += 1
			if n >= 3: filled[x+z*w] = sum/n
	return {"h":filled,"at":lo,"w":w,"d":d}

## A slice's outline (`pts`, in turn round its centre; a zero is no skin at
## that column) into `r` from `at`: its radius at each of SOLID_WAYS ways.
static func _ways(pts: PackedVector2Array, r: PackedFloat32Array, at: int) -> void:
	for k in SOLID_WAYS: r[at+k] = 0.0
	var n := pts.size()
	var step := TAU/SOLID_WAYS
	for e in n:
		var a := pts[e]
		var b := pts[(e+1)%n]
		if a == Vector2.ZERO:
			if b == Vector2.ZERO: continue
			a = b
		elif b == Vector2.ZERO: b = a
		var ta := a.angle()
		var turn := wrapf(b.angle()-ta,-PI,PI)
		var lo := int(ceil(minf(ta,ta+turn)/step))
		var hi := int(floor(maxf(ta,ta+turn)/step))
		var seg := b-a
		for w in range(lo,hi+1):
			var ang := w*step
			var u := Vector2(cos(ang),sin(ang))
			var den := seg.x*u.y-seg.y*u.x
			var t := 0.0
			if absf(den) > 1e-6: t = clampf(-(a.x*u.y-a.y*u.x)/den,0.0,1.0)
			var o := posmod(w,SOLID_WAYS)
			r[at+o] = maxf(r[at+o],(a+seg*t).dot(u))
