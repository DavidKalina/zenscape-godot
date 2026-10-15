extends "res://scripts/kit_isle/motif_greybox.gd"
## The Haul-Way (card: docs/design/roguelike/brainstorm/round4-crossings/
## motif-m5-haulway.md), a crossing of the underground Olmec city: a quarry
## shore, a hundred and forty metres of black air, a low green shore far down, and
## between them two stone hawsers sagging in one long curve, each with a
## house-sized sledge slung under it. The pair are counterweights: one goes
## down full while the other comes up empty; they pass at the relay pier.
##
##   A  the quarry shore (west): a stepped pit cut into the land, opening
##      east through a slot at the lip. Over the slot the haul-house: two
##      colossus columns against the cut faces and a heavy lintel resting on
##      the uncut shoulders, the hawsers' anchors in its east face. The
##      sledge's cradle is the slot's mouth.
##   R  the relay pier, mid-gulf: one lone basalt pillar between the two
##      hawsers, its capital a step over the passing decks, a capstan on it,
##      a fender block hung either side.
##   B  the far shore (east, 140 m across, 24 m down): a low green
##      terrace, a matching haul-house, its cradle empty, the pieces of a
##      great head laid out on the turf with one place empty.
##
## Routes (rim in on A's west edge, rim out on B's east edge):
##   ride     down the quarry benches to the slot; hop the 1 m gap onto the
##            sledge at the cradle (8 s dwell, the chocks drop as a tell);
##            ride ~37 s; hop off at B's cradle.
##   slide    round the pit's rim to a shoulder, up onto the lintel, onto the
##            hawser's back; crouch: the rail slide down the sag. Past the
##            pier the cable flattens and the slide dies: walk its back up to
##            B's lintel, or drop to the pier.
##   relay    either way to the pier; take the passing sledge on, or the one
##            going back up (the retreat).
## The machine (the sledges, the fenders, the chocks, the jolts) is
## haulway_sledge.gd. Everything stands on one LAYOUT table.
const OlmecPlaces = preload("res://scripts/enemies/olmec_places.gd")
const CityKit = preload("res://scripts/city_kit.gd")
const CityStone = preload("res://scripts/city_kit_stone.gd")
const CityFires = preload("res://scripts/city_kit_fires.gd")
const SC = preload("res://scripts/kit_isle/greybox/gb_stacked_court.gd")
const GiantStone = preload("res://scripts/kit_isle/greybox/giant_stone.gd")
const Breakables = preload("res://scripts/kit_isle/breakables.gd")
const HeadlessBody = preload("res://scripts/enemies/headless_body.gd")
const InhalerHead = preload("res://scripts/enemies/inhaler_head.gd")
const KitLife = preload("res://scripts/kit_isle/kit_life.gd")
const Underground = preload("res://scripts/underground/underground.gd")
const Machine = preload("res://scripts/kit_isle/greybox/haulway_sledge.gd")
const HangingRoots = preload("res://scripts/kit_isle/hanging_roots.gd")

const SO := CityKit.SET_OFF
const SEED := 8500

# --- The layout: one table ----------------------------------------------------------------
## Frame: x east (A west, B east), z south, y up. A's slot floor (the cradle)
## is y 0 by construction (`floor_a`).
const LAYOUT := {
	"floor":-70.0,
	# The two hawsers: their centre lines from A's anchor (x a, y a) to B's
	# (x b, y b), a parabola `sag` m under the chord at the middle; each at
	# its z; drum links `radius` m (a wanderer tall across), a link every
	# `link` m. Their backs are walked: a flat top `walk` m wide at the crest.
	"hawser":{"xa":0.0,"ya":13.41,"xb":148.0,"yb":-15.39,"sag":12.0,"z":[-7.5,7.5],"radius":1.0,"link":2.2,"walk":1.8},
	# The sledges: a deck `deck` (x long, z wide, thick) slung `hang` m under
	# its hawser's line on one mast; it waits at A's cradle (deck centre x
	# `dwell_a`) and B's (`dwell_b`). Sledge 0 rides the north hawser, 1 the
	# south; they run against each other (counterweights).
	"sledge":{"deck":Vector3(14.0,3.0,8.0),"hang":7.5,"dwell_a":12.0,"dwell_b":136.0,"curb":Vector2(0.4,0.5),
		"speed":4.0,"accel":0.8,"dwell":8.0,"tell":2.0,"start":14.0},
	# A: its outline; the slot (half-width, from x `slot_back` to the lip at
	# x `lip`); the pit's benches (a set-off each, `bench` m wide, `benches`
	# of them up to the rim) round the slot's back, held under the shore's
	# fall to the lip ; the low shoulders
	# east of `mouth`, `shoulders` set-offs up, so the rim in looks out past
	# the haul-house (falling in arcs round the mouth, a set-off every `fall`
	# m); the haul road's rib (x from, to; z; half-width) from
	# the rim to the lintel's north end.
	"a":{"outline":[Vector2(4.0,-7.6),Vector2(3.0,-14.0),Vector2(4.5,-19.0),Vector2(0.0,-25.0),Vector2(-9.0,-28.5),Vector2(-20.0,-29.5),
			Vector2(-31.0,-27.0),Vector2(-41.0,-24.0),Vector2(-49.0,-16.0),Vector2(-52.0,-5.0),Vector2(-51.0,7.0),Vector2(-47.0,18.0),
			Vector2(-38.0,26.0),Vector2(-26.0,29.0),Vector2(-13.0,28.5),Vector2(-3.0,26.0),Vector2(3.5,19.5),Vector2(2.5,13.0),Vector2(4.0,7.6)],
		"slot":7.4,"slot_back":-16.0,"lip":4.0,"bench":2.4,"benches":10,"shoulders":1,"fall":2.6,"mouth":-3.0,"rib":{"x":Vector2(-40.0,1.6),"z":-12.9,"half":1.6},"depth":46.0,"seed":SEED+1},
	# B: its outline; its slot from the lip to `slot_back` (stepping up east
	# a set-off every `step_in` m past the lintel); its shoulders
	# under the lintel stepping down east a set-off every `step` m; the
	# terrace rising `rise` m east between x `rise_x`; the green crown, a
	# knoll [x, z, radius, high] with a lit beacon tower on it (read from A).
	"b":{"outline":[Vector2(143.4,-7.6),Vector2(145.0,-12.0),Vector2(152.0,-15.5),Vector2(164.0,-14.0),Vector2(176.0,-10.0),Vector2(186.0,-2.0),
			Vector2(190.0,10.0),Vector2(187.0,22.0),Vector2(178.0,31.0),Vector2(164.0,35.0),Vector2(152.0,33.0),Vector2(145.0,26.0),Vector2(143.5,16.0),Vector2(143.4,7.6)],
		"slot":7.4,"slot_back":156.0,"lip":144.0,"step":3.4,"step_in":2.4,"rise":3.2,"rise_x":Vector2(156.0,182.0),"knoll":[168.0,19.0,13.0,6.0],"beacon":Vector2(168.0,19.0),"depth":38.0,"seed":SEED+2},
	# The haul-houses: lintel (x middle, half-thickness x, z from and to, how
	# deep), columns (z, radius). A's lintel stops short of the south so the
	# rim in sees the pier and B past its end.
	"house_a":{"x":0.0,"half_x":1.8,"z":Vector2(-12.5,11.5),"tall":2.6,"columns":[-7.5,7.5],"radius":1.6,"fallen":true,
		# Its capitals (z from, to) and the fallen beam's halves [(x, z), size,
		# yaw, pitch, roll (deg), sunk (m)].
		"caps":[[Vector2(-13.0,-5.5)],[Vector2(5.5,9.5)]],
		"fallen_beam":[[Vector2(-1.5,13.5),Vector3(3.4,2.6,11.0),74.0,4.0,-6.0,0.6],[Vector2(-9.0,-10.6),Vector3(3.4,2.6,9.0),-12.0,-14.0,8.0,0.9]]},
	"house_b":{"x":148.0,"half_x":1.8,"z":Vector2(-12.5,12.5),"tall":2.0,"columns":[-9.8,9.8],"radius":1.4},
	# The relay pier: x, its capital (half x, half z, thick) a step over the
	# decks passing at its middle; its shaft's radius; the capstan; its root
	# of widening courses from `root_under` m under the decks.
	"pier":{"x":74.0,"half":Vector2(6.0,3.0),"thick":1.4,"over":1.2,"shaft":2.3,"capstan":1.1,"root_under":9.0},
	# The fenders (haulway_sledge.gd): arm (m), block, its pivot `drop` m
	# under the capital's top (a deck's waist), the knock (m/s out, up), the
	# window (m of a deck's middle off the pier's) they swing in.
	"fender":{"arm":2.4,"block":Vector3(1.0,1.1,1.0),"drop":0.3,"knock":Vector2(3.5,3.0),"window":10.0},
	# The quarry's stone: [kind, x, z, size or radius, ...] as Lamplighters'
	# `stones`: ["block", x, z, size, yaw, pitch, roll, sunk], ["drum", x, z,
	# radius, length, yaw, sunk], ["slab", x, z, size, yaw, pitch, roll,
	# sunk] (a block with its rough end unworked), ["split", x, z, size, yaw,
	# sunk, gap] (a block split in two, wedges in the split). A: the
	# half-dressed slab on its rollers, a wedge-split block, a felled column
	# drum on a bench.
	"stones":[
		["block",-9.0,3.5,Vector3(5.2,1.8,3.4),8.0,0.0,0.0,-0.9],["drum",-11.0,3.5,0.45,4.2,8.0,0.0],["drum",-7.0,3.5,0.45,4.2,8.0,0.0],
		["block",-13.5,-4.0,Vector3(2.6,1.6,2.2),-14.0,4.0,-6.0,0.2],["block",-12.4,-5.8,Vector3(1.4,1.5,2.0),24.0,-8.0,10.0,0.3],
		["drum",-27.0,-14.0,1.5,2.6,62.0,0.6],["block",-24.0,17.0,Vector3(3.0,1.4,2.2),30.0,8.0,-4.0,0.5],
		["block",-38.0,-18.0,Vector3(1.2,4.4,0.9),15.0,-6.0,9.0,1.2],
		# A second slab half-dressed on its rollers, a row of wedge-split
		# blocks along a bench, a drum rolled into the turf, a stela.
		["block",-20.0,-4.5,Vector3(6.0,2.2,3.8),-6.0,0.0,0.0,-0.9],["drum",-22.4,-4.5,0.5,4.6,-6.0,0.0],["drum",-17.6,-4.5,0.5,4.6,-6.0,0.0],
		["block",-24.0,11.5,Vector3(2.2,1.6,1.8),12.0,3.0,-4.0,0.4],["block",-21.4,12.2,Vector3(2.0,1.5,1.7),-8.0,-5.0,6.0,0.4],["block",-18.9,12.6,Vector3(2.3,1.4,1.9),20.0,4.0,3.0,0.5],
		["drum",-31.0,4.0,1.4,2.8,40.0,0.8],["block",-33.0,-9.0,Vector3(1.1,3.8,0.8),-25.0,8.0,-7.0,1.1],
		# Polish: a great half-dressed slab sunk in the turf where it slid
		# down two broken benches (its rough end unworked); wedge-split
		# blocks, their wedges still in the split; the spoil heaps' rubble.
		["slab",-33.0,12.5,Vector3(7.4,2.4,4.2),-28.0,9.0,-5.0,1.1],
		["split",-23.0,-18.5,Vector3(3.4,1.8,2.2),8.0,0.5,0.3],["split",-28.5,-20.0,Vector3(2.8,1.6,2.0),-14.0,0.4,0.22],["split",-17.0,19.0,Vector3(3.0,1.7,2.1),24.0,0.5,0.26],
		["block",-12.0,-25.0,Vector3(1.6,1.1,1.3),20.0,18.0,-12.0,0.5],["block",-10.4,-23.6,Vector3(1.1,0.8,0.9),-30.0,-22.0,15.0,0.35],["block",-13.6,-23.2,Vector3(0.9,0.7,1.0),45.0,10.0,25.0,0.3],
		["block",-8.0,23.0,Vector3(1.4,1.0,1.2),-15.0,-16.0,10.0,0.45],["block",-6.4,21.8,Vector3(1.0,0.7,0.8),35.0,20.0,-18.0,0.3],
		["block",-44.0,-20.0,Vector3(1.3,0.9,1.1),10.0,14.0,20.0,0.4],["block",-45.6,-18.8,Vector3(0.8,0.6,0.9),-40.0,-25.0,10.0,0.3],
		["block",-30.0,25.5,Vector3(1.2,0.9,1.0),25.0,-12.0,-20.0,0.4],
		# B: a stela; a drum.
		["block",170.0,9.0,Vector3(1.3,4.0,1.0),40.0,7.0,-11.0,1.0],
		["drum",176.0,-2.0,1.4,2.4,-30.0,0.7],
		# Polish: what was delivered: a head's pieces laid out on the turf in
		# their places, brow to chin, one place empty (the slab still on its
		# way). ["brow", x, z, yaw, sunk, pitch, roll].
		["brow",160.0,-6.4,-4.0,0.6,3.0,-2.0],["brow",163.6,-6.7,2.0,0.7,-2.0,3.0],["brow",167.2,-6.3,-6.0,0.5,4.0,1.0],
		["brow",160.4,-9.9,6.0,0.8,-5.0,2.0],["brow",167.0,-10.1,-3.0,0.9,2.0,-4.0],
	],
	# Far off in the haze (the yard alone): pillar crowns [x, z, crown, apothem].
	"far_pillars":[[30.0,-150.0,-30.0,26.0],[120.0,170.0,-44.0,30.0],[-90.0,-110.0,-6.0,24.0],[230.0,-90.0,-30.0,28.0],[80.0,-260.0,-12.0,30.0],[-60.0,190.0,-20.0,26.0],
		# Polish: two low crowns deep under the gulf, beside and past the
		# pier (the drop reads against them).
		[46.0,-62.0,-58.0,16.0],[112.0,58.0,-66.0,18.0]],
	# Polish (`--haul-grey` builds the grey boxes instead, A/B):
	# The pit's benches: their lines meander `warp` m (tongues and bites,
	# held off the rim's west edge); in patches two benches go as one, a
	# double cut face (`merge`: the noise over which); elsewhere a face has
	# slumped to a rounded scree slope (`slump`); every bench's pit-side lip
	# is rounded over in turf `lip` m deep over `lip_w` of a bench.
	"pit":{"warp":2.2,"merge":0.32,"slump":0.22,"lip":0.75,"lip_w":0.6,"rim_lip":1.3},
	# Spoil heaps on A [x, z, radius, high]: the quarry's waste, rough.
	"spoil":[[-12.0,-24.5,6.5,2.4],[-7.5,22.5,6.0,2.0],[-44.0,-20.0,5.0,1.8],[-30.0,25.5,5.0,1.5]],
	# B's knolls [x, z, radius, high] beside its crown (held off the rim
	# out, the cradle and the laid-out head).
	"b_knolls":[[181.0,-3.0,8.0,1.8],[152.0,25.0,7.0,1.4],[176.0,26.0,6.0,1.2]],
	# Where he comes in and goes out.
	"start":Vector2(-38.5,20.0),
	"rim_in":Vector2(-40.0,22.0),
	"rim_out":Vector2(185.0,12.0),
	# The Olmecs (STAND-IN for riders): one waits on the pier's capital, one
	# walks B's terrace past the cradle. Beats (x, z).
	"olmecs":{"pier":[Vector2(71.5,0.0),Vector2(74.0,0.0),Vector2(76.5,0.0)],"b":[Vector2(159.0,-3.0),Vector2(164.0,1.0),Vector2(159.0,4.0)]},
}

# --- The hawsers ------------------------------------------------------------------------------

## The hawser's centre line at x (both hawsers alike).
static func cable_y(x: float) -> float:
	var h: Dictionary = LAYOUT.hawser
	var t := (x-float(h.xa))/(float(h.xb)-float(h.xa))
	return float(h.ya)+(float(h.yb)-float(h.ya))*t-4.0*float(h.sag)*t*(1.0-t)

## Its rise a metre along x.
static func cable_slope(x: float) -> float:
	var h: Dictionary = LAYOUT.hawser
	var L := float(h.xb)-float(h.xa)
	var t := (x-float(h.xa))/L
	return ((float(h.yb)-float(h.ya))-4.0*float(h.sag)*(1.0-2.0*t))/L

## Its back (the walked crest) at x.
static func crest(x: float) -> float:
	return cable_y(x)+float(LAYOUT.hawser.radius)

## A sledge's deck top with its mast under x.
static func deck_top(x: float) -> float:
	return cable_y(x)-float(LAYOUT.sledge.hang)

static func floor_a() -> float:
	return deck_top(float(LAYOUT.sledge.dwell_a))

static func floor_b() -> float:
	return deck_top(float(LAYOUT.sledge.dwell_b))

## The shoulders at the lip and the rim at the back, where he arrives over
## the whole view.
static func top_a() -> float:
	return floor_a()+float(LAYOUT.a.shoulders)*SO

static func rim_a() -> float:
	return floor_a()+float(LAYOUT.a.benches)*SO

static func pier_top() -> float:
	return deck_top(float(LAYOUT.pier.x))+float(LAYOUT.pier.over)

## The lintels: top at the hawser's crest over the anchor; A's on its
## columns and, at its north end, the haul road's rib; B's on its shoulders.
static func lintel_a() -> Vector2:
	var top := crest(float(LAYOUT.house_a.x))
	return Vector2(top-float(LAYOUT.house_a.tall),top)

static func lintel_b() -> Vector2:
	var top := crest(float(LAYOUT.house_b.x))
	return Vector2(top-float(LAYOUT.house_b.tall),top)

# --- The land ---------------------------------------------------------------------------------

## A's ground: the slot at the cradle's floor; east of the mouth its low
## shoulders; behind, the pit's benches climbing out round the slot's back
## to the rim, ragged (each bench line wanders on its own), the shore
## stepping down to the lip; the haul road's rib over them. Polish: the
## benches broken (pinched into double cut faces, slumped to scree), their
## lips rounded in turf, spoil heaps.
static func a_ground(x: float, z: float) -> float:
	var a: Dictionary = LAYOUT.a
	var fa := floor_a()
	var az := absf(z)
	var slot := float(a.slot)+0.45*sin(x*0.31+1.0)+0.25*sin(x*0.93)
	var y := fa
	var polish := not grey()
	if x > float(a.mouth):
		# The mouth: the slot, and low shoulders either side (a set-off) where
		# the columns stand, so the rim in sees the crossing past them.
		if az >= slot: y = fa+float(a.shoulders)*SO+0.25*sin(z*0.7+x*0.3)
	else:
		var back := float(a.slot_back)-x
		var side := az-float(a.slot)
		var e := maxf(back,side)
		if e > 0.0 or az >= slot:
			var pit: Dictionary = LAYOUT.pit
			var rim_past := INF
			var wob := 1.1*sin(x*0.17+z*0.11+0.4)+0.6*sin(x*0.41-z*0.23)
			if not polish: wob += 0.35*sin(z*0.9+x*0.2)
			# The benches out of the pit, held under the shore's fall to the
			# lip: the land steps down east, a set-off every `fall` m.
			# (Arcs round the mouth, so the shore falls to the lip as a bowl's
			# lip, not in rows.)
			var d := Vector2(x-float(a.lip),z*0.62).length()+1.2*sin(z*0.23+x*0.05)+0.6*sin(x*0.31+1.3)
			var g := (d-9.0)/float(a.fall)
			var cap := int(a.shoulders)+clampi(int(floor(g)),0,int(a.benches)-int(a.shoulders))
			var f := (e+wob)/float(a.bench)
			var n := mini(clampi(int(ceil(f)),0,int(a.benches)),cap)
			var yb := float(n)
			if polish:
				# Polish: every bench line and every step of the shore's fall
				# wanders on its own (`cut`), so benches pinch out into double
				# faces and spread into wide shelves; here and there a line is
				# gone (a bench slumped away: a cross step where it ends).
				var cut := _cut(e+wob,x,z,int(a.benches),float(a.bench),3,0.0)
				rim_past = cut.y
				var fall := _cut(d-9.0,x,z,int(a.benches)-int(a.shoulders),float(a.fall),11,2.5)
				var nb := int(cut.x)
				var nf := int(a.shoulders)+int(fall.x)
				n = mini(nb,nf)
				yb = float(n)
				# How far past its own line (m) and how wide the bench is there.
				var past := cut.y if nb <= nf else fall.y
				var r := smoothstep(float(pit.slump),float(pit.slump)+0.35,sin(x*0.13+1.7)*sin(z*0.19+0.4)+0.25*sin(x*0.29-z*0.21))
				if n > 0 and n < int(a.benches):
					if r > 0.0:
						# Slumped: the face above gone to a rounded scree slope.
						var t := clampf(past/2.4,0.0,1.0)
						yb = lerpf(yb,float(n)-1.0+smoothstep(0.0,1.0,t),r*0.9)
					else:
						# The lip rounded over in turf (its downhill side).
						var w := float(pit.lip_w)*2.4
						if past < w: yb -= float(pit.lip)/SO*pow(1.0-past/w,1.6)*(0.7+0.3*sin(x*0.7+z*0.5))
			else:
				if n > 0 and n < cap:
					var fr := f-floorf(f)
					var r := smoothstep(0.35,0.75,sin(x*0.13+1.7)*sin(z*0.19+0.4))
					if r > 0.0: yb = lerpf(yb,floor(f)+fr,r*0.8)
			y = fa+yb*SO
			# The rim: a little swell, held flat at the rim in.
			if n == int(a.benches):
				var ri: Vector2 = LAYOUT.rim_in
				var keep := smoothstep(6.0,14.0,Vector2(x-ri.x,z-ri.y).length())
				y += keep*(0.7*sin(x*0.09+z*0.07)*sin(z*0.11-0.3)+0.5)
				# Polish: the rim's lip over the pit rounded over in turf.
				if polish:
					var into := rim_past/float(a.bench)
					if into < 1.0: y -= float(pit.rim_lip)*pow(1.0-clampf(into,0.0,1.0),2.0)
	if polish:
		y += spoil(x,z)
	return maxf(y,rib(x,z))

## Polish: lines `apart` m apart in `v`, each wandering on its own about
## its place (salt `salt`), some gone in patches from line `gone_from`
## (none if 0): [how many lines v is past, m past the last of them].
static func _cut(v: float, x: float, z: float, lines: int, apart: float, salt: int, gone_from: float) -> Vector2:
	var count := 0
	var past := v
	# Only the lines near v are worked out: one further than the most a
	# line wanders (and its next, a gone line's) is surely under or over.
	var most := float(LAYOUT.pit.warp)+apart
	for i in lines:
		var base := i*apart
		if base-most > v: break
		if base+most+2.4 < v:
			count += 1
			past = minf(past,v-base-most)
			continue
		var at := _line(i,x,z,lines,apart,salt)
		# Broken: a line gone in a patch: that bench pinched out, its face
		# one with the next (a double face; a cross step where the patch ends).
		if i >= 2 and i < lines-2 and (gone_from == 0.0 or i >= int(gone_from)):
			var k := float(i*7+salt)
			if sin(x*0.12+k*2.1)*sin(z*0.14-k*1.7) > 0.55: at = maxf(at,_line(i+1,x,z,lines,apart,salt))
		if v > at:
			count += 1
			past = minf(past,v-at)
	return Vector2(count,past)

## Line i of `_cut`'s (the top two held nearly still: the rim and the haul
## road's foot).
static func _line(i: int, x: float, z: float, lines: int, apart: float, salt: int) -> float:
	var k := float(i*7+salt)
	var w := float(LAYOUT.pit.warp)*(0.35 if i >= lines-2 else 1.0)
	return i*apart+w*(0.6*sin(x*(0.07+0.011*(i%3))+z*0.05+k*1.3)+0.4*sin(z*(0.09+0.013*(i%4))-x*0.04+k*0.7))

static func grey() -> bool:
	return preload("res://scripts/launch_args.gd").user_args().has("--haul-grey")

## Polish: the spoil heaps' rise at (x, z) (rough, a little lumpy).
static func spoil(x: float, z: float) -> float:
	var up := 0.0
	for h: Array in LAYOUT.spoil:
		var d := Vector2(x-float(h[0]),z-float(h[1])).length()/float(h[2])
		if d >= 1.0: continue
		var lump := 1.0+0.18*sin(x*1.3+z*0.7)*sin(z*1.1-x*0.4)+0.1*sin(x*2.3+z*1.9)
		up += float(h[3])*pow(cos(d*PI*0.5),1.3)*lump
	return up

## The haul road: a rib of uncut rock the quarrymen left standing along the
## pit's north side, from the rim down to the lintel's north end (its top
## the lintel's), the way up onto the hawsers. -INF off it.
static func rib(x: float, z: float) -> float:
	var r: Dictionary = LAYOUT.a.rib
	var span: Vector2 = r.x
	if x < span.x or x > span.y: return -INF
	var mid := float(r.z)+0.9*sin(x*0.19+0.5)+0.4*sin(x*0.53)
	var half := float(r.half)+0.35*sin(x*0.37+1.1)
	if absf(z-mid) > half: return -INF
	var t := (x-span.x)/(span.y-span.x)
	return lerpf(rim_a(),lintel_a().y,t)+0.25*sin(x*0.7)*(1.0-t)*t*4.0

## B's ground: the slot at the cradle's floor; its shoulders under the
## lintel's ends stepping down east a set-off at a time; the green terrace
## rising gently east to the rim out.
static func b_ground(x: float, z: float) -> float:
	var b: Dictionary = LAYOUT.b
	var fb := floor_b()
	var az := absf(z)
	var rx: Vector2 = b.rise_x
	var rise := float(b.rise)*smoothstep(rx.x,rx.y,x)
	var swell := 0.8*sin(x*0.11+z*0.07)*sin(z*0.09+1.2)*smoothstep(rx.x-4.0,rx.x+8.0,x)
	var y := fb+rise+swell
	# The green crown: a knoll over the terrace, the beacon on it, held off
	# the rim out.
	var kn: Array = b.knoll
	var kd := Vector2(x-float(kn[0]),z-float(kn[1])).length()/float(kn[2])
	if kd < 1.0:
		var ro: Vector2 = LAYOUT.rim_out
		var keep := smoothstep(5.0,11.0,Vector2(x-ro.x,z-ro.y).length())
		y += float(kn[3])*pow(cos(kd*PI*0.5),1.6)*keep
	if not grey():
		# Polish: knolls beside the crown, a terrace rolling to its edge
		# (held off the rim out).
		var ro: Vector2 = LAYOUT.rim_out
		var keep := smoothstep(4.0,9.0,Vector2(x-ro.x,z-ro.y).length())
		for k: Array in LAYOUT.b_knolls:
			var d := Vector2(x-float(k[0]),z-float(k[1])).length()/float(k[2])
			if d < 1.0: y += float(k[3])*pow(cos(d*PI*0.5),1.8)*keep
	var lb := lintel_b()
	var n := clampi(int(floor((x-float(LAYOUT.house_b.x)-2.0+1.2*sin(z*0.3))/float(b.step)))+1,0,4)
	# Polish: the shoulders held low (the lintel stands on its columns over
	# them), so from the docked deck the terrace opens beyond the cradle.
	if not grey(): n = maxi(n,int(b.get("low",3)))
	if az < 21.0:
		var sh := lb.x-n*SO
		y = maxf(y,sh)
	# The slot: the cradle's floor, then stepping up east a set-off at a
	# time out onto the terrace (never over the ground beside it).
	var slot := float(b.slot)+0.4*sin(x*0.37+0.5)
	if x < float(b.slot_back) and az < slot:
		var up := maxi(0,int(floor((x-float(LAYOUT.house_b.x)-2.0)/float(b.step_in))))
		return minf(y,fb+up*SO)
	return y

# --- The motif's face -------------------------------------------------------------------

func slug() -> String:
	return "haulway"

func isle_name() -> String:
	return "The Haul-Way"

func epithet() -> String:
	return "They never finished the delivery. The last slab is still on its way."

func brief() -> String:
	return "Ride a sledge across: hop on at the cradle while it waits. Or climb onto the lintel and rail-slide the hawser (crouch).\nThey pass at the relay pier: change sledges there. Mind the fenders, and what waits on the pier."

func start() -> Vector3:
	var s: Vector2 = LAYOUT.start
	return Vector3(s.x,a_ground(s.x,s.y),s.y)

func rims() -> Array:
	var ri: Vector2 = LAYOUT.rim_in
	var ro: Vector2 = LAYOUT.rim_out
	return [
		{"name":"quarry_rim","at":Vector3(ri.x,a_ground(ri.x,ri.y),ri.y),"face":Vector3(-0.85,0.0,0.53),"run_up":14.0,"lip":1.5},
		{"name":"far_terrace","at":Vector3(ro.x,b_ground(ro.x,ro.y),ro.y),"face":Vector3(1.0,0.0,0.0),"run_up":14.0,"lip":1.5},
	]

func spots() -> Array:
	var p: Dictionary = LAYOUT.pier
	var la := lintel_a()
	return [
		{"kind":"arena","name":"slot_floor","at":Vector3(-8.0,floor_a(),0.0),"room":6.0},
		{"kind":"arena","name":"far_terrace","at":Vector3(172.0,b_ground(172.0,2.0),2.0),"room":10.0},
		{"kind":"cover","name":"under_the_lintel","at":Vector3(-1.0,floor_a(),0.0),"room":3.0},
		{"kind":"perch","name":"lintel","at":Vector3(0.0,la.y,0.0),"room":1.5},
		{"kind":"perch","name":"capstan","at":Vector3(float(p.x),pier_top()+1.0,0.0),"room":1.0},
		{"kind":"rune_line","name":"bench_north","at":Vector3(-20.0,a_ground(-20.0,-14.0)+0.6,-14.0),"room":1.0},
		{"kind":"rune_line","name":"cradle","at":Vector3(2.0,floor_a()+0.6,0.0),"room":1.0},
		{"kind":"rune_line","name":"pier","at":Vector3(float(p.x)-3.5,pier_top()+0.6,0.0),"room":1.0},
		{"kind":"rune_risk","name":"hawser_mid","at":Vector3(34.0,crest(34.0)+0.6,-5.0),"room":0.8},
		{"kind":"rare","name":"capstan_top","at":Vector3(float(p.x),pier_top()+1.6,0.0),"room":0.6},
	]

## Solids for the occupancy and the footprint: each shore in 4 m strips
## (each its lowest, from the keel), the pier, the hawsers' band with the
## sledges' sweep under them.
func parts() -> Array:
	var out: Array = []
	var floor_y := float(LAYOUT.floor)
	_strips(out,LAYOUT.a.outline,func(x: float, z: float) -> float: return a_ground(x,z),floor_y)
	_strips(out,LAYOUT.b.outline,func(x: float, z: float) -> float: return b_ground(x,z),floor_y)
	var p: Dictionary = LAYOUT.pier
	var hp: Vector2 = p.half
	out.append(["box",Rect2(float(p.x)-hp.x,-hp.y,hp.x*2.0,hp.y*2.0),floor_y,pier_top()+1.0,"grey"])
	var rr := float(p.shaft)+7.2
	out.append(["box",Rect2(float(p.x)-rr,-rr,rr*2.0,rr*2.0),floor_y,deck_top(float(p.x))-float(p.root_under),"grey"])
	var h: Dictionary = LAYOUT.hawser
	var x := float(h.xa)+4.0
	while x < float(h.xb)-4.0:
		var x1 := minf(x+12.0,float(h.xb)-4.0)
		var hi := maxf(crest(x),crest(x1))
		var lo := minf(deck_top(x),deck_top(x1))-float(LAYOUT.sledge.deck.y)
		out.append(["box",Rect2(x,-12.0,x1-x,24.0),lo,hi,"grey"])
		x = x1
	return out

static func _strips(out: Array, outline: Array, ground: Callable, floor_y: float) -> void:
	var poly := PackedVector2Array(outline)
	var box := Rect2(poly[0],Vector2.ZERO)
	for p in poly: box = box.expand(p)
	var cell := 4.0
	var z := box.position.y
	while z < box.end.y:
		var x := box.position.x
		var run_x := NAN
		var run_y := NAN
		while x <= box.end.x:
			var h := NAN
			if Geometry2D.is_point_in_polygon(Vector2(x+cell*0.5,z+cell*0.5),poly):
				h = INF
				for q: Vector2 in [Vector2(0.3,0.3),Vector2(cell-0.3,0.3),Vector2(0.3,cell-0.3),Vector2(cell-0.3,cell-0.3),Vector2(cell*0.5,cell*0.5)]:
					h = minf(h,float(ground.call(x+q.x,z+q.y)))
				h = snappedf(h,0.1)
			if not is_nan(run_x) and (is_nan(h) or h != run_y):
				out.append(["box",Rect2(run_x,z,x-run_x,cell),floor_y,run_y,"grey"])
				run_x = NAN
			if not is_nan(h) and is_nan(run_x):
				run_x = x
				run_y = h
			x += cell
		if not is_nan(run_x): out.append(["box",Rect2(run_x,z,x-run_x,cell),floor_y,run_y,"grey"])
		z += cell

# --- The land and the stone ------------------------------------------------------------

func flora_site() -> KitFlora.Site:
	var site := KitFlora.Site.new(top(),KitLand.wear_of(paths()))
	site.ray = Vector2(rim_a()+20.0,floor_b()-10.0)
	# Polish: grass over both shores, a little thicker than the kit's.
	if not grey(): site.tufts = 6.0
	return site

func flora_seed() -> int:
	return SEED+9

## The worn ways: the rim in round the pit's north rim to the shoulder; down
## the benches' west side into the slot and out to the cradle; B's cradle to
## the rim out.
static func paths() -> Array:
	var ri: Vector2 = LAYOUT.rim_in
	var ro: Vector2 = LAYOUT.rim_out
	return [[ri,Vector2(-28.0,14.0),Vector2(-18.0,6.0),Vector2(-10.0,2.0),Vector2(3.0,0.0)],
		[Vector2(-36.0,-8.0),Vector2(-22.0,-24.0),Vector2(-4.0,-22.0),Vector2(0.0,-14.0)],
		[Vector2(144.0,0.0),Vector2(158.0,3.0),Vector2(172.0,8.0),ro]]

func life_script() -> Script:
	return null if Underground.on() or grey() else KitLife

func warm() -> void:
	if grey():
		super.warm()
		return
	HangingRoots.warm()
	KitLook.palette()
	KitLook.ground_material()
	KitLook.rock_material()
	KitLook.rock_tone(Vector3.ZERO,30.0,Vector3.UP)
	CityStone.warm()
	GiantStone.warm()
	_computed()

func build_cost() -> int:
	return 0 if grey() else 1000

var pieces := {}

func build(into: Node3D) -> void:
	if grey():
		super.build(into)
		return
	art = into
	var began := Time.get_ticks_msec()
	var root := Node3D.new()
	root.name = "HaulWay"
	into.add_child(root)
	pieces.clear()
	var a: Dictionary = LAYOUT.a
	var land_a := KitLand.island({"outline":a.outline,"seed":int(a.seed),"ground":func(x: float, z: float) -> float: return a_ground(x,z),
		"top":floor_a(),"depth":float(a.depth),"hang":true,"resample":[60.0,220,48],"cell":2.0,"fine":1.0,"cliffs":Rect2(-54.0,-32.0,60.0,64.0),
		"fine_box":Rect2(-40.0,-28.0,46.0,56.0),"cliff_drop":0.55,"stable":true,"tone":KitLook.turf(int(a.seed),KitLand.wear_of(paths()))})
	land_a.name = "QuarryShore"
	var b: Dictionary = LAYOUT.b
	var land_b := KitLand.island({"outline":b.outline,"seed":int(b.seed),"ground":func(x: float, z: float) -> float: return b_ground(x,z),
		"top":floor_b(),"depth":float(b.depth),"hang":true,"resample":[60.0,200,48],"cell":2.0,"fine":1.2,"cliffs":Rect2(140.0,-18.0,54.0,56.0),
		"fine_box":Rect2(142.0,-16.0,30.0,50.0),"cliff_drop":0.55,"stable":true,"tone":KitLook.turf(int(b.seed),KitLand.wear_of(paths()))})
	land_b.name = "FarShore"
	for land: Node3D in [land_a,land_b]:
		_collide_sides(land)
		root.add_child(land)
		turf(land)
	pieces.quarry = land_a
	pieces.far = land_b
	_house(root,"HaulHouseA",LAYOUT.house_a,lintel_a(),floor_a(),true)
	_house(root,"HaulHouseB",LAYOUT.house_b,lintel_b(),floor_b(),false)
	_hawsers(root)
	_pier(root)
	_stones(root)
	_roots(root)
	root.set_meta("triangles",_triangles())
	built_ms = Time.get_ticks_msec()-began

## An island's hanging sides collided as drawn (gb_serpent_crossing's).
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

## A haul-house: the lintel across the slot (its ends on the shoulders), two
## colossus columns of stacked drums against the cut faces under it, the
## hawsers' anchor bosses in its gulf face. Its corner broken off and lying at a column's foot.
func _house(root: Node3D, node_name: String, d: Dictionary, lintel: Vector2, ground: float, is_a: bool) -> void:
	var g: RefCounted = GiantStone.mesher()
	var body := StaticBody3D.new()
	body.name = node_name+"Solid"
	var x := float(d.x)
	var hx := float(d.half_x)
	var zs: Vector2 = d.z
	var mid_y := (lintel.x+lintel.y)*0.5
	var tall := lintel.y-lintel.x
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED+hash(node_name)
	var fallen := bool(d.get("fallen",false))
	if not fallen:
		# The lintel in three stones (a seam either side of the slot), one
		# end's corner gone.
		var cuts := [zs.x,-7.8,7.8,zs.y]
		for k in 3:
			var z0 := float(cuts[k])
			var z1 := float(cuts[k+1])
			var drop := 0.0 if k != 2 else 0.06
			var size := Vector3(hx*2.0,tall,z1-z0-0.06)
			var xf := Transform3D(Basis(Vector3.RIGHT,deg_to_rad(0.6*(k-1))),Vector3(x,mid_y-drop,(z0+z1)*0.5))
			g.box(xf,size,0.22,lintel.x-0.5,0.92+0.06*k)
		_shape(body,Vector3(hx*2.0,tall,zs.y-zs.x),Transform3D(Basis.IDENTITY,Vector3(x,mid_y,(zs.x+zs.y)*0.5)))
		var cx := x+3.0
		var cy := b_ground(cx,12.2)
		g.box(Transform3D(Basis.from_euler(Vector3(0.4,0.7,0.2)),Vector3(cx,cy+0.5,12.2)),Vector3(1.6,1.2,1.9),0.18,cy-0.3,0.88)
	else:
		# A's beam is down: it broke and fell, its halves lying across the
		# south shoulder and the pit's edge. Each hawser's anchor is a column
		# of its own now, a capital on each (the north one corbelled out to
		# the haul road's rib); the rim in sees the hawsers run out between.
		for b: Array in d.fallen_beam:
			var at: Vector2 = b[0]
			var size: Vector3 = b[1]
			var gy := a_ground(at.x,at.y)
			var bb := Basis.from_euler(Vector3(deg_to_rad(float(b[3])),deg_to_rad(float(b[2])),deg_to_rad(float(b[4]))),EULER_ORDER_YXZ)
			var xf := Transform3D(bb,Vector3(at.x,gy+size.y*0.5-float(b[5]),at.y))
			g.box(xf,size,0.25,gy-0.4,0.9)
			var c := CollisionShape3D.new()
			var sh := BoxShape3D.new()
			sh.size = size
			c.shape = sh
			c.transform = xf
			body.add_child(c)
		for cap: Array in d.caps:
			var cz: Vector2 = cap[0]
			var size := Vector3(hx*2.0,tall,cz.y-cz.x)
			var xf := Transform3D(Basis.IDENTITY,Vector3(x,mid_y,(cz.x+cz.y)*0.5))
			g.box(xf,size,0.22,lintel.x-0.5,0.95)
			_shape(body,size,xf)
	# The columns: drums to the lintel's underside, a seam each, one drum
	# shifted (an old quake).
	for cz: float in d.columns:
		var r := float(d.radius)
		var y := ground-0.6
		var n := 0
		while y < lintel.x-0.05:
			var h := minf(rng.randf_range(1.5,2.1),lintel.x-y)
			var shift := Vector3(rng.randf_range(-0.12,0.12),0.0,rng.randf_range(-0.12,0.12)) if n % 2 == 1 else Vector3.ZERO
			g.cylinder(Transform3D(Basis(Vector3.UP,rng.randf()*TAU),Vector3(x,y+h*0.5,cz)+shift),r-0.04*(n%2),h-0.05,14,0.1,ground-0.5,0.9+0.05*(n%3))
			y += h
			n += 1
		var c := CollisionShape3D.new()
		var cs := CylinderShape3D.new()
		cs.radius = r
		cs.height = lintel.x-ground+0.6
		c.shape = cs
		c.position = Vector3(x,(lintel.x+ground-0.6)*0.5,cz)
		body.add_child(c)
	# The anchor bosses where each hawser goes into the lintel's gulf face.
	var face := 1.0 if is_a else -1.0
	for hzz: float in LAYOUT.hawser.z:
		var at := Vector3(x+face*(hx+0.25),cable_y(x)+0.0,hzz)
		g.box(Transform3D(Basis.IDENTITY,at),Vector3(0.5,2.8,2.8),0.2,NAN,0.85)
	# (The card's tally of slabs on the landward face waits for the city's
	# dead rune bands: GiantStone's runes glow, too bright for the city.)
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	mesh.mesh = GiantStone.mesh_of(g)
	mesh.set_meta("triangles",g.triangles())
	root.add_child(mesh)
	root.add_child(body)
	pieces[node_name] = mesh

## The two hawsers: links of drum-stone (a fat drum and a neck, turned along
## the line), their backs collided flat at the crest, a walk `walk` m wide
## (the rail slide: PilotMotor reads a narrow slope along its way).
## Polish: weathered (some drums spalled: smaller, fewer faces, a paler
## fresh break; moss on their tops, GiantStone's), and drawn in runs of
## `CHUNK` links, each with a far stand-in (one plain tube a link, no neck)
## past `FAR_LINKS` m (visibility ranges).
const CHUNK := 8
const FAR_LINKS := 70.0
func _hawsers(root: Node3D) -> void:
	var h: Dictionary = LAYOUT.hawser
	var body := StaticBody3D.new()
	body.name = "HawsersSolid"
	var r := float(h.radius)
	var walk := float(h.walk)
	var x0 := float(LAYOUT.house_a.x)+float(LAYOUT.house_a.half_x)
	var x1 := float(LAYOUT.house_b.x)-float(LAYOUT.house_b.half_x)
	var link := float(h.link)
	var n := int(ceil((x1-x0)/link))
	var step := (x1-x0)/n
	var holder := Node3D.new()
	holder.name = "Hawsers"
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED+20
	var tris := 0
	var k := 0
	for z: float in h.z:
		var g: RefCounted = null
		var far: RefCounted = null
		for i in n:
			if i % CHUNK == 0:
				g = GiantStone.mesher()
				far = GiantStone.mesher()
			var xa := x0+i*step
			var xb := xa+step
			var pa := Vector3(xa,cable_y(xa),z)
			var pb := Vector3(xb,cable_y(xb),z)
			var along := (pb-pa).normalized()
			var side := Vector3(0.0,0.0,1.0)
			var up := side.cross(along).normalized()
			if up.y < 0.0: up = -up
			var mid := (pa+pb)*0.5
			# Drawn: the drum (axis along the line) and the neck to the next.
			var axis := Basis(along.cross(side).normalized(),along,side)
			var ax := axis.orthonormalized()
			var flip := Basis(side,PI)*ax
			var spin := Basis(along,rng.randf()*TAU)
			var wob := 0.06*sin(i*1.7+k)
			var drum := step*0.78
			var tone := 0.86+0.08*sin(i*0.9+k)
			# Each drum in two halves, back to back, so both its faces are
			# capped; now and then a half spalled (smaller, cruder, paler).
			for hf in 2:
				var b: Basis = (ax if hf == 0 else flip)
				var at := mid+along*drum*0.25*(1.0 if hf == 0 else -1.0)
				if rng.randf() < 0.22:
					g.cylinder(Transform3D(spin*b,at),(r+wob)*rng.randf_range(0.86,0.93),drum*0.5,9,0.22,NAN,tone*1.08)
				else:
					g.cylinder(Transform3D(b,at),r+wob,drum*0.5,12,0.16,NAN,tone)
			g.cylinder(Transform3D(ax,mid),r*0.74,step+0.04,10,0.05,NAN,0.8)
			# Far: one plain tube the link's length.
			far.cylinder(Transform3D(ax,mid),r*0.95,step+0.02,7,0.0,NAN,tone*0.95)
			# Collided: a slab under the crest, its top the walk.
			var c := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = Vector3(walk,1.6,pa.distance_to(pb)+0.06)
			c.shape = bs
			c.transform = Transform3D(Basis(along.cross(up).normalized(),up,-along).orthonormalized(),mid+up*(r-0.8))
			body.add_child(c)
			if i % CHUNK == CHUNK-1 or i == n-1:
				var near := MeshInstance3D.new()
				near.name = "Run%d_%d" % [k,i/CHUNK]
				near.mesh = GiantStone.mesh_of(g)
				near.visibility_range_end = FAR_LINKS
				near.visibility_range_end_margin = 8.0
				holder.add_child(near)
				var fm := MeshInstance3D.new()
				fm.name = "Far%d_%d" % [k,i/CHUNK]
				fm.mesh = GiantStone.mesh_of(far)
				fm.visibility_range_begin = FAR_LINKS
				fm.visibility_range_begin_margin = 8.0
				holder.add_child(fm)
				tris += int(g.triangles())
				holder.set_meta("far_triangles",int(holder.get_meta("far_triangles",0))+int(far.triangles()))
		k += 1
	holder.set_meta("triangles",tris)
	root.add_child(holder)
	root.add_child(body)
	pieces.hawsers = holder

## The relay pier: a drum shaft out of the haze, a collar ring a little
## under the decks' tops, the capital a step over them (its long way along
## the line), the capstan on it with four spokes.
func _pier(root: Node3D) -> void:
	var p: Dictionary = LAYOUT.pier
	var g: RefCounted = GiantStone.mesher()
	var body := StaticBody3D.new()
	body.name = "PierSolid"
	var x := float(p.x)
	var top := pier_top()
	var hp: Vector2 = p.half
	var th := float(p.thick)
	var r := float(p.shaft)
	var lo := float(LAYOUT.floor)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED+30
	var y := lo
	var n := 0
	while y < top-th-0.05:
		var hh := minf(rng.randf_range(3.0,4.2),top-th-y)
		g.cylinder(Transform3D(Basis(Vector3.UP,rng.randf()*TAU),Vector3(x,y+hh*0.5,0.0)),r-0.05*(n%2),hh-0.06,14,0.12,NAN,0.86+0.05*(n%3))
		y += hh
		n += 1
	var sc := CollisionShape3D.new()
	var cs := CylinderShape3D.new()
	cs.radius = r
	cs.height = top-th-lo
	sc.shape = cs
	sc.position = Vector3(x,(lo+top-th)*0.5,0.0)
	body.add_child(sc)
	# Its root (drawn only, out of every reach): stepped courses widening
	# down into the haze from well under the decks, the city's massing.
	var foot := deck_top(x)-float(p.root_under)
	var rr := r
	for k in 6:
		rr = r+1.2*(k+1)
		var y1 := foot-3.4*k
		g.cylinder(Transform3D(Basis(Vector3.UP,k*0.4),Vector3(x,y1-1.7,0.0)),rr,3.4,8,0.25,NAN,0.8+0.04*(k%2))
	var bottom := foot-3.4*6.0
	g.cylinder(Transform3D(Basis(Vector3.UP,0.2),Vector3(x,(bottom+lo)*0.5,0.0)),rr,bottom-lo,8,0.25,NAN,0.78)
	# The collar ring (drawn), between the decks. Polish: weathered, in
	# eight stones, one fallen out, one slumped, their joints open.
	var cy := top-th-1.6
	for k in 8:
		if k == 5: continue
		var a := TAU*(k+0.5)/8.0
		var drop := 0.28 if k == 2 else 0.0
		var tilt := Basis(Vector3.UP,-a)*Basis(Vector3.RIGHT,deg_to_rad(9.0 if k == 2 else rng.randf_range(-2.0,2.0)))
		g.box(Transform3D(tilt,Vector3(x+cos(a)*(r+0.2),cy-drop,sin(a)*(r+0.2))),Vector3(0.75,1.0,r*0.72),0.14,NAN,0.74+0.08*float(k%3))
	# The capital: two stones, the east one sunk a little (cracked off).
	g.box(Transform3D(Basis.IDENTITY,Vector3(x-hp.x*0.5,top-th*0.5,0.0)),Vector3(hp.x-0.05,th,hp.y*2.0),0.2,NAN,0.95)
	g.box(Transform3D(Basis(Vector3.FORWARD,deg_to_rad(1.5)),Vector3(x+hp.x*0.5,top-th*0.5-0.05,0.0)),Vector3(hp.x-0.05,th,hp.y*2.0-0.1),0.2,NAN,0.9)
	_shape(body,Vector3(hp.x*2.0,th,hp.y*2.0),Transform3D(Basis.IDENTITY,Vector3(x,top-th*0.5,0.0)))
	# The capstan and its spokes.
	var cap := float(p.capstan)
	g.cylinder(Transform3D(Basis.IDENTITY,Vector3(x,top+0.5,0.0)),cap,1.0,14,0.15,top,0.88)
	g.cylinder(Transform3D(Basis.IDENTITY,Vector3(x,top+1.1,0.0)),cap*0.75,0.25,14,0.08,top,0.8)
	# Its spokes (polish: one snapped short, one gone, its socket empty).
	for s in 4:
		if s == 3: continue
		var b := Basis(Vector3.UP,s*PI*0.25+0.3)
		var long := 3.6 if s != 1 else 2.3
		var shift := 0.0 if s != 1 else 0.65
		g.box(Transform3D(b,Vector3(x,top+0.75,0.0)+b*Vector3(shift,0.0,0.0)),Vector3(long,0.28,0.32),0.06,top,0.78)
	g.box(Transform3D(Basis(Vector3.UP,0.5),Vector3(x+2.6,top+0.12,1.2)),Vector3(1.1,0.24,0.3),0.05,top,0.72)
	var cc := CollisionShape3D.new()
	var ccs := CylinderShape3D.new()
	ccs.radius = cap
	ccs.height = 1.0
	cc.shape = ccs
	cc.position = Vector3(x,top+0.5,0.0)
	body.add_child(cc)
	var mesh := MeshInstance3D.new()
	mesh.name = "RelayPier"
	mesh.mesh = GiantStone.mesh_of(g)
	mesh.set_meta("triangles",g.triangles())
	root.add_child(mesh)
	root.add_child(body)
	pieces.pier = mesh

## The quarry's stone and B's unloaded slab (LAYOUT `stones`).
func _stones(root: Node3D) -> void:
	var g: RefCounted = GiantStone.mesher()
	var body := StaticBody3D.new()
	body.name = "QuarryStoneSolid"
	for st: Array in LAYOUT.stones:
		var x := float(st[1])
		var z := float(st[2])
		var y := a_ground(x,z) if x < 74.0 else b_ground(x,z)
		if st[0] in ["slab","split","brow"]:
			_worked(g,body,st,x,z,y)
			continue
		var c := CollisionShape3D.new()
		if st[0] == "block":
			var size: Vector3 = st[3]
			var bb := Basis.from_euler(Vector3(deg_to_rad(float(st[5])),deg_to_rad(float(st[4])),deg_to_rad(float(st[6]))),EULER_ORDER_YXZ)
			var xf := Transform3D(bb,Vector3(x,y+size.y*0.5-float(st[7]),z))
			g.box(xf,size,clampf(minf(size.x,minf(size.y,size.z))*0.12,0.06,0.3),y-0.4,0.9+0.2*fmod(absf(x*0.37+z*0.11),1.0))
			var shape := BoxShape3D.new()
			shape.size = size
			c.shape = shape
			c.transform = xf
		else:
			var r := float(st[3])
			var length := float(st[4])
			var bb := Basis(Vector3.UP,deg_to_rad(float(st[5])))*Basis(Vector3.BACK,PI*0.5)
			var xf := Transform3D(bb,Vector3(x,y+r-float(st[6]),z))
			g.cylinder(xf,r,length,14,0.14,y-0.4,0.95)
			var shape := CylinderShape3D.new()
			shape.radius = r
			shape.height = length
			c.shape = shape
			c.transform = xf
		body.add_child(c)
	# The far lamp's plinth on B's knoll, two courses, the top one shifted.
	var bc: Vector2 = LAYOUT.b.beacon
	var by := b_ground(bc.x,bc.y)
	for k in 2:
		var size := Vector3(2.6-0.6*k,KNOLL_PLINTH*0.5+(0.5 if k == 0 else 0.0),2.6-0.6*k)
		var yy := by-0.5+(0.0 if k == 0 else KNOLL_PLINTH*0.5+0.5)
		var xf := Transform3D(Basis(Vector3.UP,0.6+0.12*k),Vector3(bc.x+0.08*k,yy+size.y*0.5,bc.y))
		g.box(xf,size,0.14,by-0.4,0.9)
		_shape(body,size,xf)
	var mesh := MeshInstance3D.new()
	mesh.name = "QuarryStone"
	mesh.mesh = GiantStone.mesh_of(g)
	mesh.set_meta("triangles",g.triangles())
	root.add_child(mesh)
	root.add_child(body)
	pieces.stones = mesh

## Polish: the quarry's worked stone (LAYOUT `stones`):
##   slab   a great block half-dressed: its dressed part, and at one end
##          the rough rock it was cut from (lumps, unworked), sunk and tilted
##   split  a block split in two by wedges: the halves a `gap` apart,
##          splayed, the wedges still standing in the split
##   brow   a dressed piece of a great head laid on the turf: a block with
##          a brow's ridge along its face
func _worked(g: RefCounted, body: StaticBody3D, st: Array, x: float, z: float, y: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED+int(x*13.0+z*7.0)
	match str(st[0]):
		"slab":
			var size: Vector3 = st[3]
			var bb := Basis.from_euler(Vector3(deg_to_rad(float(st[5])),deg_to_rad(float(st[4])),deg_to_rad(float(st[6]))),EULER_ORDER_YXZ)
			var at := Vector3(x,y+size.y*0.5-float(st[7]),z)
			var dressed := Vector3(size.x*0.7,size.y,size.z)
			var xf := Transform3D(bb,at+bb*Vector3(-size.x*0.15,0.0,0.0))
			g.box(xf,dressed,0.12,y-0.4,1.0)
			_shape(body,dressed,xf)
			# The rough end: lumps of the rock it came out of.
			for k in 5:
				var lump := Vector3(rng.randf_range(0.9,1.5),size.y*rng.randf_range(0.6,1.0),size.z*rng.randf_range(0.3,0.55))
				var off := Vector3(size.x*0.2+rng.randf_range(0.0,size.x*0.22),rng.randf_range(-0.3,0.15),(k-2)*size.z*0.2)
				var lb := bb*Basis.from_euler(Vector3(rng.randf_range(-0.2,0.2),rng.randf_range(-0.4,0.4),rng.randf_range(-0.2,0.2)))
				g.box(Transform3D(lb,at+bb*off),lump,0.3,y-0.4,0.86)
			var rough := Vector3(size.x*0.3,size.y*0.85,size.z*0.9)
			_shape(body,rough,Transform3D(bb,at+bb*Vector3(size.x*0.33,-0.1,0.0)))
		"split":
			var size: Vector3 = st[3]
			var gap := float(st[6])
			var yaw := deg_to_rad(float(st[4]))
			var half := Vector3(size.x*0.5-gap*0.5,size.y,size.z)
			for sx: float in [-1.0,1.0]:
				# Each half splayed off the split a few degrees.
				var bb := Basis(Vector3.UP,yaw)*Basis(Vector3.FORWARD,sx*deg_to_rad(rng.randf_range(2.0,5.0)))
				var xf := Transform3D(bb,Vector3(x,y+size.y*0.5-float(st[5]),z)+Basis(Vector3.UP,yaw)*Vector3(sx*(half.x*0.5+gap*0.5),0.0,0.0))
				g.box(xf,half,0.1,y-0.4,0.95)
				_shape(body,half,xf)
			# The wedges standing in the split, their heads proud.
			var top := y+size.y-float(st[5])
			for k in 3:
				var wz := (k-1)*size.z*0.3
				g.box(Transform3D(Basis(Vector3.UP,yaw),Vector3(x,top+0.05,z)+Basis(Vector3.UP,yaw)*Vector3(0.0,0.0,wz)),Vector3(gap*0.9,0.4,0.28),0.03,top-0.3,0.62)
		"brow":
			var yaw := deg_to_rad(float(st[3]))
			var bb := Basis.from_euler(Vector3(deg_to_rad(float(st[5])),yaw,deg_to_rad(float(st[6]))),EULER_ORDER_YXZ)
			var size := Vector3(3.3,1.5,3.0)
			var at := Vector3(x,y+size.y*0.5-float(st[4]),z)
			var xf := Transform3D(bb,at)
			g.box(xf,size,0.2,y-0.4,1.0)
			# The brow: a heavy ridge along its east face, a furrow under it.
			g.box(Transform3D(bb,at+bb*Vector3(1.25,0.75,0.0)),Vector3(0.9,0.45,2.8),0.16,y,0.96)
			g.box(Transform3D(bb,at+bb*Vector3(1.55,0.25,0.0)),Vector3(0.4,0.25,2.5),0.08,y,0.7)
			_shape(body,size,xf)

## Polish: roots (the kit's HangingRoots) from under both shores' turf
## lips (not the cradles' mouths), from the relay pier's capital ends, its
## collar and its stepped root down into the haze.
func _roots(root: Node3D) -> void:
	var all: Array = []
	for shore: Array in [[LAYOUT.a.outline,func(x: float, z: float) -> float: return a_ground(x,z),SEED+90],[LAYOUT.b.outline,func(x: float, z: float) -> float: return b_ground(x,z),SEED+91]]:
		var ring: Array = shore[0]
		# Outward is to the right as walked on a clockwise ring (x east, z south).
		var area := 0.0
		for k in ring.size(): area += (ring[k] as Vector2).cross(ring[(k+1)%ring.size()])
		all.append_array(HangingRoots.along(ring,shore[1],6.0,Vector2(2.0,9.0),-0.5 if area > 0.0 else 0.5,int(shore[2])))
	var p: Dictionary = LAYOUT.pier
	var px := float(p.x)
	var top := pier_top()
	var th := float(p.thick)
	var hp: Vector2 = p.half
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED+92
	# The capital's ends (east and west), kept off the decks' lanes.
	for sx: float in [-1.0,1.0]:
		for k in 3:
			all.append(Vector4(px+sx*(hp.x+0.15),top-th+0.1,rng.randf_range(-hp.y+0.6,hp.y-0.6),rng.randf_range(1.5,4.5)))
	# The collar ring, down the shaft.
	var r := float(p.shaft)
	for k in 8:
		var a := TAU*k/8.0+rng.randf_range(-0.2,0.2)
		all.append(Vector4(px+cos(a)*(r+0.5),top-th-2.0,sin(a)*(r+0.5),rng.randf_range(2.0,6.0)))
	# The stepped root's courses, long into the haze.
	var foot := deck_top(px)-float(p.root_under)
	for c in 6:
		var rr := r+1.2*(c+1)
		var n := 4+c
		for k in n:
			var a := TAU*k/n+rng.randf_range(-0.25,0.25)+c*0.4
			all.append(Vector4(px+cos(a)*(rr+0.1),foot-3.4*c-0.2,sin(a)*(rr+0.1),rng.randf_range(3.0,13.0)))
	var batch := HangingRoots.batch(all,SEED+93)
	root.add_child(batch)
	batch.set_meta("triangles",all.size()*HangingRoots.triangles())
	pieces.roots = batch

static func _shape(body: StaticBody3D, size: Vector3, xf: Transform3D) -> void:
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	c.shape = s
	c.transform = xf
	body.add_child(c)

func _triangles() -> int:
	var n := 0
	for p: Variant in pieces.values():
		if p is Node3D: n += int((p as Node3D).get_meta("triangles",0))
	return n

# --- What moves --------------------------------------------------------------------------

## The machine (the two sledges, the fenders, the chocks, the jolts), the
## lamps on the lintels and the pier, the Olmecs, the yard's far pillars.
var machine: Node3D = null

func live(g: Node) -> void:
	# STAND-IN (gb_serpent_crossing's): the yard's ground swap leaves the
	# motor without `mover`; wired again to the ground in use, so it rides
	# the sledges (moving ground).
	var study: Node = g.stage.study
	var motor: Variant = study.get("motor")
	var ground: Variant = study.get("ground")
	if motor != null and ground != null:
		if not (motor.mover as Callable).is_valid(): motor.mover = ground.mover_callable()
		if not (motor.soft as Callable).is_valid(): motor.soft = ground.soft_callable()
	machine = Machine.new()
	machine.name = "HaulMachine"
	g.add_child(machine)
	machine.setup(self,study,g.w(Vector3.ZERO))
	var fires := Node3D.new()
	fires.name = "Fires"
	g.add_child(fires)
	var la := lintel_a()
	var lb := lintel_b()
	var p: Dictionary = LAYOUT.pier
	var k := 0
	for at: Vector3 in [Vector3(-1.0,la.y,-5.9),Vector3(float(LAYOUT.house_b.x)+0.6,lb.y,9.6),Vector3(float(p.x)+3.6,pier_top(),-1.4)]:
		var lamp: Node3D = CityFires.cresset(fires,Transform3D(Basis.IDENTITY,g.w(at)),{"size":"crown","seed":SEED+40+k,"name":"HaulLamp%d" % k,"lit":true,"barge":false,"beam":LAMP_BEAM})
		SC._still(lamp)
		k += 1
	# B's lamp on its knoll (lit since ever): the far shore read from A.
	# Polish: a dim cresset on a low plinth, not a beacon tower's blaze.
	var bc: Vector2 = LAYOUT.b.beacon
	if grey():
		var tower: Node3D = CityFires.tower(fires,Transform3D(Basis(Vector3.UP,0.6),g.w(Vector3(bc.x,b_ground(bc.x,bc.y)-0.4,bc.y))),{"seed":SEED+50,"name":"FarBeacon","lit":true,"tiers":2,"beam":3.0})
		SC._still(tower)
	else:
		var top := b_ground(bc.x,bc.y)+KNOLL_PLINTH
		var far_lamp: Node3D = CityFires.cresset(fires,Transform3D(Basis(Vector3.UP,0.6),g.w(Vector3(bc.x,top,bc.y))),{"size":"crown","seed":SEED+50,"name":"FarBeacon","lit":true,"barge":false,"beam":LAMP_BEAM*1.3})
		SC._still(far_lamp)
	var args := preload("res://scripts/launch_args.gd").user_args()
	var yard := str(study.get_script().resource_path).ends_with("motif_yard.gd")
	if yard: _far(g)
	if args.has("--no-olmec"): return
	var hub: Node3D = Breakables.new()
	hub.field = g.stage.enemies
	g.add_child(hub)
	# STAND-IN for the card's riders (headless_body can't ride a moving
	# deck): a whole Olmec waits on the pier's capital, chase on; as a deck
	# passes with him on it, it pounces down onto it (and the deck goes on
	# without it). A second walks B's terrace past the cradle, so the
	# arrival is contested.
	# In a generated layer the roaming Olmec comes instead (olmec-threat-
	# round1.md; `--knob=olmecs=places` brings the riders back).
	if OlmecPlaces.keepers(g):
		var ol: Dictionary = LAYOUT.olmecs
		_olmec(g,hub,ol.pier,pier_top(),Vector2(0.0,1.0),SEED+60)
		# (B's walks the terrace past the cradle, its feet on the turf there.)
		var bp: Vector2 = ol.b[1]
		_olmec(g,hub,ol.b,b_ground(bp.x,bp.y),Vector2(-1.0,0.0),SEED+61)

## The lamps' beam (dim and warm: the city's cressets, turned down).
const LAMP_BEAM := 1.5
## The far lamp's plinth on B's knoll (m over the turf; drawn in `_stones`).
const KNOLL_PLINTH := 1.6

func _olmec(g: Node, hub: Node3D, beat_xz: Array, y: float, face: Vector2, s: int) -> void:
	var beat: Array[Vector3] = []
	for q: Vector2 in beat_xz: beat.append(g.w(Vector3(q.x,y,q.y)))
	var post: Vector3 = beat[1]
	var body: Node3D = g.enemy(HeadlessBody,post+Vector3.UP*0.1,face,{"chase":1,"chase_routes":1,"seed":s})
	var head: Node3D = g.enemy(InhalerHead,post+Vector3.UP*0.1,face,{})
	# (The Lamplighters' Keeper: the Stacked Court's, its refind safe for
	# bodies freed by a fall or a reset.)
	var keeper: Node = preload("res://scripts/kit_isle/greybox/gb_lamplighters_stair.gd").Keeper.new()
	keeper.name = "Rider_STANDIN_%d" % s
	keeper.beat = beat
	keeper.post = post
	keeper.field = g.stage.enemies
	keeper.hub = hub
	keeper.wear(body,head)
	g.add_child(keeper)

## Alone in the yard: far pillar crowns in the haze under and beyond the
## gulf (drawn only), a lit tower on two.
func _far(g: Node) -> void:
	var far := Node3D.new()
	far.name = "FarLayers"
	g.add_child(far)
	var k := 0
	for f: Array in LAYOUT.far_pillars:
		var crown := float(f[2])
		var at: Vector3 = g.w(Vector3(float(f[0]),crown,float(f[1])))
		var pl := CityKit.pillar(SEED+70+k,0.7,{"apothem":float(f[3]),"courses":2,"climb":-1,"crown":"paved","depth":maxf(crown-float(LAYOUT.floor)-40.0,18.0)})
		pl.position = at
		for nd: Node in pl.find_children("*","CollisionObject3D",true,false): (nd as CollisionObject3D).collision_layer = 0
		far.add_child(pl)
		if k % 2 == 0:
			var t: Node3D = CityFires.tower(far,Transform3D(Basis(Vector3.UP,k*1.3),at+Vector3(float(f[3])*0.3,2.0*SO,0.0)),{"tiers":2,"base":9.0,"steps":false,"lit":true,"seed":SEED+80+k,"name":"FarTower%d" % k,"beam":3.0})
			SC._still(t)
		k += 1
