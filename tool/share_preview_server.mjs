// Temporary, password-protected public demo gateway. Never serves project files.
import http from 'node:http';
import fs from 'node:fs';
import crypto from 'node:crypto';
const file = process.env.TIGER_SHARE_CONFIG;
if (!file) throw new Error('Set TIGER_SHARE_CONFIG to a private JSON config file.');
const config = JSON.parse(fs.readFileSync(file, 'utf8'));
if (typeof config.accessCode !== 'string' || config.accessCode.length < 16) throw new Error('Use a random access code of at least 16 characters.');
const session = crypto.randomBytes(32).toString('hex');
let windowStart = Date.now(), calls = 0;
const page = `<!doctype html><html lang="en"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Tiger Path Advisor preview</title><style>body{font:17px system-ui;background:#121117;color:#fff;display:grid;place-items:center;min-height:90vh;margin:20px}main{max-width:420px;padding:32px;background:#24212d;border-radius:20px}input,button{box-sizing:border-box;width:100%;padding:14px;margin-top:14px;border-radius:10px;border:1px solid #aaa;font:inherit}button{background:#bca2ed;color:#151020;cursor:pointer}p{line-height:1.5;color:#ded8e8}</style><main><h1>Tiger Path Advisor</h1><p>Private test preview. Enter the access code shared with your invitation.</p><form method="post" action="/preview-access"><label for="code">Preview access code</label><input id="code" name="code" type="password" required autocomplete="off"><button>Open preview</button></form><p>Use fictional student profiles. This is not Tiger Portal.</p></main></html>`;
http.createServer(async (req,res) => {
  res.setHeader('Cache-Control','no-store');res.setHeader('X-Robots-Tag','noindex, nofollow');
  res.setHeader('X-Content-Type-Options','nosniff');
  const url = new URL(req.url,'http://127.0.0.1');
  const authorized = (req.headers.cookie || '').split(';').some(c=>c.trim() === `tiger_preview=${session}`);
  if(url.pathname === '/preview-access' && req.method === 'POST') {
    let body='';for await(const chunk of req){body+=chunk;if(Buffer.byteLength(body)>1024){res.writeHead(413).end();return;}}
    const code=new URLSearchParams(body).get('code') || '';
    const a=crypto.createHash('sha256').update(code).digest(),b=crypto.createHash('sha256').update(config.accessCode).digest();
    if(!crypto.timingSafeEqual(a,b)){res.writeHead(403,{'Content-Type':'text/html; charset=utf-8'}).end(page.replace('Private test preview.','Incorrect code. Please try again.'));return;}
    res.writeHead(303,{'Location':'/','Set-Cookie':`tiger_preview=${session}; HttpOnly; Secure; SameSite=Lax; Path=/; Max-Age=21600`}).end();return;
  }
  if(!authorized){res.writeHead(req.method==='GET'?200:401,{'Content-Type':'text/html; charset=utf-8'}).end(page);return;}
  const api=url.pathname === '/.netlify/functions/advisor';
  const decoded=decodeURIComponent(url.pathname);
  if (!api && (/(?:^|\/)\./.test(decoded) || /^\/(?:private_data|tool|lib|test)(?:\/|$)/.test(decoded))) {res.writeHead(403).end();return;}
  if(!['GET','HEAD'].includes(req.method) && !(api && req.method==='POST')){res.writeHead(405).end();return;}
  if(api && req.method==='POST') {
    if(Date.now()-windowStart>3600000){windowStart=Date.now();calls=0;}
    if(++calls>60){res.writeHead(429,{'Content-Type':'application/json'}).end(JSON.stringify({error:'The shared preview has reached its hourly AI request limit. Please try later.'}));return;}
  }
  let body; if(req.method==='POST'){const chunks=[];let size=0;for await(const c of req){size+=c.length;if(size>64000){res.writeHead(413).end();return;}chunks.push(c);}body=Buffer.concat(chunks);}
  try {
    const upstream=await fetch(`http://127.0.0.1:8765${url.pathname}${url.search}`,{
      method:req.method,headers:{'content-type':req.headers['content-type'] || 'application/json'},body,signal:AbortSignal.timeout(90000)});
    res.writeHead(upstream.status,{'Content-Type':upstream.headers.get('content-type') || 'application/octet-stream'});
    res.end(Buffer.from(await upstream.arrayBuffer()));
  }catch{res.writeHead(502).end('Preview temporarily unavailable.');}
}).listen(8766,'127.0.0.1',()=>console.log('Protected preview gateway ready on 127.0.0.1:8766'));
