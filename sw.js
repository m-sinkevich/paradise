/* Кэш файлов для оффлайн-режима терминала (см. terminal-offline.js).
 * Страницы (.html) и свои скрипты — сначала из сети, без сети из кэша.
 * Библиотеки, шрифты, картинки, видео и аудио — сначала из кэша (их кладёт туда кнопка «Выгрузить базу»).
 * Запросы к базе (rest/v1) и realtime не трогаем: их обслуживает terminal-offline.js. */
const CACHE = 'tk-files-v1';

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', e => e.waitUntil(self.clients.claim()));

function timed(req, ms) {
  const ctl = new AbortController();
  const t = setTimeout(() => ctl.abort(), ms);
  return fetch(req, { signal: ctl.signal }).finally(() => clearTimeout(t));
}

// видео/аудио просят кусками (Range) — отдаём кусок из закэшированного целого файла
async function ranged(req, res) {
  const range = req.headers.get('range');
  if (!range || res.type === 'opaque' || res.status !== 200) return res;
  const m = /bytes=(\d*)-(\d*)/.exec(range);
  if (!m) return res;
  const buf = await res.arrayBuffer();
  const size = buf.byteLength;
  let start = m[1] === '' ? Math.max(0, size - Number(m[2])) : Number(m[1]);
  let end = m[1] !== '' && m[2] !== '' ? Math.min(Number(m[2]), size - 1) : size - 1;
  if (start >= size) return new Response(null, { status: 416, headers: { 'Content-Range': `bytes */${size}` } });
  return new Response(buf.slice(start, end + 1), {
    status: 206,
    headers: { 'Content-Type': res.headers.get('Content-Type') || 'application/octet-stream', 'Content-Range': `bytes ${start}-${end}/${size}`, 'Content-Length': String(end - start + 1), 'Accept-Ranges': 'bytes' }
  });
}

async function fromCache(req, nav) {
  const c = await caches.open(CACHE);
  let r = await c.match(req.url, { ignoreVary: true });
  if (!r && nav) r = await c.match(req.url, { ignoreSearch: true, ignoreVary: true });
  return r || null;
}

self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (!/^https?:$/.test(url.protocol)) return;
  if (url.pathname.includes('/rest/v1/') || url.pathname.includes('/realtime/') || url.pathname.includes('/auth/v1/')) return;
  const nav = req.mode === 'navigate';
  const own = url.origin === self.location.origin && (nav || /\.(html|js|json)$/.test(url.pathname) || url.pathname.endsWith('/'));

  if (own) {
    // сначала сеть (свежая версия), без сети — кэш
    e.respondWith((async () => {
      try {
        const r = await timed(req, 6000);
        if (r.ok && !req.headers.get('range')) { const c = await caches.open(CACHE); c.put(nav ? url.origin + url.pathname + url.search : req.url, r.clone()).catch(() => {}); }
        return r;
      } catch (err) {
        const r = await fromCache(req, nav);
        if (r) return r;
        throw err;
      }
    })());
    return;
  }

  // остальное — сначала кэш
  e.respondWith((async () => {
    const hit = await fromCache(req, false);
    if (hit) return ranged(req, hit);
    const r = await fetch(req);
    if ((r.ok && r.status === 200) && !req.headers.get('range') && /\.(woff2?|ttf|otf|wasm|css|js)(\?|$)|fonts\.g/.test(req.url)) {
      const c = await caches.open(CACHE); c.put(req.url, r.clone()).catch(() => {});
    }
    return r;
  })());
});
