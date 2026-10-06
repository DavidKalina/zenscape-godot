extends SceneTree
## Probe: a ring range drawn every way it is drawn (its skyline made cold and
## read back from the cache; its full range's near and far faces), compared
## where they overlap: colours, snow, normals, the light, and the nodes'
## draw settings. Headless: arrays and nodes only.
## godot --headless --path . --script tools/probe_peak_swap.gd
const SkyPeak = preload("res://scripts/sky_peak.gd")
const SkyPeaks = preload("res://scripts/sky_peaks.gd")
const SkyRing = preload("res://scripts/sky_ring.gd")
const SkyCache = preload("res://scripts/sky_cache.gd")
const SkyWorld = preload("res://scripts/sky_world.gd")
const SUN := Vector3(0.45,0.7,0.3)
const TILE := 128.0

func _initialize() -> void:
	SkyCache.dir = "user://sky_cache_probe"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SkyCache.dir))
	SkyCache.wipe()
	var peaks: Node3D = SkyPeaks.new()
	peaks.ring.peaks = peaks
	var cells: Array[Vector2i] = SkyPeaks.ring_cells()
	var picked := {}
	for cell in cells:
		var kind := SkyPeaks.kind_of(cell)
		var tag := "%s/%s/%d" % [("band" if SkyWorld.in_band(kind) else "ridge"),kind,peaks.ring.stride_of(cell)]
		if not picked.has(tag): picked[tag] = cell
	print("ranges: %d; kinds probed: %s" % [cells.size(),str(picked.keys())])
	for tag in picked: _probe(peaks,picked[tag],tag)
	_nodes(peaks,picked.values()[0])
	SkyCache.wipe()
	peaks.free()
	quit(0)

func _probe(peaks: Node3D, cell: Vector2i, tag: String) -> void:
	var made: Array = peaks.ring.inputs(cell)
	var key := SkyCache.key("skyline",made)
	var cold: Array = SkyRing._shape(made)
	SkyCache.save_arrays(key,cold)
	var back: Array = SkyCache.load_arrays(key)
	var exact := true
	for slot in range(cold.size()):
		if cold[slot] != null and back[slot] != cold[slot]: exact = false
	var out := {}
	SkyPeaks._make(SkyPeaks.seed_of(cell),SkyPeaks.stature_of(cell),peaks._palette("grass"),peaks._palette("rock"),peaks._gravel(),peaks._snow(),out,SkyPeaks.gorge_of(cell),SkyPeaks.detail_of(cell),SkyPeaks.scale_of(cell).y)
	var detail := SkyPeaks.detail_of(cell)
	var sky_stride: int = made[4]
	var near := _faces(out.body.surface_get_arrays(0),detail)
	var far := _faces(out.far.surface_get_arrays(0),detail*SkyPeaks.LOD_STRIDE)
	var line := _faces(back,sky_stride)
	print("\n== %s cell %s: skyline stride %d (cache round trip exact: %s), full near %d, far %d; scale %s" % [tag,str(cell),sky_stride,str(exact),detail,detail*SkyPeaks.LOD_STRIDE,str(SkyPeaks.scale_of(cell))])
	_compare("skyline vs far",line,far,out.shape)
	_compare("skyline vs near",line,near,out.shape)
	_compare("far vs near",far,near,out.shape)

## Faces bucketed by their grid quad: quad -> [triangles: {a,b,c, colour, need, shade, n (vertex normals), facet}].
func _faces(arrays: Array, stride: int) -> Dictionary:
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var nrm: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var col: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var quads := {}
	for k in range(0,v.size(),3):
		var c := (v[k]+v[k+1]+v[k+2])/3.0-SkyPeaks.OFF_MAP
		var q := Vector2i(floori((c.x+SkyPeak.HALF.x)/(SkyPeak.STEP*stride)),floori((c.z+SkyPeak.HALF.y)/(SkyPeak.STEP*stride)))
		var facet := (v[k+2]-v[k]).cross(v[k+1]-v[k]).normalized()
		if facet.y < 0.0: facet = -facet
		if not quads.has(q): quads[q] = []
		quads[q].append({"a":v[k]-SkyPeaks.OFF_MAP,"b":v[k+1]-SkyPeaks.OFF_MAP,"c":v[k+2]-SkyPeaks.OFF_MAP,"colour":col[k],"need":uv[k].x,"shade":uv2[k].x,"n":[nrm[k],nrm[k+1],nrm[k+2]],"facet":facet})
	return {"stride":stride,"quads":quads}

## The face over a point (x, z), with its barycentric weights, or {}.
func _at(faces: Dictionary, p: Vector2) -> Dictionary:
	var s: int = faces.stride
	var q := Vector2i(floori((p.x+SkyPeak.HALF.x)/(SkyPeak.STEP*s)),floori((p.y+SkyPeak.HALF.y)/(SkyPeak.STEP*s)))
	for t: Dictionary in faces.quads.get(q,[]):
		var a := Vector2(t.a.x,t.a.z)
		var b := Vector2(t.b.x,t.b.z)
		var c := Vector2(t.c.x,t.c.z)
		var d := (b.y-c.y)*(a.x-c.x)+(c.x-b.x)*(a.y-c.y)
		if absf(d) < 1e-9: continue
		var w0 := ((b.y-c.y)*(p.x-c.x)+(c.x-b.x)*(p.y-c.y))/d
		var w1 := ((c.y-a.y)*(p.x-c.x)+(a.x-c.x)*(p.y-c.y))/d
		var w2 := 1.0-w0-w1
		if w0 >= -1e-4 and w1 >= -1e-4 and w2 >= -1e-4:
			var out := t.duplicate()
			out.w = Vector3(w0,w1,w2)
			out.y = t.a.y*w0+t.b.y*w1+t.c.y*w2
			return out
	return {}

static func _luma(c: Color) -> float:
	return c.r*0.2126+c.g*0.7152+c.b*0.0722

## The shader's light, roughly: the facet leaned FACET_SOFT to the vertex
## normal (scale ignored: both drawn under the same one).
func _light(t: Dictionary) -> float:
	var w: Vector3 = t.w
	var n: Vector3 = ((t.n[0] as Vector3)*w.x+(t.n[1] as Vector3)*w.y+(t.n[2] as Vector3)*w.z).normalized()
	var l := (t.facet as Vector3).lerp(n,SkyPeaks.FACET_SOFT).normalized()
	return maxf(l.dot(SUN.normalized()),0.0)

func _shown(t: Dictionary, snow: Color) -> Color:
	var base: Color = snow if float(t.need) < 0.0 else t.colour
	return base*(0.35+0.65*_light(t))

func _compare(label: String, a: Dictionary, b: Dictionary, shape: RefCounted) -> void:
	var n := 0
	var sums := {"colour":0.0,"colour_signed":0.0,"light":0.0,"light_signed":0.0,"facet_deg":0.0,"vnormal_deg":0.0,"shown":0.0,"shown_signed":0.0,"height":0.0}
	var snow_a := 0
	var snow_b := 0
	var snow_flip := 0
	# Where b stands over a (b drawn opaque under a's opaque start of the
	# swap wins the depth test there): what changes the instant b stands.
	var over := 0
	var over_shown := 0.0
	var tiles := {}
	var p := Vector2(-SkyPeak.HALF.x+2.0,0.0)
	while p.x < SkyPeak.HALF.x:
		p.y = -SkyPeak.HALF.y+2.0
		while p.y < SkyPeak.HALF.y:
			var ta := _at(a,p)
			var tb := _at(b,p)
			if not ta.is_empty() and not tb.is_empty() and minf(ta.y,tb.y) > SkyPeak.SEA:
				n += 1
				var dl := _luma(ta.colour)-_luma(tb.colour)
				sums.colour += absf(dl)
				sums.colour_signed += dl
				var la := _light(ta)
				var lb := _light(tb)
				sums.light += absf(la-lb)
				sums.light_signed += la-lb
				sums.facet_deg += rad_to_deg((ta.facet as Vector3).angle_to(tb.facet))
				var wa: Vector3 = ta.w
				var wb: Vector3 = tb.w
				var na: Vector3 = ((ta.n[0] as Vector3)*wa.x+(ta.n[1] as Vector3)*wa.y+(ta.n[2] as Vector3)*wa.z).normalized()
				var nb: Vector3 = ((tb.n[0] as Vector3)*wb.x+(tb.n[1] as Vector3)*wb.y+(tb.n[2] as Vector3)*wb.z).normalized()
				sums.vnormal_deg += rad_to_deg(na.angle_to(nb))
				var sa := _luma(_shown(ta,SkyPeak.SNOW_COLOUR))
				var sb := _luma(_shown(tb,SkyPeak.SNOW_COLOUR))
				sums.shown += absf(sa-sb)
				sums.shown_signed += sa-sb
				sums.height += absf(ta.y-tb.y)
				var ia := float(ta.need) < 0.0
				var ib := float(tb.need) < 0.0
				if ia: snow_a += 1
				if ib: snow_b += 1
				if ia != ib: snow_flip += 1
				if tb.y > ta.y:
					over += 1
					over_shown += absf(sa-sb)
				var tile := Vector2i(floori(p.x/TILE),floori(p.y/TILE))
				if not tiles.has(tile): tiles[tile] = [0,0.0,0.0,0.0]
				tiles[tile][0] += 1
				tiles[tile][1] += sa-sb
				tiles[tile][2] += _luma(ta.colour)-_luma(tb.colour)
				tiles[tile][3] += la-lb
			p.y += 4.0
		p.x += 4.0
	if n == 0:
		print("  %s: no overlap" % label)
		return
	var worst := 0.0
	var worst_colour := 0.0
	var worst_light := 0.0
	var big := 0
	var counted := 0
	for tile in tiles:
		var t: Array = tiles[tile]
		if t[0] < 200: continue
		counted += 1
		var m: float = float(t[1])/t[0]
		if absf(m) > absf(worst): worst = m
		if absf(float(t[2])/t[0]) > absf(worst_colour): worst_colour = float(t[2])/t[0]
		if absf(float(t[3])/t[0]) > absf(worst_light): worst_light = float(t[3])/t[0]
		if absf(m) > 0.02: big += 1
	print("  %s (%d points): |dheight| %.2f m; |dcolour luma| %.4f (signed %.4f); |dlight| %.4f (signed %.4f); facet %.1f deg, vertex normal %.2f deg apart" % [label,n,sums.height/n,sums.colour/n,sums.colour_signed/n,sums.light/n,sums.light_signed/n,sums.facet_deg/n,sums.vnormal_deg/n])
	print("    shown luma |d| %.4f (signed %.4f); snowy %.1f%% vs %.1f%%, flipped %.1f%%; %d-m tiles: worst mean shown d %.4f, colour %.4f, light %.4f; %d of %d tiles off by > 0.02" % [sums.shown/n,sums.shown_signed/n,100.0*snow_a/n,100.0*snow_b/n,100.0*snow_flip/n,int(TILE),worst,worst_colour,worst_light,big,counted])
	print("    the second stands over the first at %.0f%% of points (shown luma |d| there %.4f)" % [100.0*over/n,over_shown/maxf(over,1)])

func _nodes(peaks: Node3D, cell: Vector2i) -> void:
	peaks.ring.warm(peaks)
	peaks.ring.flush()
	var key: String = peaks._key(cell)
	var line: Node3D = peaks.ring.lines[key].node
	var out := {}
	SkyPeaks._make(SkyPeaks.seed_of(cell),SkyPeaks.stature_of(cell),peaks._palette("grass"),peaks._palette("rock"),peaks._gravel(),peaks._snow(),out,SkyPeaks.gorge_of(cell),SkyPeaks.detail_of(cell),SkyPeaks.scale_of(cell).y)
	peaks._finish(cell,SkyPeaks.spot(cell),out)
	var full: Node3D = peaks.built[key].node
	print("\n== nodes for %s" % key)
	for g: GeometryInstance3D in [line.get_child(0),full.get_node("Body"),full.get_node("BodyFar")]:
		var mi := g as MeshInstance3D
		print("  %s/%s: global %s; cast_shadow %d layers %d gi %d transparency %.2f vis %.0f-%.0f (margins %.0f/%.0f, fade %d) material %s override %s aabb %s" % [g.get_parent().name,g.name,str(g.transform),g.cast_shadow,g.layers,g.gi_mode,g.transparency,g.visibility_range_begin,g.visibility_range_end,g.visibility_range_begin_margin,g.visibility_range_end_margin,g.visibility_range_fade_mode,str(mi.mesh.surface_get_material(0)),str(g.material_override),str(mi.get_aabb())])
		print("    format %d" % mi.mesh.surface_get_format(0))
