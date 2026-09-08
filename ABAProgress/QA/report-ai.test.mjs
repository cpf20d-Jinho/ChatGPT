import test from "node:test";
import assert from "node:assert/strict";
import {validatePayload,requestBody,parseResponse,server} from "../Server/server.mjs";
const fixture=()=>({templateVersion:"geomdan-interim-v1",stoCount:1,masteredCount:0,confirmedObservations:"",
 goals:[{name:"가상 목표",domain:"모방",group:"기타 목표",points:[{date:"2026-01-01",value:20,level:1},{date:"2026-01-03",value:60,level:1}],masteredLevels:[]}]});
test("aggregate evidence and strip identity",()=>{const p=fixture();p.childName="NOT_TO_SEND";const out=validatePayload(p);assert.equal(out.domains[0].recentMean,40);assert.equal(JSON.stringify(out).includes("NOT_TO_SEND"),false)});
test("reject invalid measurement and count",()=>{const p=fixture();p.goals[0].points[0].value=101;assert.throws(()=>validatePayload(p));p.goals[0].points[0].value=10;p.stoCount=22;assert.throws(()=>validatePayload(p));});
test("Responses strict format and no store",()=>{const r=requestBody(fixture(),"configured-model");assert.equal(r.store,false);assert.equal(r.text.format.strict,true);assert.deepEqual(r.text.format.schema.required,["currentStatus","majorChanges","warnings"]);});
test("refusal and incomplete output fail closed",()=>{assert.throws(()=>parseResponse({status:"incomplete"}));assert.throws(()=>parseResponse({status:"completed",output:[{content:[{type:"refusal"}]}]}));});
test("valid output retains only designated prose",()=>{const content={currentStatus:"자료에 근거한 현황",majorChanges:"동일 단계에서의 변화",warnings:[]};assert.deepEqual(parseResponse({status:"completed",output:[{content:[{type:"output_text",text:JSON.stringify(content)}]}]}),content)});
test("service requires server secrets",()=>assert.throws(()=>server({apiKey:"",model:"",token:""})));
