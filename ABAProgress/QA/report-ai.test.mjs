import test from "node:test";
import assert from "node:assert/strict";
import {validatePayload,requestBody,parseResponse,server} from "../Server/server.mjs";
const fixture=()=>({version:1,series:[[20,60]]});
const prose={currentStatus:"계열 1 최근 평균 40",majorChanges:"비교 구간이 겹칩니다.",warnings:[]};
const completion=(content=prose)=>({candidates:[{finishReason:"STOP",content:{parts:[{text:JSON.stringify(content)}]}}]});
test("numeric summary without raw series",()=>{const out=validatePayload(fixture());assert.equal(out.series[0].recentMean,40);assert.equal(out.series[0].count,2);assert.equal(out.series[0].overlappingWindows,true);assert.equal(out.series[0].values,undefined);});
test("reject every extra field and string including identity and instructions",()=>{for(const key of ["childName","date","notes","domain","confirmedObservations"]){assert.throws(()=>validatePayload({...fixture(),[key]:"SECRET"}));}for(const value of ["20",null,101,-1,NaN])assert.throws(()=>validatePayload({version:1,series:[[value]]}));});
test("window arithmetic and sample limits",()=>{const s=validatePayload({version:1,series:[[10,20,30,60,70,80]]}).series[0];assert.equal(s.changePercentagePoints,50);assert.equal(s.overlappingWindows,false);assert.throws(()=>validatePayload({version:1,series:[]}));assert.throws(()=>validatePayload({version:1,series:[Array(2001).fill(1)]}));});
test("Gemini JSON schema and no stored request",()=>{const r=requestBody(fixture());assert.equal(r.store,false);assert.equal(r.generationConfig.responseMimeType,"application/json");assert.deepEqual(r.generationConfig.responseJsonSchema.required,["currentStatus","majorChanges","warnings"]);assert.ok(!r.contents[0].parts[0].text.includes('values'));});
test("blocked or truncated output rejected",()=>{for(const reason of ["MAX_TOKENS","SAFETY",null]){const r=completion();r.candidates[0].finishReason=reason;assert.throws(()=>parseResponse(r));}assert.throws(()=>parseResponse({...completion(),promptFeedback:{blockReason:"SAFETY"}}));});
test("only designated fields and no blank output",()=>{assert.deepEqual(parseResponse(completion()),prose);assert.throws(()=>parseResponse(completion({...prose,diagnosis:"unexpected"})));assert.throws(()=>parseResponse(completion({...prose,currentStatus:" "})));});
test("server requires secrets",()=>assert.throws(()=>server({apiKey:"",token:""})));

async function withServer(fetchImpl,run){
 const service=server({apiKey:"synthetic-key",token:"t".repeat(32),fetchImpl});
 await new Promise(resolve=>service.listen(0,"127.0.0.1",resolve));
 const url=`http://127.0.0.1:${service.address().port}/report/narrative`;
 const send=(body=fixture(),auth="Bearer "+"t".repeat(32))=>fetch(url,{method:"POST",headers:{Authorization:auth},body:JSON.stringify(body)});
 try{await run(send);}finally{service.closeAllConnections();await new Promise(resolve=>service.close(resolve));}
}
test("HTTP success uses Google once with numeric summaries",async()=>{
 let calls=0;
 await withServer(async(url,options)=>{calls++;assert.equal(url,"https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent");assert.equal(options.headers["x-goog-api-key"],"synthetic-key");assert.ok(!options.body.includes("NOT_TO_SEND"));return Response.json(completion());},async send=>{const r=await send(fixture());assert.equal(r.status,200);assert.equal(r.headers.get("cache-control"),"no-store");assert.deepEqual(await r.json(),prose);});
 assert.equal(calls,1);
});
test("unauthorized, invalid and oversized input never reaches provider",async()=>{
 await withServer(async()=>{assert.fail("Unexpected provider call");},async send=>{
  assert.equal((await send(fixture(),"wrong")).status,401);
  assert.equal((await send({})).status,400);
  assert.equal((await send({padding:"x".repeat(256001)})).status,413);
 });
});
test("quota does not retry or fall back and forwards safe wait time",async()=>{
 let calls=0;
 await withServer(async()=>{calls++;return new Response("secret provider detail",{status:429,headers:{"Retry-After":"60"}});},async send=>{
  const r=await send();assert.equal(r.status,429);assert.equal(r.headers.get("retry-after"),"60");assert.deepEqual(await r.json(),{error:"provider_rate_limit"});
 });assert.equal(calls,1);
});
test("provider credentials and unavailable response are sanitized",async()=>{
 for(const status of [401,403,500])await withServer(async()=>new Response("secret",{status}),async send=>{const r=await send();assert.equal(r.status,status===500?502:503);assert.ok(!(await r.text()).includes("secret"));});
});
test("truncated and network failures leave no draft",async()=>{
 for(const upstream of [async()=>{throw Error("secret");},async()=>Response.json({candidates:[{finishReason:"MAX_TOKENS"}]})])await withServer(upstream,async send=>{const r=await send();assert.equal(r.status,502);assert.deepEqual(await r.json(),{error:"generation_failed"});});
});
