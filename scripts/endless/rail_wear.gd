extends RefCounted
## The railway's weathered surfaces: one shared wear map and the materials
## that read it (shaders/rail_track.gdshader for the ballast, sleepers and
## rails, shaders/rail_stop.gdshader for the stops). Made once, on first ask;
## the wear map is 256 x 256 (about 200 KB), nothing per piece.
##
## `track(mode, inside)`: mode 0 ballast, 1 sleepers, 2 rails. `inside` is the
## material for a piece in a tunnel (no sky fill: the bore lights it).
## `stop()`: the stops' paint. Any other railway kit can take `track(1)` for
## its own sleepers and `stop()` for boards, to look the same.

const TRACK_SHADER = preload("res://shaders/rail_track.gdshader")
const STOP_SHADER = preload("res://shaders/rail_stop.gdshader")
const SIZE := 256

static var _wear: ImageTexture
static var _track: Dictionary = {}
static var _stop: ShaderMaterial

## The wear map: R wide blotches, G medium, B fine grit; seamless.
static func wear_map() -> ImageTexture:
	if _wear != null: return _wear
	var chans: Array[PackedByteArray] = []
	for k in 3:
		var n := FastNoiseLite.new()
		n.seed = 4100+k*97
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.fractal_type = FastNoiseLite.FRACTAL_FBM
		n.fractal_octaves = 3 if k < 2 else 2
		n.frequency = [0.012,0.03,0.09][k]
		var img := n.get_seamless_image(SIZE,SIZE)
		img.convert(Image.FORMAT_L8)
		var d := img.get_data()
		# Stretch to the full range, so a threshold means the same on each.
		var lo := 255
		var hi := 0
		for v in d:
			lo = mini(lo,v)
			hi = maxi(hi,v)
		var out := PackedByteArray()
		out.resize(d.size())
		var span := float(maxi(hi-lo,1))
		for i in d.size():
			out[i] = clampi(int(float(d[i]-lo)/span*255.0),0,255)
		chans.append(out)
	var data := PackedByteArray()
	data.resize(SIZE*SIZE*3)
	for i in SIZE*SIZE:
		data[i*3] = chans[0][i]
		data[i*3+1] = chans[1][i]
		data[i*3+2] = chans[2][i]
	var im := Image.create_from_data(SIZE,SIZE,false,Image.FORMAT_RGB8,data)
	im.generate_mipmaps()
	_wear = ImageTexture.create_from_image(im)
	return _wear

static func track(mode: int, inside := false) -> ShaderMaterial:
	var key := mode+(10 if inside else 0)
	if _track.has(key): return _track[key]
	var m := ShaderMaterial.new()
	m.shader = TRACK_SHADER
	m.set_shader_parameter("wear_tex",wear_map())
	m.set_shader_parameter("mode",mode)
	if inside: m.set_shader_parameter("fill",0.0)
	_track[key] = m
	return m

static func stop() -> ShaderMaterial:
	if _stop == null:
		_stop = ShaderMaterial.new()
		_stop.shader = STOP_SHADER
		_stop.set_shader_parameter("wear_tex",wear_map())
	return _stop
