extends RefCounted
## The home isle (docs/design/home/spec-home.md): the haul's end, west of
## the stretch's last rocks (studies/wreck_cluster_stretch.gd, its line
## ends near x -700 on z 16). Built in the wreck cluster study with --home,
## which starts you there on foot beside the working plane.
##
## A compact landform, not a disc: a long low tongue the strip runs along
## (z STRIP_Z, from the east rim at x STRIP_EAST west to STRIP_WEST), so the
## flight home off the stretch ends in a straight-in approach heading -x;
## north of the strip a shelf for the vault (spec task 2) under a grassy
## bluff at the west end; south of it a broad flat for the drop field (task
## 4), its rim rising into a low hummock at the south-west. The plane parks
## at the strip's west end facing east, down the strip toward the stretch.
##
## World-view names: the island `island/home`, its pieces `home/<piece>`
## (studies/wreck_cluster.gd `_place_piece` with the "home/" root).

const RuinKit = preload("res://scripts/ruin_kit.gd")

## The turf's base height (the stretch's islets stand at 20 and 22, its
## line at 34-36): the approach comes down some 10 m over the last 60 m of
## open sky past rocks_e.
const TOP := 26.0
## The strip: a clear run along z STRIP_Z from STRIP_EAST to STRIP_WEST
## (165 m), STRIP_HALF either side kept flat and clear.
const STRIP_Z := 16.0
const STRIP_HALF := 7.0
const STRIP_EAST := -762.0
const STRIP_WEST := -927.0
## The parked plane: near the strip's west end, facing east (heading -PI/2:
## forward (-sin h, 0, -cos h) = +x), so its take-off runs the strip's
## length toward the stretch.
const PLANE_AT := Vector2(-912.0,STRIP_Z)
const PLANE_HEADING := -PI*0.5
## The vault's shelf north of the strip (task 2) and the drop field south
## of it (task 4): their middles, kept flat.
const VAULT_AT := Vector2(-880.0,31.0)
const FIELD_AT := Vector2(-850.0,-2.0)
## The deposit pad on the strip's north edge before the vault: its middle
## and half extents (x along the strip, z across). A plane stopped with its
## middle over it (PAD_SLACK past its rim) unloads.
const PAD_AT := Vector2(-880.0,20.5)
const PAD_HALF := Vector2(8.0,4.0)
const PAD_SLACK := 1.0
## The vault: three walls round a slab floor, its open side south toward
## the pad; inside (vault-local, its floor's middle at the origin) the
## INSIDE half extents bank a treasure carried in; banked ones stand on
## SHOW, in rows on the floor. The board stands outside by its door.
const VAULT_YAW := 0.0
const INSIDE := Vector2(2.5,2.6)
const BOARD_AT := Vector3(5.4,0.0,-3.6)
const FIELD_HALF := Vector2(26.0,8.0)

## The outline (x, z), wound as the cluster's lands (east along the south
## rim, back along the north): a narrow tongue in the east under the
## approach, widening west into the field (south) and the vault's shelf and
## bluff (north).
static func outline() -> Array:
	return [Vector2(-944.0,14.0),Vector2(-940.0,2.0),Vector2(-930.0,-8.0),Vector2(-912.0,-14.5),
		Vector2(-884.0,-15.5),Vector2(-852.0,-14.5),Vector2(-826.0,-12.0),Vector2(-812.0,-4.0),
		Vector2(-800.0,4.5),Vector2(-784.0,7.0),Vector2(-766.0,7.5),Vector2(-756.0,11.0),
		Vector2(-754.0,17.0),Vector2(-758.0,23.0),Vector2(-772.0,25.5),Vector2(-800.0,27.0),
		Vector2(-826.0,34.0),Vector2(-846.0,42.0),Vector2(-872.0,46.0),Vector2(-900.0,47.0),
		Vector2(-924.0,43.5),Vector2(-938.0,35.0),Vector2(-944.0,25.0)]

## The turf's height at (x, z): TOP on the strip, the field and the vault's
## shelf; a bluff rising some 11 m at the north-west, a hummock some 6.5 m
## at the south-west rim, a swell on the north rim and a low knoll on the
## tongue's south rim (so the top line is not flat from a low angle), each
## eased in so the slopes stay walkable.
static func ground(x: float, z: float) -> float:
	var h := TOP
	h += 11.0*_mound(x,z,Vector2(-926.0,43.0),Vector2(30.0,18.0))
	h += 6.5*_mound(x,z,Vector2(-932.0,-9.0),Vector2(20.0,14.0))
	h += 4.0*_mound(x,z,Vector2(-846.0,46.0),Vector2(22.0,9.0))
	h += 3.0*_mound(x,z,Vector2(-800.0,-2.0),Vector2(14.0,7.0))
	# The strip's band, the field and the vault's shelf held flat.
	var keep := maxf(_flat(absf(z-STRIP_Z),STRIP_HALF,4.0),_flat(_box(x,z,FIELD_AT,FIELD_HALF),0.0,4.0))
	keep = maxf(keep,_flat(_box(x,z,VAULT_AT,Vector2(12.0,6.0)),0.0,4.0))
	return lerpf(h,TOP,keep)

## A smooth mound: 1 at `at`, easing to 0 at `half` (x, z) away.
static func _mound(x: float, z: float, at: Vector2, half: Vector2) -> float:
	var d := Vector2((x-at.x)/half.x,(z-at.y)/half.y).length()
	return 1.0-smoothstep(0.0,1.0,d)

## How far (m) (x, z) lies outside the box at `at` with half extents `half`.
static func _box(x: float, z: float, at: Vector2, half: Vector2) -> float:
	return Vector2(maxf(absf(x-at.x)-half.x,0.0),maxf(absf(z-at.y)-half.y,0.0)).length()

## 1 within `inner` of the kept place, easing to 0 `ease` m further out.
static func _flat(d: float, inner: float, ease: float) -> float:
	return 1.0-smoothstep(inner,inner+ease,d)

## The worn ground (KitFlora Site `wear`, 0..1 at world (x, z)): the
## deposit pad, the vault's floor and the drop field kept bare of grass,
## easing out a metre.
static func wear(p: Vector2) -> float:
	var on_pad := _box(p.x,p.y,PAD_AT,PAD_HALF+Vector2(0.4,0.4))
	var in_vault := _box(p.x,p.y,VAULT_AT,INSIDE+Vector2(0.6,0.6))
	var on_field := _box(p.x,p.y,FIELD_AT,FIELD_HALF+Vector2(0.6,0.6))
	return 1.0-smoothstep(0.0,1.2,minf(minf(on_pad,in_vault),on_field))

## The isle as a row of the cluster's lands (studies/wreck_cluster_art.gd
## `lands`: name, outline, ground, depth, seed, cliffs, rim).
static func land() -> Array:
	return ["home",outline(),ground,80.0,467,Rect2(),TOP]

## The home isle and its two stacks (studies/wreck_cluster.gd builds them
## with the stretch's lands): the isle, a tall stack off its south-east rim
## south of the approach, a lower one off the bluff's north side. Each
## stack is a small round islet hung on a deep column, as the cluster's
## tower rock and its outliers stand, so the isle reads as a cluster from
## afar and from the approach, not one slab.
const SPIRE_S := Vector3(-806.0,33.0,-30.0)
const SPIRE_N := Vector3(-902.0,41.0,66.0)
static func lands() -> Array:
	return [land(),
		["home_spire_s",_round(Vector2(SPIRE_S.x,SPIRE_S.z),6.5,471),_level(SPIRE_S.y),64.0,471,Rect2(),SPIRE_S.y],
		["home_spire_n",_round(Vector2(SPIRE_N.x,SPIRE_N.z),5.5,473),_level(SPIRE_N.y),48.0,473,Rect2(),SPIRE_N.y]]

static func _level(y: float) -> Callable:
	return func(_x: float, _z: float) -> float: return y

## A rough round outline (wound as the lands are) of radius `r` at `at`.
static func _round(at: Vector2, r: float, seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out: Array = []
	for i in 10:
		var a := -TAU*float(i)/10.0
		out.append(at+Vector2(cos(a),sin(a))*r*rng.randf_range(0.85,1.12))
	return out

## The rock each hangs (studies/wreck_cluster_art.gd `hangs`). The isle: a
## sheer band under its rim, then stepping in twice in overhangs (as the
## rope rock's tiers) down to seven fangs, the deepest some 80 m under the
## turf, leaning a little east toward the approach. The stacks: columns
## near-vertical most of their drop, a single fang.
const HANGS := {
	"home":{"rings":[[5.0,0.97],[12.0,0.95],[14.0,0.84],[24.0,0.8],[27.0,0.64],[37.0,0.56],[44.0,0.4]],
		"fangs":[58.0,76.0,50.0,68.0,56.0,80.0,52.0],"spread":0.72,"lean":Vector2(6.0,1.0)},
	"home_spire_s":{"rings":[[6.0,0.95],[20.0,0.88],[34.0,0.8],[46.0,0.66]],"fangs":[64.0],"lean":Vector2(-2.0,1.0)},
	"home_spire_n":{"rings":[[5.0,0.94],[16.0,0.86],[28.0,0.74],[36.0,0.6]],"fangs":[48.0],"lean":Vector2(2.0,-2.0)},
}

## A land of `lands` built as the stretch's islets are (KitLand turf, its
## own hanging rock, sides collided as drawn). World-view islands
## `island/home`, `island/home_spire_s`, `island/home_spire_n`.
static func build_land(spec: Array) -> Node3D:
	var Art: GDScript = load("res://studies/wreck_cluster_art.gd")
	var called := str(spec[0])
	var d := {"outline":spec[1],"seed":int(spec[4]),"ground":spec[2],"top":float(spec[6]),
		"depth":float(spec[3]),"hang":true,"resample":[60.0,128,48],"tone":KitLook.turf(467),"cell":2.0,
		"collide_sides":true,"sides":false,"name":called}
	var node := KitLand.island(d)
	node.name = "Land_"+called.to_pascal_case()
	var hang: Dictionary = HANGS[called]
	var rings: Array = Art.hang_rings(d,hang)
	var drawn: MeshInstance3D = Art.hang_rock(rings,hang,int(spec[4])).node("Mesh")
	node.add_child(drawn)
	KitLand.collide_sides(node,drawn,true)
	return node

## The pieces: [layout name (under home/), node, world foot, yaw (deg)]:
## a few ruins on the rims, off the strip's band, so the isle reads as an
## old place from the approach; the vault on its shelf; the deposit pad;
## the drop field on the south flat.
static func built() -> Array:
	return [
		["vault",vault(),Vector3(VAULT_AT.x,TOP,VAULT_AT.y),rad_to_deg(VAULT_YAW)],
		["deposit_pad",pad(),Vector3(PAD_AT.x,TOP,PAD_AT.y),0.0],
		["drop_field",field(),Vector3(FIELD_AT.x,TOP,FIELD_AT.y),0.0],
		["rim_pier",RuinKit.piece("pier",561,0.45),Vector3(-780.0,TOP,25.0),15.0],
		["rim_fallen",RuinKit.piece("fallen_pier",562,0.45),Vector3(-822.0,TOP,-9.0),70.0],
		["bluff_arch",RuinKit.piece("arch",563,0.4),Vector3(-922.0,ground(-922.0,41.0),41.0),100.0],
		["spire_s_arch",RuinKit.piece("arch",564,0.35),Vector3(SPIRE_S.x,SPIRE_S.y,SPIRE_S.z),20.0],
		["spire_n_pier",RuinKit.piece("pier",565,0.5),Vector3(SPIRE_N.x+1.0,SPIRE_N.y,SPIRE_N.z),35.0],
	]

## The vault (one piece for the world view, `home/vault`): RuinKit walls on
## three sides (back to the north), piers framing the open south side, a
## slab floor, and the tally board outside by its door (a stone slab on two
## legs, its face south; `Board/Text` is its Label3D). Banked treasures
## stand on `Show` (scripts/home/vault_host.gd).
static func vault() -> Node3D:
	var root := Node3D.new()
	root.name = "Vault"
	var t := RuinKit.WALL_THICK*0.5
	var side := INSIDE.x+0.1+t
	var parts := [
		[RuinKit.piece("floor",571,0.1),Vector3(0.0,0.0,0.3),0.0],
		[RuinKit.piece("wall",572,0.35),Vector3(0.0,0.0,INSIDE.y+t),0.0],
		[RuinKit.piece("wall",573,0.3),Vector3(-side,0.0,0.0),90.0],
		[RuinKit.piece("wall",574,0.3),Vector3(side,0.0,0.0),-90.0],
		[RuinKit.piece("pier",575,0.2),Vector3(-side,0.0,INSIDE.y+t),0.0],
		[RuinKit.piece("pier",576,0.2),Vector3(side,0.0,INSIDE.y+t),0.0],
		[RuinKit.piece("pier",577,0.15),Vector3(-side,0.0,-INSIDE.y-0.3),0.0],
		[RuinKit.piece("pier",578,0.15),Vector3(side,0.0,-INSIDE.y-0.3),0.0],
		# Buttresses shoulder the side walls and the back from outside, so
		# the store reads as built to hold, not three plain slabs.
		[RuinKit.piece("buttress",579,0.25),Vector3(-side-t,0.0,0.0),90.0],
		[RuinKit.piece("buttress",580,0.25),Vector3(side+t,0.0,0.0),-90.0],
		[RuinKit.piece("buttress",581,0.25),Vector3(0.0,0.0,INSIDE.y+t*2.0),0.0],
	]
	for p: Array in parts:
		var n: Node3D = p[0]
		n.position = p[1]
		n.rotation.y = deg_to_rad(float(p[2]))
		root.add_child(n)
	var shelf := Node3D.new()
	shelf.name = "Show"
	root.add_child(shelf)
	root.add_child(board())
	return root

## The tally board: a slate face in a stone frame on two legs, a cap
## stone over it, its text (sized to sit inside the frame) on the face.
static func board() -> Node3D:
	var b := Node3D.new()
	b.name = "Board"
	b.position = BOARD_AT
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("8a8372")
	stone.roughness = 0.95
	var face := StandardMaterial3D.new()
	face.albedo_color = Color("4d4a43")
	face.roughness = 0.85
	var box := func(size: Vector3, at: Vector3, m: Material, nm := "") -> MeshInstance3D:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		mi.mesh = bm
		mi.material_override = m
		mi.position = at
		if nm != "": mi.name = nm
		b.add_child(mi)
		return mi
	for x: float in [-1.65,1.65]:
		box.call(Vector3(0.4,3.3,0.4),Vector3(x,1.65,0.0),stone)
		box.call(Vector3(0.6,0.25,0.6),Vector3(x,0.12,0.0),stone)
	box.call(Vector3(2.9,1.6,0.22),Vector3(0.0,2.35,0.0),face,"Slab")
	# The frame's rails and the cap stone, a little proud of the face.
	box.call(Vector3(3.3,0.22,0.36),Vector3(0.0,1.48,0.0),stone)
	box.call(Vector3(3.9,0.3,0.55),Vector3(0.0,3.36,0.0),stone)
	box.call(Vector3(3.4,0.12,0.42),Vector3(0.0,3.17,0.0),stone)
	var text := Label3D.new()
	text.name = "Text"
	text.font_size = 64
	text.pixel_size = 0.003
	text.outline_size = 8
	text.modulate = Color("efe2bd")
	text.outline_modulate = Color(0.1,0.08,0.05,1.0)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.line_spacing = 6.0
	text.position = Vector3(0.0,2.35,-0.12)
	text.rotation.y = PI
	text.double_sided = false
	b.add_child(text)
	return b

## The deposit pad marked on the turf (drawn only; the plane rolls on the
## turf under it): a pale sand bed in a kerb of dark stones, a band of
## darker sand across it and a chevron at each end pointing in.
static func pad() -> Node3D:
	var root := Node3D.new()
	root.name = "DepositPad"
	var sand := StandardMaterial3D.new()
	sand.albedo_color = Color("c9b48a")
	sand.roughness = 1.0
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("8d7a58")
	dark.roughness = 1.0
	var kerb := StandardMaterial3D.new()
	kerb.albedo_color = Color("5d5a52")
	kerb.roughness = 0.95
	var box := func(size: Vector3, at: Vector3, mat: Material, yaw := 0.0) -> void:
		var m := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		m.mesh = bm
		m.material_override = mat
		m.position = at
		m.rotation.y = yaw
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(m)
	var h := PAD_HALF
	box.call(Vector3(h.x*2.0,0.06,h.y*2.0),Vector3(0.0,0.03,0.0),sand)
	box.call(Vector3(1.2,0.065,h.y*2.0-0.6),Vector3(0.0,0.035,0.0),dark)
	# The kerb: stones along each side, a little uneven.
	var rng := RandomNumberGenerator.new()
	rng.seed = 581
	for side: int in 4:
		var along := h.x if side < 2 else h.y
		var across := h.y if side < 2 else h.x
		var sgn := 1.0 if side%2 == 0 else -1.0
		var x := -along
		while x < along:
			var run := minf(rng.randf_range(0.7,1.2),along-x)
			var mid := x+run*0.5
			var at := Vector3(mid,0.06,sgn*across) if side < 2 else Vector3(sgn*across,0.06,mid)
			var size := Vector3(run-0.08,rng.randf_range(0.08,0.14),0.45) if side < 2 else Vector3(0.45,rng.randf_range(0.08,0.14),run-0.08)
			box.call(size,at,kerb)
			x += run
	# Chevrons at each end, pointing in along the strip: the field's
	# pennant red, wide and raised a little, so they read from the air.
	var mark := StandardMaterial3D.new()
	mark.albedo_color = Color("a8432c")
	mark.roughness = 1.0
	for sgn: float in [-1.0,1.0]:
		for row: float in [0.0,1.6]:
			for k: float in [-1.0,1.0]:
				box.call(Vector3(0.7,0.09,2.6),Vector3(sgn*(h.x-1.5-row),0.05,k*0.95),mark,k*sgn*0.65)
	return root

## The drop field (`home/drop_field`, drawn only: treasures land on the
## turf under it; scripts/home/drop_pass.gd judges them by its box,
## FIELD_HALF about its middle): a bed of pale sand, mats of straw strewn
## over it, two rope nets pegged out on the straw, a kerb of dark stones,
## and a tall post with a pennant at each corner so it reads from the air.
static func field() -> Node3D:
	var root := Node3D.new()
	root.name = "DropField"
	var mat := func(c: String) -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(c)
		m.roughness = 1.0
		return m
	var sand: StandardMaterial3D = mat.call("cdb88c")
	var straw: StandardMaterial3D = mat.call("c9a75a")
	var straw_dark: StandardMaterial3D = mat.call("9f7d3c")
	# Straw's grain: a streaked noise, stretched one way, laid on
	# triplanar so heaps, mats and bales all read as stalks, not paint.
	var grain := FastNoiseLite.new()
	grain.frequency = 0.09
	grain.seed = 593
	var streak := NoiseTexture2D.new()
	streak.width = 128
	streak.height = 128
	streak.seamless = true
	streak.noise = grain
	var ramp := Gradient.new()
	ramp.set_color(0,Color(0.62,0.58,0.5))
	ramp.set_color(1,Color(1.12,1.08,0.98))
	streak.color_ramp = ramp
	for m: StandardMaterial3D in [straw,straw_dark]:
		m.albedo_texture = streak
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(5.0,0.6,0.6)
	var rope: StandardMaterial3D = mat.call("6e5233")
	var kerb: StandardMaterial3D = mat.call("5d5a52")
	var post: StandardMaterial3D = mat.call("5a4630")
	var cloth: StandardMaterial3D = mat.call("b0472f")
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	var box := func(size: Vector3, at: Vector3, m: Material, yaw := 0.0, shadow := false) -> void:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		mi.mesh = bm
		mi.material_override = m
		mi.position = at
		mi.rotation.y = yaw
		if not shadow: mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	var h := FIELD_HALF
	var rng := RandomNumberGenerator.new()
	rng.seed = 591
	box.call(Vector3(h.x*2.0,0.06,h.y*2.0),Vector3(0.0,0.03,0.0),sand)
	# Straw: a thin strewn bed (a few flat mats for colour), low heaps
	# that give it body, tufts sticking up all over so it reads as straw
	# up close, and bales stacked along the long sides.
	for i in 30:
		var at := Vector3(rng.randf_range(-h.x+1.5,h.x-1.5),0.07+0.004*float(i%5),rng.randf_range(-h.y+1.2,h.y-1.2))
		var size := Vector3(rng.randf_range(2.0,4.2),0.04,rng.randf_range(1.2,2.6))
		box.call(size,at,straw if rng.randf() < 0.6 else straw_dark,rng.randf_range(-0.6,0.6))
	var heap := SphereMesh.new()
	heap.radius = 1.0
	heap.height = 2.0
	heap.radial_segments = 10
	heap.rings = 5
	var heaps: Array[Vector3] = []
	for i in 60:
		var mi := MeshInstance3D.new()
		mi.mesh = heap
		mi.material_override = straw if rng.randf() < 0.65 else straw_dark
		var r := rng.randf_range(0.7,1.5)
		mi.scale = Vector3(r*rng.randf_range(1.0,1.5),rng.randf_range(0.35,0.6),r)
		mi.position = Vector3(rng.randf_range(-h.x+2.0,h.x-2.0),0.0,rng.randf_range(-h.y+1.6,h.y-1.6))
		mi.rotation.y = rng.randf_range(0.0,TAU)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		heaps.append(Vector3(mi.position.x,mi.scale.y,mi.position.z))
	var tuft := BoxMesh.new()
	tuft.size = Vector3(0.05,0.45,0.012)
	var tuft_mat := StandardMaterial3D.new()
	tuft_mat.vertex_color_use_as_albedo = true
	tuft_mat.roughness = 1.0
	tuft_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = tuft
	mm.instance_count = 2200
	var light := Color("e2c26a")
	var deep := Color("a8823a")
	for i in mm.instance_count:
		var basis := Basis(Vector3.UP,rng.randf_range(0.0,TAU))*Basis(Vector3.RIGHT,rng.randf_range(-1.1,1.1))
		basis = basis.scaled(Vector3.ONE*rng.randf_range(0.6,1.3))
		var at := Vector3(rng.randf_range(-h.x+0.8,h.x-0.8),0.18,rng.randf_range(-h.y+0.8,h.y-0.8))
		if i%4 != 0:
			# Most stick out of the heaps' skirts and tops, in clumps.
			var hp: Vector3 = heaps[rng.randi()%heaps.size()]
			var off := Vector2.from_angle(rng.randf_range(0.0,TAU))*rng.randf_range(0.0,1.6)
			at = Vector3(hp.x+off.x,0.12+hp.y*maxf(1.0-off.length()/1.6,0.0)*0.8,hp.z+off.y)
		mm.set_instance_transform(i,Transform3D(basis,at))
		mm.set_instance_color(i,light.lerp(deep,rng.randf()))
	var tufts := MultiMeshInstance3D.new()
	tufts.name = "Tufts"
	tufts.multimesh = mm
	tufts.material_override = tuft_mat
	tufts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(tufts)
	for sgn: float in [-1.0,1.0]:
		var x := -h.x+3.0
		while x < h.x-3.0:
			var n := rng.randi_range(1,3)
			for k in n:
				var at := Vector3(x+rng.randf_range(-0.2,0.2),0.3+(0.6 if k == 2 else 0.0),sgn*(h.y-1.0)+rng.randf_range(-0.15,0.15))
				if k == 1: at += Vector3(1.25,0.0,0.0)
				elif k == 2: at += Vector3(0.62,0.0,0.0)
				box.call(Vector3(1.2,0.6,0.7),at,straw_dark if (k+int(x))%3 == 0 else straw,rng.randf_range(-0.12,0.12),true)
			x += rng.randf_range(5.0,9.0)
	# Two nets pegged out over the straw: a rope grid on short pegs.
	for mid: Vector3 in [Vector3(-h.x*0.45,0.0,0.0),Vector3(h.x*0.45,0.0,0.0)]:
		var nx := 6.0
		var nz := 4.5
		var step := 0.75
		var x := -nx
		while x <= nx+0.01:
			box.call(Vector3(0.06,0.06,nz*2.0),mid+Vector3(x,0.14,0.0),rope)
			x += step
		var z := -nz
		while z <= nz+0.01:
			box.call(Vector3(nx*2.0,0.06,0.06),mid+Vector3(0.0,0.15,z),rope)
			z += step
		for c: Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
			box.call(Vector3(0.16,0.4,0.16),mid+Vector3(c.x*nx,0.2,c.y*nz),post,0.0,true)
	# The kerb: dark stones along each side, a little uneven.
	for side: int in 4:
		var along := h.x if side < 2 else h.y
		var across := h.y if side < 2 else h.x
		var sgn := 1.0 if side%2 == 0 else -1.0
		var x := -along
		while x < along:
			var run := minf(rng.randf_range(0.8,1.4),along-x)
			var m := x+run*0.5
			var at := Vector3(m,0.08,sgn*across) if side < 2 else Vector3(sgn*across,0.08,m)
			var size := Vector3(run-0.1,rng.randf_range(0.12,0.2),0.55) if side < 2 else Vector3(0.55,rng.randf_range(0.12,0.2),run-0.1)
			box.call(size,at,kerb,0.0,true)
			x += run
	# Corner posts with pennants (seen from the air on the approach).
	for c: Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
		var foot := Vector3(c.x*(h.x+0.6),0.0,c.y*(h.y+0.6))
		box.call(Vector3(0.22,4.2,0.22),foot+Vector3(0.0,2.1,0.0),post,0.0,true)
		box.call(Vector3(1.6,0.9,0.03),foot+Vector3(-c.x*0.8,3.65,0.0),cloth,0.0,true)
	return root
