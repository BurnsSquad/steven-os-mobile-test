// Pure fictional demo tests; never connect to Supabase or represent server RLS proof.
import test from 'node:test';import assert from 'node:assert/strict';
import {seed,createItem,renameItem,assignItem,completeItem,isComplete,canEdit,canComplete} from '../preview/planner-demo/model.mjs';
test('Task creation is adult-only; child Activities cannot assign siblings',()=>{
 assert.equal(createItem('adult',{type:'task',title:'Fictional chore',mode:'individual',assignees:['river']},'new').type,'task');
 assert.throws(()=>createItem('river',{type:'task',title:'No',mode:'individual',assignees:['river']},'new'));
 assert.throws(()=>createItem('river',{type:'activity',title:'No',mode:'individual',assignees:['sky']},'new'));
 assert.throws(()=>createItem('river',{type:'activity',title:'No',mode:'household',assignees:['river','sky']},'new'));
 const own=createItem('river',{type:'activity',title:'Fictional drawing',mode:'individual',assignees:['river']},'new');assert.equal(own.owner,'river');assert.equal(canEdit('sky',own),false);assert.equal(renameItem('river',own,'Fictional map').title,'Fictional map');
 assert.throws(()=>assignItem('river',own,'individual',['sky']));
});
test('Visible individual assignments cannot be completed or edited by sibling',()=>{
 const task=seed()[0];assert.equal(canEdit('river',task),false);assert.equal(canComplete('sky',task),false);assert.throws(()=>completeItem('sky',task,'river'));assert.equal(isComplete(completeItem('river',task)),true);
 const admin=completeItem('adult',task,'river','2026-01-01T00:00:00Z');assert.equal(admin.completions[0].actor,'adult');assert.equal(admin.completions[0].member,'river');
});
test('Household completion is once, retains first actor and rejects repeat transition',()=>{
 const task=seed()[1],done=completeItem('sky',task,'sky','2026-01-01T00:00:00Z');assert.equal(isComplete(done),true);assert.throws(()=>completeItem('river',done));assert.equal(done.completions.length,1);assert.equal(done.completions[0].actor,'sky');assert.equal(task.completions.length,0);
});
test('Shared item requires every contribution and prevents child impersonation',()=>{
 const task=seed()[2];assert.throws(()=>completeItem('river',task,'sky'));const first=completeItem('river',task);assert.equal(isComplete(first),false);assert.equal(canComplete('river',first),false);const both=completeItem('sky',first);assert.equal(isComplete(both),true);assert.equal(both.completions.length,2);assert.throws(()=>assignItem('adult',first,'individual',['sky']));
});
test('Admin can assign an Activity; ownership does not grant another contribution',()=>{
 const activity=assignItem('adult',seed()[3],'shared',['river','sky']);assert.equal(canEdit('river',activity),true);assert.throws(()=>completeItem('river',activity,'sky'));assert.equal(isComplete(completeItem('sky',completeItem('river',activity))),true);
});
