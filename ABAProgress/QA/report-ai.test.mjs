import test from "node:test";
import assert from "node:assert/strict";
import {validatePayload,requestBody,parseResponse,server} from "../Server/server.mjs";
const fixture=()=>({version:1,series:[[20,60]]});
const prose={currentStatus:"계열 1 최근 평균 40",majorChanges:"비교 구간이 겹칩니다.",warnings:[]};
const completion=(content=prose)=>({choices:[{finish_reason:"stop",message:{content:JSON.stringify(content)}}]});
test("numeric summary without raw series",()=>{const out=validatePayload(fixture());assert.equal(out.series[0].recentMean,40);assert.equal(out.series[0].count,2);assert.equal(out.series[0].overlappingWindows,true);assert.equal(out.series[0].values,undefined);});
test("reject every extra field and string including identity and instructions",()=>{for(const key of ["childName","date","notes","domain","confirmedObservations"]){assert.throws(()=>validatePayload({...fixture(),[key]:"SECRET"}));}for(const value of ["20",null,101,-1,NaN])assert.throws(()=>validatePayload({version:1,series:[[value]]}));});
test("window arithmetic and sample limits",()=>{const s=validatePayload({version:1,series:[[10,20,30,60,70,80]]}).series[0];assert.equal(s.changePercentagePoints,50);assert.equal(s.overlappingWindows,false);assert.throws(()=>validatePayload({version:1,series:[]}));assert.throws(()=>validatePayload({version:1,series:[Array(2001).fill(1)]}));});
test("Groq fixed model and strict JSON schema",()=>{const r=requestBody(fixture());assert.equal(r.model,"openai/gpt-oss-120b");assert.equal(r.response_format.json_schema.strict,true);assert.deepEqual(r.response_format.json_schema.schema.required,["currentStatus","majorChanges","warnings"]);assert.ok(!r.messages[1].content.includes('values'));});
test("refused or truncated output rejected",()=>{for(const reason of ["length","tool_calls",null]){const r=completion();r.choices[0].finish_reason=reason;assert.throws(()=>parseResponse(r));}const r=completion();r.choices[0].message.refusal="refused";assert.throws(()=>parseResponse(r));});
test("only designated fields and no blank output",()=>{assert.deepEqual(parseResponse(completion()),prose);assert.throws(()=>parseResponse(completion({...prose,diagnosis:"unexpected"})));assert.throws(()=>parseResponse(completion({...prose,currentStatus:" "})));});
test("server requires access token",()=>assert.throws(()=>server({token:""})));

async function withServer(fetchImpl,run){
 const service=server({token:"t".repeat(32),fetchImpl});
 await new Promise(resolve=>service.listen(0,"127.0.0.1",resolve));
 const url=`http://127.0.0.1:${service.address().port}/report/narrative`;
 const send=(body=fixture(),auth="Bearer "+"t".repeat(32),key="gsk_"+"k".repeat(32))=>fetch(url,{method:"POST",headers:{Authorization:auth,"X-Groq-API-Key":key},body:JSON.stringify(body)});
 try{await run(send);}finally{service.closeAllConnections();await new Promise(resolve=>service.close(resolve));}
}
test("HTTP success uses Groq once with a per-request key and numeric summaries",async()=>{
 let calls=0;
 await withServer(async(url,options)=>{calls++;assert.equal(url,"https://api.groq.com/openai/v1/chat/completions");assert.equal(options.headers.Authorization,"Bearer gsk_"+"k".repeat(32));assert.ok(!options.body.includes("NOT_TO_SEND"));return Response.json(completion());},async send=>{const r=await send(fixture());assert.equal(r.status,200);assert.equal(r.headers.get("cache-control"),"no-store");assert.deepEqual(await r.json(),prose);});
 assert.equal(calls,1);
});
test("unauthorized, invalid and oversized input never reaches provider",async()=>{
 await withServer(async()=>{assert.fail("Unexpected provider call");},async send=>{
  assert.equal((await send(fixture(),"wrong")).status,401);
  assert.equal((await send(fixture(),undefined,"bad-key")).status,422);
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
 for(const upstream of [async()=>{throw Error("secret");},async()=>Response.json({choices:[{finish_reason:"length"}]})])await withServer(upstream,async send=>{const r=await send();assert.equal(r.status,502);assert.deepEqual(await r.json(),{error:"generation_failed"});});
});
