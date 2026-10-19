extends RefCounted
## The wreck cluster's numbers and land (studies/wreck_cluster.gd), rebuilt
## round the colonnade spine (docs/design/wreck-cluster/spec-wreck-colonnade.md).
##
##   spine    the colonnade spine at the centre, built by its own motif
##            (scripts/kit_isle/motif_colonnade_spine.gd at its authored
##            seed, studies/colonnade_spine_isle_art.gd's numbers), standing
##            where its own study stands it: the ridge along x 14..150, the
##            temple's podium at its west head, the tail curling south-east
##   strip    a long narrow islet under the spine's south flank, the plane
##            parked at its east end facing west down a clear run; a lobe
##            off its north edge carries the footbridge up onto the spine's
##            south bench
##   coast    a tall islet east of the tower, reached only by the sail off
##            the lookout: an arch, part spot 13, the way on down to the tail
##   ropes    the chain off the north shelf: a slam-spring slab under a jib,
##            its launch into the swing rope hung from the jib, the release
##            across onto the rope rock's landing (an islet north of the
##            spine, higher than anything near it): a chapel arch, part spot
##            14, and the start of the way on (the slide, a later step)
##
## Every gap and rise is sized from the walker (RuinKit GRAB_TOP 1.875,
## CHAIN_TOP 2.575; `tools/kit_piece.py numbers`).
const RuinKit = preload("res://scripts/ruin_kit.gd")
const Spine = preload("res://studies/colonnade_spine_isle_art.gd")
const Tower = preload("res://scripts/ruin_kit_tower.gd")
const Belfry = preload("res://scripts/ruin_kit_belfry.gd")

## The spine's base turf (world y): its TOP.
const TOP := Spine.TOP
## The strip's turf: a metre over the spine's TOP, so the footbridge up to
## the bench (y about 32.6) climbs gently.
const STRIP_TOP := TOP+1.0
## The take-off strip: a clear run along z STRIP_Z from the plane west to
## the islet's west rim (about 90 m), STRIP_HALF either side kept clear.
const STRIP_Z := 16.0
const STRIP_HALF := 5.5
## The parked plane: its middle near the strip's east end, facing west
## (heading PI/2: forward is (-sin h, 0, -cos h) = -x).
const PLANE_AT := Vector2(113.0,STRIP_Z)
const PLANE_HEADING := PI*0.5
## The footbridge from the strip's lobe up to the south bench's lip.
static func bridge_ends() -> Array:
	return [Vector3(110.0,STRIP_TOP,4.6),Vector3(110.0,Spine.ground(110.0,-2.6),-2.6)]

# --- Outlines ---------------------------------------------------------------------

## The strip islet (x, z): about 100 m west to east, 13 wide, its lobe at
## x 104..118 reaching north under the bench.
static func strip_outline() -> Array:
	return [Vector2(20.0,15.0),Vector2(23.0,10.6),Vector2(34.0,9.6),Vector2(60.0,9.9),Vector2(86.0,9.6),
		Vector2(100.0,9.0),Vector2(104.0,5.4),Vector2(109.0,3.6),Vector2(115.0,3.8),Vector2(119.5,7.0),
		Vector2(122.0,13.0),Vector2(121.0,20.0),Vector2(113.0,23.0),Vector2(90.0,23.4),Vector2(60.0,23.0),
		Vector2(36.0,22.6),Vector2(25.0,20.6)]

## The rock the tower's podium hangs over: a shelf off the spine's north-
## east corner where the pad falls away, its turf TOWER_ROCK, under the
## skirt's top, so the podium's tiers stand on it rather than in the air.
const TOWER_ROCK := 30.4
static func tower_rock_outline() -> Array:
	return [Vector2(135.0,-28.5),Vector2(134.5,-33.5),Vector2(138.0,-38.0),Vector2(146.0,-39.0),Vector2(152.5,-37.0),
		Vector2(155.5,-31.0),Vector2(155.5,-22.0),Vector2(153.5,-15.5),Vector2(150.0,-15.0),Vector2(149.5,-28.0)]

## The coast rock: a tall islet standing alone in the sky east of the
## tower, its turf COAST_TOP (15 m over the spine's TOP, near the belfry's
## wall head), its keel COAST_DEEP down. Reached only by the coast down: the
## sail off the lookout (y 55.75) carries him over its near edge at about
## y 49 (measured: 4.35 m on per m down after the jump; at y 46 he is
## 46.7 m out), while from the next highest ground, the belfry's wall head
## (y 46.1, 35 m west of its near edge), the sail is 4.9 m out at y 46.
## The way on: the sail off its west edge down to the tail's first fragment
## (spot 08, 24 m away and 12 m down: the slam onto its cache from the sail).
const COAST_TOP := 46.0
const COAST_DEEP := 26.0
const COAST_AT := Vector2(188.0,-20.0)
static func coast_rock_outline() -> Array:
	var c := COAST_AT
	var out := []
	for w: Vector2 in [Vector2(-8.5,-1.0),Vector2(-7.0,-5.5),Vector2(-2.5,-7.5),Vector2(3.0,-7.0),Vector2(7.5,-4.0),
			Vector2(8.5,1.5),Vector2(6.0,6.0),Vector2(1.0,7.5),Vector2(-4.5,6.5),Vector2(-8.0,3.5)]:
		out.append(c+w)
	return out
## The coast rock's arch: on its west side, its span along z, so it frames
## the tower as he lands and the way back off the west edge; part spot 13
## stands under it.
const COAST_ARCH := Vector2(-3.0,0.0)
static func coast_arch_foot() -> Vector3:
	return Vector3(COAST_AT.x+COAST_ARCH.x,COAST_TOP,COAST_AT.y+COAST_ARCH.y)

## The rope chain (spec: Chained moves), north off the spine's north shelf
## along x ROPE_X, every step on the architecture or the land:
##   shelf    the north shelf (y 37.6 at x 84, its edge at z -32.5)
##   spur     a stone jutting north off the shelf's edge, level with it
##   slab     a slam-spring bob slab past the spur's end, ROPE_SLAB_DOWN
##            under it, clear of the flank by more than its spring's sink:
##            a running hop off the spur and the slam onto it (a hop gives
##            the 0.45 m of air a slam needs)
##   jib      a worn column standing on the shelf beside the spur's root, a
##            broken beam jutting north off its head over the slab: the
##            rope's anchor
##   rope     the swing rope hung from the jib's end, its knot over the
##            slab, where the slab's launch (6 pumps, 9 m) meets it
##   landing  a stone landing jutting off the rope rock's south rim, 14 m on
##            from the rope (measured: let go rising, he is 13.4+ m on with
##            his feet still over its grab height and lands on it)
## The rope rock's turf (ROPE_TOP) stands over the slab's launch (apex
## 44.25: with the sail, his feet are over the landing's grab height only
## 0-5 m on, 14.6 needed) and over everything near it but the tower (the
## colonnade's lintels 45.2-47.4, the crest 41.2); the tower's rim is 71 m
## off, past its sail's 47 m to that height. Its sides are `sheer`
## (nothing to climb). The deliberate shortcut: an updraft charge saved
## and spent at the launch's top (3.7 m more) sails him 14.3 m on, to a
## grab on the landing's edge. The way back is the sail down to the
## shelf; the way on is the slide (a later step).
const ROPE_X := 84.0
const ROPE_SHELF := Vector3(84.0,37.6,-31.4)
## The spur: a stone jutting north off the shelf's edge, its top level
## with the shelf, its end ROPE_SPUR_END (the jump off).
const ROPE_SPUR_END := -35.0
const ROPE_SPUR := Vector2(1.6,1.2)
const ROPE_SLAB_DOWN := 1.0
const ROPE_SLAB_Z := -37.4
## The jib's column: on the shelf beside the spur's root (east of it).
const JIB_AT := Vector2(85.7,-31.4)
const JIB_SIDE := 1.3
const JIB_BEAM := Vector2(0.9,0.8)
const ROPE_ANCHOR := Vector3(84.0,49.5,-38.0)
const ROPE_LENGTH := 5.6
const ROPE_TOP := 46.5
const ROPE_AT := Vector2(84.0,-62.7)
const LANDING := Vector3(4.0,0.7,3.0)
static func rope_slab_top() -> Vector3:
	return Vector3(ROPE_X,ROPE_SHELF.y-ROPE_SLAB_DOWN,ROPE_SLAB_Z)
static func rope_anchor() -> Vector3:
	return ROPE_ANCHOR
static func rope_spur_end() -> Vector3:
	return Vector3(ROPE_X,ROPE_SHELF.y,ROPE_SPUR_END)
static func rope_rock_outline() -> Array:
	var c := ROPE_AT
	var out := []
	for w: Vector2 in [Vector2(-7.5,-2.0),Vector2(-5.5,-6.5),Vector2(-1.0,-8.0),Vector2(4.5,-6.5),Vector2(7.5,-2.5),
			Vector2(7.0,3.5),Vector2(4.0,7.5),Vector2(0.0,8.5),Vector2(-4.5,7.5),Vector2(-7.5,3.0)]:
		out.append(c+w)
	return out
## The landing's outer edge's middle (its top) and where it starts in the turf.
static func landing_edge() -> Vector3:
	return Vector3(ROPE_AT.x,ROPE_TOP,ROPE_AT.y+8.5+LANDING.z-0.8)
## The chapel arch on the rope rock (span along x), part spot 14 under it.
static func rope_arch_foot() -> Vector3:
	return Vector3(ROPE_AT.x,ROPE_TOP,ROPE_AT.y-1.0)
## The jib, the column under it and the landing: [layout name, node, world
## foot, yaw (deg)].
static func ropes_built() -> Array:
	var head := ROPE_ANCHOR.y+JIB_BEAM.y
	var col_h := head-ROPE_SHELF.y
	var cb := RuinKit.Build.new(621,0.35,"JibColumn")
	_block(cb,Vector3(0.0,(col_h-4.0)*0.5,0.0),Vector3(JIB_SIDE*0.5,(col_h+4.0)*0.5,JIB_SIDE*0.5))
	var column := cb.finish()
	# The jib: from over the column's middle out past the anchor (0.3 m).
	var jb := RuinKit.Build.new(622,0.3,"Jib")
	var to := Vector2(ROPE_ANCHOR.x,ROPE_ANCHOR.z)-JIB_AT
	var tip := to+to.normalized()*0.3
	var back := -to.normalized()*JIB_SIDE*0.5
	Spine._beam(jb,Vector3(back.x,0.0,back.y),Vector3(tip.x,0.0,tip.y),JIB_BEAM)
	var jib := jb.finish()
	var sb := RuinKit.Build.new(625,0.3,"Spur")
	Spine._beam(sb,Vector3(0.0,0.0,0.0),Vector3(0.0,0.0,ROPE_SPUR_END-ROPE_SHELF.z),ROPE_SPUR)
	var spur := sb.finish()
	var lb := RuinKit.Build.new(623,0.3,"Landing")
	Spine._beam(lb,Vector3(0.0,0.0,-LANDING.z),Vector3(0.0,0.0,0.0),Vector2(LANDING.x,LANDING.y))
	var landing := lb.finish()
	return [
		["ropes/spur",spur,ROPE_SHELF,0.0],
		["ropes/column",column,Vector3(JIB_AT.x,ROPE_SHELF.y,JIB_AT.y),0.0],
		["ropes/jib",jib,Vector3(JIB_AT.x,head,JIB_AT.y),0.0],
		["ropes/landing",landing,landing_edge(),0.0],
	]

## A worn upright block (walk hull on all sides) centred `c`, `half` its
## half extents, in `b`'s frame.
static func _block(b: RuinKit.Build, c: Vector3, half: Vector3) -> void:
	var pose := Transform3D(Basis.IDENTITY,c)
	b.lean = true
	b.solid(RuinKit._box(b,half),pose,RuinKit._stone(b,1.03),false,true,[],-1,1.0)
	b.lean = false
	RuinKit._walk_hull(b,pose,[Plane(Vector3.RIGHT,half.x),Plane(Vector3.LEFT,half.x),Plane(Vector3.UP,half.y),Plane(Vector3.DOWN,half.y),Plane(Vector3.BACK,half.z),Plane(Vector3.FORWARD,half.z)])

## The lands besides the spine: [name, outline, ground, depth (its keel
## under its rim), seed, cliffs box (none: Rect2()), its rim's height,
## optional: sheer (its hanging sides not collided as drawn, whose jagged
## faces he catches and climbs, but one smooth hull that overhangs all
## round: nothing to catch on the way up its flank)].
static func lands() -> Array:
	return [
		["strip",strip_outline(),func(_x: float, _z: float) -> float: return STRIP_TOP,16.0,405,Rect2(),STRIP_TOP],
		["tower_rock",tower_rock_outline(),func(_x: float, _z: float) -> float: return TOWER_ROCK,18.0,407,Rect2(),TOWER_ROCK],
		["coast_rock",coast_rock_outline(),func(_x: float, _z: float) -> float: return COAST_TOP,COAST_DEEP,409,Rect2(),COAST_TOP,true],
		["rope_rock",rope_rock_outline(),func(_x: float, _z: float) -> float: return ROPE_TOP,22.0,411,Rect2(),ROPE_TOP,true],
	]

## Land `spec` (a row of `lands`) built: a KitLand island, its sides collided.
static func build_land(spec: Array) -> Node3D:
	var cliffs: Rect2 = spec[5]
	var d := {"outline":spec[1],"seed":int(spec[4]),"ground":spec[2],"top":float(spec[6]),
		"depth":float(spec[3]),"hang":true,"resample":[60.0,128,48],"tone":KitLook.turf(int(spec[4])),"cell":2.0,
		"collide_sides":true,"name":"wreck_cluster/"+str(spec[0])}
	if cliffs.size != Vector2.ZERO: d["cliffs"] = cliffs
	var sheer: bool = spec.size() > 7 and bool(spec[7])
	if sheer: d["collide_sides"] = false
	var node := KitLand.island(d)
	node.name = "Land_"+str(spec[0]).capitalize()
	if sheer: node.add_child(sheer_hull(spec[1],float(spec[6]),float(spec[3])))
	return node

## How far under the rim a sheer land's hull starts (the turf collides
## over it), its depth's share it reaches down, how much of the outline its
## keel end keeps, and how far in from the drawn rim its top stands.
const SHEER_UNDER := 0.25
const SHEER_DEEP := 0.7
const SHEER_KEEL := 0.28
const SHEER_IN := 0.4

## A sheer land's flank: one convex hull from just under its rim (the
## outline pulled SHEER_IN in) narrowing down to a small keel, so its sides
## overhang everywhere and hold no lip to catch.
static func sheer_hull(outline: Array, top: float, depth: float) -> StaticBody3D:
	var mid := Vector2.ZERO
	for p: Vector2 in outline: mid += p
	mid /= float(outline.size())
	var pts := PackedVector3Array()
	var y0 := top-SHEER_UNDER
	var y1 := top-depth*SHEER_DEEP
	for p: Vector2 in outline:
		var q := p-(p-mid).normalized()*SHEER_IN
		pts.append(Vector3(q.x,y0,q.y))
		var k := mid+(p-mid)*SHEER_KEEL
		pts.append(Vector3(k.x,y1,k.y))
	var shape := ConvexPolygonShape3D.new()
	shape.points = pts
	var col := CollisionShape3D.new()
	col.shape = shape
	var body := StaticBody3D.new()
	body.name = "SheerFlank"
	body.add_child(col)
	return body

# --- What stands --------------------------------------------------------------------

## The kit pieces: [layout name, kit piece, seed, weathered, world foot,
## yaw (deg)], each colliding as the kit built it. (None yet: the tower is
## `tower` below; the slide and the other islets come in later steps.)
static func pieces() -> Array:
	return [
		["coast/arch","arch",619,0.3,coast_arch_foot(),90.0],
		["ropes/arch","arch",624,0.25,rope_arch_foot(),0.0],
	]

# --- The tower --------------------------------------------------------------------

## The tower: a ruined campanile on the low pad at the spine's east end
## (turf y about 31.2-31.7, open sky north and east), two stages side by
## side on one broad podium: a tall kick shell (scripts/ruin_kit_tower.gd,
## its back wall torn open) with the belfry (scripts/ruin_kit_belfry.gd,
## its bell still hanging) standing against its open back, north of it.
## A stepped skirt and a buttress widen the foot. The climb, bottom to top:
##   stairs   a kit flight north from the pad to a landing STAIRS_RISE up
##   ledge    the podium's lip (PODIUM_H-STAIRS_RISE, 1.56) over the
##            landing: under GRAB_TOP, a jump and a grab
##   then a choice of line:
##   inside   in at the shell's door, wall kicks the whole way up the shaft
##            to the kick walls' heads (the long line, one move)
##   outside  round the shell's east side to the belfry's outer stair (three
##            flights round three faces), in at its west opening onto the
##            belfry floor, up its two corbels to the wall head: the landing
##            partway up (the bell under you, part spot 12, the view south
##            over the spine); along the south wall's head onto the lintel
##            jammed across the shell's open back, and kicks from there up the
##            last SHELL_H-BELFRY_HEAD of the shaft
##   top      the east kick wall's head, the lookout beam jutting off it east
##            over the sky (the coast down's start) and part spot 11
## The skilled shortcut: the crest's east lip (x ~136-138, y 34.6-35.3)
## stands about level with the podium's top west of the buttress.
## The shell's middle (x, z) and the turf its stairs stand on.
const TOWER_AT := Vector2(144.5,-22.0)
const TOWER_FOOT := 31.7
## The podium's height over the turf; the kick walls' height over the
## podium; the shell's wear (breaches up its front to rest in).
const PODIUM_H := 3.8
const SHELL_H := 20.0
const SHELL_WEAR := 0.35
## The belfry's wall head over its foot (the kit's HEAD, its south wall's
## worn top) and its wear.
const BELFRY_HEAD := 10.6
const BELFRY_WEAR := 0.4
## The stair flight's rise to its landing (RuinKit STEPS of RISER) and its
## run, foot to the landing's far edge.
const STAIRS_RISE := RuinKit.STEPS*RuinKit.RISER
const STAIRS_RUN := (RuinKit.STEPS-1)*RuinKit.TREAD+RuinKit.LANDING
## The podium's apron round the two stages: east and west of the shell
## (room for the buttress west and the walk east), north of the belfry, and
## before the shell's door; how deep it runs down into the rock.
const APRON_SIDE := 4.4
const APRON_BACK := 0.4
const APRON_FRONT := 2.2
const PODIUM_DEEP := 4.0
## The skirt: a lower tier round the podium's back and sides, SKIRT_H over
## the turf, SKIRT out past the podium, falling deep down the cliff.
const SKIRT_H := 1.0
const SKIRT := 2.2
const SKIRT_DEEP := 6.0
## The lintel jammed across the shell's open back at the belfry head: its
## depth into the shaft from the shell's back edge (the kick walls start
## Tower.WALL in from that edge, the back wall being gone, so it reaches
## past them: kicked from its south end; the rest of the shaft stays clear
## for the inside line), its thickness, how far under the head.
const LINTEL_IN := 2.0
const LINTEL_THICK := 0.6
const LINTEL_DROP := 0.15
## The lookout beam off the east wall's head: how far it juts past the
## wall's outer face, its width and depth, how far its top stands over the
## head.
const LOOKOUT_OUT := 3.4
const LOOKOUT := Vector2(1.1,0.5)
const LOOKOUT_STEP := 0.25

## The podium's top, the kick walls' heads, the belfry's wall head (world y).
static func plinth_top() -> float:
	return TOWER_FOOT+PODIUM_H
static func tower_rim() -> float:
	return plinth_top()+SHELL_H
static func belfry_head() -> float:
	return plinth_top()+BELFRY_HEAD

## The belfry's middle (x, z): against the shell's open back, north.
static func belfry_at() -> Vector2:
	return Vector2(TOWER_AT.x,TOWER_AT.y-Tower.half_extents().y-Belfry.WIDTH*0.5)

## The podium's extents (x, z: min and max corners, world).
static func plinth_rect() -> Rect2:
	var h := Tower.half_extents()
	var a := Vector2(TOWER_AT.x-h.x-APRON_SIDE,belfry_at().y-Belfry.STAIR_OUT-Belfry.STAIR_WIDTH*0.5-APRON_BACK)
	var e := Vector2(TOWER_AT.x+h.x+APRON_SIDE,TOWER_AT.y+h.y+APRON_FRONT)
	return Rect2(a,e-a)

## The stair flight's middle (the kit's origin: the run centred on it),
## climbing north (-z) to the podium's south face.
static func stairs_at() -> Vector3:
	return Vector3(TOWER_AT.x,TOWER_FOOT,plinth_rect().end.y+STAIRS_RUN*0.5)

## The route's way points (world): the stair landing, the shell's door,
## the belfry's outer stair's points (foot to the floor), its corbels' tops,
## the middle of its south wall's head, the lintel's kicking spot (its
## south end, between the kick walls).
static func landing_point() -> Vector3:
	return Vector3(TOWER_AT.x,TOWER_FOOT+STAIRS_RISE,plinth_rect().end.y+0.5)
static func door_point() -> Vector3:
	return Vector3(TOWER_AT.x,plinth_top(),TOWER_AT.y+Tower.half_extents().y+0.6)
static func belfry_way() -> Array:
	var c := belfry_at()
	var out := []
	for w: Vector3 in [Vector3(3.77,0.0,1.53),Vector3(3.77,2.24,-2.67),Vector3(3.77,2.24,-3.77),Vector3(-2.67,4.48,-3.77),
			Vector3(-3.77,4.48,-3.77),Vector3(-3.77,6.16,0.55),Vector3(-1.2,6.16,0.0)]:
		out.append(Vector3(c.x+w.x,plinth_top()+w.y,c.y+w.z))
	return out
static func belfry_corbels() -> Array:
	var c := belfry_at()
	var out := []
	for k: Array in Belfry.CORBELS:
		var s: Vector2 = k[1]
		out.append(Vector3(c.x+s.x*0.95,plinth_top()+float(k[0]),c.y+s.y*0.95))
	return out
static func belfry_south_head(dx := 0.0) -> Vector3:
	return Vector3(belfry_at().x+dx,belfry_head(),belfry_at().y+Belfry.WIDTH*0.5-Belfry.WALL*0.5)
static func lintel_point() -> Vector3:
	return Vector3(TOWER_AT.x,belfry_head()-LINTEL_DROP,TOWER_AT.y-Tower.half_extents().y+LINTEL_IN-0.35)

## The east kick wall's head (the middle of its thickness) at `dz` along it.
static func east_head(dz := 0.0) -> Vector3:
	return Vector3(TOWER_AT.x+Tower.half_extents().x-Tower.WALL*0.5,tower_rim(),TOWER_AT.y+dz)

## The lookout's tip (its top's middle at the far end, world).
static func lookout_tip() -> Vector3:
	return Vector3(TOWER_AT.x+Tower.half_extents().x+LOOKOUT_OUT,tower_rim()+LOOKOUT_STEP,TOWER_AT.y)

## The tower's parts: [layout name, node, world foot, yaw (deg)].
static func tower() -> Array:
	var r := plinth_rect()
	var c := r.get_center()
	var b := RuinKit.Build.new(611,0.4,"Podium")
	var hx := r.size.x*0.5
	Spine._beam(b,Vector3(-hx,0.0,0.0),Vector3(hx,0.0,0.0),Vector2(r.size.y,PODIUM_H+PODIUM_DEEP))
	var podium := b.finish()
	# The skirt: three worn tiers (west, north, east) round the podium.
	var sk := RuinKit.Build.new(615,0.5,"Skirt")
	var sx := hx+SKIRT
	var sz := r.size.y*0.5
	var tier := Vector2(SKIRT,SKIRT_H+SKIRT_DEEP)
	Spine._beam(sk,Vector3(-sx,0.0,-sz-SKIRT*0.5),Vector3(sx,0.0,-sz-SKIRT*0.5),tier)
	Spine._beam(sk,Vector3(-sx+SKIRT*0.5,0.0,-sz),Vector3(-sx+SKIRT*0.5,0.0,sz-1.0),tier)
	Spine._beam(sk,Vector3(sx-SKIRT*0.5,0.0,-sz),Vector3(sx-SKIRT*0.5,0.0,sz-1.0),tier)
	var skirt := sk.finish()
	var shell := Tower.tower_shell(612,SHELL_WEAR,SHELL_H,true)
	var belfry := Belfry.belfry(616,BELFRY_WEAR)
	# The lintel: a long stone jammed between the kick walls, from the
	# belfry's south wall head into the shaft.
	var lb0 := RuinKit.Build.new(617,0.3,"Lintel")
	var back := Belfry.WALL*0.5
	Spine._beam(lb0,Vector3(0.0,0.0,-back),Vector3(0.0,0.0,LINTEL_IN),Vector2(Tower.KICK_GAP-0.04,LINTEL_THICK))
	var lintel := lb0.finish()
	var lb := RuinKit.Build.new(613,0.3,"Lookout")
	var tail := Tower.WALL+0.4
	Spine._beam(lb,Vector3(-tail,0.0,0.0),Vector3(LOOKOUT_OUT,0.0,0.0),LOOKOUT)
	var lookout := lb.finish()
	var ox := TOWER_AT.x+Tower.half_extents().x
	var bf := belfry_at()
	var lp := lintel_point()
	return [
		["tower/skirt",skirt,Vector3(c.x,TOWER_FOOT+SKIRT_H,c.y),0.0],
		["tower/plinth",podium,Vector3(c.x,plinth_top(),c.y),0.0],
		["tower/stairs",RuinKit.piece("stairs",614,0.35),stairs_at(),0.0],
		["tower/shell",shell,Vector3(TOWER_AT.x,plinth_top(),TOWER_AT.y),0.0],
		["tower/belfry",belfry,Vector3(bf.x,plinth_top(),bf.y),0.0],
		["tower/buttress",RuinKit.piece("buttress",618,0.15),Vector3(TOWER_AT.x-Tower.half_extents().x-1.9,plinth_top(),TOWER_AT.y),180.0],
		["tower/lintel",lintel,Vector3(lp.x,lp.y,TOWER_AT.y-Tower.half_extents().y),0.0],
		["tower/lookout",lookout,Vector3(ox,tower_rim()+LOOKOUT_STEP,TOWER_AT.y),0.0],
	]

# --- The part spots -----------------------------------------------------------------

## The holder types a spot could host (spec item 10): `lying` and `cache`
## are built; the rest are data for a later round.
const HOLDERS := ["lying","cache","water","islet","salvager","knight","jammed"]

## A point on the spine's ground at axis `x`, `d` across.
static func on_spine(x: float, d: float) -> Vector3:
	var q := Spine.at(x,d)
	return Vector3(q.x,Spine.ground(q.x,q.y),q.y)

## A point on slab or fragment `name`'s top, `off` (x, z) from its middle.
static func on_slab(name: String, off := Vector2.ZERO) -> Vector3:
	var s := Spine.slab(name)
	var c := Spine.slab_at(s)+off
	return Vector3(c.x,TOP+float(s[4]),c.y)

## The candidate spots for the plane's six parts, in the architecture's
## nooks: [mass, what it asks, world point (on what it rests on), holder
## tags]. Named `wreck_cluster/part_spot_NN` (NN from 01 in this order) for
## the world view; the deal settles each onto what's under it.
static func spots() -> Array:
	var podium := TOP+Spine.PODIUM
	return [
		["head","in the cella, by the altar",Vector3(Spine.ALTAR_X+2.4,podium,Spine.zc(Spine.ALTAR_X+2.4)+1.6),["lying","cache"]],
		["head","the pulpit off the podium (dropped onto)",on_slab("pulpit",Vector2(0.4,0.6)),["lying","salvager"]],
		["way","under the first portal's arch",on_spine(float(Spine.LINES[2][0]),0.0),["lying","jammed"]],
		["way","on the north balcony",on_slab("balcony",Vector2(-0.3,-0.4)),["lying","salvager"]],
		["way","under the second portal's arch",on_spine(float(Spine.LINES[5][0]),1.2),["lying","jammed"]],
		["bench","the top slab of the south three",on_slab("south_3"),["lying","knight"]],
		["bench","the bench's east end by the tail",Spine.bench_point(140.0),["lying","cache"]],
		["tail","the tail's first fragment",on_slab("frag_1",Vector2(0.5,-0.5)),["lying","islet","cache"]],
		["tail","the tail's far fragment (over the bridge)",on_slab("frag_3"),["lying","salvager"]],
		["tail","the last fragment, under the bench",on_slab("frag_5"),["lying","water","cache"]],
		["tower","the tower top, on the east wall's head by the lookout",east_head(1.4),["lying","salvager"]],
		["tower","the belfry's wall head, over the bell (partway up)",belfry_south_head(-1.4),["lying","jammed"]],
		["coast","under the coast rock's arch (the coast down's end)",coast_arch_foot(),["lying","islet","salvager"]],
		["ropes","under the rope rock's chapel arch (the rope chain's end)",rope_arch_foot(),["lying","islet","salvager"]],
	]

## The caches (spec item 10's change; studies/wreck_cluster_caches.gd): a
## breakable kit piece standing on a spot, which hides a part on the deals
## that pick it and breaks to nothing on the rest. [spot index (Art.spots
## order), RuinKit id, seed, yaw (deg), wear (its rubble skirt widens it:
## a pier 1.5 m across at 0, 5 m at 0.3)]. Named `wreck_cluster/cache_NN`
## (NN the spot's). Every one is CACHE_TOUGH: a slam off CACHE_DROP m or
## more (scripts/slam.gd: 0.25 + 0.75 (drop - 1.8) / 9.2) or a side slam
## (0.65) opens it; a hop's slam only flares its glint. Each has a height
## over it to slam from (only 10 checked): the cella's walls (01), the
## crest over the bench's end (07), the tower's skirt (08), the crest north
## of 10 (a jump and the sail down).
const CACHES := [
	[0,"pier",731,15.0,0.3],
	[6,"buttress",732,90.0,0.3],
	[7,"wall",733,-20.0,0.15],
	[9,"pier",734,0.0,0.0],
]
const CACHE_TOUGH := 0.32
const CACHE_DROP := 2.6
## How many of the six each deal hides in caches, least and most.
const HIDDEN := Vector2i(1,2)

static func cache_name(spot: int) -> String:
	return "wreck_cluster/cache_%02d" % (spot+1)

## The spot indices that stand a cache.
static func cache_spots() -> Array:
	return CACHES.map(func(c: Array) -> int: return int(c[0]))

static func spot_name(i: int) -> String:
	return "wreck_cluster/part_spot_%02d" % (i+1)

# --- The knight -------------------------------------------------------------------

## The knight's line (scripts/enemies/rune_knight.gd `setup`): none until
## his deck is built (empty: no knight).
static func knight_line() -> Dictionary:
	return {}
