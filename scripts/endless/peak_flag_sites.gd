extends RefCounted
## Where the climbers' flags stand on the crown (spec-crown.md, lane flags): the
## marks of a way people went, up the stair, under the saddle, round the strip
## and the lake's rim and at the top. Everything hangs off the massif's own
## numbers (the gorge's line, the stair's flights, the tarn, the towers), so it
## follows the handles `peak/massif`, `peak/tarn`, `peak/stair/<n>` and
## `peak/tower/<n>`. Each pole and anchor has a name of its own,
## `peak/flags/<place>/<n>`, in the layout file: move one and its strings go
## with it, delete one and they go too.
##
## The plane flies through all of it (no colliders); so that a run never does
## so by accident, the strings that cross a gorge hang over the flown band
## (OVER_FLOOR) and the stair's keep to the wall side of the stair.

const LayoutOverrides = preload("res://scripts/layout_overrides.gd")
const PeakMassif = preload("res://scripts/endless/peak_massif.gd")
const Split = preload("res://scripts/endless/peak_split.gd")
const PeakTunnel = preload("res://scripts/endless/peak_tunnel.gd")

## A string's cloths, sparse: a rope that carries flags, not a line of bunting.
const SPARSE := {"width":3.0,"length":3.5,"gap":3.4,"missing":0.2}
## The great strings across a gap, seen from under and from farther off.
const GREAT := {"width":4.2,"length":5.4,"gap":6.2,"missing":0.2}
## The small ones by the water and the strip.
const SMALL := {"width":3.0,"length":3.5,"gap":2.6,"missing":0.16}

## Stretches of the stair that carry a string, as shares of its flights: the
## climb is marked now and then, not fenced.
const STAIR_RUNS := [[0.03,0.11],[0.24,0.31],[0.44,0.53],[0.66,0.72],[0.88,0.97]]
## The stair's poles: a pole every this many flights, this tall.
const STAIR_EVERY := 2
const STAIR_POLE := 15.0
## How far past the stair's cheek a pole stands, on its wall side (m).
const STAIR_OFF := 2.5
## Across the gorge: the anchors' height over the floor, and how many strings.
## With the sag and a cloth hanging this leaves the flown band (28 m over the
## floor, give or take a wobble: scratch/crown_fly.gd) well under the lowest cloth.
const OVER_FLOOR := 74.0
const ACROSS := 3
## Narrows no closer than this along the line (points of it).
const ACROSS_APART := 12
## Past the saddle, where the two gorges' lines are one (points of the rock
## gorge's line past its saddle), the great string's place. The walls are low
## there, so its anchors stand lower, on tall poles.
const SADDLE_PAST := 4
const SADDLE_OVER := 56.0
const SADDLE_STAKE := 20.0
## The saddle's two pennants: how far in from the floor's edge (m).
const SADDLE_IN := 16.0
## Round the strip (massif's a, v): the corners off its edges and ends (m), and
## how far a lake-side string runs in from each end, leaving the middle open.
const STRIP_OFF := Vector2(13.0,-6.0)
const STRIP_RUN := 54.0
## Round the lake, its far side: bearings off the way back from the plateau
## (degrees), the poles' distance past its widest reach, and which neighbours a
## string joins. The gap faces the strip's end and leaves the shore a shore.
const LAKE_AT := [-82.0,-52.0,-22.0,14.0,44.0,76.0]
const LAKE_JOIN := [[0,1],[1,2],[3,4],[4,5]]
const LAKE_OFF := 20.0
const LAKE_POLE := 13.0
## The tallest tower's tip: how far down from the axis's tip the pole may stand.
const SUMMIT_POLE := 16.0
## How far round the axis's tip the true top is looked for (steps of 3 m).
const SUMMIT_FEEL := 10

## Hangs everything on `flags` (PeakFlags). `stair` and `towers` may be null.
static func hang(flags: Node3D, peak: RefCounted, ground: Callable, stair: Node3D, towers: Node3D) -> void:
	_stair(flags,stair,ground)
	_across(flags,peak,ground)
	_saddle(flags,peak,ground)
	_strip(flags,peak,ground)
	_lake(flags,peak,ground)
	_summit(flags,peak,towers)
	_tunnel(flags,peak,ground)

## `name`'s place: the file's, else the coded `p`. Null if the file deleted it.
static func _spot(name: String, p: Vector3) -> Variant:
	if LayoutOverrides.deleted(name): return null
	return LayoutOverrides.xform(name,Transform3D(Basis.IDENTITY,p)).origin

## The pole `name` at `p` with `opts`; its top, or null if deleted.
static func _pole(flags: Node3D, name: String, p: Vector3, opts := {}) -> Variant:
	var at: Variant = _spot(name,p)
	if at == null: return null
	return flags.add_pole(at,opts.merged({"seed":hash(name)}))

## A string between two tops, skipped when either is gone.
static func _string(flags: Node3D, name: String, a: Variant, b: Variant, sag: float, opts: Dictionary) -> void:
	if a == null or b == null: return
	flags.add_string(a,b,sag,opts.merged({"seed":hash(name)}))

# --- The stair --------------------------------------------------------------

## Stretches of poles on the stair's wall side, a string pole to pole.
static func _stair(flags: Node3D, stair: Node3D, ground: Callable) -> void:
	if stair == null: return
	var flights: Array = stair.get("flights")
	var n := flights.size()
	if n < 8: return
	var pole_n := 0
	for r in STAIR_RUNS.size():
		var run: Array = STAIR_RUNS[r]
		var from := int(float(run[0])*n)
		var to := mini(int(float(run[1])*n),n-1)
		var last: Variant = null
		var k := from
		while k <= to:
			var top: Variant = _pole(flags,"peak/flags/stair/%d" % pole_n,_flank(flights[k],ground),{"height":STAIR_POLE,"lean":4.0,"pennant":pole_n%3 == 1,"hoist":2.6,"fly":7.0})
			if last != null: _string(flags,"peak/flags/stair_string/%d" % pole_n,last,top,-1.0,SPARSE.merged({"wear":0.42+0.08*r}))
			last = top
			pole_n += 1
			k += STAIR_EVERY

## A flight's flank on its wall side, on the ground: the side whose ground
## climbs soonest past it.
static func _flank(f: Dictionary, ground: Callable) -> Vector3:
	var xf: Transform3D = f.xf
	var c := xf.origin
	var across := xf.basis.x.normalized()
	var reach := float(f.half)*xf.basis.x.length()+STAIR_OFF
	var best := Vector3.ZERO
	var high := -INF
	for sg: float in [-1.0,1.0]:
		var out := c+across*sg*(reach+14.0)
		var y := float(ground.call(out.x,out.z))
		if y > high:
			high = y
			var p := c+across*sg*reach
			best = Vector3(p.x,float(ground.call(p.x,p.z)),p.z)
	return best

# --- Across the gorge -------------------------------------------------------

## The ground `over` m over the floor at `p`, walking out along `way` from
## `from` m; null if the wall never gets there.
static func _wall(p: Vector3, way: Vector2, from: float, over: float, ground: Callable) -> Variant:
	var r := from
	while r < 300.0:
		var w := Vector2(p.x,p.z)+way*r
		var y := float(ground.call(w.x,w.y))
		if y >= p.y+over: return Vector3(w.x,y,w.y)
		r += 3.0
	return null

## Two strings high across the rock gorge's narrows, wall to wall.
static func _across(flags: Node3D, peak: RefCounted, ground: Callable) -> void:
	var g: Dictionary = peak.gorge(Split.ROCK)
	var line: Array = g.line
	var half: PackedFloat32Array = g.half
	var last: int = g.saddle
	# The narrows, narrowest first, past the first of the stair.
	var order: Array = []
	for k in range(int(0.2*last),int(0.9*last)):
		if half[k] <= half[k-1] and half[k] <= half[k+1]: order.append(k)
	order.sort_custom(func(x: int, y: int) -> bool: return half[x] < half[y])
	var taken: Array[int] = []
	for k: int in order:
		if taken.size() >= ACROSS: break
		var near := false
		for t in taken: near = near or absi(t-k) < ACROSS_APART
		if near: continue
		var n: Vector2 = g.side[k]
		var a: Variant = _wall(line[k],n,half[k],OVER_FLOOR,ground)
		var b: Variant = _wall(line[k],-n,half[k],OVER_FLOOR,ground)
		if a == null or b == null: continue
		var i := taken.size()
		taken.append(k)
		_great(flags,"peak/flags/across/%d" % i,a,b,5.0)

## A great string on two stakes `tall` driven into the walls.
static func _great(flags: Node3D, name: String, a: Vector3, b: Vector3, tall: float) -> void:
	var stake := {"height":tall,"lean":9.0,"pennant":false,"cairn":false}
	var ta: Variant = _pole(flags,name+"/a",a,stake)
	var tb: Variant = _pole(flags,name+"/b",b,stake)
	_string(flags,name,ta,tb,a.distance_to(b)*0.05,GREAT.merged({"wear":0.65,"tails":true}))

# --- The saddle -------------------------------------------------------------

## The way over: a great string high across where the gorges have joined, and
## a tall pennant each side of the floor.
static func _saddle(flags: Node3D, peak: RefCounted, ground: Callable) -> void:
	var g: Dictionary = peak.gorge(Split.ROCK)
	var line: Array = g.line
	var k := mini(int(g.saddle)+SADDLE_PAST,line.size()-1)
	var n: Vector2 = g.side[k]
	var a: Variant = _wall(line[k],n,float(g.half[k]),SADDLE_OVER,ground)
	var b: Variant = _wall(line[k],-n,float(g.half[k]),SADDLE_OVER,ground)
	if a != null and b != null: _great(flags,"peak/flags/saddle_string",a,b,SADDLE_STAKE)
	var s: int = g.saddle
	var mid: Vector3 = line[s]
	var across: Vector2 = g.side[s]
	var reach := float(g.half[s])-SADDLE_IN
	for i in 2:
		var w := Vector2(mid.x,mid.z)+across*(1.0 if i == 0 else -1.0)*reach
		_pole(flags,"peak/flags/saddle/%d" % i,Vector3(w.x,float(ground.call(w.x,w.y)),w.y),{"height":22.0,"fly":11.0,"lean":5.0})

# --- The strip --------------------------------------------------------------

## Poles off the strip's corners, and from the lake-side ones a short string in
## along it each way, the middle left open for the way to the water. Nothing
## crosses the strip, its ends or the apron.
static func _strip(flags: Node3D, peak: RefCounted, ground: Callable) -> void:
	var a: float = peak.STRIP.x
	var along: float = peak.STRIP.y+STRIP_OFF.y
	var off: float = peak.STRIP.z+STRIP_OFF.x
	var at := func(ta: float, tv: float) -> Vector3:
		var w: Vector2 = peak.world(ta,tv)
		return Vector3(w.x,float(ground.call(w.x,w.y)),w.y)
	var i := 0
	for sg: float in [-1.0,1.0]:
		_pole(flags,"peak/flags/strip/%d" % i,at.call(a+off,sg*along),{"height":14.0,"fly":8.0,"hoist":2.8,"lean":3.0})
		var corner: Variant = _pole(flags,"peak/flags/strip/%d" % (i+1),at.call(a-off,sg*along),{"height":14.0,"pennant":false,"lean":3.0})
		var inner: Variant = _pole(flags,"peak/flags/strip/%d" % (i+2),at.call(a-off,sg*(along-STRIP_RUN)),{"height":12.0,"pennant":false,"lean":5.0})
		_string(flags,"peak/flags/strip_string/%d" % i,corner,inner,-1.0,SMALL.merged({"wear":0.4}))
		i += 3

# --- The lake ---------------------------------------------------------------

## A broken ring of poles round the far side of the water.
static func _lake(flags: Node3D, peak: RefCounted, ground: Callable) -> void:
	var t: Dictionary = peak.tarn()
	var c: Vector3 = t.centre
	var back: Vector2 = -(peak.facing as Vector2)
	var level: float = t.level
	var tops: Array = []
	for i in LAKE_AT.size():
		var way := back.rotated(deg_to_rad(float(LAKE_AT[i])))
		var r := float(t.widest)+LAKE_OFF
		var w := Vector2(c.x,c.z)+way*r
		# Out of the water, whatever the lobes do.
		while float(ground.call(w.x,w.y)) < level+1.5 and r < float(t.widest)+90.0:
			r += 6.0
			w = Vector2(c.x,c.z)+way*r
		tops.append(_pole(flags,"peak/flags/lake/%d" % i,Vector3(w.x,float(ground.call(w.x,w.y)),w.y),{"height":LAKE_POLE,"pennant":i%2 == 1,"hoist":2.4,"fly":6.5}))
	for q: Array in LAKE_JOIN:
		_string(flags,"peak/flags/lake_string/%d_%d" % [q[0],q[1]],tops[q[0]],tops[q[1]],-1.0,SMALL.merged({"wear":0.5}))

# --- The top ----------------------------------------------------------------

## One pole on the tallest tower's tip, a long pennant, a cairn: somebody got up there.
static func _summit(flags: Node3D, peak: RefCounted, towers: Node3D) -> void:
	if towers == null: return
	var best := {}
	for ax: Dictionary in towers.axes():
		if best.is_empty() or float(ax.tip.y) > float(best.tip.y): best = ax
	if best.is_empty(): return
	# The true top: the tip's axis may stand over a notch in its broken crown.
	var tip: Vector3 = best.tip
	var at := tip
	var y := -INF
	for i in range(-SUMMIT_FEEL,SUMMIT_FEEL+1):
		for j in range(-SUMMIT_FEEL,SUMMIT_FEEL+1):
			var q := tip+Vector3(i,0.0,j)*3.0
			var top: float = towers.top_near(q,0.5)
			if top > y and top < tip.y+10.0:
				y = top
				at = q
	if y < tip.y-90.0: y = tip.y
	_pole(flags,"peak/flags/summit/0",Vector3(at.x,y,at.z),{"height":SUMMIT_POLE,"radius":0.2,"lean":6.0,"hoist":3.0,"fly":13.0,"wear":0.75})

# --- The ice tunnel's mouth ---------------------------------------------------

## The way to mouth A. The mouth sits low in the bank's hummocks and hides
## from most of the glacier, but the bank over it shows from the toe up: so
## a gate of two tall stakes on the rock over the mouth (TUNNEL_GATE m in
## from the mouth, TUNNEL_GATE_SIDE m each side of the line) with a great
## string between, over the vault, never in the flown band; and pairs of
## poles from just out of the mouth back along its approach toward the
## glacier, a sparse string pole to pole along each side. Nothing crosses
## the open line: the poles stand TUNNEL_SIDE m off it (past the cut and its
## lip), their strings run along it.
const TUNNEL_PAIRS := 5
const TUNNEL_EVERY := 36.0
const TUNNEL_SIDE := 26.0
const TUNNEL_POLE := 16.0
const TUNNEL_TALL := 22.0
const TUNNEL_GATE := 14.0
const TUNNEL_GATE_SIDE := 20.0
const TUNNEL_STAKE := 26.0

## Off with `--ice-tunnel=0` (PeakTunnel.make is null then).
static func _tunnel(flags: Node3D, peak: RefCounted, ground: Callable) -> void:
	var t: RefCounted = PeakTunnel.make(peak)
	if t == null: return
	# The gate: its string only when its lowest cloth clears the vault's
	# crown by 6 m and more.
	var sg0 := PeakTunnel.MOUTH_A+TUNNEL_GATE
	var gc: Vector2 = t.at_s(sg0)
	var gt: Vector2 = t.tan_s(sg0)
	var gn := Vector2(-gt.y,gt.x)
	var stake := {"height":TUNNEL_STAKE,"lean":5.0,"fly":12.0}
	var tops: Array = []
	for side in 2:
		var w := gc+gn*(1.0 if side == 0 else -1.0)*TUNNEL_GATE_SIDE
		tops.append(_pole(flags,"peak/flags/tunnel/gate/%d" % side,Vector3(w.x,float(ground.call(w.x,w.y)),w.y),stake))
	if tops[0] != null and tops[1] != null:
		var span: float = (tops[0] as Vector3).distance_to(tops[1])
		var low: float = minf(tops[0].y,tops[1].y)-span*0.05-float(GREAT.length)
		if low > float(t.floor_at(sg0))+float(t.profile(sg0).y)+6.0:
			_string(flags,"peak/flags/tunnel/gate",tops[0],tops[1],span*0.05,GREAT.merged({"wear":0.6,"tails":true}))
	var c0: Vector2 = t.at_s(0.0)
	var back: Vector2 = -t.tan_s(0.0)
	var prev: Array = [null,null]
	for i in TUNNEL_PAIRS:
		# Metres along the line: past 0, back out along the approach.
		var d := PeakTunnel.MOUTH_A-PeakTunnel.MOUTH_OUT_A+6.0-i*TUNNEL_EVERY
		var c: Vector2 = t.at_s(d) if d >= 0.0 else c0+back*(-d)
		var tg: Vector2 = t.tan_s(d) if d >= 0.0 else -back
		var n := Vector2(-tg.y,tg.x)
		for side in 2:
			var sg := 1.0 if side == 0 else -1.0
			# Staggered a little, so the pairs aren't a fence.
			var w := c+n*sg*TUNNEL_SIDE+tg*(5.0*sg if i > 0 else 0.0)
			var p := Vector3(w.x,float(ground.call(w.x,w.y)),w.y)
			var name := "peak/flags/tunnel/%d/%d" % [i,side]
			var opts := {"height":TUNNEL_TALL,"fly":11.0,"lean":4.0} if i == 0 else {"height":TUNNEL_POLE,"fly":8.0}
			var top: Variant = _pole(flags,name,p,opts)
			_string(flags,name+"/string",prev[side],top,-1.0,SPARSE)
			prev[side] = top
