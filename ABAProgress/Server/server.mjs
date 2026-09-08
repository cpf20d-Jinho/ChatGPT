import {createServer} from "node:http";
import {readFileSync} from "node:fs";
import {timingSafeEqual} from "node:crypto";
import {fileURLToPath} from "node:url";

const guide=readFileSync(new URL("./GUIDE_SCRIPT.md",import.meta.url),"utf8");
// This contract contains no user-supplied strings or real-world identifiers.
export function validatePayload(p){
 if(!p||Object.keys(p).sort().join(',')!=="series,version"||p.version!==1||!Array.isArray(p.series)||p.series.length<1||p.series.length>100)throw Error("Invalid numeric payload");
 let total=0;
 const series=p.series.map((values,index)=>{
  if(!Array.isArray(values)||values.length<1||values.length>2000||values.some(v=>typeof v!=="number"||!Number.isFinite(v)||v<0||v>100))throw Error("Invalid values");
  total+=values.length;if(total>10000)throw Error("Too many values");
  const mean=a=>a.reduce((x,y)=>x+y,0)/a.length;
  const first=mean(values.slice(0,3)),recent=mean(values.slice(-3));
  return {series:index+1,count:values.length,firstMean:first,recentMean:recent,changePercentagePoints:recent-first,minimum:Math.min(...values),maximum:Math.max(...values),overlappingWindows:values.length<6};
 });
 return {version:1,series};
}
export const MODEL="gemini-3.8-flash";
export function requestBody(payload){
 return {store:false,systemInstruction:{parts:[{text:guide}]},
  contents:[{role:"user",parts:[{text:JSON.stringify(validatePayload(payload))}]}],
  generationConfig:{maxOutputTokens:4096,thinkingConfig:{thinkingLevel:"LOW"},responseMimeType:"application/json",responseJsonSchema:{
   type:"object",additionalProperties:false,
   properties:{currentStatus:{type:"string"},majorChanges:{type:"string"},warnings:{type:"array",items:{type:"string"}}},
   required:["currentStatus","majorChanges","warnings"]
  }}};
}
export function parseResponse(r){
 const candidate=r?.candidates?.[0];
 if(r?.promptFeedback?.blockReason||candidate?.finishReason!=="STOP"||candidate?.safetyRatings?.some(x=>x.blocked))throw Error("Incomplete or blocked response");
 const parts=candidate.content?.parts;
 if(!Array.isArray(parts)||parts.some(x=>x.functionCall))throw Error("Invalid parts");
 const out=JSON.parse(parts.filter(x=>!x.thought&&typeof x.text==="string").map(x=>x.text).join(""));
 if(!out||Object.keys(out).sort().join(",")!=="currentStatus,majorChanges,warnings")throw Error("Unexpected fields");
 if(typeof out.currentStatus!=="string"||typeof out.majorChanges!=="string"||!Array.isArray(out.warnings)||
  out.warnings.length>20||out.warnings.some(x=>typeof x!=="string"||x.length>2000)||!out.currentStatus.trim()||!out.majorChanges.trim()||
  out.currentStatus.length>12000||out.majorChanges.length>12000)throw Error("Invalid response");
 return out;
}
export function server({apiKey,token,fetchImpl=fetch}){
 if(!apiKey||!token||token.length<32)throw Error("Set GEMINI_API_KEY and REPORT_SERVER_TOKEN (32+ chars) on server only");
 let busy=false;
 return createServer(async(req,res)=>{
  res.setHeader("Cache-Control","no-store");res.setHeader("Content-Type","application/json");
  const received=Buffer.from(req.headers.authorization??""),expected=Buffer.from("Bearer "+token);
  if(received.length!==expected.length||!timingSafeEqual(received,expected)){res.writeHead(401);res.end('{"error":"unauthorized"}');return;}
  if(req.method!=="POST"||req.url!=="/report/narrative"){res.writeHead(404);res.end('{"error":"not_found"}');return;}
  if(busy){res.writeHead(429);res.end('{"error":"busy"}');return;}
  busy=true;
  try{
   let size=0;const chunks=[];
   for await(const chunk of req){size+=chunk.length;if(size>256000){res.writeHead(413);res.end('{"error":"payload_too_large"}');return;}chunks.push(chunk);}
   let body;
   try {body=requestBody(JSON.parse(Buffer.concat(chunks).toString()));}
   catch {res.writeHead(400);res.end('{"error":"invalid_payload"}');return;}
   const r=await fetchImpl(`https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`,{method:"POST",
    headers:{"x-goog-api-key":apiKey,"Content-Type":"application/json"},
    body:JSON.stringify(body),signal:AbortSignal.timeout(75000)});
   // One call only: never retry automatically or switch providers/models/plans.
   if(r.status===429){
    const retry=r.headers?.get("retry-after");
    if(retry&&/^\d{1,6}$/.test(retry))res.setHeader("Retry-After",retry);
    res.writeHead(429);res.end('{"error":"provider_rate_limit"}');return;
   }
   if(r.status===401||r.status===403){res.writeHead(503);res.end('{"error":"provider_configuration"}');return;}
   if(r.status===413){res.writeHead(413);res.end('{"error":"payload_too_large"}');return;}
   if(!r.ok)throw Error("Upstream error");
   const result=parseResponse(await r.json());
   res.writeHead(200);res.end(JSON.stringify(result));
  }catch{
   // No clinical payload, API key, or provider error body in logs or response.
   res.writeHead(502);res.end('{"error":"generation_failed"}');
  }finally{busy=false;}
 });
}
if(process.argv[1]===fileURLToPath(import.meta.url)){
 const service=server({apiKey:process.env.GEMINI_API_KEY,token:process.env.REPORT_SERVER_TOKEN});
 service.listen(Number(process.env.PORT??8787),"127.0.0.1",()=>console.log("Report service listening on loopback; place behind authenticated TLS ingress."));
}
