extends RefCounted
## What the shop sells (docs/design/endless-flight/spec-wild-loop.md, lane
## `shop`), and putting what is worn on the plane. A first stock, kept easy
## to change: an item is one row of ITEMS, its slot one of SLOTS. Prices are
## set against the pay (PilotBook `line_pay`, BeatRoutes' money; trunk 1):
## decent flying earns about 5-7 a minute, a wild line 30 or more, so the
## first paint (60) comes in about ten minutes, a ribbon (40-70) in five to
## ten, and the dearest paint (180) in about half an hour.
##
## Slots, each with its free first item (had by everyone, worn when the
## book names none):
##   paint   the plane's livery: body, dark, trim and wing colours
##           (PlaneFigure `repaint`'s keys), repainted in place
##   ribbon  a streamer off the rudder's top, two colours: nothing on the
##           flight, only to look at
## The book (PilotBook) keeps owned ids and the worn id per slot.
##
## Skins (docs/design/endless-flight/spec-skins.md, "The contract"): a paint
## row may carry more than its livery:
##   rarity  common, uncommon, rare or legendary (RARITIES), shown in the list
##   finish  how the paint shines: {sheen: a SHEENS name, pearl: Color,
##           pearl_amount, glow: Color, glow_on: [slots], glow_power}
##           (`finish_values`; PlaneFigure `refinish`); glow_on may name
##           "decal" too: the decal lit in its own colours
##   decal   a texture's path (res://assets/models/hero_plane/skins/<batch>/),
##           marks over the paint in the atlas's UV, made by the decal painter
##           (art/blender/hero_plane/hero_plane_decal.py); loaded only while
##           worn or tried
##   bake    the skin's own atlas maps, {albedo, mask, orm: a texture's path},
##           any left out the plane's own (the normal is shared), made by the
##           bake maker (art/blender/hero_plane/hero_plane_bake.py); loaded
##           only while worn or tried
## Paints beyond the first seven come in batches, one file each under
## scripts/endless/skins/ (its `SKINS`, rows as ITEMS'), gathered from
## BATCHES: a new batch is one line there.


const SLOTS := ["paint","ribbon"]
## Each slot's heading in the shop.
const SLOT_NAMES := {"paint":"Paints","ribbon":"Ribbons"}

## The skin batches, each a script with `const SKINS := [rows]`.
const BATCHES := [
	"res://scripts/endless/skins/demo.gd",
]

const RARITIES := ["common","uncommon","rare","legendary"]
## Each rarity's colour in the shop's list.
const RARITY_COLOURS := {"common":Color("c9c2b3"),"uncommon":Color("8fc7a0"),"rare":Color("8fb4e8"),"legendary":Color("f0a860")}

## The finish's sheens: the paint's roughness, clearcoat and metal
## (PlaneFigure HERO_FINISH's names), each told apart on the sheet
## (tools/skin_sheet.py sheen:NAME@id). satin is the atlas's own; gloss a
## deepened colour under a lacquer, white edge-on with a streak of light
## along the fuselage; matte greyed, chalky and flat, no highlight at all;
## metal a hard mirror in the paint's hue, bright sky over dark land with a
## sharp horizon down the round body.
const SHEENS := {
	"satin":{},
	"gloss":{"finish_rough":0.15,"finish_coat":1.0,"finish_sheen":1.0},
	"matte":{"finish_rough":0.92,"finish_coat":0.0,"finish_chalk":1.0},
	"metal":{"finish_rough":0.2,"finish_coat":0.2,"finish_metal":1.0},
}
## The maps a bake may swap (PlaneFigure HERO_ATLAS, without "_tex").
const BAKE_MAPS := ["albedo","mask","orm"]
## The slots a glow can light, in glow_slots' order.
const GLOW_SLOTS := ["body","trim","wing","dark"]

## The base stock; the batches' skins follow (`items`).
const ITEMS := [
	# The wanderer's own: terracotta, teal and cream (PlaneFigure's defaults).
	{"id":"paint/home","slot":"paint","rarity":"common","name":"Homestead","price":0,
		"livery":{"body":Color("b9583b"),"dark":Color("2f4a4f"),"trim":Color("2f6670"),"wing":Color("ece2c8")}},
	{"id":"paint/harbour","slot":"paint","rarity":"common","name":"Harbour","price":60,
		"livery":{"body":Color("3f6e8c"),"dark":Color("26394a"),"trim":Color("e8d9a8"),"wing":Color("eef0ea")}},
	{"id":"paint/moss","slot":"paint","rarity":"common","name":"Moss","price":80,
		"livery":{"body":Color("5f7a45"),"dark":Color("33402a"),"trim":Color("d98e4a"),"wing":Color("f0ead8")}},
	{"id":"paint/ochre","slot":"paint","rarity":"common","name":"Ochre","price":100,
		"livery":{"body":Color("d3a23c"),"dark":Color("5e4526"),"trim":Color("8a3f2e"),"wing":Color("f3ecd9")}},
	{"id":"paint/heather","slot":"paint","rarity":"uncommon","name":"Heather","price":120,
		"livery":{"body":Color("85587a"),"dark":Color("44303f"),"trim":Color("e6c48f"),"wing":Color("efe8e0")}},
	{"id":"paint/chalk","slot":"paint","rarity":"uncommon","name":"Chalk","price":150,
		"livery":{"body":Color("e9e4d6"),"dark":Color("3a3a36"),"trim":Color("b8342a"),"wing":Color("f4f1e8")}},
	{"id":"paint/night","slot":"paint","rarity":"uncommon","name":"Night Mail","price":180,
		"livery":{"body":Color("262c3a"),"dark":Color("161a22"),"trim":Color("d6a84a"),"wing":Color("d9d3c2")}},
	{"id":"ribbon/none","slot":"ribbon","name":"None","price":0,"colours":[]},
	{"id":"ribbon/scarlet","slot":"ribbon","name":"Scarlet","price":40,"colours":[Color("c8352b"),Color("f2e8d2")]},
	{"id":"ribbon/gilt","slot":"ribbon","name":"Gilt","price":50,"colours":[Color("ffd36b"),Color("8a5a1c")]},
	{"id":"ribbon/sky","slot":"ribbon","name":"Sky","price":50,"colours":[Color("7fb6dc"),Color("f4f4ee")]},
	{"id":"ribbon/ember","slot":"ribbon","name":"Ember","price":70,"colours":[Color("e0702a"),Color("2a2622")]},
]

## Where the ribbon hangs on the figure (its own frame: -Z the nose), the
## rudder's top, and its length and depth there (the figure's units).
const RIBBON_AT := Vector3(0.0,0.24,0.74)
const RIBBON_LONG := 0.62
const RIBBON_DEEP := 0.045
const RIBBON_SEGMENTS := 12

static var _stock: Array = []
static var _by_id := {}

## Every item, the base's then the batches', paints in order of price.
static func stock() -> Array:
	if _stock.is_empty():
		var paints: Array = []
		var rest: Array = []
		for i: Dictionary in ITEMS: (paints if i.slot == "paint" else rest).append(i)
		for path: String in BATCHES:
			var batch: Variant = load(path)
			if batch == null:
				push_error("ShopStock: no skin batch at %s" % path)
				continue
			for i: Dictionary in batch.SKINS: paints.append(i)
		# Stable: by price, then as listed.
		var at := {}
		for k in paints.size(): at[paints[k].id] = k
		paints.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.price) < int(b.price) or (int(a.price) == int(b.price) and at[a.id] < at[b.id]))
		_stock = paints+rest
		for i: Dictionary in _stock:
			if _by_id.has(i.id): push_error("ShopStock: two items are %s" % i.id)
			_by_id[i.id] = i
	return _stock

static func items(slot := "") -> Array:
	if slot == "": return stock()
	return stock().filter(func(i: Dictionary) -> bool: return i.slot == slot)

static func item(id: String) -> Dictionary:
	stock()
	return _by_id.get(id,{})

## The item's rarity (common when it names none).
static func rarity(i: Dictionary) -> String:
	return String(i.get("rarity","common"))

## A paint's finish as the hero shader's values (PlaneFigure `refinish`).
static func finish_values(i: Dictionary) -> Dictionary:
	var f: Dictionary = i.get("finish",{})
	var out: Dictionary = (SHEENS.get(String(f.get("sheen","satin")),{}) as Dictionary).duplicate()
	if f.has("pearl"):
		out["pearl"] = f.pearl
		out["pearl_amount"] = float(f.get("pearl_amount",0.6))
	if f.has("glow") or f.has("glow_on"):
		var on := Vector4.ZERO
		for slot: String in f.get("glow_on",["trim"]):
			if GLOW_SLOTS.has(slot): on[GLOW_SLOTS.find(slot)] = 1.0
			elif slot == "decal": out["glow_decal"] = 1.0
			else: push_error("ShopStock: %s glows on no slot %s" % [i.id,slot])
		out["glow"] = f.get("glow",Color(0,0,0))
		out["glow_slots"] = on
		# 1 shows the glow's own colour; above whitens it (1.6 washes a green
		# to mint), so it stops at 1.3.
		out["glow_power"] = clampf(float(f.get("glow_power",1.0)),0.0,1.3)
	if i.has("decal"):
		var tex: Texture2D = load(String(i.decal)) if ResourceLoader.exists(String(i.decal)) else null
		if tex == null: push_error("ShopStock: %s has no decal at %s" % [i.id,i.decal])
		else:
			out["decal_tex"] = tex
			out["decal_on"] = 1.0
	if i.has("bake"):
		var b: Dictionary = i.bake
		for key: String in b:
			if not BAKE_MAPS.has(key):
				push_error("ShopStock: %s bakes no map %s" % [i.id,key])
				continue
			var path := String(b[key])
			var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
			if tex == null: push_error("ShopStock: %s has no %s at %s" % [i.id,key,path])
			else: out[key+"_tex"] = tex
	return out

## The slot's free first item.
static func first(slot: String) -> String:
	for i: Dictionary in stock():
		if i.slot == slot and int(i.price) == 0: return i.id
	return ""

## Whether `book` has `id`: bought, or free.
static func has(book: RefCounted, id: String) -> bool:
	var i := item(id)
	return not i.is_empty() and (int(i.price) == 0 or book.owns(id))

## The item worn in `slot` (its first when the book names none, or one it
## does not have).
static func worn(book: RefCounted, slot: String) -> String:
	var id: String = book.worn_in(slot,first(slot))
	return id if has(book,id) else first(slot)

## Buys `id` (spent and owned); true when it is had after.
static func buy(book: RefCounted, id: String) -> bool:
	if has(book,id): return true
	var i := item(id)
	if i.is_empty() or not book.spend(int(i.price)): return false
	book.own(id)
	return true

## Puts what `book` wears on `figure` (a PlaneFigure), slot by slot, unless
## it wears it already. `try` overrides slots for a fitting ({slot: id}).
static func dress(figure: Node3D, book: RefCounted, try := {}) -> void:
	if figure == null or book == null: return
	for slot: String in SLOTS:
		var id: String = try.get(slot,worn(book,slot))
		if String(figure.get_meta("shop_"+slot,"")) == id: continue
		figure.set_meta("shop_"+slot,id)
		match slot:
			"paint": _paint(figure,item(id))
			"ribbon": _ribbon(figure,item(id).get("colours",[]))

## Repaints the figure in place (PlaneFigure `repaint`) to the paint's
## livery (its defaults else) and finish.
static func _paint(figure: Node3D, i: Dictionary) -> void:
	figure.repaint(i.get("livery",{}))
	if figure.has_method("refinish"): figure.refinish(finish_values(i))

const RIBBON_SHADER := """
shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform vec4 a : source_color = vec4(1.0);
uniform vec4 b : source_color = vec4(1.0);
uniform float bands = 5.0;
varying float u;
void vertex() {
	u = UV.x;
	float k = u*u;
	VERTEX.x += sin(TIME*11.0-u*7.0)*0.07*k+sin(TIME*17.0-u*11.0)*0.02*k;
	VERTEX.y += sin(TIME*7.0-u*5.0)*0.03*k-0.05*k;
}
void fragment() {
	ALBEDO = mod(floor(u*bands),2.0) < 0.5 ? a.rgb : b.rgb;
	ROUGHNESS = 0.8;
}
"""
static var _ribbon_shader: Shader

## The streamer off the rudder (none for no colours).
static func _ribbon(figure: Node3D, colours: Array) -> void:
	var old := figure.get_node_or_null("ShopRibbon")
	if old != null:
		figure.remove_child(old)
		old.queue_free()
	if colours.is_empty(): return
	if _ribbon_shader == null:
		_ribbon_shader = Shader.new()
		_ribbon_shader.code = RIBBON_SHADER
	var m := ShaderMaterial.new()
	m.shader = _ribbon_shader
	m.set_shader_parameter("a",colours[0])
	m.set_shader_parameter("b",colours[1 % colours.size()])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in RIBBON_SEGMENTS:
		var u0 := float(s)/RIBBON_SEGMENTS
		var u1 := float(s+1)/RIBBON_SEGMENTS
		# It narrows to its tail.
		var d0 := RIBBON_DEEP*lerpf(1.0,0.45,u0)
		var d1 := RIBBON_DEEP*lerpf(1.0,0.45,u1)
		var a := Vector3(0.0,0.0,u0*RIBBON_LONG)
		var b := Vector3(0.0,0.0,u1*RIBBON_LONG)
		var quad := [[a,u0,0.0],[b,u1,0.0],[b+Vector3(0,-d1,0),u1,1.0],[a,u0,0.0],[b+Vector3(0,-d1,0),u1,1.0],[a+Vector3(0,-d0,0),u0,1.0]]
		for v: Array in quad:
			st.set_normal(Vector3.RIGHT)
			st.set_uv(Vector2(v[1],v[2]))
			st.add_vertex(v[0])
	var part := MeshInstance3D.new()
	part.name = "ShopRibbon"
	part.mesh = st.commit()
	part.material_override = m
	part.position = RIBBON_AT
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	figure.add_child(part)
