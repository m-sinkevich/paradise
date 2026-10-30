# Сборка alien/index.html: подставляет данные (тексты, размеры строк, QR-матрицы) в шаблон.
import json, pathlib
here = pathlib.Path(__file__).resolve().parent
data = json.load(open(here / 'data.json', encoding='utf-8'))
html = (here / 'template.html').read_text(encoding='utf-8').replace('/*DATA*/null', json.dumps(data, ensure_ascii=False))
(here.parent / 'index.html').write_text(html, encoding='utf-8')
print('ok', len(html))
