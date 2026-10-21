/* =========================================================================
   КАРТА ПОЛИГОНА — общий компонент для терминала (показ) и терминала мастера
   (расстановка точек кликом). Снимок map/polygon.jpg + схема местности поверх:
   граница полигона, лес/поля/лагерь, дорожки, купола, корпус, сетка A–J × 1–8.
   Схема читается и в ч/б: зоны различаются штриховкой, точки — формой.
   Координаты — в системе viewBox 0..1000 × 0..922 (точки хранятся так же).
   ========================================================================= */
(function () {
  const VB_W = 1000, VB_H = 922, COLS = 'ABCDEFGHIJ', NC = 10, NR = 8;
  const NS = 'http://www.w3.org/2000/svg';

  const DATA = {
    boundary: '884,529 870,553 857,575 847,596 838,617 828,637 818,657 806,676 794,694 782,711 769,728 757,745 746,762 735,780 723,797 710,814 696,830 679,843 661,854 641,862 621,869 601,873 580,877 560,880 540,881 520,882 501,882 481,882 462,880 444,878 426,876 408,874 390,871 372,868 354,865 337,861 319,858 301,853 284,848 267,841 250,833 234,824 219,813 206,801 192,789 179,776 165,764 149,753 130,744 111,733 93,721 77,707 66,689 58,670 54,650 52,629 52,609 53,588 54,568 55,549 58,529 60,510 62,491 64,472 66,453 68,433 70,414 72,393 74,373 77,351 80,330 84,307 89,284 95,262 105,240 117,220 131,202 148,186 166,171 184,156 201,141 219,124 238,107 258,91 278,76 301,63 324,53 349,44 374,38 400,33 426,29 452,28 478,27 505,29 531,31 558,34 584,40 610,48 636,56 659,70 682,84 706,96 732,108 756,121 782,133 809,145 836,160 861,177 885,195 905,218 921,243 931,272 936,302 937,333 940,362 939,392 935,421 928,450 916,478 900,504',
    // открытые участки (луг/поле)
    fields: [
      '0,282 52,292 92,322 118,372 140,418 150,452 120,470 76,452 30,436 0,430',
      '100,498 160,478 222,486 262,512 298,560 286,604 248,640 196,668 140,676 104,650 96,580',
      '286,386 344,402 404,428 452,458 436,488 384,478 334,458 292,428',
      '552,700 628,688 694,700 742,736 730,792 690,842 618,874 560,872 538,820 540,756',
      '908,690 960,672 1000,668 1000,822 940,820 904,770'
    ],
    // лагерь — расчищенная территория с куполами
    camp: '196,276 246,222 336,242 430,262 520,266 604,258 692,268 764,300 800,352 786,402 716,458 640,466 556,430 470,410 378,414 298,376 220,334',
    // дорожки
    paths: [
      '552,262 572,276 594,292 604,298',
      '514,288 560,294 604,299 640,304 670,316',
      '514,288 560,320 610,356 652,390 678,410 676,428 662,438',
      '606,366 612,384 608,402 590,408',
      '696,347 726,351 748,366 760,378',
      '350,306 380,316'
    ],
    buildings: [
      { pts: '686,289 704,285 712,299 717,329 707,348 690,346 678,331 680,302', label: 'КОРПУС' },
      { pts: '616,279 647,281 646,295 615,293', label: '' },
      { pts: '719,331 737,324 748,343 731,350', label: '' }
    ],
    domes: [[213, 299], [261, 238], [289, 349], [335, 267], [376, 392], [418, 284], [492, 391], [576, 407], [657, 442], [766, 378]],
    labels: [
      { x: 470, y: 150, t: 'ЛЕС', s: 22 }, { x: 380, y: 700, t: 'ЛЕС', s: 22 }, { x: 790, y: 560, t: 'ЛЕС', s: 22 },
      { x: 185, y: 585, t: 'ПОЛЕ', s: 16 }, { x: 640, y: 790, t: 'ПОЛЕ', s: 16 }, { x: 70, y: 380, t: 'ПОЛЕ', s: 13 },
      { x: 455, y: 335, t: 'ЛАГЕРЬ', s: 15 }
    ]
  };

  const TYPES = {
    danger:  { name: 'Опасность',   color: '#FF4D4D', shape: 'tri' },
    gather:  { name: 'Точка сбора', color: '#4ADE80', shape: 'circle' },
    shelter: { name: 'Укрытие',     color: '#38BDF8', shape: 'square' },
    target:  { name: 'Цель',        color: '#FFB454', shape: 'diamond' },
    info:    { name: 'Отметка',     color: '#E2E8F0', shape: 'hex' }
  };

  const sectorOf = (x, y) => COLS[Math.max(0, Math.min(NC - 1, Math.floor(x / (VB_W / NC))))] + (Math.max(0, Math.min(NR - 1, Math.floor(y / (VB_H / NR)))) + 1);
  function el(tag, attrs, parent) {
    const e = document.createElementNS(NS, tag);
    for (const k in attrs) e.setAttribute(k, attrs[k]);
    if (parent) parent.appendChild(e);
    return e;
  }
  const esc = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

  function shapePath(shape, r) {
    if (shape === 'tri') return `M0,${-r * 1.15} L${r},${r * 0.75} L${-r},${r * 0.75} Z`;
    if (shape === 'square') return `M${-r * .85},${-r * .85} H${r * .85} V${r * .85} H${-r * .85} Z`;
    if (shape === 'diamond') return `M0,${-r * 1.15} L${r * 1.15},0 L0,${r * 1.15} L${-r * 1.15},0 Z`;
    if (shape === 'hex') { let d = ''; for (let i = 0; i < 6; i++) { const a = Math.PI / 3 * i - Math.PI / 2; d += (i ? 'L' : 'M') + (r * Math.cos(a)).toFixed(1) + ',' + (r * Math.sin(a)).toFixed(1); } return d + 'Z'; }
    return `M${r},0 A${r},${r} 0 1,1 ${-r},0 A${r},${r} 0 1,1 ${r},0 Z`;
  }

  function create(container, opts) {
    opts = Object.assign({ mode: 'view', points: [], imageUrl: 'map/polygon.jpg', accent: '#5EEAD4', onChange: null, labels: true }, opts || {});
    const uid = 'pm' + Math.random().toString(36).slice(2, 8);
    container.innerHTML = '';
    const svg = el('svg', { viewBox: `0 0 ${VB_W} ${VB_H}`, preserveAspectRatio: 'xMidYMid meet', class: 'pm-svg', role: 'img', 'aria-label': 'Карта полигона' }, container);
    svg.style.cssText = 'width:100%;height:100%;display:block;user-select:none;touch-action:none;' + (opts.mode === 'edit' ? 'cursor:crosshair;' : '');
    const defs = el('defs', {}, svg);
    defs.innerHTML = `
      <pattern id="${uid}-forest" width="40" height="34" patternUnits="userSpaceOnUse">
        <path d="M8,13 l4,-7 l4,7 z M28,30 l4,-7 l4,7 z" fill="none" stroke="#B4F0C8" stroke-width="1.2" opacity=".42"/>
      </pattern>
      <pattern id="${uid}-field" width="9" height="9" patternUnits="userSpaceOnUse" patternTransform="rotate(-35)">
        <line x1="0" y1="0" x2="0" y2="9" stroke="#F5E6A8" stroke-width="1.2" opacity=".55"/>
      </pattern>
      <mask id="${uid}-outside"><rect width="${VB_W}" height="${VB_H}" fill="#fff"/><polygon points="${DATA.boundary}" fill="#000"/></mask>
      <mask id="${uid}-forestmask"><polygon points="${DATA.boundary}" fill="#fff"/>
        ${DATA.fields.map(f => `<polygon points="${f}" fill="#000"/>`).join('')}<polygon points="${DATA.camp}" fill="#000"/></mask>
      <filter id="${uid}-glow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="3" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>`;

    // снимок + затемнение
    el('image', { href: opts.imageUrl, x: 0, y: 0, width: VB_W, height: VB_H, preserveAspectRatio: 'none' }, svg);
    el('rect', { width: VB_W, height: VB_H, fill: 'rgba(3,10,22,.18)' }, svg);
    el('rect', { width: VB_W, height: VB_H, fill: 'rgba(2,6,14,.55)', mask: `url(#${uid}-outside)` }, svg);

    // зоны
    const zones = el('g', {}, svg);
    el('rect', { width: VB_W, height: VB_H, fill: `url(#${uid}-forest)`, mask: `url(#${uid}-forestmask)` }, zones);
    DATA.fields.forEach(f => {
      el('polygon', { points: f, fill: 'rgba(240,220,140,.13)' }, zones);
      el('polygon', { points: f, fill: `url(#${uid}-field)` }, zones);
      el('polygon', { points: f, fill: 'none', stroke: '#F5E6A8', 'stroke-width': 1.6, 'stroke-dasharray': '6 4', opacity: .85 }, zones);
    });
    el('polygon', { points: DATA.camp, fill: 'rgba(120,230,200,.10)', stroke: '#9FF5DD', 'stroke-width': 1.6, 'stroke-dasharray': '2 4', opacity: .9 }, zones);

    // дорожки: тёмная «обводка» + светлая линия
    const paths = el('g', { fill: 'none', 'stroke-linecap': 'round', 'stroke-linejoin': 'round' }, svg);
    DATA.paths.forEach(p => el('polyline', { points: p, stroke: '#04101c', 'stroke-width': 7, opacity: .8 }, paths));
    DATA.paths.forEach(p => el('polyline', { points: p, stroke: '#FFFFFF', 'stroke-width': 3 }, paths));

    // постройки и купола
    const bld = el('g', {}, svg);
    DATA.buildings.forEach(b => el('polygon', { points: b.pts, fill: '#EAF6FF', stroke: '#04101c', 'stroke-width': 2.5 }, bld));
    DATA.domes.forEach(([x, y], i) => {
      el('circle', { cx: x, cy: y, r: 13, fill: '#FFFFFF', stroke: '#04101c', 'stroke-width': 3 }, bld);
      const t = el('text', { x, y: y + 4.5, 'text-anchor': 'middle', 'font-size': 12.5, 'font-weight': 700, fill: '#04101c', 'font-family': 'IBM Plex Mono, monospace' }, bld);
      t.textContent = i + 1;
    });

    // подписи местности
    const lab = el('g', { 'font-family': 'Exo 2, IBM Plex Mono, sans-serif', 'font-weight': 700, 'text-anchor': 'middle', 'paint-order': 'stroke', stroke: 'rgba(2,8,16,.85)', 'stroke-width': 4, 'stroke-linejoin': 'round' }, svg);
    if (opts.labels) {
      DATA.labels.forEach(l => { const t = el('text', { x: l.x, y: l.y, 'font-size': l.s, fill: '#EAF6FF', 'letter-spacing': 3, opacity: .9 }, lab); t.textContent = l.t; });
      DATA.buildings.forEach(b => { if (!b.label) return; const [x, y] = b.pts.split(' ')[3].split(',').map(Number); const t = el('text', { x: x + 8, y: y - 8, 'font-size': 13, fill: '#EAF6FF', 'text-anchor': 'start' }, lab); t.textContent = b.label; });
    }

    // граница полигона
    el('polygon', { points: DATA.boundary, fill: 'none', stroke: '#04101c', 'stroke-width': 9, opacity: .8 }, svg);
    el('polygon', { points: DATA.boundary, fill: 'none', stroke: '#FFB454', 'stroke-width': 4, 'stroke-dasharray': '18 8' }, svg);

    // сетка
    const grid = el('g', {}, svg);
    for (let i = 0; i <= NC; i++) el('line', { x1: i * VB_W / NC, y1: 0, x2: i * VB_W / NC, y2: VB_H, stroke: '#5EEAD4', 'stroke-width': 1, opacity: .45 }, grid);
    for (let j = 0; j <= NR; j++) el('line', { x1: 0, y1: j * VB_H / NR, x2: VB_W, y2: j * VB_H / NR, stroke: '#5EEAD4', 'stroke-width': 1, opacity: .45 }, grid);
    const gl = el('g', { 'font-family': 'IBM Plex Mono, monospace', 'font-size': 15, 'font-weight': 700, fill: '#5EEAD4', 'paint-order': 'stroke', stroke: '#02060e', 'stroke-width': 3 }, svg);
    for (let i = 0; i < NC; i++) {
      el('text', { x: i * VB_W / NC + 7, y: 18 }, gl).textContent = COLS[i];
      el('text', { x: i * VB_W / NC + 7, y: VB_H - 7 }, gl).textContent = COLS[i];
    }
    for (let j = 0; j < NR; j++) {
      el('text', { x: 6, y: (j + 1) * VB_H / NR - 8 }, gl).textContent = j + 1;
      el('text', { x: VB_W - 18, y: (j + 1) * VB_H / NR - 8 }, gl).textContent = j + 1;
    }
    // север
    const n = el('g', { transform: `translate(${VB_W - 44},48)` }, svg);
    el('circle', { r: 20, fill: 'rgba(2,6,14,.75)', stroke: '#5EEAD4', 'stroke-width': 1.5 }, n);
    el('path', { d: 'M0,-14 L7,6 L0,2 L-7,6 Z', fill: '#EAF6FF' }, n);
    el('text', { y: 16.5, 'text-anchor': 'middle', 'font-size': 9, fill: '#5EEAD4', 'font-family': 'IBM Plex Mono, monospace', 'font-weight': 700 }, n).textContent = 'С';

    // точки
    const pts = el('g', {}, svg);
    let points = (opts.points || []).slice();
    let selected = -1, drag = null;

    function drawPoints() {
      pts.innerHTML = '';
      points.forEach((p, i) => {
        const T = TYPES[p.type] || TYPES.danger;
        const g = el('g', { transform: `translate(${p.x},${p.y})`, class: 'pm-point', 'data-i': i, style: opts.mode === 'edit' ? 'cursor:grab' : '' }, pts);
        // пульсирующие кольца
        [0, 1].forEach(k => {
          const c = el('circle', { r: 14, fill: 'none', stroke: T.color, 'stroke-width': 3 }, g);
          el('animate', { attributeName: 'r', values: '14;58', dur: '2s', begin: `${k}s`, repeatCount: 'indefinite' }, c);
          el('animate', { attributeName: 'opacity', values: '.95;0', dur: '2s', begin: `${k}s`, repeatCount: 'indefinite' }, c);
        });
        const rot = el('circle', { r: 26, fill: 'none', stroke: T.color, 'stroke-width': 2, 'stroke-dasharray': '6 6' }, g);
        el('animateTransform', { attributeName: 'transform', type: 'rotate', from: '0', to: '360', dur: '6s', repeatCount: 'indefinite' }, rot);
        el('path', { d: shapePath(T.shape, 15), fill: '#04101c', stroke: '#04101c', 'stroke-width': 7 }, g);
        const body = el('path', { d: shapePath(T.shape, 15), fill: T.color, stroke: '#FFFFFF', 'stroke-width': 2.2, filter: `url(#${uid}-glow)` }, g);
        el('animate', { attributeName: 'opacity', values: '1;.55;1', dur: '1.2s', repeatCount: 'indefinite' }, body);
        el('text', { y: T.shape === 'tri' ? 7 : 5.5, 'text-anchor': 'middle', 'font-size': 15, 'font-weight': 800, fill: '#04101c', 'font-family': 'IBM Plex Mono, monospace' }, g).textContent = i + 1;
        // подпись
        const text = (p.label || T.name).toUpperCase();
        const sec = sectorOf(p.x, p.y);
        const right = p.x < VB_W - 260;
        const lg = el('g', { transform: `translate(${right ? 34 : -34},-30)` }, g);
        const w = Math.max(text.length * 9.6, 70) + 20;
        el('rect', { x: right ? 0 : -w, y: -2, width: w, height: 40, fill: 'rgba(2,8,16,.88)', stroke: T.color, 'stroke-width': 2 }, lg);
        el('text', { x: right ? 10 : -w + 10, y: 15, 'font-size': 15, 'font-weight': 700, fill: T.color, 'font-family': 'Exo 2, IBM Plex Mono, sans-serif' }, lg).textContent = text;
        el('text', { x: right ? 10 : -w + 10, y: 32, 'font-size': 12, fill: '#EAF6FF', 'font-family': 'IBM Plex Mono, monospace' }, lg).textContent = `${i + 1} · СЕКТОР ${sec}`;
        if (opts.mode === 'edit' && i === selected) el('circle', { r: 32, fill: 'none', stroke: '#FFFFFF', 'stroke-width': 2, 'stroke-dasharray': '3 3' }, g);
      });
    }
    drawPoints();

    function toVB(evt) {
      const pt = svg.createSVGPoint(); pt.x = evt.clientX; pt.y = evt.clientY;
      const p = pt.matrixTransform(svg.getScreenCTM().inverse());
      return { x: Math.max(0, Math.min(VB_W, Math.round(p.x))), y: Math.max(0, Math.min(VB_H, Math.round(p.y))) };
    }
    if (opts.mode === 'edit') {
      svg.addEventListener('pointerdown', e => {
        const g = e.target.closest('.pm-point');
        if (g) { selected = +g.dataset.i; drag = selected; svg.setPointerCapture(e.pointerId); drawPoints(); opts.onSelect && opts.onSelect(selected); return; }
        if (points.length >= (opts.max || 6)) { opts.onLimit && opts.onLimit(); return; }
        const p = toVB(e);
        points.push({ x: p.x, y: p.y, type: opts.defaultType || 'danger', label: '' });
        selected = points.length - 1; drawPoints(); opts.onChange && opts.onChange(points.slice(), selected);
      });
      svg.addEventListener('pointermove', e => {
        if (drag == null) return;
        const p = toVB(e); points[drag].x = p.x; points[drag].y = p.y; drawPoints();
      });
      svg.addEventListener('pointerup', () => { if (drag != null) { drag = null; opts.onChange && opts.onChange(points.slice(), selected); } });
    }

    return {
      svg,
      setPoints(list) { points = (list || []).slice(); if (selected >= points.length) selected = -1; drawPoints(); },
      getPoints() { return points.slice(); },
      select(i) { selected = i; drawPoints(); },
      setOption(k, v) { opts[k] = v; }
    };
  }

  window.PolygonMap = { create, TYPES, sectorOf, VB_W, VB_H };
})();
