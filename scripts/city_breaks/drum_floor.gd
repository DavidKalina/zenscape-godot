extends Node3D
## The drum floor, colossus_drum (docs/design/roguelike/city-breaks-round1.md;
## card: brainstorm/round3-olmec-city/kit-k2-contrarian.md): a court of loose
## stone slabs (scripts/city_kit_breaks.gd SLAB, a metre thick, a carved ring
## on each) set on squat hollow drums. It rings like a bell when the Olmec
## lands on it.
##
## His landing's shockwave (scripts/enemies/headless_body.gd `_shock`, handed
## on by the hub `wave`) runs out across it: each slab hops as the front
## passes its middle (HOP, less the further out, by the wave's power), so
## the court staggers outward from his landing in a ring of slabs, each
## with a ring of light and dust at its seams; the slabs under his feet are
## driven down instead. The wanderer's own slam hops the slabs round his
## landing too (the slam group), without throwing him.
##
## The wanderer on it takes the wave's hit from the slabs, not the wave
## (`takes_shock`): when the slab under him hops,
##   standing on it        `knock`ed up and out from the landing
##                         (KNOCK: about 3 m up, 4 m/s out; source
##                         "colossus_drum", its own stun gap apart from the
##                         body's shockwave's)
##   stunned on it         `toss`ed again, still stunned
##   jumped in time        launched: a jump from it within PRE s before its
##                         hop, or within GRACE s after it begins, is a
##                         `toss` straight up to LAUNCH m (no stun): onto a
##                         ledge his jump never reaches.
## Collision: each slab a clean box (moved as it hops, a few frames).
## Drawn: the slabs and their rings as two MultiMeshes, the drums under them
## as one mesh (three draws for the court).
const K = preload("res://scripts/city_kit_breaks.gd")
const GiantStone = preload("res://scripts/kit_isle/greybox/giant_stone.gd")
const Dust = preload("res://scripts/enemies/body_dust.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const Slam = preload("res://scripts/slam.gd")

## The hop at the landing and at the wave's rim (m), its parts (s): the
## crouch, the rise, the fall back, the rebound.
const HOP := Vector2(0.7,0.2)
const HOP_T := Vector4(0.05,0.12,0.23,0.16)
const DIP := 0.14
## The lean out from the landing at the top of a hop (rad).
const LEAN := 0.06
## The wanderer: a jump this long (s) before his slab hops, or this long
## after it begins, launches him; the launch's height (m, at the landing,
## and at the rim) and its push out (m/s); the knock (m up, m/s out).
const PRE := 0.24
const GRACE := 0.1
## The motor's moves that are a jump of his.
const JUMPS := ["jump","pump","long","flip"]
const LAUNCH := Vector2(5.6,4.4)
const LAUNCH_OUT := 1.2
const KNOCK := Vector2(3.0,4.0)
## The carved ring's groove and its light (linear).
const GROOVE := Color(0.07,0.055,0.045,0.8)
const RING_LIT := Color(2.4,1.5,0.7,1.0)
const RING_FADE := 1.6

var cols := 5
var rows := 5
var seed_value := 1
## The slabs: {c (local x, z), top, hop (s since, -1 none), amp, dip, out (world flat way), ring, body}.
var slabs: Array = []
## The hits on the wanderer: [source, kind].
var dealt: Array = []
var hops := 0
## The wanderer's last jump off a slab (s on the floor's clock, -1 none).
var jumped_at := -1.0
var _clock := 0.0
var _was_on := -1
var _pending := {}
var _hub: Node = null
var _slab_mm: MultiMesh
var _ring_mm: MultiMesh
var mesh: MeshInstance3D
var body: StaticBody3D
var src: Node
var _rng := RandomNumberGenerator.new()
var _turns: Array[int] = []

func build(seed_in: int, _weathered := 0.0, n_cols := 5, n_rows := 5) -> void:
	seed_value = seed_in
	cols = n_cols
	rows = n_rows
	name = "colossus_drum"
	add_to_group(K.BREAKABLE)
	add_to_group(Slam.GROUP)
	_rng.seed = seed_in*13+1
	src = Node.new()
	src.name = "colossus_drum"
	add_child(src)
	var m := K.Mesher.new()
	var stride := K.SLAB
	var drum_r := K.SLAB*0.42
	for j in rows:
		for i in cols:
			var c := Vector2((i-(cols-1)*0.5)*stride,(j-(rows-1)*0.5)*stride)
			m.lathe(Transform3D(Basis.IDENTITY,Vector3(c.x,-K.SLAB_THICK-0.7,c.y)),[Vector2(drum_r-0.12,0.0),Vector2(drum_r,0.12),Vector2(drum_r*1.02,0.35),Vector2(drum_r,0.58),Vector2(drum_r-0.12,0.7)],18,true,0.8)
	m.box(Transform3D(Basis.IDENTITY,Vector3(0.0,-K.SLAB_THICK-0.95,0.0)),Vector3(cols*stride,0.5,rows*stride),0.1)
	mesh = MeshInstance3D.new()
	mesh.name = "Mesh"
	mesh.mesh = K.mesh_of(m)
	add_child(mesh)
	body = StaticBody3D.new()
	body.name = "Body"
	add_child(body)
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(cols*stride,0.5,rows*stride)
	var holder := CollisionShape3D.new()
	holder.shape = floor_shape
	holder.position = Vector3(0.0,-K.SLAB_THICK-0.95,0.0)
	body.add_child(holder)
	# The slabs: one stone mesh, one ring mesh, drawn as many.
	var sm := K.Mesher.new()
	sm.moss = 0.15
	sm.box(Transform3D(Basis.IDENTITY,Vector3(0.0,-K.SLAB_THICK*0.5,0.0)),Vector3(K.SLAB-K.SEAM,K.SLAB_THICK,K.SLAB-K.SEAM),0.14,-K.SLAB_THICK-0.6)
	_slab_mm = MultiMesh.new()
	_slab_mm.transform_format = MultiMesh.TRANSFORM_3D
	_slab_mm.mesh = K.mesh_of(sm)
	_slab_mm.instance_count = cols*rows
	var smi := MultiMeshInstance3D.new()
	smi.name = "Slabs"
	smi.multimesh = _slab_mm
	add_child(smi)
	_ring_mm = MultiMesh.new()
	_ring_mm.transform_format = MultiMesh.TRANSFORM_3D
	_ring_mm.use_colors = true
	_ring_mm.mesh = _ring_mesh()
	_ring_mm.instance_count = cols*rows
	var rmi := MultiMeshInstance3D.new()
	rmi.name = "Rings"
	rmi.multimesh = _ring_mm
	rmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rmi)
	var bodies := Node3D.new()
	bodies.name = "SlabBodies"
	add_child(bodies)
	for j in rows:
		for i in cols:
			var c := Vector2((i-(cols-1)*0.5)*stride,(j-(rows-1)*0.5)*stride)
			var sb := StaticBody3D.new()
			sb.name = "Slab_%d_%d" % [i,j]
			var shape := BoxShape3D.new()
			shape.size = Vector3(K.SLAB-K.SEAM,K.SLAB_THICK,K.SLAB-K.SEAM)
			var cs := CollisionShape3D.new()
			cs.shape = shape
			cs.position = Vector3(0.0,-K.SLAB_THICK*0.5,0.0)
			sb.add_child(cs)
			sb.position = Vector3(c.x,0.0,c.y)
			bodies.add_child(sb)
			_turns.append(_rng.randi_range(0,3))
			slabs.append({"c":c,"hop":-1.0,"amp":0.0,"dip":false,"out":Vector3.RIGHT,"ring":0.0,"body":sb,"y":0.0,"lean":0.0,"dusted":false})
	for k in slabs.size(): _draw(k)

## The carved ring: a flat band laid on the slab's top.
func _ring_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inner := K.SLAB*0.26
	var outer := K.SLAB*0.33
	var n := 40
	st.set_normal(Vector3.UP)
	for k in n:
		var a0 := TAU*k/n
		var a1 := TAU*(k+1)/n
		var p := [Vector3(cos(a0)*inner,0.012,sin(a0)*inner),Vector3(cos(a1)*inner,0.012,sin(a1)*inner),Vector3(cos(a1)*outer,0.012,sin(a1)*outer),Vector3(cos(a0)*outer,0.012,sin(a0)*outer)]
		for i: int in [0,2,1,0,3,2]: st.add_vertex(p[i])
	var mesh_out := st.commit()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_out.surface_set_material(0,mat)
	return mesh_out

## Every slab back down, quiet (a study's reset).
func reset() -> void:
	for k in slabs.size():
		slabs[k].hop = -1.0
		slabs[k].ring = 0.0
		_draw(k)
	_pending = {}
	dealt.clear()

## Slab `k`'s world middle on top (at rest).
func slab_top(k: int) -> Vector3:
	var c: Vector2 = slabs[k].c
	return to_global(Vector3(c.x,0.0,c.y))

## The slab under `p` (world), -1 none.
func slab_at(p: Vector3) -> int:
	var l := to_local(p)
	var i := roundi(l.x/K.SLAB+(cols-1)*0.5)
	var j := roundi(l.z/K.SLAB+(rows-1)*0.5)
	if i < 0 or j < 0 or i >= cols or j >= rows: return -1
	var k := j*cols+i
	var c: Vector2 = slabs[k].c
	if absf(l.x-c.x) > K.SLAB*0.5 or absf(l.z-c.y) > K.SLAB*0.5: return -1
	return k

func _over(p: Vector3, up: float) -> bool:
	var l := to_local(p)
	return absf(l.x) < cols*K.SLAB*0.5+0.5 and absf(l.z) < rows*K.SLAB*0.5+0.5 and l.y > -0.8 and l.y < up

# --- What the hub asks ---------------------------------------------------------------------

func standing_rids() -> Array[RID]:
	return []

func rubble_rids() -> Array[RID]:
	return []

func met(_hub_in: Node, _b: Node3D) -> void:
	pass

## The wanderer over the court: the slabs take the wave's hit on him.
func takes_shock(_hub_in: Node, _b: Node3D, _w: Dictionary) -> bool:
	var m: PilotMotor = _hub_in.motor()
	return m != null and _over(m.feet,3.0)

## His landing's shockwave `w` across the court: each slab as its front
## passes its middle.
func wave(hub: Node, b: Node3D, w: Dictionary) -> void:
	_hub = hub
	var at: Vector3 = w.at
	if absf(to_local(at).y) > 4.0: return
	var key := "drum_%d" % get_instance_id()
	if not w.has(key):
		w[key] = {}
		hub.sound(&"drum_ring",at)
	var done: Dictionary = w[key]
	var foot: float = float(b.length)*0.5+1.4
	for k in slabs.size():
		if done.has(k): continue
		var top := slab_top(k)
		var d := Vector2(top.x-at.x,top.z-at.z).length()
		if d > float(w.r): continue
		done[k] = true
		if d > float(w.max)+K.SLAB*0.5: continue
		var share := clampf(d/maxf(float(w.max),0.1),0.0,1.0)
		var amp := lerpf(HOP.x,HOP.y,share)*sqrt(float(w.power))
		_hop(k,amp,d < foot,Vector3(top.x-at.x,0.0,top.z-at.z),1.0-share*0.5,true)

## The slam (scripts/slam.gd) landing on the court: the slabs round it hop
## (his own: no hit on him).
func slam(at: Vector3, radius: float, strength: float) -> void:
	if strength < 0.25 or not _over(at,1.5): return
	for k in slabs.size():
		var top := slab_top(k)
		var s := Slam.share(at,radius,top)
		if s <= 0.0: continue
		var d := Vector2(top.x-at.x,top.z-at.z).length()
		_hop(k,HOP.y*1.6*s*strength,d < K.SLAB*0.6,Vector3(top.x-at.x,0.0,top.z-at.z),s,false)

## Slab `k` hops (`amp` m; driven down if `dip`), leaning out along `out`.
func _hop(k: int, amp: float, dip: bool, out: Vector3, share: float, hits: bool) -> void:
	var s: Dictionary = slabs[k]
	s.hop = 0.0
	s.amp = amp
	s.dip = dip
	s.out = out.normalized() if out.length() > 0.1 else Vector3.ZERO
	s.ring = 1.0
	s.dusted = false
	hops += 1
	if not hits or dip: return
	var m: PilotMotor = _hub.motor() if _hub != null else null
	if m == null or m.seized() or m.rider != null: return
	var now := _clock
	if _on_slab(m,k):
		_pending = {"k":k,"at":now,"share":share,"out":s.out}
	elif not m.grounded and jumped_at >= 0.0 and now-jumped_at <= PRE and slab_at(m.feet) == k and to_local(m.feet).y < 2.4:
		_launch(m,share,s.out)

## On slab `k`: over it, his feet on its top (or just lifted off it by its
## hop, not by a jump of his).
func _on_slab(m: PilotMotor, k: int) -> bool:
	if slab_at(m.feet) != k: return false
	var over := m.feet.y-to_global(Vector3(0.0,float(slabs[k].y),0.0)).y
	if m.grounded: return absf(over) < 0.5
	return over > -0.3 and over < 0.8 and not m.move in JUMPS and m.move != "tumble"

func _launch(m: PilotMotor, share: float, out: Vector3) -> void:
	var up := sqrt(2.0*m.gravity*lerpf(LAUNCH.y,LAUNCH.x,share)*m.size)
	var v := Vector3(m.velocity.x*0.6+out.x*LAUNCH_OUT,up,m.velocity.z*0.6+out.z*LAUNCH_OUT)
	m.toss(v)
	jumped_at = -1.0
	_pending = {}
	dealt.append(["colossus_drum","launch"])
	if _hub != null: _hub.knocked("colossus_drum","launch",v)
	Dust.puff(get_parent(),m.feet,2.2)

func _throw(m: PilotMotor, share: float, out: Vector3) -> void:
	var v := Vector3(out.x*KNOCK.y,sqrt(2.0*m.gravity*KNOCK.x*share*m.size),out.z*KNOCK.y)*Vector3(share,1.0,share)
	var kind := "knock"
	if m.move == "tumble":
		m.toss(v)
		kind = "toss"
	else: m.knock(v,src)
	dealt.append(["colossus_drum",kind])
	if _hub != null: _hub.knocked("colossus_drum",kind,v)

# --- A frame ---------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_clock += delta
	var m: PilotMotor = _hub.motor() if _hub != null else null
	if m != null:
		# His jump off a slab (left it rising).
		var on := slab_at(m.feet) if m.grounded and absf(to_local(m.feet).y) < 0.5 else -1
		if on < 0 and _was_on >= 0 and not m.grounded and m.velocity.y > 0.5 and m.move in JUMPS: jumped_at = _clock
		_was_on = on
		if not _pending.is_empty():
			if jumped_at >= float(_pending.at):
				_launch(m,float(_pending.share),_pending.out)
			elif _clock-float(_pending.at) >= GRACE:
				var k: int = _pending.k
				var share: float = _pending.share
				var out: Vector3 = _pending.out
				_pending = {}
				if _on_slab(m,k): _throw(m,share,out)
	for k in slabs.size():
		var s: Dictionary = slabs[k]
		if float(s.ring) > 0.0: s.ring = maxf(0.0,float(s.ring)-delta*RING_FADE)
		if float(s.hop) < 0.0:
			if float(s.ring) > 0.0: _draw(k)
			continue
		s.hop += delta
		var t: float = s.hop
		var amp: float = s.amp
		var y := 0.0
		if s.dip:
			y = -DIP*sin(PI*minf(t/0.3,1.0))
			if t >= 0.3: s.hop = -1.0
		else:
			var a := HOP_T.x
			var b := a+HOP_T.y
			var c := b+HOP_T.z
			var e := c+HOP_T.w
			if t < a: y = -0.12*amp*(t/a)
			elif t < b: y = lerpf(-0.12*amp,amp,1.0-pow(1.0-(t-a)/HOP_T.y,2.0))
			elif t < c: y = amp*(1.0-pow((t-b)/HOP_T.z,2.0))
			elif t < e:
				y = 0.12*amp*sin(PI*(t-c)/HOP_T.w)
				if not s.dusted:
					s.dusted = true
					if amp > 0.28: _dust(k,amp)
			else:
				y = 0.0
				s.hop = -1.0
		s.y = y
		s.lean = LEAN*clampf(y/maxf(amp,0.01),-0.3,1.0) if not s.dip else 0.0
		_draw(k)

func _dust(k: int, amp: float) -> void:
	var top := slab_top(k)
	var s: Dictionary = slabs[k]
	var out: Vector3 = s.out
	if out == Vector3.ZERO: out = Vector3.RIGHT
	Dust.puff(get_parent(),top+out*K.SLAB*0.5+Vector3.UP*0.1,1.2+amp*2.0,out)
	if k % 3 == 0 and _hub != null: _hub.sound(&"drum_thud",top)

## Slab `k` where it is in its hop, its ring lit as it rings.
func _draw(k: int) -> void:
	var s: Dictionary = slabs[k]
	var c: Vector2 = s.c
	var basis := Basis.IDENTITY
	if float(s.lean) != 0.0 and is_inside_tree():
		var lean_axis := Vector3.UP.cross(global_transform.basis.inverse()*(s.out as Vector3))
		if lean_axis.length() > 0.01: basis = Basis(lean_axis.normalized(),float(s.lean))
	var xf := Transform3D(basis,Vector3(c.x,float(s.y),c.y))
	(s.body as StaticBody3D).transform = xf
	_slab_mm.set_instance_transform(k,xf*Transform3D(Basis(Vector3.UP,_turns[k]*PI*0.5),Vector3.ZERO))
	_ring_mm.set_instance_transform(k,xf)
	_ring_mm.set_instance_color(k,GROOVE.lerp(RING_LIT,pow(float(s.ring),1.5)))
