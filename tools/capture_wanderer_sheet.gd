extends SceneTree
## The wanderer beside his character sheet (docs/design/wanderer-look/): the
## walker's figure (scripts/pilot_figure.gd, assets/models/pilot.glb) standing
## on a dark stage lit as the sheet is, turned round front, side, back and
## three-quarters, then floating under the cap (scripts/pocket_sail_figure.gd:
## held over his head; front, three-quarters, side, from the chase camera's
## height, and tipped into a turn) and seen from the chase camera's height
## behind him. Writes DIR/turnaround.png,
## DIR/vs_sheet.png (the sheet's turnaround over ours, if --sheet= names the
## sheet), DIR/cap_float.png, DIR/chase.png, and quits.
## Rendered only when asked for (needs a window):
##   Godot --windowed --path . -s res://tools/capture_wanderer_sheet.gd -- --no-title --out=DIR [--sheet=PNG]
const PilotFigure = preload("res://scripts/pilot_figure.gd")
const PocketSailFigure = preload("res://scripts/pocket_sail_figure.gd")
## Each tile's size (px), and the sheet's turnaround (its px: x, y, w, h).
const TILE := Vector2i(420,560)
const SHEET_TURNAROUND := Rect2i(490,95,640,240)

## What the figure reads of the motor.
class Motor:
	extends RefCounted
	var facing := 0.0
	var grounded := true
	var skidding := false
	var flip := -1.0
	var velocity := Vector3.ZERO
	var feet := Vector3.ZERO
	var pace := 0.0
	var move := ""
	func speed() -> float: return pace

var out := "/tmp/wanderer_sheet"
var sheet := ""
var figure: Node3D
var sail: Node3D
var camera: Camera3D
var motor := Motor.new()
var turning := 0.0

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
		if arg.begins_with("--sheet="): sheet = arg.trim_prefix("--sheet=")
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(240.0).timeout.connect(func() -> void: push_error("wanderer sheet capture timed out"); quit(2))
	root.size = TILE
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("0b0b0c")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8a8f99")
	environment.ambient_light_energy = 0.6
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	stage.add_child(world)
	var key := DirectionalLight3D.new()
	# The key from his front left and above, as the sheet's; a cool rim
	# from behind.
	key.rotation_degrees = Vector3(-35.0,150.0,0.0)
	key.light_color = Color("fff1dc")
	key.light_energy = 1.3
	stage.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20.0,-20.0,0.0)
	rim.light_color = Color("c9d6ff")
	rim.light_energy = 0.4
	stage.add_child(rim)
	camera = Camera3D.new()
	camera.fov = 22.0
	stage.add_child(camera)
	camera.current = true
	figure = PilotFigure.new()
	stage.add_child(figure)
	sail = PocketSailFigure.new()
	figure.add_child(sail)
	figure.settle()
	for i in range(20): await _step()
	# The turnaround: he faces -Z; the camera goes round him.
	var tiles: Array[Image] = []
	for a: float in [0.0,-PI*0.5,PI,-PI*0.25]:
		_aim(Vector3(sin(a),0.0,-cos(a))*4.2+Vector3.UP*0.75,Vector3.UP*0.6)
		tiles.append(await _grab())
	var row := _row(tiles)
	row.save_png(out.path_join("turnaround.png"))
	if sheet != "":
		var picture := Image.load_from_file(sheet)
		picture.convert(Image.FORMAT_RGBA8)
		var part := picture.get_region(SHEET_TURNAROUND)
		part.resize(row.get_width(),int(row.get_width()*float(SHEET_TURNAROUND.size.y)/SHEET_TURNAROUND.size.x),Image.INTERPOLATE_LANCZOS)
		var both := Image.create(row.get_width(),part.get_height()+row.get_height(),false,Image.FORMAT_RGBA8)
		both.blit_rect(part,Rect2i(Vector2i.ZERO,part.get_size()),Vector2i.ZERO)
		both.blit_rect(row,Rect2i(Vector2i.ZERO,row.get_size()),Vector2i(0,part.get_height()))
		both.save_png(out.path_join("vs_sheet.png"))
	# From the chase camera's height (scripts/wanderer_eye.gd: 40 degrees
	# over him, behind), standing.
	_aim(Vector3(0.0,sin(0.7),cos(0.7))*4.2,Vector3.UP*0.6)
	var chase := await _grab()
	# The cap float: off the ground, the sail out, held over his head; front,
	# three-quarters, side, and from the chase camera's height behind; then
	# leaning into a turn, from behind.
	motor.grounded = false
	motor.move = "sail"
	for i in range(40): await _step(true)
	var floats: Array[Image] = []
	for a: float in [0.0,-PI*0.3,-PI*0.5]:
		_aim(Vector3(sin(a),0.1,-cos(a))*5.4+Vector3.UP*0.9,Vector3.UP*0.8)
		floats.append(await _grab(true))
	_aim(Vector3(0.0,sin(0.7),cos(0.7))*5.4+Vector3.UP*0.8,Vector3.UP*0.8)
	floats.append(await _grab(true))
	turning = 1.0
	for i in range(25): await _step(true)
	_aim(Vector3(0.0,0.15,1.0)*5.4+Vector3.UP*0.8,Vector3.UP*0.8)
	floats.append(await _grab(true))
	turning = 0.0
	_row(floats).save_png(out.path_join("cap_float.png"))
	motor.grounded = true
	motor.move = ""
	for i in range(40): await _step()
	_row([chase]).save_png(out.path_join("chase.png"))
	print("WANDERER SHEET captured ",out)
	quit(0)

func _step(open := false) -> void:
	await process_frame
	var delta := 1.0/60.0
	figure.drive(motor.pose(),delta)
	sail.update(delta,open,turning)

func _aim(at: Vector3, look: Vector3) -> void:
	camera.global_position = at
	camera.look_at(look)

func _grab(open := false) -> Image:
	for i in range(4): await _step(open)
	await RenderingServer.frame_post_draw
	# The window may be bigger than asked (a high-density screen): its
	# middle at the tile's shape, scaled to the tile.
	var image := root.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	var size := image.get_size()
	var w := mini(size.x,int(size.y*float(TILE.x)/TILE.y))
	var h := int(w*float(TILE.y)/TILE.x)
	image = image.get_region(Rect2i((size.x-w)/2,(size.y-h)/2,w,h))
	image.resize(TILE.x,TILE.y,Image.INTERPOLATE_LANCZOS)
	return image

func _row(tiles: Array[Image]) -> Image:
	var row := Image.create(TILE.x*tiles.size(),TILE.y,false,Image.FORMAT_RGBA8)
	for i in range(tiles.size()):
		var tile := tiles[i]
		row.blit_rect(tile,Rect2i(Vector2i.ZERO,TILE),Vector2i(TILE.x*i,0))
	return row
