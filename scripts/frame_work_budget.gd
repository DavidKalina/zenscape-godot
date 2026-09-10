extends RefCounted
## Optional cooperative budget for expensive authoring loops. A null tree keeps
## the deterministic synchronous path used by loading, undo and offline tools.
var _tree: SceneTree
var _frame := Signal()
var _started := 0
const USEC := 2000
func _init(tree: SceneTree = null, frame := Signal()) -> void:
	_tree = tree
	if tree != null: _frame = tree.process_frame if frame.is_null() else frame
	_started = Time.get_ticks_usec()
func checkpoint() -> Variant:
	if _tree != null and Time.get_ticks_usec()-_started >= USEC:
		# Return the signal rather than suspending a method on this helper. Its
		# caller may disappear before the next frame. The one-shot reset owns
		# only the budget, and releases it when the frame arrives (or tree exits).
		var budget := self
		_frame.connect(func() -> void: budget._started = Time.get_ticks_usec(),CONNECT_ONE_SHOT)
		return _frame
	return null
