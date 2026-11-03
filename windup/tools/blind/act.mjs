// The game's controls. One command per run; prints where the new screenshot is.
//   node ./act.mjs look | click X Y | double_click X Y | hold X Y SECONDS |
//                  drag X1 Y1 X2 Y2 [SECONDS] | key NAME | hold_key NAME SECONDS |
//                  wait SECONDS | end
import http from 'node:http';
import fs from 'node:fs';
const port = Number(fs.readFileSync(new URL('./.port', import.meta.url), 'utf8').trim());
const [cmd, ...args] = process.argv.slice(2);
const req = http.request({ host: '127.0.0.1', port, method: 'POST', path: '/' }, (res) => {
  let out = '';
  res.on('data', (c) => { out += c; });
  res.on('end', () => console.log(out));
});
req.on('error', (e) => console.log(JSON.stringify({ error: 'the game is not reachable: ' + e.message })));
req.end(JSON.stringify({ cmd, args }));
