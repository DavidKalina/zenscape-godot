extends SceneTree
## Irregular islands: the outline is a land mask over the plate's own
## triangulation (scripts/island_outline.gd), owned by the terrain
## (NativeTerrainData `outline`, `shore_distance`): saved, loaded, undone; the
## Quiet plain takes one from its seed; tools leave the sky off the island
## alone; and the live water has no cells there. Under it hangs its rock
## (scripts/island_shore.gd `keel`), which the glide's sense of the island
## (scripts/sky_islands.gd `_body`) matches.
const Outline = preload("res://scripts/island_outline.gd")
const Genesis = preload("res://scripts/genesis_canvas.gd")
const LandClay = preload("res://scripts/land_clay.gd")
const Wire = preload("res://scripts/clay_tools/wire.gd")
const Shore = preload("res://scripts/island_shore.gd")
const SkyIslands = preload("res://scripts/sky_islands.gd")

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func plate() -> NativeTerrainData:
	var source: Node3D = preload("res://assets/zen_reference/geometry.scn").instantiate()
	var data := NativeTerrainData.new()
	data.setup(source.get_node("terrain").mesh)
	source.free()
	return data

func run() -> void:
	var data := plate()
	generator(data)
	await ownership(data)
	shaped(plate())
	tools(plate())
	await water(plate())
	await far(plate())
	rock(plate())
	span(plate())
	print("ISLAND OUTLINE failures=",failures)
	quit(1 if failures else 0)

## The share of the square's area that is land.
func area(data: NativeTerrainData, mask: PackedByteArray) -> float:
	var land := 0.0
	var total := 0.0
	for f in range(mask.size()):
		var a := data.points[data.vertex_ids[f*3]]
		var b := data.points[data.vertex_ids[f*3+1]]
		var c := data.points[data.vertex_ids[f*3+2]]
		var size := absf((b-a).cross(c-a))*0.5
		total += size
		if mask[f] == 0: land += size
	return land/total

func generator(data: NativeTerrainData) -> void:
	var points := data.points
	var ids := data.vertex_ids
	var faces := ids.size()/3
	# Faces across each edge, and the faces round each point.
	var across := PackedInt32Array()
	across.resize(faces*3)
	across.fill(-1)
	var star: Array[PackedInt32Array] = []
	star.resize(points.size())
	var edges := {}
	for f in range(faces):
		for j in range(3):
			var a := ids[f*3+j]
			var b := ids[f*3+(j+1)%3]
			star[a].append(f)
			var key := Vector2i(mini(a,b),maxi(a,b))
			if edges.has(key):
				across[f*3+j] = int(edges[key])/3
				across[int(edges[key])] = f
			else: edges[key] = f*3+j
	var smallest := 1.0
	var largest := 0.0
	var shapes := {}
	var banded_total := 0.0
	for seed_value in range(1,41):
		var mask := Outline.mask(points,ids,seed_value)
		check(mask.size() == faces,"The outline holds a byte a face")
		if seed_value <= 3: check(mask == Outline.mask(points,ids,seed_value),"The same seed gives the same outline")
		shapes[mask.hex_encode().sha256_text()] = true
		var share := area(data,mask)
		smallest = minf(smallest,share)
		largest = maxf(largest,share)
		check(share >= 0.3 and share <= 0.88,"Seed %d's island is %.2f of the square" % [seed_value,share])
		# The middle is land: the player and the landing spot arrive there.
		var middle_land := true
		for f in range(faces):
			var centre := (points[ids[f*3]]+points[ids[f*3+1]]+points[ids[f*3+2]])/3.0
			if centre.length() <= Outline.MIDDLE and mask[f] != 0: middle_land = false
		check(middle_land,"Seed %d's middle is land" % seed_value)
		# One piece, joined across edges.
		var land_faces := mask.count(0)
		var start := -1
		for f in range(faces):
			if mask[f] == 0:
				start = f
				break
		var seen := {start:true}
		var stack := [start]
		while not stack.is_empty():
			var f: int = stack.pop_back()
			for j in range(3):
				var g := across[f*3+j]
				if g >= 0 and mask[g] == 0 and not seen.has(g):
					seen[g] = true
					stack.append(g)
		check(seen.size() == land_faces,"Seed %d's island is one piece (%d of %d faces)" % [seed_value,seen.size(),land_faces])
		# No face hanging on by one side, no notch of sky open on one side only.
		var slivers := 0
		var notches := 0
		for f in range(faces):
			var sides := 0
			for j in range(3):
				var g := across[f*3+j]
				if g >= 0 and mask[g] == 0: sides += 1
			if mask[f] == 0 and sides <= 1: slivers += 1
			if mask[f] != 0 and sides == 3: notches += 1
		check(slivers == 0 and notches == 0,"Seed %d has no slivers (%d) or notches (%d)" % [seed_value,slivers,notches])
		# No two pieces of land meeting at one point (a neck a point wide).
		var pinches := 0
		for i in range(points.size()):
			var round := star[i]
			var runs := 0
			var met := {}
			for f in round:
				if mask[f] != 0 or met.has(f): continue
				runs += 1
				var walk := [f]
				met[f] = true
				while not walk.is_empty():
					var g: int = walk.pop_back()
					for j in range(3):
						var h := across[g*3+j]
						if h < 0 or met.has(h) or mask[h] != 0 or not h in round: continue
						if ids[g*3+j] != i and ids[g*3+(j+1)%3] != i: continue
						met[h] = true
						walk.append(h)
			if runs > 1: pinches += 1
		check(pinches == 0,"Seed %d has no point-wide necks (%d)" % [seed_value,pinches])
		# No neck a triangle wide: every land face has a land face within
		# the opening's reach on each side of it, so no face has all three
		# of its corners on the shore and two sides open.
		var thin := 0
		for f in range(faces):
			if mask[f] != 0: continue
			var open_sides := 0
			for j in range(3):
				var g := across[f*3+j]
				if g < 0 or mask[g] != 0: open_sides += 1
			if open_sides >= 2: thin += 1
		check(thin == 0,"Seed %d has no land face open on two sides (%d)" % [seed_value,thin])
		# Sky all along the plate's rim, never less than about RIM.x of it,
		# and the shore is the island's own shape, seldom held in by that
		# band of sky (where it would follow the square).
		var nearest_rim := INF
		for f in range(faces):
			if mask[f] != 0: continue
			for j in range(3):
				var p := points[ids[f*3+j]]
				var reach := Outline.HALF-maxf(absf(p.x),absf(p.y))
				nearest_rim = minf(nearest_rim,reach)
		# The shore edges whose sky side is the rim's band, not the island's
		# own shape.
		var band: PackedByteArray = Outline._Rim.new(seed_value).faces(points,ids)
		var shore := Outline.shore_edges(ids,mask)
		var banded := 0
		for k in range(0,shore.size(),3):
			for f: int in star[shore[k]]:
				if mask[f] != 0 and band[f] == 1 and shore[k+1] in [ids[f*3],ids[f*3+1],ids[f*3+2]]: banded += 1
		var share_banded := float(banded)/(shore.size()/3)
		banded_total += share_banded
		check(nearest_rim >= 0.8,"Seed %d keeps %.2f m of sky to the plate's rim" % [seed_value,nearest_rim])
		check(share_banded < 0.2,"Seed %d's shore is its own, not the square's (%.2f against the rim's band)" % [seed_value,share_banded])
	check(shapes.size() == 40,"Every seed shapes its own island")
	print("islands %.2f to %.2f of the square; %.3f of their shores against the rim's band" % [smallest,largest,banded_total/40.0])
	check(banded_total/40.0 < 0.04,"Shores are rarely held in by the rim's band (%.3f)" % (banded_total/40.0))
	check(smallest < 0.5 and largest > 0.45,"Sizes vary clearly by seed (%.2f to %.2f)" % [smallest,largest])
	check(absf(area(data,Outline.mask(points,ids,7,0.0))-Outline.AREA.x) < 0.06 and absf(area(data,Outline.mask(points,ids,7,1.0))-Outline.AREA.y) < 0.06,"An asked size gives its area")
	# Not a circle: the shore wanders in and out round the middle.
	var mask := Outline.mask(points,ids,11,0.5)
	var distance := Outline.shore_distance(points,ids,mask)
	var reach := PackedFloat32Array()
	for k in range(72):
		var way := Vector2.from_angle(TAU*k/72.0)
		var r := 0.0
		while r < 20.0:
			var h: Variant = data.sample(way*(r+0.25),data.heights)
			if h == null: break
			var slot: int = data._locate_cache[way*(r+0.25)]
			if mask[data._locate_face[slot]/3] != 0: break
			r += 0.25
		reach.append(r)
	var low := INF
	var high := 0.0
	for r in reach:
		low = minf(low,r)
		high = maxf(high,r)
	check(high-low > 3.0,"The shore is lobed, not round (%.1f to %.1f m)" % [low,high])
	# The distance field: 0 on the shore, -1 off the island, rising inland.
	var on_shore := 0
	var off := 0
	var deepest := 0.0
	for i in range(points.size()):
		if distance[i] == 0.0: on_shore += 1
		if distance[i] < 0.0: off += 1
		deepest = maxf(deepest,distance[i])
	check(on_shore > 20 and off > 100 and deepest > 4.0,"Shore distance: %d on the shore, %d off, %.1f m deepest" % [on_shore,off,deepest])
	check(distance[_nearest(points,Vector2.ZERO)] > 3.0,"The middle stands well inland")

static func _nearest(points: PackedVector2Array, at: Vector2) -> int:
	var best := 0
	for i in range(points.size()):
		if points[i].distance_to(at) < points[best].distance_to(at): best = i
	return best

func ownership(data: NativeTerrainData) -> void:
	data.reset_flat()
	var square := data.to_document()
	check(square.version == 11,"Documents are version 11")
	check(not square.has("outline"),"A square island saves no outline")
	# A document from before outlines (version 10) loads as the full square.
	var old: Dictionary = JSON.parse_string(JSON.stringify(square))
	old.version = 10
	var mask := Outline.mask(data.points,data.vertex_ids,5)
	data.set_outline(mask)
	check(data.outline == mask and not data.void_faces.is_empty(),"Setting an outline cuts the faces off the island")
	check(data.ground_height(Vector2.ZERO) != null,"The middle stands on land")
	check(data.load_document(old),"A version 10 document still loads")
	check(data.outline.is_empty() and data.void_faces.is_empty() and data.shore_distance.is_empty(),"A document without an outline loads as the full square")
	# A saved outline comes back, through JSON as a save file holds it.
	data.set_outline(mask)
	var off := Vector2.ZERO
	for i in range(data.points.size()):
		if data.shore_distance[i] < 0.0:
			off = data.points[i]
			break
	check(data.ground_height(off) == null,"No ground off the island")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(data.to_document()))
	check(saved.has("outline"),"An island with an outline saves it")
	data.set_outline(PackedByteArray())
	check(data.ground_height(off) != null,"Clearing the outline restores the square")
	check(data.load_document(saved),"An island with an outline loads")
	check(data.outline == mask and data.ground_height(off) == null,"The outline round-trips through a save")
	var broken := saved.duplicate()
	var short := PackedByteArray()
	short.resize(10)
	broken.outline = Marshalls.raw_to_base64(short.compress(FileAccess.COMPRESSION_DEFLATE))
	check(not data.load_document(broken),"A malformed outline is refused")
	check(data.outline == mask,"A refused load leaves the island as it was")
	# Undo and redo bring the outline back with the land.
	var other := Outline.mask(data.points,data.vertex_ids,9)
	data.begin_stroke()
	data.set_outline(other)
	check(data.end_stroke(),"An outline change is an undo step")
	data.undo()
	check(data.outline == mask,"Undo restores the outline before")
	check(data.shore_distance == Outline.shore_distance(data.points,data.vertex_ids,mask),"Undo recomputes the distance to shore")
	data.redo()
	check(data.outline == other,"Redo restores the outline after")
	# The chasm composition keeps its own cut alongside, and keeps the outline.
	data.begin_stroke()
	await preload("res://scripts/inland_landscape.gd").new().form(data,preload("res://scripts/chasm_glade.gd").RECIPE)
	data.end_stroke()
	check(data.outline == other,"A terrain recipe keeps the island's outline")
	check(not data.chasm_faces.is_empty() and data.has_chasm(),"The chasm still cuts its own faces")
	for f in range(data.void_faces.size()):
		if data.void_faces[f] != int(data.outline[f] != 0 or data.chasm_faces[f] != 0):
			check(false,"The cut faces are the outline's and the chasm's together")
			break
	data.play_mesh()
	check(data.ray_hit(Vector3(0,30,0),Vector3.DOWN) == null,"Picking sees through the chasm on an island")
	data.undo()
	check(data.chasm_faces.is_empty() and data.outline == other,"Undoing the recipe takes the chasm, not the outline")

## A fresh plain takes its seed's outline, eased to the rim at the shore.
func shaped(data: NativeTerrainData) -> void:
	Genesis.shape(data,77)
	check(data.outline == Outline.mask(data.points,data.vertex_ids,77),"The Quiet plain is its seed's island")
	var rim_ok := true
	for i in range(data.points.size()):
		if data.shore_distance[i] == 0.0 and absf(data.heights[i]-Genesis.RIM_HEIGHT) > 0.001: rim_ok = false
	check(rim_ok,"The plain meets its shore at the rim height")
	Genesis.shape(data,77,Vector2.ZERO,false)
	check(data.outline.is_empty(),"A plain asked for without an island is the full square")
	# Picking: straight down onto land hits, off the island misses.
	Genesis.shape(data,77)
	data.play_mesh()
	var off := Vector2.ZERO
	for i in range(data.points.size()):
		if data.shore_distance[i] < 0.0:
			off = data.points[i]
			break
	check(data.ray_hit(Vector3(0,30,0),Vector3.DOWN) != null,"Picking hits the island")
	check(data.ray_hit(Vector3(off.x,30,off.y),Vector3.DOWN) == null,"Picking misses the sky off the island")
	var slant: Variant = data.ray_hit(Vector3(off.x*1.5,20,off.y*1.5),(Vector3(0,0,0)-Vector3(off.x*1.5,20,off.y*1.5)).normalized())
	check(slant != null and data.ground_height(Vector2(slant.x,slant.z)) != null,"A slanting pick past the shore lands on the island")
	# The shore wall: under every shore edge, down to the slab's base, facing
	# out; a floor under the land.
	var wall := preload("res://scripts/island_shore.gd").build(data,Transform3D(),null)
	var box := wall.get_aabb()
	check(box.position.y < NativeTerrainData.SLAB_BASE-Shore.DEEP.x*0.5,"The shore wall and its rock hang well under the slab's base (%.2f)" % box.position.y)
	var soup := wall.get_faces()
	check(soup.size() == (data.shore_edges.size()/3*4+data.outline.count(0))*3,"Four wall facets a shore edge and the land's rock")
	var outward := 0
	for k in range(0,data.shore_edges.size(),3):
		var tri := k/3*4*3
		var a := soup[tri]
		var normal := (soup[tri+2]-a).cross(soup[tri+1]-a)
		var land := data.points[data.shore_edges[k+2]]
		if Vector2(normal.x,normal.z).dot(Vector2(a.x,a.z)-land) > 0.0: outward += 1
	check(outward == data.shore_edges.size()/3,"Every wall facet faces away from the land (%d of %d)" % [outward,data.shore_edges.size()/3])
	var faces := data.play_collision_faces()
	check(faces.size() == data.outline.count(0)*9 or faces.size() == data.outline.count(0)*3,"Collision holds only the island's faces")

func tools(data: NativeTerrainData) -> void:
	Genesis.shape(data,31)
	var before := data.heights.duplicate()
	var off := PackedInt32Array()
	for i in range(data.points.size()):
		if data.shore_distance[i] < 0.0: off.append(i)
	check(off.size() > 100,"Some of the plate is off the island")
	# Fade: nothing off the island or on its shore; full well inland.
	var editor := NativeChunkEditor.new()
	editor.data = data
	var clay = LandClay.new()
	clay.editor = editor
	var faded := true
	for i in off: faded = faded and clay.fade(i) == 0.0
	for i in range(data.points.size()):
		if data.shore_distance[i] == 0.0: faded = faded and clay.fade(i) == 0.0
	check(faded,"Shaping fades to nothing at the shore")
	check(clay.fade(_nearest(data.points,Vector2.ZERO)) == 1.0,"Shaping is full in the middle")
	clay.gather(Vector2.ZERO,30.0)
	var gathered_off := false
	for i in clay.near: gathered_off = gathered_off or data.shore_distance[i] < 0.0
	check(not gathered_off,"Tools never gather a point off the island")
	# The Ravine bypasses the fade: run it right across the island.
	clay.base = data.heights.duplicate()
	var wire := Wire.new()
	wire.clay = clay
	var heights := data.heights.duplicate()
	var path := PackedVector2Array()
	for k in 33: path.append(Vector2(-14,-2).lerp(Vector2(14,2),k/32.0))
	wire.cut_gorge(heights,path)
	data.heights = heights
	var moved_off := false
	var moved_on := false
	for i in range(heights.size()):
		if heights[i] != before[i]:
			if data.shore_distance[i] < 0.0: moved_off = true
			else: moved_on = true
	check(moved_on and not moved_off,"A ravine across the island cuts only the island")
	# The old editor's brushes.
	for mode in ["raise","lower","flatten","smooth"]: data.brush(Vector2(0,0),40.0,0.8,mode,2.0)
	data.mountain(Vector2.ZERO,40.0,6.0)
	var kept := true
	for i in off: kept = kept and data.heights[i] == before[i]
	check(kept,"The brush and the mountain leave the sky alone")
	# The clay's own write-back keeps the sky as it was too.
	heights = data.heights.duplicate()
	for i in range(heights.size()): heights[i] += 1.0
	data.heights = data.land_only(heights,before)
	kept = true
	for i in off: kept = kept and data.heights[i] == before[i]
	check(kept,"Written heights keep every point off the island where it stood")
	clay.free()
	editor.free()

func water(data: NativeTerrainData) -> void:
	Genesis.shape(data,31)
	var flow: RefCounted = preload("res://scripts/water_flow.gd").new(data)
	await flow.setup()
	var outside := 0
	var wrong := 0
	for j in range(flow.height):
		for i in range(flow.width):
			var at := Vector2(flow.origin.x+(i+0.5)*flow.cell,flow.origin.y+(j+0.5)*flow.cell)
			var land := data.ground_height(at) != null
			var cell: int = flow.inside[j*flow.width+i]
			if not land: outside += 1
			# A cell straddling the shore may be either; well off it is out.
			var deep: Variant = data.sample(at,data.shore_distance)
			if deep != null and float(deep) < -0.01 and not land and cell != 0: wrong += 1
	check(outside > 100 and wrong == 0,"Water cells off the island are outside the grid (%d off, %d wrong)" % [outside,wrong])
	# A new outline sets the grid up again.
	var was: PackedByteArray = flow.inside.duplicate()
	data.set_outline(PackedByteArray())
	check(flow.inside != was and flow.inside.count(0) == 0,"Clearing the outline gives the water the whole square")
	data.set_outline(Outline.mask(data.points,data.vertex_ids,31))
	check(flow.inside == was,"The outline back, the water's grid follows")
	# Springs by the shore all round: their water drains over the shore, and
	# no spill is reported where an edge fall would hang off the island.
	for k in range(8):
		var way := Vector2.from_angle(TAU*k/8.0)
		var r := 0.0
		while data.ground_height(way*(r+0.5)) != null and r < 14.0: r += 0.25
		flow.springs.append({"x":way.x*maxf(r-1.0,0.0),"z":way.y*maxf(r-1.0,0.0),"rate":0.05,"radius":0.6,"age":100.0})
	for k in range(200): flow.run(4)
	var raw: Array = flow.kernel.spills(preload("res://scripts/edge_falls.gd").DETECT)
	var kept: Array = flow.spills(preload("res://scripts/edge_falls.gd").DETECT)
	var floating := 0
	for spill: Dictionary in raw:
		var lip: Vector3 = spill.lip
		var n: Vector2 = spill.normal
		if data.ground_height(Vector2(lip.x,lip.z)-n*0.3) == null: floating += 1
	print("shore spills: %d, %d off the island" % [raw.size(),floating])
	check(not raw.is_empty(),"Water reaches the shore and leaves over it (%d spills)" % raw.size())
	check(kept.size() == raw.size()-floating,"Spills off the island are dropped (%d of %d)" % [floating,raw.size()])
	for spill: Dictionary in kept:
		var lip: Vector3 = spill.lip
		var n: Vector2 = spill.normal
		check(data.ground_height(Vector2(lip.x,lip.z)-n*0.3) != null,"No edge fall stands off the island")
	data.release_listeners()

## A far island is baked as scripts/sky_islands.gd `_bake` does: a detached
## plain shaped on a worker, its play mesh built there, and its earth sides
## (the shore wall) fitted after.
func far(data: NativeTerrainData) -> void:
	var mesh := data.source_mesh
	var arrays := data._arrays.duplicate()
	var baked: Array = []
	var task := WorkerThreadPool.add_task(func() -> void:
		var plain := NativeTerrainData.new()
		plain.setup(mesh,arrays)
		Genesis.shape(plain,123)
		baked.append(plain)
		baked.append(plain.play_mesh(plain.build_mesh())))
	while not WorkerThreadPool.is_task_completed(task): await process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	check(baked.size() == 2,"The far island bakes on a worker")
	var plain: NativeTerrainData = baked[0]
	var ground: ArrayMesh = baked[1]
	check(not plain.outline.is_empty() and plain.outline == Outline.mask(plain.points,plain.vertex_ids,123),"A far island is its seed's island")
	check(ground.get_faces().size() == plain.outline.count(0)*3,"Its ground is only the island's faces")
	var sides := preload("res://scripts/island_shore.gd").build(plain,Transform3D(Basis(),Vector3(0,-2,0)),null)
	check(sides.get_surface_count() == 1 and sides.get_aabb().position.y < -6.0,"Its shore wall hangs under it")

## The rock under an island: one face under each land face, hung from the
## wall's foot, facing down, closed against the wall, seeded by the outline,
## deeper for a bigger island, and laid once per outline.
func rock(data: NativeTerrainData) -> void:
	Genesis.shape(data,77)
	var mesh := Shore.build(data,Transform3D(),null)
	var soup := mesh.get_faces()
	var wall_count := data.shore_edges.size()/3*4*3
	var faces := data.outline.count(0)
	check(soup.size() == wall_count+faces*3,"The rock is one face under each land face (%d)" % faces)
	print("island 77: %d triangles (%d wall, %d rock)" % [soup.size()/3,wall_count/3,faces])
	# Every rock face looks down (the shader's front, as the wall's facets).
	var down := 0
	for k in range(wall_count,soup.size(),3):
		if (soup[k+2]-soup[k]).cross(soup[k+1]-soup[k]).y < 0.0: down += 1
	check(down == faces,"Every rock face looks down (%d of %d)" % [down,faces])
	# Closed: the rock's open edges are the wall's feet, end for end.
	var count := {}
	for k in range(wall_count,soup.size(),3):
		for j in range(3):
			var key := _edge_key(soup[k+j],soup[k+(j+1)%3])
			count[key] = int(count.get(key,0))+1
	var open := {}
	for key: String in count:
		if count[key] == 1: open[key] = true
	var wall_edges := {}
	for k in range(0,wall_count,3):
		for j in range(3): wall_edges[_edge_key(soup[k+j],soup[k+(j+1)%3])] = true
	var in_wall := 0
	for key: String in open:
		if wall_edges.has(key): in_wall += 1
	check(open.size() == data.shore_edges.size()/3,"The rock's open edges run along the shore (%d of %d)" % [open.size(),data.shore_edges.size()/3])
	check(in_wall == open.size(),"The wall comes down to every one of them (%d of %d)" % [in_wall,open.size()])
	# The wall's foot and the rock's edge are the keel's own depths there.
	var base := NativeTerrainData.SLAB_BASE
	var foot_off := 0.0
	for k in range(wall_count,soup.size()):
		var i := _nearest(data.points,Vector2(soup[k].x,soup[k].z))
		foot_off = maxf(foot_off,absf(soup[k].y-(base-data.keel[i])))
	check(foot_off < 0.0001,"The rock hangs at the keel's depths (%.5f m off)" % foot_off)
	# Shallow at the shore, deep inland, its deepest off the middle.
	var near_shore := 0.0
	var near_n := 0
	var inland := 0.0
	var inland_n := 0
	var deepest := 0.0
	var tip := Vector2.ZERO
	var foot_ok := true
	for i in range(data.points.size()):
		var s := data.shore_distance[i]
		if s < 0.0: continue
		if s == 0.0: foot_ok = foot_ok and data.keel[i] >= Shore.LIP.x-0.001 and data.keel[i] <= Shore.LIP.y+0.001
		if s < 1.0:
			near_shore += data.keel[i]
			near_n += 1
		elif s > 4.0:
			inland += data.keel[i]
			inland_n += 1
		if data.keel[i] > deepest:
			deepest = data.keel[i]
			tip = data.points[i]
	near_shore /= maxf(near_n,1)
	inland /= maxf(inland_n,1)
	check(foot_ok,"The wall's foot stays within the lip's range all round")
	check(inland > near_shore+3.0,"The rock hangs deep inland (%.1f m) and shallow at the shore (%.1f m)" % [inland,near_shore])
	check(deepest >= Shore.DEEP.x*(1.0-Shore.DEEP_SPREAD)*0.9 and deepest <= Shore.DEEPEST,"It hangs to a point %.1f m under the slab's base" % deepest)
	check(data.shore_distance[_nearest(data.points,tip)] > 1.0,"Its deepest point is inland")
	# Not one smooth bowl: the point and its spurs are separate low points.
	var lows := 0
	var across := {}
	for f in range(data.outline.size()):
		if data.outline[f] != 0: continue
		for j in range(3):
			var a := data.vertex_ids[f*3+j]
			if not across.has(a): across[a] = {}
			for k in range(3): across[a][data.vertex_ids[f*3+k]] = true
	for i: int in across:
		if data.shore_distance[i] <= 0.0: continue
		var lowest := true
		for j: int in across[i]: lowest = lowest and (j == i or data.keel[j] < data.keel[i])
		if lowest and data.keel[i] > 3.0: lows += 1
	check(lows >= 2,"It hangs to more than one low point (%d)" % lows)
	# Deterministic for the outline; another island hangs other rock.
	var again := plate()
	Genesis.shape(again,77)
	check(again.keel == data.keel and Shore.build(again,Transform3D(),null).get_faces() == soup,"The same island hangs the same rock")
	var other := plate()
	Genesis.shape(other,78)
	check(other.keel != data.keel,"Another island hangs its own rock")
	# A bigger island hangs deeper.
	var small := 0.0
	var big := 0.0
	for seed_value in range(1,7):
		for size: float in [0.0,1.0]:
			var mask := Outline.mask(other.points,other.vertex_ids,seed_value,size)
			var keel := Shore.keel(other.points,other.vertex_ids,mask,Outline.shore_distance(other.points,other.vertex_ids,mask))
			var low := 0.0
			for d in keel: low = maxf(low,d)
			if size == 0.0: small += low/6.0
			else: big += low/6.0
	check(big > small+2.5,"A big island hangs deeper than a small one (%.1f m against %.1f m)" % [big,small])
	# Laid once per outline: shaping the top moves the wall's top, not the rock.
	var laid: Array = data.underside_laid
	var heights := data.heights.duplicate()
	for i in range(heights.size()): heights[i] += 0.5
	data.heights = heights
	var shaped := Shore.build(data,Transform3D(),null).get_faces()
	check(data.underside_laid == laid and shaped.slice(wall_count) == soup.slice(wall_count),"Shaping the top leaves the rock as it was")
	check(shaped.slice(0,wall_count) != soup.slice(0,wall_count),"The wall's top follows the land")
	data.set_outline(Outline.mask(data.points,data.vertex_ids,5))
	check(data.underside_laid.is_empty(),"A new outline lays its rock again")
	# A sum of every island's triangles: a sensible budget for nine live.
	var most := 0
	for seed_value in range(1,21):
		Genesis.shape(other,seed_value)
		most = maxi(most,Shore.build(other,Transform3D(),null).get_faces().size()/3)
	print("most triangles in an island's sides and rock, seeds 1-20: %d" % most)
	check(most <= 3000,"An island's sides and rock stay within 3000 triangles (%d)" % most)
	# No outline: the flat slab's base, as before.
	Genesis.shape(other,77,Vector2.ZERO,false)
	check(other.keel.is_empty() and other.underside(Vector2.ZERO) == NativeTerrainData.SLAB_BASE,"A square plate keeps its flat base")

## Two corners as a key, either way round.
static func _edge_key(a: Vector3, b: Vector3) -> String:
	var x := "%.3f,%.3f,%.3f" % [a.x,a.y,a.z]
	var y := "%.3f,%.3f,%.3f" % [b.x,b.y,b.z]
	return x+"|"+y if x < y else y+"|"+x

## The glide's solid at a point (SkyIslands `_body`) is the rock that is
## drawn: its underside is the rock face's own height there, on the live
## plate and on a far island alike.
func span(data: NativeTerrainData) -> void:
	Genesis.shape(data,77)
	var far := plate()
	Genesis.shape(far,123)
	var editor := NativeChunkEditor.new()
	editor.data = data
	editor.terrain = MeshInstance3D.new()
	root.add_child(editor.terrain)
	editor.terrain.position = Vector3(5.0,-3.0,2.0)
	var islands := SkyIslands.new()
	islands.editor = editor
	for land: NativeTerrainData in [data,far]:
		var soup := Shore.build(land,Transform3D(),null).get_faces()
		var rock := soup.slice(land.shore_edges.size()/3*4*3)
		var rng := RandomNumberGenerator.new()
		rng.seed = 3
		var tried := 0
		var worst := 0.0
		var hidden := 0
		while tried < 200:
			var at := Vector2(snappedf(rng.randf_range(-13.0,13.0),SkyIslands.SNAP),snappedf(rng.randf_range(-13.0,13.0),SkyIslands.SNAP))
			if land.ground_height(at) == null: continue
			tried += 1
			var body: Variant = islands._body(editor.terrain.to_global(Vector3(at.x,40.0,at.y)),land if land == far else null)
			if body == null:
				hidden += 1
				continue
			var drawn := _rock_under(rock,at)
			worst = maxf(worst,absf((body as Vector2).y-editor.terrain.to_global(Vector3(at.x,drawn,at.y)).y))
		check(hidden == 0,"The glide finds a solid over every land point (%d missed)" % hidden)
		check(worst < 0.001,"The solid's underside is the drawn rock (%.4f m off at worst)" % worst)
	var off := Vector2.ZERO
	for i in range(data.points.size()):
		if data.shore_distance[i] < 0.0:
			off = data.points[i]
			break
	check(islands._body(editor.terrain.to_global(Vector3(off.x,40.0,off.y))) == null,"Off the island, open air")
	islands.free()
	editor.terrain.free()
	editor.free()

## The rock's height in `rock` (a face soup) straight under `at`.
static func _rock_under(rock: PackedVector3Array, at: Vector2) -> float:
	for k in range(0,rock.size(),3):
		var a := Vector2(rock[k].x,rock[k].z)
		var b := Vector2(rock[k+1].x,rock[k+1].z)
		var c := Vector2(rock[k+2].x,rock[k+2].z)
		var whole := (b-a).cross(c-a)
		if absf(whole) < 0.000001: continue
		var u := (b-at).cross(c-at)/whole
		var v := (c-at).cross(a-at)/whole
		if u < -0.00001 or v < -0.00001 or u+v > 1.00001: continue
		return u*rock[k].y+v*rock[k+1].y+(1.0-u-v)*rock[k+2].y
	return INF
