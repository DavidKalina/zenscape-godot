extends RefCounted
## The wreck cluster's numbers and land (studies/wreck_cluster.gd), rebuilt
## round the colonnade spine (docs/design/wreck-cluster/spec-wreck-colonnade.md).
##
##   spine    the colonnade spine at the centre, built by its own motif
##            (scripts/kit_isle/motif_colonnade_spine.gd at its authored
##            seed, studies/colonnade_spine_isle_art.gd's numbers), standing
##            where its own study stands it: the ridge along x 14..150, the
##            temple's podium at its west head (its tail of fragments and
##            stepping stones cut: studies/wreck_cluster.gd TAIL_CUT)
##   strip    a long narrow islet under the spine's south flank, the plane
##            parked at its east end facing west down a clear run; a lobe
##            off its north edge carries the footbridge up onto the spine's
##            south bench
##   coast    a tall islet east of the tower, reached only by the sail off
##            the lookout: an arch, part spot 13, the way on down to the tower
##            rock's south-east lobe
##   ropes    the chain off the north shelf: a slam-spring slab under a flyer,
##            its launch into the swing rope hung from the flyer, the release
##            across onto the rope rock's landing (an islet north of the
##            spine, higher than anything near it): a chapel arch, part spot
##            14, and the start of the way on (the slide)
##   slide    a tongue of the tilt rock's own turf and rock sloping up
##            under the rope rock's west rim (the tilt rock a low islet
##            tilted like a dropped slab): a
##            lancet wall, a carved chest, part spot 15, and a footbridge
##            on to the north balcony
##   knight   a snapped stone causeway west off the strip's west end over
##            open sky: the rune knight's deck, part spot 16 on its tip in
##            the lee of a snapped pier
##   flank    a broken terrace walk along the spine's south flank, from
##            the bench's west end up to the pulpit, a fallen pier up onto
##            it from the strip, part spot 17
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
## Its south-east lobe takes in the ground where the spine's own tail
## curled off in fragments and stepping stones (cut here as clutter): the
## coast down's way on lands on it (spot 08 and its cache, TAIL_LOBE).
const TAIL_LOBE := Vector2(157.0,-10.0)
static func tower_rock_outline() -> Array:
	return [Vector2(135.0,-28.5),Vector2(134.5,-33.5),Vector2(138.0,-38.0),Vector2(146.0,-39.0),Vector2(152.5,-37.0),
		Vector2(155.5,-31.0),Vector2(155.5,-22.0),Vector2(158.5,-16.5),Vector2(161.5,-11.5),Vector2(160.5,-6.5),
		Vector2(156.5,-4.8),Vector2(151.5,-5.5),Vector2(147.0,-7.5),Vector2(145.8,-11.0),Vector2(147.5,-15.5),Vector2(149.5,-28.0)]
## A point on the tower rock's turf (world), `off` (x, z) from the lobe's
## middle.
static func on_lobe(off := Vector2.ZERO) -> Vector3:
	return Vector3(TAIL_LOBE.x+off.x,TOWER_ROCK,TAIL_LOBE.y+off.y)
## Spot 09: on the tower rock's turf under the belfry's north face, below
## its outer stair (the slam onto its cache: off the stair's flights).
const UNDER_BELFRY := Vector2(146.0,-36.6)
## Spot 10: on the strip's lobe by the footbridge's foot, under the bench.
const STRIP_LOBE_SPOT := Vector2(116.5,6.5)

## The coast rock: a tall islet standing alone in the sky east of the
## tower, its turf COAST_TOP (15 m over the spine's TOP, near the belfry's
## wall head), its keel COAST_DEEP down. Reached only by the coast down: the
## sail off the lookout (y 55.75) carries him over its near edge at about
## y 49 (measured: 4.35 m on per m down after the jump; at y 46 he is
## 46.7 m out), while from the next highest ground, the belfry's wall head
## (y 46.1, 35 m west of its near edge), the sail is 4.9 m out at y 46.
## The way on: the sail off its west edge down to the tower rock's lobe
## (spot 08, 24 m away and 12 m down: the slam onto its cache from the sail).
const COAST_TOP := 46.0
const COAST_DEEP := 50.0
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
##   flyer    a gothic buttress pier on the shelf beside the spur's root,
##            its flying arm leaping north off its head over the slab and
##            broken off in mid-air: the rope's anchor
##   rope     the swing rope hung from the flyer's broken end, its knot over the
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
## shelf; the way on is the slide (below).
const ROPE_X := 84.0
const ROPE_SHELF := Vector3(84.0,37.6,-31.4)
## The spur: a stone jutting north off the shelf's edge, its top level
## with the shelf, its end ROPE_SPUR_END (the jump off).
const ROPE_SPUR_END := -35.0
const ROPE_SPUR := Vector2(1.6,1.2)
const ROPE_SLAB_DOWN := 1.0
const ROPE_SLAB_Z := -37.4
## The flyer's pier: on the shelf beside the spur's root (east of it).
const JIB_AT := Vector2(85.7,-31.4)
## The arm's depth at its broken end (the old jib's, under the anchor).
const JIB_BEAM := Vector2(0.9,0.8)
## The pier's stages [top over the shelf, depth], FLYER_WIDTH across, sunk
## FLYER_SINK into the rock; the arm springs FLYER_RISE under its coping at
## the pier, whose top meets the pier at FLYER_FOOT, rising to the old jib's
## head at its end; FLYER_ARM wide, a FLYER_COPE coping, FLYER_STONES long.
const FLYER_STAGES := [Vector2(4.2,1.45),Vector2(7.6,1.15),Vector2(10.9,0.85)]
const FLYER_WIDTH := 1.4
const FLYER_SINK := 2.5
const FLYER_FOOT := 48.0
const FLYER_RISE := 3.2
const FLYER_ARM := 0.9
const FLYER_COPE := 0.2
const FLYER_STONES := 7
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
## The flyer, its pier and the landing: [layout name, node, world foot,
## yaw (deg)]. The rope hangs from a broken flying buttress: a gothic
## buttress pier propping the spine's north flank from the shelf (layout
## `ropes/column`), its arm (`ropes/jib`) leaping north off its head toward
## a nave that is gone, broken off in mid-air; the rope's anchor is under
## its broken end. The pier's first set-off stands FLYER_STAGES[0] over the
## shelf (past CHAIN_TOP), the next 3.4 m over that: no way up it, so the
## arm is no more reachable than the old jib was.
static func ropes_built() -> Array:
	var head := ROPE_ANCHOR.y+JIB_BEAM.y
	var to := Vector2(ROPE_ANCHOR.x,ROPE_ANCHOR.z)-JIB_AT
	var dir := to.normalized()
	var d3 := Vector3(dir.x,0.0,dir.y)
	# The pier: a buttress standing out along the arm's heading, its back
	# against the flank, sunk FLYER_SINK into the shelf's rock.
	var cb := RuinKit.Build.new(621,0.35,"FlyerPier")
	var stages := []
	for st: Vector2 in FLYER_STAGES: stages.append([st.x+FLYER_SINK,st.y])
	var face := Basis(Vector3(dir.y,0.0,-dir.x),Vector3.UP,d3)
	var depth0: float = FLYER_STAGES[0].y
	var foot := Transform3D(face,-d3*depth0*0.5+Vector3.DOWN*FLYER_SINK)
	RuinKit._buttress(cb,foot,stages,FLYER_WIDTH,true,true)
	# Collided as one clean battered block, its front leaning back from the
	# first stage's depth to the last's: the courses' slips and the set-offs'
	# lips give nothing to catch (checked: drawn as built, he jumped from
	# the shelf onto a course's lip and up the treads to the top).
	cb.hulls.clear()
	var tall: float = stages[-1][0]
	var depth1: float = FLYER_STAGES[-1].y
	var batter := Vector3(0.0,(depth0-depth1)/tall,1.0).normalized()
	var half := FLYER_WIDTH*0.5
	RuinKit._walk_hull(cb,foot,[Plane(Vector3.RIGHT,half),Plane(Vector3.LEFT,half),Plane(Vector3.DOWN,0.0),
		Plane(Vector3.UP,tall),Plane(Vector3.FORWARD,0.1),Plane(batter,batter.dot(Vector3(0.0,0.0,depth0)))])
	var column := cb.finish()
	# The arm, in the frame of its springing face (x along the heading, from
	# the pier's top stage's front, y from the jib's old head).
	var jb := RuinKit.Build.new(622,0.3,"Flyer")
	var s0: float = -depth0*0.5+FLYER_STAGES[-1].y
	var length := to.length()+0.3-s0
	var top0 := FLYER_FOOT-head
	var k := (0.0-top0)/length
	var spring := top0-FLYER_RISE
	var low := -JIB_BEAM.y
	var arm := Transform3D(Basis(d3,Vector3.UP,d3.cross(Vector3.UP)),d3*s0)
	var under := func(x: float) -> float:
		var u := clampf(1.0-x/length,0.0,1.0)
		return spring+(low-spring)*sqrt(1.0-u*u)
	var n := FLYER_STONES
	for i in range(n):
		var a := length*i/n-(0.35 if i == 0 else 0.0)
		var e := length*(i+1)/n
		var ya: float = under.call(maxf(a,0.0))
		var ye: float = under.call(e)
		var m := (ye-ya)/(e-a)
		var crest := Vector3(-k,1.0,0.0).normalized()
		var body: Array[Plane] = [Plane(Vector3.LEFT,-a),Plane(Vector3.RIGHT,e-0.012),
			Plane(Vector3.BACK,FLYER_ARM*0.5),Plane(Vector3.FORWARD,FLYER_ARM*0.5)]
		body.append(Plane(crest,crest.dot(Vector3(0.0,top0-FLYER_COPE,0.0))))
		var sole := Vector3(m,-1.0,0.0).normalized()
		body.append(Plane(sole,sole.dot(Vector3(a,ya,0.0))))
		var cope: Array[Plane] = [Plane(Vector3.LEFT,-a),Plane(Vector3.RIGHT,e-0.012),
			Plane(Vector3.BACK,FLYER_ARM*0.5+0.08),Plane(Vector3.FORWARD,FLYER_ARM*0.5+0.08)]
		cope.append(Plane(crest,crest.dot(Vector3(0.0,top0,0.0))))
		cope.append(Plane(-crest,-crest.dot(Vector3(0.0,top0-FLYER_COPE,0.0))))
		var cut: Array[Plane] = []
		if i == n-1:
			# The break: the last stone's end torn off on a slant, clear of
			# the anchor (0.3 m back from the end).
			var t := Vector3(1.0,jb.rng.randf_range(0.9,1.4),jb.rng.randf_range(-0.5,0.5)).normalized()
			cut.append(Plane(t,t.dot(Vector3(e-0.15,-0.3,0.0))))
			var t2 := Vector3(1.0,-jb.rng.randf_range(0.6,1.1),jb.rng.randf_range(-0.7,0.7)).normalized()
			cut.append(Plane(t2,t2.dot(Vector3(e+0.05,low+0.2,0.0))))
		jb.solid(body,arm,RuinKit._stone(jb,1.0),true,true,cut,-1,1.0)
		# The coping's last stone is gone with the break.
		if i < n-1: jb.solid(cope,arm,RuinKit._stone(jb,1.06),true,true,[],-1,1.2)
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

## The slide (spec item 6): the rope rock's way on, the land itself: the
## tilt rock (an islet tilted like a dropped slab, low under the north
## shelf) runs a tongue of turf and rock up north-east under the rope
## rock's west rim, a scree slope spilled off it (`slide_ground`, along
## SLIDE_WAY from SLIDE_HEAD, crowned across):
##   lodge    a flat shelf SLIDE_DROP_IN under the rope rock's west rim,
##            tucked under its overhang and reaching SLIDE_LIP past the
##            head: he drops in off the rim onto it (under the stun's 6 m)
##            and on down. From below the rim is past CHAIN_TOP (2.575)
##            over it, so the slide is one way: the rope rock stays the
##            rope's
##   steep    SLIDE_STEEP down: past the motor's SLIDE_AUTO (44), so he
##            can't stand on it and boot-surfs (drawn rock past the turf's
##            slope; hopping up it is possible, but the lodge's drop stops
##            him)
##   ease     SLIDE_EASE down to where it meets the tilt rock's own turf: a
##            crouched surf (over SLIDE_FROM 10), walkable back up
##   runout   the tilt rock's turf rises TILT_DEG westward, so the surf's
##            pace runs out up it before the far rim
## On the tilt rock: a lancet wall at its high west end with a carved
## chest before it, part spot 15 beside the chest; the way on is the
## footbridge off its south edge to the north balcony (spot 04) under the
## shelf, a jump-grab (1.6 m) up onto the shelf.
const SLIDE_WAY := Vector2(-0.944,0.330)
const SLIDE_HEAD := Vector3(73.4,ROPE_TOP-SLIDE_DROP_IN,-59.7)
const SLIDE_DROP_IN := 5.7
## How far the lodge runs back east from the head (under the rim, into the
## rope rock's flank), and on west past it before the steep starts (a full
## run's walk-off carries him 2.7 m out past the rim, about SLIDE_HEAD).
const SLIDE_LODGE := 6.3
const SLIDE_LIP := 0.8
const SLIDE_STEEP := 52.0
const SLIDE_BREAK := 3.6
const SLIDE_EASE := 24.0
## The tongue's crown: how much its turf falls across from its middle line
## (per m² off it), and its half widths along it [s, half].
const SLIDE_CROWN := 0.035
const SLIDE_HALF := [Vector2(-5.0,2.5),Vector2(-2.0,3.5),Vector2(1.0,4.0),Vector2(4.0,4.6)]
## The tilt rock: its middle, the turf at its east rim (x TILT_EAST), rising
## TILT_DEG westward; its keel.
const TILT_AT := Vector2(56.0,-53.5)
const TILT_EAST := 68.0
const TILT_LOW := 34.4
const TILT_DEG := 5.0
const TILT_DEEP := 11.0
## The tilt rock's own turf (no tongue).
static func tilt_plain(x: float) -> float:
	return TILT_LOW+(TILT_EAST-x)*tan(deg_to_rad(TILT_DEG))
## The tongue's top line: its height `s` m along SLIDE_WAY from the head.
static func slide_line(s: float) -> float:
	var steep_run := SLIDE_BREAK/tan(deg_to_rad(SLIDE_STEEP))
	var d := s-SLIDE_LIP
	if d <= 0.0: return SLIDE_HEAD.y
	if d <= steep_run: return SLIDE_HEAD.y-d*tan(deg_to_rad(SLIDE_STEEP))
	return SLIDE_HEAD.y-SLIDE_BREAK-(d-steep_run)*tan(deg_to_rad(SLIDE_EASE))
## The tongue at (x, z): along its line, less its crown across.
static func slide_ground(x: float, z: float) -> float:
	var q := Vector2(x-SLIDE_HEAD.x,z-SLIDE_HEAD.z)
	var s := q.dot(SLIDE_WAY)
	var t := q.dot(Vector2(-SLIDE_WAY.y,SLIDE_WAY.x))
	return slide_line(s)-SLIDE_CROWN*t*t
## The tilt rock's ground: its tilted turf, and up its tongue, the slide.
static func tilt_ground(x: float, z: float) -> float:
	return maxf(tilt_plain(x),slide_ground(x,z))
## Long and slab-like (x 43.5..68.5), its corners broken, and its tongue
## up north-east under the rope rock's west rim.
static func tilt_rock_outline() -> Array:
	var out := []
	for w: Vector2 in [Vector2(-12.5,-3.5),Vector2(-10.5,-7.0),Vector2(-3.0,-7.8),Vector2(5.0,-7.2),Vector2(10.5,-6.2)]:
		out.append(TILT_AT+w)
	var head := Vector2(SLIDE_HEAD.x,SLIDE_HEAD.z)
	var side := Vector2(-SLIDE_WAY.y,SLIDE_WAY.x)
	var halves := SLIDE_HALF.duplicate()
	halves.reverse()
	for h: Vector2 in halves: out.append(head+SLIDE_WAY*h.x-side*h.y)
	out.append(head-SLIDE_WAY*SLIDE_LODGE)
	for h: Vector2 in SLIDE_HALF: out.append(head+SLIDE_WAY*h.x+side*h.y)
	for w: Vector2 in [Vector2(12.0,2.5),Vector2(9.0,5.5),Vector2(7.5,7.4),Vector2(4.5,7.6),Vector2(-2.0,6.4),
			Vector2(-9.0,5.8),Vector2(-12.8,2.0)]:
		out.append(TILT_AT+w)
	return out
## The finer grid over the tongue, so its steep reads and rides as drawn.
static func slide_fine_box() -> Rect2:
	return Rect2(Vector2(62.0,-66.0),Vector2(19.0,14.0))
## The slide's three points (the top line): the head (the lodge's west
## edge), the break, the foot where it meets the tilt rock's own turf.
static func slide_points() -> Array:
	var way := Vector3(SLIDE_WAY.x,0.0,SLIDE_WAY.y)
	var steep_run := SLIDE_BREAK/tan(deg_to_rad(SLIDE_STEEP))
	var head := SLIDE_HEAD+way*SLIDE_LIP
	var brk := head+way*steep_run-Vector3(0.0,SLIDE_BREAK,0.0)
	var s := SLIDE_LIP+steep_run
	var foot := brk
	while s < 30.0:
		foot = SLIDE_HEAD+way*s
		if slide_line(s) <= tilt_plain(foot.x): break
		s += 0.1
	foot.y = tilt_plain(foot.x)
	return [head,brk,foot]
## The footbridge off the tilt rock's south edge to the north balcony.
static func tilt_bridge_ends() -> Array:
	var bal := on_slab("balcony")
	var a := Vector2(62.5,-47.0)
	return [Vector3(a.x,tilt_ground(a.x,a.y),a.y),Vector3(bal.x,bal.y,bal.z-1.9)]
## The lancet wall at the tilt rock's west end (facing east, along z), the
## chest before it, part spot 15 beside the chest.
static func tilt_wall_foot() -> Vector3:
	return Vector3(47.0,tilt_plain(47.0),TILT_AT.y)
static func tilt_chest_foot() -> Vector3:
	return Vector3(50.2,tilt_plain(50.2),TILT_AT.y-1.6)
static func tilt_spot() -> Vector3:
	return Vector3(50.0,tilt_plain(50.0),TILT_AT.y+1.4)

## A fallen entablature laid from `a` to `e` (its top's middle line, in
## `b`'s frame), `size` (across, deep): a cornice whose top is the walked
## face, dentils under it, a frieze of triglyphs and plain metopes, two
## fasciae of architrave at the bottom, each band in stones of random
## length broken short at the ends. It collides as the clean walk box
## Spine._beam's was (only the cornice's lip stands 0.1 m past its sides,
## drawn), so the surf and the stance are as before.
static func _entablature(b: RuinKit.Build, a: Vector3, e: Vector3, size: Vector2) -> void:
	var way := e-a
	var length := way.length()
	var x := way/length
	var z := x.cross(Vector3.UP).normalized()
	var y := z.cross(x).normalized()
	var pose := Transform3D(Basis(x,y,z),(a+e)*0.5-y*size.y*0.5)
	var hl := length*0.5
	var hh := size.y*0.5
	var hw := size.x*0.5
	var cornice := 0.28
	var arch := 0.34
	var over := 0.1
	b.lean = true
	# The core: the metopes' plane, set back behind the bands.
	b.solid(RuinKit._box(b,Vector3(hl-0.02,hh-cornice*0.5-0.01,hw-0.26)),pose*Transform3D(Basis.IDENTITY,Vector3(0.0,-cornice*0.5,0.0)),RuinKit._stone(b,0.78),false)
	# The cornice: whole stones across, their tops the walk box's top,
	# standing `over` out past its sides (drawn only).
	_ent_run(b,pose,-hl,hl,hh-cornice,hh,0.0,hw+over,1.1,0.12,true)
	for side: float in [-1.0,1.0]:
		# Fasciae, stepping out going up.
		_ent_run(b,pose,-hl,hl,-hh,-hh+arch*0.45,side,hw-0.16,0.95,0.35)
		_ent_run(b,pose,-hl,hl,-hh+arch*0.45,-hh+arch,side,hw-0.08,1.05,0.3)
		# Triglyphs: three bars each, standing out of the metopes.
		var t := -hl+0.5+b.rng.randf_range(0.0,0.3)
		while t < hl-0.6:
			for k in 3:
				var c := Vector3(t+(k-1)*0.15,(-hh+arch+hh-cornice)*0.5,side*(hw-0.04-0.11))
				b.solid(RuinKit._box(b,Vector3(0.055,(hh-cornice-(-hh+arch))*0.5-0.02,0.11)),pose*Transform3D(Basis.IDENTITY,c),RuinKit._stone(b,1.15),false,false)
			t += 1.15
		# Dentils under the cornice's lip.
		var d := -hl+0.15
		while d < hl-0.15:
			if b.rng.randf() > 0.12:
				var c := Vector3(d,hh-cornice-0.07,side*(hw+0.02-0.08))
				b.solid(RuinKit._box(b,Vector3(0.06,0.07,0.08)),pose*Transform3D(Basis.IDENTITY,c),RuinKit._stone(b,1.12),false,false)
			d += 0.22
	b.lean = false
	RuinKit._walk_hull(b,pose,[Plane(Vector3.RIGHT,hl),Plane(Vector3.LEFT,hl),Plane(Vector3.UP,hh),Plane(Vector3.DOWN,hh),Plane(Vector3.BACK,hw),Plane(Vector3.FORWARD,hw)])

## One band of an entablature in `pose`'s frame: stones of random length
## from `x0` to `x1` (each end broken short by up to `jag`), from `y0` up
## to `y1`, their faces `out` from the middle on `side` (0: one stone
## across, `out` its half width), drawn only.
static func _ent_run(b: RuinKit.Build, pose: Transform3D, x0: float, x1: float, y0: float, y1: float, side: float, out: float, tone: float, jag: float, level := false) -> void:
	var x := x0+b.rng.randf_range(0.0,jag)
	var end := x1-b.rng.randf_range(0.0,jag)
	var deep := 0.3
	while x < end-0.05:
		var xe := minf(end,x+b.rng.randf_range(0.9,1.7))
		if end-xe < 0.4: xe = end
		var half := Vector3((xe-x)*0.5-0.006,(y1-y0)*0.5,out if side == 0.0 else deep*0.5)
		var c := Vector3((x+xe)*0.5,(y0+y1)*0.5,0.0 if side == 0.0 else side*(out-deep*0.5))
		var at := Transform3D(Basis.IDENTITY,c)
		if not level: at = RuinKit._jiggle(b,at,0.25)
		b.solid(RuinKit._box(b,half),pose*at,RuinKit._stone(b,tone),false)
		x = xe

## The knight's causeway (spec item 7): the rune knight's deck. A snapped
## stone causeway jutting west off the strip's west end over open sky, one
## deck CAUSEWAY_HALF either side of z STRIP_Z, its top level with the
## strip's turf, broken off at CAUSEWAY_TIP; a snapped pier stands on the
## broken tip and part spot 16 lies in its lee. The knight patrols the deck
## between the strip and the pier, so the spot is past him; nothing but sky
## either side and past the tip, so a knock-off (his or yours) is a fall.
## Its root runs CAUSEWAY_ROOT into the strip's turf so no seam opens.
const CAUSEWAY_HALF := 1.6
const CAUSEWAY_ROOT := 23.5
const CAUSEWAY_EDGE := 20.5
const CAUSEWAY_TIP := -4.0
const CAUSEWAY_THICK := 1.1
## The course under the deck: narrower, deeper, stopping short of the tip.
const CAUSEWAY_UNDER := Vector3(2.5,1.6,-1.5)
static func causeway_top() -> float:
	return STRIP_TOP+0.03
static func causeway_pier_foot() -> Vector3:
	return Vector3(CAUSEWAY_TIP+1.0,causeway_top(),STRIP_Z-0.6)
static func causeway_spot() -> Vector3:
	return Vector3(CAUSEWAY_TIP+2.6,causeway_top(),STRIP_Z+0.7)
## The causeway's stone: [layout name, node, world foot, yaw (deg)].
## Dressed as ruin (drawn only; it walks on the one clean deck box from
## CAUSEWAY_ROOT to CAUSEWAY_TIP, as before): coursed sides under a coping,
## the drawn deck stopping just inside the strip's rim (the 3 cm root that
## lay on the turf is gone; a coping stone lies fallen there instead), the
## under-course coursed too, the stumps of two lost piers hanging under it
## with their arches' springers, two short broken parapet runs by the tip's
## pier, and a jagged broken tip.
static func causeway_built() -> Array:
	var b := RuinKit.Build.new(651,0.35,"Causeway")
	var top := causeway_top()
	var h := CAUSEWAY_HALF
	var t := CAUSEWAY_THICK
	var u := CAUSEWAY_UNDER
	var root := CAUSEWAY_EDGE+0.7
	var tip := CAUSEWAY_TIP+0.5
	# The deck: its rubble core, then coursed faces both sides under a
	# coping, each course broken off ragged past the tip.
	b.solid(RuinKit._box(b,Vector3((root-tip)*0.5,t*0.5-0.01,h-FACE*2.0),0.02),Transform3D(Basis.IDENTITY,Vector3((root+tip)*0.5,-t*0.5,0.0)),RuinKit._stone(b,0.85),false)
	for side: float in [-1.0,1.0]:
		var basis := Basis(Vector3.UP,0.0 if side > 0.0 else PI)
		var pose := Transform3D(basis,Vector3(0.0,0.0,side*(h-FACE)))
		var x0 := -root if side < 0.0 else CAUSEWAY_TIP-0.3
		var x1 := -(CAUSEWAY_TIP-0.3) if side < 0.0 else root
		# Past the tip's last 1.6 m the courses step down raggedly.
		var jag := func(x: float) -> float:
			var d := x*side-(CAUSEWAY_TIP-0.3)
			if d > 1.6: return 0.0
			var cell := fposmod(sin(floorf(d/0.45)*12.9898+side*4.1)*43758.5,1.0)
			return -0.45*(1.0-d/1.6)-0.3*cell
		RuinKit._courses(b,pose,x0,x1,-t,jag,FACE,func(_y: float) -> Vector2: return Vector2(0.0,-1.0),COURSE,true)
		# The under-course's faces.
		var up := Transform3D(basis,Vector3(0.0,0.0,side*(u.x*0.5-FACE)))
		var ua := CAUSEWAY_TIP-u.z
		RuinKit._courses(b,up,-(CAUSEWAY_EDGE+1.0) if side < 0.0 else ua,-ua if side < 0.0 else CAUSEWAY_EDGE+1.0,-t-u.y,func(_x: float) -> float: return -t,FACE,func(_y: float) -> Vector2: return Vector2(0.0,-1.0),COURSE)
	b.solid(RuinKit._box(b,Vector3((CAUSEWAY_EDGE+1.0-CAUSEWAY_TIP+u.z)*0.5,u.y*0.5,u.x*0.5-FACE*2.0),0.02),Transform3D(Basis.IDENTITY,Vector3((CAUSEWAY_EDGE+1.0+CAUSEWAY_TIP-u.z)*0.5,-t-u.y*0.5,0.0)),RuinKit._stone(b,0.8),false)
	# The under-course's broken west end.
	_ashlar_face(b,Vector3.LEFT,u.x*0.5,-(CAUSEWAY_TIP-u.z),0.0,-t-u.y,-t-0.25,0.0,-0.4)
	# The lost piers' stumps and their arches' springers.
	for px: float in CAUSEWAY_PIERS:
		_causeway_pier(b,px,-t-u.y,u.x*0.5)
	# The coursed stones collide nothing (a coping's lip would catch the
	# knight's fall and give the wanderer a ledge); only the one deck box
	# below does (the parapets and fallen stone are a piece of their own).
	b.hulls.clear()
	b.hull_anchors.clear()
	# One clean deck box, root to tip, posed exactly as Spine._beam posed
	# it (its frame turned to run west): the knight's fall off a teeter
	# starts on the deck's top inside its footprint, and his fall ray
	# passing or meeting that top hangs on the last bit of float in it
	# (an identity pose here made him land and shatter at the lip).
	var a := Vector3(CAUSEWAY_ROOT,0.0,0.0)
	var e := Vector3(CAUSEWAY_TIP,0.0,0.0)
	var way := (e-a).normalized()
	var zx := way.cross(Vector3.UP).normalized()
	var yx := zx.cross(way).normalized()
	var half := Vector3((a-e).length()*0.5,t*0.5,h)
	RuinKit._walk_hull(b,Transform3D(Basis(way,yx,zx),(a+e)*0.5-yx*t*0.5),[Plane(Vector3.RIGHT,half.x),Plane(Vector3.LEFT,half.x),Plane(Vector3.UP,half.y),Plane(Vector3.DOWN,half.y),Plane(Vector3.BACK,half.z),Plane(Vector3.FORWARD,half.z)])
	var deck := b.finish()
	# The parapets and the fallen stone collide, in a piece of their own:
	# the deck's body stays its one box, as the knight's teeter fall needs
	# (a ray from his feet on the deck's top misses a lone box but met the
	# same box among other shapes in one body, and he shattered there).
	var pb := RuinKit.Build.new(653,0.35,"CausewayParapet")
	# Two short broken parapet runs on the deck's edges at the tip, either
	# side of the pier (none along the knight's patrol, where he's knocked
	# off: his fall would land on them).
	for run: Vector3 in CAUSEWAY_PARAPETS:
		var side := signf(run.z)
		var pp := Transform3D(Basis(Vector3.UP,0.0 if side > 0.0 else PI),Vector3(0.0,0.0,side*(h-PARAPET_D)))
		var ra := run.x if side > 0.0 else -run.y
		var re := run.y if side > 0.0 else -run.x
		RuinKit._courses(pb,pp,ra,re,0.0,RuinKit._ruin_line(pb,ra,re,0.25,absf(run.z),0.7,true),PARAPET_D,func(_y: float) -> Vector2: return Vector2(0.0,-1.0),0.36,true)
	# A coping stone fallen on the turf at the root, off the knight's line.
	_fallen(pb,Vector3(CAUSEWAY_EDGE+1.8,-0.03,-h-0.2))
	return [["knight/causeway",deck,Vector3(0.0,top,STRIP_Z),0.0],["knight/parapet",pb.finish(),Vector3(0.0,top,STRIP_Z),0.0]]

## The lost piers under the causeway (local x), and the arches they bore:
## their span (centre to centre) and the voussoirs' radial depth.
const CAUSEWAY_PIERS := [14.5,4.5]
const CAUSEWAY_SPAN := 10.0
const CAUSEWAY_RING := 0.55
## The parapet runs: (from x, to x, highest with its side's sign).
const CAUSEWAY_PARAPETS := [Vector3(-3.6,0.2,-0.75),Vector3(-3.8,-0.6,0.55)]

## One lost pier's stump hanging under the causeway's under-course (its
## bottom `y0`), snapped off ragged below, and the springers of the arches
## either side of it: a few voussoirs on the ring, then broken. Drawn only.
static func _causeway_pier(b: RuinKit.Build, px: float, y0: float, half_w: float) -> void:
	var pw := 0.85
	var r := CAUSEWAY_SPAN*0.5-pw
	var spring := y0-CAUSEWAY_RING-r*0.55
	var stump := spring-1.4-b.rng.randf_range(0.0,1.2)
	for side: float in [-1.0,1.0]:
		var p := Transform3D(Basis(Vector3.UP,0.0 if side > 0.0 else PI),Vector3(px,0.0,side*(half_w-FACE)))
		RuinKit._courses(b,p,-pw,pw,stump,func(_x: float) -> float: return y0,FACE,func(_y: float) -> Vector2: return Vector2(0.0,-1.0),COURSE)
	b.solid(RuinKit._box(b,Vector3(pw-0.02,(y0-stump)*0.5,half_w-FACE*2.0),0.02),Transform3D(Basis.IDENTITY,Vector3(px,(y0+stump)*0.5,0.0)),RuinKit._stone(b,0.8),false)
	# Its snapped bottom: a few stones hanging lower.
	for i in 3:
		var s := Vector3(b.rng.randf_range(0.25,0.45),b.rng.randf_range(0.2,0.35),b.rng.randf_range(0.3,0.6))
		var c := Vector3(px+b.rng.randf_range(-pw*0.6,pw*0.6),stump-s.y*0.8,b.rng.randf_range(-half_w*0.6,half_w*0.6))
		b.solid(RuinKit._box(b,s),RuinKit._settle(b,c,0.6),RuinKit._stone(b,0.95),false)
	# The springers: voussoirs round each arch from the pier's face.
	for dir: float in [-1.0,1.0]:
		var centre := Vector3(px+dir*(pw+r),spring,0.0)
		var n := 2+b.rng.randi_range(0,2)
		var step := deg_to_rad(12.0)
		for k in n:
			var ang := step*(k+0.5)
			var radial := Vector3(-dir*cos(ang),sin(ang),0.0)
			var c := centre+radial*(r+CAUSEWAY_RING*0.5)
			var xa := radial
			var ya := Vector3(0.0,0.0,1.0).cross(xa)*dir
			var basis := Basis(xa,ya.normalized(),xa.cross(ya.normalized()))
			var len := (r+CAUSEWAY_RING)*step*0.5-0.01
			b.solid(RuinKit._box(b,Vector3(CAUSEWAY_RING*0.5,len,half_w-0.05)),RuinKit._jiggle(b,Transform3D(basis,c),0.3),RuinKit._stone(b,1.04),false)
		# The spandrel over the springers, up to the under-course.
		var sw := r*(1.0-cos(step*n))*0.9+0.3
		var sy0 := spring+(r+CAUSEWAY_RING)*sin(step*n*0.6)
		b.solid(RuinKit._box(b,Vector3(sw*0.5,(y0-sy0)*0.5,half_w-FACE*2.0),0.02),Transform3D(Basis.IDENTITY,Vector3(px+dir*(pw+sw*0.5-0.05),(y0+sy0)*0.5,0.0)),RuinKit._stone(b,0.82),false)

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
## faces he catches and climbs, but smooth hulls that overhang all round:
## nothing to catch on the way up its flank)]. Each hangs its own rock
## under it (`hangs`), not KitLand's one cone.
static func lands() -> Array:
	return [
		["strip",strip_outline(),func(_x: float, _z: float) -> float: return STRIP_TOP,40.0,405,Rect2(),STRIP_TOP],
		["tower_rock",tower_rock_outline(),func(_x: float, _z: float) -> float: return TOWER_ROCK,74.0,407,Rect2(),TOWER_ROCK],
		["coast_rock",coast_rock_outline(),func(_x: float, _z: float) -> float: return COAST_TOP,COAST_DEEP,409,Rect2(),COAST_TOP,true],
		["rope_rock",rope_rock_outline(),func(_x: float, _z: float) -> float: return ROPE_TOP,44.0,411,Rect2(),ROPE_TOP,true],
		["tilt_rock",tilt_rock_outline(),tilt_ground,TILT_DEEP,413,Rect2(),TILT_LOW],
	]

## The rock each land hangs under its rim, so the cluster reads upright
## from afar (deep keels, each its own shape): rings of [drop under the
## rim, share of the ring kept toward its middle], top down, after the
## rim's two lip rings (KitLand's); `fangs`: the last ring's arcs each hang
## to their own point, [drop] each (one: a single keel), `spread` how far
## out from the middle toward their arcs they hang; `lean`: how far
## (x, z) the keel stands off the middle (the rings between lean with it);
## `follow`: drops from each rim point's own height (a slab's underside
## that tilts with its turf), else from the land's top.
##   strip       a deep blade under the runway, four fangs
##   tower_rock  the tower's root: a broad column hanging 60 m and more
##               under the podium, so the tower and its rock stand as one
##               upright stack at the east end
##   coast_rock  a tall stack, near-vertical then stepping in, leaning east
##   rope_rock   tiered: three overhanging steps down to two fangs (its top
##               6 m kept as before: the slide's lodge tucks under it)
##   tilt_rock   a thick dropped slab, its flat underside tilted with it
static func hangs() -> Dictionary:
	return {
		"strip":{"rings":[[5.0,0.95],[12.0,0.84],[20.0,0.66],[25.0,0.52]],"fangs":[34.0,40.0,30.0,37.0],"spread":0.55},
		"tower_rock":{"rings":[[6.0,0.95],[14.0,0.9],[26.0,0.84],[40.0,0.74],[52.0,0.6]],"fangs":[66.0,74.0,60.0],"spread":0.55,"lean":Vector2(-3.0,2.0)},
		"coast_rock":{"rings":[[5.0,0.9],[12.0,0.86],[13.0,0.64],[24.0,0.6],[25.0,0.4],[36.0,0.34]],"fangs":[COAST_DEEP],"lean":Vector2(4.0,-2.0)},
		"rope_rock":{"rings":[[3.7,0.79],[6.0,0.69],[7.0,0.56],[15.0,0.52],[16.0,0.38],[25.0,0.34],[26.0,0.22]],"fangs":[36.0,44.0],"spread":0.5,"lean":Vector2(-2.0,-3.0)},
		"tilt_rock":{"rings":[[4.5,0.97],[8.0,0.9],[9.5,0.62]],"fangs":[TILT_DEEP],"follow":true},
	}

## Land `spec` (a row of `lands`) built: a KitLand island (its turf), and
## under it its own hanging rock (`hangs`), its sides collided as drawn, or
## for a sheer land by overhanging hulls.
static func build_land(spec: Array) -> Node3D:
	var cliffs: Rect2 = spec[5]
	var d := {"outline":spec[1],"seed":int(spec[4]),"ground":spec[2],"top":float(spec[6]),
		"depth":float(spec[3]),"hang":true,"resample":[60.0,128,48],"tone":KitLook.turf(int(spec[4])),"cell":2.0,
		"collide_sides":true,"name":"wreck_cluster/"+str(spec[0])}
	if cliffs.size != Vector2.ZERO: d["cliffs"] = cliffs
	var sheer: bool = spec.size() > 7 and bool(spec[7])
	var hang: Dictionary = hangs().get(str(spec[0]),{})
	if str(spec[0]) == "tilt_rock":
		d["fine_box"] = slide_fine_box()
		d["fine"] = 1.0
	if not hang.is_empty(): d["sides"] = false
	if sheer: d["collide_sides"] = false
	var node := KitLand.island(d)
	node.name = "Land_"+str(spec[0]).capitalize()
	if hang.is_empty():
		if sheer: node.add_child(sheer_hull(spec[1],float(spec[6]),float(spec[3])))
		return node
	var rings := hang_rings(d,hang)
	var drawn := hang_rock(rings,hang,int(spec[4])).node("Mesh")
	node.add_child(drawn)
	if sheer: node.add_child(hang_hulls(rings))
	else: KitLand.collide_sides(node,drawn,true)
	return node

## A land's hanging rings (world points), top down: the rim (the turf's own
## edge: KitLand's ring, resampled from the same seed), its two lip rings,
## then the profile's. Each ring a whole Array[Vector3], every point kept
## (the strides come in drawing). Returned with the rest the drawing
## needs: [rings, centre (x, z), the height the fangs hang from, lean,
## the deepest fang].
static func hang_rings(d: Dictionary, hang: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(d.seed)
	var resampling: Array = d.resample
	var outline: Array = d.outline
	var ring := KitLand.resample(outline,int(resampling[1]) if KitLand.perimeter(outline) > float(resampling[0]) else int(resampling[2]),rng)
	var centre := KitLand.centre_of(ring)
	var out := KitLand.outward(ring)
	var ground: Callable = d.ground
	var top: float = d.top
	var follow := bool(hang.get("follow",false))
	var lean: Vector2 = hang.get("lean",Vector2.ZERO)
	var deepest: float = (hang.fangs as Array).max()
	var rims: Array = []
	for p: Vector2 in ring: rims.append(float(ground.call(p.x,p.y)))
	var rows: Array = [[0.0,1.0,0.0],[0.45,1.0,0.28],[2.1,1.0,0.35]]
	for r: Array in hang.rings: rows.append([float(r[0]),float(r[1]),0.0])
	var rings: Array = []
	for row: Array in rows:
		var drop: float = row[0]
		var mid := centre+lean*(drop/deepest)
		var r: Array[Vector3] = []
		for i in ring.size():
			var p: Vector2 = ring[i]
			var q := mid+(p-centre)*float(row[1])+out[i]*float(row[2])
			var base: float = rims[i] if (follow or drop < 3.0) else minf(top,rims[i])
			r.append(Vector3(q.x,base-drop-(0.02 if drop == 0.0 else 0.0),q.y))
		rings.append(r)
	return [rings,centre,top if not follow else _mean(rims),lean,deepest]

static func _mean(v: Array) -> float:
	var t := 0.0
	for x: float in v: t += x
	return t/maxf(v.size(),1)

## The hanging rock drawn: the rings stitched (coarser down the keel), the
## last ring's arcs hung each to its own fang.
static func hang_rock(built: Array, hang: Dictionary, seed_value: int) -> KitLook.RockMesh:
	var rings: Array = built[0]
	var centre: Vector2 = built[1]
	var top: float = built[2]
	var lean: Vector2 = built[3]
	var deepest: float = built[4]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value*31+7
	var count: int = (rings[0] as Array).size()
	var rock := KitLook.RockMesh.new()
	var rim_y: float = (rings[0] as Array)[0].y
	# Every ring jittered a little (not the rim, which meets the turf).
	var drawn: Array = [rings[0]]
	var strides: Array[int] = [1]
	for k in range(1,rings.size()):
		var stride := 1 if k < 3 else mini(1 << ((k-1)/2),8)
		while stride > 1 and count/stride < 8: stride >>= 1
		var r: Array[Vector3] = []
		for i in range(0,count,stride):
			var p: Vector3 = rings[k][i]
			var c := Vector3(centre.x,p.y,centre.y)
			r.append(c+(p-c)*rng.randf_range(0.96,1.03)+Vector3.DOWN*rng.randf_range(-0.4,0.4)*float(k > 2))
		drawn.append(r)
		strides.append(stride)
	for k in range(drawn.size()-1):
		var upper: Array = drawn[k]
		var lower: Array = drawn[k+1]
		var su: int = strides[k]
		var sl: int = strides[k+1]
		for j in range(lower.size()):
			var l0: Vector3 = lower[j]
			var l1: Vector3 = lower[(j+1)%lower.size()]
			var u := j*sl
			var next := mini((j+1)*sl,count)
			while u < next:
				var u0: Vector3 = upper[u/su]
				var u1: Vector3 = upper[((u+su)%count)/su]
				_face(rock,[u0,l0,u1],rim_y,centre,rng)
				u += su
			_face(rock,[l0,l1,upper[(next%count)/su]],rim_y,centre,rng)
	# The fangs: the last ring cut in arcs, each fanned to its own point; a
	# crotch point under the ring's middle closes them.
	var last: Array = drawn[drawn.size()-1]
	var fangs: Array = hang.fangs
	var n := fangs.size()
	var low_y: float = 0.0
	for p: Vector3 in last: low_y += p.y
	low_y /= float(last.size())
	var crotch := Vector3(centre.x+lean.x,low_y-3.0,centre.y+lean.y)
	var m := last.size()
	for f in n:
		var a0 := f*m/n
		var a1 := (f+1)*m/n
		var mid := Vector3.ZERO
		for i in range(a0,a1+1): mid += last[i%m]
		mid /= float(a1-a0+1)
		var c := Vector3(centre.x,mid.y,centre.y)
		var tip := (c+(mid-c)*(float(hang.get("spread",0.35)) if n > 1 else 0.0))
		tip.x += lean.x*(1.0-float(n > 1)*0.5)+rng.randf_range(-1.0,1.0)
		tip.z += lean.y*(1.0-float(n > 1)*0.5)+rng.randf_range(-1.0,1.0)
		tip.y = top-float(fangs[f])
		for i in range(a0,a1):
			_face(rock,[last[i%m],tip,last[(i+1)%m]],rim_y,centre,rng)
		if n > 1:
			_face(rock,[last[a0%m],crotch,tip],rim_y,centre,rng)
			_face(rock,[last[a1%m],tip,crotch],rim_y,centre,rng)
	return rock

static func _face(rock: KitLook.RockMesh, tri: Array, rim_y: float, centre: Vector2, rng: RandomNumberGenerator) -> void:
	var m: Vector3 = (tri[0]+tri[1]+tri[2])/3.0
	var flat := Vector2(m.x-centre.x,m.z-centre.y).length()
	rock.add(tri,rim_y,m-Vector3(centre.x,m.y+flat*0.6,centre.y),rng.randf_range(0.88,1.1))

## A sheer land's flank as hulls: one convex hull between each two of its
## rings down to the fangs (the rim's pulled SHEER_IN in and SHEER_UNDER
## down, under the turf), each ring no wider than the one over it, so the
## stack overhangs everywhere and holds no lip to catch.
static func hang_hulls(built: Array) -> StaticBody3D:
	var rings: Array = built[0]
	var centre: Vector2 = built[1]
	var body := StaticBody3D.new()
	body.name = "SheerFlank"
	var prev := PackedVector3Array()
	for k in range(rings.size()):
		if k == 1 or k == 2: continue
		var ring := PackedVector3Array()
		var r: Array = rings[k]
		for i in range(0,r.size(),2):
			var p: Vector3 = r[i]
			if k == 0:
				var flat := Vector2(p.x-centre.x,p.z-centre.y)
				var q := Vector2(p.x,p.z)-flat.normalized()*SHEER_IN
				p = Vector3(q.x,p.y-SHEER_UNDER+0.02,q.y)
			ring.append(p)
		if not prev.is_empty():
			var shape := ConvexPolygonShape3D.new()
			shape.points = prev+ring
			var col := CollisionShape3D.new()
			col.shape = shape
			body.add_child(col)
		prev = ring
	return body

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
		["slide/wall","lancet_wall",643,0.35,tilt_wall_foot(),90.0],
		["slide/chest","tomb_chest",644,0.4,tilt_chest_foot(),0.0],
		["knight/pier","pier",652,0.12,causeway_pier_foot(),0.0],
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
	var hx := r.size.x*0.5
	var hz := r.size.y*0.5
	# The podium: an ashlar block, its faces laid in courses under a
	# chamfered coping, quoined corners, a string course, a plinth course
	# either side of the stairs; walked on one clean box (no lip).
	var b := RuinKit.Build.new(611,0.4,"Podium")
	var deep := PODIUM_H+PODIUM_DEEP
	for f: Array in [[Vector3.BACK,hx,hz,0.0],[Vector3.FORWARD,hx,hz,0.0],[Vector3.RIGHT,hz,hx,FACE*2.0],[Vector3.LEFT,hz,hx,FACE*2.0]]:
		_ashlar_face(b,f[0],f[1],f[2],f[3],-PODIUM_H-1.5,0.0)
	_quoins(b,hx,hz,-PODIUM_H-1.5,0.0)
	for f: Array in [[Vector3.BACK,hx,hz],[Vector3.FORWARD,hx,hz],[Vector3.RIGHT,hz,hx],[Vector3.LEFT,hz,hx]]:
		_band(b,f[0],f[1],f[2],STRING_AT-PODIUM_H)
	var stair_half := RuinKit.STAIR_WIDTH*0.5+0.6
	for side: float in [-1.0,1.0]:
		var half_len := (hx-stair_half)*0.5
		RuinKit._plinth_course(b,Transform3D(Basis.IDENTITY,Vector3(side*(stair_half+half_len),-PODIUM_H-0.12,hz-FACE)),half_len-RuinKit.PLINTH_COURSE.y,FACE)
	b.hulls.clear()
	b.hull_anchors.clear()
	_core(b,Vector3(hx,deep*0.5,hz),Vector3(0.0,-deep*0.5,0.0))
	# A broken parapet along the east apron's edge, beside the shell (none
	# west, where the crest's lip jumps on; none by the belfry's stair).
	var shell_back := TOWER_AT.y-Tower.half_extents().y-c.y
	var par := Transform3D(Basis(Vector3.UP,PI*0.5),Vector3(hx-PARAPET_D,0.0,0.0))
	RuinKit._courses(b,par,-hz+0.3,-shell_back,0.0,RuinKit._ruin_line(b,-hz+0.3,-shell_back,0.3,PARAPET_H,0.6,true),PARAPET_D,func(_y: float) -> Vector2: return Vector2(0.0,-1.0),0.38,true)
	_fallen(b,Vector3(hx-1.6,0.0,hz*0.25))
	var podium := b.finish()
	# The skirt: three tiers (west, north, east) round the podium, a
	# retaining wall in courses down the cliff under a coping, walked on
	# clean boxes as before.
	var sk := RuinKit.Build.new(615,0.5,"Skirt")
	var sx := hx+SKIRT
	var sz := hz
	var tall := SKIRT_H+SKIRT_DEEP
	var south := sz-1.0
	# The facing goes 1.5 m under the turf; the core on down the cliff.
	var sunk := -SKIRT_H-1.5
	_ashlar_face(sk,Vector3.FORWARD,sx,sz+SKIRT,0.0,sunk,0.0)
	for side: float in [-1.0,1.0]:
		var n := Vector3(side,0.0,0.0)
		# The tier's outer face, along z from the north tier to its end.
		var mid := (south-sz-SKIRT)*0.5
		_ashlar_face(sk,n,(south+sz+SKIRT)*0.5,sx,FACE*2.0,sunk,0.0,mid*-side)
		# Its broken south end.
		_ashlar_face(sk,Vector3.BACK,SKIRT*0.5,south,0.0,sunk,0.0,side*(sx-SKIRT*0.5),-0.3)
	for corner: Vector3 in [Vector3(-sx,0.0,-sz-SKIRT),Vector3(sx,0.0,-sz-SKIRT)]:
		_quoin_stack(sk,corner,sunk,0.0)
	sk.hulls.clear()
	sk.hull_anchors.clear()
	# Coping stones fallen onto the tiers' tops.
	for at: Vector3 in [Vector3(-sx*0.45,0.0,-sz-SKIRT*0.5),Vector3(sx-SKIRT*0.5,0.0,south-2.6),Vector3(-sx+SKIRT*0.5,0.0,-sz*0.2)]:
		_fallen(sk,at)
	_core(sk,Vector3(sx,tall*0.5,SKIRT*0.5),Vector3(0.0,-tall*0.5,-sz-SKIRT*0.5))
	for side: float in [-1.0,1.0]:
		var len_z := south+sz
		_core(sk,Vector3(SKIRT*0.5,tall*0.5,len_z*0.5),Vector3(side*(sx-SKIRT*0.5),-tall*0.5,(south-sz)*0.5))
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

## The podium's and skirt's dressing: the facing's half depth (courses
## FACE*2 thick on a rubble core), its course height, the string course's
## height over the turf.
const FACE := 0.3
const COURSE := 0.5
const STRING_AT := 2.3
## The broken parapet on the podium's east edge: its highest and half depth.
const PARAPET_H := 1.0
const PARAPET_D := 0.25

## Coursed facing on the face of a block about the frame's origin whose
## outward normal is `n`, `off` out from the middle, along the face
## `half_len` either side of `shift` less `trim` at each end (where a
## crossing face takes the corner), from `y0` up to `y1` under a coping
## (`y1` lowered by `drop` for a worn end).
static func _ashlar_face(b: RuinKit.Build, n: Vector3, half_len: float, off: float, trim: float, y0: float, y1: float, shift := 0.0, drop := 0.0) -> void:
	var pose := Transform3D(Basis(Vector3.UP,atan2(n.x,n.z)),n*(off-FACE))
	pose.origin += Basis(Vector3.UP,atan2(n.x,n.z))*Vector3(shift,0.0,0.0)
	var x0 := -half_len+trim
	var x1 := half_len-trim
	var top := (func(_x: float) -> float: return y1+drop) if drop == 0.0 else RuinKit._ruin_line(b,x0,x1,y1+drop,y1,0.2)
	RuinKit._courses(b,pose,x0,x1,y0,top,FACE,func(_y: float) -> Vector2: return Vector2(0.0,-1.0),COURSE,true)

## Quoins up the four corners of a block `hx` by `hz` about the origin:
## long and short stones in turn, standing a hair proud of both faces.
static func _quoins(b: RuinKit.Build, hx: float, hz: float, y0: float, y1: float) -> void:
	for sx: float in [-1.0,1.0]:
		for sz: float in [-1.0,1.0]:
			_quoin_stack(b,Vector3(sx*hx,0.0,sz*hz),y0,y1)

## One corner's quoins at `c` (x, z: the corner; its signs say which way
## is out).
static func _quoin_stack(b: RuinKit.Build, c: Vector3, y0: float, y1: float) -> void:
	var sx := signf(c.x)
	var sz := signf(c.z)
	var y := y0
	var k := 0
	while y < y1-0.25:
		var h := minf(COURSE*1.1,y1-0.2-y)
		var along := Vector2(0.95,0.55) if k%2 == 0 else Vector2(0.55,0.95)
		var mid := Vector3(c.x-sx*(along.x*0.5-0.05),y+h*0.5,c.z-sz*(along.y*0.5-0.05))
		b.solid(RuinKit._box(b,Vector3(along.x*0.5,h*0.5-0.005,along.y*0.5)),RuinKit._settle(b,mid,0.4),RuinKit._stone(b,1.12))
		y += h
		k += 1

## A string course round the face whose outward normal is `n` at height
## `y`: a chamfered band standing out a little, in stones of random length.
static func _band(b: RuinKit.Build, n: Vector3, half_len: float, off: float, y: float) -> void:
	var basis := Basis(Vector3.UP,atan2(n.x,n.z))
	var x := -half_len
	while x < half_len-0.05:
		var x1 := minf(half_len,x+b.rng.randf_range(1.0,1.8))
		if half_len-x1 < 0.4: x1 = half_len
		var half := Vector3((x1-x)*0.5-0.005,0.13,0.2)
		var planes := RuinKit._box(b,half)
		var cn := Vector3(0.0,-1.0,1.3).normalized()
		planes.append(Plane(cn,cn.dot(Vector3(0.0,-half.y+0.08,half.z))))
		var at := basis*Vector3((x+x1)*0.5,0.0,off-0.08)+Vector3(0.0,y,0.0)
		b.solid(planes,RuinKit._jiggle(b,Transform3D(basis,at),0.3),RuinKit._stone(b,1.08))
		x = x1

## A coping stone fallen onto a block's top at `at`: lying askew, a
## corner sunk, walked over (a low step).
static func _fallen(b: RuinKit.Build, at: Vector3) -> void:
	var half := Vector3(b.rng.randf_range(0.45,0.7),0.14,0.32)
	var basis := Basis(Vector3.UP,b.rng.randf()*TAU)*Basis(Vector3.RIGHT,b.rng.randf_range(-0.12,0.12))
	b.solid(RuinKit._box(b,half),Transform3D(basis,at+Vector3(0.0,half.y-0.04,0.0)),RuinKit._stone(b,1.06))
	for i in range(2):
		var s := Vector3(b.rng.randf_range(0.12,0.22),b.rng.randf_range(0.07,0.12),b.rng.randf_range(0.1,0.2))
		var a := b.rng.randf()*TAU
		var off := Vector3(cos(a),0.0,sin(a))*b.rng.randf_range(0.8,1.3)
		b.solid(RuinKit._box(b,s),Transform3D(Basis(Vector3.UP,a),at+off+Vector3(0.0,s.y*0.8,0.0)),RuinKit._stone(b),false)

## A block's rubble core (drawn, not collided, set in behind its facing)
## and its clean walk box (the block's full size: no lip, no gaps).
static func _core(b: RuinKit.Build, half: Vector3, mid: Vector3) -> void:
	var pose := Transform3D(Basis.IDENTITY,mid)
	var inner := half-Vector3(FACE,0.02,FACE)
	b.solid(RuinKit._box(b,inner,0.02),pose,RuinKit._stone(b,0.8),false,false)
	RuinKit._walk_hull(b,pose,[Plane(Vector3.RIGHT,half.x),Plane(Vector3.LEFT,half.x),Plane(Vector3.UP,half.y),Plane(Vector3.DOWN,half.y),Plane(Vector3.BACK,half.z),Plane(Vector3.FORWARD,half.z)])

# --- The south flank walk ----------------------------------------------------------

## A second layer along the spine's south flank (spec change 2): the
## builders' lower terrace walk, broken into stretches of stone deck set
## against the flank's rock, each a little higher going west, from the
## south bench's west end up under the crest to the pulpit. Between the
## stretches the walk is lost: a gap to jump and a step up (a hop or a
## jump and a grab, each under GRAB_TOP); at its west end a broken stair
## of fallen blocks climbs the flank onto the pulpit (part spot 02, no
## longer only dropped onto). A pier fallen from the colonnade lies from
## the strip's north edge up onto the second stretch, so the walk is
## reached from the strip too (a loop: strip, fallen pier, walk, bench,
## footbridge). Part spot 17 on the fourth stretch.
## The stretches: [layout name, axis x east end, x west end, deck top
## (world y)]. Each is FLANK_S_W wide out from where the flank's rock
## (its facets too) last stands over its top (`flank_s_out`), so its whole
## width is clear and the rock rises behind it as a wall, and runs
## FLANK_S_BURY further into the rock. The breaks between them are filled
## by fallen blocks (FLANK_S_RUBBLE: [gap, its top over the lower
## stretch's]), so nothing opens onto the flank's rock under the walk,
## whose facets hold a fallen walker in pockets far from anything: the
## first two halfway up (a hop up and a hop up again), the last two sunk
## (a step down, then a jump and a grab, 1.6 m, up the next stretch's worn
## end).
const FLANK_S := [
	["flank_s/walk_1",98.5,86.0,33.2],
	["flank_s/walk_2",84.3,72.0,34.4],
	["flank_s/walk_3",70.4,60.5,35.8],
	["flank_s/walk_4",58.4,52.6,36.9],
	["flank_s/walk_5",50.4,43.0,38.0],
]
const FLANK_S_RUBBLE := [[0,0.6],[1,0.7],[2,-0.5],[3,-0.5]]
const FLANK_S_W := 2.6
const FLANK_S_BURY := 1.6
## The broken stair up to the pulpit, west from walk_5's end: [x east end,
## x west end, top, outer edge d], each block a hop or a jump over the last.
const FLANK_S_STAIR := [
	[42.6,41.0,39.4,14.0],
	[40.8,39.4,40.8,13.6],
	[39.2,37.9,42.0,13.2],
	[37.7,36.4,43.2,12.8],
	[36.3,35.2,44.3,12.6],
]
## The fallen pier: its foot on the strip's turf (world x, z; just in from
## its north rim, outside the runway's clear band, STRIP_HALF), its head on
## walk_2's outer edge at axis x FLANK_S_PIER_HEAD; its section (wide, deep).
const FLANK_S_PIER_FOOT := Vector2(75.5,10.4)
const FLANK_S_PIER_HEAD := 79.0
const FLANK_S_PIER := Vector2(1.4,1.0)

## Stretch `i`'s outer edge (d, m south of the axis): FLANK_S_W out from
## the last place along it where the spine's ground stands over its top
## (sampled every 0.5 m along and 0.1 m across, past the bench's edge).
static func flank_s_out(i: int) -> float:
	var s: Array = FLANK_S[i]
	return _flank_out(float(s[1]),float(s[2]),float(s[3]))

static func _flank_out(x0: float, x1: float, top: float) -> float:
	var inner := 8.0
	var x := minf(x0,x1)
	while x <= maxf(x0,x1)+0.01:
		var d := 30.0
		while d > 6.0:
			var q := Spine.at(x,d)
			if Spine.ground(q.x,q.y) > top-0.05: break
			d -= 0.1
		inner = maxf(inner,d+0.1)
		x += 0.5
	return inner+FLANK_S_W

## The yaw (deg) that turns a piece's +x east along the axis at `x`.
static func axis_yaw(x: float) -> float:
	var t := Spine.along(x)
	return rad_to_deg(atan2(-t.z,t.x))

## A point on stretch `i` of the south walk: `along` (0 east end .. 1 west
## end), `inset` m in from its outer edge (world, on its top).
static func flank_s_point(i: int, along := 0.5, inset := 1.3) -> Vector3:
	var s: Array = FLANK_S[i]
	var x := lerpf(float(s[1]),float(s[2]),along)
	var q := Spine.at(x,flank_s_out(i)-inset)
	return Vector3(q.x,float(s[3]),q.y)

## The walk's stone: [layout name, node, world foot, yaw (deg)]: each
## stretch and each stair block its own deck block (`_flank_block`), the
## fallen pier a beam from the strip's turf onto walk_2.
static func flank_s_built() -> Array:
	var out: Array = []
	var k := 0
	for s: Array in FLANK_S:
		out.append(_flank_piece(str(s[0]),float(s[1]),float(s[2]),float(s[3]),flank_s_out(k),FLANK_S_W,661+k))
		k += 1
	# The fallen blocks filling the breaks, end to end with the stretches
	# either side (their worn ends show over and under them).
	for rub: Array in FLANK_S_RUBBLE:
		var g := int(rub[0])
		var a: Array = FLANK_S[g]
		var e: Array = FLANK_S[g+1]
		var top := minf(float(a[3]),float(e[3]))+float(rub[1])
		var ra := float(a[2])+0.05
		var re := float(e[1])-0.05
		out.append(_flank_piece("flank_s/rubble_%d" % (g+1),ra,re,top,maxf(_flank_out(ra,re,top),minf(flank_s_out(g),flank_s_out(g+1))),FLANK_S_W,676+g))
	k = 0
	for s: Array in FLANK_S_STAIR:
		k += 1
		out.append(_flank_piece("flank_s/stair_%d" % k,float(s[0]),float(s[1]),float(s[2]),float(s[3]),2.4,671+k))
	var b := RuinKit.Build.new(681,0.35,"FallenPier")
	var w2: Array = FLANK_S[1]
	var head2 := Spine.at(FLANK_S_PIER_HEAD,flank_s_out(1)-0.5)
	var foot := Vector3(FLANK_S_PIER_FOOT.x,STRIP_TOP-0.05,FLANK_S_PIER_FOOT.y)
	var head := Vector3(head2.x,float(w2[3]),head2.y)
	Spine._beam(b,foot-foot,head-foot,FLANK_S_PIER)
	out.append(["flank_s/fallen_pier",b.finish(),foot,0.0])
	return out

## One stretch or stair block placed: its axis x from `x0` to `x1`, top
## `top`, its outer edge `d_out` across, `wide` walkable inside it and
## FLANK_S_BURY more into the rock; as deep as reaches the flank's rock
## under its outer edge (1.5 to 7 m).
static func _flank_piece(called: String, x0: float, x1: float, top: float, d_out: float, wide: float, seed_value: int) -> Array:
	var xm := (x0+x1)*0.5
	var out := wide+FLANK_S_BURY
	var edge := Spine.at(xm,d_out)
	var deep := clampf(top-Spine.ground(edge.x,edge.y)+1.0,1.5,7.0)
	var b := RuinKit.Build.new(seed_value,0.4,called.get_file().capitalize())
	_flank_block(b,absf(x0-x1),out,deep)
	var q := Spine.at(xm,d_out-out*0.5)
	return [called,b.finish(),Vector3(q.x,top,q.y),axis_yaw(xm)]

## One deck block in its own frame (+x east along the axis, +z out from
## the flank, its top's middle at the origin): `len` long, `out` from its
## inner (buried) face to its outer edge, `deep` tall; coursed faces out
## and at both ends (the ends worn lower), quoins at its outer corners,
## walked on one clean box (no lip).
static func _flank_block(b: RuinKit.Build, len: float, out: float, deep: float) -> void:
	var hx := len*0.5
	var hz := out*0.5
	_ashlar_face(b,Vector3.BACK,hx,hz,0.0,-deep,0.0)
	for n: Vector3 in [Vector3.RIGHT,Vector3.LEFT]:
		_ashlar_face(b,n,hz,hx,FACE*2.0,-deep,0.0,0.0,-0.3)
	for sx: float in [-1.0,1.0]:
		_quoin_stack(b,Vector3(sx*hx,0.0,hz),-deep,-0.3)
	b.hulls.clear()
	b.hull_anchors.clear()
	_core(b,Vector3(hx,deep*0.5,hz),Vector3(0.0,-deep*0.5,0.0))

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
		["head","the pulpit off the podium (dropped onto, or up the south flank walk's stair)",on_slab("pulpit",Vector2(0.4,0.6)),["lying","salvager"]],
		["way","under the first portal's arch",on_spine(float(Spine.LINES[2][0]),0.0),["lying","jammed"]],
		["way","on the north balcony",on_slab("balcony",Vector2(-0.3,-0.4)),["lying","salvager"]],
		["way","under the second portal's arch",on_spine(float(Spine.LINES[5][0]),1.2),["lying","jammed"]],
		["bench","the top slab of the south three",on_slab("south_3"),["lying","jammed"]],
		["bench","the bench's east end by the tail",Spine.bench_point(140.0),["lying","cache"]],
		["tail","the tower rock's south-east lobe, where the tail fell (the coast down's way on)",on_lobe(Vector2(0.5,-0.5)),["lying","islet","cache"]],
		["tower","the tower rock under the belfry's north face",Vector3(UNDER_BELFRY.x,TOWER_ROCK,UNDER_BELFRY.y),["lying","cache"]],
		["bench","the strip's lobe by the footbridge's foot, under the bench",Vector3(STRIP_LOBE_SPOT.x,STRIP_TOP,STRIP_LOBE_SPOT.y),["lying","water"]],
		["tower","the tower top, on the east wall's head by the lookout",east_head(1.4),["lying","salvager"]],
		["tower","the belfry's wall head, over the bell (partway up)",belfry_south_head(-1.4),["lying","jammed"]],
		["coast","under the coast rock's arch (the coast down's end)",coast_arch_foot(),["lying","islet","salvager"]],
		["ropes","under the rope rock's chapel arch (the rope chain's end)",rope_arch_foot(),["lying","islet","salvager"]],
		["slide","by the carved chest under the tilt rock's lancet wall (the slide's end)",tilt_spot(),["lying","islet","cache"]],
		["knight","on the snapped causeway's tip, in the lee of its last pier (past the knight)",causeway_spot(),["lying","knight","cache"]],
		["flank","on the south flank walk's fourth stretch, against the crest's rock",flank_s_point(3,0.45,1.0),["lying","jammed"]],
	]

## The caches (spec item 10's change; studies/wreck_cluster_caches.gd): a
## breakable kit piece standing on a spot, which hides a part on the deals
## that pick it and breaks to nothing on the rest. [spot index (Art.spots
## order), RuinKit id, seed, yaw (deg), wear (its rubble skirt widens it:
## a pier 1.5 m across at 0, 5 m at 0.3)]. Named `wreck_cluster/cache_NN`
## (NN the spot's). Every one is CACHE_TOUGH: a slam off CACHE_DROP m or
## more (scripts/slam.gd: 0.25 + 0.75 (drop - 1.8) / 9.2) or a side slam
## (0.65) opens it; a hop's slam only flares its glint. Each has a height
## over it to slam from: the cella's walls (01, unchecked), the crest over
## the bench's end (07, unchecked), the coast down's sail off the coast
## rock (08, checked), a jump off the belfry's outer stair (09, checked).
const CACHES := [
	[0,"pier",731,15.0,0.3],
	[6,"buttress",732,90.0,0.3],
	[7,"wall",733,-20.0,0.15],
	[8,"pier",734,0.0,0.0],
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

## The knight's line (scripts/enemies/rune_knight.gd `setup`): the
## causeway, its local x running west from the strip's west rim
## (CAUSEWAY_EDGE) to the tip. His head end reaches back over the strip's
## turf, so a push back toward the strip leaves him standing.
static func knight_line() -> Dictionary:
	var xf := Transform3D(Basis(Vector3(-1.0,0.0,0.0),Vector3.UP,Vector3(0.0,0.0,-1.0)),Vector3(CAUSEWAY_EDGE,0.0,STRIP_Z))
	return {"xf":xf,"head":CAUSEWAY_EDGE-CAUSEWAY_ROOT,"snap":CAUSEWAY_EDGE-CAUSEWAY_TIP-0.8,"deck":causeway_top(),"half":CAUSEWAY_HALF}
