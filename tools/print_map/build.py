"""Печатные карты полигона (А4) — 4 варианта оформления, цвет и ч/б.

Данные: map/topo.json (та же схема, что на терминале). Масштаб: 1 единица карты ≈ 0,111 м
(Web Mercator, уровень 20, широта ≈ 42°: купол ≈ 54 ед. ≈ 6 м).
Запуск: python3 tools/print_map/build.py  →  print/maps/*.html, *.pdf, *.png
"""
import json, math, os, pathlib, sys, base64

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / 'print' / 'maps'
OUT.mkdir(parents=True, exist_ok=True)
D = json.load(open(ROOT / 'map' / 'topo.json'))
W, H = D['W'], D['H']
M_PER_U = 0.1111            # метров на единицу карты
COLS, NC, NR = 'ABCDEFGHIJ', 10, 8
FONTS = pathlib.Path(os.environ.get('FONTS', '/tmp/claude-0/pv/node_modules/@fontsource'))

def font_css():
    css = ''
    for fam, pkg in [('Exo 2', 'exo-2'), ('IBM Plex Mono', 'ibm-plex-mono'), ('Jura', 'jura'), ('Tektur', 'tektur'), ('Russo One', 'russo-one'), ('Oxanium', 'oxanium')]:
        for wt in (300, 400, 500, 600, 700, 800):
            for sub in ('cyrillic', 'latin'):
                f = FONTS / pkg / 'files' / f'{pkg}-{sub}-{wt}-normal.woff2'
                if f.exists():
                    b = base64.b64encode(f.read_bytes()).decode()
                    css += f"@font-face{{font-family:'{fam}';font-weight:{wt};src:url(data:font/woff2;base64,{b}) format('woff2');}}\n"
    return css

def pl(pts): return ' '.join(f'{p[0]},{p[1]}' for p in pts)

def cloud(pts, step, hole):
    P = pts + [pts[0]]; per = []
    for a, b in zip(P, P[1:]):
        L = math.hypot(b[0] - a[0], b[1] - a[1]); n = max(1, round(L / step))
        for k in range(n): per.append((a[0] + (b[0] - a[0]) * k / n, a[1] + (b[1] - a[1]) * k / n))
    area = sum(pts[i][0] * pts[(i + 1) % len(pts)][1] - pts[(i + 1) % len(pts)][0] * pts[i][1] for i in range(len(pts)))
    sweep = 1 if ((area > 0) != hole) else 0
    d = f'M{per[0][0]:.1f},{per[0][1]:.1f}'
    for i in range(1, len(per) + 1):
        q = per[i % len(per)]; r = step * 0.62 * (0.85 + ((i * 7) % 5) / 12)
        d += f'A{r:.1f},{r:.1f} 0 0,{sweep} {q[0]:.1f},{q[1]:.1f}'
    return d + 'Z'

OUTER = [c for c in D['canopy'] if not c['h']]
HOLES = [c for c in D['canopy'] if c['h']]
CLOUD_O = [cloud(c['p'], 16, False) for c in OUTER]
CLOUD_H = [cloud(c['p'], 14, True) for c in HOLES]
HILL = 'data:image/jpeg;base64,' + base64.b64encode((ROOT / 'map' / 'hill.jpg').read_bytes()).decode()

def dome_geo(p):
    xs = [q[0] for q in p]; ys = [q[1] for q in p]
    return (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, (max(xs) - min(xs)) / 2

def map_svg(S, uid, margin=110, labels=True):
    """Схема в стиле S. margin — поля вокруг карты для подписей сетки (в единицах карты)."""
    m = margin
    o = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{-m} {-m} {W + 2 * m} {H + 2 * m}" class="map">']
    o.append(f'''<defs>
      <clipPath id="{uid}c"><rect width="{W}" height="{H}"/></clipPath>
      <pattern id="{uid}h" width="10" height="10" patternUnits="userSpaceOnUse" patternTransform="rotate(45)"><line x1="0" y1="0" x2="0" y2="10" stroke="{S['hatch']}" stroke-width="1.6"/></pattern>
      <pattern id="{uid}dots" width="14" height="14" patternUnits="userSpaceOnUse"><circle cx="4" cy="4" r="{S.get('dot_r', 3.2)}" fill="{S.get('dot', '#000')}"/><circle cx="11" cy="11" r="{S.get('dot_r', 3.2)}" fill="{S.get('dot', '#000')}"/></pattern>
      <filter id="{uid}soft"><feGaussianBlur stdDeviation="18"/></filter>
      <mask id="{uid}out"><rect width="{W}" height="{H}" fill="#fff"/><polygon points="{pl(D['boundary'])}" fill="#000" filter="url(#{uid}soft)"/></mask>
    </defs>''')
    o.append(f'<g clip-path="url(#{uid}c)">')
    o.append(f'<rect width="{W}" height="{H}" fill="{S["bg"]}"/>')
    if S.get('hill'):
        o.append(f'<image href="{HILL}" width="{W}" height="{H}" preserveAspectRatio="none" opacity="{S["hill"]}" style="mix-blend-mode:{S.get("hill_blend", "multiply")}"/>')
    def contours(op1, op2, w1, w2, col):
        g = [f'<g fill="none" stroke="{col}" stroke-linejoin="round">']
        for c in D['contours']:
            g.append(f'<polyline points="{pl(c["p"])}" stroke-width="{w1 if c["m"] else w2}" opacity="{op1 if c["m"] else op2}"/>')
        return ''.join(g) + '</g>'
    o.append(contours(S['cont_op'][0], S['cont_op'][1], S['cont_w'][0], S['cont_w'][1], S['cont']))
    # кроны
    if S.get('canopy_shadow'):
        o.append('<g>' + ''.join(f'<path d="{d}" fill="{S["canopy_shadow"]}" opacity=".5" transform="translate(7,9)"/>' for d in CLOUD_O) + '</g>')
    fill = f'url(#{uid}dots)' if S.get('canopy_dots') else S['canopy']
    o.append('<g>' + ''.join(f'<path d="{d}" fill="{S["canopy"]}" fill-opacity="{S.get("canopy_op", .9)}" stroke="{S["canopy_edge"]}" stroke-width="{S.get("canopy_w", 2)}"/>' for d in CLOUD_O))
    if S.get('canopy_dots'):
        o.append(''.join(f'<path d="{d}" fill="url(#{uid}dots)" opacity="{S.get("dots_op", .5)}"/>' for d in CLOUD_O))
    o.append(''.join(f'<path d="{d}" fill="{S["bg"]}" fill-opacity=".95" stroke="{S["canopy_edge"]}" stroke-width="{S.get("canopy_w", 2)}"/>' for d in CLOUD_H) + '</g>')
    if S.get('cont_over', True):
        o.append(contours(S['cont_op'][0] * .6, S['cont_op'][1] * .5, S['cont_w'][0] * .8, S['cont_w'][1] * .8, S['cont']))
    # дороги и тропы — двойной линией
    g = ['<g fill="none" stroke-linecap="round" stroke-linejoin="round">']
    def dbl(lst, w, inner, col, fillc):
        for p in lst: g.append(f'<polyline points="{pl(p)}" stroke="{col}" stroke-width="{w}"/>')
        for p in lst: g.append(f'<polyline points="{pl(p)}" stroke="{fillc}" stroke-width="{w - inner}"/>')
    dbl(D['roads'], 26, 6, S['path'], S.get('road_fill', S['path_fill']))
    dbl(D['tracks'], 17, 5, S['path'], S.get('track_fill', S['path_fill']))
    dbl(D['paths'], 11, 4.2, S['path'], S['path_fill'])
    for p in D['fences']: g.append(f'<polyline points="{pl(p)}" stroke="{S["path"]}" stroke-width="2" stroke-dasharray="8 5" opacity=".8"/>')
    for p in D['walls']: g.append(f'<polyline points="{pl(p)}" stroke="{S["path"]}" stroke-width="3.5"/>')
    o.append(''.join(g) + '</g>')
    # постройки, бассейн, купола
    for p in D['pools']: o.append(f'<polygon points="{pl(p)}" fill="{S["pool"]}" stroke="{S["bld"]}" stroke-width="2.5"/>')
    for p in D['buildings']:
        o.append(f'<polygon points="{pl(p)}" fill="{S["bld_fill"]}" stroke="{S["bld"]}" stroke-width="3.5"/><polygon points="{pl(p)}" fill="url(#{uid}h)"/>')
    for p in D['domes']:
        cx, cy, r = dome_geo(p)
        if S.get('dome_shadow'): o.append(f'<circle cx="{cx}" cy="{cy}" r="{r + 3}" fill="{S["dome_shadow"]}" opacity=".55" transform="translate(5,6)"/>')
        o.append(f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{S["dome_fill"]}" stroke="{S["dome"]}" stroke-width="4"/>')
        o.append(f'<circle cx="{cx}" cy="{cy}" r="{r * .55}" fill="none" stroke="{S["dome"]}" stroke-width="1.5" opacity=".6"/>')
        # рёбра геодезического купола
        o.append(''.join(f'<line x1="{cx + r * .55 * math.cos(a):.1f}" y1="{cy + r * .55 * math.sin(a):.1f}" x2="{cx + r * math.cos(a):.1f}" y2="{cy + r * math.sin(a):.1f}" stroke="{S["dome"]}" stroke-width="1.2" opacity=".55"/>' for a in [k * math.pi / 3 for k in range(6)]))
    if S.get('veil'):
        o.append(f'<rect width="{W}" height="{H}" fill="{S["veil"]}" mask="url(#{uid}out)"/>')
    # сетка секторов
    gg = [f'<g stroke="{S["grid"]}" stroke-width="{S.get("grid_w", 1.6)}" opacity="{S.get("grid_op", .5)}" {S.get("grid_dash", "")}>']
    for i in range(1, NC): gg.append(f'<line x1="{i * W / NC:.1f}" y1="0" x2="{i * W / NC:.1f}" y2="{H}"/>')
    for j in range(1, NR): gg.append(f'<line x1="0" y1="{j * H / NR:.1f}" x2="{W}" y2="{j * H / NR:.1f}"/>')
    o.append(''.join(gg) + '</g>')
    o.append('</g>')
    # рамка и подписи сетки по полям
    o.append(f'<rect width="{W}" height="{H}" fill="none" stroke="{S["frame"]}" stroke-width="{S.get("frame_w", 5)}"/>')
    if labels:
        fs = S.get('lab_fs', 46)
        lab = [f'<g fill="{S["lab"]}" font-family="{S["lab_font"]}" font-size="{fs}" font-weight="700" text-anchor="middle" dominant-baseline="central">']
        for i in range(NC):
            x = (i + .5) * W / NC
            lab.append(f'<text x="{x:.1f}" y="{-m / 2}">{COLS[i]}</text><text x="{x:.1f}" y="{H + m / 2}">{COLS[i]}</text>')
            # засечки на рамке
        for j in range(NR):
            y = (j + .5) * H / NR
            lab.append(f'<text x="{-m / 2}" y="{y:.1f}">{j + 1}</text><text x="{W + m / 2}" y="{y:.1f}">{j + 1}</text>')
        lab.append('</g>')
        tk = [f'<g stroke="{S["frame"]}" stroke-width="3">']
        for i in range(NC + 1):
            x = i * W / NC; tk.append(f'<line x1="{x:.1f}" y1="-22" x2="{x:.1f}" y2="0"/><line x1="{x:.1f}" y1="{H}" x2="{x:.1f}" y2="{H + 22}"/>')
        for j in range(NR + 1):
            y = j * H / NR; tk.append(f'<line x1="-22" y1="{y:.1f}" x2="0" y2="{y:.1f}"/><line x1="{W}" y1="{y:.1f}" x2="{W + 22}" y2="{y:.1f}"/>')
        tk.append('</g>')
        o += lab + tk
    o.append('</svg>')
    return ''.join(o)

# ---------------------------------------------------------------- мелкие элементы
def scale_bar(mm_per_m, S, total=100, step=25, h=2.6, font='IBM Plex Mono', col=None, alt=None):
    """Масштабная линейка в мм (SVG в миллиметрах)."""
    col = col or S['ink']; alt = alt or S['paper']
    L = total * mm_per_m; n = total // step; w = L / n
    o = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{L + 14:.2f}mm" height="{h + 8:.2f}mm" viewBox="-2 -5 {L + 14:.2f} {h + 8:.2f}">']
    for k in range(n):
        o.append(f'<rect x="{k * w:.2f}" y="0" width="{w:.2f}" height="{h}" fill="{col if k % 2 == 0 else alt}" stroke="{col}" stroke-width=".25"/>')
    for k in range(n + 1):
        o.append(f'<text x="{k * w:.2f}" y="-1.2" font-size="2.6" font-family="{font}" fill="{col}" text-anchor="middle">{k * step}</text>')
    o.append(f'<text x="{L + 2.5:.2f}" y="{h - .2}" font-size="2.8" font-family="{font}" fill="{col}">м</text></svg>')
    return ''.join(o)

def legend_items(S):
    """Иконки условных знаков (в единицах карты, 120×60)."""
    def box(inner): return f'<svg viewBox="0 0 120 60" class="lg-ic">{inner}</svg>'
    dome = box(f'<circle cx="60" cy="30" r="24" fill="{S["dome_fill"]}" stroke="{S["dome"]}" stroke-width="4"/><circle cx="60" cy="30" r="13" fill="none" stroke="{S["dome"]}" stroke-width="1.5" opacity=".6"/>')
    bld = box(f'<defs><pattern id="lgh{S["id"]}" width="10" height="10" patternUnits="userSpaceOnUse" patternTransform="rotate(45)"><line x1="0" y1="0" x2="0" y2="10" stroke="{S["hatch"]}" stroke-width="1.6"/></pattern></defs><rect x="30" y="10" width="60" height="40" fill="{S["bld_fill"]}" stroke="{S["bld"]}" stroke-width="3.5"/><rect x="30" y="10" width="60" height="40" fill="url(#lgh{S["id"]})"/>')
    def line(w, inner, fillc): return box(f'<polyline points="8,40 50,22 112,30" fill="none" stroke="{S["path"]}" stroke-width="{w}" stroke-linecap="round"/><polyline points="8,40 50,22 112,30" fill="none" stroke="{fillc}" stroke-width="{w - inner}" stroke-linecap="round"/>')
    tree_fill = S['canopy']
    tree = box(f'<path d="{cloud([[15, 12], [105, 8], [110, 50], [12, 52]], 16, False)}" fill="{tree_fill}" fill-opacity="{S.get("canopy_op", .9)}" stroke="{S["canopy_edge"]}" stroke-width="2"/>' + (f'<path d="{cloud([[15, 12], [105, 8], [110, 50], [12, 52]], 16, False)}" fill="url(#lgd{S["id"]})" opacity="{S.get("dots_op", .5)}"/><defs><pattern id="lgd{S["id"]}" width="14" height="14" patternUnits="userSpaceOnUse"><circle cx="4" cy="4" r="{S.get("dot_r", 3.2)}" fill="{S.get("dot", "#000")}"/><circle cx="11" cy="11" r="{S.get("dot_r", 3.2)}" fill="{S.get("dot", "#000")}"/></pattern></defs>' if S.get('canopy_dots') else ''))
    cont = box(f'<path d="M4,44 C30,30 60,48 116,22" fill="none" stroke="{S["cont"]}" stroke-width="4" opacity="{S["cont_op"][0]}"/><path d="M4,54 C34,40 64,58 116,34" fill="none" stroke="{S["cont"]}" stroke-width="2" opacity="{S["cont_op"][1]}"/>')
    pool = box(f'<rect x="34" y="12" width="52" height="36" fill="{S["pool"]}" stroke="{S["bld"]}" stroke-width="2.5"/>')
    fence = box(f'<line x1="6" y1="30" x2="114" y2="30" stroke="{S["path"]}" stroke-width="2.5" stroke-dasharray="8 5"/>')
    return [(dome, 'Купол модуля'), (bld, 'Постройка'), (line(26, 6, S.get('road_fill', S['path_fill'])), 'Дорога'),
            (line(17, 5, S.get('track_fill', S['path_fill'])), 'Грунтовка'), (line(11, 4.2, S['path_fill']), 'Тропа'),
            (tree, 'Деревья, заросли'), (cont, 'Горизонтали через 2 м'), (pool, 'Водоём'), (fence, 'Ограда')]

def north(S, size=16, style='arrow'):
    c, p = S['ink'], S['paper']
    if style == 'rose':
        pts = []
        for k in range(16):
            a = k * math.pi / 8 - math.pi / 2; r = 48 if k % 4 == 0 else (30 if k % 2 == 0 else 20)
            pts.append((r * math.cos(a), r * math.sin(a)))
        rays = ''
        for k in range(0, 16, 2):
            a = k * math.pi / 8 - math.pi / 2; r = 48 if k % 4 == 0 else 30
            x, y = r * math.cos(a), r * math.sin(a)
            bx1, by1 = 7 * math.cos(a - math.pi / 2), 7 * math.sin(a - math.pi / 2)
            rays += f'<path d="M0,0 L{bx1:.1f},{by1:.1f} L{x:.1f},{y:.1f} Z" fill="{c}"/><path d="M0,0 L{-bx1:.1f},{-by1:.1f} L{x:.1f},{y:.1f} Z" fill="{p}" stroke="{c}" stroke-width=".8"/>'
        return f'''<svg viewBox="-62 -66 124 124" width="{size}mm" height="{size}mm"><circle r="52" fill="none" stroke="{c}" stroke-width="1"/><circle r="56" fill="none" stroke="{c}" stroke-width=".5" stroke-dasharray="1.5 2.5"/>{rays}<circle r="4" fill="{p}" stroke="{c}"/>
          <text y="-57" text-anchor="middle" font-size="12" font-weight="700" fill="{c}" font-family="{S['font_t']}">С</text></svg>'''
    return f'''<svg viewBox="-30 -40 60 72" width="{size}mm" height="{size * 1.2}mm"><circle r="24" fill="none" stroke="{c}" stroke-width="1.6"/>
      <path d="M0,-21 L8,0 L0,-5 L-8,0 Z" fill="{c}"/><path d="M0,21 L8,0 L0,5 L-8,0 Z" fill="none" stroke="{c}" stroke-width="1.5"/>
      <text y="-29" text-anchor="middle" font-size="12" font-weight="700" fill="{c}" font-family="{S['font_t']}">С</text></svg>'''

# ---------------------------------------------------------------- стили
BASE_LIGHT = dict(cont_w=(3, 1.5), cont_op=(.9, .55), canopy_w=2, path_fill='#ffffff', pool='#bfe6f7', hatch='#000', grid_w=1.6)

STYLES = {}
# 1. Тактический планшет (как терминал)
STYLES['v1c'] = dict(id='v1c', bg='#06111e', paper='#06111e', ink='#BFF8F0', accent='#5EEAD4', accent2='#FFB454', hill=.32, hill_blend='soft-light',
    cont='#a9d2ee', cont_w=(3, 1.5), cont_op=(.7, .42), canopy='#1f4d5e', canopy_op=.93, canopy_edge='#86e6d2', canopy_shadow='#01050b',
    path='#e3f2ff', path_fill='#06111e', bld='#EAF6FF', bld_fill='#06111e', hatch='#EAF6FF', pool='#38BDF8', dome='#EAF6FF', dome_fill='#06111e', dome_shadow='#01050b',
    veil='rgba(2,6,14,.3)', grid='#5EEAD4', grid_op=.45, frame='#5EEAD4', lab='#5EEAD4', lab_font='IBM Plex Mono', font_t='Tektur', font_b='IBM Plex Mono')
STYLES['v1b'] = dict(STYLES['v1c'], id='v1b', bg='#ffffff', paper='#ffffff', ink='#111', accent='#111', accent2='#111', hill=.22, hill_blend='multiply',
    cont='#555', cont_op=(.85, .55), canopy='#cfcfcf', canopy_op=1, canopy_edge='#333', canopy_shadow=None, path='#111', path_fill='#fff',
    bld='#111', bld_fill='#fff', hatch='#111', pool='#e2e2e2', dome='#111', dome_fill='#fff', dome_shadow=None, veil='rgba(255,255,255,.45)',
    grid='#111', grid_op=.35, frame='#111', lab='#111')
# 2. Топографический лист экспедиции
STYLES['v2c'] = dict(BASE_LIGHT, id='v2c', bg='#f6f0df', paper='#f6f0df', ink='#2b2118', accent='#8c4a1f', accent2='#2f6b3c', hill=.18,
    cont='#a8693a', cont_op=(.95, .6), canopy='#b9d79b', canopy_op=.95, canopy_edge='#4f7d3a', path='#3a2a1c', path_fill='#fffaf0', road_fill='#f2b866', track_fill='#f7dca8',
    bld='#2b2118', bld_fill='#e9dcc4', hatch='#2b2118', pool='#9fd3e6', dome='#2b2118', dome_fill='#fffaf0', veil='rgba(246,240,223,.55)',
    grid='#2b2118', grid_op=.3, frame='#2b2118', lab='#2b2118', lab_font='Exo 2', font_t='Exo 2', font_b='Jura')
STYLES['v2b'] = dict(STYLES['v2c'], id='v2b', bg='#ffffff', paper='#ffffff', ink='#111', accent='#111', accent2='#111', hill=.14,
    cont='#555', canopy='#e6e6e6', canopy_edge='#333', canopy_dots=True, dot='#555', dot_r=2.4, dots_op=.55, path='#111', path_fill='#fff', road_fill='#bdbdbd', track_fill='#e0e0e0',
    bld='#111', bld_fill='#fff', hatch='#111', pool='#d6d6d6', dome='#111', dome_fill='#fff', veil='rgba(255,255,255,.55)', grid='#111', frame='#111', lab='#111')
# 3. Чертёж-синька
STYLES['v3c'] = dict(id='v3c', bg='#173a6b', paper='#173a6b', ink='#eaf2ff', accent='#ffffff', accent2='#9fd0ff', hill=0,
    cont='#cfe2ff', cont_w=(2.6, 1.2), cont_op=(.75, .4), canopy='#1f4a83', canopy_op=1, canopy_edge='#eaf2ff', canopy_w=1.6,
    path='#ffffff', path_fill='#173a6b', bld='#ffffff', bld_fill='#173a6b', hatch='#ffffff', pool='#2c5d9c', dome='#ffffff', dome_fill='#173a6b',
    veil='rgba(13,40,80,.35)', grid='#ffffff', grid_op=.35, grid_dash='stroke-dasharray="14 10"', frame='#ffffff', lab='#ffffff', lab_font='Jura', font_t='Jura', font_b='Jura', cont_over=False)
STYLES['v3b'] = dict(STYLES['v3c'], id='v3b', bg='#ffffff', paper='#ffffff', ink='#111', accent='#111', accent2='#111',
    cont='#666', canopy='#ffffff', canopy_edge='#222', path='#111', path_fill='#fff', bld='#111', bld_fill='#fff', hatch='#111', pool='#e4e4e4',
    dome='#111', dome_fill='#fff', veil='rgba(255,255,255,.5)', grid='#111', frame='#111', lab='#111')
# 4. Полевая карта колониста (яркий постер + памятка)
STYLES['v4c'] = dict(BASE_LIGHT, id='v4c', bg='#f3f5f4', paper='#ffffff', ink='#14181d', accent='#ff6a2b', accent2='#0f9d8a', hill=.12,
    cont='#8f9aa3', cont_w=(2.6, 1.2), cont_op=(.9, .55), canopy='#7fd38f', canopy_op=.85, canopy_edge='#1f7a3f', canopy_dots=True, dot='#1f7a3f', dot_r=2.2, dots_op=.35,
    path='#14181d', path_fill='#ffffff', road_fill='#ff6a2b', track_fill='#ffb48c', bld='#14181d', bld_fill='#ffd84d', hatch='#14181d', pool='#5ec8ef',
    dome='#14181d', dome_fill='#0fb59e', veil='rgba(255,255,255,.5)', grid='#14181d', grid_op=.28, frame='#14181d', frame_w=6, lab='#14181d', lab_font='Russo One',
    font_t='Russo One', font_b='Exo 2')
STYLES['v4b'] = dict(STYLES['v4c'], id='v4b', bg='#ffffff', paper='#ffffff', ink='#111', accent='#111', accent2='#111', side_bg='#e6e6e6', side_txt='#111', cont='#777',
    canopy='#d9d9d9', canopy_edge='#222', dot='#222', path='#111', road_fill='#666', track_fill='#bbb', bld='#111', bld_fill='#d0d0d0', hatch='#111', pool='#eaeaea',
    dome='#111', dome_fill='#8a8a8a', grid='#111', frame='#111', lab='#111')

TITLE = 'ПАРАДАЙЗ'
SUB = 'Посадочный сектор · карта местности'
MAP_MM = 186               # ширина SVG карты вместе с полями
MARGIN_U = 110
MM_PER_U = MAP_MM / (W + 2 * MARGIN_U)
MM_PER_M = MM_PER_U / M_PER_U
SCALE_N = round(1000 / MM_PER_M / 50) * 50          # 1 : N
CELL = f'{W / NC * M_PER_U:.0f} × {H / NR * M_PER_U:.0f} м'
SUITS = [('Пирвели', 2), ('Парадайз', 1), ('Фридом', 2), ('Искупление', 1)]

def legend_html(S, cols=3):
    return '<div class="legend" style="grid-template-columns:repeat(%d,1fr)">' % cols + ''.join(f'<div class="lg">{ic}<span>{t}</span></div>' for ic, t in legend_items(S)) + '</div>'

def page(S, body, css):
    return f'''<!doctype html><html lang="ru"><head><meta charset="utf-8"><title>Карта полигона</title><style>
{font_css()}
@page {{ size: A4; margin: 0; }}
* {{ box-sizing: border-box; }}
html, body {{ margin: 0; padding: 0; }}
body {{ -webkit-print-color-adjust: exact; print-color-adjust: exact; }}
.sheet {{ width: 210mm; height: 297mm; overflow: hidden; position: relative; background: {S['paper']}; color: {S['ink']}; font-family: '{S['font_b']}', monospace; }}
.map {{ display: block; width: {MAP_MM}mm; height: auto; }}
.legend {{ display: grid; gap: 1.2mm 4mm; }}
.lg {{ display: flex; align-items: center; gap: 2mm; font-size: 2.9mm; }}
.lg-ic {{ width: 9mm; height: 4.5mm; flex: 0 0 9mm; }}
{css}
</style></head><body><div class="sheet">{body}</div></body></html>'''

def v1(S):
    a, a2, ink = S['accent'], S['accent2'], S['ink']
    corner = lambda pos: f'<i class="cn {pos}"></i>'
    css = f'''
.hdr {{ position: absolute; left: 12mm; right: 12mm; top: 10mm; display: flex; align-items: flex-end; gap: 6mm; border-bottom: .5mm solid {a}; padding-bottom: 3mm; }}
.hdr h1 {{ margin: 0; font: 700 10.5mm/1 'Tektur'; letter-spacing: 1mm; color: {a}; white-space: nowrap; }}
.hdr .sub {{ font-size: 2.9mm; letter-spacing: .2mm; text-transform: uppercase; line-height: 1.5; white-space: nowrap; }}
.hdr .id {{ margin-left: auto; text-align: right; font-size: 2.5mm; letter-spacing: .15mm; line-height: 1.6; opacity: .85; white-space: nowrap; }}
.hdr .id b {{ color: {a2}; }}
.mapbox {{ position: absolute; left: 12mm; top: 33mm; }}
.cn {{ position: absolute; width: 7mm; height: 7mm; border: .6mm solid {a2}; }}
.cn.tl {{ left: 9mm; top: 30mm; border-right: 0; border-bottom: 0; }} .cn.tr {{ right: 9mm; top: 30mm; border-left: 0; border-bottom: 0; }}
.cn.bl {{ left: 9mm; top: 216mm; border-right: 0; border-top: 0; }} .cn.br {{ right: 9mm; top: 216mm; border-left: 0; border-top: 0; }}
.foot {{ position: absolute; left: 12mm; right: 12mm; top: 228mm; bottom: 10mm; display: grid; grid-template-columns: 1.45fr 1fr; gap: 6mm; }}
.panel {{ border: .35mm solid {a}; padding: 3mm 3.5mm; position: relative; }}
.panel h3 {{ margin: 0 0 2.2mm; font: 600 3mm/1 'Tektur'; letter-spacing: .6mm; color: {a}; text-transform: uppercase; }}
.panel h3::before {{ content: '▮ '; color: {a2}; }}
.warn {{ border-color: {a2}; }}
.warn p {{ margin: 0 0 2.2mm; font-size: 3mm; line-height: 1.4; }}
.warn .wl {{ margin-top: 3mm; border-bottom: .25mm dashed {a}; height: 5.5mm; opacity: .6; }}
.warn b {{ color: {a2}; }}
.suits {{ display: grid; grid-template-columns: 1fr auto; gap: .6mm 3mm; font-size: 2.9mm; margin-top: 1.5mm; }}
.suits span:nth-child(even) {{ color: {a2}; font-weight: 700; text-align: right; }}
.sc {{ display: flex; align-items: flex-end; justify-content: space-between; margin-top: 3mm; font-size: 2.8mm; }}
.ticker {{ position: absolute; left: 12mm; right: 12mm; bottom: 5mm; font-size: 2.3mm; letter-spacing: .5mm; opacity: .65; display: flex; justify-content: space-between; }}
'''
    body = f'''
<div class="hdr"><h1>{TITLE}</h1><div class="sub">{SUB}<br>Колониальная картографическая служба</div>
  <div class="id">ЛИСТ <b>01</b> · ОРБИТАЛЬНАЯ СЪЁМКА<br>4073 С.Э. · КЛЕТКА {CELL}</div></div>
{corner('tl')}{corner('tr')}{corner('bl')}{corner('br')}
<div class="mapbox">{map_svg(S, S['id'])}</div>
<div class="foot">
  <div class="panel"><h3>Условные обозначения</h3>{legend_html(S, 3)}
    <div class="sc"><div>{scale_bar(MM_PER_M, S, 100, 25, col=a, alt=S['paper'])}<div style="margin-top:.8mm">МАСШТАБ ≈ 1 : {SCALE_N:,}</div></div>{north(dict(S, ink=a), 13)}</div></div>
  <div class="panel warn"><h3>Внимание, колонист</h3>
    <p>Ночью атмосфера содержит газ: выход из модуля — <b>только в скафандре</b>.</p>
    <p>Бортовой журнал — запись <b>каждые 30 минут</b>.</p>
    <p style="margin-top:2.5mm;color:{a}">Скафандры по модулям:</p>
    <div class="suits">{''.join(f'<span>{n}</span><span>{k} ск.</span>' for n, k in SUITS)}</div></div>
</div>
<div class="ticker"><span>◈ SECTOR GRID A–J / 1–8</span><span>SIG −42dB ◇ ФОН 0.11 мЗв ◇ g 0.92</span><span>NAV-OSM / DEM-02</span></div>'''.replace('1 : ' + f'{SCALE_N:,}', '1 : ' + f'{SCALE_N:,}'.replace(',', ' '))
    return page(S, body, css)

def v2(S):
    a, a2, ink = S['accent'], S['accent2'], S['ink']
    css = f'''
.frame {{ position: absolute; inset: 8mm; border: .8mm solid {ink}; }}
.frame::after {{ content: ''; position: absolute; inset: 1.4mm; border: .25mm solid {ink}; }}
.title {{ position: absolute; left: 14mm; right: 14mm; top: 13mm; text-align: center; }}
.title .k {{ font: 600 3mm/1 'Jura'; letter-spacing: 1.2mm; text-transform: uppercase; color: {a}; }}
.title h1 {{ margin: 1.5mm 0 1mm; font: 800 12mm/1 'Exo 2'; letter-spacing: 2.5mm; }}
.title .s {{ font: 500 3.4mm/1.3 'Jura'; letter-spacing: .4mm; }}
.title .orn {{ display: flex; align-items: center; gap: 3mm; justify-content: center; margin-top: 1.6mm; color: {a}; font-size: 3mm; }}
.title .orn i {{ display: block; width: 40mm; height: .3mm; background: {a}; }}
.mapbox {{ position: absolute; left: 12mm; top: 40mm; }}
.bot {{ position: absolute; left: 14mm; right: 14mm; top: 226mm; bottom: 17mm; display: grid; grid-template-columns: 1fr 86mm; gap: 4mm; }}
.box {{ border: .35mm solid {ink}; padding: 2.6mm 3.2mm; position: relative; background: {S['paper']}; }}
.box h3 {{ margin: 0 0 2mm; font: 700 3.1mm/1 'Exo 2'; letter-spacing: .8mm; text-transform: uppercase; color: {a}; }}
.right {{ display: flex; flex-direction: row; align-items: center; justify-content: space-between; gap: 2mm; text-align: center; font-size: 2.6mm; padding: 2mm 1.5mm; }}
.right .n {{ font: 600 3mm 'Jura'; letter-spacing: .4mm; }}
.imprint {{ position: absolute; left: 14mm; right: 14mm; bottom: 11.5mm; display: flex; justify-content: space-between; font: 500 2.4mm 'Jura'; letter-spacing: .3mm; }}
'''
    body = f'''
<div class="frame"></div>
<div class="title"><div class="k">Колониальная экспедиция · картографический отдел</div><h1>{TITLE}</h1>
  <div class="s">План посадочного сектора · рельеф, растительность, тропы</div>
  <div class="orn"><i></i>✦ 4073 С.Э. ✦<i></i></div></div>
<div class="mapbox">{map_svg(S, S['id'])}</div>
<div class="bot">
  <div class="box"><h3>Условные знаки</h3>{legend_html(S, 2)}</div>
  <div class="box right">{north(S, 26, 'rose')}
    <div>{scale_bar(MM_PER_M, S, 80, 20, font='Jura')}<div class="n">Масштаб ≈ 1 : {SCALE_N:,}</div><div style="margin-top:.6mm">Клетка сетки {CELL}</div></div></div>
</div>
<div class="imprint"><span>Составлено по данным орбитальной съёмки и наземной разведки «Пирвели»</span><span>Лист 1 из 1</span></div>'''.replace(f'{SCALE_N:,}', f'{SCALE_N:,}'.replace(',', ' '))
    return page(S, body, css)

def v3(S):
    ink = S['ink']
    css = f'''
.frame {{ position: absolute; left: 10mm; right: 6mm; top: 6mm; bottom: 6mm; border: .6mm solid {ink}; }}
.mapbox {{ position: absolute; left: 13mm; top: 22mm; }}
.dim {{ position: absolute; left: {13 + MARGIN_U * MM_PER_U:.2f}mm; width: {W * MM_PER_U:.2f}mm; top: 14mm; height: 6mm; }}
.lbl {{ position: absolute; left: 14mm; top: 8.5mm; font: 700 3.2mm 'Jura'; letter-spacing: .6mm; }}
.notes {{ position: absolute; left: 14mm; top: 212mm; width: 80mm; font: 500 3mm/1.45 'Jura'; }}
.notes h4, .stamp h4 {{ margin: 0 0 1.5mm; font: 700 3.2mm 'Jura'; letter-spacing: .6mm; text-transform: uppercase; }}
.notes .ln {{ border-bottom: .25mm solid {ink}; height: 6.2mm; opacity: .7; }}
.leg {{ position: absolute; left: 100mm; top: 212mm; width: 100mm; }}
.stamp {{ position: absolute; right: 6mm; bottom: 6mm; width: 120mm; border-collapse: collapse; font: 500 2.8mm 'Jura'; }}
.stamp td {{ border: .35mm solid {ink}; padding: 1mm 1.6mm; height: 6mm; }}
.stamp .big {{ font: 700 5.4mm 'Jura'; letter-spacing: 1.2mm; text-align: center; }}
.stamp .k {{ opacity: .75; font-size: 2.4mm; }}
.sc {{ position: absolute; left: 100mm; top: 246mm; display: flex; gap: 6mm; align-items: center; font: 500 2.8mm 'Jura'; }}
'''
    span = W * M_PER_U
    dim = f'''<svg class="dim" viewBox="0 0 167.7 6" preserveAspectRatio="none"><g stroke="{ink}" stroke-width=".25" fill="none"><line x1="0" y1="0" x2="0" y2="6"/><line x1="167.7" y1="0" x2="167.7" y2="6"/><line x1="0" y1="3" x2="167.7" y2="3"/>
      <path d="M0,3 l3,-1.2 v2.4z M167.7,3 l-3,-1.2 v2.4z" fill="{ink}"/></g><rect x="70" y=".6" width="27.7" height="4.8" fill="{S['paper']}"/>
      <text x="83.85" y="4.2" text-anchor="middle" font-size="3" fill="{ink}" font-family="Jura">≈ {span:.0f} м</text></svg>'''
    stamp = f'''<table class="stamp">
  <tr><td colspan="3" rowspan="2" class="big">{TITLE} · ПЛАН</td><td class="k">Лит.</td><td class="k">Масштаб</td></tr>
  <tr><td>К</td><td>1 : {SCALE_N:,}</td></tr>
  <tr><td class="k">Разраб.</td><td colspan="2">Картограф. служба «Пирвели»</td><td class="k">Лист</td><td>1 / 1</td></tr>
  <tr><td class="k">Пров.</td><td colspan="2">Инженерная группа</td><td class="k">Сетка</td><td>{NC}×{NR}</td></tr>
  <tr><td class="k">Дата</td><td colspan="2">4073 С.Э.</td><td class="k">Клетка</td><td>{CELL}</td></tr>
</table>'''.replace(f'{SCALE_N:,}', f'{SCALE_N:,}'.replace(',', ' '))
    body = f'''<div class="frame"></div><div class="lbl">ПЛАН МЕСТНОСТИ · ПОСАДОЧНЫЙ СЕКТОР</div>{dim}
<div class="mapbox">{map_svg(S, S['id'])}</div>
<div class="notes"><h4>Отметки экипажа</h4>{''.join('<div class="ln"></div>' for _ in range(6))}</div>
<div class="leg">{legend_html(S, 3)}</div>
<div class="sc">{scale_bar(MM_PER_M, S, 100, 25, font='Jura')}{north(S, 11)}</div>
{stamp}'''
    return page(S, body, css)

def v4(S):
    a, a2, ink = S['accent'], S['accent2'], S['ink']
    css = f'''
.side {{ position: absolute; left: 0; top: 0; bottom: 0; width: 22mm; background: {S.get('side_bg', a)}; }}
.side span {{ position: absolute; left: 50%; bottom: 14mm; transform-origin: 0 0; transform: rotate(-90deg) translate(0, -50%); font: 400 15mm/1 'Russo One'; letter-spacing: 3mm; color: {S.get('side_txt', S['paper'])}; white-space: nowrap; }}
.side small {{ position: absolute; left: 0; right: 0; top: 10mm; text-align: center; font: 700 3mm/1.3 'Exo 2'; color: {S.get('side_txt', S['paper'])}; letter-spacing: .4mm; }}
.hd {{ position: absolute; left: 30mm; right: 8mm; top: 9mm; display: flex; justify-content: space-between; align-items: flex-end; }}
.hd h2 {{ margin: 0; font: 400 6.4mm/1 'Russo One'; letter-spacing: .4mm; }}
.hd .s {{ font: 600 3mm/1.4 'Exo 2'; text-align: right; color: {a2}; letter-spacing: .3mm; }}
.mapbox {{ position: absolute; left: 24mm; top: 20mm; }}
.mapbox .map {{ width: 182mm; }}
.grid2 {{ position: absolute; left: 30mm; right: 8mm; top: 202mm; bottom: 8mm; display: grid; grid-template-columns: 1fr 1fr; gap: 4mm; }}
.card {{ border: .5mm solid {ink}; padding: 2.8mm 3.2mm; display: flex; flex-direction: column; }}
.card .fill {{ flex: 1; display: flex; flex-direction: column; justify-content: flex-end; }}
.card .lab {{ font: 600 2.6mm 'Exo 2'; letter-spacing: .3mm; text-transform: uppercase; opacity: .7; margin-top: 2mm; }}
.card h3 {{ margin: 0 0 2mm; font: 400 3.6mm/1 'Russo One'; letter-spacing: .3mm; display: flex; align-items: center; gap: 2mm; }}
.card h3 i {{ display: inline-block; width: 4mm; height: 4mm; background: {a}; border-radius: 50%; }}
.rule {{ display: flex; gap: 2.4mm; align-items: flex-start; font: 500 3mm/1.35 'Exo 2'; margin-bottom: 1.8mm; }}
.rule b.n {{ flex: 0 0 5.6mm; height: 5.6mm; border-radius: 50%; background: {ink}; color: {S['paper']}; display: grid; place-items: center; font: 400 3mm 'Russo One'; }}
.suits {{ display: grid; grid-template-columns: repeat(4, 1fr); gap: 1.5mm; margin-top: 2mm; }}
.suits div {{ border: .35mm solid {ink}; text-align: center; padding: 1.2mm 0; font: 600 2.15mm 'Exo 2'; }}
.suits div b {{ display: block; font: 400 5mm/1.1 'Russo One'; color: {a}; }}
.sc {{ display: flex; justify-content: space-between; align-items: center; margin-top: 2mm; font: 600 2.8mm 'Exo 2'; }}
.ln {{ border-bottom: .3mm dashed {ink}; height: 6mm; }}
'''
    body = f'''
<div class="side"><small>4073<br>С.Э.</small><span>{TITLE}</span></div>
<div class="hd"><h2>ПОЛЕВАЯ КАРТА КОЛОНИСТА</h2><div class="s">Посадочный сектор · сетка {NC}×{NR}<br>клетка {CELL} · север вверху</div></div>
<div class="mapbox">{map_svg(S, S['id'])}</div>
<div class="grid2">
  <div class="card"><h3><i></i>Условные знаки</h3>{legend_html(S, 2)}
    <div class="sc">{scale_bar(MM_PER_M, S, 100, 25, font='Exo 2', col=ink, alt=S['paper'])}{north(S, 10)}</div>
    <div class="fill"><div class="lab">Отметки экипажа</div><div class="ln"></div><div class="ln"></div></div></div>
  <div class="card"><h3><i></i>Памятка колониста</h3>
    <div class="rule"><b class="n">1</b><span>Ночью в атмосфере газ: наружу — только в скафандре (кожа закрыта, перчатки, шлем).</span></div>
    <div class="rule"><b class="n">2</b><span>Оказались без скафандра в газе — наденьте белый хайратник и сообщите мастеру.</span></div>
    <div class="rule"><b class="n">3</b><span>Бортовой журнал — каждые 30 минут, иначе модуль отключит питание.</span></div>
    <div class="lab">Скафандры по модулям</div>
    <div class="suits">{''.join(f'<div><b>{k}</b>{n}</div>' for n, k in SUITS)}</div>
    <div class="fill"><div class="lab">Наш модуль на карте — сектор</div><div class="ln"></div></div>
  </div>
</div>'''
    return page(S, body, css)

BUILD = {'v1': v1, 'v2': v2, 'v3': v3, 'v4': v4}
NAMES = {'v1': 'tactical', 'v2': 'topo', 'v3': 'blueprint', 'v4': 'field'}

if __name__ == '__main__':
    from playwright.sync_api import sync_playwright
    files = []
    for v, fn in BUILD.items():
        for mode in ('c', 'b'):
            S = STYLES[v + mode]
            p = OUT / f'map_{v}_{NAMES[v]}_{"color" if mode == "c" else "bw"}.html'
            p.write_text(fn(S)); files.append(p)
    with sync_playwright() as pw:
        b = pw.chromium.launch()
        pg = b.new_page(viewport={'width': 794, 'height': 1123}, device_scale_factor=2)
        for p in files:
            pg.goto(p.as_uri()); pg.wait_for_timeout(400)
            pg.pdf(path=str(p.with_suffix('.pdf')), format='A4', print_background=True, margin={'top': '0', 'right': '0', 'bottom': '0', 'left': '0'})
            pg.screenshot(path=str(p.with_suffix('.png')))
            print(p.name, 'ok')
        b.close()
    print('scale 1 :', SCALE_N, 'mm/m', MM_PER_M, 'cell', CELL)
