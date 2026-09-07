// Expose source procedural strand data in a temporary browser module; source files stay unchanged.
import {readFileSync,writeFileSync} from 'node:fs';
import {openBrowser} from './capture_browser.mjs';
const saved=JSON.parse(readFileSync(new URL('../assets/zen_reference/scene.json',import.meta.url)));
const {open,evalJs}=await openBrowser('godot-water-growth',{flags:['--use-angle=metal','--ignore-gpu-blocklist']});
await open(saved.query);
const data=await evalJs(`(async()=>{
 const built=Object.values(__dbg.built).find(b=>b?.world && b?.water);
 if(!built) throw Error('No live source world');
 let code=await (await fetch('/waterfall.js')).text();
 const needle='return { mesh, tick, centers, halfW, rooms, steep, aer, ledges, impact, tau };';
 if(!code.includes(needle)) throw Error('Strand export seam changed');
 code=code.replace(needle,'return { mesh, tick, centers, halfW, rooms, steep, aer, ledges, impact, tau, axA, axB, thick, vertRing, vertAng, faceSect, sectWhite, bodyWhite, seed };');
 code=code.replace(/from\\s*(['"])([^'"]+)\\1/g,(_,q,path)=>'from '+q+new URL(path,location.origin+'/waterfall.js').href+q);
 const url=URL.createObjectURL(new Blob([code],{type:'text/javascript'}));
 const mod=await import(url);
 const water=mod.buildWater({world:built.world});
 const out={strands:water.strands.map(s=>({centers:s.centers.map(v=>v.toArray()),axA:s.axA.map(v=>v.toArray()),axB:s.axB.map(v=>v.toArray()),halfW:Array.from(s.halfW),thick:Array.from(s.thick),steep:Array.from(s.steep),aer:Array.from(s.aer),tau:Array.from(s.tau),vertRing:Array.from(s.vertRing),vertAng:Array.from(s.vertAng),sectWhite:Array.from(s.sectWhite),bodyWhite:s.bodyWhite,seed:s.seed,impact:s.impact.toArray()})),streams:[],lakes:[]};
 water.group.traverse(o=>{if(!o.isMesh)return;
  const a=o.geometry.attributes;
  if(a.aT&&a.aCenter){const attrs={};for(const k of ['position','aT','aCenter','aRun','aS','aU'])attrs[k]={size:a[k].itemSize,array:Array.from(a[k].array)};out.streams.push(attrs);}
  if(a.aDepth && !a.aT)out.lakes.push({position:Array.from(a.position.array),level:o.position.y,node:o});
 });
 water.grow(0);
 for(const lake of out.lakes){lake.bed=lake.node.position.y;delete lake.node;}
 for(const s of water.strands){s.tick(1.25,0.47,0,null);}
 out.checks=water.strands.map(s=>Array.from(s.mesh.geometry.attributes.position.array));
 URL.revokeObjectURL(url);
 return out;
})()`);
for(const stream of data.streams){
 const m=saved.meshes.find(m=>m.attrs.aDepth&&!m.material.water);
 const pos=m.attrs.position.array;
 if(pos.length!==stream.position.array.length||pos.some((v,i)=>Math.abs(v-stream.position.array[i])>1e-5))throw Error('Stream geometry changed');
 stream.name=m.name;delete stream.position;
}
for(const lake of data.lakes){
 const m=saved.meshes.find(m=>m.material.water&&m.attrs.position.array.length===lake.position.length);
 if(!m||m.attrs.position.array.some((v,i)=>Math.abs(v-lake.position[i])>1e-5))throw Error('Lake geometry changed');
 lake.name=m.name;delete lake.position;
}
writeFileSync(new URL('../assets/zen_reference/water-growth.json',import.meta.url),JSON.stringify(data));
console.log('Exported',data.strands.length,'strands,',data.streams.length,'streams,',data.lakes);
process.exit(0);
