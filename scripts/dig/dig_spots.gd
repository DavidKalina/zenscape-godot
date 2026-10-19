extends Node3D
## The wreck cluster's dig spots (docs/design/dig/spec-dig.md, loop `dig`,
## task 3): a dozen strange spots in its soil, each marked by a small
## surface tell a curious walker notices up close (a mound of turned earth,
## a ring or a line of small stones, a lone leaning marker stone, a patch
## of dead grass, a strap or a box's corner poking out), each with a find
## buried under it. Digging one (scripts/dig/dig.gd: a dig whose bite lands
## within REACH of it) brings the find up on the dig's second bite: it
## rises out of the scoop (scripts/buried_find.gd, bare), a beat of dust,
## the plane arc's found chime; it hangs a beat, then he takes it (the
## collectibles readout's blip and count). A dug spot stays dug (its tell
## gone) for the rest of the deal; `re_deal` re-buries every spot and deals
## its finds afresh from the deal's seed.
##
## Each spot is a named token (scripts/layout_overrides.gd)
## `wreck_cluster/dig_spot_NN` (NN from 01 in SPOTS order), so the world
## view (F4) moves it; the tell settles onto whatever ground is under it.
##
## Finds are collectibles the game has (GlyphPickup glyphs: the rune token
## and a few others), not a currency of their own; a later task deals some
## plane parts into the spots that sit by a soil part spot (`part`).
const GlyphPickup = preload("res://scripts/glyph_pickup.gd")
const BuriedFind = preload("res://scripts/buried_find.gd")
const LayoutOverrides = preload("res://scripts/layout_overrides.gd")
const Hud = preload("res://scripts/collectibles_hud.gd")
const DigFx = preload("res://scripts/dig/dig_fx.gd")

## [where, coded point (on the ground), tell, the part spot it sits by
## (studies/wreck_cluster_art.gd spots() index) or -1]. Kept out of the
## strip's open middle: nooks exploring takes you to.
const SPOTS := [
	["under the coast rock's arch",Vector3(185.0,46.0,-19.0),"ring",12],
	["the coast rock's east tip",Vector3(194.0,46.0,-17.5),"marker",-1],
	["under the rope rock's chapel arch",Vector3(85.5,46.5,-63.7),"strap",13],
	["the rope rock's south rim, where the rope chain lands",Vector3(86.5,46.5,-56.5),"bare",-1],
	["by the carved chest under the tilt rock's lancet wall",Vector3(52.5,35.8,-51.4),"mound",14],
	["the tilt rock's low east end",Vector3(64.0,34.8,-54.0),"line",-1],
	["the tower's foot, under the belfry's north face",Vector3(140.0,30.4,-35.8),"corner",8],
	["the tail lobe's tip, where the tail fell",Vector3(158.5,30.4,-7.5),"mound",7],
	["the strip's lobe by the footbridge's foot",Vector3(118.5,31.0,9.0),"marker",9],
	["the strip's west end by the causeway's root",Vector3(26.0,31.0,18.0),"line",-1],
	["the tower rock's west rim, looking back down the spine",Vector3(148.5,30.4,-13.0),"bare",-1],
	["the bench's east end, under the crest",Vector3(132.0,31.8,-2.0),"ring",-1],
]
## What the deal buries (GlyphPickup glyphs), drawn per spot.
const FINDS := ["rune","rune","rune","crystal","moon","feather"]
## A bite within this of a spot (m, flat, times his size) digs it up.
const REACH := 1.0
const LEVEL := 1.2
## The find: its size, how high it hovers over the turf once up, the beat
## it hangs there before he takes it (s).
const SIZE := 0.7
const HOVER := 0.95
const HANG := 0.45
const TELL_SEED := 801

var host: Node3D = null
var fx: Node3D = null
var size := 1.0
## {name, where, tell, part, node, tell_node, state ("buried", "rising",
## "taken"), glyph, find, dig, up_t}.
var spots: Array[Dictionary] = []
var hud: CanvasLayer = null
var _own_hud := false
## Finds taken this deal.
var taken := 0
var _seed := 0

static func spot_name(i: int) -> String:
	return "wreck_cluster/dig_spot_%02d" % (i+1)

func setup(scene: Node3D, dig_fx: Node3D, s: float) -> void:
	host = scene
	fx = dig_fx
	size = s
	name = "DigSpots"
	top_level = true
	for i in range(SPOTS.size()):
		var row: Array = SPOTS[i]
		var key := spot_name(i)
		if LayoutOverrides.deleted(key): continue
		var node := Node3D.new()
		node.name = "DigSpot_%02d" % (i+1)
		var coded := Transform3D(Basis(Vector3.UP,float(i)*1.7),row[1])
		add_child(node)
		node.global_transform = LayoutOverrides.xform(key,coded)
		LayoutOverrides.track(key,node,"token",coded)
		var tell := MeshInstance3D.new()
		tell.name = "Tell"
		tell.mesh = tell_mesh(str(row[2]),TELL_SEED+i)
		tell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if str(row[2]) in ["bare","mound"] else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		node.add_child(tell)
		spots.append({"name":key,"where":row[0],"tell":row[2],"part":row[3],"node":node,"tell_node":tell,
			"state":"buried","glyph":"","find":null,"dig":null,"up_t":0.0})
	settle()
	re_deal(int(host.get("deal_seed")) if host.get("deal_seed") != null else 0)

## Each tell onto the ground under its spot (the ground's normal leans it).
func settle() -> void:
	for sp: Dictionary in spots:
		var node: Node3D = sp.node
		var g := _ground(node.global_position)
		var tell: Node3D = sp.tell_node
		if g.is_empty():
			tell.position = Vector3.ZERO
			continue
		var n: Vector3 = (g.normal as Vector3).normalized()
		var x := node.global_basis.x.slide(n).normalized()
		var z := x.cross(n).normalized()
		tell.global_transform = Transform3D(Basis(x,n,z).scaled(Vector3.ONE*size),g.position)

func _ground(p: Vector3) -> Dictionary:
	if not is_inside_tree(): return {}
	var space := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(p+Vector3.UP*1.5,p+Vector3.DOWN*3.0,1|(1 << 11))
	return space.intersect_ray(ray)

## A fresh deal: every spot buried again under its tell, its find drawn
## from `seed_value`.
func re_deal(seed_value: int) -> void:
	_seed = seed_value
	taken = 0
	for i in range(spots.size()):
		var sp: Dictionary = spots[i]
		_drop_find(sp)
		sp.state = "buried"
		(sp.tell_node as Node3D).visible = true
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%d:%s" % [seed_value,sp.name])
		sp.glyph = FINDS[rng.randi()%FINDS.size()]
	settle()

func _drop_find(sp: Dictionary) -> void:
	for k: String in ["find","dig"]:
		var n: Variant = sp.get(k)
		if n != null and is_instance_valid(n): (n as Node).queue_free()
		sp[k] = null

## The buried spot a bite at `at` digs (within REACH flat, LEVEL up or
## down), else {}.
func near(at: Vector3) -> Dictionary:
	var best := {}
	var best_d := REACH*size
	for sp: Dictionary in spots:
		if sp.state != "buried": continue
		var p: Vector3 = (sp.tell_node as Node3D).global_position
		var d := Vector2(p.x-at.x,p.z-at.z).length()
		if d <= best_d and absf(p.y-at.y) <= LEVEL*size:
			best = sp
			best_d = d
	return best

## Spot `sp` dug open: the tell gone, the find coming up out of the scoop
## at `at` (the bite's ground point) with a beat of dust and the chime.
func reveal(sp: Dictionary, at: Vector3) -> void:
	if sp.is_empty() or sp.state != "buried": return
	sp.state = "rising"
	sp.up_t = 0.0
	(sp.tell_node as Node3D).visible = false
	var holder := GlyphPickup.make(str(sp.glyph),SIZE*size,randf()*TAU,true)
	holder.name = "Find_%s" % str(sp.name).get_file()
	add_child(holder)
	holder.visible = false
	if holder.has_method("motes_on"): holder.motes_on(true)
	var dig := BuriedFind.new()
	dig.bare = true
	dig.size = size
	dig.setup(holder,at,"",HOVER*size)
	dig.from = at+Vector3.DOWN*0.35*size
	add_child(dig)
	dig.reveal()
	sp.find = holder
	sp.dig = dig
	if fx != null and fx.has_method("dust"): fx.dust(at,7,0.32,0.9)
	var arc: Variant = host.get("plane_arc") if host != null else null
	if arc != null and arc.get("sounds") != null: arc.sounds.found(1)

## The grass and meadow flowers round each spot cut down (the flora's
## multimesh instances shrunk: to stubble round a tell, gone on a bare
## patch), so the tell shows and the dug hole reads. Tried once a second
## for the first CUT_TRIES s while the flora draws (reading a batch's
## buffer back waits on the GPU, so it stops after).
const CUT := 0.75
const CUT_BARE := 0.95
const STUBBLE := 0.3
const CUT_TRIES := 12
var _cut_wait := 0.0
var _cut_tries := 0

func cut_grass() -> int:
	var flora: Node = host.get_node_or_null("Art/Flora") if host != null else null
	if flora == null: return 0
	var cut := 0
	for m: Node in flora.get_children():
		var mmi := m as MultiMeshInstance3D
		if mmi == null or mmi.multimesh == null: continue
		var called := str(mmi.name)
		if not (called.begins_with("grass_tuft") or called.contains("meadow")): continue
		# KitFlora names each batch for its tile (`<part>_<x>_<z>`, TILE m):
		# only the batches a spot stands in are read back (a readback waits
		# on the GPU, so not all of them).
		var bits := called.rsplit("_",true,2)
		if bits.size() < 3: continue
		var tile := Vector2i(int(bits[1]),int(bits[2]))
		var near: Array = []
		for sp: Dictionary in spots:
			var p: Vector3 = (sp.tell_node as Node3D).global_position
			var r := (CUT_BARE if sp.tell == "bare" else CUT)*size
			var lo := Vector2i(floori((p.x-r)/KitFlora.TILE),floori((p.z-r)/KitFlora.TILE))
			var hi := Vector2i(floori((p.x+r)/KitFlora.TILE),floori((p.z+r)/KitFlora.TILE))
			if tile.x >= lo.x and tile.x <= hi.x and tile.y >= lo.y and tile.y <= hi.y: near.append([p,r,0.0 if sp.tell == "bare" else STUBBLE])
		if near.is_empty(): continue
		var mm := mmi.multimesh
		if mm.instance_count == 0: continue
		var stride := 12+(4 if mm.use_colors else 0)+(4 if mm.use_custom_data else 0)
		# The first tuft says whether this buffer is cut already (the flora
		# lays its buffers after making the batch, and may again).
		var buf := mm.buffer
		if buf.size() < mm.instance_count*stride: continue
		var mark := Vector3(buf[3],buf[7],buf[11])
		if mark == Vector3.ZERO: continue
		if mmi.has_meta("dig_cut") and (mmi.get_meta("dig_cut") as Vector3) == mark and buf[0] == float(mmi.get_meta("dig_cut0",buf[0])): continue
		var xf := mmi.global_transform
		var changed := false
		for k in range(mm.instance_count):
			var o := k*stride
			if o+11 >= buf.size(): break
			var w := xf*Vector3(buf[o+3],buf[o+7],buf[o+11])
			for n: Array in near:
				var p: Vector3 = n[0]
				var d := Vector2(w.x-p.x,w.z-p.z).length()
				if d > float(n[1]) or absf(w.y-p.y) > 1.0: continue
				# Stubble at the heart, rising back toward the edge.
				var keep := maxf(lerpf(float(n[2]),1.0,smoothstep(0.55,1.0,d/float(n[1]))),0.001)
				for j: int in [0,1,2,4,5,6,8,9,10]: buf[o+j] *= keep
				changed = true
				cut += 1
				break
		if changed: mm.buffer = buf
		mmi.set_meta("dig_cut",mark)
		mmi.set_meta("dig_cut0",buf[0])
	return cut

func _process(delta: float) -> void:
	_cut_wait -= delta
	if _cut_wait <= 0.0 and _cut_tries < CUT_TRIES:
		_cut_wait = 1.0
		_cut_tries += 1
		var began := Time.get_ticks_msec()
		var n := cut_grass()
		if n > 0: print("dig spots: %d grass and flowers cut round the spots in %d ms" % [n,Time.get_ticks_msec()-began])
	for sp: Dictionary in spots:
		if sp.state != "rising": continue
		var dig: Node3D = sp.dig
		if dig == null or not is_instance_valid(dig) or not dig.takeable(): continue
		sp.up_t = float(sp.up_t)+delta
		if float(sp.up_t) >= HANG: take(sp)

## The find taken: it twists away, the readout counts it.
func take(sp: Dictionary) -> void:
	if sp.state != "rising": return
	sp.state = "taken"
	taken += 1
	var holder: Node3D = sp.find
	if holder != null and is_instance_valid(holder): holder.take(hash(str(sp.name)) & 0xffff,self)
	sp.find = null
	_readout().show_pickup(str(sp.glyph),taken,taken,spots.size())

## The collectibles readout: the sky's (or the isle life's) if there is
## one, else one of its own.
func _readout() -> CanvasLayer:
	if hud != null and is_instance_valid(hud): return hud
	var sky: Variant = host.get("sky") if host != null else null
	var col: Variant = (sky as Object).get("collectibles") if sky != null else null
	if col != null and (col as Object).get("hud") != null: hud = col.hud
	if hud == null:
		var life: Variant = host.get("life") if host != null else null
		var tokens: Variant = (life as Object).get("tokens") if life != null else null
		if tokens != null and (tokens as Object).get("hud") != null: hud = tokens.hud
	if hud == null:
		hud = Hud.new()
		add_child(hud)
		_own_hud = true
	return hud

func dug_count() -> int:
	return spots.filter(func(sp: Dictionary) -> bool: return sp.state != "buried").size()

# --- The tells ------------------------------------------------------------------------

const EARTH := Color(0.44,0.31,0.17)
const EARTH_TURNED := Color(0.52,0.37,0.21)
const DRY := Color(0.56,0.47,0.33)
const STONE_A := Color(0.58,0.56,0.52)
const STONE_B := Color(0.47,0.46,0.43)
const MOSS := Color(0.36,0.42,0.24)
const STRAW := Color(0.66,0.58,0.36)
const STRAW_DARK := Color(0.48,0.40,0.24)
const LEATHER := Color(0.33,0.19,0.10)
const BRASS := Color(0.62,0.50,0.26)
const WOOD := Color(0.42,0.30,0.18)
const WOOD_DARK := Color(0.27,0.19,0.11)

## Tell `kind`'s mesh, its own frame (y up from the ground's point, at
## size 1), seeded.
static func tell_mesh(kind: String, seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match kind:
		"mound":
			# A low hump of turned earth, a few clods on it, sunk at its edge.
			DigFx._lump(st,Vector3.ZERO,0.62,0.16,rng,EARTH)
			for i in range(7):
				var a := TAU*i/7.0+rng.randf()*0.5
				var r := rng.randf_range(0.15,0.5)
				DigFx._lump(st,Vector3(cos(a)*r,0.16*(1.0-r/0.62)-0.02,sin(a)*r),rng.randf_range(0.06,0.11),rng.randf_range(0.05,0.09),rng,EARTH_TURNED.lerp(EARTH,rng.randf()))
		"ring":
			# Small stones set in a ring, a few sunk or missing.
			var n := 9
			for i in range(n):
				if rng.randf() < 0.15: continue
				var a := TAU*i/n+rng.randf_range(-0.12,0.12)
				_stone(st,Vector3(cos(a),0.0,sin(a))*0.5,Vector3(0.09,0.08,0.07)*rng.randf_range(0.8,1.25),a,rng)
		"line":
			# A short row of stones set end to end, leading nowhere.
			for i in range(5):
				var x := -0.6+0.3*i+rng.randf_range(-0.04,0.04)
				_stone(st,Vector3(x,0.0,rng.randf_range(-0.05,0.05)),Vector3(0.11,0.09,0.08)*rng.randf_range(0.85,1.2),rng.randf_range(-0.3,0.3),rng)
		"marker":
			# A lone standing stone, leaning, mossy at its foot, a few pebbles.
			var b := Basis(Vector3.FORWARD,deg_to_rad(rng.randf_range(14.0,22.0)))*Basis(Vector3.UP,rng.randf()*TAU)
			_block(st,Transform3D(b,Vector3.ZERO),Vector3(0.13,0.62,0.09),STONE_A,STONE_B,rng,0.03)
			DigFx._lump(st,Vector3.ZERO,0.2,0.07,rng,MOSS)
			for i in range(3):
				var a := rng.randf()*TAU
				_stone(st,Vector3(cos(a),0.0,sin(a))*rng.randf_range(0.28,0.45),Vector3(0.05,0.04,0.04),a,rng)
		"bare":
			# A patch where the grass won't grow: dead straw lying flat in a
			# rough ring, a dark heart, a pebble or two.
			DigFx._lump(st,Vector3.ZERO,0.42,0.04,rng,DRY)
			for i in range(16):
				var a := rng.randf()*TAU
				var r := rng.randf_range(0.18,0.55)
				var at := Vector3(cos(a),0.0,sin(a))*r
				var lay := a+PI*0.5+rng.randf_range(-0.6,0.6)
				_stalk(st,at,lay,rng.randf_range(0.18,0.32),STRAW.lerp(STRAW_DARK,rng.randf()))
			for i in range(2):
				var a := rng.randf()*TAU
				_stone(st,Vector3(cos(a),0.0,sin(a))*0.2,Vector3(0.05,0.04,0.04),a,rng)
		"strap":
			# A leather strap's loop poking out of the turf, a brass buckle on
			# it, a little turned earth where it comes up.
			var loop: Array = []
			for i in range(9):
				var t := float(i)/8.0
				loop.append(Vector3(lerpf(-0.18,0.18,t),sin(t*PI)*0.2-0.04,sin(t*PI)*0.04))
			for i in range(8):
				var a: Vector3 = loop[i]
				var c: Vector3 = loop[i+1]
				_band(st,a,c,0.06,0.012,LEATHER)
			_block(st,Transform3D(Basis(Vector3.BACK,0.5),loop[3]+Vector3(0.0,0.0,0.01)),Vector3(0.05,0.035,0.03),BRASS,BRASS.darkened(0.3),rng,0.0)
			for x: float in [-0.19,0.19]:
				DigFx._lump(st,Vector3(x,0.0,0.0),0.08,0.04,rng,EARTH_TURNED)
		"corner":
			# A box's corner poking up out of the ground, tipped, one board
			# split, turned earth round it.
			var b := Basis(Vector3(1,0,1).normalized(),deg_to_rad(38.0))*Basis(Vector3.UP,deg_to_rad(20.0))
			_block(st,Transform3D(b,Vector3(0.0,-0.12,0.0)),Vector3(0.24,0.2,0.2),WOOD,WOOD_DARK,rng,0.0)
			_block(st,Transform3D(b,Vector3(0.0,-0.12,0.0))*Transform3D(Basis.IDENTITY,Vector3(0.0,0.2,0.0)),Vector3(0.25,0.018,0.21),BRASS.darkened(0.35),BRASS.darkened(0.55),rng,0.0)
			for i in range(5):
				var a := TAU*i/5.0+rng.randf()*0.5
				DigFx._lump(st,Vector3(cos(a),0.0,sin(a))*0.26,0.09,0.05,rng,EARTH_TURNED.lerp(EARTH,rng.randf()))
	st.generate_normals()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(m)
	return st.commit()

## A small stone half sunk: a squashed box, its corners jittered.
static func _stone(st: SurfaceTool, at: Vector3, half: Vector3, yaw: float, rng: RandomNumberGenerator) -> void:
	var b := Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,rng.randf_range(-0.2,0.2))
	_block(st,Transform3D(b,at+Vector3(0.0,half.y*0.25,0.0)),half,STONE_A.lerp(STONE_B,rng.randf()),STONE_B.darkened(0.15),rng,0.25)

## A box (half extents `half`) at `xf`, its corners jittered by `jag` of
## their size; `top` on its upward faces, `side` on the rest.
static func _block(st: SurfaceTool, xf: Transform3D, half: Vector3, top: Color, side: Color, rng: RandomNumberGenerator, jag: float) -> void:
	var c := []
	for i in range(8):
		var v := Vector3(half.x*(1 if i&1 else -1),half.y*(1 if i&2 else -1),half.z*(1 if i&4 else -1))
		v += Vector3(rng.randf_range(-1,1)*half.x,rng.randf_range(-1,1)*half.y,rng.randf_range(-1,1)*half.z)*jag
		c.append(xf*v)
	var faces := [[0,1,3,2],[4,6,7,5],[0,4,5,1],[2,3,7,6],[0,2,6,4],[1,5,7,3]]
	for f: Array in faces:
		var a: Vector3 = c[f[0]]
		var b: Vector3 = c[f[1]]
		var d: Vector3 = c[f[2]]
		var e: Vector3 = c[f[3]]
		var out := ((a+b+d+e)*0.25-xf.origin).normalized()
		_quad(st,a,b,d,e,xf.origin,top if out.y > 0.6 else side)

## A quad a-b-d-e wound to face away from `centre` (DigFx's winding: its
## (b-a)x(c-a) points into the solid).
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, d: Vector3, e: Vector3, centre: Vector3, col: Color) -> void:
	var mid := (a+b+d+e)*0.25
	if (b-a).cross(d-a).dot(mid-centre) > 0.0:
		var t := b
		b = e
		e = t
	DigFx._tri(st,a,b,d,col)
	DigFx._tri(st,a,d,e,col)

## A dead stalk lying on the ground: a thin flat sliver `length` long.
static func _stalk(st: SurfaceTool, at: Vector3, yaw: float, length: float, col: Color) -> void:
	var way := Vector3(cos(yaw),0.0,sin(yaw))
	var side := Vector3(-way.z,0.0,way.x)*0.012
	var a := at-way*length*0.5+Vector3.UP*0.02
	var b := at+way*length*0.5+Vector3.UP*0.05
	DigFx._tri(st,a-side,b,a+side,col)

## A flat band from `a` to `b`, `w` wide (across, in z) and `t` thick.
static func _band(st: SurfaceTool, a: Vector3, b: Vector3, w: float, t: float, col: Color) -> void:
	var side := Vector3(0.0,0.0,w*0.5)
	var up := (b-a).cross(side).normalized()*t*0.5
	var q := [a-side+up,b-side+up,b+side+up,a+side+up,a-side-up,b-side-up,b+side-up,a+side-up]
	for f: Array in [[0,1,2,3],[7,6,5,4],[0,4,5,1],[3,2,6,7]]:
		_quad(st,q[f[0]],q[f[1]],q[f[2]],q[f[3]],(a+b)*0.5,col)
