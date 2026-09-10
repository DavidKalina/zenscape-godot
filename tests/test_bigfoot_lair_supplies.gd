extends SceneTree
## Standalone cave-room checks: real resources produce persistent visible changes.
const Lair = preload("res://scripts/bigfoot_lair_room.gd")
var failures := 0
var commits := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	print("PASS: " if ok else "FAIL: ",message)
	if not ok: failures += 1

func commit_source() -> bool:
	commits += 1
	return true

func run() -> void:
	var room := Lair.new()
	root.add_child(room)
	check(room.comfort()==0.0 and room.food_count()==0 and room.material_count()==0,"Fresh cave starts with an uncomfortable bed and no supplies")
	var bare_count: int = room.bedding.get_child_count()
	check(bare_count>0 and room.bedding.name=="Bedding" and room.play_stones.name=="PlayStones","Living areas have stable named visual roots")
	check(not room.tend_bed() and room.eat_food().is_empty(),"Empty stash cannot create bedding or food")
	check(not room.receive_item_checked("fruit",func() -> bool: return false) and room.food_count()==0,"Failed source transaction creates no food")
	check(room.receive_item_checked("fruit",commit_source) and commits==1 and room.food_count()==1,"Successful source transaction transfers one food item")
	check(not room.receive_item_checked("stone",commit_source) and commits==1,"Unsupported supplies never consume the source")
	room.receive_item("fish")
	room.receive_item("branch")
	room.receive_item("leaves")
	check(room.food_count()==2 and room.material_count()==2 and room.stockpile.get_child_count()==4,"Stash mesh count matches mixed supplies")
	check(room.tend_bed() and room.stash==["fruit","fish","branch"],"Tending consumes one leaf supply while preserving food")
	check(is_equal_approx(room.comfort(),1.0/3.0) and room.bedding.get_child_count()>bare_count,"First contribution makes the bed visibly fuller and more comfortable")
	check(room.stockpile.get_child_count()==3,"Used bedding material disappears from the stockpile")
	check(room.eat_food()=="fruit" and room.eat_food()=="fish" and room.eat_food().is_empty(),"Bigfoot prefers fruit, can eat fish, and cannot eat an empty stash")
	check(room.material_count()==1 and room.stockpile.get_child_count()==1,"Eating never consumes building materials")
	check(room.tend_bed(),"A branch can improve the bed too")
	room.receive_item("branch")
	room.receive_item("leaves")
	check(room.tend_bed() and room.comfort()==1.0,"Three successful contributions complete the bed")
	var supply_before: Array = room.stash.duplicate()
	check(not room.tend_bed() and room.stash==supply_before,"A finished bed never wastes further supplies")
	for stage in range(1,4):
		check(room.arrange_stone() and room.play_stones.get_child_count()==3 and room.play_stones.get_node_or_null("BalancedStone%d" % (stage-1))!=null,"Play arranges one of three existing stones at stage %d" % stage)
	check(not room.arrange_stone() and room.stash==supply_before,"A complete cairn is bounded and never consumes unrelated supplies")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(room.capture_living()))
	var saved_stash: Array = room.stash.duplicate()
	check(Lair.valid_living(saved),"Living state accepts integer-valued JSON numbers")
	for invalid in [{},{"bed_stage":-1,"play_stage":0},{"bed_stage":4,"play_stage":0},{"bed_stage":1.5,"play_stage":0},{"bed_stage":true,"play_stage":0},{"bed_stage":0,"play_stage":"1"},{"bed_stage":NAN,"play_stage":0},[]]:
		check(not Lair.valid_living(invalid),"Malformed living state is rejected: "+str(invalid))
	var living_before: Dictionary = room.capture_living()
	room.restore_living({"bed_stage":999,"play_stage":0})
	check(room.capture_living()==living_before,"Invalid restoration leaves the room unchanged")
	room.restore_living({"bed_stage":0,"play_stage":0})
	check(room.bedding.get_child_count()==bare_count and room.play_stones.get_child_count()==3 and room.play_stones.get_node_or_null("LooseStone0")!=null,"Resetting living state thins bedding and returns the cairn to loose stones")
	room.restore_living(saved)
	check(room.comfort()==1.0 and room.play_stones.get_child_count()==3 and room.stash==saved_stash,"Restoration rebuilds bedding and stones without consuming supplies again")
	check(room.document().genome==room.genome and room.document().stash==saved_stash and room.document().living==room.capture_living(),"Cave document preserves existing fields and includes living state")
	check(room.disturb_bed() and room.bed_stage==2 and room.stash==saved_stash,"Disturbing bedding reduces comfort without fabricating supplies")
	check(room.remove_one_supply()=="branch" and room.remove_one_supply().is_empty() and room.stockpile.get_child_count()==0,"Disturbing supplies removes exactly one visible resource, then reports empty")
	room.restore_living({"bed_stage":0,"play_stage":0})
	check(not room.disturb_bed(),"An already bare bed cannot lose more comfort")
	var full: Array = []
	full.resize(24)
	full.fill("fruit")
	room.restore_stash(full)
	check(room.stockpile.get_child_count()==24 and not room.receive_item_checked("fruit",commit_source) and commits==1,"Full storage rejects a transfer before consuming its source")
	check(room.eat_food()=="fruit" and room.receive_item_checked("fish",commit_source) and room.stockpile.get_child_count()==24,"Consumption frees a real storage slot for later gathering")
	var layer_ok := true
	for visual_root in [room.bedding,room.play_stones,room.stockpile]:
		for child in visual_root.get_children(): layer_ok = layer_ok and child.layers==Lair.LAYER
	check(layer_ok,"All rebuilt living visuals stay on the cave render layer")
	room.free()
	await process_frame
	print("BIGFOOT LAIR SUPPLIES: failures=",failures)
	quit(1 if failures else 0)
