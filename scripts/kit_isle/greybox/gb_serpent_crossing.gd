extends "res://scripts/kit_isle/motif_greybox.gd"
## The Serpent Crossing (card: docs/design/roguelike/brainstorm/round3-olmec-
## city/motif-serpent-crossing.md), a place of the underground Olmec city: a
## wide void with no bridge between a low arrival isle and a high far one.
## The rune serpent still runs its line across it (the city's train,
## docs/design/roguelike/city-serpent-round1.md); the slow way is the city's
## climb pieces with a whole Olmec in his lanes.
##
##   A  the arrival isle (0 m): KitLand turf, west terraces, a tongue of land
##      north under the wedged chunk. On its east cliff the waiting dais
##      (kukul_dais) juts out over the void; the line runs up its trough.
##   K  the ash court (-9.6 m) under the dais: the ash bowl (colossus_
##      ashbowl) catches a missed boarding; giant steps climb back to A.
##   R  the ring's pillar (0 m) alone in the void, the threading ring
##      (kukul_ring) over it, an alighting stage beside the line: reached
##      only off the serpent's back, left only by dropping onto it again.
##   the coil  (kukul_coil) out of the haze in the north, its cap (37 m) the
##      top of the ride.
##   F  the far isle (32 m): turf, its east cliff worn concave by the line,
##      an alighting ledge along it: the saddle passes a step over it.
##   B, the pit, the wrap  the slow way: the wedged chunk (city_wedge) up
##      A's tongue to pillar B (9.6 m), the leaper's pit (city_pit) to the
##      wrapped pillar (city_wrap), its ramp up to F's south edge.
##
## Routes (rim in on A's south edge, rim out on F's north edge):
##   the ride   wait on the dais; board at a run off its lip; ride through
##              the ring, round and up the coil; jump off onto F's ledge as
##              it passes (stay on: shrugged onto the cap; walk down the ramp
##              and board the next lap).
##   the slow   the wedge (slab or chimney), B, the pit's cornice, the wrap's
##   way        ramp or recess, F. The whole Olmec keeps this side.
## The serpent is the ride (serpent_crossing_line.gd steps it); the Olmec is
## lured by the unlit great cresset on A's west terrace.
const OlmecPlaces = preload("res://scripts/enemies/olmec_places.gd")
const CityKit = preload("res://scripts/city_kit.gd")
const CityStone = preload("res://scripts/city_kit_stone.gd")
const CityFires = preload("res://scripts/city_kit_fires.gd")
const CS = preload("res://scripts/city_kit_serpent.gd")
const SC = preload("res://scripts/kit_isle/greybox/gb_stacked_court.gd")
const GiantStone = preload("res://scripts/kit_isle/greybox/giant_stone.gd")
const Breakables = preload("res://scripts/kit_isle/breakables.gd")
const HeadlessBody = preload("res://scripts/enemies/headless_body.gd")
const InhalerHead = preload("res://scripts/enemies/inhaler_head.gd")
const KitLife = preload("res://scripts/kit_isle/kit_life.gd")
const Underground = preload("res://scripts/underground/underground.gd")
const Line = preload("res://scripts/kit_isle/greybox/serpent_crossing_line.gd")

const COURSE := CityKit.COURSE
const SO := CityKit.SET_OFF
const SEED := 7600

# --- The layout: one table ----------------------------------------------------------------
## The frame: A's middle at x z 0, its ground 0; north -z. Points (x, y, z) m.
const LAYOUT := {
	"floor":-70.0,
	# A: its outline (x, z), its west terraces (edge x, a set-off up west of
	# each; only south of z -18), its keel.
	"arrival":{"outline":[Vector2(-6.0,26.0),Vector2(10.0,26.0),Vector2(24.0,25.0),Vector2(35.5,24.0),Vector2(35.5,20.2),Vector2(28.0,19.8),
		Vector2(25.5,12.0),Vector2(25.0,0.0),Vector2(25.0,-10.0),Vector2(19.0,-17.0),Vector2(10.0,-20.0),Vector2(9.0,-34.0),Vector2(8.0,-50.0),
		Vector2(5.0,-61.0),Vector2(-10.0,-62.0),Vector2(-18.0,-55.0),Vector2(-19.0,-36.0),Vector2(-24.0,-24.0),Vector2(-32.0,-17.0),
		Vector2(-37.0,-4.0),Vector2(-35.0,10.0),Vector2(-27.0,20.0),Vector2(-17.0,25.0)],
		"terraces":[-19.0,-27.0],"depth":26.0,"seed":SEED+1,
		# Fallen drums (offset, radius, length, turn deg): cover on the way.
		"drums":[[Vector2(15.5,-12.5),1.7,5.0,55.0],[Vector2(-25.0,-11.0),1.5,4.2,-40.0],[Vector2(19.0,18.0),1.9,3.4,70.0]],
		# The north-east shoulder (polish): A's ground falls away toward the
		# ring in two broken set-offs (a set-off down past each edge line:
		# x over `x`, z under `z`, both wandering).
		"falls":[[10.5,-6.0],[16.0,-11.5]]},
	# The dais (its middle; its trough on its east, the line up it).
	"dais":Vector3(30.0,0.0,-2.0),
	# The ash court: its middle (floor), half its side, the ash's radius.
	"ash":{"at":Vector3(44.0,-9.6,-3.0),"half":13.0,"radius":8.0},
	# Giant steps from the court's south edge up to A (x span, first z, count).
	"steps":{"x":Vector2(31.0,35.0),"z":10.0,"n":5},
	# The ring over R: its z, its bore's height; R's crown and apothem; the
	# alighting stage's tiers (x, z rect, top over R's crown).
	# Polish: R's crown sunk four set-offs (it was A's level, a shelf in line
	# with A from the rim): the ring stands up out of the gulf on long
	# stepped abutments (their courses a set-off each, down to R's crown,
	# R a little wider to keep their feet). The stage keeps its tops (over
	# `stage_at`, the old crown): a pier, its low tier run north to the
	# west abutment's side (a set-off under its course there).
	"ring":{"z":-58.0,"y":5.0,"crown":-4.0*SO,"apothem":17.5,"stage_at":0.0,
		"stage":[[Rect2(28.8,-56.1,6.8,12.1),SO],[Rect2(30.6,-52.0,5.0,7.0),2.0*SO]]},
	# The coil: its axis (x, z), its ramp's foot height, turns, a turn's
	# rise, the foot's angle (deg from +x toward -z).
	"coil":{"at":Vector2(38.5,-168.0),"y":7.5,"turns":2.0,"rise":14.4,"foot":280.0,
		# Polish: a wick spire on the cap's lower tier (deg, radius off the
		# axis, tall), clear of the stela, the shrug's sector (south-east)
		# and the serpent's face (north-east); a crown lamp on the cap (deg);
		# lamps on the ramp's inner edge every `every` deg of it from `from`.
		"spire":[160.0,4.0,18.0],"lamps":[230.0],"ramp_lamps":{"from":340.0,"every":120.0,"r":8.2}},
	# How far the polish's lamps read (CityFires `beam`).
	"beam":2.2,
	# Polish: rune strips held dimly lit, by piece.
	"glow":{"coil":0.45,"ring":0.3},
	# The slow way: the wedge's origin, B (x, z, crown, apothem), the pit's
	# origin, the wrap's origin (its foot's ground) and depth.
	"wedge":Vector3(-0.5,0.0,-51.8),
	"pillar_b":{"at":Vector2(-5.0,-70.8),"crown":9.6,"apothem":10.0,"cap":{"grow":3.0,"keep":[3],"seed":SEED+11}},
	"pit":Vector3(-5.0,9.6,-94.3),
	"wrap":{"at":Vector3(7.78,9.6,-126.8),"deep":50.0},
	# F: its crown, its outline before the line's wear, its terraces (z edge,
	# west of x), its keel; the worn cliff kept this far (m) off the coil's
	# axis; the alighting ledge on the arc (deg), radii, top over F's crown.
	"far":{"crown":32.0,"outline":[Vector2(-12.0,-146.4),Vector2(4.0,-146.4),Vector2(16.0,-147.0),Vector2(26.0,-149.0),Vector2(22.0,-160.0),
		Vector2(18.0,-170.0),Vector2(22.0,-182.0),Vector2(16.0,-192.0),Vector2(4.0,-200.0),Vector2(-12.0,-203.0),Vector2(-26.0,-198.0),
		Vector2(-35.0,-186.0),Vector2(-36.0,-168.0),Vector2(-28.0,-152.0)],
		"terraces":[[-180.0,8.0],[-190.0,-6.0],[-162.0,-19.0],[-170.0,-24.0]],"depth":34.0,"keep":24.6,"ledge":[150.0,216.0],"ledge_r":Vector2(21.7,25.4),"seed":SEED+2,
		# Polish: the beacon tower on the west hill, lamps on the south lip.
		"tower":Vector3(-29.0,0.0,-184.0),"lamps":[Vector2(-12.5,-149.8),Vector2(3.5,-149.6)]},
	# The whole Olmec's beat on B (x, z), his first look.
	"keeper":{"beat":[Vector2(-5.0,-64.0),Vector2(-5.0,-71.0),Vector2(-5.0,-79.0)],"face":Vector2(0.0,1.0)},
	# The great cresset on A's west terrace (unlit: lit, it calls him).
	# Polish: nearer the rim, left of the path (it stood mid-view).
	"lure":Vector3(-14.0,0.0,16.0),
	# Alone (the yard): far pillars in the haze [x, z, crown (courses), apothem].
	"far_pillars":[[-260.0,-200.0,4,30.0],[200.0,-330.0,12,26.0],[260.0,40.0,-1,34.0],[-300.0,120.0,1,38.0],[60.0,-480.0,16,32.0],[-200.0,-430.0,10,28.0],[150.0,230.0,-2,30.0]],
}

# --- Solved from the table -------------------------------------------------------------------

## The dais's line (x, y) in the frame: up its trough's middle.
static func line_x() -> float:
	return (LAYOUT.dais as Vector3).x+CS.CELL*1.5+CS.Kit.trough_width(1.0)*0.5

static func line_y() -> float:
	return (LAYOUT.dais as Vector3).y+CS.set_off()+CS.SADDLE_OVER-CS.saddle_top(1.0)

static func ring_at() -> Vector3:
	return Vector3(line_x(),float(LAYOUT.ring.y),float(LAYOUT.ring.z))

static func coil_at() -> Vector3:
	var c: Dictionary = LAYOUT.coil
	return Vector3(c.at.x,float(c.y),c.at.y)

## The coil's line radius, its depth under the ramp (CS Coil `build`'s).
static func coil_line_r() -> float:
	return 7.5+CS.CELL*2.0+CS.Kit.radius(1.0)*CS.FLANK_SHARE+1.35

static func coil_line_under() -> float:
	return CS.saddle_top(1.0)-CS.SADDLE_OVER

static func coil_top() -> float:
	return float(LAYOUT.coil.y)+float(LAYOUT.coil.rise)*float(LAYOUT.coil.turns)

## The ramp's height (frame) at `phi` (deg, unwrapped from the coil's 0).
static func coil_ramp(phi: float) -> float:
	var c: Dictionary = LAYOUT.coil
	var a := deg_to_rad(phi-float(c.foot))
	return float(c.y)+clampf(float(c.rise)*a/TAU,0.0,float(c.rise)*float(c.turns))

static func b_at() -> Vector3:
	var b: Dictionary = LAYOUT.pillar_b
	return Vector3(b.at.x,float(b.crown),b.at.y)

## A's ground (frame x, z): 0, a set-off up west of each terrace edge
## (wandering), south of the tongue.
static func arrival_ground(x: float, z: float) -> float:
	var y := 0.0
	var j := 0
	for f: Array in LAYOUT.arrival.falls:
		var wx := 1.6*sin(z*0.21+j*2.3)+0.8*sin(z*0.47+1.1)
		var wz := 1.4*sin(x*0.19+j*1.7)+0.7*sin(x*0.43+0.6)
		if x > float(f[0])+wx and z < float(f[1])+wz: y -= SO
		j += 1
	if z < -17.0: return y
	var k := 0
	for edge: float in LAYOUT.arrival.terraces:
		var wander := 2.0*sin(z*0.13+k*1.9)+1.2*sin(z*0.31+0.4+k)
		if x < edge+wander: y += SO
		k += 1
	return y

## F's ground: its crown, a set-off up north of each terrace edge (west of
## its x), wandering.
static func far_ground(x: float, z: float) -> float:
	var y := float(LAYOUT.far.crown)
	var k := 0
	for t: Array in LAYOUT.far.terraces:
		var wander := 2.2*sin(x*0.12+k*1.3)+1.1*sin(x*0.29+0.8+k)
		if z < float(t[0])+wander and x < float(t[1])+1.5*sin(z*0.2+k): y += SO
		k += 1
	return y

## F's outline with its east cliff worn back to `keep` m off the coil's
## axis, the arc between drawn round it (so the line never meets it).
static func far_outline() -> Array:
	var c: Vector2 = LAYOUT.coil.at
	var keep := float(LAYOUT.far.keep)
	var out: Array = []
	var src: Array = LAYOUT.far.outline
	for i in src.size():
		var p: Vector2 = src[i]
		var q: Vector2 = src[(i+1)%src.size()]
		var n := int(ceil(p.distance_to(q)/3.0))
		for k in n:
			var s := p.lerp(q,float(k)/float(n))
			var d := s-c
			if d.length() < keep: s = c+d.normalized()*keep
			out.append(s)
	return out

## Where his feet go round the arc of the ledge (deg) at radius r (frame).
static func coil_point(deg: float, r: float, y: float) -> Vector3:
	var c := coil_at()
	return Vector3(c.x+cos(deg_to_rad(deg))*r,y,c.z-sin(deg_to_rad(deg))*r)

## The serpent's line (frame): [control points, marks]. South up the dais's
## trough, through the ring, north-east to the coil's east point, coupled
## to its ramp two turns up, a sixth past the cap, away north-east and home
## in a long loop over the void to the east.
static func line() -> Array:
	var cps: Array = []
	var marks := {}
	var lx := line_x()
	var ly := line_y()
	var dz := (LAYOUT.dais as Vector3).z
	var add := func(p: Vector3, weave := 0.0) -> void: cps.append([p,weave,1.0,0.0])
	marks["approach"] = cps.size()
	for z: float in [62.0,50.0,38.0,26.0]: add.call(Vector3(lx,ly,dz+z))
	for z: float in [6.6,0.0,-6.6]:
		if z == 0.0: marks["station"] = cps.size()
		add.call(Vector3(lx,ly,dz+z))
	add.call(Vector3(lx,ly+0.4,dz-14.0))
	var r := ring_at()
	var outer := CS.bore(1.0)+1.4
	add.call(Vector3(lx,r.y-0.6,r.z+outer+9.0))
	marks["ring"] = cps.size()
	for z: float in [outer,0.0,-outer]: add.call(Vector3(lx,r.y,r.z+z))
	# On north-east to the coil's east point (phi 0), level with the ramp
	# there (its line coupled from the first point).
	var every := 30.0
	var shrink := (4.0+2.0*cos(deg_to_rad(every)))/6.0
	var c := coil_at()
	var lr := coil_line_r()/shrink
	var first := 360.0
	var arrive := Vector3(c.x+lr,coil_ramp(first)-coil_line_under(),c.z)
	var from := Vector3(lx,r.y,r.z-outer)
	marks["coil"] = cps.size()
	var legs := 7
	for k in range(1,legs+1):
		var t := float(k)/float(legs+1)
		var ease := t*t*(3.0-2.0*t)
		add.call(Vector3(lerpf(from.x,arrive.x,ease),lerpf(from.y,arrive.y,t),lerpf(from.z,arrive.z,t)))
	var end_phi := float(LAYOUT.coil.foot)+360.0*float(LAYOUT.coil.turns)
	var over := 60.0
	var phi := first
	marks["couple"] = cps.size()
	while phi <= end_phi+over+0.01:
		if absf(phi-end_phi) < every*0.5: marks["top"] = cps.size()
		if absf(phi-(end_phi+over*0.5)) < every*0.5: marks["shrug"] = cps.size()
		var y := coil_ramp(minf(phi,end_phi))-coil_line_under()
		add.call(Vector3(c.x+cos(deg_to_rad(phi))*lr,y,c.z-sin(deg_to_rad(phi))*lr))
		phi += every
	marks["leave"] = cps.size()
	var last := deg_to_rad(phi-every)
	var tangent := Vector3(-sin(last),0.0,-cos(last))
	var tail: Vector3 = cps[cps.size()-1][0]
	for k in 2: add.call(tail+tangent*14.0*(k+1)-Vector3(0.0,0.5*(k+1),0.0),0.1)
	marks["loop"] = cps.size()
	var top := coil_top()
	for p: Vector3 in [Vector3(84.0,top-2.0,-206.0),Vector3(112.0,top-5.0,-208.0),Vector3(136.0,top-9.0,-180.0),Vector3(148.0,top-14.0,-130.0),
			Vector3(150.0,top-19.0,-75.0),Vector3(142.0,top-25.0,-20.0),Vector3(128.0,4.0,32.0),Vector3(108.0,1.5,70.0),Vector3(84.0,0.0,90.0),
			Vector3(62.0,-0.8,94.0),Vector3(48.0,ly,86.0),Vector3(lx+0.3,ly,dz+74.0)]:
		add.call(p,0.5 if p.x > 70.0 else 0.15)
	return [cps,marks]

# --- The motif's face ----------------------------------------------------------------------

func slug() -> String:
	return "serpent_crossing"

func role() -> String:
	return "hero"

func isle_name() -> String:
	return "The Serpent Crossing"

func epithet() -> String:
	return "It still keeps its timetable. Nobody has waited for it in a thousand years."

func brief() -> String:
	return "Wait on the dais and board the serpent at a run; ride it up the coil and jump off at the far isle's ledge.\nOr the slow way: the wedge, the pit, the wrapped pillar, past the Olmec."

func start() -> Vector3:
	return Vector3(-4.0,0.0,20.0)

## In on A's south edge; out on F's north edge.
func rims() -> Array:
	return [
		{"name":"arrival","at":Vector3(-4.0,0.0,24.0),"face":Vector3(0.0,0.0,1.0),"run_up":14.0,"lip":1.2},
		{"name":"far_isle","at":Vector3(-12.0,far_ground(-12.0,-200.0),-200.0),"face":Vector3(0.0,0.0,-1.0),"run_up":12.0,"lip":1.2},
	]

func spots() -> Array:
	var lx := line_x()
	var r := ring_at()
	var b := b_at()
	var d: Vector3 = LAYOUT.dais
	var p: Vector3 = LAYOUT.pit
	var w: Dictionary = LAYOUT.wrap
	var wa: Vector3 = w.at
	var c := coil_at()
	var fc := float(LAYOUT.far.crown)
	return [
		{"kind":"arena","name":"arrival_terrace","at":Vector3(-22.0,SO,0.0),"room":10.0},
		{"kind":"arena","name":"pillar_b","at":b,"room":6.0},
		{"kind":"cover","name":"dais_shrine","at":d+Vector3(-4.0,SO,0.0),"room":2.0},
		{"kind":"cover","name":"wrap_cell","at":wa+Vector3(0.0,8.0,1.8),"room":1.5},
		{"kind":"perch","name":"ring_cap","at":r+Vector3(0.0,9.6,0.0),"room":1.2},
		{"kind":"perch","name":"coil_cap","at":c+Vector3(0.0,coil_top()-c.y+0.8,0.0),"room":4.0},
		{"kind":"perch","name":"far_summit","at":Vector3(-20.0,far_ground(-20.0,-196.0),-196.0),"room":4.0},
		# Runes along the ways and just off them.
		{"kind":"rune_line","name":"tongue","at":Vector3(0.0,0.0,-14.0),"room":1.0},
		{"kind":"rune_line","name":"wedge_slab","at":(LAYOUT.wedge as Vector3)+Vector3(2.0,4.8,16.0),"room":1.0},
		{"kind":"rune_line","name":"wedge_crown","at":(LAYOUT.wedge as Vector3)+Vector3(-4.5,9.6,-4.4),"room":1.0},
		{"kind":"rune_line","name":"b_crown","at":b+Vector3(3.0,0.0,-4.0),"room":1.0},
		{"kind":"rune_line","name":"pit_south","at":p+Vector3(0.0,0.0,9.0),"room":1.0},
		{"kind":"rune_line","name":"pit_north","at":p+Vector3(0.0,0.0,-9.0),"room":1.0},
		{"kind":"rune_line","name":"wrap_ramp_e","at":wa+Vector3(12.78,4.8,0.0),"room":1.0},
		{"kind":"rune_line","name":"wrap_ramp_w","at":wa+Vector3(-12.78,11.2,0.0),"room":1.0},
		{"kind":"rune_line","name":"wrap_ramp_n","at":wa+Vector3(0.0,20.8,-12.78),"room":1.0},
		{"kind":"rune_line","name":"dais_top","at":d+Vector3(1.6,SO,0.0),"room":1.0},
		{"kind":"rune_line","name":"far_landing","at":Vector3(-4.0,fc,-152.0),"room":1.0},
		# Tempting detours that expose you.
		{"kind":"rune_risk","name":"arrival_east_lip","at":Vector3(34.5,0.0,22.0),"room":0.8},
		{"kind":"rune_risk","name":"pit_cornice","at":p+Vector3(-3.95,-1.6,0.0),"room":0.6},
		{"kind":"rune_risk","name":"wrap_ne_corner","at":wa+Vector3(16.5,16.0,-16.5),"room":1.0},
		{"kind":"rune_risk","name":"far_ledge","at":coil_point(182.0,24.0,fc),"room":0.8},
		{"kind":"rune_risk","name":"ash_stele","at":(LAYOUT.ash.at as Vector3)+Vector3(0.0,-1.2,0.0),"room":1.0},
		# Hidden and hard.
		{"kind":"rare","name":"coil_cap_stela","at":c+Vector3(0.0,coil_top()-c.y+0.8,0.0),"room":1.0},
		{"kind":"rare","name":"ring_cap","at":r+Vector3(0.0,9.6,0.0),"room":0.8},
		{"kind":"rare","name":"ring_isle","at":Vector3(lx-9.0,float(LAYOUT.ring.crown),r.z-6.0),"room":1.0},
		{"kind":"rare","name":"wrap_cell","at":wa+Vector3(0.0,8.0,1.8),"room":0.8},
	]

## Solids for the occupancy and the bodies' cliffs (never the build).
func parts() -> Array:
	var out: Array = []
	var floor_y := float(LAYOUT.floor)
	var box := func(r: Rect2, lo: float, hi: float) -> void: out.append(["box",r,lo,hi,"grey"])
	# A (its main and its tongue) and its terraces.
	box.call(Rect2(-35.0,-17.0,70.0,42.0),-float(LAYOUT.arrival.depth),0.0)
	box.call(Rect2(-36.0,-14.0,10.0,30.0),-float(LAYOUT.arrival.depth),2.0*SO)
	box.call(Rect2(-17.0,-60.0,25.0,43.0),-float(LAYOUT.arrival.depth),0.0)
	# The wedge on the tongue.
	var wd: Vector3 = LAYOUT.wedge
	box.call(Rect2(wd.x-14.0,wd.z-8.6,22.0,8.6),0.0,9.6)
	out.append(["ramp",wd+Vector3(0.0,0.0,30.8),wd+Vector3(0.0,9.6,0.0),8.8,"grey"])
	# The dais, its footing, the ash court and its steps.
	var d: Vector3 = LAYOUT.dais
	box.call(Rect2(d.x-9.0,d.z-6.6,23.0,13.2),d.y-9.6,d.y+SO)
	var a: Dictionary = LAYOUT.ash
	var ac: Vector3 = a.at
	var h := float(a.half)
	box.call(Rect2(ac.x-h,ac.z-h,h*2.0,h*2.0),floor_y,ac.y)
	var st: Dictionary = LAYOUT.steps
	box.call(Rect2(st.x.x,float(st.z),st.x.y-st.x.x,2.0*int(st.n)),ac.y-4.0,-SO)
	# R and the ring.
	var r := ring_at()
	SC._hex_strips(out,Vector2(r.x,r.z),float(LAYOUT.ring.apothem)+CityKit.LEDGE,floor_y,float(LAYOUT.ring.crown)-COURSE,0.0)
	SC._hex_strips(out,Vector2(r.x,r.z),float(LAYOUT.ring.apothem),floor_y,float(LAYOUT.ring.crown),0.0)
	box.call(Rect2(r.x-15.0,r.z-1.2,30.0,2.4),float(LAYOUT.ring.crown),r.y+9.6)
	# B, the pit, the wrap.
	var b := b_at()
	SC._hex_strips(out,Vector2(b.x,b.z),float(LAYOUT.pillar_b.apothem)+CityKit.LEDGE,floor_y,b.y-COURSE,0.0)
	SC._hex_strips(out,Vector2(b.x,b.z),float(LAYOUT.pillar_b.apothem),floor_y,b.y,0.0)
	var p: Vector3 = LAYOUT.pit
	box.call(Rect2(p.x-5.6,p.z-13.3,11.2,8.8),p.y-24.0,p.y)
	box.call(Rect2(p.x-5.6,p.z+4.5,11.2,8.8),p.y-24.0,p.y)
	var wa: Vector3 = LAYOUT.wrap.at
	box.call(Rect2(wa.x-6.6,wa.z-6.6,13.2,13.2),wa.y-float(LAYOUT.wrap.deep),wa.y+25.6)
	for k in 4:
		# The ramp's four sides as boxes at their middle heights (the planner's
		# shelves are the pieces' own; these only fill the occupancy).
		var side := [Rect2(wa.x-19.0,wa.z+6.6,38.0,12.4),Rect2(wa.x+6.6,wa.z-19.0,12.4,38.0),Rect2(wa.x-19.0,wa.z-19.0,38.0,12.4),Rect2(wa.x-19.0,wa.z-19.0,12.4,38.0)][k] as Rect2
		box.call(side,wa.y-float(LAYOUT.wrap.deep),wa.y+3.2*(k+1)+12.8)
	# F, the coil.
	var fc := float(LAYOUT.far.crown)
	box.call(Rect2(-33.0,-200.0,52.0,52.0),fc-float(LAYOUT.far.depth),fc)
	box.call(Rect2(-33.0,-200.0,40.0,18.0),fc,fc+2.0*SO)
	var c := coil_at()
	var co := 16.3
	box.call(Rect2(c.x-co,c.z-co,co*2.0,co*2.0),floor_y,coil_top()+0.8)
	return out

# --- The land and the stone ----------------------------------------------------------------

func flora_site() -> KitFlora.Site:
	return KitFlora.Site.new(top(),KitLand.wear_of(paths()))

func flora_seed() -> int:
	return SEED+9

## The worn ways: the rim to the wedge's foot and to the dais's steps; the
## wrap's exit across F to its rim.
static func paths() -> Array:
	var wd: Vector3 = LAYOUT.wedge
	var d: Vector3 = LAYOUT.dais
	return [[Vector2(-4.0,22.0),Vector2(-2.0,0.0),Vector2(wd.x,-18.0)],[Vector2(-4.0,22.0),Vector2(10.0,8.0),Vector2(d.x-10.0,d.z)],
		[Vector2(-5.0,-148.0),Vector2(-8.0,-175.0),Vector2(-12.0,-198.0)]]

func life_script() -> Script:
	return null if Underground.on() else KitLife

func warm() -> void:
	KitLook.palette()
	KitLook.ground_material()
	KitLook.rock_material()
	KitLook.rock_tone(Vector3.ZERO,30.0,Vector3.UP)
	CityStone.warm()
	for k: String in CityStone.WEAR: CityStone.wear(k)
	GiantStone.warm()
	_computed()

## Measured headless on the Mac (the build alone, `built_ms`: 511 ms).
func build_cost() -> int:
	return 520

## The pieces, by name, once built (for `live`'s line and dresser).
var pieces := {}

func build(into: Node3D) -> void:
	art = into
	var began := Time.get_ticks_msec()
	var root := Node3D.new()
	root.name = "SerpentCrossing"
	into.add_child(root)
	pieces.clear()
	var floor_y := float(LAYOUT.floor)
	var made := {}
	# A: the arrival isle.
	var ad: Dictionary = LAYOUT.arrival
	var tone := KitLook.turf(int(ad.seed),KitLand.wear_of(paths()))
	var a_land := KitLand.island({"outline":ad.outline,"seed":int(ad.seed),"ground":func(x: float, z: float) -> float: return arrival_ground(x,z),
		"top":0.0,"depth":float(ad.depth),"cliffs":Rect2(-40.0,-66.0,80.0,96.0),"hang":true,"resample":[60.0,260,48],"tone":tone,"cell":2.0})
	a_land.name = "Arrival"
	# F: the far isle.
	var fd: Dictionary = LAYOUT.far
	var f_land := KitLand.island({"outline":far_outline(),"seed":int(fd.seed),"ground":func(x: float, z: float) -> float: return far_ground(x,z),
		"top":float(fd.crown),"depth":float(fd.depth),"cliffs":Rect2(-40.0,-206.0,70.0,62.0),"hang":true,"resample":[60.0,220,48],"tone":KitLook.turf(int(fd.seed)),"cell":2.0})
	f_land.name = "FarIsle"
	for land: Node3D in [a_land,f_land]:
		_collide_sides(land)
		root.add_child(land)
		turf(land)
	# The dais on A's east cliff, its footing down to the court.
	var d: Vector3 = LAYOUT.dais
	made.dais = CS.dais(root,Transform3D(Basis.IDENTITY,d),{"girth":1.0,"seed":SEED+20})
	# The ash court under it, the bowl, the giant steps.
	var a: Dictionary = LAYOUT.ash
	made.bowl = CS.ashbowl(root,Transform3D(Basis.IDENTITY,a.at),{"radius":float(a.radius),"rows":2,"seed":SEED+21})
	_court(root)
	# R and the ring.
	var r := ring_at()
	var rd: Dictionary = LAYOUT.ring
	var ri := CityKit.pillar(SEED+22,0.65,{"apothem":float(rd.apothem),"courses":1,"climb":-1,"crown":"flat","depth":float(rd.crown)-floor_y})
	ri.name = "RingIsle"
	ri.position = Vector3(r.x,float(rd.crown),r.z)
	root.add_child(ri)
	made.ring_isle = ri
	made.ring = CS.ring(root,Transform3D(Basis.IDENTITY,r),{"girth":1.0,"ground":float(rd.crown)-r.y,"seed":SEED+23})
	_stage(root)
	# The coil.
	var cd: Dictionary = LAYOUT.coil
	made.coil = CS.coil(root,Transform3D(Basis.IDENTITY,coil_at()),{"girth":1.0,"foot":deg_to_rad(float(cd.foot)-360.0),"turns":float(cd.turns),
		"rise":float(cd.rise),"depth":float(cd.y)-floor_y,"seed":SEED+24})
	# The slow way: the wedge, B with its turf, the pit, the wrap.
	made.wedge = CityKit.stand("city_wedge",root,Transform3D(Basis.IDENTITY,LAYOUT.wedge),SEED+25,0.6)
	var bd: Dictionary = LAYOUT.pillar_b
	var b := b_at()
	var bp := CityKit.pillar(SEED+26,0.7,{"apothem":float(bd.apothem),"courses":1,"climb":-1,"crown":"bare","depth":b.y-floor_y})
	bp.name = "PillarB"
	bp.position = b
	root.add_child(bp)
	made.pillar_b = bp
	var cap := KitLand.island({"outline":SC.cap_outline(float(bd.apothem),bd.cap),"seed":int(bd.cap.seed),"ground":func(_x: float, _z: float) -> float: return 0.0,
		"top":0.0,"depth":COURSE*0.6,"hang":true,"resample":[60.0,120,48],"tone":KitLook.turf(int(bd.cap.seed)),"cell":2.5})
	cap.name = "Turf_B"
	cap.position = b
	root.add_child(cap)
	# Registered where it stands (the Stacked Court's grass fix): the isle
	# reads a land's outline in its own frame, moved only by the isle's offset.
	var placed := PackedVector2Array()
	for q: Vector2 in (cap.get_meta("outline") as PackedVector2Array): placed.append(q+Vector2(b.x,b.z))
	turf(cap,placed)
	made.pit = CityKit.stand("city_pit",root,Transform3D(Basis.IDENTITY,LAYOUT.pit),SEED+27,0.55)
	made.wrap = CityKit.stand("city_wrap",root,Transform3D(Basis.IDENTITY,LAYOUT.wrap.at),SEED+28,0.6,{"deep":float(LAYOUT.wrap.deep)})
	_ledge(root)
	_drums(root)
	pieces = made
	root.set_meta("triangles",_triangles())
	built_ms = Time.get_ticks_msec()-began

## The ash court round the bowl's square (paving over a deep footing), the
## dais's footing, the giant steps up its south side to A.
func _court(root: Node3D) -> void:
	var m := GiantStone.mesher()
	var shapes: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED+30
	var a: Dictionary = LAYOUT.ash
	var c: Vector3 = a.at
	var h := float(a.half)
	var bh := 10.4
	var lo := float(LAYOUT.floor)+10.0
	for rr: Rect2 in [Rect2(c.x-h,c.z-h,h-bh,h*2.0),Rect2(c.x+bh,c.z-h,h-bh,h*2.0),Rect2(c.x-bh,c.z-h,bh*2.0,h-bh),Rect2(c.x-bh,c.z+bh,bh*2.0,h-bh)]:
		_pave(m,rr,c.y,rng)
		CS.Kit.span(m,shapes,Vector3(rr.position.x,c.y-8.0,rr.position.y),Vector3(rr.end.x,c.y-2.0,rr.end.y),0.3,0.8)
		shapes.append(CS.Kit.box_shape(Vector3(rr.size.x,8.0,rr.size.y),CS.Kit.at(Vector3(rr.get_center().x,c.y-4.0,rr.get_center().y))))
	# Under the bowl and the court: the footing stepped in as it goes down
	# into the haze (drawn), the makers' inverted courses.
	var y := c.y-8.0
	var side := h*2.0-0.6
	for k in 4:
		var tall := 7.0+4.0*k
		m.box(CS.Kit.at(Vector3(c.x+0.4*k,y-tall*0.5,c.z-0.3*k)),Vector3(side,tall,side),0.3,NAN,0.82-0.03*k)
		y -= tall
		side -= 4.2
	# The dais's footing: from under its platform down to the court.
	var d: Vector3 = LAYOUT.dais
	var x1 := c.x-bh-0.2
	CS.Kit.span(m,shapes,Vector3(d.x-6.0,c.y-2.0,d.z-6.4),Vector3(x1,d.y-0.02,d.z+6.4),0.2,0.86)
	# The giant steps: a set-off each, up south to A.
	var st: Dictionary = LAYOUT.steps
	for i in int(st.n):
		var z0 := float(st.z)+2.0*i
		var top := c.y+SO*(i+1)
		CS.Kit.span(m,shapes,Vector3(st.x.x,c.y-4.0,z0),Vector3(st.x.y,top,z0+2.0+(0.0 if i < int(st.n)-1 else 0.4)),0.1,0.9+0.03*(i%2))
	var node := Node3D.new()
	node.name = "AshCourt"
	root.add_child(node)
	CS.Kit.stone_node(node,m,"Mesh")
	CS.Kit.solid(node,shapes,"Body")

## Fallen column drums on A (cover; the makers' stone), gb_stacked_court's.
func _drums(root: Node3D) -> void:
	var g: RefCounted = GiantStone.mesher()
	var solids := StaticBody3D.new()
	solids.name = "Drums"
	for d: Array in LAYOUT.arrival.drums:
		var r := float(d[1])
		var length := float(d[2])
		var at := Vector3(d[0].x,0.0,d[0].y)
		at.y = arrival_ground(at.x,at.z)
		var turn := Basis(Vector3.UP,deg_to_rad(float(d[3])))*Basis(Vector3.FORWARD,PI/2.0)
		var xf := Transform3D(turn,at+Vector3.UP*(r-0.25))
		g.cylinder(xf,r,length,12,0.2,at.y-0.3,0.9)
		var c := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = r
		shape.height = length
		c.shape = shape
		c.transform = xf
		solids.add_child(c)
	var mesh := MeshInstance3D.new()
	mesh.name = "DrumsMesh"
	mesh.mesh = GiantStone.mesh_of(g)
	root.add_child(mesh)
	root.add_child(solids)

## The alighting stage on R: two set-off tiers beside the line, south of
## the ring's west abutment: off the saddle onto it is a drop under the
## fall stun (onto R's crown it would stun).
func _stage(root: Node3D) -> void:
	var m := GiantStone.mesher()
	var shapes: Array = []
	var cr := float(LAYOUT.ring.crown)
	for t: Array in LAYOUT.ring.stage:
		var rr: Rect2 = t[0]
		CS.Kit.span(m,shapes,Vector3(rr.position.x,cr-0.4,rr.position.y),Vector3(rr.end.x,float(LAYOUT.ring.stage_at)+float(t[1]),rr.end.y),0.12,0.92)
	var node := Node3D.new()
	node.name = "AlightingStage"
	root.add_child(node)
	CS.Kit.stone_node(node,m,"Mesh")
	CS.Kit.solid(node,shapes,"Body")

## Paving slabs over `r` at `y` (the serpent yard's).
static func _pave(m: GiantStone.Mesher, r: Rect2, y: float, rng: RandomNumberGenerator) -> void:
	var pave := 5.0
	var nx := maxi(1,int(roundf(r.size.x/pave)))
	var nz := maxi(1,int(roundf(r.size.y/pave)))
	var sx := r.size.x/nx
	var sz := r.size.y/nz
	for i in nx:
		for j in nz:
			var p := Vector3(r.position.x+sx*(i+0.5),y-1.0-rng.randf_range(0.0,0.035),r.position.y+sz*(j+0.5))
			m.box(Transform3D(Basis.IDENTITY,p),Vector3(sx-0.08,2.0,sz-0.08),0.06,y-2.0,rng.randf_range(0.82,1.06))

## The alighting ledge on F's worn cliff: stone slabs round the coil's arc,
## their tops F's crown, their inner edge clear of the serpent's flank.
func _ledge(root: Node3D) -> void:
	var fd: Dictionary = LAYOUT.far
	var arc: Array = fd.ledge
	var rr: Vector2 = fd.ledge_r
	var fc := float(fd.crown)
	var m := GiantStone.mesher()
	var shapes: Array = []
	var a0 := float(arc[0])
	var a1 := float(arc[1])
	var n := int(ceil((a1-a0)/6.0))
	var c := coil_at()
	for i in n:
		var a := a0+(a1-a0)*(i+0.5)/n
		var span := deg_to_rad((a1-a0)/n)*rr.y+0.3
		var mid := coil_point(a,(rr.x+rr.y)*0.5,fc-0.8)
		var out := Vector3(mid.x-c.x,0.0,mid.z-c.z).normalized()
		var basis := Basis.looking_at(-out,Vector3.UP)
		var xf := Transform3D(basis,mid)
		var size := Vector3(span,1.6,rr.y-rr.x)
		m.box(xf,size,0.12,NAN,0.9+0.05*(i%3))
		shapes.append([_box(size),xf])
		# A corbel under every other slab, into the cliff.
		if i%2 == 0: m.box(Transform3D(basis,mid+out*0.8-Vector3.UP*1.5),Vector3(span*0.6,1.6,1.0),0.12,NAN,0.85)
	var node := Node3D.new()
	node.name = "AlightingLedge"
	root.add_child(node)
	CS.Kit.stone_node(node,m,"Mesh")
	CS.Kit.solid(node,shapes,"Body")

static func _box(size: Vector3) -> BoxShape3D:
	var b := BoxShape3D.new()
	b.size = size
	return b

## An island's hanging sides collided as drawn (gb_sunken_giant's).
static func _collide_sides(land: Node3D) -> void:
	var sides := land.get_node_or_null("Mesh") as MeshInstance3D
	if sides == null or sides.mesh == null: return
	var body := StaticBody3D.new()
	body.name = "Sides"
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(sides.mesh.get_faces())
	shape.backface_collision = true
	var holder := CollisionShape3D.new()
	holder.shape = shape
	body.add_child(holder)
	land.add_child(body)

func _triangles() -> int:
	var n := 0
	for p: Variant in pieces.values():
		if p is Node3D: n += int((p as Node3D).get_meta("triangles",0))
	return n

# --- What moves --------------------------------------------------------------------------

## The serpent on its line, the fires, the breakables hub, the whole Olmec
## on B, the yard's far pillars, the abyss's ground cover on the stone.
func live(g: Node) -> void:
	# STAND-IN: studies/kit_isle.gd swaps the character study's ground for
	# its DeckGround after the motor took the old one's `mover` and `soft`;
	# the old ground is freed, so on the generator's stage the motor has no
	# moving or soft ground. Wired again here to the ground in use (the fix
	# belongs in kit_isle.gd `_build_pilot`).
	var study: Node = g.stage.study
	var motor: Variant = study.get("motor")
	var ground: Variant = study.get("ground")
	if motor != null and ground != null:
		if not (motor.mover as Callable).is_valid(): motor.mover = ground.mover_callable()
		if not (motor.soft as Callable).is_valid(): motor.soft = ground.soft_callable()
	var made := line()
	var cps: Array = made[0]
	var world: Array = []
	for cp: Array in cps:
		var q := cp.duplicate()
		q[0] = g.w(cp[0])
		world.append(q)
	var ride: Node3D = Line.new()
	ride.name = "SerpentLine"
	g.add_child(ride)
	ride.setup(self,g.stage.study,[world,made[1]],g.w(coil_at()))
	var fires := Node3D.new()
	fires.name = "Fires"
	g.add_child(fires)
	var d: Vector3 = LAYOUT.dais
	var k := 0
	for sz: float in [-1.0,1.0]:
		CityFires.cresset(fires,Transform3D(Basis.IDENTITY,g.w(d+Vector3(-0.6,SO,sz*3.2))),{"size":"crown","seed":SEED+40+k,"name":"DaisLamp%d" % k,"lit":true,"draw":1.0,"barge":false})
		k += 1
	var lure: Vector3 = LAYOUT.lure
	lure.y = arrival_ground(lure.x,lure.z)
	CityFires.cresset(fires,Transform3D(Basis.IDENTITY,g.w(lure)),{"size":"great","seed":SEED+44,"name":"LureCresset","lit":false,"draw":0.0})
	# Where you're going, read from the arrival rim (polish): F's beacon tower
	# raised on its west hill, a tier taller, its crown read far off; two
	# lamps on F's south lip where the slow way comes up; the coil's cap lit.
	var tw: Vector3 = LAYOUT.far.tower
	# Its foot at the lowest ground under it: the hill's steps bury the rest.
	var foot := INF
	for o: Vector2 in [Vector2.ZERO,Vector2(4.5,4.5),Vector2(-4.5,4.5),Vector2(4.5,-4.5),Vector2(-4.5,-4.5)]: foot = minf(foot,far_ground(tw.x+o.x,tw.z+o.y))
	var summit: Node3D = CityFires.tower(fires,Transform3D(Basis(Vector3.UP,0.5),g.w(Vector3(tw.x,foot,tw.z))),
		{"seed":SEED+45,"name":"FarTower","lit":true,"tiers":4,"beam":float(LAYOUT.beam)})
	SC._still(summit)
	k = 0
	for p: Vector2 in LAYOUT.far.lamps:
		var lamp := CityFires.cresset(fires,Transform3D(Basis.IDENTITY,g.w(Vector3(p.x,far_ground(p.x,p.y),p.y))),
			{"size":"crown","seed":SEED+46+k,"name":"FarLamp%d" % k,"lit":true,"barge":false,"beam":float(LAYOUT.beam)})
		SC._still(lamp)
		k += 1
	# The coil's rune spiral and the ring's bore held dimly lit (the strips'
	# `hold`; the serpent's nearness still wakes them full): the spiral
	# reads up out of the haze.
	for key: String in LAYOUT.glow:
		var piece: Node3D = pieces.get(key) as Node3D
		if piece == null: continue
		for st: Dictionary in piece.get_meta("strips",[]): st.hold = maxf(float(st.hold),float(LAYOUT.glow[key]))
	var cc := coil_at()
	var sp: Array = LAYOUT.coil.spire
	var spire: Node3D = CityFires.spire(fires,Transform3D(Basis.IDENTITY,g.w(coil_point(float(sp[0]),float(sp[1]),coil_top()+0.4))),
		{"tall":float(sp[2]),"radius":1.2,"lit":true,"seed":SEED+49,"name":"CoilSpire"})
	SC._still(spire)
	var rl: Dictionary = LAYOUT.coil.ramp_lamps
	var phi := float(rl.from)
	while phi < float(LAYOUT.coil.foot)+360.0*float(LAYOUT.coil.turns)-30.0:
		var lamp := CityFires.cresset(fires,Transform3D(Basis.IDENTITY,g.w(coil_point(phi,float(rl.r),coil_ramp(phi)))),
			{"size":"crown","seed":SEED+80+k,"name":"RampLamp%d" % k,"lit":true,"barge":false,"beam":float(LAYOUT.beam)})
		SC._still(lamp)
		phi += float(rl.every)
		k += 1
	for deg: float in LAYOUT.coil.lamps:
		var at := cc+Vector3(cos(deg_to_rad(deg))*5.4,coil_top()-cc.y+0.4,-sin(deg_to_rad(deg))*5.4)
		var lamp := CityFires.cresset(fires,Transform3D(Basis.IDENTITY,g.w(at)),
			{"size":"crown","seed":SEED+50+k,"name":"CoilLamp%d" % k,"lit":true,"barge":false,"beam":float(LAYOUT.beam)})
		SC._still(lamp)
		k += 1
	var hub: Node3D = Breakables.new()
	hub.field = g.stage.enemies
	g.add_child(hub)
	# The whole Olmec on B, chase on, his beat to the pit's plinth
	# (`--no-olmec`: none, for route checks).
	if preload("res://scripts/launch_args.gd").user_args().has("--no-olmec"):
		if str(g.stage.study.get_script().resource_path).ends_with("motif_yard.gd"): _far(g)
		return
	# In a generated layer the roaming Olmec comes instead (olmec-threat-
	# round1.md; `--knob=olmecs=places` brings the Keeper back).
	if OlmecPlaces.keepers(g):
		var kd: Dictionary = LAYOUT.keeper
		var beat: Array[Vector3] = []
		for p: Vector2 in kd.beat: beat.append(g.w(Vector3(p.x,b_at().y,p.y)))
		var post: Vector3 = beat[1]
		var body: Node3D = g.enemy(HeadlessBody,post+Vector3.UP*0.1,kd.face,{"chase":1,"chase_routes":1,"seed":SEED})
		var head: Node3D = g.enemy(InhalerHead,post+Vector3.UP*0.1,kd.face,{})
		var keeper: Node = SC.Keeper.new()
		keeper.name = "Keeper_STANDIN"
		keeper.beat = beat
		keeper.post = post
		keeper.field = g.stage.enemies
		keeper.hub = hub
		keeper.wear(body,head)
		g.add_child(keeper)
	if str(g.stage.study.get_script().resource_path).ends_with("motif_yard.gd"): _far(g)
	if Underground.on():
		var dresser: Node = SC.Dresser.new()
		dresser.name = "Dresser"
		dresser.motif = self
		g.add_child(dresser)

## Alone in the yard: far pillars in the haze, their crowns lit (drawn only).
func _far(g: Node) -> void:
	var far := Node3D.new()
	far.name = "FarLayers"
	g.add_child(far)
	var k := 0
	for f: Array in LAYOUT.far_pillars:
		var crown := float(f[2])*COURSE
		var at: Vector3 = g.w(Vector3(float(f[0]),crown,float(f[1])))
		var p := CityKit.pillar(SEED+60+k,0.7,{"apothem":float(f[3]),"courses":2,"climb":-1,"crown":"paved","depth":crown-float(LAYOUT.floor)-40.0})
		p.position = at
		for n: Node in p.find_children("*","CollisionObject3D",true,false): (n as CollisionObject3D).collision_layer = 0
		far.add_child(p)
		var t: Node3D = CityFires.tower(far,Transform3D(Basis(Vector3.UP,k*1.3),at+Vector3(float(f[3])*0.3,2.0*SO,0.0)),{"tiers":2,"base":9.0,"steps":false,"lit":true,"seed":SEED+70+k,"name":"FarTower%d" % k,"beam":3.0})
		SC._still(t)
		k += 1
