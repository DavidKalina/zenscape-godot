extends RefCounted
## The storm front's cloud deck on the CPU: the mirror of shaders/
## storm_cloud.glslinc (the shelf, the core, the ragged back; keep the
## numbers equal), so EndlessClouds' `cloud_depth` / `in_cloud` agree with
## the march. `storm` is the study's StormFront (scripts/endless/
## storm_front.gd); `salt` the clouds' seed salt.

const EndlessClouds = preload("res://scripts/endless/endless_clouds.gd")
const Field = preload("res://scripts/endless/land_field.gd")

const LIP := 280.0
const LIP_WAVE := 150.0
const LIP_SCALE := 1500.0
const SHELF_BASE := 190.0
const CORE_BASE := 240.0
const BASE_BACK := 900.0
const FACE := 0.55
const SHELF_TOP := 450.0
const CORE_RISE := Vector2(250.0,1300.0)
const CORE_TOP := 1850.0
const TOP_WAVE := 320.0
const TOP_SCALE := 1300.0
const CLEAR := 1000.0
const TAPER := 1000.0
const END := 3000.0
const PAST := 1500.0
const CELL := 2300.0
const CELL_RISE := 700.0
const BREAK := 480.0
const SALT := 401

static func _sstep(a: float, b: float, x: float) -> float:
	var t := clampf((x-a)/(b-a),0.0,1.0)
	return t*t*(3.0-2.0*t)

## The march's `value_noise`.
static func _noise(g: Vector2, s: int) -> float:
	var i := Vector2i(floori(g.x),floori(g.y))
	var u := g-Vector2(i)
	u = u*u*(Vector2(3.0,3.0)-2.0*u)
	var a := EndlessClouds.hash3(i.x,i.y,s).x
	var b := EndlessClouds.hash3(i.x+1,i.y,s).x
	var c := EndlessClouds.hash3(i.x,i.y+1,s).x
	var d := EndlessClouds.hash3(i.x+1,i.y+1,s).x
	return lerpf(lerpf(a,b,u.x),lerpf(c,d,u.x),u.y)

## (top, base) over the sea of the deck at world `xz`; where it has none,
## top < base (base - top a lower bound on the distance to it).
static func deck(storm: RefCounted, xz: Vector2, salt: int) -> Vector2:
	var d: float = storm.edge_distance(xz)
	var along: float = storm.along(xz)
	var half: float = storm.length*0.5
	var core: float = storm.CORE_DEPTH
	var s := salt+SALT
	var lip := LIP+LIP_WAVE*(2.0*_noise(Vector2(along/LIP_SCALE,0.5),s)-1.0) \
		+0.4*LIP_WAVE*(2.0*_noise(Vector2(along/(LIP_SCALE*0.29),3.5),s+1)-1.0)
	var u := lip-d
	if u < 0.0: return Vector2(SHELF_BASE+0.7*u,SHELF_BASE)
	var q := Vector2(along,d)
	var e := _sstep(half+PAST,half+PAST-END,absf(along)+900.0*(_noise(q/900.0,s+4)-0.5))
	var keep := _sstep(-core-CLEAR-300.0,-core+100.0,d)
	var m := 0.15+keep+0.7*(_noise(q/BREAK,s+5)-0.5)+0.25*(_noise(q/(BREAK*0.37),s+6)-0.5)
	if m < 0.5 or e < 0.15:
		var gap := maxf((0.5-m)*260.0 if m < 0.5 else 0.0,(0.15-e)*END*0.3 if e < 0.15 else 0.0)
		gap = maxf(gap,-(d+core+CLEAR+600.0))
		return Vector2(CORE_BASE-maxf(gap,10.0),CORE_BASE)
	var body := _sstep(0.5,0.85,m)*_sstep(0.15,0.4,e)
	var n_top := _noise(q/TOP_SCALE,s+2)
	var n_low := _noise(q/600.0,s+3)
	var base := lerpf(SHELF_BASE,CORE_BASE,_sstep(0.0,BASE_BACK,u))+40.0*(n_low-0.5)+90.0*(1.0-keep)
	var shelf := minf(base+25.0+u*FACE,SHELF_TOP+70.0*(n_low-0.5))
	var rise := _sstep(CORE_RISE.x,CORE_RISE.y,u+500.0*(n_top-0.5))
	var cells := _noise(Vector2(along/CELL,7.5),s+8)
	var roof := CORE_TOP+CELL_RISE*(cells-0.45)+TOP_WAVE*(2.0*n_top-1.0)+180.0*(_noise(q/760.0,s+7)-0.5)
	var top := maxf(shelf,lerpf(base,roof,rise))
	top = base+(top-base)*body*lerpf(0.3,1.0,keep)*lerpf(0.25,1.0,_sstep(0.15,1.0,e))
	return Vector2(maxf(top,base+12.0),base)

## How far world point `p` is into the deck (m, up to its top or down to
## its base, the base lifted to `clear_y` as the march lifts it), negative
## outside.
static func depth(storm: RefCounted, p: Vector3, salt: int, clear_y: float) -> float:
	var k := deck(storm,Vector2(p.x,p.z),salt)
	if k.x < k.y: return -1e9
	var base := maxf(Field.SEA_Y+k.y,clear_y)
	var top := maxf(Field.SEA_Y+k.x,base+12.0)
	return minf(top-p.y,p.y-base)
