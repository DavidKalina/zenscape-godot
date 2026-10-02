extends RefCounted
## Flowers painted from the hand (docs/scenic/handful.md "Flower seed"; the
## materials bar's flower slots, scripts/hand_materials.gd). The tool is a
## paintbrush: with a flower in hand, press and drag over the land and the
## flowers come up under the brush as it goes, growing in at once. Spreading
## by the wind (the veil, scripts/pollen_cloud.gd) is kept for what already
## grows: pollen from plants and pollinators, later.
##
## One stroke, press to release, is one of these. The brush lays a coat on a
## field over the plate (CELL m cells), in FlowerSowing's units (seed per
## square metre: a drift starts at THIN and stands full at FULL):
##
## - **Dragged,** each pass lays PASS at the middle of the brush, the moment
##   the brush is over the ground, whatever its size or the drag's speed: the
##   brush's profile is laid at once wherever it covers (`_touch`, the most
##   it has laid on a cell this visit), and when the brush has gone on past a
##   cell what it laid there is banked (`_field`). So the flowers come up under
##   the brush itself, not behind it; one pass comes up as a loose drift, and
##   going over it again (the brush leaving and coming back) adds another
##   pass, packing it toward a full drift's core.
## - **Held still** (or barely moving, under LINGER m/s) it also lays
##   PER_SECOND at the middle each second (LINGER_FAST of that while it moves
##   quickly): lingering, or scrubbing in place, thickens.
## - **A tap** lays one small dab (TAP at the middle, TAP_SHARE of the brush
##   across), a little round drift where the pointer is.
## - Each dab is full to INNER of the brush's radius and eases to nothing at
##   its rim, and FlowerSowing's feather noise breaks the edge, so a stroke's
##   edge feathers softly.
##
## What stands where the coat lies is the meadow types' composition, exactly
## as a sown drift's (scripts/flower_sowing.gd `grow`): the world's own
## jittered 0.2 m lattice, each spot kept at `pow(presence, 1.2)` times the
## kind's packing, the kind the type's (drifts of one kind, a few companions),
## sunflowers only on their rows. The ground decides as ever (`suits`: no
## flowers on water, rock, steep ground, near snow, under crowns or on
## stones). Each spot is judged once a stroke (`_spots`), and only once its
## coat could raise it, so a frame only compares numbers.
##
## **Thinning** (Shift, as the Brush's Shift wipes): the same brush lays its
## coat as a thinning instead. Each flower under it has its own share
## (`_share`) and goes when the coat over it passes that share of the way
## from THIN to FULL, so one pass thins a drift and going over it clears it,
## its edge feathered. Any flower goes, the hand's or the world's; the cell it
## stood in turns hand work, as a plucked plant's does, so emergence does not
## sow it straight back.
##
## The caller opens the undo step before the first dab and closes it after
## `finish`, which lays the ground's faint wash under what was painted.
##
## Preloaded, not a class_name.

const FlowerSowing = preload("res://scripts/flower_sowing.gd")
const MeadowTypes = preload("res://scripts/meadow_types.gd")
const Variety = preload("res://scripts/seeded_variety.gd")
const Emergence = preload("res://scripts/emergence.gd")

## The brush's radius (m) at the roll's middle pip (× 0.6 and × 1.5 either
## side), the same reach as the Modeller's thumb.
const RADIUS := 1.6
## The coat's cells (m), over the plate's 28 m.
const CELL := 0.25
const SIDE := 112
const HALF := 14.0
## What one pass lays along its middle; what holding lays a second; a tap's
## dab and its share of the brush; the most a cell holds.
const PASS := 5.0
const PER_SECOND := 4.0
const LINGER := 0.8
const LINGER_FAST := 0.25
const TAP := 11.0
const TAP_SHARE := 0.65
const MOST := 12.0
## The brush's falloff: full to INNER of the radius, easing to nothing at it.
const INNER := 0.3
## A press stays a tap until the pointer has gone TAP_SLACK m on the ground
## or been held TAP_HOLD s; the path is laid in sub-dabs STEP radii apart.
const TAP_SLACK := 0.2
const TAP_HOLD := 0.22
const STEP := 0.25
## Each flower is born within SPROUT s of being painted, so a dab's flowers
## rise together but not in lockstep.
const SPROUT := 0.3

var sowing: RefCounted
var data: NativeTerrainData
var radius := RADIUS
var thin := false
var serial := 0
## The coat, SIDE × SIDE cells from (-HALF, -HALF): banked from passes gone
## by and lingering (`_field`), and laid by the brush on this visit
## (`_touch`, its cells in `_visiting`).
var _field := PackedFloat32Array()
var _touch := PackedFloat32Array()
var _visiting := {}
## Lattice spot -> [p, presence needed, kind, feather] or [] where nothing
## can stand this stroke.
var _spots := {}
## The flowers on the plate when a thinning starts, by 0.5 m cell: [id, p].
var _flowers := {}
var _press := Vector2.INF
var _last: Variant = null
var _held := 0.0
var _decided := false
## What this stroke has done: the flowers it placed (ids), by kind, the ids it
## thinned away, the ground it has coated (plate), the spots the ground
## refused, and dabs laid.
var placed: Array[int] = []
var kinds := {}
var removed: Array[int] = []
var bounds := Rect2()
var refused := 0
var dabs := 0

## A stroke of `sowing` (a FlowerSowing for the slot, its wetness and habitat
## already set) at `size` times the brush, thinning when `thinning`. `stroke_serial`
## keys its draws, so a second stroke over the first fills what it left.
func _init(flower_sowing: RefCounted, size: float, thinning: bool, stroke_serial: int) -> void:
	sowing = flower_sowing
	data = sowing.data
	radius = RADIUS*size
	thin = thinning
	serial = stroke_serial
	_field.resize(SIDE*SIDE)
	_touch.resize(SIDE*SIDE)
	var plate := Rect2(-HALF,-HALF,2.0*HALF,2.0*HALF)
	if thin: _survey_flowers()
	else: sowing._survey(plate)

## True for a record's asset that is a flower (the kit's kinds, and the old
## forms and their stand-ins).
static func is_flower(asset: String) -> bool:
	return MeadowTypes.FLOWER_KEYS.has(asset) or asset in ["flower","daisy_flower","button_flower","umbel_flower","spike_flower"]

# --- Painting -----------------------------------------------------------------------

## The press at `p` (plate): a tap's small dab, there at once. What it made:
## {"records" (placed, as in data), "removed" (ids)}.
func press(p: Vector2) -> Dictionary:
	_press = p
	_last = p
	_held = 0.0
	_decided = false
	var reach := radius*TAP_SHARE
	var touched := {}
	_brush(p,reach,TAP,touched)
	_visiting = touched
	return _settle(Rect2(p-Vector2.ONE*reach,Vector2.ONE*reach*2.0))

## A frame of the held press with the brush at `p` (plate), `delta` s on. Until
## the press is decided a drag (TAP_SLACK) or a hold (TAP_HOLD) it is still a
## tap and lays nothing more; from then the path from the last point is laid,
## and the time held.
func stroke(p: Vector2, delta: float) -> Dictionary:
	_held += delta
	if not _decided:
		if p.distance_to(_press) < TAP_SLACK and _held < TAP_HOLD: return {"records":[],"removed":[]}
		_decided = true
	var from: Vector2 = _last if _last != null else p
	_last = p
	var area := Rect2(p,Vector2.ZERO)
	var length := from.distance_to(p)
	var steps := maxi(1,ceili(length/(radius*STEP)))
	var touched := {}
	for i in range(1,steps+1):
		var at := from.lerp(p,float(i)/steps)
		_brush(at,radius,PASS,touched)
		area = area.expand(at)
	var dt := minf(delta,0.1)
	var speed := length/maxf(dt,0.001)
	_dab(p,radius,PER_SECOND*dt*lerpf(1.0,LINGER_FAST,smoothstep(0.0,LINGER,speed)))
	# What the brush has gone on past is banked: coming back is a new pass.
	var left := []
	for i: int in _visiting:
		if not touched.has(i): left.append(i)
	_bank(left)
	_visiting = touched
	return _settle(area.grow(radius))

## The pointer left the land: the next point starts a new path, not a line
## across what lies between, and a new pass.
func lift() -> void:
	_last = null
	_bank(_visiting.keys())
	_visiting = {}

## Lays the brush's profile (`peak` at its middle) round `p` at once: each
## cell under it holds the most laid on it this visit. The cells go in
## `touched`.
func _brush(p: Vector2, reach: float, peak: float, touched: Dictionary) -> void:
	dabs += 1
	var low := _cell_of(p-Vector2.ONE*reach)
	var high := _cell_of(p+Vector2.ONE*reach)
	for z in range(maxi(low.y,0),mini(high.y,SIDE-1)+1):
		for x in range(maxi(low.x,0),mini(high.x,SIDE-1)+1):
			var d := p.distance_to(Vector2((x+0.5)*CELL-HALF,(z+0.5)*CELL-HALF))/reach
			if d >= 1.0: continue
			var i := z*SIDE+x
			_touch[i] = maxf(_touch[i],peak*(1.0-smoothstep(INNER,1.0,d)))
			touched[i] = true
	_grow_bounds(p,reach)

## Adds `amount` at the middle of a dab of radius `reach` round `p`, banked
## at once (lingering).
func _dab(p: Vector2, reach: float, amount: float) -> void:
	if amount <= 0.0: return
	var low := _cell_of(p-Vector2.ONE*reach)
	var high := _cell_of(p+Vector2.ONE*reach)
	for z in range(maxi(low.y,0),mini(high.y,SIDE-1)+1):
		for x in range(maxi(low.x,0),mini(high.x,SIDE-1)+1):
			var d := p.distance_to(Vector2((x+0.5)*CELL-HALF,(z+0.5)*CELL-HALF))/reach
			if d >= 1.0: continue
			var i := z*SIDE+x
			_field[i] = minf(_field[i]+amount*(1.0-smoothstep(INNER,1.0,d)),MOST)
	_grow_bounds(p,reach)

## Banks what this visit laid on the cells `cells`.
func _bank(cells: Array) -> void:
	for i: int in cells:
		_field[i] = minf(_field[i]+_touch[i],MOST)
		_touch[i] = 0.0

func _grow_bounds(p: Vector2, reach: float) -> void:
	var box := Rect2(p-Vector2.ONE*reach,Vector2.ONE*reach*2.0)
	bounds = box if bounds.size == Vector2.ZERO else bounds.merge(box)

func _cell_of(p: Vector2) -> Vector2i:
	return Vector2i(((p+Vector2.ONE*HALF)/CELL).floor())

## The coat at `p` (plate), between cell middles.
func coat(p: Vector2) -> float:
	var g := (p+Vector2.ONE*HALF)/CELL-Vector2.ONE*0.5
	var x0 := clampi(floori(g.x),0,SIDE-1)
	var z0 := clampi(floori(g.y),0,SIDE-1)
	var x1 := mini(x0+1,SIDE-1)
	var z1 := mini(z0+1,SIDE-1)
	var fx := clampf(g.x-x0,0.0,1.0)
	var fz := clampf(g.y-z0,0.0,1.0)
	return lerpf(lerpf(_cell_coat(z0*SIDE+x0),_cell_coat(z0*SIDE+x1),fx),lerpf(_cell_coat(z1*SIDE+x0),_cell_coat(z1*SIDE+x1),fx),fz)

func _cell_coat(i: int) -> float:
	return minf(_field[i]+_touch[i],MOST)

## Brings what stands in `area` up to its coat: flowers where it now holds
## them, or thinned away.
func _settle(area: Rect2) -> Dictionary:
	if thin: return {"records":[],"removed":_thin(area)}
	return {"records":_grow(area),"removed":[]}

# --- Growing ------------------------------------------------------------------------

func _grow(area: Rect2) -> Array:
	var made := []
	var spacing := FlowerSowing.SPACING
	var salt: int = sowing.salt
	var first := Vector2i((area.position/spacing).floor())
	var last := Vector2i((area.end/spacing).ceil())
	var now: float = Emergence.time
	for gz in range(first.y,last.y):
		for gx in range(first.x,last.x):
			var cell := Vector2i(gx,gz)
			var spot: Variant = _spots.get(cell)
			if spot == null:
				# Not judged yet: only once the coat here could bring it up.
				var rough := Vector2((gx+0.5)*spacing,(gz+0.5)*spacing)
				if coat(rough)*1.2 < FlowerSowing.THIN: continue
				spot = _judge(cell)
				_spots[cell] = spot
			if (spot as Array).is_empty(): continue
			var p: Vector2 = spot[0]
			var presence := clampf(smoothstep(FlowerSowing.THIN,FlowerSowing.FULL,coat(p)*float(spot[3])),0.0,1.0)
			if presence <= float(spot[1]): continue
			# It comes up (or nothing will, if something took the spot).
			_spots[cell] = []
			if not sowing._free(p): continue
			var key := [salt,71,gx,gz]
			var record: Array = sowing.meadow.flower(str(spot[2]),p,key)
			var id := data.place(record[0],p,record[4],record[1],record[3],record[2])
			if id < 0: continue
			var item: Dictionary = data.objects.back()
			item["source"] = "hand"
			item["born"] = now+SPROUT*Variety.unit([salt,serial,gx,gz,6])
			sowing._taken.get_or_add(Vector2i((p/0.5).floor()),[]).append(Vector3(p.x,p.y,FlowerSowing.ROOM))
			placed.append(id)
			kinds[spot[2]] = int(kinds.get(spot[2],0))+1
			made.append(item)
	return made

## The lattice spot `cell`, judged once a stroke: where it stands, the
## presence it needs to come up (from its draw, the drift's density and its
## kind's packing), its kind and its share of the feather; [] where nothing
## can stand (its draw is too high, off its row, or the ground refuses).
func _judge(cell: Vector2i) -> Array:
	var salt: int = sowing.salt
	var spacing := FlowerSowing.SPACING
	var key := [salt,71,cell.x,cell.y]
	var p := Vector2((cell.x+Variety.unit(key+[1]))*spacing,(cell.y+Variety.unit(key+[2]))*spacing)
	var roll := Variety.unit([salt,serial,cell.x,cell.y,3])
	var meadow: RefCounted = sowing.meadow
	var density := float(meadow.type.drift.get("density",1.0))
	var kind: String = meadow.kind_at(p,Variety.unit([salt,serial,cell.x,cell.y,4]))
	var standing := density*MeadowTypes.packing(kind)
	if roll >= standing or not meadow.on_row(p,kind): return []
	if not sowing.suits(p):
		refused += 1
		return []
	var need := pow(roll/standing,1.0/1.2)
	var feather := clampf(0.8+0.45*sowing._feather.get_noise_2d(p.x,p.y),0.0,1.2)
	return [p,need,kind,feather]

# --- Thinning -----------------------------------------------------------------------

func _survey_flowers() -> void:
	_flowers.clear()
	for item: Dictionary in data.objects:
		if not is_flower(str(item.asset)): continue
		var p := Vector2(float(item.x),float(item.z))
		_flowers.get_or_add(Vector2i((p/0.5).floor()),[]).append([int(item.id),p])

## Each flower's own share of the way from THIN to FULL the coat must reach
## to take it.
func _share(id: int) -> float:
	return Variety.unit([int(sowing.salt),id,17])

func _thin(area: Rect2) -> Array:
	var gone: Array[int] = []
	var first := Vector2i((area.position/0.5).floor())
	var last := Vector2i((area.end/0.5).floor())
	for z in range(first.y,last.y+1):
		for x in range(first.x,last.x+1):
			var cell := Vector2i(x,z)
			var here: Array = _flowers.get(cell,[])
			if here.is_empty(): continue
			var keep := []
			for entry: Array in here:
				var p: Vector2 = entry[1]
				if coat(p) >= lerpf(FlowerSowing.THIN,FlowerSowing.FULL,_share(int(entry[0]))): gone.append(int(entry[0]))
				else: keep.append(entry)
			_flowers[cell] = keep
	if gone.is_empty(): return gone
	var going := {}
	for id in gone: going[id] = true
	var kept: Array[Dictionary] = []
	for item: Dictionary in data.objects:
		if going.has(int(item.id)):
			var p := Vector2(float(item.x),float(item.z))
			data.provenance[data.meadow_cell(p)] = NativeTerrainData.SOURCE_HAND
		else: kept.append(item)
	data.objects.assign(kept)
	data.objects_revision += 1
	removed.append_array(gone)
	return gone

# --- The end ------------------------------------------------------------------------

## The stroke is let go: the ground under what was painted is warmed toward
## its flowers (FlowerSowing `wash`, faint, dense cores only). Inside the open
## undo step. A summary: {"placed", "kinds", "removed", "bounds", "washed",
## "refused", "dabs"}.
func finish() -> Dictionary:
	var washed := 0
	if not thin and not placed.is_empty(): washed = sowing.wash(coat,bounds)
	return {"placed":placed.duplicate(),"kinds":kinds.duplicate(),"removed":removed.duplicate(),"bounds":bounds,"washed":washed,"refused":refused,"dabs":dabs}
