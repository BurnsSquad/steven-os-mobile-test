// Offline parser check only: never executes application code or contacts Supabase.
import {readFileSync, readdirSync} from 'node:fs';
import {createHash} from 'node:crypto';
import vm from 'node:vm';
const expected='aecb177cdebe6eded90f5e5b9626e152fd677066b923e8b988ece2b83c6683f8';
const hash=createHash('sha256').update(readFileSync('index.html')).digest('hex');
if(hash!==expected) throw Error('Stable index.html integrity mismatch; stop.');
console.log('PASS stable index SHA-256 '+hash);
let total=0;
for(const file of readdirSync('.').filter(f=>f.endsWith('.html')).sort()) {
 let count=0;
 for(const match of readFileSync(file,'utf8').matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script\s*>/gi)) {
  if(/\bsrc\s*=/i.test(match[1]) || /\btype\s*=\s*["'](?:application\/ld\+json|application\/json)["']/i.test(match[1])) continue;
  new vm.Script(match[2],{filename:file+':inline-'+(++count)});
 }
 total+=count; console.log('PASS syntax '+file+' ('+count+' inline scripts)');
}
console.log('Parsed '+total+' scripts. No browser, authentication, network, or RLS tests executed.');
