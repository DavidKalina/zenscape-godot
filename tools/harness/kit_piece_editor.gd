extends "res://tools/harness/drive.gd"
## A RuinKit piece in the motif editor (studies/motif_editor.tscn, the real
## loop): in the palette; placed; turned; dressed; saved and reloaded with
## id, seed and turn kept and the mesh rebuilt the same (compared after a
## dress); its ropes (if it has the meta) hung live and following it. The
## temporary save is deleted. Run by `python tools/kit_piece.py check <id>`:
##   python tools/drive.py tools/harness/kit_piece_editor.gd -- --id=pent_hood
## Nothing here preloads the editor's FootPieces (it leaks at exit).
const SLUG := "zz_kit_piece_check"
const SEED := 4242
const TURN := 90.0

func faces_of(n: Node) -> int:
	var m := n.get_node_or_null("Mesh") as MeshInstance3D if n != null else null
	return m.mesh.get_faces().size() if m != null and m.mesh != null else -1

func live_ropes() -> int:
	var host: Variant = study.get("rope_host")
	if host == null: return 0
	var n := 0
	for r: Node in host.ropes:
		if is_instance_valid(r) and not r.is_queued_for_deletion(): n += 1
	return n

func drive() -> void:
	var id := str(arg("id", "pent_hood"))
	await open("studies/motif_editor.tscn")
	await frames(30)
	var MotifAuthored: Script = load("res://scripts/kit_isle/motif_authored.gd")
	var ids: Array = MotifAuthored.palette().map(func(e: Array) -> String: return str(e[0]))
	check(id in ids, "in the palette")
	var c: Vector2 = KitLand.centre_of(study.motif.outline())
	var at := Vector3(c.x - 6.0, float(study.motif.ground(c.x - 6.0, c.y)), c.y)
	var k: int = study.place_piece(id, at, SEED, 0.0)
	await frames(5)
	var node: Node3D = study.piece_node(k)
	check(node != null and faces_of(node) > 0, "placed", "node %s" % node)
	if node == null: return
	var want_ropes := (node.get_meta("ropes") as Array).size() if node.has_meta("ropes") else 0
	if want_ropes > 0: check(live_ropes() == want_ropes, "ropes hung live", "%d of %d" % [live_ropes(), want_ropes])
	study.select(k)
	study.turn_selected(TURN)
	await frames(5)
	node = study.piece_node(k)
	check(node != null and is_equal_approx(float(study.data.pieces[k].turn), TURN), "turned", str(study.data.pieces[k]))
	study.dress()
	await frames(10)
	var before := faces_of(study.piece_node(k))
	var ropes_before := live_ropes()
	if study.panel != null: study.panel.slug_edit.text = SLUG
	else: study.data.slug = SLUG
	var path: String = study.save()
	var ok: bool = study.load_motif(SLUG)
	await frames(10)
	if path != "": DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var p: Dictionary = study.data.pieces[k] if ok and k < study.data.pieces.size() else {}
	check(ok and str(p.get("id", "")) == id and int(p.get("seed", -1)) == SEED and is_equal_approx(float(p.get("turn", 0.0)), TURN), "saved and reloaded: id, seed, turn kept", str(p))
	var after := faces_of(study.piece_node(k))
	check(before > 0 and before == after, "reload rebuilds the same", "%d vs %d faces" % [before, after])
	if want_ropes > 0: check(live_ropes() == ropes_before, "reloaded, the ropes hang again", "%d vs %d" % [live_ropes(), ropes_before])
	check(not FileAccess.file_exists(path), "temp save removed", path)
