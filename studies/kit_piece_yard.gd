extends "res://studies/character_study.gd"
## The kit piece yard: one RuinKit piece by id on flat ground with the
## pilot (the character study's motor, figure, camera, F1 numbers), for
## stills (tools/shot.py) and checks through the real loop (tools/drive.py).
## A piece's "ropes" meta is hung live (MotifAuthored.hang_ropes into a
## FootPieces, as the editor and authored places do); a self-stepping Rig
## (keel_hung_stair) runs on its own.
##   --piece=<id> (tower_shell) --seed=<n> (3) --weathered=<0..1> (0.4)
##   --turn=<deg> (0) --floor=<m> (40, the ground's half size)
##   python tools/kit_piece.py yard <id>   prints the shot/drive lines
## Stations: 1 in front (+Z), 2 left (-X), 3 behind (-Z). R back to 1.
## The piece is the node "Piece" at the origin; the rope host "RopeHost".
const RuinKit = preload("res://scripts/ruin_kit.gd")

var piece_id := "tower_shell"
var piece_seed := 3
var piece_weathered := 0.4
var piece_turn := 0.0
var floor_half := 40.0
var piece: Node3D
var rope_host: Node3D
var ropes_made: Array = []

func _ready() -> void:
	pack = "kit_piece_yard"
	for a in preload("res://scripts/launch_args.gd").user_args():
		if a.begins_with("--piece="): piece_id = a.get_slice("=",1)
		elif a.begins_with("--seed="): piece_seed = a.get_slice("=",1).to_int()
		elif a.begins_with("--weathered="): piece_weathered = clampf(a.get_slice("=",1).to_float(),0.0,1.0)
		elif a.begins_with("--turn="): piece_turn = a.get_slice("=",1).to_float()
		elif a.begins_with("--floor="): floor_half = maxf(10.0,a.get_slice("=",1).to_float())
	super._ready()

## The piece's drawn box (its own frame, turned), for the stations.
func _piece_box() -> AABB:
	var probe := RuinKit.piece(piece_id,piece_seed,piece_weathered)
	if probe == null: return AABB(Vector3(-2,0,-2),Vector3(4,4,4))
	var mesh := probe.get_node_or_null("Mesh") as MeshInstance3D
	var box := mesh.get_aabb() if mesh != null and mesh.mesh != null else AABB(Vector3(-2,0,-2),Vector3(4,4,4))
	probe.free()
	return Transform3D(Basis(Vector3.UP,deg_to_rad(piece_turn)),Vector3.ZERO)*box

func _load_pack() -> void:
	var box := _piece_box()
	var front := Vector3(box.get_center().x,0.0,box.end.z+2.5)
	var left := Vector3(box.position.x-2.5,0.0,box.get_center().z)
	var back := Vector3(box.get_center().x,0.0,box.position.z-2.5)
	stations = [
		{"key":1,"name":"in front","spawn":front,"face":Vector2(0.0,-1.0),
			"parts":[["box",Rect2(-floor_half,-floor_half,floor_half*2.0,floor_half*2.0),-1.0,0.0,"floor"]]},
		{"key":2,"name":"left","spawn":left,"face":Vector2(1.0,0.0),"parts":[]},
		{"key":3,"name":"behind","spawn":back,"face":Vector2(0.0,1.0),"parts":[]},
	]
	start = front
	start_face = Vector2(0.0,-1.0)
	lost = -30.0
	_last_stood = start

func _build_room() -> void:
	super._build_room()
	piece = RuinKit.piece(piece_id,piece_seed,piece_weathered)
	if piece == null:
		push_error("kit_piece_yard: no RuinKit piece '%s'" % piece_id)
		return
	piece.name = "Piece"
	piece.rotation.y = deg_to_rad(piece_turn)
	add_child(piece)
	if piece.has_meta("ropes"):
		# Loaded at run time, never preloaded: a const preload of the
		# FootPieces graph leaks it at exit (the torana lane's note).
		rope_host = load("res://scripts/roguelike/layer_greybox.gd").FootPieces.new()
		rope_host.name = "RopeHost"
		add_child(rope_host)
		rope_host.attach(self)
		ropes_made = load("res://scripts/kit_isle/motif_authored.gd").hang_ropes(piece.get_meta("ropes"),piece.transform,Callable(rope_host,"rope"))

func _hint_text() -> String:
	return "Kit piece yard · %s seed %d weathered %.2f · 1 front · 2 left · 3 behind · R front · F1 numbers · Esc mouse" % [piece_id,piece_seed,piece_weathered]
