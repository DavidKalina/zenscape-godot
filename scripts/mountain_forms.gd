extends RefCounted
## The land brush's forms (docs/scenic/brushes.md, "Mountain forms"). Hill is
## the everyday brush (scripts/land_brush.gd); the others raise one whole
## mountain per press. Press where the summit goes and drag out: the drag adds
## to the brush size to set the spread, and the height follows the spread (a
## ridge runs along the drag instead, centred on the press). The form rises
## while the button is held and finishes rising after release, then weathers
## on a worker: a native `erode` pass over the mountain's own footprint cuts
## gullies and drops scree, and its rock takes the form's colour through the
## painted-ground tint layer. Water is never buried: the lift fades to nothing
## within WATER_GAP of a pond or stream, so a flank parts around it.
##
## Per-vertex noise is built once per world (`prepare`); a tick only scales a
## stored lift, and the lift is reshaped only when the drag moves it.
const Erosion = preload("res://scripts/terrain_erosion.gd")

## The forms in picker order: data only, so a shell can restyle the picker.
## `glyph` names a scripts/glass_chrome.gd GLYPHS entry.
const FORMS := [
	{"id":"hill","title":"Hill","glyph":"land","hint":"Drag to raise land  ·  Shift-drag lowers"},
	{"id":"alpine","title":"Alpine","glyph":"form_alpine","hint":"Press where the peak goes  ·  drag out for a bigger, higher peak"},
	{"id":"ridge","title":"Ridge","glyph":"form_ridge","hint":"Press and drag along the ridge  ·  longer is higher"},
	{"id":"mesa","title":"Mesa","glyph":"form_mesa","hint":"Press for a mesa  ·  drag out for a broader, higher one"},
	{"id":"volcano","title":"Volcano","glyph":"form_volcano","hint":"Press for a cone  ·  drag out for a bigger one"},
	{"id":"tors","title":"Tors","glyph":"form_tors","hint":"Press for a cluster of stacks  ·  drag out to spread them"},
]

## Per form: `spread` (metres from the centre, half the length for a ridge):
## min, max, and the share of the brush size a press starts from; `aspect`
## height per metre of spread; `height` min, max; `rock` its colour (ROCKS);
## `erode` what it weathers with, over STROKE_EROSION.
const SHAPES := {
	"alpine":{"spread":Vector3(3.0,9.5,1.1),"aspect":1.45,"height":Vector2(3.5,14.0),"rock":"granite",
		"erode":{"detail":0.55,"k":0.013,"max_cut":1.2,"deposit":0.45,"channel_area":3.0}},
	"ridge":{"spread":Vector3(3.0,12.0,1.2),"aspect":0.62,"height":Vector2(2.5,10.0),"rock":"granite",
		"erode":{"detail":0.45,"k":0.012,"max_cut":1.0,"deposit":0.45,"channel_area":3.0}},
	"mesa":{"spread":Vector3(3.5,9.5,1.25),"aspect":0.5,"height":Vector2(2.0,5.5),"rock":"sandstone",
		"erode":{"detail":0.1,"k":0.006,"max_cut":0.45,"deposit":0.65,"channel_area":4.0}},
	"volcano":{"spread":Vector3(3.5,9.5,1.3),"aspect":0.95,"height":Vector2(3.0,11.0),"rock":"basalt",
		"erode":{"detail":0.2,"k":0.012,"max_cut":0.8,"deposit":0.4,"channel_area":3.0}},
	"tors":{"spread":Vector3(2.5,7.0,0.9),"aspect":0.6,"height":Vector2(1.8,4.5),"rock":"slate",
		"erode":{"detail":0.12,"k":0.005,"max_cut":0.35,"deposit":0.5,"channel_area":4.0}},
}
## The weathering pass's shared settings; `detail` scales with the height
## (per HEIGHT_REF m). The kernel's plate-edge fade matches land_brush.gd.
const STROKE_EROSION := {"frequency":0.16,"warp":1.3,"slope_ref":1.2,"iterations":24,"jitter":0.6,
	"deposit_slope":0.35,"deposit_cap":0.06,"edge_inner":11.6,"edge_outer":13.4}
const HEIGHT_REF := 8.0
## Rock colours (sRGB), picked per tint cell. Sandstone bands by height
## (BAND m each, bottom to top), and basalt reddens toward the crater
## (`summit`). They paint steep ground (ROCK_SLOPE, as a gradient) and the
## upper share of the form (SUMMIT), never its gentle green foot. Snow
## (the plain's snowline, about 6.55 m) still settles over them.
const ROCKS := {
	"granite":{"colors":["a8a49b","bab5ab","96928a"],"weight":0.8},
	"slate":{"colors":["5e6974","6d7882","525c67"],"weight":0.85},
	"sandstone":{"colors":["b8683f","d49660","e4be8a","c77b4c"],"weight":0.9,"banded":true},
	"basalt":{"colors":["3e3a38","4a4542","36312f"],"weight":0.9,"summit":"6e3d2c"},
}
const BAND := 0.55
const ROCK_SLOPE := Vector2(0.45,0.9)
const SUMMIT := Vector2(0.35,0.7)
## A mesa's flat cap takes its lightest sandstone at this weight.
const CAP_WEIGHT := 0.55
## The lift fades from nothing at WATER_GAP.x metres from water to all of it
## at .y, and over the plate's last metres (EDGE, as |x| or |z|), so a form
## never buries a pond or a stream nor walls the plate's rim.
const WATER_GAP := Vector2(1.0,2.6)
const EDGE := Vector2(11.4,13.6)
## Seconds a mountain takes to rise; a quick click finishes rising after the
## button comes up.
const RISE_SECONDS := 2.2
## A drag shorter than this keeps a ridge on its view-facing default.
const AIM_MIN := 0.5

var seed_value := -1
var _points := 0
var _jag := PackedFloat32Array()
var _lump := PackedFloat32Array()
var _fine := PackedFloat32Array()

## The mountain in progress: `active` from press until it lands.
var active := false
var form := ""
var center := Vector2.ZERO
var spread := 0.0
var height := 0.0
var direction := Vector2.RIGHT
var rise := 0.0
## Ground height at the press; flat caps stand on it.
var ground := 0.0
## World-space XZ bounds of the lift so far.
var bounds := Rect2()
var last_shape_usec := 0
var last_weather_usec := 0
var _start := 0.0
var _strength_scale := 1.0
var _base := PackedFloat32Array()
var _keep := PackedFloat32Array()
var _lift := PackedFloat32Array()
var _reach := Rect2()
var _touched := PackedInt32Array()
var _aretes := PackedFloat32Array()
var _stacks: Array[Vector4] = []
var _salt := 0
var _has_bounds := false
## Tint cells (the meadow grid) the rock must leave alone, 1 each: set after
## `begin` by a caller that keeps the hand's bare earth (scripts/edge_spring.gd);
## empty paints everywhere.
var tint_lock := PackedByteArray()
## The ground the rock measures its share of height from, when not the
## ground under the mountain: set after `begin` by a caller that lifts a
## plateau under the peaks (scripts/edge_spring.gd), so the plateau's top
## stays green. Empty is the ground under it.
var rock_base := PackedFloat32Array()

static func form_ids() -> Array:
	return FORMS.map(func(entry: Dictionary) -> String: return entry.id)

static func form_entry(id: String) -> Dictionary:
	for entry: Dictionary in FORMS:
		if entry.id == id: return entry
	return {}

## The form `step` places along the list from `id`, wrapping.
static func cycled(id: String, step: int) -> String:
	var ids := form_ids()
	return ids[posmod(maxi(ids.find(id),0)+step,ids.size())]

## Rebuild the per-vertex noise when the seed or mesh changes.
func prepare(data: NativeTerrainData, world_seed: int) -> void:
	if world_seed == seed_value and _points == data.points.size(): return
	seed_value = world_seed
	_points = data.points.size()
	var jag := FastNoiseLite.new()
	jag.seed = world_seed+401
	jag.frequency = 0.32
	jag.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	jag.fractal_octaves = 3
	var lump := FastNoiseLite.new()
	lump.seed = world_seed+433
	lump.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	lump.frequency = 0.13
	lump.fractal_octaves = 2
	var fine := FastNoiseLite.new()
	fine.seed = world_seed+467
	fine.noise_type = FastNoiseLite.TYPE_VALUE
	fine.frequency = 0.9
	_jag.resize(_points)
	_lump.resize(_points)
	_fine.resize(_points)
	for i in range(_points):
		var p: Vector2 = data.points[i]
		_jag[i] = clampf(jag.get_noise_2d(p.x,p.y)*0.5+0.5,0.0,1.0)
		_lump[i] = clampf(lump.get_noise_2d(p.x,p.y)*0.5+0.5,0.0,1.0)
		_fine[i] = clampf(fine.get_noise_2d(p.x,p.y)*0.5+0.5,0.0,1.0)

## Start a mountain of `form_id` at `press`. `size` is the brush size (the
## spread a press starts from), `strength` scales the height, and `view_right`
## lies a click's ridge across the view.
func begin(data: NativeTerrainData, form_id: String, press: Vector2, size: float, strength: float, view_right: Vector2) -> void:
	var shape: Dictionary = SHAPES[form_id]
	active = true
	form = form_id
	center = press
	rise = 0.0
	_base = data.heights.duplicate()
	rock_base = PackedFloat32Array()
	var at: Variant = data.sample(press,_base)
	ground = float(at) if at != null else 0.0
	_start = clampf(size*shape.spread.z,shape.spread.x,shape.spread.y)
	_strength_scale = clampf(0.75+0.25*strength,0.8,1.5)
	direction = view_right.normalized() if view_right.length() > 0.01 else Vector2.RIGHT
	_salt = hash([seed_value,form_id,press.snapped(Vector2.ONE*0.01)])
	var rng := RandomNumberGenerator.new()
	rng.seed = _salt
	# Alpine arêtes: three to five, roughly spread round the horn.
	_aretes = PackedFloat32Array()
	var count := rng.randi_range(3,5)
	var turn := rng.randf()*TAU
	for k in range(count): _aretes.append(turn+TAU*(float(k)+rng.randf_range(-0.22,0.22))/count)
	# Tors: stacks as (x, z) in spread units, radius share, height share.
	_stacks.clear()
	for k in range(rng.randi_range(4,6)):
		var angle := rng.randf()*TAU
		var out := 0.0 if k == 0 else rng.randf_range(0.25,0.6)
		_stacks.append(Vector4(cos(angle)*out,sin(angle)*out,rng.randf_range(0.2,0.32),rng.randf_range(0.55,1.0) if k > 0 else 1.0))
	_keep = _keep_out(data)
	_lift.resize(_points)
	_lift.fill(0.0)
	_touched = PackedInt32Array()
	_reach = Rect2()
	bounds = Rect2()
	_has_bounds = false
	tint_lock = PackedByteArray()
	spread = -1.0
	aim(data,press)

## Follow the pointer (on the press's ground plane). True when the form
## reshaped.
func aim(data: NativeTerrainData, point: Vector2) -> bool:
	var shape: Dictionary = SHAPES[form]
	var drag := point-center
	var next_spread := clampf(_start+drag.length(),shape.spread.x,shape.spread.y)
	var next_direction := direction
	if form == "ridge" and drag.length() > AIM_MIN: next_direction = drag.normalized()
	if absf(next_spread-spread) < 0.04 and next_direction.dot(direction) > 0.9995: return false
	spread = next_spread
	direction = next_direction
	height = clampf(spread*float(shape.aspect)*_strength_scale,shape.height.x,shape.height.y)
	_reshape(data)
	return true

## Rise by `seconds`; writes the heights. Returns how fast it is rising now,
## 0..1 of its quickest.
func advance(data: NativeTerrainData, seconds: float) -> float:
	var before := _eased(rise)
	rise = minf(1.0,rise+seconds/RISE_SECONDS)
	_apply(data)
	return clampf((_eased(rise)-before)/maxf(seconds,0.001)*RISE_SECONDS/1.5,0.0,1.0)

func risen() -> bool:
	return rise >= 1.0

## Finish rising at once.
func settle(data: NativeTerrainData) -> void:
	rise = 1.0
	_apply(data)

static func _eased(t: float) -> float:
	return t*t*(3.0-2.0*t)

func _apply(data: NativeTerrainData) -> void:
	var e := _eased(rise)
	var heights := data.heights
	for i in _touched: heights[i] = minf(_base[i]+_lift[i]*e,NativeTerrainData.MAX_HEIGHT)
	data.heights = heights

## Recompute the full lift for the current spread and direction over every
## vertex this mountain has reached, so a shrinking drag lets land back down.
func _reshape(data: NativeTerrainData) -> void:
	var started := Time.get_ticks_usec()
	var reach := _footprint()
	_reach = reach if not _reach.has_area() else _reach.merge(reach)
	_touched = PackedInt32Array()
	for i in range(_points):
		var p: Vector2 = data.points[i]
		if not _reach.has_point(p): continue
		_touched.append(i)
		var lift := 0.0
		if reach.has_point(p) and _keep[i] > 0.0: lift = maxf(0.0,_stamp(i,p))*_keep[i]
		_lift[i] = lift
		if lift > 0.02:
			bounds = bounds.expand(p) if _has_bounds else Rect2(p,Vector2.ZERO)
			_has_bounds = true
	last_shape_usec = Time.get_ticks_usec()-started

func _footprint() -> Rect2:
	var reach := spread*1.3
	if form == "ridge":
		var ends := [center-direction*spread,center+direction*spread]
		var width := _ridge_width()*1.3
		var box := Rect2(ends[0],Vector2.ZERO).expand(ends[1])
		return box.grow(width)
	return Rect2(center-Vector2.ONE*reach,Vector2.ONE*reach*2.0)

func _ridge_width() -> float:
	return clampf(spread*0.55,2.2,5.5)

## The form's lift over the ground at vertex `i`, before the keep-out.
func _stamp(i: int, p: Vector2) -> float:
	var jag: float = _jag[i]
	var lump: float = _lump[i]
	var fine: float = _fine[i]
	var base: float = _base[i]
	var d := p-center
	var r := d.length()/spread
	match form:
		"alpine":
			# A horn: concave faces to a sharp summit, arêtes standing proud
			# between hollowed cirques, crags over the flanks.
			var rw := r*(1.0+(lump-0.5)*0.4)
			if rw >= 1.0: return 0.0
			var theta := atan2(d.y,d.x)
			var arete := 0.0
			for angle in _aretes: arete = maxf(arete,1.0-absf(angle_difference(theta,angle))/0.6)
			arete = arete*arete*smoothstep(0.02,0.25,rw)
			var profile := pow(1.0-rw,1.9)
			var crag := (jag-0.5)*0.16*rw*(1.0-rw)*4.0
			var shoulder := pow(maxf(0.0,1.0-rw),1.2)*0.12*arete
			return height*(profile*(0.8+0.2*arete)+shoulder+crag)
		"ridge":
			# A knife-edge crest centred on the press, serrated, one flank
			# steeper than the other, tapering at both ends.
			var along := d.dot(direction)/spread
			var across := d.dot(Vector2(-direction.y,direction.x))
			var t := clampf(along,-1.0,1.0)
			var off := Vector2(along-t,0.0).length()*spread
			var width := _ridge_width()*(0.85+0.3*lump)*(1.0 if across > 0.0 else 0.72)
			var q := Vector2(absf(across)/width,off/width).length()
			if q >= 1.0: return 0.0
			var crest := (0.5+0.5*cos(t*PI*0.5))*(0.82+0.18*jag)
			var summit := 1.0+0.12*exp(-pow((t-0.18)/0.25,2.0))
			return height*crest*summit*pow(1.0-q,1.45)
		"mesa":
			# A flat cap on the press's ground, a caprock cliff, a bench, a
			# lower cliff and a talus apron. The outline wanders.
			var rw := r*(1.0+(lump-0.5)*0.55+(fine-0.5)*0.1)
			if rw >= 1.0: return 0.0
			var rel := 1.0
			if rw > 0.5: rel = lerpf(1.0,0.74,smoothstep(0.5,0.6,rw))
			if rw > 0.6: rel = lerpf(0.74,0.64,(rw-0.6)/0.1)
			if rw > 0.7: rel = lerpf(0.64,0.26,smoothstep(0.7,0.8,rw))
			if rw > 0.8: rel = 0.26*pow((1.0-rw)/0.2,1.6)
			# The cap and cliffs stand level on the press's ground.
			var flat := 1.0-smoothstep(0.7,0.95,rw)
			return lerpf(base+height*rel,ground+height*rel,flat)-base
		"volcano":
			# A concave cone, ribbed, with a crater and a lipped rim.
			var rw := r*(1.0+(lump-0.5)*0.18)
			if rw >= 1.0: return 0.0
			var crater := 0.2
			var cone := pow(1.0-maxf(rw,crater),1.5)
			var rib := 1.0+0.07*cos(atan2(d.y,d.x)*9.0+lump*6.0)*smoothstep(0.25,0.6,rw)
			var h := height*cone/pow(1.0-crater,1.5)*rib
			if rw < crater: h -= height*0.24*(1.0-pow(rw/crater,2.0))
			return h+(jag-0.5)*0.08*height*rw*(1.0-rw)
		"tors":
			# Blocky stacks of split slate on a low swell, tops tilted along
			# the bedding.
			if r >= 1.0: return 0.0
			var swell := height*0.3*pow(1.0-r*r,2.0)
			var best := 0.0
			for stack in _stacks:
				var local := (p-(center+Vector2(stack.x,stack.y)*spread))/(spread*stack.z)
				var rotated := local.rotated(float(posmod(_salt,628))*0.01)
				var q := pow(pow(absf(rotated.x),4.0)+pow(absf(rotated.y*1.3),4.0),0.25)*(1.0+(fine-0.5)*0.25)
				if q >= 1.0: continue
				var top := height*stack.w*(1.0+rotated.x*0.12)
				best = maxf(best,top*(1.0-smoothstep(0.7,1.0,q)))
			return maxf(swell,best+swell*0.4)*(1.0-smoothstep(0.85,1.0,r))
	return 0.0

## 1 where the form may lift, fading to 0 near water and the plate's rim.
func _keep_out(data: NativeTerrainData) -> PackedFloat32Array:
	var keep := PackedFloat32Array()
	keep.resize(_points)
	for i in range(_points):
		var p: Vector2 = data.points[i]
		keep[i] = 1.0-smoothstep(EDGE.x,EDGE.y,maxf(absf(p.x),absf(p.y)))
	if data.ponds.is_empty() and data.streams.is_empty(): return keep
	# Wet cells on the 0.5 m cover grid, then a chamfer distance out from them.
	var side := data.MEADOW_CELLS
	var step := data.MEADOW_STEP
	var far := 1e9
	var distance := PackedFloat32Array()
	distance.resize(side*side)
	distance.fill(far)
	var wet := PackedVector2Array()
	for pond: Dictionary in data.ponds:
		for v in data.pond_surface(pond): wet.append(Vector2(v.x,v.z))
		wet.append(Vector2(pond.x,pond.z))
	for stream: Dictionary in data.streams:
		var points: Array = stream.get("pts",[])
		var width := float(stream.get("width",0.5))*0.5
		for k in range(points.size()-1):
			var a := Vector2(points[k].x,points[k].z)
			var b := Vector2(points[k+1].x,points[k+1].z)
			var steps := maxi(1,ceili(a.distance_to(b)/0.25))
			for s in range(steps+1):
				var at := a.lerp(b,float(s)/steps)
				for offset: Vector2 in [Vector2.ZERO,Vector2(width,0),Vector2(-width,0),Vector2(0,width),Vector2(0,-width)]: wet.append(at+offset)
	for p in wet:
		var x := floori((p.x+14.0)/step)
		var z := floori((p.y+14.0)/step)
		if x >= 0 and z >= 0 and x < side and z < side: distance[z*side+x] = 0.0
	var diagonal := step*1.4142
	for z in range(side):
		for x in range(side):
			var c := z*side+x
			var best: float = distance[c]
			if x > 0: best = minf(best,distance[c-1]+step)
			if z > 0:
				best = minf(best,distance[c-side]+step)
				if x > 0: best = minf(best,distance[c-side-1]+diagonal)
				if x < side-1: best = minf(best,distance[c-side+1]+diagonal)
			distance[c] = best
	for z in range(side-1,-1,-1):
		for x in range(side-1,-1,-1):
			var c := z*side+x
			var best: float = distance[c]
			if x < side-1: best = minf(best,distance[c+1]+step)
			if z < side-1:
				best = minf(best,distance[c+side]+step)
				if x < side-1: best = minf(best,distance[c+side+1]+diagonal)
				if x > 0: best = minf(best,distance[c+side-1]+diagonal)
			distance[c] = best
	for i in range(_points):
		var p: Vector2 = data.points[i]
		var x := clampi(floori((p.x+14.0)/step),0,side-1)
		var z := clampi(floori((p.y+14.0)/step),0,side-1)
		keep[i] *= smoothstep(WATER_GAP.x,WATER_GAP.y,distance[z*side+x])
	return keep

## The finished mountain's weathering and rock colour as a pure-data callable
## over detached copies taken now. It returns {"moved","heights","tint",
## "usec"}; the caller publishes both only while the terrain still holds the
## heights they were taken from. Empty when nothing rose.
func weather_job(data: NativeTerrainData) -> Callable:
	if not _has_bounds: return Callable()
	var region := bounds.grow(Erosion.CELL*2.0).intersection(Rect2(-14,-14,28,28))
	if region.size.x <= 0.0 or region.size.y <= 0.0: return Callable()
	preload("res://scripts/native_terrain_kernels.gd").get_kernel()
	var snapshot: NativeTerrainData = preload("res://scripts/native_terrain_snapshot.gd").for_height(data)
	var shape: Dictionary = SHAPES[form]
	var settings := STROKE_EROSION.duplicate()
	settings.merge(shape.erode,true)
	settings.detail = float(settings.detail)*clampf(height/HEIGHT_REF,0.4,1.4)
	settings.merge({"size":Erosion.SIZE,"cell":Erosion.CELL,"origin":Erosion.ORIGIN,"seed":(_salt+7919)&0xffffffff})
	var job := {"base":(_base if rock_base.is_empty() else rock_base).duplicate(),"lift":_lift.duplicate(),"keep":_keep.duplicate(),"tint":data.tint.duplicate(),
		"region":region,"settings":settings,"rock":ROCKS[shape.rock],"form":form,"height":height,"ground":ground,"salt":_salt,"lock":tint_lock.duplicate()}
	return func() -> Dictionary: return _weathered(snapshot,job)

## `data` is a detached copy. Erodes only grid cells the mountain lifted (the
## rest is locked, so the plain and any water stay as they were), then paints
## its rock.
static func _weathered(data: NativeTerrainData, job: Dictionary) -> Dictionary:
	var started := Time.get_ticks_usec()
	var result := {"moved":false,"heights":data.heights,"tint":PackedFloat32Array(),"usec":0}
	var size: int = Erosion.SIZE
	var region: Rect2 = job.region
	var lift: PackedFloat32Array = job.lift
	var keep: PackedFloat32Array = job.keep
	var base_grid := PackedFloat64Array()
	var fixed := PackedByteArray()
	base_grid.resize(size*size)
	fixed.resize(size*size)
	var any := false
	for j in range(size):
		for i in range(size):
			var p := Vector2(Erosion.ORIGIN+i*Erosion.CELL,Erosion.ORIGIN+j*Erosion.CELL)
			var h: Variant = data.sample(p,data.heights)
			var c := j*size+i
			base_grid[c] = float(h) if h != null else 0.0
			var inside := h != null and region.has_point(p) and not data.is_void(p)
			if inside:
				var raised: Variant = data.sample(p,lift)
				var kept: Variant = data.sample(p,keep)
				inside = raised != null and float(raised) > 0.08 and float(kept) > 0.5
			fixed[c] = 0 if inside else 1
			any = any or inside
	var heights := data.heights
	if any:
		var delta := Erosion.erode(base_grid,fixed,job.settings)
		if delta.size() == size*size:
			var reach := region.grow(Erosion.CELL)
			for i in range(data.points.size()):
				var p: Vector2 = data.points[i]
				if not reach.has_point(p) or keep[i] <= 0.0: continue
				var change := Erosion.sample(delta,p.x,p.y)*minf(1.0,keep[i]*2.0)
				if absf(change) < 0.0005: continue
				heights[i] = clampf(heights[i]+change,NativeTerrainData.MIN_HEIGHT,NativeTerrainData.MAX_HEIGHT)
				result.moved = true
	data.heights = heights
	result.heights = heights
	result.tint = _rock_tint(data,job)
	result.usec = Time.get_ticks_usec()-started
	return result

## Paint the form's rock over its steeps and upper share, onto the tint layer.
static func _rock_tint(data: NativeTerrainData, job: Dictionary) -> PackedFloat32Array:
	var tint: PackedFloat32Array = job.tint
	var rock: Dictionary = job.rock
	var colors: Array = rock.colors.map(func(hex: String) -> Color: return Color(hex).srgb_to_linear())
	var summit := Color(str(rock.get("summit","000000"))).srgb_to_linear()
	var tall: float = job.height
	var base: PackedFloat32Array = job.base
	var region: Rect2 = job.region
	var lock: PackedByteArray = job.get("lock",PackedByteArray())
	var side := data.MEADOW_CELLS
	var step := data.MEADOW_STEP
	var low := Vector2i(clampi(floori((region.position.x+14.0)/step),0,side-1),clampi(floori((region.position.y+14.0)/step),0,side-1))
	var high := Vector2i(clampi(floori((region.end.x+14.0)/step),0,side-1),clampi(floori((region.end.y+14.0)/step),0,side-1))
	for z in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			if not lock.is_empty() and lock[z*side+x] != 0: continue
			var p := data.meadow_position(x,z)+Vector2.ONE*step*0.5
			var h: Variant = data.sample(p,data.heights)
			var b: Variant = data.sample(p,base)
			if h == null or b == null: continue
			var share := (float(h)-float(b))/maxf(tall,0.5)
			if share < 0.04: continue
			var e: Variant = data.sample(p+Vector2(0.35,0),data.heights)
			var w: Variant = data.sample(p-Vector2(0.35,0),data.heights)
			var n: Variant = data.sample(p+Vector2(0,0.35),data.heights)
			var s: Variant = data.sample(p-Vector2(0,0.35),data.heights)
			if e == null or w == null or n == null or s == null: continue
			var slope := Vector2(float(e)-float(w),float(n)-float(s)).length()/0.7
			var weight := maxf(smoothstep(ROCK_SLOPE.x,ROCK_SLOPE.y,slope),smoothstep(SUMMIT.x,SUMMIT.y,share)*0.85)*float(rock.weight)
			var roll := float(hash([job.salt,x,z])%1000)/1000.0
			var color: Color = colors[int(roll*colors.size())%colors.size()]
			if rock.get("banded",false):
				var band := floori((float(h)-float(job.ground))/BAND+roll*0.35)
				color = colors[posmod(band,colors.size())]
			if job.form == "mesa" and share > 0.92 and slope < 0.4:
				color = colors[2]
				weight = maxf(weight,CAP_WEIGHT)
			if rock.has("summit"): color = color.lerp(summit,smoothstep(0.7,0.95,share)*0.7)
			if weight <= 0.01: continue
			var k := (z*side+x)*NativeTerrainTint.STRIDE
			var before: float = tint[k+3]
			var after := maxf(before,weight)
			var mix := 1.0 if before <= 0.0 else clampf(weight/after,0.0,1.0)
			tint[k] = lerpf(tint[k],color.r,mix)
			tint[k+1] = lerpf(tint[k+1],color.g,mix)
			tint[k+2] = lerpf(tint[k+2],color.b,mix)
			tint[k+3] = minf(after,1.0)
	return tint
