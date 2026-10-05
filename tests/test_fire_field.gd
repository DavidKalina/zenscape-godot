extends SceneTree
## FireField: spread, wind bias, suppression, objects, embers, regrowth,
## persistence and the undo bracket. Pure logic — no scene, no renderer.
const PlateFixture := preload("res://tests/fixtures/plate.gd")

var failures := 0
var _mesh: ArrayMesh = null

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: "+message)
		print("FAIL: ",message)
	else:
		print("PASS: ",message)

class Air:
	var wind := Vector3.ZERO
	var ground_wet := 0.0
	var snow_cover := 0.0
	var rain := 0.0
	var water := PackedInt32Array()
	func sample(_position: Vector3) -> Vector3: return wind
	func weather() -> Dictionary: return {"ground_wet":ground_wet,"snow_cover":snow_cover,"rain":rain}
	func wet(position: Vector3) -> bool:
		for i in range(0,water.size(),2):
			if position.x >= float(water[i])*0.5 and position.x < float(water[i+1])*0.5: return true
		return false

## `patch` is the list of cells to fuel; empty means grass everywhere.
func world(air: Air, rng_seed := 7, patch: Array = []) -> Array:
	var data := NativeTerrainData.new()
	data.setup(_mesh)
	data.reset_flat()
	if patch.is_empty():
		data.grass.fill(1.0)
	else:
		for point: Vector2 in patch:
			data.grass[data.meadow_cell(point)] = 1.0
	var field := FireField.new()
	field.setup(data,air.sample,air.weather,air.wet,rng_seed)
	return [data,field]

func run() -> void:
	_mesh = PlateFixture.mesh()
	_spread()
	_suppression()
	_objects()
	_embers()
	_regrowth()
	_persistence()
	_paused()
	_stroke()
	print("FIRE FIELD: failures=",failures)
	quit(1 if failures else 0)

## Advance in sixtieths until `test` passes, returning the seconds it took or
## -1.0 when it never did.
func until(field: FireField, limit: float, test: Callable) -> float:
	var elapsed := 0.0
	while elapsed < limit:
		field.advance(1.0/60.0)
		elapsed += 1.0/60.0
		if test.call(): return elapsed
	return -1.0

func step(field: FireField, seconds: float) -> void:
	for i in range(roundi(seconds*60.0)): field.advance(1.0/60.0)

# ------------------------------------------------------------------ spread

func _spread() -> void:
	var air := Air.new()
	air.wind = Vector3(4,0,0)
	var pair := world(air)
	var field: FireField = pair[1]
	# Ember spotting is measured separately; it would jump the front and hide
	# the neighbour-to-neighbour speed this case is about.
	field.ember_chance = 0.0
	var lit := {}
	var clock := {"t":0.0}
	field.cell_ignited.connect(func(index: int, _center: Vector3):
		if not lit.has(index): lit[index] = clock.t)
	var origin := field.cell_at(Vector3.ZERO)
	var cells: int = field._cells
	field.ignite(Vector3.ZERO,0.6,1.0)
	var reach := 4
	while clock.t < 40.0:
		field.advance(1.0/60.0)
		clock.t += 1.0/60.0
	var downwind: float = lit.get(origin+reach,-1.0)
	var upwind: float = lit.get(origin-reach,-1.0)
	var across: float = lit.get(origin+reach*cells,-1.0)
	var down_speed := float(reach)/downwind if downwind > 0.0 else 0.0
	var up_speed := float(reach)/upwind if upwind > 0.0 else 0.0
	var side_speed := float(reach)/across if across > 0.0 else 0.0
	print("  downwind %.2f cells/s (%.2f s/cell), upwind %.2f cells/s (%.2f s/cell), crosswind %.2f cells/s" % [down_speed,downwind/reach,up_speed,upwind/reach,side_speed])
	print("  downwind/upwind ratio %.2f" % (down_speed/up_speed))
	check(downwind > 0.0 and upwind > 0.0,"Dry grass carries a front both ways")
	check(down_speed/up_speed > 2.4 and down_speed/up_speed < 4.5,"Fire runs roughly three times faster downwind than upwind")
	check(absf(downwind/reach-0.8) < 0.35,"Downwind front is about one cell per 0.8 s at 4 m/s")
	check(absf(upwind/reach-3.0) < 1.2,"Upwind front is about one cell per 3 s")
	check(field.total_intensity() > 0.0 and field.total_intensity() <= 1.0,"Total intensity reads 0..1")
	check(not field.burning_cells().is_empty() and field.active(),"An established fire reports burning cells")

func _front(field: FireField, lit: Dictionary) -> int:
	var best := -1000000
	var cells: int = field._cells
	for index: int in lit: best = maxi(best,index%cells)
	return best

func _suppression() -> void:
	for case in [{"key":"ground_wet","value":0.9,"label":"ground_wet 0.9 stalls the front"},
			{"key":"snow_cover","value":0.5,"label":"snow_cover 0.5 stops the front"}]:
		var air := Air.new()
		air.wind = Vector3(4,0,0)
		var pair := world(air)
		var field: FireField = pair[1]
		var lit := {}
		field.cell_ignited.connect(func(index: int, _center: Vector3): lit[index] = true)
		field.ignite(Vector3.ZERO,0.6,1.0)
		step(field,4.0)
		var before := _front(field,lit)
		air.set(case.key,case.value)
		step(field,15.0)
		check(_front(field,lit) == before,case.label)
	# Rain drowns an established fire fast.
	var air := Air.new()
	air.wind = Vector3(4,0,0)
	var pair := world(air)
	var field: FireField = pair[1]
	field.ignite(Vector3.ZERO,0.8,1.0)
	step(field,6.0)
	check(field.active(),"Fire is established before the rain")
	air.rain = 1.0
	var out := until(field,30.0,func(): return not field.active())
	print("  rain 1.0 extinguish in %.2f s" % out)
	check(out > 0.0 and out < 12.0,"Rain 1.0 extinguishes an established fire in under 12 s")

# ----------------------------------------------------------------- objects

func _objects() -> void:
	var air := Air.new()
	var pair := world(air)
	var data: NativeTerrainData = pair[0]
	var field: FireField = pair[1]
	# Spread out so canopy-to-canopy ignition does not cross the cases.
	var flower := data.place("flower",Vector2(-8,-8))
	var shrub := data.place("shrub",Vector2(-8,0))
	var tree := data.place("tree",Vector2(-8,8))
	var rock := data.place("rock",Vector2(8,-8))
	var bomb := data.place("explosive",Vector2(8,8))
	check(flower > 0 and shrub > 0 and tree > 0 and rock > 0 and bomb > 0,"Test world places every object kind")
	var ignited := {}
	var out := {}
	var detonated := {}
	field.object_ignited.connect(func(id: int, kind: String, _p: Vector3): ignited[id] = kind)
	field.object_burned_out.connect(func(id: int, kind: String, _p: Vector3): out[id] = kind)
	field.explosive_triggered.connect(func(id: int, p: Vector3): detonated[id] = p)
	for point in [Vector2(-8,-8),Vector2(-8,0),Vector2(-8,8),Vector2(8,-8),Vector2(8,8)]:
		field.ignite(Vector3(point.x,0,point.y),0.4,1.0)
	step(field,1.0)
	check(ignited.has(flower) and ignited.has(shrub) and ignited.has(tree),"Flora catches when its cell ignites")
	check(not ignited.has(rock),"Rock never catches")
	check(field.burning_objects().has(tree),"burning_objects reports live fire state")
	check(detonated.has(bomb) and not data.object_by_id(bomb).is_empty(),"An explosive signals for detonation and is left to the explosives system")
	step(field,5.0)
	check(data.object_by_id(flower).is_empty() and out.has(flower),"Flowers vanish after about four seconds")
	check(not data.object_by_id(shrub).is_empty(),"A shrub is still burning at five seconds")
	step(field,9.0)
	check(data.object_by_id(shrub).is_empty(),"Shrubs vanish after about twelve seconds")
	var snag_at := until(field,60.0,func(): return data.object_by_id(tree).get("asset","") == "snag")+15.0
	print("  tree torch to snag in %.1f s" % snag_at)
	check(snag_at > 36.0 and snag_at < 44.0,"A tree becomes a snag after about forty seconds")
	var record := data.object_by_id(tree)
	check(record.get("asset") == "snag" and NativeObjectPose.decode_tint(record.get("tint","")).v < 0.2,"The snag carries a charcoal tint")
	check(absf(record.x+8.0) < 0.001 and absf(record.z-8.0) < 0.001,"The snag keeps its placement")
	check(not data.object_by_id(rock).is_empty(),"Rock survives the fire untouched")

# ------------------------------------------------------------------ embers

func _embers() -> void:
	var air := Air.new()
	air.wind = Vector3(9,0,0)
	# Two cells of water at x in [0.0, 1.0) with the grid centre at 28 cells.
	air.water = PackedInt32Array([0,2])
	var pair := world(air,11)
	var field: FireField = pair[1]
	var cells: int = field._cells
	var row := field.cell_at(Vector3(-2,0,0))/cells
	var lit := {}
	field.cell_ignited.connect(func(index: int, _c: Vector3): lit[index] = true)
	field.ignite(Vector3(-2,0,0),0.6,1.0)
	var jumped := until(field,90.0,func():
		for index: int in lit:
			if index%cells >= 30: return true
		return false)
	print("  ember jump across a two-cell water gap in %.1f s" % jumped)
	check(jumped > 0.0,"Embers carry the fire across a two-cell water gap in high wind")
	var wet_lit := false
	for index: int in lit:
		if index%cells == 28 or index%cells == 29: wet_lit = true
	check(not wet_lit,"Water cells never burn")

# --------------------------------------------------------------- regrowth

func _regrowth() -> void:
	var air := Air.new()
	var pair := world(air,7,[Vector2.ZERO])
	var data: NativeTerrainData = pair[0]
	var field: FireField = pair[1]
	field.regrow_seconds = 6.0
	var index := field.cell_at(Vector3.ZERO)
	var grass_before: float = data.grass[index]
	field.ignite(Vector3.ZERO,0.6,1.0)
	step(field,2.0)
	check(data.grass[index] == 0.0,"Cover is zeroed while a cell burns")
	check(NativeTerrainTint.weight_at(data.tint,index) > 0.2,"Burning paints scorch into the tint layer")
	step(field,20.0)
	check(absf(data.grass[index]-grass_before) < 0.001,"Regrowth restores the remembered cover")
	check(NativeTerrainTint.weight_at(data.tint,index) == 0.0,"Regrowth erases the scorch tint")
	check(not field.active() and field.burning_cells().is_empty(),"A fully regrown field is inert")
	check(field.document().is_empty(),"An inert field documents as nothing")

# ------------------------------------------------------------ persistence

func _persistence() -> void:
	var air := Air.new()
	air.wind = Vector3(4,0,0)
	var pair := world(air)
	var data: NativeTerrainData = pair[0]
	var field: FireField = pair[1]
	data.place("shrub",Vector2(0.2,0.2))
	field.ignite(Vector3.ZERO,0.8,1.0)
	step(field,3.0)
	var document := field.document()
	check(not document.is_empty() and FireField.valid(document),"A live fire documents and validates")
	check(FireField.valid({}) and not FireField.valid("fire") and not FireField.valid({"clock":"zz"}),"Rubbish sub-documents are rejected")
	var burning := field.burning_cells().duplicate()
	var objects := field.burning_objects()
	field.restore(document)
	check(field.burning_cells() == burning,"Restore reinstates the burning cells")
	check(field.burning_objects().size() == objects.size(),"Restore reinstates object fire state")
	check(field.document() == document,"document/restore round-trips exactly")
	var ground_before_reset := data._snapshot()
	field.restore({})
	check(not field.active() and field.document().is_empty(),"Restoring an empty sub-document yields an inert field")
	check(data._snapshot() == ground_before_reset,"Resetting simulation state never overwrites terrain owned by the editor")

# -------------------------------------------------------------------- pause

func _paused() -> void:
	var air := Air.new()
	air.wind = Vector3(4,0,0)
	var pair := world(air)
	var data: NativeTerrainData = pair[0]
	var field: FireField = pair[1]
	field.ignite(Vector3.ZERO,0.8,1.0)
	step(field,3.0)
	var snapshot := [field.fuel.duplicate(),field.heat.duplicate(),field.burn.duplicate(),field.ash.duplicate(),data.grass.duplicate(),data.tint.duplicate()]
	for i in range(300): field.advance(1.0/60.0,true)
	check(field.fuel == snapshot[0] and field.heat == snapshot[1],"Paused advance leaves fuel and heat alone")
	check(field.burn == snapshot[2] and field.ash == snapshot[3],"Paused advance leaves burn and ash alone")
	check(data.grass == snapshot[4] and data.tint == snapshot[5],"Paused advance writes nothing to the ground")
	field.advance(1.0/60.0)
	check(field.active(),"The fire resumes after the pause")

# ------------------------------------------------------------------- stroke

func _stroke() -> void:
	var air := Air.new()
	var pair := world(air,7,[Vector2.ZERO,Vector2(4,4)])
	var field: FireField = pair[1]
	var count := {"started":0,"ended":0,"fires":0,"outs":0}
	field.stroke_started.connect(func(): count.started += 1)
	field.stroke_ended.connect(func(): count.ended += 1)
	field.fire_started.connect(func(_p: Vector3): count.fires += 1)
	field.fire_extinguished.connect(func(): count.outs += 1)
	field.ignite(Vector3.ZERO,1.2,1.0)
	step(field,1.0)
	check(count.started == 1 and count.fires == 1,"One fire opens exactly one undo stroke")
	field.ignite(Vector3(0.5,0,0.5),0.6,1.0)
	step(field,60.0)
	check(count.started == 1,"Reigniting inside a live fire does not open a second stroke")
	check(count.ended == 1 and count.outs == 1,"The stroke and the fire close once when the last cell dies")
	field.ignite(Vector3(4,0,4),0.6,1.0)
	step(field,1.0)
	check(count.started == 2 and count.fires == 2,"A later, separate fire opens a fresh stroke")
