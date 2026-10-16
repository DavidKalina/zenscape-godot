extends RefCounted
## The Olmec city kit's fire pieces, "fire on high":
## maker_cresset, maker_wickspire and ol_beacon. One cresset piece sized as a
## bowl, a tower's crown or a spire's top. All in the Olmec's weathered
## basalt (scripts/kit_isle/greybox/giant_stone.gd), the fire on the
## campfire's shaders (scripts/city_fire.gd). The fires are dressing: a
## piece stood "lit" burns for good, an unlit one stays a cold bowl: nothing
## lights them, puts them out or is drawn to them.
##
## Pieces (`build(id, parent, xform, opts)`, or the builders):
##   maker_cresset   `cresset`: a basalt fire bowl on a plinth (`size`:
##                   "cresset" one tier, "great" two). Lit, a real light. A
##                   breakable (the group of scripts/kit_isle/breakables.gd,
##                   the Olmec's breaker hub): standing it is air to his
##                   routes, so a body that barges into it (or lands his
##                   shockwave by it) tips it over, its fire out. A scene
##                   with no hub: "walker" makes it walker-only stone with
##                   its own barge check.
##   ol_beacon       `tower`: a stepped basalt tower of giant steps, its
##                   crown a cresset ("crown"). Lit, its crown is read from
##                   far off; a layer's towers say where the layers above are.
##   maker_wickspire `spire`: a tall lone hex column, a spiral of glyph steps,
##                   a crown cup with a cresset ("crown"): Mudge's home.
##
## Register in a kit registry with `PIECES` (id -> what it is) and `build`.
const CityFire = preload("res://scripts/city_fire.gd")
const GiantStone = preload("res://scripts/kit_isle/greybox/giant_stone.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const GroundCover = preload("res://scripts/underground/ground_cover.gd")
const CityStone = preload("res://scripts/city_kit_stone.gd")

const PIECES := {
	"maker_cresset":"Great cresset: a fire bowl on a plinth; lit, a light; barged, it tips",
	"ol_beacon":"Beacon tower: a stepped tower of giant steps with a cresset crown",
	"maker_wickspire":"Wick spire: a lone hex column, a spiral of glyph steps, a cresset crown",
}

## A tip: how long the bowl takes to go over (s).
const TIP_TIME := 0.75

## The cresset's sizes. Plinth tiers [side m, top in SET_OFFs]; shaft
## [radius, tall]; bowl [lip radius, depth]; fire [flame, bed]; light
## [range, energy, shadows].
const SIZES := {
	"cresset":{"tiers":[[3.6,1]],"shaft":[0.55,0.45],"bowl":[1.1,0.55],"fire":[1.5,1.3],
		"light":[24.0,6.0,false],"halo":6.0},
	"great":{"tiers":[[6.4,1],[4.6,2]],"shaft":[0.75,0.5],"bowl":[1.6,0.7],"fire":[2.3,2.0],
		"light":[34.0,10.0,true],"halo":10.0},
	"crown":{"tiers":[],"shaft":[0.4,0.3],"bowl":[0.95,0.45],"fire":[1.6,1.1],
		"light":[22.0,5.0,false],"halo":9.0},
}

static func size() -> float:
	return WorldScale.wanderer

## The rise between standing places on a climb (RuinKit.SET_OFF at his size).
static func set_off() -> float:
	return RuinKit.SET_OFF*size()

## How deep a place to stand is (RuinKit.STAND at his size), with a margin.
static func stand() -> float:
	return (RuinKit.STAND+0.12)*size()

## Piece `id` (PIECES) stood in `parent` at `xform`, `opts` its own.
static func build(id: String, parent: Node3D, xform: Transform3D, opts := {}) -> Node3D:
	match id:
		"maker_cresset": return cresset(parent,xform,opts)
		"ol_beacon": return tower(parent,xform,opts)
		"maker_wickspire": return spire(parent,xform,opts)
	push_error("city fires: no piece '%s'" % id)
	return null

# --- Ground cover ----------------------------------------------------------------------

## The underground's ground cover (scripts/underground/ground_cover.gd: dust,
## grass or moss by the flags; nothing with the look off) on a flat walk top
## at local `y` of `parent`: `outer` (x, z) less `inner` (what stands on it),
## laid as the strips round it. `tufts` (1 the cover's own): what grows
## through it; 0 for a skin only (the bowl's heat).
static func cover_ring(parent: Node3D, outer: Rect2, inner: Rect2, y: float, seed_value: int, tufts := 1.0) -> void:
	var strips: Array[Rect2] = []
	if inner.size.x <= 0.0 or inner.size.y <= 0.0: strips.append(outer)
	else:
		strips.append(Rect2(outer.position.x,outer.position.y,outer.size.x,inner.position.y-outer.position.y))
		strips.append(Rect2(outer.position.x,inner.end.y,outer.size.x,outer.end.y-inner.end.y))
		strips.append(Rect2(outer.position.x,inner.position.y,inner.position.x-outer.position.x,inner.size.y))
		strips.append(Rect2(inner.end.x,inner.position.y,outer.end.x-inner.end.x,inner.size.y))
	var i := 0
	for r: Rect2 in strips:
		i += 1
		if r.size.x < 0.2 or r.size.y < 0.2: continue
		GroundCover.cover(parent,r,"",y+0.002,seed_value*7+i,{"tufts":tufts,"under":tufts,"fade":0.25})

# --- The Olmec ---------------------------------------------------------------------------

static var _fields: Array = []
static var _fields_frame := -1000

## The headless bodies (and whole Olmecs) of every enemy field on the scene.
static func olmecs(tree: SceneTree) -> Array:
	var out: Array = []
	if tree == null or tree.current_scene == null: return out
	var f := Engine.get_physics_frames()
	if f-_fields_frame > 60 or f < _fields_frame:
		_fields_frame = f
		_fields = tree.current_scene.find_children("EnemyField","",true,false)
	for field: Variant in _fields:
		if not is_instance_valid(field): continue
		var list: Variant = (field as Node).get("enemies")
		if not (list is Array): continue
		for e: Variant in list:
			if is_instance_valid(e) and (e as Node).has_method("make_whole") and (e as Node).is_inside_tree(): out.append(e)
	return out

# --- Stone -------------------------------------------------------------------------------

## A lathe in the giant's stone: `profile` [Vector2(radius, y)] from the
## foot up, turned `segments` times round `place`'s y; `inward` for a face
## seen from the axis (a bowl's inside); `chip` the rng that bites the top
## rim (or null); `tone` darker for soot.
static func lathe(m: GiantStone.Mesher, place: Transform3D, profile: Array, segments: int, inward := false, tone := 1.0, foot := NAN) -> void:
	m._centre = place.origin
	m._foot = place.origin.y if is_nan(foot) else foot
	m._tone = tone
	for k in segments:
		var a0 := TAU*k/segments
		var a1 := TAU*(k+1)/segments
		var d0 := Vector3(cos(a0),0.0,sin(a0))
		var d1 := Vector3(cos(a1),0.0,sin(a1))
		for j in profile.size()-1:
			var p: Vector2 = profile[j]
			var q: Vector2 = profile[j+1]
			var pts: Array = [d0*p.x+Vector3.UP*p.y,d1*p.x+Vector3.UP*p.y,d1*q.x+Vector3.UP*q.y,d0*q.x+Vector3.UP*q.y]
			if p.x < 0.001: pts = [pts[0],pts[2],pts[3]]
			elif q.x < 0.001: pts = [pts[0],pts[1],pts[2]]
			var mid := (d0+d1).normalized()*(p.x+q.x)*0.5+Vector3.UP*(p.y+q.y)*0.5
			var axis := Vector3.UP*mid.y
			# The way out the face looks: off the axis (or toward it), or up/down for a flat ring.
			var out := (mid-axis)
			if absf(p.x-q.x) > absf(p.y-q.y)*1.5: out = Vector3.UP*(1.0 if (q.x < p.x) != inward else -1.0)
			elif inward: out = -out
			m._poly(place,pts,mid-out.normalized())

## The chipped lip of a bowl: a ring of quads over the rim at `y`, from
## `r_in` to `r_out`, each segment's top bitten by `rng` (silhouette).
static func lip(m: GiantStone.Mesher, place: Transform3D, r_in: float, r_out: float, y: float, segments: int, rng: RandomNumberGenerator) -> void:
	m._tone = 1.05
	for k in segments:
		var a0 := TAU*k/segments
		var a1 := TAU*(k+1)/segments
		var d0 := Vector3(cos(a0),0.0,sin(a0))
		var d1 := Vector3(cos(a1),0.0,sin(a1))
		var bite := rng.randf_range(0.0,0.07) if rng.randf() < 0.35 else 0.0
		var top := y-bite
		m._poly(place,[d0*r_in+Vector3.UP*top,d1*r_in+Vector3.UP*top,d1*r_out+Vector3.UP*top,d0*r_out+Vector3.UP*top],(d0+d1).normalized()*(r_in+r_out)*0.5+Vector3.UP*(top-1.0))
		if bite > 0.0:
			# The bite's walls, so the chip reads in silhouette.
			m._poly(place,[d0*r_in+Vector3.UP*top,d0*r_out+Vector3.UP*top,d0*r_out+Vector3.UP*y,d0*r_in+Vector3.UP*y],d0*(r_in+r_out)*0.5+d1*0.5+Vector3.UP*top)
			m._poly(place,[d1*r_in+Vector3.UP*top,d1*r_out+Vector3.UP*top,d1*r_out+Vector3.UP*y,d1*r_in+Vector3.UP*y],d1*(r_in+r_out)*0.5+d0*0.5+Vector3.UP*top)

## The bowl: outside, the chipped lip, the inside crusted with soot, the
## resin bed. Its lip at local y `depth`, its foot at 0.
static func bowl_stone(m: GiantStone.Mesher, place: Transform3D, radius: float, depth: float, foot_r: float, rng: RandomNumberGenerator) -> void:
	var wall := maxf(0.14,radius*0.12)
	var bed_y := depth*0.45
	lathe(m,place,[Vector2(0.0,0.0),Vector2(foot_r,0.0),Vector2(foot_r*1.25,depth*0.3),Vector2(radius*0.82,depth*0.72),Vector2(radius,depth*0.94),Vector2(radius,depth)],18)
	lip(m,place,radius-wall,radius,depth,18,rng)
	lathe(m,place,[Vector2(radius-wall,depth),Vector2(radius-wall*1.2,depth*0.8),Vector2(radius*0.72,bed_y+0.04),Vector2(radius*0.62,bed_y),Vector2(0.0,bed_y)],18,true,0.45)

## A StaticBody3D of `shapes` ([Shape3D, Transform3D] each) in `parent`,
## walker-only if `walker` (the Olmec's rays don't see it).
static func solid(parent: Node3D, shapes: Array, walker := false, node_name := "Solid") -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	for s: Array in shapes:
		var c := CollisionShape3D.new()
		c.shape = s[0]
		c.transform = s[1]
		body.add_child(c)
	if walker: WalkerOnly.mark(body)
	parent.add_child(body)
	return body

static func box_shape(size_m: Vector3, at: Vector3) -> Array:
	var b := BoxShape3D.new()
	b.size = size_m
	return [b,Transform3D(Basis.IDENTITY,at)]

static func cyl_shape(radius: float, tall: float, at: Vector3) -> Array:
	var c := CylinderShape3D.new()
	c.radius = radius
	c.height = tall
	return [c,Transform3D(Basis.IDENTITY,at)]

static func mesh_node(parent: Node3D, m: GiantStone.Mesher, node_name := "Stone") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	GiantStone.warm()
	mi.mesh = m.mesh(CityStone.wear("fire"),GiantStone._runes)
	parent.add_child(mi)
	return mi

# --- The cresset ---------------------------------------------------------------------------

## A cresset in `parent` at `xform` (its foot). opts: "size" (SIZES key,
## "cresset"), "lit" (false), "seed", "walker" (true: walker-only stone,
## barged over by the Olmec; a crown's is false), "barge", "beam".
static func cresset(parent: Node3D, xform: Transform3D, opts := {}) -> Cresset:
	var c := Cresset.new()
	c.name = str(opts.get("name","Cresset"))
	c.transform = xform
	c.kind = str(opts.get("size","cresset"))
	c.barge = bool(opts.get("barge",c.kind != "crown"))
	c.walker = bool(opts.get("walker",false))
	c.seed_value = int(opts.get("seed",hash(xform.origin)))
	c.beam = float(opts.get("beam",1.0))
	parent.add_child(c)
	c.stand_up()
	if bool(opts.get("lit",false)): c.burn()
	return c

class Cresset extends Node3D:
	## Tipped over.
	signal tipped(dir: Vector3)
	const Kit = preload("res://scripts/city_kit_fires.gd")
	const HeadlessBody = preload("res://scripts/enemies/headless_body.gd")
	## Of his shockwave's reach, the share inside which it snaps.
	const WAVE_BREAK := 0.62
	var kind := "cresset"
	## Barged over by the Olmec (the breakables hub's piece): a crown's isn't.
	var barge := true
	## Walker-only stone, and its own barge check (a scene with no hub).
	var walker := false
	var plinth_body: StaticBody3D = null
	var _hub: Node = null
	## The plinth's runes: their glow out and burning.
	const RUNES_OUT := 0.06
	const RUNES_LIT := 0.7
	var runes: ShaderMaterial = null
	var _rune_e := RUNES_OUT
	var seed_value := 0
	## Seen from far off (a far layer's tower): its halo this times wider,
	## its flame taller by the root of it.
	var beam := 1.0
	var lit := false
	var broken := false
	## The plinth's top (local y), the bowl's lip (local y), its radius.
	var top := 0.0
	var lip_y := 0.0
	var radius := 1.0
	## The widest tier's half side (m): what a body barges.
	var half := 1.0
	var fire: Node3D
	## What tips: the shaft's head, the bowl and its fire.
	var bowl: Node3D
	var bowl_body: StaticBody3D
	var _tip_t := -1.0
	var _tip_from := Transform3D()
	var _tip_to := Transform3D()

	func spec() -> Dictionary:
		return Kit.SIZES[kind]

	func stand_up() -> void:
		var s: Dictionary = spec()
		var k := Kit.size()
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var m := GiantStone.mesher()
		var shapes: Array = []
		top = 0.0
		half = 0.0
		for t: Array in s.tiers:
			var side := float(t[0])*k
			var y := float(t[1])*Kit.set_off()
			m.box(Transform3D(Basis.IDENTITY,Vector3(0.0,(top+y)*0.5,0.0)),Vector3(side,y-top,side),0.14,0.0)
			shapes.append(Kit.box_shape(Vector3(side,y-top,side),Vector3(0.0,(top+y)*0.5,0.0)))
			half = maxf(half,side*0.5)
			top = y
		var shaft: Array = s.shaft
		var b: Array = s.bowl
		radius = float(b[0])*k
		var depth := float(b[1])*k
		var sr := float(shaft[0])*k
		var st := float(shaft[1])*k
		lip_y = top+st+depth
		half = maxf(half,radius)
		# The plinth's foot course: a band of glyph runes on the top tier's face.
		if not s.tiers.is_empty():
			var last: Array = s.tiers[s.tiers.size()-1]
			var hs := float(last[0])*k*0.5
			var band := top-0.95*k
			for f: Vector3 in [Vector3.BACK,Vector3.RIGHT]:
				var side_v := f.cross(Vector3.UP)
				m.runes(f*(hs+0.005)+side_v*hs*0.8+Vector3.UP*band,f*(hs+0.005)-side_v*hs*0.8+Vector3.UP*band,Vector3.UP,f,float(seed_value%97)+f.x*3.0)
		# Its runes in their own material: faint dark, flaring as it burns.
		GiantStone.warm()
		runes = (GiantStone._runes as ShaderMaterial).duplicate() as ShaderMaterial
		runes.set_shader_parameter("energy",RUNES_OUT)
		var pm := MeshInstance3D.new()
		pm.name = "Plinth"
		pm.mesh = m.mesh(CityStone.wear("fire"),runes)
		add_child(pm)
		# The bowl and the shaft's head: one piece that tips.
		bowl = Node3D.new()
		bowl.name = "Bowl"
		bowl.position = Vector3(0.0,top,0.0)
		add_child(bowl)
		var mb := GiantStone.mesher()
		# The shaft: a squat drum, the crouching bearer's stand-in, a helmet ring.
		mb.cylinder(Transform3D(Basis.IDENTITY,Vector3(0.0,st*0.5,0.0)),sr,st,12,0.06,0.0)
		mb.cylinder(Transform3D(Basis.IDENTITY,Vector3(0.0,st*0.85,0.0)),sr*1.12,st*0.3,12,0.05,0.0,0.85)
		Kit.bowl_stone(mb,Transform3D(Basis.IDENTITY,Vector3(0.0,st,0.0)),radius,depth,sr*0.95,rng)
		mesh_node_into(bowl,mb,"BowlStone")
		bowl_body = Kit.solid(bowl,[Kit.cyl_shape(sr,st,Vector3(0.0,st*0.5,0.0)),Kit.cyl_shape(radius,depth,Vector3(0.0,st+depth*0.5,0.0))],walker,"BowlSolid")
		if not shapes.is_empty(): plinth_body = Kit.solid(self,shapes,walker,"PlinthSolid")
		# The underground's cover on the tiers' tops: root and moss on the
		# lower, a dusting by the bowl (nothing grows in its heat).
		var ty := 0.0
		for ti in s.tiers.size():
			var t: Array = s.tiers[ti]
			var side := float(t[0])*k
			ty = float(t[1])*Kit.set_off()
			var inner := 0.0
			if ti+1 < s.tiers.size(): inner = float((s.tiers[ti+1] as Array)[0])*k
			else: inner = sr*2.0
			Kit.cover_ring(self,Rect2(-side*0.5,-side*0.5,side,side),Rect2(-inner*0.5,-inner*0.5,inner,inner),ty,seed_value+ti,0.0 if ti == s.tiers.size()-1 else 0.6)
		if barge: add_to_group(&"breakable")
		# The fire in the bowl, on its resin bed.
		var f: Array = s.fire
		var l: Array = s.light
		fire = CityFire.new()
		fire.name = "Fire"
		fire.flame = float(f[0])*k
		fire.bed = float(f[1])*k
		fire.light_range = float(l[0])
		fire.light_energy = float(l[1])
		fire.shadows = bool(l[2])
		fire.halo = float(s.halo)*beam
		fire.flame *= sqrt(beam)
		fire.halo_glow = 0.55+0.1*(beam-1.0)
		fire.position = Vector3(0.0,st+depth*0.45+0.02,0.0)
		bowl.add_child(fire)

	func mesh_node_into(p: Node3D, m: GiantStone.Mesher, n: String) -> void:
		Kit.mesh_node(p,m,n)

	## The bowl's rim's middle (world).
	func rim() -> Vector3:
		return to_global(Vector3(0.0,lip_y,0.0))

	## Where the fire stands (world).
	func fire_point() -> Vector3:
		return fire.global_position

	## Burning from the start (no flare), for good.
	func burn() -> void:
		if lit or broken: return
		lit = true
		fire.burn()

	# --- The breakables hub's protocol (scripts/kit_isle/breakables.gd) ---------------

	## Standing, it is air to his rays: he plans through it and barges it.
	func standing_rids() -> Array[RID]:
		var out: Array[RID] = []
		if broken or not barge: return out
		if plinth_body != null: out.append(plinth_body.get_rid())
		out.append(bowl_body.get_rid())
		return out

	## Fallen, the bowl is waded.
	func rubble_rids() -> Array[RID]:
		var out: Array[RID] = []
		if broken: out.append(bowl_body.get_rid())
		return out

	## His bulk (the box his push-out has) against the plinth: over it goes,
	## his way.
	func met(hub: Node, b: Node3D) -> void:
		if broken or not barge: return
		var hh: float = b.get("hh")
		var low: float = b.global_position.y+0.3
		var high: float = b.global_position.y+float(b.call("_bulk_top"))
		var me := global_position
		if high < me.y or low > me.y+lip_y: return
		var rel := Basis(Vector3.UP,float(b.get("facing"))).inverse()*(me-b.global_position)
		var bw := hh*HeadlessBody.BULK_W
		var bl := hh*HeadlessBody.BULK_L
		if absf(rel.x) > bw+half*0.8 or absf(rel.z) > bl+half*0.8: return
		var v: Vector3 = b.get("vel")
		var way := Vector3(v.x,0.0,v.z)
		if way.length() < 0.3: way = b.call("_forward3")
		if b.has_method("stagger"): b.call("stagger",0.4)
		_hub = hub
		hub.call("shake",0.3)
		hub.call("pause",3,0.15)
		tip(way.normalized())

	## His landing's shockwave front: near enough, it snaps the shaft and
	## the bowl goes over, away from where he landed.
	func wave(hub: Node, _b: Node3D, w: Dictionary) -> void:
		if broken or not barge: return
		var at: Vector3 = w.at
		var me := global_position
		var d := Vector2(me.x-at.x,me.z-at.z).length()
		if d > float(w.r) or d > float(w.max)*WAVE_BREAK+half or absf(at.y-me.y) > 4.0: return
		_hub = hub
		hub.call("shake",0.25)
		tip(Vector3(me.x-at.x,0.0,me.z-at.z))

	func _physics_process(delta: float) -> void:
		var tree := get_tree()
		if runes != null:
			var want := RUNES_LIT if lit else RUNES_OUT
			if absf(_rune_e-want) > 0.001:
				_rune_e = move_toward(_rune_e,want,delta*(0.5 if lit else 1.2))
				runes.set_shader_parameter("energy",_rune_e)
		if _tip_t >= 0.0:
			_tip(delta)
		elif not broken and walker and barge: _barged(tree)

	## A body barging through the plinth tips it its way.
	func _barged(tree: SceneTree) -> void:
		var me := global_position
		for e: Variant in Kit.olmecs(tree):
			var b := e as Node3D
			var v: Vector3 = b.get("vel")
			var flat := Vector2(b.global_position.x-me.x,b.global_position.z-me.z)
			var reach := float(b.get("width"))*0.5+half*0.8
			if flat.length() > reach or absf(b.global_position.y-me.y) > top+2.5: continue
			var way := Vector3(v.x,0.0,v.z)
			if way.length() < 0.6: continue
			tip(way.normalized())
			return

	## Over it goes, `dir` (world, flat): the bowl falls off its plinth onto
	## the ground that way, its fire out.
	func tip(dir: Vector3) -> void:
		if broken: return
		broken = true
		if lit:
			lit = false
			fire.douse()
		bowl_body.collision_layer = 0
		var d := Vector3(dir.x,0.0,dir.z).normalized()
		if d.length() < 0.5: d = Vector3.FORWARD
		var axis := Vector3.UP.cross(d).normalized()
		var land := global_position+d*(half+radius*1.1)
		var floor_y := _floor_at(land+Vector3.UP*(top+3.0))
		_tip_from = bowl.global_transform
		var lie := Basis(axis,deg_to_rad(100.0))*_tip_from.basis
		_tip_to = Transform3D(lie,Vector3(land.x,floor_y+radius*0.75,land.z))
		_tip_t = 0.0
		tipped.emit(d)

	func _floor_at(from: Vector3) -> float:
		var q := PhysicsRayQueryParameters3D.create(from,from+Vector3.DOWN*60.0)
		q.collision_mask = 1
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		return global_position.y if hit.is_empty() else (hit.position as Vector3).y

	func _tip(delta: float) -> void:
		_tip_t += delta/TIP_TIME
		var u := clampf(_tip_t,0.0,1.0)
		# Slow at first about its foot, then falling (gravity's ease-in),
		# a small bounce where it lands.
		var e := u*u
		var xf := _tip_from.interpolate_with(_tip_to,e)
		xf.origin.y += sin(u*PI)*0.4
		if _tip_t > 1.0:
			var b := _tip_t-1.0
			xf = _tip_to
			xf.origin.y += maxf(0.0,sin(b*PI/0.35))*0.18*maxf(0.0,1.0-b/0.35)
			if b > 0.35:
				_tip_t = -1.0
				xf = _tip_to
				# Rubble now: stood on (walker-only, as it stood).
				if walker: WalkerOnly.mark(bowl_body)
				else: bowl_body.collision_layer = 1
				if _hub != null and is_instance_valid(_hub):
					_hub.call("changed",AABB(bowl.global_position-Vector3.ONE*(half+2.0),Vector3.ONE*(half+2.0)*2.0))
		bowl.global_transform = xf

# --- The beacon tower --------------------------------------------------------------------

## A beacon tower in `parent` at `xform` (its foot's middle, its steps on
## local +z). opts: "tiers" (3), "tier" (tier height in SET_OFFs, 3),
## "base" (side m, 8.0), "lit", "seed", "steps" (true: the giant steps up
## its face; a far one leaves them out).
static func tower(parent: Node3D, xform: Transform3D, opts := {}) -> Tower:
	var t := Tower.new()
	t.name = str(opts.get("name","BeaconTower"))
	t.transform = xform
	parent.add_child(t)
	t.beam = float(opts.get("beam",1.0))
	t.stand_up(int(opts.get("tiers",3)),int(opts.get("tier",3)),float(opts.get("base",8.0)),int(opts.get("seed",hash(xform.origin))),bool(opts.get("steps",true)))
	if bool(opts.get("lit",false)): t.crown.burn()
	return t

class Tower extends Node3D:
	const Kit = preload("res://scripts/city_kit_fires.gd")
	var crown: Cresset
	## The crown shelf's top (local y).
	var top := 0.0
	## Its crown's beam (Cresset `beam`).
	var beam := 1.0

	## Tiers each `tier` SET_OFFs tall, set back on the stepped face (+z)
	## more than round the rest; on that face, per tier, a run of giant
	## steps (blocks SET_OFF apart up, side by side) to the tier's top.
	func stand_up(tiers: int, tier: int, base: float, seed_value: int, steps: bool) -> void:
		var k := Kit.size()
		var rise := Kit.set_off()
		var deep := Kit.stand()
		var m := GiantStone.mesher()
		var shapes: Array = []
		var w := base*k
		var front := base*0.5*k
		var back := -base*0.5*k
		var y := 0.0
		var step_w := maxf(1.3*k,deep*2.0)
		# Two stands deep: stood on, he is clear of the tier's face, so a
		# jump along the run catches the next step, not a wall run.
		var step_d := deep*2.0
		# Each tier's run starts where the last ended (stood on the tier's
		# top, the next run's first step is straight ahead), and turns back
		# when the tier is too narrow to go on.
		var run_x := w*0.5-step_w*0.5
		var dirn := -1.0
		var tops: Array = []
		for i in tiers:
			var h := rise*tier
			var mid := Vector3(0.0,y+h*0.5,(front+back)*0.5)
			tops.append([Rect2(-w*0.5,back,w,front-back),y+h])
			var sz := Vector3(w,h,front-back)
			m.box(Transform3D(Basis.IDENTITY,mid),sz,0.16,y)
			shapes.append(Kit.box_shape(sz,mid))
			if steps:
				var half_w := w*0.5-step_w*0.5
				run_x = clampf(run_x,-half_w,half_w)
				if absf(run_x+dirn*step_w*float(tier-2)) > half_w+0.01: dirn = -dirn
				var x := run_x
				for j in range(1,tier):
					x = run_x+dirn*step_w*float(j-1)
					var st := Vector3(step_w,rise*j,step_d)
					var at := Vector3(x,y+rise*j*0.5,front+step_d*0.5)
					m.box(Transform3D(Basis.IDENTITY,at),st,0.1,y)
					shapes.append(Kit.box_shape(st,at))
				run_x = x
			y += h
			if i < tiers-1:
				# Set back: on the stepped face a run of steps deep and a place
				# to stand in front of them; a little round the rest. A far
				# tower with no steps tapers evenly.
				front -= (step_d+deep+0.15*k) if steps else 0.5*k
				back += 0.25*k if steps else 0.5*k
				w -= 0.7*k
		top = y
		# The underground's cover on each tier's set-back and the crown shelf.
		for i in tops.size():
			var r: Rect2 = tops[i][0]
			var inner := Rect2()
			if i+1 < tops.size(): inner = tops[i+1][0]
			Kit.cover_ring(self,r,inner,float(tops[i][1]),seed_value+i,0.5 if i+1 < tops.size() else 0.0)
		Kit.mesh_node(self,m,"TowerStone")
		Kit.solid(self,shapes,false,"TowerSolid")
		crown = Kit.cresset(self,Transform3D(Basis.IDENTITY,Vector3(0.0,top,(front+back)*0.5)),{"size":"crown","seed":seed_value,"walker":false,"name":"Crown","beam":beam})

# --- The wick spire ----------------------------------------------------------------------

## A wick spire in `parent` at `xform` (its foot). opts: "tall" (m, 16),
## "radius" (m, 1.6), "lit", "seed". Its glyph steps spiral up SET_OFF
## apart, three to a quarter turn; its crown a cup with a cresset.
static func spire(parent: Node3D, xform: Transform3D, opts := {}) -> Spire:
	var s := Spire.new()
	s.name = str(opts.get("name","WickSpire"))
	s.transform = xform
	parent.add_child(s)
	s.stand_up(float(opts.get("tall",16.0)),float(opts.get("radius",1.6)),int(opts.get("seed",hash(xform.origin))))
	if bool(opts.get("lit",false)): s.crown.burn()
	return s

class Spire extends Node3D:
	const Kit = preload("res://scripts/city_kit_fires.gd")
	var crown: Cresset
	var top := 0.0

	func stand_up(tall: float, radius: float, seed_value: int) -> void:
		var k := Kit.size()
		var rise := Kit.set_off()
		var deep := Kit.stand()+0.1*k
		var m := GiantStone.mesher()
		var shapes: Array = []
		# The drum it is rooted in, then the hex shaft, tapering a little.
		var drum_r := radius*1.9
		var drum_h := rise
		m.cylinder(Transform3D(Basis.IDENTITY,Vector3(0.0,drum_h*0.5,0.0)),drum_r,drum_h,10,0.14,0.0)
		shapes.append(Kit.cyl_shape(drum_r,drum_h,Vector3(0.0,drum_h*0.5,0.0)))
		var shaft_h := tall-drum_h
		m.cylinder(Transform3D(Basis.IDENTITY,Vector3(0.0,drum_h+shaft_h*0.5,0.0)),radius,shaft_h,6,0.08,drum_h)
		shapes.append(Kit.cyl_shape(radius*0.93,shaft_h,Vector3(0.0,drum_h+shaft_h*0.5,0.0)))
		# The glyph steps: three to a quarter turn, SET_OFF apart.
		var y := drum_h+rise
		var a := 0.0
		while y < tall-0.2:
			var d := Vector3(cos(a),0.0,sin(a))
			var at := d*(radius+deep*0.5-0.05)+Vector3.UP*(y-0.2*k)
			var b := Basis(Vector3.UP,-a)
			var sz := Vector3(deep+0.1,0.4*k,1.25*k)
			m.box(Transform3D(b,at),sz,0.07,drum_h)
			shapes.append([_box(sz),Transform3D(b,at)])
			y += rise
			a += PI/6.0
		top = tall
		# The crown cup: a wide flared lip a perch round the bowl.
		var cup_r := maxf(radius*1.35,RuinKit.TOP_ROOM*k+0.95*k)
		var cup_h := 0.5*k
		m.cylinder(Transform3D(Basis.IDENTITY,Vector3(0.0,tall+cup_h*0.5,0.0)),cup_r,cup_h,12,0.1,tall)
		shapes.append(Kit.cyl_shape(cup_r,cup_h,Vector3(0.0,tall+cup_h*0.5,0.0)))
		top = tall+cup_h
		Kit.mesh_node(self,m,"SpireStone")
		Kit.solid(self,shapes,false,"SpireSolid")
		crown = Kit.cresset(self,Transform3D(Basis.IDENTITY,Vector3(0.0,top,0.0)),{"size":"crown","seed":seed_value,"walker":false,"name":"Crown"})

	func _box(sz: Vector3) -> BoxShape3D:
		var b := BoxShape3D.new()
		b.size = sz
		return b
