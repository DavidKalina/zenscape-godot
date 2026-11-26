extends Node3D
## Cracked walls (docs/design/endless-flight/spec-wilderness-demo.md, lane
## `roll`): a stone chamber standing in the land, sealed, a black gash down the
## wall at each end. A surge roll (scripts/endless/surge_smash.gd) breaks either
## wall and flies on; once inside, it stays hot till it's out the other end, so
## the far wall goes too. Nothing else opens one.
##
## The contract:
##   place(name, at, yaw)   a chamber, `name` its stable handle `cracked/<place>`
##                          (a move in the layout file wins, as ever), `at` world
##                          XZ of the front wall's middle, `yaw` radians: the
##                          front faces local +Z, the chamber runs back to -Z
##   signal broken(name)    once, the first time either of its walls breaks
##   is_broken(name)        whether it's been broken
##   mark_broken(name)      open already, no signal (a saved book's: the book's
##                          `opened` holds each one broken, and `place` reads it)
##   chamber_at(name)       the middle of the room (world), for a thing inside it
##
## Each stands from REACH m, built on a worker (RuinKit pieces of its own: the
## walls `build_wall`, the room `build_room`), and its stone is the flight's solid
## through LandArches `loose`. Sized from toy widths through WorldScale.

const RuinKit = preload("res://scripts/ruin_kit.gd")
const Build = RuinKit.Build
const BoxSolid = preload("res://scripts/endless/box_solid.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const LayoutOverrides = preload("res://scripts/layout_overrides.gd")

signal broken(name: String)

## Every wall in the land: the finds' relics stand in their rooms (`chamber/<place>`).
const SITES := [
	{"name":"cracked/start-east","at":Vector2(510.9,-20.3),"yaw":-1.373},
	{"name":"cracked/start-north","at":Vector2(430.9,-740.3),"yaw":-0.38},
	{"name":"cracked/gorge","at":Vector2(-2041.0,-977.0),"yaw":0.785},
	{"name":"cracked/tarn","at":Vector2(-3425.0,-700.0),"yaw":0.0},
	{"name":"cracked/long-isle","at":Vector2(621.0,3537.0),"yaw":-2.356},
	{"name":"cracked/south-scarp","at":Vector2(-1130.0,2800.0),"yaw":2.356},
	{"name":"cracked/high-shelf","at":Vector2(-1870.0,-1630.0),"yaw":4.32},
	{"name":"cracked/north-downs","at":Vector2(710.0,-2990.0),"yaw":0.785},
	{"name":"cracked/east-shore","at":Vector2(3290.0,430.0),"yaw":2.749},
	{"name":"cracked/west-gorge","at":Vector2(-5476.0,2408.0),"yaw":1.571},
]
## The room's clear size, in toy widths (WorldScale `opening`): across, high, long.
const TOY_WIDE := 7.0
const TOY_HIGH := 4.5
const TOY_LONG := 14.0
const THICK := 1.4
## The walls' footing under the land (m), the courses' height.
const FOOT := 6.0
const COURSE := 0.8
const WEATHERED := 0.5
## Stands within REACH m of the eye, gone past FREE; its cuts are made within CUT.
const REACH := 2400.0
const FREE := 2800.0
const CUT := 700.0

var game: Node3D
var smash: Node3D
## handle -> {name, xf, wide, high, long, seed, node, state ("away", "building",
## "up"), task, made, open, room, walls, records}.
var sites := {}

func setup(g: Node3D, s: Node3D) -> void:
	game = g
	smash = s
	for site: Dictionary in SITES: place(site.name,site.at,site.yaw)

## A chamber at `at` (world XZ), turned `yaw`: see the header.
func place(handle: String, at: Vector2, yaw: float) -> void:
	var y := float(game.field.height(at.x,at.y))
	var coded := Transform3D(Basis(Vector3.UP,yaw),Vector3(at.x,y,at.y))
	sites[handle] = {"name":handle,"xf":LayoutOverrides.xform(handle,coded),"coded":coded,
		"wide":WorldScale.opening(TOY_WIDE),"high":WorldScale.opening(TOY_HIGH),"long":WorldScale.opening(TOY_LONG),
		"seed":absi(hash(handle))%100000,"state":"away","open":false,"records":[],"walls":{},"task":-1}
	if game.book.opened.has(handle): mark_broken(handle)

func is_broken(handle: String) -> bool:
	return bool((sites.get(handle,{}) as Dictionary).get("open",false))

## Open already (a saved book's), no signal: it stands with both walls gone.
func mark_broken(handle: String) -> void:
	if not sites.has(handle): return
	var site: Dictionary = sites[handle]
	site.open = true
	for part: String in (site.walls as Dictionary).keys(): _drop_wall(site,part)

## The middle of the room (world).
func chamber_at(handle: String) -> Vector3:
	var site: Dictionary = sites[handle]
	return (site.xf as Transform3D)*Vector3(0.0,float(site.high)*0.45,-float(site.long)*0.5)

## One frame: chambers streamed round the eye, cuts made ahead.
func step(eye: Vector3) -> void:
	for handle: String in sites:
		var site: Dictionary = sites[handle]
		var d := (site.xf as Transform3D).origin.distance_to(eye)
		match str(site.state):
			"away":
				if d < REACH: _begin(site)
			"building":
				if WorkerThreadPool.is_task_completed(int(site.task)): _commit(site)
			"up":
				if d > FREE: _free(site)
				elif d < CUT and not bool(site.get("cutting",false)):
					site.cutting = true
					for part: String in site.walls: smash.breaks._ready_job(int(site.walls[part].target),Vector3.INF)

## The plane's breaking wall record `r` at `q`: its solid gone now, the stone by
## the hub's hit that follows (SurgeSmash `_hit`). The signal, the first time.
func strike(r: Dictionary, q: Vector3) -> void:
	var site: Dictionary = r.site
	_drop_solid(site,str(r.part))
	var speed := maxf(float(game.plane.velocity.length()),10.0)
	smash.keep_hot(float(site.long)/speed+0.5)
	if bool(site.open): return
	site.open = true
	game.book.open_up(str(site.name))
	broken.emit(str(site.name))

# --- Building ----------------------------------------------------------------

func _begin(site: Dictionary) -> void:
	site.state = "building"
	Build.materials()
	site.task = WorkerThreadPool.add_task(_make.bind(site),false,"Cracked wall")

## On a worker: the pieces, off the tree.
func _make(site: Dictionary) -> void:
	var w := float(site.wide)
	var h := float(site.high)
	var l := float(site.long)
	var s := int(site.seed)
	var made := {"room":build_room(s,WEATHERED,w,h,l),"front":build_wall(s+1,WEATHERED,w,h),"back":build_wall(s+2,WEATHERED,w,h)}
	# Their hulls freed here, off the tree, on the worker that made them: boxes
	# stand in (`_commit`). Freed on the main thread they cost ~6 ms for the
	# room's ~1200 shapes and ~1 ms a wall, in one frame of the flight.
	for piece: Node3D in made.values(): _drop_hulls(piece)
	site.made = made

## A built piece's hull bodies freed (it is off the tree).
static func _drop_hulls(piece: Node3D) -> void:
	for old in piece.find_children("*","StaticBody3D",true,false):
		old.get_parent().remove_child(old)
		old.free()

## The kit's own, for the wall and the room: a Build as the gothic pieces' are.
static func _build(s: int, weathered: float, label: String) -> RuinKit.Build:
	var b := Build.new(s,weathered,label)
	b.settle = 0.4
	return b

## A wall `w`+2 thick across, `h` to its worn head, its crack a real gap in the
## courses, wandering, widest low down, open at the head: dark on the room behind.
static func build_wall(s: int, weathered: float, w: float, h: float) -> Node3D:
	var b := _build(s,weathered,"Cracked wall")
	var half := w*0.5+THICK
	var crack := _crack(s,h,w)
	RuinKit._courses(b,Transform3D.IDENTITY,-half,half,-FOOT,RuinKit._worn_top(b,-half,half,h+THICK,0.4),THICK*0.5,crack,COURSE)
	RuinKit._drift(b,Vector3(0.0,0.0,THICK*0.5+1.4),3.2,9)
	RuinKit._rubble(b,half*0.7,5)
	return b.finish()

## The gap at height `y`: Vector2(middle x, half width), half < 0 none. A zigzag
## down the wall, closed at the foot.
static func _crack(s: int, h: float, w: float) -> Callable:
	var lean := -0.16 if s%2 == 0 else 0.16
	var a := float(s%7)
	var top := h+THICK+1.0
	return func(y: float) -> Vector2:
		if y < 0.9: return Vector2(0.0,-1.0)
		var t := clampf(y/top,0.0,1.0)
		var x := (t-0.45)*w*lean*3.0+sin(y*1.15+a)*0.9+sin(y*2.3+a*2.0)*0.4
		var open := 0.95*sin(PI*pow(t,0.62))+0.25
		return Vector2(x,open*(1.0+0.35*sin(y*3.1+a)))

## The room: its two long walls and a roof of slabs, the ends left to the walls.
static func build_room(s: int, weathered: float, w: float, h: float, l: float) -> Node3D:
	var b := _build(s,weathered,"Chamber")
	var half := l*0.5
	var mid := Vector3.BACK*(-half)
	for side: float in [-1.0,1.0]:
		var pose := Transform3D(Basis(Vector3.UP,PI*0.5),mid+Vector3.RIGHT*side*(w*0.5+THICK*0.5))
		RuinKit._courses(b,pose,-half,half,-FOOT,RuinKit._worn_top(b,-half,half,h+THICK,0.4),THICK*0.5,Callable(),COURSE)
	var slab := 3.2
	var z := -l
	while z < -0.01:
		var x := -w*0.5-THICK
		while x < w*0.5+THICK-0.01:
			var size := Vector3(slab*0.5-0.02,THICK*0.5,slab*0.5-0.02)
			b.solid(RuinKit._box(b,size),Transform3D(Basis.IDENTITY,Vector3(x+slab*0.5,h+THICK*0.5,z+slab*0.5)),RuinKit._stone(b,0.97))
			x += slab
		z += slab
	return b.finish()

## On the main thread: the pieces in the tree, their colliders and solids.
func _commit(site: Dictionary) -> void:
	WorkerThreadPool.wait_for_task_completion(int(site.task))
	site.task = -1
	var xf: Transform3D = site.xf
	var w := float(site.wide)
	var h := float(site.high)
	var l := float(site.long)
	var made: Dictionary = site.made
	site.erase("made")
	var root := Node3D.new()
	root.name = str(site.name).replace("/","_")
	root.transform = xf
	add_child(root)
	site.node = root
	LayoutOverrides.track(str(site.name),root,"piece",site.coded)
	var top := h+THICK
	var outer := w*0.5+THICK
	var room: Node3D = made.room
	_tidy(room)
	root.add_child(room)
	var boxes := [AABB(Vector3(-outer,-FOOT,-l),Vector3(THICK,top+FOOT,l)),AABB(Vector3(outer-THICK,-FOOT,-l),Vector3(THICK,top+FOOT,l)),
		AABB(Vector3(-outer,h,-l),Vector3(outer*2.0,THICK,l))]
	_body(root,"Room",boxes)
	site.records = [_record(site,"room",boxes)]
	game.arches.loose.append(site.records[0])
	GroundNative.bump_loose()
	if bool(site.open):
		(made.front as Node).free()
		(made.back as Node).free()
		site.state = "up"
		return
	for part: String in ["front","back"]:
		var wall: Node3D = made[part]
		_tidy(wall)
		var at := Transform3D.IDENTITY
		var z := -THICK*0.5
		if part == "back":
			at = Transform3D(Basis(Vector3.UP,PI),Vector3(0.0,0.0,-l))
			z = -l+THICK*0.5
		wall.transform = at
		root.add_child(wall)
		wall.set_meta("break_kind","cracked")
		var box := AABB(Vector3(-outer,-FOOT,z-THICK*0.5),Vector3(outer*2.0,top+FOOT,THICK))
		var body := _body(root,part,[box])
		var record := _record(site,part,[box])
		game.arches.loose.append(record)
		GroundNative.bump_loose()
		var rebuild := func() -> Node3D: return build_wall(int(site.seed)+(1 if part == "front" else 2),WEATHERED,w,h)
		var target: int = smash.breaks.add(wall,"cracked",rebuild,int(site.seed))
		smash.breaks.targets[target].threaded = true
		(site.walls as Dictionary)[part] = {"node":wall,"body":body,"record":record,"target":target}
	site.state = "up"

## A built piece's stone as the land's ruins' (its hulls already off, `_make`).
func _tidy(piece: Node3D) -> void:
	_drop_hulls(piece)
	game.arches._sunlit(piece,false,false,global_position)

func _body(root: Node3D, label: String, boxes: Array) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.collision_layer = game.arches.LAYER
	body.collision_mask = 0
	for box: AABB in boxes:
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box.size
		cs.shape = shape
		cs.position = box.get_center()
		body.add_child(cs)
	root.add_child(body)
	return body

func _record(site: Dictionary, part: String, boxes: Array) -> Dictionary:
	var xf: Transform3D = site.xf
	var yaw := xf.basis.get_euler().y
	var record := {"name":"%s/%s" % [site.name,part],"kind":"cracked","node":site.node,"pos":xf.origin,"cos":cos(yaw),"sin":sin(yaw),
		"solid":BoxSolid.build(boxes),"reach":float(site.long)+float(site.wide)+BoxSolid.grow_most()+10.0,"spec":{},"site":site,"part":part}
	if part != "room": record["wall"] = true
	else: record["no_break"] = true
	return record

## A wall's solid and collider gone; its stone stays for the break.
func _drop_solid(site: Dictionary, part: String) -> void:
	var wall: Dictionary = (site.walls as Dictionary).get(part,{})
	if wall.is_empty(): return
	game.arches.loose.erase(wall.record)
	GroundNative.bump_loose()
	if is_instance_valid(wall.body): (wall.body as Node).queue_free()

## A wall gone altogether.
func _drop_wall(site: Dictionary, part: String) -> void:
	_drop_solid(site,part)
	var wall: Dictionary = (site.walls as Dictionary).get(part,{})
	if not wall.is_empty() and is_instance_valid(wall.node): (wall.node as Node).queue_free()
	(site.walls as Dictionary).erase(part)

func _free(site: Dictionary) -> void:
	for part: String in (site.walls as Dictionary).keys(): _drop_solid(site,part)
	for r: Dictionary in site.records: game.arches.loose.erase(r)
	GroundNative.bump_loose()
	site.records = []
	site.walls = {}
	site.erase("cutting")
	if site.has("node") and is_instance_valid(site.node): (site.node as Node).queue_free()
	LayoutOverrides.entries.erase(site.name)
	site.state = "away"

func _exit_tree() -> void:
	for handle: String in sites:
		var site: Dictionary = sites[handle]
		if int(site.task) >= 0: WorkerThreadPool.wait_for_task_completion(int(site.task))
		site.task = -1
