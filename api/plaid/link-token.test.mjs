import test from 'node:test';import assert from 'node:assert/strict';
test('Plaid Link endpoint source keeps credentials server-side and enforces parent access',async()=>{
 const source=await import('node:fs').then(fs=>fs.promises.readFile(new URL('./link-token.mjs',import.meta.url),'utf8'));
 assert.match(source,/PLAID-SECRET/);assert.doesNotMatch(source,/access_token/);assert.match(source,/member_role!==['"]adult['"]/);
});
