extends SceneTree
## The base of a driver: a throwaway script that opens a study, plays it
## through the real loop (its own `_process`, input pressed as actions) and
## prints what it measured. Extend it and write `drive()`:
##
##   extends "res://tools/harness/drive.gd"
##   func drive() -> void:
##   	await open("studies/trap_yard.tscn")
##   	await place(Vector3(0, 1, 4), Vector2(0, -1))
##   	await walk_to(Vector3(0, 1, -6))
##   	check(motor.grounded, "made it across", "feet %s" % motor.feet)
##   	row({"seed": arg("seed"), "feet": motor.feet})
##
##   python tools/drive.py scratch/my_check.gd -- --seed=2 --scene-args --shape=ring
##
## Args after `--` are the driver's (`arg("seed")`); the ones after a
## `--scene-args` token are the scene's (`arg` falls back to them): `open` hands those to it as its
## launch flags (scripts/launch_args.gd), with `--no-title`, so the scene
## never sees the driver's. `--timeout=S` (default 240) is wall-clock.
##
## What it prints, for tools/drive.py and tools/sweep.py to read:
##   OK   label / FAIL label: detail   from check()
##   [f12] text / | text               from say() / note()
##   ROW {json}                        from row(), one per run of a sweep
##   RESULT {json}                     once, at the end: result() values,
##                                     checks, failures, frames, seconds
## and quits 0, or 1 with a failed check, 2 on the timeout.
##
## Typing: the project warns on untyped `:=` it can't infer, which is a
## parse error. Write `var d: Dictionary = x.get("k")`, never
## `var d := x.get("k")`; `study` and `motor` are Variants on purpose.

const LaunchArgs = preload("res://scripts/launch_args.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const DT := 1.0/60.0
## The actions a driver may hold; `let_go` releases them all.
const ACTIONS: Array[StringName] = [&"move_forward",&"move_back",&"move_left",&"move_right",
	&"walk_jump",&"walk_twirl",&"walk_crouch",&"walk_wind",&"telescope"]

## The scene `open` opened, and its pilot motor (scripts/pilot_motor.gd) if
## it has one.
var study: Node = null
var motor: Variant = null
## Frames stepped through `frames` / `until` / `walk_to` since start.
var frame := 0
## True: each frame the study's camera yaw follows the walker's facing, so
## the stick's forward is his forward (the way the tests hold it).
var yaw_follows_facing := false
var failures := 0
var checks := 0
var results := {}
var _args := {}
var _scene_kv := {}
var _scene_args := PackedStringArray()
var _deadline := 0
var _began := 0
var _done := false

## Override: the run.
func drive() -> void:
	push_error("drive.gd: write a drive() in the script that extends it")

func _initialize() -> void:
	_began = Time.get_ticks_msec()
	var after := false
	for a: String in OS.get_cmdline_user_args():
		if a == "--scene-args":
			after = true
		elif after:
			_scene_args.append(a)
			if a.begins_with("--"):
				var eq := a.find("=")
				if eq < 0: _scene_kv[a.substr(2)] = true
				else: _scene_kv[a.substr(2,eq-2)] = a.substr(eq+1)
		elif a.begins_with("--"):
			var eq := a.find("=")
			if eq < 0: _args[a.substr(2)] = true
			else: _args[a.substr(2,eq-2)] = a.substr(eq+1)
	_deadline = _began+int(float(arg("timeout","240"))*1000.0)
	process_frame.connect(_watch)
	_main.call_deferred()

func _main() -> void:
	await drive()
	finish()

func _watch() -> void:
	if _done or Time.get_ticks_msec() < _deadline: return
	_done = true
	print("TIMEOUT after %.0f s at frame %d" % [(Time.get_ticks_msec()-_began)/1000.0,frame])
	_print_result()
	push_error("driver timed out")
	quit(2)

# --- Args ---------------------------------------------------------------------

## `--name=value` as a String, `--name` as true, else `default`. The
## driver's args first, then the scene's (so a tools/sweep.py axis, which
## is a scene flag, reads here too).
func arg(name: String, default: Variant = null) -> Variant:
	return _args.get(name,_scene_kv.get(name,default))

func arg_int(name: String, default := 0) -> int:
	return int(arg(name,default))

func arg_float(name: String, default := 0.0) -> float:
	return float(arg(name,default))

func flag(name: String) -> bool:
	return _args.has(name) or _scene_kv.has(name)

## `--at=x,y,z` as a Vector3.
func arg_vec3(name: String, default := Vector3.ZERO) -> Vector3:
	if arg(name) == null: return default
	var p := String(arg(name)).split(",")
	return Vector3(float(p[0]),float(p[1]),float(p[2]))

## The args after `--scene-args`.
func scene_args() -> PackedStringArray:
	return _scene_args

# --- The scene ----------------------------------------------------------------

## Changes to `scene` ("studies/x.tscn" or a res:// path) the way the game
## does, with `args` (default: scene_args()) as its launch flags, and waits
## until it stands and, if it has `walk_ready`, until he walks (at most
## `ready_frames`). Returns the frames it took to be ready, -1 if it never was.
func open(scene: String, args: Variant = null, ready_frames := 3000) -> int:
	if not scene.begins_with("res://"): scene = "res://"+scene
	var given := PackedStringArray(scene_args() if args == null else args)
	if not "--no-title" in given: given.insert(0,"--no-title")
	LaunchArgs.set_override(given)
	var packed: PackedScene = load(scene)
	if packed == null:
		check(false,"open "+scene,"did not load")
		return -1
	var was := current_scene
	change_scene_to_packed(packed)
	while current_scene == null or current_scene == was:
		await process_frame
	study = current_scene
	motor = study.get("motor")
	if not "walk_ready" in study: return 0
	# A study that holds him after walk_ready (run_layer's city layers wait
	# for the landing to stand, then set him back at the spawn) says so.
	var waited := await until(func() -> bool: return bool(study.walk_ready) and not (study.has_method("holding") and bool(study.holding())),ready_frames)
	if waited < 0: check(false,"%s ready" % scene.get_file(),"walk_ready still false after %d frames" % ready_frames)
	return waited

## Set down at `at` facing `face` (x, z), then two frames to settle.
func place(at: Vector3, face := Vector2(0.0,-1.0)) -> void:
	study.place(at,face)
	await frames(2)

## To station `key` (the study's number keys), then two frames.
func go_to(key: int) -> void:
	let_go()
	study.go_to(key)
	await frames(2)

# --- Time ---------------------------------------------------------------------

## `n` frames of the real loop.
func frames(n: int) -> void:
	for i in n:
		if yaw_follows_facing and motor != null and "_yaw" in study:
			study.set("_yaw",motor.facing)
		await process_frame
		frame += 1

func physics_frames(n: int) -> void:
	for i in n: await physics_frame

## Frames until `cond` is true (at most `max_frames`): how many it took, or -1.
func until(cond: Callable, max_frames := 600) -> int:
	for i in max_frames + 1:
		if cond.call(): return i
		if i < max_frames: await frames(1)
	return -1

# --- Input (the real path: actions the study reads) --------------------------

func hold(action: StringName, on := true, strength := 1.0) -> void:
	if on: Input.action_press(action,strength)
	else: Input.action_release(action)

## Pressed for `n` frames, then released.
func press(action: StringName, n := 1) -> void:
	hold(action)
	await frames(n)
	hold(action,false)

func let_go() -> void:
	for a in ACTIONS:
		if InputMap.has_action(a): Input.action_release(a)

## The left stick, Godot's way: x right, y down (so (0, -1) is forward).
func stick(v: Vector2) -> void:
	hold(&"move_right",v.x > 0.0,maxf(v.x,0.0))
	hold(&"move_left",v.x < 0.0,maxf(-v.x,0.0))
	hold(&"move_back",v.y > 0.0,maxf(v.y,0.0))
	hold(&"move_forward",v.y < 0.0,maxf(-v.y,0.0))

## The stick that walks him toward world `point` from the camera's yaw
## (character_study `_want`, inverted).
func stick_toward(point: Vector3) -> Vector2:
	var d := Vector2(point.x-motor.feet.x,point.z-motor.feet.z)
	if d.length() < 0.001: return Vector2.ZERO
	d = d.normalized()
	var forward: Vector2 = PilotMotor.forward(float(study.get("_yaw")))
	var right := Vector2(-forward.y,forward.x)
	return Vector2(d.dot(right),-d.dot(forward)).limit_length(1.0)

## Walks him to `point` through the input (within `near` m across), at most
## `max_frames`; true if he got there. `jump_at` (0..1 of the way, or -1):
## the jump pressed once when that far along.
func walk_to(point: Vector3, max_frames := 900, near := 0.6, jump_at := -1.0) -> bool:
	var from := Vector2(motor.feet.x,motor.feet.z)
	var to := Vector2(point.x,point.z)
	var jumped := false
	for i in max_frames:
		var at := Vector2(motor.feet.x,motor.feet.z)
		if at.distance_to(to) <= near:
			stick(Vector2.ZERO)
			return true
		if jump_at >= 0.0 and not jumped and from.distance_to(at) >= from.distance_to(to)*jump_at:
			jumped = true
			hold(&"walk_jump")
		elif jumped:
			hold(&"walk_jump",false)
		stick(stick_toward(point))
		await frames(1)
	stick(Vector2.ZERO)
	return false

## A jump: held `n` frames (longer is higher), then released.
func jump(n := 8) -> void:
	await press(&"walk_jump",n)

# --- Scripted ticks (no input path: faster, but not the play loop) ------------

## `n` ticks with the study scripted: its stick `want` (world x, z) and
## jump set, `tick` called by hand. Use for setup, prove with the input.
func scripted_ticks(n: int, want := Vector2.ZERO, jump_held := false) -> void:
	study.scripted = true
	for i in n:
		study.script_want = want
		study.script_jump = jump_held
		study.tick(DT)
		await physics_frame
	study.script_want = Vector2.ZERO
	study.script_jump = false

func unscripted() -> void:
	study.scripted = false

# --- Looking around -----------------------------------------------------------

## Nodes under the scene whose name, class or script path contains `pattern`.
func find(pattern: String, under: Node = null) -> Array[Node]:
	var out: Array[Node] = []
	var top: Node = under if under != null else (study if study != null else root)
	for n: Node in top.find_children("*","",true,false):
		var s: Script = n.get_script()
		if pattern in n.name or n.is_class(pattern) or (s != null and pattern in s.resource_path):
			out.append(n)
	return out

func first(pattern: String, under: Node = null) -> Node:
	var hits := find(pattern,under)
	return hits[0] if not hits.is_empty() else null

# --- Collider probes ----------------------------------------------------------
#
#   var h := ray(Vector3(-20, 200, -41), Vector3(-20, -50, -41))
#   say(hit_text(h))   # "Isle/Island/Body (Concave) layer 1 mask 1 shape CollisionShape3D at (..) n (..) d 12.30"
#   for s in pierce(Vector3(-20, 200, -41), Vector3(-20, -50, -41)): say(hit_text(s))
#   for c in what_is_at(motor.feet, 0.5): say(hit_text(c))
#
# Each returns hit Dictionaries ({} or [] for nothing): `collider` (the
# Node), `path`, `name`, `layer`, `mask`, `shape` (its index on the
# collider), `shape_type` ("Box", "Concave"...), `shape_node` (the
# CollisionShape3D's path) and, for a ray, `position`, `normal`, `distance`.

## Every layer.
const ALL_LAYERS := 0xFFFFFFFF
const _SHAPE_TYPES := ["WorldBoundary","SeparationRay","Sphere","Box","Capsule","Cylinder","Convex","Concave","HeightMap","SoftBody","Custom"]

## The physics space of the open scene (the root's, before `open`).
func space() -> PhysicsDirectSpaceState3D:
	var w: World3D = (study as Node3D).get_world_3d() if study is Node3D else root.find_world_3d()
	return w.direct_space_state

## The first collider on the segment `from`..`to` ({} if none). `mask`:
## the layers it sees (e.g. `WalkerOnly.body_mask(study.ground.mask)`);
## `inside`: a ray starting inside a shape hits it there (normal zero);
## `exclude`: CollisionObject3Ds or RIDs skipped; `areas`: Area3Ds too.
func ray(from: Vector3, to: Vector3, mask := ALL_LAYERS, inside := false, exclude: Array = [], areas := false) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from,to,mask,_rids(exclude))
	q.hit_from_inside = inside
	q.collide_with_areas = areas
	var h: Dictionary = space().intersect_ray(q)
	if h.is_empty(): return {}
	var out := _about(h.get("collider"),int(h.get("shape",0)))
	out["position"] = h.position
	out["normal"] = h.normal
	out["distance"] = from.distance_to(h.position)
	return out

## Every surface on `from`..`to` in order, at most `most`: after each hit
## the ray goes on from `step` m past it (so a trimesh's lower face under
## an overhang is found too). A stack of floors under a point:
## `pierce(Vector3(x, 200, z), Vector3(x, -50, z))`.
func pierce(from: Vector3, to: Vector3, mask := ALL_LAYERS, most := 8, step := 0.05) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dir := (to-from).normalized()
	var at := from
	for i in most:
		var h := ray(at,to,mask)
		if h.is_empty(): break
		h["distance"] = from.distance_to(h.position)
		out.append(h)
		at = (h.position as Vector3)+dir*step
		if (to-at).dot(dir) <= 0.0: break
	return out

## The colliders touching a ball of `radius` at `pos`, one a shape (at
## most `most` contacts asked of the space).
func what_is_at(pos: Vector3, radius := 0.25, mask := ALL_LAYERS, most := 16, areas := false) -> Array[Dictionary]:
	var ball := SphereShape3D.new()
	ball.radius = radius
	return _overlap(ball,Transform3D(Basis.IDENTITY,pos),mask,most,areas)

## The colliders touching `box` (world, axis-aligned), as `what_is_at`.
func what_is_in(box: AABB, mask := ALL_LAYERS, most := 16, areas := false) -> Array[Dictionary]:
	var b := BoxShape3D.new()
	b.size = box.size.abs()
	return _overlap(b,Transform3D(Basis.IDENTITY,box.get_center()),mask,most,areas)

## Each CollisionObject3D under `node` (itself too): {collider, path,
## layer, mask, shapes ({type: count}), box (its shapes' AABB, world)}.
## A piece's whole collision box: `collision_box(node)`.
func colliders(node: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var all: Array[Node] = [node]
	all.append_array(node.find_children("*","CollisionObject3D",true,false))
	for n in all:
		if not n is CollisionObject3D: continue
		var co := n as CollisionObject3D
		var d := _about(co,-1)
		var kinds := {}
		var box := AABB()
		var any := false
		for c: Node in co.get_children():
			var cs := c as CollisionShape3D
			if cs == null or cs.shape == null: continue
			var kind := cs.shape.get_class().trim_suffix("Shape3D").replace("Polygon","")
			kinds[kind] = int(kinds.get(kind,0))+1
			var bb := cs.global_transform*cs.shape.get_debug_mesh().get_aabb()
			box = bb if not any else box.merge(bb)
			any = true
		d["shapes"] = kinds
		d["box"] = box
		out.append(d)
	return out

## The AABB of every collision shape under `node`, world; in `node`'s own
## frame with `local` (a piece built off the tree has no global frame).
func collision_box(node: Node, local := false) -> AABB:
	var box := AABB()
	var any := false
	for c: Node in node.find_children("*","CollisionShape3D",true,false):
		var cs := c as CollisionShape3D
		if cs.shape == null: continue
		var x := cs.transform
		if local:
			var p := cs.get_parent()
			while p != node and p is Node3D:
				x = (p as Node3D).transform*x
				p = p.get_parent()
		else:
			x = cs.global_transform
		var bb := x*cs.shape.get_debug_mesh().get_aabb()
		box = bb if not any else box.merge(bb)
		any = true
	return box

## A hit (from `ray`, `pierce`, `what_is_at`, `colliders`) as one line;
## "miss" for {}.
func hit_text(h: Dictionary) -> String:
	if h.is_empty(): return "miss"
	var s := str(h.get("path","?"))
	if str(h.get("shape_type","")) != "": s += " (%s)" % str(h.shape_type)
	s += " layer %s mask %s" % [_bits(int(h.get("layer",0))),_bits(int(h.get("mask",0)))]
	if h.has("shape_node") and str(h.shape_node) != "": s += " shape %s" % str(h.shape_node).get_file()
	if h.has("position"): s += " at %s n %s d %.2f" % [str((h.position as Vector3).snapped(Vector3.ONE*0.01)),str((h.normal as Vector3).snapped(Vector3.ONE*0.01)),float(h.distance)]
	if h.has("shapes"): s += " shapes %s box %s" % [str(h.shapes),str(h.box)]
	return s

func _overlap(shape: Shape3D, at: Transform3D, mask: int, most: int, areas: bool) -> Array[Dictionary]:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = at
	q.collision_mask = mask
	q.collide_with_areas = areas
	var out: Array[Dictionary] = []
	var seen := {}
	# One line a shape (a trimesh can answer once a face it touches).
	for h: Dictionary in space().intersect_shape(q,most):
		var key := [h.get("rid"),int(h.get("shape",0))]
		if seen.has(key): continue
		seen[key] = true
		out.append(_about(h.get("collider"),int(h.get("shape",0))))
	return out

## What a hit's collider and shape index are: path, layers, shape type.
func _about(collider: Variant, shape: int) -> Dictionary:
	var out := {"collider":collider,"path":"","name":"","layer":0,"mask":0,"shape":shape,"shape_type":"","shape_node":""}
	if not (collider is Node): return out
	var n := collider as Node
	out.path = str(n.get_path()).trim_prefix(str(study.get_path())+"/") if study != null and study.is_ancestor_of(n) else str(n.get_path())
	out.name = str(n.name)
	if n is CollisionObject3D:
		var co := n as CollisionObject3D
		out.layer = co.collision_layer
		out.mask = co.collision_mask
		if shape >= 0:
			var rid := co.get_rid()
			var shapes := PhysicsServer3D.area_get_shape_count(rid) if co is Area3D else PhysicsServer3D.body_get_shape_count(rid)
			if shape < shapes:
				var srid := PhysicsServer3D.area_get_shape(rid,shape) if co is Area3D else PhysicsServer3D.body_get_shape(rid,shape)
				var t := PhysicsServer3D.shape_get_type(srid)
				out.shape_type = _SHAPE_TYPES[t] if t < _SHAPE_TYPES.size() else str(t)
				var holder: Object = co.shape_owner_get_owner(co.shape_find_owner(shape))
				if holder is Node: out.shape_node = str((holder as Node).name)
	return out

## Layer bits as their numbers, "1+16"; "-" for none.
static func _bits(v: int) -> String:
	var on := PackedStringArray()
	for i in 32:
		if v & (1 << i): on.append(str(i+1))
	if on.size() == 32: return "all"
	return "+".join(on) if not on.is_empty() else "-"

static func _rids(exclude: Array) -> Array[RID]:
	var out: Array[RID] = []
	for e: Variant in exclude:
		if e is RID: out.append(e)
		elif e is CollisionObject3D: out.append((e as CollisionObject3D).get_rid())
	return out

## A still of the window to `path` (a rendered run only; headless prints SKIP).
## The HUD's canvas layers are hidden for it unless `hud`; scaled to
## `size` if given (a window on a scaled display is bigger than asked).
func shot(path: String, hud := false, size := Vector2i.ZERO) -> void:
	if DisplayServer.get_name() == "headless":
		print("SKIP shot %s: headless" % path)
		return
	var hidden: Array[Node] = []
	if not hud:
		for c: Node in root.find_children("*","CanvasLayer",true,false):
			if c.visible:
				c.visible = false
				hidden.append(c)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if size != Vector2i.ZERO and image.get_size() != size: image.resize(size.x,size.y,Image.INTERPOLATE_LANCZOS)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := image.save_png(path)
	print("saved %s" % path if err == OK else "FAIL shot %s: error %d" % [path,err])
	for c in hidden: c.visible = true

# --- Reporting ----------------------------------------------------------------

func check(ok: bool, label: String, detail := "") -> bool:
	checks += 1
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label+("" if detail == "" else ": "+detail))
	return ok

func result(key: String, value: Variant) -> void:
	results[key] = value

## One line of a table (a seed, a knob's value): `ROW {json}`.
func row(values: Dictionary) -> void:
	print("ROW "+JSON.stringify(_plain(values)))

## A line tools/drive.py shows, the frame it was said at first.
func say(text: String) -> void:
	print("[f%d] %s" % [frame,text])

## A line tools/drive.py shows, as is (`| text`).
func note(text: String) -> void:
	print("| "+text)

func finish() -> void:
	if _done: return
	_done = true
	let_go()
	_print_result()
	LaunchArgs.set_override(null)
	quit(1 if failures > 0 else 0)

func _print_result() -> void:
	var out := results.duplicate()
	out["checks"] = checks
	out["failures"] = failures
	out["frames"] = frame
	out["seconds"] = snappedf((Time.get_ticks_msec()-_began)/1000.0,0.1)
	print("RESULT "+JSON.stringify(_plain(out)))

## Vectors as arrays, rounded, so the JSON reads back.
static func _plain(v: Variant) -> Variant:
	match typeof(v):
		TYPE_VECTOR2, TYPE_VECTOR2I: return [snappedf(v.x,0.001),snappedf(v.y,0.001)]
		TYPE_VECTOR3, TYPE_VECTOR3I: return [snappedf(v.x,0.001),snappedf(v.y,0.001),snappedf(v.z,0.001)]
		TYPE_FLOAT: return snappedf(v,0.0001)
		TYPE_DICTIONARY:
			var d := {}
			for k: Variant in v: d[str(k)] = _plain(v[k])
			return d
		TYPE_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_VECTOR3_ARRAY:
			var a := []
			for x: Variant in v: a.append(_plain(x))
			return a
		TYPE_OBJECT:
			return str(v)
	return v
