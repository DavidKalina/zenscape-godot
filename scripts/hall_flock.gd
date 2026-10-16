extends Node3D
## The swifts of the Sundered line's halls (docs/scenic/hall-flock.md): each
## real piece of the line (scripts/hall_line.gd) keeps a roost of a few
## hundred small dark birds on its high places (the ties' and beams' tops,
## the walls' heads, the roof's broken edges), and as the plane comes into
## its nave the birds ahead startle, a beat before it reaches them and one
## after another, so the burst ripples on ahead of it. Most drop off their
## ledges into the nave and stream on down it ahead of the plane, weaving
## between the columns, under the ties and down the plane's own lane, faster
## than the plane, and pour up out of the far end's open roof; the rest go
## the nearest way out (a roof break, an open bay, a side arch) and up. Over
## the hall they gather into one swirling body that sweeps on ahead and
## wheels off to the left, banking as one. Once the plane is well past they
## come home one after another, each back down its own way to its own ledge.
##
## Never through stone. Each piece's flight is planned on a worker as the
## piece rises (`plan`): its hulls' boxes (scripts/hall_line_build.gd
## `boxes`, grown by PAD) laid in a grid of CELL, and from every open cell
## its steps out (breadth-first walks): the nearest way (to the grid's top
## or sides), the plane's lane shut (LANE_PAD round it); and the stream's
## way (to the top of its last FAR_END m only, under CEILING and within the
## lane's width short of it) with the lane open, and down into it from
## anywhere. A bird's way is its cell walk from its ledge pulled straight
## where the grid sees through, woven side to side where it has room
## (WEAVE), smoothed, checked again against the boxes themselves, then
## climbing (out of the top, or straight up past the island's side) to over
## everything the piece has (`top`). Over `top` and outside the piece's
## footprint the air is clear, and every free flight (the flock, the joins)
## is kept there (`_clear`).
##
## Never into the plane. The nearest ways keep out of its lane. A stream
## bird goes only while a plane at PLANE_PACE would still be GAP behind it
## wherever its way is in the lane (and sooner for a faster plane), flies
## faster than the plane can, and one the plane is already on (a piece that
## stood late) keeps to its ledge.
##
## Cheap. Every bird is a closed form of its piece's clock: on its ledge;
## along its way (accelerating off the ledge, `path_at`); easing into its
## slot in the flock (`slot`: the flock's middle on a sweeping, looping
## course, its body turning with it); and home again, the same way back. Its
## heading and bank come from its way since the last frame. A piece's birds
## are one MultiMesh (the swift, `bird_mesh`, its wings beaten in shaders/
## hall_flock_bird.gdshader from each bird's custom data), their poses
## worked out on the workers each frame a flock is up and handed over the
## next. A piece's flock is stood under its node, so it rises, sinks and is
## freed with it.
##
## Heard: a rush of wings (the kit's flutter, sped up) at the flock, louder
## the more are up; a flurry of wings as it bursts; the screams (the kit's
## chirps and twitters, pitched up) from birds in it.
##
## --hall-flock=0 turns it off; --hall-flock=<n> sets the birds a piece;
## --hall-flock-size=<x> their size (times SIZE).

const Hall = preload("res://scripts/ruin_kit_hall.gd")
const LineBuild = preload("res://scripts/hall_line_build.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const SHADER := preload("res://shaders/hall_flock_bird.gdshader")

## Birds a piece, their size (times a real swift's 0.42 m span: bigger, so
## they read at the plane's speed).
const COUNT := 480
const SIZE := 3.0
## The plan's grid (m), how far it keeps every bird from the stone's boxes
## (m), the plane's lane shut this much wider and higher (m).
const CELL := 1.0
const PAD := 0.5
const LANE_PAD := Vector2(1.2,3.5)
## The lowest ledge (m over the floor) a bird roosts on.
const ROOST_LOW := 4.5
## A bird going the nearest way startles once the plane is this far short
## of the nearest it comes (m along the nave, a range), plus up to STAGGER s.
const LEAD := Vector2(30.0,55.0)
const STAGGER := 0.5
## A bird the plane is already within this of (m along the nave) keeps
## to its ledge.
const MIN_AHEAD := 18.0
## Flight: top speed along its way (m/s, a range), off the ledge at V0 and
## gaining ACCEL; JOIN s easing into the flock.
const SPEED := Vector2(15.0,20.0)
## The stream down the nave (and the plane's lane) flies faster; it goes
## while a plane at PLANE_PACE (m/s) would stay GAP (m) behind every bird of
## it in the lane, and up to STREAM_LEAD m sooner.
const STREAM_SPEED := Vector2(22.0,27.0)
const PLANE_PACE := 18.0
const GAP := 8.0
const STREAM_LEAD := 10.0
const V0 := 2.0
const ACCEL := 14.0
const JOIN := 1.8
## The flock: its body's half extents (across, up, along: m), its loops
## (radius m, rad/s), how fast it first sweeps on (m/s), how far left it
## drifts (m), how high over `top` it flies (m).
const BODY := Vector3(9.0,3.0,12.0)
const LOOP_R := 8.0
const LOOP_W := 0.62
const SWEEP := 17.0
const SIDE := -16.0
const OVER := 3.0
## Of the birds roosting short of the far end, this share streams on down
## the nave and out of its last FAR_END m (the rest take the nearest way).
const FAR_SHARE := 0.9
const FAR_END := 12.0
## Streaming down the nave they keep under this (m: the high ties' soffit
## less PAD) and within the lane's width (and a metre) till the far end:
## under the ties and beams, where the plane sees them against the far
## end's light.
const CEILING := 5.5
## Home once the plane is this far past the piece's end (m), spread over
## HOME_SPREAD s.
const HOME_PAST := 40.0
const HOME_SPREAD := 6.0
## Drawn this near (m).
const FAR := 240.0
## The way's samples (m apart).
const DS := 0.3
## Ways weave from side to side: a swing every WEAVE_STEP m, WEAVE m across
## (a range, less where the stone is near).
const WEAVE_STEP := 6.0
## A way's cell walk is pulled straight this many cells on at most.
const PULL := 6
const WEAVE := Vector2(1.2,3.2)
## The kit's sounds (scripts/kit_isle/kit_audio.gd's; tools/
## generate_kit_audio.py).
const KIT := "res://assets/audio/kit/"

var line: Node = null
## Each piece's flock, by the piece's index.
var flocks := {}
var count := COUNT
var size := SIZE
## For HUDs and checks: the last frame's main-thread cost (usec), the worst
## so far, and the worker's.
var main_usec := 0
var worst_main := 0
var work_usec := 0
var worst_work := 0
var _task := -1
var _working: Array = []
var _rush: AudioStreamPlayer3D
var _calls: Array[AudioStreamPlayer3D] = []
var _call_streams: Array = []
var _wing_streams: Array = []
var _call_clock := 0.0
var _rng := RandomNumberGenerator.new()
static var _mesh: ArrayMesh
static var _material: ShaderMaterial

## One piece's flock.
class Flock extends RefCounted:
	var index := 0
	var made := {}
	var task := -1
	var out := {}
	var plan := {}
	var node: MultiMeshInstance3D = null
	var n := 0
	var clock := 0.0
	var t_start := PackedFloat32Array()
	var t_ret := PackedFloat32Array()
	var next := 0
	var blob0 := -1.0
	var s_start := 0.0
	var home := false
	var landed := 0
	var started := 0
	var buf := PackedFloat32Array()
	var positions := PackedVector3Array()
	var flying := 0
	var centroid := Vector3.ZERO
	var size := 1.5
	var burst_heard := false
	# The plan's arrays, held typed (read on the worker).
	var roost := PackedVector3Array()
	var yaw := PackedFloat32Array()
	var first := PackedInt32Array()
	var counts := PackedInt32Array()
	var pts := PackedVector3Array()
	var high := PackedVector3Array()
	var vmax := PackedFloat32Array()
	var dur := PackedFloat32Array()
	var slots := PackedVector3Array()
	var phase := PackedFloat32Array()
	var scale := PackedFloat32Array()
	var length := 0.0
	var top := 0.0
	var x_clear := 0.0
	# Each bird's last place, way (m/s) and bank, and when (the flock's
	# clock), for its pose from frame to frame.
	var last_p := PackedVector3Array()
	var last_v := PackedVector3Array()
	var bank := PackedFloat32Array()
	var last_t := -INF
	# The flock's body this frame: its middle and its axes (`frame`).
	var took := 0
	var _ft := -INF
	var _fc := Vector3.ZERO
	var _fr := Vector3.RIGHT
	var _fu := Vector3.UP
	var _ff := Vector3.FORWARD

	## Takes the plan's arrays (on the main thread, once).
	func take(p: Dictionary) -> void:
		plan = p
		roost = p.roost
		yaw = p.yaw
		first = p.first
		counts = p.count
		pts = p.pts
		high = p.high
		vmax = p.vmax
		dur = p.dur
		slots = p.slot
		phase = p.phase
		length = p.length
		top = p.top
		x_clear = p.x_clear
		n = roost.size()
		scale.resize(n)
		for b in range(n): scale[b] = size*(0.9+0.2*phase[(b*7)%n])
		t_start.resize(n)
		t_start.fill(INF)
		t_ret.resize(n)
		t_ret.fill(INF)
		buf.resize(n*16)
		positions.resize(n)
		last_p.resize(n)
		last_v.resize(n)
		bank.resize(n)
		bank.fill(0.0)
		for b in range(n): _perch(b)

	## Where bird `b` is at the flock's clock `t` (the piece's frame).
	func at(b: int, t: float) -> Vector3:
		var t0 := t_start[b]
		if t < t0: return roost[b]
		var d := dur[b]
		var tr := t_ret[b]
		if t >= tr:
			var r := t-tr
			if r < JOIN:
				var ext := high[b]+Vector3.UP*(vmax[b]*(JOIN-r))
				return _clear(slot(b,t).lerp(ext,smoothstep(0.0,JOIN,r)))
			r -= JOIN
			if r >= d: return roost[b]
			return path_at(b,d-r)
		var u := t-t0
		if u < d: return path_at(b,u)
		var v := u-d
		var ext := high[b]+Vector3.UP*(vmax[b]*v)
		return _clear(ext.lerp(slot(b,t),smoothstep(0.0,JOIN,v)))

	## Along bird `b`'s way `u` s after leaving its ledge.
	func path_at(b: int, u: float) -> Vector3:
		var top_v := vmax[b]
		var t1 := (top_v-V0)/ACCEL
		var l := 0.0
		if u <= t1: l = V0*u+0.5*ACCEL*u*u
		else: l = (top_v*top_v-V0*V0)/(2.0*ACCEL)+top_v*(u-t1)
		var f0 := first[b]
		var f := l/DS
		var k := clampi(int(f),0,counts[b]-2)
		return pts[f0+k].lerp(pts[f0+k+1],clampf(f-k,0.0,1.0))

	## The flock's middle `tau` s after it burst.
	func middle(tau: float) -> Vector3:
		var s_end := length-16.0
		var adv := maxf(s_end-s_start,1.0)
		var s := s_start+adv*(1.0-exp(-tau*SWEEP/adv))
		var r := LOOP_R*smoothstep(0.0,4.0,tau)
		var th := LOOP_W*tau
		var x := SIDE*smoothstep(1.0,9.0,tau)+r*sin(th)
		s += r*(1.0-cos(th))*0.7
		return Vector3(x,top+OVER+2.0*sin(0.5*tau),-s)

	## The flock's body at `t`: its middle and axes, kept for every bird
	## asking at the same `t`.
	func frame(t: float) -> void:
		if t == _ft: return
		var tau := t-blob0
		_fc = middle(tau)
		var way := middle(tau+0.1)-middle(tau-0.1)
		way.y *= 0.3
		_ff = way.normalized() if way.length() > 0.01 else Vector3.FORWARD
		_fr = _ff.cross(Vector3.UP).normalized()
		_fu = _fr.cross(_ff)
		_ft = t

	## Bird `b`'s place in the flock at `t`: its slot in the body, turned
	## with the flock's way, breathing and rippling.
	func slot(b: int, t: float) -> Vector3:
		frame(t)
		var tau := t-blob0
		var e := slots[b]
		var o := Vector3(e.x*BODY.x,e.y*BODY.y,e.z*BODY.z)*(1.0+0.22*sin(1.1*tau+e.x*3.0))
		var ph := phase[b]*TAU
		o.y += 1.3*sin(0.9*tau+0.35*o.z+e.x)+0.36*sin(2.3*tau+ph*1.3)
		o.x += 1.0*sin(0.7*tau+0.4*o.z)+0.6*sin(1.7*tau+ph)
		o.z += 0.6*cos(1.3*tau+ph)
		return _fc+_fr*o.x+_fu*o.y-_ff*o.z

	## Free flight kept over the piece's stone (and so over `top` while
	## over its footprint).
	func _clear(p: Vector3) -> Vector3:
		if absf(p.x) < x_clear and p.z < 12.0 and p.z > -(length+12.0): p.y = maxf(p.y,top+0.5)
		return p

	## Every bird's place and pose for `t`, into `buf` and `positions`: its
	## heading and bank from its way since the last frame.
	func compute(t: float) -> void:
		var began := Time.get_ticks_usec()
		var sum := Vector3.ZERO
		var n_fly := 0
		var down := 0
		var dt := t-last_t
		var fresh := dt <= 0.0 or dt > 0.25
		if fresh: dt = 1.0/60.0
		var ease := 1.0-exp(-9.0*dt)
		frame(t)
		for b in range(n):
			var t0 := t_start[b]
			if t < t0: continue
			var tr := t_ret[b]
			var d := dur[b]
			if tr < INF and t >= tr+JOIN+d:
				if positions[b] != roost[b] or last_t < tr+JOIN+d: _perch(b)
				down += 1
				continue
			var p := at(b,t)
			var vel: Vector3
			var acc := Vector3.ZERO
			if fresh or last_t < t0:
				vel = (p-at(b,t-dt))/dt
				if last_t >= t0: acc = (vel-last_v[b])/dt
			else:
				vel = (p-last_p[b])/dt
				acc = (vel-last_v[b])/dt
			last_p[b] = p
			last_v[b] = vel
			positions[b] = p
			var speed := vel.length()
			var f := vel/speed if speed > 0.3 else Vector3(-sin(yaw[b]),0.0,-cos(yaw[b]))
			var right := f.cross(Vector3.UP)
			var rl := right.length()
			right = right/rl if rl > 0.05 else Vector3.RIGHT
			var up := right.cross(f)
			var want := clampf(atan2(acc.dot(right),9.8),-1.2,1.2)
			var bk := lerpf(bank[b],want,ease)
			bank[b] = bk
			var basis := Basis(right,up,-f).rotated(f,bk)
			# Off the ledge or onto it: the wings open and fold; beating hard
			# off it and climbing, else beating in bursts and gliding.
			var u := t-t0
			var landing := tr+JOIN+d-t if t >= tr+JOIN else -1.0
			var fold := 1.0-smoothstep(0.0,0.18,u)
			if landing >= 0.0: fold = maxf(fold,1.0-smoothstep(0.0,0.25,landing))
			var ph := phase[b]
			var beat := smoothstep(-0.3,0.5,sin(0.8*t+ph*11.0)+0.5*sin(1.9*t+ph*5.0))
			if u < 1.2 or vel.y > 3.0 or (landing >= 0.0 and landing < 0.8): beat = 1.0
			beat = maxf(beat,clampf(acc.length()/40.0,0.0,1.0))
			basis = basis.scaled(Vector3.ONE*scale[b])
			var o := b*16
			buf[o] = basis.x.x
			buf[o+1] = basis.y.x
			buf[o+2] = basis.z.x
			buf[o+3] = p.x
			buf[o+4] = basis.x.y
			buf[o+5] = basis.y.y
			buf[o+6] = basis.z.y
			buf[o+7] = p.y
			buf[o+8] = basis.x.z
			buf[o+9] = basis.y.z
			buf[o+10] = basis.z.z
			buf[o+11] = p.z
			buf[o+12] = beat
			buf[o+13] = ph
			buf[o+14] = fold
			buf[o+15] = 0.12+0.1*sin(ph*7.0+t)
			sum += p
			n_fly += 1
		last_t = t
		flying = n_fly
		landed = down
		centroid = sum/float(n_fly) if n_fly > 0 else Vector3.ZERO
		took = Time.get_ticks_usec()-began

	## Bird `b` on its ledge, wings folded, facing its way off it.
	func _perch(b: int) -> void:
		var o := b*16
		var p := roost[b]
		var basis := Basis(Vector3.UP,yaw[b]).scaled(Vector3.ONE*scale[b])
		buf[o] = basis.x.x
		buf[o+1] = basis.y.x
		buf[o+2] = basis.z.x
		buf[o+3] = p.x
		buf[o+4] = basis.x.y
		buf[o+5] = basis.y.y
		buf[o+6] = basis.z.y
		buf[o+7] = p.y
		buf[o+8] = basis.x.z
		buf[o+9] = basis.y.z
		buf[o+10] = basis.z.z
		buf[o+11] = p.z
		buf[o+12] = 0.0
		buf[o+13] = phase[b]
		buf[o+14] = 1.0
		buf[o+15] = 0.0
		positions[b] = p
		bank[b] = 0.0

	## Whether any bird is off its ledge now (or about to be).
	func up_now() -> bool:
		return started > landed

## Whether --hall-flock (default on) asks for it.
static func enabled(args: PackedStringArray) -> bool:
	for a: String in args:
		if a.begins_with("--hall-flock="): return int(a.get_slice("=",1)) > 0
	return true

func _init() -> void:
	name = "HallFlock"

func _ready() -> void:
	_rng.seed = 7151
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--hall-flock="): count = maxi(1,int(a.get_slice("=",1)))
		elif a.begins_with("--hall-flock-size="): size = SIZE*maxf(0.2,float(a.get_slice("=",1)))
	bird_mesh()
	bird_material()
	var bus := &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
	_rush = AudioStreamPlayer3D.new()
	_rush.name = "Rush"
	var loop: AudioStream = load(KIT+"flutter-loop.wav")
	if loop is AudioStreamWAV:
		var wav := (loop as AudioStreamWAV).duplicate() as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = roundi(wav.get_length()*wav.mix_rate)
		loop = wav
	_rush.stream = loop
	_rush.bus = bus
	_rush.pitch_scale = 1.35
	_rush.unit_size = 18.0
	_rush.max_distance = 220.0
	_rush.volume_db = -60.0
	add_child(_rush)
	for k in range(8): _call_streams.append(load(KIT+"chirp-%d.wav" % (k+1)))
	for k in range(6): _call_streams.append(load(KIT+"twitter-%d.wav" % (k+1)))
	for k in range(4): _wing_streams.append(load(KIT+"wings-%d.wav" % (k+1)))
	for k in range(6):
		var p := AudioStreamPlayer3D.new()
		p.name = "Call%d" % k
		p.bus = bus
		p.unit_size = 10.0
		p.max_distance = 160.0
		add_child(p)
		_calls.append(p)

func _exit_tree() -> void:
	_finish_work()
	for f: Flock in flocks.values():
		if f.task >= 0: WorkerThreadPool.wait_for_task_completion(f.task)
		f.task = -1

## The swift: a slim spindle of a body, a forked tail and long scythe wings,
## along -Z (its nose), a real swift's size (0.42 m across). Wing points
## carry their reach in UV.x (0 at the shoulder, 1 at the tip) and the
## trailing edge 1 in UV.y.
static func bird_mesh() -> ArrayMesh:
	if _mesh != null: return _mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# The body: a diamond section at three stations, a point at the nose.
	var rings := [[-0.085,0.0,0.0],[-0.045,0.016,0.015],[0.0,0.019,0.017],[0.045,0.011,0.010],[0.07,0.004,0.004]]
	var sections: Array = []
	for r: Array in rings:
		var z: float = r[0]
		var w: float = r[1]
		var hgt: float = r[2]
		sections.append([Vector3(0.0,hgt,z),Vector3(w,0.0,z),Vector3(0.0,-hgt*0.8,z),Vector3(-w,0.0,z)])
	for i in range(sections.size()-1):
		var a: Array = sections[i]
		var b: Array = sections[i+1]
		for k in range(4):
			var k2 := (k+1)%4
			_tri(st,a[k],b[k],b[k2],Vector2.ZERO)
			_tri(st,a[k],b[k2],a[k2],Vector2.ZERO)
	# The forked tail: two thin streamers.
	for side in [-1.0,1.0]:
		_tri(st,Vector3(0.0,0.0,0.045),Vector3(0.026*side,0.0,0.118),Vector3(0.004*side,0.0,0.07),Vector2.ZERO)
	# The wings: long and swept back in a crescent.
	for side in [-1.0,1.0]:
		var sh_f := Vector3(0.017*side,0.004,-0.032)
		var sh_b := Vector3(0.017*side,0.004,0.004)
		var le1 := Vector3(0.07*side,0.003,-0.042)
		var le2 := Vector3(0.14*side,0.0,-0.025)
		var tip := Vector3(0.21*side,0.0,0.05)
		var te2 := Vector3(0.13*side,0.0,0.012)
		var te1 := Vector3(0.065*side,0.002,0.006)
		var reach := func(p: Vector3) -> float: return clampf((absf(p.x)-0.017)/0.193,0.0,1.0)+0.002
		var pts := [sh_f,le1,le2,tip,te2,te1,sh_b]
		var uv := []
		for p: Vector3 in pts: uv.append(Vector2(reach.call(p),1.0 if p in [te2,te1,sh_b] else 0.0))
		var tris := [[0,1,5],[0,5,6],[1,2,4],[1,4,5],[2,3,4]]
		for t: Array in tris:
			for k: int in t:
				st.set_uv(uv[k])
				st.add_vertex(pts[k])
	st.generate_normals()
	_mesh = st.commit()
	return _mesh

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, uv: Vector2) -> void:
	for p: Vector3 in [a,b,c]:
		st.set_uv(uv)
		st.add_vertex(p)

static func bird_material() -> ShaderMaterial:
	if _material != null: return _material
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	return _material

# --- Each frame --------------------------------------------------------------------

## One frame, from the line's `advance`: the flocks kept with the pieces,
## each planned and stood, the birds startled and sent home by where the
## plane is, the last frame's poses handed over and this frame's begun.
func advance(delta: float, plane_at: Variant) -> void:
	var began := Time.get_ticks_usec()
	# The workers' last poses handed over if done; else this frame waits
	# for them (the birds keep last frame's poses).
	var busy := false
	if _task >= 0:
		if WorkerThreadPool.is_group_task_completed(_task): _finish_work()
		else: busy = true
	if line == null: return
	var seen := {}
	var stood := false
	for h: Dictionary in line.halls:
		var index := int(h.index)
		seen[index] = true
		var made: Dictionary = h.made
		if made.is_empty(): continue
		if not flocks.has(index):
			# Planned once the piece stands still, its island and bodies stood:
			# its worker never runs beside the piece's own hand-over frames.
			if h.rise.playing or h.rise.sinking or not line._islands_due.is_empty(): continue
			flocks[index] = _start(index,made)
			continue
		var f: Flock = flocks[index]
		if f.plan.has("dead"): continue
		if f.node == null:
			if f.task >= 0:
				if not WorkerThreadPool.is_task_completed(f.task): continue
				WorkerThreadPool.wait_for_task_completion(f.task)
				f.task = -1
				f.plan = f.out.get("plan",{})
				if f.plan.is_empty() or (f.plan.roost as PackedVector3Array).is_empty():
					f.plan = {"dead":true}
					continue
			if stood: continue
			var root: Variant = made.get("node")
			if root == null or not is_instance_valid(root) or not (root as Node3D).is_inside_tree(): continue
			_stand(f,root as Node3D)
			stood = true
			continue
		f.clock += delta
		# Startled only once the piece stands still (a late one rising under
		# the plane keeps its birds on their ledges).
		var still: bool = not h.rise.playing and not h.rise.sinking
		if not busy and plane_at != null and is_instance_valid(f.node) and (still or f.started > 0): _watch(f,plane_at as Vector3,still)
	for index: int in flocks.keys():
		if not seen.has(index):
			var f: Flock = flocks[index]
			if f.task >= 0: WorkerThreadPool.wait_for_task_completion(f.task)
			flocks.erase(index)
	if not busy:
		_sound(delta)
		# This frame's poses, on the workers (a flock each): handed over the
		# next frame.
		var work: Array = []
		for f: Flock in flocks.values():
			if f.node != null and is_instance_valid(f.node) and f.up_now(): work.append([f,f.clock+delta])
		_working = work
		if not work.is_empty():
			_task = WorkerThreadPool.add_group_task(func(i: int) -> void:
				var item: Array = work[i]
				(item[0] as Flock).compute(float(item[1])),work.size(),-1,false,"Hall flock poses")
	main_usec = Time.get_ticks_usec()-began
	worst_main = maxi(worst_main,main_usec)

## The workers' poses taken (waited for, if they are not done: only when
## the flock goes or a check asks) and handed to each flock's MultiMesh.
func _finish_work() -> void:
	if _task < 0: return
	WorkerThreadPool.wait_for_group_task_completion(_task)
	_task = -1
	work_usec = 0
	for item: Array in _working:
		var f: Flock = item[0]
		work_usec += f.took
		if f.node != null and is_instance_valid(f.node): f.node.multimesh.buffer = f.buf
	worst_work = maxi(worst_work,work_usec)
	_working = []

## Waits for the workers' poses (checks read the birds' places after it).
func settle() -> void:
	_finish_work()

## A piece's flock begun: its plan drawn on a worker.
func _start(index: int, made: Dictionary) -> Flock:
	var f := Flock.new()
	f.index = index
	f.made = made
	f.size = size
	var near: Node3D = (made.node as Node3D).get_node_or_null(^"Near") if made.get("node") != null else null
	var weave: Dictionary = near.get_meta("weave",{}) if near != null else {}
	var gaps: Array = []
	for key: String in ["gaps","open"]:
		for box: AABB in weave.get(key,[]): gaps.append(LineBuild.HALL*box)
	var hp: Dictionary = made.get("hall",{})
	var given := {"boxes":made.boxes,"lo":made.lo,"hi":made.hi,"length":float(hp.get("length",0.0)),"gaps":gaps,"count":count,
		"seed":hash([int(hp.get("seed",index)),"hall flock"])}
	var out := f.out
	f.task = WorkerThreadPool.add_task(func() -> void: out.plan = plan(given),false,"Hall flock plan")
	return f

## A planned flock stood under its piece's node: the birds on their ledges.
func _stand(f: Flock, root: Node3D) -> void:
	var p: Dictionary = f.plan
	f.take(p)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = bird_mesh()
	mm.instance_count = f.n
	mm.buffer = f.buf
	var length: float = p.length
	mm.custom_aabb = AABB(Vector3(-70.0,-5.0,-(length+40.0)),Vector3(140.0,float(p.top)+OVER+30.0,length+80.0))
	var node := MultiMeshInstance3D.new()
	node.name = "HallFlock"
	node.multimesh = mm
	node.material_override = bird_material()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visibility_range_end = FAR
	node.set_meta("skip_reflection",true)
	node.position = -(f.made.pivot as Vector3)
	root.add_child(node)
	f.node = node

## Where the plane is along piece `f`'s nave: the birds it is coming up on
## startled, and once it is well past, all sent home.
func _watch(f: Flock, plane_at: Vector3, still := true) -> void:
	if f.n == 0: return
	var local := f.node.global_transform.affine_inverse()*plane_at
	var length := f.length
	if absf(local.x) > 60.0 or absf(local.y) > 60.0: return
	var s := -local.z
	var trig: PackedFloat32Array = f.plan.trigger
	var near: PackedFloat32Array = f.plan.near
	# A faster plane startles them sooner.
	var early := maxf(0.0,(float(line.plane_speed)-16.0)*2.5) if line != null else 0.0
	while still and f.next < f.n and s+early >= trig[f.next] and not f.home:
		var b := f.next
		# The plane already on it (a piece stood late): it stays put.
		if s > near[b]-MIN_AHEAD:
			f.next += 1
			continue
		if f.blob0 < 0.0:
			f.blob0 = f.clock
			f.s_start = clampf(s+52.0,12.0,maxf(length-18.0,12.0))
		# The stream's are timed to the plane already (plan): no stagger.
		var streams: PackedByteArray = f.plan.stream
		f.t_start[b] = f.clock+(0.0 if streams[b] != 0 else _rng.randf()*STAGGER)
		f.started += 1
		f.next += 1
	if not f.home and f.started > 0 and s > length+HOME_PAST:
		f.home = true
		for b in range(f.n):
			if f.t_start[b] == INF: continue
			f.t_ret[b] = maxf(f.clock+0.5+_rng.randf()*HOME_SPREAD,f.t_start[b]+f.dur[b]+JOIN+0.4)

## The rush of wings and the calls, at the flocks up now.
func _sound(delta: float) -> void:
	var most: Flock = null
	for f: Flock in flocks.values():
		if f.node == null or not is_instance_valid(f.node) or f.flying == 0: continue
		if most == null or f.flying > most.flying: most = f
		if not f.burst_heard and f.flying > 0:
			f.burst_heard = true
			_play(_wing_streams[3],f.node.global_transform*f.centroid,1.0,0.0)
			_play(_wing_streams[2],f.node.global_transform*f.centroid,1.1,-2.0)
	if most == null:
		if _rush.playing:
			_rush.volume_db = move_toward(_rush.volume_db,-60.0,delta*30.0)
			if _rush.volume_db <= -59.0: _rush.stop()
		return
	var at := most.node.global_transform*most.centroid
	_rush.global_position = at
	var share := clampf(float(most.flying)/float(maxi(most.n,1)),0.0,1.0)
	var want := linear_to_db(0.15+0.85*sqrt(share))-2.0
	if not _rush.playing:
		_rush.volume_db = -30.0
		_rush.play()
	_rush.volume_db = move_toward(_rush.volume_db,want,delta*40.0)
	# Screams: more, the more are up.
	_call_clock -= delta*(1.0+7.0*share)
	if _call_clock <= 0.0:
		_call_clock = _rng.randf_range(0.4,1.0)
		var b := _rng.randi()%most.n
		if most.t_start[b] < most.clock:
			_play(_call_streams[_rng.randi()%_call_streams.size()],most.node.global_transform*most.positions[b],_rng.randf_range(1.5,1.95),-4.0)

func _play(stream: AudioStream, at: Vector3, pitch: float, db: float) -> void:
	if stream == null: return
	for p: AudioStreamPlayer3D in _calls:
		if p.playing: continue
		p.stream = stream
		p.pitch_scale = pitch
		p.volume_db = db
		p.global_position = at
		p.play()
		return

## For HUDs and checks: {flocks, birds, flying, plan_ms (the newest's),
## main_us, worst_main_us, work_us, worst_work_us, rush_db (the wings' rush,
## -INF silent), calls (playing now)}.
func status() -> Dictionary:
	var birds := 0
	var fly := 0
	var plan_ms := 0.0
	for f: Flock in flocks.values():
		birds += f.n
		fly += f.flying if f.up_now() else 0
		if f.plan.has("usec"): plan_ms = float(f.plan.usec)/1000.0
	return {"flocks":flocks.size(),"birds":birds,"flying":fly,"plan_ms":plan_ms,"main_us":main_usec,"worst_main_us":worst_main,"work_us":work_usec,"worst_work_us":worst_work,
		"rush_db":snappedf(_rush.volume_db,0.1) if _rush != null and _rush.playing else -INF,"calls":_calls.filter(func(p: AudioStreamPlayer3D) -> bool: return p.playing).size()}

# --- The plan (on a worker) ---------------------------------------------------------

## A piece's flock planned from its hulls' boxes (the piece's frame: the
## nave along -Z from 0, +X its right, the floor at 0): {roost, yaw (each
## bird's ledge, facing), first, count, pts (its way's samples, DS apart),
## high (where its way ends, over `top`), vmax, dur (s along its way),
## trigger (m along the nave the plane startles it at), slot (its place in
## the flock's body, a unit ball), phase, length, top, x_clear, usec, ...}.
## Birds come sorted by trigger.
static func plan(given: Dictionary) -> Dictionary:
	var began := Time.get_ticks_usec()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(given.seed)
	var boxes: Array = given.boxes
	var lo: Vector3 = given.lo
	var hi: Vector3 = given.hi
	var length: float = given.length
	if length <= 0.0 or boxes.is_empty(): return {}
	var top := hi.y+1.8
	var x_clear := maxf(absf(lo.x),absf(hi.x))+1.0
	var g := Grid.new()
	g.setup(Vector3(-(x_clear+3.0),1.0,-(length+8.0)),Vector3(2.0*(x_clear+3.0),top-1.0,length+16.0),CELL)
	g.boxes = boxes
	g.bucket()
	g.fill(PAD)
	var open := g.shut_cells.duplicate()
	# The plane's lane shut, end to end (but for the stream: below).
	var lane_x := Vector2(Hall.LANE.x-LANE_PAD.x,Hall.LANE.y+LANE_PAD.x)
	var lane_top: float = Hall.LANE_Y.y+LANE_PAD.y
	g.shut(AABB(Vector3(lane_x.x,-10.0,-(length+40.0)),Vector3(lane_x.y-lane_x.x,lane_top+10.0,length+80.0)))
	# And over it all the way up where they climb out of the far end (the
	# plane comes under it just after them).
	g.shut(AABB(Vector3(lane_x.x,-10.0,-(length+40.0)),Vector3(lane_x.y-lane_x.x,top+20.0,FAR_END+50.0)))
	var laned := g.shut_cells
	# Two ways out: the nearest (out of the top or the sides: a roof break,
	# an open bay, a side arch), kept out of the plane's lane; and the
	# stream, on down the nave to its far end (up out of the last bays, the
	# torn end's open roof), low under the ties and down the lane itself,
	# ahead of the plane and faster than it (STREAM_SPEED).
	var near_d := g.field(-1)
	g.shut_cells = open
	var far_d := g.field(int((FAR_END+8.0)/CELL)-1,CEILING,PackedInt32Array(),Vector2(Hall.LANE.x-1.0,Hall.LANE.y+1.0))
	# And down into that stream from anywhere.
	var to_far := g.field(-1,INF,far_d)
	g.shut_cells = laned
	var nowhere := AABB(Vector3.ONE*1.0e6,Vector3.ONE)
	var t_fields := Time.get_ticks_usec()-began
	# The ledges.
	var gaps: Array = given.gaps
	var cands: Array = []
	var lane_box := AABB(Vector3(lane_x.x,-10.0,-(length+40.0)),Vector3(lane_x.y-lane_x.x,lane_top+10.0,length+80.0))
	for i in range(boxes.size()):
		var b: AABB = boxes[i]
		var t := b.end.y
		if t < ROOST_LOW or t > top-2.5 or b.size.y > 1.4 or b.size.x < 0.35 or b.size.z < 0.35: continue
		if absf(b.get_center().x) > Hall.WALL_Z+2.0: continue
		var nx := maxi(1,int((b.size.x-0.24)/0.6))
		var nz := maxi(1,int((b.size.z-0.24)/0.6))
		for ix in range(nx):
			for iz in range(nz):
				var p := Vector3(b.position.x+0.12+(b.size.x-0.24)*(ix+0.5)/nx,t+0.035,b.position.z+0.12+(b.size.z-0.24)*(iz+0.5)/nz)
				var near_gap := false
				for gap: AABB in gaps:
					if p.x > gap.position.x-2.5 and p.x < gap.end.x+2.5 and p.z > gap.position.z-2.5 and p.z < gap.end.z+2.5:
						near_gap = true
						break
				var inside := g.hits(AABB(Vector3(p.x-0.1,t+0.8,p.z-0.1),Vector3(0.2,8.0,0.2)))
				if not near_gap and not inside and rng.randf() > 0.05: continue
				if lane_box.has_point(p): continue
				if g.hits(AABB(Vector3(p.x-0.12,t+0.02,p.z-0.12),Vector3(0.24,0.6,0.24))): continue
				var start := -1
				for k in range(1,7):
					var c := g.cell_at(p+Vector3.UP*0.3*k)
					if c >= 0 and near_d[c] >= 0:
						start = c
						break
				if start < 0: continue
				var lift := g.center(start)
				if not g.clear_line(p+Vector3.UP*0.06,lift,0.03): continue
				var w := 1.0 if inside else (0.35 if near_gap else 0.1)
				cands.append([pow(rng.randf(),1.0/w),p,start])
	cands.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var t_cands := Time.get_ticks_usec()-began
	# Up to `count`, at least a bird's room apart, each with a way out.
	var want: int = given.count
	var taken := {}
	var birds: Array = []
	for cand: Array in cands:
		if birds.size() >= want: break
		var p: Vector3 = cand[1]
		var key := Vector3i(floori(p.x/0.34),floori(p.y/0.34),floori(p.z/0.34))
		if taken.has(key): continue
		var start := int(cand[2])
		var way := PackedVector3Array()
		var stream := false
		if -p.z < length-FAR_END-18.0 and to_far[start] >= 0 and rng.randf() < FAR_SHARE:
			g.shut_cells = open
			way = _way(g,p,start,[[to_far,0],[far_d,2]],top,x_clear,nowhere,rng)
			g.shut_cells = laned
			stream = not way.is_empty()
		if way.is_empty(): way = _way(g,p,start,[[near_d,0]],top,x_clear,lane_box,rng)
		if way.is_empty(): continue
		taken[key] = true
		birds.append({"roost":p,"way":way,"stream":stream})
	var t_ways := Time.get_ticks_usec()-began
	# Each bird's numbers, sorted by when the plane startles it.
	# A bird in the plane's lane (the stream) goes once the plane, at
	# PLANE_PACE, would still be GAP short of it wherever it is in the lane;
	# the rest LEAD (a range) short of the nearest it comes.
	var lane_near := lane_box.grow(1.0)
	for bird: Dictionary in birds:
		var way: PackedVector3Array = bird.way
		var speeds: Vector2 = STREAM_SPEED if bool(bird.stream) else SPEED
		bird.vmax = rng.randf_range(speeds.x,speeds.y)
		var s_min := INF
		for q: Vector3 in way:
			if q.y < top: s_min = minf(s_min,-q.z)
		bird.near = s_min
		bird.trigger = s_min-rng.randf_range(LEAD.x,LEAD.y)
		if bool(bird.stream):
			var vmax: float = bird.vmax
			var t1 := (vmax-V0)/ACCEL
			var l1 := (vmax*vmax-V0*V0)/(2.0*ACCEL)
			var go := INF
			for k in range(way.size()):
				var q := way[k]
				if not lane_near.has_point(q): continue
				var l := DS*k
				var t := (sqrt(V0*V0+2.0*ACCEL*l)-V0)/ACCEL if l <= l1 else t1+(l-l1)/vmax
				go = minf(go,-q.z-GAP-PLANE_PACE*t)
			if go < INF:
				bird.near = go+MIN_AHEAD
				bird.trigger = minf(bird.trigger,go-rng.randf()*STREAM_LEAD)
	birds.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.trigger) < float(b.trigger))
	var out := {"roost":PackedVector3Array(),"yaw":PackedFloat32Array(),"first":PackedInt32Array(),"count":PackedInt32Array(),"pts":PackedVector3Array(),
		"high":PackedVector3Array(),"vmax":PackedFloat32Array(),"dur":PackedFloat32Array(),"trigger":PackedFloat32Array(),"near":PackedFloat32Array(),"stream":PackedByteArray(),"slot":PackedVector3Array(),
		"phase":PackedFloat32Array(),"length":length,"top":top,"x_clear":x_clear,"candidates":cands.size(),"cells":g.n,"streams":birds.filter(func(x: Dictionary) -> bool: return bool(x.stream)).size()}
	for bird: Dictionary in birds:
		var way: PackedVector3Array = bird.way
		out.roost.append(bird.roost)
		var off: Vector3 = way[mini(4,way.size()-1)]-way[0]
		out.yaw.append(atan2(-off.x,-off.z) if Vector2(off.x,off.z).length() > 0.05 else rng.randf()*TAU)
		out.first.append(out.pts.size())
		out.count.append(way.size())
		out.pts.append_array(way)
		out.high.append(way[way.size()-1])
		var vmax: float = bird.vmax
		out.vmax.append(vmax)
		var l := DS*(way.size()-1)
		var l1 := (vmax*vmax-V0*V0)/(2.0*ACCEL)
		out.dur.append((sqrt(V0*V0+2.0*ACCEL*l)-V0)/ACCEL if l <= l1 else (vmax-V0)/ACCEL+(l-l1)/vmax)
		out.trigger.append(bird.trigger)
		out.near.append(bird.near)
		out.stream.append(1 if bool(bird.stream) else 0)
		var e := Vector3(rng.randf_range(-1,1),rng.randf_range(-1,1),rng.randf_range(-1,1))
		while e.length() > 1.0: e = Vector3(rng.randf_range(-1,1),rng.randf_range(-1,1),rng.randf_range(-1,1))
		out.slot.append(e)
		out.phase.append(rng.randf())
	out.usec = Time.get_ticks_usec()-began
	out.split = [t_fields,t_cands,t_ways]
	return out

## A bird's way out from its ledge `p` (its first open cell `start`): the
## grid's walk out, pulled straight, smoothed, then climbing over `top`;
## resampled DS apart. Empty if no clear way.
static func _way(g: Grid, p: Vector3, start: int, legs: Array, top: float, x_clear: float, lane: AABB, rng: RandomNumberGenerator) -> PackedVector3Array:
	# Each leg [field, order] walked on from where the last ended.
	var cells := PackedInt32Array()
	var at_cell := start
	for leg: Array in legs:
		var part := g.walk(at_cell,leg[0],int(leg[1]))
		if part.is_empty(): return PackedVector3Array()
		if not cells.is_empty(): part = part.slice(1)
		cells.append_array(part)
		at_cell = cells[cells.size()-1]
	if cells.is_empty(): return PackedVector3Array()
	var raw: Array[Vector3] = []
	for c: int in cells: raw.append(g.center(c))
	# Pulled straight where the grid sees through (a few cells on at most:
	# the weave and the smoothing round it off).
	var pulled: Array[Vector3] = [raw[0]]
	var i := 0
	while i < raw.size()-1:
		var j := mini(raw.size()-1,i+PULL)
		while j > i+1 and not g.sees(raw[i],raw[j]): j -= 1
		pulled.append(raw[j])
		i = j
	var straight := pulled
	pulled = _weave(g,pulled,rng)
	# Out of the grid: up from its top, or out past the island and up.
	var last := pulled[pulled.size()-1]
	var tail: Array[Vector3] = []
	var lc := g.coords(cells[cells.size()-1])
	if lc.y == g.size.y-1:
		tail.append(Vector3(last.x,top+1.5,last.z))
	elif lc.x == 0 or lc.x == g.size.x-1:
		var side := signf(last.x)
		tail.append(Vector3(side*(x_clear+4.0),last.y,last.z))
		tail.append(Vector3(side*(x_clear+4.0),top+1.5,last.z))
	else:
		return PackedVector3Array()
	var at := last
	for q: Vector3 in tail:
		if not g.clear_line(at,q,0.3): return PackedVector3Array()
		at = q
	var pts: Array[Vector3] = [p+Vector3.UP*0.06]
	pts.append_array(pulled)
	pts.append_array(tail)
	# Smoothed (Catmull-Rom through the corners), checked against the boxes;
	# else the corners as they are.
	var smooth := _resample(_spline(pts),DS)
	var ok := true
	for k in range(2,smooth.size()):
		var q := smooth[k]
		if lane.has_point(q) or g.near_stone(q,0.2):
			ok = false
			break
	if ok: return smooth
	# Woven too close: the straight way, smoothed if it clears.
	pts = [p+Vector3.UP*0.06]
	pts.append_array(straight)
	pts.append_array(tail)
	smooth = _resample(_spline(pts),DS)
	ok = true
	for k in range(2,smooth.size()):
		var q := smooth[k]
		if lane.has_point(q) or g.near_stone(q,0.2):
			ok = false
			break
	if ok: return smooth
	return _resample(pts,DS)

## A way woven from side to side (and a little up and down) where the grid
## has room: every WEAVE_STEP m along it a point thrown WEAVE m (a range)
## the other way across, kept if the grid sees it from the last and to the
## next. The first two points (off the ledge) stay.
static func _weave(g: Grid, pts: Array[Vector3], rng: RandomNumberGenerator) -> Array[Vector3]:
	var fine: Array[Vector3] = [pts[0]]
	for i in range(1,pts.size()):
		var a := pts[i-1]
		var b := pts[i]
		var k := maxi(1,int(a.distance_to(b)/WEAVE_STEP))
		for j in range(1,k+1): fine.append(a.lerp(b,float(j)/k))
	if fine.size() < 4: return pts
	var out: Array[Vector3] = [fine[0],fine[1]]
	var side := 1.0 if rng.randf() < 0.5 else -1.0
	for i in range(2,fine.size()-1):
		var p := fine[i]
		var placed := p
		var amp := rng.randf_range(WEAVE.x,WEAVE.y)
		for t in range(3):
			var q := p+Vector3(side*amp,rng.randf_range(-0.8,0.8),0.0)
			var c := g.cell_at(q)
			if c >= 0 and g.shut_cells[c] == 0 and g.sees(out[out.size()-1],q) and g.sees(q,fine[i+1]):
				placed = q
				break
			amp *= 0.55
		out.append(placed)
		side = -side
	out.append(fine[fine.size()-1])
	return out

## Catmull-Rom through `pts`, 6 samples a span.
static func _spline(pts: Array[Vector3]) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var n := pts.size()
	for i in range(n-1):
		var p0 := pts[maxi(i-1,0)]
		var p1 := pts[i]
		var p2 := pts[i+1]
		var p3 := pts[mini(i+2,n-1)]
		var steps := maxi(2,int(p1.distance_to(p2)/0.5))
		for k in range(steps):
			var t := float(k)/steps
			out.append(p1.cubic_interpolate(p2,p0,p3,t))
	out.append(pts[n-1])
	return out

## A polyline resampled every `step` m along it.
static func _resample(pts: Array[Vector3], step: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	if pts.is_empty(): return out
	out.append(pts[0])
	var carry := 0.0
	for i in range(pts.size()-1):
		var a := pts[i]
		var b := pts[i+1]
		var d := a.distance_to(b)
		var s := step-carry
		while s <= d:
			out.append(a.lerp(b,s/d))
			s += step
		carry = d-(s-step)
	if out[out.size()-1].distance_to(pts[pts.size()-1]) > 0.01: out.append(pts[pts.size()-1])
	return out

## The plan's grid over a piece: shut cells (the boxes grown, the lane),
## each open cell's steps out (-1 none), the boxes in columns to ask.
class Grid extends RefCounted:
	var origin := Vector3.ZERO
	var size := Vector3i.ZERO
	var cell := 1.0
	var n := 0
	var shut_cells := PackedByteArray()
	var boxes: Array = []
	var columns: Array = []
	var col_size := 3.0
	var col_n := Vector2i.ZERO

	func setup(at: Vector3, extent: Vector3, c: float) -> void:
		origin = at
		cell = c
		size = Vector3i(ceili(extent.x/c),ceili(extent.y/c),ceili(extent.z/c))
		n = size.x*size.y*size.z
		shut_cells.resize(n)
		shut_cells.fill(0)

	func coords(i: int) -> Vector3i:
		return Vector3i(i%size.x,(i/size.x)%size.y,i/(size.x*size.y))

	func index(c: Vector3i) -> int:
		return c.x+size.x*(c.y+size.y*c.z)

	func center(i: int) -> Vector3:
		var c := coords(i)
		return origin+(Vector3(c)+Vector3.ONE*0.5)*cell

	## The cell holding `p`, -1 outside.
	func cell_at(p: Vector3) -> int:
		var q := (p-origin)/cell
		var c := Vector3i(floori(q.x),floori(q.y),floori(q.z))
		if c.x < 0 or c.y < 0 or c.z < 0 or c.x >= size.x or c.y >= size.y or c.z >= size.z: return -1
		return index(c)

	## The boxes sorted into columns (x, z) of col_size.
	func bucket() -> void:
		col_n = Vector2i(ceili(size.x*cell/col_size),ceili(size.z*cell/col_size))
		columns = []
		columns.resize(col_n.x*col_n.y)
		for k in range(columns.size()): columns[k] = PackedInt32Array()
		for i in range(boxes.size()):
			var b: AABB = boxes[i]
			var a := _col(b.position)
			var e := _col(b.end)
			if e.x < 0 or e.y < 0 or a.x >= col_n.x or a.y >= col_n.y: continue
			for cx in range(maxi(a.x,0),mini(e.x,col_n.x-1)+1):
				for cz in range(maxi(a.y,0),mini(e.y,col_n.y-1)+1):
					var list: PackedInt32Array = columns[cx+col_n.x*cz]
					list.append(i)
					columns[cx+col_n.x*cz] = list

	func _col(p: Vector3) -> Vector2i:
		return Vector2i(floori((p.x-origin.x)/col_size),floori((p.z-origin.z)/col_size))

	## Whether any box meets `q`.
	func hits(q: AABB) -> bool:
		var a := _col(q.position)
		var e := _col(q.end)
		for cx in range(maxi(a.x,0),mini(e.x,col_n.x-1)+1):
			for cz in range(maxi(a.y,0),mini(e.y,col_n.y-1)+1):
				for k: int in columns[cx+col_n.x*cz]:
					if (boxes[k] as AABB).intersects(q): return true
		return false

	## Whether `p` is within `grow` of any box.
	func inside(p: Vector3, grow: float) -> bool:
		return hits(AABB(p-Vector3.ONE*grow,Vector3.ONE*grow*2.0))

	## Whether `p` is within `grow` (under PAD) of any box: no, in an open
	## cell (every box is PAD off it); else asked of the boxes.
	func near_stone(p: Vector3, grow: float) -> bool:
		var c := cell_at(p)
		if c >= 0 and shut_cells[c] == 0: return false
		return inside(p,grow)

	## Whether the line from `a` to `b` keeps `grow` off every box.
	func clear_line(a: Vector3, b: Vector3, grow: float) -> bool:
		var d := a.distance_to(b)
		var steps := maxi(1,ceili(d/0.15))
		for k in range(steps+1):
			if near_stone(a.lerp(b,float(k)/steps),grow): return false
		return true

	## Every cell a box (grown by `pad`) meets, shut.
	func fill(pad: float) -> void:
		for b: AABB in boxes:
			shut(b.grow(pad))

	func shut(a: AABB) -> void:
		var lo := (a.position-origin)/cell
		var hi := (a.end-origin)/cell
		var x0 := maxi(floori(lo.x),0)
		var y0 := maxi(floori(lo.y),0)
		var z0 := maxi(floori(lo.z),0)
		var x1 := mini(floori(hi.x),size.x-1)
		var y1 := mini(floori(hi.y),size.y-1)
		var z1 := mini(floori(hi.z),size.z-1)
		if x0 > x1 or y0 > y1 or z0 > z1: return
		for z in range(z0,z1+1):
			for y in range(y0,y1+1):
				var row := size.x*(y+size.y*z)
				for x in range(x0,x1+1): shut_cells[row+x] = 1

	## Each open cell's steps out (-1 none): a walk from the open cells of
	## the top and the sides, or (`far` >= 0) only of the top's last `far`
	## rows (the far end's), or (`to` given) from every cell `to` reaches.
	func field(far: int, ceiling := INF, to := PackedInt32Array(), band := Vector2(-INF,INF)) -> PackedInt32Array:
		var dist := PackedInt32Array()
		dist.resize(n)
		dist.fill(-1)
		var queue := PackedInt32Array()
		queue.resize(n)
		var tail := 0
		for z in range(size.z):
			for y in range(size.y):
				for x in range(size.x):
					var i := x+size.x*(y+size.y*z)
					var goal := y == size.y-1 and (far < 0 or z <= far)
					if far < 0: goal = goal or x == 0 or x == size.x-1
					if not to.is_empty(): goal = to[i] >= 0
					if not goal: continue
					if shut_cells[i] != 0: continue
					dist[i] = 0
					queue[tail] = i
					tail += 1
		# Short of the far end, kept under ceiling (shut over it).
		var shut := shut_cells
		if far >= 0 and ceiling < INF and to.is_empty():
			shut = shut_cells.duplicate()
			var y0 := maxi(0,ceili((ceiling-origin.y)/cell-0.5))
			for z in range(far+1,size.z):
				for y in range(size.y):
					var row := size.x*(y+size.y*z)
					for x in range(size.x):
						var cx := origin.x+(x+0.5)*cell
						if y >= y0 or cx < band.x or cx > band.y: shut[row+x] = 1
		var head := 0
		var sx := size.x
		var sxy := size.x*size.y
		while head < tail:
			var i := queue[head]
			head += 1
			var d := dist[i]+1
			var x := i%sx
			var y := (i/sx)%size.y
			var z := i/sxy
			if x > 0 and dist[i-1] < 0 and shut[i-1] == 0:
				dist[i-1] = d
				queue[tail] = i-1
				tail += 1
			if x < sx-1 and dist[i+1] < 0 and shut[i+1] == 0:
				dist[i+1] = d
				queue[tail] = i+1
				tail += 1
			if y > 0 and dist[i-sx] < 0 and shut[i-sx] == 0:
				dist[i-sx] = d
				queue[tail] = i-sx
				tail += 1
			if y < size.y-1 and dist[i+sx] < 0 and shut[i+sx] == 0:
				dist[i+sx] = d
				queue[tail] = i+sx
				tail += 1
			if z > 0 and dist[i-sxy] < 0 and shut[i-sxy] == 0:
				dist[i-sxy] = d
				queue[tail] = i-sxy
				tail += 1
			if z < size.z-1 and dist[i+sxy] < 0 and shut[i+sxy] == 0:
				dist[i+sxy] = d
				queue[tail] = i+sxy
				tail += 1
		return dist

	## The cells from `start` out, each a step nearer: `order` 0 up first,
	## then on along the nave, then across; 1 down first, then on; 2 on
	## first, then across, up, down.
	func walk(start: int, dist: PackedInt32Array, order := 0) -> PackedInt32Array:
		var out := PackedInt32Array()
		var i := start
		if dist[i] < 0: return out
		out.append(i)
		var sx := size.x
		var sxy := size.x*size.y
		var guard := 0
		# The six steps (0 up, 1 on, 2 left, 3 right, 4 back, 5 down) in order.
		var seq: PackedInt32Array = [0,1,2,3,4,5] if order == 0 else ([5,1,2,3,0,4] if order == 1 else [1,2,3,0,5,4])
		while dist[i] > 0 and guard < 600:
			guard += 1
			var x := i%sx
			var y := (i/sx)%size.y
			var z := i/sxy
			var here := dist[i]
			var best := -1
			for k in range(6):
				var j := -1
				match seq[k]:
					0: j = i+sx if y < size.y-1 else -1
					1: j = i-sxy if z > 0 else -1
					2: j = i-1 if x > 0 else -1
					3: j = i+1 if x < sx-1 else -1
					4: j = i+sxy if z < size.z-1 else -1
					5: j = i-sx if y > 0 else -1
				if j >= 0 and dist[j] >= 0 and dist[j] < here:
					best = j
					break
			if best < 0: return PackedInt32Array()
			i = best
			out.append(i)
		return out

	## Whether the grid sees from `a` to `b` (every point between in an
	## open cell).
	func sees(a: Vector3, b: Vector3) -> bool:
		var d := a.distance_to(b)
		var steps := maxi(1,ceili(d/0.5))
		for k in range(steps+1):
			var c := cell_at(a.lerp(b,float(k)/steps))
			if c < 0 or shut_cells[c] != 0: return false
		return true
