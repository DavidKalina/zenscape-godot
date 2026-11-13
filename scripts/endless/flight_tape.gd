class_name FlightTape
extends RefCounted
## A flight kept frame by frame, to be drawn again later from any camera
## (scripts/endless/flight_replay.gd, tools/movie.py). `--record=FILE` on the
## game's command line (`--record` alone: res://scratch/flights/<date>.flight)
## writes one row per frame of the flight proper (not the menu's takeoff):
## the frame's time, the camera as drawn, the hour, the input, and every
## number the plane (SkyPlane) and the landing (ManualLanding) hold, so the
## replay sets them back and the figure, the spray, the sound and the land
## read what they read in the flight. A frame's events (a touch, a bounce)
## follow its row.
##
## The file: "ZFT1", then records of [kind u8][bytes u32][payload].
##   HEAD   json: the seed, the world, the launch flags and the columns. A
##          new head starts a new take (the scene stood again: a door, a
##          restart).
##   FRAME  float32s: OWN, then the plane's columns, then the landing's.
##   EVENTS var_to_str of the frame's events, after its row.
## tools/movie.py reads the heads and the first column (the frame's delta).

const MAGIC := "ZFT1"
const HEAD := 1
const FRAME := 2
const EVENTS := 3
## A frame's own columns, before the plane's and the landing's.
const OWN: Array[String] = ["delta","cam_x","cam_y","cam_z","cam_qx","cam_qy","cam_qz","cam_qw","fov","phase","flaps",
	"turn","pitch","lean","boost","brake","roll","look_x","look_y"]
## The kinds of field kept: a number, a switch, a vector.
const KINDS: Array[int] = [TYPE_FLOAT,TYPE_INT,TYPE_BOOL,TYPE_VECTOR2,TYPE_VECTOR3]
const DIR := "res://scratch/flights"

static var on := false
static var path := ""
static var _file: FileAccess
static var _game := 0
static var _plane: Array = []
static var _landing: Array = []
static var _row := PackedFloat32Array()
static var _rows := 0

## Starts the tape when the launch flags ask for it. Once only: the scene
## stood again carries on in the same file, as a new take.
static func begin(args: PackedStringArray) -> void:
	if on: return
	for a in args:
		if a == "--record": _open("%s/%s.flight" % [DIR,Time.get_datetime_string_from_system().replace(":","").replace("-","").replace("T","-")])
		elif a.begins_with("--record="): _open(a.get_slice("=",1))

static func _open(to: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(to.get_base_dir()))
	_file = FileAccess.open(to,FileAccess.WRITE)
	if _file == null:
		push_warning("--record: can't write %s" % to)
		return
	_file.store_buffer(MAGIC.to_ascii_buffer())
	path = to
	on = true
	print("flight tape: recording to %s" % ProjectSettings.globalize_path(to))

## The fields of `o` a tape keeps: [[name, type], ...], its script's numbers,
## switches and vectors.
static func fields_of(o: Object) -> Array:
	var out := []
	for p: Dictionary in o.get_property_list():
		if int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE and int(p.type) in KINDS: out.append([String(p.name),int(p.type)])
	return out

## How many columns `fields` take.
static func width_of(fields: Array) -> int:
	var n := 0
	for f: Array in fields:
		n += 3 if int(f[1]) == TYPE_VECTOR3 else (2 if int(f[1]) == TYPE_VECTOR2 else 1)
	return n

## The frame just flown: `game` is the endless flight, `input` what the plane
## was given and `events` what the landing said of it.
static func frame(game: Node, delta: float, input: Dictionary, events: Dictionary) -> void:
	if not on: return
	var plane: Object = game.plane
	var landing: Object = game.hand_landing
	if _game != game.get_instance_id():
		_game = game.get_instance_id()
		_head(game,plane,landing)
	var camera: Camera3D = game.camera
	var at := camera.global_position
	var q := camera.global_basis.orthonormalized().get_rotation_quaternion()
	var look: Vector2 = input.get("look",Vector2.ZERO)
	var phase := 0.0
	if game.look != null: phase = float(game.look.celestial.phase)
	var own: Array[float] = [delta,at.x,at.y,at.z,q.x,q.y,q.z,q.w,camera.fov,phase,1.0 if game.flaps else 0.0,
		float(input.get("turn",0.0)),float(input.get("pitch",0.0)),float(input.get("lean",0.0)),float(input.get("boost",0.0)),
		float(input.get("brake",0.0)),float(input.get("roll",0.0)),look.x,look.y]
	for i in own.size(): _row[i] = own[i]
	var n := _put(plane,_plane,own.size())
	_put(landing,_landing,n)
	_write(FRAME,_row.to_byte_array())
	if not events.is_empty(): _write(EVENTS,var_to_str(_plain(events)).to_utf8_buffer())
	_rows += 1
	if _rows % 240 == 0: _file.flush()

## What is written so far is on the disk (the scene leaving the tree).
static func flush() -> void:
	if on: _file.flush()

static func _head(game: Node, plane: Object, landing: Object) -> void:
	_plane = fields_of(plane)
	_landing = fields_of(landing)
	_row.resize(OWN.size()+width_of(_plane)+width_of(_landing))
	var head := {"v":1,"at":Time.get_datetime_string_from_system(),"seed":int(game.seed),"world":str(game.world.id),
		"weight":str(game.weight),"pace":str(game.pace),"args":Array(preload("res://scripts/launch_args.gd").own_args()),
		"own":OWN,"plane":_plane,"landing":_landing}
	_write(HEAD,JSON.stringify(head).to_utf8_buffer())

static func _write(kind: int, bytes: PackedByteArray) -> void:
	_file.store_8(kind)
	_file.store_32(bytes.size())
	_file.store_buffer(bytes)

static func _put(o: Object, fields: Array, from: int) -> int:
	var i := from
	for f: Array in fields:
		var v: Variant = o.get(f[0])
		match int(f[1]):
			TYPE_VECTOR3:
				var v3: Vector3 = v
				_row[i] = v3.x
				_row[i+1] = v3.y
				_row[i+2] = v3.z
				i += 3
			TYPE_VECTOR2:
				var v2: Vector2 = v
				_row[i] = v2.x
				_row[i+1] = v2.y
				i += 2
			TYPE_BOOL:
				_row[i] = 1.0 if v else 0.0
				i += 1
			_:
				_row[i] = float(v)
				i += 1
	return i

## `v` with only what a tape can hold and give back: numbers, words, vectors
## and lists of them.
static func _plain(v: Variant) -> Variant:
	match typeof(v):
		TYPE_DICTIONARY:
			var d := {}
			var from: Dictionary = v
			for k: Variant in from:
				var got: Variant = _plain(from[k])
				if got != null: d[str(k)] = got
			return d
		TYPE_ARRAY:
			var a := []
			var list: Array = v
			for e: Variant in list:
				var got: Variant = _plain(e)
				if got != null: a.append(got)
			return a
		TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_VECTOR2, TYPE_VECTOR3: return v
		TYPE_STRING_NAME: return str(v)
	return null

## The takes in the tape at `from`: [{head, width, data (every row end to
## end), times (seconds at each row, from 0), events ({row: Dictionary})}].
## Empty when it can't be read. A row cut short at the end (a run killed) is
## dropped.
static func read(from: String) -> Array:
	var bytes := FileAccess.get_file_as_bytes(from)
	var out := []
	if bytes.size() < 4 or bytes.slice(0,4).get_string_from_ascii() != MAGIC:
		push_error("flight tape: %s is not a tape" % from)
		return out
	var i := 4
	var take := {}
	while i+5 <= bytes.size():
		var kind := bytes.decode_u8(i)
		var n := bytes.decode_u32(i+1)
		i += 5
		if i+n > bytes.size(): break
		var payload := bytes.slice(i,i+n)
		i += n
		if kind == HEAD:
			var head: Variant = JSON.parse_string(payload.get_string_from_utf8())
			if not head is Dictionary: break
			var h: Dictionary = head
			var plane_f: Array = h.get("plane",[])
			var landing_f: Array = h.get("landing",[])
			var own_f: Array = h.get("own",[])
			take = {"head":h,"width":own_f.size()+width_of(plane_f)+width_of(landing_f),"data":PackedFloat32Array(),
				"times":PackedFloat64Array(),"events":{}}
			out.append(take)
		elif take.is_empty(): continue
		elif kind == FRAME:
			var row := payload.to_float32_array()
			if row.size() != int(take.width): continue
			var data: PackedFloat32Array = take.data
			var times: PackedFloat64Array = take.times
			times.append(0.0 if times.is_empty() else times[times.size()-1]+float(row[0]))
			data.append_array(row)
			take.data = data
			take.times = times
		elif kind == EVENTS:
			var got: Variant = str_to_var(payload.get_string_from_utf8())
			var times: PackedFloat64Array = take.times
			if got is Dictionary and not times.is_empty():
				var events: Dictionary = take.events
				events[times.size()-1] = got
	return out
