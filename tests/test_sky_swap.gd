extends SceneTree
## The swap between a ring range's far skyline (scripts/sky_ring.gd) and the
## range made in full (scripts/sky_peaks.gd) never cuts.
##
## The two are drawn alike (the same material, shadow, layers, GI, frame)
## and the skyline reads back from the cache exactly as made, but they are
## not the same faces: a band range's skyline every 4th or 8th grid point,
## its full range's far faces every 2nd, so their facets, the normals the
## light reads and their colours lie apart, and the full range stands proud
## of the skyline over about half of it. A fading mesh shows only where it
## stands in front of a solid one, so the swap as it was (the full range
## come in solid at once, the skyline fading out over it) cut at once to the
## full range's light over those swaths. Now each half of the swap fades
## only one of the two, the other solid: the full range is unseen as it
## stands, fades in over its solid skyline, and only then does the skyline
## fade out over it; let go, the same backwards; and one made again while
## the last is still fading out takes up its swap where it stood. Headless:
## arrays, nodes and their fades; how it looks is checked with a rendered
## glide.
const SkyPeak = preload("res://scripts/sky_peak.gd")
const SkyPeaks = preload("res://scripts/sky_peaks.gd")
const SkyRing = preload("res://scripts/sky_ring.gd")
const SkyCache = preload("res://scripts/sky_cache.gd")
const SkyWorld = preload("res://scripts/sky_world.gd")
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	SkyCache.dir = "user://sky_cache_test_swap"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SkyCache.dir))
	SkyCache.wipe()
	var peaks: Node3D = SkyPeaks.new()
	root.add_child(peaks)
	peaks.ring.warm(peaks)
	peaks.ring.flush()
	var cell := Vector2i(-1,-1)
	for c in SkyPeaks.ring_cells():
		if SkyWorld.in_band(SkyPeaks.kind_of(c)) and not SkyPeaks.coarse_of(c):
			cell = c
			break
	check(cell.x == SkyPeaks.RING_ROW,"A band range to swap")
	if cell.x == SkyPeaks.RING_ROW:
		var out := {}
		SkyPeaks._make(SkyPeaks.seed_of(cell),SkyPeaks.stature_of(cell),peaks._palette("grass"),peaks._palette("rock"),peaks._gravel(),peaks._snow(),out,SkyPeaks.gorge_of(cell),SkyPeaks.detail_of(cell),SkyPeaks.scale_of(cell).y)
		_apart(peaks,cell,out)
		_swap(peaks,cell,out)
	peaks.queue_free()
	await process_frame
	SkyCache.wipe()
	print("PASS: sky swap" if failures == 0 else "FAIL: sky swap (%d)" % failures)
	quit(1 if failures else 0)

## The skyline and the full range: drawn alike, read back exactly, but not
## the same faces.
func _apart(peaks: Node3D, cell: Vector2i, out: Dictionary) -> void:
	var made: Array = peaks.ring.inputs(cell)
	var cold: Array = SkyRing._shape(made)
	var back: Array = SkyCache.load_arrays(SkyCache.key("skyline",made))
	var exact := not back.is_empty()
	for slot in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_COLOR,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2]:
		if exact and back[slot] != cold[slot]: exact = false
	check(exact,"The skyline reads back from the cache as made cold: faces, normals, colours, snow need (UV) and shade (UV2)")
	# The faces apart: the full range's far faces stand over the skyline's
	# over a good share of it, where a solid range come in at once would
	# show over its skyline.
	var stride := int(made[4])
	var line_faces := _quads(cold,stride)
	var far: PackedVector3Array = (out.far as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var over := 0
	var both := 0
	for k in range(0,far.size(),7):
		var q := far[k]-SkyPeaks.OFF_MAP
		var h: Variant = _height(line_faces,stride,Vector2(q.x,q.z))
		if h == null: continue
		both += 1
		if q.y > float(h)+0.25: over += 1
	check(stride != SkyPeaks.detail_of(cell)*SkyPeaks.LOD_STRIDE and both > 1000 and over > both/5,"Its skyline (every %d grid points) and its full range's far faces (every %d) are not the same faces: the full range stands proud of it at %d%% of %d points" % [stride,SkyPeaks.detail_of(cell)*SkyPeaks.LOD_STRIDE,100*over/maxi(both,1),both])
	# Drawn alike: the swap is only the faces.
	var line: MeshInstance3D = peaks.ring.lines[peaks._key(cell)].node.get_child(0)
	peaks._finish(cell,SkyPeaks.spot(cell),out)
	var full: Node3D = peaks.built[peaks._key(cell)].node
	var alike := true
	for name in ["Body","BodyFar"]:
		var g: MeshInstance3D = full.get_node(name)
		alike = alike and g.mesh.surface_get_material(0) == line.mesh.surface_get_material(0) and g.cast_shadow == line.cast_shadow and g.layers == line.layers and g.gi_mode == line.gi_mode and g.material_override == line.material_override and g.position == line.position and g.mesh.surface_get_format(0) == line.mesh.surface_get_format(0)
	alike = alike and full.transform.is_equal_approx((line.get_parent() as Node3D).transform)
	check(alike,"The skyline and the full range are drawn alike: one material, no shadow, the same layers, GI, vertex format and frame")
	# Made again below, as a range made ahead would be.
	peaks.built[peaks._key(cell)].node.queue_free()
	peaks.built.erase(peaks._key(cell))
	peaks.ring._show()

## A range's triangles by their grid quad (every `stride` points).
func _quads(arrays: Array, stride: int) -> Dictionary:
	var out := {}
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for k in range(0,v.size(),3):
		var c := (v[k]+v[k+1]+v[k+2])/3.0-SkyPeaks.OFF_MAP
		var q := Vector2i(floori((c.x+SkyPeak.HALF.x)/(SkyPeak.STEP*stride)),floori((c.z+SkyPeak.HALF.y)/(SkyPeak.STEP*stride)))
		if not out.has(q): out[q] = []
		out[q].append([v[k]-SkyPeaks.OFF_MAP,v[k+1]-SkyPeaks.OFF_MAP,v[k+2]-SkyPeaks.OFF_MAP])
	return out

## The faces' height over a point, or null off them.
func _height(quads: Dictionary, stride: int, p: Vector2) -> Variant:
	var q := Vector2i(floori((p.x+SkyPeak.HALF.x)/(SkyPeak.STEP*stride)),floori((p.y+SkyPeak.HALF.y)/(SkyPeak.STEP*stride)))
	for t: Array in quads.get(q,[]):
		var a: Vector3 = t[0]
		var b: Vector3 = t[1]
		var c: Vector3 = t[2]
		var d := (b.z-c.z)*(a.x-c.x)+(c.x-b.x)*(a.z-c.z)
		if absf(d) < 1e-9: continue
		var w0 := ((b.z-c.z)*(p.x-c.x)+(c.x-b.x)*(p.y-c.z))/d
		var w1 := ((c.z-a.z)*(p.x-c.x)+(a.x-c.x)*(p.y-c.z))/d
		var w2 := 1.0-w0-w1
		if w0 >= -1e-4 and w1 >= -1e-4 and w2 >= -1e-4: return a.y*w0+b.y*w1+c.y*w2
	return null

## How faded each is: the skyline, the full range's faces and spruces.
func _fades(peaks: Node3D, key: String, node: Node3D) -> Vector2:
	peaks._fade_leaving()
	peaks.ring._show()
	var line: Node3D = peaks.ring.lines[key].node
	var sky := 1.0 if not line.visible else (line.get_child(0) as GeometryInstance3D).transparency
	var range_fade := -1.0
	for child in node.get_children():
		if child is GeometryInstance3D and child.name != "Wrap":
			var t: float = (child as GeometryInstance3D).transparency
			if range_fade >= 0.0 and absf(t-range_fade) > 1e-6: return Vector2(sky,-2.0)
			range_fade = t
	return Vector2(sky,range_fade)

## Sets a swap where it stands (0 the skyline alone, 1 the range).
func _at(peaks: Node3D, key: String, swap: float, leaving := false) -> void:
	var now := Time.get_ticks_msec()
	if leaving: peaks._leaving[key].at = now-int((1.0-swap)*SkyRing.SWAP*1000.0)
	else: peaks.built[key].at = now-int(swap*SkyRing.SWAP*1000.0)

func _swap(peaks: Node3D, cell: Vector2i, out: Dictionary) -> void:
	var key: String = peaks._key(cell)
	check(peaks.ring.showing(key) and peaks.ring.whole,"The skyline shows before its range is made")
	peaks._finish(cell,SkyPeaks.spot(cell),out)
	var node: Node3D = peaks.built[key].node
	# The frame it stands: nothing new drawn, the skyline as it was.
	var first := _fades(peaks,key,node)
	check(first.y > 0.99 and first.x == 0.0,"Stood up under its skyline, the full range is unseen and the skyline solid (range %.2f, skyline %.2f faded)" % [first.y,first.x])
	# Through the swap: never both fading, and each fade steady.
	var both_fading := 0
	var jump := 0.0
	var last := first
	var steps := 48
	for k in range(steps+1):
		_at(peaks,key,float(k)/steps)
		var f := _fades(peaks,key,node)
		if f.y < 0.0:
			both_fading = 99
			break
		if f.x > 1e-4 and f.y > 1e-4: both_fading += 1
		jump = maxf(jump,maxf(absf(f.x-last.x),absf(f.y-last.y)))
		last = f
	check(both_fading == 0,"Through the swap one of the two always stands solid, the full range's faces and spruces faded alike")
	check(jump <= 2.0/steps+0.03,"Each fades steadily, never a cut (at most %.3f a step of %d)" % [jump,steps])
	check(is_equal_approx(last.y,0.0) and is_equal_approx(last.x,1.0),"Once swapped, the full range stands solid and its skyline is gone")
	# The halves: the full range fades in first, the skyline out after.
	_at(peaks,key,0.25)
	var quarter := _fades(peaks,key,node)
	_at(peaks,key,0.75)
	var three := _fades(peaks,key,node)
	check(quarter.x == 0.0 and quarter.y > 0.3 and quarter.y < 0.7 and three.y == 0.0 and three.x > 0.3 and three.x < 0.7,"The full range fades in over its solid skyline, then the skyline out over it (a quarter in: range %.2f faded; three quarters: skyline %.2f)" % [quarter.y,three.x])
	# Let go: the same backwards, and it goes once faded out.
	_at(peaks,key,1.0)
	last = _fades(peaks,key,node)
	peaks._let_go_of(key)
	check(peaks._leaving.has(key),"Let go, it stays while its skyline comes back")
	var back_jump := 0.0
	var back_both := 0
	for k in range(steps,0,-1):
		_at(peaks,key,float(k)/steps,true)
		var f := _fades(peaks,key,node)
		if f.x > 1e-4 and f.y > 1e-4: back_both += 1
		back_jump = maxf(back_jump,maxf(absf(f.x-last.x),absf(f.y-last.y)))
		last = f
	check(back_both == 0 and back_jump <= 2.0/steps+0.03 and last.x == 0.0 and last.y > 0.9,"Let go, the skyline fades back in over it, then it fades out under the solid skyline (at most %.3f a step)" % back_jump)
	# Made again while fading out: the new one takes up the swap where the
	# last one stood.
	var again := {}
	SkyPeaks._make(SkyPeaks.seed_of(cell),SkyPeaks.stature_of(cell),peaks._palette("grass"),peaks._palette("rock"),peaks._gravel(),peaks._snow(),again,SkyPeaks.gorge_of(cell),SkyPeaks.detail_of(cell),SkyPeaks.scale_of(cell).y)
	_at(peaks,key,0.6,true)
	var before := _fades(peaks,key,node)
	peaks._finish(cell,SkyPeaks.spot(cell),again)
	var after := _fades(peaks,key,peaks.built[key].node)
	check(not peaks._leaving.has(key) and absf(after.x-before.x) < 0.03 and absf(after.y-before.y) < 0.03,"Made again while fading out, it takes up the swap where the last stood (skyline %.2f to %.2f, range %.2f to %.2f)" % [before.x,after.x,before.y,after.y])
	# Faded out, it goes.
	var last_node: Node3D = peaks.built[key].node
	_at(peaks,key,0.0)
	peaks._let_go_of(key)
	_at(peaks,key,0.0,true)
	var gone := _fades(peaks,key,last_node)
	check(not peaks._leaving.has(key) and last_node.is_queued_for_deletion() and gone.y == 1.0 and gone.x == 0.0,"Faded out under its solid skyline, it goes")
