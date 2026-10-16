extends Node3D
## The motif editor's traps (loop editor-traps): the greybox traps of
## scripts/traps/ (TrapRegistry's list) placed as the kit's pieces are.
## A trap is carried in from the palette's Traps pocket as a ghost of the
## real trap (its way in marked by a green arrow at `entry()`, its way out
## by an orange ring at `exit()`), set down on the ground or a placed
## piece's top, then selected, dragged, turned (Z X), trashed or deleted;
## every change is one undo step (the editor's `snapshot` of `data`).
##
## The data: `data.traps`, [{id, at:[x,y,z], turn}] (knobs come later).
## What stands is built again from it whenever it differs from what was
## built (`sync`, after every land build, so undo and load follow).
##
## While editing the traps stand still: their holder is process-disabled,
## so nothing steps and their bodies are out of the physics space (rigid
## blocks hang where they are built, the editor's rays pass through).

const TrapRegistry = preload("res://scripts/traps/trap_registry.gd")
const MotifAuthored = preload("res://scripts/kit_isle/motif_authored.gd")
const RuinKitFit = preload("res://scripts/ruin_kit_fit.gd")
const PICK_PX := 40.0
## The lip's edge is sought along the drop in steps this long (m); the top
## ends where the ground falls this far under the lip.
const LIP_SNAP := 2.5
const LIP_PROBE := 0.1
const LIP_STEP := 0.25
const LIP_RAYS := 36
## The grey look's clay: multiplied over a trap's own colours (tells keep
## their hue) so traps read against grey stone; the full look leaves them.
const CLAY := Color(1.0,0.72,0.5)
const ENTRY_TINT := Color(0.08,0.62,0.22)
const EXIT_TINT := Color(1.0,0.55,0.2)

var editor: Node
## The selected trap (its index in data.traps), -1 none.
var selected := -1
## The ghost in hand: {id, node, turn} or {}.
var held := {}
var placed: Node3D
var _built := ""
var _ring: MeshInstance3D
var _entry_mark: MeshInstance3D
var _exit_mark: MeshInstance3D
var traps_made := 0
var _clay: StandardMaterial3D

func setup(owner_editor: Node) -> void:
	editor = owner_editor
	name = "EditorTraps"
	placed = Node3D.new()
	placed.name = "Placed"
	placed.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(placed)
	_entry_mark = _mark(_arrow_mesh(),ENTRY_TINT)
	_exit_mark = _mark(_ring_mesh(0.55,0.8),EXIT_TINT)
	_ring = _mark(null,Color(1.0,0.9,0.3))

func entries() -> Array:
	if not (editor.data as Dictionary).has("traps"): return []
	return editor.data.traps

func count() -> int:
	return entries().size()

func holding() -> bool:
	return not held.is_empty()

func node_of(k: int) -> Node3D:
	return placed.get_node_or_null("T%d" % k) as Node3D

## Built again from the data if it changed since the last build.
func sync() -> void:
	if var_to_str(entries()) == _built: return
	rebuild()

func rebuild() -> void:
	for c: Node in placed.get_children():
		placed.remove_child(c)
		c.queue_free()
	var list := entries()
	for k in range(list.size()):
		var node := _make(list[k])
		if node == null: continue
		node.name = "T%d" % k
		placed.add_child(node)
	_built = var_to_str(list)
	selected = -1
	tint()
	show_marks()

func _make(e: Dictionary) -> Node3D:
	var node := TrapRegistry.make(str(e.get("id","")),e.get("knobs",{}))
	if node == null:
		push_warning("motif editor: no trap %s" % e.get("id",""))
		return null
	node.transform = _frame(e)
	return node

static func _frame(e: Dictionary) -> Transform3D:
	var a: Array = e.get("at",[0.0,0.0,0.0])
	return Transform3D(Basis(Vector3.UP,deg_to_rad(float(e.get("turn",0.0)))),Vector3(float(a[0]),float(a[1]),float(a[2])))

# --- Carried in from the palette ---------------------------------------------------------

func begin_ghost(key: String, at: Vector2) -> void:
	drop_ghost()
	var node := TrapRegistry.make(key)
	if node == null: return
	node.name = "TrapGhost"
	node.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(node)
	for g: GeometryInstance3D in node.find_children("*","GeometryInstance3D",true,false):
		g.transparency = 0.45
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for b: CollisionObject3D in node.find_children("*","CollisionObject3D",true,false):
		b.collision_layer = 0
		b.collision_mask = 0
	held = {"id":key,"node":node,"turn":0.0}
	_tint_one(node,_grey())
	select(-1)
	ghost_to(at)

## Where a trap goes under screen point `at`, in snap order: its way in on
## a cliff lip near the cursor (RuinKitFit.lip_near), facing out over the
## drop as in the trap yard; else a placed piece's top; else the ground.
## Alt held skips the lip. {position, on, turn (lip only)} or {}.
func spot(at: Vector2) -> Dictionary:
	if not Input.is_key_pressed(KEY_ALT):
		var lip := lip_spot(at)
		if not lip.is_empty(): return lip
	var top: Dictionary = editor._top_hit(at)
	if not top.is_empty(): return {"position":top.position,"on":"piece"}
	var hit: Dictionary = editor.ground_hit(at)
	if hit.is_empty(): return {}
	return {"position":hit.position,"on":"ground"}

## The cliff lip near the ground under `at`: the trap's origin (its way in)
## on the edge itself, turned so its route (local -z) runs out over the
## drop. {} when no lip is within the editor's LIP_SNAP.
func lip_spot(at: Vector2) -> Dictionary:
	var motif: RefCounted = editor.motif
	if motif == null: return {}
	var hit: Dictionary = editor.ground_hit(at)
	if hit.is_empty(): return {}
	var g: Callable = motif.ground_fn()
	var p := Vector2(hit.position.x,hit.position.z)
	var lip := RuinKitFit.lip_near(g,p,LIP_SNAP,motif.outline())
	if lip.is_empty(): return {}
	var out := lip_out(g,lip.at,lip.out)
	var edge := lip_edge(g,lip.at,out)
	var y := float(g.call(edge.x,edge.y))
	# Route (local -z) along `out`: Basis(UP, a) * (0,0,-1) = (-sin a, 0, -cos a).
	var turn := fposmod(snappedf(rad_to_deg(atan2(-out.x,-out.y)),1.0),360.0)
	return {"position":Vector3(edge.x,y,edge.y),"on":"lip","turn":turn}

## The way off the lip at `p`, square to the edge: the fall round it
## (LIP_REACH out, LIP_RAYS ways) summed by direction, so a straight edge
## faces straight out rather than to lip_near's nearest twelfth. `rough`
## (lip_near's) when the sum says nothing.
static func lip_out(g: Callable, p: Vector2, rough: Vector2) -> Vector2:
	var here := float(g.call(p.x,p.y))
	var sum := Vector2.ZERO
	for k in range(LIP_RAYS):
		var dir := Vector2.from_angle(TAU*k/LIP_RAYS)
		var q := p+dir*RuinKitFit.LIP_REACH
		sum += dir*maxf(here-float(g.call(q.x,q.y)),0.0)
	if sum.length() < 0.01 or sum.normalized().dot(rough) < 0.0: return rough
	return sum.normalized()

## The last point along `out` from `from` still on the top (before the
## ground falls LIP_STEP under it), so the way in sits at the edge.
static func lip_edge(g: Callable, from: Vector2, out: Vector2) -> Vector2:
	var top := float(g.call(from.x,from.y))
	var edge := from
	var d := LIP_PROBE
	while d <= RuinKitFit.LIP_REACH+0.001:
		var q := from+out*d
		if float(g.call(q.x,q.y)) < top-LIP_STEP: break
		edge = q
		d += LIP_PROBE
	return edge

func ghost_to(at: Vector2) -> void:
	if held.is_empty(): return
	var node: Node3D = held.node
	var s := spot(at)
	held.spot = s
	node.visible = not s.is_empty()
	if s.is_empty():
		show_marks()
		return
	var turn := float(s.get("turn",held.turn))
	node.transform = Transform3D(Basis(Vector3.UP,deg_to_rad(turn)),s.position)
	show_marks()

## The ghost set down where it hangs (nothing off the land). The new
## trap's index, or -1.
func place_ghost(at: Vector2) -> int:
	if held.is_empty(): return -1
	ghost_to(at)
	var node: Node3D = held.node
	var key := str(held.id)
	var on := node.visible
	var p := node.position
	var turn := rad_to_deg(node.basis.get_euler().y)
	var where := str((held.get("spot",{}) as Dictionary).get("on","ground"))
	drop_ghost()
	if not on:
		editor.say("Dropped off the land: no trap placed")
		return -1
	editor.snapshot()
	var k := place(key,p,turn)
	editor.say("Placed %s%s" % [TrapRegistry.display_name(key),{"piece":" on a piece","lip":" on the cliff lip"}.get(where,"")])
	return k

func drop_ghost() -> void:
	if held.is_empty(): return
	var node: Node3D = held.node
	remove_child(node)
	node.queue_free()
	held = {}
	show_marks()

## A new trap `key` at `at` turned `turn` degrees; selected. Its index.
func place(key: String, at: Vector3, turn := 0.0) -> int:
	if not (editor.data as Dictionary).has("traps"): editor.data.traps = []
	var list: Array = editor.data.traps
	list.append({"id":key,"at":[snappedf(at.x,0.001),snappedf(at.y,0.001),snappedf(at.z,0.001)],"turn":snappedf(fposmod(turn,360.0),0.001)})
	rebuild()
	traps_made += 1
	var k := list.size()-1
	select(k)
	_pop(k)
	return k

func _pop(k: int) -> void:
	var node := node_of(k)
	if node == null: return
	node.scale = Vector3.ONE*0.6
	create_tween().tween_property(node,"scale",Vector3.ONE,0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if editor.feel != null: editor.feel.cue(&"stone_drop",node.global_position,0.8)

# --- Picking and changing a placed one ---------------------------------------------------

## The trap under screen point `at` (-1 none): the camera's ray through
## each trap's drawn box (its own frame), nearest first; else the trap
## whose way in is nearest on screen within PICK_PX.
func hit(at: Vector2) -> int:
	var cam: Camera3D = editor.camera
	var from := cam.project_ray_origin(at)
	var way := cam.project_ray_normal(at)
	var best := -1
	var near := INF
	for k in range(count()):
		var node := node_of(k)
		if node == null: continue
		var inv := node.global_transform.affine_inverse()
		var box := MotifAuthored.drawn_box(node).grow(0.3)
		var h: Variant = box.intersects_ray(inv*from,inv.basis*way)
		if h == null: continue
		var d := from.distance_to(node.global_transform*(h as Vector3))
		if d < near:
			near = d
			best = k
	if best >= 0: return best
	var px := PICK_PX
	for k in range(count()):
		var node := node_of(k)
		if node == null or cam.is_position_behind(node.global_position): continue
		var d := cam.unproject_position(node.global_position).distance_to(at)
		if d < px:
			px = d
			best = k
	return best

func select(k: int) -> void:
	selected = k if k < count() else -1
	if selected >= 0: editor.select(-1)
	show_marks()
	if selected >= 0:
		var e: Dictionary = entries()[selected]
		editor.say("Trap %s #%d turned %d deg · drag it, Z X turn, Delete takes it away" % [TrapRegistry.display_name(str(e.id)),selected,int(e.get("turn",0.0))])

## The selected trap dragged to screen point `at` (no undo step: the
## press that began the drag took it).
func drag_to(at: Vector2) -> void:
	if selected < 0: return
	var s := spot(at)
	if s.is_empty(): return
	var p: Vector3 = s.position
	var e: Dictionary = entries()[selected]
	e.at = [snappedf(p.x,0.001),snappedf(p.y,0.001),snappedf(p.z,0.001)]
	if s.has("turn"): e.turn = float(s.turn)
	_refit(selected)

## The held ghost or the selected trap turned `deg` degrees.
func turn(deg: float) -> bool:
	if not held.is_empty():
		held.turn = fposmod(float(held.turn)+deg,360.0)
		var node: Node3D = held.node
		node.basis = Basis(Vector3.UP,deg_to_rad(float(held.turn)))
		show_marks()
		return true
	if selected < 0: return false
	editor.snapshot()
	var e: Dictionary = entries()[selected]
	e.turn = snappedf(fposmod(float(e.get("turn",0.0))+deg,360.0),0.001)
	_refit(selected)
	select(selected)
	return true

func _refit(k: int) -> void:
	var node := node_of(k)
	if node != null: node.transform = _frame(entries()[k])
	_built = var_to_str(entries())
	show_marks()

## Trap `k` taken away (one undo step).
func remove(k: int) -> void:
	if k < 0 or k >= count(): return
	editor.snapshot()
	var node := node_of(k)
	var at := node.global_position if node != null else Vector3.ZERO
	entries().remove_at(k)
	if entries().is_empty(): (editor.data as Dictionary).erase("traps")
	selected = -1
	rebuild()
	if editor.feel != null: editor.feel.cue(&"crumble",at,0.6)

func delete_selected() -> bool:
	if selected < 0: return false
	remove(selected)
	editor.say("Trap taken away")
	return true

# --- The grey look's tint -----------------------------------------------------------------

func _grey() -> bool:
	return editor.get("grey") != null and bool(editor.grey.on)

## Placed traps and the ghost in clay while the grey look is on; as built
## in the full look (called on every build and when the look changes).
func tint() -> void:
	var on := _grey()
	for c: Node in placed.get_children(): _tint_one(c,on)
	if not held.is_empty(): _tint_one(held.node,on)

## A clay overlay multiplied over the trap's own materials: nothing of the
## trap's is changed, so its tells still write their colours under it.
func _tint_one(root: Node, on: bool) -> void:
	if on and _clay == null:
		_clay = StandardMaterial3D.new()
		_clay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_clay.blend_mode = BaseMaterial3D.BLEND_MODE_MUL
		_clay.albedo_color = CLAY
	for g: GeometryInstance3D in root.find_children("*","GeometryInstance3D",true,false):
		g.material_overlay = _clay if on else null

# --- The marks: way in, way out, the selection ring ---------------------------------------

func show_marks() -> void:
	var node: Node3D = null
	if bool(editor.editing):
		if not held.is_empty() and (held.node as Node3D).visible: node = held.node
		elif selected >= 0: node = node_of(selected)
	_entry_mark.visible = node != null
	_exit_mark.visible = node != null
	_ring.visible = node != null and held.is_empty()
	if node == null: return
	var lift := Vector3.UP*0.15
	var into: Transform3D = node.entry()
	var out: Transform3D = node.exit()
	_entry_mark.global_transform = Transform3D(Basis(Vector3.UP,into.basis.get_euler().y),into.origin+lift)
	_exit_mark.global_transform = Transform3D(Basis.IDENTITY,out.origin+lift)
	if _ring.visible:
		var box := MotifAuthored.drawn_box(node)
		var r := maxf(Vector2(box.size.x,box.size.z).length()*0.5,1.0)
		_ring.mesh = _ring_mesh(r,r+0.15)
		var c := node.global_transform*box.get_center()
		_ring.global_position = Vector3(c.x,node.global_position.y+0.3,c.z)

func _process(_delta: float) -> void:
	# Hidden while playing, back when editing.
	if _entry_mark.visible != (bool(editor.editing) and (selected >= 0 or not held.is_empty())): show_marks()

func _mark(mesh: Mesh, tint: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = tint
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.visible = false
	add_child(m)
	return m

## A flat arrow on the ground pointing along -z (the route's way).
static func _arrow_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := [Vector3(-0.25,0,0.9),Vector3(0.25,0,0.9),Vector3(0.25,0,-0.1),Vector3(-0.25,0,-0.1),
		Vector3(-0.7,0,-0.1),Vector3(0.7,0,-0.1),Vector3(0,0,-1.0)]
	for i: int in [0,1,2, 0,2,3, 4,5,6]:
		st.set_normal(Vector3.UP)
		st.add_vertex(pts[i])
	return st.commit()

static func _ring_mesh(inner: float, outer: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	return t
