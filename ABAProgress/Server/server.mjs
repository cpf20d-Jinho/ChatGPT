import {createServer} from "node:http";
import {readFileSync} from "node:fs";
import {timingSafeEqual,createHash} from "node:crypto";
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
export const MODEL="openai/gpt-oss-120b";
export function requestBody(payload){
 return {model:MODEL,max_completion_tokens:3072,reasoning_effort:"low",
  messages:[{role:"system",content:guide},{role:"user",content:JSON.stringify(validatePayload(payload))}],
  response_format:{type:"json_schema",json_schema:{name:"aba_numeric_interpretation",strict:true,schema:{
   type:"object",additionalProperties:false,
   properties:{currentStatus:{type:"string"},majorChanges:{type:"string"},warnings:{type:"array",items:{type:"string"}}},
   required:["currentStatus","majorChanges","warnings"]
  }}}};
}
export function parseResponse(r){
 const choice=r?.choices?.[0];
 if(choice?.finish_reason!=="stop"||choice.message?.refusal||choice.message?.tool_calls)throw Error("Incomplete or refused response");
 const out=JSON.parse(choice.message.content);
 if(!out||Object.keys(out).sort().join(",")!=="currentStatus,majorChanges,warnings")throw Error("Unexpected fields");
 if(typeof out.currentStatus!=="string"||typeof out.majorChanges!=="string"||!Array.isArray(out.warnings)||
  out.warnings.length>20||out.warnings.some(x=>typeof x!=="string"||x.length>2000)||!out.currentStatus.trim()||!out.majorChanges.trim()||
  out.currentStatus.length>12000||out.majorChanges.length>12000)throw Error("Invalid response");
 return out;
}
export function server({token,users,fetchImpl=fetch,now=Date.now,limit=10}){
 const accounts=users??(token?.length>=32?[{digest:createHash("sha256").update(token).digest("hex"),expiresAt:"2099-01-01T00:00:00Z"}]:[]);
 if(!accounts.length||accounts.some(a=>!/^\w{64}$/.test(a.digest)||!/^[a-f0-9]+$/.test(a.digest)||!Number.isFinite(Date.parse(a.expiresAt))))throw Error("Configure user token digests and expiration");
 const windows=new Map();
 let busy=false;
 return createServer(async(req,res)=>{
  res.setHeader("Cache-Control","no-store");res.setHeader("Content-Type","application/json");
  const auth=req.headers.authorization??"";
  const received=createHash("sha256").update(auth.startsWith("Bearer ")?auth.slice(7):"").digest();
  const account=accounts.find(a=>Date.parse(a.expiresAt)>now()&&timingSafeEqual(received,Buffer.from(a.digest,"hex")));
  if(!account){res.writeHead(401);res.end('{"error":"unauthorized"}');return;}
  if(req.method==="GET"&&req.url==="/report/health"){res.end(JSON.stringify({status:"ok",contract:"numeric-v1",provider:"groq",providerVerified:false}));return;}
  if(req.method!=="POST"||req.url!=="/report/narrative"){res.writeHead(404);res.end('{"error":"not_found"}');return;}
  if(req.headers["x-aba-consent"]!=="numeric-v1"){res.writeHead(428);res.end('{"error":"consent_required"}');return;}
  let window=windows.get(account.digest);
  if(!window||now()-window.start>=60000){window={start:now(),count:0};windows.set(account.digest,window);}
  if(window.count>=limit){res.writeHead(429);res.end('{"error":"user_rate_limit"}');return;}
  window.count++;
  if(busy){res.writeHead(429);res.end('{"error":"busy"}');return;}
  busy=true;
  try{
   let size=0;const chunks=[];
   for await(const chunk of req){size+=chunk.length;if(size>256000){res.writeHead(413);res.end('{"error":"payload_too_large"}');return;}chunks.push(chunk);}
   let body;
   try {body=requestBody(JSON.parse(Buffer.concat(chunks).toString()));}
   catch {res.writeHead(400);res.end('{"error":"invalid_payload"}');return;}
   const userKey=req.headers["x-groq-api-key"];
   if(typeof userKey!=="string"||!/^gsk_[A-Za-z0-9_-]{20,}$/.test(userKey)){res.writeHead(422);res.end('{"error":"groq_key_required"}');return;}
   const r=await fetchImpl("https://api.groq.com/openai/v1/chat/completions",{method:"POST",
    headers:{"Authorization":"Bearer "+userKey,"Content-Type":"application/json"},
    body:JSON.stringify(body),redirect:"error",signal:AbortSignal.timeout(75000)});
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
 if(process.env.NODE_ENV==="production"&&!process.env.REPORT_USERS_FILE&&!process.env.REPORT_USERS_JSON)throw Error("Production requires per-user expiring token digests");
 const users=process.env.REPORT_USERS_FILE?JSON.parse(readFileSync(process.env.REPORT_USERS_FILE,"utf8")):
  process.env.REPORT_USERS_JSON?JSON.parse(process.env.REPORT_USERS_JSON):undefined;
 const service=server({token:process.env.REPORT_SERVER_TOKEN,users});
 service.requestTimeout=15000;service.headersTimeout=10000;
 service.listen(Number(process.env.PORT??8787),process.env.LISTEN_HOST??"127.0.0.1",()=>console.log("Report service ready; TLS ingress required for external access."));
}
