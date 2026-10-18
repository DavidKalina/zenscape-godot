extends "res://scripts/kit_isle/motif_greybox.gd"
## The Pilgrim's Ladder (card m1, docs/design/motifs/brainstorm/round3-new-
## kit-isles/motif-m1-pilgrims-ladder.md; plan docs/design/motifs/plans/
## pilgrims-ladder/plan.md, the spec): four sky isles stepped up and east,
## one new piece at each station. Threshold (0) holds the landing strip and
## the torana's jamb on its east lip; the Halo (7) the nimbus; the Crown
## (20) the pent hood on its north rim and, off its south lip, the keel-hung
## stair's plinth down to the Cellar (10), tucked under the Crown's south
## half. Played alone: studies/motif_yard.tscn -- --motif=pilgrims_ladder.
##
## Built on the real terrain from the start: each isle a KitLand island
## (turf, hanging rock, a keel), its flora and life. The layout is the one
## table LAYOUT below; the occupancy is computed from it (`_solids`).
## Plan frame: x east, z south (+Z), y up.

const Torana = preload("res://scripts/ruin_kit_torana.gd")
const Cloister = preload("res://scripts/ruin_kit_cloister.gd")
const Keel = preload("res://scripts/ruin_kit_keel.gd")

const TURF_SEED := 5300
## How far a keel's spurs can hang under top-depth (KitLand ring_sides),
## for the occupancy (as gb_sunken_giant's).
const KEEL_REACH := 1.4

## The layout (the plan's Layout, its numbers): each isle an ellipse at
## `at` (x, z) with radii `r`, flat turf at `top`, its keel `depth` under it,
## `wobble` its outline's ripple (share of the radius). `strip` the landing
## band kept clear (x, z: the plan's strip x -38..-8, z -5..5, and its clear
## band x -45..-3, z -8..8). `paths` the worn ways (flora thins on them).
const LAYOUT := {
	"isles":[
		{"name":"Threshold","at":Vector2(-10.0,0.0),"r":Vector2(40.0,22.0),"top":0.0,"depth":14.0,"wobble":0.06,"seed":0},
		{"name":"Halo","at":Vector2(62.0,0.0),"r":Vector2(12.0,12.0),"top":7.0,"depth":12.0,"wobble":0.08,"seed":1},
		{"name":"Crown","at":Vector2(91.0,0.0),"r":Vector2(16.0,14.0),"top":20.0,"depth":8.0,"wobble":0.07,"seed":2},
		## `cut`: the outline's points inside this rect (x, z) pulled back to
		## its west edge: the hung stair's turn sweeps down to 7.3 under the
		## plinth (x 84..89.4, z 14.9..20.7), so the turf ends at x 83.85
		## there and the flight's foot steps west onto it.
		{"name":"Cellar","at":Vector2(84.0,11.0),"r":Vector2(8.0,8.0),"top":10.0,"depth":7.0,"wobble":0.08,"seed":3,
			"cut":Rect2(83.85,14.0,20.0,20.0)},
	],
	## The stations' pieces: id, seed, weathered, `at` (its foot, world),
	## `rot` (deg about Y), `box` its bounds (piece frame, the occupancy). The torana's jamb stands on Threshold's east
	## lip with its lintel out east toward the Halo; rope 1 (x +3.2 off the
	## jamb, z +1.58) hangs over turf (the lip is at about x 30), the
	## snapped end (x +21.2) about 4 m short of the Halo's west lip, its
	## top 10.5 over the Halo's 7. `dry` the dry rope's index (rope 3).
	"pieces":[
		{"id":"relic_torana","seed":5320,"weathered":0.5,"at":Vector3(25.0,0.0,0.0),"rot":0.0,"ropes":4,"dry":2,
			"box":AABB(Vector3(-3.2,-0.2,-2.4),Vector3(24.4,11.8,4.8))},
		## The nimbus on the Halo, its ring in XY (the plane threads it along
		## Z), set 3 m north of the isle's centre line so the torana's hop
		## lands at about (52..56, 7, 0) in front (+Z) of the ring's lower
		## outer face (x 55.7 at head height), where its trough is stepped
		## into. Box: its mesh AABB.
		{"id":"relic_nimbus","seed":5330,"weathered":0.5,"at":Vector3(62.0,7.0,-3.0),"rot":0.0,
			"box":AABB(Vector3(-10.4,0.0,-2.2),Vector3(19.8,17.3,8.3))},
		## The pent hood along the Crown's north rim: 3 bays (15.6 m), the
		## back wall north (its line z -11.18), eaves south (z -8.3). Seed
		## 5342 puts its one fallen roof gap in the middle bay (piece x
		## -0.41..1.68). Set at x 92, z -10, not the plan's (94, -11): the
		## rim pulls in to z -12 at x 84 and 100 and to -10.5 at x 102, so
		## the plan's east end hung over the void. Box: its mesh AABB.
		{"id":"pent_hood","seed":5342,"weathered":0.5,"at":Vector3(92.0,20.0,-10.0),"rot":0.0,"bays":3,"fallen":1,
			"box":AABB(Vector3(-8.0,-0.14,-3.4),Vector3(16.0,5.3,8.5))},
		## The hung stair, its boss on the plinth's deck (15.5, 4.5 m under
		## the Crown's south lip) at z 18, its hinge 3.2 m under it, hung out
		## south over the void. Turned, its flight lies in the plinth's shaft
		## (x 84..88, z 15..18.2), head (87.8, 12.3) under the deck's hatch,
		## foot (84, 10.06) at the Cellar's cut edge. `plinth`: build it
		## (`plinth`, the stair's frame). Box: the plinth and the turn's sweep.
		{"id":"keel_hung_stair","seed":5350,"weathered":0.5,"at":Vector3(86.0,15.5,18.0),"rot":0.0,"plinth":true,
			"box":AABB(Vector3(-3.2,-8.3,-4.6),Vector3(7.7,8.5,7.4))},
	],
	## The pilgrimage's ruin dressing round the stations (RuinKit pieces,
	## low and broken, weathered 0.7: stumps and walls 2-2.6 m, slabs and
	## chests about 1 m): id, seed, `at` (its foot on the turf, world),
	## `rot` (deg about Y). Kept off the strip's clear band, the walked ways,
	## the gate's flown line (x 22..36 across Threshold), under the ring's
	## opening on the Halo, the Crown's landing, hood and south lip path,
	## and the Cellar's door and west rim.
	"dressing":[
		# Threshold: the precinct before the gate (pier stumps either side
		# of its line), the pilgrims' way flanked by slabs, a wayside shrine
		# north of it (a floor, its back wall and stumps, a fallen pier), a
		# ruined stair and wall south, more fallen stone off the strip.
		{"id":"pier","seed":5401,"at":Vector3(19.0,0.0,-12.0),"rot":15.0},
		{"id":"pier","seed":5402,"at":Vector3(19.0,0.0,12.0),"rot":-20.0},
		{"id":"floor","seed":5403,"at":Vector3(4.0,0.0,-4.8),"rot":4.0},
		{"id":"floor","seed":5404,"at":Vector3(12.0,0.0,5.6),"rot":-6.0},
		{"id":"tomb_chest","seed":5405,"at":Vector3(15.0,0.0,-6.5),"rot":12.0},
		{"id":"floor","seed":5420,"at":Vector3(7.8,0.0,-12.0),"rot":0.0},
		{"id":"floor","seed":5421,"at":Vector3(12.1,0.0,-12.0),"rot":0.0},
		{"id":"wall","seed":5422,"at":Vector3(10.0,0.0,-16.0),"rot":0.0},
		{"id":"pier","seed":5423,"at":Vector3(4.5,0.0,-15.5),"rot":30.0},
		{"id":"fallen_pier","seed":5406,"at":Vector3(1.5,0.0,-10.0),"rot":30.0},
		{"id":"tomb_chest","seed":5424,"at":Vector3(10.0,0.0,-8.4),"rot":0.0},
		{"id":"wall","seed":5408,"at":Vector3(-6.0,0.0,17.0),"rot":8.0},
		{"id":"stairs","seed":5425,"at":Vector3(-11.0,0.0,14.0),"rot":90.0},
		{"id":"fallen_pier","seed":5407,"at":Vector3(-1.0,0.0,12.5),"rot":-25.0},
		{"id":"pier","seed":5426,"at":Vector3(-16.0,0.0,16.0),"rot":-10.0},
		{"id":"wall","seed":5409,"at":Vector3(-22.0,0.0,-15.0),"rot":-5.0},
		{"id":"stairs","seed":5410,"at":Vector3(-32.0,0.0,13.0),"rot":180.0},
		{"id":"tomb_chest","seed":5411,"at":Vector3(-14.0,0.0,-14.0),"rot":-10.0},
		# The Halo: behind the ring (north), off the ways and the Cellar's
		# sail in (it lands about (65.5, 5.7); a stump at (70, 5) caught it),
		# a fallen pier, a chest and a stump.
		{"id":"fallen_pier","seed":5412,"at":Vector3(61.0,7.0,-8.6),"rot":0.0},
		{"id":"tomb_chest","seed":5413,"at":Vector3(68.5,7.0,-6.5),"rot":-30.0},
		{"id":"pier","seed":5414,"at":Vector3(65.0,7.0,-9.5),"rot":40.0},
		# The Crown: the reliquary's chest and its floor east of the middle,
		# a fallen pier toward the east lip.
		{"id":"floor","seed":5415,"at":Vector3(96.5,20.0,3.0),"rot":10.0},
		{"id":"tomb_chest","seed":5416,"at":Vector3(101.0,20.0,0.0),"rot":10.0},
		{"id":"fallen_pier","seed":5417,"at":Vector3(100.0,20.0,7.0),"rot":60.0},
		# The Cellar: a worn floor where the stair lets out.
		{"id":"floor","seed":5418,"at":Vector3(80.0,10.0,8.0),"rot":10.0},
		# The landmarks, taller and less worn (their own `weathered` and
		# `box`, dumped headless): on Threshold a pointed arch left standing
		# north of the strip (15 m off its line, 13 m tall, its span along
		# x), on the Crown a buttress off the east lip. The Halo's is the
		# ring; the Cellar lies under the Crown.
		{"id":"arch","seed":5501,"weathered":0.3,"at":Vector3(-6.0,0.0,-17.5),"rot":0.0,
			"box":AABB(Vector3(-7.6,-0.2,-1.2),Vector3(14.9,14.3,3.0))},
		{"id":"buttress","seed":5501,"weathered":0.3,"at":Vector3(104.5,20.0,2.5),"rot":90.0,
			"box":AABB(Vector3(-1.9,-0.2,-1.9),Vector3(4.4,7.5,3.9))},
	],
	## Trees in clumps (MotifAuthored's hero trees: oak 9 m, birch 7.5,
	## willow 6.5; a trunk collider), at their trunk's foot: Threshold's
	## four corners off the strip's band (12 m and more off its line), the
	## south rim's run-up (x 0..8) and the gate's line; two on the Crown's
	## east, a willow west of the hood and a birch on the south-west. None on the Halo (the plane threads its ring) or the Cellar.
	"trees":[
		{"id":"tree_oak","seed":5601,"at":Vector3(-30.0,0.0,-14.5)},
		{"id":"tree_birch","seed":5602,"at":Vector3(-25.5,0.0,-17.0)},
		{"id":"tree_willow","seed":5603,"at":Vector3(-35.0,0.0,-12.5)},
		{"id":"tree_oak","seed":5604,"at":Vector3(-25.0,0.0,15.5)},
		{"id":"tree_birch","seed":5605,"at":Vector3(-21.0,0.0,18.5)},
		{"id":"tree_willow","seed":5606,"at":Vector3(-28.5,0.0,17.5)},
		{"id":"tree_birch","seed":5607,"at":Vector3(15.5,0.0,-14.5)},
		{"id":"tree_oak","seed":5608,"at":Vector3(11.5,0.0,15.5)},
		{"id":"tree_willow","seed":5609,"at":Vector3(15.0,0.0,12.0)},
		{"id":"tree_oak","seed":5610,"at":Vector3(99.5,20.0,9.5)},
		{"id":"tree_birch","seed":5611,"at":Vector3(104.0,20.0,-4.0)},
		# The Crown's west and south, off its landing (77, 2: 6.4 m and
		# more), the paths and the bird drive's south-lip walk (x 86..93).
		{"id":"tree_willow","seed":5612,"at":Vector3(79.0,20.0,-6.5)},
		{"id":"tree_birch","seed":5613,"at":Vector3(80.5,20.0,8.5)},
	],
	## Bands kept clear of tall flora round the pieces' feet (x, z).
	"clear":[Rect2(20.0,-4.0,11.0,8.0),Rect2(52.0,-6.0,20.0,10.0),Rect2(83.0,-14.0,18.0,9.0),Rect2(79.0,14.0,5.0,5.5)],
	"strip":Rect2(-38.0,-5.0,30.0,10.0),
	"strip_clear":Rect2(-45.0,-8.0,42.0,16.0),
	"paths":[
		[Vector2(-8.0,0.0),Vector2(10.0,1.5),Vector2(26.0,0.0)],
		[Vector2(52.0,1.0),Vector2(60.0,2.0)],
		[Vector2(77.0,2.0),Vector2(84.0,-4.0),Vector2(84.5,-9.5)],
		[Vector2(86.0,4.0),Vector2(86.0,12.0)],
		[Vector2(79.0,12.0),Vector2(84.0,15.0)],
	],
	## The guacharo (scripts/enemies/guacharo.gd, laid by LayerFlyers): home
	## high over the Crown, it hunts once his feet are within `range` (flat)
	## of it: the Crown and the plinth, not the high horn (28 m). `floor`
	## 15: under it (the stair's lower half, the Cellar at 10) he is out of
	## its reach, so the stair down is the escape.
	## `rim_r` 2.5 (default 1.4): it reads the Crown's turf within about
	## 6.4 m of the lip as a rim (hungry), not only the last 3.6 m, so the
	## landing, the hood's front and the south lip are open to it.
	"flyers":[{"home":Vector3(91.0,46.0,0.0),"grace":0.0,"range":22.0,"floor":15.0,"knobs":{"rim_r":2.5}}],
	## The on-foot tokens (the plan's walked collectibles; scripts/kit_isle/
	## greybox/pilgrims_ladder_life.gd lays them): `at` his middle where he
	## stands for it (feet + 0.85, as the kit isles' tokens), `move` the way
	## to it. The stair's foot token is on the Cellar's turf west of the cut
	## (x 83.85), where the turned flight's foot walks out of the plinth's door.
	"tokens":[
		{"name":"niche_sill","at":Vector3(24.3,7.25,0.0),"move":"The slow way: up the offering steps to the jamb's head"},
		{"name":"lintel_end","at":Vector3(45.6,11.2,0.0),"move":"Let go of the fourth rope onto the lintel's broken end"},
		{"name":"high_horn","at":Vector3(62.8,24.95,-3.0),"move":"The twirled leap from the low horn to the high horn"},
		{"name":"reliquary","at":Vector3(99.0,20.85,-10.0),"move":"Creep the hood's gallery to its east end, under the bird"},
		{"name":"stair_foot","at":Vector3(82.9,10.85,16.4),"move":"Slam the hung stair and run its flight down to the Cellar"},
	],
}

func slug() -> String:
	return "pilgrims_ladder"

## The landmark of its neighbourhood.
func role() -> String:
	return "hero"

func isle_name() -> String:
	return "The Pilgrim's Ladder"

func epithet() -> String:
	return "Four stations up into the wind."

func brief() -> String:
	return "Ride the gate's ropes, climb the broken halo to its horns, sail to the Crown.\nKeep under the hood from the bird; slam the hung stair and run it down to the cellar."

## On the strip's east end, facing the torana (the plane parks behind).
func start() -> Vector3:
	return Vector3(-6.0,0.0,0.0)

## Threshold carries a 30 m strip on flat turf.
func landing_run() -> bool:
	return true

## Where the plane stands parked (the motif yard's --plane): on the strip's
## line, behind the start, nosed west down the strip to roll off the west
## lip (x, y, z its turf, w its heading: PI/2 faces -x).
func plane_park() -> Vector4:
	return Vector4(-14.0,0.0,0.0,PI*0.5)

## In off Threshold's west lip (the strip's approach), out off its south
## side, where you come home.
func rims() -> Array:
	return [
		{"name":"threshold_west","at":Vector3(-48.0,0.0,0.0),"face":Vector3(-1.0,0.0,0.0),"run_up":30.0,"lip":1.5},
		{"name":"threshold_south","at":Vector3(4.0,0.0,19.0),"face":Vector3(0.0,0.0,1.0),"run_up":12.0,"lip":1.5},
	]

func spots() -> Array:
	return [
		{"kind":"arena","name":"threshold_lawn","at":Vector3(10.0,0.0,0.0),"room":8.0},
		{"kind":"perch","name":"halo","at":Vector3(56.0,7.0,6.0),"room":3.0},
		{"kind":"perch","name":"crown","at":Vector3(91.0,20.0,2.0),"room":5.0},
		{"kind":"perch","name":"cellar","at":Vector3(80.0,10.0,13.0),"room":3.0},
	]

# --- The land ----------------------------------------------------------------------------

static func isle(name: String) -> Dictionary:
	for i: Dictionary in LAYOUT.isles:
		if i.name == name: return i
	return {}

## An isle's outline: its ellipse, rippled by two low waves (seeded by its
## index), 64 points.
static func outline_of(i: Dictionary) -> Array:
	var out: Array = []
	var c: Vector2 = i.at
	var r: Vector2 = i.r
	var w := float(i.wobble)
	var s := float(i.seed)*1.7
	for k in 64:
		var a := TAU*k/64.0
		var ripple := 1.0+w*(0.6*sin(3.0*a+s)+0.4*sin(5.0*a+s*2.3))
		var p := c+Vector2(cos(a)*r.x,sin(a)*r.y)*ripple
		if i.has("cut") and (i.cut as Rect2).has_point(p): p.x = (i.cut as Rect2).position.x
		out.append(p)
	return out

## The worn ways, plus the strip lightly worn so nothing tall grows on it.
static func wear(p: Vector2) -> float:
	var w: float = KitLand.wear_of(LAYOUT.paths).call(p)
	if (LAYOUT.strip_clear as Rect2).has_point(p): w = maxf(w,0.12)
	for r: Rect2 in LAYOUT.clear:
		if r.has_point(p): w = maxf(w,0.12)
	return w

## Turf tone wear: the paths only (the strip stays green, read as a lawn).
static func tone_wear(p: Vector2) -> float:
	return KitLand.wear_of(LAYOUT.paths).call(p)

func flora_site() -> KitFlora.Site:
	var site := KitFlora.Site.new(top(),func(p: Vector2) -> float: return wear(p))
	site.ray = Vector2(20.0+60.0,-8.0)
	return site

func flora_seed() -> int:
	return TURF_SEED+9

## The kit isles' life plus its tokens (loaded, not preloaded: it reads
## this script's LAYOUT).
func life_script() -> Script:
	return load("res://scripts/kit_isle/greybox/pilgrims_ladder_life.gd")

## The place's guacharos ([{home, grace, range}], this frame): the motif
## yard lays them (studies/motif_yard.gd `yard_plan`).
func flyers() -> Array:
	return LAYOUT.flyers

func summit() -> Vector3:
	return Vector3(91.0,20.0,0.0)

func warm() -> void:
	super.warm()
	KitLook.palette()
	KitLook.ground_material()
	KitLook.rock_material()
	KitLook.rock_tone(Vector3.ZERO,30.0,Vector3.UP)
	RuinKit.materials()

## Each isle's box from its keel's reach to its top.
func _solids() -> Array:
	var out: Array = []
	for i: Dictionary in LAYOUT.isles:
		var ring := outline_of(i)
		var box := Rect2(ring[0],Vector2.ZERO)
		for p: Vector2 in ring: box = box.expand(p)
		out.append([box.grow(-1.0),float(i.top)-float(i.depth)*KEEL_REACH,float(i.top),null])
	for p: Dictionary in LAYOUT.dressing:
		var b: AABB = pose(p)*(p.get("box",DRESS_BOX) as AABB)
		out.append([Rect2(b.position.x,b.position.z,b.size.x,b.size.z),b.position.y,b.end.y,null])
	for t: Dictionary in LAYOUT.trees:
		var b := AABB(t.at+TREE_BOX.position,TREE_BOX.size)
		out.append([Rect2(b.position.x,b.position.z,b.size.x,b.size.z),b.position.y,b.end.y,null])
	for p: Dictionary in LAYOUT.pieces:
		var b: AABB = pose(p)*(p.box as AABB)
		out.append([Rect2(b.position.x,b.position.z,b.size.x,b.size.z),b.position.y,b.end.y,null])
	return out

## A guess until measured headless.
func build_cost() -> int:
	return 700

func build(into: Node3D) -> void:
	art = into
	var began := Time.get_ticks_msec()
	var root := Node3D.new()
	root.name = "PilgrimsLadder"
	into.add_child(root)
	var tone := KitLook.turf(TURF_SEED,func(p: Vector2) -> float: return tone_wear(p))
	for i: Dictionary in LAYOUT.isles:
		var y := float(i.top)
		var land := KitLand.island({"outline":outline_of(i),"seed":TURF_SEED+int(i.seed),
			"ground":func(_x: float, _z: float) -> float: return y,
			"top":y,"depth":float(i.depth),"hang":true,"resample":[60.0,200,64],"tone":tone})
		land.name = str(i.name)
		_collide_sides(land)
		root.add_child(land)
		turf(land)
	_pieces(root)
	_dress(root)
	built_ms = Time.get_ticks_msec()-began

## The stations' pieces (LAYOUT.pieces), each at its foot and turn.
func _pieces(root: Node3D) -> void:
	for p: Dictionary in LAYOUT.pieces:
		var node := piece_of(p)
		if node == null: continue
		node.name = str(p.id)
		node.transform = pose(p)
		_specs["%s/%d" % [str(p.id),int(p.seed)]] = node.get_meta("ropes",[])
		root.add_child(node)
		if p.get("plinth",false):
			var built := plinth(int(p.seed)+7,float(p.weathered))
			built.transform = pose(p)
			root.add_child(built)

## The ruin dressing (LAYOUT.dressing), each piece at its foot and turn.
## DRESS_BOX: the bounds any of them keeps within (piece frame; dumped
## headless at weathered 0.7: the walls and fallen piers reach 3.7 m out,
## the stumps and stairs 2.8 m up), for the occupancy.
const DRESS := 0.7
const DRESS_BOX := AABB(Vector3(-3.8,-0.25,-3.8),Vector3(7.6,3.0,7.6))
## A tree's occupancy (its crown's middle, the tallest, an oak, at 1.15)
## and how far its trunk's foot sinks into the turf.
const TREE_BOX := AABB(Vector3(-2.5,-0.2,-2.5),Vector3(5.0,10.6,5.0))
const TREE_SINK := 0.15
func _dress(root: Node3D) -> void:
	var holder := Node3D.new()
	holder.name = "Dressing"
	root.add_child(holder)
	for p: Dictionary in LAYOUT.dressing:
		var node := RuinKit.piece(str(p.id),int(p.seed),float(p.get("weathered",DRESS)))
		if node == null: continue
		node.name = "%s_%d" % [str(p.id),int(p.seed)]
		node.transform = pose(p)
		holder.add_child(node)
	var Authored: Script = load("res://scripts/kit_isle/motif_authored.gd")
	for t: Dictionary in LAYOUT.trees:
		var tree: Node3D = Authored.tree(str(t.id),int(t.seed))
		tree.name = "%s_%d" % [str(t.id),int(t.seed)]
		tree.position = (t.at as Vector3)+Vector3(0.0,-TREE_SINK,0.0)
		holder.add_child(tree)

## A piece of LAYOUT.pieces built (the torana with its rope count and dry
## rope; the hood with its bays and fallen count; the others by
## RuinKit.piece).
static func piece_of(p: Dictionary) -> Node3D:
	if p.id == "relic_torana":
		return Torana.torana(int(p.seed),float(p.weathered),int(p.get("ropes",4)),Torana.TILT,int(p.get("dry",-1)))
	if p.id == "pent_hood":
		return Cloister.pent_hood(int(p.seed),float(p.weathered),int(p.get("bays",Cloister.HOOD_BAYS)),int(p.get("fallen",-1)))
	return RuinKit.piece(str(p.id),int(p.seed),float(p.weathered))

## The hung stair's plinth, in the stair's frame (the boss at the origin on
## the deck's top, y 0; the hinge along +X 3.2 m under it at z 0; the
## turned flight on its -Z side). Clear of the turn's sweep (x -2.01..3.40,
## z -3.11..2.73, y -8.23..-2.77, dumped headless): a deck of slabs with a
## hatch over the flight's head, a north wall against the Crown's flank,
## an east wall, a lintel over the west door (the flight's foot walks out
## under it onto the Cellar) and a fascia on the south; under the deck the
## south side is open, where the hung flight swings out. The shaft's floor
## east of the head, flush with its top, its lip cut on the stair's
## `head_cut` (nothing of the turn crosses it): hung or turned, a drop
## through the hatch's east half lands on stone.
const PLINTH_DECK := 0.36
const PLINTH := {"x":Vector2(-3.0,4.4),"z":Vector2(-4.6,1.3),"hatch_x":Vector2(0.4,2.8),"hatch_z":Vector2(-2.9,-0.75),
	"north":-3.28,"east":3.62,"low":-7.2,"lintel":-2.4,"fascia":-1.3,"floor":Vector2(-3.75,-3.2)}
static func plinth(seed_value: int, weathered: float) -> Node3D:
	var b := RuinKit.Build.new(seed_value,weathered,"Plinth")
	b.settle = 0.4
	var P: Dictionary = PLINTH
	var x: Vector2 = P.x
	var z: Vector2 = P.z
	var hx: Vector2 = P.hatch_x
	var hz: Vector2 = P.hatch_z
	var top := -PLINTH_DECK
	# The deck round the hatch: north and south strips the deck's width, the
	# west and east between them.
	for r: Array in [[x.x,x.y,z.x,hz.x],[x.x,x.y,hz.y,z.y],[x.x,hx.x,hz.x,hz.y],[hx.y,x.y,hz.x,hz.y]]:
		_slabs(b,Rect2(r[0],r[2],r[1]-r[0],r[3]-r[2]),top,0.0)
	# The walls in courses of long stones: north (against the Crown), east.
	_courses(b,Vector3(x.x,float(P.low),z.x),Vector3(x.y,top,float(P.north)),true)
	_courses(b,Vector3(float(P.east),float(P.low),float(P.north)),Vector3(x.y,top,z.y),false)
	# The west door's lintel and the south fascia, both over the sweep.
	_courses(b,Vector3(x.x,float(P.lintel),float(P.north)),Vector3(x.x+0.8,top,z.y),false)
	_courses(b,Vector3(x.x+0.8,float(P.fascia),z.y-0.5),Vector3(float(P.east),top,z.y),true)
	# The shaft's floor at the head, its lip on the head cut.
	var fy: Vector2 = P.floor
	var hc: Plane = Keel.flight_frame()*Keel.head_cut()
	var c := Vector3((1.6+float(P.east))*0.5,(fy.x+fy.y)*0.5,(float(P.north)-0.05)*0.5)
	var planes: Array[Plane] = [Plane(Vector3.LEFT,-1.4),Plane(Vector3.RIGHT,float(P.east)),Plane(Vector3.DOWN,-fy.x),
		Plane(Vector3.UP,fy.y),Plane(Vector3.FORWARD,-float(P.north)),Plane(Vector3.BACK,-0.05),Plane(-hc.normal,-(hc.d+0.05))]
	var local: Array[Plane] = []
	for q: Plane in planes: local.append(Plane(q.normal,q.d-q.normal.dot(c)))
	b.solid(local,Transform3D(Basis.IDENTITY,c),RuinKit._stone(b,0.9))
	_plinth_growth(b)
	return b.finish()

## Vines down the plinth's faces (its near-black shadow sides): clumps of
## strands (RuinGrowth.strand, hugging the stone) from under the deck's
## edge, long on the east wall and the north wall's open ends, short over
## the west door and the south fascia (over the flight's swing; never
## collided). Grown after every stone, the stones' draw left as it was
## (the rng's state put back), the ground let down under the walls' feet
## only while they grow.
## Each clump: [start (x, z on the face), out (the face's way), along, strands, longest].
const PLINTH_VINES := [
	[Vector2(4.47,-2.6),Vector3.RIGHT,Vector3.BACK,9,5.5],[Vector2(4.47,0.3),Vector3.RIGHT,Vector3.BACK,7,4.0],
	[Vector2(-3.07,-3.9),Vector3.LEFT,Vector3.BACK,5,5.0],
	[Vector2(-1.9,1.37),Vector3.BACK,Vector3.RIGHT,7,1.1],[Vector2(1.6,1.37),Vector3.BACK,Vector3.RIGHT,6,1.0],
	[Vector2(-3.07,-1.0),Vector3.LEFT,Vector3.BACK,6,1.6],[Vector2(-3.07,0.7),Vector3.LEFT,Vector3.BACK,5,1.8],
	[Vector2(-3.07,-2.5),Vector3.LEFT,Vector3.BACK,4,1.4],
	[Vector2(0.6,-3.21),Vector3.BACK,Vector3.RIGHT,8,3.6],[Vector2(-2.0,-3.21),Vector3.BACK,Vector3.RIGHT,7,5.0],
	[Vector2(2.7,-3.21),Vector3.BACK,Vector3.RIGHT,6,4.5],
]
static func _plinth_growth(b: RuinKit.Build) -> void:
	var state := b.rng.state
	b.terrain = func(_x: float, _z: float) -> float: return float(PLINTH.low)-1.0
	for v: Array in PLINTH_VINES:
		var at: Vector2 = v[0]
		var out: Vector3 = v[1]
		var along: Vector3 = v[2]
		var n := int(v[3])
		for j in range(n):
			var t := (j+0.5)/n
			var start := Vector3(at.x,-PLINTH_DECK-0.04,at.y)+along*(t-0.5)*n*0.17
			var l := float(v[4])*(0.45+0.55*sin(PI*t))*b.rng.randf_range(0.7,1.1)
			RuinKit.RuinGrowth.strand(b,start,l,out,false)
	b.terrain = Callable()
	b.rng.state = state

## A run of slabs filling `r` (x, z) from y0 to y1.
static func _slabs(b: RuinKit.Build, r: Rect2, y0: float, y1: float) -> void:
	var zz := r.position.y
	while zz < r.end.y-0.05:
		var d := minf(b.rng.randf_range(0.8,1.3),r.end.y-zz)
		if r.end.y-(zz+d) < 0.35: d = r.end.y-zz
		var xx := r.position.x
		while xx < r.end.x-0.05:
			var w := minf(b.rng.randf_range(0.9,1.7),r.end.x-xx)
			if r.end.x-(xx+w) < 0.35: w = r.end.x-xx
			var half := Vector3(w*0.5-0.02,(y1-y0)*0.5,d*0.5-0.02)
			var at := Vector3(xx+w*0.5,(y0+y1)*0.5+b.rng.randf_range(-0.03,0.0),zz+d*0.5)
			b.solid(RuinKit._box(b,half),RuinKit._jiggle(b,Transform3D(Basis.IDENTITY,at),0.3),RuinKit._stone(b,1.0))
			xx += w
		zz += d

## A wall from `lo` to `hi` in courses (0.5-0.7 m) of stones laid along X
## (`along_x`) or Z, each course's joints offset.
static func _courses(b: RuinKit.Build, lo: Vector3, hi: Vector3, along_x: bool) -> void:
	var y := lo.y
	var row := 0
	while y < hi.y-0.05:
		var h := minf(b.rng.randf_range(0.5,0.7),hi.y-y)
		if hi.y-(y+h) < 0.25: h = hi.y-y
		var a0 := lo.x if along_x else lo.z
		var a1 := hi.x if along_x else hi.z
		var s := a0
		var first := true
		while s < a1-0.05:
			var l := minf(b.rng.randf_range(0.9,1.6)*(0.5 if first and row%2 == 1 else 1.0),a1-s)
			if a1-(s+l) < 0.4: l = a1-s
			first = false
			var mid := Vector3(s+l*0.5,y+h*0.5,(lo.z+hi.z)*0.5) if along_x else Vector3((lo.x+hi.x)*0.5,y+h*0.5,s+l*0.5)
			var half := Vector3(l*0.5-0.02,h*0.5-0.01,(hi.z-lo.z)*0.5) if along_x else Vector3((hi.x-lo.x)*0.5,h*0.5-0.01,l*0.5-0.02)
			b.solid(RuinKit._box(b,half),RuinKit._jiggle(b,Transform3D(Basis.IDENTITY,mid),0.25),RuinKit._stone(b,0.96))
			s += l
		y += h
		row += 1

static func pose(p: Dictionary) -> Transform3D:
	return Transform3D(Basis(Vector3.UP,deg_to_rad(float(p.rot))),p.at)

## The torana's prayer ropes, hung live where it stands (its "ropes" meta
## through the host's `rope`; the dry one dried, a tag beside each).
func live(g: Node) -> void:
	var Authored: Script = load("res://scripts/kit_isle/motif_authored.gd")
	for p: Dictionary in LAYOUT.pieces:
		var specs := _rope_specs(p)
		if specs.is_empty(): continue
		var frame := pose(p)
		frame.origin = g.w(frame.origin)
		Authored.hang_ropes(specs,frame,Callable(g,"rope"))

## A piece's "ropes" meta (built once per id and kept).
static var _specs := {}
static func _rope_specs(p: Dictionary) -> Array:
	var key := "%s/%d" % [str(p.id),int(p.seed)]
	if not _specs.has(key):
		var node := piece_of(p)
		_specs[key] = node.get_meta("ropes",[]) if node != null else []
		if node != null: node.free()
	return _specs[key]

## An island's hanging sides collided as drawn (as gb_sunken_giant's): a
## fall past a flank meets it.
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
