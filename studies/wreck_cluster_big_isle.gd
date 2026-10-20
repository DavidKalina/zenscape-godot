extends RefCounted
## The big isle (docs/design/big-isle/handoff.md): a greybox destination
## south of the stretch (studies/wreck_cluster_stretch.gd) and south-east of
## the home isle, built in the wreck cluster study unless --no-big-isle.
## KitLand turf on hanging rock keels (studies/wreck_cluster_art.gd
## `hang_rings` / `hang_rock`, as the home isle's), no dressing. +z is
## north, as the cluster has it.
##   mother      the big isle, high and central (turf MOTHER_TOP), its keel
##               stepping in to seven fangs; a landing run along its north
##               side (MOTHER_RUN)
##   crown       a cliff-sided rise on the mother's south half (turf
##               CROWN_TOP), ruins on its rims and a tower at its east end:
##               the landmark; a landing run along its length (CROWN_RUN)
##   summit      a sheer stack on the crown's east end, the tower on it
##   low_islet   the low landing islet out north-west, nearest home (turf
##               LOW_TOP), a long run along it
##   step_a..c   the stepping stones from the low islet up to the mother,
##               joined by rope bridges, each gap opening(STEP_TOY)
##   sat_e, sat_ne, sat_s, sat_far, sat_nw   satellites at other heights,
##               farther out
##   arch_w, arch_e         two islets south-west, opening(ARCH_TOY)
##               apart, a rock lintel across their heads (`arch_lintel`)
##   floater_NN  small free rocks
## Handles: every islet is a world-view island `big_isle/<mass>`, the
## pieces `big_isle/<piece>`, the treasures `big_isle/treasure_NN`.

const WorldScale = preload("res://scripts/world_scale.gd")
const Stretch = preload("res://studies/wreck_cluster_stretch.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")

## The flown openings' toy widths: the gaps in the stepping chain (12 m at
## the defaults) and the arch (14 m).
const STEP_TOY := 6.0
const ARCH_TOY := 7.0

const MOTHER_AT := Vector2(-470.0,-250.0)
const MOTHER_HALF := Vector2(100.0,80.0)
const MOTHER_TOP := 66.0
const CROWN_AT := Vector2(-475.0,-270.0)
const CROWN_HALF := Vector2(75.0,30.0)
## The summit: a sheer stack on the crown's east end, past its run, the
## tower on it.
const SUMMIT_AT := Vector2(-408.0,-266.0)
const SUMMIT_R := 15.0
const SUMMIT_TOP := 158.0
const CROWN_TOP := 106.0
const LOW_HALF := Vector2(74.0,20.0)
const LOW_TOP := 46.0
## The stepping stones from the mother out: [radius, turf, the way out
## from the one before (x, z)]; then the low islet's way out.
const STEPS := [[11.0,61.0,Vector2(-0.45,0.89)],[10.0,56.0,Vector2(-0.6,0.8)],[12.0,51.0,Vector2(-0.85,0.53)]]
const LOW_WAY := Vector2(-0.97,0.25)
## The landing runs' middle lines: [z, x from, x to] (each heads east).
const MOTHER_RUN := [-200.0,-540.0,-410.0]
const CROWN_RUN := [-270.0,-538.0,-438.0]

# --- Outlines --------------------------------------------------------------------

## An organic outline round `at`, half extents `half`, wound east, south,
## west, north (the home isle's stacks' way): its radius rippled by three
## sines (`amp`), their phases shifted by `ph`.
static func organic(at: Vector2, half: Vector2, n: int, ph: float, amp := Vector3(0.07,0.05,0.03)) -> Array:
	var out: Array = []
	for i in n:
		var a := -TAU*float(i)/float(n)
		var k := 1.0+amp.x*sin(3.0*a+0.5+ph)+amp.y*sin(5.0*a+1.3+ph*2.0)+amp.z*sin(9.0*a+ph*3.0)
		out.append(at+Vector2(cos(a)*half.x,sin(a)*half.y)*k)
	return out

## How far `outline` reaches along `d` past `at`.
static func reach(outline: Array, at: Vector2, d: Vector2) -> float:
	var most := -INF
	for p: Vector2 in outline: most = maxf(most,(p-at).dot(d))
	return most

## How far from `at` along `d` the ray out meets `outline`'s rim.
static func rim_along(outline: Array, at: Vector2, d: Vector2) -> float:
	var best := 0.0
	for i in outline.size():
		var hit: Variant = Geometry2D.segment_intersects_segment(at,at+d*1000.0,outline[i],outline[(i+1)%outline.size()])
		if hit != null: best = maxf(best,((hit as Vector2)-at).length())
	return best

static func mother_outline() -> Array:
	return organic(MOTHER_AT,MOTHER_HALF,40,0.0)

static func crown_outline() -> Array:
	return organic(CROWN_AT,CROWN_HALF,32,2.2,Vector3(0.08,0.07,0.04))

static func _stone(at: Vector2, r: float, ph: float) -> Array:
	return organic(at,Vector2(r,r),14,ph,Vector3(0.06,0.05,0.0))

static func _low(at: Vector2) -> Array:
	return organic(at,LOW_HALF,32,1.0,Vector3(0.04,0.03,0.02))

## The stepping chain out from the mother: [[name, outline, top, centre]]
## for step_c, step_b, step_a, low_islet, each set out along its way so
## the gap to the one before is opening(STEP_TOY) at least (their reaches
## along the way apart by that much: no closer anywhere).
static func chain() -> Array:
	var gap := WorldScale.opening(STEP_TOY)
	var out: Array = []
	var prev := mother_outline()
	var at := MOTHER_AT
	var names := ["step_c","step_b","step_a"]
	for i in STEPS.size():
		var row: Array = STEPS[i]
		var d: Vector2 = (row[2] as Vector2).normalized()
		var r: float = row[0]
		var shape := _stone(Vector2.ZERO,r,1.7+i*0.6)
		var c := at+d*(reach(prev,at,d)+gap+reach(shape,Vector2.ZERO,-d))
		var outline := _stone(c,r,1.7+i*0.6)
		out.append([names[i],outline,float(row[1]),c])
		prev = outline
		at = c
	var d := LOW_WAY.normalized()
	var low0 := _low(Vector2.ZERO)
	var lc := at+d*(reach(prev,at,d)+gap+reach(low0,Vector2.ZERO,-d))
	out.append(["low_islet",_low(lc),LOW_TOP,lc])
	return out

static func low_at() -> Vector2:
	return chain()[3][3]

## The arch's two islets: arch_w and arch_e opening(ARCH_TOY) apart along x.
const ARCH_W_AT := Vector2(-618.0,-305.0)
const ARCH_R := 12.0
const ARCH_TOP := 78.0
static func arch_e_at() -> Vector2:
	var w := _stone(ARCH_W_AT,ARCH_R,0.4)
	var e0 := _stone(Vector2.ZERO,ARCH_R,0.9)
	return ARCH_W_AT+Vector2.RIGHT*(reach(w,ARCH_W_AT,Vector2.RIGHT)+WorldScale.opening(ARCH_TOY)+reach(e0,Vector2.ZERO,Vector2.LEFT))

static func _level(y: float) -> Callable:
	return func(_x: float, _z: float) -> float: return y

## The islets as rows of the cluster's lands (studies/wreck_cluster_art.gd
## `lands`: name, outline, ground, depth, seed, cliffs, rim).
static func lands() -> Array:
	var out: Array = [
		["mother",mother_outline(),_level(MOTHER_TOP),110.0,701,Rect2(),MOTHER_TOP],
		["crown",crown_outline(),_level(CROWN_TOP),44.0,703,Rect2(),CROWN_TOP],
		["summit",_stone(SUMMIT_AT,SUMMIT_R,0.3),_level(SUMMIT_TOP),54.0,731,Rect2(),SUMMIT_TOP],
	]
	var seed_value := 705
	for row: Array in chain():
		out.append([row[0],row[1],_level(float(row[2])),70.0 if row[0] == "low_islet" else 55.0,seed_value,Rect2(),float(row[2])])
		seed_value += 2
	out.append(["sat_e",organic(Vector2(-318.0,-232.0),Vector2(22.0,19.0),18,0.8),_level(132.0),75.0,721,Rect2(),132.0])
	out.append(["sat_ne",_stone(Vector2(-362.0,-128.0),11.0,2.6),_level(104.0),50.0,723,Rect2(),104.0])
	out.append(["sat_s",organic(Vector2(-488.0,-392.0),Vector2(18.0,15.0),16,3.1),_level(88.0),65.0,725,Rect2(),88.0])
	out.append(["sat_far",organic(Vector2(-300.0,-380.0),Vector2(26.0,20.0),18,4.0),_level(150.0),85.0,733,Rect2(),150.0])
	out.append(["sat_nw",_stone(Vector2(-600.0,-215.0),9.0,1.1),_level(122.0),45.0,735,Rect2(),122.0])
	out.append(["arch_w",_stone(ARCH_W_AT,ARCH_R,0.4),_level(ARCH_TOP),60.0,727,Rect2(),ARCH_TOP])
	out.append(["arch_e",_stone(arch_e_at(),ARCH_R,0.9),_level(ARCH_TOP),52.0,729,Rect2(),ARCH_TOP])
	return out

## The keels (studies/wreck_cluster_art.gd `hangs`): a cliff band under
## each rim, stepping in through overhangs to a spread of fangs.
const HANGS := {
	"mother":{"rings":[[5.0,0.97],[14.0,0.94],[16.0,0.84],[30.0,0.8],[33.0,0.66],[48.0,0.58],[52.0,0.44],[64.0,0.34]],
		"fangs":[96.0,110.0,84.0,104.0,90.0,116.0,88.0],"spread":0.7,"lean":Vector2(4.0,-3.0)},
	"crown":{"rings":[[4.0,0.97],[14.0,0.94],[16.0,0.86],[30.0,0.82],[32.0,0.74]],"fangs":[44.0,42.0,46.0],"spread":0.5},
	"summit":{"rings":[[4.0,0.97],[18.0,0.94],[20.0,0.86],[40.0,0.82],[42.0,0.74]],"fangs":[54.0]},
	"step_c":{"rings":[[4.0,0.95],[12.0,0.82],[24.0,0.6]],"fangs":[55.0,42.0,48.0],"spread":0.5},
	"step_b":{"rings":[[4.0,0.95],[10.0,0.8],[20.0,0.58]],"fangs":[46.0,36.0],"spread":0.45},
	"step_a":{"rings":[[4.0,0.95],[12.0,0.82],[22.0,0.6]],"fangs":[50.0,40.0,44.0],"spread":0.5},
	"low_islet":{"rings":[[4.0,0.95],[12.0,0.84],[14.0,0.7],[26.0,0.6],[34.0,0.44]],"fangs":[58.0,70.0,50.0,64.0,54.0],"spread":0.62,"lean":Vector2(-3.0,2.0)},
	"sat_e":{"rings":[[5.0,0.95],[16.0,0.85],[18.0,0.7],[34.0,0.56],[46.0,0.4]],"fangs":[75.0,62.0,68.0],"spread":0.5,"lean":Vector2(3.0,-2.0)},
	"sat_ne":{"rings":[[4.0,0.94],[14.0,0.76],[26.0,0.5]],"fangs":[50.0,40.0],"spread":0.4},
	"sat_s":{"rings":[[4.0,0.95],[14.0,0.84],[16.0,0.66],[30.0,0.5]],"fangs":[65.0,52.0,58.0],"spread":0.5,"lean":Vector2(-2.0,-3.0)},
	"sat_far":{"rings":[[5.0,0.95],[18.0,0.86],[20.0,0.7],[38.0,0.56],[52.0,0.4]],"fangs":[85.0,70.0,78.0,64.0],"spread":0.55,"lean":Vector2(4.0,-3.0)},
	"sat_nw":{"rings":[[4.0,0.94],[14.0,0.74],[24.0,0.5]],"fangs":[45.0,36.0],"spread":0.4},
	"arch_w":{"rings":[[4.0,0.96],[20.0,0.86],[34.0,0.6]],"fangs":[60.0,48.0],"spread":0.45},
	"arch_e":{"rings":[[4.0,0.96],[18.0,0.84],[30.0,0.58]],"fangs":[52.0,44.0],"spread":0.45},
}

## Islet `spec` (a row of `lands`) built as the home isle's lands are:
## KitLand turf, its own hanging rock, sides collided as drawn.
static func build_land(spec: Array) -> Node3D:
	var Art: GDScript = load("res://studies/wreck_cluster_art.gd")
	var called := str(spec[0])
	var d := {"outline":spec[1],"seed":int(spec[4]),"ground":spec[2],"top":float(spec[6]),
		"depth":float(spec[3]),"hang":true,"resample":[60.0,128,48],"tone":KitLook.turf(int(spec[4])),"cell":2.0,
		"collide_sides":true,"sides":false,"name":"big_isle/"+called}
	var node := KitLand.island(d)
	node.name = "Land_BigIsle_"+called.to_pascal_case()
	var hang: Dictionary = HANGS[called]
	var rings: Array = Art.hang_rings(d,hang)
	var drawn: MeshInstance3D = Art.hang_rock(rings,hang,int(spec[4])).node("Mesh")
	node.add_child(drawn)
	KitLand.collide_sides(node,drawn,true)
	return node

## The rope bridges up the stepping chain: [a, b] world ends, a metre and a
## half in from each rim along the way between the two middles; low islet
## to step_a to step_b to step_c to the mother.
static func bridges() -> Array:
	var links: Array = []
	var c: Array = chain()
	var tops := {"mother":MOTHER_TOP}
	var ats := {"mother":MOTHER_AT}
	var shapes := {"mother":mother_outline()}
	for row: Array in c:
		tops[row[0]] = float(row[2])
		ats[row[0]] = row[3]
		shapes[row[0]] = row[1]
	for pair: Array in [["low_islet","step_a"],["step_a","step_b"],["step_b","step_c"],["step_c","mother"]]:
		var a: Vector2 = ats[pair[0]]
		var b: Vector2 = ats[pair[1]]
		var d := (b-a).normalized()
		var pa := a+d*(rim_along(shapes[pair[0]],a,d)-3.5)
		var pb := b-d*(rim_along(shapes[pair[1]],b,-d)-3.5)
		links.append([Vector3(pa.x,float(tops[pair[0]]),pa.y),Vector3(pb.x,float(tops[pair[1]]),pb.y)])
	return links

## The pieces: [layout name, node, world foot, yaw (deg)], laid by the
## study's `_place_piece` with the "big_isle/" root: the crown's ruins on
## its rims and east end (off its run), the arch's lintel, the floaters.
static func built() -> Array:
	var c := CROWN_AT
	var e := arch_e_at()
	var span := e.x-ARCH_W_AT.x
	var out: Array = [
		["crown_tower",RuinKit.piece("tower_shell",731,0.35),Vector3(SUMMIT_AT.x,SUMMIT_TOP,SUMMIT_AT.y),90.0],
		["summit_turret",RuinKit.piece("turret",739,0.3),Vector3(SUMMIT_AT.x-6.0,SUMMIT_TOP,SUMMIT_AT.y+5.0),0.0],
		["crown_turret_e",RuinKit.piece("turret",732,0.3),Vector3(c.x+50.0,CROWN_TOP,c.y-22.0),0.0],
		["crown_gable",RuinKit.piece("rose_gable",733,0.35),Vector3(c.x+20.0,CROWN_TOP,c.y+24.0),180.0],
		["crown_arch_w",RuinKit.piece("arch",734,0.4),Vector3(c.x-40.0,CROWN_TOP,c.y+23.0),180.0],
		["crown_pier_s",RuinKit.piece("pier",735,0.4),Vector3(c.x-10.0,CROWN_TOP,c.y-24.0),20.0],
		["crown_turret_w",RuinKit.piece("turret",736,0.4),Vector3(c.x-58.0,CROWN_TOP,c.y-6.0),0.0],
		["mother_arch",RuinKit.piece("arch",737,0.45),Vector3(-548.0,MOTHER_TOP,-240.0),80.0],
		["mother_wall",RuinKit.piece("lancet_wall",738,0.45),Vector3(-395.0,MOTHER_TOP,-250.0),90.0],
		["arch_lintel",Stretch.boulder(741,Vector3(span*0.5+6.0,3.2,6.0),1.0),Vector3((ARCH_W_AT.x+e.x)*0.5,ARCH_TOP+2.4,ARCH_W_AT.y),0.0],
	]
	var floaters := [[-650.0,100.0,-175.0,5.0],[-640.0,58.0,-240.0,3.5],[-380.0,90.0,-330.0,4.5],[-420.0,124.0,-160.0,3.0],
		[-340.0,70.0,-300.0,6.0],[-560.0,120.0,-330.0,4.0],[-520.0,30.0,-120.0,3.0],[-300.0,110.0,-170.0,3.5],[-430.0,52.0,-360.0,4.0]]
	for i in floaters.size():
		var f: Array = floaters[i]
		out.append(["floater_%02d" % (i+1),Stretch.boulder(751+i,Vector3(f[3],f[3]*0.8,f[3]*0.9)),Vector3(f[0],f[1],f[2]),float(i*53%360)])
	return out

## The treasures (scripts/carry/carry_host.gd rows: [id, model, weight,
## foot, yaw]), easy ones low and near the edges, the best high or deep:
##   01 idol (light)     the low islet's west end, by its rim
##   02 urn (medium)     step_b, the stepping chain's middle stone
##   03 urn (medium)     the mother's west rim, by its arch
##   04 egg (heavy)      deep on the mother, under the crown's north cliff
##   05 chalice (light)  the crown's top, at the summit's foot
static func spots() -> Array:
	var c: Array = chain()
	var low: Vector2 = c[3][3]
	var b: Vector2 = c[1][3]
	return [
		["big_isle/treasure_01","idol","light",Vector3(low.x-60.0,LOW_TOP,low.y+6.0),30.0],
		["big_isle/treasure_02","urn","medium",Vector3(b.x,float(c[1][2]),b.y),200.0],
		["big_isle/treasure_03","urn","medium",Vector3(-556.0,MOTHER_TOP,-252.0),120.0],
		["big_isle/treasure_04","egg","heavy",Vector3(-472.0,MOTHER_TOP,-232.0),90.0],
		["big_isle/treasure_05","chalice","light",Vector3(SUMMIT_AT.x-18.0,CROWN_TOP,SUMMIT_AT.y+14.0),0.0],
	]

## The landing turfs for drivers: name -> [z, x from, x to, turf height].
static func turfs() -> Dictionary:
	var low := low_at()
	return {"low_islet":[low.y,low.x-62.0,low.x+62.0,LOW_TOP],
		"mother":[MOTHER_RUN[0],MOTHER_RUN[1],MOTHER_RUN[2],MOTHER_TOP],
		"crown":[CROWN_RUN[0],CROWN_RUN[1],CROWN_RUN[2],CROWN_TOP]}
