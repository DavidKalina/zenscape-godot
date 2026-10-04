extends RefCounted
## What a world's card shows (Claude Design "ZenScape Main Menu Cards", face
## 5d Coin; docs/design/title-cards/README.md): its palette, its mood and the
## things placed in it, condensed when the world is kept
## (scripts/world_session.gd `keep_now`) and stored with it in the library
## index (scripts/world_library.gd `touch`). A world kept before cards has no
## summary yet; its land stands in (`of`).

const Icons = preload("res://scripts/hud_icons.gd")
const MoodLook = preload("res://scripts/mood_look.gd")

## Each placeable asset (scripts/native_terrain_data.gd ASSETS) as the glyph
## the materials case shows for it (scripts/hud_icons.gd). Ground cover,
## dead wood and the old study props have none and are not counted.
const ASSET_GLYPHS := {
	"broadleaf":"oak","tree":"pine","layered_tree":"pine","willow":"willow","birch":"birch","redwood":"redwood",
	"juniper":"juniper","joshua":"joshua","cactus":"joshua",
	"flower":"wildflower","daisy_flower":"wildflower","oxeye_daisy":"wildflower","buttercup":"wildflower",
	"button_flower":"wildflower","spike_flower":"wildflower","umbel_flower":"wildflower","lupine":"wildflower",
	"dandelion":"dandelion","dandelion_clock":"dandelion","cosmos":"cosmos","sunflower":"sunflower","poppy":"poppy",
	"wheat":"wheat","reeds":"reed","rock":"stone","boulder_1":"stone","boulder_2":"stone","boulder_3":"stone",
	"boulder_4":"stone","stone_lamp":"lamp","campfire":"campfire","cabin":"cabin","bridge":"bridge","waterfall":"water",
}
## Glyphs that sit in the sky, not on the land: never a card's hero.
const SKY_GLYPHS := ["globe","snow"]
## How many elements a card keeps, most placed first.
const KEPT := 4
## A palette per land for worlds with no summary: sky, horizon glow, land and
## sun, after the design's sample worlds.
const LAND_PALETTES := {
	"plain":{"sky":"8b95a2","glow":"c4bfb2","land":"4f8a5a","sun":"fff3d6"},
	"canyon":{"sky":"8a7c9c","glow":"e2a462","land":"b0703c","sun":"f2c79a"},
	"isle":{"sky":"7a8a96","glow":"c8d0c6","land":"5a8c62","sun":"e8ece6"},
	"hollow":{"sky":"4c6c6c","glow":"9cc2a0","land":"2f6c4c","sun":"d8ecd4"},
	"wildflowers":{"sky":"b89c68","glow":"f0cf86","land":"7d8a4c","sun":"fff3d6"},
	"sunflowers":{"sky":"b89c68","glow":"f0cf86","land":"c9944e","sun":"fff3d6"},
	"dandelions":{"sky":"8b95a2","glow":"d6d2a8","land":"6f8f45","sun":"fff3d6"},
	"cosmos":{"sky":"8a7c9c","glow":"e2b0a4","land":"9a7484","sun":"f2c79a"},
	"alpine_meadow":{"sky":"a8b2be","glow":"e8e8ea","land":"5f7a66","sun":"fff3d6"},
}
## The glyph a land's card shows before anything is placed in it.
const LAND_GLYPHS := {"plain":"oak","canyon":"joshua","isle":"water","hollow":"willow","wildflowers":"wildflower",
	"sunflowers":"sunflower","dandelions":"dandelion","cosmos":"cosmos","alpine_meadow":"pine"}
const SUN := "fff3d6"

## The kept world in `scene` as a card: {pal, mood, els}. `els` is up to KEPT
## {k: glyph id, n: count}, most placed first; ponds, streams and falls count
## as water. Parts the scene lacks are left out.
static func summarize(scene: Node) -> Dictionary:
	var card := {}
	var editor: Node = scene.get("_chunk_editor")
	var data: Object = editor.get("data") if editor != null else null
	if data != null:
		var counts := {}
		var objects: Variant = data.get("objects")
		if objects is Array:
			for item: Variant in objects:
				if not item is Dictionary: continue
				var glyph: String = ASSET_GLYPHS.get(str(item.get("asset","")),"")
				if not glyph.is_empty(): counts[glyph] = int(counts.get(glyph,0))+1
		for key in ["ponds","streams"]:
			var water: Variant = data.get(key)
			if water is Array and not water.is_empty(): counts["water"] = int(counts.get("water",0))+water.size()
		card.els = elements(counts)
	var mood: Node = scene.get("mood_look")
	if mood != null and mood.has_method("value"):
		var parts: Array = []
		for pair: Array in [["season",MoodLook.SEASONS],["time",MoodLook.TIMES],["weather",MoodLook.WEATHERS]]:
			var title := _title(pair[1],str(mood.value(pair[0])))
			if not title.is_empty(): parts.append(title)
		if not parts.is_empty(): card.mood = " · ".join(parts)
	var celestial: Variant = scene.get("_celestial")
	var look: Variant = celestial.get("look") if celestial is Object else null
	var colors: Variant = look.get("colors") if look is Object else null
	if colors is Dictionary and colors.has("sky") and colors.has("glow") and colors.has("grass"):
		card.pal = {"sky":(colors.sky as Color).to_html(false),"glow":(colors.glow as Color).to_html(false),
			"land":(colors.grass as Color).to_html(false),"sun":SUN}
	return card

## Counts by glyph as a card's elements: most placed first, then by name.
static func elements(counts: Dictionary) -> Array:
	var els: Array = []
	for k: String in counts:
		if int(counts[k]) > 0: els.append({"k":k,"n":int(counts[k])})
	els.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.n > b.n or (a.n == b.n and str(a.k) < str(b.k)))
	return els.slice(0,KEPT)

## The card a library world shows: its summary, or its land's, with a
## palette (Colors), a mood line and a hero glyph always present.
static func of(world: Dictionary) -> Dictionary:
	var land := str(world.get("land","plain"))
	var stored: Dictionary = world.get("card",{}) if world.get("card") is Dictionary else {}
	var pal: Dictionary = LAND_PALETTES.get(land,LAND_PALETTES.plain)
	if stored.get("pal") is Dictionary: pal = stored.pal
	var els: Array = stored.get("els",[]) if stored.get("els") is Array else []
	return {
		"pal":{"sky":_colour(pal,"sky","8b95a2"),"glow":_colour(pal,"glow","c4bfb2"),"land":_colour(pal,"land","4f8a5a"),"sun":_colour(pal,"sun",SUN)},
		"mood":str(stored.get("mood","")),
		"els":els,
		"hero":hero(els,LAND_GLYPHS.get(land,"oak")),
	}

## The most placed element that stands on the land, else `fallback`.
static func hero(els: Array, fallback: String) -> String:
	for e: Variant in els:
		if e is Dictionary and not str(e.get("k","")) in SKY_GLYPHS and not Icons.item(str(e.get("k",""))).is_empty(): return str(e.k)
	return fallback

## The coin window's colours from a world palette (WorldCard.dc.html `cozy`):
## top and low of its sky, the haze round the sun, the sun and the hill.
static func coin_colours(pal: Dictionary) -> Dictionary:
	var sky: Color = pal.sky
	var low := sky.lerp(pal.glow,0.72)
	var sun: Color = pal.sun
	return {"top":sky.lerp(Color("2a2230"),0.2),"low":low,"haze":Color(sun,176.0/255.0),"sun":sun.lerp(low,0.12),
		"hill":(pal.land as Color).lerp(Color("241c16"),0.5)}

## "Summer · Golden hour · Clear" as the card's foot: the first two parts.
static func mood_short(mood: String) -> String:
	return " · ".join(Array(mood.split(" · ")).slice(0,2)) if not mood.is_empty() else ""

## I, II … XII, then the number itself.
static func roman(n: int) -> String:
	const ROMAN := ["","I","II","III","IV","V","VI","VII","VIII","IX","X","XI","XII"]
	return ROMAN[n] if n >= 1 and n < ROMAN.size() else str(n)

static func _title(options: Array, id: String) -> String:
	for entry: Dictionary in options:
		if entry.id == id: return str(entry.title)
	return ""

static func _colour(pal: Dictionary, key: String, fallback: String) -> Color:
	var value: Variant = pal.get(key,fallback)
	if value is Color: return value
	var text := str(value)
	return Color(text) if Color.html_is_valid(text) else Color(fallback)
