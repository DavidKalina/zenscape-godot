"""Hero weeping willow: a short furrowed trunk that splits low into arching limbs, a
domed top and a curtain of hanging lobes that sweep out and fall nearly to the ground,
with gaps where the trunk shows through.

Run: blender -b --factory-startup --python tools/blender_trees/willow.py [-- --no-render]
"""
import sys, math
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import bmesh
from mathutils import Vector
import kit
from kit import rng, srgb, mix

kit.seed(57)
LEAF_DARK, LEAF_MID, LEAF_LIGHT = srgb('4c6e2e'), srgb('86a445'), srgb('c2d27a')
BARK_DARK, BARK_LIGHT = srgb('3f3329'), srgb('7d6a55')

asset = kit.fresh_scene('EXPORT - hero willow')
wood, leaves = bmesh.new(), bmesh.new()


def drape(top, bottom, width, depth, outward, points=7, taper=0.72):
	"""One hanging lobe: a convex hull of flattened rings, broad where it leaves the crown
	and narrowing to a ragged tip. Width runs round the crown, depth along `outward`."""
	top, bottom = Vector(top), Vector(bottom)
	side = Vector((-outward.y, outward.x, 0)).normalized()
	verts = []
	for i, t in enumerate((0.0, 0.3, 0.65, 1.0)):
		centre = top.lerp(bottom, t)
		scale = (1.0 - taper * t ** 1.3) * rng.uniform(0.9, 1.1)
		ring = points if t < 1.0 or taper == 0.0 else 3
		for k in range(ring):
			a = (k + rng.uniform(-0.2, 0.2)) * math.tau / ring
			verts.append(leaves.verts.new(centre + side * math.cos(a) * width * scale + outward * math.sin(a) * depth * scale
				+ Vector((0, 0, rng.uniform(-0.08, 0.08)))))
	if taper > 0.0:
		verts.append(leaves.verts.new(bottom + Vector((0, 0, -rng.uniform(0.15, 0.35)))))
	result = bmesh.ops.convex_hull(leaves, input=verts)
	loose = list({v for v in result['geom_interior'] + result['geom_unused'] if isinstance(v, bmesh.types.BMVert)})
	bmesh.ops.delete(leaves, geom=loose, context='VERTS')


# ---------------------------------------------------------------- wood
fork = Vector((0.15, 0.05, 1.9))
kit.tube(wood, [(0, 0, -0.1), (0.04, 0.0, 0.6), (0.1, 0.03, 1.3), fork], [0.42, 0.34, 0.31, 0.3], 8, gnarl=0.12)
for k in range(4):
	a = k * math.tau / 4 + rng.uniform(-0.3, 0.3)
	d = Vector((math.cos(a), math.sin(a), 0))
	kit.tube(wood, [d * 0.12 + Vector((0, 0, 0.45)), d * 0.45 + Vector((0, 0, 0.08)), d * 0.8 + Vector((0, 0, -0.08))], [0.18, 0.1, 0.04], 5, gnarl=0.1)
limbs = []
for k in range(5):
	a = k * math.tau / 5 + rng.uniform(-0.25, 0.25)
	d = Vector((math.cos(a), math.sin(a), 0))
	reach = rng.uniform(1.5, 2.1)
	end = fork + d * reach + Vector((0, 0, rng.uniform(2.3, 2.9)))
	pts = kit.bowed(fork - Vector((0, 0, 0.25)), end, d * -0.2 + Vector((0, 0, 0.35)), 4)
	kit.tube(wood, pts, kit.taper(0.19, 0.05, len(pts)), 6, gnarl=0.1)
	limbs.append((d, end))

# ---------------------------------------------------------------- crown
# The dome: one low mound over the fork, filled out by smaller clumps on the limb ends.
for d, end in limbs:
	kit.clump(leaves, end + Vector((0, 0, -0.1)), rng.uniform(0.75, 0.9), squash=0.7, points=11)
kit.clump(leaves, fork + Vector((0, 0, 3.15)), 1.75, squash=0.62, points=20)
# The curtain: each lobe arches over the dome's shoulder to a knee, then hangs, ragged
# in length and a little skewed, so the hem is uneven rather than a fringe.
count = 13
gaps = set(rng.sample(range(count), 3))
for i in range(count):
	a = (i + rng.uniform(-0.3, 0.3)) * math.tau / count
	out = Vector((math.cos(a), math.sin(a), 0))
	side = Vector((-out.y, out.x, 0))
	top = fork + out * rng.uniform(0.9, 1.3) + Vector((0, 0, rng.uniform(3.35, 3.65)))
	knee = fork + out * rng.uniform(2.0, 2.35) + side * rng.uniform(-0.2, 0.2) + Vector((0, 0, rng.uniform(2.55, 2.85)))
	# Gaps hang short, so the trunk shows through the curtain there.
	drop = rng.uniform(1.0, 1.5) if i in gaps else rng.uniform(2.3, 3.6)
	bottom = knee + out * rng.uniform(0.35, 0.6) + side * rng.uniform(-0.3, 0.3) - Vector((0, 0, drop))
	width = rng.uniform(0.5, 0.72)
	drape(top, knee, width * 0.85, 0.3, out, points=5, taper=0.0)
	drape(knee + Vector((0, 0, 0.15)), bottom, width, rng.uniform(0.28, 0.38), out, points=6)
	if i % 2 == 0:
		# A shorter lobe hung inside thickens the curtain.
		inner = knee - out * 0.7 + Vector((0, 0, 0.2))
		drape(inner, inner + out * 0.3 - Vector((0, 0, drop * rng.uniform(0.45, 0.65))), 0.6, 0.34, out, points=5)

bark = kit.to_object(wood, 'Bark', asset)
crown = kit.to_object(leaves, 'Crown', asset)
before = len(crown.data.polygons)
holes = kit.merge_shell(crown, weld=0.01, planar=3)
zs = [v.co.z for v in crown.data.vertices]
zmin, zmax = min(zs), max(zs)
spread = max(Vector((v.co.x, v.co.y)).length for v in crown.data.vertices)
print('WILLOW crown faces', before, '->', len(crown.data.polygons), 'boundary edges', holes,
	'bark', len(bark.data.polygons), 'height', round(zmax, 2), 'spread', round(spread, 2), 'crown bottom', round(zmin, 2))


def leaf_colour(poly):
	# Light catches the dome and the outer curtain; the inside of the curtain stays dark.
	c, n = poly.center, poly.normal
	h = (c.z - zmin) / (zmax - zmin)
	radial = Vector((c.x, c.y, 0)).normalized() if c.xy.length > 0.01 else Vector((0, 0, 1))
	outer = max(0.0, n.dot(radial))
	light = 0.35 * h + 0.3 * outer + 0.35 * max(n.z, 0) - 0.2 * max(-n.z, 0)
	base = mix(LEAF_DARK, LEAF_MID, light * 1.5) if light < 0.66 else mix(LEAF_MID, LEAF_LIGHT, (light - 0.66) * 2.4)
	return base * rng.uniform(0.93, 1.06)


def bark_colour(poly):
	lit = 0.3 + 0.4 * rng.random() + 0.3 * max(poly.normal.z, 0)
	return mix(BARK_DARK, BARK_LIGHT, lit) * rng.uniform(0.9, 1.06)


kit.paint(crown, leaf_colour)
kit.paint(bark, bark_colour)


def stage(collection):
	kit.ground(collection, 12, srgb('5f8c3c'), srgb('86ad4e'))
	kit.pine(collection, (6.0, 4.5, 0), 6.0)


kit.finish('hero-willow', [(bark, 'Bark', 0.95), (crown, 'Crown', 0.85)],
	{'description': 'Faceted hero weeping willow; origin at ground contact. Crown palette_role 2 (tinted per tree), bark palette_role 4.',
		'height_m': round(zmax, 2), 'crown_bottom_m': round(zmin, 2)},
	stage,
	{
		'three-quarter': ((13, -14, 7.5), (0.3, 0.3, 2.8), 45),
		'low-hero': ((6, -8, 0.9), (0.3, 0.3, 2.8), 24),
		'diorama': ((12, -12, 16), (0.3, 0.3, 1.8), 42),
		'side': ((-15, -4, 3.5), (0.3, 0.3, 2.8), 45),
	})
