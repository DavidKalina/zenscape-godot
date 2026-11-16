extends Node3D
## The ruined hillside sanctuary on the ridge north-west of the Peak (seed 1,
## the wilderness): five terraces stepping up the ridge's seaward face from the
## plain to its crest, from the sanctuary's own pieces
## (art/blender/temple_kit/sanctuary_build.py) and the temple kit's.
##
## The frame: O the foot of the axis on the plain, U the way uphill, V across
## (U turned a quarter, the right hand looking uphill). A point is O + U*s +
## V*v; the pieces are laid in that frame turned so -z is uphill, at
## (v, height, -s). Bays are BAY wide: bay k is centred on v = k*BAY, row r
## spans s = F0 + r*BAY on.
##
## - The levels: LEVEL[j] (j 1..5) the floor of terrace j, 26 m apart, each
##   three rows deep and narrower than the one under it (bays KL[j]..KR[j]). A
##   level's wall stands on the level below along its front and sides and goes
##   on down under it, so it meets whatever ground is there; its floor is deck
##   bays wherever the hill isn't already higher. The fourth level's left end
##   has slipped away (its wall's stumps and spill lie on the third).
## - The great stair up the axis, three bays wide, a flight to each level. The
##   flights to the second and third levels have a way through under them
##   along the level below (14.5 m by 13.5 m).
## - Walls one and two are arcades (arches 14.5 m by 21.25 m) with a gallery
##   behind them under the level's first row (17 m by 23 m), fallen in over two
##   bays left of the stair (and two right of it on the first); each gallery's left end is a cracked wall.
## - The sunken stair: up bay TRENCH through walls three, four and five by a
##   gateway each (two piers, 14.5 m clear, open above) and a flight in a cut
##   behind it.
## - On the levels: a pair of columns under a lintel at the head of each
##   flight, more columns along the second level's edge, a podium and its last
##   columns on the third, the temple's on the fifth; a gate, an altar and
##   paving on the plain.
##
## What the plane breaks in a surge roll (temple_breaks.gd): each gallery's
## cracked end wall ("sanctuary/end_wall_1", "sanctuary/end_wall_2": a breach
## is left to fly out through) and the cracked lintel over the axis on the
## third level ("sanctuary/lintel").
##
## Drawn as the theatre is (theatre_site.gd): MultiMeshes per piece and LOD,
## a set per 74 m square of the site, made on the main thread once a worker has sorted the
## pieces; a StaticBody3D and a LandArches `loose` record per level in the
## site's turned frame, so the pieces' boxes stay exact. Trees keep off
## (`tree_keepouts`), grass keeps off what is built over (`grass_off`).
## `--sanctuary=0`: none.

const TempleKit = preload("res://scripts/temple_kit.gd")
const BoxSolid = preload("res://scripts/endless/box_solid.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const TempleBreaks = preload("res://scripts/endless/temple_breaks.gd")

const B := TempleKit.BAY
const O := Vector2(-4652.7,-2252.6)
const UP_DEG := 60.0
## The plain's datum under the first wall, then each level's floor.
const LEVEL: Array[float] = [-18.0,8.0,34.0,60.0,86.0,112.0]
## sanctuary_build.py's numbers: a wall's height, the stair bay's rise.
const RISE := 26.0
const STAIR_RISE := 13.0
## Where the first wall stands (s) and the rows' count; wall j stands at
## F0 + 3*BAY*(j-1).
const F0 := 78.0
const ROWS := 15
## Each level's first and last bay (index j; 0 unused).
const KL: Array[int] = [0,-5,-5,-4,-2,-2]
const KR: Array[int] = [0,5,5,4,3,2]
## The sunken stair's bay.
const TRENCH := 2
## Wall j's bays, KL[j] on: w wall, a arch, x fallen arch, o gateway, b burst,
## - none (behind the great stair).
const WALLS: Array[String] = ["","aaxxwwwaxxa","aaxxwwwaaaa","wwwwwwoww","b---ow","w---o"]
## The trees' keep-out: its middle (s), half across and half along.
const KEEP_S := 180.0
const KEEP_HALF := Vector2(128.0,200.0)
const REACH := 3000.0
const FREE := 3400.0
## The drawing's sets are cut on a grid this wide (m), so a set's near and mid
## LODs reach only a little past its own stones.
const CELL := 74.0
const MID_NEAREST := 50.0
const FAR_NEAREST := 280.0

var game: Node3D
## {root (the site's frame, world), draws ([id, xf in the frame, level]), state, task, made, nodes, records}.
var site := {}
## The cracked pieces (temple_breaks.gd).
var breaks: Node3D

static func wanted() -> bool:
	return not ("--sanctuary=0" in LaunchArgs.user_args())

static func _u() -> Vector2:
	return Vector2.from_angle(deg_to_rad(UP_DEG))

static func _v() -> Vector2:
	var u := _u()
	return Vector2(-u.y,u.x)

## The world XZ of (v, s).
static func at_vs(v: float, s: float) -> Vector2:
	return O+_u()*s+_v()*v

## The site's frame: -z uphill, +x along V, at height 0.
static func frame() -> Transform3D:
	var u := _u()
	return Transform3D(Basis(Vector3.UP,atan2(-u.x,-u.y)),Vector3(O.x,0.0,O.y))

## TreePlan's keep-outs near a world rectangle, [centre XZ, cos, sin, half across, half along].
static func tree_keepouts(x0: float, z0: float, x1: float, z1: float) -> Array:
	if not wanted(): return []
	var c := at_vs(0.0,KEEP_S)
	if c.x < x0-500.0 or c.x > x1+500.0 or c.y < z0-500.0 or c.y > z1+500.0: return []
	var v := _v()
	return [[c,v.x,-v.y,KEEP_HALF.x,KEEP_HALF.y]]

static func _g(field: Object, v: float, s: float) -> float:
	var p := at_vs(v,s)
	return float(field.call("height",p.x,p.y))

## A piece's frame in the site's: at (v, y, s), turned `yaw` about y.
static func _at(v: float, y: float, s: float, yaw := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP,yaw),Vector3(v,y,-s))

## Wall j's line (s).
static func wall_s(j: int) -> float:
	return F0+3.0*B*(j-1)

## Row r's middle (s).
static func row_s(r: int) -> float:
	return F0+B*(r+0.5)

## The level standing over bay k, row r (0: none).
static func level_at(k: int, r: int) -> int:
	if r < 0 or r >= ROWS: return 0
	for j in range(5,0,-1):
		if r >= 3*(j-1) and k >= KL[j] and k <= KR[j]: return j
	return 0

## Whether wall j's bay k is a fallen arch: 0 no, 1 the left of its pair, 2 the right.
static func _fallen(j: int, k: int) -> int:
	var row: String = WALLS[j]
	var i := k-KL[j]
	if i < 0 or i >= row.length() or row[i] != "x": return 0
	return 2 if i > 0 and row[i-1] == "x" else 1

## Whether bay k, row r is the sunken stair's cut (no floor: its flight).
static func _cut(k: int, r: int) -> bool:
	if k != TRENCH: return false
	for j: int in [3,4,5]:
		if r == 3*(j-1) or r == 3*(j-1)+1: return true
	return false

## The lowest and highest ground under a bay (its middle and corners).
static func _under(field: Object, v: float, s: float, half := B*0.45) -> Vector2:
	var lo := INF
	var hi := -INF
	for d: Vector2 in [Vector2.ZERO,Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
		var h := _g(field,v+d.x*half,s+d.y*half)
		lo = minf(lo,h)
		hi = maxf(hi,h)
	return Vector2(lo,hi)

## Every piece, in the site's frame: [id, xf, level]; a cracked one
## [id, xf, level, its name, what is left ([id, xf])].
static func layout(field: Object) -> Array:
	var out: Array = []
	# ---- The floors: a deck bay wherever a level stands and the hill is lower.
	for r in range(ROWS):
		for k in range(-5,6):
			var j := level_at(k,r)
			if j == 0 or _cut(k,r): continue
			var v := k*B
			var s := row_s(r)
			if _under(field,v,s).x > LEVEL[j]+0.4: continue
			var id: StringName = &"sanctuary_deck"
			var yaw := 0.0
			if r == 3*(j-1) and _fallen(j,k) > 0:
				id = &"sanctuary_deck_broken"
				yaw = 0.0 if _fallen(j,k) == 1 else PI
			elif j == 4 and r == 9 and k == KL[4]:
				id = &"sanctuary_deck_broken"
				yaw = -PI*0.5
			out.append([id,_at(v,LEVEL[j],s,yaw),j])
	# ---- The walls: front, sides and back of each level.
	for j in range(1,6):
		var base := LEVEL[j-1]
		var f := wall_s(j)
		var row: String = WALLS[j]
		for i in range(row.length()):
			var k := KL[j]+i
			var v := k*B
			var id: StringName
			var yaw := 0.0
			match row[i]:
				"w": id = &"sanctuary_wall"
				"a": id = &"sanctuary_arch"
				"x":
					id = &"sanctuary_arch_broken"
					if _fallen(j,k) == 2: yaw = PI
				"o": id = &"sanctuary_slot_open"
				"b": id = &"sanctuary_wall_burst"
				_: continue
			out.append([id,_at(v,base,f,yaw),j])
			if row[i] == "b":
				# The burst bay: an inner wall behind the breach, its spill before it.
				out.append([&"sanctuary_wall",_at(v,base,f+5.0),j])
				out.append([&"sanctuary_spill",_at(v,base,f),j-1])
		# The second gallery's floor: the first level carried on under it.
		if j == 2:
			for k in range(KL[j],KR[j]+1): out.append([&"sanctuary_deck",_at(k*B,base,f+B*0.5),1])
		# The gallery's back wall.
		if j <= 2:
			for k in range(KL[j],KR[j]+1):
				if _under(field,k*B,f+20.0,B*0.4).x > LEVEL[j]: continue
				out.append([&"sanctuary_wall",_at(k*B,base,f+20.0),j])
		# Sides and back: a wall wherever the bay beside is lower and the hill hasn't covered it.
		for r in range(3*(j-1),ROWS):
			for side: int in [-1,1]:
				var k: int = KL[j] if side < 0 else KR[j]
				if level_at(k,r) < j or level_at(k+side,r) >= j: continue
				var v := (k+side*0.5)*B
				var s := row_s(r)
				if _g(field,v+side*2.0,s) > LEVEL[j] and _g(field,v+side*2.0,s-B*0.5) > LEVEL[j]: continue
				# A gallery's ends: the left a cracked wall, the right open.
				if j <= 2 and r == 3*(j-1):
					if side > 0:
						if j == 1: out.append([&"sanctuary_arch",_at(v,base,f+10.0,PI*0.5),j])
						continue
					var xf := _at(v,base,f+10.0,-PI*0.5)
					out.append([&"sanctuary_wall_cracked",xf,j,"sanctuary/end_wall_%d" % j,[[&"sanctuary_wall_holed",xf]]])
					continue
				out.append([&"sanctuary_wall",_at(v,base,s,side*PI*0.5),j])
		for k in range(KL[j],KR[j]+1):
			if level_at(k,ROWS-1) != j: continue
			var s := F0+B*ROWS
			if _under(field,k*B,s+2.0,B*0.4).x > LEVEL[j]: continue
			out.append([&"sanctuary_wall",_at(k*B,base,s,PI),j])
	# The slipped end of level four: its outer wall's stumps, front and side.
	out.append([&"sanctuary_wall_stump",_at((KL[4]-1)*B,LEVEL[3],wall_s(4)),4])
	out.append([&"sanctuary_wall_stump",_at((KL[4]-1.5)*B,LEVEL[3],row_s(9),-PI*0.5),4])
	# ---- The great stair: a flight to each level, three bays wide; a way
	# through under the flights to levels two and three.
	for j in range(1,6):
		var f := wall_s(j)
		for k: int in [-1,0,1]:
			out.append([&"sanctuary_stair",_at(k*B,LEVEL[j-1],f-B*1.5),j-1])
			var upper: StringName = &"sanctuary_stair_arch" if j == 2 or j == 3 else &"sanctuary_stair"
			out.append([upper,_at(k*B,LEVEL[j-1]+STAIR_RISE,f-B*0.5),j-1])
	# ---- The sunken stair: a flight in a cut behind each gateway, walled.
	for j: int in [3,4,5]:
		var f := wall_s(j)
		var v := TRENCH*B
		out.append([&"sanctuary_stair",_at(v,LEVEL[j-1],f+B*0.5),j])
		out.append([&"sanctuary_stair",_at(v,LEVEL[j-1]+STAIR_RISE,f+B*1.5),j])
		for r: int in [0,1]:
			var s := f+B*(r+0.5)
			out.append([&"sanctuary_wall",_at(v-B*0.5,LEVEL[j-1],s,PI*0.5),j])
			if level_at(TRENCH+1,3*(j-1)+r) >= j: out.append([&"sanctuary_wall",_at(v+B*0.5,LEVEL[j-1],s,-PI*0.5),j])
	_dress(field,out)
	return out

## The kit's pieces on the levels.
static func _dress(field: Object, out: Array) -> void:
	var c := B*0.5
	# ---- The plain: the gate on the axis, paving to the stair's foot, an altar, a statue's base.
	out.append([&"agora_gate",_at(0.0,_g(field,0.0,6.0)-0.3,6.0,PI*0.5),0])
	for i: int in [-1,0,1]:
		for s: float in [22.0,40.5]:
			out.append([&"agora_paving_broken" if (i+int(s))%2 == 0 else &"agora_paving",_tile(field,i*B,s,i*PI*0.5),0])
	out.append([&"agora_altar",_at(31.0,_g(field,31.0,24.0)+0.05,24.0,0.2),0])
	out.append([&"agora_plinth",_at(-33.0,_g(field,-33.0,30.0)+0.05,30.0,1.1),0])
	out.append([&"column_broken",_at(-c,_g(field,-c,-12.0)-0.1,-12.0),0])
	out.append([&"column",_at(c,_g(field,c,-12.0)-0.1,-12.0),0])
	# What fell from the galleries: heaps in the fallen bays and before them.
	for e: Array in [[1,-2.6,-13.0,0.4],[1,-2.4,13.5,2.2],[2,-2.6,-13.0,0.4],[2,-2.4,13.5,2.2],[1,3.4,-12.0,1.9],[1,3.6,13.5,0.3]]:
		var j := int(e[0])
		var v := float(e[1])*B
		var s := wall_s(j)+float(e[2])
		var gy := (_g(field,v,s) if j == 1 else LEVEL[1])-0.3
		out.append([&"aqueduct_rubble",_at(v,gy,s,float(e[3])),j-1])
	# ---- Level one: an altar right of the stair, a drum.
	out.append([&"agora_altar",_at(2.0*B,LEVEL[1]+0.05,wall_s(1)+13.0,1.6),1])
	out.append([&"agora_drum",_at(-4.6*B,LEVEL[1]+0.05,wall_s(1)+9.0,0.7),1])
	# ---- Level two: columns along its edge at the stair's head and right of it.
	var s2 := wall_s(2)+c
	for e: Array in [[-3.0*c,&"column"],[-c,&"column"],[c,&"column"],[3.0*c,&"column"],[5.0*c,&"column"],[7.0*c,&"column_broken"],[9.0*c,&"column"]]:
		out.append([e[1],_at(float(e[0]),LEVEL[2],s2),2])
	for m: float in [-2.0*c,0.0,2.0*c,4.0*c]:
		out.append([&"lintel",_at(m,LEVEL[2],s2),2])
	out.append([&"lintel_broken",_at(6.0*c,LEVEL[2],s2),2])
	# ---- Level three: the pair at the stair's head under the cracked lintel;
	# a podium on the right wing, two of its columns under a lintel, one a stump, one down.
	var s3 := wall_s(3)+c
	out.append([&"column",_at(-c,LEVEL[3],s3),3])
	out.append([&"column",_at(c,LEVEL[3],s3),3])
	var lx := _at(0.0,LEVEL[3],s3)
	out.append([&"agora_lintel_cracked",lx,3,"sanctuary/lintel",[[&"lintel_broken",lx]]])
	var py := LEVEL[3]+3.0
	for kv: float in [3.0,4.0]:
		for ds: float in [B,2.0*B]:
			out.append([&"sanctuary_deck",_at(kv*B,py,wall_s(3)+ds),3])
	out.append([&"column",_at(3.0*B,py,wall_s(3)+2.0*B),3])
	out.append([&"column",_at(4.0*B,py,wall_s(3)+2.0*B),3])
	out.append([&"lintel",_at(3.5*B,py,wall_s(3)+2.0*B),3])
	out.append([&"column_broken",_at(4.0*B,py,wall_s(3)+B),3])
	out.append([&"agora_drum",_at(3.1*B,py+0.05,wall_s(3)+0.9*B,0.4),3])
	out.append([&"agora_altar",_at(-3.2*B,LEVEL[3]+0.05,wall_s(3)+26.0,0.1),3])
	# The slip's leavings on level three's left end: deck bays tipped, heaps.
	for e: Array in [[-3.1,wall_s(4)+10.0,0.34,-0.2,-3.0],[-3.4,wall_s(4)+29.0,-0.22,0.3,-1.0]]:
		var xf := _at(float(e[0])*B,LEVEL[3]+7.0+float(e[4]),float(e[1]))
		xf.basis = Basis(Vector3(1,0,0),float(e[2]))*Basis(Vector3(0,0,1),float(e[3]))
		out.append([&"sanctuary_deck_broken",xf,3])
	out.append([&"aqueduct_rubble",_at(-3.0*B,LEVEL[3]-0.3,wall_s(4)+20.0,1.2),3])
	out.append([&"baths_rubble",_at(-3.3*B,LEVEL[3]-0.3,wall_s(4)-9.0,0.5),3])
	# ---- Level four: the pair and lintel, a stump, an altar.
	var s4 := wall_s(4)+c
	out.append([&"column",_at(-c,LEVEL[4],s4),4])
	out.append([&"column",_at(c,LEVEL[4],s4),4])
	out.append([&"lintel",_at(0.0,LEVEL[4],s4),4])
	out.append([&"column_broken",_at(-3.0*c,LEVEL[4],s4),4])
	out.append([&"agora_plinth",_at(-1.5*B,LEVEL[4]+0.05,wall_s(4)+2.0*B,2.0),4])
	# ---- Level five: the temple: its front's three columns and the left
	# flank's under their lintels, the back's one, the rest stumps.
	var f5 := wall_s(5)
	for e: Array in [[-3.0*c,c,&"column"],[-c,c,&"column"],[c,c,&"column"],
			[-3.0*c,3.0*c,&"column"],[-3.0*c,5.0*c,&"column"],[-c,5.0*c,&"column"],[c,5.0*c,&"column_broken"],[3.0*c,5.0*c,&"column_broken"]]:
		var v := float(e[0])
		var s := f5+float(e[1])
		out.append([e[2],_at(v,maxf(LEVEL[5],_g(field,v,s)-1.5),s),5])
	out.append([&"lintel",_at(-2.0*c,LEVEL[5],f5+c),5])
	out.append([&"lintel",_at(0.0,LEVEL[5],f5+c),5])
	out.append([&"lintel",_at(-3.0*c,LEVEL[5],f5+2.0*c,PI*0.5),5])
	out.append([&"lintel",_at(-3.0*c,LEVEL[5],f5+4.0*c,PI*0.5),5])
	out.append([&"agora_drum",_at(1.4*B,LEVEL[5]+0.05,f5+1.6*B,1.3),5])

## A paving tile's frame on the plain: on the ground's own tilt, sunk a little.
static func _tile(field: Object, v: float, s: float, yaw: float) -> Transform3D:
	var h := B*0.5
	var hx0 := _g(field,v-h,s)
	var hx1 := _g(field,v+h,s)
	var hz0 := _g(field,v,s+h)
	var hz1 := _g(field,v,s-h)
	var hc := (_g(field,v,s)+hx0+hx1+hz0+hz1)/5.0
	var n := Vector3(-(hx1-hx0)/B,1.0,-(hz1-hz0)/B).normalized()
	var tilt := Basis()
	var ax := Vector3.UP.cross(n)
	if ax.length() > 1e-5: tilt = Basis(ax.normalized(),Vector3.UP.angle_to(n))
	return Transform3D(tilt*Basis(Vector3.UP,yaw),Vector3(v,hc-0.08,-s))

## The grass kept off what is built over (endless_grass.gd grow_cell, over its
## cell's LandField.grid): every node under a level's floor or the stair, and
## on the plain's paving, reads as a river's water (`river` -1, as the
## agora's), so none grows up through a floor. Where the hill stands higher
## than the level over it, its grass stays. Seed 1 only.
static func grass_off(got: Dictionary, land_seed: int, x0: float, z0: float, n: int, pad: int) -> void:
	if land_seed != 1 or not wanted() or not got.has("river"): return
	var gx0 := x0-pad
	var gz0 := z0-pad
	var c := at_vs(0.0,KEEP_S)
	var reach := 240.0
	if gx0+n-1 < c.x-reach or gx0 > c.x+reach or gz0+n-1 < c.y-reach or gz0 > c.y+reach: return
	var u := _u()
	var w := _v()
	var rs: PackedFloat32Array = got.river
	var hs: PackedFloat32Array = got.get("heights",PackedFloat32Array())
	var tall := hs.size() == rs.size()
	var i0 := maxi(ceili(c.x-reach-gx0),0)
	var i1 := mini(floori(c.x+reach-gx0),n-1)
	var j0 := maxi(ceili(c.y-reach-gz0),0)
	var j1 := mini(floori(c.y+reach-gz0),n-1)
	for jj in range(j0,j1+1):
		for ii in range(i0,i1+1):
			var d := Vector2(gx0+ii,gz0+jj)-O
			var s := d.dot(u)
			var v := d.dot(w)
			var off := false
			if s >= F0-2.0:
				var lv := level_at(roundi(v/B),floori((s-F0)/B))
				if lv == 0 and s < F0: lv = level_at(roundi(v/B),0)
				off = lv > 0 and (not tall or hs[jj*n+ii] < LEVEL[lv]+0.6)
			elif s > 10.0 and absf(v) < B*1.5: off = true
			if off:
				var k := jj*n+ii
				rs[k] = minf(rs[k],-1.0)
	got.river = rs

func setup(g: Node3D) -> void:
	game = g
	breaks = TempleBreaks.new()
	add_child(breaks)
	breaks.setup(g)
	var root := frame()
	var draws: Array = []
	for e: Array in layout(game.field):
		if e.size() > 3:
			var left: Array = []
			for l: Array in e[4]: left.append([l[0],root*(l[1] as Transform3D)])
			breaks.add(e[3],e[0],root*(e[1] as Transform3D),left)
		else: draws.append(e)
	site = {"root":root,"draws":draws,"state":"away","task":-1}
	_load_meshes()

## One frame: the site streamed round the eye. `busy`: a temple-kit build is
## running elsewhere (one at a time). Returns whether it is building.
func step(eye: Vector3, busy: bool, here: bool) -> bool:
	var building := false
	if str(site.state) == "building":
		if WorkerThreadPool.is_task_completed(int(site.task)): _commit()
		else: building = true
	if here: breaks.step(eye,not busy and not building)
	var c := at_vs(0.0,KEEP_S)
	var d := Vector2(c.x-eye.x,c.y-eye.z).length() if here else INF
	match str(site.state):
		"away":
			if d < REACH and not busy and not building:
				site.state = "building"
				site.task = WorkerThreadPool.add_task(_make,false,"Sanctuary")
				building = true
		"up":
			if d > FREE: _free()
	return building

## On a worker: the drawing's sets (one per piece and CELL of the site: its
## frames, box and LOD ranges) and each level's boxes and solid. No resource is made here
## (as the agora: the MultiMeshes are made on the main thread).
func _make() -> void:
	var by := {}
	var boxes := {}
	for e: Array in site.draws:
		var id: StringName = e[0]
		var xf: Transform3D = e[1]
		var lv := int(e[2])
		var key := [Vector2i(floori(xf.origin.x/CELL),floori(-xf.origin.z/CELL)),id]
		if not by.has(key): by[key] = []
		(by[key] as Array).append(xf)
		if not boxes.has(lv): boxes[lv] = []
		for box: AABB in TempleKit.boxes(id): (boxes[lv] as Array).append(xf*box)
	var sets: Array = []
	for key: Array in by:
		var id: StringName = key[1]
		var xfs: Array = by[key]
		var piece_box: AABB = _piece_box[id]
		var set_box: AABB = xfs[0]*piece_box
		for xf: Transform3D in xfs: set_box = set_box.merge(xf*piece_box)
		var centre := set_box.get_center()
		var radius := 0.0
		for xf: Transform3D in xfs:
			var b: AABB = xf*piece_box
			for k in 8: radius = maxf(radius,b.get_endpoint(k).distance_to(centre))
		var far_at := FAR_NEAREST+radius
		var mid_at := MID_NEAREST+radius if TempleKit.lod(id,TempleKit.MID) != null else far_at
		sets.append({"id":id,"cell":key[0],"xfs":xfs,"box":set_box,"ranges":[Vector2(0.0,mid_at),Vector2(mid_at,far_at),Vector2(far_at,0.0)]})
	var solids: Array = []
	for lv: int in boxes:
		var list: Array = boxes[lv]
		var reach := 0.0
		for b: AABB in list:
			for corner in [Vector2(b.position.x,b.position.z),Vector2(b.end.x,b.end.z),
					Vector2(b.position.x,b.end.z),Vector2(b.end.x,b.position.z)]:
				reach = maxf(reach,(corner as Vector2).length())
		solids.append({"level":lv,"boxes":list,"reach":reach,"solid":BoxSolid.build(list)})
	site.made = {"sets":sets,"solids":solids}

## Each piece's box over its LODs, its meshes loaded on the main thread (setup).
var _piece_box := {}

func _load_meshes() -> void:
	for e: Array in site.draws:
		var id: StringName = e[0]
		if _piece_box.has(id): continue
		var box := AABB()
		var first := true
		for level in [TempleKit.NEAR,TempleKit.MID,TempleKit.FAR]:
			var m: Mesh = TempleKit.lod(id,level)
			if m == null: continue
			box = m.get_aabb() if first else box.merge(m.get_aabb())
			first = false
		_piece_box[id] = box

## On the main thread: the MultiMeshes, in the tree, the levels' bodies and solids.
func _commit() -> void:
	WorkerThreadPool.wait_for_task_completion(int(site.task))
	site.task = -1
	var made: Dictionary = site.made
	site.erase("made")
	var xf: Transform3D = site.root
	var root := Node3D.new()
	root.name = "SanctuaryDraw"
	for s: Dictionary in made.sets:
		var id: StringName = s.id
		var xfs: Array = s.xfs
		for level in 3:
			var m: Mesh = TempleKit.lod(id,level)
			if m == null: continue
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = m
			mm.instance_count = xfs.size()
			for i in range(xfs.size()): mm.set_instance_transform(i,xfs[i])
			mm.custom_aabb = s.box
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.name = "%s_%s%s" % [id,s.cell,["","_mid","_far"][level]]
			mmi.visibility_range_begin = (s.ranges[level] as Vector2).x
			mmi.visibility_range_end = (s.ranges[level] as Vector2).y
			root.add_child(mmi)
	root.transform = xf
	add_child(root)
	var nodes: Array = [root]
	var records: Array = []
	var yaw := xf.basis.get_euler().y
	for solid: Dictionary in made.solids:
		var list: Array = solid.boxes
		if list.is_empty(): continue
		var body := StaticBody3D.new()
		body.name = "SanctuaryBody%d" % int(solid.level)
		body.collision_layer = game.arches.LAYER
		body.collision_mask = 0
		for box: AABB in list:
			var cs := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = box.size
			cs.shape = shape
			cs.position = box.get_center()
			body.add_child(cs)
		body.transform = xf
		add_child(body)
		nodes.append(body)
		var record := {"name":"sanctuary/%d" % int(solid.level),"kind":"way","node":body,"pos":xf.origin,"cos":cos(yaw),"sin":sin(yaw),
			"solid":solid.solid,"reach":float(solid.reach)+BoxSolid.grow_most()+10.0,"spec":{},"no_break":true}
		records.append(record)
		game.arches.loose.append(record)
	GroundNative.bump_loose()
	site.nodes = nodes
	site.records = records
	site.state = "up"

func _free() -> void:
	for record: Dictionary in site.get("records",[]): game.arches.loose.erase(record)
	GroundNative.bump_loose()
	site.erase("records")
	for node: Node in site.get("nodes",[]):
		if is_instance_valid(node): node.queue_free()
	site.erase("nodes")
	site.state = "away"

func _exit_tree() -> void:
	if site.is_empty(): return
	if int(site.task) >= 0: WorkerThreadPool.wait_for_task_completion(int(site.task))
	site.task = -1
	site.erase("made")
