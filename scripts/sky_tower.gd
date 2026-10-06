extends RefCounted
## One towering cumulus (scripts/sky_towers.gd): a billowing column of cloud
## rising out of the cloud sea, a few hundred metres over the sky islands,
## two or three times as tall as it is wide: a broad, low foot where it
## boils up out of the sea, a leaning column of stacked turrets, each
## narrower than the one under it and budding at its shoulder, a lower
## turret off one side, and a tight cauliflower crown on top.
##
## Its shape is a heap of round LOBES (Vector4 x, y, z, radius, in the
## tower's own frame: its middle at the sea's foot, y up, the sea at SEA)
## blended into one smooth body (`distance`, a smooth union). The shader
## (shaders/sky_tower.gdshader) never sees the lobes: the body is baked on
## a worker into a coarse grid of distances (`bake`), a float 3D texture the
## shader reads once a step, and the cauliflower's finer bumps and wisps are
## its own noise on top. Here, the same body says how deep a point is in the
## cloud (`depth`), for the vapour, the muffled wind and the tests.
##
## A seed always makes the same tower.

## The cloud sea's top in the tower's frame (scripts/sky_flight.gd SEA_Y).
const SEA := -105.0
## How tall (over the sea) and how wide (its foot) a tower grows, metres.
const TALL := Vector2(330.0,480.0)
const WIDE := Vector2(215.0,260.0)
## How far the shader's bumps can swell the body out (m): the bake's box is
## this much bigger all round, so the noise is never cut off by its edge.
const SWELL := 42.0
## The bake's cells, at most, along the widest side; and the distance
## stored is clamped to this (m), all the shader ever needs.
const CELLS := 40
const CLAMP := 160.0
## The smooth union's reach, a share of the trunk's width.
const BLEND := 0.07

var seed := 0
var tall := 0.0
var wide := 0.0
## Which way and how far the crown leans off the foot (m, plate plane).
var lean := Vector2.ZERO
var lobes := PackedVector4Array()
## The body's box in the tower's frame, with SWELL round it.
var box := AABB()
## The smooth union's reach (m).
var blend := 0.0

static func make(seed_value: int) -> RefCounted:
	var t := new()
	t.seed = seed_value
	t._grow()
	return t

## The top of the crown, the tower's frame.
func top() -> float:
	return SEA+tall

func _grow() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	tall = rng.randf_range(TALL.x,TALL.y)
	wide = rng.randf_range(WIDE.x,WIDE.y)
	blend = wide*BLEND
	var a := rng.randf()*TAU
	lean = Vector2(cos(a),sin(a))*tall*rng.randf_range(0.05,0.12)
	lobes = PackedVector4Array()
	# The foot: a broad, low swell boiling up out of the sea, its lobes
	# mostly under the sea's top, so above it shows only their flat crowns.
	var feet := rng.randi_range(6,8)
	var turn := rng.randf()*TAU
	for i in range(feet):
		var f := turn+TAU*(float(i)+rng.randf_range(-0.25,0.25))/feet
		var r := wide*rng.randf_range(0.34,0.44)
		var out := wide*rng.randf_range(0.3,0.42)
		lobes.append(Vector4(cos(f)*out,SEA-r*rng.randf_range(0.35,0.55),sin(f)*out,r))
	lobes.append(Vector4(0.0,SEA-wide*0.12,0.0,wide*0.5))
	# The column: stacked stages, each a turret narrower than the one under
	# it, set a little off the lean, with buds round its shoulder, so the
	# tower climbs in steps toward the crown.
	var crown_r := wide*rng.randf_range(0.19,0.23)
	var stages := rng.randi_range(4,5)
	var floor_y := SEA+wide*0.12
	for n in range(stages):
		var k := float(n)/(stages-1)
		var r := wide*lerpf(0.39,0.24,k)*rng.randf_range(0.94,1.06)
		var y := lerpf(floor_y+r*0.6,top()-crown_r*1.6,k)
		var at := _axis(y)+Vector2(rng.randf_range(-1.0,1.0),rng.randf_range(-1.0,1.0))*wide*0.05
		lobes.append(Vector4(at.x,y,at.y,r))
		# Halfway to the next stage, a waist lobe keeps the column whole.
		if n < stages-1:
			var y2 := lerpf(floor_y+r*0.6,top()-crown_r*1.6,(float(n)+0.5)/(stages-1))
			var at2 := _axis(y2)
			lobes.append(Vector4(at2.x,y2,at2.y,r*0.82))
		var buds := rng.randi_range(2,3)
		var bud_turn := rng.randf()*TAU
		for b in range(buds):
			var f := bud_turn+TAU*(float(b)+rng.randf_range(-0.2,0.2))/buds
			var br := r*rng.randf_range(0.42,0.6)
			var reach := r*rng.randf_range(0.65,0.85)
			lobes.append(Vector4(at.x+cos(f)*reach,y+r*rng.randf_range(0.15,0.5),at.y+sin(f)*reach,br))
	# The crown: a main dome and a tight cauliflower of buds heaped on it,
	# some climbing over the others.
	var head := _axis(top()-crown_r)
	lobes.append(Vector4(head.x,top()-crown_r,head.y,crown_r))
	var buds := rng.randi_range(5,7)
	var bud_turn := rng.randf()*TAU
	for i in range(buds):
		var f := bud_turn+TAU*(float(i)+rng.randf_range(-0.25,0.25))/buds
		var r := crown_r*rng.randf_range(0.42,0.62)
		var out := crown_r*rng.randf_range(0.55,0.95)
		lobes.append(Vector4(head.x+cos(f)*out,top()-crown_r*rng.randf_range(0.4,1.4)+r*0.4,head.y+sin(f)*out,r))
	# A lower turret off a shoulder, its own small dome short of the crown.
	for i in range(rng.randi_range(1,2)):
		var f := rng.randf()*TAU
		var from := rng.randf_range(0.3,0.45)
		var to := rng.randf_range(0.6,0.75)
		var tr := wide*rng.randf_range(0.14,0.19)
		for n in range(3):
			var y := SEA+tall*lerpf(from,to,n/2.0)
			var at := _axis(y)+Vector2(cos(f),sin(f))*wide*lerpf(0.36,0.3,n/2.0)
			lobes.append(Vector4(at.x,y,at.y,tr*lerpf(1.0,0.8,n/2.0)))
	var lo := Vector3(INF,INF,INF)
	var hi := -lo
	for l in lobes:
		lo = lo.min(Vector3(l.x,l.y,l.z)-Vector3.ONE*l.w)
		hi = hi.max(Vector3(l.x,l.y,l.z)+Vector3.ONE*l.w)
	lo -= Vector3.ONE*SWELL
	hi += Vector3.ONE*SWELL
	# Nothing of it under the sea's top but a skirt.
	lo.y = maxf(lo.y,SEA-20.0)
	box = AABB(lo,hi-lo)

## The trunk's middle at height y: from the foot over the sea, leaning.
func _axis(y: float) -> Vector2:
	return lean*clampf((y-SEA)/tall,0.0,1.0)

## The smooth body's signed distance at a point in the tower's frame (m):
## below 0 inside.
func distance(p: Vector3) -> float:
	var d := CLAMP
	var k := blend
	for l in lobes:
		var e := Vector3(p.x-l.x,p.y-l.y,p.z-l.z).length()-l.w
		# Polynomial smooth minimum.
		var h := clampf(0.5+0.5*(d-e)/k,0.0,1.0)
		d = lerpf(d,e,h)-k*h*(1.0-h)
	return d

## How deep (m) a point in the tower's frame is inside the body: below 0
## outside it.
func depth(p: Vector3) -> float:
	return -distance(p)

## The body's distances on a grid over `box`: {size: Vector3i, data:
## PackedFloat32Array, x fastest, then y, then z}, clamped to ±CLAMP.
func bake() -> Dictionary:
	var longest := maxf(box.size.x,maxf(box.size.y,box.size.z))
	var cell := longest/CELLS
	var n := Vector3i(maxi(4,ceili(box.size.x/cell)),maxi(4,ceili(box.size.y/cell)),maxi(4,ceili(box.size.z/cell)))
	var data := PackedFloat32Array()
	data.resize(n.x*n.y*n.z)
	var i := 0
	for z in range(n.z):
		for y in range(n.y):
			for x in range(n.x):
				var p := box.position+Vector3((x+0.5)/n.x*box.size.x,(y+0.5)/n.y*box.size.y,(z+0.5)/n.z*box.size.z)
				data[i] = clampf(distance(p),-CLAMP,CLAMP)
				i += 1
	return {"size":n,"data":data}

## The bake as a float 3D texture for the shader, from its slices
## (`slices_of`, made on a worker if given).
static func texture_of(baked: Dictionary, slices: Array[Image] = []) -> ImageTexture3D:
	var n: Vector3i = baked.size
	if slices.is_empty(): slices = slices_of(baked)
	var texture := ImageTexture3D.new()
	texture.create(Image.FORMAT_RF,n.x,n.y,n.z,false,slices)
	return texture

## The bake's slices as images, one per depth: plain data, safe on a worker.
static func slices_of(baked: Dictionary) -> Array[Image]:
	var n: Vector3i = baked.size
	var data: PackedFloat32Array = baked.data
	var slices: Array[Image] = []
	var slice := n.x*n.y
	for z in range(n.z):
		slices.append(Image.create_from_data(n.x,n.y,false,Image.FORMAT_RF,data.slice(z*slice,(z+1)*slice).to_byte_array()))
	return slices
