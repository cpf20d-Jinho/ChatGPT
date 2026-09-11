import {randomBytes, createHash, timingSafeEqual} from 'node:crypto';
import {readFileSync} from 'node:fs';

const assets = new Map([
 ['/report/editor', ['text/html; charset=utf-8', 'editor.html']],
 ['/report/editor.js', ['text/javascript; charset=utf-8', 'editor.js']],
 ['/report/editor.css', ['text/css; charset=utf-8', 'editor.css']]
].map(([url, [type, file]]) => [url, {type, body:readFileSync(new URL(file, import.meta.url))}]));
const hash = value => createHash('sha256').update(value).digest();
const reply = (res, status, body) => { res.writeHead(status); res.end(JSON.stringify(body)); };
async function envelope(req) {
 let size=0; const chunks=[];
 for await (const chunk of req) {
  size+=chunk.length;
  if(size>600000) throw Error('size');
  chunks.push(chunk);
 }
 const body=JSON.parse(Buffer.concat(chunks).toString());
 if(!body || Object.keys(body).sort().join(',')!=='ciphertext,revision' ||
    !Number.isSafeInteger(body.revision) || body.revision<0 ||
    typeof body.ciphertext!=='string' || body.ciphertext.length<40 || body.ciphertext.length>590000 ||
    !/^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(body.ciphertext)) throw Error('payload');
 return body;
}

// Ephemeral encrypted relay only. No report IDs, patient profiles, keys or plaintext on disk.
export function reportEditor({now=Date.now}) {
 const rooms=new Map();
 const prune=()=>{ for(const [id,room] of rooms) if(room.expiresAt<=now()) rooms.delete(id); };
 const timer=setInterval(prune, 10000); timer.unref();
 return {
  close(){clearInterval(timer); rooms.clear();},
  async handle(req,res,account){
   if(assets.has(req.url) && req.method==='GET') {
    const asset=assets.get(req.url);
    res.setHeader('Content-Type',asset.type);
    res.setHeader('Content-Security-Policy',"default-src 'none'; script-src 'self'; style-src 'self'; connect-src 'self'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'");
    res.setHeader('Referrer-Policy','no-referrer');
    res.setHeader('X-Content-Type-Options','nosniff');
    res.setHeader('X-Frame-Options','DENY');
    res.setHeader('X-Robots-Tag','noindex, nofollow');
    res.end(asset.body); return true;
   }
   if(req.url!=='/report/edit-sessions' && !/^\/report\/edit-sessions\/[a-f0-9]{32}$/.test(req.url)) return false;
   prune();
   if(req.url==='/report/edit-sessions') {
    if(!account){reply(res,401,{error:'unauthorized'});return true;}
    if(req.method!=='POST'){reply(res,405,{error:'method'});return true;}
    if(req.headers['x-aba-consent']!=='encrypted-edit-v1'){reply(res,428,{error:'consent_required'});return true;}
    try {
     const body=await envelope(req);
     // Check after reading the request to enforce the cap across concurrent uploads.
     if(rooms.size>=32 || [...rooms.values()].filter(r=>r.owner===account.digest).length>=3){reply(res,429,{error:'room_limit'});return true;}
     if(body.revision!==0){reply(res,400,{error:'revision'});return true;}
     const id=randomBytes(16).toString('hex'), capability=randomBytes(32).toString('hex');
     const expiresAt=Math.min(now()+30*60000,Date.parse(account.expiresAt));
     rooms.set(id,{owner:account.digest,capability:hash(capability),expiresAt,ciphertext:body.ciphertext,revision:0,window:now(),count:0});
     reply(res,201,{id,capability,expiresAt,revision:0});
    } catch {reply(res,400,{error:'invalid_encrypted_payload'});}
    return true;
   }
   const id=req.url.split('/').at(-1), room=rooms.get(id);
   const capability=req.headers['x-aba-edit-capability'];
   if(!room || typeof capability!=='string' || !timingSafeEqual(hash(capability),room.capability)){
    reply(res,404,{error:'expired_or_unavailable'});return true;
   }
   if(now()-room.window>=60000){room.window=now();room.count=0;}
   if(++room.count>60){reply(res,429,{error:'rate_limit'});return true;}
   if(req.method==='GET'){reply(res,200,{ciphertext:room.ciphertext,revision:room.revision,expiresAt:room.expiresAt});return true;}
   if(req.method==='DELETE'){rooms.delete(id);reply(res,200,{deleted:true});return true;}
   if(req.method!=='PUT'){reply(res,405,{error:'method'});return true;}
   try {
    const body=await envelope(req);
    if(rooms.get(id)!==room || room.expiresAt<=now()){reply(res,404,{error:'expired_or_unavailable'});return true;}
    if(body.revision!==room.revision){reply(res,409,{error:'revision_conflict'});return true;}
    room.ciphertext=body.ciphertext;room.revision++;
    reply(res,200,{revision:room.revision,expiresAt:room.expiresAt});
   } catch {reply(res,400,{error:'invalid_encrypted_payload'});}
   return true;
  }
 };
}
