import {randomBytes,randomUUID,scryptSync,timingSafeEqual,createHash} from "node:crypto";

// scrypt cost tuned for a free-tier host: ~16MiB/hash (Node core, no native deps).
const SCRYPT_OPTIONS={N:16384,r:8,p:1,maxmem:64*1024*1024};
const SCRYPT_KEYLEN=64;
const EMAIL_RE=/^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const SESSION_TTL_MS=30*24*60*60*1000;
const VERIFICATION_TTL_MS=15*60*1000;
const MAX_VERIFICATION_ATTEMPTS=5;

function scryptHash(password,saltHex){
 return scryptSync(password,Buffer.from(saltHex,"hex"),SCRYPT_KEYLEN,SCRYPT_OPTIONS).toString("hex");
}
function makePasswordRecord(password){
 const salt=randomBytes(16).toString("hex");
 return `${salt}:${scryptHash(password,salt)}`;
}
function verifyPasswordRecord(password,record){
 const [salt,hash]=record.split(":");
 if(!salt||!hash)return false;
 const a=Buffer.from(scryptHash(password,salt),"hex"),b=Buffer.from(hash,"hex");
 return a.length===b.length&&timingSafeEqual(a,b);
}
function sixDigitCode(){
 return String(randomBytes(4).readUInt32BE()%1_000_000).padStart(6,"0");
}
function sha256Hex(s){
 return createHash("sha256").update(s).digest("hex");
}
function isBase64(s){
 return typeof s==="string"&&s.length>0&&s.length<200000&&/^[A-Za-z0-9+/]+=*$/.test(s);
}
function toBlobArg(base64){
 return Buffer.from(base64,"base64");
}
function toBase64(blob){
 return Buffer.from(blob).toString("base64");
}

function readJsonBody(req,maxBytes=65536){
 return new Promise((resolve,reject)=>{
  let size=0;const chunks=[];
  req.on("data",chunk=>{
   size+=chunk.length;
   if(size>maxBytes){reject(Object.assign(Error("payload_too_large"),{status:413}));req.destroy();return;}
   chunks.push(chunk);
  });
  req.on("end",()=>{
   try{resolve(JSON.parse(Buffer.concat(chunks).toString("utf8")||"{}"));}
   catch{reject(Object.assign(Error("invalid_json"),{status:400}));}
  });
  req.on("error",reject);
 });
}
function fail(res,status,error){
 res.writeHead(status);res.end(JSON.stringify({error}));
}

// Therapist account auth: signup / email verification / login / profile sync.
// Child data, sessions, and reports never pass through here — see Server/README.md.
export function createAuthService({db,now=Date.now,sendEmail,sessionTtlMs=SESSION_TTL_MS}){

 async function signup(req,res){
  let body;
  try{body=await readJsonBody(req);}catch(e){fail(res,e.status??400,e.message);return;}
  const {email,password,profileKeySalt,profileCiphertext,profileNonce}=body??{};
  if(typeof email!=="string"||email.length>320||!EMAIL_RE.test(email)){fail(res,422,"invalid_email");return;}
  if(typeof password!=="string"||password.length<10||password.length>256){fail(res,422,"weak_password");return;}
  if(!isBase64(profileKeySalt)||!isBase64(profileCiphertext)||!isBase64(profileNonce)){fail(res,422,"invalid_profile_payload");return;}

  const normalizedEmail=email.trim().toLowerCase();
  const existing=await db.execute({sql:"SELECT id FROM users WHERE email = ?",args:[normalizedEmail]});
  if(existing.rows.length){fail(res,409,"email_taken");return;}

  const id=randomUUID();
  const nowIso=new Date(now()).toISOString();
  await db.execute({
   sql:`INSERT INTO users (id,email,email_verified_at,password_hash,profile_ciphertext,profile_nonce,profile_key_salt,created_at,updated_at)
        VALUES (?,?,NULL,?,?,?,?,?,?)`,
   args:[id,normalizedEmail,makePasswordRecord(password),
    toBlobArg(profileCiphertext),toBlobArg(profileNonce),toBlobArg(profileKeySalt),nowIso,nowIso],
  });

  const code=sixDigitCode();
  await db.execute({
   sql:"INSERT INTO email_verifications (id,user_id,code_hash,expires_at,attempt_count,created_at) VALUES (?,?,?,?,0,?)",
   args:[randomUUID(),id,sha256Hex(code),new Date(now()+VERIFICATION_TTL_MS).toISOString(),nowIso],
  });
  if(sendEmail)await sendEmail({to:normalizedEmail,subject:"Easy ABA 이메일 인증 코드",text:`인증 코드: ${code} (15분 내 유효)`});

  res.writeHead(201);res.end(JSON.stringify({userId:id}));
 }

 async function verifyEmail(req,res){
  let body;
  try{body=await readJsonBody(req);}catch(e){fail(res,e.status??400,e.message);return;}
  const {email,code}=body??{};
  if(typeof email!=="string"||typeof code!=="string"||!/^\d{6}$/.test(code)){fail(res,422,"invalid_request");return;}
  const normalizedEmail=email.trim().toLowerCase();

  const userRow=await db.execute({sql:"SELECT id,email_verified_at FROM users WHERE email = ?",args:[normalizedEmail]});
  const user=userRow.rows[0];
  if(!user){fail(res,404,"not_found");return;}
  if(user.email_verified_at){res.writeHead(200);res.end(JSON.stringify({status:"already_verified"}));return;}

  const pending=await db.execute({
   sql:`SELECT id,code_hash,expires_at,attempt_count FROM email_verifications
        WHERE user_id = ? AND consumed_at IS NULL ORDER BY created_at DESC LIMIT 1`,
   args:[user.id],
  });
  const verification=pending.rows[0];
  if(!verification||Date.parse(verification.expires_at)<=now()){fail(res,410,"code_expired");return;}
  if(verification.attempt_count>=MAX_VERIFICATION_ATTEMPTS){fail(res,429,"too_many_attempts");return;}

  const match=sha256Hex(code)===verification.code_hash;
  await db.execute({sql:"UPDATE email_verifications SET attempt_count = attempt_count + 1 WHERE id = ?",args:[verification.id]});
  if(!match){fail(res,422,"invalid_code");return;}

  const nowIso=new Date(now()).toISOString();
  await db.execute({sql:"UPDATE email_verifications SET consumed_at = ? WHERE id = ?",args:[nowIso,verification.id]});
  await db.execute({sql:"UPDATE users SET email_verified_at = ? WHERE id = ?",args:[nowIso,user.id]});
  res.writeHead(200);res.end(JSON.stringify({status:"verified"}));
 }

 async function login(req,res){
  let body;
  try{body=await readJsonBody(req);}catch(e){fail(res,e.status??400,e.message);return;}
  const {email,password}=body??{};
  if(typeof email!=="string"||typeof password!=="string"){fail(res,422,"invalid_request");return;}
  const normalizedEmail=email.trim().toLowerCase();

  const result=await db.execute({
   sql:`SELECT id,password_hash,email_verified_at,profile_ciphertext,profile_nonce,profile_key_salt FROM users WHERE email = ?`,
   args:[normalizedEmail],
  });
  const user=result.rows[0];
  // Hash a decoy record even when the account doesn't exist, so response timing doesn't leak which case failed.
  const record=user?.password_hash??`${randomBytes(16).toString("hex")}:${randomBytes(SCRYPT_KEYLEN).toString("hex")}`;
  const passwordOk=verifyPasswordRecord(password,record);
  if(!user||!passwordOk){fail(res,401,"invalid_credentials");return;}
  if(!user.email_verified_at){fail(res,403,"email_not_verified");return;}

  const token=randomBytes(32).toString("base64url");
  const nowIso=new Date(now()).toISOString();
  await db.execute({
   sql:"INSERT INTO sessions (token_digest,user_id,expires_at,created_at) VALUES (?,?,?,?)",
   args:[sha256Hex(token),user.id,new Date(now()+sessionTtlMs).toISOString(),nowIso],
  });

  res.writeHead(200);res.end(JSON.stringify({
   sessionToken:token,
   profileKeySalt:toBase64(user.profile_key_salt),
   profileCiphertext:toBase64(user.profile_ciphertext),
   profileNonce:toBase64(user.profile_nonce),
  }));
 }

 async function authenticateSession(req){
  const header=req.headers.authorization??"";
  if(!header.startsWith("Bearer "))return null;
  const digest=sha256Hex(header.slice(7));
  const result=await db.execute({
   sql:"SELECT user_id as userId, expires_at as expiresAt FROM sessions WHERE token_digest = ?",
   args:[digest],
  });
  const session=result.rows[0];
  if(!session||Date.parse(session.expiresAt)<=now())return null;
  return session.userId;
 }

 async function updateProfile(req,res){
  const userId=await authenticateSession(req);
  if(!userId){fail(res,401,"unauthorized");return;}
  let body;
  try{body=await readJsonBody(req);}catch(e){fail(res,e.status??400,e.message);return;}
  const {profileCiphertext,profileNonce}=body??{};
  if(!isBase64(profileCiphertext)||!isBase64(profileNonce)){fail(res,422,"invalid_profile_payload");return;}
  await db.execute({
   sql:"UPDATE users SET profile_ciphertext = ?, profile_nonce = ?, updated_at = ? WHERE id = ?",
   args:[toBlobArg(profileCiphertext),toBlobArg(profileNonce),new Date(now()).toISOString(),userId],
  });
  res.writeHead(200);res.end(JSON.stringify({status:"ok"}));
 }

 async function logout(req,res){
  const header=req.headers.authorization??"";
  if(header.startsWith("Bearer ")){
   await db.execute({sql:"DELETE FROM sessions WHERE token_digest = ?",args:[sha256Hex(header.slice(7))]});
  }
  res.writeHead(200);res.end(JSON.stringify({status:"ok"}));
 }

 async function handle(req,res){
  if(req.method==="POST"&&req.url==="/auth/signup"){await signup(req,res);return true;}
  if(req.method==="POST"&&req.url==="/auth/verify-email"){await verifyEmail(req,res);return true;}
  if(req.method==="POST"&&req.url==="/auth/login"){await login(req,res);return true;}
  if(req.method==="POST"&&req.url==="/auth/logout"){await logout(req,res);return true;}
  if(req.method==="PUT"&&req.url==="/auth/profile"){await updateProfile(req,res);return true;}
  return false;
 }

 return {handle};
}
