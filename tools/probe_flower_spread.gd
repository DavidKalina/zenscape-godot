extends SceneTree
## Main-thread cost of the other kinds' pollen (scripts/dandelion_seeds.gd) on
## a ~4,400-flower meadow: reindex, a breeze step, and a wind-tool gust step.
## Headless: godot --headless --path . -s res://tools/probe_flower_spread.gd
const Seeds = preload("res://scripts/dandelion_seeds.gd")
const FlowerSowing = preload("res://scripts/flower_sowing.gd")
const Emergence = preload("res://scripts/emergence.gd")
const PlateFixture := preload("res://tests/fixtures/plate.gd")

class Gust extends Node3D:
	var gusts: Array = []
	var wakes: Array = []
	func aiming() -> bool: return true
	func blow_at(p: Vector2, _m := 0.0, _ph := 0.0) -> Vector3:
		return Vector3(1.0,0.0,0.0) if absf(p.y) < 2.5 else Vector3.ZERO

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var data := NativeTerrainData.new()
	data.setup(PlateFixture.mesh())
	data.reset_flat()
	var kinds := ["poppy","oxeye_daisy","cosmos","buttercup"]
	for i in range(66):
		for j in range(66):
			data.place(kinds[(i+j)%4],Vector2(i-33,j-33)*0.4,0.0,1.0)
	var plate := Node3D.new()
	root.add_child(plate)
	var seeds: Node3D = Seeds.new()
	seeds.data = data
	seeds.sowing_for = func(slot: String) -> RefCounted: return FlowerSowing.new(data,slot,41)
	seeds.set_process(false)
	plate.add_child(seeds)
	var t := Time.get_ticks_usec()
	seeds.reindex()
	print("PROBE reindex %d flowers: %.2f ms" % [data.objects.size(),(Time.get_ticks_usec()-t)/1000.0])
	seeds.air_override = Vector2(1.0,0.0)
	var worst := 0
	var total := 0
	for i in range(600):
		Emergence.time += 1.0/60.0
		seeds.step(1.0/60.0)
		worst = maxi(worst,seeds.last_step_usec)
		total += seeds.last_step_usec
	print("PROBE breeze step: mean %.3f ms, worst %.3f ms, grains in air %d" % [total/600000.0,worst/1000.0,seeds.pollen_in_air()])
	var gust := Gust.new()
	seeds.add_child(gust)
	seeds.gust = gust
	worst = 0
	total = 0
	for i in range(600):
		Emergence.time += 1.0/60.0
		seeds.step(1.0/60.0)
		worst = maxi(worst,seeds.last_step_usec)
		total += seeds.last_step_usec
	print("PROBE gust step: mean %.3f ms, worst %.3f ms, grains in air %d" % [total/600000.0,worst/1000.0,seeds.pollen_in_air()])
	quit()
