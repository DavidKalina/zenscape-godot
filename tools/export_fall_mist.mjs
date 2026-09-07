import {readFileSync,writeFileSync} from 'node:fs';
import {openBrowser} from './capture_browser.mjs';
const saved=JSON.parse(readFileSync(new URL('../assets/zen_reference/scene.json',import.meta.url)));
const {open,evalJs}=await openBrowser('godot-fall-mist',{flags:['--use-angle=metal','--ignore-gpu-blocklist']});
await open(saved.query);
const data=await evalJs(String.raw`(()=>{const found=[];__dbg.scene.traverse(o=>{const a=o.geometry?.attributes;if(!a?.aVel||!a.aPhase||!a.aSize||!o.material.vertexShader.includes('uGrowFall'))return;const rise=o.material.vertexShader.match(/\* ([0-9.]+) \* \(1.0 \+ 0.35 \* gale\)/);if(!rise)throw Error('Source mist rise coefficient missing');found.push({positions:Array.from(a.position.array),velocity:Array.from(a.aVel.array),phase:Array.from(a.aPhase.array),size:Array.from(a.aSize.array),matrix:o.matrixWorld.toArray(),rise:Number(rise[1])});});if(found.length!==1)throw Error('Expected one imported fall mist cloud');return found[0];})()`);
writeFileSync(new URL('../assets/zen_reference/fall-mist.json',import.meta.url),JSON.stringify(data));
console.log('Exported',data.phase.length,'source mist particles, rise',data.rise);process.exit(0);
