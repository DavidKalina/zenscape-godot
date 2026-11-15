extends "res://tools/harness/drive.gd"
## Stills of skins on the hero plane, frozen in flight over the endless
## land: one window, one hour. tools/skin_sheet.py runs it once by day and
## once by night and lays the stills out; run it through that.
##
##   --skins=paint/moonstone,sheen:gloss   ids (ShopStock.item), or
##       sheen:NAME[@id]: a skin's livery (Harbour's by default) in that
##       sheen alone, to compare finishes; glow:HEX[*POWER][@id]: that
##       livery with its trim and body glowing HEX at POWER (1), to tune a glow
##   --tag=day   --dir=captures/skins/raw   --views=port,quarter,top,chase
##
## Prints `SKIN <id> glow=<0|1> rarity=<r>` per skin and `LIGHT daylight=<d>`;
## saves <dir>/<id with / and : as _>_<tag>_<view>.png.

const ShopStock = preload("res://scripts/endless/shop_stock.gd")
const GlideCam = preload("res://scripts/glide_camera.gd")

## A view: the way out from the plane in its own frame (nose along -Z) and
## the camera's distance (1 fits the plane in the frame). chase is where
## the play camera sits at a cruise (GlideCamera BACK.x back, UP.x up, its
## FOV): flying distance.
const SKIN_VIEWS := {
	"port": [Vector3(-1.0,0.12,0.0),0.85],
	"starboard": [Vector3(1.0,0.12,0.0),0.85],
	"quarter": [Vector3(-0.8,0.45,-1.0),0.95],
	"top": [Vector3(0.25,1.0,0.55),0.95],
	"tail": [Vector3(0.35,0.3,1.0),0.95],
	"chase": [Vector3.ZERO,0.0],
}

func drive() -> void:
	await open("studies/endless_flight.tscn")
	var fig: Node3D = study.plane_figure
	await frames(30)
	# Frozen: the bot-less plane would fall and tumble.
	study.process_mode = Node.PROCESS_MODE_DISABLED
	var tag := String(arg("tag","day"))
	var dir := String(arg("dir","captures/skins/raw"))
	var views := String(arg("views","port,quarter,top,chase")).split(",",false)
	var look: Node = study.get("look")
	var daylight := -1.0
	if look != null and look.get("celestial") != null:
		daylight = float(look.celestial.state.get("zs_daylight",-1.0))
	print("LIGHT daylight=%.2f" % daylight)
	for id: String in String(arg("skins","")).split(",",false):
		var i := _row(id)
		if i.is_empty():
			check(false,"skin "+id,"no such skin (ShopStock.item, sheen:NAME[@id] or glow:HEX[*POWER][@id])")
			continue
		print("SKIN %s glow=%d rarity=%s" % [id,int(i.get("finish",{}).has("glow")),ShopStock.rarity(i)])
		ShopStock._paint(fig,i)
		await frames(4)
		var basis := fig.global_basis.orthonormalized()
		for v: String in views:
			if not SKIN_VIEWS.has(v):
				check(false,"view "+v,"one of "+", ".join(SKIN_VIEWS.keys()))
				continue
			var way: Vector3 = basis*(SKIN_VIEWS[v][0] as Vector3).normalized()
			var out := "%s/%s_%s_%s.png" % [dir,id.replace("/","_").replace(":","_").replace("@","_").replace("*","x"),tag,v]
			var opts := {"out":out,"dist":float(SKIN_VIEWS[v][1]),"size":Vector2i(720,450)}
			if v == "chase":
				way = basis*Vector3(0.0,0.26,1.0)
				opts.merge({"eye":fig.global_position+basis*Vector3(0.0,GlideCam.UP.x,GlideCam.BACK.x),"fov":GlideCam.FOV})
			var p := await shot_at(way,fig,opts)
			check(p != "" or _headless(),"%s %s %s" % [id,tag,v])

## The row for `id`: a stock skin, or sheen:NAME[@id], that skin's livery
## (Harbour's by default) in that sheen alone.
static func _row(id: String) -> Dictionary:
	if id.begins_with("glow:"):
		var g := id.trim_prefix("glow:")
		var lit := ShopStock.item(g.get_slice("@",1) if "@" in g else "paint/harbour")
		var hp := g.get_slice("@",0)
		if lit.is_empty() or not Color.html_is_valid(hp.get_slice("*",0)): return {}
		return {"id":id,"slot":"paint","name":"glow","livery":lit.livery,"finish":{"glow":Color(hp.get_slice("*",0)),
			"glow_on":["trim","body"],"glow_power":float(hp.get_slice("*",1)) if "*" in hp else 1.0}}
	if not id.begins_with("sheen:"): return ShopStock.item(id)
	var rest := id.trim_prefix("sheen:")
	var sheen := rest.get_slice("@",0)
	var base := ShopStock.item(rest.get_slice("@",1) if "@" in rest else "paint/harbour")
	if base.is_empty() or not ShopStock.SHEENS.has(sheen): return {}
	return {"id":id,"slot":"paint","name":sheen,"livery":base.livery,"finish":{"sheen":sheen}}
