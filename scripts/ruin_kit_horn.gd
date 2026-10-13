extends RefCounted
class_name RuinKitHorn
## The ruin kit's wind-horn (scripts/ruin_kit.gd, its Build and its stone): an
## ancient device of the ruin-builders', made to ward off the dragon and
## still blowing at anything that moves. A squat octagonal pedestal of
## courses, on it a turning head: a stout bellows chest with a flat stone
## cap, and out of its front (+Z) a flared horn of carved stone rings, each
## ring eight staves, the last with a lip, a staff or two broken off the
## lip where it is weathered. Old, heavy, ivied, centuries from working
## right; no ornament glows.
##
## The piece, as the kit's: a Node3D, foot on y 0 round the origin, "Mesh"
## and "Body" (the pedestal). On it:
##   "Head"  Node3D at the pedestal's top, the pivot: it yaws about its
##           own origin. Its own "Mesh", a "Body" (the chest's hull, the
##           standable top) and:
##   "Head/Barrel"  the horn itself on its trunnion at the chest's face
##           (AXIS up, PIVOT_Z out): it pitches about its own x. Its own
##           "Mesh", "Body" (each stave, so the pilot can't pass through
##           it; the mouth is open) and:
##   "Head/Barrel/Mouth" Marker3D at the horn's mouth, which looks out along
##           the barrel's +Z (the piece's front, like the kit's other
##           fronts). Its global_position is where a blast leaves; its
##           global basis.z is the way it points.
##   "Rig"   the runtime (scripts/wind_horn.gd): `aim_at`, `tell`, `fired`,
##           `disabled`, `is_disabled`.
## Meta: "mouth_radius" (the clear radius at the mouth, m), "top" (the
## standable cap's height over the foot, m), "top_radius" (its apothem),
## "ped_height".
##   ./run-wind-horn.command   (the study)   ./run-ruin-kit.command --family=horn

const RuinKit = preload("res://scripts/ruin_kit.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const AirBlast = preload("res://scripts/dragon_air_blast.gd")
const Build = RuinKit.Build

const PIECES := ["wind_horn"]

## The pedestal: its height (a jump up; the plinth under it a step each way
## would be wasted on a thing he stands beside), its widest apothem.
const PED_H := 1.2
const PED_R := 1.6
## The chest's cap stands this far under the highest lip a plain jump
## catches from the pedestal's top (PED_H + RuinKit.GRAB_TOP): the pilot
## jumps onto the pedestal (PED_H, under CHAIN_TOP) and then catches the cap,
## or drops to it from a ledge above.
const TOP_SLACK := 0.25
static var TOP_HEIGHT: float = PED_H+RuinKit.GRAB_TOP-TOP_SLACK
## The chest: its apothem under the cap, the cap's apothem and its
## thickness; the chest's height is what is left to TOP_HEIGHT.
const CHEST_R := 1.0
const CAP_R := 1.1
const CAP_H := 0.2
## The horn's axis over the head's pivot, and the stave rings: the first
## ring's foot (inside the chest), how many rings, the staves a ring, and
## the horn's length (to the lip's front).
const AXIS := 1.0
## The barrel's trunnion, this far out of the head's middle along +Z (in
## the chest, near its face): the horn pitches about it.
const PIVOT_Z := 0.85
const THROAT := 0.5
const RINGS := 4
const STAVES := 8
const LENGTH := 3.0
## The wall of a ring at the throat and at the mouth, and the lip.
const WALL := Vector2(0.2,0.26)
const LIP := Vector2(0.22,0.14)
## The mouth is the air ball's radius times this clear, and the throat a
## share of the mouth.
const MOUTH_FIT := 1.3
const THROAT_SHARE := 0.55

## The clear radius at the mouth: the air ball (the dragon's air blast) with
## room round it.
static func mouth_radius() -> float:
	return AirBlast.ball_radius()*MOUTH_FIT

## The piece with PIECES id `id`.
static func piece(id: String, seed_value: int, weathered := 0.0) -> Node3D:
	if id == "wind_horn": return wind_horn(seed_value,weathered)
	return null

## The runtime of a horn built here (its "Rig"), or null.
static func rig(horn: Node) -> Node:
	return horn.get_node_or_null("Rig")

## The wind-horn. See the header.
static func wind_horn(seed_value: int, weathered := 0.0) -> Node3D:
	var b := Build.new(seed_value,weathered,"WindHorn")
	# --- The pedestal: a splayed foot, two drums, a cornice. ---
	var layers := [
		[0.3,PED_R+0.1,PED_R,0.92],
		[0.34,PED_R-0.15,PED_R-0.15,1.0],
		[0.26,PED_R-0.15,PED_R-0.15,0.97],
		[PED_H-0.9,PED_R-0.15,PED_R,1.05]]
	var y := 0.0
	for i in range(layers.size()):
		var layer: Array = layers[i]
		var h: float = layer[0]
		var extra: Array[Plane] = []
		if i == 0 and weathered > 0.2: extra = RuinKit._break(b,h,PED_R,0.45+0.3*weathered)
		var turn := PI/8.0+b.rng.randf_range(-0.05,0.05)*(i+1)
		b.solid(RuinKit._prism(8,float(layer[1]),float(layer[2]),0.0,h,turn),RuinKit._settle(b,Vector3(0.0,y,0.0),0.25),RuinKit._stone(b,float(layer[3])),true,true,extra)
		y += h
	# Clean top for the head to turn on and the pilot to step onto.
	RuinKit._walk_hull(b,Transform3D.IDENTITY,RuinKit._prism(8,PED_R-0.2,PED_R-0.2,0.0,PED_H,PI/8.0))
	RuinKit._drift(b,Vector3(b.rng.randf_range(-1.0,1.0),0.0,PED_R+0.9),1.0,2+int(weathered*3.0))
	RuinKit._rubble(b,PED_R+0.3,int(round(weathered*b.rng.randf_range(4.0,7.0))))
	var node := b.finish()
	# --- The head, built apart so it can turn. ---
	var hb := Build.new(seed_value+7,weathered,"WindHornHead")
	var top := TOP_HEIGHT-PED_H
	var chest_top := top-CAP_H
	var courses := 3
	var cy := 0.0
	for k in range(courses):
		var ch := chest_top/courses
		var turn := PI/8.0+hb.rng.randf_range(-0.12,0.12)
		hb.solid(RuinKit._prism(8,CHEST_R,CHEST_R-0.05+0.05*(k%2),0.0,ch,turn),RuinKit._settle(hb,Vector3(0.0,cy,0.0),0.2),RuinKit._stone(hb,0.98+0.04*k),false)
		cy += ch
	hb.solid(RuinKit._prism(8,CAP_R,CAP_R-0.04,0.0,CAP_H,PI/8.0),RuinKit._settle(hb,Vector3(0.0,chest_top,0.0),0.15),RuinKit._stone(hb,1.06),false)
	# The standable top: true hulls (chest, then cap).
	RuinKit._walk_hull(hb,Transform3D.IDENTITY,RuinKit._prism(8,CHEST_R,CHEST_R,0.0,chest_top+0.01,PI/8.0))
	RuinKit._walk_hull(hb,Transform3D.IDENTITY,RuinKit._prism(8,CAP_R,CAP_R,chest_top,top,PI/8.0))
	var head := hb.finish()
	head.name = "Head"
	head.position = Vector3(0.0,PED_H,0.0)
	node.add_child(head)
	# The horn: rings of staves, the radius widening with a curve, built
	# apart on its trunnion so it can pitch.
	var bb := Build.new(seed_value+11,weathered,"WindHornBarrel")
	bb.frame = Transform3D(Basis.IDENTITY,-Vector3(0.0,AXIS,PIVOT_Z))
	var mouth := mouth_radius()
	var throat := mouth*THROAT_SHARE
	var z0 := 0.55
	var z_lip := LENGTH-LIP.y
	var ring_len := (z_lip-z0)/RINGS
	for r in range(RINGS):
		var za := z0+ring_len*r
		var zb := za+ring_len
		var ta := pow(float(r)/RINGS,1.7)
		var tb := pow(float(r+1)/RINGS,1.7)
		var ia := lerpf(throat,mouth,ta)
		var ib := lerpf(throat,mouth,tb)
		var wa := lerpf(WALL.x,WALL.y,ta)
		var wb := lerpf(WALL.x,WALL.y,tb)
		_ring(bb,za,zb,ia,ib,wa,wb,r%2,0.0)
	_ring(bb,z_lip-0.02,LENGTH,mouth,mouth,WALL.y,WALL.y+LIP.x,0,weathered*0.35,true)
	var barrel := bb.finish()
	barrel.name = "Barrel"
	barrel.position = Vector3(0.0,AXIS,PIVOT_Z)
	head.add_child(barrel)
	var marker := Marker3D.new()
	marker.name = "Mouth"
	marker.position = Vector3(0.0,0.0,LENGTH-PIVOT_Z+0.02)
	barrel.add_child(marker)
	node.set_meta("mouth_radius",mouth)
	node.set_meta("top",TOP_HEIGHT)
	node.set_meta("top_radius",CAP_R)
	node.set_meta("ped_height",PED_H)
	var runtime := Node.new()
	runtime.name = "Rig"
	runtime.set_script(load("res://scripts/wind_horn.gd"))
	node.add_child(runtime)
	return node

## One ring of the horn: STAVES staves round the axis (Z) from `za` to
## `zb`, clear radius `ia` to `ib` and wall `wa` to `wb`, the joints turned
## half a stave on every second ring (`odd`); a share `lost` of them broken
## off, `lip` the front flange (a plain flare, drawn thicker).
static func _ring(hb: Build, za: float, zb: float, ia: float, ib: float, wa: float, wb: float, odd: int, lost: float, lip := false) -> void:
	var half := PI/STAVES
	for k in range(STAVES):
		if lost > 0.0 and hb.rng.randf() < lost: continue
		var a := TAU*k/STAVES+half*odd
		var r := Vector3(cos(a),sin(a),0.0)
		var planes: Array[Plane] = [Plane(Vector3.BACK,zb),Plane(Vector3.FORWARD,-za)]
		# Inner and outer faces follow the flare (rim line r(z)).
		var sa := (ib-ia)/(zb-za)
		var n_in := (-r+Vector3.BACK*sa).normalized()
		planes.append(Plane(n_in,n_in.dot(r*ia+Vector3.BACK*za)))
		var sb := (ib+wb-(ia+wa))/(zb-za)
		var n_out := (r-Vector3.BACK*sb).normalized()
		planes.append(Plane(n_out,n_out.dot(r*(ia+wa)+Vector3.BACK*za)))
		# Sides: the planes through the axis half a stave either way.
		for s: float in [-1.0,1.0]:
			var edge := a+s*half
			planes.append(Plane(Vector3(-sin(edge),cos(edge),0.0)*s,0.004))
		var tone := RuinKit._stone(hb,1.04 if not lip else 1.1)
		hb.solid(planes,RuinKit._settle(hb,Vector3(0.0,AXIS,0.0),0.12),tone,true,true)
