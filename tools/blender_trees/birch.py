"""Hero birch: a slender pale stem with a smaller sister stem, dark lenticel marks and a
rough dark foot, under a light, airy crown of small clumps on climbing, tip-drooping twigs.

Run: blender -b --factory-startup --python tools/blender_trees/birch.py [-- --no-render]
"""
import sys, math
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import bmesh
from mathutils import Vector, noise
import kit
from kit import rng, srgb, mix

kit.seed(41)
LEAF_DARK, LEAF_MID, LEAF_LIGHT = srgb('4d7a34'), srgb('79a445'), srgb('b4cf6a')
BARK_WHITE, BARK_CREAM, MARK, FOOT = srgb('f2efe6'), srgb('ddd3c0'), srgb('1c1917'), srgb('2e2a26')

asset = kit.fresh_scene('EXPORT - hero birch')
wood, leaves = bmesh.new(), bmesh.new()
stems = []


def stem(base, lean, height, r0, sides):
	"""A gently S-curved stem; returns its centre line."""
	count = max(5, int(height / 0.42))
	side = Vector((-lean.y, lean.x, 0))
	pts = [Vector(base) + lean * (height * t) ** 1.3 * 0.09 + side * 0.12 * math.sin(t * 5.0) + Vector((0, 0, height * t))
		for t in (i / (count - 1) for i in range(count))]
	pts[0].z = -0.1
	kit.tube(wood, pts, kit.taper(r0, 0.02, count, 0.9), sides, gnarl=0.05)
	stems.append(pts)
	return pts


def at(pts, t):
	f = t * (len(pts) - 1)
	i = min(int(f), len(pts) - 2)
	return pts[i].lerp(pts[i + 1], f - i)


def twig(start, direction, length, radius, clumps):
	"""A climbing twig whose tip droops, with small clumps strung along its outer half."""
	d = direction.normalized()
	tip = start + d * length + Vector((0, 0, -0.22 * length))
	mid = start + d * length * 0.55 + Vector((0, 0, 0.12 * length))
	kit.tube(wood, [start, mid, tip], [radius, radius * 0.6, radius * 0.3], 4, gnarl=0.1)
	for i in range(clumps):
		t = 0.45 + 0.55 * (i + rng.uniform(0.0, 0.5)) / clumps
		p = (start.lerp(mid, t * 2) if t < 0.5 else mid.lerp(tip, t * 2 - 1)) + Vector((0, 0, rng.uniform(-0.05, 0.12)))
		kit.clump(leaves, p, rng.uniform(0.46, 0.64) * (1.0 - 0.2 * (i / clumps)), squash=0.74, points=11, stretch=(1.25, 0.9))


main = stem((0, 0, 0), Vector((0.8, 0.3, 0)).normalized(), 7.2, 0.21, 7)
sister = stem((0.18, -0.12, 0), Vector((0.3, -1.0, 0)).normalized(), 5.2, 0.13, 6)
golden = math.pi * (3 - math.sqrt(5))
# Twigs climb in a golden spiral; the crown is a narrow, open oval, widest a third of the way up.
for pts, lo, hi, count, reach in ((main, 0.38, 0.95, 11, 1.75), (sister, 0.5, 0.95, 5, 1.2)):
	for i in range(count):
		t = lo + (hi - lo) * i / (count - 1)
		shape = math.sin(math.pi * min(1.0, (t - lo) / (hi - lo) * 0.8 + 0.2))
		a = i * golden + rng.uniform(-0.3, 0.3)
		d = Vector((math.cos(a), math.sin(a), rng.uniform(0.9, 1.4)))
		twig(at(pts, t), d, reach * (0.45 + 0.6 * shape) * rng.uniform(0.85, 1.1), 0.045 * (1.1 - t), 2)
# A small crown top on each leader.
for pts, r in ((main, 0.48), (sister, 0.4)):
	kit.clump(leaves, pts[-1] + Vector((0, 0, 0.1)), r, squash=1.1, points=13)

bark = kit.to_object(wood, 'Bark', asset)
crown = kit.to_object(leaves, 'Crown', asset)
before = len(crown.data.polygons)
holes = kit.merge_shell(crown, weld=0.01, planar=3)
zs = [v.co.z for v in crown.data.vertices]
zmin, zmax = min(zs), max(zs)
spread = max(Vector((v.co.x, v.co.y)).length for v in crown.data.vertices)
print('BIRCH crown faces', before, '->', len(crown.data.polygons), 'boundary edges', holes,
	'bark', len(bark.data.polygons), 'height', round(zmax, 2), 'spread', round(spread, 2))


def leaf_colour(poly):
	c, n = poly.center, poly.normal
	h = (c.z - zmin) / (zmax - zmin)
	light = 0.35 * h + 0.25 * min(1.0, c.xy.length / spread) + 0.4 * max(n.z, 0) - 0.25 * max(-n.z, 0)
	base = mix(LEAF_DARK, LEAF_MID, light * 1.5) if light < 0.66 else mix(LEAF_MID, LEAF_LIGHT, (light - 0.66) * 2.4)
	return base * rng.uniform(0.93, 1.06)


def bark_colour(poly):
	# Chalk-white with horizontal dark lenticel dashes, darker and rougher at the foot.
	c = poly.center
	band = noise.noise(Vector((c.x * 0.6, c.y * 0.6, c.z * 3.1)))
	base = mix(BARK_WHITE, BARK_CREAM, rng.random() * 0.7)
	if band > 0.22 or rng.random() < 0.1:
		base = mix(base, MARK, 0.9 + 0.1 * rng.random())
	foot = max(0.0, min(1.0, (1.1 - c.z) / 0.7))
	return mix(base, FOOT, foot * (0.75 + 0.25 * rng.random())) * rng.uniform(0.95, 1.04)


kit.paint(crown, leaf_colour)
kit.paint(bark, bark_colour)


def stage(collection):
	kit.ground(collection, 10, srgb('5f8c3c'), srgb('86ad4e'))
	kit.pine(collection, (4.8, 3.2, 0), 6.0)


kit.finish('hero-birch', [(bark, 'Bark', 0.9), (crown, 'Crown', 0.85)],
	{'description': 'Faceted hero birch; origin at ground contact. Crown palette_role 2 (tinted per tree), bark palette_role 4.',
		'height_m': round(zmax, 2), 'crown_bottom_m': round(zmin, 2)},
	stage,
	{
		'three-quarter': ((12, -13, 7), (0.3, 0.3, 3.6), 45),
		'low-hero': ((5, -7, 0.9), (0.3, 0.3, 3.8), 26),
		'diorama': ((11, -11, 15), (0.3, 0.3, 2.5), 42),
		'side': ((-14, -4, 4), (0.3, 0.3, 3.6), 45),
	})
