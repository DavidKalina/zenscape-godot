extends SceneTree
## The train's colliders and openings at the default sizes, from RailTrain
## (scripts/endless/rail_train.gd `_parts`, the source of them), written to
## art/blender/train/train_parts.json for train_build.py's proof: every model is
## proved against these numbers, not a copy of them. train_build.py runs this
## itself (python3 tools/godot.py -s res://art/blender/train/train_parts.gd).
##
## Each kind of RailTrain.CARS (its first car's size) and the plain boxcar:
## {long, tall, solid: [[x0,y0,z0,x1,y1,z1]], plates: [...], movers: [{box,
## slide}], holes: [{box, way, roofed}], inner: [half width, floor, roof] or
## absent}, the boxes in Godot's frame (x right, y up, z back), m.

const RailTrain = preload("res://scripts/endless/rail_train.gd")
const OUT := "res://art/blender/train/train_parts.json"

func _init() -> void:
	var sizes := {"box":[24.0,9.0]}
	for row: Array in RailTrain.CARS:
		if not sizes.has(str(row[0])): sizes[str(row[0])] = [float(row[1]),float(row[2])]
	var out := {"gap":RailTrain.GAP,"wide":RailTrain.WIDE,"floor":RailTrain.FLOOR,"kinds":{}}
	for kind: String in sizes:
		var long := float(sizes[kind][0])
		var tall := float(sizes[kind][1])
		var parts: Dictionary = RailTrain._parts(kind,long,tall)
		var k := {"long":long,"tall":tall,"solid":[],"plates":[],"movers":[],"holes":[]}
		for part: Array in parts.solid: (k.solid as Array).append(_b(part[0]))
		for b: AABB in parts.plates: (k.plates as Array).append(_b(b))
		for m: Dictionary in parts.movers:
			var s: Vector3 = m.slide
			(k.movers as Array).append({"box":_b(m.box),"slide":[s.x,s.y,s.z]})
		for h: Dictionary in parts.holes:
			(k.holes as Array).append({"box":_b(h.box),"way":str(h.get("way","")),"roofed":bool(h.roofed)})
		if kind in RailTrain.CORRIDOR:
			k.inner = [RailTrain.smash_wide()*0.5,RailTrain.FLOOR,RailTrain.FLOOR+RailTrain.smash_high(tall)]
		out.kinds[kind] = k
	var f := FileAccess.open(OUT,FileAccess.WRITE)
	f.store_string(JSON.stringify(out,"\t"))
	f.close()
	print("wrote %s: %d kinds" % [OUT,(out.kinds as Dictionary).size()])
	quit(0)

static func _b(b: AABB) -> Array:
	return [snappedf(b.position.x,0.0001),snappedf(b.position.y,0.0001),snappedf(b.position.z,0.0001),
		snappedf(b.end.x,0.0001),snappedf(b.end.y,0.0001),snappedf(b.end.z,0.0001)]
