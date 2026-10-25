extends Node3D
## Knocking spruces down (endless flight, the weighted presets: scripts/
## flight_weight.gd; docs/design/endless-flight/tree-knockdown-handoff.md).
##
## Each frame before the plane's step (`before`), its coming spot is tried
## against the standing trees the way its move and the near misses would
## meet them: the middle against the flight's cone (LandTrees `top_at`) with
## the skim's SkyGlide.SKIM over it, NearMiss's body points against the same
## cone TIP_DEPTH deep, and points along the wings against the bare crown
## (the colliders the wing rays find). Every tree met is knocked down
## (LandTrees `knock`: gone from the land for good, game state) before the
## move, so the plane flies on through instead of riding up or turning aside.
##
## What it costs: per tree, KEEP.x of the speed kept for a brush of the tip
## to KEEP.y for a hit deep in it (`heft`: how far under the cone's top the
## point was, over HEFT of the tree's height; a wing alone WING of that), a
## shove of JOLT.x m/s away from the trunk and JOLT.y up, the nose and path
## turned YAW rad away (both times the heft) (SkyPlane `knock`), and the near
## misses' unbanked chain (LOSES_CHAIN). No tree crashes the plane: there is
## no knob for it, every spruce goes down. A tree hit FlightContact still
## sees (a touch these tries missed) is knocked the same way (`at_hit`).
##
## The fall (scripted, the same every time but its twist): the trunk breaks
## STUMP m over its foot (a stump of it stays) and the tree goes over the
## plane's way turned up to LEAN rad toward the side it was struck on (a
## wing clip falls out past that wing, a hit on the nose straight ahead).
## It snaps at the hit: a lurch of SNAP rad/s (times the blow, SNAP_TIP for
## a brush of the tip to 1 for a full hit, the speed over SNAP_SPEED and the
## hit's height) that dies over LURCH s, CARRY of it kept as spin; then it
## tips as a rod on its foot (its angle's acceleration 1.5 g FALL_G
## sin(angle) over its height). Its crown whips: cut at JOINTS of its height,
## each cut bends on a spring (WHIP_HZ, WHIP_DAMP), kicked back WHIP times
## the lurch at the hit and forward WHIP_THUD times the spin at the thud,
## and sheds needles at the hit and as it whips forward. On the land (its
## slope there, the crown's girth lifting it REST_LIFT) it thuds and
## bounces back BOUNCE of its swing, at most BOUNCES times. Then it lies LIE
## s and sinks into the land over SINK s. At most MAX_LIVE lie at once (the
## oldest sinks over SINK_FAST s); past FORGET m from the eye one goes. While
## the chase camera is inside a falling crown (CLEAR_EYE) it isn't drawn.

const WorldScale = preload("res://scripts/world_scale.gd")
const SkyGlide = preload("res://scripts/sky_glide.gd")
const NearMiss = preload("res://scripts/endless/near_miss.gd")
const LandTrees = preload("res://scripts/endless/land_trees.gd")

const KEEP := Vector2(0.96,0.86)
const HEFT := 0.35
const WING := 0.5
const JOLT := Vector2(1.8,0.9)
const YAW := 0.05
const LOSES_CHAIN := true
## Points along each wing tried against the bare crown (shares of the half
## span), fore and aft NearMiss.RAY_FORE.
const WING_AT := [0.35,0.7,1.0]

const STUMP := 0.6
const FALL_G := 1.5
const TIP0 := 0.03
## The lean: the fall turned off the plane's way toward the struck side by
## up to LEAN rad, all of it once the trunk stands LEAN_FULL of the half span
## out from the flight line, none inside LEAN_DEAD m.
const LEAN := 0.85
const LEAN_FULL := 0.8
const LEAN_DEAD := 0.4
## A hit inside LEAN_DEAD turned this much (rad) to one side or the other
## (seeded by the tree's spot): 0 falls dead ahead.
const CENTRE_SWERVE := 0.0
## The snap: the lurch's spin (rad/s) for a full hit at SNAP_SPEED m/s on a
## SNAP_HEIGHT m tree; SNAP_TIP of it for a brush of the tip (heft 0); the
## speed's share clamped to SNAP_RANGE. It dies over LURCH s; CARRY of it
## stays as the fall's spin.
const SNAP := 8.0
const SNAP_TIP := 0.5
## What makes a full blow (`_blow`).
const BLOW_IN := 0.3
const BLOW_DEEP := 0.35
const SNAP_SPEED := 36.0
const SNAP_RANGE := Vector2(0.5,1.5)
const SNAP_HEIGHT := 14.0
const LURCH := 0.11
const CARRY := 0.05
## The crown's whip: bends at these shares of the height, each on a spring.
const JOINTS := [0.42,0.7]
const WHIP_HZ := 2.4
const WHIP_DAMP := 0.28
const WHIP := 0.6
const WHIP_THUD := 0.12
const WHIP_MOST := 0.4
const REST_LIFT := 0.55
const BOUNCE := 0.22
const BOUNCES := 2
const TWIST := 0.35
const LIE := 30.0
const SINK := 6.0
const SINK_FAST := 1.5
const MAX_LIVE := 12
const FORGET := 900.0
## The eye this near a falling crown (m past its girth) hides it.
const CLEAR_EYE := 1.5

## Knocked so far, for the drivers and the numbers.
var knocks := 0
## The trees down and lying (each {pivot, stump, ...}), oldest first.
var falling: Array = []

## One frame before the plane's step (weighted, flying): the trees its
## coming spot meets knocked down and paid for. Returns {} or the frame's
## "knock" event {at, what "tree", count, keep, heft, speed (before)}.
func before(delta: float, game: Node3D) -> Dictionary:
	var plane = game.plane
	var trees: Node3D = game.trees
	if trees == null or not bool(trees.enabled) or not bool(plane.weighted) or not bool(game.hand_landing.flying()): return {}
	var p: Vector3 = plane.position
	var ahead: Vector3 = p+plane.velocity*delta
	var size := WorldScale.plane
	var half := WorldScale.span*0.5
	var xf := Transform3D(Basis.from_euler(Vector3(float(plane.pitch),float(plane.heading),-(float(plane.bank)+float(plane.spin)))),ahead)
	var met := {}
	# The middle, here and where it is going, against the cone and its skim.
	for c: Vector3 in [p,ahead]: _meet(met,trees.tree_in(c,true,SkyGlide.SKIM),c,false)
	# The body's points (NearMiss BODY), TIP_DEPTH into the cone.
	for b: Vector3 in NearMiss.BODY:
		var q: Vector3 = xf*(b*size)
		_meet(met,trees.tree_in(q,true,-NearMiss.TIP_DEPTH),q,absf(b.x) > 0.3)
	# Along the wings, against the bare crown.
	for side: float in [-1.0,1.0]:
		for fore: float in [-NearMiss.RAY_FORE,NearMiss.RAY_FORE]:
			for f: float in WING_AT:
				var q: Vector3 = xf*Vector3(side*half*f,0.0,fore*size)
				_meet(met,trees.tree_in(q,false,0.0),q,true)
	if met.is_empty(): return {}
	return _knock_all(game,met)

## A tree FlightContact found the plane touching at `at` (a hit these tries
## missed), knocked the same way; {} if no standing tree is there.
func at_hit(game: Node3D, at: Vector3) -> Dictionary:
	var trees: Node3D = game.trees
	if trees == null or not bool(trees.enabled): return {}
	var t: Dictionary = trees.tree_in(at,true,1.0)
	if t.is_empty(): return {}
	var met := {}
	_meet(met,t,at,false)
	return _knock_all(game,met)

func _meet(met: Dictionary, t: Dictionary, at: Vector3, wing: bool) -> void:
	if t.is_empty(): return
	var key: Vector2i = LandTrees.tree_key(float(t.x),float(t.z))
	var heft := clampf(float(t.depth)/maxf(float(t.height)*HEFT,0.5),0.0,1.0)*(WING if wing else 1.0)
	if met.has(key) and float(met[key].heft) >= heft: return
	met[key] = {"tree":t,"at":at,"heft":heft}

## Each met tree down: the plane pays (the costs multiplied, the shoves
## added), the falls begun, the debris thrown.
func _knock_all(game: Node3D, met: Dictionary) -> Dictionary:
	var plane = game.plane
	var trees: Node3D = game.trees
	var speed_was := float(plane.speed)
	var way: Vector3 = plane.velocity
	var flat := Vector3(way.x,0.0,way.z)
	flat = flat.normalized() if flat.length() > 0.1 else Vector3(-sin(float(plane.heading)),0.0,-cos(float(plane.heading)))
	var keep := 1.0
	var shove := Vector3.ZERO
	var yaw := 0.0
	var top_heft := 0.0
	var at := Vector3.ZERO
	var count := 0
	for key: Vector2i in met:
		var m: Dictionary = met[key]
		var t: Dictionary = m.tree
		var stood: Dictionary = trees.knock(t)
		if stood.is_empty(): continue
		count += 1
		knocks += 1
		var heft := float(m.heft)
		keep *= lerpf(KEEP.x,KEEP.y,heft)
		# Away from the trunk, across the way.
		var off := Vector3(plane.position.x-float(t.x),0.0,plane.position.z-float(t.z))
		var across := off-flat*off.dot(flat)
		var away := across.normalized() if across.length() > 0.05 else flat.cross(Vector3.UP)
		shove += (away*JOLT.x+Vector3.UP*JOLT.y)*lerpf(0.4,1.0,heft)
		yaw += signf(flat.cross(away).y)*YAW*heft
		if heft >= top_heft:
			top_heft = heft
			at = m.at
		_fall(game,t,stood,_lean(flat,across,t),speed_was,m.at,_blow(plane.position,across,t))
		var trunk := Vector3(float(t.x),clampf(float(m.at.y),float(t.foot)+0.5,float(t.foot)+float(t.height)),float(t.z))
		game.debris.burst("leaves",m.at,(Vector3.UP+flat).normalized())
		var crown := Vector3(float(t.x),float(t.foot)+float(t.height)*0.78,float(t.z))
		game.debris.burst("needles",crown,(Vector3.UP*0.35+flat).normalized(),heft > 0.5)
		game.debris.burst("wood",trunk,(Vector3.UP*0.6+flat).normalized(),heft > 0.5)
	if count == 0: return {}
	plane.knock(keep,shove,yaw)
	return {"at":at,"what":"tree","count":count,"keep":keep,"heft":top_heft,"speed":speed_was}

## How full a blow the plane's line deals tree `t` (0 a brush, 1 full on),
## for the snap: how near the trunk it passes (`across`, BLOW_IN of the half
## span or nearer is full; past the wing and the crown's girth nothing), times
## how far under the top it goes (BLOW_DEEP of the height or more is full).
## Not the heft: the hit is caught the frame the plane first touches, so
## that is shallow on nearly every pass.
static func _blow(p: Vector3, across: Vector3, t: Dictionary) -> float:
	var half := WorldScale.span*0.5
	var near := half*BLOW_IN
	var lat := 1.0-clampf((across.length()-near)/maxf(half+float(t.radius)-near,0.1),0.0,1.0)
	var height := maxf(float(t.height),2.0)
	var deep := clampf((float(t.foot)+height-p.y)/(height*BLOW_DEEP),0.0,1.0)
	return lat*deep

## The way a tree falls: the plane's (flat) way turned toward the side the
## trunk stood on, `across` the plane's offset from the trunk square to it.
static func _lean(flat: Vector3, across: Vector3, t: Dictionary) -> Vector3:
	var out := across.length()
	var full := maxf(WorldScale.span*0.5*LEAN_FULL,LEAN_DEAD+0.1)
	var share := clampf((out-LEAN_DEAD)/(full-LEAN_DEAD),0.0,1.0)
	var side := -across/out if out > 0.01 else flat.cross(Vector3.UP)
	var turn := LEAN*share
	if share <= 0.0:
		if CENTRE_SWERVE == 0.0: return flat
		turn = CENTRE_SWERVE*(1.0 if hash([int(float(t.x)*10.0),int(float(t.z)*10.0)])%2 == 0 else -1.0)
	return (flat*cos(turn)+side*sin(turn)).normalized()

# --- The fall --------------------------------------------------------------------

## A one-instance batch of `mesh` at `xf` in `colour` (the land's batches'
## way, so the crown's material reads its tint as there).
static func _one(mesh: Mesh, xf: Transform3D, colour: Color, shadows: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = 1
	mm.set_instance_transform(0,xf)
	mm.set_instance_color(0,colour)
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("skip_reflection",true)
	return mi

## A variant's parts cut at JOINTS for the whip: [[trunk, crown] per piece,
## foot first] and the cuts' heights in the meshes' units. Each piece keeps
## the whole vertex buffer and the triangles whose middle is in its band.
## [[trunk, crown]] and no cuts when the meshes can't be read.
var _cut := {}
func _pieces(parts: Array, v: int) -> Dictionary:
	if _cut.has(v): return _cut[v]
	var top := maxf((parts[1] as Mesh).get_aabb().end.y,0.1)
	var at: Array = JOINTS.map(func(j: float) -> float: return j*top)
	var out := {"pieces":[parts.duplicate()],"at":[]}
	var cut: Array = []
	for part: Mesh in parts:
		var bands := _cut_mesh(part,at)
		if bands.is_empty(): break
		cut.append(bands)
	if cut.size() == 2:
		var pieces: Array = []
		for i in at.size()+1: pieces.append([cut[0][i],cut[1][i]])
		out = {"pieces":pieces,"at":at}
	_cut[v] = out
	return out

## `mesh` (one surface of triangles) cut into bands at heights `at`; [] if
## its arrays can't be read.
static func _cut_mesh(mesh: Mesh, at: Array) -> Array:
	if mesh == null or mesh.get_surface_count() < 1: return []
	var arrays := mesh.surface_get_arrays(0)
	if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX] == null: return []
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if verts.is_empty(): return []
	var idx := PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] != null: idx = arrays[Mesh.ARRAY_INDEX]
	if idx.is_empty():
		idx.resize(verts.size())
		for i in verts.size(): idx[i] = i
	var bands: Array = []
	for i in at.size()+1: bands.append(PackedInt32Array())
	for q in range(0,idx.size()-2,3):
		var y := (verts[idx[q]].y+verts[idx[q+1]].y+verts[idx[q+2]].y)/3.0
		var band := 0
		while band < at.size() and y > float(at[band]): band += 1
		var list: PackedInt32Array = bands[band]
		list.append(idx[q])
		list.append(idx[q+1])
		list.append(idx[q+2])
		bands[band] = list
	var out: Array = []
	for list: PackedInt32Array in bands:
		var piece := ArrayMesh.new()
		if not list.is_empty():
			var copy := arrays.duplicate()
			copy[Mesh.ARRAY_INDEX] = list
			piece.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,copy)
			piece.surface_set_material(0,mesh.surface_get_material(0))
		out.append(piece)
	return out

## Tree `t` (as it `stood`: LandTrees `knock`) falling along `way` (flat),
## hit at `at` by the plane going `speed` m/s, a `blow` (`_blow`) that full.
func _fall(game: Node3D, t: Dictionary, stood: Dictionary, way: Vector3, speed: float, at: Vector3, blow := 1.0) -> void:
	var trees: Node3D = game.trees
	var v := int(stood.variant)
	var xf: Transform3D = stood.trunk
	var parts: Array = trees.parts(maxi(v,0))
	var height := maxf(float(t.height),2.0)
	if v < 0:
		# Not found in a batch (a bare block): the mature at the solid's height.
		var top := maxf((parts[1] as Mesh).get_aabb().end.y,0.1)
		xf = Transform3D(Basis.from_scale(Vector3.ONE*height/top),xf.origin)
	var foot := xf.origin
	var stump := minf(STUMP,height*0.08)
	var pivot := Node3D.new()
	pivot.name = "Fallen"
	pivot.position = foot+Vector3.UP*stump
	# The pieces, each hung from the cut below it (a joint at the cut).
	var cut := _pieces(parts,maxi(v,0))
	var joints: Array = []
	var holder: Node3D = pivot
	var below := Vector3.ZERO
	for i in (cut.pieces as Array).size():
		var here := Vector3.ZERO
		if i > 0:
			here = xf.basis*Vector3(0.0,float(cut.at[i-1]),0.0)+Vector3(0.0,-stump,0.0)
			var joint := Node3D.new()
			joint.name = "Joint%d" % i
			joint.position = here-below
			holder.add_child(joint)
			joints.append(joint)
			holder = joint
			below = here
		var local := Transform3D(xf.basis,Vector3(0.0,-stump,0.0)-here)
		var piece: Array = cut.pieces[i]
		holder.add_child(_one(piece[0],local,Color.WHITE,true))
		holder.add_child(_one(piece[1],local,stood.tone,true))
	add_child(pivot)
	# The stump: the trunk's foot, cut STUMP up.
	var trunk_top := maxf((parts[0] as Mesh).get_aabb().end.y*xf.basis.y.length(),0.1)
	var stump_xf := Transform3D(xf.basis*Basis.from_scale(Vector3(1.0,stump/trunk_top,1.0)),foot)
	var stump_node := _one(parts[0],stump_xf,Color.WHITE,false)
	stump_node.name = "Stump"
	add_child(stump_node)
	# Where it comes to rest: square to the land's slope along the way,
	# lifted by the crown's girth.
	var field = game.field
	var reach := height*0.6
	var h0: float = field.height(foot.x,foot.z)
	var h1: float = field.height(foot.x+way.x*reach,foot.z+way.z*reach)
	var slope := atan2(h1-h0,reach)
	var lift := atan2(float(t.radius)*REST_LIFT,height*0.45)
	var rest := clampf(PI*0.5-slope-lift,0.9,1.9)
	# The snap: by the blow, the speed, the hit's height and the tree's size.
	var up := clampf((at.y-foot.y)/height,0.2,1.0)
	var snap := SNAP*lerpf(SNAP_TIP,1.0,clampf(blow,0.0,1.0))*clampf(speed/SNAP_SPEED,SNAP_RANGE.x,SNAP_RANGE.y)
	snap *= lerpf(0.6,1.0,up)*clampf(sqrt(SNAP_HEIGHT/height),0.75,1.35)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(foot.x*10.0),int(foot.z*10.0)])
	falling.append({"pivot":pivot,"stump":stump_node,"axis":Vector3.UP.cross(way).normalized(),"angle":TIP0,
		"spin":snap*CARRY,"snap":snap*(1.0-CARRY),"bend":0.0,"bend_v":-WHIP*snap,"joints":joints,"shed":false,
		"blow":blow,"rest":rest,"k":1.5*9.8*FALL_G/height,"height":height,"phase":"fall",
		"bounces":0,"t":0.0,"twist":rng.randf_range(-TWIST,TWIST),"base":pivot.position.y,"stump_y":foot.y,
		"sink":SINK,"depth":float(t.radius)*1.8+stump+1.0,"way":way,"girth":float(t.radius)/0.85+CLEAR_EYE})
	game.sound.shot("creak",0.3,0.6,foot)
	# Only so many lie at once: the oldest not yet sinking goes, fast.
	while _lying() > MAX_LIVE:
		for g: Dictionary in falling:
			if str(g.phase) != "sink":
				g.phase = "sink"
				g.t = 0.0
				g.sink = SINK_FAST
				break

func _lying() -> int:
	var n := 0
	for f: Dictionary in falling:
		if str(f.phase) != "sink": n += 1
	return n

## One frame of the falls: tipping, the thud and bounce, lying, sinking.
func step(delta: float, game: Node3D) -> void:
	if falling.is_empty(): return
	var eye: Vector3 = game.camera.global_position
	var i := 0
	while i < falling.size():
		var f: Dictionary = falling[i]
		var pivot: Node3D = f.pivot
		if pivot.position.distance_to(eye) > FORGET or not _advance(f,delta,game):
			pivot.queue_free()
			(f.stump as Node).queue_free()
			falling.remove_at(i)
			continue
		var angle := float(f.angle)
		var axis: Vector3 = f.axis
		var twist := Basis(Vector3.UP,float(f.twist)*clampf(angle/float(f.rest),0.0,1.0))
		pivot.basis = Basis(axis,angle)*twist
		# The crown's bend, the same at each cut, about the fall's axis.
		var bend := Basis((twist.inverse()*axis).normalized(),float(f.bend))
		for joint: Node3D in f.joints: joint.basis = bend
		# The chase camera comes through where the plane did: while the eye is
		# inside the falling crown (CLEAR_EYE m round its axis) it isn't drawn.
		var tip := pivot.position+pivot.basis.y*float(f.height)
		var near := Geometry3D.get_closest_point_to_segment(eye,pivot.position,tip)
		pivot.visible = near.distance_to(eye) > float(f.girth)
		i += 1

## One fall's step; false when it has sunk away.
func _advance(f: Dictionary, delta: float, game: Node3D) -> bool:
	match str(f.phase):
		"fall":
			var n := maxi(1,ceili(delta/0.004))
			var h := delta/n
			for s in n:
				f.spin = float(f.spin)+float(f.k)*sin(float(f.angle))*h
				f.snap = float(f.snap)*exp(-h/LURCH)
				f.angle = float(f.angle)+(float(f.spin)+float(f.snap))*h
				_whip(f,h,game)
				if float(f.angle) >= float(f.rest) and float(f.spin)+float(f.snap) > 0.0:
					f.angle = float(f.rest)
					if int(f.bounces) == 0:
						f.bend_v = float(f.bend_v)+WHIP_THUD*(float(f.spin)+float(f.snap))
						_thud(f,game)
					f.spin = float(f.spin)+float(f.snap)
					f.snap = 0.0
					f.bounces = int(f.bounces)+1
					f.spin = -float(f.spin)*BOUNCE
					if int(f.bounces) > BOUNCES or absf(float(f.spin)) < 0.06:
						f.spin = 0.0
						f.phase = "lie"
						f.t = 0.0
						break
		"lie":
			if absf(float(f.bend))+absf(float(f.bend_v)) > 0.002:
				var n := maxi(1,ceili(delta/0.004))
				for s in n: _whip(f,delta/n,game)
			else:
				f.bend = 0.0
				f.bend_v = 0.0
			f.t = float(f.t)+delta
			if float(f.t) >= LIE:
				f.phase = "sink"
				f.t = 0.0
		"sink":
			f.t = float(f.t)+delta
			var s := clampf(float(f.t)/float(f.sink),0.0,1.0)
			var down := float(f.depth)*s*s
			(f.pivot as Node3D).position.y = float(f.base)-down
			(f.stump as Node3D).position.y = float(f.stump_y)-down
			if s >= 1.0: return false
	return true

## One step of the crown's whip (each cut's bend on its spring); the first
## time it swings forward through straight it sheds needles off the top.
func _whip(f: Dictionary, h: float, game: Node3D) -> void:
	if (f.joints as Array).is_empty(): return
	var w := TAU*WHIP_HZ
	var was := float(f.bend)
	f.bend_v = float(f.bend_v)+(-w*w*was-2.0*WHIP_DAMP*w*float(f.bend_v))*h
	f.bend = clampf(was+float(f.bend_v)*h,-WHIP_MOST,WHIP_MOST)
	if not bool(f.shed) and was < 0.0 and float(f.bend) >= 0.0:
		f.shed = true
		var pivot: Node3D = f.pivot
		var tip := pivot.position+Basis(f.axis as Vector3,float(f.angle))*Vector3.UP*float(f.height)*0.78
		game.debris.burst("needles",tip,(Vector3.UP*0.4+(f.way as Vector3)).normalized())

## The crown meets the land: a thud, leaves and dust where it lands.
func _thud(f: Dictionary, game: Node3D) -> void:
	var pivot: Node3D = f.pivot
	var crown := pivot.position+Basis(f.axis as Vector3,float(f.rest))*Vector3.UP*float(f.height)*0.55
	game.debris.burst("leaves",crown,Vector3.UP,true)
	game.debris.burst("dust",crown,Vector3.UP,float(f.height) > 12.0)
	var big := clampf(float(f.height)/18.0,0.5,1.4)
	game.sound.shot("thud",0.5*big,1.05-0.2*big,crown)
	game.sound.shot("leaves",0.35,0.8,crown)
	f.landed_at = crown

## The numbers line (F1).
func note() -> String:
	return "  ·  %d trees knocked, %d down" % [knocks,falling.size()]
