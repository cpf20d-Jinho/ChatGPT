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
const doc={childName:"가상 아동",birthDate:"",start:"2026-01-01",end:"2026-01-31",goals,incompleteCount:0,draft};
const element={innerHTML:""};
const ctx={document:{getElementById:()=>element,querySelectorAll:()=>Array.from(element.innerHTML.matchAll(/class="page/g))}};
vm.createContext(ctx);vm.runInContext(html.match(/<script>([\s\S]*?)<\/script>/)[1],ctx);
ctx.fixture=doc;
const result=vm.runInContext("renderReport(fixture)",ctx);
assert.equal(result.stoCount,22);assert.equal(result.sections,13);
assert(!element.innerHTML.includes('<h2>치료사 종합 소견</h2>'));
assert(!element.innerHTML.includes('<th>생년월일</th>'));
assert(html.includes('.narrative{break-before:auto'));
assert(element.innerHTML.includes('stroke-dasharray="4 3"'));
assert(element.innerHTML.includes('stroke-dasharray="3 3"'),"level transition must use a vertical dotted separator");
assert(element.innerHTML.includes('r="3.6" fill="white"'),"partial-coverage points must be hollow");
doc.childName='<script>alert("x")</script>';vm.runInContext("renderReport(fixture)",ctx);
assert(!element.innerHTML.includes('<script>alert'));doc.childName="가상 아동";
console.log("PASS: 22 STO / 13 graphs / 13 populated sections / escaped text / SVG charts");
if(process.argv.includes("--fixture")){
 const {writeFileSync}=require("node:fs");
 doc.draft.nextGoals="검증끝";
 const stress=JSON.parse(JSON.stringify(doc));
 stress.draft.therapistOpinion=Array.from({length:100},(_,i)=>`${i+1}. 긴 한국어 문단의 페이지 나눔과 누락을 확인하는 합성 데이터입니다.`).join("\n");
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
  const sectionCount=await page.locator(".page").count();
  for(const i of [...new Set([0,1,2,Math.floor(sectionCount/2),sectionCount-1])])
   await page.locator(".page").nth(i).screenshot({path:resolve(root,"template-"+(i+1)+".png")});
  await browser.close();
 })().catch(e=>{console.error(e);process.exitCode=1});
}

