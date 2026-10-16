extends RefCounted
## The motif isles' native kernels (native/terrain_kernels/isle_kernels.h,
## `ZenScapeIsleKernels`): the
## number crunching of an isle's build (the stone, the growth, the levels, the
## hulls) as pure-data calls, packed arrays in and out, safe on any worker.
## Null when the library is not built (or lacks the isle kernels), or under
## `--gdscript-kernels`: then every caller runs its GDScript, which gives the
## very same arrays.
## The kernels' version this GDScript calls (ZenScapeIsleKernels `version`): a
## library built before them is left unused, not half-called.
const VERSION := 2
static var _kernel: Object
static var _attempted := false
static var _lock := Mutex.new()

static func get_kernel() -> Object:
	if _attempted: return _kernel
	_lock.lock()
	if not _attempted:
		var args := OS.get_cmdline_user_args()
		if not args.has("--gdscript-kernels"):
			var path := "res://native/terrain_kernels/zenscape_kernels.gdextension"
			if not ClassDB.class_exists("ZenScapeIsleKernels") and FileAccess.file_exists(path):
				GDExtensionManager.load_extension(path)
			if ClassDB.class_exists("ZenScapeIsleKernels"):
				var kernel: Object = ClassDB.instantiate("ZenScapeIsleKernels")
				if kernel.has_method("version") and int(kernel.version()) == VERSION:
					_kernel = kernel
					# The engine's own sin, cos, atan2 and colour curve (as off
					# macOS), to check they give the same as the local ones.
					if args.has("--engine-math"): kernel.set_engine_math(true)
				else: push_warning("ZenScapeIsleKernels is not version %d: rebuild it (tools/build_native_kernels.py); the isles are built in GDScript" % VERSION)
		_attempted = true
	_lock.unlock()
	return _kernel
