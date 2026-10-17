extends "res://scripts/pilot_physics_ground.gd"
## The pilot's ground on a kit isle (docs/scenic/kit-isle-shared.md): the
## physics space (scripts/pilot_physics_ground.gd) with the game's live
## rope bridges' decks in it (scripts/rope_bridge.gd, hung by
## scripts/footbridge.gd `live`), as the game's walker reads them. Over a
## deck (between its ends, within its width as it sways) the ground is the
## planks' top where they sag and sway now (RopeBridge `_on_deck`), where
## that is under the ray's start; his step is held between the hand ropes
## (RopeBridge `hold`; jumped clear over them, let through). The motifs had
## each written one (bell spires, cloister tarn, sundered gorge, colonnade
## spine); this is theirs made one.
##
## With `rest_decks` the bridges' resting decks already stand in the
## physics space as walk boxes (the bell spires'): a deck met at rest is
## lowered by the sim's drop under him, so it still sags. A bridge with the
## meta "rest_deck" is such a bridge whatever `rest_decks` says (the bell
## spires placed in the aqueduct isle's sky, scripts/kit_isle/
## motif_isle.gd, beside the other isles' live decks).
const RopeBridge = preload("res://scripts/rope_bridge.gd")

## The node the feet are in (the scene: world space).
var frame: Node3D
var rest_decks := false

func height_from(p: Vector2, y: float) -> float:
	var h := super.height_from(p,y)
	if RopeBridge._live.is_empty(): return h
	if rest_decks: return _sagged(p,h)
	var sagged := _sagged(p,h)
	if sagged != h: return sagged
	var from := y+PilotMotor.STEP_UP+LOOK_OVER
	var deck := deck_at(p,from)
	return maxf(h,deck) if deck > -INF else h

## The live deck's top under `p` that is under `from` (world y), or -INF.
func deck_at(p: Vector2, from: float) -> float:
	var best := -INF
	for bridge: MeshInstance3D in RopeBridge._live:
		if not is_instance_valid(bridge) or not bridge.is_inside_tree() or _resting(bridge): continue
		var local: Vector3 = bridge.global_transform.affine_inverse()*Vector3(p.x,from,p.y)
		if not bridge._near_deck(local,float(bridge.sim.width)*0.5+RopeBridge.STAND_SLACK+RopeBridge.SWAY_ROOM): continue
		var on: Vector3 = bridge._on_deck(local)
		if on.x <= 0.0 or on.x >= 1.0: continue
		if absf(on.y-float(bridge.sim.sway(on.x))) > float(bridge.sim.width)*0.5+RopeBridge.STAND_SLACK: continue
		var top: float = (bridge.global_transform*Vector3(local.x,local.y-on.z,local.z)).y
		if top <= from+0.001: best = maxf(best,top)
	return best

## Whether `bridge`'s resting deck stands as walk boxes.
func _resting(bridge: Node) -> bool:
	return rest_decks or bridge.has_meta("rest_deck")

## `h` (the physics ground's) lowered by the sim's drop where it is a
## bridge's resting deck (read in the bridge's frame).
func _sagged(p: Vector2, h: float) -> float:
	if not is_finite(h): return h
	for bridge: MeshInstance3D in RopeBridge._live:
		if not is_instance_valid(bridge) or not bridge.is_inside_tree() or not _resting(bridge): continue
		var local: Vector3 = bridge.global_transform.affine_inverse()*Vector3(p.x,h,p.y)
		if not bridge._near_deck(local,float(bridge.sim.width)*0.5+0.12+RopeBridge.SWAY_ROOM): continue
		var on: Vector3 = bridge._on_deck(local)
		if on.x <= 0.0 or on.x >= 1.0: continue
		if absf(on.y) > float(bridge.sim.width)*0.5+0.12: continue
		var rest: float = lerpf(float(bridge.a.y),float(bridge.b.y),on.x)+float(bridge.bow)*pow(sin(PI*on.x),2.0)
		if absf(local.y-rest) > 0.06: continue
		return h+float(bridge.sim.drop(on.x,on.y-bridge.sim.sway(on.x)))
	return h

func slide(feet: Vector3, step: Vector2) -> Vector3:
	var to := super.slide(feet,step)
	if frame == null or RopeBridge._live.is_empty(): return to
	var held: Vector2 = RopeBridge.hold(frame,feet,Vector2(to.x,to.z))
	return Vector3(held.x,to.y,held.y)
