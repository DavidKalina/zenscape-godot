uniform bool desert_enabled = false;
uniform bool desert_has_map = false;
uniform sampler2D desert_geology : filter_linear, repeat_disable;
uniform float desert_band_height = 0.85;
uniform vec4 desert_sand_a : source_color = vec4(0.8784,0.7020,0.4353,1.0);
uniform vec4 desert_sand_b : source_color = vec4(0.8118,0.6157,0.3451,1.0);
uniform vec4 desert_band_a : source_color = vec4(0.6471,0.3137,0.1843,1.0);
uniform vec4 desert_band_b : source_color = vec4(0.5608,0.2471,0.1647,1.0);
uniform vec4 desert_band_c : source_color = vec4(0.7882,0.5294,0.3529,1.0);
uniform vec4 desert_varnish : source_color = vec4(0.4902,0.2275,0.1490,1.0);
uniform vec4 desert_salt : source_color = vec4(0.9059,0.8745,0.7882,1.0);
uniform float inland_snowline = 99.0;
uniform float inland_rock_amount = 0.0;
uniform int rock_treatment = 0;
uniform float rock_detail_strength = 0.65;
float salt_cells(vec2 p) {
	vec2 cell=floor(p), f=fract(p);
	float a=10.0, b=10.0;
	for(int y=-1;y<=1;y++) for(int x=-1;x<=1;x++) {
		vec2 o=vec2(float(x),float(y)), q=cell+o;
		vec2 jitter=fract(sin(vec2(dot(q,vec2(127.1,311.7)),dot(q,vec2(269.5,183.3))))*43758.5453);
		float d=length(o+jitter*0.7+0.15-f);
		if(d<a){b=a;a=d;} else {b=min(b,d);}
	}
	return b-a;
}

vec3 terrain_geology(vec3 tint, vec3 geology_position, vec3 face_normal) {
	float rock_height = smoothstep(3.5,6.5,geology_position.y)*inland_rock_amount;
	float grain = zs_noise(geology_position.xz*0.55);
	tint = mix(tint,vec3(0.24,0.265,0.29)*zs_palette_rock*(0.82+0.3*grain),rock_height);
	if (desert_enabled) {
		vec2 geology = desert_has_map ? texture(desert_geology,(geology_position.xz+zs_plate_half)/(zs_plate_half*2.0)).rg : vec2(rock_height,0.0);
		rock_height = geology.r;
		vec3 sand = mix(desert_sand_b.rgb,desert_sand_a.rgb,smoothstep(0.35,0.65,grain));
		float band = mod(floor((geology_position.y-0.8)/desert_band_height),3.0);
		vec3 stone = band<1.0 ? desert_band_a.rgb : band<2.0 ? desert_band_b.rgb : desert_band_c.rgb;
		stone = mix(stone,desert_varnish.rgb,smoothstep(0.78,0.90,abs(face_normal.y))*smoothstep(3.8,4.2,geology_position.y));
		tint = mix(sand,stone,geology.r);
		tint = mix(tint,desert_salt.rgb,smoothstep(0.08,0.9,geology.g));
		float cracks = 1.0-smoothstep(0.012,0.052+fwidth(geology_position.x)*0.1,salt_cells(geology_position.xz*2.8));
		tint *= 1.0-cracks*0.20*smoothstep(0.35,0.85,geology.g);
		tint *= 0.97+0.06*zs_noise(geology_position.xz*32.0);
	}
	// Broad world-space strata keep their scale across facets and camera distance.
	if (rock_treatment > 0) {
		vec3 p = geology_position;
		float exposed = max(rock_height, smoothstep(0.35,0.75,1.0-abs(face_normal.y))) * (1.0-smoothstep(0.62,0.9,abs(face_normal.y)));
		float fold = (zs_noise(p.xz*0.14)-0.5)*1.0;
		float bed = p.y*1.65+p.x*0.16+p.z*0.08+fold+(zs_noise(vec2(p.y*0.36,p.z*0.12))-0.5)*0.8;
		float wave = sin(bed*6.283185);
		float seam = 1.0-smoothstep(0.035,0.13+fwidth(bed),abs(fract(bed)-0.5));
		float broad = sin(bed*1.55+0.8);
		vec3 strata = tint*(1.0+0.035*wave+0.055*broad-0.12*seam);
		strata *= mix(vec3(1.0),vec3(1.06,1.015,0.94),smoothstep(0.2,0.8,broad));
		tint = mix(tint,strata,exposed*rock_detail_strength*(0.35+0.65*zs_noise(vec2(p.y*0.23,p.x*0.3+p.z*0.16))));
		if (rock_treatment == 2) {
			float streak = zs_noise(vec2(p.x*2.0+p.z*1.2,p.y*0.13));
			float broken = zs_noise(p.xz*0.65+vec2(p.y*0.08,0.0));
			float stain = smoothstep(0.48,0.75,streak)*smoothstep(0.3,0.7,broken);
			float damp = (1.0-smoothstep(5.0,11.0,p.y))*smoothstep(0.45,0.72,broken);
			vec3 weathered = tint*(1.0-0.26*stain);
			weathered = mix(weathered,weathered*vec3(0.72,0.86,0.65),damp*0.45);
			tint = mix(tint,weathered,exposed*rock_detail_strength);
		}
	}
	return tint;
}
