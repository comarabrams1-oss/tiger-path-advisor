// Local preview only. Serves build/web; private project files are never served.
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import handler from '../netlify/functions/advisor.mjs';
const project = path.resolve(import.meta.dirname, '..');
for (const line of fs.readFileSync(path.join(project, '.env'), 'utf8').split(/\r?\n/)) {
  if (!line.trim() || line.trim().startsWith('#') || !line.includes('=')) continue;
  const i = line.indexOf('=');
  process.env[line.slice(0, i).trim()] = line.slice(i + 1).trim().replace(/^(['"])(.*)\1$/, '$2');
}
const root = path.join(project, 'build/web');
const mime = {'.html':'text/html','.js':'text/javascript','.json':'application/json','.wasm':'application/wasm','.png':'image/png','.otf':'font/otf','.ttf':'font/ttf','.css':'text/css','.svg':'image/svg+xml'};
http.createServer(async (req, res) => {
  try {
    const url = new URL(req.url, 'http://127.0.0.1:8765');
    if (url.pathname === '/.netlify/functions/advisor') {
      let body = ''; for await (const chunk of req) { body += chunk; if (Buffer.byteLength(body) > 64000) {res.writeHead(413).end(); return;} }
      const response = await handler(new Request(url, {method:req.method,headers:req.headers,body: req.method === 'GET' ? undefined : body}));
      res.writeHead(response.status, Object.fromEntries(response.headers)); res.end(await response.text()); return;
    }
    if (req.method !== 'GET') { res.writeHead(405).end(); return; }
    const requested = path.resolve(root, '.' + decodeURIComponent(url.pathname));
    if (requested !== root && !requested.startsWith(root + path.sep)) {res.writeHead(403).end(); return;}
    const file = requested === root || url.pathname.endsWith('/') ? path.join(root, 'index.html') : requested;
    if (!fs.existsSync(file) || !fs.statSync(file).isFile()) {res.writeHead(404).end(); return;}
    res.writeHead(200, {'Content-Type':mime[path.extname(file)] || 'application/octet-stream','Cache-Control':'no-store'});
    fs.createReadStream(file).pipe(res);
  } catch { res.writeHead(500).end('Local preview error.'); }
}).listen(8765,'127.0.0.1',()=>console.log('Tiger Path preview: http://127.0.0.1:8765'));
