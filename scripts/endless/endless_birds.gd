extends Node3D
## The endless flight's birds (docs/design/endless-flight/birds-handoff.md).
##
## Perched flocks wait in spruce tops near where the plane is heading (the
## trees' own plan, LandTrees `cell_trees`, no physics). The plane coming
## within FLUSH_SPANS of its span flushes one: each bird crouches a beat and
## bursts up and out, the flock forms up and flies alongside the plane for
## RIDE seconds (a little ahead, sliding back: they top out about the
## plane's cruise, so a boost leaves them), then peels off away from it and
## is dropped out of sight. A few loose flocks wheel far off over the land.
##
## All the birds are one MultiMesh of a small faceted bird (one draw call,
## no shadow); its wings are posed in shaders/endless_birds.gdshader from
## each instance's custom data (inner angle, outer bend, spread, tint), set
## here so the flap-and-glide, the startle and the tuck are timed by hand.
## Visual only: nothing collides, nothing touches the plane.
##
## Flags: --birds=0 off, --birds=X how many flocks wait in the trees (1),
## --bird-range=X the flush reach over its default (1), --bird-size=X (1),
## --bird-ride=S seconds alongside (6), --ambient-birds=X the far flocks
## (1; 0 none).

const LaunchArgs = preload("res://scripts/launch_args.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const Plan = preload("res://scripts/endless/tree_plan.gd")
const SHADER = preload("res://shaders/endless_birds.gdshader")

## The most birds drawn at once (the MultiMesh's instances).
const MAX_BIRDS := 140
## A bird's span over the plane's (WorldScale.span): about 1.05 m at the
## sizes' knobs, a dove-sized bird made readable at the plane's scale.
const SPAN_SHARE := 0.38
## The plane within this many of its spans of a perched flock flushes it.
const FLUSH_SPANS := 16.0
## Where perched flocks are put: this far ahead along the plane's way (m),
## within this far to either side of it, not nearer its line than LANE_MIN.
const AHEAD := Vector2(140.0,280.0)
const LANE := 38.0
const LANE_MIN := 5.0
## The plane higher than this over the ground puts no flocks in the trees.
const LOW := 80.0
## Flocks waiting in the trees at once (times --birds=), and the seconds
## between putting one (over --birds=).
const PERCHED := 2
const PERCH_GAP := 5.0
## Birds in a flock.
const FLOCK := Vector2i(9,17)
## The alongside: seconds, the slot beside the plane (lateral m, from ahead
## to beside m, over it m), and the birds' top speed over the plane's cruise.
const RIDE := 6.0
const SLOT_SIDE := Vector2(6.0,9.0)
const SLOT_AHEAD := Vector2(16.0,0.0)
const SLOT_OVER := Vector2(0.0,2.5)
const TOP_SPEED := 1.08
## Peeled: the turn away (rad) and its seconds, the speed over cruise, and
## the distance from the eye they are dropped past (or PEEL_LONGEST s).
const PEEL_TURN := 1.0
const PEEL_TIME := 3.0
const PEEL_SPEED := 0.78
const GONE := 200.0
const GONE_BEHIND := 50.0
const PEEL_LONGEST := 20.0
## The startle: each bird's delay (s, nearest the plane first), its crouch,
## and the burst (up, out from the tree, m/s) and its beats a second.
const STARTLE_SPREAD := 0.35
const CROUCH := 0.1
const BURST_UP := Vector2(4.5,7.0)
const BURST_OUT := 3.0
const BURST_TIME := 0.7
const BURST_BEAT := 19.0
## Cruising wingbeats a second, the flap and glide bounds (s), and the glide's
## dihedral.
const BEAT := 12.0
const FLAP_FOR := Vector2(0.3,0.65)
const GLIDE_FOR := Vector2(0.18,0.5)
const DIHEDRAL := 0.12
## The far flocks: how many, their birds, size over the near ones, how far
## from the eye they are put and dropped, and their height over the ground.
const AMBIENT := 2
const AMBIENT_FLOCK := Vector2i(16,26)
const AMBIENT_SIZE := 2.0
const AMBIENT_AT := Vector2(130.0,300.0)
const AMBIENT_GONE := 650.0
const AMBIENT_OVER := Vector2(28.0,70.0)

enum { PERCH, BURST, RIDING, PEEL, WHEEL }

class Bird:
	var p := Vector3.ZERO
	var v := Vector3.ZERO
	var off := Vector3.ZERO      # its place in the flock, in the flock's frame
	var face := Vector3.FORWARD  # where it points (lags its velocity)
	var roll := 0.0
	var delay := 0.0             # startle delay
	var t := 0.0                 # since it startled
	var phase := 0.0             # wingbeat
	var beat := BEAT
	var bound := 0.0             # time left in this flap or glide
	var flapping := true
	var flap_w := 1.0            # flap pose (1) against glide pose (0)
	var spread := 0.0
	var squash := 0.0
	var tint := 0.0
	var seed := 0.0

class Flock:
	var state := PERCH
	var birds: Array = []
	var a := Vector3.ZERO        # the anchor the birds keep station on
	var av := Vector3.ZERO
	var t := 0.0                 # in this state
	var tree := Vector4.ZERO     # x, z, foot y, height
	var side := 1.0
	var lateral := 10.0
	var over := 2.0
	var peel_from := Vector3.FORWARD
	var climb := 0.0
	var spread := 1.0
	var size := 1.0
	var ground := 0.0
	var centre := Vector3.ZERO   # a far flock's wheel
	var radius := 50.0
	var spin := 1.0

var enabled := true
var density := 1.0
var reach := 1.0
var size := 1.0
var ride := RIDE
var ambient := 1.0
var flocks: Array = []
## The numbers (F1) and the harness: flushes so far, and the last step's ms.
var stats := {"flushed":0,"rode":0,"peeled":0,"dropped":0,"ms":0.0,"ms_avg":0.0}

var _field: RefCounted
var _trees: Node3D
var _rng := RandomNumberGenerator.new()
var _mm: MultiMesh
var _mmi: MultiMeshInstance3D
var _buf := PackedFloat32Array()
var _perch_wait := 0.0
var _span := 0.6
var _tick := 0

static func flags() -> Dictionary:
	var out := {"on":true,"density":1.0,"reach":1.0,"size":1.0,"ride":RIDE,"ambient":1.0}
	for a: String in LaunchArgs.user_args():
		var v := a.get_slice("=",1)
		if a.begins_with("--birds="):
			out.density = maxf(0.0,float(v))
			out.on = out.density > 0.0
		elif a == "--no-birds": out.on = false
		elif a.begins_with("--bird-range="): out.reach = maxf(0.1,float(v))
		elif a.begins_with("--bird-size="): out.size = maxf(0.1,float(v))
		elif a.begins_with("--bird-ride="): out.ride = maxf(0.0,float(v))
		elif a.begins_with("--ambient-birds="): out.ambient = maxf(0.0,float(v))
	return out

func setup(land_seed: int, field: RefCounted, trees: Node3D) -> void:
	var f := flags()
	enabled = f.on
	density = f.density
	reach = f.reach
	size = f.size
	ride = f.ride
	ambient = f.ambient
	_field = field
	_trees = trees
	_rng.seed = hash("birds%d" % land_seed)
	_span = WorldScale.span*SPAN_SHARE*size
	if not enabled: return
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_custom_data = true
	_mm.mesh = bird_mesh()
	_mm.instance_count = MAX_BIRDS
	_mm.visible_instance_count = 0
	_buf.resize(MAX_BIRDS*16)
	_mmi = MultiMeshInstance3D.new()
	_mmi.name = "Birds"
	_mmi.multimesh = _mm
	_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ShaderMaterial.new()
	m.shader = SHADER
	_mmi.material_override = m
	add_child(_mmi)

func bird_count() -> int:
	var n := 0
	for f: Flock in flocks: n += f.birds.size()
	return n

func count_in(state: int) -> int:
	var n := 0
	for f: Flock in flocks:
		if f.state == state: n += 1
	return n

## The flush reach (m).
func flush_reach() -> float:
	return WorldScale.span*FLUSH_SPANS*reach

## One frame: flocks put and dropped round the plane, flushed, flown and drawn.
## `plane` is the SkyPlane (position, velocity, speed, cruise()).
func step(delta: float, eye: Vector3, plane: RefCounted) -> void:
	if not enabled: return
	var began := Time.get_ticks_usec()
	var pp: Vector3 = plane.position
	var pv: Vector3 = plane.velocity
	var cruise: float = plane.cruise()
	_tick += 1
	_perch_wait -= delta
	if _perch_wait <= 0.0:
		_perch_wait = 0.5
		_put_perched(pp,pv)
		_put_ambient(eye)
	for i in range(flocks.size()-1,-1,-1):
		var f: Flock = flocks[i]
		if not _flock_step(f,delta,eye,pp,pv,cruise):
			flocks.remove_at(i)
			stats.dropped += 1
	var t_draw := Time.get_ticks_usec()
	_draw()
	stats["draw_ms"] = lerpf(float(stats.get("draw_ms",0.0)),(Time.get_ticks_usec()-t_draw)/1000.0,0.05)
	var ms := (Time.get_ticks_usec()-began)/1000.0
	stats.ms = ms
	stats.ms_avg = lerpf(float(stats.ms_avg),ms,0.05)

# --- Putting flocks --------------------------------------------------------------

func _put_perched(pp: Vector3, pv: Vector3) -> void:
	if _trees == null or not _trees.enabled or density <= 0.0: return
	if count_in(PERCH) >= ceili(PERCHED*density): return
	var flat := Vector3(pv.x,0.0,pv.z)
	if flat.length() < 3.0: return
	if pp.y-_field.height(pp.x,pp.z) > LOW: return
	var fwd := flat.normalized()
	var right := fwd.cross(Vector3.UP)
	# Cells along the way ahead; a few trees sampled from each.
	var tried := {}
	var best := Vector4.INF
	for k in 5:
		var along := lerpf(AHEAD.x,AHEAD.y,k/4.0)
		var c := pp+fwd*along
		var ck := Plan.cell_of(c.x,c.z)
		if tried.has(ck): continue
		tried[ck] = true
		var list: PackedFloat32Array = _trees.cell_trees(ck)
		var n := list.size()/8
		if n == 0: continue
		for s in 24:
			var q := _rng.randi_range(0,n-1)*8
			var d := Vector3(list[q]-pp.x,0.0,list[q+1]-pp.z)
			var ahead := d.dot(fwd)
			var side := absf(d.dot(right))
			if ahead < AHEAD.x or ahead > AHEAD.y or side > LANE or side < LANE_MIN: continue
			if list[q+3] < 4.0: continue
			var t := Vector4(list[q],list[q+1],list[q+2],list[q+3])
			if _taken(t): continue
			best = t
			break
		if best != Vector4.INF: break
	if best == Vector4.INF: return
	if bird_count()+FLOCK.y > MAX_BIRDS: return
	_perch(best,list_radius(best))
	_perch_wait = PERCH_GAP/maxf(density,0.1)

## A crown's radius at its foot, for a tree's height (the plan's spruces are
## about a fifth as wide as tall at the crown's foot).
func list_radius(t: Vector4) -> float:
	return t.w*0.19

func _taken(t: Vector4) -> bool:
	for f: Flock in flocks:
		if f.state == WHEEL: continue
		if Vector2(f.tree.x-t.x,f.tree.y-t.y).length() < 60.0: return true
	return false

func _perch(t: Vector4, radius: float) -> void:
	var f := Flock.new()
	f.state = PERCH
	f.tree = t
	f.size = 1.0
	var top := t.z+t.w
	f.a = Vector3(t.x,top,t.y)
	f.ground = t.z
	var n := _rng.randi_range(FLOCK.x,FLOCK.y)
	var tint := _rng.randf_range(0.0,1.0)*_rng.randf()
	for i in n:
		var b := Bird.new()
		# On the crown's cone, mostly the top third, a few on the tip.
		var h := 1.0 if i == 0 else _rng.randf_range(0.62,0.97)
		var r := radius*(1.0-h)/0.75*0.95+0.15
		var ang := _rng.randf()*TAU
		var out := Vector3(cos(ang),0.0,sin(ang))
		b.p = Vector3(t.x,t.z+t.w*h,t.y)+out*r
		b.face = Vector3(-out.z,0.0,out.x)*(1.0 if _rng.randf() < 0.5 else -1.0)
		b.off = Vector3(_rng.randf_range(-1,1),_rng.randf_range(-0.5,0.5),_rng.randf_range(-1,1))
		b.tint = clampf(tint+_rng.randf_range(-0.12,0.12),0.0,1.0)
		b.seed = _rng.randf()*100.0
		b.beat = BEAT*_rng.randf_range(0.88,1.12)
		b.phase = _rng.randf()*TAU
		b.spread = 0.0
		b.flap_w = 0.0
		f.birds.append(b)
	flocks.append(f)

func _put_ambient(eye: Vector3) -> void:
	if ambient <= 0.0: return
	var far := 0
	for f: Flock in flocks:
		if f.state == WHEEL: far += 1
	if far >= roundi(AMBIENT*ambient): return
	if bird_count()+AMBIENT_FLOCK.y > MAX_BIRDS: return
	var view := get_viewport().get_camera_3d()
	var fwd := -view.global_basis.z if view != null else Vector3.FORWARD
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var ang := _rng.randf_range(-0.9,0.9)
	var dir := fwd.rotated(Vector3.UP,ang)
	var c := eye+dir*_rng.randf_range(AMBIENT_AT.x,AMBIENT_AT.y)
	# Over the higher of two spots: along ridges more than in hollows.
	var c2 := c+dir.rotated(Vector3.UP,PI*0.5)*_rng.randf_range(-60.0,60.0)
	var g1: float = maxf(_field.height(c.x,c.z),-INF)
	var g2: float = _field.height(c2.x,c2.z)
	if g2 > g1:
		c = c2
		g1 = g2
	var sea: float = preload("res://scripts/endless/land_field.gd").SEA_Y
	g1 = maxf(g1,sea)
	var f := Flock.new()
	f.state = WHEEL
	f.size = AMBIENT_SIZE
	f.ground = g1
	f.centre = Vector3(c.x,g1+_rng.randf_range(AMBIENT_OVER.x,AMBIENT_OVER.y),c.z)
	f.radius = _rng.randf_range(35.0,75.0)
	f.spin = 1.0 if _rng.randf() < 0.5 else -1.0
	f.spread = _rng.randf_range(1.8,2.8)
	f.t = _rng.randf()*30.0
	var speed := 10.0
	var ph := _rng.randf()*TAU
	f.a = f.centre+Vector3(cos(ph),0.0,sin(ph))*f.radius
	f.av = Vector3(-sin(ph),0.0,cos(ph))*speed*f.spin
	var n := _rng.randi_range(AMBIENT_FLOCK.x,AMBIENT_FLOCK.y)
	var tint := _rng.randf()*0.4
	for i in n:
		var b := Bird.new()
		b.off = Vector3(_rng.randf_range(-1,1),_rng.randf_range(-0.6,0.6),_rng.randf_range(-1,1))
		b.p = f.a+b.off*4.0*f.spread
		b.v = f.av
		b.face = f.av.normalized()
		b.tint = clampf(tint+_rng.randf_range(-0.1,0.1),0.0,1.0)
		b.seed = _rng.randf()*100.0
		b.beat = BEAT*0.8*_rng.randf_range(0.88,1.12)
		b.phase = _rng.randf()*TAU
		b.spread = 1.0
		b.t = 10.0
		f.birds.append(b)
	flocks.append(f)

# --- Flying ------------------------------------------------------------------------

## One flock's frame; false once it is to be dropped.
func _flock_step(f: Flock, delta: float, eye: Vector3, pp: Vector3, pv: Vector3, cruise: float) -> bool:
	f.t += delta
	var flat := Vector3(pv.x,0.0,pv.z)
	var fwd := flat.normalized() if flat.length() > 0.5 else Vector3.FORWARD
	var right := fwd.cross(Vector3.UP)
	match f.state:
		PERCH:
			var to := pp-f.a
			if to.length() < flush_reach() and to.dot(pv) < 0.0:
				_flush(f,pp,fwd,right)
			elif to.dot(fwd) > 60.0 or to.length() > AHEAD.y*1.6:
				return false
			else:
				_sit(f,delta)
				return true
		BURST:
			# Up out of the tree and away ahead of the plane, toward the slot.
			var rise := clampf((pp.y+f.over-f.a.y)*0.9,2.0,8.0)
			var want := fwd*cruise*0.75+Vector3.UP*rise+right*f.side*2.5
			f.av = f.av.move_toward(want,delta*14.0)
			f.a += f.av*delta
			if f.t > BURST_TIME:
				f.state = RIDING
				f.t = 0.0
				stats.rode += 1
		RIDING:
			var k := clampf(f.t/maxf(ride,0.1),0.0,1.0)
			var along := lerpf(SLOT_AHEAD.x,SLOT_AHEAD.y,k)
			var slot := pp+fwd*along+right*f.side*f.lateral+Vector3.UP*f.over
			var want := pv+(slot-f.a)*1.1
			var top := cruise*TOP_SPEED
			if want.length() > top: want = want.normalized()*top
			f.av = f.av.move_toward(want,delta*10.0)
			f.a += f.av*delta
			# Left behind (a boost) or done: away.
			if f.t > ride or (pp-f.a).dot(fwd) > 25.0:
				f.state = PEEL
				f.t = 0.0
				f.peel_from = fwd
				f.climb = _rng.randf_range(-0.8,2.2)
				stats.peeled += 1
		PEEL:
			var k := smoothstep(0.0,PEEL_TIME,f.t)
			var dir := f.peel_from.rotated(Vector3.UP,-f.side*PEEL_TURN*k)
			var want := dir*cruise*PEEL_SPEED+Vector3.UP*f.climb*k
			f.av = f.av.move_toward(want,delta*6.0)
			f.a += f.av*delta
			var far := (f.a-eye).length()
			var view := get_viewport().get_camera_3d()
			var behind := view != null and (f.a-eye).dot(-view.global_basis.z) < 0.0
			if far > GONE or f.t > PEEL_LONGEST or (behind and far > GONE_BEHIND): return false
		WHEEL:
			var rel := f.a-f.centre
			rel.y = 0.0
			var tang := Vector3(-rel.z,0.0,rel.x).normalized()*f.spin
			var pull := -rel.normalized()*(rel.length()-f.radius)*0.15
			var bob := sin(f.t*0.7+f.radius)*2.5
			var want := tang*10.0+pull+Vector3.UP*(f.centre.y+bob-f.a.y)*0.4
			f.av = f.av.move_toward(want,delta*5.0)
			f.a += f.av*delta
			f.centre += Vector3(0.6,0.0,0.3)*delta
			f.spread = lerpf(f.spread,2.3+0.8*sin(f.t*0.35+f.radius),delta*0.5)
			if (f.a-eye).length() > AMBIENT_GONE: return false
	# The ground under the anchor, once a frame for the flock.
	if f.state != WHEEL:
		var g: float = _field.height(f.a.x,f.a.z)
		f.ground = maxf(g,preload("res://scripts/endless/land_field.gd").SEA_Y)
		if f.a.y < f.ground+3.0:
			f.a.y = f.ground+3.0
			f.av.y = maxf(f.av.y,0.0)
	# The far flocks fly every other frame (half the cost; too far to see it).
	if f.state == WHEEL:
		if (_tick+int(f.radius))%2 == 0: _fly_birds(f,delta*2.0,pp)
	else: _fly_birds(f,delta,pp)
	return true

func _flush(f: Flock, pp: Vector3, fwd: Vector3, right: Vector3) -> void:
	f.state = BURST
	f.t = 0.0
	stats.flushed += 1
	var lat := (f.a-pp).dot(right)
	f.side = signf(lat) if absf(lat) > 0.5 else (1.0 if _rng.randf() < 0.5 else -1.0)
	f.lateral = clampf(absf(lat),SLOT_SIDE.x,SLOT_SIDE.y)
	f.over = _rng.randf_range(SLOT_OVER.x,SLOT_OVER.y)
	f.av = Vector3.UP*4.0
	f.spread = _rng.randf_range(0.9,1.3)
	# Nearest the plane go first, a ripple through the crown.
	var near := INF
	var far := -INF
	for b: Bird in f.birds:
		var d := (b.p-pp).length()
		near = minf(near,d)
		far = maxf(far,d)
	for b: Bird in f.birds:
		var d := (b.p-pp).length()
		b.delay = remap(d,near,far+0.01,0.0,STARTLE_SPREAD)+_rng.randf_range(0.0,0.08)
		b.t = -b.delay

func _sit(f: Flock, delta: float) -> void:
	for b: Bird in f.birds:
		b.t += delta
		# Now and then one turns on its twig.
		if _rng.randf() < delta*0.15:
			b.face = b.face.rotated(Vector3.UP,_rng.randf_range(-1.2,1.2))

func _fly_birds(f: Flock, delta: float, pp: Vector3) -> void:
	var n := f.birds.size()
	var heading := f.av
	heading.y = 0.0
	var fx := heading.normalized() if heading.length() > 0.5 else Vector3.FORWARD
	var rx := fx.cross(Vector3.UP)
	var keep := 3.0*f.spread*f.size
	var sep := _span*f.size*3.0
	var avoid := WorldScale.span*1.5
	var accel := 16.0
	# The flock's mean velocity, for alignment.
	var mean := Vector3.ZERO
	for b: Bird in f.birds: mean += b.v
	mean /= maxf(n,1)
	for i in n:
		var b: Bird = f.birds[i]
		b.t += delta
		if b.t < 0.0: continue           # still sat, not yet startled
		if f.state == BURST and b.t < CROUCH:
			# The crouch: a squat and the wings eased off the back.
			b.squash = -b.t/CROUCH
			b.spread = 0.25*b.t/CROUCH
			continue
		if f.state == BURST and b.t-delta < CROUCH:
			# Off: up and out from the tree, wings flung up for the first stroke.
			var out := b.p-Vector3(f.tree.x,b.p.y,f.tree.y)
			out = out.normalized() if out.length() > 0.1 else rx
			b.v = Vector3.UP*_rng.randf_range(BURST_UP.x,BURST_UP.y)+out*BURST_OUT+fx*2.0
			b.phase = PI*0.5
			b.squash = 1.0
			b.flapping = true
			b.bound = BURST_TIME
		var w := b.off
		# The flock breathes: places drift slowly.
		w += Vector3(sin(b.t*0.5+b.seed),sin(b.t*0.37+b.seed*1.7)*0.5,cos(b.t*0.43+b.seed))*0.35
		var place := f.a+rx*w.x*keep+Vector3.UP*w.y*keep*0.6+fx*w.z*keep*1.3
		var want := f.av+(place-b.p)*1.4+(mean-b.v)*0.3
		# Apart from the nearest few (the flock's order, in turn).
		for j in range(1,4 if f.state != WHEEL else 2):
			var o: Bird = f.birds[(i+j*((int(b.seed)%5)+1))%n]
			var d := b.p-o.p
			var l := d.length()
			if l < sep and l > 0.001: want += d/l*(sep-l)*4.0
		# Clear of the plane, always.
		var dp := b.p-pp
		var lp := dp.length()
		if lp < avoid: want += dp/maxf(lp,0.01)*(avoid-lp)*6.0
		var dv := want-b.v
		var acc := accel*(2.2 if f.state == BURST else 1.0)
		if dv.length() > acc*delta: dv = dv.normalized()*acc*delta
		b.v += dv
		b.p += b.v*delta
		if b.p.y < f.ground+0.8 and f.state != PERCH:
			b.p.y = f.ground+0.8
			b.v.y = maxf(b.v.y,0.5)
		_wings(b,f,delta,dv.length()/maxf(delta,0.0001))
		# Faces where it flies, a beat behind (the follow-through), and
		# rolls into its turns.
		if b.v.length() > 0.5:
			b.face = b.face.slerp(b.v.normalized(),minf(1.0,delta*7.0)).normalized()
			var side_acc := (dv/maxf(delta,0.0001)).dot(b.face.cross(Vector3.UP))
			b.roll = lerpf(b.roll,clampf(-side_acc*0.09,-1.1,1.1),minf(1.0,delta*5.0))
		b.squash = move_toward(b.squash,0.0,delta*5.0)

## The wings: a startled bird beats hard; then bounds of flapping and of
## gliding with wings held out, beating more when it climbs or works hard.
func _wings(b: Bird, f: Flock, delta: float, effort: float) -> void:
	var beat := b.beat
	if f.state == BURST:
		beat = BURST_BEAT
		b.flapping = true
	else:
		b.bound -= delta
		if b.bound <= 0.0:
			var hard := b.v.y > 1.2 or effort > 7.0
			b.flapping = hard or not b.flapping
			var relaxed := 1.6 if f.state == PEEL or f.state == WHEEL else 1.0
			b.bound = _rng.randf_range(FLAP_FOR.x,FLAP_FOR.y) if b.flapping else _rng.randf_range(GLIDE_FOR.x,GLIDE_FOR.y)*relaxed
	b.spread = move_toward(b.spread,1.0,delta*6.0)
	b.flap_w = move_toward(b.flap_w,1.0 if b.flapping else 0.0,delta*(9.0 if b.flapping else 6.0))
	# Keep beating out the stroke into the glide, so the wings settle from
	# where they were rather than snapping.
	if b.flapping or b.flap_w > 0.02: b.phase = fmod(b.phase+TAU*beat*delta,TAU)

func _wing_pose(b: Bird) -> Vector2:
	# A fast downstroke and a slower recovery: the phase warped.
	var ph := b.phase+0.45*sin(b.phase)
	var s := cos(ph)                       # 1 up, -1 down
	var inner := 0.25+0.85*s
	var outer := 0.55*cos(ph+0.9)-0.1      # the hand lags the arm
	var glide := Vector2(DIHEDRAL,-0.04)
	return glide.lerp(Vector2(inner,outer),b.flap_w)

# --- Drawing -------------------------------------------------------------------------

func _draw() -> void:
	var i := 0
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for f: Flock in flocks:
		var sz := _span*f.size
		for b: Bird in f.birds:
			if i >= MAX_BIRDS: break
			# Its frame by hand (cheaper than Basis.looking_at): z back along
			# its facing, rolled about it, scaled for the squash and stretch
			# (+ long and thin on the burst, - squat).
			var bz := -b.face
			var bx := Vector3(bz.z,0.0,-bz.x)   # up x z
			var lx := bx.length()
			bx = bx/lx if lx > 0.001 else Vector3.RIGHT
			var by := bz.cross(bx)
			if b.roll != 0.0:
				var c := cos(b.roll)
				var sn := sin(b.roll)
				var rx := bx*c+by*sn
				by = by*c-bx*sn
				bx = rx
			var sq := b.squash
			bx *= sz*(1.0-0.1*sq)
			by *= sz*(1.0+(0.18*sq if sq < 0.0 else -0.12*sq))
			bz *= sz*(1.0+maxf(sq,0.0)*0.2)
			var pose := _wing_pose(b) if b.spread > 0.0 else Vector2.ZERO
			var at := b.p
			# The body rides each stroke: up on the downstroke.
			if b.flap_w > 0.0: at += by*(-sin(b.phase))*0.05*b.flap_w
			if sq < 0.0: at.y += sq*0.06*sz
			var q := i*16
			_buf[q] = bx.x; _buf[q+1] = by.x; _buf[q+2] = bz.x; _buf[q+3] = at.x
			_buf[q+4] = bx.y; _buf[q+5] = by.y; _buf[q+6] = bz.y; _buf[q+7] = at.y
			_buf[q+8] = bx.z; _buf[q+9] = by.z; _buf[q+10] = bz.z; _buf[q+11] = at.z
			_buf[q+12] = pose.x; _buf[q+13] = pose.y; _buf[q+14] = b.spread; _buf[q+15] = b.tint
			lo = lo.min(at)
			hi = hi.max(at)
			i += 1
	_mm.visible_instance_count = i
	if i > 0:
		RenderingServer.multimesh_set_buffer(_mm.get_rid(),_buf)
		var pad := Vector3.ONE*(_span*AMBIENT_SIZE+1.0)
		_mmi.custom_aabb = AABB(lo-pad,hi-lo+pad*2.0)

# --- The bird -----------------------------------------------------------------------

## A small faceted bird, span 1, facing -z: body, head and beak, tail fan,
## and two wings with an elbow (shaders/endless_birds.gdshader bends them).
static func bird_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var back := Color("a29a90").srgb_to_linear()
	var belly := Color("d8cdbb").srgb_to_linear()
	var wing := Color("b4ada3")
	var hand := Color("3b3633").srgb_to_linear().srgb_to_linear()
	var beak := Color("8a7448").srgb_to_linear()
	# The body: rings along z (z, half width, half height, y), six sides.
	var rings := [
		Vector4(-0.165,0.004,0.004,0.0),
		Vector4(-0.13,0.022,0.022,0.004),
		Vector4(-0.1,0.03,0.03,0.006),
		Vector4(-0.06,0.03,0.03,0.0),
		Vector4(0.0,0.048,0.045,0.0),
		Vector4(0.07,0.038,0.035,0.004),
		Vector4(0.13,0.016,0.014,0.01)]
	const SIDES := 6
	for r in rings.size()-1:
		var r0: Vector4 = rings[r]
		var r1: Vector4 = rings[r+1]
		for s in SIDES:
			var a0 := TAU*s/SIDES
			var a1 := TAU*(s+1)/SIDES
			var p00 := Vector3(cos(a0)*r0.y,sin(a0)*r0.z+r0.w,r0.x)
			var p01 := Vector3(cos(a1)*r0.y,sin(a1)*r0.z+r0.w,r0.x)
			var p10 := Vector3(cos(a0)*r1.y,sin(a0)*r1.z+r1.w,r1.x)
			var p11 := Vector3(cos(a1)*r1.y,sin(a1)*r1.z+r1.w,r1.x)
			var c := belly if sin((a0+a1)*0.5) < -0.3 else back
			if r == 0: c = beak
			_tri(st,p00,p10,p11,c)
			_tri(st,p00,p11,p01,c)
	# The tail fan.
	_tri(st,Vector3(-0.012,0.01,0.12),Vector3(-0.05,0.012,0.25),Vector3(0.05,0.012,0.25),back)
	_tri(st,Vector3(-0.012,0.01,0.12),Vector3(0.05,0.012,0.25),Vector3(0.012,0.01,0.12),back)
	# The wings: root at the shoulder, an elbow, a swept pointed hand.
	for side: float in [-1.0,1.0]:
		var r0 := Vector3(0.056*side,0.012,-0.04)
		var r1 := Vector3(0.056*side,0.012,0.06)
		var e0 := Vector3(0.27*side,0.012,-0.05)
		var e1 := Vector3(0.27*side,0.012,0.075)
		var tip := Vector3(0.5*side,0.012,0.06)
		_tri(st,r0,e0,e1,wing)
		_tri(st,r0,e1,r1,wing)
		_tri(st,e0,tip,e1,hand)
	st.generate_normals()
	return st.commit()

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	st.set_color(col)
	st.add_vertex(a)
	st.set_color(col)
	st.add_vertex(c)
	st.set_color(col)
	st.add_vertex(b)

## The numbers line (F1).
func note() -> String:
	if not enabled: return "\nno birds"
	var flying := 0
	var perched := 0
	for f: Flock in flocks:
		if f.state == PERCH: perched += f.birds.size()
		else: flying += f.birds.size()
	return "\nbirds: %d flying, %d perched in %d flocks  ·  %d flushed  ·  %.2f ms (avg %.2f), 1 draw" % [
		flying,perched,flocks.size(),int(stats.flushed),float(stats.ms),float(stats.ms_avg)]
