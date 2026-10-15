extends RefCounted
## [summit] The run's end you can see and want (docs/design/roguelike/
## summit-round1.md): a fixed run length (`--summit-at=N`, 6 layers), the
## count shown as a quiet climbing mark (summit_mark.gd), the sun's gate
## far above and nearer each layer (summit_crown.gd), the last layer's gate
## an ending (run_loop.gd `_win_begin`), the win card, and the death card
## naming how close he got. Words, the sums and the small record live here;
## the rest in the files named. Off with `--no-summit` (or `--loot=off`).
const RunFeatures = preload("res://scripts/roguelike/run_features.gd")
const ItemCatalog = preload("res://scripts/roguelike/item_catalog.gd")
const RunState = preload("res://scripts/roguelike/run_state.gd")

const LAYERS := 6
## Where the summit record is kept (a test points it elsewhere).
static var record_path := "user://summit_record.json"
## The region a climb began at (run_loop sets it), so the plans' regions
## count as layers of this climb.
static var base_region := 1

const WORDS := {
	"arrive_line": "%d of %d   ·   %s",       # under a gate's caption
	"arrive_last": "THE LAST STAIR",          # the summit layer's caption
	"arrive_last_line": "the sun's gate   ·   %s",
	"title": "THE SUMMIT   %s",
	"through": "through the sun's gate",
	"carried": "carried to the top: %s",
	"carried_none": "carried nothing to the top",
	"layers": "%d layers climbed",
	"fastest_new": "the fastest summit yet",
	"fastest": "fastest summit: %s",
	"wins": "summits: %d",
	"prompt": "SPACE / A   CLIMB AGAIN",
	"near_one": "one layer from the summit",
	"near": "%d layers from the summit",
	"near_last": "on the last stair, short of the sun's gate",
}

static func on() -> bool:
	return RunFeatures.on(&"summit")

## The run's length in layers (`--summit-at=N`).
static func at() -> int:
	return maxi(int(RunFeatures.value("summit-at",str(LAYERS))),2)

## Whether `plan` (a layer's) is the summit layer of this climb, by its region.
static func final_plan(plan: Dictionary) -> bool:
	if not on(): return false
	var knobs: Dictionary = plan.get("user_knobs",plan.get("knobs",{}))
	var region := int(knobs.get("region",0))
	return region > 0 and region-base_region+1 >= at()

## 0 on the first layer, 1 on the summit's.
static func progress(depth: int) -> float:
	return clampf(float(depth-1)/float(at()-1),0.0,1.0)

## The death card's line: how close he got ("" when off).
static func near_line(fall: Dictionary) -> String:
	if not on() or bool(fall.get("summit",false)): return ""
	var left := at()-int(fall.get("depth",1))
	if left <= 0: return WORDS.near_last
	return WORDS.near_one if left == 1 else WORDS.near % left

# --- The win card -----------------------------------------------------------------

## The run's sums at the gate: the card's facts, the record kept.
static func sums(run: RunState, metres_text: String) -> Dictionary:
	run.highest = maxf(run.highest,run.best)
	run.most_runes = maxi(run.most_runes,run.haul)
	run.most_rares = maxi(run.most_rares,run.rares)
	run.save_record()
	var rec := load_record()
	var wins := int(rec.get("wins",0))+1
	var best := float(rec.get("fastest",0.0))
	var fresh := best <= 0.0 or run.time < best
	if fresh: best = run.time
	save_record({"wins":wins,"fastest":best})
	return {"summit":true,"items":run.items.duplicate(),"depth":run.depth,"runes":run.runes,"haul":run.haul,
		"rares":run.rares,"time":run.time,"height":run.best,"best":run.best,"highest":run.highest,
		"wins":wins,"fastest":best,"fastest_new":fresh and wins > 1,"metres":metres_text}

static func title(fall: Dictionary) -> String:
	return WORDS.title % String(fall.get("metres",""))

static func facts(fall: Dictionary) -> PackedStringArray:
	var held: Array = fall.get("items",[])
	var carried: String = WORDS.carried_none
	if not held.is_empty():
		var names := PackedStringArray()
		for id: StringName in held: names.append(ItemCatalog.title(id))
		carried = WORDS.carried % ", ".join(names)
	var rares := int(fall.get("rares",0))
	var tally := "%d %s" % [int(fall.runes),"rune" if int(fall.runes) == 1 else "runes"]
	if rares > 0: tally += "   ·   %d sun %s" % [rares,"glyph" if rares == 1 else "glyphs"]
	var rec: String = WORDS.fastest_new if bool(fall.get("fastest_new",false)) else WORDS.fastest % RunState.clock(float(fall.get("fastest",0.0)))
	return PackedStringArray([WORDS.through,WORDS.layers % int(fall.depth),RunState.clock(float(fall.time)),carried,tally,"",rec,WORDS.wins % int(fall.wins)])

static func load_record() -> Dictionary:
	if not FileAccess.file_exists(record_path): return {}
	var f := FileAccess.open(record_path,FileAccess.READ)
	if f == null: return {}
	var data: Variant = JSON.parse_string(f.get_as_text())
	return data if data is Dictionary else {}

static func save_record(data: Dictionary) -> void:
	var f := FileAccess.open(record_path,FileAccess.WRITE)
	if f != null: f.store_string(JSON.stringify(data))

# --- The sound ----------------------------------------------------------------------

const RATE := 22050

## The arrival's chord, a held swell of open fifths rising to a bell on the
## top: synthesised (the game ships no music), about 7 s.
static func chime() -> AudioStreamWAV:
	var length := 7.0
	var n := int(length*RATE)
	var data := PackedFloat32Array()
	data.resize(n)
	# D, A, D, F#, A, E: a bright open chord (D major add 9), swelling.
	var notes := [146.83,220.0,293.66,369.99,440.0,659.26]
	var delays := [0.0,0.25,0.55,0.9,1.3,1.9]
	for i in range(n):
		var t := float(i)/RATE
		var v := 0.0
		for k in range(notes.size()):
			var s: float = t-float(delays[k])
			if s < 0.0: continue
			var swell := smoothstep(0.0,1.6,s)*exp(-maxf(s-3.0,0.0)*0.7)
			var f: float = notes[k]
			v += (sin(TAU*f*t)+0.35*sin(TAU*f*2.0*t+0.4)+0.12*sin(TAU*f*3.0*t))*swell*(0.22 if k < 3 else 0.16)
		# The bell: the top note struck once and left to ring.
		var b := t-1.9
		if b > 0.0:
			var env := minf(b/0.004,1.0)*exp(-b*1.3)
			v += env*0.35*(sin(TAU*1318.5*t)+0.4*sin(TAU*1318.5*2.76*t)*exp(-b*5.0))
		data[i] = v
	var peak := 0.0
	for v in data: peak = maxf(peak,absf(v))
	var bytes := PackedByteArray()
	bytes.resize(n*2)
	for i in range(n): bytes.encode_s16(i*2,int(clampf(data[i]/maxf(peak,0.001)*0.85,-1.0,1.0)*32000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = bytes
	return stream
