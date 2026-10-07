extends SceneTree
## The glide (scripts/sky_glide.gd) keeps its rules: off the edge it drops
## before it catches; it never stalls; a dive builds speed and pulling out
## swings it higher than a plain glide would; there is a float at the top of
## the arc; Rise always climbs; it turns easily and banks into turns; it
## skims along the ground instead of crashing; and a long fall is caught.
## The air (scripts/sky_currents.gd): the islands stand far apart, a jet
## stream carries the glide fast and turns it downstream, steering hard
## takes it out, and a thermal lifts it.
## Wandered off (scripts/sky_cells.gd): islands turn up in seeded cells, the
## same spot each time, well apart; far for a while one turns up ahead,
## fallen into the sea one turns up just ahead, unless one is in reach; the
## swaps' shifts keep the cells in place; past the cap the farthest go.
const SkyGlide = preload("res://scripts/sky_glide.gd")
const SkyCurrents = preload("res://scripts/sky_currents.gd")
const SkyIslands = preload("res://scripts/sky_islands.gd")
const SkyClouds = preload("res://scripts/sky_clouds.gd")
const SkyCells = preload("res://scripts/sky_cells.gd")
const DT := 1.0/60.0
var failures := 0

func _initialize() -> void:
	_drop()
	_never_stalls()
	_dive_and_swoop()
	_rise()
	_turns()
	_skim()
	_under_island()
	_island_side()
	_caught()
	_spread()
	_currents()
	_clouds()
	# The cells' own workings, in the open sky (SkyWorld `ring` off): far
	# out past the bounds. In the bounded world: tests/test_sky_world.gd.
	preload("res://scripts/sky_world.gd").ring = false
	_cells_determined()
	_cells_spaced()
	_cells_wander()
	_cells_fall()
	_cells_swap()
	_cells_trim()
	preload("res://scripts/sky_world.gd").ring = true
	_added_air()
	_airspeed()
	_flaps()
	_approach()
	print("PASS: sky glide" if failures == 0 else "FAIL: sky glide")
	quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func air(_p: Vector3) -> Variant:
	return null

func fly(glide: SkyGlide, seconds: float, input: Dictionary, ground := Callable(self,"air")) -> void:
	for i in range(int(seconds/DT)): glide.step(DT,input,ground)

func launched() -> SkyGlide:
	var glide := SkyGlide.new()
	glide.launch(Vector3(0.0,10.0,0.0),0.0,1.6)
	return glide

func _drop() -> void:
	var glide := launched()
	fly(glide,0.6,{})
	var dropping := glide.velocity.y
	fly(glide,2.0,{})
	check(dropping < -4.0,"Off the edge it drops (%.1f m/s)" % dropping)
	check(glide.velocity.y > dropping+2.0,"Then the glide catches it (%.1f m/s)" % glide.velocity.y)

func _never_stalls() -> void:
	var glide := launched()
	var slowest := INF
	for i in range(int(8.0/DT)):
		glide.step(DT,{"pitch":1.0},air)
		slowest = minf(slowest,glide.speed)
	check(slowest >= SkyGlide.MIN-0.001,"Nose held up, it never drops under MIN (%.2f m/s)" % slowest)

func _dive_and_swoop() -> void:
	var glide := launched()
	fly(glide,3.0,{})
	var cruise := glide.speed
	fly(glide,3.0,{"dive":1.0})
	var dived := glide.speed
	check(dived > cruise*2.0,"A dive builds speed (%.1f to %.1f m/s)" % [cruise,dived])
	var bottom := glide.position.y
	var top := bottom
	var floated := 0.0
	for i in range(int(6.0/DT)):
		glide.step(DT,{"pitch":1.0} if glide.pitch < 0.7 else {},air)
		top = maxf(top,glide.position.y)
		floated = maxf(floated,glide.hang)
	check(top-bottom > 12.0,"Pulled out, it swings up a big arc (%.1f m)" % (top-bottom))
	check(floated > 0.4,"There is a float at the top (%.2f)" % floated)
	fly(glide,3.0,{})
	check(glide.pitch < 0.0,"Then the nose tips over (%.2f rad)" % glide.pitch)

func _rise() -> void:
	var glide := launched()
	fly(glide,2.0,{})
	var from := glide.position.y
	fly(glide,10.0,{"rise":1.0})
	check(glide.position.y-from > 15.0,"Rise climbs for as long as it is held (%.1f m in 10 s)" % (glide.position.y-from))
	var high := launched()
	high.position.y = SkyGlide.CEILING+SkyGlide.CEILING_FADE+20.0
	var start := high.position.y
	fly(high,4.0,{"rise":1.0})
	check(high.position.y <= start,"Above the ceiling Rise no longer climbs")

func _turns() -> void:
	var glide := launched()
	fly(glide,1.0,{})
	var from := glide.heading
	fly(glide,1.5,{"turn":1.0})
	check(absf(angle_difference(from,glide.heading)) > 2.0,"A held turn comes round fast (%.2f rad in 1.5 s)" % absf(angle_difference(from,glide.heading)))
	check(glide.bank > 0.3,"It banks into the turn (%.2f rad)" % glide.bank)
	fly(glide,2.0,{})
	check(absf(glide.bank) < 0.05,"Let go, it levels (%.2f rad)" % glide.bank)
	var mouse := launched()
	mouse.step(DT,{"look":Vector2(0.05,0.0)},air)
	check(mouse.heading < 0.0,"Mouse right turns right")

func flat(_p: Vector3) -> Variant:
	return 2.0

func _skim() -> void:
	var glide := launched()
	glide.position.y = 6.0
	var lowest := INF
	var skims := 0
	for i in range(int(5.0/DT)):
		glide.step(DT,{"dive":1.0},flat)
		lowest = minf(lowest,glide.position.y)
		if glide.skimming: skims += 1
	check(lowest >= 2.0+SkyGlide.SKIM-0.001,"Diving into the ground skims over it (lowest %.2f m)" % lowest)
	check(skims > 0 and glide.speed > SkyGlide.MIN,"It keeps going along it (%.1f m/s)" % glide.speed)
	glide.step(DT,{"rise":1.0},flat)
	fly(glide,2.0,{"rise":1.0},flat)
	check(glide.position.y > 2.0+SkyGlide.SKIM+1.0,"Rise lifts it off again")

## A plate 28 m square, ground at 2 m, rock down to -10 m.
func island(p: Vector3) -> Variant:
	if absf(p.x) >= 14.0 or absf(p.z) >= 14.0: return null
	return Vector2(2.0,-10.0)

func inside(p: Vector3) -> bool:
	return absf(p.x) < 14.0 and absf(p.z) < 14.0 and p.y > -10.0-SkyGlide.CLEAR+0.01 and p.y < 2.0+SkyGlide.SKIM-0.01

## Under an island the glide passes beneath it, never snapped up on top;
## climbing into the rock it slides along under it, and out past the rim
## it can rise up beside it and over the top.
func _under_island() -> void:
	var glide := SkyGlide.new()
	glide.launch(Vector3(-30.0,-18.0,0.0),-PI*0.5,8.0,false)
	glide.pitch = 0.0
	var was_inside := false
	var below := 0
	for i in range(int(9.0/DT)):
		glide.step(DT,{},island)
		was_inside = was_inside or inside(glide.position)
		if absf(glide.position.x) < 14.0 and glide.position.y < 0.0: below += 1
	check(not was_inside and below > 60,"It passes beneath an island, never snapped up on top (%d frames under)" % below)
	check(glide.position.x > 14.0,"It comes out the far side (x %.1f m)" % glide.position.x)
	glide.launch(Vector3(-10.0,-14.0,0.0),-PI*0.5,8.0,false)
	var under_rock := false
	for i in range(int(3.0/DT)):
		glide.step(DT,{"rise":1.0,"pitch":1.0},island)
		was_inside = was_inside or inside(glide.position)
		under_rock = under_rock or glide.under_rock
	check(under_rock and not was_inside,"Pressed up under the rock, it slides along under it")
	fly(glide,25.0,{"rise":1.0,"pitch":1.0},island)
	check(glide.position.y > 2.0,"Past the rim, Rise takes it up beside the island (%.1f m)" % glide.position.y)

## Flown at an island's side below its rim, the face turns it aside along
## the face; near the rim it rides up over the top.
func _island_side() -> void:
	var glide := SkyGlide.new()
	glide.launch(Vector3(-25.0,-3.0,1.5),-PI*0.5-0.25,8.0,false)
	glide.pitch = 0.05
	var was_inside := false
	var brushed := false
	for i in range(int(4.0/DT)):
		glide.step(DT,{"pitch":0.12},island)
		was_inside = was_inside or inside(glide.position)
		brushed = brushed or glide.brushing
	check(brushed and not was_inside,"At an island's side it never goes in")
	var along := Vector2(-sin(glide.heading),-cos(glide.heading))
	check(absf(along.x) < 0.6,"The face turns it along the face (heading %.2f)" % glide.heading)
	glide.launch(Vector3(-25.0,2.8,0.0),-PI*0.5,8.0,false)
	glide.pitch = 0.0
	var skimmed := false
	for i in range(int(4.0/DT)):
		glide.step(DT,{},island)
		skimmed = skimmed or glide.skimming
	check(skimmed and glide.position.x > -14.0,"Coming in just under the rim, it rides up over it")

func _caught() -> void:
	var glide := launched()
	var lowest := INF
	for i in range(int(90.0/DT)):
		glide.step(DT,{"dive":1.0},air)
		lowest = minf(lowest,glide.position.y)
	check(lowest > SkyGlide.FLOOR-60.0,"A long dive is caught under the floor (lowest %.1f m)" % lowest)
	fly(glide,20.0,{})
	check(glide.position.y > SkyGlide.FLOOR-25.0,"Let go, the cushion lifts it back towards the band (%.1f m)" % glide.position.y)

func _spread() -> void:
	var slots := [Vector3.ZERO]
	slots.append_array(SkyIslands.OFFSETS)
	var nearest := INF
	for i in range(slots.size()):
		for j in range(i+1,slots.size()):
			nearest = minf(nearest,Vector2(slots[i].x,slots[i].z).distance_to(Vector2(slots[j].x,slots[j].z)))
	check(nearest > 350.0,"The islands stand far apart (nearest pair %.0f m)" % nearest)

func _currents() -> void:
	var currents := SkyCurrents.new()
	var slots := [Vector3.ZERO]
	slots.append_array(SkyIslands.OFFSETS)
	currents.build(slots)
	var jets := currents.currents.filter(func(c: Dictionary) -> bool: return c.kind == "jet")
	var thermals := currents.currents.filter(func(c: Dictionary) -> bool: return c.kind == "thermal")
	check(jets.size() == 2 and thermals.size() >= slots.size()*2,"Two jet loops and thermals by every island (%d jets, %d thermals)" % [jets.size(),thermals.size()])
	# Drawn as ribbons (tests/test_jet_ribbons.gd): a few strokes a jet, a
	# handful a thermal.
	check(currents.wisp_count() >= jets.size()*3+thermals.size()*SkyCurrents.THERMAL_RIBBONS,"The currents are drawn (%d ribbons)" % currents.wisp_count())
	check(currents.air_at(Vector3(0.0,300.0,0.0)).wind == Vector3.ZERO,"Out of the currents the air is still")
	# Nowhere along either jet does the air stall: no crossing where the
	# two loops cancel out, and the loops keep apart.
	var weakest := INF
	for c: Dictionary in currents.currents:
		if c.kind != "jet": continue
		var pts: PackedVector3Array = c.points
		for i in range(pts.size()):
			for f in [0.0,0.5]:
				var p: Vector3 = pts[i].lerp(pts[(i+1)%pts.size()],f)
				var along_jet: Vector3 = (pts[(i+1)%pts.size()]-pts[i]).normalized()
				weakest = minf(weakest,currents.air_at(p).wind.dot(along_jet))
	check(weakest > SkyCurrents.JET*0.7,"Along every jet the air runs strong (weakest %.1f m/s)" % weakest)
	var apart := INF
	var low: PackedVector3Array = jets[0].points
	var high: PackedVector3Array = jets[1].points
	for a in low:
		for i in range(high.size()):
			var h0: Vector3 = high[i]
			var h1: Vector3 = high[(i+1)%high.size()]
			var t := clampf((a-h0).dot(h1-h0)/maxf((h1-h0).length_squared(),1e-6),0.0,1.0)
			apart = minf(apart,a.distance_to(h0.lerp(h1,t)))
	check(apart > SkyCurrents.JET_RADIUS*2.6,"The two jet loops keep apart (closest %.1f m)" % apart)
	# Into the low jet, facing across it.
	var jet: Dictionary = jets[0]
	var on: Vector3 = jet.points[10]
	var way: Vector3 = (jet.points[11]-jet.points[10]).normalized()
	var air := Callable(currents,"air_at")
	var glide := SkyGlide.new()
	glide.launch(on,atan2(-way.x,-way.z)+1.0,SkyGlide.CRUISE)
	glide.airborne = 10.0
	var carried := 0.0
	for i in range(int(1.0/DT)): glide.step(DT,{},Callable(self,"air"),air)
	carried = glide.velocity.length()
	check(carried > 22.0,"A jet stream carries the glide fast (%.1f m/s)" % carried)
	check(absf(angle_difference(glide.heading,atan2(-way.x,-way.z))) < 0.6,"In the jet it turns downstream (%.2f rad off)" % absf(angle_difference(glide.heading,atan2(-way.x,-way.z))))
	var stayed := 0
	for i in range(int(6.0/DT)):
		glide.step(DT,{},Callable(self,"air"),air)
		if glide.in_jet > 0.5: stayed += 1
	check(stayed > int(5.0/DT),"Left alone it rides the jet (%.1f s of 6 in it)" % (stayed*DT))
	for i in range(int(4.0/DT)): glide.step(DT,{"turn":1.0,"rise":1.0},Callable(self,"air"),air)
	check(glide.in_jet < 0.1,"Steering hard takes it out of the jet")
	# Into a thermal.
	var thermal: Dictionary = thermals[0]
	var column: Vector3 = thermal.points[20]
	var lifted := SkyGlide.new()
	lifted.launch(column,0.0,SkyGlide.MIN)
	lifted.airborne = 10.0
	var from := lifted.position.y
	for i in range(int(3.0/DT)):
		lifted.position.x = column.x
		lifted.position.z = column.z
		lifted.step(DT,{},Callable(self,"air"),air)
	check(lifted.position.y-from > 12.0,"A thermal lifts the glide (%.1f m in 3 s)" % (lifted.position.y-from))
	currents.free()

## Clouds fill the air between the islands, keep clear of them, drift and
## wrap whole, and say how deep a point is in one.
func _clouds() -> void:
	var clouds := SkyClouds.new()
	var slots := [Vector3.ZERO]
	slots.append_array(SkyIslands.OFFSETS)
	clouds.build(slots)
	check(clouds.clouds.size() == SkyClouds.COUNT and clouds.puff_count() > SkyClouds.COUNT*SkyClouds.PUFFS.x-1,"Clouds fill the air (%d clouds, %d puffs)" % [clouds.clouds.size(),clouds.puff_count()])
	var nearest := INF
	for i in range(clouds.clouds.size()):
		var c := clouds.centre(i,0.0)
		for s: Vector3 in slots: nearest = minf(nearest,Vector2(c.x,c.z).distance_to(Vector2(s.x,s.z)))
	check(nearest >= SkyClouds.CLEAR,"They keep clear of the islands (nearest %.0f m)" % nearest)
	var heart := clouds.centre(0,0.0)
	check(clouds.inside(heart,0.0) > 0.9,"A cloud's heart is deep inside it")
	check(clouds.inside(heart+Vector3.UP*200.0,0.0) == 0.0,"Clear air is outside every cloud")
	var later := clouds.centre(0,100.0)
	check(later.distance_to(heart) > 30.0,"Clouds drift (%.0f m in 100 s)" % later.distance_to(heart))
	var far_later := clouds.centre(0,1e5)
	check(far_later.x >= clouds.field.x and far_later.x <= clouds.field.x+clouds.field.z,"They wrap round the field")
	clouds.move(Vector3(10.0,0.0,0.0))
	check(clouds.centre(0,0.0).is_equal_approx(heart+Vector3(10.0,0.0,0.0)),"An island swap moves them with the world")
	clouds.free()

func cells() -> SkyCells:
	var slots := [Vector3.ZERO]
	slots.append_array(SkyIslands.OFFSETS)
	return SkyCells.new(slots)

## The same cell always gives the same island, from a fresh grid too.
func _cells_determined() -> void:
	var a := cells()
	var b := cells()
	var same := true
	var held := 0
	var heights := true
	for x in range(-8,9):
		for z in range(-8,9):
			var sa: Variant = a.spot(Vector2i(x,z))
			var sb: Variant = b.spot(Vector2i(x,z))
			if (sa == null) != (sb == null) or (sa != null and not (sa as Vector3).is_equal_approx(sb)): same = false
			if sa != null:
				held += 1
				if sa.y < SkyCells.BAND.x or sa.y > SkyCells.BAND.y: heights = false
	check(same,"The same cell gives the same island every time")
	check(held > 17*17/4,"Many cells hold an island (%d of %d)" % [held,17*17])
	check(heights,"Every island stands in the height band")

## No two islands, cells or fixed slots, stand closer than SPACING.
func _cells_spaced() -> void:
	var grid := cells()
	var all: Array = grid.spots_near(Vector3.ZERO,5000.0)
	var nearest := INF
	for i in range(all.size()):
		for j in range(i+1,all.size()):
			nearest = minf(nearest,Vector2(all[i].x-all[j].x,all[i].z-all[j].z).length())
	check(all.size() > 60 and nearest >= SkyCells.SPACING,"Islands keep apart (%d spots, nearest pair %.0f m)" % [all.size(),nearest])

## Far from every island for long enough, one turns up ahead, about IDEAL
## out, and not before.
func _cells_wander() -> void:
	var grid := cells()
	var eye := Vector3(3000.0,0.0,-2000.0)
	var heading := 0.8
	var live := [Vector3.ZERO]
	var early: Variant = null
	var found: Variant = null
	var t := 0.0
	while t < 40.0 and found == null:
		found = grid.advance(DT,eye,heading,live,0.0)
		if t < SkyCells.WANDER_TIME-0.1 and found != null: early = found
		t += DT
	check(early == null,"Not before WANDER_TIME of wandering")
	check(found != null and found.kind == "wander" and t < SkyCells.WANDER_TIME+1.0,"Wandered off, an island turns up (after %.1f s)" % t)
	if found == null: return
	var at: Vector3 = found.home+grid.origin
	var to := Vector2(at.x-eye.x,at.z-eye.z)
	var way := Vector2(-sin(heading),-cos(heading))
	check(to.length() >= SkyCells.NEAR and to.length() <= SkyCells.FAR,"It turns up out in the haze (%.0f m out)" % to.length())
	check(absf(way.angle_to(to)) < SkyCells.CONE,"It turns up ahead (%.2f rad off the heading)" % absf(way.angle_to(to)))
	var again := cells()
	again.wandered = SkyCells.WANDER_TIME
	var twice: Variant = again.advance(DT,eye,heading,live,0.0)
	check(twice != null and (twice.home as Vector3).is_equal_approx(found.home),"The same wander finds the same island")
	# Near an island the clock doesn't run.
	var near := cells()
	for i in range(int(30.0/DT)): near.advance(DT,Vector3(100.0,0.0,0.0),heading,live,0.0)
	check(near.wandered == 0.0,"Near an island nothing turns up")

## Fallen into the parted sea with nothing in reach, one turns up just
## ahead; with one in reach, none does.
func _cells_fall() -> void:
	var grid := cells()
	var eye := Vector3(-2600.0,-75.0,1900.0)
	var found: Variant = grid.advance(DT,eye,0.0,[Vector3.ZERO],0.9)
	check(found != null and found.kind == "fall","Fallen into the parted sea, an island turns up at once")
	if found == null: return
	var ahead := eye+Vector3(0.0,0.0,-SkyCells.AHEAD)
	var d := Vector2(found.home.x-ahead.x,found.home.z-ahead.z).length()
	check(d <= SkyCells.RANGE,"It turns up just ahead (%.0f m from the point ahead)" % d)
	var high: Variant = cells().advance(DT,Vector3(eye.x,-20.0,eye.z),0.0,[Vector3.ZERO],0.9)
	check(high == null,"High in the band, no fall spawn")
	var closed: Variant = cells().advance(DT,eye,0.0,[Vector3.ZERO],0.2)
	check(closed == null,"With the sea closed, no fall spawn")
	var reach: Variant = cells().advance(DT,eye,0.0,[Vector3.ZERO,eye+Vector3(150.0,0.0,0.0)],0.9)
	check(reach == null,"With an island in reach, none turns up")

## A swap shifts the world; with the origin shifted the same, the same place
## gives the same island.
func _cells_swap() -> void:
	var grid := cells()
	var eye := Vector3(2500.0,-90.0,2500.0)
	var before: Variant = grid.advance(DT,eye,1.0,[Vector3.ZERO],0.9)
	var shift := Vector3(-380.0,20.0,160.0)
	var moved := cells()
	moved.origin = shift
	var after: Variant = moved.advance(DT,eye+shift,1.0,[shift],0.9)
	check(before != null and after != null and (before.home as Vector3).is_equal_approx(after.home),"Across a swap the same place gives the same island")

## Past the cap the farthest copies go, never the ones kept.
func _cells_trim() -> void:
	var copies := []
	for i in range(12): copies.append(Vector3(400.0*(i+1),0.0,0.0))
	var freed := SkyCells.trim(Vector3.ZERO,copies,9,[11])
	check(freed.size() == 3 and 11 not in freed and 10 in freed and 9 in freed and 8 in freed,"Past the cap the farthest go, never the kept (freed %s)" % str(freed))
	check(SkyCells.trim(Vector3.ZERO,copies.slice(0,9),9,[]).is_empty(),"Under the cap none go")

## A later island's thermal lifts, and goes with it; the clouds follow a
## far glide.
func _added_air() -> void:
	var currents := SkyCurrents.new()
	var slots := [Vector3.ZERO]
	slots.append_array(SkyIslands.OFFSETS)
	currents.build(slots)
	currents.position = Vector3(50.0,0.0,0.0)
	var count := currents.currents.size()
	var base := Vector3(2000.0,-30.0,2000.0)
	currents.add_thermal(base,"far")
	check(currents.air_at(base+Vector3.UP*10.0).thermal > 0.9,"A later island's thermal lifts")
	currents.drop_thermals("far")
	check(currents.currents.size() == count and currents.air_at(base+Vector3.UP*10.0).thermal == 0.0,"It goes with its island")
	currents.free()
	var clouds := SkyClouds.new()
	clouds.build(slots)
	var far := Vector3(3000.0,0.0,-2500.0)
	clouds.follow(far)
	var middle := Vector2(clouds.field.x+clouds.field.z*0.5,clouds.field.y+clouds.field.w*0.5)
	check(middle.distance_to(Vector2(far.x,far.z)) < 1.0,"The clouds' field follows a far glide")
	var held := clouds.field
	clouds.follow(far+Vector3(100.0,0.0,0.0))
	check(clouds.field == held,"A little way on, it stays put")
	clouds.reset()
	check(Vector2(clouds.field.x,clouds.field.y).distance_to(middle) > 100.0,"Reset puts it home")
	clouds.free()

## Rise needs airspeed, and a glide opened from a jump has no drop.
func _airspeed() -> void:
	var slow := SkyGlide.new()
	slow.launch(Vector3(0.0,10.0,0.0),0.0,SkyGlide.MIN,false)
	check(slow.airborne >= SkyGlide.FALL_TIME+SkyGlide.CATCH-0.001,"Opened from a jump, it glides at once")
	slow.step(DT,{},air)
	check(slow.velocity.y > -3.0,"No drop off a jump (%.1f m/s)" % slow.velocity.y)
	var fresh := SkyGlide.new()
	fresh.launch(Vector3(0.0,10.0,0.0),0.0,SkyGlide.MIN,false)
	fresh.speed = SkyGlide.MIN
	fresh.step(DT*30,{"rise":1.0},air)
	var weak := fresh.climb
	var fast := SkyGlide.new()
	fast.launch(Vector3(0.0,10.0,0.0),0.0,12.0,false)
	fast.step(DT*30,{"rise":1.0},air)
	check(weak < fast.climb*0.2,"Slow, Rise barely bites; with speed it climbs (%.2f vs %.2f m/s)" % [weak,fast.climb])

## Flapping is the glide's own lift: from a slow flutter, kept-up flaps
## climb; asking faster than the stroke gives no more;
## the steady climb stays under a thermal's; and the ceiling still holds.
func _flaps() -> void:
	var still := SkyGlide.new()
	still.launch(Vector3(0.0,10.0,0.0),0.0,0.0,false)
	fly(still,6.0,{})
	var risen := SkyGlide.new()
	risen.launch(Vector3(0.0,10.0,0.0),0.0,0.0,false)
	for i in range(int(6.0/DT)): risen.step(DT,{"flap":i % 24 == 0},air)
	check(risen.position.y > 14.0 and risen.position.y > still.position.y+8.0,"Flapping from a flutter climbs (%.1f m against %.1f m let be)" % [risen.position.y,still.position.y])
	var mashed := SkyGlide.new()
	mashed.launch(Vector3(0.0,10.0,0.0),0.0,0.0,false)
	for i in range(int(6.0/DT)): mashed.step(DT,{"flap":true},air)
	check(mashed.flaps <= int(6.0/SkyGlide.FLAP_STROKE)+1 and absf(mashed.position.y-risen.position.y) < 3.0,"Mashing flaps no faster than the stroke (%d flaps)" % mashed.flaps)
	var climb := (mashed.position.y-10.0)/6.0
	check(climb > 1.0 and climb < 3.5,"Kept up, it climbs steadily but gently (%.1f m/s)" % climb)
	var high := SkyGlide.new()
	high.launch(Vector3(0.0,SkyGlide.CEILING+SkyGlide.CEILING_FADE+5.0,0.0),0.0,6.0,false)
	var top := high.position.y
	for i in range(int(6.0/DT)): high.step(DT,{"flap":true},air)
	check(high.position.y < top,"Over the ceiling, flaps don't lift it")

## A plate 28 m across with its ground at 0, as the landing sees it.
func plate(p: Vector3) -> Variant:
	if absf(p.x) > 14.0 or absf(p.z) > 14.0: return null
	return Vector2(0.0,-8.0)

func _approach() -> void:
	# From 20 m up beside the plate, heading away from it, it turns in, comes
	# down steeply, flares and skims in at a walk.
	var glide := SkyGlide.new()
	glide.launch(Vector3(10.0,20.0,10.0),0.0,8.0,false)
	glide.approach = true
	glide.approach_target = Vector3.ZERO
	var lowest_pitch := 0.0
	var skimmed := -1.0
	for i in range(int(20.0/DT)):
		glide.step(DT,{},plate)
		lowest_pitch = minf(lowest_pitch,glide.pitch)
		if glide.skimming:
			skimmed = i*DT
			break
	check(skimmed > 0.0 and skimmed < 12.0,"Coming in to land, it reaches the plate (%.1f s)" % skimmed)
	check(absf(glide.position.x) <= 14.0 and absf(glide.position.z) <= 14.0,"On the plate, though it set off heading away")
	check(glide.speed < SkyGlide.APPROACH_SPEED+0.5,"Slow enough to land (%.1f m/s)" % glide.speed)
	check(lowest_pitch < -0.2 and glide.pitch > -0.15,"Nose down high, flared by the ground (%.2f, then %.2f rad)" % [lowest_pitch,glide.pitch])
	var called := SkyGlide.new()
	called.launch(Vector3(0.0,20.0,0.0),0.0,8.0,false)
	called.approach = true
	called.step(DT,{"flap":true},plate)
	check(not called.approach,"A flap calls the landing off")
