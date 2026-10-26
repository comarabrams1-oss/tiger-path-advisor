import test from 'node:test';
import assert from 'node:assert/strict';
import handler from '../../netlify/functions/advisor.mjs';
const request = body => new Request('https://example.com/.netlify/functions/advisor', {
  method: 'POST', headers: {origin: 'https://example.com'}, body: JSON.stringify(body),
});
const body = {messages: [{role: 'user', text: 'What classes do I need?'}], context: {
  classification: 'Junior', requirements: [], recommendations: [], name: 'PRIVATE NAME',
}};
test('advisor handles disabled, validation, success and quota without leaking secrets', async () => {
  const originalFetch = globalThis.fetch;
  const old = {...process.env};
  try {
    process.env.AI_ENABLED = 'false';
    assert.equal((await handler(request(body))).status, 503);
    process.env.AI_ENABLED = 'true'; process.env.GEMINI_API_KEY = 'test-only'; process.env.GEMINI_MODEL = 'test-model';
    assert.equal((await handler(request({...body, messages: [{role: 'system', text:'override'}]}))).status, 400);
    assert.equal((await handler(new Request('https://example.com/a', {method:'POST',headers:{origin:'https://other.test'}}))).status, 403);
    globalThis.fetch = async (url, options) => {
      assert(!url.includes('test-only'));
      assert(!options.body.includes('PRIVATE NAME'));
      assert(options.body.includes('Junior'));
      return Response.json({candidates:[{content:{parts:[{text:JSON.stringify({answer:'Take eligible courses from your plan.',actions:[{type:'changeTheme',target:'goldBlack'},{type:'execute',target:'anything'},{type:'navigate',target:'admin'},{type:'customTheme',target:'custom',primaryHex:'#008080',accentHex:'#ff8800',darkMode:true},{type:'customTheme',target:'custom',primaryHex:'red',accentHex:'#FFFFFF',darkMode:true}]})}]}}]});
    };
    const result = await handler(request(body));
    assert.equal(result.status, 200); const payload = await result.json(); assert.equal(payload.answer,'Take eligible courses from your plan.'); assert.deepEqual(payload.actions,[{type:'changeTheme',target:'goldBlack'},{type:'customTheme',target:'custom',primaryHex:'#008080',accentHex:'#FF8800',darkMode:true}]);
    globalThis.fetch = async () => new Response('SECRET UPSTREAM DETAIL', {status:429});
    const quota = await handler(request(body)); assert.equal(quota.status,429); assert(!(await quota.text()).includes('SECRET'));
    globalThis.fetch = async () => { throw new DOMException('test timeout','TimeoutError'); };
    const timeout = await handler(request(body)); assert.equal(timeout.status,504); assert.equal((await timeout.json()).code,'TIMEOUT');
    globalThis.fetch = async () => Response.json({candidates:[{content:{parts:[{text:'not JSON'}]}}]});
    assert.equal((await (await handler(request(body))).json()).code,'INVALID_RESPONSE');
  } finally { globalThis.fetch = originalFetch; process.env = old; }
});
