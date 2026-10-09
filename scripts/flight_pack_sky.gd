extends RefCounted
## The flight study's sky pack (scripts/flight_course.gd appends STATIONS to
## its own): greybox stations built from floating masses, with open sky and
## the cloud floor below rather than ground terrain. Each was laid out line
## first (tools/flight_sky_layout.py, which writes the STATIONS block below):
## the flowing line through the sky, then the islands, spans and spires
## stood round it, then the tokens along it.
##
## The pack's stations have no digit key (`key` NO_KEY): the study reaches
## them with N, `--station=<id>` or `--pack=sky` (which starts at the pack's
## first station and keeps N cycling within it). Their ids start `sky_`.
##
## Part kinds of its own (FlightCourse `solids` hands any kind it doesn't
## know to `solids_of`), in the station's local metres:
##   ["rock", middle Vector3, radius, height]   a floating upright drum: a
##       spire, a stack, a pillar of rock that doesn't reach the floor
##   ["isle", top Vector3, radius, keel]   a floating island: a flat top
##       ISLE_TOP thick at `top` (its middle), and under it a hanging keel of
##       KEEL_TIERS drums narrowing to a point `keel` m under the top, the
##       inverted cone of the game's islets (scripts/sky_islet.gd) in steps
##   ["span", a Vector3, b Vector3, width, sag]   a rope bridge's deck from
##       `a` to `b` (its walking surface at each end), sagging `sag` m at its
##       middle, SPAN_SEGMENTS planks with a rope rail either side
##   ["bore", start Vector3, yaw, pitch, length, width, height, wall]   a
##       stretch of tunnel through rock: `start` the middle of its mouth,
##       running `length` m along yaw and pitch, a `width` x `height`
##       opening with `wall` m of rock round it (floor, roof, both sides).
##       A curving tunnel is a chain of them.
##   ["slab", middle Vector3, size Vector3, yaw, pitch]   a box turned by
##       yaw and pitch (the course's own "box" turns by yaw only)
## Each expands into the course's solids ({"kind":"box"|"cyl", ...}).

const PACK := "sky"
## The key of a station with no digit key.
const NO_KEY := -1
## An isle's flat top (m thick), and its keel's drums as shares of its
## radius, top to bottom.
const ISLE_TOP := 1.5
const KEEL_TIERS := [0.66,0.46,0.3,0.16]
## A rope bridge: planks, the deck's thickness, its rails' height and size.
const SPAN_SEGMENTS := 6
const DECK := 0.35
const RAIL_UP := 0.9
const RAIL := 0.12

# >>> sky stations: written by tools/flight_sky_layout.py --write
const STATIONS := [
	{"id":"sky_weave","key":NO_KEY,"pack":PACK,"name":"Islet weave (round islets, under rims and keels, between pairs)","intent":"easy","ease":1.25,"parts":[
		["isle",Vector3(-4.16,0.51,-26.97),6.0,8.0],
		["isle",Vector3(5.44,10.83,-43.14),9.0,9.0],
		["isle",Vector3(10.27,5.82,-61.26),10.0,10.0],
		["isle",Vector3(1.13,2.98,-83.23),5.0,7.0],
		["isle",Vector3(17.17,3.48,-75.51),6.0,8.0],
		["isle",Vector3(4.97,1.49,-98.45),7.0,9.0],
		["isle",Vector3(11.27,11.70,-115.59),11.0,10.0],
		["isle",Vector3(11.71,5.49,-135.11),11.0,11.0],
		["isle",Vector3(-4.92,3.31,-153.39),6.0,8.0],
		["isle",Vector3(11.73,2.31,-149.97),5.0,7.0],
		["isle",Vector3(-2.07,1.53,-170.23),6.0,8.0],
		["isle",Vector3(1.17,13.95,-187.83),14.0,12.0],
	],"tokens":[
		Vector3(0.88,0.19,-10.95),Vector3(3.33,0.21,-20.64),Vector3(5.84,-0.55,-30.28),Vector3(5.93,-1.60,-40.18),
		Vector3(3.95,-1.71,-49.97),Vector3(2.80,-0.53,-59.81),Vector3(4.43,1.06,-69.51),Vector3(8.26,1.95,-78.69),
		Vector3(12.41,1.72,-87.78),Vector3(14.91,0.49,-97.35),Vector3(14.25,-1.05,-107.16),Vector3(10.85,-1.94,-116.50),
		Vector3(6.55,-1.73,-125.52),Vector3(3.33,-0.47,-134.88),Vector3(2.82,1.10,-144.70),Vector3(4.53,1.96,-154.50),
		Vector3(6.48,1.69,-164.30),Vector3(6.66,0.44,-174.19),Vector3(3.70,-1.09,-183.56),Vector3(-1.78,-1.95,-191.86),
		Vector3(-8.00,-1.70,-199.67),
	]},
	{"id":"sky_spire","key":NO_KEY,"pack":PACK,"name":"Spire spiral (round a floating spire: under its ledges, between stacks, under spans)","intent":"easy","ease":1.25,"miss_near":16.0,"parts":[
		["rock",Vector3(-30.00,4.00,-20.00),5.0,68.0],
		["isle",Vector3(-29.97,11.77,-32.60),10.0,9.0],
		["isle",Vector3(-29.96,23.78,-7.40),10.0,9.0],
		["isle",Vector3(-24.61,34.65,-32.41),10.0,9.0],
		["isle",Vector3(-44.00,16.42,-19.88),3.5,6.0],
		["isle",Vector3(-74.50,16.42,-19.88),6.5,9.0],
		["span",Vector3(-47.00,16.42,-19.88),Vector3(-69.00,16.42,-19.88),2.4,0.8],
		["isle",Vector3(-16.00,28.39,-20.08),3.5,6.0],
		["isle",Vector3(14.50,28.39,-19.80),6.5,9.0],
		["span",Vector3(-13.00,28.39,-20.05),Vector3(9.00,28.39,-19.85),2.4,0.8],
		["rock",Vector3(-44.54,8.01,-31.93),2.2,12.0],
		["rock",Vector3(-49.51,8.01,-41.96),2.2,12.0],
		["rock",Vector3(-44.49,13.99,-8.05),2.2,12.0],
		["rock",Vector3(-49.58,13.99,1.93),2.2,12.0],
		["rock",Vector3(-15.58,19.98,-8.02),2.2,12.0],
		["rock",Vector3(-10.67,19.98,2.05),2.2,12.0],
		["rock",Vector3(-15.57,26.00,-31.98),2.2,12.0],
		["rock",Vector3(-10.51,26.00,-41.97),2.2,12.0],
	],"tokens":[
		Vector3(-0.00,0.04,-10.00),Vector3(-0.86,0.32,-18.95),Vector3(-3.60,1.06,-27.45),Vector3(-9.05,2.31,-34.42),
		Vector3(-16.89,3.65,-38.50),Vector3(-25.63,5.17,-39.89),Vector3(-34.47,6.84,-39.89),Vector3(-43.20,8.37,-38.47),
		Vector3(-51.03,9.71,-34.35),Vector3(-56.42,10.96,-27.35),Vector3(-57.95,12.18,-18.66),Vector3(-55.15,13.41,-10.29),
		Vector3(-48.86,14.68,-4.09),Vector3(-40.62,16.06,-0.87),Vector3(-31.82,17.65,-0.02),Vector3(-22.98,19.31,-0.31),
		Vector3(-14.38,20.77,-2.41),Vector3(-7.09,22.08,-7.41),Vector3(-2.70,23.32,-15.06),Vector3(-2.43,24.53,-23.89),
		Vector3(-6.37,25.77,-31.79),Vector3(-13.40,27.06,-37.15),Vector3(-21.91,28.50,-39.56),
	]},
	{"id":"sky_spans","key":NO_KEY,"pack":PACK,"name":"Chain of spans (round each island, back in under each rope bridge)","intent":"medium","parts":[
		["isle",Vector3(-7.41,3.01,-26.43),8.0,10.0],
		["isle",Vector3(11.32,2.63,-57.60),9.0,10.066],
		["isle",Vector3(12.68,7.27,-91.42),10.0,10.066],
		["isle",Vector3(32.78,4.43,-121.30),8.5,11.504],
		["isle",Vector3(36.90,8.02,-157.96),9.5,11.504],
		["isle",Vector3(68.96,0.76,-176.36),8.0,10.0],
		["span",Vector3(-3.60,3.01,-32.77),Vector3(6.99,2.63,-50.40),2.4,0.9],
		["span",Vector3(11.66,2.63,-65.99),Vector3(12.30,7.27,-82.02),2.4,0.9],
		["span",Vector3(17.93,7.27,-99.22),Vector3(28.37,4.43,-114.74),2.4,0.9],
		["span",Vector3(33.66,4.43,-129.15),Vector3(35.90,8.02,-149.12),2.4,0.9],
		["span",Vector3(44.62,8.02,-162.39),Vector3(62.54,0.76,-172.68),2.4,0.9],
	],"tokens":[
		Vector3(0.42,0.23,-10.98),Vector3(2.63,0.21,-20.72),Vector3(4.60,-0.80,-30.44),Vector3(3.29,-1.97,-40.23),
		Vector3(0.20,-1.87,-49.73),Vector3(-0.74,-0.30,-59.49),Vector3(2.74,1.54,-68.58),Vector3(9.14,2.39,-76.19),
		Vector3(16.07,1.87,-83.36),Vector3(21.27,0.12,-91.65),Vector3(22.64,-1.72,-101.32),Vector3(21.66,-2.40,-111.24),
		Vector3(21.05,-1.72,-121.18),Vector3(23.35,0.05,-130.67),Vector3(29.60,1.78,-138.18),Vector3(37.88,2.40,-143.71),
		Vector3(46.30,1.64,-149.04),Vector3(52.90,-0.25,-156.21),Vector3(56.07,-1.94,-165.49),Vector3(57.47,-2.38,-175.37),
	]},
	{"id":"sky_pierced","key":NO_KEY,"pack":PACK,"name":"Pierced isle (a tunnel in from under the rim, round and back under the keel, the veil)","intent":"medium","miss_near":10.0,"parts":[
		["isle",Vector3(2.52,8.61,-29.62),6.5,8.0],
		["bore",Vector3(-1.98,1.99,-60.93),0.295,0.023,7.21,9.0,7.0,5.0],
		["bore",Vector3(-3.93,2.18,-67.25),0.254,-0.027,7.82,9.0,7.0,5.0],
		["bore",Vector3(-5.83,1.97,-74.22),0.105,0.001,7.81,9.0,7.0,5.0],
		["bore",Vector3(-6.71,1.97,-81.39),-0.122,0.005,7.8,9.0,7.0,5.0],
		["bore",Vector3(-5.99,2.01,-88.57),-0.379,-0.002,7.8,9.0,7.0,5.0],
		["bore",Vector3(-3.46,2.00,-95.33),-0.642,-0.001,7.8,9.0,7.0,5.0],
		["bore",Vector3(0.73,1.99,-101.22),-0.927,0.003,7.79,9.0,7.0,5.0],
		["bore",Vector3(6.42,2.01,-105.64),-1.127,-0.002,7.82,9.0,7.0,5.0],
		["rock",Vector3(-7.77,12.50,-89.13),24.0,4.0],
		["isle",Vector3(-7.77,-6.50,-89.13),20.0,7.0],
		["isle",Vector3(-29.84,-8.49,-66.99),9.0,11.0],
		["isle",Vector3(-35.97,-7.02,-89.66),8.0,10.0],
		["isle",Vector3(37.36,5.03,-122.59),8.0,8.0],
		["rock",Vector3(56.20,-8.52,-84.43),2.4,12.0],
		["rock",Vector3(45.70,-8.52,-89.36),2.4,12.0],
	],"tokens":[
		Vector3(1.72,-0.84,-10.82),Vector3(2.78,-2.14,-20.67),Vector3(2.46,-3.02,-30.62),Vector3(1.65,-2.42,-40.56),
		Vector3(0.36,-0.54,-50.29),Vector3(-1.69,1.38,-59.88),Vector3(-4.56,1.61,-69.44),Vector3(-6.52,1.46,-79.23),
		Vector3(-5.76,1.51,-89.15),Vector3(-1.61,1.50,-98.19),Vector3(5.56,1.51,-105.06),Vector3(14.53,1.49,-109.45),
		Vector3(23.69,1.11,-113.44),Vector3(33.05,0.07,-116.76),Vector3(42.62,-1.39,-115.28),Vector3(49.77,-3.02,-108.64),
		Vector3(52.95,-4.91,-99.43),Vector3(52.07,-6.91,-89.75),Vector3(47.16,-8.86,-81.36),Vector3(39.00,-11.04,-76.19),
		Vector3(29.40,-13.37,-75.05),Vector3(19.72,-15.26,-76.60),Vector3(10.03,-16.24,-78.86),Vector3(0.27,-16.66,-81.00),
		Vector3(-9.65,-16.36,-82.02),Vector3(-19.44,-14.64,-81.08),Vector3(-28.93,-11.86,-79.55),Vector3(-38.52,-9.55,-77.96),
		Vector3(-48.20,-7.65,-79.00),
	]},
]
# <<< sky stations

## The pack's solids for `part` (a kind above) at station origin `at`, or []
## for a kind it doesn't know.
static func solids_of(part: Array, at: Vector3) -> Array:
	match str(part[0]):
		"rock":
			return [{"kind":"cyl","middle":at+(part[1] as Vector3),"radius":float(part[2]),"height":float(part[3])}]
		"isle":
			return isle(at+(part[1] as Vector3),float(part[2]),float(part[3]))
		"span":
			return span(at+(part[1] as Vector3),at+(part[2] as Vector3),float(part[3]),float(part[4]))
		"bore":
			return bore(at+(part[1] as Vector3),float(part[2]),float(part[3]),float(part[4]),float(part[5]),float(part[6]),float(part[7]))
		"slab":
			return [_box(at+(part[1] as Vector3),part[2],turned(float(part[3]),float(part[4])))]
	return []

## A basis turned by `yaw` (about up, 0 north) and then `pitch` (nose up).
static func turned(yaw: float, pitch: float) -> Basis:
	return Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,pitch)

static func isle(top: Vector3, radius: float, keel: float) -> Array:
	var out := [{"kind":"cyl","middle":top-Vector3(0.0,ISLE_TOP*0.5,0.0),"radius":radius,"height":ISLE_TOP}]
	var step := (keel-ISLE_TOP)/KEEL_TIERS.size()
	for i in range(KEEL_TIERS.size()):
		var y := top.y-ISLE_TOP-step*(float(i)+0.5)
		out.append({"kind":"cyl","middle":Vector3(top.x,y,top.z),"radius":radius*float(KEEL_TIERS[i]),"height":step+0.02})
	return out

static func span(a: Vector3, b: Vector3, width: float, sag: float) -> Array:
	var out := []
	for i in range(SPAN_SEGMENTS):
		var p := _deck(a,b,sag,float(i)/SPAN_SEGMENTS)
		var q := _deck(a,b,sag,float(i+1)/SPAN_SEGMENTS)
		var d := q-p
		var flat := Vector2(d.x,d.z).length()
		var basis := turned(atan2(-d.x,-d.z),atan2(d.y,flat))
		var mid := (p+q)*0.5
		out.append(_box(mid-basis.y*DECK*0.5,Vector3(width,DECK,d.length()+0.15),basis))
		for side: float in [-1.0,1.0]:
			out.append(_box(mid+basis.x*side*width*0.5+basis.y*RAIL_UP,Vector3(RAIL,RAIL,d.length()+0.1),basis))
	return out

## The deck's walking surface `t` (0..1) of the way from `a` to `b`.
static func _deck(a: Vector3, b: Vector3, sag: float, t: float) -> Vector3:
	return a.lerp(b,t)-Vector3(0.0,4.0*sag*t*(1.0-t),0.0)

static func bore(start: Vector3, yaw: float, pitch: float, length: float, width: float, height: float, wall: float) -> Array:
	var basis := turned(yaw,pitch)
	var mid := start+basis*Vector3(0.0,0.0,-length*0.5)
	var put := func(local: Vector3, size: Vector3) -> Dictionary: return _box(mid+basis*local,size,basis)
	return [
		put.call(Vector3(0.0,-(height+wall)*0.5,0.0),Vector3(width+2.0*wall,wall,length)),
		put.call(Vector3(0.0,(height+wall)*0.5,0.0),Vector3(width+2.0*wall,wall,length)),
		put.call(Vector3(-(width+wall)*0.5,0.0,0.0),Vector3(wall,height,length)),
		put.call(Vector3((width+wall)*0.5,0.0,0.0),Vector3(wall,height,length)),
	]

static func _box(middle: Vector3, size: Vector3, basis: Basis) -> Dictionary:
	return {"kind":"box","middle":middle,"size":size,"basis":basis}
