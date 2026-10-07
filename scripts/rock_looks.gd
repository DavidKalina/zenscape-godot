extends RefCounted
## Rock looks for the sky clusters' islets (scripts/sky_islets.gd
## `rock_material`): the earth sides' strata (scripts/strata.gd, the
## shader's zs strata uniforms) recoloured so a cluster's rock reads as the
## peaks' dark basalt rather than the plate's layer cake: a thin turf and
## topsoil skin over close, dark tones, the bands still there but quiet.
## Each look is sRGB, by band; `tone` brightens or darkens a member a
## little so the members of one cluster differ.

const LOOKS := {
	"basalt": {"topsoil":"3d2b1f","clay":"43382f","sand":"3e3a36","shale":"2f2d2b","shale_dark":"242220",
		"bedrock":"34322f","core_a":"4a4744","core_b":"55514c","core_c":"3c3936"},
	"basalt_warm": {"topsoil":"4a3322","clay":"55402f","sand":"4d443a","shale":"37312b","shale_dark":"2a2520",
		"bedrock":"3e3833","core_a":"564e45","core_b":"625950","core_c":"463f38"},
	"slate": {"topsoil":"3b2e24","clay":"474649","sand":"525458","shale":"34373b","shale_dark":"27292d",
		"bedrock":"3c3f44","core_a":"4c5056","core_b":"585c62","core_c":"3f4247"},
}
## The looks are authored dark; drawn on the earth sides' shading they read
## near black, so they are lifted this much to sit with the peaks' basalt.
const LIFT := 1.55
## The bands' floors (m): a thin topsoil, then the dark rock close under it.
const FLOORS := Vector4(-0.3,-0.75,-1.3,-2.1)

## Sets a look's colours (at `tone`, 1 as authored) on an earth sides
## material already given its strata (Strata `apply`).
static func apply(material: ShaderMaterial, look: String, tone := 1.0) -> void:
	var colours: Dictionary = LOOKS.get(look,LOOKS.basalt)
	for key: String in colours:
		var c := Color(colours[key])*tone*LIFT
		c = Color(minf(c.r,1.0),minf(c.g,1.0),minf(c.b,1.0)).srgb_to_linear()
		material.set_shader_parameter("strata_"+key,Vector3(c.r,c.g,c.b))
	material.set_shader_parameter("strata_floors",FLOORS)
