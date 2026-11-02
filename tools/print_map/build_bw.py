"""Нейтральная чёрно-белая карта полигона на А4: карта во весь лист, сетка по краям,
легенда, масштаб и «Отметки экипажа» с названиями модулей.
Запуск: python3 tools/print_map/build_bw.py  →  print/maps/karta_bw.pdf (+ .png для просмотра)
"""
import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).parent))
from build import *   # noqa: F401,F403 — данные карты, отрисовка, шрифты

SHEET_M = 6                      # поле листа, мм
MAP_W = 210 - 2 * SHEET_M        # ширина SVG карты (вместе с подписями сетки), мм
MARG = 64                        # поле под подписи сетки, в единицах карты
MMU = MAP_W / (W + 2 * MARG)
MMM = MMU / M_PER_U
MAP_H = (H + 2 * MARG) * MMU
SCALE = round(1000 / MMM / 50) * 50
MODULES = ['Пирвели', 'Парадайз', 'Фридом', 'Искупление']

S = dict(STYLES['v4b'], id='bw', bg='#ffffff', paper='#ffffff', ink='#111', hill=.1,
         cont='#7a7a7a', cont_w=(2.6, 1.2), cont_op=(.9, .55),
         canopy='#dcdcdc', canopy_op=1, canopy_edge='#222', canopy_dots=True, dot='#222', dot_r=2.2, dots_op=.35,
         path='#111', path_fill='#ffffff', road_fill='#6b6b6b', track_fill='#c4c4c4',
         bld='#111', bld_fill='#d0d0d0', hatch='#111', pool='#ececec', dome='#111', dome_fill='#8a8a8a',
         veil='rgba(255,255,255,.5)', grid='#111', grid_op=.3, frame='#111', frame_w=5,
         lab='#111', lab_font='Exo 2', lab_fs=40, font_t='Exo 2', font_b='Exo 2')

def sheet():
    css = f'''
.map {{ width: {MAP_W}mm !important; }}
.mapbox {{ position: absolute; left: {SHEET_M}mm; top: {SHEET_M}mm; }}
.bot {{ position: absolute; left: {SHEET_M + 4}mm; right: {SHEET_M + 4}mm; top: {SHEET_M + MAP_H + 3:.1f}mm; bottom: {SHEET_M + 2}mm;
        display: grid; grid-template-columns: 1fr 1fr; gap: 6mm; }}
.col {{ display: flex; flex-direction: column; }}
h3 {{ margin: 0 0 2.2mm; font: 700 3.3mm/1 'Exo 2'; letter-spacing: .5mm; text-transform: uppercase; }}
.meta {{ font: 500 2.9mm/1.45 'Exo 2'; margin-top: 3mm; }}
.col > .legend {{ gap: 3.2mm 4mm; }}
.col .lg {{ font-size: 3.3mm; }} .col .lg-ic {{ width: 11mm; height: 5.5mm; flex-basis: 11mm; }}
.sc {{ display: flex; align-items: flex-end; justify-content: space-between; margin-top: 5mm; }}
.notes .row {{ display: flex; align-items: flex-end; gap: 2mm; flex: 1; min-height: 7mm; font: 600 3.3mm 'Exo 2'; padding-bottom: .4mm; }}
.notes .row span {{ flex: 0 0 25mm; }}
.notes .row i {{ flex: 1; border-bottom: .3mm solid #111; height: 100%; }}
.notes .row.free i {{ border-bottom-style: dashed; }}
'''
    notes = ''.join(f'<div class="row"><span>{m}</span><i></i></div>' for m in MODULES) + ''.join('<div class="row free"><span></span><i></i></div>' for _ in range(5))
    scale_txt = f'{SCALE:,}'.replace(',', ' ')
    body = f'''<div class="mapbox">{map_svg(S, 'bw', margin=MARG)}</div>
<div class="bot">
  <div class="col"><h3>Условные знаки</h3>{legend_html(S, 2)}
    <div class="sc">{scale_bar(MMM, S, 100, 25, font='Exo 2', col='#111', alt='#fff')}{north(S, 10)}</div>
    <div class="meta">Масштаб ≈ 1 : {scale_txt} · клетка сетки {CELL} · горизонтали через 2 м</div></div>
  <div class="col notes"><h3>Отметки экипажа</h3>{notes}</div>
</div>'''
    return page(S, body, css)

if __name__ == '__main__':
    from playwright.sync_api import sync_playwright
    p = OUT / 'karta_bw.html'
    p.write_text(sheet())
    with sync_playwright() as pw:
        b = pw.chromium.launch()
        pg = b.new_page(viewport={'width': 794, 'height': 1123}, device_scale_factor=2)
        pg.goto(p.as_uri()); pg.wait_for_timeout(400)
        pg.pdf(path=str(p.with_suffix('.pdf')), format='A4', print_background=True, margin={'top': '0', 'right': '0', 'bottom': '0', 'left': '0'})
        pg.screenshot(path=str(p.with_suffix('.png')))
        b.close()
    print('ok, 1 :', SCALE, 'map', round(MAP_W), 'x', round(MAP_H), 'mm')
