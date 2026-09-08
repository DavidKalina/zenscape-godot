extends RefCounted
## Optional cooperative budget for expensive authoring loops. A null tree keeps
## the deterministic synchronous path used by loading, undo and offline tools.
var _tree: SceneTree
var _started := 0
const USEC := 2000
func _init(tree: SceneTree = null) -> void:
	_tree = tree
	_started = Time.get_ticks_usec()
func checkpoint() -> void:
	if _tree != null and Time.get_ticks_usec()-_started >= USEC:
		await _tree.process_frame
		_started = Time.get_ticks_usec()
