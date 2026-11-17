extends "res://scripts/endless/citadel_site.gd"
## The great dome (seed 1, the wilderness): a ruined rotunda on the Peak's
## northern spur at about (-960, -2030), built from the dome's pieces
## (art/blender/temple_kit/dome_build.py) and a few of the kit's and the
## sanctuary's.
##
## - The rotunda: 16 wedges of 22.5 deg turned about its middle (wedge k at
##   yaw PI + k*DT; wedge 0 looks north), each a drum, a dome shell and a
##   floor wedge, its footing stacked down to the ground. Inside radius 47 m,
##   the dome springs at 38 m, the eye (32 m across) at about 82 m.
## - The breach on the north (wedges 14, 15, 0, 1, 2: dome_*_b<k>), where the
##   drum and the dome fell in; heaps and slabs lie inside and out.
## - The door on the south (wedge 8) and the porch before it: the kit's
##   columns and lintels under dome_porch_roof, on sanctuary decks stacked
##   down to the ground, one sanctuary stair flight (or more) down the slope.
##
## Drawn and solid as the citadel is (citadel_site.gd, whose streaming this
## extends): one chunk per wedge in the wedge's own frame (so its boxes stay
## tight), one for the porch, one for the rubble. `--dome=0`: no dome.
##
## To change it: C (the middle), PORCH_ROW / PORCH_SIDE, HEAPS / SLABS.

## The rotunda's middle (XZ).
const C := Vector2(-960.0,-2030.0)
const N := 16
const DT := TAU/16.0
## dome_build.py's numbers.
const RI := 47.0
const RO := 53.0
const FOOT0 := -4.0
const FOOT_H := 12.0
const STAIR_RISE := 13.0
const DECK_T := 3.0
## The breach's wedges (k -> its piece suffix) and the door's.
const BREACH := {14:"m2",15:"m1",0:"0",1:"p1",2:"p2"}
const DOOR_K := 8
## The porch (its frame: +z out of the door, south): the front row of columns
## this far out, the side ones a bay behind it; the decks' rows.
const PORCH_ROW := 87.0
const DECK_Z := [62.5,81.0]
## The front row's middle columns at +-MID_X (not +-B/2): the middle bay
## wider than the door (about 21 m between shafts, 19.6 at the capitals, the
## door 16), so a line through the door clears the porch a few metres off.
const MID_X := 12.5
## Rubble: [angle from north (deg, + toward east), r (m), piece, yaw, inside].
const HEAPS := [[0.0,30.0,&"dome_heap",0.3,true],[-14.0,38.0,&"dome_heap",2.1,true],
	[10.0,66.0,&"dome_heap",1.0,false],[-8.0,72.0,&"dome_heap",-0.7,false],
	[6.0,18.0,&"dome_slab",0.9,true],[-20.0,24.0,&"dome_slab",2.6,true],[18.0,34.0,&"dome_slab",-1.2,true],
	[-2.0,84.0,&"dome_slab",0.2,false]]
const KEEP_HALF_D := Vector2(150.0,170.0)
## Its own distances (not the citadel's, citadel_site.gd reach() etc.): it
## comes in at DOME_REACH, a few pixels in the haze, so it never appears
## whole; the mid stands in to DOME_FAR (the far only where the rotunda is
## small); rubble and the kit's pieces with no mid keep their near to DOME_NOMID.
const DOME_REACH := 8000.0
const DOME_FREE := 8400.0
const DOME_MID := 60.0
const DOME_FAR := 1200.0
const DOME_NOMID := 250.0

func reach() -> float: return DOME_REACH
func free_at() -> float: return DOME_FREE
func mid_nearest() -> float: return DOME_MID
func far_nearest() -> float: return DOME_FAR
func nomid_nearest() -> float: return DOME_NOMID

static func wanted() -> bool:
	return not ("--dome=0" in LaunchArgs.user_args())

static func tree_keepouts(x0: float, z0: float, x1: float, z1: float) -> Array:
	if not wanted(): return []
	if C.x < x0-600.0 or C.x > x1+600.0 or C.y < z0-600.0 or C.y > z1+600.0: return []
	# A touch south of the middle, for the porch and its stair.
	return [[C+Vector2(0.0,20.0),1.0,0.0,KEEP_HALF_D.x,KEEP_HALF_D.y]]

## The floor's top: just over the highest ground under the drum.
static func floor_y(field: Object) -> float:
	var hi := -INF
	for i in range(10):
		var r := RO*i/9.0
		for j in range(32 if i > 0 else 1):
			var a := TAU*j/32.0
			hi = maxf(hi,_h(field,C+Vector2(sin(a),cos(a))*r))
	return hi+0.5

## Wedge k's frame: its middle at the rotunda's, turned so its local +z looks out.
static func wedge_xf(k: int, y: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP,PI+k*DT),Vector3(C.x,y,C.y))

## A world XZ from the rotunda's: `deg` from north toward the east, `r` out.
static func polar(deg: float, r: float) -> Vector2:
	var a := deg_to_rad(deg)
	return C+Vector2(sin(a),-cos(a))*r

func _lay(field: Object) -> void:
	var fy := floor_y(field)
	for k in range(N):
		var xf := wedge_xf(k,fy)
		var c := _chunk("dome/wedge%d" % k,xf)
		var drum: StringName = &"dome_drum"
		var shell: StringName = &"dome_shell"
		var flr: StringName = &"dome_floor"
		if BREACH.has(k):
			drum = StringName("dome_drum_b"+str(BREACH[k]))
			shell = StringName("dome_shell_b"+str(BREACH[k]))
			# The same stones, their sky baked with the breach open.
			flr = StringName("dome_floor_b"+str(BREACH[k]))
		elif k == DOOR_K:
			drum = &"dome_drum_door"
		_put(c,drum,xf)
		_put(c,shell,xf)
		_put(c,flr,xf)
		# The footing down to the lowest ground under the wedge's outer arc.
		var a := PI+k*DT
		var lo := INF
		for j in range(7):
			var u := a+DT*(j/6.0-0.5)
			lo = minf(lo,_h(field,C+Vector2(sin(u),cos(u))*(RO+0.6)))
		var top := fy+FOOT0
		var n := 0
		while top > lo-0.5 and n < 8:
			_put(c,&"dome_footing",Transform3D(xf.basis,Vector3(C.x,top,C.y)))
			top -= FOOT_H
			n += 1
	_lay_porch(field,fy)
	var rub := _chunk("dome/rubble",Transform3D(Basis(),Vector3(C.x,fy,C.y)-Vector3(0.0,0.0,40.0)))
	for e: Array in HEAPS:
		var p := polar(float(e[0]),float(e[1]))
		var y: float = fy if bool(e[4]) else _low(field,p,Vector2.RIGHT,8.0,8.0)-0.4
		_put(rub,e[2],Transform3D(Basis(Vector3.UP,float(e[3])),Vector3(p.x,y,p.y)))

## The porch before the door (south, world +z): columns, lintels, roof, decks, stair.
func _lay_porch(field: Object, fy: float) -> void:
	var o := Vector3(C.x,fy,C.y)
	var pc := _chunk("dome/porch",Transform3D(Basis(),o+Vector3(0.0,0.0,75.0)))
	_put(pc,&"dome_porch_roof",Transform3D(Basis(),o))
	var along := Basis()
	var across := Basis(Vector3.UP,-PI*0.5)
	for x: float in [-1.5*B,-MID_X,MID_X,1.5*B]:
		_put(pc,&"column",Transform3D(Basis(),o+Vector3(x,0.0,PORCH_ROW)))
	for x: float in [-1.5*B,1.5*B]:
		_put(pc,&"column",Transform3D(Basis(),o+Vector3(x,0.0,PORCH_ROW-B)))
	# The lintels from column to column, stretched to the bays' own widths.
	var xs := [-1.5*B,-MID_X,MID_X,1.5*B]
	for i in range(3):
		var x0: float = xs[i]
		var x1: float = xs[i+1]
		_put(pc,&"lintel",Transform3D(along*Basis.from_scale(Vector3((x1-x0)/B,1.0,1.0)),o+Vector3((x0+x1)*0.5,0.0,PORCH_ROW)))
	# The sides: one bay from the front row back to the side column, then on to the drum's face.
	var face := sqrt(RO*RO-pow(1.5*B,2.0))
	for x: float in [-1.5*B,1.5*B]:
		_put(pc,&"lintel",Transform3D(across,o+Vector3(x,0.0,PORCH_ROW-B*0.5)))
		var z0 := face-1.0
		var z1 := PORCH_ROW-B
		_put(pc,&"lintel",Transform3D(across*Basis.from_scale(Vector3((z1-z0)/B,1.0,1.0)),o+Vector3(x,0.0,(z0+z1)*0.5)))
	# The decks, each stacked down to the ground under it.
	for z: float in DECK_Z:
		for x: float in [-1.5*B,-0.5*B,0.5*B,1.5*B]:
			var p := Vector2(C.x+x,C.y+z)
			var lo := _low(field,p,Vector2.RIGHT,B*0.5,B*0.5)
			var top := fy
			var n := 0
			while top > lo-0.5 and n < 12:
				_put(pc,&"sanctuary_deck",Transform3D(Basis(),Vector3(p.x,top,p.y)))
				top -= DECK_T
				n += 1
	# The stair down the slope from the porch's front edge, a flight a bay, rising north.
	var edge := DECK_Z[1]+B*0.5
	var y := fy
	for i in range(4):
		var p := Vector2(C.x,C.y+edge+B*(i+0.5))
		var foot := y-STAIR_RISE
		_put(pc,&"sanctuary_stair",Transform3D(Basis(),Vector3(p.x,foot,p.y)))
		y = foot
		if _low(field,p+Vector2(0.0,B*0.5),Vector2.RIGHT,B*0.5,2.0) > foot-2.0: break
