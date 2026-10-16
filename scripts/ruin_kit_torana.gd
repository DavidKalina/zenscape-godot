extends RefCounted
## The prayer lintel (round 2 card: docs/design/motifs/brainstorm/round2/
## kit-k1-grab-climb.md, "The Prayer Lintel"), a relic kit piece by id
## (RuinKit TORANA_PIECES, `piece`), in the kit's stone (scripts/ruin_kit.gd
## Build): what is left of a colossal gate. One square jamb stands on the
## isle's lip, a column of shallow votive niches up its back (-X) face, each
## with a sill to stand on; its lintel, a long coursed beam of three
## corbelled tiers (the soffit narrowest, the top widest), snapped off the
## far jamb and settled tilted against this one's head, rises out along +X
## over the drop, its far end broken. Prayer ropes hang from iron arms out
## of stone posts on its top's front (+Z) edge, a tag beside each.
##
## The ropes are not built here: the piece carries them as meta ("ropes",
## as city_court and gb_sunken_giant pass theirs) and its host hangs them
## live (SwingRope, scripts/interactables/swing_rope.gd: scripts/kit_isle/
## motif_authored.gd `live` and `hang_ropes`, the motif editor's
## `hang_ropes`).
##
## Sizes (from the code, the card's names):
## - Rope 1 hangs over the turf a swing clear of the jamb, its knot at
##   SwingRope.KNOT over the foot (a run takes it, RUN_IN); each next one
##   SwingRope.LENGTH further out and SET_OFF higher (the lintel's slope:
##   TILT over SPACING, 16 deg), as long as the first (`tilt` over SET_OFF
##   shortens each by the difference, never under half LENGTH): the arc
##   under MOST carries his hands to about 0.15 m short of the next one.
## - Code over card: the ropes hang beside the beam (ROPE_Z out, past the
##   top tier's face by a body and more: the swing drifts in), from posts
##   on its top (RING_OVER over it), not from rings in its soffit: a
##   release peaks about 1.4 m under its ring, so from the soffit no
##   release ever reaches the top. Let go rising on the backswing, he flies
##   back beside the beam over its lower top and comes down on it (steer
##   in); forward releases carry him rope to rope.
## - The slow way: offering steps against the head's back, SET_OFF high
##   and STEP deep each (a stair of set-offs, a niche in each riser), to
##   the head's top (JAMB_HEAD, the fourth set-off: ROOT_BACK deep behind
##   the beam's root, the pillar it butts against), then a drop onto the
##   beam's top at its root (one jump back up the head). Code over card: a
##   sill out of a face can't be climbed from the one under it (he stands
##   under it and jumps into it), so the niches sit in the risers.
## - Under the beam between the jamb and rope 1 the plane threads the gate:
##   meta "thread", RuinKit.THREAD wide (WorldScale.opening).
##
## Collision: clean boxes only. The jamb (its faces kickable), the steps
## (ledges with a top), the posts, the beam's three tiers (tilted, the top one
## walked: its edge the lip). The drawn stones' own hulls are dropped; the
## brackets, shims and tags are drawn only. The ropes collide only through
## their catch (FootPieces), never the plane.
## Meta: "ropes" [{anchor, length, dry, tag, bell}] (piece frame: anchor
## the rope's ring, tag the top middle of its cloth; bell on the last),
## "thread" AABB, "niches" [Vector3] (each step's lip, middle, bottom up),
## "jamb_top", "top" [root, end] (the beam top's middle at its root and
## near its broken end), "lintel" {x_root, x_end, tan, depth (vertical)}.

const RuinKit = preload("res://scripts/ruin_kit.gd")
const Build = RuinKit.Build
const SwingRope = preload("res://scripts/interactables/swing_rope.gd")

## The relic pieces this file builds (RuinKit TORANA_PIECES).
const PIECES := ["relic_torana"]

## The jamb: width along X, depth across (Z); its top under the lintel,
## two set-offs up; its head (the back part, behind the lintel's root),
## four: the pillar the lintel butts against.
const JAMB := Vector2(2.0,1.9)
const JAMB_TOP := 2.0*RuinKit.SET_OFF
const JAMB_HEAD := 4.0*RuinKit.SET_OFF
## Its plinth course: height (stepped onto) and how far it stands out.
const PLINTH := Vector2(0.32,0.07)
## The offering steps against the head's back: each a treads' depth (STAND
## and a hand) out from the one over it and SET_OFF lower, a stair of
## set-offs (a sill out of a face can't be climbed from the one under it:
## he stands under it and jumps into it); half a hand narrower each side.
const STEP := RuinKit.STAND+0.12
const STEP_INSET := 0.15
## The niches, one in each step's riser and one in the head's back over
## the top step (a column of them up the back): the skin they are cut in
## (its depth, so a niche is that deep), their clear width and height, how
## far over the riser's foot.
const SKIN := 0.18
const NICHE := Vector2(0.7,0.95)
const NICHE_UP := 0.32
## The jamb's head: its depth along X behind the beam's root (its top
## stood on: STAND and more).
const ROOT_BACK := 1.0
## The beam's tiers across its slope: [bottom, top (m over the soffit,
## square to it), half width], the soffit tier narrowest.
const TIERS := [[0.0,0.5,0.65],[0.5,1.0,0.8],[1.0,1.45,0.95]]
## Each rope's prayer post: a stone set on the beam's top at its front
## edge (across, up over the top, along), an iron arm out of its head
## carrying the ring RING_DOWN under the arm. A release peaks about 1.4 m
## under its ring, so the post stands the ring that much over the top and
## more: a backswing release comes down on the lower top behind with room.
const POST := Vector3(0.3,1.0,0.3)
const RING_DOWN := 0.12
## The ring's height over the beam's top under it.
const RING_OVER := POST.y-RING_DOWN
## The ropes' spacing along X and how much each ring rises over the last.
const SPACING := SwingRope.LENGTH
const TILT := RuinKit.SET_OFF
## The ropes' line out past the top tier's face: a body and a hand, so he
## rises past the face clear of it.
static var ROPE_Z: float = float(TIERS[2][2])+RuinKit.BODY+0.35
## How far the beam reaches past the last rope (to its snapped end).
const END_PAST := 1.2
## Ropes, least and most; the default.
const ROPES := Vector3i(3,5,4)
## How dark the soffit's underside and the niches are at their deepest.
const SOOT := 0.55
const IRON := Color("2c2a28")

## The piece with PIECES id `id`: the card's defaults (4 ropes, a dry one
## from weathered 0.5).
static func piece(id: String, seed_value: int, weathered := 0.0) -> Node3D:
	match id:
		"relic_torana": return torana(seed_value,weathered)
	return null

## The beam's numbers: its slope (tan), the root's x, rope 1's x, the soffit
## at x (a Callable), the beam's vertical depth.
static func lines(ropes := ROPES.z) -> Dictionary:
	var t := TILT/SPACING
	var x_root := -JAMB.x*0.5+ROOT_BACK
	var anchor1 := SwingRope.KNOT+SwingRope.LENGTH
	var depth := float(TIERS[2][1])/cos(atan(t))
	var x1 := x_root+(anchor1-RING_OVER-depth-JAMB_TOP)/t
	var x_last := x1+SPACING*(ropes-1)
	var x_end := x_last+END_PAST
	return {"tan":t,"x_root":x_root,"x1":x1,"x_last":x_last,"x_end":x_end,"depth":depth,"anchor1":anchor1}

## The offering steps: [x of the riser's face, top] from the head out
## (the top step first).
static func steps() -> Array:
	var out: Array = []
	var n := int(round(JAMB_HEAD/RuinKit.SET_OFF))-1
	for j in range(n): out.append([-JAMB.x*0.5-STEP*(j+1),RuinKit.SET_OFF*(n-j)])
	return out

static func soffit(L: Dictionary, x: float) -> float:
	return JAMB_TOP+(x-float(L.x_root))*float(L.tan)

## The prayer lintel (see the header). `ropes` 3 to 5; `tilt` how much each
## rope's knot rises over the last (SET_OFF: the ropes all LENGTH long; more
## shortens each one after the first, never under half LENGTH); `dry` the
## index of a dry rope (snaps on the catch: a gap in the chain to twirl
## past), -1 by `weathered` (one in the middle from 0.5), -2 none.
static func torana(seed_value: int, weathered := 0.0, ropes := ROPES.z, tilt := TILT, dry := -1) -> Node3D:
	var b := Build.new(seed_value,weathered,"PrayerLintel")
	b.settle = 0.35
	ropes = clampi(ropes,ROPES.x,ROPES.y)
	var L := lines(ropes)
	var t: float = L.tan
	var theta := atan(t)
	var x_root: float = L.x_root
	var x_end: float = L.x_end
	var hx := JAMB.x*0.5
	var hz := JAMB.y*0.5
	var stairs := steps()
	# The niches' boxes: in each riser's skin, and the head's back over the
	# top step.
	var niches: Array[AABB] = []
	for j in range(stairs.size()):
		var foot: float = float(stairs[j+1][1]) if j+1 < stairs.size() else 0.0
		niches.append(AABB(Vector3(float(stairs[j][0])-0.05,foot+NICHE_UP,-NICHE.x*0.5),Vector3(SKIN+0.1,NICHE.y,NICHE.x)))
	niches.append(AABB(Vector3(-hx-0.05,float(stairs[0][1])+NICHE_UP,-NICHE.x*0.5),Vector3(SKIN+0.1,NICHE.y,NICHE.x)))
	# Shelter: the soffit's underside and the niches dark (vertex grime).
	b.shelter = func(mid: Vector3, n: Vector3) -> float:
		if mid.x > x_root-0.1 and absf(mid.z) < 1.1 and n.y < -0.3 and mid.y < soffit(L,mid.x)+0.15: return 0.85
		for box: AABB in niches:
			if box.grow(0.02).has_point(mid): return 0.9
		return 0.0
	var keep_hulls := b.hulls.size()
	# The jamb: a core coursed to its top, and over the back face a skin of
	# the niche's depth with the niches left open in it (so each is a
	# shallow recess). Coursed along Z (the pose turned: its x the piece's
	# z, its front the piece's -X).
	var turn := Basis(Vector3.UP,-PI*0.5)
	var top_line := func(_x: float) -> float: return JAMB_TOP
	var head_line := func(_x: float) -> float: return JAMB_HEAD
	var front_d := (hx-x_root)*0.5
	RuinKit._courses(b,Transform3D(turn,Vector3(hx-front_d,0.0,0.0)),-hz,hz,0.0,top_line,front_d,Callable(),0.62)
	var back_d := (x_root+hx-SKIN)*0.5
	RuinKit._courses(b,Transform3D(turn,Vector3(x_root-back_d,0.0,0.0)),-hz,hz,0.0,head_line,back_d,Callable(),0.62,true)
	# Each face with a niche: a core, and a skin of the niche's depth over
	# its face (x0 the face) with the niche open in it.
	var niched := func(x0: float, x1: float, top: float, half_w: float, box: AABB) -> void:
		var hole := func(y: float) -> Vector2:
			return Vector2(0.0,NICHE.x*0.5) if y > box.position.y and y < box.end.y else Vector2(0.0,-1.0)
		var line := func(_x: float) -> float: return top
		var core_d := (x1-x0-SKIN)*0.5
		if core_d > 0.05: RuinKit._courses(b,Transform3D(turn,Vector3(x1-core_d,0.0,0.0)),-half_w,half_w,0.0,line,core_d,Callable(),0.62)
		RuinKit._courses(b,Transform3D(turn,Vector3(x0+SKIN*0.5,0.0,0.0)),-half_w,half_w,0.0,line,SKIN*0.5,hole,0.62)
	niched.call(-hx,-hx,JAMB_HEAD,hz,niches[niches.size()-1])
	for j in range(stairs.size()):
		var x0: float = stairs[j][0]
		niched.call(x0,x0+STEP,float(stairs[j][1]),hz-STEP_INSET,niches[j])
	# The plinth course round its foot.
	for side in range(4):
		var along := side%2 == 0
		var half := Vector3(hx+PLINTH.y,PLINTH.x*0.5,0.12) if along else Vector3(0.12,PLINTH.x*0.5,hz+PLINTH.y)
		var at := Vector3(0.0,PLINTH.x*0.5,(hz+PLINTH.y-0.12)*(1.0 if side == 0 else -1.0)) if along else Vector3((hx+PLINTH.y-0.12)*(1.0 if side == 1 else -1.0),PLINTH.x*0.5,0.0)
		b.solid(RuinKit._box(b,half),RuinKit._jiggle(b,Transform3D(Basis.IDENTITY,at),0.2),RuinKit._stone(b,0.9),false,true)
	# The treads' lips, bottom up (meta).
	var niche_meta: Array = []
	for j in range(stairs.size()-1,-1,-1): niche_meta.append(Vector3(float(stairs[j][0]),float(stairs[j][1]),0.0))
	# Shims in the wedge between the jamb's level top and the tilted soffit.
	var gap := soffit(L,hx)-JAMB_TOP
	for i in range(2):
		var sx := lerpf(x_root+0.5,hx-0.15,float(i))
		var h := maxf(soffit(L,sx)-JAMB_TOP-0.02,0.06)
		if gap < 0.1: break
		b.solid(RuinKit._box(b,Vector3(0.18,h*0.5,b.rng.randf_range(0.35,0.6)),0.02),Transform3D(Basis.IDENTITY,Vector3(sx,JAMB_TOP+h*0.5,b.rng.randf_range(-0.3,0.3))),RuinKit._stone(b,0.8),false,true)
	# The beam: three tiers of long blocks along its slope, cut level with
	# the jamb's top at its root, ragged where it snapped.
	var beam := Transform3D(Basis(Vector3.BACK,theta),Vector3(x_root,JAMB_TOP,0.0))
	var root_cut := Plane(Vector3.LEFT,-x_root)
	var u_full := (x_end-x_root)/cos(theta)
	var tier_ends: Array[float] = []
	for tier: Array in TIERS:
		var y0: float = tier[0]
		var y1: float = tier[1]
		var hw: float = tier[2]
		var u_end := u_full+b.rng.randf_range(-0.7,0.25)
		tier_ends.append(u_end)
		var u := 0.0
		while u < u_end-0.05:
			# Joints broken tier to tier: every other tier's first block short.
			var first := u == 0.0 and tier_ends.size()%2 == 0
			var ub := minf(u+(b.rng.randf_range(0.7,1.2) if first else b.rng.randf_range(1.5,2.6)),u_end)
			if u_end-ub < 0.6: ub = u_end
			var ua := u
			var half := Vector3((ub-ua)*0.5-0.01,(y1-y0)*0.5-0.01,hw)
			var local := Transform3D(Basis.IDENTITY,Vector3((ua+ub)*0.5,(y0+y1)*0.5,0.0))
			var pose := RuinKit._jiggle(b,beam*local,0.25)
			var inv := pose.affine_inverse()
			var extra: Array[Plane] = []
			if ua < 0.6: extra.append(inv*root_cut)
			if ub >= u_end-0.01:
				# The snapped end: a ragged break across the block's far end.
				for j in range(2):
					var n := Vector3(1.0,b.rng.randf_range(-0.7,0.7),b.rng.randf_range(-0.6,0.6)).normalized()
					extra.append(Plane(n,n.dot(Vector3(half.x-b.rng.randf_range(0.0,0.35),0.0,0.0))))
			b.solid(RuinKit._box(b,half),pose,RuinKit._stone(b,1.0 if y0 > 0.0 else 0.94),false,true,extra,-1,1.0)
			u = ub
	# The drawn stones' own hulls out: the clean boxes stand for them.
	b.hulls.resize(keep_hulls)
	b.hull_anchors.resize(keep_hulls)
	# The far jamb's ruin: fallen blocks heaped at this one's foot, off the
	# plane's way (their own hulls kept).
	RuinKit._drift(b,Vector3(-0.4,0.0,-hz-0.7),0.8,2+int(weathered*4.0))
	RuinKit._rubble(b,hx+1.2,int(round(weathered*b.rng.randf_range(3.0,6.0))))
	# The clean boxes: the jamb, the steps, the beam's tiers.
	RuinKit._walk_hull(b,Transform3D.IDENTITY,[Plane(Vector3.RIGHT,hx),Plane(Vector3.LEFT,-x_root),Plane(Vector3.UP,JAMB_TOP),Plane(Vector3.DOWN,0.0),Plane(Vector3.BACK,hz),Plane(Vector3.FORWARD,hz)])
	RuinKit._walk_hull(b,Transform3D.IDENTITY,[Plane(Vector3.RIGHT,x_root),Plane(Vector3.LEFT,hx),Plane(Vector3.UP,JAMB_HEAD),Plane(Vector3.DOWN,0.0),Plane(Vector3.BACK,hz),Plane(Vector3.FORWARD,hz)])
	for st: Array in stairs:
		var x0: float = st[0]
		RuinKit._walk_hull(b,Transform3D.IDENTITY,[Plane(Vector3.LEFT,-x0),Plane(Vector3.RIGHT,x0+STEP),Plane(Vector3.UP,float(st[1])),Plane(Vector3.DOWN,0.0),Plane(Vector3.BACK,hz-STEP_INSET),Plane(Vector3.FORWARD,hz-STEP_INSET)])
	var beam_inv := beam.affine_inverse()
	for i in range(TIERS.size()):
		var tier: Array = TIERS[i]
		var hw: float = tier[2]
		RuinKit._walk_hull(b,beam,[Plane(Vector3.UP,float(tier[1])),Plane(Vector3.DOWN,-float(tier[0])),Plane(Vector3.BACK,hw),Plane(Vector3.FORWARD,hw),
			Plane(Vector3.LEFT,0.6),Plane(Vector3.RIGHT,float(tier_ends[i])-0.15),beam_inv*root_cut])
	# The ropes: each from an iron arm out of a prayer post's head (the post
	# a clean box), a tag beside each; a dry one in the middle as it
	# weathers.
	if dry == -1: dry = b.rng.randi_range(1,ropes-2) if weathered >= 0.5 and ropes >= 3 else -2
	var rope_meta: Array = []
	var top_hw: float = TIERS[2][2]
	for r in range(ropes):
		var x := float(L.x1)+SPACING*r
		var top := soffit(L,x)+float(L.depth)
		var ring := Vector3(x,top+RING_OVER,ROPE_Z)
		var length := clampf(SwingRope.LENGTH-(tilt-TILT)*r,SwingRope.LENGTH*0.5,SwingRope.LENGTH*1.5)
		var pz := top_hw-POST.x*0.5-0.02
		var low := top-0.3
		var head := top+POST.y
		var half := Vector3(POST.x*0.5,(head-low)*0.5,POST.z*0.5)
		b.solid(RuinKit._box(b,half,0.03),RuinKit._jiggle(b,Transform3D(Basis.IDENTITY,Vector3(x,(low+head)*0.5,pz)),0.1),RuinKit._stone(b,1.04),false,true)
		RuinKit._walk_hull(b,Transform3D.IDENTITY,[Plane(Vector3.RIGHT,x+half.x),Plane(Vector3.LEFT,-(x-half.x)),Plane(Vector3.UP,head),Plane(Vector3.DOWN,-low),Plane(Vector3.BACK,pz+half.z),Plane(Vector3.FORWARD,-(pz-half.z))])
		var arm := ROPE_Z-pz+0.06
		b.solid(RuinKit._box(b,Vector3(0.05,0.05,arm*0.5),0.01),Transform3D(Basis.IDENTITY,Vector3(x,head-0.08,pz+arm*0.5)),IRON,false,false,[],-1,1.0,false)
		b.solid(RuinKit._box(b,Vector3(0.04,0.06,0.04),0.01),Transform3D(Basis.IDENTITY,Vector3(x,head-0.08,ROPE_Z+0.03)),IRON,false,false,[],-1,1.0,false)
		rope_meta.append({"anchor":ring,"length":length,"dry":r == dry,"tag":Vector3(x+0.45,ring.y,ROPE_Z+0.05),"bell":r == ropes-1})
	# Growth hanging off the soffit between the ropes, ivy down the jamb.
	for r in range(ropes):
		var x := float(L.x1)+SPACING*(r-0.5)+b.rng.randf_range(-1.0,1.0)
		if x < x_root+0.3: continue
		b.hang(Vector3(x,0.0,b.rng.randf_range(-0.4,0.4)),b.rng.randf_range(0.6,1.6)*(0.5+weathered),true,soffit(L,x)-0.02)
	for i in range(int(1+weathered*3.0)):
		b.hang(Vector3(b.rng.randf_range(-hx+0.3,hx-0.3),0.0,-hz+0.1),b.rng.randf_range(0.8,2.0)*(0.5+weathered),true,JAMB_HEAD-0.1)
	# Soot under the soffit and in the niches (vertex grime).
	for face: Array in b.pending:
		if not (face[0] is PackedVector3Array) or not (face[2] is Color): continue
		var corners: PackedVector3Array = face[0]
		var m := Vector3.ZERO
		for q in corners: m += q
		m /= corners.size()
		var dark := float(b.shelter.call(m,face[1]))
		if dark <= 0.0: continue
		var c: Color = face[2]
		face[2] = c.darkened(SOOT*dark)
	var node := b.finish()
	var top_at := func(x: float) -> Vector3: return Vector3(x,soffit(L,x)+float(L.depth),0.0)
	node.set_meta("ropes",rope_meta)
	node.set_meta("thread",AABB(Vector3(hx+PLINTH.y,0.5,-3.0),Vector3(RuinKit.THREAD,soffit(L,hx)-0.6,6.0)))
	node.set_meta("niches",niche_meta)
	node.set_meta("jamb_top",JAMB_HEAD)
	node.set_meta("top",[top_at.call(x_root+0.5),top_at.call(x_end-1.0)])
	node.set_meta("lintel",{"x_root":x_root,"x_end":x_end,"tan":t,"depth":float(L.depth)})
	return node
