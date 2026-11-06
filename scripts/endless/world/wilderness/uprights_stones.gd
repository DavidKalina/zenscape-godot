extends RefCounted
## The wilderness's standing stones: skin `stones` of the uprights kind
## (scripts/endless/kinds/uprights.gd). A ring of tall slabs of the land's
## own rock, lofted and weathered by scripts/endless/rocks/rock_build.gd and
## carved by the rock shape (scripts/endless/rock_shape.gd), drawn with the
## land's rock material with no turf: lintels laid across a few pairs, one
## leaning out, one broken short, one fallen outward on the meadow.
##
## Each piece keeps inside its slot's width (its weathering's push
## included, PUSH), so the kind's gaps stay at least their openings.

const Build = preload("res://scripts/endless/rocks/rock_build.gd")

## How far the weathering pushes a stone's outline out at most, as a share
## of its radius (lumps, grain, ledges and flutes below, together).
const PUSH := 0.17
## A stone's foot buried under the land (m), its loft's ring spacing (m)
## and the points a ring.
const BURY := 3.0
const RING_EVERY := 1.5
const SEGMENTS := 16
## A lintel's height (m), how far it runs past each stone's middle (shares
## of the stone's half width), its ring spacing along it (m).
const LINTEL_TALL := 3.2
const OVERHANG := 0.75
const LINTEL_EVERY := 1.0
## How much of a fallen stone's thickness is sunk in the turf at its foot
## end; it lies tipped TIP deg, its far end dug in deeper (so it stands
## clear of the grass and reads as toppled).
const SUNK := 0.1
const TIP := 4.0

static func defaults() -> Dictionary:
	return {"shape":"ring","count":14,"radius":32.0,"tall":22.0,"jitter":0.15,"wide":2,"spans":3,
		"lean":14.0,"leaners":1,"fallen":1,"broken":1,"depth":3.6}

static func material(_key: String) -> Material:
	return null

## The ring's stones and lintels (uprights.gd `pieces`), on a worker.
static func pieces(layout: Dictionary) -> Array:
	var out: Array = []
	var slots: Array = layout.slots
	for slot: Dictionary in slots:
		out.append(_lying(slot) if bool(slot.fallen) else _upright(slot))
	for sp: Array in layout.spans:
		out.append(_lintel(slots[sp[0]],slots[sp[1]],int(layout.seed)+int(sp[0])))
	return out

## The weathering every stone shares; a stone's own `tint` and seed over it.
static func _weather(pillar: Dictionary, seed_value: int, tint: Color) -> Dictionary:
	pillar.merge({"seed":seed_value,"square":0.5,"segments":SEGMENTS,"lump":5.0,"lumps":0.08,"grain":0.03,
		"ledges":0.02,"bed":3.0,"flutes":0.04,"tint":tint},true)
	return pillar

static func _tint(seed_value: int) -> Color:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var k := rng.randf_range(0.9,1.06)
	return Color(k*rng.randf_range(0.97,1.03),k,k*rng.randf_range(0.95,1.0))

## A standing stone: a slab across the path, tapering a little to a rounded
## top (a span's pair: squarer, its top flat for the lintel), leaning out.
static func _upright(slot: Dictionary) -> Dictionary:
	var rx := float(slot.wide)*0.5/(1.0+PUSH)
	var rz := float(slot.depth)*0.5
	var tall := float(slot.tall)*float(slot.short)
	var along: Vector3 = slot.along
	var out: Vector3 = slot.out
	var lean := tan(float(slot.lean))
	var held := bool(slot.held)
	var top_k := 0.94 if held else 0.72
	var rows := [[-BURY,1.04,1.06],[0.0,1.02,1.04],[tall*0.45,1.0,1.0],[tall*0.8,0.94,0.92],[tall*0.94,lerpf(0.94,top_k,0.6),0.9],[tall,top_k,0.82]]
	if float(slot.short) < 1.0:
		# Broken: the top snapped off square, a shade wider than whole.
		rows = [[-BURY,1.04,1.06],[0.0,1.02,1.04],[tall*0.6,1.0,1.0],[tall,0.98,0.97]]
	var profile: Array = []
	for r: Array in rows:
		var y := float(r[0])
		profile.append([y,rx*float(r[1]),rz*float(r[2]),out.x*maxf(y,0.0)*lean,out.z*maxf(y,0.0)*lean])
	var seed_value := int(slot.seed)
	var pillar := _weather({"at":slot.at,"profile":profile,"yaw":atan2(along.z,along.x),"ring_every":RING_EVERY,
		"dome":0.15 if held else (0.3 if float(slot.short) < 1.0 else 1.2)},seed_value,_tint(seed_value))
	return _piece(Build.build({"pos":Vector3.ZERO,"pillars":[pillar]}),Transform3D.IDENTITY)

## A lintel across the tops of `a` and `b`: a block laid from past one's
## middle to past the other's.
static func _lintel(a: Dictionary, b: Dictionary, seed_value: int) -> Dictionary:
	var pa: Vector3 = (a.at as Vector3)+Vector3(0.0,float(a.tall),0.0)
	var pb: Vector3 = (b.at as Vector3)+Vector3(0.0,float(b.tall),0.0)
	var d := Vector3(pb.x-pa.x,0.0,pb.z-pa.z)
	var dir := d.normalized()
	var from := pa-dir*float(a.wide)*0.5*OVERHANG
	var to := pb+dir*float(b.wide)*0.5*OVERHANG
	var long := Vector3(to.x-from.x,0.0,to.z-from.z).length()
	var half_deep := minf(float(a.depth),float(b.depth))*0.55
	var half_tall := LINTEL_TALL*0.5
	from.y = maxf(pa.y,pb.y)+half_tall
	var profile := [[0.0,half_deep*0.55,half_tall*0.55,0.0,0.0],[LINTEL_EVERY,half_deep,half_tall,0.0,0.0],
		[long*0.5,half_deep*1.03,half_tall*1.02,0.0,0.0],[long,half_deep*0.97,half_tall*0.97,0.0,0.0]]
	var pillar := _weather({"at":Vector3.ZERO,"profile":profile,"ring_every":LINTEL_EVERY,"dome":0.35},seed_value,_tint(seed_value))
	pillar.lumps = 0.06
	pillar.flutes = 0.0
	pillar.square = 0.45
	return _piece(Build.build({"pos":Vector3(seed_value%97,40.0,seed_value%89),"pillars":[pillar]}),_laid(from,dir))

## A fallen stone: toppled outward from its foot, lying on its broad face,
## sunk a share of its thickness into the turf.
static func _lying(slot: Dictionary) -> Dictionary:
	var rx := float(slot.wide)*0.5/(1.0+PUSH)
	var rz := float(slot.depth)*0.5
	var long := float(slot.tall)*0.92
	var out: Vector3 = slot.out
	var foot: Vector3 = slot.at
	var from := foot+out*(rz*0.6)
	from.y = minf(foot.y,float(slot.lie_y))+rz*(1.0-SUNK*2.0)
	var profile := [[0.0,rx*0.6,rz*0.6,0.0,0.0],[RING_EVERY,rx*1.02,rz,0.0,0.0],[long*0.6,rx,rz,0.0,0.0],[long,rx*0.72,rz*0.85,0.0,0.0]]
	var seed_value := int(slot.seed)
	var pillar := _weather({"at":Vector3.ZERO,"profile":profile,"ring_every":RING_EVERY,"dome":0.8},seed_value,_tint(seed_value)*0.94)
	# Turned a little off straight out, as it fell.
	var dir := out.rotated(Vector3.UP,(float(seed_value%21)-10.0)*0.02)
	return _piece(Build.build({"pos":Vector3(seed_value%83,-20.0,seed_value%79),"pillars":[pillar]}),_laid(from,dir,deg_to_rad(TIP)))

## A pillar lofted up its +Y laid along `dir` (level, or tipped `tip` rad
## down) from `from`: its +Y along `dir`, its x across (level), its z up. A
## turn, not a mirror (the skin's winding keeps facing out).
static func _laid(from: Vector3, dir: Vector3, tip := 0.0) -> Transform3D:
	var side := dir.cross(Vector3.UP).normalized()
	return Transform3D(Basis(side,dir*cos(tip)-Vector3.UP*sin(tip),Vector3.UP*cos(tip)+dir*sin(tip)),from)

## A built pillar (rock_build.gd) as a piece, moved by `t`.
static func _piece(b: Dictionary, t: Transform3D) -> Dictionary:
	var arrays: Array = b.arrays
	var faces := PackedVector3Array()
	for f: PackedVector3Array in b.faces: faces.append_array(f)
	if t != Transform3D.IDENTITY:
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in range(v.size()):
			v[i] = t*v[i]
			n[i] = t.basis*n[i]
		arrays[Mesh.ARRAY_VERTEX] = v
		arrays[Mesh.ARRAY_NORMAL] = n
		for i in range(faces.size()): faces[i] = t*faces[i]
	return {"arrays":arrays,"lods":b.lods,"faces":faces,"material":"bare","tris":b.tris}
