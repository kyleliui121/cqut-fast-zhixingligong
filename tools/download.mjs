// 断点续传下载器：node tools/download.mjs <url> <dest>
import { createWriteStream, existsSync, mkdirSync, renameSync, statSync } from 'node:fs';
import { dirname } from 'node:path';

const [, , url, dest] = process.argv;
if (!url || !dest) {
  console.error('usage: node download.mjs <url> <dest>');
  process.exit(2);
}
mkdirSync(dirname(dest), { recursive: true });

const part = dest + '.part';
let start = 0;
if (existsSync(part)) start = statSync(part).size;

for (let attempt = 1; attempt <= 30; attempt++) {
  try {
    const headers = { 'User-Agent': 'Mozilla/5.0' };
    if (start > 0) headers['Range'] = `bytes=${start}-`;
    const res = await fetch(url, { headers, redirect: 'follow', signal: AbortSignal.timeout(10 * 60 * 1000) });
    if (!res.ok && res.status !== 206) {
      if (res.status === 416) { console.log('already complete'); break; }
      throw new Error(`HTTP ${res.status}`);
    }
    const total = Number(res.headers.get('content-length') || 0) + start;
    console.log(`[${attempt}] start at ${(start / 1048576).toFixed(1)}MB / ${(total / 1048576).toFixed(1)}MB`);
    const out = createWriteStream(part, { flags: start > 0 ? 'a' : 'w' });
    let written = start;
    let lastLog = Date.now();
    for await (const chunk of res.body) {
      if (!out.write(chunk)) await new Promise((r) => out.once('drain', r));
      written += chunk.length;
      if (Date.now() - lastLog > 5000) {
        lastLog = Date.now();
        console.log(`  ${(written / 1048576).toFixed(1)}MB / ${(total / 1048576).toFixed(1)}MB`);
      }
    }
    await new Promise((r) => out.end(r));
    if (total && written < total) throw new Error(`short read ${written}/${total}`);
    renameSync(part, dest);
    console.log(`DONE ${dest} ${(written / 1048576).toFixed(1)}MB`);
    process.exit(0);
  } catch (e) {
    console.log(`attempt ${attempt} failed: ${e.message}`);
    if (existsSync(part)) start = statSync(part).size;
    await new Promise((r) => setTimeout(r, 3000));
  }
}
console.log('FAILED');
process.exit(1);
