"""Hero coast redwood: fluted, flared trunk with a fire scar, bare lower bole, shelf-like
foliage on drooping branches and a narrow spire.

Run: blender -b --factory-startup --python tools/blender_trees/redwood.py [-- --no-render]
"""
import sys, math
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import bmesh
from mathutils import Vector
import kit
from kit import rng, srgb, mix

kit.seed(16)
HEIGHT = 16.0
FOLIAGE_DARK, FOLIAGE_MID, FOLIAGE_LIGHT = srgb('1f3a28'), srgb('30573a'), srgb('5b844a')
BARK_DARK, BARK_LIGHT, CHAR = srgb('5a3024'), srgb('a0603e'), srgb('2a201c')

asset = kit.fresh_scene('EXPORT - hero redwood')

# ---------------------------------------------------------------- trunk
heights = [-0.15, 0.35, 1.1, 2.4, 4.4, 7.0, 9.6, 12.1, 14.1, 15.7]
trunk = [Vector((0.18 * math.sin(z * 0.23), 0.1 * math.sin(z * 0.17 + 1), z)) for z in heights]
radii = [0.62 * (1 - z / 17.5) ** 1.1 + 0.05 for z in heights]
radii[0] *= 2.0
radii[1] *= 1.4


def flutes(k, i):
	"""Alternate ridge and furrow, deepest at the buttressed base."""
	return 1.0 + (0.08 + 0.3 * math.exp(-i * 1.1)) * (1 if k % 2 == 0 else -0.35)


wood = bmesh.new()
kit.tube(wood, trunk, radii, 12, gnarl=0.04, profile=flutes, twist_step=(0.0, 0.06))


def trunk_at(z):
	for a, b in zip(trunk, trunk[1:]):
		if a.z <= z <= b.z:
			return a.lerp(b, (z - a.z) / (b.z - a.z))
	return trunk[-1]


# Dead stubs on the bare lower bole.
for z in (3.6, 4.4, 5.3, 6.0):
	a = rng.uniform(0, math.tau)
	d = Vector((math.cos(a), math.sin(a), -0.35)).normalized()
	start = trunk_at(z)
	kit.tube(wood, [start, start + d * rng.uniform(0.55, 0.8)], [0.07, 0.03], 5, gnarl=0.1)

# Branches in a golden-angle spiral; long and drooping low, short near the top.
foliage = bmesh.new()
golden = math.pi * (3 - math.sqrt(5))
z, index = 5.4, 0
while z < 14.6:
	t = (z - 5.4) / 9.2
	length = 2.0 * (1 - t) ** 0.8 + 0.6
	a = index * golden + rng.uniform(-0.25, 0.25)
	d = Vector((math.cos(a), math.sin(a), 0))
	start = trunk_at(z)
	mid = start + d * length * 0.55 + Vector((0, 0, -0.25 * (1 - t)))
	tip = start + d * length + Vector((0, 0, 0.05))
	kit.tube(wood, [start, mid, tip], [0.13 - 0.06 * t, 0.07, 0.03], 5, gnarl=0.1)
	radius = 0.62 + 0.62 * (length / 2.6)
	kit.clump(foliage, tip + d * 0.1 + Vector((0, 0, 0.12)), radius, squash=0.55, points=26, stretch=(1.25, 0.9))
	z += rng.uniform(0.34, 0.48)
	index += 1
# A core column hides the trunk inside the crown so the tree reads as one tall mass.
for zc in (6.4, 7.6, 8.8, 10.0, 11.2, 12.4, 13.5):
	t = (zc - 5.4) / 9.2
	kit.clump(foliage, trunk_at(zc), 1.05 * (1 - 0.5 * t) + 0.3, squash=1.0, points=26)
top = trunk_at(15.3)
kit.clump(foliage, top + Vector((0, 0, -0.5)), 0.95, squash=1.1, points=26)
kit.clump(foliage, top + Vector((0.05, 0, 0.7)), 0.48, squash=2.5, points=22, floor=-0.9)

bark = kit.to_object(wood, 'Bark', asset)
crown = kit.to_object(foliage, 'Foliage', asset)
before = len(crown.data.polygons)
holes = kit.merge_shell(crown, weld=0.02)
print('REDWOOD crown faces', before, '->', len(crown.data.polygons), 'boundary edges', holes)

# ---------------------------------------------------------------- colour
zs = [v.co.z for v in crown.data.vertices]
zmin, zmax = min(zs), max(zs)
reach = max(Vector((v.co.x, v.co.y)).length for v in crown.data.vertices)
scar_side = Vector((-1, 0.3, 0)).normalized()


def foliage_colour(poly):
	c, n = poly.center, poly.normal
	axis = trunk_at(c.z)
	outward = min(1.0, Vector((c.x - axis.x, c.y - axis.y)).length / (reach * 0.7))
	h = (c.z - zmin) / (zmax - zmin)
	light = 0.5 * outward + 0.4 * max(n.z, 0) - 0.3 * max(-n.z, 0) + 0.15 * h
	base = mix(FOLIAGE_DARK, FOLIAGE_MID, light * 1.5) if light < 0.66 else mix(FOLIAGE_MID, FOLIAGE_LIGHT, (light - 0.66) * 2.4)
	return base * rng.uniform(0.94, 1.05)


def bark_colour(poly):
	c, n = poly.center, poly.normal
	facing = Vector((n.x, n.y, 0)).normalized().dot(scar_side) if n.xy.length > 0.1 else 0
	scar = max(0.0, min(1.0, (2.6 - c.z) / 1.4)) * max(0.0, (facing - 0.35) / 0.65)
	lit = 0.35 + 0.35 * min(1.0, c.z / 8.0) + 0.3 * rng.random()
	return mix(mix(BARK_DARK, BARK_LIGHT, lit), CHAR, scar * 1.3) * rng.uniform(0.92, 1.06)


kit.paint(crown, foliage_colour)
kit.paint(bark, bark_colour)


def stage(collection):
	kit.ground(collection, 11, srgb('4b5a2c'), srgb('6f7c3c'))
	kit.pine(collection, (6.5, 4.5, 0), 6.0)


kit.finish('hero-redwood', [(bark, 'Bark', 0.95), (crown, 'Foliage', 0.85)],
	{'description': 'Faceted hero coast redwood; origin at ground contact. Foliage palette_role 2, bark palette_role 4.',
		'height_m': round(zmax, 2), 'crown_bottom_m': round(zmin, 2)},
	stage,
	{
		'three-quarter': ((21, -23, 11), (0.5, 0.5, 7.8), 45),
		'low-hero': ((5.5, -8.5, 1.0), (0, 0, 8.0), 22),
		'diorama': ((18, -18, 26), (1, 1, 5.5), 40),
		'side': ((-25, -6, 7), (0, 0, 8.0), 40),
	})
