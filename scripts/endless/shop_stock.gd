extends RefCounted
## What the shop sells (docs/design/endless-flight/spec-wild-loop.md, lane
## `shop`), and putting what is worn on the plane. A first stock, kept easy
## to change: an item is one row of ITEMS, its slot one of SLOTS. Prices are
## set by time to earn against the pay; the pay, the rates measured and the
## price bands with their target times are scripts/endless/economy.gd's. A
## paint's price follows its rarity (PRICE_BANDS); a ribbon has none.
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
##           pearl_amount, glow: Color, glow_on: [slots], glow_power,
##           bare: 0..1, the bake's bared metal as a mirror in its own colour,
##           metal: 0..1, how much of the metal sheen's mirror the paint takes
##           (1 by default): below, a dark metal stays dark}
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
##
## Parts (docs/design/endless-flight/spec-hangar.md; scripts/endless/plane_parts.gd):
## the patterns, special finishes and decals a look is made of are sold too.
## A part is no slot (nothing is worn in its place): its row comes from
## PlaneParts, its id is kind:name, and `item`, `has` and `buy` take it as
## they take an item's. Had: bought, or come with a skin that is had
## (`has`). Bought or chosen in the shop it goes onto the book's look
## (`put_part`); `wearing` says whether the plane has it on. SECTIONS is the
## shop's list: the slots, then the parts' sections. `--hangar-all` has every
## part.
##
## Presets (spec-hangar.md, "Skins as presets"): a paint row is a preset, a
## whole look (`preset`; PlaneLook `from_skin`), and wearing one is loading
## it (`wear`, `load_look`): the book's look becomes the preset's, to change
## in the hangar from there. The pilot's own are kept in the book's
## `presets` by slot (CUSTOM_SLOTS; `save_custom`). Loading over a look that
## is no preset (`saved_as`) keeps that look as the book's LAST preset, so
## it can be had back.


const SLOTS := ["paint","ribbon"]
## Each slot's heading in the shop.
const SLOT_NAMES := {"paint":"Paints","ribbon":"Ribbons","pattern":"Patterns","finish":"Finishes","decal":"Decals"}
const PlaneParts = preload("res://scripts/endless/plane_parts.gd")
## The shop's sections, in order: the slots, then the parts'.
const SECTIONS: Array[String] = ["paint","ribbon","pattern","finish","decal"]

## The skin batches, each a script with `const SKINS := [rows]`.
const BATCHES := [
	"res://scripts/endless/skins/demo.gd",
	"res://scripts/endless/skins/wild.gd",
	"res://scripts/endless/skins/heritage.gd",
	"res://scripts/endless/skins/glow.gd",
	"res://scripts/endless/skins/metal.gd",
]

const RARITIES := ["common","uncommon","rare","legendary"]
## Each rarity's colour in the shop's list.
## Each rarity's price band [least, most]: the economy's (economy.gd, which
## has the reasoning).
const PRICE_BANDS: Dictionary = preload("res://scripts/endless/economy.gd").PRICE_BANDS
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
	{"id":"paint/harbour","slot":"paint","rarity":"common","name":"Harbour","price":2000,
		"livery":{"body":Color("3f6e8c"),"dark":Color("26394a"),"trim":Color("e8d9a8"),"wing":Color("eef0ea")}},
	{"id":"paint/moss","slot":"paint","rarity":"common","name":"Moss","price":3000,
		"livery":{"body":Color("5f7a45"),"dark":Color("33402a"),"trim":Color("d98e4a"),"wing":Color("f0ead8")}},
	{"id":"paint/ochre","slot":"paint","rarity":"common","name":"Ochre","price":4500,
		"livery":{"body":Color("d3a23c"),"dark":Color("5e4526"),"trim":Color("8a3f2e"),"wing":Color("f3ecd9")}},
	{"id":"paint/heather","slot":"paint","rarity":"uncommon","name":"Heather","price":6000,
		"livery":{"body":Color("85587a"),"dark":Color("44303f"),"trim":Color("e6c48f"),"wing":Color("efe8e0")}},
	{"id":"paint/chalk","slot":"paint","rarity":"uncommon","name":"Chalk","price":7500,
		"livery":{"body":Color("e9e4d6"),"dark":Color("3a3a36"),"trim":Color("b8342a"),"wing":Color("f4f1e8")}},
	{"id":"paint/night","slot":"paint","rarity":"uncommon","name":"Night Mail","price":8500,
		"livery":{"body":Color("262c3a"),"dark":Color("161a22"),"trim":Color("d6a84a"),"wing":Color("d9d3c2")}},
	{"id":"ribbon/none","slot":"ribbon","name":"None","price":0,"colours":[]},
	{"id":"ribbon/scarlet","slot":"ribbon","name":"Scarlet","price":1000,"colours":[Color("c8352b"),Color("f2e8d2")]},
	{"id":"ribbon/gilt","slot":"ribbon","name":"Gilt","price":1300,"colours":[Color("ffd36b"),Color("8a5a1c")]},
	{"id":"ribbon/sky","slot":"ribbon","name":"Sky","price":1300,"colours":[Color("7fb6dc"),Color("f4f4ee")]},
	{"id":"ribbon/ember","slot":"ribbon","name":"Ember","price":2000,"colours":[Color("e0702a"),Color("2a2622")]},
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
			for i: Dictionary in batch.SKINS:
				var band: Array = PRICE_BANDS.get(String(i.get("rarity","")),[])
				if band.is_empty(): push_error("ShopStock: %s has no rarity of %s" % [i.id,RARITIES])
				elif int(i.price) < int(band[0]) or int(i.price) > int(band[1]):
					push_warning("ShopStock: %s costs %d, outside %s's %s" % [i.id,int(i.price),i.rarity,band])
				paints.append(i)
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
	if is_part(id): return PlaneParts.row(id)
	stock()
	return _by_id.get(id,{})

## What the shop lists under `section` (SECTIONS): a slot's items or a
## section's parts.
static func listed(section: String) -> Array:
	return items(section) if SLOTS.has(section) else PlaneParts.listed(section)

## Whether `id` is a part's (kind:name), not an item's (slot/name).
static func is_part(id: String) -> bool:
	return ":" in id

## The item's rarity (common when it names none).
static func rarity(i: Dictionary) -> String:
	return String(i.get("rarity","common"))

## A paint's finish as the hero shader's values (PlaneFigure `refinish`).
static func finish_values(i: Dictionary) -> Dictionary:
	var f: Dictionary = i.get("finish",{})
	var out: Dictionary = (SHEENS.get(String(f.get("sheen","satin")),{}) as Dictionary).duplicate()
	if f.has("bare"): out["finish_bare"] = clampf(float(f.bare),0.0,1.0)
	if f.has("metal") and out.has("finish_metal"): out["finish_metal"] = clampf(float(f.metal),0.0,1.0)
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
	if is_part(id): return _has_part(book,id)
	var i := item(id)
	return not i.is_empty() and (int(i.price) == 0 or book.owns(id))

static var _all_parts := -1
## Whether every part is had (--hangar-all: to try looks, and for stills).
static func all_parts() -> bool:
	if _all_parts < 0: _all_parts = int("--hangar-all" in preload("res://scripts/launch_args.gd").user_args())
	return _all_parts == 1

## The parts each skin comes with, by the skin's id (PlaneParts `of_skin`).
static var _skin_parts := {}

## A part is had when it is free (no row in PlaneParts), bought, or come
## with a skin that is had.
static func _has_part(book: RefCounted, id: String) -> bool:
	if PlaneParts.row(id).is_empty() or all_parts() or book.owns(id): return true
	if _skin_parts.is_empty():
		for i: Dictionary in items("paint"):
			var with := PlaneParts.of_skin(i)
			if not with.is_empty(): _skin_parts[i.id] = with
	for skin: String in _skin_parts:
		if (_skin_parts[skin] as Array).has(id) and has(book,skin): return true
	return false

## The parts of `look` that `book` does not have.
static func locked(book: RefCounted, look: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for id in PlaneParts.of_look(look):
		if not has(book,id): out.append(id)
	return out

## The look the plane wears by `book`, whole: its own, else its worn skin as one.
static func look_of(book: RefCounted) -> Dictionary:
	return PlaneLook.of(book,item(worn(book,"paint")))

## The pilot's own preset slots, and the book's key for the look a loaded
## preset replaced.
const CUSTOM_SLOTS := 5
const LAST := "last"

## Skin `id` as a look: its preset.
static func preset(id: String) -> Dictionary:
	return PlaneLook.from_skin(item(id))

## The name of the preset `look` is as it stands (one of the pilot's own, or
## a skin's), "" for a look that is none of them.
static func saved_as(book: RefCounted, look: Dictionary) -> String:
	for slot: String in book.presets:
		if slot != LAST and book.presets[slot] == look: return custom_name(slot)
	for i: Dictionary in items("paint"):
		if PlaneLook.from_skin(i) == look: return String(i.name)
	return ""

static func custom_name(slot: String) -> String:
	return "Custom "+slot

## `look` (whole) becomes what the plane wears; `skin` names the skin it is
## the preset of ("" for one of the pilot's own). The look it replaces, when
## it is no preset, is kept as the book's LAST.
static func load_look(book: RefCounted, look: Dictionary, skin := "") -> void:
	var was := look_of(book)
	if was != look and saved_as(book,was) == "": book.set_preset(LAST,was)
	if skin != "": book.wear("paint",skin)
	book.set_look(look.duplicate(true))

## `id` worn in `slot`. A paint worn is its preset loaded.
static func wear(book: RefCounted, slot: String, id: String) -> void:
	if slot == "paint": load_look(book,preset(id),id)
	else: book.wear(slot,id)

## `look` kept in the pilot's slot `n` (0..CUSTOM_SLOTS-1), over what was
## there.
static func save_custom(book: RefCounted, n: int, look: Dictionary) -> void:
	book.set_preset(str(n+1),look.duplicate(true))

## `look_of(book)` with part `id` put on it: what buying or choosing the part
## in the shop keeps (`put_part`), and what trying it shows.
static func look_with(book: RefCounted, id: String) -> Dictionary:
	var look := look_of(book)
	PlaneParts.put(look,id)
	return look

## Part `id` onto the book's look (kept; worn from the next `dress`).
static func put_part(book: RefCounted, id: String) -> void:
	book.set_look(look_with(book,id))

## Whether the plane has `id` on: an item worn in its slot, or a part on the
## look (a skin's own part under a look that lacks its kind too).
static func wearing(book: RefCounted, id: String) -> bool:
	if not is_part(id): return worn(book,String(item(id).get("slot",""))) == id
	return PlaneParts.of_look(look_of(book)).has(id)

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
## it wears it already. `try` overrides slots for a fitting ({slot: id}), and
## its `look` is a whole look tried on in place of the book's (a part in the
## shop); the book's own `fitting` (the hangar's, a part not had shown on the
## plane) is one too, for every caller while it is set.
static func dress(figure: Node3D, book: RefCounted, try := {}) -> void:
	if figure == null or book == null: return
	for slot: String in SLOTS:
		var id: String = try.get(slot,worn(book,slot))
		# The hangar's look (PlaneLook), when the book has one, is the paint
		# worn; a fitting (`try`) still shows the shop's paint over it.
		var look: Dictionary = {}
		var look_key := ""
		if slot == "paint" and not try.has(slot) and book is PilotBook:
			var fit: Dictionary = try.get("look",book.fitting)
			if not fit.is_empty():
				look = fit
				look_key = "fit#%d" % fit.hash()
			elif book.look_key != "":
				look = book.look
				look_key = book.look_key
		var key := id if look_key == "" else look_key
		if String(figure.get_meta("shop_"+slot,"")) == key: continue
		figure.set_meta("shop_"+slot,key)
		match slot:
			"paint":
				if look_key == "": _paint(figure,item(id))
				else: PlaneLook.apply(figure,look,(item(id).get("livery",{}) as Dictionary).duplicate(),finish_values(item(id)),finish_values(PlaneLook.finish_row(look)))
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
