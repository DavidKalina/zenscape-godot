extends RefCounted
## Curated palette families for generated worlds.
##
## Each family is an art-directed colour scheme: the land (grass, foliage,
## rock, earth, water) and a daytime sky (sky, horizon, glow, sun). A world
## picks one family, weighted by its land (wet or desert), dominant habitat or
## desert kind, hour and weather, then draws seeded variation inside it: one
## small shift shared by the whole land plus a little per colour. The hour
## reshapes the sky within the ranges the renderer was tuned for, and autumn
## warms the foliage. Several variations are drawn and the most harmonious
## (`world_beauty.gd` `palette`) is kept.
##
## Everything here runs on its own random stream seeded from the world seed,
## so a seed's terrain, weather, hour and other mood draws are untouched.
##
## Desert families may carry `geology` bases: the strata, sand, varnish and
## salt colours `geology_palette.gd` then leans toward the palette's rock and
## earth. Without them the old shader colours are the base.
##
## The first four come from the landscape experiment (chalk, copper, moss and
## lavender, `wip/parked-2026-09-26`); moss is lifted so its woods do not go
## to silhouette.
const Beauty = preload("res://scripts/world_beauty.gd")
const DRAWS := 4
const LAND := ["grass","foliage","rock","earth","water"]
## Hour weights run dawn, day, dusk, night (the generator's `hour` 0..3).
const FAMILIES := {
	"chalk":{"title":"Chalk & turquoise","land":["wet","dry"],
		"colors":{"grass":"929c72","foliage":"58796e","rock":"c9c5b5","earth":"9b8d76","water":"3f8f93","sky":"90aebf","horizon":"b3c5c5","glow":"f4dfb9","sun":"f6e6c8"},
		"affinity":{"alpine":1.6,"meadow":1.2,"woodland":0.8,"salt-basin":2.0,"dunes":1.0,"monuments":0.6},
		"hours":[1.0,1.3,0.7,0.8],"weather":{"snow":1.5,"mist":1.3},
		"geology":{"sand_a":"e3cfa2","sand_b":"d4bb8a","band_a":"c7b595","band_b":"a8937a","band_c":"ddd0b6","varnish":"8a7358","salt":"eee9dc"}},
	"copper":{"title":"Copper & sage","land":["wet","dry"],
		"colors":{"grass":"a5a070","foliage":"5f7f68","rock":"ad7b66","earth":"8a6452","water":"5a8589","sky":"94aab6","horizon":"c4b6a6","glow":"f6d0a5","sun":"f8dcb6"},
		"affinity":{"meadow":1.0,"woodland":0.9,"alpine":0.6,"redwood":0.9,"wetland":0.4,"buttes":1.3,"desert-mountains":1.3,"desert":1.2,"tablelands":1.0},
		"hours":[1.0,1.0,1.3,0.6],"weather":{"snow":0.3}},
	"moss":{"title":"Slate & moss","land":["wet"],
		"colors":{"grass":"8a9e72","foliage":"4d7361","rock":"67717b","earth":"6b6d5a","water":"56808c","sky":"8fa9b5","horizon":"b0beb5","glow":"e5d5b0","sun":"f0e2c6"},
		"affinity":{"redwood":1.8,"wetland":1.8,"woodland":1.3,"alpine":1.0,"meadow":0.6},
		"hours":[1.2,1.0,0.8,1.0],"weather":{"mist":1.8,"rain":1.6,"overcast":1.4}},
	"lavender":{"title":"Lavender & gold","land":["wet","dry"],
		"colors":{"grass":"b3a67a","foliage":"777d67","rock":"c4bccf","earth":"82748a","water":"66899f","sky":"a2a9c6","horizon":"c1b6c7","glow":"f2d1b2","sun":"f6dcc4"},
		"affinity":{"meadow":1.5,"alpine":0.9,"woodland":0.6,"wetland":0.8,"redwood":0.3,"monuments":1.0,"salt-basin":0.8,"dunes":0.7},
		"hours":[1.3,0.6,1.6,1.0],"weather":{"rain":0.5,"overcast":0.5}},
	"spring":{"title":"Spring meadow","land":["wet"],
		"colors":{"grass":"79a26a","foliage":"4f7b53","rock":"c2b59a","earth":"7a6048","water":"448a8e","sky":"7fb0c8","horizon":"aac4c4","glow":"f2dcb0","sun":"fbe6c0"},
		"affinity":{"meadow":1.8,"woodland":1.4,"wetland":1.2,"alpine":0.8,"redwood":0.6},
		"hours":[1.1,1.4,0.8,0.6],"weather":{"snow":0.2}},
	"granite":{"title":"Pine & granite","land":["wet"],
		"colors":{"grass":"849c72","foliage":"4b6a5c","rock":"b9b6aa","earth":"766850","water":"4a8fa6","sky":"7aa4c9","horizon":"a9bccb","glow":"e9e0cc","sun":"f7ecd6"},
		"affinity":{"alpine":2.0,"woodland":1.0,"redwood":0.8,"meadow":0.6,"wetland":0.6},
		"hours":[1.2,1.3,0.7,0.8],"weather":{"snow":1.5,"overcast":1.2}},
	"fern":{"title":"Fern & cedar","land":["wet"],
		"colors":{"grass":"6f9a5c","foliage":"456e56","rock":"70665a","earth":"6d5243","water":"437a78","sky":"86a8a8","horizon":"a9bbb0","glow":"e8d6ae","sun":"f4e2bf"},
		"affinity":{"redwood":2.0,"wetland":1.4,"woodland":1.3,"meadow":0.6,"alpine":0.4},
		"hours":[1.2,1.1,0.9,0.7],"weather":{"mist":1.5,"rain":1.4,"snow":0.4}},
	"frost":{"title":"Frost & slate","land":["wet"],
		"colors":{"grass":"8aa876","foliage":"52706a","rock":"bfcad8","earth":"736c68","water":"5b8298","sky":"8ea6c4","horizon":"b6c2cf","glow":"dcdde6","sun":"eef0f4"},
		"affinity":{"alpine":1.4,"woodland":0.6,"wetland":0.6,"meadow":0.3,"redwood":0.4},
		"hours":[1.2,0.9,0.7,1.4],"weather":{"snow":8.0,"overcast":1.5,"clear":0.4,"fair":0.4,"rain":0.3}},
	"ember":{"title":"Ember & plum","land":["wet"],
		"colors":{"grass":"9d9c64","foliage":"6a7050","rock":"cbb2b8","earth":"7a5a58","water":"697d98","sky":"9189b0","horizon":"c0a4a8","glow":"f0b894","sun":"f8d2ac"},
		"affinity":{"meadow":1.2,"woodland":1.1,"alpine":0.7,"wetland":0.7,"redwood":0.7},
		"hours":[0.4,0.2,2.2,0.3],"weather":{"snow":0.2,"rain":0.5}},
	"sandstone":{"title":"Sandstone & sky","land":["dry"],
		"colors":{"grass":"8f8a4c","foliage":"7a7646","rock":"d09a70","earth":"ae7a55","water":"3f7f82","sky":"86a9c4","horizon":"c9b7a2","glow":"f1cf9e","sun":"fbe0b4"},
		"affinity":{"buttes":2.6,"monuments":2.6,"tablelands":2.4,"desert":1.8,"desert-mountains":1.5,"dunes":1.2,"salt-basin":0.6},
		"hours":[1.0,1.3,1.0,0.8]},
	"bone":{"title":"Bone & sage","land":["dry"],
		"colors":{"grass":"a8a676","foliage":"7f8a64","rock":"cdbfa2","earth":"b39e7c","water":"4f9296","sky":"93b4c6","horizon":"cfc6b4","glow":"f3e2c0","sun":"fbecd2"},
		"affinity":{"salt-basin":1.8,"dunes":1.8,"desert":1.2,"tablelands":0.9,"desert-mountains":0.7,"buttes":0.6,"monuments":0.6},
		"hours":[1.2,1.4,0.7,0.8],
		"geology":{"sand_a":"e6cf9f","sand_b":"d7bb87","band_a":"d0b58f","band_b":"b89a74","band_c":"e2d2b2","varnish":"8a6a4c","salt":"f0ead9"}},
	"rust":{"title":"Rust & violet","land":["dry"],
		"colors":{"grass":"a39460","foliage":"858057","rock":"a0644e","earth":"956052","water":"5f889c","sky":"9690b0","horizon":"c7a8a0","glow":"f0b58a","sun":"f9d4ac"},
		"affinity":{"desert-mountains":1.6,"buttes":1.3,"monuments":1.3,"desert":1.0,"tablelands":1.0,"dunes":0.8,"salt-basin":0.5},
		"hours":[1.2,0.6,1.8,1.2],
		"geology":{"sand_a":"d9a46e","sand_b":"c48d5a","band_a":"9c4632","band_b":"7e3526","band_c":"b87458","varnish":"6c3024","salt":"e6dbc8"}},
}

## Pick a family and draw this world's colours. `habitat` is the dominant
## habitat, or the desert kind for a desert. Returns {"family","colors","harmony"}
## with every key the look needs, derived ambient, bounce, rim and fog included.
static func draw(seed_value: int,dry: bool,habitat: String,hour: int,weather: String,autumn: bool) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value*104729+2027
	var family := choose(rng,dry,habitat,hour,weather)
	var best := {}
	var best_harmony := -1.0
	for attempt in range(DRAWS):
		var colors := vary(rng,FAMILIES[family].colors,hour,autumn)
		var harmony: float = Beauty.palette(colors,hour==3)
		if harmony>best_harmony:
			best_harmony = harmony
			best = colors
	derive(best)
	return {"family":family,"colors":best,"harmony":best_harmony}

static func weight(name: String,dry: bool,habitat: String,hour: int,weather: String) -> float:
	var f: Dictionary = FAMILIES[name]
	if ("dry" if dry else "wet") not in f.land: return 0.0
	return float(f.affinity.get(habitat,0.5))*float(f.hours[clampi(hour,0,3)])*float(f.get("weather",{}).get(weather,1.0))

static func choose(rng: RandomNumberGenerator,dry: bool,habitat: String,hour: int,weather: String) -> String:
	var total := 0.0
	for name: String in FAMILIES: total += weight(name,dry,habitat,hour,weather)
	var roll := rng.randf()*total
	var last := ""
	for name: String in FAMILIES:
		var w := weight(name,dry,habitat,hour,weather)
		if w<=0.0: continue
		last = name
		roll -= w
		if roll<0.0: return name
	return last

static func _jitter(rng: RandomNumberGenerator,c: Color,hue_shift: float,sat_scale: float,value_shift: float) -> Color:
	return Color.from_hsv(fposmod(c.h+hue_shift+rng.randf_range(-.012,.012),1.0),
		clampf(c.s*sat_scale*rng.randf_range(.93,1.07),0.0,1.0),
		clampf(c.v+value_shift+rng.randf_range(-.03,.03),0.0,1.0))

## One variation of a family at an hour. The land shares one small hue,
## saturation and value shift so the scheme holds together.
static func vary(rng: RandomNumberGenerator,authored: Dictionary,hour: int,autumn: bool) -> Dictionary:
	var hue_shift := rng.randf_range(-.02,.02)
	var sat_scale := rng.randf_range(.9,1.1)
	var value_shift := rng.randf_range(-.03,.03)
	var colors := {}
	for key: String in LAND: colors[key] = _jitter(rng,Color(authored[key]),hue_shift,sat_scale,value_shift)
	if autumn:
		# Turned leaves: foliage toward amber and the grass toward straw.
		var f: Color = colors.foliage
		colors.foliage = Color.from_hsv(lerpf(f.h,rng.randf_range(.065,.12),.8),clampf(maxf(f.s,.34)*1.1,0.0,.55),clampf(f.v+.04,.40,.62))
		var g: Color = colors.grass
		colors.grass = Color.from_hsv(lerpf(g.h,.14,.35),g.s,g.v)
	var sky := Color(authored.sky)
	var horizon := Color(authored.horizon)
	var glow := Color(authored.glow)
	var sun := Color(authored.sun)
	var sky_shift := rng.randf_range(-.02,.02)
	match hour:
		0:
			# Dawn: a cooler, bluer-violet sky and a rose glow.
			sky = Color.from_hsv(fposmod(lerpf(sky.h,.66,.45)+sky_shift,1.0),clampf(sky.s*rng.randf_range(.95,1.1),.18,.40),clampf(sky.v*rng.randf_range(.95,1.02),.60,.80))
			glow = Color.from_hsv(lerpf(glow.h,.03,.5),clampf(glow.s+rng.randf_range(.02,.08),.13,.36),glow.v)
			horizon = horizon.lerp(glow,.2)
			sun = Color.from_hsv(lerpf(sun.h,.08,.5),clampf(sun.s+.06,.12,.30),.98)
		2:
			# Dusk: violet overhead, a deeper amber glow.
			sky = Color.from_hsv(fposmod(lerpf(sky.h,.72,.5)+sky_shift,1.0),clampf(sky.s*rng.randf_range(1.0,1.15),.20,.40),clampf(sky.v*rng.randf_range(.9,.98),.58,.78))
			glow = Color.from_hsv(lerpf(glow.h,.05,.5),clampf(glow.s+rng.randf_range(.06,.12),.15,.40),clampf(glow.v*.97,.74,.96))
			horizon = horizon.lerp(glow,.3)
			sun = Color.from_hsv(lerpf(sun.h,.07,.6),clampf(sun.s+.12,.18,.32),.98)
		3:
			# Night: the moonlit ranges the renderer was tuned for, tinted by the family.
			sky = Color.from_hsv(fposmod(lerpf(sky.h,.61,.5)+sky_shift,1.0),clampf(sky.s,.20,.38),rng.randf_range(.42,.58))
			horizon = Color.from_hsv(fposmod(sky.h-.03,1.0),clampf(horizon.s,.12,.28),rng.randf_range(.45,.62))
			glow = Color.from_hsv(.61,rng.randf_range(.13,.32),rng.randf_range(.76,.96))
			sun = Color.from_hsv(.60,.13,.98)
		_:
			sky = Color.from_hsv(fposmod(sky.h+sky_shift,1.0),clampf(sky.s*rng.randf_range(.92,1.08),0.0,1.0),clampf(sky.v+rng.randf_range(-.03,.03),0.0,1.0))
			horizon = Color.from_hsv(fposmod(horizon.h+sky_shift,1.0),horizon.s,clampf(horizon.v+rng.randf_range(-.03,.03),0.0,1.0))
	colors.sky = sky
	colors.horizon = horizon
	colors.glow = glow
	colors.sun = sun
	return colors

## The derived light colours, as the generator has always made them.
static func derive(colors: Dictionary) -> void:
	colors.ambient = colors.sky.lerp(Color("d3dce6"),.50)
	colors.bounce = colors.earth.darkened(.20)
	colors.rim = colors.sky.lerp(Color("d2dce7"),.50)
	colors.fog = colors.horizon.lerp(Color("eef2ed"),.60)

## Geology bases for a family (empty keeps the old shader colours).
static func geology(family: String) -> Dictionary:
	return FAMILIES.get(family,{}).get("geology",{})
