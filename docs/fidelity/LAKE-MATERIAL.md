# Source lake material parameters

The live source lake has opacity .9536031282, roughness .8610449858, and volume
[1.05243873596, 0, .72000002861, .44323754311]. The previous native material used
roughness .22, absorption span .45 and a .4 floor. export_lake_wind.mjs now reads
the actual uVolume from the rendered Three.js program and verifies both vertex
positions and colors against the saved scene before updating the data.

The imported material now uses source absorption, opacity and roughness. Its
Fresnel factor is (.02 + .98*(1-facing)^5) times the source sky gain; transparency
is closed toward opaque by that reflection after absorption. The source ice
roughness rule is retained, including clear ice and snow. The extra native .8
reflection gain is removed for the lake. Streams keep their existing separate
adaptation. --legacy-lake-material provides the previous parameter comparison.

Native test_lake_material checks source import values and GPU shallow opacity,
one absorption distance, normal/grazing reflection and clear/snow-covered ice.
The scene was rebuilt with the native renderer to retain instance buffers.

lake-material-comparison.mp4 shows new material left and previous fixed material
right: clear weather, no fog, camera 8,.55,1.9,6.2,.38,-3.4, three-second clocks.
lake-material-source.png is a fresh original-scene capture from the corresponding
close camera; the tool lowers the original orbit minimum to permit that view.
The actual source position is logged by tools/capture_lake_material.mjs. Source
and native motion are not guaranteed frame-identical.

The source still looks greener and its shadows are crisper. Vertex colors match,
so a stale imported palette does not explain that remaining gap. Algae,
submerged sight depth, reflection blend ordering, transparent-water atmosphere
and shadow calibration still require inspection. The lake reflection still
blends inside Godot HDR, while the source blends reflected sky after tone mapping.
These parameter corrections do not establish full material or water parity.

Follow-up: `LAKE-SHADOWS.md` identifies and corrects the missing source lake
shadow-receiving flag, substantially improving the shadowed-water color reported
in this earlier pass. Reflection and compositing order remain separate gaps.
