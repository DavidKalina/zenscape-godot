extends RefCounted
## The Sundered hall, a sky cluster's motif (scripts/sky_clusters.gd,
## `--motif=sundered`): one long gothic hall of the old sky-builders (the
## ruin kit's colossus hall, scripts/ruin_kit_hall.gd) torn apart when the
## land broke, its pieces floating off on a chain of long ridge islands at
## different heights. Each island carries a stretch of nave that ends in a
## ragged torn edge, then open sky, then the next piece. The plane flies
## the whole nave, gaps and all: a minute or more at cruise.
##
## This script is the planner and the query: plain data, safe on a worker,
## the same plan for the same seed. scripts/sundered_build.gd builds it
## (the islands' beds, the hall's near and far detail, the aqueduct, the
## apse) and streams the near detail in and out.
##
## The plan is laid as a sequence of acts (ACTS), never a repeat of one bay:
##   gate     the west front: a gabled mouth out of open sky, a whole roof
##            and then the first light;
##   nave     the dark nave: whole roof in runs of two or three bays, each
##            run broken by a wide arch out the side;
##   shafts   the roof half fallen: light in shafts, slabs tipped;
##   cloister the roof gone: open sky over the columns, walls torn low;
##   slit     a narrow stretch: screens with knife-edge slits every other
##            bay, inner columns paired;
##   apse     the end: the roof opening up, a ring of snapped columns, a
##            snapped tower beside it, and the line climbing out to the
##            open sky (the release).
## Between the pieces, gaps of open sky (GAP) with a step up or down; one
## (the drop) a long dive; one (the aqueduct) holds a small island an
## aqueduct crosses, the line threading one of its arches, the channel
## spilling off its torn end down to the cloud sea.
##
## Exits everywhere: no more than MAX_SHUT bays in a row lack a way out (an
## open or broken roof, a flyable breach, a torn end, a gap), checked by
## `validate`.
##
## Frames. The cluster frame: the cluster's spot (SkyClusters `spots` `at`)
## at the origin, home axes. A piece's hall frame: its first mouth's nave
## middle at its origin, its floor at y 0, the nave along +X (HallPath's
## path space: x along the nave's middle line, y up, z across, +Z the
## right, where the lane runs). `pieces[i].frame` carries a hall frame into
## the cluster frame.
##
## The query (for what threads the hall later: tokens, a foot route):
##   `line(plan, step)`: the flown centreline sampled: [{at (cluster),
##     way (unit tangent), s (m from the line's start), kind ("lead",
##     "hall", "gap", "release"), piece, bay}]; its middle is the lane's
##     (Hall.LANE) at LINE_Y over the floor, so the plane passes every bay;
##   `sections(plan)`: [{kind (an act, "gap", "drop", "aqueduct", "lead",
##     "release"), from, to (s), piece}];
##   `exits(plan)`: [{kind ("roof" broken, "open", "breach", "torn",
##     "gap"), s, at (cluster), side (-1 left, 1 right, 0 up), bay, piece,
##     breach kind}];
##   `corridor(plan, piece, bay)`: the clear way through a bay: {lane
##     (AABB in the piece's path space), floor, roof, tie, slit (path space
##     Vector3 or null), screen};
##   `anchors(plan)`: per gap, both torn ends' walkable lips: [{gap, from
##     ({piece, floor (cluster, the floor's lip on the nave's middle),
##     floor_y, left_wall, right_wall (cluster points on the walls' lips,
##     their tops ~torn wall height), heading}), to (the same)}].
## The near build's own metadata (Hall weave: exact roof gaps, breach
## boxes, slits) stands on each piece's near node (`weave`).

const Hall = preload("res://scripts/ruin_kit_hall.gd")
const HallPath = Hall.HallPath

const BAY := Hall.BAY
## The line's height over the floor (the lane's middle, LANE_Y) and its
## place across the nave (the lane's middle), both from the lane (which
## follows the plane, scripts/world_scale.gd): 2.55 and 7.08 at plane 2,
## the wings 1.68 m off the lane's sides (it was 6.0, off the middle: 0.6
## m off the inner columns' side, too tight to fly).
static var LINE_Y: float = (Hall.LANE_Y.x+Hall.LANE_Y.y)*0.5
static var LANE_MID: float = (Hall.LANE.x+Hall.LANE.y)*0.5
## The acts in order: each [act, pieces (range), bays a piece (range)].
const ACTS := [
	["gate",Vector2i(1,1),Vector2i(8,10)],
	["nave",Vector2i(2,2),Vector2i(9,12)],
	["shafts",Vector2i(1,2),Vector2i(8,11)],
	["cloister",Vector2i(2,2),Vector2i(8,10)],
	["slit",Vector2i(1,1),Vector2i(7,9)],
	["shafts",Vector2i(1,1),Vector2i(7,9)],
	["apse",Vector2i(1,1),Vector2i(8,10)],
]
## Gaps (m, torn end to torn end along the line) and their steps up or
## down (m), the steepest grade a step may take (rise over run, held at
## cruise: about 17 degrees), the drop's step and gap, the aqueduct's gap.
const GAP := Vector2(12.0,30.0)
const STEP := Vector2(-5.0,4.0)
const GRADE := 0.3
const DROP := Vector2(-11.0,-8.0)
const DROP_GAP := Vector2(34.0,40.0)
const AQUEDUCT_GAP := Vector2(40.0,44.0)
## The line's kink at a gap (rad either way) and how far the heading may
## wander off the first (rad): the hall snakes on, never back. Eased for
## the big plane (it was 0.14).
const KINK := 0.1
const WANDER := 0.9
## A piece's curve: at most a stretch's turn, and never tighter than
## RADIUS (m) (the kit keeps >= 40). Eased for the big plane (it was 70):
## a lane's breadth off the line still turns gently.
const TURN := 0.5
const RADIUS := 95.0
## Lead in to the gate and the release out of the apse (m), its climb.
const LEAD := 60.0
const RELEASE := 70.0
const RELEASE_CLIMB := 22.0
## Exits: at most this many bays in a row with no way out.
const MAX_SHUT := 2
## The islands: their half width across the hall (m, a range), how far a
## torn end overhangs its island's tip (m), how far the land runs on past
## the gate's mouth and past the apse (m).
const ISLE_HALF := Vector2(21.0,24.0)
const OVERHANG := Vector2(1.0,4.5)
const FORECOURT := 8.0
const APSE_ROOM := 16.0
## Kept clear between two islands' capsules (m): neighbours, the rest.
const NEIGHBOUR_CLEAR := 5.0
const FAR_CLEAR := 30.0
## The aqueduct's island: its long half along the run and short half
## across it (m).
const AQ_ISLE := Vector2(12.5,9.0)
## The target the plans are held to (m of line), the range validate asks.
const LENGTH := Vector2(850.0,1300.0)
## Attempts at a well-formed layout.
const ATTEMPTS := 12
const WEATHERED := 0.6

# --- Layout ---------------------------------------------------------------------

## The layout for `seed_value`, the first heading `yaw` (radians, the
## hall frame's +X turned about +Y): pieces, gaps, sections, no islands.
## Cheap (a few ms): the placement reads its line before anything is made.
static func layout(seed_value: int, yaw := 0.0) -> Dictionary:
	var out := {}
	for attempt in range(ATTEMPTS):
		out = _layout(seed_value,yaw,attempt)
		if validate(out).is_empty(): return out
	return out

static func _layout(seed_value: int, yaw: float, attempt: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value,"sundered",attempt])
	var plan := {"motif":"sundered","seed":seed_value,"yaw":yaw,"label":"Sundered hall","night":{},
		"pieces":[],"gaps":[],"problems":[],"members":[],"bridges":[],"routes":[]}
	# The acts, piece by piece.
	var acts: Array = []
	for a: Array in ACTS:
		var n := rng.randi_range((a[1] as Vector2i).x,(a[1] as Vector2i).y)
		for k in range(n): acts.append([a[0],rng.randi_range((a[2] as Vector2i).x,(a[2] as Vector2i).y)])
	# Where the drop and the aqueduct fall: the drop after the shafts that
	# follow the naves, the aqueduct before the slit.
	var drop_after := -1
	var aqueduct_after := -1
	for i in range(acts.size()-1):
		if acts[i][0] == "shafts" and acts[i+1][0] == "cloister" and drop_after < 0: drop_after = i
		if acts[i+1][0] == "slit": aqueduct_after = i
	var start := Vector3.ZERO
	var theta := yaw
	var sense := 1.0 if rng.randf() < 0.5 else -1.0
	var floor_y := 0.0
	for i in range(acts.size()):
		var act: String = acts[i][0]
		var bays: int = acts[i][1]
		var piece := _piece(i,act,bays,start,theta,yaw,sense,rng,i == 0,i == acts.size()-1,seed_value)
		plan.pieces.append(piece)
		sense = -sense
		if i == acts.size()-1: break
		var end_frame: Transform3D = (piece.frame as Transform3D)*(piece.path as HallPath).xform(piece.length)
		var end_theta := theta+_turned(piece.layout)
		var kind := "gap"
		var g := rng.randf_range(GAP.x,GAP.y)
		var dy := rng.randf_range(STEP.x,STEP.y)
		if i == drop_after:
			kind = "drop"
			g = rng.randf_range(DROP_GAP.x,DROP_GAP.y)
			dy = rng.randf_range(DROP.x,DROP.y)
		elif i == aqueduct_after:
			kind = "aqueduct"
			g = rng.randf_range(AQUEDUCT_GAP.x,AQUEDUCT_GAP.y)
			dy = rng.randf_range(-2.0,2.0)
		# Floors stay in a band round the first, so the keels clear the sea.
		if floor_y+dy < -24.0: dy = absf(dy)*0.5
		if floor_y+dy > 14.0: dy = -absf(dy)*0.5
		dy = clampf(dy,-g*GRADE,g*GRADE)
		var kink := rng.randf_range(-KINK,KINK)
		# Never wander far off the first heading: kink back toward it.
		if absf(end_theta+kink-yaw) > WANDER: kink = -signf(end_theta-yaw)*absf(kink)
		var way := end_frame.basis.x
		start = end_frame.origin+way*g+Vector3.UP*dy
		floor_y += dy
		theta = end_theta+kink
		plan.gaps.append({"index":i,"kind":kind,"from":i,"to":i+1,"length":g,"rise":dy,"kink":kink})
	_islands(plan,rng)
	_aqueduct(plan,rng)
	_measure(plan)
	return plan

## A piece: its stretches (straight, perhaps a curve, straight), frame,
## path, bay plans and the island it stands on.
static func _piece(index: int, act: String, bays: int, start: Vector3, theta: float, yaw: float, sense: float, rng: RandomNumberGenerator, first: bool, last: bool, seed_value: int) -> Dictionary:
	var layout: Array = []
	var curve := 0
	if act in ["nave","shafts","cloister","apse"] and bays >= 6 and rng.randf() < 0.85:
		curve = rng.randi_range(3,mini(6,bays-2))
	if curve > 0:
		var lead := rng.randi_range(1,bays-curve-1)
		var turn := minf(TURN,curve*BAY/RADIUS)*rng.randf_range(0.6,1.0)
		# Turn back toward the first heading if wandered off it.
		var s := sense
		if absf(theta-yaw) > WANDER*0.5: s = -signf(theta-yaw)
		layout = [{"bays":lead,"turn":0.0},{"bays":curve,"turn":turn*s},{"bays":bays-lead-curve,"turn":0.0}]
	else:
		layout = [{"bays":bays,"turn":0.0}]
	var path := HallPath.make(layout,BAY)
	var frame := Transform3D(Basis(Vector3.UP,theta),start)
	var piece := {"index":index,"act":act,"bays":bays,"layout":layout,"path":path,"length":path.length,"frame":frame,
		"floor":start.y,"theta":theta,"first":first,"last":last,"seed":hash([seed_value,"piece",index]) & 0xffffff}
	piece.plans = _plans(piece,rng)
	return piece

## The total turn of a layout (rad).
static func _turned(layout: Array) -> float:
	var t := 0.0
	for st: Dictionary in layout: t += float(st.get("turn",0.0))
	return t

## The bays' plans (Hall `bay`'s), drawn from the kit's own (inner columns,
## ties, fallen beams, buttresses) and then set by the act: the roof, the
## breaches, the screens, the torn ends.
static func _plans(piece: Dictionary, rng: RandomNumberGenerator) -> Array:
	var bays: int = piece.bays
	var act: String = piece.act
	var plans: Array = Hall.plan(rng,WEATHERED,bays)
	var torn_start: bool = not piece.first
	var torn_end: bool = not piece.last
	# The roofs by act.
	var roofs: Array = []
	match act:
		"gate":
			roofs = ["whole","whole","broken","whole","broken","open","open","broken","whole","broken"]
		"nave":
			var k := 0
			while roofs.size() < bays:
				var run := rng.randi_range(2,3)
				for j in range(run): roofs.append("whole")
				roofs.append("broken" if rng.randf() < 0.75 else "open")
				k += 1
		"shafts":
			for j in range(bays): roofs.append("whole" if rng.randf() < 0.18 else "broken")
		"cloister":
			for j in range(bays): roofs.append("broken" if rng.randf() < 0.15 else "open")
		"slit":
			for j in range(bays): roofs.append("whole" if j%2 == 1 else "broken")
		"apse":
			roofs = ["broken","whole","whole","broken","open","broken","open","open","open","open"]
	while roofs.size() < bays: roofs.append("broken")
	for i in range(bays):
		var p: Dictionary = plans[i]
		p.roof = roofs[i]
		p.torn = 0
		p.gable = false
		p.last_gable = false
		p.gaps = []
		p.screen = false
		p.breach = Vector2i.ZERO
	if torn_start:
		plans[0].torn = 1
	if torn_end:
		plans[bays-1].torn = int(plans[bays-1].torn) | 2
	# The mouths: the gate's first line gabled; the apse's end left open
	# (its ring of columns stands round it, scripts/sundered_build.gd).
	if piece.first:
		plans[0].gable = true
		plans[0].roof = "whole"
	for i in range(bays):
		var p: Dictionary = plans[i]
		if int(p.torn) != 0:
			p.roof = "open"
			p.tie = ""
			p.fallen = false
			p.architraves = Vector2.ZERO
			p.beam = false
			p.buttress = ""
			p.right_buttress = false
	for i in range(bays):
		var p: Dictionary = plans[i]
		var prev: String = plans[i-1].roof if i > 0 else ("whole" if piece.first else "open")
		if p.roof == "open":
			p.beam = bool(p.beam) and prev != "open" and int(p.torn) == 0
			if int(p.torn) == 0: p.architraves = Vector2(float(rng.randf() < 0.6),float(rng.randf() < 0.6))
		if i > 0 and (prev == "open") != (p.roof == "open") and int(p.torn) & 1 == 0: p.gable = true
		if p.roof == "open" and bool(p.fallen): p.fallen = false
	# The slit: screens every other bay (the slit through each), the inner
	# columns paired.
	if act == "slit":
		for i in range(1,bays-1):
			if i%2 == 1 and int(plans[i].torn) == 0:
				var p: Dictionary = plans[i]
				p.screen = true
				p.fallen = false
				if p.tie == "low": p.tie = "high"
				p.inner = [-Hall.INNER_Z,Hall.INNER_Z] if rng.randf() < 0.5 else [-Hall.INNER_Z]
	# Breaches: open stretches' walls collapse or are torn low, roofed ones
	# open in arches and doors; then every run of shut bays broken by an
	# arch so no more than MAX_SHUT stand in a row.
	var flyable := ["low","arch","collapse"]
	for i in range(bays):
		var p: Dictionary = plans[i]
		if int(p.torn) != 0 or (piece.first and i == 0): continue
		for side in range(2):
			var roll := rng.randf()
			var kind := ""
			if p.roof == "open": kind = "collapse" if roll < 0.3 else ("low" if roll < 0.5 else "")
			elif p.roof == "broken": kind = "arch" if roll < 0.15 else ("door" if roll < 0.22 else "")
			else: kind = "arch" if roll < 0.25 else ("door" if roll < 0.35 else "")
			if side == 0 and kind in flyable and bool(p.fallen): kind = ""
			# Only where the breach's corridor fits between the columns (the
			# inside of a curve is shorter).
			if kind in flyable and not Hall.breach_fits(piece.get("path"),i,side): kind = ""
			var v: Vector2i = p.breach
			v[side] = Hall.BREACHES.find(kind)
			p.breach = v
	var shut := 0
	for i in range(bays):
		var p: Dictionary = plans[i]
		if bay_exit(p).is_empty(): shut += 1
		else: shut = 0
		if shut > MAX_SHUT-1 and not (piece.first and i == 0):
			# Open this one: an arch out on the lane's side, else the left.
			var v: Vector2i = p.breach
			var left := not bool(p.fallen) and Hall.breach_fits(piece.get("path"),i,0)
			var right := Hall.breach_fits(piece.get("path"),i,1)
			if left and (rng.randf() < 0.35 or not right): v.x = Hall.BREACHES.find("arch")
			elif right: v.y = Hall.BREACHES.find("arch")
			elif p.roof == "whole": p.roof = "broken"
			p.breach = v
			shut = 0
	# A stair up near each end on foot, where the bay keeps its buttress.
	for i in [1,bays-2]:
		if i >= 0 and i < bays and int(plans[i].torn) == 0: plans[i].buttress = "stair"
	return plans

## What a bay's plan gives as a way out: [] if none, else its kinds
## ("roof", "open", "breach", "torn").
static func bay_exit(p: Dictionary) -> Array:
	var out: Array = []
	if int(p.get("torn",0)) != 0: out.append("torn")
	if p.roof == "open": out.append("open")
	elif p.roof == "broken" or not (p.get("gaps",[]) as Array).is_empty(): out.append("roof")
	var b: Vector2i = p.get("breach",Vector2i.ZERO)
	for k in range(2):
		if Hall.BREACHES[b[k]] in ["low","arch","collapse"]: out.append("breach")
	return out

## Each piece's island: centred on its chord, long along it (its frame's
## +X along the chord), the torn ends overhanging its tips a little, the
## land running on past the gate's mouth and round the apse.
static func _islands(plan: Dictionary, rng: RandomNumberGenerator) -> void:
	for piece: Dictionary in plan.pieces:
		var path: HallPath = piece.path
		var length: float = piece.length
		var a := Vector3.ZERO
		var b := path.xform(length).origin
		var chord := b-a
		var phi := atan2(-chord.z,chord.x)
		var axis := Basis(Vector3.UP,phi)
		# The arc's bulge off the chord: its middle's offset across.
		var mid_arc := path.xform(length*0.5).origin
		var across := (mid_arc-(a+b)*0.5).dot(axis.z)
		var back := rng.randf_range(OVERHANG.x,OVERHANG.y)
		var front := rng.randf_range(OVERHANG.x,OVERHANG.y)
		var lo := -chord.length()*0.5+(back if not piece.first else -FORECOURT)
		var hi := chord.length()*0.5-(front if not piece.last else -APSE_ROOM)
		var half_long := (hi-lo)*0.5
		var half_wide := rng.randf_range(ISLE_HALF.x,ISLE_HALF.y)+absf(across)*0.5
		var middle := (a+b)*0.5+axis.x*((lo+hi)*0.5)+axis.z*across*0.5
		piece.island = {"name":"piece%d" % piece.index,"half":Vector2(half_long,half_wide),"axis_yaw":phi,
			"middle":middle,"seed":hash([plan.seed,"isle",piece.index]) & 0xffffff}
		# In the cluster frame: its middle (at the floor) and its yaw.
		var frame: Transform3D = piece.frame
		piece.island.at = frame*middle
		piece.island.yaw = float(piece.theta)+phi

## The aqueduct gap's small island and the run across the line.
static func _aqueduct(plan: Dictionary, rng: RandomNumberGenerator) -> void:
	for gap: Dictionary in plan.gaps:
		if gap.kind != "aqueduct": continue
		var ends := gap_line(plan,gap)
		var a: Vector3 = ends[0]
		var b: Vector3 = ends[1]
		var mid := (a+b)*0.5
		var way := (b-a)
		way.y = 0.0
		way = way.normalized()
		var heading := atan2(-way.z,way.x)
		# The run crosses the line square: its +X across, to the line's left
		# or right at random (the spill falls off that end).
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		plan.aqueduct = {"gap":gap.index,"crossing":mid,"line_way":way,"yaw":heading+side*PI*0.5,"half":AQ_ISLE,
			"seed":hash([plan.seed,"aqueduct"]) & 0xffffff}

## A gap's line: from the lane's end in its first piece to the lane's
## start in the next (cluster frame).
static func gap_line(plan: Dictionary, gap: Dictionary) -> Array:
	var p0: Dictionary = plan.pieces[gap.from]
	var p1: Dictionary = plan.pieces[gap.to]
	return [lane_point(p0,float(p0.length)),lane_point(p1,0.0)]

## The line's point `s` m along a piece's nave (cluster frame).
static func lane_point(piece: Dictionary, s: float) -> Vector3:
	var path: HallPath = piece.path
	return (piece.frame as Transform3D)*path.point(Vector3(s,LINE_Y,LANE_MID))

## The line's way at `s` along a piece (cluster frame, unit).
static func lane_way(piece: Dictionary, s: float) -> Vector3:
	var path: HallPath = piece.path
	return ((piece.frame as Transform3D).basis*path.tangent(s)).normalized()

## The line's total length and each section's span (sets `length`,
## `sections`).
static func _measure(plan: Dictionary) -> void:
	var sections: Array = []
	var s := 0.0
	sections.append({"kind":"lead","from":0.0,"to":LEAD,"piece":0})
	s = LEAD
	var pieces: Array = plan.pieces
	for i in range(pieces.size()):
		var piece: Dictionary = pieces[i]
		piece.s0 = s
		sections.append({"kind":piece.act,"from":s,"to":s+float(piece.length),"piece":i})
		s += float(piece.length)
		if i < plan.gaps.size():
			var gap: Dictionary = plan.gaps[i]
			var ends := gap_line(plan,gap)
			var d := (ends[0] as Vector3).distance_to(ends[1])
			gap.s0 = s
			gap.span = d
			sections.append({"kind":gap.kind,"from":s,"to":s+d,"piece":i})
			s += d
	var hall_end := s
	sections.append({"kind":"release","from":s,"to":s+RELEASE,"piece":pieces.size()-1})
	s += RELEASE
	plan.sections = sections
	plan.length = s
	# The hall's own length: the gate's mouth to the apse's end.
	plan.hall_length = hall_end-LEAD

# --- The query ---------------------------------------------------------------------

## The flown centreline sampled every `step` m (see the header).
static func line(plan: Dictionary, step := 2.0) -> Array:
	var out: Array = []
	var pieces: Array = plan.pieces
	var first: Dictionary = pieces[0]
	var start := lane_point(first,0.0)
	var way0 := lane_way(first,0.0)
	var s := 0.0
	while s < LEAD:
		out.append({"at":start-way0*(LEAD-s),"way":way0,"s":s,"kind":"lead","piece":0,"bay":-1})
		s += step
	for i in range(pieces.size()):
		var piece: Dictionary = pieces[i]
		var u := 0.0
		while u < float(piece.length):
			out.append({"at":lane_point(piece,u),"way":lane_way(piece,u),"s":float(piece.s0)+u,"kind":"hall","piece":i,"bay":mini(int(u/BAY),int(piece.bays)-1)})
			u += step
		if i < plan.gaps.size():
			var gap: Dictionary = plan.gaps[i]
			var ends := gap_line(plan,gap)
			var a: Vector3 = ends[0]
			var b: Vector3 = ends[1]
			var d := a.distance_to(b)
			var t := 0.0
			while t < d:
				out.append({"at":a.lerp(b,t/d),"way":(b-a)/d,"s":float(gap.s0)+t,"kind":"gap","piece":i,"bay":-1})
				t += step
	var last: Dictionary = pieces[pieces.size()-1]
	var end := lane_point(last,float(last.length))
	var way := lane_way(last,float(last.length))
	var r := 0.0
	while r <= RELEASE:
		# Climbing out of the apse on an easing curve.
		var climb := RELEASE_CLIMB*smoothstep(0.0,1.0,r/RELEASE)
		out.append({"at":end+way*r+Vector3.UP*climb,"way":(way+Vector3.UP*RELEASE_CLIMB/RELEASE*0.5).normalized(),"s":float(plan.length)-RELEASE+r,"kind":"release","piece":pieces.size()-1,"bay":-1})
		r += step
	return out

## The sections along the line (see the header).
static func sections(plan: Dictionary) -> Array:
	return plan.sections

## Every way out along the line (see the header): each bay's (at its
## middle, on the lane), and each gap's (at its middle).
static func exits(plan: Dictionary) -> Array:
	var out: Array = []
	var pieces: Array = plan.pieces
	for i in range(pieces.size()):
		var piece: Dictionary = pieces[i]
		for k in range(int(piece.bays)):
			var p: Dictionary = piece.plans[k]
			var u := (k+0.5)*BAY
			var at := lane_point(piece,u)
			for kind: String in bay_exit(p):
				if kind == "breach":
					var b: Vector2i = p.breach
					for side in range(2):
						var name: String = Hall.BREACHES[b[side]]
						if name in ["low","arch","collapse"]:
							var path: HallPath = piece.path
							var wall := (piece.frame as Transform3D)*path.point(Vector3(u,LINE_Y,(side*2-1)*Hall.WALL_Z))
							out.append({"kind":"breach","s":float(piece.s0)+u,"at":wall,"side":side*2-1,"bay":k,"piece":i,"breach":name})
				elif kind != "breach":
					out.append({"kind":kind,"s":float(piece.s0)+u,"at":at+Vector3.UP*(Hall.ROOF_TOP-LINE_Y),"side":0,"bay":k,"piece":i,"breach":""})
	for gap: Dictionary in plan.gaps:
		var ends := gap_line(plan,gap)
		out.append({"kind":"gap","s":float(gap.s0)+float(gap.span)*0.5,"at":((ends[0] as Vector3)+(ends[1] as Vector3))*0.5,"side":0,"bay":-1,"piece":gap.from,"breach":""})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.s) < float(b.s))
	return out

## The clear way through bay `bay` of piece `index` (see the header).
static func corridor(plan: Dictionary, index: int, bay: int) -> Dictionary:
	var piece: Dictionary = plan.pieces[index]
	var p: Dictionary = piece.plans[bay]
	var top := Hall.LANE_Y.y
	if p.tie == "" and p.roof == "open": top = Hall.OPEN_SKY+4.0
	elif p.tie == "": top = Hall.COLUMN_H-0.4
	elif p.tie == "high": top = Hall.TIE_HIGH-0.3
	var lane := AABB(Vector3(bay*BAY,Hall.LANE_Y.x,Hall.LANE.x),Vector3(BAY,top-Hall.LANE_Y.x,Hall.LANE.y-Hall.LANE.x))
	var slit: Variant = null
	if bool(p.screen): slit = Vector3(bay*BAY,Hall.KNIFE.y+Hall.KNIFE.z*0.5,-(Hall.ROW_Z+Hall.INNER_Z)*0.5)
	return {"lane":lane,"floor":float(piece.floor),"roof":p.roof,"tie":p.tie,"slit":slit,"slit_size":Vector2(Hall.KNIFE.x,Hall.KNIFE.z),"screen":bool(p.screen)}

## Each gap's two torn ends' walkable lips (see the header).
static func anchors(plan: Dictionary) -> Array:
	var out: Array = []
	for gap: Dictionary in plan.gaps:
		out.append({"gap":gap.index,"kind":gap.kind,"from":_lip(plan.pieces[gap.from],true),"to":_lip(plan.pieces[gap.to],false)})
	return out

static func _lip(piece: Dictionary, at_end: bool) -> Dictionary:
	var path: HallPath = piece.path
	var s: float = float(piece.length)-0.6 if at_end else 0.6
	var frame: Transform3D = piece.frame
	var way := lane_way(piece,s)*(1.0 if at_end else -1.0)
	return {"piece":piece.index,"floor":frame*path.point(Vector3(s,0.0,0.0)),"floor_y":float(piece.floor),
		"left_wall":frame*path.point(Vector3(s,0.0,-Hall.WALL_Z)),"right_wall":frame*path.point(Vector3(s,0.0,Hall.WALL_Z)),
		"heading":way}

# --- Checks ------------------------------------------------------------------------

## What is wrong with a layout, as sentences; empty when nothing is.
static func validate(plan: Dictionary) -> Array:
	var problems: Array = (plan.get("problems",[]) as Array).duplicate()
	var length: float = plan.get("length",0.0)
	if length < LENGTH.x or length > LENGTH.y: problems.append("line %.0f m, outside %s" % [length,LENGTH])
	for gap: Dictionary in plan.gaps:
		var span: float = gap.get("span",0.0)
		if span < GAP.x-1.0 or span > AQUEDUCT_GAP.y+3.0: problems.append("gap %d spans %.1f m" % [gap.index,span])
		var ends := gap_line(plan,gap)
		var rise := absf((ends[1] as Vector3).y-(ends[0] as Vector3).y)
		if rise > span*GRADE+0.01: problems.append("gap %d too steep (%.1f m over %.1f m)" % [gap.index,rise,span])
	for piece: Dictionary in plan.pieces:
		var shut := 0
		for p: Dictionary in piece.plans:
			shut = 0 if not bay_exit(p).is_empty() else shut+1
			if shut > MAX_SHUT: problems.append("piece %d shut too long" % piece.index)
		for st: Dictionary in piece.layout:
			var t := absf(float(st.turn))
			if t > 0.0 and float(st.bays)*BAY/t < RADIUS*0.99: problems.append("piece %d curves too tight" % piece.index)
	# The islands' capsules clear of one another.
	var isles := capsules(plan)
	for i in range(isles.size()):
		for j in range(i+1,isles.size()):
			var a: Array = isles[i]
			var b: Array = isles[j]
			var d := _segment_distance(a[0],a[1],b[0],b[1])-float(a[2])-float(b[2])
			var ia: int = a[3]
			var ib: int = b[3]
			var neighbours: bool = absi(ia-ib) <= 1 or ia < 0 or ib < 0
			var need := NEIGHBOUR_CLEAR if neighbours else FAR_CLEAR
			# The aqueduct's island sits between its two neighbours only.
			if (ia < 0 or ib < 0) and not _beside_aqueduct(plan,maxi(ia,ib)): need = FAR_CLEAR
			if d < need: problems.append("islands %s and %s too close (%.1f m)" % [a[3],b[3],d])
	return problems

static func _beside_aqueduct(plan: Dictionary, index: int) -> bool:
	if not plan.has("aqueduct"): return false
	var g: Dictionary = plan.gaps[int(plan.aqueduct.gap)]
	return index == int(g.from) or index == int(g.to)

## The islands as capsules [a, b (flat, cluster frame), radius, piece index
## (-1 the aqueduct's)]: an ellipse's half length less its half width each
## way along its axis, its half width round.
static func capsules(plan: Dictionary) -> Array:
	var out: Array = []
	for piece: Dictionary in plan.pieces:
		var isle: Dictionary = piece.island
		var half: Vector2 = isle.half
		var axis := Basis(Vector3.UP,float(isle.yaw)).x
		var reach := maxf(half.x-half.y,0.0)
		var at: Vector3 = isle.at
		out.append([Vector2(at.x,at.z)+Vector2(axis.x,axis.z)*reach,Vector2(at.x,at.z)-Vector2(axis.x,axis.z)*reach,half.y,int(piece.index)])
	if plan.has("aqueduct"):
		var aq: Dictionary = plan.aqueduct
		var axis := Basis(Vector3.UP,float(aq.yaw)).x
		var half: Vector2 = aq.half
		var c: Vector3 = aq.crossing
		var reach := half.x-half.y
		out.append([Vector2(c.x,c.z)+Vector2(axis.x,axis.z)*reach,Vector2(c.x,c.z)-Vector2(axis.x,axis.z)*reach,half.y,-1])
	return out

static func _segment_distance(a0: Vector2, a1: Vector2, b0: Vector2, b1: Vector2) -> float:
	var best := INF
	for p: Vector2 in [a0,a1]: best = minf(best,p.distance_to(Geometry2D.get_closest_point_to_segment(p,b0,b1)))
	for p: Vector2 in [b0,b1]: best = minf(best,p.distance_to(Geometry2D.get_closest_point_to_segment(p,a0,a1)))
	if Geometry2D.segment_intersects_segment(a0,a1,b0,b1) != null: return 0.0
	return best

## The plan's footprint for placement: flat points (cluster frame) every
## `step` m along the line, each with the reach it keeps (m).
static func footprint(plan: Dictionary, step := 40.0) -> Array:
	var out: Array = []
	for c: Array in capsules(plan):
		var a: Vector2 = c[0]
		var b: Vector2 = c[1]
		var n := maxi(1,ceili(a.distance_to(b)/step))
		for k in range(n+1): out.append(Vector3(lerpf(a.x,b.x,float(k)/n),lerpf(a.y,b.y,float(k)/n),float(c[2])))
	return out
