const fields={behavior:'도전적 행동 변화',currentStatus:'종합 현황',majorChanges:'강점과 주요 변화',therapistOpinion:'치료사 종합 소견',homePractice:'가정에서 함께 하기',nextGoals:'다음 목표'};
const params=new URLSearchParams(location.hash.slice(1));
// Remove the secret fragment from this browser history entry immediately.
history.replaceState(null,'',location.pathname);
const id=params.get('id'), capability=params.get('cap'), rawKey=params.get('key');
params.delete('key');params.delete('cap');
const status=document.querySelector('#status'), form=document.querySelector('#editor'), save=document.querySelector('#save');
const extend=document.querySelector('#extend'), expiry=document.querySelector('#expiry'), prompt=document.querySelector('#expiryPrompt');
const decode=s=>Uint8Array.from(atob(s),c=>c.charCodeAt(0));
const encode=b=>{let s='';for(const byte of new Uint8Array(b))s+=String.fromCharCode(byte);return btoa(s);};
let key, revision=0, expiresAt=0, clockOffset=0, promptedExpiry=0, dirty=false, active=false;
function syncClock(result){
 expiresAt=result.expiresAt;
 if(Number.isFinite(result.serverTime))clockOffset=result.serverTime-Date.now();
 updateCountdown();
}
function updateCountdown(){
 if(!expiresAt)return;
 const remaining=Math.max(0,expiresAt-(Date.now()+clockOffset));
 const seconds=Math.ceil(remaining/1000),hours=Math.floor(seconds/3600),minutes=Math.floor(seconds%3600/60);
 expiry.textContent=`남은 시간 ${String(hours).padStart(2,'0')}:${String(minutes).padStart(2,'0')}:${String(seconds%60).padStart(2,'0')} · 만료 ${new Date(expiresAt).toLocaleTimeString('ko-KR')}`;
 if(remaining<=0){
  active=false;save.disabled=true;extend.disabled=true;
  if(prompt.open)prompt.close();
  status.textContent='편집 시간이 만료됐습니다. 저장하지 않은 내용은 내 기기에 임시본으로 보관하고 앱에서 새 링크를 만드세요.';
 }else if(active&&remaining<=5*60000&&promptedExpiry!==expiresAt){
  promptedExpiry=expiresAt;
  if(!prompt.open)prompt.showModal();
 }
}
setInterval(updateCountdown,1000);
function values(){return Object.fromEntries(Object.keys(fields).map(k=>[k,document.getElementById(k).value]));}
function validate(v){if(!v||Object.keys(v).sort().join(',')!==Object.keys(fields).sort().join(',')||Object.values(v).some(x=>typeof x!=='string'||x.length>12000))throw Error('보고서 형식을 확인할 수 없습니다.');return v;}
async function api(method,body){
 const r=await fetch(`/report/edit-sessions/${id}`,{method,headers:{'X-ABA-Edit-Capability':capability,'Content-Type':'application/json'},body:body?JSON.stringify(body):undefined,cache:'no-store',credentials:'omit',redirect:'error',signal:AbortSignal.timeout(90000)});
 if(!r.ok){
  const error=await r.json().catch(()=>({}));
  throw Error(error.error==='extension_unavailable'?'계정 만료 시각을 넘어 연장할 수 없습니다. 만료 전에 저장하세요.':r.status===409?'다른 창에서 먼저 저장했습니다. 현재 내용을 임시본으로 보관한 뒤 앱에서 새 링크를 만드세요.':r.status===429?'요청이 많습니다. 잠시 후 다시 시도하세요.':'편집 링크가 만료되었거나 연결할 수 없습니다. 현재 내용을 임시본으로 보관하고 앱에서 다시 시작하세요.');
 }
 return r.json();
}
async function start(){
 if(!/^[a-f0-9]{32}$/.test(id??'')||!/^[a-f0-9]{64}$/.test(capability??'')||!rawKey)return;
 try{
  key=await crypto.subtle.importKey('raw',decode(rawKey),{name:'AES-GCM'},false,['encrypt','decrypt']);
  status.textContent='보고서를 여는 중…';
  const result=await api('GET');
  const combined=decode(result.ciphertext);
  const plain=await crypto.subtle.decrypt({name:'AES-GCM',iv:combined.slice(0,12)},key,combined.slice(12));
  const report=validate(JSON.parse(new TextDecoder().decode(plain)));
  revision=result.revision;
  for(const [name,label] of Object.entries(fields)){
   const title=document.createElement('label');title.htmlFor=name;title.textContent=label;
   const input=document.createElement('textarea');input.id=name;input.name=name;input.maxLength=12000;input.value=report[name];input.spellcheck=false;input.autocomplete='off';
   input.addEventListener('input',()=>{dirty=true;status.textContent='수정 중 · 아직 서버에 저장하지 않았습니다.';});
   document.querySelector('#fields').append(title,input);
  }
  active=true;form.hidden=false;status.textContent='서술 항목만 편집할 수 있습니다.';
  syncClock(result);
 }catch(e){status.textContent=e.message;}
}
async function saveDraft(){
 if(!active)return false;save.disabled=true;
 const snapshot=values();
 try{
  validate(snapshot);
  const iv=crypto.getRandomValues(new Uint8Array(12));
  const encrypted=new Uint8Array(await crypto.subtle.encrypt({name:'AES-GCM',iv},key,new TextEncoder().encode(JSON.stringify(snapshot))));
  const combined=new Uint8Array(12+encrypted.length);combined.set(iv);combined.set(encrypted,12);
  const result=await api('PUT',{ciphertext:encode(combined),revision});revision=result.revision;syncClock(result);
  dirty=JSON.stringify(snapshot)!==JSON.stringify(values());
  status.textContent=dirty?'이전 수정본은 저장됐습니다. 추가 변경을 저장하세요.':'서버 저장 완료 · 앱에서 웹 수정본을 검토하고 반영하세요.';
  return true;
 }catch(e){status.textContent=e.message;return false;}finally{save.disabled=!active;}
}
form.addEventListener('submit',async e=>{e.preventDefault();await saveDraft();});
async function extendSession(){
 if(!active)return;extend.disabled=true;document.querySelector('#promptExtend').disabled=true;
 try{
  syncClock(await api('PATCH'));
  if(prompt.open)prompt.close();
  status.textContent='편집 시간이 30분 연장됐습니다.';
 }catch(e){status.textContent=e.message;}
 finally{extend.disabled=!active;document.querySelector('#promptExtend').disabled=!active;}
}
extend.addEventListener('click',extendSession);
document.querySelector('#promptExtend').addEventListener('click',extendSession);
document.querySelector('#promptSave').addEventListener('click',async()=>{
 document.querySelector('#promptSave').disabled=true;
 if(await saveDraft())prompt.close();
 document.querySelector('#promptSave').disabled=false;
});
document.querySelector('#promptDiscard').addEventListener('click',()=>{
 prompt.close();
 status.textContent=dirty?'이번에는 저장하지 않았습니다. 만료 전에는 여전히 저장하거나 임시본을 내려받을 수 있습니다.':'현재 저장하지 않은 변경은 없습니다.';
});
prompt.addEventListener('cancel',e=>e.preventDefault());
document.querySelector('#download').addEventListener('click',()=>{
 const text=Object.entries(values()).map(([k,v])=>fields[k]+'\n'+v).join('\n\n');
 const url=URL.createObjectURL(new Blob([text],{type:'text/plain;charset=utf-8'}));
 const a=document.createElement('a');a.href=url;a.download=`ABA-report-draft-${Date.now()}.txt`;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
 status.textContent='임시본은 이 기기에 평문 파일로 저장됩니다. 사용 후 직접 삭제하세요.';
});
addEventListener('beforeunload',e=>{if(dirty){e.preventDefault();e.returnValue='';}});
start();

