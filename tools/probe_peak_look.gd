extends SceneTree
## Probes the mountains' faces and colours headless (scripts/sky_peak.gd
## `body_arrays`), for the world seeds asked (default 7, 11, 42): a few of
## each layout's ranges (a massif, a ridge piece, a foothill, a far one) at
## their near stride and their skyline's, and a few of the sea's summits.
## Prints, per seed and in all:
##   faces: flipped (wound against their face normal, or facing down), whose
##     vertex normal disagrees with the face (dot < 0.2), slivers (smallest
##     angle under 4 degrees), grid pits (a point more than 1.5 m under all
##     eight neighbours);
##   pit faces: a face drawn (snow as the spring sky lays it) and lit by a
##     plain sun and sky much darker than every face sharing its edges
##     (under PIT_SHARE of the darkest of them, under any of SUNS: `lit`),
##     split by why: its colour, or its light;
##   colour: rock faces' mean linear colour, its spread (std of luminance),
##     the green share (g over both r and b) and the warm share (r over b),
##     the snow share by height band (share of the range's height over the
##     sea) and the snow's share of faces over the snow line.
## Run: godot --headless --path . --script tools/probe_peak_look.gd -- [seeds]
const SkyPeak = preload("res://scripts/sky_peak.gd")
const SkyPeaks = preload("res://scripts/sky_peaks.gd")
const SkyRing = preload("res://scripts/sky_ring.gd")
const SkyWorld = preload("res://scripts/sky_world.gd")
const PIT_SHARE := 0.5
const SUNS := [Vector3(0.45,0.62,0.35),Vector3(-0.55,0.45,-0.2),Vector3(0.1,0.9,-0.4)]

var totals := {}
var white := Color.WHITE

func _initialize() -> void:
	var seeds := [7,11,42]
	var asked := []
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int(): asked.append(int(a))
	if not asked.is_empty(): seeds = asked
	var palette: RefCounted = preload("res://scripts/native_terrain_palette.gd").new()
	var grass: Array = []
	for c in palette.grass: grass.append(c)
	var rock: Array = []
	for c in palette.rock: rock.append(c)
	white = palette.snow
	for s: int in seeds:
		SkyWorld.seed = s
		var laid: Dictionary = SkyWorld.layout()
		var picked := {}
		for r: Dictionary in laid.ranges:
			if picked.has(r.kind) or picked.size() >= 4: continue
			picked[r.kind] = r
		for kind in picked:
			var r: Dictionary = picked[kind]
			var shape: RefCounted = SkyPeak.make(int(r.seed),float(r.stature),bool(r.gorge))
			shape.snowline = maxf(shape.snowline,SkyPeak.snow_floor(float(r.scale.y)))
			var near := SkyPeaks.RIDGE_STRIDE if kind == "ridge" else 1
			_measure("seed %d %s near" % [s,kind],shape,shape.body_arrays(grass,rock,palette.gravel,SkyPeaks.OFF_MAP,near,palette.snow),near,SkyPeak.CUT)
			var line := SkyRing.STRIDE_LOW if kind in ["foot","far"] else SkyRing.STRIDE
			_measure("seed %d %s skyline" % [s,kind],shape,shape.body_arrays(grass,rock,palette.gravel,SkyPeaks.OFF_MAP,line,palette.snow),line,SkyPeak.CUT)
		var summits: Array = laid.get("summits",[])
		for k in range(mini(2,summits.size())):
			var out := {}
			SkyRing._make_summit(int(summits[k].seed),float(summits[k].show),grass,rock,palette.gravel,palette.snow,SkyPeaks.OFF_MAP,out)
			var shape: RefCounted = SkyPeak.make(int(summits[k].seed),1.0,false)
			_measure("seed %d summit %d" % [s,k],shape,out.arrays,SkyRing.SUMMIT_STRIDE,float(out.solid.sea))
	_report("ALL",totals)
	quit(0)

## The light a face takes from a plain sun and sky: its light normal leans
## FACET_SOFT to the broad lie, as reference_surface's does.
## As the ground's shader does, the face's normal (from the screen's
## derivatives, its sign unknown) is first turned to agree with the vertex
## normal there (reference_surface `facet`).
static func lit(colour: Color, face: Vector3, broad: Vector3, sun: Vector3) -> float:
	if face.dot(broad) < 0.0: face = -face
	var n := face.lerp(broad,SkyPeaks.FACET_SOFT).normalized()
	var l := 0.35*(n.y*0.5+0.5)+0.85*maxf(n.dot(sun.normalized()),0.0)
	return (0.2126*colour.r+0.7152*colour.g+0.0722*colour.b)*l

func _measure(label: String, shape: RefCounted, arrays: Array, stride: int, sea: float) -> void:
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var nrm: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var col: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var faces := v.size()/3
	var s := {"faces":0,"flipped":0,"down":0,"disagree":0,"sliver":0,"pit_faces":0,"grid_pits":0,
		"rock":0,"rock_r":0.0,"rock_g":0.0,"rock_b":0.0,"rock_l":0.0,"rock_l2":0.0,"green":0,"warm":0,
		"over_line":0,"over_line_snow":0,"pit_colour":0,"pit_rock_in_snow":0,"pit_light":0,"pit_against":0}
	for b in range(5):
		s["band%d" % b] = 0
		s["band%d_snow" % b] = 0
	var drawn := PackedColorArray()
	drawn.resize(faces)
	var face_n := PackedVector3Array()
	face_n.resize(faces)
	var broad := PackedVector3Array()
	broad.resize(faces)
	var edges := {}
	var span := maxf(shape.top-sea,1.0)
	for f in range(faces):
		var a := v[f*3]
		var b := v[f*3+1]
		var c := v[f*3+2]
		# Godot's front faces wind clockwise: the outward normal is (c-a)x(b-a).
		var n := (c-a).cross(b-a)
		var area := n.length()
		n = n/maxf(area,1e-9)
		face_n[f] = n
		var bn := (nrm[f*3]+nrm[f*3+1]+nrm[f*3+2]).normalized()
		broad[f] = bn
		s.faces += 1
		if n.y < 0.0: s.down += 1
		if n.dot(bn) < 0.0: s.flipped += 1
		elif n.dot(bn) < 0.2: s.disagree += 1
		var smallest := PI
		for q in [[a,b,c],[b,c,a],[c,a,b]]:
			smallest = minf(smallest,((q[1] as Vector3)-q[0]).angle_to((q[2] as Vector3)-q[0]))
		if smallest < deg_to_rad(4.0): s.sliver += 1
		var snowy := uv[f*3].x < 0.0
		var colour := col[f*3]
		if snowy:
			var blue := clampf(fposmod(uv2[f*3].x,1.0)/0.999,0.0,1.0)
			var nudge := (floorf(uv2[f*3].x)/32.0*2.0-1.0)*SkyPeak.SNOW_JITTER
			colour = Color(white.r*lerpf(1.0,0.93,blue),white.g*lerpf(1.0,0.965,blue),white.b)*(1.0+nudge)
		drawn[f] = colour
		var y := (a.y+b.y+c.y)/3.0
		var band := clampi(int((y-sea)/span*5.0),0,4)
		s["band%d" % band] += 1
		if snowy: s["band%d_snow" % band] += 1
		if y > shape.snowline:
			s.over_line += 1
			if snowy: s.over_line_snow += 1
		if not snowy:
			s.rock += 1
			s.rock_r += colour.r
			s.rock_g += colour.g
			s.rock_b += colour.b
			var l := 0.2126*colour.r+0.7152*colour.g+0.0722*colour.b
			s.rock_l += l
			s.rock_l2 += l*l
			if colour.g > colour.r*1.02 and colour.g > colour.b*1.02: s.green += 1
			if colour.r > colour.b*1.05: s.warm += 1
		for e in [[a,b],[b,c],[c,a]]:
			var key := _edge(e[0],e[1])
			if edges.has(key): edges[key].append(f)
			else: edges[key] = [f]
	# Pit faces: much darker, lit, than the faces sharing their edges, under
	# any of the suns.
	var round := []
	round.resize(faces)
	for f in range(faces): round[f] = []
	for key in edges:
		var fs: Array = edges[key]
		if fs.size() == 2:
			round[fs[0]].append(fs[1])
			round[fs[1]].append(fs[0])
	for f in range(faces):
		if (round[f] as Array).size() < 2: continue
		var pit := false
		for sun: Vector3 in SUNS:
			var mine := lit(drawn[f],face_n[f],broad[f],sun)
			var least := INF
			for g: int in round[f]: least = minf(least,lit(drawn[g],face_n[g],broad[g],sun))
			if least > 0.02 and mine < least*PIT_SHARE: pit = true
		if not pit: continue
		s.pit_faces += 1
		# Why: its own colour much darker than theirs (a rock face among
		# snow, a dark band); or its light (its normal turned from theirs,
		# its broad normal against its face); or a pit in the grid.
		var least_l := INF
		for g: int in round[f]: least_l = minf(least_l,_lum(drawn[g]))
		if _lum(drawn[f]) < least_l*0.7:
			s.pit_colour += 1
			if uv[f*3].x >= 0.0 and least_l > 0.5: s.pit_rock_in_snow += 1
		else:
			s.pit_light += 1
			if face_n[f].dot(broad[f]) < 0.2: s.pit_against += 1
	# Grid pits: a drawn point well under all eight round it.
	for j in range(stride,shape.nz-stride,stride):
		for i in range(stride,shape.nx-stride,stride):
			var h: float = shape.heights[j*shape.nx+i]
			if h < sea: continue
			var lowest := INF
			for dj in [-stride,0,stride]:
				for di in [-stride,0,stride]:
					if di == 0 and dj == 0: continue
					lowest = minf(lowest,shape.heights[(j+dj)*shape.nx+i+di])
			if h < lowest-1.5: s.grid_pits += 1
	_report(label,s)
	for k in s:
		totals[k] = totals.get(k,0)+s[k]

static func _lum(c: Color) -> float:
	return 0.2126*c.r+0.7152*c.g+0.0722*c.b

static func _edge(a: Vector3, b: Vector3) -> String:
	var p := Vector3i(roundi(a.x*10.0),roundi(a.y*10.0),roundi(a.z*10.0))
	var q := Vector3i(roundi(b.x*10.0),roundi(b.y*10.0),roundi(b.z*10.0))
	if p.x > q.x or (p.x == q.x and (p.y > q.y or (p.y == q.y and p.z > q.z))):
		var t := p
		p = q
		q = t
	return "%d,%d,%d|%d,%d,%d" % [p.x,p.y,p.z,q.x,q.y,q.z]

static func _report(label: String, s: Dictionary) -> void:
	var rock := maxf(s.rock,1.0)
	var mean := Color(s.rock_r/rock,s.rock_g/rock,s.rock_b/rock)
	var ml: float = s.rock_l/rock
	var spread := sqrt(maxf(s.rock_l2/rock-ml*ml,0.0))
	var bands := ""
	for b in range(5): bands += " %d%%" % roundi(100.0*float(s["band%d_snow" % b])/maxf(s["band%d" % b],1.0))
	print("%s: faces %d flipped %d down %d disagree %d sliver %d grid_pits %d PIT_FACES %d (colour %d, rock among snow %d, light %d, normal against face %d) | rock mean (%.3f %.3f %.3f) lum %.3f spread %.3f green %.2f%% warm %.1f%% | snow by band (low->high)%s | over line snowed %d%%" % [
		label,s.faces,s.flipped,s.down,s.disagree,s.sliver,s.grid_pits,s.pit_faces,s.pit_colour,s.pit_rock_in_snow,s.pit_light,s.pit_against,mean.r,mean.g,mean.b,ml,spread,
		100.0*s.green/rock,100.0*s.warm/rock,bands,roundi(100.0*float(s.over_line_snow)/maxf(s.over_line,1.0))])
