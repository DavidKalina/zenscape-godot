extends RefCounted
## The cumulus' tiling noise volume, made once a run and shared by the
## towering cumulus (scripts/sky_towers.gd) and the near cloud sea's heaps
## (scripts/sky_sea.gd), so both are the one cloud (shaders/
## cumulus_light.gdshaderinc): in red the cauliflower's round bumps
## (cellular, inverted so each cell is a dome, two octaves), in green the
## soft wisps (fbm). One texture, so a step reads both at once.
##
## The slices are worked out on whichever thread asks first (`slices`: a
## tower's worker, or the sea's `request`); only the texture is made on the
## main thread (`texture`).

## The volume's size (texels a side).
const NOISE := 64

static var _texture: ImageTexture3D
static var _lock := Mutex.new()
static var _made: Array[Image] = []
static var _task := -1

## The texture, made from the slices (worked out here if no one has yet).
static func texture() -> ImageTexture3D:
	if _texture != null: return _texture
	_texture = ImageTexture3D.new()
	_texture.create(Image.FORMAT_RG8,NOISE,NOISE,NOISE,false,slices())
	return _texture

## The texture if it is ready, else null, the slices set going on a worker
## the first time, so the main thread never works them out.
static func request() -> ImageTexture3D:
	if _texture != null: return _texture
	if ready():
		settle()
		return texture()
	if _task == -1: _task = WorkerThreadPool.add_task(_work,false,"Cumulus noise")
	return null

## Waits for `request`'s worker, if one is going (every task is waited on,
## and before the run ends).
static func settle() -> void:
	if _task < 0: return
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -2

static func _work() -> void:
	slices()

## Whether the slices are worked out.
static func ready() -> bool:
	_lock.lock()
	var done := not _made.is_empty()
	_lock.unlock()
	return done

## The volume's slices, worked out once a run, on whichever thread asks
## first; the rest wait for them.
static func slices() -> Array[Image]:
	_lock.lock()
	if _made.is_empty(): _made = _make()
	var made := _made
	_lock.unlock()
	return made

static func _make() -> Array[Image]:
	var bumps := FastNoiseLite.new()
	bumps.seed = 31
	bumps.noise_type = FastNoiseLite.TYPE_CELLULAR
	bumps.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	bumps.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	bumps.frequency = 5.0/NOISE
	bumps.fractal_type = FastNoiseLite.FRACTAL_FBM
	bumps.fractal_octaves = 2
	bumps.fractal_lacunarity = 3.0
	bumps.fractal_gain = 0.32
	var wisps := FastNoiseLite.new()
	wisps.seed = 57
	wisps.noise_type = FastNoiseLite.TYPE_PERLIN
	wisps.frequency = 7.0/NOISE
	wisps.fractal_type = FastNoiseLite.FRACTAL_FBM
	wisps.fractal_octaves = 3
	var red: Array[Image] = bumps.get_seamless_image_3d(NOISE,NOISE,NOISE,true,0.15,true)
	var green: Array[Image] = wisps.get_seamless_image_3d(NOISE,NOISE,NOISE,false,0.15,true)
	var out: Array[Image] = []
	for z in range(NOISE):
		var r := red[z].get_data()
		var g := green[z].get_data()
		var both := PackedByteArray()
		both.resize(r.size()*2)
		for i in range(r.size()):
			both[i*2] = r[i]
			both[i*2+1] = g[i]
		out.append(Image.create_from_data(NOISE,NOISE,false,Image.FORMAT_RG8,both))
	return out
