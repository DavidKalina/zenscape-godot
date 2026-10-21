extends Node3D
## Home's hub (docs/design/home-isle/handoff.md, Round: hub): land round
## home (studies/heist_home.gd) to take off into and fly round, under,
## through and between, all in sight of home's strip. Built under home as
## its node "Hub", after home's land, from home's strip as it stands (its
## middle, its way), so it follows the strip wherever home lays it:
##   gate     a wide rock arch (scripts/rock_arch.gd) off the climb-out's
##            side, its hole facing the strip: through it on takeoff
##   ridge    a mountain (scripts/mountain_massif.gd, scripts/
##            landform_mountains.gd's recipe, grown, no snow, no hut) on
##            home's dry side, its pass (the col) turned to run out from
##            home, cut WorldScale.opening(TOY_PASS) wide
##   shaft    a sea-cliff tableland (scripts/sea_cliffs.gd) with a hole
##            through it to dive down
##   stacks   sea-cliff stacks standing at staggered heights off the
##            climb-out's other side: a slalom
##   downs    rolling hills (scripts/landform_hills.gd's recipe, grown)
##            low on the lake's side, to skim
##   needle   a snug arch at the downs' far end, low
##   window   a high arch on the way back, its hole facing the strip
## Every opening is sized by its toy width (AGENTS.md Sizes, the TOY_
## consts). Each piece keeps out of the strip's approach and climb-out (a
## corridor CORRIDOR m off each end, widening), off home's land, its lake
## and fall, and off the landmarks: one that would stand in one is moved
## out, away from the strip's line, until it doesn't.
## Pieces are named `home/hub/<piece>` (scripts/layout_overrides.gd); an
## arch's knobs are its tunes. `--no-hub` builds none of it.

const SkyIslet = preload("res://scripts/sky_islet.gd")
const SkyIslets = preload("res://scripts/sky_islets.gd")
const LandformMountains = preload("res://scripts/landform_mountains.gd")
const LandformHills = preload("res://scripts/landform_hills.gd")
const SeaCliffs = preload("res://scripts/sea_cliffs.gd")
const RockArch = preload("res://scripts/rock_arch.gd")
const RockLooks = preload("res://scripts/rock_looks.gd")
const LineBuild = preload("res://scripts/hall_line_build.gd")
const Layout = preload("res://scripts/layout_overrides.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")

## The openings' toy widths (WorldScale.opening: 2x at the plane's size).
const TOY_GATE := 16.0
const TOY_WINDOW := 11.0
const TOY_NEEDLE := 7.0
const TOY_PASS := 10.0
const TOY_NOTCH := 8.0
const TOY_HOOP := 9.0
const TOY_SHAFT := 15.0
## The strip's approach and climb-out kept clear: off each end LONG m,
## HALF m either side of its line at the end, widening WIDEN m a metre out.
const CORRIDOR := Vector3(400.0,35.0,0.22)
## Kept this far (m) off home's land, its lake and fall, and a landmark.
const KEEP_HOME := 25.0
const KEEP_FALL := 45.0
const KEEP_LANDMARK := 30.0
## A piece in the way is moved out NUDGE m at a time, at most NUDGES times.
const NUDGE := 10.0
const NUDGES := 30

## The pieces, in the strip's frame: (u along the strip's way from its
## middle, the takeoff end +; v across it, + home's dry side, - the lake's;
## y off home's strip top), and the way its hole looks (deg off the strip's
## way, toward +v), or for "at" (the strip-frame point) the hole's axis
## pointed toward.
## [name, kind, (u, v, y), aim, spec]
const PIECES := [
	["gate","arch",Vector3(240.0,115.0,-6.0),Vector2(75.0,0.0),{"seed":11,"toy":TOY_GATE,"tall":0.8,"deep":12.0,"leg":0.42,"rib":0.3,"keel":0.9}],
	["window","arch",Vector3(-255.0,-150.0,40.0),Vector2(0.0,0.0),{"seed":23,"toy":TOY_WINDOW,"tall":1.1,"deep":10.0,"leg":0.5,"rib":0.4,"keel":1.3}],
	["hoop","arch",Vector3(160.0,200.0,4.0),Vector2(60.0,280.0),{"seed":53,"toy":TOY_HOOP,"tall":1.0,"deep":9.0,"leg":0.55,"rib":0.45,"keel":1.1}],
	["needle","arch",Vector3(-255.0,-300.0,-30.0),Vector2(-600.0,-300.0),{"seed":37,"toy":TOY_NEEDLE,"tall":1.0,"deep":14.0,"leg":0.9,"rib":0.6,"keel":0.7}],
]
## The mountains: [name, its pass's middle (strip frame, y the pass's
## floor off the strip top), the way through the pass (deg off the strip's
## way toward +v), the islet's radius, the summits' height range over its
## foot (m), the pass's toy width].
const RIDGES := [
	["ridge",Vector3(60.0,280.0,2.0),90.0,80.0,Vector2(105.0,125.0),TOY_PASS],
	["horn",Vector3(110.0,-330.0,-14.0),-40.0,48.0,Vector2(62.0,78.0),TOY_NOTCH],
]
## The downs: middle (strip frame, y its rim off the strip top), radius,
## how high its crests rise over the rim.
const DOWNS_AT := Vector3(-110.0,-300.0,-48.0)
const DOWNS_R := 80.0
const DOWNS_RISE := 22.0
## The shaft: middle (strip frame, y its top off the strip top), radius,
## cliff height.
const SHAFT_AT := Vector3(-210.0,215.0,8.0)
const SHAFT_R := 40.0
const SHAFT_H := 42.0
## The stacks: [middle (strip frame, y the top off the strip top),
## radius, cliff height].
const STACKS := [
	[Vector3(150.0,-150.0,10.0),11.0,40.0],
	[Vector3(195.0,-120.0,-12.0),9.0,30.0],
	[Vector3(200.0,-185.0,24.0),13.0,52.0],
	[Vector3(245.0,-150.0,4.0),10.0,36.0],
	[Vector3(255.0,-215.0,-6.0),12.0,40.0],
	[Vector3(150.0,-215.0,-20.0),10.0,30.0],
	[Vector3(295.0,-185.0,16.0),11.0,46.0],
]
const SEED := 9300
const TURF_LAYER := 1 << 11

var home: Node3D
var host: Node3D
## The strip's frame: its middle (world, at its top), its way (u) and
## across (v, + the dry side).
var mid := Vector3.ZERO
var way := Vector3.FORWARD
var across := Vector3.RIGHT
## What each piece is, by name: {node, kind, at (world middle), reach,
## and for an opening: through (world middle), axis, width, height}.
var pieces := {}
var built_ms := 0
var _rock := {}

## Home's hub under `h` (home, its land built), or null with --no-hub or
## no land.
static func add(h: Node3D) -> Node3D:
	if LaunchArgs.user_args().has("--no-hub") or h == null or h.get("land") == null: return null
	var hub: Node3D = new()
	hub.name = "Hub"
	h.add_child(hub)
	hub.build(h)
	return hub

## The hub's pieces as the sky's places ([id, middle, reach]: the cloud
## towers keep off them), [] with none.
static func places_of(h: Node3D) -> Array:
	var hub: Node = h.get_node_or_null("Hub") if h != null else null
	if hub == null: return []
	var out: Array = []
	for n: String in hub.pieces:
		var p: Dictionary = hub.pieces[n]
		out.append(["hub_"+n,p.at,float(p.reach)])
	return out

func build(h: Node3D) -> void:
	home = h
	host = h.get("host")
	var began := Time.get_ticks_msec()
	var a: Vector3 = h.strip_a
	var b: Vector3 = h.strip_b
	mid = (a+b)*0.5
	way = Vector3(b.x-a.x,0.0,b.z-a.z).normalized()
	across = way.cross(Vector3.UP)
	var lake: Node3D = h.get("lake")
	if lake != null and (lake.global_position-mid).dot(across) > 0.0: across = -across
	_rock = _home_rock()
	var islets: Node3D = h.get("islets")
	var palette: Dictionary = islets.prepare_authored()
	# The islets made on workers at once.
	var jobs := {}
	var hs := int(h.get("hunt_seed"))
	for row: Array in RIDGES: jobs[str(row[0])] = _ridge_spec(hs,row)
	jobs["downs"] = _downs_spec(hs)
	jobs["shaft"] = _shaft_spec(hs)
	for i in range(STACKS.size()): jobs["stack_%d" % (i+1)] = _stack_spec(hs,i)
	var outs := {}
	var tasks: Array = []
	var k := 0
	for n: String in jobs:
		k += 1
		var out := {}
		outs[n] = out
		tasks.append(WorkerThreadPool.add_task(_make.bind(SEED+k*31+hs,jobs[n],palette,out),false,"Hub islet"))
	for t: int in tasks: WorkerThreadPool.wait_for_task_completion(t)
	var made_ms := Time.get_ticks_msec()-began
	for row: Array in RIDGES: _stand_ridge(row,outs[str(row[0])])
	_stand_downs(outs.downs)
	_stand_shaft(outs.shaft)
	for i in range(STACKS.size()): _stand_stack(i,outs["stack_%d" % (i+1)])
	for row: Array in PIECES: _stand_arch(row)
	built_ms = Time.get_ticks_msec()-began
	var tris := 0
	for n: String in pieces: tris += int(pieces[n].get("tris",0))
	print("home hub: %d pieces in %d ms (islets on workers %d ms), %d arch triangles" % [pieces.size(),built_ms,made_ms,tris])
	for n: String in pieces:
		var p: Dictionary = pieces[n]
		var line := "home hub: %s at %s, reach %.0f m" % [n,(p.at as Vector3).round(),float(p.reach)]
		if p.has("width"): line += ", opening %.1f x %.1f m (axis %s)" % [float(p.width),float(p.height),(p.axis as Vector3).snapped(Vector3.ONE*0.01)]
		print(line)

static func _make(seed_value: int, spec: Dictionary, palette: Dictionary, out: Dictionary) -> void:
	out.merge(SkyIslets.make(seed_value,spec,palette,0.0))

## A point of the strip's frame (u, v, y off the strip's top) in the world.
func at(p: Vector3) -> Vector3:
	return mid+way*p.x+across*p.y+Vector3.UP*p.z

## The rock home's walls wear (its material's bands, scripts/rock_looks.gd
## `apply`): the look among home's that matches them nearest, at the tone
## they were drawn at.
func _home_rock() -> Dictionary:
	var out := {"palette":"basalt_warm","tone":0.86,"vary":0.5,"bed":2.0}
	var land: Node3D = home.get("land")
	var sides: MeshInstance3D = land.get_node_or_null("Sides") as MeshInstance3D if land != null else null
	var m: ShaderMaterial = sides.mesh.surface_get_material(0) as ShaderMaterial if sides != null and sides.mesh != null else null
	if m == null: return out
	var got: Variant = m.get_shader_parameter("strata_core_a")
	if not got is Vector3: return out
	var want: Vector3 = got
	var best := INF
	for look: String in ["basalt_warm","basalt","slate"]:
		var c := RockLooks.colour_of(look,"core_a",1.0,0.5)
		var base := Vector3(c.r,c.g,c.b)
		var tone := want.length()/maxf(base.length(),0.0001)
		var d := (want/maxf(want.length(),0.0001)).distance_to(base/maxf(base.length(),0.0001))
		if d < best:
			best = d
			out.palette = look
			out.tone = clampf(sqrt(tone),0.6,1.2)
	return out

## Home's rock without its beds: a mountain's or the downs' walls take
## the look's strata, not painted beds (the beds are a sea cliff's).
func _bare_rock() -> Dictionary:
	var r := _rock.duplicate()
	r.erase("bed")
	return r

func _material() -> Material:
	var land: Node3D = home.get("land")
	var sides: MeshInstance3D = land.get_node_or_null("Sides") as MeshInstance3D if land != null else null
	return sides.mesh.surface_get_material(0) if sides != null and sides.mesh != null else null

# --- The recipes ------------------------------------------------------------------

func _ridge_spec(hs: int, row: Array) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["hub "+str(row[0]),hs])
	var spec := LandformMountains.recipe(rng,95.0)
	spec.radius = float(row[3])
	spec.step = 2.0 if float(row[3]) > 60.0 else 4.0/3.0
	spec.massif = {"height":row[4],"hut":false,"snow":false,"col_half":WorldScale.opening(float(row[5]))*0.5}
	spec.rock = _bare_rock()
	return spec

func _downs_spec(hs: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["hub downs",hs])
	var spec := LandformHills.recipe(rng,90.0)
	spec.radius = DOWNS_R
	spec.step = 2.0
	(spec.downs as Dictionary).rise = DOWNS_RISE
	(spec.downs as Dictionary).ridges = Vector2i(4,5)
	(spec.downs as Dictionary).tors = Vector2i(2,3)
	spec.rock = _bare_rock()
	return spec

func _cliffs_spec(radius: float, height: float, rng: RandomNumberGenerator) -> Dictionary:
	return {"kind":"hills","radius":radius,"step":1.0 if radius < 20.0 else 2.0,"room":4.0,
		"cliffs":{"height":height,"low":rng.randf_range(0.82,0.95),"tilt":rng.randf()*TAU,"bed":float(_rock.get("bed",2.0)),"stacks":0,"arch":false,"cove":false},
		"mounds":[],"dome":0.3,"keel":rng.randf_range(0.8,1.2),
		"trees":Vector2i(0,2) if radius < 20.0 else Vector2i(3,6),"tree_pool":{"juniper":1.0,"tree":0.6,"birch":0.35},"drifts":Vector2i(1,3),"undergrowth":0.5,
		"rock":_rock.duplicate()}

func _shaft_spec(hs: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["hub shaft",hs])
	var spec := _cliffs_spec(SHAFT_R,SHAFT_H,rng)
	spec.holes = [Vector3(0.0,0.0,WorldScale.opening(TOY_SHAFT)*0.5+SeaCliffs.COLUMN+1.0)]
	spec.room = 6.0
	return spec

func _stack_spec(hs: int, i: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["hub stack",hs,i])
	var row: Array = STACKS[i]
	return _cliffs_spec(float(row[1]),float(row[2]),rng)

# --- Standing them ----------------------------------------------------------------

## Where a piece reaching `reach` m round `p` (world) is in the way: the
## strip's corridor, home's land, its lake or fall, a landmark, or a piece
## already stood. "" clear.
func in_way(p: Vector3, reach: float) -> String:
	var flat := Vector2(p.x,p.z)
	var a: Vector3 = home.strip_a
	var b: Vector3 = home.strip_b
	for end: Array in [[b,way],[a,-way]]:
		var e: Vector3 = end[0]
		var d: Vector3 = end[1]
		var off := Vector3(p.x-e.x,0.0,p.z-e.z)
		var along := off.dot(d)
		if along < -reach or along > CORRIDOR.x+reach: continue
		var side := absf(off.dot(across))
		if side < CORRIDOR.y+CORRIDOR.z*clampf(along,0.0,CORRIDOR.x)+reach: return "the strip's corridor"
	var land: Node3D = home.get("land")
	var c: Vector3 = home.get("circle")
	if land != null and flat.distance_to(Vector2(land.global_position.x,land.global_position.z)) < c.z-84.0+KEEP_HOME+reach: return "home's land"
	var lake: Node3D = home.get("lake")
	if lake != null and flat.distance_to(Vector2(lake.global_position.x,lake.global_position.z)) < 42.0+KEEP_HOME+reach: return "home's lake"
	for cue: Node3D in home.get("cues"):
		if cue.name == "CueHome" and flat.distance_to(Vector2(cue.global_position.x,cue.global_position.z)) < KEEP_FALL+reach: return "home's fall"
	for lm: Node3D in home.get("landmarks"):
		if lm != null and flat.distance_to(Vector2(lm.global_position.x,lm.global_position.z)) < KEEP_LANDMARK+float(lm.get("spec").get("size",12.0))+reach: return "a landmark"
	for n: String in pieces:
		var q: Dictionary = pieces[n]
		var qa: Vector3 = q.at
		if flat.distance_to(Vector2(qa.x,qa.z)) < float(q.reach)+reach+4.0: return "the hub's "+n
	return ""

## `p` (world) moved to the nearest spot (NUDGE m rings, 16 ways round)
## where a piece reaching `reach` round it is in nothing's way.
func clear_spot(name_: String, p: Vector3, reach: float) -> Vector3:
	var first := in_way(p,reach)
	if first == "": return p
	for i in range(1,NUDGES+1):
		for k in range(16):
			var q := p+Vector3.FORWARD.rotated(Vector3.UP,TAU*k/16.0)*NUDGE*i
			if in_way(q,reach) == "":
				print("home hub: %s moved %.0f m out of %s" % [name_,NUDGE*i,first])
				return q
	print("home hub: %s still in %s" % [name_,first])
	return p

## An islet `made` stood as `name_` (home/hub/<name_>) at `t`: solid, its
## top the turf (TURF_LAYER, landable), its rock and walls the rock.
func _stand_islet(name_: String, t: Transform3D, made: Dictionary) -> Node3D:
	var full := "home/hub/"+name_
	if Layout.deleted(full): return null
	var islets: Node3D = home.get("islets")
	var b: Dictionary = islets.stand(name_.to_pascal_case(),Vector3.ZERO,made,self)
	var node: Node3D = b.node
	node.transform = Layout.xform(full,t)
	# A mountain's massif draws its own faces (not in the top's): solid
	# too, as rock.
	var parts: Array = ["top","sides"]+(["massif"] if made.has("massif") else [])
	for part: String in parts:
		var faces := LineBuild._faces(made[part],-SkyIslets.OFF_MAP if part != "sides" else Vector3.ZERO)
		var k := 0
		for cut: PackedVector3Array in LineBuild._cut(faces):
			var shape := ConcavePolygonShape3D.new()
			shape.set_faces(cut)
			shape.backface_collision = true
			var holder := CollisionShape3D.new()
			holder.shape = shape
			var body := StaticBody3D.new()
			body.name = "%s%d" % [part.capitalize(),k]
			body.collision_layer = 1|(TURF_LAYER if part == "top" else 0)
			body.collision_mask = 0
			body.add_child(holder)
			node.add_child(body)
			k += 1
			if part == "top" and host != null and host.has_method("home_turf"): host.call("home_turf",body)
	Layout.track(full,node,"piece",t)
	return node

func _yaw_to(local: Vector2, world: Vector3) -> float:
	return atan2(world.x,world.z)-atan2(local.x,local.y)

## A mountain (a RIDGES row): turned so its pass runs its way off the
## strip's way, its pass's floor at its spot.
func _stand_ridge(row: Array, made: Dictionary) -> void:
	var name_: String = row[0]
	var shape: RefCounted = made.shape
	var massif: RefCounted = shape.spire
	if massif == null: return
	var col: Vector3 = massif.col
	var col2 := Vector2(col.x,col.y)
	var through: Vector2 = massif.across
	var want := way*cos(deg_to_rad(float(row[2])))+across*sin(deg_to_rad(float(row[2])))
	var yaw := _yaw_to(through,want)
	var basis := Basis(Vector3.UP,yaw)
	var floor_y: float = massif.pass_floor(shape)
	var pass_at := at(row[1])
	var reach := float(shape.reach)
	# The islet's middle off the pass's, turned.
	var off := basis*Vector3(col2.x,0.0,col2.y)
	var centre := clear_spot(name_,pass_at-off,reach)
	var origin := Vector3(centre.x,pass_at.y-floor_y,centre.z)
	var node := _stand_islet(name_,Transform3D(basis,origin),made)
	if node == null: return
	var tops: PackedFloat32Array = massif.summit_tops(shape)
	var summits: Array = []
	for i in range(massif.summits.size()):
		var s: Vector3 = massif.summits[i]
		summits.append(node.transform*Vector3(s.x,tops[i],s.y))
	var axis := basis*Vector3(through.x,0.0,through.y)
	pieces[name_] = {"node":node,"kind":"ridge","at":Vector3(centre.x,origin.y,centre.z),"reach":reach,
		"through":node.transform*Vector3(col2.x,floor_y,col2.y),"axis":axis,"width":float(massif.col_half)*2.0,"height":0.0,
		"summits":summits,"floor":origin.y+floor_y}

func _stand_downs(made: Dictionary) -> void:
	var shape: RefCounted = made.shape
	var reach := float(shape.reach)
	var p := clear_spot("downs",at(DOWNS_AT),reach)
	var node := _stand_islet("downs",Transform3D(Basis(Vector3.UP,float(int(home.get("hunt_seed"))%7)),p),made)
	if node == null: return
	var high := -INF
	for y: float in shape.heights: high = maxf(high,y)
	pieces.downs = {"node":node,"kind":"downs","at":p,"reach":reach,"crest":p.y+high}

func _stand_shaft(made: Dictionary) -> void:
	var shape: RefCounted = made.shape
	var reach := float(shape.reach)
	var top: float = shape.ground_at(Vector2(SHAFT_R*0.6,0.0))
	var want := at(SHAFT_AT)
	var p := clear_spot("shaft",Vector3(want.x,want.y-top,want.z),reach)
	var node := _stand_islet("shaft",Transform3D(Basis.IDENTITY,p),made)
	if node == null: return
	var hole: Vector3 = (shape.recipe.holes as Array)[0]
	pieces.shaft = {"node":node,"kind":"shaft","at":p,"reach":reach,"through":p+Vector3(0.0,top,0.0),"axis":Vector3.DOWN,
		"width":WorldScale.opening(TOY_SHAFT),"height":top,"hole":hole.z}

func _stand_stack(i: int, made: Dictionary) -> void:
	var shape: RefCounted = made.shape
	var row: Array = STACKS[i]
	var reach := float(shape.reach)
	var top: float = shape.ground_at(Vector2.ZERO)
	var want := at(row[0])
	var p := clear_spot("stack_%d" % (i+1),Vector3(want.x,want.y-top,want.z),reach)
	var node := _stand_islet("stack_%d" % (i+1),Transform3D(Basis(Vector3.UP,float(i)*1.3),p),made)
	if node == null: return
	pieces["stack_%d" % (i+1)] = {"node":node,"kind":"stack","at":p+Vector3(0.0,top,0.0),"reach":reach}

## An arch: its hole looking along its aim (the strip-frame point it faces,
## through its own middle), its floor at the row's height.
func _stand_arch(row: Array) -> void:
	var name_: String = row[0]
	var full := "home/hub/"+name_
	if Layout.deleted(full): return
	var spec: Dictionary = row[4]
	var p := at(row[2])
	var aim := at(Vector3((row[3] as Vector2).x,(row[3] as Vector2).y,0.0))
	var opening := RockArch.opening_of(spec)
	var reach := opening.x*0.5+RockArch.SPARE+maxf(opening.x*float(spec.get("leg",0.42)),5.0)
	p = clear_spot(name_,p,reach)
	var axis := Vector3(aim.x-p.x,0.0,aim.z-p.z).normalized()
	var basis := Basis(Vector3.UP,atan2(axis.x,axis.z))
	var t := Transform3D(basis,p)
	var node: Node3D = RockArch.new()
	node.name = name_.to_pascal_case()
	add_child(node)
	node.setup(Layout.xform(full,t),spec,_rock,_material())
	Layout.track(full,node,"piece",t)
	var made: Dictionary = node.get("made")
	pieces[name_] = {"node":node,"kind":"arch","at":p+Vector3.UP*float(made.height)*0.5,"reach":float(made.outer),
		"through":node.transform*Vector3(0.0,float(made.height)*0.45,0.0),"axis":node.transform.basis*Vector3.BACK,
		"width":float(made.width),"height":float(made.height),"tris":int(made.triangles)}
