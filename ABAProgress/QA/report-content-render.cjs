// Synthetic content regression: no page-count target, no patient data.
const {readFileSync,mkdirSync}=require('node:fs');
const {resolve}=require('node:path');
const {execFileSync}=require('node:child_process');
const assert=require('node:assert/strict');
const {chromium}=require('playwright');
(async()=>{
 const out=process.env.REPORT_QA_OUTPUT;
 if(!out)throw Error('Set REPORT_QA_OUTPUT to a scratch directory');
 mkdirSync(out,{recursive:true});
 const fixture=resolve(out,'fixtures.json');
 execFileSync(process.execPath,[resolve(__dirname,'report-template.test.cjs'),'--fixture',fixture]);
 const docs=JSON.parse(readFileSync(fixture));
 docs[1].goals[0].learning['1']=Array.from({length:100},(_,i)=>`과제 ${i+1}: 긴 과제 목록의 페이지 흐름 검증`).join('\n')+'\n과제목록끝';
 const browser=await chromium.launch({headless:true,executablePath:process.env.REPORT_QA_CHROME||undefined});
 try {
  const page=await browser.newPage({viewport:{width:794,height:1123}});
  const html=readFileSync(resolve(__dirname,'../XcodeProject/ABAProgress/Resources/ReportTemplate.html'),'utf8');
  for(const [i,doc] of docs.entries()){
   await page.setContent(html);
   await page.evaluate(doc=>renderReport(doc),doc);
   await page.evaluate(()=>document.fonts.ready);
   assert.equal(await page.locator('.report-section').count(),4);
   assert.equal(await page.locator('.performance-record').count(),doc.goals.length);
   assert(await page.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth),'Horizontal clipping');
   await page.emulateMedia({media:'print'});
   await page.pdf({path:resolve(out,`content-${i}.pdf`),format:'A4',printBackground:true,margin:{top:'18mm',bottom:'18mm',left:'14mm',right:'14mm'}});
   await page.emulateMedia({media:'screen'});
   if(i===0){
    await page.screenshot({path:resolve(out,'content-first.png')});
    await page.locator('.performance-record').first().screenshot({path:resolve(out,'content-record.png')});
    await page.locator('.report-section').nth(2).screenshot({path:resolve(out,'content-interpretation.png')});
   }
  }
 } finally {await browser.close();}
 console.log('PASS: multiple programs and long narratives/tasks rendered; inspect generated PDFs for pagination.');
})().catch(e=>{console.error(e);process.exitCode=1});
