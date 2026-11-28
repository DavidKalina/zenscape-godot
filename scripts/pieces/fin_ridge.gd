extends RefCounted
## A greybox piece of land: a round grassy clearing split in two by a long,
## winding fin ridge (cliff sides, a grass top to land on, one waterfall),
## in a ring of forest. Centred on its own origin; the ridge runs along z
## (its south end at +z, its north end at -z), its spine bending in x.
##
## Pure functions of local (x, z) and the constants below: `height`,
## `normal`, `is_rock` and `trees` read no scene state, so a later round can
## stamp the piece into a map by calling them. studies/piece_fin_ridge.gd
## builds and flies it. Every size is a first guess, to retune here.

## The clearing: its flat floor's radius (m), and how far out the forest
## ring runs past it, rising FOREST_RISE m as it goes (a shallow bowl).
const CLEARING_R := 600.0
const FOREST_RUN := 320.0
const FOREST_RISE := 24.0
## The ridge: its length end to end along the spine, its width at the base
## and on top in the middle, and its height at its highest (the middle).
const RIDGE_LENGTH := 900.0
const BASE_WIDTH := 120.0
const TOP_WIDTH := 36.0
const PEAK_HEIGHT := 150.0
## How far the spine swings to each side (m) and in how many half-waves
## over the length (1.0: one gentle S; 2.0: four bends).
const BEND := 70.0
const BEND_WAVES := 1.0
## The cliff: its sheer face runs FACE_RUN m out from the top's edge (at the
## peak; less where the ridge is lower) down to TALUS_SHARE of the height,
## then a scree apron runs on out to the base's edge. The top is domed
## CROWN m over its edges. WOBBLE: how much the cliff lines wander (m).
const FACE_RUN := 9.0
const TALUS_SHARE := 0.28
const CROWN := 2.0
const WOBBLE := 4.0
## Steeper than this (the normal's y under it) is bare rock, not grass.
const ROCK_UP := 0.72
## The waterfall: where along the ridge (t, -1 the north end, 1 the south),
## on which side (+1 east, -1 west), how wide the bite where it falls sheer
## to the floor runs (m along the ridge), its face's run there (m), and the
## plunge pool at its foot (radius, depth, water level).
const FALL_T := -0.22
const FALL_SIDE := 1.0
const FALL_BITE := 34.0
const FALL_FACE_RUN := 4.0
const POOL_R := 22.0
const POOL_DEEP := 3.5
const POOL_Y := -1.0
## Tree counts: scattered over the clearing's west (left, flying north) and
## east halves, on the ridge's top, and in the forest ring round the
## clearing; and their heights (m).
const TREES_WEST := 90
const TREES_EAST := 35
const TREES_TOP := 10
const TREES_RING := 700
## The forest ring's canopy: a greybox mass of treetops CANOPY_H m over the
## floor, from a ragged edge EDGE_GAP m (give or take EDGE_RAGGED) past the
## clearing's rim, rising to full height over EDGE_RISE m; lumped by LUMP m.
const CANOPY_H := 18.0
const EDGE_GAP := 30.0
const EDGE_RAGGED := 18.0
const EDGE_RISE := 22.0
const LUMP := 3.0
const TREE_TALL := Vector2(12.0,22.0)
const TREE_SEED := 23

## Along the ridge: t in -1..1 from z (beyond 1, past its ends).
static func along(z: float) -> float:
	return z/(RIDGE_LENGTH*0.5)

## The spine's x at z.
static func spine_x(z: float) -> float:
	var t := clampf(along(z),-1.0,1.0)
	return BEND*sin(BEND_WAVES*PI*t)

## The spine's slope dx/dz at z.
static func spine_slope(z: float) -> float:
	var t := clampf(along(z),-1.0,1.0)
	return BEND*BEND_WAVES*PI*cos(BEND_WAVES*PI*t)/(RIDGE_LENGTH*0.5)

## The ridge's height over the floor along the spine at t (0 past the ends).
static func crest(t: float) -> float:
	if absf(t) >= 1.0: return 0.0
	return PEAK_HEIGHT*(0.5+0.5*cos(PI*t))

## The spine's point at t (y on the floor) and its horizontal unit normal
## toward `side` (+1 east).
static func spine_point(t: float) -> Vector3:
	var z := t*RIDGE_LENGTH*0.5
	return Vector3(spine_x(z),0.0,z)

static func side_normal(t: float, side: float) -> Vector3:
	var z := t*RIDGE_LENGTH*0.5
	return Vector3(1.0,0.0,-spine_slope(z)).normalized()*signf(side)

## The floor: the clearing flat (a faint roll), the forest ring rising
## round it, the plunge pool dug in.
static func floor_height(x: float, z: float) -> float:
	var r := Vector2(x,z).length()
	var h := 0.35*sin(x*0.011+0.7)*sin(z*0.013+1.9)+0.2*sin((x+z)*0.031)
	h += FOREST_RISE*smoothstep(CLEARING_R,CLEARING_R+FOREST_RUN,r)
	var pool := Vector2(x,z).distance_to(pool_centre())
	h -= POOL_DEEP*smoothstep(POOL_R,POOL_R*0.35,pool)
	return h

## The ridge's rise over the floor at (x, z).
static func ridge_height(x: float, z: float) -> float:
	var t := along(z)
	if absf(t) >= 1.0: return 0.0
	var top := crest(t)
	var full := top/PEAK_HEIGHT
	var off := x-spine_x(z)
	var side := 1.0 if off >= 0.0 else -1.0
	# The true distance from the spine, near enough for a gentle bend.
	var d := absf(off)/sqrt(1.0+pow(spine_slope(z),2.0))
	d += WOBBLE*(sin(z*0.047+side*1.3)+0.6*sin(z*0.121+side*2.9)+0.3*sin(z*0.29))*sqrt(full)
	var half_top := TOP_WIDTH*0.5*(0.55+0.45*sqrt(full))
	var half_base := BASE_WIDTH*0.5*(0.3+0.7*sqrt(full))
	var face := maxf(FACE_RUN*full,1.5)
	var talus := TALUS_SHARE
	# The waterfall's bite: the face falls sheer to the floor there.
	if side == signf(FALL_SIDE):
		var bite := smoothstep(FALL_BITE,FALL_BITE*0.4,absf(z-FALL_T*RIDGE_LENGTH*0.5))
		face = lerpf(face,FALL_FACE_RUN,bite)
		talus = lerpf(talus,0.0,bite)
		half_base = lerpf(half_base,half_top+face+2.0,bite)
	if d <= half_top:
		return top+CROWN*full*(1.0-pow(d/half_top,2.0))
	var s := d-half_top
	if s <= face:
		# The lip a little rounded, then sheer.
		var k := s/face
		return top*lerpf(1.0,talus,k*k*(3.0-2.0*k)*0.25+k*0.75)
	var run := maxf(half_base-half_top-face,0.5)
	var u := clampf((s-face)/run,0.0,1.0)
	return top*talus*pow(1.0-u,1.6)

## The land's height at local (x, z).
static func height(x: float, z: float) -> float:
	return floor_height(x,z)+ridge_height(x,z)

## The ground's normal at (x, z).
static func normal(x: float, z: float) -> Vector3:
	var e := 0.75
	return Vector3(height(x-e,z)-height(x+e,z),2.0*e,height(x,z-e)-height(x,z+e)).normalized()

## Bare rock (a cliff or its scree) at (x, z), else grass.
static func is_rock(x: float, z: float) -> bool:
	return normal(x,z).y < ROCK_UP

## The forest canopy's ragged inner edge (m from the middle) at angle `a`.
static func canopy_edge(a: float) -> float:
	return CLEARING_R+EDGE_GAP+EDGE_RAGGED*(0.6*sin(a*5.0+0.4)+0.4*sin(a*13.0+2.1)+0.25*sin(a*29.0))

## The forest canopy's rise over the floor at (x, z) (0 in the clearing).
static func canopy_rise(x: float, z: float) -> float:
	var r := Vector2(x,z).length()
	var edge := canopy_edge(atan2(z,x))
	if r <= edge: return 0.0
	var lump := LUMP*(sin(x*0.09+1.0)*sin(z*0.08)+0.5*sin(x*0.23-z*0.19))
	return smoothstep(edge,edge+EDGE_RISE,r)*(CANOPY_H+lump)

## The top of what is solid at (x, z): the land, or the forest's canopy
## over it (for the plane to skim and the camera to keep out of).
static func solid_height(x: float, z: float) -> float:
	return height(x,z)+canopy_rise(x,z)

## The waterfall's lip (on the ridge's top edge), its outward normal and
## the plunge pool's middle.
static func fall_lip() -> Vector3:
	var t := FALL_T
	var n := side_normal(t,FALL_SIDE)
	var base := spine_point(t)
	var top := crest(t)
	# Out from the spine to where the top's edge breaks into the face.
	var d := 0.0
	while d < BASE_WIDTH:
		var q := base+n*(d+0.5)
		if height(q.x,q.z) < top*0.97: break
		d += 0.5
	var p := base+n*d
	p.y = height(p.x,p.z)
	return p

static func pool_centre() -> Vector2:
	var t := FALL_T
	var n := side_normal(t,FALL_SIDE)
	var p := spine_point(t)+n*(TOP_WIDTH*0.5*(0.55+0.45*sqrt(crest(t)/PEAK_HEIGHT))+FALL_FACE_RUN+POOL_R*0.7)
	return Vector2(p.x,p.z)

## --- Stamped into a map (scripts/endless/land_pieces.gd) ---------------------
## Only the ridge and its plunge pool: the map's own ground and woods stand in
## for the clearing and the forest ring.

## The ridge's rise over the ground it stands on at local (x, z), the pool dug
## in at its foot; 0 off it, its foot eased to 0 (no step where it meets).
static func rise(x: float, z: float) -> float:
	var h := ridge_height(x,z)
	var pool := Vector2(x,z).distance_to(pool_centre())
	if pool < POOL_R: h -= POOL_DEEP*smoothstep(POOL_R,POOL_R*0.35,pool)
	return h

## The local box `rise` is 0 outside of.
static func reach() -> Rect2:
	var half := BEND+BASE_WIDTH*0.5+WOBBLE*2.0+4.0
	return Rect2(-half,-RIDGE_LENGTH*0.5,half*2.0,RIDGE_LENGTH)

## The dressing a map hangs on it (land_pieces.gd `dressing`): the waterfall,
## its lip's y over the ground, the pool's water over the ground at its middle.
static func dressing() -> Array:
	var lip := fall_lip()
	lip.y = ridge_height(lip.x,lip.z)
	return [{"kind": "waterfall", "lip": lip, "out": side_normal(FALL_T,FALL_SIDE), "pool": pool_centre(),
		"pool_y": POOL_Y, "pool_r": POOL_R}]

## Whether (x, z) is on the ridge's footprint (its rise over the floor).
static func on_ridge(x: float, z: float) -> bool:
	return ridge_height(x,z) > 0.5

## The trees: [{at: Vector3 (base on the ground), tall: m, where: "west",
## "east", "top" or "ring"}], the same every call. None on rock, in the
## pool, or on the ridge but on its top.
static func trees() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = TREE_SEED
	var out: Array = []
	var want := {"west": TREES_WEST, "east": TREES_EAST, "top": TREES_TOP, "ring": TREES_RING}
	for where: String in want:
		var placed := 0
		var tries := 0
		while placed < int(want[where]) and tries < int(want[where])*60:
			tries += 1
			var p := Vector2.ZERO
			match where:
				"west", "east":
					var a := rng.randf()*TAU
					p = Vector2(cos(a),sin(a))*sqrt(rng.randf())*(CLEARING_R-20.0)
					var east := p.x > spine_x(p.y)
					if east != (where == "east"): continue
					if on_ridge(p.x,p.y) or absf(p.x-spine_x(p.y)) < BASE_WIDTH*0.6: continue
				"top":
					var t := rng.randf_range(-0.55,0.55)
					var n := side_normal(t,1.0)
					p = Vector2(spine_point(t).x,spine_point(t).z)+Vector2(n.x,n.z)*rng.randf_range(-1.0,1.0)*TOP_WIDTH*0.3
				"ring":
					var a := rng.randf()*TAU
					# At the canopy's edge, poking out of it.
					p = Vector2(cos(a),sin(a))*(canopy_edge(a)+rng.randf_range(-20.0,EDGE_RISE))
			if p.distance_to(pool_centre()) < POOL_R+6.0: continue
			if where != "top" and on_ridge(p.x,p.y): continue
			if is_rock(p.x,p.y): continue
			var tall := rng.randf_range(TREE_TALL.x,TREE_TALL.y)*(0.7 if where == "top" else 1.0)
			out.append({"at": Vector3(p.x,height(p.x,p.y),p.y), "tall": tall, "where": where})
			placed += 1
	return out
