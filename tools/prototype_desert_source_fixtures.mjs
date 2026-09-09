// Generate fixtures directly from the sibling Electron source; no copied expected formulas.
import {writeFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {pathToFileURL} from 'node:url';
const source = resolve(process.argv[2]);
const load = name => import(pathToFileURL(resolve(source,name)).href);
const {makeNoise} = await load('world.js');
const {makeDesertHeight} = await load('desert.js');
const {makeDesertSaltBasin} = await load('desert-salt-basin.js');
const {makeDesertMonuments} = await load('desert-monuments.js');
const {makeDesertMountains} = await load('desert-mountains.js');
const samples=[];
for(const seed of [7,91,1234])for(const kind of ['desert','dunes','tablelands','buttes','salt-basin','monuments','desert-mountains']){
 const regional=['salt-basin','monuments','desert-mountains'].includes(kind);
 const r=kind==='salt-basin'?makeDesertSaltBasin(seed):kind==='monuments'?makeDesertMonuments(seed):kind==='desert-mountains'?makeDesertMountains(seed):null;
 const height=r?.heightAt ?? makeDesertHeight({fbm:makeNoise(seed===7?97.13:seed*.137+97.13).fbm,terrain:{kind:kind==='desert'?'original':kind}});
 for(let x=-10;x<=10;x+=2)for(let z=-10;z<=10;z+=2){const X=regional?x*3:x,Z=regional?z*3:z;samples.push({seed,kind,x,z,height:regional?.8+height(X,Z)*.65:height(X,Z),salt:r?.saltAt?.(X,Z)??0});}
}
writeFileSync(process.argv[3],JSON.stringify(samples));console.log(samples.length+' original terrain samples');
