extends "res://studies/character_study.gd"
## The enemy yard: a greybox arena
## in open sky for trying an enemy against the pilot, in the interactables
## yard's style (the character study's grey structure; this extends it, so
## the motor, figure, camera, F1 numbers, F2 feel and recorder are the
## character study's). Laid out for the bullfight (scripts/enemies/plinth_ram.gd):
##   - an open isle, 24 by 26 m, its rims open over the drop: open ground
##     in the middle (a dodge there is a miss it comes back from), rims all
##     round to bait it toward, and every rim hangs (step off it slowly);
##   - the spit: a 2.5 m wide, 9 m long tongue off the south rim. Stand at
##     its tip and the dodge is risky (a slide aside goes off it too, unless
##     you hang) and sure (any miss there sends it over);
##   - two low boulders to bait it into (it stuns on them, a stone to stand on);
##   - along the north side a ledge 1.2 m up, orange-lipped, out of its reach;
##   - west, an islet over a 2.5 m gap (a long jump): it won't charge across.
## R sets him back and brings the enemies back.
##   --enemy=NAME   which enemy (ENEMIES; `none` for an empty yard); the
##                  pilot is set down facing it. Default: ram.
## Adding an enemy is one line in ENEMIES: its script, where it stands, where
## the pilot starts (it is faced toward the pilot, and he toward it).
##   godot --path . res://studies/enemy_yard.tscn -- --no-title --enemy=ram
## Greybox sounds: the enemies' sound calls play short synthesized
## placeholders (`_voice`), a thump, a huff, a snort, a scrape, a bellow.
const EnemyField = preload("res://scripts/enemies/enemy_field.gd")
const PlinthRam = preload("res://scripts/enemies/plinth_ram.gd")

## name: {script, at (the enemy), pilot (where he starts), knobs (overrides)}.
const ENEMIES := {
	"ram":{"script":PlinthRam,"at":Vector3(0.0,0.0,-3.0),"pilot":Vector3(0.0,0.0,7.0)},
}
const DEFAULT_ENEMY := "ram"
const YARD_LOST := -20.0
## The isle, its spit (south), its ledge (north, up to LEDGE_TOP), the
## islet over the gap (west), the boulders ([middle, radius, top]); x, z.
const ISLE := Rect2(-12.0,-14.0,24.0,26.0)
const SPIT := Rect2(-1.25,12.0,2.5,9.0)
const LEDGE := Rect2(-6.0,-14.0,12.0,3.0)
const LEDGE_TOP := 1.2
const ISLET := Rect2(-19.0,-4.0,4.5,8.0)
const BOULDERS := [[Vector2(-7.0,-2.0),0.8,0.8],[Vector2(7.0,4.0),0.8,0.8]]

var enemies: Node
var enemy_name := DEFAULT_ENEMY
var _voices := {}

func _ready() -> void:
	pack = "enemy_yard"
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg.begins_with("--enemy="): enemy_name = arg.get_slice("=",1)
	super._ready()

## The yard's one station, not a pack's file.
func _load_pack() -> void:
	var entry: Dictionary = ENEMIES.get(enemy_name,ENEMIES[DEFAULT_ENEMY])
	var pilot: Vector3 = entry.pilot
	var at: Vector3 = entry.at
	var face := Vector2(at.x-pilot.x,at.z-pilot.z).normalized()
	start = pilot
	start_face = face
	lost = YARD_LOST
	_last_stood = start
	var parts := [
		["box",ISLE,-2.0,0.0,"floor"],
		["box",SPIT,-2.0,0.0,"floor"],
		["box",LEDGE,-2.0,LEDGE_TOP,"lip"],
		["box",ISLET,-2.0,0.0,"floor"],
		["ticks",Vector2(12.6,ISLE.end.y),Vector2(12.6,ISLE.position.y),1.0,5],
		["label",Vector3(0.0,0.6,SPIT.end.y-0.6),"the spit"],
	]
	for b: Array in BOULDERS: parts.append(["cyl",b[0],b[1],0.0,b[2],"grey"])
	stations = [{"key":1,"name":"Enemy yard","spawn":pilot,"face":face,"sign":Vector3(-9.0,3.0,11.0),"parts":parts}]

func _build_room() -> void:
	super._build_room()
	enemies = EnemyField.new()
	enemies.attach(self)
	enemies.sound_hook = _voice
	if ENEMIES.has(enemy_name):
		var entry: Dictionary = ENEMIES[enemy_name]
		var at: Vector3 = entry.at
		enemies.spawn(entry.script,at,Vector2(start.x-at.x,start.z-at.z).normalized(),entry.get("knobs",{}))

## Set down, the enemies back as they began.
func place(at: Vector3, face: Vector2) -> void:
	super.place(at,face)
	if enemies != null: enemies.reset()

func _hint_text() -> String:
	return "Enemy yard: %s · you are the red flag: let it come, and when its head locks down (deep red, a snort) jump its horns, run or slide out of its line, or drop into a rim hang · near a rim (or out on the spit) it goes over; in the open it comes again · R start (the enemies too) · F1 numbers · F2 feel · Esc mouse" % enemy_name

func _show_hud() -> void:
	super._show_hud()
	if not _hud.visible or enemies == null: return
	var lines := PackedStringArray([_hud.text,""])
	for e: Node3D in enemies.enemies:
		lines.append("%s  %s %.1fs · %.1f m/s · %s · tells %d" % [e.name,e.state,e.state_t,Vector2(e.vel.x,e.vel.z).length(),"on ground" if e.grounded else "falling",e.told_count])
	lines.append("fallen and gone: %d" % enemies.gone_count)
	_hud.text = "\n".join(lines)

# --- Placeholder sounds ------------------------------------------------------------

## [seconds, tone (Hz, 0 none), tone at the end, noise share, low-pass (0-1),
## attack (s), tremolo (Hz, 0 none)].
const VOICES := {
	"ram_huff":[0.35,0.0,0.0,1.0,0.12,0.12,0.0],
	"ram_paw":[0.14,90.0,60.0,0.6,0.3,0.005,0.0],
	"ram_charge":[0.3,70.0,50.0,0.5,0.15,0.02,30.0],
	"ram_snort":[0.28,0.0,0.0,1.0,0.35,0.01,0.0],
	"ram_scrape":[0.6,0.0,0.0,1.0,0.6,0.02,0.0],
	"ram_scrabble":[0.45,0.0,0.0,1.0,0.45,0.01,24.0],
	"ram_bellow":[0.9,120.0,70.0,0.15,0.5,0.08,0.0],
	"ram_thud":[0.2,55.0,40.0,0.4,0.2,0.003,0.0],
}

## Plays enemy sound `sound_name` at `at` (a short synthesized placeholder).
func _voice(sound_name: StringName, at: Vector3) -> void:
	var key := String(sound_name)
	if not VOICES.has(key): key = "ram_paw"
	if not _voices.has(key): _voices[key] = _synth(VOICES[key])
	var player := AudioStreamPlayer3D.new()
	player.stream = _voices[key]
	player.position = at
	player.unit_size = 6.0
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

static func _synth(v: Array) -> AudioStreamWAV:
	var rate := 22050
	var n := int(float(v[0])*rate)
	var data := PackedByteArray()
	data.resize(n*2)
	var rng := RandomNumberGenerator.new()
	rng.seed = n
	var low := 0.0
	var phase := 0.0
	for i in range(n):
		var t := float(i)/rate
		var k := t/float(v[0])
		var env := minf(t/maxf(float(v[5]),0.001),1.0)*pow(1.0-k,1.5)
		if float(v[6]) > 0.0: env *= 0.5+0.5*sin(TAU*float(v[6])*t)
		low = lerpf(low,rng.randf_range(-1.0,1.0),float(v[4]))
		var tone := 0.0
		if float(v[1]) > 0.0:
			phase += lerpf(float(v[1]),float(v[2]),k)/rate
			tone = fposmod(phase,1.0)*2.0-1.0
		var s := clampf((low*float(v[3])+tone*(1.0-float(v[3])))*env*0.8,-1.0,1.0)
		data.encode_s16(i*2,int(s*32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav
