extends Control
## [items] The items carried (docs/design/roguelike/items-contract.md): a
## row of small hand-drawn glyphs (scripts/roguelike/item_glyphs.gd) under
## the hearts, riding their alpha. [juice] One added swells and flashes, and
## its name shows beside the row a few seconds. Any id works: an unknown
## one wears its kind's mark. Its place and size follow the overlay's
## scale (design px of a 1080-high screen).
const ItemCatalog = preload("res://scripts/roguelike/item_catalog.gd")
const Glyphs = preload("res://scripts/roguelike/item_glyphs.gd")
const Splash = preload("res://scripts/isle_splash.gd")

## Design px: the row's left (the hearts'), its top below the hearts' row,
## a glyph's size and gap, the name's type.
const LEFT := 46.0
const TOP := 128.0
const GLYPH := 26.0
const GAP := 10.0
const TYPE := 14
## The swell of an added item (s) and how far it grows; the name's hold (s).
const SWELL := 0.7
const GROW := 0.55
const NAME_HOLD := 3.2

var _ids: Array[StringName] = []
var _born := {}
var _newest := &""

func _init() -> void:
	name = "Items"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func show_items(ids: Array[StringName]) -> void:
	for id in ids:
		if not (id in _ids):
			_born[id] = Time.get_ticks_msec()
			_newest = id
	_ids = ids.duplicate()
	queue_redraw()

func _process(_delta: float) -> void:
	if not _ids.is_empty() or not _born.is_empty(): queue_redraw()

## Seconds (real) since `id` was added (INF when long ago).
func _age(id: StringName) -> float:
	return float(Time.get_ticks_msec()-int(_born[id]))*0.001 if _born.has(id) else INF

func _draw() -> void:
	if _ids.is_empty(): return
	var overlay := get_parent().get_parent() if get_parent() != null else null
	var a := 1.0
	var px := 1.0
	if overlay != null and overlay.has_method("_hearts_a"):
		a = overlay._hearts_a()
		px = overlay._px
	if a <= 0.0: return
	var size := GLYPH*px
	var x := LEFT*px
	var y := TOP*px+size*0.5
	for id in _ids:
		var kind := String(ItemCatalog.info(id).get("kind",""))
		var age := _age(id)
		var k := clampf(age/SWELL,0.0,1.0)
		var pop := 1.0+GROW*sin(k*PI)*(1.0-k) if age != INF else 1.0
		var flash := 1.0-smoothstep(0.0,0.5,k) if age != INF else 0.0
		var at := Vector2(x+size*0.5,y)
		if flash > 0.0:
			draw_circle(at,size*(0.6+0.6*k),Color(1.0,0.86,0.55,0.22*flash*a))
		Glyphs.draw(self,id,kind,at,size*pop,a,1.0+0.5*flash)
		x += size+GAP*px
	# The newest one's name, a while.
	var age := _age(_newest)
	if age != INF and age < NAME_HOLD and TYPE*px >= 4.0:
		var fade := 1.0-smoothstep(NAME_HOLD-1.0,NAME_HOLD,age)
		var font: Font = Splash.READING
		var text := ItemCatalog.title(_newest)
		var pos := Vector2(x+4.0*px,y+float(TYPE)*px*0.35)
		draw_string(font,pos+Vector2(1,1),text,HORIZONTAL_ALIGNMENT_LEFT,-1,int(TYPE*px),Color(0,0,0,0.6*fade*a))
		draw_string(font,pos,text,HORIZONTAL_ALIGNMENT_LEFT,-1,int(TYPE*px),Color(0.91,0.86,0.75,fade*a))
