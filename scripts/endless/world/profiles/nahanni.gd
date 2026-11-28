extends "res://scripts/endless/world/profiles/wilderness.gd"
## Nahanni (--world=nahanni): an experiment in a second map. One placed
## valley that slopes the whole way: it starts as a pass high in a ring of
## giant mountains (in place of the wilderness's sea), winds down into an
## open field, and branches there into two valleys that run on down to lakes
## under the far wall; a side valley joins it part-way. No tiers or walls:
## the land climbs off every floor in one eased slope (LandField `_vale`).
## It starts from wilderness's tables; none of wilderness's placed
## content (sites, finds) is keyed to this id.

## The valleys, each a line of [x, z, the floor's height (m over the sea),
## its half-width (m), the rock wall on its left and on its right (0 a
## gentle side .. 1 a full wall), the spurs' share (0 none .. 0.6: rock ribs
## reaching into the floor from each side in turn, and knolls on the floor)],
## from the top down; `_curve` rounds them. The floor is kept changing:
## narrows between walls, steps where it drops fast, wide stretches with
## spurs to weave through.
const MAIN := [[150,4700,470,90,0.8,0.8,0.0],[-80,4000,400,110,0.3,0.6,0.2],[-430,3450,352,70,1.0,1.0,0.0],[-380,3050,300,60,1.0,0.7,0.0],
	[-60,2700,285,190,0.0,0.3,0.5],[160,2350,265,170,0.2,0.0,0.5],[420,2000,240,75,1.0,1.0,0.0],[560,1650,198,200,0.5,0.0,0.4],
	[430,1100,172,400,0.0,0.2,0.3],[250,650,148,430,0.0,0.0,0.0],[0,250,130,520,0.0,0.0,0.0],[0,-250,122,520,0.0,0.0,0.0]]
const WEST := [[0,-250,122,520,0.0,0.0,0.0],[-700,-700,105,200,0.0,0.4,0.4],[-1300,-1300,80,90,1.0,1.0,0.0],[-1100,-2100,46,170,0.3,0.0,0.5],
	[-1900,-2700,22,220,0.0,0.0,0.3],[-2500,-3200,-14,380,0.0,0.0,0.0],[-2700,-3500,-16,380,0.0,0.0,0.0]]
const EAST := [[0,-250,122,520,0.0,0.0,0.0],[800,-600,104,190,0.4,0.0,0.4],[1500,-700,84,80,1.0,1.0,0.0],[2100,-1400,50,170,0.0,0.5,0.5],
	[2000,-2200,30,200,0.0,0.0,0.3],[2700,-2900,-14,380,0.0,0.0,0.0],[2950,-3200,-16,380,0.0,0.0,0.0]]
const SIDE := [[-2700,2200,430,100,0.5,0.5,0.3],[-1750,2550,365,110,0.0,0.6,0.4],[-850,2300,305,80,1.0,1.0,0.0],[150,2380,266,150,0.0,0.0,0.0]]
## The wedge above the field: a tongue of land to ride up from its tail
## [x, z] to its tip [x, z], this tall and this wide (half) at the tip, where
## it breaks off in a cliff over the field; the river passes to its east, a
## tight way to its west.
const WEDGE := [330.0,1500.0,-20.0,640.0,95.0,110.0]
## A curve's points stand this far apart (m).
const STEP := 80.0

func _init() -> void:
	super()
	id = "nahanni"
	title = "Nahanni"
	var vale := PackedFloat32Array()
	for line: Array in [MAIN,WEST,EAST,SIDE]: vale.append_array(_curve(line))
	land.merge({
		# The land off the valleys: rolling, the ranges tall on the high ground
		# between them; no tiers, and none of the noise's own valleys (so none of their rivers).
		"continent_lift":34.0,"continent_swing":40.0,"hill_tall":20.0,"peak_tall":Vector2(160.0,300.0),"snow":800.0,
		"valleys":0.0,
		# The placed valleys: the land climbs 0.32 m a metre off a floor, eased
		# in over 350 m; the lines wander 110 m by the warp noise.
		"vale":vale,"vale_slope":0.32,"vale_ease":350.0,"vale_keep":0.1,"vale_warp":110.0,"vale_river":9.0,"vale_wall":70.0,"vale_knoll":26.0,"vale_wedge":PackedFloat32Array(WEDGE),
		# The edge: no sea. The land climbs rim_tall m into a ring of mountains
		# from rim_ramp m short of the line (LandField `_rim`).
		"coast_x":0.0,"coast_z":0.0,"coast_half":5600.0,"coast_corner":3200.0,"coast_ramp":1400.0,"coast_depth":0.0,"coast_wobble":450.0,
		"rim_tall":1500.0,"rim_ramp":2600.0},true)
	# The woods a little thinner, and up the slopes to a tree line moved up with the land.
	flora["forest"] = 0.5
	flora["tree_line"] = Vector2(430.0,560.0)
	# The paint's heights (m over the sea) moved up with the land: turf up the
	# valley sides, bare stone and snow only on the rim.
	paint["alpine_lift"] = 480.0
	(paint.ground as Dictionary).merge({"alpine_lift":480.0,"turf_high":Vector2(380.0,540.0),"alpine_stone":Vector2(430.0,720.0),"summit_snow":Vector2(700.0,950.0)},true)
	layers = {"trees":true,"grass":true,"birds":true,"fish":true,"tunnels":0.0,"arches":0.0,"splits":0.0,"stacks":0.0,
		"balloons":false,"whale":false,"peak":false,"traffic":-1}
	# The start: in the pass at the valley's head, facing down it.
	spawn = {"at":Vector2(-80.0,4000.0),"alt":70.0,"heading":0.0}
	# The greybox pieces on the land (scripts/endless/land_pieces.gd): a row
	# each, its piece script, its middle (x, z), its heading (degrees clockwise
	# from -z: 0 runs its length along the valley, north end downstream),
	# scale (across and along) and tall (up). The fin ridge stands in the open
	# field west of the river, its south end off the wedge's west gap, clear of
	# the pond at (-300, 220) and the west valley's mouth at (-250, -260).
	# The scarp (a change of level) crosses the west valley's lower reach wall
	# to wall, facing down it: flying up from the lake you meet its face. Its
	# middle foot is `at`; the stamp gathers the valley's climb over its reach
	# (350 m in front to 950 m behind, about 45 m there) into a cliff of about
	# 70 m (tall 0.5 of 150), the ground let down a little in front and the
	# bench falling back gently behind (scarp.gd `rise`). Its front stops short
	# of the lake (y -40). `across` narrows it to the valley (blocks and gullies
	# 0.8: gullies 56, 80, 64 m) without thinning its height.
	pieces = [
		{"piece":preload("res://scripts/pieces/fin_ridge.gd"),"at":Vector2(-170.0,150.0),"heading":0.0,"scale":1.0,"tall":1.0},
		{"piece":preload("res://scripts/pieces/scarp.gd"),"at":Vector2(-1577.0,-2504.0),"heading":125.0,"scale":1.0,"across":0.8,"along":1.0,"tall":0.5},
	]

## `line` as a Catmull-Rom curve with a point every STEP m: LandField's `vale`
## rows (x, z, floor, half-width, 1 on the line's first point, wall left,
## wall right, the way along the line so far (m), the spurs' share).
static func _curve(line: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var n := line.size()
	var way := 0.0
	var last := Vector2(float(line[0][0]),float(line[0][1]))
	for i in n-1:
		var p0: Array = line[maxi(i-1,0)]
		var p1: Array = line[i]
		var p2: Array = line[i+1]
		var p3: Array = line[mini(i+2,n-1)]
		var span := Vector2(float(p2[0])-float(p1[0]),float(p2[1])-float(p1[1])).length()
		var cuts := maxi(int(ceil(span/STEP)),1)
		for c in cuts+(1 if i == n-2 else 0):
			var t := float(c)/float(cuts)
			var v := PackedFloat32Array()
			for k in 7:
				var a := float(p0[k])
				var b := float(p1[k])
				var d := float(p2[k])
				var e := float(p3[k])
				v.append(0.5*((2.0*b)+(d-a)*t+(2.0*a-5.0*b+4.0*d-e)*t*t+(3.0*b-a-3.0*d+e)*t*t*t))
			way += Vector2(v[0],v[1]).distance_to(last)
			last = Vector2(v[0],v[1])
			out.append_array([v[0],v[1],v[2],maxf(v[3],30.0),1.0 if i == 0 and c == 0 else 0.0,clampf(v[4],0.0,1.0),clampf(v[5],0.0,1.0),way,clampf(v[6],0.0,0.6)])
	return out
