import {createServer} from "node:http";
import {readFileSync} from "node:fs";
import {timingSafeEqual} from "node:crypto";
import {fileURLToPath} from "node:url";

const guide=readFileSync(new URL("./GUIDE_SCRIPT.md",import.meta.url),"utf8");
export function validatePayload(p){
 if(!p||p.templateVersion!=="geomdan-interim-v1"||!Array.isArray(p.goals)||p.goals.length<1||p.goals.length>100)throw Error("Invalid goals");
 if(typeof p.confirmedObservations!=="string"||p.confirmedObservations.length>10000)throw Error("Invalid observations");
 for(const g of p.goals){
  if(typeof g.name!=="string"||g.name.length>300||typeof g.domain!=="string"||g.domain.length>100||typeof g.group!=="string"||g.group.length>100)throw Error("Invalid labels");
  if(!Array.isArray(g.points)||g.points.length<1||g.points.length>2000)throw Error("Invalid points");
  for(const x of g.points)if(!/^\d{4}-\d{2}-\d{2}$/.test(x.date)||!Number.isFinite(x.value)||x.value<0||x.value>100||!Number.isInteger(x.level)||x.level<1||x.level>100)throw Error("Invalid observation");
  if(!Array.isArray(g.masteredLevels)||g.masteredLevels.some(l=>!g.points.some(x=>x.level===l)))throw Error("Invalid mastery");
 }
 // Whitelist only the fields needed for drafting. Never forward a full child/document object.
 const goals=p.goals.map(g=>({name:g.name,domain:g.domain,
  points:g.points.map(x=>({date:x.date,value:x.value,level:x.level})),
  masteredLevels:[...new Set(g.masteredLevels)]}));
 const grouped={};
 const mean=a=>a.reduce((s,x)=>s+x,0)/a.length;
 let stoCount=0,masteredCount=0;
 for(const g of goals){
  const levels=[...new Set(g.points.map(x=>x.level))];stoCount+=levels.length;masteredCount+=g.masteredLevels.length;
  for(const level of levels){const s=g.points.filter(x=>x.level===level).sort((a,b)=>a.date.localeCompare(b.date));(grouped[g.domain]??=[]).push(s);}
 }
 const domains=Object.entries(grouped).map(([name,series])=>({name,stoCount:series.length,
  initialMean:mean(series.map(s=>mean(s.slice(0,3).map(p=>p.value)))),
  recentMean:mean(series.map(s=>mean(s.slice(-3).map(p=>p.value))))}));
 if(stoCount!==p.stoCount||masteredCount!==p.masteredCount)throw Error("Counts do not match evidence");
 return {templateVersion:p.templateVersion,stoCount,masteredCount,domains,goals,confirmedObservations:p.confirmedObservations};
}
export function requestBody(payload,model){
 return {model,store:false,instructions:guide,
  input:[{role:"user",content:JSON.stringify(validatePayload(payload))}],
  text:{format:{type:"json_schema",name:"aba_report_narrative",strict:true,schema:{
   type:"object",additionalProperties:false,
   properties:{currentStatus:{type:"string"},majorChanges:{type:"string"},warnings:{type:"array",items:{type:"string"}}},
   required:["currentStatus","majorChanges","warnings"]
  }}}};
}
export function parseResponse(r){
 if(r.status!=="completed")throw Error("Incomplete response");
 const parts=(r.output??[]).flatMap(x=>x.content??[]);
 if(parts.some(x=>x.type==="refusal"))throw Error("Refused response");
 const out=JSON.parse(parts.filter(x=>x.type==="output_text").map(x=>x.text).join(""));
 if(typeof out.currentStatus!=="string"||typeof out.majorChanges!=="string"||!Array.isArray(out.warnings)||
  out.warnings.some(x=>typeof x!=="string")||!out.currentStatus||!out.majorChanges||
  out.currentStatus.length>12000||out.majorChanges.length>12000)throw Error("Invalid response");
 return out;
}
export function server({apiKey,model,token,fetchImpl=fetch}){
 if(!apiKey||!model||!token||token.length<32)throw Error("Set OPENAI_API_KEY, OPENAI_MODEL and REPORT_SERVER_TOKEN (32+ chars) on server only");
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
   for await(const chunk of req){size+=chunk.length;if(size>256000)throw Error("Payload limit");chunks.push(chunk);}
   let body;
   try {body=requestBody(JSON.parse(Buffer.concat(chunks).toString()),model);}
   catch {res.writeHead(400);res.end('{"error":"invalid_payload"}');return;}
   const r=await fetchImpl("https://api.openai.com/v1/responses",{method:"POST",
    headers:{"Authorization":"Bearer "+apiKey,"Content-Type":"application/json"},
    body:JSON.stringify(body),signal:AbortSignal.timeout(75000)});
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
 const service=server({apiKey:process.env.OPENAI_API_KEY,model:process.env.OPENAI_MODEL,token:process.env.REPORT_SERVER_TOKEN});
 service.listen(Number(process.env.PORT??8787),"127.0.0.1",()=>console.log("Report service listening on loopback; place behind authenticated TLS ingress."));
}
