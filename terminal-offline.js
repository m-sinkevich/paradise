/* =====================================================================
 *  Оффлайн-режим терминала модуля.
 *
 *  • Мастер заранее (пока есть интернет) жмёт «Выгрузить базу»: копия нужных таблиц ложится в IndexedDB,
 *    страница, библиотеки, шрифты и все картинки/видео/аудио контента — в кэш браузера (sw.js).
 *  • Все запросы supabase-js идут через Offline.fetch. Нет сети (или включён режим «только оффлайн») —
 *    ответ собирается из локальной копии: фильтры PostgREST (eq, in, is, or, ilike, order, limit…),
 *    вставки, обновления и функция spend_crystal выполняются локально.
 *  • Всё, что терминал записал без сети, копится в очереди и досылается, когда сеть появится
 *    (сама в режиме «авто» или кнопкой «Отправить накопленное»). Оплаты кристаллами досылаются через
 *    spend_crystal_offline (sql/offline.sql): если кристалл тем временем потратили на другом устройстве,
 *    оплата всё равно засчитывается, а в журнал пишется crystal_conflict.
 *  • Каналы связи, камера и угрозы от мастера без сети не работают — для них нужна связь между устройствами.
 * ===================================================================== */
(function () {
  'use strict';

  /* ---------- IndexedDB: одна таблица ключ → значение ---------- */
  const IDB = {
    db: null,
    open() {
      if (this.db) return Promise.resolve(this.db);
      return new Promise((res, rej) => {
        const r = indexedDB.open('tk_offline', 1);
        r.onupgradeneeded = () => r.result.createObjectStore('kv');
        r.onsuccess = () => { this.db = r.result; res(this.db); };
        r.onerror = () => rej(r.error);
      });
    },
    async get(k) {
      const db = await this.open();
      return new Promise((res, rej) => { const t = db.transaction('kv').objectStore('kv').get(k); t.onsuccess = () => res(t.result); t.onerror = () => rej(t.error); });
    },
    async set(k, v) {
      const db = await this.open();
      return new Promise((res, rej) => { const t = db.transaction('kv', 'readwrite'); t.objectStore('kv').put(v, k); t.oncomplete = () => res(); t.onerror = () => rej(t.error); });
    }
  };

  const ls = { get(k) { try { return localStorage.getItem(k); } catch (e) { return null; } }, set(k, v) { try { localStorage.setItem(k, v); } catch (e) {} } };
  const uuid = () => (window.crypto && crypto.randomUUID) ? crypto.randomUUID()
    : 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, c => { const r = Math.random() * 16 | 0; return (c === 'x' ? r : (r & 3 | 8)).toString(16); });

  // ключи строк для upsert (у остальных таблиц — id)
  const PK = {
    content_payments: ['character_id', 'content_id', 'variant'],
    character_progress: ['character_id', 'content_id'],
    threat_progress: ['alert_id', 'module_id', 'code']
  };
  // таблицы с колонкой id: при вставке без сети id генерируется здесь и уходит на сервер тем же
  const WITH_ID = new Set(['logs', 'journal_entries', 'alerts', 'modules', 'characters', 'content_items', 'crystals']);
  // связь между устройствами — без сети недоступна
  const NEEDS_NET = /^(comm_channels|comm_members|comm_messages|camera_requests)$/;
  // служебные отметки «я жив» — без сети применяются только локально, на сервер не досылаются
  const NO_QUEUE = new Set(['modules']);

  /* ---------- разбор запроса PostgREST ---------- */
  function splitTop(s, sep) {
    const out = []; let depth = 0, cur = '', q = false;
    for (const ch of s) {
      if (ch === '"') q = !q;
      if (!q && ch === '(') depth++;
      if (!q && ch === ')') depth--;
      if (!q && depth === 0 && ch === sep) { out.push(cur); cur = ''; continue; }
      cur += ch;
    }
    if (cur !== '') out.push(cur);
    return out;
  }
  function colGetter(col) {
    // params->>auto, params->a->>b
    const parts = col.split(/->>?/);
    if (parts.length === 1) return r => r[col];
    const asText = /->>[^>]*$/.test(col);
    return r => {
      let v = r[parts[0]];
      for (let i = 1; i < parts.length && v != null; i++) { if (typeof v === 'string') { try { v = JSON.parse(v); } catch (e) { return null; } } v = v[parts[i]]; }
      if (asText && v != null && typeof v === 'object') return JSON.stringify(v);
      return v;
    };
  }
  const isNum = v => typeof v === 'number' || (typeof v === 'string' && v.trim() !== '' && !isNaN(Number(v)));
  const ISO = /^\d{4}-\d\d-\d\d([T ]\d\d:\d\d(:\d\d(\.\d+)?)?)?(Z|[+-]\d\d(:?\d\d)?)?$/;
  function cmp(a, b) {
    if (a == null || b == null) return a == null && b == null ? 0 : (a == null ? 1 : -1);
    if (typeof a === 'boolean' || typeof b === 'boolean') return String(a) === String(b) ? 0 : (String(a) < String(b) ? -1 : 1);
    if (isNum(a) && isNum(b)) return Number(a) - Number(b);
    const sa = String(a), sb = String(b);
    if (ISO.test(sa) && ISO.test(sb)) return Date.parse(sa) - Date.parse(sb);
    return sa < sb ? -1 : sa > sb ? 1 : 0;
  }
  function eq(a, v) {
    if (a == null) return false;
    if (typeof a === 'boolean') return String(a) === v;
    if (typeof a === 'object') return JSON.stringify(a) === v;
    if (isNum(a) && isNum(v)) return Number(a) === Number(v);
    const sa = String(a);
    if (ISO.test(sa) && ISO.test(v)) return Date.parse(sa) === Date.parse(v);
    return sa === v;
  }
  function unquote(s) { s = s.trim(); return s.length > 1 && s[0] === '"' && s[s.length - 1] === '"' ? s.slice(1, -1).replace(/\\"/g, '"') : s; }
  function likeRe(p, ci) { return new RegExp('^' + p.replace(/[.+?^${}()|[\]\\]/g, '\\$&').replace(/[%*]/g, '.*').replace(/_/g, '.') + '$', ci ? 'is' : 's'); }
  function makeCond(col, expr) {
    let not = false;
    if (expr.startsWith('not.')) { not = true; expr = expr.slice(4); }
    const dot = expr.indexOf('.');
    const op = dot < 0 ? expr : expr.slice(0, dot), val = dot < 0 ? '' : expr.slice(dot + 1);
    const g = colGetter(col);
    let f;
    switch (op) {
      case 'eq': f = r => eq(g(r), val); break;
      case 'neq': f = r => g(r) != null && !eq(g(r), val); break;
      case 'gt': f = r => g(r) != null && cmp(g(r), val) > 0; break;
      case 'gte': f = r => g(r) != null && cmp(g(r), val) >= 0; break;
      case 'lt': f = r => g(r) != null && cmp(g(r), val) < 0; break;
      case 'lte': f = r => g(r) != null && cmp(g(r), val) <= 0; break;
      case 'like': { const re = likeRe(val, false); f = r => g(r) != null && re.test(String(g(r))); break; }
      case 'ilike': { const re = likeRe(val, true); f = r => g(r) != null && re.test(String(g(r))); break; }
      case 'is': {
        const v = val.toLowerCase();
        f = v === 'null' ? (r => g(r) == null) : v === 'true' ? (r => g(r) === true) : v === 'false' ? (r => g(r) === false) : (r => g(r) == null);
        break;
      }
      case 'in': {
        const list = splitTop(val.replace(/^\(|\)$/g, ''), ',').map(unquote);
        f = r => g(r) != null && list.some(x => eq(g(r), x)); break;
      }
      case 'cs': {   // массив содержит: {a,b}
        const list = val.replace(/^\{|\}$/g, '').split(',').map(unquote).filter(Boolean);
        f = r => Array.isArray(g(r)) && list.every(x => g(r).map(String).includes(x)); break;
      }
      case 'ov': {
        const list = val.replace(/^[{(]|[)}]$/g, '').split(',').map(unquote).filter(Boolean);
        f = r => Array.isArray(g(r)) && list.some(x => g(r).map(String).includes(x)); break;
      }
      default: f = () => true;
    }
    return not ? (r => !f(r)) : f;
  }
  function logicCond(kind, val) {   // or=(a.eq.1,b.is.null), and=(...)
    const items = splitTop(val.replace(/^\(|\)$/g, ''), ',').map(s => s.trim()).filter(Boolean).map(it => {
      const m = /^(not\.)?(or|and)\((.*)\)$/.exec(it);
      if (m) { const c = logicCond(m[2], '(' + m[3] + ')'); return m[1] ? (r => !c(r)) : c; }
      const d = it.indexOf('.');
      return makeCond(it.slice(0, d), it.slice(d + 1));
    });
    return kind === 'or' ? (r => items.some(f => f(r))) : (r => items.every(f => f(r)));
  }
  function parseQuery(sp) {
    const q = { select: '*', filters: [], order: [], limit: null, offset: 0 };
    for (const [k, v] of sp.entries()) {
      if (k === 'select') q.select = v;
      else if (k === 'order') q.order = splitTop(v, ',').map(s => { const p = s.split('.'); return { col: p[0], desc: p.includes('desc'), nullsfirst: p.includes('nullsfirst') }; });
      else if (k === 'limit') q.limit = Number(v);
      else if (k === 'offset') q.offset = Number(v);
      else if (k === 'on_conflict' || k === 'columns') continue;
      else if (k === 'or' || k === 'and') q.filters.push(logicCond(k, v));
      else if (/^not\.(or|and)$/.test(k)) { const c = logicCond(k.slice(4), v); q.filters.push(r => !c(r)); }
      else if (k.includes('.')) continue;   // фильтры встроенных таблиц не поддерживаем
      else q.filters.push(makeCond(k, v));
    }
    return q;
  }

  /* ---------- локальная копия ---------- */
  const Offline = window.Offline = {
    base: '', key: '',
    snap: null,          // { at, code, moduleId, tables: { name: [rows] } }
    queue: [],           // [{ method, path, body, prefer, at }]
    failed: [],          // что сервер не принял при досылке
    mode: 'auto',        // auto — сеть, при обрыве локально; offline — только локально
    net: null,           // последняя известная доступность сети
    downUntil: 0,
    pushing: false,
    ready: Promise.resolve(),
    listeners: [],

    init(base, key) {
      this.base = String(base).replace(/\/+$/, ''); this.key = key;
      this.mode = ls.get('tk_off_mode') === 'offline' ? 'offline' : 'auto';
      this.ready = (async () => {
        try {
          this.snap = (await IDB.get('snap')) || null;
          this.queue = (await IDB.get('queue')) || [];
          this.failed = (await IDB.get('failed')) || [];
        } catch (e) { console.warn('[offline] IndexedDB', e); }
        this.emit();
      })();
      if ('serviceWorker' in navigator && (location.protocol === 'https:' || location.hostname === 'localhost' || location.hostname === '127.0.0.1')) {
        navigator.serviceWorker.register('sw.js').catch(e => console.warn('[offline] sw', e));
      }
      window.addEventListener('online', () => { this.downUntil = 0; if (this.mode === 'auto') setTimeout(() => this.push(), 1500); });
      return this;
    },
    on(fn) { this.listeners.push(fn); },
    emit() { this.listeners.forEach(fn => { try { fn(this); } catch (e) {} }); },
    setMode(m) { this.mode = m === 'offline' ? 'offline' : 'auto'; ls.set('tk_off_mode', this.mode); this.downUntil = 0; this.emit(); },
    isLocal() { return !!this.snap && (this.mode === 'offline' || this.net === false); },
    table(name) { const t = this.snap.tables; return t[name] || (t[name] = []); },
    saveSnapSoon() {
      clearTimeout(this._st);
      this._st = setTimeout(() => IDB.set('snap', this.snap).catch(e => console.warn('[offline] save', e)), 800);
    },
    async saveQueue() { try { await IDB.set('queue', this.queue); await IDB.set('failed', this.failed.slice(-200)); } catch (e) { console.warn('[offline] queue', e); } this.emit(); },
    enqueue(item) { item.at = new Date().toISOString(); this.queue.push(item); this.saveQueue(); },
    hdr(extra) { return Object.assign({ apikey: this.key, Authorization: 'Bearer ' + this.key }, extra || {}); },

    /* ---------- fetch для supabase-js ---------- */
    async fetch(input, init) {
      const url = typeof input === 'string' ? input : (input && input.url) || String(input);
      if (!url.startsWith(Offline.base)) return fetch(input, init);
      await Offline.ready;
      const u = new URL(url);
      const isRest = u.pathname.startsWith('/rest/v1/');
      const method = String((init && init.method) || 'GET').toUpperCase();
      const canLocal = isRest && !!Offline.snap;
      if (!(canLocal && Offline.mode === 'offline') && !(canLocal && Date.now() < Offline.downUntil)) {
        try {
          const res = await Offline.timed(input, init, canLocal ? 7000 : 20000);
          Offline.setNet(true);
          if (canLocal && res.ok) Offline.mirror(u, method, init, res.clone()).catch(() => {});
          if (Offline.queue.length && !Offline.pushing && Offline.mode === 'auto') setTimeout(() => Offline.push(), 300);
          return res;
        } catch (e) {
          if (init && init.signal && init.signal.aborted) throw e;
          Offline.setNet(false);
          Offline.downUntil = Date.now() + 20000;
          if (!canLocal) throw e;
        }
      }
      if (!canLocal) throw new TypeError('Нет сети');
      try { return Offline.local(u, method, init); }
      catch (e) { console.warn('[offline] local', e); return Offline.err(500, 'Оффлайн: ' + e.message); }
    },
    timed(input, init, ms) {
      const ctl = new AbortController();
      const outer = init && init.signal;
      if (outer) outer.addEventListener('abort', () => ctl.abort());
      const t = setTimeout(() => ctl.abort(), ms);
      return fetch(input, Object.assign({}, init, { signal: ctl.signal })).finally(() => clearTimeout(t));
    },
    setNet(v) { if (this.net !== v) { this.net = v; this.emit(); } },

    /* ---------- ответы ---------- */
    json(data, status, extra) {
      return new Response(data === undefined ? '' : JSON.stringify(data), { status: status || 200, headers: Object.assign({ 'Content-Type': 'application/json' }, extra || {}) });
    },
    empty(status) { return new Response(null, { status: status || 204 }); },
    err(status, msg, code) { return this.json({ message: msg, code: code || 'OFFLINE', details: null, hint: null }, status); },
    respond(rows, headers, status) {
      const acc = headers.get('Accept') || '';
      if (acc.includes('vnd.pgrst.object')) {
        if (rows.length !== 1) return this.json({ code: 'PGRST116', details: `Results contain ${rows.length} rows`, hint: null, message: 'JSON object requested, multiple (or no) rows returned' }, 406);
        return this.json(rows[0], status || 200);
      }
      return this.json(rows, status || 200, { 'Content-Range': `0-${Math.max(rows.length - 1, 0)}/${rows.length}` });
    },

    /* ---------- выборка ---------- */
    project(row, select) {
      if (!select || select.trim() === '*') return Object.assign({}, row);
      const out = {};
      for (let item of splitTop(select, ',')) {
        item = item.trim(); if (!item) continue;
        if (item === '*') { Object.assign(out, row); continue; }
        const m = /^(?:([\w]+):)?([\w]+)(?:!\w+)?\((.*)\)$/s.exec(item);
        if (m) {   // встроенная таблица: characters(name) по character_id
          const rel = m[2], alias = m[1] || rel;
          const fk = rel.replace(/ies$/, 'y').replace(/s$/, '') + '_id';
          const t = this.snap.tables[rel] || [];
          const target = row[fk] != null ? t.find(x => String(x.id) === String(row[fk])) : null;
          out[alias] = target ? this.project(target, m[3]) : null;
          continue;
        }
        const a = /^(?:([\w]+):)?(.+?)(?:::\w+)?$/.exec(item);
        const col = a[2], alias = a[1] || col.split(/->>?/).pop();
        out[alias] = colGetter(col)(row);
      }
      return out;
    },
    select(table, sp) {
      const q = parseQuery(sp);
      let rows = this.table(table).filter(r => q.filters.every(f => f(r)));
      if (q.order.length) rows = rows.slice().sort((a, b) => {
        for (const o of q.order) {
          const g = colGetter(o.col), x = g(a), y = g(b);
          if (x == null || y == null) { if (x == null && y == null) continue; const n = (x == null ? 1 : -1) * (o.nullsfirst ? -1 : 1); return o.desc ? -n : n; }
          const c = cmp(x, y); if (c) return o.desc ? -c : c;
        }
        return 0;
      });
      if (q.offset) rows = rows.slice(q.offset);
      if (q.limit != null) rows = rows.slice(0, q.limit);
      return { rows, q };
    },
    keyOf(table, r, cols) { return (cols || PK[table] || ['id']).map(c => String(r[c] == null ? (c === 'variant' ? '' : '') : r[c])).join('|'); },

    /* ---------- запрос без сети ---------- */
    local(u, method, init) {
      const headers = new Headers((init && init.headers) || {});
      let body = null;
      if (init && init.body != null && typeof init.body === 'string' && init.body !== '') { try { body = JSON.parse(init.body); } catch (e) { body = null; } }
      const path = decodeURIComponent(u.pathname.slice('/rest/v1/'.length));
      if (path.startsWith('rpc/')) return this.localRpc(path.slice(4), body || {});
      const table = path;
      if (NEEDS_NET.test(table)) {
        if (method === 'GET' || method === 'HEAD') return this.respond([], headers);
        return this.err(503, 'Нет связи: каналы связи и камера работают только при подключении к сети');
      }
      const prefer = headers.get('Prefer') || '';
      const wantRows = /return=representation/.test(prefer);
      if (method === 'GET' || method === 'HEAD') {
        const { rows, q } = this.select(table, u.searchParams);
        return this.respond(rows.map(r => this.project(r, q.select)), headers);
      }
      const changed = this.applyWrite(table, method, u.searchParams, body, prefer);
      if (!NO_QUEUE.has(table)) this.enqueue({ method, path: u.pathname + u.search, body: changed.sent, prefer: prefer.replace(/return=representation/, 'return=minimal') || 'return=minimal' });
      this.saveSnapSoon();
      if (!wantRows) return this.empty(method === 'POST' ? 201 : 204);
      const sel = u.searchParams.get('select') || '*';
      return this.respond(changed.rows.map(r => this.project(r, sel)), headers, method === 'POST' ? 201 : 200);
    },
    // применить вставку/обновление/удаление к локальной копии (и при работе без сети, и в зеркале онлайн-запросов)
    applyWrite(table, method, sp, body, prefer, online) {
      const rows = this.table(table);
      const out = { rows: [], sent: body };
      if (method === 'POST') {
        const list = Array.isArray(body) ? body : (body ? [body] : []);
        const conflict = (sp.get('on_conflict') || '').split(',').map(s => s.trim()).filter(Boolean);
        const upsert = /resolution=(merge|ignore)-duplicates/.test(prefer || '') || conflict.length > 0;
        const ignore = /ignore-duplicates/.test(prefer || '');
        const keyCols = conflict.length ? conflict : (PK[table] || ['id']);
        const sent = [];
        for (const r0 of list) {
          const s = Object.assign({}, r0);
          if (!online && WITH_ID.has(table) && s.id == null && !PK[table]) s.id = uuid();
          sent.push(s);
          const l = Object.assign({}, s);
          const now = new Date().toISOString();
          if (l.created_at == null) l.created_at = now;
          if (table === 'logs' && l.timestamp == null) l.timestamp = now;
          if (table === 'content_payments' && l.variant == null) l.variant = '';
          const k = this.keyOf(table, l, keyCols);
          const ex = (upsert || l.id != null) ? rows.find(x => this.keyOf(table, x, keyCols) === k) : null;
          if (ex) { if (!ignore) Object.assign(ex, s); out.rows.push(ex); }
          else { rows.push(l); out.rows.push(l); }
        }
        out.sent = Array.isArray(body) ? sent : sent[0];
      } else if (method === 'PATCH') {
        const q = parseQuery(sp);
        rows.forEach(r => { if (q.filters.every(f => f(r))) { Object.assign(r, body || {}); out.rows.push(r); } });
      } else if (method === 'DELETE') {
        const q = parseQuery(sp);
        for (let i = rows.length - 1; i >= 0; i--) if (q.filters.every(f => f(rows[i]))) out.rows.push(rows.splice(i, 1)[0]);
      }
      return out;
    },

    /* ---------- функции базы без сети ---------- */
    price(contentId, variant) {
      const it = this.table('content_items').find(x => x.id === contentId);
      if (!it) return 0;
      if (!variant) return Number(it.price) || 0;
      const v = (Array.isArray(it.variants) ? it.variants : []).find(x => x && x.id === variant);
      return v && v.price !== '' && v.price != null ? (Number(v.price) || 0) : 0;
    },
    localRpc(fn, b) {
      if (fn === 'content_price') return this.json(this.price(b.p_content, b.p_variant || ''));
      if (fn === 'spend_crystal') {
        const variant = b.p_variant || '';
        const price = this.price(b.p_content, variant);
        const pays = this.table('content_payments');
        let pay = pays.find(p => p.character_id === b.p_character && p.content_id === b.p_content && (p.variant || '') === variant);
        if ((pay && pay.completed_at) || price <= 0) return this.json({ result: 'already_paid', paid: pay ? pay.paid : 0, price, completed: true });
        const code = String(b.p_code || '').trim().toUpperCase();
        const cr = this.table('crystals').find(c => String(c.code || '').toUpperCase() === code);
        if (!cr) return this.json({ result: 'unknown', paid: pay ? pay.paid : 0, price, completed: false });
        if (cr.spent_at) return this.json({ result: 'spent', paid: pay ? pay.paid : 0, price, completed: false });
        const now = new Date().toISOString();
        Object.assign(cr, { spent_at: now, spent_by: b.p_character, spent_for: b.p_content, spent_variant: variant, spent_module: b.p_module || null, spent_source: (b.p_source || 'terminal') + ' · оффлайн' });
        if (!pay) { pay = { character_id: b.p_character, content_id: b.p_content, variant, paid: 0, completed_at: null }; pays.push(pay); }
        pay.paid = (Number(pay.paid) || 0) + 1; pay.updated_at = now;
        if (pay.paid >= price) pay.completed_at = now;
        this.enqueue({ method: 'POST', path: '/rest/v1/rpc/spend_crystal_offline', body: Object.assign({}, b, { p_at: now }), prefer: '', rpc: true });
        this.saveSnapSoon();
        return this.json({ result: 'ok', paid: pay.paid, price, completed: pay.paid >= price });
      }
      if (fn === 'create_channel_paid') return this.err(503, 'Нет связи: канал можно создать только при подключении к сети');
      return this.err(503, 'Нет связи: функция ' + fn + ' недоступна без сети');
    },

    /* ---------- зеркало: удачные онлайн-ответы обновляют локальную копию ---------- */
    async mirror(u, method, init, res) {
      const path = decodeURIComponent(u.pathname.slice('/rest/v1/'.length));
      if (path.startsWith('rpc/')) {
        if (path === 'rpc/spend_crystal') {
          let b = {}; try { b = JSON.parse(init.body); } catch (e) {}
          const r = await res.json().catch(() => null);
          if (!r || (r.result !== 'ok' && r.result !== 'already_paid')) return;
          const code = String(b.p_code || '').trim().toUpperCase();
          const cr = this.table('crystals').find(c => String(c.code || '').toUpperCase() === code);
          if (cr && r.result === 'ok') cr.spent_at = cr.spent_at || new Date().toISOString();
          const pays = this.table('content_payments'), variant = b.p_variant || '';
          let pay = pays.find(p => p.character_id === b.p_character && p.content_id === b.p_content && (p.variant || '') === variant);
          if (!pay) { pay = { character_id: b.p_character, content_id: b.p_content, variant, paid: 0 }; pays.push(pay); }
          pay.paid = r.paid; if (r.completed) pay.completed_at = pay.completed_at || new Date().toISOString();
          this.saveSnapSoon();
        }
        return;
      }
      if (NEEDS_NET.test(path)) return;
      const tables = this.snap.tables;
      if (method === 'GET') {
        if (!tables[path]) return;
        const sel = (u.searchParams.get('select') || '*').replace(/\s/g, '');
        if (!(sel === '*' || /^\*,/.test(sel))) return;     // только полные строки
        let data = await res.json().catch(() => null);
        if (data == null) return;
        if (!Array.isArray(data)) data = [data];
        const rows = this.table(path);
        for (const r of data) {
          if (!r || typeof r !== 'object') continue;
          const clean = {}; for (const k in r) if (!(r[k] && typeof r[k] === 'object' && !Array.isArray(r[k]) && tables[k])) clean[k] = r[k];
          const k = this.keyOf(path, clean);
          const ex = rows.find(x => this.keyOf(path, x) === k);
          if (ex) Object.assign(ex, clean); else rows.push(clean);
        }
        this.saveSnapSoon();
        return;
      }
      let body = null; try { body = init && init.body ? JSON.parse(init.body) : null; } catch (e) {}
      this.applyWrite(path, method, u.searchParams, body, new Headers((init && init.headers) || {}).get('Prefer') || '', true);
      this.saveSnapSoon();
    },

    /* ---------- досылка накопленного ---------- */
    async push() {
      if (this.pushing || !this.queue.length) return { sent: 0, failed: 0, left: this.queue.length };
      this.pushing = true; this.emit();
      let sent = 0, failed = 0, netErr = null;
      try {
        while (this.queue.length) {
          const q = this.queue[0];
          let res;
          try {
            res = await this.timed(this.base + q.path, {
              method: q.method,
              headers: this.hdr({ 'Content-Type': 'application/json', Prefer: q.prefer || 'return=minimal' }),
              body: q.body != null ? JSON.stringify(q.body) : undefined
            }, 20000);
          } catch (e) { netErr = e; break; }
          if (res.status >= 500) { netErr = new Error('сервер ' + res.status); break; }
          if (!res.ok && res.status !== 409) {
            const txt = await res.text().catch(() => '');
            this.failed.push(Object.assign({}, q, { status: res.status, error: txt.slice(0, 300) }));
            failed++;
          } else if (q.rpc) {
            const r = await res.json().catch(() => null);
            if (r && r.result === 'conflict') console.warn('[offline] кристалл уже был потрачен на другом устройстве', q.body && q.body.p_code);
          }
          this.queue.shift(); sent++;
          await this.saveQueue();
        }
        if (!netErr) this.setNet(true);
      } finally { this.pushing = false; this.emit(); }
      if (netErr) { this.setNet(false); throw netErr; }
      return { sent, failed, left: this.queue.length };
    },

    /* ---------- выгрузка базы ---------- */
    async download(moduleCode, progress) {
      const say = t => { try { progress && progress(t); } catch (e) {} };
      if (this.queue.length) { say('Отправляю накопленное…'); await this.push(); }
      const H = this.hdr();
      const getAll = async (q, optional) => {
        const all = [];
        for (let off = 0; ; off += 1000) {
          const r = await this.timed(`${this.base}/rest/v1/${q}${q.includes('?') ? '&' : '?'}limit=1000&offset=${off}`, { headers: H, cache: 'no-store' }, 30000);
          if (!r.ok) { if (optional) return []; throw new Error(q.split('?')[0] + ': HTTP ' + r.status + ' ' + (await r.text()).slice(0, 120)); }
          const a = await r.json(); all.push(...a);
          if (a.length < 1000 || /[?&]limit=/.test(q)) break;
        }
        return all;
      };
      say('Модули и персонажи…');
      const modules = await getAll('modules?select=*');
      const me = modules.find(m => String(m.access_code || '').toUpperCase() === String(moduleCode || '').toUpperCase());
      if (!me) throw new Error('модуль с кодом ' + moduleCode + ' не найден');
      const tables = { modules };
      tables.characters = await getAll('characters?select=*');
      say('Контент…');
      tables.content_items = await getAll('content_items?select=*');
      say('Оплаты, прогресс, кристаллы…');
      tables.content_payments = await getAll('content_payments?select=*', true);
      tables.character_progress = await getAll('character_progress?select=*', true);
      tables.crystals = await getAll('crystals?select=*', true);
      say('Угрозы и журнал…');
      tables.alerts = await getAll('alerts?select=*&active=eq.true', true);
      tables.threat_progress = await getAll('threat_progress?select=*&module_id=eq.' + me.id, true);
      tables.journal_entries = await getAll('journal_entries?select=*&module_id=eq.' + me.id, true);
      tables.logs = await getAll('logs?select=*&module_id=eq.' + me.id + '&order=timestamp.desc&limit=300', true);
      this.snap = { at: Date.now(), code: me.access_code, moduleId: me.id, moduleName: me.name, tables };
      await IDB.set('snap', this.snap);
      this.emit();

      // файлы: страница, библиотеки, шрифты, медиа контента и журнала
      const urls = new Set();
      const add = x => { if (!x || typeof x !== 'string') return; try { const v = new URL(x, location.href); if (/^https?:$/.test(v.protocol) && !v.pathname.includes('/rest/v1/') && !v.pathname.includes('/realtime/')) urls.add(v.href); } catch (e) {} };
      add(location.href); add(location.pathname); add('sw.js'); add('terminal-offline.js');
      document.querySelectorAll('script[src]').forEach(s => add(s.src));
      document.querySelectorAll('link[rel="stylesheet"][href]').forEach(l => add(l.href));
      (performance.getEntriesByType('resource') || []).forEach(e => add(e.name));
      const pub = p => `${this.base}/storage/v1/object/public/${window.MEDIA_BUCKET_NAME || 'content-media'}/${String(p).replace(/^\/+/, '')}`;
      const walk = (v, key) => {
        if (v == null) return;
        if (typeof v === 'string') {
          if (/^https?:\/\//.test(v) && (/\.(png|jpe?g|gif|webp|svg|mp4|webm|mov|m4v|ogg|ogv|mp3|wav|m4a|aac|opus|pdf)(\?|$)/i.test(v) || v.includes('/storage/v1/object/'))) add(v);
          else if (key && /(^|_)(media_path|path|file_path|audio_path|video_path|image_path|photo_path)$/.test(key) && /\.\w{2,5}$/.test(v) && !/^https?:/.test(v)) add(pub(v));
          else if (/^(media|catalog|badges|alien|map)\/[^\s]+\.\w{2,5}$/.test(v)) add(v);
          return;
        }
        if (Array.isArray(v)) return v.forEach(x => walk(x, key));
        if (typeof v === 'object') for (const k in v) walk(v[k], k);
      };
      tables.content_items.forEach(r => walk(r));
      tables.journal_entries.forEach(r => walk(r));
      // шрифты из CSS Google Fonts
      for (const href of [...urls].filter(x => x.includes('fonts.googleapis.com'))) {
        try { const css = await (await fetch(href)).text(); (css.match(/url\(([^)]+)\)/g) || []).forEach(m => add(m.slice(4, -1).replace(/["']/g, ''))); } catch (e) {}
      }
      // библиотека распознавания кодов (wasm)
      try { if (window.ZXingWASM) await ZXingWASM.prepareZXingModule({ fireImmediately: true }); } catch (e) {}
      (performance.getEntriesByType('resource') || []).forEach(e => { if (/\.wasm(\?|$)/.test(e.name)) add(e.name); });

      const list = [...urls];
      const cache = await caches.open('tk-files-v1');
      let ok = 0, bad = [];
      for (let i = 0; i < list.length; i++) {
        const x = list[i];
        say(`Файлы ${i + 1}/${list.length}…`);
        try {
          const same = new URL(x).origin === location.origin;
          const cors = same || x.startsWith(this.base) || /jsdelivr|cdnjs|unpkg|gstatic|googleapis/.test(x);
          let r;
          try { r = await this.timed(x, { mode: cors ? 'cors' : 'no-cors', cache: 'reload', credentials: 'omit' }, 120000); }
          catch (e) { if (!cors) throw e; r = await this.timed(x, { mode: 'no-cors', cache: 'reload', credentials: 'omit' }, 120000); }
          if (r.ok || r.type === 'opaque') { await cache.put(x, r); ok++; } else bad.push(x + ' (' + r.status + ')');
        } catch (e) { bad.push(x + ' (' + (e.message || e) + ')'); }
      }
      // страница терминала — по адресу без параметров тоже
      try { const pg = location.origin + location.pathname; if (!urls.has(pg)) { const r = await fetch(pg, { cache: 'reload' }); if (r.ok) await cache.put(pg, r); } } catch (e) {}
      this.snap.files = { ok, bad: bad.slice(0, 50), total: list.length };
      await IDB.set('snap', this.snap);
      this.setNet(true);
      this.emit();
      return { tables: Object.fromEntries(Object.entries(tables).map(([k, v]) => [k, v.length])), files: this.snap.files };
    },

    summary() {
      const s = this.snap;
      return {
        hasSnap: !!s, at: s ? s.at : null, module: s ? (s.moduleName || s.code) : null,
        counts: s ? Object.fromEntries(Object.entries(s.tables).map(([k, v]) => [k, v.length])) : {},
        files: s && s.files, queue: this.queue.length, failed: this.failed.length, mode: this.mode, net: this.net, local: this.isLocal()
      };
    }
  };
})();
