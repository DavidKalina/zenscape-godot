extends Node3D
## The Olmec's air arcs (spec "The tilt", the slide): braced on the rim of
## the tipped field he sends up its slope blades of wind standing on edge,
## crescents ARC_W m across and ARC_H m tall, bowed forward, a few at a
## time with gaps between, at the wanderer sliding down to him. Each runs
## in the field's rest frame (the study's `tipped` turns it to the world)
## from his feet along its own way at ARC_SPEED, and fades out past the
## field. One that meets the wanderer knocks him back up the slope and a
## little in toward the field's middle (never off its lip), once.
##   volley(from, at, n): `n` arcs from `from` (rest frame), the middle
##     one aimed at `at`, the others ARC_W+ARC_GAP to either side.
## The study (studies/olmec_field.gd) owns it; `motor` the wanderer's.

const Dust = preload("res://scripts/enemies/body_dust.gd")

## The crescent: across (m), its height (m), its bow forward (m), its
## thickness at the crown (share of the height).
const ARC_W := 3.6
const ARC_H := 3.0
const ARC_BOW := 0.9
const ARC_THICK := 0.32
## The gap between two arcs of a volley (m) and their pace (m/s).
const ARC_GAP := 3.4
const ARC_SPEED := 10.5
## How far an arc runs before it fades (m), and the fade (s).
const ARC_RUN := 90.0
const ARC_FADE := 0.35
## Its depth for a hit (m, either side of its line), the knock (m out, m
## up) and the share of it in toward the field's middle line.
const HIT_DEPTH := 0.7
const KNOCK_OUT := 3.0
const KNOCK_UP := 1.4
const KNOCK_IN := 0.3

var study: Node = null
var motor: RefCounted = null
## The live arcs: [{node, q (rest frame), way (rest flat), run, t, hit, fade}].
var arcs: Array = []
## Counts, for checks.
var fired := 0
var hits := 0
var last_hit := Vector3.ZERO
var _mesh: ArrayMesh = null

func _init() -> void:
	name = "AirArcs"

## A volley of `n` arcs from `from` toward `at` (both rest frame, flat):
## the middle one on `at`, the rest spread to either side of it.
func volley(from: Vector3, at: Vector3, n: int) -> void:
	var to := Vector2(at.x-from.x,at.z-from.z)
	if to.length() < 1.0: return
	var dist := to.length()
	var mid := to/dist
	var side := Vector2(-mid.y,mid.x)
	# Side by side, all one way (so the gaps between hold as they come).
	for k in range(n):
		var off := (float(k)-float(n-1)*0.5)*(ARC_W+ARC_GAP)
		var way := mid
		var q := from+Vector3(way.x,0.0,way.y)*2.0+Vector3(side.x,0.0,side.y)*off
		var node := MeshInstance3D.new()
		node.mesh = _arc_mesh()
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		arcs.append({"node":node,"q":q,"way":way,"run":0.0,"t":0.0,"hit":false,"fade":-1.0,"puff":0.0})
		fired += 1
	_place_all()

## Every arc up its way; a meeting with him, a knock; done ones gone.
func step(delta: float) -> void:
	if delta <= 0.0: return
	var keep: Array = []
	for a: Dictionary in arcs:
		if not is_instance_valid(a.node): continue
		var node: MeshInstance3D = a.node
		a.t = float(a.t)+delta
		if float(a.fade) >= 0.0:
			a.fade = float(a.fade)+delta
			if float(a.fade) >= ARC_FADE:
				node.queue_free()
				continue
		var was: Vector3 = a.q
		var way: Vector2 = a.way
		var q := was+Vector3(way.x,0.0,way.y)*ARC_SPEED*delta
		a.q = q
		a.run = float(a.run)+ARC_SPEED*delta
		if float(a.run) > ARC_RUN and float(a.fade) < 0.0: a.fade = 0.0
		if not bool(a.hit) and float(a.fade) < 0.0: _meet(a,was,q)
		a.puff = float(a.puff)-delta
		if float(a.puff) <= 0.0 and study != null and float(a.fade) < 0.0:
			a.puff = 0.12
			var side := Vector3(-way.y,0.0,way.x)
			var foot: Vector3 = study.tipped(_on_turf(q)+side*ARC_W*0.45*(1.0 if randf() < 0.5 else -1.0))
			Dust.puff(study.get("enemies"),foot,0.9,Vector3.UP)
		keep.append(a)
	arcs = keep
	_place_all()

## All gone at once (R, the tilt over).
func clear() -> void:
	for a: Dictionary in arcs:
		if is_instance_valid(a.node): (a.node as Node).queue_free()
	arcs.clear()

## Fade the live ones out (the brace broken).
func fade_all() -> void:
	for a: Dictionary in arcs:
		if float(a.fade) < 0.0: a.fade = 0.0

func _on_turf(q: Vector3) -> Vector3:
	var y: float = study.call("_ground_y",q.x,q.z) if study != null else q.y
	return Vector3(q.x,y,q.z)

## The arc swept from `was` to `q` this step: his feet (rest frame) within
## its depth of the swept line, across within its half width, under its
## top: knocked.
func _meet(a: Dictionary, was: Vector3, q: Vector3) -> void:
	if motor == null or study == null: return
	if motor.seized(): return
	var turn: Transform3D = study.tilt.steep_turn()
	var p: Vector3 = turn.affine_inverse()*motor.feet
	var way: Vector2 = a.way
	var side := Vector2(-way.y,way.x)
	var rel_was := Vector2(p.x-was.x,p.z-was.z)
	var rel := Vector2(p.x-q.x,p.z-q.z)
	var along_was := rel_was.dot(way)
	var along := rel.dot(way)
	# Crossed (or within its depth of) him this step.
	if not (along <= HIT_DEPTH and along_was >= -HIT_DEPTH): return
	var across := absf(rel.dot(side))
	if across > ARC_W*0.5: return
	var over := p.y-float(study.call("_ground_y",p.x,p.z))
	if over > ARC_H or over < -1.0: return
	a.hit = true
	hits += 1
	last_hit = motor.feet
	# Back up its way (up the slope) and a little in toward the field's
	# middle line, so it never throws him off a side.
	var inward := -Vector2(p.x,p.z).dot(side)*side
	inward = inward.normalized() if inward.length() > 0.1 else Vector2.ZERO
	var flat_rest := (way+inward*KNOCK_IN).normalized()
	var w3: Vector3 = turn.basis*Vector3(flat_rest.x,0.0,flat_rest.y)
	var away := Vector2(w3.x,w3.z).normalized()
	motor.knock(motor.knock_velocity(away,KNOCK_OUT,KNOCK_UP),self)
	Dust.puff(study.get("enemies"),motor.feet,1.4,Vector3.UP)
	print("air arcs: hit him at (%.1f, %.1f), across %.1f" % [p.x,p.z,across])

func _place_all() -> void:
	if study == null: return
	var turn: Transform3D = study.tilt.steep_turn()
	for a: Dictionary in arcs:
		if not is_instance_valid(a.node): continue
		var node: MeshInstance3D = a.node
		var way: Vector2 = a.way
		# Its bow leads: the mesh's +z along its way.
		var b := Basis.looking_at(-Vector3(way.x,0.0,way.y),Vector3.UP)
		var grow := clampf(float(a.t)/0.18,0.2,1.0)
		var shimmer := 1.0+0.04*sin(float(a.t)*31.0)
		var s := grow*shimmer
		var fade := 1.0-clampf(float(a.fade)/ARC_FADE,0.0,1.0) if float(a.fade) >= 0.0 else 1.0
		b = b.scaled(Vector3(s,s*maxf(fade,0.05),s))
		node.global_transform = turn*Transform3D(b,_on_turf(a.q))
		node.transparency = 1.0-fade

## The crescent: an arch standing on edge, horns down on the turf, its
## crown ARC_H up, thickest at the crown, bowed ARC_BOW forward (+z) at
## the middle; three rows (outer rim, bright core, inner rim) so the
## edges fade.
func _arc_mesh() -> ArrayMesh:
	if _mesh != null: return _mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 28
	var rows: Array = []
	for r in range(3):
		var row: Array = []
		for i in range(n+1):
			var u := float(i)/float(n)
			var ang := PI*u
			var x := -cos(ang)*ARC_W*0.5
			var crown := sin(ang)
			var thick := ARC_H*ARC_THICK*pow(crown,1.4)
			var y_out := crown*ARC_H
			var y := y_out-thick*float(r)*0.5
			var z := ARC_BOW*(1.0-pow(2.0*u-1.0,2.0))
			# The inner rim pulled in a little across too, a sharper horn.
			var xs := x*(1.0-0.06*float(r))
			row.append(Vector3(xs,y,z))
		rows.append(row)
	var core := Color(0.94,0.97,1.0,0.9)
	var rim := Color(0.85,0.92,1.0,0.0)
	for r in range(2):
		for i in range(n):
			var a: Vector3 = rows[r][i]
			var b: Vector3 = rows[r][i+1]
			var c: Vector3 = rows[r+1][i+1]
			var d: Vector3 = rows[r+1][i]
			var ca := core if r == 1 else rim
			var cb := core if r == 0 else rim
			# Horns fade into the turf.
			var ha := clampf(sin(PI*float(i)/float(n))*2.5,0.0,1.0)
			var hb := clampf(sin(PI*float(i+1)/float(n))*2.5,0.0,1.0)
			for v: Array in [[a,ca,ha],[b,ca,hb],[c,cb,hb],[a,ca,ha],[c,cb,hb],[d,cb,ha]]:
				var col: Color = v[1]
				st.set_color(Color(col.r,col.g,col.b,col.a*float(v[2])))
				st.add_vertex(v[0])
	_mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = false
	_mesh.surface_set_material(0,mat)
	return _mesh
