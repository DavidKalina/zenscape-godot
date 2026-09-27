"""Hero juniper / scrub pine: a short, twisted, leaning trunk that splits into crooked
limbs reaching wide, flat evergreen pads at their ends and one bleached dead limb, the
wind-shaped tree of dry ridges and exposed ground.

Run: blender -b --factory-startup --python tools/blender_trees/juniper.py [-- --no-render]
"""
import sys, math
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import bmesh
from mathutils import Vector
import kit
from kit import rng, srgb, mix

kit.seed(73)
NEEDLE_DARK, NEEDLE_MID, NEEDLE_LIGHT = srgb('1f3b2e'), srgb('36604a'), srgb('6f9468')
BARK_DARK, BARK_LIGHT, DEADWOOD = srgb('4a2f22'), srgb('8f6448'), srgb('c9c1b1')

asset = kit.fresh_scene('EXPORT - hero juniper')
wood, dead, needles = bmesh.new(), bmesh.new(), bmesh.new()
pads = []


def crooked(start, end, r0, r1, steps, kink, sides=5):
	"""A limb that zigzags on its way: each joint is knocked sideways by up to `kink`."""
	start, end = Vector(start), Vector(end)
	pts = [start.lerp(end, i / steps) for i in range(steps + 1)]
	for p in pts[1:-1]:
		p += Vector((rng.uniform(-kink, kink), rng.uniform(-kink, kink), rng.uniform(-kink, kink) * 0.5))
	return pts, kit.tube(wood if sides else dead, pts, kit.taper(r0, r1, len(pts)), sides or 4, gnarl=0.18)


def pad(centre, radius):
	# Flat, wind-pressed foliage: wide and thin, with a smaller cushion on top.
	kit.clump(needles, centre, radius, squash=0.42, points=20, stretch=(1.3, 0.95))
	kit.clump(needles, centre + Vector((rng.uniform(-0.15, 0.15), rng.uniform(-0.15, 0.15), radius * 0.28)), radius * 0.6, squash=0.5, points=11)
	pads.append(centre)


# The trunk leans away from the prevailing wind and twists as it goes.
lean = Vector((0.45, 0.15, 0))
trunk = [Vector((0, 0, -0.1)), Vector((0.08, 0.0, 0.35)), Vector((0.25, 0.1, 0.7)), Vector((0.42, 0.12, 1.0)), Vector((0.5, 0.18, 1.25))]
kit.tube(wood, trunk, [0.34, 0.27, 0.23, 0.2, 0.17], 7, gnarl=0.2, twist_step=(0.3, 0.6))
for k in range(4):
	a = k * math.tau / 4 + rng.uniform(-0.4, 0.4)
	d = Vector((math.cos(a), math.sin(a), 0))
	kit.tube(wood, [d * 0.1 + Vector((0, 0, 0.3)), d * 0.42 + Vector((0, 0, 0.02)), d * 0.75 + Vector((0, 0, -0.1))], [0.15, 0.08, 0.03], 5, gnarl=0.15)
fork = trunk[-1]
# Limbs: two long ones downwind, one short one back into the wind, one climbing leader.
limbs = [
	(Vector((1.9, 0.6, 1.9)), 0.13, 0.9), (Vector((1.0, -1.5, 1.55)), 0.12, 0.8),
	(Vector((-1.3, 0.9, 1.6)), 0.1, 0.72), (Vector((0.7, 0.4, 2.6)), 0.12, 0.8),
]
for end, r0, size in limbs:
	pts, _ = crooked(fork - Vector((0, 0, 0.15)), end, r0, 0.05, 3, 0.22)
	pad(end + Vector((0, 0, 0.12)), size)
	# A side shoot off the middle joint carries a smaller, lower pad.
	joint = pts[2]
	side = joint + (end - fork).normalized().cross(Vector((0, 0, 1))) * rng.choice((-1, 1)) * 0.75 + Vector((0, 0, 0.1))
	crooked(joint, side, r0 * 0.6, 0.035, 2, 0.1)
	pad(side + Vector((0, 0, 0.1)), size * 0.62)
# Pads hugging the fork fill the crown's middle, so it reads as one windswept mass.
for offset, size in ((Vector((0.55, 0.05, 0.55)), 0.7), (Vector((-0.2, -0.45, 0.45)), 0.55), (Vector((0.2, 0.55, 0.9)), 0.55)):
	pad(fork + offset, size)
# The bleached dead limb reaching up out of the crown, with a broken stub.
pts, _ = crooked(fork + Vector((-0.05, 0, 0.1)), Vector((-0.6, -0.4, 2.6)), 0.09, 0.025, 3, 0.2, sides=0)
crooked(pts[2], pts[2] + Vector((-0.35, 0.1, 0.12)), 0.04, 0.015, 1, 0.0, sides=0)

bark = kit.to_object(wood, 'Bark', asset)
deadwood = kit.to_object(dead, 'Deadwood', asset)
crown = kit.to_object(needles, 'Crown', asset)
before = len(crown.data.polygons)
holes = kit.merge_shell(crown, weld=0.01, planar=3)
zs = [v.co.z for v in crown.data.vertices]
zmin, zmax = min(zs), max(zs)
spread = max(Vector((v.co.x, v.co.y)).length for v in crown.data.vertices)
print('JUNIPER crown faces', before, '->', len(crown.data.polygons), 'boundary edges', holes,
	'bark', len(bark.data.polygons) + len(deadwood.data.polygons), 'height', round(zmax, 2), 'spread', round(spread, 2))


def needle_colour(poly):
	c, n = poly.center, poly.normal
	nearest = min(pads, key=lambda p: (p - c).length)
	top = max(0.0, min(1.0, (c.z - nearest.z) / 0.35 + 0.5))
	light = 0.45 * top + 0.4 * max(n.z, 0) - 0.3 * max(-n.z, 0) + 0.1 * (c.z - zmin) / (zmax - zmin)
	base = mix(NEEDLE_DARK, NEEDLE_MID, light * 1.5) if light < 0.66 else mix(NEEDLE_MID, NEEDLE_LIGHT, (light - 0.66) * 2.4)
	return base * rng.uniform(0.93, 1.06)


def bark_colour(poly):
	# Stringy reddish bark, with bleached, stripped streaks spiralling up the trunk.
	lit = 0.3 + 0.45 * rng.random() + 0.25 * max(poly.normal.z, 0)
	base = mix(BARK_DARK, BARK_LIGHT, lit)
	if rng.random() < 0.12:
		base = mix(base, DEADWOOD, 0.6)
	return base * rng.uniform(0.92, 1.06)


kit.paint(crown, needle_colour)
kit.paint(bark, bark_colour)
kit.paint(deadwood, lambda p: mix(DEADWOOD, BARK_LIGHT, 0.25 * rng.random()) * rng.uniform(0.9, 1.05))


def stage(collection):
	kit.ground(collection, 8, srgb('9c8f62'), srgb('b8a878'), relief=0.2)
	kit.pine(collection, (4.0, 3.0, 0), 6.0)


kit.finish('hero-juniper', [(bark, 'Bark', 0.95), (deadwood, 'Deadwood', 0.9), (crown, 'Crown', 0.9)],
	{'description': 'Faceted hero juniper; origin at ground contact. Crown palette_role 2 (tinted per tree), bark and deadwood palette_role 4.',
		'height_m': round(max(zmax, 2.9), 2), 'crown_bottom_m': round(zmin, 2)},
	stage,
	{
		'three-quarter': ((8, -9, 5), (0.5, 0.2, 1.4), 45),
		'low-hero': ((4, -5.5, 0.7), (0.5, 0.2, 1.5), 26),
		'diorama': ((7, -7, 9.5), (0.5, 0.2, 1.0), 42),
		'side': ((-9.5, -3, 2.2), (0.5, 0.2, 1.4), 45),
	}, sun_rotation=(55, 0, 50))
