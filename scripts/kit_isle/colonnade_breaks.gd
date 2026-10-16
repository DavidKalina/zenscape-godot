extends "res://scripts/kit_isle/break_pieces.gd"
## The Olmec's destruction (round2.md): the colonnade spine's piers, its
## lintels, its portals' arches
## (studies/colonnade_spine_isle_art.gd `colonnade`, `breakable`) and the
## temple's rose gable, stood each on its own, for the headless body
## (scripts/enemies/headless_body.gd, `breaker`) to tear through.
## Scripted breaks, not voxels:
##
##   a pier met by his bulk (`met`) or reached by his landing's shockwave
##   (`wave`) snaps at a drum joint near where it was hit: a stump stays
##   (the kit's snapped pier, its ragged head), and what stood over the
##   joint goes over whole, slowly at first about its foot, the way he
##   pushed (or out from the wave), and bursts into its drums and capital
##   where it hits; a lintel it bore, or one his chest meets, breaks in two
##   near that end and falls. A portal's pier taken, or its ring met, the
##   arch comes down in chunks after it (scripts/kit_isle/masonry_cuts.gd
##   `ring`), its far springer left on the pier still standing.
##   The rose gable (`ahead`, `smash`): walked at, he plants and punches
##   through its door; it falls in big slabs, the door's first, then the
##   walls over it slumping in, the rose and the rake after them; its flanks
##   stand (masonry_cuts.gd `gable`).
##   The pieces are Jolt RigidBody3Ds a second or two (MAX_BODIES at most at
##   once; past that a piece skips the physics and lands as rubble where it
##   would lie), then freeze where they came to rest: static rubble he and
##   the walker stand on. A break's rubble, settled, is drawn as one mesh
##   (what stands of it with it), and the bodies read its ground afresh
##   (`world_changed`).
##
## What still stands is left out of the body's rays (`standing_rids`): he
## plans and walks through it as if it were air, and it breaks as he does.
## Breaks last the session. The fall, the cap, the settling and the hub's
## `changed` are the shared breakable's (scripts/kit_isle/break_pieces.gd);
## the hub (scripts/kit_isle/breakables.gd) gates who may break (`olmec`) and
## hands `hit` on here.
const Spine = preload("res://studies/colonnade_spine_isle_art.gd")
const Cuts = preload("res://scripts/kit_isle/masonry_cuts.gd")
const HeadlessBody = preload("res://scripts/enemies/headless_body.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")
## His veer into a pier beside his way (`veer`): how far on (m), how far
## past his flank (m), how much at most (rad, under his ROUTE_TURN).
const VEER_AHEAD := 8.0
const VEER_SIDE := 3.6
const VEER_MOST := 0.34

## A pier's reach round its middle (its sub-base's half).
const PIER_R := 0.62
## Of a shockwave's reach, the piers inside this share of it fall (surely
## near, by chance to its edge).
const WAVE_BREAK := 0.62
## A hit's strength (the hub's breakers: the Olmec's 1) that breaks a pier,
## a lintel, a ring or a wall; the gable's.
const TOUGH := 0.5
const PUNCH := 1.0
## The gable's pause on impact.
const GABLE_HITSTOP := 7
const GABLE_HITSTOP_SCALE := 0.06
## A column going over (round 2): its first turn about its foot (rad/s),
## more for his push (per m/s).
const TOPPLE_W := 0.55
const TOPPLE_PUSH := 0.12
## The ground's shake at the gable's punch.
const QUAKE_PUNCH := 1.4
## The gable punched (`ahead`): his front this near its face (m) and his
## way this square to it.
const SMASH_REACH := 2.2
const SMASH_SQUARE := 0.55
## How much of the colonnade's growth each unit grows (a unit is a Build of
## its own, its ivy no longer one strand budget across the whole colonnade:
## at 0.16 the colonnade's growth is 23.4k triangles against the one Build's
## 24.8k; 0.2 jumps to 31k, the lintels' fringes coming in).
const IVY_SHARE := 0.16
## The pieces' look: no growth of their own (ivy hanging from a toppled drum
## points the wrong way); the stump keeps its.
const PIECE_DETAIL := 0.0
## The rose gable's seed and wear (studies/colonnade_spine_isle_art.gd
## `temple`).
const GABLE_WEAR := 0.45
## The piers: {line, side, frame, height (INF whole), node, alive, base, top, lintels, portal (index or -1)}.
var piers: Array = []
## The lintels: {a, b, top, node, alive, piers}.
var lintels: Array = []
## The portals: {line, frame, h, node (the ring standing), springs, parts, alive, piers}.
var portals: Array = []
## The rose gable: {xf (world), node (as it stands, in the temple), stands, parts, alive}, or {}.
var gable := {}
## The temple's turrets and cella walls: {node, xf, box (its frame), stands, parts, alive}.
var walls: Array = []
## Counted, for checks and the HUD.
var broken := 0
var lintels_down := 0
var portals_down := 0
var walls_down := 0
var gable_down := false

## The units stood from the colonnade's `breakable` meta (Spine `colonnade`).
func setup(colonnade: Node3D, seed_value: int) -> void:
	name = "Breaks"
	_seed = seed_value
	_rng.seed = seed_value*7919+3
	flat_rest = Spine.LINTEL.y*0.5
	var meta: Dictionary = colonnade.get_meta("breakable")
	var was := Build.detail
	Build.detail = was*IVY_SHARE
	for d: Dictionary in meta.piers:
		var f: Transform3D = d.frame
		var hgt: float = d.height
		var b := Build.new(seed_value+int(d.line)*13+int(d.side)*5,Spine.WEATHERED,"Pier_%d_%d" % [int(d.line),int(d.side)])
		b.settle = 0.5
		RuinKit._pier(b,Transform3D.IDENTITY,Spine.PIER_H,hgt)
		var node := b.finish()
		node.transform = f
		add_child(node)
		piers.append({"line":int(d.line),"side":float(d.side),"frame":f,"height":hgt,"node":node,"alive":true,
			"base":f.origin.y,"top":f.origin.y+minf(hgt,Spine.PIER_H),"lintels":[],"portal":-1})
	var k := 0
	for l: Dictionary in meta.lintels:
		var a: Vector3 = l.a
		var e: Vector3 = l.b
		var mid := (a+e)*0.5
		var b := Build.new(seed_value+500+k,Spine.WEATHERED,"Lintel_%d" % k)
		b.settle = 0.5
		Spine._beam(b,a-mid,e-mid,Spine.LINTEL)
		var node := b.finish()
		node.position = mid
		add_child(node)
		var held: Array = []
		for i in range(piers.size()):
			var c: Vector3 = (piers[i].frame as Transform3D).origin
			for end: Vector3 in [a,e]:
				if Vector2(c.x-end.x,c.z-end.z).length() < 0.8 and absf(float(piers[i].top)+Spine.LINTEL.y-end.y) < 0.4 and not held.has(i):
					held.append(i)
					(piers[i].lintels as Array).append(k)
		lintels.append({"a":a,"b":e,"top":float(l.top),"node":node,"alive":true,"piers":held})
		k += 1
	# The portals' rings, each pre-cut (masonry_cuts.gd `ring`).
	var began := Time.get_ticks_usec()
	for r: Dictionary in meta.get("portals",[]):
		var f: Transform3D = r.frame
		var cut: Dictionary = Cuts.ring(seed_value+300+int(r.line),Spine.WEATHERED,f,Spine.PIER_H,float(r.h),int(r.lost),float(r.lost_side),Build.detail)
		var node: Node3D = cut.whole
		add_child(node)
		var mine: Array = []
		var inv := f.affine_inverse()
		for i in range(piers.size()):
			if int(piers[i].line) != int(r.line): continue
			piers[i].portal = portals.size()
			mine.append(i)
		var by_side := {}
		for i: int in mine: by_side["l" if (inv*(piers[i].frame as Transform3D).origin).x < 0.0 else "r"] = i
		portals.append({"line":int(r.line),"frame":f,"h":float(r.h),"node":node,"springs":cut.springs,"parts":cut.parts,"alive":true,"piers":by_side})
	cut_ms += (Time.get_ticks_usec()-began)/1000.0
	Build.detail = was
	_refresh_rids()

## The temple's rose gable (studies/colonnade_spine_isle_art.gd `temple`,
## seed `seed_value`), pre-cut to fall (masonry_cuts.gd `gable`).
func setup_gable(temple: Node3D, seed_value: int) -> void:
	var node := temple.get_node_or_null("RoseGable") as Node3D
	if node == null: return
	var began := Time.get_ticks_usec()
	var cut: Dictionary = Cuts.gable(seed_value,GABLE_WEAR,Build.detail)
	cut_ms += (Time.get_ticks_usec()-began)/1000.0
	# The stair turrets stand into the gable's flanks: its slabs fall clear
	# of them (never wedged against them as they go).
	var clear: Array = []
	# The rake's slabs, high over the flanks, fall clear of the cella's
	# walls run up behind it too.
	var high: Array = []
	var turrets: Array = temple.get_meta("turrets",[])
	for t: Node in temple.get_children():
		if not t is Node3D or t == node or t.get_node_or_null("Body") == null: continue
		var at := (t as Node3D).global_position
		for tp: Vector3 in turrets:
			if at.distance_to(tp) < 0.5: clear.append(t.get_node("Body"))
		if absf(at.x-node.global_position.x) < 4.0 and not clear.has(t.get_node("Body")): high.append(t.get_node("Body"))
	gable = {"xf":node.global_transform,"node":node,"stands":cut.stands,"parts":cut.parts,"alive":true,"clear":clear,"high":high}
	# The turrets and the cella's walls: he goes through them too (round 2:
	# no masonry wedges him), each pre-cut by bands (masonry_cuts.gd `piece`).
	began = Time.get_ticks_usec()
	for t: Node in temple.get_children():
		if not t.has_meta("kit") or not t is Node3D: continue
		var kit: Array = t.get_meta("kit")
		var mi := t.get_node_or_null("Mesh") as MeshInstance3D
		if mi == null or mi.mesh == null: continue
		var box := mi.mesh.get_aabb()
		var tall := String(kit[0]) == "turret"
		var wc: Dictionary = Cuts.piece(String(kit[0]),int(kit[1]),float(kit[2]),box,2.2 if tall else 1.1,5.0,Build.detail)
		walls.append({"node":t,"xf":(t as Node3D).global_transform,"box":box,"stands":wc.stands,"parts":wc.parts,"alive":true})
	cut_ms += (Time.get_ticks_usec()-began)/1000.0
	_refresh_rids()

func _standing_bodies() -> Array[RID]:
	var out: Array[RID] = []
	for u: Dictionary in piers+lintels+portals:
		if u.alive: out.append((u.node as Node3D).get_node("Body").get_rid())
	for w: Dictionary in walls:
		if w.alive and is_instance_valid(w.node): out.append((w.node as Node3D).get_node("Body").get_rid())
	if not gable.is_empty() and gable.alive and is_instance_valid(gable.node):
		out.append((gable.node as Node3D).get_node("Body").get_rid())
	return out

func standing() -> int:
	var n := 0
	for u: Dictionary in piers:
		if u.alive: n += 1
	return n

# --- What breaks them --------------------------------------------------------------------

## The body's bulk (its box, as its push-out has it: shoulders and hanging
## arms across, its depth along, knees to stump) against what stands.
func met(body: Node3D) -> void:
	var hh: float = body.hh
	var hw := hh*HeadlessBody.BULK_W
	var hl := hh*HeadlessBody.BULK_L
	var low: float = body.position.y+0.3
	var high: float = body.position.y+float(body._bulk_top())
	var inv := Basis(Vector3.UP,float(body.facing)).inverse()
	var fwd: Vector3 = body._forward3()
	var hits := 0
	for i in range(piers.size()):
		var u: Dictionary = piers[i]
		if not u.alive or float(u.top) < low or float(u.base) > high: continue
		var c: Vector3 = (u.frame as Transform3D).origin
		var rel := inv*(c-body.position)
		if absf(rel.x) > hw+PIER_R or absf(rel.z) > hl+PIER_R: continue
		var out := Vector3(c.x-body.position.x,0.0,c.z-body.position.z)
		var dir := (fwd*0.65+out.normalized()*0.35).normalized()
		# Snapped about where his shins and knees meet it.
		_break_pier(i,dir,_rng.randf_range(0.9,1.9),body.vel,body)
		hits += 1
	for j in range(lintels.size()):
		var l: Dictionary = lintels[j]
		if not l.alive or float(l.top) < low or float(l.top)-Spine.LINTEL.y > high: continue
		var a: Vector3 = l.a
		var e: Vector3 = l.b
		var n := maxi(2,ceili(a.distance_to(e)/0.8))
		for s in range(n+1):
			var q := a.lerp(e,float(s)/n)
			var rel := inv*(q-body.position)
			if absf(rel.x) < hw+0.3 and absf(rel.z) < hl+0.3:
				_drop_lintel(j,q,fwd,body.vel,_new_group(q))
				hits += 1
				break
	# A portal's ring his shoulders meet (its chunks' middles in his box).
	for k in range(portals.size()):
		var pt: Dictionary = portals[k]
		if not pt.alive: continue
		for part: Dictionary in pt.parts:
			var c: Vector3 = part.at
			if c.y < low or c.y > high+0.5: continue
			var rel := inv*(c-body.position)
			if absf(rel.x) < hw+0.5 and absf(rel.z) < hl+0.5:
				var side := "l" if ((pt.frame as Transform3D).affine_inverse()*c).x < 0.0 else "r"
				_drop_ring(k,side,fwd,body.vel)
				hits += 1
				break
	# A turret or a cella wall his box meets (its bounds, his bulk round).
	for k in range(walls.size()):
		var w: Dictionary = walls[k]
		if not w.alive: continue
		var xf: Transform3D = w.xf
		var box: AABB = w.box
		var lp := xf.affine_inverse()*body.position
		if lp.y+float(body._bulk_top()) < box.position.y+1.0 or lp.y > box.end.y: continue
		var near := Vector3(clampf(lp.x,box.position.x,box.end.x),lp.y,clampf(lp.z,box.position.z,box.end.z))
		var rel := inv*(xf.basis*(near-lp))
		if absf(rel.x) < hw+0.15 and absf(rel.z) < hl+0.15:
			_drop_wall(k,body)
			hits += 1
	if hits > 0:
		body.stagger(minf(1.0,0.5*hits))
		_pause()

## A shockwave `w` (the body's: at, r its front, max its reach, power) as
## it runs out: a pier its front passes within WAVE_BREAK of its reach falls
## out from it (surely near, by chance to the edge), snapped low.
func wave(body: Node3D, w: Dictionary) -> void:
	if not w.has("tried"): w["tried"] = {}
	var tried: Dictionary = w.tried
	var at: Vector3 = w.at
	var reach: float = float(w.max)*WAVE_BREAK
	var any := false
	for i in range(piers.size()):
		var u: Dictionary = piers[i]
		if not u.alive or tried.has(i): continue
		var c: Vector3 = (u.frame as Transform3D).origin
		var d := Vector2(c.x-at.x,c.z-at.z).length()
		if d > float(w.r) or absf(float(u.base)-at.y) > 4.0: continue
		tried[i] = true
		if d > reach or _rng.randf() > 1.0-smoothstep(0.5,1.0,d/reach): continue
		var out := Vector3(c.x-at.x,0.0,c.z-at.z).normalized()
		_break_pier(i,out,_rng.randf_range(0.6,1.2),Vector3.ZERO,body)
		any = true
	if any: _pause()

## A hit from any breaker (the hub's `hit`): at `at`, reaching `radius` m.
## A pier whose foot is in reach snaps and goes over out from it, a lintel
## or a portal's ring in reach drops, a turret or wall in reach goes over;
## the gable needs PUNCH strength. What a hit this weak can't break
## (`strength` under TOUGH) stands.
func hit(at: Vector3, radius: float, strength: float, _source: StringName) -> int:
	if strength < TOUGH: return 0
	var n := 0
	for i in range(piers.size()):
		var u: Dictionary = piers[i]
		if not u.alive: continue
		var c: Vector3 = (u.frame as Transform3D).origin
		var near := Vector3(c.x,clampf(at.y,float(u.base),float(u.top)),c.z)
		if near.distance_to(at) > radius+PIER_R: continue
		var out := Vector3(c.x-at.x,0.0,c.z-at.z)
		var dir := out.normalized() if out.length() > 0.05 else Vector3.FORWARD
		_break_pier(i,dir,clampf(at.y-float(u.base),0.6,1.9),Vector3.ZERO,null)
		n += 1
	for j in range(lintels.size()):
		var l: Dictionary = lintels[j]
		if not l.alive: continue
		var q := Geometry3D.get_closest_point_to_segment(at,l.a,l.b)
		if q.distance_to(at) > radius+Spine.LINTEL.y: continue
		var out := Vector3(q.x-at.x,0.0,q.z-at.z)
		_drop_lintel(j,q,out.normalized() if out.length() > 0.05 else Vector3.FORWARD,Vector3.ZERO,_new_group(q))
		n += 1
	for k in range(portals.size()):
		var pt: Dictionary = portals[k]
		if not pt.alive: continue
		for part: Dictionary in pt.parts:
			var c: Vector3 = part.at
			if c.distance_to(at) > radius+0.5: continue
			var side := "l" if ((pt.frame as Transform3D).affine_inverse()*c).x < 0.0 else "r"
			var out := Vector3(c.x-at.x,0.0,c.z-at.z)
			_drop_ring(k,side,out.normalized() if out.length() > 0.05 else Vector3.FORWARD,Vector3.ZERO)
			n += 1
			break
	for k in range(walls.size()):
		var w: Dictionary = walls[k]
		if not w.alive: continue
		var xf: Transform3D = w.xf
		var box: AABB = w.box
		var lp := xf.affine_inverse()*at
		var near := Vector3(clampf(lp.x,box.position.x,box.end.x),clampf(lp.y,box.position.y,box.end.y),clampf(lp.z,box.position.z,box.end.z))
		if (xf.basis*(near-lp)).length() > radius: continue
		var out := xf*near-at
		out.y = 0.0
		_drop_wall_from(k,at,out.normalized() if out.length() > 0.05 else Vector3.FORWARD,null)
		n += 1
	if strength >= PUNCH and not gable.is_empty() and gable.alive:
		var door := (gable.xf as Transform3D)*Vector3(0.0,2.0,0.0)
		if door.distance_to(at) < radius+RuinKit.GABLE.x*0.5:
			_smash_from(at,Vector3.ZERO,null)
			n += 1
	if n > 0: _pause()
	return n

## A brute's veer: the nearest pier standing just off his way ahead (within
## VEER_AHEAD m on, VEER_SIDE m past his bulk's flank) draws `heading` round
## so his flank meets it, VEER_MOST rad at most.
func veer(body: Node3D, heading: float) -> float:
	var p: Vector3 = body.position
	var fwd := PilotMotor.forward(heading)
	var right := Vector2(-fwd.y,fwd.x)
	var hw: float = float(body.hh)*HeadlessBody.BULK_W
	var hl: float = float(body.hh)*HeadlessBody.BULK_L
	var best := -1
	var near := INF
	var side := 0.0
	for i in range(piers.size()):
		var u: Dictionary = piers[i]
		if not u.alive or absf(float(u.base)-p.y) > 1.0: continue
		var c: Vector3 = (u.frame as Transform3D).origin
		var rel := Vector2(c.x-p.x,c.z-p.z)
		var ahead_by := rel.dot(fwd)
		var off := rel.dot(right)
		if ahead_by < hl or ahead_by > VEER_AHEAD or absf(off) > hw+PIER_R+VEER_SIDE: continue
		# One in his way already: on as he goes.
		if absf(off) < hw: return heading
		if ahead_by < near:
			near = ahead_by
			best = i
			side = signf(off)
	if best < 0: return heading
	var c: Vector3 = (piers[best].frame as Transform3D).origin
	var aim := Vector2(c.x,c.z)-right*side*hw*0.6
	var want := PilotMotor.facing_of((aim-Vector2(p.x,p.z)).normalized())
	var out := wrapf(heading+clampf(angle_difference(heading,want),-VEER_MOST,VEER_MOST),-PI,PI)
	# Never off the terrace for it: level ground that way, all the way in.
	var way := PilotMotor.forward(out)
	for k in range(1,4):
		var q := p+Vector3(way.x,0.0,way.y)*near*k/3.0
		var g: float = body._floor(q,1.0,1.0)
		if g == -INF or absf(g-p.y) > 0.8: return heading
	return out

## The gable standing square across his way, his front within SMASH_REACH
## of its face and his feet at its foot: time to punch it.
func ahead(body: Node3D) -> bool:
	if gable.is_empty() or not gable.alive: return false
	var xf: Transform3D = gable.xf
	var local := xf.affine_inverse()*body.position
	if absf(local.y) > 1.6 or absf(local.x) > RuinKit.GABLE.x*0.5: return false
	var hl := float(body.hh)*HeadlessBody.BULK_L
	if absf(local.z)-hl-RuinKit.ARCH_DEPTH*0.5 > SMASH_REACH: return false
	var fwd: Vector3 = body._forward3()
	var toward := -xf.basis.z.normalized()*signf(local.z)
	return fwd.dot(toward) > SMASH_SQUARE

# --- A break --------------------------------------------------------------------------------

## Pier `i` snapped at `seam` m up (a drum joint near the hit), toppling
## along `dir` (flat); `push` the body's own way (its pieces carry some).
func _break_pier(i: int, dir: Vector3, seam: float, push: Vector3, _body: Node3D) -> void:
	var began := Time.get_ticks_usec()
	var u: Dictionary = piers[i]
	u.alive = false
	var f: Transform3D = u.frame
	var whole: bool = float(u.height) >= Spine.PIER_H
	var hgt: float = minf(float(u.height),Spine.PIER_H)
	seam = clampf(seam,0.45,maxf(0.45,hgt-0.5))
	var old: Node3D = u.node
	remove_child(old)
	old.queue_free()
	var group := _new_group(f.origin)
	# The stump: the kit's snapped pier, its ragged head at the seam.
	var b := Build.new(_seed+int(u.line)*13+int(u.side)*5,Spine.WEATHERED,"Stump_%d_%d" % [int(u.line),int(u.side)])
	b.settle = 0.5
	RuinKit._pier(b,Transform3D.IDENTITY,Spine.PIER_H,seam)
	var stump := b.finish()
	stump.transform = f
	add_child(stump)
	group.stump = stump
	# What stood over the seam, as one column: its drums, then the capital
	# (each a mesh and a shape of the one body, round its middle).
	var was := Build.detail
	Build.detail = PIECE_DETAIL
	var shaft_top := Spine.PIER_H-0.62 if whole else hgt
	var top := shaft_top+(CAPITAL.y if whole else 0.0)
	var mid_y := (seam+top)*0.5
	var subs: Array = []
	var y := seam
	var n := 0
	while y < shaft_top-0.15:
		var length := minf(_rng.randf_range(0.6,0.85),shaft_top-y)
		if shaft_top-(y+length) < 0.3: length = shaft_top-y
		var pb := Build.new(_seed+900+broken*31+n,Spine.WEATHERED,"Drum")
		RuinKit._drum_cluster(pb,Transform3D(Basis.IDENTITY,Vector3(0.0,-length*0.5,0.0)),length,[])
		var shape := CylinderShape3D.new()
		shape.radius = DRUM_R
		shape.height = length
		subs.append({"mesh":_mesh_of(pb.finish()),"shape":shape,"local":Transform3D(Basis.IDENTITY,Vector3(0.0,y+length*0.5-mid_y,0.0)),
			"kg":STONE_KG*PI*DRUM_R*DRUM_R*length*0.8,"kind":"drum"})
		y += length
		n += 1
	if whole:
		var pb := Build.new(_seed+950+broken*31,Spine.WEATHERED,"Capital")
		RuinKit._capital(pb,Transform3D(Basis.IDENTITY,Vector3(0.0,-CAPITAL.y*0.5,0.0)))
		var shape := CylinderShape3D.new()
		shape.radius = CAPITAL.x
		shape.height = CAPITAL.y
		subs.append({"mesh":_mesh_of(pb.finish()),"shape":shape,"local":Transform3D(Basis.IDENTITY,Vector3(0.0,shaft_top+CAPITAL.y*0.5-mid_y,0.0)),
			"kg":STONE_KG*CAPITAL.x*CAPITAL.x*2.8*CAPITAL.y,"kind":"capital"})
	Build.detail = was
	if not subs.is_empty():
		var xf := Transform3D(f.basis,f*Vector3(0.0,mid_y,0.0))
		var rb := _body_of(subs,xf)
		var flat := Vector3(push.x,0.0,push.z)
		# It goes over about its foot: slow at first, gravity doing the rest.
		var w := TOPPLE_W+TOPPLE_PUSH*flat.length()+_rng.randf_range(-0.1,0.1)
		var axis := Vector3.UP.cross(dir).normalized()
		var half := (top-seam)*0.5
		var lin := dir*w*half+flat*0.15
		var ang := axis*w+Vector3.UP*_rng.randf_range(-0.3,0.3)
		_go_piece(rb,group,"column",lin,ang,0.0,dir,1.0)
		var entry: Dictionary = live[-1] if not live.is_empty() and live[-1].rb == rb else {}
		if not entry.is_empty(): entry["burst"] = subs
	# The lintels it bore lose their footing.
	for j: int in u.lintels:
		if lintels[j].alive: _drop_lintel(j,f.origin+Vector3.UP*Spine.PIER_H,dir,push,group)
	# A portal's pier: its arch comes down after it.
	if int(u.portal) >= 0 and portals[int(u.portal)].alive:
		var pt: Dictionary = portals[int(u.portal)]
		var side := "l"
		for s: String in pt.piers:
			if int(pt.piers[s]) == i: side = s
		_drop_ring(int(u.portal),side,dir,push)
	var at := f*Vector3(0.0,seam,0.0)
	Dust.plume(self,at,4.6)
	Dust.rocks(self,at+Vector3.UP*0.5,dir,10,0.24)
	_sound(&"ruin_crack",at)
	_sound(&"ruin_fall",at)
	_shake(QUAKE_PIER)
	broken += 1
	_refresh_rids()
	build_ms = maxf(build_ms,(Time.get_ticks_usec()-began)/1000.0)

## Lintel `j` broken near `near` (an end whose pier went, or where he hit
## it) into two, falling (the far half, still on a pier, tips off it).
func _drop_lintel(j: int, near: Vector3, dir: Vector3, push: Vector3, group: Dictionary) -> void:
	var began := Time.get_ticks_usec()
	var l: Dictionary = lintels[j]
	l.alive = false
	var old: Node3D = l.node
	remove_child(old)
	old.queue_free()
	var a: Vector3 = l.a
	var e: Vector3 = l.b
	var t := _rng.randf_range(0.3,0.45)
	if a.distance_to(near) > e.distance_to(near): t = 1.0-t
	var cut := a.lerp(e,t)
	var was := Build.detail
	Build.detail = PIECE_DETAIL
	var k := 0
	for part: Array in [[a,cut],[cut,e]]:
		var p0: Vector3 = part[0]
		var p1: Vector3 = part[1]
		var length := p0.distance_to(p1)-0.06
		if length < 0.4: continue
		var b := Build.new(_seed+700+j*7+k,Spine.WEATHERED,"LintelChunk")
		var half := Vector3(length*0.5,Spine.LINTEL.y*0.5,Spine.LINTEL.x*0.5)
		# Its broken end cut on the slant (the crack), the other square.
		var s := -1.0 if part[0] == cut else 1.0
		var crack := Vector3(s,_rng.randf_range(-0.35,0.35),_rng.randf_range(-0.6,0.6)).normalized()
		var cuts: Array[Plane] = [Plane(crack,crack.dot(Vector3(s*(half.x-0.15),0.0,0.0)))]
		b.solid(RuinKit._box(b,half,0.07),Transform3D.IDENTITY,RuinKit._stone(b,1.03),false,true,cuts,-1,1.3)
		var x := (p1-p0).normalized()
		var z := x.cross(Vector3.UP).normalized()
		var basis := Basis(x,z.cross(x).normalized(),z)
		var shape := BoxShape3D.new()
		shape.size = half*2.0
		var mid := (p0+p1)*0.5+Vector3.DOWN*Spine.LINTEL.y*0.5
		var nearer := mid.distance_to(near) < (a.lerp(e,0.5)).distance_to(near)+0.01
		var up := 0.8 if nearer else 0.15
		var rb := _body_of([{"mesh":_mesh_of(b.finish()),"shape":shape,"local":Transform3D.IDENTITY,"kg":STONE_KG*half.x*half.y*half.z*8.0}],Transform3D(basis,mid))
		var flat := Vector3(push.x,0.0,push.z)*(0.25 if nearer else 0.08)
		var lin := dir*(0.5+1.6*up)+Vector3.UP*(0.2+0.5*up)+flat+Vector3(_rng.randf_range(-0.3,0.3),0.0,_rng.randf_range(-0.3,0.3))
		var ang := Vector3.UP.cross(dir).normalized()*(0.4+1.0*up)+Vector3(_rng.randf_range(-0.4,0.4),_rng.randf_range(-0.5,0.5),_rng.randf_range(-0.4,0.4))
		_go_piece(rb,group,"lintel",lin,ang,0.0,dir,up)
		k += 1
	Build.detail = was
	_sound(&"ruin_crack",cut)
	lintels_down += 1
	_refresh_rids()
	build_ms = maxf(build_ms,(Time.get_ticks_usec()-began)/1000.0)

## Portal `k`'s ring down, from side `side` ("l" or "r", its frame's): the
## chunks that side first, the crown, then the far side's high chunks; the
## far springer stands on its pier.
func _drop_ring(k: int, side: String, dir: Vector3, push: Vector3) -> void:
	var pt: Dictionary = portals[k]
	if not pt.alive: return
	pt.alive = false
	portals_down += 1
	var old: Node3D = pt.node
	remove_child(old)
	old.queue_free()
	var far := "r" if side == "l" else "l"
	var group := _new_group((pt.frame as Transform3D).origin)
	var keep: Node3D = pt.springs["spring_"+far]
	add_child(keep)
	group.stump = keep
	var f: Transform3D = pt.frame
	var across := f.basis.x.normalized()*(-1.0 if side == "l" else 1.0)
	var flat := Vector3(push.x,0.0,push.z)
	var fwd := (flat.normalized() if flat.length() > 0.3 else dir)
	var axis := Vector3.UP.cross(fwd).normalized()
	for part: Dictionary in pt.parts:
		var id: String = part.kind
		var wait := 0.0
		if id == "low_"+side: wait = 0.0
		elif id == "high_"+side: wait = 0.06
		elif id == "crown": wait = 0.14
		elif id == "high_"+far: wait = 0.32
		elif id == "low_"+far: wait = 0.55
		var rb := _body_of([{"mesh":part.mesh,"shape":part.shape,"local":Transform3D.IDENTITY,"kg":float(part.kg)}],Transform3D(Basis.IDENTITY,part.at))
		# They sag toward the lost side and out along his way.
		var lin := across*_rng.randf_range(0.4,1.2)+fwd*_rng.randf_range(0.8,1.8)+Vector3.DOWN*0.4
		var ang := axis*_rng.randf_range(0.3,0.9)+f.basis.z.normalized()*(0.5 if side == "l" else -0.5)*_rng.randf_range(0.5,1.2)
		_go_piece(rb,group,"chunk",lin,ang,wait,fwd,0.7)
	# Dust off the ground under the side that goes first (a plume in the
	# open air reads as a dark blot), stones off the ring.
	Dust.plume(self,f.origin+across*float(pt.h)*0.8,5.0)
	Dust.rocks(self,f*Vector3(0.0,Spine.PIER_H+2.0,0.0)+across*float(pt.h)*0.7,fwd,12,0.3)
	_sound(&"ruin_fall",f.origin)
	_shake(QUAKE_PIER*1.5)
	_refresh_rids()

## A turret or cella wall `k` down where he went into it: its stump stands,
## its upper halves go over away from him (the high tier a beat after).
func _drop_wall(k: int, body: Node3D) -> void:
	_drop_wall_from(k,body.position,body._forward3(),body.get("body"))

## Wall `k` down, hit from `from` going `fwd` (its upper halves go over
## away from there); `his` a body its slabs pass through, or null.
func _drop_wall_from(k: int, from: Vector3, fwd: Vector3, his: Variant) -> void:
	var w: Dictionary = walls[k]
	w.alive = false
	walls_down += 1
	var xf: Transform3D = w.xf
	var old: Node3D = w.node
	if is_instance_valid(old):
		old.get_parent().remove_child(old)
		old.queue_free()
	var stands: Node3D = w.stands
	add_child(stands)
	stands.global_transform = xf
	var group := _new_group(xf.origin)
	group.stump = stands
	for part: Dictionary in w.parts:
		var at: Vector3 = xf*(part.at as Vector3)
		var out := Vector3(at.x-from.x,0.0,at.z-from.z).normalized()
		var dir := (out*0.6+fwd*0.4).normalized()
		var axis := Vector3.UP.cross(dir).normalized()
		var hi := String(part.kind).begins_with("hi")
		var ang := axis*_rng.randf_range(0.7,1.1)+Vector3.UP*_rng.randf_range(-0.3,0.3)
		var lin := dir*_rng.randf_range(0.8,1.6)+ang.cross(Vector3.UP*float((part.size as Vector3).y)*0.5)
		var rb := _body_of([{"mesh":part.mesh,"shape":part.shape,"local":Transform3D.IDENTITY,"kg":float(part.kg)}],xf*Transform3D(Basis.IDENTITY,part.at))
		rb.angular_damp = 0.9
		if his is PhysicsBody3D: rb.add_collision_exception_with(his)
		for other: Variant in group.pieces:
			if is_instance_valid(other): rb.add_collision_exception_with(other as RigidBody3D)
		_go_piece(rb,group,"slab",lin,ang,0.12 if hi else 0.0,dir,0.5)
	var foot := xf.origin
	Dust.plume(self,foot+fwd*1.0,5.0)
	Dust.rocks(self,foot+Vector3.UP*2.0,fwd,14,0.3)
	_sound(&"ruin_crack",foot)
	_sound(&"ruin_fall",foot)
	_shake(QUAKE_PIER*1.5)
	_refresh_rids()

## The punch: the gable's door gone through, its slabs down in turn, its
## flanks left standing; a big beat (the pause, the shake, dust, a boom).
func smash(body: Node3D) -> void:
	_smash_from(body.position,body.vel,body.get("body"))

## The gable punched from `from` (its side of it), `push` the puncher's way,
## `his` a body its slabs pass through, or null.
func _smash_from(from: Vector3, push: Vector3, his: Variant) -> void:
	if gable.is_empty() or not gable.alive: return
	var began := Time.get_ticks_usec()
	gable.alive = false
	gable_down = true
	var xf: Transform3D = gable.xf
	var old: Node3D = gable.node
	if is_instance_valid(old):
		old.get_parent().remove_child(old)
		old.queue_free()
	var stands: Node3D = gable.stands
	add_child(stands)
	stands.global_transform = xf
	var group := _new_group(xf.origin)
	group.stump = stands
	var n := xf.basis.z.normalized()
	var local := xf.affine_inverse()*from
	var into := -n*signf(local.z) if absf(local.z) > 0.01 else -n
	var across := xf.basis.x.normalized()
	var axis := Vector3.UP.cross(into).normalized()
	for part: Dictionary in gable.parts:
		var id: String = part.kind
		var out := -across if id.ends_with("_l") else across
		var wait := 0.0
		var lin := Vector3.ZERO
		var ang := Vector3.ZERO
		match id:
			"door_l","door_r":
				# Blown in off his fists, the halves spinning apart.
				lin = into*_rng.randf_range(6.0,7.5)+Vector3.UP*_rng.randf_range(2.6,3.4)+out*1.6+Vector3(push.x,0.0,push.z)*0.3
				ang = axis*_rng.randf_range(0.9,1.4)+Vector3.UP*(0.7 if id == "door_r" else -0.7)
			"wall_l","wall_r":
				# Over the hole, nothing under them: they slump in.
				wait = 0.1
				lin = into*1.6+out*0.5+Vector3.DOWN*0.6
				ang = axis*0.4+n*(0.7 if id == "wall_l" else -0.7)*signf(-into.dot(n))
			"rose_tl","rose_tr","rose_bl","rose_br":
				# The rose hangs a beat, then comes apart out over him, down
				# the way he came, its quarters spreading.
				var low := id.begins_with("rose_b")
				wait = (0.28 if low else 0.36)+_rng.randf_range(0.0,0.05)
				out = -across if id.ends_with("l") else across
				lin = -into*(0.4 if low else 0.9)+out*0.7+Vector3.DOWN*0.2
				ang = -axis*_rng.randf_range(0.8,1.3)+n*(0.5 if id.ends_with("l") else -0.5)*signf(-into.dot(n))
			"rake_l","rake_r":
				# Off the flanks' broken heads: over and out, down the way he
				# came (the cella's walls stand behind them).
				wait = 0.45 if id == "rake_l" else 0.6
				lin = out*1.0+Vector3.UP*0.2
				ang = -axis*1.15+n*(-0.4 if id == "rake_l" else 0.4)*signf(-into.dot(n))
			"apex":
				wait = 0.55
				lin = -into*0.5+Vector3.DOWN*0.8
				ang = -axis*0.6
		# Turning about its foot, not its middle (its foot stays as it
		# goes over), all but the door's (blown off his fists).
		if not id.begins_with("door"):
			var half_up: Vector3 = xf.basis.y.normalized()*float((part.size as Vector3).y)*0.5
			lin += ang.cross(half_up)
		var rb := _body_of([{"mesh":part.mesh,"shape":part.shape,"local":Transform3D.IDENTITY,"kg":float(part.kg)}],xf*Transform3D(Basis.IDENTITY,part.at))
		# Heavy: it doesn't roll on far once down.
		rb.angular_damp = 0.9
		# (What of them stands still: a turret or a wall he went through
		# first is gone.)
		for c: Variant in gable.clear:
			if is_instance_valid(c): rb.add_collision_exception_with(c as PhysicsBody3D)
		if id.begins_with("rake") or id == "apex":
			for c: Variant in gable.high:
				if is_instance_valid(c): rb.add_collision_exception_with(c as PhysicsBody3D)
		# Nor on him: he strides on through what falls (it never props on
		# his shoulders, nor shoves him).
		if his is PhysicsBody3D: rb.add_collision_exception_with(his)
		# Nor on each other: pre-cut round the rose and the door, their
		# hulls overlap where they stood (they fall apart, not jammed).
		for other: Variant in group.pieces:
			if is_instance_valid(other): rb.add_collision_exception_with(other as RigidBody3D)
		_go_piece(rb,group,"slab",lin,ang,wait,into,0.5)
	var door := xf*Vector3(0.0,2.0,0.0)
	Dust.plume(self,door,7.0)
	Dust.plume(self,door+into*4.0,5.0)
	Dust.rocks(self,door+Vector3.UP*1.5,into,26,0.5)
	Dust.rocks(self,door+Vector3.UP*3.0,-into,10,0.35)
	_sound(&"ruin_boom",door)
	_sound(&"ruin_crack",door)
	_sound(&"ruin_fall",xf*Vector3(0.0,8.0,0.0))
	_shake(QUAKE_PUNCH)
	_pause(GABLE_HITSTOP,GABLE_HITSTOP_SCALE)
	_refresh_rids()
	build_ms = maxf(build_ms,(Time.get_ticks_usec()-began)/1000.0)

## The pre-cuts never used (out of the tree) go with this.
func _exit_tree() -> void:
	var orphans: Array = []
	for pt: Dictionary in portals:
		for id: String in pt.springs: orphans.append(pt.springs[id])
		if pt.alive:
			for part: Dictionary in pt.parts: orphans.append(part.mesh)
	for w: Dictionary in walls:
		orphans.append(w.stands)
		if w.alive:
			for part: Dictionary in w.parts: orphans.append(part.mesh)
	if not gable.is_empty():
		orphans.append(gable.stands)
		if gable.alive:
			for part: Dictionary in gable.parts: orphans.append(part.mesh)
	for n: Variant in orphans:
		if is_instance_valid(n) and not (n as Node).is_inside_tree() and (n as Node).get_parent() == null: (n as Node).free()

