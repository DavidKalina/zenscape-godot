"""Keep the lake's thin biological film aligned with source lake-algae.js."""
from pathlib import Path
import re
root=Path(__file__).resolve().parents[1]
source=(root.parent/'zenscape/lake-algae.js').read_text()
body=re.search(r'colorGLSL: /\* glsl \*/ `([\s\S]*?)`',source)[1]
for a,b in [('uAlgaeWindDir','zs_wind_direction'),('uAlgaeWind','zs_wind_strength'),('uAlgaeTime','zs_flow_time'),('uAlgaeRichness','lake_algae_richness'),('uAlgaeSeed','lake_algae_seed'),('uAlgaeGrow','zs_water_growth'),('uAlgaeAnchors','lake_algae_anchors'),('uAlgae','lake_algae_amount'),('uIce','zs_ice'),('vCut','cut'),('vWaterD','depth'),('vIceP','world_p'),('vAlgaeLocal','local_p'),('vnNoise','zs_noise'),('diffuseColor.rgb','body'),('diffuseColor.a','alpha')]: body=body.replace(a,b)
(root/'shaders/reference_lake_algae.gdshaderinc').write_text('''// Generated from lake-algae.js by tools/export_lake_algae.py.
uniform float lake_algae_amount = 1.0;
uniform float lake_algae_richness = 0.18;
uniform float lake_algae_seed = 0.0;
uniform vec3 lake_algae_anchors[12];
void zs_lake_algae(inout vec3 body, inout float alpha, vec3 world_p, vec2 local_p, float depth, float cut) {
'''+body+'\n}\n')
