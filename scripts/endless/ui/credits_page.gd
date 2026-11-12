extends "res://scripts/endless/ui/menu_base.gd"
## The credits page (docs/design/ui/mock/Main.dc.html, its credits screen):
## the game's name and who made it, a roll, the typefaces and their
## licence, and Back. A page (menu_base.gd `open_page`): `setup(host)`,
## then `closed` when Back, Esc or the pad's B leaves it.
##
## The roll is one long list in sections, the heading over it naming the
## section at its top: Sound (the recordings' table in
## assets/audio/ATTRIBUTION.md, read from the pack: export_presets.cfg
## includes it; then SOUND_MORE), Engine (Godot's licence), Third-party
## notices (Engine.get_copyright_info) and Licence texts
## (Engine.get_license_info, and the fonts' OFL files when they are in the
## pack). It rolls on its own at the mock-up's pace, round and round; Up /
## Down, W / S, the d-pad, either stick (faster the longer held), the wheel,
## Page Up / Down and Home move it by hand, and it rolls on again HOLD s after.

signal closed

const ATTRIBUTION := "res://assets/audio/ATTRIBUTION.md"
## The sound that is not a row of the table, as the mock-up words it
## (ATTRIBUTION.md's prose sections).
const SOUND_MORE := [
	["Wildlife and thunder recordings","From Wikimedia Commons, trimmed and levelled for the game"],
	["Tool and HUD foley","Cut from CC0 recordings on Freesound and from Kenney packs"],
	["Bell and gong","CC0 recordings from Freesound"],
	["Streams, shore, wind, rain and the rest","Synthesised for the game"],
]
const TYPE_FACES := "Barlow Semi Condensed, Newsreader, Spectral, Cormorant Garamond"
const TYPE_LICENCE := "SIL Open Font License 1.1"
## The fonts' licence files (assets/fonts), shown under Licence texts when
## they are in the pack.
const FONT_NOTES := {"Barlow Semi Condensed":"BarlowSemiCondensed-OFL.txt","Newsreader":"Newsreader-OFL.txt",
	"Spectral":"Spectral-OFL.txt","Cormorant Garamond":"CormorantGaramond-OFL.txt"}
const TAKES := ["","",", two takes",", three takes",", four takes"]

## The roll's own pace (mock px a second: the mock-up's 602 px in 44 s), a
## hand's pace, the wheel's step, and how long it waits after a hand.
const ROLL := 13.7
const HAND := 260.0
## Held, the hand's pace grows by HAND_GAIN of itself a second, to HAND_MOST times.
const HAND_GAIN := 1.5
const HAND_MOST := 10.0
const WHEEL := 43.0
const HOLD := 3.0
const ROLL_H := 196.0
## The roll's line styles: [face, px, tracking, colour, line height].
enum {CR1, CR2, HEAD}
const STYLES := [[Kit.MED,14.0,0.06,Kit.INK,18.0],[Kit.MED,12.0,0.06,Kit.DIM,16.0],[Kit.MED,10.5,0.26,Kit.HEAD,34.0]]

## The roll's window: clips the lines to itself, fades them at its ends.
class RollWindow extends Control:
	var owner_page: Control
	func _init() -> void:
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		owner_page.draw_roll(self)

## The sections: [title, items], an item ["pair", first, second] or
## ["text", lines of prose].
var sections: Array = []
## The roll, laid out: each line's top (px), words and style; the sections'
## tops; its whole height.
var _tops := PackedFloat32Array()
var _words := PackedStringArray()
var _styles := PackedByteArray()
var _section_tops: Array = []
var _total := 1.0
var _laid_for := Vector2.ZERO
var scroll := 0.0
var _hold := 0.0
var _held := 0.0
var _window := RollWindow.new()
var _type_lines := PackedStringArray()

func _init() -> void:
	super()
	name = "CreditsPage"
	rows = [{"id":"back","label":"Back","key":"Esc","pad":"B","gap":10.0}]
	_window.owner_page = self
	add_child(_window)

func setup(game: Node) -> void:
	host = game
	sections = build_sections()
	_laid_for = Vector2.ZERO
	arrive(0)

func pick(_i: int) -> void:
	closed.emit()

func back() -> void:
	closed.emit()

## Up and down move the roll here (`tick`), not the selection: Back is the
## one row.
func move(_step: int) -> void:
	pass

func other_input(event: InputEvent) -> bool:
	var s := k()
	var b := event as InputEventMouseButton
	if b != null and b.pressed:
		if b.button_index == MOUSE_BUTTON_WHEEL_UP: _by_hand(-WHEEL*s)
		elif b.button_index == MOUSE_BUTTON_WHEEL_DOWN: _by_hand(WHEEL*s)
		else: return false
		return true
	if _is_key(event,KEY_PAGEUP): _by_hand(-ROLL_H*0.8*s)
	elif _is_key(event,KEY_PAGEDOWN): _by_hand(ROLL_H*0.8*s)
	elif _is_key(event,KEY_HOME): _by_hand(-scroll)
	else: return false
	return true

func _by_hand(px: float) -> void:
	scroll = fposmod(scroll+px,_total)
	_hold = HOLD
	_window.queue_redraw()
	queue_redraw()

func tick(delta: float) -> void:
	var s := k()
	_lay_out(s)
	var hand := Input.get_axis(&"ui_up",&"ui_down")+Pad.stick(&"look_left",&"look_right",&"look_up",&"look_down").y
	if Input.is_physical_key_pressed(KEY_S): hand += 1.0
	if Input.is_physical_key_pressed(KEY_W): hand -= 1.0
	var before := _section()
	if absf(hand) > 0.1 and taking():
		_held += delta
		_by_hand(clampf(hand,-1.0,1.0)*HAND*minf(1.0+_held*HAND_GAIN,HAND_MOST)*s*delta)
	else:
		_held = 0.0
		if _hold > 0.0: _hold -= delta
		else: scroll = fposmod(scroll+ROLL*s*delta,_total)
	_window.queue_redraw()
	if _section() != before or age < 0.3: queue_redraw()

# --- What the roll says ------------------------------------------------------------------

## The roll's sections, built from the pack and the engine.
static func build_sections() -> Array:
	var sound := sound_rows(_read(ATTRIBUTION))
	var engine := [["pair","Godot Engine","MIT licence · godotengine.org/license"],["text",Engine.get_license_text()]]
	var notices := []
	for part: Dictionary in Engine.get_copyright_info():
		var lines := PackedStringArray()
		for piece: Dictionary in part.get("parts",[]):
			var line := "© %s · %s" % ["; ".join(PackedStringArray(piece.get("copyright",[]))),str(piece.get("license",""))]
			if not line in lines: lines.append(line)
		notices.append(["pair",str(part.get("name","")),"\n".join(lines)])
	var texts := []
	for font: String in FONT_NOTES:
		var note := _read("res://assets/fonts/"+str(FONT_NOTES[font]))
		if not note.is_empty(): texts.append(["pair",font,note])
	var licences: Dictionary = Engine.get_license_info()
	for id: String in licences: texts.append(["pair",id,str(licences[id])])
	return [["Sound",sound],["Engine",engine],["Third-party notices",notices],["Licence texts",texts]]

static func _read(path: String) -> String:
	var file := FileAccess.open(path,FileAccess.READ)
	return file.get_as_text() if file != null else ""

## The Sound section from ATTRIBUTION.md's text: a pair for each recording
## in its table (the takes of one recording as one line), then SOUND_MORE,
## then where the CC licences' texts are.
static func sound_rows(text: String) -> Array:
	var out := []
	var links := PackedStringArray()
	for line: String in text.split("\n"):
		for word: String in line.split(" ",false):
			if word.begins_with("https://creativecommons.org/"): links.append(word.trim_prefix("https://").rstrip("."))
		if not line.begins_with("|"): continue
		var cells := line.split("|")
		if cells.size() < 5 or cells[1].strip_edges() == "file" or cells[1].strip_edges().begins_with("-"): continue
		var who := cells[3].strip_edges()
		if "/" in who and not " / " in who: who = who.replace("/"," / ")
		var licence := cells[2].strip_edges()
		if licence.to_lower() == "public domain": licence = "public domain"
		var title := _title_of(cells[4].strip_edges(),cells[1].strip_edges())
		var second := "%s · %s" % [who,licence]
		if not out.is_empty() and str(out[-1][3]) == title and str(out[-1][2]) == second:
			var same: Array = out[-1]
			same[4] = int(same[4])+1
			continue
		out.append(["pair","",second,title,1])
	for row: Array in out:
		row[1] = str(row[3])+str(TAKES[mini(int(row[4]),TAKES.size()-1)])
		row.resize(3)
	for more: Array in SOUND_MORE: out.append(["pair",more[0],more[1]])
	if not links.is_empty(): out.append(["pair","CC BY-SA licence texts"," and ".join(links)])
	return out

## A recording's name from its source page ("...File:Genus_species_-_Name_XC1.mp3"),
## else from its file.
static func _title_of(source: String, file: String) -> String:
	var page := source.uri_decode()
	var at := page.rfind("File:")
	if at < 0: return file.get_basename().capitalize()
	var parts := page.substr(at+5).get_basename().replace("_"," ").split(" - ")
	if parts.size() == 1: return parts[0].get_slice(" ",0)
	var title := parts[1].strip_edges()
	var last := title.rfind(" ")
	if last > 0 and title.substr(last+1).begins_with("XC"): title = title.substr(0,last)
	return title.replace("'","’")

# --- Layout ------------------------------------------------------------------------------

## `text` broken to lines no wider than `width` px, in a style.
static func fold(text: String, style: int, s: float, width: float) -> PackedStringArray:
	var out := PackedStringArray()
	var st: Array = STYLES[style]
	var px := maxi(roundi(float(st[1])*s),4)
	var f := Kit.face(int(st[0]),px,float(st[2]))
	var space := f.get_string_size(" ",HORIZONTAL_ALIGNMENT_LEFT,-1,px).x
	var line := ""
	var w := 0.0
	for word: String in text.split(" ",false):
		var ww := f.get_string_size(word,HORIZONTAL_ALIGNMENT_LEFT,-1,px).x
		if line.is_empty():
			line = word
			w = ww
		elif w+space+ww > width:
			out.append(line)
			line = word
			w = ww
		else:
			line += " "+word
			w += space+ww
	if not line.is_empty(): out.append(line)
	return out

func _slip(s: float) -> Rect2:
	var type_h := 2.0+18.0*maxi(_type_lines.size(),1)+16.0
	return Rect2(72.0*s,112.0*s,440.0*s,(8.0+30.0+89.0+34.0+4.0+ROLL_H+34.0+type_h+rows_height(30.0)+12.0)*s)

## Lays the roll out for this size (once a size).
func _lay_out(s: float) -> void:
	if _laid_for == size: return
	_laid_for = size
	var width := (440.0-30.0-38.0)*s
	_type_lines = fold(TYPE_FACES,CR1,s,(440.0-30.0-50.0)*s)
	_tops.clear()
	_words.clear()
	_styles.clear()
	_section_tops.clear()
	var y := 0.0
	for section: Array in sections:
		_section_tops.append([y,str(section[0])])
		if y > 0.0: y = _line(str(section[0]).to_upper(),HEAD,y,s)
		for item: Array in section[1]:
			if str(item[0]) == "pair":
				for l: String in fold(str(item[1]),CR1,s,width): y = _line(l,CR1,y,s)
				y = _prose(str(item[2]),y,s,width)
			else: y = _prose(str(item[1]),y,s,width)
			y += 9.0*s
	_total = maxf(y+ROLL_H*0.5*s,1.0)
	scroll = fposmod(scroll,_total)
	var slip := _slip(s)
	_window.position = Vector2(slip.position.x+30.0*s,slip.position.y+(8.0+30.0+89.0+34.0+4.0)*s)
	_window.size = Vector2(width,ROLL_H*s)
	queue_redraw()

## Prose in the quiet style: each line of it wrapped, a blank line a gap.
func _prose(text: String, y: float, s: float, width: float) -> float:
	for para: String in text.split("\n"):
		if para.strip_edges().is_empty():
			y += 8.0*s
			continue
		for l: String in fold(para.strip_edges(),CR2,s,width): y = _line(l,CR2,y,s)
	return y

func _line(words: String, style: int, y: float, s: float) -> float:
	_tops.append(y)
	_words.append(words)
	_styles.append(style)
	return y+float(STYLES[style][4])*s

## The section at the roll's top.
func _section() -> String:
	var out := "Sound"
	for st: Array in _section_tops:
		if float(st[0]) <= scroll+12.0*k(): out = str(st[1])
	return out

# --- Drawing -----------------------------------------------------------------------------

## The roll's lines in its window, drawn round (the start follows the end),
## fading out at the top and the foot.
func draw_roll(on: Control) -> void:
	var s := k()
	var a := Kit.slip_in(age).y
	var view := on.size.y
	for turn in 2:
		var off := scroll-_total*float(turn)
		var i := maxi(_tops.bsearch(off-40.0*s)-1,0)
		while i < _tops.size() and _tops[i]-off < view:
			var st: Array = STYLES[_styles[i]]
			var mid := _tops[i]-off+float(st[4])*s*0.5
			if _styles[i] == HEAD: mid += 4.0*s
			# The mock-up's fades: 14 px at the top, 22 at the foot.
			var la := a*clampf(mid/(14.0*s),0.0,1.0)*clampf((view-mid)/(22.0*s),0.0,1.0)
			if _styles[i] == HEAD:
				var hw := Kit.text(on,Kit.MED,_words[i],Vector2(0.0,mid),10.5,s,0.26,Kit.HEAD,0.0,la)
				Kit.hair(on,Vector2(hw+10.0*s,mid),on.size.x,s,Color(Kit.RULE,Kit.RULE.a*la))
			else: Kit.text(on,int(st[0]),_words[i],Vector2(0.0,mid),float(st[1]),s,float(st[2]),st[3],0.0,la)
			i += 1

func _draw() -> void:
	var s := k()
	_lay_out(s)
	var arrival := Kit.slip_in(age)
	var a := arrival.y
	var slip := _slip(s)
	slip.position.x -= arrival.x*s
	_window.position.x = slip.position.x+30.0*s
	Kit.slip(self,slip,s,a)
	var x := slip.position.x+Kit.LABEL_X*s
	var y := slip.position.y+8.0*s
	Kit.head(self,slip,y,s,"Credits",30.0,0.0,38.0,a)
	y += 30.0*s
	# The name, who made it.
	Kit.text(self,Kit.SERIF,GAME_NAME,Vector2(x,y+25.0*s),27.0,s,0.18,Kit.INK,0.0,a)
	Kit.text(self,Kit.MED,"A GAME BY",Vector2(x,y+58.5*s),10.5,s,0.14,Kit.DIM,0.0,a)
	Kit.text(self,Kit.NUM,GAME_BY,Vector2(x,y+77.0*s),17.0,s,0.06,Kit.INK,0.0,a)
	y += 89.0*s
	Kit.head(self,slip,y,s,_section(),34.0,8.0,38.0,a)
	y += (34.0+4.0+ROLL_H)*s
	Kit.head(self,slip,y,s,"Type",34.0,8.0,38.0,a)
	y += 36.0*s
	for l: String in _type_lines:
		Kit.text(self,Kit.MED,l,Vector2(x,y+9.0*s),14.0,s,0.06,Kit.INK,0.0,a)
		y += 18.0*s
	Kit.text(self,Kit.MED,TYPE_LICENCE,Vector2(x,y+8.0*s),12.0,s,0.06,Kit.DIM,0.0,a)
	y += 16.0*s
	draw_rows(slip,y,s,30.0,15.0,42.0,a)
	draw_footer([["Up Down","Stick","scroll"],P_BACK],s)
