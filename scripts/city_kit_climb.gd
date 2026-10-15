extends RefCounted
## The city kit's climb pieces (docs/design/roguelike/city-climb-round1.md):
## lanes for two bodies, in the underground Olmec city's weathered basalt
## (the `city` family; scripts/city_kit.gd registers them, see the handoff).
## Each piece cuts two lanes into one stone: his (the Olmec's, scripts/
## enemies/headless_body.gd) wide, plain and his size, and the wanderer's
## narrow, broken and clever, on the walker-only layer (scripts/
## walker_only.gd) where he must not read it, with a true safe room in it
## (out of his reach, his sight and his inhale). From the round 3 cards
## (docs/design/roguelike/brainstorm/round3-olmec-city/):
##   city_riser    the giant's riser (k2 colossus_riser): treads a riser too
##                 tall for her and a stride for him; her chimney climbs
##                 inside the left cheek behind the treads, in by an arch at
##                 its foot, out by a door onto the summit
##   city_lip      the hauling lip (k3 oc_lip): a face he climbs and a deep
##                 cornice his hands come over, worn hand-troughs in its top;
##                 under it the undercut, her hide, and her shelf chain up
##                 the face's end; the far corner is pre-cracked and breaks
##                 under his weight
##   city_pit      the leaper's pit (k3 oc_pit): two plinths across a gap
##                 inside his jump and past hers, flanked by fins; the inner
##                 cornice along the fins is hers (the east one cracked: his
##                 landing breaks it, nearest first)
##   city_wrap     the wrapped pillar (k3 oc_wrap): a square core with his
##                 ramp wound round it (his lane, his landings), her climb up
##                 a recess carved in the core's south face, a safe cell
##                 halfway up it
##   city_terrace  the hanging terrace (k7 ol_terrace): two decks hung on a
##                 host wall, his stair between them; under the upper one
##                 the undercroft (too low for him) and her shelves up
##                 through a hatch; the upper deck's outer tier snaps under
##                 his weight
##   city_wedge    the wedged chunk (k7 ol_wedge): a fallen slab jammed
##                 against a crown block, its top his ramp; her chimney
##                 between it and the flanking wall; the hollow under its
##                 high end her hide
##
## Every size is read from the two bodies (`numbers`: the wanderer's
## WorldScale, RuinKit GRAB_TOP / CHAIN_TOP / SET_OFF / STAND, PhysicsGround;
## the Olmec's `default_knobs` and `build_of`) and checked by `fit()`.
##
## Each piece, as the city kit's (CityKit.Piece): a Node3D, front toward +Z,
## "Mesh" (stone, then runes) and "Body" (his and hers, layer 1), and a
## "WalkerOnly" body (hers alone). Its y 0 is the ground it stands on (the
## riser's foot, the wrap's start, the terrace's lower deck, the wedge's
## foot, the pit's plinth tops), or for the lip the top it is climbed to.
## Meta (CityKit's, and): "kind", "sizes", "his" (what he can and can't do),
## "his_lane" / "hers" / "safe" (local AABBs: his lane, hers, her safe
## room), "ports" (named local points), "breaks", "walk_areas", "triangles".
##
##   var n := CityKitClimb.piece("city_riser", 7)   # or CityKit.stand(...)
const CityKit = preload("res://scripts/city_kit.gd")
const Stone = preload("res://scripts/city_kit_stone.gd")
const WalkerOnly = preload("res://scripts/walker_only.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const PhysicsGround = preload("res://scripts/pilot_physics_ground.gd")
const HeadlessBody = preload("res://scripts/enemies/headless_body.gd")
const FloorBreak = preload("res://scripts/city_breaks/floor_break.gd")

const FAMILY := "city"
const PIECES := ["city_riser","city_lip","city_pit","city_wrap","city_terrace","city_wedge"]
const NAMES := {"city_riser":"Giant's riser","city_lip":"Hauling lip","city_pit":"Leaper's pit",
	"city_wrap":"Wrapped pillar","city_terrace":"Hanging terrace","city_wedge":"Wedged chunk"}
const CARDS := {"city_riser":"colossus_riser (k2)","city_lip":"oc_lip (k3)","city_pit":"oc_pit (k3)",
	"city_wrap":"oc_wrap (k3)","city_terrace":"ol_terrace (k7)","city_wedge":"ol_wedge (k7)"}

## The walker-only shelves and chimney ledges: the refuges' proven numbers
## (city-refuges-round1.md: the slotted wall's chimney 2.41 across with 0.9
## ledges a set-off up, alternating leaves; the niches' 1.4 x 1.02 shelves
## zigzagging 0.5 apart), as shares of the walker.
const LEDGE_DEEP := 0.9
const SHELF := Vector2(1.4,1.02)
const SHELF_GAP := 0.5
const SHELF_THICK := 0.4
## A walker's door through the stone (wide, tall): she fits, he doesn't.
const DOOR := Vector2(1.4,1.9)

# --- The two bodies -----------------------------------------------------------------------

static var _numbers := {}

## Both bodies' numbers (m), at the wanderer's scale. The wanderer: tall,
## radius, grab (a jump's catch, GRAB_TOP), chain (the second jump's,
## CHAIN_TOP), rise (SET_OFF), stand. The Olmec (his own knobs): hh, width,
## length, neck, arm, reach (the swat's flat reach), swat_dy (its height
## band), climb_max, step, stair (a riser he walks up), jump_gap (ledge to
## ledge), leap_max, press (a lip he mantles at once), bulk (his shoulders
## and arms across, BULK_W both sides), pounce (min, max flat), shock_band.
static func numbers() -> Dictionary:
	if not _numbers.is_empty(): return _numbers
	var ws: float = WorldScale.wanderer
	var unit := PhysicsGround.HEAD*ws
	var b: Node = HeadlessBody.new()
	var k: Dictionary = b.default_knobs({"walk":PilotMotor.WALK,"run":PilotMotor.RUN,"unit":unit,"gravity":20.0})
	b.free()
	var o := HeadlessBody.build_of(k,unit)
	var hh := float(o.hh)
	var n := {
		"ws":ws,"tall":PhysicsGround.HEAD*ws,"radius":PhysicsGround.RADIUS*ws,
		"grab":RuinKit.GRAB_TOP*ws,"chain":RuinKit.CHAIN_TOP*ws,"rise":RuinKit.SET_OFF*ws,"stand":RuinKit.STAND*ws,
		"hh":hh,"width":float(o.width),"length":float(o.length),"neck":float(o.neck),"arm":float(o.arm),
		"reach":float(k.catch_reach)*hh,"swat_dy":float(o.neck)*0.6,"climb_max":float(k.climb_max),
		"step":float(k.step),"stair":float(k.step)*HeadlessBody.STAIR,"jump_gap":float(k.jump_gap)*hh,
		"leap_max":float(k.leap_max),"press":float(o.neck)*0.55,"bulk":2.0*HeadlessBody.BULK_W*hh,
		"pounce":Vector2(float(k.pounce_min)*hh,float(k.pounce_max)*hh),"shock_band":float(k.shock_band),
		# His planner's column (body_routes.gd CELL) and a place he fits: its
		# 3 x 3 columns on one floor.
		"fit":3.0*1.5,
	}
	_numbers = n
	return n

## The pieces' sizes (m), each from the numbers (see the handoff's table).
static var _sizes := {}
static func sizes() -> Dictionary:
	if not _sizes.is_empty(): return _sizes
	var n := numbers()
	var ws: float = n.ws
	var so: float = n.rise
	var cell := CityKit.CELL*ws
	var s := {
		"set_off":so,"cell":cell,
		# His lane and landing: the kit's two cells (his bulk 6.7 m eased off
		# both walls; city-kit-round1.md).
		"lane":CityKit.LANE*ws,"landing":CityKit.LANDING*ws,
		"chimney":1.5*so,"ledge":LEDGE_DEEP*ws,"shelf":SHELF*ws,"shelf_gap":SHELF_GAP*ws,
		# The riser: two set-offs, over her chain catch (the card's 2.2 m she
		# reaches on her second jump), under his press-up; the tread his
		# column fit and his turn on it.
		"riser":2.0*so,"tread":1.5*cell,"riser_cheek":so+1.5*so+0.75*so,
		# The lip: the cornice (a course of three-quarter set-off), its
		# overhang a quarter set-off (his head stays out of it as he hangs),
		# the undercut a set-off tall (her headroom), a metre deep.
		"cornice":0.75*so,"over":0.25*so,"undercut":so,"undercut_deep":1.4*ws,"sill":1.3*ws,
		# The pit: a stride inside his jump (and past hers: measured).
		"pit_gap":float(n.jump_gap)-0.3*float(n.hh),"fin":0.75*so,"fin_up":3.0*so,"pit_deep":24.0*ws,
		# The wrap: the core three cells, a side's rise two set-offs.
		"core":3.0*cell,"side_rise":2.0*so,"slab":so,
		# The terrace: the undercroft two set-offs clear (under his neck,
		# over her head), the fall deck to deck a course (under the 6 m stun).
		"undercroft":2.0*so,"deck_drop":3.0*so,
		# The wedge: the chunk's run and rise (17 degrees), its thickness.
		"wedge_run":7.0*cell,"wedge_rise":6.0*so,"wedge_thick":3.0*so,
	}
	_sizes = s
	return s

## Each derived size against what it must be: [name, value, bound, ok, why].
static func fit() -> Array:
	var n := numbers()
	var s := sizes()
	var out: Array = []
	var add := func(what: String, v: float, bound: float, ok: bool, why: String) -> void: out.append([what,v,bound,ok,why])
	add.call("riser over her chain catch",s.riser,n.chain,float(s.riser) > float(n.chain)+0.2,"a wall to her")
	add.call("riser under his press-up",s.riser,n.press,float(s.riser) <= float(n.press),"he mantles each at once")
	add.call("riser over his stair step",s.riser,n.stair,float(s.riser) > float(n.stair),"a climb to him, not a step")
	add.call("tread over his fit",s.tread,n.fit,float(s.tread) >= float(n.fit),"his planner fits each tread")
	add.call("lane over his bulk",s.lane,n.bulk,float(s.lane) >= float(n.bulk)+1.5,"his shoulders clear both walls")
	add.call("chimney under his width",s.chimney,n.width,float(s.chimney) < float(n.width)*0.6,"he never enters, never stands in it (his fit 4.5)")
	add.call("door under his width",DOOR.x*float(n.ws),n.width,DOOR.x*float(n.ws) < float(n.width)*0.5,"")
	add.call("pit gap under his jump",s.pit_gap,n.jump_gap,float(s.pit_gap) < float(n.jump_gap),"he jumps it")
	add.call("undercroft under his neck",s.undercroft,n.neck,float(s.undercroft) < float(n.neck),"he can't stand under")
	add.call("undercroft over her",s.undercroft,n.tall,float(s.undercroft) > float(n.tall)+0.6,"she stands, jumps")
	add.call("deck drop under the fall stun",s.deck_drop,PilotMotor.FALL_STUN_PUMPS*1.5,float(s.deck_drop) <= 5.5,"a fall lands standing")
	add.call("wrap side under his step a column",float(s.side_rise)/float(s.core)*1.5,n.step,float(s.side_rise)/float(s.core)*1.5 < float(n.step),"walked")
	add.call("wedge slope (deg)",rad_to_deg(atan2(float(s.wedge_rise),float(s.wedge_run))),PilotMotor.SLOPE_SLOW,rad_to_deg(atan2(float(s.wedge_rise),float(s.wedge_run))) < PilotMotor.SLOPE_SLOW,"walked by both")
	add.call("lip face under his climb",4.0*float(s.set_off)+float(s.cornice)+float(s.undercut)+2.0*float(s.set_off),n.climb_max,true,"")
	add.call("ledge rise under her grab",s.set_off,n.grab,float(s.set_off) < float(n.grab),"one jump a ledge")
	return out

# --- The pieces ---------------------------------------------------------------------------

static func piece(id: String, seed_value := 1, weathered := 0.4, opts := {}) -> Node3D:
	match id:
		"city_riser": return riser(seed_value,weathered,opts)
		"city_lip": return lip(seed_value,weathered,opts)
		"city_pit": return pit(seed_value,weathered,opts)
		"city_wrap": return wrapped(seed_value,weathered,opts)
		"city_terrace": return terrace(seed_value,weathered,opts)
		"city_wedge": return wedge(seed_value,weathered,opts)
	push_error("city_kit_climb: no piece %s" % id)
	return null

# --- Builders -----------------------------------------------------------------------------

## A box's planes from its low and high corners.
static func _bx(lo: Vector3, hi: Vector3, bevel := 0.0) -> Array:
	return Stone.box(Transform3D(Basis.IDENTITY,(lo+hi)*0.5),(hi-lo)*0.5,bevel)

## A box drawn and collided (into `into`, the piece's body if null); its
## collision stops CityKit.GAP over `foot` (what it stands on) if given.
static func _solid(b: RefCounted, lo: Vector3, hi: Vector3, foot := NAN, into: CollisionObject3D = null, chips := 0.6, bevel := 0.06) -> void:
	var clip: Array = [] if is_nan(foot) else [CityKit.over(foot)]
	b.block(_bx(lo,hi,bevel),true,into,chips,null,clip)

## A box collided whole (as `_solid`) and drawn as coursed masonry: courses
## about a set-off tall, each cut into big staggered blocks along its longer
## side, chamfered and chipped, their tones a little apart (the joints and
## the tone steps carry the scale; the shader the weathering).
static func _coursed(b: RefCounted, lo: Vector3, hi: Vector3, foot := NAN, into: CollisionObject3D = null, course := 1.6, chips := 0.7, collide := true, cuts: Array = []) -> void:
	if collide:
		var typed: Array[Plane] = CityKit._typed(_bx(lo,hi)+cuts)
		if not is_nan(foot): typed.append(CityKit.over(foot))
		b.hull(Geometry3D.compute_convex_mesh_points(typed),into)
	var size := hi-lo
	var along := 0 if size.x >= size.z else 2
	var n := maxi(1,int(roundf(size.y/course)))
	var ch := size.y/n
	var rng: RandomNumberGenerator = b.rng
	for k in n:
		var y0 := lo.y+k*ch
		var y1 := y0+ch
		var a := lo[along]
		var end := hi[along]
		var first := true
		while a < end-0.05:
			var l := rng.randf_range(2.2,4.6) if not (first and k%2 == 1) else rng.randf_range(1.0,2.2)
			first = false
			var bb := minf(a+l,end)
			if end-bb < 1.0: bb = end
			var blo := lo
			var bhi := hi
			blo.y = y0
			bhi.y = y1
			blo[along] = a
			bhi[along] = bb
			if cuts.is_empty(): b.block(_bx(blo,bhi,0.07),false,null,chips)
			else: b.block(_bx(blo,bhi,0.07)+cuts,false,null,chips)
			a = bb

## A colossal face in low relief on a riser's front (`z` the face, `x` its
## middle, `y0`..`y1` its height): the inhaler's heavy brow, sunk eyes, a
## broad flat nose, the mouth a dark slot at the foot (drawn only).
static func _relief(b: RefCounted, x: float, z: float, y0: float, y1: float, half: float) -> void:
	var h := y1-y0
	var out := 0.22
	_drawn(b,Vector3(x-half*0.92,y0+h*0.62,z),Vector3(x+half*0.92,y0+h*0.8,z+out),1.08,0.12)
	for s: float in [-1.0,1.0]:
		_drawn(b,Vector3(x+s*half*0.45-half*0.22,y0+h*0.44,z),Vector3(x+s*half*0.45+half*0.22,y0+h*0.6,z+0.04),0.5,0.04)
		_drawn(b,Vector3(x+s*half*0.82-0.35,y0+h*0.2,z),Vector3(x+s*half*0.82+0.35,y0+h*0.58,z+out*0.8),1.0,0.12)
	_drawn(b,Vector3(x-half*0.18,y0+h*0.24,z),Vector3(x+half*0.18,y0+h*0.62,z+out*1.6),1.05,0.15)
	_drawn(b,Vector3(x-half*0.42,y0+h*0.1,z),Vector3(x+half*0.42,y0+h*0.2,z+out*0.9),1.0,0.08)
	_drawn(b,Vector3(x-half*0.34,y0,z-0.02),Vector3(x+half*0.34,y0+h*0.1,z+0.03),0.4,0.02)

## A box drawn only (`tone` lighter or darker if not 1).
static func _drawn(b: RefCounted, lo: Vector3, hi: Vector3, tone := 1.0, bevel := 0.05) -> void:
	if tone == 1.0: b.block(_bx(lo,hi,bevel),false,null,0.5)
	else: b.m.solid(_bx(lo,hi,bevel),NAN,tone)

## The piece's walker-only body (hers alone: he and his planner never read it).
static func _hers_body(b: RefCounted, node_name := "WalkerOnly") -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	WalkerOnly.mark(body)
	b.root.add_child(body)
	return body

## A walker-only ledge (top `top`, `lo`/`hi` its footprint x, z).
static func _ledge(b: RefCounted, into: CollisionObject3D, x0: float, x1: float, z0: float, z1: float, top: float) -> void:
	_solid(b,Vector3(x0,top-SHELF_THICK*0.875,z0),Vector3(x1,top,z1),NAN,into,0.3,0.05)

static func _aabb(lo: Vector3, hi: Vector3) -> AABB:
	return AABB(lo,hi-lo)

## A breakable unit (scripts/city_breaks/floor_break.gd, or a subclass)
## of `cells` pieces, each a box (unit-local lo, hi), its "Body" on `layer`
## (1, or the walker-only LAYER); `top` the unit's top in the piece.
static func _unit(b: RefCounted, unit: Node3D, node_name: String, at: Vector3, cells: Array, kind: String, weight: float, walker_only := false) -> Node3D:
	unit.name = node_name
	unit.transform = Transform3D(Basis.IDENTITY,at)
	var body := StaticBody3D.new()
	body.name = "Body"
	unit.add_child(body)
	if walker_only: WalkerOnly.mark(body)
	var box := AABB()
	var kg := 0.0
	for i in cells.size():
		var lo: Vector3 = cells[i][0]
		var hi: Vector3 = cells[i][1]
		var mid := (lo+hi)*0.5
		var h := (hi-lo)*0.5
		var mesher := Stone.Mesher.new(Stone.stone_colour(),0.2)
		mesher.rest_frame = Transform3D(Basis.IDENTITY,at+mid)
		b.block(Stone.box(Transform3D.IDENTITY,h-Vector3(0.03,0.0,0.03),0.05),false,null,0.8,mesher)
		# The crack's tell: a paler seam face on each piece's top.
		mesher.solid(Stone.box(Transform3D(Basis.IDENTITY,Vector3(0.0,h.y-0.01,0.0)),Vector3(h.x-0.05,0.02,0.04),0.0),NAN,1.3)
		var shape := BoxShape3D.new()
		shape.size = h*2.0+Vector3(CityKit.SEAM,0.0,CityKit.SEAM)
		CityKit._unit_piece(unit,i,Transform3D(Basis.IDENTITY,mid),mesher,[[shape,Transform3D.IDENTITY]])
		box = AABB(lo,hi-lo) if i == 0 else box.merge(AABB(lo,hi-lo))
		kg += CityKit.STONE_KG*(hi-lo).x*(hi-lo).y*(hi-lo).z
	b.root.add_child(unit)
	var d := {"kind":kind,"unit":node_name,"pieces":cells.size(),"box":box,"kg":kg/maxf(cells.size(),1),"weight":weight}
	(b.meta.breaks as Array).append(d)
	CityKit._arm(unit,d)
	return unit

## The piece done: its meta (`extra` over the builder's) and its node.
static func _finish(b: RefCounted, kind: String, extra: Dictionary) -> Node3D:
	b.meta["kind"] = kind
	for k: String in extra: b.meta[k] = extra[k]
	return b.finish()

## The east cornice's segments (the pit): a cracked walker-only slab his
## landing's shockwave breaks when its front passes within `reach` m of it
## and he came down over it (his plinth top, within `drop` m over it).
class CorniceBreak extends "res://scripts/city_breaks/floor_break.gd":
	var reach := 6.5
	var drop := 3.0

	## Not his weight: he never stands on her cornice.
	func met(_hub: Node, _body: Node3D) -> void:
		pass

	func wave(hub: Node, _body: Node3D, w: Dictionary) -> void:
		if not alive: return
		var at: Vector3 = w.at
		var mid := global_transform*box.get_center()
		var flat := Vector2(mid.x-at.x,mid.z-at.z).length()
		if flat <= minf(float(w.r),reach) and at.y-mid.y > 0.0 and at.y-mid.y < drop:
			break_now(hub,at,Vector3.ZERO)

# --- The giant's riser (colossus_riser) ------------------------------------------------------

## The giant's riser. y 0 its foot's ground; the flight climbs from z 0 toward
## -Z: `treads` (4) treads `riser` (3.2) up and `tread` (6.6) deep, the last
## the summit landing (`landing` deep), `lane` (8.8) wide between cheeks a
## riser over the tread beside them. Her chimney climbs inside the left
## cheek beside the summit: an arch in the cheek's outer face at the foot,
## ledges up alternate leaves a set-off apart, a platform under the roof, a
## door through the inner wall onto the summit. His: walks each tread,
## climbs and presses up each riser; never in the cheek. Opts: treads.
static func riser(seed_value: int, weathered := 0.4, opts := {}) -> Node3D:
	var b := CityKit.Piece.new("CityRiser",seed_value,weathered)
	var s := sizes()
	var n := numbers()
	var hers := _hers_body(b,"Chimney")
	var count: int = opts.get("treads",4)
	var r: float = s.riser
	var deep: float = s.tread
	var land: float = s.landing
	var hw: float = float(s.lane)*0.5
	var so: float = s.set_off
	var ch: float = s.chimney
	var wall_in := so
	var wall_out := 0.75*so
	var cw := wall_in+ch+wall_out
	var top := count*r
	var zn := -(count-1)*deep
	var z_back := zn-land
	var zc := zn-land*0.5
	var treads: Array = []
	for i in range(1,count+1):
		var z_front := -(i-1)*deep
		var z_rear := z_front-(land if i == count else deep)
		var h := i*r
		_coursed(b,Vector3(-hw,0.0,z_rear),Vector3(hw,h,z_front),0.0,null,so)
		# The riser's face: a colossal face in low relief (the inhaler's
		# brow, its mouth a dark slot at the tread's foot), a glyph band on
		# the nosing over it.
		_relief(b,0.0,z_front,h-r,h-0.35,hw*0.62)
		b.runes(Vector3(-hw+0.4,h-0.32,z_front),Vector3(hw-0.4,h-0.32,z_front),Vector3.UP,Vector3.BACK,0.3)
		treads.append(Vector3(0.0,h,(z_front+z_rear)*0.5))
		b.rect_area("summit" if i == count else "tread",Rect2(-hw,z_rear,hw*2.0,z_front-z_rear),h)
		# The cheeks: a riser over the tread they flank.
		var ct := h+r
		_coursed(b,Vector3(hw,0.0,z_rear),Vector3(hw+cw,ct,z_front),0.0,null,so)
		b.rect_area("cheek",Rect2(hw,z_rear,cw,z_front-z_rear),ct)
		b.runes(Vector3(hw+cw,ct-1.6,z_front-0.6),Vector3(hw+cw,ct-1.6,z_rear+0.6),Vector3.UP,Vector3.RIGHT,0.7)
		if i < count:
			_coursed(b,Vector3(-hw-cw,0.0,z_rear),Vector3(-hw,ct,z_front),0.0,null,so)
			b.rect_area("cheek",Rect2(-hw-cw,z_rear,cw,z_front-z_rear),ct)
			b.runes(Vector3(-hw-cw,ct-1.6,z_rear+0.6),Vector3(-hw-cw,ct-1.6,z_front-0.6),Vector3.UP,Vector3.LEFT,0.7)
	# The left cheek by the summit: the chimney inside it.
	var ct_n := top+r
	var x_out := -hw-cw
	var xs0 := -hw-wall_in-ch
	var xs1 := -hw-wall_in
	var zs0 := zc-ch*0.5
	var zs1 := zc+ch*0.5
	var dh := DOOR.x*0.5*float(n.ws)
	var dt := DOOR.y*float(n.ws)
	# In front of it and behind it, whole.
	_coursed(b,Vector3(x_out,0.0,zs1),Vector3(-hw,ct_n,zn),0.0,null,so)
	_coursed(b,Vector3(x_out,0.0,z_back),Vector3(-hw,ct_n,zs0),0.0,null,so)
	b.rect_area("cheek",Rect2(x_out,zs1,cw,zn-zs1),ct_n)
	b.rect_area("cheek",Rect2(x_out,z_back,cw,zs0-z_back),ct_n)
	# Its outer wall, the arch at the foot.
	_solid(b,Vector3(x_out,0.0,zs0),Vector3(xs0,ct_n,zc-dh),0.0,null,0.4)
	_solid(b,Vector3(x_out,0.0,zc+dh),Vector3(xs0,ct_n,zs1),0.0,null,0.4)
	_solid(b,Vector3(x_out,dt,zc-dh),Vector3(xs0,ct_n,zc+dh),NAN,null,0.3)
	# The tell: a pale lintel over the arch.
	_drawn(b,Vector3(x_out-0.12,dt,zc-dh-0.35),Vector3(x_out+0.2,dt+0.45,zc+dh+0.35),1.45,0.06)
	# Its inner wall, the door at the summit's level.
	# (The door at the shaft's back, over the platform.)
	var zd := zs0+dh
	_solid(b,Vector3(xs1,0.0,zd+dh),Vector3(-hw,ct_n,zs1),0.0,null,0.4)
	_solid(b,Vector3(xs1,0.0,zs0),Vector3(-hw,top,zd+dh),0.0,null,0.3)
	_solid(b,Vector3(xs1,top+dt,zs0),Vector3(-hw,ct_n,zd+dh),NAN,null,0.3)
	_drawn(b,Vector3(-hw-0.2,top+dt,zs0-0.35),Vector3(-hw+0.12,top+dt+0.45,zd+dh+0.35),1.45,0.06)
	# The roof, a lintel's thickness under the cheek head.
	_solid(b,Vector3(xs0,top+ch,zs0),Vector3(xs1,ct_n,zs1),NAN,null,0.3)
	# Inside, lampblack: the shaft's walls drawn dark.
	_drawn(b,Vector3(xs0,0.0,zs0),Vector3(xs0+0.03,top+ch,zs1),0.45,0.0)
	_drawn(b,Vector3(xs1-0.03,0.0,zs0),Vector3(xs1,top+ch,zs1),0.45,0.0)
	# Her floor (walker-only: the ground under it is the yard's), ledges up
	# alternate leaves, the platform the last one climbs to.
	_solid(b,Vector3(xs0,-0.4,zs0),Vector3(xs1,0.0,zs1),NAN,hers,0.0,0.0)
	var ledges: Array = []
	var levels := int(roundf(top/so))-1
	for k in range(1,levels+1):
		var y := k*so
		if k%2 == 1: _ledge(b,hers,xs0,xs1,zs1-float(s.ledge),zs1,y)
		else: _ledge(b,hers,xs0,xs1,zs0,zs0+float(s.ledge),y)
		ledges.append(Vector3((xs0+xs1)*0.5,y,(zs1-float(s.ledge)*0.5) if k%2 == 1 else (zs0+float(s.ledge)*0.5)))
	var plat_z1 := zs0+float(s.ledge)+0.1
	_solid(b,Vector3(xs0,top-0.35,zs0),Vector3(xs1,top,plat_z1),NAN,hers,0.2,0.04)
	var extra := {
		"sizes":{"riser":r,"tread":deep,"lane":hw*2.0,"treads":count,"top":top,"cheek":cw,"chimney":ch,"ledges":levels,"door":DOOR*float(n.ws),"wall_in":wall_in},
		"his":{"walks":"each tread (%.1f deep, %.1f wide) and the summit" % [deep,hw*2.0],"climbs":"each riser (%.1f: over his stair step %.2f, a press-up under %.2f)" % [r,float(n.stair),float(n.press)],
			"can't":"enter the chimney (%.1f across, doors %.1f wide), reach into it (its middle %.1f m in from the lane's edge)" % [ch,DOOR.x*float(n.ws),wall_in+ch*0.5]},
		"his_lane":[_aabb(Vector3(-hw,0.0,z_back),Vector3(hw,top+float(n.neck),0.0))],
		"hers":[_aabb(Vector3(xs0,0.0,zs0),Vector3(xs1,top+ch,zs1)),_aabb(Vector3(x_out,0.0,zc-dh),Vector3(xs0,dt,zc+dh)),_aabb(Vector3(xs1,top,zs0),Vector3(-hw,top+dt,zd+dh))],
		"safe":[_aabb(Vector3(xs0,0.0,zs0),Vector3(xs1,top-1.0,zs1))],
		"ports":{"foot":Vector3(0.0,0.0,3.0),"summit":Vector3(0.0,top,zc),"arch":Vector3(x_out-1.2,0.0,zc),"shaft":Vector3((xs0+xs1)*0.5,0.0,zc),
			"platform":Vector3((xs0+xs1)*0.5,top,zs0+0.5),"door":Vector3(-hw+0.6,top,zd),"treads":treads,"ledges":ledges},
	}
	return _finish(b,"city_riser",extra)

# --- The hauling lip (oc_lip) -----------------------------------------------------------------

## The hauling lip. y 0 the top he comes over onto, the face below it at z 0
## (front +Z), its foot `height` (12.4: the undercut's floor and six
## set-offs) under it. The cornice (a course of 0.75 set-off) steps out a
## quarter set-off over the face, two hand-troughs worn into its top edge a
## his shoulders apart; under it the undercut, a set-off clear and a metre
## deep, her hide; her shelves up the face's east end (walker-only), the
## top one on the cornice's front. The west corner (a cell square) is
## pre-cracked: his weight on it, or his mantle's wave starting on it,
## breaks it into four (scripts/city_breaks/floor_break.gd). Behind the lip
## his landing (`depth`, 8.8), `width` (13.2) across. Opts: height, width, depth.
static func lip(seed_value: int, weathered := 0.4, opts := {}) -> Node3D:
	var b := CityKit.Piece.new("CityLip",seed_value,weathered)
	var s := sizes()
	var n := numbers()
	var hers := _hers_body(b,"Shelves")
	var so: float = s.set_off
	var cell: float = s.cell
	var ct: float = s.cornice
	var ov: float = s.over
	var uc: float = s.undercut
	var ud: float = s.undercut_deep
	var sill := -(ct+uc)
	var h: float = opts.get("height",-sill+6.0*so)
	var w2: float = float(opts.get("width",5.0*cell))*0.5
	var depth: float = opts.get("depth",s.landing)
	var foot := -h
	var end := 0.5*so
	var xb := -w2+cell
	# Her shelves' column (the face's south end) and the undercut over it;
	# his zone between it and the cracked corner, the face plain to the
	# cornice (his planner climbs where no floor lies between).
	var xc := w2-end-float(s.shelf.x)-float(s.shelf_gap)*0.5
	var off := (float(s.shelf.x)+float(s.shelf_gap))*0.5
	var sx0 := xc-off-float(s.shelf.x)*0.5+0.1
	# The mass behind the face (the cracked corner's square cut from its top).
	_coursed(b,Vector3(xb,foot,-depth),Vector3(w2,0.0,-ud),foot,null,2.0*so)
	_coursed(b,Vector3(-w2,foot,-depth),Vector3(xb,0.0,-cell),foot,null,2.0*so)
	_solid(b,Vector3(-w2,foot,-cell),Vector3(xb,-ct-CityKit.GAP,-ud),foot,null,0.4,0.06)
	# The face's front course: the ends whole, the west under the corner.
	_coursed(b,Vector3(w2-end,foot,-ud),Vector3(w2,0.0,0.0),foot,null,so)
	_coursed(b,Vector3(-w2,foot,-ud),Vector3(xb,-ct-CityKit.GAP,0.0),foot,null,so)
	# His zone: whole to the top, drawn to the cornice.
	b.hull(Geometry3D.compute_convex_mesh_points(CityKit._typed(_bx(Vector3(xb,foot,-ud),Vector3(sx0,0.0,0.0))+[CityKit.over(foot)])))
	_coursed(b,Vector3(xb,foot,-ud),Vector3(sx0,-ct,0.0),foot,null,so,0.7,false)
	# Under the undercut, its top the undercut's floor; along its front a
	# sill (her height and a little: from the ground, even his lifted head
	# looks over it at the cornice, not at her), open at the east end where
	# her shelf steps in.
	var sill_h: float = s.sill
	var sill_t := 0.35*float(n.ws)
	var sx1 := w2-end-float(s.shelf.x)-0.1
	_coursed(b,Vector3(sx0,foot,-ud),Vector3(w2-end,sill,-sill_t),foot,null,so)
	_coursed(b,Vector3(sx0,foot,-sill_t),Vector3(sx1,sill+sill_h,0.0),foot,null,so)
	_coursed(b,Vector3(sx1,foot,-sill_t),Vector3(w2-end,sill,0.0),foot,null,so)
	b.runes(Vector3(-w2+1.0,sill-2.2,0.0),Vector3(w2-1.0,sill-2.2,0.0),Vector3.UP,Vector3.BACK,0.8)
	b.runes(Vector3(-w2+1.0,foot+2.4,0.0),Vector3(w2-1.0,foot+2.4,0.0),Vector3.UP,Vector3.BACK,0.8)
	# The undercut's back, lampblack.
	_drawn(b,Vector3(sx0,sill,-ud-0.03),Vector3(w2-end,-ct,-ud),0.4,0.0)
	# The cornice (east of the cracked corner): collided as its roof over the
	# undercut and its overhang, drawn round the two hand-troughs worn into
	# its top edge (his hands' place, his shoulders apart).
	var xg := (xb+sx0)*0.5
	var troughs := [xg-float(n.width)*0.37,xg+float(n.width)*0.37]
	var tw := 0.25*so
	var tl := 0.6*float(n.ws)
	var td := 0.25*so
	b.hull(Geometry3D.compute_convex_mesh_points(CityKit._typed(_bx(Vector3(sx0,-ct,-ud),Vector3(w2-end,0.0,0.0)))))
	b.hull(Geometry3D.compute_convex_mesh_points(CityKit._typed(_bx(Vector3(xb,-ct,0.0),Vector3(w2,0.0,ov)))))
	_drawn(b,Vector3(xb,-ct,-ud),Vector3(w2,-td,ov),1.0,0.06)
	var cuts: Array = [xb]
	for t: float in troughs: cuts.append_array([t-tw,t+tw])
	cuts.append(w2)
	for i in range(0,cuts.size(),2): _drawn(b,Vector3(cuts[i],-td,-ud),Vector3(cuts[i+1],0.0,ov),1.0,0.05)
	for t: float in troughs:
		_drawn(b,Vector3(t-tw,-td,-ud),Vector3(t+tw,0.0,ov-tl),1.0,0.03)
		# Fine pale dust in the trough.
		_drawn(b,Vector3(t-tw+0.04,-td,ov-tl),Vector3(t+tw-0.04,-td+0.04,ov-0.02),1.5,0.0)
	b.runes(Vector3(xb+0.3,-ct+0.2,ov),Vector3(w2-0.3,-ct+0.2,ov),Vector3.UP,Vector3.BACK,0.55)
	# The cracked corner: four slabs over the undercut's west end.
	var cells: Array = []
	var cx := [-w2,(-w2+xb)*0.5,xb]
	var cz := [-cell,(-cell+ov)*0.5,ov]
	for i in 2:
		for j in 2: cells.append([Vector3(float(cx[i]),-ct,float(cz[j])),Vector3(float(cx[i+1]),0.0,float(cz[j+1]))])
	_unit(b,FloorBreak.new(),"Corner",Vector3.ZERO,cells,"lip_corner",1.2)
	# Her shelves up the face's east end, the top one on the cornice's front.
	var shelves: Array = []
	var count := int(roundf((h+sill)/so))
	for k in range(1,count+2):
		var y := foot+k*so
		var x := xc+(off if k%2 == 0 else -off)
		var z0 := 0.0 if k <= count else ov
		# The last two stand out past the cornice (her head clear of it).
		var deep_k: float = float(s.shelf.y)+(ov+0.6 if k >= count else 0.0)
		_ledge(b,hers,x-float(s.shelf.x)*0.5,x+float(s.shelf.x)*0.5,z0,z0+deep_k,y)
		shelves.append(Vector3(x,y,z0+float(s.shelf.y)*0.5))
	var brazier := Vector3(w2-1.6,0.0,-2.4)
	b.cresset(brazier)
	# The brazier niche: a squat carved bowl on the top; lit (`brazier`), it
	# glows and draws every calm Olmec in reach to come and look, up the
	# face and over the cornice (scripts/enemies/beacon.gd).
	_drawn(b,brazier+Vector3(-0.55,0.0,-0.55),brazier+Vector3(0.55,0.35,0.55),0.9,0.12)
	_drawn(b,brazier+Vector3(-0.75,0.35,-0.75),brazier+Vector3(0.75,0.8,0.75),1.0,0.25)
	if opts.get("brazier",false):
		var flame := MeshInstance3D.new()
		flame.name = "Flame"
		var cone := CylinderMesh.new()
		cone.top_radius = 0.05
		cone.bottom_radius = 0.42
		cone.height = 0.9
		flame.mesh = cone
		var fm := StandardMaterial3D.new()
		fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fm.albedo_color = Color(1.0,0.62,0.26)
		fm.emission_enabled = true
		fm.emission = Color(1.0,0.55,0.2)
		fm.emission_energy_multiplier = 2.0
		flame.material_override = fm
		flame.position = brazier+Vector3.UP*1.2
		b.root.add_child(flame)
		var lamp := OmniLight3D.new()
		lamp.name = "BrazierLight"
		lamp.light_color = Color(1.0,0.66,0.38)
		lamp.light_energy = 3.0
		lamp.omni_range = 14.0
		lamp.position = brazier+Vector3.UP*1.6
		b.root.add_child(lamp)
		var beacon := Beacon.new()
		beacon.name = "Brazier"
		beacon.radius = 6.0
		beacon.strength = 0.8
		beacon.draw = 90.0
		beacon.gather = 2.0
		beacon.dwell = 8.0
		beacon.position = brazier+Vector3.UP*1.2
		beacon.stand = Vector3(xg-brazier.x,-1.2,-3.5-brazier.z)
		b.root.add_child(beacon)
	b.rect_area("top",Rect2(-w2,-depth,w2*2.0,depth+ov),0.0)
	var extra := {
		"sizes":{"height":h,"width":w2*2.0,"depth":depth,"cornice":ct,"over":ov,"undercut":uc,"undercut_deep":ud,"shelves":count+1,"troughs":troughs,"corner":cell},
		"his":{"climbs":"the face (%.1f, under his %.1f) anywhere off her shelves, hangs his hands in the troughs and pulls up over the cornice" % [h,float(n.climb_max)],
			"breaks":"the west corner (%.1f square), standing on it 1.2 s or his mantle's wave on it" % cell,"can't":"stand in the undercut (%.1f clear), see down into it over the cornice, reach it (his swat band %.1f, the wave's %.1f)" % [uc,float(n.swat_dy),float(n.shock_band)]},
		"his_lane":[_aabb(Vector3(xb,foot,0.0),Vector3(sx0,0.0,float(n.length)+1.0)),_aabb(Vector3(-w2,0.0,-depth),Vector3(w2,float(n.neck),ov))],
		"hers":[_aabb(Vector3(xc-off-float(s.shelf.x)*0.5,foot,0.0),Vector3(xc+off+float(s.shelf.x)*0.5,0.0,float(s.shelf.y))),_aabb(Vector3(sx0,sill,-ud),Vector3(w2-end,-ct,0.0))],
		"safe":[_aabb(Vector3(sx0,sill,-ud),Vector3(sx1,-ct,-sill_t))],
		"ports":{"foot":Vector3(xg,foot,3.0),"top":Vector3(xg,0.0,-depth*0.5),"troughs":troughs,"shelf_foot":Vector3(xc-off,foot,2.0),
			"undercut":Vector3((sx0+sx1)*0.5,sill,-ud*0.5-sill_t*0.5),"shelves":shelves,"brazier":brazier},
	}
	return _finish(b,"city_lip",extra)

# --- The leaper's pit (oc_pit) -----------------------------------------------------------------

## The leaper's pit. y 0 the plinths' tops; the gap (`gap`, a stride inside
## his jump and past hers) across z round z 0, a plinth `landing` deep each
## side, `lane` wide, fins either side (thin, `fin_up` over the tops: no
## top for either of you) down into the dark. The worn stride-marks on each
## plinth's takeoff. Her cornice runs along each fin's inner face a
## set-off under the tops, a step at each end; the east one is cracked in
## two segments (CorniceBreak): his landing's wave breaks the one nearest it.
## His: jumps the gap both ways. Hers: walks a cornice across. Opts: gap.
static func pit(seed_value: int, weathered := 0.4, opts := {}) -> Node3D:
	var b := CityKit.Piece.new("CityPit",seed_value,weathered)
	var s := sizes()
	var n := numbers()
	var hers := _hers_body(b,"Cornice")
	var g: float = opts.get("gap",s.pit_gap)
	var hw: float = float(s.lane)*0.5
	var land: float = s.landing
	var fin: float = s.fin
	var up: float = s.fin_up
	var deep: float = s.pit_deep
	var so: float = s.set_off
	var ld: float = s.ledge
	var g2 := g*0.5
	for side: float in [-1.0,1.0]:
		var z0 := side*g2
		var z1 := side*(g2+land)
		_coursed(b,Vector3(-hw,-deep,minf(z0,z1)),Vector3(hw,0.0,maxf(z0,z1)),NAN,null,3.0*so,0.4)
		b.rect_area("plinth",Rect2(-hw,minf(z0,z1),hw*2.0,land),0.0)
		# His pit face: glyph bands down into the dark.
		var nrm := Vector3(0.0,0.0,-side)
		for y: float in [-2.4,-9.0]:
			var a := Vector3(-hw+0.6,y,z0)
			var c := Vector3(hw-0.6,y,z0)
			if side > 0.0: b.runes(a,c,Vector3.UP,nrm,0.8)
			else: b.runes(c,a,Vector3.UP,nrm,0.8)
		# The stride-marks: two worn hollows where a giant stood to leap.
		for sx: float in [-1.0,1.0]:
			var mz := side*(g2+1.6+1.1)
			_drawn(b,Vector3(sx*float(n.width)*0.5-0.55,0.0,mz-1.1),Vector3(sx*float(n.width)*0.5+0.55,0.025,mz+1.1),0.55,0.02)
	# The fins: thin and tall, the length of the crossing.
	for side: float in [-1.0,1.0]:
		var x0 := hw if side > 0.0 else -hw-fin
		_coursed(b,Vector3(x0,-deep,-g2-land),Vector3(x0+fin,up,g2+land),NAN,null,2.0*so,0.4)
		var xf := hw if side > 0.0 else -hw
		var nrm := Vector3(-side,0.0,0.0)
		var a := Vector3(xf,1.2,-g2-land+0.6)
		var c := Vector3(xf,1.2,g2+land-0.6)
		if side > 0.0: b.runes(c,a,Vector3.UP,nrm,0.8)
		else: b.runes(a,c,Vector3.UP,nrm,0.8)
	# Her cornices: a set-off under the tops, a step down at each end.
	var cy := -so
	var step_y := -so*0.5
	var span := g-2.0*ld
	for side: float in [-1.0,1.0]:
		var x0 := hw-ld if side > 0.0 else -hw
		var x1 := x0+ld
		for e: float in [-1.0,1.0]:
			var za := e*g2
			var zb := e*(g2-ld)
			_solid(b,Vector3(x0,cy-0.5,minf(za,zb)),Vector3(x1,step_y,maxf(za,zb)),NAN,hers,0.3,0.04)
		# Corbels under it (drawn: its seat on the fin).
		for k in 3:
			var z := lerpf(-g2+ld,g2-ld,(k+0.5)/3.0)
			_drawn(b,Vector3(x0+(0.25 if side > 0.0 else 0.0),cy-1.3,z-0.3),Vector3(x1-(0.0 if side > 0.0 else 0.25),cy-0.5,z+0.3),0.8,0.05)
		if side < 0.0:
			_solid(b,Vector3(x0,cy-0.5,-g2+ld),Vector3(x1,cy,g2-ld),NAN,hers,0.4,0.04)
		else:
			# Cracked: two segments, each its own unit.
			for k in 2:
				var za := -g2+ld+span*k*0.5
				var zb := za+span*0.5
				var unit := CorniceBreak.new()
				_unit(b,unit,"Cornice%d" % k,Vector3((x0+x1)*0.5,cy,(za+zb)*0.5),[[Vector3(-ld*0.5,-0.5,-(zb-za)*0.5),Vector3(ld*0.5,0.0,(zb-za)*0.5)]],"pit_cornice",INF,true)
	var extra := {
		"sizes":{"gap":g,"lane":hw*2.0,"landing":land,"fin":fin,"fin_up":up,"cornice":cy,"cornice_deep":ld,"his_jump":float(n.jump_gap),"depth":deep},
		"his":{"jumps":"the gap (%.2f, inside his %.2f), plinth to plinth, either way" % [g,float(n.jump_gap)],"breaks":"the east cornice: his landing's wave takes the segment nearest it",
			"can't":"walk the cornice (walker-only, %.1f deep), pounce onto it (no floor under her for his rays), climb a fin (%.1f thick)" % [ld,fin]},
		"his_lane":[_aabb(Vector3(-hw,0.0,-g2-land),Vector3(hw,float(n.neck),g2+land))],
		"hers":[_aabb(Vector3(-hw,cy-0.5,-g2),Vector3(-hw+ld,0.0,g2)),_aabb(Vector3(hw-ld,cy-0.5,-g2),Vector3(hw,0.0,g2))],
		"safe":[],
		"ports":{"north":Vector3(0.0,0.0,-g2-land*0.5),"south":Vector3(0.0,0.0,g2+land*0.5),"north_edge":Vector3(0.0,0.0,-g2-1.0),"south_edge":Vector3(0.0,0.0,g2+1.0),
			"west_cornice":[Vector3(-hw+ld*0.5,step_y,-g2+ld*0.5),Vector3(-hw+ld*0.5,cy,0.0),Vector3(-hw+ld*0.5,step_y,g2-ld*0.5)],
			"east_cornice":[Vector3(hw-ld*0.5,step_y,-g2+ld*0.5),Vector3(hw-ld*0.5,cy,0.0),Vector3(hw-ld*0.5,step_y,g2-ld*0.5)]},
	}
	return _finish(b,"city_pit",extra)

# --- The wrapped pillar (oc_wrap) -----------------------------------------------------------

## The wrapped pillar. y 0 the ground at its foot; a square core (`core`,
## 13.2) with his ramp wound round it anticlockwise from the south-west
## corner: a side each `side_rise` (3.2) up, flat landings his size at the
## corners, `turns` (2) turns to the crown (25.6). The first turn is built
## solid to the ground (the pillar's foot), the rest hang as slabs on
## corbels. Her climb: a recess carved in the core's south face (a chimney,
## ledges on alternate leaves a set-off apart) from the first turn's ramp to
## the crown; she steps out onto the second turn's ramp on the way; halfway
## up the first stretch a door off it leads into a safe cell inside the
## core. Opts: turns.
static func wrapped(seed_value: int, weathered := 0.4, opts := {}) -> Node3D:
	var b := CityKit.Piece.new("CityWrap",seed_value,weathered)
	var s := sizes()
	var n := numbers()
	var hers := _hers_body(b,"Recess")
	var turns: int = opts.get("turns",2)
	# `deep` > 0: the first turn and the core go down into the abyss that far
	# (the pillar over the void, its start corner on the ground); 0: all of
	# it stands on the ground at y 0.
	var deep: float = opts.get("deep",0.0)
	var base := -deep
	var foot := 0.0 if deep <= 0.0 else NAN
	var c2: float = float(s.core)*0.5
	# The ramp: his lane and his shoulders' width over it again (his bulk,
	# 6.7 m, is wider than his planner's 4.5 m fit: he walks a lane's middle
	# a little off the core's face).
	var lane: float = float(s.lane)+float(n.bulk)*0.5+0.2
	var rs: float = s.side_rise
	var th: float = s.slab
	var so: float = s.set_off
	var ch: float = s.chimney
	var ld: float = s.ledge
	var sides := 4*turns
	var top := sides*rs
	var path: Array = []
	# Over the void, the start corner is its own landing (the ground meets
	# its south edge).
	if deep > 0.0:
		_solid(b,Vector3(-c2-lane,base,c2),Vector3(-c2,0.0,c2+lane),NAN,null,0.6,0.1)
		b.rect_area("landing",Rect2(-c2-lane,c2,lane,lane),0.0)
	for k in range(sides):
		var sd := k%4
		var y0 := k*rs
		var y1 := y0+rs
		var solid := k < 4
		# The strip, its way up (u), its low edge's middle.
		var rect: Rect2
		var u: Vector3
		var low: Vector3
		match sd:
			0:
				rect = Rect2(-c2,c2,c2*2.0,lane)
				u = Vector3.RIGHT
				low = Vector3(-c2,y0,c2+lane*0.5)
			1:
				rect = Rect2(c2,-c2,lane,c2*2.0)
				u = Vector3.FORWARD
				low = Vector3(c2+lane*0.5,y0,c2)
			2:
				rect = Rect2(-c2,-c2-lane,c2*2.0,lane)
				u = Vector3.LEFT
				low = Vector3(c2,y0,-c2-lane*0.5)
			_:
				rect = Rect2(-c2-lane,-c2,lane,c2*2.0)
				u = Vector3.BACK
				low = Vector3(-c2-lane*0.5,y0,-c2)
		var m := rs/(c2*2.0)
		var nt := Vector3(-u.x*m,1.0,-u.z*m).normalized()
		var sides_p: Array = [Plane(Vector3.LEFT,-rect.position.x),Plane(Vector3.RIGHT,rect.end.x),Plane(Vector3.FORWARD,-rect.position.y),Plane(Vector3.BACK,rect.end.y)]
		var planes: Array = sides_p+[Plane(nt,nt.dot(low))]
		if solid: planes.append(Plane(Vector3.DOWN,deep))
		else: planes.append(Plane(-nt,-nt.dot(low-Vector3.UP*th/nt.y)))
		b.block(planes,true,null,0.5,null,[CityKit.over(0.0)] if solid and deep <= 0.0 else [])
		var mid := low+u*c2+Vector3.UP*rs*0.5
		path.append(mid)
		b.area("ramp",[rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)],y0,y1)
		# The outer fascia: a glyph band along the strip's outer edge.
		var out := Vector3(u.z,0.0,-u.x)
		if out.dot(Vector3(mid.x,0.0,mid.z)) < 0.0: out = -out
		var edge := mid+out*lane*0.5
		if not solid:
			var fa := edge-u*(c2-0.4)+Vector3.DOWN*(rs*0.5+0.75)
			var fb := edge+u*(c2-0.4)+Vector3.DOWN*(-rs*0.5+0.75)
			var band_up := out.cross(fb-fa).normalized()
			if band_up.y < 0.0: band_up = -band_up
			b.runes(fa,fb,band_up,out,0.55)
			# Corbels under the slab at the core's face: drawn only.
			var inner := mid-out*lane*0.5
			for j: float in [-0.6,0.0,0.6]:
				var at := inner+u*c2*j
				var yb := at.y+rs*0.5*j-th/nt.y-0.05
				var across := Vector3(absf(u.x),0.0,absf(u.z))*0.45
				var lo := Vector3(minf(at.x,at.x+out.x*1.6),yb-1.0,minf(at.z,at.z+out.z*1.6))-across
				var hi := Vector3(maxf(at.x,at.x+out.x*1.6),yb,maxf(at.z,at.z+out.z*1.6))+across
				_drawn(b,lo,hi,0.85,0.06)
		# The landing after it (none after the last).
		if k < sides-1:
			var cr: Rect2
			match sd:
				0: cr = Rect2(c2,c2,lane,lane)
				1: cr = Rect2(c2,-c2-lane,lane,lane)
				2: cr = Rect2(-c2-lane,-c2-lane,lane,lane)
				_: cr = Rect2(-c2-lane,c2,lane,lane)
			# The first turn's landings stand on the ground; the one closing
			# it (over the start corner) hangs, as the second turn's do.
			var held := solid and k < 3
			var lo_y := base if held else y1-th
			_solid(b,Vector3(cr.position.x,lo_y,cr.position.y),Vector3(cr.end.x,y1,cr.end.y),foot if held else NAN,null,0.6,0.1)
			b.rect_area("landing",cr,y1)
			path.append(Vector3(cr.get_center().x,y1,cr.get_center().y))
			if not held:
				for j: float in [-0.3,0.3]:
					_drawn(b,Vector3(cr.get_center().x+j*lane-0.4,lo_y-1.0,cr.get_center().y-0.4),Vector3(cr.get_center().x+j*lane+0.4,lo_y,cr.get_center().y+0.4),0.85,0.08)
	# The core, as columns (never a solid stood on another): the recess cut
	# in its south face, the passage and cell behind it.
	var rh := ch*0.5
	var rz := c2-so
	var pz := rz-2.0*float(n.ws)*1.0
	var cz := pz-2.4*float(n.ws)
	var floor_r := rs*0.5
	var cell_y := floor_r+4.0*so
	var cell_h := 1.5*so
	var pass_h := DOOR.y*float(n.ws)*0.95
	# Its four edges chamfered (a leg of `bevel`): his shoulders turning a
	# landing's corner glance off a slant, never catch on an edge.
	var bevel := 0.75*float(n.hh)
	var cuts: Array = []
	for cs: Vector2 in [Vector2(1,1),Vector2(-1,1),Vector2(1,-1),Vector2(-1,-1)]:
		var dn := Vector3(cs.x,0.0,cs.y).normalized()
		cuts.append(Plane(dn,(2.0*c2-bevel)/sqrt(2.0)))
	_coursed(b,Vector3(-c2,base,-c2),Vector3(c2,top,cz),foot,null,2.0*so,0.7,true,cuts)
	_coursed(b,Vector3(-c2,base,cz),Vector3(-rh,top,c2),foot,null,2.0*so,0.7,true,cuts)
	_coursed(b,Vector3(rh,base,cz),Vector3(c2,top,c2),foot,null,2.0*so,0.7,true,cuts)
	# The cell (its floor and over it).
	_solid(b,Vector3(-rh,base,cz),Vector3(rh,cell_y,pz),foot,null,0.3)
	_solid(b,Vector3(-rh,cell_y+cell_h,cz),Vector3(rh,top,pz),NAN,null,0.3)
	# The passage to it: off the +x leaf, its west side solid.
	_solid(b,Vector3(-rh,base,pz),Vector3(0.0,top,rz),foot,null,0.3)
	_solid(b,Vector3(0.0,base,pz),Vector3(rh,cell_y,rz),foot,null,0.3)
	_solid(b,Vector3(0.0,cell_y+pass_h,pz),Vector3(rh,top,rz),NAN,null,0.3)
	# The recess's face, closed but for a door at each turn's ramp: his
	# shoulders (his bulk, its foot a stair step over his feet) pass along a
	# flat face, never catch in its mouth; her shaft out of his sight.
	var screen := 0.25*so
	var door_h := 2.0*float(n.ws)
	var exit_y := 4.0*rs+rs*0.5
	var door2 := exit_y-0.4
	_coursed(b,Vector3(-rh,floor_r+door_h,c2-screen),Vector3(rh,door2,c2),NAN,null,so,0.4)
	_coursed(b,Vector3(-rh,door2+door_h+0.4,c2-screen),Vector3(rh,top,c2),NAN,null,so,0.4)
	_drawn(b,Vector3(-rh-0.3,floor_r+door_h,c2),Vector3(rh+0.3,floor_r+door_h+0.4,c2+0.12),1.4,0.04)
	_drawn(b,Vector3(-rh-0.3,door2+door_h+0.4,c2),Vector3(rh+0.3,door2+door_h+0.8,c2+0.12),1.4,0.04)
	# The recess's floor: the first turn's ramp height at its mouth.
	_solid(b,Vector3(-rh,base,rz),Vector3(rh,floor_r,c2),foot,null,0.2)
	# Inside, lampblack.
	_drawn(b,Vector3(-rh,floor_r,rz-0.03),Vector3(rh,top,rz),0.5,0.0)
	_drawn(b,Vector3(-rh,cell_y,cz),Vector3(rh,cell_y+cell_h,cz+0.03),0.4,0.0)
	# The crown corbelled out over the south face (three courses stepping
	# out), over her recess's top; clear of his bulk on the strip below.
	var cor := 1.65*float(n.ws)
	for f in 1:
		var d: Vector3 = [Vector3.BACK,Vector3.RIGHT,Vector3.FORWARD][f]
		var t := Vector3(d.z,0.0,-d.x)
		var wedge_p: Array = [Plane(d,c2+cor),Plane(-d,-c2+0.01),Plane(t,c2+cor),Plane(-t,c2+cor),Plane(Vector3.UP,top)]
		var lean := (d+Vector3.DOWN*(cor/1.6)).normalized()
		wedge_p.append(Plane(lean,lean.dot(d*c2+Vector3.UP*(top-2.4))))
		b.hull(Geometry3D.compute_convex_mesh_points(CityKit._typed(wedge_p)))
		for c in 3:
			var o := cor*(c+1)/3.0
			var y0 := top-2.4+0.8*c
			var lo := d*c2+t*(c2+o)+Vector3.UP*y0
			var hi := d*(c2+o)-t*(c2+o)+Vector3.UP*(y0+0.8)
			_drawn(b,Vector3(minf(lo.x,hi.x),y0,minf(lo.z,hi.z)),Vector3(maxf(lo.x,hi.x),y0+0.8,maxf(lo.z,hi.z)),1.0-0.05*c,0.08)
		b.runes(d*(c2+cor)+t*(c2+cor-0.4)+Vector3.UP*(top-0.65),d*(c2+cor)-t*(c2+cor-0.4)+Vector3.UP*(top-0.65),Vector3.UP,d,0.5)
	# Glyph bands round the core between the ramp's passes.
	for f in 4:
		var d: Vector3 = [Vector3.BACK,Vector3.RIGHT,Vector3.FORWARD,Vector3.LEFT][f]
		var t := Vector3(d.z,0.0,-d.x)
		for j in range(turns):
			var y := j*4.0*rs+rs*(f+0.5)+so*1.6
			if f == 0:
				b.runes(d*c2+t*(c2-0.5)+Vector3.UP*y,d*c2+t*(rh+0.4)+Vector3.UP*y,Vector3.UP,d,0.7)
				b.runes(d*c2-t*(rh+0.4)+Vector3.UP*y,d*c2-t*(c2-0.5)+Vector3.UP*y,Vector3.UP,d,0.7)
			else: b.runes(d*c2+t*(c2-0.5)+Vector3.UP*y,d*c2-t*(c2-0.5)+Vector3.UP*y,Vector3.UP,d,0.7)
	# Her ledges up the recess: alternate leaves (west odd, east even), from
	# the floor to the crown; the fourth by the cell's passage.
	var ledges: Array = []
	var levels := int(roundf((top-floor_r)/so))-1
	for k in range(1,levels+1):
		var y := floor_r+k*so
		if k%2 == 1: _ledge(b,hers,-rh,-rh+ld,rz,c2-screen,y)
		else: _ledge(b,hers,rh-ld,rh,rz,c2-screen,y)
		ledges.append(Vector3((-rh+ld*0.5) if k%2 == 1 else (rh-ld*0.5),y,(rz+c2-screen)*0.5))
	b.rect_area("crown",Rect2(-c2,-c2,c2*2.0,c2*2.0),top)
	for corner: Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
		b.cresset(Vector3(corner.x*(c2-1.6),top,corner.y*(c2-1.6)))
	var exit_k := int(roundf((4.0*rs+rs*0.5-floor_r)/so))
	var extra := {
		"sizes":{"core":c2*2.0,"lane":lane,"side_rise":rs,"slope_deg":rad_to_deg(atan2(rs,c2*2.0)),"turns":turns,"top":top,"recess":Vector2(ch,so),"ledges":levels,"cell":Vector3(ch,cell_h,2.4*float(n.ws)),"cell_y":cell_y,"exit_ledge":exit_k},
		"his":{"walks":"the ramp round (%d sides, %.1f each up, %.0f m of ramp), every landing, the crown" % [sides,rs,sides*(c2*2.0+lane)],"climbs":"the core's face from the second turn to the crown (%.1f, under his %.1f)" % [top-4.0*rs,float(n.climb_max)],
			"can't":"enter the recess (%.1f across), the passage or the cell; reach the cell (%.1f over the first turn, %.1f under the second: his swat band %.1f)" % [ch,cell_y-floor_r,4.0*rs+rs*0.5-cell_y,float(n.swat_dy)]},
		"his_lane":[_aabb(Vector3(-c2-lane,0.0,-c2-lane),Vector3(c2+lane,top+float(n.neck),c2+lane))],
		"hers":[_aabb(Vector3(-rh,floor_r,rz),Vector3(rh,top,c2)),_aabb(Vector3(-rh,cell_y,cz),Vector3(rh,cell_y+cell_h,rz))],
		"safe":[_aabb(Vector3(-rh,cell_y,cz),Vector3(rh,cell_y+cell_h,pz))],
		"ports":{"start":Vector3(-c2-lane*0.5,0.0,c2+lane*0.5),"foot":Vector3(-c2-lane*0.5,0.0,c2+lane+3.0),"crown":Vector3(0.0,top,0.0),"recess":Vector3(0.0,floor_r,c2+0.8),
			"cell":Vector3(0.0,cell_y,(cz+pz)*0.5),"passage":Vector3(rh*0.5,cell_y,(pz+rz)*0.5),"ledges":ledges,"path":path},
	}
	return _finish(b,"city_wrap",extra)

# --- The hanging terrace (ol_terrace) ---------------------------------------------------------

## The hanging terrace. Two decks hung on a host wall (its face at z 0, front
## +Z): the lower deck at y 0 (`lower`, 15.4 deep), the upper `deck_drop`
## (4.8) over it (`landing` deep), his stair (`lane` wide, the city's 0.4
## risers) from the lower deck's east end up to it. Under the upper deck,
## the undercroft (`undercroft`, 3.2 clear: under his neck), closed west by
## a wall and east by the stair's fill: her hide. Her way up: two shelves on
## the host wall (walker-only) to a hatch slot through the upper deck by
## the wall. The upper deck's outer tier (3 m) is a breakable unit: his
## weight 2 s on it, or his landing, snaps it onto the lower deck. Corbels
## hang under both decks. Opts: lower (depth), host_down.
static func terrace(seed_value: int, weathered := 0.4, opts := {}) -> Node3D:
	var b := CityKit.Piece.new("CityTerrace",seed_value,weathered)
	var s := sizes()
	var n := numbers()
	var hers := _hers_body(b,"Hatch")
	var so: float = s.set_off
	var cell: float = s.cell
	var lane: float = s.lane
	var ud: float = s.landing
	var uc: float = s.undercroft
	var uy: float = s.deck_drop
	var th := uy-uc
	var ld: float = opts.get("lower",3.5*cell)
	var hw := 1.5*cell
	var wall := so
	var xw := -hw-wall
	var rises := int(roundf(uy/CityKit.RISER))
	var run := rises*CityKit.TREAD
	var xe := hw+run
	var host_t := cell
	var host_down: float = opts.get("host_down",30.0)
	var host_up := uy+2.0*CityKit.COURSE
	# The host wall.
	# The lower deck runs a landing past the stair's foot (his way onto it).
	var xl := xe+float(s.landing)
	b.hull(Geometry3D.compute_convex_mesh_points(CityKit._typed(_bx(Vector3(xw-so,-host_down,-host_t),Vector3(xl,host_up,0.0)))))
	_coursed(b,Vector3(xw-so,-3.0*so,-host_t),Vector3(xl,host_up,0.0),NAN,null,2.0*so,0.6,false)
	_drawn(b,Vector3(xw-so+0.2,-host_down,-host_t+0.2),Vector3(xl-0.2,-3.0*so,-0.1),0.9,0.3)
	for y: float in [uy+3.0,uy+6.6]: b.runes(Vector3(xw,y,0.0),Vector3(xl-so,y,0.0),Vector3.UP,Vector3.BACK,0.8)
	# The lower deck, hung (its corbels drawn under it).
	_solid(b,Vector3(xw-so,-th,0.0),Vector3(xl,0.0,ld),NAN,null,0.6,0.1)
	b.rect_area("deck",Rect2(xw-so,0.0,xl-xw+so,ld),0.0)
	for c in 3:
		var reach := ld*(0.7-0.22*c)
		_drawn(b,Vector3(xw,-th-0.9*(c+1),0.0),Vector3(xl-so,-th-0.9*c,reach),0.85,0.1)
	for k in range(int((xl-xw)/cell)+1):
		var x := xw+0.5*cell+k*cell
		if x > xl-so: break
		_drawn(b,Vector3(x-0.35,-th-3.0,0.0),Vector3(x+0.35,-th,ld*0.92),0.8,0.08)
	b.runes(Vector3(xw-so,-th*0.75,ld),Vector3(xl,-th*0.75,ld),Vector3.UP,Vector3.BACK,0.55)
	# The undercroft's west wall (stood on the lower deck), the upper deck's
	# west end over it.
	_solid(b,Vector3(xw,0.0,0.0),Vector3(-hw,uy,ud),0.0,null,0.5,0.08)
	# The upper deck: whole but for the hatch slot by the wall and the outer
	# tier (its own unit).
	var hatch := Rect2(-hw+cell*0.25,0.0,1.5*so*1.4,DOOR.x*float(n.ws))
	var tier := 3.0*float(n.ws)
	var keep := ud-tier
	_solid(b,Vector3(-hw,uc,0.0),Vector3(hatch.position.x,uy,keep),NAN,null,0.6,0.06)
	_solid(b,Vector3(hatch.end.x,uc,0.0),Vector3(hw,uy,keep),NAN,null,0.6,0.06)
	_solid(b,Vector3(hatch.position.x,uc,hatch.end.y),Vector3(hatch.end.x,uy,keep),NAN,null,0.6,0.06)
	var cells: Array = []
	for k in 4:
		var x0 := -hw+hw*2.0*k/4.0
		cells.append([Vector3(x0,-th,-tier*0.5),Vector3(x0+hw*0.5,0.0,tier*0.5)])
	var unit := FloorBreak.new()
	_unit(b,unit,"OuterTier",Vector3(0.0,uy,keep+tier*0.5),cells,"terrace_tier",2.0)
	b.rect_area("deck",Rect2(-hw,0.0,hw*2.0,keep),uy)
	b.rect_area("deck",Rect2(xw,0.0,wall,ud),uy)
	# The tier's teeth: corbel ends under the upper deck's front (drawn).
	for k in 7:
		var x := lerpf(-hw+0.6,hw-0.6,k/6.0)
		_drawn(b,Vector3(x-0.3,uc-0.7,ud-0.9),Vector3(x+0.3,uc,ud+0.25),0.75,0.08)
	b.runes(Vector3(-hw,uc+0.3,ud+0.25),Vector3(hw,uc+0.3,ud+0.25),Vector3.UP,Vector3.BACK,0.6)
	# The undercroft: lampblack.
	_drawn(b,Vector3(-hw,0.0,-0.03),Vector3(hw,uc,0.0),0.4,0.0)
	_drawn(b,Vector3(-hw,uc-0.03,0.0),Vector3(hw,uc,ud),0.45,0.0)
	# The stair: down from the upper deck's east end to the lower deck.
	for j in range(rises):
		var x0 := hw+j*CityKit.TREAD
		var y := uy-j*CityKit.RISER
		_solid(b,Vector3(x0,0.0,0.0),Vector3(x0+CityKit.TREAD,y,lane),0.0,null,0.35,0.04)
	b.area("stair",[Vector2(hw,0.0),Vector2(xe,0.0),Vector2(xe,lane),Vector2(hw,lane)],uy,0.0)
	# The altar bowl on the west wall's top, a fire mount by it.
	_drawn(b,Vector3(xw+0.25,uy,ud-2.6),Vector3(-hw-0.25,uy+0.7,ud-1.2),1.0,0.15)
	b.cresset(Vector3((xw-hw)*0.5,uy+0.7,ud-1.9))
	# Her shelves to the hatch: one east of it, one in it.
	var sw: float = float(s.shelf.x)
	var bx := hatch.position.x+sw*0.5+0.1
	var ax := bx+sw+float(s.shelf_gap)
	_ledge(b,hers,ax-sw*0.5,ax+sw*0.5,0.0,float(s.shelf.y),so)
	_ledge(b,hers,bx-sw*0.5,bx+sw*0.5,0.0,float(s.shelf.y),2.0*so)
	var extra := {
		"sizes":{"upper":Vector2(hw*2.0,ud),"lower":Vector2(xl-xw+so,ld),"deck_drop":uy,"undercroft":uc,"stair":Vector3(lane,CityKit.RISER,CityKit.TREAD),"hatch":hatch.size,"tier":tier},
		"his":{"walks":"the lower deck, the stair (%.1f wide, %.1f risers), the upper deck (%.1f x %.1f)" % [lane,CityKit.RISER,hw*2.0,ud],"breaks":"the upper deck's outer tier (%.1f), his weight 2 s or his landing" % tier,
			"can't":"stand in the undercroft (%.1f clear, his neck %.1f), reach its back (%.1f deep, his reach %.1f), see under the deck, use the hatch (%.1f)" % [uc,float(n.neck),ud,float(n.reach),hatch.size.y]},
		"his_lane":[_aabb(Vector3(hw,0.0,0.0),Vector3(xe,uy+float(n.neck),lane)),_aabb(Vector3(-hw,uy,0.0),Vector3(hw,uy+float(n.neck),ud)),_aabb(Vector3(xw,0.0,ud),Vector3(xl,float(n.neck),ld)),_aabb(Vector3(xe,0.0,0.0),Vector3(xl,float(n.neck),ud))],
		"hers":[_aabb(Vector3(-hw,0.0,0.0),Vector3(hw,uc,ud)),_aabb(Vector3(hatch.position.x,uc,0.0),Vector3(hatch.end.x,uy,hatch.end.y))],
		"safe":[_aabb(Vector3(-hw,0.0,0.0),Vector3(hw,uc,ud-float(n.reach)-1.2))],
		"ports":{"lower":Vector3(xl-3.0,0.0,ld-3.0),"upper":Vector3(0.0,uy,keep*0.5+0.5),"stair_foot":Vector3(xe+1.0,0.0,lane*0.5),"undercroft":Vector3(-hw*0.5,0.0,1.5),
			"shelf_a":Vector3(ax,so,float(s.shelf.y)*0.5),"shelf_b":Vector3(bx,2.0*so,float(s.shelf.y)*0.5),"hatch":Vector3(hatch.get_center().x,uy,hatch.end.y+0.6)},
	}
	return _finish(b,"city_terrace",extra)

# --- The wedged chunk (ol_wedge) --------------------------------------------------------------

## The wedged chunk. y 0 the ground; a fallen slab (`wedge_run` 30.8 long,
## `wedge_thick` thick, its top 17 degrees up toward -Z) jammed against a
## crown block (z under 0, `wedge_rise` 9.6 tall), its top flush with the
## crown at its high end: his ramp. West of it a flanking wall the crown's
## height; between them her chimney (`chimney` across), ledges on alternate
## leaves up its back corner to the wall's top; the slab's underside rests
## on a rubble footing on the chimney's side, so the hollow under its high
## end opens only east: her hide (he can't stand in it, his swat can't
## reach its back, the slab cuts his sight). A broken crown block on the
## slab's high end: a perch for her second jump. Opts: run, rise.
static func wedge(seed_value: int, weathered := 0.4, opts := {}) -> Node3D:
	var b := CityKit.Piece.new("CityWedge",seed_value,weathered)
	var s := sizes()
	var n := numbers()
	var hers := _hers_body(b,"Chimney")
	var run: float = opts.get("run",s.wedge_run)
	var rise: float = opts.get("rise",s.wedge_rise)
	var thick: float = s.wedge_thick
	var so: float = s.set_off
	var ch: float = s.chimney
	var ld: float = s.ledge
	var cw := float(s.lane)*0.5+0.5*so
	var x_ch := -cw-ch
	var q_t := 1.5*float(s.cell)
	var x_q := x_ch-q_t
	var pd: float = s.landing
	var slope := atan2(rise,run)
	var nt := Vector3(0.0,cos(slope),sin(slope))
	var top_at := Vector3(0.0,rise,0.0)
	var under_d := thick/cos(slope)
	var z_rest := run*(1.0-under_d/rise)
	# The crown block and the flanking wall.
	_coursed(b,Vector3(x_q,0.0,-pd),Vector3(cw,rise,0.0),0.0,null,so)
	_coursed(b,Vector3(x_q,0.0,0.0),Vector3(x_ch,rise,run),0.0,null,so)
	b.rect_area("crown",Rect2(x_q,-pd,cw-x_q,pd),rise)
	b.rect_area("wall",Rect2(x_q,0.0,q_t,run),rise)
	for y: float in [2.0,5.6]:
		b.runes(Vector3(x_q,y,run),Vector3(x_q,y,0.4),Vector3.UP,Vector3.LEFT,0.8)
		b.runes(Vector3(cw,y,-pd),Vector3(x_q,y,-pd),Vector3.UP,Vector3.FORWARD,0.8)
	# The slab: its top a plane through the crown's edge, its underside
	# `thick` under; collided as one hull (GAP over the ground it rests on).
	var top_p := Plane(nt,nt.dot(top_at))
	var bottom_p := Plane(-nt,-nt.dot(top_at-nt*thick))
	var slab: Array = [Plane(Vector3.LEFT,cw),Plane(Vector3.RIGHT,cw),Plane(Vector3.FORWARD,0.0),Plane(Vector3.BACK,run),top_p,bottom_p,Plane(Vector3.DOWN,0.0)]
	b.hull(Geometry3D.compute_convex_mesh_points(CityKit._typed(slab+[CityKit.over(0.0)])))
	# Drawn as three courses (the floors it was cut from), chipped.
	for c in 3:
		var a := Plane(nt,nt.dot(top_at-nt*thick*c/3.0))
		var z := Plane(-nt,-nt.dot(top_at-nt*thick*(c+1)/3.0))
		b.block([Plane(Vector3.LEFT,cw),Plane(Vector3.RIGHT,cw),Plane(Vector3.FORWARD,0.0),Plane(Vector3.BACK,run),a,z,Plane(Vector3.DOWN,0.0)],false,null,1.0)
	var flank_y := func(z: float) -> float: return rise*(1.0-z/run)
	for side: float in [-1.0,1.0]:
		var x := side*cw
		var p0 := Vector3(x,float(flank_y.call(1.0))-thick*0.45,1.0)
		var p1 := Vector3(x,float(flank_y.call(run*0.62))-thick*0.45,run*0.62)
		var up := Vector3(0.0,cos(slope),sin(slope))
		if side < 0.0: b.runes(p1,p0,up,Vector3.LEFT,0.7)
		else: b.runes(p0,p1,up,Vector3.RIGHT,0.7)
	b.area("ramp",[Vector2(-cw,0.0),Vector2(cw,0.0),Vector2(cw,run),Vector2(-cw,run)],rise,0.0)
	# The rubble footing on the chimney's side, under the slab (its top GAP
	# under the underside).
	var foot_x := -cw+0.5*so
	var footing: Array = [Plane(Vector3.LEFT,cw),Plane(Vector3.RIGHT,foot_x),Plane(Vector3.FORWARD,0.0),Plane(Vector3.BACK,z_rest),Plane(nt,nt.dot(top_at-nt*(thick+CityKit.GAP))),Plane(Vector3.DOWN,0.0)]
	b.hull(Geometry3D.compute_convex_mesh_points(CityKit._typed(footing+[CityKit.over(0.0)])))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value*7+3
	var zz := 0.0
	while zz < z_rest-0.5:
		var lz := rng.randf_range(1.6,2.8)
		var hy := float(flank_y.call(zz+lz))-under_d
		if hy > 0.3:
			b.block(_bx(Vector3(-cw+rng.randf_range(-0.05,0.1),0.0,zz),Vector3(foot_x-rng.randf_range(0.0,0.15),hy,minf(zz+lz,z_rest))),false,null,1.4)
		zz += lz
	# Rubble shed along its east foot and round its low end (off his ramp):
	# what broke off as it fell; she climbs it, he steps over it.
	for k in 9:
		var along := rng.randf_range(z_rest+1.5,run-1.0)
		var r := rng.randf_range(0.5,1.3)
		var foot_y := 0.0
		var hx := cw+r*rng.randf_range(0.6,1.4)
		var bl := Vector3(hx-r,foot_y,along-r*rng.randf_range(0.6,1.2))
		var bh := Vector3(hx+r,foot_y+r*rng.randf_range(0.8,1.5),along+r*rng.randf_range(0.6,1.2))
		var tilt := Basis(Vector3(rng.randf_range(-1,1),1.0,rng.randf_range(-1,1)).normalized(),rng.randf_range(0.0,0.5))
		var pl := Stone.box(Transform3D(tilt,(bl+bh)*0.5),(bh-bl)*0.5,0.12)
		b.block(pl,true,null,1.6,null,[CityKit.over(0.0)])
	# The broken crown on the slab's high end: a perch.
	var perch := Vector3(cw-1.2*float(n.ws)-0.2,0.0,1.6)
	var ptop := float(flank_y.call(perch.z))+1.5*so
	var crown_b := _bx(Vector3(perch.x-1.2,float(flank_y.call(perch.z+1.2))-1.0,perch.z-1.2),Vector3(perch.x+1.2,ptop,perch.z+1.2),0.15)
	b.block(crown_b,true,null,1.6)
	# Her ledges up the chimney's back corner.
	var ledges: Array = []
	var levels := int(roundf(rise/so))-1
	for k in range(1,levels+1):
		var y := k*so
		if k%2 == 1: _ledge(b,hers,x_ch,x_ch+ld,0.0,so,y)
		else: _ledge(b,hers,-cw-ld,-cw,0.0,so,y)
		ledges.append(Vector3((x_ch+ld*0.5) if k%2 == 1 else (-cw-ld*0.5),y,so*0.5))
	# The hollow's back and the chimney's floor, lampblack.
	_drawn(b,Vector3(-cw+0.5*so,0.0,0.0),Vector3(cw,under_d*0.9,0.04),0.45,0.0)
	var extra := {
		"sizes":{"run":run,"rise":rise,"slope_deg":rad_to_deg(slope),"thick":thick,"ramp":cw*2.0,"chimney":ch,"wall":q_t,"ledges":levels,"hollow":Vector2(rise-under_d,z_rest),"perch":ptop-float(flank_y.call(perch.z))},
		"his":{"walks":"the slab's top (%.1f wide, %.0f degrees) to the crown block (%.1f x %.1f) and the flanking wall's top (%.1f)" % [cw*2.0,rad_to_deg(slope),cw-x_q,pd,q_t],
			"can't":"enter the chimney (%.1f), stand in the hollow (%.1f at its highest, his neck %.1f), reach its back (his swat from the east side reaches %.1f in)" % [ch,rise-under_d,float(n.neck),float(n.reach)-float(n.length)*0.5]},
		"his_lane":[_aabb(Vector3(-cw,0.0,0.0),Vector3(cw,rise+float(n.neck),run)),_aabb(Vector3(x_q,rise,-pd),Vector3(cw,rise+float(n.neck),0.0))],
		"hers":[_aabb(Vector3(x_ch,0.0,0.0),Vector3(-cw,rise,run)),_aabb(Vector3(foot_x,0.0,0.0),Vector3(cw,rise-under_d,z_rest))],
		"safe":[_aabb(Vector3(foot_x,0.0,0.0),Vector3(cw-float(n.reach)-0.3,rise-under_d-0.6,z_rest*0.4))],
		"ports":{"foot":Vector3(0.0,0.0,run+3.0),"crown":Vector3((x_q+cw)*0.5,rise,-pd*0.5),"chimney":Vector3((x_ch-cw)*0.5,0.0,run*0.5),"chimney_back":Vector3((x_ch-cw)*0.5,0.0,so+0.3),
			"wall_top":Vector3((x_q+x_ch)*0.5,rise,3.0),"hollow_mouth":Vector3(cw+2.0,0.0,z_rest*0.3),"hollow":Vector3(foot_x+1.0,0.0,1.2),"perch":Vector3(perch.x,ptop,perch.z),"ledges":ledges},
	}
	return _finish(b,"city_wedge",extra)
