extends RefCounted
## Kind `curtain`: a sheet that falls over a lip, which the plane punches
## through, with a space behind it (docs/design/endless-flight/
## spec-wild-kit-falls.md). No skin of its own: the kind keeps the sheet's
## shape, the punch and the space behind; a skin (SKINS) says what falls and
## dresses it (the wilderness's waterfall: scripts/endless/world/wilderness/
## waterfall.gd; later a sand fall, an ice curtain, hanging moss).
##
## The land under it is the kind's too (curtain_land.gd, a layer over the
## land field keyed to the site): an alcove cut back into the slope to a face
## `back` m behind the foot, the lip on its top edge `lip` m over the foot, a
## pool at its foot, a stream over the lip from a tarn behind. A curtain
## names its foot's height (params.y): the land under it is its own to cut.
##
## Params (m; curtain_land.gd has the defaults): y, back, lip, half_back,
## half_front, pool_r, pool_depth, tarn (Vector3: s, f, radius), tarn_over_lip,
## lip_half (the stream's half-width at the lip: the sheet's), out_f, out_under,
## throw (the sheet's speed off the lip, m/s).

const Land = preload("res://scripts/endless/kinds/curtain_land.gd")
const SKINS := {
	"waterfall": preload("res://scripts/endless/world/wilderness/waterfall.gd"),
}
const THROW := 2.0

static func build(site: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Curtain"
	var sheet := sheet_of(site)
	var skin := str(site.get("skin",""))
	if SKINS.has(skin): (SKINS[skin] as GDScript).dress(root,sheet,site)
	return root

## The sheet in the piece's own frame (origin the foot, -Z its heading): {lip
## (the lip's middle, at the water), out (the way it falls away from the
## face), drop (lip to the pool's water), half (its half-width at the lip),
## throw, pool (the pool's middle on its water), pool_r, back}.
static func sheet_of(site: Dictionary) -> Dictionary:
	var c := Land.shape_of(site,site.xform)
	var foot_y := c[Land.I_Y]
	var back := c[Land.I_BACK]
	var lip := Vector3(0.0,c[Land.I_LIP]-foot_y,back)
	var pool := Vector3(0.0,c[Land.I_POOL_Y]-foot_y,-c[Land.I_POOL_F])
	return {"lip":lip,"out":Vector3.FORWARD,"drop":c[Land.I_LIP]-c[Land.I_POOL_Y],"half":c[Land.I_LIP_HALF]*0.85,
		"throw":float((site.params as Dictionary).get("throw",THROW)),"pool":pool,"pool_r":c[Land.I_POOL_R],"back":back}
