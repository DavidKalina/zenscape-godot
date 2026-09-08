extends SceneTree
## A live edit must yield between chunks and produce the same safe-cell map.
class FlatGround extends RefCounted:
	var ponds: Array[Dictionary] = []
	var streams: Array[Dictionary] = []
	var objects: Array[Dictionary] = []
	var calls := 0
	func ground_height(_point: Vector2) -> float:
		calls += 1
		return 0.0
	func waterfall_impacts() -> Array[Dictionary]: return []
func _initialize() -> void:
	var data := FlatGround.new()
	var sync := CreatureNavigation.new()
	sync.rebuild(data,Callable(),0.35,0.3)
	var sliced := CreatureNavigation.new()
	sliced.begin_rebuild(data,Callable(),0.35,0.3)
	assert(not sliced.advance_rebuild(1),"One tiny slice must yield")
	assert(sliced._nodes.size()<sync._nodes.size(),"Cannot scan the full map before yielding")
	assert(sliced.path(Vector3.ZERO,Vector3.ONE).is_empty(),"No routes may escape a partial map")
	# A newer edit replaces a partially built map.
	sliced.begin_rebuild(data,Callable(),0.35,0.3)
	var slices := 0
	while not sliced.advance_rebuild(1000): slices += 1
	assert(slices>0)
	assert(sliced._nodes==sync._nodes and sliced._cells==sync._cells,"Sliced and synchronous maps must agree exactly")
	print("NAVIGATION BUDGET PASS slices=",slices)
	quit()
