import test from "node:test";
import assert from "node:assert/strict";
import {once} from "node:events";
import {mkdtempSync,rmSync} from "node:fs";
import {tmpdir} from "node:os";
import {join} from "node:path";
import {server} from "../Server/server.mjs";
import {createAuthService} from "../Server/auth.mjs";
import {createDb,migrate} from "../Server/db.mjs";

async function startTestServer(){
 const dir=mkdtempSync(join(tmpdir(),"aba-auth-test-"));
 const db=createDb({url:`file:${join(dir,"test.db")}`});
 await migrate(db);
 const sentEmails=[];
 const authService=createAuthService({db,sendEmail:async(msg)=>{sentEmails.push(msg);}});
 const app=server({token:"t".repeat(32),authService,fetchImpl:async()=>assert.fail("No Groq calls expected")});
 app.listen(0,"127.0.0.1");
 await once(app,"listening");
 const {port}=app.address();
 const base=`http://127.0.0.1:${port}`;
 return {base,sentEmails,close:()=>{
  app.close();
  db.close();
  // libsql keeps a native file handle open on Windows until closed; retry the cleanup once it's released.
  try{rmSync(dir,{recursive:true,force:true});}catch{}
 }};
}

async function postJson(base,path,body){
 const r=await fetch(base+path,{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify(body)});
 return {status:r.status,body:await r.json()};
}

const validSignup=()=>({
 email:"therapist@example.com",
 password:"correct-horse-battery",
 profileKeySalt:Buffer.from("salt-bytes-0001").toString("base64"),
 profileCiphertext:Buffer.from("ciphertext-blob!").toString("base64"),
 profileNonce:Buffer.from("nonce-bytes-0001").toString("base64"),
});

test("signup rejects weak password",async()=>{
 const ctx=await startTestServer();
 try{
  const {status,body}=await postJson(ctx.base,"/auth/signup",{...validSignup(),password:"short"});
  assert.equal(status,422);assert.equal(body.error,"weak_password");
 }finally{ctx.close();}
});

test("signup rejects malformed email",async()=>{
 const ctx=await startTestServer();
 try{
  const {status,body}=await postJson(ctx.base,"/auth/signup",{...validSignup(),email:"not-an-email"});
  assert.equal(status,422);assert.equal(body.error,"invalid_email");
 }finally{ctx.close();}
});

test("signup -> verify-email -> login round trip returns the stored ciphertext",async()=>{
 const ctx=await startTestServer();
 try{
  const signup=validSignup();
  const signupRes=await postJson(ctx.base,"/auth/signup",signup);
  assert.equal(signupRes.status,201);
  assert.equal(ctx.sentEmails.length,1);
  assert.equal(ctx.sentEmails[0].to,signup.email);
  const code=ctx.sentEmails[0].text.match(/\d{6}/)[0];

  const loginBeforeVerify=await postJson(ctx.base,"/auth/login",{email:signup.email,password:signup.password});
  assert.equal(loginBeforeVerify.status,403);
  assert.equal(loginBeforeVerify.body.error,"email_not_verified");

  const verify=await postJson(ctx.base,"/auth/verify-email",{email:signup.email,code});
  assert.equal(verify.status,200);
  assert.equal(verify.body.status,"verified");

  const login=await postJson(ctx.base,"/auth/login",{email:signup.email,password:signup.password});
  assert.equal(login.status,200);
  assert.ok(login.body.sessionToken);
  assert.equal(login.body.profileCiphertext,signup.profileCiphertext);
  assert.equal(login.body.profileNonce,signup.profileNonce);
  assert.equal(login.body.profileKeySalt,signup.profileKeySalt);
 }finally{ctx.close();}
});

test("verify-email rejects wrong code and enforces attempt limit",async()=>{
 const ctx=await startTestServer();
 try{
  const signup=validSignup();
  await postJson(ctx.base,"/auth/signup",signup);
  for(let i=0;i<5;i++){
   const attempt=await postJson(ctx.base,"/auth/verify-email",{email:signup.email,code:"000000"});
   assert.equal(attempt.status,422);
  }
  const locked=await postJson(ctx.base,"/auth/verify-email",{email:signup.email,code:"000000"});
  assert.equal(locked.status,429);
 }finally{ctx.close();}
});

test("login rejects wrong password without revealing account existence",async()=>{
 const ctx=await startTestServer();
 try{
  const signup=validSignup();
  await postJson(ctx.base,"/auth/signup",signup);
  const wrongPassword=await postJson(ctx.base,"/auth/login",{email:signup.email,password:"totally-wrong-password"});
  assert.equal(wrongPassword.status,401);
  const noSuchUser=await postJson(ctx.base,"/auth/login",{email:"nobody@example.com",password:"whatever-password"});
  assert.equal(noSuchUser.status,401);
  assert.equal(wrongPassword.body.error,noSuchUser.body.error);
 }finally{ctx.close();}
});

test("signup rejects duplicate email",async()=>{
 const ctx=await startTestServer();
 try{
  const signup=validSignup();
  await postJson(ctx.base,"/auth/signup",signup);
  const dup=await postJson(ctx.base,"/auth/signup",signup);
  assert.equal(dup.status,409);
  assert.equal(dup.body.error,"email_taken");
 }finally{ctx.close();}
});

test("profile update requires a valid session token",async()=>{
 const ctx=await startTestServer();
 try{
  const noAuth=await fetch(ctx.base+"/auth/profile",{method:"PUT",headers:{"Content-Type":"application/json"},
   body:JSON.stringify({profileCiphertext:"AAAA",profileNonce:"AAAA"})});
  assert.equal(noAuth.status,401);

  const signup=validSignup();
  await postJson(ctx.base,"/auth/signup",signup);
  const code=ctx.sentEmails[0].text.match(/\d{6}/)[0];
  await postJson(ctx.base,"/auth/verify-email",{email:signup.email,code});
  const login=await postJson(ctx.base,"/auth/login",{email:signup.email,password:signup.password});

  const updated={profileCiphertext:Buffer.from("new-ciphertext").toString("base64"),profileNonce:Buffer.from("new-nonce-000001").toString("base64")};
  const withAuth=await fetch(ctx.base+"/auth/profile",{method:"PUT",
   headers:{"Content-Type":"application/json","Authorization":`Bearer ${login.body.sessionToken}`},
   body:JSON.stringify(updated)});
  assert.equal(withAuth.status,200);

  const relogin=await postJson(ctx.base,"/auth/login",{email:signup.email,password:signup.password});
  assert.equal(relogin.body.profileCiphertext,updated.profileCiphertext);
 }finally{ctx.close();}
});

test("logout revokes the session token",async()=>{
 const ctx=await startTestServer();
 try{
  const signup=validSignup();
  await postJson(ctx.base,"/auth/signup",signup);
  const code=ctx.sentEmails[0].text.match(/\d{6}/)[0];
  await postJson(ctx.base,"/auth/verify-email",{email:signup.email,code});
  const login=await postJson(ctx.base,"/auth/login",{email:signup.email,password:signup.password});

  const logout=await fetch(ctx.base+"/auth/logout",{method:"POST",headers:{"Authorization":`Bearer ${login.body.sessionToken}`}});
  assert.equal(logout.status,200);

  const afterLogout=await fetch(ctx.base+"/auth/profile",{method:"PUT",
   headers:{"Content-Type":"application/json","Authorization":`Bearer ${login.body.sessionToken}`},
   body:JSON.stringify({profileCiphertext:"AAAA",profileNonce:"AAAA"})});
  assert.equal(afterLogout.status,401);
 }finally{ctx.close();}
});

test("legacy report token routes are unaffected by /auth/*",async()=>{
 const ctx=await startTestServer();
 try{
  const health=await fetch(ctx.base+"/report/health",{headers:{"Authorization":`Bearer ${"t".repeat(32)}`}});
  assert.equal(health.status,200);
 }finally{ctx.close();}
});
