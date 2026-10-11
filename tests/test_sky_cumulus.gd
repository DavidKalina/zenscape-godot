extends SceneTree
## The towering cumulus (scripts/sky_tower.gd, scripts/sky_towers.gd): a
## seed always grows the same tower, 200 to 500 m over the sea and 150 to
## 300 m across; the towers are rare and well apart, clear of the mountain
## ranges; the one in sight of the plate is clear of its islands and their
## jet streams, and no island, islet or drifting cloud turns up in one; the
## in-cloud amount is 0 outside, 1 in the heart and rises on the way in; a
## thermal stands in its heart; it is no solid; it rises out of the sea from
## the foot up, stands, wanes away and rises again; and deep in one the wind
## is muffled. Headless: shapes and queries only, nothing drawn.
const SkyTower = preload("res://scripts/sky_tower.gd")
const SkyTowers = preload("res://scripts/sky_towers.gd")
const SkyPeaks = preload("res://scripts/sky_peaks.gd")
const SkyCells = preload("res://scripts/sky_cells.gd")
const SkyIslets = preload("res://scripts/sky_islets.gd")
const SkyIslands = preload("res://scripts/sky_islands.gd")
const SkyClouds = preload("res://scripts/sky_clouds.gd")
const SkyCurrents = preload("res://scripts/sky_currents.gd")
const SkyHaze = preload("res://scripts/sky_haze.gd")
const GlideAir = preload("res://scripts/glide_air.gd")
const SEEDS := [101,2024,77777,4242,9,31337]
var failures := 0

func _initialize() -> void:
	# The wonders are off in play (SkyHomes `stone`, `isles`); on here.
	preload("res://scripts/sky_homes.gd").stone = true
	preload("res://scripts/sky_homes.gd").isles = true
	# The open sky, endless, its kinds scattered through the cells (SkyHomes
	# `ring` off); the bounded world's are checked in tests/test_sky_world.gd.
	preload("res://scripts/sky_homes.gd").ring = false
	_same_seed()
	_size()
	_rare()
	_home()
	_clear()
	await _inside()
	_rises()
	await _lives()
	_drawn_over_fading_ranges()
	await _muffled()
	print("PASS: sky cumulus" if failures == 0 else "FAIL: sky cumulus")
	quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func home_shape() -> RefCounted:
	return SkyTower.make(SkyTowers.seed_of(Vector2i.ZERO))

func _same_seed() -> void:
	var a: RefCounted = home_shape()
	var b: RefCounted = home_shape()
	var c: RefCounted = SkyTower.make(SEEDS[0])
	check(a.lobes == b.lobes and a.box == b.box,"A seed grows the same tower")
	check(a.lobes != c.lobes,"Another seed grows another")
	var started := Time.get_ticks_msec()
	var baked: Dictionary = a.bake()
	var took := Time.get_ticks_msec()-started
	check(baked.data == b.bake().data,"Its bake is the same every time (%d cells, %d ms)" % [baked.data.size(),took])
	var n: Vector3i = baked.size
	var middle: Vector3 = a.box.position+a.box.size*0.5
	var i := n.x/2+n.x*(n.y/2)+n.x*n.y*(n.z/2)
	var cell: Vector3 = a.box.size/Vector3(n)
	var at: Vector3 = a.box.position+Vector3(n.x/2+0.5,n.y/2+0.5,n.z/2+0.5)*cell
	check(absf(baked.data[i]-a.distance(at)) < 0.01,"The bake holds the body's distances (%.1f m near its middle %s)" % [baked.data[i],middle])
	check(SkyTowers.spot(Vector2i(3,-2)) == SkyTowers.spot(Vector2i(3,-2)) and SkyTowers.seed_of(Vector2i(3,-2)) == SkyTowers.seed_of(Vector2i(3,-2)),"Its place is the same every time")

## The body's height over the sea and its width at mid-height, measured off
## the smooth body itself.
func _size() -> void:
	var all := SEEDS.duplicate()
	all.append(SkyTowers.seed_of(Vector2i.ZERO))
	var worst := ""
	for s: int in all:
		var t: RefCounted = SkyTower.make(s)
		var axis := Vector2.ZERO
		var high := SkyTower.SEA
		for l in t.lobes: high = maxf(high,l.y+l.w)
		var y: float = SkyTower.SEA+t.tall*0.5
		var mid: Vector2 = t._axis(y)
		var across := 0.0
		for k in range(8):
			var way := Vector2(cos(TAU*k/16.0),sin(TAU*k/16.0))
			var span := 0.0
			for side in [-1.0,1.0]:
				var r := 0.0
				while r < 400.0 and t.distance(Vector3(mid.x+way.x*side*r,y,mid.y+way.y*side*r)) < 0.0: r += 2.0
				span += r
			across = maxf(across,span)
		var tall := high-SkyTower.SEA
		if tall < 200.0 or tall > 500.0 or across < 150.0 or across > 300.0: worst += " seed %d: %.0f m tall, %.0f across;" % [s,tall,across]
	check(worst == "","Every tower stands 200-500 m over the sea and 150-300 m across"+worst)

func _rare() -> void:
	var spots := []
	var cells := 0
	for x in range(-8,9):
		for z in range(-8,9):
			cells += 1
			var s: Variant = SkyTowers.spot(Vector2i(x,z))
			if s != null: spots.append(s)
	var share := float(spots.size())/cells
	check(share > 0.08 and share < 0.4,"Towers are rare: %d in %d cells of %.0f m" % [spots.size(),cells,SkyTowers.CELL])
	var closest := INF
	for i in range(spots.size()):
		for j in range(i+1,spots.size()):
			closest = minf(closest,Vector2(spots[i].x-spots[j].x,spots[i].z-spots[j].z).length())
	check(closest > 1000.0,"They stand well apart (closest pair %.0f m)" % closest)
	var on_range := 0
	for s: Vector3 in spots:
		if SkyPeaks.blocks(s,SkyTowers.REACH): on_range += 1
	check(on_range == 0,"None stands on or beside a mountain range")

## The one in sight of the plate: near enough to see whole, clear of the
## plate, its islands and the range there.
func _home() -> void:
	var home: Variant = SkyTowers.spot(Vector2i.ZERO)
	check(home == SkyTowers.HOME,"The plate's cell holds the home tower")
	var t: RefCounted = home_shape()
	var reach := 0.0
	for l in t.lobes: reach = maxf(reach,Vector2(l.x,l.z).length()+l.w)
	var off := Vector2(SkyTowers.HOME.x,SkyTowers.HOME.z).length()
	check(off-reach > 200.0 and off < 1000.0,"It stands in sight of the plate: %.0f m off, its nearest cloud %.0f m off" % [off,off-reach])
	check(SkyHaze.fog_far(off,0.0,SkyTowers.HAZE_FAR) < 0.5,"The haze leaves it clear from the plate (%.2f hazed)" % SkyHaze.fog_far(off,0.0,SkyTowers.HAZE_FAR))
	check(reach < SkyTowers.KEEP,"Its cloud stays within its keep (%.0f m of %.0f)" % [reach,SkyTowers.KEEP])
	var nearest := INF
	for s: Vector3 in SkyIslands.OFFSETS: nearest = minf(nearest,Vector2(s.x-SkyTowers.HOME.x,s.z-SkyTowers.HOME.z).length())
	check(nearest > SkyTowers.KEEP+30.0,"Every fixed island stands clear of it (%.0f m)" % nearest)
	var peak := Vector2(SkyPeaks.HOME.x-SkyTowers.HOME.x,SkyPeaks.HOME.z-SkyTowers.HOME.z).length()
	check(not SkyPeaks.blocks(SkyTowers.HOME,SkyTowers.REACH),"It stands clear of the range in sight of the plate (%.0f m between)" % peak)
	var slots := [Vector3.ZERO]
	slots.append_array(SkyIslands.OFFSETS)
	var currents: Node3D = SkyCurrents.new()
	root.add_child(currents)
	currents.build(slots)
	var closest := INF
	for c: Dictionary in currents.currents:
		for p: Vector3 in c.points: closest = minf(closest,t.distance(p-SkyTowers.HOME))
	check(closest > 40.0,"The islands' jet streams and thermals pass clear of its cloud (%.0f m at the closest)" % closest)
	currents.free()

## Nothing else turns up in a tower: islands, islets, drifting clouds.
func _clear() -> void:
	var slots := [Vector3.ZERO]
	slots.append_array(SkyIslands.OFFSETS)
	var cells := SkyCells.new(slots)
	var towers := []
	for x in range(-4,5):
		for z in range(-4,5):
			var s: Variant = SkyTowers.spot(Vector2i(x,z))
			if s != null: towers.append(s)
	var island_in := 0
	var islands := 0
	for x in range(-20,21):
		for z in range(-20,21):
			var s: Variant = cells.spot(Vector2i(x,z))
			if s == null: continue
			islands += 1
			for t: Vector3 in towers:
				if Vector2(s.x-t.x,s.z-t.z).length() < SkyTowers.KEEP: island_in += 1
	check(island_in == 0 and islands > 100,"No island turns up in a tower (%d islands looked at)" % islands)
	var islets: Node3D = SkyIslets.new()
	islets.cells = cells
	var islet_in := 0
	for x in range(-20,21):
		for z in range(-20,21):
			var s: Variant = islets.spot(Vector2i(x,z))
			if s == null: continue
			for t: Vector3 in towers:
				if Vector2(s.x-t.x,s.z-t.z).length() < SkyTowers.KEEP: islet_in += 1
	check(islet_in == 0,"No islet stands in a tower")
	islets.free()
	var clouds: Node3D = SkyClouds.new()
	clouds.build(slots)
	var cloud_in := 0
	for c: Vector4 in clouds.clouds:
		if Vector2(c.x-SkyTowers.HOME.x,c.z-SkyTowers.HOME.z).length() < SkyTowers.KEEP+c.w: cloud_in += 1
	check(cloud_in == 0,"No drifting cloud is set in the home tower")
	clouds.free()

## Built round the eye: the in-cloud amount, the thermals, no solid.
func _inside() -> void:
	var slots := [Vector3.ZERO]
	slots.append_array(SkyIslands.OFFSETS)
	var cells := SkyCells.new(slots)
	var currents: Node3D = SkyCurrents.new()
	root.add_child(currents)
	currents.build(slots)
	var towers: Node3D = SkyTowers.new()
	root.add_child(towers)
	towers.reset(cells,currents)
	towers.advance(0.6,Vector3.ZERO)
	towers.flush()
	check(towers.tower_count() >= 1 and towers.built.has("0,0"),"The home tower is made round the plate (%d made)" % towers.tower_count())
	if not towers.built.has("0,0"):
		towers.free()
		currents.free()
		return
	var b: Dictionary = towers.built["0,0"]
	var t: RefCounted = b.shape
	# Its heart: the trunk's middle at glide height.
	var axis: Vector2 = t._axis(20.0)
	var heart: Vector3 = towers.global_of(b,Vector3(axis.x,20.0,axis.y))
	check(is_equal_approx(towers.fade(heart),1.0),"In its heart the in-cloud amount is whole (%.2f)" % towers.fade(heart))
	check(towers.fade(Vector3(0.0,20.0,0.0)) == 0.0 and towers.fade(heart+Vector3(600.0,0.0,0.0)) == 0.0,"Out in open air it is 0")
	check(towers.fade(heart+Vector3.UP*(t.tall+80.0)) == 0.0,"Over its crown it is 0")
	# Flying straight out from the heart, the amount only falls, and it
	# falls from whole to nothing about where the body's surface is.
	var way := Vector3(1.0,0.0,0.4).normalized()
	var last := 1.0
	var rising := false
	var surface := 0.0
	for k in range(0,400,2):
		var f: float = towers.fade(heart+way*k)
		if f > last+1e-5: rising = true
		if surface == 0.0 and towers.depth(heart+way*k) < 0.0: surface = k
		last = f
	check(not rising,"From the heart out it only thins")
	var at_surface: float = towers.fade(heart+way*surface)
	check(at_surface > 0.1 and at_surface < 0.6,"At the body's surface (%.0f m out) it is part way (%.2f)" % [surface,at_surface])
	var out := surface
	while towers.depth(heart+way*out) > -(SkyTowers.EDGE+1.0) and out < surface+60.0: out += 1.0
	check(out-surface < 3.0*SkyTowers.EDGE and towers.fade(heart+way*out) == 0.0,"A little past it (%.0f m on), it is gone" % (out-surface))
	var deep := Vector3.INF
	for k in range(0,int(surface),2):
		if towers.depth(heart+way*k) > SkyTowers.DEEP+1.0: deep = heart+way*k
	check(deep != Vector3.INF and towers.fade(deep) > 0.99,"DEEP inside, it is whole")
	# The thermals in its heart.
	var mine: Array = currents.currents.filter(func(c: Dictionary) -> bool: return c.get("key","") == "tower:0,0")
	check(mine.size() == SkyTowers.THERMALS,"Its thermals stand in it (%d)" % mine.size())
	var lifted := 0
	for c: Dictionary in mine:
		var p: Vector3 = (c.points[0] as Vector3)+currents.position+Vector3.UP*60.0
		var air: Dictionary = currents.air_at(p)
		if float(air.thermal) > 0.5 and (air.wind as Vector3).y > 1.0 and towers.fade(p) > 0.9: lifted += 1
	check(lifted == mine.size(),"Each lifts the glide up through the cloud's heart (%d of %d)" % [lifted,mine.size()])
	# Soft: nothing to hit.
	var solids := towers.find_children("*","CollisionObject3D",true,false).size()
	check(solids == 0 and not towers.has_method("body") and not towers.has_method("ground") and not towers.has_method("solid"),"It is no solid: nothing collides with a cloud")
	# Its box holds the whole body, and the volume is drawn first among the
	# see-through things, never casting a shadow.
	var volume: MeshInstance3D = b.node.get_node("Volume")
	check((volume.mesh as BoxMesh).size.is_equal_approx(t.box.size) and volume.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and (b.material as ShaderMaterial).render_priority < 0,"Its volume is a box round the body, drawn before other see-through things")
	# Let go far off, the thermals with it; and back when flown back to.
	towers.advance(SkyTowers.CHECK,Vector3(9000.0,0.0,9000.0))
	check(not towers.built.has("0,0") and currents.currents.filter(func(c: Dictionary) -> bool: return c.get("key","") == "tower:0,0").is_empty(),"Far off it is let go, its thermals with it")
	towers.advance(SkyTowers.CHECK,Vector3.ZERO)
	towers.flush()
	check(towers.built.has("0,0") and (towers.built["0,0"].shape.lobes as PackedVector4Array) == t.lobes,"Flown back to, the same tower is there")
	towers.queue_free()
	currents.queue_free()
	await process_frame

## Its rising: nothing over the sea at first, the front climbing to the
## crown, each lobe swelling up off its own base, whole at the end.
func _rises() -> void:
	var t: RefCounted = home_shape()
	var top_of := func(heap: PackedVector4Array) -> float:
		var high := -INF
		for l in heap: high = maxf(high,l.y+l.w)
		return high
	check(top_of.call(t.lobes_at(0.0)) <= SkyTower.SEA,"Before it rises nothing stands over the sea (%.0f m)" % (top_of.call(t.lobes_at(0.0))-SkyTower.SEA))
	var last := -INF
	var climbing := true
	var on_front := true
	for i in range(1,11):
		var g := i/10.0
		var high: float = top_of.call(t.lobes_at(g))
		if high <= last: climbing = false
		if absf(high-t.front(g)) > 0.5: on_front = false
		last = high
	check(climbing and on_front,"It climbs steadily, its head on the rising front")
	check(t.lobes_at(1.0) == t.lobes and is_equal_approx(t.front(1.0),t.crest),"Risen, it is the whole tower")
	var half: PackedVector4Array = t.lobes_at(0.5)
	var based := true
	var low := 0
	for l in half:
		var whole := false
		for w in t.lobes:
			if Vector2(l.x,l.z) == Vector2(w.x,w.z) and is_equal_approx(l.y-l.w,w.y-w.w): whole = true
		if not whole: based = false
		if l.y+l.w < SkyTower.SEA+t.tall*0.3: low += 1
	check(based and low > 0,"Each lobe swells up off its own base, the foot first (%d of %d low)" % [low,half.size()])
	check(t.bake(0.5).data != t.bake().data,"A stage of its rising bakes its own body")

## Its life, held at points along it: rising, it stands to its front and no
## higher; waned, it is gone; the lives are out of step; the home tower
## rises soon after the glide first sees it.
func _lives() -> void:
	check(is_equal_approx(SkyTowers.grown_of(SkyTowers.phase(Vector2i.ZERO)+SkyTowers.RISE_SOON),0.0) and SkyTowers.grown_of(SkyTowers.phase(Vector2i.ZERO)+SkyTowers.RISE_SOON+1.0) > 0.0,"The home tower starts rising soon after it is first seen")
	check(SkyTowers.phase(Vector2i(3,1)) != SkyTowers.phase(Vector2i(-2,4)),"The towers' lives are out of step")
	var slots := [Vector3.ZERO]
	slots.append_array(SkyIslands.OFFSETS)
	var cells := SkyCells.new(slots)
	var towers: Node3D = SkyTowers.new()
	root.add_child(towers)
	towers.reset(cells,null)
	towers.pinned = SkyTowers.REST+SkyTowers.GROW*0.3
	towers.advance(0.6,Vector3.ZERO)
	towers.flush()
	var b: Dictionary = towers.built["0,0"]
	var t: RefCounted = b.shape
	var axis: Vector2 = t._axis(SkyTower.SEA+20.0)
	var foot: Vector3 = towers.global_of(b,Vector3(axis.x,SkyTower.SEA+20.0,axis.y))
	var head: float = t.top()-t.wide*0.21
	var crown: Vector3 = towers.global_of(b,Vector3(t._axis(head).x,head,t._axis(head).y))
	check(towers.fade(foot) > 0.9 and towers.fade(crown) == 0.0,"Rising, its foot stands and its crown is not there yet (foot %.2f, crown %.2f)" % [towers.fade(foot),towers.fade(crown)])
	check(b.pair == SkyTowers._stage(b.grown) and absf(b.grown-0.3) < 0.03,"It shows the stage its life has come to (%.3f)" % b.grown)
	var material: ShaderMaterial = b.material
	var risen_top: float = material.get_shader_parameter("top")
	check(risen_top < t.top()-50.0,"Its crown's light follows its head (top %.0f of %.0f)" % [risen_top,t.top()])
	towers.pinned = SkyTowers.MATURE
	towers.flush()
	check(towers.fade(crown) > 0.9 and b.wane == 0.0,"Standing, it is whole to the crown (%.2f)" % towers.fade(crown))
	towers.pinned = SkyTowers.LIFE
	towers.flush()
	check(towers.fade(foot) == 0.0 and towers.screens(Vector3.ZERO).is_empty() and is_equal_approx(float(material.get_shader_parameter("wane")),1.0),"Waned, it is gone")
	# A new life: shown nothing till its first stages are baked, then rises.
	towers.pinned = 0.0
	towers.advance(0.0,Vector3.ZERO)
	check(b.wane >= 1.0 or b.pair == 0,"A new life never shows the last one's tower")
	towers.flush()
	check(b.pair == 0 and b.wane == 0.0,"Then it rests, ready to rise")
	towers.queue_free()
	await process_frame

## A range fading (its swap with its skyline, its near and far faces
## crossfading) is drawn with the see-through things, and the tower stands
## no depth: the range must draw before the tower and the cloud sea, or it
## shows through a tower in front of it (tools/probe_tower_seethrough.gd
## sees it rendered).
func _drawn_over_fading_ranges() -> void:
	var peaks: Node3D = SkyPeaks.new()
	var ground: Material = peaks._ground()
	var sea_priority: int = preload("res://scripts/sky_sea.gd").RENDER_PRIORITY
	check(ground.render_priority < SkyTowers.RENDER_PRIORITY and ground.render_priority < sea_priority,"A fading range draws before the tower and the cloud sea (%d, %d, %d)" % [ground.render_priority,SkyTowers.RENDER_PRIORITY,sea_priority])
	peaks.free()

## Deep in a tower the wind closes down and quietens, and the streaks thicken.
func _muffled() -> void:
	var open_air: Node3D = GlideAir.new()
	var cloud: Node3D = GlideAir.new()
	root.add_child(open_air)
	root.add_child(cloud)
	for i in range(120):
		open_air.advance(1.0/60.0,Vector3(0.0,0.0,-20.0),0.0,0.0,0.0,0.0)
		cloud.advance(1.0/60.0,Vector3(0.0,0.0,-20.0),0.0,0.0,0.0,1.0)
	check(cloud._open < open_air._open*0.5 and cloud._gain < open_air._gain*0.8,"In cloud the wind is muffled (open %.3f vs %.3f, gain %.3f vs %.3f)" % [cloud._open,open_air._open,cloud._gain,open_air._gain])
	check(cloud._shown > open_air._shown,"And the streaks thicken into the cloud's wisps")
	open_air.queue_free()
	cloud.queue_free()
	await process_frame
