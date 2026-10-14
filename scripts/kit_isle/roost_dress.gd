extends RefCounted
## The dragon's roost dressed as a lair (docs/design/dragon-roost/round3.md):
## what the mountain (scripts/kit_isle/motif_dragon_roost.gd) builds on its
## rock besides the land itself. All of it built on a worker with the rest
## of the motif: nodes and meshes only, no scene, no physics queries.
##
## - `tower`: the old tower on the summit crown the dragon coils under, in
##   the ruin kit's own stone (RuinKit.Build): an octagonal shell of coursed
##   blocks, its top sheared off in a long slant from a broken tooth on its
##   far side down toward the aqueduct isle, lancet slits, two string
##   courses, stepped buttresses at its foot, fallen blocks round it, the
##   upper courses sooted dark.
## - `dead_tree`: a bare, bent tree, leaning away from the summit.
## - `airship_wreck`: a sky folk airship's frame caught on a crag, its rings
##   broken, a few charred canvas gores left, its gondola hanging off it.
## - `gouges`: claw marks raked into the rock: each a few parallel grooves,
##   dark in the middle, fresh pale stone at their edges, laid on the drawn
##   faces (`Faces`: the land's own triangles, looked up by cell).
const RuinKit = preload("res://scripts/ruin_kit.gd")
const AirshipBuild = preload("res://scripts/airship_build.gd")
const Builds = preload("res://scripts/showcase_builds.gd")
const SURFACE := preload("res://shaders/airship_surface.gdshader")

## Soot on the old stone (sRGB) and the wreck's char.
const SOOT := Color("1b1816")
const CHAR := Color("1a1512")

# --- The tower ---------------------------------------------------------------------

## The old tower, its axis at the origin, its foot `sunk` m under y 0 (the
## crown it stands in), `height` m to the top of its broken tooth's side,
## octagonal, `outer` m to the middle of a face, its wall `wall` thick, its
## high side toward `high_side` (radians, from +x toward +z). `ground`
## (x, z) -> y in its frame: where its fallen blocks lie.
## The tower's shell's top at angle `a`: a long slant from the high side
## round to the low, a broken tooth standing just off the high side, ragged.
static func tower_top(a: float, high_side: float, height: float, jag: PackedFloat32Array) -> float:
	var off := wrapf(a-high_side,-PI,PI)
	var t := 0.5+0.5*cos(off)
	var h := height*(0.38+0.5*pow(t,1.3))
	h += height*0.2*maxf(0.0,1.0-absf(off-0.42)/0.3)
	var u := fposmod(a,TAU)/TAU*36.0
	var i := int(u)
	h += 1.3*lerpf(jag[i],jag[i+1],u-float(i))
	return h

static func tower(seed_value: int, height: float, outer: float, wall: float, high_side: float, sunk: float, ground: Callable) -> Node3D:
	var b := RuinKit.Build.new(seed_value,0.8,"DragonTower")
	b.terrain = ground
	var inner := outer-wall
	var half_side := outer*tan(PI/8.0)
	var jag := PackedFloat32Array()
	for i in range(37): jag.append(b.rng.randf_range(-1.0,1.0))
	# The shell's top by angle (`tower_top`; a static function bound, not a
	# lambda, so the isle store can keep the tower's "top" meta).
	var top := tower_top.bind(high_side,height,jag)
	var slits := [1,3,5,6]
	var bands := [height*0.3,height*0.58]
	for side in range(8):
		var a := TAU*side/8.0
		var n := Vector3(cos(a),0.0,sin(a))
		var along := Vector3(-sin(a),0.0,cos(a))
		var s0 := Vector3(cos(a-PI/8.0),0.0,sin(a-PI/8.0))
		var s1 := Vector3(cos(a+PI/8.0),0.0,sin(a+PI/8.0))
		var left := Plane(-s0.cross(Vector3.UP).normalized(),0.01)
		var right := Plane(s1.cross(Vector3.UP).normalized(),0.01)
		var most := maxf(float(top.call(a)),maxf(float(top.call(a-PI/8.0)),float(top.call(a+PI/8.0))))
		var y := -sunk
		var k := 0
		while y < most:
			var y1 := y+b.rng.randf_range(1.25,1.65)
			var cuts: Array[float] = [-1.0]
			var slit: bool = side in slits and ((y > height*0.18 and y < height*0.18+6.0) or (y > height*0.44 and y < height*0.44+5.0))
			if slit: cuts.append_array([-0.12,0.12])
			elif k%2 == 0: cuts.append(b.rng.randf_range(-0.3,0.3))
			else: cuts.append_array([-0.4+b.rng.randf_range(-0.08,0.08),0.36+b.rng.randf_range(-0.08,0.08)])
			cuts.append(1.0)
			for c in range(cuts.size()-1):
				if slit and c == 1: continue
				var u0 := cuts[c]*half_side*1.3
				var u1 := cuts[c+1]*half_side*1.3
				var mid := (u0+u1)*0.5
				var am := a+atan2(mid,outer)
				var here := float(top.call(am))
				if y+1.0 > here: continue
				var planes: Array[Plane] = [Plane(n,outer),Plane(-n,-inner),Plane(Vector3.DOWN,-y),Plane(Vector3.UP,y1)]
				planes.append(left if c == 0 else Plane(-along,-u0-0.01))
				planes.append(right if c == cuts.size()-2 else Plane(along,u1-0.01))
				var extra: Array[Plane] = []
				if y1 > here:
					var m := (Vector3.UP+n*b.rng.randf_range(-0.5,0.5)+along*b.rng.randf_range(-0.8,0.8)).normalized()
					extra.append(Plane(m,m.dot(n*outer+along*mid+Vector3.UP*here)))
				b.solid(planes,RuinKit._settle(b,Vector3.ZERO,0.4),_sooted(b,am,y,height),true,true,extra)
			# A string course where the shell still stands over it.
			for band: float in bands:
				if y <= band and y1 > band and minf(float(top.call(a-PI/8.0)),float(top.call(a+PI/8.0))) > band+1.5:
					var planes: Array[Plane] = [Plane(n,outer+0.45),Plane(-n,-(outer-0.4)),Plane(Vector3.DOWN,-band),Plane(Vector3.UP,band+0.6),left,right]
					var m := (n+Vector3.UP*1.2).normalized()
					planes.append(Plane(m,m.dot(n*(outer+0.1)+Vector3.UP*(band+0.6))))
					b.solid(planes,Transform3D.IDENTITY,_sooted(b,a,band,height)*1.08)
			y = y1
			k += 1
	# Stepped buttresses at three of its corners (the fourth fallen).
	var corners := [0.5,2.5,4.5,6.5]
	var fallen := b.rng.randi_range(0,3)
	for ci in range(corners.size()):
		var a := TAU*float(corners[ci])/8.0
		var n := Vector3(cos(a),0.0,sin(a))
		var along := Vector3(-sin(a),0.0,cos(a))
		var corner := outer/cos(PI/8.0)
		var stages := [[5.0,height*0.16],[3.4,height*0.3],[1.8,height*0.42]]
		if ci == fallen: stages = [[5.0,height*0.1]]
		var y := -sunk
		for st: Array in stages:
			var depth: float = st[0]
			var high: float = st[1]
			while y < high-0.3:
				var y1 := minf(high,y+b.rng.randf_range(2.2,3.0))
				var planes: Array[Plane] = [Plane(n,corner+depth),Plane(-n,-(corner-1.0)),Plane(along,1.4),Plane(-along,1.4),Plane(Vector3.DOWN,-y),Plane(Vector3.UP,y1)]
				if y1 >= high-0.01:
					var m := (n+Vector3.UP*1.1).normalized()
					planes.append(Plane(m,m.dot(n*(corner+depth*0.35)+Vector3.UP*high)))
				b.solid(planes,RuinKit._settle(b,Vector3.ZERO,0.3),_sooted(b,a,y,height)*0.95)
				y = y1
	# Fallen blocks round its foot, the bigger lower.
	for i in range(26):
		var a := b.rng.randf()*TAU
		var r := outer+b.rng.randf_range(1.5,9.0)
		var s := Vector3(b.rng.randf_range(0.8,1.9),b.rng.randf_range(0.5,0.9),b.rng.randf_range(0.7,1.4))
		var at := Vector3(cos(a)*r,0.0,sin(a)*r)
		at.y = b.floor_at(at.x,at.z)+s.y*0.5
		var pose := Transform3D(Basis(Vector3.UP,b.rng.randf()*TAU)*Basis(Vector3.RIGHT,b.rng.randf_range(-0.4,0.4))*Basis(Vector3.BACK,b.rng.randf_range(-0.3,0.3)),at)
		b.solid(RuinKit._box(b,s),pose,_sooted(b,a,0.0,height)*0.9,true,true,[],-1,1.5)
	var root := b.finish()
	root.set_meta("top",top)
	return root

## A block's colour: the kit's stone, sooted the more the higher it stands
## and in streaks round the shell.
static func _sooted(b: RuinKit.Build, a: float, y: float, height: float) -> Color:
	var c := RuinKit._stone(b,0.9)
	var streak := smoothstep(0.1,0.6,b.noise.get_noise_2d(a*5.0,y*0.04))
	var soot := clampf(0.3+0.4*smoothstep(0.15,0.9,y/height)+0.45*streak,0.0,0.95)
	return c.lerp(SOOT,soot)

# --- Dead trees ----------------------------------------------------------------------

## A bare dead tree, `tall` m, its foot at the origin, bent over toward
## `lean` (flat, its length the lean's share: 0.3 a strong one), `charred`
## 0..1 (bleached grey to burnt black). Drawn in `material`.
static func dead_tree(seed_value: int, tall: float, lean: Vector2, charred: float, material: Material) -> MeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := Builds._begin()
	var wood := Color("8a8278").lerp(Color("2a2420"),charred)
	var bend := Vector3(lean.x,0.0,lean.y)
	var r := tall*0.055
	var at := Vector3(0.0,-0.4,0.0)
	var up := (Vector3.UP+bend*0.6).normalized()
	var segs := 4
	for k in range(segs):
		var t := float(k+1)/segs
		up = (up+bend*0.35*t+Vector3(rng.randf_range(-0.12,0.12),0.0,rng.randf_range(-0.12,0.12))).normalized()
		var next := at+up*tall/segs*(1.15 if k == 0 else 1.0)
		var r1 := r*(1.0-0.22*float(k+1))
		_limb(st,at,next,r*(1.0-0.22*k),r1,wood*rng.randf_range(0.9,1.08))
		# Branches off the upper trunk: thin, crooked, mostly bent the same way.
		if k >= 1:
			for j in range(rng.randi_range(1,2)):
				var side := Vector3(rng.randf_range(-1,1),0.0,rng.randf_range(-1,1)).normalized()
				var dir := (side*0.8+Vector3.UP*rng.randf_range(0.3,0.9)+bend*1.2).normalized()
				var from := at.lerp(next,rng.randf_range(0.3,0.9))
				var length := tall*rng.randf_range(0.22,0.4)*(1.0-0.15*k)
				var mid := from+dir*length*0.55
				_limb(st,from,mid,r1*0.55,r1*0.35,wood)
				var dir2 := (dir+Vector3(rng.randf_range(-0.6,0.6),rng.randf_range(-0.2,0.4),rng.randf_range(-0.6,0.6))+bend*0.5).normalized()
				_limb(st,mid,mid+dir2*length*0.5,r1*0.35,r1*0.12,wood)
				if rng.randf() < 0.6:
					var dir3 := (dir+Vector3(rng.randf_range(-1,1),0.5,rng.randf_range(-1,1))).normalized()
					_limb(st,mid,mid+dir3*length*0.35,r1*0.25,r1*0.08,wood)
		at = next
	# A snapped top.
	_limb(st,at,at+up*tall*0.08+bend*0.4,r*0.15,r*0.04,wood)
	var mi := MeshInstance3D.new()
	mi.mesh = Builds._end(st)
	mi.material_override = material
	mi.name = "DeadTree"
	return mi

## A five-sided limb from `a` (radius `ra`) to `b` (radius `rb`).
static func _limb(st: SurfaceTool, a: Vector3, b: Vector3, ra: float, rb: float, colour: Color) -> void:
	var along := b-a
	if along.length() < 0.01: return
	var z := along.normalized()
	var x := z.cross(Vector3.UP if absf(z.y) < 0.95 else Vector3.RIGHT).normalized()
	var y := z.cross(x).normalized()
	var linear := colour.srgb_to_linear()
	for k in range(5):
		var t0 := TAU*k/5.0
		var t1 := TAU*(k+1)/5.0
		var a0 := a+(x*cos(t0)+y*sin(t0))*ra
		var a1 := a+(x*cos(t1)+y*sin(t1))*ra
		var b0 := b+(x*cos(t0)+y*sin(t0))*rb
		var b1 := b+(x*cos(t1)+y*sin(t1))*rb
		_tri(st,a0,b0,b1,a,b,linear)
		_tri(st,a0,b1,a1,a,b,linear)
	_tri(st,b+(x)*rb,b+(x*cos(TAU/5.0)+y*sin(TAU/5.0))*rb,b+(x*cos(TAU*2.0/5.0)+y*sin(TAU*2.0/5.0))*rb,b-z,b-z,linear)

static func _tri(st: SurfaceTool, p: Vector3, q: Vector3, r: Vector3, a: Vector3, b: Vector3, linear: Color) -> void:
	var n := (q-p).cross(r-p)
	if n.length_squared() < 1e-12: return
	var inside := (a+b)*0.5
	if n.dot((p+q+r)/3.0-inside) > 0.0:
		var s := q
		q = r
		r = s
	for v: Vector3 in [p,q,r]:
		st.set_color(linear)
		st.add_vertex(v)

# --- The airship wreck --------------------------------------------------------------

## A sky folk airship's frame caught on a crag: the envelope's rings along
## its length (`length` m, radius `radius`), broken, joined by a keel and a
## few stringers (some snapped short), a few charred canvas gores left
## between them; laid along `axis` (its own frame: from its middle), the
## low end drooping. Its gondola (`gondola_at`, frame) hangs from the low
## end on two lines. Drawn in `material`. Seeded.
static func airship_wreck(seed_value: int, length: float, radius: float, material: Material) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var root := Node3D.new()
	root.name = "AirshipWreck"
	var st := Builds._begin()
	var rings := 9
	var segs := 12
	var girder := Color("3d342c")
	var pts := []
	for k in range(rings):
		var u := float(k)/float(rings-1)
		var z := (u-0.5)*length
		var r := radius*sqrt(maxf(0.08,1.0-pow(2.0*u-1.0,2.0)))
		# Crushed toward its low end.
		var squash := lerpf(1.0,0.72,u)
		var ring := []
		for i in range(segs):
			var t := TAU*float(i)/segs+rng.randf_range(-0.05,0.05)
			ring.append(Vector3(cos(t)*r*(1.0+rng.randf_range(-0.06,0.06)),sin(t)*r*squash,z+rng.randf_range(-0.3,0.3)))
		pts.append(ring)
	# The rings: girders between neighbours, a run of each broken away.
	for k in range(rings):
		var ring: Array = pts[k]
		var gone := rng.randi_range(0,segs-1)
		var gone_n := rng.randi_range(0,4) if k > 0 and k < rings-1 else segs
		for i in range(segs):
			if k == 0 or k == rings-1: break
			var off := posmod(i-gone,segs)
			if off < gone_n: continue
			AirshipBuild._beam(st,ring[i],ring[(i+1)%segs],0.13,girder*rng.randf_range(0.8,1.1))
	# The keel (along the bottom) and stringers, some snapped short.
	for i in range(segs):
		var keep := i == segs*3/4 or rng.randf() < 0.45
		if not keep: continue
		var snapped := rng.randi_range(rings/2,rings-1) if rng.randf() < 0.5 else rings-1
		for k in range(snapped):
			var a: Vector3 = pts[k][i]
			var c: Vector3 = pts[k+1][i]
			if k == snapped-1 and snapped < rings-1: c = a.lerp(c,rng.randf_range(0.3,0.8))+Vector3(0.0,rng.randf_range(-0.8,0.8),0.0)
			AirshipBuild._beam(st,a,c,0.11,girder)
	# A few gores of canvas left, faded and charred, torn.
	for k in range(rings-1):
		for i in range(segs):
			if rng.randf() > 0.3: continue
			var c := AirshipBuild.CANVAS if i%3 != 0 else AirshipBuild.RUST
			c = c.lerp(CHAR,rng.randf_range(0.35,0.75))
			var a0: Vector3 = pts[k][i]
			var a1: Vector3 = pts[k][(i+1)%segs]
			var b0: Vector3 = pts[k+1][i]
			var b1: Vector3 = pts[k+1][(i+1)%segs]
			var torn := rng.randf_range(0.35,1.0)
			var face := [a0,a1,a1.lerp(b1,torn),a0.lerp(b0,torn*rng.randf_range(0.6,1.0))]
			AirshipBuild._slab(st,face,(a1-a0).cross(b0-a0).normalized(),0.05,c)
	# Two fins, one hanging askew off the high end.
	var fin_at: Vector3 = pts[0][segs/4]
	AirshipBuild._slab(st,[fin_at,fin_at+Vector3(0.0,3.2,-1.2),fin_at+Vector3(0.0,3.6,-3.8),fin_at+Vector3(0.0,0.4,-2.8)],Vector3.RIGHT,0.1,AirshipBuild.RUST.lerp(CHAR,0.5))
	var fin2: Vector3 = pts[0][segs/2]
	AirshipBuild._slab(st,[fin2,fin2+Vector3(-2.6,-1.4,-0.8),fin2+Vector3(-3.0,-1.8,-3.2),fin2+Vector3(-0.3,-0.2,-2.6)],Vector3.UP,0.1,AirshipBuild.RUST.lerp(CHAR,0.6))
	var frame := MeshInstance3D.new()
	frame.name = "Frame"
	frame.mesh = Builds._end(st)
	frame.material_override = material
	root.add_child(frame)
	# The gondola, hung off the low end on two lines, tipped, sooted.
	var low: Vector3 = pts[rings-1][segs*3/4]
	var gst := Builds._begin()
	AirshipBuild._gondola(gst)
	var gondola := MeshInstance3D.new()
	gondola.name = "Gondola"
	gondola.mesh = _sooted_mesh(Builds._end(gst),0.55)
	gondola.material_override = material
	var hang := low+Vector3(0.0,-9.0,1.5)
	gondola.transform = Transform3D(Basis(Vector3.RIGHT,-0.5)*Basis(Vector3.BACK,0.35)*Basis.from_scale(Vector3.ONE*1.6),hang)
	root.add_child(gondola)
	var lines := Builds._begin()
	for side: float in [-1.0,1.0]:
		var at := gondola.transform*Vector3(side*0.8,0.2,-1.0+side*0.8)
		AirshipBuild._beam(lines,low+Vector3(side*0.6,0.0,0.0),at,0.04,AirshipBuild.ROPE.lerp(CHAR,0.3))
	var line_mesh := MeshInstance3D.new()
	line_mesh.name = "Lines"
	line_mesh.mesh = Builds._end(lines)
	line_mesh.material_override = material
	root.add_child(line_mesh)
	return root

## `mesh`'s colours sooted `k` of the way to char.
static func _sooted_mesh(mesh: ArrayMesh, k: float) -> ArrayMesh:
	var out := ArrayMesh.new()
	var ch := CHAR.srgb_to_linear()
	for s in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(s)
		var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		for i in range(colours.size()): colours[i] = colours[i].lerp(ch,k*(0.7+0.3*float((i/3)%3)/2.0))
		arrays[Mesh.ARRAY_COLOR] = colours
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return out

## The wreck's and the trees' material: the airships' own vertex-coloured
## surface.
static func surface_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SURFACE
	m.set_shader_parameter("fill",1.1)
	m.set_shader_parameter("rim",0.3)
	m.set_shader_parameter("roughness_value",0.95)
	return m

# --- Claw gouges --------------------------------------------------------------------

## The land's drawn triangles, bucketed by CELL (x, z) for rays.
class Faces extends RefCounted:
	const CELL := 4.0
	var v := PackedVector3Array()
	var cells := {}

	func add_mesh(mesh: Mesh, xf: Transform3D) -> void:
		for s in range(mesh.get_surface_count()):
			var arrays := mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var count := index.size() if not index.is_empty() else verts.size()
			for i in range(0,count,3):
				var a := xf*verts[index[i] if not index.is_empty() else i]
				var b := xf*verts[index[i+1] if not index.is_empty() else i+1]
				var c := xf*verts[index[i+2] if not index.is_empty() else i+2]
				var k := v.size()
				v.append(a)
				v.append(b)
				v.append(c)
				var lo := Vector2(minf(a.x,minf(b.x,c.x)),minf(a.z,minf(b.z,c.z)))
				var hi := Vector2(maxf(a.x,maxf(b.x,c.x)),maxf(a.z,maxf(b.z,c.z)))
				for cx in range(floori(lo.x/CELL),floori(hi.x/CELL)+1):
					for cz in range(floori(lo.y/CELL),floori(hi.y/CELL)+1):
						var key := Vector2i(cx,cz)
						if not cells.has(key): cells[key] = PackedInt32Array()
						var list: PackedInt32Array = cells[key]
						list.append(k)
						cells[key] = list

	## The nearest hit of the ray from `from` along `dir` (unit) within
	## `reach`: [point, normal], or [] for none.
	func ray(from: Vector3, dir: Vector3, reach: float) -> Array:
		var best := INF
		var out := []
		var seen := {}
		var steps := int(ceil(reach/(CELL*0.5)))+1
		for s in range(steps+1):
			var p := from+dir*minf(reach,float(s)*CELL*0.5)
			for dx in range(-1,2):
				for dz in range(-1,2):
					var key := Vector2i(floori(p.x/CELL)+dx,floori(p.z/CELL)+dz)
					if seen.has(key) or not cells.has(key): continue
					seen[key] = true
					for k: int in cells[key]:
						var hit: Variant = Geometry3D.ray_intersects_triangle(from,dir,v[k],v[k+1],v[k+2])
						if hit == null: continue
						var d := (hit as Vector3).distance_to(from)
						if d < best and d <= reach:
							best = d
							var n := (v[k+1]-v[k]).cross(v[k+2]-v[k]).normalized()
							if n.dot(dir) > 0.0: n = -n
							out = [hit,n]
		return out

## Claw marks: for each [start, along (unit), into (unit: the ray toward
## the rock), length, claws, spread] the grooves raked along the drawn
## faces, each sampled every STEP m. One mesh.
const STEP := 0.6
static func gouges(faces: Faces, marks: Array, material: Material) -> MeshInstance3D:
	var st := Builds._begin()
	var dark := Color("0d0b0a").srgb_to_linear()
	var pale := Color("8c857a").srgb_to_linear()
	for mark: Array in marks:
		var start: Vector3 = mark[0]
		var along: Vector3 = mark[1]
		var into: Vector3 = mark[2]
		var length: float = mark[3]
		var claws: int = mark[4]
		var spread: float = mark[5]
		var across := along.cross(into).normalized()
		for c in range(claws):
			var off := (float(c)-(claws-1)*0.5)*spread
			var prev := []
			var count := int(length/STEP)+1
			for i in range(count):
				var t := float(i)/float(count-1)
				# Each claw's groove a little curved and tapering at both ends.
				var p := start+along*length*t+across*(off+0.25*sin(t*PI)*float(c-1))
				var hit := faces.ray(p-into*4.0,into,9.0)
				if hit.is_empty():
					prev = []
					continue
				var n: Vector3 = hit[1]
				var side := along.cross(n).normalized()
				var w := 0.22*sin(PI*clampf(t*1.1,0.05,0.95))+0.06
				var at: Vector3 = (hit[0] as Vector3)+n*0.07
				var row := [at-side*(w+0.14),at-side*w,at+side*w,at+side*(w+0.14)]
				if not prev.is_empty():
					var cols := [pale,dark,pale]
					for lane in range(3):
						_quad(st,prev[lane],prev[lane+1],row[lane+1],row[lane],n,cols[lane])
				prev = row
	var mi := MeshInstance3D.new()
	mi.name = "ClawGouges"
	mi.mesh = Builds._end(st)
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, linear: Color) -> void:
	for tri: Array in [[a,b,c],[a,c,d]]:
		var p: Vector3 = tri[0]
		var q: Vector3 = tri[1]
		var r: Vector3 = tri[2]
		if (q-p).cross(r-p).dot(n) > 0.0:
			var s := q
			q = r
			r = s
		for v: Vector3 in [p,q,r]:
			st.set_color(linear)
			st.add_vertex(v)
