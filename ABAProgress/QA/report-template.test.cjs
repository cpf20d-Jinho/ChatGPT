const {readFileSync}=require("node:fs");
const {resolve}=require("node:path");
const assert=require("node:assert/strict");
const vm=require("node:vm");
const html=readFileSync(resolve(__dirname,"../XcodeProject/ABAProgress/Resources/ReportTemplate.html"),"utf8");
const counts=[1,1,1,2,3,2,1,1,2,2,2,2,2];
const goals=counts.map((n,i)=>({
 id:"fixture-"+i,name:"가상 학습 목표 "+(i+1),domain:["모방","청자","학습능력","신체 발달"][i%4],group:i<10?"ELCAR 평가":"기타 목표",
 points:Array.from({length:n*4},(_,j)=>({date:"2026-01-"+String(j+1).padStart(2,"0"),value:20+(j%4)*20,level:Math.floor(j/4)+1,recordedCount:j===1?1:2,applicableCount:2})),
 learning:Object.fromEntries(Array.from({length:n},(_,j)=>[String(j+1),"가상 학습 내용입니다. 실제 아동 기록이 아닙니다."])),
 criteria:Object.fromEntries(Array.from({length:n},(_,j)=>[String(j+1),80])),masteredLevels:[],binary:false
}));
const draft={institution:"가상 ABA 연구소",therapist:"가상 치료사",director:"",directorCredential:"",className:"개별 ABA",schedule:"주 2회",duration:"50분",programFamily:"ELCAR, 기타",copyright:"테스트용 가상 자료",signedDate:"",
 behavior:"직접 작성 영역",currentStatus:"가상 데이터로 생성한 템플릿 검증 문단입니다.\n\n미측정 결과를 추측하지 않습니다.",majorChanges:"이번 기간의 강점은 다음과 같습니다.\n\n▸ 동일 단계의 변화\n수치에 근거하여 작성합니다.",
 therapistOpinion:"",homePractice:"",nextGoals:"",groupByProgram:{},confirmedObservations:"",reviewedFingerprint:""};
draft.supportNeeds="지원이 필요한 부분 검증";
draft.totalSessions="6회";
draft.notesByProgram=Object.fromEntries(goals.map(g=>[g.id,"개별 노트 "+g.id]));
goals[0].objective="프로그램 이름과 다른 실제 치료 목표";
const doc={childName:"가상 아동",birthDate:"2020-02-01",start:"2026-01-01",end:"2026-01-31",goals,incompleteCount:0,draft};
const element={innerHTML:""};
const ctx={document:{getElementById:()=>element,querySelectorAll:()=>Array.from(element.innerHTML.matchAll(/class="page/g))}};
vm.createContext(ctx);vm.runInContext(html.match(/<script>([\s\S]*?)<\/script>/)[1],ctx);
ctx.fixture=doc;
const result=vm.runInContext("renderReport(fixture)",ctx);
assert.equal(result.stoCount,22);assert.equal(result.sections,4);
const headings=['1. 개요','2. 진행 과제 및 수행 기록','3. 결과 해석','4. 향후 목표 및 치료 계획'];
let previous=-1;
for(const title of headings){const index=element.innerHTML.indexOf('<h2>'+title+'</h2>');assert(index>previous);previous=index;}
assert.equal((element.innerHTML.match(/class="performance-record"/g)||[]).length,13);
for(const goal of goals){
 const record=element.innerHTML.split('data-goal-id="'+goal.id+'"')[1].split('</article>')[0];
 for(const label of ['영역','목표','진행 과제 (List)','<svg','세션 노트 및 가정 연계 사항','개별 노트 '+goal.id])assert(record.includes(label));
}
assert(element.innerHTML.includes(goals[0].objective));
assert(element.innerHTML.includes('5세 11개월'));
assert(element.innerHTML.includes('총 회기: 6회'));
assert(element.innerHTML.includes(draft.supportNeeds));
assert(!element.innerHTML.includes('중간 보고서'));
assert(!element.innerHTML.includes('확인 및 서명'));
assert(!html.includes('break-before:page'),'Page count must follow content, never a fixed template');
assert(element.innerHTML.includes('stroke-dasharray="4 3"'));
assert(element.innerHTML.includes('stroke-dasharray="3 3"'),"level transition must use a vertical dotted separator");
assert(element.innerHTML.includes('r="3.6" fill="white"'),"partial-coverage points must be hollow");
doc.childName='<script>alert("x")</script>';vm.runInContext("renderReport(fixture)",ctx);
assert(!element.innerHTML.includes('<script>alert'));doc.childName="가상 아동";
draft.notesByProgram[goals[0].id]='<img src=x onerror=alert(1)>';
vm.runInContext("renderReport(fixture)",ctx);assert(!element.innerHTML.includes('<img src=x'));
draft.notesByProgram[goals[0].id]='개별 노트 '+goals[0].id;
const sparse={...doc,goals:[],birthDate:'',draft:{}};
ctx.sparse=sparse;vm.runInContext('renderReport(sparse)',ctx);
assert(element.innerHTML.includes('총 회기: 미입력'));
assert(element.innerHTML.includes('유효한 완료 기록이 없습니다'));
assert(!element.innerHTML.includes('NaN')&&!element.innerHTML.includes('undefined'));
// Same date/irregular gaps have categorical spacing and different levels stay separate.
ctx.points=[{date:'2026-01-01',value:20,level:1},{date:'2026-01-20',value:40,level:1},{date:'2026-01-31',value:80,level:2}];
const graph=vm.runInContext('chart(points,{1:80,2:80})',ctx);
assert(graph.includes('cx="44"')&&graph.includes('cx="343"')&&graph.includes('cx="642"'));
assert(graph.includes('d="M642 '),'New level must start a new SVG path');
console.log("PASS: four content sections / 13 linked records / 22 levels / missing fields / age / escaped notes / categorical charts");
if(process.argv.includes("--fixture")){
 const {writeFileSync}=require("node:fs");
 doc.draft.nextGoals="검증끝";
 const stress=JSON.parse(JSON.stringify(doc));
 stress.draft.therapistOpinion=Array.from({length:100},(_,i)=>`${i+1}. 긴 한국어 문단의 페이지 나눔과 누락을 확인하는 합성 데이터입니다.`).join("\n");
 stress.draft.notesByProgram[goals[0].id]=Array.from({length:80},(_,i)=>`노트 ${i+1}: 프로그램별 긴 서술도 잘리지 않아야 합니다.`).join('\n')+'\n개별노트끝';
 stress.draft.nextGoals="검증끝";
 writeFileSync(process.argv[process.argv.indexOf("--fixture")+1],JSON.stringify([doc,stress]));
}
if(process.argv.includes("--render")){
 (async()=>{
  const {chromium}=require("playwright");
  const browser=await chromium.launch({headless:true,executablePath:process.env.REPORT_QA_CHROME||undefined,args:["--no-sandbox"]});
  const page=await browser.newPage({viewport:{width:794,height:1123},deviceScaleFactor:1});
  await page.setContent(html);await page.evaluate(doc=>renderReport(doc),doc);
  const root=process.env.REPORT_QA_OUTPUT;
  if(!root)throw Error("Set REPORT_QA_OUTPUT to scratch directory");
  const sectionCount=await page.locator(".report-section").count();
  for(const i of [...new Set([0,1,2,Math.floor(sectionCount/2),sectionCount-1])])
   await page.locator(".report-section").nth(i).screenshot({path:resolve(root,"template-"+(i+1)+".png")});
  await browser.close();
 })().catch(e=>{console.error(e);process.exitCode=1});
}

