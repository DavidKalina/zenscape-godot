## The Peak's massif (docs/design/endless-flight/spec-peak.md, Shape): one
## stamp over the land, applied by the land-field wrapper (LandField
## `sample`, `shape`, `height`, `build_chunk` and `grid`) after the ponds,
## tunnels, halls and splits, so chunk meshes, `height()` and collision
## agree.
##
## The profile is built in the massif's own frame from its centre (the
## plateau's middle) and its facing (the way out of the horseshoe's
## opening): `a` metres along the facing, `v` across it. The horseshoe's
## crest is a ring of RING_R round a point O_ALONG ahead of the plateau;
## `th` is the angle round it from the back (0, the couloir) toward the arms'
## tips (ARM_END). Each piece is a height over the sea (SEA_Y), and the land
## gets the higher of its own and the massif's, except where the massif cuts
## (`c`: inside the horseshoe, the valley, the plateau), where the massif's
## height stands alone. Along the axis, from the opening in:
##
##   glacier valley  a 4750..2250  100..250 m, a flat floor between side ridges
##   boulder field   a 2250..1250  250..330 m, lumpy floor
##   icefall         a 1250..750   330..420 m, three steps
##   the wall        a 750..250    420..735 m: talus, then a cliff; the
##                                 couloir a slot cut into it, a 600..240,
##                                 455..700 m
##   crest, towers   th 0..40      735..750 m, tower bases on it
##   plateau, tarn   a 150..-150   752 m flat, the tarn's bowl in it
##   summit block    beside the plateau, to 805 m
##   back face       a -150..-2200 770 m down to the sea
##
## Everything outside a circle of BOUND round O pays one distance check
## (`reaches`, `meets`). Placed through LayoutOverrides "peak/massif": the
## transform's origin the plateau's centre, its +z the facing.
extends RefCounted

const SEA_Y := -40.0
const LayoutOverrides = preload("res://scripts/layout_overrides.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const Sites = preload("res://scripts/endless/hall_sites.gd")

const HANDLE := "peak/massif"
## The coded spot until the trunk places it (lane stamp's test spot): the
## plateau's centre (world XZ) and the facing's yaw (degrees; 0 faces +z,
## toward the start at the origin).
const TEST_AT := Vector2(0.0,-8500.0)
const TEST_YAW := 0.0

# --- The ring: crest, wall, flanks -------------------------------------------------

## The horseshoe's middle, ahead of the plateau along the facing, and the
## crest's radius round it.
const O_ALONG := 1600.0
const RING_R := 1350.0
## The crest's height over the sea by `th` (degrees from the back), pairs.
const CREST := [0.0,735.0, 14.0,748.0, 38.0,742.0, 60.0,660.0, 100.0,520.0, 140.0,330.0, 168.0,40.0]
## Where the arms end (degrees); past it the ring sinks under the land.
const ARM_END := 168.0
## The wall at the back (th under 30, gone by 60): its foot's height, its
## run from the crest inward, the talus's fall past the foot (m per m).
const WALL_FOOT := 420.0
const WALL_RUN := 500.0
const TALUS_FALL := 0.2
## The wall's rise from foot to crest: a talus share up to TALUS_TOP of the
## run, the rest a cliff from CLIFF.x to CLIFF.y (shares of the run from the
## foot).
const TALUS_SHARE := 0.22
const TALUS_TOP := 0.6
const CLIFF := Vector2(0.45,0.97)
## The arms' inner flank: its fall per metre at the crest and 500 m in.
const ARM_IN := Vector2(0.85,0.6)
## The back's outer side (th under 35, gone by 70): the shoulder that holds
## the plateau (th under 5, gone by 16): from the crest up to PLATEAU_Y over
## SHOULDER.x m, flat to SHOULDER.y, up to LIP_Y by SHOULDER.z, then the back
## face; elsewhere a knife ridge straight into the face.
const SHOULDER := Vector3(120.0,400.0,460.0)
const PLATEAU_Y := 752.0
const LIP_Y := 770.0
const BACK_RUN := 2000.0
const BACK_BOW := 1.8
const KNIFE_BOW := 2.6
## The arms' outer flank.
const ARM_OUT_RUN := 1100.0
const ARM_OUT_BOW := 1.5
## Where every fall ends (over the sea, below the sea's face) and how fast
## it drops past its run, so the massif always sinks under the land before
## BOUND.
const FALL_END := -60.0
const PAST_END := 1.0

# --- The approach valley ------------------------------------------------------------

## The floor's stretches along `a`: icefall, boulders, glacier, toe.
const ICEFALL := Vector2(750.0,1250.0)
const ICEFALL_Y := Vector2(420.0,330.0)
const ICEFALL_STEPS := 3
const ICEFALL_RISER := 0.35
const BOULDERS := Vector2(1250.0,2250.0)
const BOULDERS_Y := Vector2(330.0,250.0)
const GLACIER := Vector2(2250.0,4750.0)
const GLACIER_Y := Vector2(250.0,100.0)
const TOE := Vector2(4750.0,5300.0)
## The floor's half-width: icefall, boulders, glacier's head and mouth.
const FLOOR_HALF := Vector4(200.0,240.0,260.0,330.0)
## The side ridges: their rise over the floor, the run to their top, their
## outer fall (m per m).
const SIDE_UP := 75.0
const SIDE_RUN := 170.0
const SIDE_FALL := 0.4
const SIDE_DIP := 15.0
const SIDE_DIP_TO := 2400.0
## Boulder-field lumps (m, and their scale against the rock noise's).
const LUMPS := 2.5
const LUMP_SCALE := 3.7

# --- Couloir, plateau, tarn, summit, towers ----------------------------------------------

## The couloir's toy width (WorldScale.opening), its floor's ramp from the
## mouth (a, height) to the crest's notch, its walls' softness (m).
const TOY_COULOIR := 40.0
const COULOIR_FOOT := Vector2(600.0,455.0)
const COULOIR_TOP := Vector2(240.0,700.0)
const COULOIR_SOFT := 6.0
const COULOIR_BACK := 50.0
## The plateau: flat out to PLATEAU_FLAT from its centre, blended out by
## PLATEAU_BLEND.
const PLATEAU_FLAT := 150.0
const PLATEAU_BLEND := 220.0
## The tarn's bowl: its centre TARN_BACK m behind the plateau's, its radius
## and depth, and the water level the bowl is cut for (over the sea): the
## water's edge lies at TARN_WET m from its centre.
const TARN_BACK := 40.0
const TARN_BOWL := 60.0
const TARN_DEEP := 8.0
const TARN_LEVEL := 751.0
## The summit block: its centre (a, v), half sizes, top over the sea.
const SUMMIT_AT := Vector2(-30.0,240.0)
const SUMMIT_HALF := Vector2(85.0,65.0)
const SUMMIT_Y := 805.0
## Tower bases on the crest: their angles each side (degrees), a flat top
## TOWER_UP over the crest of TOWER_R, falling TOWER_FALL m per m.
const TOWER_TH := [13.0,21.0,29.0,37.0]
const TOWER_R := 18.0
const TOWER_UP := 22.0
const TOWER_FALL := 2.5

## The rock's noise: its height (m) and scale (m).
const ROUGH := 9.0
const ROUGH_SCALE := 90.0
## The bounding circle round O: everything outside is the land's own.
const BOUND := 4050.0

## The stretches along the axis, for drivers and the trunk: name, a from,
## a to, height over the sea from, to.
const STRETCHES := [
	["glacier",4750.0,2250.0,100.0,250.0],
	["boulders",2250.0,1250.0,250.0,330.0],
	["icefall",1250.0,750.0,330.0,420.0],
	["wall",750.0,250.0,420.0,735.0],
	["plateau",150.0,-150.0,752.0,752.0],
	["back",-150.0,-2200.0,770.0,FALL_END],
]

var centre := Vector2.ZERO
var facing := Vector2(0.0,1.0)
var side := Vector2(1.0,0.0)
var _o := Vector2.ZERO
var _cw := 0.0
var _noise := FastNoiseLite.new()
## Tower bases, local (a, v), and their tops over the sea.
var _towers := PackedVector2Array()
var _tower_tops := PackedFloat32Array()
## The last `apply`'s change to the land's height (m).
var last_lift := 0.0

## The massif for this land, or null: `--peak=0` turns it off.
static func make(land_seed: int) -> RefCounted:
	var at := Vector2(TEST_AT)
	var yaw := TEST_YAW
	for a: String in LaunchArgs.user_args():
		if a == "--peak=0" or a == "--no-peak": return null
		if a.begins_with("--peak-at="):
			var xz := a.get_slice("=",1).split(",")
			if xz.size() == 2: at = Vector2(float(xz[0]),float(xz[1]))
		elif a.begins_with("--peak-yaw="): yaw = float(a.get_slice("=",1))
	var coded := Transform3D(Basis(Vector3.UP,deg_to_rad(yaw)),Vector3(at.x,0.0,at.y))
	return new(land_seed,LayoutOverrides.xform(HANDLE,coded))

func _init(land_seed: int, frame: Transform3D) -> void:
	centre = Vector2(frame.origin.x,frame.origin.z)
	var f := frame.basis.z
	facing = Vector2(f.x,f.z).normalized()
	side = Vector2(-facing.y,facing.x)
	_o = centre+facing*O_ALONG
	_cw = WorldScale.opening(TOY_COULOIR)*0.5
	_noise.seed = hash([land_seed,"peak"]) & 0x7fffffff
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0/ROUGH_SCALE
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = 4
	for t: float in TOWER_TH:
		for s: float in [-1.0,1.0]:
			var r := deg_to_rad(t)
			_towers.append(Vector2(O_ALONG-RING_R*cos(r),s*RING_R*sin(r)))
			_tower_tops.append(_crest(t)+TOWER_UP)

# --- Asked by the land field ----------------------------------------------------------

## Whether (x, z) lies inside the bounding circle (one distance check).
func reaches(x: float, z: float) -> bool:
	var dx := x-_o.x
	var dz := z-_o.y
	return dx*dx+dz*dz < BOUND*BOUND

## Whether the box (x0, z0)..(x1, z1) meets the bounding circle.
func meets(x0: float, z0: float, x1: float, z1: float) -> bool:
	var dx := _o.x-clampf(_o.x,x0,x1)
	var dz := _o.y-clampf(_o.y,z0,z1)
	return dx*dx+dz*dz < BOUND*BOUND

## Whether a site of reach `r` at (x, z) stays clear of the massif (the
## ponds, tunnels, halls and splits keep out of it).
func clear(x: float, z: float, r: float) -> bool:
	return Vector2(x,z).distance_to(_o) > BOUND+r

## The land's Vector2(world height, meadow) `base` at (x, z) with the massif
## on it (the caller checked `reaches`). Sets `last_lift`.
func apply(base: Vector2, x: float, z: float) -> Vector2:
	var q := Vector2(x,z)-centre
	var hm := _h(q.dot(facing),q.dot(side))
	var by := base.x-SEA_Y
	var y := lerpf(maxf(by,hm.x),hm.x,hm.y)
	last_lift = y-by
	var m := maxf(base.y*(1.0-smoothstep(0.5,6.0,absf(last_lift))),hm.z)
	return Vector2(y+SEA_Y,m)

## The massif's pass over a chunk's arrays (LandField.build_chunk; its
## args), after every other layer's: heights, then the normals (central
## differences, as the field's) and colours round what moved, the skirt's
## copies of the edges. The land's heights one step outside the chunk come
## back from its edge normals (each is (left-right, 2 step, down-up)), so
## the edges' normals need no field sample. `field` the LandField (its
## `colours`).
func apply_chunk(field: Object, _impl: Object, made: Dictionary, x0: float, z0: float, step: float, cells: int, skirt_drop: float) -> void:
	var n := cells+1
	var w := n+2
	var heights: PackedFloat32Array = made.heights
	var verts: PackedVector3Array = made.verts
	var normals: PackedVector3Array = made.normals
	var colours: PackedColorArray = made.colours
	var carved: PackedByteArray = made.carved
	var river: PackedFloat32Array = made.river
	# The padded grid's heights (a ring of one step round the chunk, its
	# corners unused) and which moved; which vertices the massif lifted.
	var hs := PackedFloat32Array()
	hs.resize(w*w)
	var mv := PackedByteArray()
	mv.resize(w*w)
	var lifted := PackedByteArray()
	lifted.resize(n*n)
	var any := false
	var r2 := BOUND*BOUND
	var fx := facing.x
	var fz := facing.y
	var sx := side.x
	var sz := side.y
	for jj in w:
		var j := jj-1
		var j_out := j < 0 or j > cells
		for ii in w:
			var i := ii-1
			var i_out := i < 0 or i > cells
			if i_out and j_out: continue
			var base: float
			var v := j*n+i
			if not i_out and not j_out: base = heights[v]
			elif i < 0:
				v = j*n
				base = heights[v+1]+2.0*step*normals[v].x/normals[v].y
			elif i_out:
				v = j*n+cells
				base = heights[v-1]-2.0*step*normals[v].x/normals[v].y
			elif j < 0:
				v = i
				base = heights[v+n]+2.0*step*normals[v].z/normals[v].y
			else:
				v = cells*n+i
				base = heights[v-n]-2.0*step*normals[v].z/normals[v].y
			var k := jj*w+ii
			hs[k] = base
			var x := x0+i*step
			var z := z0+j*step
			var dx := x-_o.x
			var dz := z-_o.y
			if dx*dx+dz*dz >= r2: continue
			var qx := x-centre.x
			var qz := z-centre.y
			var hm := _h(qx*fx+qz*fz,qx*sx+qz*sz)
			var by := base-SEA_Y
			var y := lerpf(maxf(by,hm.x),hm.x,hm.y)
			var lift := y-by
			if not i_out and not j_out:
				var c := colours[v]
				var m := maxf(c.a*(1.0-smoothstep(0.5,6.0,absf(lift))),hm.z)
				if absf(lift) <= 0.0005 and absf(m-c.a) <= 0.002: continue
				c.a = m
				colours[v] = c
				if absf(lift) > 1.0: lifted[v] = 1
			elif absf(lift) <= 0.0005: continue
			hs[k] = y+SEA_Y
			mv[k] = 1
			any = true
	if not any: return
	# Normals and colours wherever a height round them moved.
	var redo := PackedInt32Array()
	for j in n:
		for i in n:
			var k := (j+1)*w+i+1
			if mv[k]+mv[k-1]+mv[k+1]+mv[k-w]+mv[k+w] > 0: redo.append(j*n+i)
	var xs := PackedFloat64Array()
	var zs := PackedFloat64Array()
	var ys := PackedFloat32Array()
	var ups := PackedFloat32Array()
	var ms := PackedFloat32Array()
	xs.resize(redo.size())
	zs.resize(redo.size())
	ys.resize(redo.size())
	ups.resize(redo.size())
	ms.resize(redo.size())
	for t in redo.size():
		var v := redo[t]
		var i := v%n
		var j := v/n
		var k := (j+1)*w+i+1
		var normal := Vector3(hs[k-1]-hs[k+1],2.0*step,hs[k-w]-hs[k+w]).normalized()
		normals[v] = normal
		heights[v] = hs[k]
		verts[v] = Vector3(verts[v].x,hs[k],verts[v].z)
		xs[t] = x0+i*step
		zs[t] = z0+j*step
		ys[t] = hs[k]
		ups[t] = normal.y
		ms[t] = colours[v].a
		if mv[k] != 0:
			# Off the carve's marks (the field's groove and crest).
			carved[v*4] = 0
			carved[v*4+1] = 0
		if lifted[v] != 0:
			# No river on the massif: far from any, its flow still.
			carved[v*4+2] = 128
			carved[v*4+3] = 128
			river[v*3] = 1000.0
			river[v*3+1] = 0.0
			river[v*3+2] = SEA_Y-100.0
	var cs: PackedColorArray = field.colours(xs,zs,ys,ups,ms)
	for t in redo.size():
		var c := cs[t]
		c.a = ms[t]
		colours[redo[t]] = c
	# The skirt's copies of the edges.
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

## The massif's pass over LandField.grid's arrays (the grass's, the
## horizon's): heights, meadows, and no river where it lifts the land.
func apply_grid(got: Dictionary, x0: float, z0: float, step: float, nx: int, nz: int, pad: int) -> void:
	var hs: PackedFloat32Array = got.heights
	var ms: PackedFloat32Array = got.meadows
	var rs: PackedFloat32Array = got.river
	var i0 := clampi(floori((_o.x-BOUND-x0)/step)+pad,0,nx-1)
	var i1 := clampi(ceili((_o.x+BOUND-x0)/step)+pad,0,nx-1)
	var j0 := clampi(floori((_o.y-BOUND-z0)/step)+pad,0,nz-1)
	var j1 := clampi(ceili((_o.y+BOUND-z0)/step)+pad,0,nz-1)
	for j in range(j0,j1+1):
		for i in range(i0,i1+1):
			var x := x0+(i-pad)*step
			var z := z0+(j-pad)*step
			if not reaches(x,z): continue
			var k := j*nx+i
			var m := ms[k] if not ms.is_empty() else 0.0
			var y := apply(Vector2(hs[k],m),x,z)
			hs[k] = y.x
			if not ms.is_empty(): ms[k] = y.y
			if absf(last_lift) > 1.0 and not rs.is_empty(): rs[k] = 1000.0
	got.heights = hs
	if not ms.is_empty(): got.meadows = ms
	if not rs.is_empty(): got.river = rs

# --- For the trunk and the lanes -----------------------------------------------------

## A world XZ point at (a, v) in the massif's frame.
func world(a: float, v := 0.0) -> Vector2:
	return centre+facing*a+side*v

## The tarn's bowl: {centre (world, at the water level), level (world y),
## wet (the water's radius at that level), bowl (the bowl's radius), shore
## (the flat shore's reach from the plateau's centre), plateau (world XZ)}.
func tarn() -> Dictionary:
	var c := world(-TARN_BACK)
	var wet := TARN_BOWL*sqrt(1.0-pow((PLATEAU_Y-TARN_LEVEL)/TARN_DEEP,2.0/3.0))
	return {"centre":Vector3(c.x,TARN_LEVEL+SEA_Y,c.y),"level":TARN_LEVEL+SEA_Y,"wet":wet,"bowl":TARN_BOWL,
		"shore":PLATEAU_FLAT,"plateau":centre}

## The couloir: {mouth, top (world, on its floor), half_width}.
func couloir() -> Dictionary:
	var m := world(COULOIR_FOOT.x)
	var t := world(COULOIR_TOP.x)
	return {"mouth":Vector3(m.x,COULOIR_FOOT.y+SEA_Y,m.y),"top":Vector3(t.x,COULOIR_TOP.y+SEA_Y,t.y),"half_width":_cw}

## The tower bases' tops (world), for the spires.
func tower_bases() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for k in _towers.size():
		var p := world(_towers[k].x,_towers[k].y)
		out.append(Vector3(p.x,_tower_tops[k]+SEA_Y,p.y))
	return out

## The summit block's top (world).
func summit() -> Vector3:
	var p := world(SUMMIT_AT.x,SUMMIT_AT.y)
	return Vector3(p.x,SUMMIT_Y+SEA_Y,p.y)

# --- The profile -------------------------------------------------------------------

## The crest's height over the sea at `th` degrees from the back.
static func _crest(th: float) -> float:
	var k := 0
	while k+4 < CREST.size() and th > float(CREST[k+2]): k += 2
	var t0: float = CREST[k]
	var t1: float = CREST[k+2]
	return lerpf(float(CREST[k+1]),float(CREST[k+3]),clampf((th-t0)/(t1-t0),0.0,1.0))

## The wall `e` m in from a crest at `hc`: talus, then a cliff.
static func _wall(e: float, hc: float) -> float:
	if e >= WALL_RUN: return WALL_FOOT-(e-WALL_RUN)*TALUS_FALL
	var t := 1.0-maxf(e,0.0)/WALL_RUN
	return WALL_FOOT+(hc-WALL_FOOT)*(TALUS_SHARE*smoothstep(0.0,TALUS_TOP,t)+(1.0-TALUS_SHARE)*smoothstep(CLIFF.x,CLIFF.y,t))

## A fall from `top` over `run` m to FALL_END, steep first (`bow` > 1), on
## past its run at PAST_END.
static func _fall(top: float, d: float, run: float, bow: float) -> float:
	if d >= run: return FALL_END-(d-run)*PAST_END
	return top-(top-FALL_END)*(1.0-pow(1.0-d/run,bow))

## Vector3(height over the sea, cut 0..1, meadow) at (a, v) in the frame.
func _h(a: float, v: float) -> Vector3:
	var n := _noise.get_noise_2d(a,v)
	var av := absf(v)
	var oa := a-O_ALONG
	var r := sqrt(oa*oa+v*v)
	var th := rad_to_deg(atan2(av,-oa))
	var h := -INF
	var c := 0.0
	var meadow := 0.0
	# The ring.
	if th < ARM_END+10.0:
		var hc := _crest(th)
		var d := r-RING_R
		var rough := 1.0
		var hr: float
		if d < 0.0:
			var e := -d
			var hw := _wall(e,hc)
			var ha := hc-e*lerpf(ARM_IN.x,ARM_IN.y,smoothstep(0.0,500.0,e))
			hr = lerpf(ha,hw,1.0-smoothstep(30.0,60.0,th))
		else:
			var ws := 1.0-smoothstep(5.0,16.0,th)
			var hs: float
			if d < SHOULDER.x: hs = lerpf(hc,PLATEAU_Y,smoothstep(0.0,SHOULDER.x,d))
			elif d < SHOULDER.y: hs = PLATEAU_Y
			elif d < SHOULDER.z: hs = lerpf(PLATEAU_Y,LIP_Y,smoothstep(SHOULDER.y,SHOULDER.z,d))
			else: hs = _fall(LIP_Y,d-SHOULDER.z,BACK_RUN,BACK_BOW)
			var hb := lerpf(_fall(hc,d,BACK_RUN,KNIFE_BOW),hs,ws)
			hr = lerpf(_fall(hc,d,ARM_OUT_RUN,ARM_OUT_BOW),hb,1.0-smoothstep(35.0,70.0,th))
			rough = lerpf(1.0,0.15,ws*smoothstep(40.0,SHOULDER.x,d)*(1.0-smoothstep(SHOULDER.y+20.0,SHOULDER.z+60.0,d)))
		# The arms' tips sink under the land.
		hr -= 400.0*smoothstep(160.0,ARM_END+8.0,th)
		h = hr+n*ROUGH*rough
		c = (1.0-smoothstep(RING_R,RING_R+150.0,r))*(1.0-smoothstep(130.0,160.0,th))
	# The approach valley.
	var vl := _valley(a,av,n)
	if vl.x > h: h = vl.x
	c = maxf(c,vl.y)
	# The couloir, cut into the wall.
	if av < _cw+COULOIR_SOFT and a > 150.0 and a < COULOIR_FOOT.x+40.0:
		var k := (1.0-smoothstep(_cw-COULOIR_SOFT,_cw+COULOIR_SOFT,av))*(1.0-smoothstep(COULOIR_FOOT.x-40.0,COULOIR_FOOT.x+40.0,a))
		# Its floor the wall set back COULOIR_BACK m, no higher than the ramp
		# from the mouth to the crest's notch.
		var fc: float
		if a >= COULOIR_TOP.x:
			fc = COULOIR_FOOT.y+(COULOIR_FOOT.x-a)*(COULOIR_TOP.y-COULOIR_FOOT.y)/(COULOIR_FOOT.x-COULOIR_TOP.x)
		else: fc = COULOIR_TOP.y+(COULOIR_TOP.x-a)*1.5
		fc = minf(fc,_wall(a+COULOIR_BACK-(O_ALONG-RING_R),_crest(0.0)))+n*ROUGH*0.25
		if fc < h: h = lerpf(h,fc,k)
	# The plateau and the tarn's bowl.
	var rho2 := a*a+v*v
	if rho2 < PLATEAU_BLEND*PLATEAU_BLEND:
		var wf := 1.0-smoothstep(PLATEAU_FLAT,PLATEAU_BLEND,sqrt(rho2))
		var ta := a+TARN_BACK
		var rt := sqrt(ta*ta+v*v)
		var hp := PLATEAU_Y
		if rt < TARN_BOWL: hp -= TARN_DEEP*pow(1.0-(rt/TARN_BOWL)*(rt/TARN_BOWL),1.5)
		h = lerpf(h,hp,wf)
		c = maxf(c,wf)
		var wet := TARN_BOWL*sqrt(1.0-pow((PLATEAU_Y-TARN_LEVEL)/TARN_DEEP,2.0/3.0))
		meadow = wf*smoothstep(wet,wet+6.0,rt)
	# The summit block.
	var sa := absf(a-SUMMIT_AT.x)
	var sv := absf(v-SUMMIT_AT.y)
	if sa < SUMMIT_HALF.x*1.3 and sv < SUMMIT_HALF.y*1.3:
		var qa := sa/SUMMIT_HALF.x
		var qv := sv/SUMMIT_HALF.y
		var q := pow(qa*qa*qa*qa+qv*qv*qv*qv,0.25)
		var hb := SUMMIT_Y-8.0*q*q-maxf(q-0.96,0.0)*900.0+n*ROUGH*0.5
		if hb > h:
			h = hb
			meadow = 0.0
	# The tower bases on the crest.
	if th < 42.0 and absf(r-RING_R) < 70.0:
		for k in _towers.size():
			var dt := Vector2(a,v).distance_to(_towers[k])
			if dt > TOWER_R+60.0: continue
			var ht := _tower_tops[k]-maxf(dt-TOWER_R,0.0)*TOWER_FALL+n*ROUGH*0.2
			if ht > h: h = ht
	return Vector3(h,c,meadow)

## The approach valley at (a, |v|): Vector2(height over the sea, cut).
func _valley(a: float, av: float, n: float) -> Vector2:
	var fl: float
	var half: float
	var rough := 0.0
	if a < ICEFALL.x:
		fl = ICEFALL_Y.x-(ICEFALL.x-a)
		half = FLOOR_HALF.x
		rough = 0.6
	elif a < ICEFALL.y:
		var s := (a-ICEFALL.x)/(ICEFALL.y-ICEFALL.x)*ICEFALL_STEPS
		var k := floorf(s)
		var g := (k+smoothstep(0.0,ICEFALL_RISER,s-k))/ICEFALL_STEPS
		fl = lerpf(ICEFALL_Y.x,ICEFALL_Y.y,g)
		half = FLOOR_HALF.x
		rough = 0.5
	elif a < BOULDERS.y:
		var t := (a-BOULDERS.x)/(BOULDERS.y-BOULDERS.x)
		fl = lerpf(BOULDERS_Y.x,BOULDERS_Y.y,t)+_noise.get_noise_2d(a*LUMP_SCALE,av*LUMP_SCALE)*LUMPS
		half = lerpf(FLOOR_HALF.x,FLOOR_HALF.y,smoothstep(0.0,0.3,t))
		rough = 0.35
	elif a < GLACIER.y:
		var t := (a-GLACIER.x)/(GLACIER.y-GLACIER.x)
		fl = lerpf(GLACIER_Y.x,GLACIER_Y.y,pow(t,0.9))
		half = lerpf(FLOOR_HALF.z,FLOOR_HALF.w,t)
		# The boulders' lumps fade out onto the ice.
		fl += _noise.get_noise_2d(a*LUMP_SCALE,av*LUMP_SCALE)*LUMPS*(1.0-smoothstep(0.0,0.06,t))
		rough = 0.35*(1.0-smoothstep(0.0,0.06,t))
	else:
		fl = _fall(GLACIER_Y.y,a-TOE.x,TOE.y-TOE.x,1.0)
		half = FLOOR_HALF.w
		rough = 0.2
	var e := av-half
	var h: float
	if e <= 0.0: h = fl
	elif e <= SIDE_RUN:
		h = fl+SIDE_UP*smoothstep(0.0,SIDE_RUN,e)
		rough = lerpf(rough,0.6,smoothstep(0.0,60.0,e))
	else:
		# Inside the horseshoe the side ridges' outer fall stops a little under
		# the floor; out on the glacier it falls to the land.
		h = maxf(fl+SIDE_UP-(e-SIDE_RUN)*SIDE_FALL,fl-SIDE_DIP-maxf(0.0,a-SIDE_DIP_TO)*0.5)
		rough = 0.6
	var c := (1.0-smoothstep(SIDE_RUN,SIDE_RUN+90.0,e))*(1.0-smoothstep(TOE.x,TOE.x+400.0,a))
	return Vector2(h+n*ROUGH*rough,c)
