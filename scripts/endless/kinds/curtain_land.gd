extends RefCounted
## The land under a placed curtain (scripts/endless/kinds/curtain.gd): a layer
## over the land field (LandField, land_field.gd, applies it after the native
## or GDScript field and the ponds, halls and splits, as they are applied),
## keyed to the placed site and a pure function of the lists, the world and
## the layout file, so every machine stands the same land. --no-placed: none.
##
## In the site's frame (f along its heading, + toward what it faces; s to its
## right; the foot at f = 0): an alcove cut back into the slope to a face at
## f = -back, its floor at the foot; on the face's top edge a notch, the lip,
## where a stream comes over from a tarn on the land behind; at the face's
## foot a plunge pool; from the pool an outflow to the river in front. The
## cut only lowers the land. A wet skin (the waterfall) has water in the
## tarn, the stream, the pool and the outflow: they read as a pond does
## (LandField `_p_*`: the river's reads, the ground shader's water).
##
## Behind the face, a cave (`cave_at`): its mouth at the face's foot behind
## the sheet, straight in CAVE_IN m, a bend of CAVE_R m turning CAVE_TURN to
## the +s side, then CAVE_OUT m to its exit, a mouth in the back wall of a cut
## (the exit's gully) that runs out and down the hill's flank. The land field
## (the flight's crash test) has the cave as a trench down to its floor with
## walls at its half-width; the chunks draw the hill whole over it (`cave`
## false: LandField.surface), with holes in the two faces (`hole_mask`), and
## the curtain's piece draws the cave's rock and holds its roof
## (curtain.gd `cave`).
##
## A shape is a PackedFloat32Array (see the I_ indices).

const LayoutOverrides = preload("res://scripts/layout_overrides.gd")
const PlacedList = preload("res://scripts/endless/placed_list.gd")
const WorldScale = preload("res://scripts/world_scale.gd")

const I_X := 0
const I_Z := 1
const I_Y := 2
const I_FX := 3
const I_FZ := 4
const I_REACH := 5
const I_BACK := 6
const I_LIP := 7
const I_HALF_BACK := 8
const I_HALF_FRONT := 9
const I_FLOOR := 10
const I_POOL_F := 11
const I_POOL_R := 12
const I_POOL_Y := 13
const I_POOL_DEPTH := 14
const I_TARN_S := 15
const I_TARN_F := 16
const I_TARN_R := 17
const I_TARN_Y := 18
const I_LIP_HALF := 19
const I_OUT_F := 20
const I_OUT_Y := 21
const I_WET := 22
const I_CAVE_HALF := 23
const I_CAVE_TALL := 24
const I_CAVE_FLOOR := 25
const I_CAVE_IN := 26
const I_CAVE_R := 27
const I_CAVE_TURN := 28
const I_CAVE_OUT := 29
const SIZE := 30

## The defaults (m), each a param of the same name (lip: over the foot).
const BACK := 48.0
const LIP := 61.5
const HALF_BACK := 24.0
const HALF_FRONT := 36.0
const POOL_R := 14.0
const POOL_DEPTH := 2.3
const TARN := Vector3(-14.0,-70.0,8.0)
const TARN_OVER_LIP := 4.0
const LIP_HALF := 13.0
const OUT_F := 36.0
const OUT_Y_UNDER := 4.0

## The cave: its width and height from their toy-era sizes (WorldScale
## `opening`, AGENTS.md Sizes: 22 m by 16 m at plane 2), its walls upright to
## WALL_SHARE of its height and an arch over them; its floor CAVE_OVER m over
## the foot. Its path (m, degrees), each a param of the same name (cave_in,
## cave_r, cave_turn, cave_out; cave false: none).
const TOY_CAVE := 11.0
const TOY_CAVE_TALL := 8.0
const WALL_SHARE := 0.45
const CAVE_OVER := 0.4
const CAVE_IN := 10.0
const CAVE_R := 60.0
const CAVE_TURN := 50.0
const CAVE_OUT := 6.0
## The exit's gully: as wide as the cave and EXIT_PAD more where it leaves
## the face, opening EXIT_SPREAD m a m out, its floor rising EXIT_RISE a m,
## its banks EXIT_BANK (rise over run); it fades over FRONT past EXIT_LONG.
const EXIT_PAD := 2.0
const EXIT_SPREAD := 0.25
const EXIT_RISE := 0.15
const EXIT_BANK := 1.4
const EXIT_LONG := 34.0
## The faces' holes in the chunks reach HOLE_PAD m past the cave's sides.
const HOLE_PAD := 1.0

## The face runs from its top edge to the floor over WALL m (a cliff); the
## alcove fades out over FRONT m past the foot.
const WALL := 4.0
const FRONT := 10.0
## The pool's and tarn's banks rise BANK (rise over run) off the water; the
## stream's and the tarn's hollow sides HOLLOW; the outflow's banks OUT_BANK.
const BANK := 0.14
const HOLLOW := 1.0
const OUT_BANK := 0.35
## The stream's water half-width at the tarn (it fans to LIP_HALF at the lip)
## and its depth; the outflow's half-width and depth.
const STREAM_HALF := 3.5
const STREAM_DEPTH := 1.0
const OUT_HALF := 4.0
const OUT_DEPTH := 1.1
## The outflow's banks reach OUT_CAP m past its water, no further.
const OUT_CAP := 8.0
## How far past a shape's water its cut and reads carry (m); its reads stop
## where the ground stands DRY_OVER m over the water.
const REACH := 30.0
const DRY_OVER := 1.2

## Site `s`'s shape, the coded site (placed_list.gd `site_of`) at `xform`.
static func shape_of(s: Dictionary, xform: Transform3D) -> PackedFloat32Array:
	var p: Dictionary = s.params
	var c := PackedFloat32Array()
	c.resize(SIZE)
	var fwd := -xform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	c[I_X] = xform.origin.x
	c[I_Z] = xform.origin.z
	c[I_Y] = xform.origin.y
	c[I_FX] = fwd.x
	c[I_FZ] = fwd.z
	c[I_BACK] = float(p.get("back",BACK))
	c[I_LIP] = xform.origin.y+float(p.get("lip",LIP))
	c[I_HALF_BACK] = float(p.get("half_back",HALF_BACK))
	c[I_HALF_FRONT] = float(p.get("half_front",HALF_FRONT))
	c[I_FLOOR] = xform.origin.y
	c[I_POOL_R] = float(p.get("pool_r",POOL_R))
	c[I_POOL_F] = -c[I_BACK]+c[I_POOL_R]+2.0
	c[I_POOL_Y] = xform.origin.y-0.6
	c[I_POOL_DEPTH] = float(p.get("pool_depth",POOL_DEPTH))
	var tarn: Vector3 = p.get("tarn",TARN)
	c[I_TARN_S] = tarn.x
	c[I_TARN_F] = tarn.y
	c[I_TARN_R] = tarn.z
	c[I_TARN_Y] = c[I_LIP]+float(p.get("tarn_over_lip",TARN_OVER_LIP))
	c[I_LIP_HALF] = float(p.get("lip_half",LIP_HALF))
	c[I_OUT_F] = float(p.get("out_f",OUT_F))
	c[I_OUT_Y] = xform.origin.y-float(p.get("out_under",OUT_Y_UNDER))
	c[I_WET] = 1.0 if str(s.get("skin","")) == "waterfall" else 0.0
	var tarn_far := Vector2(tarn.x,tarn.y).length()+tarn.z+REACH
	c[I_REACH] = maxf(maxf(tarn_far,c[I_OUT_F]+OUT_HALF+REACH),c[I_BACK]+c[I_HALF_FRONT]+REACH)
	if bool(p.get("cave",true)):
		c[I_CAVE_HALF] = WorldScale.opening(TOY_CAVE)*0.5
		c[I_CAVE_TALL] = WorldScale.opening(TOY_CAVE_TALL)
		c[I_CAVE_FLOOR] = c[I_FLOOR]+CAVE_OVER
		c[I_CAVE_IN] = float(p.get("cave_in",CAVE_IN))
		c[I_CAVE_R] = float(p.get("cave_r",CAVE_R))
		c[I_CAVE_TURN] = deg_to_rad(float(p.get("cave_turn",CAVE_TURN)))
		c[I_CAVE_OUT] = float(p.get("cave_out",CAVE_OUT))
		var gully := cave_length(c)+EXIT_LONG+FRONT
		var end: Vector2 = cave_point(c,gully)[0]
		c[I_REACH] = maxf(c[I_REACH],end.length()+c[I_CAVE_HALF]+EXIT_PAD+EXIT_SPREAD*gully+REACH)
	return c

## Whether shape `c` has a cave.
static func has_cave(c: PackedFloat32Array) -> bool:
	return c[I_CAVE_HALF] > 0.0

## The cave's length (m) from its mouth at the face's foot to its exit's foot.
static func cave_length(c: PackedFloat32Array) -> float:
	return c[I_CAVE_IN]+c[I_CAVE_R]*c[I_CAVE_TURN]+c[I_CAVE_OUT]

## The cave's path `t` m in (on past its exit along its last heading): [its
## point (s, f), its heading (s, f), its +u side (s, f)].
static func cave_point(c: PackedFloat32Array, t: float) -> Array:
	var a := Vector2(0.0,-c[I_BACK]+WALL)
	var r := c[I_CAVE_R]
	var turn := c[I_CAVE_TURN]
	if t <= c[I_CAVE_IN]: return [a+Vector2(0.0,-t),Vector2(0.0,-1.0),Vector2(1.0,0.0)]
	var centre := a+Vector2(r,-c[I_CAVE_IN])
	var th := minf((t-c[I_CAVE_IN])/r,turn)
	var at := centre-Vector2(cos(th),sin(th))*r
	var dir := Vector2(sin(th),-cos(th))
	var side := Vector2(cos(th),sin(th))
	var past := t-c[I_CAVE_IN]-r*turn
	if past > 0.0: at += dir*past
	return [at,dir,side]

## Site-frame point `q` (s, f) on the cave's path: (t, u), t m along it (< 0
## before the mouth, past cave_length beyond the exit), u m off it (+ toward
## the bend's inside); (NAN, INF) where none of its pieces is beside q.
static func cave_at(c: PackedFloat32Array, q: Vector2) -> Vector2:
	var a := Vector2(0.0,-c[I_BACK]+WALL)
	var r := c[I_CAVE_R]
	var turn := c[I_CAVE_TURN]
	var t_in := c[I_CAVE_IN]
	var best := Vector2(NAN,INF)
	# The run in (and before the mouth).
	var t := a.y-q.y
	if t <= t_in and absf(q.x) < absf(best.y): best = Vector2(t,q.x)
	# The bend.
	var centre := a+Vector2(r,-t_in)
	var v := q-centre
	var th := atan2(-v.y,-v.x)
	if th >= 0.0 and th <= turn:
		var u := r-v.length()
		if absf(u) < absf(best.y): best = Vector2(t_in+th*r,u)
	# The run out (and the gully past it).
	var end := centre-Vector2(cos(turn),sin(turn))*r
	var dir := Vector2(sin(turn),-cos(turn))
	var along := (q-end).dot(dir)
	if along >= 0.0:
		var u := (q-end).dot(Vector2(cos(turn),sin(turn)))
		if absf(u) < absf(best.y): best = Vector2(t_in+r*turn+along,u)
	return best

## The cave's roof `u` m off its path, over its floor (m): upright walls to
## WALL_SHARE of its height, then a half ellipse to its crown.
static func cave_roof(c: PackedFloat32Array, u: float) -> float:
	var half := c[I_CAVE_HALF]
	var tall := c[I_CAVE_TALL]
	var wall := tall*WALL_SHARE
	var k := clampf(absf(u)/half,0.0,1.0)
	return wall+(tall-wall)*sqrt(1.0-k*k)

## The exit's gully cut into the land `h` at path point (t, u): its floor
## rising out from the exit's foot, its banks, the back wall over WALL m.
static func _gully(c: PackedFloat32Array, h: float, t: float, u: float) -> float:
	var foot := cave_length(c)
	var out := t-foot
	if out < -WALL or out > EXIT_LONG+FRONT: return h
	var half := c[I_CAVE_HALF]+EXIT_PAD+maxf(out,0.0)*EXIT_SPREAD
	var floor_y := c[I_CAVE_FLOOR]+maxf(out,0.0)*EXIT_RISE
	var cut := floor_y+maxf(absf(u)-half,0.0)*EXIT_BANK
	var a := clampf((out+WALL)/WALL,0.0,1.0)*clampf(1.0-(out-EXIT_LONG)/FRONT,0.0,1.0)
	return lerpf(h,minf(h,cut),a)

## The curtains in play in world `profile`, as shapes: each in-play site of
## kind curtain at its spot after the layout file's move, none for a deleted
## one. Made once per world and layout file, as PlacedList.clears.
static func shapes(profile: RefCounted) -> Array:
	if profile == null or not PlacedList.wanted(): return []
	_lock.lock()
	if _of.size() != 2 or not is_same(_of[0],profile) or not is_same(_of[1],LayoutOverrides.data):
		var out: Array = []
		for s: Dictionary in PlacedList.in_play(profile):
			if str(s.kind) != "curtain" or LayoutOverrides.deleted(str(s.handle)): continue
			out.append(shape_of(s,xform_of(s)))
		_shapes = out
		_of = [profile,LayoutOverrides.data]
	var got := _shapes
	_lock.unlock()
	return got

static var _shapes: Array = []
static var _of: Array = []
static var _lock := Mutex.new()

## Where curtain site `s` stands: its coded spot at params.y (a curtain names
## its foot's height: the land under it is its own to cut), turned to its
## heading, after the layout file's move.
static func xform_of(s: Dictionary) -> Transform3D:
	var p: Dictionary = s.params
	var coded := Transform3D(Basis(Vector3.UP,deg_to_rad(float(s.heading))),Vector3(float(s.x),float(p.get("y",0.0)),float(s.z)))
	return LayoutOverrides.xform(str(s.handle),coded)

## Whether shape `c` reaches (x, z).
static func reaches(c: PackedFloat32Array, x: float, z: float) -> bool:
	return absf(x-c[I_X]) < c[I_REACH] and absf(z-c[I_Z]) < c[I_REACH]

## Whether shape `c` meets the box (x0, z0)..(x1, z1).
static func meets(c: PackedFloat32Array, x0: float, z0: float, x1: float, z1: float) -> bool:
	return c[I_X]+c[I_REACH] > x0 and c[I_X]-c[I_REACH] < x1 and c[I_Z]+c[I_REACH] > z0 and c[I_Z]-c[I_REACH] < z1

## (s, f) of world (x, z) in shape `c`'s frame.
static func local(c: PackedFloat32Array, x: float, z: float) -> Vector2:
	var dx := x-c[I_X]
	var dz := z-c[I_Z]
	return Vector2(-dx*c[I_FZ]+dz*c[I_FX],dx*c[I_FX]+dz*c[I_FZ])

## Shape `c` cut into the land's height `base` at (x, z): [height, water's
## out (m past its edge, < 0 on it; INF dry), r, w, level] (the pond's reads:
## LandField `_pond`).
## With `cave` the cave's trench too (the field's), else the hill whole over
## it (the chunks').
static func at(c: PackedFloat32Array, base: float, x: float, z: float, cave := true) -> PackedFloat32Array:
	var q := local(c,x,z)
	var s := q.x
	var f := q.y
	var h := base
	# Each water's reads [out, r, w, level], kept at the end only where the
	# ground holds it (DRY_OVER), so a face between two waters reads dry.
	var waters: Array[PackedFloat32Array] = []
	# The tarn and the stream from it to the lip.
	var tarn := Vector2(c[I_TARN_S],c[I_TARN_F])
	var lip := Vector2(0.0,-c[I_BACK])
	var along := lip-tarn
	var long := along.length()
	var dir := along/long
	var rel := q-tarn
	var t := clampf(rel.dot(dir)/long,0.0,1.0)
	var across := rel.x*dir.y-rel.y*dir.x
	var off := absf(rel.x*dir.y-rel.y*dir.x) if rel.dot(dir) >= 0.0 and rel.dot(dir) <= long else (q-(tarn+along*t)).length()
	var half := lerpf(STREAM_HALF,c[I_LIP_HALF],smoothstep(0.35,1.0,t))
	var level := lerpf(c[I_TARN_Y]-0.15,c[I_LIP],t)
	if f < -c[I_BACK]+0.5 and off < half+REACH:
		var out := off-half
		h = minf(h,_bowl(level,STREAM_DEPTH,out,half,HOLLOW))
		var t_in := rel.dot(dir)/long
		waters.append(PackedFloat32Array([out,across if t_in > 0.0 and t_in < 1.0 else off,half,level]))
	var rt := (q-tarn).length()
	if rt < c[I_TARN_R]+REACH:
		var out := rt-c[I_TARN_R]
		h = minf(h,_bowl(c[I_TARN_Y],STREAM_DEPTH*1.6,out,c[I_TARN_R],HOLLOW))
		waters.append(PackedFloat32Array([out,rt,c[I_TARN_R],c[I_TARN_Y]]))
	# The alcove: the face from its top edge down to the floor.
	var back := c[I_BACK]
	var side := lerpf(c[I_HALF_BACK],c[I_HALF_FRONT],clampf((f+back)/back,0.0,1.0))+maxf(f,0.0)
	var inside := minf(f+back,side-absf(s))
	if inside > 0.0:
		var a := clampf(inside/WALL,0.0,1.0)*clampf(1.0-f/FRONT,0.0,1.0)
		h = lerpf(h,minf(h,c[I_FLOOR]),a)
	# The plunge pool at the face's foot.
	var rp := Vector2(s,f-c[I_POOL_F]).length()
	if rp < c[I_POOL_R]+REACH and f > -back:
		var out := rp-c[I_POOL_R]
		h = minf(h,_bowl(c[I_POOL_Y],c[I_POOL_DEPTH],out,c[I_POOL_R],BANK,(c[I_FLOOR]+0.3-c[I_POOL_Y])/BANK))
		waters.append(PackedFloat32Array([out,rp,c[I_POOL_R],c[I_POOL_Y]]))
	# The outflow from the pool to the river.
	var f0 := c[I_POOL_F]+c[I_POOL_R]*0.6
	if f > f0 and f < c[I_OUT_F]+OUT_HALF and absf(s) < OUT_HALF+REACH:
		var u := clampf((f-f0)/(c[I_OUT_F]-f0),0.0,1.0)
		var lv := lerpf(c[I_POOL_Y],c[I_OUT_Y],u)
		var out := absf(s)-OUT_HALF
		h = minf(h,_bowl(lv,OUT_DEPTH,out,OUT_HALF,OUT_BANK,OUT_CAP))
		waters.append(PackedFloat32Array([out,s,OUT_HALF,lv]))
	if has_cave(c):
		var tu := cave_at(c,q)
		if not is_nan(tu.x):
			h = _gully(c,h,tu.x,tu.y)
			# In the trench the waters over the hill are not the flight's.
			if cave and tu.x >= 0.0 and tu.x <= cave_length(c) and absf(tu.y) < c[I_CAVE_HALF]:
				h = minf(h,c[I_CAVE_FLOOR])
				waters.clear()
	var got := PackedFloat32Array([h,INF,0.0,0.0,0.0])
	if c[I_WET] <= 0.0: return got
	for w: PackedFloat32Array in waters:
		if w[0] < got[1] and (w[0] < 0.0 or h < w[3]+DRY_OVER):
			got[1] = w[0]
			got[2] = w[1]
			got[3] = w[2]
			got[4] = w[3]
	return got

## A water's ground at `out` m past its edge (< 0 on it), `half` m to its
## middle: a bed `depth` under `level` in the middle, the bank rising `rise`
## off the water's edge, to `cap` m past it (INF past that: no cut).
static func _bowl(level: float, depth: float, out: float, half: float, rise: float, cap := INF) -> float:
	if out > cap: return INF
	if out < 0.0:
		var k := clampf(-out/maxf(half,0.01),0.0,1.0)
		return level-depth*smoothstep(0.0,0.7,k)
	return level+0.06+rise*out

## The pass over a chunk's arrays (LandField.build_chunk; its args), after
## the ponds, halls and splits.
static func apply_chunk(field: Object, impl: Object, made: Dictionary, cs: Array, x0: float, z0: float, step: float, cells: int, skirt_drop: float) -> void:
	var n := cells+1
	var heights: PackedFloat32Array = made.heights
	var verts: PackedVector3Array = made.verts
	var normals: PackedVector3Array = made.normals
	var colours: PackedColorArray = made.colours
	var carved: PackedByteArray = made.carved
	var river: PackedFloat32Array = made.river
	var moved := PackedByteArray()
	moved.resize(n*n)
	var touched := PackedByteArray()
	touched.resize(n*n)
	var any_moved := false
	for c: PackedFloat32Array in cs:
		var far := c[I_REACH]
		var i0 := clampi(floori((c[I_X]-far-x0)/step),0,cells)
		var i1 := clampi(ceili((c[I_X]+far-x0)/step),0,cells)
		var j0 := clampi(floori((c[I_Z]-far-z0)/step),0,cells)
		var j1 := clampi(ceili((c[I_Z]+far-z0)/step),0,cells)
		for j in range(j0,j1+1):
			for i in range(i0,i1+1):
				var v := j*n+i
				var got := at(c,heights[v],x0+i*step,z0+j*step,false)
				var out_now := absf(river[v*3])-river[v*3+1]
				if got[1] < REACH and got[1] < out_now:
					# The distance takes the sign the river's had here, so
					# the shader's interpolation to a neighbour left with the
					# river's never crosses zero (a false strip of water).
					river[v*3] = absf(got[2])*(-1.0 if river[v*3] < 0.0 else 1.0)
					river[v*3+1] = got[3]
					river[v*3+2] = got[4]
					carved[v*4+2] = 127
					carved[v*4+3] = 127
					touched[v] = 1
				var y := got[0]
				if absf(y-heights[v]) > 0.0005:
					heights[v] = y
					verts[v] = Vector3(verts[v].x,y,verts[v].z)
					moved[v] = 1
					touched[v] = 1
					any_moved = true
	if any_moved:
		var redo := PackedByteArray()
		redo.resize(n*n)
		for j in n:
			for i in n:
				if moved[j*n+i] == 0: continue
				for d: Vector2i in [Vector2i(0,0),Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
					var ii := i+d.x
					var jj := j+d.y
					if ii >= 0 and ii < n and jj >= 0 and jj < n: redo[jj*n+ii] = 1
		for j in n:
			for i in n:
				var v := j*n+i
				if redo[v] == 0: continue
				var x := x0+i*step
				var z := z0+j*step
				var hl: float = heights[v-1] if i > 0 else field.height(x-step,z)
				var hr: float = heights[v+1] if i < cells else field.height(x+step,z)
				var hd: float = heights[v-n] if j > 0 else field.height(x,z-step)
				var hu: float = heights[v+n] if j < cells else field.height(x,z+step)
				var normal := Vector3(hl-hr,2.0*step,hd-hu).normalized()
				normals[v] = normal
				var meadow := colours[v].a
				var col: Color = impl.colour(x,z,heights[v],normal.y,meadow)
				col.a = meadow
				colours[v] = col
				touched[v] = 1
	# The skirt's copies of the edges.
	var edges := [[],[],[],[]]
	for t in n:
		edges[0].append(t)
		edges[1].append(t*n+cells)
		edges[2].append(cells*n+t)
		edges[3].append(t*n)
	for e in 4:
		for t in n:
			var from: int = edges[e][t]
			if touched[from] == 0: continue
			var v := n*n+e*n+t
			verts[v] = verts[from]-Vector3(0.0,skirt_drop,0.0)
			normals[v] = normals[from]
			colours[v] = colours[from]
			for q in 4: carved[v*4+q] = carved[from*4+q]
			river[v*3] = river[from*3]
			river[v*3+1] = -river[from*3+1]
			river[v*3+2] = river[from*3+2]
	made.heights = heights
	made.verts = verts
	made.normals = normals
	made.colours = colours
	made.carved = carved
	made.river = river

## The pass over LandField.grid's arrays.
static func apply_grid(got: Dictionary, cs: Array, x0: float, z0: float, step: float, nx: int, nz: int, pad: int) -> void:
	var hs: PackedFloat32Array = got.heights
	var rs: PackedFloat32Array = got.get("river",PackedFloat32Array())
	for c: PackedFloat32Array in cs:
		var far := c[I_REACH]
		var i0 := clampi(floori((c[I_X]-far-x0)/step)+pad,0,nx-1)
		var i1 := clampi(ceili((c[I_X]+far-x0)/step)+pad,0,nx-1)
		var j0 := clampi(floori((c[I_Z]-far-z0)/step)+pad,0,nz-1)
		var j1 := clampi(ceili((c[I_Z]+far-z0)/step)+pad,0,nz-1)
		for j in range(j0,j1+1):
			for i in range(i0,i1+1):
				var k := j*nx+i
				var e := at(c,hs[k],x0+(i-pad)*step,z0+(j-pad)*step,false)
				hs[k] = e[0]
				if not rs.is_empty() and e[1] < rs[k]: rs[k] = e[1]
	got.heights = hs
	if not rs.is_empty(): got.river = rs

## The chunk's triangles on the cave's two faces over its mouths dropped
## (LandField.curtain_cut, from land_stream.gd after the tunnels' holes):
## those whose middle is on a face (the WALL strip at either end, HOLE_PAD
## past the cave's sides) that reach under the cave's crown and over its
## floor, so the floor in front and the top over each face stay. `idx` the
## chunk's triangles now (its grid's and skirts'); `made.indices` gets the
## rest, and a level-0 chunk (`level0`) its collider's faces (chunk-local).
## False where none dropped.
static func cut_faces(cs: Array, made: Dictionary, x0: float, z0: float, cells: int, idx: PackedInt32Array, level0: bool) -> bool:
	var verts: PackedVector3Array = made.verts
	var n := cells+1
	var mouths: Array = []
	for c: PackedFloat32Array in cs:
		if not has_cave(c): continue
		var foot := cave_length(c)
		for t: float in [WALL*0.5,foot-WALL*0.5]:
			var q: Vector2 = cave_point(c,t)[0]
			var fwd := Vector2(c[I_FX],c[I_FZ])
			var w := Vector2(c[I_X],c[I_Z])+Vector2(-fwd.y,fwd.x)*q.x+fwd*q.y
			mouths.append([c,w,c[I_CAVE_HALF]+HOLE_PAD+WALL+4.0])
	if mouths.is_empty(): return false
	var out := PackedInt32Array()
	var faces := PackedVector3Array()
	var dropped := false
	for k in range(0,idx.size(),3):
		var a := verts[idx[k]]
		var b := verts[idx[k+1]]
		var d := verts[idx[k+2]]
		var mid := Vector2(x0+(a.x+b.x+d.x)/3.0,z0+(a.z+b.z+d.z)/3.0)
		var drop := false
		for m: Array in mouths:
			if mid.distance_to(m[1]) > float(m[2]): continue
			var c: PackedFloat32Array = m[0]
			var tu := cave_at(c,local(c,mid.x,mid.y))
			if is_nan(tu.x) or absf(tu.y) > c[I_CAVE_HALF]+HOLE_PAD: continue
			var foot := cave_length(c)
			if not ((tu.x > -1.0 and tu.x < WALL+2.5) or (tu.x > foot-WALL-2.5 and tu.x < foot+1.0)): continue
			var lo := minf(a.y,minf(b.y,d.y))
			var hi := maxf(a.y,maxf(b.y,d.y))
			if lo < c[I_CAVE_FLOOR]+c[I_CAVE_TALL] and hi > c[I_CAVE_FLOOR]+1.5:
				drop = true
				break
		if drop:
			dropped = true
			continue
		out.append(idx[k])
		out.append(idx[k+1])
		out.append(idx[k+2])
		if level0 and idx[k] < n*n and idx[k+1] < n*n and idx[k+2] < n*n: faces.append_array([a,b,d])
	if not dropped: return false
	made.indices = out
	if level0: made.faces = faces
	return true
