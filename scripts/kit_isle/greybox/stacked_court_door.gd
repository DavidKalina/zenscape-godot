extends RefCounted
## STAND-IN: the Stacked Court's well with a door (gb_stacked_court.gd). The
## city kit's drum stair has no door out of its core (city-kit-round1.md,
## Limits; the card's first kit ask), so the drum could only be a pit. This
## builds M (CityKit `pillar`, courses 0, a flat crown round a well) and its
## drum stair (CityKit `drum_stair`, rim false) as the kit does, the same
## planes, Piece, stone and walk areas, with one change: a tunnel cut
## through M's flank, the outer wall and turn 0, out to turn 1's outer
## edge, its floor turn 1's step there. Under turn 0 the tunnel has a
## ceiling of turn 0's own stone, so the turn above still runs whole over
## it. From the land outside you walk in at the drum's second turn and climb
## the coil up to M's rim (or drop to the core). It is walker-sized (his
## headroom is 7.5 m; this is DOOR_HEAD): the Keeper can't follow through it.
##
## When the kit grows a `door` opt (pillar and drum_stair), this goes and
## the motif calls the kit; the numbers it needs are `door` below.
const CityKit = preload("res://scripts/city_kit.gd")
const Stone = preload("res://scripts/city_kit_stone.gd")

const COURSE := CityKit.COURSE
## The tunnel's clear height and half its width (m).
const DOOR_HEAD := 3.6
const DOOR_HALF := 1.8

## The door, in M's frame (its crown y 0, the well's centre the origin): the
## tunnel's axis at `angle` (rad, CityKit `dir`: 0 toward +Z, then toward
## +X), its floor turn 1's step at that angle (one drum turn under turn 0's).
static func door(angle: float) -> Dictionary:
	var j := 24+int(floor(fposmod(angle,TAU)/(TAU/CityKit.DRUM_SEGMENTS)))
	var floor_y := -CityKit.RISER*floori(j*CityKit.DRUM_STEPS/float(CityKit.DRUM_SEGMENTS))
	return {"angle":angle,"half":DOOR_HALF,"floor":floor_y,"top":floor_y+DOOR_HEAD}

## The tunnel's axis (outward) and its side.
static func _axes(d: Dictionary) -> Array:
	var u := CityKit.dir(float(d.angle))
	return [u,Vector3(u.z,0.0,-u.x)]

## A convex block (`planes`) with the tunnel taken out: itself if the tunnel
## misses it, else what is under the floor, over the top, and either side.
static func split(planes: Array, d: Dictionary) -> Array:
	var ax := _axes(d)
	var u: Vector3 = ax[0]
	var t: Vector3 = ax[1]
	var hw := float(d.half)
	var lo := float(d.floor)
	var hi := float(d.top)
	var probe: Array = planes+[Plane(t,hw),Plane(-t,hw),Plane(-u,0.0)]+CityKit.slab(lo,hi)
	if _solid(probe).size() < 4: return [planes]
	var out: Array = []
	for extra: Array in [[Plane(Vector3.UP,lo)],[Plane(Vector3.DOWN,-hi)],
			CityKit.slab(lo,hi)+[Plane(t,-hw)],CityKit.slab(lo,hi)+[Plane(-t,-hw)]]:
		var p: Array = planes+extra
		if _solid(p).size() >= 4: out.append(p)
	return out

static func _solid(planes: Array) -> PackedVector3Array:
	var typed: Array[Plane] = []
	for p: Plane in planes: typed.append(p)
	return Geometry3D.compute_convex_mesh_points(typed)

## Within the tunnel's corridor (outward half), with `margin`.
static func in_door(p: Vector3, d: Dictionary, margin := 0.0) -> bool:
	var ax := _axes(d)
	return (ax[0] as Vector3).dot(p) > 0.0 and absf((ax[1] as Vector3).dot(p)) < float(d.half)+margin

## M: CityKit `pillar` with {apothem a, courses 0, climb -1, crown "flat",
## well, depth}, the door cut through its flank, a lintel and two jamb
## stones round the door's mouth.
static func well_pillar(seed_value: int, weathered: float, a: float, well: float, depth: float, d: Dictionary) -> Node3D:
	var b := CityKit.Piece.new("CityPillar",seed_value,weathered)
	var well_depth := CityKit.DRUM_TURNS*COURSE
	var sectors: Array = []
	for s in range(24):
		var a0 := TAU*s/24.0
		var a1 := TAU*(s+1)/24.0
		var cut: Array = CityKit.wedge(a0,a1)
		cut.append(CityKit.chord(CityKit.dir(a0)*well,CityKit.dir(a1)*well,true))
		sectors.append(cut)
	for cut: Array in sectors:
		for planes: Array in split(CityKit.hex_planes(a)+CityKit.slab(-depth,0.0)+cut,d):
			b.block(planes,false,null,0.5)
	# The glyph band under the crown.
	var half := a*tan(PI/6.0)*0.82
	for f in 6:
		var dd := CityKit.hex_dir(f)
		var tt := Vector3(dd.z,0.0,-dd.x)
		b.runes(dd*a+tt*half+Vector3.UP*-2.2,dd*a-tt*half+Vector3.UP*-2.2,Vector3.UP,dd)
	# The organ pipes (none across the door's mouth).
	for f in 6:
		var dd := CityKit.hex_dir(f)
		var tt := Vector3(dd.z,0.0,-dd.x)
		var hh := a*tan(PI/6.0)
		var x := -hh+1.2
		while x < hh-1.2:
			var r := b.rng.randf_range(1.0,2.2)
			var top := lerpf(-COURSE,-depth*0.55,pow(b.rng.randf(),1.5))
			var at := dd*(a+r*0.35)+tt*x
			if not (in_door(at,d,r+0.8) and top > float(d.floor)-1.0):
				var xf := Transform3D(Basis(Vector3.UP,TAU*f/6.0+PI/6.0),at+Vector3.UP*(-depth))
				b.block(Stone.drum(xf,6,r,r,top+depth,0.15),false,null,0.4)
			x += r*1.75
	# Collision: the sectors round the well (the door cut through), the
	# well's floor.
	for cut: Array in sectors:
		for planes: Array in split(CityKit.hex_planes(a)+CityKit.slab(-depth,0.0)+cut,d):
			var pts := _solid(planes)
			if pts.size() >= 4: b.hull(pts)
	b.hull(_solid(Stone.drum(Transform3D(Basis.IDENTITY,Vector3.UP*-depth),24,well,well,-well_depth+depth)))
	_door_frame(b,a,d)
	b.meta.ports["crown"] = CityKit.dir(0.0)*(a-well)*0.5+CityKit.dir(0.0)*well
	for f in 6:
		var corner := (CityKit.hex_dir(f)+CityKit.hex_dir(f+1)).normalized()*(a-3.0)/cos(PI/6.0)
		b.cresset(corner)
	b.meta.ports["well"] = well
	b.meta.ports["door"] = door_mouth(a,d)
	for f in 6:
		var c0 := (CityKit.hex_dir(f)+CityKit.hex_dir(f-1)).normalized()*a/cos(PI/6.0)
		var c1 := (CityKit.hex_dir(f)+CityKit.hex_dir(f+1)).normalized()*a/cos(PI/6.0)
		var poly: Array = [Vector2(c0.x,c0.z),Vector2(c1.x,c1.z)]
		var a1 := TAU*f/6.0+PI/6.0
		for k in range(9):
			var q := CityKit.dir(a1-PI/3.0*k/8.0)*well
			poly.append(Vector2(q.x,q.z))
		b.area("crown",poly,0.0)
	b.meta.his = {"walks":"the crown (its ring %.1f m round a well)" % (a-well),"climbs":"any flank to the crown","never":"through the door (%.1f m: under his headroom)" % DOOR_HEAD}
	b.root.set_meta("apothem",a)
	b.root.set_meta("courses",0)
	return b.finish()

## Where the door's axis leaves M's face (its floor's middle), M's frame.
static func door_mouth(a: float, d: Dictionary) -> Vector3:
	var ang := float(d.angle)
	var f := int(round(ang/(TAU/6.0)))%6
	var r := a/cos(ang-TAU*f/6.0)
	return CityKit.dir(ang)*r+Vector3.UP*float(d.floor)

## The door's frame on M's face: two jamb stones and a lintel carved with a
## glyph band, the makers' door (stone the walker can stand on; collided).
static func _door_frame(b: CityKit.Piece, a: float, d: Dictionary) -> void:
	var ang := float(d.angle)
	var f := int(round(ang/(TAU/6.0)))%6
	var n := CityKit.hex_dir(f)
	var side := Vector3(n.z,0.0,-n.x)
	var mouth := door_mouth(a,d)
	var along := side.dot(mouth)
	var hw := float(d.half)/cos(ang-TAU*f/6.0)
	var lo := float(d.floor)
	var hi := float(d.top)
	var basis := Basis(side,Vector3.UP,n)
	var out := 0.7
	for s: float in [-1.0,1.0]:
		var c := n*(a+out*0.5-0.2)+side*(along+s*(hw+0.7))+Vector3.UP*((lo+hi)*0.5+0.4)
		b.block(Stone.box(Transform3D(basis,c),Vector3(0.7,(hi-lo)*0.5+0.4,out*0.5+0.2),0.12),true,null,0.8)
	var lc := n*(a+out*0.5-0.1)+side*along+Vector3.UP*(hi+0.85)
	var lh := Vector3(hw+1.6,0.85,out*0.5+0.3)
	b.block(Stone.box(Transform3D(basis,lc),lh,0.15),true,null,0.8)
	var front := lc+n*(lh.z+0.01)
	b.runes(front-side*(hw+1.2),front+side*(hw+1.2),Vector3.UP,n,0.8)

## The drum stair in M's well: CityKit `drum_stair` (radius DRUM_RADIUS,
## turns DRUM_TURNS, lane LANE, rim false), the door's tunnel cut through
## turn 0 and its outer wall.
static func drum(seed_value: int, weathered: float, d: Dictionary) -> Node3D:
	var b := CityKit.Piece.new("CityDrumStair",seed_value,weathered)
	var w := CityKit.DRUM_RADIUS
	var turns := CityKit.DRUM_TURNS
	var lane := CityKit.LANE
	var per := CityKit.DRUM_SEGMENTS
	var segs := per*turns
	var bottom := -turns*COURSE
	var foot := bottom-CityKit.SET_OFF
	var r_out := func(th: float) -> float: return w-lane*th/TAU
	var top_of := func(j: int) -> float: return -CityKit.RISER*floori(j*CityKit.DRUM_STEPS/float(per))
	var path: Array = []
	for j in range(segs):
		var a0 := TAU*j/per
		var a1 := TAU*(j+1)/per
		var o0: float = r_out.call(a0)
		var o1: float = r_out.call(a1)
		var y: float = top_of.call(j)
		var wa0 := fposmod(a0,TAU)
		var wa1 := wa0+(a1-a0)
		var p: Array = CityKit.wedge(wa0,wa1)+CityKit.slab(foot,y)
		p.append(CityKit.chord(CityKit.dir(wa0)*o0,CityKit.dir(wa1)*o1,false))
		p.append(CityKit.chord(CityKit.dir(wa0)*(o0-lane),CityKit.dir(wa1)*(o1-lane),true))
		var pieces: Array = split(p,d) if j < per else [p]
		for planes: Array in pieces: b.block(planes,true,null,0.6,null,[CityKit.over(bottom)])
		path.append(CityKit.dir((wa0+wa1)*0.5)*((o0+o1)*0.5-lane*0.5)+Vector3.UP*y)
		if j+per < segs and j%2 == 0 and pieces.size() == 1:
			var i0 := CityKit.dir(wa0)*(o0-lane)
			var i1 := CityKit.dir(wa1)*(o1-lane)
			var nrm := -((i0+i1)*0.5).normalized()
			b.runes(i1+Vector3.UP*(y-COURSE*0.62),i0+Vector3.UP*(y-COURSE*0.62),Vector3.UP,nrm,0.7)
		if j < per and w-o1 > 0.3:
			var q: Array = CityKit.wedge(wa0,wa1)+CityKit.slab(foot,0.0)
			q.append(CityKit.chord(CityKit.dir(wa0)*w,CityKit.dir(wa1)*w,false))
			q.append(CityKit.chord(CityKit.dir(wa0)*o0,CityKit.dir(wa1)*o1,true))
			for planes: Array in split(q,d): b.block(planes,true,null,0.5,null,[CityKit.over(bottom)])
	var core: float = r_out.call(TAU*(turns-1))-lane
	b.block(Stone.drum(Transform3D(Basis.IDENTITY,Vector3.UP*foot),24,core/cos(PI/24.0),core/cos(PI/24.0),bottom-foot,0.05),true,null,0.2)
	b.cresset(CityKit.dir(PI)*core*0.45+Vector3.UP*bottom)
	for k in 4: b.cresset(CityKit.dir(TAU*k/4.0+PI/4.0)*(w+0.6))
	for j in range(segs):
		var a0 := TAU*j/per
		var a1 := TAU*(j+1)/per
		var o0: float = r_out.call(a0)
		var o1: float = r_out.call(a1)
		var pts: Array = []
		for q: Vector3 in [CityKit.dir(a0)*o0,CityKit.dir(a1)*o1,CityKit.dir(a1)*(o1-lane),CityKit.dir(a0)*(o0-lane)]: pts.append(Vector2(q.x,q.z))
		b.area("turn",pts,top_of.call(j))
	b.meta.ports["rim"] = CityKit.dir(0.0)*(w-lane*0.5)
	b.meta.ports["bottom"] = CityKit.dir(PI)*core*0.5+Vector3.UP*bottom
	b.meta.ports["path"] = path
	# Where the tunnel comes out on turn 1 (its floor, at the turn's middle).
	var u := CityKit.dir(float(d.angle))
	var th := TAU+fposmod(float(d.angle),TAU)
	b.meta.ports["door_in"] = u*(float(r_out.call(th))-lane*0.5)+Vector3.UP*float(d.floor)
	b.meta.his = {"walks":"every turn (%.1f m wide, %d steps a turn)" % [lane,CityKit.DRUM_STEPS],"drops":"a turn on purpose (%.1f m)" % COURSE,"headroom":"open sky over every turn; the door's tunnel %.1f m" % DOOR_HEAD}
	b.root.set_meta("radius",w)
	b.root.set_meta("turns",turns)
	return b.finish()
