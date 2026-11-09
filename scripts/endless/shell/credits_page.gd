extends "res://scripts/endless/shell/shell_page.gd"
## Credits: the maker, the sounds assets/audio/ATTRIBUTION.md asks to credit
## (kept here as text, since an export leaves the .md behind; update both
## together), the fonts' licence and the Godot engine's notice and licence.

const MAKER := "David Kalina"
## [what, licence, author, source] for each clip that needs or earns credit.
const SOUNDS := [
	["Black-capped Chickadee","CC0","*ngoomie","commons.wikimedia.org/wiki/File:Black-capped_Chickadee_201947598.wav"],
	["Steller's Jay","Public domain","National Park Service","commons.wikimedia.org/wiki/File:Steller's_Jay_-_National_Park_Service.ogg"],
	["Steller's Jay","CC0","nfrae","freesound.org/people/nfrae/sounds/703255"],
	["Hermit Thrush","Public domain","National Park Service, Yosemite","commons.wikimedia.org/wiki/File:Hermit_Thrush_Yosemite_National_Park.ogg"],
	["Ruby-crowned Kinglet","Public domain","G. McGrane","commons.wikimedia.org/wiki/File:Ruby-crowned_Kinglet.ogg"],
	["Great Horned Owl","CC0","Felix Blume","freesound.org/people/felix.blume/sounds/612651"],
	["Clark's Nutcracker","Public domain","NPS / Shan Burson","Yellowstone sound library"],
	["Common Raven","Public domain","NPS / David Restivo","Yellowstone sound library"],
	["Mountain Bluebird, American Robin","Public domain","NPS & MSU Acoustic Atlas / Jennifer Jerrett","Yellowstone sound library"],
	["Thunder","Public domain","stephan","commons.wikimedia.org/wiki/File:Thunderstorm_after_hot_summer_day_17_minutes_02_of_04.ogg"],
]
const FONTS := [
	["Newsreader","Production Type"],
	["Spectral","Production Type"],
	["Barlow Semi Condensed","Jeremy Tribby"],
	["Cormorant Garamond","Christian Thalmann"],
]

func _init(_shell: Node) -> void:
	super()
	title = "Credits"
	width = 680.0
	var rows: Array = [
		{"kind":"heading","text":"Made by"},
		{"kind":"line","text":MAKER},
		{"kind":"heading","text":"Sounds"},
		{"kind":"line","small":true,"dim":true,"text":"Wildlife recordings from Wikimedia Commons and Freesound, public domain or CC0, trimmed and levelled for the game."},
	]
	for s: Array in SOUNDS:
		rows.append({"kind":"line","text":"%s, by %s (%s)" % [s[0],s[2],s[1]]})
		rows.append({"kind":"line","small":true,"dim":true,"text":str(s[3])})
	rows.append({"kind":"line","small":true,"text":"Foley, the bell and the gong are CC0 recordings from Freesound and Kenney's packs; the wind, water and genesis tones are made in code."})
	rows.append({"kind":"heading","text":"Fonts"})
	for f: Array in FONTS:
		rows.append({"kind":"line","text":"%s, by %s" % [f[0],f[1]]})
	rows.append({"kind":"line","small":true,"dim":true,"text":"Each under the SIL Open Font License 1.1 (openfontlicense.org)."})
	rows.append({"kind":"heading","text":"Engine"})
	rows.append({"kind":"line","text":"Made with the Godot Engine (godotengine.org/license)"})
	rows.append({"kind":"line","small":true,"dim":true,"text":Engine.get_license_text()})
	set_rows(rows)
