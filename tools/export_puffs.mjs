import {puff,retirePuffs,puffField,gustSpeed} from '../../zenscape/wind.js';
import {writeFileSync} from 'node:fs';
const wind={strength:.4,uWindDir:{value:{x:1,y:0}},uGustT:{value:0}};
const operations=[{puff:[0,0,.45]},{advance:.5},{puff:[0,0,.45]},{advance:1},{puff:[2,3,.6]},...Array.from({length:7},(_,i)=>[{advance:1.3},{puff:[i,-i,.45]}]).flat(),{advance:13},{advance:24}];
const samples=[];
for(const op of operations){if(op.puff)puff(wind,...op.puff);else {wind.uGustT.value+=gustSpeed(wind.strength)*op.advance;retirePuffs(wind);}samples.push({op,travel:wind.uGustT.value,parcels:wind.uZsPuff.value.map(p=>p.toArray()),field:[[-4,0],[0,0],[8,3],[20,-2]].map(([x,z])=>puffField(x,z,1,0,wind.uGustT.value,wind.uZsPuff.value))});}
writeFileSync(new URL('../assets/zen_reference/puff-checks.json',import.meta.url),JSON.stringify(samples,null,2));
