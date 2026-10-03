extends SceneTree
## Headless probe of the fence (scripts/fences.gd, docs/scenic/fences.md) on
## the real cozy worlds scene, driven by synthesized input through hand_reach.
## Checks:
## - the case has a fence slot, and the hand takes it;
## - a line dragged over the land lays one fence, one undo step, its posts
##   about POST_SPACING apart and each drawn sunk POST_SINK into the ground;
## - a tap lays nothing;
## - Cmd+Z takes the whole fence away, redo brings it back;
## - the Hills rolled across it re-seat every post on the new ground (no post
##   floats or is buried), through the light refresh a held brush makes and
##   the full one at its end;
## - the trash can swept across its middle cuts a gap (two fences left, one
##   undo step), and undo mends it;
## - a loop ending where it began closes into a pen;
## - the fences survive a save round trip (JSON and back), and a corrupt
##   fence record is refused;
## - joins (docs/scenic/fences.md "Joining"): pressed near a fence's end, the
##   line snaps to that post and continues the fence (one record, the post
##   not doubled, the rail carrying on), ringed in the preview; let go near
##   an end, it joins there; from one end round to the other closes a pen;
##   pressed on a span, a T with a post put in; ended on a side, a T sharing
##   its post. One Cmd+Z undoes a piece and its join; the trash can cuts
##   across a join (a shared post flies only when no fence keeps it); the
##   Hills carry a shared post; the joins survive the save;
## - a line drawn across a lake stands on both shores and skips the water: no
##   post in it and no span over it.
## Visuals (the look of the wood, the faint stakes while drawing) need a GPU
## and are not checked here.
##   godot --headless --fixed-fps 60 --path . -s res://tools/probe_fences.gd -- --modeless --no-title
const Fences = preload("res://scripts/fences.gd")
var scene: Node3D
var editor: NativeChunkEditor
var reach: Node
var clay: Node
var materials: Node
var failures := []

func _initialize() -> void: run.call_deferred()

func check(label: String, ok: bool, detail: Variant = "") -> void:
	if not ok: failures.append(label)
	print(("OK   " if ok else "FAIL ")+label+("" if str(detail).is_empty() else "  "+str(detail)))

func button(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.global_position = at
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	root.push_input(event)

func motion(at: Vector2, relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(event)

func frames(count: int) -> void:
	for i in range(count): await process_frame

func settled() -> void:
	var quiet := 0
	while quiet < 20:
		await process_frame
		var busy: bool = editor.mountain.active or editor.land_settling or editor.refresh_pending > 0 or clay.state != 0 or clay.poking
		quiet = 0 if busy else quiet+1

func height(p: Vector2) -> float:
	return float(editor.data.sample(p,editor.data.heights))

func screen(p: Vector2) -> Vector2:
	return scene.camera.unproject_position(editor.terrain.to_global(Vector3(p.x,height(p),p.y)))

## A drag through screen points, a frame a step; `before_release` is called
## (awaited) with the press still held at the end.
func drag(path: Array[Vector2], before_release := Callable()) -> void:
	button(path[0],true)
	await frames(2)
	for k in range(1,path.size()):
		motion(path[k],path[k]-path[k-1])
		await frames(1)
	await frames(2)
	if before_release.is_valid(): await before_release.call()
	button(path[-1],false)
	await frames(2)

## Screen points along a plate polyline through `corners`, about `per_m`
## a metre.
func poly(corners: Array[Vector2], per_m := 6.0) -> Array[Vector2]:
	var out: Array[Vector2] = [screen(corners[0])]
	for k in range(1,corners.size()):
		var steps := maxi(2,ceili(corners[k-1].distance_to(corners[k])*per_m))
		for s in range(1,steps+1): out.append(screen(corners[k-1].lerp(corners[k],float(s)/steps)))
	return out

func fence(id: int) -> Dictionary:
	for item: Dictionary in data_fences():
		if int(item.id) == id: return item
	return {}

func data_fences() -> Array:
	return editor.data.fences

## The closest gap (m) between two posts of one record, and between two posts
## the view drew: a doubled post shows as ~0.
func closest_posts() -> Dictionary:
	var in_record := INF
	for item: Dictionary in editor.data.fences:
		var ps := Fences.posts_of(item)
		for i in range(ps.size()):
			for j in range(i+1,ps.size()): in_record = minf(in_record,ps[i].distance_to(ps[j]))
	var drawn := INF
	var all: PackedVector2Array = editor.fences.drawn_posts
	for i in range(all.size()):
		for j in range(i+1,all.size()): drawn = minf(drawn,all[i].distance_to(all[j]))
	return {"in_record":in_record,"drawn":drawn}

## Whether `p` is a post of record `item`, and how many times.
func post_count(item: Dictionary, p: Vector2) -> int:
	var count := 0
	for q in Fences.posts_of(item):
		if q.distance_to(p) <= 0.005: count += 1
	return count

## Screen points along the plate line from `a` to `b`, `steps` of them.
func line(a: Vector2, b: Vector2, steps := 40) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for k in range(steps+1): out.append(screen(a.lerp(b,float(k)/steps)))
	return out

## Screen points round a plate loop of `radius` m about `at`, back to its start.
func loop(at: Vector2, radius: float, steps := 60) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for k in range(steps+1):
		var a := TAU*float(k)/steps
		out.append(screen(at+Vector2(cos(a),sin(a))*radius))
	return out

func fence_nodes() -> Array:
	return editor.fences.get_children().filter(func(n: Node) -> bool: return str(n.name).begins_with("fence_"))

## The worst gap (m) between each post's drawn foot and the ground under it
## now less POST_SINK, over every fence: 0 when every post sits as it should.
func seat_error() -> float:
	var worst := 0.0
	for item: Dictionary in editor.data.fences:
		for p in Fences.posts_of(item):
			# Any fence's: where fences join, one of them draws the post.
			var drawn: float = editor.fences.foot_at(0,p)
			var ground: Variant = editor.data.ground_height(p)
			if ground == null: continue
			if is_nan(drawn): return INF
			worst = maxf(worst,absf(drawn-(float(ground)-Fences.POST_SINK)))
	return worst

func all_posts() -> PackedVector2Array:
	var out := PackedVector2Array()
	for item: Dictionary in editor.data.fences: out.append_array(Fences.posts_of(item))
	return out

func run() -> void:
	create_timer(400).timeout.connect(func() -> void: push_error("fence probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-fence-probe-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	await create_timer(1.0).timeout
	editor = scene._chunk_editor
	reach = scene.hand_reach
	clay = scene.get("land_clay")
	materials = reach.get("materials")
	scene.world_clock.running = false
	check("land clay, the materials tray and the fence view exist",clay != null and materials != null and editor.fences != null)
	if not failures.is_empty():
		quit(1)
		return
	await settled()
	var data := editor.data

	# --- The case's slot ---
	var tray: Control = materials.tray
	for i in range(120):
		if tray.shown > 0.99: break
		await process_frame
	# The case fans a group out under a resting pointer (scripts/materials_tray.gd).
	tray.pointer_override = tray.compartment_centre("fence")
	for i in range(120):
		if tray.showing("fence"): break
		await process_frame
	check("the case has a fence slot, found",tray.discovered("fence") and tray.specimen_at(tray.specimen_centre("fence")) == "fence")
	tray.pointer_override = null
	check("the hand takes the fence",materials.take("fence") and materials.held == "fence",materials.held)
	await frames(5)

	# --- A straight fence: one undo step, posts seated ---
	var a := Vector2(-8.0,-3.0)
	var b := Vector2(-1.0,-3.0)
	var undo0: int = data._undo.size()
	var heights0 := data.heights.duplicate()
	await drag(line(a,b))
	await settled()
	check("a dragged line lays one fence",data.fences.size() == 1 and materials.fence_ids.size() == 1,data.fences.size())
	check("one undo step",data._undo.size() == undo0+1,data._undo.size()-undo0)
	check("it moves no ground",data.heights == heights0)
	var posts := all_posts()
	var gaps := []
	for k in range(1,posts.size()): gaps.append(snappedf(posts[k-1].distance_to(posts[k]),0.01))
	var span := a.distance_to(b)
	print("STRAIGHT ",JSON.stringify({"posts":posts.size(),"first":posts[0] if posts.size() > 0 else null,"last":posts[-1] if posts.size() > 0 else null,"gaps":gaps}))
	check("its posts run end to end about POST_SPACING apart",posts.size() >= int(span/Fences.POST_SPACING) and gaps.all(func(g: float) -> bool: return g > Fences.POST_SPACING*0.7 and g < Fences.POST_SPACING*1.35),posts.size())
	check("it is drawn, every post sunk POST_SINK into the ground",fence_nodes().size() == 1 and seat_error() < 0.005,seat_error())
	var first_id := int(data.fences[0].id) if data.fences.size() > 0 else -1

	# --- A tap lays nothing ---
	var tap := screen(Vector2(-4.0,3.0))
	button(tap,true)
	await frames(3)
	button(tap,false)
	await settled()
	check("a tap lays nothing",data.fences.size() == 1 and data._undo.size() == undo0+1,data.fences.size())

	# --- Undo and redo take the whole fence ---
	editor.undo()
	await settled()
	check("Cmd+Z takes the whole fence away",data.fences.is_empty() and fence_nodes().is_empty(),[data.fences.size(),fence_nodes().size()])
	editor.redo()
	await settled()
	check("redo brings it back, drawn",data.fences.size() == 1 and fence_nodes().size() == 1 and int(data.fences[0].id) == first_id)

	# --- The land shaped under it: posts re-seat ---
	var before := PackedFloat32Array()
	for p in posts: before.append(float(data.ground_height(p)))
	materials.put_back()
	materials.select_tool("hills")
	await frames(10)
	var across := Vector2(-4.5,-3.0)
	var rebuilds0: int = editor.fences.rebuilds
	var roll_path: Array[Vector2] = []
	for pass_ in range(4):
		var from := across+Vector2(0.0,-3.0) if pass_%2 == 0 else across+Vector2(0.0,3.0)
		var to := across+Vector2(0.0,3.0) if pass_%2 == 0 else across+Vector2(0.0,-3.0)
		roll_path.append_array(line(from,to,20))
	button(roll_path[0],true)
	await frames(2)
	var mid_error := 0.0
	for k in range(1,roll_path.size()):
		motion(roll_path[k],roll_path[k]-roll_path[k-1])
		await frames(1)
		if k%10 == 0: mid_error = maxf(mid_error,seat_error())
	button(roll_path[-1],false)
	await settled()
	var rose := 0.0
	for k in range(posts.size()): rose = maxf(rose,float(data.ground_height(posts[k]))-before[k])
	print("RESEAT ",JSON.stringify({"most_risen_post_m":snappedf(rose,0.01),"seat_error_while_rolling":snappedf(mid_error,0.0001),"seat_error_after":snappedf(seat_error(),0.0001),"view_rebuilds":editor.fences.rebuilds-rebuilds0}))
	check("the Hills raised the ground under the fence",rose > 0.1,rose)
	check("every post rides the new ground while the brush is held",mid_error < 0.005,mid_error)
	check("and sits on it once the stroke settles",seat_error() < 0.005,seat_error())
	editor.undo()
	await settled()
	check("undoing the Hills puts the posts back down too",seat_error() < 0.005 and absf(float(data.ground_height(posts[posts.size()/2]))-before[posts.size()/2]) < 0.01)

	# --- The trash can cuts a gap ---
	materials.select_tool("trash")
	await frames(10)
	var undo1: int = data._undo.size()
	var count0 := all_posts().size()
	await drag(line(across+Vector2(0.0,-2.5),across+Vector2(0.0,2.5),20))
	await settled()
	await frames(40)
	var left := all_posts()
	print("TRASH ",JSON.stringify({"fences":data.fences.size(),"posts_before":count0,"posts_after":left.size()}))
	check("the trash can cuts a gap: two fences left either side",data.fences.size() == 2,data.fences.size())
	check("the posts in its reach go",left.size() < count0 and left.size() >= 4,[count0,left.size()])
	var near := INF
	for p in left: near = minf(near,absf(p.x-across.x))
	check("none is left near the sweep",near > 0.5,near)
	check("one undo step",data._undo.size() == undo1+1,data._undo.size()-undo1)
	check("the cut fences are drawn as they are",fence_nodes().size() == 2 and seat_error() < 0.005)
	editor.undo()
	await settled()
	check("undo mends it whole",data.fences.size() == 1 and all_posts().size() == count0 and fence_nodes().size() == 1)

	# --- A pen ---
	materials.take("fence")
	await frames(5)
	var pen_at := Vector2(-5.0,4.5)
	await drag(loop(pen_at,2.4))
	await settled()
	var pen: Dictionary = {}
	for item: Dictionary in data.fences:
		if int(item.id) != first_id: pen = item
	check("a loop ending where it began closes into one pen",data.fences.size() == 2 and not pen.is_empty() and bool(pen.get("closed",false)),pen.get("closed"))
	var pen_posts := Fences.posts_of(pen)
	var round_err := 0.0
	for p in pen_posts: round_err = maxf(round_err,absf(p.distance_to(pen_at)-2.4))
	check("its posts stand round the loop",pen_posts.size() >= 9 and round_err < 0.5,[pen_posts.size(),round_err])

	# --- Joins: snap the start, snap the end, close a pen, T-joins ---
	var n0 := data.fences.size()
	await drag(line(Vector2(-8.0,-7.0),Vector2(-4.0,-7.0),30))
	await settled()
	check("a fence to join is laid",data.fences.size() == n0+1 and materials.fence_ids.size() == 1,data.fences.size()-n0)
	var a_id := int(materials.fence_ids[0]) if materials.fence_ids.size() > 0 else -1
	var a_posts := Fences.posts_of(fence(a_id))
	var a_end := a_posts[-1]
	var a_start := a_posts[0]
	var a_count := a_posts.size()
	var seen := {}
	var watch := func() -> void:
		seen.merge({"start":materials.fence_start_join.duplicate(),"end":materials.fence_end_join.duplicate(),"rings":editor.fences.preview_joins.duplicate()},true)
	var ringed := func(p: Vector2) -> bool:
		for q: Vector2 in seen.get("rings",[]):
			if q.distance_to(p) <= 0.01: return true
		return false

	# Snap the start: pressed half a metre off its end post, the line carries on.
	var undo_j: int = data._undo.size()
	await drag(poly([a_end+Vector2(0.4,-0.3),Vector2(-1.0,-7.5)]),watch)
	await settled()
	var joined := Fences.posts_of(fence(a_id))
	var kept_old := joined.size() > a_count and joined.slice(0,a_count) == a_posts
	print("SNAP START ",JSON.stringify({"fences":data.fences.size()-n0,"posts_before":a_count,"posts_after":joined.size(),"start_join":seen.start,"rings":seen.rings,"closest":closest_posts()}))
	check("pressed near a fence's end, the start snaps to its post",not seen.start.is_empty() and bool(seen.start.get("end",false)) and int(seen.start.get("id",-1)) == a_id)
	check("and the preview rings the post it will join",ringed.call(a_end),seen.rings)
	check("the line continues that fence: one record, its id",data.fences.size() == n0+1 and materials.fence_ids == [a_id],[data.fences.size()-n0,materials.fence_ids])
	check("its old posts kept, the new ones after them",kept_old,[a_count,joined.size()])
	check("the joined post is not doubled",post_count(fence(a_id),a_end) == 1 and editor.fences.posts_drawn_at(a_end) == 1 and closest_posts().in_record > 0.5,closest_posts())
	check("the rail carries on from it (the post after it is a span away)",joined.size() > a_count and joined[a_count].distance_to(a_end) < Fences.POST_SPACING*1.4,joined[a_count].distance_to(a_end) if joined.size() > a_count else -1)
	check("one undo step",data._undo.size() == undo_j+1,data._undo.size()-undo_j)
	editor.undo()
	await settled()
	check("Cmd+Z takes the new piece and the join, the fence as it was",Fences.posts_of(fence(a_id)) == a_posts and data.fences.size() == n0+1)
	editor.redo()
	await settled()
	check("redo joins it again",Fences.posts_of(fence(a_id)) == joined)

	# Snap the end: let go half a metre off the fence's (new) end post.
	var b_end := joined[-1]
	var undo_k: int = data._undo.size()
	await drag(poly([Vector2(-1.0,-10.0),b_end+Vector2(-0.35,-0.4)]),watch)
	await settled()
	var joined2 := Fences.posts_of(fence(a_id))
	print("SNAP END ",JSON.stringify({"fences":data.fences.size()-n0,"posts":joined2.size(),"end_join":seen.end,"rings":seen.rings,"closest":closest_posts()}))
	check("let go near a fence's end, the end snaps to its post",not seen.end.is_empty() and int(seen.end.get("id",-1)) == a_id and ringed.call(b_end),seen.end)
	check("the two are one fence now",data.fences.size() == n0+1 and materials.fence_ids == [a_id] and joined2.size() > joined.size(),[data.fences.size()-n0,materials.fence_ids])
	check("the joined post stands once",post_count(fence(a_id),b_end) == 1 and editor.fences.posts_drawn_at(b_end) == 1 and closest_posts().in_record > 0.5,closest_posts())
	check("it runs on to the new line's far end",joined2[0].distance_to(a_start) < 0.01 and joined2[-1].distance_to(Vector2(-1.0,-10.0)) < 0.05,[joined2[0],joined2[-1]])
	check("one undo step",data._undo.size() == undo_k+1)

	# Close the pen: from its free end round to its first post.
	var c_from := joined2[-1]
	await drag(poly([c_from+Vector2(0.3,-0.3),Vector2(-8.0,-10.2),a_start+Vector2(-0.3,-0.35)]),watch)
	await settled()
	var pen2 := fence(a_id)
	var pen2_posts := Fences.posts_of(pen2)
	print("CLOSE ",JSON.stringify({"fences":data.fences.size()-n0,"closed":pen2.get("closed"),"posts":pen2_posts.size(),"rings":seen.rings,"closest":closest_posts()}))
	check("ending on the fence's other end closes it into one pen",data.fences.size() == n0+1 and bool(pen2.get("closed",false)),[data.fences.size()-n0,pen2.get("closed")])
	check("the preview rang both joins",ringed.call(c_from) and ringed.call(a_start),seen.rings)
	check("no post doubled round the pen",post_count(pen2,a_start) == 1 and post_count(pen2,c_from) == 1 and editor.fences.posts_drawn_at(a_start) == 1 and closest_posts().in_record > 0.5 and closest_posts().drawn > 0.3,closest_posts())

	# A T on a span: a post is put in where it joins.
	var mid := Vector2.INF
	var span_k := -1
	for k in range(pen2_posts.size()):
		var p0 := pen2_posts[k]
		var p1 := pen2_posts[(k+1)%pen2_posts.size()]
		var m := (p0+p1)*0.5
		if p0.y < -9.8 and p1.y < -9.8 and m.x > -6.0 and m.x < -3.0 and p0.distance_to(p1) > 1.0:
			mid = m
			span_k = k
			break
	check("the pen has a bottom span to join",span_k >= 0)
	var undo_t: int = data._undo.size()
	await drag(poly([mid+Vector2(0.0,-0.3),mid+Vector2(0.2,-2.2)]),watch)
	await settled()
	var t_id := int(materials.fence_ids[0]) if materials.fence_ids.size() == 1 else -1
	var t_posts := Fences.posts_of(fence(t_id))
	var junction: Vector2 = t_posts[0] if t_posts.size() > 0 else Vector2.INF
	var pen3_posts := Fences.posts_of(fence(a_id))
	print("T SPAN ",JSON.stringify({"t":t_id,"start_join":seen.start,"junction":junction,"pen_posts":[pen2_posts.size(),pen3_posts.size()],"closest":closest_posts()}))
	check("pressed on a span's middle, the start snaps onto the span",not seen.start.is_empty() and int(seen.start.get("index",0)) == -1 and ringed.call(Vector2(seen.start.get("point",Vector2.INF))),seen.start)
	check("a new fence branches off: a T",t_id != a_id and t_id > 0 and data.fences.size() == n0+2,[t_id,data.fences.size()-n0])
	check("a post is put into the span, shared by both",pen3_posts.size() == pen2_posts.size()+1 and post_count(fence(a_id),junction) == 1 and junction.distance_to(mid) < 0.05,[pen3_posts.size(),junction])
	check("drawn once",editor.fences.posts_drawn_at(junction) == 1 and closest_posts().drawn > 0.3,closest_posts())
	check("one undo step",data._undo.size() == undo_t+1)
	editor.undo()
	await settled()
	check("Cmd+Z takes the T and the post it put in",data.fences.size() == n0+1 and Fences.posts_of(fence(a_id)) == pen2_posts)
	editor.redo()
	await settled()
	check("redo puts both back",data.fences.size() == n0+2 and post_count(fence(a_id),junction) == 1 and Fences.posts_of(fence(t_id)).size() == t_posts.size())

	# A T ending on a post: it shares the post (or one put in), drawn once.
	await drag(poly([Vector2(-10.6,-8.6),Vector2(-8.3,-8.6)]),watch)
	await settled()
	var u_id := int(materials.fence_ids[0]) if materials.fence_ids.size() == 1 else -1
	var u_end: Vector2 = Fences.posts_of(fence(u_id))[-1] if u_id > 0 else Vector2.INF
	print("T END ",JSON.stringify({"u":u_id,"end_join":seen.end,"u_end":u_end}))
	check("let go on the pen's side, a T ends on it",u_id > 0 and u_id != a_id and not seen.end.is_empty() and int(seen.end.get("id",-1)) == a_id)
	check("its last post is the pen's post, once, drawn once",post_count(fence(a_id),u_end) == 1 and editor.fences.posts_drawn_at(u_end) == 1 and closest_posts().drawn > 0.3,closest_posts())
	check("every post at every join sits on its ground",seat_error() < 0.005,seat_error())

	# The trash can across a join: both fences cut, nothing doubled; undo mends.
	materials.put_back()
	materials.select_tool("trash")
	await frames(10)
	var undo_c: int = data._undo.size()
	var before_cut: Array = data.fences.duplicate(true)
	await drag(line(junction+Vector2(-0.3,0.0),junction+Vector2(0.3,0.0),6))
	await settled()
	await frames(40)
	var t_left := 0
	for item: Dictionary in data.fences:
		if int(item.id) == t_id: t_left = Fences.posts_of(item).size()
	var junction_left := 0
	for item: Dictionary in data.fences: junction_left += post_count(item,junction)
	print("TRASH JOIN ",JSON.stringify({"fences":data.fences.size()-n0,"pen_closed":fence(a_id).get("closed"),"t_posts":[t_posts.size(),t_left],"junction_left":junction_left,"closest":closest_posts()}))
	check("the trash can cuts across the join: the pen opens, the T loses its foot",fence(a_id).get("closed",true) == false and t_left < t_posts.size() and junction_left == 0)
	check("one undo step, nothing doubled, every post seated",data._undo.size() == undo_c+1 and closest_posts().drawn > 0.3 and seat_error() < 0.005,[data._undo.size()-undo_c,closest_posts(),seat_error()])
	editor.undo()
	await settled()
	check("undo mends the pen and the T, joined again",str(data.fences) == str(before_cut) and editor.fences.posts_drawn_at(junction) == 1)
	# A cut that takes the pen's spans either side of the join but not the
	# T's: the shared post still stands (in the T), and does not fly.
	var ring_posts := Fences.posts_of(fence(a_id))
	var at := -1
	for k in range(ring_posts.size()):
		if ring_posts[k].distance_to(junction) < 0.005: at = k
	data.begin_stroke()
	var left_cut: Dictionary = Fences.cut(data,junction.lerp(ring_posts[at-1],0.5),0.12)
	var right_cut: Dictionary = Fences.cut(data,junction.lerp(ring_posts[(at+1)%ring_posts.size()],0.5),0.12)
	data.end_stroke()
	editor.fences.rebuild(data)
	var flew := false
	for p in left_cut.taken+right_cut.taken: flew = flew or p.distance_to(junction) < 0.01
	var in_pen := 0
	for item: Dictionary in data.fences:
		if int(item.id) != t_id: in_pen += post_count(item,junction)
	check("cut away from the pen, the shared post stays with the T and does not fly",not flew and in_pen == 0 and post_count(fence(t_id),junction) == 1 and editor.fences.posts_drawn_at(junction) == 1,[flew,in_pen])
	editor.undo()
	await settled()
	check("and undo mends that too",str(data.fences) == str(before_cut))

	# The land reshaped under a join: both fences' posts ride it, still one.
	materials.select_tool("hills")
	await frames(10)
	var ground_j := float(data.ground_height(junction))
	await drag(line(junction+Vector2(-1.5,0.4),junction+Vector2(1.5,0.4),20))
	await settled()
	print("RESEAT JOIN ",JSON.stringify({"rose":snappedf(float(data.ground_height(junction))-ground_j,0.01),"seat_error":seat_error()}))
	check("the Hills under a join: the shared post rides the ground, every post seated",float(data.ground_height(junction))-ground_j > 0.02 and seat_error() < 0.005 and editor.fences.posts_drawn_at(junction) == 1,[float(data.ground_height(junction))-ground_j,seat_error()])
	editor.undo()
	await settled()
	materials.take("fence")
	await frames(5)

	# --- Save round trip ---
	var saved: Array = data.fences.duplicate(true)
	var text := JSON.stringify(data.to_document())
	var parsed: Variant = JSON.parse_string(text)
	data.fences.clear()
	var loaded: bool = data.load_document(parsed)
	editor.refresh()
	await settled()
	var same: bool = loaded and data.fences.size() == saved.size()
	if same:
		for k in range(saved.size()):
			same = same and int(data.fences[k].id) == int(saved[k].id) and bool(data.fences[k].closed) == bool(saved[k].closed) and Fences.posts_of(data.fences[k]) == Fences.posts_of(saved[k])
	check("the fences come back from a save, as they were",same,[loaded,data.fences.size()])
	check("and are drawn again on load",fence_nodes().size() == saved.size() and seat_error() < 0.005)
	check("the joins come back: the pen closed, the T's foot on its post, drawn once",bool(fence(a_id).get("closed",false)) and post_count(fence(a_id),junction) == 1 and Fences.posts_of(fence(t_id))[0].distance_to(junction) < 0.005 and editor.fences.posts_drawn_at(junction) == 1 and editor.fences.posts_drawn_at(u_end) == 1 and closest_posts().drawn > 0.3,closest_posts())
	check("and a press there still snaps to the very post",Vector2(Fences.snap(data,junction+Vector2(0.2,-0.2),1.0).get("point",Vector2.INF)).distance_to(junction) < 0.005)
	var corrupt: Dictionary = JSON.parse_string(text)
	corrupt.fences[0].posts.pop_back()
	check("a corrupt fence record is refused",not data.load_document(corrupt) and data.fences.size() == saved.size())
	var older: Dictionary = JSON.parse_string(text)
	older.erase("fences")
	check("a save from before fences loads with none",data.load_document(older) and data.fences.is_empty())
	data.load_document(parsed)
	editor.refresh()
	await settled()

	# --- A lake: the fence skips the water ---
	var lake_at := Vector2(5.5,0.0)
	materials.put_back()
	materials.select_tool("crater")
	await frames(5)
	materials.set_mode("draw")
	await frames(2)
	await drag(loop(lake_at,3.2,60))
	await settled()
	await frames(10)
	var shore: PackedVector2Array = clay.tool.lake_shore()
	var low := INF
	for p in shore: low = minf(low,height(p))
	var level := low-0.5
	var flow: RefCounted = editor.flow
	var ground: PackedFloat32Array = flow.grounds()
	var depth: PackedFloat32Array = flow.depths()
	var found: Dictionary = flow.hollow(lake_at,ground)
	for c: int in found.get("cells",PackedInt32Array()): depth[c] = maxf(level-ground[c],0.0)
	flow.kernel.set_depth(depth)
	await create_timer(3.0).timeout
	check("a lake stands to cross",flow.depth_at(lake_at) > 0.3,flow.depth_at(lake_at))
	materials.take("fence")
	await frames(5)
	var count_before := data.fences.size()
	var undo2: int = data._undo.size()
	await drag(line(lake_at+Vector2(-6.0,0.4),lake_at+Vector2(6.0,0.4),60))
	await settled()
	var laid: Array = materials.fence_ids
	var wet_posts := 0
	var wet_spans := 0
	var laid_posts := 0
	for item: Dictionary in data.fences:
		if not int(item.id) in laid: continue
		var ps := Fences.posts_of(item)
		laid_posts += ps.size()
		for p in ps:
			if flow.depth_at(p) >= Fences.WET_DEPTH: wet_posts += 1
		for k in range(ps.size()-1):
			for t in [0.25,0.5,0.75]:
				if flow.depth_at(ps[k].lerp(ps[k+1],t)) >= 0.05: wet_spans += 1
	var sides := {}
	for item: Dictionary in data.fences:
		if int(item.id) in laid:
			for p in Fences.posts_of(item): sides[signf(p.x-lake_at.x)] = true
	print("LAKE ",JSON.stringify({"runs":laid.size(),"posts":laid_posts,"posts_in_water":wet_posts,"spans_over_water":wet_spans,"middle_depth":snappedf(flow.depth_at(lake_at),0.01)}))
	check("the line across the lake lays as one undo step",data._undo.size() == undo2+1 and data.fences.size() == count_before+laid.size(),data._undo.size()-undo2)
	check("it stands on both shores, in two runs or more",laid.size() >= 2 and sides.size() == 2,[laid.size(),sides.keys()])
	check("no post stands in the water",wet_posts == 0,wet_posts)
	check("no span is laid over the water",wet_spans == 0,wet_spans)
	check("every post sits on its ground",seat_error() < 0.005,seat_error())

	print("FENCE PROBE: ",failures.size()," failures ",failures)
	print("RESULT ","PASS" if failures.is_empty() else "FAIL "+str(failures))
	quit(0 if failures.is_empty() else 1)
