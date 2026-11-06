extends RefCounted
## The steam train's models on RailTrain's cars (spec-steam-train.md, the trunk):
## each car's glb (art/blender/train/train_build.py, into
## assets/models/train/<kind>.glb) in place of its greybox blocks. Drawn only: the
## solid stays RailTrain's blocks (`_parts`), which follow the models.
##
## - The running gear, driven by the train's odometer: every wheelset (Driver_*,
##   Lead_*, Wheels_*) turns about its axle (local x) by the distance run over its
##   radius (its axle's height over the rail's top); the trucks (LeadTruck,
##   Truck_F, Truck_R) swivel to the track's way at the car's bogies; the engine's
##   rods follow the drivers' crank pins: SideRod_* rides round with the pins (it
##   never turns), MainRod_* turns on the rear pin so its far end stays on the
##   crosshead's line, and Crosshead_* slides along it. Only the cars within their
##   far look's range of the camera are moved: past it the Far mesh shows, the car
##   at rest (assets/models/train/train_import.gd).
## - The smash car's plugs, CrackPlug_F and CrackPlug_B (RailTrain's plates 0 and
##   1): shut, each is drawn as one merged mesh (one draw call, not 40) with its
##   Cover glowing behind; a burst throws its shards in the car's frame (on with the
##   plane, out from its line, up, spinning: SmashBreaks' numbers, as the pirate
##   ship's), kept in the corridor, lying on the flats either side, else falling
##   away under the bed; a reseal puts them home.
##
## --train-greybox: the greybox blocks as before (the A/B).

const SmashBreaks = preload("res://scripts/breaks/smash_breaks.gd")
const RailTrack = preload("res://scripts/endless/rail_track.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")

const MODELS := "res://assets/models/train/%s.glb"
## Moved only within the car's far range of the camera plus this (m): the range's
## own hysteresis (train_import.gd MARGIN) and a little more.
const MOVE_PAST := 12.0
## A thrown shard: fall (m/s²), what a bounce keeps, how fast a floor stops it
## (1/s), its room from the corridor's walls (m), still under this (m/s), and how
## far past the car's ends the flats either side catch it (m: a flat's length).
const SHARD_DROP := 16.0
const SHARD_BOUNCE := 0.35
const SHARD_RUB := 4.0
const SHARD_ROOM := 0.3
const SHARD_STILL := 1.0
const SHARD_CATCH := 20.0

## kind -> PackedScene, or null with no model.
static var _scenes := {}
## The shut plugs' merged meshes, kind/part -> Mesh, built once for every train.
static var _wholes := {}

## Thrown shards: {node, plug (its CrackPlug), v (m/s, the car's frame), spin, car}.
var shards: Array[Dictionary] = []

static func wanted() -> bool:
	return not ("--train-greybox" in LaunchArgs.user_args())

static func _scene(kind: String) -> PackedScene:
	if not _scenes.has(kind):
		var path := MODELS % kind
		_scenes[kind] = load(path) if ResourceLoader.exists(path) else null
	return _scenes[kind]

## Car `car`'s model under its node, its moving parts found (`car.rig`). False if
## its kind has no model (RailTrain draws its blocks then).
func dress(car: Dictionary) -> bool:
	var scene := _scene(str(car.kind))
	if scene == null: return false
	var model := scene.instantiate() as Node3D
	model.name = "Model"
	(car.node as Node3D).add_child(model)
	car.model = model
	var root: Node3D = model.get_child(0) if model.get_child_count() > 0 else model
	var rig := {"wheels":[],"trucks":[],"rods":[],"reach":0.0}
	var far := root.get_node_or_null("Far") as GeometryInstance3D
	rig.reach = (far.visibility_range_begin+far.visibility_range_begin_margin if far != null else 150.0)+MOVE_PAST
	for child in root.get_children():
		var n := str(child.name)
		if n.begins_with("Driver_"): _wheel(rig,child,root)
		elif n == "LeadTruck" or n.begins_with("Truck_"):
			(rig.trucks as Array).append([child,n != "Truck_R"])
			for w in child.get_children():
				if str(w.name).begins_with("Lead_") or str(w.name).begins_with("Wheels_"): _wheel(rig,w,root)
	var rear := root.get_node_or_null("Driver_2") as Node3D
	if rear != null:
		var r := rear.position.y-RailTrack.RAIL_TOP
		for tag: String in ["R","L"]:
			var side := root.get_node_or_null("SideRod_"+tag) as Node3D
			var main := root.get_node_or_null("MainRod_"+tag) as Node3D
			var head := root.get_node_or_null("Crosshead_"+tag) as Node3D
			if side == null or main == null or head == null: continue
			var pin := Vector2(main.position.y,main.position.z)
			var to := Vector2(head.position.y,head.position.z)-pin
			(rig.rods as Array).append({"side":side,"main":main,"head":head,"r":r,
				"axle":Vector2(rear.position.y,rear.position.z),"off":pin-Vector2(rear.position.y,rear.position.z),
				"side_at":side.position,"pin":pin,"head_at":head.position,"long":to.length(),
				"rest":atan2(to.x,to.y),"ahead":signf(to.y)})
	car.rig = rig
	return true

## A wheelset: its node and radius (its axle over the rail's top, in the car's frame).
static func _wheel(rig: Dictionary, n: Node, root: Node3D) -> void:
	var y := 0.0
	var m: Node = n
	while m != root:
		y += (m as Node3D).position.y
		m = m.get_parent()
	(rig.wheels as Array).append([n,maxf(y-RailTrack.RAIL_TOP,0.1)])

## The smash car's plate `k` (0 the front) drawn by its plug: {plug, whole, cover,
## shards ([{node, home}])}, the plug drawn shut; {} if the model has none.
func plug(car: Dictionary, k: int) -> Dictionary:
	if not car.has("model"): return {}
	var part := "F" if k == 0 else "B"
	var p := (car.model as Node).find_child("CrackPlug_"+part,true,false) as Node3D
	if p == null: return {}
	var out := {"plug":p,"shards":[]}
	for s: Node in p.get_children():
		if str(s.name).begins_with("Cover"):
			out.cover = s
			(s as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			continue
		(out.shards as Array).append({"node":s,"home":(s as Node3D).transform})
		(s as Node3D).visible = false
	var key := "%s/%s" % [car.kind,part]
	if not _wholes.has(key): _wholes[key] = _merge(out.shards)
	var whole := MeshInstance3D.new()
	whole.name = "Whole_"+part
	whole.mesh = _wholes[key]
	p.add_child(whole)
	out.whole = whole
	return out

## `list` ({node, home}) as one mesh in their plug's frame, a surface a material.
static func _merge(list: Array) -> Mesh:
	var by := {}
	for s: Dictionary in list:
		var mesh: Mesh = (s.node as MeshInstance3D).mesh
		for k in mesh.get_surface_count():
			var mat := mesh.surface_get_material(k)
			if not by.has(mat):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				by[mat] = st
			(by[mat] as SurfaceTool).append_from(mesh,k,s.home)
	var out := ArrayMesh.new()
	for mat: Material in by:
		(by[mat] as SurfaceTool).commit(out)
		out.surface_set_material(out.get_surface_count()-1,mat)
	return out

## Plate `look` (`plug`'s) burst by a plane going `v` (m/s, the car's frame) at
## `q` (the car's frame): the shards thrown.
func burst(car: Dictionary, look: Dictionary, q: Vector3, v: Vector3) -> void:
	if look.is_empty(): return
	(look.whole as Node3D).visible = false
	if look.has("cover"): (look.cover as Node3D).visible = false
	var p: Node3D = look.plug
	var d := v.normalized() if v.length() > 1.0 else Vector3.FORWARD
	for s: Dictionary in look.shards:
		var n: Node3D = s.node
		n.transform = s.home
		n.visible = true
		var out := (p.position+n.position-q).slide(d)
		out = out.normalized() if out.length() > 0.05 else Vector3.UP
		var lin := v*randf_range(SmashBreaks.KEEP.x,SmashBreaks.KEEP.y)+out*randf_range(SmashBreaks.OUT.x,SmashBreaks.OUT.y)+Vector3.UP*randf_range(SmashBreaks.UP_V.x,SmashBreaks.UP_V.y)
		var spin := Vector3(randf_range(-1.0,1.0),randf_range(-1.0,1.0),randf_range(-1.0,1.0)).normalized()*randf_range(SmashBreaks.SPIN.x,SmashBreaks.SPIN.y)
		shards.append({"node":n,"plug":p,"v":lin,"spin":spin,"car":car})

## Plate `look` shut: its shards home and hidden, drawn whole again.
func shut(look: Dictionary) -> void:
	if look.is_empty(): return
	for i in range(shards.size()-1,-1,-1):
		if shards[i].plug == look.plug: shards.remove_at(i)
	for s: Dictionary in look.shards:
		(s.node as Node3D).transform = s.home
		(s.node as Node3D).visible = false
	(look.whole as Node3D).visible = true
	if look.has("cover"): (look.cover as Node3D).visible = true

## One frame of the running gear, the train `d` m along its track (its odometer),
## for the cars within reach of `eye` (world); and the thrown shards.
func step(delta: float, cars: Array[Dictionary], d: float, eye: Vector3, corridor: Vector3, deck: float) -> void:
	for car: Dictionary in cars:
		if not car.has("rig"): continue
		var rig: Dictionary = car.rig
		var xf: Transform3D = car.xf
		if xf.origin.distance_squared_to(eye) > float(rig.reach)*float(rig.reach): continue
		for w: Array in rig.wheels: (w[0] as Node3D).rotation.x = -fposmod(d/float(w[1]),TAU)
		for t: Array in rig.trucks:
			var way: Vector3 = car.ta if bool(t[1]) else car.tb
			var l: Vector3 = (car.inv as Transform3D).basis*way
			if l.z > 0.0: l = -l
			(t[0] as Node3D).rotation.y = atan2(-l.x,-l.z)
		for rod: Dictionary in rig.rods: _rod(rod,-d/float(rod.r))
	if not shards.is_empty(): _shards_step(delta,corridor,deck)

## The rods with the drivers turned `a` (rad about x).
static func _rod(rod: Dictionary, a: float) -> void:
	var o: Vector2 = rod.off
	var pin: Vector2 = (rod.axle as Vector2)+Vector2(o.x*cos(a)-o.y*sin(a),o.x*sin(a)+o.y*cos(a))
	var moved := pin-(rod.pin as Vector2)
	var side: Node3D = rod.side
	var at: Vector3 = rod.side_at
	side.position = Vector3(at.x,at.y+moved.x,at.z+moved.y)
	var main: Node3D = rod.main
	main.position = Vector3(main.position.x,pin.x,pin.y)
	var head: Node3D = rod.head
	var h: Vector3 = rod.head_at
	var up := h.y-pin.x
	var z := pin.y+float(rod.ahead)*sqrt(maxf(float(rod.long)*float(rod.long)-up*up,0.0))
	head.position = Vector3(h.x,h.y,z)
	main.rotation.x = float(rod.rest)-atan2(up,z-pin.y)

## Thrown shards on, each in its car's frame: `corridor` the smash car's
## (half width, floor, roof), `deck` the flats' either side. Inside the car's
## length they're kept in the corridor and lie where they stop till the reseal;
## out past its ends they lie on the flat there, or past that fall away.
func _shards_step(delta: float, corridor: Vector3, deck: float) -> void:
	for i in range(shards.size()-1,-1,-1):
		var s: Dictionary = shards[i]
		var n: Node3D = s.node
		var p: Node3D = s.plug
		var half := float((s.car as Dictionary).long)*0.5
		var v: Vector3 = s.v
		v += Vector3.DOWN*SHARD_DROP*delta
		var at: Vector3 = p.position+n.position+v*delta
		var low := false
		var floor_y := -INF
		if absf(at.z) < half:
			var x := corridor.x-SHARD_ROOM
			if absf(at.x) > x:
				at.x = signf(at.x)*x
				v.x *= -SHARD_BOUNCE
			if at.y > corridor.z-SHARD_ROOM:
				at.y = corridor.z-SHARD_ROOM
				v.y = -absf(v.y)*SHARD_BOUNCE
			floor_y = corridor.y+SHARD_ROOM*0.5
		elif absf(at.z) < half+SHARD_CATCH and absf(at.x) < 3.0: floor_y = deck+SHARD_ROOM*0.5
		if at.y < floor_y:
			at.y = floor_y
			v.y = absf(v.y)*SHARD_BOUNCE
			v *= maxf(1.0-SHARD_RUB*delta,0.0)
			low = true
		s.v = v
		n.position = at-p.position
		var spin: Vector3 = s.spin
		if low: spin *= maxf(1.0-SHARD_RUB*delta,0.0)
		s.spin = spin
		if spin.length() > 0.01: n.rotate(spin.normalized(),spin.length()*delta)
		if low and v.length() < SHARD_STILL: shards.remove_at(i)
		elif at.y < -2.0:
			n.visible = false
			shards.remove_at(i)
