"""Hero Joshua tree: plated trunk, angular forking limbs, a shaggy dead-leaf skirt under
each rosette and spiky blade rosettes at the tips.

Run: blender -b --factory-startup --python tools/blender_trees/joshua.py [-- --no-render]
"""
import sys, math
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import bmesh
from mathutils import Vector, Matrix
import kit
from kit import rng, srgb, mix

kit.seed(23)
BARK_DARK, BARK_LIGHT = srgb('3f342a'), srgb('77644f')
SKIRT_DARK, SKIRT_LIGHT = srgb('5e4c35'), srgb('a58c5f')
BLADE_DARK, BLADE_LIGHT, BLADE_TIP = srgb('4d6a3c'), srgb('8fa55a'), srgb('c2bd70')

asset = kit.fresh_scene('EXPORT - hero joshua')
wood, skirts, blades = bmesh.new(), bmesh.new(), bmesh.new()
tips = []


def turn(direction, degrees):
	"""Bend a direction by an angle around a random horizontal-ish axis, then lift it."""
	axis = direction.cross(Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), 0))).normalized()
	d = Matrix.Rotation(math.radians(degrees), 3, axis) @ direction
	d.z += 0.3
	return d.normalized()


def rosette(tip, direction):
	for i in range(26):
		# Blades fan through a wide cone; the outer ones droop, as on real rosettes.
		cone = math.radians(100) * math.sqrt(rng.random())
		d = turn_around(direction, cone, rng.uniform(0, math.tau))
		d.z -= 0.25 * (cone / math.radians(100)) ** 2
		kit.spike(blades, tip, d, rng.uniform(0.34, 0.5), 0.035)
	for i in range(5):
		kit.spike(blades, tip, turn_around(direction, rng.uniform(0, 0.3), rng.uniform(0, math.tau)), rng.uniform(0.25, 0.32), 0.03)


def turn_around(direction, cone, spin):
	side = direction.orthogonal().normalized()
	up = direction.cross(side)
	return (direction * math.cos(cone) + (side * math.cos(spin) + up * math.sin(spin)) * math.sin(cone)).normalized()


def heading(direction):
	return math.atan2(direction.y, direction.x), math.asin(max(-1.0, min(1.0, direction.z)))


def aim(h, e):
	return Vector((math.cos(h) * math.cos(e), math.sin(h) * math.cos(e), math.sin(e)))


def grow(start, direction, radius, depth):
	length = rng.uniform(0.8, 1.05) if depth >= 2 else rng.uniform(0.55, 0.75)
	kink = direction.orthogonal().normalized() * rng.uniform(-0.12, 0.12)
	end = start + direction * length
	kit.tube(wood, [start - direction * 0.08, start + direction * length * 0.5 + kink, end], [radius, radius * 0.9, radius * 0.8], 6, gnarl=0.12)
	if depth == 0:
		# Shaggy skirt of dead leaves hanging below the living rosette.
		skirt_top = end + direction * 0.04
		skirt_bottom = end - direction * rng.uniform(0.5, 0.7) + Vector((0, 0, -0.1))
		kit.tube(skirts, [skirt_bottom, skirt_bottom.lerp(skirt_top, 0.55), skirt_top], [radius * 1.05, radius * 1.4, radius * 1.3], 7, gnarl=0.3)
		rosette(end + direction * 0.03, direction)
		tips.append(end)
		return
	# Forks fan out around the vertical and climb a little: the classic reaching-arms silhouette.
	h, e = heading(direction)
	count = 3 if depth >= 2 and rng.random() < 0.4 else 2
	spreads = (-0.8, 0.0, 0.8) if count == 3 else (-0.6, 0.6)
	for spread in spreads:
		child_h = h + spread * rng.uniform(0.75, 1.1)
		child_e = min(math.radians(78), e + math.radians(rng.uniform(6, 22)))
		grow(end, aim(child_h, child_e), radius * 0.8, depth - 1)


trunk = [Vector((0, 0, -0.1)), Vector((0.03, 0, 0.5)), Vector((0.08, 0.02, 1.05)), Vector((0.1, 0.05, 1.45))]
kit.tube(wood, trunk, [0.34, 0.27, 0.24, 0.21], 8, gnarl=0.13)
for a, e, depth in ((15, 34, 2), (140, 28, 2), (255, 40, 1)):
	grow(trunk[-1], aim(math.radians(a), math.radians(e)), 0.15, depth)

bark = kit.to_object(wood, 'Bark', asset)
thatch = kit.to_object(skirts, 'Thatch', asset)
leaves = kit.to_object(blades, 'Blades', asset)
height = max(v.co.z for v in leaves.data.vertices)
print('JOSHUA rosettes', len(tips), 'height', round(height, 2))


def bark_colour(poly):
	return mix(BARK_DARK, BARK_LIGHT, 0.3 + 0.5 * rng.random() + 0.2 * max(poly.normal.z, 0)) * rng.uniform(0.92, 1.06)


def thatch_colour(poly):
	# Lighter, sun-bleached at the top of each skirt; dark and matted underneath.
	nearest = min(tips + [trunk[-1]], key=lambda t: (t - poly.center).length)
	drop = max(0.0, min(1.0, (nearest.z - poly.center.z) / 0.6))
	return mix(SKIRT_LIGHT, SKIRT_DARK, drop * 0.8 + 0.3 * rng.random()) * rng.uniform(0.9, 1.08)


def blade_colour(poly):
	# Blades are three-faced pyramids; the face centre's distance from its rosette sets the tip tint.
	nearest = min(tips, key=lambda t: (t - poly.center).length)
	out = min(1.0, (poly.center - nearest).length / 0.3)
	base = mix(BLADE_DARK, BLADE_LIGHT, 0.35 + 0.45 * max(poly.normal.z, 0) + 0.25 * rng.random())
	return mix(base, BLADE_TIP, max(0.0, out - 0.6) * 1.2) * rng.uniform(0.93, 1.06)


kit.paint(bark, bark_colour)
kit.paint(thatch, thatch_colour)
kit.paint(leaves, blade_colour)


def stage(collection):
	kit.ground(collection, 8, srgb('c49a68'), srgb('ddb987'), relief=0.18)


kit.finish('hero-joshua', [(bark, 'Bark', 0.95), (thatch, 'Thatch', 1.0), (leaves, 'Blades', 0.8)],
	{'description': 'Faceted hero Joshua tree; origin at ground contact. Blades palette_role 2, bark and thatch palette_role 4.',
		'height_m': round(height, 2)},
	stage,
	{
		'three-quarter': ((8.5, -9.5, 5.5), (0.3, 0.3, 2.0), 45),
		'low-hero': ((3.8, -5.2, 0.8), (0.2, 0.2, 2.2), 30),
		'diorama': ((7.5, -7.5, 10), (0.3, 0.3, 1.5), 45),
		'side': ((-9.5, -3, 2.8), (0.3, 0.3, 2.0), 45),
	}, sun_rotation=(58, 0, 55))
