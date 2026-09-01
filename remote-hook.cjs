#!/usr/bin/env node
// EOF-tolerant variant of the hive's cth-hook shim, for hooks arriving over
// Win32-OpenSSH (which does not forward stdin EOF). Fires as soon as the
// accumulated stdin parses as JSON, or after a safety timeout, instead of
// waiting for 'end'. Same contract: env AGENT_ID + HIVE_SOCK, payload on
// stdin, server reply on stdout (Stop decisions), --status prints the gauge.
'use strict';
const net = require('net');
const isStatus = process.argv.includes('--status');
let data = '';
let fired = false;

function go(raw) {
  if (fired) return;
  fired = true;
  let payload = {};
  try { payload = JSON.parse(raw || '{}'); } catch (_) {}
  if (!payload.agent_id) payload.agent_id = process.env.AGENT_ID || null;
  const sock = process.env.HIVE_SOCK;
  if (isStatus) {
    payload.hook_event_name = 'Status';
    const cw = payload.context_window || {};
    const used = cw.total_input_tokens, size = cw.context_window_size;
    if (typeof used === 'number' && typeof size === 'number' && size > 0) {
      const pct = Math.round((used / size) * 100);
      process.stdout.write('ctx ' + Math.round(used / 1000) + 'k/' + Math.round(size / 1000) + 'k (' + pct + '%)');
    }
  }
  if (!sock) process.exit(0);
  const c = net.createConnection(sock, () => { c.end(JSON.stringify(payload) + '\n'); });
  let reply = '';
  c.on('data', (d) => { reply += d; });
  c.on('error', () => process.exit(0));
  c.on('close', () => {
    if (!isStatus && reply) process.stdout.write(reply);
    process.exit(0);
  });
}

process.stdin.setEncoding('utf8');
process.stdin.on('data', (d) => {
  data += d;
  try { JSON.parse(data); go(data); } catch (_) { /* incomplete JSON - keep reading */ }
});
process.stdin.on('end', () => go(data));
process.stdin.on('error', () => go(data));
setTimeout(() => go(data), 5000);
