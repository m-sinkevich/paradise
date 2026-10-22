"""Сборка бейджей «Тишина Парадайза»: 16 персонажей, листы A4 + отдельные страницы бейджей.
Исходники карточек — design/*.dc.html из handoff (утверждённый макет)."""
import re, csv, os, shutil
import pathlib
B = str(pathlib.Path(__file__).resolve().parent)          # tools/badges
ROOT = str(pathlib.Path(B).parents[1])                     # корень репозитория
OUT = f'{B}/build'
src = open(f'{B}/design/Main.dc.html').read() + open(f'{B}/design/Sheet2.dc.html').read()

# ---- карточки из макета ----
cards = {}
for m in re.finditer(r'<!-- ([^·]+?) · [^>]+ -->\n(<div style="position: relative; isolation: isolate;.*?\n</div>\n)', src, re.S):
    cards[m.group(1).strip()] = m.group(2)
defs = re.search(r'<svg width="0" height="0".*?</svg>', src, re.S).group(0)
assert len(cards) == 11, cards.keys()

blob = {r['blob_url_in_artifact']: r['file'] for r in csv.DictReader(open(f'{B}/design/blob-map.csv'))}

def localize(h):
    def rep(m):
        f = blob[m.group(0)]
        return ('qr/' if f.startswith('qr-') else 'photos/') + f
    return re.sub(r'/_blob/[0-9a-f]{32}', rep, h)

PH_RE = re.compile(r'(<div style="position: relative; z-index: 4; width: 116px; height: 146px; flex-shrink: 0; box-sizing: border-box; border: 1px solid [^;]+; background: [^;]+); display: flex; align-items: center; justify-content: center; color: [^;]+; font-size: 13px; font-weight: 700">\[ФОТО\]')
def set_photo(h, slug, alt):
    if PH_RE.search(h):
        h = PH_RE.sub(lambda m: m.group(1) + f'; overflow: hidden">\n        <img src="photos/{slug}.jpg" alt="Фото: {alt}" style="width: 100%; height: 100%; object-fit: cover; object-position: 50% 30%; display: block">', h)
    else:
        h = re.sub(r'<img src="photos/[^"]+" alt="Фото: [^"]*"', f'<img src="photos/{slug}.jpg" alt="Фото: {alt}"', h)
    return h

def set_qr(h, slug, code):
    return re.sub(r'<img src="qr/[^"]+" alt="QR-код [^"]*"', f'<img src="qr/qr-{slug}.svg" alt="QR-код {code}"', h)

def set_name(h, first, last):
    h = re.sub(r'(letter-spacing: 2px; color: #[0-9A-F]{6}">)[^<]+(</div>\n      <div style="font-family: \'Oswald\', sans-serif; font-weight: \d00; font-size: 31px; line-height: 1">)[^<]+',
               lambda m: m.group(1) + first + m.group(2) + last, h, count=1)
    return h

def set_field(h, label, value, new_label=None):
    pat = re.compile(r'(color: #[0-9A-F]{6}">)' + re.escape(label) + r'(</div><div[^>]*>)(.*?)(</div>)')
    assert pat.search(h), label
    return pat.sub(lambda m: m.group(1) + (new_label or label) + m.group(2) + value + m.group(4), h, count=1)

def set_micro(h, text):
    return re.sub(r'(font-size: 9px; font-weight: 700; letter-spacing: 1.5px; line-height: 1.3[^"]*">)(.*?)(</div>)', lambda m: m.group(1) + text + m.group(3), h, count=1)

DATES = {'2029-07-12': '4076-07-12', '2028-10-10': '4075-10-10', '2315-11-23': '4108-11-23', '2298-06-01': '4089-06-01'}

# slug, полное имя, модуль, код, номер, шаблон
HEROES = [
    ('giorgi', 'Гиорги Гхвиношвили', 'Пирвели', 'MK8XYW', 'PG-CAP-01', 'ГИОРГИ ГХВИНОШВИЛИ'),
    ('arsen', 'Арсен Серосян', 'Пирвели', None, 'PG-XO-02', 'СТЕПАН РЯЗИН'),
    ('stepan', 'Степан Рязин', 'Пирвели', 'PN68AC', 'PG-ENG-03', 'СТЕПАН РЯЗИН'),
    ('silvio', 'Сильвио Чирзанне', 'Пирвели', None, 'PG-SCI-04', 'СТЕПАН РЯЗИН'),
    ('andrew', 'Эндрю Воллас', 'Парадайз', 'YK5V65', None, 'ЭНДРЮ ВОЛЛАС'),
    ('antoine', 'Антуан Зиппер', 'Парадайз', 'WS5NEX', None, 'АНТУАН ЗИППЕР'),
    ('magda', 'Магда Берт', 'Парадайз', 'EYRT3M', None, 'МАГДА БЕРТ'),
    ('alissia', 'Алиссия Тёрнер', 'Парадайз', 'TRD6W3', None, 'АЛИССИЯ ТЁРНЕР'),
    ('dylan', 'Дилан Бэтч', 'Фридом', 'PH2GAD', None, 'ДИЛАН БЭТЧ'),
    ('eva', 'Ева Форманн', 'Фридом', None, None, 'НАТЕЛЛА ИСАЙРО'),
    ('natella', 'Нателла Исайро', 'Фридом', 'BN533Q', None, 'НАТЕЛЛА ИСАЙРО'),
    ('ganesh', 'Ганеш Шарма', 'Фридом', None, None, 'НАТЕЛЛА ИСАЙРО'),
    ('mateo', 'Отец Матео Альварес', 'Искупление', None, 'CH-0020', 'ТАМАРА ОРЛОВА'),
    ('marcus', 'Маркус Кейн', 'Искупление', 'ZT3H52', 'RK-4592-B', 'МАРКУС КЕЙН'),
    ('lin', 'Линь Цзинь', 'Искупление', '9DQMDT', 'C-1187', 'ЛИНЬ ЦЗИНЬ'),
    ('tamara', 'Тамара Орлова', 'Искупление', 'FJKTZD', 'A-7324', 'ТАМАРА ОРЛОВА'),
]
NEW_CODES = {'arsen': 'UNMCH3', 'silvio': 'VS6YE9', 'eva': 'QNGDK2', 'ganesh': '9KH93X', 'mateo': '22HUJR'}

def build_card(slug, full, module, code, number, tpl):
    h = localize(cards[tpl])
    for a, b in DATES.items(): h = h.replace(a, b)
    code = code or NEW_CODES[slug]
    h = set_photo(h, slug, full)
    h = set_qr(h, slug, code)
    if slug == 'arsen':
        h = set_name(h, 'АРСЕН', 'СЕРОСЯН')
        h = set_field(h, 'ДОЛЖНОСТЬ', 'СТАРПОМ')
        h = set_field(h, 'ГРУППА КРОВИ', '0(I) Rh+')
        h = set_field(h, 'НОМЕР', 'PG-XO-02')
    if slug == 'silvio':
        h = set_name(h, 'СИЛЬВИО', 'ЧИРЗАННЕ')
        h = set_field(h, 'ДОЛЖНОСТЬ', 'УЧЁНЫЙ')
        h = set_field(h, 'ГРУППА КРОВИ', 'AB(IV) Rh−')
        h = set_field(h, 'НОМЕР', 'PG-SCI-04')
    if slug == 'eva':
        h = set_name(h, 'ЕВА', 'ФОРМАНН')
        h = set_field(h, 'СПЕЦИАЛЬНОСТЬ', 'СПЕЦАГЕНТ')
        h = set_field(h, 'ДОПУСК', 'ОСОБЫЙ')
        h = set_field(h, 'ГРУППА КРОВИ', '0(I) Rh−')
        h = set_micro(h, 'СПЕЦОПЕРАЦИИ<br>ШТАБ СОЛА')
    if slug == 'ganesh':
        h = set_name(h, 'ГАНЕШ', 'ШАРМА')
        h = set_field(h, 'СПЕЦИАЛЬНОСТЬ', 'КСЕНОБИОЛОГ')
        h = set_field(h, 'ГРУППА КРОВИ', 'B(III) Rh+')
        h = set_micro(h, 'КСЕНОБИОЛОГИЯ<br>ДЕСЯТКИ ЭКСПЕДИЦИЙ')
    if slug == 'mateo':
        h = set_name(h, 'ОТЕЦ МАТЕО', 'АЛЬВАРЕС')
        h = set_field(h, 'СТАТУС', 'КАПЕЛЛАН', 'ДОЛЖНОСТЬ')
        h = set_field(h, 'УРОВЕНЬ ОПАСНОСТИ', 'ВСЕ БЛОКИ', 'ДОПУСК')
        h = set_field(h, 'СРОК', '20+ ЛЕТ', 'СЛУЖБА')
        h = set_field(h, 'НОМЕР', 'CH-0020')
        h = set_micro(h, 'ДУХОВНАЯ ОПЕКА<br>ЭКИПАЖ МОДУЛЯ')
        h = h.replace('border: 2px solid #B3261E', 'border: 2px solid #222222').replace('color: #B3261E; pointer-events: none">ПОД СТРАЖЕЙ', 'color: #222222; pointer-events: none">ПЕРСОНАЛ')
    h = re.sub(r'<!--.*?-->', '', h)
    return h, code

HEAD = '''<!doctype html><html lang="ru"><head><meta charset="utf-8"><title>{title}</title>
<link rel="stylesheet" href="fonts.css">
<style>body{{margin:0;background:#fff}} @page{{size:{page};margin:0}} .sheet{{page-break-after:always}}</style></head><body>'''

def fit_script():
    # длинные фамилии — уменьшаем кегль только фамилии
    return '''<script>document.fonts.ready.then(()=>{document.querySelectorAll('[style*="font-size: 31px"]').forEach(el=>{let s=31;const p=el.parentElement;while(el.scrollWidth>p.clientWidth+0.5&&s>18){s-=1;el.style.fontSize=s+'px';}});document.body.dataset.ready=1;});</script>'''

os.makedirs(OUT, exist_ok=True)
for d, src_dir in (('photos', f'{ROOT}/catalog/photos'), ('qr', f'{B}/qr'), ('fonts', f'{B}/fonts')):
    shutil.rmtree(f'{OUT}/{d}', ignore_errors=True); shutil.copytree(src_dir, f'{OUT}/{d}')
shutil.copy(f'{B}/fonts.css', f'{OUT}/fonts.css')

built = []
for row in HEROES:
    h, code = build_card(*row)
    built.append((row[0], row[1], row[2], code, row[4], h))

# листы A4: 6 на лист
sheets = []
for i in range(0, len(built), 6):
    chunk = built[i:i + 6]
    sheets.append('<div class="sheet" style="width: 1123px; height: 794px; box-sizing: border-box; background: #ffffff; display: grid; grid-template-columns: repeat(3, 265px); grid-auto-rows: 321px; gap: 20px; justify-content: center; align-content: center; font-family: \'Sofia Sans Condensed\', sans-serif">\n'
                  + '\n'.join(c[5] for c in chunk) + '\n</div>')
open(f'{OUT}/sheets.html', 'w').write(HEAD.format(title='Бейджи — печать', page='A4 landscape') + defs + '\n'.join(sheets) + fit_script() + '</body></html>')

# отдельные бейджи (без zoom, 350×425)
for slug, full, module, code, number, h in built:
    one = h.replace('zoom: 0.7559; ', '', 1)
    open(f'{OUT}/badge-{slug}.html', 'w').write(HEAD.format(title=full, page='350px 425px') + defs +
        '<div style="width:350px;height:425px;font-family: \'Sofia Sans Condensed\', sans-serif">' + one + '</div>' + fit_script() + '</body></html>')

with open(f'{OUT}/heroes_qr.csv', 'w', newline='') as f:
    w = csv.writer(f); w.writerow(['slug', 'module', 'name', 'qr_code', 'badge_id', 'sheet'])
    for i, (slug, full, module, code, number, h) in enumerate(built):
        w.writerow([slug, module, full, code, number or '', i // 6 + 1])
print('ok', len(built), 'sheets', len(sheets))
