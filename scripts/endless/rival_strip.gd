extends RefCounted
## Where a challenged rival (scripts/endless/rival_race.gd) lands to start
## the race, and the lane beside it where the player lands: two parallel
## lanes on one flat, the rival's and, LANE_SPANS wingspans aside, his.
##
## `find` tries spots ahead of the rival (DIST m on, within SPREAD of its
## heading, the lanes laid along the way there or turned by TURNS), nearest
## IDEAL first, and keeps the first where:
## - both lanes are level as the flats check has it (land_ponds.gd `_strip`,
##   the land's guarantee): dry (DRY m over the sea, off a river's or pond's
##   water), no rise over STEP_RISE between points STEP m apart nor over
##   SPAN_RISE across SPAN m (nor READ_SLOPE from read to read, READ m
##   apart); and across from lane to lane no more than
##   STEP_RISE; and no tree planted within TREE_ROOM m of it (`_tree_free`:
##   the trees' plan keeps every flat open, TreePlan `_flat`);
## - nothing stands on either lane or under its wings (the study's
##   `_blocked` and `plane_ground`: an arch, a rock, a tree, a hall, a
##   tunnel), every WING_EVERY m;
## - both approaches are clear under a GLIDE glide FINAL m back from where
##   each touches (CLEAR m under it), and the climb out past the run on
##   (CLIMB a metre, CLEAR under it) for CLIMB_OUT m.
## None found: {}. The rival flies on and looks again (rival_line.gd).
##
## The strip: {touch (the rival's wheels down), stop (where it stands, on
## the ground), axis (the way both face, XZ), across (from its lane to his),
## lane (m between the lanes), spot {centre, half_len, half_wide}: his
## marks, beside its stop; start (the start line: between the lanes, at the
## stops), approach (where its final approach begins, in the air)}.

const WorldScale = preload("res://scripts/world_scale.gd")
const TreePlan = preload("res://scripts/endless/tree_plan.gd")
const PlaneStrip = preload("res://scripts/plane_strip.gd")

const SEA_Y := -40.0
## The rival's roll from its touch to its stop, the touch zone before its
## touch, his touch zone before his marks (both lanes level along them),
## and the run on past the stops for the takeoff (m).
const ROLL := 60.0
const TOUCH_ZONE := 30.0
const HIS_ZONE := 110.0
const RUN_ON := 60.0
## His lane: this many wingspans aside; his marks: half their length (m)
## and half their width (wingspans).
const LANE_SPANS := 3.5
const SPOT_HALF_LEN := 22.0
const SPOT_HALF_SPANS := 1.7
## The flats check's measure (land_ponds.gd `_strip`): no rise over
## STEP_RISE m between points STEP m apart, nor over SPAN_RISE m across
## SPAN m; DRY m over the sea and off any water. Read every READ m, and
## from read to read no steeper than READ_SLOPE (a ditch, a stream's bank).
const READ := 4.0
const READ_SLOPE := 0.2
const STEP := 16.0
const STEP_RISE := 1.92
const SPAN := 64.0
const SPAN_RISE := 3.84
const DRY := 2.0
## No tree planted within this far of either lane (m; `_tree_free`).
const TREE_ROOM := 12.0
## What stands: read every WING_EVERY m on each lane, its middle and its
## wingtips, at these heights over the ground (m).
const WING_EVERY := 6.0
const WING_AT := [0.8,2.4]
## The approaches and the climb out: the glide (m down a metre; `glide_y`,
## eased flat over its last FLARE m), how far back it is read (m), the room
## kept under it (m), the climb out (m up a metre) and how far on it is
## read (m).
const GLIDE := 0.1
const FLARE := 40.0
const FINAL := 340.0
const CLEAR := 4.0
const CLIMB := 0.15
const CLIMB_OUT := 360.0
## The spots tried: distances on (m, nearest IDEAL first), off its heading
## (rad, each way), the lanes' turn off the way there (rad).
const DIST := [500.0,650.0,800.0,950.0,1100.0,1300.0,1550.0,1800.0]
const IDEAL := 650.0
const SPREAD := [0.0,0.2,-0.2,0.4,-0.4,0.6,-0.6,0.85,-0.85]
const TURNS := [0.0,0.3,-0.3,0.55,-0.55]
## Out to the sides as well (rad), once nothing was found ahead.
const WIDE := [1.15,-1.15,1.45,-1.45]

## For checks: why spots failed ({reason: count}).
static var fails := {}

static func _fail(why: String) -> Dictionary:
	fails[why] = int(fails.get(why,0))+1
	return {}

## The lane's offset (m): LANE_SPANS wingspans.
static func lane() -> float:
	return WorldScale.span*LANE_SPANS

## The spots to try ahead of `pos` heading `dir` (XZ), best first:
## [[touch, axis, side], ...]; `wide`, out to the sides too (WIDE).
static func order(pos: Vector3, dir: Vector3, wide := false) -> Array:
	dir = Vector3(dir.x,0.0,dir.z).normalized()
	var ranked: Array = []
	var spread: Array = SPREAD+WIDE if wide else SPREAD
	for d: float in DIST:
		for off: float in spread:
			for turn: float in TURNS:
				for side: float in [1.0,-1.0]:
					ranked.append([absf(d-IDEAL)/IDEAL+absf(off)*0.8+absf(turn)*0.5+(0.01 if side < 0.0 else 0.0),d,off,turn,side])
	ranked.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var out: Array = []
	for o: Array in ranked:
		var bearing := atan2(-dir.x,-dir.z)+float(o[2])
		var yaw := bearing+float(o[3])
		out.append([pos+Vector3(-sin(bearing),0.0,-cos(bearing))*float(o[1]),Vector3(-sin(yaw),0.0,-cos(yaw)),float(o[4])])
	return out

## Spot `o` (one of `order`'s) tried for a rival now at `pos` heading
## `dir`: the strip, or {}.
static func try(line: RefCounted, o: Array, pos: Vector3, dir: Vector3) -> Dictionary:
	var touch: Vector3 = o[0]
	var axis: Vector3 = o[1]
	# The approach must begin ahead of it, not behind (out to the side, at
	# least clear of it).
	var start := touch-axis*FINAL-pos
	if start.dot(dir) < 120.0 and Vector2(start.x,start.z).length() < 400.0: return _fail("behind")
	return check(line.game,line,touch,axis,float(o[2]))

## A strip ahead of `pos` heading `dir` (XZ) for `line` (rival_line.gd: its
## ground reading and the study), or {}; all at once (`order` and `try` a
## few a frame is the rival's way). `tries` caps how many are read.
static func find(line: RefCounted, pos: Vector3, dir: Vector3, tries := 800, wide := false) -> Dictionary:
	var tried := 0
	for o: Array in order(pos,dir,wide):
		tried += 1
		if tried > tries: break
		var s := try(line,o,pos,dir)
		if not s.is_empty():
			s.tried = tried
			return s
	return {}

## The strip with the rival touching at `touch`, both facing `axis`, his
## lane `side` (1 right, -1 left) of its, or {} if it fails a test.
## `heights`, if given, keeps the land's heights on the trees' flats grid
## between checks (a search trying many strips near one spot reads each
## node once). With `stands` false the dearest reads (what stands on the
## approaches and the lanes) are left to the caller, one at a time
## (`late_count`, `late_read`; the strip keeps them as "late" till then).
static func check(game: Node, line: RefCounted, touch: Vector3, axis: Vector3, side: float, heights: Variant = null, stands := true) -> Dictionary:
	var field: RefCounted = game.field
	var across := axis.cross(Vector3.UP).normalized()*side
	var gap := lane()
	var stop := touch+axis*ROLL
	# Down both lanes: from the touch zones to the run on.
	var from := -ROLL-maxf(TOUCH_ZONE,HIS_ZONE)
	var to := RUN_ON
	var lanes: Array = [Vector3.ZERO,across*gap]
	var rows: Array = []
	for l: Vector3 in lanes:
		var hs := PackedFloat32Array()
		var u := from
		while u <= to+0.1:
			var p := stop+l+axis*u
			var h := float(field.sample(p.x,p.z).x)
			if h-SEA_Y < DRY or float(field.last_river) < DRY+WorldScale.span: return _fail("dry")
			var n := hs.size()
			if n > 0 and absf(h-hs[n-1]) > READ_SLOPE*READ: return _fail("bank")
			var j := int(STEP/READ)
			if n >= j and absf(h-hs[n-j]) > STEP_RISE: return _fail("step")
			var k := int(SPAN/READ)
			if n >= k and absf(h-hs[n-k]) > SPAN_RISE: return _fail("span")
			hs.append(h)
			u += READ
		rows.append(hs)
	# Across, lane to lane.
	var a: PackedFloat32Array = rows[0]
	var b: PackedFloat32Array = rows[1]
	for i in range(a.size()):
		if absf(a[i]-b[i]) > STEP_RISE*maxf(gap/STEP,0.5): return _fail("across")
	# Flat as the trees keep it open: no tree is planted near either lane.
	if not _tree_free(field,stop,axis,across,gap,from,to,heights): return _fail("trees")
	# The approaches (each lane's, from its touch back) and the climb out,
	# as [point, the line over it, why]: read on the bare land first (cheap;
	# what stands only adds to it), with all that stands at the end.
	var touch_y := float(field.height(touch.x,touch.z))
	var late: Array = []
	for l: Vector3 in lanes:
		var at := touch+l if l == Vector3.ZERO else stop+l-axis*SPOT_HALF_LEN
		# Read from where the lane's level run ends (that is checked above).
		var d := (at-(stop+l+axis*from)).dot(axis)+20.0
		while d <= FINAL:
			late.append([at-axis*d,touch_y+glide_y(d),"approach"])
			d += 20.0
		d = 20.0
		while d <= CLIMB_OUT:
			late.append([stop+l+axis*(RUN_ON*0.5+d),touch_y+CLIMB*d,"climb"])
			d += 20.0
	for e: Array in late:
		var p: Vector3 = e[0]
		if maxf(float(field.height(p.x,p.z)),SEA_Y)+CLEAR > float(e[1]): return _fail(e[2])
	var spot_c := stop+across*gap
	spot_c.y = float(field.height(spot_c.x,spot_c.z))
	stop.y = float(field.height(stop.x,stop.z))
	touch.y = touch_y
	var start := stop+across*gap*0.5
	start.y = float(field.height(start.x,start.z))
	var strip := {"touch":touch,"stop":stop,"axis":axis,"across":across,"lane":gap,"side":side,"start":start,
		"spot":{"centre":spot_c,"half_len":SPOT_HALF_LEN,"half_wide":WorldScale.span*SPOT_HALF_SPANS},
		"approach":touch-axis*FINAL+Vector3.UP*glide_y(FINAL)}
	strip["late"] = late
	if not stands: return strip
	for k in late_count(strip):
		var why := late_read(game,line,strip,k)
		if why != "": return _fail(why)
	strip.erase("late")
	return strip

## How many reads `check` without its stands leaves (`late_read`, any
## order): the approaches with what stands on them, then the lanes' rows.
static func late_count(strip: Dictionary) -> int:
	return (strip.late as Array).size()+stand_rows()

## `check`'s late read `k` of `strip`: "" if clear, else why not.
static func late_read(game: Node, line: RefCounted, strip: Dictionary, k: int) -> String:
	var late: Array = strip.late
	if k >= late.size(): return stand_row(game,strip,k-late.size())
	var e: Array = late[k]
	if _top(game,line,e[0])+CLEAR > float(e[1]): return e[2]
	return ""

## How many rows `stand_row` reads: down the lanes from the touch zones to
## the run on, WING_EVERY m apart.
static func stand_rows() -> int:
	return int((RUN_ON+ROLL+maxf(TOUCH_ZONE,HIS_ZONE)+0.1)/WING_EVERY)+1

## Nothing standing on row `k` of both of `strip`'s lanes or under the
## wings: "" if clear, else why not.
static func stand_row(game: Node, strip: Dictionary, k: int) -> String:
	var field: RefCounted = game.field
	var stop: Vector3 = strip.stop
	var axis: Vector3 = strip.axis
	var across: Vector3 = strip.across
	var u := -ROLL-maxf(TOUCH_ZONE,HIS_ZONE)+float(k)*WING_EVERY
	var half := WorldScale.span*0.6
	for l: Vector3 in [Vector3.ZERO,across*float(strip.lane)]:
		for w: float in [-half,0.0,half]:
			var p := stop+l+axis*u+across*w
			var h := float(field.height(p.x,p.z))
			for over: float in WING_AT:
				if bool(game._blocked(Vector3(p.x,h+float(over),p.z))): return "blocked"
			var g: Variant = game.plane_ground(Vector3(p.x,h+60.0,p.z))
			if g is Vector2: return "over"
			if g != null and float(g) > h+0.5: return "stands"
	return ""

## The glide's height over the touch `d` m short of it: GLIDE a metre,
## its slope eased to level over the last FLARE m (no sink at the touch).
static func glide_y(d: float) -> float:
	if d <= FLARE: return GLIDE*d*d/(2.0*FLARE)
	return GLIDE*(d-FLARE*0.5)

## What stands at `p` (spans counted), or the water over it.
static func _top(game: Node, line: RefCounted, p: Vector3) -> float:
	return maxf(float(line._ground_top(p,true)),float(game.water_at(Vector3(p.x,SEA_Y+1.0,p.z))))

## Whether no tree is planted within TREE_ROOM m of the lanes: every node
## of the trees' flats grid (TreePlan FLAT_STEP m) near enough to hold one
## is flat as TreePlan `_flat` reads it (FLAT_SLOPE across FLAT_REACH m
## either way), and the plan keeps every flat open.
static func _tree_free(field: RefCounted, stop: Vector3, axis: Vector3, across: Vector3, gap: float, from: float, to: float, heights: Variant = null) -> bool:
	var step := TreePlan.FLAT_STEP
	var r := roundi(TreePlan.FLAT_REACH/step)
	var most := TreePlan.FLAT_SLOPE*r*step*2.0
	# A tree's nearest node is within half a cell's diagonal of it.
	var grow := TREE_ROOM+step*0.75
	var u0 := from-grow
	var u1 := to+grow
	var v0 := -WorldScale.span*0.5-grow
	var v1 := gap+WorldScale.span*0.5+grow
	var box := Rect2(Vector2(stop.x,stop.z),Vector2.ZERO)
	for u: float in [u0,u1]:
		for v: float in [v0,v1]:
			var c := stop+axis*u+across*v
			box = box.expand(Vector2(c.x,c.z))
	var hs: Dictionary = heights if heights is Dictionary else {}
	var h := func(i: int, j: int) -> float:
		var k := Vector2i(i,j)
		if not hs.has(k): hs[k] = float(field.height(i*step,j*step))
		return hs[k]
	for j in range(floori(box.position.y/step),ceili(box.end.y/step)+1):
		for i in range(floori(box.position.x/step),ceili(box.end.x/step)+1):
			var o := Vector3(i*step-stop.x,0.0,j*step-stop.z)
			var u := o.dot(axis)
			var v := o.dot(across)
			if u < u0 or u > u1 or v < v0 or v > v1: continue
			if absf(float(h.call(i+r,j))-float(h.call(i-r,j))) > most: return false
			if absf(float(h.call(i,j+r))-float(h.call(i,j-r))) > most: return false
	return true

## Whether `p` (XZ) is inside his marks.
static func in_spot(strip: Dictionary, p: Vector3) -> bool:
	var spot: Dictionary = strip.spot
	var c: Vector3 = spot.centre
	var axis: Vector3 = strip.axis
	var across: Vector3 = strip.across
	var o := Vector3(p.x-c.x,0.0,p.z-c.z)
	return absf(o.dot(axis)) <= float(spot.half_len) and absf(o.dot(across)) <= float(spot.half_wide)

## Whether the strip is still clear (what stands near the eye is built as
## it comes near: a tree or a rock missed far off).
static func still_clear(game: Node, strip: Dictionary) -> bool:
	var field: RefCounted = game.field
	var stop: Vector3 = strip.stop
	var axis: Vector3 = strip.axis
	var across: Vector3 = strip.across
	var half := WorldScale.span*0.6
	for l: Vector3 in [Vector3.ZERO,across*float(strip.lane)]:
		var u := -ROLL-maxf(TOUCH_ZONE,HIS_ZONE)
		while u <= RUN_ON+0.1:
			for w: float in [-half,0.0,half]:
				var p := stop+l+axis*u+across*w
				var h := float(field.height(p.x,p.z))
				for over: float in WING_AT:
					if bool(game._blocked(Vector3(p.x,h+float(over),p.z))): return false
			u += WING_EVERY
	return true

## The rival's pose standing on its wheels at `at` (XZ) facing `heading`:
## Vector4(the flight's y, pitch, roll, the ground under the wheels).
static func rest(game: Node, at: Vector3, heading: float) -> Vector4:
	var field: RefCounted = game.field
	return PlaneStrip.rest(func(p: Vector2) -> float: return field.height(p.x,p.y),Vector2(at.x,at.z),heading)
