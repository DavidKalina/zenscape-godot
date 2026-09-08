shader_type canvas_item;
void fragment() {
 vec2 size = vec2(880.,540.);
 vec2 q = abs((UV-.5)*size)-(size*.5-26.);
 float d = length(max(q,0.))+min(max(q.x,q.y),0.)-26.;
 vec3 plum = mix(vec3(56.,41.,52.),vec3(34.,26.,29.),clamp(UV.y*.8+UV.x*.2,0.,1.))/255.;
 float edge = 1.-smoothstep(-1.5,-.5,d);
 COLOR=vec4(mix(vec3(.85,.70,.44),plum,edge),.95*(1.-smoothstep(-.5,.5,d)));
}
