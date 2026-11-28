extends RefCounted
## Greybox pieces of land (scripts/pieces/) stamped into a world's generated
## ground: a stamp like the coast's isles (coast_isles.gd). The world profile
## lists them (`pieces`, world_profile.gd); each row places one piece script
## at a world point and heading, and the piece's own `rise(x, z)` (its height
## over the ground it stands on, in its own frame) is added to the map's
## ground inside the piece's `reach()` box. The piece file stays the single
## source of its shape: retuning the study retunes the map.
##
## LandField reads it wherever it reads the isles: `sample`, `height`, `shape`,
## `river_y`, `build_chunk` (every level of detail; the level-0 collision is
## that chunk's heights), `grid` / `peak_grid` (the grass, the horizon's
## shadow, the wind) and the native fast paths' gates (`native_impl_in`,
## `native_band_in`: a box a piece reaches is sampled through LandField).
##
## A piece script has, static:
##   rise(x, z) -> float   its height over the ground at local (x, z), 0 off it
##                         (its edges eased to 0, so the foot meets the ground
##                         with no seam); local -z is the piece's north.
##   reach() -> Rect2      the local box outside which `rise` is 0.
##   dressing() -> Array   optional: [{kind: "waterfall", lip: Vector3 (y over
##                         the ground), out: Vector3, pool: Vector2, pool_y,
##                         pool_r}] for piece_dress.gd.
##
## A row: {"piece": preload(script), "at": Vector2(x, z), "heading": degrees
## clockwise from -z (the flight's --heading), "scale": horizontal (1), "tall":
## vertical (1)}.

## Lifted less than this (m), the land is the map's own (river, trees).
const LIFTED := 0.5

var _script: Array = []
var _cx := PackedFloat64Array()
var _cz := PackedFloat64Array()
var _ca := PackedFloat64Array()
var _sa := PackedFloat64Array()
var _scale := PackedFloat64Array()
var _tall := PackedFloat64Array()
## The local reach, and the world box round it (x0, z0, x1, z1 a row).
var _local: Array[Rect2] = []
var _box := PackedFloat64Array()

## What the last `apply` moved: its rise over the ground (m).
var last_lift := 0.0

## The world's pieces, or null where it lists none (every other world pays
## nothing).
static func make(world: RefCounted) -> RefCounted:
	if world == null: return null
	var rows: Variant = world.get("pieces")
	if rows == null or (rows as Array).is_empty(): return null
	if "--pieces=0" in preload("res://scripts/launch_args.gd").user_args(): return null
	return new(rows as Array)

func _init(rows: Array) -> void:
	for row: Dictionary in rows:
		var s: Script = row.piece
		var at: Vector2 = row.get("at",Vector2.ZERO)
		var h := deg_to_rad(float(row.get("heading",0.0)))
		var sc := maxf(float(row.get("scale",1.0)),0.01)
		_script.append(s)
		_cx.append(at.x)
		_cz.append(at.y)
		_ca.append(cos(h))
		_sa.append(sin(h))
		_scale.append(sc)
		_tall.append(float(row.get("tall",1.0)))
		var r: Rect2 = s.reach()
		_local.append(r)
		# The world box: the local box's corners turned and scaled.
		var lo := Vector2(INF,INF)
		var hi := -lo
		for c: Vector2 in [r.position,r.position+Vector2(r.size.x,0.0),r.end,r.position+Vector2(0.0,r.size.y)]:
			var w := to_world(_cx.size()-1,c)
			lo = lo.min(w)
			hi = hi.max(w)
		_box.append_array([lo.x,lo.y,hi.x,hi.y])

## How many pieces.
func count() -> int:
	return _script.size()

## Piece `i`'s local point (x, z) in world XZ.
func to_world(i: int, p: Vector2) -> Vector2:
	var q := p*_scale[i]
	return Vector2(_cx[i]+q.x*_ca[i]-q.y*_sa[i],_cz[i]+q.x*_sa[i]+q.y*_ca[i])

## World XZ (x, z) in piece `i`'s local frame.
func to_local(i: int, x: float, z: float) -> Vector2:
	var dx := x-_cx[i]
	var dz := z-_cz[i]
	return Vector2(dx*_ca[i]+dz*_sa[i],dz*_ca[i]-dx*_sa[i])/_scale[i]

## Piece `i`'s script, its vertical and horizontal scale and its heading's
## (cos, sin) (for the dressing).
func script_of(i: int) -> Script:
	return _script[i]

func tall_of(i: int) -> float:
	return _tall[i]

func scale_of(i: int) -> float:
	return _scale[i]

## A local direction of piece `i` (x, z) in world XZ.
func dir_to_world(i: int, d: Vector2) -> Vector2:
	return Vector2(d.x*_ca[i]-d.y*_sa[i],d.x*_sa[i]+d.y*_ca[i])

## Whether (x, z) lies in any piece's box.
func reaches(x: float, z: float) -> bool:
	for i in _script.size():
		var b := i*4
		if x >= _box[b] and x <= _box[b+2] and z >= _box[b+1] and z <= _box[b+3]: return true
	return false

## Whether a site of reach `r` at (x, z) keeps clear of every piece's box.
func clear(x: float, z: float, r := 0.0) -> bool:
	for i in _script.size():
		var b := i*4
		if x+r >= _box[b] and x-r <= _box[b+2] and z+r >= _box[b+1] and z-r <= _box[b+3]: return false
	return true

## Whether the box (x0, z0)..(x1, z1) meets any piece's box.
func meets(x0: float, z0: float, x1: float, z1: float) -> bool:
	for i in _script.size():
		var b := i*4
		if x1 >= _box[b] and x0 <= _box[b+2] and z1 >= _box[b+1] and z0 <= _box[b+3]: return true
	return false

## The pieces' rise at world (x, z) (m, summed).
func rise(x: float, z: float) -> float:
	var up := 0.0
	for i in _script.size():
		var b := i*4
		if x < _box[b] or x > _box[b+2] or z < _box[b+1] or z > _box[b+3]: continue
		var p := to_local(i,x,z)
		if not _local[i].has_point(p): continue
		up += float(_script[i].rise(p.x,p.y))*_tall[i]*_scale[i]
	return up

## Vector2(world height, meadow) `got` with the pieces on it at (x, z).
func apply(got: Vector2, x: float, z: float) -> Vector2:
	last_lift = rise(x,z)
	got.x += last_lift
	return got

# --- The land's arrays ------------------------------------------------------------

## The pieces' pass over a chunk's arrays (LandField.build_chunk's): heights,
## then the normals and colours round what moved, the skirt's copies.
func apply_chunk(field: Object, impl: Object, made: Dictionary, x0: float, z0: float, step: float, cells: int, skirt_drop: float) -> void:
	var n := cells+1
	var w := n+2
	var heights: PackedFloat32Array = made.heights
	var hs := PackedFloat32Array()
	var mv := PackedByteArray()
	hs.resize(w*w)
	mv.resize(w*w)
	var any := false
	for j in w:
		for i in w:
			var x := x0+(i-1)*step
			var z := z0+(j-1)*step
			var k := j*w+i
			var inner := i >= 1 and i <= n and j >= 1 and j <= n
			var up := rise(x,z) if reaches(x,z) else 0.0
			if not inner:
				# The rim (one sample out): read through the field, below, only
				# where a redrawn vertex's normal needs it.
				hs[k] = NAN
				if up != 0.0: mv[k] = 1
				continue
			hs[k] = heights[(j-1)*n+i-1]+up
			if up != 0.0:
				mv[k] = 1
				any = true
	if not any: return
	for j in w:
		for i in w:
			var k := j*w+i
			if not is_nan(hs[k]): continue
			var near := false
			for d: int in [k-1,k+1,k-w,k+w]:
				if d < 0 or d >= w*w: continue
				var di := d%w
				var dj := d/w
				if di < 1 or di > n or dj < 1 or dj > n: continue
				if mv[d]+mv[d-1]+mv[d+1]+mv[d-w]+mv[d+w] > 0: near = true
			hs[k] = float(field.height(x0+(i-1)*step,z0+(j-1)*step)) if near else 0.0
	var verts: PackedVector3Array = made.verts
	var normals: PackedVector3Array = made.normals
	var colours: PackedColorArray = made.colours
	var carved: PackedByteArray = made.carved
	var river: PackedFloat32Array = made.river
	var ms: PackedColorArray = colours
	# The vertices the paint is asked for: all that moved or touch one that did.
	var xs := PackedFloat64Array()
	var zs := PackedFloat64Array()
	var ys := PackedFloat32Array()
	var ups := PackedFloat32Array()
	var mds := PackedFloat32Array()
	var ids := PackedInt32Array()
	for j in n:
		for i in n:
			var k := (j+1)*w+i+1
			if mv[k]+mv[k-1]+mv[k+1]+mv[k-w]+mv[k+w] == 0: continue
			var v := j*n+i
			var y := hs[k]
			var nrm := Vector3(hs[k-1]-hs[k+1],2.0*step,hs[k-w]-hs[k+w]).normalized()
			normals[v] = nrm
			heights[v] = y
			verts[v] = Vector3(i*step,y,j*step)
			xs.append(x0+i*step)
			zs.append(z0+j*step)
			ys.append(y)
			ups.append(nrm.y)
			mds.append(ms[v].a)
			ids.append(v)
			if mv[k] == 0: continue
			# No river on the piece.
			river[v*3] = 1000.0
			river[v*3+1] = 0.0
	if not ids.is_empty():
		var cs: PackedColorArray = field.colours(xs,zs,ys,ups,mds)
		for q in ids.size():
			var c := cs[q]
			c.a = mds[q]
			colours[ids[q]] = c
	for e in 4:
		for t in n:
			var from: int = t if e == 0 else (t*n+cells if e == 1 else (cells*n+t if e == 2 else t*n))
			var k := ((from/n)+1)*w+(from%n)+1
			if mv[k]+mv[k-1]+mv[k+1]+mv[k-w]+mv[k+w] == 0: continue
			var sv := n*n+e*n+t
			verts[sv] = verts[from]-Vector3(0.0,skirt_drop,0.0)
			normals[sv] = normals[from]
			colours[sv] = colours[from]
			for q in 4: carved[sv*4+q] = carved[from*4+q]
			river[sv*3] = river[from*3]
			river[sv*3+1] = -river[from*3+1]
			river[sv*3+2] = river[from*3+2]
	made.heights = heights
	made.verts = verts
	made.normals = normals
	made.colours = colours
	made.carved = carved
	made.river = river

## The pieces' pass over LandField.grid's arrays (the grass's, the horizon's).
func apply_grid(got: Dictionary, x0: float, z0: float, step: float, nx: int, nz: int, pad: int) -> void:
	var hs: PackedFloat32Array = got.heights
	var rs: PackedFloat32Array = got.get("river",PackedFloat32Array())
	for j in nz:
		for i in nx:
			var x := x0+(i-pad)*step
			var z := z0+(j-pad)*step
			if not reaches(x,z): continue
			var up := rise(x,z)
			if up == 0.0: continue
			var k := j*nx+i
			hs[k] += up
			if not rs.is_empty() and up > LIFTED: rs[k] = 1000.0
	got.heights = hs
	if not rs.is_empty(): got.river = rs
