extends RefCounted
## Overgrown's paint, flora and dressing layers
## (scripts/endless/world/profiles/overgrown.gd). For now wilderness's; the
## palette and overgrowth round gives it its own.

static func flora() -> Dictionary:
	return {"forest":1.0,"forest_meadows":1.0,"tree_weights":PackedFloat32Array(),"grass":1.0,"flowers":true}

static func paint() -> Dictionary:
	return {"mood":"alpine_morning","hour":8.6,"ground":{},"sea":{},"globals":{}}

static func layers() -> Dictionary:
	return {"trees":true,"grass":true,"birds":true,"fish":true,"arches":1.0,"traffic":-1}
