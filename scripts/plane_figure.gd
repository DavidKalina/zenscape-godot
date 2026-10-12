extends Node3D
## The wanderer flying the little plane (scripts/sky_plane.gd), for the chase
## camera (scripts/glide_camera.gd): a small 1920s biplane in warm wood
## browns, cream doped wings tipped in terracotta, and the wanderer in the
## open cockpit behind a little windscreen, in a leather cap and brass
## goggles, the scarf's two tails streaming behind. It is what flies.
##
## Drawn as a real one is built, at a toy's size: a slim body tapering to a
## knife-edged tail, a round cowl with louvres, a seam of rivets and
## exhaust stacks bent back along the side, a padded coaming and a turtle
## deck behind the pilot's head; thin wings, tapered, rounded at the tips,
## with an airfoil's section, their cloth drawn tight over the ribs and
## sagging a little between them (`_wing`), so every rib shows as a crease
## in the light; roundels on the upper wing; fine struts, wires crossed
## between the wings, a V undercarriage on an axle and spoked-over wheels.
##
## Faceted solids and soft light, as the style asks: every solid is a few
## flat faces, lit as the folk are (shaders/folk_surface.gdshader, so it
## never goes black in shade); the paint a deep glossy lacquer under a clear
## coat, so each facet catches the sun as it turns; the wings a satin doped
## cloth, the spinner and fittings bright brass, the propeller's varnish
## glowing. How worn it is (`set_wear`) runs from that, kept and polished,
## to dusty, sun-faded and scuffed, the coat gone dull and the brass
## tarnished; a livery may carry its own (scripts/sky_traffic.gd). The scarf is soft wool, fluttering faster
## the faster it flies. The propeller is a varnished wooden one with brass
## tips; once it turns too fast to see, only a soft disc of air shows
## (shaders/prop_blur.gdshader), its sweeps crawling round as a filmed one's
## do. It is drawn turned by the bank and the barrel roll together. The
## ailerons tip with the roll, the elevator with the pitch, so the stick
## shows on the wings. A soft mark under it shows where it
## would touch down, and close past rock vapour peels off its upper
## wingtips.
##
## Its fixed parts are joined into one mesh for each material (`_join`), so
## a plane is a dozen draws however finely it is made (the sky's traffic
## flies several, scripts/sky_traffic.gd).
##
## Its loose pieces (`piece`: the cowl, propeller, windscreen, wheels, fin
## and wingtip) are built apart, so the parts the pilot finds on foot
## (scripts/plane_parts.gd) are drawn from the same geometry and paint.
##
## Landed, it stands on its two wheels and a tail skid, nose up (`park`,
## scripts/plane_strip.gd `rest`), the pilot out, the propeller still.
##
## It can stand broken (`set_missing`): each of the six found parts
## (scripts/plane_parts.gd IDS) gone leaves damage where it was, so the
## plane reads as broken, not unfinished: a bare shaft and flange for the
## propeller, the radial engine bare for the cowl, the right gear folded
## up under a bare stub axle for the right wheel (the plane slumped onto
## it, its lower wingtip down by the grass), a jagged stub and bare rudder
## post for the fin, the upper wing's right end torn past its last rib,
## spars and a broken rib showing, and for the windscreen its frame bent
## open, the top rail hanging, a crazed shard and its splinters on the
## deck. Broken, it is worn too: the more parts lost, the dustier and more
## faded (`set_missing` sets the wear, BROKEN_WEAR). `set_found` seats a
## part back: it eases in from just off its place, turning, and settles,
## then a warm glint, a brass ring of light and a puff of dust, and the
## paint eases a step cleaner; it keeps a faint glow a while after
## (`afterglow`, or for good with `hold_glow`). The last part home, the
## wear eases off to new and a gleam runs over the whole plane, nose to
## tail. Nothing missing, the figure is built as ever: it only splits its
## found parts off its joined meshes the first time one goes missing
## (`_split`).

const PlanePilot = preload("res://scripts/plane_pilot.gd")
const FacetMesh = preload("res://scripts/facet_mesh.gd")
const PersonKit = preload("res://scripts/person_kit.gd")
const PROP_BLUR := preload("res://shaders/prop_blur.gdshader")
const FOLK_RIBBON := preload("res://shaders/folk_ribbon.gdshader")
const PART_GLOW := preload("res://shaders/plane_part_glow.gdshader")
const WOOD := Color("8f5234")
const DARK := Color("6b3b28")
const TRIM := Color("c8643b")
const WING := Color("f3ead6")
const LEATHER := Color("5e3522")
const BRASS := Color("d6ad62")
const STRIPE := Color("f3ead6")
const PROPWOOD := Color("7a4429")
const STEEL := Color("3b3430")
## Each paint's finish from new to worn (`set_wear`): its roughness new
## and worn, its clear coat new and worn, the coat's roughness new and
## worn, and the shader's weathering (folk_surface `wear`) at worn. New is
## a deep gloss: the lacquer and the varnish under a hard clear coat, the
## doped cloth satin, the brass polished. Worn, the coat is gone dull.
const FINISH := {
	"wood":[0.3,0.62,0.55,0.15,0.03,0.4,1.0],
	"dark":[0.3,0.62,0.55,0.15,0.03,0.4,0.55],
	"trim":[0.3,0.62,0.55,0.15,0.03,0.4,1.0],
	"cream":[0.45,0.82,0.3,0.0,0.1,0.45,0.9],
	"leather":[0.42,0.75,0.45,0.1,0.15,0.4,0.6],
	"varnish":[0.22,0.6,0.7,0.1,0.03,0.4,0.8],
	"brass":[0.22,0.55,0.5,0.0,0.05,0.12,0.55],
	"steel":[0.3,0.68,0.0,0.0,0.12,0.12,0.6],
}
## The cool sky rim the folk paint takes in shade (folk_surface `rim`),
## new: less, so the deep lacquer keeps its own colour; worn, as the folk.
const RIM_NEW := 0.22
## Brass: how metal it is new and worn (less, it reads as a warm gold in
## shade rather than mirroring the ground), and the dull brown it tarnishes
## toward (its share at worn).
const BRASS_METAL := Vector2(0.42,0.35)
const TARNISH := Color("7d6a45")
const TARNISH_SHARE := 0.55
## Broken, its wear: with one part still lost, and with all of them (the
## wear between runs with the count); mended, none (new). Seconds the
## paint takes to ease a step cleaner as a part seats.
const BROKEN_WEAR := Vector2(0.3,1.0)
const WEAR_EASE := 1.2
## The gleam over the whole plane as the last part seats: its strength,
## seconds it takes to run nose to tail, its band's width (m, unscaled),
## and the slant it runs on, in the plane's own frame.
const GLEAM := 0.9
const GLEAM_TIME := 1.5
const GLEAM_WIDTH := 0.1
const GLEAM_SLANT := Vector3(0.35,0.3,1.0)
## The wings: the upper's span (m) and the lower's, the chord at the root
## and the tip, the thickness, the ribs out each side, the height of the
## lower and upper wing over the body's middle, and how far the upper sits
## forward. The cloth sags SAG (of the thickness) between the ribs above,
## SAG_UNDER below; the tips round off past ROUND of the half span.
const SPAN := 1.4
const LOWER_SPAN := 1.26
const CHORD := 0.28
const TIP_CHORD := 0.22
const THICK := 0.028
const RIBS := 7
const SAG := 0.18
const SAG_UNDER := 0.1
const ROUND := 0.86
const LOWER_Y := -0.1
const UPPER_Y := 0.3
const STAGGER := -0.06
## The found wingtip (`piece` "wingtip") runs from this share of the upper
## wing's half span out to its tip.
const WINGTIP_FROM := 0.4
## The ailerons, out along the upper wing's trailing edge (fractions of its
## half span), and their depth (m); the elevator's depth.
const AILERON_SPAN := Vector2(0.42,0.78)
const AILERON_DEPTH := 0.06
const ELEVATOR_DEPTH := 0.055
## The section of the wings, (along the chord, up) as fractions of the
## chord and the thickness: the upper surface from the leading edge back,
## then the lower forward.
const AIRFOIL_TOP := [Vector2(0.0,0.0),Vector2(0.04,0.42),Vector2(0.14,0.78),Vector2(0.3,1.0),Vector2(0.55,0.86),Vector2(0.8,0.5),Vector2(1.0,0.08)]
const AIRFOIL_UNDER := [Vector2(1.0,-0.02),Vector2(0.6,-0.135),Vector2(0.25,-0.22),Vector2(0.06,-0.2)]
const AIRFOIL_SCALE := 0.72
## Control surfaces: radians of aileron per radian a second of roll, of
## elevator per radian a second of pitch, and the most either tips.
const AILERON := 0.35
const ELEVATOR := 0.5
const DEFLECT := 0.5
## The propeller: turns a second at rest and per m/s of speed; the blades
## hide past PROP_HIDE turns a second (shown again under PROP_SHOW), leaving
## the disc; the disc's strength at rest and at speed, and how fast its
## sweeps crawl round (radians a second).
const PROP_TURNS := 3.0
const PROP_PER := 0.6
const PROP_HIDE := 9.5
const PROP_SHOW := 8.5
const BLUR := Vector2(0.22,0.55)
const BLUR_CRAWL := 1.4
## The scarf: points of the long tail and the short, the gap between them
## (m), its width, where its two pale stripes run (fractions of a tail's
## length), and its flutter: the waves' rate (radians a second) slow and
## fast, their reach at the tip (m), and the speed (m/s) it is fastest at.
const SCARF := 12
const SCARF_SHORT := 8
const SCARF_GAP := 0.09
const SCARF_WIDTH := 0.085
const SCARF_STRIPES := [Vector2(0.7,0.77),Vector2(0.83,0.9)]
const FLUTTER := Vector2(5.0,17.0)
const FLUTTER_REACH := 0.035
const FLUTTER_FAST := 18.0
## The landing mark shows within MARK_HEIGHT m of the ground.
const MARK_HEIGHT := 28.0
## The wingtip vapour (scripts/glide_vapour.gd says how near the rock is).
const VAPOUR := 14
const VAPOUR_EVERY := 0.04
const VAPOUR_WIDTH := Vector2(0.06,0.55)
const VAPOUR_ALPHA := 0.42
const VAPOUR_DRIFT := Vector2(0.18,0.3)
const VAPOUR_COLOR := Color(1.0,0.98,0.94)
## The found parts (scripts/plane_parts.gd IDS), each of which can be
## missing (`set_missing`).
const FOUND := ["propeller","wheel","cowl","fin","wingtip","windscreen"]
## Seating a part back (`set_found`): seconds it eases in, how far past its
## seat it overshoots before it settles (the ease's back), the glow and
## inner light it comes in with, the flash's at the snap and seconds it
## falls in (a warm glint, not a white-out), the faint glow and inner light
## it keeps after, and seconds it
## keeps them by default (`afterglow`).
const SEAT := 0.6
const SETTLE := 0.9
const ARRIVE := Vector2(0.75,0.05)
const FLASH := Vector2(0.95,0.09)
const FLASH_FALL := 0.35
const KEEP := Vector2(0.5,0.03)
const AFTERGLOW := 40.0
## The brass ring of light at the snap: its reach (times the part's size)
## from and to, its strength and seconds; the puff's motes and seconds.
const RING_REACH := Vector2(0.9,2.8)
const RING_ALPHA := 0.95
const RING_TIME := 0.85
const PUFF := 16
const PUFF_TIME := 1.1
const SEAT_WARM := Color("ffd59a")
const PUFF_DUST := Color(0.96,0.92,0.84)
## Each part's seat: its middle (`at`), where it comes in from (m off the
## seat), the axis it turns about on the way and how far (rad), and its
## size (m), for the ring and the puff.
const SEATS := {
	"propeller":{"at":Vector3(0.0,0.0,-0.7),"from":Vector3(0.0,0.03,-0.26),"axis":Vector3.BACK,"turn":5.0,"size":0.55},
	"cowl":{"at":Vector3(0.0,0.0,-0.53),"from":Vector3(0.0,0.06,-0.22),"axis":Vector3.RIGHT,"turn":0.35,"size":0.32},
	"wheel":{"at":Vector3(0.2,-0.33,-0.28),"from":Vector3(0.2,0.07,0.0),"axis":Vector3.RIGHT,"turn":-3.0,"size":0.2},
	"fin":{"at":Vector3(0.0,0.15,0.63),"from":Vector3(0.0,0.22,0.04),"axis":Vector3.UP,"turn":0.6,"size":0.3},
	"wingtip":{"at":Vector3(0.49,UPPER_Y,STAGGER),"from":Vector3(0.2,0.07,0.0),"axis":Vector3.BACK,"turn":0.35,"size":0.45},
	"windscreen":{"at":Vector3(0.0,0.235,0.11),"from":Vector3(0.0,0.16,-0.05),"axis":Vector3.RIGHT,"turn":0.6,"size":0.16},
}
## The upper wing's right end with its tip lost: the cloth whole to the rib
## TORN_RIB m out, torn ragged past it (TEAR, m, the tears' reach round the
## section, and TOOTH the teeth between them); the spars run on bare to
## SPARS m out, a broken rib at BARE_RIB.
const TORN_RIB := 0.2
const TEAR := [0.032,0.012,0.05,0.02,0.058,0.014,0.04,0.026,0.052,0.01,0.03]
const TOOTH := [0.05,0.008,0.066,0.022,0.03,0.07,0.012,0.045,0.02,0.06]
const SPARS := Vector2(0.318,0.272)
const BARE_RIB := 0.262
## Lost the right wheel, the right gear folds up and it slumps over, about
## the line from the left wheel's foot to the tail skid's, till its lower
## right wingtip (LOW_TIP) is WING_CLEAR m off the grass; the folded gear
## (the right V and the axle) meets the grass under where the V's foot was
## (GEAR_FOOT).
const LOW_TIP := Vector3(0.6,-0.106,-0.03)
const WING_CLEAR := 0.012
const GEAR_FOOT := Vector3(0.165,-0.33,-0.28)
const LEFT_FOOT := Vector3(-0.2,-0.41,-0.28)
const RIGHT_FOOT := Vector3(0.2,-0.41,-0.28)
const SKID_FOOT := Vector3(0.0,-0.118,0.66)

var _prop: Node3D
var _blur: MeshInstance3D
## The pilot in the cockpit, hidden once they hop out.
var _pilot: Array[Node3D] = []
var _rig: Node3D
## True while it stands parked on the land, not flying.
var parked := false
var _blur_material: ShaderMaterial
var _blades_shown := true
var _prop_angle := 0.0
## The ailerons (left, right) and the elevator, on their hinges.
var _ailerons: Array[Node3D] = []
var _elevator: Node3D
var _last_roll := 0.0
var _last_pitch := 0.0
var _scarf_points := PackedVector3Array()
var _short_points := PackedVector3Array()
var _scarf: MeshInstance3D
var _scarf_mesh: ImmediateMesh
var _mark: MeshInstance3D
var _mark_material: StandardMaterial3D
var _mark_bright := 0.0
var _vapour: MeshInstance3D
var _vapour_mesh: ImmediateMesh
var _vapour_points := PackedVector3Array()
var _vapour_strength := PackedFloat32Array()
var _vapour_clock := 0.0
## The paints it was built in, for the parts it splits off (`_split`).
var _paints := {}
## Where its found parts' triangles lie in its joined meshes: [the joined
## MeshInstance3D, the part, first vertex, vertex count].
var _spans := []
## The parts missing, and each part's nodes once split (`_split`): "whole"
## (the part itself, which seats), "base" (shown while it is on, not
## seating: the wing's inner end, the aileron), "broken" (the damage), its
## glow and where it seats.
var _missing := {}
var _parts := {}
var _split_done := false
## The seatings under way: {id, t, snapped, ring, puff}.
var _seating := []
## Seconds a seated part keeps its faint glow, and true to keep it on.
var afterglow := AFTERGLOW
var hold_glow := false
## How far it leans onto the bare axle (0 to 1, `_tip`), and the transform
## it was parked at.
var _lean := 0.0
var _lean_to := 0.0
var _parked_at := Transform3D.IDENTITY
## How worn its paint is (`set_wear`), what it eases to and over how many
## seconds; its livery's own, under any broken wear; the gleam's clock (-1
## none).
var _wear := 0.0
var _wear_to := 0.0
var _wear_ease := WEAR_EASE
var _base_wear := 0.0
var _gleam_t := -1.0

## `livery` repaints it (scripts/sky_traffic.gd): any of body, dark, trim,
## wing and scarf, each a Color, and wear (0 to 1, `set_wear`); the
## wanderer's own plane takes none, new.
func _init(livery := {}) -> void:
	name = "Plane"
	var paint := paints(livery)
	_paints = paint
	_base_wear = clampf(float(livery.get("wear",0.0)),0.0,1.0)
	_wear = _base_wear
	_wear_to = _base_wear
	var wood: Material = paint.wood
	var dark: Material = paint.dark
	var trim: Material = paint.trim
	var cream: Material = paint.cream
	var leather: Material = paint.leather
	var steel: Material = paint.steel
	# The body runs along -Z, the nose forward: slim, deepest at the
	# cockpit, tapering to a knife-edged tail post; a round terracotta cowl
	# round the nose (`piece` "cowl") and the brass spinner.
	_add(_hull([Vector3(-0.47,0.13,0.135),Vector3(-0.36,0.142,0.15),Vector3(-0.1,0.146,0.158),Vector3(0.1,0.14,0.15),Vector3(0.3,0.105,0.12),Vector3(0.52,0.06,0.085),Vector3(0.72,0.016,0.05)],10),wood,Vector3.ZERO,Vector3.ZERO)
	_add_piece("cowl",paint)
	_add_piece("spinner",paint)
	# A terracotta band round the body before the tail.
	_add(_hull([Vector3(0.42,0.085,0.104),Vector3(0.47,0.075,0.097)],10),trim,Vector3.ZERO,Vector3.ZERO)
	# The cockpit: a dark tub let into the back, a padded leather coaming,
	# a small glass windscreen in a brass frame before it and a turtle deck
	# behind, rising to a headrest. In it, the wanderer from the chest up,
	# alive in the seat (scripts/plane_pilot.gd).
	_add(_hull([Vector3(-0.12,0.095,0.06),Vector3(0.12,0.095,0.06)],8),dark,Vector3(0.0,0.15,0.22),Vector3.ZERO)
	var rim := _add(FacetMesh.frustum(0.108,0.096,0.03,12),leather,Vector3(0.0,0.2,0.22),Vector3.ZERO)
	rim.scale = Vector3(1.0,1.0,1.3)
	_add(_hull([Vector3(0.0,0.052,0.05),Vector3(0.1,0.04,0.035),Vector3(0.27,0.0,0.0)],8),dark,Vector3(0.0,0.17,0.33),Vector3(0.2,0.0,0.0))
	_add_piece("windscreen",paint)
	_rig = PlanePilot.new(PersonKit.outfit(livery.get("scarf",PersonKit.SCARF)))
	_rig.scale = Vector3.ONE*0.92
	add_child(_rig)
	_pilot.append(_rig)
	# The wings: a lower wing through the body and a longer upper one on
	# struts, the upper a little forward; cream doped cloth tight over the
	# ribs, tipped in terracotta, the upper with roundels near its tips.
	var rounded := SPAN*0.5*0.8
	var ailerons := Vector3(SPAN*0.5*AILERON_SPAN.x,SPAN*0.5*AILERON_SPAN.y,_hinge_z())
	_add(_wing(SPAN*0.5,-rounded,rounded,ailerons),cream,Vector3(0.0,UPPER_Y,STAGGER),Vector3.ZERO).set_meta("piece","upper_wing")
	var lower_round := LOWER_SPAN*0.5*0.8
	_add(_wing(LOWER_SPAN*0.5,-lower_round,lower_round),cream,Vector3(0.0,LOWER_Y,0.0),Vector3.ZERO)
	for side in [-1.0,1.0]:
		var tip := Vector2(rounded,SPAN*0.5) if side > 0.0 else Vector2(-SPAN*0.5,-rounded)
		var upper_tip := _add(_wing(SPAN*0.5,tip.x,tip.y),trim,Vector3(0.0,UPPER_Y,STAGGER),Vector3.ZERO)
		if side > 0.0: upper_tip.set_meta("piece","wingtip")
		var low := Vector2(lower_round,LOWER_SPAN*0.5) if side > 0.0 else Vector2(-LOWER_SPAN*0.5,-lower_round)
		_add(_wing(LOWER_SPAN*0.5,low.x,low.y),trim,Vector3(0.0,LOWER_Y,0.0),Vector3.ZERO)
		# A roundel on the upper wing, on the cloth as it lies.
		var at := Vector2(SPAN*0.3*side,-CHORD*0.5+0.42*_chord_at(SPAN*0.5,SPAN*0.3))
		var rings := [[0.062,dark],[0.046,trim],[0.018,cream]]
		for k in range(rings.size()):
			var ring := _add(_decal(SPAN*0.5,at,float(rings[k][0]),0.0015+0.0005*k),rings[k][1],Vector3(0.0,UPPER_Y,STAGGER),Vector3.ZERO)
			if side > 0.0: ring.set_meta("piece","wingtip")
	for side in [-1.0,1.0]:
		# The ailerons hinge into the upper wing's trailing edge, out towards
		# the tips.
		var hinge := Node3D.new()
		hinge.position = Vector3((ailerons.x+ailerons.y)*0.5*side,UPPER_Y+0.004,STAGGER+ailerons.z)
		add_child(hinge)
		var flap := MeshInstance3D.new()
		flap.mesh = _scaled(_prism([Vector2(0.0,0.006),Vector2(AILERON_DEPTH,-0.001),Vector2(0.0,-0.006)]),Vector3(ailerons.y-ailerons.x-0.004,1.0,1.0))
		flap.material_override = cream
		hinge.add_child(flap)
		_ailerons.append(hinge)
		# Interplane struts, a cabane from the upper wing to the body, and
		# wires crossed between the wings, glinting.
		var out: float = SPAN*0.34*side
		for dz in [-0.075,0.075]:
			_strut(Vector3(out,LOWER_Y,dz),Vector3(out,UPPER_Y,dz+STAGGER),dark,0.008)
		for dz in [-0.05,0.05]:
			_strut(Vector3(0.09*side,0.14,-0.25+dz),Vector3(0.13*side,UPPER_Y,STAGGER+dz),dark,0.007)
		for dz in [-0.06,0.06]:
			_strut(Vector3(out,UPPER_Y,STAGGER+dz),Vector3(0.15*side,LOWER_Y,dz),steel,0.0028)
			_strut(Vector3(out,LOWER_Y,dz),Vector3(0.14*side,UPPER_Y,STAGGER+dz),steel,0.0028)
		# The undercarriage: a V of legs either side to the axle, and the
		# wheels on it, their spokes covered in cream, brass hubs.
		var legs := [_strut(Vector3(0.07*side,-0.14,-0.38),Vector3(0.165*side,-0.33,-0.28),dark,0.009),_strut(Vector3(0.07*side,-0.14,-0.17),Vector3(0.165*side,-0.33,-0.28),dark,0.009)]
		# The right gear folds up when its wheel is lost (`damage`).
		if side > 0.0:
			for leg: Node in legs: leg.set_meta("piece","gear")
		_add_piece("wheel",paint,null,side)
	_strut(Vector3(-0.17,-0.33,-0.28),Vector3(0.17,-0.33,-0.28),dark,0.008).set_meta("piece","gear")
	# A tail skid it rests on, parked (scripts/plane_strip.gd TAIL).
	_strut(Vector3(0.0,-0.03,0.58),Vector3(0.0,-0.11,0.66),dark,0.01)
	_add(FacetMesh.gem(0.018),steel,Vector3(0.0,-0.1,0.66),Vector3.ZERO)
	# The tail: a terracotta fin with a cream rudder, a cream tailplane and
	# its elevator either side of the rudder.
	_add_piece("fin",paint)
	_add(_wing(0.25,-0.25,0.25,Vector3.ZERO,0.13,0.1,0.016,3),cream,Vector3(0.0,0.03,0.62),Vector3.ZERO)
	_elevator = Node3D.new()
	_elevator.position = Vector3(0.0,0.032,0.62+0.065)
	add_child(_elevator)
	for side in [-1.0,1.0]:
		var elevator := MeshInstance3D.new()
		elevator.mesh = _scaled(_prism([Vector2(0.0,0.004),Vector2(ELEVATOR_DEPTH,0.0),Vector2(0.0,-0.004)]),Vector3(0.2,1.0,1.0))
		elevator.material_override = cream
		elevator.position = Vector3(0.125*side,0.0,0.0)
		_elevator.add_child(elevator)
	# The propeller: two varnished wooden blades, brass-sheathed at the
	# tips, and the soft disc of air they turn into, at the nose.
	_prop = Node3D.new()
	_prop.position = Vector3(0.0,0.0,-0.68)
	add_child(_prop)
	var varnish: Material = paint.varnish
	_add_piece("propeller",paint,_prop)
	var blur := MeshInstance3D.new()
	_blur = blur
	var disc := QuadMesh.new()
	disc.size = Vector2.ONE*0.58
	blur.mesh = disc
	_blur_material = ShaderMaterial.new()
	_blur_material.shader = PROP_BLUR
	blur.material_override = _blur_material
	blur.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	blur.position = Vector3(0.0,0.0,-0.69)
	add_child(blur)
	_scarf_mesh = ImmediateMesh.new()
	_scarf = MeshInstance3D.new()
	_scarf.mesh = _scarf_mesh
	_scarf.top_level = true
	var scarf_material := ShaderMaterial.new()
	scarf_material.shader = FOLK_RIBBON
	scarf_material.set_shader_parameter("roughness_value",0.95)
	scarf_material.set_meta("scarf",livery.get("scarf",Color("d9573a")))
	_scarf.material_override = scarf_material
	_scarf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_scarf)
	_mark = MeshInstance3D.new()
	var mark := QuadMesh.new()
	mark.size = Vector2.ONE
	mark.orientation = PlaneMesh.FACE_Y
	_mark.mesh = mark
	_mark.top_level = true
	_mark_material = StandardMaterial3D.new()
	_mark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mark_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mark_material.albedo_texture = FacetMesh.soft_ring()
	_mark_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mark.material_override = _mark_material
	_mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mark.visible = false
	add_child(_mark)
	_vapour_mesh = ImmediateMesh.new()
	_vapour = MeshInstance3D.new()
	_vapour.name = "Vapour"
	_vapour.mesh = _vapour_mesh
	_vapour.top_level = true
	var mist := StandardMaterial3D.new()
	mist.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mist.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mist.vertex_color_use_as_albedo = true
	mist.albedo_texture = FacetMesh.soft_band()
	mist.cull_mode = BaseMaterial3D.CULL_DISABLED
	_vapour.material_override = mist
	_vapour.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_vapour.visible = false
	add_child(_vapour)
	_vapour_points.resize(VAPOUR*2)
	_vapour_strength.resize(VAPOUR*2)
	# The body's paint first among its children (sky_traffic tells liveries
	# by it).
	_join(self,wood)
	_join(_prop,varnish)

## Its parent must be a plain Node (or the scene root): it is placed by its
## own transform. The scarf and the mark are top level, in global space.
##
## Starts the scarf streaming straight back from where it is now.
func reset(glide: RefCounted) -> void:
	parked = false
	show_pilot(true)
	_scarf_points.resize(SCARF)
	_short_points.resize(SCARF_SHORT)
	var back: Vector3 = -glide.forward()
	for i in range(SCARF): _scarf_points[i] = glide.position+back*SCARF_GAP*i
	for i in range(SCARF_SHORT): _short_points[i] = glide.position+back*SCARF_GAP*i
	_mark_bright = 0.0
	_vapour_clock = 0.0
	_vapour_points.fill(glide.position)
	_vapour_strength.fill(0.0)
	_last_roll = _roll(glide)
	_last_pitch = float(glide.pitch)
	update(0.0,glide,0.0,Callable(),false)

## The world moved under it (SkyIslands `arrive`): the scarf goes too.
func shift(by: Vector3) -> void:
	for i in range(_scarf_points.size()): _scarf_points[i] += by
	for i in range(_short_points.size()): _short_points[i] += by
	for i in range(_vapour_points.size()): _vapour_points[i] += by

## One frame: posed on `glide` (a SkyPlane, or a plain
## glide drawn without its roll), `dive` held 0..1 (unused), `ground` the
## height under a point, `landable` whether a touch now would land, and
## `near` and `lean` the vapour's.
func update(delta: float, glide: RefCounted, _dive: float, ground: Callable, landable: bool, near := 0.0, lean := 0.0) -> void:
	var at: Vector3 = glide.position
	var roll := _roll(glide)
	transform = pose(at,float(glide.heading),float(glide.pitch),roll)
	# The control surfaces follow how fast it rolls and pitches, and so
	# does the pilot.
	var roll_rate := (roll-_last_roll)/delta if delta > 0.0 else 0.0
	var pitch_rate := (float(glide.pitch)-_last_pitch)/delta if delta > 0.0 else 0.0
	var spin: Variant = glide.get("spin")
	var throttle: Variant = glide.get("throttle")
	var running: Variant = glide.get("engine")
	if _rig.visible: _rig.animate(delta,float(glide.bank),float(glide.pitch),roll_rate,pitch_rate,float(throttle) if throttle != null else 0.0,float(spin) if spin != null else 0.0,float(running) if running != null else 1.0)
	if delta > 0.0:
		var rolled := clampf(roll_rate*AILERON,-DEFLECT,DEFLECT)
		var pitched := clampf(pitch_rate*ELEVATOR,-DEFLECT,DEFLECT)
		var k := 1.0-exp(-delta/0.08)
		for s in range(2):
			var hand := -1.0 if s == 0 else 1.0
			_ailerons[s].rotation.x = lerpf(_ailerons[s].rotation.x,rolled*hand,k)
		_elevator.rotation.x = lerpf(_elevator.rotation.x,pitched,k)
	_last_roll = roll
	_last_pitch = float(glide.pitch)
	var pace := float(glide.speed)
	_spin_prop(delta,pace,float(running) if running != null else 1.0)
	_trail_scarf(delta,glide)
	_trail_vapour(delta,near,lean)
	_place_mark(delta,at,ground,landable)

## The propeller turns with the speed while the engine runs (`running`, 0
## to 1), its blur fading as it spins down. Too fast to see, the blades
## give way to the disc alone, its sweeps crawling round.
func _spin_prop(delta: float, pace: float, running: float) -> void:
	var turns := (PROP_TURNS+PROP_PER*pace)*running
	_prop_angle = wrapf(_prop_angle+delta*turns*TAU,0.0,TAU)
	_prop.rotation.z = _prop_angle
	if _blades_shown and turns > PROP_HIDE: _blades_shown = false
	elif not _blades_shown and turns < PROP_SHOW: _blades_shown = true
	for blade in _prop.get_children(): blade.visible = _blades_shown
	var fast := clampf(pace/30.0,0.0,1.0)
	_blur_material.set_shader_parameter("strength",lerpf(BLUR.x,BLUR.y,fast)*smoothstep(0.0,0.6,running))
	_blur_material.set_shader_parameter("spread",fast)
	_blur_material.set_shader_parameter("phase",fmod(Time.get_ticks_msec()*0.001*BLUR_CRAWL,TAU)*running)
	_blur.visible = running > 0.01 and not _missing.has("propeller")

## The pilot in the cockpit, or not (hopped out).
func show_pilot(on: bool) -> void:
	for part in _pilot: part.visible = on
	_scarf.visible = on

## Where the figure stands for a flight's pose: its position (the flight's,
## the figure hangs FIGURE_DROP under it), heading, pitch and roll.
static func pose(at: Vector3, heading: float, pitch: float, roll: float) -> Transform3D:
	return Transform3D(Basis.from_euler(Vector3(pitch,heading,-roll)),at+Vector3.DOWN*0.2)

## Stands it parked: `placed` is its transform in its parent's frame (the
## plate's, so it turns and moves with the land); the engine off, the
## pilot out, no scarf, mark or vapour.
func park(placed: Transform3D) -> void:
	parked = true
	_parked_at = placed
	transform = placed*_leaning()
	show_pilot(false)
	_spin_prop(0.0,0.0,0.0)
	_mark.visible = false
	_vapour.visible = false

## The whole roll it is drawn at: the bank and, on a plane, the barrel roll.
func _roll(glide: RefCounted) -> float:
	var spin: Variant = glide.get("spin")
	return float(glide.bank)+(float(spin) if spin != null else 0.0)

## The scarf's two tails, from the knot at the back of the neck: each point
## is dragged back by the air past it and kept a gap behind the one before,
## sagging when slow. Drawn, ripples run down each tail, side to side and up
## and down, twisting it so the wool catches the light, reaching further
## towards the tip and running faster with the speed.
func _trail_scarf(delta: float, glide: RefCounted) -> void:
	if _scarf_points.size() != SCARF: return
	var knot: Vector3 = transform*_rig.knot()
	var side := basis.x.normalized()
	var up := basis.y.normalized()
	var fast := clampf(float(glide.speed)/FLUTTER_FAST,0.0,1.0)
	var wind: Vector3 = glide.velocity
	_drag_tail(_scarf_points,knot-side*0.012,wind,delta,fast)
	_drag_tail(_short_points,knot+side*0.014,wind,delta,fast)
	var t := Time.get_ticks_msec()*0.001
	var rate := lerpf(FLUTTER.x,FLUTTER.y,fast)
	var color: Color = _scarf.material_override.get_meta("scarf",Color("d9573a"))
	_scarf_mesh.clear_surfaces()
	_draw_tail(_scarf_points,side,up,t*rate,fast,1.0,color)
	_draw_tail(_short_points,side,up,t*rate*1.13+1.7,fast,0.85,color)

func _drag_tail(points: PackedVector3Array, root: Vector3, wind: Vector3, delta: float, fast: float) -> void:
	points[0] = root
	for i in range(1,points.size()):
		var p := points[i]-wind*delta*0.15+Vector3.DOWN*delta*0.5*(1.0-fast)
		var d := p-points[i-1]
		if d.length() > 0.0001: p = points[i-1]+d.normalized()*SCARF_GAP
		points[i] = p

## One tail as a ribbon, `phase` its ripples' clock, `wide` its width's
## share, with the pale stripes cut sharp near its end.
func _draw_tail(points: PackedVector3Array, side: Vector3, up: Vector3, phase: float, fast: float, wide: float, color: Color) -> void:
	var last := float(points.size()-1)
	var cuts := []
	for i in range(points.size()): cuts.append(float(i))
	for stripe: Vector2 in SCARF_STRIPES:
		cuts.append(stripe.x*last)
		cuts.append(stripe.y*last)
	cuts.sort()
	var reach := FLUTTER_REACH*lerpf(0.35,1.0,fast)
	_scarf_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var before := Color(0,0,0,0)
	for u: float in cuts:
		var i := mini(int(u),points.size()-2)
		var p := points[i].lerp(points[i+1],u-i)
		var along := (points[i+1]-points[i]).normalized()
		var tip := pow(u/last,1.3)
		var wave := phase-u*1.1
		p += side*sin(wave)*reach*tip+up*sin(wave*0.8+1.3)*reach*0.6*tip
		var across := side.rotated(along,sin(wave+0.6)*0.7*tip) if along.length_squared() > 0.5 else side
		var normal := across.cross(along).normalized()
		var f := u/last
		var c := color
		for stripe: Vector2 in SCARF_STRIPES:
			if f >= stripe.x-0.0001 and f < stripe.y-0.0001: c = STRIPE
		if before.a > 0.0 and c != before:
			# The stripe's edge: the same place again in the new colour.
			for e in [-1.0,1.0]:
				_scarf_mesh.surface_set_color(before)
				_scarf_mesh.surface_set_normal(normal)
				_scarf_mesh.surface_add_vertex(p+across*e*_scarf_width(f,wide)*0.5)
		before = c
		for e in [-1.0,1.0]:
			_scarf_mesh.surface_set_color(c)
			_scarf_mesh.surface_set_normal(normal)
			_scarf_mesh.surface_add_vertex(p+across*e*_scarf_width(f,wide)*0.5)
	_scarf_mesh.surface_end()

static func _scarf_width(along: float, wide: float) -> float:
	return SCARF_WIDTH*wide*(1.0-0.4*along)

## The vapour: each upper wingtip lays a point every
## VAPOUR_EVERY seconds; the points hang, drifting and widening as they fade.
func _trail_vapour(delta: float, near: float, side: float) -> void:
	_vapour_clock += delta
	var lay := _vapour_clock >= VAPOUR_EVERY
	if lay: _vapour_clock = fmod(_vapour_clock,VAPOUR_EVERY)
	var shown := false
	for s in range(2):
		var hand := -1.0 if s == 0 else 1.0
		var o := s*VAPOUR
		if lay:
			for i in range(VAPOUR-1,0,-1):
				_vapour_points[o+i] = _vapour_points[o+i-1]
				_vapour_strength[o+i] = _vapour_strength[o+i-1]
		var drift := (Vector3.UP*VAPOUR_DRIFT.x+basis.x.normalized()*hand*VAPOUR_DRIFT.y)*delta
		for i in range(1,VAPOUR): _vapour_points[o+i] += drift*float(i)/VAPOUR
		_vapour_points[o] = transform*Vector3(SPAN*0.5*hand,UPPER_Y,STAGGER)
		_vapour_strength[o] = near*clampf(0.6+0.6*side*hand,0.25,1.0)
		for i in range(VAPOUR): shown = shown or _vapour_strength[o+i] > 0.004
	_vapour.visible = shown
	if not shown: return
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	_vapour_mesh.clear_surfaces()
	for s in range(2):
		var o := s*VAPOUR
		_vapour_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for i in range(VAPOUR):
			var p := _vapour_points[o+i]
			var age := float(i)/(VAPOUR-1)
			var along := _vapour_points[o+maxi(i-1,0)]-_vapour_points[o+mini(i+1,VAPOUR-1)]
			var facing := basis.y
			if camera != null and along.length_squared() > 0.000001:
				var across := along.cross(camera.global_position-p)
				if across.length_squared() > 0.000001: facing = across
			facing = facing.normalized()*lerpf(VAPOUR_WIDTH.x,VAPOUR_WIDTH.y,age)*0.5
			var c := VAPOUR_COLOR
			c.a = _vapour_strength[o+i]*VAPOUR_ALPHA*(1.0-age)*(1.0-age)*smoothstep(0.0,0.15,age+0.05)
			_vapour_mesh.surface_set_color(c)
			_vapour_mesh.surface_set_uv(Vector2(0.0,age))
			_vapour_mesh.surface_add_vertex(p-facing)
			_vapour_mesh.surface_set_color(c)
			_vapour_mesh.surface_set_uv(Vector2(1.0,age))
			_vapour_mesh.surface_add_vertex(p+facing)
		_vapour_mesh.surface_end()

func _place_mark(delta: float, at: Vector3, ground: Callable, landable: bool) -> void:
	var under: Variant = ground.call(at) if ground.is_valid() else null
	if under is Vector2:
		var body := under as Vector2
		under = body.x if at.y > body.x else null
	var height := at.y-float(under) if under != null else INF
	_mark.visible = height < MARK_HEIGHT
	if not _mark.visible: return
	_mark_bright = lerpf(_mark_bright,float(landable),1.0-exp(-delta/0.2)) if delta > 0.0 else float(landable)
	var close := 1.0-clampf(height/MARK_HEIGHT,0.0,1.0)
	var size := lerpf(1.2,2.8,clampf(height/12.0,0.0,1.0))
	_mark.transform = Transform3D(Basis().scaled(Vector3(size,1.0,size)),Vector3(at.x,float(under)+0.06,at.z))
	_mark_material.albedo_color = Color(1.0,0.97,0.88,close*lerpf(0.35,0.85,_mark_bright))

# --- Missing and found --------------------------------------------------------------

func _ready() -> void:
	_finish(_paints,_wear)
	_set_running()

func _set_running() -> void:
	set_process(not _seating.is_empty() or _lean != _lean_to or _wear != _wear_to or _gleam_t >= 0.0)

## How worn its paint is, `t` from 0 (new: deep clean lacquer, crisp trim,
## bright brass, glowing varnish, taut clean cloth) to 1 (dusty, faded,
## scuffed, the coat dull, the brass tarnished), easing there over `over`
## seconds (at once with 0). `set_missing` and `set_found` set it from how
## many parts are lost (BROKEN_WEAR), never under the livery's own.
func set_wear(t: float, over := 0.0) -> void:
	_wear_to = clampf(t,0.0,1.0)
	if over <= 0.0:
		_wear = _wear_to
		_finish(_paints,_wear)
	else:
		_wear_ease = over
	_set_running()

## How worn its paint is now (`set_wear`).
func get_wear() -> float:
	return _wear

## The wear with `lost` parts missing: none mended, BROKEN_WEAR between,
## the livery's own beneath.
func _broken_wear(lost: int) -> float:
	var t := 0.0 if lost <= 0 else lerpf(BROKEN_WEAR.x,BROKEN_WEAR.y,clampf((lost-1)/float(FOUND.size()-1),0.0,1.0))
	return maxf(_base_wear,t)

## Stands it with the parts `ids` (of FOUND) missing, the damage showing
## where each was, and the rest on, at once. A figure never broken, given
## none, is left as it was built.
func set_missing(ids: Array) -> void:
	if ids.is_empty() and not _split_done: return
	_split()
	for s: Dictionary in _seating: _clear_seat(s)
	_seating.clear()
	_missing.clear()
	for id in ids:
		if FOUND.has(String(id)): _missing[String(id)] = true
	for id: String in FOUND:
		_show(id,not _missing.has(id))
		_glow(id,0.0,0.0)
	_lean = 1.0 if _missing.has("wheel") else 0.0
	_lean_to = _lean
	if parked: transform = _parked_at*_leaning()
	_gleam_t = -1.0
	_gleam(-1.0)
	set_wear(_broken_wear(_missing.size()))

## The parts missing now.
func missing() -> Array:
	return _missing.keys()

func is_missing(id: String) -> bool:
	return _missing.has(id)

## Puts part `id` back on. With `seat` it eases in from just off its place,
## turning, settles, and snaps home with a flash, a brass ring of light and
## a puff; without, it is simply there. Either way it keeps a faint glow
## `afterglow` seconds (for good with `hold_glow`).
func set_found(id: String, seat := true) -> void:
	if not _missing.has(id): return
	_missing.erase(id)
	_lean_to = 1.0 if _missing.has("wheel") else 0.0
	var s := {"id":id,"t":0.0,"snapped":false,"ring":null,"puff":null}
	if seat:
		var rec: Dictionary = _parts[id]
		for n: Node3D in rec.whole: n.visible = true
		for n: Node3D in rec.base: n.visible = false
		if rec.flap != null: rec.flap.visible = true
		if id == "propeller": _prop.visible = true
		_pose_part(id,1.0)
	else:
		s.t = SEAT+FLASH_FALL*8.0
		s.snapped = true
		_show(id,true)
		_lean = _lean_to
		if parked: transform = _parked_at*_leaning()
		set_wear(_broken_wear(_missing.size()))
	_seating.append(s)
	set_process(true)

func _process(delta: float) -> void:
	for s: Dictionary in _seating.duplicate():
		s.t += delta
		var id: String = s.id
		if not s.snapped:
			var u := clampf(s.t/SEAT,0.0,1.0)
			_pose_part(id,1.0-_settle(u))
			_glow(id,lerpf(ARRIVE.x*0.5,ARRIVE.x,u),ARRIVE.y*u)
			if s.t < SEAT: continue
			# Home: the damage goes, and the flash, the ring and the puff.
			s.snapped = true
			_show(id,true)
			s.ring = _seat_ring(id)
			s.puff = _seat_puff(id)
			# The paint a step cleaner; the last part home, new, and a
			# gleam runs over it all.
			set_wear(_broken_wear(_missing.size()),WEAR_EASE)
			if _missing.is_empty(): _gleam_t = 0.0
		var after: float = s.t-SEAT
		var keep := 1.0 if hold_glow else 1.0-smoothstep(afterglow*0.5,afterglow,after)
		var flash := exp(-after/FLASH_FALL)
		_glow(id,KEEP.x*keep+(FLASH.x-KEEP.x)*flash,KEEP.y*keep+(FLASH.y-KEEP.y*keep)*flash)
		if s.ring != null:
			var r := clampf(after/RING_TIME,0.0,1.0)
			var reach := lerpf(RING_REACH.x,RING_REACH.y,1.0-pow(1.0-r,3.0))*float(SEATS[id].size)
			(s.ring as MeshInstance3D).scale = Vector3(reach,1.0,reach)
			var fade := pow(1.0-r,1.5)*RING_ALPHA
			((s.ring as MeshInstance3D).material_override as StandardMaterial3D).albedo_color = Color(SEAT_WARM.r,SEAT_WARM.g,SEAT_WARM.b,fade)
			if r >= 1.0:
				(s.ring as Node).queue_free()
				s.ring = null
		if s.puff != null and after > PUFF_TIME+0.2:
			(s.puff as Node).queue_free()
			s.puff = null
		if not hold_glow and after >= afterglow and s.ring == null and s.puff == null:
			_glow(id,0.0,0.0)
			_seating.erase(s)
	if _lean != _lean_to:
		_lean = move_toward(_lean,_lean_to,delta/SEAT)
		if parked: transform = _parked_at*_leaning()
	if _wear != _wear_to:
		_wear = move_toward(_wear,_wear_to,delta/_wear_ease)
		_finish(_paints,_wear)
	if _gleam_t >= 0.0:
		_gleam_t += delta
		_gleam(_gleam_t/GLEAM_TIME if _gleam_t < GLEAM_TIME else -1.0)
		if _gleam_t >= GLEAM_TIME: _gleam_t = -1.0
	_set_running()

## The gleam `u` of the way from nose to tail (below 0, none): a band of
## warm light across the whole plane, along its slant, swelling and
## fading as it runs.
func _gleam(u: float) -> void:
	var on := u >= 0.0 and is_inside_tree()
	var dir := Vector3.BACK
	var at := 0.0
	var width := GLEAM_WIDTH
	if on:
		var frame := global_transform
		var slant := GLEAM_SLANT.normalized()
		dir = (frame.basis*slant).normalized()
		at = (frame*(slant*lerpf(-0.95,0.95,u))).dot(dir)
		width *= frame.basis.get_scale().x
	for paint: Material in _paints.values():
		if not paint is ShaderMaterial: continue
		var m := paint as ShaderMaterial
		m.set_shader_parameter("gleam",GLEAM*sin(PI*clampf(u,0.0,1.0)) if on else 0.0)
		if on:
			m.set_shader_parameter("gleam_dir",dir)
			m.set_shader_parameter("gleam_at",at)
			m.set_shader_parameter("gleam_width",width)

## The ease a part comes in on: past its seat a touch, and back.
static func _settle(u: float) -> float:
	var v := u-1.0
	return 1.0+(SETTLE+1.0)*v*v*v+SETTLE*v*v

## Stands part `id` `k` of the way back out along its way in (0 home).
func _pose_part(id: String, k: float) -> void:
	var seat: Dictionary = SEATS[id]
	var at: Vector3 = seat.at
	var moved := Transform3D(Basis((seat.axis as Vector3).normalized(),float(seat.turn)*k),at+(seat.from as Vector3)*k)*Transform3D(Basis.IDENTITY,-at)
	for n: Node3D in _parts[id].whole:
		var p := n.get_parent() as Node3D
		n.transform = moved if p == self else p.transform.affine_inverse()*moved*p.transform

## Part `id` on (and its damage gone), or off (the damage showing).
func _show(id: String, on: bool) -> void:
	var rec: Dictionary = _parts[id]
	for n: Node3D in rec.whole:
		n.transform = Transform3D.IDENTITY
		n.visible = on and (n.get_parent() != _prop or _blades_shown)
	for n: Node3D in rec.base: n.visible = on
	for n: Node3D in rec.broken: n.visible = not on
	if rec.flap != null: rec.flap.visible = false
	if id == "propeller": _prop.visible = on

## Part `id`'s warm glow (shaders/plane_part_glow.gdshader, as the found
## parts glow), drawn over it while there is any.
func _glow(id: String, glow: float, inner: float) -> void:
	var rec: Dictionary = _parts[id]
	var material: ShaderMaterial = rec.glow
	var lit := glow > 0.001 or inner > 0.001
	material.set_shader_parameter("glow",glow)
	material.set_shader_parameter("inner",inner)
	for n: Node3D in rec.whole:
		for m in n.get_children():
			if m is MeshInstance3D: (m as MeshInstance3D).material_overlay = material if lit else null

func _clear_seat(s: Dictionary) -> void:
	for key in ["ring","puff"]:
		if s[key] != null: (s[key] as Node).queue_free()

## The brass ring of light that spreads from a part as it seats, the found
## parts' own (scripts/facet_mesh.gd `soft_ring`), lying level through it.
func _seat_ring(id: String) -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.orientation = PlaneMesh.FACE_Y
	ring.mesh = quad
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = _ring_texture()
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(SEAT_WARM.r,SEAT_WARM.g,SEAT_WARM.b,0.0)
	ring.material_override = material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = SEATS[id].at
	add_child(ring)
	return ring

## A small puff of dust knocked off as a part seats: soft motes bursting
## out and drifting, fading as they spread.
func _seat_puff(id: String) -> CPUParticles3D:
	var size := float(SEATS[id].size)
	var puff := CPUParticles3D.new()
	puff.one_shot = true
	puff.explosiveness = 0.95
	puff.amount = PUFF
	puff.lifetime = PUFF_TIME
	puff.local_coords = true
	puff.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	puff.emission_sphere_radius = size*0.3
	puff.direction = Vector3.UP
	puff.spread = 180.0
	puff.gravity = Vector3(0.0,0.06,0.0)
	puff.initial_velocity_min = 0.25
	puff.initial_velocity_max = 0.55
	puff.damping_min = 0.6
	puff.damping_max = 0.9
	var mote := QuadMesh.new()
	mote.size = Vector2.ONE*maxf(size*0.22,0.05)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = _puff_texture()
	mote.material = material
	puff.mesh = mote
	var grow := Curve.new()
	grow.add_point(Vector2(0.0,0.45))
	grow.add_point(Vector2(1.0,1.0))
	puff.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0,0.25,1.0])
	fade.colors = PackedColorArray([Color(PUFF_DUST,0.7),Color(PUFF_DUST,0.45),Color(PUFF_DUST,0.0)])
	puff.color_ramp = fade
	puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	puff.position = SEATS[id].at
	add_child(puff)
	puff.emitting = true
	return puff

static var _ring_tex: Texture2D
static var _puff_tex: Texture2D

static func _ring_texture() -> Texture2D:
	if _ring_tex == null: _ring_tex = FacetMesh.soft_ring()
	return _ring_tex

## A soft round blob, for a mote of dust.
static func _puff_texture() -> Texture2D:
	if _puff_tex != null: return _puff_tex
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0,0.5,1.0])
	gradient.colors = PackedColorArray([Color(1,1,1,1.0),Color(1,1,1,0.5),Color(1,1,1,0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5,0.5)
	texture.fill_to = Vector2(1.0,0.5)
	texture.width = 64
	texture.height = 64
	_puff_tex = texture
	return texture

## Leaning onto the bare axle, as far as `_lean` (none, the identity).
func _leaning() -> Transform3D:
	if _lean <= 0.0: return Transform3D.IDENTITY
	var tip := _tip()
	var turn := Basis(tip[1],float(tip[2])*smoothstep(0.0,1.0,_lean))
	return Transform3D(turn,tip[0]-turn*tip[0])

static var _tip_cache := []

## [a point on the line it tips about, the line, the angle] that brings the
## lower right wingtip down to WING_CLEAR over the ground the other wheel
## and the skid stand on.
static func _tip() -> Array:
	if not _tip_cache.is_empty(): return _tip_cache
	var axis := (SKID_FOOT-LEFT_FOOT).normalized()
	var up := _ground_up()
	var p := LOW_TIP-LEFT_FOOT
	var hand := 1.0 if (Basis(axis,0.05)*p).dot(up) < p.dot(up) else -1.0
	var lo := 0.0
	var hi := 0.8
	for i in range(32):
		var mid := (lo+hi)*0.5
		if (Basis(axis,mid*hand)*p).dot(up) > WING_CLEAR: lo = mid
		else: hi = mid
	_tip_cache = [LEFT_FOOT,axis,lo*hand]
	return _tip_cache

## The ground's up, parked, in the plane's frame: square to its two wheels'
## feet and the skid's.
static func _ground_up() -> Vector3:
	var up := (RIGHT_FOOT-LEFT_FOOT).cross(SKID_FOOT-LEFT_FOOT).normalized()
	return -up if up.y < 0.0 else up

## The right gear, standing (from, to, radius): its two legs and the axle,
## as the figure builds them.
static func _gear() -> Array:
	return [[Vector3(0.07,-0.14,-0.38),Vector3(0.165,-0.33,-0.28),0.009],[Vector3(0.07,-0.14,-0.17),Vector3(0.165,-0.33,-0.28),0.009],[Vector3(-0.17,-0.33,-0.28),Vector3(0.17,-0.33,-0.28),0.008]]

## Where the folded right gear meets the grass, slumped (`_tip`): under
## where its V's foot was, on the ground as it lies leaned over.
static func _gear_foot() -> Vector3:
	var tip := _tip()
	var up: Vector3 = Basis(tip[1],float(tip[2])).inverse()*_ground_up()
	var p := GEAR_FOOT-LEFT_FOOT
	return GEAR_FOOT-up*(p.dot(up)-0.008)

## Splits the found parts off the joined meshes (`_join`, `_spans`), once,
## and builds each one apart, its damage, and what goes with it.
func _split() -> void:
	if _split_done: return
	_split_done = true
	var cut := {}
	for span: Array in _spans:
		if not cut.has(span[0]): cut[span[0]] = []
		cut[span[0]].append(span)
	for joined: MeshInstance3D in cut:
		var arrays := joined.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var keep := PackedByteArray()
		keep.resize(vertices.size())
		keep.fill(1)
		for span: Array in cut[joined]:
			for i in range(int(span[2]),int(span[2])+int(span[3])): keep[i] = 0
		var kept := PackedVector3Array()
		var facing := PackedVector3Array()
		for i in range(vertices.size()):
			if keep[i] == 0: continue
			kept.append(vertices[i])
			facing.append(normals[i])
		if kept.is_empty():
			joined.get_parent().remove_child(joined)
			joined.free()
			continue
		var into := []
		into.resize(Mesh.ARRAY_MAX)
		into[Mesh.ARRAY_VERTEX] = kept
		into[Mesh.ARRAY_NORMAL] = facing
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,into)
		joined.mesh = mesh
	_spans.clear()
	# The windscreen's glass stood apart from the join.
	for child in get_children():
		if child is MeshInstance3D and child.has_meta("piece"):
			remove_child(child)
			child.free()
	var half := SPAN*0.5
	var wing := _placed(Vector3(0.0,UPPER_Y,STAGGER),Vector3.ZERO)
	var ailerons := Vector3(half*AILERON_SPAN.x,half*AILERON_SPAN.y,_hinge_z())
	for id: String in FOUND:
		var whole := _holder("Part_"+id,self)
		var glow := ShaderMaterial.new()
		glow.shader = PART_GLOW
		glow.set_shader_parameter("tint",SEAT_WARM)
		glow.set_shader_parameter("reach",float(SEATS[id].size))
		var rec := {"whole":[whole],"base":[],"broken":[],"glow":glow,"flap":null}
		match id:
			"propeller":
				_fill(whole,piece("spinner"))
				var blades := _holder("Part_propeller_blades",_prop)
				_fill(blades,piece("propeller"))
				rec.whole.append(blades)
			"wingtip":
				# The aileron comes back on its own hinge once home; till
				# then the piece's own flies in with it.
				var parts := piece("wingtip")
				_fill(whole,parts.slice(0,parts.size()-1))
				rec.flap = _fill(whole,[parts[-1]])[0]
				var inner := _holder("Wing_inner",self)
				_fill(inner,[[_wing(half,-half*0.8,half*WINGTIP_FROM,ailerons),"cream",wing]])
				rec.base = [inner,_ailerons[1]]
			"wheel":
				# The right gear stands straight while the wheel is on; lost,
				# it is folded up (`damage`).
				_fill(whole,piece(id,1.0))
				var gear := _holder("Gear_right",self)
				var bars := []
				for g: Array in _gear(): bars.append([FacetMesh.frustum(g[2],g[2],1.0,4),"dark",_strut_at(g[0],g[1])])
				_fill(gear,bars)
				rec.base = [gear]
			_:
				_fill(whole,piece(id,1.0))
		var broken := _holder("Broken_"+id,self)
		_fill(broken,damage(id))
		broken.visible = false
		rec.broken = [broken]
		_parts[id] = rec

func _holder(holder_name: String, parent: Node3D) -> Node3D:
	var n := Node3D.new()
	n.name = holder_name
	parent.add_child(n)
	return n

## [mesh, paint name, transform] parts (as `piece` gives) drawn on `into`.
func _fill(into: Node3D, parts: Array) -> Array:
	var out := []
	for p: Array in parts:
		var m := MeshInstance3D.new()
		m.mesh = p[0]
		m.material_override = _paints[p[1]]
		m.transform = p[2]
		if p[1] == "glass" or p[1] == "crazed": m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		into.add_child(m)
		out.append(m)
	return out

## The damage part `id` leaves when it is lost, as [mesh, paint name,
## transform] parts placed as on the figure (as `piece` gives the part):
##   "propeller"   the bare shaft out of the nose, a steel flange on it with
##                 its brass bolt heads, and the splintered stumps of the
##                 blades
##   "cowl"        the engine bare: a dark firewall and crankcase,
##                 five finned cylinders round it with brass heads and
##                 rocker boxes, and their pushrods
##   "wheel"       the right gear folded up: its two legs buckled out at
##                 the knee to a foot on the grass, the axle snapped short
##                 of the middle, and the bare stub axle out of the foot,
##                 a brass collar and the nut on its end (the plane
##                 slumps onto it, `_tip`)
##   "fin"         a jagged terracotta stub of the fin and the bare rudder
##                 post, bent over at its top, its brass hinges
##   "wingtip"     the upper wing's right end: the cloth whole to the last
##                 rib, torn ragged past it, the two spars running on bare
##                 to where they snapped, a broken rib on them
##   "windscreen"  the frame bent open: the rail along the bottom, the
##                 left post standing, the right bent out, the top rail
##                 hanging off the left post; a big shard of crazed glass
##                 with a crack star in it left in the frame, and three
##                 splinters lying on the deck before it
static func damage(id: String) -> Array:
	var out := []
	match id:
		"propeller":
			out.append([FacetMesh.frustum(0.011,0.009,1.0,6),"steel",_strut_at(Vector3(0.0,0.0,-0.6),Vector3(0.0,0.0,-0.722))])
			out.append([FacetMesh.frustum(0.036,0.036,0.012,8),"steel",_placed(Vector3(0.0,0.0,-0.668),Vector3(PI*0.5,0.0,0.0))])
			for i in range(4):
				var a := TAU*(i+0.5)/4.0
				out.append([FacetMesh.gem(0.0065),"brass",_placed(Vector3(cos(a)*0.025,sin(a)*0.025,-0.676),Vector3(PI*0.5,0.0,0.0))])
			# The blades' roots, splintered off: a jagged stump each way.
			var stump := [Vector2(-0.017,0.0),Vector2(0.017,0.0),Vector2(0.015,0.052),Vector2(0.007,0.04),Vector2(0.001,0.068),Vector2(-0.006,0.047),Vector2(-0.014,0.058)]
			var short := [Vector2(-0.017,0.0),Vector2(0.017,0.0),Vector2(0.014,0.03),Vector2(0.004,0.022),Vector2(-0.003,0.036),Vector2(-0.015,0.026)]
			for k in range(2):
				var lay := Transform3D(Basis(Vector3.BACK,0.6+PI*k)*Basis(Vector3.UP,PI*0.5),Vector3(0.0,0.0,-0.68))
				out.append([_cut(stump if k == 0 else short,0.014),"varnish",lay])
		"cowl":
			out.append([_hull([Vector3(-0.478,0.13,0.136),Vector3(-0.468,0.133,0.139)],10),"dark",Transform3D.IDENTITY])
			out.append([_hull([Vector3(-0.64,0.022,0.022),Vector3(-0.625,0.045,0.045),Vector3(-0.6,0.062,0.062),Vector3(-0.53,0.064,0.064),Vector3(-0.5,0.052,0.052),Vector3(-0.47,0.05,0.05)],10),"dark",Transform3D.IDENTITY])
			for i in range(5):
				var a := PI*0.5+TAU*i/5.0
				var d := Vector3(cos(a),sin(a),0.0)
				var z := Vector3(0.0,0.0,-0.565)
				out.append([FacetMesh.frustum(0.023,0.021,1.0,8),"steel",_strut_at(z+d*0.05,z+d*0.12)])
				for k in range(4):
					var r := 0.072+0.014*k
					out.append([FacetMesh.frustum(0.033,0.033,1.0,8),"steel",_strut_at(z+d*(r-0.0022),z+d*(r+0.0022))])
				out.append([FacetMesh.frustum(0.029,0.022,1.0,8),"brass",_strut_at(z+d*0.12,z+d*0.142)])
				out.append([FacetMesh.gem(0.011),"brass",_placed(z+d*0.146+Vector3(0.0,0.0,-0.012),Vector3(0.0,0.0,a-PI*0.5))])
				out.append([FacetMesh.frustum(0.0032,0.0032,1.0,4),"steel",_strut_at(Vector3(0.0,0.0,-0.612)+d*0.05,Vector3(0.0,0.0,-0.585)+d*0.135)])
		"wheel":
			var foot := _gear_foot()
			var out_x := Vector3(1.0,-0.15,0.0).normalized()
			var gear := _gear()
			for k in range(2):
				var root: Vector3 = gear[k][0]
				var knee := (root+foot)*0.5+Vector3(0.04,-0.012,0.012*(1.0 if k == 0 else -1.0))
				out.append([FacetMesh.frustum(0.009,0.009,1.0,4),"dark",_strut_at(root,knee)])
				out.append([FacetMesh.frustum(0.009,0.008,1.0,4),"dark",_strut_at(knee,foot)])
				out.append([FacetMesh.gem(0.011),"dark",_placed(knee,Vector3.ZERO)])
			# The axle snapped short of the middle; its torn end on the foot.
			var bar: Array = gear[2]
			out.append([FacetMesh.frustum(0.008,0.006,1.0,4),"dark",_strut_at(bar[0],Vector3(0.025,-0.333,-0.28))])
			out.append([FacetMesh.frustum(0.008,0.006,1.0,4),"dark",_strut_at(foot,foot+(Vector3(0.0,-0.33,-0.28)-foot).normalized()*0.07)])
			out.append([FacetMesh.frustum(0.008,0.008,1.0,6),"steel",_strut_at(foot,foot+out_x*0.06)])
			out.append([FacetMesh.frustum(0.017,0.017,0.009,8),"brass",_placed(foot+out_x*0.028,Vector3(0.0,0.0,PI*0.5))])
			out.append([FacetMesh.gem(0.0095),"brass",_placed(foot+out_x*0.062,Vector3(0.0,0.0,PI*0.5))])
		"fin":
			var stub := [Vector2(-0.1,0.0),Vector2(0.1,0.0),Vector2(0.1,0.085),Vector2(0.075,0.068),Vector2(0.05,0.112),Vector2(0.028,0.078),Vector2(0.0,0.1),Vector2(-0.03,0.066),Vector2(-0.06,0.084),Vector2(-0.1,0.055)]
			out.append([_cut(stub,0.012),"trim",_placed(Vector3(0.0,0.03,0.58),Vector3.ZERO)])
			out.append([FacetMesh.frustum(0.0055,0.0055,1.0,5),"dark",_strut_at(Vector3(0.0,0.03,0.68),Vector3(0.0,0.17,0.684))])
			out.append([FacetMesh.frustum(0.0055,0.004,1.0,5),"dark",_strut_at(Vector3(0.0,0.17,0.684),Vector3(0.024,0.2,0.702))])
			for y: float in [0.085,0.14]: out.append([FacetMesh.gem(0.008),"brass",_placed(Vector3(0.0,y,0.682),Vector3.ZERO)])
		"wingtip":
			var half := SPAN*0.5
			var wing := _placed(Vector3(0.0,UPPER_Y,STAGGER),Vector3.ZERO)
			out.append([_wing(half,-half*0.8,TORN_RIB,Vector3(half*AILERON_SPAN.x,half*AILERON_SPAN.y,_hinge_z())),"cream",wing])
			out.append([_tatters(half),"cream",wing])
			# The spars run on bare, as the struts meet them, the rear one
			# snapped and bent down; a rib stands broken on them.
			var s := _station(half,TORN_RIB,CHORD,TIP_CHORD,THICK,RIBS)
			var y := float(s.top)*0.25
			out.append([FacetMesh.frustum(0.0062,0.005,1.0,4),"dark",wing*_strut_at(Vector3(TORN_RIB-0.012,y,-0.075),Vector3(SPARS.x,y-0.003,-0.075))])
			out.append([FacetMesh.frustum(0.0062,0.005,1.0,4),"dark",wing*_strut_at(Vector3(TORN_RIB-0.012,y,0.075),Vector3(SPARS.y,y-0.016,0.082))])
			var r := _station(half,BARE_RIB,CHORD,TIP_CHORD,THICK,RIBS)
			var rib := []
			for p: Vector2 in AIRFOIL_TOP:
				if p.x <= 0.56: rib.append(Vector2(float(r.le)+p.x*float(r.chord),p.y*float(r.top)))
			rib.append(Vector2(float(r.le)+0.64*float(r.chord),0.4*float(r.top)))
			rib.append(Vector2(float(r.le)+0.58*float(r.chord),0.1*float(r.top)))
			rib.append(Vector2(float(r.le)+0.62*float(r.chord),-0.15*float(r.under)))
			for p: Vector2 in AIRFOIL_UNDER:
				if p.x <= 0.56: rib.append(Vector2(float(r.le)+p.x*float(r.chord),p.y*float(r.under)))
			out.append([_cut(rib,0.005),"dark",wing*_placed(Vector3(BARE_RIB,0.0,0.0),Vector3.ZERO)])
		"windscreen":
			out.append([FacetMesh.frustum(0.0035,0.0035,1.0,4),"brass",_strut_at(Vector3(-0.058,0.2,0.1),Vector3(0.058,0.2,0.1))])
			out.append([FacetMesh.frustum(0.004,0.004,1.0,4),"brass",_strut_at(Vector3(-0.056,0.2,0.1),Vector3(-0.056,0.268,0.124))])
			out.append([FacetMesh.frustum(0.004,0.004,1.0,4),"brass",_strut_at(Vector3(0.056,0.2,0.1),Vector3(0.058,0.238,0.112))])
			out.append([FacetMesh.frustum(0.004,0.0035,1.0,4),"brass",_strut_at(Vector3(0.058,0.238,0.112),Vector3(0.092,0.256,0.104))])
			# The top rail, torn off the right post, hanging off the left.
			out.append([FacetMesh.frustum(0.0032,0.0032,1.0,4),"brass",_strut_at(Vector3(-0.056,0.268,0.124),Vector3(0.03,0.226,0.082))])
			# A big shard of crazed glass left in the frame, jagged across
			# its top and right, a star of cracks in it; the right of the
			# frame open.
			var shard := [Vector2(-0.056,0.0),Vector2(0.024,0.0),Vector2(0.014,0.012),Vector2(0.027,0.022),Vector2(0.006,0.031),Vector2(0.013,0.046),Vector2(-0.01,0.051),Vector2(-0.018,0.066),Vector2(-0.033,0.058),Vector2(-0.041,0.0715),Vector2(-0.056,0.0715)]
			var lean := Vector3(0.0,0.068,0.022).normalized()
			var face := lean.cross(Vector3.RIGHT)
			var screen := Transform3D(Basis(face,lean,Vector3.RIGHT),Vector3(0.0,0.2,0.1025))
			out.append([_cut(shard,0.003),"crazed",screen])
			var star := Vector2(-0.028,0.03)
			for a: float in [0.3,1.4,2.3,3.5,4.4,5.5]:
				var reach := 0.018+0.01*absf(sin(a*3.1))
				var tip := star+Vector2(cos(a),sin(a))*reach
				for side: float in [-1.0,1.0]:
					var lift := face*0.0022*side
					out.append([FacetMesh.frustum(0.0009,0.0005,1.0,3),"dark",Transform3D(Basis.IDENTITY,lift)*screen*_strut_at(Vector3(0.0,star.y,star.x),Vector3(0.0,tip.y,tip.x))])
			# Splinters of it on the deck before the cockpit.
			var splinters := [[Vector3(0.02,0.149,0.03),0.4,[Vector2(0.0,0.0),Vector2(0.022,0.004),Vector2(0.008,0.016)]],[Vector3(-0.03,0.149,0.0),1.9,[Vector2(0.0,0.0),Vector2(0.016,-0.003),Vector2(0.012,0.012),Vector2(0.002,0.009)]],[Vector3(0.045,0.146,-0.03),2.8,[Vector2(0.0,0.0),Vector2(0.014,0.002),Vector2(0.006,0.011)]]]
			for sp: Array in splinters:
				var a: float = sp[1]
				var y := Vector3(cos(a),0.0,sin(a))
				out.append([_cut(sp[2],0.0025),"crazed",Transform3D(Basis(Vector3.UP,y,Vector3.UP.cross(y)),sp[0])])
	return out

## The cloth torn past the rib at TORN_RIB on the upper wing (`half` its
## span each side): a ragged fringe of flaps off the section's upper and
## lower surfaces, reaching TEAR out with TOOTH teeth between, the upper
## flaps lifting a little and the lower drooping.
static func _tatters(half: float) -> ArrayMesh:
	var s := _station(half,TORN_RIB,CHORD,TIP_CHORD,THICK,RIBS)
	var le := float(s.le)
	var c := float(s.chord)
	var top := []
	for p: Vector2 in AIRFOIL_TOP: top.append(Vector2(le+p.x*c,p.y*float(s.top)))
	var under := [Vector2(le+c,0.0)]
	for p: Vector2 in AIRFOIL_UNDER: under.append(Vector2(le+p.x*c,p.y*float(s.under)))
	under.append(Vector2(le,0.0))
	var tris := []
	var k := 0
	for surface: Array in [[top,1.0],[under,-1.0]]:
		var line: Array = surface[0]
		var hand: float = surface[1]
		for i in range(line.size()-1):
			var a: Vector2 = line[i]
			var b: Vector2 = line[i+1]
			var la: float = TEAR[k%TEAR.size()]
			var lb: float = TEAR[(k+1)%TEAR.size()]
			var lm: float = TOOTH[k%TOOTH.size()]
			k += 1
			var sag := 0.12 if hand > 0.0 else -0.55
			var a0 := Vector3(TORN_RIB,a.y,a.x)
			var b0 := Vector3(TORN_RIB,b.y,b.x)
			var a1 := Vector3(TORN_RIB+la,a.y+la*sag,a.x)
			var b1 := Vector3(TORN_RIB+lb,b.y+lb*sag,b.x)
			var m := (a+b)*0.5
			var m1 := Vector3(TORN_RIB+lm,m.y+lm*sag,m.x+(b.x-a.x)*0.1)
			for t: Array in [[a0,b0,b1],[a0,b1,a1],[a1,b1,m1]]:
				var out := Vector3(0.0,hand,0.0)
				var mid: Vector3 = (t[0]+t[1]+t[2])/3.0
				tris.append([t[0],t[1],t[2],mid-out*0.01])
				var lower := out*-0.0012
				tris.append([t[0]+lower,t[1]+lower,t[2]+lower,mid+out*0.01])
	return FacetMesh.shell(tris)

## A flat-shaded slab along X, `width` thick and centred: `section` its
## outline in (z, y), which may be ragged (concave), as a torn edge is.
static func _cut(section: Array, width: float) -> ArrayMesh:
	var outline := PackedVector2Array(section)
	if Geometry2D.is_polygon_clockwise(outline): outline.reverse()
	var x := width*0.5
	var tris := []
	var fan := Geometry2D.triangulate_polygon(outline)
	for t in range(0,fan.size(),3):
		var a := outline[fan[t]]
		var b := outline[fan[t+1]]
		var d := outline[fan[t+2]]
		var mid := (a+b+d)/3.0
		for e: float in [-x,x]:
			tris.append([Vector3(e,a.y,a.x),Vector3(e,b.y,b.x),Vector3(e,d.y,d.x),Vector3(0.0,mid.y,mid.x)])
	for i in range(outline.size()):
		var p := outline[i]
		var q := outline[(i+1)%outline.size()]
		var along := q-p
		var out := Vector2(along.y,-along.x).normalized()
		var inside := (p+q)*0.5-out*0.001
		var inner := Vector3(0.0,inside.y,inside.x)
		tris.append([Vector3(-x,p.y,p.x),Vector3(x,p.y,p.x),Vector3(x,q.y,q.x),inner])
		tris.append([Vector3(-x,p.y,p.x),Vector3(x,q.y,q.x),Vector3(-x,q.y,q.x),inner])
	return FacetMesh.shell(tris)

# --- The pieces ---------------------------------------------------------------------

## The plane's paints by name, `livery` (see `_init`) repainting the body,
## dark, trim and wing and setting their wear (new without); the pieces
## (`piece`) name theirs from these. "crazed" is the windscreen's cracked
## glass, for its damage.
static func paints(livery := {}) -> Dictionary:
	var out := {
		"wood":_paint(livery.get("body",WOOD)),
		"dark":_paint(livery.get("dark",DARK)),
		"trim":_paint(livery.get("trim",TRIM)),
		"cream":_paint(livery.get("wing",WING)),
		"leather":_paint(LEATHER),
		"brass":_metal(BRASS,0.28),
		"steel":_metal(STEEL,0.4),
		"glass":_glass(),
		"crazed":_crazed(),
		"varnish":_paint(PROPWOOD),
	}
	_finish(out,clampf(float(livery.get("wear",0.0)),0.0,1.0))
	return out

## Puts `paint` (`paints`) at wear `t` (`set_wear`): each paint's FINISH
## between new and worn, the brass tarnishing, the glass filming over.
static func _finish(paint: Dictionary, t: float) -> void:
	for key: String in FINISH:
		if not paint.has(key): continue
		var m := paint[key] as ShaderMaterial
		var f: Array = FINISH[key]
		m.set_shader_parameter("roughness_value",lerpf(f[0],f[1],t))
		m.set_shader_parameter("coat",lerpf(f[2],f[3],t))
		m.set_shader_parameter("coat_roughness",lerpf(f[4],f[5],t))
		m.set_shader_parameter("wear",float(f[6])*t)
		m.set_shader_parameter("rim",lerpf(RIM_NEW,0.5,t))
	if paint.has("brass"):
		var brass := paint.brass as ShaderMaterial
		brass.set_shader_parameter("albedo",BRASS.lerp(TARNISH,TARNISH_SHARE*t))
		brass.set_shader_parameter("metallic_value",lerpf(BRASS_METAL.x,BRASS_METAL.y,t))
	if paint.has("glass"):
		var glass := paint.glass as StandardMaterial3D
		glass.albedo_color = Color(0.85,0.93,0.96,0.22).lerp(Color(0.8,0.79,0.72,0.45),t)
		glass.roughness = lerpf(0.03,0.45,t)

## Each paint's plain colour, for drawing a piece flat (scripts/
## plane_parts.gd's coins).
const PAINT_COLOURS := {"wood":WOOD,"dark":DARK,"trim":TRIM,"cream":WING,"leather":LEATHER,"brass":BRASS,"steel":STEEL,"glass":Color(0.78,0.88,0.92),"crazed":Color(0.9,0.93,0.92),"varnish":PROPWOOD}

## One of the plane's pieces, as [mesh, paint name (`paints`), transform]
## parts placed as on the figure: "cowl" (the terracotta ring round the
## nose, its brass lip and dark face, the rivets, louvres and exhaust
## stacks), "spinner", "propeller" (in the propeller's own frame, its hub at
## the origin), "windscreen" (glass in a brass frame), "wheel" (`side` -1
## the left, 1 the right), "fin" (the terracotta fin and cream rudder) and
## "wingtip" (the upper wing's right tip with its roundel and aileron; the
## figure draws that as part of the whole wing). The figure is built from
## these, and the found parts are too (scripts/plane_parts.gd), so a found
## part matches the plane it goes back on.
static func piece(id: String, side := 1.0) -> Array:
	var out := []
	match id:
		"cowl":
			out.append([_hull([Vector3(-0.62,0.1,0.1),Vector3(-0.6,0.125,0.125),Vector3(-0.55,0.14,0.145),Vector3(-0.47,0.143,0.149),Vector3(-0.44,0.139,0.146)],12),"trim",Transform3D.IDENTITY])
			out.append([FacetMesh.frustum(0.102,0.102,0.006,12),"brass",_placed(Vector3(0.0,0.0,-0.619),Vector3(PI*0.5,0.0,0.0))])
			out.append([FacetMesh.frustum(0.082,0.082,0.006,12),"steel",_placed(Vector3(0.0,0.0,-0.623),Vector3(PI*0.5,0.0,0.0))])
			# A seam of rivets where the cowl meets the body, louvres let
			# into its sides, and the exhaust stacks bent back into a pipe
			# along each side.
			for i in range(14):
				var a := TAU*(float(i)+0.5)/14.0
				out.append([FacetMesh.gem(0.0055),"brass",_placed(Vector3(cos(a)*0.141,sin(a)*0.148,-0.452),Vector3.ZERO)])
			for hand: float in [-1.0,1.0]:
				for i in range(4):
					out.append([_hull([Vector3(-0.035,0.0045,0.0045),Vector3(0.035,0.0045,0.0045)],4),"steel",_placed(Vector3(0.139*hand,0.042-0.026*i,-0.505),Vector3.ZERO)])
				for i in range(3):
					var z := -0.56+0.045*i
					out.append([FacetMesh.frustum(0.009,0.009,1.0,4),"steel",_strut_at(Vector3(0.12*hand,-0.05,z),Vector3(0.168*hand,-0.075,z+0.03))])
				out.append([FacetMesh.frustum(0.011,0.011,1.0,4),"steel",_strut_at(Vector3(0.168*hand,-0.075,-0.53),Vector3(0.152*hand,-0.098,-0.22))])
		"spinner":
			out.append([_hull([Vector3(-0.76,0.0,0.0),Vector3(-0.73,0.03,0.03),Vector3(-0.67,0.052,0.052),Vector3(-0.63,0.056,0.056)],8),"brass",Transform3D.IDENTITY])
		"propeller":
			# Two varnished wooden blades, brass-sheathed at the tips.
			for turn: float in [0.0,PI]:
				var lay := Transform3D(Basis(Vector3.BACK,turn)*Basis(Vector3.UP,0.32)*Basis(Vector3.RIGHT,-PI*0.5),Vector3.ZERO)
				out.append([_hull([Vector3(0.0,0.012,0.009),Vector3(0.04,0.026,0.008),Vector3(0.16,0.024,0.006),Vector3(0.235,0.017,0.005)],6),"varnish",lay])
				out.append([_hull([Vector3(0.232,0.0175,0.0055),Vector3(0.262,0.012,0.0045),Vector3(0.27,0.004,0.003)],6),"brass",lay])
		"windscreen":
			out.append([_prism([Vector2(0.0,0.0),Vector2(0.005,0.0),Vector2(0.027,0.068),Vector2(0.022,0.068)],0.11),"glass",_placed(Vector3(0.0,0.2,0.1),Vector3.ZERO)])
			for hand: float in [-1.0,1.0]: out.append([FacetMesh.frustum(0.004,0.004,1.0,4),"brass",_strut_at(Vector3(0.056*hand,0.2,0.1),Vector3(0.056*hand,0.268,0.124))])
			out.append([FacetMesh.frustum(0.003,0.003,1.0,4),"brass",_strut_at(Vector3(-0.056,0.268,0.124),Vector3(0.056,0.268,0.124))])
		"wheel":
			# The spokes covered in cream, a brass hub.
			out.append([FacetMesh.frustum(0.08,0.08,0.038,14),"steel",_placed(Vector3(0.2*side,-0.33,-0.28),Vector3(0.0,0.0,PI*0.5))])
			out.append([FacetMesh.frustum(0.058,0.058,0.044,14),"cream",_placed(Vector3(0.2*side,-0.33,-0.28),Vector3(0.0,0.0,PI*0.5))])
			out.append([FacetMesh.frustum(0.02,0.014,0.06,8),"brass",_placed(Vector3(0.21*side,-0.33,-0.28),Vector3(0.0,0.0,PI*0.5))])
		"fin":
			out.append([_prism([Vector2(-0.1,0.0),Vector2(0.1,0.0),Vector2(0.1,0.2),Vector2(0.065,0.24),Vector2(0.02,0.25),Vector2(-0.03,0.2)],0.012),"trim",_placed(Vector3(0.0,0.03,0.58),Vector3.ZERO)])
			out.append([_prism([Vector2(0.1,-0.04),Vector2(0.15,-0.04),Vector2(0.165,0.1),Vector2(0.145,0.19),Vector2(0.1,0.2)],0.01),"cream",_placed(Vector3(0.0,0.03,0.58),Vector3.ZERO)])
		"wingtip":
			# The upper wing from WINGTIP_FROM out: the cloth cut back for
			# the aileron, the terracotta tip, the roundel and the aileron.
			var half := SPAN*0.5
			var rounded := half*0.8
			var ailerons := Vector3(half*AILERON_SPAN.x,half*AILERON_SPAN.y,_hinge_z())
			var wing := _placed(Vector3(0.0,UPPER_Y,STAGGER),Vector3.ZERO)
			out.append([_wing(half,half*WINGTIP_FROM,rounded,ailerons),"cream",wing])
			out.append([_wing(half,rounded,half),"trim",wing])
			var at := Vector2(SPAN*0.3,-CHORD*0.5+0.42*_chord_at(half,SPAN*0.3))
			var rings := [[0.062,"dark"],[0.046,"trim"],[0.018,"cream"]]
			for k in range(rings.size()):
				out.append([_decal(half,at,float(rings[k][0]),0.0015+0.0005*k),rings[k][1],wing])
			var flap := _scaled(_prism([Vector2(0.0,0.006),Vector2(AILERON_DEPTH,-0.001),Vector2(0.0,-0.006)]),Vector3(ailerons.y-ailerons.x-0.004,1.0,1.0))
			out.append([flap,"cream",_placed(Vector3((ailerons.x+ailerons.y)*0.5,UPPER_Y+0.004,STAGGER+ailerons.z),Vector3.ZERO)])
	return out

## A part at `at`, turned by `turn` (Euler angles, as Node3D.rotation).
static func _placed(at: Vector3, turn: Vector3) -> Transform3D:
	return Transform3D(Basis.from_euler(turn),at)

# --- Building -----------------------------------------------------------------------

## Paint, lit as the folk are (shaders/folk_surface.gdshader), under a
## clear coat; its finish is set by its wear (`_finish`).
static func _paint(color: Color) -> ShaderMaterial:
	return PersonKit._lacquer(color,0.3,0.8)

static func _metal(color: Color, roughness: float) -> ShaderMaterial:
	return PersonKit._metal(color,roughness)

## The windscreen: faint, clear and sharp-shining.
static func _glass() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.85,0.93,0.96,0.22)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.03
	m.metallic = 0.3
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

## The windscreen cracked: crazed safety glass, milky and catching the
## light, so a broken screen reads from across the field.
static func _crazed() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.9,0.94,0.94,0.62)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.3
	m.metallic = 0.1
	m.rim_enabled = true
	m.rim = 0.6
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

## A fixed part on `parent` (the figure if null), joined with the rest of
## its material's by `_join`.
func _add(mesh: Mesh, material: Material, at: Vector3, turn: Vector3, parent: Node3D = null) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = at
	part.rotation = turn
	part.set_meta("join",true)
	(parent if parent != null else self).add_child(part)
	return part

## A thin strut (or, `radius` finer, a wire) from `from` to `to`.
func _strut(from: Vector3, to: Vector3, material: Material, radius := 0.014) -> MeshInstance3D:
	var part := _add(FacetMesh.frustum(radius,radius,1.0,4),material,Vector3.ZERO,Vector3.ZERO)
	part.transform = _strut_at(from,to)
	return part

## Where a strut from `from` to `to` stands: a unit frustum along Y
## stretched and turned onto the line.
static func _strut_at(from: Vector3, to: Vector3) -> Transform3D:
	var y := (to-from)
	var x := y.cross(Vector3.FORWARD if absf(y.normalized().dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	return Transform3D(Basis(x,y,x.cross(y.normalized()).normalized()),(from+to)*0.5)

## A piece's parts (`piece`) added as fixed parts on `parent`, in `paint`.
## The windscreen's glass casts no shadow and stays out of the join.
##
## Each is tagged with the found part it belongs to (the spinner goes with
## the propeller; only the right wheel is ever lost), for `_split`.
func _add_piece(id: String, paint: Dictionary, parent: Node3D = null, side := 1.0) -> void:
	for p: Array in piece(id,side):
		var part := _add(p[0],paint[p[1]],Vector3.ZERO,Vector3.ZERO,parent)
		part.transform = p[2]
		if not (id == "wheel" and side < 0.0): part.set_meta("piece","propeller" if id == "spinner" else id)
		if p[1] == "glass":
			part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			part.remove_meta("join")

## Joins `parent`'s fixed parts (`_add`'s) into one mesh for each material,
## that of `first` first among its children, noting where each tagged
## part's triangles land (`_spans`).
func _join(parent: Node3D, first: Material) -> void:
	var groups := {}
	var spans := []
	for child in parent.get_children():
		if not (child is MeshInstance3D and child.has_meta("join")): continue
		var part := child as MeshInstance3D
		var material := part.material_override
		if not groups.has(material): groups[material] = [PackedVector3Array(),PackedVector3Array()]
		var into: PackedVector3Array = groups[material][0]
		var facing: PackedVector3Array = groups[material][1]
		var arrays := part.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: Variant = arrays[Mesh.ARRAY_INDEX]
		var placed := part.transform
		var turn := placed.basis.inverse().transposed()
		var order: Variant = indices if indices is PackedInt32Array and (indices as PackedInt32Array).size() > 0 else range(vertices.size())
		if part.has_meta("piece"): spans.append([material,part.get_meta("piece"),into.size(),order.size()])
		for i: int in order:
			into.append(placed*vertices[i])
			facing.append((turn*normals[i]).normalized())
		groups[material] = [into,facing]
		parent.remove_child(part)
		part.free()
	for material: Material in groups:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = groups[material][0]
		arrays[Mesh.ARRAY_NORMAL] = groups[material][1]
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var joined := MeshInstance3D.new()
		joined.mesh = mesh
		joined.material_override = material
		parent.add_child(joined)
		if material == first: parent.move_child(joined,0)
		for span: Array in spans:
			if span[0] == material: _spans.append([joined,span[1],span[2],span[3]])

# --- The wings ------------------------------------------------------------------------

## A wing's chord `x` m out along a wing of `half` span each side.
static func _chord_at(half: float, x: float, root := CHORD, tip := TIP_CHORD) -> float:
	return lerpf(root,tip,minf(absf(x)/(half*ROUND),1.0))

## Where the ailerons hinge, along the upper wing's chord from its middle.
static func _hinge_z() -> float:
	return -CHORD*0.5+_chord_at(SPAN*0.5,SPAN*0.5*(AILERON_SPAN.x+AILERON_SPAN.y)*0.5)-AILERON_DEPTH

## A wing's section `x` m out: its leading edge (z), chord, the scale of
## its upper and lower surface (m, sagging between the ribs) and where its
## trailing edge is cut back for an aileron (z). Past ROUND the tip rounds
## off, the chord and the thickness closing in an ellipse.
static func _station(half: float, x: float, root: float, tip: float, thick: float, ribs: int, cut := Vector3.ZERO) -> Dictionary:
	var a := absf(x)
	var edge := half*ROUND
	var le := -root*0.5
	var c := _chord_at(half,a,root,tip)
	var size := 1.0
	var top := 1.0
	var under := 1.0
	if a > edge:
		var q := clampf((a-edge)/(half-edge),0.0,1.0)
		var e := maxf(sqrt(maxf(1.0-q*q,0.0)),0.12)
		var mid := le+tip*0.5
		c = tip*e
		le = mid-c*0.5
		size = maxf(e,0.3)
	else:
		var bay := half/ribs
		var between := 1.0-absf(2.0*fposmod(a,bay)/bay-1.0)
		top -= SAG*between
		under -= SAG_UNDER*between
	var stop := INF
	if cut != Vector3.ZERO and a > cut.x and a < cut.y: stop = cut.z
	var t := thick*AIRFOIL_SCALE*size
	return {"le":le,"chord":c,"top":t*top,"under":t*under,"stop":stop}

## The section's outline as (z, y), the upper surface back, the lower forward.
static func _section(s: Dictionary) -> Array:
	var out := []
	for p: Vector2 in AIRFOIL_TOP: out.append(Vector2(minf(s.le+p.x*s.chord,s.stop),p.y*s.top))
	for p: Vector2 in AIRFOIL_UNDER: out.append(Vector2(minf(s.le+p.x*s.chord,s.stop),p.y*s.under))
	return out

## A wing of `half` span each side, the piece from `from` to `to` m out
## (negative to the left): an airfoil in section, tapering from `root` to
## `tip` chord and rounded at the tips, `thick` deep, its cloth drawn over
## `ribs` ribs each side and sagging between them, so each rib is a crease
## in the light. `cut` (out from, out to, z) cuts the trailing edge back to
## z between those for the ailerons.
static func _wing(half: float, from: float, to: float, cut := Vector3.ZERO, root := CHORD, tip := TIP_CHORD, thick := THICK, ribs := RIBS) -> ArrayMesh:
	var edge := half*ROUND
	var xs := [from,to]
	for k in range(-ribs*2,ribs*2+1):
		var x := half/ribs*k*0.5
		if absf(x) < edge: xs.append(x)
	for q in [0.0,0.4,0.7,0.88,0.97,1.0]:
		for hand in [-1.0,1.0]: xs.append(hand*(edge+(half-edge)*q))
	if cut != Vector3.ZERO:
		for e in [cut.x,cut.y]:
			for hand in [-1.0,1.0]:
				xs.append(hand*e-0.0005)
				xs.append(hand*e+0.0005)
	xs = xs.filter(func(x: float) -> bool: return x >= from-1e-6 and x <= to+1e-6)
	xs.sort()
	var stations := []
	for x: float in xs:
		if stations.is_empty() or x-float(stations[-1]) > 1e-5: stations.append(x)
	var tris := []
	var before := []
	var before_mid := Vector3.ZERO
	for i in range(stations.size()):
		var x: float = stations[i]
		var s := _station(half,x,root,tip,thick,ribs,cut)
		var points := []
		for p: Vector2 in _section(s): points.append(Vector3(x,p.y,p.x))
		var mid := Vector3(x,(s.top-s.under)*0.1,s.le+s.chord*0.35)
		var n := points.size()
		if i == 0 or i == stations.size()-1:
			var inward := Vector3(0.001 if i == 0 else -0.001,0.0,0.0)
			for k in range(n): tris.append([mid,points[k],points[(k+1)%n],mid+inward])
		if i > 0:
			var inside := (mid+before_mid)*0.5
			for k in range(n):
				var a0: Vector3 = before[k]
				var a1: Vector3 = before[(k+1)%n]
				var b0: Vector3 = points[k]
				var b1: Vector3 = points[(k+1)%n]
				tris.append([a0,b0,b1,inside])
				tris.append([a0,b1,a1,inside])
		before = points
		before_mid = mid
	return FacetMesh.shell(tris)

## The upper wing's top at (x, z), sagging between its ribs as the cloth.
static func _on_top(half: float, at: Vector2) -> Vector3:
	var s := _station(half,at.x,CHORD,TIP_CHORD,THICK,RIBS)
	var u := clampf((at.y-float(s.le))/float(s.chord),0.0,1.0)
	var v := 0.0
	for k in range(AIRFOIL_TOP.size()-1):
		var p: Vector2 = AIRFOIL_TOP[k]
		var q: Vector2 = AIRFOIL_TOP[k+1]
		if u >= p.x and u <= q.x:
			v = lerpf(p.y,q.y,(u-p.x)/maxf(q.x-p.x,1e-6))
			break
	return Vector3(at.x,v*float(s.top),at.y)

## A painted disc of `radius` on the upper wing's top at `at` (x, z),
## `lift` m over the cloth.
static func _decal(half: float, at: Vector2, radius: float, lift: float) -> ArrayMesh:
	var tris := []
	var n := 20
	var centre := _on_top(half,at)+Vector3.UP*lift
	for i in range(n):
		var a0 := TAU*i/n
		var a1 := TAU*(i+1)/n
		var p0 := _on_top(half,at+Vector2(cos(a0),sin(a0))*radius)+Vector3.UP*lift
		var p1 := _on_top(half,at+Vector2(cos(a1),sin(a1))*radius)+Vector3.UP*lift
		tris.append([centre,p0,p1,centre+Vector3.DOWN*0.01])
	return FacetMesh.shell(tris)

## A copy of `mesh` stretched by `by`, its normals kept flat.
static func _scaled(mesh: ArrayMesh, by: Vector3) -> ArrayMesh:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i in range(vertices.size()):
		vertices[i] *= by
		normals[i] = (normals[i]/by).normalized()
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return out

## A flat-shaded body along Z (scripts/facet_mesh.gd `hull`).
static func _hull(rings: Array, sides: int) -> ArrayMesh:
	return FacetMesh.hull(rings,sides)

## A flat-shaded prism along X, from -0.5 to 0.5: `section` is its outline
## in (z, y), convex. With `width` it runs along X only that wide.
static func _prism(section: Array, width := 1.0) -> ArrayMesh:
	var tris := []
	var x := width*0.5
	var mid := Vector2.ZERO
	for p: Vector2 in section: mid += p
	mid /= section.size()
	var inside := Vector3(0.0,mid.y,mid.x)
	for i in range(section.size()):
		var p: Vector2 = section[i]
		var q: Vector2 = section[(i+1)%section.size()]
		tris.append([Vector3(-x,p.y,p.x),Vector3(x,p.y,p.x),Vector3(x,q.y,q.x),inside])
		tris.append([Vector3(-x,p.y,p.x),Vector3(x,q.y,q.x),Vector3(-x,q.y,q.x),inside])
		for e in [-x,x]:
			tris.append([Vector3(e,mid.y,mid.x),Vector3(e,p.y,p.x),Vector3(e,q.y,q.x),Vector3(0.0,mid.y,mid.x)])
	return _shell(tris)

## Triangles as a flat-shaded mesh (scripts/facet_mesh.gd `shell`).
static func _shell(tris: Array) -> ArrayMesh:
	return FacetMesh.shell(tris)
