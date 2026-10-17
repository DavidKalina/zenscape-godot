extends Node3D
## The Olmec's air slices (spec "The tilt", the slide; the user's playtest
## of (9)): braced on the rim of the tipped field he sends up its slope
## slashes of wind, each a thin upright crescent travelling edge-first (its
## plane holds its run: horns down on the turf front and back, its crown
## SLICE_H m up), so from the wanderer each reads as a sharp upright line
## coming at him, to sidestep. Each volley is one pattern, never the same
## one twice in a row:
##   "fan":        five from his feet, fanned out, one on the wanderer;
##   "rows":       a row straight up the slope, then a second row in the
##                 first row's gaps;
##   "sweep":      one after another, each further across, sweeping over
##                 the wanderer's line;
##   "converging": two files from either side, crossing where he is
##                 (their lines kept on him till they're near);
##   "aimed":      a single fast one, led at where he'll be.
## Every pattern hits a wanderer who stands still and leaves room a
## sidestep or two away. Slices run in the field's rest frame (the study's
## `tipped` turns them to the world) and fade off the field. One that
## meets him knocks him back up the slope and a little in toward the
## field's middle (never off its lip), once a wave.
##   volley(from, at, n): a pattern from `from` (his feet, rest frame) at
##     `at` (the wanderer, rest frame); `n` is unused (kept for the call).
##   can_send(): whether the last pattern has had its time.
## The study (studies/olmec_field.gd) owns it; `motor` the wanderer's.
## (The file keeps its old name from the crescent "air arcs".)

const Dust = preload("res://scripts/enemies/body_dust.gd")

## A slice: its chord along its run (m), its crown's height (m), its
## thickness at the crown (m, across), the pace (m/s; the slide tops at
## 9.4, set in (10)) and the aimed one's share faster.
const SLICE_L := 3.4
const SLICE_H := 2.6
const SLICE_W := 0.34
const ARC_SPEED := 9.6
const AIMED_FAST := 1.45
## How far a slice runs before it fades (m), and the fade (s).
const ARC_RUN := 95.0
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
## The patterns. LANE: the room between two slices of a row (m). WAVE_GAP:
## the time between two waves reaching him (s), spaced as if he closes at
## CLOSE_AT m/s. REST: the quiet after a pattern has come (s).
const PATTERNS := ["fan","rows","sweep","converging","aimed"]
const LANE := 3.2
const WAVE_GAP := 0.9
const CLOSE_AT := 8.5
const REST := 1.0

var study: Node = null
var motor: RefCounted = null
## The live slices: [{node, q (rest centre), way (rest flat run), speed,
## run, t, delay, wave, fade, puff, pattern, seen, hit}]. One with
## delay > 0 hasn't gone yet.
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

func _init() -> void:
	name = "AirArcs"
	_rng.seed = 911

func can_send() -> bool:
	return _clock >= _rest_until

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
	# His drift and how fast he closes on them (his slide toward the rim).
	var vel := Vector2.ZERO
	if motor != null and study != null and study.get("tilt") != null:
		var v3: Vector3 = study.tilt.steep_turn().basis.inverse()*motor.velocity
		vel = Vector2(v3.x,v3.z)
	var close := maxf(-vel.dot(fwd),0.0)
	var span := dist-2.0
	var g := 1.0 if _rng.randf() < 0.5 else -1.0
	var y := from.y
	var sp := ARC_SPEED
	# The spawn delay that puts a wave WAVE_GAP s behind the one before at him.
	var behind := WAVE_GAP*(sp+maxf(close,CLOSE_AT))/sp
	var last_delay := 0.0
	match pattern:
		"fan":
			# Five from his feet, 9 deg apart, the middle one on the wanderer.
			for k in range(-2,3):
				_slice(o,fwd.rotated(deg_to_rad(9.0)*float(k)),sp,y,0.0,pattern)
		"rows":
			# A row LANE apart, one on him; the second in its gaps.
			for k in range(-3,4):
				_slice(o+side*float(k)*LANE,fwd,sp,y,0.0,pattern)
			_wave += 1
			for k in range(-3,3):
				_slice(o+side*(float(k)+0.5)*LANE,fwd,sp,y,behind,pattern)
			last_delay = behind
		"sweep":
			# One after another across his line, from the -g side to the g side.
			var n := 7
			var each := behind*0.45
			for k in range(n):
				var lat := g*(float(k)-3.0)*2.0
				# Each its own wave: each can knock.
				_slice(o+side*lat,fwd,sp,y,each*float(k),pattern)
				_wave += 1
			last_delay = each*float(n-1)
		"converging":
			# Two files of three from either side of his feet, crossing where
			# the wanderer is.
			for s in [-1.0,1.0]:
				var start: Vector2 = o+side*float(s)*7.0
				var way := (me-start).normalized()
				for k in range(3):
					_slice(start,way,sp,y,behind*0.5*float(k),pattern)
					arcs.back()["home"] = true
			last_delay = behind
		"aimed":
			# Short and fast, led at where his drift across takes him.
			var fast := sp*AIMED_FAST
			var t1 := span/(fast+close)
			var lead := clampf(vel.dot(side)*t1,-6.0,6.0)
			var aim := me+side*lead
			_slice(o,(aim-o).normalized(),fast,y,0.0,pattern)
	_wave += 1
	# Quiet till it has come to him (and a breath), so patterns don't pile up.
	_rest_until = _clock+last_delay+span/(sp+maxf(close,CLOSE_AT))+REST
	print("air arcs: volley %d, %s, %.0f m off" % [patterns.size(),pattern,dist])
	_place_all()

func _slice(c: Vector2, way: Vector2, speed: float, y: float, delay: float, pattern: String) -> void:
	var node := MeshInstance3D.new()
	node.mesh = _slice_mesh()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visible = false
	add_child(node)
	arcs.append({"node":node,"q":Vector3(c.x,y,c.y),"way":way.normalized(),"speed":speed,"run":0.0,"t":0.0,
		"delay":delay,"wave":_wave,"fade":-1.0,"puff":0.0,"pattern":pattern,"seen":false,"hit":false,"seed":_rng.randf()*50.0})
	fired += 1

## Every slice along its run; a meeting with him, a knock; done ones gone.
func step(delta: float) -> void:
	if delta <= 0.0: return
	_clock += delta
	var keep: Array = []
	for a: Dictionary in arcs:
		if not is_instance_valid(a.node): continue
		var node: MeshInstance3D = a.node
		if float(a.delay) > 0.0:
			a.delay = float(a.delay)-delta
			keep.append(a)
			continue
		a.t = float(a.t)+delta
		if float(a.fade) >= 0.0:
			a.fade = float(a.fade)+delta
			if float(a.fade) >= ARC_FADE:
				node.queue_free()
				continue
		if a.get("home",false): _home(a,delta)
		var way: Vector2 = a.way
		var q: Vector3 = (a.q as Vector3)+Vector3(way.x,0.0,way.y)*float(a.speed)*delta
		a.q = q
		a.run = float(a.run)+float(a.speed)*delta
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

## A converging slice keeps its line on where he is now (HOME_TURN rad/s
## at most), till it is HOME_UNTIL m off him; then it runs straight.
const HOME_TURN := 0.5
const HOME_UNTIL := 8.0
func _home(a: Dictionary, delta: float) -> void:
	if motor == null or study == null: return
	var turn_t: Transform3D = study.tilt.steep_turn()
	var me: Vector3 = turn_t.affine_inverse()*motor.feet
	var v3: Vector3 = turn_t.basis.inverse()*motor.velocity
	var to := Vector2(me.x-(a.q as Vector3).x,me.z-(a.q as Vector3).z)
	var way: Vector2 = a.way
	if to.length() < HOME_UNTIL or to.dot(way) <= 0.0:
		a.home = false
		return
	# On where he'll be when it gets there (his slide and drift led).
	var vel := Vector2(v3.x,v3.z)
	var t := to.length()/maxf(float(a.speed)-vel.dot(to.normalized()),2.0)
	var turn := way.angle_to(to+vel*t)
	a.way = way.rotated(clampf(turn,-HOME_TURN*delta,HOME_TURN*delta))

## All gone at once (R, the tilt over).
func clear() -> void:
	for a: Dictionary in arcs:
		if is_instance_valid(a.node): (a.node as Node).queue_free()
	arcs.clear()
	_hit_waves.clear()

## Fade the live ones out (the brace broken); the ones not gone yet never go.
func fade_all() -> void:
	var keep: Array = []
	for a: Dictionary in arcs:
		if float(a.delay) > 0.0:
			if is_instance_valid(a.node): (a.node as Node).queue_free()
			continue
		if float(a.fade) < 0.0: a.fade = 0.0
		keep.append(a)
	arcs = keep

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
		if float(a.delay) > 0.0 or not _inside(q):
			node.visible = false
			continue
		node.visible = true
		var way: Vector2 = a.way
		# Edge-first: the mesh's +z along its run, its plane upright.
		var b := Basis.looking_at(-Vector3(way.x,0.0,way.y),Vector3.UP)
		# It cuts up out of the turf as it goes, and sinks back as it fades.
		var grow := clampf(float(a.t)/0.2,0.15,1.0)
		var fade := 1.0-clampf(float(a.fade)/ARC_FADE,0.0,1.0) if float(a.fade) >= 0.0 else 1.0
		var flick := 1.0+0.05*sin(float(a.t)*29.0+float(a.seed))
		b = b.scaled(Vector3(flick,grow*maxf(fade,0.05)*flick,1.0))
		node.global_transform = turn*Transform3D(b,_on_turf(q)-Vector3.UP*0.1)
		node.transparency = (1.0-fade)*0.9

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
