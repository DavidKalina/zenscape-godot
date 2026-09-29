extends SceneTree
## Headless probe of the edge falls (docs/scenic/water-flow.md "Edge falls",
## docs/scenic/modeless.md "The thumb at the rim"), on the cozy worlds scene
## under --modeless, driven by synthesized input through hand_reach:
##   - a peak near the +x side (written into the heights);
##   - a real thumb stroke from its flank out toward the rim, let go short of
##     it: the groove is carried to the lip and notches the rim, and the
##     rim stays as it was either side of the notch;
##   - a thumb stroke running along the edge leaves the rim alone;
##   - the earth sides are refitted to the notch without a gap;
##   - a spring at the groove's head: its water runs off at the lip, the sim
##     counts it per edge cell, one spill stands on +x, the edge fall stands,
##     the flow levels off, and every litre is accounted for in stats();
##   - the spring taken away, the fall fades out;
##   - costs: the step, the spills read, the edge falls' frame update.
##   godot --headless --fixed-fps 60 --path . -s res://tools/probe_edge_fall.gd -- --modeless
var scene: Node3D
var editor: NativeChunkEditor
var reach: Node
var clay: Node
var failures := []
## The heights before any stroke, to measure the rim's change against.
var base := PackedFloat32Array()

const PEAK := Vector2(8.0,-3.0)
const HEAD := Vector2(9.4,-3.0)
const SHORT := Vector2(13.0,-3.0)

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
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func motion(at: Vector2, relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	editor.pointer_override = at
	reach.pointer_override = at
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func frames(count: int) -> void:
	for i in range(count): await process_frame

func height(p: Vector2) -> float:
	return float(editor.data.sample(p,editor.data.heights))

func screen(p: Vector2) -> Vector2:
	return scene.camera.unproject_position(editor.terrain.to_global(Vector3(p.x,height(p),p.y)))

func settled() -> void:
	var quiet := 0
	while quiet < 20:
		await process_frame
		var busy: bool = editor.mountain.active or editor.land_settling or editor.refresh_pending > 0 or (clay != null and (clay.state != 0 or clay.poking))
		quiet = 0 if busy else quiet+1

## A thumb stroke through hand_reach from plate point `a` to `b`, 5 px a frame.
func thumb(a: Vector2, b: Vector2) -> void:
	var from := screen(a)
	var to := screen(b)
	var steps := maxi(ceili(from.distance_to(to)/5.0),10)
	editor.pointer_override = from
	reach.pointer_override = from
	button(from,true)
	await frames(1)
	var p := from
	for i in range(steps):
		var step := (to-from)/steps
		p += step
		motion(p,step)
		await frames(1)
	button(p,false)
	await settled()

## Rim points on the +x side (x = 14) with z in [z0, z1]: [z, height, change
## since the probe's land was laid].
func rim(z0: float, z1: float) -> Array:
	var data := editor.data
	var out := []
	for i in range(data.points.size()):
		var p := data.points[i]
		if p.x > 13.9999 and p.y >= z0 and p.y <= z1: out.append([p.y,data.heights[i],data.heights[i]-base[i]])
	out.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	return out

## The worst height gap between the earth sides' top edge (their vertices on
## the rim line) and the land's rim, over +x points with z in [z0, z1].
func skirt_gap(z0: float, z1: float) -> float:
	var skirt: MeshInstance3D = editor._skirt
	var placing: Transform3D = editor.terrain.global_transform.affine_inverse()*skirt.global_transform
	var top := {}
	for v: Vector3 in placing*skirt.mesh.get_faces():
		if absf(v.x-14.0) > 0.01 or v.z < z0 or v.z > z1: continue
		var key := snappedf(v.z,0.001)
		top[key] = maxf(float(top.get(key,-INF)),v.y)
	var worst := 0.0
	for z: float in top: worst = maxf(worst,absf(float(top[z])-height(Vector2(13.999,z))))
	return worst

func run() -> void:
	create_timer(280).timeout.connect(func() -> void: push_error("edge fall probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-edge-fall-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	await create_timer(1.0).timeout
	editor = scene._chunk_editor
	reach = scene.hand_reach
	clay = scene.get("land_clay")
	scene.world_clock.running = false
	for i in range(120):
		if editor.flow != null and editor.flow.ready: break
		await process_frame
	check("live water on the native kernel with spills",editor.flow != null and editor.flow.ready and editor.flow.native)
	var falls: Node = editor.flow_view.edge_falls if editor.flow_view != null else null
	check("the edge falls are set up",falls != null)
	if editor.flow == null or falls == null or clay == null:
		quit(1)
		return
	var flow: RefCounted = editor.flow
	print("GRID ",flow.width,"x",flow.height," cell ",flow.cell," origin ",flow.origin)
	# The edge ring lies on the grid's border and nowhere inside it.
	var sides: Array = flow.edge_outflow().sides
	check("the edge ring is the grid's border",sides.size() == 4 and (sides[0] as PackedFloat32Array).size() == flow.height and (sides[2] as PackedFloat32Array).size() == flow.width)

	# The land: a peak near +x, faded like the clay's shaping.
	var data := editor.data
	for i in range(data.points.size()):
		var p := data.points[i]
		var t := p.distance_to(PEAK)/4.5
		var edge := maxf(absf(p.x),absf(p.y))
		var fade := clampf((13.6-edge)/(13.6-11.4),0.0,1.0)
		if t < 1.0: data.heights[i] += 4.0*pow(1.0-t*t,2.0)*fade
	editor.force_refresh()
	await settled()
	flow.drain(Vector2.ZERO,40.0)
	base = data.heights.duplicate()
	var skirt_began := Time.get_ticks_usec()
	editor.skirt_mesh_for(data)
	print("SKIRT fit, untouched rim: %d us, %d triangles" % [Time.get_ticks_usec()-skirt_began,editor._skirt.mesh.get_faces().size()/3])

	# A thumb along the edge, inside the fade: the rim stays.
	await thumb(Vector2(12.6,5.0),Vector2(12.6,10.5))
	var along := rim(3.0,12.0)
	var moved := 0.0
	for r: Array in along: moved = maxf(moved,absf(r[2]))
	check("a thumb along the edge leaves the rim alone",moved < 0.005 and clay.notches == 0,"rim moved %.3f m, notches %d" % [moved,clay.notches])

	# The thumb from the peak's flank out toward the rim, let go short of it.
	var began := Time.get_ticks_usec()
	await thumb(HEAD,SHORT)
	var cut := rim(-6.0,0.0)
	var deepest := 0.0
	var line := ""
	for r: Array in cut:
		deepest = minf(deepest,r[2])
		line += " %.2f:%.2f" % [r[0],r[2]]
	print("NOTCH rim change by z:",line)
	print("NOTCH ",clay.last_notch," notches ",clay.notches)
	check("the thumb heading out carries its groove to the lip and notches the rim",deepest < -0.6 and clay.notches == 1,"deepest %.2f m" % deepest)
	var far := rim(-14.0,-7.0)+rim(1.5,3.0)
	var stray := 0.0
	for r: Array in far: stray = maxf(stray,absf(r[2]))
	check("the rim either side of the notch stays as it was",stray < 0.005,"%.3f m" % stray)
	var at: Vector2 = clay.last_notch.get("at",Vector2.ZERO)
	# The screen line from the flank to the rim lands a little off the plate
	# line (the peak stands 3 m up), so the notch is near HEAD.y, not on it.
	check("the notch is where the stroke met the rim",absf(at.x-14.0) < 0.01 and absf(at.y-HEAD.y) < 1.5,at)
	var bed := height(Vector2(13.999,at.y))
	var bank := height(Vector2(13.999,at.y+2.4))
	var skirt_began := Time.get_ticks_usec()
	editor.skirt_mesh_for(data)
	print("SKIRT fit, notched rim: %d us" % (Time.get_ticks_usec()-skirt_began))
	check("the spillway's floor is a groove below the rim",bank-bed > 0.6,"floor %.2f, rim beside %.2f" % [bed,bank])
	var gap_notch := skirt_gap(-6.0,0.0)
	var gap_plain := skirt_gap(4.0,10.0)
	check("the earth sides follow the notch without a gap",gap_notch < 0.06,"notch %.3f m, untouched stretch %.3f m, %d skirt triangles" % [gap_notch,gap_plain,editor._skirt.mesh.get_faces().size()/3])
	var tint := NativeTerrainTint.weight_at(data.tint,_meadow_cell(data,Vector2(13.7,at.y)))
	check("the spillway is dirt",tint > 0.3,"tint weight %.2f" % tint)

	# A spring at the groove's head.
	var kind: String = flow.drop(HEAD,8.0)
	check("a ball at the groove's head is a spring",kind == "spring",kind)
	var rate: float = flow.springs[0].rate if not flow.springs.is_empty() else 0.0
	var history := []
	var step_worst := 0
	var read_worst := 0
	var update_worst := 0
	falls.worst_update_usec = 0
	for second in range(240):
		flow.run(roundi(1.0/flow.dt))
		await frames(2)
		step_worst = maxi(step_worst,flow.last_step_usec)
		read_worst = maxi(read_worst,falls.last_read_usec)
		update_worst = maxi(update_worst,falls.last_update_usec)
		if second % 20 == 19:
			var s: Dictionary = flow.stats()
			history.append(s)
			print("RUN %3d s: volume %.2f m³, edge %.4f m³/s, drained %.2f, soaked %.2f, poured %.2f, spills %d, falls %d" % [second+1,s.volume,s.edge_flux,s.drained,s.soaked,s.poured,flow.spills(falls.DETECT).size(),falls.shown_count()])
	var last: Dictionary = history[-1]
	var earlier: Dictionary = history[-3]
	check("the flow levels off with the stream running off the edge",absf(float(last.volume)-float(earlier.volume)) < 0.03*float(last.volume)+0.05,"%.2f → %.2f m³ over 40 s" % [earlier.volume,last.volume])
	check("most of the spring leaves over the edge",float(last.edge_flux) > 0.5*rate and float(last.edge_flux) < 1.05*rate,"edge %.4f of spring %.4f m³/s" % [last.edge_flux,rate])
	var balance := float(last.poured)-float(last.volume)-float(last.drained)-float(last.soaked)-float(last.removed)
	check("stats() accounts for every litre (poured = standing + drained + soaked + removed)",absf(balance) < 0.01*float(last.poured)+0.01,"%.4f m³ unaccounted of %.2f" % [balance,last.poured])
	var spills: Array = flow.spills(falls.DETECT)
	var outflow: Dictionary = flow.edge_outflow()
	var plus_x: PackedFloat32Array = outflow.sides[1]
	var profile := ""
	for k in range(plus_x.size()):
		if plus_x[k] > 0.0002: profile += " %.2f:%.4f" % [flow.origin.y+(k+0.5)*flow.cell,plus_x[k]]
	print("EDGE +x outflow by z:",profile)
	print("SPILLS ",spills)
	check("one spill stands, on +x at the notch",spills.size() == 1 and int(spills[0].side) == 1 and absf(float(spills[0].lip.z)-at.y) < 1.0,spills.size())
	if not spills.is_empty():
		check("the water leaves at the lip, at the spillway's floor",absf(float(spills[0].lip.x)-14.0) < 0.01 and float(spills[0].lip.y) < bank and float(spills[0].lip.y) > bed-0.05,spills[0].lip)
	# The edge rule drains at the edge cell, not before: the channel holds
	# water in the cells just inward of it.
	var depths: PackedFloat32Array = flow.depths()
	var j: int = flow.cell_at(Vector2(13.9,float(spills[0].lip.z) if not spills.is_empty() else at.y))/int(flow.width)
	var row := ""
	var wet_to := -1
	for i in range(flow.width-8,flow.width):
		row += " %.3f" % depths[j*flow.width+i]
		if depths[j*flow.width+i] > 0.005: wet_to = i
	print("CHANNEL depths to the rim:",row)
	check("water runs in the channel to the cell beside the edge (none vanishes early)",wet_to == flow.width-2,"wet to column %d of %d" % [wet_to,flow.width])
	var vertices: PackedVector3Array = editor.flow_view.moving.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] if editor.flow_view.moving.mesh.get_surface_count() > 0 else PackedVector3Array()
	var reach_x := -INF
	for v in vertices:
		if absf(v.z-at.y) < 1.5: reach_x = maxf(reach_x,v.x)
	check("the drawn stream runs to the lip",reach_x > 13.99,"moving water drawn to x = %.3f" % reach_x)
	var shown: Array = falls.describe()
	print("FALLS ",shown)
	check("the edge fall stands, full, on +x",shown.size() == 1 and int(shown[0].side) == 1 and float(shown[0].presence) > 0.99,shown.size())
	if not shown.is_empty():
		check("it pours down the block's face and on into the void",float(shown[0].face_drop) > 4.0 and float(shown[0].drop) > float(shown[0].face_drop)+2.0,"face %.2f m, in all %.2f m" % [shown[0].face_drop,shown[0].drop])
		var fall: Dictionary = falls._falls[0]
		var points: PackedVector3Array = fall.rings.points
		var hug := ""
		for r in range(0,points.size(),3): hug += " (%.2f,%.2f)" % [points[r].x-14.0,points[r].y]
		print("COURSE out past the rim, height:",hug)
		var inside := 0
		for r in range(1,falls.BEND_RINGS+falls.FACE_RINGS):
			if points[r].x-14.0 < falls._face_at(fall.profile,points[r].y): inside += 1
		check("it stands off the earth side all the way down",inside == 0,"%d rings inside the side" % inside)

	# The spring taken away: the flow dies down and the fall fades.
	flow.springs.clear()
	for second in range(150):
		flow.run(roundi(1.0/flow.dt))
		await frames(2)
		if falls.shown_count() == 0 and second > 5: break
	var after: Dictionary = flow.stats()
	print("DRY edge %.5f m³/s, falls %d" % [after.edge_flux,falls.shown_count()])
	check("without the spring the stream dies down and the fall fades out",falls.shown_count() == 0,"edge %.5f m³/s" % after.edge_flux)

	print("COST ",JSON.stringify({"step_us_worst":step_worst,"spills_read_us_worst":read_worst,"edge_falls_frame_us_worst":update_worst,"step_us_last":flow.last_step_usec}))
	print("RESULT ","PASS" if failures.is_empty() else "FAIL "+str(failures))
	quit(0 if failures.is_empty() else 1)

static func _meadow_cell(data: NativeTerrainData, p: Vector2) -> int:
	var side := NativeTerrainData.MEADOW_CELLS
	var cell := Vector2i(((p+Vector2(14,14))/NativeTerrainData.MEADOW_STEP).floor()).clamp(Vector2i.ZERO,Vector2i.ONE*(side-1))
	return cell.y*side+cell.x
