extends RefCounted
## The kinds a region's placed list may name (scripts/endless/placed_sites.gd;
## docs/design/endless-flight/wilderness-kit.md, "How a region is made"):
## a kind's name to its script in scripts/endless/kinds/.
##
## Every kind's script has one build entry:
##   static func build(site: Dictionary) -> Node3D
## The site in (placed_sites.gd `site_of`): handle, kind, skin, x, z, heading
## (degrees, the node's yaw: 0 faces north, -Z; 90 faces west, -X), params
## (the list's own dictionary), region (the list's region id), y (the ground
## under the coded spot, or params.y), xform (Transform3D, where the piece
## stands in the world after the layout file's moves) and field (the
## LandField, main thread only). A Node3D out, built in its own frame: its
## origin is the site's foot, -Z its heading; the reader places it at
## `xform`. A kind that shapes or reads the land round it uses `xform` and
## `field`. The skin is the kind's to read ("" for its plain one).
##
## A lane adds its kind with one line in KINDS, after `marker`.

const KINDS := {
	"marker": preload("res://scripts/endless/kinds/marker.gd"),
}

## Whether `kind` is in the table.
static func has(kind: String) -> bool:
	return KINDS.has(kind)

## Kind `site.kind` built for `site`, or null (an unknown kind warns once).
static func build(site: Dictionary) -> Node3D:
	var kind := str(site.get("kind",""))
	if not KINDS.has(kind):
		if not _warned.has(kind):
			_warned[kind] = true
			push_warning("placed site %s: no kind '%s' in scripts/endless/kinds/kinds.gd" % [site.get("handle","?"),kind])
		return null
	return (KINDS[kind] as GDScript).build(site)

static var _warned := {}
