extends RefCounted
## The sky clusters' motifs: data recipes for a group of islets that reads
## as one place (a farmstead, a fishing hamlet, a lighthouse reef), laid
## out by the solver (scripts/cluster_solver.gd) from a seed. Pure data.
##
## A motif:
##   label: its name for people;
##   layout: how members spread round the member they relate to, the
##     "pattern": scatter (any way), ring (evenly round it), chain (on
##     along the way the last one went), terrace (scatter, each lower than
##     the last: the heights say so), stack (straight over or under it,
##     clear of its rock);
##   rock: the members' earth sides (scripts/rock_looks.gd): palettes to
##     draw from per member and a tone range; keel: how much deeper than an
##     islet's own the rock hangs (a range);
##   night: its signature after dark: windows (cabins lit), lanterns
##     (posts and lamps), beam (a lighthouse sweeping);
##   roles: the members, in the order they are laid.
## A role:
##   name; anchor: the first, at the cluster's middle;
##   kind: the islet kind (scripts/sky_islet.gd KINDS) its ground and
##     planting start from; radius (m, a range); height: its middle over
##     the anchor's (m, a range);
##   count: how many (a range), chance: the odds it is there at all;
##   spec: anything more of the islet's recipe (SkyIslet `recipe`);
##   pond: the odds of a pond whose stream falls off the rim;
##   features: what stands on it, each {type, chance, count}: cabin,
##     field (fenced wheat), lamps (stone lamps by the cabin), bearer
##     (someone with a lantern by the door), windmill, lighthouse, lookout
##     (a lamp on the highest ground), dock (off the rim into open sky),
##     fisher (on the dock's end);
##   relation: how it is laid against another member:
##     {type: near | bridge | stones | outer, to: a role's name, or
##     "prev" (the last of its own role, else `to`), gap (m, rim to rim,
##     a range), stones (how many stepping stones, for "stones")}:
##     near, a flight apart; bridge, a rope footbridge's span; stones, a
##     run of stepping stones the pilot jumps; outer, out on the side
##     facing open sky (a landmark).
## Fixed layouts (the showcase): a role may give `offset` (its middle from
## the anchor's), `seed` and `radius` exactly, and a stones relation
## `angle` and `swings`.
##
## Next (terrain motifs, not built yet): mountain (a spire role of a rock
## piece kind with a trail feature), lake (a role whose recipe sets its own
## water level), ravine (a role split by a cleft, a bridge relation within
## it), waterfall terraces (a fall relation onto a lower role's pool),
## forest hold, hermit's stack (the stack pattern). They fit as new kinds,
## features and relations; the format stays.

const MOTIFS := {
	"farmstead": {
		"label":"Farmstead","layout":"terrace",
		"rock":{"palettes":["basalt_warm","basalt"],"tone":Vector2(0.9,1.1)},"keel":Vector2(1.4,1.9),
		"night":{"windows":true,"lanterns":true,"beam":false},
		"roles":[
			{"name":"farm","anchor":true,"kind":"meadow","radius":Vector2(15.0,18.0),"height":Vector2(0.0,0.0),"pond":0.75,
				"spec":{"dome":0.35,"trees":Vector2i(8,12),"tree_pool":{"broadleaf":1.0,"birch":0.8,"tree":0.5,"willow":0.3},
					"mixed":true,"tree_size":Vector2(0.9,1.3),"drifts":Vector2i(8,12)},
				"features":[{"type":"cabin"},{"type":"field"},{"type":"lamps","count":Vector2i(2,3)},{"type":"bearer","chance":0.7}]},
			{"name":"wood","kind":"grove","radius":Vector2(10.0,13.5),"height":Vector2(2.0,4.5),"chance":0.9,
				"spec":{"dome":1.2,"trees":Vector2i(40,56),"tree_pool":{"tree":1.0,"redwood":0.4,"juniper":0.35,"broadleaf":0.6,"birch":0.4},
					"mixed":true,"tree_size":Vector2(0.75,1.7),"apart":0.7,"undergrowth":1.8},
				"relation":{"type":"bridge","to":"farm","gap":Vector2(6.0,12.0)}},
			{"name":"crag","kind":"crag","radius":Vector2(7.0,9.5),"height":Vector2(11.0,18.0),"chance":0.8,
				"spec":{"trees":Vector2i(5,8),"tree_pool":{"tree":1.0,"juniper":0.8}},
				"features":[{"type":"lookout"}],
				"relation":{"type":"near","to":"farm","gap":Vector2(6.0,14.0)}},
			{"name":"mill","kind":"hills","radius":Vector2(5.0,6.5),"height":Vector2(0.5,4.0),"chance":0.85,
				"spec":{"dome":0.4,"trees":Vector2i(0,1)},
				"features":[{"type":"windmill"}],
				"relation":{"type":"near","to":"farm","gap":Vector2(4.0,9.0)}},
			{"name":"dock","kind":"shore","radius":Vector2(4.5,6.0),"height":Vector2(-3.4,-2.0),
				"spec":{"trees":Vector2i(1,2),"tree_pool":{"willow":1.0}},
				"features":[{"type":"dock"},{"type":"fisher","chance":0.8}],
				"relation":{"type":"stones","to":"farm","stones":Vector2i(2,4)}},
			{"name":"light","kind":"crag","radius":Vector2(6.0,7.5),"height":Vector2(-13.0,-7.0),"chance":0.35,
				"spec":{"peaks":[Vector4(0.0,0.0,5.0,1.2)],"trees":Vector2i(0,2),"tree_pool":{"juniper":1.0}},
				"features":[{"type":"lighthouse"}],
				"relation":{"type":"outer","to":"farm","gap":Vector2(14.0,24.0)}},
		]},
	"hamlet": {
		"label":"Fishing hamlet","layout":"ring",
		"rock":{"palettes":["slate","basalt"],"tone":Vector2(0.9,1.12)},"keel":Vector2(1.3,1.7),
		"night":{"windows":true,"lanterns":true,"beam":false},
		"roles":[
			{"name":"green","anchor":true,"kind":"meadow","radius":Vector2(9.0,11.0),"height":Vector2(0.0,0.0),"pond":0.5,
				"spec":{"dome":0.3,"trees":Vector2i(3,6),"tree_pool":{"willow":1.0,"birch":0.7,"broadleaf":0.4},"mixed":true,"drifts":Vector2i(4,7)},
				"features":[{"type":"cabin"},{"type":"lamps","count":Vector2i(2,3)},{"type":"bearer","chance":0.8}]},
			{"name":"cottage","kind":"shore","radius":Vector2(6.5,8.0),"height":Vector2(-3.0,1.5),"count":Vector2i(2,4),
				"spec":{"trees":Vector2i(1,2),"tree_pool":{"willow":1.0,"juniper":0.5},"dome":0.25},
				"features":[{"type":"cabin"},{"type":"dock"},{"type":"fisher","chance":0.6},{"type":"lamps","count":Vector2i(0,1)}],
				"relation":{"type":"bridge","to":"green","gap":Vector2(5.0,11.0)}},
			{"name":"skerry","kind":"crag","radius":Vector2(2.4,3.4),"height":Vector2(-5.0,-1.0),"count":Vector2i(1,3),"chance":0.8,
				"spec":{"peaks":[Vector4(0.0,0.0,2.5,0.7)],"trees":Vector2i(0,1),"tree_pool":{"juniper":1.0}},
				"relation":{"type":"near","to":"green","gap":Vector2(4.0,12.0)}},
		]},
	"reef": {
		"label":"Lighthouse reef","layout":"chain",
		"rock":{"palettes":["basalt","slate"],"tone":Vector2(0.82,1.0)},"keel":Vector2(1.6,2.2),
		"night":{"windows":true,"lanterns":true,"beam":true},
		"roles":[
			{"name":"keeper","anchor":true,"kind":"hills","radius":Vector2(8.0,10.0),"height":Vector2(0.0,0.0),
				"spec":{"mounds":[],"dome":0.5,"trees":Vector2i(1,3),"tree_pool":{"juniper":1.0,"tree":0.6}},
				"features":[{"type":"cabin"},{"type":"lamps","count":Vector2i(1,2)},{"type":"bearer","chance":0.6}]},
			{"name":"rock","kind":"crag","radius":Vector2(6.5,8.0),"height":Vector2(3.0,7.0),
				"spec":{"peaks":[Vector4(0.0,0.0,5.5,1.6)],"trees":Vector2i(0,1),"tree_pool":{"juniper":1.0}},
				"features":[{"type":"lighthouse"}],
				"relation":{"type":"stones","to":"keeper","stones":Vector2i(2,3)}},
			{"name":"reef","kind":"crag","radius":Vector2(2.4,6.0),"height":Vector2(-9.0,2.0),"count":Vector2i(3,6),
				"spec":{"peaks":[Vector4(0.0,0.0,3.0,0.9)],"trees":Vector2i(0,2),"tree_pool":{"juniper":1.0,"tree":0.5},"drifts":Vector2i(0,2)},
				"relation":{"type":"near","to":"prev","gap":Vector2(2.5,11.0)}},
			{"name":"jetty","kind":"shore","radius":Vector2(4.5,5.5),"height":Vector2(-4.0,-2.0),"chance":0.7,
				"spec":{"trees":Vector2i(0,1),"tree_pool":{"willow":1.0}},
				"features":[{"type":"dock"},{"type":"fisher","chance":0.8}],
				"relation":{"type":"bridge","to":"keeper","gap":Vector2(5.0,10.0)}},
		]},
	# The forest hold: a real wood on a big islet, a hut in its glade and a
	# platform up its hold tree, wooded islets round it on rope bridges;
	# lanterns strung through the trees and along the bridges at night
	# (scripts/woodland.gd plants it, scripts/forest_hold.gd lays the rest).
	"forest": {
		"label":"Forest hold","layout":"scatter",
		"rock":{"palettes":["basalt","basalt_warm"],"tone":Vector2(0.84,1.02)},"keel":Vector2(1.5,2.0),
		"night":{"windows":true,"lanterns":true,"beam":false,"canopy":true,"bridge_lanterns":true},
		"roles":[
			{"name":"hold","anchor":true,"kind":"grove","radius":Vector2(16.0,19.0),"height":Vector2(0.0,0.0),
				"spec":{"dome":0.9,"trees":Vector2i(0,0),"drifts":Vector2i(0,0),"undergrowth":0.2,
					"woodland":{"hold":true,"glades":Vector2i(1,2),"glade":Vector2(6.0,7.5),"giants":Vector2i(3,5),
						"canopy_pool":{"tree":1.0,"birch":0.22,"redwood":0.07},"under_pool":{"tree":1.0,"juniper":0.45,"birch":0.25},
						"edge_pool":{"birch":0.9,"tree":1.0,"juniper":0.45}}},
				"features":[{"type":"hut"},{"type":"treehouse"},{"type":"lamps","count":Vector2i(1,2)},{"type":"bearer","chance":0.8},
					{"type":"trail"},{"type":"canopy"}]},
			{"name":"grove","kind":"grove","radius":Vector2(8.5,12.0),"height":Vector2(-2.0,2.0),"count":Vector2i(2,3),
				"spec":{"dome":0.9,"trees":Vector2i(0,0),"drifts":Vector2i(0,0),"undergrowth":0.2,
					"woodland":{"glades":Vector2i(0,1),"glade":Vector2(3.5,4.5),"giants":Vector2i(0,2),
						"canopy_pool":{"tree":1.0,"birch":0.3,"redwood":0.06},"under_pool":{"tree":1.0,"juniper":0.5},
						"edge_pool":{"birch":1.0,"tree":0.9,"juniper":0.5}}},
				"features":[{"type":"trail"},{"type":"canopy"}],
				"relation":{"type":"bridge","to":"hold","gap":Vector2(7.0,12.5)}},
			{"name":"spring","kind":"grove","radius":Vector2(7.0,8.5),"height":Vector2(-2.5,1.0),"chance":0.6,"pond":1.0,
				"spec":{"dome":0.6,"trees":Vector2i(0,0),"drifts":Vector2i(0,0),"undergrowth":0.3,
					"woodland":{"glades":Vector2i(0,0),"giants":Vector2i(0,1),"fill":0.75,
						"canopy_pool":{"tree":1.0,"birch":0.5},"under_pool":{"tree":1.0,"juniper":0.4},"edge_pool":{"birch":1.0,"tree":0.6}}},
				"features":[{"type":"trail"},{"type":"canopy"}],
				"relation":{"type":"bridge","to":"grove","gap":Vector2(6.5,11.0)}},
			{"name":"knoll","kind":"hills","radius":Vector2(3.6,4.6),"height":Vector2(-1.5,1.5),"chance":0.6,
				"spec":{"mounds":[],"dome":0.3,"trees":Vector2i(1,1),"tree_pool":{"redwood":1.0},"tree_size":Vector2(1.5,1.8),"undergrowth":1.5},
				"relation":{"type":"stones","to":"hold","stones":Vector2i(2,3)}},
		]},
}

## The showcase (--showcase): the farmstead as first laid out by hand, its
## members fixed, what stands on them found by querying the land.
const SHOWCASE := {
	"label":"Showcase farmstead","layout":"terrace",
	"rock":{"palettes":["basalt_warm"],"tone":Vector2(0.92,1.08)},"keel":Vector2(1.5,1.5),
	"night":{"windows":true,"lanterns":true,"beam":true},
	"roles":[
		{"name":"lead","anchor":true,"kind":"meadow","radius":Vector2(19.0,19.0),"seed":91021,"offset":Vector3.ZERO,
			"spec":{"dome":0.35,"mounds":[Vector4(-12.0,-8.0,8.0,1.6),Vector4(12.0,10.0,7.0,1.1)],
				"pond":{"at":Vector2(-7.0,3.0),"radius":3.2,"toward":Vector2(-1.0,0.35)},
				"trees":Vector2i(10,13),"tree_pool":{"broadleaf":1.0,"birch":0.8,"tree":0.5,"willow":0.3},"mixed":true,
				"tree_size":Vector2(0.9,1.3),"drifts":Vector2i(9,13)},
			"features":[{"type":"field","prefer":{"toward":Vector2(0.3,-1.0)}},{"type":"cabin","prefer":{"near":Vector2(1.5,4.5),"near_weight":0.6}},
				{"type":"lamps","count":Vector2i(3,3)},{"type":"bearer"}]},
		{"name":"forest","kind":"grove","radius":Vector2(13.5,13.5),"seed":55117,"offset":Vector3(-35.0,4.0,-26.0),
			"spec":{"dome":1.3,"trees":Vector2i(48,60),"tree_pool":{"tree":1.0,"redwood":0.4,"juniper":0.35,"broadleaf":0.6,"birch":0.4},
				"mixed":true,"tree_size":Vector2(0.75,1.7),"apart":0.7,"undergrowth":1.8},
			"relation":{"type":"bridge","to":"lead"}},
		{"name":"crag","kind":"crag","radius":Vector2(9.0,9.0),"seed":33829,"offset":Vector3(5.0,17.0,-37.0),
			"spec":{"peaks":[Vector4(1.0,-1.0,7.5,6.5),Vector4(-4.0,3.0,4.5,3.0)],"trees":Vector2i(6,9),"tree_pool":{"tree":1.0,"juniper":0.8}},
			"features":[{"type":"lookout"}]},
		{"name":"mill","kind":"hills","radius":Vector2(5.8,5.8),"seed":71993,"offset":Vector3(31.0,2.0,-8.0),
			"spec":{"dome":0.4,"mounds":[Vector4(0.0,0.0,4.6,1.0)],"trees":Vector2i(0,1)},
			"features":[{"type":"windmill"}]},
		{"name":"light","kind":"crag","radius":Vector2(6.8,6.8),"seed":18517,"offset":Vector3(36.0,-12.0,30.0),
			"spec":{"peaks":[Vector4(0.0,0.0,5.5,1.4)],"trees":Vector2i(1,2),"tree_pool":{"juniper":1.0}},
			"features":[{"type":"lighthouse"}]},
		{"name":"dock","kind":"shore","radius":Vector2(5.2,5.2),"seed":62207,"height":Vector2(-2.6,-2.6),
			"spec":{"trees":Vector2i(1,2),"tree_pool":{"willow":1.0}},
			"features":[{"type":"dock","prefer":Vector2(-0.55,0.83)},{"type":"fisher"}],
			"relation":{"type":"stones","to":"lead","stones":Vector2i(3,3),"angle":Vector2(-0.55,0.83),"swings":[0.25,-0.3,0.2],
				"stone_radius":[2.4,2.1,2.6]}},
	]}

static func names() -> Array:
	return MOTIFS.keys()

static func motif(motif_name: String) -> Dictionary:
	if motif_name == "showcase": return SHOWCASE
	return MOTIFS.get(motif_name,{})
