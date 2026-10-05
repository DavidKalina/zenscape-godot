extends SceneTree
const Plate = preload("res://scripts/plate.gd")
const Stepping = preload("res://scripts/stepping_route.gd")
## The fixture sits on the walking grid (0.35 m steps from the plate's corner),
## as it did at the origin of the 28 m plate: its centre is the node nearest
## the origin.
const AT := roundf(Plate.HALF/0.35)*0.35-Plate.HALF
class Stones extends RefCounted:
	var ponds: Array[Dictionary] = []
	var streams: Array[Dictionary] = [{"pts":[{"x":AT,"z":-Plate.HALF,"h":-0.5},{"x":AT,"z":Plate.HALF,"h":-0.5}],"width":1.8,"surface":0.05}]
	var objects: Array[Dictionary] = []
	var stone := true
	func ground_height(p: Vector2) -> float:
		return 0.0 if absf(p.x-AT)>1.0 or (stone and absf(p.x-AT)<0.36 and absf(p.y-AT)<0.6) else -0.8
	func waterfall_impacts() -> Array[Dictionary]: return []
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var data := Stones.new()
	var nav := CreatureNavigation.new()
	nav.rebuild(data,Callable(),0.35,0.3)
	var from := Vector3(-3+AT,0,AT)
	var to := Vector3(3+AT,0,AT)
	check(nav.path(from,to).is_empty(),"The stepping stone is separated by real water gaps")
	var planner := Stepping.new()
	var plan: Dictionary = await planner.plan(nav,self,from,to,func() -> bool: return true)
	check(not plan.is_empty() and plan.hops.size()>=2,"A planned outing hops onto and off the stone")
	if not plan.is_empty():
		for i in range(1,plan.points.size()):
			check(Stepping.hop_safe(nav,plan.points[i-1],plan.points[i]) if plan.hops.has(i) else nav.segment_safe(plan.points[i-1],plan.points[i]),"Every leg has checked footing or a clear hop arc")
		var actor := CreatureActor.new()
		root.add_child(actor)
		actor.setup("res://assets/models/zenscape-bigfoot-breathing.glb")
		var index: int = plan.hops.keys()[0]
		actor.reset_at(plan.points[index-1])
		check(actor.begin_hop(plan.points[index]),"The actor starts a planned hop")
		for i in range(21): actor.advance(1.0/60.0)
		check(actor.state==CreatureActor.State.HOPPING and actor.position.y>0.35,"The actor rises above the water along the arc")
		for i in range(240): actor.advance(1.0/60.0)
		check(actor.can_roam() and actor.position.distance_to(plan.points[index])<0.01,"The landing performance ends on the checked stone")
		actor.free()
	var detour: Dictionary = await planner.plan(nav,self,Vector3(-3+AT,0,2+AT),Vector3(3+AT,0,2+AT),func() -> bool: return true)
	check(not detour.is_empty() and detour.hops.size()>=2,"He can walk along the bank to a stone away from the direct line to his destination")
	data.stone = false
	nav.rebuild(data,Callable(),0.35,0.3)
	var removed: Dictionary = await planner.plan(nav,self,from,to,func() -> bool: return true)
	check(removed.is_empty(),"Removing the middle stone leaves no crossing")
	var cancelled: Dictionary = await planner.plan(nav,self,from,to,func() -> bool: return false)
	check(cancelled.is_empty(),"Cancelled planning cannot publish a route")
	print("STEPPING ROUTE: failures=",failures)
	quit(1 if failures else 0)
