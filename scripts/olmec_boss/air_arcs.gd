extends Node3D
## The Olmec's air slices (spec "The tilt", the slide; the user's playtests
## of (9) and (11)): braced on the rim of the tipped field he sends slashes
## of wind across its slope at the wanderer, each a thin upright crescent
## travelling edge-first (horns down on the turf front and back along its
## run, its crown SLICE_H m up; the blade turns with its path), so from
## the wanderer each reads as a sharp upright line. They don't just
## advance: each runs a curving path (a bow off the straight line to him,
## swept wide and hooking in), from his feet, either side of him or the
## field's flanks, and each speeds up as it comes (V0 m/s at launch,
## ACCEL m/s/s, up to V_MAX). Each is aimed at where the wanderer will be
## when it gets there (his slide and drift led), and keeps that aim in
## flight (its curve bent at most K_RATE 1/m a second) till it is AIM_UNTIL
## s from him; then it runs on its curve, which eases out after it passes.
## A volley is two to four of them arriving one after another, so a step
## and a hold is met by the next one: he has to keep weaving. Fair: each
## rises out of the turf in place for TELL s before it goes, its path
## drawn on the turf ahead of it (a pale line, TRACE_M m), on the heave of
## his weight. Each volley is one pattern, never the same twice in a row:
##   "scythes":  two from either side of his feet, bowed wide, hooking in;
##   "crossing": two from the field's flanks, sweeping across the slope
##               and crossing where he is;
##   "chase":    three from his feet, bowed one way, then the other;
##   "sweeper":  one from a flank sweeping across, one fast from his feet,
##               one from the other flank;
##   "spiral":   four from about his feet, bowed alternately, in quick
##               succession.
## Slices run in the field's rest frame (the study's `tipped` turns them to
## the world) and fade off the field. One that meets him knocks him back up
## the slope and a little in toward the field's middle (never off its
## lip), once a volley.
##   volley(from, at, n): a pattern from `from` (his feet, rest frame) at
##     `at` (the wanderer, rest frame); `n` is unused (kept for the call).
##   can_send(): whether the last pattern has had its time.
## The study (studies/olmec_field.gd) owns it; `motor` the wanderer's.
## (The file keeps its old name from the crescent "air arcs".)

const Dust = preload("res://scripts/breaks/body_dust.gd")

## A slice: its chord along its run (m), its crown's height (m), its
## thickness at the crown (m, across). Its pace: V0 m/s as it goes, ACCEL
## m/s/s on, up to V_MAX (the slide tops at 9.4, set in (10)). TELL: the
## time it rises in place before it goes (s).
const SLICE_L := 3.4
const SLICE_H := 2.6
const SLICE_W := 0.34
const V0 := 4.5
const ACCEL := 8.0
const V_MAX := 17.0
const TELL := 0.4
## Its curve: at most K_MAX 1/m, re-bent at most K_RATE 1/m a second while
## it aims, till AIM_UNTIL s off him. LEAD: the most it leads him (m).
const K_MAX := 0.12
const K_RATE := 0.15
const AIM_UNTIL := 0.9
const LEAD := 40.0
const SLIDE_TOP := 10.3
## Its path drawn on the turf ahead of it (m).
const TRACE_M := 16.0
## How far a slice runs before it fades (m), and the fade (s).
const ARC_RUN := 110.0
const ARC_FADE := 0.35
## His body's half width (m) for a hit, the knock (m out, m up) and the
## share of it in toward the field's middle line.
const BODY := 0.3
const KNOCK_OUT := 3.0
const KNOCK_UP := 1.4
const KNOCK_IN := 0.3
## The field's disc in the rest frame (m about the middle): slices are
## drawn and hit only inside it.
const DISC := 39.5
## The patterns, and the quiet after one has come (s).
const PATTERNS := ["scythes","crossing","chase","sweeper","spiral"]
const REST := 1.0

var study: Node = null
var motor: RefCounted = null
## The live slices: [{node, trace, q (rest centre), way (rest flat run),
## k (its curve, 1/m, + bends toward +90 deg), speed, run, t, delay, wave,
## fade, puff, pattern, seen, hit, aim, arrive}]. One with delay > 0
## hasn't shown yet; one with t < TELL is rising in place.
var arcs: Array = []
## Counts, for checks: slices fired, hits, volleys and their patterns.
var fired := 0
var hits := 0
var last_hit := Vector3.ZERO
var patterns: Array[String] = []
var last_pattern := ""
## Patterns to send next, in order, before the random ones (a tuning knob
## and for checks).
var queue: Array[String] = []
var _hit_waves := {}
var _wave := 0
var _clock := 0.0
var _rest_until := 0.0
var _rng := RandomNumberGenerator.new()
var _mesh: ArrayMesh = null
var _trace_mat: StandardMaterial3D = null
## His velocity a step ago and his acceleration (rest frame, flat,
## smoothed): his slide speeds up down the slope, so the lead counts it.
var _vel_was := Vector2.ZERO
var _acc := Vector2.ZERO

func _init() -> void:
	name = "AirArcs"
	_rng.seed = 911

func can_send() -> bool:
	return _clock >= _rest_until

## Travel time over `l` m from speed `v` (accelerating to V_MAX).
static func travel(l: float, v := V0) -> float:
	v = minf(v,V_MAX)
	var t1 := (V_MAX-v)/ACCEL
	var d1 := v*t1+0.5*ACCEL*t1*t1
	if l <= d1: return (-v+sqrt(v*v+2.0*ACCEL*l))/ACCEL
	return t1+(l-d1)/V_MAX

## The arc from `p` heading `way` through `to`: [curve 1/m, length m].
static func arc_to(p: Vector2, way: Vector2, to: Vector2) -> Vector2:
	var c := to-p
	var d := c.length()
	if d < 0.01: return Vector2(0.0,0.0)
	var al := way.angle_to(c)
	var k := 2.0*sin(al)/d
	var l := d if absf(al) < 0.001 else d*al/sin(al)
	return Vector2(k,l)

## The wanderer (rest frame, flat) and his velocity there.
func _him() -> Array:
	if motor == null or study == null or study.get("tilt") == null: return [Vector2.ZERO,Vector2.ZERO]
	var turn: Transform3D = study.tilt.steep_turn()
	var me: Vector3 = turn.affine_inverse()*motor.feet
	var v3: Vector3 = turn.basis.inverse()*motor.velocity
	return [Vector2(me.x,me.z),Vector2(v3.x,v3.z)]

## Where he'll be in `t` s: his slide and drift led, speeding up as he
## is (his acceleration) but no faster than SLIDE_TOP, on the field.
func _lead(me: Vector2, vel: Vector2, t: float) -> Vector2:
	var top := SLIDE_TOP
	if study != null and study.get("TILT_SLIDE_TOP") != null: top = float(study.TILT_SLIDE_TOP)*1.1
	var tc := t
	var end := vel+_acc*t
	if end.length() > top and _acc.length() > 0.1:
		tc = clampf((top-vel.length())/_acc.length(),0.0,t)
	var p := me+vel*tc+_acc*0.5*tc*tc
	if tc < t:
		var v := vel+_acc*tc
		p += v.normalized()*minf(v.length(),top)*(t-tc)
	return (me+(p-me).limit_length(LEAD)).limit_length(DISC-3.0)

## When a slice from `s` heading off the line by `bow` meets him (s
## after its tell starts, its share `fast` of the pace), and where.
func _meet_at(s: Vector2, bow: float, toward: Vector2, me: Vector2, vel: Vector2, fast := 1.0, v := 0.0) -> Array:
	var t := 2.0
	var aim := me
	var way := Vector2.ZERO
	for it in range(6):
		aim = _lead(me,vel,t)
		var chord := (aim-s).normalized()
		var sg := 1.0 if chord.rotated(bow).dot(toward) >= chord.rotated(-bow).dot(toward) else -1.0
		way = chord.rotated(bow*sg)
		var l := arc_to(s,way,aim).y
		t = TELL+travel(l,V0 if v <= 0.0 else v)/fast
	return [t,aim,way]

## Whether the arc from `s` heading `way` with curve `k` stays on the field
## for `l` m.
func _on_field(s: Vector2, way: Vector2, k: float, l: float) -> bool:
	var p := s
	var w := way
	var d := 0.0
	while d < l:
		p += w
		w = w.rotated(k)
		d += 1.0
		if p.length() > DISC-1.5: return false
	return true

## A pattern from `from` toward `at` (both rest frame, flat).
func volley(from: Vector3, at: Vector3, _n := 3, pattern := "") -> void:
	var to := Vector2(at.x-from.x,at.z-from.z)
	if to.length() < 1.0: return
	if pattern == "" and not queue.is_empty(): pattern = queue.pop_front()
	if pattern == "":
		var pick: Array = PATTERNS.duplicate()
		pick.erase(last_pattern)
		pattern = pick[_rng.randi() % pick.size()]
	last_pattern = pattern
	patterns.append(pattern)
	var dist := to.length()
	var fwd := to/dist
	var side := Vector2(-fwd.y,fwd.x)
	var o := Vector2(from.x,from.z)+fwd*2.0
	var me := Vector2(at.x,at.z)
	var vel: Vector2 = _him()[1]
	var g := 1.0 if _rng.randf() < 0.5 else -1.0
	# The field's flanks: either side of him, partway down toward his feet.
	var flank := func(s: float) -> Vector2: return (me-fwd*minf(12.0,dist*0.4)+side*s*18.0).limit_length(DISC-2.5)
	# Each: [start, bow (rad off the straight line), toward (the side it
	# bows to), arrival after the first (s), speed share].
	var plan: Array = []
	match pattern:
		"scythes":
			plan.append([o+side*g*9.0,0.8,side*g,0.0,1.0])
			plan.append([o-side*g*9.0,0.8,-side*g,0.75,1.0])
		"crossing":
			plan.append([flank.call(g),0.5,-fwd,0.0,1.0])
			plan.append([flank.call(-g),0.5,fwd,0.45,1.0])
		"chase":
			plan.append([o,0.6,side*g,0.0,1.0])
			plan.append([o,0.6,-side*g,0.7,1.0])
			plan.append([o,0.35,side*g,1.4,1.0])
		"sweeper":
			plan.append([flank.call(g),0.7,-fwd,0.0,1.0])
			plan.append([o,0.25,-side*g,0.6,1.15])
			plan.append([flank.call(-g),0.6,-fwd,1.25,1.0])
		"spiral":
			for k in range(4):
				var sg := g*(1.0 if k % 2 == 0 else -1.0)
				plan.append([o+side*sg*4.0,[1.0,0.7,0.45,0.25][k],side*sg,0.5*float(k),1.0])
	# The first arrives as soon as the slowest can; each its own share
	# later. Each meets him where he'll be then (fixed-point on the time).
	var base := 0.0
	for e: Array in plan:
		var s: Vector2 = (e[0] as Vector2).limit_length(DISC-2.5)
		var m: Array = _meet_at(s,float(e[1]),e[2],me,vel,float(e[4]))
		base = maxf(base,float(m[0])-float(e[3]))
	var last := 0.0
	for e: Array in plan:
		var s: Vector2 = (e[0] as Vector2).limit_length(DISC-2.5)
		var bow := float(e[1])*_rng.randf_range(0.85,1.15)
		var arrive := base+float(e[3])*_rng.randf_range(0.9,1.1)
		var m: Array = _meet_at(s,bow,e[2],me,vel,float(e[4]))
		# Its own meeting would come at m[0]; held back to `arrive`, it
		# meets him further on: aim there.
		var aim := _lead(me,vel,arrive)
		var chord := (aim-s).normalized()
		var way: Vector2 = chord.rotated(chord.angle_to(m[2]) if absf(chord.angle_to(m[2])) <= bow+0.01 else bow*signf(chord.angle_to(m[2])))
		var kl := arc_to(s,way,aim)
		# Keep it on the field: bowed the other way, or less, if it'd leave.
		for tries in range(3):
			if _on_field(s,way,kl.x,kl.y): break
			var a0 := chord.angle_to(way)
			way = chord.rotated(-a0 if tries == 0 else a0*0.5)
			kl = arc_to(s,way,aim)
		var delay := maxf(arrive-TELL-travel(kl.y)/float(e[4]),0.0)
		_slice(s,way,clampf(kl.x,-K_MAX,K_MAX),float(e[4]),from.y,delay,pattern)
		arcs.back()["arrive"] = _clock+arrive
		last = maxf(last,arrive)
	_wave += 1
	# Quiet till it has come to him (and a breath), so patterns don't pile up.
	_rest_until = _clock+last+REST
	print("air arcs: volley %d, %s, %.0f m off, %d slices" % [patterns.size(),pattern,dist,plan.size()])
	_place_all()

func _slice(c: Vector2, way: Vector2, k: float, fast: float, y: float, delay: float, pattern: String) -> void:
	var node := MeshInstance3D.new()
	node.mesh = _slice_mesh()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visible = false
	add_child(node)
	var trace := MeshInstance3D.new()
	trace.mesh = ImmediateMesh.new()
	trace.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trace.visible = false
	add_child(trace)
	arcs.append({"node":node,"trace":trace,"q":Vector3(c.x,y,c.y),"way":way.normalized(),"k":k,"fast":fast,
		"speed":0.0,"run":0.0,"t":0.0,"delay":delay,"wave":_wave,"fade":-1.0,"puff":0.0,"pattern":pattern,
		"seen":false,"hit":false,"aim":true,"past":false,"seed":_rng.randf()*50.0})
	fired += 1

## Every slice along its path; a meeting with him, a knock; done ones gone.
func step(delta: float) -> void:
	if delta <= 0.0: return
	_clock += delta
	var v_now: Vector2 = _him()[1]
	var acc := ((v_now-_vel_was)/delta).limit_length(20.0)
	_acc = _acc.lerp(acc,clampf(delta*6.0,0.0,1.0))
	_vel_was = v_now
	var keep: Array = []
	for a: Dictionary in arcs:
		if not is_instance_valid(a.node): continue
		var node: MeshInstance3D = a.node
		if float(a.delay) > 0.0:
			a.delay = float(a.delay)-delta
			keep.append(a)
			continue
		if float(a.t) == 0.0 and study != null:
			# It cuts up out of the turf: the tell.
			Dust.puff(study.get("enemies"),study.tipped(_on_turf(a.q)),1.1,Vector3.UP)
		a.t = float(a.t)+delta
		if float(a.fade) >= 0.0:
			a.fade = float(a.fade)+delta
			if float(a.fade) >= ARC_FADE:
				_free(a)
				continue
		if float(a.t) < TELL:
			keep.append(a)
			continue
		var cap := V_MAX*float(a.fast)
		a.speed = minf(maxf(float(a.speed),V0*float(a.fast))+ACCEL*float(a.fast)*delta,cap)
		_steer(a,delta)
		var ds := float(a.speed)*delta
		var way: Vector2 = (a.way as Vector2).rotated(float(a.k)*ds*0.5)
		var q: Vector3 = (a.q as Vector3)+Vector3(way.x,0.0,way.y)*ds
		a.way = way.rotated(float(a.k)*ds*0.5)
		a.q = q
		a.run = float(a.run)+ds
		var inside := _inside(q)
		if inside: a.seen = true
		elif bool(a.seen) and float(a.fade) < 0.0: a.fade = 0.0
		if float(a.run) > ARC_RUN and float(a.fade) < 0.0: a.fade = 0.0
		if inside and float(a.fade) < 0.0 and not _hit_waves.has(int(a.wave)): _meet(a,q)
		a.puff = float(a.puff)-delta
		if float(a.puff) <= 0.0 and study != null and float(a.fade) < 0.0 and inside:
			# The slice scours the turf: dust off its trailing horn.
			a.puff = 0.09
			var foot: Vector3 = study.tipped(_on_turf(q-Vector3(way.x,0.0,way.y)*SLICE_L*0.45))
			Dust.puff(study.get("enemies"),foot,0.7,Vector3.UP)
		keep.append(a)
	arcs = keep
	_place_all()

## Its aim kept on where he'll be when it gets there, its curve bent at
## most K_RATE 1/m a second, till it is AIM_UNTIL s off (or past him);
## then it runs its curve, which eases straight after it passes.
func _steer(a: Dictionary, delta: float) -> void:
	var k := float(a.k)
	if motor == null or study == null: return
	var h: Array = _him()
	var me: Vector2 = h[0]
	var p := Vector2((a.q as Vector3).x,(a.q as Vector3).z)
	var way: Vector2 = a.way
	if bool(a.get("past",false)) or (me-p).dot(way) < -SLICE_L:
		# Past him: its curve eases out, so it sweeps on off the field.
		a.past = true
		a.aim = false
		a.k = move_toward(k,0.0,K_RATE*2.0*delta)
		return
	if not bool(a.aim): return
	var v := float(a.speed)/float(a.fast)
	var left := travel(arc_to(p,way,me).y,v)/float(a.fast)
	var aim := me
	for it in range(4):
		aim = _lead(me,h[1],left)
		left = travel(arc_to(p,way,aim).y,v)/float(a.fast)
	var c := aim-p
	if left < AIM_UNTIL or c.dot(way) <= 0.0 or absf(way.angle_to(c)) > 1.6:
		a.aim = false
		return
	var want := clampf(arc_to(p,way,aim).x,-K_MAX,K_MAX)
	a.k = move_toward(k,want,K_RATE*delta)

## All gone at once (R, the tilt over).
func clear() -> void:
	for a: Dictionary in arcs: _free(a)
	arcs.clear()
	_hit_waves.clear()

## Fade the live ones out (the brace broken); the ones not gone yet never go.
func fade_all() -> void:
	var keep: Array = []
	for a: Dictionary in arcs:
		if float(a.delay) > 0.0:
			_free(a)
			continue
		if float(a.fade) < 0.0: a.fade = 0.0
		keep.append(a)
	arcs = keep

func _free(a: Dictionary) -> void:
	for key in ["node","trace"]:
		if is_instance_valid(a.get(key)): (a[key] as Node).queue_free()

func _on_turf(q: Vector3) -> Vector3:
	var y: float = study.call("_ground_y",q.x,q.z) if study != null else q.y
	return Vector3(q.x,y,q.z)

func _inside(q: Vector3) -> bool:
	return Vector2(q.x,q.z).length() < DISC

## His feet (rest frame) within the slice's chord along its run and its
## thickness (plus his body) across, under its crown: knocked.
func _meet(a: Dictionary, q: Vector3) -> void:
	if motor == null or study == null: return
	if motor.seized(): return
	var turn: Transform3D = study.tilt.steep_turn()
	var p: Vector3 = turn.affine_inverse()*motor.feet
	var way: Vector2 = a.way
	var rel := Vector2(p.x-q.x,p.z-q.z)
	if absf(rel.dot(way)) > SLICE_L*0.5: return
	var across := rel.dot(Vector2(-way.y,way.x))
	if absf(across) > SLICE_W*0.5+BODY: return
	var over := p.y-float(study.call("_ground_y",p.x,p.z))
	if over > SLICE_H or over < -1.0: return
	_hit_waves[int(a.wave)] = true
	a.hit = true
	hits += 1
	last_hit = motor.feet
	# Back up its run (up the slope) and a little in toward the field's
	# middle line, so it never throws him off a side.
	var sideways := Vector2(-way.y,way.x)
	var inward := -Vector2(p.x,p.z).dot(sideways)*sideways
	inward = inward.normalized() if inward.length() > 0.1 else Vector2.ZERO
	var flat_rest := (way+inward*KNOCK_IN).normalized()
	var w3: Vector3 = turn.basis*Vector3(flat_rest.x,0.0,flat_rest.y)
	var away := Vector2(w3.x,w3.z).normalized()
	motor.knock(motor.knock_velocity(away,KNOCK_OUT,KNOCK_UP),self)
	Dust.puff(study.get("enemies"),motor.feet,1.4,Vector3.UP)
	print("air arcs: %s hit him at (%.1f, %.1f), across %.2f" % [a.pattern,p.x,p.z,across])

func _place_all() -> void:
	if study == null: return
	var turn: Transform3D = study.tilt.steep_turn()
	for a: Dictionary in arcs:
		if not is_instance_valid(a.node): continue
		var node: MeshInstance3D = a.node
		var q: Vector3 = a.q
		_trace(a,turn)
		if float(a.delay) > 0.0 or not _inside(q):
			node.visible = false
			continue
		node.visible = true
		var way: Vector2 = a.way
		# Edge-first: the mesh's +z along its run, its plane upright.
		var b := Basis.looking_at(-Vector3(way.x,0.0,way.y),Vector3.UP)
		# It cuts up out of the turf in its tell, and sinks back as it fades.
		var grow := clampf(float(a.t)/TELL,0.1,1.0)
		var fade := 1.0-clampf(float(a.fade)/ARC_FADE,0.0,1.0) if float(a.fade) >= 0.0 else 1.0
		var flick := 1.0+0.05*sin(float(a.t)*29.0+float(a.seed))
		b = b.scaled(Vector3(flick,grow*maxf(fade,0.05)*flick,1.0))
		node.global_transform = turn*Transform3D(b,_on_turf(q)-Vector3.UP*0.1)
		node.transparency = (1.0-fade)*0.9

## Its path on the turf ahead of it, along its curve as it is now: drawn
## out in its tell, a pale line fading ahead; gone once it is past him.
func _trace(a: Dictionary, turn: Transform3D) -> void:
	var tr: MeshInstance3D = a.get("trace")
	if not is_instance_valid(tr): return
	var im: ImmediateMesh = tr.mesh
	im.clear_surfaces()
	if float(a.delay) > 0.0 or float(a.fade) >= 0.0 or bool(a.get("past",false)) or not _inside(a.q):
		tr.visible = false
		return
	tr.visible = true
	tr.global_transform = turn
	var out := TRACE_M*clampf(float(a.t)/TELL,0.15,1.0)
	var p := Vector2((a.q as Vector3).x,(a.q as Vector3).z)
	var w: Vector2 = a.way
	var k := float(a.k)
	p += w*SLICE_L*0.5
	var n := 16
	var stp := out/float(n)
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP,_trace_material())
	for i in range(n+1):
		var u := float(i)/float(n)
		var half := 0.24*(1.0-0.5*u)
		var side := Vector2(-w.y,w.x)*half
		var col := Color(0.9,0.96,1.0,0.7*(1.0-u)*(1.0-u))
		for e in [side,-side]:
			var at := p+(e as Vector2)
			var y: float = study.call("_ground_y",at.x,at.y)+0.14
			im.surface_set_color(col)
			im.surface_add_vertex(Vector3(at.x,y,at.y))
		w = w.rotated(k*stp*0.5)
		p += w*stp
		w = w.rotated(k*stp*0.5)
		if p.length() > DISC: break
	im.surface_end()

func _trace_material() -> StandardMaterial3D:
	if _trace_mat != null: return _trace_mat
	_trace_mat = StandardMaterial3D.new()
	_trace_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_trace_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_trace_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_trace_mat.vertex_color_use_as_albedo = true
	return _trace_mat

## The slice: an upright crescent in the y-z plane, horns down on the turf
## SLICE_L apart along z (its run), its crown SLICE_H up, thickest there;
## its section a thin diamond SLICE_W across at the crown, so it's a blade
## edge-on and a sweep of air side-on, closed from every angle. Brightest
## along its outer (cutting) edge.
func _slice_mesh() -> ArrayMesh:
	if _mesh != null: return _mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 24
	var rings: Array = []
	for i in range(n+1):
		var u := float(i)/float(n)
		var ang := PI*u
		var crown := sin(ang)
		var z := -cos(ang)*SLICE_L*0.5
		var y_out := crown*SLICE_H
		var thick := SLICE_H*0.36*pow(crown,1.3)
		var y_in := y_out-thick
		var w := SLICE_W*0.5*pow(crown,0.9)+0.02
		# Swept a little back at the crown, like a stroke.
		var lean := -0.35*crown
		var mid_y := (y_out+y_in)*0.5
		rings.append([Vector3(0.0,y_out,z+lean),Vector3(w,mid_y,z+lean*0.8),Vector3(0.0,y_in,z+lean*0.6),Vector3(-w,mid_y,z+lean*0.8)])
	var edge := Color(1.0,1.0,1.0,0.97)
	var body := Color(0.72,0.84,0.97,0.85)
	var inner := Color(0.6,0.74,0.92,0.7)
	var cols := [edge,body,inner,body]
	for i in range(n):
		var ha := clampf(sin(PI*float(i)/float(n))*3.0,0.25,1.0)
		var hb := clampf(sin(PI*float(i+1)/float(n))*3.0,0.25,1.0)
		for k in range(4):
			var k2 := (k+1) % 4
			var a: Vector3 = rings[i][k]
			var b: Vector3 = rings[i+1][k]
			var c: Vector3 = rings[i+1][k2]
			var d: Vector3 = rings[i][k2]
			var ca: Color = cols[k]
			var cb: Color = cols[k2]
			for v: Array in [[a,ca,ha],[b,ca,hb],[c,cb,hb],[a,ca,ha],[c,cb,hb],[d,cb,ha]]:
				var col: Color = v[1]
				st.set_color(Color(col.r,col.g,col.b,col.a*float(v[2])))
				st.add_vertex(v[0])
	_mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true
	_mesh.surface_set_material(0,mat)
	return _mesh
