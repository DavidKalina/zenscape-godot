extends Node3D
## The Olmec's destruction, round 1 (docs/design/roguelike/olmec-destruction-
## round1.md): the colonnade spine's plain piers and its lintels (studies/
## colonnade_spine_isle_art.gd `colonnade`, `breakable`) stood each on its
## own, for the headless body (scripts/enemies/headless_body.gd, `breaker`)
## to tear through. Nintendo-style scripted breaks, not voxels:
##
##   a pier met by his bulk (`met`) or reached by his landing's shockwave
##   (`wave`) snaps at a drum joint near where it was hit: a stump stays
##   (the kit's snapped pier, its ragged head), the drums over the joint and
##   the capital go as pieces, toppling the way he pushed (or out from the
##   wave); a lintel it bore, or one his chest meets, breaks in two near
##   that end and falls.
##   The pieces are Jolt RigidBody3Ds a second or two (MAX_BODIES at most at
##   once; past that a piece skips the physics and lands as rubble where it
##   would lie), then freeze where they came to rest: static rubble he and
##   the walker stand on (a lintel half-fallen off its last pier is a ramp, a
##   drum a step). A break's rubble, settled, is drawn as one mesh (its
##   stump with it), and the bodies read its ground afresh (`world_changed`).
##
## What still stands is left out of the body's rays (`standing_rids`): he
## plans and walks through it as if it were air, and it breaks as he does.
## Breaks last the session. Only the body breaks things.
const Spine = preload("res://studies/colonnade_spine_isle_art.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")
const Build = RuinKit.Build
const Dust = preload("res://scripts/enemies/body_dust.gd")
const HeadlessBody = preload("res://scripts/enemies/headless_body.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")
## His veer into a pier beside his way (`veer`): how far on (m), how far
## past his flank (m), how much at most (rad, under his ROUTE_TURN).
const VEER_AHEAD := 8.0
const VEER_SIDE := 3.6
const VEER_MOST := 0.34

## Live pieces at most (scripts/native_explosives.gd's MAX_BODIES, at this
## scale): past it a piece lands as rubble at once.
const MAX_BODIES := 24
## A piece this still (m/s, rad/s) this long (s) is rubble.
const STILL_V := 0.35
const STILL_W := 0.6
const STILL_FOR := 0.25
## Live this long (s) and slow, it is frozen where it is; falling on past
## LIVE_MOST (off the isle), it is gone.
const SETTLE_MOST := 2.5
const LIVE_MOST := 7.0
## A pier's reach round its middle (its sub-base's half), a drum's radius,
## the capital's.
const PIER_R := 0.62
const DRUM_R := 0.55
const CAPITAL := Vector2(0.66,0.62)
const STONE_KG := 2300.0
## Of a shockwave's reach, the piers inside this share of it fall (surely
## near, by chance to its edge).
const WAVE_BREAK := 0.62
## The pause on impact: the game this slow this many frames.
const HITSTOP_FRAMES := 4
const HITSTOP_SCALE := 0.12
## How much of the colonnade's growth each unit grows (a unit is a Build of
## its own, its ivy no longer one strand budget across the whole colonnade:
## at 0.16 the colonnade's growth is 23.4k triangles against the one Build's
## 24.8k; 0.2 jumps to 31k, the lintels' fringes coming in).
const IVY_SHARE := 0.16
## The pieces' look: no growth of their own (ivy hanging from a toppled drum
## points the wrong way); the stump keeps its.
const PIECE_DETAIL := 0.0
## Placeholder sounds (studies/enemy_yard.gd `_synth`: seconds, tone, tone at
## the end, noise share, low-pass, attack, tremolo) and their reach (m).
const VOICES := {
	"ruin_crack":[0.35,0.0,0.0,1.0,0.55,0.001,0.0],
	"ruin_fall":[1.6,38.0,24.0,0.8,0.07,0.04,6.0],
	"ruin_thud":[0.45,60.0,38.0,0.55,0.16,0.002,0.0],
}
const REACH := {"ruin_crack":36.0,"ruin_fall":50.0,"ruin_thud":20.0}

## The piers: {line, side, frame, height (INF whole), node, alive, base, top, lintels}.
var piers: Array = []
## The lintels: {a, b, top, node, alive, piers}.
var lintels: Array = []
## Live pieces: {rb, t, still, group, v, kind}.
var live: Array = []
## The scene's enemies (scripts/enemies/enemy_field.gd), told of new rubble.
var field: Node = null
## (name, at): the scene's sound.
var sound_hook := Callable()
## Under this (world y) a piece is gone.
var lost_y := -INF
var _rids: Array[RID] = []
var _rubble: Array[RID] = []
var _rng := RandomNumberGenerator.new()
var _seed := 0
var _hitstop := 0
var _material := PhysicsMaterial.new()
## Counted, for checks and the HUD.
var broken := 0
var lintels_down := 0
var peak_live := 0
var landed_direct := 0
var settled_groups := 0
## The longest a break took to build (ms).
var build_ms := 0.0

## The units stood from the colonnade's `breakable` meta (Spine `colonnade`).
func setup(colonnade: Node3D, seed_value: int) -> void:
	name = "Breaks"
	_seed = seed_value
	_rng.seed = seed_value*7919+3
	_material.friction = 0.9
	_material.bounce = 0.05
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
			"base":f.origin.y,"top":f.origin.y+minf(hgt,Spine.PIER_H),"lintels":[]})
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
	Build.detail = was
	_refresh_rids()

## What still stands, and the pieces still flying (left out of the body's
## rays: he walks through the one, and the other is gone in a moment).
func standing_rids() -> Array[RID]:
	return _rids

## The rubble come to rest: ground to him (his feet and his routes read it),
## but his bulk and legs wade through it (a lintel's half is ankle-high to
## him), never shoved back off it.
func rubble_rids() -> Array[RID]:
	return _rubble

func _refresh_rids() -> void:
	_rids.clear()
	for u: Dictionary in piers+lintels:
		if u.alive: _rids.append((u.node as Node3D).get_node("Body").get_rid())
	for p: Dictionary in live: _rids.append((p.rb as RigidBody3D).get_rid())

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
	if hits > 0:
		body.stagger(minf(1.0,0.55*hits))
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
		var ahead := rel.dot(fwd)
		var off := rel.dot(right)
		if ahead < hl or ahead > VEER_AHEAD or absf(off) > hw+PIER_R+VEER_SIDE: continue
		# One in his way already: on as he goes.
		if absf(off) < hw: return heading
		if ahead < near:
			near = ahead
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

func _pause() -> void:
	if _hitstop <= 0: Engine.time_scale = HITSTOP_SCALE
	_hitstop = HITSTOP_FRAMES

# --- A break --------------------------------------------------------------------------------

func _new_group(at: Vector3) -> Dictionary:
	return {"pieces":[],"left":0,"box":AABB(at,Vector3.ZERO),"stump":null}

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
	# What stood over the seam: its drums, then the capital.
	var was := Build.detail
	Build.detail = PIECE_DETAIL
	var shaft_top := Spine.PIER_H-0.62 if whole else hgt
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
		var mid := y+length*0.5
		_launch(pb.finish(),Transform3D(f.basis,f*Vector3(0.0,mid,0.0)),shape,STONE_KG*PI*DRUM_R*DRUM_R*length*0.8,dir,mid/Spine.PIER_H,push,group,"drum")
		y += length
		n += 1
	if whole:
		var pb := Build.new(_seed+950+broken*31,Spine.WEATHERED,"Capital")
		RuinKit._capital(pb,Transform3D(Basis.IDENTITY,Vector3(0.0,-CAPITAL.y*0.5,0.0)))
		var shape := CylinderShape3D.new()
		shape.radius = CAPITAL.x
		shape.height = CAPITAL.y
		_launch(pb.finish(),Transform3D(f.basis,f*Vector3(0.0,shaft_top+CAPITAL.y*0.5,0.0)),shape,STONE_KG*CAPITAL.x*CAPITAL.x*2.8*CAPITAL.y,dir,1.0,push,group,"capital")
	Build.detail = was
	# The lintels it bore lose their footing.
	for j: int in u.lintels:
		if lintels[j].alive: _drop_lintel(j,f.origin+Vector3.UP*Spine.PIER_H,dir,push,group)
	var at := f*Vector3(0.0,seam,0.0)
	Dust.plume(self,at,3.6)
	Dust.rocks(self,at+Vector3.UP*0.5,dir,8,0.22)
	_sound(&"ruin_crack",at)
	_sound(&"ruin_fall",at)
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
		_launch(b.finish(),Transform3D(basis,mid),shape,STONE_KG*half.x*half.y*half.z*8.0,dir,0.8 if nearer else 0.15,push*(1.0 if nearer else 0.3),group,"lintel")
		k += 1
	Build.detail = was
	_sound(&"ruin_crack",cut)
	lintels_down += 1
	_refresh_rids()
	build_ms = maxf(build_ms,(Time.get_ticks_usec()-began)/1000.0)

## A built piece (`piece`: its Mesh, its Body let go) set going at `xf` as a
## rigid body of `shape`, `kg`: toppling along `dir`, the higher (`up`, 0
## its foot to 1 its top) the faster; past MAX_BODIES, laid as rubble at once.
func _launch(piece: Node3D, xf: Transform3D, shape: Shape3D, kg: float, dir: Vector3, up: float, push: Vector3, group: Dictionary, kind: String) -> void:
	var mesh := piece.get_node("Mesh") as MeshInstance3D
	piece.remove_child(mesh)
	piece.free()
	var rb := RigidBody3D.new()
	rb.name = "Piece"
	rb.collision_layer = 1
	rb.collision_mask = 1
	rb.mass = maxf(kg,50.0)
	rb.physics_material_override = _material
	var holder := CollisionShape3D.new()
	holder.shape = shape
	rb.add_child(holder)
	rb.add_child(mesh)
	add_child(rb)
	rb.global_transform = xf
	group.pieces.append(rb)
	group.box = (group.box as AABB).expand(xf.origin)
	if live.size() >= MAX_BODIES:
		_lay(rb,dir,up,kind)
		landed_direct += 1
		return
	var flat := Vector3(push.x,0.0,push.z)
	rb.linear_velocity = dir*(0.8+3.2*up)+Vector3.UP*(0.4+0.8*up)+flat*0.5+Vector3(_rng.randf_range(-0.4,0.4),0.0,_rng.randf_range(-0.4,0.4))
	rb.angular_velocity = Vector3.UP.cross(dir).normalized()*(0.8+2.0*up)+Vector3(_rng.randf_range(-0.5,0.5),_rng.randf_range(-0.8,0.8),_rng.randf_range(-0.5,0.5))
	group.left += 1
	live.append({"rb":rb,"t":0.0,"still":0.0,"group":group,"v":rb.linear_velocity,"kind":kind})
	peak_live = maxi(peak_live,live.size())

## Past the cap: laid where it would lie, a little along `dir` from where it
## stood, on its side (a drum, the capital) or flat (a lintel's half), and
## frozen there.
func _lay(rb: RigidBody3D, dir: Vector3, up: float, kind: String) -> void:
	var from := rb.global_position+dir*(0.6+2.4*up)
	var skip: Array[RID] = [rb.get_rid()]
	skip.append_array(_rids)
	var q := PhysicsRayQueryParameters3D.create(from+Vector3.UP*2.0,from+Vector3.DOWN*30.0,1,skip)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var ground: float = (hit.position as Vector3).y if not hit.is_empty() else from.y-2.0
	var yaw := Basis(Vector3.UP,_rng.randf_range(-PI,PI))
	var lie := yaw
	var rest := Spine.LINTEL.y*0.5
	if kind == "drum":
		lie = Basis(Vector3.UP.cross(dir).normalized(),PI*0.5)*Basis(Vector3.UP,_rng.randf_range(-PI,PI))
		rest = DRUM_R*0.92
	elif kind == "capital":
		lie = Basis(Vector3.UP.cross(dir).normalized(),_rng.randf_range(1.2,1.6))
		rest = CAPITAL.x*0.85
	else:
		lie = Basis(Vector3.UP,atan2(dir.x,dir.z)+_rng.randf_range(-0.6,0.6)+PI*0.5)
	rb.global_transform = Transform3D(lie,Vector3(from.x,ground+rest,from.z))
	_freeze(rb)

func _freeze(rb: RigidBody3D) -> void:
	rb.linear_velocity = Vector3.ZERO
	rb.angular_velocity = Vector3.ZERO
	rb.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	rb.freeze = true
	_rubble.append(rb.get_rid())

# --- The pieces, live -----------------------------------------------------------------------

func _process(_delta: float) -> void:
	if _hitstop > 0:
		_hitstop -= 1
		if _hitstop == 0: Engine.time_scale = 1.0

func _physics_process(delta: float) -> void:
	if live.is_empty(): return
	var done: Array = []
	for p: Dictionary in live:
		p.t += delta
		var rb: RigidBody3D = p.rb
		var v := rb.linear_velocity
		# A hard stop (it hit the ground or another stone): a puff, a thud.
		var lost_v: float = ((p.v as Vector3)-v).length()
		if lost_v > 2.5 and float(p.t) > 0.08:
			Dust.puff(self,rb.global_position,0.9+0.25*minf(lost_v,6.0))
			if lost_v > 3.5: _sound(&"ruin_thud",rb.global_position)
		p.v = v
		if v.length() < STILL_V and rb.angular_velocity.length() < STILL_W: p.still += delta
		else: p.still = 0.0
		if float(p.still) >= STILL_FOR or (float(p.t) > SETTLE_MOST and v.length() < 2.0):
			_freeze(rb)
			done.append(p)
		elif rb.global_position.y < lost_y or float(p.t) > LIVE_MOST:
			(p.group.pieces as Array).erase(rb)
			rb.queue_free()
			done.append(p)
	for p: Dictionary in done:
		live.erase(p)
		p.group.left -= 1
		if int(p.group.left) <= 0: _settled(p.group)
	if not done.is_empty(): _refresh_rids()

## A break's pieces all at rest: drawn as one mesh with its stump, and its
## ground read afresh by every body.
func _settled(group: Dictionary) -> void:
	if group.get("merged",false): return
	group.merged = true
	settled_groups += 1
	var root := Node3D.new()
	root.name = "Rubble"
	add_child(root)
	var box: AABB = group.box
	var holders: Array = []
	for rb: RigidBody3D in group.pieces:
		if not is_instance_valid(rb): continue
		box = box.expand(rb.global_position)
		var mesh := rb.get_node_or_null("Mesh") as MeshInstance3D
		if mesh == null: continue
		var holder := Node3D.new()
		holder.transform = rb.transform
		rb.remove_child(mesh)
		holder.add_child(mesh)
		root.add_child(holder)
		holders.append(holder)
	var stump: Node3D = group.stump
	if stump != null and is_instance_valid(stump):
		# The stump's own stone and growth go in; it keeps its own body.
		var mesh := stump.get_node_or_null("Mesh") as MeshInstance3D
		if mesh != null:
			var holder := Node3D.new()
			holder.transform = stump.transform
			stump.remove_child(mesh)
			holder.add_child(mesh)
			root.add_child(holder)
			holders.append(holder)
	RuinKit.merge(root)
	for h: Node3D in holders: h.free()
	box = box.grow(1.5)
	if field != null:
		for e in field.enemies:
			if is_instance_valid(e) and e.has_method("world_changed"): e.world_changed(box)

func _sound(sound_name: StringName, at: Vector3) -> void:
	if sound_hook.is_valid(): sound_hook.call(sound_name,at)

## The draws the breaks add now (meshes under this, each surface).
func draws() -> int:
	var n := 0
	for m: Node in find_children("*","MeshInstance3D",true,false):
		var mi := m as MeshInstance3D
		if mi.visible and mi.mesh != null: n += mi.mesh.get_surface_count()
	return n
