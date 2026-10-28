extends RefCounted
## The ruin kit's gothic set pieces (scripts/ruin_kit.gd: its Build, its
## weathered stone and growth): giant ruins that stand on their own in the
## land and read from a kilometre off, each with tight, precise openings to
## thread by hand.
##
## - `gothic_nave`: a ruined nave, BAYS bays long. Two rows of clustered
##   piers carry the side walls, each bay's wall pierced by a tall lancet
##   (some still split by their mullion into two knife-edge lights, some
##   torn down to a breach); stepped buttresses stand off the flanks, FLANK
##   out, their flyers leaping back to the pier heads, so a corridor runs
##   down each flank under a row of flying arches; one flank's buttresses
##   are pierced by a knife slot each, a line threaded on a wingtip. Inside,
##   the transverse ribs of the vault stand or break off, a few bays keep
##   their webbing (a dim pointed barrel, holed), the rest are open to the
##   sky over drifts of fallen vault. In at the west portal (+Z), down the
##   nave through the choir screen's arch, out at the east end's great
##   lancet or one of the slits either side of it (or out a side lancet).
## - `belfry_tower`: a tall broken tower, hollow, on stepped angle
##   buttresses, a tracery window high on its front (a light of it flown,
##   out through the lancet behind) and an open belfry near the top: two
##   lights a face front and back, knife slits on the sides, the head torn
##   away over the back.
## - `rose_gate`: a standing gable, a gate in the land, its rose window
##   (spokes fallen) the round opening flown through, a knife slot down
##   each side of it in the walling.
##
## The openings: each piece's flown openings are data (`openings`), in the
## piece's frame, drawn from the same plan as the stone (`plan`), so a
## placer or a flyability check reads them without building it. Their
## widths come from toy widths named here through `WorldScale.opening`, the
## knife slots from `WorldScale.knife()`.
##
## Every piece, as the kit's: a Node3D, its foot on y 0 round the origin,
## its front toward +Z, "Mesh" (stone and growth, one surface) and "Body"
## (each block's hull, so collision is what is drawn). Built lean (the
## halls' cheap stone, long blocks in deep courses) and culled, as giants
## built by the few. Meta on the root: "openings" (as `openings`), "bounds"
## (AABB), "gothic" (the plan).

const RuinKit = preload("res://scripts/ruin_kit.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const Build = RuinKit.Build

## The pieces built by id here (RuinKit GOTHIC_SET_PIECES), ids stable.
const PIECES := ["gothic_nave","belfry_tower","rose_gate"]

# --- The openings' toy widths (WorldScale.opening: x plane x ratio) ----------

## The west portal: toy 5.0 (10 m at the defaults), the nave's way in.
const TOY_PORTAL := 5.0
## A side lancet, its mullion gone: toy 3.0 (6 m, 1.6 m past each tip).
const TOY_LANCET := 3.0
## The flank's corridor between the piers and the buttresses, under the
## flyers: toy 3.0 (6 m).
const TOY_FLANK := 3.0
## The choir screen's arch: toy 3.4 (6.8 m).
const TOY_SCREEN := 3.4
## The east end's great lancet: toy 3.2 (6.4 m).
const TOY_EAST := 3.2
## The belfry's lights, front and back: toy 2.8 (5.6 m, 1.4 m past a tip).
const TOY_BELFRY := 2.8
## The tower's tracery light (its tracery broken out): toy 2.9 (5.8 m).
const TOY_TRACERY := 2.9
## The rose: toy 4.0 (8 m across).
const TOY_ROSE := 4.0

# --- The nave ----------------------------------------------------------------

## Bays, and a bay's length along Z (pier line to pier line, m).
const BAYS := 8
const BAY := 14.0
## Half the clear width between the piers' inner faces.
const NAVE_HALF := 12.0
## The piers' apothem (an octagon; four shafts on it).
const PIER_R := 1.7
## The pier line's x (either side): the wall runs on it.
const PIER_X := NAVE_HALF+PIER_R
## How far a pier's shafts and base reach out from its middle (the
## shafts' vertices), under its capital.
const PIER_REACH := PIER_R*1.36+0.3
## The side walls: half thickness, their heads, the course.
const WALL_D := 1.1
const WALL_H := 28.0
const COURSE := 1.8
## Footings: walls and piers start this far under y 0.
const FOOT := 2.0
## A side lancet: its sill, its springing (head equilateral).
const LANCET_SILL := 7.0
const LANCET_SPRING := 20.0
## The vault: ribs spring at VAULT_SPRING (over the capitals), their arc's
## radius a share of the span (a drop arch); rib depth and half width; the
## webbing's depth.
const VAULT_SPRING := 26.6
const VAULT_PITCH := 0.85
const RIB := Vector2(1.4,0.7)
const WEB := 0.8
## Buttresses: across Z (width), their stages [top, depth out], the knife
## slot through the pierced ones (from, to over the ground).
const BUTTRESS_W := 3.2
const BUTTRESS_STAGES := [[11.0,5.6],[19.0,4.6],[24.5,3.6]]
const END_STAGES := [[11.0,4.6],[19.0,3.6],[24.5,2.8]]
const SLOT_Y := Vector2(3.0,15.0)
## The flyer: its soffit leaves the buttress at FLYER.x, meets the pier
## head at FLYER.y; its depth over the soffit at the crown.
const FLYER := Vector3(17.0,24.5,1.5)
## The choir screen: its pier line; its height, the arch's springing, its
## half thickness; its sill.
const SCREEN_LINE := 6
const SCREEN := Vector3(18.0,9.0,1.5)
const SCREEN_SILL := 1.5
## The west front and east end: half thickness, the portal's springing,
## the east lancet's sill and springing, the slits' either side of it.
const END_D := 1.4
const PORTAL_SPRING := 14.0
const EAST := Vector2(6.0,21.0)
const EAST_SLIT := Vector2(8.0,19.0)
## The mullion's half width between two lights (a slit bay, the belfry).
const MULLION := 0.45
## The lane down the nave: its floor over the drifts, its height (under the
## ribs' springing). The drifts of fallen stone are at most HEAP_TOP high.
const NAVE_LANE := Vector2(4.0,20.0)
const HEAP_TOP := 3.6

## The nave's flown widths (m), read once.
static var PORTAL: float = WorldScale.opening(TOY_PORTAL)
static var LANCET: float = WorldScale.opening(TOY_LANCET)
static var FLANK: float = WorldScale.opening(TOY_FLANK)
static var SCREEN_W: float = WorldScale.opening(TOY_SCREEN)
static var EAST_W: float = WorldScale.opening(TOY_EAST)
static var KNIFE: float = WorldScale.knife()
## The buttresses' inner face (x): the flank corridor runs from the
## piers' shafts to it.
static var BUTTRESS_X: float = PIER_X+PIER_REACH+FLANK
## The nave's half length (Z): the end walls stand on its two ends.
const HALF_LEN := BAYS*BAY*0.5

# --- The belfry tower ----------------------------------------------------------

## The tower: outer half side, wall thickness, the head's height, course.
const TOWER_HALF := 8.0
const TOWER_WALL := 2.2
const TOWER_H := 80.0
const TOWER_COURSE := 1.9
## The belfry's lights: sill, springing (the slits' on the sides the same).
const BELFRY := Vector2(55.0,64.0)
## The tracery window on the front (its plain lancet behind): sill,
## springing.
const TRACERY := Vector2(33.0,44.0)
## The angle buttresses' stages [top, depth out], width.
const TOWER_STAGES := [[18.0,4.2],[34.0,3.2],[50.0,2.2]]
const TOWER_BUTTRESS_W := 3.0
static var BELFRY_W: float = WorldScale.opening(TOY_BELFRY)
static var TRACERY_W: float = WorldScale.opening(TOY_TRACERY)

# --- The rose gate ------------------------------------------------------------

## The gable: half width, its eaves, apex, half thickness; the rose's
## centre height and its ring's radial depth; the slots' sill and springing.
const GATE := Vector4(17.0,24.0,38.0,1.5)
const ROSE_Y := 20.0
const ROSE_RING := 1.6
const GATE_SLOT := Vector2(4.0,18.0)
static var ROSE: float = WorldScale.opening(TOY_ROSE)

## The piece with PIECES id `id`.
static func piece(id: String, seed_value: int, weathered := 0.6) -> Node3D:
	match id:
		"gothic_nave": return nave(seed_value,weathered)
		"belfry_tower": return belfry(seed_value,weathered)
		"rose_gate": return rose_gate(seed_value,weathered)
	return null

# --- The plan (what the stone and the openings both read) ----------------------

## The piece's plan from its seed and wear, a pure function: what stands,
## what fell, which lights keep their mullions. Its own rng (the build's
## draws the stone), so `openings` gives the same without building.
static func plan(id: String, seed_value: int, weathered := 0.6) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = hash([id,seed_value,"gothic_plan"])
	var p := {"id":id,"seed":seed_value,"weathered":weathered}
	match id:
		"gothic_nave":
			# Each side's bays: "lancet" (flown), "slit" (two knife lights),
			# "breach" (the wall torn down to a low line, the head gone).
			var sides := {}
			var low := {}
			for s: int in [-1,1]:
				var bays: Array = []
				for i in range(BAYS):
					var roll := r.randf()
					var kind := "lancet"
					if roll < 0.2: kind = "slit"
					elif roll > 0.92-0.15*weathered and i > 0 and i < BAYS-1: kind = "breach"
					bays.append(kind)
					low["%d/%d" % [s,i]] = r.randf_range(9.0,13.0)
				# One slit a side for sure.
				if not bays.has("slit"): bays[r.randi_range(1,BAYS-2)] = "slit"
				sides[s] = bays
			p["bays"] = sides
			p["breach_low"] = low
			# The vault: a bay webbed (its barrel standing, holed) or open.
			var web: Array = []
			for i in range(BAYS):
				web.append(i >= BAYS-3 and i != SCREEN_LINE-1 and r.randf() < 1.15-weathered*0.5)
			p["web"] = web
			# The ribs on the pier lines: stones kept each side (of 9).
			var ribs: Array = []
			for k in range(BAYS+1):
				var keep := Vector2i(9,9)
				var webbed := (k > 0 and bool(web[k-1])) or (k < BAYS and bool(web[k]))
				if k == 0 or k == BAYS: keep = Vector2i(0,0)
				elif not webbed and r.randf() < 0.35+0.5*weathered:
					keep = Vector2i(r.randi_range(2,7),r.randi_range(2,7))
				ribs.append(keep)
			p["ribs"] = ribs
			# The flyers on the inner pier lines: whole, or snapped off.
			var flyers := {}
			for s: int in [-1,1]:
				for k in range(1,BAYS):
					flyers["%d/%d" % [s,k]] = r.randf() > 0.15*weathered
			p["flyers"] = flyers
			# The flank whose buttresses are pierced by the knife slots.
			p["pierced"] = -1 if r.randf() < 0.5 else 1
		"belfry_tower":
			p["corner"] = r.randi_range(0,3)
			p["torn"] = r.randf()
			p["mullion"] = r.randf() < 0.5
		"rose_gate":
			p["lean"] = r.randf_range(-1.0,1.0)
	return p

## The piece's flown openings, in its frame (its foot on y 0, front +Z),
## from the plan (no build): an Array of Dictionaries
##   name     a stable name, "<piece>/<opening>" (a layout handle's tail)
##   kind     "portal", "nave" (the lane down the nave), "screen", "east",
##            "lancet", "knife", "breach", "flank" (the corridor down a
##            flank), "flyer" (the gap under one flyer, a gate in the
##            flank), "tracery", "belfry", "rose"
##   frame    Transform3D: origin the clear box's middle, basis x across,
##            y up, z the way through (flown either way)
##   size     Vector3 (clear width, clear height, depth along the way): the
##            box a plane must pass, a pointed head over it left out
##   head     a pointed head's rise over the box's top (0 none)
##   knife    true when level wings don't fit: rolled onto a wingtip
##   round    true for a round opening (the rose): size.x its diameter
##   lane     true for a lane flown along its whole depth (the nave's,
##            a flank's, the slots' line), not a gate passed through
static func openings(id: String, seed_value: int, weathered := 0.6) -> Array:
	var p := plan(id,seed_value,weathered)
	var out: Array = []
	match id:
		"gothic_nave": _nave_openings(p,out)
		"belfry_tower": _belfry_openings(p,out)
		"rose_gate": _gate_openings(p,out)
	return out

static func _opening(out: Array, name: String, kind: String, centre: Vector3, way: Vector3, size: Vector3, head := 0.0, knife := false, round := false, lane := false) -> void:
	var z := way.normalized()
	var x := Vector3.UP.cross(z).normalized()
	out.append({"name":name,"kind":kind,"frame":Transform3D(Basis(x,Vector3.UP,z),centre),"size":size,"head":head,"knife":knife,"round":round,"lane":lane})

static func _nave_openings(p: Dictionary, out: Array) -> void:
	_opening(out,"gothic_nave/portal","portal",Vector3(0.0,PORTAL_SPRING*0.5+0.5,HALF_LEN+PIER_R*0.4),Vector3.BACK,Vector3(PORTAL,PORTAL_SPRING-1.0,END_D*2.0),RuinKit._rise(PORTAL*0.5,PORTAL))
	# The lane down the nave, either side of the screen: under the ribs'
	# springing, over the drifts, between the ends' and the screen's faces.
	var sz := HALF_LEN-SCREEN_LINE*BAY
	var west_in := HALF_LEN+PIER_R*0.4-END_D-1.0
	var east_in := -HALF_LEN-PIER_R*0.4+END_D+1.0
	_opening(out,"gothic_nave/nave","nave",Vector3(0.0,NAVE_LANE.x+NAVE_LANE.y*0.5,(west_in+sz+SCREEN.z+1.0)*0.5),Vector3.BACK,Vector3(NAVE_HALF,NAVE_LANE.y,west_in-sz-SCREEN.z-1.0),0.0,false,false,true)
	_opening(out,"gothic_nave/choir","nave",Vector3(0.0,NAVE_LANE.x+NAVE_LANE.y*0.5,(sz-SCREEN.z-1.0+east_in)*0.5),Vector3.BACK,Vector3(NAVE_HALF,NAVE_LANE.y,sz-SCREEN.z-1.0-east_in),0.0,false,false,true)
	_opening(out,"gothic_nave/screen","screen",Vector3(0.0,(SCREEN_SILL+SCREEN.y)*0.5,sz),Vector3.BACK,Vector3(SCREEN_W,SCREEN.y-SCREEN_SILL,SCREEN.z*2.0),RuinKit._rise(SCREEN_W*0.5,SCREEN_W))
	var ez := -HALF_LEN-PIER_R*0.4
	_opening(out,"gothic_nave/east","east",Vector3(0.0,(EAST.x+EAST.y)*0.5,ez),Vector3.BACK,Vector3(EAST_W,EAST.y-EAST.x,END_D*2.0),RuinKit._rise(EAST_W*0.5,EAST_W))
	for s: float in [-1.0,1.0]:
		_opening(out,"gothic_nave/east_slit_%s" % ("w" if s < 0.0 else "e"),"knife",Vector3(s*_east_slit_x(),(EAST_SLIT.x+EAST_SLIT.y)*0.5,ez),Vector3.BACK,Vector3(KNIFE,EAST_SLIT.y-EAST_SLIT.x,END_D*2.0),RuinKit._rise(KNIFE*0.5,KNIFE),true)
	var bays: Dictionary = p["bays"]
	var low: Dictionary = p["breach_low"]
	var flyers: Dictionary = p["flyers"]
	for s: int in [-1,1]:
		var side := "w" if s < 0 else "e"
		var kinds: Array = bays[s]
		for i in range(BAYS):
			var z := HALF_LEN-(i+0.5)*BAY
			var at := Vector3(s*PIER_X,0.0,z)
			var name := "gothic_nave/%s%d" % [side,i]
			match str(kinds[i]):
				"lancet":
					_opening(out,name,"lancet",at+Vector3(0.0,(LANCET_SILL+LANCET_SPRING)*0.5,0.0),Vector3(s,0,0),Vector3(LANCET,LANCET_SPRING-LANCET_SILL,WALL_D*2.0),RuinKit._rise(LANCET*0.5,LANCET))
				"slit":
					var off := KNIFE*0.5+MULLION
					for t: float in [-1.0,1.0]:
						_opening(out,"%s_%s" % [name,"a" if t < 0.0 else "b"],"knife",at+Vector3(0.0,(LANCET_SILL+LANCET_SPRING)*0.5,t*off),Vector3(s,0,0),Vector3(KNIFE,LANCET_SPRING-LANCET_SILL,WALL_D*2.0),0.0,true)
				"breach":
					var y0: float = float(low["%d/%d" % [s,i]])+3.5
					_opening(out,name,"breach",at+Vector3(0.0,(y0+WALL_H-6.0)*0.5,0.0),Vector3(s,0,0),Vector3(BAY-2.0*PIER_R-4.0,WALL_H-6.0-y0,WALL_D*2.0))
		# The flank corridor and the gap under each flyer standing.
		var cx := s*(BUTTRESS_X-FLANK*0.5)
		var top := FLYER.x-1.5
		_opening(out,"gothic_nave/flank_%s" % side,"flank",Vector3(cx,(HEAP_TOP+top)*0.5,0.0),Vector3.BACK,Vector3(FLANK,top-HEAP_TOP,BAYS*BAY+BUTTRESS_W),0.0,false,false,true)
		for k in range(1,BAYS):
			if not bool(flyers["%d/%d" % [s,k]]): continue
			_opening(out,"gothic_nave/flyer_%s%d" % [side,k],"flyer",Vector3(cx,(1.0+top)*0.5,HALF_LEN-k*BAY),Vector3.BACK,Vector3(FLANK,top-1.0,BUTTRESS_W))
		if s == int(p["pierced"]):
			_opening(out,"gothic_nave/slots_%s" % side,"knife",Vector3(s*(BUTTRESS_X+_slot_in()),(SLOT_Y.x+SLOT_Y.y)*0.5,0.0),Vector3.BACK,Vector3(KNIFE,SLOT_Y.y-SLOT_Y.x,BAYS*BAY+BUTTRESS_W),RuinKit._rise(KNIFE*0.5,KNIFE),true,false,true)

## How far into a buttress (from its inner face) the knife slot's middle is.
static func _slot_in() -> float:
	return float(BUTTRESS_STAGES[1][1])*0.5

## The east end's slits' middles off the axis.
static func _east_slit_x() -> float:
	return EAST_W*0.5+4.0+KNIFE*0.5

static func _belfry_openings(p: Dictionary, out: Array) -> void:
	var depth := TOWER_HALF*2.0
	var h := BELFRY.y-BELFRY.x
	var cy := (BELFRY.x+BELFRY.y)*0.5
	# Front to back, two lights (one either side of the middle mullion),
	# or, the mullion fallen, one wide way through.
	if bool(p["mullion"]):
		for t: float in [-1.0,1.0]:
			_opening(out,"belfry_tower/belfry_%s" % ("w" if t < 0.0 else "e"),"belfry",Vector3(t*(BELFRY_W*0.5+MULLION),cy,0.0),Vector3.BACK,Vector3(BELFRY_W,h,depth),RuinKit._rise(BELFRY_W*0.5,BELFRY_W))
	else:
		var w := BELFRY_W*2.0+MULLION*2.0
		_opening(out,"belfry_tower/belfry","belfry",Vector3(0.0,cy,0.0),Vector3.BACK,Vector3(w,h,depth),RuinKit._rise(w*0.5,w))
	# Side to side, a knife slit each face.
	_opening(out,"belfry_tower/slits","knife",Vector3(0.0,cy,0.0),Vector3.RIGHT,Vector3(KNIFE,h,depth),RuinKit._rise(KNIFE*0.5,KNIFE),true)
	_opening(out,"belfry_tower/tracery","tracery",Vector3(0.0,(TRACERY.x+TRACERY.y)*0.5,0.0),Vector3.BACK,Vector3(TRACERY_W,TRACERY.y-TRACERY.x,depth),RuinKit._rise(TRACERY_W*0.5,TRACERY_W))

static func _gate_openings(_p: Dictionary, out: Array) -> void:
	_opening(out,"rose_gate/rose","rose",Vector3(0.0,ROSE_Y,0.0),Vector3.BACK,Vector3(ROSE,ROSE,GATE.w*2.0),0.0,false,true)
	for s: float in [-1.0,1.0]:
		_opening(out,"rose_gate/slot_%s" % ("w" if s < 0.0 else "e"),"knife",Vector3(s*_gate_slot_x(),(GATE_SLOT.x+GATE_SLOT.y)*0.5,0.0),Vector3.BACK,Vector3(KNIFE,GATE_SLOT.y-GATE_SLOT.x,GATE.w*2.0),RuinKit._rise(KNIFE*0.5,KNIFE),true)

static func _gate_slot_x() -> float:
	return ROSE*0.5+ROSE_RING+5.0

# --- Building blocks -----------------------------------------------------------

## A new lean, culled build (the halls' cheap stone) that settles little.
static func _build(seed_value: int, weathered: float, label: String) -> Build:
	var b := Build.new(seed_value,weathered,label)
	b.lean = true
	b.cull = true
	b.settle = 0.4
	return b

## A wall run along the pose's X from `x0` to `x1`, `d` half thick, from
## `y0` (the footing) up to `top` (a Callable(x) -> y), pierced by `hole`
## (the kit's: Callable(y) -> Vector2(middle x, half width), y < 0 none).
static func _wall(b: Build, pose: Transform3D, x0: float, x1: float, top: Callable, d: float, hole := Callable(), course := COURSE, y0 := -FOOT) -> void:
	RuinKit._courses(b,pose,x0,x1,y0,top,d,hole,course)

## A pointed opening's hole for `_wall`: middle `cx`, clear width `w`, from
## `sill` (-INF: from the foot) to its springing `spring`, its head an
## equilateral arch, `ring` of voussoirs round it (left out of the walling:
## the ring is built on its own, `_head`, and the jambs, `_jambs`).
static func _lancet_hole(cx: float, w: float, sill: float, spring: float, ring: float) -> Callable:
	var h := w*0.5
	return func(y: float) -> Vector2:
		if y < sill: return Vector2(cx,-1.0)
		if y < spring: return Vector2(cx,h+ring)
		return Vector2(cx,RuinKit._arc_half(h,w,ring,y-spring))

## The voussoir ring of a pointed opening, in two orders (the inner set
## back): a giant's, `dr` deep radially, `d` half thick, `n` a side.
static func _head(b: Build, pose: Transform3D, cx: float, w: float, spring: float, dr: float, d: float, n := 9, lost := 0, top := Callable()) -> void:
	var h := w*0.5
	var side := -1.0 if b.rng.randf() < 0.5 else 1.0
	RuinKit._ring_order(b,pose,cx,spring,h,w,0.0,dr*0.5,d-0.35,n,99,side,RuinKit._stone(b,1.03),lost,top,true)
	RuinKit._ring_order(b,pose,cx,spring,h,w,dr*0.5,dr*0.5,d,n,99,side,RuinKit._stone(b,0.98),lost+int(b.rng.randf()*1.6*b.weathered),top)

## Jambs: long and short stones up both sides of an opening (middle `cx`,
## clear width `w`) from `sill` to `spring`, `d` half thick, `ring` out.
static func _jambs(b: Build, pose: Transform3D, cx: float, w: float, sill: float, spring: float, d: float, ring: float) -> void:
	for s: float in [-1.0,1.0]:
		var y := sill
		var k := 0
		while y < spring-0.2:
			var hgt := minf(COURSE*b.rng.randf_range(0.9,1.3),spring-y)
			if spring-(y+hgt) < 0.6: hgt = spring-y
			var wide := ring*(1.0 if k%2 == 0 else 0.7)
			var at := Vector3(cx+s*(w*0.5+wide*0.5),y+hgt*0.5,0.0)
			b.solid(RuinKit._box(b,Vector3(wide*0.5,hgt*0.5-0.01,d)),pose*RuinKit._settle(b,at,0.2),RuinKit._stone(b,1.02))
			y += hgt
			k += 1

## A sill stone under an opening (its top at `y`).
static func _sill(b: Build, pose: Transform3D, cx: float, w: float, y: float, d: float) -> void:
	b.solid(RuinKit._box(b,Vector3(w*0.5+0.4,0.25,d+0.12)),pose*RuinKit._settle(b,Vector3(cx,y-0.25,0.0),0.2),RuinKit._stone(b,1.05))

## A giant clustered pier at `pose` (its foot), `height` to its capital's
## top: an octagonal core in drums, four shafts on its faces in long
## lengths, a moulded base and a capital.
static func _pier(b: Build, pose: Transform3D, height: float, r := PIER_R) -> void:
	b.solid(RuinKit._prism(8,r*1.32,r*1.2,-FOOT,0.9,PI/8.0),pose,RuinKit._stone(b,0.92))
	var cap_h := 1.6
	var top := height-cap_h
	var y := 0.9
	while y < top-0.1:
		var hgt := minf(b.rng.randf_range(2.2,2.8),top-y)
		if top-(y+hgt) < 0.8: hgt = top-y
		b.solid(RuinKit._prism(8,r,r,0.0,hgt,PI/8.0),pose*RuinKit._jiggle(b,Transform3D(Basis.IDENTITY,Vector3(0.0,y,0.0)),0.25),RuinKit._stone(b,0.97))
		y += hgt
	# The shafts: on the four faces, in long lengths.
	for k in range(4):
		var a := PI*0.5*k+PI/8.0*0.0
		var out := Vector3(cos(a),0.0,sin(a))*(r+0.2)
		var sy := 0.9
		while sy < top-0.1:
			var hgt := minf(b.rng.randf_range(5.0,6.5),top-sy)
			if top-(sy+hgt) < 1.0: hgt = top-sy
			b.solid(RuinKit._prism(8,r*0.36,r*0.36,0.0,hgt),pose*Transform3D(Basis.IDENTITY,out+Vector3(0.0,sy,0.0)),RuinKit._stone(b,1.04))
			sy += hgt
	b.solid(RuinKit._prism(8,r*1.12,r*1.55,0.0,cap_h*0.7,PI/8.0),pose*Transform3D(Basis.IDENTITY,Vector3(0.0,top,0.0)),RuinKit._stone(b,1.05))
	b.solid(RuinKit._prism(8,r*1.6,r*1.6,cap_h*0.7,cap_h,PI/8.0),pose*Transform3D(Basis.IDENTITY,Vector3(0.0,top,0.0)),RuinKit._stone(b,1.0))

## A stepped buttress at `pose` (its inner face's foot middle; it stands
## out along +Z, `width` across X), its stages [top, depth]; a pinnacle on
## its head; `slot`: a knife slot (pointed head) from SLOT_Y.x to .y up it,
## through it along X, `_slot_in` out from its inner face.
static func _buttress(b: Build, pose: Transform3D, stages: Array, width: float, slot := false, pinnacle := true) -> void:
	var y := -FOOT
	var hx := width*0.5
	var slot_z := _slot_in()
	var slot_top := SLOT_Y.y+RuinKit._rise(KNIFE*0.5,KNIFE)+1.0
	for i in range(stages.size()):
		var top: float = stages[i][0]
		var depth: float = stages[i][1]
		while y < top-0.1:
			var y1 := minf(top,y+b.rng.randf_range(1.5,2.1))
			if top-y1 < 0.6: y1 = top
			if slot and y < SLOT_Y.x and y1 > SLOT_Y.x: y1 = SLOT_Y.x
			if slot and y < SLOT_Y.y and y1 > SLOT_Y.y: y1 = SLOT_Y.y
			var parts: Array = [Vector2(0.0,depth)]
			if slot and y >= SLOT_Y.x-0.01 and y < SLOT_Y.y-0.01:
				parts = [Vector2(0.0,slot_z-KNIFE*0.5),Vector2(slot_z+KNIFE*0.5,depth)]
			elif slot and y >= SLOT_Y.y-0.01 and y < slot_top:
				parts = []
			for part: Vector2 in parts:
				var half := Vector3(hx-0.01,(y1-y)*0.5-0.01,(part.y-part.x)*0.5-0.01)
				var at := Vector3(0.0,(y+y1)*0.5,(part.x+part.y)*0.5)
				var planes := RuinKit._box(b,half)
				if y1 >= top-0.01 and part.y > depth-0.01 and i < stages.size()-1:
					# The set-off's weathering: the front edge sloped off.
					var n := Vector3(0.0,1.0,1.0).normalized()
					planes.append(Plane(n,n.dot(Vector3(0.0,half.y,half.z-0.8))))
				b.solid(planes,pose*RuinKit._settle(b,at,0.2),RuinKit._stone(b,1.0 if i%2 == 0 else 0.96))
			if slot and y >= SLOT_Y.y-0.01 and y < slot_top:
				# The slot's pointed head: two leaning stones meeting over it,
				# then plain courses on.
				var rise := RuinKit._rise(KNIFE*0.5,KNIFE)
				for s: float in [-1.0,1.0]:
					var far := depth if s > 0.0 else 0.0
					var pts := PackedVector3Array()
					for xx: float in [-hx+0.01,hx-0.01]:
						pts.append(Vector3(xx,SLOT_Y.y,slot_z+s*KNIFE*0.5))
						pts.append(Vector3(xx,SLOT_Y.y,far))
						pts.append(Vector3(xx,SLOT_Y.y+rise,slot_z))
						pts.append(Vector3(xx,slot_top,slot_z))
						pts.append(Vector3(xx,slot_top,far))
					b.solid(RuinKit._planes_round(pts),pose,RuinKit._stone(b,1.04))
				y1 = slot_top
			y = y1
	if pinnacle:
		var last: float = stages[-1][1]
		var base := pose*Transform3D(Basis.IDENTITY,Vector3(0.0,y,last*0.5))
		var snapped := b.rng.randf() < 0.3+0.5*b.weathered
		RuinKit._spire(b,base,minf(hx,last*0.5)*0.7,9.0,snapped)

## A flying buttress in the pose's XY plane from a buttress's inner face
## (x `from`, soffit at FLYER.x) to the pier head (x `to`, FLYER.y): its
## soffit a quarter ellipse (upright off the buttress, level at the pier),
## its back a straight coping; `keep` of its stones (from the buttress).
static func _flyer(b: Build, pose: Transform3D, from: float, to: float, keep := 99) -> void:
	var n := 6
	var a := from-to
	var bb := FLYER.y-FLYER.x
	var centre := Vector2(to,FLYER.x)
	var back_from := Vector2(from,FLYER.x+bb+FLYER.z*0.4)
	var back_to := Vector2(to,FLYER.y+FLYER.z)
	var hz := 0.95
	for i in range(mini(n,keep)):
		var t0 := PI*0.5*i/n
		var t1 := PI*0.5*(i+1)/n
		var p0 := centre+Vector2(cos(t0)*a,sin(t0)*bb)
		var p1 := centre+Vector2(cos(t1)*a,sin(t1)*bb)
		var q0 := back_from.lerp(back_to,(from-p0.x)/a)
		var q1 := back_from.lerp(back_to,(from-p1.x)/a)
		var pts := PackedVector3Array()
		for z: float in [-hz,hz]:
			for v: Vector2 in [p0,p1,q0,q1]:
				pts.append(Vector3(v.x,v.y,z))
		var extra: Array[Plane] = []
		if i == mini(n,keep)-1 and keep < n:
			var m := Vector3(-1.0,b.rng.randf_range(-0.4,0.6),b.rng.randf_range(-0.4,0.4)).normalized()
			extra.append(Plane(m,m.dot(Vector3((p0.x+p1.x)*0.5,(p0.y+q0.y)*0.5,0.0))))
		b.solid(RuinKit._planes_round(pts),pose*RuinKit._jiggle(b,Transform3D.IDENTITY,0.1),RuinKit._stone(b,1.03),true,true,extra,-1,0.6)

## A drift of big fallen stones (vault, walling) round `at` (on the
## ground), `reach` across (x, z half), at most `high` tall, `count` of them.
static func _heap(b: Build, at: Vector3, reach: Vector2, high: float, count: int) -> void:
	count = int(ceil(count*(0.5+0.5*b.level)))
	for i in range(count):
		var s := Vector3(b.rng.randf_range(0.6,1.6),b.rng.randf_range(0.4,0.9),b.rng.randf_range(0.5,1.2))*(1.0-0.45*float(i)/count)
		var p := at+Vector3(b.rng.randf_range(-1.0,1.0)*reach.x,0.0,b.rng.randf_range(-1.0,1.0)*reach.y)*(1.0-0.5*float(i)/count)
		p.y = minf(high-s.y,s.y*0.6+b.rng.randf()*high*float(i)/count*0.6)
		var pose := Transform3D(Basis(Vector3.UP,b.rng.randf()*TAU)*Basis(Vector3.RIGHT,b.rng.randf_range(-0.4,0.4))*Basis(Vector3.BACK,b.rng.randf_range(-0.3,0.3)),p)
		b.solid(RuinKit._box(b,s),pose,RuinKit._stone(b,0.94),true,true,[],-1,2.0)

## Growth on a ruin: strands hung from `points`, about `length` long.
static func _grow(b: Build, points: Array, length: float) -> void:
	for p: Vector3 in points:
		if b.rng.randf() < 0.3+0.6*b.weathered: b.hang(p,b.rng.randf_range(0.4,1.0)*length*(0.4+b.weathered),true)

static func _meta(node: Node3D, id: String, p: Dictionary) -> void:
	node.set_meta("openings",openings(id,int(p["seed"]),float(p["weathered"])))
	node.set_meta("gothic",p)
	var box := AABB()
	var first := true
	for child in node.get_children():
		if child is MeshInstance3D:
			var m: AABB = (child as MeshInstance3D).get_aabb()
			box = m if first else box.merge(m)
			first = false
	node.set_meta("bounds",box)

# --- 1. The ruined nave ----------------------------------------------------------

## The ruined nave (`gothic_nave`): see the file's head. Runs along Z, the
## west portal its front (+Z), BAYS*BAY long (112 m) between its ends, 2 *
## BUTTRESS_X wide to the buttresses' faces (55 m, 66 over them), its ribs'
## crowns about 46 m up, the gables to 40.
static func nave(seed_value: int, weathered := 0.6) -> Node3D:
	var p := plan("gothic_nave",seed_value,weathered)
	var b := _build(seed_value,weathered,"GothicNave")
	var bays: Dictionary = p["bays"]
	var low: Dictionary = p["breach_low"]
	var flyers: Dictionary = p["flyers"]
	var ribs: Array = p["ribs"]
	var web: Array = p["web"]
	var radius := NAVE_HALF*2.0*VAULT_PITCH
	var ring := 1.3
	var hangs: Array = []
	# The piers, on every pier line both sides.
	for k in range(BAYS+1):
		var z := HALF_LEN-k*BAY
		for s: float in [-1.0,1.0]:
			_pier(b,Transform3D(Basis.IDENTITY,Vector3(s*PIER_X,0.0,z)),VAULT_SPRING)
	# The side walls, bay by bay between the piers, each pierced.
	for s: int in [-1,1]:
		var kinds: Array = bays[s]
		for i in range(BAYS):
			var z := HALF_LEN-(i+0.5)*BAY
			var half := BAY*0.5-PIER_R+0.2
			var pose := Transform3D(Basis(Vector3.UP,PI*0.5),Vector3(s*PIER_X,0.0,z))
			var kind := str(kinds[i])
			var top: Callable = RuinKit._ruin_line(b,-half,half,lerpf(WALL_H,WALL_H-5.0,weathered),WALL_H,weathered*0.5)
			if kind == "breach":
				var y0: float = low["%d/%d" % [s,i]]
				var line := RuinKit._ruin_line(b,-half,half,y0,y0+3.0,1.0)
				top = func(x: float) -> float:
					var edge := clampf((absf(x)-(half-2.2))/2.2,0.0,1.0)
					return lerpf(float(line.call(x)),WALL_H-3.0,edge)
				_wall(b,pose,-half,half,top,WALL_D)
				_heap(b,Vector3(s*(PIER_X+PIER_REACH+FLANK*0.5),0.0,z),Vector2(2.4,4.0),HEAP_TOP,10)
				_heap(b,Vector3(s*(PIER_X-4.5),0.0,z),Vector2(2.2,3.5),3.0,6)
				continue
			var w := LANCET if kind == "lancet" else KNIFE*2.0+MULLION*2.0
			_wall(b,pose,-half,half,top,WALL_D,_lancet_hole(0.0,w,LANCET_SILL,LANCET_SPRING,ring))
			_sill(b,pose,0.0,w,LANCET_SILL,WALL_D)
			_jambs(b,pose,0.0,w,LANCET_SILL,LANCET_SPRING,WALL_D,ring)
			if kind == "slit":
				# Its mullion stands: two knife lights, a head over each.
				var mh := LANCET_SPRING-LANCET_SILL
				b.solid(RuinKit._box(b,Vector3(MULLION-0.02,mh*0.5,WALL_D*0.7)),pose*Transform3D(Basis.IDENTITY,Vector3(0.0,LANCET_SILL+mh*0.5,0.0)),RuinKit._stone(b,1.06))
				for t: float in [-1.0,1.0]:
					RuinKit._ring_order(b,pose,t*(KNIFE*0.5+MULLION),LANCET_SPRING,KNIFE*0.5,KNIFE,0.0,0.45,WALL_D*0.7,4,99,t,RuinKit._stone(b,1.06))
			_head(b,pose,0.0,w,LANCET_SPRING,ring,WALL_D,9,0,top)
			hangs.append(pose*Vector3(0.0,LANCET_SPRING+RuinKit._rise(w*0.5,w)+ring,WALL_D))
	# The buttresses and their flyers, down both flanks.
	for s: int in [-1,1]:
		for k in range(BAYS+1):
			var z := HALF_LEN-k*BAY
			var end := k == 0 or k == BAYS
			var pose := Transform3D(Basis(Vector3.UP,s*PI*0.5),Vector3(s*BUTTRESS_X,0.0,z))
			_buttress(b,pose,END_STAGES if end else BUTTRESS_STAGES,BUTTRESS_W,s == int(p["pierced"]))
			if end: continue
			var fpose := Transform3D(Basis(Vector3.UP,0.0 if s > 0 else PI),Vector3(0.0,0.0,z))
			var keep := 99 if bool(flyers["%d/%d" % [s,k]]) else b.rng.randi_range(1,2)
			_flyer(b,fpose,BUTTRESS_X,PIER_X,keep)
	# The vault: ribs on the inner pier lines, webbing over some bays.
	for k in range(1,BAYS):
		var z := HALF_LEN-k*BAY
		var keep: Vector2i = ribs[k]
		for s: float in [-1.0,1.0]:
			var n := keep.x if s < 0.0 else keep.y
			if n <= 0: continue
			var pose := Transform3D(Basis(Vector3.UP,0.0 if s < 0.0 else PI),Vector3(s*NAVE_HALF,VAULT_SPRING,z))
			RuinKit._rib(b,pose,NAVE_HALF,radius,RIB.x,RIB.y,9,n)
	for i in range(BAYS):
		var z := HALF_LEN-(i+0.5)*BAY
		if bool(web[i]):
			var pose := Transform3D(Basis.IDENTITY,Vector3(0.0,VAULT_SPRING,z))
			RuinKit._ring_order(b,pose,0.0,0.0,NAVE_HALF,radius,0.0,WEB,BAY*0.5-RIB.y-0.05,10,99,1.0,RuinKit._stone(b,0.95),0,Callable(),false,0.18)
		elif i != SCREEN_LINE-1 and i != SCREEN_LINE:
			# Its vault fallen: drifts along both sides of the floor, kept out
			# of the lane down the middle.
			for s: float in [-1.0,1.0]:
				_heap(b,Vector3(s*(NAVE_HALF-3.2),0.0,z+b.rng.randf_range(-3.0,3.0)),Vector2(2.4,4.5),HEAP_TOP-0.4,8)
	# The choir screen across the nave, its arch the way on.
	var sz := HALF_LEN-SCREEN_LINE*BAY
	var spose := Transform3D(Basis.IDENTITY,Vector3(0.0,0.0,sz))
	var stop: Callable = RuinKit._ruin_line(b,-NAVE_HALF,NAVE_HALF,SCREEN.x-4.0*weathered,SCREEN.x,weathered*0.5)
	_wall(b,spose,-NAVE_HALF-0.4,NAVE_HALF+0.4,stop,SCREEN.z,_lancet_hole(0.0,SCREEN_W,SCREEN_SILL,SCREEN.y,1.1),1.5)
	_sill(b,spose,0.0,SCREEN_W,SCREEN_SILL,SCREEN.z)
	_jambs(b,spose,0.0,SCREEN_W,SCREEN_SILL,SCREEN.y,SCREEN.z,1.1)
	_head(b,spose,0.0,SCREEN_W,SCREEN.y,1.1,SCREEN.z,8,0,stop)
	# The west front: the portal under a broken gable.
	var span := PIER_X+PIER_R
	var wpose := Transform3D(Basis.IDENTITY,Vector3(0.0,0.0,HALF_LEN+PIER_R*0.4))
	var gable := RuinKit._ruin_line(b,-span,span,30.0,40.0,weathered)
	var wtop := func(x: float) -> float: return minf(float(gable.call(x)),46.0-absf(x)*0.9)
	_wall(b,wpose,-span,span,wtop,END_D,_lancet_hole(0.0,PORTAL,-INF,PORTAL_SPRING,1.6))
	_jambs(b,wpose,0.0,PORTAL,0.0,PORTAL_SPRING,END_D,1.6)
	_head(b,wpose,0.0,PORTAL,PORTAL_SPRING,1.6,END_D,10,0,wtop)
	hangs.append(wpose*Vector3(0.0,PORTAL_SPRING+RuinKit._rise(PORTAL*0.5,PORTAL)+1.6,END_D))
	# The east end: the great lancet between two slits.
	var epose := Transform3D(Basis.IDENTITY,Vector3(0.0,0.0,-HALF_LEN-PIER_R*0.4))
	var east := RuinKit._ruin_line(b,-span,span,32.0,42.0,weathered)
	var etop := func(x: float) -> float: return minf(float(east.call(x)),48.0-absf(x)*0.9)
	var slit_x := _east_slit_x()
	var cut := slit_x-KNIFE*0.5-2.0
	_wall(b,epose,-span,-cut,etop,END_D,_lancet_hole(-slit_x,KNIFE,EAST_SLIT.x,EAST_SLIT.y,0.8))
	_wall(b,epose,-cut,cut,etop,END_D,_lancet_hole(0.0,EAST_W,EAST.x,EAST.y,ring))
	_wall(b,epose,cut,span,etop,END_D,_lancet_hole(slit_x,KNIFE,EAST_SLIT.x,EAST_SLIT.y,0.8))
	_sill(b,epose,0.0,EAST_W,EAST.x,END_D)
	_jambs(b,epose,0.0,EAST_W,EAST.x,EAST.y,END_D,ring)
	_head(b,epose,0.0,EAST_W,EAST.y,ring,END_D,9,0,etop)
	for s: float in [-1.0,1.0]:
		_jambs(b,epose,s*slit_x,KNIFE,EAST_SLIT.x,EAST_SLIT.y,END_D,0.8)
		_head(b,epose,s*slit_x,KNIFE,EAST_SLIT.y,0.8,END_D,4,0,etop)
	# Growth: from the heads, down the walls' tops.
	_grow(b,hangs,8.0)
	for i in range(int(6+weathered*10.0)):
		var s := -1.0 if b.rng.randf() < 0.5 else 1.0
		var face := WALL_D+0.2 if b.rng.randf() < 0.5 else -WALL_D-0.2
		b.hang(Vector3(s*(PIER_X+face),WALL_H-6.0*weathered-1.0,b.rng.randf_range(-HALF_LEN+3.0,HALF_LEN-3.0)),b.rng.randf_range(3.0,10.0)*weathered,true)
	var node := b.finish()
	_meta(node,"gothic_nave",p)
	return node

# --- 2. The belfry tower ----------------------------------------------------------

## The belfry tower (`belfry_tower`): see the file's head. TOWER_HALF*2 (16
## m) square over its walls, 24 over its angle buttresses, its head
## TOWER_H (80 m) where it stands whole, a pinnacle on one corner to 96.
static func belfry(seed_value: int, weathered := 0.6) -> Node3D:
	var p := plan("belfry_tower",seed_value,weathered)
	var b := _build(seed_value,weathered,"BelfryTower")
	var half := TOWER_HALF
	var d := TOWER_WALL*0.5
	var mid := half-d
	var ring := 1.1
	var torn := float(p["torn"])
	var belfry_head := BELFRY.y+RuinKit._rise(BELFRY_W*0.5,BELFRY_W)+ring
	if not bool(p["mullion"]): belfry_head = BELFRY.y+RuinKit._rise(BELFRY_W+MULLION,BELFRY_W*2.0+MULLION*2.0)+ring
	var tracery_head := TRACERY.y+RuinKit._rise(TRACERY_W*0.5,TRACERY_W)+ring
	for face in range(4):
		var turn := Basis(Vector3.UP,PI*0.5*face)
		var pose := Transform3D(turn,turn*Vector3(0.0,0.0,mid))
		# Front and back run the full width; the sides between them.
		var x0 := -half if face%2 == 0 else -half+TOWER_WALL
		var x1 := -x0
		# The head ragged, never down into the belfry's heads (the back's
		# tear apart): the belfry stays a chamber you fly through.
		var head := TOWER_H-weathered*3.0
		var ragged := RuinKit._ruin_line(b,x0,x1,maxf(belfry_head+2.0,head-3.0-weathered*4.0),head,weathered)
		var line := func(x: float) -> float: return maxf(float(ragged.call(x)),belfry_head+2.0)
		var top: Callable = line
		if face == 2:
			# The back: torn down toward one corner, never into the belfry.
			var low := lerpf(belfry_head+2.0,TOWER_H-8.0,torn)
			top = func(x: float) -> float: return minf(float(line.call(x)),lerpf(TOWER_H,low,clampf((x-x0)/(x1-x0)*1.6,0.0,1.0)))
		var holes: Array = []
		if face == 0 or face == 2:
			if bool(p["mullion"]):
				var off := BELFRY_W*0.5+MULLION
				holes.append([-off,BELFRY_W,BELFRY.x,BELFRY.y])
				holes.append([off,BELFRY_W,BELFRY.x,BELFRY.y])
			else:
				holes.append([0.0,BELFRY_W*2.0+MULLION*2.0,BELFRY.x,BELFRY.y])
			holes.append([0.0,TRACERY_W,TRACERY.x,TRACERY.y])
		else:
			holes.append([0.0,KNIFE,BELFRY.x,BELFRY.y])
		# The wall in bands by height, one `_courses` run a hole (the
		# belfry's two lights split their band at the mullion).
		var levels := [-FOOT,TRACERY.x-1.5,tracery_head+0.6,BELFRY.x-1.5,belfry_head+0.6,INF]
		for li in range(levels.size()-1):
			var y0: float = levels[li]
			var y1: float = levels[li+1]
			var band_top := func(x: float) -> float: return minf(float(top.call(x)),y1)
			var in_band: Array = []
			for hl: Array in holes:
				if float(hl[2]) >= y0 and float(hl[2]) < y1: in_band.append(hl)
			if in_band.is_empty():
				_wall(b,pose,x0,x1,band_top,d,Callable(),TOWER_COURSE,y0)
				continue
			if in_band.size() == 1:
				var hl: Array = in_band[0]
				_wall(b,pose,x0,x1,band_top,d,_lancet_hole(float(hl[0]),float(hl[1]),float(hl[2]),float(hl[3]),ring),TOWER_COURSE,y0)
			else:
				var ha: Array = in_band[0]
				var hb: Array = in_band[1]
				_wall(b,pose,x0,0.0,band_top,d,_lancet_hole(float(ha[0]),float(ha[1]),float(ha[2]),float(ha[3]),ring),TOWER_COURSE,y0)
				_wall(b,pose,0.0,x1,band_top,d,_lancet_hole(float(hb[0]),float(hb[1]),float(hb[2]),float(hb[3]),ring),TOWER_COURSE,y0)
			for hl: Array in in_band:
				var cx := float(hl[0])
				var w := float(hl[1])
				_sill(b,pose,cx,w,float(hl[2]),d)
				_jambs(b,pose,cx,w,float(hl[2]),float(hl[3]),d,ring)
				_head(b,pose,cx,w,float(hl[3]),ring,d,7 if w > 3.0 else 4,0,top)
		if face == 0:
			# The tracery's remains: a broken ring high in the window's point.
			var rise := RuinKit._rise(TRACERY_W*0.5,TRACERY_W)
			RuinKit._circle_ring(b,pose,Vector2(0.0,TRACERY.y+rise*0.42),rise*0.3,0.26,d*0.45,10,0.35*weathered)
		# String courses round the outside at the stages' heads.
		for sy: float in [18.0,34.0,50.0]:
			b.solid(RuinKit._box(b,Vector3((x1-x0)*0.5,0.3,0.35)),pose*Transform3D(Basis.IDENTITY,Vector3(0.0,sy,d+0.3)),RuinKit._stone(b,1.06))
	# The angle buttresses: two at each corner, one off each face.
	var along := half-TOWER_BUTTRESS_W*0.5
	for face in range(4):
		var turn := Basis(Vector3.UP,PI*0.5*face)
		for t: float in [-1.0,1.0]:
			_buttress(b,Transform3D(turn,turn*Vector3(t*along,0.0,half)),TOWER_STAGES,TOWER_BUTTRESS_W,false,false)
	# The corner pinnacle over the head: one stands, the others gone.
	var cp := Basis(Vector3.UP,PI*0.5*int(p["corner"]))*Vector3(half-1.4,0.0,half-1.4)
	b.solid(RuinKit._box(b,Vector3(1.3,2.5,1.3)),Transform3D(Basis.IDENTITY,cp+Vector3(0.0,TOWER_H+2.5,0.0)),RuinKit._stone(b,1.02))
	RuinKit._spire(b,Transform3D(Basis.IDENTITY,cp+Vector3(0.0,TOWER_H+5.0,0.0)),1.0,11.0,false)
	for i in range(4):
		var a := TAU*i/4.0+b.rng.randf_range(0.3,1.2)
		_heap(b,Vector3(cos(a),0.0,sin(a))*(half+7.0),Vector2(3.0,3.0),3.0,6)
	for i in range(int(6+10.0*weathered)):
		var turn := Basis(Vector3.UP,PI*0.5*b.rng.randi_range(0,3))
		b.hang(turn*Vector3(b.rng.randf_range(-half+3.0,half-3.0),b.rng.randf_range(24.0,TOWER_H-6.0),half+0.3),b.rng.randf_range(4.0,12.0)*weathered,true)
	var node := b.finish()
	_meta(node,"belfry_tower",p)
	return node

# --- 3. The rose gate ----------------------------------------------------------

## The rose gate (`rose_gate`): a standing gable GATE.x*2 (34 m) wide, its
## apex GATE.z (38 m) up, the rose's ring round a ROSE (8 m) opening flown
## through, its spokes fallen; a knife slot down either side.
static func rose_gate(seed_value: int, weathered := 0.6) -> Node3D:
	var p := plan("rose_gate",seed_value,weathered)
	var b := _build(seed_value,weathered,"RoseGate")
	var hw := GATE.x
	var d := GATE.w
	var line := RuinKit._ruin_line(b,-hw,hw,GATE.y-6.0*weathered,GATE.z,weathered*0.6)
	var top := func(x: float) -> float: return minf(float(line.call(x)),lerpf(GATE.z,GATE.y,absf(x)/hw))
	var rr := ROSE*0.5
	var outer := rr+ROSE_RING
	var rose_hole := func(y: float) -> Vector2:
		var dy := y-ROSE_Y
		if absf(dy) >= outer: return Vector2(0.0,-1.0)
		return Vector2(0.0,sqrt(outer*outer-dy*dy))
	var slot_x := _gate_slot_x()
	var inner := slot_x-KNIFE*0.5-1.6
	var outer_run := slot_x+KNIFE*0.5+1.6
	_wall(b,Transform3D.IDENTITY,-inner,inner,top,d,rose_hole)
	for s: float in [-1.0,1.0]:
		var sx := s*slot_x
		_wall(b,Transform3D.IDENTITY,minf(s*inner,s*outer_run),maxf(s*inner,s*outer_run),top,d,_lancet_hole(sx,KNIFE,GATE_SLOT.x,GATE_SLOT.y,0.7))
		_wall(b,Transform3D.IDENTITY,minf(s*outer_run,s*hw),maxf(s*outer_run,s*hw),top,d)
		_jambs(b,Transform3D.IDENTITY,sx,KNIFE,GATE_SLOT.x,GATE_SLOT.y,d,0.7)
		_head(b,Transform3D.IDENTITY,sx,KNIFE,GATE_SLOT.y,0.7,d,4,0,top)
		_sill(b,Transform3D.IDENTITY,sx,KNIFE,GATE_SLOT.x,d)
	# The rose's ring, a deep order and a moulded one on each face.
	RuinKit._circle_ring(b,Transform3D.IDENTITY,Vector2(0.0,ROSE_Y),rr+ROSE_RING*0.5,ROSE_RING*0.5,d,20,0.0)
	for f: float in [-1.0,1.0]:
		RuinKit._circle_ring(b,Transform3D(Basis.IDENTITY,Vector3(0.0,0.0,f*(d+0.2))),Vector2(0.0,ROSE_Y),outer+0.3,0.35,0.2,24,0.3*weathered,top)
	# The gable's ends: a stepped buttress off each face.
	for s: float in [-1.0,1.0]:
		for f: float in [-1.0,1.0]:
			_buttress(b,Transform3D(Basis(Vector3.UP,0.0 if f > 0.0 else PI),Vector3(s*(hw-1.6),0.0,f*d)),[[10.0,3.6],[18.0,2.6],[23.0,1.8]],3.0,false,true)
	for f: float in [-1.0,1.0]:
		_heap(b,Vector3(b.rng.randf_range(-8.0,8.0),0.0,f*(d+4.0)),Vector2(5.0,2.0),2.5,7)
	_grow(b,[Vector3(0.0,ROSE_Y+outer,d),Vector3(0.0,ROSE_Y+outer,-d),Vector3(slot_x,22.0,d),Vector3(-slot_x,22.0,-d)],9.0)
	var node := b.finish()
	_meta(node,"rose_gate",p)
	return node
