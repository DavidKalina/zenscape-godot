// Extract the original strength function without importing weather's renderer.
import {readFileSync,writeFileSync} from 'node:fs';
const source=readFileSync(new URL('../../zenscape/weather.js',import.meta.url),'utf8');
const body=source.match(/export function gustAt\(t\) \{([\s\S]*?)\n\}/)?.[1];
if(!body)throw Error('Missing source gustAt');
const gustAt=new Function('t',body);
const samples=[0,.25,1,3,6,12,30,100].map(t=>({t,value:gustAt(t)}));
writeFileSync(new URL('../assets/zen_reference/wind-checks.json',import.meta.url),JSON.stringify(samples,null,2));
