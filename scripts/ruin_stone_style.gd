extends RefCounted
## The ruin stone's look (scripts/ruin_kit.gd and its families): how a
## block's faces are coloured and how much the weathering cuts into them,
## switchable, so the directions can be judged on the same pieces
## (docs/scenic/ruin-stone.md). The pieces' plans, silhouettes and breaks
## are the same in every look: the kit draws the same random numbers
## whichever look is on, and only what it does with the surface differs.
##
##   classic   the kit as it was: charcoal blocks each a tone of its own,
##             faces a step apart, worn arrises, chips, stains in bands,
##             lichen, moss patches on the tops, faces out of true.
##   ashlar    big calm blocks: the coursed stones read in groups a few
##             metres long, each group one tone; no wear, no stains, no
##             chips; mid warm grey.
##   mass      the islands' rule: no block reads at all; a wall is one cut
##             mass in a pale warm stone, banded by height as the plate's
##             strata are and lit facet by facet (each face's tone from its
##             facing only, as the earth sides' `side_facets`).
##   basalt    THE LOOK (the default, chosen 2026-10-09): the sky islets'
##             rock (scripts/rock_looks.gd): the mass's rule in the islets'
##             dark, nearly neutral stone, its facets parting more, and its
##             blocks carved (CARVE): broad facets on the open arrises (the
##             steps' lips, the corners) and a crease or two across big open
##             faces, so the ruins read as cut from the islets' rock.
##
## A clean look (any but classic) also builds without the worn arrises and
## the cuts of the weathering, keeps the blocks true and flush, and so
## draws far fewer triangles; its collision is its uncut block (the carving
## is drawn only, a few centimetres at most into a top).
##   RuinStoneStyle.use("mass")   before building; the gallery's T key and
##   --stone= flag (studies/ruin_kit_gallery.gd, studies/aqueduct_isle.gd).

const ORDER := ["classic","ashlar","mass","basalt"]
const NAMES := {"classic":"classic stone","ashlar":"big ashlar","mass":"carved mass","basalt":"islet basalt"}

## Each look (colours sRGB):
##   stone, cool   the two stones a piece is between (`vary` of the way
##                 from its seed);
##   facets        how far a face's tone moves by its facing (a share,
##                 half either way; the plate's sides 0.14, the islets' 0.45);
##   block         how far a group of blocks' tone moves (half either way);
##   cell          a group's size (m: along, up), its rows staggered;
##   band          the height bands (m; 0 none) and how far apart they
##                 stand (`band_tone`, alternating);
##   foot, rise    the foot darker by this share, lightening over `rise` m;
##   under         undersides' share;
##   recess        a part built darker than its stone (a niche's back)
##                 keeps this share;
##   true_off      the blocks' tilt and shift out of true (share of the
##                 classic's);
##   depth         the coursed stones' faces in and out (share);
##   sag           the courses' sag (share);
##   fill, rim     the stone material's hemisphere fill and sky rim;
##   facet_hash    upright faces' tone by the islets' own rule (the earth
##                 sides' `side_facets`: a hash of the facing in 40 steps,
##                 so faces even a little apart part clearly), not the
##                 smooth one. Tried on basalt and left off: on coursed
##                 walls it parts stone from stone again (a checker).
## A carved look's facets on its blocks' open arrises (RuinKit Build
## `_carve`): the odds a top's edge or an upright corner is cut, how deep
## (m, at least and at most), at most this share of the block's least
## size, the same along a stretch this long (m).
## The creases across open faces (bigger than `crease_area` m²), laid out
## by `stretch` along each face's plane: the odds a stretch has one, how far
## the face past it turns (degrees), and its deepest at the stretch's end
## (m: a top's, an upright face's). Lean stone (the halls) carves `lean`
## as often, for the halls' triangle budget.
const CARVE := {"edge":0.6,"corner":0.7,"edge_depth":Vector2(0.06,0.14),"corner_depth":Vector2(0.1,0.26),"share":0.3,"stretch":2.4,
	"crease":0.85,"crease_area":0.12,"crease_angle":Vector2(7.0,13.0),"crease_flat":0.035,"crease_side":0.16,"lean":0.5}
const LOOKS := {
	"classic": {"fill":1.2,"rim":0.14},
	"ashlar": {"stone":Color("7a7268"),"cool":Color("6f7176"),"vary":0.35,"facets":0.18,"top":0.25,"block":0.09,"cell":Vector2(3.2,1.25),
		"band":0.0,"band_tone":0.0,"foot":0.14,"rise":2.2,"under":0.8,"recess":0.72,"true_off":0.2,"depth":0.0,"sag":0.3,"fill":1.3,"rim":0.14},
	"mass": {"stone":Color("9e9586"),"cool":Color("96958f"),"vary":0.3,"facets":0.24,"top":0.25,"block":0.0,"cell":Vector2.ZERO,
		"band":1.25,"band_tone":0.045,"foot":0.18,"rise":3.0,"under":0.78,"recess":0.7,"true_off":0.0,"depth":0.0,"sag":0.0,"fill":1.3,"rim":0.12},
	"basalt": {"stone":Color("5a5d63"),"cool":Color("52575f"),"vary":0.5,"facets":0.42,"top":0.3,"carve":CARVE,"facet_hash":false,"block":0.0,"cell":Vector2.ZERO,
		"band":1.6,"band_tone":0.06,"foot":0.12,"rise":3.0,"under":0.8,"recess":0.7,"true_off":0.0,"depth":0.0,"sag":0.0,"fill":1.45,"rim":0.2},
}

## The look the kit builds with now.
static var current := "basalt"

## Builds from now on in look `id` (one of ORDER); sets the shared stone
## material's fill to it. Built ruins keep the look they were built in.
static func use(id: String) -> void:
	current = id if LOOKS.has(id) else "classic"

## Whether the look is a clean one (no wear cut, faces coloured by rule).
static func clean() -> bool:
	return current != "classic"

## A setting of the current look.
static func get_value(key: String) -> Variant:
	return (LOOKS[current] as Dictionary).get(key)

## The look's next in ORDER.
static func next(id: String) -> String:
	return ORDER[(ORDER.find(id)+1)%ORDER.size()]

## The stone material set for the current look.
static func dress(material: ShaderMaterial) -> void:
	var look: Dictionary = LOOKS[current]
	material.set_shader_parameter("fill",float(look.fill))
	material.set_shader_parameter("rim",float(look.rim))

## The piece's stone (sRGB) in a clean look, from its seed.
static func stone_of(seed_value: int) -> Color:
	var look: Dictionary = LOOKS[current]
	var t := float(hash([seed_value,"stone look"]) % 1000)/1000.0*float(look.vary)
	return (look.stone as Color).lerp(look.cool,t)

## A face's colour (linear) in a clean look: the piece's stone, its
## block group's tone (by the block's middle `centre`), its height band
## and the foot's dark (by the face's middle `at`), its facing's step, the
## undersides darker; `part` the share the kit built the part darker or
## lighter than its stone (a niche's back under 0.8 stays dark).
static func shade(stone: Color, centre: Vector3, at: Vector3, normal: Vector3, part: float) -> Color:
	var look: Dictionary = LOOKS[current]
	var c := stone
	var block: float = look.block
	if block > 0.0:
		var cell: Vector2 = look.cell
		var row := floorf(centre.y/cell.y)
		var stagger := 0.5*cell.x*fposmod(row,2.0)
		var key := Vector3i(int(floorf((centre.x+stagger)/cell.x)),int(row),int(floorf((centre.z+stagger)/cell.x)))
		c *= 1.0+(_unit(hash(key))-0.5)*block*2.0
	var band: float = look.band
	if band > 0.0:
		var k := floori(at.y/band)
		c *= 1.0+float(look.band_tone)*(1.0 if k%2 == 0 else -1.0)
	c *= 1.0-float(look.foot)*(1.0-smoothstep(0.0,float(look.rise),at.y))
	# The face's step by its facing alone (the earth sides' rule), so flush
	# faces of neighbouring blocks read as one plane; a smooth function of
	# the facing, so a block settled a little off true keeps its
	# neighbours' tone and only a face cut another way parts from them.
	# Every top (a slab, a wall head, a tread) is one tone: a roof reads
	# whole, not as a patchwork.
	if normal.y > 0.85:
		# A top barely tipped (a carved look's crease) still parts from
		# its neighbour: lighter tipped toward the light's side, darker away.
		var tip := clampf(Vector2(normal.x,normal.z).dot(Vector2(-0.55,0.83))/0.06,-1.0,1.0)
		c *= 1.0+float(look.facets)*(float(look.top)+0.3*tip)
	elif look.get("facet_hash",false):
		var facet := Vector3i((normal.abs()*40.0).floor())
		c *= 1.0+(_unit(hash(facet))-0.5)*float(look.facets)
	else: c *= 1.0+_facing(normal)*float(look.facets)
	if normal.y < -0.3: c *= float(look.under)
	if part < 0.8: c *= float(look.recess)
	var linear := Color(c.r,c.g,c.b).srgb_to_linear()
	return Color(linear.r,linear.g,linear.b,1.0)

## A smooth tone (-0.5 to 0.5) by facing: faces a few degrees apart a
## shade apart, faces cut across each other well apart.
static func _facing(n: Vector3) -> float:
	var a := atan2(n.z,n.x)
	return clampf(0.32*sin(a*3.0+0.7)+0.18*sin(a*5.0+2.3)+0.25*(n.y),-0.5,0.5)

## Whether the current look carves its blocks' open arrises (`carve`).
static func carves() -> bool:
	return current != "classic" and (LOOKS[current] as Dictionary).has("carve")

## A hash as a share, 0 to 1.
static func unit(h: int) -> float:
	return _unit(h)

static func _unit(h: int) -> float:
	return float(posmod(h,10007))/10007.0
