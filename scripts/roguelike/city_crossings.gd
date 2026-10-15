extends RefCounted
## The crossings of a city layer (underground; docs/design/roguelike/
## layer-round14-city-layers.md), built in the city kit's basalt
## (scripts/city_kit.gd `Piece`, scripts/city_kit_stone.gd) in place of the
## sky kit's: the same plan (scripts/roguelike/layer_plan.gd edges: their
## stones and bridges, sized from the wanderer), dressed as the city.
##   stones    the tops of sunken basalt columns: a hex drum his stride long
##             (a flat across the way, so the gap he jumps is the plan's),
##             its shaft going down into the haze, broken off short
##   landings  a square slab on a stepped corbel and a pier
##   bridges   a causeway beam: a basalt deck from end to end at the
##             footbridge's grade, a curb each side a hand high, a pier under
##             each third of a long one
## Collision is clean (the plan's tops), drawn stone chipped.
## Round 15's family (layer-round15-city-crossings.md, scripts/roguelike/
## city_ways.gd), drawn with scripts/city_kit_ways.gd:
##   spans     a causeway's spans in their states (whole, gone, sagged,
##             slumped) on joint piers
##   chute     the spillway, a banked channel on hex piers
##   piers     (stones marked "pier") drum stacks; "step" a low stump
## and the roots off all of them, one HangingRoots batch.
const CityKit = preload("res://scripts/city_kit.gd")
const Stone = preload("res://scripts/city_kit_stone.gd")
const Ways = preload("res://scripts/city_kit_ways.gd")
const HangingRoots = preload("res://scripts/kit_isle/hanging_roots.gd")

## A column top's shaft: how far down (m), its apothem as a share of the
## top's; a landing's pier.
const SHAFT := Vector2(5.0,16.0)
const SHAFT_IN := 0.82
const PIER_DOWN := Vector2(10.0,22.0)
## A causeway: its deck's width and thickness (m), its curbs (width, height
## over the deck), a pier at least this far apart (m).
const DECK := 2.6
const DECK_THICK := 1.1
const CURB := Vector2(0.35,0.3)
const PIER_EVERY := 9.0

## Every stone and bridge of `edges` as one piece ("CityCrossings": its
## "Mesh" and "Body").
static func build(edges: Array, seed_value: int) -> Node3D:
	var b := CityKit.Piece.new("CityCrossings",seed_value,0.55)
	var roots: Array = []
	for e: Dictionary in edges:
		for s: Dictionary in e.stones:
			if bool(s.get("pier",false)): Ways.drum_pier(b,s.at,(s.size as Vector3).x,float(s.yaw),roots)
			elif bool(s.get("step",false)): Ways.step_drum(b,s.at,(s.size as Vector3).x,float(s.yaw))
			else: _stone(b,s)
		for ends: Array in e.bridges: _causeway(b,ends[0],ends[1])
		if not (e.get("spans",[]) as Array).is_empty(): Ways.causeway(b,e.spans,roots)
		if not (e.get("chute",{}) as Dictionary).is_empty(): Ways.chute(b,e.chute,roots)
	var out := b.finish()
	if not roots.is_empty(): out.add_child(HangingRoots.batch(roots,seed_value+7))
	return out

## A stone of the plan ({at (its top's middle), size, yaw, landing}).
static func _stone(b: CityKit.Piece, s: Dictionary) -> void:
	var size: Vector3 = s.size
	var top: Vector3 = s.at
	var yaw := float(s.yaw)
	var turn := Basis(Vector3.UP,yaw)
	if bool(s.get("landing",false)):
		# A square slab, a corbel course under it, a pier into the haze.
		var h := Vector3(size.x*0.5,size.y*0.5,size.z*0.5)
		b.block(Stone.box(Transform3D(turn,top-Vector3.UP*h.y),h,0.08),true,null,0.7)
		var c := Vector3(h.x*0.78,0.5,h.z*0.78)
		b.block(Stone.box(Transform3D(turn,top-Vector3.UP*(size.y+0.5)),c,0.06),true,null,0.5)
		var down := b.rng.randf_range(PIER_DOWN.x,PIER_DOWN.y)
		var ph := Vector3(h.x*0.45,down*0.5,h.z*0.45)
		b.block(Stone.box(Transform3D(turn,top-Vector3.UP*(size.y+1.0+ph.y)),ph,0.1),true,null,1.0)
		return
	# A hex column's top, one flat facing along the way (+x of its yaw).
	var r := minf(size.x,size.z)*0.5
	var face_turn := yaw+PI/2.0
	var tall := float(size.y)
	b.block(Stone.drum(Transform3D(Basis.IDENTITY,top-Vector3.UP*tall),6,r,r,tall,0.06,face_turn),true,null,0.8)
	var down := b.rng.randf_range(SHAFT.x,SHAFT.y)
	var rs := r*SHAFT_IN*b.rng.randf_range(0.92,1.0)
	b.block(Stone.drum(Transform3D(Basis.IDENTITY,top-Vector3.UP*(tall+down)),6,rs,rs*0.94,down-0.02,0.0,face_turn),true,null,1.2)

## A causeway beam from `a` to `b` (their deck tops, the plan's bridge
## ends).
static func _causeway(b: CityKit.Piece, a: Vector3, z: Vector3) -> void:
	var along := z-a
	var length := along.length()
	if length < 0.5: return
	var dir := along/length
	var flat := Vector3(dir.x,0.0,dir.z).normalized()
	var side := Vector3.UP.cross(flat).normalized()
	var up := dir.cross(side).normalized()
	if up.y < 0.0: up = -up
	var basis := Basis(side,up,dir)
	var mid := (a+z)*0.5
	var hw := DECK*0.5
	# The deck (run a little past each end onto the lip it meets).
	var h := Vector3(hw,DECK_THICK*0.5,length*0.5+0.4)
	b.block(Stone.box(Transform3D(basis,mid-up*h.y),h,0.06),true,null,0.6)
	# Its curbs: a hand high, not a wall (he hops off them).
	for s: float in [-1.0,1.0]:
		var ch := Vector3(CURB.x*0.5,CURB.y*0.5,length*0.5)
		b.block(Stone.box(Transform3D(basis,mid+side*s*(hw-CURB.x*0.5)+up*ch.y),ch,0.04),false,null,0.6)
	# A carved fret down each face.
	for s: float in [-1.0,1.0]:
		b.runes(a+side*s*hw-up*DECK_THICK*0.45,z+side*s*hw-up*DECK_THICK*0.45,up,side*s,0.5)
	# Piers under a long one.
	var n := int(floor(length/PIER_EVERY))
	for k in range(1,n+1):
		var t := float(k)/float(n+1)
		var p := a.lerp(z,t)
		var down := b.rng.randf_range(PIER_DOWN.x,PIER_DOWN.y)
		var ph := Vector3(hw*0.7,down*0.5,0.7)
		b.block(Stone.box(Transform3D(Basis(Vector3.UP,atan2(flat.x,flat.z)),p-Vector3.UP*(DECK_THICK+ph.y)),ph,0.1),true,null,1.0)
