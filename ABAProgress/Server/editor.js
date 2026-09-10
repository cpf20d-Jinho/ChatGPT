const fields={behavior:'도전적 행동 변화',currentStatus:'종합 현황',majorChanges:'강점과 주요 변화',therapistOpinion:'치료사 종합 소견',homePractice:'가정에서 함께 하기',nextGoals:'다음 목표'};
const params=new URLSearchParams(location.hash.slice(1));
// Remove the secret fragment from this browser history entry immediately.
history.replaceState(null,'',location.pathname);
const id=params.get('id'), capability=params.get('cap'), rawKey=params.get('key');
params.delete('key');params.delete('cap');
const status=document.querySelector('#status'), form=document.querySelector('#editor'), save=document.querySelector('#save');
const decode=s=>Uint8Array.from(atob(s),c=>c.charCodeAt(0));
const encode=b=>{let s='';for(const byte of new Uint8Array(b))s+=String.fromCharCode(byte);return btoa(s);};
let key, revision=0, expiresAt=0, dirty=false, active=false;
function values(){return Object.fromEntries(Object.keys(fields).map(k=>[k,document.getElementById(k).value]));}
function validate(v){if(!v||Object.keys(v).sort().join(',')!==Object.keys(fields).sort().join(',')||Object.values(v).some(x=>typeof x!=='string'||x.length>12000))throw Error('보고서 형식을 확인할 수 없습니다.');return v;}
async function api(method,body){
 const r=await fetch(`/report/edit-sessions/${id}`,{method,headers:{'X-ABA-Edit-Capability':capability,'Content-Type':'application/json'},body:body?JSON.stringify(body):undefined,cache:'no-store',credentials:'omit',redirect:'error',signal:AbortSignal.timeout(90000)});
 if(!r.ok)throw Error(r.status===409?'다른 창에서 먼저 저장했습니다. 현재 내용을 임시본으로 보관한 뒤 앱에서 새 링크를 만드세요.':r.status===429?'요청이 많습니다. 잠시 후 저장하세요.':'편집 링크가 만료되었거나 연결할 수 없습니다. 현재 내용을 임시본으로 보관하고 앱에서 다시 시작하세요.');
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
  revision=result.revision;expiresAt=result.expiresAt;
  for(const [name,label] of Object.entries(fields)){
   const title=document.createElement('label');title.htmlFor=name;title.textContent=label;
   const input=document.createElement('textarea');input.id=name;input.name=name;input.maxLength=12000;input.value=report[name];input.spellcheck=false;input.autocomplete='off';
   input.addEventListener('input',()=>{dirty=true;status.textContent='수정 중 · 아직 서버에 저장하지 않았습니다.';});
   document.querySelector('#fields').append(title,input);
  }
  active=true;form.hidden=false;status.textContent='서술 항목만 편집할 수 있습니다.';
  document.querySelector('#expiry').textContent=`만료 ${new Date(expiresAt).toLocaleTimeString('ko-KR')}`;
 }catch(e){status.textContent=e.message;}
}
form.addEventListener('submit',async e=>{
 e.preventDefault();if(!active)return;save.disabled=true;
 const snapshot=values();
 try{
  validate(snapshot);
  const iv=crypto.getRandomValues(new Uint8Array(12));
  const encrypted=new Uint8Array(await crypto.subtle.encrypt({name:'AES-GCM',iv},key,new TextEncoder().encode(JSON.stringify(snapshot))));
  const combined=new Uint8Array(12+encrypted.length);combined.set(iv);combined.set(encrypted,12);
  const result=await api('PUT',{ciphertext:encode(combined),revision});revision=result.revision;
  dirty=JSON.stringify(snapshot)!==JSON.stringify(values());
  status.textContent=dirty?'이전 수정본은 저장됐습니다. 추가 변경을 저장하세요.':'서버 저장 완료 · 앱에서 웹 수정본을 검토하고 반영하세요.';
 }catch(e){status.textContent=e.message;}finally{save.disabled=false;}
});
document.querySelector('#download').addEventListener('click',()=>{
 const text=Object.entries(values()).map(([k,v])=>fields[k]+'\n'+v).join('\n\n');
 const url=URL.createObjectURL(new Blob([text],{type:'text/plain;charset=utf-8'}));
 const a=document.createElement('a');a.href=url;a.download=`ABA-report-draft-${Date.now()}.txt`;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
 status.textContent='임시본은 이 기기에 평문 파일로 저장됩니다. 사용 후 직접 삭제하세요.';
});
addEventListener('beforeunload',e=>{if(dirty){e.preventDefault();e.returnValue='';}});
start();
