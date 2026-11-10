// 解析浏览器/抓包工具导出的 HAR，产出接口清单。
// 用法: node tools/analyze_har.mjs capture/xxx.har [out.md]
import { readFileSync, writeFileSync } from 'node:fs';

const [, , harPath, outPath = 'docs/har-report.md'] = process.argv;
if (!harPath) {
  console.error('usage: node tools/analyze_har.mjs <file.har> [out.md]');
  process.exit(2);
}

const har = JSON.parse(readFileSync(harPath, 'utf8'));
const entries = har?.log?.entries ?? [];
console.log(`entries: ${entries.length}`);

const interesting = entries.filter((e) => {
  const url = e.request?.url ?? '';
  const mime = e.response?.content?.mimeType ?? '';
  if (/\.(png|jpe?g|gif|svg|woff2?|ttf|ico|css|map)(\?|$)/i.test(url)) return false;
  if (/google-analytics|doubleclick|umeng|cnzz|sentry/i.test(url)) return false;
  return /json|javascript|html|text/i.test(mime) || /api|json|action|service/i.test(url);
});

function short(s, n = 600) {
  if (!s) return '';
  const t = String(s).replace(/\s+/g, ' ').trim();
  return t.length > n ? t.slice(0, n) + ' …' : t;
}

function hostOf(url) {
  try {
    return new URL(url).host;
  } catch {
    return '?';
  }
}

const byHost = new Map();
for (const e of interesting) {
  const host = hostOf(e.request.url);
  if (!byHost.has(host)) byHost.set(host, []);
  byHost.get(host).push(e);
}

const lines = [];
lines.push('# HAR 接口清单');
lines.push('');
lines.push(`源文件：\`${harPath}\``);
lines.push(`总请求 ${entries.length}，筛选后 ${interesting.length}`);
lines.push('');
lines.push('## 按域名分组');
lines.push('');
for (const [host, list] of [...byHost.entries()].sort((a, b) => b[1].length - a[1].length)) {
  lines.push(`- \`${host}\` — ${list.length} 条`);
}
lines.push('');

for (const [host, list] of [...byHost.entries()].sort((a, b) => b[1].length - a[1].length)) {
  lines.push(`## ${host}`);
  lines.push('');
  for (const e of list) {
    const req = e.request;
    const res = e.response;
    const url = req.url;
    const path = (() => {
      try {
        const u = new URL(url);
        return u.pathname + u.search;
      } catch {
        return url;
      }
    })();
    lines.push(`### ${req.method} ${path}`);
    lines.push('');
    lines.push(`- 状态：${res.status} ${res.statusText ?? ''}  (${res.content?.mimeType ?? '?'})`);
    lines.push(`- 时间：${e.startedDateTime}`);
    const reqHeaders = (req.headers ?? [])
      .filter((h) => /cookie|referer|origin|content-type|authorization|token|x-/i.test(h.name))
      .map((h) => `${h.name}: ${short(h.value, 200)}`);
    if (reqHeaders.length) lines.push(`- 请求头：\n${reqHeaders.map((h) => '  - ' + h).join('\n')}`);
    if (req.postData?.text) {
      lines.push(`- 请求体：\n\`\`\`\n${short(req.postData.text, 800)}\n\`\`\``);
    }
    if (res.content?.text) {
      lines.push(`- 响应（前 800 字）：\n\`\`\`\n${short(res.content.text, 800)}\n\`\`\``);
    }
    lines.push('');
  }
}

writeFileSync(outPath, lines.join('\n'), 'utf8');
console.log(`wrote ${outPath}`);

// 终端简要输出
for (const [host, list] of [...byHost.entries()].sort((a, b) => b[1].length - a[1].length)) {
  console.log(`\n${host} (${list.length})`);
  const seen = new Set();
  for (const e of list) {
    let key;
    try {
      const u = new URL(e.request.url);
      key = `${e.request.method} ${u.pathname}`;
    } catch {
      key = e.request.url;
    }
    if (seen.has(key)) continue;
    seen.add(key);
    console.log(`  ${key}  -> ${e.response.status}`);
  }
}
