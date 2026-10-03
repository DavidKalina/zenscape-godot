extends SceneTree
## Flowers from the hand (scripts/flower_paint.gd, scripts/flower_sowing.gd,
## docs/scenic/handful.md "Flower seed"). Headless.
##
## Painting on a flat plate: a stroke places flowers under the brush and
## nowhere else, showing each the frame it is placed, growing in at once, in
## one undo step; its edge feathers; passes and lingering thicken it toward a
## full drift's core and no further; a second stroke fills, never stacks; a
## tap paints a small dab; the pips size the brush; Shift thins (a pass takes
## some, passes clear it, nothing outside the brush is touched, undo brings
## them back); none on water, steep ground, painted rock, under trees or on
## stones; each slot paints its kinds (sunflowers in rows); the wash; saves;
## a painted frame's cost.
##
## The veil's drift (kept for pollen from existing life later): a handful's
## landings grow a drift inside where they fell, and the flower veil rides the
## air further than tree seed's.
##
## The bar: every flower slot has a faceted icon and a small-caps name and is
## painted; tree seeds are painted too (tests/test_hand_trees.gd); reeds
## still scatter.
##
## In the cozy scene (the hand scheme, real input): a poppy stroke shows its
## flowers from the press's own frame, with no refresh while the button is
## down and the brush's footprint showing; one undo step; the land's batches
## take them over once settled; Shift-drag thins and undoes; a tap dabs; the
## world saves and reopens with them.
const FlowerPaint = preload("res://scripts/flower_paint.gd")
const FlowerSowing = preload("res://scripts/flower_sowing.gd")
const MeadowTypes = preload("res://scripts/meadow_types.gd")
const Tray = preload("res://scripts/materials_tray.gd")
const Icons = preload("res://scripts/hud_icons.gd")
const Materials = preload("res://scripts/hand_materials.gd")
const Palette = preload("res://scripts/command_palette.gd")
const Emergence = preload("res://scripts/emergence.gd")
const Wind = preload("res://scripts/pollen_wind.gd")

var failures := 0
var only := ""

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: "+message)
	else:
		print("PASS: "+message)

func _flat_data() -> NativeTerrainData:
	var source: Node3D = load("res://assets/zen_reference/geometry.scn").instantiate()
	var data := NativeTerrainData.new()
	data.setup(source.get_node("terrain").mesh)
	data.reset_flat()
	source.free()
	return data

## A handful's landings: `count` motes spread evenly over a disc of `radius`
## round `centre`, landing over 4 s.
static func handful(centre: Vector2, radius: float, count: int, salt: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = salt
	var points := PackedVector2Array()
	var times := PackedFloat32Array()
	for i in range(count):
		points.append(centre+Vector2.from_angle(rng.randf()*TAU)*radius*sqrt(rng.randf()))
		times.append(6.0+rng.randf()*4.0)
	return [points,times]

## A sweep's landings: a band `width` across along a to b.
static func band(a: Vector2, b: Vector2, width: float, per_metre: float, salt: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = salt
	var points := PackedVector2Array()
	var times := PackedFloat32Array()
	var length := a.distance_to(b)
	var across := (b-a).normalized().orthogonal()
	for i in range(int(length*per_metre)):
		var t := rng.randf()
		points.append(a.lerp(b,t)+across*(rng.randf()-0.5)*width+Vector2(rng.randfn(0.0,0.15),rng.randfn(0.0,0.15)))
		times.append(6.0+t*0.6+rng.randf()*3.5)
	return [points,times]

func _sown(data: NativeTerrainData, ids: Array) -> Array:
	var out := []
	for item: Dictionary in data.objects:
		if int(item.id) in ids: out.append(item)
	return out

func run() -> void:
	create_timer(900).timeout.connect(func() -> void: print("FAIL: timed out"); quit(2))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="): only = arg.trim_prefix("--only=")
	if only.is_empty() or only == "unit":
		painting()
		units()
		veils()
		bar()
	if only.is_empty() or only == "scene":
		await in_scene()
	print("Hand flowers: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures else 0)

# --- The veil's drift on a flat plate (kept for pollen later) ------------------------------------------------------

func units() -> void:
	var data := _flat_data()
	var sowing := FlowerSowing.new(data,"poppy",4242)
	var centre := Vector2(-3.0,2.0)
	var landed: Array = handful(centre,1.6,110,1)
	var now := Emergence.time
	data.begin_stroke()
	var grown: Dictionary = sowing.grow(landed[0],landed[1],1,now)
	check(data.end_stroke(),"A sowing is one undo step")
	var flowers := _sown(data,grown.placed)
	var poppies := flowers.filter(func(item: Dictionary) -> bool: return item.asset == "poppy").size()
	var outside := flowers.filter(func(item: Dictionary) -> bool: return Vector2(item.x,item.z).distance_to(centre) > 1.6+FlowerSowing.KERNEL*1.5).size()
	var core := flowers.filter(func(item: Dictionary) -> bool: return Vector2(item.x,item.z).distance_to(centre) < 0.8).size()
	print("handful: %d flowers (%d poppies), %d in the 0.8 m core, kinds %s, %d cells washed" % [flowers.size(),poppies,core,str(grown.kinds),grown.washed])
	check(flowers.size() >= 90,"A handful of poppy seed comes up as a dense drift (%d flowers on ~8 m²)" % flowers.size())
	check(core >= int(PI*0.64/(0.2*0.2)*MeadowTypes.packing("poppy")*0.75),"Its core is packed (%d in the middle 0.8 m)" % core)
	check(poppies >= flowers.size()*0.8 and poppies < flowers.size(),"It is poppies with a few companions (%d of %d)" % [poppies,flowers.size()])
	check(outside == 0,"Every flower stands where the seed came down (%d outside)" % outside)
	check(int(grown.washed) > 0,"The ground under the drift is washed toward the poppies (%d cells)" % grown.washed)
	var hand := flowers.all(func(item: Dictionary) -> bool: return item.get("source") == "hand")
	check(hand,"Sown flowers are hand work, so emergence leaves them")
	# It blooms in the order it landed, over BLOOM seconds.
	var births: Array = flowers.map(func(item: Dictionary) -> float: return float(item.born)-now)
	births.sort()
	check(births[0] >= 0.0 and births.back() <= FlowerSowing.BLOOM_DELAY+FlowerSowing.BLOOM+FlowerSowing.BLOOM_JITTER+0.01 and births.back()-births[0] > 1.0,
		"It grows in visibly, from %.2f to %.2f s" % [births[0],births.back()])
	# Its edge feathers: the outer ring is thinner than the core.
	var ring := flowers.filter(func(item: Dictionary) -> bool: var d := Vector2(item.x,item.z).distance_to(centre); return d > 1.3 and d < 1.9).size()
	var ring_area := PI*(1.9*1.9-1.3*1.3)
	check(float(ring)/ring_area < float(core)/(PI*0.64)*0.75,"Its edge is softer than its core (%.1f against %.1f a m²)" % [ring/ring_area,core/(PI*0.64)])
	# A second sowing over it fills, never doubles.
	var before := data.objects.size()
	var again: Array = handful(centre,1.6,110,2)
	data.begin_stroke()
	var second: Dictionary = sowing.grow(again[0],again[1],2,now)
	data.end_stroke()
	var crowded := 0
	var all := _sown(data,grown.placed+second.placed)
	for i in range(all.size()):
		for j in range(i+1,all.size()):
			if Vector2(all[i].x,all[i].z).distance_to(Vector2(all[j].x,all[j].z)) < FlowerSowing.ROOM*0.99: crowded += 1
	print("second sowing: +%d" % (data.objects.size()-before))
	check(crowded == 0 and data.objects.size()-before < flowers.size(),"A second sowing fills the gaps (+%d) and stacks none (%d too close)" % [data.objects.size()-before,crowded])
	# Undo takes the sowing and its wash away.
	var tint := data.tint.duplicate()
	data.undo()
	check(data.objects.size() == before and data.tint != tint,"Undo takes the second sowing back whole")
	# Saves: object records, reopened as they were (births only animate).
	var reopened := _flat_data()
	check(reopened.load_document(JSON.parse_string(JSON.stringify(data.to_document()))),"A world with sown flowers saves and reopens")
	var same := reopened.objects.size() == data.objects.size()
	for i in range(mini(reopened.objects.size(),data.objects.size())):
		var a: Dictionary = data.objects[i].duplicate()
		a.erase("born")
		if JSON.stringify(a) != JSON.stringify(reopened.objects[i]): same = false
	check(same and reopened.tint == data.tint,"Its flowers and wash reopen as they were")

	# The ground decides: none on water, a steep peak, painted rock, under trees.
	var ground := _flat_data()
	ground.ponds.append({"x":4.0,"z":-4.0,"level":0.4})
	ground.mountain(Vector2(-5.0,-5.0),2.4,6.0)
	var rock: Color = ground._palette.rock[0]
	for i in range(8): ground.paint_tint(Vector2(5.0,5.0),3.4,rock,1.0)
	for k in range(6): ground.place("broadleaf",Vector2(-5.0,5.0)+Vector2.from_angle(k*TAU/6.0)*1.1,0.0,1.0)
	ground.place("broadleaf",Vector2(-5.0,5.0),0.0,1.0)
	ground.place("rock",Vector2(0.0,-5.0),0.0,1.0)
	var refuse := FlowerSowing.new(ground,"poppy",4242)
	for spot: Array in [["water",Vector2(4.0,-4.0),0.9],["a steep peak",Vector2(-5.0,-5.0),1.0],["painted rock",Vector2(5.0,5.0),0.7],["dense forest",Vector2(-5.0,5.0),1.0]]:
		var on: Array = handful(spot[1],float(spot[2]),110,3)
		var made: Dictionary = refuse.grow(on[0],on[1],3,now)
		var steep := 0
		if spot[0] == "a steep peak":
			for item in _sown(ground,made.placed):
				if preload("res://scripts/native_landscape_presets.gd")._slope(ground,Vector2(item.x,item.z)) > FlowerSowing.STEEP: steep += 1
			check(steep == 0,"No flower takes on a slope over %.2f (%d did)" % [FlowerSowing.STEEP,steep])
		else:
			check(made.placed.size() == 0,"No flower takes on %s (%d did, %d refused)" % [spot[0],made.placed.size(),made.refused])
	var stone := refuse.grow(handful(Vector2(0.0,-5.0),0.6,60,4)[0],handful(Vector2(0.0,-5.0),0.6,60,4)[1],4,now)
	var on_stone := _sown(ground,stone.placed).filter(func(item: Dictionary) -> bool: return Vector2(item.x,item.z).distance_to(Vector2(0.0,-5.0)) < FlowerSowing.STONE*0.99).size()
	check(on_stone == 0,"Nothing grows on a stone (%d did)" % on_stone)

	# Each slot grows its kinds: dandelions with their clocks, cosmos,
	# sunflowers in rows, and the wildflower meadow's mix.
	for slot: String in ["dandelion","cosmos","sunflower","wildflower"]:
		var plate := _flat_data()
		var sow := FlowerSowing.new(plate,slot,777)
		var swept: Array = band(Vector2(-7.0,-1.0),Vector2(7.0,1.0),2.6,110.0,5)
		var began := Time.get_ticks_usec()
		var made: Dictionary = sow.grow(swept[0],swept[1],5,now)
		var took := (Time.get_ticks_usec()-began)/1000.0
		print("%s sweep: %d flowers %s, grown in %.0f ms from %d landings" % [slot,made.placed.size(),str(made.kinds),took,swept[0].size()])
		var expect: Array = {"dandelion":["dandelion","dandelion_clock"],"cosmos":["cosmos"],"sunflower":["sunflower"],"wildflower":["oxeye_daisy","buttercup","poppy"]}[slot]
		var main := 0
		for kind: String in expect: main += int(made.kinds.get(kind,0))
		check(made.placed.size() >= 120 and main >= made.placed.size()*0.75,"A %s sweep comes up as %s (%d of %d)" % [slot," and ".join(expect),main,made.placed.size()])
		if slot == "dandelion": check(int(made.kinds.get("dandelion",0)) > 0 and int(made.kinds.get("dandelion_clock",0)) > 0,"Dandelions come with seed clocks")
		if slot == "wildflower": check(made.kinds.size() >= 3,"The wildflower slot sows a mix (%d kinds)" % made.kinds.size())
		if slot == "sunflower":
			var rows := 0
			for item in _sown(plate,made.placed):
				if item.asset == "sunflower" and sow.meadow.on_row(Vector2(item.x,item.z),"sunflower"): rows += 1
			check(rows == int(made.kinds.get("sunflower",0)) and made.placed.size() < 600,"Sunflowers stand in rows, a stand not a carpet (%d)" % rows)
	# In a meadow world the wildflower slot sows the world's own meadow.
	var cosmos_world := _flat_data()
	cosmos_world._recipe_settings = {"kind":"inland","biome":"meadow","meadow":"cosmos"}
	check(FlowerSowing.type_for("wildflower",cosmos_world._recipe_settings) == "cosmos" and FlowerSowing.type_for("poppy",cosmos_world._recipe_settings) == "wildflower",
		"In a cosmos meadow the wildflower slot sows cosmos; poppy stays poppy")

## A stand-in atmosphere: one steady breeze, no gusts (scripts/pollen_wind.gd
## reads these).
class StillAir extends Node:
	var _air_angle := 0.0
	var _air_strength := 0.5
	var swell := 0.0
	var _wind_time := 0.0
	var _gust_distance := 0.0
	func gust_at(_t: float) -> float: return 1.0

class Stage extends Node:
	var _atmosphere: Node

## The flower veil on one steady breeze, beside a tree's: it drifts
## FlowerSowing.CARRY times as far, and falls closer to its sweep.
func veils() -> void:
	var stage := Stage.new()
	stage._atmosphere = StillAir.new()
	var plate := Node3D.new()
	root.add_child(plate)
	var drifts := {}
	var widths := {}
	for kind: String in ["tree","flower"]:
		var cloud: Node3D = preload("res://scripts/pollen_cloud.gd").new()
		cloud.scene = stage
		plate.add_child(cloud)
		cloud.set_process(false)
		var look := {} if kind == "tree" else {"spread":FlowerSowing.SPREAD,"carry":FlowerSowing.CARRY,"colour":FlowerSowing.look("poppy")}
		cloud.gather(Vector3(-4.0,0.0,0.0),FlowerSowing.RADIUS,1.0,"broadleaf",77,look)
		for i in range(30):
			cloud.hold(Vector3(-4.0+i*0.1,0.0,0.0))
			cloud._process(1.0/30.0)
		var out := {}
		cloud.settled.connect(func(c: Dictionary) -> void: out.merge(c))
		cloud.release()
		for i in range(900):
			if not out.is_empty(): break
			cloud._process(1.0/60.0)
		drifts[kind] = (out.drift as Vector2).length()
		var spread := 0.0
		for q: Vector2 in out.points: spread = maxf(spread,absf(q.y))
		widths[kind] = spread
	print("veils on one breeze: tree drift %.2f m, half-width %.2f m; flower drift %.2f m, half-width %.2f m" % [drifts.tree,widths.tree,drifts.flower,widths.flower])
	check(drifts.tree > 1.0 and absf(drifts.flower/drifts.tree-FlowerSowing.CARRY) < 0.05,"Flower fluff rides the air %.2fx as far as tree seed (%.2f)" % [FlowerSowing.CARRY,drifts.flower/maxf(drifts.tree,0.001)])
	check(widths.flower < widths.tree,"It comes down closer to its sweep (%.2f m against %.2f m)" % [widths.flower,widths.tree])
	plate.queue_free()
	stage._atmosphere.free()
	stage.free()

# --- Painting on a flat plate ----------------------------------------------------------

## A stroke of `slot` at `size` along `path` (plate points) at `speed` m/s,
## frames of 1/60 s, then `hold` s held still at its end; `passes` times back
## and forth. Returns the stroke, finished (its summary in `.last`).
func paint_on(data: NativeTerrainData, slot: String, path: Array, speed := 3.0, passes := 1, size := 1.0, thinning := false, hold := 0.0, salt := 1) -> Dictionary:
	var sowing := FlowerSowing.new(data,slot,4242)
	var stroke = FlowerPaint.new(sowing,size,thinning,salt)
	data.begin_stroke()
	var records := 0
	var removed := 0
	var made: Dictionary = stroke.press(path[0])
	records += made.records.size()
	removed += made.removed.size()
	var points := []
	for k in range(passes):
		var leg: Array = path if k%2 == 0 else path.duplicate()
		if k%2 == 1: leg.reverse()
		for i in range(leg.size()-1):
			var a: Vector2 = leg[i]
			var b: Vector2 = leg[i+1]
			var frames := maxi(1,ceili(a.distance_to(b)/(speed/60.0)))
			for f in range(1,frames+1):
				made = stroke.stroke(a.lerp(b,float(f)/frames),1.0/60.0)
				records += made.records.size()
				removed += made.removed.size()
	var end: Vector2 = path[-1] if passes%2 == 1 else path[0]
	for f in range(int(hold*60.0)):
		made = stroke.stroke(end,1.0/60.0)
		records += made.records.size()
		removed += made.removed.size()
	var summary: Dictionary = stroke.finish()
	summary.changed = data.end_stroke()
	summary.records = records
	summary.removed_seen = removed
	summary.stroke = stroke
	return summary

## Flowers in `data` within `reach` of `centre`.
static func near(data: NativeTerrainData, centre: Vector2, reach: float) -> int:
	return data.objects.filter(func(item: Dictionary) -> bool: return FlowerPaint.is_flower(str(item.asset)) and Vector2(item.x,item.z).distance_to(centre) < reach).size()

## Distance from `p` to the polyline `path`.
static func off_path(p: Vector2, path: Array) -> float:
	var best := INF
	for i in range(path.size()-1):
		best = minf(best,p.distance_to(Geometry2D.get_closest_point_to_segment(p,path[i],path[i+1])))
	return best

func painting() -> void:
	var radius := FlowerPaint.RADIUS
	# Leak allowed past the brush: the coat is read between 0.25 m cells.
	var leak := FlowerPaint.CELL*1.5
	# One stroke: flowers come up under the brush and nowhere else.
	var data := _flat_data()
	var path := [Vector2(-6.0,0.0),Vector2(6.0,0.0)]
	var one: Dictionary = paint_on(data,"poppy",path)
	var flowers := _sown(data,one.placed)
	var outside := flowers.filter(func(item: Dictionary) -> bool: return off_path(Vector2(item.x,item.z),path) > radius+leak).size()
	var poppies := flowers.filter(func(item: Dictionary) -> bool: return item.asset == "poppy").size()
	print("one poppy pass, 12 m: %d flowers %s, %d dabs, %d cells washed" % [flowers.size(),str(one.kinds),one.dabs,one.washed])
	check(flowers.size() >= 120,"A pass of the brush paints a drift under it (%d flowers over 12 m)" % flowers.size())
	check(outside == 0,"Every flower stands under the brush (%d outside %.1f m of its path)" % [outside,radius+leak])
	check(poppies >= flowers.size()*0.85 and poppies < flowers.size(),"Poppies, with a few companions (%d of %d)" % [poppies,flowers.size()])
	check(one.changed and one.records == flowers.size(),"Every flower showed the frame it was placed (%d of %d) in one undo step" % [one.records,flowers.size()])
	check(flowers.all(func(item: Dictionary) -> bool: return item.get("source") == "hand"),"Painted flowers are hand work")
	var now := Emergence.time
	check(flowers.all(func(item: Dictionary) -> bool: return float(item.born)-now <= FlowerPaint.SPROUT+0.001 and float(item.born) >= now-0.001),"They grow in at once (born within %.1f s of the stroke)" % FlowerPaint.SPROUT)
	# The edge feathers: within the outer third of the brush it is thinner.
	var core := flowers.filter(func(item: Dictionary) -> bool: return absf(item.z) < radius*0.35 and absf(item.x) < 5.0).size()/(10.0*radius*0.7)
	var edge := flowers.filter(func(item: Dictionary) -> bool: return absf(item.z) > radius*0.65 and absf(item.x) < 5.0).size()/(10.0*(radius*0.35+leak)*2.0)
	print("one pass: core %.1f a m², edge %.1f a m²" % [core,edge])
	check(edge < core*0.5,"The stroke's edge feathers (%.1f a m² against %.1f at its middle)" % [edge,core])
	# Undo takes the stroke back whole.
	var count := data.objects.size()
	data.undo()
	check(data.objects.size() == count-flowers.size() and data.objects.is_empty(),"One undo takes the whole stroke back")

	# Passes thicken toward a cap.
	var dense := []
	for passes in [1,2,4,8]:
		var plate := _flat_data()
		paint_on(plate,"poppy",path,3.0,passes)
		dense.append(near(plate,Vector2.ZERO,0.6)/(PI*0.36))
	var cap := MeadowTypes.packing("poppy")/(FlowerSowing.SPACING*FlowerSowing.SPACING)
	print("core density by passes 1, 2, 4, 8: %s a m² (cap %.1f)" % [str(dense.map(func(v: float) -> String: return "%.1f" % v)),cap])
	check(dense[1] > dense[0]*1.3 and dense[2] >= dense[1],"Going over it again thickens it (%.1f, %.1f, %.1f a m²)" % [dense[0],dense[1],dense[2]])
	check(dense[3] <= cap*1.05 and dense[3] < dense[2]*1.15,"Up to a cap, a full drift's core (%.1f a m², cap %.1f)" % [dense[3],cap])
	check(dense[2] >= cap*0.6,"Four passes pack it near the cap (%.1f of %.1f)" % [dense[2],cap])
	# A second stroke over the first fills, never stacks.
	var twice := _flat_data()
	var first: Dictionary = paint_on(twice,"poppy",path,3.0,1,1.0,false,0.0,1)
	var second: Dictionary = paint_on(twice,"poppy",path,3.0,1,1.0,false,0.0,2)
	var crowded := 0
	var all := twice.objects
	for i in range(all.size()):
		for j in range(i+1,all.size()):
			if absf(all[i].x-all[j].x) < 0.12 and Vector2(all[i].x,all[i].z).distance_to(Vector2(all[j].x,all[j].z)) < FlowerSowing.ROOM*0.99: crowded += 1
	check(second.placed.size() > 0 and crowded == 0,"A second stroke fills (+%d after %d) and stacks none (%d too close)" % [second.placed.size(),first.placed.size(),crowded])
	# Lingering thickens: held still for two seconds the core is full.
	var linger := _flat_data()
	paint_on(linger,"poppy",[Vector2(2.0,2.0),Vector2(2.0,2.0)],3.0,1,1.0,false,2.0)
	var held_core := near(linger,Vector2(2.0,2.0),0.6)/(PI*0.36)
	check(held_core >= cap*0.6,"Held still, the brush packs a core (%.1f a m², cap %.1f)" % [held_core,cap])

	# A tap paints a small dab; a stroke much more.
	var tap := _flat_data()
	var dab: Dictionary = paint_on(tap,"cosmos",[Vector2(-3.0,4.0)])
	var dab_out := _sown(tap,dab.placed).filter(func(item: Dictionary) -> bool: return Vector2(item.x,item.z).distance_to(Vector2(-3.0,4.0)) > radius*FlowerPaint.TAP_SHARE+leak).size()
	print("tap: %d flowers %s" % [dab.placed.size(),str(dab.kinds)])
	check(dab.placed.size() >= 8 and dab.placed.size() < flowers.size()/4,"A tap paints a small dab (%d flowers)" % dab.placed.size())
	check(dab_out == 0,"Inside the tap's small reach (%d outside %.2f m)" % [dab_out,radius*FlowerPaint.TAP_SHARE+leak])
	# The pips size the brush.
	var small := _flat_data()
	var wide := _flat_data()
	var s: Dictionary = paint_on(small,"poppy",path,3.0,1,0.6)
	var w: Dictionary = paint_on(wide,"poppy",path,3.0,1,1.5)
	var s_out := _sown(small,s.placed).filter(func(item: Dictionary) -> bool: return absf(item.z) > radius*0.6+leak).size()
	print("brush sizes: small %d, middle %d, wide %d flowers" % [s.placed.size(),flowers.size(),w.placed.size()])
	check(s.placed.size() < flowers.size() and w.placed.size() > flowers.size() and s_out == 0,"The pips size the brush (%d, %d, %d flowers; %d past the small one)" % [s.placed.size(),flowers.size(),w.placed.size(),s_out])

	# Shift thins: a pass takes some, passes take the rest; nothing outside.
	var thinned := _flat_data()
	paint_on(thinned,"poppy",path,3.0,4)
	var before_core := near(thinned,Vector2.ZERO,0.6)
	var aside := _flat_data()
	paint_on(aside,"poppy",[Vector2(-6.0,5.0),Vector2(6.0,5.0)],3.0,2)
	var thin_path := [Vector2(-2.0,0.0),Vector2(2.0,0.0)]
	var outside_before := thinned.objects.filter(func(item: Dictionary) -> bool: return off_path(Vector2(item.x,item.z),thin_path) > radius+leak).size()
	var thin_one: Dictionary = paint_on(thinned,"poppy",thin_path,3.0,1,1.0,true)
	var after_one := near(thinned,Vector2.ZERO,0.6)
	var outside_after := thinned.objects.filter(func(item: Dictionary) -> bool: return off_path(Vector2(item.x,item.z),thin_path) > radius+leak).size()
	paint_on(thinned,"poppy",thin_path,3.0,3,1.0,true)
	var after_more := near(thinned,Vector2.ZERO,0.6)
	print("thinning the core: %d, one pass %d, four %d (%d gone in the first, %d hidden as it went)" % [before_core,after_one,after_more,thin_one.removed.size(),thin_one.removed_seen])
	check(after_one < before_core*0.75 and after_one > 0,"Shift thins: one pass takes some (%d of %d left)" % [after_one,before_core])
	check(after_more <= before_core*0.05,"Going over it clears it (%d left)" % after_more)
	check(outside_after == outside_before,"Thinning touches nothing outside the brush (%d before, %d after)" % [outside_before,outside_after])
	check(thin_one.placed.is_empty() and thin_one.removed_seen == thin_one.removed.size(),"Thinning places nothing and every flower taken was hidden as it went")
	thinned.undo()
	check(near(thinned,Vector2.ZERO,0.6) == after_one,"One undo brings a thinning stroke's flowers back")

	# The ground decides: none on water, a steep peak, painted rock, under trees, on a stone.
	var ground := _flat_data()
	ground.ponds.append({"x":4.0,"z":-4.0,"level":0.4})
	ground.mountain(Vector2(-5.0,-5.0),2.4,6.0)
	var rock: Color = ground._palette.rock[0]
	for i in range(8): ground.paint_tint(Vector2(5.0,5.0),3.4,rock,1.0)
	for k in range(6): ground.place("broadleaf",Vector2(-5.0,5.0)+Vector2.from_angle(k*TAU/6.0)*1.1,0.0,1.0)
	ground.place("broadleaf",Vector2(-5.0,5.0),0.0,1.0)
	ground.place("rock",Vector2(0.0,-5.0),0.0,1.0)
	for spot: Array in [["water",Vector2(4.0,-4.0),0.4],["a steep peak",Vector2(-5.0,-5.0),0.0],["painted rock",Vector2(5.0,5.0),0.5],["dense forest",Vector2(-5.0,5.0),0.4]]:
		var at: Vector2 = spot[1]
		var made: Dictionary = paint_on(ground,"poppy",[at-Vector2(float(spot[2]),0.0),at+Vector2(float(spot[2]),0.0)],1.0,4,0.6)
		if spot[0] == "a steep peak":
			var steep := 0
			for item in _sown(ground,made.placed):
				if preload("res://scripts/native_landscape_presets.gd")._slope(ground,Vector2(item.x,item.z)) > FlowerSowing.STEEP: steep += 1
			check(steep == 0 and made.refused > 0,"No flower is painted on a slope over %.2f (%d were; %d spots refused)" % [FlowerSowing.STEEP,steep,made.refused])
		else:
			check(made.placed.size() == 0,"No flower is painted on %s (%d were, %d refused)" % [spot[0],made.placed.size(),made.refused])
	var on_stone: Dictionary = paint_on(ground,"poppy",[Vector2(0.0,-5.0)],1.0,1,0.6,false,1.0)
	var stone_hit := _sown(ground,on_stone.placed).filter(func(item: Dictionary) -> bool: return Vector2(item.x,item.z).distance_to(Vector2(0.0,-5.0)) < FlowerSowing.STONE*0.99).size()
	check(stone_hit == 0,"Nothing is painted on a stone (%d were)" % stone_hit)

	# Each slot paints its kinds: dandelions with clocks, cosmos, sunflower
	# stands in rows, the wildflower meadow's mix.
	for slot: String in ["dandelion","cosmos","sunflower","wildflower"]:
		var plate := _flat_data()
		var made: Dictionary = paint_on(plate,slot,[Vector2(-7.0,-1.0),Vector2(7.0,1.0)],3.0,2,1.5)
		print("%s, two passes of the wide brush: %d flowers %s" % [slot,made.placed.size(),str(made.kinds)])
		var expect: Array = {"dandelion":["dandelion","dandelion_clock"],"cosmos":["cosmos"],"sunflower":["sunflower"],"wildflower":["oxeye_daisy","buttercup","poppy"]}[slot]
		var main := 0
		for kind: String in expect: main += int(made.kinds.get(kind,0))
		check(made.placed.size() >= 60 and main >= made.placed.size()*0.75,"A %s stroke paints %s (%d of %d)" % [slot," and ".join(expect),main,made.placed.size()])
		if slot == "dandelion": check(int(made.kinds.get("dandelion_clock",0)) > 0,"Dandelions come with seed clocks")
		if slot == "wildflower": check(made.kinds.size() >= 3,"The wildflower slot paints a mix (%d kinds)" % made.kinds.size())
		if slot == "sunflower":
			var rows := 0
			for item in _sown(plate,made.placed):
				if item.asset == "sunflower" and made.stroke.sowing.meadow.on_row(Vector2(item.x,item.z),"sunflower"): rows += 1
			check(rows == int(made.kinds.get("sunflower",0)) and made.placed.size() < 500,"Sunflowers stand in rows, a stand not a carpet (%d)" % rows)
		if slot == "cosmos":
			check(int(made.washed) > 0,"The ground under a dense drift is washed toward its flowers (%d cells)" % made.washed)
	# Saves: ordinary object records, reopened as they were.
	var saved := _flat_data()
	paint_on(saved,"cosmos",path,3.0,2)
	var reopened := _flat_data()
	check(reopened.load_document(JSON.parse_string(JSON.stringify(saved.to_document()))),"A world with painted flowers saves and reopens")
	var same := reopened.objects.size() == saved.objects.size()
	for i in range(mini(reopened.objects.size(),saved.objects.size())):
		var a: Dictionary = saved.objects[i].duplicate()
		a.erase("born")
		if JSON.stringify(a) != JSON.stringify(reopened.objects[i]): same = false
	check(same and reopened.tint == saved.tint,"Its flowers and wash reopen as they were (%d records)" % reopened.objects.size())
	# Cost: a frame of painting compares numbers once its spots are judged.
	var timing := _flat_data()
	var sowing := FlowerSowing.new(timing,"wildflower",4242)
	var stroke = FlowerPaint.new(sowing,1.5,false,9)
	timing.begin_stroke()
	stroke.press(Vector2(-8.0,-3.0))
	var worst := 0
	var total := 0
	var frames := 0
	for f in range(1,241):
		var began := Time.get_ticks_usec()
		stroke.stroke(Vector2(-8.0,-3.0).lerp(Vector2(8.0,3.0),f/240.0),1.0/60.0)
		var took := Time.get_ticks_usec()-began
		worst = maxi(worst,took)
		total += took
		frames += 1
	stroke.finish()
	timing.end_stroke()
	print("painting cost, wide wildflower brush at 4.3 m/s: mean %.2f ms, worst %.2f ms a frame (%d flowers)" % [total/1000.0/frames,worst/1000.0,stroke.placed.size()])
	check(worst < 12000,"A painted frame stays light (worst %.1f ms on the main thread)" % (worst/1000.0))

# --- The bar --------------------------------------------------------------------------

func bar() -> void:
	var ids: Array = Tray.SPECIMENS.map(func(entry: Dictionary) -> String: return entry.id)
	for slot: String in ["wildflower","dandelion","poppy","cosmos","sunflower"]:
		check(slot in ids and FlowerSowing.has(slot) and Materials.paints(slot) and not Materials.sows(slot) and not Materials.SCATTER.has(slot),"%s has a slot and is painted, not sown as a veil" % slot)
		var item := Icons.item(slot)
		check(not item.is_empty() and str(item.label).contains(" · ") and Icons.texture(slot,"icon",44.0) != null,"%s has its faceted icon and name (%s)" % [slot,item.get("label","")])
		check(Palette.SEEDS.any(func(entry: Array) -> bool: return entry[0] == slot),"%s is in the command palette" % slot)
	for seed: String in ["oak","pine","willow","birch","redwood","juniper","joshua"]:
		check(Materials.paints(seed) and not Materials.sows(seed),"%s seed is painted as trees, not sown as a veil (tests/test_hand_trees.gd)" % seed)
	check(Materials.SCATTER.has("reed") and Materials.SCATTER.has("stone") and "reed" in ids,"Reeds and stones still scatter")
	# The seed group: the tree seeds (first steps added birch, redwood, juniper
	# and Joshua to the case), the five flowers, then reed.
	var seeds: Array = Tray.SPECIMENS.filter(func(entry: Dictionary) -> bool: return entry.group == 0).map(func(entry: Dictionary) -> String: return entry.id)
	var expected := ["oak","pine","willow","birch","redwood","juniper","joshua","wildflower","dandelion","poppy","cosmos","sunflower","wheat","reed"]
	check(seeds == expected,"The seed group is seven tree seeds, five flowers, wheat and reed (%s)" % str(seeds))
	# The elements: water, stone, the stone lamp, the campfire and the cabin,
	# fence, footbridge, and the crystal still hidden.
	var elements: Array = Tray.SPECIMENS.filter(func(entry: Dictionary) -> bool: return entry.group == 1).map(func(entry: Dictionary) -> String: return entry.id)
	check(elements == ["water","stone","lamp","campfire","cabin","fence","bridge","crystal"],"The element group is water, stone, lamp, campfire, cabin, fence, footbridge and crystal (%s)" % str(elements))

# --- The cozy scene ---------------------------------------------------------------------

var scene: Node3D
var editor: Node

func screen_of(point: Vector2) -> Vector2:
	var data: NativeTerrainData = editor.data
	return scene.camera.unproject_position(editor.terrain.to_global(Vector3(point.x,float(data.sample(point,data.heights)),point.y)))

var reach: Node
var materials: Node

## The pointer at `at` (viewport), pressed or not, as the hand scheme reads it.
func button(at: Vector2, pressed: bool, shift := false) -> void:
	point(at)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.global_position = at
	event.pressed = pressed
	event.shift_pressed = shift
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func motion(at: Vector2, relative: Vector2) -> void:
	point(at)
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func point(at: Vector2) -> void:
	reach.pointer_override = at
	editor.pointer_override = at

## Paint `kind` along `path` (plate) over `seconds` through the hand: take it
## in hand, press on the land, drag, let go. While it paints: whether the
## first frame already showed flowers, the most the preview drew, the frames'
## gaps (ms) and whether any refresh ran. {"summary", "first", "drawn",
## "gaps", "refreshed", "mark"}.
func paint(kind: String, path: Array, seconds: float, shift := false) -> Dictionary:
	var out := {"first":0,"drawn":0,"gaps":[],"refreshed":false,"mark":"","veil":false}
	check(materials.take(kind) and materials.held == kind,"%s is taken in hand" % kind)
	var start := screen_of(path[0])
	point(start)
	for i in range(20): await process_frame
	button(start,true,shift)
	await process_frame
	check(reach.holding == Materials.PAINT and editor.flower_paint != null,"A press on the land with %s in hand paints" % kind)
	out.first = editor.content.paint_preview_count() if not shift else editor.content.paint_hidden
	var began := Time.get_ticks_msec()
	var was := start
	var last := Time.get_ticks_usec()
	var pending := false
	while (Time.get_ticks_msec()-began)/1000.0 < seconds:
		var t := (Time.get_ticks_msec()-began)/1000.0/maxf(seconds,0.001)
		var at := screen_of(Vector2(path[0]).lerp(path[-1],clampf(t,0.0,1.0)))
		motion(at,at-was)
		was = at
		await process_frame
		var now := Time.get_ticks_usec()
		out.gaps.append((now-last)/1000.0)
		last = now
		out.drawn = maxi(out.drawn,editor.content.paint_preview_count())
		if int(editor.refresh_pending) > 0: pending = true
		var marks: Node = reach.get("marks")
		if marks != null and marks.wanted: out.mark = str(marks.kind)
		if editor._handful_holding: out.veil = true
	out.refreshed = pending
	button(was,false,shift)
	await process_frame
	out.summary = editor.last_paint
	began = Time.get_ticks_msec()
	while int(editor.refresh_pending) > 0 and Time.get_ticks_msec()-began < 10000: await process_frame
	for i in range(4): await process_frame
	materials.put_back()
	return out

func in_scene() -> void:
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.set_meta("no_title",true)
	scene.places_path = "/private/tmp/zs-hand-flowers-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while true:
		while scene.places.busy or scene._chunk_editor.forming: await process_frame
		await create_timer(1.0).timeout
		if not scene.places.busy and not scene._chunk_editor.forming: break
	editor = scene._chunk_editor
	var waited := Time.get_ticks_msec()
	while scene._growth.terrain < 0.995 and Time.get_ticks_msec()-waited < 30000: await process_frame
	if not editor.active: scene.set_building(false)
	check(editor.active,"The land takes presses")
	scene.world_clock.running = false
	reach = scene.hand_reach
	materials = reach.get("materials")
	check(materials != null,"The hand scheme's materials are in the scene")
	if materials == null: return
	check(materials.take("poppy") and materials.held == "poppy","Poppy can be taken in hand")
	check(materials.hint("land")[1] == Materials.FLOWER_HINT and Materials.FLOWER_HINT.contains("paint"),"Its hint says to paint")
	materials.put_back()
	var data: NativeTerrainData = editor.data
	for i in range(60): await process_frame
	while int(editor.refresh_pending) > 0: await process_frame
	var steps: int = data._undo.size()
	var count := data.objects.size()
	var tint := data.tint.duplicate()
	var stroke: Dictionary = await paint("poppy",[Vector2(-4.0,3.0),Vector2(3.0,3.0)],1.2)
	var summary: Dictionary = stroke.summary
	var placed: Array = summary.get("placed",[])
	var poppies := int(summary.get("kinds",{}).get("poppy",0))
	var gaps: Array = stroke.gaps
	gaps.sort()
	print("scene poppy stroke: %d flowers %s; preview drew up to %d; frame gaps median %.1f ms, worst %.1f ms; paint work worst %.2f ms" % [placed.size(),str(summary.get("kinds",{})),stroke.drawn,gaps[gaps.size()/2],gaps.back(),float(editor.paint_usec.max() if not editor.paint_usec.is_empty() else 0)/1000.0])
	check(stroke.first > 0,"The press's own frame already shows flowers (%d instances)" % stroke.first)
	check(stroke.drawn > 0 and not stroke.refreshed,"Flowers show as they are painted, with no refresh while the button is down")
	check(stroke.mark == "flower","The brush's footprint shows while it paints (%s)" % stroke.mark)
	check(placed.size() >= 80 and poppies >= placed.size()*0.85,"A poppy stroke paints a poppy drift (%d flowers, %d poppies)" % [placed.size(),poppies])
	check(data._undo.size() == steps+1,"One undo step for the stroke (%d)" % (data._undo.size()-steps))
	check(editor.content.paint_preview_count() == 0,"Once settled the land's own batches draw them (the preview is cleared)")
	check(not stroke.veil,"No veil was flicked")
	var stray := 0
	for item: Dictionary in _sown(data,placed):
		if off_path(Vector2(item.x,item.z),[Vector2(-4.0,3.0),Vector2(3.0,3.0)]) > FlowerPaint.RADIUS*materials.size_scale()+0.5: stray += 1
	check(stray == 0,"Every flower stands under the brush's path (%d far from it)" % stray)
	# Shift thins what was painted.
	var before := near(data,Vector2(0.0,3.0),1.0)
	var thinning: Dictionary = await paint("poppy",[Vector2(-1.0,3.0),Vector2(1.0,3.0)],0.8,true)
	var after := near(data,Vector2(0.0,3.0),1.0)
	print("scene thinning: %d to %d in the middle, %d taken" % [before,after,thinning.summary.get("removed",[]).size()])
	check(after < before and thinning.summary.get("placed",[1]).is_empty(),"Shift-drag thins the flowers under the brush (%d to %d)" % [before,after])
	check(data._undo.size() == steps+2,"The thinning is its own undo step")
	editor.undo()
	for i in range(4): await process_frame
	check(near(data,Vector2(0.0,3.0),1.0) == before,"Undo brings the thinned flowers back")
	editor.undo()
	for i in range(4): await process_frame
	check(data.objects.size() == count and data.tint == tint,"Undo takes the stroke and its wash away")
	editor.redo()
	for i in range(4): await process_frame
	# A tap: a small dab.
	var dab: Dictionary = await paint("cosmos",[Vector2(-6.0,-4.0)],0.0)
	var dabbed: int = dab.summary.get("placed",[]).size()
	check(dabbed > 0 and dabbed < placed.size(),"A tap paints a small dab (%d flowers)" % dabbed)
	# Saves and reopens with the flowers.
	var document: Dictionary = data.to_document()
	var reopened := NativeTerrainData.new()
	reopened.setup(data.source_mesh)
	check(reopened.load_document(JSON.parse_string(JSON.stringify(document))) and reopened.objects.size() == data.objects.size(),"The world saves and reopens with its painted flowers")
	scene.queue_free()
	await process_frame
	await process_frame
