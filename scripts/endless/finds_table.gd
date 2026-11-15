extends RefCounted
## The finds (endless flight; docs/design/endless-flight/spec-wilderness-demo.md,
## lane `finds`): the one table of what there is to find, per world. Seed 1
## only. scripts/endless/finds.gd streams it and keeps the score in the pilot's
## book as `find/<world>/<id>`, so never rename an id once it has been flown.
##
## A row:
##   id      stable, unique in its world
##   area    a key of AREAS; the logbook's Wilderness page groups by it
##   kind    "relic"    fly through it
##           "landing"  come to rest within `radius` m of it (default 45)
##           "event"    fired by a signal or by the book, see below
##           "line"     a place line finished once, see below
##   title   what it reads as once found (else the id, spaced)
##   hint    optional: what the blank reads as before it is found
##   pay     optional: the money it pays the first time it is found (PilotBook
##           `earn`); else finds.gd PAY for its kind, PAY_ROOM for a relic in a
##           cracked wall's room. By how hard it is to come across: about 10 in
##           plain sight, 20 off the path, 40 hidden (shop_stock.gd's header:
##           decent flying earns 5-7 a minute, a wild line 30 or more)
## Where it stands (relic and landing; an event may have none), one of:
##   at      Vector3 exactly, or Vector2 on the ground there
##   anchor  a name:
##             a layout handle ("coast/lighthouse", "doors/amber-hall"): where
##             that tracked object stands now, followed if it moves
##             a plan site, as named on the map (tools/site_map.py):
##             "endless/arch/3_-2/0", "endless/rock/stacks/4_-2/0",
##             "endless/split/1_-3", "pond/1405_935"
##             a Peak part: "peak/summit", "peak/tarn", "peak/plateau",
##             "peak/strip/0", "peak/strip/1", "peak/strip/mid", "peak/tower/2",
##             a hole in the Dike or a Sill's gap, "peak/hole/2", "peak/sill/3"
##             (peak_carve.gd HOLES, SILL_HOLES)
##             the glacier's long crevasse, on its floor halfway along its full
##             depth: "peak/crevasse" (--ice-carve=0: none); under an ice arch,
##             halfway from the ice to the bridge's underside: "peak/ice-arch/1"
##             (peak_ice_forms.gd ARCHES; --ice-forms=0: none); deep in the
##             ice tunnel, 3 m over the chamber's floor: "peak/tunnel/deep"
##             (--ice-tunnel=0: none)
##             the room behind a cracked wall: "chamber/<place>" for the wall
##             `cracked/<place>` (cracked_walls.gd SITES)
##             a way tower's foot: "way/bay", "way/south", "way/isle" (way_towers.gd)
##             "doors/amber-hall/deep": deep in the door's hall; give the row
##             `hall` true as well, and it's seen only from inside
##           or anything lanes hand to `finds.anchor(name, position)`.
##           An anchor not there yet is tried again as the flight goes on.
## and, with either:
##   up      m over the ground or anchor (relic default HOVER, landing 0)
##   offset  Vector3 added last
##   yaw     a relic's facing in degrees (else it turns to meet the plane)
##   radius  a landing's reach (m)
##   pillar  with a stacks anchor: that pillar's top, not the group's middle
##   under   true: it stands in a bore under the land (the ice tunnel), lit by
##           the bore's own lights (find_marks.gd HALL_LAYER as well)
## Each spot then goes through the layout file as `finds/<id>`, so a find can
## be moved by hand without touching this table.
##
## An event names what fires it:
##   event   "broken/roll/wall-1": `finds.listen(wall.broken, "broken")` makes
##           the signal `broken(name)` fire "broken/<name>" and "broken";
##           `finds.listen(burrower.caught, "caught")` fires "caught". Any
##           signal of any arguments; `finds.fire("name")` by hand.
##   book    id or ids: done when the book has found one ("door/amber-wall").
## A line names its record: `line` "line/<place>/<name>" (a LINES entry in
## place_lines.gd), or gives its own `place`, `name` and `gates` and the table
## adds it (place_lines.gd's header has the gates' shape). `mark` (s): the time
## to beat before there is a best. Done at its first finished time; the page
## shows the best.

const SEED := 1
const HOVER := 16.0

## The areas in the order they read (worlds share them): round the start, then
## out and up; the Wilderness page flows them over four columns in this order.
const AREAS := {
	"meadow":"The start meadow",
	"north":"The north downs",
	"coast":"The near coast",
	"east":"The east hills",
	"south":"The south meadows",
	"west":"The west lands",
	"foothills":"The foothills",
	"peak":"The Peak",
	"amberlands":"The Amberlands",
}

const WORLDS := {
	"wilderness":[
		# The start meadow: in view of the start, or a short hop from it.
		{"id":"first-ring","area":"meadow","kind":"relic","at":Vector2(45.0,-75.0),"up":28.0,
			"title":"The first ring"},
		{"id":"inlet-skim","area":"meadow","kind":"relic","at":Vector2(40.0,320.0),"up":5.0,
			"title":"The ring on the water"},
		{"id":"first-cairn","area":"meadow","kind":"landing","at":Vector2(600.0,-60.0),"radius":60.0,
			"title":"Set down by the cairn","hint":"Put the wheels down inside the stones"},
		{"id":"meadow-dash","area":"meadow","kind":"line","place":"meadow","name":"meadow_dash",
			"title":"The meadow dash","gates":[Vector3(330.0,2.0,-60.0),Vector3(820.0,4.0,-30.0),Vector3(1400.0,4.0,120.0)]},
		{"id":"east-room","area":"meadow","kind":"relic","anchor":"chamber/start-east","up":0.0,
			"title":"The ring in the east room","hint":"Cracked stone, east of the meadow"},
		{"id":"north-room","area":"meadow","kind":"relic","anchor":"chamber/start-north","up":0.0,
			"title":"The ring in the green cup's room"},
		{"id":"the-cup","area":"meadow","kind":"landing","pay":20,"at":Vector2(500.0,-830.0),"radius":60.0,
			"title":"Set down in the green cup","hint":"A green cup in the hills, north"},
		{"id":"burrower-catch","area":"meadow","kind":"event","event":"caught",
			"title":"Caught the burrower","hint":"Skim low, and something runs"},
		# The way south, in the first frame's left edge, down the bay to the tower
		# at its far end. From the tower: way/south for the ruin, way/isle for the isles.
		{"id":"bay-lead","area":"meadow","kind":"relic","at":Vector2(-141.0,138.0),"up":26.0,
			"title":"The ring at the bay's head"},
		{"id":"bay-ring","area":"meadow","kind":"relic","at":Vector2(140.0,800.0),"up":6.0,
			"title":"The ring down the bay"},
		{"id":"tower-ring","area":"meadow","kind":"relic","pay":20,"anchor":"way/bay","up":17.0,"offset":Vector3(9.25,0.0,-18.5),
			"title":"The ring in the old colonnade","hint":"A ruin stands at the bay's far end"},
		# More round the meadow: over the ridge on the way to the saddle, a fold
		# behind the start, the field under the scarp south-east.
		{"id":"ridge-ring","area":"meadow","kind":"relic","at":Vector2(800.0,-480.0),"up":20.0,
			"title":"The ring on the ridge","hint":"Over the ridge, on the way to the saddle"},
		{"id":"gully-ring","area":"meadow","kind":"relic","pay":40,"at":Vector2(-150.0,-250.0),"up":8.0,
			"title":"The ring in the gully","hint":"Low behind the start, where the land folds"},
		{"id":"scarp-field","area":"meadow","kind":"landing","pay":20,"at":Vector2(1300.0,950.0),"radius":60.0,
			"title":"Set down under the scarp","hint":"A field at the foot of a tall scarp"},
		# The south meadows: the tower on the way, the strait to the isles.
		{"id":"south-tower","area":"south","kind":"relic","anchor":"way/south","up":15.0,
			"title":"The ring in the shrine's doorway"},
		{"id":"gap-ring","area":"south","kind":"relic","pay":20,"at":Vector2(-1300.0,2900.0),"up":16.0,
			"title":"The ring in the gap"},
		{"id":"strait-ring","area":"south","kind":"relic","pay":20,"at":Vector2(-880.0,3540.0),"up":8.0,
			"title":"The ring in the strait"},
		{"id":"south-field","area":"south","kind":"landing","at":Vector2(-1450.0,2450.0),"radius":60.0,
			"title":"Set down in the south meadow","hint":"Open grass west of the shrine"},
		{"id":"scarp-room","area":"south","kind":"relic","anchor":"chamber/south-scarp","up":0.0,
			"title":"The ring in the scarp's room","hint":"Cracked stone under a scarp, south"},
		{"id":"pond-ring","area":"south","kind":"relic","anchor":"pond/-1750_4107","up":8.0,
			"title":"The ring on the south pond"},
		{"id":"shore-arch","area":"south","kind":"relic","pay":20,"anchor":"endless/arch/-2_8/0","up":15.0,
			"title":"The ring under the shore arch","hint":"An arch on the far side of the strait"},
		{"id":"south-stack","area":"south","kind":"relic","pay":20,"anchor":"endless/rock/stacks/-5_9/0","pillar":0,"up":14.0,
			"title":"The ring over the south stack"},
		{"id":"south-ravine","area":"south","kind":"relic","pay":20,"at":Vector2(-1350.0,5000.0),"up":7.0,
			"title":"The ring in the south ravine","hint":"Low in a ravine past the shore arch"},
		# The foothills: the glacier and its gorge (spec-icefield.md: the long
		# crevasse, the ice arch by the head, the tunnel, the slot way's gates).
		{"id":"ice-skim","area":"foothills","kind":"relic","pay":20,"anchor":"peak/crevasse","up":8.0,
			"title":"The ring low over the ice","hint":"Low over the old ice"},
		{"id":"gorge-room","area":"foothills","kind":"relic","anchor":"chamber/gorge","up":0.0,
			"title":"The ring in the gorge room"},
		{"id":"bend-ring","area":"foothills","kind":"relic","pay":40,"anchor":"peak/ice-arch/1","up":0.0,
			"title":"The ring under the ice arch","hint":"Under the ice at the glacier's head"},
		{"id":"tunnel-deep","area":"foothills","kind":"relic","pay":40,"anchor":"peak/tunnel/deep","under":true,"up":15.0,
			"title":"The ring deep in the ice","hint":"A dark mouth in the glacier's flank"},
		{"id":"gorge-run","area":"foothills","kind":"line","place":"foothills","name":"gorge_run",
			"title":"The gorge run","hint":"Gates up the ice, bend after bend","mark":58.0,"gates":[
				{"at":Vector3(-1150.5,204,-155.2),"half":Vector2(3.0,2.5)},
				{"at":Vector3(-1246.1,212,-131.6),"half":Vector2(3.0,2.5)},
				{"at":Vector3(-1378,262,-90.1),"half":Vector2(5.0,4.0)},
				{"at":Vector3(-1417,285,-89.9),"half":Vector2(5.0,4.0)},
				{"at":Vector3(-1595.4,322,-329.1),"half":Vector2(6.0,4.0)},
				{"at":Vector3(-1685,363,-554),"half":Vector2(6.0,4.0)},
				{"at":Vector3(-1820,404,-752),"half":Vector2(6.0,4.0)},
				{"at":Vector3(-1892,425,-848),"half":Vector2(6.0,4.0)},
				{"at":Vector3(-1985,445,-917),"half":Vector2(6.0,4.0)},
				{"at":Vector3(-2187,486,-818),"half":Vector2(6.0,4.0)},
				{"at":Vector3(-2349,527,-643),"half":Vector2(6.0,4.0)},
				{"at":Vector3(-2435,548,-563),"half":Vector2(6.0,4.0)},
				{"at":Vector3(-2543,569,-573),"half":Vector2(6.0,4.0)},
				{"at":Vector3(-2639,613,-793),"half":Vector2(6.0,4.0)},
				{"at":Vector3(-2711,657,-1019),"half":Vector2(6.0,4.0)},
				{"at":Vector3(-2783,679,-1107),"half":Vector2(6.0,4.0)},
				{"at":Vector3(-2900,701,-1086),"half":Vector2(6.0,4.0)},
				{"at":Vector3(-2939,723,-979),"half":Vector2(6.0,4.0)}]},
		{"id":"serac-ring","area":"foothills","kind":"relic","anchor":"endless/rock/ice-forms/-2_0/0","up":25.0,
			"title":"The ring over the seracs"},
		{"id":"valley-head","area":"foothills","kind":"relic","pay":20,"anchor":"endless/rock/valley/-4_-1/0","up":8.0,
			"title":"The ring at the valley's head","hint":"Follow the valley up to where it ends"},
		{"id":"fold-ring","area":"foothills","kind":"relic","pay":40,"at":Vector2(-2100.0,100.0),"up":8.0,
			"title":"The ring in the deep fold","hint":"A fold in the hills, deeper than it looks"},
		{"id":"spur-ring","area":"foothills","kind":"relic","pay":20,"at":Vector2(-1350.0,-1250.0),"up":12.0,
			"title":"The ring on the spur"},
		{"id":"shelf-room","area":"foothills","kind":"relic","anchor":"chamber/high-shelf","up":0.0,
			"title":"The ring in the high room","hint":"Walls stand high on the Peak's north flank"},
		# The Peak.
		{"id":"tarn-shore","area":"peak","kind":"landing","pay":20,"anchor":"peak/strip/mid","offset":Vector3(15.0,0.0,2.6),"radius":130.0,
			"title":"Set down by the tarn","hint":"A lake high up, with a shore to stop on"},
		{"id":"tarn-skim","area":"peak","kind":"relic","pay":20,"anchor":"peak/tarn","up":5.0,
			"title":"The ring on the black water"},
		{"id":"tarn-room","area":"peak","kind":"relic","anchor":"chamber/tarn","up":0.0,
			"title":"The ring in the tarn room","hint":"Walls stand on the high plateau"},
		{"id":"crown-gap","area":"peak","kind":"relic","pay":20,"anchor":"peak/tower/0","up":40.0,"offset":Vector3(39.0,0.0,-98.0),
			"title":"The ring in the crown"},
		{"id":"dike-hole","area":"peak","kind":"relic","anchor":"peak/hole/2","up":0.0,
			"title":"The ring in the black wall","hint":"A hole in the black wall"},
		{"id":"high-hole","area":"peak","kind":"relic","pay":20,"anchor":"peak/hole/5","up":0.0,
			"title":"The ring in the high hole"},
		{"id":"summit-ring","area":"peak","kind":"relic","anchor":"peak/summit","up":22.0,
			"title":"The ring over the summit","hint":"Higher than anything here"},
		{"id":"low-hole","area":"peak","kind":"relic","anchor":"peak/hole/0","up":0.0,
			"title":"The ring in the low hole","hint":"The black wall's lowest hole"},
		{"id":"sill-eye","area":"peak","kind":"relic","pay":40,"anchor":"peak/sill/1","up":0.0,
			"title":"The ring in the sill's eye","hint":"A thin wall across the slot has an eye"},
		{"id":"bench-eye","area":"peak","kind":"relic","pay":20,"anchor":"peak/sill/3","up":0.0,
			"title":"The ring in the bench wall"},
		{"id":"boulder-ring","area":"peak","kind":"relic","pay":20,"anchor":"endless/rock/boulders/-7_-1/0","up":12.0,
			"title":"The ring among the boulders","hint":"Boulders strewn on the high ground"},
		# The near coast: arches, stacks, the islands, the light and the ship.
		{"id":"saddle-ring","area":"coast","kind":"relic","at":Vector2(1260.0,-900.0),"up":22.0,
			"title":"The ring on the saddle"},
		{"id":"sea-arch-ring","area":"coast","kind":"relic","anchor":"endless/arch/3_-2/0","up":14.0,
			"title":"The ring under the sea arch","hint":"A tall arch stands on the east shore"},
		{"id":"aqueduct-ring","area":"coast","kind":"relic","pay":20,"anchor":"endless/arch/4_0/0","up":14.0,
			"title":"The ring under the aqueduct"},
		{"id":"high-arch","area":"coast","kind":"relic","pay":20,"anchor":"endless/arch/3_3/0","up":10.0,
			"title":"The ring in the high arch","hint":"A lone arch on the southern hill"},
		{"id":"stack-top","area":"coast","kind":"relic","anchor":"endless/rock/stacks/4_-2/0","pillar":0,"up":14.0,
			"title":"The ring over the stacks","hint":"On top of the rocks in the bay"},
		{"id":"giant-stack","area":"coast","kind":"relic","anchor":"endless/rock/stacks/4_5/0","pillar":0,"up":14.0,
			"title":"The ring over the giant"},
		{"id":"stack-run","area":"coast","kind":"line","place":"coast","name":"round_the_stacks",
			"title":"Round the stacks","hint":"Gates in the bay, out and back through the rocks","mark":20.0,"gates":[
				{"at":Vector3(1900,-24,-600),"half":Vector2(9.0,5.0)},
				{"at":Vector3(1958,-24,-779),"half":Vector2(9.0,5.0)},
				{"at":Vector3(2012,-24,-882),"half":Vector2(9.0,5.0)},
				{"at":Vector3(2135,-24,-1040),"half":Vector2(9.0,5.0)},
				{"at":Vector3(2170,-24,-950),"half":Vector2(9.0,5.0)},
				{"at":Vector3(2094,-24,-844),"half":Vector2(9.0,5.0)},
				{"at":Vector3(1984,-24,-716),"half":Vector2(9.0,5.0)},
				{"at":Vector3(1870,-24,-625),"half":Vector2(9.0,5.0)}]},
		{"id":"arch-run","area":"coast","kind":"line","place":"coast","name":"arch_run",
			"title":"The arch run","hint":"Gates through the arches of the east hills","mark":33.0,"gates":[
				{"at":Vector3(2530,68,59),"dir":Vector3(0.97,0.0,0.25),"half":Vector2(7.0,5.0)},
				{"at":Vector3(2603,50,78),"dir":Vector3(0.97,0.0,0.25),"half":Vector2(3.0,2.0)},
				{"at":Vector3(2760,30,150),"half":Vector2(9.0,6.0)},
				{"at":Vector3(2870,70,300),"half":Vector2(9.0,6.0)},
				{"at":Vector3(2775,92,445),"half":Vector2(9.0,6.0)},
				{"at":Vector3(2656,30,530),"dir":Vector3(-0.56,0.0,0.83),"half":Vector2(7.0,5.0)},
				{"at":Vector3(2612,5,597),"dir":Vector3(-0.56,0.0,0.83),"half":Vector2(3.0,2.0)},
				{"at":Vector3(2620,6,790),"dir":Vector3(1.0,0.0,-0.1),"half":Vector2(12.0,6.0)},
				{"at":Vector3(2668,14,640),"dir":Vector3(-0.45,0.0,-0.9),"half":Vector2(9.0,5.0)},
				{"at":Vector3(2562,8,505),"dir":Vector3(-0.09,0.0,-1.0),"half":Vector2(7.0,4.0)},
				{"at":Vector3(2554,5,426),"dir":Vector3(-0.09,0.0,-1.0),"half":Vector2(3.0,2.0)},
				{"at":Vector3(2515,42,362),"dir":Vector3(-0.5,0.0,-0.85),"half":Vector2(9.0,5.0)},
				{"at":Vector3(2425,80,300),"dir":Vector3(-0.9,0.0,-0.4),"half":Vector2(10.0,6.0)}]},
		{"id":"sound-ring","area":"coast","kind":"relic","at":Vector2(560.0,2120.0),"up":6.0,
			"title":"The ring on the sound"},
		{"id":"isle-tower","area":"coast","kind":"relic","anchor":"way/isle","up":17.0,"offset":Vector3(9.25,0.0,-0.5),
			"title":"The ring in the temple's broken porch"},
		{"id":"lone-stack","area":"coast","kind":"relic","anchor":"endless/rock/stacks/2_5/0","pillar":0,"up":14.0,
			"title":"The ring over the lone stack"},
		{"id":"long-isle","area":"coast","kind":"landing","at":Vector2(455.0,3510.0),"radius":300.0,
			"title":"Set down on Long Isle","hint":"An island with room to land"},
		{"id":"isle-room","area":"coast","kind":"relic","anchor":"chamber/long-isle","up":0.0,
			"title":"The ring in the island's room"},
		{"id":"light-rock","area":"coast","kind":"landing","pay":20,"at":Vector2(2097.0,3222.0),"radius":140.0,
			"title":"Set down on Light Rock","hint":"There's a flat under the lighthouse"},
		{"id":"lamp-ring","area":"coast","kind":"relic","anchor":"coast/lighthouse","up":50.0,"offset":Vector3(18.0,0.0,-14.0),
			"title":"The ring by the lamp"},
		{"id":"boat-deck","area":"coast","kind":"landing","pay":40,"at":Vector2(2225.0,3330.0),"radius":90.0,
			"title":"Set down on the Rock's south shelf","hint":"Past the light, a long shelf runs down the Rock"},
		{"id":"ship-hold","area":"coast","kind":"relic","pay":40,"anchor":"coast/ship","up":8.0,
			"title":"The ring on the gun deck","hint":"Something sails off the Horn. It has a way in"},
		{"id":"horn-mouth","area":"coast","kind":"relic","pay":20,"at":Vector2(2930.0,3900.0),"up":12.0,
			"title":"The ring in the Horn's mouth"},
		{"id":"ridge-arch","area":"coast","kind":"relic","pay":20,"anchor":"endless/arch/4_1/0","up":19.0,
			"title":"The ring under the ridge arch","hint":"An arch on the hill past the aqueduct"},
		{"id":"far-stack","area":"coast","kind":"relic","anchor":"endless/rock/stacks/7_2/0","pillar":0,"up":14.0,
			"title":"The ring over the far stack"},
		# The far lands: north past the cup, east past the arches, west past the Peak.
		{"id":"downs-ring","area":"north","kind":"relic","at":Vector2(400.0,-2400.0),"up":25.0,
			"title":"The ring over the downs"},
		{"id":"downs-flat","area":"north","kind":"landing","at":Vector2(-1450.0,-2950.0),"radius":60.0,
			"title":"Set down on the north flats","hint":"Flat grass, a long way north"},
		{"id":"downs-room","area":"north","kind":"relic","anchor":"chamber/north-downs","up":0.0,
			"title":"The ring in the downs' room","hint":"Cracked stone on the north downs"},
		{"id":"north-arch","area":"north","kind":"relic","pay":20,"anchor":"endless/arch/0_-10/0","up":10.0,
			"title":"The ring under the north arch","hint":"An arch on a hill by the north sea"},
		{"id":"north-stack","area":"north","kind":"relic","pay":20,"anchor":"endless/rock/stacks/1_-10/0","pillar":0,"up":14.0,
			"title":"The ring over the north stack"},
		{"id":"north-split","area":"north","kind":"relic","pay":20,"anchor":"endless/split/-1_-4","up":8.0,
			"title":"The ring in the north split","hint":"The land splits open by the north sea"},
		{"id":"east-stack","area":"east","kind":"relic","anchor":"endless/rock/stacks/8_0/0","pillar":0,"up":14.0,
			"title":"The ring over the east stack"},
		{"id":"east-arch","area":"east","kind":"relic","pay":20,"anchor":"endless/arch/9_3/0","up":12.0,
			"title":"The ring under the east arch","hint":"A rock arch down the east shore"},
		{"id":"shore-room","area":"east","kind":"relic","anchor":"chamber/east-shore","up":0.0,
			"title":"The ring in the shore room","hint":"Cracked stone on a shore, east"},
		{"id":"east-flat","area":"east","kind":"landing","pay":20,"at":Vector2(5050.0,-1750.0),"radius":60.0,
			"title":"Set down on the east flats"},
		{"id":"east-split","area":"east","kind":"relic","pay":40,"anchor":"endless/split/2_-2","up":6.0,
			"title":"The ring in the east split","hint":"The land splits open, north-east"},
		{"id":"west-flat","area":"west","kind":"landing","at":Vector2(-4750.0,450.0),"radius":60.0,
			"title":"Set down on the west flats","hint":"Flat land far past the Peak"},
		{"id":"west-arch","area":"west","kind":"relic","anchor":"endless/arch/-10_6/1","up":15.0,
			"title":"The ring under the west arch"},
		{"id":"west-vale","area":"west","kind":"relic","pay":20,"at":Vector2(-4200.0,3200.0),"up":8.0,
			"title":"The ring in the far vale","hint":"A vale running down to the west sea"},
		{"id":"west-split","area":"west","kind":"relic","pay":40,"anchor":"endless/split/-4_1","up":6.0,
			"title":"The ring in the west split","hint":"Up the gorge from its mouth"},
		{"id":"gorge-mouth-room","area":"west","kind":"relic","anchor":"chamber/west-gorge","up":0.0,
			"title":"The ring in the gorge mouth's room","hint":"Cracked stone in a gorge's mouth, far west"},
	],
	"amberlands":[],
}
