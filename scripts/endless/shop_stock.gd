extends RefCounted
## What the shop sells (docs/design/endless-flight/spec-wild-loop.md, lane
## `shop`), and putting what is worn on the plane. A first stock, kept easy
## to change: an item is one row of ITEMS, its slot one of SLOTS. Prices come
## from PRICE, set against the pay (PilotBook `line_pay`, BeatRoutes' money):
## decent flying earns about PER_MINUTE (6,000) a minute, so each tier is its
## minutes of decent flying times that.
##
## Slots, each with its free first item (had by everyone, worn when the
## book names none):
##   paint   the plane's livery: body, dark, trim and wing colours
##           (PlaneFigure `repaint`'s keys), repainted in place
##   ribbon  a streamer off the rudder's top, two colours: nothing on the
##           flight, only to look at
## The book (PilotBook) keeps owned ids and the worn id per slot.


## Decent flying's money a minute at the book's scale (PilotBook MONEY_SCALE).
const PER_MINUTE := 6_000
## The price tiers, by name: each its minutes of decent flying times
## PER_MINUTE (ribbons about five minutes, the first paint ten, the dearest
## paint an hour, a plane body two, four and eight hours).
const PRICE := {
	"free": 0,
	"ribbon_5m": 30_000, "ribbon_7m": 42_000, "ribbon_9m": 54_000,
	"paint_10m": 60_000, "paint_15m": 90_000, "paint_22m": 132_000,
	"paint_30m": 180_000, "paint_45m": 270_000, "paint_60m": 360_000,
	"plane_2h": 720_000, "plane_4h": 1_440_000, "plane_8h": 2_880_000,
}
## The plane bodies' tiers in order of price (the `plane` slot's rows read
## PLANE_TIERS[i]; the hero plane is free): two, four and eight hours.
const PLANE_TIERS := [720_000, 1_440_000, 2_880_000]

const SLOTS := ["paint","ribbon"]
## Each slot's heading in the shop.
const SLOT_NAMES := {"paint":"Paints","ribbon":"Ribbons"}

const ITEMS := [
	# The wanderer's own: terracotta, teal and cream (PlaneFigure's defaults).
	{"id":"paint/home","slot":"paint","name":"Homestead","price":0,
		"livery":{"body":Color("b9583b"),"dark":Color("2f4a4f"),"trim":Color("2f6670"),"wing":Color("ece2c8")}},
	{"id":"paint/harbour","slot":"paint","name":"Harbour","price":PRICE.paint_10m,
		"livery":{"body":Color("3f6e8c"),"dark":Color("26394a"),"trim":Color("e8d9a8"),"wing":Color("eef0ea")}},
	{"id":"paint/moss","slot":"paint","name":"Moss","price":PRICE.paint_15m,
		"livery":{"body":Color("5f7a45"),"dark":Color("33402a"),"trim":Color("d98e4a"),"wing":Color("f0ead8")}},
	{"id":"paint/ochre","slot":"paint","name":"Ochre","price":PRICE.paint_22m,
		"livery":{"body":Color("d3a23c"),"dark":Color("5e4526"),"trim":Color("8a3f2e"),"wing":Color("f3ecd9")}},
	{"id":"paint/heather","slot":"paint","name":"Heather","price":PRICE.paint_30m,
		"livery":{"body":Color("85587a"),"dark":Color("44303f"),"trim":Color("e6c48f"),"wing":Color("efe8e0")}},
	{"id":"paint/chalk","slot":"paint","name":"Chalk","price":PRICE.paint_45m,
		"livery":{"body":Color("e9e4d6"),"dark":Color("3a3a36"),"trim":Color("b8342a"),"wing":Color("f4f1e8")}},
	{"id":"paint/night","slot":"paint","name":"Night Mail","price":PRICE.paint_60m,
		"livery":{"body":Color("262c3a"),"dark":Color("161a22"),"trim":Color("d6a84a"),"wing":Color("d9d3c2")}},
	{"id":"ribbon/none","slot":"ribbon","name":"None","price":0,"colours":[]},
	{"id":"ribbon/scarlet","slot":"ribbon","name":"Scarlet","price":PRICE.ribbon_5m,"colours":[Color("c8352b"),Color("f2e8d2")]},
	{"id":"ribbon/gilt","slot":"ribbon","name":"Gilt","price":PRICE.ribbon_7m,"colours":[Color("ffd36b"),Color("8a5a1c")]},
	{"id":"ribbon/sky","slot":"ribbon","name":"Sky","price":PRICE.ribbon_7m,"colours":[Color("7fb6dc"),Color("f4f4ee")]},
	{"id":"ribbon/ember","slot":"ribbon","name":"Ember","price":PRICE.ribbon_9m,"colours":[Color("e0702a"),Color("2a2622")]},
]

## Where the ribbon hangs on the figure (its own frame: -Z the nose), the
## rudder's top, and its length and depth there (the figure's units).
const RIBBON_AT := Vector3(0.0,0.24,0.74)
const RIBBON_LONG := 0.62
const RIBBON_DEEP := 0.045
const RIBBON_SEGMENTS := 12

static func items(slot := "") -> Array:
	if slot == "": return ITEMS
	return ITEMS.filter(func(i: Dictionary) -> bool: return i.slot == slot)

static func item(id: String) -> Dictionary:
	for i: Dictionary in ITEMS:
		if i.id == id: return i
	return {}

## The slot's free first item.
static func first(slot: String) -> String:
	for i: Dictionary in ITEMS:
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
			"paint": _paint(figure,item(id).get("livery",{}))
			"ribbon": _ribbon(figure,item(id).get("colours",[]))

## Repaints the figure in place (PlaneFigure `repaint`) to `livery`'s colours
## (its defaults else).
static func _paint(figure: Node3D, livery: Dictionary) -> void:
	figure.repaint(livery)

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
