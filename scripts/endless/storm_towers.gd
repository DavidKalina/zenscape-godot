extends RefCounted
## The storm's cumulonimbus: a few giant towers standing in the front's core
## (scripts/endless/storm_front.gd), riding its line, kilometres taller than
## the flight ceiling, so the storm reads from 10 km off.
##
## Each is a baked tower (scripts/sky_tower.gd: a heap of round lobes in a
## smooth union, baked to a coarse float 3D distance texture) scaled up
## SCALE times, its frame's sea at BASE m over the world's sea. The cloud
## march (shaders/endless_cloud_march.glsl, `st_*`) reads the bake, carves
## the storm's own heaps into it (shaders/storm_cloud.glslinc) and lights
## it as it lights the pushed cells, so it is the same weather.
##
## It rises as the front builds: each tower's `grown` follows
## StormFront.intensity through its own window (RISE, staggered), baked in
## STAGES stages on a worker, two stages a texture (red, green) so the march
## morphs between them; a stage not baked yet holds the last one.
##
## Knobs: --storm-towers=0 (none), --storm-tower-scale=X.

const SkyTower = preload("res://scripts/sky_tower.gd")
const Field = preload("res://scripts/endless/land_field.gd")

## How many towers, at most (the march has 3 slots: spare[6..17]).
const COUNT := 3
## Each tower's place on the front's frame: along the line (m) and behind
## the leading edge, in the core (m), and the seed of its shape.
const ALONG := [-2700.0, 400.0, 3100.0]
const BEHIND := [1700.0, 2300.0, 1450.0]
const SEEDS := [9137, 4421, 6810]
## The baked tower's frame scaled up this much: 330-480 m tall over its sea
## there (a little more once widened), so about 4-6 km here.
const SCALE := 12.0
## The isle's tower is a towering cumulus, a column three times as tall as
## it is through; a cumulonimbus is broad: its lobes are set this much
## farther out and made this much bigger before the bake
## (--storm-tower-widen=X), so the distances stay true.
const WIDEN := 1.5
## The tower frame's sea (SkyTower.SEA) stands this high over the world's sea.
const BASE := 330.0
## Stages a rise is baked in, and the bake's cells along its widest side.
const STAGES := 12
const CELLS := 36
## Each tower's rise over the storm's intensity: grown 0 at RISE.x, whole
## at RISE.y, later by STAGGER for each.
const RISE := Vector2(0.12, 0.88)
const STAGGER := [0.0, 0.1, 0.05]
## A tower's first bake fades in over this long (s).
const FADE_IN := 3.0

var storm: RefCounted
var scale := SCALE
## The light taps' share on a tower (0: the march's ST_TAPS).
var taps := 0.0
var towers: Array[Dictionary] = []

static func from_args(front: RefCounted, args: PackedStringArray) -> RefCounted:
	var count := COUNT
	var at_scale := SCALE
	var widen_by := WIDEN
	var debug_mode := 0.0
	for a in args:
		if a.begins_with("--storm-towers="): count = clampi(int(a.get_slice("=",1)),0,COUNT)
		elif a.begins_with("--storm-tower-scale="): at_scale = maxf(float(a.get_slice("=",1)),0.5)
		elif a.begins_with("--storm-tower-taps="): debug_mode = float(a.get_slice("=",1))
		elif a.begins_with("--storm-tower-widen="): widen_by = maxf(float(a.get_slice("=",1)),1.0)
	if count <= 0: return null
	var t: RefCounted = (load("res://scripts/endless/storm_towers.gd") as GDScript).new()
	t.storm = front
	t.scale = at_scale
	t.taps = debug_mode
	for i in count:
		var shape: RefCounted = SkyTower.make(int(SEEDS[i]))
		_widen(shape,widen_by)
		t.towers.append({
			"shape": shape,
			"along": float(ALONG[i]), "behind": float(BEHIND[i]),
			"window": Vector2(RISE.x+float(STAGGER[i]),minf(RISE.y+float(STAGGER[i]),0.99)),
			"bakes": {}, "pair": -1, "texture": null, "box": AABB(),
			"job": -1, "job_k": -1, "result": {},
			"show": 0.0, "morph": 0.0, "grown": 0.0, "lobes": PackedVector4Array(), "lobes_g": -1.0,
		})
	return t

## Broadens a SkyTower's heap of lobes by `by` across (positions and
## radii), and its crest and box with it.
static func _widen(shape: RefCounted, by: float) -> void:
	if by == 1.0: return
	var out := PackedVector4Array()
	for l: Vector4 in shape.lobes: out.append(Vector4(l.x*by,l.y,l.z*by,l.w*by))
	shape.lobes = out
	shape.lean *= by
	shape.blend *= by
	var crest := SkyTower.SEA
	var lo := Vector3(INF,INF,INF)
	var hi := -lo
	for l in out:
		crest = maxf(crest,l.y+l.w)
		lo = lo.min(Vector3(l.x,l.y,l.z)-Vector3.ONE*l.w)
		hi = hi.max(Vector3(l.x,l.y,l.z)+Vector3.ONE*l.w)
	lo -= Vector3.ONE*SkyTower.SWELL
	hi += Vector3.ONE*SkyTower.SWELL
	lo.y = maxf(lo.y,SkyTower.SEA-20.0)
	shape.crest = crest
	shape.box = AABB(lo,hi-lo)

## How far through its rise tower `t` stands now (0..1).
func _grown(t: Dictionary) -> float:
	var w: Vector2 = t.window
	var x := clampf((float(storm.intensity)-w.x)/(w.y-w.x),0.0,1.0)
	return x*x*(3.0-2.0*x)

## Each frame: start and take bakes, set each tower's morph and fade.
func advance(delta: float) -> void:
	for t in towers:
		var g := _grown(t)
		t.grown = g
		var k := clampi(floori(g*STAGES),0,STAGES-1)
		# A finished job: its pair becomes the texture.
		if int(t.job) >= 0 and WorkerThreadPool.is_task_completed(int(t.job)):
			WorkerThreadPool.wait_for_task_completion(int(t.job))
			t.job = -1
			var r: Dictionary = t.result
			if not r.is_empty():
				t.texture = SkyTower.pair_texture(r.a,r.slices)
				t.pair = int(t.job_k)
				var shape: RefCounted = t.shape
				t.box = shape.box
		if int(t.job) < 0 and int(t.pair) != k:
			_start(t,k)
		var pair := int(t.pair)
		if pair < 0:
			t.show = 0.0
			continue
		t.show = minf(float(t.show)+delta/FADE_IN,1.0)
		var f := g*STAGES-pair
		t.morph = clampf(f,0.0,1.0)

func _start(t: Dictionary, k: int) -> void:
	t.job_k = k
	t.result = {}
	var shape: RefCounted = t.shape
	var bakes: Dictionary = t.bakes
	t.job = WorkerThreadPool.add_task(func() -> void:
		var a: Dictionary = bakes[k] if bakes.has(k) else shape.bake(float(k)/STAGES,CELLS)
		var b: Dictionary = bakes[k+1] if bakes.has(k+1) else shape.bake(float(k+1)/STAGES,CELLS)
		t.result = {"a":a,"slices":SkyTower.pair_slices(a,b)}
		# Only the two kept: the next pair shares one.
		bakes.clear()
		bakes[k] = a
		bakes[k+1] = b)

## Waits for every bake (stills, tests).
func flush() -> void:
	for t in towers:
		if int(t.job) >= 0: WorkerThreadPool.wait_for_task_completion(int(t.job))
	advance(0.0)

## Where tower `t`'s frame origin stands in the world now.
func origin(t: Dictionary) -> Vector3:
	var e: Vector2 = storm.edge()
	var h: Vector2 = storm.heading()
	var side := Vector2(-h.y,h.x)
	var xz: Vector2 = e-h*float(t.behind)+side*float(t.along)
	return Vector3(xz.x,Field.SEA_Y+BASE-SkyTower.SEA*scale,xz.y)

## The bodies' textures, for the march's body0..2.
func textures() -> Array:
	var out := []
	for t in towers: out.append(t.texture if float(t.show) > 0.0 else null)
	return out

## The march's params: spare[5].y the count, spare[6+4i..9+4i] each tower
## (frame origin, scale up; box middle, morph; box half, show; foot and top
## y, scale across).
func put(p: PackedFloat32Array) -> void:
	p[89] = float(towers.size())
	p[90] = taps
	for i in towers.size():
		var t := towers[i]
		var o := 92+16*i
		var shape: RefCounted = t.shape
		var box: AABB = t.box
		var at := origin(t)
		var mid := box.get_center()
		var half := box.size*0.5
		var show := float(t.show) if float(t.show) > 0.0 and t.texture != null else 0.0
		var vals := [at.x,at.y,at.z,scale, mid.x,mid.y,mid.z,float(t.morph), half.x,half.y,half.z,show,
			at.y+(box.position.y)*scale, at.y+_top(t)*scale, scale, 0.0]
		for j in 16: p[o+j] = vals[j]

## The top of tower `t` as it stands now (its frame): the rising front.
func _top(t: Dictionary) -> float:
	var shape: RefCounted = t.shape
	var g := (float(t.pair)+float(t.morph))/STAGES
	return clampf(float(shape.front(g)),SkyTower.SEA+20.0,float(shape.crest))

## How far world point `p` is into a tower's smooth body (m), or a large
## negative number outside every one: the CPU's mirror (no heaps).
func depth(p: Vector3) -> float:
	var best := -1e9
	for t in towers:
		if float(t.show) <= 0.0: continue
		var shape: RefCounted = t.shape
		var q := (p-origin(t))/scale
		var box: AABB = t.box
		if not box.grow(1.0).has_point(q): continue
		var g := (float(t.pair)+float(t.morph))/STAGES
		if absf(g-float(t.lobes_g)) > 0.02:
			t.lobes = shape.lobes_at(g)
			t.lobes_g = g
		# Cut at its foot as the march cuts it (ST_FOOT 60: under = y -
		# foot - 18 m, at 0.8, lifted by its lumps, ST_UNDER 150 deep: half
		# that here), so under the flat base is out of it.
		var foot: float = origin(t).y+box.position.y*scale
		var body := -float(shape._distance(q,t.lobes))*scale-(1.0-float(t.show))*300.0
		best = maxf(best,minf(body,(p.y-foot-18.0-75.0)*0.8))
	return best
