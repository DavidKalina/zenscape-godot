import {readFileSync,writeFileSync} from 'node:fs';
const source=readFileSync(new URL('../../zenscape/daynight.js',import.meta.url),'utf8');
// uAlpen is reset earlier in the source; select its elevation-driven assignment.
const alpen=[...source.matchAll(/bus\.paint\.uAlpen\.value = ([^;]+);/g)].at(-1)[1];
const after=[...source.matchAll(/bus\.paint\.uAfterglow\.value = ([^;]+);/g)].at(-1)[1];
const line=source.match(/const line = (smoothstep\(0\.10[^;]+);/)[1];
const calculate=new Function('e','cloud','smoothstep',`const clear=1-Math.min(1,cloud*1.4);return [${alpen},${line},${after}];`);
const smoothstep=(a,b,x)=>{const t=Math.max(0,Math.min(1,(x-a)/(b-a)));return t*t*(3-2*t)};
const samples=[];for(const e of [.3,.08,.03,-.02,-.08,-.16])for(const cloud of [0,.3,1])samples.push({e,cloud,value:calculate(e,cloud,smoothstep)});
writeFileSync(new URL('../assets/zen_reference/alpenglow-checks.json',import.meta.url),JSON.stringify(samples,null,2));
