extends SceneTree
const Genome = preload("res://scripts/cave_genome.gd")
const Inland = preload("res://scripts/inland_genome.gd")
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	print("PASS: " if ok else "FAIL: ",message)
	if not ok: failures += 1
func run() -> void:
	var surface_before := var_to_bytes(Inland.sample(37))
	var connected := true
	var clear_passages := true
	var varied := {}
	for seed_value in range(100):
		var recipe := Inland.cave(seed_value)
		var layout := Genome.sample(recipe)
		var replay: Dictionary = JSON.parse_string(JSON.stringify(recipe))
		if var_to_bytes(layout)!=var_to_bytes(Genome.sample(replay)): connected = false
		var reached := [0]
		for iteration in range(layout.rooms.size()):
			for link in layout.links:
				if link.from in reached and link.to not in reached: reached.append(link.to)
				if link.to in reached and link.from not in reached: reached.append(link.from)
				for i in range(31):
					var point: Vector2 = layout.rooms[link.from].center.lerp(layout.rooms[link.to].center,float(i)/30)
					if Genome.field(layout,point)<1.7: clear_passages = false
		if reached.size()!=layout.rooms.size(): connected = false
		varied[str(layout.bed)] = true
	check(connected,"100 cave seeds replay exactly and connect every chamber")
	check(clear_passages,"Generated passage centerlines retain Bigfoot clearance")
	check(varied.size()>90,"Seeds produce distinct cave layouts")
	check(var_to_bytes(Inland.sample(37))==surface_before,"Cave generation leaves the surface genome unchanged")
	var shale := Genome.sample(Inland.cave(37,"mossy shale",0.8))
	check(var_to_bytes(shale)==var_to_bytes(Genome.sample(Inland.cave(37,"limestone",0.2))),"Palette and moisture changes preserve layout")
	check(not Genome.valid({"version":1,"seed":-1,"palette":"limestone","moisture":0.5}),"Invalid cave seed is rejected")
	check(not Genome.valid({"version":1,"seed":37,"palette":"unknown","moisture":0.5}),"Unknown palette is rejected")
	check(not Genome.valid_state({"genome":Inland.cave(37),"stash":["unknown"]}),"Invalid stored item is rejected")
	check(Genome.valid_state({"genome":Inland.cave(37),"stash":["branch","fish"]}),"Supported cave and storage state validates")
	quit(1 if failures else 0)
