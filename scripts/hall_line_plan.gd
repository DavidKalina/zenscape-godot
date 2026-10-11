extends RefCounted
## The Sundered line's plan (docs/design/isle-hall-line.md): the aqueduct
## isle's endless run of big Sundered-hall pieces laid end to end, as the
## game's Sundered hall motif lays them (scripts/sundered_hall.gd), with now
## and then a sidestep or a bend between runs. Plain data, seeded, safe on a
## worker, the same every time for a seed.
##
## A piece is one long straight stretch of torn nave on its own ridge
## island, the Sundered hall's piece in greybox: its bays drawn by the
## Sundered planner (`Sundered._plans`: the act's roofs, breaches, screens,
## ties, both ends torn) and stood as the flight course's greybox bays
## (FlightCourse `_bay`, the moments hall's own boxes and columns), with a
## faceted rock keel under it, one hull a bay, deepest at its middle and
## drawn in at the torn ends (the island). It rises whole: `template` gives
## a hall rise plan (scripts/hall_rise_plan.gd's shape) of one chunk.
##
## Pieces run in straight runs of `run` pieces, end to end along one
## heading, the lane (the Sundered line, LINE_Y over the floor and LANE_MID
## right of the nave's middle) straight through them and over each gap of
## `gap` m, stepping up or down a little (STEP, kept in a band). Between
## runs the line turns (`turn`): a sidestep (the next run parallel, `jog` m
## to one side, over a longer gap, `jog_gap` m, the lane an easy S), or a
## bend (the next run `bend` degrees off, over a gap of BEND_GAP), or
## either ("mix"). Sidesteps lean back toward the first run's axis and
## bends back toward its heading, so the line never wanders off round.
##
## A piece's frame: its first bay's start on the nave's middle line at the
## floor (y 0), the nave running -Z (north), +X its right (the flight
## course's bay frame turned by yaw 0). A piece record: {index, act, bays,
## length (m), yaw (its heading, SkyPlane's: 0 north), origin (world: its
## frame's origin), entry and exit (world: the lane's two ends), floor
## (world y), run (which run), kind (how the line came into it: "start",
## "gap", "jog", "bend"), gap (m from the last piece's exit), side (the jog
## or bend's way: -1 left, 1 right, 0), offset (m: the entry's way off the
## first run's axis), seed}.

const Sundered = preload("res://scripts/sundered_hall.gd")
const Hall = preload("res://scripts/ruin_kit_hall.gd")
const Course = preload("res://scripts/flight_course.gd")
const Plan = preload("res://scripts/sky_moments_plan.gd")
const RisePlan = preload("res://scripts/hall_rise_plan.gd")

const BAY := Hall.BAY
## The lane: Sundered's line, LINE_Y over the floor, LANE_MID right of the
## nave's middle (clear of the inner columns and the low ties).
const LINE_Y := Sundered.LINE_Y
const LANE_MID := Sundered.LANE_MID
## The defaults, all tunable by flag (scripts/hall_line.gd `options`):
##   bays     bays a piece (a range; Sundered's pieces are 7-12)
##   gap      m of open sky between pieces in a run (a range; Sundered's
##            12-30)
##   run      pieces a straight run (a range): how often the line turns
##   turn     "sidestep", "bend" or "mix": what the line does between runs
##   jog      m the next run stands to the side on a sidestep
##   jog_gap  m of sky a sidestep takes (long enough to fly the S at boost)
##   bend     degrees a bend turns the line
##   band     m a piece's floor may stand over or under the first's
##   seed     the line's seed
const LINE := {"bays":Vector2i(8,11),"gap":Vector2(14.0,26.0),"run":Vector2i(2,4),"turn":"sidestep","jog":48.0,"jog_gap":120.0,"bend":26.0,"band":8.0,"seed":3}
## The step up or down over a gap (m, a range), kept under GRADE (rise over
## run, as the Sundered hall's).
const STEP := Vector2(-3.0,3.0)
const GRADE := 0.25
## A sidestep's jog and gap each drawn within this share either way.
const JOG_VARY := 0.15
## A bend's gap (m, a range) and its turn's share either way.
const BEND_GAP := Vector2(34.0,46.0)
const BEND_VARY := 0.2
## How far the heading may wander off the first run's before bends turn
## back (rad), and how far the line may stand off the first run's axis
## before sidesteps lean back (shares of `jog`).
const WANDER := 0.6
const DRIFT := 1.2
## The gap's lane runs straight this far (m, at most a tenth of the gap)
## off one torn end and into the next before it turns.
const PAD := 8.0
## The acts the pieces take in turn (Sundered's middle acts: the dark
## nave, the shafts, the open cloister, the slit).
const ACTS := ["nave","shafts","cloister","nave","slit","shafts","cloister"]
## The island under a piece: its top's half width (m, ends and middle;
## the nave's walls stand at Hall.WALL_Z), how deep it hangs (m, at the
## torn ends and the middle), how far it draws in under each torn end
## (m), the bottom's share of the top, the jitter (m). Its top stands just
## under the floor slab.
const ISLE_HALF := Vector2(15.5,19.5)
const KEEL_DEEP := Vector2(8.0,22.0)
const TIP := 2.5
const TAPER := 0.42
const JITTER := 1.4
const ISLE_TOP := -2.02
## Rim points every this many metres round the island's top (where the
## cloud breaks).
const RIM_STEP := 3.0

## The settings: LINE with any given.
static func settings(opts := {}) -> Dictionary:
	var out := LINE.duplicate()
	for key: String in LINE:
		if opts.has(key): out[key] = opts[key]
	var b: Vector2i = out.bays
	out.bays = Vector2i(maxi(3,mini(b.x,b.y)),maxi(3,maxi(b.x,b.y)))
	var g: Vector2 = out.gap
	out.gap = Vector2(maxf(4.0,minf(g.x,g.y)),maxf(4.0,maxf(g.x,g.y)))
	var r: Vector2i = out.run
	out.run = Vector2i(maxi(1,mini(r.x,r.y)),maxi(1,maxi(r.x,r.y)))
	if not str(out.turn) in ["sidestep","bend","mix"]: out.turn = "sidestep"
	out.jog = maxf(0.0,float(out.jog))
	out.jog_gap = maxf(20.0,float(out.jog_gap))
	out.bend = clampf(float(out.bend),0.0,60.0)
	out.band = maxf(0.0,float(out.band))
	out.seed = int(out.seed)
	return out

static func ahead(h: float) -> Vector3:
	return Vector3(-sin(h),0.0,-cos(h))

static func right(h: float) -> Vector3:
	return Vector3(cos(h),0.0,-sin(h))

static func heading_of(d: Vector3) -> float:
	return atan2(-d.x,-d.z)

## The lane's point in a piece's frame `s` m along it.
static func lane_local(s: float) -> Vector3:
	return Vector3(LANE_MID,LINE_Y,-s)

static func xform(piece: Dictionary) -> Transform3D:
	return Transform3D(Basis(Vector3.UP,float(piece.yaw)),piece.origin)

## What piece `index` of line `seed` is: {act, bays, length, seed}, drawn
## from its own stream (so where it stands never changes what it is).
static func content(seed_value: int, index: int, cfg: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value,"line piece",index])
	for k in range(3): rng.randi()
	var b: Vector2i = cfg.bays
	var bays := rng.randi_range(b.x,b.y)
	var act: String = ACTS[(index+seed_value)%ACTS.size()]
	return {"act":act,"bays":bays,"length":bays*BAY,"seed":hash([seed_value,"line plans",index]) & 0xffffff}

## The first piece: its lane's entry at `entry`, run on `heading`.
static func first(seed_value: int, cfg: Dictionary, entry: Vector3, heading: float) -> Dictionary:
	var piece := content(seed_value,0,cfg)
	var rng := _placer(seed_value,0)
	var r: Vector2i = cfg.run
	piece.merge({"index":0,"run":0,"run_left":rng.randi_range(r.x,r.y)-1,"kind":"start","gap":0.0,"side":0,"offset":0.0,
		"base_heading":heading,"base_entry":entry,"base_floor":entry.y-LINE_Y,"line_seed":seed_value})
	_stand(piece,entry,heading)
	return piece

static func _placer(seed_value: int, index: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value,"line place",index])
	# Near seeds' first draws run alike: let a few go.
	for k in range(3): rng.randi()
	return rng

## Stands `piece` with its lane's entry at `entry` on `heading`.
static func _stand(piece: Dictionary, entry: Vector3, heading: float) -> void:
	var basis := Basis(Vector3.UP,heading)
	piece.yaw = heading
	piece.origin = entry-basis*lane_local(0.0)
	piece.entry = entry
	piece.exit = entry+ahead(heading)*float(piece.length)
	piece.floor = entry.y-LINE_Y

## The piece after `prev` (see the header): on in its run, or the line
## turning into a new run.
static func next(prev: Dictionary, cfg: Dictionary) -> Dictionary:
	var index := int(prev.index)+1
	var seed_value := int(prev.line_seed)
	var piece := content(seed_value,index,cfg)
	var rng := _placer(seed_value,index)
	var h := float(prev.yaw)
	var h0 := float(prev.base_heading)
	var exit: Vector3 = prev.exit
	var kind := "gap"
	var run := int(prev.run)
	var left := int(prev.run_left)-1
	if int(prev.run_left) <= 0:
		run += 1
		var r: Vector2i = cfg.run
		left = rng.randi_range(r.x,r.y)-1
		kind = str(cfg.turn)
		if kind == "mix": kind = "jog" if rng.randf() < 0.6 else "bend"
		elif kind == "sidestep": kind = "jog"
		if kind == "jog" and float(cfg.jog) <= 0.0: kind = "gap"
		if kind == "bend" and float(cfg.bend) <= 0.0: kind = "gap"
	var g := 0.0
	var side := 0
	var heading := h
	var entry := exit
	var gr: Vector2 = cfg.gap
	match kind:
		"gap":
			g = rng.randf_range(gr.x,gr.y)
			entry = exit+ahead(h)*g
		"jog":
			g = float(cfg.jog_gap)*rng.randf_range(1.0-JOG_VARY*0.5,1.0+JOG_VARY)
			var j := float(cfg.jog)*rng.randf_range(1.0-JOG_VARY,1.0+JOG_VARY)
			side = 1 if rng.randf() < 0.5 else -1
			# Lean back toward the first run's axis once off it.
			var off := float(prev.offset)
			if absf(off+side*j) > float(cfg.jog)*DRIFT and off != 0.0: side = -int(signf(off))
			entry = exit+ahead(h)*g+right(h)*side*j
		"bend":
			g = rng.randf_range(BEND_GAP.x,BEND_GAP.y)
			var turn := deg_to_rad(float(cfg.bend))*rng.randf_range(1.0-BEND_VARY,1.0+BEND_VARY)
			side = 1 if rng.randf() < 0.5 else -1
			# Turned right is a heading less (SkyPlane's: right negative).
			var wander := wrapf(h-h0,-PI,PI)
			if absf(wrapf(h-side*turn-h0,-PI,PI)) > WANDER and wander != 0.0: side = int(signf(wander))
			heading = h-side*turn
			entry = exit+ahead((h+heading)*0.5)*g
	# The step, kept in the band round the first floor and under GRADE.
	var dy := rng.randf_range(STEP.x,STEP.y)
	var floor_y := float(prev.floor)
	var base := float(prev.base_floor)
	var band := float(cfg.band)
	if floor_y+dy > base+band: dy = -absf(dy)
	if floor_y+dy < base-band: dy = absf(dy)
	dy = clampf(dy,-g*GRADE,g*GRADE)
	entry.y = float(prev.entry.y)+dy
	piece.merge({"index":index,"run":run,"run_left":left,"kind":kind,"gap":g,"side":side,
		"base_heading":h0,"base_entry":prev.base_entry,"base_floor":base,"line_seed":seed_value})
	_stand(piece,entry,heading)
	var e0: Vector3 = prev.base_entry
	piece.offset = (entry-e0).dot(right(h0))
	return piece

## The lane through a piece, every `step` m (world), entry to exit.
static func lane_route(piece: Dictionary, step := 2.0) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var t := xform(piece)
	var n := maxi(1,ceili(float(piece.length)/step))
	for k in range(n+1): out.append(t*lane_local(float(piece.length)*k/n))
	return out

## The lane over the gap into `piece` from `prev`'s exit, every `step` m
## (world), the exit itself left out, the entry in.
static func gap_route(prev: Dictionary, piece: Dictionary, step := 2.0) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var a: Vector3 = prev.exit
	var b: Vector3 = piece.entry
	var n := maxi(2,ceili(a.distance_to(b)/step))
	for k in range(1,n+1): out.append(gap_point(prev,piece,float(k)/n))
	return out

## The gap's lane `u` (0-1) of the way from `prev`'s exit to `piece`'s
## entry: straight off the torn end PAD m, then (a sidestep) an S sideways
## eased at both ends, or (a gap, a bend) a curve tangent to both runs,
## then straight PAD m into the next; the height eased between them.
static func gap_point(prev: Dictionary, piece: Dictionary, u: float) -> Vector3:
	var a: Vector3 = prev.exit
	var b: Vector3 = piece.entry
	var h0 := float(prev.yaw)
	var h1 := float(piece.yaw)
	var flat_a := Vector3(a.x,0.0,a.z)
	var flat_b := Vector3(b.x,0.0,b.z)
	var y := lerpf(a.y,b.y,_smoother(u))
	if str(piece.kind) == "jog":
		var d := flat_b-flat_a
		var along := d.dot(ahead(h0))
		var across := d.dot(right(h0))
		var pad := minf(PAD,along*0.1)/maxf(along,1.0)
		var v := clampf((u-pad)/maxf(1.0-2.0*pad,1e-6),0.0,1.0)
		var p := flat_a+ahead(h0)*along*u+right(h0)*across*_smoother(v)
		return Vector3(p.x,y,p.z)
	var chord := flat_a.distance_to(flat_b)
	var p0 := flat_a
	var p1 := flat_b
	var t0 := ahead(h0)*chord
	var t1 := ahead(h1)*chord
	var u2 := u*u
	var u3 := u2*u
	var p := p0*(2.0*u3-3.0*u2+1.0)+t0*(u3-2.0*u2+u)+p1*(-2.0*u3+3.0*u2)+t1*(u3-u2)
	return Vector3(p.x,y,p.z)

static func _smoother(u: float) -> float:
	var x := clampf(u,0.0,1.0)
	return x*x*x*(x*(x*6.0-15.0)+10.0)

# --- The piece, whole --------------------------------------------------------------------

## A piece's bays in greybox (its frame): the Sundered planner's plans for
## its act (both ends torn), each drawn as the flight course's bay, the
## broken roofs with two strips gone. [solids, plans].
static func bays(piece: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(piece.seed)
	var plans: Array = Sundered._plans({"bays":int(piece.bays),"act":str(piece.act),"first":false,"last":false},rng)
	var solids := []
	for i in range(plans.size()):
		var p: Dictionary = plans[i]
		var q := p.duplicate()
		var b: Vector2i = p.breach
		q.breach = [Hall.BREACHES[b.x],Hall.BREACHES[b.y]]
		q.last = i == plans.size()-1
		q.gaps = []
		if p.roof == "broken":
			var gone := []
			while gone.size() < 2:
				var k := rng.randi_range(1,4)
				if not k in gone: gone.append(k)
			q.gaps = gone
		solids.append_array(Course._bay(Vector3(0.0,0.0,-i*BAY),0.0,q))
	return [solids,plans]

## The island under a piece (its frame): one faceted hull a bay (a top
## ring just under the floor, a shoulder ring, a bottom ring, as the hall
## rise's keels, scripts/hall_rise.gd `_keel_faces`), its width and depth
## running smoothly along the piece, deepest at the middle, drawn in under
## the torn ends so they overhang it.
static func island(piece: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(piece.seed)+17
	var n := int(piece.bays)
	var length := float(piece.length)
	# Jitter at each bay line, shared by the hulls either side of it.
	var wide := PackedFloat32Array()
	var deep := PackedFloat32Array()
	var drift := PackedFloat32Array()
	for k in range(n+1):
		var u := float(k)/n
		var bulge := sin(u*PI)
		wide.append(lerpf(ISLE_HALF.x,ISLE_HALF.y,bulge)+rng.randf_range(-JITTER,JITTER))
		deep.append(lerpf(KEEL_DEEP.x,KEEL_DEEP.y,bulge)+rng.randf_range(-JITTER,JITTER)*1.5)
		drift.append(rng.randf_range(-JITTER,JITTER)*1.5)
	var out := []
	for i in range(n):
		var s := [i*BAY,(i+1)*BAY]
		if i == 0: s[0] = TIP
		if i == n-1: s[1] = length-TIP
		var pts := PackedVector3Array()
		# Ring 0, the top; ring 1, the bottom; ring 2, the shoulder: each
		# (-,-) (-,+) (+,-) (+,+) along, across.
		for ring in range(3):
			for e in range(2):
				var k := i+e
				var along: float = s[e]
				var w := wide[k]
				var d := deep[k]
				if (i == 0 and e == 0) or (i == n-1 and e == 1):
					d *= 0.55
					w *= 0.85
				for sz: float in [-1.0,1.0]:
					var p := Vector3.ZERO
					match ring:
						0: p = Vector3(sz*w,ISLE_TOP,-along)
						1:
							var tip := 0.0
							if i == 0 and e == 0: tip = TIP*2.0
							if i == n-1 and e == 1: tip = -TIP*2.0
							p = Vector3(sz*w*TAPER+drift[k],ISLE_TOP-d,-along-tip)
						2: p = Vector3(sz*w*0.88+drift[k]*0.4,ISLE_TOP-d*0.38,-along)
					pts.append(p)
		out.append({"kind":"hull","points":pts,"keel":true})
	return out

## A piece as the hall rise plans a hall (scripts/hall_rise_plan.gd's
## shape), its frame for the hall's: every solid in one chunk, the island
## its `extra`, so it rises whole. Not timed (HallRise's `setup` times it
## from this, RisePlan.remake). Safe on a worker.
static func template(piece: Dictionary) -> Dictionary:
	var made := bays(piece)
	var solids: Array = made[0]
	var chunk := {"id":"piece","title":"the %s, %d bays" % [piece.act,int(piece.bays)],"bays":[0,int(piece.bays)-1],"solids":range(solids.size()),"extra":island(piece)}
	_shape(chunk,solids,piece)
	return {"solids":solids,"chunks":[chunk],"length":0.0,"sea":RisePlan.SEA,"plans":made[1]}

## A chunk's box, middle, solids' boxes and rim (round the island's top).
static func _shape(chunk: Dictionary, solids: Array, piece: Dictionary) -> void:
	var lo := Vector3.INF
	var hi := -Vector3.INF
	var boxes := []
	var all := []
	for k: int in chunk.solids: all.append(solids[k])
	all.append_array(chunk.extra)
	for q: Dictionary in all:
		var a := Vector3.INF
		var b := -Vector3.INF
		if q.kind == "hull":
			for v: Vector3 in q.points:
				a = a.min(v)
				b = b.max(v)
		else:
			var e := Plan.extent(q)
			a = (q.middle as Vector3)-e
			b = (q.middle as Vector3)+e
		boxes.append(AABB(a,b-a))
		lo = lo.min(a)
		hi = hi.max(b)
	chunk.lo = lo
	chunk.hi = hi
	chunk.pivot = (lo+hi)*0.5
	chunk.boxes = boxes
	chunk.top = hi.y-(lo.y+hi.y)*0.5
	var rim := PackedVector3Array()
	for q: Dictionary in chunk.extra:
		var pts: PackedVector3Array = q.points
		# The top ring's long sides.
		for e in [[0,2],[1,3]]:
			var a: Vector3 = pts[e[0]]
			var b: Vector3 = pts[e[1]]
			var steps := maxi(1,ceili(a.distance_to(b)/RIM_STEP))
			for s in range(steps): rim.append(a.lerp(b,float(s)/steps))
	# Across the torn ends.
	for e: Array in [[0,0,1],[chunk.extra.size()-1,2,3]]:
		var pts: PackedVector3Array = chunk.extra[e[0]].points
		var a: Vector3 = pts[e[1]]
		var b: Vector3 = pts[e[2]]
		var steps := maxi(1,ceili(a.distance_to(b)/RIM_STEP))
		for s in range(steps): rim.append(a.lerp(b,float(s)/steps))
	chunk.rim = rim

## The real piece's island (scripts/hall_line_build.gd, Sundered's: some
## 21-24 m half across, its rounded outline reaching a little further) at
## most this far (m) either side of the nave's middle, and past either torn
## end (the podium's hanging blocks).
const REAL_HALF := 30.0
const REAL_PAST := 2.5

## A piece's footprint (flat, world): its island's top's four corners, the
## real island's box (`real`) or the greybox's.
static func footprint(piece: Dictionary, real := true) -> PackedVector2Array:
	var t := xform(piece)
	var w := REAL_HALF if real else ISLE_HALF.y+JITTER
	var past := REAL_PAST if real else 0.0
	var out := PackedVector2Array()
	for c: Vector2 in [Vector2(-w,-past),Vector2(w,-past),Vector2(w,float(piece.length)+past),Vector2(-w,float(piece.length)+past)]:
		var p := t*Vector3(c.x,0.0,-c.y)
		out.append(Vector2(p.x,p.z))
	return out
