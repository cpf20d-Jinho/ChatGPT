import {test} from 'node:test';
import assert from 'node:assert/strict';
import {once} from 'node:events';
import {randomBytes, webcrypto, createHash} from 'node:crypto';
import {server} from '../Server/server.mjs';

test('encrypted report editing: consent, capability isolation, revisions, expiry and no AI',async()=>{
 let clock=Date.now(), calls=0;
 const token=randomBytes(32).toString('hex');
 const app=server({token,now:()=>clock,fetchImpl:()=>{calls++;throw Error('No provider calls allowed');}});
 app.listen(0,'127.0.0.1');await once(app,'listening');
 const base=`http://127.0.0.1:${app.address().port}`;
 const auth={Authorization:`Bearer ${token}`,'Content-Type':'application/json','X-ABA-Consent':'encrypted-edit-v1'};
 const payload={behavior:'',currentStatus:'가상 데이터 · 40%에서 80%',majorChanges:'변화 관찰',therapistOpinion:'직접 작성',homePractice:'',nextGoals:''};
 const key=await webcrypto.subtle.generateKey({name:'AES-GCM',length:256},true,['encrypt','decrypt']);
 const iv=randomBytes(12);
 const encrypted=await webcrypto.subtle.encrypt({name:'AES-GCM',iv},key,Buffer.from(JSON.stringify(payload)));
 const ciphertext=Buffer.concat([iv,Buffer.from(encrypted)]).toString('base64');
 const create=(headers=auth)=>fetch(base+'/report/edit-sessions',{method:'POST',headers,body:JSON.stringify({ciphertext,revision:0})});
 try{
  assert.equal((await create({})).status,401);
  assert.equal((await create({Authorization:auth.Authorization})).status,428);
  const response=await create();assert.equal(response.status,201);
  const room=await response.json(), path=base+'/report/edit-sessions/'+room.id;
  assert.equal(room.expiresAt-clock,60*60000);
  assert.equal((await fetch(path,{headers:auth})).status,404,'server owner token alone cannot read content');
  assert.equal((await fetch(path,{headers:{'X-ABA-Edit-Capability':'wrong'}})).status,404);
  const headers={'X-ABA-Edit-Capability':room.capability,'Content-Type':'application/json'};
  assert.equal((await fetch(path,{method:'PATCH',headers:{'X-ABA-Edit-Capability':'wrong'}})).status,404);
  const stored=await (await fetch(path,{headers})).json();assert.equal(stored.ciphertext,ciphertext);
  const extended=await (await fetch(path,{method:'PATCH',headers})).json();
  assert.equal(extended.expiresAt-clock,90*60000);
  assert.equal(extended.serverTime,clock);
  assert.ok(!JSON.stringify(stored).includes('가상'));
  assert.equal((await fetch(path,{method:'PUT',headers,body:JSON.stringify({ciphertext,revision:0,childName:'not permitted'})})).status,400);
  const put=()=>fetch(path,{method:'PUT',headers,body:JSON.stringify({ciphertext,revision:0})});
  const concurrent=await Promise.all([put(),put()]);assert.deepEqual(concurrent.map(r=>r.status).sort(),[200,409]);
  const other=await (await create()).json();
  assert.equal((await fetch(base+'/report/edit-sessions/'+other.id,{headers})).status,404);
  assert.equal((await fetch(path,{method:'DELETE',headers})).status,200);
  assert.equal((await fetch(path,{headers})).status,404);
  clock+=61*60000;
  assert.equal((await fetch(base+'/report/edit-sessions/'+other.id,{headers:{'X-ABA-Edit-Capability':other.capability}})).status,404);
  const page=await fetch(base+'/report/editor');assert.equal(page.status,200);
  assert.ok(page.headers.get('content-security-policy').includes("frame-ancestors 'none'"));
  assert.equal(page.headers.get('referrer-policy'),'no-referrer');
  assert.equal(page.headers.get('cache-control'),'no-store');
  assert.equal(calls,0);
 }finally{app.close();app.closeAllConnections();await once(app,'close');}
});

test('bounded room allocation and account expiry apply to edit links',async()=>{
 let clock=Date.now();const token=randomBytes(32).toString('hex');
 const app=server({users:[{digest:createHash('sha256').update(token).digest('hex'),expiresAt:new Date(clock+60000).toISOString()}],now:()=>clock});
 app.listen(0,'127.0.0.1');await once(app,'listening');
 const base=`http://127.0.0.1:${app.address().port}/report/edit-sessions`;
 const headers={Authorization:`Bearer ${token}`,'X-ABA-Consent':'encrypted-edit-v1','Content-Type':'application/json'};
 const body=JSON.stringify({ciphertext:randomBytes(48).toString('base64'),revision:0});
 try {
  const rooms=await Promise.all(Array.from({length:6},()=>fetch(base,{method:'POST',headers,body})));
  assert.equal(rooms.filter(r=>r.status===201).length,3);assert.equal(rooms.filter(r=>r.status===429).length,3);
  const room=await rooms.find(r=>r.status===201).json();
  assert.equal(room.expiresAt-clock,60000,'account expiry caps the initial hour');
  const capped=await fetch(base+'/'+room.id,{method:'PATCH',headers:{'X-ABA-Edit-Capability':room.capability}});
  assert.equal(capped.status,409,'extension cannot pass account expiry');
  clock+=61000;
  assert.equal((await fetch(base+'/'+room.id,{headers:{'X-ABA-Edit-Capability':room.capability}})).status,404);
 }finally{app.close();app.closeAllConnections();await once(app,'close');}
});

