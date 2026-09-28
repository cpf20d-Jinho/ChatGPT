// Resend REST API, no SDK dependency (Node 20+ has native fetch).
export function createResendSender({apiKey,from,fetchImpl=fetch}){
 if(!apiKey||!from)throw Error("Configure RESEND_API_KEY and RESEND_FROM");
 return async function sendEmail({to,subject,text}){
  const r=await fetchImpl("https://api.resend.com/emails",{method:"POST",
   headers:{"Authorization":`Bearer ${apiKey}`,"Content-Type":"application/json"},
   body:JSON.stringify({from,to,subject,text}),
   signal:AbortSignal.timeout(10000)});
  if(!r.ok)throw Error("email_send_failed");
 };
}
