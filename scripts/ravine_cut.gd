extends RefCounted
## The ravine (scripts/cluster_motifs.gd "ravine"): one big island torn in
## two by a deep cleft. Each half is an islet of its own (scripts/
## sky_islet.gd), authored from the same whole: the same seed, radius,
## outline and hanging rock, so the two outer coasts run on as one island's
## and the rock under them is one rock cut through; each keeps only the land
## on its side of a jagged tear line, the gap between them a few metres at
## the narrow end and wide enough at the other for the plane to thread.
##
## The tear (a recipe's `tear`, filled by `share` from the cluster's draw so
## both halves read the same one), in the whole island's frame (its grid's
## middle at the origin):
##   along: the tear's way, across: its normal (the far half's side);
##   offset(s): how far the tear's middle line stands off the straight
##     line at `s` m along it: a slow bend plus a zigzag through seeded
##     knots (JAG), so the walls are jagged and the two halves' walls match
##     tooth for tooth;
##   width(s): the gap, from width.x at the narrow end to width.y at the
##     wide (`narrow` says which way along is wide);
##   side: -1 for the near half (land where the margin says), 1 the far.
## A half keeps the faces whose middle lies past half the width on its side
## (`margin`), tidied (no face hanging on by one side, only the largest
## piece), and is re-centred on its most inland point (SkyIslet `grid_shift`),
## so it reads as any islet does (its middle is land, its rim a ray out).
##
## The inner wall (`wall`): the faces along the tear stand on a wall of
## their own instead of the shore's slumped earth: sheer, faceted rock from
## the lip down to the hanging rock, which along the tear is as deep as the
## whole island's middle (the keel is the whole's). Under its lip it falls
## in SHELVES steps, each a shelf (a ring set back, and just under it one
## stood out, so the face between looks up and catches the light) over a
## face falling back in under it (in shadow): crags, not a sheet. How far
## each stands out runs along the tear (ribs, like basalt columns) and down
## it, never out past a share of the gap, and the wall is held back by the
## spring's lip so the fall pours clear. Drawn in the members' earth sides (the cluster's rock
## look), in the islet's sides mesh.
##
## The layout (`place`, for the solver's relations): "tear" stands the far
## half where the whole puts it, lifted by its height, and lays the rope
## bridge across the gap where it spans BRIDGE_SPAN; "cleft" hangs a
## broken-off chunk in the wide part of the gap, low; "flank" lays a
## satellite off a half's outer side, never in the cleft's mouths. Features
## (`feature`): "overlook", a plank lookout out over the gap from the far
## half, opposite the near half's fall, its lantern at the end;
## "lip_lanterns", lantern posts along a half's lip, their lanterns hung
## out toward the gap, so at night the gap reads as a dark line between two
## rows of warm points.

const IslandOutline = preload("res://scripts/island_outline.gd")
const IslandShore = preload("res://scripts/island_shore.gd")
const Footbridge = preload("res://scripts/footbridge.gd")
const PlateMesh = preload("res://scripts/plate_mesh.gd")

## The relations and features this file lays (the solver's hooks).
const RELATIONS := ["tear","cleft","flank"]
const FEATURES := ["overlook","lip_lanterns"]
## The whole island's radius (m, a circle of its land).
const RADIUS := Vector2(19.0,23.0)
## The gap (m): at the narrow end (a range) and at the wide end (a range),
## easing between over WIDTH_RUN of the radius each side of the middle.
const NARROW := Vector2(3.6,4.8)
const WIDE := Vector2(12.5,15.0)
const WIDTH_RUN := 0.75
## The tear's bend: its sway (m) and wavelength (share of the radius); its
## zigzag: knots JAG_STEP m apart, each off by up to JAG m, alternating.
const BEND := Vector2(1.2,3.2)
const BEND_WAVE := Vector2(2.2,3.4)
const JAG := 1.05
const JAG_STEP := Vector2(1.7,3.0)
## The spring whose fall pours into the gap: its pond's radius (m) and how
## far in from the lip it lies (m past its radius), and where along the
## tear (share of the radius toward the wide end).
const POND := Vector2(1.9,2.4)
const POND_IN := 2.6
const FALL_AT := Vector2(0.15,0.4)
## Where along the tear (share of the radius, toward the wide end) the
## bridge would rather cross, and the span it would rather have (m).
const BRIDGE_AT := Vector2(-0.6,0.1)
const BRIDGE_SPAN := 7.5
const BRIDGE_INSET := 1.3
## The chunk: tried along the tear's wide part (share of the radius), and
## kept this far clear of the fall's line along the tear (m).
const CHUNK_AT := Vector2(0.35,0.85)
const CHUNK_CLEAR := 1.6
const FALL_CLEAR := 5.0
## The lookout: its deck's length (m, and share of the gap at most), its
## width, and how far along the tear it stands off the fall (m).
const LOOKOUT := Vector2(2.8,4.2)
const LOOKOUT_SHARE := 0.34
const LOOKOUT_WIDTH := 1.4
const LOOKOUT_OFF := Vector2(2.5,4.5)
## Lantern posts along a lip: how many (a range), at least this far apart
## along the tear and off the bridge's and the lookout's heads (m), and how
## far in from the lip (m).
const LIP_LANTERNS := Vector2i(3,4)
const LIP_APART := 5.5
const LIP_CLEAR := 3.0
const LIP_IN := 0.85
## The inner wall: shelves from lip to foot and a shelf's height (m), the
## lip's drop (m) and jut, the ribs' and ledges' jut (m) and waves (1/m),
## and the most it stands out into the gap (m, and share of the gap) or
## back (m).
const SHELVES := 5
const SHELF := Vector2(0.35,0.9)
const WALL_LIP := Vector2(0.45,1.1)
const WALL_LIP_OUT := Vector2(0.05,0.35)
const RIBS := 0.75
const RIB_WAVE := 0.55
const LEDGES := 0.6
const LEDGE_WAVE := 0.18
const WALL_OUT := 1.3
const WALL_OUT_SHARE := 0.26
const WALL_BACK := 0.9

# --- The tear -------------------------------------------------------------------

## Fills a half's recipe (`spec`, its `tear` holding its side and whether it
## has the fall) from the cluster's draw (`draw`, the same for both halves),
## so both read the same tear, island, rock and hanging depth; the motif's
## rock gives the palettes and the keel range. Returns the halves' shared
## seed.
static func share(spec: Dictionary, draw: int, motif: Dictionary) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([draw,"ravine"])
	var tear: Dictionary = spec.tear
	tear.seed = rng.randi() & 0xffffff
	var r := rng.randf_range(RADIUS.x,RADIUS.y)
	tear.radius = r
	tear.angle = rng.randf()*TAU
	tear.narrow = -1.0 if rng.randf() < 0.5 else 1.0
	tear.width = Vector2(rng.randf_range(NARROW.x,NARROW.y),rng.randf_range(WIDE.x,WIDE.y))
	tear.bend = Vector3(rng.randf_range(BEND.x,BEND.y)*(1.0 if rng.randf() < 0.5 else -1.0),TAU/(r*rng.randf_range(BEND_WAVE.x,BEND_WAVE.y)),rng.randf()*TAU)
	var step := rng.randf_range(JAG_STEP.x,JAG_STEP.y)
	var knots := PackedFloat32Array()
	var count := ceili(r*3.6/step)+2
	for k in range(count): knots.append((1.0 if k % 2 == 0 else -1.0)*rng.randf_range(0.25,1.0)*JAG)
	tear.knots = knots
	tear.step = step
	tear.fall_s = wide_s(tear,rng.randf_range(FALL_AT.x,FALL_AT.y))
	spec.radius = r
	var rock: Dictionary = motif.get("rock",{})
	var palettes: Array = rock.get("palettes",["basalt"])
	var tone: Vector2 = rock.get("tone",Vector2.ONE)
	var keel: Vector2 = motif.get("keel",Vector2.ONE)
	spec.rock = {"palette":palettes[rng.randi() % palettes.size()],"tone":rng.randf_range(tone.x,tone.y)}
	spec.keel = rng.randf_range(keel.x,keel.y)
	spec.erase("pond")
	if bool(tear.get("fall",false)) and float(tear.side) < 0.0:
		spec.pond = {"radius":rng.randf_range(POND.x,POND.y),"toward":across(tear)*-float(tear.side)}
	return int(tear.seed)

static func along(tear: Dictionary) -> Vector2:
	return Vector2.from_angle(float(tear.angle))

static func across(tear: Dictionary) -> Vector2:
	return along(tear).orthogonal()

## `share` of the radius along the tear toward its wide end, as `s` (m).
static func wide_s(tear: Dictionary, share_: float) -> float:
	return share_*float(tear.radius)*float(tear.narrow)

## The tear's middle line's offset (m, across) at `s` m along.
static func offset(tear: Dictionary, s: float) -> float:
	var bend: Vector3 = tear.bend
	var knots: PackedFloat32Array = tear.knots
	var step := float(tear.step)
	var t := (s+float(knots.size()-1)*step*0.5)/step
	var k := clampi(floori(t),0,knots.size()-2)
	var jag := lerpf(knots[k],knots[k+1],clampf(t-k,0.0,1.0))
	return bend.x*sin(s*bend.y+bend.z)+jag

## The gap's width (m) at `s` m along.
static func width(tear: Dictionary, s: float) -> float:
	var run := float(tear.radius)*WIDTH_RUN
	var w: Vector2 = tear.width
	return lerpf(w.x,w.y,smoothstep(-run,run,s*float(tear.narrow)))

## How far (m, across) the whole's point `p` lies past the edge of the
## half on `side`'s land: positive on that half's land, negative in the gap
## or on the other half.
static func margin(tear: Dictionary, p: Vector2, side: float) -> float:
	var s := p.dot(along(tear))
	var d := p.dot(across(tear))-offset(tear,s)
	return d*side-width(tear,s)*0.5

## The point on the gap's middle line at `s` (the whole's frame).
static func middle_at(tear: Dictionary, s: float) -> Vector2:
	return along(tear)*s+across(tear)*offset(tear,s)

# --- A half ---------------------------------------------------------------------

## Cuts the islet's whole outline (SkyIslet `_shape`, just masked with the
## shared seed) down to its half, and sets what the rest of its shaping
## reads: the half's outline, shore distance and edges, the whole's keel
## (`cleft.keel`), which shore edges are the tear's (`cleft.edges`), the
## half's middle in the whole's frame (`cleft.middle`, its points shifted by
## it), and the spring's pond in the half's own frame.
static func cut(islet: RefCounted) -> void:
	var tear: Dictionary = islet.recipe.tear
	var side := float(tear.side)
	var points: PackedVector2Array = islet.points
	var ids: PackedInt32Array = islet.ids
	var whole: PackedByteArray = islet.outline
	var faces := ids.size()/3
	var whole_distance := IslandOutline.shore_distance(points,ids,whole)
	var keel := IslandShore.keel(points,ids,whole,whole_distance)
	var out := whole.duplicate()
	var middles := PackedVector2Array()
	middles.resize(faces)
	for f in range(faces):
		middles[f] = (points[ids[f*3]]+points[ids[f*3+1]]+points[ids[f*3+2]])/3.0
		if whole[f] == 0 and margin(tear,middles[f],side) < 0.0: out[f] = 1
	# Neighbours over the whole's land, for the tidying and the tear edges.
	var edges := {}
	for f in range(faces):
		if whole[f] != 0: continue
		for j in range(3):
			var key := Vector2i(mini(ids[f*3+j],ids[f*3+(j+1)%3]),maxi(ids[f*3+j],ids[f*3+(j+1)%3]))
			if edges.has(key): (edges[key] as Array).append(f)
			else: edges[key] = [f]
	var neighbours := {}
	for key: Vector2i in edges:
		var pair: Array = edges[key]
		if pair.size() != 2: continue
		for k in range(2):
			if not neighbours.has(pair[k]): neighbours[pair[k]] = []
			(neighbours[pair[k]] as Array).append(pair[1-k])
	# A face hanging on by one side goes.
	for _pass in range(3):
		var gone := false
		for f in range(faces):
			if out[f] != 0: continue
			var held := 0
			for g: int in neighbours.get(f,[]): held += 1 if out[g] == 0 else 0
			if held <= 1:
				out[f] = 1
				gone = true
		if not gone: break
	# Only the largest piece stays.
	var piece := PackedInt32Array()
	piece.resize(faces)
	piece.fill(-1)
	var best := -1
	var best_size := 0
	var label := 0
	for f in range(faces):
		if out[f] != 0 or piece[f] >= 0: continue
		var stack := [f]
		piece[f] = label
		var size := 0
		while not stack.is_empty():
			var g: int = stack.pop_back()
			size += 1
			for h: int in neighbours.get(g,[]):
				if out[h] == 0 and piece[h] < 0:
					piece[h] = label
					stack.append(h)
		if size > best_size:
			best_size = size
			best = label
		label += 1
	for f in range(faces):
		if out[f] == 0 and piece[f] != best: out[f] = 1
	var distance := IslandOutline.shore_distance(points,ids,out)
	var shore := IslandOutline.shore_edges(ids,out)
	# The tear's edges: shore edges with the whole's land on both sides.
	var flags := PackedByteArray()
	flags.resize(shore.size()/3)
	for k in range(0,shore.size(),3):
		var key := Vector2i(mini(shore[k],shore[k+1]),maxi(shore[k],shore[k+1]))
		flags[k/3] = 1 if (edges.get(key,[]) as Array).size() == 2 else 0
	# The half's middle: its most inland point (the land's mean breaks a tie).
	var deepest := 0.0
	var mean := Vector2.ZERO
	var count := 0
	for i in range(points.size()):
		if distance[i] < 0.0: continue
		deepest = maxf(deepest,distance[i])
		mean += points[i]
		count += 1
	mean /= maxf(count,1)
	var middle := Vector2.ZERO
	var nearest := INF
	for i in range(points.size()):
		if distance[i] < deepest*0.92: continue
		if points[i].distance_to(mean) < nearest:
			nearest = points[i].distance_to(mean)
			middle = points[i]
	var shifted := PackedVector2Array()
	shifted.resize(points.size())
	for i in range(points.size()): shifted[i] = points[i]-middle
	islet.points = shifted
	islet.grid_shift = middle
	islet.outline = out
	islet.shore_distance = distance
	islet.shore_edges = shore
	islet.cleft = {"keel":keel,"edges":flags,"middle":middle,"whole_distance":whole_distance}
	# The spring: its pond in from the lip where the fall is wanted.
	if islet.recipe.has("pond"):
		var pond: Dictionary = islet.recipe.pond
		var r := float(pond.get("radius",2.0))
		var s := float(tear.fall_s)
		var at := Vector2.INF
		for k in range(24):
			var try_s: float = s+(k/2)*0.8*(1.0 if k % 2 == 0 else -1.0)
			var into := width(tear,try_s)*0.5+r+POND_IN
			var q := middle_at(tear,try_s)+across(tear)*side*into
			var local := q-middle
			if islet.on_land(local) and _sample(islet,distance,local) >= r+1.2:
				at = local
				tear.fall_s = try_s
				break
		if at != Vector2.INF: pond.at = at
		else: islet.recipe.erase("pond")

static func _sample(islet: RefCounted, values: PackedFloat32Array, p: Vector2) -> float:
	return float(islet._sample(values,p,-1.0))

## The inner wall's faces, appended to the islet's sides (SkyIslet
## `side_arrays`: `vertices` and their `uvs`, each wall vertex carrying its
## rim top), under every tear edge.
static func wall(islet: RefCounted, vertices: PackedVector3Array, uvs: PackedVector2Array) -> void:
	var tear: Dictionary = islet.recipe.tear
	var side := float(tear.side)
	var flags: PackedByteArray = islet.cleft.edges
	var middle: Vector2 = islet.cleft.middle
	var points: PackedVector2Array = islet.points
	var heights: PackedFloat32Array = islet.heights
	var keel: PackedFloat32Array = islet.keel
	var shore: PackedInt32Array = islet.shore_edges
	var base: float = islet.base
	var outward: Dictionary = IslandShore._outward(points,shore)
	var gap_way := -across(tear)*side
	var ribs := FastNoiseLite.new()
	ribs.seed = int(tear.seed)+int(side)*7
	ribs.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ribs.frequency = RIB_WAVE
	var ledges := FastNoiseLite.new()
	ledges.seed = int(tear.seed)+int(side)*13+5
	ledges.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ledges.frequency = LEDGE_WAVE
	var into := Transform3D.IDENTITY
	var columns := {}
	for k in range(0,shore.size(),3):
		if flags[k/3] == 0: continue
		for i in [shore[k],shore[k+1]]:
			if columns.has(i): continue
			var out: Vector2 = ((outward.get(i,gap_way) as Vector2)+gap_way*0.6).normalized()
			columns[i] = _column(islet,i,out,middle,tear,ribs,ledges,heights[i],base-keel[i])
	for k in range(0,shore.size(),3):
		if flags[k/3] == 0: continue
		var a := shore[k]
		var b := shore[k+1]
		var out: Vector2 = ((outward.get(a,gap_way) as Vector2)+(outward.get(b,gap_way) as Vector2)).normalized()
		var face := Vector3(out.x,0.0,out.y)
		var col_a: Array = columns[a]
		var col_b: Array = columns[b]
		var ha := heights[a]
		var hb := heights[b]
		for r in range(col_a.size()-1):
			IslandShore._add(vertices,uvs,into,[col_a[r],col_b[r],col_b[r+1]],face,[ha,hb,hb],0.0)
			IslandShore._add(vertices,uvs,into,[col_a[r],col_b[r+1],col_a[r+1]],face,[ha,hb,ha],0.0)

## One tear point's column of rings, lip to foot (islet frame).
static func _column(islet: RefCounted, i: int, out: Vector2, middle: Vector2, tear: Dictionary, ribs: FastNoiseLite, ledges: FastNoiseLite, top: float, foot: float) -> Array:
	var p: Vector2 = islet.points[i]
	var whole := p+middle
	var s := whole.dot(along(tear))
	var gap := width(tear,s)
	var most := minf(WALL_OUT,gap*WALL_OUT_SHARE)
	var h1 := PlateMesh._hash(i,int(tear.seed) % 7919,21)
	var h2 := PlateMesh._hash(i,int(tear.seed) % 7919,23)
	var lip_y := top-lerpf(WALL_LIP.x,WALL_LIP.y,h1)
	foot = minf(foot,lip_y-0.3)
	var rib := ribs.get_noise_1d(s)
	var column: Array = [Vector3(p.x,top,p.y)]
	var lip_out := lerpf(WALL_LIP_OUT.x,WALL_LIP_OUT.y,h2)
	column.append(_held(islet,Vector3(p.x+out.x*lip_out,lip_y,p.y+out.y*lip_out)))
	var drop := lip_y-foot
	for r in range(SHELVES):
		var t := float(r+1)/float(SHELVES+1)
		# Each shelf's height wanders a little along the tear (ledges).
		var y := lerpf(lip_y,foot,t)+ledges.get_noise_2d(s*1.7,float(r)*11.0)*drop/float(SHELVES+1)*0.4
		var stand := rib*RIBS+ledges.get_noise_2d(s,y)*LEDGES+(PlateMesh._hash(i,r,29)-0.5)*0.3
		# The wall leans back a little toward the hanging rock's foot.
		stand -= t*t*0.6
		var deep := lerpf(SHELF.x,SHELF.y,clampf(ledges.get_noise_2d(s*0.8+40.0,float(r)*7.0)*0.5+0.5,0.0,1.0))
		var back := clampf(stand-deep*0.9,-WALL_BACK,most)
		var front := clampf(stand,-WALL_BACK*0.5,most)
		var shelf_y := minf(y+deep*0.45,lerpf(lip_y,foot,t-0.5/float(SHELVES+1)))
		column.append(_held(islet,Vector3(p.x+out.x*back,shelf_y,p.y+out.y*back)))
		column.append(_held(islet,Vector3(p.x+out.x*front,y,p.y+out.y*front)))
	column.append(Vector3(p.x,foot,p.y))
	return column

## A wall point near the spring's lip held back so the fall pours clear
## (SkyIslet `_behind_lip`).
static func _held(islet: RefCounted, v: Vector3) -> Vector3:
	if float(islet.pond.z) > 0.0 and Vector2(v.x,v.z).distance_to(islet.lip) < 2.5: return islet._behind_lip(v)
	return v

# --- The layout -----------------------------------------------------------------

## Lays member `m` by its relation `rel` to `parent` (the solver's hook):
## true when it stands. Sets `m.offset`, and for the far half its bridge
## (`bridge_to`, `bridge_ends`) and the plan's `cleft`.
static func place(m: Dictionary, parent: Dictionary, rel: Dictionary, placed: Array, plan: Dictionary, rng: RandomNumberGenerator) -> bool:
	var solver: GDScript = load("res://scripts/cluster_solver.gd")
	match str(rel.type):
		"tear":
			if not parent.shape.recipe.has("tear") or not m.shape.recipe.has("tear"): return false
			var near: Vector2 = parent.shape.cleft.middle
			var far: Vector2 = m.shape.cleft.middle
			var at := Vector3(parent.offset.x+far.x-near.x,parent.offset.y+float(m.y),parent.offset.z+far.y-near.y)
			if not solver._clear(m,at,placed,solver.MIN_GAP): return false
			m.offset = at
			var ends := _bridge_ends(parent,m)
			if ends.is_empty(): return false
			m.bridge_to = parent.name
			m.bridge_ends = ends
			var tear: Dictionary = parent.shape.recipe.tear
			var origin: Vector3 = parent.offset-Vector3(near.x,0.0,near.y)
			plan.cleft = {"origin":origin,"along":along(tear),"across":across(tear),"narrow":float(tear.narrow),
				"radius":float(tear.radius),"width":tear.width,"near":parent.name,"far":m.name,"fall_s":float(tear.fall_s),
				"bridge_s":float(ends[2])}
			return true
		"cleft":
			if not plan.has("cleft"): return false
			var cleft: Dictionary = plan.cleft
			var tear: Dictionary = parent.shape.recipe.tear
			var fall_s := float(tear.fall_s)
			for k in range(16):
				var s := wide_s(tear,lerpf(CHUNK_AT.y,CHUNK_AT.x,k/15.0))
				if absf(s-fall_s) < FALL_CLEAR or absf(s-float(cleft.bridge_s)) < FALL_CLEAR: continue
				var q := middle_at(tear,s)
				var at: Vector3 = (cleft.origin as Vector3)+Vector3(q.x,parent.offset.y-(cleft.origin as Vector3).y+float(m.y),q.y)
				if solver._clear(m,at,placed,CHUNK_CLEAR):
					m.offset = at
					cleft.chunk_s = s
					return true
			return false
		"flank":
			var gap: Vector2 = rel.get("gap",Vector2(6.0,12.0))
			var away := Vector2.from_angle(rng.randf()*TAU)
			if parent.shape.recipe.has("tear"): away = across(parent.shape.recipe.tear)*float(parent.shape.recipe.tear.side)
			for k in range(solver.TRIES):
				var angle := away.angle()+rng.randf_range(-1.0,1.0)
				var at: Vector3 = solver._beyond(parent,m,angle,rng.randf_range(gap.x,gap.y))
				if not solver._clear(m,at,placed,solver.MIN_GAP*2.0): continue
				m.offset = at
				return true
			return false
	return false

## The rope bridge across the gap, from the near half to the far one
## standing where it does: [a, b (deck ends, the near half's frame), s],
## where it spans nearest BRIDGE_SPAN within its grade, along the tear's
## BRIDGE_AT, clear of the fall; [] if nowhere will do.
static func _bridge_ends(near: Dictionary, far: Dictionary) -> Array:
	var tear: Dictionary = near.shape.recipe.tear
	var n_mid: Vector2 = near.shape.cleft.middle
	var f_mid: Vector2 = far.shape.cleft.middle
	var lift: float = float(far.offset.y)-float(near.offset.y)
	var way := across(tear)*-float(tear.side)
	var best: Array = []
	var best_score := INF
	for k in range(25):
		var s := wide_s(tear,lerpf(BRIDGE_AT.x,BRIDGE_AT.y,k/24.0))
		if absf(s-float(tear.fall_s)) < FALL_CLEAR: continue
		var q := middle_at(tear,s)
		var a2 := _land_end(near.shape,q-n_mid,-way)
		var b2 := _land_end(far.shape,q-f_mid,way)
		if a2 == Vector2.INF or b2 == Vector2.INF: continue
		var a_whole := a2+n_mid
		var b_whole := b2+f_mid
		var span := a_whole.distance_to(b_whole)
		if span < 3.0 or span > Footbridge.MAX_SPAN-1.0: continue
		var a := Vector3(a_whole.x-n_mid.x,near.shape.ground_at(a2)+0.05,a_whole.y-n_mid.y)
		var b := Vector3(b_whole.x-n_mid.x,far.shape.ground_at(b2)+lift+0.05,b_whole.y-n_mid.y)
		if absf(b.y-a.y) > span*Footbridge.MAX_GRADE*0.85: continue
		var score := absf(span-BRIDGE_SPAN)+absf(b.y-a.y)*1.5
		if score < best_score:
			best_score = score
			best = [a,b,s]
	return best

## Where a bridge's end stands on `shape` (its frame), walking from the
## gap's middle `from` out along `way` onto the land and BRIDGE_INSET on:
## dry, firm ground; Vector2.INF if none within reach.
static func _land_end(shape: RefCounted, from: Vector2, way: Vector2) -> Vector2:
	var p := from
	for k in range(60):
		if shape.on_land(p): break
		p += way*0.2
	if not shape.on_land(p): return Vector2.INF
	p += way*BRIDGE_INSET
	if not shape.on_land(p) or shape.wet(p) or shape.inland(p) < 0.9: return Vector2.INF
	if shape.wet(p+way*1.2) or shape.wet(p-way*0.8): return Vector2.INF
	return p

## A feature this file lays on member `m` (the solver's hook): the
## overlook. False when there is no room.
static func feature(m: Dictionary, f: Dictionary, placed: Array, plan: Dictionary) -> bool:
	if not m.shape.recipe.has("tear") or not plan.has("cleft"): return false
	if str(f.type) == "lip_lanterns": return _lip_lanterns(m,f,plan)
	if str(f.type) != "overlook": return false
	var shape: RefCounted = m.shape
	var tear: Dictionary = shape.recipe.tear
	var mid: Vector2 = shape.cleft.middle
	var way := across(tear)*-float(tear.side)
	var cleft: Dictionary = plan.cleft
	var tries: Array = []
	for k in range(10):
		var off := lerpf(LOOKOUT_OFF.x,LOOKOUT_OFF.y,float(k/2)/4.0)*(1.0 if k % 2 == 0 else -1.0)
		tries.append(float(cleft.fall_s)+off*float(tear.narrow))
	for s: float in tries:
		if absf(s-float(cleft.bridge_s)) < 3.5: continue
		if cleft.has("chunk_s") and absf(s-float(cleft.chunk_s)) < 5.0: continue
		var gap := width(tear,s)
		var length := minf(LOOKOUT.y,gap*LOOKOUT_SHARE)
		if length < LOOKOUT.x: continue
		var start := _land_end(shape,middle_at(tear,s)-mid,-way)
		if start == Vector2.INF: continue
		start -= -way*(BRIDGE_INSET-0.9)
		if not shape.on_land(start) or shape.wet(start): continue
		# Its end is over the gap, out to `length` past the lip.
		var lip := start
		for k in range(30):
			if not shape.on_land(lip+way*0.2): break
			lip += way*0.2
		var end := lip+way*length
		var clear := true
		for p: Dictionary in placed:
			if p == m: continue
			var q := end+Vector2(m.offset.x-p.offset.x,m.offset.z-p.offset.z)
			if p.shape.inside(q) or _near_rim(p.shape,q,2.4): clear = false
		if not clear: continue
		shape.claim(start,1.0)
		var y: float = shape.ground_at(start)+0.12
		var a := Vector3(start.x,y,start.y)
		var b := Vector3(end.x,y,end.y)
		shape.decks.append({"a":a,"b":b,"width":LOOKOUT_WIDTH,"bow":0.0})
		shape.reach = maxf(shape.reach,end.length()+1.0)
		m.features.append({"type":"dock","a":a,"b":b,"lookout":true,"lip":Vector3(lip.x,shape.ground_at(lip),lip.y)})
		return true
	return false

static func _near_rim(shape: RefCounted, q: Vector2, room: float) -> bool:
	for k in range(12):
		if shape.on_land(q+Vector2.from_angle(TAU*k/12.0)*room): return true
	return false

## Lantern posts along `m`'s lip, spread along the tear clear of the
## bridge, the lookout and the fall, each LIP_IN in from the edge with its
## arm out over the gap.
static func _lip_lanterns(m: Dictionary, f: Dictionary, plan: Dictionary) -> bool:
	var shape: RefCounted = m.shape
	var tear: Dictionary = shape.recipe.tear
	var mid: Vector2 = shape.cleft.middle
	var way := across(tear)*-float(tear.side)
	var cleft: Dictionary = plan.cleft
	var count: Vector2i = f.get("count",LIP_LANTERNS)
	# Taken: [s, room] along the tear.
	var taken: Array = [[float(cleft.bridge_s),LIP_CLEAR]]
	for g: Dictionary in m.features:
		if g.get("lookout",false):
			var at: Vector3 = g.a
			taken.append([(Vector2(at.x,at.z)+mid).dot(along(tear)),LIP_CLEAR])
	var laid := 0
	var r := float(tear.radius)
	# From the bridge outward both ways, so the lights gather round it.
	var tries: Array = []
	for k in range(1,40):
		for sign_: float in [1.0,-1.0]: tries.append(float(cleft.bridge_s)+sign_*k*1.0)
	for s: float in tries:
		if laid >= count.y: break
		if absf(s) > r*1.2: continue
		var near := false
		for t: Array in taken: near = near or absf(s-float(t[0])) < float(t[1])
		if near: continue
		if float(tear.side) < 0.0 and absf(s-float(tear.fall_s)) < 3.0: continue
		var p := middle_at(tear,s)-mid
		var edge := Vector2.INF
		for k in range(60):
			if shape.on_land(p):
				edge = p
				break
			p -= way*0.2
		if edge == Vector2.INF: continue
		var at := edge-way*LIP_IN
		if not shape.on_land(at) or shape.wet(at) or shape.inland(at) < 0.5 or shape.wet(at-way*1.0): continue
		shape.claim(at,0.35)
		m.features.append({"type":"post","at":at,"angle":atan2(-way.x,-way.y)})
		taken.append([s,LIP_APART])
		laid += 1
	return laid >= count.x
