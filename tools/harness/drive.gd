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
## Index (`python tools/drive.py --api [word]` adds the docs; `--api --update` rewrites it):
##   The driver
##     drive() -> void
##   Args
##     arg(name, default = null) -> Variant
##     arg_int(name, default = 0) -> int
##     arg_float(name, default = 0.0) -> float
##     flag(name) -> bool
##     arg_vec3(name, default = Vector3.ZERO) -> Vector3
##     scene_args() -> PackedStringArray
##   The scene
##     open(scene, args = null, ready_frames = 3000) -> int
##     place(at, face = Vector2(0.0,-1.0)) -> void
##     go_to(key) -> void
##   Time
##     frames(n) -> void
##     physics_frames(n) -> void
##     until(cond, max_frames = 600) -> int
##   Input (the real path: actions the study reads)
##     hold(action, on = true, strength = 1.0) -> void
##     press(action, n = 1) -> void
##     let_go() -> void
##     stick(v) -> void
##     stick_toward(point) -> Vector2
##     walk_to(point, max_frames = 900, near = 0.6, jump_at = -1.0) -> bool
##     jump(n = 8) -> void
##     tap(key, n = 2, opts = {}) -> void
##   Scripted ticks (no input path: faster, but not the play loop)
##     scripted_ticks(n, want = Vector2.ZERO, jump_held = false) -> void
##     unscripted() -> void
##   Looking around
##     find(pattern, under = null) -> Array[Node]
##     first(pattern, under = null) -> Node
##   Collider probes
##     space() -> PhysicsDirectSpaceState3D
##     ray(from, to, mask = ALL_LAYERS, inside = false, exclude = [], areas = false) -> Dictionary
##     pierce(from, to, mask = ALL_LAYERS, most = 8, step = 0.05) -> Array[Dictionary]
##     what_is_at(pos, radius = 0.25, mask = ALL_LAYERS, most = 16, areas = false) -> Array[Dictionary]
##     what_is_in(box, mask = ALL_LAYERS, most = 16, areas = false) -> Array[Dictionary]
##     colliders(node) -> Array[Dictionary]
##     collision_box(node, local = false) -> AABB
##     hit_text(h) -> String
##   Shots
##     shot(path, hud = false, size = Vector2i.ZERO) -> void
##     shot_at(view, target, opts = {}) -> String
##     film(target, opts = {}) -> Dictionary
##     film_end(f, now = false) -> Dictionary
##     make_sheet(paths, out, cols = 2, width = 720) -> Error
##     mesh_box(tops) -> AABB
##     view_eye(view, box, ahead, him, fov = 50.0, dist = 1.0) -> Dictionary
##   Routes: walks through the real input
##     walk_leg(to, opts = {}) -> Dictionary
##     route(points, opts = {}) -> Dictionary
##     walk_paths(owner = null, offset = Vector3.ZERO, opts = {}) -> Dictionary
##   Watching an enemy
##     watch(enemy, opts = {}) -> Dictionary
##   Breaking (scripts/kit_isle/breakables.gd, spec docs/design/kit-breaks)
##     hubs() -> Array[Node]
##     hit(at, radius, strength = -1.0, source = &"olmec") -> int
##   Reporting
##     check(ok, label, detail = "") -> bool
##     result(key, value) -> void
##     row(values) -> void
##     say(text) -> void
##     note(text) -> void
##     finish() -> void
## (end of index)
##
## Typing: the project warns on untyped `:=` it can't infer, which is a
## parse error. Write `var d: Dictionary = x.get("k")`, never
## `var d := x.get("k")`; `study` and `motor` are Variants on purpose.

const LaunchArgs = preload("res://scripts/launch_args.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")
## One frame's time at --fixed-fps 60.
const DT := 1.0/60.0
## The actions a driver may hold; `let_go` releases them all.
const ACTIONS: Array[StringName] = [&"move_forward",&"move_back",&"move_left",&"move_right",
	&"walk_jump",&"walk_twirl",&"walk_crouch",&"walk_wind",&"telescope"]

## The scene `open` opened.
var study: Node = null
## Its pilot motor (scripts/pilot_motor.gd), if it has one: feet, grounded,
## velocity, stunned, knocks, jumps, size, run.
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
## Called after every frame `frames` steps (route's tracker, watch's log).
var _hooks: Array[Callable] = []
## Set by a watch whose time is up: a leg under way stops ("halted").
var _halt := false

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

## `arg` as an int.
func arg_int(name: String, default := 0) -> int:
	return int(arg(name,default))

## `arg` as a float.
func arg_float(name: String, default := 0.0) -> float:
	return float(arg(name,default))

## True if `--name` or `--name=...` was given (driver's or scene's).
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
		if not _hooks.is_empty():
			for h: Callable in _hooks.duplicate(): h.call()

## `n` physics frames, nothing else stepped by hand.
func physics_frames(n: int) -> void:
	for i in n: await physics_frame

## Frames until `cond` is true (at most `max_frames`): how many it took, or -1.
func until(cond: Callable, max_frames := 600) -> int:
	for i in max_frames + 1:
		if cond.call(): return i
		if i < max_frames: await frames(1)
	return -1

# --- Input (the real path: actions the study reads) --------------------------

## `action` held (at `strength`) or, with `on` false, released.
func hold(action: StringName, on := true, strength := 1.0) -> void:
	if on: Input.action_press(action,strength)
	else: Input.action_release(action)

## Pressed for `n` frames, then released.
func press(action: StringName, n := 1) -> void:
	hold(action)
	await frames(n)
	hold(action,false)

## Every action in ACTIONS released.
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

## A real key tap: pressed, held `n` frames, released, through
## Input.parse_input_event, so it reaches `_input` / `_unhandled_input`
## (where the studies read Space to board the parked plane, E to pick up,
## R to reset) and the actions mapped to it. `key` is a Key (KEY_SPACE) or
## an action name (its first key in the InputMap). `press`/`hold` only set
## an action's state, which no event handler sees. Opts: shift, ctrl, alt.
func tap(key: Variant, n := 2, opts := {}) -> void:
	var e := _key_event(key)
	if e == null:
		check(false,"tap %s" % key,"no key: give a Key or an action with a key")
		return
	e.shift_pressed = bool(opts.get("shift",false))
	e.ctrl_pressed = bool(opts.get("ctrl",false))
	e.alt_pressed = bool(opts.get("alt",false))
	e.pressed = true
	Input.parse_input_event(e)
	await frames(maxi(n,1))
	var up: InputEventKey = e.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	await frames(1)

func _key_event(key: Variant) -> InputEventKey:
	var e := InputEventKey.new()
	if key is int:
		e.keycode = key
		e.physical_keycode = key
		return e
	var action := StringName(str(key))
	if not InputMap.has_action(action): return null
	for ev: InputEvent in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var k := ev as InputEventKey
			var code := k.keycode if k.keycode != KEY_NONE else k.physical_keycode
			e.keycode = code
			e.physical_keycode = k.physical_keycode if k.physical_keycode != KEY_NONE else code
			return e
	return null

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

## Back to the input path after `scripted_ticks`.
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

## The first of `find(pattern)`, or null.
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

# --- Shots --------------------------------------------------------------------
#
#   await shot_at("side", motor)                                # him, framed by his size
#   await shot_at("three", first("Motif_"), {"out": "scratch/shots/well.png"})
#   await shot_at(Vector3(1, 0.4, 0), box, {"dist": 1.4})       # an AABB, a way of your own
#   await shot_at("side", motor, {"when": func() -> bool: return not motor.grounded})
#   await route(points)                     # the armed still is taken mid-jump, mid-route
#   var f := film(bird, {"view": "shoulder", "every": 6, "seconds": 3})
#   await watch(bird, {"frames": 240})
#   f = await film_end(f)                   # {shots: [paths], sheet: path}
#   [f120] saved scratch/shots/jump.png: side of him at (12.0, 3.1, -4.0), 3.6 m off
#   [f360] FILM bird shoulder: 30 stills every 6 frames, scratch/shots, sheet scratch/shots/bird_sheet.png
#
# A target is a Node3D (framed by the box of its visible meshes), `motor`
# or "him" (his figure), a pattern for `first`, a Vector3 (a point
# `radius` m round, default his height) or an AABB. The camera stands
# off it by its size: `dist` 1 fits it in the frame.
# Views: the world ones shot.py has (three, front, back, left, right, top,
# close), and ones that turn with him (his facing when the target is him,
# else the line from the target to him): side (square across it; the
# other side when a collider hides the target from the first), ahead
# (on it: his face, or the target from his side), behind, shoulder
# (behind him, over his shoulder, at the target), high (from above), play
# (the study's own camera, not moved). A Vector3 is a way out from the target.
# Opts, both:
#   out     the PNG (shot_at) or the prefix (film); default
#           captures/drive/<driver>_<n>_<view>
#   dist (1.0)  fov (50)  radius (a Vector3 target's, m)
#   with    a second target framed too (e.g. "him" with an enemy)
#   eye     a Vector3: the camera stands there;  offset: at target + offset (m)
#   size    Vector2i: the PNG's size (shot_at 1440 wide, film 640, both
#           shaped like the window)
#   hud     true: the HUD kept in (the play view only; the others are drawn
#           by a camera of their own, in a SubViewport, so the study's
#           camera stays current and whatever acts on it plays on)
#   when    Callable() -> bool: shot_at returns at once, armed, and takes
#           the still the first frame it is true, while a route() or
#           watch() plays; film starts then
# film only: every (6 frames), seconds (2.0) or count (stills), sheet
# (true: <out>_sheet.png, `cols` 4 wide), follow (true: the eye goes with
# the target; false: it stays and turns), turn (false: the view's way held
# from the first frame). A film runs in the frame hooks, so it goes on
# through whatever the driver awaits; film_end waits for it (or, `now`,
# stops it). finish() closes any film still open.
# Headless, both print one SKIP line and save nothing (shot_at returns "",
# film a finished film with no shots), so a driver runs either way.

## The world views (shot.py's): a way out from the target.
const VIEWS := {"three":Vector3(1.0,0.75,1.0),"front":Vector3(0.0,0.25,1.0),"back":Vector3(0.0,0.25,-1.0),
	"left":Vector3(-1.0,0.25,0.0),"right":Vector3(1.0,0.25,0.0),"top":Vector3(0.0,1.0,0.05),"close":Vector3(1.0,0.5,0.8)}
## The views that turn with him (see above).
const TURN_VIEWS: Array[String] = ["side","ahead","behind","shoulder","high"]
var _shots := 0
var _films: Array[Dictionary] = []
var _armed: Array[Dictionary] = []

## A still of the window to `path` (a rendered run only; headless prints SKIP).
## The HUD's canvas layers are hidden for it unless `hud`; scaled to
## `size` if given (a window on a scaled display is bigger than asked).
func shot(path: String, hud := false, size := Vector2i.ZERO) -> void:
	if _headless():
		print("SKIP shot %s: headless" % path)
		return
	var err := await _grab(path,hud,size)
	print("saved %s" % path if err == OK else "FAIL shot %s: error %d" % [path,err])

## A still of `target` from `view`, the camera placed by its size (opts
## above); the PNG's path ("" headless or failed). With `when`: armed.
func shot_at(view: Variant, target: Variant, opts := {}) -> String:
	_shots += 1
	var path := str(opts.get("out",_default_out(view,_shots)+".png"))
	if not path.ends_with(".png"): path += ".png"
	var what := "%s of %s" % [_view_name(view),_target_name(target)]
	if _headless():
		print("SKIP shot_at %s: headless has no pixels (drive.py --rendered)" % what)
		return ""
	if opts.has("when"):
		var cond: Callable = opts.when
		var st := {"hook":Callable(),"what":what}
		st.hook = func() -> void:
			if not cond.call(): return
			_hooks.erase(st.hook)
			_armed.erase(st)
			st.clear()
			_shot_now.call(view,target,opts,path,what)
		_hooks.append(st.hook)
		_armed.append(st)
		return path
	return await _shot_now(view,target,opts,path,what)

## Stills of `target` every few frames while the run goes on, the camera
## following it (opts above); `film_end` waits for it and its sheet.
func film(target: Variant, opts := {}) -> Dictionary:
	_shots += 1
	var view: Variant = opts.get("view","side")
	var every := maxi(1,int(opts.get("every",6)))
	var f := {"shots":[] as Array[String],"sheet":"","done":false,"what":"%s %s" % [_target_name(target),_view_name(view)],
		"view":view,"target":target,"opts":opts,"every":every,"out":str(opts.get("out",_default_out(view,_shots))).trim_suffix(".png"),
		"count":int(opts.get("count",ceili(float(opts.get("seconds",2.0))*60.0/every))),"started":false,"f0":0,
		"view_port":null,"rig":{},"hidden":[],"hook":Callable()}
	if _headless():
		print("SKIP film %s: headless has no pixels (drive.py --rendered)" % f.what)
		f.done = true
		return f
	var when: Callable = opts.get("when",Callable())
	f.hook = func() -> void: _film_tick(f,when)
	_hooks.append(f.hook)
	_films.append(f)
	return f

## Waits until film `f` has its stills (stops it at once with `now`), makes
## its sheet; returns it: {shots, sheet, done}.
func film_end(f: Dictionary, now := false) -> Dictionary:
	var most := int(f.count)*int(f.every)+1200
	while not bool(f.done) and not now and most > 0:
		await frames(1)
		most -= 1
	_film_close(f)
	return f

## A contact sheet: the PNGs at `paths` in a grid `cols` wide, each scaled
## to `width`, to `out`. An Error. (tools/harness/sheet.gd, shot.py --sheet.)
static func make_sheet(paths: Array, out: String, cols := 2, width := 720) -> Error:
	var images: Array[Image] = []
	for p: Variant in paths:
		var img := Image.load_from_file(ProjectSettings.globalize_path(String(p)))
		if img == null: continue
		img.convert(Image.FORMAT_RGB8)
		img.resize(width,int(round(float(img.get_height())*width/img.get_width())),Image.INTERPOLATE_LANCZOS)
		images.append(img)
	if images.is_empty(): return ERR_FILE_NOT_FOUND
	cols = clampi(cols,1,images.size())
	var rows := ceili(float(images.size())/cols)
	var cell_h := 0
	for img in images: cell_h = maxi(cell_h,img.get_height())
	var gap := 4
	var sheet := Image.create_empty(cols*width+(cols-1)*gap,rows*cell_h+(rows-1)*gap,false,Image.FORMAT_RGB8)
	sheet.fill(Color(0.1,0.1,0.1))
	for i in images.size():
		var img := images[i]
		sheet.blit_rect(img,Rect2i(Vector2i.ZERO,img.get_size()),Vector2i((i%cols)*(width+gap),(i/cols)*(cell_h+gap)))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out).get_base_dir())
	return sheet.save_png(out)

## The world box of the visible meshes under `tops`; sky domes, sea planes,
## particles and what is loose in the world's frame (`_loose`) left out.
## AABB() if none.
func mesh_box(tops: Array) -> AABB:
	var box := AABB()
	var any := false
	for top: Variant in tops:
		if not (top is Node) or not is_instance_valid(top): continue
		var meshes: Array[Node] = (top as Node).find_children("*","GeometryInstance3D",true,false)
		if top is GeometryInstance3D: meshes.append(top)
		for m: Node in meshes:
			var g := m as GeometryInstance3D
			if not g.is_visible_in_tree() or g is GPUParticles3D or g is CPUParticles3D: continue
			if _loose(g,top): continue
			var b := g.global_transform*g.get_aabb()
			if b.size.length() > 3000.0 or b.size.length() < 0.001: continue
			box = b if not any else box.merge(b)
			any = true
	return box if any else AABB()

## The camera for `view` of `box`: {eye, look}, by its size (shot.py's
## framing). `ahead`: the turning views' way (x, z); `him`: his box (shoulder).
func view_eye(view: Variant, box: AABB, ahead: Vector3, him: AABB, fov := 50.0, dist := 1.0) -> Dictionary:
	var middle := box.get_center()
	var radius := maxf(box.size.length()*0.5,0.3)
	var d := radius/tan(deg_to_rad(fov)*0.5)*dist*1.05
	var way: Vector3
	if view is Vector3: way = view
	else:
		match str(view):
			"side": way = ahead.cross(Vector3.UP)+Vector3.UP*0.25
			"ahead": way = ahead+Vector3.UP*0.25
			"behind": way = -ahead+Vector3.UP*0.3
			"high": way = -ahead*0.35+Vector3.UP
			"shoulder":
				# Behind him and up, looking past his head at the target.
				var hr := maxf(him.size.length()*0.5,0.3)
				var hc := him.get_center()
				if him.has_point(middle) or him.is_equal_approx(box):
					return {"eye":hc-ahead*hr*3.2*dist+Vector3.UP*hr*1.4*dist,"look":hc+ahead*hr*3.0}
				var line := Vector3(middle.x-hc.x,0.0,middle.z-hc.z).normalized()
				return {"eye":hc-line*hr*3.2*dist+Vector3.UP*hr*1.6*dist,"look":middle}
			"close":
				way = VIEWS.close
				d *= 0.6
			_: way = VIEWS.get(str(view),VIEWS.three)
	return {"eye":middle+way.normalized()*d,"look":middle}

## True if `g` is in the world's frame, not `top`'s: it or a parent under
## `top` is top_level (his puffs and ripples, a trail).
static func _loose(g: Node, top: Node) -> bool:
	var n := g
	while n != null and n != top:
		if n is Node3D and (n as Node3D).top_level: return true
		n = n.get_parent()
	return false

func _headless() -> bool:
	return DisplayServer.get_name() == "headless"

func _default_out(view: Variant, n: int) -> String:
	var me := (get_script() as Script).resource_path.get_file().get_basename()
	return "captures/drive/%s_%02d_%s" % [me,n,_view_name(view)]

static func _view_name(view: Variant) -> String:
	if view is Vector3: return "way(%.1f,%.1f,%.1f)" % [view.x,view.y,view.z]
	return str(view)

func _is_him(target: Variant) -> bool:
	if target is String: return target == "him"
	if typeof(target) != TYPE_OBJECT or not is_instance_valid(target): return false
	return (motor != null and is_same(target,motor)) or (study != null and is_same(target,study.get("figure")))

func _target_name(target: Variant) -> String:
	if _is_him(target): return "him"
	if target is AABB: return "a box %.1f m across" % (target as AABB).size.length()
	if target is Vector3: return "point %s" % _vtext(target)
	if target is Node:
		var n := str((target as Node).name)
		var sc: Script = (target as Node).get_script()
		return sc.resource_path.get_file().get_basename() if n.begins_with("@") and sc != null else n
	return str(target)

## His box: his figure's meshes, else his height round his feet.
func _him_box() -> AABB:
	var fig: Variant = study.get("figure") if study != null else null
	var box := mesh_box([fig]) if fig is Node else AABB()
	if box.size == Vector3.ZERO and motor != null:
		var h := 1.8*float(motor.size)
		box = AABB(Vector3(motor.feet)-Vector3(h*0.25,0.0,h*0.25),Vector3(h*0.5,h,h*0.5))
	return box

## The box a target is framed by (AABB() if it is gone).
func _box_of(target: Variant, opts: Dictionary) -> AABB:
	if _is_him(target): return _him_box()
	if target is AABB: return target
	if target is Vector3:
		var r := float(opts.get("radius",_him_box().size.y*0.5 if motor != null else 1.0))
		return AABB(target-Vector3.ONE*r,Vector3.ONE*r*2.0)
	var n: Variant = first(target) if target is String else target
	if not (n is Node3D) or not is_instance_valid(n): return AABB()
	var box := mesh_box([n])
	if box.size == Vector3.ZERO: box = AABB((n as Node3D).global_position-Vector3.ONE*0.5,Vector3.ONE)
	return box

## The turning views' way: his facing, or from the target to him.
func _ahead_of(target: Variant, middle: Vector3) -> Vector3:
	if motor == null: return Vector3.BACK
	if _is_him(target):
		var f2: Vector2 = PilotMotor.forward(float(motor.facing))
		return Vector3(f2.x,0.0,f2.y)
	var d := Vector3(motor.feet.x-middle.x,0.0,motor.feet.z-middle.z)
	return d.normalized() if d.length() > 0.01 else Vector3.BACK

## The eye and look for `view` of `target` now; `rig` keeps the turning
## way once set (`ahead`) and the size (`radius`), for a film.
func _aim(cam: Camera3D, view: Variant, target: Variant, opts: Dictionary, rig: Dictionary) -> bool:
	var box := _box_of(target,opts)
	if box.size == Vector3.ZERO: return false
	if opts.has("with"):
		var w := _box_of(opts.with,opts)
		if w.size != Vector3.ZERO: box = box.merge(w)
	if rig.has("half"):
		# A film: the size held from its first frame, the middle eased.
		var mid: Vector3 = (rig.mid as Vector3).lerp(box.get_center(),0.5)
		rig.mid = mid
		box = AABB(mid-rig.half,rig.half*2.0)
	var ahead: Vector3 = rig.get("ahead",_ahead_of(target,box.get_center()))
	var at: Dictionary
	if opts.has("eye"): at = {"eye":opts.eye,"look":box.get_center()}
	elif opts.has("offset"): at = {"eye":box.get_center()+(opts.offset as Vector3),"look":box.get_center()}
	else:
		var him := _him_box() if motor != null else box
		var fov := float(opts.get("fov",50.0))
		var dist := float(opts.get("dist",1.0))
		at = view_eye(view,box,ahead,him,fov,dist)
		if str(view) == "side" and not rig.has("flip"):
			# Stone between the eye and what it frames: the other side, if
			# that one is clear (a film decides once).
			rig.flip = _hidden_from(at.eye,target,opts) and not _hidden_from(view_eye(view,box,-ahead,him,fov,dist).eye,target,opts)
		if bool(rig.get("flip",false)): at = view_eye(view,box,-ahead,him,fov,dist)
	if rig.has("eye_fixed"): at.eye = rig.eye_fixed
	var eye: Vector3 = at.eye
	var look: Vector3 = at.look
	if eye.is_equal_approx(look): return false
	var up := Vector3.UP if absf((look-eye).normalized().y) < 0.99 else Vector3.BACK
	cam.fov = float(opts.get("fov",50.0))
	cam.far = maxf(4000.0,eye.distance_to(look)*4.0)
	cam.look_at_from_position(eye,look,up)
	rig.eye_now = eye
	rig.look_now = look
	return true

## True if a collider stands between `eye` and the target (or `with`).
func _hidden_from(eye: Vector3, target: Variant, opts: Dictionary) -> bool:
	for t: Variant in [target,opts.get("with")]:
		if t == null: continue
		var b := _box_of(t,opts)
		if b.size == Vector3.ZERO: continue
		var p := b.get_center()
		var h := ray(eye,p)
		if not h.is_empty() and float(h.distance) < eye.distance_to(p)-b.size.length()*0.5: return true
	return false

## A view of the world of its own (a SubViewport on the same World3D), so
## the study's camera stays current: enemies that act on what the camera
## sees play on as they would. Its camera takes the play
## camera's environment, attributes and cull mask; the window's AA.
func _cap_view(label: String, size: Vector2i) -> SubViewport:
	var sv := SubViewport.new()
	sv.name = label
	sv.size = size
	sv.world_3d = root.find_world_3d()
	sv.msaa_3d = root.msaa_3d
	sv.screen_space_aa = root.screen_space_aa
	sv.use_taa = root.use_taa
	sv.use_debanding = root.use_debanding
	sv.scaling_3d_mode = root.scaling_3d_mode
	sv.scaling_3d_scale = root.scaling_3d_scale
	sv.mesh_lod_threshold = root.mesh_lod_threshold
	sv.positional_shadow_atlas_size = root.positional_shadow_atlas_size
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var cam := Camera3D.new()
	var play := root.get_camera_3d()
	if play != null:
		cam.environment = play.environment
		cam.attributes = play.attributes
		cam.cull_mask = play.cull_mask
		cam.near = minf(play.near,0.05)
	sv.add_child(cam)
	root.add_child(sv)
	cam.make_current()
	return sv

func _cap_cam(sv: SubViewport) -> Camera3D:
	return sv.get_child(0) as Camera3D

func _shot_now(view: Variant, target: Variant, opts: Dictionary, path: String, what: String) -> String:
	var rig := {}
	var err := OK
	if str(view) == "play":
		var size: Vector2i = opts.get("size",Vector2i(1440,0))
		err = await _grab(path,bool(opts.get("hud",false)),size)
	else:
		var sv := _cap_view("HarnessShotAt",_cap_size(opts,Vector2i(1440,900)))
		if not _aim(_cap_cam(sv),view,target,opts,rig):
			sv.queue_free()
			check(false,"shot_at "+what,"nothing to frame (gone, or no visible meshes)")
			return ""
		# Two draws: the first fills the temporal AA's history.
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := sv.get_texture().get_image()
		sv.queue_free()
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
		err = img.save_png(path)
	if err != OK:
		check(false,"shot_at "+what,"saving %s: error %d" % [path,err])
		return ""
	var off := ""
	if rig.has("eye_now"): off = ", %.1f m off" % (rig.eye_now as Vector3).distance_to(rig.look_now)
	var where := " at "+_vtext(rig.look_now) if rig.has("look_now") else ""
	say("saved %s: %s%s%s" % [path,what,where,off])
	return path

## `opts.size`, else `fallback`, shaped like the window.
func _cap_size(opts: Dictionary, fallback: Vector2i) -> Vector2i:
	if opts.has("size"): return opts.size
	var win := root.get_visible_rect().size
	if win.x <= 0.0: return fallback
	return Vector2i(fallback.x,int(round(fallback.x*win.y/win.x)))

func _film_tick(f: Dictionary, when: Callable) -> void:
	if bool(f.done): return
	var opts: Dictionary = f.opts
	if not bool(f.started):
		if when.is_valid() and not when.call(): return
		f.started = true
		f.f0 = frame
		if str(f.view) != "play":
			var sv := _cap_view("HarnessFilm",_cap_size(opts,Vector2i(640,400)))
			var box := _box_of(f.target,opts)
			if opts.has("with"): box = box.merge(_box_of(opts.with,opts))
			var rig := {"half":box.size*0.5,"mid":box.get_center()}
			if not bool(opts.get("turn",false)): rig.ahead = _ahead_of(f.target,box.get_center())
			if box.size == Vector3.ZERO or not _aim(_cap_cam(sv),f.view,f.target,opts,rig):
				sv.queue_free()
				check(false,"film "+str(f.what),"nothing to frame (gone, or no visible meshes)")
				_film_close(f)
				return
			if not bool(opts.get("follow",true)): rig.eye_fixed = rig.eye_now
			f.view_port = sv
			f.rig = rig
		elif not bool(opts.get("hud",false)):
			for c: Node in root.find_children("*","CanvasLayer",true,false):
				if c.visible:
					c.visible = false
					(f.hidden as Array).append(c)
		return
	# What is drawn now is from the camera set a frame ago.
	var n := frame-int(f.f0)
	if (n-1) % int(f.every) == 0:
		var shots: Array[String] = f.shots
		var path := "%s_%03d.png" % [f.out,shots.size()]
		var img: Image
		if f.get("view_port") != null: img = (f.view_port as SubViewport).get_texture().get_image()
		else:
			img = root.get_texture().get_image()
			var size := _cap_size(opts,Vector2i(640,400))
			if img.get_size() != size: img.resize(size.x,size.y,Image.INTERPOLATE_BILINEAR)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
		if img.save_png(path) == OK: shots.append(path)
		if shots.size() >= int(f.count):
			_film_close(f)
			return
	if f.get("view_port") != null and not _aim(_cap_cam(f.view_port),f.view,f.target,opts,f.rig):
		say("film %s: the target is gone" % f.what)
		_film_close(f)

func _film_close(f: Dictionary) -> void:
	if bool(f.get("closed",false)): return
	f.closed = true
	f.done = true
	_hooks.erase(f.hook)
	f.hook = Callable()
	_films.erase(f)
	for c: Variant in f.get("hidden",[]):
		if is_instance_valid(c): (c as Node).set("visible",true)
	if f.get("view_port") != null and is_instance_valid(f.view_port): (f.view_port as Node).queue_free()
	f.view_port = null
	var shots: Array[String] = f.shots
	if shots.is_empty():
		if not _headless(): say("FILM %s: no stills (%s)" % [f.what,"it never began" if not bool(f.started) else "none saved"])
		return
	if bool(f.opts.get("sheet",true)) and shots.size() > 1:
		var sheet := str(f.out)+"_sheet.png"
		var cols := int(f.opts.get("cols",mini(4,shots.size())))
		if make_sheet(shots,sheet,cols,int(f.opts.get("cell",480))) == OK: f.sheet = sheet
	say("FILM %s: %d stills every %d frames, %s%s" % [f.what,shots.size(),f.every,shots[0].get_base_dir(),
		", sheet "+str(f.sheet) if str(f.sheet) != "" else ""])

## The window's last frame to `path`, the HUD hidden unless `hud`; `size`
## (y 0: that width at most, the shape kept).
func _grab(path: String, hud: bool, size: Vector2i) -> Error:
	var hidden: Array[Node] = []
	if not hud:
		for c: Node in root.find_children("*","CanvasLayer",true,false):
			if c.visible:
				c.visible = false
				hidden.append(c)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if size.y == 0 and size.x > 0 and image.get_width() > size.x:
		image.resize(size.x,int(round(float(image.get_height())*size.x/image.get_width())),Image.INTERPOLATE_LANCZOS)
	elif size.y > 0 and image.get_size() != size: image.resize(size.x,size.y,Image.INTERPOLATE_LANCZOS)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
	var err := image.save_png(path)
	for c in hidden: if is_instance_valid(c): c.visible = true
	return err

# --- Routes: walks through the real input -------------------------------------
#
#   var r := await route([study.start, Vector2(76, 0), {"to": Vector3(52, 12, 8), "jump": "long"}], {"name": "hill"})
#   check(r.ok, "up the hill", r.why)
#   [f412] LEG hill 1/2 ok 3.4 s to (76.0, 0.0) at (76.1, 34.5, 0.2) jumps 1 drops [1.2] stuns 0 knocks 0 set back 0 stuck 0
#   [f655] ROUTE hill FAIL 1/2 legs in 10.9 s at (60.3, 30.0, 4.1) drops [1.2] stuns 0 knocks 0 set back 0 (leg 2: stuck)
#
# A point is a Vector3 (there: within `near` across and `up` in height), a
# Vector2 (x, z: any height) or a Dictionary {to, ...leg opts}. He is set
# down at the first point (facing the second); every leg after is the stick
# and the jump button, nothing teleported. Leg opts (a route's opts are
# each leg's defaults):
#   near  m across that counts as there (0.7)     pace  the stick's share (1 run, 0.5 walk)
#   up    m of height that counts (2 pumps)       most  frames before it gives up (1500)
#   jump  "auto": at a lip unless the point is below him, and at a wall he
#         can catch; "lip": at every lip; "long": a long jump at lips;
#         "drop": walk off lips (walls still); "none"
# Grounded and not moving for 40 frames, he jumps (counted in `stuck`);
# hanging on a lip, he pushes in to climb and jumps now and then.
# Route opts: name, place (true; false: start from where he is), go_on
# (false: stop at the first failed leg), rows (false: a ROW per leg too, for
# sweep.py). A leg returns {ok, why ("", "set back", "stuck", "timeout",
# "halted"), s, frames, to, feet, left (m across still to go), jumps, drops
# (m below the ground he left, each over a hop, motor.jumps[0]), stuns,
# knocks, set_back (moved further in a frame than he could travel: set back
# after a fall, gulped, carried), stuck}. A route returns {name, ok, why,
# legs (passed), of, failed_at, s, frames, feet, drops, stuns, knocks,
# set_back, each (the legs)}.

## Walks him to `to` through the stick, jumping at lips and walls (opts above).
func walk_leg(to: Variant, opts := {}) -> Dictionary:
	var goal := _route_point(to)
	var flat := is_nan(goal.y)
	var near := float(opts.get("near",0.7))
	var up := float(opts.get("up",2.0*float(motor.jumps[1])))
	var most := int(opts.get("most",1500))
	var pace := float(opts.get("pace",1.0))
	var how := str(opts.get("jump","auto"))
	var hop := float(motor.jumps[0])
	var reach := float(motor.jumps[1])+float(motor.hang_drop)+PilotMotor.GRAB_LOW
	var t := {"jumps":0,"drops":[],"stuns":0,"set_back":0,"stuck":0,"knocks0":int(motor.knocks),
		"was_ground":true,"left_y":float(motor.feet.y),"was_stun":false,"last":Vector3(motor.feet),"speed":0.0}
	var tracker := func() -> void: _leg_track(t,hop)
	_hooks.append(tracker)
	var f0 := frame
	var out := {"ok":false,"why":"timeout"}
	var still := 0
	var hung := 0
	var cool := 0
	var check_at := Vector3(motor.feet)
	var last := Vector3(motor.feet)
	var moved_lately := INF
	var g2 := Vector2(goal.x,goal.z)
	for i in most:
		if _halt:
			out.why = "halted"
			break
		if int(t.set_back) > 0:
			out.why = "set back"
			break
		var feet: Vector3 = motor.feet
		var at := Vector2(feet.x,feet.z)
		var standing: bool = motor.grounded or motor.swimming
		if at.distance_to(g2) <= near and standing and (flat or absf(feet.y-goal.y) <= up):
			out.ok = true
			out.why = ""
			break
		if i % 120 == 119:
			moved_lately = feet.distance_to(check_at)
			check_at = feet
		var aim := Vector3(goal.x,feet.y,goal.z)
		stick(stick_toward(aim)*pace)
		cool -= 1
		if str(motor.hold) == "hang":
			# On a lip: push in to climb; now and then a jump (up and over).
			hung += 1
			if hung % 60 == 40:
				t.jumps = int(t.jumps)+1
				await press(&"walk_jump",4)
				continue
			if hung > 360:
				out.why = "stuck"
				break
		else:
			hung = 0
		if motor.grounded and cool <= 0 and not motor.seized():
			still = still+1 if feet.distance_to(last) < 0.02*float(motor.size) else 0
			if still > 40:
				still = 0
				t.stuck = int(t.stuck)+1
				t.jumps = int(t.jumps)+1
				cool = 20
				await press(&"walk_jump",14)
				continue
			if how != "none" and at.distance_to(g2) > near:
				var dir2 := (g2-at).normalized()
				var dir := Vector3(dir2.x,0.0,dir2.y)
				var probe := float(motor.size)*(0.6 if how == "long" else 0.3)
				var ahead := feet+dir*probe
				# A wall he can catch: ground ahead over a step and under his reach.
				var top := _floor_y(feet+dir*float(motor.size)*0.5,reach+0.1,-PilotMotor.STEP_UP-0.05)
				if top > feet.y+PilotMotor.STEP_UP+0.05:
					t.jumps = int(t.jumps)+1
					cool = 20
					await press(&"walk_jump",14)
					continue
				# A lip: no ground a hop down ahead.
				var low := _floor_y(ahead,PilotMotor.STEP_UP,hop)
				var wants := how == "lip" or how == "long" or (how == "auto" and (flat or goal.y > feet.y-hop))
				if low == -INF and wants and at.distance_to(g2) > near*2.0:
					t.jumps = int(t.jumps)+1
					cool = 20
					if how == "long":
						hold(&"walk_crouch")
						await frames(3)
						await press(&"walk_jump",6)
						hold(&"walk_crouch",false)
					else:
						await press(&"walk_jump",12)
					continue
		last = Vector3(motor.feet)
		await frames(1)
	stick(Vector2.ZERO)
	_hooks.erase(tracker)
	if out.why == "timeout" and moved_lately < float(motor.size): out.why = "stuck"
	var fin: Vector3 = motor.feet
	var shown: Variant = goal
	if flat: shown = Vector2(goal.x,goal.z)
	out.merge({"s":snappedf((frame-f0)/60.0,0.01),"frames":frame-f0,"to":shown,
		"feet":fin,"left":snappedf(Vector2(fin.x,fin.z).distance_to(g2),0.01),"jumps":t.jumps,"drops":t.drops,
		"stuns":t.stuns,"knocks":int(motor.knocks)-int(t.knocks0),"set_back":t.set_back,"stuck":t.stuck})
	return out

## Walks `points` in order (opts above); a LEG line each, a ROUTE line, and its summary.
func route(points: Array, opts := {}) -> Dictionary:
	var name := str(opts.get("name","route"))
	var n := points.size()
	var legs: Array = []
	var f0 := frame
	var first := 0
	if bool(opts.get("place",true)) and n > 0:
		var p0 := _route_point(points[0])
		if is_nan(p0.y): p0.y = _top_y(p0)
		var face := Vector2(0.0,-1.0)
		if n > 1:
			var p1 := _route_point(points[1])
			var d := Vector2(p1.x-p0.x,p1.z-p0.z)
			if d.length() > 0.01: face = d.normalized()
		await place(p0+Vector3.UP*0.05,face)
		# A study that holds him at its own start on its first ticks (the
		# motif yard) moves him back there once: set down again.
		await frames(2)
		if Vector3(motor.feet).distance_to(p0) > float(motor.size): await place(p0+Vector3.UP*0.05,face)
		first = 1
	var sum := {"name":name,"ok":true,"why":"","legs":0,"of":n-first,"failed_at":-1,"drops":[],"stuns":0,"knocks":0,"set_back":0}
	for i in range(first,n):
		var o: Dictionary = opts.duplicate()
		var to: Variant = points[i]
		if to is Dictionary:
			o.merge(to,true)
			to = (to as Dictionary).get("to")
		var r := await walk_leg(to,o)
		r["leg"] = i
		legs.append(r)
		say("LEG %s %d/%d %s" % [name,i-first+1,n-first,_leg_text(r)])
		if bool(opts.get("rows",false)):
			var line := {"route":name,"leg":i}
			line.merge(r,false)
			row(line)
		(sum.drops as Array).append_array(r.drops)
		for k: String in ["stuns","knocks","set_back"]: sum[k] = int(sum[k])+int(r[k])
		if r.ok: sum.legs = int(sum.legs)+1
		elif int(sum.failed_at) < 0:
			sum.ok = false
			sum.why = r.why
			sum.failed_at = i-first+1
			if not bool(opts.get("go_on",false)): break
		if _halt: break
	sum.merge({"s":snappedf((frame-f0)/60.0,0.01),"frames":frame-f0,"feet":Vector3(motor.feet),"each":legs})
	say("ROUTE %s %s %d/%d legs in %.1f s at %s drops %s stuns %d knocks %d set back %d%s" % [name,"ok" if sum.ok else "FAIL",sum.legs,sum.of,sum.s,
		_vtext(sum.feet),str(sum.drops),sum.stuns,sum.knocks,sum.set_back,"" if sum.ok else " (leg %d: %s)" % [sum.failed_at,sum.why]])
	return sum

## Walks each named path of `owner` (an object or script with `walks()` ->
## {name: [points]}, else its worn `paths()` -> [[Vector2...]]), moved by
## `offset`; `opts.only` picks one name. A route each: {name: summary}.
func walk_paths(owner: Variant = null, offset := Vector3.ZERO, opts := {}) -> Dictionary:
	var src: Variant = owner if owner != null else study
	var named := {}
	if _has_func(src,"walks"):
		named = (src as Object).call("walks")
	elif _has_func(src,"paths"):
		var worn: Array = (src as Object).call("paths")
		for i in worn.size(): named["path%d" % i] = worn[i]
	if named.is_empty(): note("walk_paths: %s has no walks() or paths()" % str(src))
	var out := {}
	for k: Variant in named:
		if opts.has("only") and str(opts.only) != str(k): continue
		var pts: Array = []
		for p: Variant in named[k]:
			if p is Dictionary:
				var d: Dictionary = (p as Dictionary).duplicate()
				d.to = _moved(d.get("to"),offset)
				pts.append(d)
			else:
				pts.append(_moved(p,offset))
		var o: Dictionary = opts.duplicate()
		o.name = str(k)
		out[str(k)] = await route(pts,o)
	return out

## `name` callable on `src`: an object's method, or a script's static func.
static func _has_func(src: Variant, name: String) -> bool:
	if not (src is Object): return false
	if src is Script:
		for m: Dictionary in (src as Script).get_script_method_list():
			if str(m.name) == name: return true
		return false
	return (src as Object).has_method(name)

func _moved(p: Variant, offset: Vector3) -> Variant:
	if p is Vector2: return (p as Vector2)+Vector2(offset.x,offset.z)
	return (p as Vector3)+offset

## A route point as a Vector3; y is NAN for a Vector2 (any height).
func _route_point(p: Variant) -> Vector3:
	if p is Dictionary: p = (p as Dictionary).get("to")
	if p is Vector2: return Vector3((p as Vector2).x,NAN,(p as Vector2).y)
	return p as Vector3

## The walkable ground's mask (the study's ground, else every layer).
func _ground_mask() -> int:
	var g: Variant = study.get("ground") if study != null else null
	return int(g.get("mask")) if g is Object and g.get("mask") != null else ALL_LAYERS

## The ground's y under `p` from `above` m over it down to `below` m under
## it (`below` negative: stop over it), or -INF.
func _floor_y(p: Vector3, above: float, below: float) -> float:
	var h := ray(p+Vector3.UP*above,p-Vector3.UP*below,_ground_mask())
	return float((h.position as Vector3).y) if not h.is_empty() and (h.normal as Vector3).y > 0.5 else -INF

## The top ground at (x, z) of `p` (for a Vector2 start), his feet's y if none.
func _top_y(p: Vector3) -> float:
	var h := ray(Vector3(p.x,motor.feet.y+400.0,p.z),Vector3(p.x,motor.feet.y-400.0,p.z),_ground_mask())
	return float((h.position as Vector3).y) if not h.is_empty() else float(motor.feet.y)

## Per frame in a leg: drops (from the ground left), stuns, set-backs.
func _leg_track(t: Dictionary, hop: float) -> void:
	var feet: Vector3 = motor.feet
	var v: Vector3 = motor.velocity
	# Set back (after a fall, a gulp, a carry): a jump no speed he had could make.
	var moved := feet.distance_to(t.last)
	var set_back := moved > maxf(float(t.speed),v.length())*DT*3.0+float(motor.size)
	if set_back: t.set_back = int(t.set_back)+1
	t.speed = v.length()
	var g: bool = motor.grounded or str(motor.hold) != "" or motor.swimming
	if g and not bool(t.was_ground) and not set_back:
		var d := float(t.left_y)-feet.y
		if d > hop: (t.drops as Array).append(snappedf(d,0.01))
	if g: t.left_y = feet.y
	t.was_ground = g
	var s := str(motor.stunned) != ""
	if s and not bool(t.was_stun): t.stuns = int(t.stuns)+1
	t.was_stun = s
	t.last = feet

func _leg_text(r: Dictionary) -> String:
	var to: Variant = r.to
	return "%s %.1f s to %s at %s jumps %d drops %s stuns %d knocks %d set back %d stuck %d%s" % ["ok" if r.ok else "FAIL",r.s,_vtext(to),_vtext(r.feet),
		r.jumps,str(r.drops),r.stuns,r.knocks,r.set_back,r.stuck,"" if r.ok else " (%s, %.1f m left)" % [r.why,r.left]]

## A vector rounded to 0.1 for a line.
static func _vtext(p: Variant) -> String:
	if p is Vector3: return "(%.1f, %.1f, %.1f)" % [p.x,p.y,p.z]
	if p is Vector2: return "(%.1f, %.1f)" % [p.x,p.y]
	return str(p)

# --- Watching an enemy ---------------------------------------------------------
#
#   var w := await watch(bird, {"pilot": "dodge", "dodge_on": ["stoop"], "frames": 240})
#   [f337] bird fold d 4.2 dy 4.9 at (45.8, 49.8, -112.4) | hunger 3.00 strikes 0 last_strike "" | him (42.6, 44.9, -109.7) still knocks 0
#   [f372] bird state fold->stoop, dives 0->1 d 4.7 dy 4.7 ...        (a change: a line at once)
#   [f391] bird state stoop->carry, strikes 0->1, last_strike ""->snatch d 0.5 ... | him (..) air tumble STUN knock knocks 1
#   [f576] WATCH bird 240 frames, 4 changes, closest 0.0 m, states { "fold": 35, "stoop": 19, ... }, knocks 2 stuns 1 set back 0
#
# `enemy`: a Node, or a pattern for `first` (name, class or script path).
# It reads, where the enemy has them, WATCH_FIELDS (a field, or a method
# with no args): the state ones first, then awareness and counts. Opts:
#   frames  how long (600)          every  a line every N frames (30; 0: changes only)
#   fields  more: names, or {name: Callable(enemy) -> value}
#   only    true: just `fields`, not WATCH_FIELDS
#   at      Callable(enemy) -> Vector3, where it is (default its `head()` if
#           that's a Vector3, else its global_position)
#   pilot   "stand", "toward", "flee", "dodge", an Array of route points
#           (walked from where he is), or a Callable(enemy) called each frame
#           (steer him yourself). Default --pilot=, else "stand".
#   dodge_on  the state values he dodges on (default: within dodge_at m)
#   dodge_at  m (default half a second of his run)
#   until   Callable() -> bool: stop when true
#   pilot_at, enemy_at  Vector3s to set them at first (default --pilot-at=,
#           --enemy-at=); the enemy's `home` moves with it if it has one
#   wake    a method of the enemy called at the start (e.g. "wake")
#   label   the name in its lines (its node name, else its script's file)
#   row     true: a closing `ROW {watch, pilot, frames, changes, closest,
#           knocks, stuns, set_back, hearts_lost, state (the one held
#           longest), last_state}` for tools/sweep.py; a Dictionary: those
#           and its own columns (e.g. {"trial": t}). Default --watch-row.
# Change lines come for any field whose value is a String, bool or int. If
# the study makes its enemies again (a reset after a fall), it goes on with
# the new one of the same script. Returns {frames, changes, closest, states
# {value: frames}, knocks, stuns, set_back, hearts_lost (-1 with no run),
# last (the last values), route (if walked)}.

## What `watch` reads when an enemy has it.
const WATCH_FIELDS: Array[String] = ["state","act","stage","mode","awareness","aware","alert","hunting","seen",
	"exposure","hunger","gap_to_him","strikes","hits","snaps","blows","misses","catches","spots","last_strike"]

## Logs `enemy` over time while he does `opts.pilot` (opts above).
func watch(enemy: Variant, opts := {}) -> Dictionary:
	var e: Node = null
	if typeof(enemy) == TYPE_OBJECT:
		if is_instance_valid(enemy): e = enemy
	else:
		e = first(str(enemy))
	if e == null:
		check(false,"watch %s" % str(enemy),"no such node (freed? a study's place() can make its enemies again)")
		return {}
	var label := str(opts.get("label",e.name))
	if label.begins_with("@") and e.get_script() != null: label = (e.get_script() as Script).resource_path.get_file().get_basename()
	var pilot_at: Variant = opts.get("pilot_at",arg_vec3("pilot-at",Vector3.INF))
	var enemy_at: Variant = opts.get("enemy_at",arg_vec3("enemy-at",Vector3.INF))
	if pilot_at is Vector3 and pilot_at != Vector3.INF:
		var to := _watch_at(e,opts)
		var kind: Script = e.get_script()
		await place(pilot_at,Vector2(to.x-pilot_at.x,to.z-pilot_at.z).normalized())
		# A study's place() may make its enemies again: the same kind, found anew.
		if not is_instance_valid(e) and kind != null: e = first(kind.resource_path)
		if e == null:
			check(false,"watch %s" % label,"gone after placing him")
			return {}
	if enemy_at is Vector3 and enemy_at != Vector3.INF and e is Node3D:
		(e as Node3D).global_position = enemy_at
		if "home" in e and e.get("home") is Vector3: e.set("home",enemy_at)
	if opts.has("wake") and e.has_method(str(opts.wake)): e.call(str(opts.wake))
	var names: Array[String] = []
	if not bool(opts.get("only",false)):
		for k in WATCH_FIELDS:
			if k in e or (e.has_method(k) and e.get_method_argument_count(k) == 0): names.append(k)
	var extra: Dictionary = {}
	var more: Variant = opts.get("fields",[])
	if more is Dictionary: extra = more
	else:
		for k: Variant in more:
			if not str(k) in names: names.append(str(k))
	var every := int(opts.get("every",30))
	var most := int(opts.get("frames",600))
	var until_fn: Callable = opts.get("until",Callable())
	var w := {"f0":frame,"was":{},"changes":0,"closest":INF,"states":{},"knocks0":int(motor.knocks),"stuns":0,
		"was_stun":false,"hearts0":_hearts(),"done":false,"last":{},"e":e,"kind":e.get_script(),"set_back":0,
		"feet":Vector3(motor.feet),"speed":0.0}
	var hook := func() -> void:
		if bool(w.done): return
		if not is_instance_valid(w.e):
			# Made again (a study's reset after he fell) or gone for good.
			var again: Node = first((w.kind as Script).resource_path) if w.kind != null else null
			if again == null:
				say("%s gone" % label)
				w.done = true
				_halt = true
				return
			w.e = again
			say("%s made again (the study reset it)" % label)
		var it: Node = w.e
		var feet0: Vector3 = w.feet
		if Vector3(motor.feet).distance_to(feet0) > maxf(float(w.speed),motor.velocity.length())*DT*3.0+float(motor.size):
			w.set_back = int(w.set_back)+1
			say("%s: he was set back (a fall, a gulp, a carry) to %s" % [label,_vtext(motor.feet)])
		w.feet = Vector3(motor.feet)
		w.speed = motor.velocity.length()
		var now := _peek(it,names,extra)
		var at := _watch_at(it,opts)
		var feet: Vector3 = motor.feet
		var d := Vector2(at.x-feet.x,at.z-feet.z).length()
		w.closest = minf(float(w.closest),d)
		if not names.is_empty():
			var st := str(now.get(names[0],""))
			w.states[st] = int((w.states as Dictionary).get(st,0))+1
		var s := str(motor.stunned) != ""
		if s and not bool(w.was_stun): w.stuns = int(w.stuns)+1
		w.was_stun = s
		var changed: Array[String] = []
		var was: Dictionary = w.was
		for k: String in now:
			var v: Variant = now[k]
			if not was.is_empty() and typeof(v) in [TYPE_STRING,TYPE_STRING_NAME,TYPE_BOOL,TYPE_INT] and str(was.get(k)) != str(v):
				changed.append("%s %s->%s" % [k,_fmt(was.get(k)),_fmt(v)])
		var n := frame-int(w.f0)
		if not changed.is_empty(): w.changes = int(w.changes)+1
		if not changed.is_empty() or (every > 0 and n % every == 0) or was.is_empty():
			say(_watch_line(label,now,names,changed,at,d))
		w.was = now
		w.last = now
		if n >= most or (until_fn.is_valid() and bool(until_fn.call())):
			w.done = true
			_halt = true
	_hooks.append(hook)
	var mode: Variant = opts.get("pilot",arg("pilot","stand"))
	var walked: Dictionary = {}
	var dodge_on: Array = opts.get("dodge_on",[])
	var dodge_at := float(opts.get("dodge_at",float(motor.run)*0.5))
	var dodge_way := Vector3.ZERO
	var dodge_t := 0
	var flee_way := Vector3.ZERO
	if mode is Array:
		var ro := {"name":label+" walk","place":false}
		walked = await route(mode,ro)
		while not bool(w.done):
			stick(Vector2.ZERO)
			await frames(1)
	else:
		while not bool(w.done):
			if not is_instance_valid(w.e):
				await frames(1)
				continue
			e = w.e
			var at := _watch_at(e,opts)
			var feet: Vector3 = motor.feet
			var d := Vector2(at.x-feet.x,at.z-feet.z).length()
			if mode is Callable:
				(mode as Callable).call(e)
			else:
				match str(mode):
					"toward": stick(stick_toward(at))
					"flee":
						if flee_way == Vector3.ZERO or (frame-int(w.f0)) % 15 == 0: flee_way = _flee_way(at)
						stick(stick_toward(feet+flee_way*4.0))
					"dodge":
						var st := str(_peek(e,names.slice(0,1),{}).get(names[0],"")) if not names.is_empty() else ""
						var go := (st in dodge_on) if not dodge_on.is_empty() else d < dodge_at
						if go and dodge_way == Vector3.ZERO:
							dodge_way = _dodge_way(at)
							dodge_t = frame
							say("%s: he dodges %s (%s, %.1f m)" % [label,_vtext(dodge_way),st,d])
						if dodge_way != Vector3.ZERO:
							stick(stick_toward(feet+dodge_way*4.0))
							if frame-dodge_t > 45 and not go: dodge_way = Vector3.ZERO
						else:
							stick(Vector2.ZERO)
					_: stick(Vector2.ZERO)
			await frames(1)
	stick(Vector2.ZERO)
	_hooks.erase(hook)
	_halt = false
	var h1 := _hearts()
	var out := {"frames":frame-int(w.f0),"changes":w.changes,"closest":snappedf(float(w.closest),0.01),"states":w.states,
		"knocks":int(motor.knocks)-int(w.knocks0),"stuns":w.stuns,"set_back":w.set_back,"hearts_lost":(int(w.hearts0)-h1) if h1 >= 0 else -1,"last":w.last}
	if not walked.is_empty(): out.route = walked
	var want_row: Variant = opts.get("row",flag("watch-row"))
	if want_row is Dictionary or bool(want_row):
		var held := ""
		for st: String in out.states:
			if held == "" or int(out.states[st]) > int(out.states[held]): held = st
		var line := {"watch":label,"pilot":(mode if mode is String else ("route" if mode is Array else "callable")),"frames":out.frames,
			"changes":out.changes,"closest":out.closest,"knocks":out.knocks,"stuns":out.stuns,"set_back":out.set_back,
			"hearts_lost":out.hearts_lost,"state":held,"last_state":str((w.last as Dictionary).get(names[0],"")) if not names.is_empty() else ""}
		if want_row is Dictionary: line.merge(want_row,true)
		row(line)
	say("WATCH %s %d frames, %d changes, closest %.1f m, states %s, knocks %d stuns %d set back %d%s" % [label,out.frames,out.changes,
		out.closest,str(out.states),out.knocks,out.stuns,out.set_back," hearts lost %d" % out.hearts_lost if h1 >= 0 else ""])
	return out

## The values of `names` (fields, or methods with no args) and `extra` ({name: Callable(enemy)}).
func _peek(e: Object, names: Array, extra: Dictionary) -> Dictionary:
	var out := {}
	for k: String in names:
		if k in e: out[k] = e.get(k)
		elif e.has_method(k): out[k] = e.call(k)
	for k: Variant in extra: out[str(k)] = (extra[k] as Callable).call(e)
	return out

func _watch_at(e: Node, opts: Dictionary) -> Vector3:
	if opts.has("at"): return (opts.at as Callable).call(e)
	if e.has_method("head") and e.get_method_argument_count("head") == 0:
		var h: Variant = e.call("head")
		if h is Vector3: return h
	return (e as Node3D).global_position if e is Node3D else Vector3.ZERO

func _watch_line(label: String, now: Dictionary, names: Array, changed: Array[String], at: Vector3, d: float) -> String:
	var head := str(now.get(names[0],"")) if not names.is_empty() else ""
	if not changed.is_empty(): head = ", ".join(changed)
	var rest := PackedStringArray()
	for k: String in now:
		if k == (names[0] if not names.is_empty() else ""): continue
		rest.append("%s %s" % [k,_fmt(now[k])])
	var feet: Vector3 = motor.feet
	var him := "%s %s%s%s" % [_vtext(feet),"air" if not motor.grounded else ("moving" if Vector2(motor.velocity.x,motor.velocity.z).length() > 0.3 else "still"),
		" "+str(motor.move) if str(motor.move) != "" else "", " STUN "+str(motor.stunned) if str(motor.stunned) != "" else ""]
	var hearts := _hearts()
	return "%s %s d %.1f dy %.1f at %s | %s | him %s knocks %d%s" % [label,head,d,at.y-feet.y,_vtext(at)," ".join(rest),him,int(motor.knocks),
		" hearts %d" % hearts if hearts >= 0 else ""]

static func _fmt(v: Variant) -> String:
	match typeof(v):
		TYPE_FLOAT: return "%.2f" % v
		TYPE_VECTOR3, TYPE_VECTOR2: return _vtext(v)
		TYPE_OBJECT: return str((v as Node).name) if v is Node else str(v)
		TYPE_STRING, TYPE_STRING_NAME: return str(v) if str(v) != "" else "\"\""
	return str(v)

## His hearts in a run (run_layer), else -1.
func _hearts() -> int:
	var loop: Variant = study.get("run_loop") if study != null else null
	if not (loop is Object) or not is_instance_valid(loop): return -1
	var run: Variant = loop.get("run")
	return int(run.hearts_of(motor)) if run is Object and run.has_method("hearts_of") else -1

## Of 16 ways, the one with ground along it that ends furthest from `from`.
func _flee_way(from: Vector3) -> Vector3:
	var feet: Vector3 = motor.feet
	var far := float(motor.run)
	var best := Vector3.ZERO
	var score := -INF
	for i in 16:
		var a := TAU*i/16.0
		var dir := Vector3(cos(a),0.0,sin(a))
		var s := Vector2((feet+dir*far).x-from.x,(feet+dir*far).z-from.z).length()
		for r: float in [0.25,0.5,1.0,2.0]:
			if _floor_y(feet+dir*far*r,float(motor.jumps[1]),float(motor.jumps[1])) == -INF: s -= 100.0
		if s > score:
			score = s
			best = dir
	return best

## Across the line from `from` to him, the side with ground.
func _dodge_way(from: Vector3) -> Vector3:
	var feet: Vector3 = motor.feet
	var to := Vector3(feet.x-from.x,0.0,feet.z-from.z).normalized()
	var side := to.cross(Vector3.UP)
	var far := float(motor.run)*0.5
	if _floor_y(feet+side*far,float(motor.jumps[1]),float(motor.jumps[1])) == -INF and _floor_y(feet-side*far,float(motor.jumps[1]),float(motor.jumps[1])) != -INF:
		return -side
	return side

# --- Breaking (scripts/kit_isle/breakables.gd, spec docs/design/kit-breaks) --

## Every breakables hub in the scene (group "breakables_hub", Breakables.HUBS).
func hubs() -> Array[Node]:
	return study.get_tree().get_nodes_in_group(&"breakables_hub") if study != null else [] as Array[Node]

## A hit through every hub: what is in `radius` m of `at` (world) takes it
## at `strength` (< 0: the breaker's own) from `source` (a breaker: olmec on;
## plane, dragon, slam off unless the hub turned them on). Returns how many
## things broke (0 too when `source` is off). Step frames after it for the
## parts to fall and settle (`frames`, or `until` the hub's live_count() is 0).
func hit(at: Vector3, radius: float, strength := -1.0, source: StringName = &"olmec") -> int:
	var n := 0
	for h: Node in hubs(): n += int(h.hit(at,radius,strength,source))
	return n

# --- Reporting ----------------------------------------------------------------

## `OK label` or `FAIL label: detail`; a fail makes the run exit 1. Returns `ok`.
func check(ok: bool, label: String, detail := "") -> bool:
	checks += 1
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label+("" if detail == "" else ": "+detail))
	return ok

## `key` into the closing `RESULT {json}` line (a sweep's columns).
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

## Ends the run now: RESULT, then quit (`drive()` returning does this).
func finish() -> void:
	if _done: return
	_done = true
	let_go()
	for f: Dictionary in _films.duplicate(): _film_close(f)
	for st: Dictionary in _armed:
		print("SKIP shot_at %s: its `when` never came true" % st.what)
		st.clear()
	_armed.clear()
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
