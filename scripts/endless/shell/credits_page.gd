extends "res://scripts/endless/shell/shell_page.gd"
## Credits: the maker, the sounds assets/audio/ATTRIBUTION.md asks to credit
## (kept here as text, since an export leaves the .md behind; update both
## together), the fonts' licence and the Godot engine's notice and licence.

const MAKER := "David Kalina"
## [what, licence, author, source] for each clip that needs or earns credit.
const SOUNDS := [
	["Mountain Chickadee","CC BY-SA 4.0","Matthias Sirch","commons.wikimedia.org/wiki/File:Poecile_gambeli_-_Mountain_Chickadee_XC395088.mp3"],
	["Steller's Jay (two calls)","CC BY-SA 3.0","Jonathon Jongsma","commons.wikimedia.org/wiki/File:Cyanocitta_stelleri_-_Steller's_Jay_XC109654.mp3, _XC110259.mp3"],
	["Hermit Thrush","CC BY-SA 4.0","Leonardo Guzman Hernandez","commons.wikimedia.org/wiki/File:Catharus_guttatus_-_Hermit_Thrush_XC389885.mp3"],
	["Ruby-crowned Kinglet","CC BY-SA 4.0","Jonathon Jongsma","commons.wikimedia.org/wiki/File:Regulus_calendula_-_Ruby-crowned_Kinglet_XC175095.mp3"],
	["Great Horned Owl","CC BY-SA 4.0","Michael & Katie LaTour","commons.wikimedia.org/wiki/File:Bubo_virginianus_-_Great_Horned_Owl_XC450919.mp3"],
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
		{"kind":"line","small":true,"dim":true,"text":"Wildlife recordings from Wikimedia Commons, trimmed and levelled for the game. The CC BY-SA recordings are shared under creativecommons.org/licenses/by-sa/3.0 and /4.0."},
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
