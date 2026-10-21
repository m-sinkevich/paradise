/* =========================================================================
   КАРТА ПОЛИГОНА — общий компонент для терминала (показ) и терминала мастера
   (расстановка точек кликом). Схема по данным OpenStreetMap: купола, постройки,
   тропинки, грунтовки, дорога; кроны деревьев обведены по снимку; рельеф —
   горизонтали через 2 м и отмывка склона (Copernicus DEM 30 м).
   Данные: map/topo.json, map/hill.jpg, map/sat.jpg (снимок, подложен еле заметно).
   Подписей на карте нет — подписываются только точки угрозы.
   Координаты точек — в системе viewBox карты (W × H из topo.json), поле v: 2.
   ========================================================================= */
(function () {
  const NS = 'http://www.w3.org/2000/svg';
  const COLS = 'ABCDEFGHIJ', NC = 10, NR = 8;
  const BASE = (function () {
    const s = document.currentScript && document.currentScript.src;
    return s ? s.replace(/[^/]*$/, '') : 'map/';
  })();
  let DATA = null, loading = null;
  const load = () => DATA ? Promise.resolve(DATA) : (loading = loading || fetch(BASE + 'topo.json').then(r => r.json()).then(d => (DATA = d)));

  const TYPES = {
    danger:  { name: 'Опасность',   color: '#FF4D4D', shape: 'tri' },
    gather:  { name: 'Точка сбора', color: '#4ADE80', shape: 'circle' },
    shelter: { name: 'Укрытие',     color: '#38BDF8', shape: 'square' },
    target:  { name: 'Цель',        color: '#FFB454', shape: 'diamond' },
    info:    { name: 'Отметка',     color: '#E2E8F0', shape: 'hex' }
  };
  const C = { bg: '#06111e', canopy: '#1f4d5e', edge: '#86e6d2', shadow: '#01050b', cont: '#a9d2ee', path: '#e3f2ff', bld: '#EAF6FF', grid: '#5EEAD4' };

  const W = () => DATA ? DATA.W : 2192, H = () => DATA ? DATA.H : 2116;
  const sectorOf = (x, y) => COLS[Math.max(0, Math.min(NC - 1, Math.floor(x / (W() / NC))))] + (Math.max(0, Math.min(NR - 1, Math.floor(y / (H() / NR)))) + 1);
  // точки, поставленные на прежней версии карты (1000 × 922), переводим в новую систему
  function upgrade(p) {
    if (p.v === 2) return p;
    const x = 0.5719178 * p.x - 0.0020076 * p.y + 1104.4204, y = 0.0020076 * p.x + 0.5719178 * p.y + 1286.68;
    return Object.assign({}, p, { x: Math.round((x - 1113) * 4), y: Math.round((y - 1283) * 4), v: 2 });
  }

  function el(tag, attrs, parent) {
    const e = document.createElementNS(NS, tag);
    for (const k in attrs) e.setAttribute(k, attrs[k]);
    if (parent) parent.appendChild(e);
    return e;
  }
  const pl = pts => pts.map(p => p[0] + ',' + p[1]).join(' ');
  const esc = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

  // «облачный» контур кроны — дуги по периметру многоугольника
  function cloudPath(pts, step, hole) {
    const P = pts.concat([pts[0]]); const per = [];
    for (let i = 0; i < P.length - 1; i++) {
      const a = P[i], b = P[i + 1], L = Math.hypot(b[0] - a[0], b[1] - a[1]), n = Math.max(1, Math.round(L / step));
      for (let k = 0; k < n; k++) per.push([a[0] + (b[0] - a[0]) * k / n, a[1] + (b[1] - a[1]) * k / n]);
    }
    let area = 0;
    for (let i = 0; i < pts.length; i++) { const a = pts[i], b = pts[(i + 1) % pts.length]; area += a[0] * b[1] - b[0] * a[1]; }
    const sweep = ((area > 0) !== hole) ? 1 : 0;
    let d = 'M' + per[0][0].toFixed(1) + ',' + per[0][1].toFixed(1);
    for (let i = 1; i <= per.length; i++) {
      const q = per[i % per.length], r = (step * 0.62 * (0.85 + ((i * 7) % 5) / 12)).toFixed(1);
      d += `A${r},${r} 0 0,${sweep} ${q[0].toFixed(1)},${q[1].toFixed(1)}`;
    }
    return d + 'Z';
  }
  function shapePath(shape, r) {
    if (shape === 'tri') return `M0,${-r * 1.15} L${r},${r * 0.75} L${-r},${r * 0.75} Z`;
    if (shape === 'square') return `M${-r * .85},${-r * .85} H${r * .85} V${r * .85} H${-r * .85} Z`;
    if (shape === 'diamond') return `M0,${-r * 1.2} L${r * 1.2},0 L0,${r * 1.2} L${-r * 1.2},0 Z`;
    if (shape === 'hex') { let d = ''; for (let i = 0; i < 6; i++) { const a = Math.PI / 3 * i - Math.PI / 2; d += (i ? 'L' : 'M') + (r * Math.cos(a)).toFixed(1) + ',' + (r * Math.sin(a)).toFixed(1); } return d + 'Z'; }
    return `M${r},0 A${r},${r} 0 1,1 ${-r},0 A${r},${r} 0 1,1 ${r},0 Z`;
  }

  function drawBase(svg, D, uid, opts) {
    const defs = el('defs', {}, svg);
    defs.innerHTML = `
      <pattern id="${uid}-hatch" width="10" height="10" patternUnits="userSpaceOnUse" patternTransform="rotate(45)"><line x1="0" y1="0" x2="0" y2="10" stroke="${C.bld}" stroke-width="1.4" opacity=".5"/></pattern>
      <filter id="${uid}-soft"><feGaussianBlur stdDeviation="18"/></filter>
      <mask id="${uid}-out"><rect width="${D.W}" height="${D.H}" fill="#fff"/><polygon points="${pl(D.boundary)}" fill="#000" filter="url(#${uid}-soft)"/></mask>
      <filter id="${uid}-glow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="6" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>`;
    el('rect', { width: D.W, height: D.H, fill: C.bg }, svg);
    el('image', { href: BASE + 'hill.jpg', width: D.W, height: D.H, preserveAspectRatio: 'none', opacity: .32, style: 'mix-blend-mode:soft-light' }, svg);
    const sat = el('image', { href: BASE + 'sat.jpg', width: D.W, height: D.H, preserveAspectRatio: 'none', opacity: opts.satellite ? .55 : .14, style: 'mix-blend-mode:luminosity' }, svg);
    const contour = (op1, op2, w1, w2) => {
      const g = el('g', { fill: 'none', stroke: C.cont, 'stroke-linejoin': 'round' }, svg);
      D.contours.forEach(c => el('polyline', { points: pl(c.p), 'stroke-width': c.m ? w1 : w2, opacity: c.m ? op1 : op2 }, g));
    };
    contour(.7, .42, 3, 1.5);
    const gt = el('g', {}, svg);
    const outer = D.canopy.filter(c => !c.h), holes = D.canopy.filter(c => c.h);
    outer.forEach(c => el('path', { d: cloudPath(c.p, 16, false), fill: C.shadow, opacity: .55, transform: 'translate(7,9)' }, gt));
    outer.forEach(c => el('path', { d: cloudPath(c.p, 16, false), fill: C.canopy, 'fill-opacity': .93, stroke: C.edge, 'stroke-width': 2, 'stroke-opacity': .75 }, gt));
    holes.forEach(c => el('path', { d: cloudPath(c.p, 14, true), fill: C.bg, 'fill-opacity': .92, stroke: C.edge, 'stroke-width': 2, 'stroke-opacity': .75 }, gt));
    contour(.45, .22, 2.4, 1.2);
    const gp = el('g', { fill: 'none', 'stroke-linecap': 'round', 'stroke-linejoin': 'round' }, svg);
    const dbl = (list, w, inner) => { list.forEach(p => el('polyline', { points: pl(p), stroke: C.path, 'stroke-width': w }, gp)); list.forEach(p => el('polyline', { points: pl(p), stroke: C.bg, 'stroke-width': w - inner }, gp)); };
    dbl(D.roads, 26, 6); dbl(D.tracks, 17, 5); dbl(D.paths, 11, 4.2);
    D.fences.forEach(p => el('polyline', { points: pl(p), stroke: C.path, 'stroke-width': 1.6, 'stroke-dasharray': '8 5', opacity: .7 }, gp));
    D.walls.forEach(p => el('polyline', { points: pl(p), stroke: C.path, 'stroke-width': 3, opacity: .8 }, gp));
    const gb = el('g', {}, svg);
    D.pools.forEach(p => el('polygon', { points: pl(p), fill: '#38BDF8', 'fill-opacity': .55, stroke: C.bld, 'stroke-width': 2 }, gb));
    D.buildings.forEach(p => { el('polygon', { points: pl(p), fill: C.bg, stroke: C.bld, 'stroke-width': 3 }, gb); el('polygon', { points: pl(p), fill: `url(#${uid}-hatch)` }, gb); });
    D.domes.forEach(p => {
      const xs = p.map(q => q[0]), ys = p.map(q => q[1]);
      const cx = (Math.min(...xs) + Math.max(...xs)) / 2, cy = (Math.min(...ys) + Math.max(...ys)) / 2, r = (Math.max(...xs) - Math.min(...xs)) / 2;
      el('circle', { cx, cy, r: r + 3, fill: C.shadow, opacity: .6, transform: 'translate(5,6)' }, gb);
      el('circle', { cx, cy, r, fill: C.bg, stroke: C.bld, 'stroke-width': 3.5 }, gb);
      el('circle', { cx, cy, r: r * .55, fill: 'none', stroke: C.bld, 'stroke-width': 1.2, opacity: .5 }, gb);
    });
    el('rect', { width: D.W, height: D.H, fill: 'rgba(2,6,14,.28)', mask: `url(#${uid}-out)` }, svg);
    const gg = el('g', { stroke: C.grid, 'stroke-width': 1.5, opacity: .4 }, svg);
    for (let i = 0; i <= NC; i++) el('line', { x1: i * D.W / NC, y1: 0, x2: i * D.W / NC, y2: D.H }, gg);
    for (let j = 0; j <= NR; j++) el('line', { x1: 0, y1: j * D.H / NR, x2: D.W, y2: j * D.H / NR }, gg);
    const gl = el('g', { fill: C.grid, 'font-family': 'IBM Plex Mono, monospace', 'font-size': 34, 'font-weight': 700, 'paint-order': 'stroke', stroke: '#02060e', 'stroke-width': 7 }, svg);
    for (let i = 0; i < NC; i++) el('text', { x: i * D.W / NC + 12, y: 40 }, gl).textContent = COLS[i];
    for (let j = 0; j < NR; j++) el('text', { x: 10, y: (j + 1) * D.H / NR - 14 }, gl).textContent = j + 1;
    const n = el('g', { transform: `translate(${D.W - 80},${D.H - 90})` }, svg);
    el('circle', { r: 44, fill: 'rgba(2,6,14,.7)', stroke: C.grid, 'stroke-width': 2 }, n);
    el('path', { d: 'M0,-36 L11,0 L0,-6 L-11,0 Z', fill: '#EAF6FF' }, n);
    el('path', { d: 'M0,36 L11,0 L0,6 L-11,0 Z', fill: 'none', stroke: '#EAF6FF', 'stroke-width': 2 }, n);
    el('text', { y: -50, 'text-anchor': 'middle', 'font-size': 24, fill: C.grid, 'font-family': 'IBM Plex Mono, monospace', 'font-weight': 700 }, n).textContent = 'N';
    return sat;
  }

  function create(container, opts) {
    opts = Object.assign({ mode: 'view', points: [], onChange: null, onSelect: null, onLimit: null, max: 6, defaultType: 'danger', satellite: false }, opts || {});
    const uid = 'pm' + Math.random().toString(36).slice(2, 8);
    let points = (opts.points || []).map(upgrade);
    let selected = -1, drag = null, svg = null, ptsG = null, satImg = null, popup = null;
    container.innerHTML = '';
    if (getComputedStyle(container).position === 'static') container.style.position = 'relative';

    function popupHide() { if (popup) popup.style.display = 'none'; }
    function popupShow(i) {
      const p = points[i], T = TYPES[p.type] || TYPES.danger;
      if (!popup) {
        popup = document.createElement('div');
        popup.className = 'pm-popup';
        popup.style.cssText = 'position:absolute;z-index:3;max-width:min(320px,80%);background:rgba(2,8,16,.94);padding:12px 14px 12px;font-family:"IBM Plex Mono",monospace;color:#EAF6FF;font-size:13px;line-height:1.45;box-shadow:0 0 20px rgba(0,0,0,.6);pointer-events:auto;';
        popup.addEventListener('click', e => { e.stopPropagation(); popupHide(); });
        container.appendChild(popup);
      }
      popup.style.border = `1px solid ${T.color}`;
      popup.innerHTML = `<div style="color:${T.color};font-weight:700;letter-spacing:1px;text-transform:uppercase;font-size:14px">${i + 1}. ${esc(p.label || T.name)}</div>
        <div style="opacity:.7;font-size:11px;letter-spacing:1px;margin:2px 0 8px">СЕКТОР ${sectorOf(p.x, p.y)} · ${esc(T.name).toUpperCase()}</div>
        <div style="white-space:pre-wrap">${esc(p.info || 'Дополнительных сведений нет.')}</div>`;
      popup.style.display = 'block';
      const sr = svg.getBoundingClientRect(), cr = container.getBoundingClientRect();
      const sx = sr.width / W(), sy = sr.height / H();
      let left = sr.left - cr.left + p.x * sx + 24, top = sr.top - cr.top + p.y * sy - 20;
      const pw = popup.offsetWidth, ph = popup.offsetHeight;
      if (left + pw > cr.width - 6) left = sr.left - cr.left + p.x * sx - pw - 24;
      top = Math.max(6, Math.min(cr.height - ph - 6, top));
      popup.style.left = Math.max(6, left) + 'px'; popup.style.top = top + 'px';
    }

    function drawPoints() {
      if (!ptsG) return;
      ptsG.innerHTML = '';
      points.forEach((p, i) => {
        const T = TYPES[p.type] || TYPES.danger;
        const g = el('g', { transform: `translate(${p.x},${p.y})`, class: 'pm-point', 'data-i': i, style: 'cursor:' + (opts.mode === 'edit' ? 'grab' : 'pointer') }, ptsG);
        const S = 1.7;   // точки и подписи крупнее: карта на экране показывается в 3–4 раза меньше натурального размера
        el('circle', { r: 60 * S, fill: 'transparent' }, g);   // область нажатия
        [0, 1].forEach(k => {
          const c = el('circle', { r: 30 * S, fill: 'none', stroke: T.color, 'stroke-width': 6 * S }, g);
          el('animate', { attributeName: 'r', values: `${30 * S};${120 * S}`, dur: '2s', begin: `${k}s`, repeatCount: 'indefinite' }, c);
          el('animate', { attributeName: 'opacity', values: '1;0', dur: '2s', begin: `${k}s`, repeatCount: 'indefinite' }, c);
        });
        const rot = el('circle', { r: 52 * S, fill: 'none', stroke: T.color, 'stroke-width': 4 * S, 'stroke-dasharray': `${12 * S} ${12 * S}` }, g);
        el('animateTransform', { attributeName: 'transform', type: 'rotate', from: '0', to: '360', dur: '6s', repeatCount: 'indefinite' }, rot);
        el('path', { d: shapePath(T.shape, 32 * S), fill: '#04101c', stroke: '#04101c', 'stroke-width': 14 * S }, g);
        const body = el('path', { d: shapePath(T.shape, 32 * S), fill: T.color, stroke: '#FFFFFF', 'stroke-width': 5 * S, filter: `url(#${uid}-glow)` }, g);
        el('animate', { attributeName: 'opacity', values: '1;.6;1', dur: '1.2s', repeatCount: 'indefinite' }, body);
        el('text', { y: (T.shape === 'tri' ? 14 : 11) * S, 'text-anchor': 'middle', 'font-size': 32 * S, 'font-weight': 800, fill: '#04101c', 'font-family': 'IBM Plex Mono, monospace' }, g).textContent = i + 1;
        // подпись — полупрозрачная плашка: название и сектор
        const text = (p.label || T.name).toUpperCase();
        const right = p.x < W() - 760;
        const lg = el('g', { transform: `translate(${right ? 66 * S : -66 * S},${-62 * S})`, opacity: .8 }, g);
        const w = (Math.max(text.length * 20, 190) + 34) * S;
        el('rect', { x: right ? 0 : -w, y: 0, width: w, height: 82 * S, fill: 'rgba(2,8,16,.5)', stroke: T.color, 'stroke-width': 3 * S, 'stroke-opacity': .65 }, lg);
        el('text', { x: right ? 16 * S : -w + 16 * S, y: 35 * S, 'font-size': 30 * S, 'font-weight': 700, fill: T.color, 'font-family': 'Exo 2, IBM Plex Mono, sans-serif' }, lg).textContent = text;
        el('text', { x: right ? 16 * S : -w + 16 * S, y: 68 * S, 'font-size': 24 * S, fill: '#EAF6FF', 'font-family': 'IBM Plex Mono, monospace' }, lg).textContent = `СЕКТОР ${sectorOf(p.x, p.y)}${p.info ? '  ⓘ' : ''}`;
        if (opts.mode === 'edit' && i === selected) el('circle', { r: 66 * S, fill: 'none', stroke: '#FFFFFF', 'stroke-width': 4 * S, 'stroke-dasharray': '10 10' }, g);
      });
    }

    function toVB(evt) {
      const pt = svg.createSVGPoint(); pt.x = evt.clientX; pt.y = evt.clientY;
      const p = pt.matrixTransform(svg.getScreenCTM().inverse());
      return { x: Math.max(0, Math.min(W(), Math.round(p.x))), y: Math.max(0, Math.min(H(), Math.round(p.y))) };
    }

    const ready = load().then(D => {
      svg = el('svg', { viewBox: `0 0 ${D.W} ${D.H}`, preserveAspectRatio: 'xMidYMid meet', role: 'img', 'aria-label': 'Карта полигона' }, container);
      svg.style.cssText = 'width:100%;height:100%;display:block;user-select:none;touch-action:none;' + (opts.mode === 'edit' ? 'cursor:crosshair;' : '');
      satImg = drawBase(svg, D, uid, opts);
      ptsG = el('g', {}, svg);
      drawPoints();
      if (opts.mode === 'edit') {
        svg.addEventListener('pointerdown', e => {
          const g = e.target.closest('.pm-point');
          if (g) { selected = +g.dataset.i; drag = selected; svg.setPointerCapture(e.pointerId); drawPoints(); opts.onSelect && opts.onSelect(selected); return; }
          if (points.length >= opts.max) { opts.onLimit && opts.onLimit(); return; }
          const p = toVB(e);
          points.push({ x: p.x, y: p.y, type: opts.defaultType, label: '', info: '', v: 2 });
          selected = points.length - 1; drawPoints(); opts.onChange && opts.onChange(points.slice(), selected);
        });
        svg.addEventListener('pointermove', e => { if (drag == null) return; const p = toVB(e); points[drag].x = p.x; points[drag].y = p.y; drawPoints(); });
        svg.addEventListener('pointerup', () => { if (drag != null) { drag = null; opts.onChange && opts.onChange(points.slice(), selected); } });
      } else {
        svg.addEventListener('click', e => {
          const g = e.target.closest('.pm-point');
          if (g) { e.stopPropagation(); popupShow(+g.dataset.i); } else popupHide();
        });
      }
    }).catch(err => { container.innerHTML = '<div style="padding:20px;color:#FF6B6B;font-family:monospace">Карта не загрузилась: ' + esc(err.message) + '</div>'; });

    return {
      ready,
      setPoints(list) { points = (list || []).map(upgrade); if (selected >= points.length) selected = -1; popupHide(); drawPoints(); },
      getPoints() { return points.slice(); },
      select(i) { selected = i; drawPoints(); },
      setOption(k, v) { opts[k] = v; },
      setSatellite(on) { opts.satellite = !!on; if (satImg) satImg.setAttribute('opacity', on ? .55 : .14); }
    };
  }

  window.PolygonMap = { create, TYPES, sectorOf, upgrade, load, get W() { return W(); }, get H() { return H(); } };
})();
