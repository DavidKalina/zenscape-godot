extends RefCounted
## Builds a rock group (scripts/endless/rocks/rock_plan.gd, a kind's spec)
## on a worker: plain data, no nodes. Every kind's pillars go through here,
## so a new kind gets its mesh, levels of detail, collider and flight solid
## for nothing.
##
## Each pillar is lofted: rings every `ring_every` m from its buried foot to
## its top (the kind's control rings between), SEGMENTS points a ring, each
## pushed in and out by world-space noise sized to the rock (lumps, a finer
## grain, beds standing out and in), the top closed by a fan to its middle.
## The ring count is a multiple of 4, so level L (stride 2^L in rings and
## points) indexes the same vertices: three levels in one ArrayMesh, Godot
## picking by the screen size of each level's error (`lods`). The group's
## pillars are one mesh (one draw). It takes the land's ground material,
## as the rock arches do (scripts/endless/arch_build.gd), so faces read as
## the land's rock and flat tops grow its turf.
##
## The collider is a trimesh of level 1 (a quarter of the triangles) a
## pillar, on layer 1. The flight's solid (`solid`): per pillar, per ring, its centre
## and SECTORS radii (the most any point reaches in that turn of the ring
## and its neighbours), read by scripts/endless/land_rocks.gd.

const Field = preload("res://scripts/endless/land_field.gd")
const WorldScale = preload("res://scripts/world_scale.gd")

## Points a ring (a multiple of 4; a pillar's `segments` sets its own), the
## solid's sectors a ring, the levels.
const SEGMENTS := 20
const SECTORS := 16
const LEVELS := 3
## Each level's error (m) as shares of the group's typical radius and its
## ring spacing: the size at which Godot swaps it in (mesh_lod_threshold).
const LOD_ERROR := [Vector2(0.06,0.25),Vector2(0.2,0.6)]

static func wingtip() -> float:
	return WorldScale.span*0.5

## A built group: {spec, arrays (level 0's surface), lods ({error: indices}),
## faces (the collider's, a PackedVector3Array a pillar), solid ([pillar
## solid...]), tris ([per level])}.
static func build(spec: Dictionary) -> Dictionary:
	var pos: Vector3 = spec.pos
	var v := PackedVector3Array()
	var c := PackedColorArray()
	var levels: Array = []
	for l in range(LEVELS): levels.append(PackedInt32Array())
	var solid: Array = []
	var radii := PackedFloat32Array()
	var spacing := 0.0
	var cuts: Array = [0]
	for p: Dictionary in spec.pillars:
		var s := _pillar(v,c,levels,p,pos)
		cuts.append((levels[1] as PackedInt32Array).size())
		solid.append(s)
		radii.append(float(s.size))
		spacing = maxf(spacing,float(s.dy))
	var n := _normals(v,levels[0])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_COLOR] = c
	arrays[Mesh.ARRAY_INDEX] = levels[0]
	radii.sort()
	var typical := radii[radii.size()/2] if not radii.is_empty() else 4.0
	var lods := {}
	var tris: Array = [levels[0].size()/3]
	for l in range(1,LEVELS):
		var e: Vector2 = LOD_ERROR[l-1]
		lods[e.x*typical+e.y*spacing] = levels[l]
		tris.append((levels[l] as PackedInt32Array).size()/3)
	# The collider: a trimesh of level 1 a pillar, so they can be added a
	# few at a time (scripts/endless/land_rocks.gd).
	var coarse: PackedInt32Array = levels[1]
	var faces: Array = []
	for k in range(cuts.size()-1):
		var f := PackedVector3Array()
		f.resize(int(cuts[k+1])-int(cuts[k]))
		for i in range(f.size()): f[i] = v[coarse[int(cuts[k])+i]]
		faces.append(f)
	return {"spec":spec,"arrays":arrays,"lods":lods,"faces":faces,"solid":solid,"tris":tris}

## The control ring at height `y` (linear between them): [rx, rz, ox, oz].
static func _at(profile: Array, y: float) -> Array:
	var last: Array = profile[profile.size()-1]
	if y >= float(last[0]): return [float(last[1]),float(last[2]),float(last[3]),float(last[4])]
	var prev: Array = profile[0]
	if y <= float(prev[0]): return [float(prev[1]),float(prev[2]),float(prev[3]),float(prev[4])]
	for k in range(1,profile.size()):
		var q: Array = profile[k]
		if y <= float(q[0]):
			var t := (y-float(prev[0]))/maxf(float(q[0])-float(prev[0]),0.0001)
			return [lerpf(float(prev[1]),float(q[1]),t),lerpf(float(prev[2]),float(q[2]),t),lerpf(float(prev[3]),float(q[3]),t),lerpf(float(prev[4]),float(q[4]),t)]
		prev = q
	return [float(last[1]),float(last[2]),float(last[3]),float(last[4])]

## One pillar's rings into the shared arrays, its triangles into each
## level; returns its solid {c, r, y0, dy, rings, top, mid, reach, size}
## (local to the group's pos).
static func _pillar(v: PackedVector3Array, c: PackedColorArray, levels: Array, p: Dictionary, pos: Vector3) -> Dictionary:
	var profile: Array = p.profile
	var at: Vector3 = p.at
	var bottom := float(profile[0][0])
	var top := float(profile[profile.size()-1][0])
	var every := float(p.get("ring_every",1.5))
	var rings := maxi(4,int(ceil((top-bottom)/every/4.0))*4)
	var dy := (top-bottom)/rings
	var yaw := float(p.get("yaw",0.0))
	var cy := cos(yaw)
	var sy := sin(yaw)
	var square := float(p.get("square",0.7))
	var noise := FastNoiseLite.new()
	noise.seed = int(p.get("seed",1))
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 1.0
	noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	var lump := float(p.get("lump",6.0))
	var lumps := float(p.get("lumps",0.14))
	var grain := float(p.get("grain",0.05))
	var ledges := float(p.get("ledges",0.06))
	var flutes := float(p.get("flutes",0.0))
	var bed := float(p.get("bed",4.0))
	var tint: Color = p.get("tint",Color(1,1,1))
	var segs := maxi(4,int(ceil(int(p.get("segments",SEGMENTS))/4.0))*4)
	var rock := Field.ROCK
	var first := v.size()
	var centres := PackedVector2Array()
	var rad := PackedFloat32Array()
	rad.resize((rings+1)*SECTORS)
	var size := 0.0
	for i in range(rings+1):
		var y := bottom+i*dy
		var ring := _at(profile,y)
		var rx := float(ring[0])
		var rz := float(ring[1])
		size = maxf(size,minf(rx,rz)) if y > 0.0 and i < rings else size
		var centre := Vector3(at.x+float(ring[2]),at.y+y,at.z+float(ring[3]))
		centres.append(Vector2(centre.x,centre.z))
		# The top ring weathers less, so the cap's edge stays clean.
		var keep := 0.5 if i == rings else 1.0
		for j in range(segs):
			var ang := TAU*j/segs
			var ca := cos(ang)
			var sa := sin(ang)
			var ex := signf(ca)*pow(absf(ca),square)*rx
			var ez := signf(sa)*pow(absf(sa),square)*rz
			var dir := Vector3(ex*cy-ez*sy,0.0,ex*sy+ez*cy)
			var world := pos+centre+dir
			var push := noise.get_noise_3d(world.x/lump,world.y/lump,world.z/lump)*lumps
			push += noise.get_noise_3d(world.x/(lump*0.33)+31.0,world.y/(lump*0.33),world.z/(lump*0.33))*grain
			push += sin(world.y*TAU/bed+noise.get_noise_2d(world.x/(lump*1.5),world.z/(lump*1.5))*4.0)*ledges
			# Joints and rills: noise drawn out up the pillar.
			push += noise.get_noise_3d(world.x/(lump*0.4)+57.0,world.y/(lump*3.0),world.z/(lump*0.4))*flutes
			var q := centre+dir*(1.0+push*keep)
			v.append(q)
			var shade := 0.82+noise.get_noise_3d(world.x/6.0,world.y/2.5,world.z/6.0)*0.22+push*0.6
			c.append(Color(rock.r*shade*tint.r,rock.g*shade*tint.g,rock.b*shade*0.97*tint.b,0.0))
			# The solid: the most the ring reaches in each sector.
			var off := Vector2(q.x-centre.x,q.z-centre.z)
			var k := clampi(int(floor((off.angle()+PI)/TAU*SECTORS)),0,SECTORS-1)
			rad[i*SECTORS+k] = maxf(rad[i*SECTORS+k],off.length())
	# Each sector widened to its neighbours' reach (the chords between
	# points, a sector no point fell in).
	var reach := 0.0
	var mid := Vector2.ZERO
	for i in range(rings+1): mid += centres[i]
	mid /= rings+1
	for i in range(rings+1):
		var row := PackedFloat32Array()
		row.resize(SECTORS)
		for k in range(SECTORS):
			row[k] = maxf(rad[i*SECTORS+k],maxf(rad[i*SECTORS+(k+1)%SECTORS],rad[i*SECTORS+(k+SECTORS-1)%SECTORS]))
		for k in range(SECTORS):
			rad[i*SECTORS+k] = row[k]
			reach = maxf(reach,row[k]+centres[i].distance_to(mid))
	# The top's middle.
	var last := _at(profile,top)
	var dome := float(p.get("dome",0.8))
	v.append(Vector3(at.x+float(last[2]),at.y+top+dome,at.z+float(last[3])))
	c.append(Color(rock.r*0.8,rock.g*0.8,rock.b*0.8,0.0))
	var cap := v.size()-1
	for l in range(levels.size()):
		var s := 1 << l
		var idx: PackedInt32Array = levels[l]
		for i in range(0,rings,s):
			for j in range(0,segs,s):
				var a0 := first+i*segs+j
				var a1 := first+i*segs+(j+s)%segs
				var b0 := a0+s*segs
				var b1 := a1+s*segs
				idx.append_array([a0,b1,b0,a0,a1,b1])
		for j in range(0,segs,s):
			idx.append_array([cap,first+rings*segs+j,first+rings*segs+(j+s)%segs])
		levels[l] = idx
	return {"c":centres,"r":rad,"y0":at.y+bottom,"dy":dy,"rings":rings+1,"top":at.y+top+maxf(dome,0.0),"mid":mid,"reach":reach,"size":size,
		"base":at.y}

## Smooth normals, each facing out the way the skin's winding does.
static func _normals(v: PackedVector3Array, idx: PackedInt32Array) -> PackedVector3Array:
	var n := PackedVector3Array()
	n.resize(v.size())
	for i in range(0,idx.size(),3):
		var f := (v[idx[i+2]]-v[idx[i]]).cross(v[idx[i+1]]-v[idx[i]])
		n[idx[i]] += f
		n[idx[i+1]] += f
		n[idx[i+2]] += f
	for i in range(n.size()): n[i] = n[i].normalized() if n[i].length_squared() > 0.0 else Vector3.UP
	return n
